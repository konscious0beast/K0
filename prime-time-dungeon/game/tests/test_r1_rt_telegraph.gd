extends TestCase
## 07 §6.3, §5.5 (R1b-I2 part; impacts, zones and anchors follow with R1b-I3) test_r1_rt_telegraph: the shape test of
## every form ("Fußpunkt-Regel": circle, cone, ring, line; boundaries included, only inside the set ring), the shape
## grown by a margin for the AI's dodging (contains_inflated, the cone against a float reference of the true
## distance — floats allowed in tests), the canonical snapshot, RtSim.add_telegraph (ids, the set radius).

const S := RtTelegraph.Shape


static func _t(shape: RtTelegraph.Shape, x: int, z: int, yaw: int, r: int, r2: int, half: int = 0,
		set_r: int = 0) -> RtTelegraph:
	var t: RtTelegraph = RtTelegraph.new()
	t.shape = shape
	t.x = x
	t.z = z
	t.yaw = yaw
	t.r = r
	t.r2 = r2
	t.half_deg = half
	t.set_r = set_r
	return t


func test_circle_and_ring() -> void:
	var c: RtTelegraph = _t(S.CIRCLE, 100, -50, 0, 250, 0)
	assert_eq([c.contains(100, 200), c.contains(100, 201), c.contains(350, -50), c.contains(277, 127)],
		[true, false, true, false], "distance ≤ r (250² = 177² + 177² + 2: just outside)")
	assert_eq([c.contains_inflated(100, 260, 60), c.contains_inflated(100, 261, 60)], [true, false], "r + m")
	var ring: RtTelegraph = _t(S.RING, 0, 0, 0, 400, 200)
	assert_eq([ring.contains(0, 199), ring.contains(0, 200), ring.contains(400, 0), ring.contains(0, 401)],
		[false, true, true, false], "r2 ≤ distance ≤ r")
	assert_eq([ring.contains_inflated(0, 140, 60), ring.contains_inflated(0, 139, 60), ring.contains_inflated(460, 0,
		60), ring.contains_inflated(461, 0, 60)], [true, false, true, false], "r2 − m … r + m")
	assert_true(_t(S.RING, 0, 0, 0, 400, 50).contains_inflated(0, 0, 60), "the inner edge never below 0")


func test_line() -> void:
	var l: RtTelegraph = _t(S.LINE, 0, 0, 192, 800, 150)              # yaw 192 = +x
	assert_eq([l.contains(0, 0), l.contains(800, 75), l.contains(801, 0), l.contains(-1, 0), l.contains(400, 76),
		l.contains(400, -75)], [true, true, false, false, false, true], "0 ≤ längs ≤ L, |quer| ≤ W / 2")
	assert_eq([l.contains_inflated(-60, 0, 60), l.contains_inflated(-61, 0, 60), l.contains_inflated(860, 135, 60),
		l.contains_inflated(400, 136, 60)], [true, false, true, false], "−m ≤ längs ≤ L + m, |quer| ≤ W / 2 + m")
	var up: RtTelegraph = _t(S.LINE, 0, 0, 0, 300, 100)                 # yaw 0 = −z
	assert_eq([up.contains(0, -300), up.contains(0, 300), up.contains(50, -10)], [true, false, true])


func test_cone() -> void:
	var k: RtTelegraph = _t(S.CONE, 0, 0, 0, 400, 0, 45)                # towards −z, ±45°
	assert_eq([k.contains(0, 0), k.contains(0, -400), k.contains(0, -401), k.contains(200, -200), k.contains(210, -200),
		k.contains(0, 10)], [true, true, false, true, false, false], "distance ≤ r and inside ±half (the apex too)")
	assert_eq([k.contains_inflated(0, 60, 60), k.contains_inflated(0, -460, 60), k.contains_inflated(0, -461, 60)],
		[true, true, false], "within m of the apex; r + m along the facing")


