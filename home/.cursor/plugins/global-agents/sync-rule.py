#!/usr/bin/env python3
"""Sync Cursor alwaysApply rule snapshot from home/AGENTS.md."""

from __future__ import annotations

import pathlib
import sys

HEADER = """\
---
description: Global agent instructions from home/AGENTS.md - always apply; read live file before any work
alwaysApply: true
---

# Mandatory first step

Before any other tools or answers, read `~/.cursor/AGENTS.md` with the Read tool and follow it for the rest of this conversation.

That path is a symlink to `~/.dotfiles/home/AGENTS.md`, the single source of truth for global agent policy on this machine. If the live file differs from the snapshot below, the live file wins.

# Snapshot of home/AGENTS.md

"""


def main() -> int:
    if len(sys.argv) != 3:
        print(f"usage: {sys.argv[0]} <AGENTS.md> <global-agent-instructions.mdc>", file=sys.stderr)
        return 2
    src = pathlib.Path(sys.argv[1])
    dst = pathlib.Path(sys.argv[2])
    body = src.read_text().rstrip() + "\n"
    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_text(HEADER + body)
    print(f"Synced Cursor global-agents rule from {src}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
