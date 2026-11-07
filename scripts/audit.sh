#!/usr/bin/env bash
# Run the compliance audit (Lynis + CIS role audit via syver) and summarise.
#   scripts/audit.sh [before|after|adhoc] [extra ansible-playbook args]
# Reports: reports/<host>/<UTC stamp>-<phase>/  (gitignored)
#   lynis-report.dat, lynis.log, <host>-UBUNTU26-CIS-1.0.0_pre_scan_<epoch>.json,
#   summary.txt (written by this script)
# OpenSCAP is not used: no CIS profile exists for ubuntu2604 in SCAP Security
# Guide 0.1.82 (only "default"). Re-check before each audit cycle.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"
[[ -d .venv/bin ]] && PATH="${REPO_ROOT}/.venv/bin:${PATH}"

phase="${1:-adhoc}"
case "${phase}" in before | after | adhoc) shift || true ;; *) phase=adhoc ;; esac

ansible-playbook playbooks/audit.yml -e "cis_audit_phase=${phase}" "$@"

# Summarise the newest run of this phase for every host.
for hostdir in reports/*/; do
  [[ -d "${hostdir}" ]] || continue
  run="$(find "${hostdir}" -mindepth 1 -maxdepth 1 -type d -name "*-${phase}" | sort | tail -1)"
  [[ -n "${run}" ]] || continue
  python3 -I - "${run}" <<'PY'
import glob, json, os, re, sys
run = sys.argv[1]
lines = [f"Audit run: {run}"]
lynis = os.path.join(run, "lynis-report.dat")
if os.path.exists(lynis):
    text = open(lynis, encoding="utf-8", errors="replace").read()
    idx = re.search(r"^hardening_index=(\d+)", text, re.M)
    warns = re.findall(r"^warning\[\]=(.*)$", text, re.M)
    sugg = re.findall(r"^suggestion\[\]=(.*)$", text, re.M)
    lines.append(f"Lynis hardening index: {idx.group(1) if idx else 'n/a'} "
                 f"(warnings: {len(warns)}, suggestions: {len(sugg)})")
    lines += [f"  WARNING {w.split('|')[0]}: {w.split('|')[1] if '|' in w else w}" for w in warns]
for path in sorted(glob.glob(os.path.join(run, "*.json"))):
    data = json.load(open(path, encoding="utf-8"))
    summ = data.get("summary", {})
    total = summ.get("test-count", 0)
    failed = summ.get("failed-count", 0)
    skipped = summ.get("skipped-count", 0)
    passed = total - failed - skipped
    rate = (100.0 * passed / (total - skipped)) if total - skipped else 0.0
    lines.append(f"CIS audit {os.path.basename(path)}: {total} checks, {passed} passed, "
                 f"{failed} failed, {skipped} skipped -> pass rate {rate:.1f}% (excl. skipped)")
    for res in data.get("results", []):
        # goss/syver result codes: 0 = pass, 1 = fail, 2 = skip
        skipped = res.get("skipped") or res.get("result") == 2
        if res.get("result") == 1 or skipped:
            state = "SKIPPED" if skipped else "FAILED"
            title = (res.get("title") or res.get("summary-line") or "")[:150]
            lines.append(f"  {state}: {title}")
out = "\n".join(lines) + "\n"
open(os.path.join(run, "summary.txt"), "w", encoding="utf-8").write(out)
print(out)
PY
done
