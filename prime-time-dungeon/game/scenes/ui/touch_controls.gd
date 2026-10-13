extends CanvasLayer
## Touch layer (02_TECH §10.3, §9.4 layer 20; 03_ART §9.4): floating joystick in the left 40 %, one round `action`
## button (96 px at (1147, 587); hand icon with a prompt, otherwise the hero's field ability: fist for Kai's strike,
## sound waves for Graf Mopsula's bark — 06 §1.3), `map` (64 px at (1227, 140)) and `pause`
## (64 px at (1227, 40)); every hit area ≥ 88 px (UiTheme.ensure_hit_area). Buttons send InputEventAction press/release.
## Drag on the free right side → Events.camera_drag(relative); two fingers there pinch → Events.camera_zoom(m) (GDD
## pinch zoom; > 0 = fingers closer = zoom out, PINCH_M_PER_PX). Visible when settings.touch_controls == &"on" or
## (&"auto" and a touchscreen is available and Game.input_scheme == TOUCH).
## Safe area (§10.4): button offsets and the joystick zone shift by the display cutout insets (recomputed on resize).
## Pause (§9.4): this layer is PAUSABLE and gets no touch_up/drag while PauseMenu/BigMap pause the tree, so on
## NOTIFICATION_PAUSED it releases the joystick (move_*/sneak) and every held button action.
## While shown, `active` points at this instance: ExplorationHud and ShowOverlay move the minimap / hype meter out of
## the pause/map hit areas (top right).
## Echtzeitkampf (07 §7.3, R3): set_combat_mode() hides the action and map buttons (the combat thumb group takes the
## action spot), limits the stick to the bottom left (x 0–40 %, y ≥ 320 of the reference) without `sneak`, and splits
## a touch elsewhere into a tap (≤ 0.25 s, < 12 px → target pick) or a camera drag (from the frame it passes 12 px).
## The pull outside a combat (07 §2.2, §7.3, E36): set_explore_tap() splits the touches of the exploration the same
## way (a tap targets a lead, free ground clears it); set_pull_slot() lets the action button show slot 1's symbol in
## the action bar's tints while a lead is targeted (it pulls then), with a gold pulse while the pull hint shows (E37).

signal shown_changed(shown: bool)

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const UiIcon := preload("res://scenes/ui/ui_icon.gd")
const Joystick := preload("res://scenes/ui/virtual_joystick.gd")
const CombatStyle := preload("res://scenes/combat/ui/combat_style.gd")
const CombatIcons := preload("res://scenes/combat/ui/combat_icons.gd")
const CombatView := preload("res://scenes/combat/ui/combat_view.gd")
const IconMesh := preload("res://scenes/ui/icon_mesh.gd")
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
## Pinch: arm length change per pixel of finger distance (200 px ≈ the whole 5–9 m zoom range of the camera rig).
const PINCH_M_PER_PX: float = 0.02

var force_visible: bool = false             # captures / tests
var joystick: Control
var buttons: Dictionary = {}                # action → Button

var _root: Control
var _drag_index: int = -1
var _cam_touches: Dictionary = {}           # touch index → position of fingers on the free camera area
var _pinch_dist: float = -1.0               # finger distance of the running pinch (-1: fewer than 2 fingers)
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
	_cam_touches.clear()
	_pinch_dist = -1.0
	_taps.clear()                                # Echtzeitkampf (07, R3)
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


## Hand icon while an interaction prompt is active, the hero's field ability otherwise (fist / bark) — or slot 1's
## symbol while a lead is targeted (set_pull_slot; the prompt keeps its priority).
func set_prompt_active(active: bool) -> void:
	_prompt = active
	_refresh_action_icon()


## 06 package A: &"fist" (Kai strikes) | &"bark" (Graf Mopsula barks).
static func field_icon() -> StringName:
	return &"bark" if Game.hero() == "mopsula" else &"fist"


