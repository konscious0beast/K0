"""mod-brain — the reference service behind "M.O.D. live" (PRIME TIME DUNGEON, docs/06 §5).

The game never talks to Claude directly and never holds an API key. It sends a compact, catalog-checked summary of
the run to this service; the service asks Claude (structured output, cached persona + twist catalog) for 0–3 live
lines and at most one twist proposal from the whitelisted catalog, filters and validates both, and answers. Any
error, timeout, refusal or filter hit becomes an empty round — the game's written M.O.D. simply keeps talking.
"""

__version__ = "0.1.0"
