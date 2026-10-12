extends TestCase
## 09 §11.6 test_09_cast_sim (ST1-F): the AI cast. Determinism per seed (the same season seed → the same roster and
## play, however the time is cut — one jump or many small ones; a season session with the cast in both verifiers), the
## calibration bands of 09 §4.2 over 200 seeds (Mit Netz and Ohne Netz, the Akt-3 format, the reference human of the
## kit), Am Stück the cast follows the candidate (a step per 25 s of exploration, never more than one floor ahead, the
## old floor played to its end at the descent, the countdown's end as the collapse), "übernommen", the events (first
## ascents, collapses, out, Etagenboss, finale, record; the ticker; the breaking news and their lines; their pacing in
## the live game), the counter, the ranking, the labelling ("KI" everywhere), the guest appearance (the Helfer:in, the
## Pechvogel — never in a boss fight), the start block (cast_mismatch, {} = a season without AI candidates) and the
## name catalog.

const Kit := preload("res://tests/fixtures/season_core/season_core.gd")
const CastKit := preload("res://tests/fixtures/season_cast/cast_kit.gd")
const CastModel := preload("res://core/season/cast_model.gd")
const RtLive := preload("res://tests/fixtures/rt_live/rt_live.gd")
const GameReplayScript := preload("res://autoload/game_replay.gd")
const IpWords := preload("res://core/data/validators/ip_words.gd")
const DAY: int = Kit.DAY
const DAY0: int = Kit.DAY0
const HOUR: int = 3600
const NO_TIME: int = CastMember.NO_TIME
const CALIB_SEEDS: int = 200
## The calibration of 09 §4.2 in % of the AI places (Akt 3, 18 floors): "≈ x" is x ± 6 points, a range as written.
## Mit Netz the weiße Weste after floors 3 / 9 / the finale, Ohne Netz still in after floors 3 / 9; the finale won; the
## first AI on a floor before the first human.
const BANDS: Dictionary = {
	"net": {"vest3": [64, 76], "vest9": [34, 46], "final_vest": [20, 25], "finalists": [35, 45], "ai_first": [44, 56]},
	"no_net": {"in3": [74, 86], "in9": [39, 51], "finalists": [15, 25], "ai_first": [44, 56]},
}
## The breaking-news tags (CastSim.news) and the answers to the candidate's own commands (Game.CAST_ANSWER_TAGS).
const NEWS_TAGS: PackedStringArray = ["cast_intro", "cast_first", "cast_first_you", "cast_out", "cast_leave",
	"cast_fboss", "cast_finale", "cast_record", "cast_collapse", "cast_collapse_out", "cast_hired", "cast_help",
	"cast_helped", "cast_guest_end"]
## Names and words of other shows and Graf Mopsula's rules that no invented name may carry (lower-case substrings).
const NAME_WORDS: PackedStringArray = ["carl", "donut", "mordecai", "katia", "borant", "odette", "crawler", "fan-box",
	"fanbox", "prinz", "könig", "krone", "majest", "graf", "mops", "kai"]


func after_each() -> void:
	if Game.combat != null:
		Game.end_combat()
	Game.state = null
	Game.run_log = null
	Game.sim = null
	Game.mode = &"campaign"
	Game.timer_running = false
	Game.in_battle = false
	Save._journal_close()


## A season of `def_id` with its AI cast on a bare state (no floor yet): the start command of the kit.
static func _season(d: GameData, seed: int, mode: String = "net", tempo: String = "calendar",
		def_id: String = "ssn_akt3") -> GameState:
	var st: GameState = GameState.create_new(d, 0, "Kai", seed, &"prime")
	RunRules.apply_season(st, d, CastKit.start_cmd(d, def_id, tempo, mode))
	return st


## A calendar season of the Akt-3 format played through with the kit's reference human (its arrivals by the stairs,
## a catch-up and flush at each and at the end): {"st": the state (cast written back), "events": every event flushed}.
static func _reference_season(d: GameData, seed: int, mode: String) -> Dictionary:
	var st: GameState = GameState.create_new(d, 0, "Kai", seed, &"prime")
	var format: int = d.season_def("ssn_akt3").format
	var arr: PackedInt32Array = CastKit.human_arrivals(seed, format)
	RunRules.apply_season(st, d, CastKit.start_cmd(d, "ssn_akt3", "calendar", mode, DAY0 + arr[0]))
	var m: CastModel = CastKit.model(st, d)
	var events: Array[CastEvent] = []
	for f in range(2, format + 1):
		if arr[f - 1] == NO_TIME:
			continue
		m.catch_up(CastModel.hour_of(arr[f - 1]) + 1, arr[f - 1])
		events.append_array(m.flush(arr[f - 1]))
		m.human_arrives(f, arr[f - 1], true)
		m.hf = maxi(m.hf, f)
	var end_t: int = SeasonClock.end_day(format) * DAY + HOUR
	m.catch_up(CastModel.hour_of(end_t), end_t)
	events.append_array(m.flush(end_t))
	m.write(st)
	return {"st": st, "events": events}


