extends TestCase
## 09 §11.6 test_09_season_clock (ST1-B): the broadcast schedule (2/3/4/5 days, formats 24/54/84), day 0 = the next
## air time (time zones, an air time at the start), the collapse dates in UTC (a fixed day offset — after a
## daylight-saving change they move an hour in local time, V-17), the floor on air and the stairs limit from floor 4,
## the Am-Stück countdown per floor (floor 1 = the slice's 20:00, Vorabend × 1.5, no grace after loading), the monotone
## clock (a backwards wall clock stands, jumps over seven days are refused), the Sendepause (14 days, "clamp" does not
## count), the daily programme (at most five, kept until the collapse, Am Stück one point on entering), the binge clock
## and the migration of a campaign save (only from the switch to seasons on).

const Kit := preload("res://tests/fixtures/season_core/season_core.gd")
const SeasonsCheck := preload("res://core/data/validators/seasons.gd")
const ROOT: String = "user://test_09_season_clock"
const SAVES: String = "user://test_09_season_clock/saves"
const DAY: int = Kit.DAY
const DAY0: int = Kit.DAY0


func before_each() -> void:
	_rmrf(ROOT)
	Save.save_dir = SAVES
	Save.read_only = false


func after_each() -> void:
	Game.state = null
	Game.run_log = null
	Game.sim = null
	Game.persona = null
	Game.mode = &"campaign"
	Game.timer_running = false
	Game.in_battle = false
	Game.season_live_clock = false
	Game.season_speed = 1
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


# --- the schedule -----------------------------------------------------------------------------------------------------

func test_days_per_floor_and_formats() -> void:
	var days: Array = []
	for f in range(1, 19):
		days.append(SeasonClock.floor_days(f))
	assert_eq(days, [2, 3, 4, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5], "09 §2.4: 2, 3, 4, then 5")
	assert_eq([SeasonClock.end_day(1), SeasonClock.end_day(2), SeasonClock.end_day(3), SeasonClock.end_day(4)],
		[2, 5, 9, 14], "collapse days of the table")
	assert_eq([SeasonClock.format_days(6), SeasonClock.format_days(12), SeasonClock.format_days(18)], [24, 54, 84])
	for format: int in [6, 12, 18]:
		var dates: Array[int] = SeasonClock.schedule(DAY0, format)
		assert_eq(dates.size(), format)
		assert_eq(dates[0], DAY0 + 2 * DAY, "floor 1 has two full days after day 0")
		assert_eq(dates.back(), DAY0 + SeasonClock.format_days(format) * DAY)
		for i in dates.size():
			assert_eq((dates[i] - DAY0) % DAY, 0, "every collapse at the air time (UTC, V-17)")
		assert_eq(int(SeasonsCheck.FORMATS[format]), SeasonClock.format_days(format), "the validator's copy (core/data)")
	var d: GameData = real_data()
	for sd: SeasonDef in d.all_seasons():
		assert_eq(sd.days, SeasonClock.format_days(sd.format), sd.id)
	assert_eq(SeasonRules.default_def(d), "ssn_akt3", "09 §2.2: the largest own format (offline: all owned)")


