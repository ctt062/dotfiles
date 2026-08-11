#!/usr/bin/env bash
# Re-apply this machine's flake (pinned by flake.lock) and upgrade declared Homebrew tools.
# Does not run `nix flake update` - that would dirty flake.lock on every run.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ln -sfn "$DIR" ~/.dotfiles

echo "==> Switching nix-darwin / home-manager (Homebrew upgrades run during activation)"
exec sudo darwin-rebuild switch --flake "$DIR#mac"
