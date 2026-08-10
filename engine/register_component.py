#!/usr/bin/env python3
"""Rebuild IBus registry to include ~/.local/share/ibus/component and register live."""

from __future__ import annotations

import os
import sys

import gi

gi.require_version("IBus", "1.0")
from gi.repository import IBus  # noqa: E402


def rebuild_registry() -> int:
    IBus.init()
    reg = IBus.Registry()
    reg.load()
    user_dir = os.path.expanduser("~/.local/share/ibus/component")
    if os.path.isdir(user_dir):
        reg.load_in_dir(user_dir)
    cache = os.path.expanduser("~/.cache/ibus/bus/registry")
    os.makedirs(os.path.dirname(cache), exist_ok=True)
    reg.save_cache_file(cache)
    return len(reg.get_components())


def register_live() -> bool:
    IBus.init()
    bus = IBus.Bus()
    if not bus.is_connected():
        return False
    xml = os.path.expanduser("~/.local/share/ibus/component/amharic.xml")
    if not os.path.isfile(xml):
        return False
    comp = IBus.Component.new_from_file(xml)
    return bool(bus.register_component(comp))


def main() -> int:
    n = rebuild_registry()
    print(f"Registry updated ({n} components)")
    if register_live():
        print("Registered Amharic Phonetic with running ibus-daemon")
        return 0
    print("Could not register with live daemon (is ibus running?)", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
