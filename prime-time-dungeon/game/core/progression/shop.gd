# STUB(M0) — owned by M2. Replace completely, keep the public API.
class_name Shop extends RefCounted
## Vending machine: buy / sell (02_TECH §6.1).


## Layout safe room shop, else def.shop.
static func stock(def: FloorDef, safe_room_id: String) -> PackedStringArray:
	return PackedStringArray()


static func price_of(data: GameData, item_id: String) -> int:
	return 0


## ItemDef.sell (−1 → floori(price / 2)).
static func sell_value(data: GameData, item_id: String) -> int:
	return 0


## qty 1..9, respects max_stack.
static func buy(state: GameState, data: GameData, item_id: String, qty: int) -> bool:
	return false


## sell_value each; sell 0 → false.
static func sell(state: GameState, data: GameData, item_id: String, qty: int) -> bool:
	return false
