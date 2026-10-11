# STUB(R1a) — owned by R1b. Replace completely, keep the public API.
class_name RtCommand extends RefCounted
## Schema check and builders of the real-time combat commands (07 §10.1). Command.validate delegates every type in
## TYPES and the "rt" block of "encounter" here. All values are integers / Strings; positions room-local in cm; `u` is
## a unit id ("p0".."p3" party, "e<n>" enemy); `target` a unit id or "". The builders return exactly the recorded
## shapes. validate() is the static schema only (R1a ships it complete so that no malformed real-time command can be
## recorded); everything dynamic (GCD, MP, range, …) is RtSim.submit / step (07 §3.4 "Zwei Prüfstufen").

## Refusal reasons of RtSim.submit and ACTION_REFUSED.text (07 §3.4), fixed list.
const REASONS: PackedStringArray = ["schema", "past_tick", "finished", "unknown_unit", "not_controlled", "dead",
	"not_learned", "stunned", "casting", "drinking", "gcd", "cooldown", "mp", "range", "los", "target", "target_hp",
	"item_cd", "items_max", "no_item", "forbidden", "locked", "not_available", "grade_b"]
## Real-time command types (07 §10.1) — Command.TYPES lists them too.
const TYPES: PackedStringArray = ["ability_use", "target_change", "move_sample", "combat_item", "partner_preset",
	"partner_special", "auto_attack", "autopilot", "combat_hint", "move_input", "combat_speed", "move_batch"]
## Types that carry a combat tick "ct" (combat_speed and move_batch do not; a gift in combat carries one as well).
const CT_TYPES: PackedStringArray = ["ability_use", "target_change", "move_sample", "combat_item", "partner_preset",
	"partner_special", "auto_attack", "autopilot", "combat_hint", "move_input"]
const POS_MAX_CM: int = 2400
const VEL_MAX_MM: int = 400
const DIR_MAX: int = 127
const RT_BLOCK_VERSION: int = 1
const DIFFICULTIES: PackedStringArray = ["prime", "vorabend"]

static var _unit_re: RegEx = null


static func ability(ct: int, u: String, skill: String, target: String) -> Dictionary:
	return {"t": "ability_use", "ct": ct, "u": u, "skill": skill, "target": target}


static func target(ct: int, u: String, p_target: String) -> Dictionary:
	return {"t": "target_change", "ct": ct, "u": u, "target": p_target}


static func move(ct: int, u: String, x: int, z: int, vx: int, vz: int, yaw: int) -> Dictionary:
	return {"t": "move_sample", "ct": ct, "u": u, "p": [x, z, vx, vz, yaw]}


static func item(ct: int, u: String, p_item: String, p_target: String) -> Dictionary:
	return {"t": "combat_item", "ct": ct, "u": u, "item": p_item, "target": p_target}


static func preset(ct: int, u: String, p_preset: String, tog: Dictionary) -> Dictionary:
	return {"t": "partner_preset", "ct": ct, "u": u, "preset": p_preset, "tog": tog.duplicate()}


static func auto_attack(ct: int, u: String, on: bool) -> Dictionary:
	return {"t": "auto_attack", "ct": ct, "u": u, "on": on}


static func autopilot(ct: int, u: String, on: bool) -> Dictionary:
	return {"t": "autopilot", "ct": ct, "u": u, "on": on}


static func partner_special(ct: int, u: String) -> Dictionary:
	return {"t": "partner_special", "ct": ct, "u": u}


static func hint(ct: int, id: String) -> Dictionary:
	return {"t": "combat_hint", "ct": ct, "id": id}


static func speed(pm: int) -> Dictionary:
	return {"t": "combat_speed", "pm": pm}


