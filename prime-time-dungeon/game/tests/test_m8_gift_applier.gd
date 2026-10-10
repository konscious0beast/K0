extends TestCase
## GiftApplier (05 §6.9/§6.10, §11.4) outside battles, against the real data (no autoloads): bronze dev chest adds items
## and counts them in flags["live"]["gift_items"]; gold × effect factor; equipment duplicates → credits; server
## contents; fan pack; sponsor buffs scaled by effect_pm; run counters.


func _state(seed: int = 7) -> GameState:
	var st: GameState = GameState.create_new(real_data(), 0, "Kai", seed, &"prime")
	st.floor_run = FloorRun.create(real_data().floor_def(1), seed, &"prime")
	return st


func _rng(seed: int) -> RandomNumberGenerator:
	return SeedUtil.make_rng(seed)


func _item_total(rewards: Array[LootReward]) -> Dictionary:
	var out: Dictionary = {}
	for r: LootReward in rewards:
		if r.kind == "item":
			out[r.id] = int(out.get(r.id, 0)) + r.amount
	return out


func test_bronze_dev_chest_adds_and_counts_items() -> void:
	var data: GameData = real_data()
	var st: GameState = _state()
	var inv_before: Dictionary = st.inventory.to_dict()
	var g: Dictionary = Gift.make_dev("chest", "bronze", 0)
	var rewards: Array[LootReward] = GiftApplier.apply(st, data, g, _rng(11))
	assert_eq(rewards.size(), data.lootbox("box_bronze").rolls, "one reward per roll (box_bronze rolls)")
	assert_eq(st.inventory.to_dict(), inv_before, "rewards are returned; the caller adds them (Show → Game.add_rewards)")
	var live: Dictionary = st.flags.get("live", {})
	assert_eq(live.get("gift_items", {}), _item_total(rewards), "L3: gift contents counted in flags.live.gift_items")
	assert_eq(live.get("load_half", 0), 2, "bronze chest = 2 half points")
	assert_eq(live.get("chests", 0), 1)
	assert_eq(live.get("external", 0), 1)
	var again: Array[LootReward] = GiftApplier.apply(_state(), data, g, _rng(11))
	var a: Array = []
	var b: Array = []
	for r: LootReward in rewards:
		a.append(r.to_dict())
	for r: LootReward in again:
		b.append(r.to_dict())
	assert_eq(b, a, "same rng seed → same contents")
	for r: LootReward in rewards:
		assert_has(["common", "rare", "epic"], r.rarity)


func test_gold_scaled_by_effect_factor() -> void:
	var g: Dictionary = Gift.make_dev("gold", "", 250)
	g["load_half"] = 8
	g["effect_pm"] = GiftPolicy.effect_pm(8)
	var rewards: Array[LootReward] = GiftApplier.apply(_state(), real_data(), g, _rng(1))
	assert_eq(rewards.size(), 1)
	assert_eq([rewards[0].kind, rewards[0].amount], ["credits", 156], "(250 × 625 + 500) // 1000")
	var full: Array[LootReward] = GiftApplier.apply(_state(), real_data(), Gift.make_dev("gold", "", 100), _rng(1))
	assert_eq(full[0].amount, 100)


func test_server_contents_and_equipment_duplicates() -> void:
	var data: GameData = real_data()
	var st: GameState = _state()
	var owned: String = str(st.party[0].equipment["weapon"])
	assert_ne(owned, "", "Kai starts with a weapon")
	var fresh: String = ""
	for it: ItemDef in data.all_items():
		if it.is_equipment() and it.sell_value() > 0 and it.id != owned and st.inventory.count(it.id) == 0:
			var equipped: bool = false
			for m: PartyMember in st.party:
				equipped = equipped or m.equipment.values().has(it.id)
			if not equipped:
				fresh = it.id
				break
	var g: Dictionary = Gift.make_dev("chest", "gold", 0)
	g["contents"] = [{"rarity": "epic", "item_id": owned, "qty": 1}, {"rarity": "rare", "item_id": fresh, "qty": 2},
		{"rarity": "common", "credits": 40}, {"rarity": "common", "item_id": "itm_bandage", "qty": 2}]
	var rng: RandomNumberGenerator = _rng(5)
	var state_before: int = rng.state
	var rewards: Array[LootReward] = GiftApplier.apply(st, data, g, rng)
	assert_eq(rng.state, state_before, "server contents: no local draws")
	var dup_value: int = data.item(owned).duplicate_credits()
	var fresh_value: int = data.item(fresh).duplicate_credits()
	assert_eq(dup_value, roundi(data.item(owned).sell_value() * 0.5), "GDD §9.3: half the sell value")
	var got: Array = []
	for r: LootReward in rewards:
		got.append([r.kind, r.id, r.amount, r.converted_from])
	assert_eq(got, [["credits", "", dup_value, owned], ["item", fresh, 1, ""], ["credits", "", fresh_value, fresh],
		["credits", "", 40, ""], ["item", "itm_bandage", 2, ""]],
		"owned weapon → credits; a stack of a new piece keeps one, the second becomes credits (GDD §9.3)")
	assert_eq(st.flags["live"]["gift_items"], {fresh: 1, "itm_bandage": 2}, "converted pieces are not items")


