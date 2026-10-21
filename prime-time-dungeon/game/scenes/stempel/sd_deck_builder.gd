extends Control
## The Aktenschrank (10 §2.6, §4.7): left the owned cards as a grid (filters: Formular-Art, Herkunft, Werktage),
## right the Mappe (20 places, counter, the Bearbeitungszeit curve 1–6 WT as a small bar chart, the
## Aktenschrank's sentence when the Mappe cannot be chosen — SdCollection.deck_problem —, the cards in it) with
## "Automatisch füllen" (SdCollection.auto_fill), "Als aktive Mappe" and "Leeren" (asks first). Every change is
## saved at once (10 §6.7); nothing is overwritten without a confirmation. Controls (10 §2.6): tap / A / Enter on a
## card adds it, on a Mappe row removes one, X (keyboard X / Backspace, gamepad X) on a card removes one copy, a long
## press / Y / Tab / M shows the big view, Q / E / LB / RB switch the Mappe, Esc / B back. Params: {"mappe",
## "touch", "text_size"} (the latter two for tests and captures).

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const SdStyle := preload("res://scenes/stempel/sd_style.gd")
const SdIcons := preload("res://scenes/stempel/sd_icons.gd")
const SdSession := preload("res://scenes/stempel/sd_session.gd")
const SdScreen := preload("res://scenes/stempel/sd_screen.gd")
const SdModal := preload("res://scenes/stempel/sd_modal.gd")
const CardView := preload("res://scenes/stempel/sd_card_view.gd")

const RIGHT_W: float = 430.0
const LONG_PRESS_SEC: float = 0.4
const WT_FILTER: Array[int] = [0, 1, 2, 3, 4, 6]

## Bearbeitungszeit curve: cards per Werktag 1–6 as bars with the count above and "n WT" below.
class WtCurve extends Control:
	const Style := preload("res://scenes/stempel/sd_style.gd")
	var counts: Array[int] = [0, 0, 0, 0, 0, 0]:
		set(v):
			counts = v
			queue_redraw()

	func _draw() -> void:
		var f: Font = Style.font()
		var fb: Font = Style.bold()
		var n: int = counts.size()
		var top: float = 22.0
		var bottom: float = size.y - 22.0
		var bw: float = (size.x - 8.0 * float(n - 1)) / float(n)
		var peak: int = 1
		for c: int in counts:
			peak = maxi(peak, c)
		for i in n:
			var x: float = float(i) * (bw + 8.0)
			var h: float = (bottom - top) * float(counts[i]) / float(peak)
			draw_rect(Rect2(x, top, bw, bottom - top), Color(Style.PAPER, 0.06))
			if counts[i] > 0:
				draw_rect(Rect2(x, bottom - h, bw, h), Style.GOLD)
			var num: String = str(counts[i])
			var nw: float = fb.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			draw_string(fb, Vector2(x + (bw - nw) * 0.5, bottom - h - 4.0), num, HORIZONTAL_ALIGNMENT_LEFT, -1, 16,
				Style.TEXT)
			var lab: String = "%d WT" % (i + 1)
			var lw: float = f.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			draw_string(f, Vector2(x + (bw - lw) * 0.5, size.y - 4.0), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 16,
				Style.TEXT_DIM)


var book: SdRulebook = null
var collection: SdCollection = null
var mappe: String = "a"
var cards: PackedStringArray = []                   # the Mappe being edited (saved after every change)
var touch: bool = false
var text_size: int = 100
var filter_art: String = ""
var filter_origin: String = ""
var filter_wt: int = 0
var tiles: Dictionary = {}                          # card id → Button (visible grid tiles)
var rows: Array[Button] = []                        # the Mappe's rows (one per card id)
var modal: Node = null
var mappe_buttons: Array[Button] = []
var fill_button: Button
var active_button: Button
var clear_button: Button
var back_button: Button

