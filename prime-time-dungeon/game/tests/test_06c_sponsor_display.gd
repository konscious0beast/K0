extends TestCase
## 06-C — the five Sponsor-Fenster decisions of 06 §6 (05 §12.2 Nr. 4/13/17/18):
## 1 the overlay shows the window STATE (open + slot pips / full / next in ~N minutes) — no seconds countdown, no
##   urgency words; 2 fan packs need a window, cheers never do; 3 the boss countdown opens once more after a lost boss
##   attempt (comeback window: campaign save carry-over, recorded revisit, at most once per boss and floor, never after
##   the boss is beaten); 4 co-op: windows per team, slots per player (slots_per_player); 5 Twitch Bits only for free
##   interaction — never a gift source.

const OverlayScript := preload("res://scenes/ui/show_overlay.gd")
const DIR: String = "user://test_06c"
const TPS: int = 30

var _prev_data: GameData = null


func before_each() -> void:
	_prev_data = DB.data
	DB.data = real_data()
	Save.save_dir = DIR
	Save.read_only = false
	_clear_dir()


func after_each() -> void:
	if Game.state != null:
		Show.end_battle(null)
	Game.in_battle = false
	Game.timer_running = false
	Game.state = null
	Game.run_log = null
	Game.sim = null
	Game.mode = &"campaign"
	Game.clear_blocking_dialogs()
	_clear_dir()
	Save.save_dir = "user://saves"
	if _prev_data != null:
		DB.data = _prev_data
	_prev_data = null


func _clear_dir() -> void:
	var abs_dir: String = ProjectSettings.globalize_path(DIR)
	if DirAccess.dir_exists_absolute(abs_dir):
		for f: String in DirAccess.get_files_at(abs_dir):
			DirAccess.remove_absolute(abs_dir.path_join(f))


# --- decision 1: state, not a countdown -------------------------------------------------------------------------------

func test_next_window_in_rounded_minutes() -> void:
	assert_eq(OverlayScript.next_text(0), "in Kürze")
	assert_eq(OverlayScript.next_text(59), "in Kürze", "under a minute: no number at all")
	assert_eq(OverlayScript.next_text(60), "in ~1 Min.")
	assert_eq(OverlayScript.next_text(61), "in ~2 Min.", "rounded up ('~': battles and safe rooms pause it)")
	assert_eq(OverlayScript.next_text(300), "in ~5 Min.")


## Every view of a window gives a text without seconds (no "m:ss", no "Sekunden") and without scarcity words.
func test_badge_never_counts_seconds_or_pushes() -> void:
	var re: RegEx = RegEx.create_from_string("\\d:\\d\\d")
	var texts: PackedStringArray = []
	for mode: String in ["live", "subtle"]:
		for free: int in [0, 1, 3]:
			for left: int in [1, 9, 45, 90]:
				texts.append(OverlayScript.sponsor_text({"tracked": true, "mode": mode, "open": true, "left_sec": left,
					"slots": 3, "free": free, "full": free == 0}))
		for next: int in [0, 30, 59, 60, 192, 301]:
			texts.append(OverlayScript.sponsor_text({"tracked": true, "mode": mode, "open": false, "next_in_sec": next}))
	texts.append(OverlayScript.sponsor_text({"tracked": true, "mode": "live", "open": true, "slots": 3, "free": 2,
		"comeback": true}))
	for t: String in texts:
		assert_ne(t, "", "a badge text")
		assert_null(re.search(t), "no seconds countdown: '%s'" % t)
		for word: String in ["sekunde", "schnell", "nur noch", "letzte chance", "jetzt", "kauf"]:
			assert_false(t.to_lower().contains(word), "no urgency / purchase word '%s': '%s'" % [word, t])
	assert_has(texts, "COMEBACK-FENSTER OFFEN")
	assert_has(texts, "Sponsor-Fenster voll – danke!")


