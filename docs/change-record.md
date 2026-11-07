# Change record – Deploy CIS-hardened Tactical RMM server (Ubuntu 26.04)

> ITIL 4 Change Enablement. Pre-filled; complete every `‹…›` field before CAB.

| Field | Value |
|---|---|
| Change ID | ‹ITSM ref› |
| Title | Deploy Tactical RMM v1.6.1 on Ubuntu 26.04 LTS, hardened to CIS Level 1 Server, via Ansible (IaC repo v1.0.0) |
| Change type | Normal (first deployment). Later re-runs and TRMM upgrades: Standard, once this change is accepted as the model |
| Category | New service / infrastructure |
| Requester | ‹name› |
| Change owner / implementer | ‹Infrastructure Lead› / ‹engineer› |
| Approvers | CAB, Security Officer, Service Owner (endpoint management) |
| CIs affected | New VM ‹hostname› (‹vSphere/OpenStack›); DNS records `rmm`, `api`, `mesh` under ‹domain›; perimeter firewall rule TCP 443 → VM; backup target ‹bucket/repo›; SMTP relay; (SIEM) |
| Planned window | ‹date, 4 h› – no user impact (new service) |
| Repository / version | ‹REMOTE_URL›, tag `v1.0.0`, commit ‹sha› |

## 1. Description

Build a new single-node Tactical RMM server with the official installer
(v1.6.1), unchanged, on a fresh Ubuntu 26.04 VM. Configure TLS (Let's Encrypt
DNS-01 / internal CA), SMTP alerting, health monitoring and nightly encrypted
off-host backups. Harden the host to **CIS Ubuntu Linux 26.04 LTS Benchmark
v1.0.0 Level 1 – Server**, plus the Level 2 auditd controls, using
`ansible-lockdown/UBUNTU26-CIS` 0.9.0. All steps are Ansible playbooks in
version control.

## 2. Justification

- Central remote monitoring, scripting, patching and remote control for ‹N› endpoints.
- Build is repeatable and auditable; CIS hardening and evidence (Lynis + CIS audit before/after) support PCI DSS v4.0 Req. 2.2 and ISO/IEC 27001:2022 A.8.9.
- Not changing: no RMM in place / manual tooling (‹state current tooling›).

## 3. Risk assessment

| # | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| 1 | Hardening breaks TRMM (noexec `/tmp`, umask, nologin, AppArmor, firewall) | Medium | High | Install before harden (enforced); conflicts reviewed (`docs/cis-exceptions.md` §3); verify playbook; snapshot before phase 3 |
| 2 | CIS role 0.9.0 / benchmark v1.0.0 immature (released 2026-11-02) | Medium | Medium | Pinned by commit; every control explicit; tested on a throwaway VM first; check mode "not guaranteed" noted |
| 3 | Upstream TRMM changes during install | Low | Medium | Preflight refuses if upstream version or installer hash differs from the pin |
| 4 | Admin lock-out (SSH/firewall/faillock) | Low | Medium | Preflight lock-out guard (source IP in admin CIDR); console access + break-glass procedure |
| 5 | Credential exposure during install | Low | High | `no_log` on expect; credentials written only vault-encrypted |
| 6 | RMM is a high-value target (controls all endpoints) | Medium | Critical | Internet exposure limited to 443; TOTP for all users; CIS L1; auditd; SIEM (EXC-03 until onboarded); patching; nightly encrypted backups |
| 7 | Nightly `backup.sh` fetched from upstream (supply chain) | Low | High | Hash logged + WARNING on change (R-01); option to pin |

**Overall risk:** Medium (before mitigation High). **Risk owner:** ‹Service Owner›.

## 4. Impact

- **Users/services:** none during implementation (new service). Agents are onboarded afterwards in a separate, planned rollout.
- **Network:** new inbound TCP 443 from the Internet/agent networks to the VM; outbound HTTPS from the VM.
- **Security posture:** new internet-facing service with privileged reach into all managed endpoints (see risk 6).
- **Dependencies:** DNS, certificate authority / DNS provider API, SMTP relay, backup target, (SIEM).

## 5. Implementation plan

| Step | Action | Duration | Verification |
|---|---|---|---|
| 0 | Pre-checks: DNS records, firewall NAT/rule for 443, VM built per README layout, controller toolchain, vault populated, `scripts/lint.sh` green | 30 min | lint output |
| 1 | Snapshot `pre-baseline` | 5 min | snapshot listed |
| 2 | `01-baseline.yml --check --diff`, then apply | 15 min | preflight report; SSH still works |
| 3 | `02-trmm-install.yml --check`, then apply | 40 min | web login with TOTP; credentials file created |
| 4 | `scripts/audit.sh before` | 10 min | report saved |
| 5 | Snapshot `pre-cis`; `03-cis-level1.yml --diff` (may reboot) | 30 min | play recap |
| 6 | `04-post-hardening-verify.yml` | 5 min | all assertions pass |
| 7 | `scripts/audit.sh after`; record the pass rate | 10 min | `summary.txt` |
| 8 | `trmm-backup-now.yml`; confirm object at the backup target | 15 min | `backup OK` in journal |
| 9 | Second `site.yml` run → `changed=0` | 30 min | `scripts/idempotence.sh` |

## 6. Test plan

- **Before production:** the full procedure on a throwaway VM (runbook §Test VM), including restore onto a second fresh VM. Evidence attached: ‹links›.
- **During the change:** verification column above; `04-post-hardening-verify.yml` asserts services, users, HTTPS, NATS loopback, firewall rules, TOTP, SSH policy, `/tmp` options, AppArmor, auditd immutability, release-upgrade block, timers, health check.
- **Functional:** one test agent check-in, script run, Take Control session, alert e-mail received.

## 7. Backout plan

- **Trigger:** any failed verification that can't be fixed within the window, or loss of SSH/console management.
- **Action:** revert to snapshot `pre-cis` (hardening problem) or `pre-baseline` (anything else). The VM is new, so no data is lost. Remove the DNS records/firewall rule if the service is abandoned.
- **Time to back out:** < 15 min. **Decision owner:** change owner.

## 8. Communication plan

| When | Audience | Channel | Message |
|---|---|---|---|
| T-5 days | CAB, Service Desk, Security | ITSM / e-mail | Change scheduled, scope, no user impact |
| T-0 start/end | Change owner, Security | Chat / ITSM | Start / completion / backout |
| T+1 day | Service Desk, endpoint teams | E-mail + KB | Service live; agent onboarding plan; support contacts |
| Ongoing | SOC | SIEM onboarding ticket | Close EXC-03 |

## 9. Success criteria

- [ ] All verify assertions pass; health check `OK`
- [ ] CIS audit pass rate recorded, every failure explained or remediated (target ≥ 95 % of enabled checks, ‹set›)
- [ ] Encrypted backup present off-host; restore test scheduled within 30 days
- [ ] Second run of `site.yml` reports `changed=0`
- [ ] Credentials moved to the password manager and removed from the controller
- [ ] Exceptions EXC-01…07 accepted by the Security Officer
- [ ] Post-implementation review booked (T+14 days)

## 10. Post-implementation review

| Item | Result |
|---|---|
| Implemented as planned? | ‹› |
| Incidents caused? | ‹› |
| Lessons learned | ‹› |
| Close code | ‹Successful / Successful with issues / Backed out› |
