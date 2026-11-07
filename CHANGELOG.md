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
