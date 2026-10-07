extends CharacterBody3D
## Visible enemy group on the map (02_TECH §7.3, GDD §2.3): one symbol per encounter, model = lead enemy, shadow pips
## above the head show the group size (1–4). States IDLE / PATROL / ALERT / CHASE / RETURN; perception = sight cone
## with a line-of-sight raycast (layer `world`) + 360° hearing (hear_run / hear_sneak); give-up after
## giveup_no_sight s without sight, > leash m from the leash point or max_chase s → RETURN (3 m/s, ignores Kai 2 s).
## Contact ≤ 1.1 m → ExplorationScene.on_enemy_contact (advantage by encounter_rules). Bosses stand at boss_spot and
## fight when Kai comes within 5 m (always NORMAL). Layer 3 `enemy`, mask `world`.
## Standalone (scene root, capture of enemy_actor.tscn) it shows the first enemy of the data on a preview stage.

signal state_changed(group_id: String, state: StringName)

const Rules := preload("res://scenes/exploration/encounter_rules.gd")
const FB := preload("res://scenes/exploration/fallback_art.gd")
const IDLE: StringName = &"IDLE"
const PATROL: StringName = &"PATROL"
const ALERT: StringName = &"ALERT"
const CHASE: StringName = &"CHASE"
const RETURN: StringName = &"RETURN"
const IDLE_TURN_SEC: float = 4.0
const IDLE_TURN_DEG: float = 60.0
const ALERT_SEC: float = 0.6
const RETURN_SPEED: float = 3.0
const RETURN_IGNORE_SEC: float = 2.0
const PATROL_RADIUS: float = 4.0
const WAYPOINT_EPS: float = 0.3
const HOME_EPS: float = 0.35
const TURN_RATE: float = 6.0
const GRAVITY: float = 20.0
const EYE_HEIGHT: float = 1.0

var spawn: EnemySpawn = null
var explore: Dictionary = {}
var state: StringName = IDLE
var home: Vector3 = Vector3.ZERO      # spawn position = leash point
var base_yaw: float = 0.0
var waypoints_world: Array[Vector3] = []
var player: Node3D = null             # player body (player_controller.gd)
var scene: Node = null                # ExplorationScene (duck-typed: on_enemy_contact)
var frozen: bool = false              # dialogs / pending encounter / suspended
var group_size: int = 1
var rig: Node3D = null

var _state_t: float = 0.0
var _no_sight_t: float = 0.0
var _chase_t: float = 0.0
var _turn_step: int = 0
var _target_yaw: float = 0.0
var _wp_index: int = 0
var _circle_angle: float = 0.0
var _anim_t: float = 0.0
var _bubble: Label3D = null
var _zz: Label3D = null
var _zz_base_y: float = 0.0
var _preview: bool = false


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	if spawn == null and get_parent() == get_tree().root:
		_build_preview()


## Configures the group. `world_home` = room centre + offset; waypoints room-local → world via `room_center`.
func setup_spawn(p_spawn: EnemySpawn, world_home: Vector3, room_center: Vector3, def: EnemyDef, p_group_size: int,
		p_player: Node3D, p_scene: Node) -> void:
	spawn = p_spawn
	name = "Enemy_" + p_spawn.id
	explore = Rules.explore_params(def)
	home = world_home
	player = p_player
	scene = p_scene
	group_size = clampi(p_group_size, 1, 4)
	waypoints_world.clear()
	for w: Vector2 in p_spawn.waypoints:
		waypoints_world.append(room_center + Vector3(w.x, 0.0, w.y))
	base_yaw = 0.0
	position = home
	rotation = Vector3(0.0, base_yaw, 0.0)
	_target_yaw = base_yaw
	_circle_angle = 0.0
	_build_visual(def)
	_set_state(IDLE if p_spawn.is_boss else p_spawn.start_state)


## Faces `yaw` at once (bosses face the entrance, idle groups their data direction).
func face(yaw: float) -> void:
	base_yaw = yaw
	_target_yaw = yaw
	rotation.y = yaw


func is_boss() -> bool:
	return spawn != null and spawn.is_boss


func group_id() -> String:
	return spawn.id if spawn != null else ""


func encounter_id() -> String:
	return spawn.encounter_id if spawn != null else ""


func flat_forward() -> Vector3:
	return Rules.flat_forward(global_transform.basis)


