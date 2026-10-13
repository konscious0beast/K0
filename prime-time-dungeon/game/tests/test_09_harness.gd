extends TestCase
## 09 §11.6 test_09_harness (ST1-I) — the Staffel-Harness: the play profiles (tests/tools/season_profiles.gd: the
## sessions of typical, 20 min, weekend and two weeks away per format, deterministic per seed, never two at once), the
## planner of both bots (tests/tools/season_planner.gd: the Pflichtweg's corridor, programme doors never a goal, red
## groups after the Revier-Boss, the level-up before a boss, boss attempts per tempo, the auto strategy, closed stairs,
## the Pensum marks), the formats (12 and 18 refused until ST1-C2, 09 decision I-2) and smoke seasons of the headless
## harness (tests/tools/season_harness.gd) — floor 1 Am Stück, and a calendar run over two sessions with a logout, an
## absence of nine days (the login's "clamp", collapses while asleep) and a login: every command legal, the same report
## and state hash per seed, RunSim.replay reproduces the run log bit for bit (also as a file). Heavy runs opt-in:
## PTD_HARNESS_SEEDS=<n> plays n whole seasons per profile of the ST1 gate (scaled to format 6) and Am Stück, checks
## that the core bot plays them without an error and prints the summaries and band verdicts
## (`PTD_HARNESS_SEEDS=3 tools/check.sh --tests-only --filter=test_09_harness`; the measurement itself is
## tools/season_harness.sh).

const Kit := preload("res://tests/fixtures/season_core/season_core.gd")
const RtLive := preload("res://tests/fixtures/rt_live/rt_live.gd")
const Profiles := preload("res://tests/tools/season_profiles.gd")
const Planner := preload("res://tests/tools/season_planner.gd")
const HarnessScript := preload("res://tests/tools/season_harness.gd")
const Report := preload("res://tests/tools/season_report.gd")
const DAY: int = 86400
const MIN: int = 60
const SEEDS_ENV: String = "PTD_HARNESS_SEEDS"


# --- the play profiles (09 §11.6, decision I-3) -----------------------------------------------------------------------

func test_profiles_are_deterministic_per_seed() -> void:
	for p: String in Profiles.PROFILES:
		assert_eq(Profiles.sessions(p, 7, 6), Profiles.sessions(p, 7, 6), "%s: the same seed, the same sessions" % p)
		assert_ne(Profiles.sessions(p, 7, 6), Profiles.sessions(p, 8, 6), "%s: another seed, other sessions" % p)
	assert_eq(Profiles.sessions("hourly", 7, 6), [] as Array[Dictionary], "an unknown profile has no sessions")


func test_profiles_typical_and_twenty_minutes() -> void:
	for fmt: int in [6, 12, 18]:
		var days: int = SeasonClock.format_days(fmt)
		for seed in 12:
			for p: String in ["typical", "20min"]:
				var ss: Array[Dictionary] = Profiles.sessions(p, seed, fmt)
				assert_eq(ss.size(), days + 1, "%s/%d: the first evening and one session a day" % [p, fmt])
				var first: Dictionary = ss[0]
				assert_true(bool(first["first"]) and int(first["day"]) == -1, "the season starts the day before day 0")
				assert_between(int(first["start"]), -DAY, -1, "the first evening lies in the Vorprogramm")
				var lo: int = 20 if p == "20min" else 60
				var hi: int = 20 if p == "20min" else 90
				assert_between(int(first["sec"]) / MIN, lo, hi, "%s: the first evening's minutes" % p)
				_check_days(ss, p, 20 if p == "20min" else 45, 20 if p == "20min" else 60)


