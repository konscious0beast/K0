"""08 CR-23 (K1): the casting makes anyone the candidate — the live prompt describes the candidate neutrally (only
{name}, no job), the game client drops live lines that say "Kai" or "Tierpfleger" while the persona is not the canon
one (core/show/mod_line_filter.gd)."""

from __future__ import annotations

from mod_brain.persona import build_system_prompt


def test_the_candidate_is_described_neutrally(catalog):
    prompt = build_system_prompt(catalog)
    assert "{name}" in prompt
    for word in ("Kai", "Tierpfleger"):
        assert word not in prompt, word
    assert build_system_prompt(catalog) == prompt, "still byte-identical per process (prompt caching)"