## IDLE group that never turns (tutorial rats, GDD §1.4 B1 "schlafend"): it never notices Kai, so the first fight
## always lets Kai strike first or touch it from behind.
func is_asleep() -> bool:
	return spawn != null and not spawn.can_turn and spawn.start_state == IDLE and state == IDLE


## Can this group ever start an ambush (it has to be able to move)?
func can_ambush() -> bool:
	return float(explore.get("field_speed", 0.0)) > 0.0


## Battle over / flight: go back to the leash point (ignores Kai for 2 s).
func force_return() -> void:
	if is_boss():
		return
	_set_state(RETURN)


func _physics_process(delta: float) -> void:
	_anim_t += delta
	if spawn == null or _preview:
		return
	if frozen:
		velocity = Vector3.ZERO
		_animate(0.0)
		return
	_state_t += delta
	var kai: Vector3 = player.global_position if player != null and is_instance_valid(player) else Vector3(INF, 0, INF)
	var hidden: bool = player == null or not is_instance_valid(player) or \
		(player.has_method("is_hidden") and bool(player.call("is_hidden")))
	if is_boss():
		_boss_tick(kai, hidden)
		_animate(0.0)
		return
	var move: Vector3 = Vector3.ZERO
	match state:
		IDLE:
			if spawn.can_turn and _state_t >= IDLE_TURN_SEC:
				_state_t = 0.0
				_turn_step = (_turn_step + 1) % 4
				var offsets: Array[float] = [IDLE_TURN_DEG, 0.0, -IDLE_TURN_DEG, 0.0]
				_target_yaw = base_yaw + deg_to_rad(offsets[(_turn_step + 3) % 4])
			_turn_towards(_target_yaw, delta, 3.0)
			if not hidden and not is_asleep() and _perceives(kai):
				_set_state(ALERT)
		PATROL:
			move = _patrol_velocity(delta)
			if not hidden and _perceives(kai):
				_set_state(ALERT)
		ALERT:
			if spawn.can_turn and not hidden:
				_turn_towards(Rules.yaw_of(Rules.flat_dir(global_position, kai)), delta, 10.0)
			if _state_t >= ALERT_SEC:
				_set_state(CHASE)
		CHASE:
			_chase_t += delta
			# Same sight as when idle (§7.3: cone sight_range / sight_angle_deg + raycast); the group turns towards Kai
			# while chasing, so the cone keeps covering him as long as he does not break line of sight.
			var sees: bool = not hidden and _sees(kai)
			_no_sight_t = 0.0 if sees else _no_sight_t + delta
			if Rules.should_give_up(_no_sight_t, Rules.flat_dist(global_position, home), _chase_t, explore):
				_set_state(RETURN)
			elif not hidden:
				var dir: Vector3 = Rules.flat_dir(global_position, kai)
				move = dir * float(explore["field_speed"])
				if dir != Vector3.ZERO:
					_turn_towards(Rules.yaw_of(dir), delta, 12.0)
		RETURN:
			var to_home: Vector3 = Vector3(home.x - global_position.x, 0.0, home.z - global_position.z)
			if to_home.length() <= HOME_EPS:
				global_position = Vector3(home.x, global_position.y, home.z)
				_set_state(spawn.start_state)
				_target_yaw = base_yaw
			else:
				var d: Vector3 = to_home.normalized()
				move = d * minf(RETURN_SPEED, to_home.length() / maxf(delta, 0.0001))
				_turn_towards(Rules.yaw_of(d), delta, 8.0)
				if _state_t >= RETURN_IGNORE_SEC and not hidden and _perceives(kai):
					_set_state(ALERT)
	velocity.x = move.x
	velocity.z = move.z
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	_animate(Vector2(velocity.x, velocity.z).length())
	if not hidden and Rules.flat_dist(global_position, kai) <= Rules.CONTACT_RADIUS:
		_contact()


func _boss_tick(kai: Vector3, hidden: bool) -> void:
	if hidden:
		return
	if Rules.flat_dist(home, kai) <= Rules.BOSS_TRIGGER_RADIUS:
		_contact()


func _contact() -> void:
	if scene != null and scene.has_method("on_enemy_contact"):
		scene.call("on_enemy_contact", self)


