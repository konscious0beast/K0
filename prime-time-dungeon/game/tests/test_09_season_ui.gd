extends TestCase
## 09 ST1-H test_09_season_ui: the season UI — the words, dates and rows of season_view.gd (local time, the schedule,
## the collapse display, the counter, the ranking with the AI labelled, the closed stairs, the .ics file without
## personal data); the title's season card only in debug builds (orchestrator decision 1) beside an unchanged menu;
## "Sendung starten" / "Neue Staffel" and the single new-game path; the pause tab "Staffel" (segments, actions, the
## clear confirmation of "Staffel beenden", the Sendepause with the new .ics, "Am Stück"); the HUD's collapse display;
## the safe-room guests and the hire; the season summary (finale, the studio guest's Zeitraffer on a copy) and the hall
## of fame (Save.career, once per season, no name; "Staffel beenden" frees the slot); the routes of a season's end;
## focus inside every screen, hit areas ≥ 88 px 12 px apart, no overlap at 1280 × 720, 1920 × 1080 and 2400 × 1080
## with notch insets, texts ≥ 16 px with drawn glyphs and never cut off ("…"); the views never change the recorded
## state.

const Kit := preload("res://tests/fixtures/season_core/season_core.gd")
const SeasonView := preload("res://scenes/ui/season_view.gd")
const TitleFlow := preload("res://scenes/title/title_flow.gd")
const UiUtil := preload("res://scenes/ui/ui_util.gd")
const ModDialogScript := preload("res://scenes/ui/mod_dialog.gd")
const TITLE: String = "res://scenes/title/title.tscn"
const SETUP: String = "res://scenes/title/season_setup.tscn"
const SUMMARY: String = "res://scenes/ui/season_summary.tscn"
const HALL: String = "res://scenes/ui/hall_of_fame.tscn"
const PAUSE_MENU: String = "res://scenes/ui/pause_menu.tscn"
const HUD: String = "res://scenes/ui/exploration_hud.tscn"
const GAME_OVER: String = "res://scenes/title/game_over.tscn"
const SLOT_SELECT: String = "res://scenes/title/slot_select.tscn"
const SAFE_ROOM: String = "res://scenes/safe_room/safe_room.tscn"
const ROUTER_FIXTURE: String = "res://tests/fixtures/router/router_screen.tscn"
const ROOT: String = "user://test_09_season_ui"
const NOW: int = Kit.START                    # one hour of Vorprogramm before day 0 (Kit.DAY0, a Tuesday 20:00 UTC)
const DAY: int = 86400
const HOUR: int = 3600
const SEED_GUESTS: int = 6                    # a Helfer:in in the first safe room of floor 2 on day 3, a Pechvogel
const RESOLUTIONS: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2400, 1080)]
const NOTCH: Dictionary = {"left": 48, "top": 0, "right": 48, "bottom": 0}
const HIT: float = 88.0
const GAP: float = 12.0

var _saved_size: Vector2i
var _saved_dir: String


func before_each() -> void:
	_saved_size = tree.root.size
	_saved_dir = Save.save_dir
	_rmrf(ROOT)
	Save.save_dir = ROOT + "/saves"
	TitleFlow.pending_season = {}
	TitleScreen.season_gate = -1
	ExplorationHud.season_said.clear()


func after_each() -> void:
	tree.paused = false
	SafeAreaContainer.simulated_insets = {}
	tree.root.size = _saved_size
	await _settle_router()
	Game.replaying = false
	Game.season_live_clock = false
	if Game.combat != null:
		Game.end_combat()
	Game.state = null
	Game.run_log = null
	Game.sim = null
	Game.persona = null
	Game.mode = &"campaign"
	Game.timer_running = false
	Game.in_battle = false
	Game.clear_blocking_dialogs()
	TitleScreen.season_gate = -1
	TitleFlow.pending_season = {}
	ExplorationHud.season_said.clear()
	Save.save_dir = _saved_dir
	_rmrf(ROOT)


# --- season_view.gd: words, dates, rows ------------------------------------------------------------------------------

func test_words_dates_and_the_schedule() -> void:
	assert_eq([SeasonView.short(DAY + HOUR + 1), SeasonView.short(4 * HOUR + 600), SeasonView.short(720),
		SeasonView.short(45)], ["1 T 1 Std.", "4 Std. 10 Min.", "12 Min.", "45 Sek."])
	assert_eq([SeasonView.air_step("20:00", 1), SeasonView.air_step("21:30", 1), SeasonView.air_step("08:00", -1),
		SeasonView.air_step("kaputt", 0)], ["20:30", "21:30", "08:00", "20:00"], "H-4: 08:00 … 21:30, never at night")
	var def: SeasonDef = DB.season_def(SeasonView.default_def(DB.data))
	assert_eq(def.format, 6, "H-2: the owned format is the Basis season (no Akt 2 / 3, no upsell)")
	assert_eq(SeasonView.owned_defs(DB.data).size(), 1)
	assert_eq(SeasonView.format_text(def), "Basis · 6 Etagen · 24 Tage")
	var p: Dictionary = SeasonView.preview_dates(def, "20:00", NOW, 0)
	assert_eq([p["day0"], p["first"], p["last"]], [Kit.DAY0, Kit.DAY0 + 2 * DAY, Kit.DAY0 + 24 * DAY])
	assert_eq(SeasonView.when_text(Kit.DAY0, 0), "Di 13.10. 20:00")
	assert_eq(SeasonView.when_text(Kit.DAY0, 2 * HOUR), "Di 13.10. 22:00", "local time = UTC + the offset")
	var st: GameState = _season("calendar", "net", 7, 2, 3 * DAY + 5 * HOUR)
	assert_eq(SeasonView.head_text(st), "Staffel 3 · Basis · Kalender · Mit Netz")
	assert_eq(SeasonView.status_text(st, 0), "Tag 3 von 24 · Etage 2 auf Sendung")
	var rows: Array[Dictionary] = SeasonView.schedule(st, DB.data, 0)
	var kinds: Array = []
	for r: Dictionary in rows:
		kinds.append(r["kind"])
	assert_eq(kinds, ["gone", "air", "open", "closed", "closed", "closed"], "09 §2.4, §2.6")
	var s: SeasonState = st.season
	assert_eq(rows[0]["line"], SeasonView.when_text(s.collapse_utc[0], 0), "the collapse date in local time")
	assert_true(bool(rows[1]["here"]) and str(rows[1]["sub"]).begins_with("auf Sendung · in 1 T 19 Std."),
		str(rows[1]["sub"]))
	assert_eq(rows[3]["sub"], "Kulissen im Aufbau · öffnet So 20:00", "floor 4 opens when floor 3 is on air")
	assert_true(bool(rows[5]["finale"]))
	assert_eq(SeasonView.floor_name(DB.data, 2), "Passage Ewiger Rabatt")
	var b: GameState = _season("binge", "net", 7, 2, 0)
	var brows: Array[Dictionary] = SeasonView.schedule(b, DB.data, 0)
	assert_eq([brows[0]["kind"], brows[1]["kind"], brows[2]["kind"]], ["done", "now", "next"])
	assert_eq([brows[1]["line"], brows[2]["line"]], ["30:00", "40:00"], "Am Stück: the countdowns (09 §2.4)")
	assert_eq(SeasonView.collapse_view(b, 0, 0), {}, "Am Stück keeps today's countdown")


