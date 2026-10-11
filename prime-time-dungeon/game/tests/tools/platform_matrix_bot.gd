extends RefCounted
## Helper of tests/tools/platform_matrix.gd (no class_name; loaded with load()): the core bot runs of the platform
## matrix (05 Kap. 2 S0 gate, 07 §12.2 / 08 §10.2 Nr. 17 before a SIM_VERSION bump). Each run is a campaign Floor 1
## driven through RunSim alone (no autoloads, no scene tree — the verifier path): start room, tutorial battle (auto
## commands), chests, the clock with stray fights, rest, lootbox, a safe room, stairs, descend. The run seed varies,
## the decisions are fixed. Per run: final hash, checkpoint count, SHA-256 over all checkpoint hashes (tick order) and
## the result of RunSim.replay (mismatch_at, errors). A platform leg passes when every run replays and its digest (over
## all runs) equals the reference leg (Linux x86-64 headless).

const TICKS: int = 3300                    # ≈ 110 s floor clock: strays spawn at 90 s
const SEED_BASE: int = 4100


## The runs for seeds SEED_BASE + 1 … SEED_BASE + n → {"runs": [ {...} ], "digest": String, "ok": bool}.
func run_all(n: int) -> Dictionary:
	var data: GameData = GameData.new()
	if not data.load_dir("res://data"):
		return {"runs": [], "digest": "", "ok": false, "error": "; ".join(data.errors)}
	var runs: Array = []
	var ok: bool = true
	var lines: PackedStringArray = []
	for i in n:
		var r: Dictionary = run_one(data, SEED_BASE + 1 + i)
		ok = ok and bool(r["replay_ok"])
		runs.append(r)
		lines.append("%d|%s|%d|%s" % [int(r["seed"]), str(r["final_hash"]), int(r["checkpoints"]), str(r["cp_digest"])])
	return {"runs": runs, "digest": "\n".join(lines).sha256_text(), "ok": ok}


func run_one(data: GameData, seed: int) -> Dictionary:
	var st: GameState = GameState.create_new(data, 0, "Kai", seed, &"prime")
	var sim: RunSim = RunSim.new(data, st, {})
	var rl: RunLog = RunLog.new()
	rl.header = {"schema": 1, "seed": seed, "slot": 0, "difficulty": "prime", "mode": "campaign",
		"sim_hz": RunSim.TICKS_PER_SEC, "sim_version": RunSim.SIM_VERSION, "event_id": "",
		"run_id": "run_matrix_%d" % seed, "player_id": "local", "window_id": "", "league": ""}
	sim.run_log = rl
	sim.apply({"t": "floor", "floor": 1})
	var fdef: FloorDef = data.floor_def(1)
	var layout: FloorLayout = DungeonGenerator.generate(fdef, st.floor_run.seed)
	sim.apply({"t": "room", "cell": [layout.start.x, layout.start.y]})
	var tutorial_group: String = ""
	for g: EnemySpawn in layout.enemies:
		if g.encounter_id == fdef.timer_start_after:
			tutorial_group = g.id
	sim.apply({"t": "encounter", "enc": fdef.timer_start_after, "adv": BattleSetup.Advantage.PREEMPTIVE,
		"group": tutorial_group})
	_fight(sim)
	for c: ChestSpawn in layout.chests.slice(0, 3):
		sim.apply({"t": "chest", "id": c.id})
	var guard: int = 0
	while sim.tick() < TICKS and not sim.is_over() and guard < 1000:
		guard += 1
		for e: ExploreEvent in sim.step(30):
			if e.type == ExploreEvent.Type.STRAY_DUE and not sim.is_over():
				sim.apply({"t": "encounter", "enc": e.data["encounter_id"],
					"adv": BattleSetup.Advantage.PREEMPTIVE, "group": e.data["group_id"]})
				_fight(sim)
	if not sim.is_over():
		sim.apply({"t": "rest"})
		if not st.pending_lootboxes.is_empty():
			sim.apply({"t": "lootbox", "box": st.pending_lootboxes[0]})
		sim.apply({"t": "safe_room", "id": str(layout.safe_room_ids.values()[0])})
		sim.apply({"t": "safe_room_exit"})
		sim.apply({"t": "room", "cell": [layout.stairs.x, layout.stairs.y]})
		sim.apply({"t": "descend"})
	var final_hash: String = sim.close("floor_completed" if not sim.is_over() else "defeat")
	var cps: PackedStringArray = []
	for cp: Dictionary in rl.checkpoints():
		cps.append("%d:%s" % [int(cp["k"]), str(cp["h"])])
	var res: Dictionary = RunSim.replay(data, RunLog.from_dict(JSON.parse_string(JSON.stringify(rl.to_dict()))))
	var errors: PackedStringArray = res["errors"]
	return {"seed": seed, "final_hash": final_hash, "ticks": sim.tick(), "cmds": rl.size(),
		"checkpoints": cps.size(), "cp_digest": "\n".join(cps).sha256_text(),
		"replay_ok": int(res["mismatch_at"]) == -1 and errors.is_empty() and str(res["final_hash"]) == final_hash,
		"replay_errors": Array(errors)}


func _fight(sim: RunSim) -> void:
	var guard: int = 0
	while sim.battle != null and guard < 600:
		guard += 1
		var cmd: BattleCommand = sim.battle.choose_ai_command()
		sim.apply({"t": "battle", "cmd": cmd.to_dict(), "auto": true})
