extends Node3D
## Looping status visuals at a battle rig (03_ART §7 "Status-Loops", set by the BattlePlayer): poison 3 bubbles,
## stun 3 prism stars orbiting r 0.25 @ 2 rad/s, slow torus 0.35/0.40 at the feet, haste 2 rising chevrons, guard
## hex shield α 0.15, taunt cone hopping 0.1 m @ 2 Hz. Child of the CharacterRig (follows it); private M5 helper.

const POISON: Color = Color("#7cc242")
const STUN: Color = Color("#f5d90a")
const SLOW: Color = Color("#5b8def")
const HASTE: Color = Color("#ff7a1a")
const GUARD: Color = Color("#9aa7b8")
const TAUNT: Color = Color("#e8455a")

var _rig: CharacterRig = null
var _nodes: Dictionary = {}        # status id → Node3D
var _t: float = 0.0
var _height: float = 1.0
var _k: float = 1.0


func setup(p_rig: CharacterRig) -> void:
	_rig = p_rig
	_height = maxf(p_rig.height, 0.3)
	_k = clampf(p_rig.size_factor(), 0.5, 2.2)


func active() -> PackedStringArray:
	var out: PackedStringArray = []
	for k: Variant in _nodes.keys():
		out.append(str(k))
	out.sort()
	return out


func set_status(status_id: String, on: bool) -> void:
	if on == _nodes.has(status_id):
		return
	if not on:
		var n: Node3D = _nodes[status_id]
		_nodes.erase(status_id)
		if is_instance_valid(n):
			n.queue_free()
		return
	var node: Node3D = _build(status_id)
	if node == null:
		return
	add_child(node)
	_nodes[status_id] = node


func clear() -> void:
	for k: Variant in _nodes.keys():
		var n: Node3D = _nodes[k]
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()


func _process(delta: float) -> void:
	_t += delta
	if _nodes.is_empty():
		return
	var top: float = _height + 0.18 * _k
	for k: Variant in _nodes.keys():
		var n: Node3D = _nodes[k]
		match str(k):
			"sts_stun":
				n.position = Vector3(0, top, 0)
				n.rotation.y = _t * 2.0
			"sts_poison":
				n.position = Vector3(0, top - 0.1 * _k, 0)
				var i: int = 0
				for c: Node in n.get_children():
					var b: Node3D = c as Node3D
					var u: float = fposmod(_t * 0.7 + float(i) / 3.0, 1.0)
					b.position = Vector3(cos(float(i) * 2.1) * 0.22 * _k, u * 0.45 * _k, sin(float(i) * 2.1) * 0.22 * _k)
					b.scale = Vector3.ONE * maxf(0.05, sin(u * PI))
					i += 1
			"sts_slow":
				n.position = Vector3(0, 0.05, 0)
				n.rotation.y = -_t * 0.6
			"sts_haste":
				n.position = Vector3(0, 0, 0)
				var j: int = 0
				for c2: Node in n.get_children():
					var ch: Node3D = c2 as Node3D
					var u2: float = fposmod(_t * 1.2 + float(j) * 0.5, 1.0)
					ch.position = Vector3(0, 0.15 + u2 * _height * 0.8, 0.35 * _k)
					ch.scale = Vector3.ONE * _k * maxf(0.05, sin(u2 * PI))
					j += 1
			"sts_guard":
				n.position = Vector3(0, _height * 0.5, 0)
				var s: float = 1.0 + 0.03 * sin(_t * TAU / 1.2)
				n.scale = Vector3(s, 1.0, s)
			"sts_taunt":
				n.position = Vector3(0, top + 0.12 + 0.1 * absf(sin(_t * PI * 2.0)), 0)
				n.rotation.y = _t * 1.5


func _build(status_id: String) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Fx_" + status_id
	match status_id:
		"sts_stun":
			for i in 3:
				var a: float = TAU * float(i) / 3.0
				var star: MeshInstance3D = _mesh(MeshUtil.prism(Vector3(0.12, 0.12, 0.05)), Materials.glow(STUN, 2.5))
				star.position = Vector3(cos(a) * 0.25 * _k, 0, sin(a) * 0.25 * _k)
				star.rotation = Vector3(0, -a, 0)
				root.add_child(star)
		"sts_poison":
			for i in 3:
				var bub: MeshInstance3D = _mesh(MeshUtil.sphere(0.06 * _k), Materials.glow(POISON, 1.6))
				root.add_child(bub)
		"sts_slow":
			var ring: MeshInstance3D = _mesh(MeshUtil.torus(0.35 * _k, 0.40 * _k, 20, 3),
				Materials.hologram(SLOW, 0.55, 1.6))
			ring.scale = Vector3(1, 0.4, 1)
			root.add_child(ring)
		"sts_haste":
			for i in 2:
				var chev: MeshInstance3D = _mesh(MeshUtil.prism(Vector3(0.22, 0.12, 0.04)), Materials.glow(HASTE, 2.2))
				root.add_child(chev)
		"sts_guard":
			var hex: CylinderMesh = MeshUtil.cylinder(0.55 * _k, 0.55 * _k, _height * 1.1)
			hex.radial_segments = 6
			hex.cap_top = false
			hex.cap_bottom = false
			var shield: MeshInstance3D = _mesh(hex, Materials.hologram(GUARD, 0.15, 1.2))
			root.add_child(shield)
		"sts_taunt":
			var cone: MeshInstance3D = _mesh(MeshUtil.cylinder(0.2 * _k, 0.0, 0.26 * _k),
				Materials.toon(TAUNT, {"bands": 3, "rim": 0.4, "outline_width": 0.015}))
			root.add_child(cone)
		_:
			root.free()
			return null
	return root


static func _mesh(m: Mesh, mat: Material) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
