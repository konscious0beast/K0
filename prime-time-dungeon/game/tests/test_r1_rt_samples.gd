extends TestCase
## 07 §3.5.1–3.5.2, §2.5 (R1b-I1, part of 07's test_r1_rt_move): the player's move samples (Grad A) — dead reckoning
## in closed form, the plausibility bound "run speed × Δ + a refilling budget" (600 mm, +3 mm per tick), the velocity
## clamp, walkable placement inside the cell, holding while stunned, POS_CORRECTED, the start correction of party
## units outside the ring, and the flight after 60 ticks outside the ring (warning at 15).

const FixedMath := preload("res://core/stats/fixed_math.gd")


func _sim(opts: Dictionary = {}) -> RtSim:
	var sim: RtSim = RtKit.sim(RtKit.dummy_cmd(opts), 3)
	sim.unit("e0").auto_on = false
	return sim


## Submits a sample of p0 at the current tick and steps once; returns the tick's events.
func _sample(sim: RtSim, x: int, z: int, vx: int = 0, vz: int = 0, yaw: int = 0) -> Array[ActionEvent]:
	assert_eq(sim.submit(RtCommand.move(sim.tick(), "p0", x, z, vx, vz, yaw)), "", "sample accepted")
	return sim.step()


func _idle(sim: RtSim, until: int) -> void:
	while sim.tick() < until:
		sim.step()


func _corrections(events: Array[ActionEvent]) -> Array[ActionEvent]:
	return RtKit.of(events, ActionEvent.Type.POS_CORRECTED)


func test_honest_run_and_dead_reckoning() -> void:
	var sim: RtSim = _sim()
	var kai: RtUnit = sim.unit("p0")
	assert_eq([kai.x, kai.z], [0, 200])
	var all: Array[ActionEvent] = []
	for c in 21:
		if c % 5 == 0:
			all.append_array(_sample(sim, roundi(c * 550.0 / 30.0), 200, 183, 0, 192))
			assert_eq(kai.x, roundi(c * 550.0 / 30.0), "sample position at ct %d" % c)
		else:
			all.append_array(sim.step())
			var last: int = roundi((c - c % 5) * 550.0 / 30.0)
			assert_eq(kai.x, last + FixedMath.div_round(183 * (c % 5), 10), "dead reckoning at ct %d" % c)
	assert_eq(_corrections(all).size(), 0, "an honest run is never corrected")
	assert_eq(kai.move_budget, 600, "and spends nothing of the budget")


func test_teleport_is_cut_back_to_speed_plus_budget() -> void:
	var sim: RtSim = _sim()
	var kai: RtUnit = sim.unit("p0")
	_idle(sim, 10)
	var ev: Array[ActionEvent] = _corrections(_sample(sim, 300, 200))
	# Δ = 10: step_max = ⌈550 × 1000 × 10 / 30000⌉ = 184; excess (300 − 184) × 10 mm > budget 600 → 184 + 60
	assert_eq([kai.x, kai.z], [244, 200])
	assert_eq(kai.move_budget, 0)
	assert_eq(ev.size(), 1)
	if ev.size() == 1:
		assert_eq([ev[0].target_id, ev[0].rt], ["p0", {"x": 244, "z": 200}])
	assert_eq(_corrections(_sample(sim, 263, 200)).size(), 0, "one tick later: 19 cm is a run step")
	assert_eq(kai.move_budget, 3, "the budget refills 3 mm per tick")


func test_one_small_jump_fits_the_budget() -> void:
	var sim: RtSim = _sim()
	var kai: RtUnit = sim.unit("p0")
	sim.step()
	assert_eq(_corrections(_sample(sim, 79, 200)).size(), 0, "Δ 1: run step 19 + 60 cm from the budget")
	assert_eq(kai.move_budget, 0, "600 mm spent")
	assert_eq(_corrections(_sample(sim, 98, 200)).size(), 0, "an exact run step")
	assert_eq(kai.move_budget, 3, "+3 mm per tick")
	assert_eq(_corrections(_sample(sim, 122, 200)).size(), 1, "5 cm more than a run step: the budget (6 mm) is short")
	assert_eq([kai.x, kai.move_budget], [98 + 19, 0], "cut back to run step + budget / 10")


func test_velocity_is_clamped_for_dead_reckoning() -> void:
	var sim: RtSim = _sim()
	var kai: RtUnit = sim.unit("p0")
	_sample(sim, 0, 200, 400, -400)
	assert_eq([kai.sample[3], kai.sample[4]], [230, -230], "max_v = ⌈5500 × 1250 / 30000⌉ = 230 mm per tick")
	sim.step()
	assert_eq([kai.x, kai.z], [23, 177])


func test_dead_reckoning_stops_after_dr_max_ticks() -> void:
	var sim: RtSim = _sim()
	var kai: RtUnit = sim.unit("p0")
	_sample(sim, 0, 200, 100, 0)
	_idle(sim, 30)
	assert_eq(kai.x, 290)
	_idle(sim, 31)
	assert_eq(kai.x, 300, "30 ticks of dead reckoning …")
	_idle(sim, 60)
	assert_eq(kai.x, 300, "… then the unit stands")


func test_unwalkable_points_are_projected() -> void:
	var sim: RtSim = _sim()
	var kai: RtUnit = sim.unit("p0")
	_idle(sim, 30)
	var ev: Array[ActionEvent] = _corrections(_sample(sim, 300, 400))
	assert_eq(ev.size(), 1, "outside ring and lanes, inside the cell")
	assert_true(RtGeo.walkable(sim.setup.geo, kai.x, kai.z, kai.radius, true), "now walkable")
	assert_between(kai.x * kai.x + kai.z * kai.z, 435 * 435, 440 * 440)