func test_day0_is_the_next_air_time() -> void:
	var air: int = SeasonClock.air_seconds("20:00")
	assert_eq([air, SeasonClock.air_seconds("07:05"), SeasonClock.air_seconds("24:00"), SeasonClock.air_seconds("x")],
		[72000, 25500, -1, -1])
	var midnight: int = DAY0 - DAY0 % DAY       # some UTC midnight
	var cest: int = 2 * 3600                    # 20:00 local = 18:00 UTC
	assert_eq(SeasonClock.day0(midnight + 10 * 3600, air, cest), midnight + 18 * 3600, "10:00 UTC → today's 18:00")
	assert_eq(SeasonClock.day0(midnight + 19 * 3600, air, cest), midnight + DAY + 18 * 3600, "after it → tomorrow")
	assert_eq(SeasonClock.day0(midnight + 18 * 3600, air, cest), midnight + 18 * 3600, "at the air time → now")
	var est: int = -5 * 3600                    # 20:00 local = 01:00 UTC of the next day
	assert_eq(SeasonClock.day0(midnight + 10 * 3600, air, est), midnight + DAY + 3600)
	assert_eq(SeasonClock.day0(midnight + 30 * 60, air, est), midnight + 3600, "00:30 UTC → 01:00 UTC the same day")
	for start: int in [midnight + 1, midnight + 43210, midnight + DAY - 1]:
		var d0: int = SeasonClock.day0(start, air, cest)
		assert_between(d0 - start, 0, DAY - 1, "day 0 within a day after the start")
	# daylight saving (V-17): the dates are UTC — a start in winter at 20:00 CET collapses at 21:00 CEST in summer
	var winter: int = SeasonClock.day0(midnight, air, 3600)
	var dates: Array[int] = SeasonClock.schedule(winter, 18)
	assert_eq(posmod(dates[17] + 3600, DAY), air, "20:00 in winter time (UTC+1)")
	assert_eq(posmod(dates[17] + 7200, DAY), air + 3600, "= 21:00 in summer time (UTC+2) — documented, not corrected")


func test_start_command_checks_the_schedule() -> void:
	var d: GameData = Kit.data()
	var st: GameState = GameState.create_new(d, 0, GameState.DEFAULT_NAME, 7, &"prime")
	var ok: Dictionary = Kit.start_cmd(d)
	assert_eq(SeasonRules.refusal(st, d, ok), "")
	var forged: Dictionary = ok.duplicate(true)
	(forged["collapse_utc"] as Array)[5] = int((forged["collapse_utc"] as Array)[5]) + DAY
	assert_eq(SeasonRules.refusal(st, d, forged), "schedule_mismatch", "a longer last floor (V-17)")
	var early: Dictionary = ok.duplicate(true)
	early["utc"] = DAY0 - DAY
	assert_eq(SeasonRules.refusal(st, d, early), "bad_start", "day 0 is the NEXT air time after the start")
	var late: Dictionary = ok.duplicate(true)
	late["utc"] = DAY0 + 1
	assert_eq(SeasonRules.refusal(st, d, late), "bad_start")
	var no_utc: Dictionary = ok.duplicate(true)
	no_utc.erase("utc")
	assert_eq(SeasonRules.refusal(st, d, no_utc), "", "without utc the start is day 0 itself (the ST0 shape)")
	var wrong: Dictionary = ok.duplicate(true)
	wrong["format"] = 12
	wrong["collapse_utc"] = SeasonClock.schedule(DAY0, 12)
	assert_eq(SeasonRules.refusal(st, d, wrong), "format_mismatch", "the format comes with the template (V-14)")
	var unknown: Dictionary = ok.duplicate(true)
	unknown["def"] = "ssn_nope"
	assert_eq(SeasonRules.refusal(st, d, unknown), "unknown_season")
	var s: RunSim = Kit.sim(d)
	assert_eq(SeasonRules.refusal(s.state, d, ok), "season_started")
	var late_run: GameState = GameState.create_new(d, 0, GameState.DEFAULT_NAME, 7, &"prime")
	RunRules.start_floor(late_run, d, 1)
	assert_eq(SeasonRules.refusal(late_run, d, ok), "season_late", "09 §9.1: the start comes before floor / hero")
	assert_eq(RunRules.command_refusal(st, d, {}, ok, false, {}, true), "event_run", "never in an event run")
	assert_eq(s.state.season.utc, Kit.START, "the clock starts at the start time (the Vorprogramm)")
	assert_eq([s.state.season.on_air(), s.state.season.vest, s.state.season.programme],
		[1, true, [0, 0, 0, 0, 0, 0]])


# --- on air, stairs limit, the clock -------------------------------------------------------------------------------

