extends Node3D
## Orbit camera of the exploration (02_TECH §7.3, 03_ART §8.1, GDD §2.2): pivot on Kai + 1.4 m (follow lerp 10/s),
## SpringArm3D 7.0 m against layer `world` (sphere 0.25, margin 0.25; collisions shorten instantly, return at 4 m/s),
## pitch −38° (−65°..−15°), FOV 60, stick yaw 2.6 rad/s (cam_* actions), mouse with RMB held 0.005 rad/px, touch drag
## 0.006 rad/px (Events.camera_drag), all × camera_sensitivity; wheel / pinch (Events.camera_zoom) zoom 5–9 m;
## auto-recenter behind Kai after 2.5 s without camera input while he moves (lerp 2/s). The rig node itself is the
## yaw pivot.
##
## Rooms have no ceiling, so walls are never "solved" by shortening the arm alone (`pitch` stays the player's pitch,
## the effective pitch relaxes back to it):
## - Wall or door behind Kai: the effective pitch is first raised (up to −65°) until the arm's horizontal reach
##   (arm × cos pitch) fits the free distance behind the pivot, probed at lintel height — the camera stays inside the
##   room; only when even −65° does not fit, the arm is shortened.
## - Kai right at a wall / in a doorway (that would put the camera less than MIN_BEHIND behind him): the camera may
##   stay behind the wall (previous room, above the wall top) at the flattest pitch from which Kai's head AND feet
##   are in sight (rays against `world`).
## - Deviation (03_ART §8.1 / 02_TECH §7.3, recorded here): the pivot looks LOOK_AHEAD (2.5 m) ahead of Kai along the
##   camera's flat forward (shortened in front of walls), so Kai sits in the lower third and the interact (1.5 m) and
##   field-strike (1.8 m) zone in front of him is not hidden behind his own (chibi) head.
## - Camera closer than 1.5 m to Kai's head → his rig fades out (GeometryInstance3D.transparency for art-kit rigs; the
##   fallback toon shaders dither every fragment closer than 1.5 m to the camera), never a frame filled by his head.

const ARM_LENGTH: float = 7.0
const ZOOM_MIN: float = 5.0
const ZOOM_MAX: float = 9.0
const ZOOM_STEP: float = 0.5
const PITCH_DEFAULT_DEG: float = -38.0
const PITCH_MIN_DEG: float = -65.0
const PITCH_MAX_DEG: float = -15.0
const FOV: float = 60.0
const STICK_YAW: float = 2.6           # rad/s at full deflection
const STICK_PITCH: float = 1.6         # rad/s at full deflection
const MOUSE_RAD_PER_PX: float = 0.005
const TOUCH_RAD_PER_PX: float = 0.006
const PIVOT_HEIGHT: float = 1.4
const LOOK_AHEAD: float = 2.5
const PROBE_HEIGHT: float = 3.2         # free space behind the pivot is measured here (walls 3.5 m, lintels 3.0 m)
const MIN_BEHIND: float = 0.5           # inside-room solution only if the camera stays this far behind Kai
const PITCH_STEP_DEG: float = 3.0
const FOLLOW_LERP: float = 10.0
const RECENTER_DELAY: float = 2.5
const RECENTER_LERP: float = 2.0
const ARM_RETURN_SPEED: float = 4.0
const COLLISION_MARGIN: float = 0.25
const CAST_RADIUS: float = 0.25
const LAYER_WORLD: int = 1
const PITCH_RAISE_SPEED: float = 3.0   # rad/s towards a steeper pitch when the arm would hit a wall
const PITCH_RELAX_SPEED: float = 1.0   # rad/s back towards the player's pitch
const FADE_START: float = 1.5          # camera closer than this to Kai's head → his rig starts to fade
const FADE_HIDDEN: float = 0.6         # … and is gone at this distance
const HEAD_HEIGHT: float = 1.5

var target: Node3D = null
var yaw: float = 0.0
var pitch: float = deg_to_rad(PITCH_DEFAULT_DEG)     # the player's pitch (input, clamped)
var arm_length: float = ARM_LENGTH
var input_enabled: bool = true
## Extra arm length / flatter pitch for framing large figures (boss rooms; set by the scene).
var frame_extra_arm: float = 0.0
## Bodies the camera ignores (blocking bodies of small props: chests, event props; set by the scene). Walls, door
## lintels and gates always count.
var exclude: Array[RID] = []

