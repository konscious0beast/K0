extends Control
## The Schalterhalle (10 §4.7), the Stempelduell's home screen (Titel → Extras → Stempelduell (Vorschau)): "Bitte
## ziehen Sie eine Nummer." — one Wartemarke per opponent (besiegt n×, Übung, NEU, or locked with the way there),
## the Stempelheft at the top right and Aktenschrank · Stempelalbum · Regeln & Lernduell at the bottom. A Wartemarke
## opens the Akte (sd_hall_akte.gd: Mappe wählen, the Graf's tip, Duell starten). Before the Lernduell a welcome card
## offers it (or "Ich kenne mich aus": the Grundakte at once, 10 §1.10). Opening reads the campaign unlocks (10 §2.5,
## announced once); a broken collection file is toasted "Stempelakte neu angelegt". The table, the Aktenschrank and
## the album are pushed on top (Router.push, FADE); the table's results come back through on_resume ({"rematch"} →
## a new duel, {"akte"} → the Akte again). Waiting-room music, overlay mode &"menu".

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const SdStyle := preload("res://scenes/stempel/sd_style.gd")
const SdIcons := preload("res://scenes/stempel/sd_icons.gd")
const SdSession := preload("res://scenes/stempel/sd_session.gd")
const SdScreen := preload("res://scenes/stempel/sd_screen.gd")
const SdModal := preload("res://scenes/stempel/sd_modal.gd")
const SdHallAkte := preload("res://scenes/stempel/sd_hall_akte.gd")
const SdRulesPage := preload("res://scenes/stempel/sd_rules_page.gd")
const SdResults := preload("res://scenes/stempel/sd_results.gd")
const SdAudio := preload("res://scenes/stempel/sd_audio.gd")

const TABLE: String = "res://scenes/stempel/sd_table.tscn"
const CABINET: String = "res://scenes/stempel/sd_deck_builder.tscn"
const ALBUM: String = "res://scenes/stempel/sd_album.tscn"
const TICKET: Vector2 = Vector2(232, 280)

var book: SdRulebook = null
var collection: SdCollection = null
var audio: Node = null
var tickets: Dictionary = {}                        # opponent id → Button
var modal: Node = null                              # the open modal (Akte, welcome card, rules)
var cabinet_button: Button
var album_button: Button
var rules_button: Button
var back_button: Button
var heft_button: Button

var _params: Dictionary = {}
var _ui: Dictionary = {}
var _ticket_row: HBoxContainer
var _focus_id: String = ""


func setup(params: Dictionary) -> void:
	_params = params


func _ready() -> void:
	UiUtil.full_rect(self)
	book = SdSession.book()
	if bool(_params.get("capture", false)):
		SdSession.use_sample()
	collection = SdSession.open()
	audio = SdAudio.new()
	audio.name = "SdAudio"
	audio.set("muted", bool(_params.get("mute", false)) or bool(_params.get("capture", false)))   # stills: silent
	add_child(audio)
	_build()
	refresh()
	_enter()
	if SdSession.take_reset_notice():
		Events.toast_requested.emit(SdSession.MSG_RESET, &"warning")
	_announce_new_cards()
	if not collection.tutorial and not bool(_params.get("no_welcome", false)):
		open_welcome.call_deferred()


## Back from the table / Aktenschrank / album (Router.pop payload).
func on_resume(payload: Dictionary) -> void:
	collection = SdSession.collection()
	refresh()
	_enter()
	if payload.has("rematch"):
		start_duel.call_deferred(str(payload["rematch"]), str(payload.get("mappe", collection.active)))
	elif payload.has("akte"):
		open_akte.call_deferred(str(payload["akte"]))


func _enter() -> void:
	Events.overlay_mode_requested.emit.call_deferred(&"menu")
	audio.call("music", &"sd_wartezimmer")
	_focus_default()


func _unhandled_input(event: InputEvent) -> void:
	if modal != null and is_instance_valid(modal):
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		leave()


func leave() -> void:
	audio.call("stop_all")
	Router.pop({})


# --- build ------------------------------------------------------------------------------------------------------------

