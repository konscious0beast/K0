class_name GiftApplier extends RefCounted
## Applies a gift OUTSIDE battles (05 §6.5/§6.10/§11.2); in battle BattleState.apply_gift is used (CR-2).
##
## Returns the material rewards (items, credits) — the caller adds them to the inventory (Show: Game.add_rewards, the
## same path as chests and lootboxes). Effects that are not rewards are applied to `state` directly:
## - gold: credits = (amount × effect_pm + 500) // 1000.
## - chest: server `contents` as given; offline/dev (no contents) rolls the LootboxDef "box_<tier>" with
##   rolls = max(1, (box.rolls × effect_pm + 500) // 1000), the box guarantee on the last roll (rarities below it get
##   weight 0, 05 §7.4), entries from loot_pool(floor, rarity) (empty pool → next lower rarity). Lootbox pity is not
##   touched (sponsor chests are a separate system, 05 §0).
## - fan_pack: contents, else one entry of the common pool (the hype bonus is Show's part).
## - sponsor_buff: SponsorDef.gift effects scaled by effect_pm like in battle (value × effect_pm / 1000, HP/MP
##   percentages of the max values rounded half up): heal_party_pct / heal_party_flat / mp_party_pct on living members,
##   revive_or_heal_lowest, item (count unscaled); statuses only exist in battle (no effect here).
## - cheer: cosmetic, nothing.
## Equipment the party already owns (inventory, equipped, earlier in this gift) becomes credits:
## roundi(sell value × LootRoller.DUPLICATE_CREDIT_MULT) per piece (GDD §9.3). External gifts book their items into
## state.flags["live"]["gift_items"] (L3 statistics) and their load/caps into the run counters
## (GiftPolicy.note_applied).
## Randomness only from `rng` (integer draws), so a replay with the same seed stream ("gift") yields the same result.

const RARITY_ORDER: PackedStringArray = ["common", "rare", "epic"]


static func apply(state: GameState, data: GameData, g: Dictionary, rng: RandomNumberGenerator) -> Array[LootReward]:
	var out: Array[LootReward] = []
	if state == null or g.is_empty():
		return out
	var effect: int = clampi(_int(g.get("effect_pm", 1000)), 0, 1000)
	var floor_index: int = state.floor_run.index if state.floor_run != null else 1
	var contents: Variant = g.get("contents", [])
	var has_contents: bool = contents is Array and not (contents as Array).is_empty()
	match str(g.get("kind", "")):
		"gold":
			var credits: int = GiftPolicy.scale(maxi(0, _int(g.get("amount", 0))), effect)
			if credits > 0:
				out.append(_reward("credits", "", credits, "common"))
		"chest":
			if has_contents:
				_from_contents(contents, out)
			else:
				_roll_box(data, "box_" + str(g.get("tier", "bronze")), effect, floor_index, rng, out)
		"fan_pack":
			if has_contents:
				_from_contents(contents, out)
			else:
				_roll_entry(data, floor_index, "common", rng, out)
		"sponsor_buff":
			_apply_sponsor(state, data, str(g.get("sponsor_id", "")), effect, out)
		_:
			pass
	_convert_duplicates(state, data, out)
	if Gift.is_external(g):
		var live: Dictionary = live_counters(state)
		_count_items(live, out)
		GiftPolicy.note_applied(live, g, {})
	return out


## state.flags["live"] (created on first use) — gift counters of the run (GiftPolicy).
static func live_counters(state: GameState) -> Dictionary:
	if not (state.flags.get("live", null) is Dictionary):
		state.flags["live"] = {}
	return state.flags["live"]


# --- contents / rolls ---------------------------------------------------------------------------------------------

static func _from_contents(contents: Array, out: Array[LootReward]) -> void:
	for c: Variant in contents:
		if not (c is Dictionary):
			continue
		var d: Dictionary = c
		var rarity: String = str(d.get("rarity", "common"))
		if _int(d.get("credits", 0)) > 0:
			out.append(_reward("credits", "", _int(d["credits"]), rarity))
		elif str(d.get("item_id", "")) != "":
			out.append(_reward("item", str(d["item_id"]), maxi(1, _int(d.get("qty", 1))), rarity))


