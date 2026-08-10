#!/usr/bin/env bash
set -euo pipefail
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=${XDG_RUNTIME_DIR}/bus}"
OUT=/tmp/amh-sw2.txt
exec >"$OUT" 2>&1

gsettings set org.gnome.desktop.wm.keybindings switch-input-source "['<Super>space']"
gsettings set org.gnome.desktop.wm.keybindings switch-input-source-backward "['<Shift><Super>space']"
gsettings set org.freedesktop.ibus.general.hotkey triggers "[]"
gsettings set org.freedesktop.ibus.general.hotkey trigger "[]"

echo "triggers=$(gsettings get org.freedesktop.ibus.general.hotkey triggers)"
echo "trigger=$(gsettings get org.freedesktop.ibus.general.hotkey trigger)"
echo "switch=$(gsettings get org.gnome.desktop.wm.keybindings switch-input-source)"

cp -a /home/enoch/Desktop/amharic-ibus-fedora/engine/amharic_engine.py "$HOME/.local/share/ibus/engine/amharic/"
pkill -f 'amharic_engine.py' || true
sleep 0.5
ibus engine amharic-phonetic
sleep 0.8
echo "engine=$(ibus engine)"

ADDR=$(ibus address)
PATH_E=$(gdbus introspect --address "$ADDR" --dest org.freedesktop.IBus.AmharicPhonetic \
  --object-path /org/freedesktop/IBus/Engine/AmharicPhonetic --recurse 2>/dev/null \
  | grep -oE '/org/freedesktop/IBus/Engine/AmharicPhonetic/[0-9]+' | sort -t/ -k7 -n | tail -1)
echo "path=$PATH_E"
gdbus call --address "$ADDR" --dest org.freedesktop.IBus.AmharicPhonetic \
  --object-path "$PATH_E" --method org.freedesktop.IBus.Engine.FocusInId "/x" "gnome-shell" >/dev/null
echo -n "s="; gdbus call --address "$ADDR" --dest org.freedesktop.IBus.AmharicPhonetic \
  --object-path "$PATH_E" --method org.freedesktop.IBus.Engine.ProcessKeyEvent 115 31 0
echo -n "C-s="; gdbus call --address "$ADDR" --dest org.freedesktop.IBus.AmharicPhonetic \
  --object-path "$PATH_E" --method org.freedesktop.IBus.Engine.ProcessKeyEvent 115 31 4
echo -n "Super-sp="; gdbus call --address "$ADDR" --dest org.freedesktop.IBus.AmharicPhonetic \
  --object-path "$PATH_E" --method org.freedesktop.IBus.Engine.ProcessKeyEvent 32 57 67108864
