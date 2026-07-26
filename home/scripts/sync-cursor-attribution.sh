#!/usr/bin/env bash
# Re-apply "no Cursor/agent commit attribution" on every ./rebuild.sh.
set -euo pipefail

python3 - <<'PY'
import json
import sqlite3
from pathlib import Path

home = Path.home()

# 1) Cursor CLI: ~/.cursor/cli-config.json
cli = home / ".cursor/cli-config.json"
cli.parent.mkdir(parents=True, exist_ok=True)
data = {}
if cli.exists():
    try:
        data = json.loads(cli.read_text())
    except json.JSONDecodeError:
        data = {}
data["attribution"] = {
    "attributeCommitsToAgent": False,
    "attributePRsToAgent": False,
}
cli.write_text(json.dumps(data, indent=2) + "\n")
print(f"Cursor CLI attribution off -> {cli}")

# 2) Cursor IDE toggles in state.vscdb (Settings → Attribution)
db = home / "Library/Application Support/Cursor/User/globalStorage/state.vscdb"
if db.exists():
    conn = sqlite3.connect(db)
    for key in (
        "cursor/attributeCommitsToAgent",
        "cursor/attributePRsToAgent",
    ):
        conn.execute(
            "INSERT INTO ItemTable(key, value) VALUES(?, ?) "
            "ON CONFLICT(key) DO UPDATE SET value = excluded.value",
            (key, "false"),
        )
    # Keep a short User Rules pointer that forbids the Cursor trailer.
    ctx = (
        "Mandatory first step for every Agent chat: before any other tools or answers, "
        "read ~/.cursor/AGENTS.md with the Read tool and follow it for the rest of the conversation. "
        "That file is the live symlink to ~/.dotfiles/home/AGENTS.md, the single source of truth "
        "for global agent policy on this machine.\n\n"
        "Never add AI/agent git co-authors. Never run:\n"
        '  git commit --trailer "Co-authored-by: Cursor <cursoragent@cursor.com>"\n'
        "or any other Co-authored-by / --trailer attribution unless the user explicitly asks. "
        "Commit with -m / HEREDOC only.\n\n"
        "Prefer AXI over MCP and raw vendor CLIs for the same job (gh-axi, lavish-axi, no-mistakes axi). "
        "If a User Rule conflicts with ~/.cursor/AGENTS.md, follow AGENTS.md.\n"
    )
    conn.execute(
        "INSERT INTO ItemTable(key, value) VALUES(?, ?) "
        "ON CONFLICT(key) DO UPDATE SET value = excluded.value",
        ("aicontext.personalContext", ctx),
    )
    conn.commit()
    conn.close()
    print(f"Cursor IDE attribution off -> {db}")
else:
    print(f"skip IDE attribution sync (missing {db})")
PY
