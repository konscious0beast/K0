extends TestCase
## GiftPolicy (05 §6.10, §11.4): effect_pm table exactly, rolls_for incl. gold chest at L = 4 → 3, chest threshold
## (500 ‰ → blocked from load_half 14), caps (load_half 48, 16 gifts, 8 chests, 2 gold chests, 1 external per battle),
## league / acceptance / deadline / effect-factor checks, run counters (note_applied).

const SHOW_RULES: Dictionary = {"leagues": ["show", "pur"], "gifts": {"enabled": true,
	"sources": ["fan", "bits", "shop"], "load_cap_half": 48, "max_external": 16, "max_chests": 8, "max_gold_chests": 2,
	"max_per_battle": 1, "per_buyer_per_target": 5, "effect_k_pm": 75, "chest_min_effect_pm": 500}}


## Service gift (source shop) with a consistent effect factor for its load basis.
func _shop(kind: String, tier: String = "", load_half: int = 0, sender_ref: String = "b_1", n: int = 1) -> Dictionary:
	var g: Dictionary = Gift.make_dev(kind, tier, 100 if kind == "gold" else 0)
	g["gift_id"] = "g_shop_%d" % n
	g["source"] = "shop"
	g["sender"] = {"display_name": "", "anon": true, "sender_ref": sender_ref}
	g["load_half"] = load_half
	g["effect_pm"] = GiftPolicy.effect_pm(load_half)
	return g


func test_effect_pm_table_exact() -> void:
	var table: Array = []
	for lh: int in [0, 4, 8, 12, 16, 24, 32, 48]:
		table.append(GiftPolicy.effect_pm(lh))
	assert_eq(table, [1000, 769, 625, 526, 454, 357, 294, 217], "05 §6.10 table")
	assert_eq(GiftPolicy.effect_pm(4, 150), 625, "custom k")
	assert_eq(GiftPolicy.effect_pm(-3), 1000, "negative load → none")


func test_rolls_and_scale() -> void:
	assert_eq(GiftPolicy.rolls_for(4, GiftPolicy.effect_pm(8)), 3, "gold chest at L = 4 → (4 × 625 + 500) // 1000 = 3")
	assert_eq(GiftPolicy.rolls_for(3, GiftPolicy.effect_pm(4)), 2, "silver at L = 2 → 2")
	assert_eq(GiftPolicy.rolls_for(2, 1000), 2)
	assert_eq(GiftPolicy.rolls_for(2, 217), 1, "never below 1")
	assert_eq(GiftPolicy.rolls_for(4, 375), 2, "(4 × 375 + 500) // 1000 = 2 (1.5 → 2, half up)")
	assert_eq(GiftPolicy.scale(100, 769), 77)
	assert_eq(GiftPolicy.scale(250, 625), 156)
	assert_eq(GiftPolicy.scale(5, 769), 4, "fan_pack hype bonus")
	assert_eq(GiftPolicy.scale(35, 1000), 35)


func test_load_weights() -> void:
	var w: Dictionary = {}
	var cases: Array = [[Gift.make_dev("cheer", "", 0), 0], [Gift.make_dev("gold", "", 100), 1],
		[Gift.make_dev("gold", "", 250), 3], [Gift.make_dev("fan_pack", "", 0), 2],
		[Gift.make_dev("sponsor_buff", "spn_novanet", 0), 2], [Gift.make_dev("chest", "bronze", 0), 2],
		[Gift.make_dev("chest", "silver", 0), 4], [Gift.make_dev("chest", "gold", 0), 8],
		[Gift.make_system("spn_novanet", 1, 0), 0]]
	for c: Array in cases:
		assert_eq(GiftPolicy.load_weight_half(c[0], w), c[1], "%s %s" % [c[0]["kind"], c[0]["tier"]])
	assert_eq(GiftPolicy.load_weight_half(Gift.make_dev("chest", "gold", 0), {"gold": 10}), 10, "rules weights")


func test_chest_threshold() -> void:
	assert_true(GiftPolicy.chest_allowed(13, {}), "effect_pm(13) = 506 ≥ 500")
	assert_false(GiftPolicy.chest_allowed(14, {}), "effect_pm(14) = 487 < 500 → blocked from load_half 14")
	assert_false(GiftPolicy.chest_allowed(14, SHOW_RULES))
	assert_true(GiftPolicy.chest_allowed(14, {"gifts": {"chest_min_effect_pm": 450}}))
	var g: Dictionary = _shop("chest", "silver", 14)
	assert_eq(GiftPolicy.check({"load_half": 14}, g, SHOW_RULES), "chest_blocked")
	assert_eq(GiftPolicy.check({"load_half": 14}, _shop("gold", "", 14), SHOW_RULES), "", "non-random gifts still go")


func test_caps() -> void:
	assert_eq(GiftPolicy.check({"load_half": 47}, _shop("gold", "", 47), SHOW_RULES), "", "47 + 1 = 48 = cap")
	assert_eq(GiftPolicy.check({"load_half": 48}, _shop("gold", "", 48), SHOW_RULES), "cap_reached", "load cap 48")
	assert_eq(GiftPolicy.check({"load_half": 48}, _shop("cheer", "", 48), SHOW_RULES), "", "cheer is always possible")
	assert_eq(GiftPolicy.check({"external": 15}, _shop("gold"), SHOW_RULES), "")
	assert_eq(GiftPolicy.check({"external": 16}, _shop("gold"), SHOW_RULES), "cap_reached", "16 external gifts")
	assert_eq(GiftPolicy.check({"chests": 8}, _shop("chest", "bronze"), SHOW_RULES), "cap_reached", "8 chests")
	assert_eq(GiftPolicy.check({"chests": 7}, _shop("chest", "bronze"), SHOW_RULES), "")
	assert_eq(GiftPolicy.check({"gold_chests": 2}, _shop("chest", "gold"), SHOW_RULES), "cap_reached", "2 gold chests")
	assert_eq(GiftPolicy.check({"gold_chests": 2}, _shop("chest", "silver"), SHOW_RULES), "")
	assert_eq(GiftPolicy.check({"per_sender": {"b_1": 5}}, _shop("gold"), SHOW_RULES), "cap_reached",
		"max 5 per buyer and target")
	assert_eq(GiftPolicy.check({"per_sender": {"b_1": 5}}, _shop("gold", "", 0, "b_2"), SHOW_RULES), "")
	assert_true(GiftPolicy.can_deliver_in_battle(0, SHOW_RULES), "1 external gift per battle")
	assert_false(GiftPolicy.can_deliver_in_battle(1, SHOW_RULES), "further ones wait for the end of the battle")
	assert_false(GiftPolicy.can_deliver_in_battle(1, {}))


