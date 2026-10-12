extends TestCase
## 10 §6.9 test_sd_ui (SD2-C … F): the Stempelduell's screens — the table, the Schalterhalle with the Akte, the
## Aktenschrank, the Stempelalbum, the title's Extras — instantiate with the focus inside; the table fits 1280 × 720,
## 1600 × 720, 1920 × 1080 and 2400 × 1080 for keyboard and touch, at text size 100–150 %, with notch insets and
## mirrored for left-handers: no overlap, hit areas ≥ 88 px, ≥ 12 px between them; ghost tickets follow the marked
## card; the keyboard / gamepad / touch mapping of 10 §4.6 (sd_file; Tab and Y only while the duel runs); static texts
## readable (≥ 16 / 20 px, drawn glyphs F8, no IP words); the save hook (own file, reset toast), the campaign ids
## (ids only), the procedural sounds, the overlay mode "duel" and the M.O.D. box beside the plates.

const TABLE: String = "res://scenes/stempel/sd_table.tscn"
const HALL: String = "res://scenes/stempel/sd_hall.tscn"
const CABINET: String = "res://scenes/stempel/sd_deck_builder.tscn"
const ALBUM: String = "res://scenes/stempel/sd_album.tscn"
const TITLE: String = "res://scenes/title/title.tscn"
const OVERLAY: String = "res://scenes/ui/show_overlay.tscn"
const DIALOG: String = "res://scenes/ui/mod_dialog.tscn"
const ROUTER_FIXTURE: String = "res://tests/fixtures/router/router_screen.tscn"
const ROOT: String = "user://test_sd_ui"
const SdSession := preload("res://scenes/stempel/sd_session.gd")
const SdLayout := preload("res://scenes/stempel/sd_layout.gd")
const SdStyle := preload("res://scenes/stempel/sd_style.gd")
const SdTexts := preload("res://scenes/stempel/sd_texts.gd")
const SdPlate := preload("res://scenes/stempel/sd_plate.gd")
const SdHallAkte := preload("res://scenes/stempel/sd_hall_akte.gd")
const SdExtras := preload("res://scenes/stempel/sd_extras.gd")
const IpWords := preload("res://core/data/validators/ip_words.gd")
const SdValidator := preload("res://core/stempel/validators/sd_validator.gd")
const UiUtil := preload("res://scenes/ui/ui_util.gd")
## The four test resolutions (stretch canvas_items, aspect expand: 1920 × 1080 → canvas 1280 × 720,
## 2400 × 1080 → 1600 × 720).
const RESOLUTIONS: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1600, 720), Vector2i(1920, 1080),
	Vector2i(2400, 1080)]
const NOTCH: Dictionary = {"left": 48, "top": 0, "right": 48, "bottom": 0}
const HIT: float = 88.0
const GAP: float = 12.0

var _saved_size: Vector2i
var _saved_scheme: int
var _saved_dir: String


func before_each() -> void:
	_saved_size = tree.root.size
	_saved_scheme = Game.input_scheme
	_saved_dir = Save.save_dir
	Save.save_dir = ROOT + "/saves"
	SdSession.reset()
	SdSession.ephemeral = true


func after_each() -> void:
	Engine.time_scale = 1.0
	tree.paused = false
	SafeAreaContainer.simulated_insets = {}
	tree.root.size = _saved_size
	Game.set_input_scheme(_saved_scheme)
	await _settle_router()
	SdSession.reset()
	SdSession.ephemeral = false
	Save.save_dir = _saved_dir
	CombatInput.apply_for_game()
	_rmrf(ROOT)


# --- screens ----------------------------------------------------------------------------------------------------------

func test_screens_instantiate_with_the_focus_inside() -> void:
	SdSession.use(_collection())
	for path: String in [HALL, CABINET, ALBUM]:
		var n: Node = (load(path) as PackedScene).instantiate()
		n.call("setup", {"mute": true})
		add_to_tree(n)
		var ok: bool = await wait_until(func() -> bool:
			var f: Control = tree.root.gui_get_focus_owner()
			return f != null and n.is_ancestor_of(f) and f.is_visible_in_tree(), 30)
		assert_true(ok, "%s: a control inside has the focus (02_TECH §10.2)" % path.get_file())
		assert_eq(_bad_glyphs(n), PackedStringArray(), "%s: drawn glyphs only (F8)" % path.get_file())
		assert_eq(_small_texts(n, 16), PackedStringArray(), "%s: texts >= 16 px" % path.get_file())
		assert_eq(_small_buttons(n), PackedStringArray(), "%s: buttons >= 88 px" % path.get_file())
		_dispose(n)
	var t: Node = await _table()
	var f2: Control = tree.root.gui_get_focus_owner()
	assert_true(f2 != null and t.is_ancestor_of(f2), "table: the marked card has the focus")
	assert_eq(_bad_glyphs(t), PackedStringArray(), "table: glyphs")
	assert_eq(_small_texts(t, 16), PackedStringArray(), "table: texts >= 16 px")


