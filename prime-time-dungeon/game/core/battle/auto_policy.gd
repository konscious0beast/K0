class_name AutoPolicy extends RefCounted
## Auto battle for the party (02_TECH §5.8, Autoplay / auto battle). Deterministic, no rng; never STUNT, never FLEE.
## (0) a pseudo unit acts before the actor's next turn (within preview_order(3)) → DEFEND;
## (1) an ally below 35 % HP (or KO and a revive is available) and a heal skill/item is available → heal the lowest
##     ratio (KO counts as 0); skills before items, each in id order;
## (2) the damage skill that buys the most extra damage per MP: among the affordable damage skills whose expected
##     damage beats the basic attack on the enemy with the lowest HP, the highest (expected − attack) / mp_cost
##     (ties: lowest id), on that enemy (all_enemies: expected damage summed over all living enemies; random_enemy:
##     averaged over them, the party's random skill draws one living enemy); no MP threshold;
## (3) otherwise ATTACK the enemy with the lowest HP.
## Expected damage = GDD §3.7 without variance, crit, defend and combo: A·A/(A + D·guard) · power/100 · element · hits
## (fixed damage: power · element · hits).
## Rules (2)/(3) follow 02_TECH §5.8 as amended by CR M7-B1 (M7 balancing; TECH-owner acceptance at merge). The former
## rule "MP >= 50 % → strongest affordable damage skill (power × element), otherwise ATTACK" left half the GDD §4 MP
## pool unused, had Mopsula (STR 5–8) hit for 2–3 damage per turn below 50 % and spent 7 MP on Donnerbellen where
## Adelsflamme does the same damage for 4: Hausmeister L5 34.5 / Königin L7 42.0 party turns instead of GDD §13
## 16–22 / 20–26.

const FixedMath := preload("res://core/stats/fixed_math.gd")
const HEAL_BELOW: float = 0.35
const DAMAGE_TARGETS: PackedStringArray = ["single_enemy", "all_enemies", "random_enemy"]


static func choose(state: BattleState, actor: Combatant) -> BattleCommand:
	if actor == null:
		return null
	var order: PackedStringArray = state.preview_order(3)
	for i in range(1, order.size()):
		if order[i] == actor.id:
			break
		var c: Combatant = state.get_combatant(order[i])
		if c != null and c.is_pseudo:
			return BattleCommand.defend(actor.id)
	var heal_cmd: BattleCommand = _heal_command(state, actor)
	if heal_cmd != null:
		return heal_cmd
	var target: Combatant = BattleState.lowest_hp(state.living(_other(actor)))
	var dmg_cmd: BattleCommand = _damage_skill_command(state, actor, target)
	if dmg_cmd != null:
		return dmg_cmd
	return BattleCommand.attack(actor.id, target.id if target != null else "")


## Expected damage of `skill` used by `actor` with `target` as the main target, in micro HP (1e-6): GDD §3.7 without
## variance, crit, defend and combo (guard and element included), × hits; all_enemies sums over all living units of
## the target's side, random_enemy takes the mean over them (ActionResolver draws one living enemy for a party actor
## and lands every hit on it). Integer arithmetic like DamageCalc.compute.
static func _expected_damage(state: BattleState, actor: Combatant, skill: SkillDef, target: Combatant) -> int:
	if skill == null or target == null or not skill.is_damaging():
		return 0
	var element: String = actor.attack_element if actor.is_party() and skill.id == actor.attack_skill else skill.element
	var physical: bool = skill.damage_type != "magical"
	var a: int = actor.stat(StatBlock.Stat.STR if physical else StatBlock.Stat.MAG)
	var targets: Array[Combatant] = [target]
	if skill.target == "all_enemies" or skill.target == "random_enemy":
		targets = state.living(target.side)
	var sum: int = 0
	for t: Combatant in targets:
		var x: int = skill.power * DamageCalc.MICRO
		if skill.damage_type != "fixed":
			var d: int = t.stat(StatBlock.Stat.DEF if physical else StatBlock.Stat.RES)
			var guard_pm: int = FixedMath.pm(Balance.GUARD_DEF_MULT) if t.has_flag("guard") else FixedMath.PM
			var den: int = a * FixedMath.PM + d * guard_pm
			x = FixedMath.div_round(a * a * skill.power * 10000 * FixedMath.PM, den) if den > 0 else 0
		sum += FixedMath.mul_pm(x, Elements.multiplier_pm(t.element_mods, element))
	if skill.target == "random_enemy" and targets.size() > 1:
		sum = FixedMath.div_round(sum, targets.size())
	return sum * maxi(1, skill.hits)


