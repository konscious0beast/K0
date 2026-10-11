extends TestCase
## 07 §3.9.1 (R1b-I1) test_r1_rt_damage_fold: the real-time factors fold one by one into one capped factor (E4) —
## Enrage 1–4 stacks on base 50 → 75 / 113 / 169 / 253; every factor at the validator maximum plus 9 Enrage stacks →
## f = 8000 without overflow; neutral factors change nothing (no rounding step); dmg_pm only for enemy sources; the
## combo factor; percent hits (E30): the target's element factor first (500…1500 ‰, immunity 500, no element no
## step), then dmg_taken_pm, then guard 667 ‰ — no formula, so ATK, DEF, RES, crits and dmg_pm play no part.

const Damage := preload("res://core/rt/rt_damage.gd")
const StatusFx := preload("res://core/rt/rt_status_fx.gd")
const FixedMath := preload("res://core/stats/fixed_math.gd")
const T := ActionEvent.Type
const K := BattleCommand.Kind
const CAP: int = 8000


func _sim(level: int = 6, hero: String = "kai") -> RtSim:
	var sim: RtSim = RtKit.sim(RtKit.dummy_cmd({"ctl": "p0" if hero == "kai" else "p1"}), level, hero)
	for u: RtUnit in sim.units():
		u.auto_on = false
	return sim


static func _ints(a: Array) -> Array[int]:
	var out: Array[int] = []
	for v: Variant in a:
		out.append(int(v))
	return out


## The formula hit DamageCalc rolls with the sim's next generator (same seed, same draw number) — the base the
## real-time factors fold onto.
static func _formula(sim: RtSim, src: RtUnit, tgt: RtUnit, sk: SkillDef) -> HitResult:
	var n: int = int(sim.snapshot()["rng_n"])
	var rng: RandomNumberGenerator = SeedUtil.make_rng(SeedUtil.derive(sim.setup.seed, "rt", n + 1))
	if src.side == Combatant.Side.ENEMY:
		return DamageCalc.compute(src, tgt, sim.view(sk), sk.element, rng, false, sim.setup.enemy_dmg_mult)
	return DamageCalc.compute(src, tgt, sim.view(sk), sk.element, rng)


func test_enrage_stacks_fold_on_base_50() -> void:
	var want: Array = [75, 113, 169, 253]
	for n in range(1, 5):
		var f: Array[int] = []
		for _i in n:
			f.append(1500)
		assert_eq(Damage.fold(50, f, CAP), want[n - 1], "%d stacks" % n)
	var sim: RtSim = _sim()
	var e: RtUnit = sim.unit("e0")
	for n in range(1, 5):
		StatusFx.apply(sim, "e0", e, "sts_enrage", 0, 1000, 0, null, true)
		var got: Array[int] = []
		StatusFx.factor_list(e, "dmg_dealt_pm", got)
		assert_eq(got, _ints([1500, 1500, 1500, 1500].slice(0, n)), "one factor per stack")
		assert_eq(Damage.fold(50, got, CAP), want[n - 1])
	assert_eq(StatusFx.find(e, "sts_enrage").stacks, 4)
	assert_eq(Damage.fold_factor(_ints([1500, 1500, 1500, 1500]), CAP), 5063, "1500 → 2250 → 3375 → 5063 (rounded)")
	var kai: RtUnit = sim.unit("p0")
	var poke: SkillDef = sim.skill_def("skl_e_dummy_poke")
	var base: HitResult = _formula(sim, e, kai, poke)
	var hp0: int = kai.hp
	var dealt: int = Damage.skill_hit(sim, e, kai, poke, Damage.Kind.AUTO, true, K.ATTACK)
	assert_eq(dealt, Damage.fold(base.amount, _ints([1500, 1500, 1500, 1500]), CAP),
		"DamageCalc unchanged, then the folded Enrage factor")
	assert_eq(kai.hp, hp0 - dealt)


