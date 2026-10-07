# STUB(M0) — owned by M3. Replace completely, keep the public API.
class_name FloorLayout extends RefCounted
## Result of layout loading / generation (02_TECH §7.1).

const ROOM_SIZE: float = 16.0        # == EnvKit.ROOM_SIZE (test asserts)

var floor_index: int = 1
var seed: int = 0
var width: int = 0
var height: int = 0
var cells: Dictionary = {}           # Vector2i → RoomCell
var start: Vector2i = Vector2i.ZERO
var stairs: Vector2i = Vector2i.ZERO
var quarter_boss: Vector2i = Vector2i(-1, -1)   # (-1,-1) if floor has no quarter boss
var floor_boss: Vector2i = Vector2i(-1, -1)
var safe_rooms: Array[Vector2i] = []
var safe_room_ids: Dictionary = {}   # Vector2i → safe room id ("sr_…"; procedural: "sr_f<i>_<k>")
var safe_room_info: Dictionary = {}  # safe room id → {"cell", "name", "theme", "shop"}
var zones: Dictionary = {}           # zone id → {"name", "palette"} ({} procedural)
var gates: Array[Dictionary] = []    # [{"cell": Vector2i, "dir": int (DOOR_*), "requires": String, "key": "x,y,D"}]
var path: Array[Vector2i] = []       # start … stairs
var chests: Array[ChestSpawn] = []
var enemies: Array[EnemySpawn] = []
var events: Array[EventSpawn] = []
var spawners: Array[Dictionary] = [] # [{"zone", "pool": PackedStringArray, "interval_sec": int}]


func cell_at(c: Vector2i) -> RoomCell:
	return null


## Vector3(c.x * 16.0, 0, c.y * 16.0) = room center.
func cell_to_world(c: Vector2i) -> Vector3:
	return Vector3.ZERO


## roundi(p.x / 16.0), roundi(p.z / 16.0)
func world_to_cell(p: Vector3) -> Vector2i:
	return Vector2i.ZERO


## Via doors; closed gates block.
func neighbors(c: Vector2i, opened_gates: PackedStringArray = []) -> Array[Vector2i]:
	return []


## {} if none.
func gate_at(c: Vector2i, dir: int) -> Dictionary:
	return {}


## Zone palette merged over floor palette.
func zone_palette(c: Vector2i, floor_palette: Dictionary) -> Dictionary:
	return {}


func validate() -> PackedStringArray:
	return PackedStringArray()


## ASCII map: S start, T stairs, Q quarter boss, B floor boss, H safe, G gate, . normal
func to_debug_string() -> String:
	return ""
