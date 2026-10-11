extends CharacterBody3D
## The controlled character in the exploration (02_TECH §7.3, GDD §2.1; 06 §1.2): Kai (capsule r 0.4 / h 1.7) or —
## when GameState.hero is "mopsula" — Graf Mopsula (capsule r 0.35 / h 0.9); layer 2 `player`, mask 1 `world`,
## run 5.5 m/s, sneak 2.5 m/s (action `sneak` held; touch: stick deflection ≤ 0.6 holds sneak), accel 30 m/s²,
## decel 40 m/s², turn 12 rad/s towards the move direction, gravity 20 m/s², no jump — identical for both heroes.
## Movement is camera relative (Input.get_vector of the move_* actions: keyboard, gamepad and touch alike; the
## deflection only sets the direction).
## `action` (one key) → signal action_requested; the ExplorationScene decides between interact (focused interactable)
## and the hero's field ability (start_field_ability): Kai's field strike (start_strike: arc 100°, reach 1.8 m, 0.45 s,
## cooldown 0.6 s) or Mopsula's bark (start_bark: cone 120°, 4 m, 0.4 s, cooldown 3 s; 06 §1.3). Reach and cooldown
## carry the leader's field talents (field_range_pm / field_cd_pm, set by the scene from HeroRules.field_mods).
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
# --- 06 package A: hero bodies and the bark FX ---------------------------------------------------------------------
const MOPSULA_RADIUS: float = 0.35
const MOPSULA_HEIGHT: float = 0.9
const BARK_COLOR: Color = Color("#c79bff")    # Mopsula violet (03_ART: bark FX)
const BARK_CONE_SEC: float = 0.18             # the violet cone flashes this long, the sound rings run BARK_DURATION
const BARK_HEIGHT: float = 0.45

var input_enabled: bool = true
var camera_yaw: float = 0.0          # set by the scene from the camera rig every frame
var grace_left: float = 0.0          # > 0: unhittable + invisible for enemies (after a battle / flight)
var rig: Node3D = null
var hero_id: String = "kai"          # 06 package A: whose body / field ability this is (set_hero)
var field_range_pm: int = 1000       # field ability reach factor (06 §2.2 talents, package B) — 1000 = neutral
var field_cd_pm: int = 1000          # field ability cooldown factor (06 §2.2 talents, package B)

var _strike_t: float = -1.0          # time since the strike started (−1 = not striking)
var _bark_t: float = -1.0            # time since the bark started (−1 = not barking)
var _bark_fx: Node3D = null          # violet cone + 2 sound-wave rings (06 §1.3)
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
		add_child(cs)
	_apply_capsule()
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


## Marker used by interactable areas to recognise the controlled character.
func is_player_body() -> bool:
	return true


## 06 package A: becomes `id`'s body ("kai" | "mopsula"): rig, capsule and field ability. Safe before and after
## _ready (the scene calls it on spawn and after a switch in the safe room).
func set_hero(id: String) -> void:
	var clean: String = HeroRules.sanitize(id)
	if clean == hero_id and rig != null:
		return
	hero_id = clean
	_strike_t = -1.0
	_bark_t = -1.0
	_cooldown = 0.0
	if not is_inside_tree():
		return
	_apply_capsule()
	if rig != null and is_instance_valid(rig):
		rig.get_parent().remove_child(rig)
		rig.queue_free()
		rig = null
	_build_rig()


## &"strike" (Kai) | &"bark" (Graf Mopsula).
func field_ability() -> StringName:
	return HeroRules.field_ability(hero_id)


## Starts the hero's field ability (false while cooling down / already running).
func start_field_ability() -> bool:
	return start_bark() if field_ability() == &"bark" else start_strike()


func field_ready() -> bool:
	return bark_ready() if field_ability() == &"bark" else strike_ready()


func _capsule_size() -> Vector2:
	return Vector2(MOPSULA_RADIUS, MOPSULA_HEIGHT) if hero_id == "mopsula" else Vector2(CAPSULE_RADIUS, CAPSULE_HEIGHT)


## A fresh shape per body (player.tscn's sub-resource is shared between instances).
func _apply_capsule() -> void:
	var cs: CollisionShape3D = get_node_or_null("Collision") as CollisionShape3D
	if cs == null:
		return
	var size: Vector2 = _capsule_size()
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = size.x
	cap.height = size.y
	cs.shape = cap
	cs.position = Vector3(0.0, size.y * 0.5, 0.0)


func _build_rig() -> void:
	var model: Dictionary = {"base": "humanoid", "scale": 1.0, "colors": {"primary": "#3aa9a0", "secondary": "#2e3a57",
		"accent": "#3b2a22", "skin": "#e8b48f", "eyes": "#1a1420"}}
	if hero_id == "mopsula":
		model = {"base": "pug", "scale": 1.0, "colors": {"primary": "#d8b98a", "secondary": "#2a2024",
			"accent": "#7b2cbf", "eyes": "#1a1420"}}
	if DB.has_id("party", hero_id):
		model = DB.party_member(hero_id).model
	var r: CharacterRig = CharacterBuilder.build(model, 2 if hero_id == "mopsula" else 1)
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
	_update_bark(delta)
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
	# Router.busy: the screen is still fading in (back from a battle / safe room) or out — `action` shares Enter/Space
	# with ui_accept, so presses that skipped the results must not reach Kai (02_TECH §10: no exploration input then).
	if not input_enabled or _standalone or Router.busy:
		return
	if event.is_action_pressed(&"action") and not event.is_echo():
		get_viewport().set_input_as_handled()
		action_requested.emit()


