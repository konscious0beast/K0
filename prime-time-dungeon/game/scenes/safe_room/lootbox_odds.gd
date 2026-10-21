extends RefCounted
## Private M6 helper (§0.3): published odds of a campaign lootbox, computed exactly like LootRoller (02_TECH §6.1):
## pity forces the FIRST roll (epic before rare), an unmet guarantee forces the LAST roll to exactly the guarantee
## rarity, every other roll uses rarity_weights. Display only — the roll itself is Game.open_lootbox().

const RARITIES: PackedStringArray = ["common", "rare", "epic"]


## Per-roll rarity probabilities from rarity_weights.
static func per_roll(box: LootboxDef) -> Dictionary:
	var total: float = 0.0
	for r: String in RARITIES:
		total += maxf(0.0, float(box.rarity_weights.get(r, 0)))
	var out: Dictionary = {}
	for r: String in RARITIES:
		out[r] = maxf(0.0, float(box.rarity_weights.get(r, 0))) / total if total > 0.0 else 0.0
	return out


## Rarity the pity forces on the first roll ("" = none): epic has priority (GDD §9.3).
static func pity_forced(pity_rare: int, pity_epic: int, limits: Dictionary) -> String:
	if pity_epic >= int(limits.get("epic", 8)):
		return "epic"
	if pity_rare >= int(limits.get("rare", 4)):
		return "rare"
	return ""


## {"rolls", "per_roll", "forced_first", "p_rare_plus", "p_epic", "guarantee"} for one box with the given pity state.
static func box_odds(box: LootboxDef, pity_rare: int = 0, pity_epic: int = 0, limits: Dictionary = {"rare": 4,
		"epic": 8}) -> Dictionary:
	var pr: Dictionary = per_roll(box)
	var forced: String = pity_forced(pity_rare, pity_epic, limits)
	# State: [has_rare_plus, has_epic] → probability.
	var states: Dictionary = {Vector2i(0, 0): 1.0}
	var n: int = maxi(box.rolls, 1)
	for i in n:
		var next: Dictionary = {}
		for key: Variant in states.keys():
			var st: Vector2i = key
			var p: float = float(states[key])
			var dist: Dictionary = pr
			if i == 0 and forced != "":
				dist = {forced: 1.0}
			elif i == n - 1 and box.guarantee != "" and not _met(st, box.guarantee):
				dist = {box.guarantee: 1.0}
			for r: Variant in dist.keys():
				var q: float = float(dist[r])
				if q <= 0.0:
					continue
				var ns: Vector2i = st
				if str(r) == "rare" or str(r) == "epic":
					ns.x = 1
				if str(r) == "epic":
					ns.y = 1
				next[ns] = float(next.get(ns, 0.0)) + p * q
		states = next
	var p_rare_plus: float = 0.0
	var p_epic: float = 0.0
	for key: Variant in states.keys():
		var st2: Vector2i = key
		if st2.x == 1:
			p_rare_plus += float(states[key])
		if st2.y == 1:
			p_epic += float(states[key])
	return {"rolls": n, "per_roll": pr, "forced_first": forced, "p_rare_plus": p_rare_plus, "p_epic": p_epic,
		"guarantee": box.guarantee, "fixed_pool": box.fixed_pool}


static func _met(st: Vector2i, guarantee: String) -> bool:
	return st.y == 1 if guarantee == "epic" else st.x == 1


## Pool entries with their per-roll probability: [{"rarity", "kind", "id", "amount", "p"}] (normal rolls).
static func entry_odds(box: LootboxDef, data: GameData, floor_index: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var pr: Dictionary = per_roll(box)
	for r: String in RARITIES:
		var pool: Array[Dictionary] = data.loot_pool(floor_index, r)
		var total: float = 0.0
		for e: Dictionary in pool:
			total += maxf(0.0, float(e.get("weight", 0)))
		for e: Dictionary in pool:
			var w: float = maxf(0.0, float(e.get("weight", 0)))
			out.append({"rarity": r, "kind": str(e.get("kind", "item")), "id": str(e.get("id", "")),
				"amount": int(e.get("amount", 1)), "p": float(pr[r]) * (w / total if total > 0.0 else 0.0)})
	return out


## Fixed fan entries (box.fixed_pool == "fan"): [{"kind", "id", "amount", "p"}] — p within the fixed draw.
static func fixed_odds(box: LootboxDef, data: GameData, floor_index: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if box.fixed_pool == "":
		return out
	var pool: Array[Dictionary] = data.loot_pool(floor_index, box.fixed_pool)
	var total: float = 0.0
	for e: Dictionary in pool:
		total += maxf(0.0, float(e.get("weight", 0)))
	for e: Dictionary in pool:
		out.append({"kind": str(e.get("kind", "item")), "id": str(e.get("id", "")), "amount": int(e.get("amount", 1)),
			"p": maxf(0.0, float(e.get("weight", 0))) / total if total > 0.0 else 0.0})
	return out
