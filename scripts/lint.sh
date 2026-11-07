#!/usr/bin/env bash
# Run every static quality gate: yamllint, ansible-lint, shellcheck,
# ansible-playbook --syntax-check and gitleaks. Exits non-zero on any failure.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

if [[ -d .venv/bin ]]; then
  PATH="${REPO_ROOT}/.venv/bin:${PATH}"
fi

rc=0
step() { printf '\n==> %s\n' "$*"; }

step "yamllint"
yamllint --strict . || rc=1

step "ansible-lint"
ansible-lint || rc=1

step "shellcheck"
mapfile -t shell_files < <(git ls-files '*.sh' 'roles/*/templates/*.sh.j2' 2>/dev/null || true)
if ((${#shell_files[@]})); then
  # Jinja templates are rendered with sample values before checking.
  for f in "${shell_files[@]}"; do
    if [[ "${f}" == *.j2 ]]; then
      sed -E 's/\{\{[^}]*\}\}/PLACEHOLDER/g; /\{%.*%\}/d; s/\{#.*#\}//g' "${f}" |
        shellcheck --severity=style --shell=bash - || { echo "  in ${f}"; rc=1; }
    else
      shellcheck --severity=style "${f}" || rc=1
    fi
  done
fi

step "ansible-playbook --syntax-check"
# Syntax-check needs an inventory; use the committed example.
for pb in playbooks/*.yml; do
  ansible-playbook -i inventory/hosts.example.yml --syntax-check "${pb}" >/dev/null || {
    echo "syntax-check failed: ${pb}"
    rc=1
  }
done
echo "syntax-check done"

step "gitleaks (working tree + history)"
if command -v gitleaks >/dev/null 2>&1; then
  gitleaks dir --redact --no-banner . || rc=1
  if git rev-parse --verify HEAD >/dev/null 2>&1; then
    gitleaks git --redact --no-banner . || rc=1
  fi
else
  echo "gitleaks not found (run scripts/bootstrap-dev.sh)"
  rc=1
fi

if ((rc == 0)); then
  printf '\nAll quality gates passed.\n'
else
  printf '\nOne or more quality gates FAILED.\n'
fi
exit "${rc}"
