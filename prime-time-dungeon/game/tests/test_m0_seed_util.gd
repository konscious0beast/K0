extends TestCase
## SeedUtil determinism + golden values (02_TECH §4.6).


func test_golden_values() -> void:
	assert_eq(SeedUtil.mix(1, 2), 696197768, "mix(1, 2)")
	assert_eq(SeedUtil.derive(4242, "floor", 1), 1557687279, "derive(4242, floor, 1)")
	assert_eq(SeedUtil.derive(1, "battle", 1), 582315397, "derive(1, battle, 1)")


func test_deterministic_and_31_bit() -> void:
	for base: int in [0, 1, 7, 4242, 123456789, 0x7FFFFFFF]:
		for purpose: String in ["floor", "battle", "lootbox", "chest", "show", "event", "stray", "ctb", "action", "ai",
			"gift"]:
			for i in 4:
				var a: int = SeedUtil.derive(base, purpose, i)
				assert_eq(a, SeedUtil.derive(base, purpose, i))
				assert_between(a, 0, 0x7FFFFFFF, "31-bit result")


func test_purposes_and_indices_differ() -> void:
	var seen: Dictionary = {}
	for purpose: String in ["floor", "battle", "lootbox", "chest", "show", "shop", "event", "stray", "retry"]:
		for i in 8:
			seen[SeedUtil.derive(4242, purpose, i)] = true
	assert_eq(seen.size(), 9 * 8, "no collisions in a small sample")


func test_make_rng() -> void:
	var a: RandomNumberGenerator = SeedUtil.make_rng(99)
	var b: RandomNumberGenerator = SeedUtil.make_rng(99)
	assert_eq(a.seed, 99)
	var sa: Array[int] = []
	var sb: Array[int] = []
	for i in 5:
		sa.append(a.randi())
		sb.append(b.randi())
	assert_eq(sa, sb, "same seed → same sequence")
	assert_ne(SeedUtil.make_rng(100).randi(), SeedUtil.make_rng(99).randi())
