extends "res://scenes/exploration/gate_interactable.gd"
## Kulissenwand (06 §2.7, package A): a cracked scenery panel in a door opening — a FloorLayout gate with requires
## "secret:<id>". Painted in the zone's wall colour but flat, with dark cracks and a trickle of dust (the tell); the
## back shows plywood struts. It has no prompt (never focused): Kai's field strike or Graf Mopsula's bark knocks it over
## (ExplorationScene.knock_wall → Game.open_secret → open_visual: the panel tips away from the hero, dust, then sinks).

const PANEL_H: float = 3.0              # up to the door lintel (FloorBuilder.LINTEL_Y)
const PANEL_T: float = 0.22
const FALL_SEC: float = 0.45
const SINK_DELAY: float = 0.9
const DUST_COLOR: Color = Color("#cbbfa8")
const PLASTER: Color = Color("#b9ad94")    # rim of the cracks
const CRACKS: Array[Vector4] = [        # x, y (panel centre), length, roll (deg) — a zigzag from top left to the centre
	Vector4(-1.25, 2.55, 0.75, -55.0), Vector4(-0.82, 2.0, 0.7, 35.0), Vector4(-0.35, 1.55, 0.65, -50.0),
	Vector4(0.12, 1.15, 0.6, 30.0), Vector4(0.55, 0.85, 0.5, -60.0), Vector4(-0.55, 1.7, 0.45, 80.0),
	Vector4(0.95, 2.35, 0.55, 20.0)]

var secret_id: String = ""
var panel: Node3D = null                # pivot at the bottom edge: falls over around local X
var _dust: CPUParticles3D = null
var _fall_dir: float = 1.0


## `gate` = FloorLayout.gates entry with requires "secret:<id>"; the caller places the node in the door opening.
func setup_gate(p_gate: Dictionary, palette: Dictionary, _prop_seed: int) -> void:
	gate = p_gate
	key = str(p_gate.get("key", ""))
	requires = str(p_gate.get("requires", ""))
	secret_id = Secrets.id_of_requirement(requires)
	interact_id = secret_id
	name = "SceneryWall_" + key.replace(",", "_")
	prop = Node3D.new()
	prop.name = "Prop"
	add_child(prop)
	panel = Node3D.new()
	panel.name = "Panel"
	prop.add_child(panel)
	_build_panel(palette)
	_blocker = _make_blocker(Vector3(GATE_WIDTH + 0.4, 3.2, 1.0), Vector3(0.0, 1.6, 0.0))
	_make_area(Rules.STRIKE_RANGE + GATE_WIDTH * 0.5 + 0.6)


func is_event_gate() -> bool:
	return false


## No prompt: the wall is opened by the field ability, never by "Interagieren" (06 §8.2).
func prompt_text() -> String:
	return ""


func interact() -> void:
	pass


## Remembers which side the hero stands on: the panel falls away from him (local +Z or −Z).
func set_fall_from(hero_pos: Vector3) -> void:
	var local: Vector3 = global_transform.affine_inverse() * hero_pos if is_inside_tree() else Vector3.ZERO
	_fall_dir = -1.0 if local.z > 0.0 else 1.0


## Down it goes: blocker off at once, the panel tips over (FALL_SEC), dust puff, then sinks into the floor and hides.
func open_visual(animated: bool) -> void:
	if opened:
		return
	opened = true
	if _blocker != null:
		_blocker.queue_free()
		_blocker = null
	monitoring = false
	if _dust != null:
		_dust.emitting = false
	if not animated or not is_inside_tree():
		prop.visible = false
		return
	Sfx.play(&"hit")
	var tw: Tween = create_tween()
	tw.tween_property(panel, "rotation:x", _fall_dir * PI * 0.5, FALL_SEC).set_trans(Tween.TRANS_QUAD) \
		.set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		Sfx.play(&"door")
		var parent: Node = get_parent()
		if parent != null:
			Vfx.spawn(&"smoke", parent, global_position + global_transform.basis.z * (_fall_dir * 1.4)
				+ Vector3(0.0, 0.2, 0.0), DUST_COLOR, 2.0))
	tw.tween_interval(SINK_DELAY)
	tw.tween_property(panel, "position:y", -0.4, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void: prop.visible = false)


## The blocking body (bark line of sight ignores the wall it aims at).
func blocker_rid() -> RID:
	return _blocker.get_rid() if _blocker != null and is_instance_valid(_blocker) else RID()


func _build_panel(palette: Dictionary) -> void:
	var wall_c: Color = FB.col(palette, "wall", Color("#3b4a3f"))
	var ply: Color = Color("#a27b4f")
	# face: the zone's world-space wall tiles (env material) in a slightly lighter paint — it nearly blends in
	var face: Array[Dictionary] = [MeshUtil.part(MeshUtil.box(Vector3(GATE_WIDTH - 0.04, PANEL_H, PANEL_T)),
		Vector3(0.0, PANEL_H * 0.5, 0.0), wall_c.lightened(0.15))]
	var face_mi: MeshInstance3D = MeshInstance3D.new()
	face_mi.name = "Face"
	face_mi.mesh = MeshUtil.merge_no_hull(face)
	face_mi.material_override = FB.env_material(palette)
	panel.add_child(face_mi)
	# cracks (through both faces) + plywood struts and sill on the back: one merged mesh, one draw call
	var detail: Array[Dictionary] = []
	for c: Vector4 in CRACKS:              # dark crack with a light plaster rim: readable on dark and light walls
		detail.append(MeshUtil.part(MeshUtil.box(Vector3(0.15, c.z + 0.08, PANEL_T + 0.03)), Vector3(c.x, c.y, 0.0),
			PLASTER, Vector3(0.0, 0.0, c.w)))
		detail.append(MeshUtil.part(MeshUtil.box(Vector3(0.06, c.z, PANEL_T + 0.06)), Vector3(c.x, c.y, 0.0), FB.INK,
			Vector3(0.0, 0.0, c.w)))
	for sx: float in [-1.0, 1.0]:
		detail.append(MeshUtil.part(MeshUtil.box(Vector3(0.12, 3.2, 0.12)), Vector3(sx * 0.95, 1.45,
			-PANEL_T * 0.5 - 0.08), ply, Vector3(0.0, 0.0, sx * 32.0)))
	detail.append(MeshUtil.part(MeshUtil.box(Vector3(GATE_WIDTH - 0.2, 0.12, 0.12)), Vector3(0.0, 0.12,
		-PANEL_T * 0.5 - 0.08), ply))
	var detail_mi: MeshInstance3D = MeshInstance3D.new()
	detail_mi.name = "Detail"
	detail_mi.mesh = MeshUtil.merge(detail)
	detail_mi.material_override = Materials.toon_vc({"outline": false})
	panel.add_child(detail_mi)
	_dust = CPUParticles3D.new()
	_dust.name = "Dust"
	_dust.amount = 8
	_dust.lifetime = 1.6
	_dust.position = Vector3(0.05, 1.4, 0.0)
	_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_dust.emission_box_extents = Vector3(0.6, 0.6, 0.22)
	_dust.direction = Vector3(0.0, -1.0, 0.0)
	_dust.spread = 12.0
	_dust.gravity = Vector3(0.0, -1.2, 0.0)
	_dust.initial_velocity_min = 0.05
	_dust.initial_velocity_max = 0.2
	_dust.scale_amount_min = 0.5
	_dust.scale_amount_max = 1.0
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(0.08, 0.08)
	_dust.mesh = q
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = DUST_COLOR
	_dust.material_override = m
	panel.add_child(_dust)
