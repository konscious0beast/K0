class_name ActionEvent extends RefCounted
## Result event for presentation (02_TECH §5.3, exact structure). Serializable (Brief §6b.2).
## Side of an id: "p…" party, "e…" enemy, "u…" pseudo unit. hp_after/mp_after are snapshots after the event.
## Extra (non-default) fields the core also sets: KO.command (command of the killing action, -1 for status ticks,
## pseudo units and phase ops) and KO.item_id (the used item for ITEM kills; skill_id is then its use_skill) so
## ShowRules can tell kills by attack/skill/stunt/item apart.

enum Type {
	BATTLE_START,    # value = advantage; target_ids = all combatant ids (party first)
	TURN_START,      # actor_id
	ACTION_START,    # actor_id, command, skill_id, item_id, target_ids, text = display name of skill/item/command
	COMBO,           # actor_id (2nd actor), target_id; damage of this action × Balance.COMBO_MULT
	DAMAGE,          # actor_id ("" for status tick), target_id, amount (>= 0; 0 only if immune), hp_after, element,
	                 # crit, weak, resist, immune, beat, status_id (set if caused by a status tick), skill_id
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
	var e: ActionEvent = ActionEvent.new()
	e.type = t
	return e


## Name of the event type ("DAMAGE").
static func type_name(t: ActionEvent.Type) -> String:
	var names: Array = Type.keys()
	var i: int = int(t)
	return str(names[i]) if i >= 0 and i < names.size() else ""


## Only non-default fields + "type" as String name.
func to_dict() -> Dictionary:
	var d: Dictionary = {"type": type_name(type)}
	if actor_id != "":
		d["actor_id"] = actor_id
	if target_id != "":
		d["target_id"] = target_id
	if not target_ids.is_empty():
		d["target_ids"] = Array(target_ids)
	if skill_id != "":
		d["skill_id"] = skill_id
	if item_id != "":
		d["item_id"] = item_id
	if status_id != "":
		d["status_id"] = status_id
	if sponsor_id != "":
		d["sponsor_id"] = sponsor_id
	if def_id != "":
		d["def_id"] = def_id
	if command != -1:
		d["command"] = command
	if amount != 0:
		d["amount"] = amount
	if max_hp != -1:
		d["max_hp"] = max_hp
	if hp_after != -1:
		d["hp_after"] = hp_after
	if mp_after != -1:
		d["mp_after"] = mp_after
	if element != "":
		d["element"] = element
	if beat != 0:
		d["beat"] = beat
	if crit:
		d["crit"] = true
	if weak:
		d["weak"] = true
	if resist:
		d["resist"] = true
	if immune:
		d["immune"] = true
	if success:
		d["success"] = true
	if value != 0:
		d["value"] = value
	if not order.is_empty():
		d["order"] = Array(order)
	if text != "":
		d["text"] = text
	return d


## Inverse of to_dict (unknown type → push_error, null); Brief §6b.2. Accepts JSON floats for ints.
static func from_dict(d: Dictionary) -> ActionEvent:
	var tname: String = str(d.get("type", ""))
	var idx: int = Type.keys().find(tname)
	if idx < 0:
		push_error("ActionEvent.from_dict: unknown type '%s'" % tname)
		return null
	var e: ActionEvent = ActionEvent.make(idx as ActionEvent.Type)
	e.actor_id = str(d.get("actor_id", ""))
	e.target_id = str(d.get("target_id", ""))
	e.target_ids = JsonUtil.to_str_array(d.get("target_ids", []))
	e.skill_id = str(d.get("skill_id", ""))
	e.item_id = str(d.get("item_id", ""))
	e.status_id = str(d.get("status_id", ""))
	e.sponsor_id = str(d.get("sponsor_id", ""))
	e.def_id = str(d.get("def_id", ""))
	e.command = JsonUtil.to_int(d.get("command", -1), -1)
	e.amount = JsonUtil.to_int(d.get("amount", 0))
	e.max_hp = JsonUtil.to_int(d.get("max_hp", -1), -1)
	e.hp_after = JsonUtil.to_int(d.get("hp_after", -1), -1)
	e.mp_after = JsonUtil.to_int(d.get("mp_after", -1), -1)
	e.element = str(d.get("element", ""))
	e.beat = JsonUtil.to_int(d.get("beat", 0))
	e.crit = bool(d.get("crit", false))
	e.weak = bool(d.get("weak", false))
	e.resist = bool(d.get("resist", false))
	e.immune = bool(d.get("immune", false))
	e.success = bool(d.get("success", false))
	e.value = JsonUtil.to_int(d.get("value", 0))
	e.order = JsonUtil.to_str_array(d.get("order", []))
	e.text = str(d.get("text", ""))
	return e
