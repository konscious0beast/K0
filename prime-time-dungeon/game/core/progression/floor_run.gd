class_name FloorRun extends RefCounted
## State of the current floor (02_TECH §6.1). Timer in whole ticks (Game.TICKS_PER_SEC = 30, 05 CR-3).
##
## `seed` is the (public) layout seed; `loot_seed` (05 CR-11) is the separate seed for loot contents (chests),
## offline SeedUtil.derive(run_seed, "loot", index), so knowing the layout does not reveal chest contents.

const TICKS_PER_SEC: int = 30          # == Game.TICKS_PER_SEC (core must not reference autoloads)
const EASY_TIMER_MULT: float = 1.5     # == Balance.EASY_TIMER_MULT (Vorabendprogramm)

var floor_id: String = ""
var index: int = 1
var seed: int = 0                      # SeedUtil.derive(run_seed, "floor", index)
var loot_seed: int = 0                 # SeedUtil.derive(run_seed, "loot", index) (05 CR-11)
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
	if def == null:
		return null
	var fr: FloorRun = FloorRun.new()
	fr.floor_id = def.id
	fr.index = def.index
	fr.seed = SeedUtil.derive(run_seed, "floor", def.index)
	fr.loot_seed = SeedUtil.derive(run_seed, "loot", def.index)
	var mult: float = EASY_TIMER_MULT if difficulty == &"vorabend" else 1.0
	fr.time_left_ticks = roundi(def.timer_seconds * mult * TICKS_PER_SEC)
	fr.timer_started = def.timer_start_after == ""
	return fr


## Display only.
func time_left_sec() -> float:
	return time_left_ticks / float(TICKS_PER_SEC)


## Counts down `n` ticks (never below 0; stops at 0), adds them to stats.time_used_ticks.
## {"second_changed": bool (the whole second floor(ticks / 30) changed), "warnings": PackedInt32Array (values of
##  `warnings` crossed now and not fired before, descending; appended to `warned`), "expired": bool (reached 0 now)}.
func tick_timer(n: int, warnings: PackedInt32Array) -> Dictionary:
	var out: Dictionary = {"second_changed": false, "warnings": PackedInt32Array(), "expired": false}
	if n <= 0 or time_left_ticks <= 0:
		return out
	var before: int = time_left_ticks
	var used: int = mini(n, before)
	time_left_ticks = before - used
	stats["time_used_ticks"] = int(stats.get("time_used_ticks", 0)) + used
	out["second_changed"] = before / TICKS_PER_SEC != time_left_ticks / TICKS_PER_SEC
	var fired: PackedInt32Array = []
	var sorted: PackedInt32Array = warnings.duplicate()
	sorted.sort()
	sorted.reverse()
	for w: int in sorted:
		var at: int = w * TICKS_PER_SEC
		if before > at and time_left_ticks <= at and not warned.has(w):
			warned.append(w)
			fired.append(w)
	out["warnings"] = fired
	out["expired"] = time_left_ticks == 0
	return out


## {"floor", "time_used_sec", "time_left_sec", "kills", "viewers_peak", "followers_gained", "achievements"}
func summary() -> Dictionary:
	return {
		"floor": index,
		"time_used_sec": int(stats.get("time_used_ticks", 0)) / TICKS_PER_SEC,
		"time_left_sec": time_left_ticks / TICKS_PER_SEC,
		"kills": int(stats.get("kills", 0)),
		"viewers_peak": int(stats.get("viewers_peak", 0)),
		"followers_gained": int(stats.get("followers_gained", 0)),
		"achievements": int(stats.get("achievements", 0)),
	}


func to_dict() -> Dictionary:
	var cells: Array = []
	for c: Vector2i in visited:
		cells.append(JsonUtil.vec2i_to_arr(c))
	var stray_out: Dictionary = {}
	for g: Variant in _sorted_keys(strays):
		var s: Variant = strays[g]
		var sd: Dictionary = s if s is Dictionary else {}
		stray_out[str(g)] = {"zone": str(sd.get("zone", "")), "enc": str(sd.get("enc", ""))}
	return {
		"floor_id": floor_id,
		"index": index,
		"seed": seed,
		"loot_seed": loot_seed,
		"time_left_ticks": time_left_ticks,
		"timer_started": timer_started,
		"warned": Array(warned),
		"decay_ticks": decay_ticks,
		"visited": cells,
		"opened_chests": Array(opened_chests),
		"defeated_groups": Array(defeated_groups),
		"opened_gates": Array(opened_gates),
		"completed_events": Array(completed_events),
		"event_uses": _int_dict(event_uses),
		"strays": stray_out,
		"stray_counter": stray_counter,
		"spawner_ticks": _int_dict(spawner_ticks),
		"quarter_boss_defeated": quarter_boss_defeated,
		"floor_boss_defeated": floor_boss_defeated,
		"stairs_found": stairs_found,
		"location": String(location),
		"visited_safe_rooms": Array(visited_safe_rooms),
		"safe_room_visits": safe_room_visits,
		"stats": _int_dict(stats),
	}