func test_factor_cap_without_overflow() -> void:
	var f: Array[int] = _ints([5000, 5000, 5000, 5000, 2000, 5000])   # dealt, taken, dmg_pm, opener, combo, mods (max)
	for _i in 9:
		f.append(1500)                                                # + 9 Enrage stacks
	assert_eq(Damage.fold_factor(f, CAP), 8000)
	for base: int in [1, 7, 50, 12345]:
		assert_eq(Damage.fold(base, f, CAP), FixedMath.mul_pm(base, 8000), "base %d" % base)
	assert_eq(Damage.fold(1000000000000, f, CAP), 8000000000000, "no overflow, no sign error")
	var sim: RtSim = _sim()
	var e: RtUnit = sim.unit("e0")
	var kai: RtUnit = sim.unit("p0")
	e.dmg_pm = 5000
	for _i in 9:
		StatusFx.apply(sim, "e0", e, "sts_enrage", 0, 1000, 0, null, true)
	for _i in 3:
		StatusFx.apply(sim, "e0", kai, "sts_rt_test_exposed", 0, 1000, 0, null, true)
	assert_eq(StatusFx.find(e, "sts_enrage").stacks, 9, "max_stacks 9")
	assert_eq(StatusFx.find(kai, "sts_rt_test_exposed").stacks, 3, "max_stacks 3")
	var poke: SkillDef = sim.skill_def("skl_e_dummy_poke")
	var base: HitResult = _formula(sim, e, kai, poke)
	assert_eq(Damage.skill_hit(sim, e, kai, poke, Damage.Kind.AUTO, true, K.ATTACK), FixedMath.mul_pm(base.amount, 8000),
		"the whole fold capped at 8000 ‰")


func test_neutral_factors_change_nothing() -> void:
	assert_eq(Damage.fold(7, _ints([]), CAP), 7)
	assert_eq(Damage.fold(7, _ints([1000, 1000, 1000]), CAP), 7, "neutral factors are skipped")
	assert_eq(Damage.fold(7, _ints([2000, 500]), CAP), 7, "f back at exactly 1000: no rounding step")
	assert_eq(Damage.fold(50, _ints([1500, 1000, 1500]), CAP), Damage.fold(50, _ints([1500, 1500]), CAP))
	assert_eq(Damage.fold(0, _ints([1500]), CAP), 0, "immunity stays 0")
	assert_eq(Damage.fold(40, _ints([0, 1500]), CAP), 0, "f = 0")
	assert_eq(Damage.fold(1, _ints([100]), CAP), 1, "at least 1")
	var sim: RtSim = _sim()
	var kai: RtUnit = sim.unit("p0")
	var e: RtUnit = sim.unit("e0")
	var swing: SkillDef = sim.skill_def("skl_kai_heavy_swing")
	var base: HitResult = _formula(sim, kai, e, swing)
	assert_eq(Damage.skill_hit(sim, kai, e, swing, Damage.Kind.ABILITY, false, K.SKILL), base.amount,
		"no real-time factor: DamageCalc's amount bit for bit")


func test_dmg_pm_only_for_enemy_sources() -> void:
	var sim: RtSim = _sim()
	var e: RtUnit = sim.unit("e0")
	var kai: RtUnit = sim.unit("p0")
	e.dmg_pm = 1500
	var poke: SkillDef = sim.skill_def("skl_e_dummy_poke")
	var base: HitResult = _formula(sim, e, kai, poke)
	assert_eq(Damage.skill_hit(sim, e, kai, poke, Damage.Kind.AUTO, true, K.ATTACK),
		Damage.fold(base.amount, _ints([1500]), CAP), "enemy formula hits × dmg_pm")
	kai.dmg_pm = 1500
	var swing: SkillDef = sim.skill_def("skl_kai_heavy_swing")
	var mine: HitResult = _formula(sim, kai, e, swing)
	assert_eq(Damage.skill_hit(sim, kai, e, swing, Damage.Kind.ABILITY, false, K.SKILL), mine.amount,
		"a party unit's dmg_pm does not count")


## Mopsula (controlled) hits with Donnerbellen at ct 0 (lands ct 1), Kai's Partner-Spezial (Leinen-Lasso) lands at ct 9:
## the second party ability on the same target within 30 ticks is a combo (COMBO, × COMBO_PM 1100).
func test_combo_second_party_ability_within_30_ticks() -> void:
	var sim: RtSim = _sim(6, "mopsula")
	assert_eq(sim.submit(RtCommand.ability(0, "p1", "skl_mop_thunder_bark", "")), "")
	assert_eq(sim.submit(RtCommand.partner_special(0, "p0")), "")
	var ev: Array[ActionEvent] = []
	while sim.tick() < 9:
		ev.append_array(sim.step())
	var e: RtUnit = sim.unit("e0")
	var leash: SkillDef = sim.skill_def("skl_kai_leash_trip")
	var base: HitResult = _formula(sim, sim.unit("p0"), e, leash)
	var at9: Array[ActionEvent] = sim.step()
	var combos: Array[ActionEvent] = RtKit.of(at9, T.COMBO)
	assert_eq(combos.size(), 1, "the second hit is a combo")
	var hits: Array = RtKit.of(at9, T.DAMAGE).filter(func(d: ActionEvent) -> bool: return d.actor_id == "p0")
	assert_eq(hits.size(), 1)
	if combos.size() == 1 and hits.size() == 1:
		assert_eq([combos[0].actor_id, combos[0].target_id], ["p0", "e0"])
		assert_true(at9.find(combos[0]) < at9.find(hits[0]), "COMBO before its DAMAGE")
		assert_eq(hits[0].amount, Damage.fold(base.amount, _ints([1100]), CAP), "× COMBO_PM")
	assert_eq(RtKit.of(ev, T.COMBO).size(), 0, "the first hit is none")
	assert_eq(sim.combo_ready, 9 + 150, "at most one combo per 150 ticks")


