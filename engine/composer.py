"""Pure Amharic SERA composition state machine (no IBus / GI imports)."""

from __future__ import annotations

from dataclasses import dataclass, replace
from typing import Literal

from rules import (
    BASE_KEYS_LONGEST_FIRST,
    CONSONANT_BASES,
    LONE_VOWEL_KEYS_LONGEST_FIRST,
    LONE_VOWELS,
    PHARYNGEAL_A,
    PUNCTUATION_MAP,
    labialized_syllable,
    syllable_from_latin_base,
)

InputMode = Literal["am", "en"]


@dataclass
class EngineOptions:
    punctuation_mapping: bool = True


@dataclass
class CompositionState:
    mode: InputMode = "am"
    committed: str = ""
    pending_latin: str = ""
    preview: str = ""
    apostrophe_armed: bool = False
    last_punct_latin: str | None = None
    options: EngineOptions | None = None

    def __post_init__(self) -> None:
        if self.options is None:
            self.options = EngineOptions()


def create_initial_state(**overrides) -> CompositionState:
    opts = overrides.pop("options", None)
    if opts is None:
        options = EngineOptions()
    elif isinstance(opts, EngineOptions):
        options = opts
    elif isinstance(opts, dict):
        options = EngineOptions(**opts)
    else:
        options = EngineOptions()
    state = CompositionState(options=options, **overrides)
    return state


def display_text(state: CompositionState) -> str:
    return state.committed + state.preview


def flush_pending(state: CompositionState) -> CompositionState:
    if not state.preview and not state.pending_latin:
        return state
    return replace(
        state,
        committed=state.committed + state.preview,
        pending_latin="",
        preview="",
    )


def reset_composition(state: CompositionState) -> CompositionState:
    return replace(
        state,
        committed="",
        pending_latin="",
        preview="",
        apostrophe_armed=False,
        last_punct_latin=None,
    )


def set_options(state: CompositionState, **kwargs) -> CompositionState:
    assert state.options is not None
    opts = replace(state.options, **kwargs)
    return replace(state, options=opts)


def process_backspace(state: CompositionState) -> CompositionState:
    if state.pending_latin or state.preview:
        return replace(
            state,
            pending_latin="",
            preview="",
            apostrophe_armed=False,
            last_punct_latin=None,
        )
    if not state.committed:
        return state
    chars = list(state.committed)
    chars.pop()
    return replace(
        state,
        committed="".join(chars),
        apostrophe_armed=False,
        last_punct_latin=None,
    )


def _parse_base(pending: str) -> tuple[str, str] | None:
    for key in BASE_KEYS_LONGEST_FIRST:
        if pending.startswith(key) and key in CONSONANT_BASES:
            return key, pending[len(key) :]
    return None


def _parse_vowel_suffix(rest: str) -> dict | None:
    if rest == "":
        return {"kind": "order", "order": 6, "consumed": 0}

    if rest[0] in ("u", "U"):
        after_u = rest[1:]
        if after_u == "":
            return {"kind": "order", "order": 2, "consumed": 1}
        if len(after_u) == 2 and after_u[0] in "iI" and after_u[1] in "eE":
            return {"kind": "labial", "labial_order": 5, "consumed": 3}
        if after_u == "E":
            return {"kind": "labial", "labial_order": 5, "consumed": 2}
        if after_u == "e":
            return {"kind": "labial", "labial_order": 1, "consumed": 2}
        if after_u in ("u", "U"):
            return {"kind": "labial", "labial_order": 2, "consumed": 2}
        if after_u in ("i", "I"):
            return {"kind": "labial", "labial_order": 3, "consumed": 2}
        if after_u in ("a", "A"):
            return {"kind": "labial", "labial_order": 4, "consumed": 2}
        return None

    if len(rest) >= 2 and rest[0] in "iI" and rest[1] in "eE":
        return {"kind": "order", "order": 5, "consumed": 2}

    if rest[0] == "E":
        return {"kind": "order", "order": 5, "consumed": 1}

    ch = rest[0]
    if ch == "e":
        return {"kind": "order", "order": 1, "consumed": 1}
    if ch in ("u", "U"):
        return {"kind": "order", "order": 2, "consumed": 1}
    if ch in ("i", "I"):
        return {"kind": "order", "order": 3, "consumed": 1}
    if ch in ("a", "A"):
        return {"kind": "order", "order": 4, "consumed": 1}
    if ch in ("o", "O"):
        return {"kind": "order", "order": 7, "consumed": 1}
    return None


