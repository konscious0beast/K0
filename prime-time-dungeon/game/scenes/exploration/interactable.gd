extends Area3D
## Base interaction area of the exploration (02_TECH §7.3): Area3D on layer 4 `interact`, mask 2 `player`.
## The area is the broad phase (tracks whether Kai is near); ExplorationScene picks the focused interactable with the
## exact rule "within 1.5 m (+ extent) and inside the 120° cone in front of Kai" and calls interact() on `action`.
## Subclasses (chest/gate/event/stairs/safe door) override prompt_text() and interact(), optionally reach_point().

const Rules := preload("res://scenes/exploration/encounter_rules.gd")
const FB := preload("res://scenes/exploration/fallback_art.gd")
const LAYER_INTERACT: int = 8      # physics layer 4 "interact"
const MASK_PLAYER: int = 2         # physics layer 2 "player"
const LAYER_WORLD: int = 1         # physics layer 1 "world" (blocking bodies of props)
const KEY_ITEM: String = "itm_key_master"

var interact_id: String = ""
var extent: float = 0.0            # object half size added to the reach (chests, gates, stairs)
var scene: Node = null             # owning ExplorationScene (duck-typed callbacks)
var player_inside: bool = false
var _top_cache: float = -1.0


func _init() -> void:
	collision_layer = LAYER_INTERACT
	collision_mask = MASK_PLAYER
	monitoring = true
	monitorable = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


## Adds the broad-phase sphere (reach + extent + margin).
func _make_area(radius: float) -> void:
	var cs: CollisionShape3D = CollisionShape3D.new()
	cs.name = "Reach"
	var sph: SphereShape3D = SphereShape3D.new()
	sph.radius = radius
	cs.shape = sph
	cs.position = Vector3(0.0, 0.9, 0.0)
	add_child(cs)


## Static blocking body (layer 1) so Kai cannot walk through the object.
func _make_blocker(size: Vector3, pos: Vector3) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "Blocker"
	body.collision_layer = LAYER_WORLD
	body.collision_mask = 0
	var cs: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	cs.shape = box
	cs.position = pos
	body.add_child(cs)
	add_child(body)
	return body


## The interactable's Blocker decides what blocks: the art prop's own "Collision" body (PropKit / ChestProp) would be a
## second static body for the same object (02_TECH §12.1 Physik) → removed. Gates: opening then frees every blocking
## shape at once (before, the lifted prop kept its body).
func _drop_prop_collision(prop_node: Node) -> void:
	if prop_node == null:
		return
	var body: StaticBody3D = prop_node.get_node_or_null("Collision") as StaticBody3D
	if body != null:
		prop_node.remove_child(body)
		body.free()


func _on_body_entered(body: Node3D) -> void:
	if body != null and body.has_method("is_player_body"):
		player_inside = true


func _on_body_exited(body: Node3D) -> void:
	if body != null and body.has_method("is_player_body"):
		player_inside = false


## Prompt shown in the HUD while focused; "" = nothing to do (not focusable).
func prompt_text() -> String:
	return ""


func is_available() -> bool:
	return prompt_text() != ""


## Called by ExplorationScene on `action` while focused.
func interact() -> void:
	pass


## Focus highlight: cyan outline pass (material_overlay) on every mesh of the object's visuals.
func set_highlight(on: bool) -> void:
	for n: Node in get_children():
		if n is Node3D and not n is CollisionObject3D:
			FB.set_highlight(n, on)


## World point the focus marker floats above (top of the visuals).
func marker_position() -> Vector3:
	return global_position + Vector3(0.0, visual_top(), 0.0)


## Local height of the object's visual top (merged mesh AABBs of the children, cached; at least 0.6 m).
func visual_top() -> float:
	if _top_cache < 0.0:
		_top_cache = maxf(0.6, _max_mesh_y(self, Transform3D.IDENTITY))
	return _top_cache


static func _max_mesh_y(n: Node, xf: Transform3D) -> float:
	var top: float = 0.0
	for c: Node in n.get_children():
		if not c is Node3D or c is CollisionObject3D:
			continue
		var cx: Transform3D = xf * (c as Node3D).transform
		if c is MeshInstance3D and (c as MeshInstance3D).mesh != null and (c as Node3D).visible:
			top = maxf(top, (cx * (c as MeshInstance3D).mesh.get_aabb()).end.y)
		top = maxf(top, _max_mesh_y(c, cx))
	return top


## Cells the object is seen from (room visibility); gates override (they sit between two cells).
func occupied_cells(layout: FloorLayout) -> Array[Vector2i]:
	return [layout.world_to_cell(global_position)]


## Closest point of the object to `from` (XZ distance / cone tests).
func reach_point(_from: Vector3) -> Vector3:
	return global_position


func reach_distance(from: Vector3) -> float:
	return maxf(0.0, Rules.flat_dist(from, reach_point(from)) - extent)


## Exact focus rule (§7.3): within INTERACT_RADIUS (+ extent) and inside the 120° cone in front of Kai.
func can_reach(from: Vector3, fwd: Vector3) -> bool:
	if reach_distance(from) > Rules.INTERACT_RADIUS:
		return false
	var p: Vector3 = reach_point(from)
	if Rules.flat_dist(from, p) < 0.35:
		return true
	return Rules.in_arc(from, fwd, p, INF, Rules.INTERACT_CONE_DEG)


func _has_item(item_id: String) -> bool:
	return Game.state != null and Game.state.inventory != null and Game.state.inventory.has(item_id)


static func _item_name(item_id: String) -> String:
	if DB.has_id("items", item_id):
		return tr_static(DB.item(item_id).name)
	return item_id


static func tr_static(text: String) -> String:
	return TranslationServer.translate(text)
