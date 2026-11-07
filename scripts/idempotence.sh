#!/usr/bin/env bash
# Idempotence gate: run a playbook twice; the second run must report
# changed=0 for every host. Use on a throwaway VM / snapshot, not production.
#   scripts/idempotence.sh [playbook] [extra ansible-playbook args]
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"
[[ -d .venv/bin ]] && PATH="${REPO_ROOT}/.venv/bin:${PATH}"

playbook="${1:-playbooks/site.yml}"
shift || true
log="$(mktemp)"
trap 'rm -f "${log}"' EXIT

echo "==> first run: ${playbook}"
ansible-playbook "${playbook}" -e site_run_audits=false "$@"

echo "==> second run (must not change anything)"
ANSIBLE_DISPLAY_OK_HOSTS=false ansible-playbook "${playbook}" -e site_run_audits=false "$@" | tee "${log}"

if grep -E 'changed=[1-9]' "${log}" >/dev/null; then
  echo "IDEMPOTENCE FAILED - tasks that changed on the second run:"
  grep -B1 -E '^changed:' "${log}" | grep -E '^TASK' || true
  exit 1
fi
echo "Idempotence OK: second run reported changed=0."
