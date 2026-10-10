extends TestCase
## 06 integration D × main (anchored replay after a load): twists across save → load → replay-from-load.
## - The replay buffer (a twist command sorted in AHEAD of its tick) lives in the state (TwistApplier.buffer,
##   GameState.flags["twist_buffer"]): saved, not hashed. A save made while a twist waits keeps it; the next log segment
##   (from_save, its clock starts at 0 again) applies it after the remaining wait — in the core verifier (RunSim) and
##   in the full one (Game.replay_log) exactly like the run that continues after the load.
## - A twist still waiting when a log segment ends is no error any more (it is in the state, result.twists_waiting).
## - An active twist (applied live) keeps counting down across the save and ends at the same exploration second.
## - Both verifiers name a refused twist by its id (RunRules.refused_id / RunRules.twist_refusal).

const TPS: int = 30


func after_each() -> void:
	if Game.state != null:
		Show.end_battle(null)
	Game.state = null
	Game.run_log = null
	Game.sim = null
	Game.quest = null
	Game.mode = &"campaign"
	Game.timer_running = false
	Game.safe_room_clock = false
	Game.in_battle = false
	Game.auto_battle = false
	Game.replaying = false
	Game.settings.regie_twists = true
	Game.clear_blocking_dialogs()


func _tw(tick: int, n: int = 1, id: String = "tw_quiet_please") -> Dictionary:
	return {"t": "twist", "twist": {"schema": 1, "id": id, "n": n, "src": "dev", "params": {}, "duration": 30,
		"tick": tick}}


## A campaign run through the Game facade on floor 2 (its timer runs from the start, so every log segment replays with
## a running clock; floor 1 is "descended" like test_06d_twists._floor2_game).
func _floor2_game(seed: int) -> void:
	Game.new_game(0, "Kai", seed)
	Game.record({"t": "descend"})
	Game.timer_running = false
	Game._floor_done = true
	Events.floor_completed.emit(Game.state.floor_run.index)
	Game.start_floor(2)


## A RunSim-only run on floor 2 (clock running) recording into `rl`.
func _core_run(data: GameData, seed: int, rl: RunLog) -> RunSim:
	var st: GameState = GameState.create_new(data, 0, "Kai", seed, &"prime")
	var sim: RunSim = RunSim.new(data, st, {})
	rl.header = {"schema": 1, "seed": seed, "slot": 0, "player_name": "Kai", "difficulty": "prime", "mode": "campaign",
		"event_id": "", "run_id": "run_core"}
	sim.run_log = rl
	sim.apply({"t": "floor", "floor": 1})
	sim.apply({"t": "descend"})
	sim.apply({"t": "floor", "floor": 2})
	return sim


