extends TestCase
## Game (02_TECH §3.4): command ids, dialog pause reset, quest metric adapter (05 CR-4/CR-13), replay context restore.
## Plus one integration test (live run ≡ replay_log).
## Spies subclass RunLog / QuestTracker, so the unit parts do not depend on the M8 implementations.



class _SpyLog extends RunLog:
	var entries: Array[Dictionary] = []

	func add_cmd(tick: int, cmd: Dictionary, cmd_id: int = 0) -> void:
		entries.append({"k": tick, "id": cmd_id, "c": cmd})


class _SpyQuest extends QuestTracker:
	var events: Array[Dictionary] = []

	func on_event(ev: Dictionary) -> bool:
		events.append(ev)
		return false


func after_each() -> void:
	Game.state = null
	Game.run_log = null
	Game.sim = null
	Game.quest = null
	Game.mode = &"campaign"
	Game.timer_running = false
	Game.in_battle = false
	Game.set_dialog_presenter(false)
	Game.clear_blocking_dialogs()


func test_cmd_ids_strictly_increase_and_external_inputs_get_zero() -> void:
	var log_a: _SpyLog = _SpyLog.new()
	Game.run_log = log_a
	Game.record({"t": "rest"})
	Game.record({"t": "gift", "gift": {}})
	Game.record({"t": "buy", "item": "itm_bandage", "qty": 1, "safe_room": "sr_kiosk"})
	Game.record({"t": "twist"})
	Game.record({"t": "descend"})
	var ids: Array[int] = []
	for e: Dictionary in log_a.entries:
		ids.append(int(e["id"]))
	assert_eq(ids, [1, 0, 2, 0, 3], "player commands 1, 2, 3 …; gift/twist 0 (05 §10.6)")
	var log_b: _SpyLog = _SpyLog.new()
	Game.run_log = log_b
	Game.record({"t": "rest"})
	assert_eq(log_b.entries[0]["id"], 1, "a new run log (new game / Save.load_slot) starts at 1 again")
	Game.replaying = true
	Game.record({"t": "rest"})
	Game.replaying = false
	assert_len(log_b.entries, 1, "no recording while replaying")


func test_blocking_dialogs_pause_only_with_presenter_and_reset() -> void:
	Game.new_game(0, "Kai", 3)
	if not Game.has_state() or Game.state.floor_run == null:
		fail("new_game must create a state with a floor run (M0 stubs / M2)")
		return
	Game.state.floor_run.timer_started = true
	Game.timer_running = true
	assert_true(Game.is_timer_ticking())
	Events.mod_said.emit("Hallo", &"mod", "intro", true)
	assert_true(Game.is_timer_ticking(), "no dialog presenter (no GlobalUi): a blocking line cannot pause forever")
	Game.set_dialog_presenter(true)
	Events.mod_said.emit("Hallo", &"mod", "intro", true)
	assert_false(Game.is_timer_ticking(), "blocking line pauses the countdown")
	Events.dialog_finished.emit("intro")
	assert_true(Game.is_timer_ticking())
	Events.mod_said.emit("Eins", &"mod", "intro", true)
	Events.mod_said.emit("Zwei", &"mod", "intro", true)
	Game.clear_blocking_dialogs()
	assert_true(Game.is_timer_ticking(), "Router goto clears dialogs of freed screens")
	Events.mod_said.emit("Drei", &"mod", "intro", true)
	Game.start_floor(1)
	Game.state.floor_run.timer_started = true
	Game.timer_running = true
	# Show.start_floor may itself start (at most) one blocking line; "Drei" must be gone either way.
	Events.dialog_finished.emit("floor_start")
	assert_true(Game.is_timer_ticking(), "start_floor clears pending dialogs")
	Events.mod_said.emit("Vier", &"mod", "intro", true)
	Game.set_dialog_presenter(false)
	assert_true(Game.is_timer_ticking(), "presenter leaving the tree clears pending dialogs")