func test_combo_window_and_cooldown() -> void:
	var sim: RtSim = _sim()
	var kai: RtUnit = sim.unit("p0")
	var mop: RtUnit = sim.unit("p1")
	var e: RtUnit = sim.unit("e0")
	var swing: SkillDef = sim.skill_def("skl_kai_heavy_swing")
	var flame: SkillDef = sim.skill_def("skl_mop_noble_flame")
	Damage.skill_hit(sim, kai, e, swing, Damage.Kind.ABILITY, false, K.SKILL)
	for _i in 31:
		sim.step()
	var late: HitResult = _formula(sim, mop, e, flame)
	assert_eq(Damage.skill_hit(sim, mop, e, flame, Damage.Kind.ABILITY, true, K.SKILL), late.amount,
		"31 ticks later: no combo")
	var now: HitResult = _formula(sim, kai, e, swing)
	assert_eq(Damage.skill_hit(sim, kai, e, swing, Damage.Kind.ABILITY, false, K.SKILL),
		Damage.fold(now.amount, _ints([1100]), CAP), "within 30 ticks of the other member: combo")
	var again: HitResult = _formula(sim, mop, e, flame)
	assert_eq(Damage.skill_hit(sim, mop, e, flame, Damage.Kind.ABILITY, true, K.SKILL), again.amount,
		"the combo cooldown holds the next one back")
	var fresh: RtSim = _sim()
	var fe: RtUnit = fresh.unit("e0")
	Damage.skill_hit(fresh, fresh.unit("p0"), fe, swing, Damage.Kind.ABILITY, false, K.SKILL)
	var auto_sk: SkillDef = fresh.skill_def("skl_attack_mopsula")
	var a: HitResult = _formula(fresh, fresh.unit("p1"), fe, auto_sk)
	assert_eq(Damage.skill_hit(fresh, fresh.unit("p1"), fe, auto_sk, Damage.Kind.AUTO, true, K.ATTACK), a.amount,
		"auto-attacks never combo")


func test_percent_hit_guard_and_no_formula() -> void:
	var sim: RtSim = _sim()
	var e: RtUnit = sim.unit("e0")
	var kai: RtUnit = sim.unit("p0")
	var hex: SkillDef = sim.skill_def("skl_e_test_hex")             # shock, rt.pct_maxhp 20
	var base: int = FixedMath.div_round(kai.max_hp() * 20, 100)
	var hp0: int = kai.hp
	assert_eq(Damage.pct_hit(sim, e, kai, hex, 20, Damage.Kind.ABILITY, true, K.SKILL), base, "20 % of max HP")
	assert_eq(kai.hp, hp0 - base)
	StatusFx.apply(sim, "p0", kai, "sts_guard", 0, 1000, 0, null, true)
	kai.hp = kai.max_hp()
	assert_eq(Damage.pct_hit(sim, e, kai, hex, 20, Damage.Kind.ABILITY, true, K.SKILL), FixedMath.mul_pm(base, 667),
		"guard: PCT_GUARD_PM 667")
	var ignore: SkillDef = SkillDef.new()
	ignore.id = "skl_test_pct_ignore_guard"
	ignore.element = "shock"
	ignore.rt = {"pct_maxhp": 20, "ignore_guard": true}
	kai.hp = kai.max_hp()
	assert_eq(Damage.pct_hit(sim, e, kai, ignore, 20, Damage.Kind.ABILITY, true, K.SKILL), base, "rt.ignore_guard")
	var n0: int = int(sim.snapshot()["rng_n"])
	kai.stats.values[StatBlock.Stat.DEF] = 999
	kai.stats.values[StatBlock.Stat.RES] = 999
	e.stats.values[StatBlock.Stat.MAG] = 1
	e.stats.values[StatBlock.Stat.LCK] = 999
	e.dmg_pm = 3000
	kai.hp = kai.max_hp()
	assert_eq(Damage.pct_hit(sim, e, kai, hex, 20, Damage.Kind.ABILITY, true, K.SKILL), FixedMath.mul_pm(base, 667),
		"ATK, DEF, RES, crit chance and dmg_pm play no part")
	assert_eq(int(sim.snapshot()["rng_n"]), n0, "no variance, no crit: a percent hit draws nothing")


