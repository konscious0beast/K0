extends RefCounted
## Sponsor gifts in a real-time combat (07 §9.2) — private helper of RtSim (no class_name; preloaded as Gifts): the
## effects of one gift at a tick boundary, the same kinds as the CTB battle (ActionResolver.apply_gift_effects):
## sponsor_buff (the sponsor's effects: heal_party_pct, heal_party_flat × FIXED_SCALE_PM, mp_party_pct, status_party /
## status_enemies, item, revive_or_heal_lowest), gold, chest and fan_pack (server contents, else rolls). Draws (chest
## rolls) come from the gift's own generator SeedUtil.derive(seed, "gift", n) (RtSim.apply_gift), like the CTB battle.

const FixedMath := preload("res://core/stats/fixed_math.gd")
const Damage := preload("res://core/rt/rt_damage.gd")
const StatusFx := preload("res://core/rt/rt_status_fx.gd")


## The effects of gift `g` ({"kind", "effect_pm"?, …} like the CTB gift) with the gift generator `rng`.
static func apply(sim: RtSim, g: Dictionary, rng: RandomNumberGenerator) -> void:
	var effect_pm: int = clampi(JsonUtil.to_int(g.get("effect_pm", 1000), 1000), 0, 1000)
	match str(g.get("kind", "")):
		"sponsor_buff":
			_sponsor(sim, str(g.get("sponsor_id", "")), effect_pm)
		"gold":
			_credits(sim, FixedMath.div_round(JsonUtil.to_int(g.get("amount", 0)) * effect_pm, 1000), "")
		"chest", "fan_pack":
			var contents: Variant = g.get("contents", [])
			if contents is Array and not (contents as Array).is_empty():
				for c: Variant in (contents as Array):
					if c is Dictionary:
						_content(sim, c)
			elif str(g.get("kind", "")) == "chest":
				_roll_box(sim, rng, "box_" + str(g.get("tier", "bronze")), effect_pm)
			else:
				_roll_pool(sim, rng, "common")


# --- private --------------------------------------------------------------------------------------------------------

## SPONSOR_GIFT (sponsor id, name), then each effect of the sponsor scaled by effect_pm (07 §9.2): heals and MP on the
## living party (percent of the max, or flat × FIXED_SCALE_PM), statuses on the living party / the enemies on stage
## (the gift's ms × effect_pm, else the status's default duration; ignore_resist), items into the battle inventory,
## revive_or_heal_lowest (the KO'd member with the smallest slot is revived with value % HP, else the lowest share is
## healed by value %).
static func _sponsor(sim: RtSim, sponsor_id: String, effect_pm: int) -> void:
	var data: GameData = sim.game_data()
	if data == null or not data.has_id("sponsors", sponsor_id):
		push_warning("RtSim.apply_gift: unknown sponsor '%s'" % sponsor_id)
		return
	var sp: SponsorDef = data.sponsor(sponsor_id)
	var ev: ActionEvent = sim.ev(ActionEvent.Type.SPONSOR_GIFT)
	ev.sponsor_id = sp.id
	ev.text = sp.name
	var party: Array[RtUnit] = []
	for u: RtUnit in sim.units_ref():
		if u.side == Combatant.Side.PARTY:
			party.append(u)
	for gv: Variant in sp.gift:
		var g: Dictionary = gv
		var scaled: int = JsonUtil.to_int(g.get("value", 0)) * effect_pm / 1000
		match str(g.get("kind", "")):
			"heal_party_pct":
				for m: RtUnit in party:
					if sim.is_alive(m):
						Damage.heal(sim, null, m, FixedMath.div_round(m.max_hp() * scaled, 100), "", "")
			"heal_party_flat":                           # the scale before the effect factor (where the data carry it)
				var flat: int = FixedMath.mul_pm(JsonUtil.to_int(g.get("value", 0)), sim.bal.i("FIXED_SCALE_PM")) \
					* effect_pm / 1000
				for m: RtUnit in party:
					if sim.is_alive(m):
						Damage.heal(sim, null, m, flat, "", "")
			"mp_party_pct":
				for m: RtUnit in party:
					if sim.is_alive(m):
						Damage.change_mp(sim, m, FixedMath.div_round(m.max_mp() * scaled, 100))
			"status_party", "status_enemies":
				var side: int = Combatant.Side.PARTY if str(g.get("kind", "")) == "status_party" else Combatant.Side.ENEMY
				var ms: int = JsonUtil.to_int(g.get("ms", 0))
				if ms > 0:
					ms = maxi(100, FixedMath.mul_pm(ms, effect_pm))
				for u: RtUnit in sim.units_ref():
					if u.side == side and sim.is_alive(u) and sim.targetable(u):
						StatusFx.apply(sim, "", u, str(g.get("status", "")), ms, 1000, 0, null,
							bool(g.get("ignore_resist", false)))
			"item":
				_item(sim, str(g.get("item", "")), JsonUtil.to_int(g.get("value", 0)))
			"revive_or_heal_lowest":
				var ko: RtUnit = null
				var low: RtUnit = null
				for m: RtUnit in party:
					if m.is_ko() and ko == null:
						ko = m
					elif sim.is_alive(m) and (low == null or m.hp * low.max_hp() < low.hp * m.max_hp()):
						low = m
				if ko != null:
					Damage.revive(sim, null, ko, maxi(1, FixedMath.div_round(ko.max_hp() * scaled, 100)), "")
				elif low != null:
					Damage.heal(sim, null, low, FixedMath.div_round(low.max_hp() * scaled, 100), "", "")