func test_quest_adapter_feeds_metrics_from_stats() -> void:
	Game.new_game(0, "Kai", 5)
	if not Game.has_state() or Game.state.show == null:
		fail("new_game must create a state with a ShowState (M0 stubs / M2)")
		return
	var spy: _SpyQuest = _SpyQuest.new()
	Game.mode = &"event_offline"
	Game.quest = spy
	Game.state.show.stats["hype_100_count"] = 1
	Events.hype_changed.emit(100.0, 12.0, &"crit")
	Events.hype_changed.emit(96.0, -4.0, &"boring_fight")
	Game.state.show.stats["viewers_target_peak"] = 2900
	Events.viewers_changed.emit(2900)
	Game.state.show.stats["followers_gained_run"] = 40
	Events.followers_changed.emit(40, 40)
	Events.enemy_killed.emit({"enemy_id": "enm_kanalratte"})
	assert_eq(spy.events, [
		{"type": "metric", "name": "hype_100_count", "value": 1},
		{"type": "metric", "name": "viewers_target_peak", "value": 2900},
		{"type": "metric", "name": "followers_gained_run", "value": 40},
		{"type": "enemy_killed", "enemy_id": "enm_kanalratte"},
	], "metrics only when the stat value changed")
	assert_has(StatIds.ALL, "viewers_target_peak", "CR-13 stat ids")
	assert_has(StatIds.ALL, "followers_gained_run")
	assert_has(StatIds.ALL, "hype_100_count")
	Game.mode = &"campaign"
	Events.viewers_changed.emit(3000)
	assert_len(spy.events, 4, "campaign mode feeds no quest")


func test_replay_restores_the_live_context() -> void:
	Game.new_game(0, "Kai", 7)
	var live: GameState = Game.state
	var live_log: RunLog = Game.run_log
	var live_sim: RunSim = Game.sim
	var spy: _SpyLog = _SpyLog.new()
	spy.header = {"seed": 7, "slot": 0, "player_name": "Kai", "difficulty": "prime", "event_id": ""}
	var res: Dictionary = Game.replay_log(spy)
	assert_true(res.has("final_hash") and res.has("result") and res.has("mismatch_at"))
	assert_eq(res["mismatch_at"], -1)
	assert_true(Game.state == live, "live state restored")
	assert_true(Game.run_log == live_log, "live run log restored")
	assert_true(Game.sim == live_sim, "live sim restored")
	assert_false(Game.replaying)
	assert_eq(Game.mode, &"campaign")
	Game.in_battle = true
	assert_eq(Game.replay_log(spy)["final_hash"], "", "refused during a battle")
	Game.in_battle = false


func test_replay_matches_live_run_integration() -> void:
	Game.auto_battle = true
	Game.new_game(0, "Kai", 4242)
	assert_true(Game.has_state())
	if not Game.has_state():
		return
	var sr_id: String = ""
	var srs: Array = DB.floor_def(1).layout.get("safe_rooms", [])
	if not srs.is_empty():
		sr_id = str(srs[0]["id"])
	if sr_id != "":
		Game.enter_safe_room(sr_id)
		Game.leave_safe_room()
	Game.set_flag("intro_seen", true)
	# §5.7 battle loop without scenes (auto battle for both sides).
	var enc_id: String = DB.floor_def(1).timer_start_after
	var setup: BattleSetup = Game.make_battle_setup(enc_id, BattleSetup.Advantage.NORMAL, "")
	assert_not_null(setup)
	if setup == null:
		return
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
	assert_true(battle.is_finished(), "battle ends")
	Events.battle_ended.emit(battle.result.outcome, battle.result.encounter_id)
	Game.apply_battle_result(battle.result)
	Show.end_battle(battle.result)
	if not Game.state.pending_lootboxes.is_empty():
		Game.open_lootbox(Game.state.pending_lootboxes[0])
	Game.rest_full_heal()
	var live_hash: String = StateHash.of(Game.state)
	assert_ne(live_hash, "")
	var res: Dictionary = Game.replay_log(Game.run_log)
	assert_eq(res["mismatch_at"], -1)
	assert_eq(res["final_hash"], live_hash, "replay of the live log reproduces the state hash")
	var as_json: Variant = JSON.parse_string(JSON.stringify(Game.run_log.to_dict()))
	var reloaded: RunLog = RunLog.from_dict(as_json if as_json is Dictionary else {})
	assert_eq(Game.replay_log(reloaded)["final_hash"], live_hash, "also after a JSON round trip (ints become floats)")
	Game.auto_battle = false


