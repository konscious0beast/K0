class_name SeedUtil extends RefCounted
## Deterministic seed derivation (02_TECH §4.6). 31-bit results; treat as public (not secret, 05 CR-11).
## Purposes in use: "floor" (index = floor), "battle", "lootbox", "chest", "show", "shop", "event", "stray",
## "retry" (generator), "loot"; in battle "ctb", "action", "ai", "gift".


static func mix(a: int, b: int) -> int:
	var h: int = (a ^ (b * 0x9E3779B1)) & 0x7FFFFFFF
	h = ((h ^ (h >> 15)) * 0x2C1B3C6D) & 0x7FFFFFFF
	h = ((h ^ (h >> 12)) * 0x297A2D39) & 0x7FFFFFFF
	return (h ^ (h >> 15)) & 0x7FFFFFFF


static func derive(base: int, purpose: String, index: int) -> int:
	return mix(mix(base, purpose.hash()), index)


## New RandomNumberGenerator with rng.seed = seed.
static func make_rng(seed: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	return rng