## After a hero switch: the idle action icon follows the new hero.
func refresh_hero() -> void:
	set_prompt_active(_prompt)


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
	var kind: StringName = field_icon() if spec["action"] == &"action" else spec["icon"] as StringName
	var icon: Control = UiIcon.make(kind, Color("#f5f0e6"), vis * 0.5)
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
	if spec["action"] == &"action":                # 07 §7.3 (E36): slot 1's symbol while a lead is targeted
		var pull_icon: Control = Control.new()
		pull_icon.name = "PullIcon"
		pull_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pull_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		pull_icon.visible = false
		pull_icon.draw.connect(_draw_pull_icon.bind(pull_icon))
		b.add_child(pull_icon)
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
	if (combat_mode or _explore_tap.is_valid()) and _combat_input(event):      # Echtzeitkampf (07, R3; E36)
		return
	if event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event
		if st.pressed:
			if _over_button(st.position):
				return
			var local: Vector2 = joystick.get_global_transform_with_canvas().affine_inverse() * st.position
			if bool(joystick.call("touch_down", st.index, local)):
				get_viewport().set_input_as_handled()
			else:
				_cam_touches[st.index] = st.position
				if _drag_index < 0:
					_drag_index = st.index
				_pinch_dist = _pinch_distance()
		else:
			if bool(joystick.call("touch_up", st.index)):
				get_viewport().set_input_as_handled()
			else:
				_cam_touches.erase(st.index)
				if st.index == _drag_index:
					_drag_index = int(_cam_touches.keys()[0]) if not _cam_touches.is_empty() else -1
				_pinch_dist = _pinch_distance()
	elif event is InputEventScreenDrag:
		var sd: InputEventScreenDrag = event
		var local_d: Vector2 = joystick.get_global_transform_with_canvas().affine_inverse() * sd.position
		if bool(joystick.call("touch_move", sd.index, local_d)):
			get_viewport().set_input_as_handled()
		elif _cam_touches.has(sd.index):
			_cam_touches[sd.index] = sd.position
			if _cam_touches.size() >= 2:
				var d: float = _pinch_distance()
				if _pinch_dist > 0.0 and d > 0.0:
					Events.camera_zoom.emit((_pinch_dist - d) * PINCH_M_PER_PX)
				_pinch_dist = d
			elif sd.index == _drag_index:
				Events.camera_drag.emit(sd.relative)
			get_viewport().set_input_as_handled()


## Distance of the first two camera-area fingers (-1 with fewer than two).
func _pinch_distance() -> float:
	if _cam_touches.size() < 2:
		return -1.0
	var keys: Array = _cam_touches.keys()
	keys.sort()
	return (_cam_touches[keys[0]] as Vector2).distance_to(_cam_touches[keys[1]] as Vector2)


# --- Echtzeitkampf (07, R3): combat mode (07 §7.3) -------------------------------------------------------------------

const COMBAT_STICK_TOP: float = 320.0        # stick zone in combat: x 0–40 %, y 320–720 of the reference
const TAP_MAX_MS: int = 250
const TAP_MAX_PX: float = 12.0
const COMBAT_HIDDEN: Array[StringName] = [&"action", &"map"]

## Test seam: a fixed clock for the tap rule (ms); < 0 = Time.get_ticks_msec().
static var test_now_ms: int = -1

var combat_mode: bool = false
var _combat_tap: Callable = Callable()
var _combat_blocks: Callable = Callable()
var _taps: Dictionary = {}                   # touch index → {"pos": Vector2, "t": ms, "drag": bool}


## On: the combat HUD's `tap(canvas_pos)` receives the target taps, `blocks(canvas_pos) -> bool` names the points its
## own controls own (thumb group, frames, chip, open card / wheel) — touches there are left to the GUI. Off restores
## the exploration layout.
func set_combat_mode(on: bool, tap: Callable, blocks: Callable) -> void:
	release_all()
	combat_mode = on
	_combat_tap = tap if on else Callable()
	_combat_blocks = blocks if on else Callable()
	for a: StringName in COMBAT_HIDDEN:
		var b: Button = buttons.get(a) as Button
		if b != null:
			b.visible = not on
	if joystick != null:
		joystick.set("allow_sneak", not on)
		joystick.offset_top = COMBAT_STICK_TOP if on else 0.0


