extends TestCase
## Replay equality (05 §2 S0 exit criteria, §11.4): a bot event run driven headless by RunSim WITHOUT autoloads
## (auto battle, force_encounter equivalent via commands, strays, chests, lootbox, rest, gifts, descend) replays via
## RunSim.replay to the same final hash; the same seed gives the same run; a manipulated command is detected
## (mismatch_at >= 0); forged gifts (Pur-Liga, repeated gift id) and rejected log entries are reported in "errors";
## without explicit rules the replay takes them from the event catalog (header.event_id). Plus a thin integration test
## through the Game facade (event mode, ticks via Game._process).

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


## The event rules with the Show-Liga and gifts enabled (gifts only outside the Pur-Liga, L5).
func _show_rules(def: EventDef) -> Dictionary:
	var r: Dictionary = def.rules.duplicate(true)
	r["leagues"] = ["show"]
	r["gifts"] = {"enabled": true}
	return r


## The bot: {"log": RunLog, "hash": String, "sim": RunSim}.
func _bot_run(def: EventDef, with_gifts: bool = false) -> Dictionary:
	var data: GameData = real_data()
	var seed: int = def.run_seed()
	var st: GameState = GameState.create_new(data, 0, "Kai", seed, &"prime")
	var rules: Dictionary = _show_rules(def) if with_gifts else def.rules
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
	if with_gifts:
		# viewer gifts need an open Sponsor-Fenster (05 §6.13): a recorded QA window, open across the bot run
		sim.apply({"t": "sponsor_window", "op": "dev_open", "sec": 600, "slots": 4})
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
	assert_eq((run["sim"] as RunSim).rejected_cmds, [] as Array[Dictionary])
	var res: Dictionary = RunSim.replay(real_data(), rl, _show_rules(def), def.quest)
	assert_eq(res["final_hash"], run["hash"], "gift in battle (apply_gift) and outside (GiftApplier) replay")
	assert_eq(res["mismatch_at"], -1)
	assert_eq(res["errors"], PackedStringArray())


## L5: a gift smuggled into a Pur-Liga log is refused by the core at application and reported — the state does not
## change (same final hash as the honest run, every checkpoint still matches), but the verifier sees the error.
func test_forged_gift_in_pur_league_is_reported() -> void:
	var def: EventDef = _event()
	if def == null:
		return
	var run: Dictionary = _bot_run(def)
	var d: Dictionary = (run["log"] as RunLog).to_dict()
	var cmds: Array = d["cmds"]
	var forged: Dictionary = _fixed_gift("gold", "", 7)
	forged["amount"] = 250
	var at: int = cmds.size() / 2
	cmds.insert(at, {"k": int((cmds[at - 1] as Dictionary)["k"]), "id": 0, "c": {"t": "gift", "gift": forged}})
	var forged_log: RunLog = RunLog.from_dict(d)
	assert_eq(forged_log.rejected, 0, "a well-formed external input (id 0, tick order)")
	var res: Dictionary = RunSim.replay(real_data(), forged_log, def.rules, def.quest)
	assert_eq(res["final_hash"], run["hash"], "the gift changed nothing")
	assert_eq(res["mismatch_at"], -1)
	assert_eq((res["errors"] as PackedStringArray).size(), 1, "; ".join(res["errors"]))
	assert_has("; ".join(res["errors"]), "g_dev_bot_7' refused by the core (league_pur)")


## The same gift id twice (05 §6.4 idempotency): the repeat is refused and reported, credits arrive once.
func test_repeated_gift_id_is_reported() -> void:
	var def: EventDef = _event()
	if def == null:
		return
	var run: Dictionary = _bot_run(def, true)
	var d: Dictionary = (run["log"] as RunLog).to_dict()
	var cmds: Array = d["cmds"]
	var at: int = -1
	for i in cmds.size():
		var c: Dictionary = (cmds[i] as Dictionary)["c"]
		if c["t"] == "gift" and c["gift"]["gift_id"] == "g_dev_bot_2":
			at = i
	assert_gt(at, 0, "the gold gift is in the log")
	cmds.insert(at + 1, (cmds[at] as Dictionary).duplicate(true))
	var res: Dictionary = RunSim.replay(real_data(), RunLog.from_dict(d), _show_rules(def), def.quest)
	assert_eq(res["final_hash"], run["hash"], "applied once")
	assert_eq((res["errors"] as PackedStringArray).size(), 1, "; ".join(res["errors"]))
	assert_has("; ".join(res["errors"]), "g_dev_bot_2' refused by the core (duplicate)")


