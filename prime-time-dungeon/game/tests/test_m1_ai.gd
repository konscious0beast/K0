extends TestCase
## M1: EnemyAI conditions/target rules/taunt (80 %)/weighted choice/once/fallback, boss phase ops, pseudo unit,
## steal_credits/escape, AutoPolicy (02_TECH §5.6/§5.8, GDD §3.11).

const Fx := preload("res://tests/test_m1_fixture.gd")

var data: GameData


func before_each() -> void:
	data = fixture_data(Fx.tables())


func _started(enemy_ids: Array, opts: Dictionary = {}) -> BattleState:
	var s: BattleState = Fx.make_state(data, PackedStringArray(enemy_ids), opts)
	s.start()
	return s


func _hold(s: BattleState, c: Combatant) -> void:
	for o: Combatant in s.combatants:
		if o != c:
			o.ctb_counter = 100000


func test_condition_met_each_key() -> void:
	var s: BattleState = _started(["enm_rat", "enm_shaman"])
	var rat: Combatant = s.get_combatant("e0")
	var shaman: Combatant = s.get_combatant("e1")
	rat.hp = 11
	assert_true(EnemyAI.condition_met(s, rat, {"self_hp_below": 0.5}), "11/24 < 0.5")
	rat.hp = 12
	assert_false(EnemyAI.condition_met(s, rat, {"self_hp_below": 0.5}), "strictly below")
	assert_false(EnemyAI.condition_met(s, rat, {"self_hp_above": 0.5}), "strictly above")
	rat.hp = 13
	assert_true(EnemyAI.condition_met(s, rat, {"self_hp_above": 0.5}))
	assert_false(EnemyAI.condition_met(s, rat, {"ally_hp_below": 0.5}))
	shaman.hp = 10
	assert_true(EnemyAI.condition_met(s, rat, {"ally_hp_below": 0.5}), "any living ally")
	shaman.hp = 34
	rat.hp = 2
	assert_true(EnemyAI.condition_met(s, shaman, {"ally_hp_below": 0.5}), "allies include the actor's side incl. self")
	rat.own_turns = 2
	assert_true(EnemyAI.condition_met(s, rat, {"turn_mod": [3, 2]}))
	rat.own_turns = 5
	assert_true(EnemyAI.condition_met(s, rat, {"turn_mod": [3, 2]}))
	rat.own_turns = 3
	assert_false(EnemyAI.condition_met(s, rat, {"turn_mod": [3, 2]}))
	assert_false(EnemyAI.condition_met(s, rat, {"allies_alive_below": 2}), "2 living enemies")
	shaman.hp = 0
	assert_true(EnemyAI.condition_met(s, rat, {"allies_alive_below": 2}))
	assert_true(EnemyAI.condition_met(s, rat, {"once": true}), "once is handled by choose()")
	assert_true(EnemyAI.condition_met(s, rat, {}))
	assert_false(EnemyAI.condition_met(s, rat, {"allies_alive_below": 2, "turn_mod": [3, 2]}), "all keys must hold")
	assert_false(EnemyAI.condition_met(s, rat, {"bogus": 1}), "unknown key → false")


func test_pick_target_rules_and_ties() -> void:
	var s: BattleState = _started(["enm_rat", "enm_shaman"])
	var rat: Combatant = s.get_combatant("e0")
	var shaman: Combatant = s.get_combatant("e1")
	var kai: Combatant = s.get_combatant("p0")
	var mop: Combatant = s.get_combatant("p1")
	var bite: SkillDef = data.skill("skl_e_bite")
	var rng: RandomNumberGenerator = make_rng(4)
	mop.hp = 10
	assert_eq(EnemyAI.pick_target(s, rat, "lowest_hp_pct", bite, rng), PackedStringArray(["p1"]))
	assert_eq(EnemyAI.pick_target(s, rat, "highest_hp", bite, rng), PackedStringArray(["p0"]))
	kai.hp = 32
	mop.hp = 21
	assert_eq(EnemyAI.pick_target(s, rat, "lowest_hp_pct", bite, rng), PackedStringArray(["p0"]),
			"equal ratio → lower slot")
	mop.hp = 32
	assert_eq(EnemyAI.pick_target(s, rat, "highest_hp", bite, rng), PackedStringArray(["p0"]), "equal hp → lower slot")
	kai.statuses.append(StatusEffect.new(data.status("sts_poison"), 3, "e0"))
	for seed in range(1, 30):
		assert_eq(EnemyAI.pick_target(s, rat, "not_status:sts_poison", bite, make_rng(seed)), PackedStringArray(["p1"]))
	mop.statuses.append(StatusEffect.new(data.status("sts_poison"), 3, "e0"))
	var seen: Dictionary = {}
	for seed in range(1, 60):
		seen[EnemyAI.pick_target(s, rat, "not_status:sts_poison", bite, make_rng(seed))[0]] = true
	assert_eq(seen.size(), 2, "everybody has it → random over all")
	assert_eq(EnemyAI.pick_target(s, rat, "self", bite, rng), PackedStringArray(["e0"]))
	assert_eq(EnemyAI.pick_target(s, rat, "all_enemies", bite, rng), PackedStringArray(["p0", "p1"]))
	assert_eq(EnemyAI.pick_target(s, rat, "all_allies", bite, rng), PackedStringArray(["e0", "e1"]))
	shaman.hp = 5
	assert_eq(EnemyAI.pick_target(s, rat, "ally_lowest_hp_pct", bite, rng), PackedStringArray(["e1"]))
	rat.hp = 1
	assert_eq(EnemyAI.pick_target(s, rat, "ally_lowest_hp_pct", bite, rng), PackedStringArray(["e0"]), "incl. self")
	mop.hp = 0
	for seed in range(1, 20):
		assert_eq(EnemyAI.pick_target(s, rat, "random", bite, make_rng(seed)), PackedStringArray(["p0"]), "never KO'd units")


