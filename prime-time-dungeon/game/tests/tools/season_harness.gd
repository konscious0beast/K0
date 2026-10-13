extends RefCounted
## Staffel-Harness in the core (09 §11.6, ST1-I; decisions in 09 Kap. 11.3 "Stand ST1-I"): a whole season — RunSim,
## the verifier's engine, with the season rules (SeasonRules, LevelBand, EnemyLevels, CastSim and the SleepResolver) —
## played by a core bot as recorded commands, the way the full-run bot plays it in the world (scenes/boot/fullrun.gd,
## tools/fullrun.sh --season): the goals of tests/tools/season_planner.gd (the same rules), walking = run ticks along
## the BFS path (the time model TIME, calibrated against the full-run bot), groups and bosses = real combats on RtSim in
## the group's room (the person: RtBotPlayer `typical`, like the full-run bot; or the autopilot) — the groups of the
## rooms on the way engage like in the exploration —, chests, floor events (their fights too), gates, safe rooms
## (Mopsula scenes, lootboxes, the Recall, the talent rows, the class abilities on the bar, vending, gear), the stairs.
## Calendar: the sessions of a play profile (tests/tools/season_profiles.gd), the season clock 1:1 with the play time
## of the session ("clock" per minute, a combat's time right after it), the logout ("sleep" in a safe room within
## LOGOUT_DIST rooms, else in the corridor, Vorsichtig), the absence ("away"; over seven days the login's "clamp" — 09
## V-17, like Game.season_login_answer). Am Stück the floors' countdowns. Pure and deterministic per (data, seed,
## options): no scene, no autoload, no wall clock. run() → the report with the same per-floor records as the full-run
## bot's "FULLRUN: season" (and the Pensum marks of season_planner.pensum); with "log" the run log (closed with its
## final checkpoint), which RunSim.replay reproduces bit for bit (test_09_harness).
##
## Formats: 6 (Basis, floors 1–6). Formats 12 / 18 need the floors 7–18 of ST1-C2 — refused with FORMAT_REFUSAL (09
## Kap. 11.3 decision I-2).

const Bot := preload("res://tests/tools/rt_bot_player.gd")
const Profiles := preload("res://tests/tools/season_profiles.gd")
const Planner := preload("res://tests/tools/season_planner.gd")

const DAY: int = 86400
const DAY0_UTC: int = 1791921600           # day 0 of the harness's seasons: air time 20:00 UTC (= the full-run bot's)
const START_UTC: int = DAY0_UTC - 5400     # Am Stück: started 90 min before the first air time
const AIR: String = "20:00"
const PLAYABLE_FORMATS: Array[int] = [6]
const FORMAT_REFUSAL: String = "Format %d: die Etagen 7–%d kommen mit ST1-C2 — bis dahin misst der Harness Format 6 " \
	+ "(Basis-Staffel, --format=6)"
const TEMPOS: PackedStringArray = ["calendar", "binge"]
const STRATEGIES: PackedStringArray = ["thorough", "typical", "rush", "auto"]
const FIGHTERS: PackedStringArray = ["bot", "autopilot"]
const LOGOUT_DIST: int = 4                 # session end: a safe room at most this many rooms away → sleep there
const CLOCK_STEP: float = 60.0             # 09 §9.1: one "clock" per minute of play
const MAX_COMBAT_TICKS: int = 18000
const MAX_STEPS: int = 20000               # goals of one season (a guard)
const STUCK: int = 20                      # the same goal this often without progress → an error, the run ends
const HEAL_BELOW: float = 0.5              # heal items on a member below 50 % HP (the full-run bot's rule)
const SAFE_BELOW: float = 0.45             # party HP below this → back to a safe room (≤ SAFE_DIST rooms)
const SAFE_DIST: int = 6
const BANDAGES_WANTED: int = 3
const EQUIP_SLOTS: PackedStringArray = ["weapon", "armor", "accessory"]
const HEAL_ITEMS: PackedStringArray = ["itm_brutzel_burger", "itm_bandage"]
## The Recall of the bots (the full-run bot's FullRunSeasonUi.RECALL): a tank and a healer.
const RECALL: Dictionary = {"kai": ["spc_original", "cls_kai_wrecker"],
	"mopsula": ["spc_original", "cls_mop_physician"]}
## Encounter poses [x, z, yaw] in the room (cm; tests/tools/rt_harness.gd): the leader, the controlled figure, the
## partner — a boss: the party stands where its 5-m trigger leaves it.
const POSES: Dictionary = {"regular": [[0, -150, 128], [0, 250, 0], [-120, 340, 0]],
	"boss": [[0, 0, 64], [-420, 0, 192], [-470, 120, 192]]}

## The time model (game seconds; 09 Kap. 11.3 decision I-5). Exploration (the countdown runs), calibrated against the
## full-run bot in the world (tools/fullrun.sh --season, seed 4242, Am Stück thorough fast: 3.15 s per cell change and
## 4.15 s per group, least squares over floors 1–5, ± 10 % per floor): "cell" a cell change door to door, "engage" up
## to a group and the strike, "chest", "gate" the interaction. Human pace (02_TECH §11.4.1, the full-run bot's HUMAN_*
## model: "look" per new room, "decide" per goal, "door" per cell change, "sneak" the last metres to a group — against
## its --pace=human run, seed 4242 Am Stück typical, the exploration minutes of floors 1–4 agree within 12 %, the M.O.D.
## lines it reads included). Screens (the countdown stands): "event" the event dialog, "safe" a safe-room visit's door
## and menus, + "lootbox", "pick", "buy", "scene" each, "recall" per member of the Recall (species and class cards, the
## jury's verdict), "combat" the results panel, "intro" a boss's intro, "stairs" the stairs dialog and the Etagen-Bilanz
## — a person's reading and clicking; the bot of the fast pace clicks through them in FAST_SCREENS_PM ‰ of that (the
## full-run bot: ≈ 45 s per floor).
const TIME: Dictionary = {"cell": 3.2, "engage": 4.0, "chest": 0.5, "gate": 1.0,
	"look": 8.0, "decide": 3.0, "door": 1.0, "sneak": 0.0,
	"event": 6.0, "safe": 12.0, "lootbox": 4.0, "pick": 3.0, "buy": 2.0, "scene": 15.0, "recall": 30.0, "combat": 4.0,
	"intro": 8.0, "stairs": 8.0}
