extends CanvasLayer
## Talentbaum (09 §8.4, ST1-D; Pausemenü → Party → "Talentbaum"): the whole tree of one party member — the twelve rows
## (3, 5, 7, 9 · 15, 20 … 50) in level order, three cards each: the plaque and the kind of the row (Grund-, Klassen-,
## Figurenreihe), the column of every card (the branch of a class row, Angriff / Show / Schutz of a figure row), the
## pick that counts (gold frame, "GEWÄHLT"), open rows ("OFFEN"), rows still ahead ("ab Stufe X", dimmed). A card
## pressed in a safe room picks or re-picks for free (Game.pick_talent_row, the recorded "talent" v2); elsewhere the
## page says that re-picks belong to a safe room (09 §9.1). At the right: the focused card's sentence, its effect and
## the stats before -> after; next to the name the branch badge (TalentTree.spec_of: mostly left or mostly right).
## Keyboard / gamepad: arrows through the grid, ui_accept picks, tab_prev / tab_next switch the member, ui_cancel /
## pause closes. Touch / mouse: cards are buttons with 88 px hit areas in a scroll list, "Schließen" closes.
## Modal layer 61 (above the pause menu, 02_TECH §9.4), process mode ALWAYS (it opens from the paused menu and from a
## safe room); signal `closed`. setup({"member": id}).

signal closed()

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const UiIcon := preload("res://scenes/ui/ui_icon.gd")
const InputGlyph := preload("res://scenes/ui/input_glyph.gd")
const TalentText := preload("res://scenes/ui/talent_text.gd")
const LevelBadge := preload("res://scenes/ui/level_badge.gd")
const MenuBase := preload("res://scenes/ui/menu_base.gd")
const CARD_W: float = 238.0
const CARD_VIS_H: float = 80.0              # visible box; the hit area is UiTheme.TOUCH_HIT (88) high
const HEAD_W: float = 96.0                  # the row's plaque and kind
const DETAIL_W: float = 330.0
const ROW_KIND_SHORT: Dictionary = {"Grundreihe": "Grund", "Klassenreihe": "Klasse", "Figurenreihe": "Figur"}

var member_id: String = "kai"
var cards: Dictionary = {}                  # "row:col" → Button (col 1..3)

var _params: Dictionary = {}
var _closing: bool = false
var _root: Control
var _panel: PanelContainer
var _tabs: HBoxContainer
var _name: Label
var _info: Label
var _where: Label
var _list: VBoxContainer
var _scroll: ScrollContainer
var _d_title: Label
var _d_sub: Label
var _d_desc: Label
var _d_fx: Label
var _d_preview: Label
var _d_state: Label
var _status: Label
var close_button: Button


## {"member": party member id} (default: the first member).
func setup(params: Dictionary) -> void:
	_params = params
	member_id = str(params.get("member", member_id))


func _init() -> void:
	layer = 61
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	Game.ensure_state()
	if Game.state != null and Game.state.member(member_id) == null and not UiUtil.party().is_empty():
		member_id = UiUtil.party()[0].id
	_build()
	refresh()
	UiUtil.slide_in(_panel)


## Modal (like the candidate card): Esc / B / Start / pause close it before the pause menu sees them; tab_prev /
## tab_next switch the member here, never the pause menu's tab.
func _input(event: InputEvent) -> void:
	if _closing or not _root.is_visible_in_tree():
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		close()
	elif event.is_action(&"tab_next") or event.is_action(&"tab_prev"):
		get_viewport().set_input_as_handled()
		if not event.is_pressed() or event.is_echo():
			return
		var ids: Array = UiUtil.party().map(func(m: PartyMember) -> String: return m.id)
		if ids.size() > 1:
			var d: int = 1 if event.is_action(&"tab_next") else -1
			select_member(str(ids[posmod(ids.find(member_id) + d, ids.size())]))


func select_member(id: String) -> void:
	member_id = id
	refresh()


