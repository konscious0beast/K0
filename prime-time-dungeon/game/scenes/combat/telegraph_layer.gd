extends Node3D
## TelegraphLayer (07 §6.3, §8.7; R2): announced ground shapes and lingering zones of the running combat as flat quads
## with ONE shared ShaderMaterial (art/shaders/rt_telegraph.gdshader): a pool of MAX_TELEGRAPHS (10) MeshInstance3D +
## QuadMesh (FACE_Y), per quad only the instance uniforms tg_params / tg_color / tg_pulse / tg_stripe_speed, per set the
## material uniforms set_center / set_radius (everything is clipped at the LED ring) and `contrast` (07 §7.6). Every
## quad and the material cost one draw call / one material (07 Anhang A13). Private helper of scenes/combat (no
## class_name); the CombatDirector feeds it the combat events and calls update() every frame.
##
## Event-driven (07 §3.13): TELEGRAPH_START (rt = {shape, x, z, yaw, r, r2, half, start, impact}) shows a telegraph,
## TELEGRAPH_IMPACT flashes it white for 0.15 s and frees its quad, TELEGRAPH_CANCELLED frees it at once; ZONE_START (rt
## = geometry + end) shows a zone in the colour of its status / element (α 0.35, slower stripes, fades out in its last
## second), ZONE_END frees it. Geometry is room-local cm (07 §3.2): world = origin + (x / 100, 0.04, z / 100), yaw u8 →
## rotation.y = yaw × τ / 256. Quad sizes: circle / ring / cone 2r × 2r around the centre / apex, line W × L with the
## start at its back edge (fills towards the end).

const SHADER: Shader = preload("res://art/shaders/rt_telegraph.gdshader")
const POOL_SIZE: int = 10                     # MAX_TELEGRAPHS (telegraphs + zones)
const Y: float = 0.04                         # above the LED ring (0.035) and every floor mark
const RENDER_PRIORITY: int = 1                # in front of other transparent floor quads
const C_DANGER: Color = Color("#ff4d4d")      # enemy telegraphs (07 §8.7)
const C_FRIENDLY: Color = Color("#22d3ee")    # friendly floor marks (C_ACCENT_2), presentation only
const C_FIRE: Color = Color("#ff7a1a")
const C_POISON: Color = Color("#7cc242")
const ZONE_ALPHA: float = 0.35
const ZONE_STRIPES: float = 0.2               # zones: slower stripes (telegraphs 0.6)
const STRIPES: float = 0.6
const FLASH_SEC: float = 0.15                 # impact: white flash
const PULSE_SEC: float = 0.3                  # the edge pulses in the last 0.3 s
const ZONE_FADE_SEC: float = 1.0              # zones fade out in their last second
const TICKS_PER_SEC: float = 30.0
enum Shape { CIRCLE, CONE, RING, LINE }       # == RtTelegraph.Shape

var origin: Vector3 = Vector3.ZERO           # world position of the set cell centre (room-local 0, 0)
var material: ShaderMaterial = null
var quads: Array[MeshInstance3D] = []

var _active: Dictionary = {}                 # key ("t<id>" | "z<id>") → entry (see _show)
var _order: Array[String] = []               # keys in creation order (oldest zone gives way first)
var _flashes: Array[Dictionary] = []         # {"q": MeshInstance3D, "left": float}


func _init() -> void:
	name = "TelegraphLayer"
	material = ShaderMaterial.new()
	material.shader = SHADER
	material.render_priority = RENDER_PRIORITY
	for i in POOL_SIZE:
		var q: MeshInstance3D = MeshInstance3D.new()
		q.name = "Quad%d" % i
		var m: QuadMesh = QuadMesh.new()
		m.orientation = PlaneMesh.FACE_Y
		m.size = Vector2.ONE
		q.mesh = m
		q.material_override = material
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		q.visible = false
		add_child(q)
		quads.append(q)


## A new combat: the set centre (world) and radius (m) clip every quad; `contrast` = GameSettings.telegraph_contrast.
func setup(set_origin: Vector3, set_radius_m: float, high_contrast: bool = false) -> void:
	origin = set_origin
	material.set_shader_parameter(&"set_center", Vector2(set_origin.x, set_origin.z))
	material.set_shader_parameter(&"set_radius", set_radius_m)
	material.set_shader_parameter(&"contrast", 1.0 if high_contrast else 0.0)
	clear()


