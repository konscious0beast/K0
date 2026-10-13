"""Costs and the monthly budget (docs/06 §5.10/§5.11). Every round's usage (uncached input, cache writes, cache reads,
output incl. thinking) is priced per model and logged per run_ref and account pseudonym — "cost per playing hour"
measured, not guessed (S1 gate). At 80 % of MOD_BRAIN_MONTHLY_BUDGET_USD the service warns, at 100 % it answers only
empty rounds (automatic kill switch) until the month changes or someone raises the budget.

Prices per 1 M tokens — skill reference 2026-10-06, check before a budget decision [zu prüfen]."""

from __future__ import annotations

import json
import time
from collections import defaultdict
from dataclasses import dataclass
from typing import Any, Callable

#: model prefix → (input, output, cache read) USD per 1 M tokens; cache writes (5 min TTL) cost 1.25 × input.
PRICES: dict[str, tuple[float, float, float]] = {
    "claude-opus-5-5": (4.00, 20.00, 0.20),
    "claude-sonnet-5-5": (2.00, 10.00, 0.20),
    "claude-haiku-5-5": (0.10, 0.50, 0.01),
}
CACHE_WRITE_FACTOR = 1.25


def price_of(model: str) -> tuple[float, float, float]:
    for prefix, p in PRICES.items():
        if model.startswith(prefix):
            return p
    return PRICES["claude-opus-5-5"]          # unknown model: price it like the most expensive one


def round_cost(model: str, usage: Any) -> float:
    """USD of one response from its `usage` (SDK object or dict)."""
    def g(k: str) -> int:
        v = usage.get(k, 0) if isinstance(usage, dict) else getattr(usage, k, 0)
        return int(v or 0)
    p_in, p_out, p_read = price_of(model)
    return (g("input_tokens") * p_in + g("cache_creation_input_tokens") * p_in * CACHE_WRITE_FACTOR
            + g("cache_read_input_tokens") * p_read + g("output_tokens") * p_out) / 1_000_000


@dataclass
class BudgetState:
    month: str
    spent_usd: float = 0.0
    warned: bool = False


class Budget:
    def __init__(self, monthly_usd: float, log_path: str = "",
                 clock: Callable[[], float] = time.time) -> None:
        self.monthly_usd = monthly_usd
        self.log_path = log_path
        self.clock = clock
        self.state = BudgetState(month=self._month())
        self.per_run: dict[str, float] = defaultdict(float)
        self.per_account: dict[str, float] = defaultdict(float)
        self.log: list[dict] = []

    def _month(self) -> str:
        return time.strftime("%Y-%m", time.gmtime(self.clock()))

    def _roll(self) -> None:
        m = self._month()
        if m != self.state.month:
            self.state = BudgetState(month=m)

    def exhausted(self) -> bool:
        """True at 100 % of the monthly budget: rounds are empty (the script keeps talking)."""
        self._roll()
        return self.state.spent_usd >= self.monthly_usd

    def warning(self) -> bool:
        self._roll()
        return self.state.spent_usd >= 0.8 * self.monthly_usd

    def book(self, run_ref: str, account: str, model: str, usage: Any) -> float:
        """Prices one response, books it and writes the cost log entry. Returns the USD amount."""
        self._roll()
        usd = round_cost(model, usage)
        self.state.spent_usd += usd
        self.per_run[run_ref] += usd
        self.per_account[account] += usd
        if self.warning() and not self.state.warned:
            self.state.warned = True        # operations alert hook (S1: log line) [zu prüfen]
        def g(k: str) -> int:
            v = usage.get(k, 0) if isinstance(usage, dict) else getattr(usage, k, 0)
            return int(v or 0)
        entry = {"t": int(self.clock()), "run_ref": run_ref, "acc": account, "model": model, "usd": round(usd, 6),
                 "in": g("input_tokens"), "cache_w": g("cache_creation_input_tokens"),
                 "cache_r": g("cache_read_input_tokens"), "out": g("output_tokens")}
        self.log.append(entry)
        if self.log_path:
            with open(self.log_path, "a", encoding="utf-8") as f:
                f.write(json.dumps(entry, sort_keys=True) + "\n")
        return usd