static func _heal_command(state: BattleState, actor: Combatant) -> BattleCommand:
	var revive_src: Dictionary = _heal_source(state, actor, true)
	var heal_src: Dictionary = _heal_source(state, actor, false)
	var ko: Array[Combatant] = []
	for c: Combatant in state.combatants:
		if c.side == actor.side and c.is_ko():
			ko.append(c)
	if not ko.is_empty() and not revive_src.is_empty():
		return _command(actor, revive_src, PackedStringArray([BattleState.sort_by_slot(ko)[0].id]), state)
	if heal_src.is_empty():
		return null
	var low: Combatant = BattleState.lowest_ratio(state.living(actor.side))
	if low == null or not FixedMath.ratio_below(low.hp, low.max_hp(), HEAL_BELOW):
		return null
	return _command(actor, heal_src, PackedStringArray([low.id]), state)


## First usable heal skill, then heal item (each sorted by id) that targets KO'd allies (revive) or living allies.
## {"skill": id} | {"item": id} | {}.
static func _heal_source(state: BattleState, actor: Combatant, revive: bool) -> Dictionary:
	var skills: PackedStringArray = state.usable_skills(actor)
	skills.sort()
	for sid: String in skills:
		if _is_heal(state.skill_def(sid), revive):
			return {"skill": sid}
	for iid: String in state.usable_items():
		var it: ItemDef = state.item_def(iid)
		if it != null and _is_heal(state.skill_def(it.use_skill), revive):
			return {"item": iid}
	return {}


static func _is_heal(sk: SkillDef, revive: bool) -> bool:
	if sk == null or sk.damage_type != "heal":
		return false
	if revive:
		return sk.target == "single_ally_ko"
	return sk.target == "single_ally" or sk.target == "all_allies"


static func _command(actor: Combatant, src: Dictionary, target: PackedStringArray, state: BattleState) -> BattleCommand:
	if src.has("skill"):
		var sk: SkillDef = state.skill_def(str(src["skill"]))
		var ids: PackedStringArray = state.valid_targets(actor, sk.id) if sk.target == "all_allies" else target
		return BattleCommand.skill(actor.id, sk.id, ids)
	var it: ItemDef = state.item_def(str(src["item"]))
	var us: SkillDef = state.skill_def(it.use_skill)
	var item_ids: PackedStringArray = state.valid_targets(actor, us.id) if us.target == "all_allies" else target
	return BattleCommand.item(actor.id, it.id, item_ids)


## Rule (2): highest (expected − attack) / mp_cost among affordable damage skills that beat the basic attack (exact
## comparison by cross-multiplication; skills in id order, so ties keep the lowest id). null → ATTACK.
static func _damage_skill_command(state: BattleState, actor: Combatant, target: Combatant) -> BattleCommand:
	if target == null:
		return null
	var base: int = _expected_damage(state, actor, state.skill_def(actor.attack_skill), target)
	var skills: PackedStringArray = state.usable_skills(actor)
	skills.sort()
	var best: SkillDef = null
	var best_gain: int = 0
	var best_cost: int = 1
	for sid: String in skills:
		var sk: SkillDef = state.skill_def(sid)
		if sk == null or sid == actor.attack_skill or not sk.is_damaging() or not DAMAGE_TARGETS.has(sk.target):
			continue
		var gain: int = _expected_damage(state, actor, sk, target) - base
		var cost: int = maxi(1, sk.mp_cost)
		if gain > 0 and gain * best_cost > best_gain * cost:
			best = sk
			best_gain = gain
			best_cost = cost
	if best == null:
		return null
	var ids: PackedStringArray = PackedStringArray([target.id]) if best.target == "single_enemy" \
			else state.valid_targets(actor, best.id)
	return BattleCommand.skill(actor.id, best.id, ids)


static func _other(actor: Combatant) -> Combatant.Side:
	return Combatant.Side.ENEMY if actor.is_party() else Combatant.Side.PARTY
