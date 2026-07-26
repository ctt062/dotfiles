# dotfiles

Personal macOS setup for Apple Silicon, managed with nix-darwin and home-manager.
One repo, one rebuild command, reproducible machine config.

Stack highlights:

- **Theme**: Tokyo Night (WezTerm + Neovim)
- **Terminal**: WezTerm (Hack Nerd Font, translucent window)
- **Editor**: Neovim via lazy.nvim
- **Shell**: zsh + starship
- **Agents**: shared `home/AGENTS.md` for Claude, Codex, Cursor, and opencode
- **Multiplexer**: herdr (tmux-style agent workspace)

## What this builds

`./rebuild.sh` applies:

- macOS defaults (dark mode, key repeat, dock, Finder, trackpad)
- Homebrew packages and casks declared in `configuration.nix`
- Nix user packages (ripgrep, fd, fzf, jq, lazygit, Neovim, Hack Nerd Font)
- Shell aliases, starship prompt, git identity
- Live-edited configs under `home/` (Neovim, WezTerm, herdr, agent policy)

Homebrew apps currently declared:

| Brews | Casks |
| --- | --- |
| herdr, gnhf, node, gh, tmux, opencode | wezterm, claude-code, cursor-cli, codex, opensuperwhisper |

## Prerequisites

- Apple Silicon Mac by default (`aarch64-darwin`)
- For Intel, set `nixpkgs.hostPlatform = "x86_64-darwin";` in `configuration.nix`

## Fresh machine

```sh
git clone https://github.com/ctt062/dotfiles.git
cd dotfiles
./bootstrap.sh
```

`bootstrap.sh`:

1. Installs Determinate Nix if needed
2. Symlinks this repo to `~/.dotfiles`
3. Checks that `user` in `flake.nix` matches your macOS username
4. Runs the first `darwin-rebuild switch`

Validate without applying:

```sh
nix flake check --no-build
nix build .#darwinConfigurations.mac.system --dry-run
```

## Daily use

Edit files in this repo, then:

```sh
./rebuild.sh
```

That command:

1. Runs `nix flake update` (latest nixpkgs / nix-darwin / home-manager)
2. Runs `darwin-rebuild switch`
3. Upgrades all declared Homebrew brews/casks (`onActivation.upgrade` + `greedyCasks`)
4. Refreshes extra tools from `home.nix` activation (no-mistakes, treehouse, AXI skills for all agents, firstmate)

Configs under `home/` are symlinked live with `mkOutOfStoreSymlink`, so Neovim / WezTerm / herdr / agent policy edits take effect without a rebuild. Run `./rebuild.sh` when you change packages, system defaults, or `home.nix` / `configuration.nix` / `flake.nix`. Commit `flake.lock` when an update looks good.

## Important knobs

- **Username**: `user = "ctt";` in `flake.nix` (bootstrap can rewrite it)
- **Host label**: `"mac"` must match in `flake.nix`, `rebuild.sh`, and `bootstrap.sh`
- **Homebrew zap**: `homebrew.onActivation.cleanup = "zap"` removes anything not listed in `brews` / `casks`. Add packages you want to keep before switching.
- **Homebrew upgrades**: `onActivation.autoUpdate` only refreshes formulae metadata; `onActivation.upgrade = true` is what actually upgrades Claude Code, Codex, etc.
- **Agent policy**: `home/AGENTS.md` is installed for Claude, Codex, Cursor, and opencode. Cursor also gets a local `global-agents` plugin so the policy is always applied; reload Cursor after the first install.
- **No agent co-authors**: every rebuild runs `home/scripts/sync-cursor-attribution.sh` (Cursor CLI + IDE attribution off), keeps Claude `attribution` empty, and installs global git hooks that strip AI `Co-authored-by` / `Made-with: Cursor` trailers. Soft policy lives in `home/AGENTS.md`.
- **AXI skills**: every rebuild runs `home/scripts/sync-axi-skills.sh` so `gh-axi`, `lavish`, and `no-mistakes` are installed and linked for Claude, Codex, Cursor, and opencode. Agents should prefer AXI over MCP / raw `gh` for those jobs.
- **Shell aliases**: `cc` → claude, `co` → codex, `ca` → cursor-agent, `nm` → no-mistakes (overrides macOS `nm`)

## Repo layout

| Path | Role |
| --- | --- |
| `flake.nix` | Entry point: nixpkgs, nix-darwin, home-manager, nix-homebrew |
| `configuration.nix` | System defaults + Homebrew |
| `home.nix` | User packages, shell, git, starship, symlinks, activation hooks |
| `bootstrap.sh` / `rebuild.sh` | First boot vs daily apply |
| `home/` | Live config (nvim, wezterm, herdr, Claude settings, `AGENTS.md`, Cursor plugin) |
| `AGENTS.md` | Project notes for agents working in this repo |

## Notes

- First `nvim` launch bootstraps lazy.nvim (needs network once).
- Neovim and WezTerm both use Tokyo Night.
- Neovim uses a transparent background on macOS (and Windows / WSL) so it matches the terminal.
