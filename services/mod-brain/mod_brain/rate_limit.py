"""Per-account caps (docs/06 §5.10 "Deckel"): ≤ rate_per_hour rounds per hour, ≤ rate_per_day per day and a burst
of ≤ burst_per_min per minute — sliding windows over the round timestamps of each account pseudonym. In memory
(one process); a shared store (Redis …) replaces it when the service scales out [zu prüfen]."""

from __future__ import annotations

import time
from collections import defaultdict, deque
from typing import Callable

HOUR = 3600.0
DAY = 86400.0
MINUTE = 60.0


class RateLimiter:
    def __init__(self, per_hour: int = 90, per_day: int = 400, burst_per_min: int = 3,
                 clock: Callable[[], float] = time.monotonic) -> None:
        self.per_hour = per_hour
        self.per_day = per_day
        self.burst = burst_per_min
        self.clock = clock
        self._hits: dict[str, deque[float]] = defaultdict(deque)

    def check(self, account: str) -> str:
        """"" = allowed (and counted) or the cap that was hit: "burst" | "hour" | "day"."""
        now = self.clock()
        q = self._hits[account]
        while q and now - q[0] >= DAY:
            q.popleft()
        if sum(1 for t in q if now - t < MINUTE) >= self.burst:
            return "burst"
        if sum(1 for t in q if now - t < HOUR) >= self.per_hour:
            return "hour"
        if len(q) >= self.per_day:
            return "day"
        q.append(now)
        return ""