static func _roll_box(data: GameData, box_id: String, effect: int, floor_index: int, rng: RandomNumberGenerator,
		out: Array[LootReward]) -> void:
	if data == null or rng == null or not data.has_id("lootboxes", box_id):
		push_warning("[GiftApplier] unknown lootbox '%s' for a gift chest" % box_id)
		return
	var box: LootboxDef = data.lootbox(box_id)
	var rolls: int = GiftPolicy.rolls_for(maxi(1, box.rolls), effect)
	var weights: Array[int] = []
	for r: String in RARITY_ORDER:
		weights.append(maxi(0, _int(box.rarity_weights.get(r, 0))))
	var need: int = RARITY_ORDER.find(box.guarantee)
	var guaranteed: Array[int] = weights.duplicate()
	for j in guaranteed.size():
		if j < need:
			guaranteed[j] = 0
	var best: int = -1
	for i in rolls:
		var ri: int = 0
		if i == rolls - 1 and need > 0 and best < need:
			ri = _weighted(rng, guaranteed) if _sum(guaranteed) > 0 else need
		else:
			ri = _weighted(rng, weights)
		best = maxi(best, ri)
		_roll_entry(data, floor_index, RARITY_ORDER[ri], rng, out)


## One weighted entry of loot_pool(floor, rarity); an empty pool falls back to the next lower rarity.
static func _roll_entry(data: GameData, floor_index: int, rarity: String, rng: RandomNumberGenerator,
		out: Array[LootReward]) -> void:
	if data == null or rng == null:
		return
	var idx: int = maxi(0, RARITY_ORDER.find(rarity))
	while idx >= 0:
		var pool: Array[Dictionary] = data.loot_pool(floor_index, RARITY_ORDER[idx])
		if not pool.is_empty():
			var w: Array[int] = []
			for e: Dictionary in pool:
				w.append(maxi(0, _int(e.get("weight", 1))))
			var e: Dictionary = pool[_weighted(rng, w)]
			var amount: int = maxi(1, _int(e.get("amount", 1)))
			if str(e.get("kind", "item")) == "credits":
				out.append(_reward("credits", "", amount, RARITY_ORDER[idx]))
			else:
				out.append(_reward("item", str(e.get("id", "")), amount, RARITY_ORDER[idx]))
			return
		idx -= 1


# --- sponsor effects ----------------------------------------------------------------------------------------------

static func _apply_sponsor(state: GameState, data: GameData, sponsor_id: String, effect: int,
		out: Array[LootReward]) -> void:
	if data == null or not data.has_id("sponsors", sponsor_id):
		push_warning("[GiftApplier] unknown sponsor '%s'" % sponsor_id)
		return
	var sp: SponsorDef = data.sponsor(sponsor_id)
	for eff: Dictionary in sp.gift:
		var value: int = _int(eff.get("value", 0))
		var scaled: int = value * effect / 1000
		match str(eff.get("kind", "")):
			"heal_party_pct":
				for m: PartyMember in _living(state):
					_heal(m, _div_round(_max_hp(m, data) * scaled, 100), data)
			"heal_party_flat":
				for m: PartyMember in _living(state):
					_heal(m, scaled, data)
			"mp_party_pct":
				for m: PartyMember in _living(state):
					var max_mp: int = _max_mp(m, data)
					m.mp = mini(max_mp, m.mp + _div_round(max_mp * scaled, 100))
			"item":
				var item_id: String = str(eff.get("item", ""))
				if value > 0 and data.has_id("items", item_id):
					out.append(_reward("item", item_id, value, data.item(item_id).rarity))
			"revive_or_heal_lowest":
				var ko: PartyMember = null
				for m: PartyMember in state.party:
					if m != null and m.hp <= 0:
						ko = m
						break
				if ko != null:
					ko.hp = mini(_max_hp(ko, data), maxi(1, _div_round(_max_hp(ko, data) * scaled, 100)))
				else:
					var low: PartyMember = _lowest_ratio(state, data)
					if low != null:
						_heal(low, _div_round(_max_hp(low, data) * scaled, 100), data)
			_:
				pass   # status_party / status_enemies: statuses only exist in battle


