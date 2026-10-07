# STUB(M0) — owned by M2. Replace completely, keep the public API.
class_name PartyMember extends RefCounted
## Runtime party member (02_TECH §6.1).

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
	return {}


static func from_dict(d: Dictionary) -> PartyMember:
	return null