var _params: Dictionary = {}
var _grid: GridContainer
var _grid_scroll: ScrollContainer
var _list: VBoxContainer
var _title: Label
var _banner: Label
var _curve: WtCurve
var _owned_label: Label
var _filters: Array[Button] = []
var _long_timer: Timer
var _long_fired: bool = false
var _long_id: String = ""
var _mapped: bool = false


func setup(params: Dictionary) -> void:
	_params = params


func _ready() -> void:
	UiUtil.full_rect(self)
	book = SdSession.book()
	if bool(_params.get("capture", false)):
		SdSession.use_sample()
	collection = SdSession.collection()
	mappe = str(_params.get("mappe", collection.active))
	if not SdCollection.MAPPEN.has(mappe):
		mappe = collection.active
	cards = collection.deck(mappe)
	touch = bool(_params.get("touch", Game.input_scheme == Game.InputScheme.TOUCH))
	text_size = int(_params.get("text_size", collection.options.get("text_size", 100)))
	_long_timer = Timer.new()
	_long_timer.one_shot = true
	_long_timer.wait_time = LONG_PRESS_SEC
	_long_timer.timeout.connect(_on_long_press)
	add_child(_long_timer)
	_build()
	_rebuild_grid()
	_refresh()
	_mapped = true
	CombatInput.apply_input_mode(false)                 # Tab → map, Y → toggle_auto: the big view (10 §4.6)
	Events.overlay_mode_requested.emit.call_deferred(&"menu")
	_focus_first()


func _exit_tree() -> void:
	if _mapped:
		_mapped = false
		CombatInput.apply_for_game()


func on_resume(_payload: Dictionary) -> void:
	CombatInput.apply_input_mode(false)
	_mapped = true


## The big view keys before the GUI: Tab is also the focus navigation's ui_focus_next.
func _input(event: InputEvent) -> void:
	if modal != null and is_instance_valid(modal):
		return
	if event.is_action_pressed(&"map") or event.is_action_pressed(&"toggle_auto"):
		var cid: String = _focused_card()
		if cid != "":
			get_viewport().set_input_as_handled()
			open_big_view(cid)


func _unhandled_input(event: InputEvent) -> void:
	if modal != null and is_instance_valid(modal):
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		leave()
	elif event.is_action_pressed(&"tab_next") or event.is_action_pressed(&"tab_prev"):
		get_viewport().set_input_as_handled()
		var i: int = SdCollection.MAPPEN.find(mappe)
		select_mappe(SdCollection.MAPPEN[posmod(i + (1 if event.is_action_pressed(&"tab_next") else -1),
			SdCollection.MAPPEN.size())])
	elif event.is_action_pressed(&"sd_file"):
		var cid2: String = _focused_card()
		if cid2 != "":
			get_viewport().set_input_as_handled()
			remove_card(cid2)


func leave() -> void:
	Router.pop({})


# --- build ------------------------------------------------------------------------------------------------------------

