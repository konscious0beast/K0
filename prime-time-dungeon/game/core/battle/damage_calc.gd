# STUB(M0) — owned by M1. Replace completely, keep the public API.
class_name DamageCalc extends RefCounted
## Battle formulas, static (02_TECH §5.8/§5.9, GDD §3.7).


## physical/magical (GDD §3.7).
static func compute(attacker: Combatant, target: Combatant, skill: SkillDef, element: String, rng: RandomNumberGenerator,
		combo_second_hit: bool = false, enemy_dmg_mult: float = 1.0) -> HitResult:
	return null


## roundi(value × affinity × (defending ? 0.5 : 1.0) × enemy_dmg_mult); no A/D, no variance, no crit, guard ignored.
static func fixed(target: Combatant, value: int, element: String, enemy_dmg_mult: float = 1.0) -> HitResult:
	return null


static func heal_amount(caster: Combatant, target: Combatant, skill: SkillDef, rng: RandomNumberGenerator) -> int:
	return 0


## Slice: always 1.0 (accuracy −1).
static func hit_chance(attacker: Combatant, target: Combatant, skill: SkillDef) -> float:
	return 1.0


static func crit_chance(attacker: Combatant, skill: SkillDef) -> float:
	return 0.0


static func status_chance(target: Combatant, status_id: String, base_chance: float, ignore_resist: bool = false) -> float:
	return 0.0
