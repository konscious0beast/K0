class_name PartyMember extends RefCounted
## Runtime party member (02_TECH §6.1). Stats are not stored: Progression.total_stats derives them from the
## PartyMemberDef, level, class, species, talents and equipment.
## 06 package B (Talent-Show / Casting): `talents`, `species_id` and `casting` are written by to_dict only when set, so
## states without them (every save and run log before the feature) keep their exact JSON and StateHash; missing fields
## load as defaults (no save version bump). Open talent choices are derived (Talents.pending_levels), never stored.

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
# --- 06 package B ---------------------------------------------------------------------------------------------------
var talents: Dictionary = {}           # talent id → rank (1..max_rank); Game.pick_talent / Talents.pick
var species_id: String = ""            # "" = not cast yet (≙ spc_original); Game.choose_casting / Casting.choose
var casting: Dictionary = {}           # Casting bookkeeping: {"floor", "visit", "class_floor", "class_visit"} (ints)


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
	}.merged(_b_dict())


## 06 package B fields, only when set (see header).
func _b_dict() -> Dictionary:
	var out: Dictionary = {}
	if not talents.is_empty():
		var t: Dictionary = {}
		var keys: Array = talents.keys()
		keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
		for k: Variant in keys:
			t[str(k)] = int(talents[k])
		out["talents"] = t
	if species_id != "":
		out["species_id"] = species_id
	if not casting.is_empty():
		var c: Dictionary = {}
		for k: String in ["class_floor", "class_visit", "floor", "visit"]:
			if casting.has(k):
				c[k] = int(casting[k])
		out["casting"] = c
	return out


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
	var raw_t: Variant = d.get("talents", {})
	if raw_t is Dictionary:
		for k: Variant in (raw_t as Dictionary).keys():
			var rank: int = JsonUtil.to_int((raw_t as Dictionary)[k])
			if str(k) != "" and rank > 0:
				m.talents[str(k)] = rank
	m.species_id = str(d.get("species_id", ""))
	var raw_c: Variant = d.get("casting", {})
	if raw_c is Dictionary:
		for k: String in ["class_floor", "class_visit", "floor", "visit"]:
			if (raw_c as Dictionary).has(k):
				m.casting[k] = JsonUtil.to_int((raw_c as Dictionary)[k])
	return m
