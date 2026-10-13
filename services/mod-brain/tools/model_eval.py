"""S1 model comparison for the route "lines" (docs/06 §5.5/§5.12) — NOT part of CI, calls the real Claude API.

Runs the same sample rounds against several models and prints latency (median / p95), cost per round and per playing
hour (90 rounds/h upper bound), filter hits and the lines for the blind humor review. Credentials come from the
environment / `ant auth login` like the service itself; nothing is stored in the repository.

    python tools/model_eval.py --rounds 100 --models claude-opus-5-5 claude-sonnet-5-5 claude-haiku-5-5 \
        --out eval_lines.jsonl

The output file holds one JSON line per answer (model, latency, usd, lines) for the editorial team's blind rating
(shuffle and strip the model column before rating) [zu prüfen: Bewertungsbogen der Humor-Redaktion]."""

from __future__ import annotations

import argparse
import json
import random
import statistics
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from mod_brain.brain import ModBrain  # noqa: E402
from mod_brain.budget import Budget  # noqa: E402
from mod_brain.catalog import Catalog  # noqa: E402
from mod_brain.config import Config  # noqa: E402
from mod_brain.line_store import LineStore  # noqa: E402
from mod_brain.schema import TurnRequest  # noqa: E402

EVENTS = [
    [{"t": "kill", "id": "enm_kanalratte", "by": "stunt", "member": "kai"}],
    [{"t": "level_up", "member": "mopsula", "level": 4}],
    [{"t": "boss_defeated", "id": "enm_boss_hausmeister"}],
    [{"t": "chest"}, {"t": "kill", "id": "enm_taubenschwarm", "by": "skill", "member": "mopsula"}],
    [{"t": "party_ko", "member": "kai"}],
    [{"t": "timer_warning", "n": 60}],
    [],
]


def sample_request(rng: random.Random, i: int) -> TurnRequest:
    return TurnRequest.model_validate({
        "schema": 1, "req_id": f"r_{i:06d}", "run_ref": "rr_" + "%016x" % rng.getrandbits(64), "lang": "de",
        "state": {"floor": rng.choice([1, 2]), "timer_sec": rng.randint(30, 1200), "hype": rng.randint(5, 100),
                  "viewers_k": rng.randint(0, 9), "hero": rng.choice(["kai", "mopsula"]), "liga_tier": 0,
                  "party": [{"id": "kai", "lvl": 4, "hp_pct": rng.randint(5, 100)},
                            {"id": "mopsula", "lvl": 4, "hp_pct": rng.randint(5, 100)}],
                  "bets": [], "phase": "explore"},
        "events": rng.choice(EVENTS), "recent_line_ids": [],
        "allowed_twists_hint": ["tw_lights_out", "tw_quiet_please", "tw_overtime", "tw_fog_of_fame"],
        "spice_left_hint": 1, "last_twist_result": ""})


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--rounds", type=int, default=100)
    ap.add_argument("--models", nargs="+", default=["claude-opus-5-5", "claude-sonnet-5-5", "claude-haiku-5-5"])
    ap.add_argument("--out", default="eval_lines.jsonl")
    ap.add_argument("--seed", type=int, default=1)
    args = ap.parse_args()
    import anthropic

    client = anthropic.Anthropic()
    catalog = Catalog.load(Config().data_dir)
    rows = []
    with open(args.out, "w", encoding="utf-8") as out:
        for model in args.models:
            cfg = Config(token_secret="eval", model=model)
            brain = ModBrain(cfg, catalog, client, budget=Budget(1e9), store=LineStore())
            rng = random.Random(args.seed)
            lat, usd, hits, empty = [], [], 0, 0
            for i in range(args.rounds):
                req = sample_request(rng, i)
                t0 = time.perf_counter()
                resp = brain.turn(req, "eval")
                lat.append(time.perf_counter() - t0)
                usd.append(brain.last.usd)
                hits += len(brain.last.dropped_lines)
                empty += 0 if resp.lines else 1
                out.write(json.dumps({"model": model, "latency_s": round(lat[-1], 3), "usd": brain.last.usd,
                                      "outcome": brain.last.outcome,
                                      "lines": [x.text for x in resp.lines]}, ensure_ascii=False) + "\n")
            lat.sort()
            rows.append((model, statistics.median(lat), lat[int(0.95 * (len(lat) - 1))], statistics.mean(usd),
                         statistics.mean(usd) * 90, hits, empty))
    print(f"{'model':22} {'median s':>9} {'p95 s':>7} {'$/round':>9} {'$/hour':>8} {'filter':>7} {'empty':>6}")
    for m, med, p95, r, h, hits, empty in rows:
        print(f"{m:22} {med:9.2f} {p95:7.2f} {r:9.4f} {h:8.2f} {hits:7d} {empty:6d}")


if __name__ == "__main__":
    main()
