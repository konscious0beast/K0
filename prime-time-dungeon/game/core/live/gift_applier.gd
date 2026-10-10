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
## Equipment the party already owns (LootRoller.owned_equipment, earlier in this gift) becomes credits:
## ItemDef.duplicate_credits() per piece (GDD §9.3, integers only — the same rule in battle, ActionResolver). External
## gifts
## book their items into state.flags["live"]["gift_items"] (L3 statistics) and their load/caps into the run counters
## (GiftPolicy.note_applied). In battle (BattleState.apply_gift) the caller books the same via note_battle_gift().
## Randomness only from `rng` (integer draws), so a replay with the same seed stream ("gift") yields the same result.

const FixedMath := preload("res://core/stats/fixed_math.gd")
const RARITY_ORDER: PackedStringArray = LootRoller.RARITY_ORDER


## `tick` = run clock of the application (GiftPolicy.note_applied: last_delivery_tick of service gifts; -1 = unknown).
static func apply(state: GameState, data: GameData, g: Dictionary, rng: RandomNumberGenerator,
		tick: int = -1) -> Array[LootReward]:
	var out: Array[LootReward] = []
	if state == null or g.is_empty():
		return out
	var effect: int = clampi(JsonUtil.to_int(g.get("effect_pm", 1000)), 0, 1000)
	var floor_index: int = state.floor_run.index if state.floor_run != null else 1
	var contents: Variant = g.get("contents", [])
	var has_contents: bool = contents is Array and not (contents as Array).is_empty()
	match str(g.get("kind", "")):
		"gold":
			var credits: int = GiftPolicy.scale(maxi(0, JsonUtil.to_int(g.get("amount", 0))), effect)
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
		GiftPolicy.note_applied(live, g, {}, tick)
	return out


## Run bookkeeping of a gift applied IN battle by BattleState.apply_gift (`events` = its ActionEvents), the same as
## apply() does outside battles (05 §6.9: statistics must not depend on whether the gift arrived in a battle):
## count_battle_items + the booking into the run counters (GiftPolicy.note_applied at run tick `tick`). System gifts:
## nothing. RunSim uses it; the live run books at the hand-out (Show.take_pending_gift) and only counts the items
## (Show.note_battle_gift → count_battle_items), so every gift is booked exactly once.
static func note_battle_gift(state: GameState, g: Dictionary, events: Array[ActionEvent], tick: int = -1) -> void:
	if state == null or not Gift.is_external(g):
		return
	count_battle_items(state, g, events)
	GiftPolicy.note_applied(live_counters(state), g, {}, tick)


## The ITEM_GAINED items (item_id, value) of an external gift applied in battle → flags["live"]["gift_items"] (L3).
static func count_battle_items(state: GameState, g: Dictionary, events: Array[ActionEvent]) -> void:
	if state == null or not Gift.is_external(g):
		return
	var live: Dictionary = live_counters(state)
	if not (live.get("gift_items", null) is Dictionary):
		live["gift_items"] = {}
	var items: Dictionary = live["gift_items"]
	for e: ActionEvent in events:
		if e != null and e.type == ActionEvent.Type.ITEM_GAINED and e.item_id != "" and e.value > 0:
			items[e.item_id] = JsonUtil.to_int(items.get(e.item_id, 0)) + e.value


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
		if JsonUtil.to_int(d.get("credits", 0)) > 0:
			out.append(_reward("credits", "", JsonUtil.to_int(d["credits"]), rarity))
		elif str(d.get("item_id", "")) != "":
			out.append(_reward("item", str(d["item_id"]), maxi(1, JsonUtil.to_int(d.get("qty", 1))), rarity))


