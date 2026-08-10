#!/usr/bin/env bash
# Uninstall Amharic Phonetic IBus engine for the current user.
set -euo pipefail

PURGE=0
if [[ "${1:-}" == "--purge" ]]; then
  PURGE=1
fi

IBUS_COMPONENT="${HOME}/.local/share/ibus/component/amharic.xml"
IBUS_ENGINE_DIR="${HOME}/.local/share/ibus/engine/amharic"
CONFIG_DIR="${HOME}/.config/amharic-ibus"

echo "==> Removing IBus component and engine"
rm -f "${IBUS_COMPONENT}"
rm -rf "${IBUS_ENGINE_DIR}"
rm -f "${HOME}/.config/autostart/amharic-ibus-register.desktop"

if ((PURGE)); then
  echo "==> Removing config (--purge)"
  rm -rf "${CONFIG_DIR}"
else
  echo "==> Keeping ${CONFIG_DIR} (pass --purge to delete)"
fi

# Rebuild registry without our component
python3 - <<'PY' 2>/dev/null || true
import os, gi
gi.require_version("IBus", "1.0")
from gi.repository import IBus
IBus.init()
reg = IBus.Registry()
reg.load()
user = os.path.expanduser("~/.local/share/ibus/component")
if os.path.isdir(user):
    reg.load_in_dir(user)
cache = os.path.expanduser("~/.cache/ibus/bus/registry")
os.makedirs(os.path.dirname(cache), exist_ok=True)
reg.save_cache_file(cache)
PY

ibus restart 2>/dev/null || true

echo "Uninstalled. Remove the input source from Settings → Keyboard if it still appears."
