extends TestCase
## M1: CTB tick system (02_TECH §5.5, GDD §3.2–3.4): base_delay table, ranks, haste/slow, start values,
## tie-breaks, preview 12 incl. pending_rank, overrides and pseudo units.

const Fx := preload("res://tests/test_m1_fixture.gd")

var data: GameData


func before_each() -> void:
	data = fixture_data(Fx.tables())


func _unit(def_id: String, id: String, slot: int, counter: int) -> Combatant:
	var c: Combatant
	if def_id.begins_with("enm_"):
		c = Combatant.create_enemy(data.enemy(def_id), id, slot)
	else:
		c = Fx.member(data, def_id, id, slot)
	c.ctb_counter = counter
	return c


func _queue(units: Array[Combatant]) -> CTBQueue:
	var q: CTBQueue = CTBQueue.new()
	for c: Combatant in units:
		q.add(c, c.ctb_counter)
	return q


func test_base_delay_table() -> void:
	var table: Dictionary = {5: 67, 7: 59, 9: 53, 10: 50, 11: 48, 12: 45, 13: 43, 14: 42, 15: 40, 16: 38, 17: 37,
		19: 34, 20: 33, 25: 29, 30: 25}
	for spd: int in table.keys():
		assert_eq(CTBQueue.base_delay(spd), table[spd], "base_delay(%d) (GDD §3.2)" % spd)
	for spd in range(1, 200):
		assert_eq(CTBQueue.base_delay(spd), roundi(1000.0 / float(spd + 10)),
				"integer form == roundi(1000/(spd+10)) at %d" % spd)


func test_delay_for_ranks_haste_slow() -> void:
	var kai: Combatant = Fx.member(data, "kai", "p0", 0)   # SPD 11 → base_delay 48
	assert_eq(CTBQueue.delay_for(kai, 2), 32, "48 × 2/3")
	assert_eq(CTBQueue.delay_for(kai, 3), 48)
	assert_eq(CTBQueue.delay_for(kai, 4), 64)
	assert_eq(CTBQueue.delay_for(kai, 5), 80)
	assert_eq(CTBQueue.delay_for(kai, 6), 96)
	kai.statuses.append(StatusEffect.new(data.status("sts_haste"), 3, ""))
	assert_eq(CTBQueue.delay_for(kai, 3), 29, "haste: 48 × 0.6 = 28.8 → 29")
	assert_eq(CTBQueue.delay_for(kai, 4), 38, "haste: 64 × 0.6 = 38.4 → 38")
	kai.statuses.clear()
	kai.statuses.append(StatusEffect.new(data.status("sts_slow"), 3, ""))
	assert_eq(CTBQueue.delay_for(kai, 3), 72, "slow: 48 × 1.5")
	assert_eq(CTBQueue.delay_for(kai, 2), 48, "slow rank 2: 32 × 1.5")
	kai.statuses.clear()
	kai.stats.set_stat(StatBlock.Stat.SPD, 5000)
	assert_eq(CTBQueue.delay_for(kai, 1), 1, "never below 1")
	# Integer delay == roundi of the exact rational value for all ranks/speeds (no float representation errors).
	var mop: Combatant = Fx.member(data, "mopsula", "p1", 1)
	for spd in range(1, 41):
		mop.stats.set_stat(StatBlock.Stat.SPD, spd)
		for rank in range(1, 7):
			var bd: int = CTBQueue.base_delay(spd)
			var exact: float = float(bd * rank) / 3.0
			if absf(exact - floorf(exact) - 0.5) > 0.0001:
				assert_eq(CTBQueue.delay_for(mop, rank), maxi(1, roundi(exact)), "spd %d rank %d" % [spd, rank])


func test_start_counters_normal_deterministic_and_in_range() -> void:
	var units: Array[Combatant] = [_unit("kai", "p0", 0, -1), _unit("mopsula", "p1", 1, -1), _unit("enm_rat", "e0", 0, -1),
		_unit("enm_pigeon", "e1", 1, -1)]
	var q: CTBQueue = CTBQueue.new()
	q.setup(units, BattleSetup.Advantage.NORMAL, make_rng(77))
	var first: Array[int] = []
	for c: Combatant in units:
		var bd: int = CTBQueue.base_delay(c.stat(StatBlock.Stat.SPD))
		assert_between(c.ctb_counter, roundi(bd * 0.5), bd, "NORMAL start in [0.5, 1.0] × base_delay (%s)" % c.id)
		first.append(c.ctb_counter)
	q.setup(units, BattleSetup.Advantage.NORMAL, make_rng(77))
	var again: Array[int] = []
	for c: Combatant in units:
		again.append(c.ctb_counter)
	assert_eq(again, first, "same rng seed → same start counters")
	var differs: bool = false
	for s in range(1, 20):
		q.setup(units, BattleSetup.Advantage.NORMAL, make_rng(1000 + s))
		var other: Array[int] = []
		for c: Combatant in units:
			other.append(c.ctb_counter)
		if other != first:
			differs = true
	assert_true(differs, "different seeds give different start counters")


