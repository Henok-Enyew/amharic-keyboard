#!/usr/bin/env bash
# Install Amharic Phonetic IBus engine for the current user (no sudo required
# for the engine itself — only for optional system packages).
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
VERSION="1.1.0"

usage() {
  cat <<EOF
Amharic Phonetic IBus installer v${VERSION}

Usage:
  ./install.sh              Install / reinstall for the current user
  ./install.sh --status     Show whether the engine is installed and listed
  ./install.sh --help       Show this help

User-level install (no sudo). System packages may need sudo once — see README.
EOF
}

detect_pkg_hint() {
  if command -v dnf >/dev/null 2>&1; then
    echo "sudo dnf install ibus python3-gobject"
  elif command -v apt-get >/dev/null 2>&1; then
    echo "sudo apt install ibus python3-gi gir1.2-ibus-1.0"
  elif command -v pacman >/dev/null 2>&1; then
    echo "sudo pacman -S ibus python-gobject"
  elif command -v zypper >/dev/null 2>&1; then
    echo "sudo zypper install ibus python3-gobject"
  else
    echo "Install ibus and PyGObject IBus bindings for your distro"
  fi
}

status_cmd() {
  echo "==> Amharic Phonetic status"
  echo "    repo:     ${REPO_ROOT}"
  if [[ -x "${ENGINE_EXEC}" ]]; then
    echo "    engine:   installed (${ENGINE_EXEC})"
  else
    echo "    engine:   not installed"
  fi
  if [[ -f "${IBUS_COMPONENT_DIR}/amharic.xml" ]]; then
    echo "    component: present"
  else
    echo "    component: missing"
  fi
  if [[ -f "${CONFIG_FILE}" ]]; then
    echo "    config:   ${CONFIG_FILE}"
  else
    echo "    config:   (none yet)"
  fi
  if command -v ibus >/dev/null 2>&1; then
    if ibus list-engine 2>/dev/null | grep -q 'amharic-phonetic'; then
      echo "    ibus:     amharic-phonetic is listed"
      echo "    active:   $(ibus engine 2>/dev/null || echo unknown)"
    else
      echo "    ibus:     amharic-phonetic NOT listed (run ./install.sh)"
    fi
  else
    echo "    ibus:     not found on PATH"
  fi
  if command -v gsettings >/dev/null 2>&1; then
    echo "    sources:  $(gsettings get org.gnome.desktop.input-sources sources 2>/dev/null || echo n/a)"
  fi
}

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  --status) status_cmd; exit 0 ;;
  "") ;;
  *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
esac

echo "==> Amharic Phonetic IBus installer v${VERSION}"
echo "    Target: user install under ~/.local (no sudo for engine files)"

need=()
command -v ibus >/dev/null 2>&1 || need+=("ibus")
python3 -c "import gi; gi.require_version('IBus','1.0'); from gi.repository import IBus" >/dev/null 2>&1 \
  || need+=("PyGObject IBus bindings")

if ((${#need[@]})); then
  echo
  echo "Missing dependencies: ${need[*]}"
  echo "Install once with:"
  echo "  $(detect_pkg_hint)"
  exit 1
fi

mkdir -p "${IBUS_COMPONENT_DIR}" "${IBUS_ENGINE_DIR}" "${CONFIG_DIR}"

echo "==> Installing engine → ${IBUS_ENGINE_DIR}"
rm -rf "${IBUS_ENGINE_DIR}"
mkdir -p "${IBUS_ENGINE_DIR}"
# Ship runtime files only (skip tests / caches)
shopt -s dotglob nullglob
for item in "${ENGINE_SRC}"/*; do
  base="$(basename "${item}")"
  case "${base}" in
    tests|__pycache__) continue ;;
  esac
  cp -a "${item}" "${IBUS_ENGINE_DIR}/"
done
shopt -u dotglob nullglob
find "${IBUS_ENGINE_DIR}" -type d -name '__pycache__' -exec rm -rf {} + 2>/dev/null || true
chmod +x "${ENGINE_EXEC}" "${IBUS_ENGINE_DIR}/register_component.py"

echo "==> Writing component descriptor"
sed \
  -e "s|@ENGINE_EXEC@|${ENGINE_EXEC}|g" \
  -e "s|@ENGINE_DIR@|${IBUS_ENGINE_DIR}|g" \
  -e "s|@PYTHON@|$(command -v python3)|g" \
  -e "s|<version>.*</version>|<version>${VERSION}</version>|" \
  "${COMPONENT_SRC}" > "${IBUS_COMPONENT_DIR}/amharic.xml"

if [[ ! -f "${CONFIG_FILE}" ]]; then
  echo "==> Seeding ${CONFIG_FILE}"
  cp "${DEFAULT_CONFIG}" "${CONFIG_FILE}"
else
  echo "==> Keeping existing ${CONFIG_FILE}"
fi

echo "==> Refreshing IBus registry"
python3 "${ENGINE_SRC}/register_component.py" || true

echo "==> Restarting IBus"
if ! ibus restart 2>/dev/null; then
  echo "    (ibus restart unavailable — log out/in if the engine does not appear)"
fi

# Some IBus builds rebuild the cache on restart without user components.
sleep 1
echo "==> Re-registering with live daemon"
python3 "${IBUS_ENGINE_DIR}/register_component.py" || \
  python3 "${ENGINE_SRC}/register_component.py" || true

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

if ibus list-engine 2>/dev/null | grep -q 'amharic-phonetic'; then
  echo "==> Verified: amharic-phonetic is listed by ibus"
else
  echo "==> Warning: amharic-phonetic not yet listed. Try logging out/in, then:"
  echo "    python3 ${IBUS_ENGINE_DIR}/register_component.py"
fi

# GNOME / gsettings desktop integration
if command -v gsettings >/dev/null 2>&1 \
  && gsettings list-schemas 2>/dev/null | grep -qx 'org.gnome.desktop.input-sources'; then
  echo "==> Configuring GNOME input sources + Super+Space"
  gsettings set org.gnome.desktop.input-sources show-all-sources true 2>/dev/null || true
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
fmt = "[" + ", ".join(f"('{a}', '{b}')" for a, b in sources) + "]"
subprocess.check_call(
    ["gsettings", "set", "org.gnome.desktop.input-sources", "sources", fmt]
)
print("    sources =", fmt)
PY
  # Wayland: Mutter owns Super+Space — clear IBus grabs that fight it
  gsettings set org.gnome.desktop.wm.keybindings switch-input-source "['<Super>space']" 2>/dev/null || true
  gsettings set org.gnome.desktop.wm.keybindings switch-input-source-backward "['<Shift><Super>space']" 2>/dev/null || true
  gsettings set org.freedesktop.ibus.general.hotkey triggers "[]" 2>/dev/null || true
  gsettings set org.freedesktop.ibus.general.hotkey trigger "[]" 2>/dev/null || true
else
  echo "==> Non-GNOME session (or no gsettings schema) — add the engine in your DE's IBus UI"
fi

cat <<EOF

✓ Installed Amharic Phonetic v${VERSION}

Next steps
  1. Open a text field (Text Editor, browser, terminal, …)
  2. Press Super+Space until the indicator shows Amharic Phonetic
  3. Type:  selam   →  ሰላም
            amarNa  →  አማርኛ

GNOME: Settings → Keyboard → Input Sources
  Pick “Amharic Phonetic” (IBus) — not the plain “Amharic” XKB layout.

Config (hot-reloads on focus):
  ${CONFIG_FILE}

Uninstall:
  ./uninstall.sh
  ./uninstall.sh --purge   # also remove config

Status later:
  ./install.sh --status

EOF
