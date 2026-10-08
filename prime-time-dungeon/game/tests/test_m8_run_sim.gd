extends TestCase
## RunSim without autoloads (02_TECH §7.1, 05 §11.4, §11.5): step(n) counts the timer down in ticks, warnings once,
## expiry stops the clock, hype decay / pacifist counter / stray spawners in ticks, step(1) × n ≡ step(n), the clock
## waits for the timer start and pauses in battles, run rules in flags["live"], recording + checkpoints, core effects
## of the recorded commands. Uses the real data (GameData) and core classes only.

const TPS: int = 30


func _sim(seed: int = 99, rules: Dictionary = {}, p_log: RunLog = null) -> RunSim:
	var data: GameData = real_data()
	var st: GameState = GameState.create_new(data, 0, "Kai", seed, &"prime")
	var sim: RunSim = RunSim.new(data, st, rules)
	sim.run_log = p_log
	sim.apply({"t": "floor", "floor": 1})
	return sim


func _started(seed: int = 99, p_log: RunLog = null) -> RunSim:
	var sim: RunSim = _sim(seed, {}, p_log)
	sim.state.floor_run.timer_started = true
	return sim


func _of(events: Array[ExploreEvent], t: ExploreEvent.Type) -> Array[ExploreEvent]:
	var out: Array[ExploreEvent] = []
	for e: ExploreEvent in events:
		if e.type == t:
			out.append(e)
	return out


func _layout(sim: RunSim) -> FloorLayout:
	return DungeonGenerator.generate(real_data().floor_def(sim.state.floor_run.index), sim.state.floor_run.seed)


## Auto battle (AutoPolicy / EnemyAI choose, the commands go through apply like recorded ones).
func _fight(sim: RunSim) -> void:
	var guard: int = 0
	while sim.battle != null and guard < 600:
		guard += 1
		var cmd: BattleCommand = sim.battle.choose_ai_command()
		sim.apply({"t": "battle", "cmd": cmd.to_dict(), "auto": true})
	assert_null(sim.battle, "battle finished")


func test_clock_waits_for_the_timer_start() -> void:
	var sim: RunSim = _sim()
	var left: int = sim.state.floor_run.time_left_ticks
	assert_false(sim.state.floor_run.timer_started, "floor 1: countdown after the tutorial battle (GDD B2)")
	assert_eq(sim.step(100), [], "no events")
	assert_eq(sim.tick(), 0, "the clock does not advance")
	assert_eq(sim.state.floor_run.time_left_ticks, left)
	sim.state.floor_run.timer_started = true
	sim.step(1)
	assert_eq(sim.tick(), 1)


func test_timer_counts_down_in_ticks() -> void:
	var sim: RunSim = _started()
	var fr: FloorRun = sim.state.floor_run
	assert_eq(fr.time_left_ticks, 1200 * TPS, "20:00 = 36 000 ticks")
	var ev: Array[ExploreEvent] = sim.step(45)
	assert_eq(fr.time_left_ticks, 1200 * TPS - 45)
	assert_eq(fr.stats["time_used_ticks"], 45)
	assert_eq(sim.tick(), 45)
	var secs: Array = []
	for e: ExploreEvent in _of(ev, ExploreEvent.Type.TIMER_SECOND):
		secs.append([e.tick, e.data["seconds"]])
	assert_eq(secs, [[1, 1199], [31, 1198]], "TIMER_SECOND when the whole second changes")
	var ticks: Array[ExploreEvent] = _of(ev, ExploreEvent.Type.EXPLORE_TICK)
	assert_eq(ticks.size(), 1, "every 30 ticks")
	assert_eq([ticks[0].tick, ticks[0].data], [30, {"seconds_since_battle": 1}])


func test_warnings_once_and_expiry_stops_the_clock() -> void:
	var sim: RunSim = _started()
	var fr: FloorRun = sim.state.floor_run
	fr.time_left_ticks = 600 * TPS + 1
	var ev: Array[ExploreEvent] = sim.step(2)
	var w: Array[ExploreEvent] = _of(ev, ExploreEvent.Type.TIMER_WARNING)
	assert_eq(w.size(), 1)
	assert_eq(w[0].data, {"seconds": 600})
	assert_eq(w[0].tick, 1, "fires on the crossing tick")
	assert_eq(fr.warned, PackedInt32Array([600]))
	fr.time_left_ticks = 600 * TPS + 1
	assert_eq(_of(sim.step(2), ExploreEvent.Type.TIMER_WARNING), [], "each warning once (floor_run.warned)")
	fr.time_left_ticks = 3
	var before: int = sim.tick()
	var end: Array[ExploreEvent] = sim.step(10)
	assert_eq(end.back().type, ExploreEvent.Type.TIMER_EXPIRED)
	assert_eq(end.back().tick, before + 3)
	assert_eq(sim.tick(), before + 3, "stops at 0")
	assert_true(sim.is_over())
	assert_false(sim.is_clock_running())
	assert_eq(sim.step(5), [])
	assert_eq(sim.tick(), before + 3)
	assert_eq(fr.time_left_ticks, 0)


