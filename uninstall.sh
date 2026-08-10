#!/usr/bin/env bash
# Uninstall Amharic Phonetic IBus engine for the current user.
set -euo pipefail

PURGE=0
case "${1:-}" in
  --purge) PURGE=1 ;;
  -h|--help)
    cat <<EOF
Uninstall Amharic Phonetic IBus engine (user install).

  ./uninstall.sh          Remove engine + component (keep config)
  ./uninstall.sh --purge  Also delete ~/.config/amharic-ibus
EOF
    exit 0
    ;;
  "") ;;
  *) echo "Unknown option: $1" >&2; exit 2 ;;
esac

IBUS_COMPONENT="${HOME}/.local/share/ibus/component/amharic.xml"
IBUS_ENGINE_DIR="${HOME}/.local/share/ibus/engine/amharic"
CONFIG_DIR="${HOME}/.config/amharic-ibus"

echo "==> Removing IBus component and engine"
rm -f "${IBUS_COMPONENT}"
rm -rf "${IBUS_ENGINE_DIR}"
rm -f "${HOME}/.config/autostart/amharic-ibus-register.desktop"

# Drop from GNOME input sources if present
if command -v gsettings >/dev/null 2>&1 \
  && gsettings list-schemas 2>/dev/null | grep -qx 'org.gnome.desktop.input-sources'; then
  echo "==> Removing from GNOME input sources"
  python3 - <<'PY' 2>/dev/null || true
import subprocess, ast
raw = subprocess.check_output(
    ["gsettings", "get", "org.gnome.desktop.input-sources", "sources"],
    text=True,
).strip()
try:
    sources = [s for s in ast.literal_eval(raw) if s != ("ibus", "amharic-phonetic")]
except Exception:
    sources = [("xkb", "us")]
if not sources:
    sources = [("xkb", "us")]
fmt = "[" + ", ".join(f"('{a}', '{b}')" for a, b in sources) + "]"
subprocess.check_call(
    ["gsettings", "set", "org.gnome.desktop.input-sources", "sources", fmt]
)
subprocess.call(
    ["gsettings", "set", "org.gnome.desktop.input-sources", "current", "0"]
)
print("    sources =", fmt)
PY
fi

if ((PURGE)); then
  echo "==> Removing config (--purge)"
  rm -rf "${CONFIG_DIR}"
else
  echo "==> Keeping ${CONFIG_DIR} (pass --purge to delete)"
fi

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

echo "✓ Uninstalled. Log out/in if the old source still appears in the top bar."
