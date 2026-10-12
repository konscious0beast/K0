extends Control
## The Stempelalbum (10 §4.7, §5.2): pages per origin (Amt, Kandidat:in, Graf, Gegenstände, Talente, Trophäen) with
## the owned cards and the missing ones as outlines with the way there ("Erster Sieg gegen Ferdi Durchschlag",
## "Stempelheft: noch 2 Siege", "Der Graf lernt Frostniesen"), the Stempelheft (stamps, the fixed reward order, the
## next reward), the Dienstauszeichnungen and the cosmetics (Kartenrücken, Stempelfarbe, Tischunterlage, Titel — equip
## per slot, saved at once). Nothing to buy, nothing rolled (10 §5.1). Q / E / LB / RB switch pages, a card opens its
## big view, Esc / B back. Params: {"page" ("" = Amt, "heft", "awards", "cosmetics" or an origin), "touch",
## "text_size"}.

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const SdStyle := preload("res://scenes/stempel/sd_style.gd")
const SdIcons := preload("res://scenes/stempel/sd_icons.gd")
const SdSession := preload("res://scenes/stempel/sd_session.gd")
const SdScreen := preload("res://scenes/stempel/sd_screen.gd")
const SdModal := preload("res://scenes/stempel/sd_modal.gd")
const CardView := preload("res://scenes/stempel/sd_card_view.gd")

## Page id → tab caption (origins first, in SdCardDef.ORIGINS order).
const PAGES: Dictionary = {"amt": "Amt", "kandidat": "Kandidat:in", "graf": "Graf", "gegenstand": "Gegenstände",
	"talent": "Talente", "trophaee": "Trophäen", "heft": "Stempelheft", "awards": "Auszeichnungen",
	"cosmetics": "Kosmetik"}
const SLOTS: Dictionary = {"back": "Kartenrücken", "ink": "Stempelfarbe", "mat": "Tischunterlage", "title": "Titel"}


## A missing card: a dashed outline with its name and the way there (one canvas item).
class Outline extends Control:
	const Style := preload("res://scenes/stempel/sd_style.gd")
	var title: String = ""
	var way: String = ""
	var text_px: int = 16

	func _draw() -> void:
		var r: Rect2 = Rect2(Vector2(2, 2), size - Vector2(4, 4))
		draw_rect(r, Color(Style.INK, 0.94), true)               # opaque enough: the stage line never runs through
		draw_rect(r, Color(Style.PAPER, 0.05), true)
		var dash: float = 10.0
		var x: float = r.position.x
		while x < r.end.x:
			draw_line(Vector2(x, r.position.y), Vector2(minf(x + dash, r.end.x), r.position.y), Style.TEXT_DIM, 2.0)
			draw_line(Vector2(x, r.end.y), Vector2(minf(x + dash, r.end.x), r.end.y), Style.TEXT_DIM, 2.0)
			x += dash * 2.0
		var y: float = r.position.y
		while y < r.end.y:
			draw_line(Vector2(r.position.x, y), Vector2(r.position.x, minf(y + dash, r.end.y)), Style.TEXT_DIM, 2.0)
			draw_line(Vector2(r.end.x, y), Vector2(r.end.x, minf(y + dash, r.end.y)), Style.TEXT_DIM, 2.0)
			y += dash * 2.0
		var f: Font = Style.bold()
		var tw: float = r.size.x - 20.0
		var yy: float = r.position.y + 14.0 + text_px
		for line: String in Style.wrap_lines(title, f, text_px + 2, tw):
			draw_string(f, Vector2(r.position.x + 10.0, yy), line, HORIZONTAL_ALIGNMENT_LEFT, -1, text_px + 2, Style.TEXT)
			yy += (text_px + 2) * 1.2
		yy += 8.0
		for line2: String in Style.wrap_lines(way, Style.font(), text_px, tw):
			if yy > r.end.y - 8.0:
				break
			draw_string(Style.font(), Vector2(r.position.x + 10.0, yy), line2, HORIZONTAL_ALIGNMENT_LEFT, -1, text_px,
				Style.GOLD)
			yy += text_px * 1.25