func test_hype_decay_in_ticks() -> void:
	var sim: RunSim = _started()
	var show: ShowState = sim.state.show
	assert_eq(show.hype, 30.0, "floor start")
	assert_eq(_of(sim.step(149), ExploreEvent.Type.HYPE), [])
	var h: Array[ExploreEvent] = _of(sim.step(1), ExploreEvent.Type.HYPE)
	assert_eq(h.size(), 1, "−1 per 150 ticks (5 s)")
	assert_eq(h[0].data, {"hype": 29, "delta": -1})
	assert_eq(show.hype, 29.0)
	assert_eq(sim.state.floor_run.decay_ticks, 0)
	show.hype = 16.0
	assert_eq(_of(sim.step(150), ExploreEvent.Type.HYPE).size(), 1)
	assert_eq(show.hype, 15.0)
	assert_eq(_of(sim.step(300), ExploreEvent.Type.HYPE), [], "never below 15 in exploration")
	assert_eq(show.hype, 15.0)


func test_pacifist_counter() -> void:
	var sim: RunSim = _started()
	var ev: Array[ExploreEvent] = _of(sim.step(300), ExploreEvent.Type.EXPLORE_TICK)
	assert_eq(ev.size(), 10)
	assert_eq(ev.back().data, {"seconds_since_battle": 10})
	assert_eq(sim.state.show.stats["explore_seconds_since_battle"], 10)
	sim.apply({"t": "encounter", "enc": "enc_f1_a2", "adv": 1, "group": ""})
	assert_eq(sim.state.show.stats["explore_seconds_since_battle"], 0, "a battle resets the pacifist counter")


func test_step_one_by_one_equals_step_n() -> void:
	var a: RunSim = _started(4242)
	var b: RunSim = _started(4242)
	var ea: Array = []
	for i in 3000:
		for e: ExploreEvent in a.step(1):
			ea.append(e.to_dict())
	var eb: Array = []
	for e: ExploreEvent in b.step(3000):
		eb.append(e.to_dict())
	assert_eq(a.tick(), b.tick())
	assert_eq(ea, eb, "identical event streams")
	assert_eq(StateHash.of(a.state), StateHash.of(b.state), "step(1) × n ≡ step(n)")
	assert_gt(ea.size(), 100, "timer seconds, explore ticks, hype, strays")


func test_stray_spawners() -> void:
	var sim: RunSim = _started(777)
	var fr: FloorRun = sim.state.floor_run
	var spawners: Array[Dictionary] = _layout(sim).spawners
	assert_gt(spawners.size(), 0, "floor 1 has stray spawners")
	var interval: int = int(spawners[0]["interval_sec"]) * TPS
	for sp: Dictionary in spawners:
		assert_eq(int(sp["interval_sec"]) * TPS, interval, "same interval for the test")
	assert_eq(_of(sim.step(interval - 1), ExploreEvent.Type.STRAY_DUE), [])
	var due: Array[ExploreEvent] = _of(sim.step(1), ExploreEvent.Type.STRAY_DUE)
	assert_eq(due.size(), spawners.size(), "one stray per zone")
	for i in due.size():
		var pool: PackedStringArray = JsonUtil.to_str_array(spawners[i]["pool"])
		var rng: RandomNumberGenerator = SeedUtil.make_rng(SeedUtil.derive(fr.seed, "stray", i))
		assert_eq(due[i].data, {"zone": spawners[i]["zone"], "group_id": "f1_s%d" % i,
			"encounter_id": pool[rng.randi_range(0, pool.size() - 1)]}, "02_TECH §7.1 rule")
		assert_eq(fr.strays["f1_s%d" % i], {"zone": spawners[i]["zone"], "enc": due[i].data["encounter_id"]})
	assert_eq(fr.stray_counter, spawners.size())
	assert_eq(_of(sim.step(interval * 2), ExploreEvent.Type.STRAY_DUE), [], "no spawn while the zone's stray lives")
	fr.strays.erase("f1_s0")
	var again: Array[ExploreEvent] = _of(sim.step(interval), ExploreEvent.Type.STRAY_DUE)
	assert_eq(again.size(), 1, "the zone of the defeated stray spawns again")
	assert_eq(again[0].data["group_id"], "f1_s%d" % spawners.size())
	assert_eq(again[0].data["zone"], spawners[0]["zone"])


