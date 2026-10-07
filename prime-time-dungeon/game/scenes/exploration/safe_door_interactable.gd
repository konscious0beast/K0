extends "res://scenes/exploration/interactable.gd"
## Safe-room door (02_TECH §7.3): carries the safe room id; interact → Router.enter_safe_room(id) (the SafeRoomScene
## calls Game.enter_safe_room). The door prop is part of the SAFE room (EnvKit.build_room, anchor &"safe_door").

var safe_room_id: String = ""
var display_name: String = ""


func setup_door(p_id: String, p_name: String) -> void:
	safe_room_id = p_id
	display_name = p_name
	interact_id = p_id
	name = "SafeDoor_" + p_id
	extent = 0.9
	_make_area(Rules.INTERACT_RADIUS + extent + 0.8)


func prompt_text() -> String:
	if display_name == "":
		return tr("Safe Room betreten")
	return tr("Safe Room betreten: %s") % tr(display_name)


func interact() -> void:
	if scene != null and scene.has_method("enter_safe_room"):
		scene.call("enter_safe_room", safe_room_id)
