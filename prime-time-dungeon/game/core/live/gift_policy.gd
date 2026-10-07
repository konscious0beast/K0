# STUB(M0) — owned by M8. Replace completely, keep the public API.
class_name GiftPolicy extends RefCounted
## Caps and effect factors, integers only (05 §6.10).


static func effect_pm(load_half: int, k_pm: int = 75) -> int:
	return 1000


static func load_weight_half(g: Dictionary, weights_half: Dictionary) -> int:
	return 0


static func rolls_for(base_rolls: int, effect_pm: int) -> int:
	return base_rolls


## (value * effect_pm + 500) / 1000
static func scale(value: int, effect_pm: int) -> int:
	return value


static func chest_allowed(load_half: int, rules: Dictionary) -> bool:
	return false


## run = gift counters of the run (GameState.flags["live"]); "" = allowed.
static func check(run: Dictionary, g: Dictionary, rules: Dictionary) -> String:
	return ""
