extends TestCase
## FairRoll — provably fair commit-reveal (05 §7.3/§7.4, §11.4): the published test vector bit for bit (commit v2,
## layout_seed, loot_seed, sym, roll_key, draw, silver 3/2 rolls, gold 4/3 rolls, bronze), HMAC reference, pity,
## and the bronze distribution of 100 000 rolls within ±0.5 percentage points of the published odds.

const TABLES: String = "res://tests/fixtures/live/gift_tables.json"
const EVENT: String = "evt_2026w45_sat"
const WINDOW: String = "eu"


func _server_seed() -> PackedByteArray:
	var b: PackedByteArray = []
	for i in 32:
		b.append(i)
	return b


func _tables() -> Dictionary:
	var raw: Variant = JsonUtil.read_file(TABLES)
	if not (raw is Dictionary):
		fail("gift_tables.json does not parse")
		return {}
	return raw


func _roll_key() -> PackedByteArray:
	return FairRoll.roll_key(_server_seed(), EVENT, WINDOW, "b_7f3a9c", "c0ffee4200000017", 17)


func _summary(contents: Array[Dictionary]) -> Array:
	var out: Array = []
	for c: Dictionary in contents:
		out.append([c["rarity"], c["item_id"] if c.has("item_id") else "credits %d" % int(c["credits"]),
			int(c["qty"]) if c.has("qty") else 0])
	return out


func test_hmac_and_u48() -> void:
	var rfc: PackedByteArray = FairRoll.hmac("Jefe".to_utf8_buffer(), "what do ya want for nothing?")
	assert_eq(rfc.hex_encode(), "5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843", "RFC 4231 case 2")
	assert_eq(FairRoll.u48(PackedByteArray([0, 0, 0, 0, 1, 2, 255])), 258, "first 6 bytes big-endian")
	assert_eq(FairRoll.u48(PackedByteArray([255, 255, 255, 255, 255, 255])), 281474976710655, "2^48 − 1")
	assert_eq(FairRoll.u48(PackedByteArray([1])), 0, "too short → 0")


func test_vector_commit_and_seeds() -> void:
	var ss: PackedByteArray = _server_seed()
	assert_eq(FairRoll.commit(ss, EVENT, WINDOW, "11".repeat(32), "22".repeat(32), "33".repeat(32), 7),
		"3613e6c5f82810dc73d6629a2864df33cdfdbd3e96f980122126bcfd821fd64a", "commit v2")
	assert_eq(FairRoll.layout_seed(ss, EVENT, WINDOW), 266222357384372)
	assert_eq(FairRoll.loot_seed(FairRoll.loot_key(ss, EVENT, WINDOW), "chest", 3), 64833286715105)
	assert_eq(FairRoll.sym(ss, "t_01"), 2)
	assert_eq(FairRoll.sym(ss, "t_02"), 1)
	assert_eq(_roll_key().hex_encode(), "25e3afcc14e3ccde26f918e41da45f508541add54dac4594c3718b0987c26992", "roll_key")
	var d0: int = FairRoll.draw(_roll_key(), 0, "rarity")
	assert_eq(d0, 255368109740746)
	assert_eq(d0 % 100, 46, "→ common for silver")


