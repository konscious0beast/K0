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
var hp_scale_pm: int = 1000            # HP scale, last step of Progression.total_stats (CTB 1000, real-time 4000)
var rt_preset: String = ""             # partner tactic (RtVocab.RT_PRESETS; "" = party.json rt.default_preset)
var rt_toggles: Dictionary = {}        # partner switches {interrupt, show, potions} → bool ({} = RtVocab defaults)
var rt_loadout: Dictionary = {}        # action bar variants: "2".."4" → skill id ({} = the base abilities, §4.1)
# --- Casting (08, K0) -------------------------------------------------------------------------------------------------
## Start talent of the persona (08 §2.4, only kai; "" = none: old saves, event runs): PersonaRules.apply sets it, the
## Talents queries add its effects (rank 1) from level 1 (Talents.has_any). Written by to_dict only when set.
var origin_talent: String = ""


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
	}.merged(_b_dict()).merged(_rt_dict()).merged({"origin_talent": origin_talent} if origin_talent != "" else {})


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
	m.origin_talent = str(d.get("origin_talent", ""))   # Casting (08, K0)
	return m


# --- Echtzeitkampf (07, R1a) ------------------------------------------------------------------------------------------

## The real-time fields, only when set (see the field comments).
func _rt_dict() -> Dictionary:
	var out: Dictionary = {}
	if hp_scale_pm != 1000:
		out["hp_scale_pm"] = hp_scale_pm
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
	m.hp_scale_pm = maxi(1, JsonUtil.to_int(d.get("hp_scale_pm", 1000), 1000))
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
