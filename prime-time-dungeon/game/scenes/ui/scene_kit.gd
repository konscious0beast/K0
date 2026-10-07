extends RefCounted
## Private M6 3D helpers for the meta scenes (title studio, intro, credits teaser, safe room fallback, lootbox stage,
## M.O.D. icon). No class_name (§0.3). StandardMaterial3D only → identical look in mobile and gl_compatibility.
## Characters come from CharacterBuilder (M4); while that is still a stub (empty rig) a primitive stand-in is added.

const NOVA_CYAN: Color = Color("#22d3ee")
const NOVA_MAGENTA: Color = Color("#ff2e88")
const HYPE_GOLD: Color = Color("#ffc93c")
const INK: Color = Color("#140d1c")

static var _mat_cache: Dictionary = {}


## Opaque/unshaded/emissive material (cached by parameters).
static func mat(color: Color, emission: float = 0.0, unshaded: bool = false, alpha: float = 1.0,
		additive: bool = false) -> StandardMaterial3D:
	var key: String = "%s|%.2f|%s|%.2f|%s" % [color.to_html(), emission, unshaded, alpha, additive]
	if _mat_cache.has(key):
		return _mat_cache[key] as StandardMaterial3D
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color(color, alpha)
	m.roughness = 0.75
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	if alpha < 1.0 or additive:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.no_depth_test = false
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_cache[key] = m
	return m


static func mesh_node(mesh: Mesh, material: Material, pos: Vector3 = Vector3.ZERO, rot_deg: Vector3 = Vector3.ZERO,
		node_name: String = "") -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if node_name != "":
		mi.name = node_name
	return mi


