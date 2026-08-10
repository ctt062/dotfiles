#!/usr/bin/env bash
# Enforce firstmate crewmate harness = grok on every ./rebuild.sh.
# Writes only config/crew-harness (gitignored local preference). Does not
# touch project clones under projects/ or shared tracked firstmate files.
set -euo pipefail

CREW_VALUE="grok"
CANDIDATES=(
  "${HOME}/firstmate"
  "${HOME}/github/firstmate"
  "${HOME}/.dotfiles/../firstmate"
)

# Resolve real paths; de-dupe
declare -a HOMES=()
seen=""
for raw in "${CANDIDATES[@]}"; do
  [[ -d "$raw" ]] || continue
  # firstmate home: has config/ or bin/fm-spawn.sh or AGENTS.md
  if [[ ! -f "$raw/bin/fm-spawn.sh" && ! -f "$raw/AGENTS.md" && ! -d "$raw/config" ]]; then
    continue
  fi
  real=$(CDPATH='' cd -- "$raw" && pwd -P) || continue
  case " $seen " in
    *" $real "*) continue ;;
  esac
  seen+=" $real"
  HOMES+=("$real")
done

# Also pick up FM_HOME if set and looks like a firstmate home
if [[ -n "${FM_HOME:-}" && -d "${FM_HOME}" ]]; then
  if [[ -f "${FM_HOME}/bin/fm-spawn.sh" || -f "${FM_HOME}/AGENTS.md" || -d "${FM_HOME}/config" ]]; then
    real=$(CDPATH='' cd -- "${FM_HOME}" && pwd -P) || true
    if [[ -n "${real:-}" ]]; then
      case " $seen " in
        *" $real "*) ;;
        *) HOMES+=("$real"); seen+=" $real" ;;
      esac
    fi
  fi
fi

if [[ ${#HOMES[@]} -eq 0 ]]; then
  echo "sync-firstmate-config: no firstmate home found yet (ok on first clone; re-run rebuild after firstmate lands)"
  exit 0
fi

for home in "${HOMES[@]}"; do
  mkdir -p "${home}/config"
  printf '%s\n' "${CREW_VALUE}" > "${home}/config/crew-harness"
  # Ensure readable by agent processes
  chmod 644 "${home}/config/crew-harness" 2>/dev/null || true
  echo "sync-firstmate-config: ${home}/config/crew-harness -> ${CREW_VALUE}"
done
