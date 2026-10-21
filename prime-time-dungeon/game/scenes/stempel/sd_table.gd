extends Control
## The Stempelduell table (10 §4): a 2D card table in the TV look (ShowOverlay mode &"duel", M.O.D. hosting in the
## ModDialog box), playing one SdDuel (the frozen CTB engine underneath). Rows (sd_layout.gd): the Wartenummern-Anzeige
## (sd_board.gd), the opponent's plate | the M.O.D. box, the player's plate | the counter, the hand with ABLAGE and
## STEMPELN. The table only plays SdEvents and reads the duel's state after them (Brief §6b.2): the player's moves go
## through SdDuel.validate / submit, the opponent's through opponent_move(), the Graf's tip through SdAi.suggest.
## Controls per scheme (10 §4.6): keyboard (← / → or 1–5 mark, Enter / Space / F play, X / Backspace file, Tab / M big
## view, Q / E area, T auto, R speed, Esc / P menu), gamepad (D-pad, A, X, B, Select, LB / RB, Y, R3, Start) and touch
## (tap marks, tap again or STEMPELN plays, drag onto the counter plays, onto ABLAGE files, long press = big view).
## Tab / Y: CombatInput.apply_input_mode(false) on entering, apply_for_game() on leaving (10 §4.6 "Stand nach SD1").
## Lernduell (10 §1.10, sd_tutorial.gd): the lessons as cards at their numbers, the forced card highlighted. The duel
## ends in the results panel (sd_results.gd); the collection books it (SdCollection.record_duel) and is saved.
## Params: {"opp", "mappe", "tutorial", "seed" (tests), "collection" (tests), "instant" (tests: no waits),
## "touch" (force the touch layout), "text_size", "left_handed", "capture"}.

signal duel_over(summary: Dictionary)
signal lesson_shown(step: int)

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const InputGlyph := preload("res://scenes/ui/input_glyph.gd")
const SdStyle := preload("res://scenes/stempel/sd_style.gd")
const SdIcons := preload("res://scenes/stempel/sd_icons.gd")
const SdLayout := preload("res://scenes/stempel/sd_layout.gd")
const SdBoard := preload("res://scenes/stempel/sd_board.gd")
const SdPlate := preload("res://scenes/stempel/sd_plate.gd")
const SdHand := preload("res://scenes/stempel/sd_hand.gd")
const SdCounter := preload("res://scenes/stempel/sd_counter.gd")
const CardView := preload("res://scenes/stempel/sd_card_view.gd")
const SdHost := preload("res://scenes/stempel/sd_host.gd")
const SdAudio := preload("res://scenes/stempel/sd_audio.gd")
const SdSession := preload("res://scenes/stempel/sd_session.gd")
const SdModal := preload("res://scenes/stempel/sd_modal.gd")
const SdAkte := preload("res://scenes/stempel/sd_akte.gd")
const SdResults := preload("res://scenes/stempel/sd_results.gd")
const SdTutorial := preload("res://scenes/stempel/sd_tutorial.gd")
const SdMenu := preload("res://scenes/stempel/sd_menu.gd")
const Backdrop := preload("res://scenes/stempel/sd_table_bg.gd")

const THINK_SEC: float = 0.5
const AUTO_SEC: float = 0.6
const FLY_SEC: float = 0.25
const STATUS_ICONS: Dictionary = {"sts_sd_wiedervorlage": &"clock_arrow", "sts_sd_vorschrift": &"snail",
	"sts_sd_eilvermerk": &"seal_exclamation", "sts_sd_kleingedrucktes": &"magnifier"}
const PHASE_NAMES: PackedStringArray = ["Dienstbeginn", "Durchsagen", "Feierabend naht"]

var book: SdRulebook = null
var collection: SdCollection = null
var duel: SdDuel = null
var duel_log: SdLog = null
var host: SdHost = null
var audio: Node = null
var opp: SdOpponentDef = null
var opp_id: String = ""
var mappe: String = "a"
var tutorial: bool = false
## Presentation options (SdCollection.options; params override for tests and captures).
var touch: bool = false
var text_size: int = 100
var speed: int = 1
var reduce_motion: bool = false
var hints: bool = true
var open_hand: bool = false
var left_handed: bool = false
var auto: bool = false
var instant: bool = false

## Nodes.
var board: Control
var opp_plate: Control
var player_plate: Control
var counter: Control
var mod_slot: Control
var hand: Control
var ablage_button: Button
var stempeln_button: Button
var paw_button: Button
var menu_button: Button
var chips: Label
var fx: Control                                     # flying cards and popups (above everything on the table)
var layout: Dictionary = {}

## State.
var busy: bool = false                              # events play / the opponent moves: no player input
var file_mode: bool = false
var area: int = 0                                   # 0 hand, 1 board (reading mode), 2 Akte
var suggestion: Dictionary = {}
var finished: bool = false
var lessons_seen: Array[int] = []                   # Lernduell steps shown, in order
var results: Node = null                            # the results modal while open
var modal: Node = null                              # another modal (menu, Akte, big view, lesson) while open

var _params: Dictionary = {}
var _frame: Control
var _safe: SafeAreaContainer
var _bg: Control
var _shown_hand: PackedStringArray = []
var _shown_ticket: int = 0
var _chain_announced: int = 0
var _tie_said: bool = false
var _near_said: bool = false
var _mapped: bool = false
var _first_turn: bool = true
var _tap_marked: int = -1


func setup(params: Dictionary) -> void:
	_params = params


func _ready() -> void:
	UiUtil.full_rect(self)
	book = SdSession.book()
	if bool(_params.get("capture", false)) and not _params.has("collection"):
		SdSession.use_sample()
	var injected: Variant = _params.get("collection", null)
	if injected is SdCollection:
		SdSession.use(injected as SdCollection)         # tests: this collection is the session's (saved as such)
	collection = SdSession.collection()
	_read_options()
	instant = bool(_params.get("instant", false))
	tutorial = bool(_params.get("tutorial", false)) or not collection.tutorial and str(_params.get("opp", "")) == ""
	var setup_: SdSetup = null
	if tutorial:
		setup_ = SdSetup.lernduell(book)
		opp_id = book.tutorial_opponent()
	else:
		opp_id = str(_params.get("opp", "sdo_ferdi"))
		mappe = str(_params.get("mappe", collection.active))
		var seed: int = int(_params.get("seed", 0))
		if seed == 0:
			seed = collection.next_duel_seed()
			SdSession.save()                        # the seed counter is saved before the duel (10 §6.6)
		setup_ = SdSetup.create(book, opp_id, collection.deck(mappe), seed)
	opp = book.opponent(opp_id)
	open_hand = open_hand or (opp != null and opp.open_hand)
	duel = SdDuel.new(setup_, book)
	duel_log = SdLog.begin(setup_)
	host = SdHost.new(book, setup_.seed)
	host.ctx = {"opp": opp.name if opp != null else "", "name": "Kai"}
	host.mute = bool(_params.get("capture", false)) and bool(_params.get("mute", false))
	audio = SdAudio.new()
	audio.name = "SdAudio"
	audio.set("muted", instant or bool(_params.get("capture", false)))   # stills are silent: no playback at quit
	add_child(audio)
	_build()
	_mapped = true
	CombatInput.apply_input_mode(false)                 # Tab → map (big view), Y → toggle_auto (10 §4.6)
	Events.overlay_mode_requested.emit.call_deferred(&"duel")
	audio.call("music", &"sd_wartezimmer")
	var problem: String = setup_.problem(book)
	if problem != "":
		push_warning("[SdTable] duel cannot start: %s" % problem)
		_counter_message("Diese Mappe ist nicht zulässig.", collection.deck_problem(collection.deck(mappe), book))
		return
	_begin.call_deferred()


