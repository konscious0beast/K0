class_name FairRoll extends RefCounted
## Commit-reveal dice ("nachprüfbare Zufallsziehung", 05 §7) — hook, only used by tests in the slice.
## Everything is HMAC-SHA256 (key = server_seed as 32 raw bytes, messages UTF-8) and plain integer arithmetic, never
## Godot's RandomNumberGenerator, so tools/verify_fair.py (Python) and the web check page recompute it bit for bit.
##
## commit      = hex(SHA256("PTD-COMMIT-v2|" + event_id + "|" + window_id + "|" + tables_hash + "|" + rules_hash
##                          + "|" + data_hash + "|" + str(sim_version) + "|" + hex(server_seed)))
## u48(bytes)  = first 6 bytes big-endian (0 … 2^48 − 1)
## layout_seed = u48(HMAC(server_seed, "layout|" + event_id + "|" + window_id))            public from "open"
## loot_key    = HMAC(server_seed, "loot|" + event_id + "|" + window_id); loot_seed(p, i) = u48(HMAC(loot_key, p|i))
## sym(team)   = u48(HMAC(server_seed, "sym|" + team_id)) mod n_sym
## roll_key    = HMAC(server_seed, "gift|" + event_id + "|" + window_id + "|" + sender_ref + "|" + client_seed + "|"
##                    + str(nonce));  draw(i, stage) = u48(HMAC(roll_key, "draw|" + str(i) + "|" + stage))
## pick(weights, u): W = Σ weights, r = u mod W, first j with r < running sum.
## roll_chest: roll 0 forced to pity_forced (if set); the last roll draws with the weights below the guarantee set
## to 0 while no earlier roll reached it; else pick(tier weights). Item: pick(pool weights "w" in array order,
## draw(i, "item")). Content: {"rarity", "item_id", "qty"} or {"rarity", "credits"}.

const RARITIES: PackedStringArray = ["common", "rare", "epic"]
const COMMIT_PREFIX: String = "PTD-COMMIT-v2|"
const N_SYM: int = 8

static var _crypto: Crypto = null


static func hmac(key: PackedByteArray, msg: String) -> PackedByteArray:
	if _crypto == null:
		_crypto = Crypto.new()
	return _crypto.hmac_digest(HashingContext.HASH_SHA256, key, msg.to_utf8_buffer())


static func u48(b: PackedByteArray) -> int:
	if b.size() < 6:
		return 0
	var v: int = 0
	for i in 6:
		v = (v << 8) | int(b[i])
	return v


static func commit(server_seed: PackedByteArray, event_id: String, window_id: String, tables_hash: String,
		rules_hash: String, data_hash: String, sim_version: int) -> String:
	var text: String = COMMIT_PREFIX + "|".join(PackedStringArray([event_id, window_id, tables_hash, rules_hash,
		data_hash, str(sim_version), server_seed.hex_encode()]))
	return CanonicalJson.sha256_text(text)


static func layout_seed(server_seed: PackedByteArray, event_id: String, window_id: String) -> int:
	return u48(hmac(server_seed, "layout|" + event_id + "|" + window_id))


static func roll_key(server_seed: PackedByteArray, event_id: String, window_id: String, sender_ref: String,
		client_seed: String, nonce: int) -> PackedByteArray:
	return hmac(server_seed, "gift|%s|%s|%s|%s|%d" % [event_id, window_id, sender_ref, client_seed, nonce])


