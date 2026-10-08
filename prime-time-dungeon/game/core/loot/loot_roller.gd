class_name LootRoller extends RefCounted
## Lootbox / chest / drop rolls, deterministic per rng (02_TECH §6.1, GDD §2.5/§9).
##
## Integer randomness only (`randi_range`, 05 §3.3 Nr. 5). RNG consumption order is part of the contract (replays):
## lootbox: [fan entry] then per roll [rarity draw unless forced by pity/guarantee] + entry draw; wood chest:
## credits draw + common entry draw; chest table: entry + amount, 20 % draw, [entry + amount]; drops: one draw per
## drop entry.

const RARITY_ORDER: PackedStringArray = ["common", "rare", "epic"]
const WOOD_CREDITS_MIN: int = 20
const WOOD_CREDITS_MAX: int = 40
const DUPLICATE_CREDIT_MULT: float = 1.5      # duplicate equipment → roundi(sell value × 1.5) credits
const EXTRA_CHEST_ROLL_PCT: int = 20          # procedural chests: second roll chance
const _PPM: int = 1_000_000


## GDD §9: [fan entry (display rarity epic)] + `rolls` rolls; roll 0 forced epic/rare by pity (epic first), last roll
## forced to the box guarantee if still unmet, else rarity by `rarity_weights`; entry by weight from
## loot_pool(floor_index, rarity) (empty pool → next lower rarity). Equipment already owned (inventory, equipped,
## earlier in this box) becomes credits. Updates state.pity_rare / pity_epic (rolled rarities only).
static func roll_lootbox(box: LootboxDef, data: GameData, floor_index: int, state: GameState,
		rng: RandomNumberGenerator) -> Array[LootReward]:
	var out: Array[LootReward] = []
	if box == null or data == null or rng == null:
		return out
	var owned: Dictionary = _owned_equipment(state)
	if box.fixed_pool != "":
		var fan: Dictionary = _pick_entry(data.loot_pool(floor_index, box.fixed_pool), rng)
		if not fan.is_empty():
			out.append(_entry_reward(fan, "epic", data, owned))
	var limits: Dictionary = data.pity_limits()
	var pity_rare_at: int = int(limits.get("rare", 4))
	var pity_epic_at: int = int(limits.get("epic", 8))
	var p_rare: int = state.pity_rare if state != null else 0
	var p_epic: int = state.pity_epic if state != null else 0
	var got_rare: bool = false
	var got_epic: bool = false
	var rolls: int = maxi(1, box.rolls)
	for i in rolls:
		var rarity: String = ""
		var forced: bool = false
		if i == 0 and p_epic >= pity_epic_at:
			rarity = "epic"
			forced = true
		elif i == 0 and p_rare >= pity_rare_at:
			rarity = "rare"
			forced = true
		elif i == rolls - 1 and _guarantee_unmet(box.guarantee, got_rare, got_epic):
			rarity = box.guarantee
		else:
			rarity = _roll_rarity(box.rarity_weights, rng)
		var picked: Dictionary = _pick_with_fallback(data, floor_index, rarity, rng)
		if picked.is_empty():
			continue
		var used: String = str(picked["rarity"])
		if used == "epic":
			got_epic = true
			got_rare = true
		elif used == "rare":
			got_rare = true
		var r: LootReward = _entry_reward(picked["entry"], used, data, owned)
		r.pity = forced and used == rarity
		out.append(r)
	if state != null:
		state.pity_rare = 0 if got_rare else state.pity_rare + 1
		state.pity_epic = 0 if got_epic else state.pity_epic + 1
	return out


## Layout chest: non-empty `contents` are given as they are (metal/locked chests, and procedural wood chests whose
## contents DungeonGenerator rolled from FloorDef.chest_table, 02_TECH §7.2 step 9 — M3 CR 1); a wood chest without
## contents → 20..40 credits + 1 entry from pools.f<i>.common (handbuilt floors).
static func roll_chest(chest: Dictionary, data: GameData, floor_index: int, state: GameState,
		rng: RandomNumberGenerator) -> Array[LootReward]:
	var out: Array[LootReward] = []
	if chest.is_empty():
		return out
	var type: String = str(chest.get("type", "wood"))
	var given: Variant = chest.get("contents", [])
	if type == "wood" and not (given is Array and not (given as Array).is_empty()):
		if rng == null:
			return out
		out.append(_reward("credits", "", rng.randi_range(WOOD_CREDITS_MIN, WOOD_CREDITS_MAX), "common"))
		if data != null:
			var e: Dictionary = _pick_entry(data.loot_pool(floor_index, "common"), rng)
			if not e.is_empty():
				out.append(_entry_reward(e, "common", data, {}))
		return out
	var contents: Variant = chest.get("contents", [])
	if contents is Array:
		for c: Variant in contents:
			if not (c is Dictionary):
				continue
			var cd: Dictionary = c
			var kind: String = str(cd.get("kind", "item"))
			var amount: int = maxi(1, JsonUtil.to_int(cd.get("amount", 1), 1))
			if kind == "credits":
				out.append(_reward("credits", "", amount, "common"))
			elif kind == "item":
				var item_id: String = str(cd.get("id", ""))
				out.append(_reward("item", item_id, amount, _item_rarity(data, item_id)))
	return out


## Procedural floors: 1 roll (+1 at 20 %).
static func roll_chest_table(def: FloorDef, rng: RandomNumberGenerator) -> Array[LootReward]:
	var out: Array[LootReward] = []
	if def == null or rng == null or def.chest_table.is_empty():
		return out
	var first: LootReward = _roll_table_entry(def.chest_table, rng)
	if first != null:
		out.append(first)
	if rng.randi_range(1, 100) <= EXTRA_CHEST_ROLL_PCT:
		var second: LootReward = _roll_table_entry(def.chest_table, rng)
		if second != null:
			out.append(second)
	return out


