extends Node3D
## Pseudo unit "Einfahrender Zug" (pu_train_gleis9, GDD §5.3) on the battle stage: a track across the party line,
## blinking signal lamps while the train is in the CTB order (armed), and the train itself that rushes through the
## party on its turn (pass_through). Private M5 helper; presentation only.

signal hit
signal frame_ticked

const TRACK_LEN: float = 64.0
const START_X: float = -46.0
const END_X: float = 46.0
const BODY: Color = Color("#8a8f96")
const ROOF: Color = Color("#6e6a72")
const WINDOW: Color = Color("#ffd27a")
const BAND: Color = Color("#f2c230")
const NOSE: Color = Color("#2e2a38")

var armed: bool = false
var running: bool = false

var _track: Node3D = null
var _train: Node3D = null
var _lamps: Array[MeshInstance3D] = []
var _beams: Array[OmniLight3D] = []
var _z: float = 3.1
var _t: float = 0.0
var _hit_sent: bool = false


func setup(line_z: float) -> void:
	_z = line_z
	_track = _build_track()
	add_child(_track)
	_train = _build_train()
	_train.visible = false
	add_child(_train)
	set_armed(false)


func set_armed(on: bool) -> void:
	armed = on
	if _track != null:
		_track.visible = on or running


func _process(delta: float) -> void:
	frame_ticked.emit()
	_t += delta
	var blink: bool = armed and int(floor(_t * 3.0)) % 2 == 0
	for i in _lamps.size():
		var on: bool = blink if i % 2 == 0 else (armed and not blink)
		_lamps[i].set_instance_shader_parameter(&"flash_amount", 1.0 if on else 0.0)
	for b: OmniLight3D in _beams:
		b.visible = running


## Coroutine: the train crosses the stage in `duration` seconds; `hit` fires when the nose reaches the party.
func pass_through(duration: float) -> void:
	if _train == null or not is_inside_tree():
		hit.emit()
		return
	running = true
	_hit_sent = false
	_track.visible = true
	_train.visible = true
	_train.position = Vector3(START_X, 0, _z)
	var elapsed: float = 0.0
	var d: float = maxf(duration, 0.05)
	while elapsed < d:
		await frame_ticked
		elapsed += get_process_delta_time()
		var u: float = clampf(elapsed / d, 0.0, 1.0)
		# fast entry, a short brake at the party, out again
		var x: float = lerpf(START_X, END_X, u * u * (3.0 - 2.0 * u))
		_train.position = Vector3(x, 0, _z)
		if not _hit_sent and x + 8.5 >= -2.0:
			_hit_sent = true
			hit.emit()
	if not _hit_sent:
		hit.emit()
	_train.visible = false
	running = false
	_track.visible = armed


func _build_track() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Track"
	var parts: Array[Dictionary] = []
	for sz: float in [-0.72, 0.72]:
		parts.append(MeshUtil.part(MeshUtil.box(Vector3(TRACK_LEN, 0.08, 0.1)), Vector3(0, 0.05, _z + sz),
			Palette.RAIL, Vector3.ZERO, Vector3.ONE, 0.0, 1.0))
	var n: int = int(TRACK_LEN / 1.2)
	for i in n:
		var x: float = -TRACK_LEN * 0.5 + 0.6 + 1.2 * float(i)
		parts.append(MeshUtil.part(MeshUtil.box(Vector3(0.26, 0.04, 2.1)), Vector3(x, 0.02, _z), Palette.SLEEPER))
	# warning band along the stage crossing
	for sz2: float in [-1.35, 1.35]:
		parts.append(MeshUtil.part(MeshUtil.box(Vector3(18.0, 0.02, 0.14)), Vector3(0, 0.012, _z + sz2),
			Palette.WARN_YELLOW, Vector3.ZERO, Vector3.ONE, 0.4))
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Rails"
	mi.mesh = MeshUtil.merge_no_hull(parts)
	mi.material_override = Materials.env({"grout_width": 0.0, "dirt": 0.15})
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	# signal posts with two lamps each at both stage edges
	for sx: float in [-9.6, 9.6]:
		var post: MeshInstance3D = MeshInstance3D.new()
		post.mesh = MeshUtil.merge([MeshUtil.part(MeshUtil.cylinder(0.06, 0.08, 2.4), Vector3(0, 1.2, 0),
			Palette.DARK_METAL), MeshUtil.part(MeshUtil.box(Vector3(0.5, 0.9, 0.2)), Vector3(0, 2.4, 0), Palette.INK)])
		post.material_override = Materials.toon_vc({"bands": 3, "rim": 0.3, "outline_width": 0.02})
		post.position = Vector3(sx, 0, _z - 1.6)
		root.add_child(post)
		for ly: float in [2.6, 2.2]:
			var lamp: MeshInstance3D = MeshInstance3D.new()
			lamp.mesh = MeshUtil.sphere(0.13)
			lamp.material_override = Materials.toon(Color("#5a1010"), {"outline": false, "rim": 0.2,
				"emission": Palette.LIVE_RED})
			lamp.set_instance_shader_parameter(&"flash_color", Palette.LIVE_RED)
			lamp.position = Vector3(sx, ly, _z - 1.48)
			lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(lamp)
			_lamps.append(lamp)
	return root


