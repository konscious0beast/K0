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
# --- Echtzeitkampf (07, R1a): optional `rt` block (07 §4.7), {} = no real-time data; filled by RtNorm ---------------
const RtNorm := preload("res://core/data/defs/rt_norm.gd")
const RT_SPEC: Array = [["default_ms", "i", 3000], ["period_ms", "i", 0], ["tick_pct", "i", 0], ["tick_min", "i", 0],
	["tick_max", "i", 0], ["boss_tick_pm", "i", 1000], ["max_stacks", "i", 1], ["stack_mode", "s", "replace"],
	["move_pm", "i", 1000], ["haste_pm", "i", 1000], ["dmg_dealt_pm", "i", 1000], ["dmg_taken_pm", "i", 1000],
	["boss_ms_pm", "i", 1000], ["flags", "sa", []]]
var rt: Dictionary = {}


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
	r.rt = RtNorm.fill(d.get("rt", {}), RT_SPEC)       # Echtzeitkampf (07, R1a)
	return r


func has_flag(flag: String) -> bool:
	return flags.has(flag)
