extends TestCase
## Replay equality (05 §2 S0 exit criteria, §11.4): a bot event run driven headless by RunSim WITHOUT autoloads
## (auto battle, force_encounter equivalent via commands, strays, chests, lootbox, rest, gifts, descend) replays via
## RunSim.replay to the same final hash; the same seed gives the same run; a manipulated command is detected
## (mismatch_at >= 0). Plus a thin integration test through the Game facade (event mode, ticks via Game._process).

const EVENT_ID: String = "evt_offline_gleis9"
const BOT_TICKS: int = 3300


func _event() -> EventDef:
	var cat: EventCatalog = EventCatalog.new()
	cat.load_file("res://data/events.json")
	var def: EventDef = cat.get_event(EVENT_ID)
	assert_not_null(def, EVENT_ID)
	return def


func _fight(sim: RunSim) -> void:
	var guard: int = 0
	while sim.battle != null and guard < 600:
		guard += 1
		var cmd: BattleCommand = sim.battle.choose_ai_command()
		sim.apply({"t": "battle", "cmd": cmd.to_dict(), "auto": true})


## The bot: {"log": RunLog, "hash": String, "sim": RunSim}.
func _bot_run(def: EventDef, with_gifts: bool = false) -> Dictionary:
	var data: GameData = real_data()
	var seed: int = def.run_seed()
	var st: GameState = GameState.create_new(data, 0, "Kai", seed, &"prime")
	var rules: Dictionary = {} if with_gifts else def.rules     # gifts only outside the Pur-Liga
	var sim: RunSim = RunSim.new(data, st, rules)
	var rl: RunLog = RunLog.new()
	rl.header = {"schema": 1, "seed": seed, "slot": 0, "player_name": "Kai", "difficulty": "prime",
		"mode": "event_offline", "sim_hz": RunSim.TICKS_PER_SEC, "event_id": def.id, "run_id": "run_bot_%d" % seed}
	sim.run_log = rl
	sim.quest = QuestTracker.from_def(def.quest)
	sim.apply({"t": "floor", "floor": def.floor_index})
	var fdef: FloorDef = data.floor_def(def.floor_index)
	var layout: FloorLayout = DungeonGenerator.generate(fdef, st.floor_run.seed)
	sim.apply({"t": "room", "cell": [layout.start.x, layout.start.y]})
	# force_encounter equivalent: the tutorial group
	var tutorial_group: String = ""
	for g: EnemySpawn in layout.enemies:
		if g.encounter_id == fdef.timer_start_after:
			tutorial_group = g.id
	sim.apply({"t": "encounter", "enc": fdef.timer_start_after, "adv": BattleSetup.Advantage.PREEMPTIVE,
		"group": tutorial_group})
	if with_gifts:
		sim.apply({"t": "gift", "gift": _fixed_gift("chest", "bronze", 1)})     # in battle → BattleState.apply_gift
	_fight(sim)
	for c: ChestSpawn in layout.chests.slice(0, 3):
		sim.apply({"t": "chest", "id": c.id})
	if with_gifts:
		sim.apply({"t": "gift", "gift": _fixed_gift("gold", "", 2)})            # outside → GiftApplier
	var guard: int = 0
	while sim.tick() < BOT_TICKS and not sim.is_over() and guard < 1000:
		guard += 1
		for e: ExploreEvent in sim.step(30):
			if e.type == ExploreEvent.Type.STRAY_DUE and not sim.is_over():
				sim.apply({"t": "encounter", "enc": e.data["encounter_id"], "adv": BattleSetup.Advantage.PREEMPTIVE,
					"group": e.data["group_id"]})
				_fight(sim)
	if not sim.is_over():
		sim.apply({"t": "rest"})
		if not st.pending_lootboxes.is_empty():
			sim.apply({"t": "lootbox", "box": st.pending_lootboxes[0]})
		var sr: String = str(layout.safe_room_ids.values()[0])
		sim.apply({"t": "safe_room", "id": sr})
		sim.apply({"t": "safe_room_exit"})
		sim.apply({"t": "room", "cell": [layout.stairs.x, layout.stairs.y]})
		sim.apply({"t": "descend"})
	var h: String = sim.close("floor_completed" if not sim.is_over() else "defeat")
	return {"log": rl, "hash": h, "sim": sim}


