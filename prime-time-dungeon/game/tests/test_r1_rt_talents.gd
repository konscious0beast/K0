extends TestCase
## 07 §9.6 (R1b-I1) test_r1_rt_talents: value talents arrive through the Combatant fields make_rt_setup fills exactly
## like make_setup (crit_add_pm → crit_bonus, element_pm → element_mods; DamageCalc and E30 use them); "Erster
## Eindruck" (opener_pm: with a PREEMPTIVE start on every hit against a dazed target and on the unit's first damaging
## hit, never otherwise); "Taktgefühl" (stunt_pm: the SHOW chance × pm before the boss deduction and the cap — the AI's
## SHOW too, E27); the persona rule (display_name = the Def name, never the persona; not hashed).

const Damage := preload("res://core/rt/rt_damage.gd")
const StatusFx := preload("res://core/rt/rt_status_fx.gd")
const FixedMath := preload("res://core/stats/fixed_math.gd")
const T := ActionEvent.Type
const K := BattleCommand.Kind


func _unit(s: RtSetup, def_id: String) -> RtUnit:
	for u: RtUnit in s.units:
		if u.def_id == def_id:
			return u
	return null


static func _ints(a: Array) -> Array[int]:
	var out: Array[int] = []
	for v: Variant in a:
		out.append(int(v))
	return out


static func _formula(sim: RtSim, src: RtUnit, tgt: RtUnit, sk: SkillDef) -> HitResult:
	var n: int = int(sim.snapshot()["rng_n"])
	var rng: RandomNumberGenerator = SeedUtil.make_rng(SeedUtil.derive(sim.setup.seed, "rt", n + 1))
	return DamageCalc.compute(src, tgt, sim.view(sk), sk.element, rng)


func _started(st: GameState, cmd: Dictionary, seed: int = RtKit.SEED) -> RtSim:
	var sim: RtSim = RtSim.new(RtKit.setup(st, cmd, seed), RtKit.data())
	sim.start()
	for u: RtUnit in sim.units():
		u.auto_on = false
	return sim


func test_crit_and_element_like_make_setup() -> void:
	var st: GameState = RtKit.state(6)
	st.member("kai").talents = {"tal_kai_scharfes_auge": 2, "tal_kai_feuerfest": 1}
	var rt: RtSetup = RtKit.setup(st, RtKit.dummy_cmd())
	var ctb: BattleSetup = BattleBridge.make_setup(st, RtKit.data(), "enc_rt_dummy", 0, "g_dummy", RtKit.SEED)
	var kai: RtUnit = _unit(rt, "kai")
	var ref: Combatant = ctb.party[0]
	assert_eq(ref.def_id, "kai")
	assert_almost(kai.crit_bonus, 0.06, 0.000001, "2 × 30 ‰")
	assert_eq([kai.crit_bonus, kai.element_mods, kai.stats.values, kai.status_immune, kai.attack_element],
		[ref.crit_bonus, ref.element_mods, ref.stats.values, ref.status_immune, ref.attack_element],
		"the same Combatant fields as make_setup")
	assert_eq(FixedMath.pm(float(kai.element_mods["fire"])), 750)
	var sim: RtSim = RtSim.new(rt, RtKit.data())
	sim.start()
	var plain: RtUnit = _unit(RtKit.setup(RtKit.state(6), RtKit.dummy_cmd()), "kai")
	var swing: SkillDef = sim.skill_def("skl_kai_heavy_swing")
	assert_almost(DamageCalc.crit_chance(sim.unit("p0"), swing) - DamageCalc.crit_chance(plain, swing), 0.06, 0.000001,
		"DamageCalc reads the crit bonus")
	assert_eq(Damage.pct_element_pm(sim.unit("p0"), Elements.FIRE), 750, "and percent hits the element factor (E30)")


