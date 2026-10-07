extends Node3D
## Render regression probe (03_ART §11, request A11): checks the outline hull direction (F6) and the particle/MultiMesh
## color space (F1) in the running renderer. Runs under check.sh --shot (headless has no pixels → skipped).
## Black background, camera (0, 1, 6), sun (−55, 35, 0); sphere with outline (magenta, 0.1) at x −1.6, plain sphere at
## x +1.6, a vfx_additive MultiMesh quad (instance color 0.5) at (0, 2.6, 0). After 15 frames: widest row of non-black
## pixels per half (outline must be ≥ 6 px wider) and the brightest pixel of the center column (0x80 ± 4).
## The probe renders into its own 960 × 540 SubViewport (own world), so overlays of other modules never affect the
## pixels.
## A white `damage` number (Vfx.damage_number at (3, 2.7, 0), frozen after the pop) must reach ≥ 240 luminance in the
## upper right (03_ART §7.1: pure white; the AgX tonemapper caps Label3D text at ~205, see damage_number.gd).
## It also listens to the engine log: a "different indices" warning (instance uniforms of toon / toon_outline declared
## in
## a different order, 02_TECH §8.3/§11.5) only appears in a real renderer, so it fails here (ERROR line → check.sh).

const FRAMES: int = 15
const MIN_EXTRA_PX: int = 6
const VFX_TARGET: int = 128
const VFX_TOLERANCE: int = 4
const NUMBER_MIN_LUMA: float = 240.0
const NUMBER_AT := Vector3(3.0, 2.7, 0.0)
const LogSpy := preload("res://art/gallery/log_spy.gd")

var result: Dictionary = {}
var _frame: int = 0
var _done: bool = false
var _vp: SubViewport = null
var _spy: Logger = null
var _world: Node3D = null


func setup(_params: Dictionary) -> void:
	pass


func _enter_tree() -> void:
	if _spy == null:
		_spy = LogSpy.new()
		_spy.set("needles", PackedStringArray(["different indices"]))
		OS.add_logger(_spy)


func _exit_tree() -> void:
	if _spy != null:
		OS.remove_logger(_spy)
		_spy = null


func _ready() -> void:
	var container := SubViewportContainer.new()
	container.name = "ProbeView"
	container.stretch = false
	container.position = Vector2(160, 90)
	container.size = Vector2(960, 540)
	add_child(container)
	_vp = SubViewport.new()
	_vp.size = Vector2i(960, 540)
	_vp.own_world_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(_vp)
	var world := Node3D.new()
	world.name = "World"
	_vp.add_child(world)
	_world = world
	_build(world)
	Vfx.damage_number(world, NUMBER_AT, "88", &"damage")


