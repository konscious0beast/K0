extends RefCounted
## Private M6 3D helpers for the meta scenes (title studio, intro, credits teaser, safe room fallback, lootbox stage,
## M.O.D. icon). No class_name (§0.3). Materials go through the M4 Materials API (02_TECH §8.2): Materials.toon for
## shaded surfaces (+ inverted-hull outline on figures, props, chests and lootboxes), Materials.glow for neon /
## lamps (emission >= 1), the `hologram` shader for the M.O.D. drone (03_ART §5.6). While M4 is still a stub
## (Materials.* returns null) a StandardMaterial3D fallback with toon diffuse + grow outline keeps the look close,
## so these scenes pick up the real toon look automatically once M4 is merged.
## Characters come from CharacterBuilder (M4); while that is still a stub (empty rig) a primitive stand-in is added.
## Every figure gets a contact blob shadow (03_ART: "Kontakt-Blob"; no real-time shadows on mobile).

const NOVA_CYAN: Color = Color("#22d3ee")
const NOVA_MAGENTA: Color = Color("#ff2e88")
const HYPE_GOLD: Color = Color("#ffc93c")
const INK: Color = Color("#140d1c")
const HOLOGRAM_SHADER: String = "res://art/shaders/hologram.gdshader"
const OUTLINE_W: float = 0.02

static var _mat_cache: Dictionary = {}
static var _blob_tex: Texture2D = null


## Material by parameters (cached): shaded surfaces → Materials.toon (outline only with `outline`), emission >= 1 →
## Materials.glow, unshaded / transparent / additive → StandardMaterial3D (light cones, glass).
static func mat(color: Color, emission: float = 0.0, unshaded: bool = false, alpha: float = 1.0,
		additive: bool = false, outline: bool = false) -> Material:
	var key: String = "%s|%.2f|%s|%.2f|%s|%s" % [color.to_html(), emission, unshaded, alpha, additive, outline]
	if _mat_cache.has(key):
		return _mat_cache[key] as Material
	var m: Material = null
	if not unshaded and alpha >= 1.0 and not additive:
		if emission >= 1.0:
			m = Materials.glow(color, emission)
		else:
			var opts: Dictionary = {"outline": outline}
			if emission > 0.0:
				opts["emission"] = Color(color.r * emission, color.g * emission, color.b * emission)
			m = Materials.toon(color, opts)
	if m == null:
		m = _standard(color, emission, unshaded, alpha, additive, outline)
	_mat_cache[key] = m
	return m


## Metallic toon (silver/gold lootboxes, fittings): stronger spec + rim, outlined.
static func metal(color: Color, emission: float = 0.0) -> Material:
	var key: String = "metal|%s|%.2f" % [color.to_html(), emission]
	if _mat_cache.has(key):
		return _mat_cache[key] as Material
	var opts: Dictionary = {"outline": true, "spec": 0.9, "rim": 0.55, "rim_color": Color("#fff6e0")}
	if emission > 0.0:
		opts["emission"] = Color(color.r * emission, color.g * emission, color.b * emission)
	var m: Material = Materials.toon(color, opts)
	if m == null:
		var sm: StandardMaterial3D = _standard(color, emission, false, 1.0, false, true)
		sm.metallic = 0.35              # no reflection probes in these sets: high metallic would read as dark
		sm.roughness = 0.3
		sm.metallic_specular = 0.9
		sm.rim_enabled = true
		sm.rim = 0.6
		sm.rim_tint = 0.3
		m = sm
	_mat_cache[key] = m
	return m


## M.O.D. hologram material (03_ART §5.6): the `hologram` shader (unshaded, additive, scanlines).
static func hologram(color: Color, alpha: float = 0.6, energy: float = 1.6) -> Material:
	var key: String = "holo|%s|%.2f|%.2f" % [color.to_html(), alpha, energy]
	if _mat_cache.has(key):
		return _mat_cache[key] as Material
	var m: Material = null
	var sh: Shader = load(HOLOGRAM_SHADER) as Shader if ResourceLoader.exists(HOLOGRAM_SHADER) else null
	if sh != null:
		var hm: ShaderMaterial = ShaderMaterial.new()
		hm.shader = sh
		hm.set_shader_parameter(&"color", color)
		hm.set_shader_parameter(&"alpha", alpha)
		hm.set_shader_parameter(&"scan_speed", 1.5)
		hm.set_shader_parameter(&"energy", energy)        # real M4 shader (art extra); ignored by the stub
		m = hm
	else:
		m = _standard(color, energy, true, alpha, true, false)
	_mat_cache[key] = m
	return m


