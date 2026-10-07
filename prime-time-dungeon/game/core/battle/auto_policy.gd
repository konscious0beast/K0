class_name AutoPolicy extends RefCounted
## Auto battle for the party (02_TECH §5.8, Autoplay / auto battle). Deterministic, no rng; never STUNT, never FLEE.
## (0) a pseudo unit acts before the actor's next turn (within preview_order(3)) → DEFEND;
## (1) an ally below 35 % HP (or KO and a revive is available) and a heal skill/item is available → heal the lowest
##     ratio (KO counts as 0); skills before items, each in id order;
## (2) MP >= 50 % → strongest affordable damage skill (power × known element multiplier of the target, ties: lowest id)
##     on the enemy with the lowest HP;
## (3) otherwise ATTACK the enemy with the lowest HP.

const FixedMath := preload("res://core/stats/fixed_math.gd")
const HEAL_BELOW: float = 0.35


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
	if actor.max_mp() > 0 and actor.mp * 2 >= actor.max_mp():
		var dmg_cmd: BattleCommand = _damage_skill_command(state, actor)
		if dmg_cmd != null:
			return dmg_cmd
	var target: Combatant = BattleState.lowest_hp(state.living(_other(actor)))
	return BattleCommand.attack(actor.id, target.id if target != null else "")


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


static func _damage_skill_command(state: BattleState, actor: Combatant) -> BattleCommand:
	var target: Combatant = BattleState.lowest_hp(state.living(_other(actor)))
	if target == null:
		return null
	var skills: PackedStringArray = state.usable_skills(actor)
	skills.sort()
	var best: SkillDef = null
	var best_score: int = 0
	for sid: String in skills:
		var sk: SkillDef = state.skill_def(sid)
		if sk == null or not sk.is_damaging():
			continue
		if not ["single_enemy", "all_enemies", "random_enemy"].has(sk.target):
			continue
		var element: String = actor.attack_element if actor.is_party() and sid == actor.attack_skill else sk.element
		var score: int = sk.power * Elements.multiplier_pm(target.element_mods, element)
		if score > best_score:
			best_score = score
			best = sk
	if best == null:
		return null
	var ids: PackedStringArray = PackedStringArray([target.id]) if best.target == "single_enemy" \
			else state.valid_targets(actor, best.id)
	return BattleCommand.skill(actor.id, best.id, ids)


static func _other(actor: Combatant) -> Combatant.Side:
	return Combatant.Side.ENEMY if actor.is_party() else Combatant.Side.PARTY
