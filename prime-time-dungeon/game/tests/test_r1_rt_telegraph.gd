extends TestCase
## 07 §6.3, §5.5, §12.5 test_r1_rt_telegraph. R1b-I2: the shape test of every form ("Fußpunkt-Regel": circle, cone,
## ring, line; boundaries included, only inside the set ring), the shape grown by a margin for the AI's dodging
## (contains_inflated, the cone against a float reference of the true distance — floats allowed in tests), the
## canonical snapshot, RtSim.add_telegraph (ids, the set radius). R1b-I3: the TELEGRAPH_START format and every anchor
## (self, target_pos, each_enemy, random, lane alternating), the impact only in its tick (percent hit, telegraph_hits),
## dodges and close dodges by the mandatory sample of the impact tick (sim side), only inside the ring, zones (periods,
## status / tick skill, end), interrupt and KO remove pending telegraphs, MAX_TELEGRAPHS, the train kills adds, the
## Vorabend warning time, the dash.

const S := RtTelegraph.Shape
const T := ActionEvent.Type
const K := BattleCommand.Kind
const Damage := preload("res://core/rt/rt_damage.gd")
const Boss := preload("res://core/rt/rt_boss.gd")
const FixedMath := preload("res://core/stats/fixed_math.gd")


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


# --- R1b-I3: telegraph skills in the sim ------------------------------------------------------------------------------

## A combat against the stationary dummy e0 at (0, −50) — Kai (controlled) at (0, 200), Mopsula at (−150, 300), held in
## place (stationary) —, no rules, no auto-attacks: the dummy is the caster of the tests.
func _combat(cmd: Dictionary = {}, level: int = 6) -> RtSim:
	var sim: RtSim = RtKit.sim_no_ai(cmd if not cmd.is_empty() else RtKit.dummy_cmd(), level)
	for u: RtUnit in sim.units_ref():
		u.auto_on = false
	sim.unit("p1").stationary = true
	return sim


## The dummy casts `skill` once on the rule target `target` at its next thinking tick (after a running cast; the
## party healed up first, so a series of casts never ends the combat): the events up to and with its CAST_START.
func _cast(sim: RtSim, skill: String, target: String = "threat_top", caster: String = "e0") -> Array[ActionEvent]:
	var e: RtUnit = sim.unit(caster)
	var out: Array[ActionEvent] = []
	while not e.cast.is_empty() and not sim.is_finished():
		out.append_array(sim.step())
	for u: RtUnit in sim.party_ref():
		u.hp = u.max_hp()
	e.rules = RtRules.compile([{"skill": skill, "target": target, "once": true}], "t%d" % sim.tick())
	var guard: int = 0
	while guard < 60 and not sim.is_finished() and RtKit.of(out, T.CAST_START).filter(func(x: ActionEvent) -> bool:
			return x.actor_id == caster and x.skill_id == skill).is_empty():
		out.append_array(sim.step())
		guard += 1
	return out


func _until(sim: RtSim, ct: int) -> Array[ActionEvent]:
	var out: Array[ActionEvent] = []
	while sim.tick() < ct and not sim.is_finished():
		out.append_array(sim.step())
	return out


static func _starts(ev: Array[ActionEvent]) -> Array[ActionEvent]:
	return RtKit.of(ev, T.TELEGRAPH_START)


