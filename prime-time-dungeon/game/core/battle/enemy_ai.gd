# STUB(M0) — owned by M1. Replace completely, keep the public API.
class_name EnemyAI extends RefCounted
## Enemy command choice (02_TECH §5.8, GDD §3.11).


static func choose(state: BattleState, actor: Combatant, rng: RandomNumberGenerator) -> BattleCommand:
	return null


static func condition_met(state: BattleState, actor: Combatant, cond: Dictionary) -> bool:
	return false


static func pick_target(state: BattleState, actor: Combatant, rule: String, skill: SkillDef,
		rng: RandomNumberGenerator) -> PackedStringArray:
	return PackedStringArray()
