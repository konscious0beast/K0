class_name RtGeo extends RefCounted
## Set geometry of a real-time combat (07 §2.1–2.4, §3.5.4, §3.5.5): the ring around the room centre, the door lanes,
## blockers, line of sight, formation slots, entry anchors and escape points. Pure integer math in room-local cm
## (origin = cell centre, +x east, +z south; DetMath), no state.
##
## geo = {"r": int, "doors": int (N 1, E 2, S 4, W 8), "closed": bool, "blockers": [[x0, z0, x1, z1], …]} plus the
## structural lengths make_geo copies from RtBalance ("door_half", "cell_half", "room_inner"; the defaults of 07 §3.16
## when missing). A unit "stands" on its centre with its radius r_u:
##   in_set(p)          = |p| ≤ geo.r                                   (telegraph effect and drawing)
##   walkable(p, false) = |p| ≤ geo.r − r_u and p outside every blocker grown by r_u
##   walkable(p, true)  = walkable(p, false) or in a door lane of an open set (party only)
## Contract note (R1b): 07 §3.5.4 bounds a lane by geo.r − r_u < längs ≤ CELL_HALF. That leaves a notch between the
## circle and the lane's inner edge (for |quer| > 0 the circle ends before längs reaches geo.r − r_u), so an honest run
## out of a door off its centre line would be corrected. The lane here starts at the centre (0 < längs ≤ CELL_HALF):
## the same strip, the notch included — inside the circle it adds nothing.

const FixedMath := preload("res://core/stats/fixed_math.gd")

const DOOR_ORDER: PackedInt32Array = [1, 2, 4, 8]       # RoomCell.DOOR_N, DOOR_E, DOOR_S, DOOR_W (tie order)
const FORMATION: Array = [[0, 0], [-130, 90], [130, 90], [0, 180]]   # slot → (right, behind) in cm, 07 §3.5.5
const DEFAULT_DOOR_HALF: int = 200
const DEFAULT_CELL_HALF: int = 800
const DEFAULT_ROOM_INNER: int = 750
const ESCAPE_DISTS: PackedInt32Array = [100, 200, 300, 450, 600]   # escape point candidates (07 §5.5), cm


## Set radius of a room kind (RoomCell.Kind): SET_R_CM "regular" for NORMAL, START, GATE, SAFE; "boss" for
## QUARTER_BOSS / FLOOR_BOSS; 0 for STAIRS (no set, 07 §2.4).
static func set_radius(room_kind: int, bal: RtBalance) -> int:
	var b: RtBalance = bal if bal != null else RtBalance.new()
	match room_kind:
		RoomCell.Kind.QUARTER_BOSS, RoomCell.Kind.FLOOR_BOSS:
			return b.sub("SET_R_CM", "boss")
		RoomCell.Kind.STAIRS:
			return 0
	return b.sub("SET_R_CM", "regular")


## The geometry of a cell: radius by kind, its door bits (a closed set keeps them but has no lanes), no blockers.
static func make_geo(cell_kind: int, doors: int, closed: bool, bal: RtBalance) -> Dictionary:
	var b: RtBalance = bal if bal != null else RtBalance.new()
	return {"r": set_radius(cell_kind, b), "doors": doors & 15, "closed": closed, "blockers": [],
		"door_half": b.i("DOOR_HALF_CM"), "cell_half": b.i("CELL_HALF_CM"), "room_inner": b.i("ROOM_INNER_CM")}


## |p| ≤ geo.r (telegraphs act and are drawn only here).
static func in_set(geo: Dictionary, x: int, z: int) -> bool:
	var r: int = int(geo.get("r", 0))
	return r > 0 and x * x + z * z <= r * r


## Can a circle of radius r stand at (x, z)? Party units may also use the door lanes of an open set.
static func walkable(geo: Dictionary, x: int, z: int, r: int, party: bool) -> bool:
	if in_blocker(geo, x, z, r):
		return false
	if in_circle(geo, x, z, r):
		return true
	return party and in_gap(geo, x, z, r)


## Inside the ring part (|p| ≤ geo.r − r), blockers ignored.
static func in_circle(geo: Dictionary, x: int, z: int, r: int) -> bool:
	var big: int = int(geo.get("r", 0)) - r
	return int(geo.get("r", 0)) > 0 and big >= 0 and x * x + z * z <= big * big


## In a door lane of an open set (see the contract note above).
static func in_gap(geo: Dictionary, x: int, z: int, r: int) -> bool:
	if bool(geo.get("closed", false)) or int(geo.get("r", 0)) <= 0:
		return false
	var half: int = int(geo.get("door_half", DEFAULT_DOOR_HALF)) - r
	var cell: int = int(geo.get("cell_half", DEFAULT_CELL_HALF))
	if half < 0:
		return false
	var doors: int = int(geo.get("doors", 0))
	for d: int in DOOR_ORDER:
		if (doors & d) == 0:
			continue
		var al: Vector2i = _along_across(d, x, z)
		if al.x > 0 and al.x <= cell and absi(al.y) <= half:
			return true
	return false