const SCREENS: PackedStringArray = ["event", "safe", "lootbox", "pick", "buy", "scene", "recall", "combat", "intro",
	"stairs"]
const FAST_SCREENS_PM: int = 250

var data: GameData = null
var o: Dictionary = {}
var t: Dictionary = {}
var rs: RunSim = null
var seed: int = 0
var format: int = 6
var plan: Array[Dictionary] = []
var session: int = 0
var session_play: float = 0.0
var session_wall: int = 0
var play: float = 0.0
var here: Vector2i = Vector2i.ZERO
var layout: FloorLayout = null
var tried: Dictionary = {}
var recs: Array[Dictionary] = []
var logouts: Array[Dictionary] = []
var logins: Array[Dictionary] = []
var talents: PackedStringArray = []
var fights: int = 0
var errors: PackedStringArray = []
var stop: String = ""
var credits_won: int = 0
var credits_spent: int = 0

var _rec: Dictionary = {}
var _layout_key: String = ""
var _clock_acc: float = 0.0
var _tick_acc: float = 0.0
var _logout_due: bool = false
var _shut: bool = false
var _done: bool = false
var _descended: bool = false
var _heal_trips: int = 0
var _boss_tries: Dictionary = {}           # "qb" | "fb" → attempts this floor and session
var _last_sig: String = ""
var _same_sig: int = 0
var _final_hash: String = ""


## One season: `seed` and the options {"def" (ssn_basis), "tempo" (calendar), "mode" (net), "profile" (typical;
## calendar), "strategy" (auto in the calendar, thorough Am Stück), "pace" (human), "fighter" (bot), "log" (false),
## "time" ({} — overrides of TIME), "floors" / "sessions" (0; > 0: stop after leaving floor n / after n logouts),
## "plan" (the sessions instead of the profile's, season_profiles.gd format), "debug" (false: a line per goal and
## fight), "probe" (a Callable(harness, encounter command) before every boss fight: balance probes)}. The report (see
## report()); {"error": …} for a refused format.
static func run(p_data: GameData, p_seed: int, opts: Dictionary = {}) -> Dictionary:
	var h: RefCounted = (load("res://tests/tools/season_harness.gd") as GDScript).new()
	return h.call("play_season", p_data, p_seed, opts)


func play_season(p_data: GameData, p_seed: int, opts: Dictionary) -> Dictionary:
	data = p_data
	seed = p_seed
	o = {"def": "ssn_basis", "tempo": "calendar", "mode": "net", "profile": "typical", "pace": "human",
		"fighter": "bot", "log": false, "time": {}}
	o.merge(opts, true)
	if not o.has("strategy"):
		o["strategy"] = "auto" if str(o["tempo"]) == "calendar" else "thorough"
	t = TIME.duplicate()
	if str(o["pace"]) != "human":
		for k: String in SCREENS:
			t[k] = float(t[k]) * float(FAST_SCREENS_PM) / 1000.0
	t.merge(o["time"] as Dictionary, true)
	var def: SeasonDef = data.season_def(str(o["def"])) if data.has_id("seasons", str(o["def"])) else null
	if def == null:
		return {"error": "unknown season template %s" % str(o["def"])}
	format = def.format
	if not PLAYABLE_FORMATS.has(format):
		return {"error": FORMAT_REFUSAL % [format, format]}
	if str(o["tempo"]) == "calendar":
		plan = Profiles.sessions(str(o["profile"]), seed, format)
		if o.has("plan"):                       # the tests' own sessions
			plan.assign(o["plan"])
		if plan.is_empty():
			return {"error": "unknown profile %s" % str(o["profile"])}
	_start(def)
	var steps: int = 0
	while not _done and steps < MAX_STEPS:
		steps += 1
		_step()
	if not _done:
		errors.append("no end after %d steps" % MAX_STEPS)
	if rs.run_log != null:
		_final_hash = rs.close(stop if stop != "" else "steps")   # the final checkpoint: RunSim.replay ends here too
	return report()


# --- the start --------------------------------------------------------------------------------------------------------

func _start(def: SeasonDef) -> void:
	var start_utc: int = START_UTC if plan.is_empty() else DAY0_UTC + int(plan[0]["start"])
	session_wall = start_utc
	var st: GameState = GameState.create_new(data, 0, GameState.DEFAULT_NAME, seed, &"prime")
	RunRules.rt_start(st, data)
	rs = RunSim.new(data, st, {}, {})
	if bool(o["log"]):
		var rl: RunLog = RunLog.new()
		rl.header = {"schema": 1, "seed": seed, "slot": 0, "mode": "campaign", "difficulty": "prime",
			"sim_version": RunSim.SIM_VERSION, "event_id": "", "run_id": "run_st1i_harness", "player_id": "local",
			"window_id": "", "league": "", "combat_mode": "realtime", "rt_version": RunRules.RT_VERSION}
		rs.run_log = rl
	var day0: int = SeasonClock.day0(start_utc, SeasonClock.air_seconds(AIR), 0)
	_apply({"t": "season", "v": 1, "op": "start", "def": def.id, "format": format, "tempo": str(o["tempo"]),
		"mode": str(o["mode"]), "number": 1, "day0_utc": day0, "collapse_utc": SeasonClock.schedule(day0, format),
		"cast": CastSim.start_block(def, def.min_humans), "utc": start_utc})
	_apply({"t": "floor", "floor": 1})
	_apply({"t": "hero", "id": "kai"})
	if rs.state.season == null:
		errors.append("the season did not start: %s" % JSON.stringify(rs.rejected_cmds))
		_done = true
		return
	_layout_now()
	here = layout.start
	_open_floor()


# --- one step ---------------------------------------------------------------------------------------------------------

func _step() -> void:
	if _over():
		_finish()
		return
	if _limit_reached():
		return
	_track()
	_pensum()
	if _session_over():
		_logout_due = true
	if RunRules.in_safe_room(rs.state):            # the medics, a rescue or a login put the party into a safe room
		_safe_room(str(rs.state.floor_run.location))
		return
	var g: Dictionary = _goal()
	if bool(o.get("debug", false)):
		print("HARNESS-DEBUG: f%d %s @%s %s %s (%s%s) play %.0f" % [rs.state.floor_run.index, str(g["kind"]),
			str(here), str(g["id"]), str(g["cell"]), str(g["why"]), " before " + str(g["before"]) if g.has("before")
			else "", play])
	if not _progress(g):
		return
	if str(o["pace"]) == "human" and not ["wait", "logout"].has(str(g["kind"])):
		_spend(float(t["decide"]), true)
		if _moved():
			return
	_do(g)


