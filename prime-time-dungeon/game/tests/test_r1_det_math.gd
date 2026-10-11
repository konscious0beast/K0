extends TestCase
## 07 §12.5 R1 test_r1_det_math: the integer geometry of core/rt — table symmetry, the exact integer square root,
## yaw_of for every u8 direction (±1), the shape tests against a float reference (floats are allowed here, in the
## test only), the rotation of local offsets and the rounding rules the sim relies on (07 §3.2).

const FixedMath := preload("res://core/stats/fixed_math.gd")


func test_sine_table_symmetry_and_known_values() -> void:
	assert_eq(DetMath.SIN1024.size(), 256)
	assert_eq(DetMath.COS_DEG1024.size(), 91)
	for y in 256:
		assert_eq(DetMath.sin_y(y + 128), -DetMath.sin_y(y), "sin(y + 180°) = −sin(y) at %d" % y)
		assert_eq(DetMath.sin_y(64 - y), DetMath.sin_y(64 + y), "sin(90° − a) = sin(90° + a) at %d" % y)
		assert_eq(DetMath.cos_y(y), DetMath.sin_y(y + 64))
		assert_almost(float(DetMath.sin_y(y)), sin(TAU * y / 256.0) * 1024.0, 0.51, "SIN1024[%d]" % y)
	assert_eq([DetMath.sin_y(0), DetMath.sin_y(64), DetMath.sin_y(128), DetMath.sin_y(192)], [0, 1024, 0, -1024])
	assert_eq(DetMath.sin_y(-1), DetMath.sin_y(255), "any int is taken mod 256")
	assert_eq([DetMath.cos_deg1024(0), DetMath.cos_deg1024(60), DetMath.cos_deg1024(90), DetMath.cos_deg1024(180)],
		[1024, 512, 0, -1024])
	for d in 181:
		assert_eq(DetMath.cos_deg1024(180 - d), -DetMath.cos_deg1024(d), "cos(180° − d) = −cos(d) at %d" % d)
		assert_almost(float(DetMath.cos_deg1024(d)), cos(deg_to_rad(float(d))) * 1024.0, 0.51, "cos %d°" % d)
	assert_eq(DetMath.cos_deg1024(-5), 1024, "clamped to 0…180")
	assert_eq(DetMath.cos_deg1024(270), -1024)


func test_dir_follows_the_yaw_convention() -> void:
	assert_eq(DetMath.dir(0), Vector2i(0, -1024), "yaw 0 = −Z (forward)")
	assert_eq(DetMath.dir(64), Vector2i(-1024, 0), "yaw 64 = −X")
	assert_eq(DetMath.dir(128), Vector2i(0, 1024), "yaw 128 = +Z")
	assert_eq(DetMath.dir(192), Vector2i(1024, 0), "yaw 192 = +X")


func test_isqrt_is_exact() -> void:
	for n in range(0, 1000001, 7):
		var r: int = DetMath.isqrt(n)
		if r * r > n or (r + 1) * (r + 1) <= n:
			fail("isqrt(%d) = %d" % [n, r])
			return
	for pair: Array in [[0, 0], [1, 1], [3, 1], [4, 2], [15, 3], [16, 4], [99, 9], [100, 10],
			[2147395600, 46340], [2147395599, 46339], [1000000000001, 1000000], [999999999999, 999999],
			[(1 << 31) * (1 << 31), 1 << 31], [4611686014132420609, 2147483647]]:
		assert_eq(DetMath.isqrt(int(pair[0])), int(pair[1]), "isqrt(%d)" % int(pair[0]))
	assert_eq(DetMath.isqrt(-5), 0, "negative → 0")


func test_yaw_of_inverts_dir_for_every_direction() -> void:
	for y in 256:
		var d: Vector2i = DetMath.dir(y)
		for scale: int in [1, 3, 17]:
			var got: int = DetMath.yaw_of(d.x * scale, d.y * scale)
			var diff: int = absi(posmod(got - y + 128, 256) - 128)
			if diff > 1:
				fail("yaw_of(dir(%d) × %d) = %d" % [y, scale, got])
				return
	assert_eq(DetMath.yaw_of(0, 0), 0, "zero vector")
	assert_eq([DetMath.yaw_of(0, -5), DetMath.yaw_of(-5, 0), DetMath.yaw_of(0, 5), DetMath.yaw_of(5, 0)],
		[0, 64, 128, 192], "the four axes exactly")
	var rng: RandomNumberGenerator = SeedUtil.make_rng(SeedUtil.derive(4242, "det_math", 1))
	for _i in 500:
		var dx: int = rng.randi_range(-2400, 2400)
		var dz: int = rng.randi_range(-2400, 2400)
		if dx == 0 and dz == 0:
			continue
		var want: float = fposmod(atan2(-float(dx), -float(dz)) * 256.0 / TAU, 256.0)
		var got: int = DetMath.yaw_of(dx, dz)
		var err: float = absf(fposmod(float(got) - want + 128.0, 256.0) - 128.0)
		assert_true(err <= 1.0, "yaw_of(%d, %d) = %d, exact %.2f" % [dx, dz, got, want])