func test_telegraph_start_format_and_anchors() -> void:
	var sim: RtSim = _combat()
	var ev: Array[ActionEvent] = _cast(sim, "skl_e_rt_cone")
	var cs: ActionEvent = RtKit.of(ev, T.CAST_START)[0]
	var ts: ActionEvent = _starts(ev)[0]
	var c: int = cs.tick
	assert_eq([ts.tick, ts.actor_id, ts.skill_id, ts.value, ts.by_ai], [c, "e0", "skl_e_rt_cone", 1, true])
	assert_eq(ts.rt, {"shape": int(S.CONE), "x": 0, "z": -50, "yaw": 128, "r": 400, "r2": 0, "half": 45, "start": c,
		"impact": c + 54}, "TELEGRAPH_START rt = {shape, x, z, yaw, r, r2, half, start, impact} (07 §3.13): the cone "
		+ "from the caster towards the rule target, 1.8 s warning")
	assert_eq([cs.value, int(cs.rt["end"]), cs.success], [54, c + 54, false], "the cast bar ends at the impact")
	assert_eq(ts.rt.keys().size(), 9)
	_until(sim, c + 55)
	var slam: Array[ActionEvent] = _starts(_cast(sim, "skl_e_test_slam", "farthest_enemy"))
	assert_eq([slam[0].rt["shape"], slam[0].rt["x"], slam[0].rt["z"], slam[0].rt["r"]], [int(S.CIRCLE), -150, 300, 250],
		"target_pos: at the rule target (Mopsula) when the cast starts")
	_until(sim, sim.tick() + 31)
	var fog: Array[ActionEvent] = _starts(_cast(sim, "skl_e_rt_fog", "none"))
	assert_eq(fog.map(func(e: ActionEvent) -> Array: return [e.rt["x"], e.rt["z"], e.value]),
		[[0, 200, fog[0].value], [-150, 300, fog[0].value + 1]], "each_enemy: one per party unit, unit order")
	_until(sim, sim.tick() + 31)
	var n0: int = int(sim.snapshot()["rng_n"])
	var rnd: Array[ActionEvent] = _starts(_cast(sim, "skl_e_rt_puddles", "none"))
	assert_eq([rnd.size(), int(sim.snapshot()["rng_n"]) - n0], [3, 1], "random: 3 points from one combat-stream draw")
	for i in rnd.size():
		var x: int = int(rnd[i].rt["x"])
		var z: int = int(rnd[i].rt["z"])
		assert_true(x * x + z * z <= 420 * 420, "inside geo.r − 60")
		for j in range(i + 1, rnd.size()):
			assert_true(DetMath.dist2(x, z, int(rnd[j].rt["x"]), int(rnd[j].rt["z"])) >= 300 * 300, "≥ 300 cm apart")
	_until(sim, sim.tick() + 46)
	var lanes: Array = []
	for _k in 3:
		var lane: Array[ActionEvent] = _starts(_cast(sim, "skl_e_rt_lanes", "none"))
		lanes.append([lane[0].rt["x"], lane[0].rt["z"], lane[0].rt["yaw"], lane[0].rt["r"], lane[0].rt["r2"]])
	assert_eq(lanes, [[-480, -200, 192, 960, 150], [-480, 200, 192, 960, 150], [-480, -200, 192, 960, 150]],
		"lane: the chord along x (2 × geo.r), the z offsets of `lanes` alternating from the first")
	_until(sim, sim.tick() + 61)
	var ring: ActionEvent = _starts(_cast(sim, "skl_e_rt_ring", "self"))[0]
	assert_eq([ring.rt["shape"], ring.rt["x"], ring.rt["z"], ring.rt["r"], ring.rt["r2"]], [int(S.RING), 0, -50, 1200,
		300], "ring around the caster")
	_until(sim, sim.tick() + 91)
	var line: ActionEvent = _starts(_cast(sim, "skl_e_rt_lunge", "threat_top"))[0]
	assert_eq([line.rt["shape"], line.rt["x"], line.rt["z"], line.rt["yaw"], line.rt["r"], line.rt["r2"]],
		[int(S.LINE), 0, -50, 128, 800, 150], "line from the caster towards the rule target")


func test_impact_only_in_its_tick() -> void:
	var sim: RtSim = _combat()
	var kai: RtUnit = sim.unit("p0")
	var ev: Array[ActionEvent] = _cast(sim, "skl_e_test_slam")
	var t0: RtTelegraph = sim.telegraphs()[0]
	var impact: int = t0.impact_at
	assert_eq(impact, RtKit.of(ev, T.CAST_START)[0].tick + 30)
	ev = _until(sim, impact)
	assert_eq(RtKit.of(ev, T.DAMAGE).size() + RtKit.of(ev, T.TELEGRAPH_IMPACT).size(), 0, "nothing before the impact")
	ev = sim.step()
	var imp: Array[ActionEvent] = RtKit.of(ev, T.TELEGRAPH_IMPACT)
	assert_true(imp.size() == 1 and imp[0].tick == impact and imp[0].target_ids.has("p0"), "the impact hits Kai")
	var dmg: Array = RtKit.of(ev, T.DAMAGE).filter(func(e: ActionEvent) -> bool: return e.target_id == "p0")
	assert_eq(dmg[0].amount, FixedMath.div_round(kai.max_hp() * 25, 100), "a percent hit: 25 % of the max HP")
	assert_eq([int(sim.tally["telegraph_hits"]), sim.telegraphs().size()], [1, 0], "the person's figure was hit; gone")
	var ends: Array = RtKit.of(ev, T.ACTION_END).filter(func(e: ActionEvent) -> bool: return e.actor_id == "e0")
	assert_eq(ends.size(), 1, "the telegraph cast ends without another effect in step 6")
	assert_true(ev.find(imp[0]) < ev.find(ends[0]))