func test_erster_eindruck() -> void:
	var st: GameState = RtKit.state(6)
	st.member("kai").talents = {"tal_kai_erster_eindruck": 1}
	var rats: Dictionary = RtKit.encounter("enc_rt_rats", [["g", "enc_rt_rats", [0, -300, 128]]],
		{"adv": BattleSetup.Advantage.PREEMPTIVE})
	var sim: RtSim = _started(st, rats)
	var kai: RtUnit = sim.unit("p0")
	var mop: RtUnit = sim.unit("p1")
	var e0: RtUnit = sim.unit("e0")
	var e1: RtUnit = sim.unit("e1")
	assert_eq([kai.opener_pm, mop.opener_pm], [1150, 1000], "Talents.preemptive_dmg_pm via make_rt_setup")
	assert_true(e0.has_status("sts_dazed") and e1.has_status("sts_dazed"))
	var swing: SkillDef = sim.skill_def("skl_kai_heavy_swing")
	var f1: HitResult = _formula(sim, kai, e0, swing)
	assert_eq(Damage.skill_hit(sim, kai, e0, swing, Damage.Kind.ABILITY, false, K.SKILL),
		Damage.fold(f1.amount, _ints([1150]), 8000), "the first hit (on a dazed rat)")
	assert_true(kai.opener_done)
	var f2: HitResult = _formula(sim, kai, e1, swing)
	assert_eq(Damage.skill_hit(sim, kai, e1, swing, Damage.Kind.ABILITY, false, K.SKILL),
		Damage.fold(f2.amount, _ints([1150]), 8000), "every hit on a dazed target")
	StatusFx.remove(sim, e1, "sts_dazed")
	var f3: HitResult = _formula(sim, kai, e1, swing)
	assert_eq(Damage.skill_hit(sim, kai, e1, swing, Damage.Kind.ABILITY, false, K.SKILL), f3.amount,
		"no longer dazed, not the first hit: no bonus")
	var auto_sk: SkillDef = sim.skill_def("skl_attack_mopsula")
	var f4: HitResult = _formula(sim, mop, e0, auto_sk)
	assert_eq(Damage.skill_hit(sim, mop, e0, auto_sk, Damage.Kind.AUTO, true, K.ATTACK), f4.amount,
		"Mopsula has no talent")
	var fresh: RtSim = _started(st, rats)
	StatusFx.remove(fresh, fresh.unit("e0"), "sts_dazed")
	var auto_k: SkillDef = fresh.skill_def("skl_attack_kai")
	var f5: HitResult = _formula(fresh, fresh.unit("p0"), fresh.unit("e0"), auto_k)
	assert_eq(Damage.skill_hit(fresh, fresh.unit("p0"), fresh.unit("e0"), auto_k, Damage.Kind.AUTO, false, K.ATTACK),
		Damage.fold(f5.amount, _ints([1150]), 8000), "the first damaging hit, also an auto-attack")
	var normal: RtSim = _started(st, RtKit.encounter("enc_rt_rats", [["g", "enc_rt_rats", [0, -300, 128]]]))
	var f6: HitResult = _formula(normal, normal.unit("p0"), normal.unit("e0"), swing)
	assert_eq(Damage.skill_hit(normal, normal.unit("p0"), normal.unit("e0"), swing, Damage.Kind.ABILITY, false,
		K.SKILL), f6.amount, "without a first strike: nothing")