static func _kinds(events: Array[CastEvent]) -> Array[String]:
	var out: Array[String] = []
	for e: CastEvent in events:
		if not out.has(e.kind):
			out.append(e.kind)
	return out


## The cast events among explore events (SEASON {"kind": "cast"}): their kinds ("ev").
static func _cast_kinds(events: Array) -> Array[String]:
	var out: Array[String] = []
	for e: Variant in events:
		if e is ExploreEvent and (e as ExploreEvent).type == ExploreEvent.Type.SEASON \
				and str((e as ExploreEvent).data.get("kind", "")) == "cast":
			out.append(str((e as ExploreEvent).data.get("ev", "")))
	return out


static func _first_safe_room(d: GameData, st: GameState) -> String:
	var layout: FloorLayout = DungeonGenerator.generate(d.floor_def(st.floor_run.index), st.floor_run.seed)
	return str(layout.safe_room_ids[layout.safe_rooms[0]])


# --- determinism ----------------------------------------------------------------------------------------------------

func test_the_same_seed_is_the_same_cast_however_the_time_is_cut() -> void:
	var d: GameData = real_data()
	var a: GameState = _season(d, 7)
	var b: GameState = _season(d, 7)
	assert_eq(a.season.cast, b.season.cast, "the same season seed: the same roster")
	assert_eq(StateHash.of(a), StateHash.of(b))
	var other: GameState = _season(d, 8)
	assert_ne(str(other.season.cast["roster"]), str(a.season.cast["roster"]), "another seed: another cast")
	var end_t: int = 30 * DAY + 5 * HOUR
	var one: CastModel = CastKit.model(a, d)
	one.catch_up(CastModel.hour_of(end_t), end_t)
	one.flush(end_t)
	var steps: CastModel = CastKit.model(a, d)
	var t: int = steps.h * HOUR
	var cuts: int = 0
	while t < end_t:
		t = mini(end_t, t + 7 * HOUR + 1234)
		steps.catch_up(CastModel.hour_of(t), t)
		steps.flush(t)
		cuts += 1
	assert_gt(cuts, 90, "many small steps")
	var moved: int = 0
	for p in one.places:
		assert_eq(steps.members[p].state_text(), one.members[p].state_text(), "place %d: one jump or many" % p)
		moved += 1 if one.members[p].fl > 1 else 0
	assert_gt(moved, 80, "after 30 days the cast is under way")
	assert_eq([steps.first_who, steps.first_t, steps.ai_first], [one.first_who, one.first_t, one.ai_first],
		"the same first ascents")
	var c: GameState = _season(d, 7)
	CastKit.model(c, d)
	RunRules.apply_season(c, d, {"t": "clock", "sec": 7 * DAY})
	RunRules.apply_season(c, d, {"t": "clock", "sec": 7 * DAY})
	var e: GameState = _season(d, 7)
	for i in 14:
		RunRules.apply_season(e, d, {"t": "clock", "sec": DAY})
	assert_eq(str(e.season.cast["state"]), str(c.season.cast["state"]), "two clocks of 7 days or 14 of one day")


func test_a_season_session_with_the_cast_in_both_verifiers() -> void:
	var d: GameData = Kit.data(6)
	var s: RunSim = CastKit.sim(d, "ssn_basis", "calendar", "net", 61)
	s.apply({"t": "clock", "sec": 600})
	var need: int = CastSim.in_need(s.state, d)
	assert_gt(need, 0, "a Pechvogel in need on floor 1")
	s.apply({"t": "cast", "op": "help", "who": need})
	s.apply({"t": "descend"})
	s.apply({"t": "floor", "floor": 2})                              # the guest stays behind
	Kit.clock_to(s, DAY0 + 2 * DAY + 600)                             # floor 1 collapses below the candidate
	s.apply({"t": "season", "v": 1, "op": "tempo"})                   # Am Stück: the cast follows from here
	s.step(9000)
	s.apply({"t": "descend"})
	s.apply({"t": "floor", "floor": 3})
	s.step(3000)
	s.apply({"t": "sleep", "tactic": "careful"})                      # the logout ends the session
	assert_eq(s.rejected_cmds, [] as Array[Dictionary], "every command accepted")
	var census: Dictionary = CastSim.census(s.state, d)
	assert_eq(int(census["ai"]), 99)
	assert_ne(int((census["first_who"] as PackedInt32Array)[1]), -1, "floor 2 has its first ascent")
	assert_gt(CastSim.last_seq(s.state), 0, "the cast had news")
	var live: String = StateHash.of(s.state)
	var r: Dictionary = RunSim.replay(s.data, s.run_log)
	assert_eq([r["errors"], r["mismatch_at"], r["final_hash"]], [PackedStringArray(), -1, live], "RunSim.replay")
	var file: RunLog = RtLive.round_trip(s.run_log)
	assert_eq(RunSim.replay(s.data, file)["final_hash"], live, "the log as a file (ints became floats)")
	var saved: GameData = DB.data
	DB.data = s.data
	var gr: RefCounted = GameReplayScript.new(Game)
	var g: Dictionary = gr.call("run", s.run_log, -1)
	DB.data = saved
	assert_eq(g["errors"], PackedStringArray(), "Game.replay_log accepts every entry")
	var shown: GameState = gr.get("_final_state")
	assert_not_null(shown)
	if shown != null:
		assert_eq(shown.season.cast, s.state.season.cast, "Game.replay_log: the same cast")
		assert_eq(shown.season.to_dict(), s.state.season.to_dict(), "the season block")


