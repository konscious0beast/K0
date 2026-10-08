extends PanelContainer
## Sub menu of the battle commands (02_TECH §1.6, GDD §14.5): skills / stunts / items with name, MP cost (or count),
## element icon, rank as 1–3 clock symbols and the description of the highlighted entry at the bottom. Entries that
## cannot be used (MP, KO targets missing) stay focusable but greyed. Focus wraps; scheme TOUCH uses 88 px rows.
## Private M5 helper (no class_name).

signal chosen(id: String)
signal highlighted(id: String)

const HudStyle := preload("res://scenes/battle/ui/hud_style.gd")
const WIDTH: float = 388.0
const ROW_H: float = 40.0
const ROW_H_TOUCH: float = 88.0
const MAX_ROWS: int = 6
const MAX_ROWS_TOUCH: int = 3

var entries: Array[Dictionary] = []
var buttons: Array[Button] = []
var touch: bool = false

var _title: Label = null
var _scroll: ScrollContainer = null
var _rows: VBoxContainer = null
var _desc: Label = null
var _vbox: VBoxContainer = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", HudStyle.show_box(HudStyle.C_PANEL, Color(Color("#ff2e88"), 0.75), 2, 0.0,
		Vector4(10, 8, 10, 10)))
	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 6)
	_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vbox)
	_title = HudStyle.label("", 18, Color("#ff2e88"), true, 3)
	_vbox.add_child(_title)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_vbox.add_child(_scroll)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 0)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll.add_child(_rows)
	var sep: ColorRect = ColorRect.new()
	sep.color = Color(1, 1, 1, 0.12)
	sep.custom_minimum_size = Vector2(0, 1)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vbox.add_child(sep)
	_desc = HudStyle.label("", 16, Color("#d9d0ea"), false, 2)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size = Vector2(WIDTH - 24.0, 44)
	_vbox.add_child(_desc)
	visible = false


## entries: [{"id", "label", "enabled", "cost" (String, e.g. "4 MP" / "×3"), "element", "rank", "desc", "icon"}].
func open(title: String, p_entries: Array[Dictionary], p_touch: bool, focus_id: String = "") -> void:
	touch = p_touch
	entries = p_entries.duplicate()
	_title.text = title.to_upper()
	for c: Node in _rows.get_children():
		_rows.remove_child(c)
		c.queue_free()
	buttons.clear()
	var row_h: float = ROW_H_TOUCH if touch else ROW_H
	for i in entries.size():
		var e: Dictionary = entries[i]
		var b: Button = _make_row(e, row_h)
		_rows.add_child(b)
		buttons.append(b)
		b.pressed.connect(choose.bind(i))
		b.focus_entered.connect(_on_focus.bind(i))
	var shown: int = mini(entries.size(), MAX_ROWS_TOUCH if touch else MAX_ROWS)
	_scroll.custom_minimum_size = Vector2(WIDTH - 20.0, row_h * float(maxi(1, shown)))
	custom_minimum_size = Vector2(WIDTH, 0)
	_wire_focus()
	visible = true
	if entries.is_empty():
		_desc.text = tr("Nichts verfügbar.")
		return
	var idx: int = 0
	for i in entries.size():
		if str(entries[i].get("id", "")) == focus_id:
			idx = i
			break
		if focus_id == "" and bool(entries[i].get("enabled", true)):
			idx = i
			break
	buttons[idx].grab_focus.call_deferred()
	_show_desc(idx)


func close() -> void:
	visible = false
	for b: Button in buttons:
		if b.has_focus():
			b.release_focus()


func focused_id() -> String:
	for i in buttons.size():
		if buttons[i].has_focus():
			return str(entries[i].get("id", ""))
	return ""


func choose(i: int) -> void:
	if i < 0 or i >= entries.size() or not visible:
		return
	if not bool(entries[i].get("enabled", true)):
		Sfx.play_ui(&"ui_error")
		return
	Sfx.play_ui(&"ui_confirm")
	chosen.emit(str(entries[i].get("id", "")))


func choose_id(id: String) -> void:
	for i in entries.size():
		if str(entries[i].get("id", "")) == id:
			choose(i)
			return


func _make_row(e: Dictionary, row_h: float) -> Button:
	var ok: bool = bool(e.get("enabled", true))
	var b: Button = Button.new()
	b.name = "Row_" + str(e.get("id", ""))
	b.theme_type_variation = &"ButtonFlat"
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(WIDTH - 24.0, row_h)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10
	row.offset_right = -8
	var dim: Color = Color("#6a6278")
	var icon_kind: String = str(e.get("icon", ""))
	if icon_kind == "":
		icon_kind = "element_" + str(e.get("element", "none"))
	var ic_col: Color = HudStyle.element_color(str(e.get("element", "none")))
	if e.has("icon_color"):
		ic_col = e["icon_color"] as Color
	var ic: HudStyle.Icon = HudStyle.Icon.new(icon_kind, ic_col if ok else dim, 18)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	var l: Label = HudStyle.label(str(e.get("label", "")), 19, HudStyle.C_PAPER if ok else dim, false, 2)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(l)
	var rank: int = int(e.get("rank", 0))
	if rank > 0:
		var clocks: int = 1 if rank <= 2 else (2 if rank == 3 else 3)
		var rc: HudStyle.Icon = HudStyle.Icon.new("rank_%d" % clocks, Color("#b3a7c9") if ok else dim, 11)
		rc.custom_minimum_size = Vector2(34, 11)
		rc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(rc)
	var cost: String = str(e.get("cost", ""))
	if cost != "":
		var cl: Label = HudStyle.mono_label(cost, 17, Color("#bcd6ff") if ok else Color("#ff8080"))
		cl.custom_minimum_size = Vector2(62, 0)
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(cl)
	b.add_child(row)
	return b


func _wire_focus() -> void:
	var n: int = buttons.size()
	for i in n:
		var b: Button = buttons[i]
		b.focus_neighbor_top = b.get_path_to(buttons[(i - 1 + n) % n])
		b.focus_neighbor_bottom = b.get_path_to(buttons[(i + 1) % n])
		b.focus_neighbor_left = b.get_path_to(b)
		b.focus_neighbor_right = b.get_path_to(b)
		b.focus_previous = b.get_path_to(buttons[(i - 1 + n) % n])
		b.focus_next = b.get_path_to(buttons[(i + 1) % n])


func _on_focus(i: int) -> void:
	Sfx.play_ui(&"ui_move")
	_show_desc(i)
	highlighted.emit(str(entries[i].get("id", "")))


func _show_desc(i: int) -> void:
	if i < 0 or i >= entries.size():
		_desc.text = ""
		return
	_desc.text = str(entries[i].get("desc", ""))
