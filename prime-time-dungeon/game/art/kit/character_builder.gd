class_name CharacterBuilder extends RefCounted
## ModelSpec → CharacterRig (02_TECH §8.4, 03_ART §5). Procedural archetypes from primitives (art/kit/archetypes.gd);
## a ModelSpec with an existing `gltf` path is wrapped in a CharacterRig subclass that maps the AnimationPlayer clips
## (art/kit/gltf_rig.gd, 03_ART §10). Merged part meshes are cached per ModelSpec (base + pose + colors + props + seed).

const Archetypes := preload("res://art/kit/archetypes.gd")
const GltfRig := preload("res://art/kit/gltf_rig.gd")
const DamageNumber := preload("res://art/kit/damage_number.gd")
const MESH_CACHE_MAX: int = 96
const DEFAULT_MAT: Dictionary = {"bands": 3, "rim": 0.45}
## Arm splay (degrees) so arms clear the chibi torso.
const ARM_OUT: Dictionary = {"humanoid": 6.0, "brute": 9.0, "rodent": 10.0, "specter": 0.0}
## Bases that only appear as enemies: their rigs get the warm danger rim by default (CharacterRig.set_danger_rim).
const ENEMY_BASES: PackedStringArray = ["rodent", "blob", "insect", "robot", "brute", "specter", "swarm"]

static var _mesh_cache: Dictionary = {}


## model = ModelSpec (§4.4.14). If model.gltf != "" and ResourceLoader.exists(model.gltf) → glTF wrapped in CharacterRig
## subclass mapping to AnimationPlayer clips of the same names; otherwise procedural archetype.
static func build(model: Dictionary, seed: int = 0) -> CharacterRig:
	var gltf: String = str(model.get("gltf", ""))
	if gltf != "" and ResourceLoader.exists(gltf):
		var packed: PackedScene = load(gltf) as PackedScene
		if packed != null:
			var inst: Node = packed.instantiate()
			if inst is Node3D:
				var g: CharacterRig = GltfRig.new()
				g.call("setup_from_scene", inst as Node3D, model)
				return g
			if inst != null:
				inst.free()
		push_warning("CharacterBuilder: cannot use glTF '%s', falling back to the procedural archetype" % gltf)
	return _build_procedural(model, seed)


## == DataValidator.MODEL_BASES (test asserts)
static func supported_bases() -> PackedStringArray:
	return Archetypes.BASES.duplicate()


## == DataValidator.MODEL_PROPS
static func supported_props() -> PackedStringArray:
	return Archetypes.PROPS.duplicate()


## pose "auto": rodent with scale >= 1.0 → &"upright", else &"quadruped"; "quadruped"/"upright" force it.
## Other bases have a fixed natural pose (pug, insect → &"quadruped", all others → &"upright").
static func resolve_pose(model: Dictionary) -> StringName:
	var base: String = str(model.get("base", "humanoid"))
	var pose: String = str(model.get("pose", "auto"))
	if base == "rodent":
		if pose == "quadruped":
			return &"quadruped"
		if pose == "upright":
			return &"upright"
		return &"upright" if float(model.get("scale", 1.0)) >= 1.0 else &"quadruped"
	if base == "pug" or base == "insect":
		return &"quadruped"
	return &"upright"


## Normalized ModelSpec used by the archetypes: base (unknown → humanoid), scale (0.3..4.0), pose (resolved),
## colors (slot → Color, archetype defaults for missing slots), props (known, unique, in order).
static func normalize(model: Dictionary) -> Dictionary:
	var base: String = str(model.get("base", "humanoid"))
	if not Archetypes.BASES.has(base):
		push_warning("CharacterBuilder: unknown base '%s' → humanoid" % base)
		base = "humanoid"
	var scale: float = clampf(float(model.get("scale", 1.0)), 0.3, 4.0)
	var colors: Dictionary = Archetypes.default_colors(base)
	var given: Variant = model.get("colors", {})
	if typeof(given) == TYPE_DICTIONARY:
		for k: Variant in (given as Dictionary):
			var v: Variant = (given as Dictionary)[k]
			if typeof(v) == TYPE_COLOR:
				colors[str(k)] = v
			else:
				colors[str(k)] = Palette.hex(str(v), colors.get(str(k), Color.MAGENTA))
	if not (typeof(given) == TYPE_DICTIONARY and (given as Dictionary).has("skin")) and base != "humanoid" \
			and base != "brute":
		colors["skin"] = colors["primary"]
	var props := PackedStringArray()
	var raw_props: Variant = model.get("props", [])
	if typeof(raw_props) == TYPE_ARRAY or typeof(raw_props) == TYPE_PACKED_STRING_ARRAY:
		for p: Variant in Array(raw_props):
			var ps: String = str(p)
			if not Archetypes.PROPS.has(ps):
				push_warning("CharacterBuilder: unknown prop '%s' ignored" % ps)
				continue
			if not props.has(ps):
				props.append(ps)
	var spec: Dictionary = {"base": base, "scale": scale, "colors": colors, "props": props}
	spec["pose"] = resolve_pose({"base": base, "pose": str(model.get("pose", "auto")), "scale": scale})
	return spec


