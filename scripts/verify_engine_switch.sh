#!/usr/bin/env bash
set -euo pipefail
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=${XDG_RUNTIME_DIR}/bus}"

ENGINE="$HOME/.local/share/ibus/engine/amharic/amharic_engine.py"
LOG="/tmp/amharic-engine-verify.log"
: > "$LOG"

{
  echo "=== sources ==="
  gsettings get org.gnome.desktop.input-sources sources
  echo "=== current ==="
  gsettings get org.gnome.desktop.input-sources current
  echo "=== ibus before ==="
  ibus engine || true

  pkill -f 'amharic_engine.py' 2>/dev/null || true
  sleep 0.5

  echo "=== register ==="
  python3 "$HOME/.local/share/ibus/engine/amharic/register_component.py" || true

  echo "=== activation test ==="
  python3 - "$ENGINE" <<'PY'
import gi, os, subprocess, time, signal, sys
gi.require_version("IBus", "1.0")
from gi.repository import IBus
IBus.init()
engine = sys.argv[1]
p = subprocess.Popen(
    ["python3", engine, "--ibus"],
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT,
    text=True,
)
time.sleep(1.2)
print("alive_before", p.poll())
bus = IBus.Bus()
print("connected", bus.is_connected())
print("set_amharic", bus.set_global_engine("amharic-phonetic"))
time.sleep(0.8)
print("alive_after", p.poll())
ge = bus.get_global_engine()
print("engine_now", ge.get_name() if ge else None)
print("set_english", bus.set_global_engine("xkb:us::eng"))
time.sleep(0.3)
ge = bus.get_global_engine()
print("engine_now", ge.get_name() if ge else None)
if p.poll() is None:
    p.send_signal(signal.SIGTERM)
out, _ = p.communicate(timeout=3)
print("--- engine log ---")
print(out[-2500:] if out else "(empty)")
PY

  gsettings set org.gnome.desktop.input-sources current 0
  ibus engine xkb:us::eng || true
  echo "=== ibus after ==="
  ibus engine || true
} 2>&1 | tee "$LOG"

echo "Wrote $LOG"
