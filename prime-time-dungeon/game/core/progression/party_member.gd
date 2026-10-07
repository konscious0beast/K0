class_name PartyMember extends RefCounted
## Runtime party member (02_TECH §6.1). Stats are not stored: Progression.total_stats derives them from the
## PartyMemberDef, level, class and equipment.

const _SLOTS: PackedStringArray = ["weapon", "armor", "accessory"]

var id: String = ""
var display_name: String = ""
var level: int = 1
var exp: int = 0                       # progress toward next level (0 at LEVEL_CAP)
var hp: int = 0
var mp: int = 0
var equipment: Dictionary = {"weapon": "", "armor": "", "accessory": ""}
var skills: PackedStringArray = []     # learned (learnset up to level)
var class_id: String = ""


func to_dict() -> Dictionary:
	var eq: Dictionary = {}
	for s: String in _SLOTS:
		eq[s] = str(equipment.get(s, ""))
	return {
		"id": id,
		"display_name": display_name,
		"level": level,
		"exp": exp,
		"hp": hp,
		"mp": mp,
		"equipment": eq,
		"skills": Array(skills),
		"class_id": class_id,
	}


## Missing fields → defaults; numbers converted with int() (JSON numbers are floats). null without an id.
static func from_dict(d: Dictionary) -> PartyMember:
	var mid: String = str(d.get("id", ""))
	if mid == "":
		return null
	var m: PartyMember = PartyMember.new()
	m.id = mid
	m.display_name = str(d.get("display_name", mid))
	m.level = maxi(1, JsonUtil.to_int(d.get("level", 1), 1))
	m.exp = maxi(0, JsonUtil.to_int(d.get("exp", 0)))
	m.hp = maxi(0, JsonUtil.to_int(d.get("hp", 0)))
	m.mp = maxi(0, JsonUtil.to_int(d.get("mp", 0)))
	var raw_eq: Variant = d.get("equipment", {})
	var eq: Dictionary = {"weapon": "", "armor": "", "accessory": ""}
	if raw_eq is Dictionary:
		for s: String in _SLOTS:
			eq[s] = str((raw_eq as Dictionary).get(s, ""))
	m.equipment = eq
	var learned: PackedStringArray = []
	for s: String in JsonUtil.to_str_array(d.get("skills", [])):
		if s != "" and not learned.has(s):
			learned.append(s)
	m.skills = learned
	m.class_id = str(d.get("class_id", ""))
	return m
