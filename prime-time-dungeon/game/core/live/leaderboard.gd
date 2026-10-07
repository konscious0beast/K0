# STUB(M0) — owned by M8. Replace completely, keep the public API.
class_name Leaderboard extends RefCounted
## Local top 10 (05 §10.4).


## Rank, 1-based; top 10 kept.
func add(entry: Dictionary) -> int:
	return 0


func top(n: int) -> Array[Dictionary]:
	return []


static func is_better(a: Dictionary, b: Dictionary) -> bool:
	return false


func to_dict() -> Dictionary:
	return {}


## Corrupt → empty.
static func from_dict(d: Dictionary) -> Leaderboard:
	return null