## Missing fields → defaults; numbers converted with int(); `loot_seed` missing (save before CR-11) → -1, the
## caller (GameState.from_dict) derives it from the run seed. null without a floor id.
static func from_dict(d: Dictionary) -> FloorRun:
	var fid: String = str(d.get("floor_id", ""))
	if fid == "":
		return null
	var fr: FloorRun = FloorRun.new()
	fr.floor_id = fid
	fr.index = maxi(1, JsonUtil.to_int(d.get("index", 1), 1))
	fr.seed = JsonUtil.to_int(d.get("seed", 0))
	fr.loot_seed = JsonUtil.to_int(d.get("loot_seed", -1), -1)
	fr.time_left_ticks = maxi(0, JsonUtil.to_int(d.get("time_left_ticks", 0)))
	fr.timer_started = bool(d.get("timer_started", false))
	var w: PackedInt32Array = []
	var raw_w: Variant = d.get("warned", [])
	if raw_w is Array:
		for v: Variant in raw_w:
			if JsonUtil.is_number(v) and not w.has(int(v)):
				w.append(int(v))
	fr.warned = w
	fr.decay_ticks = maxi(0, JsonUtil.to_int(d.get("decay_ticks", 0)))
	var raw_v: Variant = d.get("visited", [])
	if raw_v is Array:
		for c: Variant in raw_v:
			var cell: Vector2i = JsonUtil.arr_to_vec2i(c, Vector2i(-999, -999))
			if cell != Vector2i(-999, -999) and not fr.visited.has(cell):
				fr.visited.append(cell)
	fr.opened_chests = JsonUtil.to_str_array(d.get("opened_chests", []))
	fr.defeated_groups = JsonUtil.to_str_array(d.get("defeated_groups", []))
	fr.opened_gates = JsonUtil.to_str_array(d.get("opened_gates", []))
	fr.completed_events = JsonUtil.to_str_array(d.get("completed_events", []))
	var raw_uses: Variant = d.get("event_uses", {})
	if raw_uses is Dictionary:
		fr.event_uses = _int_dict(raw_uses)
	var raw_strays: Variant = d.get("strays", {})
	if raw_strays is Dictionary:
		for g: Variant in _sorted_keys(raw_strays):
			var s: Variant = (raw_strays as Dictionary)[g]
			if s is Dictionary:
				fr.strays[str(g)] = {"zone": str((s as Dictionary).get("zone", "")), "enc": str((s as Dictionary).get("enc", ""))}
	fr.stray_counter = maxi(0, JsonUtil.to_int(d.get("stray_counter", 0)))
	var raw_sp: Variant = d.get("spawner_ticks", {})
	if raw_sp is Dictionary:
		fr.spawner_ticks = _int_dict(raw_sp)
	fr.quarter_boss_defeated = bool(d.get("quarter_boss_defeated", false))
	fr.floor_boss_defeated = bool(d.get("floor_boss_defeated", false))
	fr.stairs_found = bool(d.get("stairs_found", false))
	var loc: String = str(d.get("location", "start"))
	fr.location = StringName(loc if loc != "" else "start")
	fr.visited_safe_rooms = JsonUtil.to_str_array(d.get("visited_safe_rooms", []))
	fr.safe_room_visits = maxi(0, JsonUtil.to_int(d.get("safe_room_visits", 0)))
	var st: Dictionary = {"time_used_ticks": 0, "kills": 0, "viewers_peak": 0, "followers_gained": 0, "achievements": 0}
	var raw_st: Variant = d.get("stats", {})
	if raw_st is Dictionary:
		for k: Variant in _sorted_keys(raw_st):
			st[str(k)] = JsonUtil.to_int((raw_st as Dictionary)[k])
	fr.stats = st
	return fr


## Original keys, sorted by their String form (deterministic iteration, 05 §3.3 Nr. 6).
static func _sorted_keys(src: Dictionary) -> Array:
	var keys: Array = src.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
	return keys


static func _int_dict(src: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in _sorted_keys(src):
		out[str(k)] = JsonUtil.to_int(src[k])
	return out
