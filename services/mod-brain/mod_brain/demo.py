"""Demo mode (MOD_BRAIN_DEMO=1): a stand-in for the Anthropic client that never leaves the process — canned, already
filtered lines picked from the round's events and no twists. For local development and the game ↔ service smoke test
without an API key and without costs. It goes through the same validation, filter and response path as the real
model."""

from __future__ import annotations

import json
from types import SimpleNamespace
from typing import Any

from .schema import ModTurnOut, OutLine

LINES = {
    "kill": "Getroffen, versenkt. Die Ratte reicht Beschwerde bei der Hausverwaltung ein.",
    "stunt": "Ein Stunt mit Wischmopp. Ich lasse das als Kunst durchgehen.",
    "level_up": "Ein Level mehr. Die Gehaltsverhandlung verschieben wir trotzdem.",
    "achievement": "Ein Erfolg! Ich lasse ihn rahmen und hänge ihn in die Kantine.",
    "boss_defeated": "Der Boss liegt. Die Requisite fragt, ob sie ihn behalten darf.",
    "chest": "Eine Truhe! Die Buchhaltung zählt schon nervös mit.",
    "twist_applied": "Die Regie hat eingegriffen. Ich war es nicht. Vielleicht doch.",
    "evergreen": "Die Ratten haben eine Gewerkschaft gegründet. Ich bleibe ruhig.",
}


class _Messages:
    def parse(self, **kwargs: Any) -> Any:
        user = kwargs["messages"][0]["content"]
        start = user.find("{")
        end = user.rfind("}")
        kinds: list[str] = []
        try:
            payload = json.loads(user[start:end + 1])
            kinds = [str(e.get("t", "")) for e in payload.get("ereignisse", [])]
        except (ValueError, AttributeError):
            pass
        pick = next((k for k in reversed(kinds) if k in LINES), "evergreen")
        tag = pick if pick != "evergreen" else "evergreen"
        parsed = ModTurnOut(lines=[OutLine(text=LINES[pick], tag=tag, voice="mod")], twist=None, mood="snarky")
        usage = SimpleNamespace(input_tokens=0, output_tokens=0, cache_read_input_tokens=0,
                                cache_creation_input_tokens=0)
        return SimpleNamespace(parsed_output=parsed, stop_reason="end_turn", usage=usage)


class DemoClient:
    """with_options / messages.parse / beta.messages.parse like anthropic.Anthropic — offline."""

    def __init__(self) -> None:
        self.messages = _Messages()
        self.beta = SimpleNamespace(messages=self.messages)

    def with_options(self, **_opts: Any) -> "DemoClient":
        return self
