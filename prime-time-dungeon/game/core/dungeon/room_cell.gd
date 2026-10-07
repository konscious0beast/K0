# STUB(M0) — owned by M3. Replace completely, keep the public API.
class_name RoomCell extends RefCounted
## One grid cell of a floor (02_TECH §7.1).

enum Kind { START, NORMAL, SAFE, QUARTER_BOSS, FLOOR_BOSS, STAIRS, GATE }
const DOOR_N: int = 1   # -Z (y - 1)
const DOOR_E: int = 2   # +X (x + 1)
const DOOR_S: int = 4   # +Z (y + 1)
const DOOR_W: int = 8   # -X (x - 1)

var coord: Vector2i = Vector2i.ZERO
var kind: RoomCell.Kind = Kind.NORMAL
var zone: String = ""       # zone id ("" for procedural floors)
var doors: int = 0
var depth: int = 0          # BFS distance from start (gates counted as open)
var variant: int = 0        # 0..3 decoration variant
var on_path: bool = false   # on start→stairs path


## "N"/"E"/"S"/"W" → DOOR_*
static func dir_bit(dir: String) -> int:
	return 0
