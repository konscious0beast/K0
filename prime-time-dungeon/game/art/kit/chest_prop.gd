class_name ChestProp extends Node3D
## Chest with open() (02_TECH §8.5, 03_ART §6.3): body + lid pivot at the rear edge, toon material with outline,
## gold glow inside when open. Built by PropKit.build(&"chest"); style "wood" (default) | "metal" | "locked"
## (art extra set_style(), GDD §2.5 chest types).

signal opened

const LID_OPEN_DEG: float = 110.0
const OPEN_TIME: float = 0.5
const BRASS_TRIM: Color = Color("#cd7f32")
const DARK_KEYHOLE: Color = Color("#1a1420")
## Idle glint on the lock plate while closed: 0.35 s star flash every 2.6 s.
const GLINT_PERIOD: float = 2.6
const GLINT_TIME: float = 0.35

var is_open: bool = false
## "wood" | "metal" | "locked"
var chest_type: String = "wood"

var _lid: Node3D = null
var _body: MeshInstance3D = null
var _glow: MeshInstance3D = null
var _seed: int = 0
var _palette: Dictionary = {}
var _tween: Tween = null
var _open_owed: bool = false           # an animated open() whose `opened` has not been emitted yet
var _glint: MeshInstance3D = null
var _glint_t: float = 0.0


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
	_kill_tween()
	_open_owed = true
	_tween = create_tween()
	_tween.tween_property(_lid, "rotation:x", deg_to_rad(LID_OPEN_DEG), OPEN_TIME).set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT)
	_tween.tween_callback(_on_open_finished)
	if _glow != null:
		_glow.visible = true
	var host: Node = get_parent() if get_parent() != null else self
	Vfx.spawn(&"chest_open", host, global_position + Vector3(0, 0.6, 0) * global_transform.basis.get_scale().y,
		_glow_color())


## Interrupting a running animated open() still emits its `opened` (every open() emits exactly once).
func set_open_instant() -> void:
	_ensure_built()
	var owed: bool = _kill_tween()
	is_open = true
	if _lid != null:
		_lid.rotation.x = deg_to_rad(LID_OPEN_DEG)
	if _glow != null:
		_glow.visible = true
	if owed:
		opened.emit()


## Art extra: rebuilds the chest as "wood" | "metal" | "locked" (keeps the open state).
func set_style(type: String) -> void:
	chest_type = type if type in ["wood", "metal", "locked"] else "wood"
	var owed: bool = _kill_tween()
	_clear()
	_build(_seed, _palette)
	if owed:
		opened.emit()


func _ready() -> void:
	_ensure_built()


func _ensure_built() -> void:
	if _body == null:
		_build(_seed, _palette)


func _on_open_finished() -> void:
	_open_owed = false
	opened.emit()


## Stops a running lid tween; returns true if its `opened` was still owed to an awaiting caller.
func _kill_tween() -> bool:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	var owed: bool = _open_owed
	_open_owed = false
	return owed


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
	# camera-facing additive star on the lid's front edge (reads from every side and from the gameplay camera)
	_glint = MeshInstance3D.new()
	_glint.name = "Glint"
	var quad := QuadMesh.new()
	quad.size = Vector2(0.55, 0.55)
	_glint.mesh = quad
	_glint.material_override = Materials.vfx_additive_ex(Palette.HYPE_GOLD, 1, 0.5, 3.0, true)
	_glint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_glint.position = Vector3(0.18, 0.62, -0.22)
	_glint.visible = false
	_glint_t = float(absi(seed) % 13) * 0.2      # chests in one room do not glint in sync
	add_child(_glint)
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
	_glint = null