func test_slot_pips_in_the_overlay() -> void:
	Game.new_game(0, "Kai", 8181)
	var o: CanvasLayer = (load("res://scenes/ui/show_overlay.tscn") as PackedScene).instantiate() as CanvasLayer
	o.call("setup", {})
	add_to_tree(o)
	await wait_frames(1)
	o.call("set_mode", &"explore")
	o.call("show_sponsor_window", {"tracked": true, "mode": "live", "open": true, "slots": 3, "free": 1})
	assert_eq(o.call("sponsor_badge_pips"), "●●○", "2 of 3 taken")
	o.call("show_sponsor_window", {"tracked": true, "mode": "live", "open": true, "slots": 3, "free": 0, "full": true})
	assert_eq(o.call("sponsor_badge_pips"), "●●●")
	assert_eq(o.call("sponsor_badge_text"), "SPONSOR-FENSTER VOLL – danke!")
	o.call("show_sponsor_window", {"tracked": true, "mode": "live", "open": false, "next_in_sec": 200})
	assert_eq(o.call("sponsor_badge_pips"), "", "closed: no pips")
	assert_eq(o.call("sponsor_badge_text"), "Nächstes Fenster in ~4 Min.")
	o.queue_free()


# --- decision 2: fan packs need a window, cheers never ----------------------------------------------------------------

func test_fan_packs_need_a_window_cheers_never() -> void:
	Game.new_game(0, "Kai", 8282)
	var fan: Dictionary = Gift.make_dev("fan_pack", "", 0, "fan_a")
	assert_eq(Show.receive_gift(fan)["reason"], "window_closed", "a free fan pack is window-bound like a paid gift")
	assert_true(bool(Show.receive_gift(Gift.make_dev("cheer", "", 0, "fan_a"))["accepted"]),
		"cheers are always free and never need a window")
	assert_true(Game.open_dev_sponsor_window(60, 3))
	assert_true(bool(Show.receive_gift(Gift.make_dev("fan_pack", "", 0, "fan_b"))["accepted"]), "inside a window")
	assert_has(SponsorWindows.DEFAULT_RULES["exempt_kinds"] as Array, "cheer")
	assert_false((SponsorWindows.DEFAULT_RULES["exempt_kinds"] as Array).has("fan_pack"))


# --- decision 3: comeback window --------------------------------------------------------------------------------------

func _loss(kind_enc: String) -> BattleResult:
	var r: BattleResult = BattleResult.new()
	r.outcome = BattleResult.Outcome.DEFEAT
	r.is_boss = true
	r.encounter_id = kind_enc
	return r


