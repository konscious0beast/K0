# STUB(M0) — owned by M1. Replace completely, keep the public API.
class_name Elements extends RefCounted
## Element constants and multiplier helpers (02_TECH §5.2).

const NONE: String = "none"
const PHYSICAL: String = "physical"
const FIRE: String = "fire"
const ICE: String = "ice"
const SHOCK: String = "shock"
const POISON: String = "poison"
const ALL: PackedStringArray = ["none", "physical", "fire", "ice", "shock", "poison"]   # == DataValidator.ELEMENTS


## "none" → 1.0; else mods.get(element, 1.0).
static func multiplier(mods: Dictionary, element: String) -> float:
	return 1.0


## 1.5+ &"weak", 1.0 &"normal", 0<x<1 &"resist", 0 &"immune".
static func affinity(mult: float) -> StringName:
	return &"normal"