# --- calibration (09 §4.2) ------------------------------------------------------------------------------------------

func test_calibration_bands_over_200_seeds() -> void:
	var d: GameData = real_data()
	var st: GameState = GameState.create_new(d, 0, "Kai", 1, &"prime")
	for mode: String in ["net", "no_net"]:
		var sums: Dictionary = {}
		for seed in range(1, CALIB_SEEDS + 1):
			var r: Dictionary = CastKit.calibrate(d, st, seed, mode)
			for k: String in r.keys():
				sums[k] = int(sums.get(k, 0)) + int(r[k])
		var ai: float = float(sums["ai"])
		var pct: Dictionary = {}
		for k: String in ["vest3", "vest9", "final_vest", "in3", "in9", "finalists"]:
			pct[k] = 100.0 * float(sums[k]) / ai
		pct["ai_first"] = 100.0 * float(sums["ai_first"]) / float(sums["floors"])
		var bands: Dictionary = BANDS[mode]
		var shown: PackedStringArray = []
		for k: String in bands.keys():
			var band: Array = bands[k]
			assert_between(float(pct[k]), float(band[0]), float(band[1]), "09 §4.2 %s: %s" % [mode, k])
			shown.append("%s %.1f %% (%d–%d)" % [k, float(pct[k]), int(band[0]), int(band[1])])
		print("[CAST CALIBRATION] %s, %d seeds: %s" % ["Mit Netz" if mode == "net" else "Ohne Netz", CALIB_SEEDS,
			", ".join(shown)])


# --- Am Stück: the cast follows the candidate (09 §4.2, V-2) ----------------------------------------------------------

func test_binge_the_cast_follows_the_candidate() -> void:
	var d: GameData = Kit.data(6)
	var s: RunSim = CastKit.sim(d, "ssn_basis", "binge", "net", 67)
	s.state.floor_run.timer_started = true
	s.step(7500)                                                      # 250 s of exploration
	var h0: int = JsonUtil.to_int(s.state.season.cast["h"])
	for i in 4:
		s.step(750)
		assert_eq(JsonUtil.to_int(s.state.season.cast["h"]) - h0, i + 1, "a step per 25 s of exploration")
	s.step(19500)                                                     # 1 000 s on floor 1
	var c: Dictionary = CastSim.census(s.state, d)
	var on: PackedInt32Array = c["on_floor"]
	assert_gt(on[1], 0, "some came down to floor 2")
	for f in range(3, 7):
		assert_eq(on[f - 1], 0, "nobody more than one floor ahead (floor %d)" % f)
	assert_eq((c["collapse"] as PackedInt32Array)[0], NO_TIME, "floor 1 stands while the candidate plays it")
	var left: int = s.state.floor_run.time_left_ticks
	var t: int = CastSim.now(s.state)
	s.apply({"t": "descend"})
	s.apply({"t": "floor", "floor": 2})
	s.state.floor_run.timer_started = true
	c = CastSim.census(s.state, d)
	on = c["on_floor"]
	assert_eq(on[0], 0, "the old floor played to its end for everyone")
	assert_eq((c["collapse"] as PackedInt32Array)[0], t + left * SeasonClock.BINGE_FACTOR / FloorRun.TICKS_PER_SEC,
		"its collapse: the end of the candidate's countdown")
	for f in range(4, 7):
		assert_eq(on[f - 1], 0, "one floor ahead at most (floor %d)" % f)
	assert_true(int((c["first_who"] as PackedInt32Array)[1]) >= 0, "floor 2 has its first ascent")
	s.step(SeasonClock.binge_ticks(2) + 30)                           # the countdown of floor 2 ends: its collapse
	assert_eq(s.state.floor_run.index, 3, "the candidate rescued to floor 3")
	s.apply({"t": "safe_room_exit"})
	s.step(30)
	c = CastSim.census(s.state, d)
	on = c["on_floor"]
	assert_eq(on[1], 0, "the collapse caught the cast on floor 2 like the candidate")
	assert_ne((c["collapse"] as PackedInt32Array)[1], NO_TIME)
	assert_eq(on[4] + on[5], 0, "still one floor ahead at most")
	assert_eq(s.rejected_cmds, [] as Array[Dictionary])


