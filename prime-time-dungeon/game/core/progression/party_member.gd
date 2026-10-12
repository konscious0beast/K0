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
# --- Echtzeitkampf (07, R1a): written by to_dict only when they differ from the default (07 §10.4) ------------------
var rt_preset: String = ""             # partner tactic (RtVocab.RT_PRESETS; "" = party.json rt.default_preset)
var rt_toggles: Dictionary = {}        # partner switches {interrupt, show, potions} → bool ({} = RtVocab defaults)
var rt_loadout: Dictionary = {}        # action bar variants: "2".."4" → skill id ({} = the base abilities, §4.1)
# --- Staffeln (09, ST0): written by to_dict only when they differ from the default (09 §9.1) -------------------------
var rested: int = 0                    # Ausgeruht: the bonus EP pool (09 §8.2, §5.2)
var professions: Dictionary = {}       # prf id → value 1–300 (09 §8.5; only the candidate kai learns professions)
var prof_head: String = ""             # the profession with the +50 head start (09 §8.6: persona v2 or "prof" head)
var talent_rows: Dictionary = {}       # talent tree: row (level "3", "5", …) → talent id (09 §8.4, "talent" v2)


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
	}.merged(_b_dict()).merged(_rt_dict()).merged(_season_dict())


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
	_rt_from_dict(m, d)                    # Echtzeitkampf (07, R1a)
	_season_from_dict(m, d)                # Staffeln (09, ST0)
	return m


# --- Echtzeitkampf (07, R1a) ------------------------------------------------------------------------------------------

## The real-time fields, only when set (see the field comments).
func _rt_dict() -> Dictionary:
	var out: Dictionary = {}
	if rt_preset != "":
		out["rt_preset"] = rt_preset
	if not rt_toggles.is_empty():
		var t: Dictionary = {}
		var keys: Array = rt_toggles.keys()
		keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
		for k: Variant in keys:
			t[str(k)] = bool(rt_toggles[k])
		out["rt_toggles"] = t
	if not rt_loadout.is_empty():
		var l: Dictionary = {}
		var lkeys: Array = rt_loadout.keys()
		lkeys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
		for k: Variant in lkeys:
			l[str(k)] = str(rt_loadout[k])
		out["rt_loadout"] = l
	return out


static func _rt_from_dict(m: PartyMember, d: Dictionary) -> void:
	m.rt_preset = str(d.get("rt_preset", ""))
	var raw_t: Variant = d.get("rt_toggles", {})
	if raw_t is Dictionary:
		for k: Variant in (raw_t as Dictionary).keys():
			if (raw_t as Dictionary)[k] is bool:
				m.rt_toggles[str(k)] = bool((raw_t as Dictionary)[k])
	var raw_l: Variant = d.get("rt_loadout", {})
	if raw_l is Dictionary:
		for k: Variant in (raw_l as Dictionary).keys():
			m.rt_loadout[str(k)] = str((raw_l as Dictionary)[k])


# --- Staffeln (09, ST0) -----------------------------------------------------------------------------------------------

## The season fields, only when set (see the field comments).
func _season_dict() -> Dictionary:
	var out: Dictionary = {}
	if rested != 0:
		out["rested"] = rested
	if not professions.is_empty():
		var p: Dictionary = {}
		var keys: Array = professions.keys()
		keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
		for k: Variant in keys:
			p[str(k)] = int(professions[k])
		out["professions"] = p
	if prof_head != "":
		out["prof_head"] = prof_head
	if not talent_rows.is_empty():
		var r: Dictionary = {}
		var rkeys: Array = talent_rows.keys()
		rkeys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
		for k: Variant in rkeys:
			r[str(k)] = str(talent_rows[k])
		out["talent_rows"] = r
	return out


static func _season_from_dict(m: PartyMember, d: Dictionary) -> void:
	m.rested = maxi(0, JsonUtil.to_int(d.get("rested", 0)))
	var raw_p: Variant = d.get("professions", {})
	if raw_p is Dictionary:
		for k: Variant in (raw_p as Dictionary).keys():
			if str(k) != "":
				m.professions[str(k)] = JsonUtil.to_int((raw_p as Dictionary)[k])
	m.prof_head = str(d.get("prof_head", ""))
	var raw_r: Variant = d.get("talent_rows", {})
	if raw_r is Dictionary:
		for k: Variant in (raw_r as Dictionary).keys():
			if str(k) != "" and str((raw_r as Dictionary)[k]) != "":
				m.talent_rows[str(k)] = str((raw_r as Dictionary)[k])