func test_battle_pauses_the_clock_and_feeds_the_quest() -> void:
	var sim: RunSim = _sim(2024)
	sim.quest = QuestTracker.from_def({"type": "pacifist", "params": {"max_battles": 0, "then": {"type": "reach_stairs",
		"params": {"floor": 1}}}})
	var counter: int = sim.state.rng_counter
	var enc: String = real_data().floor_def(1).timer_start_after
	var ev: Array[ExploreEvent] = sim.apply({"t": "encounter", "enc": enc, "adv": 0, "group": "f1_g0"})
	assert_eq(_of(ev, ExploreEvent.Type.ENCOUNTER)[0].data, {"group_id": "f1_g0", "encounter_id": enc, "advantage": 0})
	assert_eq(sim.state.rng_counter, counter + 2, "\"battle\" + \"show\" seed draws like the live §5.7 flow")
	assert_not_null(sim.battle)
	assert_gt(sim.last_action_events.size(), 0, "BATTLE_START …")
	sim.state.floor_run.timer_started = true
	assert_false(sim.is_clock_running(), "no exploration time during a battle")
	assert_eq(sim.step(10), [])
	assert_true(sim.quest.failed(), "battle_started fed to the quest (pacifist with 0 battles)")
	sim.state.floor_run.timer_started = false
	_fight(sim)
	assert_true(sim.state.floor_run.timer_started, "victory over the tutorial starts the countdown (BattleBridge)")
	assert_true(sim.state.floor_run.defeated_groups.has("f1_g0"))
	assert_true(sim.is_clock_running())
	sim.step(1)
	assert_eq(sim.tick(), 1)


func test_invalid_commands_change_nothing() -> void:
	var rl: RunLog = RunLog.new()
	var sim: RunSim = _sim(5, {}, rl)
	var h: String = StateHash.of(sim.state)
	assert_eq(sim.apply({"t": "warp"}), [])
	assert_eq(sim.apply({"t": "floor", "floor": 0}), [])
	assert_eq(sim.apply({"t": "chest"}), [])
	assert_eq(StateHash.of(sim.state), h)
	assert_eq(rl.size(), 1, "only the valid floor command was recorded")
	sim.apply({"t": "battle", "cmd": {"kind": "attack", "actor": "p0", "skill": "", "item": "", "targets": ["e0"]},
		"auto": true})
	assert_eq(StateHash.of(sim.state), h, "battle command without a battle: no effect")


func test_event_rules_are_stored_in_the_run() -> void:
	var data: GameData = real_data()
	var st: GameState = GameState.create_new(data, 0, "Kai", 1, &"prime")
	RunSim.new(data, st, {"leagues": ["pur"], "gifts": {"enabled": false}, "timer_mode": "explore_only"})
	assert_eq(st.flags["live"], {"league": "pur", "gift_rules": {"enabled": false}})
	var st2: GameState = GameState.create_new(data, 0, "Kai", 1, &"prime")
	RunSim.new(data, st2, {})
	assert_false(st2.flags.has("live"), "campaign: no run rules")
	var st3: GameState = GameState.create_new(data, 0, "Kai", 1, &"prime")
	RunSim.new(data, st3, {"leagues": ["show", "pur"], "gifts": {"enabled": true}})
	assert_eq(st3.flags["live"], {"gift_rules": {"enabled": true}}, "league chosen per run → not fixed by the event")
	assert_eq(GiftPolicy.check(st.flags["live"], Gift.make_dev("gold", "", 100), {}), "league_pur",
		"the run's league reaches the gift policy without event rules")


func test_recording_and_checkpoints() -> void:
	var rl: RunLog = RunLog.new()
	var sim: RunSim = _sim(31, {}, rl)
	sim.state.floor_run.timer_started = true
	sim.step(10)
	sim.apply({"t": "rest"})
	sim.apply({"t": "gift", "gift": Gift.make_dev("gold", "", 100)})
	sim.step(640)
	sim.apply({"t": "room", "cell": [3, 6]})
	var cmds: Array[Dictionary] = rl.cmds()
	var meta: Array = []
	for c: Dictionary in cmds:
		meta.append([c["k"], c["id"], c["c"]["t"]])
	assert_eq(meta, [[0, 1, "floor"], [10, 2, "rest"], [10, 0, "gift"], [650, 3, "room"]], "k = tick, gift id 0")
	var ks: Array = []
	for cp: Dictionary in rl.checkpoints():
		ks.append(cp["k"])
	assert_eq(ks, [300, 600], "every 300 ticks, taken when the clock leaves the tick")
	var h: String = sim.close("test", {"score": 7})
	assert_eq(rl.result, {"cause": "test", "final_hash": h, "ticks": 650, "score": 7})
	assert_eq(rl.checkpoints().back(), {"k": 650, "h": h})
	assert_eq(rl.validate(), PackedStringArray())


