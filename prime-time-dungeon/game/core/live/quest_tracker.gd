# STUB(M0) — owned by M8. Replace completely, keep the public API.
class_name QuestTracker extends RefCounted
## Quest progress from normalized events (05 §11.2). Events: {"type": "enemy_killed", "enemy_id"},
## {"type": "boss_defeated", "boss_id"}, {"type": "battle_started"}, {"type": "floor_completed", "floor"},
## {"type": "achievement", "id"}, {"type": "metric", "name", "value": int}.


static func from_def(q: Dictionary) -> QuestTracker:
	return null


## true = progress changed.
func on_event(ev: Dictionary) -> bool:
	return false


func progress() -> float:
	return 0.0


func is_complete() -> bool:
	return false


func to_dict() -> Dictionary:
	return {}


static func from_dict(d: Dictionary) -> QuestTracker:
	return null
