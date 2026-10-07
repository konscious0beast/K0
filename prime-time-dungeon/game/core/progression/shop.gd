class_name Shop extends RefCounted
## Vending machine: buy / sell (02_TECH §6.1, GDD §6.5).

const MAX_QTY: int = 9


## Layout safe room shop, else def.shop.
static func stock(def: FloorDef, safe_room_id: String) -> PackedStringArray:
	if def == null:
		return PackedStringArray()
	var rooms: Variant = def.layout.get("safe_rooms", [])
	if safe_room_id != "" and rooms is Array:
		for r: Variant in rooms:
			if r is Dictionary and str((r as Dictionary).get("id", "")) == safe_room_id:
				return JsonUtil.to_str_array((r as Dictionary).get("shop", []))
	return def.shop.duplicate()


## Automat price (0 = not sold / unknown item).
static func price_of(data: GameData, item_id: String) -> int:
	if data == null or not data.has_id("items", item_id):
		return 0
	return maxi(0, data.item(item_id).price)


## ItemDef.sell (−1 → floori(price / 2)); 0 = not sellable / unknown item.
static func sell_value(data: GameData, item_id: String) -> int:
	if data == null or not data.has_id("items", item_id):
		return 0
	return maxi(0, data.item(item_id).sell_value())


## qty 1..9, respects max_stack (the whole quantity must fit), credits >= price × qty. false = nothing changed.
static func buy(state: GameState, data: GameData, item_id: String, qty: int) -> bool:
	if state == null or state.inventory == null or qty < 1 or qty > MAX_QTY:
		return false
	var price: int = price_of(data, item_id)
	if price <= 0:
		return false
	var def: ItemDef = data.item(item_id)
	if state.inventory.count(item_id) + qty > def.max_stack:
		return false
	var cost: int = price * qty
	if not state.inventory.spend_credits(cost):
		return false
	state.inventory.add(item_id, qty, def.max_stack)
	return true


## sell_value each; sell 0 → false; qty 1..count. false = nothing changed.
static func sell(state: GameState, data: GameData, item_id: String, qty: int) -> bool:
	if state == null or state.inventory == null or qty < 1:
		return false
	var value: int = sell_value(data, item_id)
	if value <= 0 or not state.inventory.remove(item_id, qty):
		return false
	state.inventory.add_credits(value * qty)
	return true