func test_fan_pack_rolls_one_common_entry() -> void:
	var data: GameData = real_data()
	var rewards: Array[LootReward] = GiftApplier.apply(_state(), data, Gift.make_dev("fan_pack", "", 0), _rng(3))
	assert_eq(rewards.size(), 1)
	assert_eq(rewards[0].rarity, "common")
	var ids: Array = []
	for e: Dictionary in data.loot_pool(1, "common"):
		ids.append(str(e["id"]) if str(e["kind"]) == "item" else "")
	assert_has(ids, rewards[0].id, "entry of the floor's common pool")


func test_silver_chest_guarantee_and_scaled_rolls() -> void:
	var data: GameData = real_data()
	for seed: int in 40:
		var rewards: Array[LootReward] = GiftApplier.apply(_state(), data, Gift.make_dev("chest", "silver", 0),
			_rng(seed))
		assert_eq(rewards.size(), 3, "silver: 3 rolls at 100 %")
		var best: String = LootRoller.best_rarity(rewards)
		assert_true(best == "rare" or best == "epic", "seed %d: guarantee rare (05 §7.4), got %s" % [seed, best])
	var gold: Dictionary = Gift.make_dev("chest", "gold", 0)
	gold["load_half"] = 8
	gold["effect_pm"] = 625
	var r2: Array[LootReward] = GiftApplier.apply(_state(), data, gold, _rng(9))
	assert_eq(r2.size(), 3, "gold chest at L = 4: 3 rolls")
	assert_eq(LootRoller.best_rarity(r2), "epic", "epic guarantee on the last roll")


func test_sponsor_buffs_scaled() -> void:
	var data: GameData = real_data()
	var st: GameState = _state()
	var kai: PartyMember = st.party[0]
	var max_hp: int = Progression.total_stats(kai, data).values[StatBlock.Stat.HP]
	kai.hp = 1
	var g: Dictionary = Gift.make_dev("sponsor_buff", "spn_gluckwasser", 0)
	assert_eq(GiftApplier.apply(st, data, g, _rng(1)).size(), 0, "heals are no rewards")
	assert_eq(kai.hp, mini(max_hp, 1 + (max_hp * 25 + 50) / 100), "+25 % max HP")
	kai.hp = 1
	g["load_half"] = 16
	g["effect_pm"] = 454
	GiftApplier.apply(st, data, g, _rng(1))
	assert_eq(kai.hp, 1 + (max_hp * (25 * 454 / 1000) + 50) / 100, "value × effect_pm / 1000 = 11 %")
	var st2: GameState = _state()
	st2.party[0].hp = 1
	var rewards: Array[LootReward] = GiftApplier.apply(st2, data, Gift.make_dev("sponsor_buff", "spn_brutzel", 0),
		_rng(1))
	assert_eq(rewards.size(), 1)
	assert_eq([rewards[0].kind, rewards[0].id, rewards[0].amount], ["item", "itm_brutzel_burger", 1])
	assert_eq(st2.party[0].hp, 21, "+20 flat")
	var st3: GameState = _state()
	st3.party[1].hp = 0
	GiftApplier.apply(st3, data, Gift.make_dev("sponsor_buff", "spn_sorgenfrei", 0), _rng(1))
	var mop_max: int = Progression.total_stats(st3.party[1], data).values[StatBlock.Stat.HP]
	assert_eq(st3.party[1].hp, (mop_max * 40 + 50) / 100, "KO'd member revived with 40 %")
	var st4: GameState = _state()
	st4.party[0].mp = 0
	GiftApplier.apply(st4, data, Gift.make_dev("sponsor_buff", "spn_novanet", 0), _rng(1))
	var kai_mp: int = Progression.total_stats(st4.party[0], data).values[StatBlock.Stat.MP]
	assert_eq(st4.party[0].mp, (kai_mp * 40 + 50) / 100, "+40 % MP")


func test_system_and_cheer_gifts() -> void:
	var st: GameState = _state()
	st.party[0].hp = 1
	GiftApplier.apply(st, real_data(), Gift.make_system("spn_gluckwasser", 1, 0), _rng(1))
	assert_gt(st.party[0].hp, 1, "system sponsor gift applies its effect")
	assert_false(st.flags.has("live"), "system gifts are not external: no run counters")
	var st2: GameState = _state()
	assert_eq(GiftApplier.apply(st2, real_data(), Gift.make_dev("cheer", "", 0), _rng(1)).size(), 0, "cosmetic")
	assert_eq((st2.flags["live"] as Dictionary).get("external", 0), 0, "cheer is not counted as external gift")
	assert_eq((st2.flags["live"] as Dictionary).get("load_half", -1), 0, "booked (weight 0), no interval for cheer")
	assert_false((st2.flags["live"] as Dictionary).has("last_delivery_tick"))
	assert_eq(GiftApplier.apply(null, real_data(), Gift.make_dev("gold", "", 100), _rng(1)).size(), 0, "no state")