var _pitch_node: Node3D
var _arm: SpringArm3D
var _cam: Camera3D
var _len: float = ARM_LENGTH
var _eff_pitch: float = deg_to_rad(PITCH_DEFAULT_DEG)
var _look: float = LOOK_AHEAD
var _since_input: float = 0.0
var _arm_kick: float = 1.0
var _cast_shape: SphereShape3D
var _fade: float = 0.0
var _fade_rig: Node = null
var _arm_limit: float = ARM_LENGTH


func _init() -> void:
	name = "CameraRig"
	_pitch_node = Node3D.new()
	_pitch_node.name = "Pitch"
	add_child(_pitch_node)
	_arm = SpringArm3D.new()
	_arm.name = "SpringArm"
	_arm.collision_mask = LAYER_WORLD
	_arm.margin = COLLISION_MARGIN
	_cast_shape = SphereShape3D.new()
	_cast_shape.radius = CAST_RADIUS
	_arm.shape = _cast_shape
	_arm.spring_length = ARM_LENGTH
	_pitch_node.add_child(_arm)
	_cam = Camera3D.new()
	_cam.name = "Camera"
	_cam.fov = FOV
	_cam.near = 0.1
	_cam.far = 120.0
	_pitch_node.add_child(_cam)


func _ready() -> void:
	Events.camera_drag.connect(_on_camera_drag)
	Events.camera_zoom.connect(_on_camera_zoom)
	_cam.current = true
	_apply()


func camera() -> Camera3D:
	return _cam


## Effective pitch actually used this frame (player pitch raised to clear walls).
func effective_pitch() -> float:
	return _eff_pitch


## Current camera distance from the pivot (after collisions).
func current_arm() -> float:
	return _len


## Instantly behind `yaw_rad` (Kai's facing) at the target; arm and pitch resolved against the walls at once.
func snap(yaw_rad: float) -> void:
	yaw = yaw_rad
	pitch = deg_to_rad(PITCH_DEFAULT_DEG)
	_since_input = 0.0
	_apply()
	if target != null and is_instance_valid(target):
		global_position = _pivot_target()
		if is_inside_tree():
			var sol: Vector2 = _solve(_full_arm())
			_eff_pitch = sol.x
			_arm_limit = sol.y
			_len = minf(_free_arm(_eff_pitch, _full_arm()), _arm_limit)
		else:
			_eff_pitch = pitch
			_len = arm_length
	_apply()
	_update_fade()


## Horizontal forward of the camera (movement is relative to it).
func flat_forward() -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


## FOV kick on a field strike (60 → 57 → 60 in 0.15 s).
func kick_strike() -> void:
	if not is_inside_tree():
		return
	var tw: Tween = create_tween()
	tw.tween_property(_cam, "fov", FOV - 3.0, 0.06)
	tw.tween_property(_cam, "fov", FOV, 0.09)


## Arm kick when an enemy notices Kai (7.0 → 6.3 → 7.0 in 0.4 s).
func kick_alert() -> void:
	if not is_inside_tree():
		return
	var tw: Tween = create_tween()
	tw.tween_property(self, "_arm_kick", 0.9, 0.15)
	tw.tween_property(self, "_arm_kick", 1.0, 0.25)