## 07 §6.3 "Ausweichfenster": only the impact tick decides; the mandatory sample of that tick (R2 sends it, 07 §3.5)
## counts — the position of step 1a of the impact tick. close = still inside ≤ CLOSE_DODGE_TICKS before.
func test_dodges_by_the_sample_of_the_impact_tick() -> void:
	for case: Array in [["close", 3, 0], ["not close", 12, 0], ["late sample", 3, 1]]:
		var sim: RtSim = _combat()
		var kai: RtUnit = sim.unit("p0")
		_cast(sim, "skl_e_test_slam")
		var impact: int = sim.telegraphs()[0].impact_at
		var leave: int = impact - int(case[1]) if str(case[0]) == "not close" else impact + int(case[2])
		_until(sim, impact - 15)
		kai.x = 0
		kai.z = 445                                                   # inside: |445 − 200| = 245 ≤ 250
		kai.sample = [sim.tick(), 0, 445, 0, 0, 128]
		assert_eq(sim.submit(RtCommand.move(leave, "p0", 0, 460, 0, 0, 128)), "")
		var ev: Array[ActionEvent] = _until(sim, impact + 1)
		var dodge: Array[ActionEvent] = RtKit.of(ev, T.TELEGRAPH_DODGED).filter(func(e: ActionEvent) -> bool:
			return e.target_id == "p0")
		var hit: bool = RtKit.of(ev, T.TELEGRAPH_IMPACT)[0].target_ids.has("p0")
		match str(case[0]):
			"close":
				assert_true(not hit and dodge.size() == 1 and dodge[0].success and not dodge[0].by_ai,
					"the sample of the impact tick leaves the circle: a close dodge (inside until the tick before)")
				assert_eq(int(sim.tally["dodges"]), 1, "counted for the person")
			"not close":
				assert_true(not hit and dodge.size() == 1 and not dodge[0].success, "left 12 ticks before: no close dodge")
			"late sample":
				assert_true(hit and dodge.is_empty(), "a sample of the next tick is too late")


func test_only_inside_the_ring_in_the_sim() -> void:
	var sim: RtSim = _combat()
	var kai: RtUnit = sim.unit("p0")
	kai.x = 0
	kai.z = 440
	kai.sample = [sim.tick(), 0, 440, 0, 0, 128]
	_cast(sim, "skl_e_test_slam")                                     # circle r 250 at (0, 440) — reaches the lane
	var impact: int = sim.telegraphs()[0].impact_at
	_until(sim, impact - 2)
	kai.x = 0
	kai.z = 520                                                       # the south door lane (outside the ring 480)
	kai.sample = [sim.tick(), 0, 520, 0, 0, 128]
	var ev: Array[ActionEvent] = _until(sim, impact + 1)
	assert_false(RtKit.of(ev, T.TELEGRAPH_IMPACT)[0].target_ids.has("p0"), "in the door lane: not hit (07 §6.3)")


func test_zones() -> void:
	var sim: RtSim = _combat()
	var kai: RtUnit = sim.unit("p0")
	_cast(sim, "skl_e_rt_spill")
	var impact: int = sim.telegraphs()[0].impact_at
	var ev: Array[ActionEvent] = _until(sim, impact + 1)
	var zs: Array[ActionEvent] = RtKit.of(ev, T.ZONE_START)
	assert_eq(zs.size(), 1)
	var z: ActionEvent = zs[0]
	assert_eq([z.tick, z.actor_id, z.skill_id, z.status_id, z.value], [impact, "e0", "skl_e_rt_spill", "", 2])
	assert_eq(z.rt, {"shape": int(S.CIRCLE), "x": 0, "z": 200, "yaw": 128, "r": 300, "r2": 0, "half": 0,
		"start": impact, "end": impact + 180}, "ZONE_START rt = geometry + end (07 §3.13)")
	var hits: int = int(sim.tally["telegraph_hits"])
	ev = _until(sim, impact + 182)
	var ticks: Array = RtKit.of(ev, T.DAMAGE).filter(func(e: ActionEvent) -> bool:
		return e.target_id == "p0" and e.skill_id == "skl_e_rt_spill_tick").map(func(e: ActionEvent) -> int: return e.tick)
	assert_eq(ticks, [impact + 60, impact + 120, impact + 180], "a period after the impact, the last one before the end")
	assert_eq(RtKit.of(ev, T.DAMAGE).filter(func(e: ActionEvent) -> bool: return e.skill_id == "skl_e_rt_spill_tick")[0]
		.amount, FixedMath.div_round(kai.max_hp() * 5, 100), "the tick skill: a percent hit")
	var ends: Array[ActionEvent] = RtKit.of(ev, T.ZONE_END)
	assert_true(ends.size() == 1 and ends[0].tick == impact + 180 and ends[0].value == 2, "ZONE_END at its end")
	assert_eq([int(sim.tally["telegraph_hits"]), sim.telegraphs().size()], [hits, 0], "zone ticks are no telegraph hits")
	var fog: RtSim = _combat()
	_cast(fog, "skl_e_rt_fog", "none")
	var fi: int = fog.telegraphs()[0].impact_at
	var fev: Array[ActionEvent] = _until(fog, fi + 62)
	var poison: Array = RtKit.of(fev, T.STATUS_ADDED).filter(func(e: ActionEvent) -> bool:
		return e.status_id == "sts_poison" and e.tick == fi + 60)
	assert_eq(poison.size(), 4, "status zones: the status on every party unit inside, per zone (2 zones × 2 units)")


