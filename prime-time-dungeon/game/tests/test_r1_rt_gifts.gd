extends TestCase
## 07 §9.2 (R1b-I3) test_r1_rt_gifts: sponsor gifts in a real-time combat (RtSim.apply_gift) — at the tick boundary
## before step() of tick() (every event with tick = tick() and rt.boundary = 1), the CTB kinds: sponsor_buff (the
## sponsor's effects × effect_pm), gold (× effect_pm), fan_pack (server contents into the battle inventory, credits),
## chest rolls from the gift's own generator SeedUtil.derive(seed, "gift", n) — never from the combat stream; start()
## first if it has not run, nothing once the combat is over; the counter is part of the snapshot.

const FixedMath := preload("res://core/stats/fixed_math.gd")
const T := ActionEvent.Type


func _sim(seed: int = RtKit.SEED) -> RtSim:
	var s: RtSetup = RtKit.setup(RtKit.state(6), RtKit.dummy_cmd(), seed)
	var sim: RtSim = RtSim.new(s, RtKit.data())
	sim.start()
	for u: RtUnit in RtKit.no_ai(sim).units_ref():
		u.auto_on = false
	return sim


static func _short(events: Array[ActionEvent]) -> Array:
	return events.map(func(e: ActionEvent) -> String: return "%s %s %s %d %d" % [ActionEvent.type_name(e.type),
		e.target_id, e.item_id if e.item_id != "" else e.sponsor_id, e.amount, e.value])


func test_sponsor_heal_at_the_boundary() -> void:
	var sim: RtSim = _sim()
	RtKit.steps(sim, 10)
	var kai: RtUnit = sim.unit("p0")
	var mop: RtUnit = sim.unit("p1")
	kai.hp = 10
	mop.hp = mop.max_hp() - 5
	var ev: Array[ActionEvent] = sim.apply_gift({"kind": "sponsor_buff", "sponsor_id": "spn_gluckwasser"})
	assert_eq(_short(ev), ["SPONSOR_GIFT  spn_gluckwasser 0 0", "HEAL p0  %d 0" % FixedMath.div_round(kai.max_hp() * 35,
		100), "HEAL p1  5 0"], "heal_party_pct 35, capped at the missing HP")
	assert_true(ev.all(func(e: ActionEvent) -> bool: return e.tick == 10 and int(e.rt.get("boundary", 0)) == 1),
		"tick = tick(), rt.boundary = 1")
	assert_eq(ev[0].text, "Glückwasser")
	assert_eq(sim.tick(), 10, "no step")
	kai.hp = 10
	ev = sim.apply_gift({"kind": "sponsor_buff", "sponsor_id": "spn_gluckwasser", "effect_pm": 500})
	assert_eq(ev[1].amount, FixedMath.div_round(kai.max_hp() * 17, 100), "effect_pm 500: 35 × 500 / 1000 = 17 %")
	assert_eq(sim.apply_gift({"kind": "sponsor_buff", "sponsor_id": "spn_nobody"}).size(), 0, "unknown sponsor")


func test_gold_and_fan_pack() -> void:
	var sim: RtSim = _sim()
	var ev: Array[ActionEvent] = sim.apply_gift({"kind": "gold", "amount": 50, "effect_pm": 500})
	assert_eq(_short(ev), ["CREDITS_GAINED   0 25"])
	var bandages: int = int(sim.items.get("itm_bandage", 0))
	ev = sim.apply_gift({"kind": "fan_pack", "contents": [{"rarity": "common", "item_id": "itm_bandage", "qty": 2},
		{"rarity": "rare", "credits": 40}, "junk"]})
	assert_eq(_short(ev), ["ITEM_GAINED  itm_bandage 0 2", "CREDITS_GAINED   0 40"], "server contents")
	assert_eq(int(sim.items["itm_bandage"]), bandages + 2, "into the battle inventory")
	assert_eq([sim.tally["credits_delta"], sim.tally["item_delta"]], [65, {"itm_bandage": 2}])
	RtKit.steps(sim, 1)
	for e: RtUnit in sim.units_ref():
		if e.side == Combatant.Side.ENEMY:
			e.hp = 0
	sim.step()
	assert_true(sim.is_finished())
	assert_eq([sim.result.credits_delta, sim.result.item_delta], [65, {"itm_bandage": 2}], "BattleResult")
	assert_eq(sim.apply_gift({"kind": "gold", "amount": 50}).size(), 0, "nothing once the combat is over")


func test_chest_rolls_from_the_gift_stream() -> void:
	var a: RtSim = _sim()
	var n0: int = int(a.snapshot()["rng_n"])
	var ev: Array[ActionEvent] = a.apply_gift({"kind": "chest", "tier": "bronze"})
	assert_eq(int(a.snapshot()["rng_n"]), n0, "the combat stream draws nothing")
	assert_eq(int(a.snapshot()["gift_n"]), 1)
	assert_eq(ev.size(), 2, "box_bronze: 2 rolls, one entry each")
	var pool: Array = ["CREDITS_GAINED   0 25", "ITEM_GAINED  itm_bandage 0 2", "ITEM_GAINED  itm_antidote 0 2",
		"CREDITS_GAINED   0 120", "CREDITS_GAINED   0 300"]
	assert_true(_short(ev).all(func(s: String) -> bool: return pool.has(s)), "entries of the f1 pool: %s" % str(
		_short(ev)))
	var b: RtSim = _sim()
	RtKit.steps(b, 7)
	assert_eq(_short(b.apply_gift({"kind": "chest", "tier": "bronze"})), _short(ev),
		"the same gift number rolls the same, whatever the combat did")
	var rolls: Array = []
	for seed: int in [1, 2, 3, 4, 5, 6]:
		rolls.append(_short(_sim(seed).apply_gift({"kind": "chest", "tier": "gold"})))
	assert_true(rolls.any(func(r: Array) -> bool: return r != rolls[0]), "a function of the seed")
	assert_true(rolls.all(func(r: Array) -> bool: return r.size() == 4), "box_gold: 4 rolls")
	var c: RtSim = _sim()
	c.apply_gift({"kind": "gold", "amount": 1})
	c.apply_gift({"kind": "chest", "tier": "bronze"})
	assert_eq(int(c.snapshot()["gift_n"]), 2, "every gift counts (its generator: derive(seed, \"gift\", n))")


func test_start_first() -> void:
	var s: RtSetup = RtKit.setup(RtKit.state(6), RtKit.dummy_cmd())
	var sim: RtSim = RtSim.new(s, RtKit.data())
	var ev: Array[ActionEvent] = sim.apply_gift({"kind": "gold", "amount": 30})
	assert_eq(ev[0].type, T.BATTLE_START, "start() first")
	assert_eq(_short(ev).back(), "CREDITS_GAINED   0 30")
	assert_eq(int(ev.back().rt.get("boundary", 0)), 1)
	assert_eq(int(ev[0].rt.get("boundary", 0)), 0, "the start events are no gift events")