## "" = valid, else a message (Command.validate prefixes "<t>: "). For "encounter" only the "rt" block is checked here
## (v = 1, cell, controlled unit, party poses, groups, presets, switches, opening action, difficulty).
static func validate(d: Dictionary) -> String:
	var t: String = str(d.get("t", ""))
	if t == "encounter":
		return _rt_block(d.get("rt", null))
	if not TYPES.has(t):
		return "unknown real-time command type '%s'" % t
	if CT_TYPES.has(t):
		var e: String = _int_range(d, "ct", 0, 1 << 30)
		if e != "":
			return e
	match t:
		"ability_use":
			return _first([_unit(d, "u"), _id(d, "skill"), _target(d, "target")])
		"target_change":
			return _first([_unit(d, "u"), _target(d, "target")])
		"move_sample":
			var e1: String = _unit(d, "u")
			if e1 != "":
				return e1
			return _ints(d.get("p", null), "p", [[-POS_MAX_CM, POS_MAX_CM], [-POS_MAX_CM, POS_MAX_CM],
				[-VEL_MAX_MM, VEL_MAX_MM], [-VEL_MAX_MM, VEL_MAX_MM], [0, 255]])
		"combat_item":
			return _first([_unit(d, "u"), _id(d, "item"), _target(d, "target")])
		"partner_preset":
			var e2: String = _unit(d, "u")
			if e2 != "":
				return e2
			if not RtVocab.RT_PRESETS.has(str(d.get("preset", ""))):
				return "preset must be one of %s" % ", ".join(RtVocab.RT_PRESETS)
			return _toggles(d.get("tog", null), "tog")
		"partner_special":
			return _unit(d, "u")
		"auto_attack", "autopilot":
			var e3: String = _unit(d, "u")
			if e3 != "":
				return e3
			return "" if d.get("on", null) is bool else "on must be a bool"
		"combat_hint":
			var hid: String = str(d.get("id", ""))
			if not (d.get("id", null) is String) or not (RtVocab.TUTORIAL_STEPS.has(hid) or RtVocab.HINT_IDS.has(hid)):
				return "id must be a tutorial step or hint id"
			return ""
		"move_input":
			var e4: String = _unit(d, "u")
			if e4 != "":
				return e4
			var e5: String = _ints(d.get("dir", null), "dir", [[-DIR_MAX, DIR_MAX], [-DIR_MAX, DIR_MAX]])
			if e5 != "":
				return e5
			return "" if d.get("run", null) is bool else "run must be a bool"
		"combat_speed":
			var pm: Variant = d.get("pm", null)
			if not _is_int(pm) or not RtVocab.COMBAT_SPEEDS.has(int(pm)):
				return "pm must be one of %s" % str(Array(RtVocab.COMBAT_SPEEDS))
			return ""
		"move_batch":
			var e6: String = _first([_unit(d, "u"), _int_range(d, "id0", 1, 1 << 30)])
			if e6 != "":
				return e6
			var s: Variant = d.get("s", null)
			if not (s is Array) or (s as Array).is_empty():
				return "s must be a non-empty array of samples"
			for row: Variant in (s as Array):
				var e7: String = _ints(row, "s[]", [[0, 1 << 30], [-POS_MAX_CM, POS_MAX_CM], [-POS_MAX_CM, POS_MAX_CM],
					[-VEL_MAX_MM, VEL_MAX_MM], [-VEL_MAX_MM, VEL_MAX_MM], [0, 255]])
				if e7 != "":
					return e7
			return ""
	return ""


## True for a command that belongs to a running real-time combat (a type with "ct", or a gift recorded with "ct").
static func is_combat_cmd(d: Dictionary) -> bool:
	var t: String = str(d.get("t", ""))
	return CT_TYPES.has(t) or t == "move_batch" or (t == "gift" and d.has("ct"))


# --- private --------------------------------------------------------------------------------------------------------

