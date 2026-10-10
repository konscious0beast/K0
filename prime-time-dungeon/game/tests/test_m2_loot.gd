extends TestCase
## M2 loot (02_TECH §6.1 roll_lootbox steps 1–4, GDD §2.5/§9): determinism, rarity → pool, guarantee on the last
## roll, pity 4/8 persistent in GameState, duplicate equipment → credits × 1.5, fan box, pool fallback, chests, chest
## table, drops, best_rarity.

const Fx := preload("res://tests/test_m2_fixtures.gd")


func _state() -> GameState:
	return GameState.create_new(Fx.data(), 0, "Kai", 1)


static func _dicts(rewards: Array[LootReward]) -> Array:
	var out: Array = []
	for r: LootReward in rewards:
		out.append(r.to_dict())
	return out


func test_reward_to_dict() -> void:
	var r: LootReward = LootReward.new()
	r.kind = "credits"
	r.amount = 360
	r.rarity = "rare"
	r.converted_from = "itm_wpn_axe"
	r.pity = true
	assert_eq(r.to_dict(), {"kind": "credits", "id": "", "amount": 360, "rarity": "rare",
		"converted_from": "itm_wpn_axe", "pity": true})


func test_lootbox_deterministic_per_rng_and_state() -> void:
	var d: GameData = Fx.data()
	for box_id: String in ["box_bronze", "box_silver", "box_gold", "box_fan"]:
		var a: Array = _dicts(LootRoller.roll_lootbox(d.lootbox(box_id), d, 1, _state(), make_rng(99)))
		var b: Array = _dicts(LootRoller.roll_lootbox(d.lootbox(box_id), d, 1, _state(), make_rng(99)))
		assert_eq(a, b, box_id + ": same rng seed + same state → same rewards")
	var distinct: Dictionary = {}
	for s in 30:
		distinct[str(_dicts(LootRoller.roll_lootbox(d.lootbox("box_bronze"), d, 1, _state(), make_rng(s))))] = true
	assert_gt(distinct.size(), 3, "different seeds give different boxes")


func test_lootbox_roll_count_and_rarity_to_pool() -> void:
	var d: GameData = Fx.data()
	for s in 20:
		var gold: Array[LootReward] = LootRoller.roll_lootbox(d.lootbox("box_gold"), d, 1, _state(), make_rng(s))
		assert_len(gold, 4, "gold: 4 rolls")
		var silver: Array[LootReward] = LootRoller.roll_lootbox(d.lootbox("box_silver"), d, 1, _state(), make_rng(s))
		assert_len(silver, 3, "silver: 3 rolls")
		var epic: Array[LootReward] = LootRoller.roll_lootbox(d.lootbox("box_epic1"), d, 1, _state(), make_rng(s))
		assert_len(epic, 1)
		assert_eq(epic[0].rarity, "epic")
		assert_true(epic[0].id == "itm_acc_mask" or (epic[0].kind == "credits" and epic[0].amount == 400),
			"entry from pools.f1.epic")
		var common: Array[LootReward] = LootRoller.roll_lootbox(d.lootbox("box_common1"), d, 1, _state(), make_rng(s))
		assert_eq(common[0].rarity, "common")
		assert_true(common[0].id == "itm_bandage" or (common[0].kind == "credits" and common[0].amount == 25),
			"entry from pools.f1.common")


