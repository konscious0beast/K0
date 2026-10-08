extends RefCounted
## Builds one exploration room for EnvKit.build_room() (02_TECH §7.3/§8.5, 03_ART §6). Private (no class_name).
## Room 16 × 16 m centered at the origin, walls 3.5 m / 0.5 m (inner face at 7.5 m), doors 4.0 m wide in the middle of
## an edge (lintel at 3.0 m), floor top y = 0. Free zone: circle r 5 m + 3 m corridors in front of doors; dressing only
## in the border strip. Output: "Geometry" (floor + walls, one mesh), "Props" (dressing, one mesh), "Collision"
## (StaticBody3D layer 1, box shapes), optional "Light" (+ "Neon" accent in STAIRS/SAFE rooms on quality high) and
## kind set pieces.

const DOOR_N: int = 1
const DOOR_E: int = 2
const DOOR_S: int = 4
const DOOR_W: int = 8
const SIDES: Array[int] = [1, 2, 4, 8]
const HALF: float = 8.0
const IN: float = 7.5
const WALL_BOTTOM: float = -1.0
const WALL_TOP: float = 3.5
const DOOR_HALF: float = 2.0
const FRAME: Color = Color("#3a3a44")
## Door accent lamp (length, height): flush on the lintel's inner face (this room's side only; frame depth 0.6 → face
## at w 0.3).
const LINTEL_BAND_W: float = 0.31
const LINTEL_LAMP: Vector2 = Vector2(1.2, 0.14)
const TRENCH_W: float = 2.4
const CHANNEL_W: float = 1.6
## Kinds whose room gets the extra "Neon" OmniLight on quality high; it fades out from 12 m (gone at 16 m).
const NEON_KINDS: Array[RoomSpec.Kind] = [RoomSpec.Kind.STAIRS, RoomSpec.Kind.SAFE]
const NEON_FADE_BEGIN: float = 12.0

var spec: RoomSpec
var pal: Dictionary = {}
var style: StringName = &"platform"
var rng := RandomNumberGenerator.new()
var geo: Array = []
var props: Array = []
var shapes: Array = []
var set_pieces: Array[Node3D] = []
var extra_lights: Array[Dictionary] = []
var trench_side: int = 0
var channel_side: int = 0
var hole := Rect2()
var used: Array[Vector2] = []


func _init(p_spec: RoomSpec) -> void:
	spec = p_spec
	rng.seed = hash("room") ^ (spec.seed * 2654435761) ^ (spec.variant * 97)
	match spec.kind:
		RoomSpec.Kind.QUARTER_BOSS:
			pal = Palette.resolve(Palette.ZONE_PRESETS["boss_office"] as Dictionary, spec.theme_id)
			style = &"boss_office"
		RoomSpec.Kind.FLOOR_BOSS:
			pal = Palette.resolve(Palette.ZONE_PRESETS["throne"] as Dictionary, spec.theme_id)
			style = &"throne"
		_:
			pal = Palette.resolve(spec.palette, spec.theme_id)
			style = Palette.zone_style(spec.palette, spec.theme_id)
			if style == &"safe" or style == &"boss_office" or style == &"throne":
				style = &"platform" if spec.theme_id != "mall" else &"mall"


static func edge_basis(side: int) -> Basis:
	match side:
		DOOR_N:
			return Basis(Vector3.UP, PI)
		DOOR_E:
			return Basis(Vector3.UP, PI * 0.5)
		DOOR_W:
			return Basis(Vector3.UP, -PI * 0.5)
	return Basis.IDENTITY


## Exact basis whose local −Z points at the wall `side` (no rounding noise; IDENTITY for the north wall).
static func toward_wall_basis(side: int) -> Basis:
	match side:
		DOOR_E:
			return Basis(Vector3(0, 0, 1), Vector3.UP, Vector3(-1, 0, 0))
		DOOR_S:
			return Basis(Vector3(-1, 0, 0), Vector3.UP, Vector3(0, 0, -1))
		DOOR_W:
			return Basis(Vector3(0, 0, -1), Vector3.UP, Vector3(1, 0, 0))
	return Basis.IDENTITY


static func edge_origin(side: int) -> Vector3:
	match side:
		DOOR_N:
			return Vector3(0, 0, -IN)
		DOOR_E:
			return Vector3(IN, 0, 0)
		DOOR_W:
			return Vector3(-IN, 0, 0)
	return Vector3(0, 0, IN)


## Edge frame: u along the wall (local +X), y up, w = inward distance from the inner wall face; local −Z faces the room.
static func edge_xf(side: int, u: float, y: float, w: float, yaw_deg: float = 0.0) -> Transform3D:
	var b: Basis = edge_basis(side)
	var pos: Vector3 = edge_origin(side) + b * Vector3(u, y, -w)
	return Transform3D(b * Basis(Vector3.UP, deg_to_rad(yaw_deg)), pos)