## Inside a blocker grown by r (strictly: the grown edge itself is walkable).
static func in_blocker(geo: Dictionary, x: int, z: int, r: int) -> bool:
	for bv: Variant in (geo.get("blockers", []) as Array):
		var b: Array = bv
		if b.size() == 4 and x > int(b[0]) - r and x < int(b[2]) + r and z > int(b[1]) - r and z < int(b[3]) + r:
			return true
	return false


## The nearest walkable point (07 §3.5.4): candidates are the circle projection, the clamp into each open lane (party,
## in the order N, E, S, W) and the pushes out of each blocker (list order); the nearest walkable one wins, ties keep
## the earlier candidate. A walkable point is returned unchanged.
static func project_walkable(geo: Dictionary, x: int, z: int, r: int, party: bool) -> Vector2i:
	if walkable(geo, x, z, r, party):
		return Vector2i(x, z)
	var cands: Array[Vector2i] = []
	var pc: Vector2i = _circle_point(geo, x, z, r)
	cands.append(pc)
	if party and not bool(geo.get("closed", false)):
		var half: int = int(geo.get("door_half", DEFAULT_DOOR_HALF)) - r
		var cell: int = int(geo.get("cell_half", DEFAULT_CELL_HALF))
		var doors: int = int(geo.get("doors", 0))
		if half >= 0:
			for d: int in DOOR_ORDER:
				if (doors & d) != 0:
					var al: Vector2i = _along_across(d, x, z)
					cands.append(_from_along_across(d, clampi(al.x, 1, cell), clampi(al.y, -half, half)))
	for bv: Variant in (geo.get("blockers", []) as Array):
		var b: Array = bv
		if b.size() != 4:
			continue
		for p: Vector2i in [Vector2i(x, z), pc]:
			cands.append(Vector2i(int(b[0]) - r, p.y))
			cands.append(Vector2i(int(b[2]) + r, p.y))
			cands.append(Vector2i(p.x, int(b[1]) - r))
			cands.append(Vector2i(p.x, int(b[3]) + r))
	var best: Vector2i = pc
	var best_d: int = -1
	for c: Vector2i in cands:
		if not walkable(geo, c.x, c.y, r, party):
			continue
		var d2: int = DetMath.dist2(x, z, c.x, c.y)
		if best_d < 0 or d2 < best_d:
			best = c
			best_d = d2
	return best


## Line of sight: the set has no props (07 §2.3), so any two points in the ring or a door lane see each other; a
## point beyond them (a fleeing unit outside the cell) sees nothing.
static func los(geo: Dictionary, ax: int, az: int, bx: int, bz: int) -> bool:
	return _visible(geo, ax, az) and _visible(geo, bx, bz)


## Formation slot around an anchor facing yaw (07 §3.5.5): slot 0 (0, 0), 1 (−130, 90), 2 (130, 90), 3 (0, 180) —
## (right, behind) in cm, rotated with the yaw; further slots continue behind slot 3 every 90 cm. Not clamped: the
## caller projects the point (project_walkable).
static func formation(slot: int, ax: int, az: int, yaw: int) -> Vector2i:
	var off: Array = FORMATION[slot] if slot >= 0 and slot < FORMATION.size() else [0, 180 + 90 * maxi(0, slot - 3)]
	var v: Vector2i = DetMath.rotate_local(int(off[0]), int(off[1]), yaw)
	return Vector2i(ax + v.x, az + v.y)


## Entry anchor of a group-less combat (07 §2.3): the end of the door lane (at the door, ROOM_INNER) of the open door
## farthest from (cx, cz) (ties N, E, S, W); without an open door the ring point opposite (cx, cz) (north of the
## centre if the figure stands on it).
static func group_anchor(geo: Dictionary, cx: int, cz: int) -> Vector2i:
	var r: int = int(geo.get("r", 0))
	if not bool(geo.get("closed", false)):
		var inner: int = int(geo.get("room_inner", DEFAULT_ROOM_INNER))
		var doors: int = int(geo.get("doors", 0))
		var best: Vector2i = Vector2i.ZERO
		var best_d: int = -1
		for d: int in DOOR_ORDER:
			if (doors & d) == 0:
				continue
			var p: Vector2i = _from_along_across(d, inner, 0)
			var d2: int = DetMath.dist2(cx, cz, p.x, p.y)
			if d2 > best_d:
				best = p
				best_d = d2
		if best_d >= 0:
			return best
	if cx == 0 and cz == 0:
		return Vector2i(0, -r)
	return DetMath.toward(0, 0, -cx, -cz, r)