func test_league_and_acceptance() -> void:
	var g: Dictionary = _shop("gold")
	assert_eq(GiftPolicy.check({"league": "pur"}, g, {}), "league_pur", "run league from the run counters (RunSim)")
	assert_eq(GiftPolicy.check({}, g, {"leagues": ["pur"]}), "league_pur", "single-league event rules")
	assert_eq(GiftPolicy.check({}, g, SHOW_RULES), "", "show league open")
	assert_eq(GiftPolicy.check({}, g, {"gifts": {"enabled": false}}), "not_accepting")
	assert_eq(GiftPolicy.check({"gift_rules": {"enabled": false}}, g, {}), "not_accepting", "rules stored in the run")
	var fan: Dictionary = _shop("fan_pack")
	fan["source"] = "fan"
	assert_eq(GiftPolicy.check({}, fan, {"gifts": {"sources": ["bits", "shop"]}}), "not_accepting", "source not offered")
	assert_eq(GiftPolicy.check({}, Gift.make_dev("gold", "", 100), {"gifts": {"sources": ["shop"]}}), "",
		"dev gifts are QA tools")
	assert_eq(GiftPolicy.check({"gift_accept": "none"}, g, {}), "not_accepting")
	assert_eq(GiftPolicy.check({"gift_accept": "free_only"}, _shop("chest", "bronze"), {}), "not_accepting",
		"no paid random chests without 18+ (L6)")
	assert_eq(GiftPolicy.check({"gift_accept": "free_only"}, g, {}), "", "non-random gifts are fine")
	assert_eq(GiftPolicy.check({"league": "pur"}, Gift.make_system("spn_krawumm", 1, 0), {}), "",
		"system gifts are part of the base game in both leagues")


func test_effect_factor_and_deadline() -> void:
	var g: Dictionary = _shop("gold", "", 4)
	assert_eq(GiftPolicy.check({"load_half": 4}, g, {}), "")
	g["effect_pm"] = 1000
	assert_eq(GiftPolicy.check({"load_half": 4}, g, {}), "effect_mismatch", "effect_pm must equal effect_pm(load_half)")
	var stale: Dictionary = _shop("gold", "", 2)
	assert_eq(GiftPolicy.check({"load_half": 4}, stale, {}), "effect_mismatch", "basis below the applied load")
	var dev: Dictionary = Gift.make_dev("gold", "", 100)
	assert_eq(GiftPolicy.check({"load_half": 4}, dev, {}), "", "dev gifts carry no service reservation")
	var timed: Dictionary = _shop("gold")
	timed["deliver_by_tick"] = 100
	assert_eq(GiftPolicy.check({"tick": 100}, timed, {}), "")
	assert_eq(GiftPolicy.check({"tick": 101}, timed, {}), "deadline_missed", "client-sim deadline (S2)")


func test_note_applied_counts_once() -> void:
	var run: Dictionary = {}
	GiftPolicy.note_applied(run, _shop("chest", "gold", 0, "b_1", 1), {})
	GiftPolicy.note_applied(run, _shop("chest", "gold", 0, "b_1", 1), {})
	GiftPolicy.note_applied(run, _shop("gold", "", 8, "b_2", 2), {})
	GiftPolicy.note_applied(run, _shop("cheer", "", 9, "b_2", 3), {})
	GiftPolicy.note_applied(run, Gift.make_system("spn_krawumm", 1, 0), {})
	assert_eq(run["load_half"], 9, "gold chest 8 + 100 credits 1 (cheer 0)")
	assert_eq(run["external"], 2, "cheer does not count, the repeated id neither")
	assert_eq(run["chests"], 1)
	assert_eq(run["gold_chests"], 1)
	assert_eq(run["per_sender"], {"b_1": 1, "b_2": 1})
	assert_eq(run["counted"], ["g_shop_1", "g_shop_2", "g_shop_3"])


## Sequence: gifts arrive with the service's load basis (= load applied so far); 16 deliveries, then cap — cheers
## stay possible.
func test_sequence_until_the_external_cap() -> void:
	var run: Dictionary = {}
	for n in 20:
		var g: Dictionary = _shop("gold", "", int(run.get("load_half", 0)), "b_%d" % (n % 7), n)
		var reason: String = GiftPolicy.check(run, g, SHOW_RULES)
		if n < 16:
			assert_eq(reason, "", "gift %d" % n)
			GiftPolicy.note_applied(run, g, SHOW_RULES)
		else:
			assert_eq(reason, "cap_reached", "gift %d after 16 external gifts" % n)
	assert_eq(run["external"], 16)
	assert_eq(run["load_half"], 16, "16 × 100 credits = 16 half points")
	assert_eq(GiftPolicy.check(run, _shop("cheer", "", 16, "b_9", 99), SHOW_RULES), "", "cheer after the cap")