func test_the_collapse_display_and_the_counter() -> void:
	var st: GameState = _season("calendar", "net", 7, 2, 3 * DAY + 5 * HOUR)
	var s: SeasonState = st.season
	var cv: Dictionary = SeasonView.collapse_view(st, 0, 0)
	assert_eq([cv["floor"], cv["level"], cv["ahead"], cv["text"], cv["sub"]], [2, 0, false, "Einsturz So 20:00",
		"in 1 T 19 Std."], "calm")
	s.utc = s.collapse_utc[1] - 50 * 60
	cv = SeasonView.collapse_view(st, 0, 0)
	assert_eq([cv["level"], cv["text"], cv["sub"]], [1, "Einsturz um 20:00", "in 50 Min."], "≤ 1 h (09 §2.5 Nr. 6)")
	assert_eq(SeasonView.collapse_view(st, 600, 0)["sub"], "in 40 Min.", "the wall clock counts on between the steps")
	s.utc = s.collapse_utc[1] - 300
	assert_eq(SeasonView.collapse_view(st, 0, 0)["level"], 2, "≤ 10 min")
	s.utc = s.collapse_utc[1] - 30
	assert_eq([SeasonView.collapse_view(st, 0, 0)["level"], SeasonView.collapse_view(st, 60, 0)["sub"]], [3, "jetzt"])
	s.hold_utc = s.collapse_utc[1] + 120
	assert_eq(SeasonView.collapse_view(st, 0, 0)["at"], s.hold_utc, "a waiting collapse after a combat: its hold")
	s.hold_utc = 0
	var c: Dictionary = SeasonView.counter(st, DB.data)
	assert_eq([c["kind"], c["of"]], ["vest", 100])
	assert_true(str(c["text"]).begins_with("Weiße Weste ") and str(c["text"]).ends_with("/100"), str(c["text"]))
	assert_true(SeasonView.rank_text(st, DB.data).begins_with("Platz "), SeasonView.rank_text(st, DB.data))
	var no: GameState = _season("calendar", "no_net", 7, 1, 0)
	assert_true(str(SeasonView.counter(no, DB.data)["text"]).begins_with("Noch dabei "), "Ohne Netz (09 §2.3)")
	var ahead: GameState = _season("calendar", "net", 7, 3, HOUR)
	var av: Dictionary = SeasonView.collapse_view(ahead, 0, 0)
	assert_true(bool(av["ahead"]) and str(av["text"]).begins_with("Etage 3 · Einsturz "), str(av["text"]))


func test_ranking_ticker_and_the_programme() -> void:
	var st: GameState = _season("calendar", "net", SEED_GUESTS, 2, 3 * DAY + 5 * HOUR)
	var rows: Array[Dictionary] = SeasonView.ranking_rows(st, DB.data)
	var me: int = 0
	var gaps: int = 0
	for r: Dictionary in rows:
		if bool(r.get("gap", false)):
			gaps += 1
			continue
		if bool(r["me"]):
			me += 1
			assert_false(bool(r["ai"]))
		else:
			assert_true(bool(r["ai"]) and str(r["label"]).ends_with("(KI)"), "the AI labelled (09 §4.1): " + str(r))
	assert_eq(me, 1, "the candidate's own place")
	assert_eq(rows[0]["rank"], 1)
	assert_lt(gaps, 2, "at most one gap: the top three and the places around the candidate")
	var news: Array[Dictionary] = SeasonView.ticker_rows(st, DB.data, 24, 5)
	for n: Dictionary in news:
		assert_ne(str(n["text"]), "", "every news has its M.O.D. wording")
		assert_false(str(n["text"]).contains("{"), str(n["text"]))
	var v: Dictionary = SeasonView.floor_view(st, DB.data, 0)
	assert_eq((v["points"] as Array).size(), 4, "four air times on floor 2 by day 3 (09 §3.3)")
	assert_true(bool(((v["points"] as Array)[0] as Dictionary)["new"]), "a point whose room was not entered: NEU")
	assert_eq(str(v["next"]), SeasonView.clock_text(st.season.next_air_utc, 0))
	assert_eq(int((v["need"] as Dictionary).get("place", -1)), CastSim.in_need(st, DB.data), "the Pechvogel in need")


func test_closed_stairs_say_why() -> void:
	var st: GameState = _season("calendar", "net", 7, 3, HOUR)
	var v: Dictionary = SeasonView.stairs_view(st, DB.data)
	assert_eq(v["why"], "floor_closed")
	assert_true(str(v["text"]).begins_with("Etage 4: Kulissen im Aufbau — öffnet in 4 T 23 Std. Eine Etage dürfen"),
		str(v["text"]))
	assert_false(str(v["text"]).contains(".."), "one period after the duration")
	assert_true(bool(v["binge"]), "09 §2.6: the first closed stairs offer Am Stück (private calendar seasons)")
	assert_eq(SeasonView.stairs_view(_season("calendar", "net", 7, 2, HOUR), DB.data), {}, "floor 3 is open")
	var b: GameState = _season("binge", "net", 7, 3, 0)
	assert_eq(SeasonView.stairs_view(b, DB.data), {}, "Am Stück has no such limit")
	while b.floor_run.index < 6:
		assert_true(Game.season_debug_descend())
	assert_eq(SeasonView.stairs_view(b, DB.data)["why"], "no_stairs", "the last floor: the finale, no stairs")


func test_the_calendar_file_has_dates_and_no_personal_data() -> void:
	var st: GameState = _season("calendar", "net", 7, 1, 0)
	st.player_name = "Zora Zuckerguss"
	var text: String = SeasonView.ics_text(st, DB.data, NOW)
	assert_true(text.begins_with("BEGIN:VCALENDAR\r\nVERSION:2.0\r\n") and text.ends_with("END:VCALENDAR\r\n"))
	assert_eq(text.count("BEGIN:VEVENT"), 6, "every collapse still to come")
	assert_true(text.contains("DTSTART:20261015T200000Z"), "UTC (the device's calendar shows local time)")
	assert_true(text.contains("SUMMARY:Etage 1 stürzt ein (Staffel 3)"))
	for line: String in text.split("\r\n", false):
		assert_true(line.to_utf8_buffer().size() <= SeasonView.ICS_LINE_OCTETS, "RFC 5545 §3.1: " + line)
	assert_false(text.contains("Zora") or text.contains("Zuckerguss"), "no name (no personal data, V-9)")
	var path: String = SeasonView.export_ics(st, DB.data, NOW, ROOT + "/exports")
	assert_true(path.ends_with("staffel_3_sendeplan.ics") and FileAccess.file_exists(path), path)
	assert_eq(FileAccess.get_file_as_string(path), text, "a local file")
	assert_true(Game.season_pause_days(2), "a Sendepause of two days")
	assert_true(SeasonView.ics_text(st, DB.data, NOW).contains("DTSTART:20261017T200000Z"), "the new dates")
	assert_eq(SeasonView.ics_text(_season("binge", "net", 7, 1, 0), DB.data, NOW), "", "Am Stück has no dates")


# --- the end of a season: the hall of fame, the routes ---------------------------------------------------------------

func test_the_hall_of_fame_keeps_each_season_once() -> void:
	assert_true(Save.career_hall_add({"key": "ssn_basis#1#1", "titles": ["Finalist:in der Staffel 1 (privat)"]}))
	assert_false(Save.career_hall_add({"key": "ssn_basis#1#1", "titles": []}), "once per season")
	assert_true(Save.career_hall_add({"key": "ssn_basis#2#2", "titles": ["Finalist:in der Staffel 1 (privat)",
		"Weiße Weste (privat)"]}))
	assert_eq(Save.career_hall().size(), 2)
	assert_eq(str(Save.career_hall()[0]["key"]), "ssn_basis#2#2", "newest first")
	assert_eq(Save.career_titles(), PackedStringArray(["Finalist:in der Staffel 1 (privat)", "Weiße Weste (privat)"]))
	Save.read_only = true
	assert_false(Save.career_hall_add({"key": "ssn_basis#3#3"}), "read only: nothing written")
	Save.read_only = false
	assert_false(Save.career_seen("x"))
	Save.career_mark("x")
	assert_true(Save.career_seen("x"))
	assert_true(Save.season_finished({"season": {"result": "left"}}))
	assert_false(Save.season_finished({"season": {"result": ""}}) or Save.season_finished({}))