func test_vector_chests() -> void:
	var t: Dictionary = _tables()
	var tiers: Dictionary = t.get("tiers", {})
	var pool: Dictionary = (t.get("pools", {}) as Dictionary).get("gift_f1", {})
	var rk: PackedByteArray = _roll_key()
	assert_eq(_summary(FairRoll.roll_chest(rk, tiers["silver"], pool, 3, "")),
		[["common", "item_ice_spray", 1], ["common", "credits 40", 0], ["rare", "item_hype_megaphone", 1]],
		"silver, 3 rolls, guarantee on roll 3")
	var silver_l2: int = FairRoll.rolls_at(3, 4)
	assert_eq(silver_l2, 2, "silver at L = 2 (load_half 4) → effect 769 → 2 rolls")
	assert_eq(_summary(FairRoll.roll_chest(rk, tiers["silver"], pool, silver_l2, "")),
		[["common", "item_ice_spray", 1], ["rare", "item_brutzel_burger", 2]], "restricted weights [0, 38, 7] on roll 2")
	assert_eq(_summary(FairRoll.roll_chest(rk, tiers["gold"], pool, 4, "")),
		[["rare", "item_smoke", 1], ["rare", "item_brutzel_burger", 2], ["epic", "acc_sneakers", 1],
			["epic", "credits 400", 0]], "gold, 4 rolls")
	var gold_l4: int = FairRoll.rolls_at(4, 8)
	assert_eq(gold_l4, 3, "gold at L = 4 → (4 × 625 + 500) // 1000 = 3 (round(2.5) = 2 would be wrong)")
	assert_eq(_summary(FairRoll.roll_chest(rk, tiers["gold"], pool, gold_l4, "")),
		[["rare", "item_smoke", 1], ["rare", "item_brutzel_burger", 2], ["epic", "acc_sneakers", 1]],
		"guarantee epic on roll 3")
	assert_eq(_summary(FairRoll.roll_chest(rk, tiers["bronze"], pool, 2, "")),
		[["common", "item_ice_spray", 1], ["common", "credits 40", 0]], "bronze, 2 rolls")


func test_pity_and_pick() -> void:
	var t: Dictionary = _tables()
	var pool: Dictionary = (t.get("pools", {}) as Dictionary).get("gift_f1", {})
	var forced: Array[Dictionary] = FairRoll.roll_chest(_roll_key(), t["tiers"]["bronze"], pool, 2, "epic")
	assert_eq(forced[0]["rarity"], "epic", "pity_forced fixes the rarity of roll 1 (05 §6.8)")
	assert_eq(forced[1]["rarity"], "common", "the other rolls stay normal")
	var w: Array[int] = [80, 18, 2]
	assert_eq(FairRoll.pick(w, 79), 0)
	assert_eq(FairRoll.pick(w, 80), 1)
	assert_eq(FairRoll.pick(w, 97), 1)
	assert_eq(FairRoll.pick(w, 98), 2)
	assert_eq(FairRoll.pick(w, 100), 0, "u mod W")
	var z: Array[int] = [0, 0, 0]
	assert_eq(FairRoll.pick(z, 5), -1, "all-zero table")
	assert_eq(FairRoll.roll_chest(_roll_key(), {"weights": [1, 2]}, pool, 1, ""), [], "malformed tier → nothing")


## 100 000 bronze rolls (one roll key, draws 0 … 99 999): every entry within ±0.5 percentage points of the
## published P/Wurf Bronze (05 §6.7).
func test_bronze_distribution() -> void:
	var t: Dictionary = _tables()
	var pool: Dictionary = (t.get("pools", {}) as Dictionary).get("gift_f1", {})
	var expected: Dictionary = {"common:credits 40": 24.0, "common:item_bandage": 20.0, "common:item_energy_krawumm": 16.0,
		"common:item_ice_spray": 12.0, "common:item_molotov": 8.0, "rare:item_brutzel_burger": 5.4,
		"rare:item_smelling_salts": 4.5, "rare:item_hype_megaphone": 3.6, "rare:item_smoke": 2.7,
		"rare:credits 150": 1.8, "epic:item_elixir": 0.8, "epic:wpn_fire_axe": 0.4, "epic:acc_sneakers": 0.4,
		"epic:credits 400": 0.4}
	var n: int = 100000
	var rolls: Array[Dictionary] = FairRoll.roll_chest(_roll_key(), t["tiers"]["bronze"], pool, n, "")
	assert_eq(rolls.size(), n)
	var counts: Dictionary = {}
	for c: Dictionary in rolls:
		var key: String = "%s:%s" % [c["rarity"], c["item_id"] if c.has("item_id") else "credits %d" % int(c["credits"])]
		counts[key] = int(counts.get(key, 0)) + 1
	for key: String in expected.keys():
		var pct: float = 100.0 * int(counts.get(key, 0)) / n
		assert_between(pct, float(expected[key]) - 0.5, float(expected[key]) + 0.5, key)
	assert_eq(counts.size(), expected.size(), "no other outcomes")