func test_the_hall_lists_the_opponents_and_opens_the_akte() -> void:
	var c: SdCollection = _collection()
	SdSession.use(c)
	var h: Node = (load(HALL) as PackedScene).instantiate()
	h.call("setup", {"mute": true})
	add_to_tree(h)
	await wait_frames(3)
	var tickets: Dictionary = h.get("tickets")
	assert_eq(tickets.keys().size(), SdSession.book().opponent_ids.size(), "one Wartemarke per opponent")
	var state: Callable = func(oid: String) -> String:
		return ((tickets[oid] as Node).find_child("State", true, false) as Label).text
	assert_eq(state.call("sdo_ferdi"), "NEU")
	assert_eq(state.call("sdo_graf"), "Übungsduell")
	assert_eq(state.call("sdo_ulla"), "Erst nach einem Sieg gegen Ferdi Durchschlag.", "a locked one names the way")
	h.call("open_akte", "sdo_ulla")
	await wait_frames(2)
	var m: Node = h.get("modal")
	assert_not_null(m, "the Akte opens for a locked opponent too")
	assert_not_null(m.find_child("Locked", true, false), "… with the way there and no start button")
	assert_null(m.find_child("Start", true, false))
	m.call("close")
	await wait_frames(2)
	h.call("open_akte", "sdo_ferdi")
	await wait_frames(2)
	m = h.get("modal")
	var start: Button = m.find_child("Start", true, false) as Button
	assert_true(start != null and not start.disabled, "Duell starten with the Startmappe")
	var b: Button = m.find_child("MappeB", true, false) as Button
	b.emit_signal("pressed")
	await wait_frames(1)
	assert_true(start.disabled, "an empty Mappe B cannot start")
	var info: Label = m.find_child("Info", true, false) as Label
	assert_true(info.text.contains(c.deck_problem(c.deck("b"), SdSession.book())), "the Aktenschrank's sentence")
	m.call("close")
	await wait_frames(2)


func test_the_grafs_tip_fits_the_akte_and_writes_a_copy() -> void:
	var b: SdRulebook = SdSession.book()
	var c: SdCollection = _collection()
	var ulla: SdOpponentDef = b.opponent("sdo_ulla")
	var sug: PackedStringArray = SdHallAkte.passend(c, b, ulla, c.deck("a"))
	assert_eq(c.deck_problem(sug, b), "", "the suggestion is a valid Mappe")
	assert_eq(sug.count("sdc_wiedervorlage"), 0, "no Wiedervorlage against an opponent immune to it")
	assert_lt(_art_count(b, sug, "stempel"), _art_count(b, c.deck("a"), "stempel"), "fewer Stempel against Ulla")
	assert_eq(SdHallAkte.passend(c, b, ulla, sug), sug, "a fitting Mappe stays as it is")
	var ferdi: SdOpponentDef = b.opponent("sdo_ferdi")
	assert_eq(SdHallAkte.passend(c, b, ferdi, c.deck("a")).count("sdc_adelsflamme"), 2,
		"his wunder Punkt: the second Adelsflamme")
	c.beaten = {"sdo_ferdi": 1}
	SdSession.use(c)
	var h: Node = (load(HALL) as PackedScene).instantiate()
	h.call("setup", {"mute": true})
	add_to_tree(h)
	await wait_frames(3)
	h.call("open_akte", "sdo_ulla")
	await wait_frames(2)
	var m: Node = h.get("modal")
	var take: Button = m.find_child("TakeTip", true, false) as Button
	assert_true(take != null and not take.disabled, "the tip offers a change")
	assert_true((m.find_child("Tip", true, false) as Label).text.begins_with("Graf Mopsula: Fußnote"),
		"the Graf's line from sd_akte:ulla")
	take.emit_signal("pressed")
	await wait_frames(2)
	assert_eq(c.deck("b"), SdHallAkte.passend(c, b, ulla, c.deck("a")), "written into the empty Mappe B, A stays")
	assert_eq(c.deck("a"), b.startmappe_list())
	m.call("close")
	await wait_frames(2)