# --- übernommen (09 §2.2, §4.2) ------------------------------------------------------------------------------------

func test_a_candidate_who_leaves_is_taken_over_by_the_ai() -> void:
	var d: GameData = Kit.data(6)
	var s: RunSim = CastKit.sim(d, "ssn_basis", "calendar", "net", 71)
	s.apply({"t": "descend"})
	s.apply({"t": "floor", "floor": 2})
	Kit.clock_to(s, DAY0 + 3 * HOUR)
	var before: Dictionary = CastSim.member_view(s.state, d, 0)
	assert_eq([before["ai"], before["taken"], before["label"]], [false, false, s.state.player_name])
	var ev: Array = s.apply({"t": "season", "v": 1, "op": "leave"})
	assert_has(_cast_kinds(ev), "leave", "the news: the AI takes the place over")
	var v: Dictionary = CastSim.member_view(s.state, d, 0)
	assert_eq([v["ai"], v["taken"], v["skill"], v["floor"], v["label"]], [true, true, 55, 2,
		s.state.player_name + " (KI, übernommen)"], "09 §2.2: played on with skill 55, labelled")
	var news: Array[Dictionary] = CastSim.news(s.state, d, 0)
	var tags: Array = []
	for n: Dictionary in news:
		tags.append(n["tag"])
	assert_has(tags, "cast_leave")
	var m: CastModel = CastKit.model(s.state, d)
	var fl: int = m.members[0].fl
	var wk: int = m.members[0].wk
	m.catch_up(CastModel.hour_of(10 * DAY), 10 * DAY)
	assert_true(m.members[0].fl > fl or m.members[0].wk > wk, "the AI plays the place on")
	assert_eq(CastSim.counter(s.state, d)["of"], 100)


# --- events, ticker, news -------------------------------------------------------------------------------------------

func test_events_the_ticker_and_the_news() -> void:
	var d: GameData = real_data()
	for mode: String in ["net", "no_net"]:
		var run: Dictionary = _reference_season(d, 11, mode)
		var st: GameState = run["st"]
		var events: Array[CastEvent] = run["events"]
		var kinds: Array[String] = _kinds(events)
		for k: String in ["first", "fboss", "finale", "record"]:
			assert_has(kinds, k, "%s: the season has a %s" % [mode, k])
		if mode == "no_net":
			assert_has(kinds, "out", "Ohne Netz: candidates are out")
		var last_seq: int = 0
		for e: CastEvent in events:
			assert_gt(e.seq, last_seq, "numbered in order")
			last_seq = e.seq
			assert_true(e.importance() >= CastEvent.TICKER_MIN, "only news leave the model: " + e.kind)
			assert_false(["descend", "death", "rescue", "end"].has(e.kind), "routine events stay inside")
		assert_eq(CastSim.last_seq(st), last_seq)
		var ticker: Array[Dictionary] = CastSim.ticker(st, d, 24 * 200)
		assert_between(ticker.size(), 1, CastModel.TICKER_MAX, "the ticker keeps the newest")
		assert_eq(int(ticker.back()["seq"]), last_seq)
		var news: Array[Dictionary] = CastSim.news(st, d, 0)
		for i in range(1, news.size()):
			var a: Dictionary = news[i - 1]
			var b: Dictionary = news[i]
			assert_true(int(a["importance"]) > int(b["importance"]) or (int(a["importance"]) == int(b["importance"])
				and int(a["seq"]) > int(b["seq"])), "wichtige zuerst, then the newest")
		for n: Dictionary in news:
			var who: int = int(n["who"])
			if who >= 1:
				assert_true(str(n["label"]).ends_with(" (KI)"), "an AI candidate in the news is labelled")
			if n["kind"] == "collapse":
				assert_eq(n["tag"], "cast_collapse_out" if mode == "no_net" else "cast_collapse")
		var tag_of: Dictionary = {}
		for n: Dictionary in news:
			tag_of[int(n["seq"])] = str(n["tag"])
		var first_who: PackedInt32Array = CastSim.census(st, d)["first_who"]
		var firsts: int = 0
		for e: CastEvent in events:
			if e.kind != "first":
				continue
			firsts += 1
			assert_eq(first_who[e.at - 1], e.who, "one first ascent per floor")
			if tag_of.has(e.seq):
				assert_eq(tag_of[e.seq], "cast_first_you" if e.who == 0 else "cast_first", "the first ascent's line")
		assert_eq(firsts, 17, "every floor 2..18 has exactly one first ascent")
	for mode: String in ["net", "no_net"]:                           # a collapse catches two places: its summary
		var st2: GameState = _season(d, 19, mode)
		var m: CastModel = CastKit.model(st2, d)
		var c: int = m.ct[1]
		for p: int in [7, 8]:
			m.members[p].fl = 2
			m.members[p].wk = 0
			m.members[p].t = CastModel.hour_of(c)
		m.run(m.members[7], CastModel.hour_of(c) + 1, c, -1)
		m.run(m.members[8], CastModel.hour_of(c) + 1, c, -1)
		var got: Array[CastEvent] = m.flush(c)
		m.write(st2)
		var sums: Array = []
		for e: CastEvent in got:
			if e.kind == "collapse":
				sums.append([e.at, e.t, e.n, e.m])
		assert_eq(sums, [[2, c, 0, 2]] if mode == "no_net" else [[2, c, 2, 0]], mode + ": one summary per collapse")
		var tags: Array = []
		for n: Dictionary in CastSim.news(st2, d, 0):
			if n["kind"] == "collapse":
				tags.append([n["tag"], n["ctx"]["count"]])
		assert_eq(tags, [["cast_collapse_out", 2]] if mode == "no_net" else [["cast_collapse", 2]])
		assert_eq([m.members[7].fl, m.members[7].is_out()], [2, true] if mode == "no_net" else [3, false],
			"Ohne Netz buried, Mit Netz rescued onto the next floor")
	var re: RegEx = RegEx.create_from_string("\\{([a-z_]+)\\}")
	for tag: String in NEWS_TAGS:
		var lines: Array[ModLineDef] = d.mod_lines(tag)
		assert_gt(lines.size(), 0, "a M.O.D. line for " + tag)
		for line: ModLineDef in lines:
			assert_eq(line.voice, "mod", line.id)
			for m: RegExMatch in re.search_all(line.text):
				assert_has(["cand", "floor", "count"], m.get_string(1), "placeholder in " + line.id)


