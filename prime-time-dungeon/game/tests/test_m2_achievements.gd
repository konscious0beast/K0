extends TestCase
## M2 achievements (02_TECH §6.1/§6.3, GDD §8): StatIds == validator copy, AchievementTracker with every trigger and
## its payload keys (§6.3), once-only unlocks, flag operands, and the Show unlock handling (box, follower reward by
## tier or explicit, hype +8, M.O.D. line with fallback, toast, counters before the trigger, payload signals).

const Fx := preload("res://tests/test_m2_fixtures.gd")
const KILL: Dictionary = {"enemy_id": "enm_rat", "overkill": false, "by": "attack", "member": "kai"}
const WON: Dictionary = {"party_turns": 4, "min_party_hp": 30, "min_party_hp_pct": 0.5, "crits": 0, "weakness_hits": 0,
	"items_used": 1, "party_kos": 0, "damage_taken": 20, "is_boss": false, "boss_id": "", "encounter_type": "normal",
	"group_id": "f1_g1"}

var _prev_data: GameData = null


func after_each() -> void:
	if _prev_data != null:
		Fx.end_world(_prev_data)
		_prev_data = null


static func _with(base: Dictionary, changes: Dictionary) -> Dictionary:
	var d: Dictionary = base.duplicate(true)
	d.merge(changes, true)
	return d


func test_stat_ids_equal_validator_copy() -> void:
	assert_eq(StatIds.ALL, DataValidator.STAT_IDS, "StatIds.ALL == DataValidator.STAT_IDS (§6.3)")
	assert_len(StatIds.ALL, 21)


## [id, trigger, flags, stats_bad, payload_bad, stats_ok, payload_ok]
func _cases() -> Array:
	return [
		["ach_first_blood", "enemy_killed", {}, {"kills_total": 2}, KILL, {"kills_total": 1}, KILL],
		["ach_overkill", "enemy_killed", {}, {}, KILL, {}, _with(KILL, {"overkill": true})],
		["ach_boss_kill", "enemy_killed", {}, {}, _with(KILL, {"enemy_id": "enm_boss"}), {},
			_with(KILL, {"enemy_id": "enm_boss", "by": "stunt"})],
		["ach_first_win", "battle_won", {}, {"battles_won": 2}, WON, {"battles_won": 1}, WON],
		["ach_one_hp", "battle_won", {}, {}, _with(WON, {"min_party_hp": 2}), {}, _with(WON, {"min_party_hp": 1})],
		["ach_ambush_won", "battle_won", {}, {}, _with(WON, {"encounter_type": "preemptive"}), {},
			_with(WON, {"encounter_type": "ambush"})],
		["ach_titled_win", "battle_won", {"title_ms_5000": true}, {}, WON, {}, _with(WON, {"items_used": 0})],
		["ach_flee_first", "battle_fled", {}, {"battles_fled": 0}, {"encounter_id": "enc_f1_a", "is_boss": false},
			{"battles_fled": 1}, {"encounter_id": "enc_f1_a", "is_boss": false}],
		["ach_preemptive_2", "battle_started", {}, {"preemptives": 3},
			{"encounter_id": "enc_f1_a", "encounter_type": "preemptive", "is_boss": false}, {"preemptives": 2},
			{"encounter_id": "enc_f1_a", "encounter_type": "preemptive", "is_boss": false}],
		["ach_stunt_first", "stunt_resolved", {}, {"stunts_success": 1},
			{"success": false, "member": "kai", "skill_id": "skl_stunt_kai_suplex"}, {"stunts_success": 1},
			{"success": true, "member": "kai", "skill_id": "skl_stunt_kai_suplex"}],
		["ach_combo", "combo", {}, {}, {"member": "kai", "enemy_id": "enm_rat"}, {},
			{"member": "mopsula", "enemy_id": "enm_rat"}],
		["ach_mopsula_ko", "party_ko", {}, {"ko_mopsula": 1}, {"member": "kai"}, {"ko_mopsula": 1},
			{"member": "mopsula"}],
		["ach_boss", "boss_defeated", {}, {}, {"boss_id": "enm_rat", "party_turns": 9}, {},
			{"boss_id": "enm_boss", "party_turns": 9}],
		["ach_sponsor_first", "sponsor_gift", {}, {"sponsor_gifts": 2}, {"sponsor_id": "spn_heal"},
			{"sponsor_gifts": 1}, {"sponsor_id": "spn_heal"}],
		["ach_viewers_3000", "viewers_changed", {}, {}, {"viewers": 2999}, {}, {"viewers": 3000}],
		["ach_chest_metal", "chest_opened", {}, {}, {"chest_id": "f1_c0", "type": "wood"}, {},
			{"chest_id": "f1_c1", "type": "metal"}],
		["ach_vendor_100", "item_bought", {}, {"credits_spent_vendor": 99},
			{"item_id": "itm_bandage", "qty": 1, "cost": 25, "safe_room_id": "sr_kiosk"}, {"credits_spent_vendor": 100},
			{"item_id": "itm_bandage", "qty": 1, "cost": 25, "safe_room_id": "sr_kiosk"}],
		["ach_lootbox_2", "lootbox_opened", {}, {"lootboxes_opened": 1}, {"box_id": "box_bronze", "best_rarity": "rare"},
			{"lootboxes_opened": 2}, {"box_id": "box_bronze", "best_rarity": "rare"}],
		["ach_level_3", "level_up", {}, {}, {"member": "kai", "level": 2}, {}, {"member": "kai", "level": 3}],
		["ach_events_2", "event_completed", {}, {"events_completed": 3}, {"event_id": "fev_x", "choice": "pose"},
			{"events_completed": 2}, {"event_id": "fev_x", "choice": "pose"}],
		["ach_pacifist", "explore_tick", {}, {"explore_seconds_since_battle": 299}, {"seconds_since_battle": 299},
			{"explore_seconds_since_battle": 300}, {"seconds_since_battle": 300}],
		["ach_speedrun", "floor_completed", {}, {}, {"floor": 1, "timer_left": 479}, {}, {"floor": 1, "timer_left": 480}],
	]