## The smoke runs of the tests: option "floors" stops after leaving floor n, "sessions" after n logouts (the report's
## "stop" says which; the season goes on in the state).
func _limit_reached() -> bool:
	var why: String = ""
	if int(o.get("floors", 0)) > 0 and rs.state.floor_run.index > int(o["floors"]):
		why = "floors"
	elif int(o.get("sessions", 0)) > 0 and session >= int(o["sessions"]):
		why = "sessions"
	if why == "":
		return false
	if not _rec.is_empty():
		_close_floor(("stairs" if _descended else "rescue") if _rec["fr"] != rs.state.floor_run else "stop")
	stop = why
	_done = true
	return true


## The same goal STUCK times without any progress (rooms, groups, chests, events, gates, combats, credits, probes) is a
## bug of the bot: an error, the run ends. Waiting and the logout are progress of the clock.
func _progress(g: Dictionary) -> bool:
	if ["wait", "logout"].has(str(g["kind"])):
		_same_sig = 0
		return true
	var fr: FloorRun = rs.state.floor_run
	var sig: String = "%s|%s|%s|%s|%d|%d|%d|%d|%d|%d|%d|%d|%d" % [str(g["kind"]), str(g["id"]), str(g["cell"]),
		str(here), fr.index, fr.visited.size(), fr.defeated_groups.size(), fr.opened_chests.size(),
		fr.completed_events.size(), fr.opened_gates.size(), fights, rs.state.inventory.credits, tried.size()]
	if sig != _last_sig:
		_last_sig = sig
		_same_sig = 0
		return true
	_same_sig += 1
	if _same_sig < STUCK:
		return true
	errors.append("floor %d: stuck at %s %s (%s) in %s" % [fr.index, str(g["kind"]), str(g["id"]), str(g["why"]),
		str(here)])
	_finish()
	return false


## The next goal (the full-run bot's _season_objective): the logout of a finished session (a safe room within
## LOGOUT_DIST, else here), the tutorial, a heal trip, then season_planner.gd goal (a boss below its HP / MP marks → a
## safe room first).
func _goal() -> Dictionary:
	var fr: FloorRun = rs.state.floor_run
	var dist: Dictionary = layout.distances(here, fr.opened_gates, false, Planner.blocks(rs.state, data, layout,
		tried, Planner.NO_CELL))
	_heal_items()
	_equip_best()
	if _logout_due:
		var sr: Dictionary = _nearest_safe(dist)
		if not sr.is_empty() and int(dist.get(sr["cell"], 99)) <= LOGOUT_DIST:
			sr["why"] = "logout"
			return sr
		return {"kind": "logout", "id": "", "cell": here, "why": "corridor"}
	if fr.index == 1 and fr.defeated_groups.is_empty() and layout.enemy_by_id("f1_g0") != null:
		return {"kind": "group", "id": "f1_g0", "cell": layout.enemy_by_id("f1_g0").cell, "why": "tutorial"}
	if _party_ratio("hp") < SAFE_BELOW and _heal_trips < 2:
		var heal: Dictionary = _nearest_safe(dist)
		if not heal.is_empty() and int(dist.get(heal["cell"], 99)) <= SAFE_DIST:
			_heal_trips += 1
			heal["why"] = "heal"
			return heal
	var g: Dictionary = Planner.goal(rs.state, data, layout, here, str(o["strategy"]), tried,
		{"qb": _tries("qb"), "fb": _tries("fb"), "fb_floor": (_rec.get("fb", []) as Array).size()})
	if str(g["kind"]) == "boss" and bool(g.get("heal", false)) and _heal_trips < 2:
		var sr2: Dictionary = _nearest_safe(dist)
		if not sr2.is_empty():
			_heal_trips += 1
			sr2["why"] = "heal before " + str(g["id"])
			return sr2
	return g


func _do(g: Dictionary) -> void:
	var kind: String = str(g["kind"])
	match kind:
		"wait":
			_wait(str(g["why"]))
			return
		"logout":
			_logout_login()
			return
	if kind != "safe" and kind != "boss":
		_heal_trips = 0
	if not _walk(g["cell"], kind == "boss", str(g["id"]) if kind == "group" or kind == "boss" else ""):
		return
	match kind:
		"group":
			var e: EnemySpawn = layout.enemy_by_id(str(g["id"]))
			_engage()
			if not _moved() and e != null and not rs.state.floor_run.defeated_groups.has(e.id):
				_fight(e.id, e.encounter_id, e.cell, false)
		"boss":
			var b: EnemySpawn = layout.enemy_by_id(str(g["id"]))
			if b != null:
				_spend(float(t["intro"]), false)
				_fight(b.id, b.encounter_id, b.cell, true)
		"chest":
			_spend(float(t["chest"]), true)
			_apply({"t": "chest", "id": str(g["id"])})
		"event":
			_event(str(g["id"]), str(g["why"]))
		"gate":
			_spend(float(t["gate"]), true)
			if str(g["why"]) == Planner.TRY_LOCKED:
				tried[str(g["id"])] = true
			else:
				_apply({"t": "gate", "key": str(g["id"])})
		"safe":
			_safe_room(str(g["id"]))
		"stairs":
			_stairs()
		"visit":
			pass


# --- walking and time -------------------------------------------------------------------------------------------------

## Walks door by door to `cell` (shortest path over open doors; living boss rooms only as the goal): per cell change
## TIME.cell (+ door at human pace) as exploration time, the "room" command on a first visit (+ look), the groups of
## the rooms on the way (_aggro; `goal_group` is the goal's own). false when the floor changed meanwhile (a collapse,
## the countdown), the season ended or a group on the way won.
func _walk(cell: Vector2i, boss: bool, goal_group: String = "") -> bool:
	var fr: FloorRun = rs.state.floor_run
	var goal: Vector2i = cell if boss else Planner.NO_CELL
	var p: Array[Vector2i] = Planner.path(layout, here, cell, fr.opened_gates, Planner.blocks(rs.state, data, layout,
		tried, goal))
	if p.is_empty():                                 # no way round the avoided rooms: through them
		p = Planner.path(layout, here, cell, fr.opened_gates, Planner.boss_blocks(layout, fr, goal))
	if p.is_empty():
		errors.append("floor %d: no path from %s to %s" % [fr.index, str(here), str(cell)])
		tried["unreachable:%s" % str(cell)] = true
		_rec_add("unreachable", 1)
		return false
	var human: bool = str(o["pace"]) == "human"
	_enter_room()
	for i in range(1, p.size()):
		_spend(float(t["cell"]) * 0.5 + (float(t["door"]) if human else 0.0), true)
		if _moved():
			return false
		here = p[i]
		_rec_add("cells", 1)
		if _enter_room() and human:
			_spend(float(t["look"]), true)
		if not _aggro(here, goal_group):
			return false
		_spend(float(t["cell"]) * 0.5, true)
		if _moved():
			return false
	return true


