extends TestCase
## M1: formulas of 02_TECH §5.9 / GDD §3.7 with fixed numbers: physical/magical damage (variance, crit, elements,
## defend, guard, combo, enemy_dmg_mult), crit chance + cap, fixed damage, pct damage, heal modes, status chance,
## flee and stunt chances. Expected values are computed with an independent float reference formula and the same
## integer draws (probe rng with the same seed: variance randi_range(900, 1100), then crit randi_range(0, 9999)).

const Fx := preload("res://tests/test_m1_fixture.gd")

var data: GameData


func before_each() -> void:
	data = fixture_data(Fx.tables())


func _ref(a: int, d: int, power: int, variance_pm: int, crit: bool, elem: float, defending: bool, combo: bool,
		enemy_mult: float) -> int:
	var raw: float = float(a * a) / float(a + d) * float(power) / 100.0
	raw *= float(variance_pm) / 1000.0
	if crit:
		raw *= 1.5
	raw *= elem
	if defending:
		raw *= 0.5
	if combo:
		raw *= 1.1
	raw *= enemy_mult
	return maxi(1, roundi(raw))


func _rat() -> Combatant:
	return Combatant.create_enemy(data.enemy("enm_rat"), "e0", 0)


func test_physical_damage_matches_formula_for_many_seeds() -> void:
	var kai: Combatant = Fx.member(data, "kai", "p0", 0)      # STR 12, LCK 8 → crit 0.09
	var atk: SkillDef = data.skill("skl_attack_kai")
	var crits: int = 0
	for seed in range(1, 301):
		var rat: Combatant = _rat()                            # DEF 5
		var probe: RandomNumberGenerator = make_rng(seed)
		var v: int = probe.randi_range(900, 1100)
		var crit: bool = probe.randi_range(0, 9999) < 900
		var hit: HitResult = DamageCalc.compute(kai, rat, atk, "physical", make_rng(seed))
		assert_eq(hit.amount, _ref(12, 5, 100, v, crit, 1.0, false, false, 1.0), "seed %d" % seed)
		assert_eq(hit.crit, crit, "crit draw (seed %d)" % seed)
		crits += 1 if crit else 0
		assert_false(hit.weak or hit.resist or hit.immune)
	assert_between(crits, 10, 50, "≈ 9 % crits in 300 hits")


func test_magical_damage_weakness_and_no_crit() -> void:
	var mop: Combatant = Fx.member(data, "mopsula", "p1", 1)   # MAG 13
	var flame: SkillDef = data.skill("skl_mop_noble_flame")    # magical fire 110
	for seed in range(1, 51):
		var rat: Combatant = _rat()                            # RES 3, fire 1.5
		var rng: RandomNumberGenerator = make_rng(seed)
		var probe: RandomNumberGenerator = make_rng(seed)
		var v: int = probe.randi_range(900, 1100)
		var hit: HitResult = DamageCalc.compute(mop, rat, flame, "fire", rng)
		assert_eq(hit.amount, _ref(13, 3, 110, v, false, 1.5, false, false, 1.0), "seed %d" % seed)
		assert_true(hit.weak)
		assert_false(hit.crit, "magical damage never crits")
		assert_eq(rng.randi(), probe.randi(), "magical damage uses exactly one draw (variance)")


