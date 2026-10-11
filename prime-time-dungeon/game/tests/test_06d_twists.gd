extends TestCase
## 06-D KI-Admin — twists (06 §5.6/§5.7/§5.7a): catalog + validator, the refusal rules (every reason, the shared
## fixture tests/fixtures/live/twist_cases.json that pytest runs too), apply / tick / effects of every slice twist,
## recording through Game.apply_twist (cmd id 0, tick), replay equality incl. the replay buffer (twist sorted in too
## early → same hash, too late → twist_tick_passed, manipulated → refused), RunSim-only runs, fixed event schedules,
## Pur-Liga, the offline Regie (RegieDirector) and the QA tool (Game.dev_random_twist).

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const CASES: String = "res://tests/fixtures/live/twist_cases.json"
const TPS: int = 30


func after_each() -> void:
	Game.state = null
	Game.run_log = null
	Game.sim = null
	Game.quest = null
	Game.mode = &"campaign"
	Game.timer_running = false
	Game.safe_room_clock = false
	Game.in_battle = false
	Game.auto_battle = false
	Game.settings.regie_twists = true
	Game.clear_blocking_dialogs()


# --- helpers ----------------------------------------------------------------------------------------------------------

## A fresh state on `floor` with a running timer (floor 1: the tutorial countdown is started by hand).
func _state(floor_index: int = 2, seed: int = 4242) -> GameState:
	var data: GameData = real_data()
	var st: GameState = GameState.create_new(data, 0, "Kai", seed, &"prime")
	assert_true(RunRules.start_floor(st, data, floor_index), "floor %d" % floor_index)
	st.floor_run.timer_started = true
	return st


func _layout(st: GameState) -> FloorLayout:
	return DungeonGenerator.generate(real_data().floor_def(st.floor_run.index), st.floor_run.seed)


## Validate + apply (complete form) like Game.apply_twist without the facade. "" = applied.
func _apply(st: GameState, tw: Dictionary, tick: int = 0, layout: FloorLayout = null) -> String:
	var data: GameData = real_data()
	var t: Dictionary = TwistApplier.complete(st, data, tw, tick)
	var why: String = TwistApplier.validate(st, data, t, {}, tick, false, layout)
	if why == "":
		TwistApplier.apply(st, data, t, layout)
	return why


## n exploration seconds of twist time (RunSim step 6 only) + the floor's explore-time counter.
func _explore(st: GameState, sec: int) -> PackedStringArray:
	var ended: PackedStringArray = []
	for i in sec * TPS:
		st.floor_run.stats["time_used_ticks"] = int(st.floor_run.stats.get("time_used_ticks", 0)) + 1
		for e: ExploreEvent in TwistApplier.tick(st, real_data(), true, i):
			ended.append(str(e.data.get("id", "")))
	return ended


## A campaign run on floor 2 (the stub floor; Regie twists start there): floor 1 is "descended" like
## Game.complete_floor without the scene flow (the replay does exactly the same for "descend").
func _floor2_game(seed: int) -> void:
	Game.new_game(0, "Kai", seed)
	Game.record({"t": "descend"})
	Game.timer_running = false
	Game._floor_done = true
	Events.floor_completed.emit(Game.state.floor_run.index)
	Game.start_floor(2)


## Live clock like Game._process: one tick, dispatch, Regie decision point.
func _tick_game(n: int) -> void:
	for i in n:
		Game._dispatch(Game.sim.step(1))
		Game._regie_tick()


# --- catalog + validator ----------------------------------------------------------------------------------------------

func test_catalog_has_20_bounded_twists() -> void:
	var data: GameData = real_data()
	var all: Array[TwistDef] = data.all_twists()
	assert_eq(all.size(), 20, "06 §5.6: 20 twists")
	var slice: PackedStringArray = []
	for d: TwistDef in all:
		assert_true(d.id.begins_with("tw_"), d.id)
		assert_between(d.name.length(), 1, 28, d.id + " name fits the chip")
		assert_true(TwistApplier.SCOPES.has(d.scope) and TwistApplier.SPICES.has(d.spice), d.id)
		assert_false(d.sources.is_empty(), d.id)
		for k: Variant in d.params.keys():
			var hard: Array = TwistApplier.PARAM_BOUNDS[str(k)]
			var b: Dictionary = d.params[k]
			assert_true(int(b["min"]) >= int(hard[0]) and int(b["max"]) <= int(hard[1]), "%s.%s inside the hard bounds"
				% [d.id, str(k)])
		if d.mod_tag != "":
			assert_gt(data.mod_lines(d.mod_tag).size(), 0, d.id + " has its M.O.D. line")
		if d.slice:
			slice.append(d.id)
	slice.sort()
	var impl: PackedStringArray = TwistApplier.IMPLEMENTED.duplicate()
	impl.sort()
	assert_eq(slice, impl, "11 twists with an effect in the slice")
	assert_eq(slice.size(), 11)