static func _rt_block(v: Variant) -> String:
	if not (v is Dictionary):
		return "rt must be a Dictionary"
	var rt: Dictionary = v
	if not _is_int(rt.get("v", null)) or int(rt["v"]) != RT_BLOCK_VERSION:
		return "rt.v must be %d" % RT_BLOCK_VERSION
	var e: String = _ints(rt.get("cell", null), "rt.cell", [[-999, 999], [-999, 999]])
	if e != "":
		return e
	if not _is_unit(rt.get("ctl", null), true):
		return "rt.ctl must be a party unit id"
	var party: Variant = rt.get("party", null)
	if not (party is Array) or (party as Array).is_empty() or (party as Array).size() > 4:
		return "rt.party must be an array of 1..4 poses"
	for p: Variant in (party as Array):
		if not (p is Dictionary) or not _is_unit((p as Dictionary).get("u", null), true):
			return "rt.party[].u must be a party unit id"
		var ep: String = _pose((p as Dictionary).get("p", null), "rt.party[].p")
		if ep != "":
			return ep
	var groups: Variant = rt.get("groups", null)
	if not (groups is Array):
		return "rt.groups must be an array"
	for g: Variant in (groups as Array):
		if not (g is Dictionary):
			return "rt.groups[] must be objects"
		var gd: Dictionary = g
		var eg: String = _first([_str(gd, "group"), _id(gd, "enc"), _id(gd, "state")])
		if eg != "":
			return "rt.groups[]." + eg
		var el: String = _pose(gd.get("lead", null), "rt.groups[].lead")
		if el != "":
			return el
	var presets: Variant = rt.get("presets", {})
	if not (presets is Dictionary):
		return "rt.presets must be a Dictionary"
	for k: Variant in (presets as Dictionary).keys():
		if not _is_unit(k, true):
			return "rt.presets keys must be party unit ids"
		var pv: Variant = (presets as Dictionary)[k]
		if not (pv is Dictionary) or not RtVocab.RT_PRESETS.has(str((pv as Dictionary).get("preset", ""))):
			return "rt.presets.%s.preset must be one of %s" % [str(k), ", ".join(RtVocab.RT_PRESETS)]
		var et: String = _toggles((pv as Dictionary).get("tog", null), "rt.presets.%s.tog" % str(k))
		if et != "":
			return et
	for flag: String in ["auto", "retarget"]:
		if not (rt.get(flag, null) is bool):
			return "rt.%s must be a bool" % flag
	if not (rt.get("open", null) is Dictionary):
		return "rt.open must be a Dictionary ({} = no opening action)"
	if not DIFFICULTIES.has(str(rt.get("diff", ""))):
		return "rt.diff must be one of %s" % ", ".join(DIFFICULTIES)
	return ""


static func _pose(v: Variant, what: String) -> String:
	return _ints(v, what, [[-POS_MAX_CM, POS_MAX_CM], [-POS_MAX_CM, POS_MAX_CM], [0, 255]])


static func _toggles(v: Variant, what: String) -> String:
	if not (v is Dictionary):
		return "%s must be a Dictionary" % what
	for k: Variant in (v as Dictionary).keys():
		if not RtVocab.RT_TOGGLES.has(str(k)):
			return "%s.%s is not a switch (%s)" % [what, str(k), ", ".join(RtVocab.RT_TOGGLES)]
		if not ((v as Dictionary)[k] is bool):
			return "%s.%s must be a bool" % [what, str(k)]
	return ""


## Integers with per-position ranges [[lo, hi], …] (exact length).
static func _ints(v: Variant, what: String, ranges: Array) -> String:
	if not (v is Array) or (v as Array).size() != ranges.size():
		return "%s must be an array of %d integers" % [what, ranges.size()]
	for i in ranges.size():
		var e: Variant = (v as Array)[i]
		var r: Array = ranges[i]
		if not _is_int(e) or int(e) < int(r[0]) or int(e) > int(r[1]):
			return "%s[%d] must be an integer in %d..%d" % [what, i, int(r[0]), int(r[1])]
	return ""


static func _unit(d: Dictionary, key: String) -> String:
	return "" if _is_unit(d.get(key, null), false) else "%s must be a unit id (p0..p3, e<n>)" % key


static func _target(d: Dictionary, key: String) -> String:
	var v: Variant = d.get(key, null)
	if v is String and str(v) == "":
		return ""
	return "" if _is_unit(v, false) else "%s must be \"\" or a unit id" % key


static func _is_unit(v: Variant, party_only: bool) -> bool:
	if not (v is String or v is StringName):
		return false
	if _unit_re == null:
		_unit_re = RegEx.create_from_string("^(p[0-3]|e[0-9]+)$")
	var s: String = str(v)
	return _unit_re.search(s) != null and (not party_only or s.begins_with("p"))


static func _id(d: Dictionary, key: String) -> String:
	var v: Variant = d.get(key, null)
	if not (v is String or v is StringName) or str(v) == "":
		return "%s must be a non-empty String" % key
	return ""


static func _str(d: Dictionary, key: String) -> String:
	return "" if (d.get(key, null) is String or d.get(key, null) is StringName) else "%s must be a String" % key


static func _int_range(d: Dictionary, key: String, lo: int, hi: int) -> String:
	var v: Variant = d.get(key, null)
	if not _is_int(v) or int(v) < lo or int(v) > hi:
		return "%s must be an integer in %d..%d" % [key, lo, hi]
	return ""


static func _first(errors: Array) -> String:
	for e: Variant in errors:
		if str(e) != "":
			return str(e)
	return ""


static func _is_int(v: Variant) -> bool:
	if typeof(v) == TYPE_INT:
		return true
	return typeof(v) == TYPE_FLOAT and is_finite(float(v)) and float(v) == floorf(float(v))