## Fallback while Materials is an M4 stub: toon diffuse/specular, optional emission, optional grow outline (next_pass).
static func _standard(color: Color, emission: float, unshaded: bool, alpha: float, additive: bool,
		outline: bool) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color(color, alpha)
	m.roughness = 0.75
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_TOON
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
	if outline and not unshaded and alpha >= 1.0:
		m.next_pass = _outline_fallback()
	return m


static func _outline_fallback() -> Material:
	var m: Material = Materials.outline(OUTLINE_W, INK)
	if m != null:
		return m
	if _mat_cache.has("outline_std"):
		return _mat_cache["outline_std"] as Material
	var o: StandardMaterial3D = StandardMaterial3D.new()
	o.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	o.albedo_color = INK
	o.cull_mode = BaseMaterial3D.CULL_FRONT
	o.grow = true
	o.grow_amount = OUTLINE_W
	_mat_cache["outline_std"] = o
	return o


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
		rot_deg: Vector3 = Vector3.ZERO, outline: bool = false) -> MeshInstance3D:
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	return mesh_node(bm, mat(color, emission, false, 1.0, false, outline), pos, rot_deg)


static func sphere(radius: float, color: Color, pos: Vector3 = Vector3.ZERO, emission: float = 0.0,
		outline: bool = false) -> MeshInstance3D:
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 12
	sm.rings = 6
	return mesh_node(sm, mat(color, emission, false, 1.0, false, outline), pos)


static func cylinder(top: float, bottom: float, height: float, color: Color, pos: Vector3 = Vector3.ZERO,
		emission: float = 0.0, segments: int = 16, outline: bool = false) -> MeshInstance3D:
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = top
	cm.bottom_radius = bottom
	cm.height = height
	cm.radial_segments = segments
	cm.rings = 1
	return mesh_node(cm, mat(color, emission, false, 1.0, false, outline), pos)


## Contact blob shadow (soft ink disc on the floor) under a figure of `radius` metres.
static func blob_shadow(radius: float, alpha: float = 0.55) -> MeshInstance3D:
	if _blob_tex == null:
		var g: Gradient = Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.55, Color(1, 1, 1, 0.75))
		var gt: GradientTexture2D = GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		gt.width = 64
		gt.height = 64
		_blob_tex = gt
	var key: String = "blob|%.2f" % alpha
	var m: StandardMaterial3D = _mat_cache.get(key) as StandardMaterial3D
	if m == null:
		m = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(INK, alpha)
		m.albedo_texture = _blob_tex
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		_mat_cache[key] = m
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = Vector2(radius * 2.0, radius * 2.0)
	var mi: MeshInstance3D = mesh_node(pm, m, Vector3(0, 0.015, 0), Vector3.ZERO, "BlobShadow")
	return mi


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


## M.O.D. drone (03_ART §5.6): icosahedron core (hologram NOVA_CYAN, energy 1.6) around a shaded faceted inner core
## (the facets read even with the flat stub shader), lens (hologram NOVA_MAGENTA, energy 3), ring torus 0.42/0.46
## (hologram NOVA_MAGENTA) and the speech cone (hologram, alpha 0.15). No outline, no shadow.
## Animated by `animate_drone(node, time)`.
static func build_drone(scale: float = 1.0) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "ModDrone"
	root.scale = Vector3.ONE * scale
	var core: MeshInstance3D = mesh_node(icosahedron(0.32), hologram(NOVA_CYAN, 0.6, 1.6), Vector3.ZERO, Vector3.ZERO,
		"Core")
	root.add_child(core)
	var inner: MeshInstance3D = mesh_node(icosahedron(0.27), mat(Color("#2aa5bd")), Vector3.ZERO, Vector3.ZERO,
		"Inner")
	core.add_child(inner)
	var lens: MeshInstance3D = mesh_node(_sphere_mesh(0.07), hologram(NOVA_MAGENTA, 0.9, 3.0), Vector3(0, 0, 0.3),
		Vector3.ZERO, "Lens")
	root.add_child(lens)
	var tm: TorusMesh = TorusMesh.new()
	tm.inner_radius = 0.42
	tm.outer_radius = 0.46
	tm.rings = 24
	tm.ring_segments = 6
	var ring: MeshInstance3D = mesh_node(tm, hologram(NOVA_MAGENTA, 0.8, 2.0), Vector3.ZERO, Vector3(70, 0, 0), "Ring")
	root.add_child(ring)
	var cone: CylinderMesh = CylinderMesh.new()
	cone.top_radius = 0.02
	cone.bottom_radius = 0.35
	cone.height = 0.9
	cone.radial_segments = 16
	var beam: MeshInstance3D = mesh_node(cone, hologram(NOVA_CYAN, 0.15, 1.6), Vector3(0, -0.75, 0),
		Vector3.ZERO, "Beam")
	root.add_child(beam)
	return root


