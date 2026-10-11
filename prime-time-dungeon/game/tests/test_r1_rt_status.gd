extends TestCase
## 07 §3.8 (R1b-I1) test_r1_rt_status: poison stacks (3, period 60, min 1, max 12, bosses × 0.5), frozen power ticks,
## refresh / replace / ignore keeping the period phase, excludes, the stun interrupts and holds, boss durations × 0.5,
## dazed (first strike / ambush, bosses spared), regeneration, cleanse, immunity and resistance (seeded rolls), the
## last tick before the expiry, KO clears every status.

const StatusFx := preload("res://core/rt/rt_status_fx.gd")
const FixedMath := preload("res://core/stats/fixed_math.gd")
const T := ActionEvent.Type


func _sim(level: int = 6, hero: String = "kai", st: GameState = null) -> RtSim:
	var sim: RtSim = RtKit.sim_no_ai(RtKit.dummy_cmd({"ctl": "p0" if hero == "kai" else "p1"}), level, hero, st)
	for u: RtUnit in sim.units():
		u.auto_on = false
	return sim


func _boss_sim() -> RtSim:
	var sim: RtSim = RtKit.sim(RtKit.encounter("enc_rt_test_boss", [["g_b", "enc_rt_test_boss", [0, -300, 128]]]), 6)
	for u: RtUnit in sim.units():
		u.auto_on = false
	return sim


func _until(sim: RtSim, ct: int) -> Array[ActionEvent]:
	var out: Array[ActionEvent] = []
	while sim.tick() < ct and not sim.is_finished():
		out.append_array(sim.step())
	return out


## Events of `type` about status `status_id`.
static func _of(events: Array[ActionEvent], type: ActionEvent.Type, status_id: String) -> Array[ActionEvent]:
	var out: Array[ActionEvent] = []
	for e: ActionEvent in RtKit.of(events, type):
		if e.status_id == status_id:
			out.append(e)
	return out


static func _rng_n(sim: RtSim) -> int:
	return int(sim.snapshot()["rng_n"])


func test_poison_stacks_and_period() -> void:
	var sim: RtSim = _sim()
	var kai: RtUnit = sim.unit("p0")
	var st: RtStatus = StatusFx.apply(sim, "e0", kai, "sts_poison", 0, 1000)
	assert_eq([st.stacks, st.period, st.next_tick_at, st.ends_at, st.source_id], [1, 60, 60, 180, "e0"],
		"rt.default_ms 6000 = 180 ticks, period 60 from the application")
	var per: int = clampi(FixedMath.div_round(kai.max_hp() * 2, 100), 1, 12)
	var d: Array[ActionEvent] = _of(_until(sim, 70), T.DAMAGE, "sts_poison")
	assert_eq(d.size(), 1)
	if d.size() == 1:
		assert_eq([d[0].tick, d[0].actor_id, d[0].target_id, d[0].amount, d[0].element, d[0].skill_id],
			[60, "", "p0", per, "poison", ""], "2 % of max HP; a status tick has no actor")
	assert_eq(StatusFx.apply(sim, "e0", kai, "sts_poison", 0, 1000), st, "refresh keeps the status")
	assert_eq([st.stacks, st.next_tick_at, st.ends_at], [2, 120, 250], "refresh: +1 stack, new end, same phase")
	d = _of(_until(sim, 121), T.DAMAGE, "sts_poison")
	assert_eq(d.map(func(e: ActionEvent) -> int: return e.amount), [2 * per], "the tick counts every stack")
	StatusFx.apply(sim, "e0", kai, "sts_poison", 0, 1000)
	StatusFx.apply(sim, "e0", kai, "sts_poison", 0, 1000)
	assert_eq(st.stacks, 3, "max_stacks 3")
	d = _of(_until(sim, 181), T.DAMAGE, "sts_poison")
	assert_eq(d.map(func(e: ActionEvent) -> int: return e.amount), [3 * per])


func test_last_tick_before_the_expiry() -> void:
	var sim: RtSim = _sim()
	var kai: RtUnit = sim.unit("p0")
	StatusFx.apply(sim, "e0", kai, "sts_poison", 0, 1000)
	var ev: Array[ActionEvent] = _until(sim, 200)
	assert_eq(_of(ev, T.DAMAGE, "sts_poison").map(func(e: ActionEvent) -> int: return e.tick), [60, 120, 180])
	var gone: Array[ActionEvent] = _of(ev, T.STATUS_REMOVED, "sts_poison")
	assert_eq(gone.size(), 1)
	if gone.size() == 1:
		assert_eq(gone[0].tick, 180)
		assert_true(ev.find(gone[0]) > ev.find(_of(ev, T.DAMAGE, "sts_poison")[2]), "the tick on ends_at acts first")
	assert_false(kai.has_status("sts_poison"))


