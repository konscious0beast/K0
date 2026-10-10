"""Protocol schema 1 (docs/06 §5.4) — the request the game sends (ModLiveSummary), the structured output Claude must
produce, and the response. Input hygiene (§5.9 Nr. 2): every client field is a number in a range or an id / enum
that is checked against the game catalogs; anything unknown is a 400 — never "cleaned up" and never put into a
prompt. No client-supplied string ever reaches Claude."""

from __future__ import annotations

import re
from typing import Literal, Optional

from pydantic import BaseModel, ConfigDict, Field

from .catalog import EVENT_KINDS, KILL_BY, PHASES, REASONS, Catalog

RUN_REF_RE = re.compile(r"^rr_[0-9a-f]{8,32}$")
REQ_ID_RE = re.compile(r"^r_[0-9]{1,9}$")
LINE_ID_RE = re.compile(r"^l_[0-9a-f]{12}$")
TAG_RE = re.compile(r"^[a-z0-9_]{1,24}$")

_STRICT = ConfigDict(extra="forbid", strict=False)


class PartyEntry(BaseModel):
    model_config = _STRICT
    id: str
    lvl: int = Field(ge=1, le=99)
    hp_pct: int = Field(ge=0, le=100)
    spc: str = ""
    cls: str = ""


class BetEntry(BaseModel):
    model_config = _STRICT
    id: str
    hits: int = Field(ge=0, le=99)
    goal: int = Field(ge=0, le=99)


class RunState(BaseModel):
    model_config = _STRICT
    floor: int = Field(ge=1, le=99)
    timer_sec: int = Field(ge=0, le=36000)
    hype: int = Field(ge=0, le=100)
    viewers_k: int = Field(ge=0, le=1_000_000)
    hero: str
    liga_tier: int = Field(ge=0, le=2)
    party: list[PartyEntry] = Field(max_length=4)
    bets: list[BetEntry] = Field(default_factory=list, max_length=4)
    phase: Literal["explore", "battle", "safe_room", "waiting", "done"]


class EventEntry(BaseModel):
    model_config = _STRICT
    t: str
    id: Optional[str] = None
    by: Optional[str] = None
    member: Optional[str] = None
    level: Optional[int] = Field(default=None, ge=1, le=99)
    n: Optional[int] = Field(default=None, ge=0, le=9999)


class TurnRequest(BaseModel):
    """POST /v1/mod/turn body (game/core/show/mod_live_summary.gd)."""

    model_config = _STRICT
    schema_: Literal[1] = Field(alias="schema")
    req_id: str
    run_ref: str
    lang: Literal["de"]
    state: RunState
    events: list[EventEntry] = Field(default_factory=list, max_length=8)
    recent_line_ids: list[str] = Field(default_factory=list, max_length=6)
    allowed_twists_hint: list[str] = Field(default_factory=list, max_length=20)
    spice_left_hint: int = Field(ge=0, le=4)
    last_twist_result: str = ""


def catalog_errors(req: TurnRequest, cat: Catalog) -> list[str]:
    """Every id / enum of the request checked against the game catalogs ([] = ok). Unknown → the request is refused."""
    err: list[str] = []
    if not REQ_ID_RE.match(req.req_id):
        err.append("req_id")
    if not RUN_REF_RE.match(req.run_ref):
        err.append("run_ref")
    st = req.state
    if st.hero not in cat.party:
        err.append("state.hero")
    if st.phase not in PHASES:
        err.append("state.phase")
    for i, p in enumerate(st.party):
        if p.id not in cat.party:
            err.append(f"state.party[{i}].id")
        if p.spc or p.cls:
            err.append(f"state.party[{i}].spc/cls (not in schema 1 yet)")
    for i, b in enumerate(st.bets):
        if b.id not in cat.marotten:
            err.append(f"state.bets[{i}].id")
    for i, e in enumerate(req.events):
        if e.t not in EVENT_KINDS:
            err.append(f"events[{i}].t")
            continue
        if e.id is not None:
            known = {"kill": cat.enemies, "boss_defeated": cat.enemies, "achievement": cat.achievements,
                     "twist_applied": set(cat.twists), "twist_ended": set(cat.twists)}.get(e.t, set())
            if e.id not in known:
                err.append(f"events[{i}].id")
        if e.by is not None and e.by not in KILL_BY:
            err.append(f"events[{i}].by")
        if e.member is not None and e.member not in cat.party:
            err.append(f"events[{i}].member")
    for i, lid in enumerate(req.recent_line_ids):
        if not LINE_ID_RE.match(lid):
            err.append(f"recent_line_ids[{i}]")
    for i, tid in enumerate(req.allowed_twists_hint):
        if tid not in cat.twists:
            err.append(f"allowed_twists_hint[{i}]")
    if req.last_twist_result not in ("", "applied") and req.last_twist_result not in REASONS:
        err.append("last_twist_result")
    return err


# --- what Claude must return (structured output) --------------------------------------------------------------------

class OutLine(BaseModel):
    """One live line. text ≤ 110 characters, only {name} as placeholder (checked again by the safety filter)."""

    text: str = Field(description="Deutsch, max. 110 Zeichen, Platzhalter nur {name}")
    tag: str = Field(description="kurzes Thema, nur a-z, 0-9, _ (z. B. kill, stunt, timer)")
    voice: Literal["mod", "mopsula", "chat"]


class OutParam(BaseModel):
    name: str
    value: int


class OutTwist(BaseModel):
    id: str = Field(description="eine id aus 'erlaubte_twists'")
    params: list[OutParam] = Field(description="leer = Standardwerte; sonst nur Parameter des Twists in seinen Grenzen")


class ModTurnOut(BaseModel):
    lines: list[OutLine] = Field(description="0 bis 3 Zeilen")
    twist: Optional[OutTwist] = Field(description="höchstens ein Twist aus 'erlaubte_twists' oder null")
    mood: Literal["snarky", "sweet", "neutral"]


# --- the response -------------------------------------------------------------------------------------------------

class RespLine(BaseModel):
    text: str
    tag: str
    voice: str
    line_id: str


class RespTwist(BaseModel):
    id: str
    params: dict[str, int]


class TurnResponse(BaseModel):
    lines: list[RespLine] = Field(default_factory=list)
    twist: Optional[RespTwist] = None
    mood: str = "neutral"

    @staticmethod
    def empty() -> "TurnResponse":
        return TurnResponse()


class TokenRequest(BaseModel):
    model_config = _STRICT
    platform: Literal["dev", "steam"]
    ticket: str = Field(min_length=1, max_length=4096)
    run_ref: str