func test_taunt_override_eighty_percent() -> void:
	var s: BattleState = _started(["enm_dummy"])
	var dummy: Combatant = s.get_combatant("e0")   # no actions → attack on "random"
	var kai: Combatant = s.get_combatant("p0")
	kai.statuses.append(StatusEffect.new(data.status("sts_taunt"), 3, "p0"))
	var hits: int = 0
	var n: int = 1000
	for seed in range(n):
		var cmd: BattleCommand = EnemyAI.choose(s, dummy, make_rng(seed))
		assert_eq(cmd.kind, BattleCommand.Kind.ATTACK)
		if cmd.target_ids[0] == "p0":
			hits += 1
	# P(p0) = 0.8 + 0.2 × 0.5 = 0.9
	assert_between(hits, 860, 940, "taunt: 80 % override + 50 % of the rest")
	var pig: Combatant = Combatant.create_enemy(data.enemy("enm_pigeon"), "e9", 3)
	s.combatants.append(pig)
	for seed in range(200):
		var c: BattleCommand = EnemyAI.choose(s, pig, make_rng(seed))
		if c.skill_id == "skl_e_dive_bomb":
			assert_eq(c.target_ids, PackedStringArray(["p0", "p1"]), "multi-target skills ignore taunt")


func test_weighted_choice_filters_and_purity() -> void:
	var s: BattleState = _started(["enm_rat", "enm_shaman"])
	var rat: Combatant = s.get_combatant("e0")
	var gnaw: int = 0
	for seed in range(2000):
		if EnemyAI.choose(s, rat, make_rng(seed)).skill_id == "skl_e_gnaw_poison":
			gnaw += 1
	assert_between(gnaw, 420, 580, "weights 3:1 → 25 %")
	var shaman: Combatant = s.get_combatant("e1")
	shaman.hp = 10
	var heals: int = 0
	for seed in range(700):
		var cmd: BattleCommand = EnemyAI.choose(s, shaman, make_rng(seed))
		if cmd.skill_id == "skl_e_rat_heal":
			heals += 1
			assert_eq(cmd.target_ids, PackedStringArray(["e1"]), "ally_lowest_hp_pct incl. self")
	assert_between(heals, 560, 640, "weights 6:1 → 86 %")
	shaman.mp = 2
	for seed in range(100):
		assert_ne(EnemyAI.choose(s, shaman, make_rng(seed)).skill_id, "skl_e_rat_heal", "MP < mp_cost filters")
	shaman.mp = 30
	shaman.hp = 34
	for seed in range(100):
		assert_ne(EnemyAI.choose(s, shaman, make_rng(seed)).skill_id, "skl_e_rat_heal", "cond filters")
	var a: BattleCommand = EnemyAI.choose(s, rat, make_rng(5))
	var b: BattleCommand = EnemyAI.choose(s, rat, make_rng(5))
	assert_eq(a.to_dict(), b.to_dict(), "same rng → same command")


