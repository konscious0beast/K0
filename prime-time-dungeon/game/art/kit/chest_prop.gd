class_name ChestProp extends Node3D
## Chest with open() (02_TECH §8.5, 03_ART §6.3): body + lid pivot at the rear edge, toon material with outline,
## gold glow inside when open. Built by PropKit.build(&"chest"); style "wood" (default) | "metal" | "locked"
## (art extra set_style(), GDD §2.5 chest types).

signal opened

const LID_OPEN_DEG: float = 110.0
const OPEN_TIME: float = 0.5

var is_open: bool = false
## "wood" | "metal" | "locked"
var chest_type: String = "wood"

var _lid: Node3D = null
var _body: MeshInstance3D = null
var _glow: MeshInstance3D = null
var _seed: int = 0
var _palette: Dictionary = {}
var _tween: Tween = null


## Lid tween 0.5 s + glow; emits opened. Outside the tree: set_open_instant() + opened + push_warning.
func open(animated: bool = true) -> void:
	if is_open:
		opened.emit()
		return
	if not is_inside_tree():
		push_warning("ChestProp.open() outside the tree: opened instantly")
		set_open_instant()
		opened.emit()
		return
	if not animated:
		set_open_instant()
		opened.emit()
		return
	is_open = true
	_ensure_built()
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_lid, "rotation:x", deg_to_rad(LID_OPEN_DEG), OPEN_TIME).set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT)
	_tween.tween_callback(_on_open_finished)
	if _glow != null:
		_glow.visible = true
	var host: Node = get_parent() if get_parent() != null else self
	Vfx.spawn(&"chest_open", host, global_position + Vector3(0, 0.6, 0) * global_transform.basis.get_scale().y,
		_glow_color())


func set_open_instant() -> void:
	_ensure_built()
	if _tween != null and _tween.is_valid():
		_tween.kill()
	is_open = true
	if _lid != null:
		_lid.rotation.x = deg_to_rad(LID_OPEN_DEG)
	if _glow != null:
		_glow.visible = true


## Art extra: rebuilds the chest as "wood" | "metal" | "locked" (keeps the open state).
func set_style(type: String) -> void:
	chest_type = type if type in ["wood", "metal", "locked"] else "wood"
	_clear()
	_build(_seed, _palette)


func _ready() -> void:
	_ensure_built()


func _ensure_built() -> void:
	if _body == null:
		_build(_seed, _palette)


func _on_open_finished() -> void:
	opened.emit()


func _glow_color() -> Color:
	match chest_type:
		"metal":
			return Palette.rarity_color("rare")
		"locked":
			return Palette.rarity_color("epic")
	return Palette.HYPE_GOLD


## Called by PropKit.build(); builds body, lid pivot, inner glow and collision.
func _build(seed: int, palette: Dictionary) -> void:
	_seed = seed
	_palette = palette
	var r: Dictionary = {"parts": [], "collision": []}
	body_parts(r, chest_type)
	var mat: ShaderMaterial = Materials.toon_vc({"bands": 3, "rim": 0.45, "outline_width": 0.02})
	_body = MeshInstance3D.new()
	_body.name = "Body"
	var typed: Array[Dictionary] = []
	typed.assign(r["parts"] as Array)
	_body.mesh = MeshUtil.merge(typed)
	_body.material_override = mat
	add_child(_body)
	_lid = Node3D.new()
	_lid.name = "Lid"
	_lid.position = Vector3(0, 0.45, 0.30)
	add_child(_lid)
	var lid_mesh := MeshInstance3D.new()
	lid_mesh.name = "LidMesh"
	var lt: Array[Dictionary] = []
	lt.assign(lid_parts(chest_type))
	lid_mesh.mesh = MeshUtil.merge(lt)
	lid_mesh.material_override = mat
	_lid.add_child(lid_mesh)
	_glow = MeshInstance3D.new()
	_glow.name = "Glow"
	_glow.mesh = MeshUtil.box(Vector3(0.78, 0.02, 0.48))
	_glow.position = Vector3(0, 0.44, 0)
	_glow.material_override = Materials.glow(_glow_color(), 2.5)
	_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_glow.visible = is_open
	add_child(_glow)
	if is_open:
		_lid.rotation.x = deg_to_rad(LID_OPEN_DEG)
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.9, 0.6, 0.6)
	cs.shape = box
	cs.position = Vector3(0, 0.3, 0)
	body.add_child(cs)
	add_child(body)