static func _sphere_mesh(radius: float) -> SphereMesh:
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 12
	sm.rings = 6
	return sm


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
		core.material_override = hologram(color, 0.6, 1.6)
	var inner: MeshInstance3D = drone.get_node_or_null("Core/Inner") as MeshInstance3D
	if inner != null:
		inner.material_override = mat(color.darkened(0.2))


## CharacterRig for a party member / enemy model; stub rigs (no children) get a primitive stand-in (toon + outline).
## Every figure stands on a contact blob shadow.
static func figure(model: Dictionary, seed_value: int = 0) -> Node3D:
	var rig: CharacterRig = CharacterBuilder.build(model, seed_value)
	if rig == null:
		rig = CharacterRig.new()
	if rig.get_child_count() == 0:
		_add_stand_in(rig, model)
	var base: String = str(model.get("base", "humanoid"))
	var r: float = (0.42 if base == "pug" else 0.5) * float(model.get("scale", 1.0))
	rig.add_child(blob_shadow(r))
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
		holder.add_child(sphere(0.2, primary, Vector3(0, 0.46, -0.28), 0.0, true))
		holder.add_child(sphere(0.11, secondary, Vector3(0, 0.41, -0.45), 0.0, true))
		holder.add_child(sphere(0.045, eyes, Vector3(-0.09, 0.51, -0.43)))
		holder.add_child(sphere(0.045, eyes, Vector3(0.09, 0.51, -0.43)))
		holder.add_child(sphere(0.07, secondary, Vector3(-0.15, 0.6, -0.25), 0.0, true))
		holder.add_child(sphere(0.07, secondary, Vector3(0.15, 0.6, -0.25), 0.0, true))
		for x: float in [-0.12, 0.12]:
			for z: float in [-0.12, 0.22]:
				holder.add_child(cylinder(0.05, 0.05, 0.2, primary, Vector3(x, 0.1, z), 0.0, 8, true))
		if _has_prop(model, "cape"):
			holder.add_child(box(Vector3(0.36, 0.04, 0.5), accent, Vector3(0, 0.45, 0.1), 0.0, Vector3(-8, 0, 0), true))
		if _has_prop(model, "monocle"):
			holder.add_child(cylinder(0.05, 0.05, 0.02, HYPE_GOLD, Vector3(0.09, 0.51, -0.47), 0.4, 12))
		root.set("height", 0.65 * sc)
	elif base == "humanoid":
		holder.add_child(cylinder(0.11, 0.12, 0.6, secondary, Vector3(-0.13, 0.3, 0), 0.0, 16, true))
		holder.add_child(cylinder(0.11, 0.12, 0.6, secondary, Vector3(0.13, 0.3, 0), 0.0, 16, true))
		holder.add_child(_capsule(0.3, 0.75, primary, Vector3(0, 0.88, 0)))
		holder.add_child(sphere(0.29, skin, Vector3(0, 1.43, 0), 0.0, true))
		holder.add_child(sphere(0.3, accent, Vector3(0, 1.55, 0.04), 0.0, true))
		holder.add_child(sphere(0.05, eyes, Vector3(-0.1, 1.45, -0.26)))
		holder.add_child(sphere(0.05, eyes, Vector3(0.1, 1.45, -0.26)))
		holder.add_child(_capsule(0.09, 0.6, primary, Vector3(-0.38, 0.9, 0)))
		holder.add_child(_capsule(0.09, 0.6, primary, Vector3(0.38, 0.9, 0)))
		if _has_prop(model, "mop"):
			holder.add_child(cylinder(0.025, 0.025, 1.5, Color("#c9a26b"), Vector3(0.48, 0.85, -0.1), 0.0, 16, true))
			holder.add_child(box(Vector3(0.3, 0.14, 0.12), Color("#d8d8e8"), Vector3(0.48, 0.12, -0.1), 0.0, Vector3.ZERO, true))
		root.set("height", 1.75 * sc)
	else:
		holder.add_child(sphere(0.45, primary, Vector3(0, 0.45, 0), 0.0, true))
		holder.add_child(sphere(0.07, eyes, Vector3(-0.15, 0.55, -0.4)))
		holder.add_child(sphere(0.07, eyes, Vector3(0.15, 0.55, -0.4)))
		root.set("height", 0.9 * sc)