static func box(size: Vector3, color: Color, pos: Vector3 = Vector3.ZERO, emission: float = 0.0,
		rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	return mesh_node(bm, mat(color, emission), pos, rot_deg)


static func sphere(radius: float, color: Color, pos: Vector3 = Vector3.ZERO, emission: float = 0.0) -> MeshInstance3D:
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 12
	sm.rings = 6
	return mesh_node(sm, mat(color, emission), pos)


static func cylinder(top: float, bottom: float, height: float, color: Color, pos: Vector3 = Vector3.ZERO,
		emission: float = 0.0, segments: int = 16) -> MeshInstance3D:
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = top
	cm.bottom_radius = bottom
	cm.height = height
	cm.radial_segments = segments
	cm.rings = 1
	return mesh_node(cm, mat(color, emission), pos)


static func environment(bg: Color, ambient: Color, ambient_energy: float = 1.0, glow: bool = true,
		fog_color: Color = Color(0, 0, 0, 0), fog_density: float = 0.0) -> Environment:
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = bg
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient
	env.ambient_light_energy = ambient_energy
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	if glow and Game.settings != null and Game.settings.quality == &"high":
		env.glow_enabled = true
		env.glow_intensity = 0.8
		env.glow_bloom = 0.05
		env.glow_hdr_threshold = 0.9
	if fog_color.a > 0.0 and fog_density > 0.0:
		env.fog_enabled = true
		env.fog_light_color = fog_color
		env.fog_density = fog_density
	return env


static func omni(color: Color, energy: float, range_m: float, pos: Vector3) -> OmniLight3D:
	var l: OmniLight3D = OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = range_m
	l.position = pos
	l.shadow_enabled = false
	return l


static func sun(color: Color, energy: float, rot_deg: Vector3) -> DirectionalLight3D:
	var l: DirectionalLight3D = DirectionalLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.rotation_degrees = rot_deg
	l.shadow_enabled = false
	return l


static func camera(pos: Vector3, target: Vector3, fov: float = 50.0) -> Camera3D:
	var c: Camera3D = Camera3D.new()
	c.fov = fov
	c.current = true
	look(c, pos, target)
	return c


## Local transform at `pos` looking at `target` (parent space; no tree needed, unlike Node3D.look_at).
static func look(n: Node3D, pos: Vector3, target: Vector3) -> void:
	var dir: Vector3 = target - pos
	if dir.length_squared() < 0.000001:
		n.position = pos
		return
	var up: Vector3 = Vector3.UP if absf(dir.normalized().dot(Vector3.UP)) < 0.99 else Vector3.FORWARD
	n.transform = Transform3D(Basis.looking_at(dir, up), pos)


## Flat-shaded icosahedron (M.O.D. core, 03_ART §5.6) as ArrayMesh.
static func icosahedron(radius: float) -> ArrayMesh:
	var t: float = (1.0 + sqrt(5.0)) * 0.5
	var v: Array[Vector3] = [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
	var faces: Array[Vector3i] = [Vector3i(0, 11, 5), Vector3i(0, 5, 1), Vector3i(0, 1, 7), Vector3i(0, 7, 10),
		Vector3i(0, 10, 11), Vector3i(1, 5, 9), Vector3i(5, 11, 4), Vector3i(11, 10, 2), Vector3i(10, 7, 6),
		Vector3i(7, 1, 8), Vector3i(3, 9, 4), Vector3i(3, 4, 2), Vector3i(3, 2, 6), Vector3i(3, 6, 8),
		Vector3i(3, 8, 9), Vector3i(4, 9, 5), Vector3i(2, 4, 11), Vector3i(6, 2, 10), Vector3i(8, 6, 7),
		Vector3i(9, 8, 1)]
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for f: Vector3i in faces:
		var a: Vector3 = v[f.x].normalized() * radius
		var b: Vector3 = v[f.y].normalized() * radius
		var c: Vector3 = v[f.z].normalized() * radius
		var n: Vector3 = (b - a).cross(c - a).normalized()
		if n.dot(a) < 0.0:
			n = -n
			var tmp: Vector3 = b
			b = c
			c = tmp
		# Godot front faces are clockwise → emit reversed winding.
		for p: Vector3 in [a, c, b]:
			st.set_normal(n)
			st.add_vertex(p)
	return st.commit()


## M.O.D. drone (03_ART §5.6): core, lens, ring, speech cone. Animated by `animate_drone(node, time)`.
static func build_drone(scale: float = 1.0) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "ModDrone"
	root.scale = Vector3.ONE * scale
	var core: MeshInstance3D = mesh_node(icosahedron(0.32), mat(NOVA_CYAN, 1.6), Vector3.ZERO, Vector3.ZERO, "Core")
	root.add_child(core)
	var inner: MeshInstance3D = mesh_node(icosahedron(0.2), mat(Color("#0b3b4a"), 0.0), Vector3.ZERO, Vector3.ZERO,
		"Inner")
	core.add_child(inner)
	var lens: MeshInstance3D = sphere(0.075, NOVA_MAGENTA, Vector3(0, 0, 0.3), 3.0)
	lens.name = "Lens"
	root.add_child(lens)
	var tm: TorusMesh = TorusMesh.new()
	tm.inner_radius = 0.42
	tm.outer_radius = 0.47
	tm.rings = 24
	tm.ring_segments = 6
	var ring: MeshInstance3D = mesh_node(tm, mat(NOVA_MAGENTA, 2.0), Vector3.ZERO, Vector3(70, 0, 0), "Ring")
	root.add_child(ring)
	var cone: CylinderMesh = CylinderMesh.new()
	cone.top_radius = 0.02
	cone.bottom_radius = 0.35
	cone.height = 0.9
	cone.radial_segments = 16
	var beam: MeshInstance3D = mesh_node(cone, mat(NOVA_CYAN, 0.0, true, 0.15, true), Vector3(0, -0.75, 0),
		Vector3.ZERO, "Beam")
	root.add_child(beam)
	return root


static func animate_drone(drone: Node3D, t: float, base_y: float = 0.0) -> void:
	if drone == null:
		return
	var core: Node3D = drone.get_node_or_null("Core") as Node3D
	if core != null:
		core.rotation = Vector3(t * 0.25, t * 0.6, 0.0)
	var ring: Node3D = drone.get_node_or_null("Ring") as Node3D
	if ring != null:
		ring.rotation = Vector3(deg_to_rad(70.0), t * 0.8, 0.0)
	drone.position.y = base_y + sin(t * TAU * 0.5) * 0.06


## Recolors the drone core (mood colors, 03_ART §5.6).
static func set_drone_mood(drone: Node3D, color: Color) -> void:
	if drone == null:
		return
	var core: MeshInstance3D = drone.get_node_or_null("Core") as MeshInstance3D
	if core != null:
		core.material_override = mat(color, 1.6)


## CharacterRig for a party member / enemy model; stub rigs (no children) get a primitive stand-in.
static func figure(model: Dictionary, seed_value: int = 0) -> Node3D:
	var rig: CharacterRig = CharacterBuilder.build(model, seed_value)
	if rig == null:
		rig = CharacterRig.new()
	if rig.get_child_count() == 0:
		_add_stand_in(rig, model)
	rig.play(&"idle")
	return rig


static func party_figure(member_id: String) -> Node3D:
	var model: Dictionary = {}
	if DB.has_id("party", member_id):
		model = DB.party_member(member_id).model
	return figure(model, 0)


static func _add_stand_in(root: Node3D, model: Dictionary) -> void:
	var base: String = str(model.get("base", "humanoid"))
	var colors: Dictionary = model.get("colors", {})
	var primary: Color = _c(colors, "primary", Color("#3aa9a0"))
	var secondary: Color = _c(colors, "secondary", Color("#2e3a57"))
	var accent: Color = _c(colors, "accent", Color("#7b2cbf"))
	var skin: Color = _c(colors, "skin", Color("#e8b48f"))
	var eyes: Color = _c(colors, "eyes", INK)
	var sc: float = float(model.get("scale", 1.0))
	var holder: Node3D = Node3D.new()
	holder.name = "StandIn"
	holder.scale = Vector3.ONE * sc
	root.add_child(holder)
	if base == "pug":
		holder.add_child(_capsule_x(0.2, 0.62, primary, Vector3(0, 0.27, 0.05)))
		holder.add_child(sphere(0.2, primary, Vector3(0, 0.46, -0.28)))
		holder.add_child(sphere(0.11, secondary, Vector3(0, 0.41, -0.45)))
		holder.add_child(sphere(0.045, eyes, Vector3(-0.09, 0.51, -0.43)))
		holder.add_child(sphere(0.045, eyes, Vector3(0.09, 0.51, -0.43)))
		holder.add_child(sphere(0.07, secondary, Vector3(-0.15, 0.6, -0.25)))
		holder.add_child(sphere(0.07, secondary, Vector3(0.15, 0.6, -0.25)))
		for x: float in [-0.12, 0.12]:
			for z: float in [-0.12, 0.22]:
				holder.add_child(cylinder(0.05, 0.05, 0.2, primary, Vector3(x, 0.1, z), 0.0, 8))
		if _has_prop(model, "cape"):
			holder.add_child(box(Vector3(0.36, 0.04, 0.5), accent, Vector3(0, 0.45, 0.1), 0.0, Vector3(-8, 0, 0)))
		if _has_prop(model, "monocle"):
			holder.add_child(cylinder(0.05, 0.05, 0.02, HYPE_GOLD, Vector3(0.09, 0.51, -0.47), 0.4, 12))
		root.set("height", 0.65 * sc)
	elif base == "humanoid":
		holder.add_child(cylinder(0.11, 0.12, 0.6, secondary, Vector3(-0.13, 0.3, 0)))
		holder.add_child(cylinder(0.11, 0.12, 0.6, secondary, Vector3(0.13, 0.3, 0)))
		holder.add_child(_capsule(0.3, 0.75, primary, Vector3(0, 0.88, 0)))
		holder.add_child(sphere(0.29, skin, Vector3(0, 1.43, 0)))
		holder.add_child(sphere(0.3, accent, Vector3(0, 1.55, 0.04)))
		holder.add_child(sphere(0.05, eyes, Vector3(-0.1, 1.45, -0.26)))
		holder.add_child(sphere(0.05, eyes, Vector3(0.1, 1.45, -0.26)))
		holder.add_child(_capsule(0.09, 0.6, primary, Vector3(-0.38, 0.9, 0)))
		holder.add_child(_capsule(0.09, 0.6, primary, Vector3(0.38, 0.9, 0)))
		if _has_prop(model, "mop"):
			holder.add_child(cylinder(0.025, 0.025, 1.5, Color("#c9a26b"), Vector3(0.48, 0.85, -0.1)))
			holder.add_child(box(Vector3(0.3, 0.14, 0.12), Color("#d8d8e8"), Vector3(0.48, 0.12, -0.1)))
		root.set("height", 1.75 * sc)
	else:
		holder.add_child(sphere(0.45, primary, Vector3(0, 0.45, 0)))
		holder.add_child(sphere(0.07, eyes, Vector3(-0.15, 0.55, -0.4)))
		holder.add_child(sphere(0.07, eyes, Vector3(0.15, 0.55, -0.4)))
		root.set("height", 0.9 * sc)


static func _capsule(radius: float, height: float, color: Color, pos: Vector3) -> MeshInstance3D:
	var cm: CapsuleMesh = CapsuleMesh.new()
	cm.radius = radius
	cm.height = height
	cm.radial_segments = 10
	cm.rings = 2
	return mesh_node(cm, mat(color), pos)


static func _capsule_x(radius: float, length: float, color: Color, pos: Vector3) -> MeshInstance3D:
	var mi: MeshInstance3D = _capsule(radius, length, color, pos)
	mi.rotation_degrees = Vector3(90, 0, 0)
	return mi


static func _has_prop(model: Dictionary, prop: String) -> bool:
	var props: Variant = model.get("props", [])
	if typeof(props) == TYPE_ARRAY or typeof(props) == TYPE_PACKED_STRING_ARRAY:
		for p: Variant in props:
			if str(p) == prop:
				return true
	return false


static func _c(colors: Dictionary, key: String, fallback: Color) -> Color:
	var s: String = str(colors.get(key, ""))
	return Color.from_string(s, fallback) if s.is_valid_html_color() else fallback


## Lootbox mesh by box id (03_ART §7.2): bronze wood + fittings, silver metal, gold glowing, fan gift box with heart.
static func lootbox_mesh(box_id: String, tier_color: Color) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Box_" + box_id
	var body_col: Color = tier_color
	var emit: float = 0.0
	match box_id:
		"box_bronze":
			body_col = Color("#8a5a32")
		"box_gold":
			emit = 0.35
	var body: MeshInstance3D = box(Vector3(0.5, 0.36, 0.4), body_col, Vector3(0, 0.18, 0), emit)
	body.name = "Body"
	root.add_child(body)
	var lid: Node3D = Node3D.new()
	lid.name = "Lid"
	lid.position = Vector3(0, 0.36, 0.2)
	root.add_child(lid)
	lid.add_child(box(Vector3(0.52, 0.08, 0.42), body_col.lightened(0.1), Vector3(0, 0.04, -0.2), emit))
	if box_id == "box_fan":
		lid.add_child(box(Vector3(0.08, 0.1, 0.44), Color("#f5f0e6"), Vector3(0, 0.05, -0.2)))
		root.add_child(box(Vector3(0.08, 0.37, 0.41), Color("#f5f0e6"), Vector3(0, 0.18, 0)))
		var heart: Node3D = Node3D.new()
		heart.position = Vector3(0, 0.2, -0.205)
		heart.add_child(sphere(0.055, Color("#f5f0e6"), Vector3(-0.04, 0.03, 0), 0.2))
		heart.add_child(sphere(0.055, Color("#f5f0e6"), Vector3(0.04, 0.03, 0), 0.2))
		heart.add_child(mesh_node(_cone(0.075, 0.1), mat(Color("#f5f0e6"), 0.2), Vector3(0, -0.035, 0),
			Vector3(180, 0, 0)))
		root.add_child(heart)
	else:
		for x: float in [-0.23, 0.23]:
			root.add_child(box(Vector3(0.05, 0.38, 0.42), tier_color, Vector3(x, 0.18, 0), 0.15))
		root.add_child(box(Vector3(0.1, 0.12, 0.03), tier_color.lightened(0.2), Vector3(0, 0.3, -0.21), 0.3))
	return root


static func _cone(radius: float, height: float) -> CylinderMesh:
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = 10
	return cm
