extends TestCase
## 07 §3.7 (R1b-I1) test_r1_rt_threat: damage threat × unit factor (Kai 1500) × skill factor (Wuchtschlag 2000), heal
## threat shared by the living enemies, the debuff threat, the taunt (top × 1.1 + 1 and the fixation for the 120 ticks
## of Provoziert), the target switch only above 110 %, ties to the smaller slot, the start threat, KO clears.

const Threat := preload("res://core/rt/rt_threat.gd")
const Damage := preload("res://core/rt/rt_damage.gd")
const StatusFx := preload("res://core/rt/rt_status_fx.gd")
const FixedMath := preload("res://core/stats/fixed_math.gd")
const T := ActionEvent.Type
const K := BattleCommand.Kind


func _sim(cmd: Dictionary = {}, level: int = 6, st: GameState = null) -> RtSim:
	var sim: RtSim = RtKit.sim(cmd if not cmd.is_empty() else RtKit.dummy_cmd(), level, "kai", st)
	for u: RtUnit in sim.units():
		u.auto_on = false
	return sim


func _rats() -> Dictionary:
	return RtKit.encounter("enc_rt_rats", [["g", "enc_rt_rats", [0, -300, 128]]])


func test_start_threat() -> void:
	assert_eq(_sim().unit("e0").threat, {"p0": 1}, "the party unit nearest to the first enemy gets 1")
	var rats: RtSim = _sim(_rats())
	assert_eq([rats.unit("e0").threat, rats.unit("e1").threat], [{"p0": 1}, {"p0": 1}], "on every enemy")
	var opener: RtSim = _sim(RtKit.dummy_cmd({"open": {"kind": "skill", "u": "p1", "skill": "skl_mop_noble_flame",
		"target": "e0"}}))
	assert_eq(opener.unit("e0").threat, {"p1": 1}, "the opener's unit")


func test_damage_threat_factors() -> void:
	var sim: RtSim = _sim()
	var kai: RtUnit = sim.unit("p0")
	var mop: RtUnit = sim.unit("p1")
	var e: RtUnit = sim.unit("e0")
	var t0: int = Threat.of(e, "p0")
	var dealt: int = Damage.skill_hit(sim, kai, e, sim.skill_def("skl_kai_heavy_swing"), Damage.Kind.ABILITY, false,
		K.SKILL)
	assert_gt(dealt, 0)
	assert_eq(Threat.of(e, "p0") - t0, FixedMath.div_round(dealt * 1500 * 2000, 1000000), "Kai × 1.5, Wuchtschlag × 2")
	var t1: int = Threat.of(e, "p0")
	var auto: int = Damage.skill_hit(sim, kai, e, sim.skill_def("skl_attack_kai"), Damage.Kind.AUTO, false, K.ATTACK)
	assert_eq(Threat.of(e, "p0") - t1, FixedMath.div_round(auto * 1500, 1000), "an auto hit × 1.5")
	var m: int = Damage.skill_hit(sim, mop, e, sim.skill_def("skl_attack_mopsula"), Damage.Kind.AUTO, true, K.ATTACK)
	assert_eq(Threat.of(e, "p1"), m, "Mopsula × 1.0")
	var before: Dictionary = e.threat.duplicate()
	Damage.skill_hit(sim, e, kai, sim.skill_def("skl_e_dummy_poke"), Damage.Kind.AUTO, true, K.ATTACK)
	assert_eq(e.threat, before, "damage on the party makes no threat")


func test_heal_threat_is_shared() -> void:
	var sim: RtSim = _sim(_rats())
	var kai: RtUnit = sim.unit("p0")
	var mop: RtUnit = sim.unit("p1")
	kai.hp -= 150
	assert_eq(Damage.heal(sim, mop, kai, 100, "skl_mop_holy_lick", ""), 100)
	assert_eq([Threat.of(sim.unit("e0"), "p1"), Threat.of(sim.unit("e1"), "p1")], [25, 25],
		"100 × HEAL_THREAT_PM 500 / (1000 × 2 enemies)")
	assert_eq(Damage.heal(sim, mop, kai, 1, "skl_mop_holy_lick", ""), 1)
	assert_eq(Threat.of(sim.unit("e0"), "p1"), 26, "at least 1 per enemy")
	sim.unit("e1").hp = 0
	assert_eq(Damage.heal(sim, mop, kai, 40, "skl_mop_holy_lick", ""), 40)
	assert_eq([Threat.of(sim.unit("e0"), "p1"), Threat.of(sim.unit("e1"), "p1")], [26 + 20, 26],
		"only living enemies share it")
	kai.hp = kai.max_hp()
	assert_eq(Damage.heal(sim, mop, kai, 50, "skl_mop_holy_lick", ""), 0, "nothing healed, no threat")
	assert_eq(Threat.of(sim.unit("e0"), "p1"), 46)


