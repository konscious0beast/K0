"""HTTP surface of mod-brain (docs/06 §5.3/§5.4/§5.10). Start: ``uvicorn mod_brain.app:app --port 8787``.

GET  /healthz            → {"ok", "kill_switch", "budget_exhausted"}
POST /v1/auth/token      {"platform", "ticket", "run_ref"} → {"token", "expires_in"} (platform auth required)
POST /v1/mod/turn        Bearer token, ModLiveSummary request (≤ 8 KB) → {"lines", "twist", "mood"}
POST /v1/mod/director    same, route "director" (live shows: one Regie per broadcast)

Errors: 400 (schema / unknown id / free text), 401 (no / bad / expired token or wrong run), 413 (> 8 KB), 429
(account caps). A failing Claude call is NOT an error: it is an empty round (200)."""

from __future__ import annotations

import json
from typing import Any

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from pydantic import ValidationError
from starlette.concurrency import run_in_threadpool

from .auth import ChainVerifier, DevVerifier, PlatformVerifier, SteamVerifier, TokenIssuer
from .brain import ModBrain
from .budget import Budget
from .catalog import Catalog
from .config import Config
from .rate_limit import RateLimiter
from .schema import RUN_REF_RE, TokenRequest, TurnRequest, catalog_errors


def _error(code: int, msg: str) -> JSONResponse:
    return JSONResponse(status_code=code, content={"error": msg})


async def _body(request: Request, limit: int) -> Any:
    raw = await request.body()
    if len(raw) > limit:
        return 413
    try:
        return json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError):
        return 400


def create_app(cfg: Config | None = None, client: Any = None, verifier: PlatformVerifier | None = None,
               catalog: Catalog | None = None, limiter: RateLimiter | None = None,
               budget: Budget | None = None) -> FastAPI:
    """App factory. Production: everything from the environment; tests inject a mocked client, verifier, clock."""
    cfg = cfg or Config.from_env()
    catalog = catalog or Catalog.load(cfg.data_dir)
    if client is None and cfg.demo:
        from .demo import DemoClient        # offline: no key, no costs (local development, smoke tests)
        client = DemoClient()
    if client is None:
        import anthropic                    # credentials: ANTHROPIC_API_KEY / ANTHROPIC_AUTH_TOKEN / ant auth profile
        client = anthropic.Anthropic()
    issuer = TokenIssuer(cfg.token_secret, cfg.token_ttl_sec)
    verifier = verifier or ChainVerifier(DevVerifier(cfg.dev_mode, cfg.dev_hosts), SteamVerifier())
    limiter = limiter or RateLimiter(cfg.rate_per_hour, cfg.rate_per_day, cfg.burst_per_min)
    brain = ModBrain(cfg, catalog, client, budget=budget)
    app = FastAPI(title="mod-brain", version="0.1.0", docs_url=None, redoc_url=None)
    app.state.brain = brain
    app.state.issuer = issuer
    app.state.limiter = limiter

    @app.get("/healthz")
    def healthz() -> dict:
        return {"ok": True, "kill_switch": cfg.kill_switch, "budget_exhausted": brain.budget.exhausted()}

    @app.post("/v1/auth/token")
    async def token(request: Request) -> JSONResponse:
        body = await _body(request, 4096)
        if isinstance(body, int):
            return _error(body, "bad request")
        try:
            tr = TokenRequest.model_validate(body)
        except ValidationError:
            return _error(400, "schema")
        if not RUN_REF_RE.match(tr.run_ref):
            return _error(400, "run_ref")
        host = request.client.host if request.client else ""
        account = verifier.verify(tr.platform, tr.ticket, host)
        if not account:
            return _error(401, "platform authentication failed")
        return JSONResponse({"token": issuer.issue(account, tr.run_ref), "expires_in": issuer.ttl})

    async def _round(request: Request, route: str) -> JSONResponse:
        body = await _body(request, cfg.max_body_bytes)
        if isinstance(body, int):
            return _error(body, "request too large" if body == 413 else "bad request")
        try:
            req = TurnRequest.model_validate(body)
        except ValidationError:
            return _error(400, "schema")
        errs = catalog_errors(req, catalog)
        if errs:
            return _error(400, "unknown ids: " + ", ".join(errs[:5]))
        auth = request.headers.get("authorization", "")
        claims = issuer.verify(auth[7:], req.run_ref) if auth.lower().startswith("bearer ") else {}
        if not claims:
            return _error(401, "token")
        cap = limiter.check(str(claims["acc"]))
        if cap:
            return _error(429, "rate limit: " + cap)
        resp = await run_in_threadpool(brain.turn, req, str(claims["acc"]), route)
        return JSONResponse(resp.model_dump())

    @app.post("/v1/mod/turn")
    async def turn(request: Request) -> JSONResponse:
        return await _round(request, "lines")

    @app.post("/v1/mod/director")
    async def director(request: Request) -> JSONResponse:
        return await _round(request, "director")

    return app


def __getattr__(name: str) -> Any:
    # `uvicorn mod_brain.app:app` builds the production app lazily (tests import create_app without credentials)
    if name == "app":
        return create_app()
    raise AttributeError(name)
