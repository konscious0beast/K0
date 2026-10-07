# STUB(M0) — owned by M2. Replace completely, keep the public API.
class_name LootRoller extends RefCounted
## Lootbox / chest / drop rolls, deterministic per rng (02_TECH §6.1).


static func roll_lootbox(box: LootboxDef, data: GameData, floor_index: int, state: GameState,
		rng: RandomNumberGenerator) -> Array[LootReward]:
	return []


## Layout chest: wood → 20..40 credits + 1 entry from pools.f<i>.common; metal/locked → contents.
static func roll_chest(chest: Dictionary, data: GameData, floor_index: int, state: GameState,
		rng: RandomNumberGenerator) -> Array[LootReward]:
	return []


## Procedural floors: 1 roll (+1 at 20 %).
static func roll_chest_table(def: FloorDef, rng: RandomNumberGenerator) -> Array[LootReward]:
	return []


static func roll_drops(drops: Array[Dictionary], avg_party_lck: float, rng: RandomNumberGenerator) -> PackedStringArray:
	return PackedStringArray()


static func best_rarity(rewards: Array[LootReward]) -> String:
	return "common"