func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var want: Vector3 = _pivot_target()
	global_position = global_position.lerp(want, 1.0 - exp(-FOLLOW_LERP * delta))
	var sens: float = 1.0
	var inv_x: bool = false
	var inv_y: bool = false
	if Game.settings != null:
		sens = Game.settings.camera_sensitivity
		inv_x = Game.settings.camera_invert_x
		inv_y = Game.settings.camera_invert_y
	var had_input: bool = false
	if input_enabled:
		var sx: float = Input.get_axis(&"cam_left", &"cam_right")
		var sy: float = Input.get_axis(&"cam_up", &"cam_down")
		if absf(sx) > 0.0:
			yaw -= sx * STICK_YAW * sens * delta * (-1.0 if inv_x else 1.0)
			had_input = true
		if absf(sy) > 0.0:
			pitch -= sy * STICK_PITCH * sens * delta * (-1.0 if inv_y else 1.0)
			had_input = true
	if had_input:
		_since_input = 0.0
	else:
		_since_input += delta
	var moving: bool = target.has_method("is_moving") and bool(target.call("is_moving"))
	if _since_input >= RECENTER_DELAY and moving:
		yaw = lerp_angle(yaw, target.rotation.y, 1.0 - exp(-RECENTER_LERP * delta))
	_apply()
	# Pitch first: raised where walls need it (smoothly), relaxing back to the player's pitch.
	var full: float = _full_arm()
	var sol: Vector2 = _solve(full)
	_arm_limit = sol.y
	var rate: float = PITCH_RAISE_SPEED if sol.x < _eff_pitch or had_input else PITCH_RELAX_SPEED
	_eff_pitch = move_toward(_eff_pitch, sol.x, rate * delta)
	_pitch_node.rotation = Vector3(_eff_pitch, 0.0, 0.0)
	# Then the arm: within the solved limit, collisions shorten at once (no clipping frames), free space returns at
	# 4 m/s.
	var free_len: float = minf(_free_arm(_eff_pitch, full), _arm_limit)
	if free_len < _len:
		_len = free_len
	else:
		_len = move_toward(_len, free_len, ARM_RETURN_SPEED * delta)
	_cam.position = Vector3(0.0, 0.0, _len)
	_update_fade()


func _full_arm() -> float:
	return (arm_length + frame_extra_arm) * _arm_kick


## Pivot: Kai + 1.4 m, LOOK_AHEAD along the camera's flat forward (not through a wall in front of him).
func _pivot_target() -> Vector3:
	var head: Vector3 = target.global_position + Vector3(0.0, PIVOT_HEIGHT, 0.0)
	_look = LOOK_AHEAD
	if is_inside_tree():
		_look = _cast_free(head, flat_forward(), LOOK_AHEAD)
	return head + flat_forward() * _look


## Camera solution (pitch, arm limit) for the current pivot, see the header.
func _solve(full: float) -> Vector2:
	if not is_inside_tree() or full <= 0.0:
		return Vector2(pitch, full)
	var p_min: float = deg_to_rad(PITCH_MIN_DEG)
	# 1. Inside the room: free distance behind the pivot just under the wall tops (door lintels count as wall).
	var probe: Vector3 = Vector3(global_position.x, target.global_position.y + PROBE_HEIGHT, global_position.z)
	var back: float = _cast_free(probe, Vector3(sin(yaw), 0.0, cos(yaw)), full)
	var p_room: float = pitch
	if full * cos(pitch) > back:
		p_room = maxf(minf(pitch, -acos(clampf(back / full, 0.0, 1.0))), p_min)
	var arm_room: float = minf(full, back / maxf(cos(p_room), 0.001))
	if arm_room * cos(p_room) - _look >= MIN_BEHIND:
		return Vector2(p_room, arm_room)
	# 2. Kai at a wall / in a doorway: flattest pitch whose camera sees his head and feet (may be behind the wall).
	var step: float = deg_to_rad(PITCH_STEP_DEG)
	var p: float = pitch
	while true:
		var a: float = _free_arm(p, full)
		if a >= full * 0.5 and _sees_target(p, a):
			return Vector2(p, full)
		if p <= p_min + 0.0001:
			break
		p = maxf(p_min, p - step)
	return Vector2(p_room, arm_room)


## Rays from the camera position at pitch `p` / arm `a` to Kai's head and feet hit nothing of `world`.
func _sees_target(p: float, a: float) -> bool:
	var dir: Vector3 = (Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, p)) * Vector3(0.0, 0.0, 1.0)
	var cam: Vector3 = global_position + dir * a
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	for h: float in [HEAD_HEIGHT, 0.3]:
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(cam,
			target.global_position + Vector3(0.0, h, 0.0), LAYER_WORLD, exclude)
		if not space.intersect_ray(q).is_empty():
			return false
	return true