func _exit_tree() -> void:
	if _mapped:
		_mapped = false
		CombatInput.apply_for_game()
	Events.dialog_layout_requested.emit(&"duel", {})


## Router: the hall comes back on top of a finished table never; the table is popped.
func on_resume(_payload: Dictionary) -> void:
	Events.overlay_mode_requested.emit(&"duel")
	_request_mod_layout()


func _read_options() -> void:
	var o: Dictionary = collection.options
	touch = Game.input_scheme == Game.InputScheme.TOUCH
	if _params.has("touch"):
		touch = bool(_params["touch"])
	text_size = int(_params.get("text_size", o.get("text_size", 100)))
	speed = int(o.get("speed", 1))
	reduce_motion = bool(o.get("reduce_motion", false))
	hints = bool(o.get("hints", true))
	open_hand = bool(o.get("open_hand", false))
	left_handed = bool(_params.get("left_handed", o.get("left_handed", false)))


# --- build and layout -------------------------------------------------------------------------------------------------

func _build() -> void:
	_bg = Backdrop.new()
	_bg.name = "Backdrop"
	_bg.set("mat", str(collection.cosmetics.get("mat", "")))
	add_child(_bg)
	_safe = SafeAreaContainer.new()
	_safe.name = "Safe"
	add_child(_safe)
	_frame = Control.new()
	_frame.name = "Frame"
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_safe.add_child(_frame)
	board = SdBoard.new()
	board.name = "Board"
	_frame.add_child(board)
	opp_plate = SdPlate.new()
	opp_plate.name = "OppPlate"
	opp_plate.mouse_filter = Control.MOUSE_FILTER_STOP
	opp_plate.gui_input.connect(_on_opp_plate_input)
	_frame.add_child(opp_plate)
	mod_slot = Control.new()
	mod_slot.name = "ModSlot"
	mod_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(mod_slot)
	player_plate = SdPlate.new()
	player_plate.name = "PlayerPlate"
	player_plate.set("is_player", true)
	_frame.add_child(player_plate)
	counter = SdCounter.new()
	counter.name = "Counter"
	_frame.add_child(counter)
	hand = SdHand.new()
	hand.name = "Hand"
	_frame.add_child(hand)
	hand.connect("marked", _on_marked)
	hand.connect("tapped", _on_tapped)
	hand.connect("play_requested", func(slot: int) -> void: _try_play(slot))
	hand.connect("big_requested", func(slot: int) -> void: open_big_view(slot))
	hand.connect("dropped", _on_dropped)
	ablage_button = _side_button("ABLAGE", &"tray", &"sd_file", "Abheften")
	ablage_button.name = "Ablage"
	ablage_button.pressed.connect(_on_ablage_pressed)
	stempeln_button = _side_button("STEMPELN", &"stamp", &"ui_accept", "Spielen")
	stempeln_button.name = "Stempeln"
	stempeln_button.pressed.connect(_on_stempeln_pressed)
	paw_button = _icon_button("Pfote", &"paw", SdStyle.GOLD)
	paw_button.pressed.connect(_on_paw_pressed)
	menu_button = _icon_button("Menü", &"menu", SdStyle.TEXT)
	menu_button.pressed.connect(open_menu)
	chips = SdStyle.label("", SdStyle.min_text(touch), SdStyle.GOLD, true)
	chips.name = "Chips"
	chips.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_frame.add_child(chips)
	fx = Control.new()
	fx.name = "Fx"
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.z_index = 20
	_frame.add_child(fx)
	_apply_options()
	_frame.resized.connect(_relayout)
	_relayout()


## A touch-friendly side button (ABLAGE / STEMPELN): drawn symbol + word, ≥ 88 px, no keyboard focus (keys exist).
func _side_button(text: String, icon: StringName, action: StringName, caption: String) -> Button:
	var b: Button = Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", SdStyle.panel_box(Color(SdStyle.INK, 0.92), SdStyle.GOLD, 2, 8.0))
	b.add_theme_stylebox_override("hover", SdStyle.panel_box(Color(0.2, 0.12, 0.3, 0.95), SdStyle.GOLD, 2, 8.0))
	b.add_theme_stylebox_override("pressed", SdStyle.panel_box(Color(SdStyle.GOLD, 0.35), SdStyle.GOLD, 2, 8.0))
	b.add_theme_stylebox_override("disabled", SdStyle.panel_box(Color(SdStyle.INK, 0.6), SdStyle.GREY, 2, 8.0))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var col: VBoxContainer = UiUtil.vbox(4)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiUtil.full_rect(col)
	b.add_child(col)
	var ic: Control = SdIcons.icon(icon, SdStyle.GOLD, 34)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(ic)
	var l: Label = SdStyle.label(text, 18, SdStyle.TEXT, true)
	l.name = "Text"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(l)
	b.set_meta("label", l)
	var g: Control = InputGlyph.make(action, "", 16)
	g.name = "Glyph"
	g.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(g)
	b.set_meta("caption", caption)
	_frame.add_child(b)
	return b


func _icon_button(text: String, icon: StringName, col: Color) -> Button:
	var b: Button = Button.new()
	b.name = text
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = text
	for st: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	var vis: Panel = Panel.new()
	vis.name = "Visual"
	vis.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vis.add_theme_stylebox_override("panel", SdStyle.panel_box(Color(SdStyle.INK, 0.9), Color(col, 0.7), 2, 0.0))
	vis.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vis.offset_left = -32
	vis.offset_right = 32
	vis.offset_top = -32
	vis.offset_bottom = 32
	b.add_child(vis)
	var ic: Control = SdIcons.icon(icon, col, 36)
	ic.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	ic.offset_left = -18
	ic.offset_right = 18
	ic.offset_top = -18
	ic.offset_bottom = 18
	b.add_child(ic)
	_frame.add_child(b)
	return b


