# STUB(M0) — owned by M1. Replace completely, keep the public API.
class_name ActionEvent extends RefCounted
## Result event for presentation (02_TECH §5.3, exact structure).

enum Type {
	BATTLE_START,    # value = advantage; target_ids = all combatant ids (party first)
	TURN_START,      # actor_id
	ACTION_START,    # actor_id, command, skill_id, item_id, target_ids, text = display name of skill/item/command
	COMBO,           # actor_id (2nd actor), target_id; damage of this action × Balance.COMBO_MULT
	DAMAGE,          # actor_id ("" for status tick), target_id, amount (>= 0; 0 only if immune), hp_after, element, crit, weak,
	                 # resist, immune, beat, status_id (set if caused by a status tick), skill_id
	HEAL,            # actor_id, target_id, amount (>0), hp_after, beat, status_id (tick), skill_id
	MP_CHANGE,       # target_id, amount (+/-), mp_after, beat
	STATUS_ADDED,    # target_id, status_id, value = turns, beat
	STATUS_REMOVED,  # target_id, status_id (expired, cleansed, replaced via excludes)
	STATUS_BLOCKED,  # target_id, status_id (immune, element-immune, resisted roll, stun already active)
	DEFEND,          # actor_id
	KO,              # target_id, def_id, max_hp, actor_id (killer, "" for status), skill_id, amount = killing damage,
	                 # value = 1 if overkill (damage >= hp_before + max_hp * 0.5) else 0
	REVIVE,          # target_id, hp_after, max_hp
	SUMMON,          # actor_id, target_id = new combatant id, def_id = enemy/pseudo def id, value = slot
	PSEUDO_REMOVED,  # target_id (pseudo unit leaves the CTB order)
	ESCAPED,         # actor_id (enemy leaves the battle, no rewards for it)
	CREDITS_STOLEN,  # actor_id, value = amount (refunded on VICTORY if refund_on_win)
	CREDITS_GAINED,  # value = amount (gift; applied after battle via BattleResult.credits_delta)
	STUNT_RESULT,    # actor_id, skill_id, success
	FLEE_RESULT,     # actor_id, success
	ITEM_GAINED,     # item_id, value = count (gift)
	SPONSOR_GIFT,    # sponsor_id, text = sponsor name
	PHASE_CHANGE,    # actor_id (boss), value = new phase index (1-based)
	MOD_LINE,        # text = M.O.D. tag (boss_intro:…, boss_phase:…, warn_tag); Show.say(text)
	ANNOUNCE,        # text (display, e.g. "Präventivschlag!", "Hinterhalt!")
	CTB_ORDER,       # order = next PREVIEW_LENGTH (12) combatant ids (index 0 = next actor)
	TURN_END,        # actor_id
	BATTLE_END,      # value = BattleResult.Outcome
}

var type: ActionEvent.Type = Type.BATTLE_START
var actor_id: String = ""
var target_id: String = ""
var target_ids: PackedStringArray = []
var skill_id: String = ""
var item_id: String = ""
var status_id: String = ""
var sponsor_id: String = ""
var def_id: String = ""          # def id of target_id (KO, SUMMON; set on every event that has a target_id)
var command: int = -1            # BattleCommand.Kind or -1
var amount: int = 0
var max_hp: int = -1             # target's max HP (DAMAGE, HEAL, KO, REVIVE)
var hp_after: int = -1
var mp_after: int = -1
var element: String = ""
var beat: int = 0                # events of one action with the same beat play simultaneously (0 = first hit)
var crit: bool = false
var weak: bool = false
var resist: bool = false
var immune: bool = false
var success: bool = false
var value: int = 0
var order: PackedStringArray = []
var text: String = ""            # ANNOUNCE/ACTION_START: German display text; MOD_LINE: tag


static func make(t: ActionEvent.Type) -> ActionEvent:
	return null


## Only non-default fields + "type" as String name.
func to_dict() -> Dictionary:
	return {}


## Inverse of to_dict (unknown type → push_error, null); Brief §6b.2.
static func from_dict(d: Dictionary) -> ActionEvent:
	return null
