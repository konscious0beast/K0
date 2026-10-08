extends PanelContainer
## Battle command menu (02_TECH §1.6, GDD §3.5/§14.5): Angriff / Fähigkeit / Stunt (with cooldown number) / Item /
## Verteidigen / Flucht in BattleCommand.Kind order; unavailable commands are shown greyed (focusable and pressable:
## choose() answers with ui_error and `rejected`, the HUD flashes the reason). Keyboard/gamepad: vertical list 240 px
## wide, 42 px rows, active row = 3 px cyan frame + 4 px magenta bar (03_ART §9.1/§9.2), focus wraps; scheme TOUCH:
## 2 columns × 3 rows, 200×64 visible / 88 px hit area, 12 px between hit areas (02_TECH §10.2/§10.3). While a sub
## menu is open the menu stays visible but dimmed and inert (set_dimmed). Private M5 helper (no class_name).

signal chosen(kind: int)
signal highlighted(kind: int)
## An unavailable command was pressed (kind = BattleCommand.Kind).
signal rejected(kind: int)

const HudStyle := preload("res://scenes/battle/ui/hud_style.gd")
const ROW_H: float = 42.0
const WIDTH: float = 240.0
## Gap between the touch hit areas (02_TECH §10.2 rule 5).
const TOUCH_GAP: int = 12
const LABELS: PackedStringArray = ["Angriff", "Fähigkeit", "Stunt", "Item", "Verteidigen", "Flucht"]
const ICONS: PackedStringArray = ["cmd_attack", "cmd_skill", "cmd_stunt", "cmd_item", "cmd_defend", "cmd_flee"]
const ICON_COLORS: Array[Color] = [Color("#f2ebdd"), Color("#22d3ee"), Color("#ffc93c"), Color("#4ade80"),
	Color("#9aa7b8"), Color("#ff9a2e")]

var touch: bool = false
var buttons: Array[Button] = []       # index == BattleCommand.Kind
var enabled: Array[bool] = []
var dimmed: bool = false

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
	set_dimmed(false)
	focus_default()


## Dimmed (a sub menu / target selection is open): visible at 55 %, buttons neither take focus nor clicks.
func set_dimmed(on: bool) -> void:
	dimmed = on
	modulate = Color(1, 1, 1, 0.55) if on else Color.WHITE
	mouse_filter = Control.MOUSE_FILTER_IGNORE if on else Control.MOUSE_FILTER_STOP
	for b: Button in buttons:
		b.focus_mode = Control.FOCUS_NONE if on else Control.FOCUS_ALL
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE if on else Control.MOUSE_FILTER_STOP
		if on and b.has_focus():
			b.release_focus()


func close() -> void:
	visible = false
	for b: Button in buttons:
		if b.has_focus():
			b.release_focus()


func focus_default() -> void:
	for i in buttons.size():
		if enabled[i]:
			_grab.call_deferred(buttons[i])
			return
	if not buttons.is_empty():
		_grab.call_deferred(buttons[0])


func focus_kind(kind: int) -> void:
	if kind >= 0 and kind < buttons.size():
		_grab.call_deferred(buttons[kind])


## Deferred focus that skips buttons replaced in the meantime (re-open in the same frame) or a dimmed menu.
func _grab(b: Button) -> void:
	if is_instance_valid(b) and b.is_inside_tree() and not b.is_queued_for_deletion() and visible and not dimmed:
		b.grab_focus()


func focused_kind() -> int:
	for i in buttons.size():
		if buttons[i].has_focus():
			return i
	return -1


## Presses the row of `kind` (buttons, tests); an unavailable command answers with ui_error + `rejected`.
func choose(kind: int) -> void:
	if not visible or dimmed:
		return
	if kind >= 0 and kind < enabled.size() and enabled[kind]:
		Sfx.play_ui(&"ui_confirm")
		chosen.emit(kind)
	else:
		Sfx.play_ui(&"ui_error")
		rejected.emit(kind)


func _build(available: Array[int], stunt_cd: int, has_stunt: bool) -> void:
	if _list != null:
		_vbox.remove_child(_list)           # out of the tree at once: pending deferred focus grabs skip it
		_list.queue_free()
	buttons.clear()
	enabled.clear()
	if touch:
		var grid: GridContainer = GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", TOUCH_GAP)
		grid.add_theme_constant_override("v_separation", TOUCH_GAP)
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
		b.text = ""                       # never `disabled`: a greyed command is still pressable (→ rejected)
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
			HudStyle.style_row(b)
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