func test_profiles_weekend_and_two_weeks_away() -> void:
	for fmt: int in [6, 12, 18]:
		var days: int = SeasonClock.format_days(fmt)
		for seed in 12:
			var we: Array[Dictionary] = Profiles.sessions("weekend", seed, fmt)
			var dow0: int = Profiles.day0_weekday("weekend", seed)
			assert_true(dow0 == Profiles.SUNDAY or dow0 == 0, "the weekend season starts on a Saturday or a Sunday")
			assert_between(int(we[0]["start"]), -4 * 3600, -2 * 3600, "the first weekend session")
			for s: Dictionary in we.slice(1):
				var wd: int = posmod(dow0 + int(s["day"]), 7)
				assert_true(wd == Profiles.SATURDAY or wd == Profiles.SUNDAY, "weekend sessions only on weekends")
				assert_eq(int(s["sec"]), 90 * MIN, "90 min each")
				assert_between(int(s["start"]) - int(s["day"]) * DAY, -120 * MIN, 60 * MIN, "around the air time")
			var away: Array[Dictionary] = Profiles.sessions("away2w", seed, fmt)
			var from: int = int(Profiles.AWAY_FROM[fmt])
			assert_eq([away.size(), int((away.back() as Dictionary)["day"])], [days + 1, days + Profiles.AWAY_DAYS - 1],
				"away2w/%d: 14 days without a session, then on past the format (the clamp's Sendepause)" % fmt)
			for s2: Dictionary in away:
				assert_false(int(s2["day"]) >= from and int(s2["day"]) < from + Profiles.AWAY_DAYS,
					"away2w/%d: no session on day %d" % [fmt, int(s2["day"])])
			_check_days(away.slice(1), "away2w", 45, 60)
			var idle: PackedInt32Array = Profiles.idle_days("away2w", seed, fmt)
			assert_eq([idle.size(), idle[0]], [Profiles.AWAY_DAYS, from], "away2w/%d: the idle days" % fmt)
	assert_eq(int(Profiles.AWAY_FROM[18]), 30, "format 18: days 30–43 away (09 §11.6)")
	assert_between(Profiles.planned_minutes("typical", 3, 6), 24 * 45 + 60, 24 * 60 + 90, "typical: the budget")


## Sessions after the first one: one a day (in order), `lo`–`hi` minutes, around the air time unless the previous one
## pushes it later, never two at once (Profiles.GAP_MIN apart).
func _check_days(ss: Array, what: String, lo: int, hi: int) -> void:
	var prev_day: int = -2
	for i in ss.size():
		var s: Dictionary = ss[i]
		if int(s["day"]) < 0:
			continue
		assert_gt(int(s["day"]), prev_day, "%s: one session a day, in order" % what)
		prev_day = int(s["day"])
		assert_between(int(s["sec"]) / MIN, lo, hi, "%s: the minutes of day %d" % [what, int(s["day"])])
		assert_between(int(s["start"]) - int(s["day"]) * DAY, -60 * MIN, 3 * 3600, "%s: near the air time" % what)
		if i > 0:
			var p: Dictionary = ss[i - 1]
			assert_true(int(s["start"]) >= int(p["start"]) + int(p["sec"]) + Profiles.GAP_MIN * MIN,
				"%s: day %d starts after the previous session" % [what, int(s["day"])])


# --- formats (09 decision I-2) ----------------------------------------------------------------------------------------

func test_formats_twelve_and_eighteen_are_refused() -> void:
	var d: GameData = real_data()
	assert_eq(HarnessScript.PLAYABLE_FORMATS, [6] as Array[int], "the harness measures format 6")
	for def_id: String in ["ssn_akt2", "ssn_akt3"]:
		var r: Dictionary = HarnessScript.run(d, 0, {"def": def_id})
		assert_true(str(r.get("error", "")).contains("ST1-C2"), "%s: refused with the reason" % def_id)
		assert_false(r.has("floors"), "%s: no run" % def_id)
	assert_true(str(HarnessScript.run(d, 0, {"profile": "hourly"}).get("error", "")).contains("hourly"),
		"an unknown profile is refused")


# --- the planner (both bots) ------------------------------------------------------------------------------------------

