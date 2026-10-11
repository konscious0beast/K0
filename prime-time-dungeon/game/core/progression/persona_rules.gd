# STUB(K0) — owned by 08-K1. Replace completely, keep the public API.
class_name PersonaRules extends RefCounted
## Rules of the candidate persona in the core (08 §2.3, §3.7, §4.8): the recorded command
## {"t": "persona", "v": 1, "talent", "bias": [...]} (start, once per run, before the run begins) or
## {"t": "persona", "v": 1, "talent", "swap": true} (once, in the first Talent-Show, before the first pool talent).
## Only ids go into the core (P-1): kai.origin_talent and flags["persona"] = {"v": 1, "bias": [...], "swapped": bool}.
## K0 ships check() and apply() complete (both verifiers call them, 08 §10.2 Nr. 9) and the rest as neutral stubs;
## K1 replaces the stubs (offer, bias_for, map_text, weight_add: + 1 from floor 2 for a biased preference).
## Static and pure (core): no autoloads, integer math only.

const MAX_BIAS: int = 3
const BIAS_WEIGHT_ADD: int = 1
const BIAS_MIN_FLOOR: int = 2
const VERSION: int = 1
const FLAG: String = "persona"
const MEMBER: String = "kai"                 # the persona is the candidate (08 §2.4: only kai has origin_talent)
const REASONS: PackedStringArray = ["bad_version", "unknown_talent", "bad_bias", "already_set", "run_started",
	"event_run", "no_swap", "same"]


## [A, B] (A != B) offered for an origin and a hobby (08 §3.7). Stub: [].
static func offer(_data: GameData, _origin_id: String, _hobby_id: String) -> PackedStringArray:
	return PackedStringArray()


## Sorted, distinct marotte ids (rotation only, <= 3) of the chosen traits (08 §3.7). Stub: [].
static func bias_for(_data: GameData, _trait_ids: PackedStringArray) -> PackedStringArray:
	return PackedStringArray()


## The start command for a talent and the chosen traits.
static func command_for(data: GameData, talent_id: String, trait_ids: PackedStringArray) -> Dictionary:
	return {"t": "persona", "v": VERSION, "talent": talent_id, "bias": Array(bias_for(data, trait_ids))}


## The swap command (first Talent-Show).
static func swap_command(talent_id: String) -> Dictionary:
	return {"t": "persona", "v": VERSION, "talent": talent_id, "swap": true}


## "" or why `cmd` is refused now: bad_version | event_run | unknown_talent | bad_bias | already_set | run_started |
## no_swap | same (08 §2.3). Start: only once and before the run begins (HeroRules.run_started), bias 0–3 distinct
## ascending ids of rotating marotten. Swap: after a start, not swapped yet, in a safe room, before the first pool
## talent of kai (Talents.picks == 0), a different talent. Event runs never have a persona (08 §8).
static func check(state: GameState, data: GameData, cmd: Dictionary, event_run: bool) -> String:
	if not _is_int(cmd.get("v", null)) or int(cmd["v"]) != VERSION:
		return "bad_version"
	if event_run:
		return "event_run"
	var talent: String = str(cmd.get("talent", ""))
	if state == null or data == null or not data.has_origin_talent(talent):
		return "unknown_talent"
	var kai: PartyMember = state.member(MEMBER)
	if kai == null:
		return "unknown_talent"
	var flag: Variant = state.flags.get(FLAG, null)
	if bool(cmd.get("swap", false)):
		if not (flag is Dictionary) or bool((flag as Dictionary).get("swapped", false)) \
				or not RunRules.in_safe_room(state) or Talents.picks(kai) > 0:
			return "no_swap"
		return "same" if talent == kai.origin_talent else ""
	if flag != null:
		return "already_set"
	if HeroRules.run_started(state):
		return "run_started"
	return _bias_refusal(data, cmd.get("bias", []))


## Applies a valid command: kai.origin_talent, flags["persona"] (swap: swapped = true); HP / MP follow a changed
## maximum like Talents.pick (Progression.follow_max_vitals). false (nothing changes) if check() refuses.
static func apply(state: GameState, data: GameData, cmd: Dictionary) -> bool:
	if check(state, data, cmd, false) != "":
		return false
	var kai: PartyMember = state.member(MEMBER)
	var before: StatBlock = Progression.total_stats(kai, data)
	kai.origin_talent = str(cmd["talent"])
	if bool(cmd.get("swap", false)):
		var f: Dictionary = (state.flags[FLAG] as Dictionary).duplicate(true)
		f["swapped"] = true
		state.flags[FLAG] = f
	else:
		var bias: Array = []
		for b: Variant in (cmd.get("bias", []) as Array):
			bias.append(str(b))
		state.flags[FLAG] = {"v": VERSION, "bias": bias, "swapped": false}
	Progression.follow_max_vitals(kai, before, Progression.total_stats(kai, data))
	return true


## The swap is possible now (safe room, not swapped, no pool talent yet, a persona exists).
static func can_swap(state: GameState) -> bool:
	if state == null or not (state.flags.get(FLAG, null) is Dictionary):
		return false
	var kai: PartyMember = state.member(MEMBER)
	return kai != null and not bool((state.flags[FLAG] as Dictionary).get("swapped", false)) \
		and RunRules.in_safe_room(state) and Talents.picks(kai) == 0


## The recorded bias of the run ([] without a persona).
static func bias(state: GameState) -> PackedStringArray:
	var out: PackedStringArray = []
	var f: Variant = state.flags.get(FLAG, null) if state != null else null
	if f is Dictionary:
		for b: Variant in ((f as Dictionary).get("bias", []) as Array):
			out.append(str(b))
	return out


## Extra draw weight of a preference in MarottenRules.announce (08 §4.8): BIAS_WEIGHT_ADD from BIAS_MIN_FLOOR for a
## biased id, else 0. Stub: 0 (K1).
static func weight_add(_state: GameState, _marotte_id: String, _floor_index: int) -> int:
	return 0


## Offline "Anderes …" mapping of a free text to an origin (&"job") or hobby (&"hobby") id (08 §3.7). Stub: "".
static func map_text(_data: GameData, _text: String, _kind: StringName) -> String:
	return ""


static func _bias_refusal(data: GameData, v: Variant) -> String:
	if not (v is Array) or (v as Array).size() > MAX_BIAS:
		return "bad_bias"
	var last: String = ""
	for b: Variant in (v as Array):
		var id: String = str(b)
		if not (b is String) or id <= last or not data.has_id("marotten", id) or not data.marotte(id).rotation:
			return "bad_bias"
		last = id
	return ""


static func _is_int(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or (typeof(v) == TYPE_FLOAT and is_finite(float(v)) and float(v) == floorf(float(v)))
