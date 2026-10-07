# STUB(M0) — owned by M2. Replace completely, keep the public API.
class_name FloorRun extends RefCounted
## State of the current floor (02_TECH §6.1). Timer in whole ticks (Game.TICKS_PER_SEC = 30, 05 CR-3).

var floor_id: String = ""
var index: int = 1
var seed: int = 0                      # SeedUtil.derive(run_seed, "floor", index)
var time_left_ticks: int = 0           # Game.TICKS_PER_SEC = 30 (05 CR-3)
var timer_started: bool = false        # FloorDef.timer_start_after == "" → true at creation
var warned: PackedInt32Array = []      # timer warnings already fired (seconds)
var decay_ticks: int = 0               # hype decay accumulator (ShowModel.HYPE_DECAY_TICKS)
var visited: Array[Vector2i] = []
var opened_chests: PackedStringArray = []
var defeated_groups: PackedStringArray = []
var opened_gates: PackedStringArray = []      # "<x>,<y>,<N|E|S|W>"
var completed_events: PackedStringArray = []  # fev ids
var event_uses: Dictionary = {}               # fev id → int (wheel spins)
var strays: Dictionary = {}                   # living strays: group id → {"zone": String, "enc": String}
var stray_counter: int = 0
var spawner_ticks: Dictionary = {}            # zone id → ticks since the zone had no living stray
var quarter_boss_defeated: bool = false
var floor_boss_defeated: bool = false
var stairs_found: bool = false
var location: StringName = &"start"           # &"start" | safe room id (e.g. &"sr_kiosk")
var visited_safe_rooms: PackedStringArray = []
var safe_room_visits: int = 0                 # total entries on this floor (scene conditions)
var stats: Dictionary = {"time_used_ticks": 0, "kills": 0, "viewers_peak": 0, "followers_gained": 0, "achievements": 0}


## time_left_ticks = roundi(def.timer_seconds × (difficulty == &"vorabend" ? 1.5 : 1.0) × 30)
static func create(def: FloorDef, run_seed: int, difficulty: StringName) -> FloorRun:
	# M0 stub: minimal VALID floor run (02_TECH §0.2) so that scenes/tests of other modules work before M2 delivers.
	if def == null:
		return null
	var fr: FloorRun = FloorRun.new()
	fr.floor_id = def.id
	fr.index = def.index
	fr.seed = SeedUtil.derive(run_seed, "floor", def.index)
	fr.time_left_ticks = roundi(def.timer_seconds * (1.5 if difficulty == &"vorabend" else 1.0) * 30)
	fr.timer_started = def.timer_start_after == ""
	return fr


func time_left_sec() -> float:
	return time_left_ticks / 30.0


## {"second_changed": bool, "warnings": PackedInt32Array, "expired": bool}
func tick_timer(n: int, warnings: PackedInt32Array) -> Dictionary:
	return {}


## {"floor", "time_used_sec", "time_left_sec", "kills", "viewers_peak", "followers_gained", "achievements"}
func summary() -> Dictionary:
	# M0 stub: complete key set (FloorSummary may index every key).
	return {"floor": index, "time_used_sec": int(stats.get("time_used_ticks", 0)) / 30,
		"time_left_sec": time_left_ticks / 30, "kills": int(stats.get("kills", 0)),
		"viewers_peak": int(stats.get("viewers_peak", 0)), "followers_gained": int(stats.get("followers_gained", 0)),
		"achievements": int(stats.get("achievements", 0))}


func to_dict() -> Dictionary:
	return {}


static func from_dict(d: Dictionary) -> FloorRun:
	return null