func test_comeback_rules_unit() -> void:
	var d: GameData = real_data()
	var st: GameState = GameState.create_new(d, 0, "Kai", 9)
	var sim: RunSim = RunSim.new(d, st, {})
	sim.apply({"t": "floor", "floor": 1})
	var qb: String = d.floor_def(1).quarter_boss
	var kind: int = RoomCell.Kind.QUARTER_BOSS
	assert_false(SponsorWindows.comeback_due(st, {}, kind))
	assert_eq(SponsorWindows.on_room(st, {}, kind, false), [] as Array[Dictionary], "a revisit opens nothing")
	SponsorWindows.on_battle_result(st, {}, d, _loss(qb))
	assert_true(SponsorWindows.comeback_due(st, {}, kind), "a lost quarter boss attempt marks the comeback")
	assert_false(SponsorWindows.comeback_due(st, {}, RoomCell.Kind.FLOOR_BOSS), "only for that boss")
	var ev: Array[Dictionary] = SponsorWindows.on_room(st, {}, kind, false)
	assert_eq(ev.size(), 1)
	var w: Dictionary = ev[0]["window"]
	assert_eq([w["kind"], w["comeback"], w["left_sec"]], ["boss", true, 45], "the boss window once more, 45 s")
	assert_false(SponsorWindows.comeback_due(st, {}, kind), "used up")
	SponsorWindows.on_battle_result(st, {}, d, _loss(qb))
	assert_false(SponsorWindows.comeback_due(st, {}, kind), "at most once per boss and floor (not farmable)")
	# the floor boss: a win clears its mark
	var fb: String = d.floor_def(1).floor_boss
	SponsorWindows.on_battle_result(st, {}, d, _loss(fb))
	assert_true(SponsorWindows.comeback_due(st, {}, RoomCell.Kind.FLOOR_BOSS))
	var won: BattleResult = _loss(fb)
	won.outcome = BattleResult.Outcome.VICTORY
	SponsorWindows.on_battle_result(st, {}, d, won)
	assert_false(SponsorWindows.comeback_due(st, {}, RoomCell.Kind.FLOOR_BOSS), "never after the boss is beaten")
	# switched off, regular battles, a new floor
	var off: Dictionary = {"sponsor_windows": {"boss": {"comeback": 0}}}
	var st2: GameState = GameState.create_new(d, 0, "Kai", 10)
	RunSim.new(d, st2, {}).apply({"t": "floor", "floor": 1})
	SponsorWindows.on_battle_result(st2, off, d, _loss(qb))
	assert_false(SponsorWindows.comeback_due(st2, off, kind), "boss.comeback 0: off")
	var regular: BattleResult = _loss("enc_f1_a2")
	regular.is_boss = false
	SponsorWindows.on_battle_result(st2, {}, d, regular)
	assert_false(SponsorWindows.comeback_due(st2, {}, kind), "regular battles never")
	SponsorWindows.on_battle_result(st2, {}, d, _loss(qb))
	SponsorWindows.on_floor(st2, {})
	assert_false(SponsorWindows.comeback_due(st2, {}, kind), "a new floor forgets the marks")


func test_comeback_rules_validation() -> void:
	assert_eq(SponsorWindows.validate_rules({"boss": {"comeback": 1}}), PackedStringArray())
	assert_has("; ".join(SponsorWindows.validate_rules({"boss": {"comeback": 2}})), "boss.comeback must be <= 1")
	assert_has("; ".join(SponsorWindows.validate_rules({"boss": {"comeback": -1}})),
		"boss.comeback must be an integer >= 0")
	assert_eq(int((SponsorWindows.DEFAULT_RULES["boss"] as Dictionary)["comeback"]), 1, "on by default")


## Campaign: lose against the quarter boss → game over → load the last save (it already knows the boss room) → the
## next entry of the boss room opens the comeback window (recorded "room" command); once — a second defeat and reload
## never re-arm it.
func test_comeback_carries_over_the_game_over_into_the_save() -> void:
	Game.auto_battle = true
	Game.new_game(1, "Kai", 8383)
	var layout: FloorLayout = DungeonGenerator.generate(DB.floor_def(1), Game.state.floor_run.seed)
	var cell: Vector2i = layout.quarter_boss
	var opened: Array = []
	var cb: Callable = func(w: Dictionary) -> void: opened.append(w)
	Events.sponsor_window_opened.connect(cb)
	assert_true(Game.visit_room(cell), "first entry of the boss room")
	assert_eq(opened.size(), 1)
	assert_eq([str(opened[0]["kind"]), bool(opened[0]["comeback"])], ["boss", false], "the regular Boss-Countdown")
	assert_eq(Save.save_slot(1), OK, "saved with the boss room already visited")
	assert_false(_fight(DB.floor_def(1).quarter_boss), "a level-1 party loses against the Hausmeister")
	assert_true(SponsorWindows.comeback_due(Game.state, {}, RoomCell.Kind.QUARTER_BOSS))
	Game.on_game_over(&"defeat")
	assert_eq(Save.load_slot(1), OK)
	assert_true(SponsorWindows.comeback_due(Game.state, {}, RoomCell.Kind.QUARTER_BOSS), "carried into the save")
	opened.clear()
	var cmds_before: int = Game.run_log.size()
	assert_false(Game.visit_room(cell), "a revisit")
	assert_eq(opened.size(), 1, "the comeback window opens")
	assert_true(bool(opened[0]["comeback"]))
	assert_eq(Game.run_log.size(), cmds_before + 1, "recorded as a room command")
	assert_eq(str((Game.run_log.cmds().back() as Dictionary)["c"]["t"]), "room")
	opened.clear()
	Game.visit_room(cell)
	assert_eq(opened.size(), 0, "only once")
	assert_false(_fight(DB.floor_def(1).quarter_boss), "the second attempt is lost too")
	Game.on_game_over(&"defeat")
	assert_eq(Save.load_slot(1), OK)
	assert_false(SponsorWindows.comeback_due(Game.state, {}, RoomCell.Kind.QUARTER_BOSS),
		"a used comeback stays used — reloading never re-arms it")
	Events.sponsor_window_opened.disconnect(cb)
	Game.auto_battle = false


