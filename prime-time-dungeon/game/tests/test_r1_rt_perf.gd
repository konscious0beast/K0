extends TestCase
## 07 §3.15 (R1b-I1 … I3) test_r1_rt_perf: the time budget of the sim — RtSim.step() with 2 party units (the person
## and the AI partner playing its rules), 6 enemies playing their rules (sprayers with zones, a caster with its
## telegraph) and 10 telegraphs / zones at all times ≤ 0.25 ms on a desktop, a regular fight of ≈ 600 ticks ≤ 0.3 s
## headless. Wall-clock budgets are asserted only with PTD_PERF_ASSERTS=1 (TestCase.assert_time_budget, quality-14);
## the numbers (incl. ticks per second and the machine load) are always printed. Only step() is timed, not the setup.

const STEP_BUDGET_US: float = 250.0
const FIGHT_BUDGET_MS: float = 300.0
const SHAPES: int = 10


## Steps `sim` (submitting `cmds` before their tick; `fill` tops the telegraphs / zones up to SHAPES and every unit's
## HP up to its maximum before every step, untimed, so all 8 units fight for the whole run) until it ends or
## `max_ticks`; returns [ticks, µs in step(), summed shape count].
static func _timed(sim: RtSim, cmds: Array, max_ticks: int, fill: bool = false) -> Array:
	var i: int = 0
	var us: int = 0
	var n: int = 0
	var shapes: int = 0
	while not sim.is_finished() and n < max_ticks:
		while i < cmds.size() and int((cmds[i] as Dictionary)["ct"]) <= sim.tick():
			sim.submit(cmds[i])
			i += 1
		if fill:
			_fill(sim, n)
			for u: RtUnit in sim.units_ref():
				u.hp = maxi(u.hp, u.max_hp())
		shapes += sim.telegraphs().size()
		var t0: int = Time.get_ticks_usec()
		sim.step()
		us += Time.get_ticks_usec() - t0
		n += 1
	return [n, us, shapes]


## Harmless filler shapes up to SHAPES (no skill: an impact without effect, a zone without status), alternating
## pending telegraphs (striking in 45 ticks) and zones (300 ticks) around the ring, so the step always walks 10.
static func _fill(sim: RtSim, n: int) -> void:
	var k: int = 0
	while sim.telegraphs().size() < SHAPES:
		var t: RtTelegraph = RtTelegraph.new()
		var f: Vector2i = DetMath.dir((n * 37 + k * 59) % 256)
		t.source_id = "e0"
		t.side = Combatant.Side.PARTY
		t.shape = RtTelegraph.Shape.CIRCLE
		t.x = f.x * 380 / DetMath.ONE
		t.z = f.y * 380 / DetMath.ONE
		t.r = 120
		t.start = sim.tick()
		t.is_zone = (n + k) % 2 == 0
		t.impact_at = -1 if t.is_zone else sim.tick() + 45
		t.ends_at = sim.tick() + 300 if t.is_zone else -1
		t.period = 60 if t.is_zone else 0
		t.next_tick_at = sim.tick() + 60 if t.is_zone else -1
		sim.add_telegraph(t)
		k += 1


func test_two_group_fight() -> void:
	var sim: RtSim = RtKit.canned_sim()
	var r: Array = _timed(sim, RtKit.canned_commands(), 1800)
	assert_true(sim.is_finished(), "the canned two-group fight (2 party, 4 enemies) ends")
	var ms: float = int(r[1]) / 1000.0
	print("[TIMING] two-group fight: %d ticks in %.1f ms = %.0f ticks/s, %.1f µs per step (load %s)" % [int(r[0]), ms,
		int(r[0]) * 1000000.0 / maxf(1.0, float(r[1])), float(r[1]) / maxf(1.0, float(r[0])), _load()])
	assert_time_budget(ms * 600.0 / maxf(1.0, float(r[0])), FIGHT_BUDGET_MS, "a 600-tick regular fight")


func test_six_enemies_ten_telegraphs_step() -> void:
	var cmd: Dictionary = RtKit.encounter("enc_rt_rats", [["g1", "enc_rt_rats", [-100, -300, 128]],
		["g2", "enc_f1_a2", [250, -250, 160]], ["g3", "enc_rt_sprayers", [-250, -100, 100]]])
	# One untimed warm-up run: the first fight in a fresh test process pays one-time costs (allocations, caches),
	# measured at ~1.5x the steady state; then the median of three identical timed runs (scheduler noise).
	_timed(RtKit.sim(cmd, 6, "kai", RtKit.canned_state()), [], 100, true)
	var pers: Array[float] = []
	var r: Array = []
	for k: int in 3:
		var sim: RtSim = RtKit.sim(cmd, 6, "kai", RtKit.canned_state())
		assert_eq(sim.units().size(), 8, "2 party units, 6 enemies")
		r = _timed(sim, [], 600, true)
		pers.append(float(r[1]) / maxf(1.0, float(r[0])))
	pers.sort()
	var per: float = pers[1]
	print("[TIMING] 2 + 6 units, %.1f telegraphs / zones on average: %d ticks, %.1f µs per step = %.0f ticks/s (load %s)"
		% [float(r[2]) / maxf(1.0, float(r[0])), int(r[0]), per, 1000000.0 / maxf(1.0, per), _load()])
	assert_eq(int(r[0]), 600, "600 steps")
	assert_gt(int(r[2]), int(r[0]) * (SHAPES - 1), "10 shapes on almost every step")
	assert_time_budget(per, STEP_BUDGET_US, "steps with 2 party units, 6 enemies and 10 telegraphs (0.25 ms per step)")


## The 1-minute load average (/proc/loadavg, read by line: procfs reports a length of 0) — the timings are only
## meaningful on a quiet machine.
static func _load() -> String:
	var f: FileAccess = FileAccess.open("/proc/loadavg", FileAccess.READ)
	if f == null:
		return "n/a"
	var line: String = f.get_line()
	return line.split(" ")[0] if line != "" else "n/a"
