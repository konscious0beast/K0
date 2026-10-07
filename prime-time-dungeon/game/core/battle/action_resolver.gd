class_name ActionResolver extends RefCounted
## Applies commands and produces ActionEvents (02_TECH §5.6/§5.8, GDD §3). Static; mutates the BattleState it gets.
##
## Order of one action (02_TECH §5.3): ACTION_START → (COMBO) → (STUNT_RESULT) → effects (ascending beat; KO directly
## after the lethal DAMAGE, then PHASE_CHANGE → phase ops) → [BattleState: turn_end ticks/STATUS_REMOVED → TURN_END].
## Effects per target: damage/heal → statuses → cleanse → mp_restore(_pct); then the skill's `special` once.

const FixedMath := preload("res://core/stats/fixed_math.gd")

const DAMAGE_TYPES: PackedStringArray = ["physical", "magical", "fixed"]


## Validated cmd, no TURN_END.
static func resolve(state: BattleState, cmd: BattleCommand) -> Array[ActionEvent]:
	var out: Array[ActionEvent] = []
	var actor: Combatant = state.get_combatant(cmd.actor_id)
	if actor == null:
		return out
	state.running_command = int(cmd.kind)
	state.running_item_id = cmd.item_id if cmd.kind == BattleCommand.Kind.ITEM else ""
	match cmd.kind:
		BattleCommand.Kind.ATTACK:
			var atk: SkillDef = state.skill_def(actor.attack_skill)
			if atk != null:
				_skill_action(state, actor, atk, cmd, atk.name, out)
			actor.last_action_key = "attack"
		BattleCommand.Kind.SKILL:
			var sk: SkillDef = state.skill_def(cmd.skill_id)
			if sk != null:
				_skill_action(state, actor, sk, cmd, sk.name, out)
			actor.last_action_key = cmd.skill_id
		BattleCommand.Kind.STUNT:
			_stunt_action(state, actor, cmd, out)
			actor.last_action_key = "stunt"
		BattleCommand.Kind.ITEM:
			_item_action(state, actor, cmd, out)
			actor.last_action_key = cmd.item_id
		BattleCommand.Kind.DEFEND:
			_defend_action(state, actor, out)
			actor.last_action_key = "defend"
		BattleCommand.Kind.FLEE:
			_flee_action(state, actor, out)
			actor.last_action_key = "flee"
	return out


## Applies a skill's effects (no ACTION_START). Element: skill element; for a party member's attack skill the weapon
## element (attack_element). Enemies always use the skill element. Hits on state.combo_target_id use combo_second_hit.
static func apply_skill(state: BattleState, actor: Combatant, skill: SkillDef, target_ids: PackedStringArray,
		out: Array[ActionEvent]) -> void:
	if skill == null:
		return
	var element: String = actor.attack_element if actor.is_party() and skill.id == actor.attack_skill \
			else skill.element
	var targets: Array[Combatant] = []
	for id: String in target_ids:
		var t: Combatant = state.get_combatant(id)
		if t != null and not t.is_pseudo:
			targets.append(t)
	for eid: String in skill.summon:
		summon(state, actor, eid, out)
	var last_beat: int = 0
	if DAMAGE_TYPES.has(skill.damage_type):
		for h in maxi(1, skill.hits):
			last_beat = h
			for t: Combatant in targets:
				if not t.is_alive():
					continue
				var hit: HitResult
				var mult: float = state.setup.enemy_dmg_mult if actor.side == Combatant.Side.ENEMY else 1.0
				if skill.damage_type == "fixed":
					hit = DamageCalc.fixed(t, skill.power, element, mult)
				else:
					hit = DamageCalc.compute(actor, t, skill, element, state.rng, t.id == state.combo_target_id, mult)
				var ev: ActionEvent = _ev_target(ActionEvent.Type.DAMAGE, t)
				ev.actor_id = actor.id
				ev.skill_id = skill.id
				ev.element = element
				ev.crit = hit.crit
				ev.weak = hit.weak
				ev.resist = hit.resist
				ev.immune = hit.immune
				ev.beat = h
				_note_party_hit(state, actor, t, hit, element)
				deal_damage(state, t, hit.amount, ev, out, 0, _command_of(state, actor))
	elif skill.damage_type == "heal":
		for t: Combatant in targets:
			var amount: int = DamageCalc.heal_amount(actor, t, skill, state.rng)
			if t.is_ko():
				if skill.target == "single_ally_ko":
					revive(state, t, maxi(1, amount), 0, out)
			elif t.is_alive():
				heal(state, t, amount, actor.id, skill.id, "", 0, out)
	for t: Combatant in targets:
		if not t.is_alive():
			continue
		for s: Dictionary in skill.statuses:
			apply_status(state, t, str(s.get("id", "")), JsonUtil.to_int(s.get("turns", 0)), actor.id,
					float(s.get("chance", 1.0)), last_beat, out)
		for cid: String in skill.cleanse:
			remove_status(t, cid, last_beat, out)
		var mp_gain: int = skill.mp_restore + FixedMath.div_round(t.max_mp() * skill.mp_restore_pct, 100)
		if mp_gain > 0:
			change_mp(t, mp_gain, last_beat, out)
	if not skill.special.is_empty():
		_special(state, actor, skill, out)