## Each drop {item, chance} hits with chance × (1 + avg_party_lck / 100) (GDD §3.12), one integer draw per entry.
static func roll_drops(drops: Array[Dictionary], avg_party_lck: float, rng: RandomNumberGenerator) -> PackedStringArray:
	var out: PackedStringArray = []
	if rng == null:
		return out
	for d: Dictionary in drops:
		var chance: float = float(d.get("chance", 0.0)) * (1.0 + avg_party_lck / Balance.DROP_LCK_DIV)
		var threshold: int = roundi(clampf(chance, 0.0, 1.0) * _PPM)
		var draw: int = rng.randi_range(0, _PPM - 1)
		if draw < threshold:
			out.append(str(d.get("item", "")))
	return out


static func best_rarity(rewards: Array[LootReward]) -> String:
	var best: int = 0
	for r: LootReward in rewards:
		if r == null:
			continue
		best = maxi(best, RARITY_ORDER.find(r.rarity))
	return RARITY_ORDER[best]


# --- helpers ----------------------------------------------------------------------------------------------------------

static func _reward(kind: String, item_id: String, amount: int, rarity: String) -> LootReward:
	var r: LootReward = LootReward.new()
	r.kind = kind
	r.id = item_id
	r.amount = amount
	r.rarity = rarity
	return r


## Pool entry {kind, id, amount, weight} → reward; owned equipment (dict, updated) becomes credits.
static func _entry_reward(e: Dictionary, rarity: String, data: GameData, owned: Dictionary) -> LootReward:
	var kind: String = str(e.get("kind", "item"))
	var amount: int = maxi(1, JsonUtil.to_int(e.get("amount", 1), 1))
	if kind == "credits":
		return _reward("credits", "", amount, rarity)
	var item_id: String = str(e.get("id", ""))
	if data != null and data.has_id("items", item_id):
		var def: ItemDef = data.item(item_id)
		if def.is_equipment():
			if owned.has(item_id):
				var r: LootReward = _reward("credits", "", roundi(def.sell_value() * DUPLICATE_CREDIT_MULT), rarity)
				r.converted_from = item_id
				return r
			owned[item_id] = true
	return _reward("item", item_id, amount, rarity)


## Item ids of equipment in the inventory or equipped by any party member.
static func _owned_equipment(state: GameState) -> Dictionary:
	var owned: Dictionary = {}
	if state == null:
		return owned
	if state.inventory != null:
		for item_id: Variant in state.inventory.counts.keys():
			if int(state.inventory.counts[item_id]) > 0:
				owned[str(item_id)] = true
	for m: PartyMember in state.party:
		if m == null:
			continue
		for slot: Variant in m.equipment.keys():
			var eq: String = str(m.equipment[slot])
			if eq != "":
				owned[eq] = true
	return owned


static func _guarantee_unmet(guarantee: String, got_rare: bool, got_epic: bool) -> bool:
	match guarantee:
		"rare":
			return not got_rare
		"epic":
			return not got_epic
	return false


static func _roll_rarity(weights: Dictionary, rng: RandomNumberGenerator) -> String:
	var total: int = 0
	for r: String in RARITY_ORDER:
		total += maxi(0, int(weights.get(r, 0)))
	if total <= 0:
		return "common"
	var x: int = rng.randi_range(0, total - 1)
	for r: String in RARITY_ORDER:
		x -= maxi(0, int(weights.get(r, 0)))
		if x < 0:
			return r
	return "common"


## {"entry": Dictionary, "rarity": String} from the rarity's pool, falling back to lower rarities; {} if all empty.
static func _pick_with_fallback(data: GameData, floor_index: int, rarity: String,
		rng: RandomNumberGenerator) -> Dictionary:
	var idx: int = maxi(0, RARITY_ORDER.find(rarity))
	while idx >= 0:
		var r: String = RARITY_ORDER[idx]
		var e: Dictionary = _pick_entry(data.loot_pool(floor_index, r), rng)
		if not e.is_empty():
			return {"entry": e, "rarity": r}
		idx -= 1
	return {}


## Weighted pick (integer weights ≥ 1) of one entry; {} if the pool is empty. Consumes one draw if not empty.
static func _pick_entry(pool: Array[Dictionary], rng: RandomNumberGenerator) -> Dictionary:
	var total: int = 0
	for e: Dictionary in pool:
		total += maxi(0, JsonUtil.to_int(e.get("weight", 1), 1))
	if total <= 0:
		return {}
	var x: int = rng.randi_range(0, total - 1)
	for e: Dictionary in pool:
		x -= maxi(0, JsonUtil.to_int(e.get("weight", 1), 1))
		if x < 0:
			return e
	return pool[pool.size() - 1]


static func _roll_table_entry(table: Array[Dictionary], rng: RandomNumberGenerator) -> LootReward:
	var e: Dictionary = _pick_entry(table, rng)
	if e.is_empty():
		return null
	var lo: int = JsonUtil.to_int(e.get("min", 1), 1)
	var hi: int = maxi(lo, JsonUtil.to_int(e.get("max", lo), lo))
	var amount: int = maxi(1, rng.randi_range(lo, hi))
	var kind: String = str(e.get("kind", "item"))
	if kind == "credits":
		return _reward("credits", "", amount, "common")
	return _reward("item", str(e.get("id", "")), amount, "common")


static func _item_rarity(data: GameData, item_id: String) -> String:
	if data != null and item_id != "" and data.has_id("items", item_id):
		return data.item(item_id).rarity
	return "common"
