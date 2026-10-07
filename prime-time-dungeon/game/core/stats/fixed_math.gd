extends RefCounted
## Private helper of core/stats + core/battle (no class_name, 02_TECH §0.3). Use via
## `const FixedMath := preload("res://core/stats/fixed_math.gd")`.
##
## Integer / fixed-point helpers for the deterministic battle core (Brief §6b.1, 05 CR-12): every game-relevant
## random draw is an integer draw (`randi_range`) and every game-relevant rounding happens on integers.
## Data floats (element mods 1.5, chances 0.35 …) are converted once to permille (pm, ×1000), parts per million
## (ppm, ×1e6) or basis points (bp, ×1e4). Rounding is "half away from zero", i.e. identical to `roundi` on the
## exact decimal value (and independent of float representation errors such as 10 × 1.15 = 11.4999…).

const PM: int = 1000
const PPM: int = 1000000
const BP: int = 10000


## x × 1000, rounded (1.5 → 1500).
static func pm(x: float) -> int:
	return roundi(x * 1000.0)


## x × 1 000 000, rounded (0.05 → 50000). Used for float-free snapshots (canonical JSON, 05 §3.3 Nr. 9).
static func ppm(x: float) -> int:
	return roundi(x * 1000000.0)


## Inverse of ppm().
static func from_ppm(v: int) -> float:
	return float(v) / 1000000.0


## Probability → basis points 0..10000.
static func bp(chance: float) -> int:
	return clampi(roundi(chance * 10000.0), 0, BP)


## num / den rounded half away from zero (den != 0).
static func div_round(num: int, den: int) -> int:
	if den == 0:
		return 0
	var n: int = num
	var d: int = den
	if d < 0:
		n = -n
		d = -d
	if n >= 0:
		return (n + d / 2) / d
	return -((-n + d / 2) / d)


## num / den rounded up (num >= 0, den > 0).
static func div_ceil(num: int, den: int) -> int:
	if den <= 0:
		return 0
	return (num + den - 1) / den


## v × f_pm / 1000, rounded.
static func mul_pm(v: int, f_pm: int) -> int:
	return div_round(v * f_pm, PM)


## Bernoulli draw with an integer threshold: no draw at all for 0 / 10000 (deterministic either way).
static func roll_bp(rng: RandomNumberGenerator, chance_bp: int) -> bool:
	if chance_bp <= 0:
		return false
	if chance_bp >= BP:
		return true
	return rng.randi_range(0, BP - 1) < chance_bp


static func roll(rng: RandomNumberGenerator, chance: float) -> bool:
	return roll_bp(rng, bp(chance))


## num / den < f (den > 0), exact integer comparison.
static func ratio_below(num: int, den: int, f: float) -> bool:
	if den <= 0:
		return false
	return num * PPM < ppm(f) * den


## num / den > f (den > 0), exact integer comparison.
static func ratio_above(num: int, den: int, f: float) -> bool:
	if den <= 0:
		return false
	return num * PPM > ppm(f) * den


## Weighted pick (weights < 1 count as 1); -1 for an empty list. One draw.
static func weighted_index(rng: RandomNumberGenerator, weights: Array[int]) -> int:
	if weights.is_empty():
		return -1
	var total: int = 0
	for w: int in weights:
		total += maxi(1, w)
	var r: int = rng.randi_range(0, total - 1)
	for i in weights.size():
		r -= maxi(1, weights[i])
		if r < 0:
			return i
	return weights.size() - 1