func _twist_errors(mutate: Callable) -> PackedStringArray:
	var raw: Dictionary = {}
	for t: String in GameData.TABLES:
		raw[t] = JsonUtil.read_file("res://data/%s.json" % t)
	var entries: Array = (raw["twists"] as Dictionary)["entries"]
	mutate.call(entries)
	var d: GameData = GameData.new()
	d.load_from_tables(raw)
	return d.errors


func _expect_twist_error(mutate: Callable, needle: String) -> void:
	var errs: PackedStringArray = _twist_errors(mutate)
	for e: String in errs:
		if e.begins_with("twists") and e.contains(needle):
			return
	fail("expected a twists error containing '%s', got [%s]" % [needle, "; ".join(errs)])


func test_validator_rejects_bad_twists() -> void:
	assert_eq(_twist_errors(func(_e: Array) -> void: pass), PackedStringArray(), "real twists.json is valid")
	_expect_twist_error(func(e: Array) -> void: e[0]["params"]["enemy_sight_pm"]["max"] = 1200, "exceed the hard bounds")
	_expect_twist_error(func(e: Array) -> void: e[0]["params"]["warp"] = {"default": 1, "min": 0, "max": 1},
		"unknown parameter")
	_expect_twist_error(func(e: Array) -> void: e[0]["params"]["enemy_sight_pm"]["default"] = 300,
		"min <= default <= max")
	_expect_twist_error(func(e: Array) -> void: e[0]["duration"]["max"] = 900, "exceed the hard bounds")
	_expect_twist_error(func(e: Array) -> void: e[0]["sources"] = ["hacker"], "not in [")
	_expect_twist_error(func(e: Array) -> void: e[0]["gameplay"] = false, "exactly for scope presentation")
	_expect_twist_error(func(e: Array) -> void: e[15]["slice"] = true, "has no effect in this build")
	_expect_twist_error(func(e: Array) -> void: e[0]["name"] = "Ein viel zu langer Name für den Chip", "longer than 28")
	_expect_twist_error(func(e: Array) -> void: e[0]["id"] = "twist_x", "invalid id")
	_expect_twist_error(func(e: Array) -> void: e[0]["mod_tag"] = "twist_applied_tw_nope", "has no line")


func test_event_rules_twists_are_validated() -> void:
	assert_eq(TwistApplier.validate_rules(null), PackedStringArray())
	assert_eq(TwistApplier.validate_rules({"schedule": [{"tick": 300, "id": "tw_quiet_please"}]}), PackedStringArray())
	assert_gt(TwistApplier.validate_rules({"warp": 1}).size(), 0, "unknown key")
	assert_gt(TwistApplier.validate_rules({"sources": ["hacker"]}).size(), 0, "unknown source")
	assert_gt(TwistApplier.validate_rules({"schedule": [{"tick": 0, "id": "tw_x"}]}).size(), 0, "tick >= 1")
	assert_gt(TwistApplier.validate_rules({"gap_sec": -1}).size(), 0)
	var tr: Dictionary = TwistApplier.rules_of({"leagues": ["show"]})
	assert_eq(Array(tr["sources"]), ["schedule", "dev"], "event runs: no Regie, no AI twists")
	assert_false(bool((tr["regie"] as Dictionary)["enabled"]))
	assert_eq(int(TwistApplier.rules_of({})["min_floor"]), 2, "06 §0.6: twists from floor 2")


# --- the refusal rules ------------------------------------------------------------------------------------------------

## The shared cases (pytest runs the same file against services/mod-brain): both sides decide identically.
func test_shared_twist_cases() -> void:
	var fx: Dictionary = JsonUtil.read_file(CASES)
	var data: GameData = real_data()
	var seen: Dictionary = {}
	for c: Dictionary in fx["cases"]:
		var ctx: Dictionary = (fx["base_ctx"] as Dictionary).duplicate(true)
		ctx.merge(c.get("ctx", {}), true)
		var r: Dictionary = (c.get("rules", {}) as Dictionary).duplicate(true)
		var rules: Dictionary = {}
		if bool(r.get("_event", false)):
			r.erase("_event")
			rules = {"leagues": ["show"], "twists": r}
		elif not r.is_empty():
			rules = {"twists": r}
		var tw: Dictionary = c["twist"]
		var id: String = str(tw.get("id", ""))
		var def_d: Dictionary = data.twist(id).to_dict() if data.has_id("twists", id) else {}
		var got: String = TwistApplier.refusal_for(def_d, tw, ctx, TwistApplier.rules_of(rules))
		assert_eq(got, str(c["expect"]), str(c["name"]))
		seen[str(c["expect"])] = true
	for reason: String in TwistApplier.REASONS:
		assert_true(seen.has(reason), "a shared case for " + reason)


