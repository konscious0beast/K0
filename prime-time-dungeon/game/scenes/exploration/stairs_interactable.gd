extends "res://scenes/exploration/interactable.gd"
## Stairs down (02_TECH §7.3, GDD §2.8): interact → confirmation "Etage verlassen? …" → Game.complete_floor().
## The stairs prop itself is part of the STAIRS room (EnvKit.build_room); this node is the interaction point at the
## top edge of the flight (anchor &"stairs", steps run towards local −Z).

const STAIRS_WIDTH: float = 4.0

var next_floor: int = 2


func setup_stairs(p_next_floor: int) -> void:
	next_floor = p_next_floor
	interact_id = "stairs"
	name = "Stairs"
	extent = 0.0
	_make_area(Rules.INTERACT_RADIUS + STAIRS_WIDTH * 0.5 + 1.0)


func prompt_text() -> String:
	return tr("Treppe nach unten: Etage verlassen")


func interact() -> void:
	if scene != null and scene.has_method("open_stairs_dialog"):
		scene.call("open_stairs_dialog")


## Closest point on the top edge of the flight (local X in ±2 m, slightly in front of it).
func reach_point(from: Vector3) -> Vector3:
	var local: Vector3 = global_transform.affine_inverse() * from
	return global_transform * Vector3(clampf(local.x, -STAIRS_WIDTH * 0.5, STAIRS_WIDTH * 0.5), 0.0,
		clampf(local.z, -0.2, 0.3))


## The flight is part of the room: the marker floats over its top edge (railing height).
func visual_top() -> float:
	return 1.1