## Starts a field strike (false while cooling down / already striking).
func start_strike() -> bool:
	if _cooldown > 0.0 or _strike_t >= 0.0:
		return false
	_strike_t = 0.0
	_cooldown = Rules.field_cooldown(&"strike", field_cd_pm)
	if _arc != null:                     # the gold swoosh shows the reach (Weit ausholen: a quarter wider)
		var k: float = strike_reach() / Rules.STRIKE_RANGE
		_arc.scale = Vector3(k, 1.0, k)
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


# --- 06 package A: bark ---------------------------------------------------------------------------------------------

## Starts Graf Mopsula's bark (false while cooling down / already barking). The scene dazes the groups in the cone
## right away (bark_reach(), Rules.bark_hits + line of sight); the FX run for BARK_DURATION.
func start_bark() -> bool:
	if _cooldown > 0.0 or _bark_t >= 0.0:
		return false
	_bark_t = 0.0
	_cooldown = Rules.field_cooldown(&"bark", field_cd_pm)
	Sfx.play(&"bark")
	if rig != null and rig.has_method("play"):
		rig.call("play", &"attack", 1.0)
	_ensure_bark_fx()
	_update_bark(0.0)
	return true


func is_barking() -> bool:
	return _bark_t >= 0.0


func bark_ready() -> bool:
	return _cooldown <= 0.0 and _bark_t < 0.0


## Bark reach in m (Rules.bark_reach: BARK_RANGE × field_range_pm, integer per-mille).
func bark_reach() -> float:
	return Rules.bark_reach(field_range_pm)


## Field strike reach in m (Rules.strike_reach: STRIKE_RANGE × field_range_pm, integer per-mille).
func strike_reach() -> float:
	return Rules.strike_reach(field_range_pm)


## 06 packages A × B: the leader's field talents ({"range_pm", "cd_pm"} of HeroRules.field_mods). A running cooldown
## keeps its length; the next use takes the new factor.
func set_field_mods(mods: Dictionary) -> void:
	field_range_pm = int(mods.get("range_pm", 1000))
	field_cd_pm = int(mods.get("cd_pm", 1000))


## Seconds until the field ability is ready again.
func cooldown_left() -> float:
	return _cooldown


func _ensure_bark_fx() -> void:
	if _bark_fx != null and is_instance_valid(_bark_fx):
		return
	_bark_fx = Node3D.new()
	_bark_fx.name = "BarkFx"
	_bark_fx.position = Vector3(0.0, BARK_HEIGHT, 0.0)
	add_child(_bark_fx)
	var cone: MeshInstance3D = MeshInstance3D.new()
	cone.name = "Cone"
	cone.mesh = FB.arc_mesh(Rules.BARK_RANGE, 0.4, Rules.BARK_ARC_DEG, 18)
	cone.material_override = FB.beam(BARK_COLOR, 0.35)
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bark_fx.add_child(cone)
	for i in 2:
		var ring: MeshInstance3D = MeshInstance3D.new()
		ring.name = "Ring%d" % i
		ring.mesh = FB.arc_mesh(1.0, 0.86, Rules.BARK_ARC_DEG - 20.0, 18)
		ring.material_override = FB.beam(BARK_COLOR.lightened(0.35), 0.85)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.position.y = 0.12 + 0.1 * i
		_bark_fx.add_child(ring)
	_bark_fx.visible = false


## Cone flash + two sound-wave rings travelling out to the bark reach.
func _update_bark(delta: float) -> void:
	if _bark_t < 0.0:
		return
	_bark_t += delta
	if _bark_t > Rules.BARK_DURATION:
		_bark_t = -1.0
		if _bark_fx != null:
			_bark_fx.visible = false
		return
	if _bark_fx == null:
		return
	_bark_fx.visible = true
	var reach: float = bark_reach()
	_bark_fx.get_node("Cone").set("visible", _bark_t <= BARK_CONE_SEC)
	(_bark_fx.get_node("Cone") as Node3D).scale = Vector3.ONE * (reach / Rules.BARK_RANGE)
	var t: float = clampf(_bark_t / Rules.BARK_DURATION, 0.0, 1.0)
	for i in 2:
		var ring: Node3D = _bark_fx.get_node("Ring%d" % i) as Node3D
		var k: float = clampf(t * 1.25 - 0.25 * i, 0.0, 1.0)
		ring.visible = k > 0.0 and k < 1.0
		ring.scale = Vector3.ONE * maxf(0.05, lerpf(0.6, reach, k))


## True during the hitting part of the swing.
func is_strike_hitting() -> bool:
	return _strike_t >= Rules.STRIKE_HIT_FROM and _strike_t <= Rules.STRIKE_DURATION


## The swing is running (06 package A: the scene reports a strike that hit nothing once it is over).
func is_striking() -> bool:
	return _strike_t >= 0.0


## Kai's field strike can start (field_ready() for Kai; 06 package A).
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
	_bark_t = -1.0
	if _bark_fx != null:
		_bark_fx.visible = false


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
