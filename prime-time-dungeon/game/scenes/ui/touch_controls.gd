extends CanvasLayer
## Touch layer (02_TECH §10.3, §9.4 layer 20; 03_ART §9.4): floating joystick in the left 40 %, one round `action`
## button (96 px at (1147, 587); hand icon with a prompt, fist otherwise), `map` (64 px at (1227, 140)) and `pause`
## (64 px at (1227, 40)); every hit area ≥ 88 px (UiTheme.ensure_hit_area). Buttons send InputEventAction press/release.
## Drag on the free right side → Events.camera_drag(relative). Visible when settings.touch_controls == &"on" or
## (&"auto" and a touchscreen is available and Game.input_scheme == TOUCH).
## Safe area (§10.4): button offsets and the joystick zone shift by the display cutout insets (recomputed on resize).
## Pause (§9.4): this layer is PAUSABLE and gets no touch_up/drag while PauseMenu/BigMap pause the tree, so on
## NOTIFICATION_PAUSED it releases the joystick (move_*/sneak) and every held button action.
## While shown, `active` points at this instance: ExplorationHud and ShowOverlay move the minimap / hype meter out of
## the pause/map hit areas (top right).

signal shown_changed(shown: bool)

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const UiIcon := preload("res://scenes/ui/ui_icon.gd")
const Joystick := preload("res://scenes/ui/virtual_joystick.gd")
const REF: Vector2 = Vector2(1280, 720)
const BUTTONS: Array[Dictionary] = [
	{"name": "Action", "action": &"action", "center": Vector2(1147, 587), "size": 96.0, "icon": &"fist"},
	{"name": "Map", "action": &"map", "center": Vector2(1227, 140), "size": 64.0, "icon": &"map"},
	{"name": "Pause", "action": &"pause", "center": Vector2(1227, 40), "size": 64.0, "icon": &"menu"},
]

## Shown touch layer (M6-internal; null while none is visible).
static var active: Node = null

## Horizontal gap between the pause/map HIT areas and a HUD element moved left of them (the visible 64 px discs sit
## another 12 px further right).
const HUD_GAP: float = 27.0
## right_clearance() of the 1280×720 reference layout without display insets: the pause/map hit areas (88 px around
## x = 1227) start at x = 1183; the frame edge is at 1280 − 24 = 1256 → 1256 − 1183 + HUD_GAP.
const RIGHT_CLEARANCE: float = 100.0

var force_visible: bool = false             # captures / tests
var joystick: Control
var buttons: Dictionary = {}                # action → Button

var _root: Control
var _drag_index: int = -1
var _prompt: bool = false
var _params: Dictionary = {}
var _held: Dictionary = {}                  # action → true while its button is held
var _insets: Dictionary = {"left": 0, "top": 0, "right": 0, "bottom": 0}


## Optional: {"capture": true} → always visible (stills of the touch layout on desktop).
func setup(params: Dictionary) -> void:
	_params = params
	force_visible = bool(params.get("capture", false)) or bool(params.get("force_visible", false))


func _init() -> void:
	layer = 20


func _ready() -> void:
	_root = Control.new()
	_root.name = "Root"
	UiUtil.full_rect(_root)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiUtil.apply_theme(_root)
	add_child(_root)
	joystick = Joystick.new()
	joystick.name = "Joystick"
	joystick.anchor_left = 0.0
	joystick.anchor_right = 0.4
	joystick.anchor_top = 0.0
	joystick.anchor_bottom = 1.0
	_root.add_child(joystick)
	for spec: Dictionary in BUTTONS:
		_make_button(spec)
	Events.input_scheme_changed.connect(func(_s: int) -> void: refresh_visibility())
	Events.settings_changed.connect(refresh_visibility)
	get_viewport().size_changed.connect(_apply_insets)
	_apply_insets()
	refresh_visibility()
	if bool(_params.get("capture", false)):
		set_prompt_active(true)


func _exit_tree() -> void:
	release_all()
	if active == self:
		active = null


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		release_all()


## Lets go of everything this layer holds: joystick (move_*/sneak), camera drag, held button actions.
func release_all() -> void:
	if joystick != null and bool(joystick.get("active")):
		joystick.call("release")
	_drag_index = -1
	for a: Variant in _held.keys():
		UiUtil.tap_action(a as StringName, false)
	_held.clear()


## Visibility rule of 02_TECH §10.3.
static func should_show() -> bool:
	if Game.settings == null:
		return false
	var mode: StringName = Game.settings.touch_controls
	if mode == &"on":
		return true
	if mode == &"off":
		return false
	return DisplayServer.is_touchscreen_available() and Game.input_scheme == Game.InputScheme.TOUCH


func refresh_visibility() -> void:
	var v: bool = force_visible or should_show()
	var was: bool = is_shown()
	if _root != null:
		_root.visible = v
	if not v:
		release_all()
	if v:
		active = self
	elif active == self:
		active = null
	if v != was:
		shown_changed.emit(v)


func is_shown() -> bool:
	return _root != null and _root.visible


## Hand icon while an interaction prompt is active, fist (field strike) otherwise.
func set_prompt_active(active: bool) -> void:
	_prompt = active
	var b: Button = buttons.get(&"action") as Button
	if b != null and b.has_node("Icon"):
		b.get_node("Icon").set("kind", &"hand" if active else &"fist")


