# STUB(M0) — owned by M3. Replace completely, keep the public API.
class_name ExploreEvent extends RefCounted
## Serializable exploration events (Brief §6b.2 "events out", 02_TECH §7.1).
## Data conventions used by Game._dispatch: TIMER_SECOND {"seconds": int}, TIMER_WARNING {"seconds": int},
## EXPLORE_TICK {"seconds_since_battle": int}, STRAY_DUE {"zone", "group_id", "encounter_id"}.

enum Type { ROOM_ENTERED, CHEST_OPENED, ENCOUNTER, ENEMY_STATE, EVENT_CHOICE, GATE_OPENED, ACHIEVEMENT, HYPE,
	TIMER_SECOND, TIMER_WARNING, TIMER_EXPIRED, EXPLORE_TICK, STRAY_DUE, GIFT_DELIVERED, FLOOR_COMPLETED }

var type: ExploreEvent.Type = Type.ROOM_ENTERED
var tick: int = 0                   # RunSim tick
var data: Dictionary = {}           # e.g. TIMER_WARNING {"seconds": 300}, STRAY_DUE {"zone", "group_id", "encounter_id"}


static func make(t: ExploreEvent.Type, p_tick: int, p_data: Dictionary) -> ExploreEvent:
	return null


func to_dict() -> Dictionary:
	return {}


static func from_dict(d: Dictionary) -> ExploreEvent:
	return null