func test_staffel_beenden_frees_the_slot_and_shows_the_summary() -> void:
	assert_true(Game.start_season(1, "ssn_basis", {"now": NOW, "tz_sec": 0, "seed": 7}))
	Game.state.player_name = "Zora Zuckerguss"
	assert_true(Save.has_save(1))
	assert_eq(Game._season_end_path(Router.SCENE_TITLE), Router.SCENE_TITLE, "a running season goes its way")
	assert_true(Game.season_leave())
	var e: Dictionary = Save.career_hall()[0] if not Save.career_hall().is_empty() else {}
	assert_eq([e.get("result", ""), e.get("floor", 0), e.get("number", 0)], ["left", 1, 1], "in the hall (V-18)")
	assert_false(JSON.stringify(Save.career()).contains("Zuckerguss"), "no name in the career (08 P-1)")
	assert_false(Save.has_save(1), "the slot is free")
	assert_eq(Game.state.slot, 0, "and never written again")
	assert_eq([Game._season_end_path(Router.SCENE_TITLE), Game._season_end_path(Router.SCENE_CREDITS),
		Game._season_end_path(Router.SCENE_EXPLORATION)], [Game.SCENE_SEASON_SUMMARY, Game.SCENE_SEASON_SUMMARY,
		Router.SCENE_EXPLORATION])
	assert_true(await wait_until(func() -> bool: return _current_is(SUMMARY), 600), "the season summary")
	var sm: Node = Router.current
	assert_eq(str((sm.get("entry") as Dictionary).get("result", "")), "left")
	assert_true(bool(sm.get("projected")), "a candidate who left sees the Zeitraffer bis zum Finale")
	Game.state.season = null
	assert_eq(Game._season_end_path(Router.SCENE_CREDITS), Router.SCENE_CREDITS, "a campaign keeps its credits")


func test_the_summary_and_the_hall_scenes() -> void:
	var st: GameState = _season("binge", "net", 11, 6, 0)
	var s: SeasonState = st.season
	s.result = "finalist"
	s.result_floor = 6
	s.finale_at = SeasonRules.now(st)
	CastSim.advance(st, DB.data)
	var hash0: String = StateHash.of(st)
	var sm: Node = _screen(SUMMARY, {})
	await wait_frames(3)
	assert_eq(_label_text(sm, "Title"), "GROSSES FINALE GEWONNEN")
	assert_eq(sm.find_child("Titles", true, false).get_child_count(), 2, "Finalist:in and Weiße Weste (09 §2.7)")
	assert_false(bool(sm.get("projected")), "the finalist: the ranking as it ends")
	assert_true(Save.career_hall_has(SeasonView.hall_key(st)), "the hall entry is written once")
	_check_screen(sm, "summary")
	assert_eq(StateHash.of(st), hash0, "the summary changes nothing recorded")
	_dispose(sm)
	# a studio guest: the Zeitraffer on a copy
	var out: GameState = _season("calendar", "no_net", 5, 3, 0, 4)
	Game.replaying = true
	while out.season.result == "":
		assert_true(Game.season_clock(DAY))
	Game.replaying = false
	assert_eq(out.season.result, "buried")
	var h1: String = StateHash.of(out)
	var rows: Array[Dictionary] = SeasonView.projection(out, DB.data)
	assert_eq(StateHash.of(out), h1, "the projection runs on a copy (the UI never changes recorded state)")
	assert_gt(rows.size(), 5)
	var g: Node = _screen(SUMMARY, {})
	await wait_frames(3)
	assert_true(bool(g.get("projected")))
	assert_eq(_label_text(g, "Title"), "VERSCHÜTTET AUF ETAGE 3")
	_dispose(g)
	# the Sendeschluss of Ohne Netz: the summary instead of a load, no grace time
	var go: Node = _screen(GAME_OVER, {"reason": &"timer", "capture": true})
	await wait_frames(3)
	var gb: Dictionary = go.get("buttons")
	assert_true(gb.has("summary") and gb.has("title") and not gb.has("load"), str(gb.keys()))
	assert_not_null(_find_text(go, "Verschüttet auf Etage 3 — ab jetzt Studiogast."))
	_dispose(go)
	# the hall: one card per season, the detail follows the focus
	var hall: Node = _screen(HALL, {"from": "title"})
	await wait_frames(3)
	var cards: Array = hall.get("cards")
	assert_eq(cards.size(), Save.career_hall().size())
	assert_eq(tree.root.gui_get_focus_owner(), cards[0], "the newest season has the focus")
	(cards[1] as Button).grab_focus()
	await wait_frames(1)
	assert_eq(int(hall.get("selected")), 1)
	_check_screen(hall, "hall")
	_dispose(hall)


# --- the title, the setup, the new-game path --------------------------------------------------------------------------

func test_the_title_offers_seasons_in_debug_builds_only() -> void:
	TitleScreen.season_gate = 0
	var t: Node = _screen(TITLE, {})
	await wait_frames(4)
	var base_ids: PackedStringArray = t.call("menu_ids")
	assert_null(t.get("season_card"), "decision 1: no season entry outside debug builds (the gate)")
	TitleScreen.season_gate = -1
	assert_eq(TitleScreen.seasons_offered(), OS.is_debug_build(), "the build decides")
	TitleScreen.season_gate = 1
	t.call("_st_build")
	await wait_frames(2)
	var card: Control = t.get("season_card") as Control
	assert_not_null(card)
	var sb: Dictionary = t.get("season_buttons")
	assert_eq((sb["start"] as Button).text, "Sendung starten", "the first season of the device")
	assert_false(sb.has("hall"), "an empty hall of fame has no button")
	assert_eq(t.call("menu_ids"), base_ids, "the menu column keeps its entries")
	var mb: Dictionary = t.get("menu_buttons")
	var ex: Button = t.get("extras_button") as Button
	assert_almost(ex.get_global_rect().position.y, (mb["event"] as Button).get_global_rect().position.y, 0.5,
		"Extras stays beside Event-Lauf")
	var new_b: Button = mb["new"]
	assert_eq(new_b.get_node(new_b.focus_neighbor_right), sb["start"], "ui_right from the menu reaches the card")
	assert_eq((sb["start"] as Button).get_node((sb["start"] as Button).focus_neighbor_left), new_b)
	assert_eq((mb["event"] as Button).get_node((mb["event"] as Button).focus_neighbor_right), ex)
	Save.career_set("seasons", 2)
	Save.career_hall_add({"key": "ssn_basis#2#2", "result": "end"})
	t.call("_st_build")
	await wait_frames(2)
	sb = t.get("season_buttons")
	assert_eq((sb["start"] as Button).text, "Neue Staffel")
	assert_true(sb.has("hall"), "Ruhmeshalle once a season is in it")
	for res: Vector2i in RESOLUTIONS:
		for notch: bool in [false, true]:
			tree.root.size = res
			SafeAreaContainer.simulated_insets = NOTCH if notch else {}
			tree.root.size_changed.emit()             # the screens stay: their safe areas measure again
			await wait_frames(3)
			var tag: String = "title %s notch=%s" % [str(res), notch]
			var rects: Dictionary = {"card": (t.get("season_card") as Control).get_global_rect(),
				"extras": ex.get_global_rect()}
			for id: Variant in mb.keys():
				rects["menu_" + str(id)] = (mb[id] as Control).get_global_rect()
			var foot: Control = t.find_child("Footer", true, false) as Control
			rects["footer"] = foot.get_global_rect()
			_no_overlap(rects, _frame(t), tag)
			var targets: Array[Control] = []
			for b: Variant in (t.get("season_buttons") as Dictionary).values():
				targets.append(b as Control)
			_targets(targets, tag)
	(sb["start"] as Button).emit_signal("pressed")
	assert_true(await wait_until(func() -> bool: return _current_is(SETUP), 600), "Neue Staffel → the setup")
	assert_eq(str(Router.current.get("mode")), "new")


