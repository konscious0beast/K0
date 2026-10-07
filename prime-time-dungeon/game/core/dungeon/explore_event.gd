class_name ExploreEvent extends RefCounted
## Serializable exploration events (Brief §6b.2 "events out", 02_TECH §7.1).
## Data conventions used by Game._dispatch: TIMER_SECOND {"seconds": int}, TIMER_WARNING {"seconds": int},
## EXPLORE_TICK {"seconds_since_battle": int}, STRAY_DUE {"zone", "group_id", "encounter_id"}.
## ExplorationScene (M3): ROOM_ENTERED {"cell": [x, y], "kind": String, "first_visit": bool},
## CHEST_OPENED {"chest_id", "rewards": [LootReward.to_dict()]}, ENCOUNTER {"group_id", "encounter_id", "advantage"},
## ENEMY_STATE {"group_id", "state": String}, EVENT_CHOICE {"event_id", "choice", "completed"},
## GATE_OPENED {"key"}, FLOOR_COMPLETED {"floor"}. All data values are JSON types (grid cells as [x, y]).

enum Type { ROOM_ENTERED, CHEST_OPENED, ENCOUNTER, ENEMY_STATE, EVENT_CHOICE, GATE_OPENED, ACHIEVEMENT, HYPE,
	TIMER_SECOND, TIMER_WARNING, TIMER_EXPIRED, EXPLORE_TICK, STRAY_DUE, GIFT_DELIVERED, FLOOR_COMPLETED }
## Serialized names, index == Type value.
const TYPE_NAMES: PackedStringArray = ["room_entered", "chest_opened", "encounter", "enemy_state", "event_choice",
	"gate_opened", "achievement", "hype", "timer_second", "timer_warning", "timer_expired", "explore_tick", "stray_due",
	"gift_delivered", "floor_completed"]

var type: ExploreEvent.Type = Type.ROOM_ENTERED
var tick: int = 0                   # RunSim tick
## e.g. TIMER_WARNING {"seconds": 300}, STRAY_DUE {"zone", "group_id", "encounter_id"}
var data: Dictionary = {}


static func make(t: ExploreEvent.Type, p_tick: int, p_data: Dictionary) -> ExploreEvent:
	var e: ExploreEvent = ExploreEvent.new()
	e.type = t
	e.tick = p_tick
	e.data = p_data.duplicate(true)
	return e


## {"type": "<type name>", "tick": int, "data": Dictionary} — JSON-safe as long as `data` holds JSON types.
func to_dict() -> Dictionary:
	return {"type": type_name(type), "tick": tick, "data": data.duplicate(true)}


## Accepts the type as name ("timer_warning") or number; unknown type / malformed input → null.
static func from_dict(d: Dictionary) -> ExploreEvent:
	if not d.has("type"):
		return null
	var raw: Variant = d["type"]
	var t: int = -1
	if typeof(raw) == TYPE_STRING or typeof(raw) == TYPE_STRING_NAME:
		t = TYPE_NAMES.find(str(raw))
	elif JsonUtil.is_integral(raw):
		t = int(raw)
	if t < 0 or t >= TYPE_NAMES.size():
		return null
	var data_v: Variant = d.get("data", {})
	if typeof(data_v) != TYPE_DICTIONARY:
		return null
	return make(t as ExploreEvent.Type, JsonUtil.to_int(d.get("tick", 0)), data_v)


static func type_name(t: ExploreEvent.Type) -> String:
	var i: int = int(t)
	return TYPE_NAMES[i] if i >= 0 and i < TYPE_NAMES.size() else ""
