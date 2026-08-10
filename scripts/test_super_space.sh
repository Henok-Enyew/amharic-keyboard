#!/usr/bin/env bash
set -euo pipefail
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=${XDG_RUNTIME_DIR}/bus}"
OUT=/tmp/amh-super-fix.txt
exec >"$OUT" 2>&1

cp -a /home/enoch/Desktop/amharic-ibus-fedora/engine/amharic_engine.py "$HOME/.local/share/ibus/engine/amharic/"
gsettings set org.freedesktop.ibus.general.hotkey triggers "[]"
gsettings set org.freedesktop.ibus.general.hotkey trigger "[]"
gsettings set org.gnome.desktop.wm.keybindings switch-input-source "['<Super>space']"
gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us'), ('ibus', 'amharic-phonetic')]"
gsettings set org.gnome.desktop.input-sources current 1

pkill -f 'amharic_engine.py' || true
sleep 0.4
: > /tmp/amharic-keys.log
ibus engine amharic-phonetic
sleep 0.8

ADDR=$(ibus address)
PATH_E=$(gdbus introspect --address "$ADDR" --dest org.freedesktop.IBus.AmharicPhonetic \
  --object-path /org/freedesktop/IBus/Engine/AmharicPhonetic --recurse 2>/dev/null \
  | grep -oE '/org/freedesktop/IBus/Engine/AmharicPhonetic/[0-9]+' | sort -t/ -k7 -n | tail -1)
echo "path=$PATH_E current_before=$(gsettings get org.gnome.desktop.input-sources current)"

gdbus call --address "$ADDR" --dest org.freedesktop.IBus.AmharicPhonetic \
  --object-path "$PATH_E" --method org.freedesktop.IBus.Engine.FocusInId "/x" "gnome-terminal" >/dev/null

# Simulate Super press (no SUPER_MASK on following Space — terminal bug)
echo -n "Super_L press -> "
gdbus call --address "$ADDR" --dest org.freedesktop.IBus.AmharicPhonetic \
  --object-path "$PATH_E" --method org.freedesktop.IBus.Engine.ProcessKeyEvent 65515 125 0
echo -n "Space (no mask) -> "
gdbus call --address "$ADDR" --dest org.freedesktop.IBus.AmharicPhonetic \
  --object-path "$PATH_E" --method org.freedesktop.IBus.Engine.ProcessKeyEvent 32 57 0
sleep 0.3
echo "current_after=$(gsettings get org.gnome.desktop.input-sources current)"
echo "engine_after=$(ibus engine)"
echo "--- log ---"
grep -E 'Super|English|handled|cycled|fallback' /tmp/amharic-keys.log || cat /tmp/amharic-keys.log
