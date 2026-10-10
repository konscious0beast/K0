"""Per-account caps: burst 3 / minute, 90 / hour, 400 / day (sliding windows)."""

from __future__ import annotations

from mod_brain.rate_limit import RateLimiter


class Clock:
    def __init__(self) -> None:
        self.t = 1000.0

    def __call__(self) -> float:
        return self.t


def test_burst_then_hour_then_day():
    clock = Clock()
    rl = RateLimiter(per_hour=90, per_day=400, burst_per_min=3, clock=clock)
    assert [rl.check("a") for _ in range(4)] == ["", "", "", "burst"]
    assert rl.check("b") == "", "caps are per account"
    n = 3
    while n < 90:
        clock.t += 21                      # 3 per minute at most
        if rl.check("a") == "":
            n += 1
    clock.t += 21
    assert rl.check("a") == "hour", "90 rounds per hour"
    clock.t += 3600
    assert rl.check("a") == ""


def test_day_cap():
    clock = Clock()
    rl = RateLimiter(per_hour=1000, per_day=400, burst_per_min=1000, clock=clock)
    for _ in range(400):
        assert rl.check("a") == ""
        clock.t += 1
    assert rl.check("a") == "day"
    clock.t += 86400
    assert rl.check("a") == ""