func test_on_air_and_the_stairs_limit() -> void:
	var want: Array = [3, 3, 4, 5, 6, 6, 6]
	for collapsed in 7:
		assert_eq(SeasonClock.open_floor_max(collapsed, 6, false), want[collapsed], "collapsed %d" % collapsed)
		assert_eq(SeasonClock.open_floor_max(collapsed, 6, true), 6, "Am Stück: no limit")
	assert_eq(SeasonClock.open_floor_max(9, 18, false), 11)
	var d: GameData = Kit.data()
	var s: RunSim = Kit.sim(d)
	var st: SeasonState = s.state.season
	assert_eq([st.on_air(), SeasonRules.open_floor_max(s.state)], [1, 3], "Vorprogramm: floors 1–3 open")
	assert_eq(SeasonRules.opens_in(s.state, 4), DAY0 + 5 * DAY - Kit.START, "floor 4 opens at day 5")
	Kit.clock_to(s, DAY0 + 2 * DAY)
	assert_eq([st.collapsed, st.on_air()], [1, 2], "day 2: floor 1 collapsed, floor 2 on air")
	Kit.clock_to(s, DAY0 + 5 * DAY - 1)
	assert_eq([st.collapsed, SeasonRules.open_floor_max(s.state)], [1, 3], "a second before day 5")
	assert_eq(SeasonRules.opens_in(s.state, 4), 1)
	var ev: Array = Kit.clock_to(s, DAY0 + 5 * DAY)
	assert_eq([st.collapsed, SeasonRules.open_floor_max(s.state)], [2, 4], "day 5: floor 4 opens")
	assert_eq(Kit.event(ev, "opened"), {"kind": "opened", "floor": 4})
	assert_eq(SeasonRules.collapse_in(s.state), 4 * DAY, "floor 3 collapses at day 9")


func test_clock_is_monotone_and_jumps_are_capped() -> void:
	var d: GameData = Kit.data()
	var s: RunSim = Kit.sim(d)
	for bad: Dictionary in [{"t": "clock", "sec": 0}, {"t": "clock", "sec": -60}, {"t": "clock"}]:
		assert_ne(Command.validate(bad), "", "the clock only moves forward: " + str(bad))
	assert_eq(SeasonRules.refusal(s.state, d, {"t": "clock", "sec": SeasonClock.MAX_JUMP_SEC + 1}), "clock_jump",
		"V-17: more than seven days at once is a pause clamp + away")
	assert_eq(SeasonRules.refusal(s.state, d, {"t": "clock", "sec": SeasonClock.MAX_JUMP_SEC}), "")
	s.apply({"t": "clock", "sec": SeasonClock.MAX_JUMP_SEC + 1})
	assert_eq(s.rejected_cmds.back()["reason"], "clock_jump")
	var before: int = s.state.season.utc
	s.apply({"t": "clock", "sec": 60})
	assert_eq(s.state.season.utc, before + 60)
	assert_eq(Command.is_external({"t": "clock", "sec": 60}), true, "the clock is set from outside (cmd id 0)")


