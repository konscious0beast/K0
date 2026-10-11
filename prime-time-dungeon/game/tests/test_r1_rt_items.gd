extends TestCase
## 07 §3.11 (R1b-I1) test_r1_rt_items: combat items — the drink pause (15 ticks: no moving, no ability, no swing, not
## while casting, the effect at its end, GCD free), the party-shared cooldown of 450 ticks, at most 3 per combat, the
## potion key (smallest covering heal item, else the biggest; target = friendly target, else the unit), the effects
## from use_skill (fixed heal × 4, MP, revive with the Comeback guard, fixed fire damage × 4 in an area, cleanse, the
## smoke bomb's flight — forbidden in a closed set) and the bookkeeping (item_delta, items_used).

const Damage := preload("res://core/rt/rt_damage.gd")
const StatusFx := preload("res://core/rt/rt_status_fx.gd")
const FixedMath := preload("res://core/stats/fixed_math.gd")
const T := ActionEvent.Type
const K := BattleCommand.Kind


func _sim(items: Dictionary = {}, cmd: Dictionary = {}, hero: String = "kai", bal: Dictionary = {}) -> RtSim:
	var st: GameState = RtKit.state(6, hero, items)
	var s: RtSetup = RtKit.setup(st, cmd if not cmd.is_empty() else RtKit.dummy_cmd({"ctl": "p0" if hero == "kai"
		else "p1"}))
	if not bal.is_empty():
		s.balance = RtBalance.from_values(bal)
	var sim: RtSim = RtKit.no_ai(RtSim.new(s, RtKit.data()))
	sim.start()
	for u: RtUnit in sim.units():
		u.auto_on = false
	return sim


func _until(sim: RtSim, ct: int) -> Array[ActionEvent]:
	var out: Array[ActionEvent] = []
	while sim.tick() < ct and not sim.is_finished():
		out.append_array(sim.step())
	return out


func _first(events: Array[ActionEvent], type: ActionEvent.Type) -> ActionEvent:
	var l: Array[ActionEvent] = RtKit.of(events, type)
	return l[0] if not l.is_empty() else null


func test_drink_pause() -> void:
	var sim: RtSim = _sim()
	var kai: RtUnit = sim.unit("p0")
	kai.auto_on = true
	kai.hp -= 100
	sim.submit(RtCommand.target(0, "p0", "e0"))
	assert_eq(sim.submit(RtCommand.item(0, "p0", "itm_bandage", "")), "")
	var ev: Array[ActionEvent] = sim.step()
	var st: ActionEvent = _first(ev, T.ACTION_START)
	assert_not_null(st)
	if st != null:
		assert_eq([st.command, st.item_id, st.skill_id, st.target_ids, st.by_ai, st.text],
			[K.ITEM, "itm_bandage", "skl_item_bandage", PackedStringArray(["p0"]), false, "Werbepflaster"])
	assert_eq([sim.items["itm_bandage"], kai.gcd_until], [2, 0], "used up at the start; GCD free")
	assert_eq(sim.can_use("p0", "skl_kai_heavy_swing", "e0"), "drinking")
	assert_eq(sim.can_use_item("p0", "itm_antidote", ""), "drinking")
	ev = _until(sim, 15)
	assert_eq(RtKit.of(ev, T.SWING).size(), 0, "no auto-attack while drinking")
	assert_eq(RtKit.of(ev, T.HEAL).size(), 0)
	ev = sim.step()
	var heal: ActionEvent = _first(ev, T.HEAL)
	assert_true(heal != null and heal.amount == 100 and heal.actor_id == "p0", "the effect at the end (capped at 100)")
	var end: ActionEvent = _first(ev, T.ACTION_END)
	assert_true(end != null and end.item_id == "itm_bandage" and end.tick == 15)
	var sw: ActionEvent = _first(ev, T.SWING)
	assert_true(sw != null and sw.actor_id == "p0", "and the swing right after it")
	assert_true(ev.find(heal) < ev.find(sw), "step 6 before step 8")


func test_no_item_while_casting() -> void:
	var sim: RtSim = _sim({}, {}, "mopsula")
	sim.submit(RtCommand.target(0, "p1", "e0"))
	sim.submit(RtCommand.ability(0, "p1", "skl_mop_noble_flame", ""))
	sim.step()
	assert_eq(sim.submit(RtCommand.item(1, "p1", "itm_bandage", "")), "", "the static check passes")
	var r: ActionEvent = _first(sim.step(), T.ACTION_REFUSED)
	assert_true(r != null and r.text == "casting" and r.item_id == "itm_bandage" and r.skill_id == "skl_item_bandage",
		"refused in step 1b")
	assert_eq(sim.items["itm_bandage"], 3, "nothing used")


