extends Node3D
## Puppets of a real-time combat (07 §3.5.6, §6.1, §8.10; R2): every sim-driven unit is shown by a body that follows
## RtSim.units() — the lead of a group by its EnemyActor (puppet mode: no AI, no physics), the AI partner by the
## companion (puppet mode), the extras ("Komparsen") and summons by pooled CharacterRigs without real-time shadows. The
## controlled figure is NOT a puppet (it shows its physics position) unless the sim drives it (autopilot).
## Interpolation: sync() stores the unit poses after every tick (prev ← cur), apply(alpha) places each puppet at
## prev.lerp(cur, alpha) with the yaw over the shorter arc (07 §3.5.6) and drives the locomotion loop from the shown
## speed. Room-local cm → world: origin + (x / 100, 0, z / 100).
## The extra-rig pool is filled invisibly on room entry (prewarm, 07 §8.10 rule 5: no hitch at the combat start);
## invisible rigs cost no draw calls. Private helper of scenes/combat (no class_name).

const FB := preload("res://scenes/exploration/fallback_art.gd")
const POOL_PER_DEF: int = 6
const SPARK_EVERY_SEC: float = 0.2             # 07 §8.10: hit sparks per unit at most every 0.2 s …
const MAX_SPARKS: int = 3                      # … and at most 3 emitters at the same time
const SPARK_SEC: float = 0.3
const LOCO_SMOOTH: float = 12.0
const ENTRY_SMOKE: StringName = &"smoke"

## unit id → {"node": Node3D, "rig": CharacterRig, "kind": &"actor"|&"companion"|&"extra"|&"player"|&"autopilot"
## (&"player" is never moved: the controlled body shows its physics position),
## "prev": Vector3, "cur": Vector3, "prev_yaw": float, "cur_yaw": float, "speed": float, "ko": bool,
## "shown": bool, "spark_t": float, "def_id": String}
var entries: Dictionary = {}
var origin: Vector3 = Vector3.ZERO

var _pool: Dictionary = {}                     # def id → Array[CharacterRig] (invisible, unused)
var _used: Array[CharacterRig] = []            # pool rigs in use this combat
var _anim_t: float = 0.0
var _sparks: Array[float] = []                 # remaining seconds of the running spark emitters
var _fx_root: Node3D = null


func _init() -> void:
	name = "Puppets"


func _ready() -> void:
	_fx_root = Node3D.new()
	_fx_root.name = "Fx"
	add_child(_fx_root)


# --- pool ------------------------------------------------------------------------------------------------------------

## Builds invisible extra rigs for `def_ids` (one per occurrence, up to POOL_PER_DEF free ones per def).
func prewarm(def_ids: PackedStringArray, data: GameData) -> void:
	var want: Dictionary = {}
	for id: String in def_ids:
		want[id] = int(want.get(id, 0)) + 1
	for id: Variant in want.keys():
		var list: Array = _pool.get(id, [])
		while list.size() < mini(int(want[id]), POOL_PER_DEF):
			var r: CharacterRig = _build_rig(_model_of(str(id), data), str(id))
			if r == null:
				break
			list.append(r)
		_pool[id] = list


## Free pooled rigs of `def_id` (tests).
func pooled(def_id: String) -> int:
	return (_pool.get(def_id, []) as Array).size()


func _acquire(def_id: String, model: Dictionary) -> CharacterRig:
	var list: Array = _pool.get(def_id, [])
	var r: CharacterRig = null
	while not list.is_empty() and r == null:
		var c: Variant = list.pop_back()
		if is_instance_valid(c):
			r = c as CharacterRig
	_pool[def_id] = list
	if r == null:
		r = _build_rig(model, def_id)
	if r != null:
		_used.append(r)
		_reset_rig(r)
	return r


func _build_rig(model: Dictionary, def_id: String) -> CharacterRig:
	var m: Dictionary = model if not model.is_empty() else {"base": "blob", "scale": 1.0, "colors": {}}
	var r: CharacterRig = CharacterBuilder.build(m, SeedUtil.derive(7, def_id, 0))
	if r == null:
		r = CharacterRig.new()
	if FB.is_empty(r):
		FB.build_character(m, r)
	r.name = "Extra_" + def_id
	r.set_meta(&"def_id", def_id)
	_no_shadows(r)                             # 07 §8.10: extras and summons cast no real-time shadows
	r.visible = false
	add_child(r)
	return r


static func _model_of(def_id: String, data: GameData) -> Dictionary:
	if data != null and data.has_id("enemies", def_id):
		return data.enemy(def_id).model
	if DB.has_id("enemies", def_id):
		return DB.enemy(def_id).model
	return {}


static func _no_shadows(n: Node) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c: Node in n.get_children():
		_no_shadows(c)


static func _reset_rig(r: CharacterRig) -> void:
	r.set_dissolve(0.0)
	if r.has_method("set_dead"):
		r.set_dead(false)
	r.reset_pose()
	r.rotation = Vector3.ZERO
	r.visible = false