## Floors 2–6 Am Stück, the party at the start of the band: typical keeps to the Pflichtweg's corridor (groups, chests
## and events one room off it, the programme rooms' events, safe rooms two rooms off), never visits for its own sake;
## no strategy has a programme door, a show boss is no typical goal, red groups come only with `red`, rush has no
## groups, chests or events; a group lost GROUP_TRIES times stays alone.
func test_planner_strategies_on_the_season_floors() -> void:
	var d: GameData = real_data()
	var s: RunSim = Kit.sim(d, "ssn_basis", "binge")
	for f in range(2, 7):
		s.apply({"t": "descend"})
		s.apply({"t": "floor", "floor": f})
		var st: GameState = s.state
		var l: FloorLayout = DungeonGenerator.generate(d.floor_def(f), st.floor_run.seed)
		_set_level(st, LevelBand.band(d, f).x)
		var near: Dictionary = Planner.corridor(l, 1)
		var near2: Dictionary = Planner.corridor(l, 2)
		var typical: Array[Dictionary] = Planner.candidates(st, d, l, "typical", {}, false)
		assert_gt(typical.size(), 0, "floor %d: the Pflichtweg has goals" % f)
		for c: Dictionary in typical:
			var cell: Vector2i = c["cell"]
			match str(c["kind"]):
				"group", "chest":
					assert_true(near.has(cell), "floor %d: typical %s %s on the corridor" % [f, c["kind"], c["id"]])
				"event":
					assert_true(near.has(cell) or Planner.programme_cell(l, cell), "floor %d: event %s" % [f, c["id"]])
				"safe":
					assert_true(near2.has(cell), "floor %d: safe room %s near the Pflichtweg" % [f, c["id"]])
				"visit":
					fail("floor %d: typical never visits a room for its own sake" % f)
			if str(c["kind"]) == "group":
				assert_false(Planner.is_show_boss(d, l.enemy_by_id(str(c["id"]))), "floor %d: no show boss" % f)
		for strat: String in Planner.STRATEGIES:
			if strat == "auto":
				continue
			for red: bool in [false, true]:
				for c2: Dictionary in Planner.candidates(st, d, l, strat, {}, red):
					if str(c2["kind"]) == "gate":
						assert_eq(ZoneGenerator.programme_number(_gate_req(l, str(c2["id"]))), 0,
							"floor %d %s: a programme door is never a goal" % [f, strat])
					if str(c2["kind"]) == "group":
						var lv: int = Planner.group_level(d, l.enemy_by_id(str(c2["id"])))
						assert_eq(lv - Planner.hero_level(st) >= Planner.RED, red, "floor %d %s: red only with red" % [f,
							strat])
		var rush: Array[Dictionary] = Planner.candidates(st, d, l, "rush", {}, false)
		for c3: Dictionary in rush:
			assert_true(["gate", "safe"].has(str(c3["kind"])), "floor %d: rush only gates and safe rooms" % f)
		var thorough: Array[Dictionary] = Planner.candidates(st, d, l, "thorough", {}, false)
		var gid: String = ""
		for c4: Dictionary in thorough:
			if str(c4["kind"]) == "group":
				gid = str(c4["id"])
				break
		assert_ne(gid, "", "floor %d: thorough has groups" % f)
		var lost: Dictionary = {"lost:" + gid: Planner.GROUP_TRIES}
		for c5: Dictionary in Planner.candidates(st, d, l, "thorough", lost, false):
			assert_ne(str(c5["id"]), gid, "floor %d: a group that won twice stays alone" % f)
		var gcell: Vector2i = l.enemy_by_id(gid).cell
		assert_true(Planner.blocks(st, d, l, lost, Planner.NO_CELL).has(gcell), "floor %d: … and its room is avoided" % f)
		assert_false(Planner.blocks(st, d, l, lost, gcell).has(gcell), "floor %d: unless it is the goal" % f)
	assert_eq(s.rejected_cmds, [] as Array[Dictionary])


