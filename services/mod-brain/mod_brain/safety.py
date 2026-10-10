"""Content safety post-filter (docs/06 §5.9 Nr. 3). A port of the game's ModLineFilter
(game/core/show/mod_line_filter.gd) with the same word lists (game/data/mod_filter.json): every line the service
gives out has passed exactly the rules the client applies again (tests/fixtures/live/line_filter_cases.json is run by
both sides). Never a reason to show something the game would drop.

check_line(text) → "" (ok) or the first failing rule: empty · too_long · placeholder · url · digits ·
blocked_<category> · money · purchase_pressure · language."""

from __future__ import annotations

import re
from collections import Counter

BLOCKED_ORDER = ["politics", "sexual", "slurs", "violence", "real_brands"]

_RE_WORD = re.compile(r"[a-zäöüß]+(?:-[a-zäöüß]+)*")
_RE_BRACE = re.compile(r"\{[^{}]*\}")
_RE_URL = re.compile(r"[a-z0-9-]+\.(?:de|com|net|org|io|tv|gg|eu|info|app|ly)\b")
_RE_DIGITS = re.compile(r"[0-9](?:[ ./-]?[0-9]){5,}")


def tokenize(low: str) -> list[str]:
    return _RE_WORD.findall(low.lower())


def _any_hit(tokens: list[str], entries) -> bool:
    if not isinstance(entries, list):
        return False
    for entry in entries:
        e = str(entry).lower()
        if e == "" or " " in e:
            continue
        if e.endswith("*"):
            stem = e[:-1]
            if any(t.startswith(stem) for t in tokens):
                return True
        elif e in tokens:
            return True
    return False


def _has_phrase(tokens: list[str], entries) -> bool:
    if not isinstance(entries, list):
        return False
    joined = " " + " ".join(tokens) + " "
    for entry in entries:
        e = str(entry).lower().strip()
        if e and (" " + e + " ") in joined:
            return True
    return False


def check_line(text: str, words: dict) -> str:
    """Same rules and order as ModLineFilter.check."""
    t = (text or "").strip()
    if t == "":
        return "empty"
    if len(t) > int(words.get("max_len", 110)):
        return "too_long"
    for m in _RE_BRACE.finditer(t):
        if m.group(0) != "{name}":
            return "placeholder"
    rest = _RE_BRACE.sub("", t)
    if "{" in rest or "}" in rest:
        return "placeholder"
    low = t.lower()
    if "http" in low or "www." in low or "://" in low or _RE_URL.search(low):
        return "url"
    if _RE_DIGITS.search(low):
        return "digits"
    tokens = tokenize(low.replace("{name}", " "))
    parts = list(tokens)
    for tok in tokens:
        if "-" in tok:
            parts.extend(p for p in tok.split("-") if p)
    blocked = words.get("blocked", {}) if isinstance(words.get("blocked"), dict) else {}
    for cat in BLOCKED_ORDER:
        if _any_hit(parts, blocked.get(cat, [])):
            return "blocked_" + cat
    if "€" in low or _any_hit(parts, words.get("money", [])):
        return "money"
    if _any_hit(parts, words.get("purchase", [])) and _has_phrase(tokens, words.get("urgency", [])):
        return "purchase_pressure"
    n = len(tokens)
    if n >= int(words.get("lang_min_words", 4)):
        de_list = set(words.get("de_stopwords", []))
        en_list = set(words.get("en_stopwords", [])) - de_list
        de = sum(1 for x in tokens if x in de_list)
        en = sum(1 for x in tokens if x in en_list)
        if (en * 1000 // n > int(words.get("en_max_pm", 150))
                or (n >= int(words.get("lang_de_min_words", 6)) and de * 1000 // n < int(words.get("de_min_pm", 100)))):
            return "language"
    return ""


class SafetyStats:
    """Filter hits per rule (S1 gate: hits < 2 %, false alarms < 1 %)."""

    def __init__(self) -> None:
        self.checked = 0
        self.hits: Counter[str] = Counter()

    def note(self, reason: str) -> None:
        self.checked += 1
        if reason:
            self.hits[reason] += 1
