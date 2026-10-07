# STUB(M0) — owned by M6. Replace completely, keep the public API.
class_name ExplorationHud extends CanvasLayer
## Exploration HUD stub (02_TECH §9.5), instanced by ExplorationScene.


func bind_layout(layout: FloorLayout, visited: Array[Vector2i]) -> void:
	pass


func set_player(cell: Vector2i, yaw_rad: float) -> void:
	pass


func mark_visited(cell: Vector2i) -> void:
	pass


## "" hides; the touch "action" button shows the interact icon while a prompt is set.
func set_prompt(text: String) -> void:
	pass


## Event runs only (Game.mode == &"event_offline"); "" hides.
func set_quest(text: String, progress: float) -> void:
	pass
