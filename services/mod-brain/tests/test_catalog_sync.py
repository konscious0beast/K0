"""The service and the game core decide identically: constants in sync with game/core/live/twist_applier.gd, the
shared refusal cases (tests/fixtures/live/twist_cases.json, also run by test_06d_twists.gd) and the catalog."""

from __future__ import annotations

import json
import re

from conftest import GAME, load_fixture
from mod_brain import catalog as C

GD = (GAME / "core" / "live" / "twist_applier.gd").read_text(encoding="utf-8")


def _gd_const(name: str) -> str:
    m = re.search(r"const " + name + r": \w+ = ", GD)
    assert m, name
    i = m.end()
    opener = GD[i]
    closer = {"[": "]", "{": "}"}[opener]
    depth = 0
    for j in range(i, len(GD)):
        if GD[j] == opener:
            depth += 1
        elif GD[j] == closer:
            depth -= 1
            if depth == 0:
                return GD[i:j + 1]
    raise AssertionError(name)


def _gd_json(name: str):
    src = _gd_const(name)
    src = re.sub(r"#[^\n]*", "", src)                         # comments
    src = src.replace("true", "true").replace("false", "false")
    src = re.sub(r",(\s*[}\]])", r"\1", src)                  # trailing commas
    return json.loads(src)


def test_constants_match_the_game_core():
    assert _gd_json("SOURCES") == C.SOURCES
    assert _gd_json("SCOPES") == C.SCOPES
    assert _gd_json("SPICES") == C.SPICES
    assert _gd_json("UNITS") == C.UNITS
    assert _gd_json("IMPLEMENTED") == C.IMPLEMENTED
    assert _gd_json("REASONS") == C.REASONS
    assert _gd_json("DEFAULT_RULES") == C.DEFAULT_RULES
    assert _gd_json("EVENT_OVERRIDES") == C.EVENT_OVERRIDES


def test_summary_vocabularies_match_the_game():
    src = (GAME / "core" / "show" / "mod_live_summary.gd").read_text(encoding="utf-8")
    for name, value in (("EVENT_KINDS", C.EVENT_KINDS), ("KILL_BY", C.KILL_BY), ("PHASES", C.PHASES)):
        m = re.search(r"const " + name + r": PackedStringArray = (\[[^\]]*\])", src, re.S)
        assert m, name
        assert json.loads(re.sub(r"\s+", " ", m.group(1))) == value, name


def test_shared_twist_cases(catalog):
    fx = load_fixture("twist_cases.json")
    seen = set()
    for case in fx["cases"]:
        ctx = dict(fx["base_ctx"])
        ctx.update(case.get("ctx", {}))
        r = dict(case.get("rules", {}))
        rules = {}
        if r.pop("_event", False):
            rules = {"leagues": ["show"], "twists": r}
        elif r:
            rules = {"twists": r}
        tw = case["twist"]
        got = C.refusal_for(catalog.twist(str(tw.get("id", ""))), tw, ctx, C.rules_of(rules))
        assert got == case["expect"], case["name"]
        seen.add(case["expect"])
    assert set(C.REASONS) <= seen, "a shared case for every reason"


def test_catalog_is_the_game_catalog(catalog):
    assert len(catalog.twists) == 20
    assert catalog.slice_ids() == sorted(C.IMPLEMENTED)
    for tid, d in catalog.twists.items():
        for k, b in d.get("params", {}).items():
            assert b["min"] <= b["default"] <= b["max"], (tid, k)
        assert set(d["sources"]) <= set(C.SOURCES), tid
    assert "kai" in catalog.party and "mopsula" in catalog.party
    assert "enm_kanalratte" in catalog.enemies
    assert catalog.filter_words.get("max_len") == 110


def test_bools_are_not_integers():
    d = {"slice": True, "sources": ["mod_brain"], "gameplay": True, "spice": "helpful",
         "params": {"seconds": {"default": 60, "min": 30, "max": 60}}, "duration": {"min": 0, "max": 0}}
    assert not C.params_ok(d, {"params": {"seconds": True}})
    assert C.params_ok(d, {"params": {"seconds": 45.0}})
    assert not C.params_ok(d, {"params": {"seconds": 45.5}})