## §5.7 _play without presentation.
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


# --- change requests of the integration phase (M2 CR 1–4, M8 CR 1/2/4/5/7) -------------------------------------------

## §5.7 battle without scenes, both sides on AutoPolicy / EnemyAI; returns the finished battle.
func _auto_battle(enc_id: String) -> BattleState:
	var setup: BattleSetup = Game.make_battle_setup(enc_id, BattleSetup.Advantage.NORMAL, "")
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
	return battle


## M8 CR 1 / 05 §3.3 Nr. 8: the live clock writes checkpoints into Game.run_log (after battles, every 300 ticks);
## Game.replay_log matches every one of them and detects a corrupted one.
func test_live_run_log_gets_checkpoints_that_replay_matches() -> void:
	Game.auto_battle = true
	Game.new_game(0, "Kai", 9191)
	assert_true(Game.sim.run_log == Game.run_log, "the live RunSim records into the run log")
	_auto_battle(DB.floor_def(1).timer_start_after)
	assert_true(Game.state.floor_run.timer_started, "tutorial victory starts the countdown")
	Game.timer_running = true
	for i in 22:
		Game._process(0.5)          # 11 s = 330 ticks
	Game.timer_running = false
	Game.rest_full_heal()
	var cps: Array[Dictionary] = Game.run_log.checkpoints()
	var ks: Array = []
	for cp: Dictionary in cps:
		ks.append(int(cp["k"]))
	assert_eq(ks, [0, 300], "after the battle (written when the clock leaves tick 0) and at tick 300")
	var res: Dictionary = Game.replay_log(Game.run_log)
	assert_eq(res["final_hash"], StateHash.of(Game.state))
	assert_eq(res["mismatch_at"], -1, "every live checkpoint matches the replay")
	var d: Dictionary = Game.run_log.to_dict()
	((d["checkpoints"] as Array)[1] as Dictionary)["h"] = "f".repeat(64)
	assert_eq(int(Game.replay_log(RunLog.from_dict(d))["mismatch_at"]), 1, "a corrupted checkpoint is found")
	Game.auto_battle = false


## M8 CR 1/5: finish_run stores the result in the log (sim.close) and gives ScoreCalc the run-wide summary keys.
func test_finish_run_closes_the_log_with_the_score() -> void:
	Game.auto_battle = true
	Game.start_event_run("evt_offline_gleis9")
	if not Game.has_state():
		fail("start_event_run must create a state")
		return
	_auto_battle(DB.floor_def(1).timer_start_after)
	Game.state.floor_run.stats["party_kos"] = 2      # as BattleBridge books party KOs
	var was_read_only: bool = Save.read_only
	Save.read_only = true
	var summary: Dictionary = Game.finish_run(&"test")
	Save.read_only = was_read_only
	for key: String in ["party_kos", "followers_gained_run", "achievements_in_run", "quest_progress_ppm", "final_hash"]:
		assert_true(summary.has(key), "summary key " + key)
	assert_eq(summary["party_kos"], 2)
	assert_eq(summary["followers_gained_run"], int(Game.state.show.stats.get("followers_gained_run", 0)))
	assert_eq(summary["quest_progress_ppm"], Game.quest.progress_ppm())
	assert_eq(int((summary["breakdown"] as Dictionary)["ko"]), 2 * -150, "KO penalty from the counter (05 §1.5)")
	var res: Dictionary = Game.run_log.result
	assert_eq(res["cause"], "test")
	assert_eq(res["score"], summary["score"])
	assert_eq(res["final_hash"], StateHash.of(Game.state))
	assert_eq(res["final_hash"], summary["final_hash"])
	assert_eq(Game.run_log.checkpoints().back()["h"], res["final_hash"], "final checkpoint")
	assert_eq(Game.finish_run(&"again"), {}, "once per run")
	Game.auto_battle = false


