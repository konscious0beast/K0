# STUB(M0) — owned by M1. Replace completely, keep the public API.
class_name BattleCommand extends RefCounted
## Command of one actor (02_TECH §5.4). Serializable (Brief §6b.2).

enum Kind { ATTACK, SKILL, STUNT, ITEM, DEFEND, FLEE }
const KIND_NAMES: PackedStringArray = ["attack", "skill", "stunt", "item", "defend", "flee"]

var kind: BattleCommand.Kind = Kind.ATTACK
var actor_id: String = ""
var skill_id: String = ""
var item_id: String = ""
var target_ids: PackedStringArray = []


static func attack(actor_id: String, target_id: String) -> BattleCommand:
	return null


static func skill(actor_id: String, skill_id: String, target_ids: PackedStringArray) -> BattleCommand:
	return null


static func stunt(actor_id: String, skill_id: String, target_ids: PackedStringArray) -> BattleCommand:
	return null


static func item(actor_id: String, item_id: String, target_ids: PackedStringArray) -> BattleCommand:
	return null


static func defend(actor_id: String) -> BattleCommand:
	return null


static func flee(actor_id: String) -> BattleCommand:
	return null


## {"kind": "skill", "actor": "p0", "skill": "skl_…", "item": "", "targets": ["e1"]} — Brief §6b.2
func to_dict() -> Dictionary:
	return {}


## Unknown kind / missing actor → null.
static func from_dict(d: Dictionary) -> BattleCommand:
	return null