func test_breaking_news_in_the_live_game() -> void:
	assert_true(Game.start_season(0, "ssn_basis", {"now": Kit.START, "tz_sec": 0, "seed": 73}))
	assert_true(CastSim.has_cast(Game.state), "the live start draws the cast")
	var said: Array[String] = []
	var spy: Callable = func(_text: String, _voice: StringName, tag: String, _blocking: bool) -> void:
		if tag.begins_with("cast_"):
			said.append(tag)
	Events.mod_said.connect(spy)
	assert_true(Game.season_clock(DAY))                               # a day of the cast: first ascents, a record
	assert_gt(CastSim.news(Game.state, DB.data, 0).size(), 0, "news to tell")
	Game.state.play_time_sec = 1000.0
	Game._cast_news()
	assert_eq(said, ["cast_intro"] as Array[String], "on floor 1 the introduction comes first")
	Game._cast_news()
	Game.state.play_time_sec += 599.0
	Game._cast_news()
	assert_eq(said.size(), 1, "at most one breaking news per 10 min of play time")
	Game.state.play_time_sec += 1.0
	Game._cast_news()
	assert_eq(said.size(), 2)
	var top: Dictionary = CastSim.news(Game.state, DB.data, 0)[0]
	assert_eq(said[1], str(top["tag"]), "the most important news first")
	Game.state.play_time_sec += 600.0
	Game._cast_news()
	assert_eq(said.size(), 2, "the rest stays in the ticker")
	var m: CastModel = CastKit.model(Game.state, DB.data)               # a new leader of the AI cast: news
	m.note(CastEvent.make(CastSim.now(Game.state), "record", 5, 1))
	m.write(Game.state)
	Game.in_battle = true
	Game.state.play_time_sec += 600.0
	Game._cast_news()
	assert_eq(said.size(), 2, "never in a combat")
	Game.in_battle = false
	Game._cast_news()
	assert_eq(said.size(), 3, "after the combat")
	Events.mod_said.disconnect(spy)


# --- counter, ranking, labels ---------------------------------------------------------------------------------------

func test_the_counter_the_ranking_and_the_labels() -> void:
	var d: GameData = real_data()
	for mode: String in ["net", "no_net"]:
		var run: Dictionary = _reference_season(d, 13, mode)
		var st: GameState = run["st"]
		var census: Dictionary = CastSim.census(st, d)
		var cnt: Dictionary = CastSim.counter(st, d)
		if mode == "net":
			assert_eq([cnt["kind"], cnt["label"], cnt["of"]], ["vest", "Weiße Weste", 100])
			assert_eq(cnt["n"], int(census["vest"]) + (1 if st.season.vest else 0), "the AI with the vest + the human")
		else:
			assert_eq([cnt["kind"], cnt["label"], cnt["of"]], ["in", "Noch dabei", 100])
			assert_eq(cnt["n"], int(census["in"]) + 1, "the AI still in + the human")
		var ranking: Array[Dictionary] = CastSim.ranking(st, d)
		assert_eq(ranking.size(), 100, "privately every place (V-11)")
		var names: Dictionary = {}
		for i in ranking.size():
			var row: Dictionary = ranking[i]
			assert_eq(int(row["rank"]), i + 1)
			if i > 0:
				assert_true(int(ranking[i - 1]["quote"]) >= int(row["quote"]), "sorted by the Quote")
			if bool(row["ai"]):
				assert_true(str(row["label"]).ends_with(" (KI)"), "09 S-6: every AI place labelled")
				names[str(row["label"])] = true
			else:
				assert_eq(str(row["label"]), st.player_name)
		assert_eq(names.size(), 99, "99 different names")
		for row: Dictionary in ranking:
			if int(row["place"]) == 0:
				assert_eq(CastSim.rank_of(st, d, 0), int(row["rank"]), "Platz n von 100")
		var v: Dictionary = CastSim.member_view(st, d, 5)
		assert_true(bool(v["ai"]) and str(v["label"]).ends_with(" (KI)"))
		for k: String in ["profile_name", "job", "hobby", "species", "class"]:
			assert_ne(str(v[k]), "", "the view has its " + k)
		assert_eq(CastSim.label(st, d, 5), v["label"])
		assert_eq(CastSim.label(st, d, 0), st.player_name)
	var none: GameState = GameState.create_new(d, 0, "Kai", 1, &"prime")
	RunRules.apply_season(none, d, Kit.start_cmd(d, "ssn_akt3"))
	assert_eq([CastSim.counter(none, d)["n"], CastSim.counter(none, d)["of"]], [1, 1], "no cast: the candidate alone")
	assert_eq(CastSim.ranking(none, d).size(), 0)


