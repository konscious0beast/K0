extends Node3D
## Render regression probe (03_ART §11, request A11): checks the outline hull direction (F6) and the particle/MultiMesh
## color space (F1) in the running renderer. Runs under check.sh --shot (headless has no pixels → skipped).
## Black background, camera (0, 1, 6), sun (−55, 35, 0); sphere with outline (magenta, 0.1) at x −1.6, plain sphere at
## x +1.6, a vfx_additive MultiMesh quad (instance color 0.5) at (0, 2.6, 0). After 15 frames: widest row of non-black
## pixels per half (outline must be ≥ 6 px wider) and the brightest pixel of the center column (0x80 ± 4).
## The probe renders into its own 960 × 540 SubViewport (own world), so overlays of other modules never affect the pixels.

const FRAMES: int = 15
const MIN_EXTRA_PX: int = 6
const VFX_TARGET: int = 128
const VFX_TOLERANCE: int = 4

var result: Dictionary = {}
var _frame: int = 0
var _done: bool = false
var _vp: SubViewport = null


func setup(_params: Dictionary) -> void:
	pass


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
	_build(world)


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
	result = {"w_outline": w_outline, "w_plain": w_plain, "vfx": vfx}
	var ok: bool = true
	if w_outline < w_plain + MIN_EXTRA_PX:
		push_error("RENDER_PROBE: outline not visible (w_outline %d, w_plain %d) (res://art/shaders/toon_outline.gdshader)"
			% [w_outline, w_plain])
		ok = false
	if absi(vfx - VFX_TARGET) > VFX_TOLERANCE:
		push_error("RENDER_PROBE: particle color space off (center %d, expected %d ± %d) (res://art/shaders/vfx_additive.gdshader)"
			% [vfx, VFX_TARGET, VFX_TOLERANCE])
		ok = false
	if ok:
		print("RENDER_PROBE: OK w_outline=%d w_plain=%d vfx=%d" % [w_outline, w_plain, vfx])


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