func test_the_setup_of_a_season() -> void:
	var first: Node = _screen(SETUP, {"mode": "first", "capture": true, "now": NOW, "tz": 0})
	await wait_frames(3)
	assert_eq(first.call("start_opts"), {"tempo": "calendar", "mode": "net", "air_time": "20:00"},
		"V-6: the first season has the standard values")
	assert_eq(tree.root.gui_get_focus_owner(), (first.get("buttons") as Dictionary)["start"], "Sendung starten")
	first.call("set_tempo", "binge")
	assert_eq(str(first.get("tempo")), "calendar", "no choice in the first season")
	_check_screen(first, "setup first")
	_dispose(first)
	var nw: Node = _screen(SETUP, {"mode": "new", "capture": true, "now": NOW, "tz": 0})
	await wait_frames(3)
	var b: Dictionary = nw.get("buttons")
	assert_true(b.has("mode_no_net") and (b["mode_no_net"] as Button).disabled, "Ohne Netz is locked (V-7)")
	nw.call("set_mode", "no_net")
	assert_eq(str(nw.get("net_mode")), "net")
	nw.call("step_air", 3)
	assert_eq(str(nw.get("air")), "21:30")
	nw.call("step_air", 1)
	assert_eq(str(nw.get("air")), "21:30", "never later")
	nw.call("set_tempo", "binge")
	assert_eq(nw.call("start_opts"), {"tempo": "binge", "mode": "net"}, "Am Stück has no air time")
	assert_true((b["air_less"] as Button).disabled)
	var start: Button = b["start"]
	assert_eq(start.get_node(start.focus_neighbor_top), b["air_more"], "the rows by ui_up / ui_down")
	_dispose(nw)
	Save.career_set("no_net", true)
	var nn: Node = _screen(SETUP, {"mode": "new", "capture": true, "now": NOW, "tz": 0})
	await wait_frames(3)
	nn.call("set_mode", "no_net")
	assert_eq(str(nn.get("net_mode")), "no_net", "unlocked")
	nn.call("start")
	await wait_frames(2)
	var d: Node = nn.get("_modal")
	assert_not_null(d, "„Ein Leben. Ernsthaft?“ (09 §7.2)")
	assert_eq(tree.root.gui_get_focus_owner(), d.call("button", "net"), "the safe answer first")
	d.call("answer", "net")
	await wait_frames(2)
	assert_eq(str(nn.get("net_mode")), "net")
	for res: Vector2i in RESOLUTIONS:
		for notch: bool in [false, true]:
			tree.root.size = res
			SafeAreaContainer.simulated_insets = NOTCH if notch else {}
			tree.root.size_changed.emit()             # the screens stay: their safe areas measure again
			await wait_frames(3)
			_check_screen(nn, "setup %s notch=%s" % [str(res), notch])


func test_the_single_new_game_path_starts_the_season() -> void:
	TitleFlow.pending_season = {"def": "ssn_nope", "opts": {}}
	assert_false(TitleFlow.start_new_game(1, "Zora", true, 11), "an unknown template is refused")
	assert_false(TitleFlow.pending_season.is_empty(), "the pending season stays for a retry")
	TitleFlow.pending_season = {"def": "ssn_basis", "opts": {"tempo": "binge", "mode": "net"}}
	assert_true(TitleFlow.start_new_game(1, "Zora", true, 11))
	assert_true(TitleFlow.pending_season.is_empty())
	var s: SeasonState = Game.state.season
	assert_true(s != null and s.tempo == "binge" and s.number == 1 and Game.state.player_name == "Zora")
	await _settle_router()
	TitleFlow.pending_season = {}
	assert_true(TitleFlow.start_new_game(2, "Zora", true, 12), "without a pending season: a campaign game")
	assert_null(Game.state.season)


func test_slot_cards_and_a_finished_slot() -> void:
	assert_true(Game.start_season(1, "ssn_basis", {"now": NOW, "tz_sec": 0, "seed": 7}))
	Game.state.player_name = "Zora"
	assert_eq(Save.save_slot(1), OK)
	var sel: Node = _screen(SLOT_SELECT, {"mode": "load"})
	await wait_frames(3)
	var line: Label = (sel.get("slot_buttons") as Array)[0].find_child("Season", true, false) as Label
	assert_true(line != null and line.text == "Staffel 1 · Kalender · Mit Netz · Etage 1 auf Sendung",
		line.text if line != null else "no season line")
	if line != null:
		_assert_not_cut(line, "slot card")
	_dispose(sel)
	assert_true(Game.season_leave())                 # left: the slot is freed — a finished season on slot 2 instead
	await wait_frames(2)                              # the route of "left" (deferred) before the next season
	await _settle_router()
	assert_true(Game.start_season(2, "ssn_basis", {"now": NOW, "tz_sec": 0, "seed": 8}))
	Game.state.season.result = "end"
	assert_eq(Save.save_slot(2), OK)
	assert_true(Save.season_finished(Save.slot_summary(2)))
	assert_ne(Save.newest_slot(), 2, "a finished season does not continue")
	var sel2: Node = _screen(SLOT_SELECT, {"mode": "load"})
	await wait_frames(3)
	var done: Label = (sel2.get("slot_buttons") as Array)[1].find_child("Season", true, false) as Label
	assert_true(done != null and done.text.contains(" beendet: "), done.text if done != null else "no season line")
	if done != null:
		_assert_not_cut(done, "finished slot card")
	_dispose(sel2)
	assert_eq(TitleFlow.load_and_route(2), OK)
	assert_true(await wait_until(func() -> bool: return _current_is(HALL), 600), "its slot opens the hall of fame")


# --- the pause tab "Staffel" ------------------------------------------------------------------------------------------

