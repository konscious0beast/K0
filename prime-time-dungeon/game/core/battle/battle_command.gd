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
	var targets: PackedStringArray = []
	if target_id != "":
		targets.append(target_id)
	return _make(Kind.ATTACK, actor_id, "", "", targets)


static func skill(actor_id: String, skill_id: String, target_ids: PackedStringArray) -> BattleCommand:
	return _make(Kind.SKILL, actor_id, skill_id, "", target_ids)


static func stunt(actor_id: String, skill_id: String, target_ids: PackedStringArray) -> BattleCommand:
	return _make(Kind.STUNT, actor_id, skill_id, "", target_ids)


static func item(actor_id: String, item_id: String, target_ids: PackedStringArray) -> BattleCommand:
	return _make(Kind.ITEM, actor_id, "", item_id, target_ids)


static func defend(actor_id: String) -> BattleCommand:
	return _make(Kind.DEFEND, actor_id, "", "", PackedStringArray())


static func flee(actor_id: String) -> BattleCommand:
	return _make(Kind.FLEE, actor_id, "", "", PackedStringArray())


## {"kind": "skill", "actor": "p0", "skill": "skl_…", "item": "", "targets": ["e1"]} — Brief §6b.2
func to_dict() -> Dictionary:
	return {"kind": KIND_NAMES[int(kind)], "actor": actor_id, "skill": skill_id, "item": item_id,
		"targets": Array(target_ids)}


## Unknown kind / missing actor → null.
static func from_dict(d: Dictionary) -> BattleCommand:
	var k: int = KIND_NAMES.find(str(d.get("kind", "")))
	var actor: String = str(d.get("actor", ""))
	if k < 0 or actor == "":
		return null
	return _make(k as BattleCommand.Kind, actor, str(d.get("skill", "")), str(d.get("item", "")),
			JsonUtil.to_str_array(d.get("targets", [])))


func kind_name() -> String:
	return KIND_NAMES[int(kind)]


static func _make(p_kind: BattleCommand.Kind, p_actor: String, p_skill: String, p_item: String,
		p_targets: PackedStringArray) -> BattleCommand:
	var c: BattleCommand = BattleCommand.new()
	c.kind = p_kind
	c.actor_id = p_actor
	c.skill_id = p_skill
	c.item_id = p_item
	c.target_ids = p_targets.duplicate()
	return c
