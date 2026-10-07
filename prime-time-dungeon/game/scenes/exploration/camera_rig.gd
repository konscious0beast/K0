extends Node3D
## Orbit camera of the exploration (02_TECH §7.3, 03_ART §8.1, GDD §2.2): pivot on Kai + 1.4 m (follow lerp 10/s),
## SpringArm3D 7.0 m against layer `world` (sphere 0.25, margin 0.25; collisions shorten instantly, return at 4 m/s),
## pitch −38° (−65°..−15°), FOV 60, stick yaw 2.6 rad/s (cam_* actions), mouse with RMB held 0.005 rad/px, touch drag
## 0.006 rad/px (Events.camera_drag), all × camera_sensitivity; wheel zoom 5–9 m; auto-recenter behind Kai after 2.5 s
## without camera input while he moves (lerp 2/s). The rig node itself is the yaw pivot.

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
const FOLLOW_LERP: float = 10.0
const RECENTER_DELAY: float = 2.5
const RECENTER_LERP: float = 2.0
const ARM_RETURN_SPEED: float = 4.0
const COLLISION_MARGIN: float = 0.25
const LAYER_WORLD: int = 1

var target: Node3D = null
var yaw: float = 0.0
var pitch: float = deg_to_rad(PITCH_DEFAULT_DEG)
var arm_length: float = ARM_LENGTH
var input_enabled: bool = true

var _pitch_node: Node3D
var _arm: SpringArm3D
var _cam: Camera3D
var _len: float = ARM_LENGTH
var _since_input: float = 0.0
var _arm_kick: float = 1.0


func _init() -> void:
	name = "CameraRig"
	_pitch_node = Node3D.new()
	_pitch_node.name = "Pitch"
	add_child(_pitch_node)
	_arm = SpringArm3D.new()
	_arm.name = "SpringArm"
	_arm.collision_mask = LAYER_WORLD
	_arm.margin = COLLISION_MARGIN
	var sph: SphereShape3D = SphereShape3D.new()
	sph.radius = 0.25
	_arm.shape = sph
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
	_cam.current = true
	_apply()


func camera() -> Camera3D:
	return _cam


## Instantly behind `yaw_rad` (Kai's facing) at the target; arm at full length.
func snap(yaw_rad: float) -> void:
	yaw = yaw_rad
	pitch = deg_to_rad(PITCH_DEFAULT_DEG)
	if target != null:
		global_position = target.global_position + Vector3(0.0, PIVOT_HEIGHT, 0.0)
	_len = arm_length
	_since_input = 0.0
	_apply()


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
	var want: Vector3 = target.global_position + Vector3(0.0, PIVOT_HEIGHT, 0.0)
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
	# Arm: collisions shorten at once, free space returns at 4 m/s.
	var free_len: float = _arm.get_hit_length()
	if free_len <= 0.0:
		free_len = _arm.spring_length
	if free_len < _len:
		_len = free_len
	else:
		_len = move_toward(_len, free_len, ARM_RETURN_SPEED * delta)
	_cam.position = Vector3(0.0, 0.0, _len)


func _apply() -> void:
	pitch = clampf(pitch, deg_to_rad(PITCH_MIN_DEG), deg_to_rad(PITCH_MAX_DEG))
	arm_length = clampf(arm_length, ZOOM_MIN, ZOOM_MAX)
	rotation = Vector3(0.0, yaw, 0.0)
	_pitch_node.rotation = Vector3(pitch, 0.0, 0.0)
	_arm.spring_length = arm_length * _arm_kick
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


func _rotate_by(relative: Vector2, rad_per_px: float) -> void:
	var inv_x: bool = Game.settings != null and Game.settings.camera_invert_x
	var inv_y: bool = Game.settings != null and Game.settings.camera_invert_y
	yaw -= relative.x * rad_per_px * (-1.0 if inv_x else 1.0)
	pitch -= relative.y * rad_per_px * (-1.0 if inv_y else 1.0)
	_since_input = 0.0
	_apply()