func _build() -> void:
	var ui: Dictionary = SdScreen.build(self, "AKTENSCHRANK", "", str(collection.cosmetics.get("mat", "")))
	back_button = ui["back"] as Button
	back_button.pressed.connect(leave)
	_owned_label = ui["sub"] as Label
	_owned_label.visible = true
	# the filters in the header (the grid gets the height for two full rows of cards)
	var right: HBoxContainer = ui["right"] as HBoxContainer
	var arts: PackedStringArray = ["alle"]
	for a: String in SdStyle.ARTS.keys():
		arts.append(SdStyle.art_name(a))
	var origins: PackedStringArray = ["alle"]
	for o: String in SdStyle.ORIGINS.keys():
		origins.append(str(SdStyle.ORIGINS[o]))
	var wts: PackedStringArray = ["alle"]
	for w: int in WT_FILTER.slice(1):
		wts.append(str(w))
	_filters.append(SdScreen.cycle_button("Art", arts, func(i: int) -> void:
		filter_art = "" if i == 0 else str(SdStyle.ARTS.keys()[i - 1])
		_rebuild_grid(), "FilterArt"))
	_filters.append(SdScreen.cycle_button("Herkunft", origins, func(i: int) -> void:
		filter_origin = "" if i == 0 else str(SdStyle.ORIGINS.keys()[i - 1])
		_rebuild_grid(), "FilterOrigin"))
	_filters.append(SdScreen.cycle_button("Werktage", wts, func(i: int) -> void:
		filter_wt = WT_FILTER[i]
		_rebuild_grid(), "FilterWt"))
	for fb: Button in _filters:
		right.add_child(fb)
	var body: HBoxContainer = UiUtil.hbox(16)
	body.name = "Body"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	(ui["col"] as VBoxContainer).add_child(body)
	_grid_scroll = ScrollContainer.new()
	_grid_scroll.name = "GridScroll"
	_grid_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_grid_scroll.follow_focus = true
	body.add_child(_grid_scroll)
	_grid = GridContainer.new()
	_grid.name = "Grid"
	_grid.add_theme_constant_override("h_separation", SdScreen.GAP)
	_grid.add_theme_constant_override("v_separation", SdScreen.GAP)
	_grid_scroll.add_child(_grid)
	_grid_scroll.resized.connect(_update_columns)
	var panel: PanelContainer = SdScreen.section(Vector2(RIGHT_W, 0))
	panel.name = "MappePanel"
	body.add_child(panel)
	var rcol: VBoxContainer = UiUtil.vbox(10)
	panel.add_child(rcol)
	var tabs: HBoxContainer = UiUtil.hbox(SdScreen.GAP)
	tabs.name = "Mappen"
	rcol.add_child(tabs)
	var group: ButtonGroup = ButtonGroup.new()
	for name: String in SdCollection.MAPPEN:
		var b: Button = UiUtil.button("Mappe " + name.to_upper(), &"ButtonFlat")
		b.name = "Mappe" + name.to_upper()
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.toggle_mode = true
		b.button_group = group
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UiUtil.touch_pad(b)
		b.pressed.connect(func() -> void: select_mappe(name))
		tabs.add_child(b)
		mappe_buttons.append(b)
	_title = SdStyle.label("", 20, SdStyle.TEXT, true)
	_title.name = "MappeTitle"
	rcol.add_child(_title)
	_curve = WtCurve.new()
	_curve.name = "Curve"
	_curve.custom_minimum_size = Vector2(RIGHT_W - 28.0, 84)
	_curve.tooltip_text = "Bearbeitungszeit der Mappe"
	rcol.add_child(_curve)
	_banner = SdStyle.label("", 18, SdStyle.TEXT)
	_banner.name = "Banner"
	_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner.custom_minimum_size = Vector2(RIGHT_W - 28.0, 0)
	rcol.add_child(_banner)
	var ls: ScrollContainer = ScrollContainer.new()
	ls.name = "ListScroll"
	ls.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ls.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ls.follow_focus = true
	rcol.add_child(ls)
	_list = UiUtil.vbox(SdScreen.GAP)
	_list.name = "List"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ls.add_child(_list)
	var brow: HBoxContainer = UiUtil.hbox(SdScreen.GAP)
	rcol.add_child(brow)
	fill_button = _small_button("Auffüllen", "Fill")
	fill_button.tooltip_text = "Automatisch füllen"
	fill_button.pressed.connect(auto_fill)
	brow.add_child(fill_button)
	active_button = _small_button("Aktiv setzen", "Active")
	active_button.pressed.connect(make_active)
	brow.add_child(active_button)
	clear_button = _small_button("Leeren", "Clear")
	clear_button.pressed.connect(ask_clear)
	brow.add_child(clear_button)


func _small_button(text: String, name: String) -> Button:
	var b: Button = UiUtil.button(text, &"ButtonFlat")
	b.name = name
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiUtil.touch_pad(b)
	return b