func test_lootbox_guarantee_on_last_roll() -> void:
	var d: GameData = Fx.data()
	for s in 10:
		var st: GameState = _state()
		var r: Array[LootReward] = LootRoller.roll_lootbox(d.lootbox("box_guar_rare"), d, 1, st, make_rng(s))
		assert_eq([r[0].rarity, r[1].rarity, r[2].rarity], ["common", "common", "rare"], "unmet → last roll rare")
		assert_false(r[2].pity, "a guarantee is not pity")
		assert_eq([st.pity_rare, st.pity_epic], [0, 1], "a guaranteed rare resets rare pity only")
		var e: Array[LootReward] = LootRoller.roll_lootbox(d.lootbox("box_guar_epic"), d, 1, _state(), make_rng(s))
		assert_eq([e[0].rarity, e[1].rarity], ["common", "epic"])
	# real silver boxes always contain rare or better
	for s in 200:
		var best: String = LootRoller.best_rarity(LootRoller.roll_lootbox(d.lootbox("box_silver"), d, 1, _state(),
			make_rng(s)))
		assert_true(best == "rare" or best == "epic", "silver guarantee (seed %d)" % s)


func test_pity_rare_after_four_boxes_and_epic_after_eight() -> void:
	var d: GameData = Fx.data()
	var st: GameState = _state()
	var rng: RandomNumberGenerator = make_rng(1)
	for i in 4:
		var r: Array[LootReward] = LootRoller.roll_lootbox(d.lootbox("box_common1"), d, 1, st, rng)
		assert_eq(r[0].rarity, "common")
	assert_eq([st.pity_rare, st.pity_epic], [4, 4], "counters persist in GameState")
	var forced: Array[LootReward] = LootRoller.roll_lootbox(d.lootbox("box_common1"), d, 1, st, rng)
	assert_eq(forced[0].rarity, "rare", "pity 4 → first roll rare")
	assert_true(forced[0].pity, "GARANTIE marker")
	assert_eq([st.pity_rare, st.pity_epic], [0, 5])
	for i in 3:
		LootRoller.roll_lootbox(d.lootbox("box_common1"), d, 1, st, rng)
	assert_eq(st.pity_epic, 8)
	assert_eq(st.pity_rare, 3)
	var epic: Array[LootReward] = LootRoller.roll_lootbox(d.lootbox("box_common1"), d, 1, st, rng)
	assert_eq(epic[0].rarity, "epic", "pity 8 → first roll epic")
	assert_true(epic[0].pity)
	assert_eq([st.pity_rare, st.pity_epic], [0, 0], "epic resets both counters")
	# epic has priority when both are due
	st.pity_rare = 4
	st.pity_epic = 8
	assert_eq(LootRoller.roll_lootbox(d.lootbox("box_common1"), d, 1, st, rng)[0].rarity, "epic")
	# state round trip keeps the counters
	st.pity_rare = 3
	st.pity_epic = 7
	var back: GameState = GameState.from_dict(JSON.parse_string(JSON.stringify(st.to_dict())))
	assert_eq([back.pity_rare, back.pity_epic], [3, 7], "pity counters are saved")


func test_duplicate_equipment_becomes_credits() -> void:
	var d: GameData = Fx.data()
	var st: GameState = _state()
	var first: Array[LootReward] = LootRoller.roll_lootbox(d.lootbox("box_common2"), d, 3, st, make_rng(4))
	assert_eq(first[0].to_dict(), {"kind": "item", "id": "itm_wpn_axe", "amount": 1, "rarity": "common",
		"converted_from": "", "pity": false})
	assert_eq(first[1].to_dict(), {"kind": "credits", "id": "", "amount": 120, "rarity": "common",
		"converted_from": "itm_wpn_axe", "pity": false}, "earlier in this box → roundi(240 × 0.5)")
	st.inventory.add("itm_wpn_axe")
	var owned: Array[LootReward] = LootRoller.roll_lootbox(d.lootbox("box_common1"), d, 3, st, make_rng(4))
	assert_eq(owned[0].converted_from, "itm_wpn_axe", "in the inventory")
	st.inventory.remove("itm_wpn_axe")
	st.member("kai").equipment["weapon"] = "itm_wpn_axe"
	var equipped: Array[LootReward] = LootRoller.roll_lootbox(d.lootbox("box_common1"), d, 3, st, make_rng(4))
	assert_eq(equipped[0].kind, "credits", "equipped counts as owned")
	var consumables: Array[LootReward] = LootRoller.roll_lootbox(d.lootbox("box_common2"), d, 2, st, make_rng(4))
	assert_eq(consumables[0].converted_from, "", "only equipment converts")