func test_core_effects_of_commands() -> void:
	var data: GameData = real_data()
	var sim: RunSim = _sim(8)
	var st: GameState = sim.state
	var layout: FloorLayout = _layout(sim)
	var ev: Array[ExploreEvent] = sim.apply({"t": "room", "cell": [layout.stairs.x, layout.stairs.y]})
	assert_true(st.floor_run.stairs_found)
	assert_eq(ev[0].data, {"cell": [layout.stairs.x, layout.stairs.y], "kind": "stairs", "first_visit": true})
	assert_false(sim.apply({"t": "room", "cell": [layout.stairs.x, layout.stairs.y]})[0].data["first_visit"])
	var wood: ChestSpawn = null
	var locked: ChestSpawn = null
	for c: ChestSpawn in layout.chests:
		if c.type == "wood" and wood == null:
			wood = c
		if c.type == "locked" and locked == null:
			locked = c
	var credits: int = st.inventory.credits
	var opened: Array[ExploreEvent] = sim.apply({"t": "chest", "id": wood.id})
	assert_eq(opened[0].type, ExploreEvent.Type.CHEST_OPENED)
	assert_gt(st.inventory.credits, credits, "wood chest: 20..40 credits + an entry")
	assert_eq(sim.apply({"t": "chest", "id": wood.id}), [], "already open")
	if locked != null:
		assert_eq(sim.apply({"t": "chest", "id": locked.id}), [], "locked without itm_key_master")
	sim.apply({"t": "gate", "key": "3,5,S"})
	sim.apply({"t": "gate", "key": "3,5,S"})
	assert_eq(st.floor_run.opened_gates, PackedStringArray(["3,5,S"]), "once")
	sim.apply({"t": "flag", "key": "intro_seen", "value": true})
	assert_eq(st.flags["intro_seen"], true)
	var sr: String = str(layout.safe_room_ids.values()[0])
	st.party[0].hp = 1
	sim.apply({"t": "safe_room", "id": sr})
	assert_eq([st.floor_run.location, st.floor_run.safe_room_visits], [StringName(sr), 1])
	assert_gt(st.party[0].hp, 1, "safe room heals")
	sim.apply({"t": "safe_room_exit"})
	assert_eq(st.floor_run.location, &"start")
	var gold_before: int = st.inventory.credits
	sim.apply({"t": "gift", "gift": Gift.make_dev("gold", "", 100)})
	assert_eq(st.inventory.credits, gold_before + 100, "gift outside battle → GiftApplier")
	assert_eq((st.flags["live"]["gift_ids"] as Array).size(), 1)
	var left: int = st.floor_run.time_left_ticks
	sim.apply({"t": "difficulty", "to": "vorabend"})
	assert_eq(st.floor_run.time_left_ticks, roundi(left * 1.5), "Vorabendprogramm: × 1.5")
	st.floor_run.timer_started = true
	var done: Array[ExploreEvent] = sim.apply({"t": "descend"})
	assert_eq(done[0].data, {"floor": 1})
	assert_false(sim.is_clock_running(), "the floor is over")
	assert_eq(sim.step(5), [])
	sim.apply({"t": "floor", "floor": 2})
	if data.floor_def(2) != null:
		assert_eq(st.floor_run.index, 2)


func test_quest_detail_events_from_the_core() -> void:
	var sim: RunSim = _sim(61)
	sim.quest = QuestTracker.from_def({"type": "reach_stairs", "params": {"floor": 1}})
	var layout: FloorLayout = _layout(sim)
	assert_gt(layout.zones.size(), 1, "floor 1 has zones A–D")
	var per_zone: Dictionary = {}
	for c: Vector2i in layout.cells.keys():
		var rc: RoomCell = layout.cell_at(c)
		if rc.zone != "" and not per_zone.has(rc.zone):
			per_zone[rc.zone] = c
	var zones: Array = per_zone.keys()
	zones.sort()
	for i in 2:
		var cell: Vector2i = per_zone[zones[i]]
		sim.apply({"t": "room", "cell": [cell.x, cell.y]})
	assert_eq(sim.quest.progress_ppm(), 900000 * 2 / layout.zones.size(), "explored zones × 0.9 (05 §1.3)")
	var boss: RunSim = _sim(62)
	var fdef: FloorDef = real_data().floor_def(1)
	boss.quest = QuestTracker.from_def({"type": "defeat_boss", "params": {"boss_id":
		real_data().encounter(fdef.quarter_boss).enemies[0]}})
	boss.apply({"t": "encounter", "enc": fdef.quarter_boss, "adv": 0, "group": "f1_qb"})
	var guard: int = 0
	while boss.battle != null and boss.quest.progress_ppm() == 0 and guard < 40:
		guard += 1
		boss.apply({"t": "battle", "cmd": boss.battle.choose_ai_command().to_dict(), "auto": true})
	assert_gt(boss.quest.progress_ppm(), 0, "boss damage → 1 − HP share")