func test_choose_ai_command_is_pure_and_once_is_marked_on_resolution() -> void:
	var s: BattleState = _started(["enm_mimic"])
	var mimic: Combatant = s.get_combatant("e0")
	if s.current_actor() != mimic:
		Fx.force_next(s, mimic)
		s.submit(BattleCommand.defend(s.current_actor().id))
	assert_eq(s.current_actor(), mimic)
	var snap: Dictionary = s.to_dict()
	var c1: BattleCommand = s.choose_ai_command()
	var c2: BattleCommand = s.choose_ai_command()
	assert_eq(c1.to_dict(), c2.to_dict(), "choose_ai_command is repeatable")
	assert_eq(s.to_dict(), snap, "choose_ai_command does not change the battle")
	var fine: BattleCommand = BattleCommand.skill("e0", "skl_e_fine", PackedStringArray(["p0"]))
	s.submit(fine)
	assert_eq(mimic.used_once, PackedStringArray(["0:0"]), "once marked when the skill is resolved")
	for seed in range(200):
		assert_ne(EnemyAI.choose(s, mimic, make_rng(seed)).skill_id, "skl_e_fine", "once actions are used at most once")


func test_once_is_marked_only_for_the_chosen_action() -> void:
	# The same skill as a `once` action and as a normal action: only choosing the `once` entry uses it up.
	var t: Dictionary = Fx.tables()
	(t["enemies"] as Array).append(Fx._enemy("enm_twin", Fx._stats(500, 0, 1, 1, 1, 1, 1, 1), [
		{"skill": "skl_e_brace", "weight": 1, "target": "self", "cond": {"once": true}},
		{"skill": "skl_e_brace", "weight": 1, "target": "self"}], {"exp": 1, "credits": 1}))
	# Two `once` entries with the same skill: the chosen one is marked (not simply the first).
	(t["enemies"] as Array).append(Fx._enemy("enm_twin_once", Fx._stats(500, 0, 1, 1, 1, 1, 1, 1), [
		{"skill": "skl_e_brace", "weight": 1, "target": "self", "cond": {"once": true}},
		{"skill": "skl_e_brace", "weight": 1, "target": "self", "cond": {"once": true}}], {"exp": 1, "credits": 1}))
	var d: GameData = fixture_data(t)
	for enemy_id: String in ["enm_twin", "enm_twin_once"]:
		var seen: Dictionary = {}
		for seed in range(1, 41):
			var s: BattleState = Fx.make_state(d, PackedStringArray([enemy_id]), {"seed": seed})
			s.start()
			var twin: Combatant = s.get_combatant("e0")
			_until(s, twin)
			assert_eq(s.current_actor(), twin)
			var choice: Dictionary = EnemyAI.choose_action(s, twin,
					SeedUtil.make_rng(SeedUtil.derive(s.setup.seed, "ai", s.action_n)))
			var cmd: BattleCommand = s.choose_ai_command()
			assert_eq(cmd.to_dict(), (choice["command"] as BattleCommand).to_dict(), "choose_action ≡ choose_ai_command")
			s.submit(cmd)
			var index: int = int(choice["index"])
			seen[index] = true
			var label: String = "%s seed %d index %d" % [enemy_id, seed, index]
			if index == 0:
				assert_eq(twin.used_once, PackedStringArray(["0:0"]), label + ": once entry chosen → marked")
			elif enemy_id == "enm_twin":
				assert_eq(twin.used_once, PackedStringArray(), label + ": normal entry chosen → once stays unused")
			else:
				assert_eq(twin.used_once, PackedStringArray(["0:1"]), label + ": the chosen once entry is marked")
		assert_eq(seen.size(), 2, enemy_id + ": both entries were chosen at least once")


func test_taunt_applies_to_random_enemy_skills() -> void:
	var t: Dictionary = Fx.tables()
	(t["skills"] as Array).append(Fx._skill("skl_e_pounce", "enemy", "attack", "random_enemy",
			{"damage_type": "physical", "element": "physical", "power": 10}))
	(t["skills"] as Array).append(Fx._skill("skl_kai_wild_swing", "party", "attack", "random_enemy",
			{"damage_type": "physical", "element": "physical", "power": 10}))
	(t["enemies"] as Array).append(Fx._enemy("enm_pouncer", Fx._stats(500, 0, 1, 1, 1, 1, 1, 1), [
		{"skill": "skl_e_pounce", "weight": 1, "target": "random"}], {"exp": 1, "credits": 1}))
	var d: GameData = fixture_data(t)
	var hits: int = 0
	var n: int = 400
	for seed in range(1, n + 1):
		var s: BattleState = Fx.make_state(d, PackedStringArray(["enm_pouncer"]), {"seed": seed})
		s.start()
		var pouncer: Combatant = s.get_combatant("e0")
		_until(s, pouncer)
		s.get_combatant("p0").statuses.append(StatusEffect.new(d.status("sts_taunt"), 3, "p0"))
		var dmg: Array[ActionEvent] = Fx.of_type(s.submit(s.choose_ai_command()), ActionEvent.Type.DAMAGE)
		assert_len(dmg, 1, "random_enemy: one target")
		if not dmg.is_empty() and dmg[0].target_id == "p0":
			hits += 1
	# P(p0) = 0.8 + 0.2 × 0.5 = 0.9 (the AI's target is used, not a second draw)
	assert_between(hits, 330, 390, "taunt also steers random_enemy skills of enemies")
	# Party random_enemy: a single given target is not honored (random draw with the battle rng).
	var targets: Dictionary = {}
	for seed in range(1, 41):
		var s: BattleState = Fx.make_state(d, PackedStringArray(["enm_dummy", "enm_dummy"]),
				{"seed": seed, "kai": {"skills": PackedStringArray(["skl_kai_wild_swing"])}})
		s.start()
		_until(s, s.get_combatant("p0"))
		var ev: Array[ActionEvent] = s.submit(BattleCommand.skill("p0", "skl_kai_wild_swing", PackedStringArray(["e0"])))
		targets[Fx.of_type(ev, ActionEvent.Type.DAMAGE)[0].target_id] = true
	assert_eq(targets.size(), 2, "party: random over all living enemies")