var book: SdRulebook = null
var collection: SdCollection = null
var page: String = "amt"
var touch: bool = false
var text_size: int = 100
var tabs: Dictionary = {}                           # page id → Button
var items: Array[Control] = []                      # focusable controls of the current page (reading order)
var modal: Node = null
var back_button: Button

var _params: Dictionary = {}
var _content: VBoxContainer
var _scroll: ScrollContainer
var _sub: Label


func setup(params: Dictionary) -> void:
	_params = params


func _ready() -> void:
	UiUtil.full_rect(self)
	book = SdSession.book()
	if bool(_params.get("capture", false)):
		SdSession.use_sample()
	collection = SdSession.collection()
	touch = bool(_params.get("touch", Game.input_scheme == Game.InputScheme.TOUCH))
	text_size = int(_params.get("text_size", collection.options.get("text_size", 100)))
	var p: String = str(_params.get("page", ""))
	page = p if PAGES.has(p) else "amt"
	_build()
	show_page(page)
	Events.overlay_mode_requested.emit.call_deferred(&"menu")


func _unhandled_input(event: InputEvent) -> void:
	if modal != null and is_instance_valid(modal):
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		Router.pop({})
	elif event.is_action_pressed(&"tab_next") or event.is_action_pressed(&"tab_prev"):
		get_viewport().set_input_as_handled()
		var ids: Array = PAGES.keys()
		var i: int = ids.find(page)
		show_page(str(ids[posmod(i + (1 if event.is_action_pressed(&"tab_next") else -1), ids.size())]))
		UiUtil.focus_later(tabs[page] as Control)


func _build() -> void:
	var ui: Dictionary = SdScreen.build(self, "STEMPELALBUM", "", str(collection.cosmetics.get("mat", "")))
	back_button = ui["back"] as Button
	back_button.pressed.connect(func() -> void: Router.pop({}))
	_sub = ui["sub"] as Label
	_sub.visible = true
	# the card pages in a row of their own, Stempelheft · Auszeichnungen · Kosmetik in the header
	var flow: HFlowContainer = HFlowContainer.new()
	flow.name = "Tabs"
	flow.add_theme_constant_override("h_separation", SdScreen.GAP)
	flow.add_theme_constant_override("v_separation", SdScreen.GAP)
	(ui["col"] as VBoxContainer).add_child(flow)
	var group: ButtonGroup = ButtonGroup.new()
	for id: String in PAGES.keys():
		var b: Button = UiUtil.button(str(PAGES[id]), &"ButtonFlat")
		b.name = "Tab_" + id
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size.x = 88
		UiUtil.touch_pad(b)
		b.pressed.connect(func() -> void: show_page(id))
		if SdCardDef.ORIGINS.has(id):
			flow.add_child(b)
		else:
			(ui["right"] as HBoxContainer).add_child(b)
		tabs[id] = b
	_scroll = ScrollContainer.new()
	_scroll.name = "Page"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_scroll.resized.connect(_update_columns)
	(ui["col"] as VBoxContainer).add_child(_scroll)
	_content = UiUtil.vbox(SdScreen.GAP)
	_content.name = "Content"
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_content)


func show_page(id: String) -> void:
	page = id if PAGES.has(id) else "amt"
	for k: String in tabs.keys():
		(tabs[k] as Button).set_pressed_no_signal(k == page)
	for c: Node in _content.get_children():
		_content.remove_child(c)
		c.queue_free()
	items.clear()
	_sub.text = "%d von %d Karten im Album" % [collection.owned.size(), book.card_ids.size()]
	match page:
		"heft":
			_page_heft()
		"awards":
			_page_awards()
		"cosmetics":
			_page_cosmetics()
		_:
			_page_cards(page)
	_wire()


