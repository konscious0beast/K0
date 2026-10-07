class_name StatusDef extends RefCounted
## statuses.json entry (02_TECH §4.4.1). Immutable after loading.

var id: String = ""
var name: String = ""
var kind: String = "debuff"
var default_turns: int = 3
var stat_mult: Dictionary = {}              # stat key (no hp/mp) → float
var tick_timing: String = "turn_end"
var tick_pct: int = 0
var tick_min: int = 0
var tick_speed_mult: float = 1.0
var flags: PackedStringArray = []
var excludes: PackedStringArray = []
var element: String = "none"
var color: String = "#ffffff"
var icon: String = ""


## Expects a normalized dict (GameData/DataValidator output).
static func from_dict(d: Dictionary) -> StatusDef:
	var r: StatusDef = StatusDef.new()
	r.id = str(d.get("id", ""))
	r.name = str(d.get("name", ""))
	r.kind = str(d.get("kind", "debuff"))
	r.default_turns = int(d.get("default_turns", 3))
	r.stat_mult = (d.get("stat_mult", {}) as Dictionary).duplicate(true)
	r.tick_timing = str(d.get("tick_timing", "turn_end"))
	r.tick_pct = int(d.get("tick_pct", 0))
	r.tick_min = int(d.get("tick_min", 0))
	r.tick_speed_mult = float(d.get("tick_speed_mult", 1.0))
	r.flags = JsonUtil.to_str_array(d.get("flags", []))
	r.excludes = JsonUtil.to_str_array(d.get("excludes", []))
	r.element = str(d.get("element", "none"))
	r.color = str(d.get("color", "#ffffff"))
	r.icon = str(d.get("icon", ""))
	return r


func has_flag(flag: String) -> bool:
	return flags.has(flag)