func test_validate_on_real_states() -> void:
	var st: GameState = _state(1)
	assert_eq(_apply(st, {"id": "tw_lights_out", "src": "regie"}), "floor_too_low", "06 §0.6: never on floor 1")
	assert_eq(_apply(st, {"id": "tw_lights_out", "src": "mod_brain"}), "floor_too_low")
	var st2: GameState = _state(2)
	var data: GameData = real_data()
	assert_eq(TwistApplier.validate(st2, data, {"id": "tw_lights_out", "src": "regie"}, {}, 0, true), "wrong_phase",
		"never in a battle")
	st2.floor_run.location = &"sr_x"
	assert_eq(TwistApplier.validate(st2, data, {"id": "tw_lights_out", "src": "regie"}, {}, 0, false), "wrong_phase",
		"never in a safe room")
	st2.floor_run.location = &"start"
	st2.floor_run.timer_started = false
	assert_eq(TwistApplier.validate(st2, data, {"id": "tw_lights_out", "src": "regie"}, {}, 0, false), "wrong_phase",
		"never before the countdown runs")
	st2.floor_run.timer_started = true
	for m: PartyMember in st2.party:
		m.hp = 1
	assert_eq(TwistApplier.context(st2, data, {}, 0, false)["party_hp_pct"] < 50, true)
	var pur: Dictionary = {"leagues": ["pur"]}
	GiftApplier.live_counters(st2)["league"] = "pur"
	assert_eq(TwistApplier.validate(st2, data, {"id": "tw_overtime", "src": "schedule"}, pur, 0, false), "league_pur")
	assert_eq(TwistApplier.validate(st2, data, {"id": "tw_mopsula_moderates", "src": "schedule"}, pur, 0, false), "",
		"Pur-Liga: presentation twists only")


func test_no_state_change_without_twists() -> void:
	var st: GameState = _state(2)
	var before: String = StateHash.of(st)
	TwistApplier.on_floor(st, 2)
	TwistApplier.on_battle_end(st)
	TwistApplier.on_safe_room_enter(st)
	TwistApplier.on_safe_room_exit(st)
	TwistApplier.tick(st, real_data(), true)
	assert_eq(TwistApplier.take_bonus_credits(st, 50), 0)
	assert_eq(StateHash.of(st), before, "runs without twists keep their hash (no flags.live.twist)")
	assert_true(TwistApplier.state_of(st).is_empty())


# --- apply / tick / effects -------------------------------------------------------------------------------------------

func test_lights_out_and_quiet_please_scale_perception_then_cool_down() -> void:
	var st: GameState = _state(2)
	assert_eq(_apply(st, {"id": "tw_lights_out", "src": "regie"}), "")
	assert_eq(TwistApplier.effect_pm(st, "enemy_sight_pm", 1000), 500)
	assert_eq(TwistApplier.effect_pm(st, "enemy_hear_pm", 1000), 1000)
	assert_eq(_apply(st, {"id": "tw_quiet_please", "src": "regie"}), "busy", "one gameplay twist at a time")
	assert_eq(_explore(st, 59), PackedStringArray())
	assert_eq(_explore(st, 1), PackedStringArray(["tw_lights_out"]), "60 s of exploration")
	assert_eq(TwistApplier.effect_pm(st, "enemy_sight_pm", 1000), 1000)
	assert_eq(_apply(st, {"id": "tw_quiet_please", "src": "regie"}), "cooldown", "90 s gap")
	_explore(st, 90)
	assert_eq(_apply(st, {"id": "tw_quiet_please", "src": "regie", "params": {"enemy_hear_pm": 400}}), "")
	assert_eq(TwistApplier.effect_pm(st, "enemy_hear_pm", 1000), 400)


func test_idle_ticks_do_not_count_down() -> void:
	var st: GameState = _state(2)
	_apply(st, {"id": "tw_fog_of_fame", "src": "regie"})
	for i in 200 * TPS:
		TwistApplier.tick(st, real_data(), false)
	assert_eq(TwistApplier.active_ids(st), PackedStringArray(["tw_fog_of_fame"]), "safe-room idle ticks: no countdown")


func test_fog_and_confetti_pause_the_hype_decay_in_runsim() -> void:
	for id: String in ["tw_fog_of_fame", "tw_confetti_gravity"]:
		var st: GameState = _state(2)
		st.show.hype = 60.0
		var sim: RunSim = RunSim.new(real_data(), st, {})
		assert_eq(sim.twist_refusal({"schema": 1, "id": id, "n": 1, "src": "regie", "params": {}, "duration": 30,
			"tick": 0}), "")
		sim.apply({"t": "twist", "twist": {"schema": 1, "id": id, "n": 1, "src": "regie", "params": {}, "duration": 30,
			"tick": 0}})
		sim.advance_to(30 * TPS)
		assert_eq(st.show.hype, 60.0, id + ": no decay while active")
		assert_eq(TwistApplier.active_ids(st), PackedStringArray(), id + " ended after 30 s")
		sim.advance_to(30 * TPS + ShowModel.HYPE_DECAY_TICKS)
		assert_lt(st.show.hype, 60.0, id + ": decay resumes")


