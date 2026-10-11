class_name Elements extends RefCounted
## Element constants and multiplier helpers (02_TECH §5.2, GDD §3.8).

const FixedMath := preload("res://core/stats/fixed_math.gd")

const NONE: String = "none"
const PHYSICAL: String = "physical"
const FIRE: String = "fire"
const ICE: String = "ice"
const SHOCK: String = "shock"
const POISON: String = "poison"
const ALL: PackedStringArray = ["none", "physical", "fire", "ice", "shock", "poison"]   # == DataValidator.ELEMENTS

const WEAK_MULT: float = 1.5
const RESIST_MULT: float = 0.5
const IMMUNE_MULT: float = 0.0


## "none" → 1.0; else mods.get(element, 1.0) (negative values count as 0.0, no absorption in the slice).
static func multiplier(mods: Dictionary, element: String) -> float:
	if element == NONE or element == "":
		return 1.0
	if not mods.has(element):
		return 1.0
	return maxf(0.0, float(mods[element]))


## multiplier() in permille (1.5 → 1500) for the integer damage formula.
static func multiplier_pm(mods: Dictionary, element: String) -> int:
	return FixedMath.pm(multiplier(mods, element))


## 1.5+ &"weak", 1.0 &"normal", 0<x<1 &"resist", 0 &"immune" (values between 1.0 and 1.5 count as normal).
static func affinity(mult: float) -> StringName:
	var m: int = FixedMath.pm(mult)
	if m <= 0:
		return &"immune"
	if m >= FixedMath.pm(WEAK_MULT):
		return &"weak"
	if m < FixedMath.PM:
		return &"resist"
	return &"normal"