## Up to a group and the strike (human pace: the last metres sneaking, fullrun.gd HUMAN_SNEAK_DIST).
func _engage() -> void:
	_spend(float(t["engage"]) + (float(t["sneak"]) if str(o["pace"]) == "human" else 0.0), true)


## The groups standing in a room the party walks into notice it and fight (exploration.gd _rt_triggers: sight 10 m,
## hearing 4 m, contact or 4 s of chase in the room — the full-run bot walks through their rooms like a person): every
## living regular group of `at` but `goal_group` (the goal's own fight). false when a fight was lost (the medics moved
## the party) or the floor changed.
func _aggro(at: Vector2i, goal_group: String) -> bool:
	var fr: FloorRun = rs.state.floor_run
	for e: EnemySpawn in layout.enemies:
		if e.cell != at or e.is_boss or e.is_stray() or e.id == goal_group or fr.defeated_groups.has(e.id):
			continue
		_rec_add("aggro", 1)
		_engage()
		if _moved():
			return false
		_fight(e.id, e.encounter_id, e.cell, false)
		if _moved() or not rs.state.floor_run.defeated_groups.has(e.id):
			return false
	return true


## The first visit of the room the party stands in ("room", like Game.visit_room on every room change). true = first.
func _enter_room() -> bool:
	if rs.state.floor_run.visited.has(here) or layout.cell_at(here) == null:
		return false
	_apply({"t": "room", "cell": [here.x, here.y]})
	return true


## `sec` seconds of the person's play: exploration ticks (RunSim.step — the countdown Am Stück, the floor time, the
## regeneration) when `explore`, the season clock in the calendar ("clock" per CLOCK_STEP, never in a combat).
func _spend(sec: float, explore: bool) -> void:
	play += sec
	session_play += sec
	_rec_addf("play", sec)
	if explore and not RunRules.in_safe_room(rs.state):
		_tick_acc += sec * RunSim.TICKS_PER_SEC
		var n: int = floori(_tick_acc)
		_tick_acc -= n
		if n > 0:
			_events(rs.step(n))
	_clock(sec)


## The calendar's clock: CLOCK_STEP seconds of play each (a combat's time comes right after it, V-17).
func _clock(sec: float) -> void:
	if rs.state.season.tempo != "calendar" or rs.state.season.asleep or _over():
		return
	_clock_acc += sec
	if _clock_acc < CLOCK_STEP:
		return
	var n: int = floori(_clock_acc)
	_clock_acc -= n
	_apply({"t": "clock", "sec": n})


## The floor changed (a collapse, the countdown) or the season ended since the goal began.
func _moved() -> bool:
	return _over() or _rec.is_empty() or _rec["fr"] != rs.state.floor_run


func _over() -> bool:
	return rs.state.season == null or rs.state.season.result != "" or _done


## Nothing to do now: with sessions the session ends; Am Stück the party waits for the countdown (a minute at a time).
func _wait(why: String) -> void:
	if rs.state.season.tempo == "calendar" and not plan.is_empty():
		_logout_due = true
		_rec_note("wait", why)
		return
	_spend(60.0, true)


# --- combat -----------------------------------------------------------------------------------------------------------

## A combat in the group's room (07 §10.1 encounter command; BattleBridge builds the set from the real layout): the
## person is the RtBotPlayer `typical` on its own stream (SeedUtil.derive(seed, "rt_bot", n), like the full-run bot),
## or the autopilot. Records the combat in the floor's record. `group` "" = an event's combat.
func _fight(group: String, enc_id: String, cell: Vector2i, boss: bool) -> void:
	var poses: Array = POSES["boss" if boss else "regular"]
	var groups: Array = []
	if group != "":
		groups.append({"group": group, "enc": enc_id, "lead": (poses[0] as Array).duplicate(), "state": "IDLE"})
	var cmd: Dictionary = {"t": "encounter", "enc": enc_id, "adv": 0, "group": group, "rt": {"v": 1,
		"cell": [cell.x, cell.y], "ctl": "p0", "party": [{"u": "p0", "p": (poses[1] as Array).duplicate()},
		{"u": "p1", "p": (poses[2] as Array).duplicate()}], "groups": groups, "presets": {"p1": _preset("mopsula")},
		"auto": true, "retarget": true, "open": {}, "diff": "prime"}}
	if boss and o.get("probe") is Callable:            # a balance probe sees the boss fight's command first
		(o["probe"] as Callable).call(self, cmd)
	var credits0: int = rs.state.inventory.credits
	_apply(cmd)
	var sim: RtSim = rs.combat
	if sim == null:
		errors.append("floor %d: no combat for %s %s" % [rs.state.floor_run.index, enc_id, group])
		return
	if str(o["fighter"]) == "bot":
		var bot: RefCounted = Bot.new(sim, "typical", SeedUtil.derive(seed, "rt_bot", fights))
		bot.set("submitter", _combat_submit)
		while not sim.is_finished() and sim.tick() < MAX_COMBAT_TICKS:
			bot.call("act")
			var ev: Array[ActionEvent] = sim.step()
			bot.call("observe", ev)
	else:
		_apply(RtCommand.autopilot(0, sim.controlled_id(), true))
	fights += 1
	var levels: Array[int] = _levels()
	rs.settle()
	_note_credits(credits0)
	_check_cap()
	var res: BattleResult = sim.result
	var sec: float = float(sim.tick()) / float(RtSim.TICKS_PER_SEC)
	_spend(sec, false)
	_spend(float(t["combat"]), false)
	if res == null:
		return
	_rec_add("combats", 1)
	_rec_addf("combat_sec", sec)
	if bool(o.get("debug", false)):
		print("HARNESS-FIGHT: f%d %s %s: %s, %.1f s, level %s" % [rs.state.floor_run.index, enc_id, group,
			res.outcome_name(), sec, str(levels)])
	var won: bool = res.outcome == BattleResult.Outcome.VICTORY
	if not won:
		_rec_add("defeats", 1)
		if not boss and group != "":
			tried["lost:" + group] = int(tried.get("lost:" + group, 0)) + 1
			(_rec["lost"] as Array).append(enc_id)
	if boss:
		var def: FloorDef = data.floor_def(int(_rec["floor"]))
		var kind: String = "qb" if def != null and enc_id == def.quarter_boss else "fb"
		_boss_tries[kind] = int(_boss_tries.get(kind, 0)) + 1
		(_rec[kind] as Array).append({"outcome": res.outcome_name(), "sec": snappedf(sec, 0.1), "level": levels,
			"session": session})
	if not won and RunRules.in_safe_room(rs.state):     # the medics (Mit Netz): into the safe room entered last
		here = _safe_cell(str(rs.state.floor_run.location))
	elif not won:
		here = layout.start