func test_double_credits_are_capped() -> void:
	var st: GameState = _state(2)
	_apply(st, {"id": "tw_double_credits", "src": "regie", "params": {"credits_cap": 100}})
	assert_eq(TwistApplier.take_bonus_credits(st, 60), 60, "×2")
	assert_eq(TwistApplier.take_bonus_credits(st, 60), 40, "cap +100 reached")
	assert_eq(TwistApplier.take_bonus_credits(st, 60), 0)
	# through the shared battle path (BattleBridge.apply_result → rw.credits)
	var st2: GameState = _state(2, 77)
	_apply(st2, {"id": "tw_double_credits", "src": "regie"})
	var res: BattleResult = BattleResult.new()
	res.outcome = BattleResult.Outcome.VICTORY
	res.credits = 30
	var before: int = st2.inventory.credits
	var rw: BattleRewards = BattleBridge.apply_result(st2, real_data(), res)
	assert_eq(rw.credits, 60)
	assert_eq(st2.inventory.credits - before, 60)


func test_overtime_adds_time_once_per_floor() -> void:
	var st: GameState = _state(2)
	var left: int = st.floor_run.time_left_ticks
	assert_eq(_apply(st, {"id": "tw_overtime", "src": "regie", "params": {"seconds": 45}}), "")
	assert_eq(st.floor_run.time_left_ticks, left + 45 * TPS)
	assert_eq(TwistApplier.active_ids(st), PackedStringArray(), "instant")
	_explore(st, 120)
	assert_eq(_apply(st, {"id": "tw_overtime", "src": "regie"}), "once_per_floor")
	RunRules.start_floor(st, real_data(), 2)
	st.floor_run.timer_started = true
	assert_eq(_apply(st, {"id": "tw_overtime", "src": "regie"}), "", "a new floor, a new chance")


func test_happy_hour_discounts_the_next_safe_room_visit() -> void:
	var st: GameState = _state(2)
	var data: GameData = real_data()
	var price: int = Shop.price_of(data, "itm_bandage")
	assert_gt(price, 0)
	assert_eq(_apply(st, {"id": "tw_happy_hour", "src": "regie", "params": {"pct": 25}}), "")
	assert_eq(Shop.price_for(st, data, "itm_bandage"), price, "not yet: only during the visit")
	RunRules.enter_safe_room(st, data, "sr_test")
	assert_eq(Shop.price_for(st, data, "itm_bandage"), maxi(1, (price * 750 + 500) / 1000))
	st.inventory.credits = 1000
	assert_true(Shop.buy(st, data, "itm_bandage", 2))
	assert_eq(st.inventory.credits, 1000 - 2 * maxi(1, (price * 750 + 500) / 1000), "Shop.buy pays the discount")
	RunRules.leave_safe_room(st)
	assert_eq(TwistApplier.active_ids(st), PackedStringArray(), "ends with the visit")
	assert_eq(Shop.price_for(st, data, "itm_bandage"), price)



## The vending machine shows the discount: gold "HAPPY HOUR −25 %" pill + reduced prices, only during the visit.
func test_vending_menu_shows_a_running_happy_hour() -> void:
	Game.new_game(0, "Kai", 7)
	var st: GameState = Game.state
	var data: GameData = real_data()
	var price: int = Shop.price_of(data, "itm_bandage")
	var plain: Node = _vending()
	add_to_tree(plain)
	await wait_frames(2)
	assert_eq(plain.find_child("HappyHour", true, false), null, "no pill without a running Happy Hour")
	assert_eq(UiUtil.price_of("itm_bandage"), price)
	plain.queue_free()
	await wait_frames(1)
	st.floor_run.timer_started = true
	assert_eq(_apply(st, {"id": "tw_happy_hour", "src": "dev", "params": {"pct": 25}}), "")
	RunRules.enter_safe_room(st, data, "sr_test")
	var v: Node = _vending()
	add_to_tree(v)
	await wait_frames(2)
	var pill: Node = v.find_child("HappyHour", true, false)
	assert_ne(pill, null, "pill in the header")
	if pill != null:
		assert_eq((pill.get_child(0) as Label).text, "HAPPY HOUR  −25 %")
	assert_eq(UiUtil.price_of("itm_bandage"), maxi(1, (price * 750 + 500) / 1000), "list shows the discounted price")
	v.queue_free()
	await wait_frames(1)



## The 06-D screenshots (docs/screenshots/twist_*.png) come from capture recipes — they must keep existing.
func test_capture_recipes_for_twists_exist() -> void:
	var script: GDScript = load("res://tests/capture_recipes.gd") as GDScript
	assert_true(script != null and script.can_instantiate(), "recipes load")
	if script == null:
		return
	var r: Node = script.new() as Node
	for m: String in ["_r_twist", "_r_safe_happy"]:
		assert_true(r.has_method(m), "recipe " + m)
	r.free()

func _vending() -> Node:
	var n: Node = (load("res://scenes/safe_room/vending_menu.tscn") as PackedScene).instantiate()
	n.call("setup", {})
	return n

