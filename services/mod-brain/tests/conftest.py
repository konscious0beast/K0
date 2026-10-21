"""Shared fixtures. No test ever calls the real Claude API: the Anthropic client is a fake (FakeClient) or the real
SDK on an httpx2.MockTransport that never leaves the process."""

from __future__ import annotations

import copy
import json
import sys
from pathlib import Path
from types import SimpleNamespace
from typing import Any

import pytest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from mod_brain.catalog import Catalog  # noqa: E402
from mod_brain.config import DEFAULT_DATA_DIR, Config  # noqa: E402
from mod_brain.schema import ModTurnOut, OutLine, OutParam, OutTwist  # noqa: E402

GAME = ROOT.parents[1] / "prime-time-dungeon" / "game"
FIXTURES = GAME / "tests" / "fixtures" / "live"


@pytest.fixture(scope="session")
def catalog() -> Catalog:
    return Catalog.load(DEFAULT_DATA_DIR)


@pytest.fixture()
def cfg() -> Config:
    return Config(token_secret="test-secret-not-a-real-one", dev_mode=True, dev_hosts=("testclient",),
                  monthly_budget_usd=50.0)


def make_request(**over: Any) -> dict:
    """A valid ModLiveSummary request (what the game sends)."""
    req = {
        "schema": 1, "req_id": "r_000001", "run_ref": "rr_0123456789abcdef", "lang": "de",
        "state": {"floor": 2, "timer_sec": 900, "hype": 55, "viewers_k": 3, "hero": "kai", "liga_tier": 0,
                  "party": [{"id": "kai", "lvl": 5, "hp_pct": 80}, {"id": "mopsula", "lvl": 5, "hp_pct": 70}],
                  "bets": [], "phase": "explore"},
        "events": [{"t": "kill", "id": "enm_kanalratte", "by": "stunt", "member": "kai"},
                   {"t": "level_up", "member": "mopsula", "level": 5}],
        "recent_line_ids": [],
        "allowed_twists_hint": ["tw_lights_out", "tw_overtime", "tw_quiet_please", "tw_rat_rain"],
        "spice_left_hint": 1,
        "last_twist_result": "",
    }
    for k, v in over.items():
        if k == "state":
            req["state"].update(v)
        else:
            req[k] = v
    return copy.deepcopy(req)


def out(lines: list[tuple[str, str, str]] | None = None, twist: tuple[str, dict] | None = None,
        mood: str = "snarky") -> ModTurnOut:
    return ModTurnOut(
        lines=[OutLine(text=t, tag=g, voice=v) for t, g, v in (lines or [])],
        twist=OutTwist(id=twist[0], params=[OutParam(name=k, value=v) for k, v in twist[1].items()]) if twist else None,
        mood=mood)


class FakeMessages:
    def __init__(self, owner: "FakeClient", beta: bool) -> None:
        self.owner = owner
        self.beta = beta

    def parse(self, **kwargs: Any) -> Any:
        self.owner.calls.append({"beta": self.beta, "options": dict(self.owner.options), **kwargs})
        r = self.owner.responses.pop(0) if self.owner.responses else self.owner.default
        if isinstance(r, Exception):
            raise r
        return r


class FakeClient:
    """Stands in for anthropic.Anthropic: with_options + messages.parse / beta.messages.parse, recording calls."""

    def __init__(self) -> None:
        self.calls: list[dict] = []
        self.responses: list[Any] = []
        self.options: dict = {}
        self.default = response(out([("Ein Stunt mit Wischmopp. Ich lasse das als Kunst durchgehen.", "stunt", "mod")]))
        self.messages = FakeMessages(self, False)
        self.beta = SimpleNamespace(messages=FakeMessages(self, True))

    def with_options(self, **opts: Any) -> "FakeClient":
        self.options = opts
        return self


def response(parsed: ModTurnOut | None, stop_reason: str = "end_turn", usage: dict | None = None) -> Any:
    u = usage or {"input_tokens": 900, "output_tokens": 350, "cache_read_input_tokens": 4000,
                  "cache_creation_input_tokens": 0}
    return SimpleNamespace(parsed_output=parsed, stop_reason=stop_reason, usage=SimpleNamespace(**u))


@pytest.fixture()
def fake_client() -> FakeClient:
    return FakeClient()


def load_fixture(name: str) -> dict:
    with open(FIXTURES / name, encoding="utf-8") as f:
        return json.load(f)
