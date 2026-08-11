#!/usr/bin/env bash
# Deploy the saved agent configuration payloads on every ./rebuild.sh.
# These files are copied, never linked, so normal agent writes cannot mutate
# the versioned payload in this repository.
set -euo pipefail

DOTFILES="${HOME}/.dotfiles"
PAYLOAD_ROOT="${DOTFILES}/home/agent-configs"

deploy() {
  local source="$1"
  local destination="$2"

  if [[ ! -f "${source}" ]]; then
    echo "error: saved agent config is missing: ${source}" >&2
    exit 1
  fi

  mkdir -p "$(dirname "${destination}")"
  if [[ -f "${destination}" ]] && cmp -s "${source}" "${destination}"; then
    echo "agent config unchanged: ${destination}"
    return
  fi

  install -m 600 "${source}" "${destination}"
  echo "agent config deployed: ${destination}"
}

deploy "${PAYLOAD_ROOT}/codex/config.toml" "${HOME}/.codex/config.toml"
deploy "${PAYLOAD_ROOT}/codex/hooks.json" "${HOME}/.codex/hooks.json"
deploy "${PAYLOAD_ROOT}/grok/config.toml" "${HOME}/.grok/config.toml"