func test_the_pause_tab() -> void:
	Game.new_game(0, "Kai", 3)
	var pm0: Node = _screen(PAUSE_MENU, {})
	await wait_frames(2)
	assert_false(pm0.call("_page_ids").has("season"), "without a season the tabs stay as they are")
	_dispose(pm0)
	var st: GameState = _season("calendar", "net", SEED_GUESTS, 2, 3 * DAY + 5 * HOUR)
	var hash0: String = StateHash.of(st)
	var pm: Node = _screen(PAUSE_MENU, {"tab": "season"})
	await wait_frames(3)
	var ids: Array[String] = pm.call("_page_ids")
	assert_eq(ids[1], "season", "„Staffel“ follows „Party“")
	var page: Node = pm.call("page", "season")
	assert_eq(page.call("plan_rows"), 6, "the schedule: one row per floor")
	var seg: Dictionary = page.get("_seg_buttons")
	assert_eq(tree.root.gui_get_focus_owner(), seg["ranking"], "the first segment has the focus")
	assert_not_null(_find_text_part(page, "(KI)"), "the AI labelled")
	assert_not_null(_find_text_part(page, " · Sie"), "the candidate's row")
	for id: String in ["ticker", "programme", "actions", "ranking"]:
		page.call("show_segment", id)
		await wait_frames(1)
		_check_screen(page, "tab " + id)
	assert_eq(StateHash.of(st), hash0, "looking changes nothing recorded")
	page.call("show_segment", "programme")
	var help: Button = page.call("action", "help")
	assert_not_null(help, "the Pechvogel's Helfen (09 §4.3)")
	assert_eq((seg["programme"] as Button).get_node((seg["programme"] as Button).focus_neighbor_bottom), help)
	page.call("show_segment", "actions")
	for a: String in ["ics", "pause", "binge", "leave"]:
		assert_not_null(page.call("action", a), a)
	var leave: Button = page.call("action", "leave")
	assert_eq(leave.get_node(leave.focus_neighbor_top), page.call("action", "pause"), "the grid: up")
	# Staffel beenden: the clear confirmation (red, "Weiterspielen" first; Esc keeps playing)
	leave.emit_signal("pressed")
	await wait_frames(2)
	var d: Node = pm.get("_confirm")
	assert_true(pm.call("is_confirm_open"), "modal over the menu")
	assert_eq(tree.root.gui_get_focus_owner(), d.call("button", "stay"))
	assert_eq((d.call("button", "leave") as Button).text, "Staffel beenden")
	d.call("answer", "stay")
	await wait_frames(2)
	assert_eq(st.season.result, "", "nothing happened")
	# the Sendepause: days, then the new calendar file
	var c2: int = st.season.collapse_utc[1]
	(page.call("action", "pause") as Button).emit_signal("pressed")
	await wait_frames(2)
	d = pm.get("_confirm")
	(d.find_child("DaysMore", true, false) as Button).emit_signal("pressed")
	assert_eq(int(d.get("days")), 2)
	d.call("answer", "pause")
	await wait_frames(2)
	assert_eq([st.season.collapse_utc[1], st.season.pause_sec], [c2 + 2 * DAY, 2 * DAY], "every date moved on")
	d = pm.get("_confirm")
	assert_not_null(d.call("button", "ics"), "09 §2.4: after a pause the new file is offered")
	d.call("answer", "no")
	await wait_frames(2)
	# Am Stück: one way only
	page.call("show_segment", "actions")
	(page.call("action", "binge") as Button).emit_signal("pressed")
	await wait_frames(2)
	(pm.get("_confirm") as Node).call("answer", "binge")
	await wait_frames(2)
	assert_eq(st.season.tempo, "binge")
	page.call("show_segment", "actions")
	assert_null(page.call("action", "binge"), "no way back")
	assert_null(page.call("action", "pause"), "Am Stück needs no pause")
	(page.call("action", "leave") as Button).emit_signal("pressed")
	await wait_frames(2)
	(pm.get("_confirm") as Node).call("answer", "leave")
	await wait_frames(2)
	assert_false(is_instance_valid(pm) and pm.is_inside_tree(), "the menu closed")
	assert_false(tree.paused)
	assert_eq(st.season.result, "left")


func test_the_tab_and_the_dialogs_fit_every_screen() -> void:
	_season("calendar", "net", SEED_GUESTS, 2, 3 * DAY + 5 * HOUR)
	for res: Vector2i in RESOLUTIONS:
		for notch: bool in [false, true]:
			tree.root.size = res
			SafeAreaContainer.simulated_insets = NOTCH if notch else {}
			var pm: Node = _screen(PAUSE_MENU, {"tab": "season"})
			await wait_frames(3)
			var page: Node = pm.call("page", "season")
			var tag: String = "%s notch=%s" % [str(res), notch]
			for id: String in ["ranking", "ticker", "programme", "actions"]:
				page.call("show_segment", id)
				await wait_frames(2)
				_check_screen(page, "tab %s %s" % [id, tag])
				var scroll: ScrollContainer = page.find_child("ContentScroll", true, false) as ScrollContainer
				assert_false(scroll.get_v_scroll_bar().visible, "%s fits without scrolling %s" % [id, tag])
			(page.call("action", "pause") as Button).emit_signal("pressed")
			await wait_frames(2)
			var d: Node = pm.get("_confirm")
			_check_screen(d, "pause dialog " + tag)
			d.call("answer", "back")
			await wait_frames(1)
			_dispose(pm)
			await wait_frames(1)


# --- the HUD, the safe room -------------------------------------------------------------------------------------------

func test_the_collapse_display_in_the_hud() -> void:
	Game.new_game(0, "Kai", 3)
	var camp: ExplorationHud = _screen(HUD, {}) as ExplorationHud
	await wait_frames(2)
	assert_null(camp.season_panel, "a campaign run keeps today's HUD")
	_dispose(camp)
	var st: GameState = _season("calendar", "net", SEED_GUESTS, 2, 3 * DAY + 5 * HOUR)
	var said: Array = []
	var on_said: Callable = func(_t: String, _v: StringName, tag: String, _b: bool) -> void: said.append(tag)
	Events.mod_said.connect(on_said)
	var hud: ExplorationHud = _screen(HUD, {}) as ExplorationHud
	await wait_frames(2)
	hud.season_refresh()
	assert_true(hud.season_panel.visible, "the collapse display (09 §2.5 Nr. 6)")
	assert_false(hud.is_timer_visible(), "no frozen countdown in a calendar season")
	var text: String = (hud.season_panel.find_child("CollapseText", true, false) as Label).text
	assert_true(text.begins_with("Einsturz ") and text.contains(" · in "), text)
	assert_true(hud.season_counter.visible and hud.season_counter.text.begins_with("Weiße Weste "),
		"the counter from floor 2 (09 §2.3)")
	var cached: String = str(hud.get("_season_cast_at"))
	hud.call("_season_slow", st)
	assert_eq(str(hud.get("_season_cast_at")), cached, "PERFORMANCE.md §3.11: no cast read while nothing moved")
	assert_true((hud.get("_season_reads") as Array).is_empty(), "nothing queued")
	Game.replaying = true
	assert_true(Game.season_clock(HOUR), "a recorded clock step moves the cast")
	Game.replaying = false
	hud.call("_season_slow", st)
	assert_ne(str(hud.get("_season_cast_at")), cached, "the cast moved: read again")
	assert_eq((hud.get("_season_reads") as Array).size(), 3, "counter, rank, Pechvogel — one per 0.5-s tick")
	st.season.utc = st.season.collapse_utc[1] - 50 * 60
	hud.season_refresh()
	assert_true((hud.get("_season_reads") as Array).is_empty(), "season_refresh reads at once")
	var lbl: Label = hud.season_panel.find_child("CollapseText", true, false) as Label
	assert_eq(lbl.get_theme_color("font_color"), UiTheme.C_GOLD, "≤ 1 h: gold — calm, never red")
	assert_has(said, "season_warn_3600", "M.O.D. says it once")
	var n: int = said.count("season_warn_3600")
	hud.season_refresh()
	assert_eq(said.count("season_warn_3600"), n, "not twice on this floor")
	st.season.utc = st.season.collapse_utc[1] - 30
	hud.season_refresh()
	assert_ne(lbl.get_theme_color("font_color"), UiTheme.C_DANGER)
	Events.mod_said.disconnect(on_said)
	var target: Dictionary = {"lead": "enm_rabattschild", "count": 2, "level": 9, "dist_m": 5.0, "slots": [],
		"state": ""}
	hud.set_pull_target(target)                       # 09 H-23: a pull target — the counter makes room
	assert_false(hud.season_counter.visible, "the counter steps aside for the target frame")
	assert_true(hud.season_panel.visible, "the collapse display stays")
	hud.season_refresh()
	assert_false(hud.season_counter.visible, "… also after a refresh")
	hud.set_pull_target({})
	assert_true(hud.season_counter.visible, "back when the target goes")
	for res: Vector2i in RESOLUTIONS:
		for notch: bool in [false, true]:
			tree.root.size = res
			SafeAreaContainer.simulated_insets = NOTCH if notch else {}
			tree.root.size_changed.emit()             # the screens stay: their safe areas measure again
			await wait_frames(3)
			var frame: Control = hud.get("_frame") as Control
			var rects: Dictionary = {"top": (frame.get_node("TopCenter") as Control).get_global_rect(),
				"map": hud.minimap.get_global_rect(), "party": (frame.get_node("Party") as Control).get_global_rect()}
			_no_overlap(rects, Rect2(Vector2.ZERO, hud.get_viewport().get_visible_rect().size), "hud %s %s" % [res,
				notch])
	_dispose(hud)
	_season("binge", "net", 7, 2, 0)
	var bh: ExplorationHud = _screen(HUD, {}) as ExplorationHud
	await wait_frames(2)
	bh.season_refresh()
	assert_false(bh.season_panel.visible, "Am Stück: today's countdown")
	assert_true(bh.is_timer_visible())