func _build_train() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "TrainBody"
	var parts: Array[Dictionary] = []
	for car in 2:
		var cx: float = -9.0 * float(car)
		parts.append(MeshUtil.part(MeshUtil.box(Vector3(8.6, 2.9, 2.8)), Vector3(cx, 1.75, 0), BODY))
		parts.append(MeshUtil.part(MeshUtil.box(Vector3(8.7, 0.25, 2.9)), Vector3(cx, 3.28, 0), ROOF))
		parts.append(MeshUtil.part(MeshUtil.box(Vector3(8.64, 0.22, 2.84)), Vector3(cx, 0.75, 0), BAND))
		for k in 3:
			for sz: float in [-1.0, 1.0]:
				parts.append(MeshUtil.part(MeshUtil.box(Vector3(1.6, 0.8, 0.04)),
					Vector3(cx - 2.6 + 2.6 * float(k), 2.2, 1.41 * sz), WINDOW, Vector3.ZERO, Vector3.ONE, 0.9))
		for wx: float in [-3.0, 3.0]:
			for sz2: float in [-1.0, 1.0]:
				parts.append(MeshUtil.part(MeshUtil.cylinder(0.42, 0.42, 0.22), Vector3(cx + wx, 0.42, 1.1 * sz2),
					NOSE, Vector3(90, 0, 0)))
	# nose (+X): dark front with two head lamps and the destination sign
	parts.append(MeshUtil.part(MeshUtil.box(Vector3(0.3, 2.6, 2.6)), Vector3(4.42, 1.75, 0), NOSE))
	for sz3: float in [-0.8, 0.8]:
		parts.append(MeshUtil.part(MeshUtil.cylinder(0.22, 0.22, 0.1), Vector3(4.6, 1.0, sz3), Color("#fff2c8"),
			Vector3(0, 0, 90), Vector3.ONE, 1.0))
	parts.append(MeshUtil.part(MeshUtil.box(Vector3(0.1, 0.42, 1.9)), Vector3(4.6, 2.75, 0), Palette.SODIUM,
		Vector3.ZERO, Vector3.ONE, 1.0))
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Cars"
	mi.mesh = MeshUtil.merge(parts)
	mi.material_override = Materials.toon_vc({"bands": 3, "rim": 0.45, "outline_width": 0.03})
	root.add_child(mi)
	var sign: Label3D = Label3D.new()
	sign.text = "GLEIS 9"
	sign.font_size = 48
	sign.outline_size = 8
	sign.pixel_size = 0.006
	sign.modulate = Palette.INK
	sign.outline_modulate = Palette.SODIUM
	sign.position = Vector3(4.68, 2.75, 0)
	sign.rotation = Vector3(0, PI * 0.5, 0)
	root.add_child(sign)
	var beam: OmniLight3D = OmniLight3D.new()
	beam.light_color = Color("#fff2c8")
	beam.omni_range = 8.0
	beam.light_energy = 2.4
	beam.shadow_enabled = false
	beam.light_specular = 0.0
	beam.visible = false
	beam.position = Vector3(5.8, 1.2, 0)
	root.add_child(beam)
	_beams.append(beam)
	return root
