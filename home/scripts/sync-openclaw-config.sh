#!/usr/bin/env bash
# Enforce OpenClaw default model = Grok (xAI) on every ./rebuild.sh.
# Only mutates non-secret preference keys in ~/.openclaw/openclaw.json:
#   agents.defaults.model.primary, agents.defaults.models (xai/* entries),
#   plugins.entries.xai.enabled
# Never writes tokens, gateway auth, Discord credentials, or OAuth profiles.
set -euo pipefail

CFG="${HOME}/.openclaw/openclaw.json"
PRIMARY="xai/grok-4.5"
XAI_MODELS=(
  "xai/grok-4.5"
  "xai/grok-4.3"
  "xai/grok-4.20-0309-reasoning"
)

if [[ ! -f "${CFG}" ]]; then
  echo "sync-openclaw-config: ${CFG} absent - skip (run openclaw onboard first)"
  exit 0
fi

python3 - "${CFG}" "${PRIMARY}" "${XAI_MODELS[@]}" <<'PY'
import json
import sys
from pathlib import Path

cfg_path = Path(sys.argv[1])
primary = sys.argv[2]
xai_models = sys.argv[3:]

cfg = json.loads(cfg_path.read_text())
agents = cfg.setdefault("agents", {})
defaults = agents.setdefault("defaults", {})
models = defaults.setdefault("models", {})
if not isinstance(models, dict):
    models = {}
    defaults["models"] = models
for mid in xai_models:
    models.setdefault(mid, {})

model = defaults.get("model")
if isinstance(model, str):
    defaults["model"] = {"primary": primary}
elif isinstance(model, dict):
    model["primary"] = primary
else:
    defaults["model"] = {"primary": primary}

plugins = cfg.setdefault("plugins", {})
entries = plugins.setdefault("entries", {})
xai = entries.setdefault("xai", {})
if not isinstance(xai, dict):
    xai = {}
    entries["xai"] = xai
xai["enabled"] = True

# Atomic write
tmp = cfg_path.with_suffix(".json.tmp-sync")
tmp.write_text(json.dumps(cfg, indent=2) + "\n")
tmp.replace(cfg_path)
print(f"sync-openclaw-config: primary -> {primary}")
print(f"sync-openclaw-config: plugins.entries.xai.enabled -> true")
print(f"sync-openclaw-config: xai models ensure {', '.join(xai_models)}")
PY