func _apply_options() -> void:
	for n: Control in [board, opp_plate, player_plate, counter, hand]:
		n.set("touch", touch)
		n.set("text_size", text_size)
	board.set("speed", float(speed))
	board.set("reduce_motion", reduce_motion)
	hand.set("reduce_motion", reduce_motion)
	hand.set("back_id", str(collection.cosmetics.get("back", "")))
	counter.set("ink", Color("#4f8dff") if str(collection.cosmetics.get("ink", "")) == "sdk_ink_kopierblau"
		else (SdStyle.GOLD if str(collection.cosmetics.get("ink", "")) == "sdk_ink_gold" else SdStyle.SEAL_RED))
	for b: Button in [stempeln_button, ablage_button]:
		(b.get_meta("label") as Label).add_theme_font_size_override("font_size", SdLayout.side_label_px(touch))
		(b.find_child("Glyph", true, false) as Control).visible = not touch      # touch: no key symbols
	_update_chips()


func _relayout() -> void:
	var fs: Vector2 = _frame.size
	if fs.x < 100.0 or fs.y < 100.0:
		return
	layout = SdLayout.compute(fs.x, fs.y, touch, text_size, left_handed, open_hand, book, _duty_list())
	board.set("compact", bool(layout["board_compact"]))
	opp_plate.set("compact", bool(layout["plate_compact"]))
	counter.set("compact", bool(layout["counter_compact"]))
	hand.set("fan", bool(layout["fan"]))
	hand.set("card_w", float(layout["card_w"]))
	hand.set("card_gap", float(layout["card_gap"]))
	_place(board, layout["board"])
	_place(opp_plate, layout["opp"])
	_place(mod_slot, layout["mod"])
	_place(player_plate, layout["player"])
	_place(counter, layout["counter"])
	_place(hand, layout["hand"])
	_place(ablage_button, layout["ablage"])
	_place(stempeln_button, layout["stempeln"])
	_place(paw_button, layout["paw"])
	_place(menu_button, layout["menu"])
	_place(chips, layout["chips"])
	_place(fx, Rect2(Vector2.ZERO, fs))
	hand.call("layout_cards", false)
	board.queue_redraw()
	_request_mod_layout()


static func _place(c: Control, r: Rect2) -> void:
	c.position = r.position
	c.size = r.size


## The ModDialog box over the M.O.D. slot (subtitle layout + the duel keys of mod_dialog.gd: font, speakers).
func _request_mod_layout() -> void:
	if layout.is_empty() or not is_inside_tree():
		return
	var r: Rect2 = layout["mod"]
	var fs: Vector2 = _frame.size
	var bottom: float = fs.y - r.end.y
	var shift: float = r.get_center().x - fs.x * 0.5
	Events.dialog_layout_requested.emit(&"duel", {"bottom": bottom, "width": r.size.x, "shift": shift,
		"max_lines": 3, "blocking": false, "mouse_filter_ignore": true, "font": int(layout["mod_font"]),
		"speakers": {"opp": opp.name if opp != null else ""}, "speaker_colors": {"opp": "#e8455a"}})


# --- duel flow --------------------------------------------------------------------------------------------------------

func _begin() -> void:
	busy = true
	_shown_hand = PackedStringArray()
	_counter_message("Nummern ziehen …", "Der Wartemarken-Spender druckt zwei Zettel.")
	var evs: Array[SdEvent] = duel.start()
	_sync_static()
	host.say_now("sd_explain" if tutorial else "sd_intro")
	if opp != null and not tutorial:
		host.say("sd_opp_intro:" + opp.lines, {}, true)
	audio.call("play", &"sd_shuffle")
	await _play(evs)
	await _advance()


## Runs the duel until the player has to choose (or the duel ends): the opponent's moves, the lessons, auto moves.
func _advance() -> void:
	while is_inside_tree() and not duel.is_finished():
		var side: int = duel.side_to_move()
		if side == SdDuel.Side.OPPONENT:
			busy = true
			hand.set("interactive", false)
			_counter_message("%s überlegt …" % _opp_short_name(), "Nummer %03d" % duel.ticket())
			await _wait(THINK_SEC)
			if not is_inside_tree():
				return
			var held: Array[Dictionary] = []
			if tutorial:
				held = duel.lessons_now()
			var evs: Array[SdEvent] = duel.submit(duel.opponent_move())
			await _play(evs)
			for l: Dictionary in held:
				await _show_lesson(l)
			continue
		if side != SdDuel.Side.PLAYER:
			break
		_player_turn()                                  # first: the lesson card shows the marked, highlighted card
		var own: Array[Dictionary] = []
		if tutorial:
			own = duel.lessons_now()
		for l2: Dictionary in own:
			await _show_lesson(l2)
		if not is_inside_tree() or finished:
			return
		if auto and not finished:
			await _wait(AUTO_SEC)
			if auto and not busy and duel.side_to_move() == SdDuel.Side.PLAYER:
				var m: Dictionary = SdAi.suggest(duel)
				m["a"] = true
				await _submit_player(m)
				continue
		return
	if duel.is_finished() and not finished:
		await _finish()


## The player's number: unlock, mark (the forced / recommended card first), preview, the Graf's tip.
func _player_turn() -> void:
	busy = false
	hand.set("interactive", true)
	file_mode = false
	suggestion = SdAi.suggest(duel) if (hints or tutorial or auto) else {}
	var forced: Dictionary = duel.forced_move()
	var forced_slot: int = -1
	if str(forced.get("op", "")) == "play":
		forced_slot = duel.hands[SdDuel.Side.PLAYER].find(str(forced["card"]))
	var rec: int = int(suggestion.get("slot", -1)) if hints and str(suggestion.get("op", "")) == "play" else -1
	hand.call("set_flags", rec if not tutorial else -1, forced_slot, forced_slot >= 0)
	_set_ablage_hint(str(forced.get("op", "")) == "file" or (hints and str(suggestion.get("op", "")) == "file"
		and not tutorial))
	var first: int = forced_slot if forced_slot >= 0 else (rec if rec >= 0 else maxi(0, mini(int(hand.get(
		"marked_slot")), _shown_hand.size() - 1)))
	_counter_message("Nummer %03d — Sie sind dran." % duel.ticket(), _turn_hint(forced))
	if area == 0:
		_tap_marked = -1
		hand.call("mark", first, true)
		_preview(first)
	_check_tie()
	_first_turn = false


func _turn_hint(forced: Dictionary) -> String:
	if str(forced.get("op", "")) == "play":
		var c: SdCardDef = book.card(str(forced["card"]))
		return "Lernduell: Spielen Sie %s." % (c.name if c != null else "die Karte")
	if str(forced.get("op", "")) == "file":
		return "Lernduell: Heften Sie eine Karte ab."
	if touch:
		return "Karte antippen, erneut antippen spielt."
	return "Karte wählen und spielen — oder abheften."