## 09 §8.2 "Deckel": no level above the band end of the floor the party stands on (floor 3: 13) — an error otherwise.
func _check_cap() -> void:
	var top: int = LevelBand.cap(rs.state, data)
	for m: PartyMember in rs.state.party:
		if m.level > top:
			errors.append("floor %d: %s on level %d above the cap %d" % [rs.state.floor_run.index, m.id, m.level, top])


## The bot's commands into the running combat (RunSim records them at the encounter's tick): "" = accepted.
func _combat_submit(c: Dictionary) -> String:
	var n: int = rs.rejected_cmds.size()
	rs.apply(c)
	return "" if rs.rejected_cmds.size() == n else str(rs.rejected_cmds[n].get("reason", "refused"))


## The AI partner's tactic and switches (ExplorationScene._rt_preset_of).
func _preset(member_id: String) -> Dictionary:
	var m: PartyMember = rs.state.member(member_id)
	var preset: String = m.rt_preset if m != null else ""
	if preset == "" and data.has_id("party", member_id):
		preset = str(data.party_member(member_id).rt.get("default_preset", ""))
	if not RtVocab.RT_PRESETS.has(preset):
		preset = "support" if member_id == "mopsula" else "attack"
	var tog: Dictionary = RtVocab.RT_TOGGLE_DEFAULTS.duplicate()
	if m != null:
		for k: Variant in m.rt_toggles.keys():
			if RtVocab.RT_TOGGLES.has(str(k)):
				tog[str(k)] = bool(m.rt_toggles[k])
	return {"preset": preset, "tog": tog}


# --- interactions -----------------------------------------------------------------------------------------------------

## A floor event: its outcome first (FloorEvent.resolve with RunRules' stream — pure), then the command; a fight of the
## outcome (wheel, lever) follows like in the world.
func _event(event_id: String, choice: String) -> void:
	_spend(float(t["event"]), false)              # the event dialog stops the countdown (GDD §2.8)
	if _moved():
		return
	var fr: FloorRun = rs.state.floor_run
	var ev: EventSpawn = layout.event_by_id(event_id)
	if ev == null:
		return
	if FloorEvent.PASSIVE_CHOICES.has(choice):
		tried[event_id] = true
		return
	var k: int = layout.events.find(ev)
	var rng: RandomNumberGenerator = SeedUtil.make_rng(SeedUtil.derive(fr.seed, "event", k * 16 +
		int(fr.event_uses.get(event_id, 0))))
	var outcome: Dictionary = FloorEvent.resolve(ev, choice, rs.state, data, rng)
	var credits0: int = rs.state.inventory.credits
	_apply({"t": "event", "id": event_id, "choice": choice})
	_note_credits(credits0)
	var enc: String = str(outcome.get("encounter_id", ""))
	if enc != "" and data.has_id("encounters", enc):
		_fight("", enc, ev.cell, false)


## The stairs: "Noch nicht" once per floor (nothing changes), then down — closed (calendar) → wait.
func _stairs() -> void:
	_spend(float(t["stairs"]) * 0.5, true)
	if _moved():
		return
	if SeasonRules.stairs_refusal(rs.state, data) != "":
		_shut = true
		_rec_note("stairs", "closed")
		return
	_rec["leave_play"] = play
	_descended = true
	var fr: FloorRun = rs.state.floor_run
	_apply({"t": "descend"})                      # nothing between "descend" and "floor" (a clock would be refused)
	if rs.state.season.result != "":
		return
	_apply({"t": "floor", "floor": fr.index + 1})
	_spend(float(t["stairs"]) * 0.5, false)       # the Etagen-Bilanz (still the old floor's record until _track)


# --- safe rooms -------------------------------------------------------------------------------------------------------

## A safe-room visit (the full-run bot's _season_safe_room): the door, the Recall (floor >= 3), the Mopsula scenes,
## lootboxes, the talent rows, the class abilities, gear and vending; a finished session sleeps here; then out.
func _safe_room(sid: String) -> void:
	var fr: FloorRun = rs.state.floor_run
	if not layout.safe_room_info.has(sid):
		errors.append("floor %d: unknown safe room %s" % [fr.index, sid])
		_apply({"t": "safe_room_exit"})
		return
	here = _safe_cell(sid)
	_spend(float(t["safe"]), false)
	var first: bool = not fr.visited_safe_rooms.has(sid)
	_apply({"t": "safe_room", "id": sid})
	_rec_add("safe_visits", 1)
	_recall()                                     # the Recall's screen opens first and holds the room (floor >= 3)
	_scenes({"safe_room_id": sid, "first_visit": first, "safe_room_visits": fr.safe_room_visits,
		"kai_level": rs.state.member("kai").level})
	for box: String in rs.state.pending_lootboxes.duplicate():
		var c0: int = rs.state.inventory.credits
		_apply({"t": "lootbox", "box": box})
		_note_credits(c0)
		_spend(float(t["lootbox"]), false)
	for m: PartyMember in rs.state.party:
		for row: int in TalentTree.open_rows(rs.state, data, m):
			var row_t: Array[TalentDef] = TalentTree.row_talents(data, m, row)
			if row_t.is_empty():
				continue
			_apply({"t": "talent", "v": Command.TALENT_ROW_VERSION, "member": m.id, "row": row, "id": row_t[0].id})
			talents.append("%s@R%d:%s" % [m.id, row, row_t[0].id])
			_spend(float(t["pick"]), false)
	_loadout()
	_equip_best()
	_shop(sid)
	_equip_best()
	if _logout_due:
		_logout_login()
		return
	_apply({"t": "safe_room_exit"})


