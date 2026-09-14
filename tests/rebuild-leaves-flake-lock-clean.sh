#!/usr/bin/env bash
# Behavioral regression: ./rebuild.sh must apply the pinned flake without
# running `nix flake update`, so flake.lock stays unchanged.
#
# Reproduces the pre-fix failure with the old script, then asserts the
# current rebuild.sh keeps flake.lock clean while still invoking darwin-rebuild.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
BASE_COMMIT="${BASE_COMMIT:-1c5c64d1409a90b6afd9a49fbb5fa5d4e19cfd29}"

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }

setup_fakes() {
  local work="$1"
  mkdir -p "$work/bin" "$work/home"

  cat >"$work/bin/nix" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'NIX %s\n' "$*" >>"${CALL_LOG:?}"
if [[ "${1:-}" == "flake" && "${2:-}" == "update" ]]; then
  flake_ref=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --flake)
        flake_ref="${2:-}"
        shift 2
        ;;
      *)
        shift
        ;;
    esac
  done
  if [[ -z "$flake_ref" ]]; then
    echo "fake nix: flake update missing --flake" >&2
    exit 2
  fi
  # Simulate upstream bump dirtying the lockfile in the flake directory.
  printf '\n# simulated nix flake update\n' >>"${flake_ref}/flake.lock"
fi
EOF

  cat >"$work/bin/sudo" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'SUDO %s\n' "$*" >>"${CALL_LOG:?}"
exec "$@"
EOF

  cat >"$work/bin/darwin-rebuild" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'DARWIN_REBUILD %s\n' "$*" >>"${CALL_LOG:?}"
exit 0
EOF

  chmod +x "$work/bin/nix" "$work/bin/sudo" "$work/bin/darwin-rebuild"
}

run_rebuild() {
  local script_src="$1"
  local label="$2"
  local work
  work="$(mktemp -d "${TMPDIR:-/tmp}/rebuild-test.${label}.XXXXXX")"
  setup_fakes "$work"

  mkdir -p "$work/repo"
  cp "$script_src" "$work/repo/rebuild.sh"
  chmod +x "$work/repo/rebuild.sh"
  # Minimal lockfile standing in for the real pinned flake.lock contract.
  printf '%s\n' '{"nodes":{},"root":"root","version":7}' >"$work/repo/flake.lock"
  local before after
  before="$(shasum -a 256 "$work/repo/flake.lock" | awk '{print $1}')"

  local call_log="$work/calls.log"
  : >"$call_log"

  # Isolate HOME so ~/.dotfiles lands in the temp workdir, not the real home.
  CALL_LOG="$call_log" HOME="$work/home" PATH="$work/bin:$PATH" \
    bash "$work/repo/rebuild.sh" >"$work/stdout.log" 2>"$work/stderr.log"

  after="$(shasum -a 256 "$work/repo/flake.lock" | awk '{print $1}')"
  printf 'BEFORE_HASH=%s\n' "$before" >"$work/result.env"
  printf 'AFTER_HASH=%s\n' "$after" >>"$work/result.env"
  # Emit only the workdir path on stdout for the caller to capture.
  printf '%s\n' "$work"
}

echo "==> Reproducing pre-fix dirty flake.lock with base rebuild.sh ($BASE_COMMIT)"
old_script="$(mktemp "${TMPDIR:-/tmp}/rebuild.old.XXXXXX")"
git -C "$ROOT" show "${BASE_COMMIT}:rebuild.sh" >"$old_script"
old_work="$(run_rebuild "$old_script" old)"
# shellcheck disable=SC1090,SC1091
source "$old_work/result.env"
old_calls="$(cat "$old_work/calls.log")"
echo "--- old stdout ---"
cat "$old_work/stdout.log"
echo "--- old stderr ---"
cat "$old_work/stderr.log"
echo "--- old calls ---"
printf '%s\n' "$old_calls"
echo "--- old flake.lock hashes ---"
echo "before=$BEFORE_HASH"
echo "after=$AFTER_HASH"

grep -q 'NIX flake update' <<<"$old_calls" || fail "expected old script to call nix flake update"
grep -q 'DARWIN_REBUILD switch' <<<"$old_calls" || fail "expected old script to call darwin-rebuild switch"
[[ "$BEFORE_HASH" != "$AFTER_HASH" ]] || fail "expected old script to dirty flake.lock (regression baseline)"
pass "old rebuild.sh dirtied flake.lock via nix flake update"

echo
echo "==> Verifying fixed rebuild.sh keeps flake.lock clean"
new_work="$(run_rebuild "$ROOT/rebuild.sh" new)"
# shellcheck disable=SC1090,SC1091
source "$new_work/result.env"
new_calls="$(cat "$new_work/calls.log")"
echo "--- new stdout ---"
cat "$new_work/stdout.log"
echo "--- new stderr ---"
cat "$new_work/stderr.log"
echo "--- new calls ---"
printf '%s\n' "$new_calls"
echo "--- new flake.lock hashes ---"
echo "before=$BEFORE_HASH"
echo "after=$AFTER_HASH"

if grep -q 'NIX flake update' <<<"$new_calls"; then
  fail "fixed rebuild.sh must not call nix flake update"
fi
grep -q 'DARWIN_REBUILD switch' <<<"$new_calls" || fail "fixed rebuild.sh must still call darwin-rebuild switch"
grep -q '#mac' <<<"$new_calls" || fail "fixed rebuild.sh must target flake #mac"
[[ "$BEFORE_HASH" == "$AFTER_HASH" ]] || fail "fixed rebuild.sh left flake.lock modified"
grep -q 'Switching nix-darwin' "$new_work/stdout.log" || fail "expected switch banner in rebuild output"
pass "fixed rebuild.sh switches without dirtying flake.lock"

echo
echo "==> Confirming Homebrew upgrades remain enabled via nix-darwin config eval"
upgrade_val="$(nix eval --impure -- "$ROOT#darwinConfigurations.mac.config.homebrew.onActivation.upgrade")"
echo "nix eval homebrew.onActivation.upgrade => $upgrade_val"
[[ "$upgrade_val" == "true" ]] || fail "expected homebrew.onActivation.upgrade == true, got: $upgrade_val"
pass "Homebrew onActivation.upgrade stays enabled"

echo
echo "All rebuild.sh flake.lock cleanliness checks passed."
printf 'OLD_WORK=%s\n' "$old_work"
printf 'NEW_WORK=%s\n' "$new_work"