func close() -> void:
	if _closing:
		return
	_closing = true
	Sfx.play_ui(&"ui_cancel")
	closed.emit()
	queue_free()


## True while a pick or re-pick is possible here: a safe room (09 §9.1; the core refuses anywhere else).
static func can_pick() -> bool:
	return Game.state != null and RunRules.in_safe_room(Game.state) and Game.combat == null


## Rebuilds the page for member_id; the focus goes to `focus_key` ("row:col"), else the first open row, else the
## first pick, else the first card.
func refresh(focus_key: String = "") -> void:
	MenuBase.clear(_tabs)
	_tabs.add_child(MenuBase.member_tabs(member_id, select_member))
	MenuBase.clear(_list)
	cards.clear()
	var m: PartyMember = Game.state.member(member_id) if Game.state != null else null
	if m == null:
		_list.add_child(MenuBase.empty_note("Keine Party – noch kein Spielstand."))
		return
	_name.text = UiUtil.member_name(m)
	_info.text = _info_text(m)
	_where.text = "Umwählen: hier im Safe Room, jederzeit und kostenlos." if can_pick() else \
		"Nur ansehen – umwählen geht im Safe Room, kostenlos."
	_where.add_theme_color_override("font_color", UiTheme.C_GOLD if can_pick() else UiTheme.C_TEXT_DIM)
	var first_open: String = ""
	var first_pick: String = ""
	var grid: Array = []
	for row: int in TalentDef.tree_rows():
		var three: Array[TalentDef] = TalentTree.row_talents(DB.data, m, row)
		var line: HBoxContainer = UiUtil.hbox(10)
		line.name = "Row_%d" % row
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_list.add_child(line)
		line.add_child(_row_head(m, row))
		var buttons: Array[Control] = []
		if three.is_empty():
			var note: Label = UiUtil.label("Klassenreihe – nach dem Recall (Etage 3)", &"LabelSmall", 15,
				UiTheme.C_TEXT_DIM)
			note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			line.add_child(note)
		for t: TalentDef in three:
			var b: Button = _card(m, t)
			line.add_child(b)
			buttons.append(b)
			var key: String = "%d:%d" % [row, t.col]
			cards[key] = b
			if first_pick == "" and TalentTree.pick_of(DB.data, m, row) == t.id:
				first_pick = key
		if first_open == "" and not three.is_empty() and row <= m.level and TalentTree.pick_of(DB.data, m, row) == "":
			first_open = "%d:1" % row
		UiUtil.wire_horizontal(buttons, false)
		if not buttons.is_empty():
			grid.append(buttons)
	_wire_grid(grid)
	var key: String = focus_key if cards.has(focus_key) else (first_open if first_open != "" else first_pick)
	if not cards.has(key) and not grid.is_empty():
		key = "%d:1" % TalentTree.rows(DB.data, m)[0] if not TalentTree.rows(DB.data, m).is_empty() else ""
	if cards.has(key):
		UiUtil.focus_later(cards[key] as Control)
		_show(m, (cards[key] as Button).get_meta("talent_id", "") as String)
		_reveal(cards[key] as Control)


## Scrolls the list to `c` once the rows have their sizes (follow_focus alone scrolls before the first layout).
func _reveal(c: Control) -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(c) and is_instance_valid(_scroll):
		_scroll.ensure_control_visible(c)


## "Abrissbirne · Spezialisierung Bollwerk · 7 von 12 Reihen gewählt · 1 offen".
func _info_text(m: PartyMember) -> String:
	var parts: PackedStringArray = []
	if m.class_id != "" and DB.has_id("classes", m.class_id):
		parts.append(UiUtil.tr_text(DB.class_def(m.class_id).name))
	var spec: String = TalentTree.spec_of(DB.data, m)
	if spec != "":
		parts.append("Spezialisierung " + TalentText.spec_name(spec))
	var total: int = TalentTree.rows(DB.data, m).size()
	parts.append("%d von %d Reihen gewählt" % [TalentTree.picked(DB.data, m).size(), total])
	var open: int = TalentTree.open_rows(Game.state, DB.data, m).size()
	if open > 0:
		parts.append("%d offen" % open)
	return "  ·  ".join(parts)


