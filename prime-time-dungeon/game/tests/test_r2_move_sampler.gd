extends TestCase
## MoveSampler (07 §3.5.1, R2): the sample conditions with their thresholds (15 cm deviation from dead reckoning,
## 15 mm/tick velocity change, 8 yaw steps standing, 15 ticks heartbeat), the stop sample, the forced sample before a
## telegraph impact, dead reckoning in closed form — and honest runs never hit the plausibility limits of 07 §3.5.2
## (a reference implementation of the sim-side check lives in this test: step_max, move budget, speed fields), so the
## real sim (R1b) corrects nothing in an honest single-player run.

const MoveSampler := preload("res://scenes/combat/move_sampler.gd")
const FixedMath := preload("res://core/stats/fixed_math.gd")

var _bal: RtBalance = null


func before_each() -> void:
	_bal = RtBalance.from_data(DB.data)


func _sampler() -> RefCounted:
	var s: RefCounted = MoveSampler.new()
	s.call("configure", _bal)
	return s


func _sample(s: RefCounted, ct: int, x: int, z: int, vx: int = 0, vz: int = 0, yaw: int = 0,
		impact: bool = false) -> Array[int]:
	return s.call("sample_for", ct, x, z, vx, vz, yaw, impact)


func test_thresholds_come_from_rt_balance() -> void:
	var s: RefCounted = _sampler()
	assert_eq(int(s.get("dr_threshold_cm")), 15)
	assert_eq(int(s.get("dr_vel_threshold")), 15)
	assert_eq(int(s.get("dr_yaw_threshold")), 8)
	assert_eq(int(s.get("dr_max_ticks")), 30)
	assert_eq(int(s.get("heartbeat_ticks")), 15)
	assert_eq(int(s.get("force_sample_cm")), 2)


func test_first_sample_then_quiet_on_track_until_the_heartbeat() -> void:
	var s: RefCounted = _sampler()
	assert_eq(_sample(s, 0, 100, -50, 120, 0, 64), [100, -50, 120, 0, 64], "the first tick always samples")
	# moving exactly as dead reckoning predicts: 120 mm/tick = 12 cm per tick
	for c in range(1, 15):
		assert_len(_sample(s, c, 100 + 12 * c, -50, 120, 0, 64), 0, "on track, tick %d" % c)
	assert_len(_sample(s, 15, 280, -50, 120, 0, 64), 5, "heartbeat after 15 ticks in motion")
	assert_eq(int((s.get("reasons") as Dictionary).get("heartbeat", 0)), 1)


func test_deviation_threshold_is_15_cm() -> void:
	var s: RefCounted = _sampler()
	_sample(s, 0, 0, 0)
	assert_len(_sample(s, 1, 15, 0), 0, "15 cm off dead reckoning: no sample")
	assert_len(_sample(s, 2, 9, 12), 0, "15 cm (9, 12): no sample")
	assert_eq(_sample(s, 3, 16, 0), [16, 0, 0, 0, 0], "16 cm: sample")
	assert_eq(int((s.get("reasons") as Dictionary).get("deviation", 0)), 1)


func test_velocity_threshold_is_15_mm_per_tick_per_axis() -> void:
	var s: RefCounted = _sampler()
	_sample(s, 0, 0, 0, 100, -40)
	assert_len(_sample(s, 1, 10, -4, 115, -40), 0, "+15 mm/tick on x: no sample")
	assert_len(_sample(s, 2, 20, -8, 100, -55), 0, "-15 mm/tick on z: no sample")
	assert_len(_sample(s, 3, 30, -12, 116, -40), 5, "+16 mm/tick: sample")
	assert_eq(int((s.get("reasons") as Dictionary).get("velocity", 0)), 1)


func test_yaw_threshold_is_8_steps_while_standing_only() -> void:
	var s: RefCounted = _sampler()
	_sample(s, 0, 0, 0, 0, 0, 250)
	assert_len(_sample(s, 1, 0, 0, 0, 0, 2), 0, "8 steps across 0: no sample")
	assert_eq(_sample(s, 2, 0, 0, 0, 0, 3), [0, 0, 0, 0, 3], "9 steps: sample")
	var m: RefCounted = _sampler()
	_sample(m, 0, 0, 0, 100, 0, 0)
	assert_len(_sample(m, 1, 10, 0, 100, 0, 60), 0, "turning while moving waits for another condition")


