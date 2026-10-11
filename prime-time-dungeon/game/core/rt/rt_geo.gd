# STUB(R1a) — owned by R1b. Replace completely, keep the public API.
class_name RtGeo extends RefCounted
## Set geometry (07 §3.5.4, §3.5.5): ring, door lanes, blockers, line of sight, shape tests, formation, entry anchors,
## escape points. Pure integer math in room-local cm (DetMath, R1b). The stub returns neutral values (no set, nothing
## walkable, no line of sight); nothing calls it before R1b.


## Set radius of a room kind (RoomCell.Kind): SET_R_CM regular / boss (§3.5.4). Stub: 0.
static func set_radius(_room_kind: int, _bal: RtBalance) -> int:
	return 0


## {"r", "doors", "closed", "blockers"} of a cell (§3.5.4). Stub: {}.
static func make_geo(_cell_kind: int, _doors: int, _closed: bool, _bal: RtBalance) -> Dictionary:
	return {}


## Is (x, z) inside the set (ring or door lane)? Stub: false.
static func in_set(_geo: Dictionary, _x: int, _z: int) -> bool:
	return false


## Can a circle of radius r stand at (x, z) (party: door lanes count as walkable)? Stub: false.
static func walkable(_geo: Dictionary, _x: int, _z: int, _r: int, _party: bool) -> bool:
	return false


## Nearest walkable point (§3.5.3 clamping). Stub: the input point.
static func project_walkable(_geo: Dictionary, x: int, z: int, _r: int, _party: bool) -> Vector2i:
	return Vector2i(x, z)


## Line of sight between two points (blockers only). Stub: false.
static func los(_geo: Dictionary, _ax: int, _az: int, _bx: int, _bz: int) -> bool:
	return false


## Formation slot position around an anchor (§3.5.5). Stub: the anchor.
static func formation(_slot: int, ax: int, az: int, _yaw: int) -> Vector2i:
	return Vector2i(ax, az)


## Entry anchor of a group (§2.3). Stub: the input point.
static func group_anchor(_geo: Dictionary, cx: int, cz: int) -> Vector2i:
	return Vector2i(cx, cz)


## Escape point of a unit leaving a telegraph (§5.5). Stub: Vector2i.ZERO.
static func escape_point(_sim: RtSim, _u: RtUnit) -> Vector2i:
	return Vector2i.ZERO
