extends TestCase
## 07 §2.13, E28 (R1b-I1) test_r1_rt_tutorial: the tutorial combat — bar() shows slots 1 and 5 of the controlled unit
## only, submit refuses other slots (not_learned), items and the Partner-Spezial (forbidden), the AI partner keeps its
## whole bar, the party never drops below 1 HP, enemies hit × TUTORIAL_ENEMY_DMG, the set is closed, combat hints do
## not touch the sim.

const Damage := preload("res://core/rt/rt_damage.gd")
const T := ActionEvent.Type
const K := BattleCommand.Kind


func _tutorial(hero: String = "kai", level: int = 3) -> RtSim:
	var st: GameState = RtKit.state(level, hero, {"itm_brutzel_burger": 1})
	var cmd: Dictionary = RtKit.encounter("enc_f1_a1_tutorial", [["f1_g0", "enc_f1_a1_tutorial", [0, -300, 128]]],
		{"ctl": "p0" if hero == "kai" else "p1"})
	var sim: RtSim = RtSim.new(RtKit.setup(st, cmd), RtKit.data())
	sim.start()
	return sim


func test_bar_and_static_refusals() -> void:
	var sim: RtSim = _tutorial()
	assert_true(sim.setup.tutorial)
	assert_eq(sim.setup.tutorial_steps, PackedStringArray(["target", "bar1", "show", "dodge"]))
	assert_eq(sim.bar("p0"), {1: "skl_kai_heavy_swing", 5: "skl_stunt_kai_suplex"}, "slots 1 and 5, no potion slot")
	assert_eq(sim.submit(RtCommand.ability(0, "p0", "skl_kai_leash_trip", "e0")), "not_learned")
	assert_eq(sim.submit(RtCommand.ability(0, "p0", "skl_kai_taunt", "")), "not_learned")
	assert_eq(sim.can_use("p0", "skl_kai_leash_trip", "e0"), "not_learned")
	assert_eq(sim.submit(RtCommand.item(0, "p0", "itm_bandage", "")), "forbidden")
	assert_eq(sim.can_use_item("p0", "itm_brutzel_burger", ""), "forbidden")
	assert_eq(sim.submit(RtCommand.partner_special(0, "p1")), "forbidden")
	assert_eq(sim.partner_special_skill("p1"), "", "no Partner-Spezial in the tutorial")
	assert_eq(sim.submit(RtCommand.ability(0, "p0", "skl_kai_heavy_swing", "e0")), "")
	assert_eq(sim.submit(RtCommand.ability(0, "p0", "skl_stunt_kai_suplex", "e0")), "", "the SHOW is part of it")
	assert_eq(sim.submit(RtCommand.hint(0, "bar1")), "", "a combat hint is accepted …")
	var before: String = StateHash.of_rt(sim)
	var other: RtSim = _tutorial()
	other.submit(RtCommand.ability(0, "p0", "skl_kai_heavy_swing", "e0"))
	other.submit(RtCommand.ability(0, "p0", "skl_stunt_kai_suplex", "e0"))
	assert_eq(before, StateHash.of_rt(other), "… and leaves no trace in the sim")


func test_ai_partner_plays_normally() -> void:
	var sim: RtSim = _tutorial()
	var full: Dictionary = sim.bar("p1")
	assert_eq([full.get(1, ""), full.get(2, ""), full.get(3, ""), full.get(4, ""), full.get(5, "")],
		["skl_mop_noble_flame", "skl_mop_holy_lick", "skl_mop_frost_sneeze", "skl_mop_thunder_bark",
		"skl_stunt_mop_entrance"], "the AI partner keeps its whole bar")
	assert_eq(sim.can_use("p1", "skl_mop_frost_sneeze", "e0"), "")
	var mop: RtSim = _tutorial("mopsula")
	assert_eq(mop.bar("p1"), {1: "skl_mop_noble_flame", 5: "skl_stunt_mop_entrance"}, "Mopsula as the hero: 1 + 5")
	assert_eq(mop.bar("p0").get(3, ""), "skl_kai_leash_trip", "Kai as the partner: everything")


func test_party_never_below_one_hp() -> void:
	var sim: RtSim = _tutorial()
	var kai: RtUnit = sim.unit("p0")
	var mop: RtUnit = sim.unit("p1")
	var rat: RtUnit = sim.unit("e0")
	assert_almost(sim.setup.enemy_dmg_mult, 0.5, 0.0000001, "TUTORIAL_ENEMY_DMG")
	assert_true(bool(sim.setup.geo["closed"]), "a closed set")
	for u: RtUnit in [kai, mop]:
		Damage.apply(sim, rat, u, 99999, Elements.PHYSICAL, HitResult.new(), "skl_e_strike", "", "", Damage.Kind.AUTO,
			true, K.ATTACK, 1000)
		assert_eq(u.hp, 1, u.id + ": never below 1 HP")
		assert_false(u.is_ko())
	for u: RtUnit in sim.units():
		u.auto_on = u.side == Combatant.Side.ENEMY
	var ev: Array[ActionEvent] = []
	while sim.tick() < 300 and not sim.is_finished():
		ev.append_array(sim.step())
	var hits: Array = RtKit.of(ev, T.DAMAGE).filter(func(x: ActionEvent) -> bool: return x.target_id.begins_with("p"))
	assert_gt(hits.size(), 0, "the rats keep hitting")
	assert_true(hits.all(func(x: ActionEvent) -> bool: return x.hp_after == 1), "and the party stays at 1 HP")
	assert_eq(RtKit.of(ev, T.KO).size(), 0)
	assert_false(sim.is_finished())
