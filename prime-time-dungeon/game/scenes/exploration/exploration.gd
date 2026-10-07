# STUB(M0) — owned by M3. Replace completely, keep the public API.
class_name ExplorationScene extends Node3D
## Exploration screen stub (02_TECH §7.3).

var _params: Dictionary = {}


## Stores params only: {"spawn": &"start" | &"<safe room id>", "capture": bool}
func setup(params: Dictionary) -> void:
	_params = params


## Game.timer_running = false; release pressed move actions.
func on_suspend() -> void:
	pass


## {"battle_result": BattleResult} | {"from_safe_room": "<sr id>"}
func on_resume(payload: Dictionary) -> void:
	pass


## "" → nearest living non-boss group; same path as contact (NORMAL).
func force_encounter(group_id: String = "") -> void:
	pass


func get_layout() -> FloorLayout:
	return null


func get_player_position() -> Vector3:
	return Vector3.ZERO


func get_player_cell() -> Vector2i:
	return Vector2i.ZERO