## The Recall (06 §3.5; the full-run bot's FullRunSeasonUi.recall): every member with a first choice (Casting.mode
## "first"; the screen opens by itself in the first safe room of floor >= 3), the controlled figure first
## (Casting.open_members) — what the screen's "Bestätigen" records: "casting", then in a season the signature on its
## slot ("loadout" of Casting.signature_loadout). TIME.recall per member (its cards, the jury, the end page).
func _recall() -> void:
	for mid: String in Casting.open_members(rs.state, data):
		if Casting.mode(rs.state, data, mid) != "first":
			continue
		var pick: Array = RECALL[mid]
		_apply({"t": "casting", "member": mid, "species": str(pick[0]), "class": str(pick[1])})
		var lo: Dictionary = Casting.signature_loadout(rs.state, data, mid)
		if not lo.is_empty():
			_apply(lo)
		_rec_note("recall", "%s %s/%s" % [mid, str(pick[0]), str(pick[1])])
		_spend(float(t["recall"]), false)


## The Mopsula scenes of the visit (RunRules.scene_allowed, data order, each once per visit; up to four).
func _scenes(ctx: Dictionary) -> void:
	var played: PackedStringArray = []
	for _i in 4:
		var next: SceneDef = null
		for sc: SceneDef in data.all_scenes():
			if not played.has(sc.id) and RunRules.scene_allowed(rs.state, sc, ctx):
				next = sc
				break
		if next == null:
			return
		played.append(next.id)
		_apply({"t": "scene", "id": next.id})
		_spend(float(t["scene"]), false)


## The class abilities on the bar (FullRunSeasonUi.loadout): per slot the learned class variant of the highest level.
func _loadout() -> void:
	for m: PartyMember in rs.state.party:
		var best: Dictionary = {}
		for r: Dictionary in AbilityBook.rows_of(rs.state, data, m):
			if str(r["source"]) == AbilityBook.SOURCE_PARTY or str(r["kind"]) != "variant" \
					or not AbilityBook.is_learned(m, r):
				continue
			var slot: String = str(int(r["slot"]))
			if not best.has(slot) or int(r["level"]) > int((best[slot] as Array)[0]):
				best[slot] = [int(r["level"]), str(r["skill"])]
		var bar: Dictionary = m.rt_loadout.duplicate()
		for slot: Variant in best.keys():
			bar[str(slot)] = str((best[slot] as Array)[1])
		if bar != m.rt_loadout:
			_apply(RunRules.loadout_cmd(m.id, bar, m.rt_preset, m.rt_toggles))
			_spend(float(t["pick"]), false)


## Vending (the full-run bot's shopping_list): affordable equipment upgrades, then bandages up to three.
func _shop(sid: String) -> void:
	var def: FloorDef = data.floor_def(rs.state.floor_run.index)
	var credits: int = rs.state.inventory.credits
	for item_id: String in Shop.stock(def, sid):
		var it: ItemDef = data.item(item_id)
		if it.type == "consumable" or it.price <= 0 or it.price > credits or _upgrade_for(it) == "":
			continue
		var c0: int = rs.state.inventory.credits
		_apply({"t": "buy", "item": item_id, "qty": 1, "safe_room": sid})
		_note_credits(c0)
		credits = rs.state.inventory.credits
		_spend(float(t["buy"]), false)
	if Shop.stock(def, sid).has("itm_bandage"):
		var price: int = maxi(1, Shop.price_of(data, "itm_bandage"))
		var want: int = mini(BANDAGES_WANTED - rs.state.inventory.count("itm_bandage"),
			rs.state.inventory.credits / price)
		if want > 0:
			var c1: int = rs.state.inventory.credits
			_apply({"t": "buy", "item": "itm_bandage", "qty": want, "safe_room": sid})
			_note_credits(c1)
			_spend(float(t["buy"]), false)


func _upgrade_for(def: ItemDef) -> String:
	if not EQUIP_SLOTS.has(def.type):
		return ""
	for m: PartyMember in rs.state.party:
		if not def.equip_by.is_empty() and not def.equip_by.has(m.id):
			continue
		if _item_score(def.id) > _item_score(str(m.equipment.get(def.type, ""))):
			return m.id
	return ""


## The best owned item per member and slot (the full-run bot's equip_best).
func _equip_best() -> void:
	for m: PartyMember in rs.state.party:
		for slot: String in EQUIP_SLOTS:
			var best: String = ""
			var best_score: int = _item_score(str(m.equipment.get(slot, "")))
			for item_id: String in rs.state.inventory.ids_of_type(data, slot):
				var def: ItemDef = data.item(item_id) if data.has_id("items", item_id) else null
				if def == null or def.type != slot or (not def.equip_by.is_empty() and not def.equip_by.has(m.id)):
					continue
				if _item_score(item_id) > best_score:
					best_score = _item_score(item_id)
					best = item_id
			if best != "":
				_apply({"t": "equip", "member": m.id, "slot": slot, "item": best})


func _item_score(item_id: String) -> int:
	if item_id == "" or not data.has_id("items", item_id):
		return -1
	var s: int = 1
	for v: Variant in data.item(item_id).stats.values():
		s += int(v)
	return s


## Field heal items on a member below HEAL_BELOW (the full-run bot's _use_heal_items).
func _heal_items() -> void:
	for m: PartyMember in rs.state.party:
		var sb: StatBlock = Progression.total_stats(m, data)
		var max_hp: int = sb.values[StatBlock.Stat.HP]
		for item_id: String in HEAL_ITEMS:
			var guard: int = 0
			while m.hp < max_hp * HEAL_BELOW and rs.state.inventory.has(item_id) and guard < 6:
				guard += 1
				_apply({"t": "use_item", "item": item_id, "member": m.id})
		var max_mp: int = sb.values[StatBlock.Stat.MP]
		if m.mp < max_mp * 0.25 and rs.state.inventory.has("itm_energy_krawumm"):
			_apply({"t": "use_item", "item": "itm_energy_krawumm", "member": m.id})