## Gift credits (CREDITS_GAINED, credits_delta); `from` = the duplicate equipment they replace (item_id), else "".
static func _credits(sim: RtSim, amount: int, from: String) -> void:
	if amount <= 0:
		return
	sim.tally["credits_delta"] = int(sim.tally["credits_delta"]) + amount
	var ev: ActionEvent = sim.ev(ActionEvent.Type.CREDITS_GAINED)
	ev.value = amount
	ev.item_id = from


## A gift item: consumables go into the battle inventory (they do not count against the 3 per combat until used);
## equipment the party owns already (or got earlier in this combat) becomes ItemDef.duplicate_credits() per piece —
## the duplicate rule of GDD §9.3 / ActionResolver._gain_item.
static func _item(sim: RtSim, item_id: String, count: int) -> void:
	if count <= 0:
		return
	var it: ItemDef = sim.item_def(item_id)
	if it == null:
		push_warning("RtSim.apply_gift: unknown item '%s'" % item_id)
		return
	var delta: Dictionary = sim.tally["item_delta"]
	var dup: int = 0
	var n: int = count
	if it.is_equipment():
		var owned: bool = sim.setup.owned_equipment.has(item_id) or JsonUtil.to_int(delta.get(item_id, 0)) > 0
		dup = n if owned else n - 1
		n -= dup
	if n > 0:
		if it.type == "consumable":
			sim.items[item_id] = JsonUtil.to_int(sim.items.get(item_id, 0)) + n
		delta[item_id] = JsonUtil.to_int(delta.get(item_id, 0)) + n
		var ev: ActionEvent = sim.ev(ActionEvent.Type.ITEM_GAINED)
		ev.item_id = item_id
		ev.value = n
	if dup > 0:
		_credits(sim, it.duplicate_credits() * dup, it.id)


## Server content entry {"rarity", "item_id", "qty"} or {"rarity", "credits"} (05 §6.5).
static func _content(sim: RtSim, c: Dictionary) -> void:
	if JsonUtil.to_int(c.get("credits", 0)) > 0:
		_credits(sim, JsonUtil.to_int(c.get("credits", 0)), "")
	elif str(c.get("item_id", "")) != "":
		_item(sim, str(c.get("item_id", "")), maxi(1, JsonUtil.to_int(c.get("qty", 1), 1)))


## An offline chest (05 §7.4, like ActionResolver._roll_box): rolls × effect_pm (at least 1) of the box's rarity
## weights, the last roll honouring the guarantee, entries from the floor's loot pool.
static func _roll_box(sim: RtSim, rng: RandomNumberGenerator, box_id: String, effect_pm: int) -> void:
	var data: GameData = sim.game_data()
	if data == null or not data.has_id("lootboxes", box_id):
		push_warning("RtSim.apply_gift: unknown lootbox '%s'" % box_id)
		return
	var box: LootboxDef = data.lootbox(box_id)
	var rolls: int = maxi(1, FixedMath.div_round(box.rolls * effect_pm, 1000))
	var order: PackedStringArray = ["common", "rare", "epic"]
	var weights: Array[int] = []
	for r: String in order:
		weights.append(maxi(0, JsonUtil.to_int(box.rarity_weights.get(r, 0))))
	var need: int = order.find(box.guarantee)
	var guaranteed: Array[int] = weights.duplicate()
	var guaranteed_total: int = 0
	for j in guaranteed.size():
		if j < need:
			guaranteed[j] = 0
		guaranteed_total += guaranteed[j]
	var best: int = -1
	for i in rolls:
		var ri: int = 0
		if i == rolls - 1 and need > 0 and best < need:
			ri = _weighted_nonzero(rng, guaranteed) if guaranteed_total > 0 else need
		else:
			ri = _weighted_nonzero(rng, weights)
		best = maxi(best, ri)
		_roll_pool(sim, rng, order[ri])


static func _roll_pool(sim: RtSim, rng: RandomNumberGenerator, rarity: String) -> void:
	var data: GameData = sim.game_data()
	var pool: Array[Dictionary] = data.loot_pool(sim.setup.floor_index, rarity) if data != null else []
	if pool.is_empty():
		return
	var w: Array[int] = []
	for e: Dictionary in pool:
		w.append(JsonUtil.to_int(e.get("weight", 1), 1))
	var e: Dictionary = pool[FixedMath.weighted_index(rng, w)]
	if str(e.get("kind", "")) == "credits":
		_credits(sim, JsonUtil.to_int(e.get("amount", 0)), "")
	else:
		_item(sim, str(e.get("id", "")), JsonUtil.to_int(e.get("amount", 1), 1))


## Weighted index ignoring zero weights (all zero → 0).
static func _weighted_nonzero(rng: RandomNumberGenerator, weights: Array[int]) -> int:
	var total: int = 0
	for w: int in weights:
		total += w
	if total <= 0:
		return 0
	var r: int = rng.randi_range(0, total - 1)
	for i in weights.size():
		r -= weights[i]
		if r < 0:
			return i
	return weights.size() - 1