func test_interrupt_and_ko_remove_pending_telegraphs() -> void:
	var sim: RtSim = _combat()
	_cast(sim, "skl_e_rt_charge", "self")
	var id: int = sim.telegraphs()[0].id
	sim.submit(RtCommand.ability(sim.tick(), "p0", "skl_kai_leash_trip", "e0"))
	var ev: Array[ActionEvent] = _until(sim, sim.tick() + 12)
	var cut: Array[ActionEvent] = RtKit.of(ev, T.CAST_INTERRUPTED)
	var gone: Array[ActionEvent] = RtKit.of(ev, T.TELEGRAPH_CANCELLED)
	assert_true(cut.size() == 1 and gone.size() == 1 and gone[0].value == id and gone[0].tick == cut[0].tick,
		"an interruption removes the cast's telegraph (TELEGRAPH_CANCELLED)")
	assert_true(sim.telegraphs().is_empty())
	assert_eq(RtKit.of(_until(sim, sim.tick() + 80), T.TELEGRAPH_IMPACT).size(), 0, "and it never strikes")
	var ko: RtSim = _combat()
	var e0: RtUnit = ko.unit("e0")
	_cast(ko, "skl_e_test_slam")
	Boss.run_ops(ko, e0, [{"op": "telegraph", "skill": "skl_e_test_slam"}])    # a phase-op shape, no cast
	assert_eq(ko.telegraphs().size(), 2)
	var mark: int = ko.out_len()
	Damage.apply(ko, ko.unit("p0"), e0, 99999, Elements.PHYSICAL, HitResult.new(), "skl_kai_heavy_swing", "", "",
		Damage.Kind.ABILITY, false, K.SKILL, 1000)
	var kev: Array = ko.out_from(mark).map(func(e: ActionEvent) -> String:
		return "%s %d" % [ActionEvent.type_name(e.type), e.value if e.type == T.TELEGRAPH_CANCELLED else 0])
	assert_eq(kev.slice(0, 5), ["DAMAGE 0", "KO 0", "CAST_FAILED 0", "TELEGRAPH_CANCELLED 1", "ACTION_END 0"],
		"the KO: the cast fails and takes its telegraph along …")
	assert_true(kev.has("TELEGRAPH_CANCELLED 2") and ko.telegraphs().is_empty(), "… and every other pending shape")


func test_zones_stay_after_the_caster_falls() -> void:
	var sim: RtSim = _combat()
	_cast(sim, "skl_e_rt_spill")
	_until(sim, sim.telegraphs()[0].impact_at + 1)
	assert_true(sim.telegraphs().size() == 1 and sim.telegraphs()[0].is_zone)
	Damage.apply(sim, sim.unit("p0"), sim.unit("e0"), 99999, Elements.PHYSICAL, HitResult.new(), "skl_kai_heavy_swing",
		"", "", Damage.Kind.ABILITY, false, K.SKILL, 1000)
	assert_eq(sim.telegraphs().size(), 1, "a zone lies on the ground (only pending telegraphs end with the caster)")


