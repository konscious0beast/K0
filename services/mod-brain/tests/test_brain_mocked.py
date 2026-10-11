"""One round with a mocked Anthropic client: the request form (model per route, adaptive thinking, effort "low",
JSON-schema structured output, cache_control on the last system block, byte-identical system prompt, no player name,
deadline / retries per route, server-side fallbacks), every failure path → empty round, the safety filter on the
output, and the server-side twist rules (hint ∩ catalog ∩ rules, spice budget, bounds, one twist per 90 s). Plus the
real SDK on an httpx2.MockTransport to check the wire format — no request ever leaves the process."""

from __future__ import annotations

import json

import anthropic
import httpx2
import pytest

from conftest import FakeClient, make_request, out, response
from mod_brain.brain import FALLBACK_BETA, ModBrain
from mod_brain.config import Config
from mod_brain.line_store import LineStore
from mod_brain.schema import TurnRequest


def _req(**over) -> TurnRequest:
    return TurnRequest.model_validate(make_request(**over))


def test_request_form(cfg, catalog, fake_client):
    brain = ModBrain(cfg, catalog, fake_client)
    brain.turn(_req(), "acc")
    brain.turn(_req(req_id="r_000002", events=[]), "acc")
    a, b = fake_client.calls
    assert a["model"] == "claude-opus-5-5"
    assert a["thinking"] == {"type": "adaptive"}
    assert a["output_config"] == {"effort": "low"}
    assert a["output_format"].__name__ == "ModTurnOut", "structured output via messages.parse"
    assert a["options"] == {"timeout": 4.0, "max_retries": 0}, "lines route: 4 s deadline, no retries"
    assert a["beta"] and a["betas"] == [FALLBACK_BETA] and a["fallbacks"] == "default"
    sys_a, sys_b = a["system"], b["system"]
    assert sys_a[-1]["cache_control"] == {"type": "ephemeral"}, "breakpoint on the last system block"
    assert json.dumps(sys_a, sort_keys=True) == json.dumps(sys_b, sort_keys=True), "byte-identical across rounds"
    assert len(sys_a[-1]["text"]) > 4 * 512, "above the 512-token cache minimum of Opus 5.5"
    assert a["messages"][0]["role"] == "user" and len(a["messages"]) == 1, "stateless: one user message per round"
    assert a["messages"][0]["content"] != b["messages"][0]["content"], "variable data only in the user message"


def test_model_and_effort_per_route(catalog, fake_client):
    cfg = Config(token_secret="x", model="claude-opus-5-5", model_lines="claude-haiku-5-5", effort="low",
                 effort_director="medium")
    brain = ModBrain(cfg, catalog, fake_client)
    brain.turn(_req(), "acc", route="lines")
    brain.turn(_req(), "acc", route="director")
    lines, director = fake_client.calls
    assert lines["model"] == "claude-haiku-5-5" and not lines["beta"] and "fallbacks" not in lines, \
        "Haiku 5.5 has no server-side fallback"
    assert director["model"] == "claude-opus-5-5"
    assert director["output_config"] == {"effort": "medium"}
    assert director["options"] == {"timeout": 8.0, "max_retries": 1}


def test_no_player_name_and_no_client_text_in_the_prompt(cfg, catalog, fake_client):
    brain = ModBrain(cfg, catalog, fake_client)
    brain.turn(_req(), "acc")
    prompt = json.dumps(fake_client.calls[0]["messages"]) + json.dumps(fake_client.calls[0]["system"])
    assert "{name}" in prompt, "only the placeholder"
    for forbidden in ("Robin", "player_name", "sender", "chat"):
        assert forbidden not in json.dumps(fake_client.calls[0]["messages"]), forbidden


def test_prompt_holds_only_server_stored_lines(cfg, catalog, fake_client):
    store = LineStore()
    brain = ModBrain(cfg, catalog, fake_client, store=store)
    first = brain.turn(_req(), "acc")
    lid = first.lines[0].line_id
    brain.turn(_req(req_id="r_000002", recent_line_ids=[lid, "l_ffffffffffff"]), "acc")
    user = fake_client.calls[1]["messages"][0]["content"]
    assert "Ein Stunt mit Wischmopp" in user, "the service's own earlier line (from its store)"
    assert "l_ffffffffffff" not in user and lid not in user, "ids are never prompt text"


