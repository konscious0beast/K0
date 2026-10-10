"""One "M.O.D. live" round (docs/06 §5.3–§5.5): validated request → server-side twist context → Claude (structured
output, cached system prompt, adaptive thinking at effort "low", deadline 4 s, no retries on the lines route) →
safety filter → twist validation with the game's own rules → response. Every failure path (timeout, connection,
API error, refusal, malformed output, budget, kill switch) is an EMPTY round: the game's written M.O.D. keeps
talking and nobody notices."""

from __future__ import annotations

import logging
import time
from dataclasses import dataclass, field
from typing import Any, Callable

from . import persona
from .budget import Budget
from .catalog import VOICES, Catalog, refusal_for, rules_of
from .config import Config
from .line_store import LineStore
from .safety import SafetyStats, check_line
from .schema import TAG_RE, ModTurnOut, RespLine, RespTwist, TurnRequest, TurnResponse

log = logging.getLogger("mod_brain")

FALLBACK_BETA = "server-side-fallback-2026-07-01"
MAX_LINES = 3


@dataclass
class RoundInfo:
    """What happened in the last round (tests, metrics)."""

    outcome: str = ""            # ok | empty_kill | empty_budget | refusal | error | invalid
    model: str = ""
    usd: float = 0.0
    dropped_lines: list[str] = field(default_factory=list)
    twist_refusal: str = ""
    allowed: list[str] = field(default_factory=list)