def match_syllable(pending: str) -> str | None:
    if not pending:
        return None

    parsed = _parse_base(pending)
    if parsed:
        base, rest = parsed
        v = _parse_vowel_suffix(rest)
        if v is None or v.get("kind") == "partial":
            return None
        if v["kind"] == "order":
            if v["consumed"] != len(rest):
                return None
            return syllable_from_latin_base(base, v["order"])
        if v["kind"] == "labial":
            if v["consumed"] != len(rest):
                return None
            return labialized_syllable(base, v["labial_order"])

    for key in LONE_VOWEL_KEYS_LONGEST_FIRST:
        if pending == key:
            return LONE_VOWELS.get(key)

    if pending[0] == "A" and len(pending) > 1:
        return PHARYNGEAL_A.get(pending)

    return None


def _can_extend(prefix: str, next_ch: str) -> bool:
    return match_syllable(prefix + next_ch) is not None


def _can_be_pending_start(s: str) -> bool:
    if not s:
        return False
    if match_syllable(s) is not None:
        return True
    for key in BASE_KEYS_LONGEST_FIRST:
        if key.startswith(s):
            return True
    for key in LONE_VOWEL_KEYS_LONGEST_FIRST:
        if key.startswith(s):
            return True
    if s[0] == "A":
        return True
    return False


def _split_pending(pending: str) -> tuple[str, str] | None:
    for length in range(len(pending) - 1, 0, -1):
        prefix = pending[:length]
        rest = pending[length:]
        char = match_syllable(prefix)
        if char is not None and not _can_extend(prefix, rest[0]):
            if match_syllable(rest) is not None or _can_be_pending_start(rest):
                return char, rest

    for length in range(len(pending) - 1, 0, -1):
        prefix = pending[:length]
        rest = pending[length:]
        char = match_syllable(prefix)
        if char is not None and not _can_extend(prefix, rest[0]):
            return char, rest
    return None


def _resolve_pending(pending: str) -> tuple[str, str, str]:
    committed_extra = ""
    current = pending
    while current:
        full = match_syllable(current)
        if full is not None:
            return committed_extra, current, full
        split = _split_pending(current)
        if not split:
            return committed_extra, current, ""
        char, rest = split
        committed_extra += char
        current = rest
    return committed_extra, "", ""


def _is_ascii_digit(key: str) -> bool:
    return len(key) == 1 and "0" <= key <= "9"


def _process_punctuation(state: CompositionState, key: str) -> CompositionState:
    assert state.options is not None
    mapped = PUNCTUATION_MAP.get(key)
    if not state.options.punctuation_mapping or not mapped:
        flushed = flush_pending(state)
        return replace(
            flushed,
            committed=flushed.committed + key,
            apostrophe_armed=False,
            last_punct_latin=None,
        )

    flushed = flush_pending(state)
    if flushed.last_punct_latin == key and flushed.committed.endswith(mapped):
        return replace(
            flushed,
            committed=flushed.committed[: -len(mapped)] + key,
            last_punct_latin=None,
            apostrophe_armed=False,
        )
    return replace(
        flushed,
        committed=flushed.committed + mapped,
        last_punct_latin=key,
        apostrophe_armed=False,
    )


def process_keystroke(state: CompositionState, key: str) -> CompositionState:
    if len(key) != 1 and key not in ("Space", " "):
        return state
    ch = " " if key == "Space" else key

    if state.mode == "en":
        return replace(
            state,
            committed=state.committed + ch,
            pending_latin="",
            preview="",
            apostrophe_armed=False,
            last_punct_latin=None,
        )

    if ch == "'":
        if state.apostrophe_armed and not state.pending_latin and not state.preview:
            return replace(
                state,
                committed=state.committed + "'",
                apostrophe_armed=False,
                last_punct_latin=None,
            )
        flushed = flush_pending(state)
        return replace(flushed, apostrophe_armed=True, last_punct_latin=None)

    if ch == " " or _is_ascii_digit(ch):
        flushed = flush_pending(state)
        return replace(
            flushed,
            committed=flushed.committed + ch,
            apostrophe_armed=False,
            last_punct_latin=None,
        )

    if ch in PUNCTUATION_MAP or ch in ".,;:!?":
        if ch in PUNCTUATION_MAP:
            return _process_punctuation(state, ch)
        flushed = flush_pending(state)
        return replace(
            flushed,
            committed=flushed.committed + ch,
            apostrophe_armed=False,
            last_punct_latin=None,
        )

    pending = state.pending_latin + ch
    committed_extra, pending_latin, preview = _resolve_pending(pending)
    return replace(
        state,
        committed=state.committed + committed_extra,
        pending_latin=pending_latin,
        preview=preview,
        apostrophe_armed=False,
        last_punct_latin=None,
    )


def transliterate(input_text: str, **option_kwargs) -> str:
    options = EngineOptions(**option_kwargs) if option_kwargs else EngineOptions()
    state = create_initial_state(options=options)
    for ch in input_text:
        state = process_keystroke(state, ch)
    state = flush_pending(state)
    return state.committed