## No explicit rules → the event of header.event_id from data/events.json (rules + quest), never from the log.
func test_replay_takes_rules_and_quest_from_the_catalog() -> void:
	var def: EventDef = _event()
	if def == null:
		return
	var run: Dictionary = _bot_run(def)
	var rl: RunLog = run["log"]
	var res: Dictionary = RunSim.replay(real_data(), rl)
	assert_eq(res["errors"], PackedStringArray())
	assert_eq(res["final_hash"], run["hash"], "the Pur-Liga rules (flags.live) come from the catalog")
	assert_eq(res["mismatch_at"], -1)
	assert_eq(res["result"]["quest_progress_ppm"], (run["sim"] as RunSim).quest.progress_ppm(), "and the quest")
	var d: Dictionary = rl.to_dict()
	(d["header"] as Dictionary)["rules"] = _show_rules(def)
	var forged: Dictionary = _fixed_gift("gold", "", 8)
	(d["cmds"] as Array).append({"k": rl.cmds().back()["k"], "id": 0, "c": {"t": "gift", "gift": forged}})
	var res2: Dictionary = RunSim.replay(real_data(), RunLog.from_dict(d))
	assert_has("; ".join(res2["errors"]), "league_pur", "rules in the header are ignored (not trustworthy)")
	(d["header"] as Dictionary)["event_id"] = "evt_missing"
	var res3: Dictionary = RunSim.replay(real_data(), RunLog.from_dict(d))
	assert_has("; ".join(res3["errors"]), "event 'evt_missing' not found")
	assert_eq(res3["final_hash"], "", "no replay without the event rules")


## Entries the RunLog dropped on load (tick order, duplicate id, player command with id 0) are errors of the replay.
func test_rejected_log_entries_are_errors() -> void:
	var def: EventDef = _event()
	if def == null:
		return
	var run: Dictionary = _bot_run(def)
	var d: Dictionary = (run["log"] as RunLog).to_dict()
	(d["cmds"] as Array).insert(3, {"k": 0, "id": 0, "c": {"t": "rest"}})
	var res: Dictionary = RunSim.replay(real_data(), RunLog.from_dict(d), def.rules, def.quest)
	assert_eq(res["final_hash"], run["hash"], "the extra player command was dropped")
	assert_has("; ".join(res["errors"]), "1 entries rejected")


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
		var gift_events: Array[ActionEvent] = battle.apply_gift(g)
		Show.note_battle_gift(g, gift_events)
		for e: ActionEvent in gift_events:
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
	assert_eq(res["final_hash"], live_hash, "Game.replay_log ≡ live event run (incl. Show reactions and ticks)")
	assert_eq(res["result"]["ticks"], 180)
	assert_almost(float(res["result"]["quest_progress"]), progress)
	assert_eq(Game.state.flags["live"]["league"], "pur", "live context restored")
	_assert_game_checkpoints(Game.run_log, res)


## Game.replay_log compares checkpoints, but Game does not record any yet (pending CR 1: Game sets sim.run_log) — on
## such a log mismatch_at is -1 by construction and proves nothing, so the facade tests rely on final_hash. Once Game
## records checkpoints this checks both directions: all match, and a corrupted checkpoint hash is detected.
func _assert_game_checkpoints(rl: RunLog, res: Dictionary) -> void:
	if rl.checkpoints().is_empty():
		return
	assert_eq(res["mismatch_at"], -1, "every checkpoint of the live run matches")
	var d: Dictionary = rl.to_dict()
	((d["checkpoints"] as Array)[0] as Dictionary)["h"] = "0".repeat(64)
	assert_true(int(Game.replay_log(RunLog.from_dict(d))["mismatch_at"]) >= 0, "a corrupted checkpoint is detected")
