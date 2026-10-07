# STUB(M0) — owned by M8. Replace completely, keep the public API.
class_name StateHash extends RefCounted
## SHA-256 over GameState / BattleState without display fields (05 §11.2, CR-14).


static func of(state: GameState) -> String:
	return ""


static func of_battle(state: BattleState) -> String:
	return ""
