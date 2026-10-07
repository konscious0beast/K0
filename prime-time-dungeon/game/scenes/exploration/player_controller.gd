extends CharacterBody3D
## Kai in the exploration (02_TECH §7.3, GDD §2.1): capsule r 0.4 / h 1.7 (layer 2 `player`, mask 1 `world`),
## run 5.5 m/s, sneak 2.5 m/s (action `sneak` held; touch: stick deflection ≤ 0.6 holds sneak), accel 30 m/s²,
## decel 40 m/s², turn 12 rad/s towards the move direction, gravity 20 m/s², no jump. Movement is camera relative
## (Input.get_vector of the move_* actions: keyboard, gamepad and touch alike; the deflection only sets the direction).
## `action` (one key) → signal action_requested; the ExplorationScene decides between interact (focused interactable)
## and the field strike (start_strike: arc 100°, reach 1.8 m, 0.45 s, cooldown 0.6 s).
## Standalone (scene root, e.g. capture of player.tscn) it builds a small preview stage around itself.

signal action_requested

const Rules := preload("res://scenes/exploration/encounter_rules.gd")
const FB := preload("res://scenes/exploration/fallback_art.gd")
const RUN_SPEED: float = 5.5
const SNEAK_SPEED: float = 2.5
const ACCEL: float = 30.0
const DECEL: float = 40.0
const TURN_RATE: float = 12.0
const GRAVITY: float = 20.0
const CAPSULE_RADIUS: float = 0.4
const CAPSULE_HEIGHT: float = 1.7
const STEP_INTERVAL_RUN: float = 0.36
const ARC_FLASH_SEC: float = 0.15        # gold swoosh from the start of the hitting part of the swing
const ARC_HEIGHT: float = 0.9
const STEP_INTERVAL_SNEAK: float = 0.62
const MOVE_ACTIONS: Array[StringName] = [&"move_forward", &"move_back", &"move_left", &"move_right", &"sneak",
	&"action"]

var input_enabled: bool = true
var camera_yaw: float = 0.0          # set by the scene from the camera rig every frame
var grace_left: float = 0.0          # > 0: unhittable + invisible for enemies (after a battle / flight)
var rig: Node3D = null

var _strike_t: float = -1.0          # time since the strike started (−1 = not striking)
var _cooldown: float = 0.0
var _step_t: float = 0.0
var _anim_t: float = 0.0
var _sneaking: bool = false
var _standalone: bool = false
var _arc: MeshInstance3D = null           # field-strike swoosh (100°, 1.8 m), visible ARC_FLASH_SEC


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.3
	if get_node_or_null("Collision") == null:
		var cs: CollisionShape3D = CollisionShape3D.new()
		cs.name = "Collision"
		var cap: CapsuleShape3D = CapsuleShape3D.new()
		cap.radius = CAPSULE_RADIUS
		cap.height = CAPSULE_HEIGHT
		cs.shape = cap
		cs.position = Vector3(0.0, CAPSULE_HEIGHT * 0.5, 0.0)
		add_child(cs)
	if rig == null:
		_build_rig()
	if _arc == null:
		_arc = MeshInstance3D.new()
		_arc.name = "StrikeArc"
		_arc.mesh = FB.strike_arc_mesh()
		_arc.material_override = FB.beam(FB.HYPE_GOLD, 0.9)
		_arc.position = Vector3(0.0, ARC_HEIGHT, 0.0)
		_arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_arc.visible = false
		add_child(_arc)
	_standalone = get_parent() == get_tree().root
	if _standalone:
		_build_preview_stage()


## Marker used by interactable areas to recognise Kai.
func is_player_body() -> bool:
	return true


func _build_rig() -> void:
	var model: Dictionary = {"base": "humanoid", "scale": 1.0, "colors": {"primary": "#3aa9a0", "secondary": "#2e3a57",
		"accent": "#3b2a22", "skin": "#e8b48f", "eyes": "#1a1420"}}
	if DB.has_id("party", "kai"):
		model = DB.party_member("kai").model
	var r: CharacterRig = CharacterBuilder.build(model, 1)
	if r == null:
		r = CharacterRig.new()
	if FB.is_empty(r):
		FB.build_character(model, r)
	r.name = "Rig"
	var visual: Node3D = get_node_or_null("Visual") as Node3D
	if visual != null:
		visual.add_child(r)
	else:
		add_child(r)
	rig = r


