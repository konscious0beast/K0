extends TestCase
## 07 §9.6 (R5a): M.O.D.'s preferences in a real-time combat — the MarottenTracker counts the person's actions only
## (by_ai false: distinct skill / item ids, own SHOW successes), the last kill names the member whose hit, status or
## zone landed it (the AI partner too; a train kill nobody), flee attempts come from the result, duration_sec is a new
## context key (validator and rules agree); the starter preferences are reachable on level 1 (four own actions: slot 1,
## SHOW, a potion, the Partner-Spezial; a first strike).

const RtLive := preload("res://tests/fixtures/rt_live/rt_live.gd")
const K := BattleCommand.Kind
const MarottenCheck := preload("res://core/data/validators/marotten.gd")


func before_each() -> void:
	RtLive.swap_data()


func after_each() -> void:
	Show.abort_battle()
	Game.state = null
	Game.run_log = null
	Game.sim = null
	Game.in_battle = false
	RtLive.restore_data()


static func _ev(t: ActionEvent.Type, fields: Dictionary) -> ActionEvent:
	var e: ActionEvent = ActionEvent.make(t)
	for k: String in fields.keys():
		e.set(k, fields[k])
	return e


func test_the_tracker_counts_the_person() -> void:
	var tr: MarottenTracker = MarottenTracker.new()
	tr.begin(RtKit.setup(RtKit.state(6), RtKit.canned_encounter()), 0)
	assert_true(tr.rt, "a real-time setup")
	var evs: Array[ActionEvent] = [
		_ev(ActionEvent.Type.ACTION_START, {"actor_id": "p0", "command": K.SKILL, "skill_id": "skl_kai_heavy_swing"}),
		_ev(ActionEvent.Type.ACTION_START, {"actor_id": "p0", "command": K.SKILL, "skill_id": "skl_kai_heavy_swing"}),
		_ev(ActionEvent.Type.ACTION_START, {"actor_id": "p1", "command": K.SKILL, "skill_id": "skl_mop_noble_flame",
			"by_ai": true}),
		_ev(ActionEvent.Type.ACTION_START, {"actor_id": "p1", "command": K.SKILL, "skill_id": "skl_mop_holy_lick"}),
		_ev(ActionEvent.Type.ACTION_START, {"actor_id": "p0", "command": K.ITEM, "skill_id": "skl_item_bandage",
			"item_id": "itm_bandage"}),
		_ev(ActionEvent.Type.ACTION_START, {"actor_id": "p0", "command": K.STUNT, "skill_id": "skl_stunt_kai_suplex"}),
		_ev(ActionEvent.Type.STUNT_RESULT, {"actor_id": "p0", "success": true}),
		_ev(ActionEvent.Type.STUNT_RESULT, {"actor_id": "p1", "success": true, "by_ai": true}),
		_ev(ActionEvent.Type.FLEE_RESULT, {"actor_id": "p0", "success": false}),
		_ev(ActionEvent.Type.KO, {"actor_id": "p1", "target_id": "e0", "command": K.SKILL, "by_ai": true}),
	]
	for e: ActionEvent in evs:
		tr.on_battle_event(e)
	var t: Dictionary = tr.tally()
	assert_eq([t["distinct_actions"], t["stunts_success"], t["defends"], t["flee_attempts"], t["last_kill_member"]],
		[4, 1, 0, 0, "mopsula"], "own ids: heavy swing, holy lick (Partner-Spezial), bandage, suplex; AI: none")
	assert_true(bool(t["rt"]))
	tr.on_battle_event(_ev(ActionEvent.Type.KO, {"actor_id": "e0", "target_id": "e3", "command": -1}))
	assert_eq(tr.tally()["last_kill_member"], "", "the train's kill belongs to nobody")
	var ctb: MarottenTracker = MarottenTracker.new()
	ctb.begin(BattleSetup.new(), 0)
	assert_false(ctb.rt)
	assert_false(ctb.tally().has("rt"), "the CTB tally keeps its keys")


