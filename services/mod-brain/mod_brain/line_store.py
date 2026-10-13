"""Server-side memory per run (docs/06 §5.4): the last 6 lines THIS service gave out per run_ref (TTL 2 h) — the only
earlier lines that ever reach the prompt (the client sends at most their ids, never text) — plus the run's twist
bookkeeping (spicy proposals per floor, time of the last proposal) for the server-side twist budget."""

from __future__ import annotations

import secrets
import time
from collections import deque
from dataclasses import dataclass, field
from typing import Callable

TTL_SEC = 7200.0
MAX_LINES = 6


@dataclass
class RunMemory:
    lines: deque = field(default_factory=lambda: deque(maxlen=MAX_LINES))   # (line_id, text)
    touched: float = 0.0
    spicy_by_floor: dict[int, int] = field(default_factory=dict)
    last_twist_at: float = -1e18


class LineStore:
    def __init__(self, clock: Callable[[], float] = time.monotonic, ttl_sec: float = TTL_SEC) -> None:
        self.clock = clock
        self.ttl = ttl_sec
        self._runs: dict[str, RunMemory] = {}

    def _get(self, run_ref: str) -> RunMemory:
        now = self.clock()
        self._expire(now)
        mem = self._runs.get(run_ref)
        if mem is None:
            mem = RunMemory()
            self._runs[run_ref] = mem
        mem.touched = now
        return mem

    def _expire(self, now: float) -> None:
        for ref in [r for r, m in self._runs.items() if now - m.touched > self.ttl]:
            del self._runs[ref]

    def add(self, run_ref: str, text: str) -> str:
        """Stores a line given out and returns its new id ("l_" + 12 hex)."""
        lid = "l_" + secrets.token_hex(6)
        self._get(run_ref).lines.append((lid, text))
        return lid

    def recent(self, run_ref: str) -> list[str]:
        """Texts of the last lines of this run (oldest first) — server-owned, never from the client."""
        return [t for _, t in self._get(run_ref).lines]

    def memory(self, run_ref: str) -> RunMemory:
        return self._get(run_ref)

    def __len__(self) -> int:
        self._expire(self.clock())
        return len(self._runs)