func _build() -> void:
	_ui = SdScreen.build(self, "SCHALTERHALLE", "Bitte ziehen Sie eine Nummer.", str(collection.cosmetics.get("mat",
		"")))
	back_button = _ui["back"] as Button
	back_button.pressed.connect(leave)
	heft_button = UiUtil.button("", &"ButtonFlat")
	heft_button.name = "Heft"
	heft_button.custom_minimum_size = Vector2(380, 0)
	UiUtil.touch_pad(heft_button)
	heft_button.pressed.connect(func() -> void: open_album("heft"))
	var hrow: HBoxContainer = UiUtil.hbox(10)
	hrow.name = "HeftRow"
	hrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hrow.alignment = BoxContainer.ALIGNMENT_CENTER
	UiUtil.full_rect(hrow)
	heft_button.add_child(hrow)
	var marks: HBoxContainer = UiUtil.hbox(4)
	marks.name = "Marks"
	marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marks.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hrow.add_child(marks)
	var hl: Label = SdStyle.label("", 20, SdStyle.TEXT)
	hl.name = "HeftText"
	hl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hrow.add_child(hl)
	(_ui["right"] as HBoxContainer).add_child(heft_button)
	var col: VBoxContainer = _ui["col"] as VBoxContainer
	col.add_child(UiUtil.spacer(0, 0, true))
	_ticket_row = UiUtil.hbox(24)
	_ticket_row.name = "Tickets"
	_ticket_row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(_ticket_row)
	for oid: String in book.opponent_ids:
		var b: Button = _ticket(oid)
		_ticket_row.add_child(b)
		tickets[oid] = b
	col.add_child(UiUtil.spacer(0, 0, true))
	var bottom: HBoxContainer = UiUtil.hbox(SdScreen.GAP)
	bottom.name = "Bottom"
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(bottom)
	cabinet_button = SdScreen.big_button("Aktenschrank", "Cabinet", 300)
	cabinet_button.pressed.connect(func() -> void: open_cabinet(collection.active))
	bottom.add_child(cabinet_button)
	album_button = SdScreen.big_button("Stempelalbum", "Album", 300)
	album_button.pressed.connect(func() -> void: open_album(""))
	bottom.add_child(album_button)
	rules_button = SdScreen.big_button("Regeln & Lernduell", "Rules", 300)
	rules_button.pressed.connect(open_rules)
	bottom.add_child(rules_button)
	var row: Array = []
	for oid2: String in book.opponent_ids:
		row.append(tickets[oid2])
	SdScreen.wire_grid([[heft_button, back_button], row, [cabinet_button, album_button, rules_button]])


## A Wartemarke: paper ticket with the opponent's symbol, name and state (focus: cyan frame).
func _ticket(oid: String) -> Button:
	var b: Button = Button.new()
	b.name = "Ticket_" + oid
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = TICKET
	b.add_theme_stylebox_override("normal", SdStyle.panel_box(SdStyle.PAPER, Color("#c9bfa8"), 2, 12.0))
	b.add_theme_stylebox_override("hover", SdStyle.panel_box(Color("#fffaf0"), SdStyle.GOLD, 3, 12.0))
	b.add_theme_stylebox_override("pressed", SdStyle.panel_box(Color("#e6dccb"), SdStyle.GOLD, 3, 12.0))
	var focus: StyleBoxFlat = SdStyle.panel_box(Color(0, 0, 0, 0), SdStyle.CYAN, 5, 12.0)
	focus.draw_center = false
	focus.set_expand_margin_all(4.0)
	b.add_theme_stylebox_override("focus", focus)
	UiUtil.add_sounds(b)
	var col: VBoxContainer = UiUtil.vbox(6)
	col.name = "Face"
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	UiUtil.full_rect(col)
	col.offset_left = 14
	col.offset_right = -14
	col.offset_top = 12
	col.offset_bottom = -12
	b.add_child(col)
	var head: Label = SdStyle.label("WARTEMARKE", 16, SdStyle.PAPER_DIM, true)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(head)
	var opp: SdOpponentDef = book.opponent(oid)
	var sym: Control = SdIcons.icon(SdStyle.OPPONENT_ICONS.get(opp.symbol, &"person") as StringName, SdStyle.INK, 72)
	sym.set("color_2", SdStyle.PAPER)                    # the symbol's details in paper on the ink silhouette
	sym.name = "Symbol"
	sym.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(sym)
	var n: Label = SdStyle.label(opp.name, 22, SdStyle.INK, true)
	n.name = "Name"
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	n.custom_minimum_size = Vector2(TICKET.x - 28.0, 0)
	col.add_child(n)
	var st: HBoxContainer = UiUtil.hbox(6)
	st.name = "StateRow"
	st.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(st)
	var lock: Control = SdIcons.icon(&"lock", SdStyle.INK, 20)
	lock.name = "Lock"
	lock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	st.add_child(lock)
	var s: Label = SdStyle.label("", 18, SdStyle.INK)
	s.name = "State"
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	s.custom_minimum_size = Vector2(TICKET.x - 60.0, 0)
	st.add_child(s)
	b.pressed.connect(func() -> void: open_akte(oid))
	b.focus_entered.connect(func() -> void: _focus_id = oid)
	return b