static func clear_cache() -> void:
	_mesh_cache.clear()


# --- procedural ------------------------------------------------------------------------------------------------------

static func _build_procedural(model: Dictionary, seed: int) -> CharacterRig:
	var m: Dictionary = normalize(model)
	var eff_seed: int = seed ^ int(model.get("seed", 0))
	var bp: Dictionary = Archetypes.blueprint(m, eff_seed)
	var key: String = _cache_key(m, eff_seed)
	var cached: Dictionary = _mesh_cache.get(key, {})
	var fresh: bool = cached.is_empty()
	var rig := CharacterRig.new()
	rig.name = "Rig_" + str(m["base"])
	rig.model = model.duplicate(true)
	if str(m["base"]) == "blob" or str(m["base"]) == "swarm" or str(m["base"]) == "insect" or str(m["base"]) == "robot":
		rig.death_style = &"dissolve"
	var root := Node3D.new()
	root.name = "Model"
	var eff_scale: float = float(m["scale"]) * float(Archetypes.BASE_FIT.get(str(m["base"]), 1.0))
	root.scale = Vector3.ONE * eff_scale
	rig.add_child(root)
	var nodes: Dictionary = {}
	for pv: Variant in (bp["pivots"] as Array):
		var pname: String = str(pv)
		var n := Node3D.new()
		n.name = pname
		var rot: Vector3 = bp["pivot_rot"].get(pname, Vector3.ZERO)
		var scl: Vector3 = bp["pivot_scale"].get(pname, Vector3.ONE)
		n.transform = Transform3D(Basis.from_euler(rot * (PI / 180.0)) * Basis.from_scale(scl),
			bp["pivot_pos"].get(pname, Vector3.ZERO))
		var parent_name: String = str(bp["pivot_parent"].get(pname, ""))
		var parent: Node3D = nodes.get(parent_name, root)
		parent.add_child(n)
		nodes[pname] = n
	var meshes: Array[MeshInstance3D] = []
	var mesh_opts: Dictionary = {}
	var pulses: Array[Dictionary] = []
	for mv: Variant in (bp["mesh_order"] as Array):
		var mesh_name: String = str(mv)
		var md: Dictionary = bp["meshes"][mesh_name]
		var parts: Array = md["parts"]
		if parts.is_empty():
			continue
		var am: ArrayMesh = cached.get(mesh_name, null)
		if am == null:
			var typed: Array[Dictionary] = []
			typed.assign(parts)
			am = MeshUtil.merge(typed)
			cached[mesh_name] = am
		var mi := MeshInstance3D.new()
		mi.name = mesh_name + "Mesh"
		mi.mesh = am
		var opts: Dictionary = md["mat"] if not (md["mat"] as Dictionary).is_empty() else bp["mat"]
		mi.material_override = Materials.toon_vc(opts)
		mesh_opts[mi] = opts
		var host: Node3D = nodes.get(str(md["pivot"]), root)
		host.add_child(mi)
		meshes.append(mi)
		var pulse: Dictionary = md["pulse"]
		if not pulse.is_empty():
			var pd: Dictionary = pulse.duplicate()
			pd["mesh"] = mi
			pulses.append(pd)
	if fresh:
		if _mesh_cache.size() >= MESH_CACHE_MAX:
			_mesh_cache.clear()
		_mesh_cache[key] = cached
	var anchors: Dictionary = {}
	for av: Variant in (bp["anchors"] as Dictionary):
		var aname: String = str(av)
		var ad: Dictionary = bp["anchors"][aname]
		var an := Node3D.new()
		an.name = "Anchor_" + aname
		an.position = ad["pos"]
		var host2: Node3D = nodes.get(str(ad["pivot"]), root)
		host2.add_child(an)
		anchors[StringName(aname)] = an
	var feet := Node3D.new()
	feet.name = "Anchor_feet"
	rig.add_child(feet)
	anchors[&"feet"] = feet
	var particles: Array[CPUParticles3D] = []
	for pdv: Variant in (bp["particles"] as Array):
		var pdd: Dictionary = pdv
		var part: CPUParticles3D = _rig_particles(str(pdd["kind"]), m["colors"] as Dictionary)
		part.position = pdd["pos"]
		var host3: Node3D = nodes.get(str(pdd["pivot"]), root)
		host3.add_child(part)
		particles.append(part)
	var labels: Array[Label3D] = []
	for ldv: Variant in (bp.get("labels", []) as Array):
		var lb: Label3D = _rig_label(ldv as Dictionary)
		var host4: Node3D = nodes.get(str((ldv as Dictionary).get("pivot", "")), root)
		host4.add_child(lb)
		labels.append(lb)
	var bounds: AABB = _bounds(rig, meshes)
	var piv_typed: Dictionary = {}
	for pname2: String in nodes:
		piv_typed[pname2] = nodes[pname2]
	rig.call("_setup", {
		"base": m["base"], "pose": m["pose"], "model_root": root, "scale": eff_scale, "pivots": piv_typed,
		"meshes": meshes, "mesh_opts": mesh_opts, "pulses": pulses, "anchors": anchors, "particles": particles,
		"labels": labels,
		"height": maxf(bounds.end.y, 0.1), "width": maxf(bounds.size.x, bounds.size.z),
		"arm_out": float(ARM_OUT.get(str(m["base"]), 0.0)), "phase": float(absi(eff_seed) % 97) * 0.173,
	})
	if ENEMY_BASES.has(str(m["base"])):
		rig.set_danger_rim(true)
	return rig


