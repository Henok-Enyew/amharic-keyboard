"""Load Amharic SERA rule tables from rules.json (data only)."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

_RULES_PATH = Path(__file__).resolve().parent / "rules.json"


def _load_raw() -> dict[str, Any]:
    with _RULES_PATH.open(encoding="utf-8") as f:
        return json.load(f)


_RAW = _load_raw()

ORDER_OFFSET: dict[int, int] = {int(k): int(v) for k, v in _RAW["order_offset"].items()}
CONSONANT_BASES: dict[str, int] = {
    k: int(v) for k, v in _RAW["consonant_bases"].items()
}
LABIALIZED_SPECIAL: dict[str, str] = dict(_RAW["labialized_special"])
HAS_WA_AT_OFFSET_7: set[str] = set(_RAW["has_wa_at_offset_7"])
LONE_VOWELS: dict[str, str] = dict(_RAW["lone_vowels"])
PHARYNGEAL_A: dict[str, str] = dict(_RAW.get("pharyngeal_a", {}))
PUNCTUATION_MAP: dict[str, str] = dict(_RAW["punctuation_map"])

BASE_KEYS_LONGEST_FIRST: list[str] = sorted(
    CONSONANT_BASES.keys(), key=len, reverse=True
)
LONE_VOWEL_KEYS_LONGEST_FIRST: list[str] = sorted(
    LONE_VOWELS.keys(), key=len, reverse=True
)


def syllable_from_base(first_order_cp: int, order: int) -> str:
    offset = ORDER_OFFSET.get(order)
    if offset is None:
        raise ValueError(f"Invalid order: {order}")
    return chr(first_order_cp + offset)


def syllable_from_latin_base(latin_base: str, order: int) -> str | None:
    cp = CONSONANT_BASES.get(latin_base)
    if cp is None:
        return None
    return syllable_from_base(cp, order)


def labialized_syllable(latin_base: str, labial_order: int) -> str | None:
    special = LABIALIZED_SPECIAL.get(f"{latin_base}|{labial_order}")
    if special:
        return special
    if labial_order == 4 and latin_base in HAS_WA_AT_OFFSET_7:
        cp = CONSONANT_BASES.get(latin_base)
        if cp is None:
            return None
        return chr(cp + 7)
    return None