func test_start_counters_preemptive_and_ambush() -> void:
	var units: Array[Combatant] = [_unit("kai", "p0", 0, -1), _unit("mopsula", "p1", 1, -1), _unit("enm_rat", "e0", 0, -1)]
	var q: CTBQueue = CTBQueue.new()
	q.setup(units, BattleSetup.Advantage.PREEMPTIVE, make_rng(1))
	assert_eq(units[0].ctb_counter, 0)
	assert_eq(units[1].ctb_counter, 0)
	assert_eq(units[2].ctb_counter, 43, "enemy: full base_delay (SPD 13)")
	q.setup(units, BattleSetup.Advantage.AMBUSH, make_rng(1))
	assert_eq(units[0].ctb_counter, 48, "party: full base_delay (SPD 11)")
	assert_eq(units[1].ctb_counter, 42, "SPD 14")
	assert_eq(units[2].ctb_counter, 0)
	var s: BattleState = Fx.make_state(data, PackedStringArray(["enm_rat"]),
			{"advantage": BattleSetup.Advantage.PREEMPTIVE})
	var ev: Array[ActionEvent] = s.start()
	assert_eq(ev[0].value, BattleSetup.Advantage.PREEMPTIVE)
	assert_eq(ev[1].type, ActionEvent.Type.ANNOUNCE)
	assert_eq(ev[1].text, "Präventivschlag!")
	assert_true(s.current_actor().is_party(), "preemptive: party acts first")
	var amb: BattleState = Fx.make_state(data, PackedStringArray(["enm_rat"]), {"advantage": BattleSetup.Advantage.AMBUSH})
	var aev: Array[ActionEvent] = amb.start()
	assert_eq(aev[1].text, "Hinterhalt!")
	assert_eq(Fx.of_type(aev, ActionEvent.Type.TURN_START)[0].actor_id, "e0", "ambush: enemy acts first")


func test_bosses_always_start_normal() -> void:
	var s: BattleState = Fx.make_state(data, PackedStringArray(["enm_boss_janitor"]),
			{"advantage": BattleSetup.Advantage.PREEMPTIVE, "is_boss": true})
	var ev: Array[ActionEvent] = s.start()
	assert_eq(ev[0].value, BattleSetup.Advantage.NORMAL, "boss battles ignore the advantage")
	assert_len(Fx.of_type(ev, ActionEvent.Type.ANNOUNCE), 0)
	assert_eq(s.advantage, BattleSetup.Advantage.NORMAL)


func test_next_actor_tie_breaks_and_subtraction() -> void:
	var kai: Combatant = _unit("kai", "p0", 0, 10)        # SPD 11
	var mop: Combatant = _unit("mopsula", "p1", 1, 10)    # SPD 14
	var rat: Combatant = _unit("enm_rat", "e0", 0, 10)    # SPD 13
	var pig: Combatant = _unit("enm_pigeon", "e1", 1, 25)
	var train: Combatant = Combatant.create_pseudo(data.pseudo_unit("pu_train"), "u0")
	train.ctb_counter = 10
	var q: CTBQueue = _queue([train, rat, kai, mop, pig])
	assert_eq(q.next_actor(), mop, "party before enemy before pseudo; higher SPD first")
	assert_eq(kai.ctb_counter, 0)
	assert_eq(pig.ctb_counter, 15, "the actor's counter is subtracted from all living")
	assert_eq(train.ctb_counter, 0)
	mop.ctb_counter = 99
	assert_eq(q.next_actor(), kai)
	kai.ctb_counter = 99
	assert_eq(q.next_actor(), rat, "enemy before pseudo")
	rat.ctb_counter = 99
	assert_eq(q.next_actor(), train)
	var r2: Combatant = _unit("enm_rat", "e2", 3, 5)
	var r3: Combatant = _unit("enm_rat", "e3", 2, 5)
	var q2: CTBQueue = _queue([r2, r3])
	assert_eq(q2.next_actor(), r3, "same group and SPD → lower slot")
	r3.hp = 0
	assert_eq(q2.next_actor(), r2, "dead units never act")
	r2.hp = 0
	assert_null(q2.next_actor())