# --- the guest appearance (09 §4.3) — never in a boss fight ---------------------------------------------------------

func test_a_hired_helper_comes_along_for_three_combats_never_a_boss_fight() -> void:
	var d: GameData = Kit.data(6)
	var s: RunSim = CastKit.sim(d, "ssn_basis", "calendar", "net", 79)
	var st: GameState = s.state
	var layout: FloorLayout = DungeonGenerator.generate(d.floor_def(1), st.floor_run.seed)
	s.apply({"t": "room", "cell": [layout.start.x, layout.start.y]})
	var room: String = _first_safe_room(d, st)
	var helpers: Array[int] = []
	for p in range(1, 100):
		if str(CastSim.member_view(st, d, p)["profile"]) == "helper":
			helpers.append(p)
	assert_eq(helpers.size(), 15, "Helfer:in 15 % of the 99 AI places")
	assert_eq(CastSim.refusal(st, d, {"t": "cast", "op": "hire", "who": helpers[0]}), "not_in_safe_room")
	var helper: int = -1
	for visit in 16:
		s.apply({"t": "safe_room", "id": room})
		var guests: Array[int] = CastSim.safe_room_guests(st, d)
		assert_between(guests.size(), 1, CastSim.SAFE_ROOM_SEATS)
		assert_eq(guests, CastSim.safe_room_guests(st, d), "deterministic per visit")
		for g: int in guests:
			assert_eq(int(CastSim.member_view(st, d, g)["floor"]), 1, "an AI candidate of the candidate's floor")
			if helpers.has(g):
				helper = g
			else:
				assert_eq(CastSim.refusal(st, d, {"t": "cast", "op": "hire", "who": g}), "not_helper")
		if helper >= 0:
			break
		s.apply({"t": "safe_room_exit"})
	assert_ne(helper, -1, "a Helfer:in sits in a safe room")
	var absent: int = helpers[0] if helpers[0] != helper else helpers[1]
	if not CastSim.safe_room_guests(st, d).has(absent):
		assert_eq(CastSim.refusal(st, d, {"t": "cast", "op": "hire", "who": absent}), "not_here")
	assert_eq(CastSim.refusal(st, d, {"t": "cast", "op": "hire", "who": 0}), "unknown_place", "a human place")
	assert_eq(CastSim.refusal(st, d, {"t": "cast", "op": "trade", "who": helper}), "trade_unavailable", "ST1-E")
	st.inventory.credits = CastSim.hire_cost(st) - 1
	assert_eq(CastSim.refusal(st, d, {"t": "cast", "op": "hire", "who": helper}), "no_credits")
	st.inventory.credits = 1000
	var ev: Array = s.apply({"t": "cast", "op": "hire", "who": helper})
	assert_eq(s.rejected_cmds, [] as Array[Dictionary])
	assert_has(_cast_kinds(ev), "hired")
	assert_eq(st.inventory.credits, 1000 - CastSim.hire_cost(st), "paid with credits (no favour yet)")
	assert_eq(CastSim.guest(st, d), {"who": helper, "label": CastSim.label(st, d, helper), "kind": "hire",
		"left": CastSim.HIRE_FIGHTS})
	assert_eq(CastSim.refusal(st, d, {"t": "cast", "op": "hire", "who": helper}), "guest_active")
	assert_eq(CastSim.guest_for_combat(st, d, true), {}, "09 §4.5 Nr. 3: never in a boss fight")
	var unit: Dictionary = CastSim.guest_for_combat(st, d, false)
	assert_eq([unit["who"], unit["tactic"], unit["kind"]], [helper, "support", "hire"])
	assert_between(int(unit["level"]), 1, 7, "the level of its band")
	var boss: BattleResult = Kit.result(BattleResult.Outcome.VICTORY, "enc_f1_boss")
	boss.is_boss = true
	assert_eq(CastSim.on_combat_end(st, d, boss).size(), 0, "a boss fight never counts")
	assert_eq(CastSim.guest(st, d)["left"], CastSim.HIRE_FIGHTS)
	var fight: BattleResult = Kit.result(BattleResult.Outcome.VICTORY)
	assert_eq(CastSim.on_combat_end(st, d, fight).size(), 0)
	assert_eq(CastSim.on_combat_end(st, d, Kit.result(BattleResult.Outcome.DEFEAT)).size(), 0)
	assert_eq(_cast_kinds(CastSim.on_combat_end(st, d, fight)), ["guest_end"] as Array[String], "three combats")
	assert_eq(CastSim.guest(st, d), {})
	assert_eq(CastSim.guest_for_combat(st, d, false), {})


