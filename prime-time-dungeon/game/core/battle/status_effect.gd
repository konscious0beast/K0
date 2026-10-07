# STUB(M0) — owned by M1. Replace completely, keep the public API.
class_name StatusEffect extends RefCounted
## Active status on a combatant (02_TECH §5.4).

var def: StatusDef = null
var turns_left: int = 0
var source_id: String = ""


func _init(p_def: StatusDef, p_turns: int, p_source_id: String) -> void:
	def = p_def
	turns_left = p_turns
	source_id = p_source_id


func id() -> String:
	return ""
