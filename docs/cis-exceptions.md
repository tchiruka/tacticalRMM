# CIS exceptions and deviations

**Benchmark:** CIS Ubuntu Linux 26.04 LTS Benchmark **v1.0.0**, Level 1 – Server
(published; [cisecurity.org](https://www.cisecurity.org/benchmark/ubuntu_linux)). No fallback to 24.04 was needed.
**Implementation:** `ansible-lockdown/UBUNTU26-CIS` 0.9.0, commit `9746233c6b14dd94758fc11e39e51ce6f5af24b7`.
**Per-control settings:** `roles/cis_level1/vars/main.yml` (all 350 role controls listed explicitly).
**Owner placeholders:** replace `Infrastructure Lead` / `Security Officer` with named people before CAB.
**Next review:** 2027-05-07, or earlier on a benchmark/role/TRMM version change.

How conflicts were tested: (S) source review of TRMM v1.6.1 scripts and the role
at the pinned commits; (L) reproduced on an Ubuntu 26.04.1 system; (V) to be
confirmed on the throwaway test VM during the first run (runbook §Test VM).
Anything marked (V) only must not be treated as proven until that run is recorded.

## 1. Exceptions to Level 1 controls

| ID | Control | Deviation | Reason / evidence | Compensating controls | Residual risk | Owner | Review |
|---|---|---|---|---|---|---|---|
| EXC-01 | 2.1.19 Ensure web server services are not in use; 2.1.23 Ensure only approved services are listening | nginx stays installed and running (`ubtu26cis_nginx_server: true`). MeshCentral (4430/800) listens on all interfaces | nginx is TRMM's reverse proxy and TLS terminator; MeshCentral's listeners come from the official installer config, which the TRMM docs say not to edit (S). With the defaults, rule 2.1.19 **removes nginx** (S) | Dedicated single-purpose host; ufw default-deny with only 22 (admin CIDR) and 443 open; verify playbook asserts loopback-only NATS and the inbound rule set; TLS 1.2+/strong ciphers per installer; nginx from the signed nginx.org repo | Low | Infrastructure Lead | 2027-05-07 |
| EXC-03 | 6.1.2.5 Ensure rsyslog sends logs to a remote log host | Disabled while `siem_enabled: false` | No SIEM endpoint was provided (brief placeholder) | Persistent journald; local rsyslog; auditd (adopted L2) with 90-day local archive; nightly off-host backups; health-check alerts. Forwarding (rsyslog omfwd, imfile TRMM logs, auditd syslog plugin) is built and enabled by setting `siem_*` | Medium: logs could be tampered with after a root compromise | Security Officer | **Temporary** – close at SIEM onboarding, latest 2027-02-07 |
| EXC-07 | 1.1.2.3.2-3, 1.1.2.4.2-3, 1.1.2.5.2-4, 1.1.2.6.2-4, 1.1.2.7.2-4 (mount options) | Applied only where the partition exists | The options can't be set without separate partitions (role skips + warns) (S). Partition *existence* (1.1.2.x.1) is Level 2 | Build VMs with the recommended LVM layout (README); preflight reports missing partitions | Low with layout / Medium without | Infrastructure Lead | At VM build |

> EXC-02, EXC-04, EXC-05 and EXC-06 concern **Level 2** controls or non-CIS
> settings. They are listed below for completeness: they are not Level 1
> deviations, but auditors usually ask about them.

## 2. Level 2 controls and other settings

| ID | Item | Decision | Reason / evidence | Compensating controls | Residual risk | Owner | Review |
|---|---|---|---|---|---|---|---|
| EXC-02 | 5.2.4 (L2) users must provide a password for escalation; TRMM docs say "add tactical to the sudo group" | `tactical` is **not** in `sudo`; it has a locked password and a NOPASSWD rule in `/etc/sudoers.d/50-trmm-tactical` | TRMM `backup.sh`: "Passwordless sudo is required" (S); `update.sh`/`backup.sh` must run as the install user (S). A usable password on a service account would be worse | No password, no SSH (not in `sshlogin`); reachable only via an admin's own sudo; all sudo use logged (rsyslog `/var/log/sudo.log`, auditd 6.2.3.x); AIDE | Medium: a TRMM app compromise gives root. (An app compromise already gives control of every managed endpoint, which dominates this risk) | Infrastructure Lead | 2027-05-07 |
| EXC-04 | 4.1.4 (L2) ufw outgoing default deny | Not adopted; outbound allowed | `update.sh` needs GitHub, PyPI, npm, nginx.org, PGDG, NodeSource; certbot needs Let's Encrypt and the DNS provider API; backups/SMTP/SIEM need their targets (S) | Inbound default-deny; egress filtering at the perimeter firewall recommended | Low-Medium | Network Lead | 2027-05-07 |
| EXC-05 | 1.3.1.3 (L2) all AppArmor profiles enforcing | Replaced by a narrower task: every profile in **complain** mode is enforced; Ubuntu's `flags=(unconfined)` profiles are left alone | The vendor task runs `aa-enforce /etc/apparmor.d/*`. On a 26.04.1 (desktop) system that would convert 76 `flags=(unconfined)` profiles to enforce; a server install has fewer (L; V) | AppArmor enabled (1.3.1.1-2, L1), 1.3.1.4 (restrict unprivileged unconfined) on; verify asserts no complain-mode profiles | Low | Security Officer | 2027-05-07 |
| EXC-06 | 6.2.2.3 / 6.2.2.4 (L2) halt/single when audit storage is full/low | Not adopted (auditd defaults: SYSLOG / SUSPEND) | Halting the RMM stops remote management of every endpoint | Separate `/var/log/audit`; health check WARN ≥ 85 %, CRIT ≥ 95 %; daily archive + 90-day pruning; SIEM | Low | Security Officer | 2027-05-07 |
| – | 6.2.2.2 (L2, adopted) audit logs not automatically deleted | `keep_logs`; rotated files archived and **deleted after 90 days** by `audit-log-archive` | Without pruning `/var/log/audit` fills up (→ EXC-06 situation) | Retention ≥ 12 months held in SIEM + backups (PCI DSS 10.5.1) | Low once SIEM is live | Security Officer | with EXC-03 |
| – | 4.1.1/4.1.2/4.1.3/4.1.5, 2.3.3.1 | Vendor tasks off; **implemented by** `trmm_firewall` / `baseline` | The vendor 4.1.2 adds `allow OpenSSH` from **any** source, widening the admin-only SSH rule (S). Single ownership of chrony sources avoids flip-flopping files | Same controls, implemented once; verify playbook checks them | None | Infrastructure Lead | – |

## 3. Conflicts checked that did NOT need an exception

| Area | Potential conflict | Resolution |
|---|---|---|
| `/tmp` noexec (1.1.2.1.4) | Installer builds Python; `update.sh` uses pip/npm/mktemp | Install before hardening. Upgrades set `TMPDIR=$HOME/.trmm-tmp`; the mount stays noexec (S; V) |
| umask 027 (5.4.3.3) | `collectstatic` during `update.sh` → static files unreadable for nginx (`www-data`) | Upgrade runs `umask 0022` for that process only; verify checks `www-data` can read static files (S; V) |
| 5.4.2.7 system accounts `nologin` | `install.sh`/`restore.sh` use `sudo -iu postgres` | Both only run on clean, un-hardened VMs; `update.sh` doesn't use it (S) |
| 2.4.1.9 crontab restricted to root | `backup.sh --schedule` writes the user's crontab | systemd timer instead (no crontab) |
| 5.2.3 sudo log file | `sudo-rs` rejects `Defaults logfile` (L, visudo: "unknown setting: 'logfile'") | Role Method A: rsyslog `authpriv.*` → `/var/log/sudo.log` (`ubtu26cis_syslog_service: rsyslog`) |
| 1.1.2.1.x on tmpfs `/tmp` | Role skips the fstab method for tmpfs (S); 26.04 uses `tmp.mount` (L) | `ubtu26cis_tmp_svc: true` (unit options incl. noexec) |
| 1.4.1 GRUB password | Unattended reboots | `--unrestricted` default entries; password only for edits/shell |
| SSH crypto (5.1.7/5.1.13/5.1.17) | Role default MAC list contains `hmac-sha1` | Overridden; lists checked against `ssh -Q` on the target (OpenSSH 10.2p1) |
| 6.1.3.1 log file access | rsyslog `imfile` of TRMM logs outside `/var/log` | AppArmor `rsyslog.d` include for the TRMM log dir only; `/var/log/celery` not forwarded until verified (V) |

## 4. Benchmark and role maturity gaps (26.04)

- The CIS 26.04 benchmark is **v1.0.0** and the ansible-lockdown role is **0.9.0**, released **5 days** before this build. Expect fixes in the coming months; re-run `scripts/gen-cis-vars.py` and diff on every role bump.
- Control IDs and titles in this repo come from the role's task names. **Cross-check them against the benchmark PDF** (CIS WorkBench) before the CAB.
- The role's README: "Check Mode is not guaranteed", so `--check` on `03-cis-level1.yml` is indicative only.
- No OpenSCAP/SSG CIS profile exists for `ubuntu2604` (SSG 0.1.82). Evidence comes from the role's audit (syver/goss) plus Lynis. CIS-CAT Pro (CIS member licence) lists a 26.04 v1.0.0 assessment if formal scoring is needed.
- Pass rate: **not yet measured** (no target VM run). After the first run, record it from `reports/<host>/*-after/summary.txt` in the table below.

| Date | Host | Role audit: checks / passed / failed / skipped | Pass rate | Lynis index | Notes |
|---|---|---|---|---|---|
| _pending first run_ | | | | | |

## 5. Other risks (non-CIS)

| ID | Risk | Treatment |
|---|---|---|
| R-01 | `backup.sh` is downloaded from upstream `master` and run as `tactical` (with sudo) **every night**. TRMM requires this ("does not update itself") | The script hash is logged; a change raises a syslog WARNING (`trmm-backup`) for review. Optionally pin to a reviewed hash (runbook) |
| R-02 | The installer clones `master`; a moving upstream could install an unreviewed version | Preflight refuses if upstream `TRMM_VERSION` or the `install.sh` SHA-256 differs from the pin; post-install assert |
| R-03 | Single server, no HA | Nightly off-host backups; tested restore to a fresh VM (RTO target in change record) |
