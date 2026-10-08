extends Node3D
## One pooled effect instance of Vfx (03_ART §7). Private (no class_name). Built once per kind (CPUParticles3D +
## animated helper meshes), replayed by play(); hides itself after its duration (loop kinds keep running).
## Particle colors are sRGB (03_ART F1, vfx_additive converts). Presentation jitter may use randf() (02_TECH §13.1).

const CONFETTI_COLORS: Array[Color] = [Color("#ff2e88"), Color("#ffc93c"), Color("#22d3ee"), Color("#2bd66b")]
const ICE: Color = Color("#7fd8ff")
const POISON: Color = Color("#7cc242")

var kind: StringName = &""
var life: float = 0.5
var loop: bool = false
var active: bool = false

var _t: float = 0.0
var _color: Color = Color.WHITE
var _emitters: Array[CPUParticles3D] = []
var _tinted: Array[bool] = []
var _delays: Array[float] = []
var _started: Array[bool] = []
var _fx: Array[Dictionary] = []      # {"node", "type", "base", ...}
var _jitter_t: float = 0.0


func setup(p_kind: StringName, p_life: float, p_loop: bool) -> void:
	kind = p_kind
	life = p_life
	loop = p_loop
	name = "Vfx_" + String(p_kind)
	visible = false
	set_process(false)
	match String(p_kind):
		"hit":
			_sparks(14, Color("#fff2c8"), true)
			_ring(1.2, true, false, 0.12)
		"crit":
			_sparks(14, Color("#fff2c8"), false)
			var stars := _emitter("Stars", 24, 0.4, 1, 0.12, 0.22, Palette.HYPE_GOLD, true)
			stars.spread = 180.0
			stars.initial_velocity_min = 2.5
			stars.initial_velocity_max = 5.0
			stars.gravity = Vector3(0, -3, 0)
			_ring(1.6, true, false, 0.12)
		"slash":
			for i in 3:
				var q := _quad("Slash%d" % i, Vector2(1.2, 0.12), 0, false, Palette.PAPER)
				q.position = Vector3(0.0, 0.25 - 0.25 * float(i), 0.0)
				q.rotation = Vector3(0, 0, deg_to_rad(-35.0 + 8.0 * float(i)))
				_fx.append({"node": q, "type": "slash", "delay": 0.03 * float(i), "tint": true, "shape": 0,
					"billboard": false})
		"bite":
			for row in 2:
				for k in 4:
					var b := _quad("Fang%d_%d" % [row, k], Vector2(0.18, 0.18), 3, true, Palette.PAPER)
					var y0: float = 0.28 if row == 0 else -0.28
					b.position = Vector3(-0.3 + 0.2 * float(k), y0, 0)
					b.rotation = Vector3(0, 0, PI if row == 0 else 0.0)
					_fx.append({"node": b, "type": "bite", "y0": y0, "tint": true, "shape": 3})
		"magic":
			_ring(1.5, false, true, 0.25)
			var dots := _emitter("Dots", 12, 0.6, 0, 0.08, 0.14, Palette.NOVA_CYAN, true)
			dots.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
			dots.emission_ring_axis = Vector3.UP
			dots.emission_ring_radius = 0.6
			dots.emission_ring_inner_radius = 0.5
			dots.emission_ring_height = 0.05
			dots.direction = Vector3.UP
			dots.spread = 10.0
			dots.initial_velocity_min = 1.0
			dots.initial_velocity_max = 2.0
			dots.gravity = Vector3.ZERO
			dots.explosiveness = 0.4
		"fire":
			var f := _emitter("Flames", 18, 0.6, 0, 0.15, 0.3, Color.WHITE, true)
			f.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			f.emission_sphere_radius = 0.3
			f.direction = Vector3.UP
			f.spread = 25.0
			f.initial_velocity_min = 1.5
			f.initial_velocity_max = 3.0
			f.gravity = Vector3(0, 0.5, 0)
			f.explosiveness = 0.7
			f.color_ramp = _ramp([Color("#ffe08a"), Color("#ff6a2b"), Color(0.478, 0.122, 0.122, 0.0)], [0.0, 0.45, 1.0])
		"ice":
			# review M4: thin bright frost ring (not a filled grey disc), white core flash, bigger shards
			var shards := _emitter("Shards", 12, 0.6, 0, 1.0, 1.0, Color.WHITE, false)
			var pm := PrismMesh.new()
			pm.size = Vector3(0.12, 0.35, 0.12)
			shards.mesh = pm
			shards.material_override = Materials.hologram(ICE, 0.9, 2.6)
			shards.spread = 180.0
			shards.direction = Vector3.UP
			shards.initial_velocity_min = 2.0
			shards.initial_velocity_max = 3.0
			shards.gravity = Vector3(0, -3.0, 0)
			shards.angular_velocity_min = -360.0
			shards.angular_velocity_max = 360.0
			var ring := _quad("FrostRing", Vector2(2.6, 2.6), 2, false, ICE)
			ring.material_override = Materials.vfx_additive_ex(ICE, 2, 0.35, 3.2, false)
			ring.rotation = Vector3(-PI * 0.5, 0, 0)
			ring.position = Vector3(0, 0.03, 0)
			_fx.append({"node": ring, "type": "grow", "max": 1.0, "grow": 0.25, "tint": false})
			var core := _quad("Core", Vector2(1.2, 1.2), 0, true, Color.WHITE)
			core.material_override = Materials.vfx_additive_ex(Color("#e6f8ff"), 0, 0.8, 3.0, true)
			core.position = Vector3(0, 0.6, 0)
			_fx.append({"node": core, "type": "flash", "time": 0.15, "tint": false})
		"shock":
			for b in 3:
				var bolt := Node3D.new()
				bolt.name = "Bolt%d" % b
				add_child(bolt)
				var segs: Array[MeshInstance3D] = []
				for k in 6:
					var mi := MeshInstance3D.new()
					mi.mesh = MeshUtil.box(Vector3(0.03, 0.3, 0.03))
					mi.material_override = Materials.glow(Color("#f5e642"), 4.0)
					mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					bolt.add_child(mi)
					segs.append(mi)
				_fx.append({"node": bolt, "type": "bolt", "segs": segs, "tint": false})
			var sp := _sparks(10, Color("#9fe8ff"), false)
			sp.position = Vector3(0, 0.2, 0)
		"toxic":
			# review M4: filled poison bubbles (0.10–0.18 m) at higher energy + 3 big "pop" bubbles near the end
			var bub := _emitter("Bubbles", 16, 1.0, 0, 0.10, 0.18, POISON, true)
			bub.material_override = Materials.vfx_additive_ex(Color.WHITE, 0, 0.35, 3.0)
			bub.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			bub.emission_sphere_radius = 0.4
			bub.direction = Vector3.UP
			bub.spread = 20.0
			bub.initial_velocity_min = 0.5
			bub.initial_velocity_max = 1.0
			bub.gravity = Vector3.ZERO
			bub.explosiveness = 0.6
			var pops := _emitter("Pops", 3, 0.35, 2, 0.26, 0.34, POISON, true, 0.6)
			pops.material_override = Materials.vfx_additive_ex(Color.WHITE, 2, 0.6, 3.5)
			pops.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			pops.emission_sphere_radius = 0.35
			pops.position = Vector3(0, 0.7, 0)
			pops.direction = Vector3.UP
			pops.spread = 30.0
			pops.initial_velocity_min = 0.2
			pops.initial_velocity_max = 0.4
			pops.gravity = Vector3.ZERO
		"light", "heal":
			var c: Color = Palette.PAPER if p_kind == &"light" else Color("#6bffb0")
			var st := _emitter("Stars", 20, 0.8, 1, 0.1, 0.2, c, true)
			st.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
			st.emission_ring_axis = Vector3.UP
			st.emission_ring_radius = 0.8 if p_kind == &"light" else 0.5
			st.emission_ring_inner_radius = 0.3
			st.emission_ring_height = 0.1
			st.direction = Vector3.UP
			st.spread = 5.0
			st.initial_velocity_min = 0.8
			st.initial_velocity_max = 1.4
			st.gravity = Vector3.ZERO
			st.tangential_accel_min = 3.0
			st.tangential_accel_max = 4.0
			st.explosiveness = 0.5
		"dark":
			var d := _emitter("Shadows", 20, 0.8, 0, 0.12, 0.22, Color("#7a5ad0"), true)
			d.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE_SURFACE
			d.emission_sphere_radius = 1.2
			d.initial_velocity_min = 0.0
			d.initial_velocity_max = 0.2
			d.radial_accel_min = -6.0
			d.radial_accel_max = -4.0
			d.gravity = Vector3.ZERO
			d.explosiveness = 0.6
		"buff", "debuff":
			var up: bool = p_kind == &"buff"
			for i in 2:
				var r := _quad("Ring%d" % i, Vector2(1.2, 1.2), 2, false, Palette.HYPE_GOLD if up else Color("#b05cff"))
				r.rotation = Vector3(-PI * 0.5, 0, 0)
				_fx.append({"node": r, "type": "rise", "from": 0.1 + 0.4 * float(i) if up else 1.6 - 0.4 * float(i),
					"dist": 1.2 if up else -1.2, "tint": true, "shape": 2, "billboard": false})
			var dd := _emitter("Dots", 10, 0.7, 0, 0.06, 0.12, Palette.HYPE_GOLD if up else Color("#b05cff"), true)
			dd.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
			dd.emission_ring_axis = Vector3.UP
			dd.emission_ring_radius = 0.5
			dd.emission_ring_inner_radius = 0.4
			dd.emission_ring_height = 0.05
			dd.direction = Vector3.UP if up else Vector3.DOWN
			dd.position = Vector3(0, 0.0 if up else 1.6, 0)
			dd.spread = 5.0
			dd.initial_velocity_min = 1.2
			dd.initial_velocity_max = 2.0
			dd.gravity = Vector3.ZERO
			dd.explosiveness = 0.3
		"ko":
			var ring2 := _quad("KoRing", Vector2(0.9, 0.9), 2, false, Palette.DANGER)
			ring2.rotation = Vector3(-PI * 0.5, 0, 0)
			_fx.append({"node": ring2, "type": "pulse", "tint": true, "shape": 2, "billboard": false})
			for i in 3:
				var star := _quad("Star%d" % i, Vector2(0.22, 0.22), 1, true, Palette.HYPE_GOLD)
				_fx.append({"node": star, "type": "orbit", "phase": TAU * float(i) / 3.0, "radius": 0.3, "tint": false})
		"levelup":
			var col := MeshInstance3D.new()
			col.name = "Column"
			col.mesh = MeshUtil.tube(0.6, 3.0, 16)
			col.material_override = Materials.hologram(Palette.HYPE_GOLD, 0.35, 1.6)
			col.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(col)
			_fx.append({"node": col, "type": "column", "tint": false})
			var ls := _emitter("Stars", 32, 1.2, 1, 0.1, 0.2, Palette.HYPE_GOLD, false)
			ls.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
			ls.emission_ring_axis = Vector3.UP
			ls.emission_ring_radius = 0.6
			ls.emission_ring_inner_radius = 0.2
			ls.emission_ring_height = 0.1
			ls.direction = Vector3.UP
			ls.spread = 15.0
			ls.initial_velocity_min = 1.5
			ls.initial_velocity_max = 3.0
			ls.gravity = Vector3.ZERO
			ls.explosiveness = 0.5
			var lbl := Label3D.new()
			lbl.name = "LevelUp"
			lbl.text = "LEVEL UP!"
			lbl.font_size = 72
			lbl.outline_size = 14
			lbl.pixel_size = 0.005
			lbl.modulate = Palette.sign_color(Palette.HYPE_GOLD)
			lbl.outline_modulate = Palette.INK
			lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			lbl.no_depth_test = true
			lbl.render_priority = 10
			add_child(lbl)
			_fx.append({"node": lbl, "type": "label_rise", "tint": false})
		"sponsor":
			_build_sponsor()
		"confetti":
			_confetti(40)
		"smoke":
			var sm := _emitter("Smoke", 10, 1.0, 0, 0.2, 0.3, Color(0.91, 0.91, 0.91, 0.4), false)
			sm.material_override = Materials.vfx_additive_ex(Color.WHITE, 0, 1.0, 0.9)
			sm.direction = Vector3.UP
			sm.spread = 15.0
			sm.initial_velocity_min = 1.0
			sm.initial_velocity_max = 1.4
			sm.gravity = Vector3.ZERO
			sm.explosiveness = 0.5
			var curve := Curve.new()
			curve.add_point(Vector2(0, 0.33))
			curve.add_point(Vector2(1, 1.0))
			sm.scale_amount_curve = curve
			sm.scale_amount_min = 0.55
			sm.scale_amount_max = 0.65
		"sparkle":
			var sk := _emitter("Sparkle", 8, 0.5, 1, 0.1, 0.18, Palette.PAPER, true)
			sk.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			sk.emission_sphere_radius = 0.3
			sk.spread = 180.0
			sk.initial_velocity_min = 0.5
			sk.initial_velocity_max = 1.0
			sk.gravity = Vector3.ZERO
		"stairs_glow":
			var g := _emitter("Motes", 12, 1.5, 0, 0.08, 0.16, Palette.HYPE_GOLD, true)
			g.one_shot = false
			g.explosiveness = 0.0
			g.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
			g.emission_ring_axis = Vector3.UP
			g.emission_ring_radius = 1.4
			g.emission_ring_inner_radius = 0.2
			g.emission_ring_height = 0.1
			g.direction = Vector3.UP
			g.spread = 3.0
			g.initial_velocity_min = 0.8
			g.initial_velocity_max = 1.5
			g.gravity = Vector3.ZERO
		_:
			# chest_open
			var cs := _emitter("Stars", 24, 0.8, 1, 0.1, 0.2, Palette.HYPE_GOLD, true)
			cs.direction = Vector3.UP
			cs.spread = 45.0
			cs.initial_velocity_min = 2.0
			cs.initial_velocity_max = 3.5
			cs.gravity = Vector3(0, -3.0, 0)
			_ring(1.0, true, false, 0.15)


