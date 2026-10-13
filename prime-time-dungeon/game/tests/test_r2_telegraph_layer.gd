extends TestCase
## TelegraphLayer (07 §6.3, §8.7, R2): a pool of at most MAX_TELEGRAPHS (10) quads with ONE shared ShaderMaterial,
## the instance uniforms per shape (circle / cone / ring / line), the fill progress up to the impact and the edge
## pulse in the last 0.3 s, the set uniforms that clip every quad at the LED ring, the colours (DANGER, zone colours
## with α 0.35 fading in their last second) and the contrast mode (07 §7.6), the impact flash and the pool rules.

const TelegraphLayer := preload("res://scenes/combat/telegraph_layer.gd")
const SHADER_PATH: String = "res://art/shaders/rt_telegraph.gdshader"
const ORIGIN: Vector3 = Vector3(12.0, 0.0, -36.0)
const T := ActionEvent.Type


func _layer() -> Node3D:
	var l: Node3D = TelegraphLayer.new()
	add_to_tree(l)
	l.call("setup", ORIGIN, 4.8, false)
	return l


func _tele(id: int, shape: int, x: int, z: int, yaw: int, r: int, r2: int, start: int, impact: int,
		half: int = 45) -> ActionEvent:
	var e: ActionEvent = ActionEvent.make(T.TELEGRAPH_START)
	e.value = id
	e.tick = start
	e.actor_id = "e0"
	e.rt = {"shape": shape, "x": x, "z": z, "yaw": yaw, "r": r, "r2": r2, "half": half, "start": start,
		"impact": impact}
	return e


func _zone(id: int, status: String, x: int, z: int, r: int, start: int, end: int) -> ActionEvent:
	var e: ActionEvent = ActionEvent.make(T.ZONE_START)
	e.value = id
	e.tick = start
	e.status_id = status
	e.rt = {"shape": 0, "x": x, "z": z, "r": r, "end": end}
	return e


func _ev(type: ActionEvent.Type, id: int) -> ActionEvent:
	var e: ActionEvent = ActionEvent.make(type)
	e.value = id
	return e


static func _param(q: MeshInstance3D, name: StringName) -> Variant:
	return q.get_instance_shader_parameter(name)