## Owned cards that pass the filters, cards.json order.
func visible_cards() -> PackedStringArray:
	var out: PackedStringArray = []
	for cid: String in book.card_ids:
		var c: SdCardDef = book.card(cid)
		if not collection.owns(cid):
			continue
		if filter_art != "" and c.art != filter_art:
			continue
		if filter_origin != "" and c.origin != filter_origin:
			continue
		if filter_wt > 0 and c.rank() != filter_wt:
			continue
		out.append(cid)
	return out


func _rebuild_grid() -> void:
	var keep: String = _focused_card()
	for c: Node in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	tiles.clear()
	var ids: PackedStringArray = visible_cards()
	for cid: String in ids:
		var t: Button = _tile(cid)
		_grid.add_child(t)
		tiles[cid] = t
	_owned_label.text = "%d von %d Karten im Besitz" % [collection.owned.size(), book.card_ids.size()] if ids.size() \
		== collection.owned.size() else "%d passen zum Filter" % ids.size()
	_update_columns()
	_refresh_tiles()
	if keep != "" and tiles.has(keep):
		UiUtil.focus_later(tiles[keep] as Control)


## A grid tile: the card (sd_card_view.gd) and "in der Mappe: n / max" below; a button of its own (≥ 88 px).
func _tile(cid: String) -> Button:
	var c: SdCardDef = book.card(cid)
	var b: Button = Button.new()
	b.name = "Tile_" + cid
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("hover", SdStyle.panel_box(Color(SdStyle.PAPER, 0.08), Color(SdStyle.GOLD, 0.6), 2,
		0.0))
	b.add_theme_stylebox_override("pressed", SdStyle.panel_box(Color(SdStyle.GOLD, 0.18), SdStyle.GOLD, 2, 0.0))
	var focus: StyleBoxFlat = SdStyle.panel_box(Color(0, 0, 0, 0), SdStyle.CYAN, 4, 0.0)
	focus.draw_center = false
	b.add_theme_stylebox_override("focus", focus)
	UiUtil.add_sounds(b)
	var cs: Vector2 = SdStyle.card_size(touch)
	b.custom_minimum_size = Vector2(cs.x + 8.0, cs.y + 40.0)
	var v: Control = CardView.new()
	v.name = "Card"
	v.call("setup", c, touch, text_size, false)
	v.position = Vector2(4, 4)
	b.add_child(v)
	var l: Label = SdStyle.label("", SdStyle.min_text(touch), SdStyle.TEXT)
	l.name = "Count"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = Vector2(0, cs.y + 8.0)
	l.size = Vector2(cs.x + 8.0, 28)
	b.add_child(l)
	b.button_down.connect(func() -> void:
		_long_fired = false
		if touch or Game.input_scheme == Game.InputScheme.TOUCH:
			_long_id = cid
			_long_timer.start())
	b.button_up.connect(func() -> void: _long_timer.stop())
	b.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed \
				and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
			open_big_view(cid))
	b.pressed.connect(func() -> void:
		if _long_fired:
			_long_fired = false
			return
		add_card(cid))
	return b


func _update_columns() -> void:
	if _grid == null:
		return
	var tw: float = SdStyle.card_size(touch).x + 8.0 + SdScreen.GAP
	var avail: float = _grid_scroll.size.x - 14.0
	_grid.columns = maxi(1, int(floor((avail + SdScreen.GAP) / tw)))
	_wire_grid()


func _on_long_press() -> void:
	_long_fired = true
	if _long_id != "":
		open_big_view(_long_id)


# --- the Mappe --------------------------------------------------------------------------------------------------------

## How many more copies of `cid` may go into the Mappe (copy limits, 20 places).
func room_for(cid: String) -> int:
	var c: SdCardDef = book.card(cid)
	if c == null or not collection.owns(cid):
		return 0
	var cap: int = mini(c.max_copies, book.constant("max_copies_show") if c.show else book.constant("max_copies"))
	return mini(cap - cards.count(cid), book.deck_size() - cards.size())


