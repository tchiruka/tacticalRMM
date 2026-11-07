# Compliance mapping

Engineering mapping of implemented controls to CIS Level 1, PCI DSS v4.0 and
ISO/IEC 27001:2022 Annex A. It supports, but does not replace, assessment by a
QSA or the ISMS owner. PCI DSS applies only if this server is in or connected
to a cardholder-data environment (an RMM that manages CDE systems normally
is: it is a "connected-to / security-impacting" system).

## Versions in force

| Item | Version / identifier | Verified |
|---|---|---|
| Benchmark | CIS Ubuntu Linux 26.04 LTS Benchmark **v1.0.0**, Level 1 – Server (+ selected L2) | cisecurity.org listing, 2026-11-07 |
| Hardening role | `ansible-lockdown/UBUNTU26-CIS` **0.9.0**, commit `9746233c6b14dd94758fc11e39e51ce6f5af24b7` (README: "Based on CIS UBUNTU Benchmark v1.0.0") | GitHub, 2026-11-07 |
| Role audit content | `ansible-lockdown/UBUNTU26-CIS-Audit` branch `benchmark_1.0.0`, commit `30675914e43b3d3821094c5f675d1baa993dc061` | GitHub |
| Audit engine | `syver` v0.15.1 (checksums pinned in the role) | role `defaults/main/audit.yml` |
| Lynis | Ubuntu 26.04 archive package (3.1.6 at time of writing) | `apt-cache policy lynis` |
| OpenSCAP / SSG | Not used: SSG 0.1.82 `ubuntu2604` has only a `default` profile | ComplianceAsCode repo |
| Tactical RMM | v1.6.1 (tag commit `086e2d97`), `install.sh` SCRIPT_VERSION 93 | GitHub tag |
| Ansible | ansible-core 2.22.0; community.general 13.5.0, ansible.posix 2.2.2, community.crypto 3.5.1, ansible.utils 6.1.1 | `requirements*.txt/yml` |

Control enablement: 322 of the role's 350 controls are enabled (all Level 1
Server controls except those in `docs/cis-exceptions.md`, plus the adopted
Level 2 auditd controls). The authoritative list is `roles/cis_level1/vars/main.yml`.

## Mapping

