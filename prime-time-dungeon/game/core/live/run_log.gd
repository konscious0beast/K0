# STUB(M0) — owned by M8. Replace completely, keep the public API.
class_name RunLog extends RefCounted
## Seed + commands + ticks of one run (Brief §6b.3, 05 §10.6).

var header: Dictionary = {}


func add_cmd(tick: int, cmd: Dictionary, cmd_id: int = 0) -> void:
	pass


## 2 Hz position samples (grade A).
func add_pos(tick: int, pos: Vector3) -> void:
	pass


func add_checkpoint(tick: int, p_hash: String) -> void:
	pass


func cmds() -> Array[Dictionary]:
	return []


func to_dict() -> Dictionary:
	return {}


static func from_dict(d: Dictionary) -> RunLog:
	return null


func digest() -> String:
	return ""
