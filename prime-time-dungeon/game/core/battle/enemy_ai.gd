class_name EnemyAI extends RefCounted
## Enemy command choice (02_TECH §5.8, GDD §3.11). Pure: reads the battle, draws only from the given rng.
## Action list = ai.actions or phases[phase].actions → filter (all cond keys, MP >= mp_cost, `once` unused, usable,
## summon only with a free slot, a target exists) → weighted draw → target rule → taunt override (80 %).
## Nothing left → attack_skill on a random target. Ties of lowest_*/highest_*: lower slot.

const FixedMath := preload("res://core/stats/fixed_math.gd")


static func choose(state: BattleState, actor: Combatant, rng: RandomNumberGenerator) -> BattleCommand:
	if actor == null:
		return null
	var actions: Array = actions_of(actor)
	var cands: Array[int] = []
	var weights: Array[int] = []
	for i in actions.size():
		var a: Dictionary = actions[i]
		var sk: SkillDef = state.skill_def(str(a.get("skill", "")))
		if sk == null or sk.is_stunt():
			continue
		var cond: Dictionary = a.get("cond", {})
		if bool(cond.get("once", false)) and actor.used_once.has(once_key(actor, i)):
			continue
		if not condition_met(state, actor, cond):
			continue
		if not state.usable_skills(actor).has(sk.id):
			continue
		if not sk.summon.is_empty() and state.free_enemy_slot() < 0:
			continue
		if _needs_target(sk) and state.valid_targets(actor, sk.id).is_empty():
			continue
		cands.append(i)
		weights.append(JsonUtil.to_int(a.get("weight", 1), 1))
	if not cands.is_empty():
		var a: Dictionary = actions[cands[FixedMath.weighted_index(rng, weights)]]
		var sk: SkillDef = state.skill_def(str(a.get("skill", "")))
		var targets: PackedStringArray = pick_target(state, actor, str(a.get("target", "random")), sk, rng)
		targets = _taunt_override(state, actor, sk, targets, rng)
		if not _needs_target(sk) or not targets.is_empty():
			return BattleCommand.skill(actor.id, sk.id, targets)
	var atk: SkillDef = state.skill_def(actor.attack_skill)
	var t: PackedStringArray = pick_target(state, actor, "random", atk, rng)
	t = _taunt_override(state, actor, atk, t, rng)
	return BattleCommand.attack(actor.id, t[0] if not t.is_empty() else "")


## All keys must hold (`once` is checked by choose() with the action index): self_hp_below/above f, ally_hp_below f
## (any living ally incl. self), turn_mod [n, r] (own_turns % n == r), allies_alive_below n (living allies incl. self).
## Unknown keys → false.
static func condition_met(state: BattleState, actor: Combatant, cond: Dictionary) -> bool:
	for k: Variant in cond.keys():
		var key: String = str(k)
		var v: Variant = cond[k]
		match key:
			"self_hp_below":
				if not FixedMath.ratio_below(maxi(0, actor.hp), actor.max_hp(), float(v)):
					return false
			"self_hp_above":
				if not FixedMath.ratio_above(maxi(0, actor.hp), actor.max_hp(), float(v)):
					return false
			"ally_hp_below":
				var any: bool = false
				for c: Combatant in state.living(actor.side):
					if FixedMath.ratio_below(c.hp, c.max_hp(), float(v)):
						any = true
						break
				if not any:
					return false
			"turn_mod":
				var arr: Array = v if v is Array else []
				if arr.size() != 2:
					return false
				var n: int = JsonUtil.to_int(arr[0])
				if n <= 0 or actor.own_turns % n != JsonUtil.to_int(arr[1]):
					return false
			"allies_alive_below":
				if state.living(actor.side).size() >= JsonUtil.to_int(v):
					return false
			"once":
				pass
			_:
				return false
	return true


## random | lowest_hp_pct | highest_hp | not_status:<id> (random among those without it, else random) | self |
## all_enemies (= the whole opposing side) | all_allies | ally_lowest_hp_pct (incl. self). Random picks use `rng`.
static func pick_target(state: BattleState, actor: Combatant, rule: String, skill: SkillDef,
		rng: RandomNumberGenerator) -> PackedStringArray:
	var out: PackedStringArray = []
	var other: Combatant.Side = Combatant.Side.PARTY if not actor.is_party() else Combatant.Side.ENEMY
	var opp: Array[Combatant] = state.living(other)
	var allies: Array[Combatant] = state.living(actor.side)
	if rule.begins_with("not_status:"):
		var sid: String = rule.trim_prefix("not_status:")
		var without: Array[Combatant] = []
		for c: Combatant in opp:
			if not c.has_status(sid):
				without.append(c)
		return _random_of(without if not without.is_empty() else opp, rng)
	match rule:
		"lowest_hp_pct":
			var c: Combatant = BattleState.lowest_ratio(opp)
			if c != null:
				out.append(c.id)
		"highest_hp":
			var c: Combatant = BattleState.highest_hp(opp)
			if c != null:
				out.append(c.id)
		"self":
			out.append(actor.id)
		"all_enemies":
			for c: Combatant in opp:
				out.append(c.id)
		"all_allies":
			for c: Combatant in allies:
				out.append(c.id)
		"ally_lowest_hp_pct":
			var c: Combatant = BattleState.lowest_ratio(allies)
			if c != null:
				out.append(c.id)
		_:
			return _random_of(opp, rng)
	return out


## Current action list: phases[phase].actions for phased enemies, else ai.actions.
static func actions_of(actor: Combatant) -> Array:
	if not actor.phases.is_empty():
		var p: int = clampi(actor.phase, 0, actor.phases.size() - 1)
		return actor.phases[p].get("actions", [])
	return actor.ai.get("actions", [])


## Key of a `once` action in Combatant.used_once: "<phase>:<index>".
static func once_key(actor: Combatant, index: int) -> String:
	return "%d:%d" % [maxi(0, actor.phase), index]


## Single-target skill on the party with a living taunting member → with TAUNT_CHANCE that member (lowest slot).
static func _taunt_override(state: BattleState, actor: Combatant, skill: SkillDef, targets: PackedStringArray,
		rng: RandomNumberGenerator) -> PackedStringArray:
	if actor.is_party() or skill == null or targets.size() != 1:
		return targets
	if skill.target != "single_enemy" and skill.target != "random_enemy":
		return targets
	for c: Combatant in state.living(Combatant.Side.PARTY):
		if c.has_flag("taunt"):
			if FixedMath.roll(rng, Balance.TAUNT_CHANCE):
				return PackedStringArray([c.id])
			return targets
	return targets


static func _needs_target(sk: SkillDef) -> bool:
	return sk.target != "none" and sk.target != "self"


static func _random_of(list: Array[Combatant], rng: RandomNumberGenerator) -> PackedStringArray:
	var out: PackedStringArray = []
	if list.is_empty():
		return out
	out.append(list[rng.randi_range(0, list.size() - 1)].id)
	return out