# --- binding ---------------------------------------------------------------------------------------------------------

## The unit `u` is shown by `node` (an EnemyActor, the companion or the player body) with its rig.
func bind(u: RtUnit, node: Node3D, rig: Node3D, kind: StringName) -> void:
	var p: Vector3 = world_of(u)
	entries[u.id] = {"node": node, "rig": rig, "kind": kind, "prev": p, "cur": p, "prev_yaw": yaw_of(u),
		"cur_yaw": yaw_of(u), "speed": 0.0, "ko": u.hp <= 0, "shown": true, "spark_t": 0.0, "def_id": u.def_id}


## An extra / summon: a pooled rig at the unit's position; `pop` = appears with a smoke puff (Komparsen, summons).
func bind_extra(u: RtUnit, pop: bool) -> CharacterRig:
	var r: CharacterRig = _acquire(u.def_id, u.model)
	if r == null:
		return null
	bind(u, r, r, &"extra")
	r.global_position = world_of(u)
	r.rotation.y = yaw_of(u)
	r.visible = true
	if pop:
		Vfx.spawn(ENTRY_SMOKE, _fx_root, r.global_position + Vector3(0.0, 0.4, 0.0))
	return r


func unbind(unit_id: String) -> void:
	entries.erase(unit_id)


func has(unit_id: String) -> bool:
	return entries.has(unit_id)


func node_of(unit_id: String) -> Node3D:
	return (entries.get(unit_id, {}) as Dictionary).get("node", null) as Node3D


func rig_of(unit_id: String) -> Node3D:
	return (entries.get(unit_id, {}) as Dictionary).get("rig", null) as Node3D


## Every pooled rig back into the pool (invisible), every binding dropped (combat end).
func release_all() -> void:
	for r: CharacterRig in _used:
		if not is_instance_valid(r):
			continue
		_reset_rig(r)
		var id: String = str(r.get_meta(&"def_id", ""))
		var list: Array = _pool.get(id, [])
		if list.size() < POOL_PER_DEF:
			list.append(r)
			_pool[id] = list
		else:
			r.queue_free()
	_used.clear()
	entries.clear()
	_sparks.clear()


# --- poses -----------------------------------------------------------------------------------------------------------

func world_of(u: RtUnit) -> Vector3:
	return origin + Vector3(float(u.x) / 100.0, 0.0, float(u.z) / 100.0)


static func yaw_of(u: RtUnit) -> float:
	return float(u.yaw) * TAU / 256.0


## After a tick: prev ← cur, cur ← the sim pose (bound units only); new KOs are flagged (the events animate them).
func sync(units: Array[RtUnit]) -> void:
	for u: RtUnit in units:
		if not entries.has(u.id):
			continue
		var e: Dictionary = entries[u.id]
		e["prev"] = e["cur"]
		e["prev_yaw"] = e["cur_yaw"]
		e["cur"] = world_of(u)
		e["cur_yaw"] = yaw_of(u)


## The puppet of `unit_id` glides from `from` (its world position before the combat) to its sim pose within `sec`
## (07 §3.5.5: a party unit the sim put on the ring at ct 0 glides there in 0.3 s instead of jumping).
func glide_in(unit_id: String, from: Vector3, sec: float) -> void:
	var e: Dictionary = entries.get(unit_id, {})
	if e.is_empty() or sec <= 0.0 or e["kind"] == &"player":
		return
	var to: Vector3 = e["cur"]
	if Vector2(from.x - to.x, from.z - to.z).length() < 0.05:
		return
	e["glide_from"] = from
	e["glide_left"] = sec
	e["glide_sec"] = sec


## Snap every puppet to its current sim pose (no interpolation: start, control switch).
func snap() -> void:
	for id: Variant in entries.keys():
		var e: Dictionary = entries[id]
		e["prev"] = e["cur"]
		e["prev_yaw"] = e["cur_yaw"]
	apply(1.0, 0.0)