func test_stop_sample_once() -> void:
	var s: RefCounted = _sampler()
	_sample(s, 0, 0, 0, 10, 0)
	assert_len(_sample(s, 1, 1, 0, 10, 0), 0)
	assert_eq(_sample(s, 2, 2, 0, 0, 0), [2, 0, 0, 0, 0], "standstill reached: one sample with v = 0")
	assert_eq(int((s.get("reasons") as Dictionary).get("stop", 0)), 1)
	for c in range(3, 40):
		assert_len(_sample(s, c, 2, 0, 0, 0), 0, "standing still: no further samples (tick %d)" % c)


func test_forced_sample_before_an_impact() -> void:
	var s: RefCounted = _sampler()
	_sample(s, 0, 0, 0)
	assert_len(_sample(s, 1, 2, 0, 0, 0, 0, true), 0, "2 cm off before an impact: exact enough")
	assert_eq(_sample(s, 2, 3, 0, 0, 0, 0, true), [3, 0, 0, 0, 0], "3 cm off before an impact: forced sample")
	assert_eq(int((s.get("reasons") as Dictionary).get("impact", 0)), 1)
	assert_len(_sample(s, 3, 6, 0, 0, 0, 0, false), 0, "without an impact 3 cm are no reason")


func test_dead_reckoning_closed_form() -> void:
	var last: Array[int] = [10, 100, -100, 125, -125, 0]
	assert_eq(MoveSampler.dead_reckon(last, 10, 30), Vector2i(100, -100))
	assert_eq(MoveSampler.dead_reckon(last, 11, 30), Vector2i(113, -113), "12.5 cm rounds half away from zero")
	assert_eq(MoveSampler.dead_reckon(last, 40, 30), Vector2i(475, -475), "30 ticks")
	assert_eq(MoveSampler.dead_reckon(last, 400, 30), Vector2i(475, -475), "DR_MAX_TICKS: the unit stands after 30")
	assert_eq(MoveSampler.dead_reckon(last, 5, 30), Vector2i(100, -100), "no reckoning backwards")
	assert_eq(FixedMath.div_round(-1250, 10), -125)


func test_conversions() -> void:
	var o: Vector3 = Vector3(12.0, 0.0, -36.0)
	assert_eq(MoveSampler.local_cm(Vector3(13.234, 0.4, -37.012), o), Vector2i(123, -101))
	assert_eq(MoveSampler.vel_mm(Vector3(5.5, 0.0, -1.0)), Vector2i(183, -33), "roundi(v × 1000 / 30)")
	assert_eq(MoveSampler.yaw_u8(0.0), 0)
	assert_eq(MoveSampler.yaw_u8(-PI * 0.5), 192)
	assert_eq(MoveSampler.yaw_u8(PI), 128)
	assert_almost(MoveSampler.yaw_rad(64), PI * 0.5, 0.0001)
	assert_eq(MoveSampler.yaw_diff(250, 2), 8)
	assert_eq(MoveSampler.dist_cm(3, 4), 5)
	assert_eq(MoveSampler.dist_cm(1, 1), 1, "rounded down")


func test_reset_starts_a_new_track() -> void:
	var s: RefCounted = _sampler()
	_sample(s, 0, 0, 0)
	s.call("reset")
	assert_len(_sample(s, 1, 0, 0), 5, "after reset (control switch, correction) the next tick samples again")


## Honest runs (a body integrated at 60 Hz physics, the tick loop at 30 Hz like the director): run, turn, stop,
## strafe, slide along the ring, at every movement factor — no sample ever breaks the plausibility limits of
## 07 §3.5.2, the sim position (dead reckoning between samples) never drifts more than 15 cm from the body, and at an
## impact tick it is exact to 2 cm.
func test_honest_runs_are_never_corrected() -> void:
	for pm: int in [1000, 600, 1200, 500]:
		for path: String in ["run_turn_stop", "strafe_zigzag", "ring_slide"]:
			var r: Dictionary = _honest_run(path, pm, 900)
			assert_eq(int(r["corrected"]), 0, "%s at %d ‰: corrections" % [path, pm])
			assert_eq(int(r["speed_capped"]), 0, "%s at %d ‰: speed fields over max_v" % [path, pm])
			assert_lt(int(r["max_drift_cm"]), 16, "%s at %d ‰: sim ↔ body drift %d cm" % [path, pm,
				int(r["max_drift_cm"])])
			assert_lt(int(r["impact_drift_cm"]), 3, "%s at %d ‰: drift at impacts %d cm" % [path, pm,
				int(r["impact_drift_cm"])])
			assert_gt(int(r["samples"]), 10, "%s at %d ‰ produced samples" % [path, pm])


