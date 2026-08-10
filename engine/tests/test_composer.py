"""Unit tests for the pure Amharic composer (no IBus)."""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

# Allow `pytest` from repo root or engine/
ENGINE_DIR = Path(__file__).resolve().parents[1]
if str(ENGINE_DIR) not in sys.path:
    sys.path.insert(0, str(ENGINE_DIR))

from composer import (  # noqa: E402
    create_initial_state,
    display_text,
    flush_pending,
    match_syllable,
    process_backspace,
    process_keystroke,
    transliterate,
)
from rules import syllable_from_latin_base  # noqa: E402


def type_all(text: str):
    state = create_initial_state()
    for ch in text:
        state = process_keystroke(state, ch)
    return flush_pending(state)


class TestUnicodeOrders:
    def test_l_family(self):
        assert syllable_from_latin_base("l", 1) == "ለ"
        assert syllable_from_latin_base("l", 2) == "ሉ"
        assert syllable_from_latin_base("l", 3) == "ሊ"
        assert syllable_from_latin_base("l", 4) == "ላ"
        assert syllable_from_latin_base("l", 5) == "ሌ"
        assert syllable_from_latin_base("l", 6) == "ል"
        assert syllable_from_latin_base("l", 7) == "ሎ"


class TestMatchSyllable:
    def test_basics(self):
        assert match_syllable("l") == "ል"
        assert match_syllable("le") == "ለ"
        assert match_syllable("lE") == "ሌ"
        assert match_syllable("lie") == "ሌ"
        assert match_syllable("s") == "ስ"
        assert match_syllable("sh") == "ሽ"
        assert match_syllable("sha") == "ሻ"
        assert match_syllable("ss") == "ሥ"
        assert match_syllable("a") == "አ"
        assert match_syllable("E") == "ኤ"
        assert match_syllable("N") == "ኝ"
        assert match_syllable("Na") == "ኛ"
        assert match_syllable("mua") == "ሟ"
        assert match_syllable("kua") == "ኳ"
        assert match_syllable("hua") == "ኋ"
        assert match_syllable("Hua") == "ኋ"
        assert match_syllable("tua") == "ቷ"


class TestVerifiedWords:
    def test_amarNa(self):
        assert transliterate("amarNa") == "አማርኛ"

    def test_adis_abeba(self):
        assert transliterate("adis abeba") == "አዲስ አበባ"

    def test_gebr_El(self):
        assert transliterate("gebr'El") == "ገብርኤል"

    def test_kremt(self):
        assert transliterate("kremt") == "ክረምት"

    def test_kiremiti_sera_not_kremt(self):
        assert transliterate("kiremiti") == "ኪረሚቲ"


class TestCompositionBehavior:
    def test_digraph_revise(self):
        state = create_initial_state()
        state = process_keystroke(state, "s")
        assert display_text(state) == "ስ"
        state = process_keystroke(state, "h")
        assert display_text(state) == "ሽ"

    def test_upgrade_vowel(self):
        state = create_initial_state()
        state = process_keystroke(state, "l")
        assert display_text(state) == "ል"
        state = process_keystroke(state, "e")
        assert display_text(state) == "ለ"

    def test_apostrophe_break(self):
        assert transliterate("r'E") == "ርኤ"
        assert transliterate("rE") == "ሬ"

    def test_backspace_logical(self):
        state = type_all("ha")
        assert display_text(state) == "ሃ"
        state = process_backspace(state)
        assert display_text(state) == ""

        state = create_initial_state()
        state = process_keystroke(state, "h")
        state = process_keystroke(state, "a")
        assert display_text(state) == "ሃ"
        state = process_backspace(state)
        assert display_text(state) == ""

    def test_punctuation(self):
        state = create_initial_state()
        state = process_keystroke(state, ".")
        assert display_text(state) == "።"
        state = process_keystroke(state, ".")
        assert display_text(state) == "."

    def test_selam(self):
        assert transliterate("selam") == "ሰላም"
