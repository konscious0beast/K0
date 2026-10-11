extends Node3D
## The combat Set of one room cell (07 §2.1, §2.4, §8.7; R2): the LED studio-tape ring on the floor (ONE
## MeshInstance3D, unshaded C_ACCENT_2, gaps in front of the open doors plus tape strips along their door lanes), the
## invisible collision ring (ONE StaticBody3D on layer `world`: box segments along the ring, the two side walls of every
## door lane, the roll shutters of a closed set) and the roll shutters themselves (ONE mesh, closed sets only: bosses,
## tutorial, can_flee == false). Private helper of scenes/combat (no class_name), built by the CombatDirector from the
## RtGeo geometry ({"r" cm, "doors" bits N 1 E 2 S 4 W 8, "closed"}).
##
## Geometry (room-local, metres; +x east, +z south): ring radius r = geo.r / 100, a door d has its lane where
## |quer_d| ≤ DOOR_HALF (2 m) and längs_d > 0. The collision faces sit COLLIDER_INSET inside the walkable border of
## 07 §3.5.4 (|p| ≤ r − r_u, |quer_d| ≤ DOOR_HALF − r_u for a body of radius r_u), so an honest body never stands on
## a point the sim has to correct (07 §3.5.2: < 5 cm); `body_slack` (≤ 0) moves them further in when a body's capsule
## is thinner than its sim radius (capsule − r_u). The ring lights up in 0.3 s ("Studio-Licht an") and fades out in
## 0.5 s (victory / flight).

const C_RING: Color = Color("#22d3ee")          # 07 §2.4: C_ACCENT_2
const C_CORE: Color = Color("#e8fdff")          # the bright LED core line of the tape
const RING_Y: float = 0.035                     # above every floor mark (≤ 0.029 m), under the telegraphs (0.04 m)
const BAND_W: float = 0.12                      # 07 §8.7: band 12 cm
const LANE_W: float = 0.08                      # tape strips along a door lane
const SEGMENTS: int = 96                        # full circle
const COLLIDER_SEGMENTS: int = 48
const COLLIDER_INSET: float = 0.03              # faces 3 cm inside the walkable border
const COLLIDER_THICK: float = 0.4
const COLLIDER_HEIGHT: float = 1.6
const DOOR_HALF: float = 2.0                    # DOOR_HALF_CM (07 §3.5.4) = EnvKit.DOOR_WIDTH / 2
const WALL_INNER: float = 7.5                   # ROOM_INNER_CM (door in the wall)
const SHUTTER_TOP: float = 3.0                  # door lintel height
const SHUTTER_DEPTH: float = 7.62               # inside the room's own wall (7.5 … 8.0 m)
const SHUTTER_SLATS: int = 10
const LIGHT_UP_SEC: float = 0.3
const FADE_OUT_SEC: float = 0.5
const SHUTTER_SEC: float = 0.3
const DOOR_BITS: PackedInt32Array = [1, 2, 4, 8]   # RoomCell.DOOR_N, E, S, W
const PROP_MAT: Dictionary = {"bands": 3, "rim": 0.45, "outline_width": 0.02}   # == PropKit's toon_vc options

var radius_m: float = 4.8
var gap_doors: int = 0                          # doors with a lane (open set)
var shutter_doors: int = 0                      # doors with a roll shutter (closed set)
var closed: bool = false
var body_slack: float = 0.0                     # m, ≤ 0: capsule radius − sim radius of the thinnest body
var ring: MeshInstance3D = null
var body: StaticBody3D = null
var shutters: Node3D = null                     # pivot at the lintel; its scale.y rolls the shutters down

var _material: StandardMaterial3D = null
var _tween: Tween = null
var _shutter_tween: Tween = null
var _down: bool = false


## Builds the set around the room centre `center` (world). `geo` = RtGeo geometry of the cell; `room_doors` = the
## door openings of the cell that are passable in the exploration (shutters close exactly these in a closed set);
## `slack` = min(0, capsule radius − sim radius) over the bodies the player may control (m).
func build(center: Vector3, geo: Dictionary, room_doors: int, slack: float = 0.0) -> void:
	name = "SetRing"
	position = center
	body_slack = minf(0.0, slack)
	radius_m = float(int(geo.get("r", 480))) / 100.0
	closed = bool(geo.get("closed", false))
	gap_doors = 0 if closed else int(geo.get("doors", 0)) & 15
	shutter_doors = room_doors & 15 if closed else 0
	_build_ring_mesh()
	_build_body()
	if shutter_doors != 0:
		_build_shutters()
	set_brightness(0.0)