func test_party_cooldown_and_limit() -> void:
	var sim: RtSim = _sim({"itm_brutzel_burger": 1})
	assert_eq(RtKit.act(sim, RtCommand.item(0, "p0", "itm_bandage", ""))[0], "")
	assert_eq([sim.item_cd_left(), sim.item_cd_total(), sim.items_left()], [449, 450, 2])
	_until(sim, 20)
	assert_eq(sim.can_use_item("p0", "itm_brutzel_burger", ""), "item_cd", "one cooldown for every consumable")
	assert_eq(sim.can_use_item("p1", "itm_bandage", ""), "item_cd", "and for the whole party")
	var r: ActionEvent = _first(RtKit.act(sim, RtCommand.item(20, "p0", "itm_brutzel_burger", ""))[1], T.ACTION_REFUSED)
	assert_true(r != null and r.text == "item_cd")
	_until(sim, 451)
	assert_eq(sim.can_use_item("p0", "itm_brutzel_burger", ""), "", "450 ticks later")
	var free: RtSim = _sim({}, {}, "kai", {"ITEM_CD_TICKS": 0})
	for i in 3:
		assert_eq(free.can_use_item("p0", "itm_bandage", ""), "", "use %d" % (i + 1))
		RtKit.act(free, RtCommand.item(free.tick(), "p0", "itm_bandage", ""))
		_until(free, free.tick() + 15)
	assert_eq([free.items_left(), free.items["itm_bandage"]], [0, 0])
	free.items["itm_bandage"] = 5
	assert_eq(free.can_use_item("p0", "itm_bandage", ""), "items_max", "at most 3 per combat")
	assert_eq(free.submit(RtCommand.item(free.tick(), "p0", "itm_key_master", "")), "", "a known item passes submit")
	var nk: ActionEvent = _first(free.step(), T.ACTION_REFUSED)
	assert_true(nk != null and nk.text == "no_item", "not a combat item")
	assert_eq(free.submit(RtCommand.item(free.tick(), "p0", "itm_does_not_exist", "")), "no_item")
	var none: RtSim = _sim()
	none.items["itm_antidote"] = 0
	assert_eq(none.can_use_item("p0", "itm_antidote", ""), "no_item", "none left")


func test_potion_key() -> void:
	var sim: RtSim = _sim({"itm_brutzel_burger": 1})
	var kai: RtUnit = sim.unit("p0")
	assert_eq(sim.bar("p0").get(6, ""), "itm_bandage", "full HP: the smallest heal item covers 0")
	kai.hp = kai.max_hp() - 100
	assert_eq(sim.bar("p0")[6], "itm_bandage", "180 covers 100")
	kai.hp = kai.max_hp() - 300
	assert_eq(sim.bar("p0")[6], "itm_brutzel_burger", "180 does not cover 300, 480 does")
	kai.stats.values[StatBlock.Stat.HP] = 1000
	kai.hp = 400
	assert_eq(sim.bar("p0")[6], "itm_brutzel_burger", "nothing covers 600: the biggest")
	var mop: RtUnit = sim.unit("p1")
	mop.hp = mop.max_hp() - 100
	sim.step()
	RtKit.act(sim, RtCommand.target(sim.tick(), "p0", "p1"))
	assert_eq(sim.bar("p0")[6], "itm_bandage", "for the friendly target")
	assert_eq(sim.can_use_item("p0", "itm_bandage", ""), "")
	RtKit.act(sim, RtCommand.item(sim.tick(), "p0", "itm_bandage", ""))
	var ev: Array[ActionEvent] = _until(sim, sim.tick() + 15)
	var heal: ActionEvent = _first(ev, T.HEAL)
	assert_true(heal != null and heal.target_id == "p1" and heal.amount == 100, "the item goes to the friendly target")
	sim.items = {"itm_antidote": 1, "itm_bandage": 0}
	assert_false(sim.bar("p0").has(6), "no heal item left: no potion slot")


