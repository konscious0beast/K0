"""The game's catalogs, read from the game data (data/twists.json & co.), and THE twist rules — a line-by-line port of
TwistApplier.refusal_for (game/core/live/twist_applier.gd). The service checks every proposal with exactly the rules
the game core applies (docs/06 §5.7); tests/test_catalog_sync.py keeps the constants in sync with the GDScript source
and runs the shared fixture tests/fixtures/live/twist_cases.json."""

from __future__ import annotations

import copy
import json
import math
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

SOURCES = ["regie", "mod_brain", "vote", "schedule", "dev"]
SCOPES = ["explore", "instant", "battle", "safe_room", "presentation", "room", "boss"]
SPICES = ["helpful", "neutral", "spicy", "none"]
UNITS = ["sec", "battles", "visits", "run", "none"]
IMPLEMENTED = ["tw_lights_out", "tw_quiet_please", "tw_fog_of_fame", "tw_confetti_gravity", "tw_double_credits",
               "tw_overtime", "tw_happy_hour", "tw_rat_rain", "tw_party_hats", "tw_mopsula_moderates",
               "tw_mopsula_monologue"]
REASONS = ["unknown_twist", "not_in_slice", "source_not_allowed", "league_pur", "floor_too_low",
           "params_out_of_range", "sequence_mismatch", "tick_mismatch", "wrong_phase", "busy", "once_per_floor",
           "cooldown", "floor_cap", "spice_budget", "party_weak", "timer_low", "no_target"]
DEFAULT_RULES: dict[str, Any] = {
    "enabled": True,
    "min_floor": 2,
    "sources": ["regie", "mod_brain", "vote", "schedule", "dev"],
    "dev_any_floor": True,
    "max_per_floor": 4,
    "max_spicy_per_floor": 1,
    "gap_sec": 90,
    "spicy_min_party_hp_pct": 50,
    "spicy_min_timer_sec": 180,
    "regie": {"enabled": True, "every_sec": 120, "chance_pm": 350, "max_per_floor": 3, "low_timer_sec": 180,
              "weak_party_hp_pct": 50},
    "schedule": [],
}
EVENT_OVERRIDES: dict[str, Any] = {"sources": ["schedule", "dev"], "regie": {"enabled": False}}

# Request vocabularies (game/core/show/mod_live_summary.gd)
EVENT_KINDS = ["kill", "boss_defeated", "achievement", "level_up", "stunt", "battle_won", "battle_fled", "party_ko",
               "floor_completed", "chest", "twist_applied", "twist_ended", "timer_warning"]
KILL_BY = ["attack", "skill", "stunt", "item", "other"]
PHASES = ["explore", "battle", "safe_room", "waiting", "done"]
VOICES = ["mod", "mopsula", "chat"]


def _is_int(v: Any) -> bool:
    if isinstance(v, bool):
        return False
    if isinstance(v, int):
        return True
    return isinstance(v, float) and math.isfinite(v) and v == math.floor(v)


def _int(v: Any) -> int:
    if isinstance(v, bool):
        return 0
    if isinstance(v, int):
        return v
    if isinstance(v, float) and math.isfinite(v):
        return int(v)
    return 0


def _merge(dst: dict, src: dict) -> None:
    for k, v in src.items():
        if isinstance(dst.get(k), dict) and isinstance(v, dict):
            _merge(dst[k], v)
        else:
            dst[k] = copy.deepcopy(v)


def rules_of(rules: dict | None) -> dict:
    """TwistApplier.rules_of: campaign defaults; event runs (any rules key besides "twists") with EVENT_OVERRIDES;
    then rules["twists"] merged over them."""
    rules = rules or {}
    out = copy.deepcopy(DEFAULT_RULES)
    if rules and not (len(rules) == 1 and "twists" in rules):
        _merge(out, EVENT_OVERRIDES)
    if isinstance(rules.get("twists"), dict):
        _merge(out, rules["twists"])
    return out


def _in_bounds(v: Any, b: Any) -> bool:
    if not _is_int(v) or not isinstance(b, dict):
        return False
    return _int(b.get("min", 0)) <= int(v) <= _int(b.get("max", 0))


def params_ok(def_d: dict, twist: dict) -> bool:
    bounds = def_d.get("params", {}) if isinstance(def_d.get("params"), dict) else {}
    p = twist.get("params", {})
    if p is None:
        p = {}
    if not isinstance(p, dict):
        return False
    for k, v in p.items():
        if str(k) not in bounds or not _in_bounds(v, bounds[str(k)]):
            return False
    if "duration" in twist:
        du = def_d.get("duration", {}) if isinstance(def_d.get("duration"), dict) else {}
        if not _in_bounds(twist["duration"], du):
            return False
    return True