## Sight cone (sight_range / sight_angle_deg + raycast) or hearing (360°).
func _perceives(kai: Vector3) -> bool:
	var dist: float = Rules.flat_dist(global_position, kai)
	var moving: bool = player.has_method("is_moving") and bool(player.call("is_moving"))
	var sneaking: bool = player.has_method("is_sneaking") and bool(player.call("is_sneaking"))
	var hear: float = Rules.hearing_radius(explore, moving, sneaking)
	if hear > 0.0 and dist <= hear:
		return true
	return _sees(kai)


## Sight only: inside the cone (sight_range / sight_angle_deg) and an unblocked ray (layer `world`).
func _sees(kai: Vector3) -> bool:
	var rng: float = float(explore["sight_range"])
	if not Rules.in_sight_cone(global_position, flat_forward(), kai, rng, float(explore["sight_angle_deg"])):
		return false
	return _has_line_of_sight(kai, rng)


func _has_line_of_sight(kai: Vector3, max_dist: float) -> bool:
	if max_dist <= 0.0 or Rules.flat_dist(global_position, kai) > max_dist or not is_inside_tree():
		return false
	var from: Vector3 = global_position + Vector3(0.0, EYE_HEIGHT, 0.0)
	var to: Vector3 = kai + Vector3(0.0, EYE_HEIGHT, 0.0)
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _patrol_velocity(delta: float) -> Vector3:
	var speed: float = float(explore.get("patrol_speed", 1.8))
	if speed <= 0.0:
		return Vector3.ZERO
	var target: Vector3
	if waypoints_world.is_empty():
		# Circle r 4 m around the spawn, clockwise seen from above.
		_circle_angle += speed / PATROL_RADIUS * delta
		target = home + Vector3(sin(_circle_angle), 0.0, -cos(_circle_angle)) * PATROL_RADIUS
	else:
		target = waypoints_world[_wp_index % waypoints_world.size()]
		if Rules.flat_dist(global_position, target) <= WAYPOINT_EPS:
			_wp_index = (_wp_index + 1) % waypoints_world.size()
			target = waypoints_world[_wp_index]
	var to: Vector3 = Vector3(target.x - global_position.x, 0.0, target.z - global_position.z)
	if to.length() < 0.01:
		return Vector3.ZERO
	var d: Vector3 = to.normalized()
	_turn_towards(Rules.yaw_of(d), delta, TURN_RATE)
	return d * minf(speed, to.length() / maxf(delta, 0.0001))


func _turn_towards(yaw: float, delta: float, rate: float) -> void:
	var diff: float = wrapf(yaw - rotation.y, -PI, PI)
	rotation.y += clampf(diff, -rate * delta, rate * delta)


func _set_state(s: StringName) -> void:
	if s == state and _state_t > 0.0:
		return
	var prev: StringName = state
	state = s
	_state_t = 0.0
	if s == CHASE:
		_chase_t = 0.0
		_no_sight_t = 0.0
	if s == PATROL and prev != PATROL:
		_wp_index = _nearest_waypoint()
		_circle_angle = _angle_on_circle()
	if _bubble != null:
		_bubble.visible = s == ALERT or s == CHASE
		_bubble.text = "!" if s == ALERT else "!!"
	_update_zz()
	if s == ALERT:
		Events.enemy_alerted.emit(group_id())
	if spawn != null:
		state_changed.emit(group_id(), s)


## Position in world space (the actor may still be outside the tree right after setup_spawn: parent at the origin).
func _world_pos() -> Vector3:
	return global_position if is_inside_tree() else position


func _nearest_waypoint() -> int:
	var best: int = 0
	var best_d: float = INF
	for i in waypoints_world.size():
		var d: float = Rules.flat_dist(_world_pos(), waypoints_world[i])
		if d < best_d:
			best_d = d
			best = i
	return best


func _angle_on_circle() -> float:
	var rel: Vector3 = _world_pos() - home
	if Vector2(rel.x, rel.z).length() < 0.1:
		return 0.0
	return atan2(rel.x, -rel.z)


func _animate(speed: float) -> void:
	_update_zz()
	if rig == null:
		return
	if rig.has_method("set_locomotion"):
		rig.call("set_locomotion", speed)
	FB.animate_character(rig, _anim_t, speed)


## "Z z" only while asleep (hidden from ALERT on); slow bob.
func _update_zz() -> void:
	if _zz == null:
		return
	_zz.visible = is_asleep()
	if _zz.visible:
		_zz.position.y = _zz_base_y + sin(_anim_t * 1.6) * 0.08