func test_empty_action_list_falls_back_to_attack() -> void:
	var s: BattleState = _started(["enm_dummy"])
	var dummy: Combatant = s.get_combatant("e0")
	for seed in range(20):
		var cmd: BattleCommand = EnemyAI.choose(s, dummy, make_rng(seed))
		assert_eq(cmd.kind, BattleCommand.Kind.ATTACK)
		assert_len(cmd.target_ids, 1)
	var rat: Combatant = s.get_combatant("e0")
	rat.statuses.append(StatusEffect.new(data.status("sts_mute"), 2, "p0"))
	assert_eq(EnemyAI.choose(s, rat, make_rng(1)).kind, BattleCommand.Kind.ATTACK)


func test_steal_credits_escape_and_refund() -> void:
	var s: BattleState = _started(["enm_mimic"], {"credits": 50})
	var mimic: Combatant = s.get_combatant("e0")
	_until(s, mimic)
	var ev: Array[ActionEvent] = s.submit(BattleCommand.skill("e0", "skl_e_fine", PackedStringArray(["p0"])))
	assert_eq(Fx.of_type(ev, ActionEvent.Type.CREDITS_STOLEN)[0].value, 40, "min(max 40, available 50)")
	_until(s, mimic)
	ev = s.submit(BattleCommand.skill("e0", "skl_e_fine", PackedStringArray(["p1"])))
	assert_eq(Fx.of_type(ev, ActionEvent.Type.CREDITS_STOLEN)[0].value, 10, "limited by what is left")
	assert_eq(s.credits_stolen, 50)
	_until(s, mimic)
	ev = s.submit(BattleCommand.skill("e0", "skl_e_escape", PackedStringArray()))
	assert_eq(Fx.of_type(ev, ActionEvent.Type.ESCAPED)[0].actor_id, "e0")
	assert_true(s.is_finished(), "all remaining enemies gone → victory")
	assert_eq(s.result.outcome, BattleResult.Outcome.VICTORY)
	assert_eq(s.result.escaped, PackedStringArray(["enm_mimic"]))
	assert_eq(s.result.credits_stolen, 50, "escaped thief keeps the credits")
	assert_eq(s.result.credits_refunded, 0, "nothing comes back from an escaped thief (GDD §3.11)")
	assert_eq(s.result.credits, 0, "no rewards for escaped enemies")
	assert_eq(s.result.exp, 0)
	assert_eq(s.result.kills, 0)
	var t: PackedStringArray = Fx.types(ev)
	assert_eq(t[t.size() - 1], "BATTLE_END")
	# Refund: the thief is KO'd and the party wins.
	var r: BattleState = _started(["enm_mimic"], {"credits": 50})
	var m2: Combatant = r.get_combatant("e0")
	_until(r, m2)
	r.submit(BattleCommand.skill("e0", "skl_e_fine", PackedStringArray(["p0"])))
	m2.hp = 1
	_until(r, r.get_combatant("p0"))
	r.submit(BattleCommand.attack("p0", "e0"))
	assert_true(r.is_finished())
	assert_eq(r.result.credits_stolen, 0, "refund_on_win: KO'd thief returns the credits")
	assert_eq(r.result.credits_refunded, 40, "the refunded amount is reported separately")
	assert_eq(r.result.credits, 150)


func _until(s: BattleState, c: Combatant) -> void:
	for _i in 20:
		if s.is_finished() or s.current_actor() == c:
			return
		Fx.force_next(s, c)
		s.submit(BattleCommand.defend(s.current_actor().id))


