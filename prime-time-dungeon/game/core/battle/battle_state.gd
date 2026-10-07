# STUB(M0) — owned by M1. Replace completely, keep the public API.
class_name BattleState extends RefCounted
## Battle model + state machine (02_TECH §5.1, §5.6).

enum Phase { SETUP, AWAIT_COMMAND, FINISHED }

var phase: BattleState.Phase = Phase.SETUP
var setup: BattleSetup = null
var data: GameData = null
var rng: RandomNumberGenerator = null       # resolution; reseeded per action (§5.1)
var ai_rng: RandomNumberGenerator = null    # EnemyAI only; reseeded per action
var action_n: int = 0
var combatants: Array[Combatant] = []       # party (p0..) then enemies (e0..), summons and pseudo units appended
var queue: CTBQueue = null
var items: Dictionary = {}                  # copy of setup.items, mutated by ITEM use / gifts
var turn_count: int = 0
var failed_flee_attempts: int = 0
var last_actor_side: int = -1               # Combatant.Side of the previous turn (pseudo counts as ENEMY)
var last_party_actor_id: String = ""        # combo detection
var last_party_target_id: String = ""       # "" if the previous party action was not a single-target damage action
var credits_stolen: int = 0
var result: BattleResult = null
var history: Array[ActionEvent] = []        # every event ever returned (debug/tests)


func _init(p_setup: BattleSetup, p_data: GameData) -> void:
	setup = p_setup
	data = p_data


## BATTLE_START, ANNOUNCE (preemptive/ambush), boss phase 1 on_enter ops, CTB_ORDER, TURN_START(first actor) [+ internal turns]
func start() -> Array[ActionEvent]:
	return []


func current_actor() -> Combatant:
	return null


func get_combatant(id: String) -> Combatant:
	return null


func party() -> Array[Combatant]:
	return []


## Without pseudo units.
func enemies() -> Array[Combatant]:
	return []


## Without pseudo units.
func living(side: Combatant.Side) -> Array[Combatant]:
	return []


## BattleCommand.Kind values in menu order.
func available_commands(actor: Combatant) -> Array[int]:
	return []


## MP sufficient, no no_magic flag for category magic/heal/buff/debuff.
func usable_skills(actor: Combatant) -> PackedStringArray:
	return PackedStringArray()


## count > 0, usable battle/both.
func usable_items() -> PackedStringArray:
	return PackedStringArray()


## Never pseudo units.
func valid_targets(actor: Combatant, skill_id: String) -> PackedStringArray:
	return PackedStringArray()


## Enemy: lowest hp; ally heal: lowest ratio.
func default_target(actor: Combatant, skill_id: String) -> String:
	return ""


func preview_order(count: int, hover_rank: int = -1, overrides: Dictionary = {}) -> PackedStringArray:
	return PackedStringArray()


func command_rank(cmd: BattleCommand) -> int:
	return 3


## "" valid, otherwise reason (English, for logs).
func validate(cmd: BattleCommand) -> String:
	return ""


## push_error + [] if invalid or not current actor.
func submit(cmd: BattleCommand) -> Array[ActionEvent]:
	return []


## Enemy → EnemyAI (ai_rng); party → AutoPolicy.
func choose_ai_command() -> BattleCommand:
	return null


## Only in AWAIT_COMMAND; does not consume a turn (05 CR-2).
func apply_gift(g: Dictionary) -> Array[ActionEvent]:
	return []


func is_finished() -> bool:
	return true


## Snapshot incl. CTB counters, statuses, items, action_n.
func to_dict() -> Dictionary:
	return {}