func copies_allowed(cid: String) -> int:
	var c: SdCardDef = book.card(cid)
	return mini(c.max_copies, book.constant("max_copies_show") if c.show else book.constant("max_copies"))


func add_card(cid: String) -> bool:
	if room_for(cid) <= 0:
		Sfx.play_ui(&"ui_error")
		_banner_flash(_full_reason(cid))
		return false
	cards.append(cid)
	_changed()
	return true


func remove_card(cid: String) -> bool:
	var i: int = cards.rfind(cid)
	if i < 0:
		Sfx.play_ui(&"ui_error")
		return false
	cards.remove_at(i)
	_changed()
	return true


func auto_fill() -> void:
	cards = collection.auto_fill(cards, book)
	_changed()


func make_active() -> void:
	if collection.deck_problem(cards, book) != "":
		Sfx.play_ui(&"ui_error")
		return
	collection.set_active(mappe)
	SdSession.save()
	_refresh()


func ask_clear() -> void:
	if cards.is_empty():
		return
	var d: Node = (load("res://scenes/ui/confirm_dialog.tscn") as PackedScene).instantiate()
	d.call("setup", {"title": "Mappe %s leeren?" % mappe.to_upper(), "text": "Alle %d Karten gehen zurück in den "
		% cards.size() + "Aktenschrank. Ihre Sammlung bleibt.", "yes": "Leeren", "no": "Behalten", "default_no": true})
	d.connect("closed", func(yes: bool) -> void:
		modal = null
		if yes:
			cards = PackedStringArray()
			_changed()
		UiUtil.focus_later(clear_button))
	add_child(d)
	modal = d


func select_mappe(name: String) -> void:
	if not SdCollection.MAPPEN.has(name):
		return
	mappe = name
	cards = collection.deck(mappe)
	_refresh()


func _changed() -> void:
	collection.set_deck(mappe, cards)
	SdSession.save()
	_refresh()


func _full_reason(cid: String) -> String:
	if cards.size() >= book.deck_size():
		return "Die Mappe ist voll (%d Karten). Erst eine Karte herausnehmen." % book.deck_size()
	return "%s ist schon %d × in der Mappe — mehr geht nicht." % [book.card(cid).name, copies_allowed(cid)]


func _banner_flash(text: String) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", SdStyle.GOLD)


## Title, curve, banner, rows and the tiles' counters from `cards`.
func _refresh() -> void:
	for b: Button in mappe_buttons:
		b.set_pressed_no_signal(b.name == "Mappe" + mappe.to_upper())
	var active: bool = collection.active == mappe
	_title.text = "%d / %d Karten%s · Bearbeitungszeit:" % [cards.size(), book.deck_size(), " · aktive Mappe"
		if active else ""]
	var wt: Array[int] = [0, 0, 0, 0, 0, 0]
	for cid: String in cards:
		var r: int = clampi(book.card(cid).rank(), 1, 6)
		wt[r - 1] += 1
	_curve.counts = wt
	var problem: String = collection.deck_problem(cards, book)
	_banner.text = problem if problem != "" else ("Bereit: Diese Mappe kann ins Duell." if active else
		"Bereit. „Aktiv setzen“ macht sie zur Mappe der Schalterhalle.")
	_banner.add_theme_color_override("font_color", SdStyle.DANGER if problem != "" else SdStyle.OK)
	active_button.disabled = problem != "" or active
	clear_button.disabled = cards.is_empty()
	fill_button.disabled = cards.size() >= book.deck_size()
	_rebuild_rows()
	_refresh_tiles()


func _refresh_tiles() -> void:
	for cid: String in tiles.keys():
		var t: Button = tiles[cid] as Button
		var n: int = cards.count(cid)
		var l: Label = t.get_node("Count") as Label
		l.text = "in der Mappe: %d / %d" % [n, copies_allowed(cid)]
		l.add_theme_color_override("font_color", SdStyle.GOLD if n > 0 else SdStyle.TEXT_DIM)
		(t.get_node("Card") as Control).set("dim", room_for(cid) <= 0 and n == 0)