func test_boss_phase_ops_and_order() -> void:
	var s: BattleState = Fx.make_state(data, PackedStringArray(["enm_boss_janitor"]), {"is_boss": true})
	var start: Array[ActionEvent] = s.start()
	var intro: Array[ActionEvent] = Fx.of_type(start, ActionEvent.Type.MOD_LINE)
	assert_eq(intro[0].text, "boss_intro:enm_boss_janitor", "phase 1 on_enter after BATTLE_START")
	assert_len(Fx.of_type(start, ActionEvent.Type.PHASE_CHANGE), 0, "no PHASE_CHANGE for the first phase")
	var t: PackedStringArray = Fx.types(start)
	assert_lt(t.find("MOD_LINE"), t.find("CTB_ORDER"))
	var boss: Combatant = s.get_combatant("e0")
	assert_eq(boss.phase, 0)
	var out: Array[ActionEvent] = []
	var dmg: ActionEvent = ActionEvent.make(ActionEvent.Type.DAMAGE)
	dmg.target_id = "e0"
	ActionResolver.deal_damage(s, boss, 190, dmg, out)        # 380 → 190 = 0.5
	assert_eq(Fx.types(out), PackedStringArray(["DAMAGE", "PHASE_CHANGE", "SUMMON", "MOD_LINE"]))
	assert_eq(out[1].value, 2, "1-based phase index")
	var summon: ActionEvent = out[2]
	assert_eq(summon.def_id, "enm_rat")
	assert_eq(summon.target_id, "e1", "summons continue the enemy numbering")
	assert_eq(summon.value, 1, "lowest free slot")
	var rat: Combatant = s.get_combatant("e1")
	assert_true(rat.is_summon)
	assert_eq(rat.ctb_counter, 22, "summon counter roundi(43 × 0.5)")
	assert_eq(out[3].text, "boss_phase:enm_boss_janitor:2")
	out.clear()
	boss.hp = 300
	ActionResolver.check_phase(s, boss, out)
	assert_len(out, 0, "phases only go forward")
	boss.hp = 190
	var dmg2: ActionEvent = ActionEvent.make(ActionEvent.Type.DAMAGE)
	dmg2.target_id = "e0"
	ActionResolver.deal_damage(s, boss, 120, dmg2, out)       # 70 / 380 < 0.25
	assert_eq(Fx.types(out), PackedStringArray(["DAMAGE", "PHASE_CHANGE", "STATUS_ADDED", "MOD_LINE"]))
	assert_eq(out[2].status_id, "sts_haste")
	assert_eq(out[2].value, 5)
	assert_eq(boss.phase, 2)


func test_phases_are_never_skipped() -> void:
	var s: BattleState = Fx.make_state(data, PackedStringArray(["enm_boss_janitor"]), {"is_boss": true})
	s.start()
	var boss: Combatant = s.get_combatant("e0")
	var out: Array[ActionEvent] = []
	var dmg: ActionEvent = ActionEvent.make(ActionEvent.Type.DAMAGE)
	dmg.target_id = "e0"
	ActionResolver.deal_damage(s, boss, 330, dmg, out)        # 50 / 380 → straight below 0.25
	var phases: Array[int] = []
	for e: ActionEvent in Fx.of_type(out, ActionEvent.Type.PHASE_CHANGE):
		phases.append(e.value)
	assert_eq(phases, [2, 3], "every intermediate phase is entered with its on_enter ops")
	assert_len(Fx.of_type(out, ActionEvent.Type.SUMMON), 1)


