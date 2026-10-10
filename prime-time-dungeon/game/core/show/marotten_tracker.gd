class_name MarottenTracker extends RefCounted
## Per-battle tally for M.O.D.'s preferences (06 §4.6, package C): ONLY counts what the BattleResult does not carry,
## from the ActionEvent stream of the running battle. One instance per battle, held by Show next to its ShowRules
## (the volatile battle context — battles are never saved, and Game.replay_log feeds the same events again, so the
## tally is identical live and in the replay). MarottenRules.battle_context merges it with the BattleResult.
##
## Counted: distinct party action keys (attack, skill id, item id, stunt, defend, flee — like ShowRules), defends,
## flee attempts, successful stunts and the party member that landed the last enemy KO ("" = a status tick or nobody).

var liga_tier: int = 0                     # Liga tier frozen at battle start (MarottenRules.liga_tier)
var tutorial: bool = false                 # tutorial battles never count for preferences or the Liga
var gifts: int = 0                         # gifts delivered in this battle (set by Show at the end)

var _members: Dictionary = {}              # party combatant id → member def id
var _keys: Dictionary = {}                 # distinct party action keys
var _defends: int = 0
var _flee_attempts: int = 0
var _stunts_success: int = 0
var _last_kill_member: String = ""


## Starts the tally of a battle: combatant ids of the party → member ids, Liga tier and tutorial flag.
func begin(setup: BattleSetup, p_liga_tier: int) -> void:
	_members = {}
	_keys = {}
	_defends = 0
	_flee_attempts = 0
	_stunts_success = 0
	_last_kill_member = ""
	gifts = 0
	liga_tier = p_liga_tier
	tutorial = setup != null and setup.tutorial
	if setup == null:
		return
	for c: Combatant in setup.party:
		if c != null and c.id != "":
			_members[c.id] = c.def_id


func on_battle_event(e: ActionEvent) -> void:
	if e == null:
		return
	match e.type:
		ActionEvent.Type.ACTION_START:
			if e.actor_id.begins_with("p"):
				_keys[action_key(e)] = true
				if e.command == BattleCommand.Kind.DEFEND:
					_defends += 1
		ActionEvent.Type.FLEE_RESULT:
			if e.actor_id.begins_with("p"):
				_flee_attempts += 1
		ActionEvent.Type.STUNT_RESULT:
			if e.actor_id.begins_with("p") and e.success:
				_stunts_success += 1
		ActionEvent.Type.KO:
			if e.target_id.begins_with("e"):
				_last_kill_member = str(_members.get(e.actor_id, ""))


## {"distinct_actions", "defends", "flee_attempts", "stunts_success", "last_kill_member", "gifts", "liga_tier",
## "tutorial"} — the tally part of MarottenRules.battle_context.
func tally() -> Dictionary:
	return {"distinct_actions": _keys.size(), "defends": _defends, "flee_attempts": _flee_attempts,
		"stunts_success": _stunts_success, "last_kill_member": _last_kill_member, "gifts": gifts,
		"liga_tier": liga_tier, "tutorial": tutorial}


## Party action key of an ACTION_START (same vocabulary as ShowRules: attack, skill id, item id, stunt, defend, flee).
static func action_key(e: ActionEvent) -> String:
	match e.command:
		BattleCommand.Kind.ATTACK:
			return "attack"
		BattleCommand.Kind.SKILL:
			return e.skill_id if e.skill_id != "" else "skill"
		BattleCommand.Kind.STUNT:
			return "stunt"
		BattleCommand.Kind.ITEM:
			return e.item_id if e.item_id != "" else "item"
		BattleCommand.Kind.DEFEND:
			return "defend"
		BattleCommand.Kind.FLEE:
			return "flee"
	return e.skill_id if e.skill_id != "" else "attack"