func test_preview_is_pure_and_uses_pending_rank() -> void:
	var kai: Combatant = _unit("kai", "p0", 0, 0)        # current actor, base_delay 48
	var mop: Combatant = _unit("mopsula", "p1", 1, 10)   # base_delay 42
	var rat: Combatant = _unit("enm_rat", "e0", 0, 20)   # base_delay 43
	var q: CTBQueue = _queue([kai, mop, rat])
	assert_eq(q.preview(6, kai, 3), PackedStringArray(["p0", "p1", "e0", "p0", "p1", "e0"]))
	assert_eq(q.preview(6, kai, 6), PackedStringArray(["p0", "p1", "e0", "p1", "e0", "p1"]),
			"rank 6 pushes the actor's follow-up back")
	assert_eq(q.preview(6, kai, -1), q.preview(6, kai, 3), "-1 → rank 3")
	assert_eq(q.preview(6, kai, 3, {"e0": 100}), PackedStringArray(["p0", "p1", "p0", "p1", "p1", "p0"]),
			"override = ghost preview counter")
	assert_eq([kai.ctb_counter, mop.ctb_counter, rat.ctb_counter], [0, 10, 20], "preview never mutates")
	assert_len(q.preview(CTBQueue.PREVIEW_LENGTH), 12)
	assert_eq(q.preview(1)[0], "p0", "without actor: index 0 = next actor")
	assert_len(q.preview(0), 0)
	mop.hp = 0
	assert_false(q.preview(12).has("p1"), "dead units are not previewed")


func test_preview_with_haste_and_pseudo_unit() -> void:
	var kai: Combatant = _unit("kai", "p0", 0, 0)
	var rat: Combatant = _unit("enm_rat", "e0", 0, 30)
	var q: CTBQueue = _queue([kai, rat])
	var plain: PackedStringArray = q.preview(8, kai, 3)
	kai.statuses.append(StatusEffect.new(data.status("sts_haste"), 3, ""))
	var hasted: PackedStringArray = q.preview(8, kai, 3)
	var count_plain: int = 0
	var count_haste: int = 0
	for id: String in plain:
		count_plain += 1 if id == "p0" else 0
	for id: String in hasted:
		count_haste += 1 if id == "p0" else 0
	assert_gt(count_haste, count_plain, "haste gives the unit more entries")
	kai.statuses.clear()
	var train: Combatant = Combatant.create_pseudo(data.pseudo_unit("pu_train"), "u0")
	q.add(train, 15)
	var order: PackedStringArray = q.preview(12, kai, 3)
	var positions: Array[int] = []
	for i in order.size():
		if order[i] == "u0":
			positions.append(i)
	assert_eq(positions, [1, 9], "pseudo at its counter (15 < 30), next time after ctr_after 160 ticks")
	assert_eq(order.slice(0, 3), PackedStringArray(["p0", "u0", "e0"]))
	q.on_acted(train, 3)
	assert_eq(train.ctb_counter, 160, "pseudo units get ctr_after")


func test_add_remove_add_delay_and_snapshot() -> void:
	var kai: Combatant = _unit("kai", "p0", 0, 5)
	var rat: Combatant = _unit("enm_rat", "e0", 0, 10)
	var q: CTBQueue = _queue([kai, rat])
	q.add_delay(kai, 20)
	assert_eq(kai.ctb_counter, 25)
	assert_eq(q.preview(1)[0], "e0")
	var summon: Combatant = _unit("enm_pigeon", "e1", 1, 0)
	q.add(summon, 3)
	assert_true(q.has_unit(summon))
	assert_eq(q.preview(1)[0], "e1")
	q.remove(summon)
	assert_false(q.preview(4).has("e1"))
	q.on_acted(kai, 4)
	assert_eq(kai.ctb_counter, 64)
	var snap: Dictionary = q.to_dict()
	assert_eq(snap, {"units": ["p0", "e0"]})
	var all: Array[Combatant] = [rat, kai]
	var back: CTBQueue = CTBQueue.from_dict(JSON.parse_string(JSON.stringify(snap)), all)
	assert_eq(back.preview(6), q.preview(6), "restored queue previews identically")