static func _cache_key(m: Dictionary, seed: int) -> String:
	var cols: Dictionary = m["colors"]
	var ck: Array = cols.keys()
	ck.sort()
	var cs: PackedStringArray = []
	for k: Variant in ck:
		cs.append("%s=%s" % [str(k), (cols[k] as Color).to_html()])
	var props: PackedStringArray = m["props"]
	var seed_part: String = str(seed) if props.has("cable_tangle") else "0"
	# recipes are defined at scale 1 (the Model node scales), except the compact brute below scale 1.0
	var variant: String = "compact" if str(m["base"]) == "brute" and float(m["scale"]) < 1.0 else ""
	return "%s|%s|%s|%s|%s|%s" % [str(m["base"]), str(m["pose"]), ",".join(cs), ",".join(props), seed_part, variant]


## AABB of all meshes in rig space (rest pose, including the model scale).
static func _bounds(rig: Node3D, meshes: Array[MeshInstance3D]) -> AABB:
	var out := AABB()
	var first: bool = true
	for mi: MeshInstance3D in meshes:
		var xf: Transform3D = _xform_to(mi, rig)
		var box: AABB = xf * mi.mesh.get_aabb()
		if first:
			out = box
			first = false
		else:
			out = out.merge(box)
	return out


static func _xform_to(node: Node3D, ancestor: Node) -> Transform3D:
	var xf: Transform3D = node.transform
	var cur: Node = node.get_parent()
	while cur != null and cur != ancestor:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf


## Text on a figure (blueprint "labels", e.g. the Rabattschild percent sign): unshaded, one-sided, no shadow, bold.
static func _rig_label(ld: Dictionary) -> Label3D:
	var lb := Label3D.new()
	lb.name = "Label_" + str(ld.get("name", "text"))
	lb.text = str(ld.get("text", ""))
	lb.font = DamageNumber.bold_font()
	lb.font_size = int(ld.get("font_size", 96))
	lb.outline_size = int(ld.get("outline_size", 12))
	lb.modulate = ld.get("color", Color.WHITE)
	lb.outline_modulate = ld.get("outline", Color.BLACK)
	lb.pixel_size = float(ld.get("pixel_size", 0.002))
	lb.position = ld.get("pos", Vector3.ZERO)
	lb.rotation_degrees = ld.get("rot", Vector3.ZERO)
	lb.double_sided = false
	lb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return lb


## Looping particles that belong to an archetype (specter paint tail, cable sparks; 03_ART §5.3/§5.5).
static func _rig_particles(kind: String, colors: Dictionary) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Particles_" + kind
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	p.mesh = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if kind == "specter_tail":
		p.amount = 6
		p.lifetime = 0.8
		p.local_coords = false
		p.material_override = Materials.vfx_additive_ex(Color.WHITE, 0, 0.9, 0.7)
		p.direction = Vector3(0, -1, 0.4)
		p.spread = 25.0
		p.gravity = Vector3(0, 0.3, 0)
		p.initial_velocity_min = 0.2
		p.initial_velocity_max = 0.5
		p.scale_amount_min = 0.26
		p.scale_amount_max = 0.36
		var g := Gradient.new()
		var acc: Color = colors.get("accent", Palette.NOVA_CYAN)
		var prim: Color = colors.get("primary", Palette.NOVA_MAGENTA)
		g.colors = PackedColorArray([acc, prim, Color(prim.r, prim.g, prim.b, 0.0)])
		g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
		p.color_ramp = g
	else:
		p.amount = 4
		p.lifetime = 0.45
		p.local_coords = true
		p.material_override = Materials.vfx_additive_ex(Color("#9fe8ff"), 3, 0.4, 2.5)
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE_SURFACE
		p.emission_sphere_radius = 0.45
		p.direction = Vector3(0, 1, 0)
		p.spread = 90.0
		p.gravity = Vector3(0, -2.0, 0)
		p.initial_velocity_min = 0.6
		p.initial_velocity_max = 1.4
		p.scale_amount_min = 0.06
		p.scale_amount_max = 0.12
		p.particle_flag_align_y = true
	p.emitting = true
	return p