## The head of a row: its plaque, its kind and — reached without a pick — the gold "OFFEN".
func _row_head(m: PartyMember, row: int) -> VBoxContainer:
	var v: VBoxContainer = UiUtil.vbox(2)
	v.custom_minimum_size = Vector2(HEAD_W, 0)
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var top: HBoxContainer = UiUtil.hbox(6)
	v.add_child(top)
	var reached: bool = row <= m.level
	top.add_child(LevelBadge.make(row, 16, UiTheme.C_GOLD if reached else UiUtil.C_DISABLED))
	var kind: String = str(ROW_KIND_SHORT.get(TalentText.row_kind(row), ""))
	top.add_child(UiUtil.label(kind, &"LabelSmall", 15, UiTheme.C_TEXT if reached else UiTheme.C_TEXT_DIM))
	if reached and TalentTree.pick_of(DB.data, m, row) == "" and not TalentTree.row_talents(DB.data, m, row).is_empty():
		var pill: PanelContainer = PanelContainer.new()
		pill.name = "Open"
		pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		var sb: StyleBoxFlat = UiUtil.box_style(UiTheme.C_GOLD, Color(0, 0, 0, 0), 0, 0.0, 8, 0)
		sb.set_corner_radius_all(10)
		pill.add_theme_stylebox_override("panel", sb)
		var l: Label = UiUtil.label("OFFEN", &"", 15, UiUtil.C_INK)
		l.add_theme_font_override("font", UiTheme.font_bold())
		l.add_theme_constant_override("outline_size", 0)
		pill.add_child(l)
		v.add_child(pill)
	return v


