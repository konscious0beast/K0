extends TestCase
## R5b part 1, decision E31 (07 §0.1, 06 §4.3): the Unterhosen-Liga's one rule in the real-time combat — every Liga
## member (MarottenRules.in_liga at the tier frozen at the combat start, never in the tutorial) is "leichtfüßig":
## BattleBridge adds the mod {"src": "liga:mar_unterhose", "op": "on", "event": "combat_start"} with the status
## sts_light_footed for the whole combat — 8 % faster (move_pm 1080, the sim, the person's body and the bot read the
## status), a quarter fewer overlooked telegraphs as a sim-driven unit (ai_miss_pm 750 on AI_DODGE_MISS_PM; the AI
## stream draws as before), kept through a KO (flag "keep"). Liga 0, CTB, fixtures without the status: nothing.
## Announced in the rule texts (marotte, Show tab, Liga toast) and as a status symbol in the HUD.

const Harness := preload("res://tests/tools/rt_harness.gd")
const Movement := preload("res://core/rt/rt_movement.gd")
const StatusFx := preload("res://core/rt/rt_status_fx.gd")
const FixedMath := preload("res://core/stats/fixed_math.gd")
const CombatStyle := preload("res://scenes/combat/ui/combat_style.gd")
const CombatIcons := preload("res://scenes/combat/ui/combat_icons.gd")
const BOSS: String = "enc_f1_boss_hausmeister"
const LIGHT: String = "sts_light_footed"


func _setup(hero: String, liga: int, enc: String = BOSS) -> RtSetup:
	var d: GameData = real_data()
	var st: GameState = Harness.state_for(d, enc, hero, liga, 1)
	return BattleBridge.make_rt_setup(st, d, Harness.command_for(enc, hero, 0), 77)


func _liga_mods(s: RtSetup) -> Array:
	var out: Array = []
	for m: Dictionary in s.mods:
		if str(m.get("src", "")).begins_with("liga:"):
			out.append(m)
	return out


func _unit(sim: RtSim, id: String) -> RtUnit:
	return sim.unit(id)


func test_liga_members_get_the_rule_others_not() -> void:
	assert_eq(_liga_mods(_setup("kai", 0)), [], "Liga 0: no rule")
	var one: RtSetup = _setup("kai", 1)
	assert_eq(_liga_mods(one), [{"src": "liga:mar_unterhose", "op": "on", "unit": "p0", "event": "combat_start",
		"effect": {"status": LIGHT, "ms": -1}}], "Liga 1: the controlled hero (Kai = p0)")
	assert_eq(str((one.mods.back() as Dictionary)["src"]), "liga:mar_unterhose", "the last entry of the fixed order")
	assert_eq((_liga_mods(_setup("mopsula", 1)) as Array).map(func(m: Dictionary) -> String: return str(m["unit"])),
		["p1"], "Liga 1 with Mopsula: her unit")
	assert_eq((_liga_mods(_setup("kai", 2)) as Array).map(func(m: Dictionary) -> String: return str(m["unit"])),
		["p0", "p1"], "Liga 2: both, slot order")
	assert_eq(RtMods.validate(_setup("kai", 2).mods), PackedStringArray(), "the mod list stays valid")
	assert_eq(_liga_mods(_setup("kai", 2, "enc_f1_a1_tutorial")), [], "never in the tutorial")
	var fixture: GameState = RtKit.state(6)                 # fixture party: no armor at all, but no such status
	assert_eq(_liga_mods(BattleBridge.make_rt_setup(fixture, RtKit.data(), RtKit.dummy_cmd(), 77)), [],
		"data without sts_light_footed (the fixtures and their golden hashes) stay as they were")


func test_leichtfuessig_is_faster_watches_better_and_survives_a_ko() -> void:
	var sim: RtSim = RtSim.new(_setup("kai", 1), real_data())
	var ev: Array[ActionEvent] = sim.start()
	var added: Array = []
	for e: ActionEvent in ev:
		if e.type == ActionEvent.Type.STATUS_ADDED and e.status_id == LIGHT:
			added.append(e.target_id)
	assert_eq(added, ["p0"], "the prelude shows it on the Liga member")
	var kai: RtUnit = _unit(sim, "p0")
	var mop: RtUnit = _unit(sim, "p1")
	assert_not_null(StatusFx.find(kai, LIGHT))
	assert_null(StatusFx.find(mop, LIGHT), "Liga 1: the partner keeps its armor and its pace")
	assert_eq(Movement.speed(kai), FixedMath.mul_pm(kai.move_cm_tick, 1080), "8 % faster in the sim")
	assert_eq(Movement.speed(mop), mop.move_cm_tick)
	assert_eq(CombatDirector.move_pm(kai), 1080, "the person's body follows the status (presentation)")
	for preset: String in RtVocab.RT_PRESETS:
		var base: int = sim.bal.sub("AI_DODGE_MISS_PM", preset)
		assert_eq(sim.ai_dodge_miss_pm(kai, preset), FixedMath.mul_pm(base, 750), "a quarter fewer misses: " + preset)
		assert_eq(sim.ai_dodge_miss_pm(mop, preset), base)
	StatusFx.apply(sim, "p0", kai, "sts_haste", 3000, 1000, 0, null, true)
	assert_eq(kai.statuses.size(), 2)
	StatusFx.clear_all(kai)                                  # what a KO does (RtDamage)
	assert_eq(kai.statuses.size(), 1, "the KO clears the other statuses")
	assert_not_null(StatusFx.find(kai, LIGHT), "flag keep: leichtfüßig the whole combat")


func test_the_whole_combat_with_the_rule_replays_the_same() -> void:
	var a: RtSim = RtSim.new(_setup("mopsula", 2), real_data())
	var b: RtSim = RtSim.new(_setup("mopsula", 2), real_data())
	a.start()
	b.start()
	for i in 600:
		a.step()
		b.step()
	assert_eq(StateHash.of_rt(a), StateHash.of_rt(b), "deterministic with the rule (both AI units watch better)")
	assert_not_null(StatusFx.find(a.unit("p0"), LIGHT))
	assert_not_null(StatusFx.find(a.unit("p1"), LIGHT), "Liga 2: both")


func test_the_rule_is_announced() -> void:
	var d: GameData = real_data()
	assert_has(d.marotte("mar_unterhose").desc, "leichtfüßig", "the Liga marotte names it")
	var def: StatusDef = d.status(LIGHT)
	assert_eq([def.name, def.kind, int(def.rt["default_ms"]), int(def.rt["move_pm"]), int(def.rt["ai_miss_pm"])],
		["Leichtfüßig", "buff", -1, 1080, 750])
	assert_eq(CombatStyle.status_icon(def), "light_feet", "its own HUD symbol")
	assert_true(CombatIcons.is_known("light_feet"))
	var bets: GDScript = load("res://scenes/ui/bets_menu.gd") as GDScript
	var rule: String = str(bets.get_script_constant_map()["LIGA_RULE_RT"])
	assert_true(rule.begins_with("Ohne Rüstung & ohne Accessoire: leichtfüßig — 8 % schneller"), rule)