func test_tracker_every_trigger_with_payload() -> void:
	var data: GameData = Fx.data()
	var covered: PackedStringArray = []
	for c: Array in _cases():
		var id: String = c[0]
		var trig: String = c[1]
		for key: String in (c[4] as Dictionary).keys():
			assert_has(DataValidator.TRIGGER_PAYLOAD_KEYS[trig], key, "%s payload key %s (§6.3)" % [trig, key])
		var show: ShowState = ShowState.new()
		var flags: Dictionary = (c[2] as Dictionary).duplicate()
		show.stats = (c[3] as Dictionary).duplicate()
		var tr_bad: AchievementTracker = AchievementTracker.new(data, show, flags)
		assert_false(tr_bad.evaluate(trig, c[4]).has(id), id + " must not unlock")
		show.stats = (c[5] as Dictionary).duplicate()
		var unlocked: PackedStringArray = AchievementTracker.new(data, show, flags).evaluate(trig, c[6])
		assert_has(unlocked, id, id + " unlocks")
		assert_has(show.achievements, id, "recorded in ShowState.achievements")
		assert_false(AchievementTracker.new(data, show, flags).evaluate(trig, c[6]).has(id), id + " at most once ever")
		if not covered.has(trig):
			covered.append(trig)
	for t: String in DataValidator.ACH_TRIGGERS:
		assert_has(covered, t, "trigger covered: " + t)


func test_tracker_only_evaluates_its_trigger_and_handles_missing_values() -> void:
	var show: ShowState = ShowState.new()
	show.stats = {"kills_total": 1}
	var tr: AchievementTracker = AchievementTracker.new(Fx.data(), show, {})
	assert_eq(tr.evaluate("battle_won", WON), PackedStringArray(), "enemy_killed achievements need their trigger")
	assert_eq(tr.evaluate("enemy_killed", {}), PackedStringArray(["ach_first_blood"]),
		"missing payload keys are simply false; s. conditions still hold")
	assert_eq(tr.evaluate("no_such_trigger", KILL), PackedStringArray())
	assert_eq(AchievementTracker.new(null, show, {}).evaluate("enemy_killed", KILL), PackedStringArray())