func test_live_wall_clock_stands_backwards() -> void:
	Game.start_season(0, "ssn_basis", {"now": Kit.START, "tz_sec": 0, "seed": 31})
	assert_not_null(Game.state.season, "the season started (slot 0: never written)")
	var cmds: int = Game.run_log.cmds().size()
	Game.season_live_clock = true
	Game.timer_running = true
	var wall: int = int(Time.get_unix_time_from_system())
	Game.state.season.seen_unix = wall + 3600       # the device clock ran an hour backwards
	Game._season_process()
	assert_eq(Game.run_log.cmds().size(), cmds, "a backwards wall clock records nothing: the season stands")
	assert_eq(Game.state.season.seen_unix, wall + 3600, "until the wall clock catches up")
	Game.state.season.seen_unix = wall - 61
	var utc: int = Game.state.season.utc
	Game._season_process()
	var last: Dictionary = Game.run_log.cmds().back()
	assert_eq([last["c"]["t"], last["id"]], ["clock", 0], "61 s of wall time → one clock command (external)")
	assert_between(Game.state.season.utc - utc, 61, 63)
	Game.season_speed = 1440
	Game.state.season.seen_unix = int(Time.get_unix_time_from_system()) - 2
	utc = Game.state.season.utc
	Game._season_process()
	assert_between(Game.state.season.utc - utc, 2 * 1440, 4 * 1440, "Zeitraffer (debug): × speed")
	Game.state.season.seen_unix = int(Time.get_unix_time_from_system()) - 3600
	cmds = Game.run_log.cmds().size()
	Game.season_speed = 1
	Game._season_process()
	var kinds: Array = []
	for e: Dictionary in Game.run_log.cmds().slice(cmds):
		kinds.append(str(e["c"]["t"]))
	assert_eq(kinds, ["sleep", "away"], "a gap over 10 min is an absence: the figure slept there (ST1-G, 09 §5.1 Nr. 2)")
	assert_false(Game.state.season.asleep, "and woke up: the wake summary tells the night")
	assert_eq(Game.season_wake["title"], "WÄHREND SIE SCHLIEFEN …")
	Game.season_wake = {}


# --- the Am-Stück countdown, no grace ---------------------------------------------------------------------------------

func test_binge_countdown_per_floor() -> void:
	assert_eq([SeasonClock.binge_ticks(1), SeasonClock.binge_ticks(2), SeasonClock.binge_ticks(3),
		SeasonClock.binge_ticks(4), SeasonClock.binge_ticks(18)], [36000, 54000, 72000, 90000, 90000],
		"20 / 30 / 40, then 50 min (09 §2.1)")
	assert_eq(SeasonClock.binge_ticks(2, true), 81000, "09 §7.4: Vorabend × 1.5")
	var d: GameData = Kit.data()
	assert_eq(SeasonClock.binge_ticks(1), d.floor_def(1).timer_seconds * 30, "floor 1 = the slice's 20:00")
	var s: RunSim = Kit.sim(d, "ssn_basis", "binge")
	assert_eq(s.state.floor_run.time_left_ticks, 36000)
	s.apply({"t": "descend"})
	s.apply({"t": "floor", "floor": 2})
	assert_eq(s.state.floor_run.time_left_ticks, 54000, "the countdown of floor 2 starts on entering it")
	s.apply({"t": "difficulty", "to": "vorabend"})
	s.apply({"t": "descend"})
	s.apply({"t": "floor", "floor": 3})
	assert_eq(s.state.floor_run.time_left_ticks, 108000, "Vorabend from the next floor on (× 1.5)")
	var cal: RunSim = Kit.sim(d)
	var fr: FloorRun = cal.state.floor_run
	fr.timer_started = true
	var left: int = fr.time_left_ticks
	cal.step(600)
	assert_eq([fr.time_left_ticks, int(fr.stats["time_used_ticks"])], [left, 600],
		"calendar: no floor countdown — only the floor's time counts")
	assert_eq(cal.tick(), 600)


func test_no_grace_after_loading_a_season() -> void:
	assert_true(Game.start_season(1, "ssn_basis", {"tempo": "binge", "now": Kit.START, "tz_sec": 0, "seed": 5}))
	Game.state.floor_run.time_left_ticks = 300
	assert_eq(Save.save_slot(1), OK, Save.last_error())
	Game.state = null
	assert_eq(Save.load_slot(1), OK, Save.last_error())
	assert_eq(Game.state.floor_run.time_left_ticks, 300, "09 §9.1: TIMER_GRACE_ON_LOAD is the campaign's, not a season's")
	Game.new_game(2, "Kai", 5)
	Game.state.floor_run.time_left_ticks = 300
	assert_eq(Save.save_slot(2), OK)
	assert_eq(Save.load_slot(2), OK)
	assert_eq(Game.state.floor_run.time_left_ticks, Save.GRACE_SECONDS * 30, "the campaign keeps its 3:00")