func test_comeback_line_in_the_live_presentation() -> void:
	Game.new_game(0, "Kai", 8484)
	Game.mode = &"event_offline"
	var tags: Array = []
	var cb: Callable = func(_t: String, _v: StringName, tag: String, _b: bool) -> void: tags.append(tag)
	Events.mod_said.connect(cb)
	Events.sponsor_window_opened.emit({"kind": "boss", "comeback": true, "open": true})
	Events.mod_said.disconnect(cb)
	assert_has(tags, "sponsor_window_open:boss_comeback")
	assert_gt(DB.data.mod_lines("sponsor_window_open:boss_comeback").size(), 0)


func _fight(enc_id: String) -> bool:
	var setup: BattleSetup = Game.make_battle_setup(enc_id, BattleSetup.Advantage.NORMAL, "")
	var battle: BattleState = BattleState.new(setup, DB.data)
	Show.begin_battle(setup)
	for e: ActionEvent in battle.start():
		Show.on_battle_event(e)
	var guard: int = 0
	while not battle.is_finished() and guard < 600:
		guard += 1
		var cmd: BattleCommand = battle.choose_ai_command()
		Game.record({"t": "battle", "cmd": cmd.to_dict(), "auto": true})
		for e: ActionEvent in battle.submit(cmd):
			Show.on_battle_event(e)
		if not battle.is_finished():
			var g: Dictionary = Show.take_pending_gift(battle)
			if not g.is_empty():
				for e2: ActionEvent in battle.apply_gift(g):
					Show.on_battle_event(e2)
	Game.apply_battle_result(battle.result)
	Show.end_battle(battle.result)
	return battle.result.outcome == BattleResult.Outcome.VICTORY


# --- decisions 4 and 5: co-op slots per player, Bits never a gift source ---------------------------------------------

## Decision 4 (S4): one window per team, `slots_per_player` slots per player; a solo run has one player.
func test_coop_slots_are_per_player() -> void:
	assert_eq(int(SponsorWindows.DEFAULT_RULES["slots_per_player"]), 3)
	assert_eq(SponsorWindows.team_slots({}, 1), 3, "solo")
	assert_eq(SponsorWindows.team_slots({}, 4), 12, "four players: 3 each, so nobody takes all the slots")
	assert_eq(SponsorWindows.team_slots({"sponsor_windows": {"slots_per_player": 2}}, 2), 4)


## Decision 5: Twitch Bits are free interaction only (votes, applause) — never a gift source of an event.
func test_bits_are_never_a_gift_source() -> void:
	assert_false(EventDef.EVENT_GIFT_SOURCES.has("bits"))
	var cat: EventCatalog = EventCatalog.new()
	cat.load_file("res://data/events.json")
	var raw: Dictionary = {}
	for e: Variant in (JsonUtil.read_file("res://data/events.json") as Dictionary)["events"]:
		raw = (e as Dictionary).duplicate(true)
	(raw["rules"] as Dictionary)["gifts"] = {"enabled": false, "sources": ["bits"]}
	var def: EventDef = EventDef.from_dict(raw)
	assert_has("; ".join(def.validate(real_data())), "'bits' is not offered")