## Restarts the effect with `color` (Color(0,0,0,0) = kind default) and uniform `scl`.
func play(color: Color, scl: float) -> void:
	_t = 0.0
	_jitter_t = 0.0
	active = true
	visible = true
	scale = Vector3.ONE * maxf(scl, 0.05)
	_color = color
	for i in _emitters.size():
		var p: CPUParticles3D = _emitters[i]
		p.speed_scale = 1.0
		if _tinted[i] and color.a > 0.0:
			p.color = color
		_started[i] = false
		if _delays[i] <= 0.0:
			_start(i)
		else:
			p.emitting = false
	for fx: Dictionary in _fx:
		var n: Node3D = fx["node"]
		if bool(fx.get("tint", false)) and color.a > 0.0 and n is MeshInstance3D:
			var shape: int = int(fx.get("shape", 0))
			(n as MeshInstance3D).material_override = Materials.vfx_additive_ex(color, shape, 0.5, 2.0,
				bool(fx.get("billboard", true)))
		n.visible = true
	if kind == &"slash" or kind == &"bite":
		_face_camera()
	_animate(0.0)
	set_process(true)


## Holds the current frame (galleries / screenshots): particles and helper animations pause, the effect stays visible.
func freeze() -> void:
	active = false
	for p: CPUParticles3D in _emitters:
		p.speed_scale = 0.0
	set_process(false)