func _submit_player(move: Dictionary) -> void:
	if busy or finished or duel.side_to_move() != SdDuel.Side.PLAYER:
		return
	var reason: String = duel.validate(move)
	if reason != "":
		Sfx.play_ui(&"ui_error")
		var forced: Dictionary = duel.forced_move()
		if not forced.is_empty():
			_counter_message("Das Lernduell möchte etwas anderes.", _turn_hint(forced), SdStyle.GOLD)
		return
	busy = true
	hand.set("interactive", false)
	hand.call("set_flags", -1, -1, false)           # tip, forced glow and dimming belong to this number only
	_set_ablage_hint(false)
	_clear_preview()
	file_mode = false
	_update_side_buttons()
	duel_log.add(move, bool(move.get("a", false)))
	var evs: Array[SdEvent] = duel.submit(move)
	await _play(evs)
	await _advance()


# --- player input -------------------------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if finished or results != null:
		return
	if modal != null and is_instance_valid(modal):
		return
	if event.is_action_pressed(&"pause") and not file_mode and area == 0:
		get_viewport().set_input_as_handled()
		open_menu()
		return
	if event.is_action_pressed(&"ui_cancel"):
		if file_mode:
			set_file_mode(false)
		elif area != 0:
			set_area(0)
		else:
			open_menu()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"toggle_auto"):
		set_auto(not auto)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"toggle_speed"):
		set_speed(2 if speed == 1 else 1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"tab_next") or event.is_action_pressed(&"tab_prev"):
		set_area(posmod(area + (1 if event.is_action_pressed(&"tab_next") else -1), 3))
		get_viewport().set_input_as_handled()
		return
	if area == 1:
		if event.is_action_pressed(&"ui_left") or event.is_action_pressed(&"ui_right"):
			var n: int = (board.call("tickets") as Array).size()
			var cur: int = int(board.get("cursor"))
			board.set("cursor", posmod(cur + (1 if event.is_action_pressed(&"ui_right") else -1), maxi(1, n)))
			_counter_message("Wartenummern", str(board.call("describe", int(board.get("cursor")))))
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"sd_file"):
		set_file_mode(not file_mode)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"action"):
		_play_marked()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var k: int = (event as InputEventKey).physical_keycode
		if k >= KEY_1 and k <= KEY_5:
			var slot: int = k - KEY_1
			if slot < _shown_hand.size():
				_user_input()
				hand.call("mark", slot, true)
			get_viewport().set_input_as_handled()


## The big view (Tab / M / Select) is read before the GUI: Tab is also the focus navigation's ui_focus_next.
func _input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"map") or finished or results != null or area != 0:
		return
	if modal != null and is_instance_valid(modal):
		return
	get_viewport().set_input_as_handled()
	open_big_view(int(hand.get("marked_slot")))


## Any own input ends "Der Graf übernimmt" (10 §1.11: "bis Sie wieder tippen").
func _user_input() -> void:
	if auto:
		set_auto(false)


func _on_marked(slot: int) -> void:
	if slot != _tap_marked:
		_tap_marked = -1
	_preview(slot)


## Touch / mouse: the first tap marks, a second tap on the card marked by the first one plays it (a card the table
## marked by itself never plays on one tap).
func _on_tapped(slot: int) -> void:
	_user_input()
	if _tap_marked == slot and int(hand.get("marked_slot")) == slot:
		_tap_marked = -1
		_play_slot(slot)
		return
	hand.call("mark", slot, true)
	_tap_marked = slot


func _play_marked() -> void:
	_user_input()
	_play_slot(int(hand.get("marked_slot")))


func _play_slot(slot: int) -> void:
	if slot < 0:
		return
	if file_mode:
		_submit_player({"op": "file", "slot": slot})
	else:
		_try_play(slot)


func _try_play(slot: int) -> void:
	_user_input()
	if slot < 0 or slot >= _shown_hand.size():
		return
	_submit_player({"op": "play", "slot": slot})


func _on_dropped(slot: int, global_pos: Vector2) -> void:
	_user_input()
	if ablage_button.get_global_rect().grow(12.0).has_point(global_pos):
		_submit_player({"op": "file", "slot": slot})
	elif global_pos.y < hand.get_global_rect().position.y + SdStyle.LIFT or counter.get_global_rect().grow(24.0) \
			.has_point(global_pos):
		_submit_player({"op": "play", "slot": slot})
	else:
		hand.call("layout_cards", true)


func _on_ablage_pressed() -> void:
	_user_input()
	if busy:
		return
	set_file_mode(not file_mode)


func _on_stempeln_pressed() -> void:
	_user_input()
	_play_slot(int(hand.get("marked_slot")))


func _on_paw_pressed() -> void:
	_user_input()
	if suggestion.is_empty():
		suggestion = SdAi.suggest(duel)
	var hint: String = str(suggestion.get("hint", ""))
	if hint != "":
		host.say_now("sd_hint:" + hint)
	if str(suggestion.get("op", "")) == "play":
		hand.call("mark", int(suggestion["slot"]), true)
	elif str(suggestion.get("op", "")) == "file":
		set_file_mode(true)
		hand.call("mark", int(suggestion["slot"]), true)


func _on_opp_plate_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and (e as InputEventMouseButton).pressed \
			and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		open_akte()
		accept_event()


## Abheften mode (10 §1.4, §4.6): "Welche Karte abheften?" — the marked card is filed on Enter / A / tap / STEMPELN.
func set_file_mode(on: bool) -> void:
	if on and (busy or duel.side_to_move() != SdDuel.Side.PLAYER):
		return
	file_mode = on
	_update_side_buttons()
	if on:
		_counter_message("Abheften: Welche Karte?", "Karte wählen und bestätigen — Zurück bricht ab.", SdStyle.CYAN)
	else:
		_counter_message("Nummer %03d — Sie sind dran." % duel.ticket(), _turn_hint(duel.forced_move()))
	_preview(int(hand.get("marked_slot")))


func _update_side_buttons() -> void:
	(ablage_button.get_meta("label") as Label).text = "ZURÜCK" if file_mode else "ABLAGE"
	(stempeln_button.get_meta("label") as Label).text = "ABHEFTEN" if file_mode else "STEMPELN"


func _set_ablage_hint(on: bool) -> void:
	ablage_button.modulate = Color(1.25, 1.15, 0.8) if on else Color.WHITE


