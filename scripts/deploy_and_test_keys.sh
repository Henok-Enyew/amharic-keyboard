#!/usr/bin/env bash
set -euo pipefail
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=${XDG_RUNTIME_DIR}/bus}"

SRC=/home/enoch/Desktop/amharic-ibus-fedora
DEST="$HOME/.local/share/ibus/engine/amharic"

cp -a "$SRC/engine/amharic_engine.py" "$SRC/engine/composer.py" "$SRC/engine/rules.json" "$DEST/"
chmod +x "$DEST/amharic_engine.py"

pkill -f 'amharic_engine.py' || true
sleep 0.5
: > /tmp/amharic-keys.log

python3 "$DEST/register_component.py" >/tmp/amh-reg.txt 2>&1 || true

# Restore clean input sources
gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us'), ('ibus', 'amharic-phonetic')]"
gsettings set org.gnome.desktop.input-sources current 1
ibus engine amharic-phonetic
sleep 1.0

ADDR=$(ibus address)
# Find latest engine path
TREE=$(gdbus introspect --address "$ADDR" --dest org.freedesktop.IBus.AmharicPhonetic \
  --object-path /org/freedesktop/IBus/Engine/AmharicPhonetic --recurse 2>/dev/null || true)
PATH_E=$(echo "$TREE" | grep -oE '/org/freedesktop/IBus/Engine/AmharicPhonetic/[0-9]+' | sort -t/ -k7 -n | tail -1)
echo "engine_path=$PATH_E"
echo "ibus_engine=$(ibus engine)"

gdbus call --address "$ADDR" --dest org.freedesktop.IBus.AmharicPhonetic \
  --object-path "$PATH_E" \
  --method org.freedesktop.IBus.Engine.FocusInId \
  "/org/freedesktop/IBus/InputContext_1" "gnome-shell" >/dev/null

echo "ProcessKeyEvent returns:"
for kv in 115 101 108 97 109; do
  gdbus call --address "$ADDR" --dest org.freedesktop.IBus.AmharicPhonetic \
    --object-path "$PATH_E" \
    --method org.freedesktop.IBus.Engine.ProcessKeyEvent "$kv" 31 0
done

echo "--- log ---"
cat /tmp/amharic-keys.log
