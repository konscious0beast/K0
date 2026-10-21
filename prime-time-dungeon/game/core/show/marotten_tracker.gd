class_name MarottenTracker extends RefCounted
## Per-battle tally for M.O.D.'s preferences (06 §4.6, package C): ONLY counts what the BattleResult does not carry,
## from the ActionEvent stream of the running combat. One instance per combat, held by Show next to its ShowRules
## (the volatile battle context — combats are never saved, and Game.replay_log feeds the same events again, so the
## tally is identical live and in the replay). MarottenRules.battle_context merges it with the BattleResult.
##
## Echtzeitkampf (07 §9.6, R5a; the only combat since R5b part 2b — the CTB tally of attack / defend / flee keys left
## with the CTB battle, 10 SD1): the stream counts the person's actions only (by_ai == false: distinct skill / item
## ids, own SHOW successes); defends do not exist (0), flee attempts come from the BattleResult
## (MarottenRules.battle_context), the last kill names the member whose hit, status or zone landed it (the AI partner
## too; train kills "").

var liga_tier: int = 0                     # Liga tier frozen at battle start (MarottenRules.liga_tier)
var tutorial: bool = false                 # tutorial battles never count for preferences or the Liga
var gifts: int = 0                         # gifts delivered in this battle (set by Show at the end)

var _members: Dictionary = {}              # party unit id → member def id
var _keys: Dictionary = {}                 # distinct own skill / item ids
var _stunts_success: int = 0
var _last_kill_member: String = ""


## Starts the tally of a combat: unit ids of the party (BattleSetup.party — the party RtUnits of an RtSetup) → member
## ids, Liga tier and tutorial flag.
func begin(setup: BattleSetup, p_liga_tier: int) -> void:
	_members = {}
	_keys = {}
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


## The real-time stream: the person's ACTION_START (by_ai false) → distinct skill / item ids (auto-attacks have none);
## their successful SHOW / FINALE; the member behind the last enemy KO (a party actor — controlled or AI partner — or
## "" for an enemy actor: the train).
func on_battle_event(e: ActionEvent) -> void:
	if e == null:
		return
	match e.type:
		ActionEvent.Type.ACTION_START:
			if e.actor_id.begins_with("p") and not e.by_ai:
				_keys[e.item_id if e.command == BattleCommand.Kind.ITEM and e.item_id != "" else e.skill_id] = true
		ActionEvent.Type.STUNT_RESULT:
			if e.actor_id.begins_with("p") and e.success and not e.by_ai:
				_stunts_success += 1
		ActionEvent.Type.KO:
			if e.target_id.begins_with("e"):
				_last_kill_member = str(_members.get(e.actor_id, ""))


## {"distinct_actions", "defends" (0), "flee_attempts" (0: the result counts them), "stunts_success",
## "last_kill_member", "gifts", "liga_tier", "tutorial"} — the tally part of MarottenRules.battle_context.
func tally() -> Dictionary:
	return {"distinct_actions": _keys.size(), "defends": 0, "flee_attempts": 0, "stunts_success": _stunts_success,
		"last_kill_member": _last_kill_member, "gifts": gifts, "liga_tier": liga_tier, "tutorial": tutorial}