func test_the_pechvogel_in_need_and_the_favour() -> void:
	var d: GameData = Kit.data(6)
	var s: RunSim = CastKit.sim(d, "ssn_basis", "calendar", "net", 83)
	var st: GameState = s.state
	var who: int = CastSim.in_need(st, d)
	assert_ne(who, -1, "a Pechvogel on floor 1")
	assert_eq([CastSim.member_view(st, d, who)["profile"], CastSim.member_view(st, d, who)["floor"]], ["unlucky", 1])
	assert_eq(CastSim.in_need(st, d), who, "deterministic")
	var other: int = 1 if who != 1 else 2
	assert_eq(CastSim.refusal(st, d, {"t": "cast", "op": "help", "who": other}), "not_in_need")
	s.apply({"t": "safe_room", "id": _first_safe_room(d, st)})
	assert_eq(CastSim.refusal(st, d, {"t": "cast", "op": "help", "who": who}), "in_safe_room")
	s.apply({"t": "safe_room_exit"})
	var ev: Array = s.apply({"t": "cast", "op": "help", "who": who})
	assert_eq(s.rejected_cmds, [] as Array[Dictionary])
	assert_has(_cast_kinds(ev), "help")
	assert_eq(CastSim.guest(st, d)["kind"], "help")
	assert_eq(CastSim.guest_for_combat(st, d, true), {}, "never in a boss fight")
	var boss: BattleResult = Kit.result(BattleResult.Outcome.VICTORY)
	boss.is_boss = true
	assert_eq(CastSim.on_combat_end(st, d, boss).size(), 0)
	var followers: int = st.show.followers
	var kinds: Array[String] = _cast_kinds(CastSim.on_combat_end(st, d, Kit.result(BattleResult.Outcome.VICTORY)))
	assert_eq(kinds, ["helped", "guest_end"] as Array[String])
	assert_eq(st.show.followers, followers + CastSim.HELP_FOLLOWERS + CastSim.HELP_FOLLOWERS_FLOOR, "followers")
	assert_eq(CastSim.favors(st, d), 1, "a favour")
	assert_eq(CastSim.in_need(st, d), -1, "helped on this floor")
	var helper: int = -1
	for p in range(1, 100):
		if helper < 0 and str(CastSim.member_view(st, d, p)["profile"]) == "helper":
			helper = p
	st.inventory.credits = 0
	CastSim.apply(st, d, {"t": "cast", "op": "hire", "who": helper})
	assert_eq([CastSim.favors(st, d), st.inventory.credits, CastSim.guest(st, d)["kind"]], [0, 0, "hire"],
		"the favour pays first")
	s.apply({"t": "descend"})
	s.apply({"t": "floor", "floor": 2})
	assert_eq(CastSim.guest(st, d), {}, "the guest stays behind on its floor")


# --- the start block -------------------------------------------------------------------------------------------------

func test_the_start_block_of_the_cast() -> void:
	var d: GameData = real_data()
	var st: GameState = GameState.create_new(d, 0, "Kai", 1, &"prime")
	var good: Dictionary = CastKit.start_cmd(d, "ssn_akt3")
	assert_eq(good["cast"], {"v": 1, "places": 100, "humans": 1})
	assert_eq(RunRules.season_refusal(st, d, good), "")
	assert_eq(RunRules.season_refusal(st, d, Kit.start_cmd(d, "ssn_akt3")), "", "{}: a season without a cast")
	for bad: Variant in [{"v": 1, "places": 99, "humans": 1}, {"v": 2, "places": 100, "humans": 1},
			{"v": 1, "places": 100, "humans": 2}, {"v": 1, "places": 100}, {"v": 1.5, "places": 100, "humans": 1},
			{"v": 1, "places": 100, "humans": 1, "roster": ""}, [1]]:
		var cmd: Dictionary = good.duplicate(true)
		cmd["cast"] = bad
		assert_eq(RunRules.season_refusal(st, d, cmd), "cast_mismatch", "forged: " + str(bad))
	var none: GameState = GameState.create_new(d, 0, "Kai", 1, &"prime")
	RunRules.apply_season(none, d, Kit.start_cmd(d, "ssn_akt3"))
	assert_false(CastSim.has_cast(none))
	assert_eq(RunRules.season_refusal(none, d, {"t": "cast", "op": "help", "who": 1}), "no_cast")
	assert_eq([CastSim.news(none, d, 0).size(), CastSim.ticker(none, d).size(), CastSim.last_seq(none)], [0, 0, 0])
	var s: RunSim = CastKit.sim(Kit.data(6), "ssn_basis", "calendar", "net", 89)
	var log: Dictionary = s.run_log.to_dict()
	for row: Variant in (log["cmds"] as Array):
		var c: Dictionary = (row as Dictionary)["c"]
		if str(c.get("t", "")) == "season":
			(c["cast"] as Dictionary)["places"] = 101
			break
	var r: Dictionary = RunSim.replay(s.data, RunLog.from_dict(log))
	assert_gt((r["errors"] as PackedStringArray).size(), 0, "RunSim.replay reports a forged cast")