func test_rat_rain_spawns_one_stray_out_of_a_free_zone() -> void:
	var st: GameState = _state(1)
	var layout: FloorLayout = _layout(st)
	var data: GameData = real_data()
	var t: Dictionary = TwistApplier.complete(st, data, {"id": "tw_rat_rain", "src": "dev"}, 10)
	assert_eq(TwistApplier.validate(st, data, t, {}, 10, false, layout), "")
	var events: Array[ExploreEvent] = TwistApplier.apply(st, data, t, layout)
	var due: Array = events.filter(func(e: ExploreEvent) -> bool: return e.type == ExploreEvent.Type.STRAY_DUE)
	assert_eq(due.size(), 1, "STRAY_DUE → the exploration spawns it out of sight")
	var gid: String = str((due[0] as ExploreEvent).data["group_id"])
	assert_true(st.floor_run.strays.has(gid))
	assert_eq(st.floor_run.stray_counter, 1)
	# same seed, same n → same zone / encounter (the AI chooses WHAT, never the outcome)
	var st2: GameState = _state(1)
	TwistApplier.apply(st2, data, TwistApplier.complete(st2, data, {"id": "tw_rat_rain", "src": "dev"}, 10),
		_layout(st2))
	assert_eq(st2.floor_run.strays, st.floor_run.strays)
	# every spawner zone occupied → no target
	var st3: GameState = _state(1)
	for sp: Dictionary in layout.spawners:
		st3.floor_run.strays["x_" + str(sp["zone"])] = {"zone": str(sp["zone"]), "enc": "enc_x"}
	assert_eq(TwistApplier.validate(st3, data, {"id": "tw_rat_rain", "src": "dev"}, {}, 0, false, layout), "no_target")


func test_party_hats_count_battles() -> void:
	var st: GameState = _state(2)
	assert_eq(_apply(st, {"id": "tw_party_hats", "src": "regie"}), "")
	assert_eq(TwistApplier.effect_pm(st, "hype_gain_pm", 1000), 1200)
	var res: BattleResult = BattleResult.new()
	res.outcome = BattleResult.Outcome.FLED
	BattleBridge.apply_result(st, real_data(), res)
	assert_eq(TwistApplier.active_ids(st), PackedStringArray(["tw_party_hats"]))
	BattleBridge.apply_result(st, real_data(), res)
	assert_eq(TwistApplier.active_ids(st), PackedStringArray(), "two battles, every outcome counts")


func test_floor_change_ends_twists_and_resets_counters() -> void:
	var st: GameState = _state(2)
	_apply(st, {"id": "tw_lights_out", "src": "regie"})
	_apply(st, {"id": "tw_mopsula_moderates", "src": "regie"})
	assert_eq(TwistApplier.active_ids(st).size(), 2)
	RunRules.start_floor(st, real_data(), 2)
	var ts: Dictionary = TwistApplier.state_of(st)
	assert_eq(TwistApplier.active_ids(st), PackedStringArray())
	assert_eq([int(ts["floor_count"]), int(ts["floor_regie"]), int(ts["end_at"])], [0, 0, -1])
	assert_eq(int(ts["n"]), 2, "the run counter stays")


func test_caps_per_floor_and_regie() -> void:
	var st: GameState = _state(2)
	for id: String in ["tw_overtime", "tw_lights_out", "tw_quiet_please"]:
		assert_eq(_apply(st, {"id": id, "src": "regie"}), "", id)
		_explore(st, 200)
	assert_eq(_apply(st, {"id": "tw_fog_of_fame", "src": "regie"}), "floor_cap", "Regie ≤ 3 per floor")
	assert_eq(_apply(st, {"id": "tw_fog_of_fame", "src": "mod_brain"}), "", "the 4th by another source")
	_explore(st, 200)
	assert_eq(_apply(st, {"id": "tw_party_hats", "src": "mod_brain"}), "floor_cap", "≤ 4 gameplay twists per floor")
	assert_eq(_apply(st, {"id": "tw_mopsula_monologue", "src": "mod_brain"}), "", "presentation is not capped")


# --- Game facade, recording, replay -----------------------------------------------------------------------------------

func test_game_apply_twist_records_external_command() -> void:
	Game.new_game(0, "Kai", 515)
	Game.state.floor_run.timer_started = true
	var got: Array = []
	var cb: Callable = func(tv: Dictionary) -> void: got.append(tv)
	Events.twist_applied.connect(cb)
	assert_eq(Game.apply_twist({"id": "tw_lights_out", "src": "regie"}), "floor_too_low")
	assert_eq(Game.apply_twist({"id": "tw_lights_out", "src": "dev"}), "")
	Events.twist_applied.disconnect(cb)
	assert_eq(got.size(), 1)
	assert_eq([got[0]["id"], got[0]["src"], got[0]["n"]], ["tw_lights_out", "dev", 1])
	var cmds: Array[Dictionary] = Game.run_log.cmds()
	var last: Dictionary = cmds[cmds.size() - 1]
	assert_eq(int(last["id"]), 0, "external input: cmd id 0")
	var tw: Dictionary = (last["c"] as Dictionary)["twist"]
	assert_eq([str((last["c"] as Dictionary)["t"]), int(tw["schema"]), int(tw["n"]), str(tw["src"]), int(tw["tick"])],
		["twist", 1, 1, "dev", Game.sim.tick()])
	assert_eq(Command.validate(last["c"]), "", "recorded shape == Command schema")
	assert_eq(Game.twist_effect_pm("enemy_sight_pm", 1000), 500)
	Game.in_battle = true
	assert_eq(Game.apply_twist({"id": "tw_quiet_please", "src": "dev"}), "wrong_phase", "never in battle")
	Game.in_battle = false


