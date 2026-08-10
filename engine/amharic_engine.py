#!/usr/bin/env python3
"""IBus engine adapter for Amharic phonetic input (Fedora)."""

from __future__ import annotations

import argparse
import json
import logging
import os
import sys
from pathlib import Path

import gi

gi.require_version("IBus", "1.0")
gi.require_version("GLib", "2.0")
from gi.repository import GLib, IBus  # noqa: E402

ENGINE_DIR = Path(__file__).resolve().parent
if str(ENGINE_DIR) not in sys.path:
    sys.path.insert(0, str(ENGINE_DIR))

from composer import (  # noqa: E402
    CompositionState,
    EngineOptions,
    create_initial_state,
    flush_pending,
    process_backspace,
    process_keystroke,
    set_options,
)

LOG = logging.getLogger("amharic-ibus")

CONFIG_DIR = Path.home() / ".config" / "amharic-ibus"
CONFIG_PATH = CONFIG_DIR / "config.json"
DEFAULT_CONFIG = {
    "punctuation_mapping": True,
    "ethiopic_numerals": False,
}

ENGINE_NAME = "amharic-phonetic"
BUS_NAME = "org.freedesktop.IBus.AmharicPhonetic"


def load_config() -> dict:
    cfg = dict(DEFAULT_CONFIG)
    try:
        if CONFIG_PATH.is_file():
            with CONFIG_PATH.open(encoding="utf-8") as f:
                data = json.load(f)
            if isinstance(data, dict):
                cfg.update(data)
    except (OSError, json.JSONDecodeError) as exc:
        LOG.warning("Failed to load config %s: %s", CONFIG_PATH, exc)
    return cfg


class ConfigWatcher:
    def __init__(self) -> None:
        self._mtime: float | None = None
        self.config = load_config()
        self._refresh_mtime()

    def _refresh_mtime(self) -> None:
        try:
            self._mtime = (
                CONFIG_PATH.stat().st_mtime if CONFIG_PATH.is_file() else None
            )
        except OSError:
            self._mtime = None

    def maybe_reload(self) -> dict:
        try:
            mtime = CONFIG_PATH.stat().st_mtime if CONFIG_PATH.is_file() else None
        except OSError:
            mtime = None
        if mtime != self._mtime:
            self.config = load_config()
            self._mtime = mtime
            LOG.info("Reloaded config from %s", CONFIG_PATH)
        return self.config


def engines_xml() -> str:
    icon = ENGINE_DIR / "icons" / "amharic.svg"
    icon_str = str(icon) if icon.is_file() else "ibus-keyboard"
    return f"""<?xml version="1.0" encoding="utf-8"?>
<engines>
  <engine>
    <name>{ENGINE_NAME}</name>
    <language>am</language>
    <license>MIT</license>
    <author>Henok Enyew</author>
    <icon>{icon_str}</icon>
    <layout>us</layout>
    <longname>Amharic Phonetic</longname>
    <description>SERA / GFF Amharic phonetic input (Windows IME feel)</description>
    <rank>99</rank>
    <symbol>አ</symbol>
  </engine>
</engines>
"""


def keyval_to_char(keyval: int) -> str:
    raw = IBus.keyval_to_unicode(keyval)
    if isinstance(raw, str):
        return raw
    if isinstance(raw, int):
        return chr(raw) if raw else ""
    if keyval == IBus.space:
        return " "
    return ""


# Shared config watcher for engine instances
_CONFIG = ConfigWatcher()


