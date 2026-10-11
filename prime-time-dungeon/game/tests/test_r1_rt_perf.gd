extends TestCase
## 07 §3.15 (R1b-I1) test_r1_rt_perf: the time budget of the sim — RtSim.step() with 2 party units and 6 enemies
## ≤ 0.25 ms on a desktop (the 10 telegraphs of the budget come with R1b-I3), a regular fight of ≈ 600 ticks ≤ 0.3 s
## headless. Wall-clock budgets are asserted only with PTD_PERF_ASSERTS=1 (TestCase.assert_time_budget, quality-14);
## the numbers (incl. ticks per second) are always printed. Only step() is timed, not the setup.

const STEP_BUDGET_US: float = 250.0
const FIGHT_BUDGET_MS: float = 300.0


## Steps `sim` (submitting `cmds` before their tick) until it ends or `max_ticks`; returns [ticks, µs in step()].
static func _timed(sim: RtSim, cmds: Array, max_ticks: int) -> Array:
	var i: int = 0
	var us: int = 0
	var n: int = 0
	while not sim.is_finished() and n < max_ticks:
		while i < cmds.size() and int((cmds[i] as Dictionary)["ct"]) <= sim.tick():
			sim.submit(cmds[i])
			i += 1
		var t0: int = Time.get_ticks_usec()
		sim.step()
		us += Time.get_ticks_usec() - t0
		n += 1
	return [n, us]


func test_two_group_fight() -> void:
	var sim: RtSim = RtKit.canned_sim()
	var r: Array = _timed(sim, RtKit.canned_commands(), 1800)
	assert_true(sim.is_finished(), "the canned two-group fight (2 party, 4 enemies) ends")
	var ms: float = int(r[1]) / 1000.0
	print("[TIMING] two-group fight: %d ticks in %.1f ms = %.0f ticks/s, %.1f µs per step" % [int(r[0]), ms,
		int(r[0]) * 1000000.0 / maxf(1.0, float(r[1])), float(r[1]) / maxf(1.0, float(r[0]))])
	assert_time_budget(ms * 600.0 / maxf(1.0, float(r[0])), FIGHT_BUDGET_MS, "a 600-tick regular fight")


func test_six_enemies_step() -> void:
	var cmd: Dictionary = RtKit.encounter("enc_rt_rats", [["g1", "enc_rt_rats", [-100, -300, 128]],
		["g2", "enc_f1_a2", [250, -250, 160]], ["g3", "enc_rt_rats", [-250, -100, 100]]])
	var sim: RtSim = RtKit.sim(cmd, 6, "kai", RtKit.canned_state())
	assert_eq(sim.units().size(), 8, "2 party units, 6 enemies")
	var r: Array = _timed(sim, [], 600)
	var per: float = float(r[1]) / maxf(1.0, float(r[0]))
	print("[TIMING] 2 + 6 units: %d ticks, %.1f µs per step = %.0f ticks/s" % [int(r[0]), per, 1000000.0 / maxf(1.0,
		per)])
	assert_time_budget(per, STEP_BUDGET_US, "1000 steps with 2 party units and 6 enemies (0.25 ms per step)")