static func apply_status(state: BattleState, target: Combatant, status_id: String, turns: int, source_id: String,
		chance: float, beat: int, out: Array[ActionEvent], ignore_resist: bool = false) -> void:
	var def: StatusDef = state.status_def(status_id)
	if def == null or target == null or target.is_pseudo or not target.is_alive():
		return
	var t: int = turns if turns > 0 else def.default_turns
	var blocked: bool = target.status_immune.has(status_id)
	if def.element != Elements.NONE and Elements.multiplier_pm(target.element_mods, def.element) <= 0:
		blocked = true
	if def.has_flag("delay_on_apply") and target.has_status(status_id):
		blocked = true
	if not blocked and not FixedMath.roll(state.rng, DamageCalc.status_chance(target, status_id, chance, ignore_resist)):
		blocked = true
	if blocked:
		var bev: ActionEvent = _ev_target(ActionEvent.Type.STATUS_BLOCKED, target)
		bev.status_id = status_id
		bev.beat = beat
		out.append(bev)
		return
	for ex: String in def.excludes:
		if ex != status_id:
			remove_status(target, ex, beat, out)
	var fresh: bool = target.id == state.turn_actor_id
	var existing: StatusEffect = target.get_status(status_id)
	if existing != null:
		existing.turns_left = t
		existing.source_id = source_id
		existing.fresh = fresh
	else:
		var se: StatusEffect = StatusEffect.new(def, t, source_id)
		se.fresh = fresh
		target.statuses.append(se)
	var ev: ActionEvent = _ev_target(ActionEvent.Type.STATUS_ADDED, target)
	ev.status_id = status_id
	ev.value = t
	ev.beat = beat
	out.append(ev)
	if def.has_flag("delay_on_apply"):
		var bd: int = CTBQueue.base_delay(target.stat(StatBlock.Stat.SPD))
		var delay: int = FixedMath.mul_pm(bd, FixedMath.pm(Balance.STUN_BOSS_MULT)) if target.is_boss else bd
		if target.id == state.turn_actor_id:
			state.self_delay += delay
		else:
			state.queue.add_delay(target, delay)


## Defend reset, stun removal, turn_start ticks (poison may kill → KO, the turn does not happen).
static func turn_start(state: BattleState, actor: Combatant, out: Array[ActionEvent]) -> void:
	actor.defending = false
	for st: StatusEffect in actor.statuses.duplicate():
		if st.def != null and st.def.has_flag("delay_on_apply"):
			remove_status(actor, st.id(), 0, out)
	for st: StatusEffect in actor.statuses.duplicate():
		if st.def != null and st.def.tick_timing == "turn_start" and st.def.tick_pct != 0 and actor.statuses.has(st):
			_tick(state, actor, st, out)
			if not actor.is_alive():
				return


## turn_end ticks, durations (fresh statuses skip one count-down), own_turns, stunt cooldown.
static func end_of_turn(state: BattleState, actor: Combatant, out: Array[ActionEvent]) -> void:
	if actor.is_alive():
		for st: StatusEffect in actor.statuses.duplicate():
			if st.def != null and st.def.tick_timing == "turn_end" and st.def.tick_pct != 0 and actor.statuses.has(st):
				_tick(state, actor, st, out)
				if not actor.is_alive():
					break
	for st: StatusEffect in actor.statuses.duplicate():
		if st.fresh:
			st.fresh = false
			continue
		st.turns_left -= 1
		if st.turns_left <= 0:
			remove_status(actor, st.id(), 0, out)
	actor.own_turns += 1
	if not state.stunt_used:
		actor.stunt_cooldown = maxi(0, actor.stunt_cooldown - 1)


## After every DAMAGE on a boss: phase = first phase with hp_ratio > hp_above; only forward. Crossing several
## thresholds enters every intermediate phase in order (GDD §3.11), each with PHASE_CHANGE + its on_enter ops.
static func check_phase(state: BattleState, boss: Combatant, out: Array[ActionEvent]) -> void:
	if boss == null or boss.phases.is_empty() or not boss.is_alive():
		return
	for _guard in boss.phases.size() + 1:
		var target_phase: int = _phase_for(boss)
		if boss.phase >= target_phase or not boss.is_alive():
			return
		boss.phase += 1
		var ev: ActionEvent = ActionEvent.make(ActionEvent.Type.PHASE_CHANGE)
		ev.actor_id = boss.id
		ev.value = boss.phase + 1
		out.append(ev)
		_run_phase_ops(state, boss, out)


## Phase 1 at battle start (after BATTLE_START): on_enter ops without PHASE_CHANGE, then later phases if hp is low.
static func enter_first_phase(state: BattleState, boss: Combatant, out: Array[ActionEvent]) -> void:
	if boss.phases.is_empty() or boss.phase >= 0:
		return
	boss.phase = 0
	_run_phase_ops(state, boss, out)
	check_phase(state, boss, out)