func test_pseudo_unit_turn_warning_and_removal() -> void:
	var s: BattleState = Fx.make_state(data, PackedStringArray(["enm_boss_queen"]), {"is_boss": true})
	var start: Array[ActionEvent] = s.start()
	assert_len(Fx.of_type(start, ActionEvent.Type.SUMMON), 2, "queen phase 1 summons 2 rats")
	var queen: Combatant = s.get_combatant("e0")
	var out: Array[ActionEvent] = []
	var dmg: ActionEvent = ActionEvent.make(ActionEvent.Type.DAMAGE)
	dmg.target_id = "e0"
	ActionResolver.deal_damage(s, queen, 300, dmg, out)       # 420 / 720 = 0.58 → phase 2
	var summon: ActionEvent = Fx.of_type(out, ActionEvent.Type.SUMMON)[0]
	assert_eq(summon.target_id, "u0")
	assert_eq(summon.def_id, "pu_train")
	assert_eq(summon.value, -1)
	var train: Combatant = s.get_combatant("u0")
	assert_true(train.is_pseudo)
	assert_eq(train.ctb_counter, 120)
	assert_has(s.preview_order(40), "u0", "the train shows up in the CTB preview (counter 120)")
	assert_false(s.valid_targets(s.get_combatant("p0"), "").has("u0"), "never targetable")
	# Let the train act next; the M.O.D. warning comes once when it reaches preview position <= 2.
	var kai: Combatant = s.get_combatant("p0")
	var mop: Combatant = s.get_combatant("p1")
	mop.defending = false
	if s.current_actor() == null:
		fail("no current actor")
		return
	for o: Combatant in s.combatants:
		o.ctb_counter = 500
	train.ctb_counter = 1
	var actor: Combatant = s.current_actor()
	var ev: Array[ActionEvent] = s.submit(BattleCommand.defend(actor.id))
	var warn: Array[ActionEvent] = Fx.of_type(ev, ActionEvent.Type.MOD_LINE)
	assert_eq(warn.size(), 1)
	assert_eq(warn[0].text, "boss_train_warning")
	var tail: Array[ActionEvent] = []
	var on: bool = false
	for e: ActionEvent in ev:
		if e.type == ActionEvent.Type.TURN_START and e.actor_id == "u0":
			on = true
		if on:
			tail.append(e)
	var tt: PackedStringArray = Fx.types(tail)
	assert_eq(tt.slice(0, 2), PackedStringArray(["TURN_START", "ACTION_START"]))
	assert_eq(tail[1].text, "Einfahrender Zug")
	var hits: Dictionary = {}
	for e: ActionEvent in Fx.of_type(tail, ActionEvent.Type.DAMAGE):
		hits[e.target_id] = e.amount
	var expect_kai: int = 11 if (actor == kai) else 22
	var expect_mop: int = 7 if (actor == mop) else 15
	assert_eq(hits, {"p0": expect_kai, "p1": expect_mop}, "35 % max HP, halved while defending, guard ignored")
	assert_has(tt, "TURN_END")
	assert_eq(train.ctb_counter > 100, true, "ctr_after 160 (minus the next actor's counter)")
	assert_false(train.warned, "warning resets after the train acted")
	# Phase 3 removes the train, deals the fixed self damage and hastes the queen.
	var out3: Array[ActionEvent] = []
	var dmg3: ActionEvent = ActionEvent.make(ActionEvent.Type.DAMAGE)
	dmg3.target_id = "e0"
	queen.hp = 300
	ActionResolver.deal_damage(s, queen, 100, dmg3, out3)     # 200 / 720 < 0.30
	var t3: PackedStringArray = Fx.types(out3)
	assert_eq(t3, PackedStringArray(["DAMAGE", "PHASE_CHANGE", "PSEUDO_REMOVED", "DAMAGE", "STATUS_ADDED", "MOD_LINE"]))
	assert_eq(out3[3].amount, 72)
	assert_eq(queen.hp, 128)
	assert_false(train.is_alive())
	assert_false(s.preview_order(12).has("u0"))
	queen.hp = 30
	var out4: Array[ActionEvent] = []
	queen.phase = 1
	ActionResolver.check_phase(s, queen, out4)
	assert_eq(queen.hp, 1, "fixed_damage_self never goes below min_hp")


func test_autopolicy_defends_before_pseudo_unit() -> void:
	var s: BattleState = Fx.make_state(data, PackedStringArray(["enm_boss_queen"]), {"is_boss": true})
	s.start()
	var queen: Combatant = s.get_combatant("e0")
	var out: Array[ActionEvent] = []
	var dmg: ActionEvent = ActionEvent.make(ActionEvent.Type.DAMAGE)
	dmg.target_id = "e0"
	ActionResolver.deal_damage(s, queen, 300, dmg, out)
	var actor: Combatant = s.current_actor()
	if not actor.is_party():
		_until(s, s.get_combatant("p0"))
		actor = s.current_actor()
	var train: Combatant = s.get_combatant("u0")
	for o: Combatant in s.combatants:
		if o != actor:
			o.ctb_counter = 400
	train.ctb_counter = 5
	assert_eq(AutoPolicy.choose(s, actor).kind, BattleCommand.Kind.DEFEND, "train before the next own turn → defend")
	train.ctb_counter = 1000
	assert_ne(AutoPolicy.choose(s, actor).kind, BattleCommand.Kind.DEFEND)