## The bosses: the Revier-Boss while its attempts last (four per floor Am Stück, two per session in the calendar), the
## optional Etagenboss only thorough (two per floor stay), the finale on the format's last floor; the level-up before a
## boss (no show boss, nothing above yellow); the auto strategy; closed stairs → "wait"; the Pensum marks.
func test_planner_bosses_level_up_auto_and_waits() -> void:
	var d: GameData = real_data()
	var s: RunSim = Kit.sim(d, "ssn_basis", "binge")
	s.apply({"t": "descend"})
	s.apply({"t": "floor", "floor": 2})
	var st: GameState = s.state
	var fr: FloorRun = st.floor_run
	var l: FloorLayout = DungeonGenerator.generate(d.floor_def(2), fr.seed)
	_set_level(st, LevelBand.band(d, 2).x)
	assert_eq(str(Planner.boss(st, l, "typical", 0, 0, true)["id"]), "f2_qb", "the Revier-Boss first")
	assert_eq(Planner.boss(st, l, "typical", Planner.BOSS_TRIES_BINGE, 0, true), {}, "Am Stück: four attempts")
	assert_eq(Planner.auto_strategy(st), "typical", "auto: the Pflichtweg while the Revier-Boss lives")
	var qb: EnemySpawn = l.enemy_by_id("f2_qb")
	_set_level(st, Planner.group_level(d, qb) - Planner.BOSS_GAP - 2)
	var up: Array[Dictionary] = Planner.level_up(st, d, l, {})
	for c: Dictionary in up:
		if str(c["kind"]) == "group":
			var e: EnemySpawn = l.enemy_by_id(str(c["id"]))
			assert_false(Planner.is_show_boss(d, e), "no show boss to level up on")
			assert_true(Planner.group_level(d, e) <= Planner.hero_level(st) + Planner.YELLOW, "nothing above yellow")
	_clear_floor(st, l)
	_set_level(st, Planner.group_level(d, qb) - Planner.BOSS_GAP - 2)
	assert_eq(str(Planner.goal(st, d, l, l.start, "typical", {}, {})["id"]), "f2_qb",
		"nothing left to level up on: the Revier-Boss after all")
	assert_eq(Planner.pensum(st, d, l, l.start, {}, 0), {"pflicht": false, "full": false}, "the Revier-Boss lives")
	fr.quarter_boss_defeated = true
	assert_eq(Planner.boss(st, l, "typical", 0, 0, false), {}, "the Etagenboss is optional (typical)")
	assert_eq(str(Planner.boss(st, l, "thorough", 0, 0, false)["id"]), "f2_fb", "thorough fights the Etagenboss")
	assert_eq(Planner.boss(st, l, "thorough", 0, 0, false, Planner.FLOOR_BOSS_TRIES), {}, "two attempts per floor")
	assert_eq(Planner.pensum(st, d, l, l.start, {}, 0), {"pflicht": true, "full": false}, "the Pflichtweg is done")
	assert_eq(Planner.pensum(st, d, l, l.start, {}, Planner.FLOOR_BOSS_TRIES), {"pflicht": true, "full": true},
		"vollständig: the Etagenboss given up after two attempts")
	fr.time_left_ticks = SeasonClock.binge_ticks(2)
	assert_eq(Planner.auto_strategy(st), "thorough", "auto: the rest while the countdown has time")
	fr.time_left_ticks = SeasonClock.binge_ticks(2) / 10
	assert_eq(Planner.auto_strategy(st), "typical", "auto: the stairs when the countdown runs out")
	assert_eq(str(Planner.goal(st, d, l, l.start, "auto", {}, {})["kind"]), "stairs", "nothing left: the stairs")
	# the calendar: two attempts per session, the finale on floor 6, closed stairs on floor 4 before its Vorlauf
	var c: RunSim = Kit.sim(d, "ssn_basis", "calendar")
	Kit.put_on_floor(c, 4)
	var cst: GameState = c.state
	var l4: FloorLayout = DungeonGenerator.generate(d.floor_def(4), cst.floor_run.seed)
	assert_eq(Planner.boss(cst, l4, "typical", Planner.BOSS_TRIES_SESSION, 0, true), {}, "two attempts a session")
	assert_eq(Planner.auto_strategy(cst), "typical", "the calendar: the Pflichtweg first")
	_clear_floor(cst, l4)
	cst.floor_run.quarter_boss_defeated = true
	assert_ne(SeasonRules.stairs_refusal(cst, d), "", "floor 4's stairs are closed on day −1")
	var w: Dictionary = Planner.goal(cst, d, l4, l4.start, "typical", {}, {})
	assert_eq(str(w["kind"]), "wait", "closed stairs: wait")
	assert_true(str(w["why"]).begins_with(Planner.CLOSED), "Kulissen im Aufbau")
	Kit.put_on_floor(c, 6)
	var l6: FloorLayout = DungeonGenerator.generate(d.floor_def(6), cst.floor_run.seed)
	cst.floor_run.quarter_boss_defeated = true
	var fin: Dictionary = Planner.boss(cst, l6, "typical", 0, 0, false)
	assert_eq([str(fin["id"]), str(fin["why"])], ["f6_fb", "Großes Finale"], "the finale on the last floor, any strategy")
	assert_eq(Planner.boss(cst, l6, "typical", 0, Planner.BOSS_TRIES_SESSION, false), {}, "the finale: per session")


