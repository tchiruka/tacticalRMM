#!/usr/bin/env bash
# Create the controller toolchain: .venv (Ansible + linters), pinned Galaxy
# content in .galaxy/, and a checksum-verified gitleaks binary in .venv/bin.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GITLEAKS_VERSION="8.30.1"
cd "${REPO_ROOT}"

if [[ ! -x .venv/bin/python ]]; then
  if command -v uv >/dev/null 2>&1; then
    uv venv --python 3.13 .venv
  else
    python3 -m venv .venv
  fi
fi

if command -v uv >/dev/null 2>&1; then
  uv pip install --python .venv/bin/python -r requirements-dev.txt
else
  .venv/bin/python -m pip install --upgrade pip
  .venv/bin/python -m pip install -r requirements-dev.txt
fi

.venv/bin/ansible-galaxy role install -r requirements.yml -p .galaxy/roles --force
.venv/bin/ansible-galaxy collection install -r requirements.yml -p .galaxy/collections

if [[ ! -x .venv/bin/gitleaks ]]; then
  tmp="$(mktemp -d)"
  trap 'rm -rf "${tmp}"' EXIT
  base="https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}"
  tarball="gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz"
  curl -fsSL -o "${tmp}/${tarball}" "${base}/${tarball}"
  curl -fsSL -o "${tmp}/checksums.txt" "${base}/gitleaks_${GITLEAKS_VERSION}_checksums.txt"
  (cd "${tmp}" && grep " ${tarball}\$" checksums.txt | sha256sum -c -)
  tar -xzf "${tmp}/${tarball}" -C "${tmp}" gitleaks
  install -m 0755 "${tmp}/gitleaks" .venv/bin/gitleaks
fi

echo "Toolchain ready. Activate with: source .venv/bin/activate"