func test_poison_bounds_bosses_and_elements() -> void:
	var sim: RtSim = _sim()
	var kai: RtUnit = sim.unit("p0")
	var e: RtUnit = sim.unit("e0")
	kai.stats.values[StatBlock.Stat.HP] = 20
	kai.hp = 20
	StatusFx.apply(sim, "e0", kai, "sts_poison", 0, 1000)        # 2 % of 20 HP rounds to 0 → tick_min 1
	StatusFx.apply(sim, "p0", e, "sts_poison", 0, 1000)          # 2 % of 2000 HP = 40 → tick_max 12
	var d: Array[ActionEvent] = _of(_until(sim, 61), T.DAMAGE, "sts_poison")
	assert_eq(d.map(func(x: ActionEvent) -> Array: return [x.target_id, x.amount]), [["p0", 1], ["e0", 12]])
	var half: RtSim = _sim()
	half.unit("e0").element_mods = {"poison": 0.5}
	StatusFx.apply(half, "p0", half.unit("e0"), "sts_poison", 0, 1000)
	d = _of(_until(half, 61), T.DAMAGE, "sts_poison")
	assert_eq(d.map(func(x: ActionEvent) -> int: return x.amount), [6], "the status element counts (12 × 0.5)")
	half.unit("p0").element_mods = {"poison": 0.0}
	assert_null(StatusFx.apply(half, "e0", half.unit("p0"), "sts_poison", 0, 1000), "poison-immune: blocked")
	var bs: RtSim = _boss_sim()
	var boss: RtUnit = bs.unit("e0")
	assert_true(boss.is_boss)
	StatusFx.apply(bs, "p0", boss, "sts_poison", 0, 1000)
	d = _of(_until(bs, 61), T.DAMAGE, "sts_poison")
	assert_eq(d.map(func(x: ActionEvent) -> int: return x.amount), [6], "bosses: 12 × boss_tick_pm 500")


func test_power_ticks_are_frozen() -> void:
	var sim: RtSim = _sim()
	var kai: RtUnit = sim.unit("p0")
	var mop: RtUnit = sim.unit("p1")
	var e: RtUnit = sim.unit("e0")
	var a: int = kai.stat(StatBlock.Stat.STR)
	var dd: int = e.stat(StatBlock.Stat.DEF)
	var n0: int = _rng_n(sim)
	var st: RtStatus = StatusFx.apply(sim, "p0", e, "sts_burn", 6000, 1000, 20, sim.skill_def("skl_kai_deo_torch"))
	var want: int = maxi(1, FixedMath.div_round(a * a * 20 * 1500, (a + dd) * 100 * 1000))
	assert_eq(st.amount, want, "A²/(A + D) × 20 / 100 × fire 1.5 of the dummy, no crit, no variance")
	assert_eq(_rng_n(sim), n0, "freezing draws nothing")
	assert_eq([st.period, st.next_tick_at], [30, 30])
	kai.stats.values[StatBlock.Stat.STR] = a * 3
	var d: Array[ActionEvent] = _of(_until(sim, 61), T.DAMAGE, "sts_burn")
	assert_eq(d.map(func(x: ActionEvent) -> Array: return [x.tick, x.amount, x.element]), [[30, want, "fire"],
		[60, want, "fire"]], "frozen: the later STR does not count")
	var m: int = mop.stat(StatBlock.Stat.MAG)
	var r: int = e.stat(StatBlock.Stat.RES)
	StatusFx.apply(sim, "p1", e, "sts_burn", 6000, 1000, 20, sim.skill_def("skl_mop_inferno"))
	assert_eq(st.amount, maxi(1, FixedMath.div_round(m * m * 20 * 1500, (m + r) * 100 * 1000)),
		"a magical skill freezes MAG against RES (a new application freezes anew)")
	assert_eq(st.next_tick_at, 90, "and keeps the phase")