func set_contrast(high: bool) -> void:
	material.set_shader_parameter(&"contrast", 1.0 if high else 0.0)


## Frees every quad (combat end).
func clear() -> void:
	_active.clear()
	_order.clear()
	_flashes.clear()
	for q: MeshInstance3D in quads:
		q.visible = false


## Shown telegraphs + zones (flashing quads not counted).
func active_count() -> int:
	return _active.size()


## Visible quads (including impact flashes).
func visible_quads() -> int:
	var n: int = 0
	for q: MeshInstance3D in quads:
		n += 1 if q.visible else 0
	return n


## True when a shown telegraph impacts exactly at combat tick `ct` (MoveSampler: forced sample, 07 §3.5.1).
func impacts_at(ct: int) -> bool:
	for k: String in _order:
		var e: Dictionary = _active[k]
		if not bool(e["zone"]) and int(e["impact"]) == ct:
			return true
	return false


## The quad of telegraph `id` (zone: `zone` true); null if not shown.
func quad_of(id: int, zone: bool = false) -> MeshInstance3D:
	var e: Dictionary = _active.get(("z%d" if zone else "t%d") % id, {})
	return e.get("q", null) as MeshInstance3D


## Combat event (Events.combat_event): telegraph / zone bookkeeping.
func on_event(e: ActionEvent) -> void:
	match e.type:
		ActionEvent.Type.TELEGRAPH_START:
			_show("t%d" % e.value, e.rt, false, C_DANGER, e.tick)
		ActionEvent.Type.TELEGRAPH_IMPACT:
			_release("t%d" % e.value, true)
		ActionEvent.Type.TELEGRAPH_CANCELLED:
			_release("t%d" % e.value, false)
		ActionEvent.Type.ZONE_START:
			_show("z%d" % e.value, e.rt, true, zone_color(e.status_id, e.skill_id), e.tick)
		ActionEvent.Type.ZONE_END:
			_release("z%d" % e.value, false)


## Per frame: `ct_f` = the combat time in ticks (processed ticks + fraction of the next one).
func update(ct_f: float, delta: float) -> void:
	for k: String in _order:
		var e: Dictionary = _active[k]
		var q: MeshInstance3D = e["q"]
		if bool(e["zone"]):
			var end: int = int(e["end"])
			var a: float = ZONE_ALPHA
			if end > 0:
				var left: float = (float(end) - ct_f) / TICKS_PER_SEC
				a *= clampf(left / ZONE_FADE_SEC, 0.0, 1.0)
			var c: Color = e["color"]
			q.set_instance_shader_parameter(&"tg_color", Color(c.r, c.g, c.b, a))
			q.set_instance_shader_parameter(&"tg_params", _params(e, 1.0))
			continue
		var start: int = int(e["start"])
		var impact: int = int(e["impact"])
		var prog: float = clampf((ct_f - start) / maxf(1.0, float(impact - start)), 0.0, 1.0)
		q.set_instance_shader_parameter(&"tg_params", _params(e, prog))
		var left_s: float = (float(impact) - ct_f) / TICKS_PER_SEC
		q.set_instance_shader_parameter(&"tg_pulse", 1.0 if left_s <= PULSE_SEC else 0.0)
	var i: int = _flashes.size() - 1
	while i >= 0:
		var f: Dictionary = _flashes[i]
		f["left"] = float(f["left"]) - delta
		var fq: MeshInstance3D = f["q"]
		if float(f["left"]) <= 0.0 or not _quad_free_for_flash(fq):
			if _quad_free_for_flash(fq):
				fq.visible = false
			_flashes.remove_at(i)
		else:
			fq.set_instance_shader_parameter(&"tg_color", Color(1.0, 1.0, 1.0, clampf(float(f["left"]) / FLASH_SEC,
				0.0, 1.0)))
		i -= 1


## Zone colour: status colour (poison) or element colour (fire), else DANGER.
static func zone_color(status_id: String, skill_id: String) -> Color:
	if status_id == "sts_poison":
		return C_POISON
	if status_id == "sts_burn" or skill_id.contains("fire") or skill_id.contains("flame"):
		return C_FIRE
	if Palette.STATUS_COLORS.has(status_id):
		return Color(str(Palette.STATUS_COLORS[status_id]))
	return C_DANGER