## The physics body (cameras exclude it: an invisible wall must never pull the spring arm in).
func body_rid() -> RID:
	return body.get_rid() if body != null else RID()


## Ring brightness 0..1 (0 = off: the tape is invisible).
func set_brightness(v: float) -> void:
	if _material == null:
		return
	var c: Color = C_RING
	c.a = clampf(v, 0.0, 1.0)
	_material.albedo_color = Color(clampf(v, 0.0, 1.0), clampf(v, 0.0, 1.0), clampf(v, 0.0, 1.0), c.a)
	ring.visible = v > 0.001


func brightness() -> float:
	return _material.albedo_color.a if _material != null else 0.0


## "Studio-Licht an": 0 → 1 in `sec` (07 §2.4: 0.3 s).
func light_up(sec: float = LIGHT_UP_SEC) -> void:
	_fade_to(1.0, sec)


## Victory / flight: the ring fades out in `sec` (07 §2.4: 0.5 s).
func fade_out(sec: float = FADE_OUT_SEC) -> void:
	_fade_to(0.0, sec)


func _fade_to(v: float, sec: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if sec <= 0.0 or not is_inside_tree():
		set_brightness(v)
		return
	_tween = create_tween()
	_tween.tween_method(set_brightness, brightness(), v, sec)


## Roll shutters down (true) or up (false) in `sec` (07 §2.9: 0.3 s, "Rolltor").
func set_shutters(down: bool, sec: float = SHUTTER_SEC) -> void:
	if shutters == null:
		return
	if _shutter_tween != null and _shutter_tween.is_valid():
		_shutter_tween.kill()
	var target: float = 1.0 if down else 0.001
	_down = down
	shutters.visible = true
	if sec <= 0.0 or not is_inside_tree():
		shutters.scale = Vector3(1.0, target, 1.0)
		shutters.visible = down
		return
	_shutter_tween = create_tween()
	_shutter_tween.tween_property(shutters, "scale", Vector3(1.0, target, 1.0), sec) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN if down else Tween.EASE_OUT)
	if not down:
		_shutter_tween.tween_callback(func() -> void: shutters.visible = false)


## The doors are closed or closing (the last set_shutters(true)); the animation may still run.
func shutters_down() -> bool:
	return shutters != null and _down


# --- geometry --------------------------------------------------------------------------------------------------------

## Angle of door `bit` on the ring (x = cos, z = sin): N −90°, E 0°, S 90°, W 180°.
static func door_angle(bit: int) -> float:
	match bit:
		1:
			return -PI * 0.5
		2:
			return 0.0
		4:
			return PI * 0.5
	return PI


## Unit vector from the room centre towards door `bit` (XZ) and its "quer" axis.
static func door_dir(bit: int) -> Vector2:
	var a: float = door_angle(bit)
	return Vector2(cos(a), sin(a))


## Arcs [a0, a1] (radians, a0 < a1, within [−π, π + 2π)) of the ring without the door gaps of `doors`.
static func ring_arcs(r_m: float, doors: int) -> Array[Vector2]:
	var gaps: Array[Vector2] = []
	var half: float = asin(clampf(DOOR_HALF / maxf(r_m, 0.01), 0.0, 1.0))
	for bit: int in DOOR_BITS:
		if doors & bit:
			var a: float = door_angle(bit)
			gaps.append(Vector2(a - half, a + half))
	var out: Array[Vector2] = []
	if gaps.is_empty():
		out.append(Vector2(0.0, TAU))
		return out
	gaps.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.x < q.x)
	for i in gaps.size():
		var a0: float = gaps[i].y
		var a1: float = gaps[(i + 1) % gaps.size()].x
		if i == gaps.size() - 1:
			a1 += TAU
		if a1 - a0 > 0.0001:
			out.append(Vector2(a0, a1))
	return out