## Ticket states, the Stempelheft and the button captions from the collection.
func refresh() -> void:
	for oid: String in tickets.keys():
		var b: Button = tickets[oid] as Button
		var reason: String = SdHallAkte.lock_reason(collection, book, oid)
		var wins: int = collection.wins_against(oid)
		var text: String = reason
		if reason == "":
			if oid == SdCollection.GRAF_OPPONENT:
				text = "Übung · besiegt %d ×" % wins if wins > 0 else "Übungsduell"
			else:
				text = "besiegt %d ×" % wins if wins > 0 else "NEU"
		(b.find_child("State", true, false) as Label).text = text
		(b.find_child("Lock", true, false) as Control).visible = reason != ""
		b.modulate = Color(0.78, 0.76, 0.8) if reason != "" else Color.WHITE
		b.set_meta("locked", reason != "")
		b.tooltip_text = text
	var owned: int = collection.owned.size()
	album_button.text = "Stempelalbum %d / %d" % [owned, book.card_ids.size()]
	cabinet_button.text = "Aktenschrank · Mappe %s" % collection.active.to_upper()
	(heft_button.find_child("HeftText", true, false) as Label).text = heft_text()
	_heft_marks(heft_button.find_child("Marks", true, false) as HBoxContainer)
	rules_button.text = "Regeln & Lernduell"


## "Stempelheft · noch 1 Sieg" next to the drawn fields (the next reward: the album's Stempelheft page).
func heft_text() -> String:
	var every: int = maxi(1, book.constant("heft_every"))
	var done: int = collection.heft % every
	if collection.next_heft_reward(book) == "":
		return "Stempelheft voll · %d Stempel" % collection.heft
	var left: int = every - done
	return "Stempelheft · noch %d %s" % [left, "Sieg" if left == 1 else "Siege"]


## The fields of the current Stempelheft block: stamped ones paper with the red stamp, open ones empty frames
## (10 §4.7 "Stempelheft: [S][S][ ]").
func _heft_marks(marks: HBoxContainer) -> void:
	for c: Node in marks.get_children():
		marks.remove_child(c)
		c.queue_free()
	var every: int = maxi(1, book.constant("heft_every"))
	var full: bool = collection.next_heft_reward(book) == ""
	for i in every:
		var stamped: bool = full or i < collection.heft % every
		var f: PanelContainer = PanelContainer.new()
		f.mouse_filter = Control.MOUSE_FILTER_IGNORE
		f.custom_minimum_size = Vector2(30, 30)
		f.add_theme_stylebox_override("panel", SdStyle.panel_box(SdStyle.PAPER if stamped else Color(0, 0, 0, 0),
			SdStyle.GOLD, 2, 2.0))
		if stamped:
			var ic: Control = SdIcons.icon(&"stamp", SdStyle.SEAL_RED, 22)
			ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			f.add_child(ic)
		marks.add_child(f)


func _focus_default() -> void:
	var target: Control = null
	if _focus_id != "" and tickets.has(_focus_id):
		target = tickets[_focus_id] as Control
	if target == null:
		for oid: String in book.opponent_ids:
			if not bool((tickets[oid] as Button).get_meta("locked", false)):
				target = tickets[oid] as Control
				break
	if target == null:
		target = rules_button if not collection.tutorial else cabinet_button
	UiUtil.focus_later(target)


func _announce_new_cards() -> void:
	for cid: String in SdSession.take_new_cards():
		var c: SdCardDef = book.card(cid)
		var lines: Array[Dictionary] = book.lines_for("sd_new_card")
		var text: String = str(lines[0]["text"]) if not lines.is_empty() else "Neue Karte im Stempelalbum: {card}."
		Events.toast_requested.emit(text.format({"card": c.name if c != null else cid}), &"info")


