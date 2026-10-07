# STUB(M0) — owned by M2. Replace completely, keep the public API.
class_name AchievementTracker extends RefCounted
## Achievement evaluation (02_TECH §6.1).


func _init(p_data: GameData, p_show: ShowState, p_flags: Dictionary) -> void:
	pass


## Newly unlocked ids (each id at most once ever).
func evaluate(trigger_id: String, payload: Dictionary) -> PackedStringArray:
	return PackedStringArray()
