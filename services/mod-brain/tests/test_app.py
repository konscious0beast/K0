"""The HTTP surface end to end (FastAPI TestClient, mocked Anthropic client): token against platform auth, a round,
401 / 400 / 413 / 429."""

from __future__ import annotations

import json

import pytest
from fastapi.testclient import TestClient

from conftest import FakeClient, make_request
from mod_brain.app import create_app
from mod_brain.rate_limit import RateLimiter


@pytest.fixture()
def app_client(cfg, catalog):
    fake = FakeClient()
    app = create_app(cfg, client=fake, catalog=catalog, limiter=RateLimiter(90, 400, 3))
    return TestClient(app), fake


def _token(tc, run_ref="rr_0123456789abcdef") -> str:
    r = tc.post("/v1/auth/token", json={"platform": "dev", "ticket": "local-dev", "run_ref": run_ref})
    assert r.status_code == 200, r.text
    return r.json()["token"]


def test_health(app_client):
    tc, _ = app_client
    assert tc.get("/healthz").json() == {"ok": True, "kill_switch": False, "budget_exhausted": False}


def test_round_end_to_end(app_client):
    tc, fake = app_client
    tok = _token(tc)
    r = tc.post("/v1/mod/turn", json=make_request(), headers={"Authorization": "Bearer " + tok})
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["lines"][0]["tag"] == "stunt" and body["lines"][0]["line_id"].startswith("l_")
    assert body["twist"] is None and body["mood"] == "snarky"
    assert len(fake.calls) == 1


def test_auth_failures(app_client):
    tc, fake = app_client
    assert tc.post("/v1/mod/turn", json=make_request()).status_code == 401
    assert tc.post("/v1/mod/turn", json=make_request(), headers={"Authorization": "Bearer nope"}).status_code == 401
    other = _token(tc, "rr_ffffffffffffffff")
    assert tc.post("/v1/mod/turn", json=make_request(),
                   headers={"Authorization": "Bearer " + other}).status_code == 401, "token bound to its run"
    r = tc.post("/v1/auth/token", json={"platform": "steam", "ticket": "x", "run_ref": "rr_0123456789abcdef"})
    assert r.status_code == 401, "no Steam auth wired up in S0/S1"
    assert fake.calls == []


def test_bad_requests(app_client):
    tc, fake = app_client
    tok = {"Authorization": "Bearer " + _token(tc)}
    assert tc.post("/v1/mod/turn", content=b"{not json", headers=tok).status_code == 400
    assert tc.post("/v1/mod/turn", json=make_request(state={"hero": "Robin"}), headers=tok).status_code == 400
    big = make_request()
    big["padding"] = "x" * 9000
    assert tc.post("/v1/mod/turn", content=json.dumps(big).encode(), headers=tok).status_code == 413
    assert fake.calls == []


def test_rate_limit_429(app_client):
    tc, _ = app_client
    tok = {"Authorization": "Bearer " + _token(tc)}
    codes = [tc.post("/v1/mod/turn", json=make_request(), headers=tok).status_code for _ in range(4)]
    assert codes == [200, 200, 200, 429], "burst 3 per minute"


def test_dev_tokens_only_in_dev_mode(catalog):
    from mod_brain.config import Config
    app = create_app(Config(token_secret="s", dev_mode=False, dev_hosts=("testclient",)), client=FakeClient(),
                     catalog=catalog)
    tc = TestClient(app)
    r = tc.post("/v1/auth/token", json={"platform": "dev", "ticket": "local-dev", "run_ref": "rr_0123456789abcdef"})
    assert r.status_code == 401


def test_demo_mode_runs_offline(catalog):
    from mod_brain.config import Config
    app = create_app(Config(token_secret="s", dev_mode=True, dev_hosts=("testclient",), demo=True), catalog=catalog)
    tc = TestClient(app)
    tok = _token(tc)
    r = tc.post("/v1/mod/turn", json=make_request(), headers={"Authorization": "Bearer " + tok})
    assert r.status_code == 200
    assert r.json()["lines"][0]["tag"] == "level_up", "canned line for the newest known event"
