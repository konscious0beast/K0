# STUB(M0) — owned by M2. Replace completely, keep the public API.
class_name BattleBridge extends RefCounted
## GameState ↔ BattleSetup/BattleResult (02_TECH §6.1).


static func make_setup(state: GameState, data: GameData, encounter_id: String, advantage: int, group_id: String,
		seed: int) -> BattleSetup:
	return null


static func apply_result(state: GameState, data: GameData, result: BattleResult) -> BattleRewards:
	return null
