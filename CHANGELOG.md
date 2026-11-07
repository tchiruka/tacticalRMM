# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and the project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.0.0] - 2026-11-07

First release. Pins: Tactical RMM v1.6.1, CIS Ubuntu Linux 26.04 LTS
Benchmark v1.0.0 (Level 1 Server), ansible-lockdown UBUNTU26-CIS 0.9.0
(`9746233c`). Static gates pass; not yet run against a target VM.

### Added
- Repository scaffold: Ansible config, pinned Galaxy requirements, lint and
  secret-scanning tooling (yamllint, ansible-lint, shellcheck, gitleaks).
- `baseline` role: platform/placeholder/lock-out preflight gates with a
  platform report (sudo-rs, uutils, OpenSSH, chrony, mounts), packages,
  locale/timezone, chrony with authorised sources, admin users with
  password ageing and exclusive keys, key-only SSH with verified crypto,
  persistent journald, security-only unattended upgrades, and blocked
  in-place release upgrades (`Prompt=never` + diverted do-release-upgrade).
- `trmm_firewall` role: ufw default-deny, SSH from admin CIDRs, 443 only.
- Inventory examples in `inventory/examples/` (never auto-loaded).
- `trmm_server` role: TRMM v1.6.1 via the official install.sh (unmodified,
  non-root `tactical` user, `--use-own-cert`), upstream pin enforcement
  (TRMM_VERSION + install.sh SHA-256), Let's Encrypt DNS-01 via certbot
  plugin with deploy hook or operator-supplied certificate, generated
  credentials written only vault-encrypted, SMTP via CoreSettings, Nagios/
  Prometheus health check timer, optional rsyslog imfile inputs for SIEM.
- `trmm_backup` role: nightly systemd timer that downloads the latest
  official backup.sh, age-encrypts, ships to S3/rsync/NFS, applies retention.
- Playbooks: `02-trmm-install.yml`, `04-post-hardening-verify.yml`,
  `trmm-backup-now.yml`, `trmm-upgrade.yml` (gated, snapshot + backup first),
  `trmm-restore.yml` (fresh 26.04 VM).
- `cis_level1` role wrapping ansible-lockdown UBUNTU26-CIS 0.9.0 (CIS Ubuntu
  26.04 v1.0.0): all 350 controls set explicitly in role vars with level,
  title and reason; Level 2 auditd controls adopted; install-before-harden
  order guard; narrow AppArmor enforcement; audit-log archive/retention;
  auditd->syslog when SIEM is enabled; controlled reboot + TRMM recheck.
- `03-cis-level1.yml`, `audit.yml` (Lynis + role audit, before/after),
  `site.yml`; `scripts/gen-cis-vars.py` to regenerate the control block.
- CI (GitHub Actions, SHA-pinned): yamllint, ansible-lint (production
  profile), shellcheck incl. rendered templates, syntax-check, gitleaks.
- `scripts/audit.sh` (summary with pass rate and failed/skipped checks) and
  `scripts/idempotence.sh` (second run must be changed=0).
- Docs: README (architecture, ports, quick start, first-run sequence,
  onboarding, assumptions), architecture, CIS exceptions register, runbook,
  ITIL 4 change record, CIS/PCI DSS v4.0/ISO 27001:2022 mapping.

### Security
- faillock unlock time 1800 s (PCI DSS v4.0 8.3.4); weak SSH MACs removed
  from the CIS role default list; vendor `allow OpenSSH from any` and
  blanket `aa-enforce` avoided.

[Unreleased]: <REMOTE_URL>/compare/v1.0.0...HEAD
[1.0.0]: <REMOTE_URL>/releases/tag/v1.0.0