## Pseudo unit turn: ACTION_START (text = name) → DAMAGE per living party member (max_hp × pct, element, defending ½,
## enemy_dmg_mult; guard ignored) (+KO). BattleState adds TURN_END and the counter ctr_after.
static func pseudo_turn(state: BattleState, unit: Combatant, out: Array[ActionEvent]) -> void:
	var action: Dictionary = unit.pseudo_def.action if unit.pseudo_def != null else {}
	var pct: int = JsonUtil.to_int(action.get("fixed_pct_maxhp", 0))
	var element: String = str(action.get("element", Elements.PHYSICAL))
	var targets: Array[Combatant] = state.living(Combatant.Side.PARTY)
	var ev: ActionEvent = ActionEvent.make(ActionEvent.Type.ACTION_START)
	ev.actor_id = unit.id
	ev.text = unit.display_name
	for t: Combatant in targets:
		ev.target_ids.append(t.id)
	out.append(ev)
	for t: Combatant in targets:
		var hit: HitResult = DamageCalc.pct_max_hp(t, pct, element, state.setup.enemy_dmg_mult)
		var dev: ActionEvent = _ev_target(ActionEvent.Type.DAMAGE, t)
		dev.actor_id = unit.id
		dev.element = element
		dev.weak = hit.weak
		dev.resist = hit.resist
		dev.immune = hit.immune
		deal_damage(state, t, hit.amount, dev, out, 0, -1)
	unit.last_action_key = "pseudo"
	unit.warned = false


# --- shared effect helpers (BattleState gifts use them too) ------------------------------------------------------

## Applies prepared DAMAGE event `ev` (target/flags set) with `amount`: hp never below `min_hp` (tutorial party: 1),
## KO directly after it, phase check for phased (boss) enemies. `command` = BattleCommand.Kind of the action (-1 for
## ticks/pseudo/ops).
static func deal_damage(state: BattleState, target: Combatant, amount: int, ev: ActionEvent, out: Array[ActionEvent],
		min_hp: int = 0, command: int = -1) -> void:
	var before: int = target.hp
	var floor_hp: int = min_hp
	if state.setup.tutorial and target.is_party():
		floor_hp = maxi(floor_hp, 1)
	var after: int = maxi(0, before - amount)
	if before > 0 and floor_hp > 0:
		after = maxi(mini(floor_hp, before), after)
	target.hp = after
	ev.amount = amount
	ev.hp_after = after
	ev.max_hp = target.max_hp()
	out.append(ev)
	if target.is_party():
		state.tally["damage_taken"] = int(state.tally["damage_taken"]) + amount
	if before > 0 and after <= 0:
		_ko(state, target, ev.actor_id, ev.skill_id, amount, before, command, ev.beat, out)
	elif target.is_alive() and not target.phases.is_empty():
		var first: int = out.size()
		check_phase(state, target, out)
		for i in range(first, out.size()):
			out[i].beat = maxi(out[i].beat, ev.beat)      # phase events play with the hit that caused them


## HEAL (amount > 0, hp capped at max). actor_id "" for gifts/ticks.
static func heal(state: BattleState, target: Combatant, amount: int, actor_id: String, skill_id: String,
		status_id: String, beat: int, out: Array[ActionEvent]) -> void:
	if amount <= 0 or not target.is_alive() or target.is_pseudo:
		return
	target.hp = mini(target.max_hp(), target.hp + amount)
	var ev: ActionEvent = _ev_target(ActionEvent.Type.HEAL, target)
	ev.actor_id = actor_id
	ev.skill_id = skill_id
	ev.status_id = status_id
	ev.amount = amount
	ev.hp_after = target.hp
	ev.max_hp = target.max_hp()
	ev.beat = beat
	out.append(ev)


## REVIVE a KO'd unit with `hp` (capped), counter base_delay (GDD §3.3).
static func revive(state: BattleState, target: Combatant, hp: int, beat: int, out: Array[ActionEvent]) -> void:
	if not target.is_ko():
		return
	target.hp = clampi(hp, 1, maxi(1, target.max_hp()))
	target.defending = false
	state.queue.add(target, CTBQueue.base_delay(target.stat(StatBlock.Stat.SPD)))
	var ev: ActionEvent = _ev_target(ActionEvent.Type.REVIVE, target)
	ev.hp_after = target.hp
	ev.max_hp = target.max_hp()
	ev.beat = beat
	out.append(ev)


## MP_CHANGE by the actually changed amount (capped 0..max_mp); nothing if it does not change.
static func change_mp(target: Combatant, delta: int, beat: int, out: Array[ActionEvent]) -> void:
	var before: int = target.mp
	target.mp = clampi(target.mp + delta, 0, maxi(0, target.max_mp()))
	if target.mp == before:
		return
	var ev: ActionEvent = _ev_target(ActionEvent.Type.MP_CHANGE, target)
	ev.amount = target.mp - before
	ev.mp_after = target.mp
	ev.beat = beat
	out.append(ev)


static func remove_status(target: Combatant, status_id: String, beat: int, out: Array[ActionEvent]) -> void:
	var st: StatusEffect = target.get_status(status_id)
	if st == null:
		return
	target.statuses.erase(st)
	var ev: ActionEvent = _ev_target(ActionEvent.Type.STATUS_REMOVED, target)
	ev.status_id = status_id
	ev.beat = beat
	out.append(ev)