## One honest run of `ticks` combat ticks: {"corrected", "speed_capped", "max_drift_cm", "impact_drift_cm",
## "samples"}. Physics 60 Hz (2 steps per tick), speed = PLAYER_RUN_CM_S × pm; telegraph impacts every 37 ticks.
func _honest_run(path: String, pm: int, ticks: int) -> Dictionary:
	var s: RefCounted = _sampler()
	var run_ms: float = float(_bal.i("PLAYER_RUN_CM_S")) / 100.0 * float(pm) / 1000.0
	var pos: Vector2 = Vector2(0.0, 3.0)
	var vel: Vector2 = Vector2.ZERO
	var yaw: float = 0.0
	var last: Array[int] = []                 # last accepted sample [ct, x, z, vx, vz, yaw]
	var budget: int = _bal.i("MOVE_BUDGET_MM")
	var out: Dictionary = {"corrected": 0, "speed_capped": 0, "max_drift_cm": 0, "impact_drift_cm": 0, "samples": 0}
	var max_v: int = ceili(float(_bal.i("PLAYER_RUN_CM_S")) * 10.0 / 30.0 * float(pm) / 1000.0
		* float(_bal.i("SPEED_TOLERANCE_PM")) / 1000.0)
	for c in ticks:
		for _step in 2:
			var want: Vector2 = _path_dir(path, c, pos) * run_ms
			vel = want
			pos += vel / 60.0
			if path == "ring_slide" and pos.length() > 4.4:
				pos = pos.normalized() * 4.4       # the collision ring: the body slides along it
		if vel.length() > 0.01:
			yaw = atan2(-vel.x, -vel.y)
		var cm: Vector2i = Vector2i(roundi(pos.x * 100.0), roundi(pos.y * 100.0))
		var mm: Vector2i = Vector2i(roundi(vel.x * 1000.0 / 30.0), roundi(vel.y * 1000.0 / 30.0))
		var impact: bool = c % 37 == 36 or c % 37 == 0
		var smp: Array[int] = _sample(s, c, cm.x, cm.y, mm.x, mm.y, posmod(roundi(yaw * 256.0 / TAU), 256), impact)
		if not smp.is_empty():
			out["samples"] = int(out["samples"]) + 1
			if absi(smp[2]) > max_v or absi(smp[3]) > max_v:
				out["speed_capped"] = int(out["speed_capped"]) + 1
			if not last.is_empty():
				var dt: int = c - last[0]
				var step_max: int = FixedMath.div_ceil(_bal.i("PLAYER_RUN_CM_S") * pm * dt, 30 * 1000)
				var d: int = MoveSampler.dist_cm(smp[0] - last[1], smp[1] - last[2])
				budget = mini(_bal.i("MOVE_BUDGET_MM"), budget + dt * _bal.i("MOVE_REFILL_MM_TICK"))
				var excess_mm: int = maxi(0, d - step_max) * 10
				if excess_mm <= budget:
					budget -= excess_mm
				else:
					out["corrected"] = int(out["corrected"]) + 1
			last = [c, smp[0], smp[1], smp[2], smp[3], smp[4]]
		var dr: Vector2i = MoveSampler.dead_reckon(last, c, _bal.i("DR_MAX_TICKS"))
		var drift: int = MoveSampler.dist_cm(dr.x - cm.x, dr.y - cm.y)
		out["max_drift_cm"] = maxi(int(out["max_drift_cm"]), drift)
		if c % 37 == 0 and c > 0:
			out["impact_drift_cm"] = maxi(int(out["impact_drift_cm"]), drift)
	return out


## Input direction (unit or zero) of the scripted honest paths.
static func _path_dir(path: String, c: int, pos: Vector2) -> Vector2:
	match path:
		"run_turn_stop":
			var phase: int = c % 120
			if phase >= 70 and phase < 90:
				return Vector2.ZERO
			if pos.length() > 4.5:
				return -pos.normalized()              # stay in the set (a room is ±8 m, RtCommand ±24 m)
			if phase < 40:
				return Vector2(0.0, -1.0)
			if phase < 70:
				return Vector2(1.0, 0.0).rotated(float(phase - 40) * 0.05)
			return Vector2(-1.0, 0.3).normalized()
		"strafe_zigzag":
			var side: float = 1.0 if (c / 18) % 2 == 0 else -1.0
			var v: Vector2 = Vector2(side, -0.4).normalized()
			return -pos.normalized() if pos.length() > 4.0 else v
		_:
			var out: Vector2 = Vector2(0.0, 1.0).rotated(float(c) * 0.02)
			return (out + pos.normalized() * 0.6).normalized()