## Ohne Netz (one life from floor 2) the planner plays carefully in every strategy: no show boss, nothing above yellow,
## no optional Etagenboss, a boss only at its level (BOSS_GAP 0) — floor 1 (the dress rehearsal) as Mit Netz.
func test_planner_careful_ohne_netz() -> void:
	var d: GameData = real_data()
	var s: RunSim = Kit.sim(d, "ssn_basis", "binge", "no_net")
	assert_false(Planner.careful(s.state), "floor 1: the dress rehearsal costs nothing")
	s.apply({"t": "descend"})
	s.apply({"t": "floor", "floor": 2})
	var st: GameState = s.state
	var l: FloorLayout = DungeonGenerator.generate(d.floor_def(2), st.floor_run.seed)
	_set_level(st, LevelBand.band(d, 2).x)
	assert_true(Planner.careful(st), "floor 2 Ohne Netz: careful")
	for strat: String in ["thorough", "typical"]:
		for red: bool in [false, true]:
			for c: Dictionary in Planner.candidates(st, d, l, strat, {}, red):
				if str(c["kind"]) != "group":
					continue
				var e: EnemySpawn = l.enemy_by_id(str(c["id"]))
				assert_false(Planner.is_show_boss(d, e), "%s: no show boss Ohne Netz" % strat)
				assert_true(Planner.group_level(d, e) <= Planner.hero_level(st) + Planner.YELLOW, "%s: yellow at most" % strat)
	var avoid: Array[Vector2i] = Planner.blocks(st, d, l, {}, Planner.NO_CELL)
	for e: EnemySpawn in l.enemies:
		if not e.is_boss and not e.is_stray() and (Planner.group_level(d, e) > Planner.hero_level(st) + Planner.YELLOW
				or Planner.is_show_boss(d, e)):
			assert_has(avoid, e.cell, "Ohne Netz the room of %s is walked round" % e.id)
	st.floor_run.quarter_boss_defeated = true
	assert_eq(Planner.boss(st, l, "thorough", 0, 0, false), {}, "no optional Etagenboss Ohne Netz")
	st.floor_run.quarter_boss_defeated = false
	var qb: EnemySpawn = l.enemy_by_id("f2_qb")
	_set_level(st, Planner.group_level(d, qb) - 1)
	var g: Dictionary = Planner.goal(st, d, l, l.start, "thorough", {}, {})
	assert_true(str(g["kind"]) != "boss" or Planner.level_up(st, d, l, {}).is_empty(), "one level below: level up first")


func _set_level(st: GameState, lv: int) -> void:
	for m: PartyMember in st.party:
		m.level = maxi(1, lv)


## Everything of the floor done except the bosses (a planner test, nothing recorded).
func _clear_floor(st: GameState, l: FloorLayout) -> void:
	var fr: FloorRun = st.floor_run
	for e: EnemySpawn in l.enemies:
		if not e.is_boss and not fr.defeated_groups.has(e.id):
			fr.defeated_groups.append(e.id)
	for ch: ChestSpawn in l.chests:
		if not fr.opened_chests.has(ch.id):
			fr.opened_chests.append(ch.id)
	for ev: EventSpawn in l.events:
		if not fr.completed_events.has(ev.id):
			fr.completed_events.append(ev.id)
	for g: Dictionary in l.gates:
		if not fr.opened_gates.has(str(g["key"])):
			fr.opened_gates.append(str(g["key"]))
	for sid: Variant in l.safe_room_info.keys():
		if not fr.visited_safe_rooms.has(str(sid)):
			fr.visited_safe_rooms.append(str(sid))
	for cell: Vector2i in l.sorted_cells():
		if not fr.visited.has(cell):
			fr.visited.append(cell)
	st.inventory.credits = 0                   # the wheel waits for credits


func _gate_req(l: FloorLayout, key: String) -> String:
	for g: Dictionary in l.gates:
		if str(g["key"]) == key:
			return str(g["requires"])
	return ""


# --- smoke seasons of the headless harness ----------------------------------------------------------------------------

## Floor 1 Am Stück (typical, fast): legal, the stairs, levels gained, and the run log replays bit for bit.
func test_smoke_floor_one_am_stueck() -> void:
	var d: GameData = real_data()
	var h: RefCounted = HarnessScript.new()
	var r: Dictionary = h.call("play_season", d, 7, {"tempo": "binge", "strategy": "typical", "pace": "fast",
		"floors": 1, "log": true})
	assert_eq([r["errors"], int(r["rejected"]), str(r["stop"])], [PackedStringArray(), 0, "floors"], "a legal run")
	var fl: Array = r["floors"]
	assert_eq(fl.size(), 1, "floor 1's record")
	var f1: Dictionary = fl[0]
	assert_eq(str(f1["how"]), "stairs", "floor 1 left by the stairs")
	assert_gt(int(f1["combats"]), 3, "combats on floor 1")
	assert_gt(int((f1["level_out"] as Array)[0]), int((f1["level_in"] as Array)[0]), "levels gained")
	assert_true(f1.has("pflicht_sec") and int(f1["pflicht_sec"]) <= int(f1["play_sec"]), "the Pflichtweg mark")
	assert_eq((f1["qb"] as Array).size() > 0, true, "the Revier-Boss fought")
	assert_true(Report.run_line(r).begins_with("seed 7 binge/net"), "the report line")
	var rs: RunSim = h.get("rs")
	var rp: Dictionary = RunSim.replay(d, rs.run_log)
	assert_eq([rp["errors"], int(rp["mismatch_at"]), str(rp["final_hash"])], [PackedStringArray(), -1, str(r["hash"])],
		"RunSim.replay reproduces the harness run")