func test_fan_box_fixed_entry_and_pool_fallback() -> void:
	var d: GameData = Fx.data()
	var st: GameState = _state()
	var fan: Array[LootReward] = LootRoller.roll_lootbox(d.lootbox("box_fan"), d, 1, st, make_rng(8))
	assert_len(fan, 3, "1 fixed fan entry + 2 rolls")
	assert_eq([fan[0].id, fan[0].rarity], ["itm_acc_mic", "epic"], "fan entry shown as epic")
	var rolled_epic: bool = fan[1].rarity == "epic" or fan[2].rarity == "epic"
	assert_eq(st.pity_epic, 0 if rolled_epic else 1, "the fixed fan entry does not count for pity")
	# floor 2 has only a common pool: epic/rare rolls fall back to common
	var st2: GameState = _state()
	var f2: Array[LootReward] = LootRoller.roll_lootbox(d.lootbox("box_epic1"), d, 2, st2, make_rng(1))
	assert_eq(f2[0].to_dict(), {"kind": "credits", "id": "", "amount": 50, "rarity": "common", "converted_from": "",
		"pity": false})
	assert_eq([st2.pity_rare, st2.pity_epic], [1, 1], "a fallback common does not reset pity")
	assert_eq(LootRoller.roll_lootbox(null, d, 1, st2, make_rng(1)), [])


func test_layout_chests() -> void:
	var d: GameData = Fx.data()
	var wood: Dictionary = {"id": "f1_c0", "type": "wood", "contents": []}
	for s in 50:
		var r: Array[LootReward] = LootRoller.roll_chest(wood, d, 1, _state(), make_rng(s))
		assert_len(r, 2, "credits + 1 common roll")
		assert_eq(r[0].kind, "credits")
		assert_between(r[0].amount, 10, 25, "10–25 credits")
		assert_eq(r[1].rarity, "common")
		assert_eq(_dicts(LootRoller.roll_chest(wood, d, 1, _state(), make_rng(s))), _dicts(r), "deterministic")
	var metal: Dictionary = {"id": "f1_c1", "type": "metal", "contents": [{"kind": "item", "id": "itm_arm_vest",
		"amount": 1}, {"kind": "credits", "id": "", "amount": 15}]}
	assert_eq(_dicts(LootRoller.roll_chest(metal, d, 1, _state(), make_rng(1))), [
		{"kind": "item", "id": "itm_arm_vest", "amount": 1, "rarity": "rare", "converted_from": "", "pity": false},
		{"kind": "credits", "id": "", "amount": 15, "rarity": "common", "converted_from": "", "pity": false}])
	var locked: Dictionary = {"id": "f1_c2", "type": "locked", "contents": [{"kind": "item", "id": "itm_wpn_axe",
		"amount": 1}]}
	assert_eq(LootRoller.roll_chest(locked, d, 1, _state(), null)[0].id, "itm_wpn_axe", "fixed contents need no rng")
	assert_eq(LootRoller.roll_chest({}, d, 1, _state(), make_rng(1)), [])


func test_procedural_chest_table() -> void:
	var def: FloorDef = Fx.data().floor_def(2)
	var twice: int = 0
	for s in 1000:
		var r: Array[LootReward] = LootRoller.roll_chest_table(def, make_rng(s))
		assert_between(r.size(), 1, 2)
		if r.size() == 2:
			twice += 1
		for x: LootReward in r:
			if x.kind == "item":
				assert_eq(x.id, "itm_bandage")
				assert_between(x.amount, 1, 2)
			else:
				assert_between(x.amount, 30, 60)
	assert_between(twice, 160, 240, "second roll at 20 %")
	assert_eq(LootRoller.roll_chest_table(Fx.data().floor_def(1), make_rng(1)), [], "no table → nothing")


