class_name DamageCalc extends RefCounted
## Battle formulas, static (02_TECH §5.8/§5.9, GDD §3.7). Deterministic integer arithmetic (05 CR-12): intermediate
## values in micro units (1e-6 HP), factors in permille, one integer draw per random factor; final values are rounded
## half away from zero, i.e. identical to roundi on the exact decimal formula.
##   damage = max(1, roundi(A·A/(A+D) · power/100 · variance · crit · element · defend · combo · enemy_dmg_mult))

const FixedMath := preload("res://core/stats/fixed_math.gd")
const MICRO: int = 1000000


## physical/magical (GDD §3.7). Draw order: variance (randi_range 900..1100 ‰), then crit (physical only).
## Element immunity (multiplier 0) → amount 0 without any draw.
static func compute(attacker: Combatant, target: Combatant, skill: SkillDef, element: String,
		rng: RandomNumberGenerator, combo_second_hit: bool = false, enemy_dmg_mult: float = 1.0) -> HitResult:
	var r: HitResult = HitResult.new()
	var elem_pm: int = Elements.multiplier_pm(target.element_mods, element)
	_set_affinity(r, elem_pm)
	if r.immune:
		return r
	var physical: bool = skill.damage_type != "magical"
	var a: int = attacker.stat(StatBlock.Stat.STR if physical else StatBlock.Stat.MAG)
	var d: int = target.stat(StatBlock.Stat.DEF if physical else StatBlock.Stat.RES)
	var guard_pm: int = FixedMath.pm(Balance.GUARD_DEF_MULT) if target.has_flag("guard") else FixedMath.PM
	var den: int = a * FixedMath.PM + d * guard_pm
	# raw = A·A/(A + D·guard) · power/100  →  micro: A·A·power·1e4·1000 / (1000·A + guard_pm·D)
	var x: int = FixedMath.div_round(a * a * skill.power * 10000 * FixedMath.PM, den) if den > 0 else 0
	var variance: int = rng.randi_range(FixedMath.pm(Balance.DMG_VARIANCE_MIN), FixedMath.pm(Balance.DMG_VARIANCE_MAX))
	x = FixedMath.mul_pm(x, variance)
	if physical and FixedMath.roll(rng, crit_chance(attacker, skill)):
		r.crit = true
		x = FixedMath.mul_pm(x, FixedMath.pm(Balance.CRIT_MULT))
	x = FixedMath.mul_pm(x, elem_pm)
	if target.defending:
		x = FixedMath.mul_pm(x, FixedMath.pm(Balance.DEFEND_MULT))
	if combo_second_hit:
		x = FixedMath.mul_pm(x, FixedMath.pm(Balance.COMBO_MULT))
	if attacker.side == Combatant.Side.ENEMY:
		x = FixedMath.mul_pm(x, FixedMath.pm(enemy_dmg_mult))
	r.amount = maxi(1, FixedMath.div_round(x, MICRO))
	return r


## roundi(value × affinity × (defending ? 0.5 : 1.0) × enemy_dmg_mult); no A/D, no variance, no crit, guard ignored.
## Callers pass enemy_dmg_mult only for enemy sources. A positive value never deals less than 1 (except immunity).
static func fixed(target: Combatant, value: int, element: String, enemy_dmg_mult: float = 1.0) -> HitResult:
	return _flat(target, value * MICRO, element, enemy_dmg_mult)


## Pseudo unit action (02_TECH §5.6): roundi(max_hp × pct / 100 × element × (defending ? 0.5 : 1.0) × enemy_dmg_mult);
## guard ignored.
static func pct_max_hp(target: Combatant, pct: int, element: String, enemy_dmg_mult: float = 1.0) -> HitResult:
	return _flat(target, target.max_hp() * pct * (MICRO / 100), element, enemy_dmg_mult)


## heal_mode "mag": roundi((MAG × 1.5 + 10) × power / 100 × variance 0.95..1.05) (one draw), "pct": roundi(MaxHP ×
## power / 100) (also revive), "fixed": power. Other modes → 0.
static func heal_amount(caster: Combatant, target: Combatant, skill: SkillDef, rng: RandomNumberGenerator) -> int:
	match skill.heal_mode:
		"mag":
			var base_milli: int = caster.stat(StatBlock.Stat.MAG) * FixedMath.pm(Balance.HEAL_STAT_MULT) \
					+ FixedMath.pm(Balance.HEAL_BASE)
			var x: int = base_milli * skill.power * 10    # micro: base_milli × 1000 × power / 100
			x = FixedMath.mul_pm(x, rng.randi_range(FixedMath.pm(Balance.HEAL_VARIANCE_MIN),
					FixedMath.pm(Balance.HEAL_VARIANCE_MAX)))
			return maxi(0, FixedMath.div_round(x, MICRO))
		"pct":
			return maxi(0, FixedMath.div_round(target.max_hp() * skill.power, 100))
		"fixed":
			return maxi(0, skill.power)
	return 0


## Slice: always 1.0 (accuracy −1 everywhere; `accuracy` is reserved, there is no MISS event).
static func hit_chance(attacker: Combatant, target: Combatant, skill: SkillDef) -> float:
	return 1.0


## clampf(0.05 + LCK × 0.005 + attacker.crit_bonus + skill.crit_bonus, 0.0, 0.40) (applies to physical damage only).
static func crit_chance(attacker: Combatant, skill: SkillDef) -> float:
	var c: float = Balance.CRIT_BASE + float(attacker.stat(StatBlock.Stat.LCK)) * Balance.CRIT_PER_LCK \
			+ attacker.crit_bonus + (skill.crit_bonus if skill != null else 0.0)
	return clampf(c, 0.0, Balance.CRIT_CAP)


## chance × (1 − status_resist[id]); ignore_resist skips the resist factor; status_immune → 0.0.
static func status_chance(target: Combatant, status_id: String, base_chance: float,
		ignore_resist: bool = false) -> float:
	if target.status_immune.has(status_id):
		return 0.0
	var resist: float = 0.0 if ignore_resist else clampf(float(target.status_resist.get(status_id, 0.0)), 0.0, 1.0)
	return clampf(base_chance * (1.0 - resist), 0.0, 1.0)


static func _flat(target: Combatant, micro: int, element: String, enemy_dmg_mult: float) -> HitResult:
	var r: HitResult = HitResult.new()
	var elem_pm: int = Elements.multiplier_pm(target.element_mods, element)
	_set_affinity(r, elem_pm)
	if r.immune or micro <= 0:
		return r
	var x: int = FixedMath.mul_pm(micro, elem_pm)
	if target.defending:
		x = FixedMath.mul_pm(x, FixedMath.pm(Balance.DEFEND_MULT))
	x = FixedMath.mul_pm(x, FixedMath.pm(enemy_dmg_mult))
	r.amount = maxi(1, FixedMath.div_round(x, MICRO))
	return r


static func _set_affinity(r: HitResult, elem_pm: int) -> void:
	var aff: StringName = Elements.affinity(float(elem_pm) / float(FixedMath.PM))
	r.weak = aff == &"weak"
	r.resist = aff == &"resist"
	r.immune = aff == &"immune"
