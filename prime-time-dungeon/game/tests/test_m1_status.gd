extends TestCase
## M1: status effects (02_TECH §4.4.1/§5.6, GDD §3.3/§3.9): poison at turn start (can kill, no TURN_END), stun delay
## (+ boss × 0.5, blocked while active, removed at the next TURN_START, self stun after the action), haste/slow
## exclusion, resist/immunity, reapply resets the duration, durations count own turns (fresh rule), stunt cooldown 3,
## no_magic/no_stunt, turn_end ticks.

const Fx := preload("res://tests/test_m1_fixture.gd")

var data: GameData


func before_each() -> void:
	data = fixture_data(Fx.tables())


## Submits DEFEND for whoever acts until `id` is the current actor (forcing it next).
func _until_actor(s: BattleState, id: String) -> void:
	for _i in 20:
		if s.is_finished() or s.current_actor().id == id:
			return
		Fx.force_next(s, s.get_combatant(id))
		s.submit(BattleCommand.defend(s.current_actor().id))


## Keeps `c` acting: every other unit gets a huge counter (call before each submit of c).
func _hold(s: BattleState, c: Combatant) -> void:
	for o: Combatant in s.combatants:
		if o != c:
			o.ctb_counter = 100000


func _types_after(events: Array[ActionEvent], t: ActionEvent.Type, actor: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var on: bool = false
	for e: ActionEvent in events:
		if on:
			out.append(ActionEvent.type_name(e.type))
		elif e.type == t and e.actor_id == actor:
			on = true
	return out


func test_poison_ticks_at_turn_start_and_can_kill() -> void:
	var s: BattleState = Fx.make_state(data, PackedStringArray(["enm_rat"]))
	s.start()
	var rat: Combatant = s.get_combatant("e0")
	rat.statuses.append(StatusEffect.new(data.status("sts_poison"), 4, "p0"))
	rat.hp = 2
	if s.current_actor().id == "e0":
		s.submit(BattleCommand.defend("e0"))
	Fx.force_next(s, rat)
	var ev: Array[ActionEvent] = s.submit(BattleCommand.defend(s.current_actor().id))
	assert_eq(_types_after(ev, ActionEvent.Type.TURN_START, "e0"), PackedStringArray(["DAMAGE", "KO", "BATTLE_END"]),
			"TURN_START → DAMAGE(status) → KO, no TURN_END")
	var dmg: ActionEvent = Fx.of_type(ev, ActionEvent.Type.DAMAGE)[-1]
	assert_eq(dmg.status_id, "sts_poison")
	assert_eq(dmg.actor_id, "", "status ticks have no actor")
	assert_eq(dmg.amount, 2, "maxi(1, roundi(24 × 8 %)) = 2")
	assert_eq(dmg.element, "poison")
	assert_eq(Fx.of_type(ev, ActionEvent.Type.KO)[0].actor_id, "")
	assert_true(s.is_finished())
	assert_eq(s.result.outcome, BattleResult.Outcome.VICTORY)


func test_poison_lasts_four_own_turns() -> void:
	var s: BattleState = Fx.make_state(data, PackedStringArray(["enm_dummy"]))
	s.start()
	_until_actor(s, "p1")
	var kai: Combatant = s.get_combatant("p0")
	kai.hp = 60
	kai.statuses.append(StatusEffect.new(data.status("sts_poison"), 4, "e0"))   # applied outside Kai's turn
	Fx.force_next(s, kai)
	var all: Array[ActionEvent] = s.submit(BattleCommand.defend("p1"))
	for i in 5:
		_hold(s, kai)
		all.append_array(s.submit(BattleCommand.defend("p0")))
	var ticks: int = 0
	for e: ActionEvent in all:
		if e.type == ActionEvent.Type.DAMAGE and e.status_id == "sts_poison":
			ticks += 1
			assert_eq(e.amount, 5, "64 × 8 % = 5.12 → 5")
	assert_eq(ticks, 4, "4 ticks at Kai's own turn starts")
	assert_eq(kai.hp, 40)
	assert_false(kai.has_status("sts_poison"), "expired after 4 own turns")


func test_stun_delays_counter_and_boss_half() -> void:
	var s: BattleState = Fx.make_state(data, PackedStringArray(["enm_rat", "enm_boss_janitor"]))
	s.start()
	var rat: Combatant = s.get_combatant("e0")
	var boss: Combatant = s.get_combatant("e1")
	var out: Array[ActionEvent] = []
	var before: int = rat.ctb_counter
	ActionResolver.apply_status(s, rat, "sts_stun", 0, "p0", 1.0, 0, out)
	assert_eq(rat.ctb_counter, before + 43, "stun: counter + base_delay (SPD 13 → 43)")
	assert_eq(out[-1].type, ActionEvent.Type.STATUS_ADDED)
	assert_eq(out[-1].value, 1, "default_turns")
	ActionResolver.apply_status(s, rat, "sts_stun", 0, "p0", 1.0, 0, out)
	assert_eq(out[-1].type, ActionEvent.Type.STATUS_BLOCKED, "stun already active → blocked")
	assert_eq(rat.ctb_counter, before + 43, "no extra delay")
	var b_before: int = boss.ctb_counter
	ActionResolver.apply_status(s, boss, "sts_stun", 0, "p0", 1.0, 0, out, true)
	assert_eq(boss.ctb_counter, b_before + 23, "boss: roundi(45 × 0.5) = 23")


func test_stun_removed_at_next_turn_start_and_turn_happens() -> void:
	var s: BattleState = Fx.make_state(data, PackedStringArray(["enm_rat"]),
			{"kai": {"skills": PackedStringArray(["skl_kai_cable_whip"])}})
	s.start()
	_until_actor(s, "p0")
	var ev: Array[ActionEvent] = s.submit(BattleCommand.skill("p0", "skl_kai_cable_whip", PackedStringArray(["e0"])))
	var added: Array[ActionEvent] = Fx.of_type(ev, ActionEvent.Type.STATUS_ADDED)
	if s.is_finished():
		skip("rat died from the whip")
		return
	assert_eq(added[0].status_id, "sts_stun")
	assert_true(s.get_combatant("e0").has_status("sts_stun"))
	_until_actor(s, "e0")
	assert_eq(s.current_actor().id, "e0", "the stunned unit still gets its (delayed) turn")
	assert_false(s.get_combatant("e0").has_status("sts_stun"), "stun removed at TURN_START")
	var stun_removed: bool = false
	for e: ActionEvent in s.history:
		if e.type == ActionEvent.Type.STATUS_REMOVED and e.status_id == "sts_stun":
			stun_removed = true
	assert_true(stun_removed, "STATUS_REMOVED(sts_stun) emitted")


func _failing_stunt_state(member_opts: Dictionary, actor_id: String, stunt: String,
		target: PackedStringArray) -> Dictionary:
	for seed in range(1, 400):
		var opts: Dictionary = {"seed": seed}
		opts.merge(member_opts)
		var s: BattleState = Fx.make_state(data, PackedStringArray(["enm_dummy"]), opts)
		s.start()
		_until_actor(s, actor_id)
		var snap: Dictionary = s.to_dict()
		var probe: BattleState = BattleState.from_dict(snap, data)
		var ev: Array[ActionEvent] = probe.submit(BattleCommand.stunt(actor_id, stunt, target))
		var res: Array[ActionEvent] = Fx.of_type(ev, ActionEvent.Type.STUNT_RESULT)
		if not res.is_empty() and not res[0].success:
			return {"state": BattleState.from_dict(snap, data)}
	return {}


func test_stunt_fail_self_damage_and_delay_after_action() -> void:
	var found: Dictionary = _failing_stunt_state({"kai": {"hp": 3}}, "p0", "skl_stunt_kai_suplex",
			PackedStringArray(["e0"]))
	assert_false(found.is_empty(), "a seed with a failed stunt exists")
	if found.is_empty():
		return
	var s: BattleState = found["state"]
	var kai: Combatant = s.get_combatant("p0")
	var dummy: Combatant = s.get_combatant("e0")
	var mop: Combatant = s.get_combatant("p1")
	dummy.ctb_counter = 1000
	mop.ctb_counter = 1000
	var ev: Array[ActionEvent] = s.submit(BattleCommand.stunt("p0", "skl_stunt_kai_suplex", PackedStringArray(["e0"])))
	var dmg: ActionEvent = Fx.of_type(ev, ActionEvent.Type.DAMAGE)[0]
	assert_eq(dmg.target_id, "p0")
	assert_eq(dmg.amount, 6, "10 % of 64 = 6.4 → 6")
	assert_eq(dmg.hp_after, 1, "a failed stunt never KOs (min 1 HP)")
	assert_eq(Fx.of_type(ev, ActionEvent.Type.KO).size(), 0)
	# Kai acts again next: his counter was delay(rank 4) 64 + roundi(48 × 50 %) 24 = 88 → others lost 88.
	assert_eq(s.current_actor().id, "p0")
	assert_eq(dummy.ctb_counter, 1000 - 88, "self delay is added after on_acted")
	assert_eq(kai.stunt_cooldown, 3)


func test_stunt_fail_stun_on_self_lasts_until_next_turn() -> void:
	var found: Dictionary = _failing_stunt_state({}, "p1", "skl_stunt_mop_entrance", PackedStringArray())
	assert_false(found.is_empty(), "a seed with a failed stunt exists")
	if found.is_empty():
		return
	var s: BattleState = found["state"]
	var dummy: Combatant = s.get_combatant("e0")
	var kai: Combatant = s.get_combatant("p0")
	dummy.ctb_counter = 1000
	kai.ctb_counter = 1000
	var ev: Array[ActionEvent] = s.submit(BattleCommand.stunt("p1", "skl_stunt_mop_entrance", PackedStringArray()))
	var added: Array[ActionEvent] = Fx.of_type(ev, ActionEvent.Type.STATUS_ADDED)
	assert_eq(added[0].status_id, "sts_stun")
	assert_eq(added[0].target_id, "p1")
	# Mopsula (SPD 14): delay rank 4 = 56, + stun base_delay 42 = 98; she acts next and the stun is removed then.
	assert_eq(dummy.ctb_counter, 1000 - 98)
	assert_eq(s.current_actor().id, "p1")
	assert_false(s.get_combatant("p1").has_status("sts_stun"))
	var tail: PackedStringArray = _types_after(ev, ActionEvent.Type.TURN_START, "p1")
	assert_eq(tail[0], "STATUS_REMOVED", "stun removed right after TURN_START")


func test_haste_and_slow_exclude_each_other() -> void:
	var s: BattleState = Fx.make_state(data, PackedStringArray(["enm_rat"]))
	s.start()
	var kai: Combatant = s.get_combatant("p0")
	var out: Array[ActionEvent] = []
	ActionResolver.apply_status(s, kai, "sts_haste", 3, "p1", 1.0, 0, out)
	assert_almost(kai.speed_mult(), 0.6)
	ActionResolver.apply_status(s, kai, "sts_slow", 3, "e0", 1.0, 0, out)
	assert_eq(Fx.types(out), PackedStringArray(["STATUS_ADDED", "STATUS_REMOVED", "STATUS_ADDED"]))
	assert_eq(out[1].status_id, "sts_haste")
	assert_false(kai.has_status("sts_haste"))
	assert_almost(kai.speed_mult(), 1.5)
	assert_eq(CTBQueue.delay_for(kai, 3), 72)


func test_resist_and_immunity_block() -> void:
	var s: BattleState = Fx.make_state(data, PackedStringArray(["enm_slime", "enm_rat"]))
	s.start()
	var slime: Combatant = s.get_combatant("e0")
	var rat: Combatant = s.get_combatant("e1")
	var out: Array[ActionEvent] = []
	ActionResolver.apply_status(s, slime, "sts_poison", 0, "p0", 1.0, 0, out, true)
	assert_eq(out[-1].type, ActionEvent.Type.STATUS_BLOCKED, "status_immune blocks (also with ignore_resist)")
	var no_list: Combatant = s.get_combatant("e1")
	no_list.element_mods = {"poison": 0.0}
	ActionResolver.apply_status(s, no_list, "sts_poison", 0, "p0", 1.0, 0, out)
	assert_eq(out[-1].type, ActionEvent.Type.STATUS_BLOCKED, "element_mods[status element] == 0 blocks")
	no_list.element_mods = {}
	rat.status_resist = {"sts_slow": 1.0}
	ActionResolver.apply_status(s, rat, "sts_slow", 0, "p0", 1.0, 0, out)
	assert_eq(out[-1].type, ActionEvent.Type.STATUS_BLOCKED, "resist 1.0 → chance 0")
	ActionResolver.apply_status(s, rat, "sts_slow", 0, "p0", 1.0, 0, out, true)
	assert_eq(out[-1].type, ActionEvent.Type.STATUS_ADDED, "sponsor ignore_resist skips the resist factor")
	rat.status_resist = {"sts_slow": 0.5}
	rat.statuses.clear()
	var added: int = 0
	for seed in range(1, 401):
		s.rng.seed = seed
		var o: Array[ActionEvent] = []
		ActionResolver.apply_status(s, rat, "sts_slow", 0, "p0", 1.0, 0, o)
		if o[-1].type == ActionEvent.Type.STATUS_ADDED:
			added += 1
		rat.statuses.clear()
	assert_between(added, 160, 240, "resist 0.5 → about half of the rolls succeed")


func test_reapply_resets_duration_without_stacking() -> void:
	var s: BattleState = Fx.make_state(data, PackedStringArray(["enm_rat"]))
	s.start()
	var kai: Combatant = s.get_combatant("p0")
	var out: Array[ActionEvent] = []
	ActionResolver.apply_status(s, kai, "sts_poison", 0, "e0", 1.0, 0, out)
	assert_eq(kai.get_status("sts_poison").turns_left, 4, "turns 0 → default_turns")
	kai.get_status("sts_poison").turns_left = 1
	ActionResolver.apply_status(s, kai, "sts_poison", 3, "e0", 1.0, 0, out)
	assert_eq(kai.statuses.size(), 1, "no stacking")
	assert_eq(kai.get_status("sts_poison").turns_left, 3, "turns_left = new")
	assert_eq(out[-1].value, 3)


func test_durations_count_own_turns_fresh_self_buff() -> void:
	var s: BattleState = Fx.make_state(data, PackedStringArray(["enm_dummy"]),
			{"kai": {"skills": PackedStringArray(["skl_kai_taunt"])}})
	s.start()
	_until_actor(s, "p0")
	var kai: Combatant = s.get_combatant("p0")
	_hold(s, kai)
	s.submit(BattleCommand.skill("p0", "skl_kai_taunt", PackedStringArray()))
	assert_eq(kai.get_status("sts_taunt").turns_left, 3, "applied in the own turn: not counted down at that turn's end")
	assert_eq(kai.get_status("sts_guard").turns_left, 3)
	var seen: Array[int] = []
	for i in 3:
		_hold(s, kai)
		s.submit(BattleCommand.defend("p0"))
		seen.append(kai.get_status("sts_taunt").turns_left if kai.has_status("sts_taunt") else 0)
	assert_eq(seen, [2, 1, 0], "3 following own turns, then removed")
	var mop: Combatant = s.get_combatant("p1")
	var out: Array[ActionEvent] = []
	ActionResolver.apply_status(s, mop, "sts_guard", 2, "p0", 1.0, 0, out)
	assert_false(mop.get_status("sts_guard").fresh, "applied in someone else's turn: counts from the next own turn end")


func test_stunt_cooldown_three_own_turns() -> void:
	var s: BattleState = Fx.make_state(data, PackedStringArray(["enm_dummy"]))
	s.start()
	_until_actor(s, "p0")
	var kai: Combatant = s.get_combatant("p0")
	assert_has(s.available_commands(kai), BattleCommand.Kind.STUNT)
	_hold(s, kai)
	s.submit(BattleCommand.stunt("p0", "skl_stunt_kai_suplex", PackedStringArray(["e0"])))
	assert_eq(kai.stunt_cooldown, 3, "no count-down in the stunt turn itself")
	assert_ne(s.validate(BattleCommand.stunt("p0", "skl_stunt_kai_suplex", PackedStringArray(["e0"]))), "",
			"STUNT on cooldown is invalid")
	var available: Array[bool] = []
	for i in 4:
		if i > 0:
			_hold(s, kai)
			s.submit(BattleCommand.defend("p0"))
		available.append(s.available_commands(kai).has(BattleCommand.Kind.STUNT))
	assert_eq(available, [false, false, false, true], "locked for the 3 following own turns")
	assert_eq(s.validate(BattleCommand.stunt("p0", "skl_stunt_kai_suplex", PackedStringArray(["e0"]))), "")


func test_no_magic_and_no_stunt_flags() -> void:
	var s: BattleState = Fx.make_state(data, PackedStringArray(["enm_rat"]),
			{"kai": {"skills": PackedStringArray(["skl_kai_heavy_swing", "skl_kai_first_aid"])}})
	s.start()
	var kai: Combatant = s.get_combatant("p0")
	assert_eq(s.usable_skills(kai), PackedStringArray(["skl_kai_heavy_swing", "skl_kai_first_aid"]))
	kai.statuses.append(StatusEffect.new(data.status("sts_mute"), 2, "e0"))
	assert_eq(s.usable_skills(kai), PackedStringArray(["skl_kai_heavy_swing"]), "no_magic blocks magic/heal/buff/debuff")
	assert_false(s.available_commands(kai).has(BattleCommand.Kind.STUNT), "no_stunt")
	kai.statuses.clear()
	kai.mp = 2
	assert_eq(s.usable_skills(kai), PackedStringArray(), "MP must cover mp_cost")


func test_turn_end_tick_heals() -> void:
	var s: BattleState = Fx.make_state(data, PackedStringArray(["enm_dummy"]))
	s.start()
	_until_actor(s, "p0")
	var kai: Combatant = s.get_combatant("p0")
	kai.hp = 30
	kai.statuses.append(StatusEffect.new(data.status("sts_regen"), 3, "p1"))
	var ev: Array[ActionEvent] = s.submit(BattleCommand.defend("p0"))
	var heals: Array[ActionEvent] = Fx.of_type(ev, ActionEvent.Type.HEAL)
	assert_eq(heals.size(), 1)
	assert_eq(heals[0].status_id, "sts_regen")
	assert_eq(heals[0].amount, 6, "10 % of 64 = 6.4 → 6")
	assert_eq(heals[0].hp_after, 36)
	var t: PackedStringArray = Fx.types(ev)
	assert_lt(t.find("HEAL"), t.find("TURN_END"), "turn_end ticks come before TURN_END")


func test_party_ko_clears_statuses() -> void:
	var s: BattleState = Fx.make_state(data, PackedStringArray(["enm_rat"]))
	s.start()
	var mop: Combatant = s.get_combatant("p1")
	mop.statuses.append(StatusEffect.new(data.status("sts_haste"), 3, "p1"))
	mop.hp = 1
	var out: Array[ActionEvent] = []
	var ev: ActionEvent = ActionEvent.make(ActionEvent.Type.DAMAGE)
	ev.target_id = "p1"
	ActionResolver.deal_damage(s, mop, 10, ev, out)
	assert_eq(Fx.types(out), PackedStringArray(["DAMAGE", "KO", "STATUS_REMOVED"]))
	assert_true(mop.statuses.is_empty())
	assert_true(mop.is_ko())
	assert_eq(int(s.tally["party_kos"]), 1)
