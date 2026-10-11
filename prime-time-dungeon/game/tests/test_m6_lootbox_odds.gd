extends TestCase
## Published lootbox odds (GDD §9.3, 02_TECH §6.1 LootRoller rules) — the numbers the lootbox screen shows must match
## the roll rules: per-roll weights, "at least one" chances over all rolls, the guarantee forcing the LAST roll to
## exactly the guarantee rarity, pity forcing the FIRST roll (epic before rare). Uses fixture boxes (independent of M7
## data).

const Odds := preload("res://scenes/safe_room/lootbox_odds.gd")
const LIMITS: Dictionary = {"rare": 4, "epic": 8}
const EPS: float = 0.000001


func _box(rolls: int, weights: Dictionary, guarantee: String = "", fixed_pool: String = "") -> LootboxDef:
	var b: LootboxDef = LootboxDef.new()
	b.id = "box_probe"
	b.rolls = rolls
	b.rarity_weights = weights
	b.guarantee = guarantee
	b.fixed_pool = fixed_pool
	return b


func test_per_roll_normalizes_weights() -> void:
	var pr: Dictionary = Odds.per_roll(_box(2, {"common": 80, "rare": 18, "epic": 2}))
	assert_almost(float(pr["common"]), 0.80, EPS)
	assert_almost(float(pr["rare"]), 0.18, EPS)
	assert_almost(float(pr["epic"]), 0.02, EPS)
	var pr2: Dictionary = Odds.per_roll(_box(1, {"common": 1, "rare": 1}))
	assert_almost(float(pr2["common"]), 0.5, EPS)
	assert_almost(float(pr2["epic"]), 0.0, EPS, "missing weight = 0")


func test_bronze_two_rolls_without_guarantee() -> void:
	var o: Dictionary = Odds.box_odds(_box(2, {"common": 80, "rare": 18, "epic": 2}))
	assert_eq(int(o["rolls"]), 2)
	assert_eq(str(o["forced_first"]), "")
	assert_almost(float(o["p_rare_plus"]), 1.0 - 0.8 * 0.8, EPS, "1 - 0.8²  = 36 %")
	assert_almost(float(o["p_epic"]), 1.0 - 0.98 * 0.98, EPS, "1 - 0.98² = 3.96 %")


func test_silver_guarantee_forces_last_roll_to_rare_exactly() -> void:
	var o: Dictionary = Odds.box_odds(_box(3, {"common": 55, "rare": 38, "epic": 7}, "rare"))
	assert_almost(float(o["p_rare_plus"]), 1.0, EPS, "guarantee: always at least rare")
	# Epic in the first two rolls, or (no epic but already rare+) and epic in the last roll; a forced last roll is
	# exactly "rare" and never epic.
	var p_epic_first_two: float = 1.0 - 0.93 * 0.93
	var p_no_epic_but_rare_plus: float = 0.93 * 0.93 - 0.55 * 0.55
	assert_almost(float(o["p_epic"]), p_epic_first_two + p_no_epic_but_rare_plus * 0.07, EPS, "≈ 17,45 %")
	assert_almost(float(o["p_epic"]), 0.174468, 0.000001)


func test_gold_guarantee_epic() -> void:
	var o: Dictionary = Odds.box_odds(_box(4, {"common": 25, "rare": 55, "epic": 20}, "epic"))
	assert_almost(float(o["p_epic"]), 1.0, EPS)
	assert_almost(float(o["p_rare_plus"]), 1.0, EPS)