## A card: the column caption, the name, the effect; the pick that counts in gold, rows ahead dimmed.
func _card(m: PartyMember, t: TalentDef) -> Button:
	var picked: bool = TalentTree.pick_of(DB.data, m, t.row) == t.id
	var reached: bool = t.row <= m.level
	var b: Button = UiUtil.button("", &"ButtonFlat")
	b.name = "Card_%d_%d" % [t.row, t.col]
	b.set_meta("talent_id", t.id)
	b.custom_minimum_size = Vector2(CARD_W, CARD_VIS_H)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL    # wide screens (phones): the cards share the width
	var accent: Color = UiTheme.C_GOLD if picked else (TalentText.color_of(t) if reached else UiUtil.C_DISABLED)
	var normal: StyleBoxFlat = UiUtil.box_style(Color(UiUtil.C_INK, 0.72 if reached else 0.4), Color(accent,
		1.0 if picked else 0.45), 3 if picked else 2, 0.0, 12, 6)
	normal.set_corner_radius_all(8)
	var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.2, 0.12, 0.3, 0.95)
	var focus: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	focus.draw_center = false
	focus.border_color = UiTheme.C_ACCENT_2
	focus.set_border_width_all(4)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("focus", focus)
	UiUtil.touch_pad(b, CARD_VIS_H)
	var row: int = t.row
	var tid: String = t.id
	b.pressed.connect(func() -> void: choose(row, tid))
	b.focus_entered.connect(func() -> void: _show(Game.state.member(member_id), tid))
	var col: VBoxContainer = UiUtil.vbox(0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiUtil.full_rect(col)
	col.offset_left = 12
	col.offset_right = -10
	col.offset_top = 12
	col.offset_bottom = -12
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	b.add_child(col)
	var head: HBoxContainer = UiUtil.hbox(6)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	var caption: String = TalentText.col_caption(t)
	var cap: Label = UiUtil.label(caption.to_upper() if caption != "" else TalentText.kind_tag(t), &"", 15,
		Color(accent, 0.9))
	cap.name = "Caption"
	cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cap.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	cap.clip_text = true
	head.add_child(cap)
	var state_text: String = "GEWÄHLT" if picked else ("" if reached else "ab Stufe %d" % t.row)
	if state_text != "":
		var st: Label = UiUtil.label(state_text, &"", 15, UiTheme.C_GOLD if picked else UiTheme.C_TEXT_DIM)
		st.name = "State"
		st.add_theme_font_override("font", UiTheme.font_bold())
		head.add_child(st)
	var n: Label = UiUtil.label(UiUtil.glyph_safe(UiUtil.tr_text(t.name)), &"", 18,
		UiTheme.C_TEXT if reached else UiTheme.C_TEXT_DIM)
	n.name = "Name"
	n.add_theme_font_override("font", UiTheme.font_bold())
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	n.clip_text = true
	col.add_child(n)
	var fx: Label = UiUtil.label(UiUtil.glyph_safe(TalentText.effects_line(t, m.id)), &"", 15,
		accent if reached else UiTheme.C_TEXT_DIM)
	fx.name = "Effect"
	fx.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	fx.clip_text = true
	col.add_child(fx)
	return b


## A card pressed: a pick or a free re-pick in a safe room (Game.pick_talent_row); else why not.
func choose(row: int, talent_id: String) -> bool:
	var m: PartyMember = Game.state.member(member_id) if Game.state != null else null
	if m == null or _closing:
		return false
	if row > m.level:
		_say("Diese Reihe öffnet auf Stufe %d." % row, UiTheme.C_TEXT_DIM)
		Sfx.play_ui(&"ui_error")
		return false
	var before: String = TalentTree.pick_of(DB.data, m, row)
	if before == talent_id:
		_say("Schon gewählt.", UiTheme.C_TEXT_DIM)
		return false
	if not can_pick():
		_say("Umwählen geht im Safe Room – dort jederzeit und kostenlos.", UiTheme.C_GOLD)
		Sfx.play_ui(&"ui_error")
		return false
	if not Game.pick_talent_row(member_id, row, talent_id):
		_say("Das geht gerade nicht.", UiTheme.C_DANGER)
		Sfx.play_ui(&"ui_error")
		return false
	Sfx.play(&"achievement")
	Show.say("season_tree_repick" if before != "" else "season_tree_pick:" + member_id)
	var t: TalentDef = DB.talent(talent_id)
	_say("%s: %s gewählt%s." % [UiUtil.member_name(m), UiUtil.tr_text(t.name), " (umgewählt)" if before != "" else ""],
		UiTheme.C_OK)
	refresh("%d:%d" % [row, t.col])
	return true


## The detail column: name, row and column, the sentence, the effect, the stats before -> after and the state.
func _show(m: PartyMember, talent_id: String) -> void:
	if m == null or not DB.has_id("talents", talent_id):
		return
	var t: TalentDef = DB.talent(talent_id)
	_d_title.text = UiUtil.glyph_safe(UiUtil.tr_text(t.name))
	var sub: PackedStringArray = ["%s · Stufe %d" % [TalentText.row_kind(t.row), t.row]]
	var caption: String = TalentText.col_caption(t)
	if caption != "":
		sub.append(caption)
	_d_sub.text = UiUtil.glyph_safe("  ·  ".join(sub))
	_d_desc.text = UiUtil.glyph_safe(UiUtil.tr_text(t.desc))
	_d_fx.text = UiUtil.glyph_safe(TalentText.effects_line(t, m.id))
	_d_fx.add_theme_color_override("font_color", TalentText.color_of(t))
	var pv: String = preview(m, t)
	_d_preview.text = UiUtil.glyph_safe(pv)
	_d_preview.visible = pv != ""
	var picked: bool = TalentTree.pick_of(DB.data, m, t.row) == t.id
	var state: String = "Gewählt – wirkt jetzt."
	if not picked:
		if t.row > m.level:
			state = "Öffnet auf Stufe %d." % t.row
		elif can_pick():
			state = "Drücken: wählen (kostenlos)." if TalentTree.pick_of(DB.data, m, t.row) == "" else \
				"Drücken: umwählen (kostenlos)."
		else:
			state = "Wählbar im Safe Room."
	_d_state.text = state


## "Jetzt: Stärke 30 -> 32" — the member's numbers with this talent in its row (value talents; else "").
static func preview(m: PartyMember, t: TalentDef) -> String:
	if m == null or t == null:
		return ""
	var probe: PartyMember = PartyMember.from_dict(m.to_dict())
	var cur: PartyMember = PartyMember.from_dict(m.to_dict())
	probe.talent_rows[str(t.row)] = t.id
	var before: Dictionary = UiUtil.member_stats(cur)
	var after: Dictionary = UiUtil.member_stats(probe)
	var parts: PackedStringArray = []
	for k: String in UiUtil.STAT_KEYS:
		if int(after.get(k, 0)) != int(before.get(k, 0)):
			parts.append("%s %d -> %d" % [str(UiUtil.STAT_NAMES[k]), int(before.get(k, 0)), int(after.get(k, 0))])
	return ("Mit diesem Talent: " + ", ".join(parts)) if not parts.is_empty() else ""


func _say(text: String, col: Color) -> void:
	_status.text = UiUtil.glyph_safe(text)
	_status.add_theme_color_override("font_color", col)


## Modal focus (the pause menu behind keeps its own): between the rows the same column one row up / down, the first
## row up to "Schließen", the tabs and "Schließen" down to the first card; Tab / Shift+Tab in reading order, wrapping.
func _wire_grid(grid: Array) -> void:
	var order: Array[Control] = []
	var tabs: Array[Control] = []
	for c: Node in _tabs.find_children("Tab_*", "Button", true, false):
		tabs.append(c as Control)
	order.append_array(tabs)
	order.append(close_button)
	var first: Control = (grid[0] as Array)[0] as Control if not grid.is_empty() else close_button
	for t: Control in tabs:
		t.focus_neighbor_top = t.get_path_to(t)
		t.focus_neighbor_bottom = t.get_path_to(first)
	close_button.focus_neighbor_left = close_button.get_path_to(tabs.back() if not tabs.is_empty() else close_button)
	close_button.focus_neighbor_right = close_button.get_path_to(close_button)
	close_button.focus_neighbor_top = close_button.get_path_to(close_button)
	close_button.focus_neighbor_bottom = close_button.get_path_to(first)
	if not tabs.is_empty():
		(tabs.back() as Control).focus_neighbor_right = (tabs.back() as Control).get_path_to(close_button)
		(tabs.front() as Control).focus_neighbor_left = (tabs.front() as Control).get_path_to(tabs.front() as Control)
	for r in grid.size():
		var line: Array = grid[r]
		for c in line.size():
			var b: Control = line[c]
			order.append(b)
			var up: Array = grid[r - 1] if r > 0 else []
			var down: Array = grid[r + 1] if r < grid.size() - 1 else []
			b.focus_neighbor_top = b.get_path_to(up[mini(c, up.size() - 1)] as Control) if not up.is_empty() \
				else b.get_path_to(close_button)
			b.focus_neighbor_bottom = b.get_path_to(down[mini(c, down.size() - 1)] as Control) if not down.is_empty() \
				else b.get_path_to(b)
	for k in order.size():
		order[k].focus_previous = order[k].get_path_to(order[(k + order.size() - 1) % order.size()])
		order[k].focus_next = order[k].get_path_to(order[(k + 1) % order.size()])


func _build() -> void:
	_root = Control.new()
	UiUtil.full_rect(_root)
	UiUtil.apply_theme(_root)
	add_child(_root)
	var dim: ColorRect = ColorRect.new()
	UiUtil.full_rect(dim)
	dim.color = Color(0.03, 0.02, 0.06, 0.78)
	_root.add_child(dim)
	var safe: SafeAreaContainer = SafeAreaContainer.new()
	safe.extra = 8
	safe.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(safe)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiUtil.box_style(Color(UiTheme.C_PANEL, 1.0),
		Color(UiTheme.C_GOLD, 0.8), 3, 0.0, 22, 14))
	safe.add_child(_panel)
	var col: VBoxContainer = UiUtil.vbox(10)
	_panel.add_child(col)
	# header: pill + rule, member tabs, close
	var head: HBoxContainer = UiUtil.hbox(14)
	col.add_child(head)
	head.add_child(UiIcon.make(&"star", UiTheme.C_GOLD, 36))
	var hc: VBoxContainer = UiUtil.vbox(-2)
	hc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hc)
	var pill: PanelContainer = PanelContainer.new()
	pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	pill.add_theme_stylebox_override("panel", UiUtil.box_style(UiTheme.C_GOLD, Color(0, 0, 0, 0), 0, 0.21, 14, 0))
	hc.add_child(pill)
	var pl: Label = UiUtil.label("TALENTBAUM", &"LabelHeader", 26, UiUtil.C_INK)
	pl.add_theme_constant_override("outline_size", 0)
	pill.add_child(pl)
	var rule: Label = UiUtil.label("Pro Reihe eins von drei. Umwählen im Safe Room, kostenlos.", &"LabelSmall", 15)
	rule.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	rule.clip_text = true
	hc.add_child(rule)
	_tabs = UiUtil.hbox(0)
	_tabs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_tabs)
	close_button = UiUtil.close_button("Schließen")
	close_button.pressed.connect(close)
	head.add_child(close_button)
	# who: name, class · branch · picks, where re-picks work
	var who: HBoxContainer = UiUtil.hbox(14)
	col.add_child(who)
	_name = UiUtil.label("", &"", 24)
	_name.add_theme_font_override("font", UiTheme.font_bold())
	who.add_child(_name)
	_info = UiUtil.label("", &"LabelSmall", 16)
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_info.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_info.clip_text = true
	who.add_child(_info)
	_where = UiUtil.label("", &"", 16, UiTheme.C_GOLD)
	_where.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	who.add_child(_where)
	# body: the rows (scroll) and the detail column
	var body: HBoxContainer = UiUtil.hbox(16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	_scroll = ScrollContainer.new()
	_scroll.follow_focus = true
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_scroll)
	_list = UiUtil.vbox(4)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	var detail: PanelContainer = PanelContainer.new()
	detail.custom_minimum_size = Vector2(DETAIL_W, 0)
	detail.add_theme_stylebox_override("panel", UiUtil.box_style(Color(UiUtil.C_INK, 0.55), Color(UiTheme.C_ACCENT_2,
		0.35), 1, 0.0, 16, 12))
	body.add_child(detail)
	var dc: VBoxContainer = UiUtil.vbox(8)
	detail.add_child(dc)
	_d_title = UiUtil.label("", &"LabelHeader", 24)
	_d_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dc.add_child(_d_title)
	_d_sub = UiUtil.label("", &"LabelSmall", 15)
	_d_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dc.add_child(_d_sub)
	_d_desc = UiUtil.label("", &"", 18)
	_d_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dc.add_child(_d_desc)
	_d_fx = UiUtil.label("", &"", 20)
	_d_fx.add_theme_font_override("font", UiTheme.font_bold())
	_d_fx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dc.add_child(_d_fx)
	_d_preview = UiUtil.label("", &"", 16, UiTheme.C_TEXT)
	_d_preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dc.add_child(_d_preview)
	dc.add_child(UiUtil.spacer(0, 0, true))
	_d_state = UiUtil.label("", &"", 17, UiTheme.C_GOLD)
	_d_state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dc.add_child(_d_state)
	# footer: feedback + input hints
	var foot: HBoxContainer = UiUtil.hbox(18)
	col.add_child(foot)
	_status = UiUtil.label("", &"", 17, UiTheme.C_OK)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(_status)
	foot.add_child(InputGlyph.make(&"ui_accept", "Wählen", 15))
	foot.add_child(InputGlyph.make(&"tab_next", "Figur", 15))
	foot.add_child(InputGlyph.make(&"ui_cancel", "Schließen", 15))