func test_the_guests_of_a_safe_room_and_the_hire() -> void:
	var st: GameState = _season("calendar", "net", SEED_GUESTS, 2, 3 * DAY + 5 * HOUR)
	st.inventory.credits = 640                        # a Helfer:in costs 150 credits on floor 2
	var room: String = str(SleepResolver.layout_of(st, DB.data).safe_room_ids.values().min())
	var sr: Node = _screen(SAFE_ROOM, {"safe_room_id": room})
	await wait_frames(5)
	var panel: Control = sr.get("season_guests") as Control
	assert_true(panel != null and panel.visible, "09 §4.3: AI candidates of the floor sit here")
	var buttons: Dictionary = sr.get("season_guest_buttons")
	var hire_id: String = ""
	for k: Variant in buttons.keys():
		if str(k).begins_with("hire_"):
			hire_id = str(k)
	assert_ne(hire_id, "", "a Helfer:in can be hired")
	var place: int = hire_id.trim_prefix("hire_").to_int()
	assert_not_null(_find_text_part(panel, "(KI)"), "labelled")
	var said: Array = []
	var on_said: Callable = func(_t: String, _v: StringName, tag: String, _b: bool) -> void: said.append(tag)
	Events.mod_said.connect(on_said)
	for k2: Variant in buttons.keys():
		if str(k2).begins_with("talk_"):
			(buttons[k2] as Button).pressed.emit()        # one button per guest: "Reden" — M.O.D. quotes them
			break
	Events.mod_said.disconnect(on_said)
	assert_true(said.any(func(t: Variant) -> bool: return str(t).begins_with("season_guest_")), str(said))
	var credits: int = st.inventory.credits
	(buttons[hire_id] as Button).pressed.emit()          # the Helfer:in's button asks first
	await wait_frames(2)
	var d: Node = sr.get("_modal") as Node
	assert_not_null(d, "Anheuern? — a dialog")
	if d == null:
		return
	assert_true(_find_text_part(d, "150 Credits") != null or _find_text_part(d, "Gefallen") != null, "the price")
	_check_screen(d, "hire dialog")
	d.call("answer", "hire")
	await wait_frames(2)
	assert_eq(int(CastSim.guest(st, DB.data).get("who", -1)), place, "recorded: cast hire")
	assert_eq(st.inventory.credits, credits - CastSim.hire_cost(st))
	assert_false((sr.get("season_guest_buttons") as Dictionary).has(hire_id), "no second hire while along")
	assert_eq(SeasonView.cast_reason("guest_active"), "Sie haben schon Begleitung.")
	for res: Vector2i in RESOLUTIONS:
		for notch: bool in [false, true]:
			tree.root.size = res
			SafeAreaContainer.simulated_insets = NOTCH if notch else {}
			tree.root.size_changed.emit()             # the screens stay: their safe areas measure again
			await wait_frames(3)
			var tag: String = "safe room %s notch=%s" % [str(res), notch]
			var rects: Dictionary = {"guests": panel.get_global_rect()}
			for id: Variant in (sr.get("menu_buttons") as Dictionary).keys():
				var mbt: Control = (sr.get("menu_buttons") as Dictionary)[id] as Control
				if mbt.is_visible_in_tree():
					rects["menu_" + str(id)] = mbt.get_global_rect()
			_no_overlap(rects, _frame(panel), tag)
			var targets: Array[Control] = []
			for b: Variant in (sr.get("season_guest_buttons") as Dictionary).values():
				targets.append(b as Control)
			_targets(targets, tag)
			_check_labels(panel, tag)