## Focus areas (Q / E, LB / RB): 0 the hand, 1 the board (reading mode), 2 the opponent's Akte.
func set_area(a: int) -> void:
	area = a
	board.set("cursor", 0 if a == 1 else -1)
	if a == 1:
		_counter_message("Wartenummern", str(board.call("describe", 0)))
		var v: Control = hand.call("view", int(hand.get("marked_slot")))
		if v != null:
			v.release_focus()
	elif a == 2:
		open_akte()
	else:
		hand.call("mark", maxi(0, int(hand.get("marked_slot"))), true)
		if not busy and duel.side_to_move() == SdDuel.Side.PLAYER:
			_counter_message("Nummer %03d — Sie sind dran." % duel.ticket(), _turn_hint(duel.forced_move()))


func set_auto(on: bool) -> void:
	auto = on
	_update_chips()
	if on and not busy and not finished and duel.side_to_move() == SdDuel.Side.PLAYER:
		_advance_auto.call_deferred()


func _advance_auto() -> void:
	await _wait(AUTO_SEC * 0.5)
	if auto and not busy and not finished and duel.side_to_move() == SdDuel.Side.PLAYER:
		var m: Dictionary = SdAi.suggest(duel)
		m["a"] = true
		await _submit_player(m)


func set_speed(s: int) -> void:
	speed = s
	collection.set_option("speed", s)
	SdSession.save()
	board.set("speed", float(speed))
	_update_chips()


func _update_chips() -> void:
	var parts: PackedStringArray = []
	if speed == 2:
		parts.append("TEMPO × 2")
	if auto:
		parts.append("AUTO: GRAF")
	chips.text = " · ".join(parts)


# --- preview ----------------------------------------------------------------------------------------------------------

## The marked card's dry run (SdDuel.preview): ghost tickets on the board, pale segments on the bars, the real number
## on the card ("14 · statt 9 · WUNDER PUNKT").
func _preview(slot: int) -> void:
	if busy or finished or slot < 0 or slot >= _shown_hand.size() or duel.side_to_move() != SdDuel.Side.PLAYER:
		_clear_preview()
		return
	var move: Dictionary = {"op": "file" if file_mode else "play", "slot": slot}
	var p: Dictionary = duel.preview(move)
	var c: SdCardDef = book.card(_shown_hand[slot])
	for i in _shown_hand.size():
		var v: Control = hand.call("view", i)
		if v != null:
			v.set("preview", _card_preview(c, p) if i == slot and not file_mode else {})
	if p.is_empty():
		board.call("show_preview", PackedStringArray())
		opp_plate.call("show_preview", -1)
		player_plate.call("show_preview", -1)
		return
	board.call("show_preview", p["order"] as PackedStringArray)
	var g: Array = p["geduld"]
	opp_plate.call("show_preview", int(g[1]))
	player_plate.call("show_preview", int(g[0]))


func _clear_preview() -> void:
	board.call("show_preview", PackedStringArray())
	opp_plate.call("show_preview", -1)
	player_plate.call("show_preview", -1)
	for v: Control in hand.get("views") as Array:
		v.set("preview", {})


## {"main", "sub", "tone"} of a marked card from its dry run (or the printed effect for show cards).
func _card_preview(c: SdCardDef, p: Dictionary) -> Dictionary:
	if c == null:
		return {}
	if p.is_empty():
		return {"main": CardView.effect_of(c)[0], "sub": "Show-Karte: kein Probelauf", "tone": ""} if c.show else {}
	var foe: Combatant = duel.combatant(SdDuel.Side.OPPONENT)
	var blocked: PackedStringArray = p.get("blocked", PackedStringArray())
	if c.damage() == 0 and c.heal() == 0 and not c.status_ids().is_empty() and blocked.size() >= c.status_ids().size():
		var why: String = "ABGEPRALLT" if foe.status_immune.has(c.status_ids()[0]) else "liegt schon vor"
		return {"main": "KEINE WIRKUNG", "sub": why, "tone": "blocked"}
	if c.damage() > 0:
		var dmg: int = DamageCalc.fixed(foe, c.power(), c.element()).amount * c.hits()
		var ends: bool = bool(p.get("ends", false))
		var main: String = "%d ÄRGER" % dmg
		if dmg != c.damage():
			var weak: bool = dmg > c.damage()
			return {"main": main, "sub": "statt %d · %s" % [c.damage(), "WUNDER PUNKT" if weak else "NICHT ZUSTÄNDIG"],
				"tone": "weak" if weak else "resist"}
		if ends:
			return {"main": main, "sub": "Das reicht: BEWILLIGT", "tone": "win"}
	if c.heal() > 0:
		# capped by the missing Geduld (the dry run's delta also holds what follows it, e.g. the Durchsage)
		var healed: int = mini(c.heal(), duel.max_geduld(SdDuel.Side.PLAYER) - duel.geduld(SdDuel.Side.PLAYER))
		if healed < c.heal():
			return {"main": "+%d GEDULD" % maxi(0, healed), "sub": "statt %d · fast voll" % c.heal(), "tone": ""}
	return {}


# --- event playback (10 §4.4) ---------------------------------------------------------------------------------------

## Plays the duel's events in order, then reads the state (Brief §6b.2).
func _play(evs: Array[SdEvent]) -> void:
	var ticket_before: int = _shown_ticket
	for e: SdEvent in evs:
		if not is_inside_tree():
			return
		match e.kind:
			SdEvent.Kind.CARD_PLAYED, SdEvent.Kind.CARD_FILED:
				await _on_card(e)
			SdEvent.Kind.CARD_DRAWN:
				if e.side == SdDuel.Side.PLAYER:
					_shown_hand.append(e.card_id)
					_show_hand()
				else:
					opp_plate.set("piles", _piles(SdDuel.Side.OPPONENT))
			SdEvent.Kind.RESHUFFLED:
				audio.call("play", &"sd_shuffle")
				if e.side == SdDuel.Side.PLAYER:
					host.say("sd_reshuffle")
			SdEvent.Kind.HAND_REFRESHED:
				if e.side == SdDuel.Side.PLAYER:
					_shown_hand = PackedStringArray()
					_show_hand()
				audio.call("play", &"sd_shuffle")
			SdEvent.Kind.DUEL_END:
				pass
			SdEvent.Kind.ENGINE:
				await _on_engine(e.engine)
	_sync_static()
	if _shown_ticket != ticket_before:
		_check_chain()


func _on_card(e: SdEvent) -> void:
	var c: SdCardDef = book.card(e.card_id)
	var player: bool = e.side == SdDuel.Side.PLAYER
	var filed: bool = e.kind == SdEvent.Kind.CARD_FILED
	var from: Rect2 = Rect2()
	if player:
		var v: Control = hand.call("view", e.slot)
		if v != null:
			from = v.get_global_rect()
		if e.slot >= 0 and e.slot < _shown_hand.size():
			_shown_hand.remove_at(e.slot)
		_show_hand()
	else:
		var op: Rect2 = opp_plate.get_global_rect()
		from = Rect2(Vector2(op.end.x - 120.0, op.position.y), SdStyle.card_size(touch) * 0.6)
		if opp != null and not tutorial and _rng_line(4):
			host.say("sd_opp_play:" + opp.lines, {}, false)
		if opp != null and opp.id == "sdo_graf" and not filed:
			host.say("sd_mopsula_turn")
	audio.call("play", &"sd_card")
	await _fly(c, from, player and not filed, filed)
	var result: String = "abgeheftet: halber Ärger bis zur nächsten Nummer" if filed else ""
	counter.call("show_card", c, player, result, SdStyle.CYAN if filed else SdStyle.TEXT_DIM, filed)
	if not filed:
		audio.call("play", &"sd_stamp")
		await _thump()
	if c != null and c.show:
		host.say("sd_chat_show")