func _build_visual(def: EnemyDef) -> void:
	var model: Dictionary = def.model if def != null else {"base": "blob", "scale": 1.0, "colors": {}}
	var r: CharacterRig = CharacterBuilder.build(model, SeedUtil.derive(1, spawn.id if spawn != null else "", 0))
	if r == null:
		r = CharacterRig.new()
	if FB.is_empty(r):
		FB.build_character(model, r)
	r.name = "Rig"
	add_child(r)
	rig = r
	var top: float = maxf(0.6, float(r.get("height")) if "height" in r else 1.0)
	if get_node_or_null("Collision") == null:
		var cs: CollisionShape3D = CollisionShape3D.new()
		cs.name = "Collision"
		var cap: CapsuleShape3D = CapsuleShape3D.new()
		cap.radius = 0.45
		cap.height = clampf(top, 0.9, 2.4)
		cs.shape = cap
		cs.position = Vector3(0.0, cap.height * 0.5, 0.0)
		add_child(cs)
	# Group size pips (GDD §2.3: small shadow icons above the head): INK discs with a PAPER rim (bosses DANGER) on a
	# camera-facing INK plate, drawn over everything — readable on every zone palette.
	var pips: MeshInstance3D = FB.build_pips(group_size, is_boss())
	pips.name = "GroupPips"
	pips.position = Vector3(0.0, top + 0.35, 0.0)
	add_child(pips)
	_bubble = Label3D.new()
	_bubble.name = "AlertBubble"
	_bubble.text = "!"
	_bubble.font_size = 96
	_bubble.outline_size = 18
	_bubble.modulate = Color("#ffc93c")
	_bubble.outline_modulate = Color("#140d1c")
	_bubble.pixel_size = 0.006
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.no_depth_test = true
	_bubble.position = Vector3(0.0, top + 0.8, 0.0)
	_bubble.visible = false
	add_child(_bubble)
	# Sleeping groups (tutorial rats, GDD B1): a slow "Z z" so the player learns to sneak up and strike first.
	_zz = Label3D.new()
	_zz.name = "SleepZz"
	_zz.text = "Z z"
	_zz.font_size = 64
	_zz.outline_size = 12
	_zz.modulate = Color(FB.PAPER, 0.5)
	_zz.outline_modulate = Color(FB.INK, 0.5)
	_zz.pixel_size = 0.006
	_zz.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_zz.position = Vector3(0.15, top + 0.75, 0.0)
	_zz_base_y = _zz.position.y
	add_child(_zz)
	_update_zz()


## Standalone preview (capture of enemy_actor.tscn): first enemy of the data in ALERT pose on a small stage.
func _build_preview() -> void:
	_preview = true
	var def: EnemyDef = null
	var all: Array[EnemyDef] = DB.data.all_enemies() if DB.data != null else []
	if not all.is_empty():
		def = all[0]
	var s: EnemySpawn = EnemySpawn.new()
	s.id = "preview"
	s.lead_enemy_id = def.id if def != null else ""
	s.start_state = IDLE
	spawn = s
	group_size = 3
	explore = Rules.explore_params(def)
	_build_visual(def)
	_bubble.visible = true
	rotation.y = -0.6
	var stage: StaticBody3D = StaticBody3D.new()
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(6.0, 0.2, 6.0)
	mi.mesh = bm
	mi.material_override = FB.toon(Color("#24302c"), false)
	mi.position = Vector3(0.0, -0.1, 0.0)
	stage.add_child(mi)
	get_parent().add_child.call_deferred(stage)
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = FB.environment({"fog": "#12302a", "ambient": "#3e5a50"}, &"high")
	env.environment.fog_density = 0.035
	get_parent().add_child.call_deferred(env)
	var sun: DirectionalLight3D = FB.sun({}, &"high")
	sun.light_energy = 1.2
	get_parent().add_child.call_deferred(sun)
	var cam: Camera3D = Camera3D.new()
	cam.fov = 40.0
	cam.position = Vector3(0.0, 1.6, -3.4)
	cam.ready.connect(_aim_preview_camera.bind(cam), CONNECT_ONE_SHOT)
	get_parent().add_child.call_deferred(cam)


func _aim_preview_camera(cam: Camera3D) -> void:
	cam.look_at(global_position + Vector3(0.0, 0.5, 0.0), Vector3.UP)
	cam.current = true