## M3 CR 1: a procedural wood chest carries the contents DungeonGenerator rolled from FloorDef.chest_table (§7.2
## step 9) — roll_chest gives exactly those (no 20–40 Cr pool roll, no rng needed).
func test_wood_chest_with_contents_gives_them() -> void:
	var d: GameData = Fx.data()
	var proc: Dictionary = {"id": "f2_c0", "type": "wood", "contents": [{"kind": "item", "id": "itm_bandage",
		"amount": 2}, {"kind": "credits", "id": "", "amount": 45}]}
	assert_eq(_dicts(LootRoller.roll_chest(proc, d, 2, _state(), null)), [
		{"kind": "item", "id": "itm_bandage", "amount": 2, "rarity": "common", "converted_from": "", "pity": false},
		{"kind": "credits", "id": "", "amount": 45, "rarity": "common", "converted_from": "", "pity": false}])
	var layout: FloorLayout = DungeonGenerator.generate(d.floor_def(2), 777)
	var chest: ChestSpawn = layout.chests[0]
	assert_false(chest.contents.is_empty(), "procedural chests are filled from the chest table")
	var spec: Dictionary = {"id": chest.id, "type": chest.type, "contents": chest.contents}
	var got: Array = _dicts(LootRoller.roll_chest(spec, d, 2, _state(), make_rng(5)))
	assert_eq(got.size(), chest.contents.size(), "the chest-table roll, not the wood pool")
	for i in got.size():
		assert_eq([got[i]["kind"], got[i]["amount"]], [chest.contents[i]["kind"], chest.contents[i]["amount"]])


## quality-5: the victory drop rule has one implementation (BattleState.roll_drops, used by the battle itself).
## GDD §3.12: chance × (1 + Ø LCK / 100) with Ø over all party members.
func test_drops_chance_with_luck() -> void:
	var drops: Array[Dictionary] = [{"item": "itm_bandage", "chance": 0.25}, {"item": "itm_salts", "chance": 0.0},
		{"item": "itm_antidote", "chance": 1.0}]
	var rng: RandomNumberGenerator = make_rng(3)
	var hits: int = 0
	for i in 4000:
		var got: PackedStringArray = BattleState.roll_drops(drops, 0, 2, rng)
		assert_false(got.has("itm_salts"), "chance 0 never drops")
		assert_true(got.has("itm_antidote"), "chance 1 always drops")
		if got.has("itm_bandage"):
			hits += 1
	assert_between(hits, 880, 1120, "≈ 25 %")
	hits = 0
	for i in 4000:
		if BattleState.roll_drops(drops, 200, 2, rng).has("itm_bandage"):
			hits += 1
	assert_between(hits, 1850, 2150, "× (1 + Ø LCK 100 / 100) → ≈ 50 %")
	assert_eq(BattleState.roll_drops(drops, 20, 2, make_rng(5)), BattleState.roll_drops(drops, 20, 2, make_rng(5)))
	var probe: RandomNumberGenerator = make_rng(9)
	var before: int = probe.state
	BattleState.roll_drops([{"item": "itm_salts", "chance": 0.0}, {"item": "itm_antidote", "chance": 1.0}], 0, 2, probe)
	assert_eq(probe.state, before, "no draw at 0 % or >= 100 % (FixedMath.roll_bp)")


func test_best_rarity() -> void:
	var a: LootReward = LootReward.new()
	var b: LootReward = LootReward.new()
	b.rarity = "rare"
	var c: LootReward = LootReward.new()
	c.rarity = "epic"
	assert_eq(LootRoller.best_rarity([]), "common")
	assert_eq(LootRoller.best_rarity([a, b]), "rare")
	assert_eq(LootRoller.best_rarity([c, a, b]), "epic")