func test_live_run_with_twists_replays_hash_identical() -> void:
	Game.settings.regie_twists = false                   # only the twists of this test
	_floor2_game(616)
	_tick_game(10 * TPS)
	assert_eq(Game.apply_twist({"id": "tw_fog_of_fame", "src": "dev", "duration": 30}), "")
	_tick_game(200 * TPS)
	assert_eq(Game.apply_twist({"id": "tw_overtime", "src": "dev"}), "")
	_tick_game(5 * TPS)
	assert_eq(Game.apply_twist({"id": "tw_mopsula_moderates", "src": "dev", "duration": 60}), "")
	_tick_game(100 * TPS)
	assert_eq(Game.apply_twist({"id": "tw_double_credits", "src": "dev"}), "")
	var live_hash: String = StateHash.of(Game.state)
	var out: Dictionary = Game.replay_log(Game.run_log, Game.sim.tick())
	assert_eq(out["errors"], PackedStringArray())
	assert_eq(out["final_hash"], live_hash, "Game.replay_log ≡ live run with twists")
	assert_eq(out["mismatch_at"], -1)


func _twist_log(entries: Array) -> RunLog:
	var rl: RunLog = RunLog.new()
	rl.header = {"schema": 1, "seed": 717, "slot": 0, "player_name": "Kai", "difficulty": "prime", "mode": "campaign",
		"event_id": "", "run_id": "run_t"}
	var id: int = 0
	for e: Array in entries:
		var c: Dictionary = e[1]
		if Command.is_external(c):
			rl.add_cmd(int(e[0]), c, 0)
		else:
			id += 1
			rl.add_cmd(int(e[0]), c, id)
	return rl


func _tw(tick: int, n: int = 1, id: String = "tw_quiet_please", params: Dictionary = {}) -> Dictionary:
	return {"t": "twist", "twist": {"schema": 1, "id": id, "n": n, "src": "dev", "params": params, "duration": 30,
		"tick": tick}}


## A RunSim-only run (core verifier): floor + timer + twist at tick 600 — then the same twist sorted into the log too
## early (k 30, tick 600) gives the same hash; one whose tick has passed (k 900, tick 600) is refused.
func test_runsim_replay_buffer_rules() -> void:
	var data: GameData = real_data()
	var base: Array = [[0, {"t": "floor", "floor": 1}], [0, {"t": "flag", "key": "intro_seen", "value": true}]]
	var make: Callable = func(entries: Array, until: int) -> Dictionary:
		var st: GameState = GameState.create_new(data, 0, "Kai", 717, &"prime")
		var sim: RunSim = RunSim.new(data, st, {})
		for e: Array in entries:
			sim.advance_to(int(e[0]))
			if str((e[1] as Dictionary)["t"]) == "flag":
				st.floor_run.timer_started = true           # stand-in for the tutorial victory
			sim.apply(e[1])
		sim.advance_to(until)
		return {"hash": StateHash.of(st), "rejected": sim.rejected_cmds}
	var regular: Dictionary = make.call(base + [[600, _tw(600)]], 2400)
	var early: Dictionary = make.call(base + [[30, _tw(600)]], 2400)
	assert_eq(regular["rejected"], [])
	assert_eq(early["hash"], regular["hash"], "twist sorted in too early → buffered → same hash")
	var late: Dictionary = make.call(base + [[900, _tw(600)]], 2400)
	assert_eq((late["rejected"] as Array).size(), 1)
	assert_eq(str((late["rejected"] as Array)[0]["reason"]), "twist_tick_passed")
	assert_ne(late["hash"], regular["hash"])