func has_door(side: int) -> bool:
	return (spec.doors & side) != 0


func build() -> Node3D:
	var root := Node3D.new()
	root.name = "Room"
	_choose_floor_features()
	_build_floor()
	for side: int in SIDES:
		_build_wall(side)
	_build_corners()
	_build_variant()
	_build_sconces()
	_build_kind()
	_build_dressing()
	var geo_mi := MeshInstance3D.new()
	geo_mi.name = "Geometry"
	var gt: Array[Dictionary] = []
	gt.assign(geo)
	geo_mi.mesh = MeshUtil.merge_no_hull(gt)
	geo_mi.material_override = _env_mat(true)
	geo_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(geo_mi)
	var props_mi := MeshInstance3D.new()
	props_mi.name = "Props"
	var pt: Array[Dictionary] = []
	pt.assign(props)
	props_mi.mesh = MeshUtil.merge_no_hull(pt)
	props_mi.material_override = _env_mat(false)
	props_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(props_mi)
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = 1
	body.collision_mask = 0
	for sv: Variant in shapes:
		var sd: Dictionary = sv
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = sd["size"]
		cs.shape = box
		cs.transform = sd["xform"]
		body.add_child(cs)
	root.add_child(body)
	if spec.with_light:
		var light := OmniLight3D.new()
		light.name = "Light"
		light.position = Vector3(0, 3.0, 0)
		light.omni_range = 9.0
		light.light_energy = 1.2
		light.light_color = pal["light"]
		light.shadow_enabled = false
		light.light_specular = 0.0
		light.distance_fade_enabled = true
		light.distance_fade_begin = 24.0
		light.distance_fade_length = 6.0
		root.add_child(light)
		# Neon accent (03_ART §4.3) only where light carries the signal (stairs gold, safe-room exit green), short fade:
		# every other room relies on emissive geometry + glow (02_TECH §12.1: ≤ 4 omni lights within 24 m)
		if spec.quality == &"high" and NEON_KINDS.has(spec.kind):
			for i in mini(extra_lights.size(), 1):
				var ld: Dictionary = extra_lights[i]
				var neon := OmniLight3D.new()
				neon.name = "Neon"
				neon.position = ld["pos"]
				neon.omni_range = float(ld.get("range", 5.0))
				neon.light_energy = float(ld.get("energy", 2.0))
				neon.light_color = ld["color"]
				neon.shadow_enabled = false
				neon.light_specular = 0.0
				neon.distance_fade_enabled = true
				neon.distance_fade_begin = NEON_FADE_BEGIN
				neon.distance_fade_length = 4.0
				root.add_child(neon)
	for n: Node3D in set_pieces:
		root.add_child(n)
	return root


func _env_mat(tiles: bool) -> ShaderMaterial:
	var tile: float = 2.0
	var dirt: float = 0.3
	match style:
		&"sewer":
			dirt = 0.45
		&"cellar":
			tile = 1.0
			dirt = 0.35
		&"track9":
			dirt = 0.35
		&"mall":
			tile = 1.0
			dirt = 0.12
		&"boss_office":
			tile = 1.0
			dirt = 0.25
		&"throne":
			dirt = 0.2
	var opts: Dictionary = {"shade": pal["shade"], "grout": pal["grout"], "tile_size": tile, "dirt": dirt}
	if not tiles:
		opts["grout_width"] = 0.0
		opts["dirt"] = dirt * 0.6
	return Materials.env(opts)


# --- floor ------------------------------------------------------------------------------------------------------------

func _choose_floor_features() -> void:
	var doorless: Array[int] = []
	for side: int in SIDES:
		if not has_door(side):
			doorless.append(side)
	var normalish: bool = spec.kind == RoomSpec.Kind.NORMAL or spec.kind == RoomSpec.Kind.START \
		or spec.kind == RoomSpec.Kind.GATE
	if normalish and not doorless.is_empty():
		var pick: int = doorless[rng.randi_range(0, doorless.size() - 1)]
		if style == &"platform" or style == &"track9":
			trench_side = pick
		elif style == &"sewer":
			channel_side = pick
	if spec.kind == RoomSpec.Kind.STAIRS:
		var sxf: Transform3D = EnvKit.anchor_for(spec, &"stairs")
		var depth: float = PropKit.stairs_well_depth(stairs_steps())
		var a: Vector3 = sxf * Vector3(-2.3, 0, 0)
		hole = Rect2(Vector2(a.x, a.z), Vector2.ZERO)
		for c: Vector3 in [Vector3(2.3, 0, 0), Vector3(-2.3, 0, -depth), Vector3(2.3, 0, -depth)]:
			var w: Vector3 = sxf * c
			hole = hole.expand(Vector2(w.x, w.z))


## Steps of the stairs set piece: compact well when all four walls have doors (02_TECH §7.3 corridors).
func stairs_steps() -> int:
	return PropKit.STAIRS_STEPS_COMPACT if (spec.doors & 15) == 15 else PropKit.STAIRS_STEPS


