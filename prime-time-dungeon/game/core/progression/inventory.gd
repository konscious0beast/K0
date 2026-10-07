# STUB(M0) — owned by M2. Replace completely, keep the public API.
class_name Inventory extends RefCounted
## Items + credits (02_TECH §6.1).

var counts: Dictionary = {}            # item id → int > 0 (equipped items are NOT counted)
var credits: int = 0


## Returns how many were actually added (cap max_stack).
func add(item_id: String, n: int = 1, max_stack: int = 9) -> int:
	return 0


func remove(item_id: String, n: int = 1) -> bool:
	return false


func count(item_id: String) -> int:
	return 0


func has(item_id: String, n: int = 1) -> bool:
	return false


func ids_of_type(data: GameData, type: String) -> PackedStringArray:
	return PackedStringArray()


## e.g. "heal" for fev_lost_candidate.
func ids_with_tag(data: GameData, tag: String) -> PackedStringArray:
	return PackedStringArray()


func battle_items(data: GameData) -> Dictionary:
	return {}


func add_credits(n: int) -> void:
	pass


func spend_credits(n: int) -> bool:
	return false


func to_dict() -> Dictionary:
	return {}


static func from_dict(d: Dictionary) -> Inventory:
	return null