func test_max_telegraphs() -> void:
	var sim: RtSim = _combat()
	for k in 10:
		var z: RtTelegraph = _t(S.CIRCLE, -300 + 60 * k, -300, 0, 50, 0)
		z.side = Combatant.Side.PARTY
		z.is_zone = true
		z.impact_at = -1
		z.ends_at = 900
		z.period = 60
		z.next_tick_at = 60
		assert_eq(sim.add_telegraph(z), k + 1)
	var mark: int = sim.out_len()
	var t: RtTelegraph = _t(S.CIRCLE, 0, 300, 0, 50, 0)
	t.side = Combatant.Side.PARTY
	t.impact_at = sim.tick() + 30
	assert_eq(sim.add_telegraph(t), 11)
	var ev: Array = sim.out_from(mark).map(func(e: ActionEvent) -> Array: return [ActionEvent.type_name(e.type), e.value])
	assert_eq(ev.slice(0, 2), [["ZONE_END", 1], ["TELEGRAPH_START", 11]], "the oldest zone ends early")
	assert_eq(sim.telegraphs().size(), 10)
	var full: RtSim = _combat()
	for k in 10:
		var p: RtTelegraph = _t(S.CIRCLE, -300 + 60 * k, -300, 0, 50, 0)
		p.side = Combatant.Side.PARTY
		p.impact_at = full.tick() + 100
		full.add_telegraph(p)
	var extra: RtTelegraph = _t(S.CIRCLE, 0, 0, 0, 50, 0)
	extra.side = Combatant.Side.PARTY
	extra.impact_at = full.tick() + 100
	var m2: int = full.out_len()
	assert_eq([full.add_telegraph(extra), full.telegraphs().size(), full.out_from(m2).size()], [0, 10, 0],
		"no zone to end: the shape is not placed")


func test_train_kills_adds() -> void:
	var sim: RtSim = _combat(RtKit.encounter("enc_rt_dummies", [["g", "enc_rt_dummies", [0, -50, 128]]]))
	var caster: RtUnit = sim.unit("e0")
	var rat: RtUnit = Boss.summon(sim, caster, "enm_kanalratte", "near", 0)
	assert_true(rat != null and rat.is_summon)
	rat.x = 200
	rat.z = 0
	rat.stationary = true
	rat.rules = []
	var other: RtUnit = sim.unit("e1")
	other.x = -200
	other.z = 60
	sim.unit("e2").z = -300
	var ev: Array[ActionEvent] = _cast(sim, "skl_e_test_train", "none")
	var impact: int = sim.telegraphs()[0].impact_at
	ev = _until(sim, impact + 1)
	var imp: ActionEvent = RtKit.of(ev, T.TELEGRAPH_IMPACT)[0]
	assert_eq(Array(imp.target_ids), [other.id, rat.id], "the train hits its own side too (not the caster)")
	var kos: Array[ActionEvent] = RtKit.of(ev, T.KO)
	assert_true(kos.size() == 1 and kos[0].target_id == rat.id and kos[0].command == -1 and kos[0].by_ai \
		and kos[0].actor_id == "e0", "the summoned add is KO'd at once (KO command −1)")
	var od: Array = RtKit.of(ev, T.DAMAGE).filter(func(e: ActionEvent) -> bool: return e.target_id == other.id)
	assert_eq(od[0].amount, FixedMath.div_round(other.max_hp() * 35, 100), "a non-summon takes the percent hit")
	assert_eq(int(sim.tally["train_kills"]), 1)
	assert_eq(RtKit.of(ev, T.DAMAGE).filter(func(e: ActionEvent) -> bool: return e.target_id.begins_with("p")).size(), 0,
		"the party stands outside the lane")


func test_vorabend_warning_time() -> void:
	var sim: RtSim = _combat(RtKit.dummy_cmd({"diff": "vorabend"}))
	var ev: Array[ActionEvent] = _cast(sim, "skl_e_test_slam")
	var cs: ActionEvent = RtKit.of(ev, T.CAST_START)[0]
	var ts: ActionEvent = _starts(ev)[0]
	assert_eq([cs.value, int(ts.rt["impact"]) - cs.tick], [38, 38], "30 ticks × EASY_WARN_PM 1250 = 37.5 → 38")


func test_dash() -> void:
	var sim: RtSim = _combat()
	var dummy: RtUnit = sim.unit("e0")
	_cast(sim, "skl_e_rt_lunge")
	var ev: Array[ActionEvent] = _until(sim, sim.telegraphs()[0].impact_at + 1)
	assert_eq([dummy.x, dummy.z, RtKit.of(ev, T.POS_CORRECTED).size()], [0, -50, 0], "a stationary caster never dashes")
	dummy.stationary = false
	_cast(sim, "skl_e_rt_lunge")
	ev = _until(sim, sim.telegraphs()[0].impact_at + 1)
	var pc: Array = RtKit.of(ev, T.POS_CORRECTED).filter(func(e: ActionEvent) -> bool: return e.target_id == "e0")
	assert_eq([dummy.x, dummy.z], [0, 440], "the line end (0, 750) projected into the ring (480 − 40)")
	assert_true(pc.size() == 1 and pc[0].rt == {"x": 0, "z": 440}, "POS_CORRECTED: the scene sets the dashing figure")
