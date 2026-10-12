extends TestCase
## 09 §11.6 test_09_death_modes (ST1-B): death Mit Netz (the medics: the safe room entered last on the floor, else the
## entrance; full heal, −10 % credits under the seven-day rule, the vest goes), Ohne Netz (out from floor 2: a studio
## guest), the dress rehearsal on floor 1 (both modes: nothing lost), death as a sleeper, the Ohne-Netz unlock (the
## first class choice or a season played to its end; the account keeps it), the finale and the titles, the Quote — and a
## real lost combat in a live season: no game over, the death rule, both verifiers agree.

const Kit := preload("res://tests/fixtures/season_core/season_core.gd")
const RtLive := preload("res://tests/fixtures/rt_live/rt_live.gd")
const ROOT: String = "user://test_09_death_modes"
const SAVES: String = "user://test_09_death_modes/saves"
const DAY: int = Kit.DAY
const DAY0: int = Kit.DAY0
const DEFEAT: BattleResult.Outcome = BattleResult.Outcome.DEFEAT
const VICTORY: BattleResult.Outcome = BattleResult.Outcome.VICTORY


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


## A season run on floor `n` (the stairs from floor 1; collapses and openings by the clock where needed), every member
## down to 1 HP, `credits` in the purse.
static func _on_floor(mode: String, n: int, credits: int = 1000) -> RunSim:
	var d: GameData = Kit.data()
	var s: RunSim = Kit.sim(d, "ssn_basis", "calendar", mode)
	for f in range(1, n):
		s.apply({"t": "descend"})
		s.apply({"t": "floor", "floor": f + 1})
	s.state.inventory.credits = credits
	for m: PartyMember in s.state.party:
		m.hp = 1
	return s


## The end of a combat as the client records it (09 §9.1): the season rules at its end, then its time — a clock
## command right away (V-17). Returns the events of the combat end.
static func _fight_ends(s: RunSim, outcome: BattleResult.Outcome) -> Array:
	var ev: Array = SeasonRules.on_combat_end(s.state, s.data, Kit.result(outcome))
	if s.state.season.result == "":
		s.apply({"t": "clock", "sec": 1})
	return ev


static func _first_safe_room(s: RunSim) -> String:
	var layout: FloorLayout = DungeonGenerator.generate(s.data.floor_def(s.state.floor_run.index), s.state.floor_run.seed)
	return str(layout.safe_room_ids[layout.safe_rooms[0]])


# --- Mit Netz --------------------------------------------------------------------------------------------------------

func test_death_mit_netz_the_medics() -> void:
	var s: RunSim = _on_floor("net", 2)
	var st: SeasonState = s.state.season
	var ev: Array = _fight_ends(s, DEFEAT)
	assert_eq(Kit.event(ev, "death"), {"kind": "death", "floor": 2, "location": "start", "credits": 100, "waived": ""},
		"no safe room visited yet: the floor entrance (V-16), −10 % credits")
	assert_eq([st.vest, st.deaths, st.fee_at, s.state.inventory.credits], [false, 1, Kit.START, 900])
	for m: PartyMember in s.state.party:
		assert_eq(m.hp, Progression.total_stats(m, s.data).values[StatBlock.Stat.HP], "full heal: " + m.id)
	var sr: String = _first_safe_room(s)
	s.apply({"t": "safe_room", "id": sr})
	s.apply({"t": "safe_room_exit"})
	assert_eq(st.last_safe_room, sr)
	ev = _fight_ends(s, DEFEAT)
	var dd: Dictionary = Kit.event(ev, "death")
	assert_eq([dd["location"], String(s.state.floor_run.location), dd["waived"], dd["credits"]], [sr, sr, "week", 0],
		"the safe room entered last; the second fee within seven days is waived")
	assert_eq([st.deaths, s.state.inventory.credits], [2, 900])
	var ev5: Array = Kit.clock_to(s, DAY0 + 5 * DAY)
	assert_eq(Kit.event(ev5, "rescue")["waived"], "week", "day 5: five days after the medics' fee")
	assert_eq(SeasonRules.respawn_point(s.state), "start", "a new floor: the medics' safe room resets")
	var ev9: Array = Kit.clock_to(s, DAY0 + 9 * DAY)
	assert_eq([Kit.event(ev9, "rescue")["credits"], st.fee_at, s.state.floor_run.index], [270, DAY0 + 9 * DAY, 4],
		"day 9: more than seven days later the rescue costs again (−30 %)")