## XZ rect (x = position.x, z = position.y) of a strip along `side` from the outer edge to inward depth w1.
static func strip_rect(side: int, w1: float) -> Rect2:
	var d: float = HALF - IN + w1
	match side:
		DOOR_N:
			return Rect2(-HALF, -HALF, 2.0 * HALF, d)
		DOOR_S:
			return Rect2(-HALF, HALF - d, 2.0 * HALF, d)
		DOOR_E:
			return Rect2(HALF - d, -HALF, d, 2.0 * HALF)
	return Rect2(-HALF, -HALF, d, 2.0 * HALF)


static func subtract(rects: Array[Rect2], cut: Rect2) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for r: Rect2 in rects:
		if not r.intersects(cut):
			out.append(r)
			continue
		var c: Rect2 = r.intersection(cut)
		if c.position.y > r.position.y:
			out.append(Rect2(r.position.x, r.position.y, r.size.x, c.position.y - r.position.y))
		if c.end.y < r.end.y:
			out.append(Rect2(r.position.x, c.end.y, r.size.x, r.end.y - c.end.y))
		if c.position.x > r.position.x:
			out.append(Rect2(r.position.x, c.position.y, c.position.x - r.position.x, c.size.y))
		if c.end.x < r.end.x:
			out.append(Rect2(c.end.x, c.position.y, r.end.x - c.end.x, c.size.y))
	return out


func _rect_box(r: Rect2, y0: float, y1: float, color: Color, emission: float = 0.0, metal: float = 0.0) -> Dictionary:
	return MeshUtil.part(MeshUtil.box(Vector3(r.size.x, y1 - y0, r.size.y)),
		Vector3(r.position.x + r.size.x * 0.5, (y0 + y1) * 0.5, r.position.y + r.size.y * 0.5), color, Vector3.ZERO,
		Vector3.ONE, emission, metal)


func _build_floor() -> void:
	var floor_c: Color = pal["floor"]
	var rects: Array[Rect2] = [Rect2(-HALF, -HALF, 2.0 * HALF, 2.0 * HALF)]
	if trench_side != 0:
		rects = subtract(rects, strip_rect(trench_side, TRENCH_W))
	if channel_side != 0:
		rects = subtract(rects, strip_rect(channel_side, CHANNEL_W))
	if hole.has_area():
		rects = subtract(rects, hole)
	for r: Rect2 in rects:
		geo.append(_rect_box(r, -0.2, 0.0, floor_c))
	# darker border strip along the walls (reads as skirting tiles)
	for side: int in SIDES:
		if side == trench_side or side == channel_side:
			continue
		var border: Array[Rect2] = [strip_rect(side, 0.6)]
		if hole.has_area():
			border = subtract(border, hole)
		for r2: Rect2 in border:
			geo.append(_rect_box(r2, 0.0, 0.012, Palette.mul(floor_c, 0.8)))
	shapes.append({"size": Vector3(2.0 * HALF, 0.2, 2.0 * HALF),
		"xform": Transform3D(Basis.IDENTITY, Vector3(0, -0.1, 0))})
	if trench_side != 0:
		_build_trench(trench_side)
	if channel_side != 0:
		_build_channel(channel_side)


func _build_trench(side: int) -> void:
	var r: Rect2 = strip_rect(side, TRENCH_W)
	geo.append(_rect_box(r, -1.2, -1.0, Color("#3b3436")))
	# platform edge face + yellow safety line
	geo.append(_edge_box(side, 0.0, 15.0, -0.5, 1.0, TRENCH_W + 0.15, 0.3, Palette.mul(pal["wall"], 0.6)))
	geo.append(_edge_box(side, 0.0, 15.0, 0.014, 0.03, TRENCH_W + 0.3, 0.6, Palette.WARN_YELLOW, 0.15))
	# rails + sleepers
	var center_w: float = TRENCH_W * 0.5
	for k in 8:
		var u: float = -7.0 + 2.0 * float(k)
		geo.append(_edge_box(side, u, 0.3, -0.94, 0.12, center_w, 2.2, Palette.SLEEPER))
	for sx: float in [-1.0, 1.0]:
		geo.append(_edge_box(side, 0.0, 15.0, -0.83, 0.15, center_w + 0.72 * sx, 0.08, Palette.RAIL, 0.0, 1.0))
	# barrier along the platform edge (inside the trench strip, so the clear radius stays free): players never drop
	# into the track bed
	var xf: Transform3D = edge_xf(side, 0.0, 0.6, TRENCH_W - 0.1)
	shapes.append({"size": Vector3(15.0, 1.2, 0.2), "xform": xf})


