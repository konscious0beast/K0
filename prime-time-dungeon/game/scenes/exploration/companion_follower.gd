extends CharacterBody3D
## Graf Mopsula follows Kai's trail (02_TECH §7.3) without the NavigationServer: a ring buffer of Kai's positions
## (one point every 0.25 m, 64 points); Mopsula walks along it 1.8 m of arc length behind Kai via move_and_slide()
## at Kai's speed: his current speed, at least MIN_SPEED to close a gap while he stands, never faster than his run speed
## (5.5 m/s). Distance > 10 m, spawn and on_resume → teleport onto the trail point or 1.8 m behind Kai.
## Collision layer 0 (never blocks Kai, never triggers anything), mask `world`. No battle trigger.

const FB := preload("res://scenes/exploration/fallback_art.gd")
const Rules := preload("res://scenes/exploration/encounter_rules.gd")
const TRAIL_STEP: float = 0.25
const TRAIL_SIZE: int = 64
const FOLLOW_DIST: float = 1.8
const TELEPORT_DIST: float = 10.0
const MIN_SPEED: float = 2.0
const MAX_SPEED: float = 5.5          # Kai's run speed (player RUN_SPEED; §7.3 "mit Spielergeschwindigkeit")
const GRAVITY: float = 20.0
const TURN_RATE: float = 10.0

var leader: Node3D = null
var rig: Node3D = null
var frozen: bool = false

var _trail: Array[Vector3] = []      # oldest first, newest last
var _anim_t: float = 0.0


func _ready() -> void:
	name = "Mopsula"
	collision_layer = 0
	collision_mask = 1
	if get_node_or_null("Collision") == null:
		var cs: CollisionShape3D = CollisionShape3D.new()
		cs.name = "Collision"
		var cap: CapsuleShape3D = CapsuleShape3D.new()
		cap.radius = 0.25
		cap.height = 0.6
		cs.shape = cap
		cs.position = Vector3(0.0, 0.3, 0.0)
		add_child(cs)
	if rig == null:
		var model: Dictionary = {"base": "pug", "scale": 1.0, "colors": {"primary": "#c9a57a", "secondary": "#3b2a22",
			"accent": "#7a1f3a", "eyes": "#1a1420"}}
		if DB.has_id("party", "mopsula"):
			model = DB.party_member("mopsula").model
		var r: CharacterRig = CharacterBuilder.build(model, 2)
		if r == null:
			r = CharacterRig.new()
		if FB.is_empty(r):
			FB.build_character(model, r)
		r.name = "Rig"
		add_child(r)
		rig = r


## Clears the trail and places Mopsula 1.8 m behind the leader (spawn, on_resume, too far away).
func snap_behind() -> void:
	if leader == null:
		return
	var back: Vector3 = -Rules.flat_forward(leader.global_transform.basis)
	var pos: Vector3 = leader.global_position + back * FOLLOW_DIST
	if is_inside_tree():
		pos = _safe_spot(leader.global_position, pos)
	global_position = pos
	rotation = Vector3(0.0, leader.rotation.y, 0.0)
	velocity = Vector3.ZERO
	_trail.clear()
	_trail.append(pos)
	_trail.append(leader.global_position)


## Trail point FOLLOW_DIST of arc length behind the leader (walking back along the trail).
func trail_target() -> Vector3:
	if leader == null:
		return global_position
	var remaining: float = FOLLOW_DIST
	var prev: Vector3 = leader.global_position
	for i in range(_trail.size() - 1, -1, -1):
		var p: Vector3 = _trail[i]
		var seg: float = prev.distance_to(p)
		if seg >= remaining and seg > 0.0001:
			return prev.lerp(p, remaining / seg)
		remaining -= seg
		prev = p
	return prev


func _physics_process(delta: float) -> void:
	_anim_t += delta
	if leader == null or not is_instance_valid(leader):
		return
	_record_trail()
	var lead_dist: float = Rules.flat_dist(global_position, leader.global_position)
	if lead_dist > TELEPORT_DIST:
		var tgt: Vector3 = trail_target()
		global_position = _safe_spot(leader.global_position, tgt)
		velocity = Vector3.ZERO
	var horizontal: Vector3 = Vector3.ZERO
	if not frozen:
		var target: Vector3 = trail_target()
		var to: Vector3 = Vector3(target.x - global_position.x, 0.0, target.z - global_position.z)
		var dist: float = to.length()
		if dist > 0.12 and lead_dist > FOLLOW_DIST * 0.6:
			var lead_speed: float = 0.0
			if leader is CharacterBody3D:
				var lv: Vector3 = (leader as CharacterBody3D).velocity
				lead_speed = Vector2(lv.x, lv.z).length()
			var speed: float = clampf(maxf(lead_speed, dist * 3.0), MIN_SPEED, MAX_SPEED)
			horizontal = to.normalized() * minf(speed, dist / maxf(delta, 0.0001))
			var diff: float = wrapf(Rules.yaw_of(to) - rotation.y, -PI, PI)
			rotation.y += clampf(diff, -TURN_RATE * delta, TURN_RATE * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	var speed_now: float = Vector2(velocity.x, velocity.z).length()
	if rig != null:
		if rig.has_method("set_locomotion"):
			rig.call("set_locomotion", speed_now)
		FB.animate_character(rig, _anim_t, speed_now)


func _record_trail() -> void:
	var p: Vector3 = leader.global_position
	if _trail.is_empty() or _trail[_trail.size() - 1].distance_to(p) >= TRAIL_STEP:
		_trail.append(p)
		while _trail.size() > TRAIL_SIZE:
			_trail.pop_front()


## Keeps a teleport target out of walls: if the straight line from the leader is blocked, stand next to the leader.
func _safe_spot(from: Vector3, to: Vector3) -> Vector3:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from + Vector3(0.0, 0.4, 0.0),
		to + Vector3(0.0, 0.4, 0.0), 1)
	var hit: Dictionary = space.intersect_ray(q)
	if hit.is_empty():
		return to
	var hp: Vector3 = hit["position"]
	var back: Vector3 = Rules.flat_dir(hp, from)
	return Vector3(hp.x, to.y, hp.z) + back * 0.5
