extends Control
## Floating virtual joystick (02_TECH §10.3, 03_ART §9.4): lives in the left 40 % of the screen, appears at the touch
## point, radius 90 px, knob 40 px, dead zone 0.15. Writes Input.action_press(&"move_*", strength) / action_release;
## deflection ≤ 0.6 additionally holds `sneak`. Rest display at (147, 573) of the 1280×720 reference (bottom-left anchored).

const RADIUS: float = 90.0
const KNOB: float = 40.0                    # knob diameter
const DEADZONE: float = 0.15
const SNEAK_MAX: float = 0.6
const REST: Vector2 = Vector2(147, 573)     # reference 1280×720 → 147 px from the left, 147 px from the bottom
const REF_H: float = 720.0
const MOVE_ACTIONS: Array[StringName] = [&"move_forward", &"move_back", &"move_left", &"move_right"]

var active: bool = false
var touch_index: int = -1
var center: Vector2 = Vector2.ZERO          # in this control's local coordinates
var knob_offset: Vector2 = Vector2.ZERO
var vector: Vector2 = Vector2.ZERO          # -1..1, y < 0 = forward
var sneaking: bool = false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	center = rest_position()


## Rest centre in local coordinates (bottom-left anchored).
func rest_position() -> Vector2:
	return Vector2(REST.x, size.y - (REF_H - REST.y)) if size.y > 0.0 else REST


## True if a touch at `local_pos` should be taken by the joystick (left 40 % zone = this control's rect).
func accepts(local_pos: Vector2) -> bool:
	return Rect2(Vector2.ZERO, size).has_point(local_pos)


func touch_down(index: int, local_pos: Vector2) -> bool:
	if active or not accepts(local_pos):
		return false
	active = true
	touch_index = index
	center = local_pos
	knob_offset = Vector2.ZERO
	_apply(Vector2.ZERO)
	queue_redraw()
	return true


func touch_move(index: int, local_pos: Vector2) -> bool:
	if not active or index != touch_index:
		return false
	var off: Vector2 = local_pos - center
	if off.length() > RADIUS:
		off = off.normalized() * RADIUS
	knob_offset = off
	_apply(off / RADIUS)
	queue_redraw()
	return true


func touch_up(index: int) -> bool:
	if not active or index != touch_index:
		return false
	release()
	return true


func release() -> void:
	active = false
	touch_index = -1
	knob_offset = Vector2.ZERO
	center = rest_position()
	_apply(Vector2.ZERO)
	queue_redraw()


func _apply(v: Vector2) -> void:
	var len_v: float = v.length()
	if len_v < DEADZONE:
		v = Vector2.ZERO
		len_v = 0.0
	vector = v
	_set_action(&"move_right", maxf(v.x, 0.0))
	_set_action(&"move_left", maxf(-v.x, 0.0))
	_set_action(&"move_back", maxf(v.y, 0.0))
	_set_action(&"move_forward", maxf(-v.y, 0.0))
	var want_sneak: bool = len_v > 0.0 and len_v <= SNEAK_MAX
	if want_sneak != sneaking:
		sneaking = want_sneak
		if InputMap.has_action(&"sneak"):
			if want_sneak:
				Input.action_press(&"sneak", 1.0)
			else:
				Input.action_release(&"sneak")


func _set_action(action: StringName, strength: float) -> void:
	if not InputMap.has_action(action):
		return
	if strength > 0.0:
		Input.action_press(action, clampf(strength, 0.0, 1.0))
	else:
		Input.action_release(action)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and not active:
		center = rest_position()
		queue_redraw()
	elif what == NOTIFICATION_EXIT_TREE and active:
		release()


func _draw() -> void:
	var ring_col: Color = Color("#f5f0e6", 0.25 if active else 0.16)
	draw_circle(center, RADIUS, Color("#140d1c", 0.25), true, -1.0, true)
	draw_arc(center, RADIUS, 0.0, TAU, 48, ring_col, 3.0, true)
	for i in 4:
		var a: float = float(i) * PI * 0.5
		var d: Vector2 = Vector2(cos(a), sin(a))
		var tip: Vector2 = center + d * (RADIUS - 14.0)
		var side: Vector2 = Vector2(-d.y, d.x) * 7.0
		draw_colored_polygon(PackedVector2Array([tip + d * 8.0, tip + side, tip - side]), ring_col)
	var k: Vector2 = center + knob_offset
	draw_circle(k, KNOB * 0.5 + 6.0, Color("#f5f0e6", 0.18), true, -1.0, true)
	draw_circle(k, KNOB * 0.5, Color("#f5f0e6", 0.6), true, -1.0, true)
