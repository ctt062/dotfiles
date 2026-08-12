#!/usr/bin/env bash
# Install declared global agent skills, then link them into every agent global skills dir.
# Invoked from home.nix on every ./rebuild.sh (darwin-rebuild / home-manager switch).
set -euo pipefail

CANONICAL="${HOME}/.agents/skills"
AXI_SKILLS=(gh-axi lavish no-mistakes)
OBSIDIAN_SKILLS=(defuddle json-canvas obsidian-bases obsidian-cli obsidian-markdown)
ALL_SKILLS=("${AXI_SKILLS[@]}" "${OBSIDIAN_SKILLS[@]}")
AGENT_SKILL_DIRS=(
  "${HOME}/.claude/skills"
  "${HOME}/.codex/skills"
  "${HOME}/.cursor/skills"
  "${HOME}/.config/opencode/skills"
  "${HOME}/.grok/skills"
)
SKILLS_AGENTS=(-a claude-code -a cursor -a codex -a opencode)

if ! command -v npm >/dev/null 2>&1; then
  echo "error: npm not on PATH; cannot sync agent skills" >&2
  exit 1
fi

echo "Updating gh-axi and lavish-axi CLIs..."
npm install -g gh-axi lavish-axi

echo "Installing AXI skills into ${CANONICAL}..."
# skills CLI treats Cursor/Codex/OpenCode as "universal" (~/.agents/skills) and only
# symlinks Claude. We still target the listed agents so metadata stays correct, then force
# per-agent links below so each agent globalSkillsDir actually has the skills.
npx --yes skills add kunchenguid/gh-axi --skill gh-axi -y -g "${SKILLS_AGENTS[@]}"
npx --yes skills add kunchenguid/lavish-axi --skill lavish -y -g "${SKILLS_AGENTS[@]}"
npx --yes skills add kunchenguid/no-mistakes --skill no-mistakes -y -g "${SKILLS_AGENTS[@]}"

echo "Installing Obsidian skills into ${CANONICAL}..."
npx --yes skills add kepano/obsidian-skills --skill '*' -y -g "${SKILLS_AGENTS[@]}"

echo "Linking skills into agent skill directories..."
missing=0
for skill in "${ALL_SKILLS[@]}"; do
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

echo "Verifying skill links..."
for skill in "${ALL_SKILLS[@]}"; do
  for dest in "${AGENT_SKILL_DIRS[@]}"; do
    target="${dest}/${skill}"
    if [[ ! -L "${target}" || ! -f "${target}/SKILL.md" ]]; then
      echo "error: skill link broken: ${target}" >&2
      exit 1
    fi
  done
done

echo "Agent skills ready for Claude, Codex, Cursor, opencode, and Grok."
