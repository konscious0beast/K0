# STUB(K0) — owned by 08-K1. Replace completely, keep the public API.
class_name PersonaBeats extends RefCounted
## Deterministic broadcast plans of the persona's story beats (08 §4.6, §4.7): which beat a hook gets on which floor.
## Pure, no randomness consumed (the plan follows from SeedUtil.derive(seed, "persona_plan", 0) % plans). K0: plan
## choice only; tag_for is a stub (K1 fills the plans and lines).


## The plan id of a run seed ("" without plans).
static func plan_for(data: GameData, seed: int) -> String:
	var plans: Array = data.persona_plans() if data != null else []
	if plans.is_empty():
		return ""
	return str((plans[posmod(SeedUtil.derive(seed, "persona_plan", 0), plans.size())] as Dictionary).get("id", ""))


## The M.O.D. tag of hook `hook` (ordinal `ordinal` on floor `floor_index`) for persona `p` in plan `plan_id`
## ("" = no persona line). Stub: "".
static func tag_for(_data: GameData, _p: PersonaProfile, _plan_id: String, _floor_index: int, _hook: StringName,
		_ordinal: int) -> String:
	return ""
