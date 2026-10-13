extends TestCase
## R5b part 1 (07 §9.5 "Ausrüstung", §11.5 "Stand R5b-1"): equipment carries real-time mods — items.json rt.mods, mods
## without src / unit that BattleBridge gives the wearer's unit as "equip:<item id>" (first in the fixed order
## equipment → species → spec → show boss → twists → liga). dmg_taken_pm may name an element: the factor folds into
## skill hits (formula and percent) of that element only, after the element-free factors; status ticks never. The one
## entry: the Samtcape takes 10 % off physical hits — Graf Mopsula's armour counted at the Hausmeister otherwise not at
## all (percent hits), so "leichtfüßig" made the Liga free for her there (E31 step 5–15 points). Only equipment may
## carry mods; the validator checks them like every mod list.

const Harness := preload("res://tests/tools/rt_harness.gd")
const Damage := preload("res://core/rt/rt_damage.gd")
const FixedMath := preload("res://core/stats/fixed_math.gd")
const CAPE: String = "itm_arm_velvet_cape"
const BOSS: String = "enc_f1_boss_hausmeister"


func _sim(liga: int) -> RtSim:
	var d: GameData = real_data()
	var st: GameState = Harness.state_for(d, BOSS, "mopsula", liga, 1)
	var sim: RtSim = RtSim.new(BattleBridge.make_rt_setup(st, d, Harness.command_for(BOSS, "mopsula", 0), 7), d)
	sim.start()
	return sim


func _equip_mods(s: RtSim) -> Array:
	var out: Array = []
	for m: Dictionary in s.setup.mods:
		if str(m.get("src", "")).begins_with("equip:"):
			out.append(m)
	return out


func test_the_cape_gives_its_wearer_the_physical_mod() -> void:
	var d: GameData = real_data()
	assert_eq(d.item(CAPE).rt.get("mods", []), [{"op": "dmg_taken_pm", "pm": 900, "element": "physical"}])
	assert_has(d.item(CAPE).desc, "−10 % physischer Schaden", "the item text names it")
	var worn: RtSim = _sim(0)
	assert_eq(_equip_mods(worn), [{"op": "dmg_taken_pm", "pm": 900, "element": "physical", "src": "equip:" + CAPE,
		"unit": "p1"}], "Mopsula (p1) wears the cape at the Hausmeister")
	assert_eq(str((worn.setup.mods[0] as Dictionary)["src"]), "equip:" + CAPE, "equipment first in the fixed order")
	assert_eq(_equip_mods(_sim(1)), [], "Liga 1 as Mopsula: no armour, no mod")


func test_the_element_mod_folds_into_its_element_only() -> void:
	var sim: RtSim = _sim(0)
	var mop: RtUnit = sim.unit("p1")
	var hm: RtUnit = null
	for u: RtUnit in sim.units():
		if u.is_boss:
			hm = u
	var keys: SkillDef = sim.skill_def("skl_b_keys")            # physical, percent
	var fog: SkillDef = sim.skill_def("skl_b_cleaner_fog")      # poison, percent
	var cap: int = sim.bal.i("DMG_FACTOR_MAX_PM")
	for c: Array in [[keys, [1000, 1000, 900]], [fog, [1000, 1000]]]:
		var sk: SkillDef = c[0]
		var pct: int = int(sk.rt["pct_maxhp"])
		mop.hp = mop.max_hp()
		var factors: Array[int] = []
		factors.assign(c[1])
		var want: int = Damage.fold(FixedMath.div_round(mop.max_hp() * pct, 100), factors, cap)
		Damage.pct_hit(sim, hm, mop, sk, pct, Damage.Kind.TELEGRAPH, true, -1)
		assert_eq(mop.max_hp() - mop.hp, want, "%s on the cape's wearer" % sk.id)
	var f: Array[int] = []
	sim.mod_factors(hm, mop, true, f, "physical")
	assert_eq(f, [900] as Array[int], "a formula hit of the element: the factor")
	f.clear()
	sim.mod_factors(hm, mop, true, f, "shock")
	assert_eq(f, [] as Array[int], "another element: none")
	f.clear()
	sim.mod_factors(null, mop, false, f)
	assert_eq(f, [] as Array[int], "status ticks pass no element: none")


func test_only_equipment_carries_valid_mods() -> void:
	var good: Array = RtMods.from_equipment(CAPE, [{"op": "dmg_taken_pm", "pm": 900, "element": "physical"}], "p1")
	assert_eq(RtMods.validate(good), PackedStringArray())
	assert_has(" ".join(RtMods.validate(RtMods.from_equipment(CAPE, [{"op": "dmg_taken_pm", "pm": 900,
		"element": "plasma"}], "p1"))), "unknown element", "element vocabulary")
	assert_has(" ".join(RtMods.validate(RtMods.from_equipment(CAPE, [{"op": "dmg_dealt_pm", "pm": 900,
		"element": "physical"}], "p1"))), "unknown key", "element only on dmg_taken_pm")
	var raw: Dictionary = {}
	for t: String in GameData.TABLES:
		raw[t] = JsonUtil.read_file("res://data/%s.json" % t)
	raw["rt_balance"] = JsonUtil.read_file("res://data/rt_balance.json")
	for e: Variant in ((raw["items"] as Dictionary)["entries"] as Array):
		if str((e as Dictionary)["id"]) == "itm_bandage":
			((e as Dictionary)["rt"] as Dictionary)["mods"] = [{"op": "dmg_taken_pm", "pm": 900}]
	var d: GameData = GameData.new()
	d.load_from_tables(raw)
	assert_has(" | ".join(d.errors), "only equipment carries real-time mods", "a consumable with mods is refused")