func test_replace_and_ignore() -> void:
	var sim: RtSim = _sim()
	var kai: RtUnit = sim.unit("p0")
	var rg: RtStatus = StatusFx.apply(sim, "p1", kai, "sts_regen", 0, 1000)
	assert_eq([rg.stacks, rg.next_tick_at, rg.ends_at], [1, 60, 300])
	_until(sim, 30)
	assert_eq(StatusFx.apply(sim, "p1", kai, "sts_regen", 0, 1000), rg)
	assert_eq([rg.stacks, rg.next_tick_at, rg.ends_at], [1, 60, 330], "replace: new end, one stack, same phase")
	var e: RtUnit = sim.unit("e0")
	var dz: RtStatus = StatusFx.apply(sim, "", e, "sts_dazed", 0, 1000, 0, null, true)
	assert_eq(dz.ends_at, 30 + 90)
	_until(sim, 40)
	assert_null(StatusFx.apply(sim, "", e, "sts_dazed", 0, 1000, 0, null, true), "ignore: no effect while active")
	assert_eq([dz.ends_at, dz.stacks], [120, 1])


func test_excludes() -> void:
	var st: GameState = RtKit.state(6, "mopsula")
	st.member("mopsula").rt_loadout = {"3": "skl_mop_expert_opinion"}
	var sim: RtSim = _sim(6, "mopsula", st)
	var kai: RtUnit = sim.unit("p0")
	StatusFx.apply(sim, "e0", kai, "sts_slow", 0, 1000)
	var r: Array = RtKit.act(sim, RtCommand.ability(0, "p1", "skl_mop_expert_opinion", "p0"))
	assert_eq(r[0], "")
	var ev: Array[ActionEvent] = sim.step()
	var off: Array[ActionEvent] = _of(ev, T.STATUS_REMOVED, "sts_slow")
	var on: Array[ActionEvent] = _of(ev, T.STATUS_ADDED, "sts_haste")
	assert_true(off.size() == 1 and on.size() == 1 and ev.find(off[0]) < ev.find(on[0]), "Turbo removes Verlangsamt first")
	assert_eq([kai.has_status("sts_slow"), kai.has_status("sts_haste")], [false, true])
	StatusFx.apply(sim, "e0", kai, "sts_slow", 0, 1000)
	assert_eq([kai.has_status("sts_slow"), kai.has_status("sts_haste")], [true, false], "and the other way round")


func test_stun_interrupts_and_holds() -> void:
	var sim: RtSim = _sim(6, "mopsula")
	var mop: RtUnit = sim.unit("p1")
	sim.submit(RtCommand.target(0, "p1", "e0"))
	sim.submit(RtCommand.ability(0, "p1", "skl_mop_noble_flame", ""))
	_until(sim, 2)
	assert_false(mop.cast.is_empty())
	var stun: RtStatus = StatusFx.apply(sim, "e0", mop, "sts_stun", 0, 1000)
	assert_eq(stun.ends_at, 2 + 45, "rt.default_ms 1500")
	assert_true(mop.cast.is_empty(), "interrupt_on_apply breaks the cast")
	assert_eq(mop.lockout_until, 2 + 60, "with the interrupt lockout")
	assert_eq(sim.can_use("p1", "skl_mop_thunder_bark", ""), "stunned", "no_act")
	mop.auto_on = true
	var ev: Array[ActionEvent] = _until(sim, 48)
	assert_eq(RtKit.of(ev, T.SWING).map(func(x: ActionEvent) -> int: return x.tick), [47],
		"no auto-attack while stunned; the first swing in the tick the stun ends")
	assert_eq(_of(ev, T.STATUS_REMOVED, "sts_stun").map(func(x: ActionEvent) -> int: return x.tick), [47])
	assert_eq(sim.can_use("p1", "skl_mop_noble_flame", ""), "locked", "casts wait for the lockout")
	assert_eq(sim.can_use("p1", "skl_mop_thunder_bark", ""), "", "instants do not")
	var drink: RtSim = _sim(6, "kai", null)
	var kai: RtUnit = drink.unit("p0")
	assert_eq(drink.submit(RtCommand.item(0, "p0", "itm_bandage", "")), "")
	drink.step()
	StatusFx.apply(drink, "e0", kai, "sts_stun", 0, 1000)
	assert_eq(str(kai.cast.get("kind", "")), "item", "a drink is not interruptible")
	var bs: RtSim = _boss_sim()
	var b: RtStatus = StatusFx.apply(bs, "p0", bs.unit("e0"), "sts_stun", 0, 1000)
	assert_eq(b.ends_at, FixedMath.mul_pm(45, 500), "bosses: duration × boss_ms_pm 500 (22.5 → 23)")