func test_pool_of_ten_quads_with_one_material() -> void:
	var l: Node3D = _layer()
	var quads: Array = l.get("quads")
	assert_len(quads, 10, "MAX_TELEGRAPHS quads")
	var mat: Material = l.get("material")
	assert_not_null(mat)
	assert_eq((mat as ShaderMaterial).shader.resource_path, SHADER_PATH)
	assert_eq(mat.render_priority, 1, "sorted in front of other transparent floor quads")
	for q: MeshInstance3D in quads:
		assert_true(q.material_override == mat, "one shared material")
		assert_eq(q.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		assert_false(q.visible, "the pool starts hidden")
		assert_eq((q.mesh as QuadMesh).orientation, PlaneMesh.FACE_Y, "flat on the floor")
	for i in 14:
		l.call("on_event", _tele(i + 1, 0, 0, 0, 0, 100, 0, 0, 60))
	assert_eq(int(l.call("visible_quads")), 10, "never more than 10 quads")
	assert_eq(int(l.call("active_count")), 10)


func test_set_uniforms_clip_at_the_ring_and_contrast() -> void:
	var l: Node3D = _layer()
	var mat: ShaderMaterial = l.get("material")
	assert_eq(mat.get_shader_parameter(&"set_center"), Vector2(12.0, -36.0), "world XZ of the set centre")
	assert_almost(float(mat.get_shader_parameter(&"set_radius")), 4.8, 0.0001)
	assert_almost(float(mat.get_shader_parameter(&"contrast")), 0.0, 0.0001)
	l.call("setup", Vector3(-6.0, 0.0, 6.0), 6.0, true)
	assert_eq(mat.get_shader_parameter(&"set_center"), Vector2(-6.0, 6.0))
	assert_almost(float(mat.get_shader_parameter(&"set_radius")), 6.0, 0.0001, "boss set 600 cm")
	assert_almost(float(mat.get_shader_parameter(&"contrast")), 1.0, 0.0001, "telegraph_contrast = high")
	l.call("set_contrast", false)
	assert_almost(float(mat.get_shader_parameter(&"contrast")), 0.0, 0.0001)
	# the clipping is the shader's (07 §8.7 / A13): distance to set_center against set_radius
	var src: String = FileAccess.get_file_as_string(SHADER_PATH)
	assert_true(src.contains("step(distance(world_xz, set_center), set_radius)"), "clipped at the ring")
	assert_true(src.contains("depth_draw_never") and src.contains("unshaded"), "render mode of 07 §8.7")


func test_instance_uniforms_and_placement_per_shape() -> void:
	var l: Node3D = _layer()
	# circle r 250 at (100, -50): 5 × 5 m around its centre
	l.call("on_event", _tele(1, 0, 100, -50, 0, 250, 0, 0, 60))
	var c: MeshInstance3D = l.call("quad_of", 1)
	assert_not_null(c)
	assert_eq((c.mesh as QuadMesh).size, Vector2(5.0, 5.0))
	assert_true(c.global_position.is_equal_approx(ORIGIN + Vector3(1.0, 0.04, -0.5)), "y 0.04 over the floor marks")
	assert_eq(_param(c, &"tg_params"), Vector4(0.0, 0.0, 0.0, -1.0))
	assert_eq(_param(c, &"tg_color"), Color("#ff4d4d"), "enemy telegraphs: DANGER")
	assert_almost(float(_param(c, &"tg_stripe_speed")), 0.6, 0.0001)
	# cone r 400, half 30°, yaw 64 (= +90°: facing −x): 8 × 8 m around the apex, turned with the yaw
	l.call("on_event", _tele(2, 1, 0, 0, 64, 400, 0, 0, 60, 30))
	var k: MeshInstance3D = l.call("quad_of", 2)
	assert_eq((k.mesh as QuadMesh).size, Vector2(8.0, 8.0))
	var kp: Vector4 = _param(k, &"tg_params")
	assert_almost(kp.x, 1.0, 0.0001)
	assert_almost(kp.w, cos(deg_to_rad(30.0)), 0.0001, "w = cos(half angle)")
	assert_almost(k.rotation.y, PI * 0.5, 0.0001)
	var fwd: Vector3 = -k.global_transform.basis.z
	assert_true(fwd.is_equal_approx(Vector3(-1.0, 0.0, 0.0)), "quad −Z (shader forward −V) = the cone's direction")
	# ring 380 / 200: inner ratio
	l.call("on_event", _tele(3, 2, 0, 0, 0, 380, 200, 0, 60))
	var r: MeshInstance3D = l.call("quad_of", 3)
	assert_almost((_param(r, &"tg_params") as Vector4).z, 200.0 / 380.0, 0.0001)
	assert_almost((_param(r, &"tg_params") as Vector4).x, 2.0, 0.0001)
	# line: width 300, length 960, from (-480, -330) along +x (yaw 192): pivot at its start, quad W × L
	l.call("on_event", _tele(4, 3, -480, -330, 192, 960, 300, 0, 90))
	var ln: MeshInstance3D = l.call("quad_of", 4)
	assert_eq((ln.mesh as QuadMesh).size, Vector2(3.0, 9.6), "width × length")
	assert_true(ln.global_position.is_equal_approx(ORIGIN + Vector3(0.0, 0.04, -3.3)), "centre = start + L/2 forward")
	assert_true((-ln.global_transform.basis.z).is_equal_approx(Vector3(1.0, 0.0, 0.0)), "fills along +x")
	assert_almost((_param(ln, &"tg_params") as Vector4).x, 3.0, 0.0001)


func test_progress_pulse_impact_flash_and_cancel() -> void:
	var l: Node3D = _layer()
	l.call("on_event", _tele(7, 0, 0, 0, 0, 200, 0, 30, 90))
	var q: MeshInstance3D = l.call("quad_of", 7)
	l.call("update", 60.0, 0.016)
	assert_almost((_param(q, &"tg_params") as Vector4).y, 0.5, 0.0001, "(ct − start) / (impact − start)")
	assert_almost(float(_param(q, &"tg_pulse")), 0.0, 0.0001, "no pulse before the last 0.3 s")
	l.call("update", 82.0, 0.016)
	assert_almost(float(_param(q, &"tg_pulse")), 1.0, 0.0001, "the edge pulses in the last 0.3 s (9 ticks)")
	assert_true(bool(l.call("impacts_at", 90)))
	assert_false(bool(l.call("impacts_at", 89)))
	l.call("on_event", _ev(T.TELEGRAPH_IMPACT, 7))
	assert_eq(int(l.call("active_count")), 0)
	assert_true(q.visible, "impact: white flash")
	assert_eq(_param(q, &"tg_color"), Color(1.0, 1.0, 1.0, 1.0))
	l.call("update", 90.0, 0.1)
	assert_true(q.visible)
	l.call("update", 90.0, 0.1)
	assert_false(q.visible, "after 0.15 s the quad is back in the pool")
	l.call("on_event", _tele(8, 1, 0, 0, 0, 300, 0, 100, 160))
	var c: MeshInstance3D = l.call("quad_of", 8)
	l.call("on_event", _ev(T.TELEGRAPH_CANCELLED, 8))
	assert_false(c.visible, "cancelled (interrupt): gone at once")
	assert_null(l.call("quad_of", 8))


func test_zone_colours_alpha_fade_and_stripes() -> void:
	var l: Node3D = _layer()
	l.call("on_event", _zone(1001, "sts_poison", -150, 120, 180, 10, 160))
	var z: MeshInstance3D = l.call("quad_of", 1001, true)
	assert_not_null(z)
	var col: Color = _param(z, &"tg_color")
	assert_true(Color(col.r, col.g, col.b).is_equal_approx(Color("#7cc242")), "poison zone: green")
	assert_almost(col.a, 0.35, 0.0001, "zones: α 0.35")
	assert_almost(float(_param(z, &"tg_stripe_speed")), 0.2, 0.0001, "slower stripes")
	assert_almost((_param(z, &"tg_params") as Vector4).y, 1.0, 0.0001, "a zone is filled")
	assert_false(bool(l.call("impacts_at", 160)), "zones never force a sample")
	l.call("update", 100.0, 0.016)
	assert_almost((_param(z, &"tg_color") as Color).a, 0.35, 0.0001)
	l.call("update", 145.0, 0.016)
	assert_almost((_param(z, &"tg_color") as Color).a, 0.35 * 0.5, 0.0001, "half a second left: half the alpha")
	l.call("on_event", _ev(T.ZONE_END, 1001))
	assert_false(z.visible)
	assert_eq(TelegraphLayer.zone_color("sts_burn", ""), Color("#ff7a1a"), "fire: orange")
	assert_eq(TelegraphLayer.zone_color("", "skl_e_flame_puddle"), Color("#ff7a1a"))
	assert_eq(TelegraphLayer.zone_color("", ""), Color("#ff4d4d"))


func test_full_pool_the_oldest_zone_gives_way() -> void:
	var l: Node3D = _layer()
	l.call("on_event", _zone(500, "sts_poison", 0, 0, 100, 0, 600))
	for i in 9:
		l.call("on_event", _tele(i + 1, 0, 0, 0, 0, 100, 0, 0, 300))
	assert_eq(int(l.call("visible_quads")), 10)
	l.call("on_event", _tele(20, 0, 0, 0, 0, 100, 0, 0, 300))
	assert_null(l.call("quad_of", 500, true), "the oldest zone ended early (07 §6.3)")
	assert_not_null(l.call("quad_of", 20), "the new telegraph is shown")
	l.call("on_event", _tele(21, 0, 0, 0, 0, 100, 0, 0, 300))
	assert_null(l.call("quad_of", 21), "no zone left to give way: the 11th telegraph is not drawn")
	l.call("clear")
	assert_eq(int(l.call("visible_quads")), 0, "combat end: every quad back in the pool")
