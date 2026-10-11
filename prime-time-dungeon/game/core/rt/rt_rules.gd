# STUB(R1a) — owned by R1b. Replace completely, keep the public API.
class_name RtRules extends RefCounted
## Rule engine of enemy AI, AI partner, autopilot and assist (07 §5.3, §6.2): pure selection functions (no RNG draw, no
## write, no events). The stub compiles nothing and never chooses.


## Compiled rules (ms → ticks, keys "<key_prefix>:<index>") of a phase / preset. Stub: [].
static func compile(_rules: Array, _key_prefix: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	return out


## {} or {"skill"|"item", "target", "goal"} — the action the unit takes this tick (pure). Stub: {}.
static func choose(_sim: RtSim, _u: RtUnit) -> Dictionary:
	return {}


## Does every condition of `cond` hold for the unit and the rule target (07 §5.3)? Stub: false.
static func eval_cond(_sim: RtSim, _u: RtUnit, _cond: Dictionary, _target_id: String) -> bool:
	return false
