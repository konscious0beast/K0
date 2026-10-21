class_name RoomCell extends RefCounted
## One grid cell of a floor (02_TECH §7.1). Grid: x to the east (+X), y to the south (+Z); north = −Z.
## Door bits are symmetric between neighbours (validated by FloorLayout.validate()).

enum Kind { START, NORMAL, SAFE, QUARTER_BOSS, FLOOR_BOSS, STAIRS, GATE }
const DOOR_N: int = 1   # -Z (y - 1)
const DOOR_E: int = 2   # +X (x + 1)
const DOOR_S: int = 4   # +Z (y + 1)
const DOOR_W: int = 8   # -X (x - 1)
## Fixed neighbour order of every algorithm (BFS ties, path, debug output): N, E, S, W.
const DIR_BITS: PackedInt32Array = [DOOR_N, DOOR_E, DOOR_S, DOOR_W]
## Data names of Kind (floors.json `kind`, DataValidator.CELL_KINDS), index == Kind value.
const KIND_NAMES: PackedStringArray = ["start", "normal", "safe", "quarter_boss", "floor_boss", "stairs", "gate"]

var coord: Vector2i = Vector2i.ZERO
var kind: RoomCell.Kind = Kind.NORMAL
var zone: String = ""       # zone id ("" for procedural floors)
var doors: int = 0
var depth: int = 0          # BFS distance from start (gates counted as open)
var variant: int = 0        # 0..3 decoration variant
var on_path: bool = false   # on start→stairs path


static func make(p_coord: Vector2i, p_kind: RoomCell.Kind = Kind.NORMAL, p_zone: String = "",
		p_doors: int = 0) -> RoomCell:
	var c: RoomCell = RoomCell.new()
	c.coord = p_coord
	c.kind = p_kind
	c.zone = p_zone
	c.doors = p_doors
	return c


## "N"/"E"/"S"/"W" → DOOR_* (0 for anything else).
static func dir_bit(dir: String) -> int:
	match dir:
		"N":
			return DOOR_N
		"E":
			return DOOR_E
		"S":
			return DOOR_S
		"W":
			return DOOR_W
	return 0


## DOOR_* → "N"/"E"/"S"/"W" ("" for anything else).
static func dir_letter(bit: int) -> String:
	match bit:
		DOOR_N:
			return "N"
		DOOR_E:
			return "E"
		DOOR_S:
			return "S"
		DOOR_W:
			return "W"
	return ""


## Grid offset of a door bit (N = (0, −1), E = (1, 0), S = (0, 1), W = (−1, 0)).
static func dir_offset(bit: int) -> Vector2i:
	match bit:
		DOOR_N:
			return Vector2i(0, -1)
		DOOR_E:
			return Vector2i(1, 0)
		DOOR_S:
			return Vector2i(0, 1)
		DOOR_W:
			return Vector2i(-1, 0)
	return Vector2i.ZERO


## Door bit on the other side of the same door (N ↔ S, E ↔ W).
static func opposite(bit: int) -> int:
	match bit:
		DOOR_N:
			return DOOR_S
		DOOR_E:
			return DOOR_W
		DOOR_S:
			return DOOR_N
		DOOR_W:
			return DOOR_E
	return 0


## Door bitmask from a "NESW" subset string (unknown letters are ignored).
static func doors_from_string(s: String) -> int:
	var bits: int = 0
	for ch: String in s:
		bits |= dir_bit(ch)
	return bits


## "NESW" subset string of a door bitmask (always in N, E, S, W order).
static func doors_to_string(bits: int) -> String:
	var out: String = ""
	for b: int in DIR_BITS:
		if bits & b:
			out += dir_letter(b)
	return out


## Data name ("start", "normal", …) → Kind; unknown names → NORMAL.
static func kind_from_string(s: String) -> RoomCell.Kind:
	var i: int = KIND_NAMES.find(s)
	return (i if i >= 0 else Kind.NORMAL) as RoomCell.Kind


static func kind_to_string(k: RoomCell.Kind) -> String:
	var i: int = int(k)
	return KIND_NAMES[i] if i >= 0 and i < KIND_NAMES.size() else "normal"


func has_door(bit: int) -> bool:
	return (doors & bit) != 0


func door_count() -> int:
	var n: int = 0
	for b: int in DIR_BITS:
		if doors & b:
			n += 1
	return n


## Dead end (exactly one door).
func is_leaf() -> bool:
	return door_count() == 1


## Cells where no chests, groups or events may stand (start, safe rooms, boss rooms; §7.2 validate()).
func is_reserved() -> bool:
	return kind == Kind.START or kind == Kind.SAFE or kind == Kind.QUARTER_BOSS or kind == Kind.FLOOR_BOSS