func test_resist_immune_defend_guard_combo_enemy_mult() -> void:
	var kai: Combatant = Fx.member(data, "kai", "p0", 0)
	var atk: SkillDef = data.skill("skl_attack_kai")
	var slime: Combatant = Combatant.create_enemy(data.enemy("enm_slime"), "e0", 0)   # DEF 10, physical 0.5
	var probe: RandomNumberGenerator = make_rng(9)
	var v: int = probe.randi_range(900, 1100)
	var crit: bool = probe.randi_range(0, 9999) < 900
	var hit: HitResult = DamageCalc.compute(kai, slime, atk, "physical", make_rng(9))
	assert_true(hit.resist)
	assert_eq(hit.amount, _ref(12, 10, 100, v, crit, 0.5, false, false, 1.0))
	var rng: RandomNumberGenerator = make_rng(9)
	var imm: HitResult = DamageCalc.compute(kai, slime, data.skill("skl_e_gnaw_poison"), "poison", rng)
	assert_true(imm.immune)
	assert_eq(imm.amount, 0, "immune → 0")
	assert_eq(rng.randi(), make_rng(9).randi(), "immunity consumes no draw")
	# Enemy attacker: defend × 0.5, enemy_dmg_mult applies; guard D × 1.5.
	var rat: Combatant = _rat()                                # STR 13
	var bite: SkillDef = data.skill("skl_e_bite")
	var target: Combatant = Fx.member(data, "kai", "p0", 0)   # DEF 9
	target.defending = true
	var c_bp: int = roundi(DamageCalc.crit_chance(rat, bite) * 10000.0)
	assert_eq(c_bp, 750, "rat LCK 5 → 0.075")
	for seed in range(1, 41):
		probe = make_rng(seed)
		v = probe.randi_range(900, 1100)
		crit = probe.randi_range(0, 9999) < c_bp
		var h: HitResult = DamageCalc.compute(rat, target, bite, "physical", make_rng(seed), false, 0.75)
		assert_eq(h.amount, _ref(13, 9, 100, v, crit, 1.0, true, false, 0.75), "defend + enemy mult, seed %d" % seed)
	target.defending = false
	target.statuses.append(StatusEffect.new(data.status("sts_guard"), 3, "p0"))
	probe = make_rng(3)
	v = probe.randi_range(900, 1100)
	crit = probe.randi_range(0, 9999) < roundi(DamageCalc.crit_chance(rat, bite) * 10000.0)
	var g: HitResult = DamageCalc.compute(rat, target, bite, "physical", make_rng(3))
	var raw: float = 13.0 * 13.0 / (13.0 + 9.0 * 1.5) * float(v) / 1000.0 * (1.5 if crit else 1.0)
	assert_eq(g.amount, maxi(1, roundi(raw)), "guard: D × 1.5")
	# Combo × 1.1, party attacker ignores enemy_dmg_mult.
	var r2: Combatant = _rat()
	probe = make_rng(5)
	v = probe.randi_range(900, 1100)
	crit = probe.randi_range(0, 9999) < 900
	var cb: HitResult = DamageCalc.compute(kai, r2, data.skill("skl_kai_heavy_swing"), "physical", make_rng(5), true, 0.5)
	assert_eq(cb.amount, _ref(12, 5, 160, v, crit, 1.0, false, true, 1.0), "combo × 1.1; party ignores enemy_dmg_mult")


func test_damage_is_at_least_one() -> void:
	var kai: Combatant = Fx.member(data, "kai", "p0", 0, {"stats": {"str": 1}})
	var boss: Combatant = Combatant.create_enemy(data.enemy("enm_boss_queen"), "e0", 0)   # DEF 18
	boss.defending = true
	var hit: HitResult = DamageCalc.compute(kai, boss, data.skill("skl_attack_kai"), "physical", make_rng(1))
	assert_eq(hit.amount, 1, "maxi(1, …)")


func test_crit_chance_and_cap() -> void:
	var kai: Combatant = Fx.member(data, "kai", "p0", 0)       # LCK 8
	var atk: SkillDef = data.skill("skl_attack_kai")
	assert_almost(DamageCalc.crit_chance(kai, atk), 0.09, 0.000001, "0.05 + 8 × 0.005")
	kai.crit_bonus = 0.05
	assert_almost(DamageCalc.crit_chance(kai, atk), 0.14, 0.000001, "+ equipment crit_bonus")
	var finisher: SkillDef = SkillDef.from_dict({"id": "skl_x", "name": "x", "category": "attack",
		"target": "single_enemy",
		"damage_type": "physical", "element": "physical", "crit_bonus": 0.2})
	assert_almost(DamageCalc.crit_chance(kai, finisher), 0.34, 0.000001, "+ skill crit_bonus")
	kai.stats.set_stat(StatBlock.Stat.LCK, 100)
	assert_almost(DamageCalc.crit_chance(kai, finisher), 0.40, 0.000001, "capped at 0.40")
	# A crit multiplies by 1.5: find a seed whose crit draw hits and compare with the reference.
	kai.stats.set_stat(StatBlock.Stat.LCK, 8)
	kai.crit_bonus = 0.0
	var found: bool = false
	for seed in range(1, 200):
		var probe: RandomNumberGenerator = make_rng(seed)
		var v: int = probe.randi_range(900, 1100)
		if probe.randi_range(0, 9999) < 900:
			var hit: HitResult = DamageCalc.compute(kai, _rat(), atk, "physical", make_rng(seed))
			assert_true(hit.crit)
			assert_eq(hit.amount, _ref(12, 5, 100, v, true, 1.0, false, false, 1.0), "crit × 1.5")
			found = true
			break
	assert_true(found, "some seed crits")