static func _roll_box(data: GameData, box_id: String, effect: int, floor_index: int, rng: RandomNumberGenerator,
		out: Array[LootReward]) -> void:
	if data == null or rng == null or not data.has_id("lootboxes", box_id):
		push_warning("[GiftApplier] unknown lootbox '%s' for a gift chest" % box_id)
		return
	var box: LootboxDef = data.lootbox(box_id)
	var rolls: int = GiftPolicy.rolls_for(maxi(1, box.rolls), effect)
	var weights: Array[int] = []
	for r: String in RARITY_ORDER:
		weights.append(maxi(0, JsonUtil.to_int(box.rarity_weights.get(r, 0))))
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


## One entry of LootRoller.pick_from_pool(floor, rarity) (empty pool → next lower rarity; one draw).
static func _roll_entry(data: GameData, floor_index: int, rarity: String, rng: RandomNumberGenerator,
		out: Array[LootReward]) -> void:
	if data == null or rng == null:
		return
	var picked: Dictionary = LootRoller.pick_from_pool(data, floor_index, rarity, rng)
	if picked.is_empty():
		return
	var e: Dictionary = picked["entry"]
	var amount: int = maxi(1, JsonUtil.to_int(e.get("amount", 1), 1))
	if str(e.get("kind", "item")) == "credits":
		out.append(_reward("credits", "", amount, str(picked["rarity"])))
	else:
		out.append(_reward("item", str(e.get("id", "")), amount, str(picked["rarity"])))


# --- sponsor effects ----------------------------------------------------------------------------------------------

static func _apply_sponsor(state: GameState, data: GameData, sponsor_id: String, effect: int,
		out: Array[LootReward]) -> void:
	if data == null or not data.has_id("sponsors", sponsor_id):
		push_warning("[GiftApplier] unknown sponsor '%s'" % sponsor_id)
		return
	var sp: SponsorDef = data.sponsor(sponsor_id)
	for eff: Dictionary in sp.gift:
		var value: int = JsonUtil.to_int(eff.get("value", 0))
		var scaled: int = value * effect / 1000
		match str(eff.get("kind", "")):
			"heal_party_pct":
				for m: PartyMember in _living(state):
					_heal(m, FixedMath.div_round(_max_hp(m, data) * scaled, 100), data)
			"heal_party_flat":
				for m: PartyMember in _living(state):
					_heal(m, scaled, data)
			"mp_party_pct":
				for m: PartyMember in _living(state):
					var max_mp: int = _max_mp(m, data)
					m.mp = mini(max_mp, m.mp + FixedMath.div_round(max_mp * scaled, 100))
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
					ko.hp = mini(_max_hp(ko, data), maxi(1, FixedMath.div_round(_max_hp(ko, data) * scaled, 100)))
				else:
					var low: PartyMember = _lowest_ratio(state, data)
					if low != null:
						_heal(low, FixedMath.div_round(_max_hp(low, data) * scaled, 100), data)
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

## Equipment already owned (LootRoller.owned_equipment, earlier in `out`) → ItemDef.duplicate_credits() per piece; a
## stack of a new piece keeps 1.
static func _convert_duplicates(state: GameState, data: GameData, out: Array[LootReward]) -> void:
	if data == null:
		return
	var owned: Dictionary = LootRoller.owned_equipment(state)
	var converted: Array[LootReward] = []
	for r: LootReward in out:
		if r.kind != "item" or not data.has_id("items", r.id) or not data.item(r.id).is_equipment():
			converted.append(r)
			continue
		var dup: int = r.amount
		if not owned.has(r.id):
			owned[r.id] = true
			dup = r.amount - 1
			converted.append(_reward("item", r.id, 1, r.rarity))
		if dup > 0:
			var c: LootReward = _reward("credits", "", data.item(r.id).duplicate_credits() * dup, r.rarity)
			c.converted_from = r.id
			converted.append(c)
	out.assign(converted)


static func _count_items(live: Dictionary, out: Array[LootReward]) -> void:
	if not (live.get("gift_items", null) is Dictionary):
		live["gift_items"] = {}
	var items: Dictionary = live["gift_items"]
	for r: LootReward in out:
		if r.kind == "item" and r.id != "":
			items[r.id] = JsonUtil.to_int(items.get(r.id, 0)) + r.amount


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

