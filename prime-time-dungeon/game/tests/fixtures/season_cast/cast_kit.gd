extends RefCounted
## Test kit of 09 ST1-F (the AI cast): start commands with the cast block, a season state with its cast, the reference
## human of the calibration and the calibration run itself (the bands of 09 §4.2 over many seeds). Private test helper
## (no class_name): preload it.
##
## The reference human (09 §4.2: "Erste KI auf Etage N vor dem ersten Menschen"; the harness profile `typical` of 09
## §11.6): starts the season at a random minute of the Vorprogramm (the day before day 0) and plays the first evening
## 60–90 min; from day 0 one session a day of 45–60 min, starting between an hour before and an hour after the air time
## (who waits in the Vorlauf comes when the floor opens, 09 §2.9 "Neue Etage offen"); the Pflichtweg of each floor (20 /
## 30 / 45 / 60 min); waits at closed stairs (09 §2.6) and goes down the moment they open while playing; a collapse that
## catches it is a rescue (09 §2.5). A test-side model with its own rng —
## the cast never sees it except through the arrivals (CastModel.human_arrives, like CastSim.on_floor_start).

const Kit := preload("res://tests/fixtures/season_core/season_core.gd")
const CastModel := preload("res://core/season/cast_model.gd")
const DAY: int = 86400
const HOUR: int = 3600
const WORK: PackedInt32Array = [20, 30, 45, 60]
const NO_TIME: int = CastMember.NO_TIME


## The start command of `def_id` with the cast block of its template (CastSim.start_block).
static func start_cmd(d: GameData, def_id: String = "ssn_basis", tempo: String = "calendar", mode: String = "net",
		start: int = Kit.START) -> Dictionary:
	var cmd: Dictionary = Kit.start_cmd(d, def_id, tempo, mode, start)
	cmd["cast"] = CastSim.start_block(d.season_def(def_id))
	return cmd


## A RunSim season run with its AI cast (like Kit.sim: the start, floor 1, the hero).
static func sim(d: GameData, def_id: String = "ssn_basis", tempo: String = "calendar", mode: String = "net",
		seed: int = Kit.SEED) -> RunSim:
	var st: GameState = GameState.create_new(d, 0, GameState.DEFAULT_NAME, seed, &"prime")
	RunRules.rt_start(st, d)
	var s: RunSim = RunSim.new(d, st, {}, {})
	var rl: RunLog = RunLog.new()
	rl.header = {"schema": 1, "seed": seed, "slot": 0, "mode": "campaign", "difficulty": "prime",
		"sim_version": RunSim.SIM_VERSION, "event_id": "", "run_id": "run_st1f_test", "player_id": "local",
		"window_id": "", "league": "", "combat_mode": "realtime", "rt_version": RunRules.RT_VERSION}
	s.run_log = rl
	s.apply(start_cmd(d, def_id, tempo, mode))
	s.apply({"t": "floor", "floor": 1})
	s.apply({"t": "hero", "id": "kai"})
	return s


## The model of the season block of `st` (read-only use in tests).
static func model(st: GameState, d: GameData) -> CastModel:
	var m: CastModel = CastModel.new()
	m.read(st.season.cast, st.season, st.seed, d)
	return m


## The reference human's arrival per floor 1..`format` (cast seconds since day 0; index floor − 1; NO_TIME never).
static func human_arrivals(seed: int, format: int) -> PackedInt32Array:
	var rng: RandomNumberGenerator = SeedUtil.make_rng(SeedUtil.derive(seed, "reference_human", 0))
	var arr: PackedInt32Array = []
	arr.resize(format)
	arr.fill(NO_TIME)
	var t_start: int = -rng.randi_range(60, DAY - 60)
	arr[0] = t_start
	var fl: int = 1
	var done: int = 0                             # minutes of the floor's Pflichtweg done
	var sessions: Array[Vector2i] = [Vector2i(t_start, rng.randi_range(60, 90))]
	for d in SeasonClock.format_days(format):
		sessions.append(Vector2i(d * DAY + rng.randi_range(-60, 60) * 60, rng.randi_range(45, 60)))
	for sess: Vector2i in sessions:
		var t: int = sess.x
		var end: int = sess.x + sess.y * 60
		while fl < format and SeasonClock.end_day(fl) * DAY <= t:   # caught by a collapse: rescued
			fl += 1
			arr[fl - 1] = SeasonClock.end_day(fl - 1) * DAY
			done = 0
		while t < end and fl < format:
			var need: int = WORK[mini(fl, 4) - 1] - done
			var use: int = mini(need, (end - t) / 60)
			done += use
			t += use * 60
			if done < WORK[mini(fl, 4) - 1]:
				break
			var opens: int = NO_TIME if fl + 1 <= 3 else SeasonClock.end_day(fl - 1) * DAY
			if opens >= end:
				break
			t = maxi(t, opens)
			if SeasonClock.end_day(fl) * DAY <= t:
				break
			fl += 1
			arr[fl - 1] = t
			done = 0
	return arr


