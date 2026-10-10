"""Content safety post-filter: the same verdicts as the game's ModLineFilter (shared cases), the co-occurrence rule for
purchase pressure, politics / slur / sexual / brand blocks, the language check, and the false-alarm rate on the
written M.O.D. lines (S1 gate: < 1 %)."""

from __future__ import annotations

import json

import pytest

from conftest import GAME, load_fixture
from mod_brain.safety import SafetyStats, check_line


@pytest.fixture(scope="module")
def words():
    return json.loads((GAME / "data" / "mod_filter.json").read_text(encoding="utf-8"))


def test_shared_line_filter_cases(words):
    for case in load_fixture("line_filter_cases.json")["cases"]:
        assert check_line(case["text"], words) == case["expect"], case["text"]


@pytest.mark.parametrize("text,reason", [
    ("Schnellschnitt!", ""),
    ("Schnell, Sponsor-Fenster!", "purchase_pressure"),
    ("Nur noch zwei Räume bis zur Treppe, ich zähle mit.", ""),
    ("Nur noch drei Geschenke im Fenster, beeilen Sie sich.", "purchase_pressure"),
    ("Die Bundesregierung schaut heute auch zu, sagt man.", "blocked_politics"),
    ("Das war ein schlampiger Kampf, ehrlich gesagt.", ""),     # 'schlampiger' is not the stem 'schlampe*'
    ("So eine Schlampe von Ratte habe ich noch nie gesehen.", "blocked_slurs"),
    ("Das war nackter Wahnsinn, ehrlich gesagt.", "blocked_sexual"),        # prefix stems are strict on purpose
])
def test_examples(words, text, reason):
    assert check_line(text, words) == reason


def test_placeholders_only_name(words):
    assert check_line("Kandidat:in {name} gibt heute alles für die Quote.", words) == ""
    assert check_line("Kandidat:in {name} hat {followers} Follower.", words) == "placeholder"


def test_false_alarm_rate_on_written_lines(words):
    lines = json.loads((GAME / "data" / "mod_lines.json").read_text(encoding="utf-8"))["entries"]
    stats = SafetyStats()
    bad = []
    for line in lines:
        text = str(line["text"])
        tag = str(line["tag"])
        if line.get("voice") == "chat" or tag.startswith(("sponsor_window", "gift")):
            continue
        if "{" in text.replace("{name}", ""):
            continue
        r = check_line(text, words)
        stats.note(r)
        if r:
            bad.append((line["id"], r))
    assert stats.checked > 150
    assert len(bad) * 100 < stats.checked, bad