## M2 CR 3: Save.load_slot goes through adopt_loaded_state — the private context of the previous run is gone.
func test_adopt_loaded_state_resets_the_private_run_context() -> void:
	Game.start_event_run("evt_offline_gleis9")
	if not Game.has_state():
		fail("start_event_run must create a state")
		return
	Game.visit_room(Vector2i(1, 7))          # fills the layout cache
	Game.record({"t": "rest"})
	assert_false(Game.event_rules().is_empty(), "event run: rules of the event (M2 CR 2 / M8 CR 2)")
	assert_eq(Game.event_rules().get("leagues", []), ["pur"])
	var loaded: GameState = GameState.create_new(DB.data, 2, "Ada", 77, &"prime")
	var rl: RunLog = RunLog.new()
	rl.header = {"seed": 77, "from_save": true}
	Game.adopt_loaded_state(loaded, rl)
	assert_true(Game.state == loaded)
	assert_eq(Game.mode, &"campaign")
	assert_null(Game.quest)
	assert_eq(Game.event_rules(), {}, "no event def survives the load")
	assert_null(Game._layout, "layout cache cleared")
	assert_false(Game._run_finished)
	assert_true(Game.run_log == rl and Game.sim.run_log == rl, "new log, recorded by the new sim")
	Game.record({"t": "rest"})
	assert_eq(rl.cmds()[0]["id"], 1, "command ids restart at 1")


## M2 CR 1 / M8 CR 7 (05 CR-11): chests roll from FloorRun.loot_seed, never from the public layout seed.
func test_open_chest_rolls_from_the_loot_seed() -> void:
	Game.new_game(0, "Kai", 31337)
	var fr: FloorRun = Game.state.floor_run
	assert_ne(fr.loot_seed, fr.seed)
	var spec: Dictionary = {"id": "f1_c0", "type": "wood", "contents": []}
	var want: Array[LootReward] = LootRoller.roll_chest(spec, DB.data, 1, Game.state,
		SeedUtil.make_rng(SeedUtil.derive(fr.loot_seed, "chest", 0)))
	var got: Array[LootReward] = Game.open_chest("f1_c0")
	assert_eq(_loot_dicts(got), _loot_dicts(want))
	var st: GameState = GameState.create_new(DB.data, 0, "Kai", 31337, &"prime")
	var sim: RunSim = RunSim.new(DB.data, st, {})
	sim.apply({"t": "floor", "floor": 1})
	var credits: int = st.inventory.credits
	sim.apply({"t": "chest", "id": "f1_c0"})
	var cr: int = 0
	for r: LootReward in want:
		if r.kind == "credits":
			cr += r.amount
	assert_eq(st.inventory.credits - credits, cr, "RunSim rolls the same chest (same stream as Game)")


func _loot_dicts(rewards: Array[LootReward]) -> Array:
	var out: Array = []
	for r: LootReward in rewards:
		out.append(r.to_dict())
	return out


## M8 CR 4: the quest adapter also sends zones (first room visits) and boss_hp (Show.boss_hp_changed).
func test_quest_adapter_feeds_zones_and_boss_hp() -> void:
	Game.new_game(0, "Kai", 6)
	var spy: _SpyQuest = _SpyQuest.new()
	Game.mode = &"event_offline"
	Game.quest = spy
	Game.visit_room(Vector2i(1, 7))
	Game.visit_room(Vector2i(1, 7))
	var zones: int = (DB.floor_def(1).layout.get("zones", []) as Array).size()
	assert_eq(spy.events, [{"type": "zones", "explored": 1, "total": zones}], "only first visits")
	spy.events.clear()
	var setup: BattleSetup = Game.make_battle_setup("enc_f1_boss_hausmeister", BattleSetup.Advantage.NORMAL, "")
	Show.begin_battle(setup)
	var e: ActionEvent = ActionEvent.new()
	e.type = ActionEvent.Type.DAMAGE
	e.actor_id = "p0"
	e.target_id = "e0"
	e.def_id = "enm_boss_hausmeister"
	e.value = 100
	e.hp_after = 600
	e.max_hp = 800
	Show.on_battle_event(e)
	assert_has(spy.events, {"type": "boss_hp", "boss_id": "enm_boss_hausmeister", "hp": 600, "max_hp": 800})
	Show.abort_battle()
	Game.in_battle = false