## tier = {"rolls", "guarantee": ""|"rare"|"epic", "weights": [common, rare, epic]} (gift_tables.json tiers.<tier>),
## pool = {"common": [...], "rare": [...], "epic": [...]} with entries {"item_id", "qty", "w"} | {"credits", "w"}.
static func roll_chest(roll_key: PackedByteArray, tier: Dictionary, pool: Dictionary, rolls: int,
		pity_forced: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var weights: Array[int] = _ints(tier.get("weights", []))
	if weights.size() != RARITIES.size():
		push_warning("[FairRoll] tier weights must have %d entries" % RARITIES.size())
		return out
	var guarantee: int = RARITIES.find(str(tier.get("guarantee", "")))
	var forced: int = RARITIES.find(pity_forced)
	var best: int = -1
	for i in maxi(0, rolls):
		var u: int = draw(roll_key, i, "rarity")
		var r: int = 0
		if i == 0 and forced >= 0:
			r = forced
		elif i == rolls - 1 and guarantee > 0 and best < guarantee:
			var restricted: Array[int] = weights.duplicate()
			for j in restricted.size():
				if j < guarantee:
					restricted[j] = 0
			r = pick(restricted, u)
		else:
			r = pick(weights, u)
		if r < 0:                     # degenerate table (all weights 0): the guarantee rarity itself, else common
			r = maxi(0, guarantee)
		best = maxi(best, r)
		var entries: Variant = pool.get(RARITIES[r], [])
		if not (entries is Array) or (entries as Array).is_empty():
			push_warning("[FairRoll] empty pool for rarity %s" % RARITIES[r])
			continue
		var list: Array = entries
		var ew: Array[int] = []
		for e: Variant in list:
			ew.append(_int((e as Dictionary).get("w", 0)) if e is Dictionary else 0)
		var entry: Dictionary = list[pick(ew, draw(roll_key, i, "item"))]
		if entry.has("credits"):
			out.append({"rarity": RARITIES[r], "credits": _int(entry["credits"])})
		else:
			out.append({"rarity": RARITIES[r], "item_id": str(entry.get("item_id", "")),
				"qty": maxi(1, _int(entry.get("qty", 1)))})
	return out


# --- additions (verifier helpers, 05 §7.3) ------------------------------------------------------------------------

## u48(HMAC(roll_key, "draw|" + str(i) + "|" + stage)), stage ∈ {"rarity", "item"}.
static func draw(p_roll_key: PackedByteArray, i: int, stage: String) -> int:
	return u48(hmac(p_roll_key, "draw|%d|%s" % [i, stage]))


## First index j with (u mod Σweights) < running sum; -1 for an all-zero table.
static func pick(weights: Array[int], u: int) -> int:
	var total: int = 0
	for w: int in weights:
		total += maxi(0, w)
	if total <= 0:
		return -1
	var r: int = u % total
	var c: int = 0
	for j in weights.size():
		c += maxi(0, weights[j])
		if r < c:
			return j
	return weights.size() - 1


static func loot_key(server_seed: PackedByteArray, event_id: String, window_id: String) -> PackedByteArray:
	return hmac(server_seed, "loot|" + event_id + "|" + window_id)


## p ∈ {"chest", "drop", "lootbox", "quest", "shop"}, i = index.
static func loot_seed(p_loot_key: PackedByteArray, p: String, i: int) -> int:
	return u48(hmac(p_loot_key, "%s|%d" % [p, i]))


static func sym(server_seed: PackedByteArray, team_id: String, n_sym: int = N_SYM) -> int:
	return u48(hmac(server_seed, "sym|" + team_id)) % maxi(1, n_sym)


## Number of rolls of a chest at a load basis (05 §6.10/§7.4): max(1, (base × effect_pm(load_half) + 500) // 1000).
static func rolls_at(base_rolls: int, load_half: int, k_pm: int = 75) -> int:
	return GiftPolicy.rolls_for(base_rolls, GiftPolicy.effect_pm(load_half, k_pm))


static func _ints(v: Variant) -> Array[int]:
	var out: Array[int] = []
	if v is Array:
		for e: Variant in (v as Array):
			out.append(_int(e))
	return out


static func _int(v: Variant) -> int:
	if typeof(v) == TYPE_INT:
		return v
	if typeof(v) == TYPE_FLOAT and is_finite(float(v)):
		return int(v)
	return 0