func test_shapes_against_a_float_reference() -> void:
	var rng: RandomNumberGenerator = SeedUtil.make_rng(SeedUtil.derive(4242, "det_math", 2))
	var checked: int = 0
	for _i in 4000:
		var px: int = rng.randi_range(-800, 800)
		var pz: int = rng.randi_range(-800, 800)
		var cx: int = rng.randi_range(-300, 300)
		var cz: int = rng.randi_range(-300, 300)
		var r: int = rng.randi_range(50, 600)
		var yaw: int = rng.randi_range(0, 255)
		var half: int = rng.randi_range(5, 175)
		var d: float = Vector2(px - cx, pz - cz).length()
		var inner: int = r / 2
		if absf(d - r) > 1.0:
			assert_eq(DetMath.in_circle(px, pz, cx, cz, r), d <= r, "circle")
			if absf(d - inner) > 1.0:
				assert_eq(DetMath.in_ring(px, pz, cx, cz, inner, r), d <= r and d >= inner, "ring")
		var ang: float = TAU * yaw / 256.0
		var f: Vector2 = Vector2(-sin(ang), -cos(ang))
		var v: Vector2 = Vector2(px - cx, pz - cz)
		var cone_float: bool = d <= r and (d == 0.0 or f.dot(v) / d >= cos(deg_to_rad(float(half))))
		var margin: float = absf(f.dot(v) / maxf(d, 0.001) - cos(deg_to_rad(float(half))))
		if absf(d - r) > 1.0 and margin > 0.01:
			assert_eq(DetMath.in_cone(px, pz, cx, cz, yaw, r, half), cone_float,
				"cone p(%d,%d) apex(%d,%d) yaw %d r %d half %d" % [px, pz, cx, cz, yaw, r, half])
			checked += 1
		var w: int = rng.randi_range(50, 400)
		var along: float = f.dot(v)
		var across: float = f.x * v.y - f.y * v.x
		if absf(along) > 1.0 and absf(along - r) > 1.0 and absf(absf(across) - w / 2.0) > 1.0:
			var inside: bool = along >= 0.0 and along <= r and absf(across) <= w / 2.0
			assert_eq(DetMath.in_line(px, pz, cx, cz, yaw, r, w), inside, "line")
	assert_gt(checked, 3000, "cone cases compared")
	assert_true(DetMath.in_cone(10, 10, 10, 10, 0, 100, 30), "the apex is inside")
	assert_true(DetMath.in_cone(0, -100, 0, 0, 0, 100, 1), "straight ahead at the full length")
	assert_false(DetMath.in_cone(0, 100, 0, 0, 0, 100, 89), "behind")
	assert_true(DetMath.in_cone(0, 100, 0, 0, 0, 100, 180), "a full circle")


func test_rotation_toward_and_rounding_rules() -> void:
	assert_eq(DetMath.rotate_local(-130, 90, 0), Vector2i(-130, 90), "yaw 0: right = +x, behind = +z")
	assert_eq(DetMath.rotate_local(-130, 90, 128), Vector2i(130, -90), "yaw 128 turns by 180°")
	assert_eq(DetMath.rotate_local(0, 180, 64), Vector2i(180, 0), "facing −X: behind is +X")
	assert_eq(DetMath.rotate_local(100, 0, 64), Vector2i(0, -100), "facing −X: right is −Z")
	assert_eq(DetMath.toward(0, 0, 300, 400, 250), Vector2i(150, 200))
	assert_eq(DetMath.toward(5, 5, 5, 5, 100), Vector2i(5, 5), "same point")
	assert_eq(DetMath.dist(0, 0, 3, 4), 5)
	assert_eq(DetMath.dist2(1, 1, 4, 5), 25)
	# 07 §3.2: int division truncates towards 0; the sim rounds explicitly (half away from zero) or uses posmod.
	assert_eq(-7 / 2, -3)
	assert_eq(-7 % 2, -1)
	assert_eq(posmod(-1, 256), 255)
	assert_eq([FixedMath.div_round(7, 2), FixedMath.div_round(-7, 2), FixedMath.div_round(5, 10)], [4, -4, 1])
	assert_eq([FixedMath.mul_pm(50, 1500), FixedMath.mul_pm(2250, 1500), FixedMath.div_ceil(1, 30)], [75, 3375, 1])