static func _capsule(radius: float, height: float, color: Color, pos: Vector3) -> MeshInstance3D:
	var cm: CapsuleMesh = CapsuleMesh.new()
	cm.radius = radius
	cm.height = height
	cm.radial_segments = 10
	cm.rings = 2
	return mesh_node(cm, mat(color, 0.0, false, 1.0, false, true), pos)


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


## Lootbox mesh by box id (03_ART §7.2): bronze wood + fittings, silver metal, gold glowing metal, fan gift box with
## heart. Front (lock plate, heart) faces +Z = the lootbox camera; the lid ("Lid", hinge on the back edge) opens by
## rotating Lid.rotation.x negative (−110°). Toon + outline (metallic toon for silver/gold).
static func lootbox_mesh(box_id: String, tier_color: Color) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Box_" + box_id
	var body_col: Color = tier_color
	var emit: float = 0.0
	var metal_box: bool = box_id == "box_silver" or box_id == "box_gold"
	match box_id:
		"box_bronze":
			body_col = Color("#8a5a32")
		"box_gold":
			emit = 0.25
	var body_mat: Material = metal(body_col, emit) if metal_box else mat(body_col, emit, false, 1.0, false, true)
	var lid_mat: Material = metal(body_col.lightened(0.12), emit) if metal_box else mat(body_col.lightened(0.1), emit,
		false, 1.0, false, true)
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(0.5, 0.36, 0.4)
	var body: MeshInstance3D = mesh_node(bm, body_mat, Vector3(0, 0.18, 0), Vector3.ZERO, "Body")
	root.add_child(body)
	var lid: Node3D = Node3D.new()
	lid.name = "Lid"
	lid.position = Vector3(0, 0.36, -0.2)          # hinge: back top edge
	root.add_child(lid)
	var lm: BoxMesh = BoxMesh.new()
	lm.size = Vector3(0.52, 0.08, 0.42)
	lid.add_child(mesh_node(lm, lid_mat, Vector3(0, 0.04, 0.2), Vector3.ZERO, "LidBody"))
	if box_id == "box_fan":
		lid.add_child(box(Vector3(0.08, 0.1, 0.44), Color("#f5f0e6"), Vector3(0, 0.05, 0.2), 0.0, Vector3.ZERO, true))
		root.add_child(box(Vector3(0.08, 0.37, 0.41), Color("#f5f0e6"), Vector3(0, 0.18, 0), 0.0, Vector3.ZERO, true))
		var heart: Node3D = Node3D.new()
		heart.name = "Heart"
		heart.position = Vector3(0, 0.2, 0.205)
		heart.add_child(sphere(0.055, Color("#f5f0e6"), Vector3(-0.04, 0.03, 0), 0.2, true))
		heart.add_child(sphere(0.055, Color("#f5f0e6"), Vector3(0.04, 0.03, 0), 0.2, true))
		heart.add_child(mesh_node(_cone(0.075, 0.1), mat(Color("#f5f0e6"), 0.2, false, 1.0, false, true),
			Vector3(0, -0.035, 0), Vector3(180, 0, 0)))
		root.add_child(heart)
	else:
		var fit_col: Color = Color("#c9a227") if box_id == "box_bronze" else tier_color.lightened(0.25)
		for x: float in [-0.23, 0.23]:
			var fm: BoxMesh = BoxMesh.new()
			fm.size = Vector3(0.05, 0.38, 0.42)
			root.add_child(mesh_node(fm, metal(fit_col, 0.1), Vector3(x, 0.18, 0)))
		var plate: BoxMesh = BoxMesh.new()
		plate.size = Vector3(0.11, 0.13, 0.03)
		var lock: MeshInstance3D = mesh_node(plate, metal(fit_col.lightened(0.15), 0.2), Vector3(0, 0.29, 0.21),
			Vector3.ZERO, "Lock")
		root.add_child(lock)
		lock.add_child(box(Vector3(0.025, 0.045, 0.02), INK, Vector3(0, -0.01, 0.012)))
	return root


static func _cone(radius: float, height: float) -> CylinderMesh:
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = 10
	return cm