func progress() -> float:
	return _t / maxf(life, 0.001)


func stop() -> void:
	active = false
	visible = false
	for p: CPUParticles3D in _emitters:
		p.emitting = false
	set_process(false)


func _start(i: int) -> void:
	var p: CPUParticles3D = _emitters[i]
	p.emitting = true
	p.restart()
	_started[i] = true


func _process(delta: float) -> void:
	if not active:
		return
	_t += delta
	for i in _emitters.size():
		if not _started[i] and _t >= _delays[i]:
			_start(i)
	_animate(delta)
	if not loop and _t >= life:
		stop()


func _face_camera() -> void:
	if not is_inside_tree():
		return
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return
	var to_cam: Vector3 = cam.global_position - global_position
	to_cam.y = 0.0
	if to_cam.length_squared() > 0.0001:
		global_rotation = Vector3(0, atan2(to_cam.x, to_cam.z), 0)


# --- builders ---------------------------------------------------------------------------------------------------------

func _emitter(node_name: String, amount: int, lifetime: float, shape: int, size_min: float, size_max: float,
		color: Color,
		tint: bool, delay: float = 0.0) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = node_name
	p.amount = amount
	p.lifetime = lifetime
	p.one_shot = true
	p.explosiveness = 1.0
	p.emitting = false
	p.local_coords = true
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	p.mesh = q
	p.material_override = Materials.vfx_additive_ex(Color.WHITE, shape, 0.5, 2.0)
	p.scale_amount_min = size_min
	p.scale_amount_max = size_max
	p.color = color
	p.color_ramp = _ramp([Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)], [0.0, 0.6, 1.0])
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	_emitters.append(p)
	_tinted.append(tint)
	_delays.append(delay)
	_started.append(false)
	return p