func test_autopolicy_heal_revive_skill_attack() -> void:
	var s: BattleState = _started(["enm_rat", "enm_slime"], {"mop": {"skills": PackedStringArray(
			["skl_mop_noble_flame", "skl_mop_holy_lick", "skl_mop_revive"])}, "items": {"itm_bandage": 2}})
	var kai: Combatant = s.get_combatant("p0")
	var mop: Combatant = s.get_combatant("p1")
	var rat: Combatant = s.get_combatant("e0")
	var slime: Combatant = s.get_combatant("e1")
	kai.hp = 20                                                  # 31 % < 35 %
	var c: BattleCommand = AutoPolicy.choose(s, mop)
	assert_eq(c.to_dict(), BattleCommand.skill("p1", "skl_mop_holy_lick", PackedStringArray(["p0"])).to_dict(),
			"heal the lowest ratio below 35 %")
	assert_eq(AutoPolicy.choose(s, kai).to_dict(),
			BattleCommand.item("p0", "itm_bandage", PackedStringArray(["p0"])).to_dict(),
			"no heal skill → heal item")
	kai.hp = 0
	assert_eq(AutoPolicy.choose(s, mop).to_dict(),
			BattleCommand.skill("p1", "skl_mop_revive", PackedStringArray(["p0"])).to_dict(), "KO + revive available")
	kai.hp = 64
	slime.hp = 30
	rat.hp = 24
	assert_eq(AutoPolicy.choose(s, mop).to_dict(),
			BattleCommand.skill("p1", "skl_mop_noble_flame", PackedStringArray(["e0"])).to_dict(),
			"damage skill that beats the attack, on the lowest-HP enemy")
	mop.mp = 5
	assert_eq(AutoPolicy.choose(s, mop).to_dict(),
			BattleCommand.skill("p1", "skl_mop_noble_flame", PackedStringArray(["e0"])).to_dict(),
			"no 50 % MP gate: a caster keeps casting while the skill is affordable")
	mop.mp = 3
	assert_eq(AutoPolicy.choose(s, mop).to_dict(), BattleCommand.attack("p1", "e0").to_dict(), "MP < cost → attack")
	rat.hp = 0
	assert_eq(AutoPolicy.choose(s, kai).to_dict(), BattleCommand.attack("p0", "e1").to_dict())


## Rule (2) (02_TECH §5.8, CR M7-B1): expected damage (GDD §3.7 without variance/crit) per MP.
func test_autopolicy_damage_skill_is_chosen_by_extra_damage_per_mp() -> void:
	var s: BattleState = _started(["enm_rat"], {"kai": {"skills": PackedStringArray(
			["skl_kai_cable_whip", "skl_kai_double", "skl_kai_heavy_swing", "skl_kai_sweep"])}})
	var kai: Combatant = s.get_combatant("p0")
	var mop: Combatant = s.get_combatant("p1")
	var rat: Combatant = s.get_combatant("e0")
	var atk: SkillDef = s.skill_def("skl_attack_kai")
	# Kai STR 12 vs rat DEF 5: 144 / 17 = 8.470588 HP; guard: 144 / (12 + 7.5) = 7.384615; Mopsula's Adelsflamme
	# MAG 13 vs RES 3, fire weak: 169 / 16 × 1.1 × 1.5 = 17.428125.
	assert_eq(AutoPolicy._expected_damage(s, kai, atk, rat), 8470588)
	assert_eq(AutoPolicy._expected_damage(s, kai, s.skill_def("skl_kai_heavy_swing"), rat), 13552941)
	assert_eq(AutoPolicy._expected_damage(s, kai, s.skill_def("skl_kai_double"), rat), 8470588, "2 hits × power 50")
	assert_eq(AutoPolicy._expected_damage(s, mop, s.skill_def("skl_mop_noble_flame"), rat), 17428125)
	# One rat: Wuchtschlag (+60 % for 3 MP) beats Kabelpeitsche (+20 % for 8 MP), Rundumfeger (80 %) and the double hit
	# (2 × 50 = the attack) do not beat the attack at all.
	assert_eq(AutoPolicy.choose(s, kai).to_dict(),
			BattleCommand.skill("p0", "skl_kai_heavy_swing", PackedStringArray(["e0"])).to_dict())
	kai.mp = 2
	assert_eq(AutoPolicy.choose(s, kai).to_dict(), BattleCommand.attack("p0", "e0").to_dict(),
			"only the double hit is affordable: no extra damage → attack")
	var out: Array[ActionEvent] = []
	ActionResolver.apply_status(s, rat, "sts_guard", 2, "e0", 1.0, 0, out)
	assert_eq(AutoPolicy._expected_damage(s, kai, atk, rat), 7384615, "guard: D × 1.5")
	# Three rats: the area skill sums its expected damage (3 × 80 % − 100 % = +140 % for 5 MP > +60 % for 3 MP).
	var s3: BattleState = _started(["enm_rat", "enm_rat", "enm_rat"], {"kai": {"skills": PackedStringArray(
			["skl_kai_heavy_swing", "skl_kai_sweep"])}})
	assert_eq(AutoPolicy.choose(s3, s3.get_combatant("p0")).to_dict(),
			BattleCommand.skill("p0", "skl_kai_sweep", PackedStringArray(["e0", "e1", "e2"])).to_dict())
	# Shock-weak boss: Kabelpeitsche is the strongest skill (120 × 1.5 = 180 %) but buys +80 % for 8 MP; Wuchtschlag
	# buys +60 % for 3 MP and is chosen (the old "strongest" rule spent 8 MP here).
	var sb: BattleState = _started(["enm_boss_janitor"], {"is_boss": true, "kai": {"skills": PackedStringArray(
			["skl_kai_cable_whip", "skl_kai_heavy_swing"])}})
	assert_eq(AutoPolicy.choose(sb, sb.get_combatant("p0")).to_dict(),
			BattleCommand.skill("p0", "skl_kai_heavy_swing", PackedStringArray(["e0"])).to_dict())
	sb.get_combatant("p0").mp = 9
	sb.get_combatant("p0").skills = PackedStringArray(["skl_kai_cable_whip"])
	assert_eq(AutoPolicy.choose(sb, sb.get_combatant("p0")).to_dict(),
			BattleCommand.skill("p0", "skl_kai_cable_whip", PackedStringArray(["e0"])).to_dict(),
			"a weaker-per-MP skill is still used while it beats the attack")


