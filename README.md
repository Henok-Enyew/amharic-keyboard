# Amharic Phonetic

**System-wide Amharic (አማርኛ) input for Linux** — type Latin letters, get Fidel, in every app.

SERA / GFF phonetic rules · Live underlined preedit · Works with GNOME (and other IBus desktops) · User-level install, no root for the engine

```
selam   →  ሰላም
amarNa  →  አማርኛ
kremt   →  ክረምት
```

---

## Install

**One-time packages** (pick your distro), then the installer:

<table>
<tr><td><b>Fedora / RHEL</b></td><td>

```bash
sudo dnf install ibus python3-gobject git
```

</td></tr>
<tr><td><b>Ubuntu / Debian</b></td><td>

```bash
sudo apt install ibus python3-gi gir1.2-ibus-1.0 git
```

</td></tr>
<tr><td><b>Arch</b></td><td>

```bash
sudo pacman -S ibus python-gobject git
```

</td></tr>
</table>

**Install the engine** (current user only — no sudo):

```bash
git clone https://github.com/Henok-Enyew/amharic-keyboard.git
cd amharic-keyboard
chmod +x install.sh uninstall.sh
./install.sh
```

Already cloned? Re-run `./install.sh` anytime to upgrade in place.

Check status later:

```bash
./install.sh --status
```

### GNOME (Fedora Workstation, etc.)

The installer:

- Enables “show all input sources”
- Adds **Amharic Phonetic** to your input sources
- Sets **Super+Space** for switching (and clears conflicting IBus grabs)

Then:

1. Click any text field  
2. Press **Super+Space** until the top bar shows **Amharic Phonetic**  
3. Type `selam` → **ሰላም**

> In **Settings → Keyboard → Input Sources → +**, open the **Amharic** language, then choose **Amharic Phonetic** (IBus).  
> Do **not** pick the plain **Amharic** XKB layout — that is a different keyboard.

### After reboot

A small autostart entry re-registers the engine with IBus. If it ever goes missing:

```bash
python3 ~/.local/share/ibus/engine/amharic/register_component.py
./install.sh --status
```

### KDE Plasma / other IBus desktops

1. Run `./install.sh`  
2. Set **IBus** as the input method framework in System Settings  
3. Add **Amharic Phonetic** and use your desktop’s input-source shortcut  

---

## Uninstall

```bash
./uninstall.sh          # keep ~/.config/amharic-ibus
./uninstall.sh --purge  # remove config too
```

---

## How to type

| Order | Latin | Example (`l`) |
|------:|-------|---------------|
| 6th (bare) | consonant alone | `l` → ል |
| 1st | `e` | `le` → ለ |
| 2nd | `u` | `lu` → ሉ |
| 3rd | `i` | `li` → ሊ |
| 4th | `a` | `la` → ላ |
| 5th | `E` / `ie` | `lE` → ሌ |
| 7th | `o` | `lo` → ሎ |

**Useful**

- Digraphs: `sh` → ሸ, `ch` → ቸ · ejectives `T` `C` `P` `S`
- Syllable break: `r'E` → ርኤ (not ሬ)
- Punctuation (optional): `.` → ። · `,` → ፣ · `;` → ፤ (double-tap for Latin)
- **Canonical SERA:** bare consonant = 6th order — `kremt` → ክረምት, `kiremiti` → ኪረሚቲ

Switch back to English with **Super+Space**. Ctrl shortcuts (copy/paste, etc.) pass through.

---

## Configuration

`~/.config/amharic-ibus/config.json` (created on first install):

```json
{
  "punctuation_mapping": true,
  "ethiopic_numerals": false
}
```

Changes apply the next time a text field gets focus — no IBus restart.

---

## What gets installed

| Path | Purpose |
|------|---------|
| `~/.local/share/ibus/engine/amharic/` | Engine + composer + rules |
| `~/.local/share/ibus/component/amharic.xml` | IBus component |
| `~/.config/amharic-ibus/config.json` | User options |
| `~/.config/autostart/amharic-ibus-register.desktop` | Re-register on login |

Nothing is written under `/usr` — fully reversible with `./uninstall.sh`.

---

## Requirements

- Linux with **IBus** 1.5.x  
- **Python 3.10+** with **PyGObject** IBus bindings  
- Tested on **Fedora 43 · GNOME 49 · Wayland**  

---

## Development

Composer is pure Python (no IBus import) — easy to test:

```bash
python3 -m pip install pytest
python3 -m pytest
```

Rule table: `engine/rules.json` (SERA/GFF). Companion web keyboard (same rules) lives alongside this project when developed together.

```
engine/
  amharic_engine.py   # IBus adapter
  composer.py         # transliteration core
  rules.json          # mappings
  register_component.py
component/
  amharic.xml.in      # template (paths filled by install.sh)
config/
  default_config.json
```

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Engine missing after reboot | `python3 ~/.local/share/ibus/engine/amharic/register_component.py` |
| Super+Space does nothing | Re-run `./install.sh` (resets IBus hotkey grabs + GNOME binding) |
| Only Latin while “Amharic” selected | You may have the XKB **Amharic** layout — switch to **Amharic Phonetic** |
| `install.sh` says missing deps | Install packages from the table above, then retry |

```bash
./install.sh --status
ibus list-engine | grep amharic
ibus engine
```

---

## License

[MIT](LICENSE) © [Henok Enyew](https://henokenyew.me) · henokenyew86@gmail.com