func test_a_stunned_unit_holds_its_position() -> void:
	var sim: RtSim = _sim()
	var kai: RtUnit = sim.unit("p0")
	RtSim.StatusFx.apply(sim, "e0", kai, "sts_stun", 1000, 1000)
	assert_true(kai.has_status("sts_stun"))
	var ev: Array[ActionEvent] = _corrections(_sample(sim, 20, 200, 180, 0))
	assert_eq([kai.x, kai.z, kai.sample[3]], [0, 200, 0], "held, velocity 0")
	assert_eq(ev.size(), 1, "the scene is told to put the figure back")


func test_party_units_outside_the_ring_start_on_it() -> void:
	var sim: RtSim = RtKit.sim(RtKit.dummy_cmd({"party": [{"u": "p0", "p": [0, 200, 0]},
		{"u": "p1", "p": [600, 0, 0]}]}), 3)
	var mop: RtUnit = sim.unit("p1")
	assert_eq([mop.x, mop.z], [445, 0], "projected onto the ring r − radius (480 − 35)")
	var fresh: RtSim = RtSim.new(RtKit.setup(RtKit.state(3), RtKit.dummy_cmd({"party": [{"u": "p0", "p": [0, 200, 0]},
		{"u": "p1", "p": [600, 0, 0]}]})), RtKit.data())
	var pre: Array[ActionEvent] = fresh.start()
	var pc: Array[ActionEvent] = RtKit.of(pre, ActionEvent.Type.POS_CORRECTED)
	assert_eq(pc.size(), 1)
	if pc.size() == 1:
		assert_eq([pc[0].target_id, pc[0].rt], ["p1", {"x": 445, "z": 0}])


func test_samples_only_for_the_controlled_unit() -> void:
	var sim: RtSim = _sim()
	assert_eq(sim.submit(RtCommand.move(0, "p1", 0, 0, 0, 0, 0)), "not_controlled")
	assert_eq(sim.submit(RtCommand.move(0, "e0", 0, 0, 0, 0, 0)), "not_controlled")
	assert_eq(sim.submit(RtCommand.move(0, "p0", 2500, 0, 0, 0, 0)), "schema", "|x| ≤ 2400")


## Runs p0 north from (0, 200) at 18 cm per tick, one sample per tick, for `ticks` ticks.
func _run_north(sim: RtSim, ticks: int, out: Array[ActionEvent]) -> void:
	var z: int = sim.unit("p0").z
	for _i in ticks:
		if sim.is_finished():
			return
		z -= 18
		out.append_array(_sample(sim, 0, z, 0, -180, 0))


func test_flight_after_sixty_ticks_outside_the_ring() -> void:
	var sim: RtSim = _sim()
	var events: Array[ActionEvent] = []
	_run_north(sim, 36, events)                         # z = 200 − 648 = −448: just outside r − radius
	var first_out: int = -1
	for c in 36:
		if first_out < 0 and sim.unit("p0").outside_since >= 0:
			first_out = sim.unit("p0").outside_since
	assert_eq(sim.unit("p0").outside_since, 35, "outside from the tick its centre left r − radius")
	_run_north(sim, 18, events)                         # −772: deep in the north lane
	while not sim.is_finished() and sim.tick() < 200:
		events.append_array(sim.step())
	var warn: Array[ActionEvent] = RtKit.of(events, ActionEvent.Type.FLEE_WARNING)
	assert_eq(warn.size(), 1)
	if warn.size() == 1:
		assert_eq([warn[0].tick, warn[0].value, warn[0].actor_id], [35 + 14, 45, "p0"], "warning at 15 ticks outside")
	assert_true(sim.is_finished())
	assert_eq(sim.result.outcome, BattleResult.Outcome.FLED)
	assert_eq(sim.result.duration_ticks, 35 + 60, "60 consecutive ticks outside")
	assert_eq(sim.result.flee_attempts, 1)
	assert_eq(_corrections(events).size(), 0, "running out of a door is legal")
	var fr: Array[ActionEvent] = RtKit.of(events, ActionEvent.Type.FLEE_RESULT)
	assert_true(fr.size() == 1 and fr[0].success)


func test_coming_back_resets_the_flight_counter() -> void:
	var sim: RtSim = _sim()
	var events: Array[ActionEvent] = []
	_run_north(sim, 40, events)
	assert_gt(sim.unit("p0").outside_since, 0)
	var z: int = sim.unit("p0").z
	for _i in 20:
		z += 18
		events.append_array(_sample(sim, 0, z, 0, 180, 128))
	assert_eq(sim.unit("p0").outside_since, -1, "back inside")
	_idle(sim, 150)
	assert_false(sim.is_finished(), "no flight")


func test_no_flight_from_a_closed_set() -> void:
	var st: GameState = RtKit.state(3)
	var sim: RtSim = RtKit.sim(RtKit.encounter("enc_rt_test_boss", [["g", "enc_rt_test_boss", [0, -300, 128]]]), 3,
		"kai", st)
	var events: Array[ActionEvent] = []
	_run_north(sim, 60, events)
	assert_gt(_corrections(events).size(), 0, "the ring has no gaps: the figure is put back")
	assert_eq(sim.unit("p0").outside_since, -1)
	assert_true(RtGeo.in_circle(sim.setup.geo, sim.unit("p0").x, sim.unit("p0").z, sim.unit("p0").radius))