## Per frame: places every puppet at the interpolated pose (alpha = fraction of the next tick) and animates its
## locomotion; the controlled body (kind &"player") is left alone (it shows its physics position).
func apply(alpha: float, delta: float) -> void:
	_anim_t += delta
	var a: float = clampf(alpha, 0.0, 1.0)
	for id: Variant in entries.keys():
		var e: Dictionary = entries[id]
		var node: Node3D = e["node"] as Node3D
		if node == null or not is_instance_valid(node):
			continue
		if e["kind"] == &"player":
			continue                           # the controlled figure shows its physics position (07 §3.5.6)
		var p: Vector3 = (e["prev"] as Vector3).lerp(e["cur"] as Vector3, a)
		if float(e.get("glide_left", 0.0)) > 0.0:
			var k: float = 1.0 - float(e["glide_left"]) / float(e["glide_sec"])
			p = (e["glide_from"] as Vector3).lerp(p, k * k * (3.0 - 2.0 * k))
			e["glide_left"] = float(e["glide_left"]) - delta
		var before: Vector3 = node.global_position if node.is_inside_tree() else node.position
		p.y = before.y if e["kind"] != &"extra" else origin.y
		if node.is_inside_tree():
			node.global_position = p
		else:
			node.position = p
		node.rotation.y = lerp_angle(float(e["prev_yaw"]), float(e["cur_yaw"]), a)
		if delta > 0.0:
			var v: float = Vector2(p.x - before.x, p.z - before.z).length() / delta
			e["speed"] = lerpf(float(e["speed"]), minf(v, 8.0), 1.0 - exp(-LOCO_SMOOTH * delta))
			e["spark_t"] = maxf(0.0, float(e["spark_t"]) - delta)
		var rig: Node3D = e["rig"] as Node3D
		if rig != null and is_instance_valid(rig) and not bool(e["ko"]):
			if rig.has_method("set_locomotion"):
				rig.call("set_locomotion", float(e["speed"]))
			FB.animate_character(rig, _anim_t, float(e["speed"]))
	var i: int = _sparks.size() - 1
	while i >= 0:
		_sparks[i] -= delta
		if _sparks[i] <= 0.0:
			_sparks.remove_at(i)
		i -= 1


## World position of a bound unit (interpolated as shown); Vector3.INF if unknown.
func position_of(unit_id: String) -> Vector3:
	var e: Dictionary = entries.get(unit_id, {})
	var node: Node3D = e.get("node", null) as Node3D
	if node == null or not is_instance_valid(node):
		return Vector3.INF
	return node.global_position if node.is_inside_tree() else node.position


## Sim pose of a bound unit after the last sync (tests: puppets = sim positions).
func target_of(unit_id: String) -> Vector3:
	return (entries.get(unit_id, {}) as Dictionary).get("cur", Vector3.INF)


# --- reactions --------------------------------------------------------------------------------------------------------

## One-shot animation of a bound unit's rig (attack, cast, stunt, item, hit).
func play(unit_id: String, anim: StringName) -> void:
	var e: Dictionary = entries.get(unit_id, {})
	var rig: Node3D = e.get("rig", null) as Node3D
	if rig == null or not is_instance_valid(rig) or bool(e.get("ko", false)):
		return
	if rig.has_method("play"):
		rig.call("play", anim, 1.0)


## A hit on `unit_id`: hit animation + a pooled spark (rate-limited per unit, at most MAX_SPARKS emitters).
func hit(unit_id: String, crit: bool) -> void:
	var e: Dictionary = entries.get(unit_id, {})
	if e.is_empty() or bool(e["ko"]):
		return
	play(unit_id, &"hit")
	if float(e["spark_t"]) > 0.0 or _sparks.size() >= MAX_SPARKS:
		return
	e["spark_t"] = SPARK_EVERY_SEC
	_sparks.append(SPARK_SEC)
	var rig: Node3D = e["rig"] as Node3D
	var h: float = float(rig.get("height")) if rig != null and "height" in rig else 1.0
	Vfx.spawn(&"crit" if crit else &"hit", _fx_root, position_of(unit_id) + Vector3(0.0, h * 0.6, 0.0))


## K.O.: party figures fall, enemies sink and dissolve (07 §6.1).
func knock_out(unit_id: String, enemy: bool) -> void:
	var e: Dictionary = entries.get(unit_id, {})
	if e.is_empty() or bool(e["ko"]):
		return
	e["ko"] = true
	var rig: Node3D = e["rig"] as Node3D
	if rig == null or not is_instance_valid(rig):
		return
	if enemy and "death_style" in rig:
		rig.set("death_style", &"dissolve")
	if rig.has_method("set_locomotion"):
		rig.call("set_locomotion", 0.0)
	if rig.has_method("play"):
		rig.call("play", &"die", 1.0)


## The figure lies K.O. (a rebuilt rig after the control switch, 07 §2.6), whatever its flag says.
func lie_down(unit_id: String) -> void:
	var e: Dictionary = entries.get(unit_id, {})
	if e.is_empty():
		return
	e["ko"] = false
	knock_out(unit_id, false)


## Revived: the figure stands up again.
func revive(unit_id: String) -> void:
	var e: Dictionary = entries.get(unit_id, {})
	if e.is_empty():
		return
	e["ko"] = false
	var rig: Node3D = e["rig"] as Node3D
	if rig != null and is_instance_valid(rig):
		if rig.has_method("set_dead"):
			rig.call("set_dead", false)
		if rig.has_method("set_dissolve"):
			rig.call("set_dissolve", 0.0)
		if rig.has_method("reset_pose"):
			rig.call("reset_pose")


func is_ko(unit_id: String) -> bool:
	return bool((entries.get(unit_id, {}) as Dictionary).get("ko", false))


## Running spark emitters (07 §8.10 cap).
func spark_count() -> int:
	return _sparks.size()