func _build_channel(side: int) -> void:
	var r: Rect2 = strip_rect(side, CHANNEL_W)
	geo.append(_rect_box(r, -0.6, -0.4, Color("#18201c")))
	geo.append(_rect_box(r, -0.2, -0.15, Color("#1e4a40"), 0.3))
	geo.append(_edge_box(side, 0.0, 15.0, -0.2, 0.4, CHANNEL_W + 0.1, 0.2, Palette.mul(pal["wall"], 0.7)))
	geo.append(_edge_box(side, 0.0, 15.0, 0.04, 0.08, CHANNEL_W + 0.1, 0.24, Palette.mul(pal["floor"], 1.25)))
	for k in 3:
		geo.append(_edge_box(side, -5.0 + 5.0 * float(k), 1.4, 0.06, 0.04, CHANNEL_W * 0.5, CHANNEL_W + 0.1,
			Palette.DARK_METAL, 0.0, 1.0))


## Box in the edge frame: centered at u (length along the wall), y center, w center (inward), depth along w.
func _edge_box(side: int, u: float, length: float, y: float, height: float, w: float, depth: float, color: Color,
		emission: float = 0.0, metal: float = 0.0, tilt_deg: float = 0.0) -> Dictionary:
	var xf: Transform3D = edge_xf(side, u, y, w)
	if tilt_deg != 0.0:
		xf.basis = xf.basis * Basis(Vector3.RIGHT, deg_to_rad(tilt_deg))
	xf.basis = xf.basis * Basis.from_scale(Vector3(length, height, depth))
	return {"mesh": MeshUtil.box(Vector3.ONE), "xform": xf, "color": color, "emission": emission, "metal": metal}


# --- walls ------------------------------------------------------------------------------------------------------------

func _build_wall(side: int) -> void:
	var wall_c: Color = pal["wall"]
	var door: bool = has_door(side)
	var h: float = WALL_TOP - WALL_BOTTOM
	var yc: float = (WALL_TOP + WALL_BOTTOM) * 0.5
	for k in 8:
		var u: float = -7.0 + 2.0 * float(k)
		if door and absf(u) < DOOR_HALF:
			continue
		var tilt: float = 0.0
		if spec.variant == 3 and rng.randf() < 0.3:
			tilt = rng.randf_range(-4.0, 4.0)
		var jitter: float = rng.randf_range(0.9, 1.08)
		geo.append(_edge_box(side, u, 2.0, yc, h, -0.25, 0.5, Palette.mul(wall_c, jitter), 0.0, 0.0, tilt))
	var runs: Array[Vector2] = []
	if door:
		runs.append_array([Vector2(-HALF, -DOOR_HALF), Vector2(DOOR_HALF, HALF)])
	else:
		runs.append(Vector2(-HALF, HALF))
	for run: Vector2 in runs:
		var run_len: float = run.y - run.x
		var mid: float = (run.x + run.y) * 0.5
		geo.append(_edge_box(side, mid, run_len, 0.15, 0.3, 0.0, 0.6, Palette.mul(wall_c, 0.7)))
		geo.append(_edge_box(side, mid, run_len, 3.44, 0.12, -0.02, 0.55, Palette.mul(wall_c, 1.15)))
		shapes.append({"size": Vector3(run_len, 4.5, 0.5), "xform": edge_xf(side, mid, 1.25, -0.25)})
	if door:
		for sx: float in [-1.0, 1.0]:
			geo.append(_edge_box(side, 2.25 * sx, 0.5, 1.5, 3.0, 0.0, 0.6, FRAME, 0.0, 0.3))
		geo.append(_edge_box(side, 0.0, 5.0, 3.25, 0.5, 0.0, 0.6, FRAME, 0.0, 0.3))
		# short accent lamp flush on the lintel's inner face (this room's side only): the old 4 m strip under the lintel
		# read as a stray pink line across the opening (and across the walls of neighbour rooms; visual pass)
		geo.append(_edge_box(side, 0.0, LINTEL_LAMP.x, 3.25, LINTEL_LAMP.y, LINTEL_BAND_W, 0.02,
			Palette.mul(pal["accent"], 0.9), 0.6))
		# lintel blocks the camera arm above the door (layer 1)
		shapes.append({"size": Vector3(5.0, 0.5, 0.6), "xform": edge_xf(side, 0.0, 3.25, 0.0)})


func _build_corners() -> void:
	var wall_c: Color = pal["wall"]
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var p := Vector3(7.3 * sx, 0, 7.3 * sz)
			if style == &"platform":
				var col := MeshUtil.cylinder(0.38, 0.38, 3.5)
				col.radial_segments = 6
				col.cap_bottom = false
				var band := MeshUtil.cylinder(0.39, 0.39, 0.3)
				band.radial_segments = 6
				geo.append(MeshUtil.part(col, p + Vector3(0, 1.75, 0), Palette.mul(wall_c, 0.8)))
				geo.append(MeshUtil.part(band, p + Vector3(0, 1.0, 0), Palette.WARN_YELLOW))
			else:
				geo.append(MeshUtil.part(MeshUtil.box(Vector3(0.7, 3.5, 0.7)), p + Vector3(0, 1.75, 0), Palette.mul(wall_c, 0.8)))
				geo.append(MeshUtil.part(MeshUtil.box(Vector3(0.9, 0.3, 0.9)), p + Vector3(0, 3.35, 0), Palette.mul(wall_c, 0.65)))