func _rebuild_rows() -> void:
	var keep: String = ""
	var fo: Control = get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if fo != null and fo.has_meta("card"):
		keep = str(fo.get_meta("card"))
	for r: Button in rows:
		_list.remove_child(r)
		r.queue_free()
	rows.clear()
	var order: PackedStringArray = []
	for cid: String in book.card_ids:
		if cards.has(cid):
			order.append(cid)
	for cid2: String in order:
		var c: SdCardDef = book.card(cid2)
		var b: Button = UiUtil.button("", &"ButtonFlat")
		b.name = "Row_" + cid2
		b.set_meta("card", cid2)
		b.text = "%d × %s · %d WT" % [cards.count(cid2), c.name, c.rank()]
		b.tooltip_text = "Antippen: eine Karte heraus"
		UiUtil.touch_pad(b)
		_indent(b, 48.0)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var ic: Control = SdIcons.icon(SdStyle.art_icon(c.art), SdStyle.art_band(c.art), 24)
		ic.position = Vector2(12, 32)
		b.add_child(ic)
		b.pressed.connect(func() -> void:
			remove_card(cid2)
			if cards.has(cid2):
				UiUtil.focus_later(_row_of(cid2))
			elif not rows.is_empty():
				UiUtil.focus_later(rows[0])
			else:
				UiUtil.focus_later(fill_button))
		_list.add_child(b)
		rows.append(b)
	var empty: Node = _list.get_node_or_null("Empty")
	if order.is_empty() and empty == null:
		var e: Label = SdStyle.label("Noch leer. Karten links antippen — oder „Auffüllen“.", 18, SdStyle.TEXT_DIM)
		e.name = "Empty"
		e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		e.custom_minimum_size = Vector2(RIGHT_W - 40.0, 0)
		_list.add_child(e)
	elif not order.is_empty() and empty != null:
		_list.remove_child(empty)
		empty.queue_free()
	_wire_grid()
	if keep != "" and _row_of(keep) != null:
		UiUtil.focus_later(_row_of(keep))


## Room for the art symbol left of a row's text (every state stylebox gets a wider left content margin).
static func _indent(b: Button, px: float) -> void:
	for st: String in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		if b.has_theme_stylebox_override(st):
			var sb: StyleBox = b.get_theme_stylebox(st).duplicate() as StyleBox
			sb.content_margin_left = px
			b.add_theme_stylebox_override(st, sb)


func _row_of(cid: String) -> Button:
	for r: Button in rows:
		if str(r.get_meta("card", "")) == cid:
			return r
	return null