func _fixed_gift(kind: String, tier: String, n: int) -> Dictionary:
	var g: Dictionary = Gift.make_dev(kind, tier, 100)
	g["gift_id"] = "g_dev_bot_%d" % n
	return g


func test_bot_run_replays_bit_for_bit() -> void:
	var def: EventDef = _event()
	if def == null:
		return
	var run: Dictionary = _bot_run(def)
	var rl: RunLog = run["log"]
	var sim: RunSim = run["sim"]
	assert_eq(rl.validate(), PackedStringArray(), "every recorded command passes the schema")
	assert_gt(rl.size(), 20, "battle commands, chests, rooms, …")
	assert_gt(sim.tick(), 3000, "the clock ran (strays spawned at 90 s)")
	assert_gt(rl.checkpoints().size(), 10, "checkpoints every 300 ticks and after battles")
	var stray_battles: int = 0
	for c: Dictionary in rl.cmds():
		if c["c"]["t"] == "encounter" and str(c["c"]["group"]).contains("_s"):
			stray_battles += 1
	assert_gt(stray_battles, 0, "the bot met a stray")
	var res: Dictionary = RunSim.replay(real_data(), rl, def.rules, def.quest)
	assert_eq(res["mismatch_at"], -1, "every checkpoint matches")
	assert_eq(res["final_hash"], run["hash"], "replay → same final hash")
	assert_eq(res["errors"], PackedStringArray())
	assert_eq(res["result"]["ticks"], sim.tick())
	assert_eq(res["result"]["quest_progress_ppm"], sim.quest.progress_ppm(), "quest progress replays too")
	assert_eq(rl.result["final_hash"], run["hash"])


func test_same_seed_same_run() -> void:
	var def: EventDef = _event()
	if def == null:
		return
	var a: Dictionary = _bot_run(def)
	var b: Dictionary = _bot_run(def)
	assert_eq(a["hash"], b["hash"], "deterministic: same seed + same decisions → same state")
	assert_eq((a["log"] as RunLog).digest(), (b["log"] as RunLog).digest(), "and the same log")


func test_json_round_trip_of_the_log() -> void:
	var def: EventDef = _event()
	if def == null:
		return
	var run: Dictionary = _bot_run(def)
	var text: String = JSON.stringify((run["log"] as RunLog).to_dict())
	var back: RunLog = RunLog.from_dict(JSON.parse_string(text))
	assert_eq(back.digest(), (run["log"] as RunLog).digest())
	var res: Dictionary = RunSim.replay(real_data(), back, def.rules, def.quest)
	assert_eq(res["final_hash"], run["hash"], "file → replay (ints became floats)")
	assert_eq(res["mismatch_at"], -1)


func test_manipulated_command_is_detected() -> void:
	var def: EventDef = _event()
	if def == null:
		return
	var run: Dictionary = _bot_run(def)
	var d: Dictionary = (run["log"] as RunLog).to_dict()
	var layout: FloorLayout = DungeonGenerator.generate(real_data().floor_def(1),
		SeedUtil.derive(def.run_seed(), "floor", 1))
	var other_chest: String = layout.chests[layout.chests.size() - 1].id
	var changed: bool = false
	for c: Variant in (d["cmds"] as Array):
		var cd: Dictionary = (c as Dictionary)["c"]
		if cd["t"] == "chest" and not changed:
			cd["id"] = other_chest
			changed = true
	assert_true(changed, "the log has a chest command")
	var res: Dictionary = RunSim.replay(real_data(), RunLog.from_dict(d), def.rules, def.quest)
	assert_true(int(res["mismatch_at"]) >= 0, "a checkpoint after the manipulated command fails")
	assert_ne(res["final_hash"], run["hash"])
	# a battle command aimed at another target
	var d2: Dictionary = (run["log"] as RunLog).to_dict()
	for c: Variant in (d2["cmds"] as Array):
		var cd2: Dictionary = (c as Dictionary)["c"]
		if cd2["t"] == "encounter":
			cd2["adv"] = BattleSetup.Advantage.AMBUSH
			break
	var res2: Dictionary = RunSim.replay(real_data(), RunLog.from_dict(d2), def.rules, def.quest)
	assert_true(int(res2["mismatch_at"]) >= 0, "changed encounter advantage → different battle")