func test_debuff_threat() -> void:
	var sim: RtSim = _sim()
	var e: RtUnit = sim.unit("e0")
	StatusFx.apply(sim, "p1", e, "sts_slow", 0, 1000)
	assert_eq(Threat.of(e, "p1"), 10, "DEBUFF_THREAT")
	StatusFx.apply(sim, "p1", sim.unit("p0"), "sts_haste", 0, 1000)
	assert_eq(Threat.of(e, "p1"), 10, "a buff on a friend is none")


func test_taunt_and_fixation() -> void:
	var st: GameState = RtKit.state(6)
	var sim: RtSim = _sim(RtKit.dummy_cmd(), 6, st)
	var e: RtUnit = sim.unit("e0")
	e.threat = {"p0": 1, "p1": 100}
	e.target_id = "p1"
	assert_eq(RtKit.act(sim, RtCommand.ability(0, "p0", "skl_kai_taunt", ""))[0], "")
	var ev: Array[ActionEvent] = sim.step()
	var tt: Array[ActionEvent] = RtKit.of(ev, T.STATUS_ADDED).filter(func(x: ActionEvent) -> bool:
		return x.status_id == "sts_taunted")
	assert_eq(tt.size(), 1)
	assert_eq(Threat.of(e, "p0"), FixedMath.mul_pm(100, 1100) + 1 + 10, "top × 1.1 + 1 (plus the debuff threat)")
	assert_eq([e.fixate_id, e.fixate_until], ["p0", 1 + 120], "fixed on Kai for the 4 s of Provoziert")
	var turned: Array = RtKit.of(ev, T.TARGET_CHANGED).filter(func(x: ActionEvent) -> bool: return x.actor_id == "e0")
	assert_true(turned.size() == 1 and turned[0].target_id == "p0", "the enemy turns to Kai in step 7")
	e.threat["p1"] = 5000
	while sim.tick() < 121:
		sim.step()
	assert_eq(e.target_id, "p0", "fixed while Provoziert lasts")
	sim.step()
	assert_eq([e.fixate_id, e.target_id], ["", "p1"], "the fixation ends with the status; then threat rules")


func test_switch_above_110_percent_and_ties() -> void:
	var sim: RtSim = _sim()
	var e: RtUnit = sim.unit("e0")
	e.threat = {"p0": 100, "p1": 110}
	e.target_id = "p0"
	assert_eq(Threat.top_target(sim, e), "p0", "110 % is not enough")
	e.threat["p1"] = 111
	assert_eq(Threat.top_target(sim, e), "p1", "more than 110 % switches")
	e.target_id = ""
	e.threat = {"p0": 50, "p1": 50}
	assert_eq(Threat.top_target(sim, e), "p0", "tie: the smaller slot")
	e.threat = {"p0": 0, "p1": 0}
	assert_eq(Threat.top_target(sim, e), "p0", "no threat at all: still the smaller slot")
	e.threat = {"p0": 10, "p1": 50}
	sim.unit("p1").hp = 0
	assert_eq(Threat.top_target(sim, e), "p0", "KO'd units are no target")


func test_ko_clears_threat() -> void:
	var sim: RtSim = _sim(_rats())
	var mop: RtUnit = sim.unit("p1")
	for id: String in ["e0", "e1"]:
		sim.unit(id).threat = {"p0": 5, "p1": 80}
	mop.hp = 1
	Damage.apply(sim, sim.unit("e0"), mop, 5, Elements.PHYSICAL, HitResult.new(), "skl_e_strike", "", "",
		Damage.Kind.AUTO, true, K.ATTACK, 1000)
	assert_true(mop.is_ko())
	assert_eq([Threat.of(sim.unit("e0"), "p1"), Threat.of(sim.unit("e1"), "p1")], [0, 0], "KO sets it to 0 everywhere")
	assert_eq(Threat.of(sim.unit("e0"), "p0"), 5)
	Damage.revive(sim, sim.unit("p0"), mop, 10, "skl_item_salts")
	assert_eq(Threat.of(sim.unit("e0"), "p1"), 0, "a revived unit starts at 0")
