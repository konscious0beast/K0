extends TestCase
## 09 §11.6 test_09_replay — the season parts of ST1-B: a season session (the start, the clock across day 0 and the
## daily programme, the stairs, safe rooms, a Sendepause, collapses with a rescue, the tempo switch and the end of the
## Am-Stück countdown, the logout "sleep") in both verifiers: RunSim.replay reproduces the RunSim-recorded session and
## Game.replay_log a live one through Game bit for bit, and across the verifiers the season block and the whole core
## state agree — only the Show's own part (viewers, followers, achievements, Marotten and their lootboxes) is
## Game.replay_log's alone, like in every campaign run (05 §11.4). Tampered clock commands are reported (a jump over
## seven days, a clock Am Stück or after the logout, a forged schedule, a changed duration, a clock with a player id, a
## clock of zero seconds); runs without a season are bit-identical to the golden values of main before ST1-B (bc54fca).
## "away" (ST1-G), "prof" / "craft" (ST1-E) and "talent" v2 (ST1-D) join the session with their packages.
## ST1-G: a night in a corridor ("sleep" with its cell and tactic, a Sendepause of the night, "away" with encounters
## fought in RtSim) in both verifiers — recorded by RunSim and live through Game's logout and login.

const Kit := preload("res://tests/fixtures/season_core/season_core.gd")
const RtLive := preload("res://tests/fixtures/rt_live/rt_live.gd")
const Harness := preload("res://tests/tools/rt_harness.gd")
const GameReplayScript := preload("res://autoload/game_replay.gd")
const ROOT: String = "user://test_09_replay"
const DAY: int = Kit.DAY
const DAY0: int = Kit.DAY0
const EVENT_ID: String = "evt_offline_gleis9"
## The runs without a season on main bc54fca, before ST1-B (golden_values; computed there twice, equal) — a package
## that changes such a run on purpose updates them and says why.
const GOLDEN: Dictionary = {
	"fresh_json": "14d8a1be6749a4e9103315ad4459bfb207fd0c3c98e87f68508be97c8d4cae40",
	"fresh_hash": "b05a702ca9c76ef2c1309a78c476221e953d87a2efc09e9ce3aa3bc2ad1fb036",
	"core_hash": "97b9253367bf05e8101327a48bcfbba2de3a9cbf4a470d6a9b502a1c79216db2",
	"core_log": "1e250b2a1021f515e8c04a6f75695c9b6310d1a02350aae8fee9da0e59fd2d7f",
	"core_save": "5d9abf9cceaf8b479623e6b702c67c0bad789a909335af80cc2fd5fc1d1e2060",
	"game_hash": "df94ba2521d010713eabbe9fc3b7e6dcfcb2da8e6758dba741fd19a7e8493066",
	"game_log": "208e5a88c1d4246dc312c58d17dd35a2fe7987369ec750c9e70d1857fe096ec7",
	"event_hash": "a149bcbed20bfdc5a011fbb2215451cf516a5c95514e7d1b7564d33970759c2b",
	"event_log": "908ae18121b64a614a0f7ed34772812ebaaf194e83c5d4da740720a99e4d9add",
}

var _data: GameData = null


func before_each() -> void:
	_data = DB.data
	Save.save_dir = ROOT.path_join("saves")
	Save.read_only = false


func after_each() -> void:
	DB.data = _data
	if Game.combat != null:
		Game.end_combat()
	Show.abort_battle()
	Game.state = null
	Game.run_log = null
	Game.sim = null
	Game.quest = null
	Game.persona = null
	Game.mode = &"campaign"
	Game.timer_running = false
	Game.in_battle = false
	Save._journal_close()
	Save.save_dir = "user://saves"
	_rmrf(ROOT)