# --- card pages ---------------------------------------------------------------------------------------------------

func _page_cards(origin: String) -> void:
	var ids: PackedStringArray = []
	for cid: String in book.card_ids:
		if book.card(cid).origin == origin:
			ids.append(cid)
	var have: int = 0
	for cid2: String in ids:
		if collection.owns(cid2):
			have += 1
	_content.add_child(SdStyle.label("%s: %d von %d" % [str(PAGES[origin]), have, ids.size()], 20, SdStyle.GOLD, true))
	var grid: GridContainer = GridContainer.new()
	grid.name = "Cards"
	grid.add_theme_constant_override("h_separation", SdScreen.GAP)
	grid.add_theme_constant_override("v_separation", SdScreen.GAP)
	var cs: Vector2 = SdStyle.card_size(touch)
	grid.columns = maxi(1, int(floor((_frame_width() - 14.0 + SdScreen.GAP) / (cs.x + 8.0 + SdScreen.GAP))))
	_content.add_child(grid)
	for cid3: String in ids:
		var b: Button = _card_tile(cid3)
		grid.add_child(b)
		items.append(b)


func _card_tile(cid: String) -> Button:
	var c: SdCardDef = book.card(cid)
	var cs: Vector2 = SdStyle.card_size(touch)
	var b: Button = Button.new()
	b.name = "Card_" + cid
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = cs + Vector2(8, 8)
	b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("hover", SdStyle.panel_box(Color(SdStyle.PAPER, 0.08), Color(SdStyle.GOLD, 0.6), 2,
		0.0))
	b.add_theme_stylebox_override("pressed", SdStyle.panel_box(Color(SdStyle.GOLD, 0.18), SdStyle.GOLD, 2, 0.0))
	var focus: StyleBoxFlat = SdStyle.panel_box(Color(0, 0, 0, 0), SdStyle.CYAN, 4, 0.0)
	focus.draw_center = false
	b.add_theme_stylebox_override("focus", focus)
	UiUtil.add_sounds(b)
	if collection.owns(cid):
		var v: Control = CardView.new()
		v.name = "View"
		v.call("setup", c, touch, text_size, false)
		v.position = Vector2(4, 4)
		b.add_child(v)
	else:
		var o: Outline = Outline.new()
		o.name = "Outline"
		o.title = c.name
		o.way = way_to(cid)
		o.text_px = SdStyle.min_text(touch)
		o.mouse_filter = Control.MOUSE_FILTER_IGNORE
		o.position = Vector2(4, 4)
		o.size = cs
		b.add_child(o)
		b.set_meta("missing", true)
	b.set_meta("card", cid)
	b.pressed.connect(func() -> void: open_big_view(cid))
	return b


## The way to a missing card (10 §4.7): Lernduell, first victories, the Stempelheft, the campaign.
func way_to(cid: String) -> String:
	var c: SdCardDef = book.card(cid)
	var ways: PackedStringArray = []
	if book.grundakte.has(cid) and not collection.tutorial:
		ways.append("Lernduell beenden")
	for oid: String in book.opponent_ids:
		if book.opponent(oid).first_win_cards().has(cid):
			ways.append("Erster Sieg gegen %s" % book.opponent(oid).name)
	var k: int = _heft_rank(cid)
	if k >= 0:
		var every: int = maxi(1, book.constant("heft_every"))
		var n: int = every - collection.heft % every + k * every
		ways.append("Stempelheft: noch %d %s" % [n, "Sieg" if n == 1 else "Siege"])
	if not c.campaign.is_empty():
		match c.origin:
			"kandidat":
				ways.append("Kampagne: Kai lernt %s" % c.name)
			"graf":
				ways.append("Kampagne: Der Graf lernt %s" % c.name)
			"gegenstand":
				ways.append("Kampagne: %s einmal besitzen" % c.name)
			"talent":
				ways.append("Kampagne: Talent %s %s" % [c.name, "des Grafen" if c.owner == "graf" else "von Kai"])
	return " · ".join(ways) if not ways.is_empty() else "Noch kein Weg bekannt."