func test_fixed_and_percent_damage() -> void:
	var rat: Combatant = _rat()
	assert_eq(DamageCalc.fixed(rat, 90, "ice").amount, 90, "no A/D, no variance")
	var fire: HitResult = DamageCalc.fixed(rat, 60, "fire")
	assert_eq(fire.amount, 90, "affinity: 60 × 1.5")
	assert_true(fire.weak)
	rat.defending = true
	assert_eq(DamageCalc.fixed(rat, 90, "ice").amount, 45, "defending × 0.5")
	rat.defending = false
	rat.statuses.append(StatusEffect.new(data.status("sts_guard"), 3, ""))
	assert_eq(DamageCalc.fixed(rat, 90, "ice").amount, 90, "guard ignored")
	assert_eq(DamageCalc.fixed(rat, 90, "ice", 0.75).amount, 68, "× enemy_dmg_mult: 67.5 → 68")
	var slime: Combatant = Combatant.create_enemy(data.enemy("enm_slime"), "e1", 1)
	var imm: HitResult = DamageCalc.fixed(slime, 50, "poison")
	assert_true(imm.immune)
	assert_eq(imm.amount, 0)
	var kai: Combatant = Fx.member(data, "kai", "p0", 0)       # max HP 64
	assert_eq(DamageCalc.pct_max_hp(kai, 35, "physical").amount, 22, "64 × 35 % = 22.4 → 22")
	kai.defending = true
	assert_eq(DamageCalc.pct_max_hp(kai, 35, "physical").amount, 11, "defending: 11.2 → 11")
	kai.defending = false
	kai.statuses.append(StatusEffect.new(data.status("sts_guard"), 3, ""))
	assert_eq(DamageCalc.pct_max_hp(kai, 35, "physical").amount, 22, "guard does not help against the train")
	kai.element_mods = {"physical": 0.5}
	assert_eq(DamageCalc.pct_max_hp(kai, 35, "physical", 0.75).amount, 8, "64 × 0.35 × 0.5 × 0.75 = 8.4 → 8")


func test_heal_modes() -> void:
	var mop: Combatant = Fx.member(data, "mopsula", "p1", 1)   # MAG 13
	var kai: Combatant = Fx.member(data, "kai", "p0", 0)       # max HP 64
	var lick: SkillDef = data.skill("skl_mop_holy_lick")       # mag 100
	for seed in range(1, 41):
		var probe: RandomNumberGenerator = make_rng(seed)
		var v: int = probe.randi_range(950, 1050)
		var expected: int = roundi((13.0 * 1.5 + 10.0) * 100.0 / 100.0 * float(v) / 1000.0)
		assert_eq(DamageCalc.heal_amount(mop, kai, lick, make_rng(seed)), expected, "mag heal seed %d" % seed)
	assert_eq(DamageCalc.heal_amount(kai, kai, data.skill("skl_kai_first_aid"), make_rng(1)), 19, "pct: 64 × 30 % = 19.2")
	assert_eq(DamageCalc.heal_amount(mop, mop, data.skill("skl_mop_revive"), make_rng(1)), 17, "revive 40 % of 42 = 16.8")
	assert_eq(DamageCalc.heal_amount(kai, kai, data.skill("skl_item_bandage"), make_rng(1)), 45, "fixed: power")
	assert_eq(DamageCalc.heal_amount(kai, kai, data.skill("skl_attack_kai"), make_rng(1)), 0, "no heal mode → 0")
	assert_almost(DamageCalc.hit_chance(kai, mop, lick), 1.0, 0.0, "hits never miss in the slice")