static func _living(state: GameState) -> Array[PartyMember]:
	var out: Array[PartyMember] = []
	for m: PartyMember in state.party:
		if m != null and m.hp > 0:
			out.append(m)
	return out


static func _lowest_ratio(state: GameState, data: GameData) -> PartyMember:
	var best: PartyMember = null
	var best_hp: int = 0
	var best_max: int = 1
	for m: PartyMember in _living(state):
		var mx: int = maxi(1, _max_hp(m, data))
		# m.hp / mx < best_hp / best_max, exact in integers; ties keep the earlier member
		if best == null or m.hp * best_max < best_hp * mx:
			best = m
			best_hp = m.hp
			best_max = mx
	return best


static func _heal(m: PartyMember, amount: int, data: GameData) -> void:
	if amount > 0:
		m.hp = mini(_max_hp(m, data), m.hp + amount)


static func _max_hp(m: PartyMember, data: GameData) -> int:
	return Progression.total_stats(m, data).values[StatBlock.Stat.HP]


static func _max_mp(m: PartyMember, data: GameData) -> int:
	return Progression.total_stats(m, data).values[StatBlock.Stat.MP]


# --- bookkeeping --------------------------------------------------------------------------------------------------

## Equipment already owned (inventory, equipped, earlier in `out`) → credits per piece; a stack of a new piece keeps 1.
static func _convert_duplicates(state: GameState, data: GameData, out: Array[LootReward]) -> void:
	if data == null:
		return
	var owned: Dictionary = {}
	if state.inventory != null:
		for item_id: Variant in state.inventory.counts.keys():
			if _int(state.inventory.counts[item_id]) > 0:
				owned[str(item_id)] = true
	for m: PartyMember in state.party:
		if m == null:
			continue
		for slot: Variant in m.equipment.keys():
			if str(m.equipment[slot]) != "":
				owned[str(m.equipment[slot])] = true
	var converted: Array[LootReward] = []
	for r: LootReward in out:
		if r.kind != "item" or not data.has_id("items", r.id) or not data.item(r.id).is_equipment():
			converted.append(r)
			continue
		var piece_credits: int = roundi(data.item(r.id).sell_value() * LootRoller.DUPLICATE_CREDIT_MULT)
		var dup: int = r.amount
		if not owned.has(r.id):
			owned[r.id] = true
			dup = r.amount - 1
			var keep: LootReward = _reward("item", r.id, 1, r.rarity)
			converted.append(keep)
		if dup > 0:
			var c: LootReward = _reward("credits", "", piece_credits * dup, r.rarity)
			c.converted_from = r.id
			converted.append(c)
	out.assign(converted)


static func _count_items(live: Dictionary, out: Array[LootReward]) -> void:
	if not (live.get("gift_items", null) is Dictionary):
		live["gift_items"] = {}
	var items: Dictionary = live["gift_items"]
	for r: LootReward in out:
		if r.kind == "item" and r.id != "":
			items[r.id] = _int(items.get(r.id, 0)) + r.amount


# --- helpers ------------------------------------------------------------------------------------------------------

static func _reward(kind: String, item_id: String, amount: int, rarity: String) -> LootReward:
	var r: LootReward = LootReward.new()
	r.kind = kind
	r.id = item_id
	r.amount = amount
	r.rarity = rarity
	return r


## Weighted index by integer weights (zero weights never hit; all zero → 0). One draw.
static func _weighted(rng: RandomNumberGenerator, weights: Array[int]) -> int:
	var total: int = _sum(weights)
	if total <= 0:
		return 0
	var x: int = rng.randi_range(0, total - 1)
	for i in weights.size():
		x -= weights[i]
		if x < 0:
			return i
	return weights.size() - 1


static func _sum(weights: Array[int]) -> int:
	var total: int = 0
	for w: int in weights:
		total += maxi(0, w)
	return total


## num / den rounded half away from zero (den > 0).
static func _div_round(num: int, den: int) -> int:
	if den <= 0:
		return 0
	if num >= 0:
		return (num + den / 2) / den
	return -((-num + den / 2) / den)


static func _int(v: Variant) -> int:
	if typeof(v) == TYPE_INT:
		return v
	if typeof(v) == TYPE_FLOAT and is_finite(float(v)):
		return int(v)
	return 0