## The core verifier: a recorded RunSim run with a twist replays through RunSim.replay without errors, same hash.
func test_runsim_recorded_run_with_twist_replays() -> void:
	var data: GameData = real_data()
	var st: GameState = GameState.create_new(data, 0, "Kai", 1212, &"prime")
	var sim: RunSim = RunSim.new(data, st, {})
	var rl: RunLog = RunLog.new()
	rl.header = {"schema": 1, "seed": 1212, "slot": 0, "player_name": "Kai", "difficulty": "prime", "mode": "campaign",
		"event_id": "", "run_id": "run_core"}
	sim.run_log = rl
	sim.apply({"t": "floor", "floor": 1})
	sim.apply({"t": "descend"})
	sim.apply({"t": "floor", "floor": 2})
	sim.advance_to(600)
	sim.apply(_tw(600, 1, "tw_double_credits", {"credits_pm": 1500}))
	sim.advance_to(700)
	sim.apply(_tw(800, 2, "tw_mopsula_monologue"))         # ahead → buffered (duration 30 out of range → refused)
	sim.advance_to(3000)
	var h: String = sim.close("test")
	assert_eq(sim.rejected_cmds.size(), 1, "the monologue's duration (30) is out of range: refused when due")
	var out: Dictionary = RunSim.replay(data, rl)
	assert_eq(out["final_hash"], h, "RunSim.replay ≡ recorded core run")
	assert_eq(out["mismatch_at"], -1)
	assert_eq(out["errors"].size(), 1, "the refused twist is reported: " + "; ".join(out["errors"]))


func test_game_replay_buffer_and_manipulated_twists() -> void:
	Game.settings.regie_twists = false
	_floor2_game(818)
	_tick_game(40 * TPS)
	assert_eq(Game.apply_twist({"id": "tw_quiet_please", "src": "dev", "duration": 30}), "")
	_tick_game(60 * TPS)
	var until: int = Game.sim.tick()
	var live_hash: String = StateHash.of(Game.state)
	var cmds: Array[Dictionary] = Game.run_log.cmds()
	var tw_entry: Dictionary = {}
	for e: Dictionary in cmds:
		if str((e["c"] as Dictionary)["t"]) == "twist":
			tw_entry = e
	assert_false(tw_entry.is_empty())
	var at: int = int(tw_entry["k"])
	var build: Callable = func(k_twist: int, twist: Dictionary) -> RunLog:
		var rl: RunLog = RunLog.new()
		rl.header = Game.run_log.header.duplicate(true)
		var id: int = 0
		var placed: bool = false
		for e: Dictionary in cmds:
			if str((e["c"] as Dictionary)["t"]) == "twist":
				continue
			if not placed and int(e["k"]) > k_twist:
				rl.add_cmd(k_twist, {"t": "twist", "twist": twist}, 0)
				placed = true
			id += 1
			rl.add_cmd(int(e["k"]), e["c"], id)
		if not placed:
			rl.add_cmd(k_twist, {"t": "twist", "twist": twist}, 0)
		return rl
	var tw: Dictionary = (tw_entry["c"] as Dictionary)["twist"]
	var early: Dictionary = Game.replay_log(build.call(0, tw), until)
	assert_eq(early["errors"], PackedStringArray())
	assert_eq(early["final_hash"], live_hash, "buffered until its tick → same hash")
	var late: Dictionary = Game.replay_log(build.call(at + 30, tw), until)
	assert_true("; ".join(late["errors"]).contains("twist_tick_passed"), "late: " + "; ".join(late["errors"]))
	var forged: Dictionary = tw.duplicate(true)
	forged["params"] = {"enemy_hear_pm": 100}
	var bad: Dictionary = Game.replay_log(build.call(at, forged), until)
	assert_true("; ".join(bad["errors"]).contains("params_out_of_range"), "manipulated twist is refused")
	assert_ne(bad["final_hash"], live_hash)


func test_fixed_event_schedule_applies_without_a_command() -> void:
	var data: GameData = real_data()
	var rules: Dictionary = {"leagues": ["show"], "twists": {"schedule": [{"tick": 90, "id": "tw_quiet_please"}],
		"min_floor": 1}}
	var run: Callable = func() -> Array:
		var st: GameState = GameState.create_new(data, 0, "Kai", 919, &"prime")
		var sim: RunSim = RunSim.new(data, st, rules)
		sim.apply({"t": "floor", "floor": 1})
		st.floor_run.timer_started = true
		var applied: Array = []
		for e: ExploreEvent in sim.advance_to(120):
			if e.type == ExploreEvent.Type.TWIST_APPLIED:
				applied.append([e.tick, str((e.data["twist"] as Dictionary)["id"]), str(e.data["src"])])
		return [applied, StateHash.of(st)]
	var a: Array = run.call()
	var b: Array = run.call()
	assert_eq(a[0], [[90, "tw_quiet_please", "schedule"]], "applied at its tick, src schedule")
	assert_eq(a[1], b[1], "identical for everyone (no command, from the rules)")


func test_pur_liga_refuses_gameplay_twists() -> void:
	var data: GameData = real_data()
	var st: GameState = GameState.create_new(data, 0, "Kai", 1, &"prime")
	var sim: RunSim = RunSim.new(data, st, {"leagues": ["pur"], "twists": {"min_floor": 1}})
	sim.apply({"t": "floor", "floor": 1})
	st.floor_run.timer_started = true
	assert_eq(sim.twist_refusal({"schema": 1, "id": "tw_overtime", "n": 1, "src": "dev", "params": {}, "duration": 0,
		"tick": 0}), "league_pur")
	assert_eq(sim.twist_refusal({"schema": 1, "id": "tw_mopsula_monologue", "n": 1, "src": "dev", "params": {},
		"duration": 10, "tick": 0}), "")