func test_death_with_a_rescue_in_the_same_week() -> void:
	var s: RunSim = _on_floor("net", 2)
	Kit.clock_to(s, DAY0 + 4 * DAY)
	_fight_ends(s, DEFEAT)
	assert_eq(s.state.inventory.credits, 900)
	var ev: Array = Kit.clock_to(s, DAY0 + 5 * DAY)
	assert_eq([Kit.event(ev, "rescue")["waived"], s.state.inventory.credits], ["week", 900],
		"09 §7.3: höchstens eine Gebühr je 7 Tage — Rettung oder Sanitäter, was zuerst kommt")


# --- Ohne Netz, the dress rehearsal ----------------------------------------------------------------------------------

func test_death_ohne_netz_is_out_from_floor_2() -> void:
	var s: RunSim = _on_floor("no_net", 2)
	var ev: Array = SeasonRules.on_combat_end(s.state, s.data, Kit.result(DEFEAT))
	assert_eq(Kit.kinds(ev), ["out"])
	assert_eq(Kit.event(ev, "out"), {"kind": "out", "why": "fallen", "floor": 2}, "Gefallen auf Etage 2")
	assert_eq([s.state.season.result, s.state.inventory.credits], ["fallen", 1000], "raus — no fee, no medics")
	assert_eq(SeasonRules.titles(s.state, s.data), PackedStringArray(["Studiogast, gefallen auf Etage 2 (privat)"]))
	for c: Dictionary in [{"t": "room", "cell": [0, 0]}, {"t": "descend"}, {"t": "rest"}]:
		assert_eq(RunRules.command_refusal(s.state, s.data, {}, c, false, {}), "season_over", "a guest: " + str(c["t"]))
	assert_eq(SeasonRules.refusal(s.state, s.data, {"t": "sleep", "tactic": "careful"}), "season_over")
	assert_eq(SeasonRules.on_combat_end(s.state, s.data, Kit.result(DEFEAT)).size(), 0, "once out, nothing more")


func test_dress_rehearsal_costs_nothing() -> void:
	for mode: String in ["net", "no_net"]:
		var s: RunSim = _on_floor(mode, 1)
		var ev: Array = SeasonRules.on_combat_end(s.state, s.data, Kit.result(DEFEAT))
		assert_eq(Kit.event(ev, "death")["waived"], "rehearsal", mode + ": Etage 1 ist die Generalprobe (V-7)")
		var st: SeasonState = s.state.season
		assert_eq([st.result, st.vest, st.deaths, st.fee_at, s.state.inventory.credits], ["", true, 0, -1, 1000], mode)
		assert_eq(SeasonRules.quote(s.state), 0, "floor 1 counts no death")


func test_death_as_a_sleeper() -> void:
	var s: RunSim = _on_floor("net", 2)
	var sr: String = _first_safe_room(s)
	s.apply({"t": "safe_room", "id": sr})
	s.apply({"t": "safe_room_exit"})
	s.apply({"t": "sleep", "tactic": "careful"})
	var st: SeasonState = s.state.season
	assert_eq([st.asleep, st.sleep_room], [true, ""], "asleep in a corridor")
	var ev: Array = SeasonRules.on_combat_end(s.state, s.data, Kit.result(DEFEAT))   # ST1-G: a lost patrol
	assert_eq([Kit.event(ev, "death")["location"], st.sleep_room, s.state.inventory.credits], [sr, sr, 900],
		"09 §7.3: Tod als Schläfer — wie Tod; the sleeper sleeps on in the medics' safe room")
	var o: RunSim = _on_floor("no_net", 3)
	o.apply({"t": "sleep", "tactic": "attack"})
	SeasonRules.on_combat_end(o.state, o.data, Kit.result(DEFEAT))
	assert_eq([o.state.season.result, o.state.season.result_floor], ["fallen", 3], "Ohne Netz: raus")


# --- the unlock, the finale, the titles, the Quote -------------------------------------------------------------------

func test_ohne_netz_unlock() -> void:
	var s: RunSim = _on_floor("net", 1)
	assert_false(SeasonRules.unlocks_no_net(s.state))
	s.state.member("kai").class_id = "cls_kai_wrecker"
	assert_true(SeasonRules.unlocks_no_net(s.state), "the first class choice (the Recall, V-7)")
	assert_false(bool(Save.career().get("no_net", false)))
	assert_false(Game.start_season(1, "ssn_basis", {"mode": "no_net", "now": Kit.START}), "locked")
	assert_true(Game.start_season(1, "ssn_basis", {"now": Kit.START, "tz_sec": 0, "seed": 3}))
	assert_eq(int(Save.career().get("seasons", 0)), 1, "the career counts the season")
	Game.state.member("kai").class_id = "cls_kai_wrecker"
	Game._season_autosave()
	assert_true(bool(Save.career().get("no_net", false)), "the account keeps the unlock (09 §2.8)")
	assert_true(Game.start_season(2, "ssn_basis", {"mode": "no_net", "now": Kit.START, "tz_sec": 0, "seed": 4}))
	assert_eq([Game.state.season.mode, Game.state.season.number], ["no_net", 2])