# --- pauses ----------------------------------------------------------------------------------------------------------

func test_sendepause_moves_every_open_date() -> void:
	var d: GameData = Kit.data()
	var s: RunSim = Kit.sim(d)
	Kit.clock_to(s, DAY0 + 3 * DAY)                 # floor 1 collapsed (day 2)
	var st: SeasonState = s.state.season
	var before: Array[int] = st.collapse_utc.duplicate()
	var air: int = st.next_air_utc
	s.apply({"t": "season", "v": 1, "op": "pause", "sec": 2 * DAY, "why": "user"})
	assert_eq(st.collapse_utc[0], before[0], "a collapsed floor keeps its date")
	for i in range(1, 6):
		assert_eq(st.collapse_utc[i], before[i] + 2 * DAY, "an open date moves (floor %d)" % (i + 1))
	assert_eq([st.next_air_utc, st.pause_sec], [air + 2 * DAY, 2 * DAY])
	assert_eq(SeasonRules.refusal(s.state, d, {"t": "season", "v": 1, "op": "pause", "sec": 12 * DAY + 1,
		"why": "user"}), "pause_budget", "V-9: 14 days per season")
	s.apply({"t": "season", "v": 1, "op": "pause", "sec": 12 * DAY, "why": "user"})
	assert_eq(st.pause_sec, 14 * DAY)
	s.apply({"t": "season", "v": 1, "op": "pause", "sec": 3 * DAY, "why": "clamp"})
	assert_eq([st.pause_sec, st.collapse_utc[1]], [14 * DAY, before[1] + 17 * DAY],
		"a clamp after a clock jump does not count against the 14 days (09 §5.5)")
	var b: RunSim = Kit.sim(d, "ssn_basis", "binge")
	for c: Dictionary in [{"t": "season", "v": 1, "op": "pause", "sec": 60, "why": "user"}, {"t": "clock", "sec": 60}]:
		assert_eq(SeasonRules.refusal(b.state, d, c), "binge", "Am Stück has no calendar: " + str(c["t"]))
	b.apply({"t": "season", "v": 1, "op": "tempo"})
	assert_eq(b.rejected_cmds.back()["reason"], "tempo", "only calendar → binge")


func test_tempo_switch_restarts_the_floor_countdown() -> void:
	var d: GameData = Kit.data()
	var s: RunSim = Kit.sim(d)
	var fr: FloorRun = s.state.floor_run
	fr.timer_started = true
	s.step(3000)
	Kit.clock_to(s, DAY0)
	var t0: int = SeasonRules.now(s.state)
	s.apply({"t": "season", "v": 1, "op": "tempo"})
	assert_eq([s.state.season.tempo, fr.time_left_ticks], ["binge", 36000], "the countdown of the floor starts anew")
	assert_eq(SeasonRules.now(s.state), t0, "the binge clock continues from the season clock")
	s.step(600)
	assert_eq(SeasonRules.now(s.state) - t0, 20 * SeasonClock.BINGE_FACTOR, "1 explored second = 144 season s")
	assert_eq(SeasonRules.collapse_in(s.state), (36000 - 600) / 30)


# --- the daily programme ---------------------------------------------------------------------------------------------