func test_percent_hit_element_first_e30() -> void:
	var sim: RtSim = _sim()
	var e: RtUnit = sim.unit("e0")
	var kai: RtUnit = sim.unit("p0")
	var hex: SkillDef = sim.skill_def("skl_e_test_hex")
	var base: int = FixedMath.div_round(kai.max_hp() * 20, 100)
	for row: Array in [[2.0, 1500], [1.5, 1500], [1.25, 1250], [0.75, 750], [0.25, 500], [0.0, 500]]:
		kai.element_mods = {"shock": row[0]}
		kai.hp = kai.max_hp()
		assert_eq(Damage.pct_hit(sim, e, kai, hex, 20, Damage.Kind.ABILITY, true, K.SKILL),
			FixedMath.mul_pm(base, int(row[1])), "shock × %s → %d ‰" % [str(row[0]), int(row[1])])
	assert_eq(Damage.pct_element_pm(kai, "shock"), 500, "immunity counts as 500")
	assert_eq(Damage.pct_element_pm(kai, Elements.NONE), 1000)
	var plain: SkillDef = SkillDef.new()
	plain.id = "skl_test_pct_plain"
	plain.element = Elements.NONE
	plain.rt = {"pct_maxhp": 20}
	kai.element_mods = {"shock": 0.0, "physical": 0.0, "fire": 2.0}
	kai.hp = kai.max_hp()
	assert_eq(Damage.pct_hit(sim, e, kai, plain, 20, Damage.Kind.ABILITY, true, K.SKILL), base,
		"no element: no element step")
	# order: element (1500) → 2 × dmg_taken 2500 → guard 667: 1500, 3750, 8000 (cap), 5336 — any other order rounds
	# or caps differently (element last: 6254)
	kai.element_mods = {"shock": 1.5}
	StatusFx.apply(sim, "e0", kai, "sts_rt_test_exposed", 0, 1000, 0, null, true)
	StatusFx.apply(sim, "e0", kai, "sts_rt_test_exposed", 0, 1000, 0, null, true)
	StatusFx.apply(sim, "p0", kai, "sts_guard", 0, 1000, 0, null, true)
	var small: int = FixedMath.div_round(kai.max_hp() * 5, 100)
	kai.hp = kai.max_hp()
	assert_eq(Damage.fold_factor(_ints([1500, 2500, 2500, 667]), CAP), 5336)
	assert_eq(Damage.pct_hit(sim, e, kai, hex, 5, Damage.Kind.ABILITY, true, K.SKILL), FixedMath.mul_pm(small, 5336),
		"element first, then dmg_taken_pm, then guard")


## The percent hit of an enemy cast as an event (step 6): actor, element, weak flag, never a crit.
func test_percent_hit_event() -> void:
	var sim: RtSim = _sim()
	var e: RtUnit = sim.unit("e0")
	var kai: RtUnit = sim.unit("p0")
	kai.element_mods = {"shock": 1.5}
	var c: int = sim.tick()
	e.cast = {"skill": "skl_e_test_hex", "target": "p0", "targets": ["p0"], "x": e.x, "z": e.z, "start": c - 60, "end": c,
		"interruptible": true, "worthy": true, "moving_cancels": false, "channel": false, "period": 0, "next_tick": -1,
		"tele": -1, "kind": "ability", "item": "", "ai": true, "cmd": K.SKILL}
	var ev: Array[ActionEvent] = sim.step()
	var d: Array[ActionEvent] = RtKit.of(ev, T.DAMAGE)
	assert_eq(d.size(), 1)
	if d.size() == 1:
		assert_eq([d[0].actor_id, d[0].target_id, d[0].skill_id, d[0].element, d[0].weak, d[0].crit, d[0].amount],
			["e0", "p0", "skl_e_test_hex", "shock", true, false,
			FixedMath.mul_pm(FixedMath.div_round(kai.max_hp() * 20, 100), 1500)])
	var end: Array[ActionEvent] = RtKit.of(ev, T.ACTION_END)
	assert_true(end.size() == 1 and end[0].actor_id == "e0" and end[0].skill_id == "skl_e_test_hex", "ACTION_END")
	assert_true(e.cast.is_empty())