## Core verifier: a twist buffered at k 700 for tick 1000, a save at 800 (SaveCodec round trip), the next segment
## from the save — same hashes as the uninterrupted run, and RunSim.replay of the from_save log verifies.
func test_core_buffered_twist_survives_a_save_and_the_replay_from_it() -> void:
	var data: GameData = real_data()
	var rl: RunLog = RunLog.new()
	var sim: RunSim = _core_run(data, 2024, rl)
	sim.advance_to(700)
	sim.apply(_tw(1000))
	assert_eq(sim.rejected_cmds, [], "ahead → buffered, not refused")
	assert_eq(TwistApplier.buffered(sim.state).size(), 1)
	sim.advance_to(800)
	# the buffer is no part of the hash: the same run without the early twist has the same checkpoint hash
	var plain: RunLog = RunLog.new()
	var sim_plain: RunSim = _core_run(data, 2024, plain)
	sim_plain.advance_to(800)
	assert_eq(StateHash.of(sim.state), StateHash.of(sim_plain.state), "an early twist keeps the checkpoint hash")
	# save → load (the real save codec, JSON round trip like a save file)
	var file: String = JSON.stringify(SaveCodec.encode(sim.state, "test"))
	var loaded: GameState = SaveCodec.decode(JSON.parse_string(file), data)
	assert_not_null(loaded, "the save decodes: " + "; ".join(SaveCodec.last_errors()))
	assert_eq(TwistApplier.buffered(loaded).size(), 1, "the waiting twist is in the save")
	# the uninterrupted run
	sim.advance_to(2000)
	assert_eq(sim.rejected_cmds, [])
	assert_true(int(TwistApplier.state_of(sim.state).get("n", 0)) == 1, "applied at its tick")
	var reference: String = StateHash.of(sim.state)
	# the run after the load: a new log segment whose clock starts at 0 (Save.load_slot: from_save + anchor)
	var rl2: RunLog = RunLog.new()
	rl2.header = {"schema": 1, "seed": 2024, "slot": 0, "player_name": "Kai", "difficulty": "prime", "mode": "campaign",
		"event_id": "", "run_id": "run_core", "from_save": true, "start_state": loaded.to_dict(),
		"start_hash": StateHash.of(loaded)}
	var sim2: RunSim = RunSim.new(data, loaded, {})
	sim2.run_log = rl2
	sim2.advance_to(1200)                                # 2000 − 800 on the new clock
	assert_eq(sim2.rejected_cmds, [], "due after the load: applied")
	assert_eq(StateHash.of(loaded), reference, "load + remaining wait ≡ uninterrupted run")
	var h2: String = sim2.close("test")
	var out: Dictionary = RunSim.replay(data, rl2)
	assert_eq(out["errors"], PackedStringArray(), "the from_save segment verifies")
	assert_eq(out["final_hash"], h2, "RunSim.replay from the save ≡ the run after the load")
	assert_eq(int(out["result"]["twists_waiting"]), 0)


## Full verifier through the Game facade: a twist waits in the buffer (an external input delivered early), the player
## saves and loads; the run after the load applies it after the remaining wait, Game.replay_log of the from_save log is
## hash-identical, and the log before the load verifies too (its end state still holds the waiting twist: no error).
func test_game_buffered_twist_survives_save_load_and_replay_from_load() -> void:
	Game.settings.regie_twists = false
	_floor2_game(515)
	for i in 3 * TPS:
		Game._dispatch(Game.sim.step(1))
	var due: int = Game.sim.tick() + 300
	var tw: Dictionary = TwistApplier.complete(Game.state, DB.data, {"id": "tw_quiet_please", "src": "dev",
		"duration": 30}, due)
	Game.record({"t": "twist", "twist": tw})               # sorted in at k = now, 10 s ahead of its tick
	TwistApplier.buffer(Game.state, tw, due - Game.sim.tick())
	assert_eq(Save.save_slot(1), OK, Save.last_error())
	var pre_log: RunLog = Game.run_log
	var pre_end: int = Game.sim.tick()
	var pre_hash: String = StateHash.of(Game.state)
	assert_eq(Save.load_slot(1), OK, Save.last_error())
	assert_eq(TwistApplier.buffered(Game.state).size(), 1, "the load restored the waiting twist")
	for i in 400:
		Game._dispatch(Game.sim.step(1))
	assert_true(TwistApplier.active_ids(Game.state).has("tw_quiet_please"), "applied after the remaining wait")
	assert_eq(TwistApplier.buffered(Game.state).size(), 0)
	var live: String = StateHash.of(Game.state)
	var rep: Dictionary = Game.replay_log(Game.run_log, Game.sim.tick())
	assert_eq(rep["errors"], PackedStringArray(), "the from_save segment verifies")
	assert_eq(rep["final_hash"], live, "Game.replay_log from the load ≡ live")
	var pre: Dictionary = Game.replay_log(pre_log, pre_end)
	assert_eq(pre["errors"], PackedStringArray(), "the segment before the load verifies: the twist still waits")
	assert_eq(int(pre["result"]["ticks"]), pre_end, "the replay clock ran to the save")
	assert_eq(int(pre["result"]["twists_waiting"]), 1)
	assert_eq(pre["final_hash"], pre_hash, "Game.replay_log up to the save ≡ live (the buffer is not hashed)")