# --- variants (03_ART §6.2) ---------------------------------------------------------------------------------------

func _doorless_sides() -> Array[int]:
	var out: Array[int] = []
	for side: int in SIDES:
		if not has_door(side):
			out.append(side)
	return out


func _wall_sides_for_decor() -> Array[int]:
	var sides: Array[int] = _doorless_sides()
	if sides.is_empty():
		sides = SIDES.duplicate()
	return sides


func _build_variant() -> void:
	var sides: Array[int] = _wall_sides_for_decor()
	match spec.variant:
		1:
			for i in 2:
				var side: int = sides[(i + rng.randi_range(0, 3)) % sides.size()]
				var u: float = (-4.6 if i == 0 else 4.6) if has_door(side) else rng.randf_range(-4.5, 4.5)
				var r: Dictionary = PropKit.recipe("poster", spec.seed + i, spec.palette)
				_add_recipe(props, r, edge_xf(side, u, 1.9, 0.03))
				if i == 0:
					extra_lights.append({"pos": edge_xf(side, u, 2.2, 1.2).origin, "color": pal["accent"], "energy": 2.0,
						"range": 5.0})
		2:
			var side2: int = sides[rng.randi_range(0, sides.size() - 1)]
			if side2 == trench_side and sides.size() > 1:
				side2 = sides[(sides.find(side2) + 1) % sides.size()]
			for y: float in [0.8, 3.0]:
				var segs: Array[Vector2] = []
				if has_door(side2):
					segs.append_array([Vector2(-7.4, -2.4), Vector2(2.4, 7.4)])
				else:
					segs.append(Vector2(-7.4, 7.4))
				for sgm: Vector2 in segs:
					var a: Vector3 = edge_xf(side2, sgm.x, y, 0.2).origin
					var b: Vector3 = edge_xf(side2, sgm.y, y, 0.2).origin
					geo.append(PropKit.seg(a, b, 0.12, 0.12, Color("#8a4b2a")))
					geo.append(PropKit.seg(a.lerp(b, 0.5) + Vector3(0, -0.04, 0), a.lerp(b, 0.5) + Vector3(0, 0.04, 0), 0.16,
						0.16, Palette.mul(Color("#8a4b2a"), 0.7), 0.0, 1.0))
		3:
			var side3: int = sides[rng.randi_range(0, sides.size() - 1)]
			var u0: float = rng.randf_range(-3.5, 3.5) if not has_door(side3) else 4.8
			for k in 3:
				geo.append(_edge_box(side3, u0 - 0.6 + 0.6 * float(k), 0.12, 1.6 + 0.2 * float(k), 1.6 - 0.3 * float(k),
					0.02, 0.03, Palette.GRAFFITI, 0.4, 0.0))
				var p: Dictionary = geo[geo.size() - 1]
				p["xform"] = (p["xform"] as Transform3D) * Transform3D(Basis(Vector3.FORWARD, deg_to_rad(25.0)), Vector3.ZERO)
			geo.append(_edge_box(side3, u0 + 1.2, 1.4, 2.4, 0.1, 0.02, 0.03, Palette.NOVA_CYAN, 0.4))


## Sodium wall sconces (03_ART §1 "Natrium-Orange = Weg") on two walls.
func _build_sconces() -> void:
	var sides: Array[int] = _wall_sides_for_decor()
	var lamp_c: Color = Palette.SODIUM if style != &"boss_office" else Color("#e8f0d8")
	if style == &"track9":
		lamp_c = pal["light"]
	for i in mini(2, sides.size()):
		var side: int = sides[i]
		var u: float = 5.0 if has_door(side) else 0.0
		if i == 0 and spec.kind == RoomSpec.Kind.START:
			u = -4.6          # the LIVE screen takes this wall's center / door-side slot (_start_marking)
		if style == &"boss_office":
			geo.append(_edge_box(side, u, 1.6, 2.9, 0.08, 0.12, 0.16, Palette.DARK_METAL))
			geo.append(_edge_box(side, u, 1.5, 2.85, 0.06, 0.14, 0.1, lamp_c, 1.2))
			continue
		geo.append(_edge_box(side, u, 0.5, 2.7, 0.15, 0.18, 0.3, Palette.DARK_METAL, 0.0, 0.5))
		geo.append(_edge_box(side, u, 0.42, 2.62, 0.02, 0.2, 0.22, lamp_c, 1.0))


# --- kind set pieces -------------------------------------------------------------------------------------------------

