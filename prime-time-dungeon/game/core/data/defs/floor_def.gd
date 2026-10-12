class_name FloorDef extends RefCounted
## floors.json entry (02_TECH §4.4.7). Immutable after loading.
## `layout` is the normalized layout dictionary (grid coordinates stay [x, y] int arrays,
## offsets/waypoints [x, z] float arrays; use JsonUtil.arr_to_vec2i / arr_to_vec2). {} = procedural floor.
## Staffeln (09 §2.4, §3.6; CR-27; contract pass 4): `theme` may name a Kulisse (thm_, themes.json; kulisse()) instead
## of an art theme, `variant` the floor's place in its Kulisse (1–3; 0 = not stated), `level_band` its level band
## ([from, to]; [] = none) and `zones` its quarters for the generator v2 ([] = the DungeonGenerator as today).
## Nothing reads them outside a season; ST1-C writes the floors 2–18, ST1-D reads the bands.

const KULISSE_PREFIX: String = "thm_"

var id: String = ""
var index: int = 1
var name: String = ""
var playable: bool = true
var theme: String = "metro"                 # art theme (DataValidator.THEMES) or a Kulisse (thm_)
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
# --- Staffeln (contract pass 4) ---
var variant: int = 0                        # place in the Kulisse 1..3 (0 = not stated)
var level_band: PackedInt32Array = []       # [from, to] (1..50) or [] (no band)
var zones: Array[Dictionary] = []           # [{"id", "name", "rooms": {min, max}, "palette", "pool"}] (generator v2)


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
	r.variant = int(d.get("variant", 0))                          # Staffeln (contract pass 4)
	var band: Variant = d.get("level_band", PackedInt32Array())
	if band is PackedInt32Array:                                # the validator's normalized form ("ia")
		r.level_band = (band as PackedInt32Array).duplicate()
	elif band is Array:                                         # a raw JSON entry
		for b: Variant in (band as Array):
			r.level_band.append(int(b))
	for z: Variant in (d.get("zones", []) as Array):
		if z is Dictionary:
			r.zones.append((z as Dictionary).duplicate(true))
	return r


func has_layout() -> bool:
	return not layout.is_empty()


## Staffeln (contract pass 4): the Kulisse of the floor named by `theme` ("" when `theme` is an art theme; the Kulisse
## may still list the floor in themes.json).
func kulisse() -> String:
	return theme if theme.begins_with(KULISSE_PREFIX) else ""


## Staffeln (contract pass 4): the floor has quarters for the generator v2 (09 §3.6).
func has_zones() -> bool:
	return not zones.is_empty()


## Staffeln (contract pass 4): the floor has a level band (09 §2.4).
func has_band() -> bool:
	return level_band.size() == 2


## Staffeln (09 S-14, §11.1; ST1-C): a floor of the seasons' content — its `theme` names its Kulisse. Until "Sendung
## starten" replaces the campaign (SIM_VERSION 5) only a season reaches it: the campaign ends before it as before.
func season_only() -> bool:
	return kulisse() != ""


## Staffeln (ST1-C): the floor has playable content for a run with (`season`) or without a season (playable_in(false)
## is false for every season floor, so the campaign's credits come after floor 1 as before).
func playable_in(season: bool) -> bool:
	return playable and (season or not season_only())


## Encounter of this floor by id (null if this floor does not declare it).
func encounter(enc_id: String) -> EncounterDef:
	for e: EncounterDef in encounters:
		if e.id == enc_id:
			return e
	return null