@pytest.mark.parametrize("failure", [
    anthropic.APITimeoutError(request=httpx2.Request("POST", "https://api.anthropic.com/v1/messages")),
    anthropic.APIConnectionError(request=httpx2.Request("POST", "https://api.anthropic.com/v1/messages")),
    ValueError("invalid json"),
])
def test_failures_are_empty_rounds(cfg, catalog, failure):
    client = FakeClient()
    client.responses = [failure]
    brain = ModBrain(cfg, catalog, client)
    r = brain.turn(_req(), "acc")
    assert r.lines == [] and r.twist is None
    assert brain.last.outcome == "error"


def test_refusal_and_invalid_output_are_empty_rounds(cfg, catalog):
    client = FakeClient()
    client.responses = [response(None, stop_reason="refusal"), response(None)]
    brain = ModBrain(cfg, catalog, client)
    assert brain.turn(_req(), "acc").lines == [] and brain.last.outcome == "refusal"
    assert brain.turn(_req(), "acc").lines == [] and brain.last.outcome == "invalid"


def test_kill_switch(catalog, fake_client):
    brain = ModBrain(Config(token_secret="x", kill_switch=True), catalog, fake_client)
    assert brain.turn(_req(), "acc").lines == []
    assert fake_client.calls == []


def test_output_lines_are_filtered(cfg, catalog):
    client = FakeClient()
    client.responses = [response(out([
        ("Ein Stunt mit Wischmopp. Ich lasse das als Kunst durchgehen.", "stunt", "mod"),
        ("x" * 111, "long", "mod"),
        ("Schnell, das Sponsor-Fenster ist offen!", "promo", "mod"),
        ("Die Partei der Ratten jubelt heute ganz besonders laut.", "pol", "mod"),
        ("Noch eine vierte Zeile, die schon zu viel ist.", "x", "chat")]))]
    brain = ModBrain(cfg, catalog, client)
    r = brain.turn(_req(), "acc")
    assert [x.tag for x in r.lines] == ["stunt"]
    assert brain.last.dropped_lines == ["too_long", "purchase_pressure"], "max 3 lines are even considered"
    assert r.lines[0].line_id.startswith("l_")


def test_bad_tags_become_live(cfg, catalog):
    client = FakeClient()
    client.responses = [response(out([("Ein Stunt mit Wischmopp. Ich lasse das als Kunst durchgehen.", "Bad Tag!",
                                       "mopsula")]))]
    r = ModBrain(cfg, catalog, client).turn(_req(), "acc")
    assert r.lines[0].tag == "live" and r.lines[0].voice == "mopsula"


def test_twist_must_be_allowed_and_bounded(cfg, catalog):
    client = FakeClient()
    client.responses = [response(out(twist=("tw_lights_out", {"enemy_sight_pm": 450}))),
                        response(out(twist=("tw_quiet_please", {"enemy_hear_pm": 100}))),
                        response(out(twist=("tw_elite_guest", {}))),
                        response(out(twist=("tw_fog_of_fame", {})))]
    clock = [0.0]
    brain = ModBrain(cfg, catalog, client, clock=lambda: clock[0])
    r = brain.turn(_req(), "acc")
    assert r.twist is not None and r.twist.id == "tw_lights_out" and r.twist.params == {"enemy_sight_pm": 450}
    clock[0] += 10
    assert brain.allowed_twists(_req(), brain.twist_context(_req()), {}) == [], "one twist per 90 s"
    clock[0] += 100
    r2 = brain.turn(_req(), "acc")
    assert r2.twist is None and brain.last.twist_refusal == "params_out_of_range"
    clock[0] += 100
    assert brain.turn(_req(), "acc").twist is None and brain.last.twist_refusal == "not_allowed_now", \
        "not in the slice / not in the hint"
    clock[0] += 100
    assert brain.turn(_req(), "acc").twist is None, "tw_fog_of_fame was not in the client's hint"