func test_the_deck_builder_edits_and_keeps_the_rules() -> void:
	var c: SdCollection = _collection()
	SdSession.use(c)
	var d: Node = (load(CABINET) as PackedScene).instantiate()
	d.call("setup", {"mappe": "b"})
	add_to_tree(d)
	await wait_frames(3)
	assert_eq((d.get("tiles") as Dictionary).size(), c.owned.size(), "every owned card in the grid")
	assert_true(bool(d.call("add_card", "sdc_stempel")) and bool(d.call("add_card", "sdc_stempel")))
	assert_eq(c.deck("b").count("sdc_stempel"), 2, "saved into the collection at once")
	var banner: Label = d.get("_banner") as Label
	assert_eq(banner.text, c.deck_problem(c.deck("b"), SdSession.book()), "the Aktenschrank's sentence")
	assert_false(bool(d.call("add_card", "sdc_stempel")), "two copies at most")
	assert_true(banner.text.contains("mehr geht nicht"), "… and the banner says why")
	d.call("auto_fill")
	assert_eq(c.deck("b").size(), SdSession.book().deck_size(), "Automatisch füllen up to 20")
	assert_eq(c.deck_problem(c.deck("b"), SdSession.book()), "")
	d.call("make_active")
	assert_eq(c.active, "b", "Aktiv setzen")
	assert_true(bool(d.call("remove_card", "sdc_stempel")))
	assert_eq(c.deck("b").count("sdc_stempel"), 1, "a row takes one copy out")
	d.call("ask_clear")
	await wait_frames(2)
	assert_eq(c.deck("b").size(), SdSession.book().deck_size() - 1, "nothing is emptied without a confirmation")
	var dlg: Node = d.get("modal")
	assert_not_null(dlg, "Leeren asks first")
	if dlg != null:
		dlg.call("answer", true)
	await wait_frames(2)
	assert_eq(c.deck("b").size(), 0, "… then the Mappe is empty")
	d.set("filter_art", "eilt")
	d.call("_rebuild_grid")
	for cid: String in (d.get("tiles") as Dictionary).keys():
		assert_eq(SdSession.book().card(cid).art, "eilt", "the art filter")


func test_the_album_shows_owned_cards_outlines_and_the_way_there() -> void:
	var c: SdCollection = _collection()
	SdSession.use(c)
	var a: Node = (load(ALBUM) as PackedScene).instantiate()
	a.call("setup", {"page": "graf"})
	add_to_tree(a)
	await wait_frames(3)
	var missing: int = 0
	for it: Control in a.get("items"):
		if it.has_meta("missing"):
			missing += 1
			assert_ne(str(a.call("way_to", str(it.get_meta("card")))), "Noch kein Weg bekannt.", "a way for %s"
				% str(it.get_meta("card")))
	assert_gt(missing, 0, "the Graf's page has outlines")
	assert_true(str(a.call("way_to", "sdc_gutachten")).contains("Erster Sieg gegen Graf Mopsula"))
	assert_true(str(a.call("way_to", "sdc_frostniesen")).contains("Stempelheft: noch 3 Siege"))
	assert_true(str(a.call("way_to", "sdc_frostniesen")).contains("Der Graf lernt Frostniesen"))
	for p: String in ["amt", "kandidat", "graf", "gegenstand", "talent", "trophaee", "heft", "awards", "cosmetics"]:
		a.call("show_page", p)
		await wait_frames(1)
		assert_eq(str(a.get("page")), p)
		assert_eq(_bad_glyphs(a), PackedStringArray(), "album page %s: glyphs" % p)
	var b2: Button = a.find_child("Cos_sdk_back_durchschlag", true, false) as Button
	assert_not_null(b2, "the Lernduell's card back can be put on")
	if b2 != null:
		b2.emit_signal("pressed")
		await wait_frames(2)
		assert_eq(str(c.cosmetics["back"]), "sdk_back_durchschlag", "equipped")


func test_the_title_has_extras_beside_event_lauf() -> void:
	var t: Node = (load(TITLE) as PackedScene).instantiate()
	add_to_tree(t)
	await wait_frames(4)
	var ex: Button = t.get("extras_button") as Button
	var ev: Button = (t.get("menu_buttons") as Dictionary)["event"] as Button
	assert_not_null(ex, "Extras in the title menu")
	if ex == null:
		return
	var er: Rect2 = ev.get_global_rect()
	var xr: Rect2 = ex.get_global_rect()
	assert_almost(xr.position.y, er.position.y, 0.5, "same row as Event-Lauf")
	assert_true(xr.position.x >= er.end.x + GAP - 0.5, "right of it, 12 px apart")
	assert_true(xr.size.y >= float(UiTheme.MIN_TOUCH) and xr.size.x >= 120.0, "a full button")
	assert_eq(ev.get_node(ev.focus_neighbor_right), ex, "Event-Lauf → Extras")
	assert_false((t.call("menu_ids") as PackedStringArray).has("extras"), "the menu column keeps its entries")
	ex.emit_signal("pressed")
	await wait_frames(2)
	var m: Node = t.get("_modal")
	assert_not_null(m, "Extras opens over the title")
	var sd: Button = m.find_child("Stempelduell", true, false) as Button if m != null else null
	assert_true(sd != null and sd.text == "Stempelduell (Vorschau)")
	var f: Control = tree.root.gui_get_focus_owner()
	assert_eq(f, sd, "the entry has the focus")


