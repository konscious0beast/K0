extends TestCase
## 07 §3.5.3, §3.5.5, §2.3 (R1b-I1, sim-driven part of 07's test_r1_rt_move; the samples are test_r1_rt_samples, the
## geometry test_r1_rt_geo): the entry (Auftritt) of a leader from outside the ring in ≤ 30 ticks — stationary ones
## appear at its end —, the pop-in of its komparsen, melee steering to reach + r − 30, the ranged keep distance (±200),
## the AI partner following the controlled unit, enemy repulsion, no movement while casting or held, speed factors,
## clamping into the ring (lanes only for the party, and only while the controlled unit is outside).

const StatusFx := preload("res://core/rt/rt_status_fx.gd")
const T := ActionEvent.Type


func _until(sim: RtSim, ct: int) -> Array[ActionEvent]:
	var out: Array[ActionEvent] = []
	while sim.tick() < ct and not sim.is_finished():
		out.append_array(sim.step())
	return out


func test_entry_and_pop_in() -> void:
	var sim: RtSim = RtKit.sim_no_ai(RtKit.encounter("enc_rt_rats", [["g", "enc_rt_rats", [0, -760, 128]]]), 6)
	var lead: RtUnit = sim.unit("e0")
	var kom: RtUnit = sim.unit("e1")
	assert_eq([Array(lead.entry), kom.pop_in_until], [[0, -450], 15 + 30])
	var zs: Array = []
	var ev: Array[ActionEvent] = []
	while not lead.entry.is_empty() and sim.tick() < 40:
		ev.append_array(sim.step())
		zs.append(lead.z)
	assert_eq(zs.slice(0, 3), [-748, -736, -724], "12 cm per tick (360 cm/s)")
	assert_eq([sim.tick() - 1, lead.x, lead.z], [25, 0, -450], "arrived at its ring point in tick 25")
	assert_eq(kom.pop_in_until, 25 + 15, "the komparse acts POP_IN_TICKS after the leader's arrival")
	assert_true(ev.all(func(x: ActionEvent) -> bool: return x.actor_id != "e0"), "no action, no target while entering")
	ev = _until(sim, 40)
	assert_true(ev.all(func(x: ActionEvent) -> bool: return x.type != T.SWING or x.actor_id != "e1"))
	var stand: RtSim = RtKit.sim_no_ai(RtKit.encounter("enc_rt_dummy", [["g", "enc_rt_dummy", [0, -760, 128]]]), 6)
	var dummy: RtUnit = stand.unit("e0")
	_until(stand, 29)
	assert_eq([dummy.z, dummy.entry.size()], [-760, 2], "a stationary leader does not walk …")
	stand.step()
	assert_eq([dummy.z, dummy.entry.size()], [-440, 0], "… it appears at its ring point after ENTER_MAX_TICKS")


func test_melee_goal_and_reach() -> void:
	var sim: RtSim = RtKit.sim_no_ai(RtKit.encounter("enc_f1_a2", [["g", "enc_f1_a2", [0, -300, 128]]]), 6)
	for u: RtUnit in sim.units():
		u.auto_on = u.id == "e0"
	var rat: RtUnit = sim.unit("e0")
	var ev: Array[ActionEvent] = _until(sim, 23)
	assert_eq([rat.x, rat.z], [0, -30], "reach 220 + Kai's radius 40 − MELEE_STOP_CM 30 from Kai (0, 200)")
	ev.append_array(_until(sim, 31))
	assert_eq([rat.x, rat.z], [0, -30], "and stays")
	var sw: Array = RtKit.of(ev, T.SWING).filter(func(x: ActionEvent) -> bool: return x.actor_id == "e0")
	assert_true(sw.size() == 1 and sw[0].tick == 30 and sw[0].target_id == "p0", "the first swing at ct 30")


func test_ranged_keep_distance() -> void:
	var sim: RtSim = RtKit.sim_no_ai(RtKit.encounter("enc_f1_a2", [["g", "enc_f1_a2", [0, -300, 128]]]), 6)
	for u: RtUnit in sim.units():
		u.auto_on = false
	var caster: RtUnit = sim.unit("e1")
	var kai: RtUnit = sim.unit("p0")
	var rat: RtUnit = sim.unit("e0")
	RtSim.Damage.apply(sim, kai, rat, rat.hp, Elements.PHYSICAL, HitResult.new(), "skl_kai_heavy_swing", "", "",
		RtSim.Damage.Kind.ABILITY, false, BattleCommand.Kind.SKILL, 1000)
	var p0: Vector2i = Vector2i(caster.x, caster.z)
	_until(sim, 16)
	assert_eq(Vector2i(caster.x, caster.z), p0, "within keep_cm 600 ± 200 (604): it stays")
	caster.x = 0
	caster.z = 0
	sim.step()
	assert_eq([caster.x, caster.z], [0, -12], "nearer than 400: back towards 600 (12 cm per tick)")
	_until(sim, 60)
	assert_eq([caster.x, caster.z], [0, -204], "and back within the band (d = 404) it stands (07 §3.5.3)")
	caster.x = 0
	caster.z = -440
	kai.z = 400
	kai.sample = [sim.tick(), 0, 400, 0, 0, 0]
	sim.step()
	assert_eq([caster.x, caster.z], [0, -428], "farther than 800 (840): nearer again")