## The card flies from `from` (global) to the counter (0.25 s; reduce motion: a cross-fade).
func _fly(c: SdCardDef, from: Rect2, _face_up: bool, _filed: bool) -> void:
	if instant or from.size == Vector2.ZERO:
		return
	var v: Control = CardView.new()
	v.call("setup", c, touch, 100, false)
	fx.add_child(v)
	var to: Rect2 = counter.get_global_rect()
	var fx_origin: Vector2 = fx.get_global_rect().position
	v.position = from.position - fx_origin
	v.size = SdStyle.card_size(touch)
	v.scale = from.size / v.size
	v.pivot_offset = Vector2.ZERO
	var target_scale: float = (to.size.y - 16.0) / v.size.y
	var target_pos: Vector2 = Vector2(to.end.x - 12.0 - v.size.x * target_scale, to.position.y + 8.0) - fx_origin
	var tw: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var dur: float = FLY_SEC / float(speed)
	if reduce_motion:
		v.position = target_pos
		v.scale = Vector2.ONE * target_scale
		v.modulate.a = 0.0
		tw.tween_property(v, "modulate:a", 1.0, dur)
	else:
		tw.tween_property(v, "position", target_pos, dur)
		tw.tween_property(v, "scale", Vector2.ONE * target_scale, dur)
	await tw.finished
	v.queue_free()


## The stamp thump on the counter (1.3 → 1.0 in 0.12 s) and a small shake of the table (off with reduce motion).
func _thump() -> void:
	if instant:
		return
	counter.set("thump", 1.0)
	var tw: Tween = create_tween()
	tw.tween_property(counter, "thump", 0.0, 0.12 / float(speed))
	if not reduce_motion:
		# around the place the safe area gives the frame; the container re-sorts it afterwards (a resize meanwhile)
		var base: float = _frame.position.x
		var shake: Tween = create_tween()
		for i in 3:
			shake.tween_property(_frame, "position:x", base + 3.0 * (1.0 if i % 2 == 0 else -1.0), 0.03 / float(speed))
		shake.tween_property(_frame, "position:x", base, 0.03 / float(speed))
		shake.tween_callback(_safe.queue_sort)
	await tw.finished


func _on_engine(e: ActionEvent) -> void:
	match e.type:
		ActionEvent.Type.TURN_START:
			_shown_ticket += 1
			host.ctx["ticket"] = _shown_ticket
			if e.actor_id.begins_with("u"):
				audio.call("play", &"sd_durchsage")
				host.say("sd_durchsage", {"ticket": _shown_ticket})
				_counter_message("Durchsage!", "Nummer %03d: Bitte bewahren Sie Ruhe." % _shown_ticket, SdStyle.GOLD)
			elif not instant:
				audio.call("play", &"sd_gong", 1.0 if e.actor_id == SdDuel.PLAYER_ID else 1.12)
			_board_state(board.get("order") as PackedStringArray)
			if _shown_ticket >= book.constant("dienstschluss_warn") and not _near_said:
				_near_said = true
				host.say_now("sd_dienstschluss_warn")
		ActionEvent.Type.CTB_ORDER:
			_board_state(e.order)
		ActionEvent.Type.DAMAGE:
			await _on_damage(e)
		ActionEvent.Type.HEAL:
			var plate: Control = _plate_of(e.target_id)
			if plate != null:
				plate.call("set_geduld", maxi(0, e.hp_after), not instant, float(speed))
				_popup(plate, "+%d" % e.amount, SdStyle.OK)
				audio.call("play", &"sd_card", 1.3)
		ActionEvent.Type.STATUS_ADDED:
			_sync_statuses()
			if e.status_id == SdDuel.STATUS_WIEDERVORLAGE and e.target_id == SdDuel.OPPONENT_ID:
				host.say("sd_wiedervorlage")
				_popup(opp_plate, "WIEDERVORLAGE", SdStyle.GOLD)
			elif e.status_id == SdDuel.STATUS_WIEDERVORLAGE:
				_popup(player_plate, "WIEDERVORLAGE", SdStyle.GOLD)
		ActionEvent.Type.STATUS_REMOVED:
			_sync_statuses()
		ActionEvent.Type.STATUS_BLOCKED:
			var bp: Control = _plate_of(e.target_id)
			if bp != null:
				_popup(bp, "ABGEPRALLT", SdStyle.TEXT_DIM)
			host.say("sd_abgeprallt")
		ActionEvent.Type.DEFEND:
			_sync_statuses()
		ActionEvent.Type.STUNT_RESULT:
			if e.success:
				host.say_now("sd_show_success")
			else:
				_popup(player_plate, "PATZER", SdStyle.DANGER)
				host.say_now("sd_show_fail")
		ActionEvent.Type.PHASE_CHANGE:
			opp_plate.set("phase", _phase_text(e.value))
			opp_plate.queue_redraw()
			if e.value >= 2:
				audio.call("music", &"sd_wartezimmer_eilig")
		ActionEvent.Type.MOD_LINE:
			host.say_now(e.text)
		ActionEvent.Type.SUMMON:
			audio.call("play", &"sd_durchsage")


## The board after an engine event; once the duel is decided it keeps its last picture (the order without the
## defeated side would read "9 × SIE").
func _board_state(order: PackedStringArray) -> void:
	if duel.is_finished():
		return
	board.call("show_state", _shown_ticket, order, _shown_ticket >= book.constant("dienstschluss_warn"))


func _on_damage(e: ActionEvent) -> void:
	var plate: Control = _plate_of(e.target_id)
	if plate == null:
		return
	plate.call("set_geduld", maxi(0, e.hp_after), not instant, float(speed))
	var col: Color = SdStyle.DANGER
	var text: String = "−%d" % e.amount
	if e.weak:
		col = SdStyle.GOLD
		text += " WUNDER PUNKT!"
		if e.target_id == SdDuel.OPPONENT_ID:
			host.say("sd_weak")
			if opp != null:
				host.say("sd_opp_hit:" + opp.lines, {}, false)
	elif e.resist:
		col = SdStyle.TEXT_DIM
		text += " NICHT ZUSTÄNDIG"
		host.say("sd_resist")
	_popup(plate, text, col)
	if not instant:
		plate.set("flash", 1.0)
		var tw: Tween = create_tween()
		tw.tween_property(plate, "flash", 0.0, 0.35 / float(speed))
	await _wait(0.12)