## 09 §3.4, V-6, D-7: the target frame of a pull (the group's name plate in the exploration) shows the group's level in
## its colour against the controlled figure, the difference left of the plaque ("+3", "−4", "±0") and, red, the warning
## sign — in the level label itself (no draw call more); the name gives way. Outside a season the plaque stays gold
## without a number.
func test_the_target_frame_shows_colour_and_difference() -> void:
	var view: Control = (load("res://scenes/ui/explore_target.gd") as GDScript).new() as Control
	view.size = Vector2(1280, 720)
	add_to_tree(view)
	var model: Dictionary = {"lead": "enm_rabattschild", "count": 3, "level": 9, "dist_m": 6.0, "slots": [],
		"state": ""}
	view.call("set_model", model)
	await wait_frames(1)
	var lv_l: Label = view.find_child("L_level", true, false) as Label
	var name_l: Label = view.find_child("L_name", true, false) as Label
	var labels: int = view.find_children("*", "Label", true, false).size()
	assert_eq(view.call("level_view"), {}, "without a season: gold, no number")
	assert_eq(lv_l.text, "9")
	var st: GameState = _season("calendar", "net", 7, 2, 0)
	var me: int = st.member(Game.hero()).level
	for c: Array in [[0, "yellow", "±0", false], [2, "yellow", "+2", false], [3, "orange", "+3", false],
			[5, "red", "+5", true], [-3, "green", "−3", false], [-6, "grey", "−6", false]]:
		model["level"] = me + int(c[0])
		view.call("set_model", model.duplicate())
		await wait_frames(1)
		var v: Dictionary = view.call("level_view")
		assert_eq([v.get("color", ""), v.get("text", ""), v.get("warning", false)], [c[1], c[2], c[3]], str(c))
		var want: String = UiUtil.glyph_safe(str(c[2]))
		assert_true(lv_l.text.begins_with(want) and lv_l.text.ends_with(str(me + int(c[0]))), lv_l.text)
		assert_eq(UiUtil.missing_glyphs(lv_l.text), "", "drawn glyphs: " + lv_l.text)
		var font: Font = lv_l.get_theme_font("font")
		var digits: float = font.get_string_size(str(me + int(c[0])), HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		var plaque: Vector2 = view.call("level_center", view.call("frame_rect"))
		assert_almost(lv_l.get_rect().end.x, plaque.x + digits * 0.5, 1.0, "the level sits in the plaque %s" % str(c))
		var diff_end: float = float(v["x"]) + font.get_string_size(want, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		assert_true(diff_end <= plaque.x - 11.5, "the difference left of the ring %s" % str(c))
		assert_lt(name_l.get_rect().end.x, float(v["x"]) - (14.0 if bool(c[3]) else 0.0),
			"the name gives way to the difference %s" % str(c))
	assert_eq(view.find_children("*", "Label", true, false).size(), labels, "no label more (the UI budget)")
	Game.state.season = null                           # no season any more: gold again, the level alone
	view.call("set_model", model.duplicate())
	await wait_frames(1)
	assert_eq([lv_l.text, view.call("level_view")], [str(model["level"]), {}])
	_dispose(view)


## Floor 3 (the Recall, 06 §3.5): TALENT-SHOW and RECALL stand on the right — the guests go below both, and only one
## fits there (the Helfer:in first); ui_down from RECALL reaches her, Tab after RECALL too; nothing overlaps, and the
## panel stays above M.O.D.'s box on every screen.
func test_the_guests_below_the_recall_button() -> void:
	var st: GameState = _season("calendar", "net", SEED_GUESTS, 3, 3 * DAY + 5 * HOUR)
	for m: PartyMember in st.party:
		m.level = 11                                     # open talent rows: the TALENT-SHOW stands too
	st.inventory.credits = 640                           # a Helfer:in can come
	var room: String = str(SleepResolver.layout_of(st, DB.data).safe_room_ids.values().min())
	var sr: Node = _screen(SAFE_ROOM, {"safe_room_id": room, "recall": false})   # the Recall waits behind its button
	await wait_frames(5)
	assert_true(bool(sr.call("talent_show_available")) and bool(sr.call("recall_available")), "both buttons stand")
	var panel: Control = sr.get("season_guests") as Control
	var buttons: Dictionary = sr.get("season_guest_buttons")
	assert_true(panel.visible)
	assert_eq(buttons.size(), 1, "below both buttons one guest fits")
	assert_true(str(buttons.keys()[0]).begins_with("hire_"), "the Helfer:in first: her button acts")
	var mb: Dictionary = sr.get("menu_buttons")
	var recall: Control = mb["recall"] as Control
	var guest: Control = buttons.values()[0] as Control
	assert_eq(recall.get_node(recall.focus_neighbor_bottom), guest, "ui_down from RECALL")
	assert_eq(guest.get_node(guest.focus_neighbor_top), recall, "ui_up back")
	assert_eq(recall.get_node(recall.focus_next), guest, "Tab after RECALL")
	await _assert_guest_layout(sr, "floor 3")
	(sr.call("open_recall") as Node).call("close")      # the Recall came and went: the room keeps its layout
	await wait_frames(4)
	assert_eq((sr.get("season_guest_buttons") as Dictionary).size(), 1)
	_dispose(sr)
	var st2: GameState = _season("calendar", "net", SEED_GUESTS, 2, 3 * DAY + 5 * HOUR)
	var sr2: Node = _screen(SAFE_ROOM, {"safe_room_id": str(SleepResolver.layout_of(st2, DB.data).safe_room_ids.values()
		.min())})
	await wait_frames(5)
	assert_false(bool(sr2.call("recall_available")), "floor 2: no Recall")
	assert_eq((sr2.get("season_guest_buttons") as Dictionary).size(), 2, "below one button both guests")
	await _assert_guest_layout(sr2, "floor 2")


## The guests' panel at every screen: inside the frame, apart from the menu and the buttons on the right, above the
## M.O.D. box (one box high and its speaker tab: the bottom right of the safe room, ModDialog.set_align_right).
func _assert_guest_layout(sr: Node, what: String) -> void:
	var panel: Control = sr.get("season_guests") as Control
	for res: Vector2i in RESOLUTIONS:
		for notch: bool in [false, true]:
			tree.root.size = res
			SafeAreaContainer.simulated_insets = NOTCH if notch else {}
			tree.root.size_changed.emit()
			await wait_frames(3)
			var tag: String = "%s %s notch=%s" % [what, str(res), notch]
			var rects: Dictionary = {"guests": panel.get_global_rect()}
			for id: Variant in (sr.get("menu_buttons") as Dictionary).keys():
				var b: Control = (sr.get("menu_buttons") as Dictionary)[id] as Control
				if b.is_visible_in_tree():
					rects["menu_" + str(id)] = b.get_global_rect()
			_no_overlap(rects, _frame(panel), tag)
			var vp: Vector2 = panel.get_viewport().get_visible_rect().size
			var mod_top: float = vp.y - 24.0 - ModDialogScript.BOX_BOTTOM - ModDialogScript.BOX_SIZE.y \
				- ModDialogScript.TAB_INSET.y
			assert_lt(panel.get_global_rect().end.y, mod_top, "above the M.O.D. box %s" % tag)
			var targets: Array[Control] = []
			for b2: Variant in (sr.get("season_guest_buttons") as Dictionary).values():
				targets.append(b2 as Control)
			_targets(targets, tag)
			_check_labels(panel, tag)
	tree.root.size = _saved_size
	SafeAreaContainer.simulated_insets = {}
	tree.root.size_changed.emit()
	await wait_frames(2)


## 09 §0.6 (floor 3: the Recall, "danach das Tempo-Angebot"): the offer hangs off the Recall's `closed` — after a first
## class choice, in a private calendar season, once on this device; never after "Später" without a choice, never Am
## Stück, never on entering a room.
func test_the_tempo_offer_after_the_first_class_choice() -> void:
	var st: GameState = _season("calendar", "net", 7, 3, HOUR)
	var sr: Node = _screen(SAFE_ROOM, {})               # the floor's first safe room: the Recall opens by itself
	assert_true(await wait_until(func() -> bool: return _recall_of(sr) != null, 60), "the Recall opens")
	(_recall_of(sr)).call("close")                      # "Später" without a choice
	await wait_frames(6)
	assert_false(_offer_open(sr), "no class chosen: no offer")
	assert_false(Save.career_seen("season_tempo_offer"))
	var rc: Node = sr.call("open_recall")               # the RECALL button
	assert_true(bool(rc.call("choose", 1)) and bool(rc.call("choose", 0)) and bool(rc.call("confirm")), "Kai chooses")
	await wait_frames(4)
	assert_false(_offer_open(sr), "not over the Recall")
	rc.call("close")                                    # the Count's choice waits ("Später")
	assert_true(await wait_until(func() -> bool: return _offer_open(sr), 30), "after the first class choice")
	var d: Node = sr.get("_modal")
	await wait_frames(2)
	assert_eq(tree.root.gui_get_focus_owner(), d.call("button", "calendar"), "staying is the default")
	assert_true(Save.career_seen("season_tempo_offer"), "once on this device")
	_check_screen(d, "tempo offer")
	var n0: int = Game.run_log.cmds().size()
	d.call("answer", "binge")
	await wait_frames(3)
	assert_eq(st.season.tempo, "binge", "recorded: season tempo")
	assert_eq(str((Game.run_log.cmds()[n0]["c"] as Dictionary).get("op", "")), "tempo")
	assert_null(sr.get("_modal"))
	assert_eq(tree.root.gui_get_focus_owner(), (sr.get("menu_buttons") as Dictionary)["recall"],
		"back on RECALL: the Count's choice waits, Kai may still change")
	_dispose(sr)
	_season("calendar", "net", 8, 3, HOUR)               # a second season on this device: no second offer
	var sr2: Node = _screen(SAFE_ROOM, {})
	assert_true(await wait_until(func() -> bool: return _recall_of(sr2) != null, 60))
	rc = _recall_of(sr2)
	assert_true(bool(rc.call("choose", 1)) and bool(rc.call("choose", 0)) and bool(rc.call("confirm")))
	rc.call("close")
	await wait_frames(10)
	assert_false(_offer_open(sr2), "only once on this device")
	_dispose(sr2)
	Save.career_set("seen", [])                          # a fresh device: Am Stück needs no offer
	_season("binge", "net", 9, 3, 0)
	var sr3: Node = _screen(SAFE_ROOM, {})
	assert_true(await wait_until(func() -> bool: return _recall_of(sr3) != null, 60))
	rc = _recall_of(sr3)
	assert_true(bool(rc.call("choose", 1)) and bool(rc.call("choose", 0)) and bool(rc.call("confirm")))
	rc.call("close")
	await wait_frames(10)
	assert_false(_offer_open(sr3), "Am Stück: nothing to offer")
	assert_false(Save.career_seen("season_tempo_offer"))


# --- texts ------------------------------------------------------------------------------------------------------------

func test_every_line_of_the_season_ui_exists() -> void:
	for tag: String in ["season_welcome", "season_collapse_intro", "season_warn_3600", "season_warn_600",
			"season_warn_60", "season_warn_last", "season_vest", "season_counter_in", "season_tempo_offer",
			"season_tempo_binge", "season_rival", "season_rival_after", "season_need",
			"season_left", "season_finale", "season_end", "season_out", "season_stairs_closed",
			"season_guest_extra", "season_guest_rival", "season_guest_helper", "season_guest_trader",
			"season_guest_unlucky"]:
		assert_gt(DB.mod_lines(tag).size(), 0, tag)
	for k: Variant in SeasonView.EXPLAIN.keys():
		assert_eq(UiUtil.missing_glyphs(str(SeasonView.EXPLAIN[k])), "", str(k))
		assert_lt(str(SeasonView.EXPLAIN[k]).length(), 140, "one sentence (09 §0.5): " + str(k))


# --- helpers ----------------------------------------------------------------------------------------------------------

## A season (slot 0: never saved) of the Basis template at NOW, number `number`, down the stairs to `floor` (the
## calendar opens floors 1–3 at the start), the clock `after` seconds past day 0 (recorded clock commands, quiet:
## replaying).
func _season(tempo: String, mode: String, seed: int, floor: int, after: int, number: int = 3) -> GameState:
	assert_true(Game.start_season(0, "ssn_basis", {"tempo": tempo, "mode": mode, "unlock": true, "seed": seed,
		"now": NOW, "tz_sec": 0, "number": number}))
	while Game.state.floor_run.index < floor:
		assert_true(Game.season_debug_descend())
	if tempo == "calendar" and after > 0:
		var s: SeasonState = Game.state.season
		Game.replaying = true
		while s.utc < s.day0_utc + after and s.result == "":
			Game.season_clock(mini(s.day0_utc + after - s.utc, SeasonClock.MAX_JUMP_SEC))
		Game.replaying = false
	return Game.state


func _screen(path: String, params: Dictionary) -> Node:
	var n: Node = (load(path) as PackedScene).instantiate()
	if n.has_method("setup"):
		n.call("setup", params)
	add_to_tree(n)
	return n


## The Recall modal of a safe room (null while it is not open).
static func _recall_of(r: Node) -> Node:
	for c: Node in r.get_children():
		if c.has_method("confirm") and c.has_signal("closed") and not c.is_queued_for_deletion():
			return c
	return null


## The tempo offer is the safe room's modal.
func _offer_open(sr: Node) -> bool:
	var m: Node = sr.get("_modal") as Node
	return m != null and is_instance_valid(m) and m.has_method("answer") and \
		_find_text(m, "Weiter wie im Fernsehen?") != null


## Every visible button of `root` is an 88 px target 12 px apart from the others, inside the safe frame; every
## visible label ≥ 16 px with drawn glyphs (03_ART F8) and, where it may trim, as wide as its text (no "…" in the
## states shown); the focus (if any) is inside.
func _check_screen(root: Node, tag: String) -> void:
	var targets: Array[Control] = []
	for c: Node in root.find_children("*", "BaseButton", true, false):
		if (c as Control).is_visible_in_tree():
			targets.append(c as Control)
	_targets(targets, tag)
	var frame: Rect2 = _frame(root)
	for t: Control in targets:
		assert_true(frame.grow(0.5).encloses(t.get_global_rect()), "%s inside the frame %s: %s" % [t.name, tag,
			str(t.get_global_rect())])
	_check_labels(root, tag)


## The labels of `root`: ≥ 16 px, every glyph drawn, a label that may trim as wide as its text.
func _check_labels(root: Node, tag: String) -> void:
	for c2: Node in root.find_children("*", "Label", true, false):
		var l: Label = c2 as Label
		if not l.is_visible_in_tree() or l.text.strip_edges() == "":
			continue
		assert_true(l.get_theme_font_size("font_size") >= 16, "%s '%s' ≥ 16 px %s" % [l.name, l.text.left(30), tag])
		assert_eq(UiUtil.missing_glyphs(l.text), "", "%s: '%s' %s" % [l.name, l.text.left(30), tag])
		_assert_not_cut(l, tag)


## A label that may trim ("…", one line) is as wide as its text.
func _assert_not_cut(l: Label, tag: String) -> void:
	if l.autowrap_mode != TextServer.AUTOWRAP_OFF or l.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING:
		return
	var shown: String = l.text.to_upper() if l.uppercase else l.text
	var w: float = l.get_theme_font("font").get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1,
		l.get_theme_font_size("font_size")).x
	assert_true(w <= l.size.x + 1.0, "%s '%s' not cut off %s (%.0f > %.0f px)" % [l.name, l.text.left(30), tag, w,
		l.size.x])


func _targets(targets: Array[Control], tag: String) -> void:
	for i in targets.size():
		var a: Rect2 = targets[i].get_global_rect()
		assert_true(a.size.x >= HIT - 0.5 and a.size.y >= HIT - 0.5, "%s ≥ 88 px %s: %s" % [targets[i].name, tag,
			str(a.size)])
		for j in range(i + 1, targets.size()):
			var b: Rect2 = targets[j].get_global_rect()
			var gap: float = maxf(maxf(b.position.x - a.end.x, a.position.x - b.end.x), maxf(b.position.y - a.end.y,
				a.position.y - b.end.y))
			assert_true(gap >= GAP - 0.5, "%s / %s %.1f px apart %s" % [targets[i].name, targets[j].name, gap, tag])


func _no_overlap(rects: Dictionary, frame: Rect2, tag: String) -> void:
	var keys: Array = rects.keys()
	for k: Variant in keys:
		assert_true(frame.grow(0.5).encloses(rects[k] as Rect2), "%s inside %s: %s" % [k, tag, str(rects[k])])
	for i in keys.size():
		for j in range(i + 1, keys.size()):
			var a: Rect2 = rects[keys[i]]
			var b: Rect2 = rects[keys[j]]
			assert_false(a.grow(-0.5).intersects(b.grow(-0.5)), "%s / %s overlap %s" % [keys[i], keys[j], tag])


## The safe frame of the canvas: 24 px edge (SafeAreaContainer.EDGE) plus the simulated notch insets.
func _frame(n: Node) -> Rect2:
	var vp: Vector2 = (n.get_viewport() if n.get_viewport() != null else tree.root).get_visible_rect().size
	var ins: Dictionary = SafeAreaContainer.simulated_insets
	var l: float = 24.0 + float(ins.get("left", 0))
	var r: float = 24.0 + float(ins.get("right", 0))
	return Rect2(l, 24.0, vp.x - l - r, vp.y - 48.0)


func _label_text(root: Node, node_name: String) -> String:
	var l: Label = root.find_child(node_name, true, false) as Label
	return l.text if l != null else ""


func _find_text(root: Node, text: String) -> Label:
	for c: Node in root.find_children("*", "Label", true, false):
		if (c as Label).text == text:
			return c as Label
	return null


func _find_text_part(root: Node, part: String) -> Label:
	for c: Node in root.find_children("*", "Label", true, false):
		if (c as Label).text.contains(part):
			return c as Label
	return null


func _current_is(path: String) -> bool:
	return Router.current != null and is_instance_valid(Router.current) and not Router.busy \
		and Router.current.scene_file_path == path


func _dispose(n: Node) -> void:
	if n == null or not is_instance_valid(n):
		return
	var was_current: bool = Router.current == n
	_nodes.erase(n)
	if n.get_parent() != null:
		n.get_parent().remove_child(n)
	n.free()
	if was_current or not is_instance_valid(Router.current):
		Router.adopt(null)


## Lets a transition finish, frees screens the Router created, leaves the Router empty (as test_sd_ui).
func _settle_router() -> void:
	for i in 600:
		if not Router.busy:
			break
		await tree.process_frame
	var cur: Node = Router.current
	if cur != null and is_instance_valid(cur) and not _nodes.has(cur):
		Router.goto(ROUTER_FIXTURE, {}, Router.Transition.NONE)
		for j in 240:
			if not Router.busy:
				break
			await tree.process_frame
		cur = Router.current
		if cur != null and is_instance_valid(cur):
			if cur.get_parent() != null:
				cur.get_parent().remove_child(cur)
			cur.free()
	Router.adopt(null)


static func _rmrf(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for f: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	for sub: String in DirAccess.get_directories_at(path):
		_rmrf(path.path_join(sub))
	DirAccess.remove_absolute(path)