func _clear() -> void:
	for c: Node in get_children():
		remove_child(c)
		c.queue_free()
	_body = null
	_lid = null
	_glow = null


## Chest body parts (03_ART §6.3): Box 0.9×0.45×0.6 + bands + 4 corner fittings (metal) + lock plate.
static func body_parts(r: Dictionary, type: String) -> void:
	var body: Color = Palette.WOOD if type == "wood" else Color("#8a8f96")
	var trim: Color = Color("#cd7f32") if type == "wood" else Color("#5a6068")
	var parts: Array = r["parts"]
	parts.append(MeshUtil.part(MeshUtil.box(Vector3(0.9, 0.45, 0.6)), Vector3(0, 0.225, 0), body))
	if type == "wood":
		for y: float in [0.12, 0.33]:
			parts.append(MeshUtil.part(MeshUtil.box(Vector3(0.92, 0.03, 0.62)), Vector3(0, y, 0), Palette.mul(body, 0.75)))
	else:
		for x: float in [-0.3, 0.0, 0.3]:
			parts.append(MeshUtil.part(MeshUtil.box(Vector3(0.04, 0.44, 0.61)), Vector3(x, 0.225, 0), Palette.mul(body, 0.82),
				Vector3.ZERO, Vector3.ONE, 0.0, 1.0))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			parts.append(MeshUtil.part(MeshUtil.box(Vector3(0.08, 0.08, 0.08)), Vector3(0.43 * sx, 0.04, 0.28 * sz), trim,
				Vector3.ZERO, Vector3.ONE, 0.0, 1.0))
			parts.append(MeshUtil.part(MeshUtil.box(Vector3(0.08, 0.08, 0.08)), Vector3(0.43 * sx, 0.41, 0.28 * sz), trim,
				Vector3.ZERO, Vector3.ONE, 0.0, 1.0))
	parts.append(MeshUtil.part(MeshUtil.box(Vector3(0.14, 0.16, 0.03)), Vector3(0, 0.36, -0.31),
		Palette.HYPE_GOLD if type == "wood" else trim, Vector3.ZERO, Vector3.ONE, 0.0, 1.0))
	if type == "locked":
		parts.append(MeshUtil.part(MeshUtil.torus(0.035, 0.055), Vector3(0, 0.30, -0.36), Palette.STEEL, Vector3.ZERO,
			Vector3.ONE, 0.0, 1.0))
		parts.append(MeshUtil.part(MeshUtil.box(Vector3(0.12, 0.10, 0.05)), Vector3(0, 0.24, -0.36), Palette.LIVE_RED,
			Vector3.ZERO, Vector3.ONE, 0.2, 1.0))


## Lid parts relative to the lid pivot at the rear top edge (lid extends toward −Z).
static func lid_parts(type: String) -> Array:
	var body: Color = Palette.WOOD if type == "wood" else Color("#8a8f96")
	var trim: Color = Color("#cd7f32") if type == "wood" else Color("#5a6068")
	var parts: Array = []
	parts.append(MeshUtil.part(MeshUtil.box(Vector3(0.92, 0.15, 0.62)), Vector3(0, 0.075, -0.31), Palette.mul(body, 1.08)))
	parts.append(MeshUtil.part(MeshUtil.box(Vector3(0.94, 0.04, 0.10)), Vector3(0, 0.12, -0.31), Palette.mul(body, 0.75)))
	for sx: float in [-1.0, 1.0]:
		parts.append(MeshUtil.part(MeshUtil.box(Vector3(0.08, 0.17, 0.64)), Vector3(0.43 * sx, 0.075, -0.31), trim,
			Vector3.ZERO, Vector3.ONE, 0.0, 1.0))
	return parts
