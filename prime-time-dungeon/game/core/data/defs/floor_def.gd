class_name FloorDef extends RefCounted
## floors.json entry (02_TECH §4.4.7). Immutable after loading.
## `layout` is the normalized layout dictionary (grid coordinates stay [x, y] int arrays,
## offsets/waypoints [x, z] float arrays; use JsonUtil.arr_to_vec2i / arr_to_vec2). {} = procedural floor.

var id: String = ""
var index: int = 1
var name: String = ""
var playable: bool = true
var theme: String = "metro"
var timer_seconds: int = 1200
var timer_warnings: PackedInt32Array = [600, 300, 60]
var timer_start_after: String = ""
var floor_mult: float = 1.0
var grid: Dictionary = {"w": 8, "h": 8}
var layout: Dictionary = {}
var rooms: Dictionary = {"min": 0, "max": 0}
var safe_rooms: int = 1
var chests: Dictionary = {"min": 0, "max": 0}
var enemy_groups: Dictionary = {"min": 0, "max": 0}
var chest_table: Array[Dictionary] = []     # [{"kind", "id", "weight", "min", "max"}]
var shop: PackedStringArray = []
var quarter_boss: String = ""
var floor_boss: String = ""
var encounters: Array[EncounterDef] = []
var palette: Dictionary = {}                # floor, wall, accent, light, fog, ambient → hex (theme defaults filled in)
var music: String = "explore"
var quest: Dictionary = {}
var window: Dictionary = {}


static func from_dict(d: Dictionary) -> FloorDef:
	var r: FloorDef = FloorDef.new()
	r.id = str(d.get("id", ""))
	r.index = int(d.get("index", 1))
	r.name = str(d.get("name", ""))
	r.playable = bool(d.get("playable", true))
	r.theme = str(d.get("theme", "metro"))
	r.timer_seconds = int(d.get("timer_seconds", 1200))
	var tw: Variant = d.get("timer_warnings", PackedInt32Array([600, 300, 60]))
	r.timer_warnings = PackedInt32Array(tw)
	r.timer_start_after = str(d.get("timer_start_after", ""))
	r.floor_mult = float(d.get("floor_mult", 1.0))
	r.grid = (d.get("grid", {"w": 8, "h": 8}) as Dictionary).duplicate(true)
	r.layout = (d.get("layout", {}) as Dictionary).duplicate(true)
	r.rooms = (d.get("rooms", {"min": 0, "max": 0}) as Dictionary).duplicate(true)
	r.safe_rooms = int(d.get("safe_rooms", 1))
	r.chests = (d.get("chests", {"min": 0, "max": 0}) as Dictionary).duplicate(true)
	r.enemy_groups = (d.get("enemy_groups", {"min": 0, "max": 0}) as Dictionary).duplicate(true)
	r.chest_table.assign((d.get("chest_table", []) as Array).duplicate(true))
	r.shop = JsonUtil.to_str_array(d.get("shop", []))
	r.quarter_boss = str(d.get("quarter_boss", ""))
	r.floor_boss = str(d.get("floor_boss", ""))
	for e: Variant in (d.get("encounters", []) as Array):
		if e is EncounterDef:
			r.encounters.append(e as EncounterDef)
		elif e is Dictionary:
			var ed: Dictionary = (e as Dictionary).duplicate()
			ed["floor_index"] = r.index
			r.encounters.append(EncounterDef.from_dict(ed))
	r.palette = (d.get("palette", {}) as Dictionary).duplicate(true)
	r.music = str(d.get("music", "explore"))
	r.quest = (d.get("quest", {}) as Dictionary).duplicate(true)
	r.window = (d.get("window", {}) as Dictionary).duplicate(true)
	return r


func has_layout() -> bool:
	return not layout.is_empty()


## Encounter of this floor by id (null if this floor does not declare it).
func encounter(enc_id: String) -> EncounterDef:
	for e: EncounterDef in encounters:
		if e.id == enc_id:
			return e
	return null
