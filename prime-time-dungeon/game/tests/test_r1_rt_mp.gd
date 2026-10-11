extends TestCase
## 07 §3.10 (R1b-I1) test_r1_rt_mp: the MP economy — Kai charges +1 per own landed auto-attack and +1 per taken hit
## (auto, ability; never status ticks) at most once per 30 ticks, without time regeneration; Mopsula +1 every 45 ticks
## from ct 0, also while casting; costs at the effect (instants and channels at their start, casts at their end — a
## cast without the MP at its end fails with CAST_FAILED "mp"); "mp" refusals.

const Damage := preload("res://core/rt/rt_damage.gd")
const StatusFx := preload("res://core/rt/rt_status_fx.gd")
const T := ActionEvent.Type
const K := BattleCommand.Kind


func _sim(hero: String = "kai", st: GameState = null) -> RtSim:
	var sim: RtSim = RtKit.sim_no_ai(RtKit.dummy_cmd({"ctl": "p0" if hero == "kai" else "p1"}), 6, hero, st)
	for u: RtUnit in sim.units():
		u.auto_on = false
	return sim


func _until(sim: RtSim, ct: int) -> Array[ActionEvent]:
	var out: Array[ActionEvent] = []
	while sim.tick() < ct and not sim.is_finished():
		out.append_array(sim.step())
	return out


static func _mp(events: Array[ActionEvent], id: String) -> Array:
	return RtKit.of(events, T.MP_CHANGE).filter(func(x: ActionEvent) -> bool: return x.target_id == id).map(
		func(x: ActionEvent) -> Array: return [x.tick, x.amount])


func test_kai_charges_by_hitting_and_being_hit() -> void:
	var sim: RtSim = _sim()
	var kai: RtUnit = sim.unit("p0")
	var e: RtUnit = sim.unit("e0")
	kai.mp = 0
	kai.auto_on = true
	e.auto_on = true
	sim.submit(RtCommand.target(0, "p0", "e0"))
	var ev: Array[ActionEvent] = _until(sim, 130)
	assert_eq(_mp(ev, "p0"), [[9, 1], [39, 1], [69, 1], [129, 1], [129, 1]],
		"own hits at 9 / 69 / 129, taken hits at 39 / 129 (the dummy swings every 90 ticks from 30)")
	assert_eq(kai.mp, 5)
	var hits: RtSim = _sim()
	var k2: RtUnit = hits.unit("p0")
	k2.mp = 0
	for _i in 3:
		Damage.apply(hits, hits.unit("e0"), k2, 1, Elements.PHYSICAL, HitResult.new(), "skl_e_dummy_poke", "", "",
			Damage.Kind.AUTO, true, K.ATTACK, 1000)
	assert_eq(k2.mp, 1, "at most one taken-hit MP per 30 ticks")
	_until(hits, 30)
	Damage.apply(hits, hits.unit("e0"), k2, 1, Elements.PHYSICAL, HitResult.new(), "skl_e_test_hex", "", "",
		Damage.Kind.ABILITY, true, K.SKILL, 1000)
	assert_eq(k2.mp, 2, "30 ticks later an ability hit charges again")
	StatusFx.apply(hits, "e0", k2, "sts_poison", 0, 1000)
	ev = _until(hits, 200)
	assert_eq(_mp(ev, "p0"), [], "poison ticks never charge; no time regeneration")
	assert_gt(RtKit.of(ev, T.DAMAGE).size(), 1)


func test_mopsula_regenerates_over_time() -> void:
	var sim: RtSim = _sim("mopsula")
	var mop: RtUnit = sim.unit("p1")
	mop.mp = 4
	sim.submit(RtCommand.target(0, "p1", "e0"))
	var ev: Array[ActionEvent] = _until(sim, 40)
	assert_eq(sim.submit(RtCommand.ability(40, "p1", "skl_mop_noble_flame", "")), "")
	ev.append_array(_until(sim, 136))
	assert_eq(_mp(ev, "p1"), [[45, 1], [85, -4], [90, 1], [135, 1]],
		"+1 every 45 ticks from ct 0, also while casting; the cast pays at its end (85)")
	Damage.apply(sim, sim.unit("e0"), mop, 5, Elements.PHYSICAL, HitResult.new(), "skl_e_dummy_poke", "", "",
		Damage.Kind.AUTO, true, K.ATTACK, 1000)
	assert_eq(mop.mp, 3, "no MP from hits")


func test_costs_at_the_effect() -> void:
	var st: GameState = RtKit.state(6)
	st.member("kai").rt_loadout = {"4": "skl_kai_deo_torch"}
	var sim: RtSim = _sim("kai", st)
	var kai: RtUnit = sim.unit("p0")
	var r: Array = RtKit.act(sim, RtCommand.ability(0, "p0", "skl_kai_heavy_swing", "e0"))
	assert_eq(_mp(r[1], "p0"), [[0, -2]], "an instant pays at its start")
	_until(sim, 45)
	r = RtKit.act(sim, RtCommand.ability(45, "p0", "skl_kai_deo_torch", "e0"))
	assert_eq(_mp(r[1], "p0"), [[45, -7]], "a channel too")
	assert_eq(RtKit.of(r[1], T.CAST_START).size(), 1)
	kai.mp = 1
	assert_eq(sim.can_use("p0", "skl_kai_leash_trip", "e0"), "mp")
	var mop: RtSim = _sim("mopsula")
	var m: RtUnit = mop.unit("p1")
	m.mp = 8
	mop.submit(RtCommand.target(0, "p1", "e0"))
	mop.submit(RtCommand.ability(0, "p1", "skl_mop_noble_flame", ""))
	mop.submit(RtCommand.ability(0, "p1", "skl_mop_thunder_bark", ""))
	var ev: Array[ActionEvent] = _until(mop, 46)
	assert_eq(_mp(ev, "p1"), [[0, -5], [45, 1]], "the GCD-free bark pays at once; the flame finds 4 MP missing")
	var fail: Array[ActionEvent] = RtKit.of(ev, T.CAST_FAILED)
	assert_true(fail.size() == 1 and fail[0].tick == 45 and fail[0].text == "mp" and fail[0].skill_id == \
		"skl_mop_noble_flame", "CAST_FAILED mp at the cast end (before the regeneration of step 11)")
	assert_eq(RtKit.of(ev, T.ACTION_END).filter(func(x: ActionEvent) -> bool: return x.actor_id == "p1").size(), 2)
	assert_eq(m.mp, 4, "nothing paid for the failed cast")
