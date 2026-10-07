# STUB(M0) — owned by M8. Replace completely, keep the public API.
class_name Gift extends RefCounted
## Gift schema (05 §6.5): validate, make_system, make_dev.


## Reason codes 05 §6.5, "" = valid.
static func validate(g: Dictionary) -> String:
	return ""


static func make_system(sponsor_id: String, battle_n: int, k: int) -> Dictionary:
	return {}


static func make_dev(kind: String, tier: String, amount: int) -> Dictionary:
	return {}