func test_context_keys_of_a_real_time_combat() -> void:
	assert_eq(MarottenRules.BATTLE_KEYS, MarottenCheck.BATTLE_KEYS, "rules and validator share the keys")
	assert_has(MarottenRules.BATTLE_KEYS, "duration_sec")
	var st: GameState = RtKit.state(3)
	var r: BattleResult = BattleResult.new()
	r.outcome = BattleResult.Outcome.VICTORY
	r.duration_ticks = 452
	r.flee_attempts = 2
	var rt_ctx: Dictionary = MarottenRules.battle_context(st, RtKit.data(), r, {"rt": true, "flee_attempts": 0})
	assert_eq([rt_ctx["duration_sec"], rt_ctx["flee_attempts"], rt_ctx["defends"]], [15, 2, 0],
		"whole seconds; flight warnings and smoke from the result")
	for key: String in MarottenRules.BATTLE_KEYS:
		assert_true(rt_ctx.has(key), "context key " + key)
	var ctb: BattleResult = BattleResult.new()
	ctb.outcome = BattleResult.Outcome.VICTORY
	var ctb_ctx: Dictionary = MarottenRules.battle_context(st, RtKit.data(), ctb, {"flee_attempts": 1})
	assert_eq([ctb_ctx["duration_sec"], ctb_ctx["flee_attempts"]], [0, 1], "CTB: the tracker's count, no duration")
	var data: GameData = real_data()
	assert_false(data.marotte("mar_brave").expr.eval(rt_ctx, {}, {}), "mar_brave: a flight warning breaks it")
	assert_true(data.marotte("mar_speed").expr.eval(rt_ctx, {}, {}),
		"the real-time mar_speed of floor 2 (07 §9.6, E34): a regular combat of at most 15 s")
	r.duration_ticks = 16 * 30
	assert_false(data.marotte("mar_speed").expr.eval(MarottenRules.battle_context(st, RtKit.data(), r, {"rt": true}),
		{}, {}), "16 s are too slow")


## Level 1, a first strike on two rats: slot 1, the SHOW, a potion and the Partner-Spezial are four own actions —
## mar_variety and mar_sneaky are reachable from the first real fight on.
func test_starter_preferences_on_level_one() -> void:
	var st: GameState = RtKit.state(1, "kai", {"itm_bandage": 2})
	var cmd: Dictionary = RtKit.encounter("enc_rt_rats", [["g1", "enc_rt_rats", [-80, -150, 128]]], {"adv": 1})
	var sim: RtSim = RtKit.sim(cmd, 1, "kai", st)
	var tr: MarottenTracker = MarottenTracker.new()
	tr.begin(sim.setup, 0)
	var wanted: Array = [RtCommand.ability(0, "p0", "skl_kai_heavy_swing", ""),
		RtCommand.ability(0, "p0", "skl_stunt_kai_suplex", ""), RtCommand.item(0, "p0", "itm_bandage", "p0"),
		RtCommand.partner_special(0, "p1")]
	var started: Dictionary = {}
	var events: Array[ActionEvent] = []
	while not sim.is_finished() and sim.tick() < 3000:
		for w: Dictionary in wanted:
			var key: String = str(w.get("skill", w.get("item", w["t"])))
			if not started.has(key) and sim.tick() % 10 == 0:
				var c: Dictionary = w.duplicate()
				c["ct"] = sim.tick()
				sim.submit(c)
		var ev: Array[ActionEvent] = sim.step()
		for e: ActionEvent in ev:
			tr.on_battle_event(e)
			events.append(e)
			if e.type == ActionEvent.Type.ACTION_START and e.actor_id.begins_with("p") and not e.by_ai:
				started[e.item_id if e.item_id != "" else e.skill_id] = true
				if e.actor_id == "p1":
					started["partner_special"] = true
	assert_true(sim.is_finished())
	var ctx: Dictionary = MarottenRules.battle_context(st, RtKit.data(), sim.result, tr.tally())
	assert_eq(ctx["distinct_actions"], 4, "four own actions on level 1: " + str(started.keys()))
	var data: GameData = real_data()
	assert_true(data.marotte("mar_variety").expr.eval(ctx, {}, {}), "mar_variety (starter)")
	assert_true(data.marotte("mar_sneaky").expr.eval(ctx, {}, {}), "mar_sneaky (starter): a first strike")
	assert_eq(ctx["party_turns"], sim.result.party_turns, "party_turns: the person's ACTION_STARTs")
	assert_eq(int(ctx["duration_sec"]), sim.result.duration_ticks / 30)