# --- Regie ------------------------------------------------------------------------------------------------------------

func test_regie_is_deterministic_and_never_on_floor_one() -> void:
	var data: GameData = real_data()
	var st1: GameState = _state(1)
	st1.floor_run.stats["time_used_ticks"] = 120 * TPS
	assert_false(RegieDirector.is_due(st1, {}), "floor 1: no decision points")
	var picks: Array = []
	for round_i in 2:
		var row: Array = []
		var st: GameState = _state(2, 31337)
		for k in range(1, 30):
			st.floor_run.stats["time_used_ticks"] = k * 120 * TPS
			assert_true(RegieDirector.is_due(st, {}))
			row.append(RegieDirector.decide(st, data, {}, k, null))
		picks.append(row)
	assert_eq(picks[0], picks[1], "same seed → same decisions")
	var hits: int = picks[0].filter(func(d: Dictionary) -> bool: return not d.is_empty()).size()
	assert_between(hits, 3, 20, "~35 % of decision points intervene")
	var st3: GameState = _state(2)
	st3.floor_run.stats["time_used_ticks"] = 120 * TPS + 1
	assert_false(RegieDirector.is_due(st3, {}), "only on the decision tick")
	st3.floor_run.stats["time_used_ticks"] = 120 * TPS
	assert_true(RegieDirector.is_due(st3, {}))
	assert_false(RegieDirector.is_due(st3, {"leagues": ["show"]}), "event runs: no Regie")
	assert_true(RegieDirector.decide(st3, data, {"leagues": ["show"]}, 1, null).is_empty())


func test_regie_rules_of_thumb() -> void:
	var data: GameData = real_data()
	var low_timer: Dictionary = {}
	var weak: Dictionary = {}
	for seed in range(1, 80):
		var st: GameState = _state(2, seed)
		st.floor_run.stats["time_used_ticks"] = 120 * TPS
		st.floor_run.time_left_ticks = 100 * TPS
		var d: Dictionary = RegieDirector.decide(st, data, {}, 1, null)
		if not d.is_empty():
			low_timer[str(d["id"])] = true
		var st2: GameState = _state(2, seed)
		st2.floor_run.stats["time_used_ticks"] = 120 * TPS
		for m: PartyMember in st2.party:
			m.hp = 1
		var d2: Dictionary = RegieDirector.decide(st2, data, {}, 1, null)
		if not d2.is_empty():
			weak[str(d2["id"])] = true
	assert_eq(low_timer.keys(), ["tw_overtime"], "timer < 180 s → only overtime")
	assert_gt(weak.size(), 0)
	for id: Variant in weak.keys():
		assert_true(["helpful", "none"].has(data.twist(str(id)).spice), "weak party → helpful only: " + str(id))


func test_regie_through_game_on_floor_two_replays_identically() -> void:
	_floor2_game(2468)
	var applied: Array = []
	var cb: Callable = func(tv: Dictionary) -> void: applied.append(str(tv.get("src", "")))
	Events.twist_applied.connect(cb)
	_tick_game(25 * 60 * TPS - 30)
	Events.twist_applied.disconnect(cb)
	assert_gt(applied.size(), 0, "the Regie intervened on floor 2")
	assert_true(applied.all(func(s: String) -> bool: return s == "regie"))
	assert_lt(int(TwistApplier.state_of(Game.state).get("floor_regie", 0)), 4, "≤ 3 per floor")
	var out: Dictionary = Game.replay_log(Game.run_log, Game.sim.tick())
	assert_eq(out["errors"], PackedStringArray())
	assert_eq(out["final_hash"], StateHash.of(Game.state), "a Regie run replays hash-identical")


func test_regie_switch_off() -> void:
	_floor2_game(2468)
	Game.settings.regie_twists = false
	_tick_game(12 * 60 * TPS)
	assert_true(TwistApplier.state_of(Game.state).is_empty(), "Regie-Eingriffe: aus → no twists")


func test_dev_random_twist_is_seeded() -> void:
	var ids: Array = []
	for i in 2:
		Game.new_game(0, "Kai", 1357)
		Game.state.floor_run.timer_started = true
		var res: Dictionary = Game.dev_random_twist()
		assert_eq(res["reason"], "", "allowed on floor 1 for QA (dev_any_floor)")
		ids.append(res["id"])
	assert_eq(ids[0], ids[1], "same seed → same test twist")
	var first: TwistDef = DB.data.twist(str(ids[1]))
	for i in 3:
		var again: Dictionary = Game.dev_random_twist()
		if str(again["reason"]) == "" and first.gameplay:
			assert_false(DB.data.twist(str(again["id"])).gameplay, "never a second gameplay twist at once")
	assert_eq(Game.apply_twist({"id": first.id, "src": "dev"}), "busy", "the same twist twice → busy")