## Chest body parts (03_ART §6.3): Box 0.9×0.45×0.6 + bands + 4 corner fittings (metal) + lock plate. Review M4: the
## loot chest must not read as a dressing crate — big brass corners and bands (#CD7F32, metal) and an emissive
## HYPE_GOLD lock plate (E 0.6); dressing crates use the greyer CRATE_WOOD.
static func body_parts(r: Dictionary, type: String) -> void:
	var body: Color = Palette.WOOD if type == "wood" else Color("#8a8f96")
	var trim: Color = BRASS_TRIM if type == "wood" else Color("#5a6068")
	var parts: Array = r["parts"]
	parts.append(MeshUtil.part(MeshUtil.box(Vector3(0.9, 0.45, 0.6)), Vector3(0, 0.225, 0), body))
	if type == "wood":
		for y: float in [0.12, 0.33]:
			parts.append(MeshUtil.part(MeshUtil.box(Vector3(0.92, 0.045, 0.62)), Vector3(0, y, 0), trim, Vector3.ZERO,
				Vector3.ONE, 0.0, 1.0))
	else:
		for x: float in [-0.3, 0.0, 0.3]:
			parts.append(MeshUtil.part(MeshUtil.box(Vector3(0.04, 0.44, 0.61)), Vector3(x, 0.225, 0), Palette.mul(body, 0.82),
				Vector3.ZERO, Vector3.ONE, 0.0, 1.0))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			parts.append(MeshUtil.part(MeshUtil.box(Vector3(0.12, 0.12, 0.12)), Vector3(0.42 * sx, 0.06, 0.27 * sz), trim,
				Vector3.ZERO, Vector3.ONE, 0.0, 1.0))
			parts.append(MeshUtil.part(MeshUtil.box(Vector3(0.12, 0.12, 0.12)), Vector3(0.42 * sx, 0.39, 0.27 * sz), trim,
				Vector3.ZERO, Vector3.ONE, 0.0, 1.0))
	parts.append(MeshUtil.part(MeshUtil.box(Vector3(0.20, 0.22, 0.03)), Vector3(0, 0.33, -0.31),
		Palette.HYPE_GOLD if type == "wood" else trim, Vector3.ZERO, Vector3.ONE, 0.6 if type == "wood" else 0.0, 1.0))
	parts.append(MeshUtil.part(MeshUtil.box(Vector3(0.05, 0.08, 0.02)), Vector3(0, 0.31, -0.33), DARK_KEYHOLE))
	if type == "locked":
		parts.append(MeshUtil.part(MeshUtil.torus(0.035, 0.055), Vector3(0, 0.30, -0.36), Palette.STEEL, Vector3.ZERO,
			Vector3.ONE, 0.0, 1.0))
		parts.append(MeshUtil.part(MeshUtil.box(Vector3(0.12, 0.10, 0.05)), Vector3(0, 0.24, -0.36), Palette.LIVE_RED,
			Vector3.ZERO, Vector3.ONE, 0.2, 1.0))


## Lid parts relative to the lid pivot at the rear top edge (lid extends toward −Z).
static func lid_parts(type: String) -> Array:
	var body: Color = Palette.WOOD if type == "wood" else Color("#8a8f96")
	var trim: Color = BRASS_TRIM if type == "wood" else Color("#5a6068")
	var parts: Array = []
	parts.append(MeshUtil.part(MeshUtil.box(Vector3(0.92, 0.15, 0.62)), Vector3(0, 0.075, -0.31), Palette.mul(body, 1.08)))
	parts.append(MeshUtil.part(MeshUtil.box(Vector3(0.94, 0.05, 0.12)), Vector3(0, 0.13, -0.31), trim, Vector3.ZERO,
		Vector3.ONE, 0.0, 1.0))
	for sx: float in [-1.0, 1.0]:
		parts.append(MeshUtil.part(MeshUtil.box(Vector3(0.10, 0.17, 0.64)), Vector3(0.42 * sx, 0.075, -0.31), trim,
			Vector3.ZERO, Vector3.ONE, 0.0, 1.0))
	return parts


# --- idle glint (closed chests catch the eye, pillar 4/6)
# -----------------------------------------------------------------

func _process(delta: float) -> void:
	if _glint == null:
		return
	if is_open or not is_visible_in_tree():
		_glint.visible = false
		return
	_glint_t = fmod(_glint_t + delta, GLINT_PERIOD)
	var u: float = _glint_t / GLINT_TIME
	if u >= 1.0:
		_glint.visible = false
		return
	var k: float = sin(PI * u)
	_glint.visible = true
	_glint.scale = Vector3(k, k, k)
