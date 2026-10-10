class_name Inventory extends RefCounted
## Items + credits (02_TECH §6.1). Equipped items are not counted (they live in PartyMember.equipment).
## Stacks are capped by ItemDef.max_stack (callers pass it); counts never contain zero entries.

var counts: Dictionary = {}            # item id → int > 0 (equipped items are NOT counted)
var credits: int = 0


## Returns how many were actually added (cap max_stack).
func add(item_id: String, n: int = 1, max_stack: int = 9) -> int:
	if item_id == "" or n <= 0:
		return 0
	var have: int = count(item_id)
	var added: int = clampi(max_stack - have, 0, n)
	if added > 0:
		counts[item_id] = have + added
	return added


## THE overflow rule (chests, lootboxes, floor events, battle items, gifts, milestones): n of `item_id` up to
## ItemDef.max_stack, the rest becomes credits at Shop.sell_value each. Unknown item → nothing. Returns the stored
## count.
func add_item_or_credits(data: GameData, item_id: String, n: int) -> int:
	if data == null or n <= 0 or not data.has_id("items", item_id):
		return 0
	var added: int = add(item_id, n, data.item(item_id).max_stack)
	if added < n:
		add_credits((n - added) * Shop.sell_value(data, item_id))
	return added


## LootRewards → inventory: "credits" → add_credits, "item" → add_item_or_credits.
func add_rewards(data: GameData, rewards: Array[LootReward]) -> void:
	for r: LootReward in rewards:
		if r == null:
			continue
		if r.kind == "credits":
			add_credits(r.amount)
		elif r.kind == "item":
			add_item_or_credits(data, r.id, r.amount)


func remove(item_id: String, n: int = 1) -> bool:
	if n <= 0 or not has(item_id, n):
		return false
	var left: int = count(item_id) - n
	if left > 0:
		counts[item_id] = left
	else:
		counts.erase(item_id)
	return true


func count(item_id: String) -> int:
	return int(counts.get(item_id, 0))


func has(item_id: String, n: int = 1) -> bool:
	return n > 0 and count(item_id) >= n


## Sorted ids of owned items of an ItemDef.type ("consumable", "weapon", …).
func ids_of_type(data: GameData, type: String) -> PackedStringArray:
	var out: PackedStringArray = []
	for item_id: String in _owned_ids():
		if data != null and data.has_id("items", item_id) and data.item(item_id).type == type:
			out.append(item_id)
	return out


## Sorted ids of owned items with an ItemDef tag, e.g. "heal" for fev_lost_candidate.
func ids_with_tag(data: GameData, tag: String) -> PackedStringArray:
	var out: PackedStringArray = []
	for item_id: String in _owned_ids():
		if data != null and data.has_id("items", item_id) and data.item(item_id).tags.has(tag):
			out.append(item_id)
	return out


## {item_id: count} of consumables usable in battle ("battle"/"both") with count > 0 (BattleSetup.items).
func battle_items(data: GameData) -> Dictionary:
	var out: Dictionary = {}
	for item_id: String in _owned_ids():
		if data == null or not data.has_id("items", item_id):
			continue
		var def: ItemDef = data.item(item_id)
		if def.type == "consumable" and (def.usable == "battle" or def.usable == "both"):
			out[item_id] = count(item_id)
	return out


## Negative amounts are allowed; credits never drop below 0.
func add_credits(n: int) -> void:
	credits = maxi(0, credits + n)


func spend_credits(n: int) -> bool:
	if n < 0 or credits < n:
		return false
	credits -= n
	return true


func to_dict() -> Dictionary:
	var c: Dictionary = {}
	for item_id: String in _owned_ids():
		c[item_id] = count(item_id)
	return {"credits": credits, "counts": c}


## Missing fields → defaults; counts ≤ 0 are dropped; numbers converted with int().
static func from_dict(d: Dictionary) -> Inventory:
	var inv: Inventory = Inventory.new()
	inv.credits = maxi(0, JsonUtil.to_int(d.get("credits", 0)))
	var raw: Variant = d.get("counts", {})
	if raw is Dictionary:
		var keys: Array = (raw as Dictionary).keys()
		keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
		for k: Variant in keys:
			var n: int = JsonUtil.to_int((raw as Dictionary)[k])
			if n > 0 and str(k) != "":
				inv.counts[str(k)] = n
	return inv


func _owned_ids() -> PackedStringArray:
	var out: PackedStringArray = []
	for k: Variant in counts.keys():
		if int(counts[k]) > 0:
			out.append(str(k))
	out.sort()
	return out