## Position of `cid` among the Stempelheft entries not owned yet (0 = the next reward), -1 if not in the heft.
func _heft_rank(cid: String) -> int:
	var k: int = 0
	for id: String in book.heft:
		if collection.owns(id) or collection.owns_cosmetic(id):
			continue
		if id == cid:
			return k
		k += 1
	return -1


func open_big_view(cid: String) -> void:
	if modal != null and is_instance_valid(modal):
		return
	var c: SdCardDef = book.card(cid)
	var m: Node = SdModal.new()
	m.call("setup", "", 0.0, UiTheme.C_ACCENT_2, 0.7)
	m.name = "BigView"
	var row: HBoxContainer = UiUtil.hbox(20)
	(m.get("content") as VBoxContainer).add_child(row)
	if collection.owns(cid):
		var v: Control = CardView.new()
		v.call("setup", c, touch, text_size, true)
		row.add_child(v)
	var side: VBoxContainer = UiUtil.vbox(SdScreen.GAP)
	side.custom_minimum_size = Vector2(360, 0)
	row.add_child(side)
	side.add_child(SdStyle.label(c.name, 26, SdStyle.TEXT, true))
	var t: Label = SdStyle.label(c.text if collection.owns(cid) else "Noch nicht im Album.", 20, SdStyle.TEXT)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(360, 0)
	side.add_child(t)
	var w: Label = SdStyle.label(("Herkunft: %s" % str(SdStyle.ORIGINS.get(c.origin, c.origin))) if collection.owns(cid)
		else way_to(cid), 18, SdStyle.GOLD)
	w.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	w.custom_minimum_size = Vector2(360, 0)
	side.add_child(w)
	add_child(m)
	modal = m
	m.connect("closed", func() -> void: modal = null)


# --- Stempelheft ----------------------------------------------------------------------------------------------------

func _page_heft() -> void:
	var every: int = maxi(1, book.constant("heft_every"))
	_content.add_child(SdStyle.label("STEMPELHEFT · %d Stempel" % collection.heft, 22, SdStyle.GOLD, true))
	var intro: Label = SdStyle.label("Jeder Sieg stempelt ein Feld. Je %d Stempel gibt es das nächste Stück der "
		% every + "festen Reihenfolge — was Sie schon besitzen, wird übersprungen.", 18, SdStyle.TEXT)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.custom_minimum_size = Vector2(minf(_frame_width() - 40.0, 900.0), 0)
	_content.add_child(intro)
	var fields: HBoxContainer = UiUtil.hbox(10)
	fields.name = "Fields"
	_content.add_child(fields)
	var done: int = collection.heft % every
	var full: bool = collection.next_heft_reward(book) == ""
	for i in every:
		var stamped: bool = full or i < done
		var f: PanelContainer = PanelContainer.new()
		f.custom_minimum_size = Vector2(64, 64)
		f.add_theme_stylebox_override("panel", SdStyle.panel_box(Color(SdStyle.PAPER, 0.9 if stamped else 0.12),
			SdStyle.GOLD, 2, 4.0))
		var ic: Control = SdIcons.icon(&"stamp" if stamped else &"dot", SdStyle.SEAL_RED if stamped else SdStyle.TEXT_DIM,
			40)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		f.add_child(ic)
		fields.add_child(f)
	var nxt: String = collection.next_heft_reward(book)
	var left: int = every - done
	var status: Label = SdStyle.label("Heft voll — alles erhalten." if full else "Nächste Belohnung: %s — noch %d %s."
		% [_reward_name(nxt), left, "Sieg" if left == 1 else "Siege"], 20, SdStyle.TEXT, true)
	status.name = "Next"
	_content.add_child(status)
	_content.add_child(SdStyle.label("Reihenfolge", 20, SdStyle.GOLD, true))
	for id: String in book.heft:
		var own: bool = collection.owns(id) or collection.owns_cosmetic(id)
		var row: HBoxContainer = UiUtil.hbox(10)
		row.add_child(SdIcons.icon(&"check" if own else (&"star" if id == nxt else &"lock"), SdStyle.OK if own
			else (SdStyle.GOLD if id == nxt else SdStyle.TEXT_DIM), 22))
		row.add_child(SdStyle.label("%s — %s" % [_reward_name(id), "erhalten" if own else ("als Nächstes" if id == nxt
			else "später")], 18, SdStyle.TEXT if own or id == nxt else SdStyle.TEXT_DIM))
		_content.add_child(row)


