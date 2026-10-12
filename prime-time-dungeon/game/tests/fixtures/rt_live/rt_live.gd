extends RefCounted
## Test kit of R5a (07 §10.5, §10.6): real-time runs on the rt_min fixture data (RtKit) — live through the Game API
## exactly like the CombatDirector's tick loop, and RunSim-driven core runs; both start at an anchored state (the
## "from_save" header of Save.load_slot), so a replay starts from the same levels, items and hype. Private helper (no
## class_name): preload it. Callers swap DB.data to RtKit.data() and restore it afterwards (swap_data / restore_data).

const Bot := preload("res://tests/tools/rt_bot_player.gd")
const Harness := preload("res://tests/tools/rt_harness.gd")

static var _saved: GameData = null


static func swap_data() -> void:
	if _saved == null:
		_saved = DB.data
	DB.data = RtKit.data()


static func restore_data() -> void:
	if _saved != null:
		DB.data = _saved
		_saved = null


## A real-time GameState on fixture floor 1 (RtKit.state) with `hype` and the items.
static func state(level: int, hype: float, items: Dictionary = {}, hero: String = "kai") -> GameState:
	var st: GameState = RtKit.state(level, hero, items)
	st.show.hype = hype
	return st


## The anchored run-log header of `st` (Save._make_run_log + start_state / start_hash).
static func anchor(rl: RunLog, st: GameState) -> void:
	rl.header["start_state"] = PersonaPrivacy.scrub_state_dict(st.to_dict())
	rl.header["start_hash"] = StateHash.of(st)


## The running live campaign takes `st` like Save.load_slot (adopt, game_loaded, sync, anchor). DB.data = fixture.
static func adopt(st: GameState) -> void:
	var rl: RunLog = Save._make_run_log(st)
	Game.adopt_loaded_state(st, rl)
	Events.game_loaded.emit(0)
	Show.sync_from_state()
	anchor(rl, st)


## Plays the running Game.combat like CombatDirector._tick: per tick c the combat_hint entries of `cmds` with ct == c
## (Game.combat_hint: a card the previous tick showed), Game.combat_boundary(), every other entry with ct == c
## (Game.combat_submit), Game.combat_step(); `on_tick.call(c)` after each step (e.g. a gift arriving). At most
## `max_ticks` ticks; then Game.end_combat() (+ Game.on_game_over(&"defeat") like Router.game_over). Returns
## {"result": BattleResult, "events": Array[ActionEvent], "answers": {reason: n}, "ticks": int}.
static func play(cmds: Array, max_ticks: int, on_tick: Callable = Callable()) -> Dictionary:
	var events: Array[ActionEvent] = []
	var answers: Dictionary = {}
	var cb: Callable = func(e: RefCounted) -> void: events.append(e as ActionEvent)
	Events.combat_event.connect(cb)
	var i: int = 0
	var ticks: int = 0
	while Game.combat != null and not Game.combat.is_finished() and ticks < max_ticks:
		var c: int = Game.combat.tick()
		while i < cmds.size() and int((cmds[i] as Dictionary)["ct"]) < c:
			i += 1
		var j: int = i
		while j < cmds.size() and int((cmds[j] as Dictionary)["ct"]) == c:
			if str((cmds[j] as Dictionary)["t"]) == "combat_hint":
				Game.combat_hint(str((cmds[j] as Dictionary)["id"]))
			j += 1
		Game.combat_boundary()
		while i < cmds.size() and int((cmds[i] as Dictionary)["ct"]) == c:
			var cmd: Dictionary = cmds[i]
			if str(cmd["t"]) != "combat_hint":
				var a: String = Game.combat_submit(cmd.duplicate(true))
				answers[a] = int(answers.get(a, 0)) + 1
			i += 1
		Game.combat_step()
		ticks += 1
		if on_tick.is_valid():
			on_tick.call(c)
	var result: BattleResult = Game.combat.result if Game.combat != null else null
	Game.end_combat()
	Events.combat_event.disconnect(cb)
	if result != null and result.outcome == BattleResult.Outcome.DEFEAT:
		Game.on_game_over(&"defeat")
	return {"result": result, "events": events, "answers": answers, "ticks": ticks}


## Starts the live combat of the encounter command `cmd` (Game.make_rt_setup) and plays it (play).
static func fight(cmd: Dictionary, cmds: Array, max_ticks: int = 18000, on_tick: Callable = Callable()) -> Dictionary:
	if Game.make_rt_setup(cmd) == null:
		return {}
	return play(cmds, max_ticks, on_tick)