## Free arm length at pitch `p` from the current pivot (sphere cast against `world`, minus the margin on a hit).
func _free_arm(p: float, full: float) -> float:
	var dir: Vector3 = (Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, p)) * Vector3(0.0, 0.0, 1.0)
	return _cast_free(global_position, dir, full)


func _cast_free(from: Vector3, dir: Vector3, length: float) -> float:
	if length <= 0.0 or not is_inside_tree():
		return maxf(0.0, length)
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var q: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	q.shape = _cast_shape
	q.transform = Transform3D(Basis(), from)
	q.motion = dir.normalized() * length
	q.collision_mask = LAYER_WORLD
	q.exclude = exclude
	var r: PackedFloat32Array = space.cast_motion(q)
	if r.size() < 1 or r[0] >= 1.0:
		return length
	return maxf(0.0, r[0] * length - COLLISION_MARGIN)


## Fades Kai's rig when the camera comes closer than FADE_START to his head (corner, zoomed in).
func _update_fade() -> void:
	if target == null or not is_instance_valid(target) or not _cam.is_inside_tree():
		return
	var rig: Node = target.get("rig") as Node if "rig" in target else null
	if rig == null or not is_instance_valid(rig):
		return
	var head: Vector3 = target.global_position + Vector3(0.0, HEAD_HEIGHT, 0.0)
	var d: float = _cam.global_position.distance_to(head)
	var f: float = clampf((FADE_START - d) / (FADE_START - FADE_HIDDEN), 0.0, 1.0)
	if is_equal_approx(f, _fade) and rig == _fade_rig:
		return
	_fade = f
	_fade_rig = rig
	_set_transparency(rig, f)


static func _set_transparency(n: Node, t: float) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).transparency = t
	for c: Node in n.get_children():
		_set_transparency(c, t)


func _apply() -> void:
	pitch = clampf(pitch, deg_to_rad(PITCH_MIN_DEG), deg_to_rad(PITCH_MAX_DEG))
	arm_length = clampf(arm_length, ZOOM_MIN, ZOOM_MAX)
	rotation = Vector3(0.0, yaw, 0.0)
	_eff_pitch = clampf(_eff_pitch, deg_to_rad(PITCH_MIN_DEG), deg_to_rad(PITCH_MAX_DEG))
	_pitch_node.rotation = Vector3(_eff_pitch, 0.0, 0.0)
	_arm.spring_length = _full_arm()
	_cam.position = Vector3(0.0, 0.0, minf(_len, _arm.spring_length))


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	var sens: float = Game.settings.camera_sensitivity if Game.settings != null else 1.0
	if event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		if mm.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			_rotate_by(mm.relative, MOUSE_RAD_PER_PX * sens)
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			arm_length -= ZOOM_STEP
			_since_input = 0.0
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			arm_length += ZOOM_STEP
			_since_input = 0.0


func _on_camera_drag(relative: Vector2) -> void:
	if not is_inside_tree() or not input_enabled:
		return
	var sens: float = Game.settings.camera_sensitivity if Game.settings != null else 1.0
	_rotate_by(relative, TOUCH_RAD_PER_PX * sens)


## Touch pinch (TouchControls): arm length change in m, clamped to ZOOM_MIN..ZOOM_MAX like the mouse wheel.
func _on_camera_zoom(amount: float) -> void:
	if not is_inside_tree() or not input_enabled:
		return
	arm_length = clampf(arm_length + amount, ZOOM_MIN, ZOOM_MAX)
	_since_input = 0.0


func _rotate_by(relative: Vector2, rad_per_px: float) -> void:
	var inv_x: bool = Game.settings != null and Game.settings.camera_invert_x
	var inv_y: bool = Game.settings != null and Game.settings.camera_invert_y
	yaw -= relative.x * rad_per_px * (-1.0 if inv_x else 1.0)
	var before: float = pitch
	pitch -= relative.y * rad_per_px * (-1.0 if inv_y else 1.0)
	_since_input = 0.0
	_apply()
	# Direct pitch input moves the effective pitch along (the wall clearance can only raise it further).
	_eff_pitch = clampf(_eff_pitch + (pitch - before), deg_to_rad(PITCH_MIN_DEG), deg_to_rad(PITCH_MAX_DEG))
