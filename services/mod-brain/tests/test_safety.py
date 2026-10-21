"""Content safety post-filter: the same verdicts as the game's ModLineFilter (shared cases), the co-occurrence rule for
purchase pressure, politics / slur / sexual / brand blocks, the polish pass's IP / tone lists (Fan-Box, Feinripp,
foot words, nationalities, no royalty for Graf Mopsula), the language check, and the false-alarm rate on the written
M.O.D. lines (S1 gate: < 1 %)."""

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
        assert check_line(case["text"], words, case.get("voice", "")) == case["expect"], case["text"]


@pytest.mark.parametrize("text,reason", [
    ("Schnellschnitt!", ""),
    ("Schnell, Sponsor-Fenster!", "purchase_pressure"),
    ("Nur noch zwei Räume bis zur Treppe, ich zähle mit.", ""),
    ("Nur noch drei Geschenke im Fenster, beeilen Sie sich.", "purchase_pressure"),
    ("Die Bundesregierung schaut heute auch zu, sagt man.", "blocked_politics"),
    ("Das war ein schlampiger Kampf, ehrlich gesagt.", ""),     # 'schlampiger' is not the stem 'schlampe*'
    ("So eine Schlampe von Ratte habe ich noch nie gesehen.", "blocked_slurs"),
    ("Das war nackter Wahnsinn, ehrlich gesagt.", "blocked_sexual"),        # prefix stems are strict on purpose
    ("Zwei Fanboxen auf einmal, die Fans sind großzügig.", "blocked_ip_distance"),      # "fanbox*" prefix
    ("Die Handschuhe bleiben heute im Spind.", "blocked_ip_distance"),                  # "*schuh*" anywhere
    ("Ein Russe, ein Pole und ein Mops gehen in einen Dungeon.", "blocked_origin"),
    ("Russland? Nie gehört. Hier ist nur die Unterstadt.", ""),                         # whole words only
    ("Der Graf thront auf dem Sofa und doziert.", "blocked_mopsula_royalty"),           # "*thron*" anywhere
    ("Die Rattenkönigin rückt ihre Krone zurecht.", ""),                                # no Mopsula, no rule
])
def test_examples(words, text, reason):
    assert check_line(text, words) == reason


def test_mopsula_rule_needs_his_voice_or_his_name(words):
    text = "Eine Krone aus Fahrscheinen, sehr elegant."
    assert check_line(text, words, "mod") == ""
    assert check_line(text, words, "chat") == ""
    assert check_line(text, words, "mopsula") == "blocked_mopsula_royalty"
    assert check_line("Der Mops und eine Krone aus Fahrscheinen.", words, "mod") == "blocked_mopsula_royalty"


def test_wildcards(words):
    lists = {"max_len": 110, "lang_min_words": 99, "lang_de_min_words": 99,     # word rules only
             "blocked": {"politics": ["*part*", "end", "stem*", "*tail", "zwei worte"]}}
    assert check_line("Das ist ein Apartment hier.", lists) == "blocked_politics"
    assert check_line("Das ist ein Stemmeisen hier.", lists) == "blocked_politics"
    assert check_line("Das ist ein Cocktail hier.", lists) == "blocked_politics"
    assert check_line("Das ist ein Ende hier.", lists) == ""                    # exact words stay exact
    assert check_line("Das sind zwei Worte hier.", lists) == "blocked_politics"
    assert check_line("Das sind zwei, drei Worte hier.", lists) == ""


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