func test_daily_programme_cadence() -> void:
	var d: GameData = Kit.data()
	var s: RunSim = Kit.sim(d)
	var st: SeasonState = s.state.season
	assert_eq(st.programme, [0, 0, 0, 0, 0, 0], "the Vorprogramm has no programme yet")
	var ev: Array = Kit.clock_to(s, DAY0)
	assert_eq([st.airs, st.programme], [1, [1, 1, 1, 0, 0, 0]], "day 0: every open floor gets a point")
	assert_eq(Kit.event(ev, "daily")["floor"], 1, "the candidate's floor shows it (\"NEU\")")
	assert_eq(s.state.floor_run.daily, PackedStringArray(["daily_f1_1"]), "a placeholder id without a theme pool")
	Kit.clock_to(s, DAY0 + DAY)
	Kit.clock_to(s, DAY0 + 2 * DAY)
	assert_eq(st.programme, [2, 3, 3, 0, 0, 0], "floor 1: two points, then its collapse (09 §3.3)")
	Kit.clock_to(s, DAY0 + 5 * DAY)
	assert_eq(st.programme, [2, 5, 5, 1, 0, 0], "floor 4 opens at day 5 and gets its first point at once")
	Kit.clock_to(s, DAY0 + 12 * DAY)
	assert_eq(st.programme, [2, 5, 5, 5, 4, 0], "at most five per floor")
	var fr: FloorRun = s.state.floor_run
	assert_eq([fr.index, fr.daily.size()], [4, 5], "rescued three times; floor 4 shows its five points (kept)")
	var b: RunSim = Kit.sim(d, "ssn_basis", "binge")
	assert_eq(b.state.season.programme[0], 1, "Am Stück: one point on entering")
	b.apply({"t": "descend"})
	b.apply({"t": "floor", "floor": 2})
	assert_eq([b.state.season.programme[1], b.state.floor_run.daily.size()], [1, 1])


func test_daily_ids_come_from_the_theme_pool() -> void:
	var d: GameData = real_data()
	var st: GameState = GameState.create_new(d, 0, GameState.DEFAULT_NAME, 99, &"prime")
	assert_eq(SeasonRules.daily_id(st, d, 1, 3), "daily_f1_3", "thm_unterstadt has no pool yet (ST1-C)")
	var pool: PackedStringArray = ["pp_a", "pp_b", "pp_c", "pp_d", "pp_e", "pp_f"]
	var order: PackedInt32Array = SeasonRules._shuffled(pool.size(), SeedUtil.derive(99, "daily", 1))
	var ids: Array = []
	for n in range(1, 7):
		ids.append(pool[order[n - 1]])
	ids.sort()
	assert_eq(ids, Array(pool), "every pool entry once before a repeat")
	assert_eq(SeasonRules._shuffled(6, 5), SeasonRules._shuffled(6, 5), "deterministic per seed")


# --- the migration of a campaign save --------------------------------------------------------------------------------

func test_campaign_migration_waits_for_the_switch() -> void:
	var d: GameData = real_data()
	assert_lt(RunSim.SIM_VERSION, SeasonRules.CAMPAIGN_SEASON_SIM_VERSION, "no switch in ST1-B (no SIM_VERSION bump)")
	Game.new_game(1, "Kai", 77)
	assert_eq(Save.save_slot(1), OK)
	assert_eq(Save.load_slot(1), OK)
	assert_null(Game.state.season, "until the switch a campaign save stays a campaign")
	var st: GameState = GameState.create_new(d, 0, GameState.DEFAULT_NAME, 77, &"prime")
	RunRules.start_floor(st, d, 2)
	st.floor_run.time_left_ticks = 4321
	st.floor_run.stats["time_used_ticks"] = 3000
	assert_true(SeasonRules.migrate_campaign(st, d, "ssn_basis", Kit.START, 0))
	var s: SeasonState = st.season
	assert_eq([s.tempo, s.mode, s.def_id, s.format, s.day0_utc], ["binge", "net", "ssn_basis", 6, DAY0],
		"09 §8.7: a private season Am Stück")
	assert_eq(st.floor_run.time_left_ticks, 4321, "the floor's countdown = its time left (no grace)")
	assert_eq([s.stairs, s.reached[0], s.reached[1], s.reached[2]], [1, Kit.START, Kit.START, -1])
	assert_eq(SeasonRules.now(st), Kit.START, "the binge clock starts at the migration")
	assert_false(SeasonRules.migrate_campaign(st, d, "ssn_basis", Kit.START, 0), "once")
