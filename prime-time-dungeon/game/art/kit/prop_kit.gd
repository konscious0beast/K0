class_name PropKit extends RefCounted
## Props (02_TECH §8.5, 03_ART §6.3). Every prop is a recipe of primitive parts (vertex colors, emission/metal masks)
## merged into one mesh; moving parts are own pivots, neon/holograms own meshes, texts Label3D (fallback-font glyphs only,
## 03_ART F8). Interactive props (chest, stairs, safe door, automat, terminal, gate, event props) use the toon material
## with a 0.02 outline, set dressing uses the env material without outline. Origin = floor center, front = −Z.
## Art extras: recipe() (EnvKit merges set dressing into one room mesh), palette key "label" (text of stairs_down,
## billboard, safe_door), is_interactive().

const IDS: PackedStringArray = ["chest", "stairs_down", "safe_door", "vending_machine", "save_terminal", "couch", "crate",
	"barrel", "bench", "pillar", "lamp", "trash_bin", "turnstile", "poster", "camera_drone", "billboard", "rail", "wreck", "pipe",
	"gate", "phone_booth", "fortune_wheel", "lever", "broken_vending"]   # gate: closed door bar; last four: floor events (§7.4)
const INTERACTIVE: PackedStringArray = ["chest", "stairs_down", "safe_door", "vending_machine", "save_terminal", "gate",
	"phone_booth", "fortune_wheel", "lever", "broken_vending"]
const PropAnim := preload("res://art/kit/prop_anim.gd")

const DARK: Color = Color("#1a1420")
const STAIR_GREY: Color = Color("#6e6a72")
const DOOR_GREY: Color = Color("#4a5a60")
const AUTOMAT_PINK: Color = Color("#c2185b")


## "chest" returns ChestProp.
static func build(prop_id: StringName, seed: int = 0, palette: Dictionary = {}) -> Node3D:
	var id: String = String(prop_id)
	if id == "chest":
		var chest := ChestProp.new()
		chest.name = "chest"
		chest.call("_build", seed, palette)
		return chest
	var r: Dictionary = recipe(id, seed, palette)
	if r.is_empty():
		push_warning("PropKit.build: unknown prop '%s'" % id)
		var empty := Node3D.new()
		empty.name = id
		return empty
	return assemble(id, r, palette)


static func is_interactive(prop_id: StringName) -> bool:
	return INTERACTIVE.has(String(prop_id))


## Recipe: {"parts": Array (main mesh), "outline": bool, "pivots": [{"role", "pos", "rot", "parts"}],
## "glows": [{"role", "parts", "color", "energy", "pulse", "flicker"}], "holos": [{"role", "mesh", "xform", "color",
## "alpha"}], "labels": [{"text", "pos", "size", "color", "rot", "billboard"}], "collision": [{"size", "xform"}],
## "anim": String}. Empty dictionary = unknown id.
static func recipe(prop_id: String, seed: int, palette: Dictionary) -> Dictionary:
	var pal: Dictionary = Palette.resolve(_hex_only(palette), "metro")
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(prop_id) ^ (seed * 2654435761)
	var r: Dictionary = {"parts": [], "outline": INTERACTIVE.has(prop_id), "pivots": [], "glows": [], "holos": [],
		"labels": [], "collision": [], "anim": ""}
	match prop_id:
		"chest":
			ChestProp.body_parts(r, "wood")
		"stairs_down":
			_stairs(r, palette)
		"safe_door":
			_safe_door(r, palette)
		"vending_machine":
			_vending(r, false)
		"broken_vending":
			_vending(r, true)
		"save_terminal":
			_terminal(r)
		"couch":
			_couch(r)
		"crate":
			_crate(r, rng)
		"barrel":
			_barrel(r, rng)
		"bench":
			_bench(r)
		"pillar":
			_pillar(r, pal)
		"lamp":
			_lamp(r, rng)
		"trash_bin":
			_trash(r)
		"turnstile":
			_turnstile(r, rng)
		"poster":
			_poster(r, pal, rng)
		"camera_drone":
			_drone(r)
		"billboard":
			_billboard(r, pal, palette)
		"rail":
			_rail(r)
		"wreck":
			_wreck(r)
		"pipe":
			_pipe(r, rng)
		"gate":
			_gate(r)
		"phone_booth":
			_phone_booth(r)
		"fortune_wheel":
			_fortune_wheel(r)
		"lever":
			_lever(r)
		_:
			return {}
	return r


## Builds the node tree of a recipe (also used by ChestProp / EnvKit set pieces).
static func assemble(id: String, r: Dictionary, palette: Dictionary = {}) -> Node3D:
	var anim: String = str(r.get("anim", ""))
	var root: Node3D
	if anim != "":
		root = PropAnim.new()
		root.set("mode", anim)
	else:
		root = Node3D.new()
	root.name = id
	var pal: Dictionary = Palette.resolve(_hex_only(palette), "metro")
	var outline: bool = bool(r.get("outline", false))
	var mat: ShaderMaterial = material_for(outline, pal)
	var role_nodes: Dictionary = {}
	var main_parts: Array = r.get("parts", [])
	if not main_parts.is_empty():
		var mi := MeshInstance3D.new()
		mi.name = "Mesh"
		mi.mesh = _merge(main_parts, outline)
		mi.material_override = mat
		if not outline:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	for pv: Variant in (r.get("pivots", []) as Array):
		var pd: Dictionary = pv
		var piv := Node3D.new()
		piv.name = str(pd.get("role", "Pivot")).capitalize().replace(" ", "")
		piv.position = pd.get("pos", Vector3.ZERO)
		piv.rotation_degrees = pd.get("rot", Vector3.ZERO)
		root.add_child(piv)
		var pparts: Array = pd.get("parts", [])
		if not pparts.is_empty():
			var pm := MeshInstance3D.new()
			pm.name = "Mesh"
			pm.mesh = _merge(pparts, outline)
			pm.material_override = mat
			piv.add_child(pm)
		role_nodes[str(pd.get("role", ""))] = piv
	for gv: Variant in (r.get("glows", []) as Array):
		var gd: Dictionary = gv
		var gm := MeshInstance3D.new()
		gm.name = "Glow_" + str(gd.get("role", "glow"))
		gm.mesh = _merge(gd.get("parts", []) as Array, false)
		gm.material_override = Materials.glow_ex(gd.get("color", Color.WHITE), float(gd.get("energy", 2.0)),
			float(gd.get("pulse", 0.0)), float(gd.get("flicker", 0.0)))
		gm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var parent_role: String = str(gd.get("parent", ""))
		var gparent: Node3D = role_nodes.get(parent_role, root)
		gparent.add_child(gm)
		if str(gd.get("role", "")) != "":
			role_nodes[str(gd.get("role", ""))] = gm
	for hv: Variant in (r.get("holos", []) as Array):
		var hd: Dictionary = hv
		var hm := MeshInstance3D.new()
		hm.name = "Holo_" + str(hd.get("role", "holo"))
		hm.mesh = hd["mesh"]
		hm.transform = hd.get("xform", Transform3D.IDENTITY)
		hm.material_override = Materials.hologram(hd.get("color", Palette.NOVA_CYAN), float(hd.get("alpha", 0.6)),
			float(hd.get("energy", 1.6)))
		hm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(hm)
		if str(hd.get("role", "")) != "":
			role_nodes[str(hd.get("role", ""))] = hm
	for lv: Variant in (r.get("labels", []) as Array):
		var ld: Dictionary = lv
		var l := Label3D.new()
		l.name = "Label_" + str(ld.get("text", "")).replace(" ", "_").left(16)
		l.text = str(ld.get("text", ""))
		l.font_size = int(ld.get("size", 48))
		l.outline_size = int(ld.get("outline", 10))
		l.modulate = ld.get("color", Palette.PAPER)
		l.outline_modulate = Palette.INK
		l.pixel_size = float(ld.get("pixel", 0.005))
		l.position = ld.get("pos", Vector3.ZERO)
		l.rotation_degrees = ld.get("rot", Vector3(0, 180, 0))
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED if bool(ld.get("billboard", false)) \
			else BaseMaterial3D.BILLBOARD_DISABLED
		l.double_sided = false
		l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var lparent: Node3D = role_nodes.get(str(ld.get("parent", "")), root)
		lparent.add_child(l)
	var shapes: Array = r.get("collision", [])
	if not shapes.is_empty():
		var body := StaticBody3D.new()
		body.name = "Collision"
		body.collision_layer = 1
		body.collision_mask = 0
		for sv: Variant in shapes:
			var sd: Dictionary = sv
			var cs := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = sd["size"]
			cs.shape = box
			cs.transform = sd.get("xform", Transform3D.IDENTITY)
			body.add_child(cs)
		root.add_child(body)
	if anim != "":
		root.set("parts", role_nodes)
	return root