func test_partner_follows_the_controlled_unit() -> void:
	var sim: RtSim = RtKit.sim_no_ai(RtKit.dummy_cmd(), 6)
	var mop: RtUnit = sim.unit("p1")
	var kai: RtUnit = sim.unit("p0")
	mop.x = -400
	mop.z = -500
	var goal: Array[int] = RtSim.Movement.goal_for(sim, mop, null)
	var want: Vector2i = DetMath.toward(kai.x, kai.z, mop.x, mop.z, 700 - 30)
	assert_eq(goal, [want.x, want.y] as Array[int], "back to follow_cm 700 − 30 of the controlled unit")
	mop.x = -300
	mop.z = 0
	assert_eq(RtSim.Movement.goal_for(sim, mop, null).size(), 0, "within 700: no goal")


func test_repulsion() -> void:
	var sim: RtSim = RtKit.sim_no_ai(RtKit.encounter("enc_rt_rats", [["g", "enc_rt_rats", [0, -300, 128]]]), 6)
	var a: RtUnit = sim.unit("e0")
	var b: RtUnit = sim.unit("e1")
	_until(sim, 16)
	for u: RtUnit in [a, b]:
		u.goal = []
	a.x = 0
	a.z = 0
	b.x = 0
	b.z = 0
	RtSim.Movement.move_units(sim, sim.tick())
	assert_eq([a.x, a.z, b.x, b.z], [-30, 0, 30, 0], "the same spot: apart along x, half the overlap each")
	a.x = 0
	b.x = 40
	RtSim.Movement.move_units(sim, sim.tick())
	assert_eq([a.x, b.x], [-10, 50], "overlap 20: 10 each")
	var d: RtSim = RtKit.sim_no_ai(RtKit.encounter("enc_rt_dummies", [["g", "enc_rt_dummies", [0, -200, 128]]]), 6)
	var d0: RtUnit = d.unit("e0")
	var d1: RtUnit = d.unit("e1")
	d0.x = 0
	d0.z = 0
	d1.x = 0
	d1.z = 0
	RtSim.Movement.move_units(d, d.tick())
	assert_eq([d0.x, d1.x], [0, 0], "stationary units stay")


func test_no_movement_while_casting_or_held_and_speed_factors() -> void:
	var sim: RtSim = RtKit.sim_no_ai(RtKit.encounter("enc_f1_a2", [["g", "enc_f1_a2", [0, -300, 128]]]), 6)
	for u: RtUnit in sim.units():
		u.auto_on = false
	var rat: RtUnit = sim.unit("e0")
	rat.cast = {"skill": "skl_e_test_hex", "target": "p0", "targets": ["p0"], "x": rat.x, "z": rat.z, "start": 0,
		"end": 10, "interruptible": true, "worthy": true, "moving_cancels": false, "channel": false, "period": 0,
		"next_tick": -1, "tele": -1, "kind": "ability", "item": "", "ai": true, "cmd": 1}
	_until(sim, 10)
	assert_eq([rat.x, rat.z], [0, -300], "no step during the own cast")
	sim.step()
	assert_eq(rat.z, -288, "walks again after it")
	StatusFx.apply(sim, "p0", rat, "sts_stun", 0, 1000)
	_until(sim, sim.tick() + 10)
	assert_eq(rat.z, -288, "stunned: held")
	StatusFx.remove(sim, rat, "sts_stun")
	StatusFx.apply(sim, "p0", rat, "sts_slow", 0, 1000)
	var z0: int = rat.z
	sim.step()
	assert_eq(rat.z - z0, 7, "slowed: 12 × 600 ‰")
	StatusFx.remove(sim, rat, "sts_slow")
	StatusFx.apply(sim, "", rat, "sts_dazed", 0, 1000, 0, null, true)
	z0 = rat.z
	sim.step()
	assert_eq(rat.z - z0, 6, "dazed: 12 × 500 ‰")


func test_enemies_stay_in_the_ring() -> void:
	var sim: RtSim = RtKit.sim_no_ai(RtKit.encounter("enc_f1_a2", [["g", "enc_f1_a2", [0, 300, 0]]]), 6)
	var rat: RtUnit = sim.unit("e0")
	var kai: RtUnit = sim.unit("p0")
	for u: RtUnit in sim.units():
		u.auto_on = false
	var z: int = kai.z
	for _i in 60:
		z = maxi(z - 18, -760)
		sim.submit(RtCommand.move(sim.tick(), "p0", 0, z, 0, -180, 0))
		sim.step()
		assert_true(DetMath.dist2(rat.x, rat.z, 0, 0) <= 450 * 450, "never outside r − radius (tick %d)" % sim.tick())
	assert_eq(kai.z, -760, "Kai stands in the north lane")
	var mop: RtUnit = sim.unit("p1")
	mop.x = 0
	mop.z = -600
	mop.goal = [0, -700]
	RtSim.Movement.move_units(sim, sim.tick())
	assert_eq([mop.x, mop.z], [0, -618], "the partner follows the fleeing controlled unit into the lane")
	var inside: RtSim = RtKit.sim_no_ai(RtKit.encounter("enc_f1_a2", [["g", "enc_f1_a2", [0, -300, 0]]]), 6)
	var m2: RtUnit = inside.unit("p1")
	m2.x = 0
	m2.z = -600
	m2.goal = [0, -700]
	RtSim.Movement.move_units(inside, inside.tick())
	assert_eq([m2.x, m2.z], [0, -445], "otherwise the lane is closed to it: clamped onto the ring")