## A calendar run with sessions of its own: 15 min on the evening before day 0, the logout, nine days away (more than
## seven: the login's "clamp" first, collapses while asleep), 5 min on day 9, the logout, the login (floor 2's collapse
## carries the sleeper into the first safe room of floor 3) and the Recall there (06 §3.5: the controlled figure first,
## each "casting" with its signature's "loadout", Casting.signature_loadout), the logout. Twice with the same seed: the
## same report; the run log replays bit for bit, also as a file.
func test_smoke_calendar_sessions_logout_and_login() -> void:
	var d: GameData = real_data()
	var plan: Array = [{"day": -1, "start": -1800, "sec": 15 * MIN, "first": true},
		{"day": 9, "start": 9 * DAY - 600, "sec": 5 * MIN, "first": false},
		{"day": 9, "start": 9 * DAY + 3000, "sec": 5 * MIN, "first": false}]
	var opts: Dictionary = {"tempo": "calendar", "strategy": "auto", "pace": "fast", "plan": plan, "sessions": 3,
		"log": true}
	var h: RefCounted = HarnessScript.new()
	var r: Dictionary = h.call("play_season", d, 11, opts)
	assert_eq([r["errors"], int(r["rejected"]), str(r["stop"])], [PackedStringArray(), 0, "sessions"], "a legal run")
	var outs: Array = r["logouts"]
	var ins: Array = r["logins"]
	assert_eq([outs.size(), ins.size()], [3, 3], "three logouts, three logins")
	var in1: Dictionary = ins[0]
	assert_true(int(in1["absence"]) > SeasonClock.MAX_JUMP_SEC, "nine days away")
	assert_true(bool(in1["question"]) and int(in1["away"]) < int(in1["absence"]), "the clamp: at most seven days")
	assert_gt(int(in1["floor"]), 1, "the collapses moved the sleeper on")
	var in2: Dictionary = ins[1]
	assert_eq([bool(in2["question"]), int(in2["away"]), int(in2["floor"]), int(in2["rescued"])],
		[false, int(in2["absence"]), 3, 1], "a short absence: all of it — and the rescue to floor 3")
	assert_between(float((outs[0] as Dictionary)["play_min"]), 15.0, 22.0, "the first session's play time")
	var again: Dictionary = (HarnessScript.new() as RefCounted).call("play_season", d, 11, opts)
	assert_eq(again, r, "the same seed, the same report")
	var rs: RunSim = h.get("rs")
	var recall: Array = []
	for e: Dictionary in rs.run_log.cmds():
		var c: Dictionary = e["c"]
		if ["casting", "loadout"].has(str(c["t"])):
			recall.append([str(c["t"]), str(c["member"])])
	assert_eq(recall, [["casting", "kai"], ["loadout", "kai"], ["casting", "mopsula"], ["loadout", "mopsula"]],
		"the Recall on floor 3: the controlled figure first, each with the signature on its slot")
	for mid: String in ["kai", "mopsula"]:
		var m: PartyMember = rs.state.member(mid)
		var pick: Array = HarnessScript.RECALL[mid]
		var sig: Dictionary = Casting.signature(d, mid, m.class_id)
		assert_eq([m.species_id, m.class_id, str(m.rt_loadout.get(str(int(sig["slot"])), ""))],
			[str(pick[0]), str(pick[1]), str(sig["skill"])], "%s: species, class and signature" % mid)
		assert_ne(Casting.mode(rs.state, d, mid), "first", "%s: no first choice left" % mid)
	var rp: Dictionary = RunSim.replay(d, rs.run_log)
	assert_eq([rp["errors"], int(rp["mismatch_at"]), str(rp["final_hash"])], [PackedStringArray(), -1, str(r["hash"])],
		"RunSim.replay reproduces the calendar run")
	assert_eq(str(RunSim.replay(d, RtLive.round_trip(rs.run_log))["final_hash"]), str(r["hash"]),
		"the log as a file (ints became floats)")