def test_server_twist_rules(cfg, catalog, fake_client):
    brain = ModBrain(cfg, catalog, fake_client)
    assert brain.allowed_twists(_req(), brain.twist_context(_req()), {"sources": ["mod_brain"], "min_floor": 2,
                                "enabled": True}) != []
    from mod_brain.catalog import rules_of
    tr = rules_of({})
    floor1 = _req(state={"floor": 1})
    assert brain.allowed_twists(floor1, brain.twist_context(floor1), tr) == [], "never on floor 1"
    weak = _req(state={"party": [{"id": "kai", "lvl": 5, "hp_pct": 20}, {"id": "mopsula", "lvl": 5, "hp_pct": 30}]})
    assert "tw_rat_rain" not in brain.allowed_twists(weak, brain.twist_context(weak), tr), "never kick a weak party"
    battle = _req(state={"phase": "battle"})
    assert brain.allowed_twists(battle, brain.twist_context(battle), tr) == [], "never in battle"
    client = FakeClient()
    client.responses = [response(out(twist=("tw_rat_rain", {})))]
    clock = [0.0]
    b2 = ModBrain(cfg, catalog, client, clock=lambda: clock[0])
    assert b2.turn(_req(), "acc").twist.id == "tw_rat_rain"
    assert b2.store.memory("rr_0123456789abcdef").spicy_by_floor == {2: 1}, "spice budget booked per floor"
    clock[0] += 100
    ctx = b2.twist_context(_req())
    assert ctx["floor_spicy"] == 1
    allowed = b2.allowed_twists(_req(), ctx, tr)
    assert "tw_rat_rain" not in allowed and "tw_lights_out" in allowed, "≤ 1 spicy twist per floor"
    other_floor = _req(state={"floor": 3})
    assert "tw_rat_rain" in b2.allowed_twists(other_floor, b2.twist_context(other_floor), tr), "per floor"


def test_wire_format_with_the_real_sdk(cfg, catalog):
    """The official SDK serializes our call as intended (mock transport, nothing leaves the process)."""
    seen = []

    def handler(req: httpx2.Request) -> httpx2.Response:
        seen.append((req.headers, json.loads(req.content)))
        body = {"id": "msg_1", "type": "message", "role": "assistant", "model": "claude-opus-5-5",
                "stop_reason": "end_turn", "stop_sequence": None,
                "content": [{"type": "text", "text": json.dumps(
                    {"lines": [{"text": "Ein Stunt mit Wischmopp. Ich lasse das als Kunst durchgehen.", "tag": "stunt",
                                "voice": "mod"}], "twist": None, "mood": "snarky"})}],
                "usage": {"input_tokens": 900, "output_tokens": 300, "cache_read_input_tokens": 4000,
                          "cache_creation_input_tokens": 0}}
        return httpx2.Response(200, json=body)

    client = anthropic.Anthropic(api_key="test-key-not-real",
                                 http_client=anthropic.DefaultHttpxClient(transport=httpx2.MockTransport(handler)))
    brain = ModBrain(cfg, catalog, client)
    r = brain.turn(_req(), "acc")
    assert [x.tag for x in r.lines] == ["stunt"]
    headers, body = seen[0]
    assert headers["anthropic-beta"] == FALLBACK_BETA
    assert body["model"] == "claude-opus-5-5" and body["fallbacks"] == "default"
    assert body["thinking"] == {"type": "adaptive"}
    assert body["output_config"]["effort"] == "low"
    fmt = body["output_config"]["format"]
    assert fmt["type"] == "json_schema" and fmt["schema"]["additionalProperties"] is False
    assert set(fmt["schema"]["required"]) == {"lines", "twist", "mood"}
    assert body["system"][-1]["cache_control"] == {"type": "ephemeral"}
    assert brain.last.usd > 0 and brain.budget.per_run["rr_0123456789abcdef"] > 0
