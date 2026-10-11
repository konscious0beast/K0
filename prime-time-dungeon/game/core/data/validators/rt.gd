# STUB(R1a) — owned by R4. Replace completely, keep the public API.
extends RefCounted
## Validator rules of the real-time data (07 §4.10, V1–V14): the `rt` blocks of skills / statuses / enemies / items /
## party / floors.encounters and data/rt_balance.json (RtBalance.validate = V1 + V14), plus the show-boss block of
## encounters (07 §9.6, E26: R4 adds validators/show_boss.gd and calls it from here — data_validator.gd is frozen).
## Private helper like the 06 validators (no class_name; preloaded by DataValidator as RtCheck). Vocabularies:
## RtVocab. Contract note: 07 §4.10 writes the signature as `check(data, errors)`; the real 06 helpers take the
## DataValidator instance (`v._out` = the normalized tables, `v._err` for messages), so this one does too, plus the
## raw file objects (`raw["rt_balance"]` = the parsed data/rt_balance.json or absent).
##
## Stub (R1a): no rules — the R1a data has no `rt` blocks yet; test_r1a_contract checks rt_balance.json directly.


## Appends every problem of the real-time data to v.errors ("<table>[<i>|<id>].rt.<field>: <message>").
static func check(_v: DataValidator, _raw: Dictionary) -> void:
	pass
