extends TestCase
## M2 vending machine (02_TECH §6.1 Shop, GDD §6.5): stock per safe room, prices, sell values, buy/sell rules,
## Inventory stacking and credits, and the Game.buy → item_bought → Show (credits_spent_vendor) path.

const Fx := preload("res://tests/test_m2_fixtures.gd")

var _prev_data: GameData = null


func after_each() -> void:
	if _prev_data != null:
		Fx.end_world(_prev_data)
		_prev_data = null


func _state() -> GameState:
	return GameState.create_new(Fx.data(), 0, "Kai", 3)


func test_stock_per_safe_room() -> void:
	var d: GameData = Fx.data()
	assert_eq(Shop.stock(d.floor_def(1), "sr_kiosk"), ["itm_bandage", "itm_salts"], "layout safe room shop")
	assert_eq(Shop.stock(d.floor_def(1), "sr_unknown"), [], "unknown safe room → FloorDef.shop (empty on floor 1)")
	assert_eq(Shop.stock(d.floor_def(2), "sr_f2_0"), ["itm_bandage", "itm_ether"], "procedural floor → FloorDef.shop")
	assert_eq(Shop.stock(null, "sr_kiosk"), [])


func test_prices_and_sell_values() -> void:
	var d: GameData = Fx.data()
	assert_eq(Shop.price_of(d, "itm_bandage"), 25)
	assert_eq(Shop.price_of(d, "itm_wpn_mop"), 0, "not sold")
	assert_eq(Shop.price_of(d, "itm_nope"), 0)
	assert_eq(Shop.sell_value(d, "itm_bandage"), 12, "sell −1 → floori(price / 2)")
	assert_eq(Shop.sell_value(d, "itm_wpn_mop"), 10, "explicit sell value")
	assert_eq(Shop.sell_value(d, "itm_key_master"), 0, "key items are not sellable")
	assert_eq(Shop.sell_value(d, "itm_nope"), 0)


func test_buy() -> void:
	var d: GameData = Fx.data()
	var st: GameState = _state()
	assert_true(Shop.buy(st, d, "itm_bandage", 2))
	assert_eq([st.inventory.count("itm_bandage"), st.inventory.credits], [5, 0], "2 × 25 from 50")
	assert_false(Shop.buy(st, d, "itm_bandage", 1), "not enough credits")
	assert_eq([st.inventory.count("itm_bandage"), st.inventory.credits], [5, 0], "unchanged")
	st.inventory.credits = 1000
	assert_false(Shop.buy(st, d, "itm_bandage", 0), "qty 1..9")
	assert_false(Shop.buy(st, d, "itm_bandage", 10), "qty 1..9")
	assert_false(Shop.buy(st, d, "itm_bandage", 5), "5 + 5 > max_stack 9")
	assert_true(Shop.buy(st, d, "itm_bandage", 4))
	assert_eq([st.inventory.count("itm_bandage"), st.inventory.credits], [9, 900])
	assert_false(Shop.buy(st, d, "itm_stack3", 4), "item max_stack 3")
	assert_true(Shop.buy(st, d, "itm_stack3", 3))
	assert_false(Shop.buy(st, d, "itm_wpn_mop", 1), "price 0: not sold")
	assert_false(Shop.buy(st, d, "itm_nope", 1))
	assert_false(Shop.buy(null, d, "itm_bandage", 1))


func test_sell() -> void:
	var d: GameData = Fx.data()
	var st: GameState = _state()
	assert_true(Shop.sell(st, d, "itm_bandage", 2))
	assert_eq([st.inventory.count("itm_bandage"), st.inventory.credits], [1, 74], "2 × 12")
	assert_false(Shop.sell(st, d, "itm_bandage", 2), "more than owned")
	assert_true(Shop.sell(st, d, "itm_bandage", 1))
	assert_false(st.inventory.counts.has("itm_bandage"), "zero counts are removed")
	st.inventory.add("itm_key_master")
	assert_false(Shop.sell(st, d, "itm_key_master", 1), "sell value 0")
	assert_false(Shop.sell(st, d, "itm_antidote", 0))
	st.inventory.add("itm_wpn_mop")
	assert_true(Shop.sell(st, d, "itm_wpn_mop", 1), "unequipped equipment can be sold")


func test_inventory_basics() -> void:
	var d: GameData = Fx.data()
	var inv: Inventory = Inventory.new()
	assert_eq(inv.add("itm_bandage", 5), 5)
	assert_eq(inv.add("itm_bandage", 7), 4, "capped at max_stack 9")
	assert_eq(inv.add("itm_bandage", 0), 0)
	assert_eq(inv.add("", 1), 0)
	assert_true(inv.has("itm_bandage", 9))
	assert_false(inv.has("itm_bandage", 10))
	assert_false(inv.remove("itm_bandage", 10))
	assert_true(inv.remove("itm_bandage", 9))
	assert_eq(inv.count("itm_bandage"), 0)
	inv.add("itm_salts")
	inv.add("itm_molotov", 2)
	inv.add("itm_wpn_axe")
	inv.add("itm_ether")
	assert_eq(inv.ids_of_type(d, "weapon"), ["itm_wpn_axe"])
	assert_eq(inv.ids_of_type(d, "consumable"), ["itm_ether", "itm_molotov", "itm_salts"], "sorted")
	assert_eq(inv.ids_with_tag(d, "revive"), ["itm_salts"])
	assert_eq(inv.battle_items(d), {"itm_molotov": 2, "itm_salts": 1}, "field-only and equipment excluded")
	inv.add_credits(30)
	assert_false(inv.spend_credits(31))
	assert_true(inv.spend_credits(30))
	inv.add_credits(-5)
	assert_eq(inv.credits, 0, "never negative")
	var back: Inventory = Inventory.from_dict(JSON.parse_string(JSON.stringify(inv.to_dict())))
	assert_eq(back.to_dict(), inv.to_dict())
	assert_eq(Inventory.from_dict({"credits": 3, "counts": {"itm_a": 0, "itm_b": 2.0}}).counts, {"itm_b": 2})


func test_game_buy_feeds_show_vendor_stat() -> void:
	_prev_data = Fx.begin_world()
	Game.state.inventory.credits = 200
	var bought: Array = []
	var cb: Callable = func(p: Dictionary) -> void: bought.append(p)
	Events.item_bought.connect(cb)
	assert_true(Game.buy("itm_salts", 2, "sr_kiosk"))
	Events.item_bought.disconnect(cb)
	assert_eq(bought, [{"item_id": "itm_salts", "qty": 2, "cost": 120, "safe_room_id": "sr_kiosk"}])
	assert_eq(Game.state.show.stats["credits_spent_vendor"], 120)
	assert_true(Show.is_unlocked("ach_vendor_100"))
	assert_true(Game.sell("itm_salts", 1))
	assert_eq(Game.state.inventory.credits, 80 + 30)
