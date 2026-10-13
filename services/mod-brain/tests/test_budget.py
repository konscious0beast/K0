"""Costs per round, the cost log per run_ref, the 80 % warning and the automatic kill switch at 100 % (empty rounds,
no API call), month rollover."""

from __future__ import annotations

import json

from conftest import make_request
from mod_brain.brain import ModBrain
from mod_brain.budget import Budget, round_cost
from mod_brain.schema import TurnRequest


def test_round_cost_uses_cache_prices():
    usage = {"input_tokens": 900, "output_tokens": 350, "cache_read_input_tokens": 4000,
             "cache_creation_input_tokens": 0}
    usd = round_cost("claude-opus-5-5", usage)
    assert abs(usd - (900 * 4 + 350 * 20 + 4000 * 0.20) / 1e6) < 1e-12
    assert round_cost("claude-haiku-5-5", usage) < usd / 20
    write = round_cost("claude-opus-5-5", {"cache_creation_input_tokens": 1_000_000})
    assert abs(write - 5.0) < 1e-9, "cache writes 1.25 × input"


def test_cost_log_per_run(tmp_path):
    clock = [1_700_000_000.0]
    b = Budget(monthly_usd=1.0, log_path=str(tmp_path / "cost.jsonl"), clock=lambda: clock[0])
    b.book("rr_a", "acc1", "claude-opus-5-5", {"input_tokens": 1000, "output_tokens": 100})
    b.book("rr_b", "acc1", "claude-opus-5-5", {"input_tokens": 1000, "output_tokens": 100})
    assert set(b.per_run) == {"rr_a", "rr_b"}
    lines = (tmp_path / "cost.jsonl").read_text().strip().split("\n")
    assert [json.loads(x)["run_ref"] for x in lines] == ["rr_a", "rr_b"]
    assert not b.warning()


def test_warning_and_kill_switch_then_month_rollover(cfg, catalog, fake_client):
    clock = [1_700_000_000.0]
    budget = Budget(monthly_usd=0.02, clock=lambda: clock[0])
    brain = ModBrain(cfg, catalog, fake_client, budget=budget)
    req = TurnRequest.model_validate(make_request())
    rounds = 0
    while not budget.exhausted():
        assert brain.turn(req, "acc").lines, "a normal round"
        rounds += 1
        assert rounds < 50
    assert budget.warning() and budget.state.warned
    calls = len(fake_client.calls)
    r = brain.turn(req, "acc")
    assert r.lines == [] and r.twist is None
    assert brain.last.outcome == "empty_budget"
    assert len(fake_client.calls) == calls, "no API call once the budget is spent"
    clock[0] += 40 * 86400                 # next month
    assert not budget.exhausted()
    assert brain.turn(req, "acc").lines