class ModBrain:
    def __init__(self, cfg: Config, catalog: Catalog, client: Any, budget: Budget | None = None,
                 store: LineStore | None = None, clock: Callable[[], float] = time.monotonic) -> None:
        self.cfg = cfg
        self.catalog = catalog
        self.client = client
        self.budget = budget or Budget(cfg.monthly_budget_usd, cfg.cost_log)
        self.store = store or LineStore(clock=clock)
        self.clock = clock
        self.system_prompt = persona.build_system_prompt(catalog)    # built once: byte-stable for caching
        self.safety = SafetyStats()
        self.last = RoundInfo()

    # --- the twist context the service can know ----------------------------------------------------------------------

    def twist_context(self, req: TurnRequest) -> dict:
        """TwistApplier.context from the request (validated numbers) + the service's own per-run counters. Active
        twists / cooldowns are only known to the game — its allowed_twists_hint reflects them and the game checks
        every proposal again."""
        st = req.state
        party_hp = sum(p.hp_pct for p in st.party) // len(st.party) if st.party else 100
        mem = self.store.memory(req.run_ref)
        return {"floor": st.floor, "league": "", "phase": st.phase, "timer_sec": st.timer_sec,
                "party_hp_pct": party_hp, "active": [], "next_n": 1, "now_tick": 0, "floor_count": 0,
                "floor_spicy": mem.spicy_by_floor.get(st.floor, 0), "floor_regie": 0, "since_end_sec": -1,
                "once": [], "stray_zone_free": True}

    def allowed_twists(self, req: TurnRequest, ctx: dict, trules: dict) -> list[str]:
        """Slice twists ∩ the client's hint ∩ the rules (source mod_brain) — and none within twist_gap_sec of the
        run's last proposal (1 twist / 90 s)."""
        mem = self.store.memory(req.run_ref)
        if self.clock() - mem.last_twist_at < self.cfg.twist_gap_sec:
            return []
        slice_ids = set(self.catalog.slice_ids())
        out = []
        for tid in sorted(set(req.allowed_twists_hint)):
            if tid in slice_ids and refusal_for(self.catalog.twist(tid), {"id": tid, "src": "mod_brain"}, ctx,
                                                trules) == "":
                out.append(tid)
        return out

    # --- the round ---------------------------------------------------------------------------------------------------

    def turn(self, req: TurnRequest, account: str, route: str = "lines") -> TurnResponse:
        info = RoundInfo()
        self.last = info
        if self.cfg.kill_switch:
            info.outcome = "empty_kill"
            return TurnResponse.empty()
        if self.budget.exhausted():
            info.outcome = "empty_budget"
            return TurnResponse.empty()
        trules = rules_of({})
        ctx = self.twist_context(req)
        allowed = self.allowed_twists(req, ctx, trules)
        info.allowed = allowed
        mem = self.store.memory(req.run_ref)
        max_spicy = int(trules.get("max_spicy_per_floor", 1))
        spice_left = max(0, min(req.spice_left_hint, max_spicy - mem.spicy_by_floor.get(req.state.floor, 0)))
        user = persona.user_message(
            state=req.state.model_dump(),
            events=[e.model_dump(exclude_none=True) for e in req.events],
            allowed=allowed, spice_left=spice_left, recent_lines=self.store.recent(req.run_ref),
            last_twist_result=req.last_twist_result)
        model = self.cfg.model_for(route)
        info.model = model
        try:
            resp = self._call(route, model, user)
        except Exception as exc:  # noqa: BLE001 — every failure is an empty round (timeout, network, API, parse)
            log.warning("mod-brain round failed: %s", type(exc).__name__)
            info.outcome = "error"
            return TurnResponse.empty()
        usage = getattr(resp, "usage", None)
        if usage is not None:
            info.usd = self.budget.book(req.run_ref, account, model, usage)
        if getattr(resp, "stop_reason", "") == "refusal":
            info.outcome = "refusal"
            return TurnResponse.empty()
        out = getattr(resp, "parsed_output", None)
        if not isinstance(out, ModTurnOut):
            info.outcome = "invalid"
            return TurnResponse.empty()
        info.outcome = "ok"
        return TurnResponse(lines=self._lines(req, out, info), twist=self._twist(req, out, allowed, ctx, trules, info),
                            mood=out.mood)

    def _call(self, route: str, model: str, user: str) -> Any:
        c = self.client.with_options(timeout=self.cfg.deadline_for(route), max_retries=self.cfg.retries_for(route))
        kwargs: dict[str, Any] = {
            "model": model,
            "max_tokens": self.cfg.max_tokens,
            "system": persona.system_blocks(self.system_prompt),
            "messages": [{"role": "user", "content": user}],
            "thinking": {"type": "adaptive"},
            "output_config": {"effort": self.cfg.effort_for(route)},
            "output_format": ModTurnOut,
        }
        if self.cfg.use_fallbacks(model):
            return c.beta.messages.parse(**kwargs, betas=[FALLBACK_BETA], fallbacks="default")
        return c.messages.parse(**kwargs)

    def _lines(self, req: TurnRequest, out: ModTurnOut, info: RoundInfo) -> list[RespLine]:
        lines: list[RespLine] = []
        for ol in out.lines[:MAX_LINES]:
            reason = check_line(ol.text, self.catalog.filter_words)
            if reason == "" and ol.voice not in VOICES:
                reason = "voice"
            self.safety.note(reason)
            if reason:
                info.dropped_lines.append(reason)
                continue
            tag = ol.tag if TAG_RE.match(ol.tag or "") else "live"
            text = ol.text.strip()
            lines.append(RespLine(text=text, tag=tag, voice=ol.voice, line_id=self.store.add(req.run_ref, text)))
        return lines

    def _twist(self, req: TurnRequest, out: ModTurnOut, allowed: list[str], ctx: dict, trules: dict,
               info: RoundInfo) -> RespTwist | None:
        if out.twist is None:
            return None
        tid = out.twist.id
        if tid not in allowed:
            info.twist_refusal = "not_allowed_now"
            return None
        params: dict[str, int] = {}
        for p in out.twist.params:
            if p.name in params:
                info.twist_refusal = "params_out_of_range"
                return None
            params[p.name] = p.value
        reason = refusal_for(self.catalog.twist(tid), {"id": tid, "src": "mod_brain", "params": params}, ctx, trules)
        if reason:
            info.twist_refusal = reason
            return None
        mem = self.store.memory(req.run_ref)
        mem.last_twist_at = self.clock()
        if self.catalog.twist(tid).get("spice") == "spicy":
            mem.spicy_by_floor[req.state.floor] = mem.spicy_by_floor.get(req.state.floor, 0) + 1
        return RespTwist(id=tid, params=params)
