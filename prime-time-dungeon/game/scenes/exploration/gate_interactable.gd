extends "res://scenes/exploration/interactable.gd"
## Gate in a door opening (02_TECH §7.3): PropKit gate + blocking body (layer 1). `requires` is an item id
## (e.g. itm_key_master: interact → Game.open_gate(key), prop removed, Events.gate_opened) or "event:<fev_id>"
## (opened only by that floor event; ExplorationScene.open_gate_visual).

const GATE_WIDTH: float = 4.0
const OPEN_SEC: float = 0.6

var gate: Dictionary = {}
var key: String = ""
var requires: String = ""
var opened: bool = false
var prop: Node3D = null
var _blocker: StaticBody3D = null


## `gate` = FloorLayout.gates entry; the node is placed by the caller in the door opening (local X spans the door).
func setup_gate(p_gate: Dictionary, palette: Dictionary, prop_seed: int) -> void:
	gate = p_gate
	key = str(p_gate.get("key", ""))
	requires = str(p_gate.get("requires", ""))
	interact_id = key
	name = "Gate_" + key.replace(",", "_")
	prop = PropKit.build(&"gate", prop_seed, palette)
	if prop == null:
		prop = Node3D.new()
	if FB.is_empty(prop):
		FB.fill_prop(prop, &"gate", palette)
	prop.name = "Prop"
	add_child(prop)
	_blocker = _make_blocker(Vector3(GATE_WIDTH + 0.4, 3.2, 1.0), Vector3(0.0, 1.6, 0.0))
	_drop_prop_collision(prop)
	_make_area(Rules.INTERACT_RADIUS + GATE_WIDTH * 0.5 + 0.6)


func is_event_gate() -> bool:
	return requires.begins_with("event:")


func prompt_text() -> String:
	if opened:
		return ""
	if is_event_gate():
		return tr("Verriegelt. Irgendwo muss es einen Mechanismus geben.")
	if _has_item(requires):
		return tr("Tor öffnen (%s)") % _item_name(requires)
	return tr("Benötigt: %s") % _item_name(requires)


func interact() -> void:
	if opened:
		return
	if is_event_gate() or not _has_item(requires):
		Sfx.play_ui(&"ui_error")
		return
	Game.open_gate(key)
	if scene != null and scene.has_method("open_gate_visual"):
		scene.call("open_gate_visual", key)
	else:
		open_visual(true)


## Removes the blocking body and lifts the prop away (animated in the tree, instant otherwise).
func open_visual(animated: bool) -> void:
	if opened:
		return
	opened = true
	if _blocker != null:
		_blocker.queue_free()
		_blocker = null
	monitoring = false
	if animated and is_inside_tree():
		Sfx.play(&"door")
		var tw: Tween = create_tween()
		tw.tween_property(prop, "position:y", 3.4, OPEN_SEC).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.tween_callback(func() -> void: prop.visible = false)
	else:
		prop.visible = false


## Both cells of the door.
func occupied_cells(_layout: FloorLayout) -> Array[Vector2i]:
	var c: Vector2i = gate.get("cell", Vector2i.ZERO)
	return [c, c + RoomCell.dir_offset(int(gate.get("dir", RoomCell.DOOR_N)))]


## Closest point on the gate line (local X in ±2 m).
func reach_point(from: Vector3) -> Vector3:
	var local: Vector3 = global_transform.affine_inverse() * from
	return global_transform * Vector3(clampf(local.x, -GATE_WIDTH * 0.5, GATE_WIDTH * 0.5), 0.0, 0.0)