func test_pity_forces_first_roll_epic_before_rare() -> void:
	assert_eq(Odds.pity_forced(3, 7, LIMITS), "")
	assert_eq(Odds.pity_forced(4, 0, LIMITS), "rare")
	assert_eq(Odds.pity_forced(4, 8, LIMITS), "epic", "epic pity has priority")
	assert_eq(Odds.pity_forced(0, 9, LIMITS), "epic")
	var bronze: LootboxDef = _box(2, {"common": 80, "rare": 18, "epic": 2})
	var rare_pity: Dictionary = Odds.box_odds(bronze, 4, 0, LIMITS)
	assert_eq(str(rare_pity["forced_first"]), "rare")
	assert_almost(float(rare_pity["p_rare_plus"]), 1.0, EPS)
	assert_almost(float(rare_pity["p_epic"]), 0.02, EPS, "only the second roll can be epic")
	var epic_pity: Dictionary = Odds.box_odds(bronze, 0, 8, LIMITS)
	assert_eq(str(epic_pity["forced_first"]), "epic")
	assert_almost(float(epic_pity["p_epic"]), 1.0, EPS)


func test_single_roll_with_guarantee_and_pity() -> void:
	var one: LootboxDef = _box(1, {"common": 90, "rare": 10}, "rare")
	assert_almost(float(Odds.box_odds(one)["p_rare_plus"]), 1.0, EPS, "the only roll is the last roll")
	var epic_g: LootboxDef = _box(1, {"common": 100}, "epic")
	var o: Dictionary = Odds.box_odds(epic_g, 4, 0, LIMITS)
	assert_almost(float(o["p_epic"]), 0.0, EPS, "pity forces roll 1 = the last roll: rare, guarantee then unmet")


func test_entry_odds_split_per_roll_rarity_by_pool_weights() -> void:
	var data: GameData = GameData.new()
	var ok: bool = data.load_from_dicts({
		"lootboxes": [{"id": "box_probe", "name": "Probe", "tier": 1, "color": "#ffffff", "rolls": 2,
			"rarity_weights": {"common": 75, "rare": 25, "epic": 0}}],
		"lootbox_pools": {"f1": {
			"common": [{"kind": "credits", "amount": 10, "weight": 3}, {"kind": "credits", "amount": 20, "weight": 1}],
			"rare": [{"kind": "credits", "amount": 100, "weight": 1}],
			"epic": [{"kind": "credits", "amount": 500, "weight": 1}],
			"fan": [{"kind": "credits", "amount": 5, "weight": 1}]}},
		"lootbox_pity": {"rare": 4, "epic": 8}})
	assert_true(ok, "fixture loot data valid: %s" % "; ".join(data.errors))
	if not ok:
		return
	var box: LootboxDef = data.lootbox("box_probe")
	var entries: Array[Dictionary] = Odds.entry_odds(box, data, 1)
	var by_amount: Dictionary = {}
	var total: float = 0.0
	for e: Dictionary in entries:
		by_amount[int(e["amount"])] = float(e["p"])
		total += float(e["p"])
	assert_almost(float(by_amount.get(10, -1.0)), 0.75 * 0.75, EPS)
	assert_almost(float(by_amount.get(20, -1.0)), 0.75 * 0.25, EPS)
	assert_almost(float(by_amount.get(100, -1.0)), 0.25, EPS)
	assert_almost(float(by_amount.get(500, -1.0)), 0.0, EPS)
	assert_almost(total, 1.0, EPS, "per-roll probabilities sum to 1")


func test_real_boxes_show_sane_odds() -> void:
	for id: String in DB.data.ids("lootboxes"):
		var box: LootboxDef = DB.lootbox(id)
		var o: Dictionary = Odds.box_odds(box)
		var pr: Dictionary = o["per_roll"]
		assert_almost(float(pr["common"]) + float(pr["rare"]) + float(pr["epic"]), 1.0, EPS, "%s per roll" % id)
		assert_between(float(o["p_epic"]), 0.0, 1.0 + EPS, id)
		assert_true(float(o["p_rare_plus"]) + EPS >= float(o["p_epic"]), "%s: epic counts as rare+" % id)
		if box.guarantee != "":
			assert_almost(float(o["p_rare_plus"]), 1.0, EPS, "%s: guarantee" % id)