func _plate_of(id: String) -> Control:
	if id == SdDuel.PLAYER_ID:
		return player_plate
	if id == SdDuel.OPPONENT_ID:
		return opp_plate
	return null


## A rising, fading number above a plate (0.6 s).
func _popup(plate: Control, text: String, col: Color) -> void:
	if instant:
		return
	var l: Label = SdStyle.label(text, SdStyle.fs(26 if touch else 24, text_size), col, true)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", SdStyle.INK)
	fx.add_child(l)
	var pr: Rect2 = plate.get_global_rect()
	var origin: Vector2 = fx.get_global_rect().position
	l.position = Vector2(pr.position.x + pr.size.x * 0.45, pr.position.y + 4.0) - origin
	var tw: Tween = l.create_tween().set_parallel(true)
	var dur: float = 0.6 / float(speed)
	if not reduce_motion:
		tw.tween_property(l, "position:y", l.position.y - 28.0, dur)
	tw.tween_property(l, "modulate:a", 0.0, dur).set_delay(dur * 0.5)
	tw.chain().tween_callback(l.queue_free)


func _phase_text(index: int) -> String:
	var i: int = clampi(index - 1, 0, PHASE_NAMES.size() - 1)
	return "Phase %d · %s" % [i + 1, PHASE_NAMES[i]]


# --- reading the state ------------------------------------------------------------------------------------------------

## Everything from the duel's state (after the events).
func _sync_static() -> void:
	_shown_ticket = duel.ticket()
	_shown_hand = duel.hand(SdDuel.Side.PLAYER)
	board.set("opp_short", opp.short if opp != null else "GEGNER")
	board.set("durchsage_short", str(book.durchsage.get("short", "DURCHSAGE")))
	board.set("dienstschluss", book.constant("dienstschluss"))
	if not duel.is_finished():
		board.call("show_state", duel.ticket(), duel.order(), duel.dienstschluss_near())
	_sync_plates()
	_show_hand()


func _sync_plates() -> void:
	if opp != null:
		opp_plate.set("symbol", SdStyle.OPPONENT_ICONS.get(opp.symbol, &"person") as StringName)
		opp_plate.set("title", opp.name.to_upper())
		opp_plate.set("role", opp.role)
		opp_plate.set("duties", _duty_list())
	player_plate.set("title", "KAI & DER GRAF")
	var title_id: String = str(collection.cosmetics.get("title", ""))
	player_plate.set("role", str((book.cosmetics.get(title_id, {}) as Dictionary).get("name", "")) if title_id != ""
		else "")
	for side: int in [SdDuel.Side.PLAYER, SdDuel.Side.OPPONENT]:
		var plate: Control = player_plate if side == SdDuel.Side.PLAYER else opp_plate
		plate.set("max_geduld", duel.max_geduld(side))
		plate.call("set_geduld", duel.geduld(side), false)
		plate.set("piles", _piles(side))
	var foe: Combatant = duel.combatant(SdDuel.Side.OPPONENT)
	if foe != null and not foe.phases.is_empty() and foe.phase >= 0:
		opp_plate.set("phase", _phase_text(foe.phase + 1))
	_sync_statuses()


## The opponent's Zuständigkeiten and immunities for its plate.
func _duty_list() -> Array[Dictionary]:
	var dl: Array[Dictionary] = []
	if opp == null:
		return dl
	dl = SdStyle.duties(opp.element_mods)
	for sid: String in opp.status_immune:
		dl.append({"immune": str(SdAkte.NAME_IMMUNE.get(sid, sid))})
	return dl


func _piles(side: int) -> Array[int]:
	return [duel.hands[side].size(), duel.decks[side].size(), duel.discards[side].size()]


func _sync_statuses() -> void:
	for side: int in [SdDuel.Side.PLAYER, SdDuel.Side.OPPONENT]:
		var plate: Control = player_plate if side == SdDuel.Side.PLAYER else opp_plate
		var c: Combatant = duel.combatant(side)
		var list: Array[Dictionary] = []
		if c != null:
			for st: StatusEffect in c.statuses:
				var d: Dictionary = book.statuses.get(st.id(), {})
				var count: int = status_count(st)
				if count == 0:
					continue
				list.append({"icon": STATUS_ICONS.get(st.id(), &"dot"), "color": UiUtil.hex(str(d.get("color", "")),
					SdStyle.GOLD), "count": count, "name": str(d.get("name", st.id()))})
			plate.set("defending", c.defending)
		plate.set("statuses", list)
		plate.queue_redraw()


## Numbers a status still affects (10 §1.6): speed statuses drop at the bearer's turn end before the next wait is
## computed (turns − 1), Kleingedrucktes ticks at each of its turns (turns), the Wiedervorlage shows no count (-1).
static func status_count(st: StatusEffect) -> int:
	if st.def == null:
		return -1
	if st.def.has_flag("delay_on_apply"):
		return -1
	if not is_equal_approx(st.def.tick_speed_mult, 1.0):
		return st.turns_left - 1
	return st.turns_left


func _show_hand() -> void:
	hand.call("set_cards", _shown_hand, book)
	var open: Array[Dictionary] = []
	if open_hand and bool(layout.get("open_row", false)):             # else in the Akte only (sd_layout.gd)
		for cid: String in duel.hand(SdDuel.Side.OPPONENT):
			var c: SdCardDef = book.card(cid)
			if c != null:
				open.append({"name": c.name, "art": c.art})
	opp_plate.set("open_cards", open)
	opp_plate.queue_redraw()


func _opp_short_name() -> String:
	return opp.name.get_slice(" ", 0) if opp != null else "Das Gegenüber"


func _counter_message(l1: String, l2: String = "", col: Color = SdStyle.TEXT_DIM) -> void:
	if counter != null:
		counter.call("show_message", l1, l2, col)


func _check_chain() -> void:
	var run: int = duel.chain()
	if run >= 3 and duel.side_to_move() == SdDuel.Side.PLAYER and run > _chain_announced:
		_chain_announced = run
		host.say("sd_chain")
		host.say("sd_chat_chain")
	elif duel.side_to_move() != SdDuel.Side.PLAYER:
		_chain_announced = 0


## "Bei Gleichstand geht die Kundschaft vor" — once, the first time both numbers ran out together.
func _check_tie() -> void:
	if _tie_said:
		return
	var foe: Combatant = duel.combatant(SdDuel.Side.OPPONENT)
	if foe != null and foe.ctb_counter == 0 and not _first_turn:
		_tie_said = true
		host.say_now("sd_tie")