## Titel → Extras → Schalterhalle → Duell → Ergebnis → Revanche → Zurück → Titel, through the Router (FADE).
func test_from_the_title_to_a_duel_and_back() -> void:
	Engine.time_scale = 8.0
	var c: SdCollection = _collection()
	SdSession.use(c)
	var t: Node = (load(TITLE) as PackedScene).instantiate()
	add_to_tree(t)
	await wait_frames(3)
	(t.get("extras_button") as Button).emit_signal("pressed")
	await wait_frames(2)
	var ex: Node = t.get("_modal")
	assert_not_null(ex, "the Extras menu")
	if ex == null:
		return
	(ex.find_child("Stempelduell", true, false) as Button).emit_signal("pressed")
	if not await wait_until(func() -> bool: return _current_is(HALL), 600):
		return
	var h: Node = Router.current
	assert_false(t.is_inside_tree(), "the title (3D studio) is detached under the hall")
	h.call("start_duel", "sdo_ferdi", "a")
	if not await wait_until(func() -> bool: return _current_is(TABLE), 600):
		return
	var tb: Node = Router.current
	assert_eq(c.n, 1, "the seed counter moved before the duel (10 §6.6)")
	await wait_until(func() -> bool: return _waits_for_player(tb), 1200)
	tb.call("forfeit")
	await wait_until(func() -> bool: return tb.get("results") != null, 600)
	assert_eq(str((tb.get("duel") as SdDuel).summary()["result"]), "forfeit", "Antrag zurückgezogen")
	var first_id: int = tb.get_instance_id()             # the first table is freed: compare ids, never the object
	tb.call("rematch")
	var again: bool = await wait_until(func() -> bool:
		return _current_is(TABLE) and Router.current.get_instance_id() != first_id, 900)
	assert_true(again, "Revanche: a new duel")
	if not again:
		return
	var tb2: Node = Router.current
	assert_eq(str(tb2.get("opp_id")), "sdo_ferdi", "against the same opponent")
	assert_eq(c.n, 2, "with a fresh seed")
	tb2.call("leave")
	await wait_until(func() -> bool: return Router.current == h and not Router.busy, 600)
	h.call("leave")
	var back: bool = await wait_until(func() -> bool: return Router.current == t and not Router.busy, 600)
	assert_true(back, "back on the title")
	await wait_frames(3)
	assert_eq(tree.root.gui_get_focus_owner(), t.get("extras_button"), "the focus on Extras again")
	assert_false(_has_key(&"map", KEY_TAB), "the game's input map again")


# --- layout -----------------------------------------------------------------------------------------------------------

## The pure layout for every canvas, scheme, text size, notch and hand: fits, inside the frame, no overlap, the hit
## areas and the gaps.
func test_the_table_layout_fits_every_screen() -> void:
	var b: SdRulebook = SdSession.book()
	var duties: Array[Dictionary] = _duties(b.opponent("sdo_ulla"))
	var frames: Array[Vector2] = []
	for canvas: Vector2 in [Vector2(1280, 720), Vector2(1600, 720)]:
		frames.append(canvas - Vector2(48, 48))
		frames.append(canvas - Vector2(48 + 96, 48))         # notch insets left and right
	for fsz: Vector2 in frames:
		for touch: bool in [false, true]:
			for ts: int in [100, 125, 150]:
				for lh: bool in [false, true]:
					for open: bool in [false, true]:
						var r: Dictionary = SdLayout.compute(fsz.x, fsz.y, touch, ts, lh, open, b, duties)
						var tag: String = "%s touch=%s %d%% lh=%s open=%s" % [str(fsz), touch, ts, lh, open]
						assert_true(bool(r["fits"]), "fits: " + tag)
						_check_rects(SdLayout.element_rects(r), fsz, tag)
						assert_true(int(r["mod_font"]) >= SdStyle.min_text(touch), "M.O.D. font: " + tag)
						var hand: Rect2 = r["hand"]
						if lh:
							assert_lt((r["stempeln"] as Rect2).end.x, hand.position.x, "mirrored: " + tag)
							assert_gt((r["ablage"] as Rect2).position.x, hand.end.x, "mirrored: " + tag)
						else:
							assert_lt((r["ablage"] as Rect2).end.x, hand.position.x, tag)
							assert_gt((r["stempeln"] as Rect2).position.x, hand.end.x, tag)


## The table scene at the four resolutions (and with notch insets): the drawn elements do not overlap, sit inside
## the safe frame, every button and card is a ≥ 88 px target, 12 px apart.
func test_the_table_scene_at_four_resolutions_and_with_a_notch() -> void:
	for res: Vector2i in RESOLUTIONS:
		for touch: bool in [false, true]:
			for notch: bool in [false, true]:
				tree.root.size = res
				SafeAreaContainer.simulated_insets = NOTCH if notch else {}
				var t: Node = await _table({"touch": touch, "opp": "sdo_ulla"})
				await wait_frames(2)
				var tag: String = "%s touch=%s notch=%s" % [str(res), touch, notch]
				var vp: Vector2 = t.get_viewport().get_visible_rect().size
				var expected_w: float = 720.0 * float(res.x) / float(res.y)
				assert_almost(vp.x, expected_w, 1.0, "canvas %s" % tag)
				var rects: Dictionary = _scene_rects(t)
				var inset: float = 48.0 if notch else 0.0
				var frame: Rect2 = Rect2(24.0 + inset, 24.0, vp.x - 48.0 - 2.0 * inset, vp.y - 48.0)
				_check_rects(rects, frame.size, tag, frame.position)
				for i in 5:
					var v: Control = (t.get("hand") as Node).call("view", i) as Control
					if v != null:
						assert_true(v.size.x >= HIT and v.size.y >= HIT, "card %d is a target %s" % [i, tag])
				assert_eq(_small_texts(t, SdStyle.min_text(touch)), PackedStringArray(), "text sizes " + tag)
				_dispose(t)
				await wait_frames(1)


