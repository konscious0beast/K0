extends RefCounted
## Part recipes per ModelSpec.base + props (03_ART §5.3/§5.4). Private helper of CharacterBuilder (02_TECH §0.3, no
## class_name). blueprint() returns a plain description (pivots, meshes as part lists, anchors, particles); the builder
## turns it into nodes. Coordinates: meters at ModelSpec.scale 1.0, +Y up, front = −Z, right hand = +X.
##
## Blueprint keys:
##   base, pose (StringName), colors (Dictionary slot → Color), props (PackedStringArray), seed,
##   pivots: Array[String] (creation order), pivot_parent/pivot_pos/pivot_rot/pivot_scale: Dictionary by pivot
##     (pos local to the parent pivot, rot in degrees),
##   meshes: Dictionary mesh name → {"pivot", "parts": Array, "mat": Dictionary (Materials opts), "pulse": Dictionary,
##     "role": String}, mesh_order: Array[String],
##   anchors: Dictionary anchor → {"pivot", "pos"}, sockets: Dictionary socket → {"pivot", "pos", "size", "rot"},
##   particles: Array[Dictionary] ({"kind", "pivot", "pos"}), mat: Dictionary (default material opts), flags: Dictionary.

const BASES: PackedStringArray = ["humanoid", "pug", "rodent", "blob", "insect", "robot", "brute", "specter", "swarm"]
const PROPS: PackedStringArray = ["cape", "crown", "monocle", "top_hat", "cap", "bandana", "apron", "mop", "broom",
	"knife", "staff", "key_ring", "glasses", "lamp_helmet", "backpack", "mask", "wings", "antennae",
	"newspaper_head", "briefcase", "bottlecap_chain", "cable_tangle", "spray_cap", "escalator_back", "claws", "helmet",
	"shield", "halberd", "rat_king_tail", "ticket_crown", "wrench", "axe", "crowbar", "cart"]

## Nominal heights at scale 1.0 (02_TECH §8.4).
const NOMINAL_HEIGHT: Dictionary = {"humanoid": 1.75, "pug": 0.6, "rodent": 0.7, "blob": 0.9, "insect": 0.8,
	"robot": 1.5, "brute": 2.2, "specter": 1.6, "swarm": 0.8}

const DEFAULT_COLORS: Dictionary = {
	"humanoid": {"primary": "#3aa9a0", "secondary": "#2e3a57", "accent": "#3b2a22", "skin": "#e8b48f", "eyes": "#1a1420"},
	"pug": {"primary": "#d8b98a", "secondary": "#2a2024", "accent": "#7b2cbf", "skin": "#d8b98a", "eyes": "#1a1420"},
	"rodent": {"primary": "#6b5b4e", "secondary": "#e88a9a", "accent": "#3e2f5b", "skin": "#e88a9a", "eyes": "#ff3030"},
	"blob": {"primary": "#6fbf4a", "secondary": "#d93b3b", "accent": "#9fe8ff", "skin": "#6fbf4a", "eyes": "#1a1420"},
	"insect": {"primary": "#2b2b33", "secondary": "#c2453a", "accent": "#c2453a", "skin": "#2b2b33", "eyes": "#ffb000"},
	"robot": {"primary": "#2f6fb3", "secondary": "#24578c", "accent": "#9af2ff", "skin": "#2f6fb3", "eyes": "#f5f0e6"},
	"brute": {"primary": "#7c8a94", "secondary": "#3e4a55", "accent": "#4a3a30", "skin": "#d9a88a", "eyes": "#1a1420"},
	"specter": {"primary": "#e23e9b", "secondary": "#ffffff", "accent": "#4ad9d9", "skin": "#e23e9b", "eyes": "#1a1420"},
	"swarm": {"primary": "#8c93a6", "secondary": "#5fa38e", "accent": "#e0a040", "skin": "#8c93a6", "eyes": "#ff9a2e"},
}

const BLACK_SHOE: Color = Color("#1f1f24")
const DARK: Color = Color("#1a1420")
const TOOTH: Color = Color("#f5f5f0")
const WOOD_HANDLE: Color = Color("#8a5a32")
const STAFF_WOOD: Color = Color("#6b4a2e")
const MOUTH: Color = Color("#8a3b3b")
const RQ: float = 1.25   # rodent quadruped: 03_ART table values are for scale 0.8 → stored / 0.8


# --- entry ---------------------------------------------------------------------------------------------------------

## m: normalized ModelSpec ({"base", "scale", "pose" (StringName resolved), "colors" (slot → Color), "props"}).
static func blueprint(m: Dictionary, seed: int) -> Dictionary:
	var base: String = str(m.get("base", "humanoid"))
	if not BASES.has(base):
		base = "humanoid"
	var bp: Dictionary = {
		"base": base, "pose": m.get("pose", &"upright"), "colors": m.get("colors", {}),
		"props": m.get("props", PackedStringArray()), "seed": seed,
		"pivots": [], "pivot_parent": {}, "pivot_pos": {}, "pivot_rot": {}, "pivot_scale": {},
		"meshes": {}, "mesh_order": [], "anchors": {}, "sockets": {}, "particles": [],
		"mat": {"bands": 3, "rim": 0.45}, "flags": {},
	}
	# brute below boss size (scale < 1.0) → compact recipe within the enemy budget (02_TECH §12.1)
	bp["flags"]["compact"] = base == "brute" and float(m.get("scale", 1.0)) < 1.0
	match base:
		"humanoid":
			_humanoid(bp)
		"pug":
			_pug(bp)
		"rodent":
			if StringName(bp["pose"]) == &"upright":
				_rodent_upright(bp)
			else:
				_rodent_quadruped(bp)
		"blob":
			_blob(bp)
		"insect":
			_insect(bp)
		"robot":
			_robot(bp)
		"brute":
			_brute(bp)
		"specter":
			_specter(bp)
		"swarm":
			_swarm(bp)
	_apply_props(bp)
	return bp


static func default_colors(base: String) -> Dictionary:
	var src: Dictionary = DEFAULT_COLORS.get(base, DEFAULT_COLORS["humanoid"])
	var out: Dictionary = {}
	for k: String in src:
		out[k] = Palette.hex(str(src[k]))
	return out


# --- blueprint helpers ---------------------------------------------------------------------------------------------

static func _has(bp: Dictionary, prop: String) -> bool:
	return (bp["props"] as PackedStringArray).has(prop)


static func _col(bp: Dictionary, slot: String) -> Color:
	return (bp["colors"] as Dictionary).get(slot, Color.MAGENTA)


## Pivot at rig coordinates (scale 1). Parent "" = model root. Parents must be unrotated/unscaled for this form.
static func _pivot(bp: Dictionary, pname: String, parent: String, rig_pos: Vector3) -> void:
	var parent_rig: Vector3 = _pivot_rig_pos(bp, parent)
	_pivot_local(bp, pname, parent, rig_pos - parent_rig)