## Summons an enemy into the lowest free slot (max. 4 living enemies; overflow is dropped), counter
## roundi(base_delay × 0.5). Returns the new combatant or null.
static func summon(state: BattleState, summoner: Combatant, enemy_id: String, out: Array[ActionEvent]) -> Combatant:
	if state.data == null or not state.data.has_id("enemies", enemy_id):
		return null
	var slot: int = state.free_enemy_slot()
	if slot < 0:
		return null
	var c: Combatant = Combatant.create_enemy(state.data.enemy(enemy_id), "e%d" % state.next_enemy_n, slot)
	state.next_enemy_n += 1
	c.is_summon = true
	state.combatants.append(c)
	var bd: int = CTBQueue.base_delay(c.stat(StatBlock.Stat.SPD))
	state.queue.add(c, FixedMath.mul_pm(bd, FixedMath.pm(Balance.SUMMON_CTR_FRAC)))
	var ev: ActionEvent = ActionEvent.make(ActionEvent.Type.SUMMON)
	ev.actor_id = summoner.id if summoner != null else ""
	ev.target_id = c.id
	ev.def_id = c.def_id
	ev.value = slot
	out.append(ev)
	if not c.phases.is_empty():
		enter_first_phase(state, c, out)
	return c


## Gift effects (05 §6.5/§6.10) for BattleState.apply_gift (state.rng is the "gift" stream here).
static func apply_gift_effects(state: BattleState, g: Dictionary, out: Array[ActionEvent]) -> void:
	var effect_pm: int = clampi(JsonUtil.to_int(g.get("effect_pm", FixedMath.PM), FixedMath.PM), 0, FixedMath.PM)
	match str(g.get("kind", "")):
		"sponsor_buff":
			_gift_sponsor(state, str(g.get("sponsor_id", "")), effect_pm, out)
		"gold":
			_gain_credits(state, FixedMath.div_round(JsonUtil.to_int(g.get("amount", 0)) * effect_pm, FixedMath.PM), out)
		"chest", "fan_pack":
			var contents: Variant = g.get("contents", [])
			if contents is Array and not (contents as Array).is_empty():
				for c: Variant in (contents as Array):
					if c is Dictionary:
						_gain_content(state, c, out)
			elif str(g.get("kind", "")) == "chest":
				_roll_box(state, "box_" + str(g.get("tier", "bronze")), effect_pm, out)
			else:
				_roll_pool_entry(state, "common", out)
		_:
			pass


# --- actions --------------------------------------------------------------------------------------------------------

static func _skill_action(state: BattleState, actor: Combatant, sk: SkillDef, cmd: BattleCommand, text: String,
		out: Array[ActionEvent]) -> void:
	var targets: PackedStringArray = _resolve_targets(state, actor, sk, cmd.target_ids)
	_action_start(actor, cmd, sk.id, "", targets, text, out)
	_combo(state, actor, sk, targets, out)
	if cmd.kind == BattleCommand.Kind.SKILL and sk.mp_cost > 0:
		change_mp(actor, -sk.mp_cost, 0, out)
	apply_skill(state, actor, sk, targets, out)


static func _stunt_action(state: BattleState, actor: Combatant, cmd: BattleCommand, out: Array[ActionEvent]) -> void:
	var sk: SkillDef = state.skill_def(cmd.skill_id)
	if sk == null:
		return
	var targets: PackedStringArray = _resolve_targets(state, actor, sk, cmd.target_ids)
	var success: bool = FixedMath.roll(state.rng, state.stunt_chance(actor, sk))
	_action_start(actor, cmd, sk.id, "", targets, sk.name, out)
	if success:
		_combo(state, actor, sk, targets, out)
	var res: ActionEvent = ActionEvent.make(ActionEvent.Type.STUNT_RESULT)
	res.actor_id = actor.id
	res.skill_id = sk.id
	res.success = success
	out.append(res)
	if success:
		apply_skill(state, actor, sk, targets, out)
	else:
		var fe: Dictionary = sk.fail_effect
		var dmg: int = FixedMath.div_round(actor.max_hp() * JsonUtil.to_int(fe.get("self_dmg_pct", 0)), 100)
		if dmg > 0:
			var ev: ActionEvent = _ev_target(ActionEvent.Type.DAMAGE, actor)
			ev.actor_id = actor.id
			ev.skill_id = sk.id
			deal_damage(state, actor, dmg, ev, out, 1, int(BattleCommand.Kind.STUNT))
		var delay_pct: int = JsonUtil.to_int(fe.get("delay_pct", 0))
		if delay_pct > 0:
			state.self_delay += FixedMath.div_round(CTBQueue.base_delay(actor.stat(StatBlock.Stat.SPD)) * delay_pct, 100)
		var sid: String = str(fe.get("status", ""))
		if sid != "":
			apply_status(state, actor, sid, JsonUtil.to_int(fe.get("status_turns", 0)), actor.id, 1.0, 0, out, true)
	actor.stunt_cooldown = sk.cooldown
	state.stunt_used = true