func test_show_unlock_rewards_by_tier() -> void:
	_prev_data = Fx.begin_world()
	var st: GameState = Game.state
	var ids: Array = []
	var boxes: Array = []
	var toasts: Array = []
	var lines: Array = []
	var cb_a: Callable = func(id: String) -> void: ids.append(id)
	var cb_b: Callable = func(id: String) -> void: boxes.append(id)
	var cb_t: Callable = func(text: String, icon: StringName) -> void: toasts.append([text, String(icon)])
	var cb_l: Callable = func(text: String, _v: StringName, tag: String, _b: bool) -> void: lines.append([tag, text])
	Events.achievement_unlocked.connect(cb_a)
	Events.lootbox_earned.connect(cb_b)
	Events.toast_requested.connect(cb_t)
	Events.mod_said.connect(cb_l)
	Show.bump_stat("kills_total")
	Show.trigger("enemy_killed", KILL)
	assert_eq(ids, ["ach_first_blood"])
	assert_eq(boxes, ["box_bronze"])
	assert_has(st.pending_lootboxes, "box_bronze")
	assert_eq(Show.followers(), 20, "bronze → 20 followers")
	assert_eq(Show.hype(), 35.0, "achievement hype +5")
	assert_eq(toasts, [["Erster Kill", "achievement"]])
	assert_eq(lines.back(), ["achievement:ach_first_blood", "Erster Kill! Die Werbekunden atmen auf."])
	assert_eq(st.floor_run.stats["achievements"], 1)
	Show.trigger("enemy_killed", KILL)
	assert_eq(ids.size(), 1, "never twice")
	Show.trigger("battle_won", _with(WON, {"encounter_type": "ambush"}))
	assert_eq(ids.back(), "ach_ambush_won")
	assert_eq(Show.followers(), 20 + 7, "explicit followers (7) instead of the tier value")
	assert_eq(lines.back(), ["achievement_generic", "Achievement: Rückenwind!"], "fallback line with the name")
	Show.trigger("battle_won", _with(WON, {"min_party_hp": 1}))
	assert_eq(Show.followers(), 27 + 40, "silver → 40")
	Show.trigger("boss_defeated", {"boss_id": "enm_boss", "party_turns": 20})
	assert_eq(Show.followers(), 67 + 80, "gold → 80")
	assert_eq(boxes, ["box_bronze", "box_bronze", "box_silver", "box_gold", "box_bronze"],
		"achievement boxes; the gold followers crossed milestone ms_100 (bronze)")
	Show.trigger("enemy_killed", _with(KILL, {"enemy_id": "enm_boss", "by": "stunt"}))
	assert_eq(ids.back(), "ach_boss_kill")
	assert_eq(Show.followers(), 147, "no box and followers -1 → 0 followers")
	assert_eq(boxes.size(), 5, "no box for ach_boss_kill")
	Events.achievement_unlocked.disconnect(cb_a)
	Events.lootbox_earned.disconnect(cb_b)
	Events.toast_requested.disconnect(cb_t)
	Events.mod_said.disconnect(cb_l)


func test_show_flag_condition_from_milestone_title() -> void:
	_prev_data = Fx.begin_world()
	Show.trigger("battle_won", _with(WON, {"items_used": 0}))
	assert_false(Show.is_unlocked("ach_titled_win"), "flag title_ms_5000 not set yet")
	Game.start_floor(2)
	Show.add_followers(5000)
	assert_eq(Game.state.flags.get("title_ms_5000", false), true)
	Show.trigger("battle_won", _with(WON, {"items_used": 0}))
	assert_true(Show.is_unlocked("ach_titled_win"), "f. operand reads GameState.flags")