func test_dazed_by_first_strike_and_ambush() -> void:
	var s: RtSetup = RtKit.setup(RtKit.state(6), RtKit.encounter("enc_rt_rats", [["g", "enc_rt_rats", [0, -300, 128]]],
		{"adv": BattleSetup.Advantage.PREEMPTIVE}))
	assert_eq(s.advantage, BattleSetup.Advantage.PREEMPTIVE)
	s.units[3].is_boss = true                                    # e1 stands in for a boss: bosses are never dazed
	var sim: RtSim = RtSim.new(s, RtKit.data())
	var pre: Array[ActionEvent] = sim.start()
	var an: Array[ActionEvent] = RtKit.of(pre, T.ANNOUNCE)
	assert_true(an.size() == 1 and an[0].text == "Erstschlag!")
	var dz: Array[ActionEvent] = _of(pre, T.STATUS_ADDED, "sts_dazed")
	assert_eq(dz.map(func(x: ActionEvent) -> Array: return [x.target_id, x.value]), [["e0", 90]], "3 s, not the boss")
	var ev: Array[ActionEvent] = _until(sim, 120)
	var e0_swings: Array = RtKit.of(ev, T.SWING).filter(func(x: ActionEvent) -> bool: return x.actor_id == "e0")
	assert_true(e0_swings.is_empty() or e0_swings[0].tick >= 90, "a dazed enemy does not act")
	var amb: RtSetup = RtKit.setup(RtKit.state(6), RtKit.dummy_cmd({"adv": BattleSetup.Advantage.AMBUSH}))
	var asim: RtSim = RtSim.new(amb, RtKit.data())
	var apre: Array[ActionEvent] = asim.start()
	assert_eq(_of(apre, T.STATUS_ADDED, "sts_dazed").map(func(x: ActionEvent) -> Array: return [x.target_id, x.value]),
		[["p0", 45], ["p1", 45]], "ambush: the party, half the time")
	assert_eq(RtKit.of(apre, T.ANNOUNCE)[0].text, "Hinterhalt!")
	assert_eq(asim.can_use("p0", "skl_kai_heavy_swing", ""), "stunned", "no_act")


func test_regeneration() -> void:
	var sim: RtSim = _sim()
	var kai: RtUnit = sim.unit("p0")
	kai.hp = 100
	StatusFx.apply(sim, "p1", kai, "sts_regen", 0, 1000)
	var h: Array[ActionEvent] = _of(_until(sim, 61), T.HEAL, "sts_regen")
	var amount: int = FixedMath.div_round(kai.max_hp() * 3, 100)
	assert_eq(h.map(func(x: ActionEvent) -> Array: return [x.tick, x.actor_id, x.target_id, x.amount]),
		[[60, "", "p0", amount]], "+3 % max HP every 60 ticks")
	assert_eq(kai.hp, 100 + amount)
	assert_eq(int(sim.unit("e0").threat.get("p1", 0)), maxi(1, FixedMath.div_round(amount * 500, 1000)),
		"heal threat for the source")


func test_cleanse() -> void:
	var st: GameState = RtKit.state(6)
	st.member("kai").rt_loadout = {"2": "skl_kai_first_aid"}
	var sim: RtSim = _sim(6, "kai", st)
	var kai: RtUnit = sim.unit("p0")
	StatusFx.apply(sim, "e0", kai, "sts_poison", 0, 1000)
	StatusFx.apply(sim, "e0", kai, "sts_burn", 0, 1000)
	StatusFx.apply(sim, "e0", kai, "sts_slow", 0, 1000)
	kai.hp -= 50
	assert_eq(RtKit.act(sim, RtCommand.ability(0, "p0", "skl_kai_first_aid", "p0"))[0], "")
	var ev: Array[ActionEvent] = _until(sim, 10)
	var gone: Array = RtKit.of(ev, T.STATUS_REMOVED).map(func(x: ActionEvent) -> Array: return [x.tick, x.status_id])
	assert_eq(gone, [[9, "sts_poison"], [9, "sts_burn"]], "Erste Hilfe cleanses poison and burn, not the slow")
	assert_true(kai.has_status("sts_slow"))
	var heal: Array[ActionEvent] = RtKit.of(ev, T.HEAL)
	assert_true(heal.size() == 1 and heal[0].amount == 50 and heal[0].actor_id == "p0", "heals the missing 50")


