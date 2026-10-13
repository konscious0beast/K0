"""Configuration from the environment (docs/06 §5.5/§5.10). No secret ever lives in the repository:
ANTHROPIC_API_KEY (or ANTHROPIC_AUTH_TOKEN / an ``ant auth login`` profile) is read by the official SDK itself, and
MOD_BRAIN_TOKEN_SECRET comes from the secret store. Every number here is a start value [zu prüfen]."""

from __future__ import annotations

import os
import secrets
from dataclasses import dataclass, field
from pathlib import Path

DEFAULT_MODEL = "claude-opus-5-5"
ROUTES = ("lines", "director")

#: Repository default: services/mod-brain/../../prime-time-dungeon/game/data
DEFAULT_DATA_DIR = (Path(__file__).resolve().parents[3] / "prime-time-dungeon" / "game" / "data")


def _env(name: str, default: str = "") -> str:
    return os.environ.get(name, default).strip()


def _int(name: str, default: int) -> int:
    try:
        return int(_env(name, str(default)))
    except ValueError:
        return default


def _float(name: str, default: float) -> float:
    try:
        return float(_env(name, str(default)))
    except ValueError:
        return default


def _bool(name: str, default: bool) -> bool:
    v = _env(name, "1" if default else "0").lower()
    return v in ("1", "true", "yes", "on")


@dataclass
class Config:
    """Service configuration. ``Config.from_env()`` in production, plain construction in tests."""

    model: str = DEFAULT_MODEL                       # MOD_BRAIN_MODEL (both routes)
    model_lines: str = ""                            # MOD_BRAIN_MODEL_LINES (overrides `model` for route lines)
    model_director: str = ""                         # MOD_BRAIN_MODEL_DIRECTOR
    effort: str = "low"                              # MOD_BRAIN_EFFORT (route lines; Opus 5.5 default would be medium)
    effort_director: str = "low"                     # MOD_BRAIN_EFFORT_DIRECTOR
    max_tokens: int = 2000                           # thinking (adaptive, low) + the JSON answer
    deadline_lines_sec: float = 4.0                  # route lines: no retries, stays under the client's 6 s
    deadline_director_sec: float = 8.0               # route director (live shows): 1 retry
    fallbacks: bool = True                           # MOD_BRAIN_FALLBACKS: server-side fallbacks "default" (beta)
    token_secret: str = ""                           # MOD_BRAIN_TOKEN_SECRET (HMAC of the session tokens)
    token_ttl_sec: int = 1800                        # ≤ 30 min
    dev_mode: bool = False                           # MOD_BRAIN_DEV_MODE: accept platform "dev" tickets ...
    dev_hosts: tuple[str, ...] = ("127.0.0.1", "::1")  # ... only from these client hosts
    monthly_budget_usd: float = 50.0                 # MOD_BRAIN_MONTHLY_BUDGET_USD (automatic kill switch at 100 %)
    rate_per_hour: int = 90                          # MOD_BRAIN_RATE_PER_HOUR (per account)
    rate_per_day: int = 400                          # MOD_BRAIN_RATE_PER_DAY
    burst_per_min: int = 3                           # MOD_BRAIN_BURST_PER_MIN
    twist_gap_sec: int = 90                          # at most one twist proposal per run every 90 s
    kill_switch: bool = False                        # MOD_BRAIN_KILL_SWITCH: every round is empty
    demo: bool = False                               # MOD_BRAIN_DEMO: canned offline lines, never calls Claude
    max_body_bytes: int = 8192
    data_dir: Path = field(default_factory=lambda: DEFAULT_DATA_DIR)   # MOD_BRAIN_DATA_DIR (game data, catalogs)
    cost_log: str = ""                               # MOD_BRAIN_COST_LOG: JSONL path ("" = memory only)

    @staticmethod
    def from_env() -> "Config":
        secret = _env("MOD_BRAIN_TOKEN_SECRET")
        dev = _bool("MOD_BRAIN_DEV_MODE", False)
        if secret == "" and dev:
            secret = secrets.token_hex(32)   # dev only: tokens die with the process
        data_dir = _env("MOD_BRAIN_DATA_DIR")
        return Config(
            model=_env("MOD_BRAIN_MODEL", DEFAULT_MODEL) or DEFAULT_MODEL,
            model_lines=_env("MOD_BRAIN_MODEL_LINES"),
            model_director=_env("MOD_BRAIN_MODEL_DIRECTOR"),
            effort=_env("MOD_BRAIN_EFFORT", "low") or "low",
            effort_director=_env("MOD_BRAIN_EFFORT_DIRECTOR", "low") or "low",
            fallbacks=_bool("MOD_BRAIN_FALLBACKS", True),
            token_secret=secret,
            dev_mode=dev,
            monthly_budget_usd=_float("MOD_BRAIN_MONTHLY_BUDGET_USD", 50.0),
            rate_per_hour=_int("MOD_BRAIN_RATE_PER_HOUR", 90),
            rate_per_day=_int("MOD_BRAIN_RATE_PER_DAY", 400),
            burst_per_min=_int("MOD_BRAIN_BURST_PER_MIN", 3),
            kill_switch=_bool("MOD_BRAIN_KILL_SWITCH", False),
            demo=_bool("MOD_BRAIN_DEMO", False),
            data_dir=Path(data_dir) if data_dir else DEFAULT_DATA_DIR,
            cost_log=_env("MOD_BRAIN_COST_LOG"),
        )

    def model_for(self, route: str) -> str:
        if route == "director":
            return self.model_director or self.model
        return self.model_lines or self.model

    def effort_for(self, route: str) -> str:
        return self.effort_director if route == "director" else self.effort

    def deadline_for(self, route: str) -> float:
        return self.deadline_director_sec if route == "director" else self.deadline_lines_sec

    def retries_for(self, route: str) -> int:
        return 1 if route == "director" else 0

    def use_fallbacks(self, model: str) -> bool:
        """Server-side fallbacks ("default") — not for Haiku 5.5, which has none (a list there is a 400)."""
        return self.fallbacks and not model.startswith("claude-haiku")