func _reward_name(id: String) -> String:
	if book.card(id) != null:
		return "Karte „%s“" % book.card(id).name
	var c: Dictionary = book.cosmetics.get(id, {})
	return "%s „%s“" % [str(SLOTS.get(str(c.get("kind", "")), "Kosmetik")), str(c.get("name", id))]


# --- Dienstauszeichnungen ---------------------------------------------------------------------------------------------

func _page_awards() -> void:
	_content.add_child(SdStyle.label("DIENSTAUSZEICHNUNGEN · %d von %d" % [collection.awards.size(),
		book.award_ids.size()], 22, SdStyle.GOLD, true))
	_content.add_child(SdStyle.label("Nur Ehre, keine Wirkung — getrennt von den Erfolgen der Kampagne.", 18,
		SdStyle.TEXT_DIM))
	for aid: String in book.award_ids:
		var a: Dictionary = book.awards[aid]
		var have: bool = collection.awards.has(aid)
		var row: HBoxContainer = UiUtil.hbox(12)
		row.name = "Award_" + aid
		var ic: Control = SdIcons.icon(&"trophy" if have else &"lock", SdStyle.GOLD if have else SdStyle.TEXT_DIM, 32)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(ic)
		var col: VBoxContainer = UiUtil.vbox(0)
		row.add_child(col)
		col.add_child(SdStyle.label("%s — %s" % [str(a.get("name", aid)), "verliehen" if have else "offen"], 20,
			SdStyle.TEXT if have else SdStyle.TEXT_DIM, true))
		col.add_child(SdStyle.label(str(a.get("desc", "")), 18, SdStyle.TEXT_DIM))
		_content.add_child(row)


# --- cosmetics ------------------------------------------------------------------------------------------------------

func _page_cosmetics() -> void:
	_content.add_child(SdStyle.label("KOSMETIK · nur Aussehen, nichts davon ist käuflich", 22, SdStyle.GOLD, true))
	for slot: String in SLOTS.keys():
		_content.add_child(SdStyle.label(str(SLOTS[slot]), 20, SdStyle.TEXT, true))
		var flow: HFlowContainer = HFlowContainer.new()
		flow.name = "Slot_" + slot
		flow.add_theme_constant_override("h_separation", SdScreen.GAP)
		flow.add_theme_constant_override("v_separation", SdScreen.GAP)
		_content.add_child(flow)
		var cur: String = str(collection.cosmetics.get(slot, ""))
		var std: Button = _cos_button("Standard", cur == "", "Cos_%s_std" % slot)
		std.pressed.connect(func() -> void:
			collection.unequip(slot)
			_cos_changed())
		flow.add_child(std)
		items.append(std)
		for kid: String in book.cosmetic_ids:
			var c: Dictionary = book.cosmetics[kid]
			if str(c.get("kind", "")) != slot:
				continue
			if collection.owns_cosmetic(kid):
				var b: Button = _cos_button(str(c.get("name", kid)), cur == kid, "Cos_" + kid)
				b.pressed.connect(func() -> void:
					collection.equip(kid, book)
					_cos_changed())
				flow.add_child(b)
				items.append(b)
			else:
				var lk: HBoxContainer = UiUtil.hbox(6)
				lk.name = "Locked_" + kid
				var ic: Control = SdIcons.icon(&"lock", SdStyle.TEXT_DIM, 20)
				ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				lk.add_child(ic)
				lk.add_child(SdStyle.label("%s: %s" % [str(c.get("name", kid)), str(c.get("desc", ""))], 18,
					SdStyle.TEXT_DIM))
				flow.add_child(lk)