static func _rmrf(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for f: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	for sub: String in DirAccess.get_directories_at(path):
		_rmrf(path.path_join(sub))
	DirAccess.remove_absolute(path)


static func _first_safe_room(d: GameData, st: GameState) -> String:
	var layout: FloorLayout = DungeonGenerator.generate(d.floor_def(st.floor_run.index), st.floor_run.seed)
	return str(layout.safe_room_ids[layout.safe_rooms[0]])


## A season session recorded by RunSim on the placeholder floors (Kit): {"sim": RunSim, "kinds": every SEASON kind in
## order}. Day 0 and its programme, a Sendepause, the collapse of floor 1 with the candidate on it (the dress
## rehearsal), Am Stück on floor 2 until its countdown ends (the collapse, a paid rescue), the stairs, the logout.
static func _core_session() -> Dictionary:
	var d: GameData = Kit.data(6)
	var s: RunSim = Kit.sim(d, "ssn_basis", "calendar", "net", 31)
	var ev: Array = []
	ev.append_array(s.apply({"t": "clock", "sec": 600}))
	var layout: FloorLayout = DungeonGenerator.generate(d.floor_def(1), s.state.floor_run.seed)
	ev.append_array(s.apply({"t": "room", "cell": [layout.start.x, layout.start.y]}))
	ev.append_array(s.apply({"t": "safe_room", "id": _first_safe_room(d, s.state)}))
	ev.append_array(Kit.clock_to(s, DAY0 + 3600))                     # day 0: the daily programme
	ev.append_array(s.apply({"t": "safe_room_exit"}))
	ev.append_array(s.apply({"t": "season", "v": 1, "op": "pause", "sec": 7200, "why": "user"}))
	ev.append_array(Kit.clock_to(s, DAY0 + 2 * DAY + 7200))           # floor 1 collapses: rescued to floor 2
	ev.append_array(s.apply({"t": "safe_room_exit"}))
	ev.append_array(s.apply({"t": "season", "v": 1, "op": "tempo"}))  # Am Stück from here
	ev.append_array(s.step(SeasonClock.binge_ticks(2) + 30))          # the countdown of floor 2 ends: its collapse
	ev.append_array(s.apply({"t": "safe_room_exit"}))
	ev.append_array(s.apply({"t": "descend"}))                        # the stairs (Am Stück: no limit)
	ev.append_array(s.apply({"t": "floor", "floor": 4}))
	ev.append_array(s.step(300))
	ev.append_array(s.apply({"t": "sleep", "tactic": "careful"}))     # the logout
	return {"sim": s, "kinds": Kit.kinds(ev)}


# --- a season session in both verifiers ---------------------------------------------------------------------------

func test_a_season_session_in_both_verifiers() -> void:
	var run: Dictionary = _core_session()
	var s: RunSim = run["sim"]
	assert_eq(s.rejected_cmds, [] as Array[Dictionary], "every command accepted")
	for k: String in ["daily", "pause", "collapse", "rescue", "tempo", "sleep"]:
		assert_has(run["kinds"], k, "the session has a " + k)
	var st: SeasonState = s.state.season
	assert_eq([s.state.floor_run.index, st.collapsed, st.tempo, st.asleep, st.stairs, st.rescues, st.vest], [4, 2,
		"binge", true, 1, 1, false], "floor 4 by the stairs, two collapses, Am Stück, asleep, one rescue that counts")
	var live: String = StateHash.of(s.state)
	var r: Dictionary = RunSim.replay(s.data, s.run_log)
	assert_eq([r["errors"], r["mismatch_at"], r["final_hash"]], [PackedStringArray(), -1, live], "RunSim.replay")
	var file: RunLog = RtLive.round_trip(s.run_log)
	assert_eq(RunSim.replay(s.data, file)["final_hash"], live, "the log as a file (ints became floats)")
	DB.data = s.data
	var gr: RefCounted = GameReplayScript.new(Game)
	var g: Dictionary = gr.call("run", s.run_log, -1)
	assert_eq(g["errors"], PackedStringArray(), "Game.replay_log accepts every entry")
	var shown: GameState = gr.get("_final_state")
	assert_not_null(shown)
	if shown != null:
		assert_eq(_core_part(shown), _core_part(s.state), "Game.replay_log: the season and the core state agree")
		assert_eq(shown.season.to_dict(), s.state.season.to_dict(), "the season block")


## ST1-G: a sleeper in the dangerous quarter of floor 1 (Gleis 9) for 30 h — the rolls, the fights in RtSim, the
## Sendepause of the night — replays to the same hash in RunSim.replay and Game.replay_log.
func test_a_night_in_both_verifiers() -> void:
	var d: GameData = Kit.data(6)
	var s: RunSim = Kit.sim(d, "ssn_basis", "calendar", "net", 33)
	var layout: FloorLayout = DungeonGenerator.generate(d.floor_def(1), s.state.floor_run.seed)
	var cell: Vector2i = SleepResolver.NO_CELL
	for c: Vector2i in layout.sorted_cells():
		if SleepResolver.danger_of(d.floor_def(1), layout, c) == 2 and cell == SleepResolver.NO_CELL:
			cell = c
	var ev: Array = []
	ev.append_array(s.apply({"t": "clock", "sec": 600}))
	ev.append_array(s.apply({"t": "sleep", "tactic": "attack", "cell": [cell.x, cell.y]}))
	ev.append_array(s.apply({"t": "season", "v": 1, "op": "pause", "sec": 3 * 3600, "why": "user"}))
	ev.append_array(s.apply({"t": "away", "sec": 30 * 3600}))
	assert_eq(s.rejected_cmds, [] as Array[Dictionary], "every command accepted")
	assert_gt(Kit.kinds(ev).count("meet"), 0, "the night met something")
	var away: Dictionary = Kit.event(ev, "away")
	assert_eq([away["tactic"], away["cell"], away["quiet"]], ["attack", [cell.x, cell.y], 3 * 3600])
	var live: String = StateHash.of(s.state)
	var r: Dictionary = RunSim.replay(s.data, s.run_log)
	assert_eq([r["errors"], r["mismatch_at"], r["final_hash"]], [PackedStringArray(), -1, live], "RunSim.replay")
	DB.data = s.data
	var gr: RefCounted = GameReplayScript.new(Game)
	var g: Dictionary = gr.call("run", s.run_log, -1)
	assert_eq(g["errors"], PackedStringArray(), "Game.replay_log accepts every entry")
	var shown: GameState = gr.get("_final_state")
	if shown != null:
		assert_eq(_core_part(shown), _core_part(s.state), "Game.replay_log: the night agrees")
		assert_eq(shown.season.to_dict(), s.state.season.to_dict(), "the season block")
	# live: Game's logout and login (the wall clock moved back by 30 h) — Game.replay_log and RunSim.replay
	DB.data = _data
	assert_true(Game.start_season(0, "ssn_basis", {"now": Kit.START, "tz_sec": 0, "seed": 34}))
	var gl: FloorLayout = DungeonGenerator.generate(DB.floor_def(1), Game.state.floor_run.seed)
	var gcell: Vector2i = SleepResolver.NO_CELL
	for c: Vector2i in gl.sorted_cells():
		if SleepResolver.danger_of(DB.floor_def(1), gl, c) == 1 and gcell == SleepResolver.NO_CELL:
			gcell = c
	Game.visit_room(gcell)
	Game.season_note_cell(gcell)
	assert_true(Game.season_logout("careful", gcell))
	var ro: bool = Save.read_only
	Save.read_only = true
	Game.season_live_clock = true
	Game.state.season.seen_unix = int(Time.get_unix_time_from_system()) - 30 * 3600
	Game.season_login()
	Game.season_live_clock = false
	Save.read_only = ro
	assert_false(Game.state.season.asleep, "awake after the login")
	assert_false(Game.season_wake.is_empty(), "the wake summary")
	Game.season_wake = {}
	var types: Array = RtLive.cmd_types(Game.run_log)
	for t: String in ["sleep", "away"]:
		assert_has(types, t)
	var glive: String = StateHash.of(Game.state)
	var gg: Dictionary = Game.replay_log(Game.run_log)
	assert_eq([gg["errors"], gg["mismatch_at"], gg["final_hash"]], [PackedStringArray(), -1, glive], "Game.replay_log")
	var rr: Dictionary = RunSim.replay(DB.data, Game.run_log)
	assert_eq(rr["errors"], PackedStringArray(), "RunSim.replay accepts every entry")
	var core: GameState = _core_replay(DB.data, Game.run_log)
	assert_eq(_core_part(core), _core_part(Game.state), "RunSim.replay: the night and the core state agree")


func test_a_live_season_session() -> void:
	assert_true(Game.start_season(0, "ssn_basis", {"now": Kit.START, "tz_sec": 0, "seed": 32}))
	var layout: FloorLayout = DungeonGenerator.generate(DB.floor_def(1), Game.state.floor_run.seed)
	Game.visit_room(layout.start)
	assert_true(Game.season_clock(600))
	Game.enter_safe_room(str(layout.safe_room_ids[layout.safe_rooms[0]]))
	assert_true(Game.season_clock(3600))                              # day 0: the daily programme
	Game.leave_safe_room()
	assert_true(Game.season_op({"t": "season", "v": 1, "op": "pause", "sec": 7200, "why": "user"}))
	var group: String = ""
	for e: EnemySpawn in layout.enemies:
		if e.encounter_id == DB.floor_def(1).timer_start_after:
			group = e.id
	var cmd: Dictionary = Harness.command_for(DB.floor_def(1).timer_start_after, Game.hero(),
		BattleSetup.Advantage.NORMAL)
	cmd["group"] = group
	(((cmd["rt"] as Dictionary)["groups"] as Array)[0] as Dictionary)["group"] = group
	assert_false(RtLive.fight(cmd, []).is_empty(), "the tutorial combat")
	assert_true(Game.season_clock(45), "its time, right after it")
	Game.timer_running = true
	for i in 12:
		Game._process(0.5)                                             # 6 s of exploration
	Game.timer_running = false
	assert_true(Game.season_clock(DAY))                               # the next air time
	assert_true(Game.logout("support"))
	assert_false(Game.season_clock(60), "asleep: the next session begins with \"away\" (ST1-G)")
	var live: String = StateHash.of(Game.state)
	var types: Array = RtLive.cmd_types(Game.run_log)
	for t: String in ["season", "floor", "hero", "room", "clock", "safe_room", "encounter", "sleep"]:
		assert_has(types, t)
	var g: Dictionary = Game.replay_log(Game.run_log)
	assert_eq([g["errors"], g["mismatch_at"], g["final_hash"]], [PackedStringArray(), -1, live], "Game.replay_log")
	var r: Dictionary = RunSim.replay(DB.data, Game.run_log)
	assert_eq([r["errors"], r["combat_mismatch_at"]], [PackedStringArray(), -1],
		"RunSim.replay accepts every entry and every combat checkpoint")
	var core: GameState = _core_replay(DB.data, Game.run_log)
	assert_eq(StateHash.of(core), r["final_hash"], "(the walk of RunSim.replay)")
	assert_eq(_core_part(core), _core_part(Game.state), "RunSim.replay: the season and the core state agree")
	var a: Dictionary = core.season.to_dict()
	var b: Dictionary = Game.state.season.to_dict()
	a.erase("seen_unix")
	b.erase("seen_unix")
	assert_eq(a, b, "the season block")


## The state without the Show's own part — viewers, followers, achievements, Marotten, the lootboxes of achievements and
## the Show's counters in the floor statistics (Show; RunSim has none of it, 05 §11.4) — and without the keys StateHash
## leaves out: what both verifiers agree on.
static func _core_part(st: GameState) -> Dictionary:
	var d: Dictionary = CanonicalJson.normalize(st.to_dict())
	for k: String in ["show", "pending_lootboxes", "play_time_sec", "slot"]:
		d.erase(k)
	if d.get("floor_run", null) is Dictionary:
		for k: String in ["achievements", "followers_gained", "viewers_peak"]:
			((d["floor_run"] as Dictionary).get("stats", {}) as Dictionary).erase(k)
	if d.get("season", null) is Dictionary:
		(d["season"] as Dictionary).erase("seen_unix")
	return d


## The final state of RunSim.replay for a log that starts at a new game (its walk: the clock to each entry, the entry,
## a state checkpoint ends a running combat first).
static func _core_replay(d: GameData, rl: RunLog) -> GameState:
	var h: Dictionary = rl.header
	var st: GameState = GameState.create_new(d, int(h.get("slot", 0)), GameState.DEFAULT_NAME, int(h.get("seed", 1)),
		StringName(str(h.get("difficulty", "prime"))))
	RunRules.rt_start(st, d)
	var sim: RunSim = RunSim.new(d, st, {}, RunSim.identity_of(h))
	var advance: Callable = func(k: int) -> void:
		sim.advance_to(k)
	var apply_cmd: Callable = func(i: int, c: Dictionary) -> int:
		sim.apply(c)
		return i + 1
	var on_checkpoint: Callable = func(_cp: int, k: int, _want: String) -> void:
		sim.settle()
		sim.advance_to(k)
	rl.walk(advance, apply_cmd, on_checkpoint)
	sim.settle()
	return st


# --- tampered clock commands ----------------------------------------------------------------------------------------

## The log `rl` (as a file) with its `nth_clock`-th clock entry ({"k", "c", "id"}) changed by `edit`.
static func _tampered(rl: RunLog, edit: Callable, nth_clock: int = 0) -> RunLog:
	var d: Dictionary = rl.to_dict()
	var n: int = 0
	for row: Variant in (d["cmds"] as Array):
		var c: Dictionary = (row as Dictionary)["c"]
		if str(c.get("t", "")) == "clock":
			if n == nth_clock:
				edit.call(row)
				break
			n += 1
	return RunLog.from_dict(d)


## A short calendar session recorded by RunSim (the start, clocks across day 0, a safe room, the stairs, the collapse of
## floor 1 below the candidate, the logout) — the log the tampering starts from.
static func _short_session(tempo: String = "calendar") -> RunSim:
	var d: GameData = Kit.data(6)
	var s: RunSim = Kit.sim(d, "ssn_basis", tempo, "net", 33)
	if tempo == "binge":
		s.apply({"t": "descend"})
		s.apply({"t": "floor", "floor": 2})
		s.step(600)
		return s
	s.apply({"t": "clock", "sec": 600})
	s.apply({"t": "safe_room", "id": _first_safe_room(d, s.state)})
	Kit.clock_to(s, DAY0 + 3600)
	s.apply({"t": "safe_room_exit"})
	s.apply({"t": "descend"})
	s.apply({"t": "floor", "floor": 2})
	s.step(600)
	Kit.clock_to(s, DAY0 + 2 * DAY + 60)
	s.apply({"t": "sleep", "tactic": "careful"})
	return s


func test_tampered_clock_commands() -> void:
	var s: RunSim = _short_session()
	var d: GameData = s.data
	var live: String = StateHash.of(s.state)
	assert_eq([s.rejected_cmds.size(), s.state.season.collapsed], [0, 1])
	assert_eq(RunSim.replay(d, s.run_log)["final_hash"], live, "untouched: the same season")
	var longer: RunLog = _tampered(s.run_log, func(row: Dictionary) -> void: (row["c"] as Dictionary)["sec"] = 660)
	var r: Dictionary = RunSim.replay(d, longer)
	assert_ne(r["final_hash"], live, "a changed duration: another season")
	assert_true(int(r["mismatch_at"]) >= 0 or r["final_hash"] != live, "found by the checkpoints or the end")
	DB.data = d
	assert_ne(Game.replay_log(longer)["final_hash"], live, "Game.replay_log too")
	DB.data = _data
	var jump: RunLog = _tampered(s.run_log, func(row: Dictionary) -> void:
		(row["c"] as Dictionary)["sec"] = SeasonClock.MAX_JUMP_SEC + 1)
	assert_has("; ".join(RunSim.replay(d, jump)["errors"]), "clock_jump", "more than seven days at once (V-17)")
	DB.data = d
	assert_has("; ".join(Game.replay_log(jump)["errors"]), "clock_jump", "Game.replay_log too")
	DB.data = _data
	var forged: Dictionary = s.run_log.to_dict()
	var start: Dictionary = ((forged["cmds"] as Array)[0] as Dictionary)["c"]
	(start["collapse_utc"] as Array)[0] = int((start["collapse_utc"] as Array)[0]) + 3600
	var errs: String = "; ".join(RunSim.replay(d, RunLog.from_dict(forged))["errors"])
	assert_has(errs, "schedule_mismatch", "a forged schedule (V-17: the dates follow from day 0)")
	assert_has(errs, "no_season", "and nothing of the season follows")
	var with_id: RunLog = _tampered(s.run_log, func(row: Dictionary) -> void: row["id"] = 99)
	var ri: Dictionary = RunSim.replay(d, with_id)
	assert_has("; ".join(ri["errors"]), "rejected", "the clock is an external input (id 0): the entry is dropped")
	assert_ne(ri["final_hash"], live)
	var zero: RunLog = _tampered(s.run_log, func(row: Dictionary) -> void: (row["c"] as Dictionary)["sec"] = 0)
	assert_has("; ".join(RunSim.replay(d, zero)["errors"]), "sec", "a clock of zero seconds (the clock only runs on)")
	var back: RunLog = _tampered(s.run_log, func(row: Dictionary) -> void: (row["c"] as Dictionary)["sec"] = -600)
	assert_has("; ".join(RunSim.replay(d, back)["errors"]), "sec", "a clock backwards")
	var asleep: Dictionary = s.run_log.to_dict()
	var last_k: int = int(((asleep["cmds"] as Array).back() as Dictionary)["k"])
	(asleep["cmds"] as Array).append({"k": last_k, "c": {"t": "clock", "sec": 60}, "id": 0})
	assert_has("; ".join(RunSim.replay(d, RunLog.from_dict(asleep))["errors"]), "asleep",
		"after the logout the absence is \"away\" (09 §9.1)")
	var b: RunSim = _short_session("binge")
	var binge: Dictionary = b.run_log.to_dict()
	(binge["cmds"] as Array).append({"k": b.tick(), "c": {"t": "clock", "sec": 60}, "id": 0})
	assert_has("; ".join(RunSim.replay(d, RunLog.from_dict(binge))["errors"]), "binge",
		"Am Stück has no calendar clock (its time is the exploration)")


# --- runs without a season (bit-identical) ------------------------------------------------------------------------

func test_runs_without_a_season_are_unchanged() -> void:
	var got: Dictionary = golden_values(real_data())
	for k: String in GOLDEN.keys():
		assert_eq(got.get(k, ""), GOLDEN[k], "golden " + k)
	assert_null(Game.state.season, "no season")
	assert_false(FileAccess.file_exists(Save.journal_path(1)), "no journal")


static func _sha(v: Variant) -> String:
	return CanonicalJson.stringify(v).sha256_text()


## The encounter command of the floor's group `group` for `enc` (rt_harness: its room and poses).
static func _enc(enc: String, group: String, hero: String) -> Dictionary:
	var cmd: Dictionary = Harness.command_for(enc, hero, BattleSetup.Advantage.NORMAL)
	cmd["group"] = group
	(((cmd["rt"] as Dictionary)["groups"] as Array)[0] as Dictionary)["group"] = group
	return cmd


## The golden runs without a season: {name: value} — a fresh state, a core campaign session (RunSim: floor 1 with the
## tutorial combat, strays with a bot's inputs, chests, safe room, stairs), its save, a live campaign session through
## Game (the tutorial combat, the clock, a safe room) and a live event run. The same code ran on main bc54fca (GOLDEN).
static func golden_values(data: GameData) -> Dictionary:
	var out: Dictionary = {}
	var fresh: GameState = GameState.create_new(data, 1, "Kai", 4242, &"prime")
	out["fresh_json"] = _sha(fresh.to_dict())
	out["fresh_hash"] = StateHash.of(fresh)
	var st: GameState = GameState.create_new(data, 0, "Kai", 4242, &"prime")
	RunRules.rt_start(st, data)
	var sim: RunSim = RunSim.new(data, st, {})
	var rl: RunLog = RunLog.new()
	rl.header = {"schema": 1, "seed": 4242, "slot": 0, "mode": "campaign", "difficulty": "prime",
		"sim_version": RunSim.SIM_VERSION, "event_id": "", "run_id": "run_golden", "player_id": "local",
		"window_id": "", "league": "", "combat_mode": String(RunRules.REALTIME), "rt_version": RunRules.RT_VERSION}
	sim.run_log = rl
	sim.apply({"t": "floor", "floor": 1})
	sim.apply({"t": "hero", "id": "kai"})
	var fdef: FloorDef = data.floor_def(1)
	var layout: FloorLayout = DungeonGenerator.generate(fdef, st.floor_run.seed)
	sim.apply({"t": "room", "cell": [layout.start.x, layout.start.y]})
	for g: EnemySpawn in layout.enemies:
		if g.encounter_id == fdef.timer_start_after:
			var cmd: Dictionary = _enc(g.encounter_id, g.id, "kai")
			var inputs: Array = RtLive.bot_inputs(sim, cmd)
			sim.apply(cmd)
			RtLive.core_play(sim, inputs)
			sim.settle()
	for c: ChestSpawn in layout.chests.slice(0, 3):
		sim.apply({"t": "chest", "id": c.id})
	var guard: int = 0
	while sim.tick() < 2400 and not sim.is_over() and guard < 1000:
		guard += 1
		for e: ExploreEvent in sim.step(30):
			if e.type == ExploreEvent.Type.STRAY_DUE and not sim.is_over():
				var cmd: Dictionary = _enc(str(e.data["encounter_id"]), str(e.data["group_id"]), "kai")
				var inputs: Array = RtLive.bot_inputs(sim, cmd)
				sim.apply(cmd)
				RtLive.core_play(sim, inputs)
				sim.settle()
	if not sim.is_over():
		sim.apply({"t": "rest"})
		var sr: String = str(layout.safe_room_ids.values()[0])
		sim.apply({"t": "safe_room", "id": sr})
		sim.apply({"t": "safe_room_exit"})
		sim.apply({"t": "room", "cell": [layout.stairs.x, layout.stairs.y]})
		sim.apply({"t": "descend"})
	out["core_hash"] = StateHash.of(st)
	out["core_log"] = rl.digest()
	var save: Dictionary = SaveCodec.encode(st, "golden")
	out["core_save"] = _sha(save)
	Game.new_game(0, "Kai", 4242)
	var g_layout: FloorLayout = DungeonGenerator.generate(DB.floor_def(1), Game.state.floor_run.seed)
	for g: EnemySpawn in g_layout.enemies:
		if g.encounter_id == DB.floor_def(1).timer_start_after:
			RtLive.fight(_enc(g.encounter_id, g.id, Game.hero()), [])
	Game.timer_running = true
	for i in 12:
		Game._process(0.5)
	Game.timer_running = false
	Game.rest_full_heal()
	Game.enter_safe_room(str(g_layout.safe_room_ids.values()[0]))
	Game.leave_safe_room()
	out["game_hash"] = StateHash.of(Game.state)
	var gd: Dictionary = Game.run_log.to_dict()
	out["game_log"] = _sha([gd.get("cmds", []), gd.get("checkpoints", [])])
	Game.start_event_run(EVENT_ID)
	var e_layout: FloorLayout = DungeonGenerator.generate(DB.floor_def(1), Game.state.floor_run.seed)
	for g: EnemySpawn in e_layout.enemies:
		if g.encounter_id == DB.floor_def(1).timer_start_after:
			RtLive.fight(_enc(g.encounter_id, g.id, Game.hero()), [])
	Game.timer_running = true
	for i in 6:
		Game._process(0.5)
	Game.timer_running = false
	out["event_hash"] = StateHash.of(Game.state)
	var ed: Dictionary = Game.run_log.to_dict()
	out["event_log"] = _sha([ed.get("cmds", []), ed.get("checkpoints", [])])
	return out
