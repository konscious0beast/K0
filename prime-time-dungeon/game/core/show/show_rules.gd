# STUB(M0) — owned by M2. Replace completely, keep the public API.
class_name ShowRules extends RefCounted
## ActionEvent → ShowDelta per battle (02_TECH §6.1/§6.2).


## Self-contained: needs only ActionEvent fields + setup.
func _init(p_data: GameData, p_setup: BattleSetup) -> void:
	pass


## Battle start hype (§6.2).
func start_delta() -> ShowDelta:
	return null


func feed(e: ActionEvent) -> ShowDelta:
	return null


## Close win / flawless.
func end_delta(result: BattleResult) -> ShowDelta:
	return null


func stunts_succeeded() -> int:
	return 0