## Canvas rect of the stick zone (tests).
func stick_zone() -> Rect2:
	return joystick.get_global_rect() if joystick != null else Rect2()


static func _now_ms() -> int:
	return test_now_ms if test_now_ms >= 0 else Time.get_ticks_msec()


func _blocked(pos: Vector2) -> bool:
	return _combat_blocks.is_valid() and bool(_combat_blocks.call(pos))


## The touch handling of the combat mode; true = the event is dealt with (the exploration path is skipped).
func _combat_input(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event
		if st.pressed:
			if _over_button(st.position) or _blocked(st.position):
				return true                          # a button / combat control: the GUI takes it
			var local: Vector2 = joystick.get_global_transform_with_canvas().affine_inverse() * st.position
			if bool(joystick.call("touch_down", st.index, local)):
				get_viewport().set_input_as_handled()
				return true
			_taps[st.index] = {"pos": st.position, "t": _now_ms(), "drag": false}
			_cam_touches[st.index] = st.position
			_pinch_dist = _pinch_distance()
			if _cam_touches.size() >= 2:
				for k: Variant in _taps.keys():
					(_taps[k] as Dictionary)["drag"] = true      # two fingers: zoom, never a tap
			get_viewport().set_input_as_handled()
			return true
		if bool(joystick.call("touch_up", st.index)):
			get_viewport().set_input_as_handled()
			return true
		var t: Dictionary = _taps.get(st.index, {}) as Dictionary
		_taps.erase(st.index)
		if not _cam_touches.has(st.index):
			return true
		_cam_touches.erase(st.index)
		if st.index == _drag_index:
			_drag_index = int(_cam_touches.keys()[0]) if not _cam_touches.is_empty() else -1
		_pinch_dist = _pinch_distance()
		var tap: Callable = _combat_tap if combat_mode else _explore_tap
		if not t.is_empty() and not bool(t["drag"]) and _now_ms() - int(t["t"]) <= TAP_MAX_MS \
				and st.position.distance_to(t["pos"] as Vector2) < TAP_MAX_PX and tap.is_valid():
			tap.call(st.position)
		get_viewport().set_input_as_handled()
		return true
	if event is InputEventScreenDrag:
		var sd: InputEventScreenDrag = event
		var local_d: Vector2 = joystick.get_global_transform_with_canvas().affine_inverse() * sd.position
		if bool(joystick.call("touch_move", sd.index, local_d)):
			get_viewport().set_input_as_handled()
			return true
		if not _cam_touches.has(sd.index):
			return true                              # began on a combat control
		_cam_touches[sd.index] = sd.position
		if _cam_touches.size() >= 2:
			var d: float = _pinch_distance()
			if _pinch_dist > 0.0 and d > 0.0:
				Events.camera_zoom.emit((_pinch_dist - d) * PINCH_M_PER_PX)
			_pinch_dist = d
		else:
			var t2: Dictionary = _taps.get(sd.index, {}) as Dictionary
			if not t2.is_empty() and not bool(t2["drag"]):
				if sd.position.distance_to(t2["pos"] as Vector2) < TAP_MAX_PX:
					get_viewport().set_input_as_handled()
					return true                      # still a tap candidate: the camera stays
				t2["drag"] = true
				_drag_index = sd.index
			if sd.index == _drag_index or _drag_index < 0:
				_drag_index = sd.index
				Events.camera_drag.emit(sd.relative)
		get_viewport().set_input_as_handled()
		return true
	return false


# --- the pull outside a combat (07 §2.2, §7.3; E36, E37) --------------------------------------------------------------

const PULL_SHAKE_SEC: float = 0.2

var _explore_tap: Callable = Callable()
var _pull: Dictionary = {}                   # {"id": slot 1's skill, "reason", "hint"} while a lead is targeted
var _pull_shake: float = 0.0
var _pull_t: float = 0.0


## On (a callable): the exploration's touches outside the stick and the buttons split into a tap (≤ 0.25 s, < 12 px:
## `tap(canvas_pos)` — a lead there becomes the target, free ground clears it) or a camera drag (from the frame it
## passes 12 px), like the combat (07 §7.3). Callable() restores the plain camera drag (CTB runs).
func set_explore_tap(tap: Callable) -> void:
	release_all()
	_explore_tap = tap


## A lead is targeted outside a combat: the action button shows `skill_id` (slot 1; "" = back to the field ability) in
## the tints of the action bar (`reason`: "" ready, "range" red, "mp" blue, else dimmed) and pulses gold while the pull
## hint shows (`hint`). An interaction prompt keeps the hand.
func set_pull_slot(skill_id: String, reason: String, hint: bool) -> void:
	var p: Dictionary = {"id": skill_id, "reason": reason, "hint": hint} if skill_id != "" else {}
	if p == _pull:
		return
	_pull = p
	_refresh_action_icon()


## The symbol the action button shows: &"hand", &"fist", &"bark" or "pull:<skill id>" (tests).
func action_symbol() -> String:
	var b: Button = buttons.get(&"action") as Button
	var pi: Control = b.get_node_or_null("PullIcon") as Control if b != null else null
	if pi != null and pi.visible:
		return "pull:" + str(_pull.get("id", ""))
	var icon: Node = b.get_node_or_null("Icon") if b != null else null
	return str(icon.get("kind")) if icon != null else ""


## A refused pull of the action button: its symbol shakes.
func refuse_pull() -> void:
	_pull_shake = PULL_SHAKE_SEC


func _refresh_action_icon() -> void:
	var b: Button = buttons.get(&"action") as Button
	if b == null:
		return
	var pull_on: bool = not _prompt and not _pull.is_empty()
	var icon: CanvasItem = b.get_node_or_null("Icon") as CanvasItem
	if icon != null:
		icon.set("kind", &"hand" if _prompt else field_icon())
		icon.visible = not pull_on
	var pi: Control = b.get_node_or_null("PullIcon") as Control
	if pi != null:
		pi.visible = pull_on
		pi.queue_redraw()


func _process(delta: float) -> void:
	if _pull.is_empty() and _pull_shake <= 0.0:
		return
	_pull_t += delta
	_pull_shake = maxf(0.0, _pull_shake - delta)
	var b: Button = buttons.get(&"action") as Button
	var pi: Control = b.get_node_or_null("PullIcon") as Control if b != null else null
	if pi != null and pi.visible:
		pi.queue_redraw()


## Slot 1's symbol on the action button in the action bar's tints (07 §8.2), the gold pulse of the pull hint.
func _draw_pull_icon(pi: Control) -> void:
	if _pull.is_empty():
		return
	var m: IconMesh = IconMesh.new()
	var c: Vector2 = pi.size * 0.5 + Vector2(sin(_pull_t * 70.0) * 5.0 * _pull_shake / PULL_SHAKE_SEC, 0.0)
	var vis: float = float((BUTTONS[0] as Dictionary)["size"])
	var isz: float = vis * 0.58
	var from: int = m.colors.size()
	CombatIcons.draw(m, CombatStyle.skill_icon(CombatView.skill_of(str(_pull["id"]))),
		Rect2(c - Vector2(isz, isz) * 0.5, Vector2(isz, isz)))
	match str(_pull.get("reason", "")):
		"":
			pass
		"mp":
			CombatIcons.recolor(m, from, 0.85, Color(CombatStyle.C_MANA, 0.5))
		"range":
			CombatIcons.recolor(m, from, 0.4, Color(CombatStyle.C_DANGER, 0.6))
		_:
			CombatIcons.recolor(m, from, 0.0, Color(0, 0, 0, 0), 0.4)
	if bool(_pull.get("hint", false)):
		var a: float = 0.45 + 0.55 * (0.5 + 0.5 * sin(_pull_t * TAU * 1.2))
		m.ring(c, vis * 0.5 + 7.0, Color(CombatStyle.C_GOLD, a), 3.0, true)
	m.commit(pi)