func _party_ratio(what: String) -> float:
	var cur: int = 0
	var mx: int = 0
	for m: PartyMember in rs.state.party:
		var sb: StatBlock = Progression.total_stats(m, data)
		if what == "mp":
			cur += m.mp
			mx += sb.values[StatBlock.Stat.MP]
		else:
			cur += m.hp
			mx += sb.values[StatBlock.Stat.HP]
	return float(cur) / float(maxi(1, mx))


func _nearest_safe(dist: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_d: int = 1 << 20
	var sids: Array = layout.safe_room_info.keys()
	sids.sort()
	for sid: Variant in sids:
		var cell: Vector2i = (layout.safe_room_info[sid] as Dictionary)["cell"]
		var d: int = int(dist.get(cell, -1))
		if d >= 0 and d < best_d:
			best_d = d
			best = {"kind": "safe", "id": str(sid), "cell": cell, "why": ""}
	return best


func _safe_cell(sid: String) -> Vector2i:
	return (layout.safe_room_info.get(sid, {"cell": layout.start}) as Dictionary).get("cell", layout.start)


# --- sessions: logout, absence, login ---------------------------------------------------------------------------------

func _session_over() -> bool:
	return rs.state.season.tempo == "calendar" and not plan.is_empty() and session < plan.size() \
		and session_play >= float(plan[session]["sec"])


## The logout of a finished session (in a safe room — rested — or the corridor, Vorsichtig), the absence until the
## next session (after the last one: until an hour after the last collapse — of the schedule now, a Sendepause moved
## it) and the login: "away" — over seven days (plus the night's Sendepause) "clamp" for the rest first, like
## Game.season_login_answer(true).
func _logout_login() -> void:
	_logout_due = false
	var fr: FloorRun = rs.state.floor_run
	var safe: bool = RunRules.in_safe_room(rs.state)
	var cmd: Dictionary = {"t": "sleep", "tactic": "careful"}
	if not safe:
		cmd["cell"] = [here.x, here.y]
	_apply(cmd)
	if not rs.state.season.asleep:
		errors.append("floor %d: the logout was refused (%s)" % [fr.index, JSON.stringify(rs.rejected_cmds.back()
			if not rs.rejected_cmds.is_empty() else {})])
		_done = true
		return
	_rec_add("sleeps", 1)
	var wall: int = session_wall + roundi(session_play)
	var rec: Dictionary = {"session": session, "floor": fr.index, "day": snappedf(_day(), 0.01), "safe": safe,
		"play_min": snappedf(session_play / 60.0, 0.1), "level": _levels()}
	session += 1
	var next: int = _end_utc() + 3600                # after the last session: until after the season's end
	if session < plan.size():
		next = DAY0_UTC + int(plan[session]["start"])
	var absence: int = maxi(SeasonClock.COMBAT_GRACE_SEC, next - wall)
	rec["absence"] = absence
	logouts.append(rec)
	session_wall = wall + absence
	session_play = 0.0
	_clock_acc = 0.0
	var login: Dictionary = {"absence": absence, "question": false}
	var away: int = absence
	if absence > SleepResolver.max_away(rs.state):
		away = SleepResolver.max_away(rs.state)
		login["question"] = true
		_apply({"t": "season", "v": 1, "op": "pause", "sec": absence - away, "why": "clamp"})
	var c0: int = rs.state.inventory.credits
	var before: Dictionary = {"rescues": rs.state.season.rescues, "deaths": rs.state.season.deaths,
		"floor": rs.state.floor_run.index}
	_apply({"t": "away", "sec": maxi(1, away)})
	_note_credits(c0)
	login["away"] = away
	login["floor"] = rs.state.floor_run.index
	login["rescued"] = rs.state.season.rescues - int(before["rescues"])
	login["died"] = rs.state.season.deaths - int(before["deaths"])
	login["level"] = _levels()
	login["band"] = _band_of(rs.state.floor_run.index)
	login["day"] = snappedf(_day(), 0.01)
	logins.append(login)
	_tries_reset()
	if rs.state.floor_run.index != int(before["floor"]) or not RunRules.in_safe_room(rs.state):
		_layout_now()
		if not RunRules.in_safe_room(rs.state):
			here = layout.start                     # the exploration spawns a corridor sleeper at the floor's start


# --- floors and the report --------------------------------------------------------------------------------------------

## Follows the candidate's floor (stairs, rescue): closes the old record, opens the new one; refreshes the layout.
func _track() -> void:
	var fr: FloorRun = rs.state.floor_run
	if not _rec.is_empty() and _rec["fr"] == fr:
		return
	if not _rec.is_empty():
		_close_floor("stairs" if _descended else "rescue")
	_descended = false
	_layout_now()
	here = _safe_cell(str(fr.location)) if RunRules.in_safe_room(rs.state) else layout.start
	_open_floor()


## The Pensum marks of the floor stay (season_planner.gd pensum): play seconds since the arrival when the Pflichtweg
## ("pflicht_sec") and vollständig ("full_sec") were done.
func _pensum() -> void:
	if _rec.is_empty() or (_rec.has("pflicht_sec") and _rec.has("full_sec")):
		return
	var pm: Dictionary = Planner.pensum(rs.state, data, layout, here, tried, (_rec["fb"] as Array).size())
	for k: String in ["pflicht", "full"]:
		if bool(pm[k]) and not _rec.has(k + "_sec"):
			_rec[k + "_sec"] = roundi(float(_rec["play"]))


func _layout_now() -> void:
	var fr: FloorRun = rs.state.floor_run
	var key: String = "%d:%d" % [fr.index, fr.seed]
	if key != _layout_key:
		layout = DungeonGenerator.generate(data.floor_def(fr.index), fr.seed)
		_layout_key = key


func _open_floor() -> void:
	var fr: FloorRun = rs.state.floor_run
	_rec = {"floor": fr.index, "fr": fr, "arrive_play": play, "arrive_day": snappedf(_day(), 0.01),
		"level_in": _levels(), "band": _band_of(fr.index), "combats": 0, "combat_sec": 0.0, "defeats": 0, "qb": [],
		"fb": [], "lost": [], "credits_in": rs.state.inventory.credits, "won0": credits_won, "safe_visits": 0,
		"sleeps": 0,
		"deaths_in": rs.state.season.deaths, "play": 0.0, "notes": []}
	tried.clear()
	_heal_trips = 0
	_shut = false
	_tries_reset()


func _close_floor(how: String) -> void:
	if _rec.is_empty():
		return
	var fr: FloorRun = _rec["fr"]
	var r: Dictionary = _rec.duplicate(true)
	r.erase("fr")
	r["how"] = how
	r["explore_sec"] = int(fr.stats.get("time_used_ticks", 0)) / FloorRun.TICKS_PER_SEC
	r["play_sec"] = roundi(float(r["play"]))
	r.erase("play")
	r["combat_sec"] = roundi(float(r["combat_sec"]))
	r["level_out"] = _levels()
	r["leave_day"] = snappedf(_day(), 0.01)
	r["credits_out"] = rs.state.inventory.credits
	r["credits_won"] = credits_won - int(r["won0"])
	r.erase("won0")
	r["groups"] = fr.defeated_groups.size()
	r["chests"] = fr.opened_chests.size()
	r["events"] = fr.completed_events.size()
	r["rooms"] = fr.visited.size()
	r["safe_rooms"] = fr.visited_safe_rooms.size()
	r["programme"] = fr.daily.size()
	r["deaths"] = rs.state.season.deaths - int(r["deaths_in"])
	r.erase("deaths_in")
	r["rescued"] = how == "rescue"
	recs.append(r)
	_rec = {}


func _finish() -> void:
	if _done:
		return
	var s: SeasonState = rs.state.season
	stop = s.result if s != null else "error"
	var how: String = {"finalist": "finale", "end": "end", "fallen": "out", "buried": "out"}.get(stop, stop)
	_close_floor(how)
	_done = true


## The report of the run (09 §11.6): the season's result, the per-floor records (minutes, levels against the band,
## bosses, combats, defeats, rescues, credits, how the floor was left), the logouts and logins, the cast's census.
func report() -> Dictionary:
	var s: SeasonState = rs.state.season if rs != null else null
	var census: Dictionary = CastSim.census(rs.state, data) if s != null else {}
	var ai_first: int = 0
	var compared: int = 0
	if not census.is_empty():
		var human: PackedInt32Array = census["human"]
		var first_ai: PackedInt32Array = census["ai_first"]
		for f in range(1, mini(format, human.size())):
			if human[f] == CastSim.NO_TIME and first_ai[f] == CastSim.NO_TIME:
				continue
			compared += 1
			if first_ai[f] != CastSim.NO_TIME and (human[f] == CastSim.NO_TIME or first_ai[f] < human[f]):
				ai_first += 1
	var out: Dictionary = {"seed": seed, "def": str(o["def"]), "tempo": str(o["tempo"]), "mode": str(o["mode"]),
		"profile": str(o["profile"]) if str(o["tempo"]) == "calendar" else "", "strategy": str(o["strategy"]),
		"pace": str(o["pace"]), "fighter": str(o["fighter"]), "stop": stop, "result": s.result if s != null else "",
		"result_floor": s.result_floor if s != null else 0, "vest": s.vest if s != null else false,
		"deaths": s.deaths if s != null else 0, "rescues": s.rescues if s != null else 0,
		"stairs": s.stairs if s != null else 0, "quote": SeasonRules.quote(rs.state) if s != null else 0,
		"level_end": _levels(), "play_min": snappedf(play / 60.0, 0.1), "combats": fights,
		"credits_end": rs.state.inventory.credits if rs != null else 0, "credits_won": credits_won,
		"credits_spent": credits_spent, "floors": recs, "logouts": logouts, "logins": logins, "talents": talents,
		"cast": {"ai": int(census.get("ai", 0)), "vest": int(census.get("vest", 0)), "in": int(census.get("in", 0)),
			"finalists": int(census.get("finalists", 0)), "ai_first": ai_first, "compared": compared},
		"errors": errors, "rejected": rs.rejected_cmds.size() if rs != null else 0}
	if _final_hash != "":
		out["hash"] = _final_hash
	return out


# --- helpers ----------------------------------------------------------------------------------------------------------

## Applies a recorded command and handles its events; a refusal is an error of the run (the core bot must play legal).
func _apply(c: Dictionary) -> void:
	var n: int = rs.rejected_cmds.size()
	_events(rs.apply(c))
	if rs.rejected_cmds.size() > n:
		errors.append("floor %d: %s refused (%s)" % [rs.state.floor_run.index if rs.state.floor_run != null else 0,
			str(c.get("t", "")), str(rs.rejected_cmds[n].get("reason", ""))])


## SEASON events of a command or of ticks: a rescue moved the run (the next _track follows it), the end.
func _events(evs: Array[ExploreEvent]) -> void:
	for ev: ExploreEvent in evs:
		if ev.type != ExploreEvent.Type.SEASON:
			continue
		match str(ev.data.get("kind", "")):
			"rescue":
				if not _rec.is_empty():
					_rec_note("rescue", "from %d (%s)" % [int(ev.data.get("from", 0)), str(ev.data.get("waived", ""))])
			"finale", "end", "out":
				pass


func _note_credits(before: int) -> void:
	var d: int = rs.state.inventory.credits - before
	if d > 0:
		credits_won += d
	elif d < 0:
		credits_spent -= d


func _tries(kind: String) -> int:
	return int(_boss_tries.get(kind, 0))


func _tries_reset() -> void:
	_boss_tries = {}


func _rec_add(key: String, n: int) -> void:
	if not _rec.is_empty():
		_rec[key] = int(_rec.get(key, 0)) + n


func _rec_addf(key: String, x: float) -> void:
	if not _rec.is_empty():
		_rec[key] = float(_rec.get(key, 0.0)) + x


func _rec_note(what: String, text: String) -> void:
	if not _rec.is_empty():
		(_rec["notes"] as Array).append("%s: %s @ %.2f" % [what, text, _day()])


func _levels() -> Array[int]:
	var out: Array[int] = []
	for m: PartyMember in rs.state.party:
		out.append(m.level)
	return out


func _band_of(floor_index: int) -> Array[int]:
	var b: Vector2i = LevelBand.band(data, floor_index)
	return [b.x, b.y]


## The season's last collapse (unix seconds): a Sendepause (the login's clamp) moves it.
func _end_utc() -> int:
	var at: Array[int] = rs.state.season.collapse_utc
	return at[at.size() - 1] if not at.is_empty() else DAY0_UTC + SeasonClock.format_days(format) * DAY


## Days since day 0 in season time (the cast's clock, without the Sendepause).
func _day() -> float:
	return float(CastSim.now(rs.state)) / float(DAY)