def refusal_for(def_d: dict, twist: dict, ctx: dict, trules: dict) -> str:
    """Port of TwistApplier.refusal_for — same order, same reasons ("" = allowed)."""
    tid = str(twist.get("id", ""))
    if not def_d:
        return "unknown_twist"
    if not def_d.get("slice", False) or tid not in IMPLEMENTED:
        return "not_in_slice"
    src = str(twist.get("src", ""))
    gameplay = bool(def_d.get("gameplay", True))
    regie = trules.get("regie", {}) if isinstance(trules.get("regie"), dict) else {}
    if (src not in [str(s) for s in def_d.get("sources", [])] or src not in [str(s) for s in trules.get("sources", [])]
            or not trules.get("enabled", True) or (src == "regie" and not regie.get("enabled", True))):
        return "source_not_allowed"
    if gameplay and str(ctx.get("league", "")) == "pur":
        return "league_pur"
    if (_int(ctx.get("floor", 1)) < _int(trules.get("min_floor", 2))
            and not (src == "dev" and bool(trules.get("dev_any_floor", False)))):
        return "floor_too_low"
    if not params_ok(def_d, twist):
        return "params_out_of_range"
    if "n" in twist and _int(twist["n"]) != _int(ctx.get("next_n", 1)):
        return "sequence_mismatch"
    if "tick" in twist and _int(twist["tick"]) != _int(ctx.get("now_tick", 0)):
        return "tick_mismatch"
    if str(ctx.get("phase", "")) != "explore":
        return "wrong_phase"
    for a in ctx.get("active", []) or []:
        if isinstance(a, dict) and (str(a.get("id", "")) == tid or (gameplay and bool(a.get("gameplay", False)))):
            return "busy"
    if def_d.get("once_per_floor", False) and tid in [str(x) for x in ctx.get("once", []) or []]:
        return "once_per_floor"
    if not gameplay:
        return ""
    since = _int(ctx.get("since_end_sec", -1))
    if 0 <= since < _int(trules.get("gap_sec", 90)):
        return "cooldown"
    if (_int(ctx.get("floor_count", 0)) >= _int(trules.get("max_per_floor", 4))
            or (src == "regie" and _int(ctx.get("floor_regie", 0)) >= _int(regie.get("max_per_floor", 3)))):
        return "floor_cap"
    if str(def_d.get("spice", "")) == "spicy":
        if _int(ctx.get("floor_spicy", 0)) >= _int(trules.get("max_spicy_per_floor", 1)):
            return "spice_budget"
        if _int(ctx.get("party_hp_pct", 100)) < _int(trules.get("spicy_min_party_hp_pct", 50)):
            return "party_weak"
        if _int(ctx.get("timer_sec", 0)) < _int(trules.get("spicy_min_timer_sec", 180)):
            return "timer_low"
    if tid == "tw_rat_rain" and not bool(ctx.get("stray_zone_free", False)):
        return "no_target"
    return ""


def _read(path: Path) -> dict:
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    if not isinstance(data, dict):
        raise ValueError(f"{path}: expected a JSON object")
    return data


def _ids(data: dict) -> set[str]:
    return {str(e.get("id", "")) for e in data.get("entries", []) if isinstance(e, dict)}


@dataclass
class Catalog:
    """Ids the service accepts in a request and the twist definitions (TwistDef.to_dict shape)."""

    twists: dict[str, dict] = field(default_factory=dict)
    enemies: set[str] = field(default_factory=set)
    achievements: set[str] = field(default_factory=set)
    party: set[str] = field(default_factory=set)
    marotten: set[str] = field(default_factory=set)
    filter_words: dict = field(default_factory=dict)
    example_lines: list[dict] = field(default_factory=list)

    @staticmethod
    def load(data_dir: Path) -> "Catalog":
        d = Path(data_dir)
        tw = _read(d / "twists.json")
        twists = {}
        for e in tw.get("entries", []):
            if isinstance(e, dict) and str(e.get("id", "")).startswith("tw_"):
                twists[str(e["id"])] = e
        mar = d / "marotten.json"          # package C (06-C); optional until merged
        lines = _read(d / "mod_lines.json").get("entries", [])
        return Catalog(
            twists=dict(sorted(twists.items())),
            enemies=_ids(_read(d / "enemies.json")),
            achievements=_ids(_read(d / "achievements.json")),
            party=_ids(_read(d / "party.json")),
            marotten=_ids(_read(mar)) if mar.exists() else set(),
            filter_words=_read(d / "mod_filter.json"),
            example_lines=[x for x in lines if isinstance(x, dict)],
        )

    def twist(self, twist_id: str) -> dict:
        return self.twists.get(twist_id, {})

    def slice_ids(self) -> list[str]:
        return sorted(i for i, d in self.twists.items() if d.get("slice", False) and i in IMPLEMENTED)
