# Runbook – Tactical RMM (Ubuntu 26.04, CIS L1)

All commands run from the repository root on the Ansible controller, with
`source .venv/bin/activate` and `ANSIBLE_VAULT_PASSWORD_FILE` exported, unless
marked **[server]**.

## Contents

1. [Snapshots](#snapshots)
2. [Test on a throwaway VM (snapshot-and-revert)](#test-on-a-throwaway-vm-snapshot-and-revert)
3. [Install](#install)
4. [Credentials](#credentials)
5. [Backups](#backups)
6. [Restore and restore test](#restore-and-restore-test)
7. [Upgrade Tactical RMM](#upgrade-tactical-rmm)
8. [OS patching](#os-patching)
9. [Certificates](#certificates)
10. [OS migration policy](#os-migration-policy)
11. [Rollback (99-rollback-notes)](#rollback-99-rollback-notes)
12. [Logging / SIEM](#logging--siem)
13. [Monitoring](#monitoring)
14. [Compliance audit](#compliance-audit)
15. [Break-glass](#break-glass)

---

## Snapshots

Take a snapshot before every phase and every change. Use a crash-consistent snapshot without memory.

```bash
# VMware vSphere (govc)
govc snapshot.create -vm "$VM" -m=false "pre-<change>-$(date +%F)"
govc snapshot.revert -vm "$VM" "pre-<change>-<date>"
govc snapshot.remove -vm "$VM" "pre-<change>-<date>"      # after acceptance, max 72 h

# OpenStack (boot-from-volume)
openstack volume snapshot create --force --volume "$VOLUME" "pre-<change>-$(date +%F)"
# OpenStack (ephemeral root disk)
openstack server image create --name "pre-<change>-$(date +%F)" "$SERVER"
openstack server rebuild --image "pre-<change>-<date>" "$SERVER"   # revert
```

Snapshots are not backups. Delete them once the change is accepted.

## Test on a throwaway VM (snapshot-and-revert)

This replaces a Molecule scenario: CIS hardening needs a real kernel, systemd,
mounts, AppArmor and reboots. Use a VM with the production layout, but test
DNS names and a staging certificate.

1. Build a fresh Ubuntu 26.04 VM (README layout). Snapshot `clean`.
2. Inventory: a separate `inventory/hosts.yml` (or `-i inventory/test.yml`) pointing to the test VM.
3. `ansible-playbook playbooks/01-baseline.yml --check --diff`, then without `--check`.
   Open `reports/<host>-preflight.json`. **Record** sudo, coreutils, time daemon, firewall, OpenSSH and mounts in the table below.
4. `ansible-playbook playbooks/02-trmm-install.yml`. Log in to the web UI with the TOTP. Snapshot `trmm-installed`.
5. `scripts/audit.sh before`
6. `ansible-playbook playbooks/03-cis-level1.yml --diff`, then `ansible-playbook playbooks/04-post-hardening-verify.yml`.
7. Functional checks: install one Windows test agent; run a script; open Take Control (Mesh); receive an alert e-mail.
8. `scripts/audit.sh after`. Record the pass rate in `docs/cis-exceptions.md` §4.
9. Idempotence: `scripts/idempotence.sh playbooks/site.yml`. It must end with `changed=0`. Record any task that changes and why.
10. Upgrade rehearsal (when a newer TRMM exists): `trmm-upgrade.yml`.
11. Backup + restore test (below) onto a second fresh VM.
12. Revert to `clean` and repeat after any change to the roles.

**Idempotence notes (from code review; confirm in step 9).**

- First-run-only changes (expected): installer run and cleanup, certificate issuance and first copy, `aa-enforce` of complain-mode profiles, vendor role remediation, reboot.
- Neutralised: the vendor `PRELIM | Run apt update` (`ubtu26cis_ignore_apt_update_changed_when: true`) and the baseline apt cache refresh (`changed_when: false`).
- To watch: vendor 7.1.11/7.1.12 (world-writable/unowned file sweeps). If TRMM keeps creating such files, they'll change on every run; record the path and decide fix or exception. Also 5.4.1.x (`chage`): it changes only while a non-compliant password-bearing account exists.

| Date | Tester | 26.04 image | sudo | coreutils | time | OpenSSH | Install | Verify | Idempotent | Notes |
|---|---|---|---|---|---|---|---|---|---|---|
| _pending_ | | | | | | | | | | |

## Install

Follow [README – First run](../README.md#first-run-check-mode-first). Notes:

- `02-trmm-install.yml` refuses to run if upstream `master` is no longer
  TRMM `trmm_version`, or if `install.sh` doesn't match the pinned SHA-256.
  Read the new release notes, update the three `trmm_*` pins in
  `inventory/group_vars/all/main.yml` and `CHANGELOG.md`, then retry.
- The installer takes 15-40 minutes and its output is suppressed (it contains
  secrets). On failure, a redacted tail is shown. **Do not re-run on the same VM**:
  `install.sh` requires a clean server. Revert the snapshot instead.
- The installer's Let's Encrypt flow (`certbot --manual`) is interactive and can't
  renew unattended. This repo obtains the certificate first (DNS-01 plugin or
  your own) and passes it with the documented `--use-own-cert` flag.

## Credentials

| What | Where |
|---|---|
| Web superuser + password + TOTP secret, Mesh admin user + password | `credentials/<host>.vault.yml` (controller, gitignored): `ansible-vault view credentials/<host>.vault.yml` |
| sudo / GRUB / SMTP / DNS-API / backup credentials | `inventory/group_vars/all/vault.yml` (ansible-vault) |
| age **private** key for backups | Offline (password manager / safe), **never** on the server or in git |

After first login: store the credentials file in the team password manager,
then delete it from the controller (`shred -u credentials/<host>.vault.yml`).

## Backups

**What:** the official `backup.sh` (TRMM docs: "Backup") covers the PostgreSQL
dumps (TRMM + Mesh), MeshCentral data, certificates, nginx/systemd/conf.d,
`local_settings.py` and `/opt/tactical`.

**How:** `trmm-backup.timer` runs nightly (01:30 + up to 15 min jitter) as `tactical`:

1. Downloads the **latest** `backup.sh` from `master` (it doesn't update itself) and logs its version and SHA-256. A changed hash raises a syslog WARNING.
2. Runs it; the archive appears in `/rmmbackups/rmm-backup-<date>.tar`.
3. Encrypts it with `age` to the public key(s) in `trmm_backup_age_recipients` and deletes the plaintext.
4. Ships `*.tar.age` + `.sha256` off-host (S3 via rclone / rsync over SSH / NFS) and applies remote retention (S3/NFS; rsync targets enforce their own).
5. Keeps 7 days locally; writes `/var/lib/trmm-backup/last_success`.

**On demand** (before any change): `ansible-playbook playbooks/trmm-backup-now.yml`

**Check:** `journalctl -t trmm-backup -n 20` **[server]**. The health check warns after 26 h without success.

**Recommendations:** enable object lock/versioning (S3) or an immutable
repository (e.g. a Veeam hardened Linux repository as the rsync/NFS target).
Size `/var/tmp` for at least 2× one backup (staging).

**Optional pinning of backup.sh (R-01):** to run only a reviewed script,
replace the download step in `roles/trmm_backup/templates/trmm-backup.sh.j2`
with a checksum check, and accept that TRMM recommends running the latest.

## Restore and restore test

Restore always goes to a **fresh** 26.04 VM. `restore.sh` refuses to run over an
existing install and needs the same three FQDNs.

1. Build a fresh VM (README layout) with the same hostname plan.
2. `ansible-playbook playbooks/01-baseline.yml -l <newhost>`
3. Fetch the newest `rmm-backup-*.tar.age` from the backup target and verify it:
   `sha256sum -c rmm-backup-*.tar.age.sha256`
4. Decrypt on an admin workstation that holds the private key:
   `age -d -i /secure/age-key.txt -o /secure/rmm-backup-X.tar rmm-backup-X.tar.age`
5. `ansible-playbook playbooks/trmm-restore.yml -l <newhost> -e trmm_restore_archive=/secure/rmm-backup-X.tar`
   (downloads the latest `restore.sh`, runs it as `tactical`, then re-applies TLS, SMTP, health check and backups).
6. `shred -u /secure/rmm-backup-X.tar`
7. Point DNS (`rmm`, `api`, `mesh`) at the new VM, or use hosts-file overrides for a test.
8. `ansible-playbook playbooks/03-cis-level1.yml -l <newhost>` then `04-post-hardening-verify.yml`.

**Restore test (quarterly, and before any OS migration).** Run steps 1-8 in an
**isolated network**. Agents must not reach the test copy: no public DNS
change, use hosts-file entries on one test client. Acceptance criteria:

- [ ] All 10 services active; `04-post-hardening-verify.yml` passes
- [ ] Login with an existing technician account + TOTP
- [ ] Agent list, history, scripts, alert policies present; Mesh devices present
- [ ] Newest audit-log entries match the backup time (data loss ≤ RPO 24 h)
- [ ] Elapsed time recorded against the RTO target (4 h)

| Date | Backup used | Target VM | Duration | Result | Issues | Signed off |
|---|---|---|---|---|---|---|
| _pending first execution_ | | | | | | |

## Upgrade Tactical RMM

Based on the TRMM docs "Updating the RMM". `update.sh` must **never** be scheduled.

1. Read the release notes between the installed and latest version: <https://github.com/amidaware/tacticalrmm/releases>
2. Raise a standard change (template: `docs/change-record.md`). Snapshot the VM.
3. `ansible-playbook playbooks/trmm-upgrade.yml -e trmm_upgrade_confirm=true -e trmm_upgrade_snapshot_taken=true`
   - takes a fresh backup and stops if it doesn't succeed
   - downloads the latest `update.sh` (`wget -N` equivalent) and runs it as `tactical`, with `umask 0022` and `TMPDIR` on an exec-capable path (CIS `/tmp` noexec stays in place)
   - keeps the log at `/var/log/trmm-update-<from>-to-<to>.log` **[server]**
   - asserts the new version, then runs `04-post-hardening-verify.yml`
4. Update `trmm_version`, `trmm_install_script_version` and `trmm_install_script_sha256` in `inventory/group_vars/all/main.yml` (values from the new tag), and `CHANGELOG.md`.
5. **Rollback:** if the upgrade fails, try `./update.sh --force` as `tactical` once (TRMM docs: fixes a botched update). If that fails, revert the snapshot.
6. Keep the snapshot for 72 h, then delete it.

## OS patching

- Security updates install daily via `unattended-upgrades` (Ubuntu security pocket only, no automatic reboot).
- Monthly maintenance window: `sudo apt update && sudo apt -y upgrade` **[server]** (TRMM docs: "Periodically run apt update/upgrade"). This also updates nginx.org/PGDG/NodeSource packages. Reboot if `/var/run/reboot-required` exists, then run `04-post-hardening-verify.yml`.
- PCI DSS 6.3.3: critical patches within one month of release.

## Certificates

**Let's Encrypt DNS-01 (default).** `certbot.timer` renews automatically. The
deploy hook `/etc/letsencrypt/renewal-hooks/deploy/50-trmm.sh` copies the
certificate to `/etc/ssl/trmm/` and restarts `nginx meshcentral rmm daphne`,
the services the TRMM docs list.

- Test renewal: `sudo certbot renew --dry-run` **[server]**
- Force renewal: `sudo certbot renew --cert-name <root domain> --force-renewal` **[server]**
- Expiry alerting: the health check warns below 21 days and goes critical below 7 (syslog `trmm-healthcheck`, Prometheus `trmm_cert_days_remaining`).

Deviation from the TRMM docs: their manual renewal also runs `./update.sh --force`,
because the manual flow rewrites the files the installer configured. Here the
paths never change, so restarting the services is enough. If TRMM shows
certificate errors after a renewal, run `./update.sh --force` as `tactical`.

**Own certificate (`own_cert`).** Replace the PEM files on the controller (full
chain + key), then `ansible-playbook playbooks/02-trmm-install.yml --tags tls`.
The role copies them and restarts the same services.

## OS migration policy

> **In-place OS upgrades are NOT supported by Tactical RMM and will break the
> installation** (TRMM v1.6.0 release notes; update docs: "Do NOT attempt
> in-place OS upgrades").

- `do-release-upgrade` is diverted to a refusal stub, and `/etc/update-manager/release-upgrades` has `Prompt=never` (role `baseline`). Never change apt sources to a new release.
- Moving to a new Ubuntu release (or a newer VM) is **backup → fresh VM → restore**:
  1. Confirm the target OS is supported by the then-current `install.sh`/`restore.sh` (they check the OS).
  2. Check the target OS is supported by the CIS role/benchmark used here (a new major release needs a new role, e.g. UBUNTU28-CIS).
  3. **Download the latest backup script before taking the final backup.** It doesn't update itself. `trmm-backup.service` always does this; for a manual backup use `wget -N https://raw.githubusercontent.com/amidaware/tacticalrmm/master/backup.sh`.
  4. Follow [Restore](#restore-and-restore-test) onto the new VM, cut DNS over, keep the old VM powered off for 7 days, then decommission it.

## Rollback (99-rollback-notes)

| Phase | Rollback |
|---|---|
| 01 baseline | Revert snapshot. Partial: remove `/etc/ssh/sshd_config.d/10-baseline.conf`, `ufw disable` (console), `dpkg-divert --rename --remove /usr/bin/do-release-upgrade` |
| 02 TRMM install | Revert snapshot (installer needs a clean server; there is no uninstall) |
| 03 CIS | Revert snapshot. Do not try to "un-harden" with the role. For one control: set its `ubtu26cis_rule_*: false` **and** undo the setting by hand, then record an exception |
| TRMM upgrade | `./update.sh --force`; otherwise revert snapshot |
| Restore | Discard the new VM; DNS back to the old VM |
| Certificate | Restore `/etc/ssl/trmm/*.pem` from backup or the previous `/etc/letsencrypt/archive/` version, restart services |

## Logging / SIEM

1. Set `siem_enabled: true`, `siem_host`, `siem_port`, `siem_protocol`, `siem_tls` in `site.yml`.
2. `ansible-playbook playbooks/02-trmm-install.yml --tags siem` (TRMM log inputs) and `ansible-playbook playbooks/03-cis-level1.yml` (rsyslog forwarding, CIS 6.1.2.5, 6.1.2.8-10 for TLS, auditd syslog plugin).
3. Confirm events arrive (tags `trmm-*`, `sudo`, `audit`, `trmm-backup`, `trmm-healthcheck`). Close EXC-03.

## Monitoring

- Nagios/NRPE: `command[check_trmm]=/usr/local/sbin/trmm-healthcheck` (exit 0/1/2/3).
- Prometheus: node_exporter `--collector.textfile.directory=/var/lib/prometheus/node-exporter` picks up `trmm.prom` (`trmm_health_state`, `trmm_service_up`, `trmm_cert_days_remaining`, `trmm_backup_age_hours`, `trmm_disk_used_percent`).
- WARNING and CRITICAL results also go to syslog (`trmm-healthcheck`) and so to the SIEM.

## Compliance audit

`scripts/audit.sh before|after|adhoc` runs Lynis and the CIS role's audit and
writes `reports/<host>/<UTC>-<phase>/` with `summary.txt` (pass rate plus every
failed/skipped check). Sample path:
`reports/trmm01/20261107T120000Z-after/summary.txt`. Copy the numbers into
`docs/cis-exceptions.md` §4 and explain every failure.

## Break-glass

- **SSH lock-out:** use the hypervisor console with an admin password. Check `ufw status`, `sshd -T`, group `sshlogin`.
- **Account locked (faillock, 30 min):** `sudo faillock --user <name> --reset` (from another admin or the console).
- **GRUB:** default entries boot without a password. Editing needs user `root` and the password whose hash is `vault_grub_password_hash`.
- **TRMM web lock-out / lost TOTP:** **[server]** `sudo -iu tactical`, `cd /rmm/api/tacticalrmm && source ../env/bin/activate && python manage.py reset_2fa <username>` (new TOTP secret + QR; verified at v1.6.1). Password: `python manage.py reset_password <username>`.