## The grown cone contains every point within m − 2 of the true sector and none farther than 1.5 m + 2 (the corners at
## the arc are a little generous: never too small for dodging).
func test_cone_inflated_against_the_true_distance() -> void:
	var rng: RandomNumberGenerator = make_rng(7)
	var m: int = 60
	for case: Array in [[0, 400, 45], [96, 300, 30], [200, 500, 60], [33, 250, 15], [128, 400, 90]]:
		var k: RtTelegraph = _t(S.CONE, 30, -20, int(case[0]), int(case[1]), 0, int(case[2]))
		var inside_fails: int = 0
		var outside_fails: int = 0
		for _i in 3000:
			var px: int = rng.randi_range(-800, 800)
			var pz: int = rng.randi_range(-800, 800)
			var d: float = _sector_distance(k, px, pz)
			var got: bool = k.contains_inflated(px, pz, m)
			if d <= m - 2 and not got:
				inside_fails += 1
			if d > m * 1.5 + 2 and got:
				outside_fails += 1
		assert_eq([inside_fails, outside_fails], [0, 0], "cone %s" % str(case))


## Float distance from (px, pz) to the cone sector of `k` (test reference only).
static func _sector_distance(k: RtTelegraph, px: int, pz: int) -> float:
	var f: Vector2i = DetMath.dir(k.yaw)
	var fx: float = f.x / 1024.0
	var fz: float = f.y / 1024.0
	var vx: float = px - k.x
	var vz: float = pz - k.z
	var d: float = sqrt(vx * vx + vz * vz)
	if d == 0.0:
		return 0.0
	var ang: float = acos(clampf((fx * vx + fz * vz) / d, -1.0, 1.0))
	if ang <= deg_to_rad(k.half_deg):
		return maxf(0.0, d - k.r)
	var best: float = INF
	for sgn: float in [1.0, -1.0]:
		var a: float = deg_to_rad(k.half_deg) * sgn
		var ex: float = fx * cos(a) - fz * sin(a)
		var ez: float = fx * sin(a) + fz * cos(a)
		var t: float = clampf(vx * ex + vz * ez, 0.0, float(k.r))
		best = minf(best, Vector2(vx - ex * t, vz - ez * t).length())
	return best


func test_only_inside_the_set_ring() -> void:
	var c: RtTelegraph = _t(S.CIRCLE, 400, 0, 0, 250, 0, 0, 480)
	assert_eq([c.contains(470, 0), c.contains(481, 0), c.contains(600, 0)], [true, false, false],
		"the Fußpunkt-Regel only inside |p| ≤ set_r (a unit in a door lane is never hit)")
	assert_eq([c.contains_inflated(540, 0, 60), c.contains_inflated(541, 0, 60)], [true, false], "grown: set_r + m")
	assert_true(_t(S.CIRCLE, 400, 0, 0, 250, 0).contains(600, 0), "set_r 0: unclipped")


func test_snapshot_and_add() -> void:
	var t: RtTelegraph = _t(S.CONE, 1, 2, 3, 4, 5, 6, 480)
	t.inside_last = {"p1": 9, "p0": 7}
	var d: Dictionary = t.to_dict()
	assert_eq([d["shape"], d["half_deg"], d["set_r"], d["inside_last"].keys()], [int(S.CONE), 6, 480, ["p0", "p1"]])
	var sim: RtSim = RtKit.sim(RtKit.dummy_cmd(), 6)
	var a: RtTelegraph = _t(S.CIRCLE, 0, 0, 0, 100, 0)
	a.side = Combatant.Side.PARTY
	a.start = sim.tick()
	a.impact_at = sim.tick() + 30
	var z: RtTelegraph = _t(S.CIRCLE, 0, 0, 0, 100, 0)
	z.side = Combatant.Side.PARTY
	z.is_zone = true
	z.impact_at = -1
	assert_eq([sim.add_telegraph(a), sim.add_telegraph(z)], [1, 2], "ids from 1, increasing")
	assert_eq([a.set_r, sim.telegraphs().size(), int(sim.snapshot()["next_tele"])], [480, 2, 3],
		"clipped to the set radius; part of the snapshot")