func _sparks(amount: int, color: Color, tint: bool) -> CPUParticles3D:
	var s := _emitter("Sparks", amount, 0.3, 3, 0.08, 0.16, color, tint)
	s.direction = Vector3.UP
	s.spread = 70.0
	s.initial_velocity_min = 4.0
	s.initial_velocity_max = 7.0
	s.gravity = Vector3(0, -6.0, 0)
	return s


func _quad(node_name: String, size: Vector2, shape: int, billboard: bool, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	mi.material_override = Materials.vfx_additive_ex(color, shape, 0.5, 2.0, billboard)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


## Expanding ring (shape 2). flat = lies on the ground, else camera-facing.
func _ring(max_size: float, billboard: bool, flat: bool, grow_time: float) -> void:
	var r := _quad("Ring", Vector2(1, 1), 2, billboard and not flat, Palette.PAPER)
	if flat:
		r.rotation = Vector3(-PI * 0.5, 0, 0)
		r.position = Vector3(0, 0.03, 0)
	_fx.append({"node": r, "type": "grow", "max": max_size, "grow": grow_time, "tint": true, "shape": 2,
		"billboard": billboard and not flat})


func _confetti(amount: int) -> CPUParticles3D:
	var c := _emitter("Confetti", amount, 1.2, 0, 1.0, 1.0, Color.WHITE, false)
	c.mesh = MeshUtil.box(Vector3(0.04, 0.04, 0.04))
	c.material_override = Materials.toon_vc({"outline": false, "rim": 0.3})
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	g.colors = PackedColorArray(CONFETTI_COLORS)
	g.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75])
	c.color_initial_ramp = g
	c.color_ramp = null
	c.direction = Vector3.UP
	c.spread = 60.0
	c.initial_velocity_min = 3.0
	c.initial_velocity_max = 5.0
	c.gravity = Vector3(0, -4.0, 0)
	c.angular_velocity_min = 200.0
	c.angular_velocity_max = 400.0
	c.scale_amount_min = 1.0
	c.scale_amount_max = 1.6
	c.particle_flag_rotate_y = true
	return c