func test_finale_titles_and_the_quote() -> void:
	var d: GameData = Kit.data()
	var s: RunSim = Kit.sim(d)
	Kit.put_on_floor(s, 6)
	var st: SeasonState = s.state.season
	st.stairs = 5
	st.qbosses = 4
	s.state.show.followers = 25000
	s.state.show.achievements = PackedStringArray(["ach_a", "ach_b"])
	SeasonRules.on_combat_end(s.state, d, Kit.result(VICTORY, d.floor_def(6).quarter_boss))
	assert_eq(st.qbosses, 5)
	var ev: Array = SeasonRules.on_combat_end(s.state, d, Kit.result(VICTORY, d.floor_def(6).floor_boss))
	assert_eq(Kit.event(ev, "finale"), {"kind": "finale", "floor": 6}, "das Große Finale (09 §2.7)")
	assert_eq([st.result, st.fbosses, st.finale_at], ["finalist", 1, Kit.START])
	assert_eq(SeasonRules.titles(s.state, d), PackedStringArray(["Finalist:in der Staffel 1 (privat)",
		"Weiße Weste (privat)"]), "privat: with the suffix (V-11)")
	assert_eq(SeasonRules.quote(s.state), 5 * 1000 + 5 * 200 + 500 + 3000 + 2 * 50 + 2000,
		"09 §2.7: the Quote (followers capped at 20 000)")
	assert_eq(SeasonRules.rank_key(s.state), [-SeasonRules.quote(s.state), Kit.START, 1 << 62])
	st.vest = false
	s.state.member("kai").professions = {"prf_lab": 300}
	assert_eq(SeasonRules.titles(s.state, d), PackedStringArray(["Finalist:in der Staffel 1 (privat)",
		"Legende: Labor (privat)"]))
	var o: RunSim = Kit.sim(d, "ssn_basis", "calendar", "no_net")
	Kit.put_on_floor(o, 6)
	SeasonRules.on_combat_end(o.state, d, Kit.result(VICTORY, d.floor_def(6).floor_boss))
	assert_eq(SeasonRules.titles(o.state, d), PackedStringArray(["Finalist:in der Staffel 1 (privat)",
		"Überlebende:r — Ohne Netz (privat)"]))
	Kit.put_on_floor(o, 5)
	o.state.season.result = ""
	SeasonRules.on_combat_end(o.state, d, Kit.result(VICTORY, d.floor_def(5).floor_boss))
	assert_eq(o.state.season.result, "", "an Etagenboss before the last floor is no finale")


# --- a real lost combat in a live season -----------------------------------------------------------------------------

func test_lost_combat_in_a_live_season() -> void:
	assert_true(Game.start_season(1, "ssn_basis", {"now": Kit.START, "tz_sec": 0, "seed": 9}))
	var sr: String = str((DB.floor_def(1).layout.get("safe_rooms", [{}]) as Array)[0].get("id", ""))
	Game.enter_safe_room(sr)
	Game.leave_safe_room()
	var overs: int = int(Game.state.show.stats.get("game_overs", 0))
	var out: Dictionary = RtLive.autopilot_fight(DB.floor_def(1).floor_boss, BattleSetup.Advantage.NORMAL, "st1b_boss")
	assert_false(out.is_empty(), "the Rattenkönigin at level 1")
	assert_eq(int((out["result"] as BattleResult).outcome), DEFEAT, "a lost combat")
	var st: SeasonState = Game.state.season
	assert_eq([st.result, st.deaths, st.vest, String(Game.state.floor_run.location)], ["", 0, true, sr],
		"the dress rehearsal: the medics bring the party to the safe room entered last")
	assert_eq(int(Game.state.show.stats.get("game_overs", 0)), overs, "no game over in a season (09 §7.1)")
	for m: PartyMember in Game.state.party:
		assert_gt(m.hp, 0, "healed: " + m.id)
	assert_true(Save.has_save(1), "the save after the combat")
	var live: String = StateHash.of(Game.state)
	var a: Dictionary = Game.replay_log(Game.run_log, Game.sim.tick())
	assert_eq([a["errors"], a["final_hash"]], [PackedStringArray(), live], "Game.replay_log ≡ live")
	var r: Dictionary = RunSim.replay(DB.data, Game.run_log)
	assert_eq(r["errors"], PackedStringArray(), "RunSim.replay accepts it (the Show part is Game.replay_log's, 05 §11.4)")