static func _item_action(state: BattleState, actor: Combatant, cmd: BattleCommand, out: Array[ActionEvent]) -> void:
	var it: ItemDef = state.item_def(cmd.item_id)
	var sk: SkillDef = state.skill_def(it.use_skill) if it != null else null
	if sk == null:
		return
	state.items[cmd.item_id] = maxi(0, JsonUtil.to_int(state.items.get(cmd.item_id, 0)) - 1)
	var delta: Dictionary = state.tally["item_delta"]
	delta[cmd.item_id] = JsonUtil.to_int(delta.get(cmd.item_id, 0)) - 1
	if actor.is_party():
		state.tally["items_used"] = int(state.tally["items_used"]) + 1
	if sk.flee_guaranteed:
		_action_start(actor, cmd, sk.id, cmd.item_id, PackedStringArray(), it.name, out)
		_flee_result(state, actor, true, out)
		return
	var targets: PackedStringArray = _resolve_targets(state, actor, sk, cmd.target_ids)
	_action_start(actor, cmd, sk.id, cmd.item_id, targets, it.name, out)
	_combo(state, actor, sk, targets, out)
	apply_skill(state, actor, sk, targets, out)


static func _defend_action(state: BattleState, actor: Combatant, out: Array[ActionEvent]) -> void:
	var cmd: BattleCommand = BattleCommand.defend(actor.id)
	_action_start(actor, cmd, "", "", PackedStringArray(), BattleState.TEXT_DEFEND, out)
	actor.defending = true
	var ev: ActionEvent = ActionEvent.make(ActionEvent.Type.DEFEND)
	ev.actor_id = actor.id
	out.append(ev)
	var restore: int = maxi(Balance.DEFEND_MP_MIN,
			FixedMath.div_ceil(actor.max_mp() * FixedMath.pm(Balance.DEFEND_MP_PCT), FixedMath.PM))
	if actor.max_mp() > 0:
		change_mp(actor, restore, 0, out)


static func _flee_action(state: BattleState, actor: Combatant, out: Array[ActionEvent]) -> void:
	var cmd: BattleCommand = BattleCommand.flee(actor.id)
	_action_start(actor, cmd, "", "", PackedStringArray(), BattleState.TEXT_FLEE, out)
	var ok: bool = state.flee_allowed() and FixedMath.roll(state.rng, state.flee_chance())
	_flee_result(state, actor, ok, out)


static func _flee_result(state: BattleState, actor: Combatant, ok: bool, out: Array[ActionEvent]) -> void:
	var ev: ActionEvent = ActionEvent.make(ActionEvent.Type.FLEE_RESULT)
	ev.actor_id = actor.id
	ev.success = ok
	out.append(ev)
	if ok:
		state.fled = true
	else:
		state.failed_flee_attempts += 1


static func _action_start(actor: Combatant, cmd: BattleCommand, skill_id: String, item_id: String,
		targets: PackedStringArray, text: String, out: Array[ActionEvent]) -> void:
	var ev: ActionEvent = ActionEvent.make(ActionEvent.Type.ACTION_START)
	ev.actor_id = actor.id
	ev.command = int(cmd.kind)
	ev.skill_id = skill_id
	ev.item_id = item_id
	ev.target_ids = targets.duplicate()
	ev.text = text
	out.append(ev)


## Actual targets of a skill: single → the given one, all → every living one of the side, random_enemy → one random
## living enemy (state.rng), self → actor, none → [].
## random_enemy of an enemy actor with exactly one given valid target → that target: EnemyAI already drew it with
## ai_rng (target rule + taunt override, GDD §3.11). Party commands always get the random draw (the player does not
## pick the target of a random skill).
static func _resolve_targets(state: BattleState, actor: Combatant, sk: SkillDef,
		given: PackedStringArray) -> PackedStringArray:
	var valid: PackedStringArray = state.valid_targets(actor, sk.id)
	var out: PackedStringArray = []
	match sk.target:
		"single_enemy", "single_ally", "single_ally_ko":
			if not given.is_empty() and valid.has(given[0]):
				out.append(given[0])
			elif not valid.is_empty():
				out.append(valid[0])
		"all_enemies", "all_allies":
			out = valid
		"random_enemy":
			if not actor.is_party() and given.size() == 1 and valid.has(given[0]):
				out.append(given[0])
			elif not valid.is_empty():
				out.append(valid[state.rng.randi_range(0, valid.size() - 1)])
		"self":
			out.append(actor.id)
	return out


## Combo (GDD §7.3): party damage action on exactly one enemy, directly after the other party member's action on the
## same target (no enemy/pseudo turn in between) → COMBO event, combo_second_hit for this target.
## Also records the action's single enemy target for the next party turn.
## Only physical/magical damage counts (both actions): the ×COMBO_MULT lives in DamageCalc.compute; fixed damage
## (items such as ice spray) has no combo factor (02_TECH §5.9), so it neither finishes nor starts a combo.
static func _combo(state: BattleState, actor: Combatant, sk: SkillDef, targets: PackedStringArray,
		out: Array[ActionEvent]) -> void:
	if not actor.is_party() or not (sk.damage_type == "physical" or sk.damage_type == "magical") \
			or targets.size() != 1:
		return
	var t: Combatant = state.get_combatant(targets[0])
	if t == null or t.is_party():
		return
	state.action_target_id = t.id
	if state.last_actor_side != int(Combatant.Side.PARTY) or state.last_party_actor_id == "" \
			or state.last_party_actor_id == actor.id or state.last_party_target_id != t.id:
		return
	state.combo_target_id = t.id
	var ev: ActionEvent = _ev_target(ActionEvent.Type.COMBO, t)
	ev.actor_id = actor.id
	out.append(ev)