| # | Control area | Implementation | CIS 26.04 v1.0.0 | PCI DSS v4.0 | ISO 27001:2022 Annex A |
|---|---|---|---|---|---|
| 1 | Secure configuration standard | `cis_level1` (explicit per-control vars), audit before/after | all sections | 2.2.1, 2.2.6 | A.8.9 |
| 2 | Unused filesystems & network protocols disabled | vendor role | 1.1.1.x, 3.2.x | 2.2.4 | A.8.9 |
| 3 | Mount options (`/tmp`, `/dev/shm`, `/home`, `/var*`) | vendor role (`tmp.mount` for tmpfs) | 1.1.2.x | 2.2.6 | A.8.9 |
| 4 | Package source integrity (Signed-By, HTTPS, no insecure repos) | vendor role | 1.2.1.x | 2.2.6, 6.3.3 | A.8.19 |
| 5 | Patch management | `unattended-upgrades` (security), monthly window, gated `trmm-upgrade.yml` | 1.2.2.1 | 6.3.3 | A.8.8 |
| 6 | Mandatory access control | AppArmor enabled, no complain-mode profiles (EXC-05) | 1.3.1.x | 2.2.6 | A.8.9 |
| 7 | Boot loader protection | GRUB superuser password, `grub.cfg` 0600 | 1.4.1-2 | 2.2.6 | A.8.9 |
| 8 | Process hardening (ASLR, ptrace, core dumps, kptr/dmesg) | vendor role | 1.5.x | 2.2.6 | A.8.9 |
| 9 | Login banners | `/etc/issue(.net)`, SSH banner | 1.6.x, 5.1.6 | – | A.5.10 (supporting) |
| 10 | Minimal services; approved listeners | services removed/masked; nginx approved (EXC-01) | 2.1.x, 2.2.x | 2.2.4, 2.2.5 | A.8.9, A.8.20 |
| 11 | Time synchronisation | chrony, authorised sources only | 2.3.x | 10.6.1, 10.6.2, 10.6.3 | A.8.17 |
| 12 | Scheduler restrictions | cron/at allow-lists; jobs as systemd timers | 2.4.x | 7.2.1, 7.2.2 | A.8.2, A.8.18 |
| 13 | Network stack hardening | sysctl (no forwarding/redirects, rp_filter, syncookies, martians) | 3.3.x | 2.2.6 | A.8.20 |
| 14 | Host firewall | ufw default-deny; 22 from admin CIDR, 443 only; NATS loopback-only asserted | 4.1.1-3, 4.1.5 (`trmm_firewall`) | 1.2.1, 1.3.1, 1.4.2 | A.8.20, A.8.22 |
| 15 | Secure remote administration | SSH key-only, no root, AllowGroups, PQ-hybrid KEX, AEAD/ETM ciphers/MACs, LoginGraceTime, MaxAuthTries | 5.1.x | 2.2.7, 4.2.1, 8.2.2 | A.8.5, A.8.24, A.8.2 |
| 16 | Privileged access | sudo (sudo-rs) with use_pty, logging, timeout 15, `su` restricted; `tactical` NOPASSWD (EXC-02) | 5.2.x | 7.2.1, 7.2.2, 10.2.1.2 | A.8.2, A.8.18 |
| 17 | Password policy | pwquality (min 14, 3 classes), history 24, yescrypt, faillock 5 / 30 min incl. root | 5.3.x | 8.3.2, 8.3.4, 8.3.6, 8.3.7 | A.5.17, A.8.5 |
| 18 | Account lifecycle | max 365 / min 1 / warn 7 days, inactive 45 days, unique UIDs/GIDs | 5.4.1.x, 7.2.x | 8.2.1, 8.2.6, 8.3.9 (gap note) | A.5.16, A.5.18 |
| 19 | Session controls & defaults | TMOUT 900, umask 027, root PATH/umask, system accounts nologin | 5.4.2.x, 5.4.3.x | 8.2.8, 2.2.2 | A.8.2, A.5.15 |
| 20 | Multi-factor authentication | TRMM TOTP for every web user (superuser verified); SSH via MFA bastion (assumption A3) | – | 8.4.1, 8.4.2, 8.4.3 | A.8.5 |
| 21 | Local logging | persistent compressed journald, rsyslog, log file permissions, sudo log | 6.1.1.x, 6.1.2.1-4, 6.1.2.6-7, 6.1.3.1 | 10.2.1, 10.3.1, 10.3.2 | A.8.15 |
| 22 | Central logging | rsyslog → SIEM (TLS), TRMM logs via imfile, auditd syslog plugin (EXC-03 until live) | 6.1.2.5, 6.1.2.8-10 | 10.3.3, 10.4.1, 10.5.1 | A.8.15, A.8.16 |
| 23 | Audit trail | auditd (L2 adopted): identity, sudoers, time, network, MAC, privileged commands, logins, perm changes, mounts, deletions, kernel modules; immutable; log permissions; 90-day local archive | 6.2.x | 10.2.1, 10.2.1.1-10.2.1.7, 10.2.2, 10.3.2, 10.5.1 | A.8.15 |
| 24 | File integrity monitoring | AIDE with daily timer; audit-tool integrity | 6.3.1-3 | 10.3.4, 11.5.2 | A.8.16, A.8.9 |
| 25 | System file permissions | passwd/shadow/group modes, world-writable, unowned files, SUID/SGID review | 7.1.x | 2.2.6 | A.8.3, A.8.9 |
| 26 | Encryption in transit | TLS 1.2/1.3 (installer nginx), trusted cert, DNS-01 auto-renewal, expiry alerts | – | 4.2.1, 4.2.1.1 | A.8.24 |
| 27 | Backup & recovery | nightly latest `backup.sh`, age encryption (offline private key), off-host, retention 7 d local / 90 d remote, quarterly restore test | – | 12.10.1 (supporting) | A.8.13, A.5.30 |
| 28 | Change management & IaC | git, Conventional Commits, CI gates, CAB template, pinned dependencies | – | 6.5.1, 6.5.2 | A.8.32, A.8.9 |
| 29 | Secrets management | ansible-vault, `no_log`, gitleaks (pre-commit + CI), credentials only vault-encrypted | – | 8.3.2, 8.6.2 | A.5.17, A.8.4 |
| 30 | Service monitoring | health check (services, HTTPS, cert, backup age, disk) → syslog/Prometheus/NRPE | – | 10.7.2 | A.8.16 |
| 31 | Compliance evidence | Lynis + CIS role audit, before/after reports | – | 2.2.1, 11.3.1 (partial – see gaps) | A.5.36, A.8.8 |
| 32 | Documented procedures | runbook, exceptions register, change record | – | 1.1.1, 2.1.1, 10.1.1 (pattern x.1.1) | A.5.37 |
| 33 | OS lifecycle | in-place release upgrades blocked; migration = backup → fresh VM → restore | – | 6.3.3 (supported OS), 12.3.4 | A.8.19, A.8.32 |

## Gaps to close outside this repository

| Requirement | Gap | Suggested treatment |
|---|---|---|
| PCI 5.2.1 / 5.2.3 (anti-malware) | No anti-malware/EDR on the server | Deploy the organisation's Linux EDR, or document the periodic evaluation required by 5.2.3 |
| PCI 11.3.1 / 11.3.2 (vulnerability scans) | Lynis is a hardening audit, not an authenticated vulnerability scan | Add the server to the quarterly internal (authenticated) and external ASV scope (443 is internet-facing) |
| PCI 6.4.1 / 6.4.2 (public-facing web app) | TRMM web UI/API exposed on 443 | WAF/reverse proxy, or restrict technician UI (`rmm` FQDN) to VPN at the perimeter; agents only need `api` and `mesh` |
| PCI 8.3.9 / 8.3.10.1 | Admin passwords expire after 365 days (CIS). They're only used for sudo/console, but in PCI scope a password-only console login needs 90 days | If in scope: set `baseline_password_max_days` / `ubtu26cis_pass_max_days` to 90 |
| PCI 10.4.1 / 10.5.1 | Daily review and 12-month retention depend on the SIEM | Close EXC-03; configure SIEM retention ≥ 12 months (3 months online) |
| PCI 8.4.2 (MFA into CDE) | SSH MFA relies on the bastion (assumption) | Confirm bastion MFA or add an SSH MFA method |
| ISO A.5.30 / A.8.14 | Single node, RTO depends on restore | Accept, or document a warm-standby VM procedure |