# --- the report; opt-in: whole seasons (PTD_HARNESS_SEEDS) ------------------------------------------------------------

## The report of the harness (tests/tools/season_report.gd) on series of runs: the medians per floor, the Pensum
## marks, the verdicts of the ST1 gate scaled to format 6 (decision I-3) — by default on made-up runs (the arithmetic
## and every verdict kind); with PTD_HARNESS_SEEDS=<n> on n whole seasons per gate profile (calendar, Mit Netz) and
## Am Stück (thorough), each played by the core bot without an error — the summaries and verdicts are printed (they
## are measurements: tools/season_harness.sh reports them, 09 Kap. 11.3 "Stand ST1-I").
func test_report_and_whole_seasons() -> void:
	var n: int = OS.get_environment(SEEDS_ENV).to_int()
	var series: Array = _made_up_series() if n <= 0 else _whole_seasons(n)
	for se: Dictionary in series:
		se["summary"] = Report.summary(se["runs"])
		if n > 0:
			for line: String in Report.summary_lines(se["summary"]):
				print("    %s: %s" % [str(se["profile"]) if str(se["profile"]) != "" else "binge", line])
	var verdicts: PackedStringArray = Report.band_report(series)
	if n > 0:
		for v: String in verdicts:
			print("    HARNESS-BAND: ", v)
		return
	var typical: Dictionary = (series[0] as Dictionary)["summary"]
	assert_eq([int(typical["n"]), int(typical["finale_pm"]), float(typical["deaths"])], [2, 500, 1.0], "typical")
	var f2: Dictionary = (typical["floors"] as Dictionary)[2]
	assert_eq([float(f2["play_min"]), float(f2["pflicht_min"]), int(f2["pflicht_n"]), int(f2["full_n"])],
		[35.0, 30.0, 2, 1], "floor 2: medians and marks")
	assert_eq([str(f2["fb"]), int(f2["qb_first_pm"]), float(f2["level_out"])], ["1/2", 1000, 10.0], "floor 2: bosses")
	var want: PackedStringArray = ["OUT net/typical Finale Mit Netz: 50 % (Band ≥ 80 %)",
		"ok net/typical Median-Stufe beim Abstieg, Etage 1: 7.0 (Band 0–8)",
		"ok net/typical Median-Stufe beim Abstieg, Etage 2: 10.0 (Band 6–11)",
		"OUT net/typical Pflichtweg Etage 1 (2 von 2 Läufen): 30 min (Band ≈ 20 ± 25 %)",
		"info net/typical vollständig Etage 1: von keinem Lauf erreicht",
		"ok net/typical Pflichtweg Etage 2 (2 von 2 Läufen): 30 min (Band ≈ 30 ± 25 %)",
		"OUT net/typical vollständig Etage 2 (1 von 2 Läufen): 70 min (Band 40–50)",
		"OUT net/20min Etagen per Treppe: 50 % (Band ≥ 90 %)",
		"ok net/20min Stufe beim Abstieg (min), Etage 1: 6 (Band ≥ 0)",
		"OUT net/weekend Stufe nach jedem Login ≥ Bandanfang − 2: 1 von 2 darunter (Band 0)",
		"ok net/weekend Etagen per Treppe: 50 % (Band ≥ 50 %)",
		"ok net/weekend Credits am Staffelende / typical: 60 % (Band ≥ 50 %)",
		"ok net/away2w nach der Rückkehr binnen 2 Sitzungen im Band: 1 von 1 (Band alle)",
		"OUT net/away2w Finale: 0 % (Band ≥ 60 %)"]
	for v2: String in want:
		assert_has(verdicts, v2, "verdict")
	assert_eq(verdicts.size(), want.size() + 4, "the binge series adds its Pensum lines, nothing else")