static func _special(state: BattleState, actor: Combatant, sk: SkillDef, out: Array[ActionEvent]) -> void:
	match str(sk.special.get("kind", "")):
		"steal_credits":
			var amount: int = maxi(0, mini(JsonUtil.to_int(sk.special.get("max", 0)),
					state.setup.credits_available - state.credits_stolen))
			state.credits_stolen += amount
			var thieves: Dictionary = state.tally["thieves"]
			var entry: Dictionary = thieves.get(actor.id, {"amount": 0, "refund": false})
			entry["amount"] = JsonUtil.to_int(entry.get("amount", 0)) + amount
			entry["refund"] = bool(entry.get("refund", false)) or bool(sk.special.get("refund_on_win", false))
			thieves[actor.id] = entry
			var ev: ActionEvent = ActionEvent.make(ActionEvent.Type.CREDITS_STOLEN)
			ev.actor_id = actor.id
			ev.value = amount
			out.append(ev)
		"escape":
			if actor.is_party() or not actor.is_alive():
				return
			actor.left_battle = true
			actor.defending = false
			state.queue.remove(actor)
			(state.tally["escaped"] as Array).append(actor.def_id)
			var ev: ActionEvent = ActionEvent.make(ActionEvent.Type.ESCAPED)
			ev.actor_id = actor.id
			out.append(ev)


static func _ko(state: BattleState, target: Combatant, killer_id: String, skill_id: String, amount: int, hp_before: int,
		command: int, beat: int, out: Array[ActionEvent]) -> void:
	var ev: ActionEvent = _ev_target(ActionEvent.Type.KO, target)
	ev.actor_id = killer_id
	ev.skill_id = skill_id
	ev.amount = amount
	ev.max_hp = target.max_hp()
	ev.beat = beat
	ev.command = command
	if command == int(BattleCommand.Kind.ITEM):
		ev.item_id = state.running_item_id
	var overkill: bool = amount * FixedMath.PM >= hp_before * FixedMath.PM \
			+ target.max_hp() * FixedMath.pm(Balance.OVERKILL_MAXHP_FRAC)
	ev.value = 1 if overkill else 0
	out.append(ev)
	target.defending = false
	var cleared: Array[StatusEffect] = target.statuses.duplicate()
	target.statuses.clear()
	if target.is_party():
		state.tally["party_kos"] = int(state.tally["party_kos"]) + 1
		for st: StatusEffect in cleared:
			var rem: ActionEvent = _ev_target(ActionEvent.Type.STATUS_REMOVED, target)
			rem.status_id = st.id()
			rem.beat = beat
			out.append(rem)
	elif not target.is_pseudo:
		(state.tally["killed"] as Array).append(target.id)
		if overkill:
			(state.tally["overkill"] as Array).append(target.id)


## Status tick (turn_start/turn_end): maxi(tick_min, roundi(max_hp × |tick_pct| / 100)); < 0 damage, > 0 heal.
static func _tick(state: BattleState, actor: Combatant, st: StatusEffect, out: Array[ActionEvent]) -> void:
	var amount: int = maxi(st.def.tick_min, FixedMath.div_round(actor.max_hp() * absi(st.def.tick_pct), 100))
	if st.def.tick_pct < 0:
		var ev: ActionEvent = _ev_target(ActionEvent.Type.DAMAGE, actor)
		ev.status_id = st.id()
		ev.element = st.def.element
		deal_damage(state, actor, amount, ev, out, 0, -1)
	else:
		heal(state, actor, amount, "", "", st.id(), 0, out)


static func _phase_for(boss: Combatant) -> int:
	for i in boss.phases.size():
		if FixedMath.ratio_above(maxi(0, boss.hp), boss.max_hp(), float(boss.phases[i].get("hp_above", 0.0))):
			return i
	return boss.phases.size() - 1


