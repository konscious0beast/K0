extends TestCase
## 08 §2.3, §10.3 (K1): the recorded persona command in both verifiers. A run started like the casting starts it
## (Game.new_game with a profile — TitleFlow.start_new_game) records floor → hero → persona and replays hash-equal in
## RunSim.replay and Game.replay_log, with a battle, a safe room and a hero switch, after save / load (the slot has no
## name, the anchor neither) and with Graf Mopsula leading; the name never changes a hash. "persona" in an event log →
## event_run, twice → already_set, after the run began → run_started; a log of an older kernel → old_version (never a
## mismatch).

const ROOT: String = "user://test_08_replay"
const SAVES: String = "user://test_08_replay/saves"
const EVENT_ID: String = "evt_offline_gleis9"
const OLD_LOG: String = "res://tests/fixtures/live/run_log_sim_v1.json"
const SEED: int = 9090
const RtLive := preload("res://tests/fixtures/rt_live/rt_live.gd")


func before_each() -> void:
	_rmrf(ROOT)
	Save.save_dir = SAVES
	Save.read_only = false


func after_each() -> void:
	if Game.combat != null:
		Game.end_combat()
	Game.state = null
	Game.run_log = null
	Game.sim = null
	Game.quest = null
	Game.persona = null
	Game.mode = &"campaign"
	Game.timer_running = false
	Game.in_battle = false
	Game.safe_room_clock = false
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


## Jana, Hebamme, Kochen & Backen, chaotisch · fürsorglich (bias: two rotating preferences).
static func _jana() -> PersonaProfile:
	var p: PersonaProfile = PersonaProfile.canon(DB.data)
	p.name = "Jana"
	p.form = "f"
	p.origin = "org_care"
	p.occupation = "occ_care_midwife"
	p.hobby = "hob_cooking"
	p.traits = PackedStringArray(["trt_chaotic", "trt_caring"])
	p.source = "offline"
	p.make_beats(DB.data, null)
	return p


static func _types() -> Array:
	var out: Array = []
	for c: Dictionary in Game.run_log.cmds():
		out.append(str((c["c"] as Dictionary)["t"]))
	return out


static func _safe_room() -> String:
	return str((DB.floor_def(1).layout.get("safe_rooms", [{}]) as Array)[0].get("id", ""))


## The tutorial combat of floor 1: real time, the autopilot plays the party (RtLive.autopilot_fight — the Game API of
## the CombatDirector, recorded like a live combat).
func _fight() -> void:
	var out: Dictionary = RtLive.autopilot_fight(DB.floor_def(1).timer_start_after, BattleSetup.Advantage.PREEMPTIVE,
		"")
	assert_false(out.is_empty(), "the tutorial combat")


## Both verifiers reproduce the live hash.
func _verify(what: String) -> void:
	var live: String = StateHash.of(Game.state)
	var a: Dictionary = Game.replay_log(Game.run_log, Game.sim.tick())
	assert_eq(a["errors"], PackedStringArray(), what + ": Game.replay_log")
	assert_eq([a["final_hash"], a["version"]], [live, ""], what + ": Game.replay_log ≡ live")
	var r: Dictionary = RunSim.replay(DB.data, Game.run_log)
	assert_eq(r["errors"], PackedStringArray(), what + ": RunSim.replay")
	assert_eq(int(r["mismatch_at"]), -1, what + ": RunSim.replay without a mismatch")


func test_a_cast_run_replays_hash_equal() -> void:
	var p: PersonaProfile = _jana()
	Game.new_game(1, p.name, SEED, &"prime", "kai", p)
	assert_eq(_types(), ["floor", "hero", "persona"], "floor → hero → persona (08 §2.3)")
	assert_eq(Game.run_log.cmds().back()["c"], {"t": "persona", "v": 2, "prof": "prf_first_aid",
		"recipe": "rcp_cooking_hobby", "bias": Array(PersonaRules.bias_for(DB.data, p.traits))},
		"ids only (09 ST0: v2 — Pflege → Erste Hilfe, Kochen → the cooking recipe; no origin or hobby id)")
	assert_eq(PersonaRules.bias(Game.state).size(), 2, "two rotating preferences")
	_verify("right after the casting")
	_fight()
	var sr: String = _safe_room()
	Game.enter_safe_room(sr)
	Game.leave_safe_room()
	_verify("after a battle and a safe room")
	var hashed: String = StateHash.of(Game.state)
	Game.state.player_name = "Mika"
	Game.state.member("kai").display_name = "Mika"
	assert_eq(StateHash.of(Game.state), hashed, "the name is display only (P-2)")
	Game.state.player_name = p.name
	Game.state.member("kai").display_name = p.name


