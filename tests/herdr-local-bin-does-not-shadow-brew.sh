#!/usr/bin/env bash
# Behavioral regression: after home.activation.installExtraTools, PATH must
# resolve herdr to the Homebrew binary, not a leftover ~/.local/bin/herdr.
#
# home.nix puts $HOME/.local/bin first for no-mistakes/treehouse, so a stale
# local herdr would shadow brew upgrades from configuration.nix.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }

NIX_BIN="$(command -v nix)" || fail "nix not on PATH"
# Real consumer: evaluate the activation script Home Manager will run.
activation_data="$(
  "$NIX_BIN" eval --impure --raw \
    "${ROOT}#darwinConfigurations.mac.config.home-manager.users.ctt.home.activation.installExtraTools.data"
)"

work="$(mktemp -d "${TMPDIR:-/tmp}/herdr-path.XXXXXX")"
trap 'rm -rf "$work"' EXIT

mkdir -p "$work/home/.local/bin" "$work/brew/bin"
printf '#!/bin/sh\necho local-herdr\n' >"$work/home/.local/bin/herdr"
printf '#!/bin/sh\necho brew-herdr\n' >"$work/brew/bin/herdr"
chmod +x "$work/home/.local/bin/herdr" "$work/brew/bin/herdr"

# Mirror interactive zsh: .local/bin before Homebrew.
export HOME="$work/home"
export PATH="$HOME/.local/bin:$work/brew/bin:/usr/bin:/bin"

before="$(command -v herdr)"
before_out="$(herdr)"
[[ "$before" == "$HOME/.local/bin/herdr" && "$before_out" == "local-herdr" ]] \
  || fail "setup: expected local shadow before clear (got $before / $before_out)"
echo "Reproduced shadow: $before -> $before_out"

# Run only the prefix through herdr cleanup; do not execute curl installers.
prefix="$(
  printf '%s\n' "$activation_data" | awk '/Updating no-mistakes/{exit} {print}'
)"

bash -c "$prefix"

after="$(command -v herdr)"
after_out="$(herdr)"
[[ "$after" == "$work/brew/bin/herdr" && "$after_out" == "brew-herdr" ]] \
  || fail "expected Homebrew herdr after activation (got $after / $after_out)"
[[ ! -e "$HOME/.local/bin/herdr" ]] \
  || fail "$HOME/.local/bin/herdr still present after activation"

pass "activation clears ~/.local/bin/herdr; Homebrew herdr wins on PATH"
