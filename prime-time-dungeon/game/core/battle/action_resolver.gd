# STUB(M0) — owned by M1. Replace completely, keep the public API.
class_name ActionResolver extends RefCounted
## Applies commands and produces ActionEvents (02_TECH §5.8).


## Validated cmd, no TURN_END.
static func resolve(state: BattleState, cmd: BattleCommand) -> Array[ActionEvent]:
	return []


static func apply_skill(state: BattleState, actor: Combatant, skill: SkillDef, target_ids: PackedStringArray,
		out: Array[ActionEvent]) -> void:
	pass


static func apply_status(state: BattleState, target: Combatant, status_id: String, turns: int, source_id: String,
		chance: float, beat: int, out: Array[ActionEvent], ignore_resist: bool = false) -> void:
	pass


## Defend reset, stun removal, turn_start ticks.
static func turn_start(state: BattleState, actor: Combatant, out: Array[ActionEvent]) -> void:
	pass


## turn_end ticks, durations, cooldown.
static func end_of_turn(state: BattleState, actor: Combatant, out: Array[ActionEvent]) -> void:
	pass


static func check_phase(state: BattleState, boss: Combatant, out: Array[ActionEvent]) -> void:
	pass


static func pseudo_turn(state: BattleState, unit: Combatant, out: Array[ActionEvent]) -> void:
	pass
