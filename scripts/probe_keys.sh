#!/usr/bin/env bash
set -euo pipefail
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=${XDG_RUNTIME_DIR}/bus}"

ENGINE="$HOME/.local/share/ibus/engine/amharic/amharic_engine.py"
LOG=/tmp/amharic-keys.log
STATUS=/tmp/amh-status.txt

python3 - "$ENGINE" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
t = p.read_text()
changed = False
if 'KEY keyval=' not in t:
    old = '        def do_process_key_event(self, keyval, keycode, state):  # noqa: N802\n            del keycode  # unused; layout handled by IBus\n            if state & IBus.Modifier_TYPE_RELEASE_MASK:'
    new = '        def do_process_key_event(self, keyval, keycode, state):  # noqa: N802\n            LOG.info("KEY keyval=%s keycode=%s state=%s", keyval, keycode, state)\n            del keycode  # unused; layout handled by IBus\n            if state & IBus.Modifier_TYPE_RELEASE_MASK:'
    if old not in t:
        raise SystemExit('key hook pattern missing')
    t = t.replace(old, new, 1)
    changed = True
needle = '''    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )'''
repl = '''    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
        handlers=[logging.FileHandler("/tmp/amharic-keys.log"), logging.StreamHandler()],
    )'''
if 'amharic-keys.log' not in t and needle in t:
    t = t.replace(needle, repl, 1)
    changed = True
if changed:
    p.write_text(t)
    print('engine patched for key logging')
else:
    print('engine already has key logging')
PY

pkill -f 'amharic_engine.py' || true
sleep 0.6
: > "$LOG"
ibus engine amharic-phonetic
sleep 1.2

{
  echo "engine=$(ibus engine || true)"
  pgrep -af 'amharic_engine.py' || echo 'no process'
  echo '--- log ---'
  cat "$LOG" || true
} | tee "$STATUS"

echo
echo "Now type a few letters in GNOME Text Editor with Amharic selected,"
echo "then run: cat /tmp/amharic-keys.log"
echo "If KEY lines appear, apps reach the engine. If not, keys never reach IBus."