## World transform + quad size of a telegraph geometry (room-local cm), for tests and placement.
func placement(rt: Dictionary) -> Dictionary:
	var shape: int = int(rt.get("shape", 0))
	var x: float = float(int(rt.get("x", 0))) / 100.0
	var z: float = float(int(rt.get("z", 0))) / 100.0
	var r: float = float(int(rt.get("r", 0))) / 100.0
	var r2: float = float(int(rt.get("r2", 0))) / 100.0
	var rot: float = float(int(rt.get("yaw", 0))) * TAU / 256.0
	var fwd: Vector3 = Vector3(-sin(rot), 0.0, -cos(rot))
	var pos: Vector3 = origin + Vector3(x, Y, z)
	var size: Vector2 = Vector2(2.0 * r, 2.0 * r)
	if shape == Shape.LINE:
		size = Vector2(r2, r)                            # width × length
		pos += fwd * (r * 0.5)
	elif shape != Shape.CONE:
		rot = 0.0
	return {"pos": pos, "rot": rot, "size": size}


# --- private ----------------------------------------------------------------------------------------------------------

func _show(key: String, rt: Dictionary, zone: bool, color: Color, tick: int) -> void:
	if _active.has(key):
		_release(key, false)
	var q: MeshInstance3D = _free_quad()
	if q == null:
		return
	var place: Dictionary = placement(rt)
	(q.mesh as QuadMesh).size = place["size"]
	q.transform = Transform3D(Basis(Vector3.UP, float(place["rot"])), place["pos"])
	var shape: int = int(rt.get("shape", 0))
	var r: float = maxf(1.0, float(int(rt.get("r", 1))))
	var e: Dictionary = {"q": q, "zone": zone, "shape": shape, "inner": clampf(float(int(rt.get("r2", 0))) / r, 0.0,
		0.99) if shape == Shape.RING else 0.0, "cos_half": cos(deg_to_rad(float(int(rt.get("half", 45))))),
		"start": int(rt.get("start", tick)), "impact": int(rt.get("impact", tick)), "end": int(rt.get("end", -1)),
		"color": color}
	_active[key] = e
	_order.append(key)
	q.set_instance_shader_parameter(&"tg_color", Color(color.r, color.g, color.b, ZONE_ALPHA if zone else 1.0))
	q.set_instance_shader_parameter(&"tg_stripe_speed", ZONE_STRIPES if zone else STRIPES)
	q.set_instance_shader_parameter(&"tg_pulse", 0.0)
	q.set_instance_shader_parameter(&"tg_params", _params(e, 1.0 if zone else 0.0))
	q.visible = true


func _params(e: Dictionary, prog: float) -> Vector4:
	var shape: int = int(e["shape"])
	return Vector4(float(shape), prog, float(e["inner"]), float(e["cos_half"]) if shape == Shape.CONE else -1.0)


func _release(key: String, flash: bool) -> void:
	if not _active.has(key):
		return
	var e: Dictionary = _active[key]
	_active.erase(key)
	_order.erase(key)
	var q: MeshInstance3D = e["q"]
	if flash and is_inside_tree():
		q.set_instance_shader_parameter(&"tg_params", _params(e, 1.0))
		q.set_instance_shader_parameter(&"tg_pulse", 0.0)
		q.set_instance_shader_parameter(&"tg_color", Color(1.0, 1.0, 1.0, 1.0))
		_flashes.append({"q": q, "left": FLASH_SEC})
	else:
		q.visible = false


## A pool quad: free first; else the oldest zone gives way (07 §6.3: the oldest zone ends early); else the oldest flash.
func _free_quad() -> MeshInstance3D:
	for q: MeshInstance3D in quads:
		if not q.visible:
			return q
	for k: String in _order:
		if bool((_active[k] as Dictionary)["zone"]):
			var q2: MeshInstance3D = (_active[k] as Dictionary)["q"]
			_release(k, false)
			return q2
	if not _flashes.is_empty():
		var q3: MeshInstance3D = _flashes[0]["q"]
		_flashes.remove_at(0)
		return q3
	return null


func _quad_free_for_flash(q: MeshInstance3D) -> bool:
	for k: String in _order:
		if (_active[k] as Dictionary)["q"] == q:
			return false
	return true