## Sponsor drop (03_ART §7.2): drone flies in with a parcel, the parcel floats down on a parachute, confetti + holo
## flash.
func _build_sponsor() -> void:
	var drone: Node3D = PropKit.build(&"camera_drone", 1)
	drone.name = "Drone"
	add_child(drone)
	_fx.append({"node": drone, "type": "drone", "tint": false})
	var parcel := Node3D.new()
	parcel.name = "Parcel"
	add_child(parcel)
	var box := MeshInstance3D.new()
	box.name = "Box"
	box.mesh = MeshUtil.box(Vector3(0.4, 0.4, 0.4))
	box.material_override = Materials.toon(Palette.NOVA_MAGENTA, {"bands": 3, "rim": 0.45, "outline_width": 0.02})
	parcel.add_child(box)
	for rot: float in [0.0, 90.0]:
		var band := MeshInstance3D.new()
		band.mesh = MeshUtil.box(Vector3(0.42, 0.42, 0.08))
		band.rotation_degrees = Vector3(0, rot, 0)
		band.material_override = Materials.toon(Palette.PAPER, {"bands": 3, "rim": 0.3, "outline": false})
		parcel.add_child(band)
	var chute := MeshInstance3D.new()
	chute.name = "Chute"
	chute.mesh = MeshUtil.hemisphere(0.4)
	chute.position = Vector3(0, 0.75, 0)
	chute.material_override = Materials.toon(Palette.PAPER, {"bands": 3, "rim": 0.45, "outline_width": 0.02})
	parcel.add_child(chute)
	for k in 4:
		var a: float = TAU * float(k) / 4.0 + PI * 0.25
		var line := MeshInstance3D.new()
		line.mesh = MeshUtil.cylinder(0.008, 0.008, 0.6)
		line.position = Vector3(cos(a) * 0.17, 0.48, sin(a) * 0.17)
		line.rotation = Vector3(sin(a) * 0.35, 0, -cos(a) * 0.35)
		line.material_override = Materials.toon(Palette.INK, {"outline": false, "rim": 0.0})
		parcel.add_child(line)
	_fx.append({"node": parcel, "type": "parcel", "tint": false, "box": box})
	var conf := _confetti(40)
	_delays[_delays.size() - 1] = 1.1
	conf.position = Vector3(0, 0.3, 0)
	var holo := _quad("Holo", Vector2(1.6, 0.7), 0, true, Palette.NOVA_MAGENTA)
	holo.position = Vector3(0, 1.4, 0)
	_fx.append({"node": holo, "type": "holo", "tint": true})