func _cos_button(text: String, on: bool, name: String) -> Button:
	var b: Button = UiUtil.button(("%s · angelegt" % text) if on else text, &"ButtonFlat")
	b.name = name
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.toggle_mode = true
	b.set_pressed_no_signal(on)
	b.custom_minimum_size.x = 160
	UiUtil.touch_pad(b)
	return b


func _cos_changed() -> void:
	SdSession.save()
	var keep: String = ""
	var fo: Control = get_viewport().gui_get_focus_owner()
	if fo != null:
		keep = fo.name
	show_page("cosmetics")
	var again: Node = _content.find_child(keep, true, false)
	if again is Control:
		UiUtil.focus_later(again as Control)


# --- focus ------------------------------------------------------------------------------------------------------------

func _wire() -> void:
	var origins: Array[Control] = []
	var head: Array[Control] = []
	for k: String in PAGES.keys():
		if SdCardDef.ORIGINS.has(k):
			origins.append(tabs[k] as Control)
		else:
			head.append(tabs[k] as Control)
	head.append(back_button)
	UiUtil.wire_horizontal(origins)
	UiUtil.wire_horizontal(head, false)
	var first: Control = items[0] if not items.is_empty() else origins[0]
	for h: Control in head:
		h.focus_neighbor_bottom = h.get_path_to(origins[0])
	for o: Control in origins:
		o.focus_neighbor_top = o.get_path_to(head[0])
		o.focus_neighbor_bottom = o.get_path_to(first)
	var upper: Control = tabs[page] as Control if SdCardDef.ORIGINS.has(page) else origins[0]
	var grid: GridContainer = _content.get_node_or_null("Cards") as GridContainer
	if grid != null:
		var cols: int = maxi(1, grid.columns)
		var rows: Array[Array] = []
		for i in items.size():
			if i % cols == 0:
				rows.append([])
			(rows[rows.size() - 1] as Array).append(items[i])
		SdScreen.wire_grid(rows)
		if not rows.is_empty():
			for c: Variant in rows[0]:
				(c as Control).focus_neighbor_top = (c as Control).get_path_to(upper)
	elif not items.is_empty():
		var col: Array[Control] = []
		col.append_array(items)
		UiUtil.wire_vertical(col, false)
		items[0].focus_neighbor_top = items[0].get_path_to(upper)
	UiUtil.focus_later(tabs[page] as Control)


## Columns of the card grid for the current width (on resize as well).
func _update_columns() -> void:
	var grid: GridContainer = _content.get_node_or_null("Cards") as GridContainer if _content != null else null
	if grid == null:
		return
	var cs: Vector2 = SdStyle.card_size(touch)
	var cols: int = maxi(1, int(floor((_frame_width() - 14.0 + SdScreen.GAP) / (cs.x + 8.0 + SdScreen.GAP))))
	if cols != grid.columns:
		grid.columns = cols
		_wire()


func _frame_width() -> float:
	if _scroll != null and _scroll.size.x > 100.0:
		return _scroll.size.x
	if not is_inside_tree():
		return 1232.0
	var ins: Dictionary = SafeAreaContainer.device_insets(get_viewport())
	return get_viewport_rect().size.x - 2.0 * float(SafeAreaContainer.EDGE) - float(ins["left"]) - float(ins["right"])