func test_status_chance() -> void:
	var boss: Combatant = Combatant.create_enemy(data.enemy("enm_boss_janitor"), "e0", 0)   # stun resist 0.5
	assert_almost(DamageCalc.status_chance(boss, "sts_stun", 0.35), 0.175, 0.000001, "chance × (1 − resist)")
	assert_almost(DamageCalc.status_chance(boss, "sts_stun", 0.35, true), 0.35, 0.000001, "ignore_resist")
	assert_almost(DamageCalc.status_chance(boss, "sts_haste", 1.0), 1.0, 0.000001)
	var slime: Combatant = Combatant.create_enemy(data.enemy("enm_slime"), "e1", 1)
	assert_almost(DamageCalc.status_chance(slime, "sts_poison", 1.0, true), 0.0, 0.0, "status_immune → 0")


func test_flee_chance() -> void:
	var s: BattleState = Fx.make_state(data, PackedStringArray(["enm_rat"]))       # party SPD 11/14, rat 13
	s.start()
	assert_almost(s.flee_chance(), 0.385, 0.000001, "0.40 + (12.5 − 13) × 0.03")
	s.failed_flee_attempts = 2
	assert_almost(s.flee_chance(), 0.685, 0.000001, "+ 0.15 per failed attempt")
	s.failed_flee_attempts = 9
	assert_almost(s.flee_chance(), 0.95, 0.000001, "max 0.95")
	var fast: BattleState = Fx.make_state(data, PackedStringArray(["enm_pigeon", "enm_pigeon"]),
			{"kai": {"stats": {"spd": 1}}, "mop": {"stats": {"spd": 1}}})
	fast.start()
	assert_almost(fast.flee_chance(), 0.10, 0.000001, "min 0.10")
	var pre: BattleState = Fx.make_state(data, PackedStringArray(["enm_rat"]),
			{"advantage": BattleSetup.Advantage.PREEMPTIVE})
	pre.start()
	assert_almost(pre.flee_chance(), 0.635, 0.000001, "preemptive + 0.25")


func test_stunt_chance() -> void:
	var s: BattleState = Fx.make_state(data, PackedStringArray(["enm_rat"]))
	s.start()
	var kai: Combatant = s.get_combatant("p0")                  # LCK 8
	var suplex: SkillDef = data.skill("skl_stunt_kai_suplex")
	assert_almost(s.stunt_chance(kai, suplex), 0.68, 0.000001, "0.60 + 8 × 0.01")
	kai.stats.set_stat(StatBlock.Stat.LCK, 30)
	assert_almost(s.stunt_chance(kai, suplex), 0.85, 0.000001, "cap 0.85")
	var b: BattleState = Fx.make_state(data, PackedStringArray(["enm_boss_janitor", "enm_rat"]), {"is_boss": true})
	b.start()
	var bk: Combatant = b.get_combatant("p0")
	assert_true(b.get_combatant("e0").is_boss and not b.get_combatant("e1").is_boss)
	assert_almost(b.stunt_chance(bk, suplex, PackedStringArray(["e0"])), 0.53, 0.000001, "boss target: − 0.15")
	assert_almost(b.stunt_chance(bk, suplex, PackedStringArray(["e1"])), 0.68, 0.000001,
		"GDD §3.6 target_is_boss: a suplex on the add next to the boss gets no penalty")
	assert_almost(b.stunt_chance(bk, suplex), 0.53, 0.000001, "preview without a target: a boss could be hit")
	bk.stats.set_stat(StatBlock.Stat.LCK, 30)
	assert_almost(b.stunt_chance(bk, suplex, PackedStringArray(["e0"])), 0.75, 0.000001,
		"clamp(0.60 + 0.30 − 0.15, 0.05, 0.85): the cap applies after the boss mod (GDD §3.6)")
	assert_almost(b.stunt_chance(bk, suplex, PackedStringArray(["e1"])), 0.85, 0.000001, "cap 0.85")
	var weak_stunt: SkillDef = SkillDef.from_dict({"id": "skl_y", "name": "y", "category": "stunt",
		"target": "single_enemy",
		"success_base": 0.05, "success_lck": 0.0, "success_boss_mod": -1.0})
	assert_almost(b.stunt_chance(bk, weak_stunt, PackedStringArray(["e0"])), 0.05, 0.000001, "min 0.05")