static func _run_phase_ops(state: BattleState, boss: Combatant, out: Array[ActionEvent]) -> void:
	if boss.phase < 0 or boss.phase >= boss.phases.size():
		return
	var ops: Array = boss.phases[boss.phase].get("on_enter", [])
	for o: Variant in ops:
		var op: Dictionary = o
		match str(op.get("op", "")):
			"say":
				var ev: ActionEvent = ActionEvent.make(ActionEvent.Type.MOD_LINE)
				ev.text = str(op.get("tag", ""))
				out.append(ev)
			"status_self":
				apply_status(state, boss, str(op.get("status", "")), JsonUtil.to_int(op.get("turns", 0)), boss.id, 1.0,
						0, out, true)
			"summon":
				for _k in maxi(1, JsonUtil.to_int(op.get("count", 1), 1)):
					summon(state, boss, str(op.get("enemy", "")), out)
			"fixed_damage_self":
				if not boss.is_alive():
					continue
				var min_hp: int = maxi(1, JsonUtil.to_int(op.get("min_hp", 1), 1))
				var lost: int = maxi(0, boss.hp - maxi(min_hp, boss.hp - JsonUtil.to_int(op.get("amount", 0))))
				if lost > 0:
					var dev: ActionEvent = _ev_target(ActionEvent.Type.DAMAGE, boss)
					dev.actor_id = boss.id
					dev.element = Elements.NONE
					boss.hp -= lost
					dev.amount = lost
					dev.hp_after = boss.hp
					dev.max_hp = boss.max_hp()
					out.append(dev)
			"add_pseudo":
				_add_pseudo(state, boss, str(op.get("unit", "")), JsonUtil.to_int(op.get("ctr", 0)), out)
			"remove_pseudo":
				var unit: String = str(op.get("unit", ""))
				for c: Combatant in state.combatants:
					if c.is_pseudo and c.def_id == unit and not c.left_battle:
						c.left_battle = true
						state.queue.remove(c)
						var rev: ActionEvent = ActionEvent.make(ActionEvent.Type.PSEUDO_REMOVED)
						rev.target_id = c.id
						rev.def_id = c.def_id
						out.append(rev)


static func _add_pseudo(state: BattleState, boss: Combatant, unit_id: String, ctr: int,
		out: Array[ActionEvent]) -> void:
	if state.data == null or not state.data.has_id("pseudo_units", unit_id):
		return
	var c: Combatant = Combatant.create_pseudo(state.data.pseudo_unit(unit_id), "u%d" % state.next_pseudo_n)
	state.next_pseudo_n += 1
	state.combatants.append(c)
	state.queue.add(c, maxi(0, ctr))
	var ev: ActionEvent = ActionEvent.make(ActionEvent.Type.SUMMON)
	ev.actor_id = boss.id
	ev.target_id = c.id
	ev.def_id = c.def_id
	ev.value = c.slot
	out.append(ev)


## Party hits on enemies: crits, weakness hits, weak elements (bestiary).
static func _note_party_hit(state: BattleState, actor: Combatant, t: Combatant, hit: HitResult,
		element: String) -> void:
	if not actor.is_party() or t.is_party():
		return
	if hit.crit:
		state.tally["crits"] = int(state.tally["crits"]) + 1
	if hit.weak:
		state.tally["weakness_hits"] = int(state.tally["weakness_hits"]) + 1
		var wf: Dictionary = state.tally["weak_found"]
		var list: Array = wf.get(t.def_id, [])
		if not list.has(element):
			list.append(element)
		wf[t.def_id] = list


## BattleCommand.Kind of the action that `actor` is resolving right now (-1 outside its own action, e.g. phase ops).
static func _command_of(state: BattleState, actor: Combatant) -> int:
	return state.running_command if actor.id == state.turn_actor_id else -1


static func _gift_sponsor(state: BattleState, sponsor_id: String, effect_pm: int, out: Array[ActionEvent]) -> void:
	if state.data == null or not state.data.has_id("sponsors", sponsor_id):
		push_warning("BattleState.apply_gift: unknown sponsor '%s'" % sponsor_id)
		return
	var sp: SponsorDef = state.data.sponsor(sponsor_id)
	var ev: ActionEvent = ActionEvent.make(ActionEvent.Type.SPONSOR_GIFT)
	ev.sponsor_id = sp.id
	ev.text = sp.name
	out.append(ev)
	for g: Dictionary in sp.gift:
		var value: int = JsonUtil.to_int(g.get("value", 0))
		var scaled: int = value * effect_pm / FixedMath.PM
		match str(g.get("kind", "")):
			"heal_party_pct":
				for m: Combatant in state.living(Combatant.Side.PARTY):
					heal(state, m, FixedMath.div_round(m.max_hp() * scaled, 100), "", "", "", 0, out)
			"heal_party_flat":
				for m: Combatant in state.living(Combatant.Side.PARTY):
					heal(state, m, scaled, "", "", "", 0, out)
			"mp_party_pct":
				for m: Combatant in state.living(Combatant.Side.PARTY):
					change_mp(m, FixedMath.div_round(m.max_mp() * scaled, 100), 0, out)
			"status_party", "status_enemies":
				var side: Combatant.Side = Combatant.Side.PARTY if str(g.get("kind", "")) == "status_party" \
						else Combatant.Side.ENEMY
				var turns: int = maxi(1, FixedMath.div_round(JsonUtil.to_int(g.get("turns", 0)) * effect_pm, FixedMath.PM))
				for c: Combatant in state.living(side):
					apply_status(state, c, str(g.get("status", "")), turns, "", 1.0, 0, out,
							bool(g.get("ignore_resist", false)))
			"item":
				_gain_item(state, str(g.get("item", "")), value, out)
			"revive_or_heal_lowest":
				var ko: Array[Combatant] = []
				for m: Combatant in state.party():
					if m.is_ko():
						ko.append(m)
				if not ko.is_empty():
					var t: Combatant = BattleState.sort_by_slot(ko)[0]
					revive(state, t, maxi(1, FixedMath.div_round(t.max_hp() * scaled, 100)), 0, out)
				else:
					var low: Combatant = BattleState.lowest_ratio(state.living(Combatant.Side.PARTY))
					if low != null:
						heal(state, low, FixedMath.div_round(low.max_hp() * scaled, 100), "", "", "", 0, out)