## Rule (2), random_enemy: a party actor's random skill draws one living enemy (ActionResolver), so its expected damage
## is the mean over the living enemies, not the damage on the lowest-HP enemy.
func test_autopolicy_random_enemy_skill_uses_the_mean_over_living_enemies() -> void:
	var t: Dictionary = Fx.tables()
	(t["skills"] as Array).append(Fx._skill("skl_kai_wild_swing", "party", "attack", "random_enemy",
			{"damage_type": "physical", "element": "physical", "power": 104, "mp_cost": 2}))
	var s: BattleState = Fx.make_state(fixture_data(t), PackedStringArray(["enm_rat", "enm_pigeon"]),
			{"kai": {"skills": PackedStringArray(["skl_kai_wild_swing"])}})
	s.start()
	var kai: Combatant = s.get_combatant("p0")
	var rat: Combatant = s.get_combatant("e0")
	var pigeon: Combatant = s.get_combatant("e1")
	var wild: SkillDef = s.skill_def("skl_kai_wild_swing")
	# Kai STR 12, power 104: rat DEF 5 → 149.76 / 17 = 8.809412, pigeon DEF 3 → 149.76 / 15 = 9.984; mean 9.396706.
	assert_eq(AutoPolicy._expected_damage(s, kai, wild, pigeon), 9396706)
	assert_eq(AutoPolicy._expected_damage(s, kai, wild, rat), 9396706, "independent of the main target")
	# Lowest HP = pigeon (20 < 24), attack 144 / 15 = 9.6 > the mean → ATTACK (on the pigeon alone the skill would win).
	assert_eq(AutoPolicy.choose(s, kai).to_dict(), BattleCommand.attack("p0", "e1").to_dict())
	pigeon.hp = 0
	assert_eq(AutoPolicy._expected_damage(s, kai, wild, rat), 8809412, "one living enemy: its damage")
	assert_eq(AutoPolicy.choose(s, kai).to_dict(),
			BattleCommand.skill("p0", "skl_kai_wild_swing", PackedStringArray(["e0"])).to_dict(),
			"8.809412 > attack 8.470588 → skill")


func test_autopolicy_never_stunts_or_flees_and_is_valid() -> void:
	for seed in range(1, 21):
		var s: BattleState = Fx.make_state(data, PackedStringArray(["enm_rat", "enm_pigeon", "enm_shaman"]),
				{"seed": seed, "items": {"itm_bandage": 3, "itm_smoke": 1}, "kai": {"skills": PackedStringArray(
				["skl_kai_heavy_swing", "skl_kai_sweep", "skl_kai_first_aid"])},
				"mop": {"skills": PackedStringArray(["skl_mop_noble_flame", "skl_mop_holy_lick", "skl_mop_revive"])}})
		s.start()
		var guard: int = 0
		while not s.is_finished() and guard < 300:
			guard += 1
			var cmd: BattleCommand = s.choose_ai_command()
			assert_eq(s.validate(cmd), "", "AI/auto commands are always valid (seed %d)" % seed)
			if s.current_actor().is_party():
				assert_false(cmd.kind == BattleCommand.Kind.STUNT or cmd.kind == BattleCommand.Kind.FLEE)
				assert_ne(cmd.item_id, "itm_smoke")
			s.submit(cmd)
		assert_true(s.is_finished(), "seed %d terminates" % seed)
