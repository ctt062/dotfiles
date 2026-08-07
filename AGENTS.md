# Project notes for agents

Read this file before doing any work in this repo.

Before anything else, read and follow the global agent instructions in `home/AGENTS.md` (also available live as `~/.cursor/AGENTS.md`). That file is the shared policy installed for Claude, Codex, Cursor, opencode, and Grok via `home.nix`. Cursor also loads it globally through the `global-agents` local plugin.

## Deliberate decisions

Do not silently revert these:

- `homebrew.onActivation.cleanup = "zap"` in `configuration.nix` is intentional. It forces the good habit of declaring every Homebrew package in the Nix config instead of installing things ad-hoc, which keeps the machine reproducible. Do not soften it to `uninstall` or `none`. Users are warned about its effect in README.md; this note is for anyone tempted to change the setting itself.
- `homebrew.onActivation.upgrade = true` and `greedyCasks = true` are intentional so `./rebuild.sh` upgrades Claude Code, Codex, and other declared Homebrew packages. Do not turn upgrade back off; `autoUpdate` alone only refreshes formulae metadata.
- Never commit `.no-mistakes/` validation evidence to this public repo. `.no-mistakes/` is gitignored; if a validation pipeline stages evidence into a branch, drop it before merging.

## Maintaining this file

Keep this file for knowledge useful to almost every future agent session in this project.
Do not repeat what the codebase already shows; point to the authoritative file or command instead.
Prefer rewriting or pruning existing entries over appending new ones.
Keep global agent policy in `home/AGENTS.md` only - do not duplicate it here.
When updating this file, preserve this bar for all agents and keep entries concise.