## Material of a prop mesh: interactive → toon (outline 0.02), dressing → env (no tiles on props, light dirt).
static func material_for(outline: bool, pal: Dictionary) -> ShaderMaterial:
	if outline:
		return Materials.toon_vc({"bands": 3, "rim": 0.45, "outline_width": 0.02})
	return Materials.env({"shade": pal.get("shade", Materials.DEFAULT_ENV_SHADE), "grout": pal.get("grout", Materials.DEFAULT_GROUT),
		"grout_width": 0.0, "dirt": 0.2})


# --- helpers ---------------------------------------------------------------------------------------------------------

static func _hex_only(palette: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in palette:
		var key: String = str(k)
		if Palette.PALETTE_KEYS.has(key) or Palette.ART_KEYS.has(key):
			out[key] = palette[k]
	return out


static func _merge(parts: Array, with_hull: bool) -> ArrayMesh:
	var typed: Array[Dictionary] = []
	typed.assign(parts)
	return MeshUtil.merge(typed) if with_hull else MeshUtil.merge_no_hull(typed)


static func _p(mesh: Mesh, pos: Vector3, color: Color, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE,
		emission: float = 0.0, metal: float = 0.0) -> Dictionary:
	return MeshUtil.part(mesh, pos, color, rot, scl, emission, metal)


static func _box(r: Dictionary, size: Vector3, pos: Vector3, color: Color, rot: Vector3 = Vector3.ZERO,
		emission: float = 0.0, metal: float = 0.0) -> void:
	(r["parts"] as Array).append(_p(MeshUtil.box(size), pos, color, rot, Vector3.ONE, emission, metal))


static func _add(r: Dictionary, p: Dictionary) -> void:
	(r["parts"] as Array).append(p)


## Cylinder part spanning a → b.
static func seg(a: Vector3, b: Vector3, r_a: float, r_b: float, color: Color, emission: float = 0.0,
		metal: float = 0.0) -> Dictionary:
	var d: Vector3 = b - a
	var length: float = maxf(d.length(), 0.001)
	var dir: Vector3 = d / length
	var basis := Basis.IDENTITY
	if dir.dot(Vector3.UP) < -0.9999:
		basis = Basis(Vector3.RIGHT, PI)
	elif dir.dot(Vector3.UP) < 0.9999:
		basis = Basis(Quaternion(Vector3.UP, dir))
	return {"mesh": MeshUtil.cylinder(r_b, r_a, length), "xform": Transform3D(basis, (a + b) * 0.5), "color": color,
		"emission": emission, "metal": metal}


static func _collide(r: Dictionary, size: Vector3, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> void:
	(r["collision"] as Array).append({"size": size, "xform": MeshUtil.xform(pos, rot)})


static func _label(r: Dictionary, text: String, pos: Vector3, size: int, color: Color, rot: Vector3 = Vector3(0, 180, 0),
		billboard: bool = false, parent: String = "") -> void:
	(r["labels"] as Array).append({"text": text, "pos": pos, "size": size, "color": color, "rot": rot,
		"billboard": billboard, "parent": parent})


# --- recipes -----------------------------------------------------------------------------------------------------------

static func _stairs(r: Dictionary, palette: Dictionary) -> void:
	for i in 10:
		var fi: float = float(i)
		_box(r, Vector3(4.0, 0.25, 0.5), Vector3(0, -0.125 - 0.25 * fi, -0.25 - 0.5 * fi), STAIR_GREY)
		_box(r, Vector3(4.0, 0.03, 0.06), Vector3(0, -0.25 * fi + 0.015, -0.03 - 0.5 * fi), Palette.WARN_YELLOW,
			Vector3.ZERO, 0.35)
	# stair well walls + floor
	var well: Color = Palette.mul(STAIR_GREY, 0.7)
	for sx: float in [-1.0, 1.0]:
		_box(r, Vector3(0.3, 2.8, 5.3), Vector3(2.15 * sx, -1.4, -2.55), well)
	_box(r, Vector3(4.6, 2.8, 0.3), Vector3(0, -1.4, -5.2), well)
	_box(r, Vector3(4.6, 0.2, 1.2), Vector3(0, -2.6, -4.5), well)
	# railings (metal)
	for sx: float in [-1.0, 1.0]:
		_add(r, seg(Vector3(2.05 * sx, 1.0, 0.0), Vector3(2.05 * sx, 1.0, -5.05), 0.04, 0.04, Palette.RAIL, 0.0, 1.0))
		for k in 5:
			var z: float = -1.25 * float(k)
			_add(r, seg(Vector3(2.05 * sx, 0.0, z), Vector3(2.05 * sx, 1.0, z), 0.035, 0.035, Palette.RAIL, 0.0, 1.0))
	_add(r, seg(Vector3(-2.05, 1.0, -5.05), Vector3(2.05, 1.0, -5.05), 0.04, 0.04, Palette.RAIL, 0.0, 1.0))
	for sx: float in [-1.0, 1.0]:
		_box(r, Vector3(0.22, 0.9, 0.22), Vector3(2.05 * sx, 0.45, 0.25), Palette.WARN_YELLOW)
		_box(r, Vector3(0.24, 0.12, 0.24), Vector3(2.05 * sx, 0.55, 0.25), DARK)
	# light column + label + bobbing arrow (glow)
	(r["holos"] as Array).append({"role": "column", "mesh": MeshUtil.tube(1.6, 6.0, 16),
		"xform": Transform3D(Basis.IDENTITY, Vector3(0, 1.0, -2.5)), "color": Palette.HYPE_GOLD, "alpha": 0.15})
	var text: String = str(palette.get("label", "ETAGE 2"))
	_label(r, text, Vector3(0, 3.7, -2.5), 120, Palette.HYPE_GOLD, Vector3.ZERO, true)
	(r["pivots"] as Array).append({"role": "arrow", "pos": Vector3(0, 4.6, -2.5), "rot": Vector3.ZERO, "parts": []})
	(r["glows"] as Array).append({"role": "arrow_glow", "parent": "arrow",
		"parts": [_p(MeshUtil.prism(Vector3(0.5, 0.4, 0.08)), Vector3.ZERO, Color.WHITE, Vector3(180, 0, 0)),
			_p(MeshUtil.box(Vector3(0.18, 0.3, 0.08)), Vector3(0, 0.33, 0), Color.WHITE)],
		"color": Palette.HYPE_GOLD, "energy": 2.0})
	r["anim"] = "stairs"
	# barrier around the well (players interact from the entry side, never fall in)
	for sx: float in [-1.0, 1.0]:
		_collide(r, Vector3(0.3, 1.2, 5.4), Vector3(2.15 * sx, 0.6, -2.5))
	_collide(r, Vector3(4.6, 1.2, 0.3), Vector3(0, 0.6, -5.2))
	_collide(r, Vector3(4.0, 1.2, 0.2), Vector3(0, 0.6, 0.0))


static func _safe_door(r: Dictionary, palette: Dictionary) -> void:
	var frame: Color = Palette.mul(DOOR_GREY, 0.8)
	for sx: float in [-1.0, 1.0]:
		_box(r, Vector3(0.3, 3.0, 0.45), Vector3(2.15 * sx, 1.5, 0.05), frame)
		_box(r, Vector3(0.08, 2.8, 0.08), Vector3(1.97 * sx, 1.4, -0.2), Palette.EXIT_GREEN, Vector3.ZERO, 1.0)
	_box(r, Vector3(4.6, 0.5, 0.45), Vector3(0, 3.25, 0.05), frame)
	_box(r, Vector3(4.0, 0.08, 0.08), Vector3(0, 2.86, -0.2), Palette.EXIT_GREEN, Vector3.ZERO, 1.0)
	_box(r, Vector3(4.6, 0.06, 0.6), Vector3(0, 0.03, -0.05), Palette.WARN_YELLOW)
	_box(r, Vector3(1.7, 0.42, 0.06), Vector3(0, 3.25, -0.2), Color("#123a24"), Vector3.ZERO, 0.2)
	var text: String = str(palette.get("label", "SAFE ROOM"))
	_label(r, text, Vector3(0, 3.25, -0.245), 56, Palette.EXIT_GREEN)
	for side: String in ["left", "right"]:
		var sx: float = -1.0 if side == "left" else 1.0
		var pp: Array = [
			_p(MeshUtil.box(Vector3(2.0, 2.8, 0.15)), Vector3.ZERO, DOOR_GREY),
			_p(MeshUtil.box(Vector3(0.55, 0.7, 0.02)), Vector3(0.2 * sx, 0.45, -0.08), Color("#ffe2b8"), Vector3.ZERO,
				Vector3.ONE, 0.7),
			_p(MeshUtil.box(Vector3(0.06, 0.6, 0.06)), Vector3(-0.8 * sx, 0.0, -0.1), Palette.RAIL, Vector3.ZERO,
				Vector3.ONE, 0.0, 1.0),
			_p(MeshUtil.box(Vector3(1.9, 0.1, 0.02)), Vector3(0, -0.9, -0.08), Palette.WARN_YELLOW),
		]
		(r["pivots"] as Array).append({"role": side, "pos": Vector3(1.0 * sx, 1.4, 0.0), "rot": Vector3.ZERO, "parts": pp})
	r["anim"] = "door"
	_shift(r, Vector3(0, 0, 0.45))


## Moves all parts/pivots/labels/holos/collision of a recipe (anchor-relative props such as the safe door).
static func _shift(r: Dictionary, off: Vector3) -> void:
	var t := Transform3D(Basis.IDENTITY, off)
	for key: String in ["parts"]:
		for p: Variant in (r[key] as Array):
			(p as Dictionary)["xform"] = t * ((p as Dictionary)["xform"] as Transform3D)
	for pv: Variant in (r["pivots"] as Array):
		(pv as Dictionary)["pos"] = ((pv as Dictionary)["pos"] as Vector3) + off
	for lv: Variant in (r["labels"] as Array):
		(lv as Dictionary)["pos"] = ((lv as Dictionary)["pos"] as Vector3) + off
	for hv: Variant in (r["holos"] as Array):
		(hv as Dictionary)["xform"] = t * ((hv as Dictionary)["xform"] as Transform3D)
	for gv: Variant in (r["glows"] as Array):
		var gd: Dictionary = gv
		if str(gd.get("parent", "")) == "":
			for p2: Variant in (gd["parts"] as Array):
				(p2 as Dictionary)["xform"] = t * ((p2 as Dictionary)["xform"] as Transform3D)
	for cv: Variant in (r["collision"] as Array):
		(cv as Dictionary)["xform"] = t * ((cv as Dictionary)["xform"] as Transform3D)


static func _vending(r: Dictionary, broken: bool) -> void:
	var body: Color = AUTOMAT_PINK if not broken else Palette.mul(AUTOMAT_PINK, 0.7)
	var tilt := Vector3(0, 0, 4) if broken else Vector3.ZERO
	var t := MeshUtil.xform(Vector3.ZERO, tilt)
	var local: Array = []
	local.append(_p(MeshUtil.box(Vector3(1.0, 1.9, 0.8)), Vector3(0, 0.95, 0), body))
	local.append(_p(MeshUtil.box(Vector3(1.04, 0.08, 0.84)), Vector3(0, 0.04, 0), DARK))
	local.append(_p(MeshUtil.box(Vector3(0.6, 1.1, 0.02)), Vector3(-0.12, 1.15, -0.41), Color("#ffe9b0"), Vector3.ZERO,
		Vector3.ONE, 0.0 if broken else 0.8))
	var cols: Array[Color] = [Color("#ff6a2b"), Color("#4ad9d9"), Color("#7cc242"), Color("#ffc93c"), Color("#b05cff"),
		Color("#e8455a")]
	for row in 4:
		local.append(_p(MeshUtil.box(Vector3(0.58, 0.02, 0.06)), Vector3(-0.12, 0.70 + 0.27 * float(row), -0.43),
			Palette.RAIL, Vector3.ZERO, Vector3.ONE, 0.0, 1.0))
		for c in 3:
			local.append(_p(MeshUtil.box(Vector3(0.1, 0.14, 0.06)),
				Vector3(-0.30 + 0.18 * float(c), 0.78 + 0.27 * float(row), -0.44), cols[(row * 3 + c) % cols.size()]))
	local.append(_p(MeshUtil.box(Vector3(0.05, 0.14, 0.02)), Vector3(0.36, 1.15, -0.41), Palette.NOVA_CYAN, Vector3.ZERO,
		Vector3.ONE, 1.0))
	for k in 6:
		local.append(_p(MeshUtil.box(Vector3(0.06, 0.05, 0.02)), Vector3(0.32 + 0.08 * float(k % 2), 0.95 - 0.07 * float(k / 2),
			-0.41), Palette.PAPER))
	local.append(_p(MeshUtil.box(Vector3(0.6, 0.18, 0.06)), Vector3(-0.12, 0.32, -0.41), DARK))
	local.append(_p(MeshUtil.box(Vector3(1.0, 0.25, 0.1)), Vector3(0, 1.78, -0.42), Palette.NOVA_MAGENTA, Vector3.ZERO,
		Vector3.ONE, 0.0 if broken else 0.9))
	if broken:
		local.append(_p(MeshUtil.box(Vector3(0.62, 0.03, 0.03)), Vector3(-0.12, 1.25, -0.43), DARK, Vector3(0, 0, 28)))
		local.append(_p(MeshUtil.box(Vector3(0.40, 0.03, 0.03)), Vector3(-0.2, 0.95, -0.43), DARK, Vector3(0, 0, -35)))
		local.append(_p(MeshUtil.box(Vector3(0.55, 0.22, 0.01)), Vector3(0.05, 1.45, -0.425), Color("#f2eee6"),
			Vector3(0, 0, -8)))
		local.append(_p(MeshUtil.box(Vector3(0.2, 0.3, 0.12)), Vector3(0.45, 0.6, -0.38), Palette.mul(body, 0.8),
			Vector3(15, 20, 10)))
	for p: Dictionary in local:
		var q: Dictionary = p.duplicate()
		q["xform"] = t * (p["xform"] as Transform3D)
		_add(r, q)
	if broken:
		(r["glows"] as Array).append({"role": "screen", "parts": [_p(MeshUtil.box(Vector3(0.56, 1.06, 0.01)),
			Vector3(-0.12, 1.15, -0.425), Color.WHITE)], "color": Color("#ffe9b0"), "energy": 1.6})
		_label(r, "AUSSER BETRIEB", t * Vector3(0.05, 1.45, -0.44), 22, Palette.LIVE_RED, Vector3(0, 180, 8))
		r["anim"] = "flicker"
	_label(r, "AUTOMAT", t * Vector3(0, 1.78, -0.48), 44, Palette.PAPER, Vector3(0, 180, -tilt.z))
	_collide(r, Vector3(1.0, 1.9, 0.8), Vector3(0, 0.95, 0))


static func _terminal(r: Dictionary) -> void:
	var c: Color = Palette.DARK_METAL
	_box(r, Vector3(0.7, 0.08, 0.6), Vector3(0, 0.04, 0), DARK)
	_box(r, Vector3(0.6, 1.1, 0.5), Vector3(0, 0.55, 0), c)
	_box(r, Vector3(0.62, 0.05, 0.42), Vector3(0, 1.13, -0.15), Palette.mul(c, 1.2), Vector3(-30, 0, 0))
	_box(r, Vector3(0.5, 0.02, 0.3), Vector3(0, 1.16, -0.16), Palette.NOVA_CYAN, Vector3(-30, 0, 0), 1.0)
	_box(r, Vector3(0.4, 0.06, 0.02), Vector3(0, 0.75, -0.26), Palette.NOVA_CYAN, Vector3.ZERO, 0.8)
	_box(r, Vector3(0.08, 0.08, 0.02), Vector3(0.18, 0.55, -0.26), Palette.HEAL, Vector3.ZERO, 1.0)
	(r["holos"] as Array).append({"role": "core", "mesh": MeshUtil.icosahedron(0.1),
		"xform": Transform3D(Basis.from_euler(Vector3(0.3, 0.5, 0.1)), Vector3(0, 1.48, 0.05)), "color": Palette.NOVA_CYAN,
		"alpha": 0.8})
	_collide(r, Vector3(0.6, 1.1, 0.5), Vector3(0, 0.55, 0))


static func _couch(r: Dictionary) -> void:
	var c := Color("#7a3b5a")
	_box(r, Vector3(2.0, 0.45, 0.9), Vector3(0, 0.225, 0), c)
	_box(r, Vector3(2.0, 0.6, 0.25), Vector3(0, 0.75, 0.325), Palette.mul(c, 0.9))
	for sx: float in [-1.0, 1.0]:
		_box(r, Vector3(0.25, 0.6, 0.9), Vector3(0.875 * sx, 0.40, 0), Palette.mul(c, 0.85))
		_add(r, _p(MeshUtil.capsule(0.12, 0.9), Vector3(0.38 * sx, 0.56, -0.02), Palette.mul(c, 1.15), Vector3(0, 0, 90)))
	_box(r, Vector3(0.6, 0.03, 0.9), Vector3(0.55, 0.73, 0.1), Color("#3aa9a0"), Vector3(-25, 0, 0))
	_box(r, Vector3(0.6, 0.55, 0.03), Vector3(0.55, 0.62, 0.47), Color("#3aa9a0"))
	_collide(r, Vector3(2.0, 0.9, 0.9), Vector3(0, 0.45, 0))


static func _crate(r: Dictionary, rng: RandomNumberGenerator) -> void:
	var n: int = rng.randi_range(1, 3)
	var y: float = 0.0
	for i in n:
		var s: float = rng.randf_range(0.6, 1.0) * (1.0 - 0.12 * float(i))
		var yaw: float = rng.randf_range(-15.0, 15.0)
		var c: Vector3 = Vector3(rng.randf_range(-0.08, 0.08), y + s * 0.5, rng.randf_range(-0.08, 0.08))
		_box(r, Vector3(s, s, s), c, Palette.WOOD, Vector3(0, yaw, 0))
		for k in 2:
			_box(r, Vector3(s + 0.04, 0.1 * s, s + 0.04), c + Vector3(0, (-0.25 + 0.5 * float(k)) * s, 0), Color("#6b4a2e"),
				Vector3(0, yaw, 0))
		_box(r, Vector3(s + 0.03, 0.08 * s, s * 0.12), c + Vector3(0, 0, -s * 0.5), Color("#6b4a2e"), Vector3(0, yaw, 45))
		_collide(r, Vector3(s, s, s), c, Vector3(0, yaw, 0))
		y += s


static func _barrel(r: Dictionary, rng: RandomNumberGenerator) -> void:
	var toxic: bool = rng.randf() < 0.34
	var c: Color = Palette.WARN_YELLOW if toxic else Color("#3e6b4a")
	_add(r, _p(MeshUtil.cylinder(0.30, 0.30, 0.90), Vector3(0, 0.45, 0), c))
	for y: float in [0.18, 0.72]:
		_add(r, _p(MeshUtil.cylinder(0.32, 0.32, 0.05), Vector3(0, y, 0), Palette.mul(c, 0.7), Vector3.ZERO, Vector3.ONE, 0.0,
			1.0))
	if toxic:
		_add(r, _p(MeshUtil.cylinder(0.27, 0.27, 0.03), Vector3(0, 0.91, 0), Color("#7cc242"), Vector3.ZERO, Vector3.ONE, 1.0))
		_box(r, Vector3(0.3, 0.25, 0.01), Vector3(0, 0.45, -0.305), DARK)
		_add(r, _p(MeshUtil.sphere(0.07), Vector3(0, 0.48, -0.31), Palette.WARN_YELLOW, Vector3.ZERO, Vector3(1, 1, 0.2)))
	_collide(r, Vector3(0.6, 0.9, 0.6), Vector3(0, 0.45, 0))


static func _bench(r: Dictionary) -> void:
	var c := Color("#2f6fb3")
	_box(r, Vector3(1.8, 0.08, 0.45), Vector3(0, 0.45, 0), c)
	_box(r, Vector3(1.8, 0.4, 0.06), Vector3(0, 0.75, 0.21), c, Vector3(-8, 0, 0))
	for sx: float in [-1.0, 1.0]:
		_box(r, Vector3(0.08, 0.45, 0.4), Vector3(0.75 * sx, 0.225, 0.02), Palette.RAIL, Vector3.ZERO, 0.0, 1.0)
	_collide(r, Vector3(1.8, 0.9, 0.5), Vector3(0, 0.45, 0))


static func _pillar(r: Dictionary, pal: Dictionary) -> void:
	var c: Color = Palette.mul(pal.get("wall", Color("#1f5f66")), 0.9)
	_add(r, _p(MeshUtil.cylinder(0.35, 0.35, 3.5), Vector3(0, 1.75, 0), c))
	_add(r, _p(MeshUtil.cylinder(0.36, 0.36, 0.3), Vector3(0, 1.0, 0), Palette.WARN_YELLOW))
	_add(r, _p(MeshUtil.cylinder(0.365, 0.365, 0.08), Vector3(0, 1.0, 0), DARK))
	_add(r, _p(MeshUtil.cylinder(0.42, 0.45, 0.2), Vector3(0, 0.1, 0), Palette.mul(c, 0.7)))
	_add(r, _p(MeshUtil.cylinder(0.45, 0.40, 0.25), Vector3(0, 3.38, 0), Palette.mul(c, 0.8)))
	_collide(r, Vector3(0.7, 3.5, 0.7), Vector3(0, 1.75, 0))


static func _lamp(r: Dictionary, rng: RandomNumberGenerator) -> void:
	if rng.randf() < 0.5:
		# sodium vapour mast lamp
		_add(r, seg(Vector3(0, 0, 0), Vector3(0, 3.0, 0), 0.06, 0.05, Palette.DARK_METAL, 0.0, 1.0))
		_add(r, seg(Vector3(0, 2.9, 0), Vector3(0, 3.05, -0.45), 0.04, 0.04, Palette.DARK_METAL, 0.0, 1.0))
		_box(r, Vector3(0.25, 0.15, 0.5), Vector3(0, 3.05, -0.55), Palette.DARK_METAL)
		_box(r, Vector3(0.2, 0.02, 0.44), Vector3(0, 2.97, -0.55), Palette.SODIUM, Vector3.ZERO, 1.0)
		_add(r, _p(MeshUtil.cylinder(0.2, 0.25, 0.1), Vector3(0, 0.05, 0), Palette.DARK_METAL))
		_collide(r, Vector3(0.3, 3.0, 0.3), Vector3(0, 1.5, 0))
	else:
		# hanging bulb lamp
		_add(r, seg(Vector3(0, 3.5, 0), Vector3(0, 2.75, 0), 0.012, 0.012, DARK))
		_add(r, _p(MeshUtil.hemisphere(0.25), Vector3(0, 2.62, 0), Palette.DARK_METAL, Vector3(180, 0, 0)))
		_add(r, _p(MeshUtil.sphere(0.09), Vector3(0, 2.52, 0), Color("#ffd27a"), Vector3.ZERO, Vector3.ONE, 1.0))


static func _trash(r: Dictionary) -> void:
	var c := Color("#3e6b4a")
	_add(r, _p(MeshUtil.cylinder(0.25, 0.22, 0.8), Vector3(0, 0.4, 0), c))
	_add(r, _p(MeshUtil.hemisphere(0.26), Vector3(0, 0.80, 0), Color("#2a2530")))
	_box(r, Vector3(0.14, 0.14, 0.02), Vector3(0, 0.5, -0.24), Palette.NOVA_MAGENTA, Vector3(0, 0, 45), 0.4)
	_box(r, Vector3(0.3, 0.06, 0.22), Vector3(0.12, 0.03, -0.25), Color("#cfcfcf"), Vector3(0, 30, 0))
	_collide(r, Vector3(0.5, 0.9, 0.5), Vector3(0, 0.45, 0))


static func _turnstile(r: Dictionary, rng: RandomNumberGenerator) -> void:
	var c := Color("#8a8f96")
	_box(r, Vector3(0.3, 1.0, 0.8), Vector3(0, 0.5, 0), c, Vector3.ZERO, 0.0, 1.0)
	_box(r, Vector3(0.34, 0.06, 0.84), Vector3(0, 1.03, 0), Palette.mul(c, 0.6))
	var hub := Vector3(-0.2, 0.9, 0)
	for k in 3:
		var a: float = TAU * float(k) / 3.0
		_add(r, seg(hub, hub + Vector3(-0.08, cos(a) * 0.4, sin(a) * 0.4).normalized() * 0.42, 0.022, 0.022, Palette.STEEL,
			0.0, 1.0))
	_box(r, Vector3(0.02, 0.08, 0.12), Vector3(0.16, 0.92, -0.25), Palette.EXIT_GREEN if rng.randf() < 0.6 else Palette.LIVE_RED,
		Vector3.ZERO, 1.0)
	_collide(r, Vector3(0.3, 1.0, 0.8), Vector3(0, 0.5, 0))


static func _poster(r: Dictionary, pal: Dictionary, rng: RandomNumberGenerator) -> void:
	var acc: Color = pal.get("accent", Palette.NOVA_MAGENTA)
	_box(r, Vector3(1.3, 1.7, 0.03), Vector3(0, 0, 0.01), DARK)
	_box(r, Vector3(1.2, 1.6, 0.03), Vector3(0, 0, -0.01), acc, Vector3.ZERO, 0.6)
	var motif: int = rng.randi_range(0, 2)
	match motif:
		0:
			_add(r, _p(MeshUtil.cylinder(0.32, 0.32, 0.02), Vector3(0, 0.25, -0.03), Palette.PAPER, Vector3(90, 0, 0),
				Vector3.ONE, 0.5))
			_box(r, Vector3(0.9, 0.12, 0.02), Vector3(0, -0.40, -0.03), Palette.PAPER, Vector3.ZERO, 0.5)
			_box(r, Vector3(0.6, 0.08, 0.02), Vector3(0, -0.58, -0.03), DARK)
		1:
			for k in 3:
				_box(r, Vector3(1.0, 0.1, 0.02), Vector3(0, 0.4 - 0.25 * float(k), -0.03), Palette.HYPE_GOLD, Vector3(0, 0, 12),
					0.5)
		_:
			_add(r, _p(MeshUtil.prism(Vector3(0.7, 0.7, 0.02)), Vector3(0, 0.2, -0.03), Palette.NOVA_CYAN, Vector3.ZERO,
				Vector3.ONE, 0.6))
			_box(r, Vector3(0.9, 0.15, 0.02), Vector3(0, -0.45, -0.03), Palette.PAPER, Vector3.ZERO, 0.5)


static func _drone(r: Dictionary) -> void:
	var body_parts: Array = [
		_p(MeshUtil.box(Vector3(0.5, 0.15, 0.5)), Vector3.ZERO, DARK),
		_p(MeshUtil.cylinder(0.09, 0.09, 0.2), Vector3(0, -0.06, -0.24), Palette.DARK_METAL, Vector3(90, 0, 0)),
		_p(MeshUtil.box(Vector3(0.12, 0.03, 0.02)), Vector3(0, 0.08, -0.26), Palette.NOVA_MAGENTA, Vector3.ZERO, Vector3.ONE, 1.0),
	]
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			body_parts.append(_p(MeshUtil.box(Vector3(0.24, 0.04, 0.04)), Vector3(0.22 * sx, 0.03, 0.22 * sz), DARK,
				Vector3(0, 45 * sx * sz, 0)))
			body_parts.append(_p(MeshUtil.torus(0.12, 0.14), Vector3(0.32 * sx, 0.08, 0.32 * sz), Palette.DARK_METAL,
				Vector3.ZERO, Vector3.ONE, 0.0, 1.0))
	(r["pivots"] as Array).append({"role": "body", "pos": Vector3.ZERO, "rot": Vector3.ZERO, "parts": body_parts})
	var i: int = 0
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			(r["pivots"] as Array).append({"role": "rotor%d" % i, "pos": Vector3(0.32 * sx, 0.10, 0.32 * sz), "rot": Vector3.ZERO,
				"parts": [_p(MeshUtil.box(Vector3(0.24, 0.01, 0.04)), Vector3.ZERO, Palette.RAIL)]})
			i += 1
	(r["glows"] as Array).append({"role": "lens", "parts": [_p(MeshUtil.sphere(0.06), Vector3(0, -0.06, -0.35), Color.WHITE)],
		"color": Palette.LIVE_RED, "energy": 3.0})
	r["anim"] = "drone"


static func _billboard(r: Dictionary, pal: Dictionary, palette: Dictionary) -> void:
	var c: Color = pal.get("accent", Palette.NOVA_MAGENTA)
	for sx: float in [-1.0, 1.0]:
		_add(r, seg(Vector3(1.2 * sx, 0, 0.1), Vector3(1.2 * sx, 1.8, 0.1), 0.06, 0.06, Palette.DARK_METAL, 0.0, 1.0))
	_box(r, Vector3(3.1, 1.3, 0.12), Vector3(0, 2.4, 0.05), Palette.DARK_METAL, Vector3.ZERO, 0.0, 1.0)
	_box(r, Vector3(3.0, 1.2, 0.04), Vector3(0, 2.4, -0.03), Palette.mul(c, 0.35))
	_box(r, Vector3(3.0, 0.08, 0.06), Vector3(0, 1.82, -0.05), c, Vector3.ZERO, 1.0)
	var q := QuadMesh.new()
	q.size = Vector2(2.9, 1.1)
	(r["holos"] as Array).append({"role": "screen", "mesh": q, "xform": Transform3D(Basis(Vector3.UP, PI), Vector3(0, 2.4, -0.06)),
		"color": c, "alpha": 0.45})
	_label(r, str(palette.get("label", "NOVA SYNDIKAT")), Vector3(0, 2.4, -0.09), 64, Palette.PAPER)


static func _rail(r: Dictionary) -> void:
	_box(r, Vector3(3.2, 0.2, 2.0), Vector3(0, 0.1, 0), Color("#3b3436"))
	for z: float in [-0.67, 0.0, 0.67]:
		_box(r, Vector3(2.4, 0.12, 0.25), Vector3(0, 0.26, z), Palette.SLEEPER)
	for sx: float in [-1.0, 1.0]:
		_box(r, Vector3(0.08, 0.15, 2.0), Vector3(0.72 * sx, 0.395, 0), Palette.RAIL, Vector3.ZERO, 0.0, 1.0)


## Derailed metro car (throne of the Rattenkönigin), tilted 12° (03_ART §6.3), ≤ 600 tris.
static func _wreck(r: Dictionary) -> void:
	var t := MeshUtil.xform(Vector3(0, 1.9, 0), Vector3(0, 0, 12))
	var local: Array = [
		_p(MeshUtil.box(Vector3(8.0, 3.0, 3.0)), Vector3.ZERO, Color("#8a8f96")),
		_p(MeshUtil.box(Vector3(8.2, 0.3, 3.1)), Vector3(0, 1.62, 0), Color("#6e6a72")),
		_p(MeshUtil.box(Vector3(8.04, 0.25, 3.04)), Vector3(0, -0.3, 0), Palette.WARN_YELLOW),
		_p(MeshUtil.box(Vector3(0.06, 2.2, 1.6)), Vector3(-4.02, 0.2, 0), Color("#5a5e66")),
		_p(MeshUtil.box(Vector3(0.05, 0.7, 1.2)), Vector3(-4.05, 0.7, 0), Color("#ffd27a"), Vector3.ZERO, Vector3.ONE, 0.8),
		_p(MeshUtil.box(Vector3(8.0, 0.3, 2.6)), Vector3(0, -1.6, 0), Color("#2a2530")),
	]
	for k in 3:
		for sz: float in [-1.0, 1.0]:
			local.append(_p(MeshUtil.box(Vector3(1.0, 0.8, 0.02)), Vector3(-2.4 + 2.4 * float(k), 0.45, 1.51 * sz),
				Color("#ffd27a"), Vector3.ZERO, Vector3.ONE, 0.9))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			local.append(_p(MeshUtil.cylinder(0.4, 0.4, 0.2), Vector3(2.8 * sx, -1.75, 1.2 * sz), Color("#2a2530"),
				Vector3(90, 0, 0)))
	for p: Dictionary in local:
		var q: Dictionary = p.duplicate()
		q["xform"] = t * (p["xform"] as Transform3D)
		_add(r, q)
	(r["collision"] as Array).append({"size": Vector3(8.0, 3.0, 3.0), "xform": t})


static func _pipe(r: Dictionary, rng: RandomNumberGenerator) -> void:
	var rad: float = 0.15 if rng.randf() < 0.6 else 0.25
	var c := Color("#8a4b2a")
	_add(r, _p(MeshUtil.cylinder(rad, rad, 2.0), Vector3(0, 0.5, 0), c, Vector3(0, 0, 90)))
	for sx: float in [-1.0, 1.0]:
		_add(r, _p(MeshUtil.cylinder(rad + 0.03, rad + 0.03, 0.12), Vector3(0.9 * sx, 0.5, 0), Palette.mul(c, 0.75),
			Vector3(0, 0, 90), Vector3.ONE, 0.0, 1.0))
	_add(r, _p(MeshUtil.box(Vector3(rad * 2.2, rad * 2.2, rad * 2.2)), Vector3(1.0, 0.5, 0), Palette.mul(c, 0.9)))
	_add(r, _p(MeshUtil.cylinder(rad, rad, 1.2), Vector3(1.0, 1.1, 0), c))
	_add(r, seg(Vector3(0, 0.5 + rad, 0), Vector3(0, 0.75 + rad, 0), 0.03, 0.03, Palette.DARK_METAL, 0.0, 1.0))
	_add(r, _p(MeshUtil.torus(0.08, 0.12, 8, 3), Vector3(0, 0.76 + rad, 0), Color("#c23b22"), Vector3.ZERO, Vector3.ONE, 0.0,
		1.0))


## Closed door bar for a 4 m door opening (gate, 02_TECH §7.3): front −Z, spans X.
static func _gate(r: Dictionary) -> void:
	for sx: float in [-1.0, 1.0]:
		_box(r, Vector3(0.22, 3.0, 0.3), Vector3(2.0 * sx, 1.5, 0), Palette.DARK_METAL, Vector3.ZERO, 0.0, 1.0)
	for k in 7:
		var x: float = -1.5 + 0.5 * float(k)
		_add(r, seg(Vector3(x, 0.05, 0), Vector3(x, 2.95, 0), 0.04, 0.04, Palette.RAIL, 0.0, 1.0))
	for y: float in [0.4, 2.7]:
		_box(r, Vector3(4.0, 0.12, 0.12), Vector3(0, y, 0), Palette.DARK_METAL, Vector3.ZERO, 0.0, 1.0)
	for k in 6:
		_box(r, Vector3(0.5, 0.42, 0.08), Vector3(-1.25 + 0.5 * float(k), 1.5, -0.03),
			Palette.WARN_YELLOW if k % 2 == 0 else DARK)
	_box(r, Vector3(0.22, 0.26, 0.10), Vector3(0.0, 1.1, -0.1), Palette.LIVE_RED, Vector3.ZERO, 0.0, 1.0)
	_add(r, _p(MeshUtil.torus(0.05, 0.08), Vector3(0, 1.27, -0.1), Palette.STEEL, Vector3.ZERO, Vector3.ONE, 0.0, 1.0))
	_label(r, "GESPERRT", Vector3(0, 2.1, -0.08), 48, Palette.WARN_YELLOW)
	_collide(r, Vector3(4.0, 3.0, 0.3), Vector3(0, 1.5, 0))


## Telefonzelle with Herr Brettschneider (fev_lost_candidate).
static func _phone_booth(r: Dictionary) -> void:
	var c := Palette.WARN_YELLOW
	_box(r, Vector3(1.2, 0.1, 1.2), Vector3(0, 0.05, 0), Palette.DARK_METAL)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_box(r, Vector3(0.1, 2.3, 0.1), Vector3(0.53 * sx, 1.2, 0.53 * sz), c)
	_box(r, Vector3(1.24, 0.16, 1.24), Vector3(0, 2.38, 0), c)
	_box(r, Vector3(1.0, 0.25, 0.06), Vector3(0, 2.1, -0.56), Palette.PAPER, Vector3.ZERO, 0.8)
	_box(r, Vector3(1.0, 2.2, 0.05), Vector3(0, 1.15, 0.53), Palette.mul(c, 0.85))
	for sx: float in [-1.0, 1.0]:
		_box(r, Vector3(0.05, 0.08, 1.0), Vector3(0.53 * sx, 1.0, 0), c)
	_box(r, Vector3(0.25, 0.35, 0.12), Vector3(0.25, 1.45, 0.45), DARK)
	_add(r, seg(Vector3(0.25, 1.35, 0.42), Vector3(0.05, 1.25, 0.2), 0.012, 0.012, DARK))
	# Herr Brettschneider (lost candidate): small chibi in a brown suit, phone to the ear
	var suit := Color("#6b5a4a")
	var skin := Color("#e8c09a")
	_add(r, _p(MeshUtil.capsule(0.17, 0.62), Vector3(0, 0.62, 0.05), suit))
	_add(r, _p(MeshUtil.sphere(0.2), Vector3(0, 1.12, 0.03), skin))
	_add(r, _p(MeshUtil.cylinder(0.16, 0.16, 0.16), Vector3(0, 1.32, 0.03), Color("#3a2a22")))
	_add(r, _p(MeshUtil.cylinder(0.25, 0.25, 0.02), Vector3(0, 1.24, 0.03), Color("#3a2a22")))
	for sx: float in [-1.0, 1.0]:
		_add(r, _p(MeshUtil.sphere(0.025), Vector3(0.07 * sx, 1.13, -0.16), DARK))
	_add(r, _p(MeshUtil.capsule(0.06, 0.35), Vector3(0.17, 0.98, -0.05), suit, Vector3(-30, 0, -40)))
	_add(r, _p(MeshUtil.box(Vector3(0.05, 0.16, 0.05)), Vector3(0.2, 1.12, -0.1), DARK, Vector3(0, 0, 20)))
	var glass := QuadMesh.new()
	glass.size = Vector2(0.96, 1.9)
	(r["holos"] as Array).append({"role": "glass", "mesh": glass, "xform": Transform3D(Basis(Vector3.UP, PI),
		Vector3(0, 1.2, -0.55)), "color": Color("#9fe8ff"), "alpha": 0.12, "energy": 1.0})
	_label(r, "TELEFON", Vector3(0, 2.1, -0.6), 40, DARK)
	_collide(r, Vector3(1.2, 2.4, 1.2), Vector3(0, 1.2, 0))


## Glücksrad von DoomScroll+ (fev_wheel): wheel pivot spins on play_action().
static func _fortune_wheel(r: Dictionary) -> void:
	var purple := Color("#7a5cff")
	_box(r, Vector3(1.6, 0.25, 0.9), Vector3(0, 0.125, 0), Palette.DARK_METAL)
	for sx: float in [-1.0, 1.0]:
		_add(r, seg(Vector3(0.6 * sx, 0.2, 0.15), Vector3(0.15 * sx, 2.0, 0.15), 0.07, 0.06, purple, 0.0, 1.0))
	_add(r, _p(MeshUtil.prism(Vector3(0.25, 0.3, 0.08)), Vector3(0, 3.27, -0.2), Palette.LIVE_RED, Vector3(180, 0, 0)))
	_box(r, Vector3(1.8, 0.45, 0.1), Vector3(0, 3.65, 0.1), purple, Vector3.ZERO, 0.6)
	_label(r, "DoomScroll+", Vector3(0, 3.65, 0.03), 56, Palette.PAPER)
	var seg_cols: Array[Color] = [Color("#b05cff"), Palette.NOVA_MAGENTA, Palette.HYPE_GOLD, Palette.NOVA_CYAN]
	var wheel_parts: Array = []
	var radius: float = 1.1
	for k in 8:
		var a: float = TAU * float(k) / 8.0
		var mid: Vector3 = Vector3(sin(a), cos(a), 0) * radius * 0.5
		wheel_parts.append(_p(MeshUtil.prism(Vector3(2.0 * radius * sin(PI / 8.0), radius, 0.06)), mid,
			seg_cols[k % 4], Vector3(0, 0, 180 - rad_to_deg(a)), Vector3.ONE, 0.25))
	wheel_parts.append(_p(MeshUtil.torus(radius - 0.02, radius + 0.08), Vector3.ZERO, Palette.HYPE_GOLD, Vector3(90, 0, 0),
		Vector3.ONE, 0.2, 1.0))
	for k in 8:
		var a2: float = TAU * (float(k) + 0.5) / 8.0
		wheel_parts.append(_p(MeshUtil.sphere(0.05), Vector3(sin(a2), cos(a2), -0.04) * Vector3(radius, radius, 1.0),
			Palette.PAPER, Vector3.ZERO, Vector3.ONE, 0.6))
	wheel_parts.append(_p(MeshUtil.cylinder(0.16, 0.16, 0.12), Vector3(0, 0, -0.04), Palette.STEEL, Vector3(90, 0, 0),
		Vector3.ONE, 0.0, 1.0))
	(r["pivots"] as Array).append({"role": "wheel", "pos": Vector3(0, 2.05, -0.05), "rot": Vector3.ZERO, "parts": wheel_parts})
	r["anim"] = "wheel"
	_collide(r, Vector3(1.6, 3.2, 0.9), Vector3(0, 1.6, 0))


## Verdächtiger Hebel (fev_lever): machine block with a lever on top, pipes into the floor.
static func _lever(r: Dictionary) -> void:
	var c := Palette.DARK_METAL
	_box(r, Vector3(0.8, 0.9, 0.6), Vector3(0, 0.45, 0), c, Vector3.ZERO, 0.0, 1.0)
	_box(r, Vector3(0.86, 0.06, 0.66), Vector3(0, 0.92, 0), Palette.WARN_YELLOW)
	_box(r, Vector3(0.1, 0.03, 0.4), Vector3(0, 0.96, 0), DARK)
	for sx: float in [-1.0, 1.0]:
		_add(r, seg(Vector3(0.3 * sx, 0.0, 0.32), Vector3(0.3 * sx, 0.7, 0.32), 0.07, 0.07, Color("#8a4b2a")))
		_add(r, _p(MeshUtil.torus(0.07, 0.1), Vector3(0.3 * sx, 0.5, 0.32), Palette.mul(Color("#8a4b2a"), 0.7)))
	_box(r, Vector3(0.5, 0.35, 0.02), Vector3(0, 0.55, -0.31), Palette.WARN_YELLOW, Vector3.ZERO, 0.3)
	_label(r, "?", Vector3(0, 0.55, -0.33), 80, DARK)
	_add(r, _p(MeshUtil.sphere(0.05), Vector3(0.28, 0.98, -0.2), Palette.LIVE_RED, Vector3.ZERO, Vector3.ONE, 1.0))
	(r["pivots"] as Array).append({"role": "arm", "pos": Vector3(0, 0.97, 0.12), "rot": Vector3(-30, 0, 0), "parts": [
		seg(Vector3.ZERO, Vector3(0, 0.6, 0), 0.03, 0.03, Palette.STEEL, 0.0, 1.0),
		_p(MeshUtil.sphere(0.08), Vector3(0, 0.62, 0), Palette.LIVE_RED),
	]})
	r["anim"] = "lever"
	_collide(r, Vector3(0.8, 0.9, 0.6), Vector3(0, 0.45, 0))