## 05 §3.3 Nr. 5 / GDD §9.3: THE duplicate rule (ItemDef.duplicate_credits, lootboxes, chests and gifts in and out of
## battle) in integers: sell value × 0.5, half up — the same values as roundi(sell × 0.5).
func test_duplicate_credit_factor_in_integers() -> void:
	assert_eq(ItemDef.DUPLICATE_CREDIT_PM, 500)
	for sell in 12:
		var def: ItemDef = ItemDef.from_dict({"id": "itm_x", "type": "weapon", "sell": sell})
		assert_eq(def.duplicate_credits(), roundi(sell * 0.5), "sell %d" % sell)


## In-battle gifts (BattleState.apply_gift) are booked like GiftApplier.apply books them outside battles: ITEM_GAINED
## items → flags.live.gift_items (05 §6.9), load/caps → run counters. System gifts book nothing.
func test_note_battle_gift_books_items_and_load() -> void:
	var st: GameState = _state()
	var item: ActionEvent = ActionEvent.make(ActionEvent.Type.ITEM_GAINED)
	item.item_id = "itm_bandage"
	item.value = 2
	var credits: ActionEvent = ActionEvent.make(ActionEvent.Type.CREDITS_GAINED)
	credits.value = 40
	var events: Array[ActionEvent] = [item, credits, item]
	GiftApplier.note_battle_gift(st, Gift.make_dev("chest", "bronze", 0), events)
	var live: Dictionary = st.flags["live"]
	assert_eq(live["gift_items"], {"itm_bandage": 4})
	assert_eq([live["load_half"], live["chests"], live["external"]], [2, 1, 1])
	var sys_state: GameState = _state()
	GiftApplier.note_battle_gift(sys_state, Gift.make_system("spn_gluckwasser", 1, 0), events)
	assert_false(sys_state.flags.has("live"), "system gifts are no external gift statistics")


## live-integrity-15 (05 §6.9: "Statistiken dürfen nicht davon abhängen, ob das Geschenk im Kampf ankam"): one chest
## with
## the same contents leaves the same inventory, credits and gift_items whether it arrives outside a battle
## (GiftApplier.apply + add_rewards) or in one (BattleState.apply_gift → note_battle_gift → BattleBridge.apply_result) —
## an owned weapon and the second piece of a new one become credits in both places.
func test_chest_in_and_out_of_battle_gives_the_same_result() -> void:
	var data: GameData = real_data()
	var outside: GameState = _state()
	var inside: GameState = _state()
	var owned: String = str(outside.party[0].equipment["weapon"])
	var fresh: String = ""
	for it: ItemDef in data.all_items():
		if it.is_equipment() and it.sell_value() > 0 and not LootRoller.owned_equipment(outside).has(it.id):
			fresh = it.id
			break
	assert_ne(fresh, "")
	var g: Dictionary = Gift.make_dev("chest", "silver", 0)
	g["contents"] = [{"rarity": "epic", "item_id": owned, "qty": 1}, {"rarity": "rare", "item_id": fresh, "qty": 2},
		{"rarity": "common", "credits": 40}, {"rarity": "common", "item_id": "itm_bandage", "qty": 2}]
	outside.inventory.add_rewards(data, GiftApplier.apply(outside, data, g.duplicate(true), _rng(3)))
	var setup: BattleSetup = BattleBridge.make_setup(inside, data, "enc_f1_b4", 0, "", 5)
	assert_has(setup.owned_equipment, owned, "the setup knows the owned equipment")
	var battle: BattleState = BattleState.new(setup, data)
	battle.start()
	var events: Array[ActionEvent] = battle.apply_gift(g.duplicate(true))
	GiftApplier.note_battle_gift(inside, g, events)
	var r: BattleResult = BattleResult.new()
	r.outcome = BattleResult.Outcome.FLED
	r.item_delta = (battle.tally["item_delta"] as Dictionary).duplicate()
	r.credits_delta = int(battle.tally["credits_delta"])
	BattleBridge.apply_result(inside, data, r)
	assert_eq(inside.inventory.to_dict(), outside.inventory.to_dict(), "same items and credits")
	assert_eq(inside.flags["live"]["gift_items"], outside.flags["live"]["gift_items"], "same gift_items statistics")
	assert_eq(outside.flags["live"]["gift_items"], {fresh: 1, "itm_bandage": 2})