func test_gifts_replay() -> void:
	var def: EventDef = _event()
	if def == null:
		return
	var run: Dictionary = _bot_run(def, true)
	var rl: RunLog = run["log"]
	var gifts: Array = []
	for c: Dictionary in rl.cmds():
		if c["c"]["t"] == "gift":
			gifts.append(c["id"])
	assert_eq(gifts, [0, 0], "external inputs carry cmd id 0")
	var live: Dictionary = (run["sim"] as RunSim).state.flags.get("live", {})
	assert_eq(live.get("gift_ids", []), ["g_dev_bot_1", "g_dev_bot_2"])
	assert_eq(live.get("load_half", 0), 3, "bronze chest 2 + 100 credits 1 (in-battle gifts are booked too)")
	var res: Dictionary = RunSim.replay(real_data(), rl, {}, def.quest)
	assert_eq(res["final_hash"], run["hash"], "gift in battle (apply_gift) and outside (GiftApplier) replay")
	assert_eq(res["mismatch_at"], -1)


# --- thin integration test through the Game facade (02_TECH §3.4 "Replay") -------------------------------------------

func after_each() -> void:
	Game.state = null
	Game.run_log = null
	Game.sim = null
	Game.quest = null
	Game.mode = &"campaign"
	Game.timer_running = false
	Game.in_battle = false
	Game.auto_battle = false


func _play(battle: BattleState, events: Array[ActionEvent]) -> void:
	for e: ActionEvent in events:
		Show.on_battle_event(e)
	if battle.is_finished():
		return
	var g: Dictionary = Show.take_pending_gift(battle)
	if not g.is_empty():
		for e: ActionEvent in battle.apply_gift(g):
			Show.on_battle_event(e)


func test_game_event_run_replays_through_the_facade() -> void:
	Game.auto_battle = true
	Game.start_event_run(EVENT_ID)
	if not Game.has_state():
		fail("start_event_run must create a state")
		return
	assert_eq(Game.mode, &"event_offline")
	assert_not_null(Game.quest)
	assert_eq(Game.state.seed, 424242, "seed_policy fixed")
	assert_eq(Game.state.flags["live"]["league"], "pur", "RunSim stored the run's league")
	var fdef: FloorDef = DB.floor_def(1)
	var setup: BattleSetup = Game.make_battle_setup(fdef.timer_start_after, BattleSetup.Advantage.NORMAL, "")
	var battle: BattleState = BattleState.new(setup, DB.data)
	Show.begin_battle(setup)
	Events.battle_started.emit(setup.encounter_id, setup.is_boss)
	_play(battle, battle.start())
	var guard: int = 0
	while not battle.is_finished() and guard < 400:
		guard += 1
		var cmd: BattleCommand = battle.choose_ai_command()
		Game.record({"t": "battle", "cmd": cmd.to_dict(), "auto": true})
		_play(battle, battle.submit(cmd))
	Events.battle_ended.emit(battle.result.outcome, battle.result.encounter_id)
	Game.apply_battle_result(battle.result)
	Show.end_battle(battle.result)
	assert_true(Game.state.floor_run.timer_started, "the tutorial victory starts the countdown")
	# the live clock: Game._process accumulates frame delta into whole ticks and steps RunSim tick by tick
	var left: int = Game.state.floor_run.time_left_ticks
	Game.timer_running = true
	for i in 12:
		Game._process(0.5)
	Game.timer_running = false
	assert_eq(Game.sim.tick(), 180, "6 s = 180 ticks")
	assert_eq(Game.state.floor_run.time_left_ticks, left - 180)
	assert_eq(Game.state.show.stats["explore_seconds_since_battle"], 6)
	Game.rest_full_heal()
	var srs: Array = fdef.layout.get("safe_rooms", [])
	Game.enter_safe_room(str((srs[0] as Dictionary)["id"]))
	Game.leave_safe_room()
	var live_hash: String = StateHash.of(Game.state)
	var progress: float = Game.quest.progress()
	var cmds: Array[Dictionary] = Game.run_log.cmds()
	assert_eq(cmds.back()["k"], 180, "commands after the ticks carry k = 180")
	var res: Dictionary = Game.replay_log(Game.run_log)
	assert_eq(res["mismatch_at"], -1)
	assert_eq(res["final_hash"], live_hash, "Game.replay_log ≡ live event run (incl. Show reactions and ticks)")
	assert_eq(res["result"]["ticks"], 180)
	assert_almost(float(res["result"]["quest_progress"]), progress)
	assert_eq(Game.state.flags["live"]["league"], "pur", "live context restored")