static func _ramp(colors: Array, offsets: Array) -> Gradient:
	var g := Gradient.new()
	var pc := PackedColorArray()
	for c: Variant in colors:
		pc.append(c as Color)
	var po := PackedFloat32Array()
	for o: Variant in offsets:
		po.append(float(o))
	g.colors = pc
	g.offsets = po
	return g


# --- per-frame animation of helper meshes ----------------------------------------------------------------------------

func _animate(delta: float) -> void:
	var u: float = clampf(_t / maxf(life, 0.001), 0.0, 1.0)
	_jitter_t -= delta
	var rejitter: bool = _jitter_t <= 0.0
	if rejitter:
		_jitter_t = 0.05
	for fx: Dictionary in _fx:
		var n: Node3D = fx["node"]
		match str(fx["type"]):
			"grow":
				var g: float = clampf(_t / float(fx.get("grow", 0.15)), 0.0, 1.0)
				var s: float = float(fx.get("max", 1.0)) * (1.0 - pow(1.0 - g, 3.0))
				var fade: float = 1.0 - smoothstep(0.6, 1.0, u)
				n.scale = Vector3(s, s, s) * maxf(fade, 0.001)
			"slash":
				var d: float = float(fx.get("delay", 0.0))
				var a: float = clampf((_t - d) / 0.1, 0.0, 1.0)
				var out: float = clampf((_t - d - 0.12) / 0.15, 0.0, 1.0)
				n.scale = Vector3(maxf(a, 0.01), maxf(1.0 - out, 0.01), 1.0)
				n.visible = _t >= d
			"bite":
				var y0: float = float(fx["y0"])
				var close: float = clampf(_t / 0.12, 0.0, 1.0)
				n.position.y = lerpf(y0, signf(y0) * 0.04, close * close)
				var sb: float = 1.0 - smoothstep(0.6, 1.0, u)
				n.scale = Vector3.ONE * maxf(sb, 0.01)
			"rise":
				n.position.y = float(fx["from"]) + float(fx["dist"]) * u
				var sr: float = lerpf(1.2, 0.7, u) * (1.0 - smoothstep(0.75, 1.0, u))
				n.scale = Vector3.ONE * maxf(sr, 0.01)
			"pulse":
				var sp: float = 1.0 + 0.15 * sin(_t * 12.0)
				n.scale = Vector3.ONE * sp * (1.0 - smoothstep(0.8, 1.0, u))
			"orbit":
				var ph: float = float(fx["phase"]) + _t * 4.0
				var rad: float = float(fx["radius"])
				n.position = Vector3(cos(ph) * rad, 0.05 * sin(ph * 2.0), sin(ph) * rad)
				n.scale = Vector3.ONE * (1.0 - smoothstep(0.8, 1.0, u))
			"column":
				var cy: float = clampf(_t / 0.25, 0.0, 1.0)
				var back: float = 1.0 + 0.1 * sin(cy * PI)
				var cf: float = 1.0 - smoothstep(0.7, 1.0, u)
				n.scale = Vector3(cf, maxf(cy * back, 0.01), cf)
				n.position.y = 1.5 * cy * back
			"label_rise":
				n.position.y = 2.2 + 0.6 * (1.0 - pow(1.0 - u, 2.0))
				var ls: float = minf(_t / 0.12, 1.0)
				n.scale = Vector3.ONE * (0.4 + 0.6 * ls)
				(n as Label3D).modulate.a = 1.0 - smoothstep(0.8, 1.0, u)
			"bolt":
				if rejitter:
					var segs: Array = fx["segs"]
					var p := Vector3(randf_range(-0.15, 0.15), 1.6, randf_range(-0.1, 0.1))
					for mi: Variant in segs:
						var q := p + Vector3(randf_range(-0.18, 0.18), -0.27, randf_range(-0.08, 0.08))
						var m3: MeshInstance3D = mi
						m3.transform = Transform3D(Basis(Quaternion(Vector3.UP, (p - q).normalized())), (p + q) * 0.5)
						p = q
				n.visible = u < 0.95
			"drone":
				var start := Vector3(8, 6, 4)
				var hover := Vector3(0, 3, 1)
				var ctrl := Vector3(4, 7, 4)
				if _t < 0.6:
					var k: float = _t / 0.6
					n.position = start.lerp(ctrl, k).lerp(ctrl.lerp(hover, k), k)
				elif _t < 1.1:
					n.position = hover + Vector3(0, 0.05 * sin(_t * 10.0), 0)
				else:
					var k2: float = clampf((_t - 1.1) / 0.4, 0.0, 1.0)
					n.position = hover.lerp(Vector3(-6, 7, -2), k2 * k2)
				n.visible = u < 0.98
			"parcel":
				var box: MeshInstance3D = fx["box"]
				if _color.a > 0.0 and delta == 0.0:
					box.material_override = Materials.toon(_color, {"bands": 3, "rim": 0.45, "outline_width": 0.02})
				if _t < 0.6:
					var k3: float = _t / 0.6
					var st := Vector3(8, 6, 4)
					var ct := Vector3(4, 7, 4)
					var hv := Vector3(0, 3, 1)
					n.position = st.lerp(ct, k3).lerp(ct.lerp(hv, k3), k3) + Vector3(0, -0.45, 0)
				elif _t < 1.1:
					var k4: float = (_t - 0.6) / 0.5
					n.position = Vector3(0, 2.55, 1).lerp(Vector3(0, 0.2, 0), k4)
				else:
					n.position = Vector3(0, 0.2, 0)
				n.visible = u < 0.98
			"flash":
				var ft: float = float(fx.get("time", 0.15))
				var fk: float = clampf(_t / ft, 0.0, 1.0)
				n.visible = _t < ft
				n.scale = Vector3.ONE * maxf((0.6 + 0.6 * fk) * (1.0 - fk), 0.01)
			"holo":
				var hk: float = clampf((_t - 1.1) / 0.15, 0.0, 1.0)
				n.visible = _t >= 1.1
				n.scale = Vector3.ONE * maxf(hk * (1.0 - smoothstep(0.85, 1.0, u)), 0.01)