static func _gain_credits(state: BattleState, amount: int, out: Array[ActionEvent]) -> void:
	if amount <= 0:
		return
	state.tally["credits_delta"] = int(state.tally["credits_delta"]) + amount
	var ev: ActionEvent = ActionEvent.make(ActionEvent.Type.CREDITS_GAINED)
	ev.value = amount
	out.append(ev)


static func _gain_item(state: BattleState, item_id: String, count: int, out: Array[ActionEvent]) -> void:
	if count <= 0:
		return
	var it: ItemDef = state.item_def(item_id)
	if it == null:
		push_warning("BattleState.apply_gift: unknown item '%s'" % item_id)
		return
	if it.type == "consumable":
		state.items[item_id] = JsonUtil.to_int(state.items.get(item_id, 0)) + count
	var delta: Dictionary = state.tally["item_delta"]
	delta[item_id] = JsonUtil.to_int(delta.get(item_id, 0)) + count
	var ev: ActionEvent = ActionEvent.make(ActionEvent.Type.ITEM_GAINED)
	ev.item_id = item_id
	ev.value = count
	out.append(ev)


## Server content entry: {"rarity", "item_id", "qty"} or {"rarity", "credits"} (05 §6.5).
static func _gain_content(state: BattleState, c: Dictionary, out: Array[ActionEvent]) -> void:
	if JsonUtil.to_int(c.get("credits", 0)) > 0:
		_gain_credits(state, JsonUtil.to_int(c.get("credits", 0)), out)
	elif str(c.get("item_id", "")) != "":
		_gain_item(state, str(c.get("item_id", "")), maxi(1, JsonUtil.to_int(c.get("qty", 1), 1)), out)


## Offline chest without server contents: LootboxDef box_<tier> rarity weights, rolls × effect_pm (min 1), entries
## from loot_pool(floor, rarity). Guarantee (05 §7.4): if no earlier roll reached it, the last roll draws from the
## weights with every rarity below the guarantee set to 0 (silver [55, 38, 7] → [0, 38, 7]); one draw per roll.
static func _roll_box(state: BattleState, box_id: String, effect_pm: int, out: Array[ActionEvent]) -> void:
	if state.data == null or not state.data.has_id("lootboxes", box_id):
		push_warning("BattleState.apply_gift: unknown lootbox '%s'" % box_id)
		return
	var box: LootboxDef = state.data.lootbox(box_id)
	var rolls: int = maxi(1, FixedMath.div_round(box.rolls * effect_pm, FixedMath.PM))
	var order: PackedStringArray = ["common", "rare", "epic"]
	var weights: Array[int] = []
	for r: String in order:
		weights.append(maxi(0, JsonUtil.to_int(box.rarity_weights.get(r, 0))))
	var need: int = order.find(box.guarantee)
	var guaranteed: Array[int] = weights.duplicate()
	var guaranteed_total: int = 0
	for j in guaranteed.size():
		if j < need:
			guaranteed[j] = 0
		guaranteed_total += guaranteed[j]
	var best: int = -1
	for i in rolls:
		var ri: int = 0
		if i == rolls - 1 and need > 0 and best < need:
			# Degenerate data (no weight at or above the guarantee): the guarantee rarity itself.
			ri = _weighted_nonzero(state.rng, guaranteed) if guaranteed_total > 0 else need
		else:
			ri = _weighted_nonzero(state.rng, weights)
		best = maxi(best, ri)
		_roll_pool_entry(state, order[ri], out)


static func _roll_pool_entry(state: BattleState, rarity: String, out: Array[ActionEvent]) -> void:
	var pool: Array[Dictionary] = state.data.loot_pool(state.setup.floor_index, rarity) if state.data != null else []
	if pool.is_empty():
		return
	var w: Array[int] = []
	for e: Dictionary in pool:
		w.append(JsonUtil.to_int(e.get("weight", 1), 1))
	var e: Dictionary = pool[FixedMath.weighted_index(state.rng, w)]
	if str(e.get("kind", "")) == "credits":
		_gain_credits(state, JsonUtil.to_int(e.get("amount", 0)), out)
	else:
		_gain_item(state, str(e.get("id", "")), JsonUtil.to_int(e.get("amount", 1), 1), out)


## Weighted index ignoring zero weights (all zero → 0).
static func _weighted_nonzero(rng: RandomNumberGenerator, weights: Array[int]) -> int:
	var total: int = 0
	for w: int in weights:
		total += w
	if total <= 0:
		return 0
	var r: int = rng.randi_range(0, total - 1)
	for i in weights.size():
		r -= weights[i]
		if r < 0:
			return i
	return weights.size() - 1


## Event with target_id + def_id (02_TECH §5.3: def_id is set on every event that has a target_id).
static func _ev_target(t: ActionEvent.Type, target: Combatant) -> ActionEvent:
	var ev: ActionEvent = ActionEvent.make(t)
	ev.target_id = target.id
	ev.def_id = target.def_id
	return ev