# --- actions ----------------------------------------------------------------------------------------------------------

func open_akte(oid: String) -> void:
	if not _free() or book.opponent(oid) == null:
		return
	_focus_id = oid
	_track(SdHallAkte.open(self, oid))


## A duel against `oid` with Mappe `mappe` (the table draws the seed and saves the collection first, 10 §6.6).
func start_duel(oid: String, mappe: String) -> void:
	if Router.busy and Router.current != self:
		return
	if collection.deck_problem(collection.deck(mappe), book) != "" or not collection.is_unlocked(oid, book):
		open_akte(oid)
		return
	audio.call("stop_all")
	Router.push(TABLE, {"opp": oid, "mappe": mappe}, Router.Transition.FADE)


func start_tutorial() -> void:
	audio.call("stop_all")
	Router.push(TABLE, {"tutorial": true}, Router.Transition.FADE)


func open_cabinet(mappe: String) -> void:
	if not _free():
		return
	if collection.owned.is_empty():
		Events.toast_requested.emit("Der Aktenschrank ist noch leer — erst das Lernduell.", &"info")
		return
	Router.push(CABINET, {"mappe": mappe}, Router.Transition.FADE)


func open_album(page: String) -> void:
	if not _free():
		return
	Router.push(ALBUM, {"page": page}, Router.Transition.FADE)


func open_rules() -> void:
	if not _free():
		return
	var m: Node = SdRulesPage.open(self, start_tutorial)
	var b: Button = m.find_child("Tutorial", true, false) as Button
	if b != null and not collection.tutorial:
		b.text = "Lernduell starten"
	_track(m)


## The welcome card before the Lernduell (10 §1.10): Lernduell · Ich kenne mich aus · Später.
func open_welcome() -> void:
	if not _free():
		return
	var m: Node = SdModal.new()
	m.call("setup", "SCHALTER 3", 760.0, SdStyle.GOLD)
	m.name = "Welcome"
	var box: VBoxContainer = m.get("content") as VBoxContainer
	var hall_line: Array[Dictionary] = book.lines_for("sd_hall")
	var t1: Label = SdStyle.label("M.O.D.: " + (str(hall_line[0]["text"]) if not hall_line.is_empty() else ""), 20,
		SdStyle.TEXT)
	t1.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t1.custom_minimum_size = Vector2(700, 0)
	box.add_child(t1)
	var t2: Label = SdStyle.label("Zuerst das Lernduell: sechs kurze Schritte gegen Ferdi Durchschlag. Danach gehört "
		+ "Ihnen die Grundakte — zwölf Karten und eine fertige Mappe.", 20, SdStyle.TEXT)
	t2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t2.custom_minimum_size = Vector2(700, 0)
	box.add_child(t2)
	var row: HBoxContainer = UiUtil.hbox(SdScreen.GAP)
	box.add_child(row)
	var go: Button = SdScreen.big_button("Lernduell starten", "StartTutorial")
	go.pressed.connect(func() -> void:
		m.call("close")
		start_tutorial())
	row.add_child(go)
	var skip: Button = SdScreen.big_button("Ich kenne mich aus", "Skip")
	skip.pressed.connect(func() -> void:
		m.call("close")
		skip_tutorial())
	row.add_child(skip)
	var pair: Array[Control] = [go, skip]
	UiUtil.wire_horizontal(pair)
	add_child(m)
	_track(m)


## "Ich kenne mich aus" in the hall: the Grundakte at once (SdCollection.complete_tutorial), toasted.
func skip_tutorial() -> void:
	var r: Dictionary = collection.complete_tutorial(book)
	SdSession.save()
	for line: String in SdResults.reward_lines(book, collection, r, true):
		Events.toast_requested.emit(line, &"info")
	refresh()
	_focus_default()


func _free() -> bool:
	return (modal == null or not is_instance_valid(modal)) and not Router.busy


## The open modal (an SdModal: its `closed` comes before it is freed — never a lambda that holds a freed node).
func _track(m: Node) -> void:
	modal = m
	if m != null and m.has_signal("closed"):
		var id: int = m.get_instance_id()
		m.connect("closed", func() -> void: _untrack(id))


func _untrack(id: int) -> void:
	if modal != null and is_instance_valid(modal) and modal.get_instance_id() != id:
		return
	modal = null
	if is_inside_tree():
		_focus_default()