func _make_button(spec: Dictionary) -> void:
	var b: Button = Button.new()
	b.name = str(spec["name"])
	b.focus_mode = Control.FOCUS_NONE
	var vis: float = float(spec["size"])
	b.custom_minimum_size = Vector2(vis, vis)
	UiTheme.ensure_hit_area(b)
	b.set_meta("spec", spec)
	_place_button(b)
	var visual: Panel = b.get_node_or_null("HitVisual") as Panel
	if visual != null:
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		var is_action: bool = spec["action"] == &"action"
		sb.bg_color = Color(UiTheme.C_ACCENT, 0.8) if is_action else Color(UiTheme.C_PANEL, 0.75)
		sb.border_color = Color("#f5f0e6", 0.5)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(int(vis))
		visual.add_theme_stylebox_override("panel", sb)
	var icon: Control = UiIcon.make(spec["icon"] as StringName, Color("#f5f0e6"), vis * 0.5)
	icon.name = "Icon"
	icon.anchor_left = 0.5
	icon.anchor_right = 0.5
	icon.anchor_top = 0.5
	icon.anchor_bottom = 0.5
	icon.offset_left = -vis * 0.25
	icon.offset_right = vis * 0.25
	icon.offset_top = -vis * 0.25
	icon.offset_bottom = vis * 0.25
	b.add_child(icon)
	var action: StringName = spec["action"]
	b.button_down.connect(func() -> void:
		_held[action] = true
		UiUtil.tap_action(action, true))
	b.button_up.connect(func() -> void:
		if _held.has(action):
			_held.erase(action)
			UiUtil.tap_action(action, false))
	_root.add_child(b)
	buttons[action] = b


## Anchored to the right edge (and bottom for the action button) so wider screens keep the thumb positions; shifted
## inwards by the display insets (notch / rounded corners).
func _place_button(b: Button) -> void:
	var spec: Dictionary = b.get_meta("spec") as Dictionary
	var hit: Vector2 = b.custom_minimum_size
	var c: Vector2 = spec["center"]
	var from_right: float = REF.x - c.x + float(_insets["right"])
	b.anchor_left = 1.0
	b.anchor_right = 1.0
	if c.y > REF.y * 0.5:
		b.anchor_top = 1.0
		b.anchor_bottom = 1.0
		var from_bottom: float = REF.y - c.y + float(_insets["bottom"])
		b.offset_top = -from_bottom - hit.y * 0.5
		b.offset_bottom = -from_bottom + hit.y * 0.5
	else:
		b.anchor_top = 0.0
		b.anchor_bottom = 0.0
		var y: float = c.y + float(_insets["top"])
		b.offset_top = y - hit.y * 0.5
		b.offset_bottom = y + hit.y * 0.5
	b.offset_left = -from_right - hit.x * 0.5
	b.offset_right = -from_right + hit.x * 0.5


## Canvas x of the left edge of the top-right (pause/map) hit areas: the same right anchor, display insets and hit
## size as _place_button, evaluated for the current viewport, so it is exact before a layout pass and independent of
## the order in which size_changed reaches this layer and the HUDs.
func top_buttons_left() -> float:
	var vp: Viewport = get_viewport() if is_inside_tree() else null
	var w: float = vp.get_visible_rect().size.x if vp != null else REF.x
	var ins: Dictionary = SafeAreaContainer.device_insets(vp)
	var left: float = w
	for b: Variant in buttons.values():
		var btn: Button = b as Button
		var c: Vector2 = (btn.get_meta("spec") as Dictionary)["center"]
		if c.y > REF.y * 0.5:
			continue
		var hit: float = maxf(btn.custom_minimum_size.x, btn.get_combined_minimum_size().x)
		left = minf(left, w - (REF.x - c.x + float(ins["right"])) - hit * 0.5)
	return left


## How far (≥ 0) a HUD element anchored to the right edge of `safe` (its frame) must move left so it ends HUD_GAP
## before the pause/map hit areas. Measured against the buttons' real position, i.e. including the display insets
## (notch) and whatever right margin `safe` has; HUDs re-evaluate it on viewport size changes.
func right_clearance(safe: SafeAreaContainer) -> float:
	if safe == null or not safe.is_inside_tree() or not is_inside_tree():
		return RIGHT_CLEARANCE
	var frame_right: float = safe.get_viewport().get_visible_rect().size.x - float(safe.compute_margins()["right"])
	return maxf(0.0, frame_right - top_buttons_left() + HUD_GAP)


func _apply_insets() -> void:
	_insets = SafeAreaContainer.device_insets(get_viewport())
	if joystick != null:
		joystick.offset_left = float(_insets["left"])
		joystick.offset_bottom = -float(_insets["bottom"])
	for b: Variant in buttons.values():
		_place_button(b as Button)


func _over_button(global_pos: Vector2) -> bool:
	for b: Variant in buttons.values():
		var btn: Button = b as Button
		if btn != null and btn.is_visible_in_tree() and btn.get_global_rect().has_point(global_pos):
			return true
	return false


func _input(event: InputEvent) -> void:
	if not is_shown():
		return
	if event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event
		if st.pressed:
			if _over_button(st.position):
				return
			var local: Vector2 = joystick.get_global_transform_with_canvas().affine_inverse() * st.position
			if bool(joystick.call("touch_down", st.index, local)):
				get_viewport().set_input_as_handled()
			elif _drag_index < 0:
				_drag_index = st.index
		else:
			if bool(joystick.call("touch_up", st.index)):
				get_viewport().set_input_as_handled()
			elif st.index == _drag_index:
				_drag_index = -1
	elif event is InputEventScreenDrag:
		var sd: InputEventScreenDrag = event
		var local_d: Vector2 = joystick.get_global_transform_with_canvas().affine_inverse() * sd.position
		if bool(joystick.call("touch_move", sd.index, local_d)):
			get_viewport().set_input_as_handled()
		elif sd.index == _drag_index:
			Events.camera_drag.emit(sd.relative)
			get_viewport().set_input_as_handled()