func _physics_process(delta: float) -> void:
	_anim_t += delta
	_cooldown = maxf(0.0, _cooldown - delta)
	if _strike_t >= 0.0:
		_strike_t += delta
		if _strike_t > Rules.STRIKE_DURATION:
			_strike_t = -1.0
	if _arc != null:
		_arc.visible = _strike_t >= Rules.STRIKE_HIT_FROM and _strike_t <= Rules.STRIKE_HIT_FROM + ARC_FLASH_SEC
	if grace_left > 0.0:
		grace_left = maxf(0.0, grace_left - delta)
		if rig != null:
			rig.visible = grace_left <= 0.0 or fmod(grace_left, 0.2) > 0.08
	var input: Vector2 = Vector2.ZERO
	if input_enabled:
		input = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	_sneaking = input_enabled and Input.is_action_pressed(&"sneak")
	var max_speed: float = SNEAK_SPEED if _sneaking else RUN_SPEED
	var dir: Vector3 = Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, camera_yaw)
	var strength: float = minf(1.0, input.length())
	var horizontal: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	if strength > 0.01:
		# Two speeds only (GDD §2.1, TECH §7.3/§10.3): the stick gives the direction, `sneak` the speed (the touch
		# joystick holds `sneak` itself at a deflection ≤ 0.6). Never scaled by the deflection.
		var want: Vector3 = dir.normalized() * max_speed
		horizontal = horizontal.move_toward(want, ACCEL * delta)
		var target_yaw: float = Rules.yaw_of(dir)
		var diff: float = wrapf(target_yaw - rotation.y, -PI, PI)
		rotation.y += clampf(diff, -TURN_RATE * delta, TURN_RATE * delta)
	else:
		horizontal = horizontal.move_toward(Vector3.ZERO, DECEL * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	var speed: float = Vector2(velocity.x, velocity.z).length()
	if rig != null:
		if rig.has_method("set_locomotion"):
			rig.call("set_locomotion", speed)
		FB.animate_character(rig, _anim_t, speed)
	if speed > 0.5 and is_on_floor():
		_step_t += delta
		if _step_t >= (STEP_INTERVAL_SNEAK if _sneaking else STEP_INTERVAL_RUN):
			_step_t = 0.0
			Sfx.play(&"step", -16.0 if _sneaking else -11.0)
	else:
		_step_t = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled or _standalone:
		return
	if event.is_action_pressed(&"action") and not event.is_echo():
		get_viewport().set_input_as_handled()
		action_requested.emit()


## Starts a field strike (false while cooling down / already striking).
func start_strike() -> bool:
	if _cooldown > 0.0 or _strike_t >= 0.0:
		return false
	_strike_t = 0.0
	_cooldown = Rules.STRIKE_COOLDOWN
	Sfx.play(&"swing")
	if rig != null and rig.has_method("play"):
		rig.call("play", &"attack", 1.0)
	_swing_fallback_body()
	return true


## Fallback figure (stub rig without animations): twist + lean the body 0.15 s out, 0.3 s back.
func _swing_fallback_body() -> void:
	if rig == null or not rig.has_meta(FB.META_FALLBACK) or not is_inside_tree():
		return
	var body: Node3D = rig.get_node_or_null("FallbackBody") as Node3D
	if body == null:
		return
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(body, "rotation:y", -0.7, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(body, "rotation:x", -0.25, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(body, "rotation:y", 0.0, 0.3).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(body, "rotation:x", 0.0, 0.3).set_trans(Tween.TRANS_SINE)


## True during the hitting part of the swing.
func is_strike_hitting() -> bool:
	return _strike_t >= Rules.STRIKE_HIT_FROM and _strike_t <= Rules.STRIKE_DURATION


func is_striking() -> bool:
	return _strike_t >= 0.0


func strike_ready() -> bool:
	return _cooldown <= 0.0 and _strike_t < 0.0


func flat_forward() -> Vector3:
	return Rules.flat_forward(global_transform.basis)


func is_moving() -> bool:
	return Vector2(velocity.x, velocity.z).length() > 0.5


func is_sneaking() -> bool:
	return _sneaking


func is_hidden() -> bool:
	return grace_left > 0.0


## 2 s unhittable + invisible (GDD §2.3 GRACE_SEC).
func set_grace(sec: float) -> void:
	grace_left = maxf(grace_left, sec)


func teleport(pos: Vector3, yaw: float) -> void:
	global_position = pos
	rotation = Vector3(0.0, yaw, 0.0)
	velocity = Vector3.ZERO
	reset_physics_interpolation()


## Releases every exploration action (suspend, dialogs) so nothing keeps walking.
func release_inputs() -> void:
	for a: StringName in MOVE_ACTIONS:
		if Input.is_action_pressed(a):
			Input.action_release(a)
	velocity = Vector3.ZERO
	_strike_t = -1.0
	if _arc != null:
		_arc.visible = false


## Preview stage for standalone instancing (capture of player.tscn): floor, light, camera.
func _build_preview_stage() -> void:
	input_enabled = false
	var floor_body: StaticBody3D = StaticBody3D.new()
	var cs: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(8.0, 0.2, 8.0)
	cs.shape = box
	cs.position = Vector3(0.0, -0.1, 0.0)
	floor_body.add_child(cs)
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(8.0, 0.2, 8.0)
	mi.mesh = bm
	mi.material_override = FB.toon(Color("#3a3f4b"), false)
	mi.position = Vector3(0.0, -0.1, 0.0)
	floor_body.add_child(mi)
	get_parent().add_child.call_deferred(floor_body)
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = FB.environment({"fog": "#1a1430", "ambient": "#4a4060"}, &"high")
	env.environment.fog_density = 0.035
	get_parent().add_child.call_deferred(env)
	var sun: DirectionalLight3D = FB.sun({}, &"high")
	sun.light_energy = 1.2
	get_parent().add_child.call_deferred(sun)
	var cam: Camera3D = Camera3D.new()
	cam.fov = 40.0
	cam.position = Vector3(1.6, 1.6, -3.2)
	cam.ready.connect(_aim_preview_camera.bind(cam), CONNECT_ONE_SHOT)
	get_parent().add_child.call_deferred(cam)


func _aim_preview_camera(cam: Camera3D) -> void:
	cam.look_at(global_position + Vector3(0.0, 0.9, 0.0), Vector3.UP)
	cam.current = true