func test_item_effects() -> void:
	var sim: RtSim = _sim({"itm_energy_krawumm": 1, "itm_smelling_salts": 1}, {}, "kai", {"ITEM_CD_TICKS": 0})
	var kai: RtUnit = sim.unit("p0")
	var mop: RtUnit = sim.unit("p1")
	kai.mp = 0
	RtKit.act(sim, RtCommand.item(0, "p0", "itm_energy_krawumm", ""))
	var mp: ActionEvent = _first(_until(sim, 16), T.MP_CHANGE)
	assert_true(mp != null and mp.target_id == "p0" and mp.amount == mini(20, kai.max_mp()), "KRAWUMM: +20 MP")
	Damage.apply(sim, sim.unit("e0"), mop, mop.hp, Elements.PHYSICAL, HitResult.new(), "skl_e_dummy_poke", "", "",
		Damage.Kind.AUTO, true, K.ATTACK, 1000)
	assert_true(mop.is_ko())
	assert_eq(sim.bar("p0").get(6, ""), "itm_bandage")
	assert_eq(RtKit.act(sim, RtCommand.item(sim.tick(), "p0", "itm_smelling_salts", ""))[0], "")
	var ev: Array[ActionEvent] = _until(sim, sim.tick() + 15)
	var rv: ActionEvent = _first(ev, T.REVIVE)
	assert_true(rv != null and rv.target_id == "p1" and rv.hp_after == FixedMath.div_round(mop.max_hp() * 30, 100),
		"Riechsalz: 30 % of max HP")
	var g: Array = RtKit.of(ev, T.STATUS_ADDED).filter(func(x: ActionEvent) -> bool: return x.status_id == "sts_guard")
	assert_true(g.size() == 1 and g[0].target_id == "p1" and g[0].value == 90, "with the Comeback guard (3 s)")
	StatusFx.apply(sim, "e0", kai, "sts_poison", 0, 1000)
	RtKit.act(sim, RtCommand.item(sim.tick(), "p0", "itm_antidote", ""))
	ev = _until(sim, sim.tick() + 15)
	var gone: Array = RtKit.of(ev, T.STATUS_REMOVED).map(func(x: ActionEvent) -> String: return x.status_id)
	assert_eq(gone, ["sts_poison"], "Gegengift cleanses")


func test_molotov_area_fixed_damage() -> void:
	var sim: RtSim = _sim({"itm_molotov": 1}, RtKit.encounter("enc_rt_rats", [["g", "enc_rt_rats", [0, -300, 128]]]))
	assert_eq(RtKit.act(sim, RtCommand.item(0, "p0", "itm_molotov", "e0"))[0], "")
	var ev: Array[ActionEvent] = _until(sim, 16)
	var d: Array[ActionEvent] = RtKit.of(ev, T.DAMAGE)
	assert_eq(d.map(func(x: ActionEvent) -> Array: return [x.tick, x.target_id, x.amount, x.item_id, x.element]),
		[[15, "e0", 360, "itm_molotov", "fire"], [15, "e1", 360, "itm_molotov", "fire"]],
		"60 × FIXED_SCALE_PM 4000 × fire weakness 1.5 on both rats within 4 m of the target")
	var ko: Array[ActionEvent] = RtKit.of(ev, T.KO)
	assert_eq(ko.map(func(x: ActionEvent) -> Array: return [x.target_id, x.command, x.item_id, x.value]),
		[["e0", K.ITEM, "itm_molotov", 1], ["e1", K.ITEM, "itm_molotov", 1]], "overkill: 360 ≥ 50 % of 168")
	assert_true(sim.is_finished())
	assert_eq(sim.result.outcome, BattleResult.Outcome.VICTORY)
	assert_eq([sim.result.items_used, sim.result.item_delta], [1, {"itm_molotov": -1}])


func test_smoke_bomb() -> void:
	var sim: RtSim = _sim({"itm_smoke": 1})
	assert_eq(RtKit.act(sim, RtCommand.item(0, "p0", "itm_smoke", ""))[0], "")
	var ev: Array[ActionEvent] = _until(sim, 30)
	assert_true(sim.is_finished())
	var fr: ActionEvent = _first(ev, T.FLEE_RESULT)
	assert_true(fr != null and fr.tick == 15 and fr.success and fr.text == "", "flight at the end of the drink")
	assert_eq(ev[ev.size() - 1].type, T.BATTLE_END)
	assert_eq([sim.result.outcome, sim.result.flee_attempts, sim.result.items_used, sim.result.item_delta],
		[BattleResult.Outcome.FLED, 1, 1, {"itm_smoke": -1}])
	var boss: RtSim = _sim({"itm_smoke": 1}, RtKit.encounter("enc_rt_test_boss", [["g", "enc_rt_test_boss",
		[0, -300, 128]]]))
	assert_eq(boss.submit(RtCommand.item(0, "p0", "itm_smoke", "")), "forbidden", "no flight from a closed set")
	assert_eq(boss.can_use_item("p0", "itm_smoke", ""), "forbidden")
	assert_eq(boss.can_use_item("p0", "itm_bandage", ""), "")