## Focus: filters / Mappe tabs on top, the grid (rows of `columns`), the Mappe rows on the right, the buttons below.
func _wire_grid() -> void:
	if _grid == null or fill_button == null:
		return
	var grid_rows: Array[Array] = []
	var n: int = _grid.get_child_count()
	var cols: int = maxi(1, _grid.columns)
	for i in n:
		if i % cols == 0:
			grid_rows.append([])
		var t: Node = _grid.get_child(i)
		if not t.is_queued_for_deletion():
			(grid_rows[grid_rows.size() - 1] as Array).append(t)
	var top: Array = []
	for f: Button in _filters:
		top.append(f)
	var all_rows: Array[Array] = []
	all_rows.append(top)
	all_rows.append_array(grid_rows)
	SdScreen.wire_grid(all_rows)
	var side: Array[Control] = []
	for r: Button in rows:
		side.append(r)
	side.append(fill_button)
	UiUtil.wire_vertical(side, false)
	var buttons: Array[Control] = [fill_button, active_button, clear_button]
	UiUtil.wire_horizontal(buttons, false)
	for i2 in grid_rows.size():
		var row: Array = grid_rows[i2]
		if row.is_empty():
			continue
		var last: Control = row[row.size() - 1] as Control
		var target: Control = rows[mini(i2, rows.size() - 1)] if not rows.is_empty() else fill_button
		last.focus_neighbor_right = last.get_path_to(target)
	for r2: Button in rows:
		var first_tile: Control = grid_rows[0][0] as Control if not grid_rows.is_empty() else _filters[0]
		r2.focus_neighbor_left = r2.get_path_to(first_tile)
	fill_button.focus_neighbor_left = fill_button.get_path_to(_filters[0])
	var tabs: Array[Control] = []
	for mb: Button in mappe_buttons:
		tabs.append(mb)
	UiUtil.wire_horizontal(tabs, false)
	for t2: Control in tabs:
		t2.focus_neighbor_bottom = t2.get_path_to(rows[0] if not rows.is_empty() else fill_button)
		t2.focus_neighbor_top = t2.get_path_to(back_button)
	if not rows.is_empty():
		rows[0].focus_neighbor_top = rows[0].get_path_to(mappe_buttons[0])
	else:
		fill_button.focus_neighbor_top = fill_button.get_path_to(mappe_buttons[0])
	var head: Array[Control] = []
	for f2: Button in _filters:
		head.append(f2)
	head.append(back_button)
	UiUtil.wire_horizontal(head, false)
	back_button.focus_neighbor_bottom = back_button.get_path_to(mappe_buttons[mappe_buttons.size() - 1])


func _focused_card() -> String:
	if not is_inside_tree():
		return ""
	var fo: Control = get_viewport().gui_get_focus_owner()
	if fo == null:
		return ""
	if fo.has_meta("card"):
		return str(fo.get_meta("card"))
	for cid: String in tiles.keys():
		if tiles[cid] == fo:
			return cid
	return ""


func _focus_first() -> void:
	if _grid.get_child_count() > 0:
		UiUtil.focus_later(_grid.get_child(0) as Control)
	else:
		UiUtil.focus_later(back_button)


# --- big view ---------------------------------------------------------------------------------------------------------

## The card twice as large with its full text and Hinzufügen / Herausnehmen (10 §2.6 "langes Drücken / Y vergrößert").
func open_big_view(cid: String) -> void:
	if modal != null and is_instance_valid(modal):
		return
	var c: SdCardDef = book.card(cid)
	if c == null:
		return
	var m: Node = SdModal.new()
	m.call("setup", "", 0.0, UiTheme.C_ACCENT_2, 0.7)
	m.name = "BigView"
	var row: HBoxContainer = UiUtil.hbox(20)
	(m.get("content") as VBoxContainer).add_child(row)
	var v: Control = CardView.new()
	v.call("setup", c, touch, text_size, true)
	row.add_child(v)
	var side: VBoxContainer = UiUtil.vbox(SdScreen.GAP)
	side.custom_minimum_size = Vector2(340, 0)
	row.add_child(side)
	var t: Label = SdStyle.label(c.text, 20, SdStyle.TEXT)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(340, 0)
	side.add_child(t)
	var cnt: Label = SdStyle.label("In der Mappe: %d / %d" % [cards.count(cid), copies_allowed(cid)], 18,
		SdStyle.TEXT_DIM)
	side.add_child(cnt)
	var add: Button = SdScreen.big_button("Hinzufügen", "Add")
	add.disabled = room_for(cid) <= 0
	add.pressed.connect(func() -> void:
		add_card(cid)
		m.call("close"))
	side.add_child(add)
	var rem: Button = SdScreen.big_button("Herausnehmen", "Remove")
	rem.disabled = not cards.has(cid)
	rem.pressed.connect(func() -> void:
		remove_card(cid)
		m.call("close"))
	side.add_child(rem)
	add_child(m)
	modal = m
	m.connect("closed", func() -> void: modal = null)