func test_taktgefuehl_order() -> void:
	var st: GameState = RtKit.state(6, "kai")
	st.member("mopsula").talents = {"tal_mop_taktgefuehl": 1}
	var boss: RtSim = _started(st, RtKit.encounter("enc_rt_test_boss", [["g", "enc_rt_test_boss", [0, -300, 128]]]))
	var mop: RtUnit = boss.unit("p1")
	assert_eq(mop.stunt_pm, 1200, "Talents.stunt_window_pm via make_rt_setup")
	var sk: SkillDef = boss.skill_def("skl_stunt_mop_entrance")          # base 0.55, lck 0.01, boss −0.15, cap 0.85
	var ids: PackedStringArray = PackedStringArray(["e0"])
	mop.stats.values[StatBlock.Stat.LCK] = 15
	assert_eq(RtSim.Ability.stunt_chance_bp(boss, mop, sk, ids), 7000 * 12 / 10 - 1500,
		"(5500 + 15 × 100) × 1.2 − 1500 = 6900: the factor before the boss deduction (else 6600)")
	mop.stats.values[StatBlock.Stat.LCK] = 40
	assert_eq(RtSim.Ability.stunt_chance_bp(boss, mop, sk, ids), 8500,
		"9500 × 1.2 − 1500 = 9900 → cap 8500: the cap last (else 7000)")
	assert_eq(RtSim.Ability.stunt_chance_bp(boss, mop, sk, PackedStringArray()), 8500, "no boss target: 11400 → cap")
	mop.stats.values[StatBlock.Stat.LCK] = 0
	mop.stunt_pm = 100
	assert_eq(RtSim.Ability.stunt_chance_bp(boss, mop, sk, ids), 500, "never below STUNT_CHANCE_MIN 5 %")


## E27: the AI partner's SHOW rolls with its stunt_pm — a draw between the plain and the talent chance succeeds.
func test_taktgefuehl_counts_for_the_ai_show() -> void:
	var st: GameState = RtKit.state(6, "kai")
	st.member("mopsula").talents = {"tal_mop_taktgefuehl": 1}
	for seed in range(1, 200):
		var sim: RtSim = _started(st, RtKit.dummy_cmd(), seed)
		var mop: RtUnit = sim.unit("p1")
		var sk: SkillDef = sim.skill_def("skl_stunt_mop_entrance")
		sim.step()
		RtSim.Ability.use_ability(sim, mop, "skl_stunt_mop_entrance", "", true)
		while sim.tick() < 31:
			sim.step()
		var ids: PackedStringArray = RtSim.Ability.area(sim, mop, mop.x, mop.z, 800, 0, 0, 0)
		var with_talent: int = RtSim.Ability.stunt_chance_bp(sim, mop, sk, ids)
		mop.stunt_pm = 1000
		var without: int = RtSim.Ability.stunt_chance_bp(sim, mop, sk, ids)
		mop.stunt_pm = 1200
		var n: int = int(sim.snapshot()["rng_n"])
		var draw: int = SeedUtil.make_rng(SeedUtil.derive(seed, "rt", n + 1)).randi_range(0, 9999)
		if draw < without or draw >= with_talent:
			continue
		var sr: Array[ActionEvent] = RtKit.of(sim.step(), T.STUNT_RESULT)
		assert_true(sr.size() == 1 and sr[0].success and sr[0].by_ai,
			"seed %d: draw %d succeeds only with the talent (%d vs %d)" % [seed, draw, with_talent, without])
		return
	fail("no seed with a draw between the two chances")


func test_persona_rule() -> void:
	var st: GameState = RtKit.state(6)
	st.member("kai").display_name = "Kalle"
	st.member("mopsula").display_name = "Graf Zahl"
	var s: RtSetup = RtKit.setup(st, RtKit.dummy_cmd())
	assert_eq([_unit(s, "kai").display_name, _unit(s, "mopsula").display_name, _unit(s, "enm_rt_dummy").display_name],
		["Kai", "Mopsula", "Trainingspuppe"], "the Def names (08 §2.7 Nr. 5)")
	var ctb: BattleSetup = BattleBridge.make_setup(st, RtKit.data(), "enc_rt_dummy", 0, "g_dummy", RtKit.SEED)
	assert_eq(ctb.party[0].display_name, "Kalle", "(CTB keeps the persona)")
	var a: RtSim = RtSim.new(s, RtKit.data())
	var b: RtSim = RtSim.new(RtKit.setup(RtKit.state(6), RtKit.dummy_cmd()), RtKit.data())
	b.unit("p0").display_name = "Kalle"
	assert_eq(StateHash.of_rt(a), StateHash.of_rt(b), "display names are not hashed")
