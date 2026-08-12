#!/usr/bin/env bash
# Behavioral test: sync-agent-skills.sh installs declared packages via the
# skills CLI and force-links them into every agent global skills dir.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SCRIPT="${ROOT}/home/scripts/sync-agent-skills.sh"

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }

grep -q 'home/scripts/sync-agent-skills.sh' "${ROOT}/home.nix" \
  || fail "home.nix must invoke sync-agent-skills.sh on activation"
grep -q 'kepano/obsidian-skills' "$SCRIPT" \
  || fail "sync-agent-skills.sh must install kepano/obsidian-skills"
pass "rebuild activation still installs kepano/obsidian-skills"

EXPECTED_SKILLS=(
  gh-axi lavish no-mistakes
  defuddle json-canvas obsidian-bases obsidian-cli obsidian-markdown
)
AGENT_REL_DIRS=(
  ".claude/skills"
  ".codex/skills"
  ".cursor/skills"
  ".config/opencode/skills"
  ".grok/skills"
)

work="$(mktemp -d "${TMPDIR:-/tmp}/sync-agent-skills.XXXXXX")"
trap 'rm -rf "$work"' EXIT

mkdir -p "$work/bin" "$work/home" "$work/calls"
CALL_LOG="$work/calls.log"
: >"$CALL_LOG"

cat >"$work/bin/npm" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'NPM %s\n' "$*" >>"${CALL_LOG:?}"
exit 0
EOF

cat >"$work/bin/npx" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'NPX %s\n' "$*" >>"${CALL_LOG:?}"

# npx --yes skills add <package> --skill <name|' * '> ...
package=""
skills=()
prev=""
for arg in "$@"; do
  if [[ "$prev" == "add" ]]; then
    package="$arg"
  elif [[ "$prev" == "--skill" || "$prev" == "-s" ]]; then
    skills+=("$arg")
  fi
  prev="$arg"
done

if [[ -z "$package" ]]; then
  echo "fake npx: missing package" >&2
  exit 2
fi

expand_skills() {
  case "$1" in
    kunchenguid/gh-axi) printf '%s\n' gh-axi ;;
    kunchenguid/lavish-axi) printf '%s\n' lavish ;;
    kunchenguid/no-mistakes) printf '%s\n' no-mistakes ;;
    kepano/obsidian-skills)
      printf '%s\n' defuddle json-canvas obsidian-bases obsidian-cli obsidian-markdown
      ;;
    *)
      echo "fake npx: unknown package $1" >&2
      return 2
      ;;
  esac
}

canonical="${HOME}/.agents/skills"
mkdir -p "$canonical"
for requested in "${skills[@]}"; do
  if [[ "$requested" == "*" ]]; then
    names="$(expand_skills "$package")"
  else
    names="$requested"
  fi
  for name in $names; do
    mkdir -p "${canonical}/${name}"
    printf '# %s\n' "$name" >"${canonical}/${name}/SKILL.md"
  done
done
exit 0
EOF

chmod +x "$work/bin/npm" "$work/bin/npx"

echo "==> Running sync-agent-skills.sh against mocked npm/npx"
HOME="$work/home" PATH="$work/bin:/usr/bin:/bin" CALL_LOG="$CALL_LOG" \
  bash "$SCRIPT" >"$work/stdout.log" 2>"$work/stderr.log" || {
  echo "--- stdout ---"
  cat "$work/stdout.log"
  echo "--- stderr ---"
  cat "$work/stderr.log"
  fail "sync-agent-skills.sh exited non-zero"
}

echo "--- stdout ---"
cat "$work/stdout.log"
echo "--- calls ---"
cat "$CALL_LOG"

grep -q 'NPM install -g gh-axi lavish-axi' "$CALL_LOG" \
  || fail "expected npm install of AXI CLIs"
grep -q 'NPX --yes skills add kunchenguid/gh-axi' "$CALL_LOG" \
  || fail "expected skills add for gh-axi"
grep -q 'NPX --yes skills add kunchenguid/lavish-axi' "$CALL_LOG" \
  || fail "expected skills add for lavish-axi"
grep -q 'NPX --yes skills add kunchenguid/no-mistakes' "$CALL_LOG" \
  || fail "expected skills add for no-mistakes"
grep -Fq 'NPX --yes skills add kepano/obsidian-skills --skill *' "$CALL_LOG" \
  || fail "expected skills add for kepano/obsidian-skills with --skill *"
pass "declared skill packages are installed globally"

for skill in "${EXPECTED_SKILLS[@]}"; do
  src="$work/home/.agents/skills/${skill}"
  [[ -f "${src}/SKILL.md" ]] || fail "canonical skill missing: ${src}/SKILL.md"
  for rel in "${AGENT_REL_DIRS[@]}"; do
    target="$work/home/${rel}/${skill}"
    [[ -L "$target" ]] || fail "expected symlink: $target"
    [[ -f "${target}/SKILL.md" ]] || fail "broken skill link: $target"
    resolved="$(readlink "$target")"
    [[ "$resolved" == "$src" ]] || fail "link $target -> $resolved, expected $src"
  done
done
pass "AXI + Obsidian skills are linked for Claude, Codex, Cursor, opencode, and Grok"

grep -q 'Agent skills ready' "$work/stdout.log" \
  || fail "expected success banner"
pass "sync-agent-skills.sh completed"

echo
echo "All sync-agent-skills.sh checks passed."