## Where a summon "at the door" appears (07 §3.12): the end of the door lane (at the door, ROOM_INNER from the centre)
## of the door nearest to (cx, cz) — the party centre — (ties N, E, S, W); in a closed set the ring point in front of
## that door (geo.r − r); without a door the ring point opposite (cx, cz) (north of the centre if it is the centre).
static func door_spot(geo: Dictionary, cx: int, cz: int, r: int) -> Vector2i:
	var ring: int = maxi(0, int(geo.get("r", 0)) - r)
	var inner: int = int(geo.get("room_inner", DEFAULT_ROOM_INNER))
	var doors: int = int(geo.get("doors", 0))
	var best: int = 0
	var best_d: int = -1
	for d: int in DOOR_ORDER:
		if (doors & d) == 0:
			continue
		var p: Vector2i = _from_along_across(d, inner, 0)
		var d2: int = DetMath.dist2(cx, cz, p.x, p.y)
		if best_d < 0 or d2 < best_d:
			best = d
			best_d = d2
	if best_d < 0:
		if cx == 0 and cz == 0:
			return Vector2i(0, -ring)
		return DetMath.toward(0, 0, -cx, -cz, ring)
	return _from_along_across(best, ring if bool(geo.get("closed", false)) else inner, 0)


## Escape point of a unit leaving telegraphs and zones (07 §5.5): candidates in the 16 directions yaw = k × 16 at
## ESCAPE_DISTS from the unit, ordered by distance, then by closeness to the preferred direction (melee: towards its
## target, ranged — keep_cm > 0: away from the nearest enemy; none: no preference), then k; the first one that is
## walkable in the ring (no door lane, no blocker) and safe (RtSim.safe_point: outside every hostile shape striking
## within 60 ticks, grown by ESCAPE_MARGIN_CM, and outside every hostile zone). None → the unit's own position (it
## stands). Pure.
static func escape_point(sim: RtSim, u: RtUnit) -> Vector2i:
	if u == null:
		return Vector2i.ZERO
	var geo: Dictionary = sim.setup.geo
	var pref: int = _preferred_yaw(sim, u)
	var order: PackedInt32Array = []                         # gap × 16 + k: sorted by gap, then k
	for k in 16:
		order.append((_yaw_gap(k * 16, pref) if pref >= 0 else 0) * 16 + k)
	order.sort()
	for d: int in ESCAPE_DISTS:
		for e: int in order:
			var f: Vector2i = DetMath.dir((e % 16) * 16)
			var x: int = u.x + FixedMath.div_round(f.x * d, DetMath.ONE)
			var z: int = u.z + FixedMath.div_round(f.y * d, DetMath.ONE)
			if walkable(geo, x, z, u.radius, false) and sim.safe_point(u, x, z):
				return Vector2i(x, z)
	return Vector2i(u.x, u.z)


# --- private --------------------------------------------------------------------------------------------------------

## The preferred escape direction (07 §5.5): melee — towards the unit's hostile target; ranged (keep_cm > 0) — away
## from the nearest enemy on stage (ties: unit order); −1 without one (or on the same spot).
static func _preferred_yaw(sim: RtSim, u: RtUnit) -> int:
	if u.keep_cm <= 0:
		var t: RtUnit = sim.unit(u.target_id)
		if t == null or t.side == u.side or not sim.targetable(t) or (t.x == u.x and t.z == u.z):
			return -1
		return DetMath.yaw_of(t.x - u.x, t.z - u.z)
	var near: RtUnit = null
	var nd: int = -1
	for v: RtUnit in sim.units_ref():
		if v.side == u.side or not sim.targetable(v):
			continue
		var d2: int = DetMath.dist2(u.x, u.z, v.x, v.z)
		if near == null or d2 < nd:
			near = v
			nd = d2
	if near == null or nd == 0:
		return -1
	return DetMath.yaw_of(u.x - near.x, u.z - near.z)


## Angular gap of two u8 yaws (0 … 128).
static func _yaw_gap(a: int, b: int) -> int:
	var d: int = posmod(a - b, 256)
	return mini(d, 256 - d)


## (längs, quer) of a point relative to door d: längs from the centre towards the door, quer across.
static func _along_across(d: int, x: int, z: int) -> Vector2i:
	match d:
		1:
			return Vector2i(-z, x)
		2:
			return Vector2i(x, z)
		4:
			return Vector2i(z, x)
	return Vector2i(-x, z)


static func _from_along_across(d: int, along: int, across: int) -> Vector2i:
	match d:
		1:
			return Vector2i(across, -along)
		2:
			return Vector2i(along, across)
		4:
			return Vector2i(across, along)
	return Vector2i(-along, across)


## The point of the circle |p| ≤ geo.r − r nearest to (x, z) (the centre for a set without room).
static func _circle_point(geo: Dictionary, x: int, z: int, r: int) -> Vector2i:
	var big: int = int(geo.get("r", 0)) - r
	if big <= 0:
		return Vector2i.ZERO
	if x * x + z * z <= big * big:
		return Vector2i(x, z)
	var d: int = DetMath.isqrt(x * x + z * z)
	var want: int = big
	var p: Vector2i = Vector2i.ZERO
	for _i in 4:
		p = Vector2i(FixedMath.div_round(x * want, d), FixedMath.div_round(z * want, d))
		if p.x * p.x + p.y * p.y <= big * big:
			return p
		want -= 1
	return p


static func _visible(geo: Dictionary, x: int, z: int) -> bool:
	return in_set(geo, x, z) or in_gap(geo, x, z, 0)
