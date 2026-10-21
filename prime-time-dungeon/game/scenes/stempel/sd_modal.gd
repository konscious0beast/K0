extends CanvasLayer
## A modal panel of the Stempelduell screens (layer 60, 03_ART §9.2: opaque panel over a dimmed screen): a title row
## with a visible close button (the touch way out, 02_TECH §10.3), a content column the caller fills, ui_cancel /
## pause / B close it (when `closable`), the first focusable control gets the focus, the previous focus owner gets it
## back on close. Used for the menu, the rules, the Akte, the big view, the results and the lesson cards.

signal closed()

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const SdStyle := preload("res://scenes/stempel/sd_style.gd")

var content: VBoxContainer
var panel: PanelContainer
var title_label: Label
var close_button: Button
var closable: bool = true
var is_closed: bool = false

var _restore: Control = null
var _dim: ColorRect
var _bottom: float = -1.0                           # place_above(): the panel's bottom edge (canvas y), -1 = centred
var _center: CenterContainer


## `title` ("" = no title row), `width` px (0 = content width), `frame` colour (gold for results / lessons), `dim`.
func setup(title: String, width: float = 0.0, frame: Color = UiTheme.C_ACCENT_2, dim: float = 0.6,
		with_close: bool = true) -> void:
	layer = 60
	var root: Control = Control.new()
	root.name = "Root"
	UiUtil.full_rect(root)
	UiUtil.apply_theme(root)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_dim = ColorRect.new()
	_dim.name = "Dim"
	_dim.color = Color(0.05, 0.02, 0.08, dim)
	UiUtil.full_rect(_dim)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.gui_input.connect(_on_dim_input)
	root.add_child(_dim)
	var safe: SafeAreaContainer = SafeAreaContainer.new()
	root.add_child(safe)
	var center: CenterContainer = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(center)
	_center = center
	panel = PanelContainer.new()
	panel.name = "Panel"
	var sb: StyleBoxFlat = SdStyle.panel_box(Color(UiTheme.C_PANEL, 1.0), frame, 3, 18.0)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 6
	panel.add_theme_stylebox_override("panel", sb)
	if width > 0.0:
		panel.custom_minimum_size = Vector2(width, 0)
	center.add_child(panel)
	var col: VBoxContainer = UiUtil.vbox(12)
	panel.add_child(col)
	if title != "" or with_close:
		var head: HBoxContainer = UiUtil.hbox(12)
		col.add_child(head)
		title_label = UiUtil.label(title, &"LabelHeader", 28, frame)
		title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(title_label)
		if with_close:
			close_button = UiUtil.close_button()
			close_button.pressed.connect(close)
			head.add_child(close_button)
	content = UiUtil.vbox(12)
	content.name = "Content"
	col.add_child(content)


## The panel centred horizontally with its bottom edge at canvas y `bottom` (the Lernduell's cards sit above the hand,
## so the highlighted card and the Wartenummern-Anzeige stay in view); clamped to the safe frame.
func place_above(bottom: float) -> void:
	_bottom = bottom
	if _center != null and not _center.sort_children.is_connected(_place):
		_center.sort_children.connect(_place)            # after every centring of the container
	_place.call_deferred()


func _place() -> void:
	if _bottom < 0.0 or panel == null or _center == null:
		return
	var ps: Vector2 = panel.get_combined_minimum_size()
	var origin: Vector2 = _center.get_global_rect().position
	var y: float = clampf(_bottom - ps.y - origin.y, 0.0, maxf(0.0, _center.size.y - ps.y))
	panel.position = Vector2((_center.size.x - ps.x) * 0.5, y)


func _ready() -> void:
	var vp: Viewport = get_viewport()
	_restore = vp.gui_get_focus_owner() if vp != null else null
	UiUtil.slide_in(panel)
	focus_first()


func focus_first() -> void:
	var c: Control = _first_focusable(content)
	if c == null and close_button != null:
		c = close_button
	if c != null:
		UiUtil.focus_later(c)


func _unhandled_input(event: InputEvent) -> void:
	if is_closed:
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		if closable:
			Sfx.play_ui(&"ui_cancel")
			close()


func _on_dim_input(e: InputEvent) -> void:
	if closable and e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
		close()


func close() -> void:
	if is_closed:
		return
	is_closed = true
	closed.emit()
	if _restore != null and is_instance_valid(_restore) and _restore.is_inside_tree():
		UiUtil.focus_later(_restore)
	queue_free()


static func _first_focusable(root: Node) -> Control:
	for c: Node in root.get_children():
		var ctl: Control = c as Control
		if ctl != null and ctl.is_visible_in_tree() and ctl.focus_mode == Control.FOCUS_ALL \
				and not (ctl is BaseButton and (ctl as BaseButton).disabled):
			return ctl
		var deeper: Control = _first_focusable(c)
		if deeper != null:
			return deeper
	return null