func _build(world: Node3D) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.BLACK
	env.ambient_light_energy = 0.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.glow_enabled = false
	env.fog_enabled = false
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.shadow_enabled = false
	world.add_child(sun)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1, 6)
	world.add_child(cam)
	cam.current = true
	var parts: Array[Dictionary] = [{"mesh": MeshUtil.sphere(0.6), "xform": MeshUtil.xform(Vector3(0, 1, 0)),
		"color": Color("#e8b48f")}]
	var mesh: ArrayMesh = MeshUtil.merge(parts)
	for side: int in [-1, 1]:
		var mat := ShaderMaterial.new()
		mat.shader = load("res://art/shaders/toon.gdshader") as Shader
		mat.set_shader_parameter(&"use_vertex_color", true)
		if side < 0:
			var ol := ShaderMaterial.new()
			ol.shader = load("res://art/shaders/toon_outline.gdshader") as Shader
			ol.set_shader_parameter(&"outline_width", 0.1)
			ol.set_shader_parameter(&"outline_color", Color("#ff00ff"))
			mat.next_pass = ol
		var mi := MeshInstance3D.new()
		mi.name = "Outlined" if side < 0 else "Plain"
		mi.mesh = mesh
		mi.material_override = mat
		mi.position = Vector3(1.6 * float(side), 0, 0)
		world.add_child(mi)
		mi.set_instance_shader_parameter(&"flash_amount", 0.0)
		mi.set_instance_shader_parameter(&"dissolve", 0.0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var quad := QuadMesh.new()
	quad.size = Vector2(0.6, 0.6)
	mm.mesh = quad
	mm.instance_count = 1
	mm.set_instance_transform(0, Transform3D.IDENTITY)
	mm.set_instance_color(0, Color(0.5, 0.5, 0.5, 1.0))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "VfxProbe"
	mmi.multimesh = mm
	var vmat := ShaderMaterial.new()
	vmat.shader = load("res://art/shaders/vfx_additive.gdshader") as Shader
	vmat.set_shader_parameter(&"energy", 1.0)
	vmat.set_shader_parameter(&"softness", 0.01)
	vmat.set_shader_parameter(&"color", Color.WHITE)
	mmi.material_override = vmat
	mmi.position = Vector3(0, 2.6, 0)
	world.add_child(mmi)


func _process(_delta: float) -> void:
	if _done:
		return
	_freeze_numbers()
	_frame += 1
	if _frame < FRAMES:
		return
	_done = true
	if DisplayServer.get_name() == "headless":
		print("RENDER_PROBE: skipped (headless, no pixels)")
		return
	await RenderingServer.frame_post_draw
	var img: Image = _vp.get_texture().get_image()
	if img == null or img.is_empty():
		push_error("RENDER_PROBE: no image (res://art/gallery/render_probe.gd)")
		return
	_measure(img)


func _measure(img: Image) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var half: int = w / 2
	var w_outline: int = 0
	var w_plain: int = 0
	for y in range(int(h * 0.35), h):
		var left: int = _row_width(img, y, 0, half)
		var right: int = _row_width(img, y, half, w)
		w_outline = maxi(w_outline, left)
		w_plain = maxi(w_plain, right)
	var vfx: int = 0
	var cx: int = w / 2
	for y in range(0, int(h * 0.35)):
		for dx in range(-2, 3):
			var c: Color = img.get_pixel(clampi(cx + dx, 0, w - 1), y)
			vfx = maxi(vfx, roundi(maxf(c.r, maxf(c.g, c.b)) * 255.0))
	var luma: float = _number_luma(img)
	result = {"w_outline": w_outline, "w_plain": w_plain, "vfx": vfx, "number_luma": luma}
	var ok: bool = true
	if luma < NUMBER_MIN_LUMA:
		push_error("RENDER_PROBE: damage number too dull (luma %.0f < %.0f) (res://art/kit/damage_number.gd)"
			% [luma, NUMBER_MIN_LUMA])
		ok = false
	var indices: PackedStringArray = _spy.call("found") if _spy != null else PackedStringArray()
	if not indices.is_empty():
		push_error("RENDER_PROBE: FAIL different indices (%s) (res://art/shaders/toon_outline.gdshader)" % indices[0])
		ok = false
	if w_outline < w_plain + MIN_EXTRA_PX:
		push_error("RENDER_PROBE: outline not visible (w_outline %d, w_plain %d) (res://art/shaders/toon_outline.gdshader)"
			% [w_outline, w_plain])
		ok = false
	if absi(vfx - VFX_TARGET) > VFX_TOLERANCE:
		push_error(("RENDER_PROBE: particle color space off (center %d, expected %d ± %d) "
			+ "(res://art/shaders/vfx_additive.gdshader)") % [vfx, VFX_TARGET, VFX_TOLERANCE])
		ok = false
	if ok:
		print("RENDER_PROBE: OK w_outline=%d w_plain=%d vfx=%d number_luma=%.0f" % [w_outline, w_plain, vfx, luma])


## Holds the probe's damage number once the pop is over (frame-rate independent still).
func _freeze_numbers() -> void:
	if _world == null:
		return
	for n: Variant in (_world.get_meta(Vfx.DMG_META, []) as Array):
		var l: Node = n
		if is_instance_valid(l) and bool(l.get("active")) and float(l.get("_t")) >= 0.2:
			l.call("freeze")


## Brightest luminance (0..255) in the upper right region where the damage number floats.
static func _number_luma(img: Image) -> float:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var best: float = 0.0
	for y in range(0, int(h * 0.35)):
		for x in range(int(w * 0.55), int(w * 0.85)):
			var c: Color = img.get_pixel(x, y)
			best = maxf(best, (0.299 * c.r + 0.587 * c.g + 0.114 * c.b) * 255.0)
	return best


static func _row_width(img: Image, y: int, x0: int, x1: int) -> int:
	var first: int = -1
	var last: int = -1
	for x in range(x0, x1):
		var c: Color = img.get_pixel(x, y)
		if c.r + c.g + c.b > 0.03:
			if first < 0:
				first = x
			last = x
	return 0 if first < 0 else last - first + 1