func test_show_battle_counters_before_trigger_and_battle_started_payload() -> void:
	_prev_data = Fx.begin_world()
	var setup: BattleSetup = BattleSetup.new()
	setup.encounter_id = "enc_f1_a"
	setup.advantage = BattleSetup.Advantage.PREEMPTIVE
	Show.begin_battle(setup)
	assert_false(Show.is_unlocked("ach_preemptive_2"))
	Show.end_battle(null)
	Show.begin_battle(setup)
	assert_true(Show.is_unlocked("ach_preemptive_2"), "preemptives raised before trigger battle_started")
	var ev: ActionEvent = ActionEvent.new()
	ev.type = ActionEvent.Type.STUNT_RESULT
	ev.actor_id = "p0"
	ev.skill_id = "skl_stunt_kai_suplex"
	ev.success = true
	Show.on_battle_event(ev)
	assert_true(Show.is_unlocked("ach_stunt_first"), "stunts_success == 1 already true at the stunt_resolved trigger")
	assert_has(Show.unlocked_this_battle(), "ach_stunt_first")
	assert_has(Show.unlocked_this_battle(), "ach_preemptive_2")
	Show.end_battle(null)


func test_show_trigger_signal_payloads_match_validator_keys() -> void:
	_prev_data = Fx.begin_world()
	var got: Dictionary = {}
	var spies: Dictionary = {"enemy_killed": Events.enemy_killed, "stunt_resolved": Events.stunt_resolved,
		"combo": Events.combo, "party_ko": Events.party_ko, "battle_won": Events.battle_won,
		"battle_fled": Events.battle_fled, "boss_defeated": Events.boss_defeated}
	var cbs: Dictionary = {}
	for name: String in spies:
		var n: String = name
		cbs[n] = func(p: Dictionary) -> void: got[n] = p
		(spies[n] as Signal).connect(cbs[n])
	var setup: BattleSetup = BattleSetup.new()
	setup.is_boss = true
	var kai: Combatant = Combatant.new()
	kai.id = "p0"
	kai.def_id = "kai"
	var mop: Combatant = Combatant.new()
	mop.id = "p1"
	mop.def_id = "mopsula"
	setup.party = [kai, mop]
	Show.begin_battle(setup)
	var evs: Array[ActionEvent] = []
	for spec: Array in [[ActionEvent.Type.ACTION_START, {"actor_id": "p0", "command": BattleCommand.Kind.STUNT,
			"skill_id": "skl_stunt_kai_suplex"}],
			[ActionEvent.Type.STUNT_RESULT, {"actor_id": "p0", "skill_id": "skl_stunt_kai_suplex", "success": true}],
			[ActionEvent.Type.KO, {"target_id": "e0", "def_id": "enm_boss", "actor_id": "p0"}],
			[ActionEvent.Type.COMBO, {"actor_id": "p1", "target_id": "e1", "def_id": "enm_rat"}],
			[ActionEvent.Type.KO, {"target_id": "p1", "def_id": "mopsula", "actor_id": "e1"}]]:
		var e: ActionEvent = ActionEvent.new()
		e.type = spec[0]
		for k: String in spec[1]:
			e.set(k, spec[1][k])
		evs.append(e)
	for e: ActionEvent in evs:
		Show.on_battle_event(e)
	var res: BattleResult = BattleResult.new()
	res.outcome = BattleResult.Outcome.VICTORY
	res.is_boss = true
	res.boss_id = "enm_boss"
	Show.end_battle(res)
	Show.begin_battle(BattleSetup.new())
	var fled: BattleResult = BattleResult.new()
	fled.outcome = BattleResult.Outcome.FLED
	Show.end_battle(fled)
	for name: String in spies:
		(spies[name] as Signal).disconnect(cbs[name])
		assert_true(got.has(name), "signal %s emitted" % name)
		if got.has(name):
			var keys: Array = (got[name] as Dictionary).keys()
			var want: Array = DataValidator.TRIGGER_PAYLOAD_KEYS[name].duplicate()
			keys.sort()
			want.sort()
			assert_eq(keys, want, "payload keys of " + name)
	assert_eq(got["enemy_killed"]["by"], "stunt")
	assert_eq(got["party_ko"]["member"], "mopsula")
	assert_eq(got["combo"], {"member": "mopsula", "enemy_id": "enm_rat"})