func test_immunity_and_resistance_are_seeded() -> void:
	var sim: RtSim = _sim()
	var e: RtUnit = sim.unit("e0")
	e.status_immune.append("sts_slow")
	var n0: int = _rng_n(sim)
	assert_null(StatusFx.apply(sim, "p0", e, "sts_slow", 0, 1000), "status_immune")
	assert_eq(_rng_n(sim), n0, "immunity: no roll")
	e.status_immune = PackedStringArray()
	e.element_mods = {"fire": 0.0}
	assert_null(StatusFx.apply(sim, "p0", e, "sts_burn", 0, 1000, 20, sim.skill_def("skl_kai_deo_torch")),
		"element immunity")
	e.element_mods = {}
	e.status_resist = {"sts_slow": 0.5}
	var seen: Dictionary = {}
	for i in 16:
		var n: int = _rng_n(sim)
		var resisted: bool = FixedMath.roll_bp(SeedUtil.make_rng(SeedUtil.derive(sim.setup.seed, "rt", n + 1)), 5000)
		var got: RtStatus = StatusFx.apply(sim, "p0", e, "sts_slow", 0, 1000)
		assert_eq(got == null, resisted, "application %d follows its seeded roll" % i)
		assert_eq(_rng_n(sim), n + 1, "one resistance roll")
		seen[resisted] = true
		StatusFx.remove(sim, e, "sts_slow")
	assert_eq(seen.size(), 2, "both outcomes occur")
	e.status_resist = {}
	for i in 16:
		var n2: int = _rng_n(sim)
		var hit: bool = FixedMath.roll_bp(SeedUtil.make_rng(SeedUtil.derive(sim.setup.seed, "rt", n2 + 1)), 3000)
		assert_eq(StatusFx.apply(sim, "p0", e, "sts_slow", 0, 300) != null, hit, "chance_pm 300, roll %d" % i)
		StatusFx.remove(sim, e, "sts_slow")
	e.status_resist = {"sts_stun": 1.0}
	var n3: int = _rng_n(sim)
	assert_not_null(StatusFx.apply(sim, "", e, "sts_stun", 0, 1000, 0, null, true), "force: no resistance roll")
	assert_eq(_rng_n(sim), n3)


## STATUS_BLOCKED in the stream: Frostniesen on a slow-immune dummy.
func test_blocked_event() -> void:
	var sim: RtSim = _sim(6, "mopsula")
	sim.unit("e0").status_immune.append("sts_slow")
	assert_eq(RtKit.act(sim, RtCommand.ability(0, "p1", "skl_mop_frost_sneeze", "e0"))[0], "")
	var ev: Array[ActionEvent] = sim.step()
	var b: Array[ActionEvent] = RtKit.of(ev, T.STATUS_BLOCKED)
	assert_eq(b.map(func(x: ActionEvent) -> Array: return [x.tick, x.target_id, x.status_id, x.text]),
		[[1, "e0", "sts_slow", "immune"]])
	var d: Array[ActionEvent] = RtKit.of(ev, T.DAMAGE)
	assert_true(d.size() == 1 and ev.find(d[0]) < ev.find(b[0]), "damage first, then the status")


func test_ko_clears_every_status() -> void:
	var sim: RtSim = RtKit.sim_no_ai(RtKit.encounter("enc_rt_rats", [["g", "enc_rt_rats", [0, -300, 128]]]), 6)
	for u: RtUnit in sim.units():
		u.auto_on = false
	var rat: RtUnit = sim.unit("e0")
	StatusFx.apply(sim, "p0", rat, "sts_poison", 0, 1000)
	StatusFx.apply(sim, "p0", rat, "sts_slow", 0, 1000)
	rat.hp = 1
	var ev: Array[ActionEvent] = _until(sim, 61)
	var ko: Array[ActionEvent] = RtKit.of(ev, T.KO)
	assert_eq(ko.map(func(x: ActionEvent) -> Array: return [x.tick, x.target_id, x.actor_id, x.command]),
		[[60, "e0", "p0", -1]], "a status KO names the status source, command −1")
	assert_true(rat.statuses.is_empty(), "every status gone")
	assert_eq(RtKit.of(ev, T.STATUS_REMOVED).size(), 0, "without STATUS_REMOVED: the KO says it")
