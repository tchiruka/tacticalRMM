# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and the project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

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
