# STUB(M0) — owned by M6. Replace completely, keep the public API.
class_name SafeRoomScene extends Node3D
## Safe room screen stub (02_TECH §9.5).

var _params: Dictionary = {}


## Stores params only: {"safe_room_id": String}; missing → first safe room of the floor.
func setup(params: Dictionary) -> void:
	_params = params
