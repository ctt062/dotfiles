#!/usr/bin/env bash
# Enforce preferred no-mistakes pipeline agents on every ./rebuild.sh.
# Invoked from home.nix after the no-mistakes binary install.
#
# Preference (ordered fallback):
#   1. Grok (xAI) via acpx acp:grok-build
#   2. Cursor (ACP alias)
#   3. Claude, Codex, OpenCode, Pi
#
# Only rewrites the agent: line and ensures acpx_path. Other keys in
# ~/.no-mistakes/config.yaml are left alone. If the file is missing, seeds a
# minimal config with the preferred agent list.
set -euo pipefail

CFG="${HOME}/.no-mistakes/config.yaml"
AGENT_VALUE='[acp:grok-build, cursor, claude, codex, opencode, pi]'
AGENT_LINE="agent: ${AGENT_VALUE}"
ACPX_PATH_DEFAULT="/opt/homebrew/bin/acpx"

mkdir -p "${HOME}/.no-mistakes"

if [[ ! -f "${CFG}" ]]; then
  echo "Seeding ${CFG} with preferred agent list..."
  cat > "${CFG}" <<SEED
# no-mistakes global configuration
# Managed agent preference is re-applied by home/scripts/sync-no-mistakes-config.sh on every rebuild.

# Ordered fallback list. Grok is not a native no-mistakes agent; use acp:grok-build.
# cursor is an ACP alias for cursor-agent via acpx.
agent: ${AGENT_VALUE}

# Optional path to the user-installed acpx binary for acp:<target> agents
acpx_path: ${ACPX_PATH_DEFAULT}
SEED
  echo "wrote ${CFG}"
  exit 0
fi

tmp="$(mktemp)"
trap 'rm -f "${tmp}"' EXIT

# Rewrite existing agent: line(s), or insert after the first comment/header block.
python3 - "${CFG}" "${tmp}" "${AGENT_LINE}" "${ACPX_PATH_DEFAULT}" <<'PY'
import re
import sys
from pathlib import Path

src, dst, agent_line, acpx_default = sys.argv[1:5]
text = Path(src).read_text()
lines = text.splitlines(keepends=True)

agent_re = re.compile(r"^[ \t]*agent[ \t]*:")
acpx_re = re.compile(r"^[ \t]*acpx_path[ \t]*:")

out = []
saw_agent = False
saw_acpx = False
for line in lines:
    if agent_re.match(line):
        if not saw_agent:
            out.append(agent_line + ("\n" if not agent_line.endswith("\n") else ""))
            saw_agent = True
        # drop duplicate agent lines
        continue
    if acpx_re.match(line):
        saw_acpx = True
    out.append(line)

if not saw_agent:
    # Insert near the top after leading comments / blank lines
    insert_at = 0
    for i, line in enumerate(out):
        if line.startswith("#") or line.strip() == "":
            insert_at = i + 1
            continue
        break
    out.insert(insert_at, agent_line + "\n")
    if insert_at < len(out) and out[insert_at + 1 : insert_at + 2] and out[insert_at + 1].strip() != "":
        out.insert(insert_at + 1, "\n")

if not saw_acpx:
    # After agent line if possible
    insert_at = 0
    for i, line in enumerate(out):
        if agent_re.match(line):
            insert_at = i + 1
            break
    block = f"\nacpx_path: {acpx_default}\n"
    out.insert(insert_at, block)

Path(dst).write_text("".join(out))
print(f"synced agent preference -> {agent_line.strip()}")
if not saw_acpx:
    print(f"added acpx_path: {acpx_default}")
PY

mv -f "${tmp}" "${CFG}"
trap - EXIT

# Show the effective agent line for activation logs
grep -E '^[ \t]*agent[ \t]*:' "${CFG}" || true