func _build_kind() -> void:
	match spec.kind:
		RoomSpec.Kind.START:
			_start_marking()
		RoomSpec.Kind.STAIRS:
			var steps: int = stairs_steps()
			var stairs: Node3D = PropKit.assemble("stairs_down", PropKit.stairs_recipe(spec.palette, steps), spec.palette)
			stairs.name = "Stairs"
			stairs.transform = EnvKit.anchor_for(spec, &"stairs")
			set_pieces.append(stairs)
			_steal_collision(stairs)
			extra_lights.insert(0, {"pos": stairs.transform * Vector3(0, 2.5, -0.25 * float(steps)),
				"color": Palette.HYPE_GOLD, "energy": 1.6, "range": 7.0})
		RoomSpec.Kind.SAFE:
			var door: Node3D = PropKit.build(&"safe_door", spec.seed, spec.palette)
			door.name = "SafeDoor"
			door.transform = EnvKit.anchor_for(spec, &"safe_door")
			set_pieces.append(door)
			extra_lights.insert(0, {"pos": (door.transform * Vector3(0, 2.6, -1.0)), "color": Palette.EXIT_GREEN,
				"energy": 1.5, "range": 5.0})
		RoomSpec.Kind.QUARTER_BOSS:
			_office()
		RoomSpec.Kind.FLOOR_BOSS:
			_throne()


## Moves a set piece's StaticBody shapes into the room collision (one body per room).
func _steal_collision(n: Node3D) -> void:
	var body: Node = n.get_node_or_null("Collision")
	if body == null:
		return
	for c: Node in body.get_children():
		var cs: CollisionShape3D = c as CollisionShape3D
		if cs != null and cs.shape is BoxShape3D:
			shapes.append({"size": (cs.shape as BoxShape3D).size, "xform": n.transform * cs.transform})
	n.remove_child(body)
	body.free()


func _start_marking() -> void:
	var ring := MeshUtil.torus(1.5, 1.7)
	ring.rings = 24
	geo.append(MeshUtil.part(ring, Vector3(0, 0.01, 0), Palette.NOVA_MAGENTA, Vector3.ZERO, Vector3(1, 0.08, 1), 0.9))
	geo.append(MeshUtil.part(MeshUtil.cylinder(0.6, 0.6, 0.02), Vector3(0, 0.005, 0),
		Palette.mul(Palette.NOVA_MAGENTA, 0.5),
		Vector3.ZERO, Vector3.ONE, 0.3))
	var sides: Array[int] = _wall_sides_for_decor()
	var side: int = sides[0]
	var u: float = 4.6 if has_door(side) else 0.0
	geo.append(_edge_box(side, u, 3.2, 2.2, 1.9, 0.08, 0.16, Palette.INK))
	# LIVE screen merged into the room geometry (budget: Geometry + Props + interactives only): glowing panel with
	# darker scanlines; the LIVE label floats in front of it.
	geo.append(_edge_box(side, u, 3.0, 2.2, 1.7, 0.17, 0.02, Palette.mul(Palette.NOVA_MAGENTA, 0.3), 0.3))
	for i in 3:
		geo.append(_edge_box(side, u, 2.9, 1.5 + 0.7 * float(i), 0.04, 0.185, 0.01,
			Palette.mul(Palette.NOVA_MAGENTA, 0.8), 0.7))
	var l := Label3D.new()
	l.name = "LiveLabel"
	l.text = "LIVE"
	l.font_size = 140
	l.outline_size = 16
	l.pixel_size = 0.006
	l.modulate = Palette.sign_color(Palette.PAPER)
	l.outline_modulate = Palette.LIVE_RED
	l.transform = edge_xf(side, u, 2.25, 0.2) * Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
	set_pieces.append(l)
	extra_lights.insert(0,
		{"pos": edge_xf(side, u, 2.2, 1.5).origin, "color": Palette.NOVA_MAGENTA, "energy": 1.8, "range": 6.0})