func test_left_handers_get_the_mirrored_table() -> void:
	var t: Node = await _table({"left_handed": true})
	var hand: Rect2 = (t.get("hand") as Control).get_global_rect()
	assert_lt((t.get("stempeln_button") as Control).get_global_rect().end.x, hand.position.x, "STEMPELN left")
	assert_gt((t.get("ablage_button") as Control).get_global_rect().position.x, hand.end.x, "ABLAGE right")
	_dispose(t)
	var t2: Node = await _table({"left_handed": false})
	hand = (t2.get("hand") as Control).get_global_rect()
	assert_lt((t2.get("ablage_button") as Control).get_global_rect().end.x, hand.position.x, "ABLAGE left")


## Text size 150 %: the card texts stay inside their cards and above the scheme's minimum, the compact card shows
## name, Werktage and the main effect only; the table's labels too.
func test_static_texts_stay_readable_at_150_percent() -> void:
	for touch: bool in [false, true]:
		var t: Node = await _table({"text_size": 150, "touch": touch})
		var hand: Node = t.get("hand")
		for i in 5:
			var v: Control = hand.call("view", i) as Control
			if v == null:
				continue
			assert_true(bool(v.call("is_compact")), "compact card at 150 %")
			for blk: Dictionary in v.call("text_blocks"):
				assert_true(int(blk["size"]) >= SdStyle.min_text(touch), "card text %s px" % str(blk["size"]))
				var tw: float = (blk["font"] as Font).get_string_size(str(blk["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1,
					int(blk["size"])).x
				assert_true(tw <= v.size.x - 2.0 * 6.0 + 0.5, "'%s' inside the card" % str(blk["text"]))
		assert_eq(_small_texts(t, SdStyle.min_text(touch)), PackedStringArray(), "table labels touch=%s" % touch)
		_dispose(t)
	var v: SdValidator = SdValidator.new()
	v.check({})                                           # compiles its word patterns (the files are not needed)
	for text: String in SdTexts.all_texts():
		assert_eq(UiUtil.missing_glyphs(text), "", "glyphs: " + text)
		assert_eq(IpWords.general_word(text), "", "IP words: " + text)
		assert_eq(v.text_problem(text, false), "", "the rulebook's text rules (DCC terms, authorities, F8): " + text)


# --- the duel's controls --------------------------------------------------------------------------------------------

func test_ghost_tickets_follow_the_marked_card() -> void:
	var t: Node = await _table({"instant": false})
	await wait_until(func() -> bool: return _waits_for_player(t), 600)
	var board: Node = t.get("board")
	var hand: Node = t.get("hand")
	var duel: SdDuel = t.get("duel") as SdDuel
	hand.call("mark", 0, true)
	await wait_frames(1)
	var p: Dictionary = duel.preview({"op": "play", "slot": 0})
	var ghosts: Array[String] = []
	for tk: Dictionary in board.call("tickets"):
		if bool(tk["ghost"]):
			ghosts.append(str(tk["id"]))
	assert_true(ghosts.has(SdDuel.PLAYER_ID) and ghosts.has(SdDuel.OPPONENT_ID), "both next numbers as ghosts")
	assert_eq((board.get("ghost_order") as PackedStringArray), p["order"] as PackedStringArray, "the dry run's order")
	t.call("set_file_mode", true)
	await wait_frames(1)
	assert_eq((board.get("ghost_order") as PackedStringArray),
		duel.preview({"op": "file", "slot": int(hand.get("marked_slot"))})["order"] as PackedStringArray,
		"Abheften shows its own preview")
	t.call("set_file_mode", false)
	assert_eq(duel.state_hash(), (t.get("duel") as SdDuel).state_hash(), "previews never change the duel")


func test_keyboard_gamepad_and_touch_follow_10_4_6() -> void:
	var file_keys: Array[int] = []
	var file_pad: Array[int] = []
	for e: InputEvent in InputMap.action_get_events(&"sd_file"):
		if e is InputEventKey:
			file_keys.append(int((e as InputEventKey).physical_keycode))
		elif e is InputEventJoypadButton:
			file_pad.append(int((e as InputEventJoypadButton).button_index))
	assert_true(file_keys.has(KEY_X) and file_keys.has(KEY_BACKSPACE), "sd_file: X and Backspace")
	assert_eq(file_pad, [JOY_BUTTON_X], "sd_file: pad X")
	assert_false(_has_key(&"map", KEY_TAB), "outside the duel Tab is no map key (07 §7.7)")
	var t: Node = await _table()
	assert_true(_has_key(&"map", KEY_TAB) and _has_pad(&"toggle_auto", JOY_BUTTON_Y), "the duel: Tab and Y (10 §4.6)")
	var hand: Node = t.get("hand")
	var duel: SdDuel = t.get("duel") as SdDuel
	var v0: Control = hand.call("view", 0) as Control
	assert_eq(v0.get_node(v0.focus_neighbor_right), hand.call("view", 1), "Right marks the next card")
	t.call("_unhandled_input", _key(KEY_3))
	assert_eq(int(hand.get("marked_slot")), 2, "the digit 3 marks the third card")
	t.call("_unhandled_input", _action(&"sd_file"))
	assert_true(bool(t.get("file_mode")), "X: Abheften mode")
	t.call("_unhandled_input", _action(&"ui_cancel"))
	assert_false(bool(t.get("file_mode")), "Esc / B: back")
	t.call("_unhandled_input", _action(&"toggle_speed"))
	assert_eq(int(t.get("speed")), 2, "R / R3: Tempo × 2")
	t.call("_unhandled_input", _action(&"toggle_speed"))
	t.call("_input", _action(&"map"))
	await wait_frames(1)
	var m: Node = t.get("modal")
	assert_true(m != null and str(m.name) != "Menu", "Tab / M / Select: the big view")
	if m != null:
		m.call("close")
	await wait_frames(1)
	t.call("_unhandled_input", _action(&"pause"))
	await wait_frames(1)
	m = t.get("modal")
	assert_true(m != null and str(m.name) == "Menu", "Esc / P / Start: the menu")
	if m != null:
		m.call("close")
	await wait_frames(1)
	var ticket: int = duel.ticket()
	t.call("_unhandled_input", _action(&"ui_accept"))
	await wait_until(func() -> bool: return duel.ticket() > ticket, 60)
	assert_gt(duel.ticket(), ticket, "Enter / A plays the marked card")
	await wait_until(func() -> bool: return _waits_for_player(t), 120)
	var count: int = (t.get("duel_log") as SdLog).moves.size()
	hand.call("simulate_tap", 1)
	assert_eq((t.get("duel_log") as SdLog).moves.size(), count, "touch: the first tap marks only")
	assert_eq(int(hand.get("marked_slot")), 1)
	hand.call("simulate_tap", 1)
	await wait_until(func() -> bool: return (t.get("duel_log") as SdLog).moves.size() > count, 60)
	assert_eq(str(((t.get("duel_log") as SdLog).moves.back() as Dictionary)["op"]), "play", "the second tap plays")
	await wait_until(func() -> bool: return _waits_for_player(t), 120)
	count = (t.get("duel_log") as SdLog).moves.size()
	var abl: Control = t.get("ablage_button") as Control
	hand.call("simulate_drag", 0, abl.get_global_rect().get_center())
	await wait_until(func() -> bool: return (t.get("duel_log") as SdLog).moves.size() > count, 60)
	assert_eq(str(((t.get("duel_log") as SdLog).moves.back() as Dictionary)["op"]), "file", "drag onto ABLAGE files")
	await wait_until(func() -> bool: return _waits_for_player(t), 120)
	t.call("_unhandled_input", _action(&"toggle_auto"))
	assert_true(bool(t.get("auto")), "T / Y: the Graf takes over")
	_dispose(t)
	await wait_frames(1)
	assert_false(_has_key(&"map", KEY_TAB), "leaving the duel restores the game's map")


# --- hooks: save, campaign, sounds, overlay, M.O.D. box ---------------------------------------------------------------

func test_the_save_hook_keeps_its_own_file_and_toasts_a_reset() -> void:
	SdSession.ephemeral = false
	var c: SdCollection = SdSession.collection()
	assert_gt(c.seed, 0, "the account seed is rolled once (outside core/)")
	c.complete_tutorial(SdSession.book())
	SdSession.save()
	var path: String = Save.sd_collection_path()
	assert_true(path.begins_with(ROOT) and path.ends_with("stempel/collection.json"), "own file next to the saves")
	assert_true(FileAccess.file_exists(path))
	var raw: String = FileAccess.get_file_as_string(path)
	assert_false(raw.contains("Kai") or raw.contains("Ferdi"), "ids and numbers only, no names (10 §6.7)")
	SdSession.reset()
	var again: SdCollection = SdSession.collection()
	assert_eq(again.to_dict(), c.to_dict(), "round trip")
	assert_false(SdSession.take_reset_notice())
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{kaputt")
	f.close()
	DirAccess.remove_absolute(path + ".bak")
	SdSession.reset()
	var toasts: Array[String] = []
	var cb: Callable = func(text: String, _icon: StringName) -> void: toasts.append(text)
	Events.toast_requested.connect(cb)
	var h: Node = (load(HALL) as PackedScene).instantiate()
	h.call("setup", {"mute": true, "no_welcome": true})
	add_to_tree(h)
	await wait_frames(2)
	Events.toast_requested.disconnect(cb)
	assert_has(toasts, SdSession.MSG_RESET, "„Stempelakte neu angelegt“")
	assert_false(SdSession.collection().tutorial, "an empty collection")


func test_campaign_unlocks_read_ids_only() -> void:
	var st: Dictionary = {"party": [{"id": "kai", "level": 1, "skills": ["skl_kai_first_aid"], "talents":
		{"tal_kai_kaffee": 1}, "equipment": {}}], "inventory": {"counts": {"itm_antidote": 2, "itm_bandage": 0}}}
	var ids: PackedStringArray = []
	SdSession.ids_of_state(st, ids)
	assert_has(ids, "skl_kai_first_aid")
	assert_has(ids, "tal_kai_kaffee")
	assert_has(ids, "itm_antidote")
	assert_false(ids.has("itm_bandage"), "only items held")
	var c: SdCollection = _collection()
	var fresh: PackedStringArray = c.apply_campaign(ids, SdSession.book())
	assert_has(fresh, "sdc_erste_hilfe")
	assert_has(fresh, "sdc_kaffee")
	assert_has(fresh, "sdc_gegengift")


func test_the_sounds_and_the_waiting_room_loop_build() -> void:
	for id: String in SfxSynth.SD_SFX_IDS:
		var s: AudioStreamWAV = SfxSynth.make_sd(StringName(id))
		assert_true(s != null and s.data.size() > 1000, "sound %s" % id)
		assert_eq(s.loop_mode, AudioStreamWAV.LOOP_DISABLED, id)
	for id2: String in SfxSynth.SD_MUSIC_IDS:
		var m: AudioStreamWAV = SfxSynth.make_sd_music(StringName(id2))
		assert_true(m != null and m.data.size() > 10000, "loop %s" % id2)
		assert_ne(m.loop_mode, AudioStreamWAV.LOOP_DISABLED, "%s loops" % id2)
	var t: Node = await _table({"instant": false})
	var audio: Node = t.get("audio")
	assert_eq(audio.call("current_music"), &"sd_wartezimmer", "the waiting-room loop")
	await wait_until(func() -> bool: return (audio.get("played") as PackedStringArray).has("sd_shuffle"), 120)
	assert_has(audio.get("played"), "sd_shuffle", "a sound with every visible event")


func test_the_overlay_shows_the_duel_and_the_box_sits_beside_the_plates() -> void:
	var ov: Node = (load(OVERLAY) as PackedScene).instantiate()
	add_to_tree(ov)
	var dl: Node = (load(DIALOG) as PackedScene).instantiate()
	add_to_tree(dl)
	await wait_frames(2)
	var t: Node = await _table()
	await wait_frames(3)
	assert_true(bool(ov.call("is_duel_mode")), "overlay mode duel")
	assert_eq(str(ov.call("duel_corner_text")), "STEMPELDUELL · Schalter 3")
	var lay: Dictionary = dl.call("subtitle_layout")
	var mod: Rect2 = (t.get("layout") as Dictionary)["mod"]
	assert_almost(float(lay.get("width", 0.0)), mod.size.x, 0.5, "the box is as wide as its slot")
	assert_true(lay.has("font") and int(lay["font"]) >= 18, "the duel's text size")
	assert_false(bool(lay.get("blocking", true)), "never blocking")
	Events.overlay_mode_requested.emit(&"menu")
	await wait_frames(2)
	assert_false(bool(ov.call("is_duel_mode")))
	assert_eq(str(ov.call("duel_corner_text")), "", "the corner goes with the mode")
	_dispose(t)
	await wait_frames(2)
	assert_true((dl.call("subtitle_layout") as Dictionary).is_empty(), "the normal box again")


# --- helpers ----------------------------------------------------------------------------------------------------------

## A collection after the Lernduell.
func _collection() -> SdCollection:
	var c: SdCollection = SdCollection.create(4711)
	c.complete_tutorial(SdSession.book())
	return c


## A table (instant: no waits) waiting for the player's first number.
func _table(extra: Dictionary = {}) -> Node:
	var params: Dictionary = {"opp": "sdo_ferdi", "mappe": "a", "seed": 4242, "collection": _collection(),
		"instant": true}
	params.merge(extra, true)
	var t: Node = (load(TABLE) as PackedScene).instantiate()
	t.call("setup", params)
	add_to_tree(t)
	await wait_until(func() -> bool: return _waits_for_player(t), 240)
	return t


func _current_is(path: String) -> bool:
	return Router.current != null and is_instance_valid(Router.current) and not Router.busy \
		and Router.current.scene_file_path == path


func _waits_for_player(t: Node) -> bool:
	var d: SdDuel = t.get("duel") as SdDuel
	return d != null and not bool(t.get("busy")) and not bool(t.get("finished")) \
		and d.side_to_move() == SdDuel.Side.PLAYER


func _duties(opp: SdOpponentDef) -> Array[Dictionary]:
	var dl: Array[Dictionary] = SdStyle.duties(opp.element_mods)
	for sid: String in opp.status_immune:
		dl.append({"immune": sid})
	return dl


## Global rects of the table's elements (the hand: its cards' slots).
func _scene_rects(t: Node) -> Dictionary:
	var out: Dictionary = {}
	for k: String in ["board", "opp_plate", "player_plate", "counter", "mod_slot", "ablage_button",
			"stempeln_button", "paw_button", "menu_button"]:
		out[k] = (t.get(k) as Control).get_global_rect()
	out["hand"] = (t.get("hand") as Control).get_global_rect()
	return out


## Inside `size` (at `origin`), no two rects overlap, buttons ≥ 88 px, 12 px between the touch targets.
func _check_rects(rects: Dictionary, size: Vector2, tag: String, origin: Vector2 = Vector2.ZERO) -> void:
	var keys: Array = rects.keys()
	var frame: Rect2 = Rect2(origin, size).grow(0.5)
	for k: Variant in keys:
		var r: Rect2 = rects[k]
		assert_true(frame.encloses(r), "%s inside the frame: %s %s" % [k, str(r), tag])
	for i in keys.size():
		for j in range(i + 1, keys.size()):
			var a: Rect2 = rects[keys[i]]
			var b: Rect2 = rects[keys[j]]
			assert_false(a.grow(-0.5).intersects(b.grow(-0.5)), "%s / %s overlap %s" % [keys[i], keys[j], tag])
	var targets: Array[String] = []
	for k2: Variant in keys:
		if str(k2) in ["paw", "menu", "ablage", "stempeln", "paw_button", "menu_button", "ablage_button",
				"stempeln_button", "hand"]:
			targets.append(str(k2))
	for i2 in targets.size():
		var a2: Rect2 = rects[targets[i2]]
		assert_true(a2.size.x >= HIT - 0.5 and a2.size.y >= HIT - 0.5, "%s >= 88 px %s" % [targets[i2], tag])
		for j2 in range(i2 + 1, targets.size()):
			var b2: Rect2 = rects[targets[j2]]
			var gap: float = maxf(maxf(b2.position.x - a2.end.x, a2.position.x - b2.end.x), maxf(b2.position.y - a2.end.y,
				a2.position.y - b2.end.y))
			assert_true(gap >= GAP - 0.5, "%s / %s %.1f px apart %s" % [targets[i2], targets[j2], gap, tag])


func _art_count(b: SdRulebook, deck: PackedStringArray, art: String) -> int:
	var n: int = 0
	for cid: String in deck:
		if b.card(cid).art == art:
			n += 1
	return n


func _has_key(action: StringName, key: Key) -> bool:
	for e: InputEvent in InputMap.action_get_events(action):
		if e is InputEventKey and (e as InputEventKey).physical_keycode == key:
			return true
	return false


func _has_pad(action: StringName, button: JoyButton) -> bool:
	for e: InputEvent in InputMap.action_get_events(action):
		if e is InputEventJoypadButton and (e as InputEventJoypadButton).button_index == button:
			return true
	return false


func _action(a: StringName) -> InputEventAction:
	var e: InputEventAction = InputEventAction.new()
	e.action = a
	e.pressed = true
	return e


func _key(k: Key) -> InputEventKey:
	var e: InputEventKey = InputEventKey.new()
	e.physical_keycode = k
	e.pressed = true
	return e


## Visible labels / buttons whose text has a glyph the font lacks (03_ART F8).
func _bad_glyphs(root: Node) -> PackedStringArray:
	var out: PackedStringArray = []
	for c: Node in root.find_children("*", "", true, false):
		var text: String = ""
		if c is Label:
			text = (c as Label).text
		elif c is Button:
			text = (c as Button).text
		var miss: String = UiUtil.missing_glyphs(text)
		if miss != "":
			out.append("%s: '%s' (%s)" % [c.name, text.left(30), miss])
	return out


## Visible labels with text below `min_px`.
func _small_texts(root: Node, min_px: int) -> PackedStringArray:
	var out: PackedStringArray = []
	for c: Node in root.find_children("*", "Label", true, false):
		var l: Label = c as Label
		if not l.is_visible_in_tree() or l.text.strip_edges() == "":
			continue
		var fs: int = l.get_theme_font_size("font_size")
		if fs < min_px:
			out.append("%s '%s' %d px" % [l.name, l.text.left(30), fs])
	return out


## Visible buttons whose hit area is below 88 px.
func _small_buttons(root: Node) -> PackedStringArray:
	var out: PackedStringArray = []
	for c: Node in root.find_children("*", "BaseButton", true, false):
		var b: Control = c as Control
		if not b.is_visible_in_tree():
			continue
		if b.size.x < HIT - 0.5 or b.size.y < HIT - 0.5:
			out.append("%s %s" % [b.name, str(b.size)])
	return out


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


## Lets a transition started by a screen finish, frees screens the Router created, leaves the Router empty.
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