static func _pivot_local(bp: Dictionary, pname: String, parent: String, local_pos: Vector3,
		rot_deg: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> void:
	if not (bp["pivots"] as Array).has(pname):
		(bp["pivots"] as Array).append(pname)
	bp["pivot_parent"][pname] = parent
	bp["pivot_pos"][pname] = local_pos
	bp["pivot_rot"][pname] = rot_deg
	bp["pivot_scale"][pname] = scl


static func _pivot_rig_pos(bp: Dictionary, pname: String) -> Vector3:
	var pos := Vector3.ZERO
	var cur: String = pname
	var guard: int = 0
	while cur != "" and guard < 16:
		pos += bp["pivot_pos"].get(cur, Vector3.ZERO)
		cur = str(bp["pivot_parent"].get(cur, ""))
		guard += 1
	return pos


static func _has_pivot(bp: Dictionary, pname: String) -> bool:
	return (bp["pivots"] as Array).has(pname)


static func _mesh(bp: Dictionary, mesh_name: String, pivot: String) -> Dictionary:
	var meshes: Dictionary = bp["meshes"]
	if not meshes.has(mesh_name):
		meshes[mesh_name] = {"pivot": pivot, "parts": [], "mat": {}, "pulse": {}, "role": ""}
		(bp["mesh_order"] as Array).append(mesh_name)
	return meshes[mesh_name]


## Adds a part (MeshUtil.part dictionary, pivot-local) to the mesh `mesh_name` (default: pivot name).
static func _add(bp: Dictionary, pivot: String, p: Dictionary, mesh_name: String = "") -> void:
	var mn: String = pivot if mesh_name == "" else mesh_name
	(_mesh(bp, mn, pivot)["parts"] as Array).append(p)


static func _anchor(bp: Dictionary, aname: String, pivot: String, pos: Vector3) -> void:
	bp["anchors"][aname] = {"pivot": pivot, "pos": pos}


static func _socket(bp: Dictionary, sname: String, pivot: String, pos: Vector3, size: float,
		rot_deg: Vector3 = Vector3.ZERO) -> void:
	bp["sockets"][sname] = {"pivot": pivot, "pos": pos, "size": size, "rot": rot_deg}


static func _p(mesh: Mesh, pos: Vector3, color: Color, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE,
		emission: float = 0.0, metal: float = 0.0) -> Dictionary:
	return MeshUtil.part(mesh, pos, color, rot, scl, emission, metal)


## Cylinder part spanning a → b (pivot-local).
static func _seg(a: Vector3, b: Vector3, r_a: float, r_b: float, color: Color, emission: float = 0.0,
		metal: float = 0.0) -> Dictionary:
	var d: Vector3 = b - a
	var length: float = maxf(d.length(), 0.001)
	var dir: Vector3 = d / length
	var basis := Basis.IDENTITY
	if dir.dot(Vector3.UP) < -0.9999:
		basis = Basis(Vector3.RIGHT, PI)
	elif dir.dot(Vector3.UP) < 0.9999:
		basis = Basis(Quaternion(Vector3.UP, dir))
	return {"mesh": MeshUtil.cylinder(r_b, r_a, length), "xform": Transform3D(basis, (a + b) * 0.5),
		"color": color, "emission": emission, "metal": metal}


## Places prop parts (defined relative to the socket origin at reference size `ref`) on a socket.
static func _place(bp: Dictionary, socket: String, ref: float, parts: Array, mesh_name: String = "") -> void:
	var s: Dictionary = bp["sockets"].get(socket, {})
	if s.is_empty():
		s = bp["sockets"].get("body", {"pivot": str((bp["pivots"] as Array)[0]), "pos": Vector3.ZERO, "size": ref,
			"rot": Vector3.ZERO})
	var k: float = float(s["size"]) / maxf(ref, 0.0001)
	var st := Transform3D(Basis.from_euler((s["rot"] as Vector3) * (PI / 180.0)).scaled(Vector3(k, k, k)),
		s["pos"] as Vector3)
	for p: Dictionary in parts:
		var q: Dictionary = p.duplicate()
		q["xform"] = st * (p["xform"] as Transform3D)
		_add(bp, str(s["pivot"]), q, mesh_name)


## Creates a pivot at socket origin + offset (scaled like the socket) and returns its name; parts added to it
## must be scaled by socket_scale(); returns the scale factor through bp flags.
static func _socket_pivot(bp: Dictionary, socket: String, ref: float, pname: String, offset: Vector3) -> float:
	var s: Dictionary = bp["sockets"].get(socket, bp["sockets"].get("body", {}))
	if s.is_empty():
		_pivot_local(bp, pname, "", offset)
		return 1.0
	var k: float = float(s["size"]) / maxf(ref, 0.0001)
	var rb := Basis.from_euler((s["rot"] as Vector3) * (PI / 180.0))
	_pivot_local(bp, pname, str(s["pivot"]), (s["pos"] as Vector3) + rb * (offset * k), s["rot"] as Vector3)
	return k


static func _scaled_parts(parts: Array, k: float) -> Array:
	var out: Array = []
	var st := Transform3D(Basis.from_scale(Vector3(k, k, k)), Vector3.ZERO)
	for p: Dictionary in parts:
		var q: Dictionary = p.duplicate()
		q["xform"] = st * (p["xform"] as Transform3D)
		out.append(q)
	return out


static func _common_anchor_set(bp: Dictionary, head_pivot: String, head_pos: Vector3, center_pivot: String,
		center_pos: Vector3, overhead_pos: Vector3) -> void:
	_anchor(bp, "head", head_pivot, head_pos)
	_anchor(bp, "center", center_pivot, center_pos)
	_anchor(bp, "overhead", head_pivot, overhead_pos)


# --- humanoid (Kai, Pendler; 03_ART §5.3) ---------------------------------------------------------------------------

static func _humanoid(bp: Dictionary) -> void:
	var prim: Color = _col(bp, "primary")
	var sec: Color = _col(bp, "secondary")
	var acc: Color = _col(bp, "accent")
	var skin: Color = _col(bp, "skin")
	var eyes: Color = _col(bp, "eyes")
	var news: bool = _has(bp, "newspaper_head")
	# eyes == skin → faceless mannequin (03_ART §5.7 Schaufensterpuppe): bald, no ears/face/collar, joint spheres
	var faceless: bool = eyes.is_equal_approx(skin)
	_pivot(bp, "Hips", "", Vector3(0, 0.60, 0))
	_pivot(bp, "Torso", "Hips", Vector3(0, 0.60, 0))
	_pivot(bp, "Head", "Torso", Vector3(0, 1.12, 0))
	_pivot(bp, "ArmL", "Torso", Vector3(-0.32, 1.04, 0))
	_pivot(bp, "ArmR", "Torso", Vector3(0.32, 1.04, 0))
	_pivot(bp, "LegL", "Hips", Vector3(-0.13, 0.55, 0))
	_pivot(bp, "LegR", "Hips", Vector3(0.13, 0.55, 0))
	# Torso (hip box merged in, Hips has no mesh)
	_add(bp, "Torso", _p(MeshUtil.box(Vector3(0.50, 0.12, 0.36)), Vector3(0, 0.0, 0), sec))
	_add(bp, "Torso", _p(MeshUtil.capsule(0.24, 0.62), Vector3(0, 0.26, 0), prim))
	if news:
		_add(bp, "Torso", _p(MeshUtil.box(Vector3(0.16, 0.22, 0.02)), Vector3(0, 0.42, -0.226), Color("#d9d9d9"),
			Vector3(-6, 0, 0)))
		_add(bp, "Torso", _p(MeshUtil.cylinder(0.035, 0.06, 0.32), Vector3(0, 0.30, -0.24), acc, Vector3(-6, 0, 0)))
	elif faceless:
		# shoulder joints (Sphere 0.06 class: small segment count) at the arm pivots, rig-local to Torso
		for sx: float in [-1.0, 1.0]:
			_add(bp, "Torso", _p(MeshUtil.sphere(0.058), Vector3(0.30 * sx, 0.44, 0), Palette.mul(skin, 0.9)))
	else:
		_add(bp, "Torso", _p(MeshUtil.torus(0.10, 0.20), Vector3(0, 0.50, 0.10), Palette.mul(prim, 0.8),
			Vector3(-70, 0, 0)))
		_add(bp, "Torso", _p(MeshUtil.box(Vector3(0.30, 0.12, 0.03)), Vector3(0, 0.10, -0.235), Palette.mul(prim, 0.8)))
		_add(bp, "Torso", _p(MeshUtil.box(Vector3(0.12, 0.07, 0.02)), Vector3(-0.12, 0.38, -0.235), Color("#f2f2ea")))
		_add(bp, "Torso", _p(MeshUtil.box(Vector3(0.06, 0.06, 0.02)), Vector3(0.11, 0.38, -0.236), Palette.HYPE_GOLD,
			Vector3(0, 0, 45), Vector3.ONE, 0.4))
	# Head
	if news:
		_newspaper_head(bp, "Head", Vector3(0, 0.26, 0), 1.0)
	elif faceless:
		_add(bp, "Head", _p(MeshUtil.sphere(0.28), Vector3(0, 0.26, 0), skin, Vector3.ZERO, Vector3(0.94, 1.08, 1.0)))
	else:
		_add(bp, "Head", _p(MeshUtil.sphere(0.28), Vector3(0, 0.26, 0), skin))
		_add(bp, "Head", _p(MeshUtil.sphere(0.30), Vector3(0, 0.36, 0.04), acc, Vector3.ZERO, Vector3(1, 0.72, 1)))
		_add(bp, "Head", _p(MeshUtil.capsule(0.055, 0.40), Vector3(0, 0.425, -0.19), acc, Vector3(-20, 0, 90),
			Vector3(1.35, 1.2, 1.1)))
		_add(bp, "Head", _p(MeshUtil.cone(0.07, 0.16), Vector3(0.06, 0.60, 0.04), acc, Vector3(-25, 0, -20)))
		_add(bp, "Head", _p(MeshUtil.cone(0.06, 0.13), Vector3(-0.07, 0.59, 0.08), acc, Vector3(-35, 0, 25)))
		for sx: float in [-1.0, 1.0]:
			_add(bp, "Head", _p(MeshUtil.sphere(0.05), Vector3(0.28 * sx, 0.25, 0), skin))
			_add(bp, "Head", _p(MeshUtil.capsule(0.035, 0.11), Vector3(0.10 * sx, 0.27, -0.255), eyes))
			_add(bp, "Head", _p(MeshUtil.sphere(0.016), Vector3(0.10 * sx - 0.012, 0.30, -0.284), Palette.PAPER,
				Vector3.ZERO, Vector3.ONE, 1.0))
			_add(bp, "Head", _p(MeshUtil.sphere(0.045), Vector3(0.165 * sx, 0.17, -0.225), skin.lerp(Color("#ff6f7d"), 0.45),
				Vector3.ZERO, Vector3(1, 0.6, 0.35)))
		_add(bp, "Head", _p(MeshUtil.box(Vector3(0.08, 0.015, 0.01)), Vector3(0, 0.15, -0.275), MOUTH))
	# Arms
	for arm: String in ["ArmL", "ArmR"]:
		_add(bp, arm, _p(MeshUtil.capsule(0.085, 0.48), Vector3(0, -0.20, 0), prim))
		_add(bp, arm, _p(MeshUtil.sphere(0.095), Vector3(0, -0.46, 0), skin))
	# Legs
	for leg: String in ["LegL", "LegR"]:
		_add(bp, leg, _p(MeshUtil.capsule(0.11, 0.50), Vector3(0, -0.22, 0), sec))
		_add(bp, leg, _p(MeshUtil.box(Vector3(0.18, 0.12, 0.28)), Vector3(0, -0.49, -0.04), BLACK_SHOE))
		_add(bp, leg, _p(MeshUtil.box(Vector3(0.19, 0.03, 0.29)), Vector3(0, -0.545, -0.04), Palette.PAPER))
	_common_anchor_set(bp, "Head", Vector3(0, 0.26, 0), "Torso", Vector3(0, 0.30, 0), Vector3(0, 0.83, 0))
	_anchor(bp, "hand_r", "ArmR", Vector3(0, -0.46, 0))
	_anchor(bp, "hand_l", "ArmL", Vector3(0, -0.46, 0))
	_socket(bp, "head", "Head", Vector3(0, 0.26, 0), 0.28)
	_socket(bp, "eyes", "Head", Vector3(0, 0.27, -0.27), 0.10)
	_socket(bp, "back", "Torso", Vector3(0, 0.30, 0.24), 0.24)
	_socket(bp, "chest", "Torso", Vector3(0, 0.30, -0.24), 0.24)
	_socket(bp, "belly", "Torso", Vector3(0, 0.10, -0.24), 0.24)
	_socket(bp, "hip_r", "Torso", Vector3(0.25, 0.0, 0.0), 0.24)
	_socket(bp, "body", "Torso", Vector3(0, 0.26, 0), 0.24)
	_socket(bp, "hand_r", "ArmR", Vector3(0, -0.46, 0), 1.0)
	_socket(bp, "hand_l", "ArmL", Vector3(0, -0.46, 0), 1.0)


## Pendler costume head: newspaper with clock (03_ART §5.4 newspaper_head). `c` = head center, k = scale.
static func _newspaper_head(bp: Dictionary, pivot: String, c: Vector3, k: float) -> void:
	_add(bp, pivot, _p(MeshUtil.box(Vector3(0.42, 0.50, 0.12) * k), c, Color("#e8e4d8"), Vector3(0, 0, -4)))
	_add(bp, pivot, _p(MeshUtil.box(Vector3(0.36, 0.06, 0.012) * k), c + Vector3(0, 0.17, -0.062) * k, Color("#2a2a2a"),
		Vector3(0, 0, -4)))
	for i in 4:
		var w: float = 0.30 if i % 2 == 0 else 0.22
		_add(bp, pivot, _p(MeshUtil.box(Vector3(w, 0.022, 0.01) * k),
			c + Vector3(-0.04 + 0.02 * float(i % 2), 0.08 - 0.06 * float(i), -0.065) * k, Color("#5a5650"),
			Vector3(0, 0, -4)))
	_add(bp, pivot, _p(MeshUtil.cylinder(0.07 * k, 0.07 * k, 0.012 * k), c + Vector3(0.12, -0.16, -0.068) * k,
		Color.WHITE, Vector3(90, 0, 0), Vector3.ONE, 0.6))
	_add(bp, pivot, _p(MeshUtil.box(Vector3(0.008, 0.05, 0.006) * k), c + Vector3(0.12, -0.14, -0.076) * k, DARK,
		Vector3(0, 0, 20)))
	_add(bp, pivot, _p(MeshUtil.box(Vector3(0.008, 0.035, 0.006) * k), c + Vector3(0.125, -0.165, -0.076) * k, DARK,
		Vector3(0, 0, -70)))


# --- pug (Graf Mopsula) ---------------------------------------------------------------------------------------------

static func _pug(bp: Dictionary) -> void:
	var prim: Color = _col(bp, "primary")
	var sec: Color = _col(bp, "secondary")
	var eyes: Color = _col(bp, "eyes")
	_pivot(bp, "Body", "", Vector3.ZERO)
	_pivot(bp, "Head", "Body", Vector3(0, 0.44, -0.22))
	_add(bp, "Body", _p(MeshUtil.capsule(0.17, 0.52), Vector3(0, 0.27, 0.02), prim, Vector3(90, 0, 0)))
	_add(bp, "Body", _p(MeshUtil.torus(0.025, 0.06), Vector3(0, 0.42, 0.25), prim, Vector3(0, 0, 90)))
	for sx: float in [-1.0, 1.0]:
		for z: float in [-0.14, 0.18]:
			_add(bp, "Body", _p(MeshUtil.cylinder(0.045, 0.05, 0.18), Vector3(0.10 * sx, 0.09, z), prim))
			_add(bp, "Body", _p(MeshUtil.sphere(0.05), Vector3(0.10 * sx, 0.02, z - 0.02), Palette.mul(prim, 0.9),
				Vector3.ZERO, Vector3(1, 0.5, 1.2)))
	_add(bp, "Body", _p(MeshUtil.torus(0.13, 0.165), Vector3(0, 0.40, -0.16), Color("#6b3f22"), Vector3(70, 0, 0)))
	# Signet plaque (signature, always visible; no crown motif on Mopsula, 03_ART A15)
	_add(bp, "Body", _p(MeshUtil.box(Vector3(0.08, 0.08, 0.015)), Vector3(0, 0.30, -0.26), Palette.HYPE_GOLD,
		Vector3(-15, 0, 0), Vector3.ONE, 0.25, 1.0))
	_add(bp, "Body", _p(MeshUtil.torus(0.02, 0.03), Vector3(0, 0.35, -0.25), Palette.HYPE_GOLD, Vector3(90, 0, 0),
		Vector3.ONE, 0.0, 1.0))
	# Head
	_add(bp, "Head", _p(MeshUtil.sphere(0.19), Vector3.ZERO, prim, Vector3.ZERO, Vector3(1.05, 0.95, 0.95)))
	_add(bp, "Head", _p(MeshUtil.sphere(0.10), Vector3(0, -0.04, -0.15), sec, Vector3.ZERO, Vector3(1.25, 0.8, 0.6)))
	_add(bp, "Head", _p(MeshUtil.sphere(0.03), Vector3(0, 0.0, -0.21), Color("#111111")))
	_add(bp, "Head", _p(MeshUtil.sphere(0.028), Vector3(0, -0.105, -0.185), Color("#e86a7a"), Vector3.ZERO,
		Vector3(1, 0.45, 1)))
	for sx: float in [-1.0, 1.0]:
		_add(bp, "Head", _p(MeshUtil.sphere(0.05), Vector3(0.08 * sx, 0.05, -0.15), eyes))
		_add(bp, "Head", _p(MeshUtil.sphere(0.07), Vector3(0.16 * sx, 0.08, -0.02), sec, Vector3(0, 0, 35 * sx),
			Vector3(1, 0.35, 0.8)))
	_add(bp, "Head", _p(MeshUtil.sphere(0.015), Vector3(-0.065, 0.07, -0.195), Color.WHITE, Vector3.ZERO, Vector3.ONE, 1.0))
	_add(bp, "Head", _p(MeshUtil.sphere(0.015), Vector3(0.095, 0.07, -0.195), Color.WHITE, Vector3.ZERO, Vector3.ONE, 1.0))
	_add(bp, "Head", _p(MeshUtil.capsule(0.012, 0.12), Vector3(0, 0.13, -0.13), Palette.mul(prim, 0.85), Vector3(0, 0, 90)))
	_add(bp, "Head", _p(MeshUtil.capsule(0.012, 0.12), Vector3(0, 0.10, -0.15), Palette.mul(prim, 0.85), Vector3(0, 0, 90)))
	_common_anchor_set(bp, "Head", Vector3.ZERO, "Body", Vector3(0, 0.27, 0), Vector3(0, 0.41, 0.12))
	_anchor(bp, "hand_r", "Head", Vector3(0, -0.06, -0.20))
	_anchor(bp, "hand_l", "Body", Vector3(-0.17, 0.27, -0.05))
	_socket(bp, "head", "Head", Vector3.ZERO, 0.19)
	_socket(bp, "eyes", "Head", Vector3(0, 0.05, -0.19), 0.08)
	_socket(bp, "back", "Body", Vector3(0, 0.44, 0.02), 0.17, Vector3(-90, 0, 0))
	_socket(bp, "chest", "Body", Vector3(0, 0.30, -0.20), 0.17)
	_socket(bp, "belly", "Body", Vector3(0, 0.20, -0.17), 0.17)
	_socket(bp, "hip_r", "Body", Vector3(0.17, 0.27, 0.08), 0.17)
	_socket(bp, "body", "Body", Vector3(0, 0.27, 0.02), 0.17)
	_socket(bp, "hand_r", "Head", Vector3(0, -0.08, -0.20), 0.4, Vector3(0, 0, -90))
	_socket(bp, "hand_l", "Body", Vector3(-0.18, 0.25, -0.05), 0.4)


# --- rodent ---------------------------------------------------------------------------------------------------------

static func _rodent_quadruped(bp: Dictionary) -> void:
	var prim: Color = _col(bp, "primary")
	var sec: Color = _col(bp, "secondary")
	var eyes: Color = _col(bp, "eyes")
	var f: float = RQ
	var queen: bool = _has(bp, "ticket_crown")
	_pivot(bp, "Body", "", Vector3(0, 0.22, 0) * f)
	_pivot(bp, "Head", "Body", Vector3(0, 0.26, -0.30) * f)
	if queen:
		# GDD §5.3 proportions: lying capsule 3.5 m, head Ø 1.2 m at scale 4 (03_ART §5.3)
		bp["pivot_scale"]["Head"] = Vector3(0.86, 0.86, 0.86)
		_add(bp, "Body", _p(MeshUtil.capsule(0.16 * f, 0.60 * f), Vector3.ZERO, prim, Vector3(90, 0, 0),
			Vector3(1, 1.17, 1)))
	else:
		_add(bp, "Body", _p(MeshUtil.capsule(0.16 * f, 0.60 * f), Vector3.ZERO, prim, Vector3(90, 0, 0)))
	_add(bp, "Body", _p(MeshUtil.sphere(0.13 * f), Vector3(0, -0.05, -0.05) * f, Palette.mul(prim, 1.25), Vector3.ZERO,
		Vector3(1, 0.7, 1.6)))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_add(bp, "Body", _p(MeshUtil.sphere(0.047), Vector3(0.10 * sx, -0.17, 0.18 * sz) * f, sec, Vector3.ZERO,
				Vector3(1.2, 0.85, 1.6)))
	# Head
	_add(bp, "Head", _p(MeshUtil.sphere(0.14 * f), Vector3.ZERO, prim))
	_add(bp, "Head", _p(MeshUtil.cone(0.07 * f, 0.16 * f), Vector3(0, -0.03, -0.15) * f, prim, Vector3(-90, 0, 0)))
	_add(bp, "Head", _p(MeshUtil.sphere(0.025 * f), Vector3(0, -0.03, -0.24) * f, sec))
	if not _has(bp, "helmet"):
		for sx: float in [-1.0, 1.0]:
			_add(bp, "Head", _p(MeshUtil.sphere(0.065 * f), Vector3(0.09 * sx, 0.11, 0.02) * f, sec, Vector3(0, 0, 15 * sx),
				Vector3(1, 1, 0.35)))
	for sx: float in [-1.0, 1.0]:
		_add(bp, "Head", _p(MeshUtil.sphere(0.03 * f), Vector3(0.06 * sx, 0.04, -0.11) * f, eyes, Vector3.ZERO,
			Vector3.ONE, 1.0))
	_add(bp, "Head", _p(MeshUtil.box(Vector3(0.04, 0.03, 0.01) * f), Vector3(0, -0.07, -0.20) * f, TOOTH))
	# Tail
	if not _has(bp, "rat_king_tail"):
		_pivot(bp, "Tail", "Body", Vector3(0, 0.20, 0.30) * f)
		_tail_chain(bp, "Tail", 3, 0.03 * f, 0.015 * f, 0.20 * f, 20.0, sec)
		_mesh(bp, "Tail", "Tail")["mat"] = {"bands": 3, "rim": 0.45, "wobble": 0.02}
	else:
		_pivot(bp, "Tail", "Body", Vector3(0, 0.20, 0.30) * f)
	if queen:
		bp["mat"] = {"bands": 3, "rim": 0.8, "rim_color": Color("#9a6bff")}
	_common_anchor_set(bp, "Head", Vector3.ZERO, "Body", Vector3.ZERO, Vector3(0, 0.40, 0) * f)
	_anchor(bp, "hand_r", "Head", Vector3(0, -0.07, -0.22) * f)
	_anchor(bp, "hand_l", "Body", Vector3(-0.16, 0.0, -0.1) * f)
	_socket(bp, "head", "Head", Vector3.ZERO, 0.14 * f)
	_socket(bp, "eyes", "Head", Vector3(0, 0.04, -0.13) * f, 0.06 * f)
	_socket(bp, "back", "Body", Vector3(0, 0.15, 0.02) * f, 0.16 * f, Vector3(-90, 0, 0))
	_socket(bp, "chest", "Body", Vector3(0, 0.02, -0.30) * f, 0.16 * f)
	_socket(bp, "belly", "Body", Vector3(0, -0.06, -0.20) * f, 0.16 * f)
	_socket(bp, "hip_r", "Body", Vector3(0.15, 0.0, 0.12) * f, 0.16 * f)
	_socket(bp, "body", "Body", Vector3.ZERO, 0.16 * f)
	# held items stand upright beside the front paws (scepter of the queen)
	_socket(bp, "hand_r", "Body", Vector3(0.19, -0.10, -0.22) * f, 0.30, Vector3(0, 0, -8))
	_socket(bp, "hand_l", "Body", Vector3(-0.19, -0.10, -0.22) * f, 0.30, Vector3(0, 0, 8))
	_socket(bp, "tail", "Tail", Vector3.ZERO, 0.16 * f)


## Chain of n cylinders from the pivot origin toward +Z, each bending `bend` degrees around X (tail, 03_ART §5.3).
static func _tail_chain(bp: Dictionary, pivot: String, n: int, r0: float, r1: float, seg_len: float, bend: float,
		color: Color, mesh_name: String = "", yaw_deg: float = 0.0, start: Vector3 = Vector3.ZERO) -> Vector3:
	var p: Vector3 = start
	var dir := Vector3(0, 0, 1)
	var yaw := Basis(Vector3.UP, deg_to_rad(yaw_deg))
	for i in n:
		var t0: float = float(i) / float(n)
		var t1: float = float(i + 1) / float(n)
		var ang: float = deg_to_rad(bend * float(i + 1))
		dir = yaw * Vector3(0, sin(ang), cos(ang))
		var q: Vector3 = p + dir * seg_len
		_add(bp, pivot, _seg(p, q, lerpf(r0, r1, t0), lerpf(r0, r1, t1), color), mesh_name)
		p = q
	return p


static func _rodent_upright(bp: Dictionary) -> void:
	var prim: Color = _col(bp, "primary")
	var sec: Color = _col(bp, "secondary")
	var eyes: Color = _col(bp, "eyes")
	_pivot(bp, "Torso", "", Vector3(0, 0.23, 0))
	_pivot(bp, "Head", "Torso", Vector3(0, 0.61, -0.03))
	_pivot(bp, "ArmL", "Torso", Vector3(-0.15, 0.42, 0))
	_pivot(bp, "ArmR", "Torso", Vector3(0.15, 0.42, 0))
	_add(bp, "Torso", _p(MeshUtil.capsule(0.14, 0.47), Vector3(0, 0.16, 0), prim))
	if not _has(bp, "cape"):
		_add(bp, "Torso", _p(MeshUtil.sphere(0.11), Vector3(0, 0.12, -0.06), Palette.mul(prim, 1.25), Vector3.ZERO,
			Vector3(1, 1.3, 0.7)))
	for sx: float in [-1.0, 1.0]:
		_add(bp, "Torso", _p(MeshUtil.capsule(0.05, 0.16), Vector3(0.08 * sx, -0.16, 0), prim))
		_add(bp, "Torso", _p(MeshUtil.box(Vector3(0.07, 0.03, 0.12)), Vector3(0.08 * sx, -0.22, -0.03), sec))
	_add(bp, "Head", _p(MeshUtil.sphere(0.12), Vector3.ZERO, prim))
	_add(bp, "Head", _p(MeshUtil.cone(0.055, 0.13), Vector3(0, -0.02, -0.12), prim, Vector3(-90, 0, 0)))
	_add(bp, "Head", _p(MeshUtil.sphere(0.02), Vector3(0, -0.02, -0.19), sec))
	if not _has(bp, "helmet"):
		for sx: float in [-1.0, 1.0]:
			_add(bp, "Head", _p(MeshUtil.sphere(0.055), Vector3(0.07 * sx, 0.09, 0.02), sec, Vector3(0, 0, 15 * sx),
				Vector3(1, 1, 0.35)))
	for sx: float in [-1.0, 1.0]:
		_add(bp, "Head", _p(MeshUtil.sphere(0.024), Vector3(0.05 * sx, 0.03, -0.095), eyes, Vector3.ZERO, Vector3.ONE, 1.0))
	_add(bp, "Head", _p(MeshUtil.box(Vector3(0.035, 0.025, 0.01)), Vector3(0, -0.06, -0.165), TOOTH))
	for arm: String in ["ArmL", "ArmR"]:
		_add(bp, arm, _p(MeshUtil.capsule(0.035, 0.25), Vector3(0, -0.10, 0), prim))
		_add(bp, arm, _p(MeshUtil.sphere(0.04), Vector3(0, -0.22, 0), sec))
	_pivot(bp, "Tail", "Torso", Vector3(0, 0.10, 0.12))
	if not _has(bp, "rat_king_tail"):
		_tail_chain(bp, "Tail", 3, 0.025, 0.012, 0.16, 25.0, sec)
		_mesh(bp, "Tail", "Tail")["mat"] = {"bands": 3, "rim": 0.45, "wobble": 0.02}
	_common_anchor_set(bp, "Head", Vector3.ZERO, "Torso", Vector3(0, 0.16, 0), Vector3(0, 0.40, 0))
	_anchor(bp, "hand_r", "ArmR", Vector3(0, -0.22, 0))
	_anchor(bp, "hand_l", "ArmL", Vector3(0, -0.22, 0))
	_socket(bp, "head", "Head", Vector3.ZERO, 0.12)
	_socket(bp, "eyes", "Head", Vector3(0, 0.03, -0.11), 0.05)
	_socket(bp, "back", "Torso", Vector3(0, 0.20, 0.14), 0.14)
	_socket(bp, "chest", "Torso", Vector3(0, 0.17, -0.13), 0.14)
	_socket(bp, "belly", "Torso", Vector3(0, 0.05, -0.14), 0.14)
	_socket(bp, "hip_r", "Torso", Vector3(0.14, 0.0, 0.0), 0.14)
	_socket(bp, "body", "Torso", Vector3(0, 0.16, 0), 0.14)
	_socket(bp, "hand_r", "ArmR", Vector3(0, -0.22, 0), 0.55)
	_socket(bp, "hand_l", "ArmL", Vector3(0, -0.22, 0), 0.55)
	_socket(bp, "tail", "Tail", Vector3.ZERO, 0.14)


# --- blob (Kanalschleim, Kabelsalat) ---------------------------------------------------------------------------------

static func _blob(bp: Dictionary) -> void:
	var prim: Color = _col(bp, "primary")
	var sec: Color = _col(bp, "secondary")
	var eyes: Color = _col(bp, "eyes")
	var cables: bool = _has(bp, "cable_tangle")
	_pivot(bp, "Body", "", Vector3.ZERO)
	_add(bp, "Body", _p(MeshUtil.sphere(0.45), Vector3(0, 0.36, 0), prim, Vector3.ZERO, Vector3(1, 0.8, 1)))
	if not cables:
		_add(bp, "Body", _p(MeshUtil.sphere(0.45), Vector3(0, 0.04, 0), Palette.mul(prim, 0.85), Vector3.ZERO,
			Vector3(1.18, 0.12, 1.18)))
	for sx: float in [-1.0, 1.0]:
		_add(bp, "Body", _p(MeshUtil.sphere(0.059), Vector3(0.12 * sx, 0.50, -0.33), Palette.PAPER, Vector3.ZERO,
			Vector3(1.1, 1.15, 1.0)))
		_add(bp, "Body", _p(MeshUtil.sphere(0.032), Vector3(0.12 * sx, 0.50, -0.385), eyes))
		_add(bp, "Body", _p(MeshUtil.sphere(0.012), Vector3(0.12 * sx - 0.012, 0.515, -0.415), Color.WHITE, Vector3.ZERO,
			Vector3.ONE, 1.0))
	if not cables:
		_add(bp, "Body", _p(MeshUtil.box(Vector3(0.14, 0.03, 0.01)), Vector3(0, 0.36, -0.42), Palette.mul(prim, 0.45),
			Vector3(-25, 0, 0)))
		_add(bp, "Body", _p(MeshUtil.cylinder(0.06, 0.06, 0.18), Vector3(0.22, 0.60, 0), Color("#c0c0c0"),
			Vector3(0, 0, 60), Vector3.ONE, 0.0, 1.0))
		_add(bp, "Body", _p(MeshUtil.cylinder(0.062, 0.062, 0.05), Vector3(0.235, 0.61, 0), sec, Vector3(0, 0, 60)))
		_add(bp, "Body", _p(MeshUtil.box(Vector3(0.12, 0.08, 0.10)), Vector3(-0.25, 0.55, 0.12), sec, Vector3(10, 20, 15)))
		bp["mat"] = {"bands": 3, "rim": 1.0, "spec": 0.5, "wobble": 0.03, "rim_color": Palette.mul(prim, 1.4)}
	_common_anchor_set(bp, "Body", Vector3(0, 0.50, 0), "Body", Vector3(0, 0.36, 0), Vector3(0, 0.98, 0))
	_anchor(bp, "hand_r", "Body", Vector3(0.40, 0.30, -0.12))
	_anchor(bp, "hand_l", "Body", Vector3(-0.40, 0.30, -0.12))
	_socket(bp, "head", "Body", Vector3(0, 0.30, 0), 0.42)
	_socket(bp, "eyes", "Body", Vector3(0, 0.50, -0.40), 0.12)
	_socket(bp, "back", "Body", Vector3(0, 0.40, 0.40), 0.40)
	_socket(bp, "chest", "Body", Vector3(0, 0.36, -0.42), 0.40)
	_socket(bp, "belly", "Body", Vector3(0, 0.22, -0.42), 0.40)
	_socket(bp, "hip_r", "Body", Vector3(0.40, 0.22, 0.0), 0.40)
	_socket(bp, "body", "Body", Vector3(0, 0.36, 0), 0.45)
	_socket(bp, "hand_r", "Body", Vector3(0.42, 0.30, -0.10), 0.5, Vector3(0, 0, -30))
	_socket(bp, "hand_l", "Body", Vector3(-0.42, 0.30, -0.10), 0.5, Vector3(0, 0, 30))


# --- insect (Kellerspinne, Rolltreppenkrabbe) ------------------------------------------------------------------------

static func _insect(bp: Dictionary) -> void:
	var prim: Color = _col(bp, "primary")
	var sec: Color = _col(bp, "secondary")
	var acc: Color = _col(bp, "accent")
	var eyes: Color = _col(bp, "eyes")
	var winged: bool = _has(bp, "wings")
	var clawed: bool = _has(bp, "claws")
	var body_y: float = 0.85 if winged else 0.45
	_pivot(bp, "Body", "", Vector3(0, body_y, 0))
	_pivot(bp, "LegsA", "Body", Vector3(0, body_y, 0))
	_pivot(bp, "LegsB", "Body", Vector3(0, body_y, 0))
	_add(bp, "Body", _p(MeshUtil.sphere(0.40), Vector3(0, 0.10, 0.35), prim))
	if not _has(bp, "escalator_back"):
		var discs: Array[Vector3] = [Vector3(0, 0.48, 0.35), Vector3(0, 0.40, 0.50), Vector3(0, 0.30, 0.62)]
		for d: Vector3 in discs:
			_add(bp, "Body", _p(MeshUtil.cylinder(0.08, 0.08, 0.02), d, sec, Vector3(-30, 0, 0)))
	_add(bp, "Body", _p(MeshUtil.sphere(0.22), Vector3(0, 0, -0.15), prim))
	var eye_pos: Array[Vector3] = [Vector3(0.06, 0.08, -0.34), Vector3(0.12, 0.05, -0.30), Vector3(0.04, 0.13, -0.32)]
	if clawed:
		eye_pos = [Vector3(0.08, 0.10, -0.33)]
	for e: Vector3 in eye_pos:
		for sx: float in [-1.0, 1.0]:
			var r: float = 0.045 if e.y > 0.07 and absf(e.x) < 0.07 else 0.035
			_add(bp, "Body", _p(MeshUtil.sphere(r), Vector3(e.x * sx, e.y, e.z), eyes, Vector3.ZERO, Vector3.ONE, 0.5))
	for sx: float in [-1.0, 1.0]:
		_add(bp, "Body", _p(MeshUtil.cone(0.03, 0.10), Vector3(0.05 * sx, -0.10, -0.33), acc, Vector3(-150, 0, 0)))
	# Legs: two meshes (alternating tetrapods); 4 per side, 3 with claws or wings.
	var per_side: int = 3 if (clawed or winged) else 4
	var ground: float = -0.35 if winged else -body_y
	var up_len: float = 0.32 if clawed else 0.45
	var up_ang: float = deg_to_rad(28.0 if clawed else 40.0)
	var r_leg: float = 0.05 if clawed else 0.035
	for i in per_side:
		var z: float = -0.15 + 0.12 * float(i) + (0.06 if per_side == 3 else 0.0)
		if clawed:
			z = 0.0 + 0.2 * float(i)
		for sx: float in [-1.0, 1.0]:
			var group: String = "LegsA" if ((i % 2 == 0) == (sx < 0.0)) else "LegsB"
			var root := Vector3(0.18 * sx, 0.0, z)
			var knee: Vector3 = root + Vector3(cos(up_ang) * sx, sin(up_ang), 0) * up_len
			var splay: float = (z - 0.08) * 1.4
			var foot := Vector3(sx * (0.18 + up_len * cos(up_ang) + (0.14 if clawed else 0.28)), ground, z + splay)
			_add(bp, group, _seg(root, knee, r_leg, r_leg * 0.85, prim))
			_add(bp, group, _seg(knee, foot, r_leg * 0.85, r_leg * 0.5, prim))
			_add(bp, group, _p(MeshUtil.sphere(r_leg * 1.1), knee, Palette.mul(prim, 1.3)))
	_common_anchor_set(bp, "Body", Vector3(0, 0, -0.15), "Body", Vector3(0, 0.05, 0.1), Vector3(0, 0.75, 0.1))
	_anchor(bp, "hand_r", "Body", Vector3(0.12, -0.12, -0.36))
	_anchor(bp, "hand_l", "Body", Vector3(-0.12, -0.12, -0.36))
	_socket(bp, "head", "Body", Vector3(0, 0.0, -0.15), 0.22)
	_socket(bp, "eyes", "Body", Vector3(0, 0.08, -0.36), 0.06)
	_socket(bp, "back", "Body", Vector3(0, 0.48, 0.35), 0.40, Vector3(-90, 0, 0))
	_socket(bp, "chest", "Body", Vector3(0, -0.06, -0.35), 0.22)
	_socket(bp, "belly", "Body", Vector3(0, -0.20, 0.30), 0.30)
	_socket(bp, "hip_r", "Body", Vector3(0.38, 0.05, 0.35), 0.30)
	_socket(bp, "body", "Body", Vector3(0, 0.10, 0.35), 0.40)
	_socket(bp, "hand_r", "Body", Vector3(0.15, -0.12, -0.36), 0.5)
	_socket(bp, "hand_l", "Body", Vector3(-0.15, -0.12, -0.36), 0.5)


# --- robot (Fahrscheinfresser) ---------------------------------------------------------------------------------------

static func _robot(bp: Dictionary) -> void:
	var prim: Color = _col(bp, "primary")
	var sec: Color = _col(bp, "secondary")
	var acc: Color = _col(bp, "accent")
	var eyes: Color = _col(bp, "eyes")
	var cart: bool = _has(bp, "cart")
	_pivot(bp, "Body", "", Vector3.ZERO)
	if cart:
		_pivot(bp, "JawLower", "Body", Vector3(0, 0.80, -0.40))
		_cart_parts(bp)
	else:
		_pivot(bp, "JawLower", "Body", Vector3(0, 0.625, -0.25))
		_add(bp, "Body", _p(MeshUtil.box(Vector3(0.75, 1.50, 0.50)), Vector3(0, 0.75, 0), prim))
		_add(bp, "Body", _p(MeshUtil.box(Vector3(0.80, 0.07, 0.55)), Vector3(0, 1.535, 0), sec))
		_add(bp, "Body", _p(MeshUtil.box(Vector3(0.66, 0.16, 0.04)), Vector3(0, 1.40, -0.255), sec))
		for sx: float in [-1.0, 1.0]:
			_add(bp, "Body", _p(MeshUtil.box(Vector3(0.21, 0.05, 0.42)), Vector3(0.25 * sx, 0.025, 0), Color("#1e1e1e")))
			_add(bp, "Body", _p(MeshUtil.box(Vector3(0.07, 0.09, 0.012)), Vector3(0.10 * sx, 1.135, -0.274), DARK))
		_add(bp, "Body", _p(MeshUtil.box(Vector3(0.25, 0.025, 0.02)), Vector3(0, 0.875, -0.26), DARK))
		for row in 3:
			for col in 2:
				_add(bp, "Body", _p(MeshUtil.box(Vector3(0.05, 0.05, 0.02)),
					Vector3(0.19 + 0.07 * float(col), 0.98 - 0.07 * float(row), -0.26), eyes, Vector3.ZERO, Vector3.ONE, 0.3))
		_add(bp, "Body", _p(MeshUtil.box(Vector3(0.67, 0.06, 0.12)), Vector3(0, 0.71, -0.30), Palette.mul(prim, 0.8)))
		for k in 6:
			_add(bp, "Body", _p(MeshUtil.cone(0.035, 0.085), Vector3(-0.25 + 0.1 * float(k), 0.64, -0.33), TOOTH,
				Vector3(180, 0, 0)))
		# Display: own mesh (flicker via flash_amount, 03_ART §5.3)
		_add(bp, "Body", _p(MeshUtil.box(Vector3(0.42, 0.25, 0.02)), Vector3(0, 1.125, -0.26), acc, Vector3.ZERO,
			Vector3.ONE, 1.0), "Display")
		_mesh(bp, "Display", "Body")["pulse"] = {"mode": "flicker", "color": Palette.PAPER}
		_mesh(bp, "Display", "Body")["role"] = "display"
		_add(bp, "JawLower", _p(MeshUtil.box(Vector3(0.67, 0.10, 0.21)), Vector3(0, -0.05, -0.10), prim))
		for k in 6:
			_add(bp, "JawLower", _p(MeshUtil.cone(0.035, 0.085), Vector3(-0.25 + 0.1 * float(k), 0.03, -0.18), TOOTH))
	_common_anchor_set(bp, "Body", Vector3(0, 1.20, 0), "Body", Vector3(0, 0.80, 0), Vector3(0, 1.85, 0))
	_anchor(bp, "hand_r", "Body", Vector3(0.40, 0.70, -0.1))
	_anchor(bp, "hand_l", "Body", Vector3(-0.40, 0.70, -0.1))
	_socket(bp, "head", "Body", Vector3(0, 1.30, 0), 0.27)
	_socket(bp, "eyes", "Body", Vector3(0, 1.14, -0.28), 0.10)
	_socket(bp, "back", "Body", Vector3(0, 0.90, 0.25), 0.37)
	_socket(bp, "chest", "Body", Vector3(0, 0.95, -0.26), 0.37)
	_socket(bp, "belly", "Body", Vector3(0, 0.45, -0.26), 0.37)
	_socket(bp, "hip_r", "Body", Vector3(0.38, 0.60, 0), 0.37)
	_socket(bp, "body", "Body", Vector3(0, 0.75, 0), 0.37)
	_socket(bp, "hand_r", "Body", Vector3(0.42, 0.70, -0.1), 0.8)
	_socket(bp, "hand_l", "Body", Vector3(-0.42, 0.70, -0.1), 0.8)


## cart (03_ART §5.4): wire basket replaces the machine case; JawLower = basket flap.
static func _cart_parts(bp: Dictionary) -> void:
	var wire := Color("#c0c6cc")
	var c := Vector3(0, 0.55, 0)
	var hx: float = 0.30
	var hy: float = 0.25
	var hz: float = 0.40
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_add(bp, "Body", _seg(c + Vector3(hx * sx, -hy, hz * sz), c + Vector3(hx * sx, hy, hz * sz), 0.012, 0.012,
				wire, 0.0, 1.0))
			_add(bp, "Body", _seg(c + Vector3(hx * sx * 0.8, -hy, hz * sz * 0.8), Vector3(0.25 * sx, 0.10, 0.35 * sz),
				0.012, 0.012, wire, 0.0, 1.0))
			_add(bp, "Body", _p(MeshUtil.cylinder(0.06, 0.06, 0.04), Vector3(0.25 * sx, 0.06, 0.35 * sz), Color("#1e1e1e"),
				Vector3(0, 0, 90)))
	for y: float in [-hy, 0.0, hy]:
		for sz: float in [-1.0, 1.0]:
			_add(bp, "Body", _seg(c + Vector3(-hx, y, hz * sz), c + Vector3(hx, y, hz * sz), 0.01, 0.01, wire, 0.0, 1.0))
		if y != 0.0:
			for sx: float in [-1.0, 1.0]:
				_add(bp, "Body", _seg(c + Vector3(hx * sx, y, -hz), c + Vector3(hx * sx, y, hz), 0.01, 0.01, wire, 0.0, 1.0))
	_add(bp, "Body", _p(MeshUtil.box(Vector3(0.58, 0.02, 0.78)), c + Vector3(0, -hy + 0.01, 0), Palette.mul(wire, 0.6)))
	_add(bp, "Body", _p(MeshUtil.cylinder(0.025, 0.025, 0.66), Vector3(0, 1.0, 0.46), Color("#e8455a"), Vector3(0, 0, 90)))
	for sx: float in [-1.0, 1.0]:
		_add(bp, "Body", _seg(c + Vector3(hx * sx, hy, hz), Vector3(0.30 * sx, 1.0, 0.46), 0.012, 0.012, wire, 0.0, 1.0))
		_add(bp, "Body", _p(MeshUtil.sphere(0.05), Vector3(0.15 * sx, 0.60, -0.42), Color("#fff2c8"), Vector3.ZERO,
			Vector3.ONE, 1.0))
	_add(bp, "JawLower", _p(MeshUtil.box(Vector3(0.58, 0.46, 0.015)), Vector3(0, -0.23, 0), Palette.mul(wire, 0.75),
		Vector3.ZERO, Vector3.ONE, 0.0, 1.0))
	_add(bp, "JawLower", _p(MeshUtil.box(Vector3(0.20, 0.05, 0.03)), Vector3(0, -0.40, -0.01), Color("#e8455a")))


# --- brute (Der Hausmeister) ------------------------------------------------------------------------------------------

static func _brute(bp: Dictionary) -> void:
	var prim: Color = _col(bp, "primary")
	var sec: Color = _col(bp, "secondary")
	var acc: Color = _col(bp, "accent")
	var skin: Color = _col(bp, "skin")
	var eyes: Color = _col(bp, "eyes")
	if bool(bp["flags"].get("compact", false)):
		_brute_compact(bp, prim, sec, acc, skin, eyes)
		return
	# 03_ART §5.3 brute; torso shortened so the head clears the coat (head top 2.24 m at scale 1)
	_pivot(bp, "Torso", "", Vector3(0, 0.88, 0))
	_pivot(bp, "Head", "Torso", Vector3(0, 1.94, -0.04))
	_pivot(bp, "ArmL", "Torso", Vector3(-0.56, 1.46, 0))
	_pivot(bp, "ArmR", "Torso", Vector3(0.56, 1.46, 0))
	_pivot(bp, "LegL", "", Vector3(-0.21, 0.51, 0))
	_pivot(bp, "LegR", "", Vector3(0.21, 0.51, 0))
	_add(bp, "Torso", _p(MeshUtil.capsule(0.42, 1.12), Vector3(0, 0.27, 0), prim))
	_add(bp, "Torso", _p(MeshUtil.cylinder(0.45, 0.47, 0.20), Vector3(0, -0.22, 0), Palette.mul(prim, 0.85)))
	for k in 4:
		_add(bp, "Torso", _p(MeshUtil.sphere(0.03), Vector3(0, -0.13 + 0.16 * float(k), -0.425), Color("#d8dde2"),
			Vector3.ZERO, Vector3.ONE, 0.0, 1.0))
	_add(bp, "Torso", _p(MeshUtil.box(Vector3(0.22, 0.18, 0.03)), Vector3(0.17, 0.46, -0.40), Palette.mul(prim, 0.85),
		Vector3(-10, 0, 0)))
	var pens: Array[Color] = [Color("#2a5db0"), Color("#c23b22"), Color("#1e1e1e")]
	for i in 3:
		_add(bp, "Torso", _p(MeshUtil.cylinder(0.015, 0.015, 0.15), Vector3(0.12 + 0.05 * float(i), 0.57, -0.39), pens[i],
			Vector3(-10, 0, 0)))
	_add(bp, "Torso", _p(MeshUtil.torus(0.17, 0.27), Vector3(0, 0.76, -0.02), Palette.mul(prim, 0.85), Vector3(-8, 0, 0)))
	_add(bp, "Head", _p(MeshUtil.cylinder(0.15, 0.17, 0.2), Vector3(0, -0.28, 0.02), Palette.mul(skin, 0.9)))
	_add(bp, "Head", _p(MeshUtil.sphere(0.30), Vector3.ZERO, skin))
	_add(bp, "Head", _p(MeshUtil.sphere(0.07), Vector3(0, -0.01, -0.29), Palette.mul(skin, 0.88)))
	_add(bp, "Head", _p(MeshUtil.capsule(0.045, 0.34), Vector3(0, -0.085, -0.265), acc, Vector3(0, 0, 90)))
	for sx: float in [-1.0, 1.0]:
		_add(bp, "Head", _p(MeshUtil.box(Vector3(0.13, 0.045, 0.05)), Vector3(0.105 * sx, 0.14, -0.255), acc,
			Vector3(0, 0, -14 * sx)))
		_add(bp, "Head", _p(MeshUtil.sphere(0.07), Vector3(0.30 * sx, 0.0, 0.0), skin, Vector3.ZERO, Vector3(0.6, 1, 1)))
		_add(bp, "Head", _p(MeshUtil.sphere(0.045), Vector3(0.10 * sx, 0.06, -0.255), eyes, Vector3.ZERO,
			Vector3(1, 1.2, 0.6)), "Eyes")
		_add(bp, "Head", _p(MeshUtil.capsule(0.05, 0.16), Vector3(0.20 * sx, -0.09, -0.22), acc, Vector3(0, 0, 60 * sx)))
	_mesh(bp, "Eyes", "Head")["pulse"] = {"mode": "phase", "color": Color("#ff3b30"), "phase": 3}
	_mesh(bp, "Eyes", "Head")["role"] = "eyes"
	for arm: String in ["ArmL", "ArmR"]:
		_add(bp, arm, _p(MeshUtil.capsule(0.12, 0.88), Vector3(0, -0.40, 0), prim))
		_add(bp, arm, _p(MeshUtil.cylinder(0.135, 0.135, 0.10), Vector3(0, -0.72, 0), Palette.mul(prim, 0.85)))
		_add(bp, arm, _p(MeshUtil.sphere(0.13), Vector3(0, -0.84, 0), skin))
	for leg: String in ["LegL", "LegR"]:
		_add(bp, leg, _p(MeshUtil.capsule(0.15, 0.59), Vector3(0, -0.22, 0), sec))
		_add(bp, leg, _p(MeshUtil.box(Vector3(0.26, 0.13, 0.37)), Vector3(0, -0.48, -0.06), Color("#1e1e1e")))
	_brute_sockets(bp)


## Shared brute anchors + sockets (full and compact recipe).
static func _brute_sockets(bp: Dictionary) -> void:
	_common_anchor_set(bp, "Head", Vector3.ZERO, "Torso", Vector3(0, 0.30, 0), Vector3(0, 0.62, 0))
	_anchor(bp, "hand_r", "ArmR", Vector3(0, -0.84, 0))
	_anchor(bp, "hand_l", "ArmL", Vector3(0, -0.84, 0))
	_socket(bp, "head", "Head", Vector3.ZERO, 0.30)
	_socket(bp, "eyes", "Head", Vector3(0, 0.06, -0.28), 0.10)
	_socket(bp, "back", "Torso", Vector3(0, 0.45, 0.42), 0.42)
	_socket(bp, "chest", "Torso", Vector3(0, 0.45, -0.42), 0.42)
	_socket(bp, "belly", "Torso", Vector3(0, 0.05, -0.43), 0.42)
	_socket(bp, "hip_r", "Torso", Vector3(0.38, -0.14, -0.12), 0.42)
	_socket(bp, "body", "Torso", Vector3(0, 0.27, 0), 0.42)
	_socket(bp, "hand_r", "ArmR", Vector3(0, -0.84, 0), 1.25)
	_socket(bp, "hand_l", "ArmL", Vector3(0, -0.84, 0), 1.25)


## Compact brute (scale < 1.0 = regular enemy size, e.g. 03_ART §5.7 Rabattschild): same silhouette and pivots as the
## Hausmeister recipe, without the coat details, eyes merged into the head (no boss-phase glow), lower segment counts —
## fits the enemy budget (02_TECH §12.1: ≤ 1 500 tris / 6 meshes).
static func _brute_compact(bp: Dictionary, prim: Color, sec: Color, acc: Color, skin: Color, eyes: Color) -> void:
	_pivot(bp, "Torso", "", Vector3(0, 0.88, 0))
	_pivot(bp, "Head", "Torso", Vector3(0, 1.94, -0.04))
	_pivot(bp, "ArmL", "Torso", Vector3(-0.56, 1.46, 0))
	_pivot(bp, "ArmR", "Torso", Vector3(0.56, 1.46, 0))
	_pivot(bp, "LegL", "", Vector3(-0.21, 0.51, 0))
	_pivot(bp, "LegR", "", Vector3(0.21, 0.51, 0))
	_add(bp, "Torso", _p(_capsule_lo(0.42, 1.12, 10, 1), Vector3(0, 0.27, 0), prim))
	_add(bp, "Torso", _p(MeshUtil.cylinder(0.45, 0.47, 0.20), Vector3(0, -0.22, 0), Palette.mul(prim, 0.85)))
	_add(bp, "Torso", _p(MeshUtil.box(Vector3(0.22, 0.18, 0.03)), Vector3(0.17, 0.46, -0.40), Palette.mul(prim, 0.85),
		Vector3(-10, 0, 0)))
	_add(bp, "Torso", _p(MeshUtil.cylinder(0.24, 0.30, 0.10), Vector3(0, 0.80, -0.02), Palette.mul(prim, 0.85)))
	_add(bp, "Head", _p(MeshUtil.cylinder(0.15, 0.17, 0.2), Vector3(0, -0.28, 0.02), Palette.mul(skin, 0.9)))
	_add(bp, "Head", _p(MeshUtil.sphere(0.30), Vector3.ZERO, skin))
	_add(bp, "Head", _p(MeshUtil.sphere(0.055), Vector3(0, -0.01, -0.29), Palette.mul(skin, 0.88)))
	_add(bp, "Head", _p(MeshUtil.capsule(0.045, 0.34), Vector3(0, -0.085, -0.265), acc, Vector3(0, 0, 90)))
	for sx: float in [-1.0, 1.0]:
		_add(bp, "Head", _p(MeshUtil.box(Vector3(0.13, 0.045, 0.05)), Vector3(0.105 * sx, 0.14, -0.255), acc,
			Vector3(0, 0, -14 * sx)))
		_add(bp, "Head", _p(_sphere_lo(0.07, 8, 4), Vector3(0.30 * sx, 0.0, 0.0), skin, Vector3.ZERO, Vector3(0.6, 1, 1)))
		_add(bp, "Head", _p(MeshUtil.sphere(0.045), Vector3(0.10 * sx, 0.06, -0.255), eyes, Vector3.ZERO,
			Vector3(1, 1.2, 0.6)))
	for arm: String in ["ArmL", "ArmR"]:
		_add(bp, arm, _p(_capsule_lo(0.12, 0.88, 8, 1), Vector3(0, -0.40, 0), prim))
		_add(bp, arm, _p(MeshUtil.cylinder(0.135, 0.135, 0.10), Vector3(0, -0.72, 0), Palette.mul(prim, 0.85)))
		_add(bp, arm, _p(_sphere_lo(0.13, 8, 4), Vector3(0, -0.84, 0), skin))
	for leg: String in ["LegL", "LegR"]:
		_add(bp, leg, _p(_capsule_lo(0.15, 0.59, 8, 1), Vector3(0, -0.22, 0), sec))
		_add(bp, leg, _p(MeshUtil.box(Vector3(0.26, 0.13, 0.37)), Vector3(0, -0.48, -0.06), Color("#1e1e1e")))
	_brute_sockets(bp)


static func _capsule_lo(radius: float, height: float, radial: int, rings: int) -> CapsuleMesh:
	var m := MeshUtil.capsule(radius, height)
	m.radial_segments = radial
	m.rings = rings
	return m


static func _sphere_lo(radius: float, radial: int, rings: int) -> SphereMesh:
	var m := MeshUtil.sphere(radius)
	m.radial_segments = radial
	m.rings = rings
	return m


# --- specter (Sprühgeist) ------------------------------------------------------------------------------------------

static func _specter(bp: Dictionary) -> void:
	var prim: Color = _col(bp, "primary")
	var sec: Color = _col(bp, "secondary")
	var eyes: Color = _col(bp, "eyes")
	_pivot(bp, "Body", "", Vector3(0, 0.90, 0))
	_pivot(bp, "ArmL", "Body", Vector3(-0.32, 1.25, 0))
	_pivot(bp, "ArmR", "Body", Vector3(0.32, 1.25, 0))
	_add(bp, "Body", _p(MeshUtil.cylinder(0.30, 0.10, 1.00), Vector3.ZERO, prim))
	_add(bp, "Body", _p(MeshUtil.cylinder(0.31, 0.31, 0.06), Vector3(0, 0.40, 0), Palette.mul(prim, 0.8), Vector3.ZERO,
		Vector3.ONE, 0.0, 1.0))
	_add(bp, "Body", _p(MeshUtil.sphere(0.30), Vector3(0, 0.65, 0), sec))
	for sx: float in [-1.0, 1.0]:
		_add(bp, "Body", _p(MeshUtil.capsule(0.05, 0.15), Vector3(0.11 * sx, 0.70, -0.27), eyes, Vector3(-15, 0, 0),
			Vector3.ONE, 0.4))
		_add(bp, "Body", _p(MeshUtil.sphere(0.014), Vector3(0.11 * sx - 0.015, 0.73, -0.315), Color.WHITE, Vector3.ZERO,
			Vector3.ONE, 1.0))
		_add(bp, "Body", _p(MeshUtil.box(Vector3(0.10, 0.025, 0.02)), Vector3(0.11 * sx, 0.82, -0.27), DARK,
			Vector3(-15, 0, 20 * sx)))
	_add(bp, "Body", _p(MeshUtil.box(Vector3(0.14, 0.04, 0.02)), Vector3(0, 0.55, -0.285), DARK, Vector3(-30, 0, 0)))
	for arm: String in ["ArmL", "ArmR"]:
		var sx: float = -1.0 if arm == "ArmL" else 1.0
		_add(bp, arm, _p(MeshUtil.capsule(0.06, 0.40), Vector3(0.05 * sx, -0.15, 0), prim, Vector3(0, 0, 20 * sx)))
		_add(bp, arm, _p(MeshUtil.sphere(0.075), Vector3(0.12 * sx, -0.33, 0), sec))
	bp["particles"].append({"kind": "specter_tail", "pivot": "Body", "pos": Vector3(0, -0.45, 0.06)})
	_common_anchor_set(bp, "Body", Vector3(0, 0.65, 0), "Body", Vector3(0, 0.10, 0), Vector3(0, 1.20, 0))
	_anchor(bp, "hand_r", "ArmR", Vector3(0.12, -0.33, 0))
	_anchor(bp, "hand_l", "ArmL", Vector3(-0.12, -0.33, 0))
	_socket(bp, "head", "Body", Vector3(0, 0.65, 0), 0.30)
	_socket(bp, "eyes", "Body", Vector3(0, 0.70, -0.30), 0.11)
	_socket(bp, "back", "Body", Vector3(0, 0.20, 0.25), 0.25)
	_socket(bp, "chest", "Body", Vector3(0, 0.25, -0.26), 0.25)
	_socket(bp, "belly", "Body", Vector3(0, 0.0, -0.22), 0.22)
	_socket(bp, "hip_r", "Body", Vector3(0.24, 0.05, 0), 0.22)
	_socket(bp, "body", "Body", Vector3.ZERO, 0.25)
	_socket(bp, "hand_r", "ArmR", Vector3(0.12, -0.33, 0), 0.6)
	_socket(bp, "hand_l", "ArmL", Vector3(-0.12, -0.33, 0), 0.6)


# --- swarm (Taubenschwarm) ---------------------------------------------------------------------------------------------

const SWARM_BIRDS: int = 5
const SWARM_RADIUS: float = 0.6


static func _swarm(bp: Dictionary) -> void:
	var prim: Color = _col(bp, "primary")
	var sec: Color = _col(bp, "secondary")
	var acc: Color = _col(bp, "accent")
	var eyes: Color = _col(bp, "eyes")
	_pivot(bp, "Body", "", Vector3(0, 0.8, 0))
	for i in SWARM_BIRDS:
		var a: float = deg_to_rad(72.0 * float(i))
		var bname: String = "Bird%d" % i
		_pivot_local(bp, bname, "Body", Vector3(cos(a) * SWARM_RADIUS, 0.12 * sin(float(i) * 1.3), sin(a) * SWARM_RADIUS),
			Vector3(0, rad_to_deg(-a), 0))
		_add(bp, bname, _p(MeshUtil.sphere(0.12), Vector3.ZERO, prim, Vector3.ZERO, Vector3(1, 0.9, 1.3)))
		_add(bp, bname, _p(MeshUtil.sphere(0.055), Vector3(0, 0.10, -0.12), sec, Vector3.ZERO, Vector3.ONE, 0.0, 1.0))
		_add(bp, bname, _p(MeshUtil.cone(0.02, 0.06), Vector3(0, 0.09, -0.19), acc, Vector3(-90, 0, 0)))
		for sx: float in [-1.0, 1.0]:
			_add(bp, bname, _p(MeshUtil.box(Vector3(0.025, 0.025, 0.01)), Vector3(0.03 * sx, 0.12, -0.165), eyes,
				Vector3.ZERO, Vector3.ONE, 1.0))
			_add(bp, bname, _p(MeshUtil.box(Vector3(0.22, 0.02, 0.12)), Vector3(0.13 * sx, 0.04, 0), Palette.mul(prim, 0.85),
				Vector3(0, 0, 10 * sx)))
		_add(bp, bname, _p(MeshUtil.box(Vector3(0.08, 0.02, 0.10)), Vector3(0, 0.02, 0.17), Palette.mul(prim, 0.85)))
	_common_anchor_set(bp, "Body", Vector3(0, 0.10, 0), "Body", Vector3.ZERO, Vector3(0, 0.50, 0))
	_anchor(bp, "hand_r", "Bird0", Vector3(0, 0.09, -0.19))
	_anchor(bp, "hand_l", "Bird1", Vector3(0, 0.09, -0.19))
	_socket(bp, "head", "Bird0", Vector3(0, 0.10, -0.12), 0.055)
	_socket(bp, "eyes", "Bird0", Vector3(0, 0.12, -0.17), 0.03)
	_socket(bp, "back", "Bird0", Vector3(0, 0.10, 0.02), 0.10, Vector3(-90, 0, 0))
	_socket(bp, "chest", "Bird0", Vector3(0, 0.0, -0.14), 0.10)
	_socket(bp, "belly", "Bird0", Vector3(0, -0.06, -0.08), 0.10)
	_socket(bp, "hip_r", "Bird0", Vector3(0.10, 0.0, 0.05), 0.10)
	_socket(bp, "body", "Bird0", Vector3.ZERO, 0.12)
	_socket(bp, "hand_r", "Bird0", Vector3(0, 0.09, -0.20), 0.2, Vector3(0, 0, -90))
	_socket(bp, "hand_l", "Bird1", Vector3(0, 0.09, -0.20), 0.2, Vector3(0, 0, -90))


# --- props (03_ART §5.4) ---------------------------------------------------------------------------------------------

static func _apply_props(bp: Dictionary) -> void:
	for prop: String in (bp["props"] as PackedStringArray):
		match prop:
			"cape":
				_prop_cape(bp)
			"crown":
				_prop_crown(bp)
			"monocle":
				_prop_monocle(bp)
			"top_hat":
				_prop_top_hat(bp)
			"cap":
				_prop_cap(bp, _col(bp, "secondary") if str(bp["base"]) == "brute" else _col(bp, "accent"), false)
			"bandana":
				_prop_bandana(bp)
			"apron":
				_prop_apron(bp)
			"mop":
				_prop_mop(bp)
			"broom":
				_prop_broom(bp)
			"knife":
				_prop_knife(bp)
			"staff":
				_prop_staff(bp)
			"key_ring":
				_prop_key_ring(bp)
			"glasses":
				_prop_glasses(bp)
			"lamp_helmet":
				_prop_cap(bp, Palette.WARN_YELLOW, true)
			"backpack":
				_prop_backpack(bp)
			"mask":
				_prop_mask(bp)
			"wings":
				_prop_wings(bp)
			"antennae":
				_prop_antennae(bp)
			"newspaper_head":
				if str(bp["base"]) != "humanoid":
					var s: Dictionary = bp["sockets"]["head"]
					_newspaper_head(bp, str(s["pivot"]), s["pos"] as Vector3, float(s["size"]) / 0.28)
			"briefcase":
				_prop_briefcase(bp)
			"bottlecap_chain":
				_prop_bottlecaps(bp)
			"cable_tangle":
				_prop_cable_tangle(bp)
			"spray_cap":
				_prop_spray_cap(bp)
			"escalator_back":
				_prop_escalator(bp)
			"claws":
				_prop_claws(bp)
			"helmet":
				_prop_helmet(bp)
			"shield":
				_prop_shield(bp)
			"halberd":
				_prop_halberd(bp)
			"rat_king_tail":
				_prop_rat_king_tail(bp)
			"ticket_crown":
				_prop_ticket_crown(bp)
			"wrench":
				_prop_wrench(bp)
			"axe":
				_prop_axe(bp)
			"crowbar":
				_prop_crowbar(bp)
			"cart":
				if str(bp["base"]) != "robot":
					_prop_cart_fallback(bp)


static func _prop_cape(bp: Dictionary) -> void:
	var acc: Color = _col(bp, "accent")
	var base: String = str(bp["base"])
	if base == "pug":
		# draped velvet mantle with gold trim + white ruff collar of the self-proclaimed count
		_add(bp, "Body", _p(MeshUtil.capsule(0.19, 0.46), Vector3(0, 0.30, 0.07), acc, Vector3(90, 0, 0), Vector3(1.12, 1.0, 0.8)))
		_add(bp, "Body", _p(MeshUtil.torus(0.17, 0.21), Vector3(0, 0.28, 0.27), Palette.HYPE_GOLD, Vector3(80, 0, 0),
			Vector3(1.05, 1.0, 0.75), 0.15, 1.0))
		_add(bp, "Body", _p(MeshUtil.torus(0.12, 0.19), Vector3(0, 0.44, -0.17), Palette.PAPER, Vector3(70, 0, 0),
			Vector3(1, 1, 0.55)))
		_add(bp, "Body", _p(MeshUtil.sphere(0.035), Vector3(0, 0.36, -0.26), Palette.HYPE_GOLD, Vector3.ZERO, Vector3.ONE,
			0.3, 1.0))
		return
	if base == "rodent" and StringName(bp["pose"]) == &"upright":
		_add(bp, "Torso", _p(MeshUtil.cylinder(0.09, 0.30, 0.55), Vector3(0, 0.13, 0.01), acc))
		_add(bp, "Torso", _p(MeshUtil.cylinder(0.305, 0.305, 0.035), Vector3(0, -0.13, 0.01), Palette.HYPE_GOLD,
			Vector3.ZERO, Vector3.ONE, 0.2, 1.0))
		return
	if base == "rodent":
		# royal mantle over the back (ermine when the accent is light), gold collar + hem (03_ART §5.4)
		var f: float = RQ
		_add(bp, "Body", _p(MeshUtil.capsule(0.175 * f, 0.56 * f), Vector3(0, 0.035, 0.05) * f, acc, Vector3(90, 0, 0),
			Vector3(1.1, 1.0, 0.78)))
		if acc.get_luminance() > 0.6:
			var spots: Array[Vector3] = [Vector3(-0.07, 0.17, -0.12), Vector3(0.08, 0.17, -0.02), Vector3(-0.05, 0.18, 0.08),
				Vector3(0.06, 0.165, 0.18), Vector3(-0.10, 0.14, 0.24), Vector3(0.12, 0.13, -0.18), Vector3(0.0, 0.185, 0.0),
				Vector3(-0.13, 0.12, 0.05)]
			for sp: Vector3 in spots:
				_add(bp, "Body", _p(MeshUtil.box(Vector3(0.018, 0.012, 0.04) * f), sp * f, DARK))
		_add(bp, "Body", _p(MeshUtil.torus(0.15 * f, 0.185 * f), Vector3(0, 0.04, -0.27) * f, Palette.HYPE_GOLD,
			Vector3(75, 0, 0), Vector3.ONE, 0.2, 1.0))
		_add(bp, "Body", _p(MeshUtil.box(Vector3(0.38, 0.04, 0.04) * f), Vector3(0, 0.08, 0.33) * f, Palette.HYPE_GOLD,
			Vector3.ZERO, Vector3.ONE, 0.2, 1.0))
		return
	_place(bp, "back", 0.24, [
		_p(MeshUtil.box(Vector3(0.55, 0.85, 0.04)), Vector3(0, 0.0, 0.03), acc, Vector3(6, 0, 0)),
		_p(MeshUtil.box(Vector3(0.57, 0.05, 0.05)), Vector3(0, -0.42, 0.075), Palette.HYPE_GOLD, Vector3(6, 0, 0),
			Vector3.ONE, 0.2, 1.0),
	])


static func _prop_crown(bp: Dictionary) -> void:
	var parts: Array = [_p(MeshUtil.torus(0.09, 0.11), Vector3(0, 0.30, 0.02), Palette.HYPE_GOLD, Vector3.ZERO,
		Vector3.ONE, 0.2, 1.0)]
	for i in 5:
		var a: float = TAU * float(i) / 5.0
		parts.append(_p(MeshUtil.cone(0.03, 0.08), Vector3(cos(a) * 0.10, 0.355, 0.02 + sin(a) * 0.10), Palette.HYPE_GOLD,
			Vector3.ZERO, Vector3.ONE, 0.2, 1.0))
	_place(bp, "head", 0.28, parts)


static func _prop_monocle(bp: Dictionary) -> void:
	var gold: Color = Palette.HYPE_GOLD
	_place(bp, "eyes", 0.10, [
		_p(MeshUtil.torus(0.05, 0.065), Vector3(0.10, 0.0, -0.02), gold, Vector3(90, 0, 0), Vector3.ONE, 0.2, 1.0),
		_p(MeshUtil.cylinder(0.006, 0.006, 0.18), Vector3(0.16, -0.10, 0.0), gold, Vector3(0, 0, 25), Vector3.ONE, 0.0, 1.0),
	])


static func _prop_top_hat(bp: Dictionary) -> void:
	var acc: Color = _col(bp, "accent")
	_place(bp, "head", 0.28, [
		_p(MeshUtil.cylinder(0.16, 0.16, 0.25), Vector3(0, 0.44, 0.02), DARK, Vector3(-6, 0, 8)),
		_p(MeshUtil.cylinder(0.24, 0.24, 0.02), Vector3(0, 0.325, 0.02), DARK, Vector3(-6, 0, 8)),
		_p(MeshUtil.cylinder(0.165, 0.165, 0.04), Vector3(-0.005, 0.355, 0.02), acc, Vector3(-6, 0, 8)),
	])


static func _prop_cap(bp: Dictionary, color: Color, lamp: bool) -> void:
	var parts: Array = [
		_p(MeshUtil.hemisphere(0.31), Vector3(0, 0.07, 0.01), color),
		_p(MeshUtil.box(Vector3(0.30, 0.03, 0.20)), Vector3(0, 0.08, -0.30), Palette.mul(color, 0.85), Vector3(-8, 0, 0)),
	]
	if lamp:
		parts.append(_p(MeshUtil.cylinder(0.05, 0.05, 0.06), Vector3(0, 0.22, -0.27), Color("#fff2c8"), Vector3(-70, 0, 0),
			Vector3.ONE, 1.0))
	else:
		parts.append(_p(MeshUtil.sphere(0.03), Vector3(0, 0.38, 0.01), Palette.mul(color, 0.8)))
	_place(bp, "head", 0.28, parts)


static func _prop_bandana(bp: Dictionary) -> void:
	var acc: Color = _col(bp, "accent")
	_place(bp, "head", 0.28, [
		_p(MeshUtil.torus(0.26, 0.31), Vector3(0, 0.14, 0.0), acc, Vector3(-8, 0, 0), Vector3(1, 0.45, 1)),
		_p(MeshUtil.sphere(0.04), Vector3(0, 0.17, 0.31), acc),
		_p(MeshUtil.box(Vector3(0.05, 0.14, 0.02)), Vector3(0.03, 0.08, 0.32), acc, Vector3(0, 0, -15)),
	])


static func _prop_apron(bp: Dictionary) -> void:
	var acc: Color = _col(bp, "accent")
	_place(bp, "belly", 0.24, [
		_p(MeshUtil.box(Vector3(0.45, 0.60, 0.03)), Vector3(0, 0.0, -0.01), acc),
		_p(MeshUtil.box(Vector3(0.04, 0.30, 0.02)), Vector3(0.15, 0.42, 0.0), acc, Vector3(0, 0, 8)),
		_p(MeshUtil.box(Vector3(0.04, 0.30, 0.02)), Vector3(-0.15, 0.42, 0.0), acc, Vector3(0, 0, -8)),
		_p(MeshUtil.box(Vector3(0.20, 0.10, 0.02)), Vector3(0, -0.06, -0.025), Palette.mul(acc, 0.8)),
	])


static func _prop_mop(bp: Dictionary) -> void:
	# held low, pointing forward-down (reads in idle and swings with the arm in attack)
	var d := Vector3(0.10, -0.34, -0.93).normalized()
	var fluff := Color("#d9d2b6")
	var parts: Array = [
		_seg(d * -0.38, d * 0.84, 0.025, 0.025, WOOD_HANDLE),
		_seg(d * 0.78, d * 0.86, 0.045, 0.045, Color("#e8455a")),
		_seg(d * 0.84, d * 1.00, 0.09, 0.15, fluff),
	]
	var side: Vector3 = d.cross(Vector3.UP).normalized()
	var up2: Vector3 = side.cross(d).normalized()
	for i in 7:
		var a: float = TAU * float(i) / 7.0 + 0.3
		var off: Vector3 = (side * cos(a) + up2 * sin(a))
		var root: Vector3 = d * 0.98 + off * 0.10
		var tip: Vector3 = d * 1.12 + off * 0.17 + Vector3(0, -0.08, 0)
		parts.append(_seg(root, tip, 0.035, 0.03, Palette.mul(fluff, 0.9 + 0.05 * float(i % 3))))
	_place(bp, "hand_r", 1.0, parts)


static func _prop_broom(bp: Dictionary) -> void:
	_place(bp, "hand_r", 1.25, [
		_p(MeshUtil.cylinder(0.03, 0.03, 1.60), Vector3(0, 0.15, 0), WOOD_HANDLE, Vector3(-70, 0, 0)),
		_p(MeshUtil.box(Vector3(0.60, 0.12, 0.17)), Vector3(0, 0.42, -0.76), Color("#c9a227"), Vector3(-70, 0, 0)),
		_p(MeshUtil.box(Vector3(0.57, 0.08, 0.15)), Vector3(0, 0.45, -0.86), Color("#3b2a22"), Vector3(-70, 0, 0)),
	])


static func _prop_knife(bp: Dictionary) -> void:
	_place(bp, "hand_r", 1.0, [
		_p(MeshUtil.box(Vector3(0.04, 0.12, 0.05)), Vector3(0, 0.0, -0.02), Color("#3b2a22"), Vector3(-80, 0, 0)),
		_p(MeshUtil.box(Vector3(0.03, 0.25, 0.06)), Vector3(0, 0.03, -0.20), Palette.STEEL, Vector3(-80, 0, 0),
			Vector3.ONE, 0.0, 1.0),
	])


static func _prop_staff(bp: Dictionary) -> void:
	var acc: Color = _col(bp, "accent")
	var queen: bool = _has(bp, "ticket_crown")
	var bulb: Color = Palette.LIVE_RED if queen else (acc if acc.get_luminance() > 0.35 else Color("#ffe66b"))
	var eyes: Color = _col(bp, "eyes")
	if str(bp["base"]) == "rodent" and not queen:
		bulb = eyes
	var s: Dictionary = bp["sockets"].get("hand_r", {})
	var hand_pivot: String = str(s.get("pivot", "Body"))
	_place(bp, "hand_r", 0.55, [
		_p(MeshUtil.cylinder(0.025, 0.025, 1.00), Vector3(0, 0.20, 0), STAFF_WOOD),
		_p(MeshUtil.torus(0.06, 0.085), Vector3(0, 0.66, 0), Palette.BRASS, Vector3.ZERO, Vector3.ONE, 0.0, 1.0),
	])
	_place(bp, "hand_r", 0.55, [
		_p(MeshUtil.sphere(0.08), Vector3(0, 0.72, 0), bulb, Vector3.ZERO, Vector3.ONE, 1.0),
	], "Bulb")
	_mesh(bp, "Bulb", hand_pivot)["role"] = "bulb"
	if queen:
		_mesh(bp, "Bulb", hand_pivot)["pulse"] = {"mode": "alt", "color": Palette.LIVE_RED, "color2": Palette.EXIT_GREEN}
	else:
		_mesh(bp, "Bulb", hand_pivot)["pulse"] = {"mode": "pulse", "color": Palette.PAPER}


static func _prop_key_ring(bp: Dictionary) -> void:
	var k: float = _socket_pivot(bp, "hip_r", 0.40, "Keys", Vector3.ZERO)
	var parts: Array = [_p(MeshUtil.torus(0.12, 0.145), Vector3(0, -0.02, 0), Palette.STEEL, Vector3(0, 0, 90),
		Vector3.ONE, 0.0, 1.0)]
	for i in 12:
		var a: float = deg_to_rad(-80.0 + 160.0 * float(i) / 11.0)
		var pos := Vector3(0.02 * sin(float(i)), -0.02 - cos(a) * 0.18, sin(a) * 0.18)
		var col: Color = Palette.BRASS if i % 2 == 0 else Palette.RAIL
		parts.append(_p(MeshUtil.torus(0.03, 0.06, 6, 3), pos, col, Vector3(0, 0, 90 + 25.0 * float(i % 3)), Vector3.ONE,
			0.0, 1.0))
	for p: Dictionary in _scaled_parts(parts, k):
		_add(bp, "Keys", p)


static func _prop_glasses(bp: Dictionary) -> void:
	_place(bp, "eyes", 0.10, [
		_p(MeshUtil.torus(0.05, 0.062), Vector3(0.10, 0.0, -0.015), DARK, Vector3(90, 0, 0)),
		_p(MeshUtil.torus(0.05, 0.062), Vector3(-0.10, 0.0, -0.015), DARK, Vector3(90, 0, 0)),
		_p(MeshUtil.box(Vector3(0.04, 0.012, 0.012)), Vector3(0, 0.01, -0.015), DARK),
	])


static func _prop_backpack(bp: Dictionary) -> void:
	var acc: Color = _col(bp, "accent")
	_place(bp, "back", 0.24, [
		_p(MeshUtil.box(Vector3(0.35, 0.45, 0.20)), Vector3(0, -0.05, 0.09), acc),
		_p(MeshUtil.box(Vector3(0.30, 0.15, 0.06)), Vector3(0, -0.15, 0.21), Palette.mul(acc, 0.8)),
		_p(MeshUtil.box(Vector3(0.04, 0.40, 0.02)), Vector3(0.12, 0.05, -0.49), Palette.mul(acc, 0.7)),
		_p(MeshUtil.box(Vector3(0.04, 0.40, 0.02)), Vector3(-0.12, 0.05, -0.49), Palette.mul(acc, 0.7)),
	])


static func _prop_mask(bp: Dictionary) -> void:
	_place(bp, "head", 0.28, [
		_p(MeshUtil.cylinder(0.08, 0.10, 0.10), Vector3(0, -0.07, -0.28), Palette.DARK_METAL, Vector3(-90, 0, 0)),
		_p(MeshUtil.cylinder(0.04, 0.04, 0.06), Vector3(0.11, -0.12, -0.26), Color("#6b7b3a"), Vector3(-90, 35, 0)),
		_p(MeshUtil.cylinder(0.04, 0.04, 0.06), Vector3(-0.11, -0.12, -0.26), Color("#6b7b3a"), Vector3(-90, -35, 0)),
		_p(MeshUtil.torus(0.06, 0.075), Vector3(0.09, 0.02, -0.24), Palette.DARK_METAL, Vector3(90, 0, 0)),
		_p(MeshUtil.torus(0.06, 0.075), Vector3(-0.09, 0.02, -0.24), Palette.DARK_METAL, Vector3(90, 0, 0)),
	])


static func _prop_wings(bp: Dictionary) -> void:
	var sec: Color = _col(bp, "secondary")
	for side: String in ["WingL", "WingR"]:
		var sx: float = -1.0 if side == "WingL" else 1.0
		var k: float = _socket_pivot(bp, "back", 0.24, side, Vector3(0.08 * sx, 0.05, 0.02))
		var parts: Array = [
			_p(MeshUtil.box(Vector3(0.50, 0.02, 0.25)), Vector3(0.25 * sx, 0, 0), sec, Vector3(0, 0, 0)),
			_p(MeshUtil.box(Vector3(0.30, 0.025, 0.12)), Vector3(0.18 * sx, 0.005, 0.10), Palette.mul(sec, 0.8)),
		]
		if StringName(bp["pose"]) == &"upright" and str(bp["base"]) != "insect":
			# back socket of upright bases faces +Z: wings spread sideways, laid back
			parts = [
				_p(MeshUtil.box(Vector3(0.50, 0.25, 0.02)), Vector3(0.25 * sx, 0.05, 0.02), sec),
				_p(MeshUtil.box(Vector3(0.30, 0.12, 0.025)), Vector3(0.18 * sx, -0.06, 0.03), Palette.mul(sec, 0.8)),
			]
		for p: Dictionary in _scaled_parts(parts, k):
			_add(bp, side, p)


static func _prop_antennae(bp: Dictionary) -> void:
	var acc: Color = _col(bp, "accent")
	var parts: Array = []
	for sx: float in [-1.0, 1.0]:
		var a := Vector3(0.08 * sx, 0.24, -0.02)
		var b := Vector3(0.16 * sx, 0.47, -0.06)
		parts.append(_seg(a, b, 0.012, 0.01, DARK))
		parts.append(_p(MeshUtil.sphere(0.035), b, acc, Vector3.ZERO, Vector3.ONE, 1.0))
	_place(bp, "head", 0.28, parts)


static func _prop_briefcase(bp: Dictionary) -> void:
	_place(bp, "hand_l", 1.0, [
		_p(MeshUtil.box(Vector3(0.10, 0.30, 0.40)), Vector3(-0.02, -0.19, 0), Color("#5a3a22")),
		_p(MeshUtil.box(Vector3(0.03, 0.03, 0.12)), Vector3(-0.02, -0.025, 0), Color("#2a1a10")),
		_p(MeshUtil.box(Vector3(0.01, 0.03, 0.03)), Vector3(-0.075, -0.09, 0.10), Palette.BRASS, Vector3.ZERO, Vector3.ONE,
			0.0, 1.0),
		_p(MeshUtil.box(Vector3(0.01, 0.03, 0.03)), Vector3(-0.075, -0.09, -0.10), Palette.BRASS, Vector3.ZERO, Vector3.ONE,
			0.0, 1.0),
	])


static func _prop_bottlecaps(bp: Dictionary) -> void:
	var cols: Array[Color] = [Color("#c0c0c0"), Color("#d93b3b"), Color("#f2c230")]
	var parts: Array = []
	for i in 6:
		var a: float = deg_to_rad(-60.0 + 120.0 * float(i) / 5.0)
		var pos := Vector3(sin(a) * 0.15, 0.20 - cos(a) * 0.15, -0.012 - 0.02 * cos(a))
		parts.append(_p(MeshUtil.box(Vector3(0.05, 0.05, 0.012)), pos, cols[i % 3], Vector3(0, 0, 45), Vector3.ONE,
			0.0, 1.0))
	_place(bp, "chest", 0.14, parts)


static func _prop_cable_tangle(bp: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(bp["seed"]) * 7919 + 11
	var parts: Array = []
	parts.append(_p(MeshUtil.box(Vector3(0.20, 0.20, 0.04)), Vector3(0, 0, -0.43), Color("#e8e8e8")))
	for sx: float in [-1.0, 1.0]:
		parts.append(_p(MeshUtil.cylinder(0.015, 0.015, 0.02), Vector3(0.04 * sx, 0, -0.455), DARK, Vector3(90, 0, 0)))
	var cols: Array[Color] = [Color("#1e1e1e"), Color("#d93b3b"), Color("#3b6fd9")]
	var n: int = 8
	for i in n:
		# Fibonacci sphere point on r 0.42 around the blob center
		var y: float = 1.0 - (float(i) + 0.5) / float(n) * 2.0
		var rr: float = sqrt(1.0 - y * y)
		var th: float = PI * (3.0 - sqrt(5.0)) * float(i)
		var nrm := Vector3(cos(th) * rr, y, sin(th) * rr)
		if nrm.z < -0.75:
			nrm = (nrm + Vector3(0, 0.6, 0.5)).normalized()   # keep the socket face free
		var p: Vector3 = nrm * 0.42
		var dir: Vector3 = nrm
		var side: Vector3 = dir.cross(Vector3.UP if absf(dir.y) < 0.9 else Vector3.RIGHT).normalized()
		var spin: float = rng.randf_range(0.0, TAU)
		var axis: Vector3 = side.rotated(dir, spin)
		for j in 3:
			dir = dir.rotated(axis, deg_to_rad(35.0)).normalized()
			var q: Vector3 = p + dir * 0.18
			parts.append(_seg(p, q, 0.035, 0.035, cols[(i + j) % 3]))
			p = q
		parts.append(_p(MeshUtil.box(Vector3(0.06, 0.04, 0.08)), p, Color("#c0c0c0"),
			Vector3(rng.randf_range(-40.0, 40.0), rng.randf_range(0.0, 180.0), 0), Vector3.ONE, 0.0, 1.0))
	_place(bp, "body", 0.45, parts, "Cables")
	_mesh(bp, "Cables", str(bp["sockets"]["body"]["pivot"]))["mat"] = {"bands": 3, "rim": 0.45, "wobble": 0.05}
	bp["particles"].append({"kind": "sparks", "pivot": str(bp["sockets"]["body"]["pivot"]),
		"pos": bp["sockets"]["body"]["pos"]})


static func _prop_spray_cap(bp: Dictionary) -> void:
	_place(bp, "head", 0.30, [
		_p(MeshUtil.cylinder(0.05, 0.05, 0.10), Vector3(0, 0.32, 0), DARK),
		_p(MeshUtil.box(Vector3(0.07, 0.06, 0.09)), Vector3(0, 0.39, -0.03), Color.WHITE),
		_p(MeshUtil.box(Vector3(0.025, 0.025, 0.01)), Vector3(0, 0.39, -0.079), DARK),
	])


static func _prop_escalator(bp: Dictionary) -> void:
	var prim: Color = _col(bp, "primary")
	var parts: Array = []
	for i in 5:
		var y: float = 0.12 + 0.12 * float(i)
		var z: float = -0.40 + 0.21 * float(i)
		parts.append(_p(MeshUtil.box(Vector3(0.80, 0.12, 0.24)), Vector3(0, y, z), Palette.mul(prim, 0.75)))
		parts.append(_p(MeshUtil.box(Vector3(0.82, 0.03, 0.04)), Vector3(0, y + 0.06, z - 0.105), Palette.WARN_YELLOW,
			Vector3.ZERO, Vector3.ONE, 0.25))
	for sx: float in [-1.0, 1.0]:
		parts.append(_seg(Vector3(0.44 * sx, 0.18, -0.52), Vector3(0.44 * sx, 0.76, 0.48), 0.05, 0.05, Color("#1e1e22")))
		parts.append(_p(MeshUtil.box(Vector3(0.04, 0.30, 0.95)), Vector3(0.42 * sx, 0.30, -0.02), Palette.mul(prim, 0.55),
			Vector3(-29, 0, 0)))
	if str(bp["base"]) == "insect":
		var mn: String = "Escalator"
		for p: Dictionary in parts:
			_add(bp, "Body", p, mn)
		_mesh(bp, mn, "Body")["mat"] = {"bands": 3, "rim": 0.45,
			"stripes": {"color": Palette.WARN_YELLOW, "width": 0.15, "speed": 0.8}}
	else:
		_place(bp, "back", 0.40, _scaled_parts(parts, 0.5), "Escalator")
		_mesh(bp, "Escalator", str(bp["sockets"]["back"]["pivot"]))["mat"] = {"bands": 3, "rim": 0.45,
			"stripes": {"color": Palette.WARN_YELLOW, "width": 0.15, "speed": 0.8}}


static func _prop_claws(bp: Dictionary) -> void:
	var acc: Color = _col(bp, "accent")
	var prim: Color = _col(bp, "primary")
	var insect: bool = str(bp["base"]) == "insect"
	for side: String in ["ClawL", "ClawR"]:
		var sx: float = -1.0 if side == "ClawL" else 1.0
		var parts: Array = [
			_p(MeshUtil.cone(0.07, 0.30), Vector3(0, 0.04, -0.15), acc, Vector3(-90, 0, 0)),
			_p(MeshUtil.cone(0.06, 0.25), Vector3(0, -0.04, -0.13), Palette.mul(acc, 0.85), Vector3(-80, 0, 0)),
			_p(MeshUtil.sphere(0.059), Vector3.ZERO, acc, Vector3.ZERO, Vector3(1.35, 1.35, 1.35)),
		]
		if insect:
			_pivot_local(bp, side, "Body", Vector3(0.30 * sx, 0.0, -0.45))
			for p: Dictionary in parts:
				_add(bp, side, p)
			_add(bp, "Body", _seg(Vector3(0.12 * sx, -0.05, -0.25), Vector3(0.30 * sx, 0.0, -0.45), 0.045, 0.04, prim))
		else:
			var k: float = _socket_pivot(bp, "hand_r" if sx > 0.0 else "hand_l", 1.0, side, Vector3.ZERO)
			for p: Dictionary in _scaled_parts(parts, k * 0.8):
				_add(bp, side, p)


static func _prop_helmet(bp: Dictionary) -> void:
	_place(bp, "head", 0.12, [
		_p(MeshUtil.hemisphere(0.135), Vector3(0, 0.03, 0), Palette.RAIL, Vector3.ZERO, Vector3.ONE, 0.0, 1.0),
		_p(MeshUtil.cone(0.03, 0.10), Vector3(0, 0.20, 0), Palette.RAIL, Vector3.ZERO, Vector3.ONE, 0.0, 1.0),
		_p(MeshUtil.box(Vector3(0.03, 0.08, 0.05)), Vector3(0, -0.01, -0.13), Palette.RAIL, Vector3.ZERO, Vector3.ONE,
			0.0, 1.0),
	])


static func _prop_shield(bp: Dictionary) -> void:
	var acc: Color = _col(bp, "accent")
	_place(bp, "hand_l", 0.55, [
		_p(MeshUtil.box(Vector3(0.25, 0.33, 0.03)), Vector3(0, 0, -0.06), Palette.RAIL, Vector3.ZERO, Vector3.ONE, 0.0, 1.0),
		_p(MeshUtil.box(Vector3(0.12, 0.12, 0.01)), Vector3(0, 0.02, -0.08), acc),
		_p(MeshUtil.prism(Vector3(0.12, 0.05, 0.01)), Vector3(0, 0.105, -0.08), acc),
	])


static func _prop_halberd(bp: Dictionary) -> void:
	_place(bp, "hand_r", 0.55, [
		_p(MeshUtil.cylinder(0.015, 0.015, 0.90), Vector3(0, 0.25, 0), STAFF_WOOD),
		_p(MeshUtil.box(Vector3(0.02, 0.12, 0.14)), Vector3(0, 0.62, -0.06), Palette.STEEL, Vector3.ZERO, Vector3.ONE, 0.0, 1.0),
		_p(MeshUtil.cone(0.02, 0.08), Vector3(0, 0.74, 0), Palette.STEEL, Vector3.ZERO, Vector3.ONE, 0.0, 1.0),
	])


static func _prop_rat_king_tail(bp: Dictionary) -> void:
	var sec: Color = _col(bp, "secondary")
	var prim: Color = _col(bp, "primary")
	var tail_pivot: String = "Tail"
	if not _has_pivot(bp, tail_pivot):
		var s: Dictionary = bp["sockets"].get("back", bp["sockets"]["body"])
		_pivot_local(bp, tail_pivot, str(s["pivot"]), (s["pos"] as Vector3))
	var f: float = RQ if str(bp["base"]) == "rodent" else 1.0
	var mn: String = "RatKingTail"
	_add(bp, tail_pivot, _p(MeshUtil.sphere(0.05 * f), Vector3.ZERO, sec), mn)
	var pitches: Array[float] = [-55.0, -18.0, 4.0]
	for i in 6:
		var yaw: float = -50.0 + 20.0 * float(i)
		var yb := Basis(Vector3.UP, deg_to_rad(yaw))
		var end := Vector3.ZERO
		for j in 3:
			var a: float = deg_to_rad(pitches[j] + 4.0 * float(i % 2))
			var q: Vector3 = end + yb * Vector3(0, sin(a), cos(a)) * 0.20 * f
			_add(bp, tail_pivot, _seg(end, q, lerpf(0.03, 0.015, float(j) / 3.0) * f,
				lerpf(0.03, 0.015, float(j + 1) / 3.0) * f, sec), mn)
			end = q
		var dir: Vector3 = yb * Vector3(0, 0, 1)
		var body_c: Vector3 = end + dir * 0.04 * f + Vector3(0, 0.01, 0) * f
		_add(bp, tail_pivot, _p(MeshUtil.sphere(0.059), body_c, prim, Vector3(0, yaw, 0), Vector3(0.9, 0.8, 1.4) * (0.05 * f / 0.059)),
			mn)
		var head_c: Vector3 = body_c + dir * 0.065 * f + Vector3(0, 0.01, 0) * f
		_add(bp, tail_pivot, _p(MeshUtil.sphere(0.03 * f), head_c, prim), mn)
		_add(bp, tail_pivot, _p(MeshUtil.box(Vector3(0.05, 0.022, 0.01) * f), head_c + Vector3(0, 0.028, 0) * f, sec,
			Vector3(0, yaw, 0)), mn)
	_mesh(bp, mn, tail_pivot)["mat"] = {"bands": 3, "rim": 0.45, "wobble": 0.02}


static func _prop_ticket_crown(bp: Dictionary) -> void:
	var k: float = _socket_pivot(bp, "head", 0.14, "Crown", Vector3(0, 0.125, 0.0))
	var parts: Array = [_p(MeshUtil.torus(0.095, 0.11), Vector3.ZERO, Palette.BRASS, Vector3.ZERO, Vector3.ONE, 0.15, 1.0)]
	for i in 10:
		var a: float = TAU * float(i) / 10.0
		var pos := Vector3(cos(a) * 0.10, 0.035, sin(a) * 0.10)
		var rot := Vector3(0, rad_to_deg(-a) + 90.0, 0)
		var t_basis := Basis.from_euler(rot * (PI / 180.0)) * Basis(Vector3.RIGHT, deg_to_rad(-8.0))
		parts.append({"mesh": MeshUtil.box(Vector3(0.035, 0.07, 0.006)), "xform": Transform3D(t_basis, pos),
			"color": Color("#f2e8c9"), "emission": 0.0, "metal": 0.0})
		parts.append({"mesh": MeshUtil.box(Vector3(0.012, 0.012, 0.008)),
			"xform": Transform3D(t_basis, pos + t_basis * Vector3(0, 0.015, 0)), "color": DARK, "emission": 0.0, "metal": 0.0})
	for p: Dictionary in _scaled_parts(parts, k):
		_add(bp, "Crown", p)
	_mesh(bp, "Crown", "Crown")["pulse"] = {"mode": "phase", "color": Color("#ff5a5a"), "phase": 3, "amount": 0.8}
	_mesh(bp, "Crown", "Crown")["role"] = "crown"


static func _prop_wrench(bp: Dictionary) -> void:
	_place(bp, "hand_r", 1.0, [
		_p(MeshUtil.box(Vector3(0.05, 0.32, 0.035)), Vector3(0, 0.10, -0.05), Color("#c23b22"), Vector3(-70, 0, 0)),
		_p(MeshUtil.box(Vector3(0.10, 0.08, 0.05)), Vector3(0, 0.18, -0.24), Palette.RAIL, Vector3(-70, 0, 0), Vector3.ONE,
			0.0, 1.0),
		_p(MeshUtil.box(Vector3(0.08, 0.03, 0.05)), Vector3(0, 0.23, -0.26), Palette.RAIL, Vector3(-70, 0, 0), Vector3.ONE,
			0.0, 1.0),
	])


static func _prop_axe(bp: Dictionary) -> void:
	_place(bp, "hand_r", 1.0, [
		_p(MeshUtil.cylinder(0.025, 0.025, 0.80), Vector3(0, 0.10, -0.10), Color("#c23b22"), Vector3(-70, 0, 0)),
		_p(MeshUtil.prism(Vector3(0.22, 0.18, 0.03)), Vector3(0.10, 0.20, -0.36), Palette.STEEL, Vector3(-70, 0, -90),
			Vector3.ONE, 0.0, 1.0),
		_p(MeshUtil.cone(0.025, 0.10), Vector3(-0.08, 0.20, -0.36), Palette.STEEL, Vector3(0, 0, 90), Vector3.ONE, 0.0, 1.0),
	])


static func _prop_crowbar(bp: Dictionary) -> void:
	_place(bp, "hand_r", 1.0, [
		_p(MeshUtil.cylinder(0.02, 0.02, 0.85), Vector3(0, 0.10, -0.08), Palette.DARK_METAL, Vector3(-70, 0, 0),
			Vector3.ONE, 0.0, 1.0),
		_p(MeshUtil.cylinder(0.012, 0.02, 0.15), Vector3(0, 0.27, -0.50), Palette.DARK_METAL, Vector3(-35, 0, 0),
			Vector3.ONE, 0.0, 1.0),
		_p(MeshUtil.cylinder(0.024, 0.024, 0.15), Vector3(0, 0.0, 0.05), Palette.WARN_YELLOW, Vector3(-70, 0, 0)),
	])


## cart on non-robot bases: a small trolley beside the figure (simplified fallback, 03_ART §5.4).
static func _prop_cart_fallback(bp: Dictionary) -> void:
	var wire := Color("#c0c6cc")
	var parts: Array = [
		_p(MeshUtil.box(Vector3(0.30, 0.25, 0.40)), Vector3(0.0, 0.0, 0.0), Palette.mul(wire, 0.7), Vector3.ZERO,
			Vector3.ONE, 0.0, 1.0),
		_p(MeshUtil.cylinder(0.02, 0.02, 0.34), Vector3(0, 0.20, 0.22), Color("#e8455a"), Vector3(0, 0, 90)),
	]
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			parts.append(_p(MeshUtil.cylinder(0.04, 0.04, 0.03), Vector3(0.12 * sx, -0.16, 0.15 * sz), Color("#1e1e1e"),
				Vector3(0, 0, 90)))
	_place(bp, "hip_r", 0.24, parts)