func _rng_line(one_in: int) -> bool:
	return host != null and (duel.ticket() % one_in) == 0


func _wait(sec: float) -> void:
	if instant or sec <= 0.0:
		return
	var tw: Tween = create_tween()
	tw.tween_interval(sec / float(speed))
	await tw.finished


# --- lessons, end, panels -------------------------------------------------------------------------------------------

func _show_lesson(l: Dictionary) -> void:
	var step: int = JsonUtil.to_int(l.get("step", 0))
	if lessons_seen.has(step):
		return
	lessons_seen.append(step)
	lesson_shown.emit(step)
	if instant:
		return
	var card: Node = SdTutorial.lesson_card(self, l, step == 1)
	modal = card
	await card.closed
	modal = null
	if card.has_meta("skipped"):
		skip_tutorial()


## "Ich kenne mich aus": the Lernduell ends, the Grundakte is booked (SdCollection.complete_tutorial), back to the hall.
func skip_tutorial() -> void:
	if finished:
		return
	finished = true
	var r: Dictionary = collection.complete_tutorial(book)
	SdSession.save()
	duel_over.emit({"tut": true, "result": "skipped"})
	_open_results({"tut": true, "result": "skipped", "opp": opp_id}, r)


func _finish() -> void:
	if finished:
		return
	finished = true
	busy = true
	hand.set("interactive", false)
	_clear_preview()
	duel_log.finish(duel)
	var summary: Dictionary = duel.summary()
	var res: String = str(summary["result"])
	match res:
		"won":
			host.say_now("sd_win")
			if opp != null and not tutorial:
				host.say("sd_opp_lose:" + opp.lines, {}, true)
			host.say("sd_chat_win")
			audio.call("play", &"sd_win")
		"lost":
			host.say_now("sd_loss")
			if opp != null:
				host.say("sd_opp_win:" + opp.lines, {}, true)
			host.say("sd_chat_loss")
			audio.call("play", &"sd_lose")
		"adjourned":
			host.say_now("sd_dienstschluss")
		"forfeit":
			host.say_now("sd_forfeit")
	var rewards: Dictionary = collection.record_duel(summary, book)
	SdSession.save()
	duel_over.emit(summary)
	await _wait(0.6)
	if is_inside_tree():
		_open_results(summary, rewards)


func _open_results(summary: Dictionary, rewards: Dictionary) -> void:
	if modal != null and is_instance_valid(modal):
		modal.call("close")
	results = SdResults.open(self, summary, rewards)


## Results: "Revanche" — a new duel against the same opponent with the same Mappe (a fresh seed).
func rematch() -> void:
	Router.pop({"rematch": opp_id, "mappe": mappe})


## Results: "Andere Mappe" — back to the hall with the Akte of this opponent open.
func other_mappe() -> void:
	Router.pop({"akte": opp_id})


func leave() -> void:
	Router.pop({})


## Menu: "Antrag zurückziehen" (10 §1.8) — on the player's number only (U-7); counts as a defeat, costs nothing.
func forfeit() -> void:
	if busy or finished or duel.side_to_move() != SdDuel.Side.PLAYER:
		return
	if tutorial:
		skip_tutorial()
		return
	_submit_player({"op": "forfeit"})


func open_menu() -> void:
	if modal != null and is_instance_valid(modal) or results != null:
		return
	modal = SdMenu.open(self)
	modal.connect("closed", func() -> void: modal = null)


func open_akte() -> void:
	if opp == null or (modal != null and is_instance_valid(modal)) or results != null:
		return
	var m: Node = SdModal.new()
	m.call("setup", "AKTE", 640.0)
	var extra: Dictionary = {"geduld": duel.geduld(SdDuel.Side.OPPONENT), "discard": duel.discards[
		SdDuel.Side.OPPONENT]}
	if open_hand:
		extra["open_hand"] = duel.hand(SdDuel.Side.OPPONENT)
	SdAkte.build(m.get("content") as Control, book, opp, extra)
	add_child(m)
	modal = m
	m.connect("closed", func() -> void:
		modal = null
		if area == 2:
			set_area(0))


## The big view (10 §2.2): the card twice as large with its full text; the Graf's footnote when it is his tip.
func open_big_view(slot: int) -> void:
	if slot < 0 or slot >= _shown_hand.size() or (modal != null and is_instance_valid(modal)) or results != null:
		return
	var c: SdCardDef = book.card(_shown_hand[slot])
	var m: Node = SdModal.new()
	m.call("setup", "", 0.0, UiTheme.C_ACCENT_2, 0.7)
	var box: VBoxContainer = m.get("content") as VBoxContainer
	var row: HBoxContainer = UiUtil.hbox(20)
	box.add_child(row)
	var v: Control = CardView.new()
	v.call("setup", c, touch, text_size, true)
	var p: Dictionary = duel.preview({"op": "play", "slot": slot}) if not busy else {}
	v.set("preview", _card_preview(c, p))
	row.add_child(v)
	var side: VBoxContainer = UiUtil.vbox(10)
	side.custom_minimum_size = Vector2(320, 0)
	row.add_child(side)
	var t: Label = SdStyle.label(c.text, SdStyle.fs(20, text_size), SdStyle.TEXT)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(320, 0)
	side.add_child(t)
	if int(suggestion.get("slot", -1)) == slot and str(suggestion.get("op", "")) == "play" and hints:
		var lines: Array[Dictionary] = book.lines_for("sd_hint:" + str(suggestion.get("hint", "")))
		if not lines.is_empty():
			var fn: Label = SdStyle.label("Graf Mopsula: " + str(lines[0]["text"]), SdStyle.fs(18, text_size),
				SdStyle.GOLD)
			fn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			fn.custom_minimum_size = Vector2(320, 0)
			side.add_child(fn)
	var play: Button = UiUtil.button("Spielen", &"ButtonBig")
	play.name = "Play"
	UiUtil.touch_pad(play)
	play.disabled = busy or duel.side_to_move() != SdDuel.Side.PLAYER
	play.pressed.connect(func() -> void:
		m.call("close")
		_try_play(slot))
	side.add_child(play)
	add_child(m)
	modal = m
	m.connect("closed", func() -> void:
		modal = null
		hand.call("mark", slot, true))


## Canvas y of the hand row's top (a marked card's lifted edge): lesson cards sit above it.
func hand_top_y() -> float:
	if layout.is_empty() or _frame == null:
		return -1.0
	return _frame.get_global_rect().position.y + (layout["hand"] as Rect2).position.y


## Options changed in the menu: re-read and re-layout.
func options_changed() -> void:
	_read_options()
	open_hand = open_hand or (opp != null and opp.open_hand)
	_apply_options()
	_relayout()
	_sync_static()
	if not busy and duel.side_to_move() == SdDuel.Side.PLAYER:
		_preview(int(hand.get("marked_slot")))
