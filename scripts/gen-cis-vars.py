#!/usr/bin/env python3
"""Generate the per-control toggle block of roles/cis_level1/vars/main.yml.

Reads every `ubtu26cis_rule_*` variable from the vendored UBUNTU26-CIS role,
derives each control's level from its task tags and its title from the task
name, then applies this project's decisions (OVERRIDES / ADOPTED_L2).

Usage (after bumping the role in requirements.yml and re-installing it):
    .venv/bin/python scripts/gen-cis-vars.py .galaxy/roles/ubuntu26_cis > /tmp/rules.yml
    diff <(sed -n '/Section 1$/,$p' roles/cis_level1/vars/main.yml) /tmp/rules.yml
Review every difference before replacing the block.
"""
import glob
import re
import sys

import yaml

# Controls whose value differs from "Level 1 on / Level 2 off".
OVERRIDES = {
    "1.3.1.3": ("false", 'L2. Replaced by a narrower wrapper task: no profile left in complain mode; '
                         'Ubuntu "unconfined"-flag profiles untouched (EXC-05).'),
    "2.3.3.1": ("false", "Implemented by role baseline (single owner of /etc/chrony/sources.d)."),
    "4.1.1": ("false", "Implemented by role trmm_firewall (single owner of ufw)."),
    "4.1.2": ("false", 'Implemented by role trmm_firewall; the vendor task adds "allow OpenSSH" '
                       "from ANY source, widening the admin-CIDR rule."),
    "4.1.3": ("false", "Implemented by role trmm_firewall."),
    "4.1.4": ("false", "L2, not adopted: TRMM update.sh needs outbound HTTPS to "
                       "GitHub/PyPI/npm/nginx.org/PGDG/NodeSource/LE (EXC-04)."),
    "4.1.5": ("false", "Implemented by role trmm_firewall."),
    "5.2.4": ("false", "L2, not adopted: TRMM service account needs NOPASSWD sudo for "
                       "unattended backups (EXC-02)."),
    "6.1.2.5": ('"{{ siem_enabled | bool }}"', "Remote log host. Off until a SIEM endpoint is supplied (EXC-03)."),
    "6.1.2.8": ('"{{ siem_enabled | bool and siem_tls | bool }}"', "L2, adopted when forwarding over TLS."),
    "6.1.2.9": ('"{{ siem_enabled | bool and siem_tls | bool }}"', "L2, adopted when forwarding over TLS."),
    "6.1.2.10": ('"{{ siem_enabled | bool and siem_tls | bool }}"', "L2, adopted when forwarding over TLS."),
    "6.2.2.3": ("false", "L2, not adopted: halting the RMM when audit storage is full is an "
                         "availability risk; disk alerts + SIEM instead."),
    "6.2.2.4": ("false", "L2, not adopted: admin_space_left_action must be single/halt; same "
                         "availability rationale as 6.2.2.3."),
    "6.3.3": ("true", "L2, adopted: protects audit tool integrity via AIDE at negligible cost."),
}
# Level 2 auditd controls adopted because auditd is a project requirement.
ADOPTED_L2 = ("6.2.1.", "6.2.2.1", "6.2.2.2", "6.2.3.", "6.2.4.")
ADOPTED_L2_REASON = "L2, adopted: auditd with persistent rules is a project requirement."
NAME_RE = re.compile(r"^(\d+(?:\.\d+)+) \| (?:PATCH|AUDIT) \| ([^|]+)")


def walk(tasks, levels, titles):
    for task in tasks or []:
        if not isinstance(task, dict):
            continue
        tags = task.get("tags") or []
        tags = [tags] if isinstance(tags, str) else tags
        match = NAME_RE.match(str(task.get("name", "")))
        if match and match.group(1) not in titles:
            titles[match.group(1)] = match.group(2).strip()
        for tag in tags:
            if isinstance(tag, str) and tag.startswith("rule_"):
                levels.setdefault(tag[5:], set()).update(
                    t for t in tags if isinstance(t, str) and t.startswith("level"))
        for key in ("block", "rescue", "always"):
            walk(task.get(key), levels, titles)


def main(role):
    with open(f"{role}/defaults/main/main.yml", encoding="utf-8") as fh:
        rules = re.findall(r"^ubtu26cis_rule_([0-9_]+):", fh.read(), re.M)
    levels, titles = {}, {}
    for path in sorted(glob.glob(f"{role}/tasks/section_*/cis_*.yml")):
        with open(path, encoding="utf-8") as fh:
            walk(yaml.safe_load(fh), levels, titles)

    out, section = [], None
    for rule in rules:
        rid = rule.replace("_", ".")
        tags = levels.get(rid, set())
        is_l1 = "level1-server" in tags
        level = "L1" if is_l1 else ("L2" if any("level2" in t for t in tags) else "??")
        if rid in OVERRIDES:
            value, why = OVERRIDES[rid]
        elif not is_l1 and rid.startswith(ADOPTED_L2):
            value, why = "true", ADOPTED_L2_REASON
        elif is_l1:
            value, why = "true", ""
        else:
            value, why = "false", "L2, not in scope."
        if rid.split(".")[0] != section:
            section = rid.split(".")[0]
            out.append(f"\n# ---------------------------------------------------------------- Section {section}")
        out.append(f"# {rid} [{level}] {titles.get(rid, '(see benchmark)')}" + (f"\n#   -> {why}" if why else ""))
        out.append(f"ubtu26cis_rule_{rule}: {value}")
    sys.stdout.write("\n".join(out).lstrip("\n") + "\n")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
