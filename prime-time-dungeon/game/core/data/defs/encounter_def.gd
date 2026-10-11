class_name EncounterDef extends RefCounted
## Encounter embedded in floors.json (02_TECH §4.4.7). Immutable after loading.

var id: String = ""
var enemies: PackedStringArray = []         # 1..4 enemy ids, slot order
var weight: int = 10
var min_depth: float = 0.0
var max_depth: float = 1.0
var boss: bool = false
var can_flee: bool = true                   # default: not boss
var tutorial: bool = false
var music: String = ""                      # "" → battle / boss
var floor_index: int = 0                    # floor that declares this encounter (set by GameData)
# --- Echtzeitkampf (07, R1a): optional blocks (07 §4.9, §9.6) --------------------------------------------------------
const RtNorm := preload("res://core/data/defs/rt_norm.gd")
## {"enemies": [ids] ([] = the CTB list), "music": String, "tutorial": [steps]}; {} = no real-time data.
const RT_SPEC: Array = [["enemies", "sa", []], ["music", "s", ""], ["tutorial", "sa", []]]
var rt: Dictionary = {}
## Show boss (06 §2.6, 07 §9.6 E26): {} = none, else {"elite_pm", "banner_tag", "reward": {"kind", "id"}, "rule":
## RtRule} as in the data (rules: validators/show_boss.gd, R4; mods: RtMods.from_show_boss, R1b).
var show_boss: Dictionary = {}


static func from_dict(d: Dictionary) -> EncounterDef:
	var r: EncounterDef = EncounterDef.new()
	r.id = str(d.get("id", ""))
	r.enemies = JsonUtil.to_str_array(d.get("enemies", []))
	r.weight = int(d.get("weight", 10))
	r.min_depth = float(d.get("min_depth", 0.0))
	r.max_depth = float(d.get("max_depth", 1.0))
	r.boss = bool(d.get("boss", false))
	r.can_flee = bool(d.get("can_flee", not r.boss))
	r.tutorial = bool(d.get("tutorial", false))
	r.music = str(d.get("music", ""))
	r.floor_index = int(d.get("floor_index", 0))
	r.rt = RtNorm.fill(d.get("rt", {}), RT_SPEC)       # Echtzeitkampf (07, R1a)
	var sb: Variant = d.get("show_boss", {})
	r.show_boss = RtNorm.ints(sb) if sb is Dictionary else {}
	return r