## Made-up runs: two of typical (a finale, an end), one each of 20min (a rescue), weekend, away2w and Am Stück.
func _made_up_series() -> Array:
	var t1: Dictionary = _run("finalist", 0, 1000, [_floor(1, 30, 7, "stairs", 30, 0), _floor(2, 30, 10, "stairs", 30,
		70, true)], [])
	var t2: Dictionary = _run("end", 2, 1000, [_floor(1, 30, 7, "stairs", 30, 0), _floor(2, 40, 10, "stairs", 30, 0,
		false)], [])
	var m1: Dictionary = _run("end", 1, 500, [_floor(1, 20, 6, "stairs", 0, 0), _floor(2, 20, 8, "rescue", 0, 0)], [])
	var w1: Dictionary = _run("end", 0, 600, [_floor(1, 40, 7, "stairs", 0, 0), _floor(2, 40, 8, "rescue", 0, 0)],
		[{"band": [1, 7], "level": [1, 1], "absence": 3600}, {"band": [7, 10], "level": [4, 4], "absence": 5 * DAY}])
	var a1: Dictionary = _run("end", 0, 900, [_floor(1, 30, 7, "stairs", 0, 0)],
		[{"band": [7, 10], "level": [5, 5], "absence": 14 * DAY}, {"band": [7, 10], "level": [6, 6], "absence": 3600},
		{"band": [7, 10], "level": [7, 7], "absence": 3600}])
	var b1: Dictionary = _run("end", 0, 900, [_floor(1, 25, 7, "stairs", 20, 25), _floor(2, 45, 10, "stairs", 30, 45)],
		[])
	return [{"mode": "net", "profile": "typical", "runs": [t1, t2]}, {"mode": "net", "profile": "20min", "runs": [m1]},
		{"mode": "net", "profile": "weekend", "runs": [w1]}, {"mode": "net", "profile": "away2w", "runs": [a1]},
		{"mode": "net", "profile": "", "runs": [b1]}]


func _run(result: String, deaths: int, credits: int, floors: Array, logins: Array) -> Dictionary:
	return {"seed": 0, "tempo": "calendar", "mode": "net", "profile": "typical", "strategy": "auto", "result": result,
		"deaths": deaths, "rescues": 0, "level_end": [10, 10], "play_min": 100.0, "credits_end": credits, "errors": [],
		"cast": {"ai_first": 1, "compared": 2}, "floors": floors, "logins": logins}


## A floor record: minutes played, the level at departure, how it was left, the Pensum marks (minutes; 0 = none) and
## — floor 2 — the Revier-Boss won at once and the Etagenboss (won or lost).
func _floor(f: int, minutes: int, out: int, how: String, pflicht: int, full: int, fb_won: Variant = null) -> Dictionary:
	var band: Array = [[1, 7], [7, 10]][f - 1]
	var r: Dictionary = {"floor": f, "play_sec": minutes * MIN, "explore_sec": 600, "combat_sec": 900, "combats": 10,
		"level_in": [band[0], band[0]], "level_out": [out, out], "credits_won": 100, "defeats": 0, "how": how,
		"qb": [{"outcome": "victory", "sec": 120.0}] if f == 2 else [], "fb": [], "band": band}
	if fb_won != null:
		r["fb"] = [{"outcome": "victory" if bool(fb_won) else "defeat", "sec": 200.0}]
	if pflicht > 0:
		r["pflicht_sec"] = pflicht * MIN
	if full > 0:
		r["full_sec"] = full * MIN
	return r


## n whole seasons per gate profile and Am Stück, each without an error of the core bot.
func _whole_seasons(n: int) -> Array:
	var d: GameData = real_data()
	var series: Array = []
	for prof: String in Profiles.PROFILES + PackedStringArray([""]):
		var runs: Array = []
		for seed in n:
			var opts: Dictionary = {"tempo": "binge" if prof == "" else "calendar"}
			if prof != "":
				opts["profile"] = prof
			var r: Dictionary = HarnessScript.run(d, seed, opts)
			assert_eq(r["errors"], PackedStringArray(), "%s seed %d: the core bot plays without errors" % [prof, seed])
			assert_eq(int(r["rejected"]), 0, "%s seed %d: every command legal" % [prof, seed])
			assert_true(["finalist", "end"].has(str(r["result"])), "%s seed %d: Mit Netz to the end" % [prof, seed])
			var floors: Array = r["floors"]
			for i in floors.size():
				assert_eq(int((floors[i] as Dictionary)["floor"]), i + 1, "%s seed %d: no floor skipped" % [prof, seed])
			runs.append(r)
			print("    ", Report.run_line(r))
		series.append({"mode": "net", "profile": prof, "runs": runs})
	return series