## Hausmeister-Büro (03_ART §2.2 boss palette): desk, filing cabinets, notice board, "staff only" sign.
func _office() -> void:
	var sides: Array[int] = _wall_sides_for_decor()
	var back: int = sides[0]
	var desk_c := Color("#6b4a2e")
	var xf: Transform3D = edge_xf(back, 0.0 if not has_door(back) else 4.5, 0.0, 1.6)
	var desk: Array = [
		MeshUtil.part(MeshUtil.box(Vector3(2.4, 0.08, 1.0)), Vector3(0, 0.8, 0), desk_c),
		MeshUtil.part(MeshUtil.box(Vector3(0.5, 0.76, 0.9)), Vector3(-0.9, 0.38, 0), Palette.mul(desk_c, 0.85)),
		MeshUtil.part(MeshUtil.box(Vector3(0.5, 0.76, 0.9)), Vector3(0.9, 0.38, 0), Palette.mul(desk_c, 0.85)),
		MeshUtil.part(MeshUtil.box(Vector3(0.5, 0.06, 0.35)), Vector3(-0.5, 0.87, -0.1), Color("#f2eee6")),
		MeshUtil.part(MeshUtil.box(Vector3(0.12, 0.18, 0.12)), Vector3(0.6, 0.93, 0), Palette.LIVE_RED),
		MeshUtil.part(MeshUtil.cylinder(0.05, 0.05, 0.2), Vector3(0.6, 1.1, 0), desk_c),
		MeshUtil.part(MeshUtil.box(Vector3(0.6, 0.08, 0.6)), Vector3(0, 0.5, 0.95), Color("#3a3a44")),
		MeshUtil.part(MeshUtil.box(Vector3(0.6, 0.7, 0.08)), Vector3(0, 0.9, 1.25), Color("#3a3a44")),
	]
	_add_parts(props, desk, xf)
	shapes.append({"size": Vector3(2.4, 0.9, 1.0), "xform": xf * Transform3D(Basis.IDENTITY, Vector3(0, 0.45, 0))})
	for k in 3:
		var cab_xf: Transform3D = edge_xf(back, -6.0 + 0.95 * float(k), 0.0, 0.45)
		var cab: Array = [MeshUtil.part(MeshUtil.box(Vector3(0.9, 1.6, 0.6)), Vector3(0, 0.8, 0), Color("#7c8a94"))]
		for d in 3:
			cab.append(MeshUtil.part(MeshUtil.box(Vector3(0.8, 0.02, 0.02)), Vector3(0, 0.5 + 0.45 * float(d), -0.31),
				Palette.DARK_METAL))
			cab.append(MeshUtil.part(MeshUtil.box(Vector3(0.2, 0.04, 0.03)), Vector3(0, 0.38 + 0.45 * float(d), -0.31),
				Palette.STEEL, Vector3.ZERO, Vector3.ONE, 0.0, 1.0))
		_add_parts(props, cab, cab_xf)
		shapes.append({"size": Vector3(0.9, 1.6, 0.6), "xform": cab_xf * Transform3D(Basis.IDENTITY, Vector3(0, 0.8, 0))})
	var board_xf: Transform3D = edge_xf(back, 4.0 if not has_door(back) else -3.5, 1.9, 0.04)
	var board: Array = [MeshUtil.part(MeshUtil.box(Vector3(1.8, 1.1, 0.04)), Vector3.ZERO, Color("#a8794a"))]
	for k in 6:
		board.append(MeshUtil.part(MeshUtil.box(Vector3(0.32, 0.4, 0.01)),
			Vector3(-0.6 + 0.4 * float(k % 3) + rng.randf_range(-0.05, 0.05), 0.2 - 0.45 * float(k / 3), -0.03),
			Color("#f2eee6"), Vector3(0, 0, rng.randf_range(-8.0, 8.0))))
	_add_parts(props, board, board_xf)
	var l := Label3D.new()
	l.name = "HausordnungLabel"
	l.text = "HAUSORDNUNG"
	l.font_size = 48
	l.outline_size = 8
	l.pixel_size = 0.005
	l.modulate = Palette.INK
	l.outline_modulate = Palette.PAPER
	l.transform = board_xf * Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0.68, -0.04))
	set_pieces.append(l)


## Thronsaal: derailed wreck against the back wall, ticket litter, violet light (03_ART §6.3).
func _throne() -> void:
	var sides: Array[int] = _wall_sides_for_decor()
	var back: int = sides[0]
	var r: Dictionary = PropKit.recipe("wreck", spec.seed, spec.palette)
	var sx: float = 0.75
	var u: float = 0.0
	if has_door(back):
		sx = 0.32
		u = 4.9
	var xf: Transform3D = edge_xf(back, u, 0.0, 1.3) * Transform3D(Basis.from_scale(Vector3(sx, 0.75, 0.75)), Vector3.ZERO)
	_add_recipe(props, r, xf)
	for cv: Variant in (r["collision"] as Array):
		var cd: Dictionary = cv
		var cx: Transform3D = xf * (cd["xform"] as Transform3D)
		var sc: Vector3 = cx.basis.get_scale()
		shapes.append({"size": (cd["size"] as Vector3) * sc, "xform": Transform3D(cx.basis.orthonormalized(), cx.origin)})
	for k in 24:
		var a: float = rng.randf_range(0.0, TAU)
		var d: float = rng.randf_range(1.5, 6.5)
		props.append(MeshUtil.part(MeshUtil.box(Vector3(0.12, 0.01, 0.06)), Vector3(cos(a) * d, 0.012, sin(a) * d),
			Color("#f2e8c9"), Vector3(0, rng.randf_range(0.0, 180.0), 0)))
	extra_lights.insert(0,
		{"pos": edge_xf(back, 0.0, 3.0, 3.0).origin, "color": pal["accent"], "energy": 2.0, "range": 8.0})


# --- dressing ---------------------------------------------------------------------------------------------------------