func test_save_load_keeps_the_persona_out_of_the_replay() -> void:
	var p: PersonaProfile = _jana()
	Game.new_game(1, p.name, SEED, &"prime", "kai", p)
	_fight()
	var sr: String = _safe_room()
	Game.enter_safe_room(sr)
	assert_eq(Save.save_slot(1), OK, Save.last_error())
	Game.persona = null
	assert_eq(Save.load_slot(1), OK, Save.last_error())
	assert_not_null(Game.persona, "the persona file came back with the slot")
	assert_eq(Game.persona.to_dict()["name"], "Jana")
	assert_eq(Game.state.player_name, "Jana", "the display fields follow the persona file")
	assert_eq(PersonaRules.bias(Game.state), PersonaRules.bias_for(DB.data, p.traits), "the bias is game state")
	assert_false(JSON.stringify(Game.run_log.header).contains("Jana"), "the anchor and header carry no name")
	var persona_cmds: int = 0
	for c: Dictionary in Game.run_log.cmds():
		if str((c["c"] as Dictionary)["t"]) == "persona":
			persona_cmds += 1
	assert_eq(persona_cmds, 0, "a loaded game records no new persona command (the anchor carries the flag)")
	Game.leave_safe_room()
	_verify("after save / load")


func test_graf_mopsula_with_a_persona() -> void:
	var p: PersonaProfile = _jana()
	Game.new_game(2, p.name, SEED + 1, &"prime", "mopsula", p)
	assert_eq(_types(), ["floor", "hero", "persona"])
	assert_eq(str((Game.run_log.cmds()[1]["c"] as Dictionary)["id"]), "mopsula", "the Count leads")
	assert_eq(Game.state.member("kai").display_name, "Jana", "the candidate is the companion (party id kai)")
	_fight()
	var sr: String = _safe_room()
	Game.enter_safe_room(sr)
	Game.leave_safe_room()
	_verify("Graf Mopsula leading")


func test_refusals_in_logs() -> void:
	var p: PersonaProfile = _jana()
	Game.new_game(0, p.name, SEED, &"prime", "kai", p)
	assert_false(Game.apply_persona(PersonaRules.command_for(DB.data, null)),
		"already_set: refused live, nothing recorded")
	assert_eq(_types(), ["floor", "hero", "persona"])
	var twice: RunLog = _with_cmds(Game.run_log, [PersonaRules.command_for(DB.data, null)])
	assert_has("; ".join(Game.replay_log(twice)["errors"]), "already_set")
	assert_has("; ".join(RunSim.replay(DB.data, twice)["errors"]), "already_set")
	# a run without a persona that already began: a late persona command is refused (run_started)
	Game.new_game(0, "Kai", SEED)
	_fight()
	assert_true(HeroRules.run_started(Game.state), "the battle began the run")
	assert_false(Game.apply_persona(PersonaRules.command_for(DB.data, null)), "run_started")
	var late: RunLog = _with_cmds(Game.run_log, [PersonaRules.command_for(DB.data, null)])
	assert_has("; ".join(Game.replay_log(late)["errors"]), "run_started")
	assert_has("; ".join(RunSim.replay(DB.data, late)["errors"]), "run_started")
	# event runs never take a persona (08 §8)
	Game.start_event_run(EVENT_ID)
	assert_null(Game.persona, "an event run has no persona")
	assert_false(Game.apply_persona(PersonaRules.command_for(DB.data, null)), "event_run")
	var ev: RunLog = _with_cmds(Game.run_log, [PersonaRules.command_for(DB.data, null)])
	assert_has("; ".join(Game.replay_log(ev)["errors"]), "event_run")
	assert_has("; ".join(RunSim.replay(DB.data, ev)["errors"]), "event_run")


func test_an_older_kernel_is_old_version() -> void:
	var old: RunLog = RunLog.from_dict(JsonUtil.read_file(OLD_LOG))
	var r: Dictionary = RunSim.replay(DB.data, old)
	assert_eq([r["version"], r["mismatch_at"]], ["old_version", -1], "never a mismatch")
	assert_eq(Game.replay_log(old)["version"], "old_version")


## The log of `rl` plus `extra` commands at its last tick (player cmd ids after the log's).
static func _with_cmds(rl: RunLog, extra: Array) -> RunLog:
	var d: Dictionary = rl.to_dict()
	var cmds: Array = d["cmds"]
	var k: int = int((cmds.back() as Dictionary)["k"]) if not cmds.is_empty() else 0
	var next_id: int = 0
	for c: Variant in cmds:
		next_id = maxi(next_id, int((c as Dictionary)["id"]))
	for c: Variant in extra:
		next_id += 1
		cmds.append({"k": k, "id": next_id, "c": c})
	d["checkpoints"] = []
	return RunLog.from_dict(d)
