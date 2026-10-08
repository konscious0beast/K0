extends PanelContainer
## Battle command menu (02_TECH §1.6, GDD §3.5/§14.5): Angriff / Fähigkeit / Stunt (with cooldown number) / Item /
## Verteidigen / Flucht in BattleCommand.Kind order; unavailable commands are shown greyed (focusable, not
## selectable). Keyboard/gamepad: vertical list 240 px wide, 42 px rows, focus wraps; scheme TOUCH: 2 columns × 3
## rows, 200×64 visible / 88 px hit area (02_TECH §10.3). Private M5 helper (no class_name).

signal chosen(kind: int)
signal highlighted(kind: int)

const HudStyle := preload("res://scenes/battle/ui/hud_style.gd")
const ROW_H: float = 42.0
const WIDTH: float = 240.0
const LABELS: PackedStringArray = ["Angriff", "Fähigkeit", "Stunt", "Item", "Verteidigen", "Flucht"]
const ICONS: PackedStringArray = ["cmd_attack", "cmd_skill", "cmd_stunt", "cmd_item", "cmd_defend", "cmd_flee"]
const ICON_COLORS: Array[Color] = [Color("#f2ebdd"), Color("#22d3ee"), Color("#ffc93c"), Color("#4ade80"),
	Color("#9aa7b8"), Color("#ff9a2e")]

var touch: bool = false
var buttons: Array[Button] = []       # index == BattleCommand.Kind
var enabled: Array[bool] = []

var _title: Label = null
var _list: Container = null
var _vbox: VBoxContainer = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", HudStyle.show_box(HudStyle.C_PANEL, Color(Color("#22d3ee"), 0.6), 2, 0.0,
		Vector4(10, 8, 10, 10)))
	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 4)
	_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vbox)
	_title = HudStyle.label("", 18, Color("#ffc93c"), true, 3)
	_vbox.add_child(_title)
	visible = false


## Opens the menu for `actor_name`. available: BattleCommand.Kind values allowed by BattleState; stunt_cd: cooldown
## shown on the Stunt row; has_stunt false hides the number.
func open(actor_name: String, accent: Color, available: Array[int], stunt_cd: int, has_stunt: bool,
		p_touch: bool) -> void:
	touch = p_touch
	_title.text = actor_name.to_upper()
	_title.add_theme_color_override("font_color", accent)
	_build(available, stunt_cd, has_stunt)
	visible = true
	focus_default()


func close() -> void:
	visible = false
	for b: Button in buttons:
		if b.has_focus():
			b.release_focus()


func focus_default() -> void:
	for i in buttons.size():
		if enabled[i]:
			buttons[i].grab_focus.call_deferred()
			return
	if not buttons.is_empty():
		buttons[0].grab_focus.call_deferred()


func focus_kind(kind: int) -> void:
	if kind >= 0 and kind < buttons.size():
		buttons[kind].grab_focus.call_deferred()


func focused_kind() -> int:
	for i in buttons.size():
		if buttons[i].has_focus():
			return i
	return -1


## Presses the row of `kind` (tests, touch shortcuts); ignored when disabled.
func choose(kind: int) -> void:
	if kind >= 0 and kind < enabled.size() and enabled[kind] and visible:
		Sfx.play_ui(&"ui_confirm")
		chosen.emit(kind)
	elif visible:
		Sfx.play_ui(&"ui_error")


func _build(available: Array[int], stunt_cd: int, has_stunt: bool) -> void:
	if _list != null:
		_list.queue_free()
	buttons.clear()
	enabled.clear()
	if touch:
		var grid: GridContainer = GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 0)
		_list = grid
	else:
		var v: VBoxContainer = VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		_list = v
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vbox.add_child(_list)
	for kind in LABELS.size():
		var ok: bool = available.has(kind)
		var b: Button = Button.new()
		b.name = "Cmd_" + BattleCommand.KIND_NAMES[kind]
		b.focus_mode = Control.FOCUS_ALL
		b.disabled = not ok
		b.text = ""
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 12
		row.offset_right = -10
		var dim: Color = Color("#6a6278")
		var ic: HudStyle.Icon = HudStyle.Icon.new(ICONS[kind], ICON_COLORS[kind] if ok else dim, 20)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(ic)
		var l: Label = HudStyle.label(LABELS[kind], 21 if not touch else 22, HudStyle.C_PAPER if ok else dim,
			kind == 0, 2)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(l)
		if kind == BattleCommand.Kind.STUNT and has_stunt and stunt_cd > 0:
			var cd: Label = HudStyle.mono_label(str(stunt_cd), 18, Color("#ffc93c"))
			cd.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(cd)
			var clock: HudStyle.Icon = HudStyle.Icon.new("rank_1", Color("#ffc93c"), 14)
			clock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(clock)
		if touch:
			b.custom_minimum_size = Vector2(200, 64)
			b.add_child(row)
			UiTheme.ensure_hit_area(b)
		else:
			b.theme_type_variation = &"ButtonFlat"
			b.custom_minimum_size = Vector2(WIDTH - 20.0, ROW_H)
			b.add_child(row)
		b.pressed.connect(choose.bind(kind))
		b.focus_entered.connect(_on_focus.bind(kind))
		_list.add_child(b)
		buttons.append(b)
		enabled.append(ok)
	_wire_focus()


func _wire_focus() -> void:
	var n: int = buttons.size()
	for i in n:
		var b: Button = buttons[i]
		if touch:
			var side: int = clampi(i ^ 1, 0, n - 1)
			b.focus_neighbor_top = b.get_path_to(buttons[(i - 2 + n) % n])
			b.focus_neighbor_bottom = b.get_path_to(buttons[(i + 2) % n])
			b.focus_neighbor_left = b.get_path_to(buttons[side])
			b.focus_neighbor_right = b.get_path_to(buttons[side])
		else:
			b.focus_neighbor_top = b.get_path_to(buttons[(i - 1 + n) % n])
			b.focus_neighbor_bottom = b.get_path_to(buttons[(i + 1) % n])
			b.focus_neighbor_left = b.get_path_to(b)
			b.focus_neighbor_right = b.get_path_to(b)
		b.focus_previous = b.get_path_to(buttons[(i - 1 + n) % n])
		b.focus_next = b.get_path_to(buttons[(i + 1) % n])


func _on_focus(kind: int) -> void:
	Sfx.play_ui(&"ui_move")
	highlighted.emit(kind)