class AmharicEngine(IBus.Engine):
    __gtype_name__ = "AmharicPhoneticEngine"

    def __init__(self, bus: IBus.Bus, object_path: str):
        # object_path is required — without it IBus crashes on SetGlobalEngine
        if hasattr(IBus.Engine.props, "has_focus_id"):
            super().__init__(
                connection=bus.get_connection(),
                object_path=object_path,
                has_focus_id=True,
            )
        else:
            super().__init__(
                connection=bus.get_connection(),
                object_path=object_path,
            )
        self._composer = self._new_composer_state()
        self._client = ""
        # Wayland/terminals often deliver Super+Space without SUPER_MASK on Space.
        # Track Super ourselves so we never eat the switch shortcut.
        self._super_down = False
        self._ctrl_down = False
        self._alt_down = False

    def _new_composer_state(self) -> CompositionState:
        cfg = _CONFIG.config
        return create_initial_state(
            options=EngineOptions(
                punctuation_mapping=bool(cfg.get("punctuation_mapping", True)),
            )
        )

    def _apply_config(self) -> None:
        cfg = _CONFIG.maybe_reload()
        self._composer = set_options(
            self._composer,
            punctuation_mapping=bool(cfg.get("punctuation_mapping", True)),
        )

    def do_enable(self):  # noqa: N802
        self._apply_config()

    def do_focus_in(self):  # noqa: N802
        self.do_focus_in_id("", "")

    def do_focus_in_id(self, object_path, client):  # noqa: N802
        self._client = client or ""
        LOG.info("focus-in-id path=%s client=%s", object_path, client)
        self._apply_config()

    def do_focus_out(self):  # noqa: N802
        self.do_focus_out_id("")

    def do_focus_out_id(self, object_path):  # noqa: N802
        del object_path
        self._super_down = False
        self._ctrl_down = False
        self._alt_down = False
        self._flush_commit_reset()

    def do_reset(self):  # noqa: N802
        self._super_down = False
        self._ctrl_down = False
        self._alt_down = False
        self._flush_commit_reset()

    def _clear_preedit(self) -> None:
        empty = IBus.Text.new_from_string("")
        self.update_preedit_text_with_mode(
            empty, 0, False, IBus.PreeditFocusMode.CLEAR
        )

    def _commit_string(self, text: str) -> None:
        if text:
            self.commit_text(IBus.Text.new_from_string(text))

    def _update_preedit(self, preview: str) -> None:
        if not preview:
            self._clear_preedit()
            return
        text = IBus.Text.new_from_string(preview)
        attrs = IBus.AttrList()
        attrs.append(
            IBus.Attribute.new(
                IBus.AttrType.UNDERLINE,
                IBus.AttrUnderline.SINGLE,
                0,
                len(preview),
            )
        )
        text.set_attributes(attrs)
        self.update_preedit_text_with_mode(
            text, len(preview), True, IBus.PreeditFocusMode.COMMIT
        )

    def _sync(self, before_committed: str) -> None:
        new_committed = self._composer.committed
        if new_committed.startswith(before_committed):
            delta = new_committed[len(before_committed) :]
        else:
            delta = new_committed
        if delta:
            self._commit_string(delta)
        self._update_preedit(self._composer.preview)

    def _flush_commit_reset(self) -> None:
        before = self._composer.committed
        self._composer = flush_pending(self._composer)
        self._sync(before)
        self._clear_preedit()
        self._composer = self._new_composer_state()

    def do_process_key_event(self, keyval, keycode, state):  # noqa: N802
        try:
            handled = self._process_key_event(int(keyval), int(keycode), int(state))
            return bool(handled)
        except Exception:
            LOG.exception(
                "process_key_event failed keyval=%s keycode=%s state=%s",
                keyval,
                keycode,
                state,
            )
            return False

    def _has_passthrough_modifier(self, state: int) -> bool:
        """Ctrl/Alt/Super/Hyper — desktop shortcuts, never consume."""
        return bool(
            state
            & (
                IBus.ModifierType.CONTROL_MASK
                | IBus.ModifierType.MOD1_MASK
                | IBus.ModifierType.META_MASK
                | IBus.ModifierType.SUPER_MASK
                | IBus.ModifierType.HYPER_MASK
            )
        )

    @staticmethod
    def _switch_to_english_source() -> None:
        """Leave Amharic for the first XKB layout (usually English).

        Idempotent if Mutter already switched — avoids double-toggle.
        Needed because terminals often deliver Super+Space to the IME
        instead of letting Mutter handle it.
        """
        import ast
        import subprocess

        try:
            raw = subprocess.check_output(
                ["gsettings", "get", "org.gnome.desktop.input-sources", "sources"],
                text=True,
            ).strip()
            sources = list(ast.literal_eval(raw))
            target = 0
            for i, pair in enumerate(sources):
                if pair and pair[0] == "xkb":
                    target = i
                    break
            subprocess.check_call(
                [
                    "gsettings",
                    "set",
                    "org.gnome.desktop.input-sources",
                    "current",
                    str(target),
                ]
            )
            # Keep ibus-daemon in sync with GNOME
            subprocess.Popen(
                ["ibus", "engine", "xkb:us::eng"],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            LOG.info("Super+Space fallback: switched to English (index %s)", target)
        except Exception:
            LOG.exception("Failed to switch to English input source")

    def _update_modifier_latch(self, keyval: int, is_release: bool) -> bool:
        """Track Super/Ctrl/Alt latch. Return True if this keyval is a modifier."""
        if keyval in (IBus.Super_L, IBus.Super_R, IBus.Hyper_L, IBus.Hyper_R):
            self._super_down = not is_release
            return True
        if keyval in (IBus.Control_L, IBus.Control_R):
            self._ctrl_down = not is_release
            return True
        if keyval in (IBus.Alt_L, IBus.Alt_R, IBus.Meta_L, IBus.Meta_R):
            # Meta is often Alt on PC keyboards
            self._alt_down = not is_release
            return True
        return False

    def _process_key_event(self, keyval: int, keycode: int, state: int) -> bool:
        del keycode
        is_release = bool(state & IBus.ModifierType.RELEASE_MASK)

        if self._update_modifier_latch(keyval, is_release):
            # Flush on Ctrl/Alt press so shortcuts see a clean buffer
            if not is_release and (
                keyval in (IBus.Control_L, IBus.Control_R, IBus.Alt_L, IBus.Alt_R)
            ):
                if self._composer.pending_latin or self._composer.preview:
                    self._flush_commit_reset()
            return False

        if is_release:
            return False

        # Super+Space — never compose; toggle source if the event reached us
        # (Mutter already handled it in some apps; in terminals it often does not).
        if (self._super_down or (state & IBus.ModifierType.SUPER_MASK)) and keyval in (
            IBus.space,
            IBus.KEY_space,
        ):
            if self._composer.pending_latin or self._composer.preview:
                self._flush_commit_reset()
            self._switch_to_english_source()
            return True

        # Super/Ctrl/Alt chords must reach the desktop/app
        if (
            self._super_down
            or self._ctrl_down
            or self._alt_down
            or self._has_passthrough_modifier(state)
        ):
            if self._composer.pending_latin or self._composer.preview:
                self._flush_commit_reset()
            return False

        # Bare non-character keys — never consume
        if not keyval_to_char(keyval) and keyval not in (
            IBus.BackSpace,
            IBus.Escape,
            IBus.Return,
            IBus.KP_Enter,
            IBus.Tab,
            IBus.space,
        ):
            return False

        if keyval == IBus.BackSpace:
            if self._composer.pending_latin or self._composer.preview:
                before = self._composer.committed
                self._composer = process_backspace(self._composer)
                self._sync(before)
                return True
            return False

        if keyval == IBus.Escape:
            if self._composer.pending_latin or self._composer.preview:
                before = self._composer.committed
                self._composer = process_backspace(self._composer)
                self._sync(before)
                return True
            return False

        if keyval in (IBus.Return, IBus.KP_Enter, IBus.Tab):
            if self._composer.pending_latin or self._composer.preview:
                self._flush_commit_reset()
            return False

        ch = keyval_to_char(keyval)
        if not ch:
            return False

        before = self._composer.committed
        self._composer = process_keystroke(self._composer, ch)
        self._sync(before)
        LOG.info(
            "handled %r -> committed=%r preview=%r pending=%r",
            ch,
            self._composer.committed,
            self._composer.preview,
            self._composer.pending_latin,
        )
        return True


class EngineFactory(IBus.Factory):
    __gtype_name__ = "AmharicPhoneticFactory"

    def __init__(self, bus: IBus.Bus):
        self.bus = bus
        self._id = 0
        self._engines: dict[str, AmharicEngine] = {}
        super().__init__(
            connection=bus.get_connection(),
            object_path=IBus.PATH_FACTORY,
        )

    def do_create_engine(self, engine_name):  # noqa: N802
        LOG.info("Creating engine: %s", engine_name)
        self._id += 1
        path = f"/org/freedesktop/IBus/Engine/AmharicPhonetic/{self._id}"
        engine = AmharicEngine(self.bus, path)
        self._engines[path] = engine
        return engine


def run_ibus() -> None:
    IBus.init()
    bus = IBus.Bus()
    if not bus.is_connected():
        LOG.error("Cannot connect to IBus daemon — is ibus-daemon running?")
        sys.exit(1)

    factory = EngineFactory(bus)
    bus._amharic_factory = factory  # type: ignore[attr-defined]

    if not bus.request_name(BUS_NAME, 0):
        LOG.error("Failed to request bus name %s", BUS_NAME)
        sys.exit(1)

    LOG.info("Amharic Phonetic IBus engine ready (%s)", BUS_NAME)
    GLib.MainLoop().run()


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(description="Amharic Phonetic IBus engine")
    parser.add_argument("--ibus", "-i", action="store_true", help="Run under IBus")
    parser.add_argument("--xml", "-x", action="store_true", help="Print engines XML")
    parser.add_argument("--daemon", "-d", action="store_true", help="Fork to background")
    args = parser.parse_args(argv)

    log_handlers: list[logging.Handler] = [logging.StreamHandler()]
    try:
        log_handlers.append(logging.FileHandler("/tmp/amharic-keys.log"))
    except OSError:
        pass

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
        handlers=log_handlers,
        force=True,
    )

    if args.xml:
        sys.stdout.write(engines_xml())
        return

    if args.daemon and os.fork() > 0:
        sys.exit(0)

    run_ibus()


if __name__ == "__main__":
    main()
