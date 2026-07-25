#!/usr/bin/env bash
# Re-apply this machine's flake and upgrade declared tools.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ln -sfn "$DIR" ~/.dotfiles

echo "==> Updating flake inputs (nixpkgs, nix-darwin, home-manager, ...)"
nix flake update --flake "$DIR"

echo "==> Switching nix-darwin / home-manager (Homebrew upgrades run during activation)"
exec sudo darwin-rebuild switch --flake "$DIR#mac"
