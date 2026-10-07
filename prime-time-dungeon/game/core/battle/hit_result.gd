# STUB(M0) — owned by M1. Replace completely, keep the public API.
class_name HitResult extends RefCounted
## Result of one damage/heal calculation (02_TECH §5.4).

var amount: int = 0          # >= 0
var crit: bool = false
var weak: bool = false
var resist: bool = false
var immune: bool = false
