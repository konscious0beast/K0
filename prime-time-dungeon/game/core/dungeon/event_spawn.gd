class_name EventSpawn extends RefCounted
## Floor event placement (02_TECH §7.1); rules in FloorEvent (§7.4).

var id: String = ""              # "fev_wheel"
var type: String = ""            # FLOOR_EVENT_TYPES
var cell: Vector2i = Vector2i.ZERO
var offset: Vector2 = Vector2.ZERO
var params: Dictionary = {}


func to_dict() -> Dictionary:
	return {"id": id, "type": type, "cell": [cell.x, cell.y], "offset": [offset.x, offset.y],
		"params": params.duplicate(true)}
