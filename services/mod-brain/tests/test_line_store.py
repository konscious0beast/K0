"""Server-side line memory per run_ref: ring buffer of 6, TTL 2 h, ids not text go back to the client."""

from __future__ import annotations

import re

from mod_brain.line_store import LineStore


def test_ring_buffer_and_ids():
    t = [0.0]
    s = LineStore(clock=lambda: t[0])
    ids = [s.add("rr_a", f"Zeile {i}") for i in range(8)]
    assert all(re.match(r"^l_[0-9a-f]{12}$", i) for i in ids)
    assert len(set(ids)) == 8
    assert s.recent("rr_a") == [f"Zeile {i}" for i in range(2, 8)], "the last 6"
    assert s.recent("rr_b") == [], "per run"


def test_ttl_two_hours():
    t = [0.0]
    s = LineStore(clock=lambda: t[0])
    s.add("rr_a", "alt")
    t[0] += 7199
    assert s.recent("rr_a") == ["alt"]
    t[0] += 7201
    s.recent("rr_b")
    assert s.recent("rr_a") == [], "forgotten after 2 h"