## An active twist (applied live) across save → load: it keeps counting down exploration time and ends after the
## same number of exploration ticks as without the save; Game.replay_log of the from_save log ≡ live.
func test_active_twist_counts_down_across_save_and_load() -> void:
	Game.settings.regie_twists = false
	var end_ticks: Array = []
	for with_save: bool in [false, true]:
		Game.new_game(1, "Kai", 616)
		Game.state.floor_run.timer_started = true
		assert_eq(Game.apply_twist({"id": "tw_quiet_please", "src": "dev", "duration": 30}), "")
		for i in 5 * TPS:
			Game._dispatch(Game.sim.step(1))
		var sr: String = str((DB.floor_def(1).layout.get("safe_rooms", [{}]) as Array)[0].get("id", ""))
		Game.enter_safe_room(sr)
		if with_save:
			assert_eq(Save.save_slot(1), OK, Save.last_error())
			assert_eq(Save.load_slot(1), OK, Save.last_error())
			Game.enter_safe_room(sr)
		Game.leave_safe_room()
		var n: int = 0
		while TwistApplier.active_ids(Game.state).has("tw_quiet_please") and n < 60 * TPS:
			Game._dispatch(Game.sim.step(1))
			n += 1
		end_ticks.append(n)
		if with_save:
			var live: String = StateHash.of(Game.state)
			var rep: Dictionary = Game.replay_log(Game.run_log, Game.sim.tick())
			assert_eq(rep["errors"], PackedStringArray())
			assert_eq(rep["final_hash"], live, "Game.replay_log from the load ≡ live (active twist)")
	assert_eq(end_ticks[1], end_ticks[0], "the save does not change the twist's remaining exploration time")
	assert_eq(int(end_ticks[0]), 25 * TPS, "30 s twist, 5 s used before the safe room")


## Both verifiers name a refused twist by its id: RunSim.rejected_cmds and Game.replay_log errors.
func test_refused_twists_are_reported_with_their_id_by_both_verifiers() -> void:
	var data: GameData = real_data()
	var rl: RunLog = RunLog.new()
	var sim: RunSim = _core_run(data, 3030, rl)
	sim.advance_to(900)
	sim.apply(_tw(600))                                  # its tick has passed
	assert_eq(sim.rejected_cmds.size(), 1)
	assert_eq(str(sim.rejected_cmds[0]["gift_id"]), "tw_quiet_please", "RunRules.refused_id: the twist id")
	assert_eq(str(sim.rejected_cmds[0]["reason"]), "twist_tick_passed")
	assert_eq(RunRules.refused_id({"t": "twist", "twist": {"id": "tw_overtime"}}), "tw_overtime")
	assert_eq(RunRules.refused_id({"t": "hero", "id": "mopsula"}), "mopsula")
	assert_eq(RunRules.refused_id({"t": "gift", "gift": {"gift_id": "g1"}}), "g1")
	assert_eq(RunRules.refused_id({"t": "floor", "floor": 2}), "")
	# the full verifier: a recorded live twist moved behind its tick
	Game.settings.regie_twists = false
	_floor2_game(3131)
	for i in 2 * TPS:
		Game._dispatch(Game.sim.step(1))
	assert_eq(Game.apply_twist({"id": "tw_quiet_please", "src": "dev", "duration": 30}), "")
	for i in 2 * TPS:
		Game._dispatch(Game.sim.step(1))
	var until: int = Game.sim.tick()
	var forged: RunLog = RunLog.new()
	forged.header = Game.run_log.header.duplicate(true)
	var id: int = 0
	var moved: Dictionary = {}
	for e: Dictionary in Game.run_log.cmds():
		if str((e["c"] as Dictionary)["t"]) == "twist":
			moved = e
			continue
		id += 1
		forged.add_cmd(int(e["k"]), e["c"], id)
	forged.add_cmd(int(moved["k"]) + 30, moved["c"], 0)  # 1 s after its tick
	var rep: Dictionary = Game.replay_log(forged, until)
	assert_true("; ".join(rep["errors"]).contains("(twist 'tw_quiet_please'): refused (twist_tick_passed)"),
		"Game.replay_log names the twist: " + "; ".join(rep["errors"]))
	# the live entry and the verifiers ask the same rules: after "descend" a twist is refused as run_not_active
	Game._floor_done = true
	assert_eq(Game.apply_twist({"id": "tw_lights_out", "src": "dev"}), "run_not_active")
	Game._floor_done = false
