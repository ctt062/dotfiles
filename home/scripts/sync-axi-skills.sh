#!/usr/bin/env bash
# Install AXI CLIs + skills, then link them into every agent global skills dir.
# Invoked from home.nix on every ./rebuild.sh (darwin-rebuild / home-manager switch).
set -euo pipefail

CANONICAL="${HOME}/.agents/skills"
AXI_SKILLS=(gh-axi lavish no-mistakes)
AGENT_SKILL_DIRS=(
  "${HOME}/.claude/skills"
  "${HOME}/.codex/skills"
  "${HOME}/.cursor/skills"
  "${HOME}/.config/opencode/skills"
  "${HOME}/.grok/skills"
)

if ! command -v npm >/dev/null 2>&1; then
  echo "error: npm not on PATH; cannot sync AXI skills" >&2
  exit 1
fi

echo "Updating gh-axi and lavish-axi CLIs..."
npm install -g gh-axi lavish-axi

echo "Installing AXI skills into ${CANONICAL}..."
# skills CLI treats Cursor/Codex/OpenCode as "universal" (~/.agents/skills) and only
# symlinks Claude. We still target the listed agents so metadata stays correct, then force
# per-agent links below so each agent globalSkillsDir actually has the skills.
npx --yes skills add kunchenguid/gh-axi --skill gh-axi -y -g \
  -a claude-code -a cursor -a codex -a opencode
npx --yes skills add kunchenguid/lavish-axi --skill lavish -y -g \
  -a claude-code -a cursor -a codex -a opencode
npx --yes skills add kunchenguid/no-mistakes --skill no-mistakes -y -g \
  -a claude-code -a cursor -a codex -a opencode

echo "Linking AXI skills into agent skill directories..."
missing=0
for skill in "${AXI_SKILLS[@]}"; do
  src="${CANONICAL}/${skill}"
  if [[ ! -f "${src}/SKILL.md" ]]; then
    echo "error: canonical skill missing: ${src}/SKILL.md" >&2
    missing=1
    continue
  fi
  for dest in "${AGENT_SKILL_DIRS[@]}"; do
    mkdir -p "${dest}"
    target="${dest}/${skill}"
    if [[ -e "${target}" && ! -L "${target}" ]]; then
      rm -rf "${target}"
    fi
    ln -sfn "${src}" "${target}"
  done
done

if [[ "${missing}" -ne 0 ]]; then
  exit 1
fi

echo "Verifying AXI skill links..."
for skill in "${AXI_SKILLS[@]}"; do
  for dest in "${AGENT_SKILL_DIRS[@]}"; do
    target="${dest}/${skill}"
    if [[ ! -L "${target}" || ! -f "${target}/SKILL.md" ]]; then
      echo "error: skill link broken: ${target}" >&2
      exit 1
    fi
  done
done

echo "AXI skills ready for Claude, Codex, Cursor, opencode, and Grok."