func _build_ring_mesh() -> void:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for arc: Vector2 in ring_arcs(radius_m, gap_doors):
		var n: int = maxi(1, ceili((arc.y - arc.x) / (TAU / SEGMENTS)))
		for k in n:
			var a0: float = lerpf(arc.x, arc.y, float(k) / n)
			var a1: float = lerpf(arc.x, arc.y, float(k + 1) / n)
			_band(st, a0, a1)
	for bit: int in DOOR_BITS:
		if gap_doors & bit:
			_lane_strips(st, bit)
	ring = MeshInstance3D.new()
	ring.name = "Tape"
	ring.mesh = st.commit()
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.vertex_color_use_as_albedo = true
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	ring.material_override = _material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)


## One band quad between two angles: outer cyan edges, a bright core in the middle (three strips, vertex colours).
func _band(st: SurfaceTool, a0: float, a1: float) -> void:
	var rs: PackedFloat32Array = [radius_m - BAND_W * 0.5, radius_m - BAND_W * 0.15, radius_m + BAND_W * 0.15,
		radius_m + BAND_W * 0.5]
	var cols: Array[Color] = [C_RING, C_CORE, C_CORE, C_RING]
	for i in 3:
		var p0: Vector3 = Vector3(cos(a0) * rs[i], RING_Y, sin(a0) * rs[i])
		var p1: Vector3 = Vector3(cos(a1) * rs[i], RING_Y, sin(a1) * rs[i])
		var p2: Vector3 = Vector3(cos(a1) * rs[i + 1], RING_Y, sin(a1) * rs[i + 1])
		var p3: Vector3 = Vector3(cos(a0) * rs[i + 1], RING_Y, sin(a0) * rs[i + 1])
		_quad(st, [p0, p1, p2, p3], [cols[i], cols[i], cols[i + 1], cols[i + 1]])


## The two tape strips of a door lane, from the ring gap to the door (|quer| = DOOR_HALF − LANE_W / 2).
func _lane_strips(st: SurfaceTool, bit: int) -> void:
	var d: Vector2 = door_dir(bit)
	var q: Vector2 = Vector2(-d.y, d.x)
	var q_mid: float = DOOR_HALF - LANE_W * 0.5
	var l0: float = sqrt(maxf(0.0, radius_m * radius_m - q_mid * q_mid))
	var l1: float = WALL_INNER - 0.05
	for s: float in [-1.0, 1.0]:
		var corners: Array[Vector3] = []
		for c: Vector2 in [Vector2(l0, q_mid - LANE_W * 0.5), Vector2(l1, q_mid - LANE_W * 0.5),
				Vector2(l1, q_mid + LANE_W * 0.5), Vector2(l0, q_mid + LANE_W * 0.5)]:
			var p: Vector2 = d * c.x + q * c.y * s
			corners.append(Vector3(p.x, RING_Y, p.y))
		_quad(st, corners, [C_RING, C_RING, C_RING, C_RING])


static func _quad(st: SurfaceTool, p: Array[Vector3], c: Array[Color]) -> void:
	for idx: int in [0, 1, 2, 0, 2, 3]:
		st.set_color(c[idx])
		st.set_normal(Vector3.UP)
		st.add_vertex(p[idx])