## One calibration season of the model (09 §4.2): template `def_id`, `mode`, the reference human of `seed`. {"ai",
## "vest3", "vest9", "in3", "in9" (AI places with the vest / still in after floors 3 and 9 collapsed), "finalists",
## "final_vest", "ai_first" (floors 2..format where the first AI came before the reference human), "floors" (floors
## compared)}.
static func calibrate(d: GameData, st: GameState, seed: int, mode: String, def_id: String = "ssn_akt3") -> Dictionary:
	st.season = null
	st.floor_run = null
	st.seed = seed
	var format: int = d.season_def(def_id).format
	var arr: PackedInt32Array = human_arrivals(seed, format)
	RunRules.apply_season(st, d, start_cmd(d, def_id, "calendar", mode, Kit.DAY0 + arr[0]))   # the human starts it
	var m: CastModel = model(st, d)
	var out: Dictionary = {"ai": m.places - m.humans}
	var marks: Array[Vector2i] = []               # (time, floor ≥ 1 = an arrival | 0 = a snapshot)
	for f in range(2, format + 1):
		if arr[f - 1] != NO_TIME:
			marks.append(Vector2i(arr[f - 1], f))
	for day: int in [SeasonClock.end_day(mini(3, format)), SeasonClock.end_day(mini(9, format)),
			SeasonClock.end_day(format)]:
		marks.append(Vector2i(day * DAY + HOUR, -day))
	marks.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x or (a.x == b.x and a.y > b.y))
	for mk: Vector2i in marks:
		if mk.y >= 1:
			m.catch_up(CastModel.hour_of(mk.x) + 1, mk.x)
			m.flush(mk.x)
			m.human_arrives(mk.y, mk.x, true)
			m.hf = maxi(m.hf, mk.y)
			continue
		m.catch_up(CastModel.hour_of(mk.x), mk.x)
		m.flush(mk.x)
		var vest: int = 0
		var still: int = 0
		var died: int = 0
		var rescued: int = 0
		var buried: int = 0
		for mb: CastMember in m.members:
			if mb.is_ai():
				vest += 1 if mb.has(CastMember.F_VEST) else 0
				still += 0 if mb.is_out() else 1
				died += 1 if mb.dt > 0 or (mb.is_out() and not mb.has(CastMember.F_BURIED)) else 0
				rescued += 1 if mb.rs > 0 or mb.has(CastMember.F_BURIED) else 0
		var day2: int = -mk.y
		for pair: Array in [[3, "3"], [9, "9"]]:
			if day2 == SeasonClock.end_day(mini(int(pair[0]), format)):
				out["vest" + str(pair[1])] = vest
				out["in" + str(pair[1])] = still
				out["died" + str(pair[1])] = died
				out["caught" + str(pair[1])] = rescued
	var fin: int = 0
	var fin_vest: int = 0
	for mb: CastMember in m.members:
		if mb.is_ai() and mb.has(CastMember.F_FINAL):
			fin += 1
			fin_vest += 1 if mb.has(CastMember.F_VEST) else 0
	out["finalists"] = fin
	out["final_vest"] = fin_vest
	var ai_first: int = 0
	var floors: int = 0
	for f in range(2, format + 1):
		if arr[f - 1] == NO_TIME and m.ai_first[f - 1] == NO_TIME:
			continue
		floors += 1
		if m.ai_first[f - 1] != NO_TIME and (arr[f - 1] == NO_TIME or m.ai_first[f - 1] < arr[f - 1]):
			ai_first += 1
			out["ai_first_f%d" % f] = 1
	out["ai_first"] = ai_first
	out["floors"] = floors
	return out
