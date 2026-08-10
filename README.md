# Amharic Phonetic IBus Engine (Fedora)

System-wide Amharic (አማርኛ) phonetic input for **Fedora Linux**, using **IBus** (already the default input framework on GNOME and KDE spins).

Type Latin letters and Fidel appears live — same SERA / GFF rules as the companion web app [Amharic Keyboard](../Amharic%20Keyboard), with underlined **preedit** like Chinese/Japanese IMEs on your system.

## Requirements

- Fedora (tested against IBus 1.5.x)
- Packages (Workstation usually has these already):

```bash
sudo dnf install ibus python3-gobject
```

No compiler, no meson, no extra daemons.

## Install (one script)

```bash
cd ~/Desktop/amharic-ibus-fedora   # or wherever you cloned this repo
chmod +x install.sh uninstall.sh
./install.sh
```

What it does:

1. Checks for `ibus` and PyGObject IBus bindings
2. Copies the engine to `~/.local/share/ibus/engine/amharic/`
3. Writes `~/.local/share/ibus/component/amharic.xml`
4. Seeds `~/.config/amharic-ibus/config.json` **only if missing**
5. Runs `ibus write-cache` and `ibus restart`

### Add it in GNOME Settings

GNOME often **hides** custom IBus engines. The installer turns on “show all sources”
and adds **Amharic Phonetic** for you. After `./install.sh`:

1. Open **Settings → Keyboard → Input Sources** — you should see **Amharic Phonetic**
2. Switch with **Super+Space** (top bar language menu)

If you add it manually with **+**:

1. Search **Amharic**
2. Click the **Amharic** language row (don’t stop there — Add stays grayed out)
3. Choose **Amharic Phonetic** (the IBus engine) — **not** the plain “Amharic” keyboard layout
4. Click **Add**

Or from a terminal:

```bash
gsettings set org.gnome.desktop.input-sources show-all-sources true
gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us'), ('ibus', 'amharic-phonetic')]"
```

Open Text Editor, switch to Amharic Phonetic, type `amarNa` — you should see **አማርኛ**.

If IBus loses the engine after reboot, run:

```bash
python3 ~/.local/share/ibus/engine/amharic/register_component.py
```

A login autostart entry is also installed so registration survives reboots.

## Uninstall

```bash
./uninstall.sh          # keeps your config
./uninstall.sh --purge  # also deletes ~/.config/amharic-ibus
```

Then remove the input source from Settings if it still shows up.

## How to type

| Order | Latin | Example (`l`) |
|------:|-------|---------------|
| 6th (bare) | consonant alone | `l` → ል |
| 1st | `e` | `le` → ለ |
| 2nd | `u` | `lu` → ሉ |
| 3rd | `i` | `li` → ሊ |
| 4th | `a` | `la` → ላ |
| 5th | `E` or `ie` | `lE` → ሌ |
| 7th | `o` | `lo` → ሎ |

Useful keys:

- Digraphs: `sh` → ሸ, `ch` → ቸ; ejectives `T` `C` `P` `S`
- Apostrophe syllable break: `r'E` → ርኤ (not ሬ)
- Punctuation (if enabled): `.` → ። , `,` → ፣ , `;` → ፤ (double-tap for Latin)

### `kremt` vs `kiremiti`

This engine follows **canonical SERA**: bare consonant = 6th order (schwa).

- `kremt` → ክረምት
- `kiremiti` → ኪረሚቲ (`i` is 3rd order, not schwa)

## Config

Edit `~/.config/amharic-ibus/config.json`:

```json
{
  "punctuation_mapping": true,
  "ethiopic_numerals": false
}
```

Changes are picked up the next time a text field gets focus (`do_focus_in`). No IBus restart needed.

English input: switch Input Sources (Super+Space) to your US/English keyboard — this engine does **not** steal Ctrl+Space.

## Development / tests

Composer is pure Python (no IBus imports):

```bash
cd amharic-ibus-fedora
python3 -m pip install pytest
python3 -m pytest
```

Verified words: `amarNa`, `adis abeba`, `gebr'El`, `kremt`.

## Rule table source of truth

Mappings live in `engine/rules.json`, exported from the web app’s [`rules.ts`](../Amharic%20Keyboard/src/engine/rules.ts).

**Canonical source:** web app `src/engine/rules.ts`. When you change a mapping there, re-export into this repo’s `engine/rules.json` (and keep both READMEs pointing at each other).

## KDE Plasma (short note)

IBus works on Fedora KDE as well. After `./install.sh`:

1. System Settings → Input Devices / Keyboard → Input Method (or “Virtual Keyboard” / IBus depending on Plasma version)
2. Ensure IBus is the input method framework
3. Add **Amharic Phonetic** and switch with the Plasma input-source shortcut

## License

MIT — Henok Enyew ([henokenyew.me](https://henokenyew.me) · henokenyew86@gmail.com)
# amharic-keyboard