const STYLE_PROPS: Dictionary = {
	"platform": ["bench", "bench", "trash_bin", "lamp", "lamp", "pillar", "crate"],
	"sewer": ["barrel", "barrel", "crate", "crate", "pipe", "pipe", "lamp"],
	"cellar": ["crate", "crate", "crate", "barrel", "barrel", "lamp", "pipe"],
	"track9": ["rail", "crate", "barrel", "lamp", "lamp", "pillar", "crate"],
	"mall": ["bench", "bench", "trash_bin", "lamp", "pillar", "crate"],
	"boss_office": ["crate", "barrel", "lamp"],
	"throne": ["barrel", "lamp", "crate"],
}


func _build_dressing() -> void:
	var slots: Array[Dictionary] = []
	for side: int in SIDES:
		if side == trench_side or side == channel_side:
			continue
		var us: Array[float] = [-6.2, -4.3, 4.3, 6.2]
		if not has_door(side):
			us.append_array([-2.0, 0.0, 2.0])
		for u: float in us:
			slots.append({"side": side, "u": u})
	# deterministic shuffle
	for i in range(slots.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Dictionary = slots[i]
		slots[i] = slots[j]
		slots[j] = tmp
	var count: int = rng.randi_range(4, 7)
	if spec.quality == &"low":
		count = mini(count, 4)
	if spec.kind == RoomSpec.Kind.QUARTER_BOSS or spec.kind == RoomSpec.Kind.FLOOR_BOSS:
		count = 2
	var pool: Array = STYLE_PROPS.get(String(style), STYLE_PROPS["platform"])
	var placed: int = 0
	var props_tris: int = _parts_tris(props)
	for sd: Dictionary in slots:
		if placed >= count:
			break
		var side: int = sd["side"]
		var u: float = sd["u"]
		var id: String = str(pool[rng.randi_range(0, pool.size() - 1)])
		var w: float = 1.0
		var yaw: float = 0.0
		var y: float = 0.0
		match id:
			"bench":
				w = 0.55
			"pipe":
				w = 0.35
				y = rng.randf_range(0.0, 1.2)
			"rail":
				w = 1.6
				yaw = 90.0
			"crate", "barrel":
				yaw = rng.randf_range(-15.0, 15.0)
				w = rng.randf_range(0.7, 1.3)
			"lamp":
				w = 0.6
		var xf: Transform3D = edge_xf(side, u, y, w, yaw)
		var pos2 := Vector2(xf.origin.x, xf.origin.z)
		if not _slot_free(pos2):
			continue
		if hole.has_area() and hole.grow(1.0).has_point(pos2):
			continue
		var r: Dictionary = PropKit.recipe(id, spec.seed * 31 + placed, spec.palette)
		var cost: int = _recipe_tris(r)
		if props_tris + cost > PROPS_TRI_BUDGET:
			continue
		props_tris += cost
		_add_recipe(props, r, xf)
		if id != "pipe" and id != "rail":
			for cv: Variant in (r["collision"] as Array):
				var cd: Dictionary = cv
				shapes.append({"size": cd["size"], "xform": xf * (cd["xform"] as Transform3D)})
		used.append(pos2)
		placed += 1


const PROPS_TRI_BUDGET: int = 2300


static func _parts_tris(parts: Array) -> int:
	var total: int = 0
	for p: Variant in parts:
		total += MeshUtil.tri_count((p as Dictionary)["mesh"] as Mesh)
	return total


static func _recipe_tris(r: Dictionary) -> int:
	var total: int = _parts_tris(r.get("parts", []) as Array)
	for pv: Variant in (r.get("pivots", []) as Array):
		total += _parts_tris((pv as Dictionary).get("parts", []) as Array)
	return total


func _slot_free(p: Vector2) -> bool:
	if p.length() < EnvKit.CLEAR_RADIUS + 0.4:
		return false
	for q: Vector2 in used:
		if q.distance_to(p) < 1.6:
			return false
	# 3 m corridors in front of doors (4 m wide)
	for side: int in SIDES:
		if not has_door(side):
			continue
		var o: Vector3 = edge_origin(side)
		var b: Basis = edge_basis(side)
		var local: Vector3 = b.inverse() * (Vector3(p.x, 0, p.y) - o)
		if absf(local.x) < DOOR_HALF + 0.7 and -local.z < 3.6:
			return false
	return true


func _add_recipe(target: Array, r: Dictionary, xf: Transform3D) -> void:
	_add_parts(target, r.get("parts", []) as Array, xf)
	for pv: Variant in (r.get("pivots", []) as Array):
		var pd: Dictionary = pv
		var pxf: Transform3D = xf * MeshUtil.xform(pd.get("pos", Vector3.ZERO), pd.get("rot", Vector3.ZERO))
		_add_parts(target, pd.get("parts", []) as Array, pxf)


func _add_parts(target: Array, parts: Array, xf: Transform3D) -> void:
	for p: Variant in parts:
		var q: Dictionary = (p as Dictionary).duplicate()
		q["xform"] = xf * ((p as Dictionary)["xform"] as Transform3D)
		target.append(q)