func _build_body() -> void:
	body = StaticBody3D.new()
	body.name = "SetCollision"
	body.collision_layer = 1                    # world
	body.collision_mask = 0
	add_child(body)
	var face: float = radius_m - COLLIDER_INSET + body_slack
	for arc: Vector2 in ring_arcs(radius_m, gap_doors):
		var n: int = maxi(1, ceili((arc.y - arc.x) / (TAU / COLLIDER_SEGMENTS)))
		for k in n:
			var a0: float = lerpf(arc.x, arc.y, float(k) / n)
			var a1: float = lerpf(arc.x, arc.y, float(k + 1) / n)
			var am: float = (a0 + a1) * 0.5
			var half: float = face * tan((a1 - a0) * 0.5) + 0.02
			var dir: Vector3 = Vector3(cos(am), 0.0, sin(am))
			var pos: Vector3 = dir * (face + COLLIDER_THICK * 0.5) + Vector3(0.0, COLLIDER_HEIGHT * 0.5, 0.0)
			_box(Vector3(COLLIDER_THICK, COLLIDER_HEIGHT, half * 2.0), pos, -am)
	for bit: int in DOOR_BITS:
		if gap_doors & bit:
			var d: Vector2 = door_dir(bit)
			var q: Vector2 = Vector2(-d.y, d.x)
			var wall: float = DOOR_HALF - COLLIDER_INSET + body_slack + COLLIDER_THICK * 0.5
			var l0: float = sqrt(maxf(0.0, face * face - wall * wall)) - 0.1
			var l1: float = WALL_INNER + 0.1
			for s: float in [-1.0, 1.0]:
				var c: Vector2 = d * ((l0 + l1) * 0.5) + q * wall * s
				_box(Vector3(COLLIDER_THICK, COLLIDER_HEIGHT, l1 - l0), Vector3(c.x, COLLIDER_HEIGHT * 0.5, c.y),
					PI * 0.5 - door_angle(bit))


## A box (size x = thickness across, z = length along) at `pos`, turned by `yaw` around Y.
func _box(size: Vector3, pos: Vector3, yaw: float) -> CollisionShape3D:
	var cs: CollisionShape3D = CollisionShape3D.new()
	var b: BoxShape3D = BoxShape3D.new()
	b.size = size
	cs.shape = b
	cs.transform = Transform3D(Basis(Vector3.UP, yaw), pos)
	body.add_child(cs)
	return cs


## Roll shutters (closed set): one slatted panel per door opening of the room, all in one mesh under a pivot at the
## lintel (scale.y 0 = rolled up); their collision boxes join the set body.
func _build_shutters() -> void:
	shutters = Node3D.new()
	shutters.name = "Shutters"
	shutters.position = Vector3(0.0, SHUTTER_TOP, 0.0)
	add_child(shutters)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var c_slat: Color = Color("#8a9099")
	var c_gap: Color = Color("#3a3a44")
	var c_hazard: Color = Color("#f2c230")
	for bit: int in DOOR_BITS:
		if not (shutter_doors & bit):
			continue
		var d: Vector2 = door_dir(bit)
		var q: Vector2 = Vector2(-d.y, d.x)
		var front: Vector2 = d * (SHUTTER_DEPTH - 0.06)
		var hh: float = SHUTTER_TOP / SHUTTER_SLATS
		for i in SHUTTER_SLATS:
			var y0: float = -hh * (i + 1)
			var y1: float = -hh * i
			var col: Color = c_hazard if i == SHUTTER_SLATS - 1 else (c_slat if i % 2 == 0 else c_slat.darkened(0.12))
			var corners: Array[Vector3] = []
			for cq: Vector2 in [Vector2(-DOOR_HALF, y0), Vector2(DOOR_HALF, y0), Vector2(DOOR_HALF, y1 - 0.02),
					Vector2(-DOOR_HALF, y1 - 0.02)]:
				var p: Vector2 = front + q * cq.x
				corners.append(Vector3(p.x, cq.y, p.y))
			_quad(st, corners, [col, col, col, col])
			var groove: Array[Vector3] = []
			for cq2: Vector2 in [Vector2(-DOOR_HALF, y1 - 0.02), Vector2(DOOR_HALF, y1 - 0.02), Vector2(DOOR_HALF, y1),
					Vector2(-DOOR_HALF, y1)]:
				var p2: Vector2 = front + q * cq2.x
				groove.append(Vector3(p2.x, cq2.y, p2.y))
			_quad(st, groove, [c_gap, c_gap, c_gap, c_gap])
		var shape_pos: Vector2 = d * SHUTTER_DEPTH
		_box(Vector3(0.12, SHUTTER_TOP, DOOR_HALF * 2.0), Vector3(shape_pos.x, SHUTTER_TOP * 0.5, shape_pos.y),
			-door_angle(bit))
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "ShutterMesh"
	mi.mesh = st.commit()
	mi.material_override = Materials.toon_vc(PROP_MAT)     # the room props' material (no extra material)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shutters.add_child(mi)
	shutters.scale = Vector3(1.0, 0.001, 1.0)
	shutters.visible = false
