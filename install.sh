#!/usr/bin/env bash
# Install Amharic Phonetic IBus engine for the current user (no sudo).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENGINE_SRC="${REPO_ROOT}/engine"
COMPONENT_SRC="${REPO_ROOT}/component/amharic.xml.in"
DEFAULT_CONFIG="${REPO_ROOT}/config/default_config.json"

IBUS_COMPONENT_DIR="${HOME}/.local/share/ibus/component"
IBUS_ENGINE_DIR="${HOME}/.local/share/ibus/engine/amharic"
CONFIG_DIR="${HOME}/.config/amharic-ibus"
CONFIG_FILE="${CONFIG_DIR}/config.json"

ENGINE_EXEC="${IBUS_ENGINE_DIR}/amharic_engine.py"

echo "==> Amharic Phonetic IBus installer"

need=()
command -v ibus >/dev/null 2>&1 || need+=(ibus)
python3 -c "import gi; gi.require_version('IBus','1.0'); from gi.repository import IBus" >/dev/null 2>&1 \
  || need+=("python3-gobject / typelib")

if ((${#need[@]})); then
  echo "Missing dependencies: ${need[*]}"
  echo "Install with:"
  echo "  sudo dnf install ibus python3-gobject"
  exit 1
fi

mkdir -p "${IBUS_COMPONENT_DIR}" "${IBUS_ENGINE_DIR}" "${CONFIG_DIR}"

echo "==> Installing engine to ${IBUS_ENGINE_DIR}"
rm -rf "${IBUS_ENGINE_DIR}"
mkdir -p "${IBUS_ENGINE_DIR}"
cp -a "${ENGINE_SRC}/." "${IBUS_ENGINE_DIR}/"
rm -rf "${IBUS_ENGINE_DIR}/tests" "${IBUS_ENGINE_DIR}/__pycache__"
find "${IBUS_ENGINE_DIR}" -type d -name '__pycache__' -exec rm -rf {} + 2>/dev/null || true
chmod +x "${ENGINE_EXEC}"

echo "==> Writing component descriptor"
# Expand @ENGINE_EXEC@ and @ENGINE_DIR@ for this user
sed \
  -e "s|@ENGINE_EXEC@|${ENGINE_EXEC}|g" \
  -e "s|@ENGINE_DIR@|${IBUS_ENGINE_DIR}|g" \
  -e "s|@PYTHON@|$(command -v python3)|g" \
  "${COMPONENT_SRC}" > "${IBUS_COMPONENT_DIR}/amharic.xml"

if [[ ! -f "${CONFIG_FILE}" ]]; then
  echo "==> Seeding ${CONFIG_FILE}"
  cp "${DEFAULT_CONFIG}" "${CONFIG_FILE}"
else
  echo "==> Keeping existing ${CONFIG_FILE}"
fi

echo "==> Refreshing IBus registry (system + user components)"
python3 "${ENGINE_SRC}/register_component.py" || true

echo "==> Restarting IBus"
if ! ibus restart 2>/dev/null; then
  echo "    ibus restart failed or is unavailable — log out and back in if the engine does not appear."
fi

# Daemon rebuilds cache on restart without always scanning user components on
# this Fedora/IBus version — re-register after the daemon is back.
sleep 1
echo "==> Re-registering user component with live daemon"
python3 "${IBUS_ENGINE_DIR}/register_component.py" || \
  python3 "${ENGINE_SRC}/register_component.py" || true

# Persist registration across future logins
AUTOSTART_DIR="${HOME}/.config/autostart"
mkdir -p "${AUTOSTART_DIR}"
cat > "${AUTOSTART_DIR}/amharic-ibus-register.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Register Amharic IBus Engine
Comment=Ensure Amharic Phonetic appears in IBus after login
Exec=${IBUS_ENGINE_DIR}/register_component.py
X-GNOME-Autostart-enabled=true
NoDisplay=true
EOF
chmod +x "${IBUS_ENGINE_DIR}/register_component.py"

# Quick verification
if ibus list-engine 2>/dev/null | grep -q 'amharic-phonetic'; then
  echo "==> Verified: amharic-phonetic is listed by ibus"
else
  echo "==> Warning: amharic-phonetic not yet listed. Try logging out/in, then:"
  echo "    python3 ${IBUS_ENGINE_DIR}/register_component.py"
  echo "    ibus list-engine | grep amharic"
fi

# GNOME Settings hides many IBus engines unless show-all-sources is on.
# Also add the engine to Input Sources so the user does not have to hunt for it.
if command -v gsettings >/dev/null 2>&1; then
  echo "==> Enabling GNOME 'show all input sources' + adding Amharic Phonetic"
  gsettings set org.gnome.desktop.input-sources show-all-sources true 2>/dev/null || true
  # Merge into existing sources without wiping English / others
  python3 - <<'PY' 2>/dev/null || true
import subprocess, ast
engine = ("ibus", "amharic-phonetic")
raw = subprocess.check_output(
    ["gsettings", "get", "org.gnome.desktop.input-sources", "sources"],
    text=True,
).strip()
try:
    sources = list(ast.literal_eval(raw))
except Exception:
    sources = [("xkb", "us")]
if engine not in sources:
    sources.append(engine)
# gsettings wants: [('xkb', 'us'), ('ibus', 'amharic-phonetic')]
fmt = "[" + ", ".join(f"('{a}', '{b}')" for a, b in sources) + "]"
subprocess.check_call(
    ["gsettings", "set", "org.gnome.desktop.input-sources", "sources", fmt]
)
print("sources =", fmt)
PY
fi

cat <<EOF

Done.

Amharic Phonetic should now appear under Settings → Keyboard → Input Sources.
Switch with Super+Space (top-right language indicator).

Important: In Add Input Source, click the language "Amharic", then pick
"Amharic Phonetic" (IBus) — NOT the plain "Amharic" XKB layout.

If it is missing from Settings, run:
  gsettings set org.gnome.desktop.input-sources show-all-sources true
  python3 ${IBUS_ENGINE_DIR}/register_component.py

Config file (edit anytime; reloads when you focus a text field):
  ${CONFIG_FILE}

EOF