# --- the roster and the name catalog (09 §4.2) ----------------------------------------------------------------------

func test_the_roster_and_the_name_catalog() -> void:
	var d: GameData = real_data()
	var names: Array[Dictionary] = d.cast_names()
	assert_true(names.size() >= 300, "09 §4.2: ≥ 300 invented names")
	var seen: Dictionary = {}
	var shape: RegEx = RegEx.create_from_string("^[A-ZÄÖÜ][a-zäöüß]+ [A-ZÄÖÜ][a-zäöüß-]+$")
	var fold: Dictionary = {"Ä": "A", "Ö": "O", "Ü": "U"}
	for e: Dictionary in names:
		var n: String = str(e["name"])
		assert_false(seen.has(n), "unique: " + n)
		seen[n] = true
		assert_not_null(shape.search(n), "first name and surname: " + n)
		var parts: PackedStringArray = n.split(" ")
		assert_eq(str(fold.get(parts[0][0], parts[0][0])), str(fold.get(parts[1][0], parts[1][0])),
			"alliterating: " + n)
		assert_has(["f", "m", "n"], str(e["form"]))
		assert_eq(IpWords.general_word(n), "", "no forbidden word: " + n)
		for w: String in NAME_WORDS:
			assert_false(n.to_lower().contains(w), "no '%s' in %s" % [w, n])
	var weights: Dictionary = {}
	for p: Dictionary in d.all_cast_profiles():
		weights[str(p["id"])] = [str(p["name"]), JsonUtil.to_int(p["weight"])]
	assert_eq(weights, {"extra": ["Statist:in", 50], "rival": ["Rival:in", 15], "helper": ["Helfer:in", 15],
		"trader": ["Händler:in", 10], "unlucky": ["Pechvogel", 10]}, "09 §4.2: the profiles and their shares")
	var st: GameState = _season(d, 17)
	var m: CastModel = CastKit.model(st, d)
	var counts: Dictionary = {}
	var roster: Dictionary = {}
	assert_eq([m.places, m.humans], [100, 1])
	assert_true(m.members[0].has(CastMember.F_HUMAN), "place 0 is the candidate")
	for mb: CastMember in m.members:
		if not mb.is_ai():
			continue
		counts[mb.profile] = int(counts.get(mb.profile, 0)) + 1
		roster[mb.name] = true
		assert_true(seen.has(mb.name), "a name of the catalog")
		assert_between(mb.skill, 20, 95)
		assert_between(mb.pace, 3, 30, "0.3–3.0 play hours a day")
		assert_between(mb.sess, 0, 23)
		assert_ne(d.origin(mb.org), {}, "a Vorleben of the 08 catalog")
		assert_ne(d.hobby(mb.hob), {}, "a hobby of the 08 catalog")
		assert_eq([mb.fl, mb.sp, mb.cl], [1, "", ""], "on floor 1, no Recall yet")
	assert_eq(roster.size(), 99, "99 different names")
	assert_eq(counts, {"extra": 49, "rival": 15, "helper": 15, "trader": 10, "unlucky": 10}, "by quota")
	var skills: int = 0
	for mb: CastMember in m.members:
		skills += mb.skill if mb.is_ai() else 0
	assert_between(skills / 99, 50, 62, "the triangle 20–55–95 (mean ≈ 57)")
	m.catch_up(CastModel.hour_of(20 * DAY), 20 * DAY)
	var recalled: int = 0
	for mb: CastMember in m.members:
		if mb.is_ai() and mb.fl >= 3:
			recalled += 1
			assert_true(mb.cl != "" and mb.sp != "", "the Recall on floor 3")
			assert_true(d.species_def(mb.sp).is_for("kai") and d.class_def(mb.cl).is_for("kai"),
				"Kai's species and classes — no talking pug, only the candidate has a Graf")
	assert_gt(recalled, 0)