## The encounter command of `enc_id` on the real floor-1 data (the balance harness's rt block: its cell, poses and
## lead) for group `group` and the running hero — what the exploration records for a combat (R5b part 2b: every
## campaign combat is a real-time one). `opener` "bark" (06 A × C) only with a PREEMPTIVE advantage, like the
## exploration records it.
static func encounter(enc_id: String, adv: int, group: String = "harness", opener: String = "") -> Dictionary:
	var cmd: Dictionary = Harness.command_for(enc_id, Game.hero() if Game.state != null else "kai", adv)
	cmd["group"] = group
	(((cmd["rt"] as Dictionary)["groups"] as Array)[0] as Dictionary)["group"] = group
	if opener != "" and adv == BattleSetup.Advantage.PREEMPTIVE:
		cmd["opener"] = opener
	return cmd


## The live real-time combat of `enc_id` (encounter) on the running game, the controlled unit on autopilot from tick 0
## (the sim's own AI plays the party, 07 §5.7) — the real-time successor of the CTB auto battle the campaign tests
## played through BattleState. Returns play()'s dictionary; {} when no combat starts.
static func autopilot_fight(enc_id: String, adv: int, group: String = "harness", max_ticks: int = 18000,
		on_tick: Callable = Callable(), opener: String = "") -> Dictionary:
	if Game.make_rt_setup(encounter(enc_id, adv, group, opener)) == null:
		return {}
	return play([RtCommand.autopilot(0, Game.combat.controlled_id(), true)], max_ticks, on_tick)


## A RunSim-driven core run from the anchored `st` (fixture data) that records into a fresh run log whose header names
## a real-time run.
static func core_sim(st: GameState) -> RunSim:
	var rl: RunLog = RunLog.new()
	rl.header = {"schema": 1, "seed": st.seed, "slot": 0, "mode": "campaign", "difficulty": "prime",
		"sim_version": RunSim.SIM_VERSION, "event_id": "", "run_id": "run_r5a_test", "player_id": "local",
		"window_id": "", "league": "", "from_save": true, "combat_mode": "realtime", "rt_version": 1}
	anchor(rl, st)
	var sim: RunSim = RunSim.new(RtKit.data(), st, {})
	sim.run_log = rl
	return sim


## Feeds `cmds` (combat entries with ct, in order) to the core sim: each is applied as it comes (RunSim advances the
## combat lazily). Returns the reasons of refused entries.
static func core_play(sim: RunSim, cmds: Array) -> Array:
	var reasons: Array = []
	for c: Variant in cmds:
		var before: int = sim.rejected_cmds.size()
		sim.apply((c as Dictionary).duplicate(true))
		if sim.rejected_cmds.size() > before:
			reasons.append(str(sim.rejected_cmds.back()["reason"]))
	return reasons


## The inputs a person-like bot (rt_bot_player, `profile`) gives in the real-time combat the core sim `sim` starts
## for the encounter command `cmd`: played first on a twin combat (a copy of the state, its next "battle" seed, the
## run's rules — what RunSim._apply_encounter_rt builds), its accepted commands in order. Fed to `sim` after `cmd`
## (core_play), they replay that combat exactly. [] when no combat would start.
static func bot_inputs(sim: RunSim, cmd: Dictionary, profile: String = "typical", bot_seed: int = 7,
		max_ticks: int = 18000) -> Array:
	var twin: GameState = GameState.from_dict(sim.state.to_dict())
	var setup: RtSetup = BattleBridge.make_rt_setup_rules(twin, sim.data, cmd, RunRules.next_seed(twin, "battle"),
		sim.rules)
	if setup == null:
		return []
	var rt: RtSim = RtSim.new(setup, sim.data)
	var out: Array = []
	var bot: RefCounted = Bot.new(rt, profile, bot_seed)
	bot.set("submitter", func(c: Dictionary) -> String:
		var why: String = rt.submit(c)
		if why == "":
			out.append(c.duplicate(true))
		return why)
	rt.start()
	while not rt.is_finished() and rt.tick() < max_ticks:
		bot.call("act")
		bot.call("observe", rt.step())
	return out


## The run log as JSON and back (what a stored replay is).
static func round_trip(rl: RunLog) -> RunLog:
	return RunLog.from_dict(JSON.parse_string(JSON.stringify(rl.to_dict())))


## The "t" of every run-log command, in order.
static func cmd_types(rl: RunLog) -> Array:
	var out: Array = []
	for row: Dictionary in rl.cmds():
		out.append(str((row["c"] as Dictionary).get("t", "")))
	return out
