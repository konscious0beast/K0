# STUB(R1a) — owned by R1b. Replace completely, keep the public API.
class_name RtBalance extends RefCounted
## Typed real-time tuning values (07 §3.16). Keys, types, allowed ranges and the start values are code (owned by R1:
## only R1 changes the structure); the VALUES live in data/rt_balance.json ({"schema": 1, "values": {…}}, owned by R4,
## part of DB.data_hash). from_data() reads them once per combat; a missing file or key falls back to DEFAULTS.
## validate() is V1 + V14 of 07 §4.10 (validators/rt.gd calls it from R4 on; test_r1a_contract checks the file).
## Values are integers or {sub key: integer} (IMPACT_TICKS, REACT_TICKS, AI_DODGE_MISS_PM, SET_R_CM).
## R1a ships this class complete (it is the key/range table); R1b may extend the getters, never the keys alone.

const SCHEMA: int = 1
## Start values (07 §3.16, identical to data/rt_balance.json at R1a).
const DEFAULTS: Dictionary = {
	"TICKS_PER_SEC": 30, "GCD_TICKS": 45, "GCD_MIN_TICKS": 30, "CAST_MIN_TICKS": 15, "QUEUE_TICKS": 9,
	"IMPACT_TICKS": {"attack": 9, "cast": 0, "stunt": 24, "item": 9},
	"INTERRUPT_LOCKOUT_TICKS": 60, "ITEM_CD_TICKS": 450, "ITEM_MAX_PER_COMBAT": 3, "DRINK_TICKS": 15,
	"SHOW_CD_TICKS": 900, "AI_SHOW_GRACE_TICKS": 150, "PARTNER_ORDER_TICKS": 45, "FINALE_TARGET_BELOW_PM": 300,
	"FIRST_SWING_TICKS": 30, "POP_IN_TICKS": 15, "ENTER_MAX_TICKS": 30, "AI_SLOT_OFFSET_TICKS": 9,
	"REACT_TICKS": {"attack": 15, "support": 12, "careful": 6},
	"AI_DODGE_MISS_PM": {"attack": 130, "support": 130, "careful": 40},
	"AI_INTERRUPT_REACT_TICKS": 15, "AI_INTERRUPT_JITTER_TICKS": 10, "AI_INTERRUPT_LATE_PM": 250,
	"AI_INTERRUPT_LATE_TICKS": 45, "AI_INTERRUPT_GCD_TAIL_TICKS": 5,
	"ESCAPE_MARGIN_CM": 60, "RANDOM_POINT_MIN_CM": 300, "FLEE_TICKS": 60, "FLEE_WARN_TICKS": 15,
	"DR_THRESHOLD_CM": 15, "DR_VEL_THRESHOLD": 15, "DR_YAW_THRESHOLD": 8, "DR_MAX_TICKS": 30, "HEARTBEAT_TICKS": 15,
	"FORCE_SAMPLE_CM": 2, "MOVE_BUDGET_MM": 600, "MOVE_REFILL_MM_TICK": 3, "SPEED_TOLERANCE_PM": 1250,
	"PLAYER_RUN_CM_S": 550, "CAST_CANCEL_SPEED_PM": 250, "CAST_CANCEL_CM": 40,
	"CELL_HALF_CM": 800, "ROOM_INNER_CM": 750, "SET_R_CM": {"regular": 480, "boss": 600}, "DOOR_HALF_CM": 200,
	"MELEE_STOP_CM": 30, "THREAT_SWITCH_PM": 1100, "TAUNT_TOP_PM": 1100, "TAUNT_RADIUS_CM": 1000, "FIXATE_TICKS": 120,
	"HEAL_THREAT_PM": 500, "DEBUFF_THREAT": 10, "COMBO_WINDOW_TICKS": 30, "COMBO_COOLDOWN_TICKS": 150, "COMBO_PM": 1100,
	"OVERKILL_PM": 500, "DMG_FACTOR_MAX_PM": 8000, "PCT_GUARD_PM": 667, "CLOSE_DODGE_TICKS": 9,
	"HIT_MP_EVERY_TICKS": 30,
	"MAX_PARTY": 4, "MAX_ENEMIES": 6, "MAX_TELEGRAPHS": 10, "MAX_COMBAT_TICKS": 18000, "CHECKPOINT_TICKS": 300,
	"HP_SCALE_PM": 4000, "FIXED_SCALE_PM": 4000, "ENEMY_HP_PM": 7000, "SUMMON_HP_PM": 4000, "EASY_WARN_PM": 1250,
	"REVIVE_GUARD_MS": 3000, "REGEN_PERIOD_TICKS": 90, "REGEN_HP_DELAY_TICKS": 150, "REGEN_HP_PM": 5,
	"REGEN_MP_PM": 20, "CHASE_COMBAT_SEC_X10": 40,
}
## Allowed range [lo, hi] of every value (for {sub: int} keys: of each sub value). TICKS_PER_SEC is structure, not
## balance: it is in the file only to be checked (must be 30).
const RANGES: Dictionary = {
	"TICKS_PER_SEC": [30, 30], "GCD_TICKS": [15, 90], "GCD_MIN_TICKS": [15, 90], "CAST_MIN_TICKS": [1, 60],
	"QUEUE_TICKS": [0, 30], "IMPACT_TICKS": [0, 60], "INTERRUPT_LOCKOUT_TICKS": [0, 300], "ITEM_CD_TICKS": [0, 3600],
	"ITEM_MAX_PER_COMBAT": [0, 9], "DRINK_TICKS": [0, 90], "SHOW_CD_TICKS": [0, 3600],
	"AI_SHOW_GRACE_TICKS": [0, 900], "PARTNER_ORDER_TICKS": [0, 300], "FINALE_TARGET_BELOW_PM": [0, 1000],
	"FIRST_SWING_TICKS": [0, 300], "POP_IN_TICKS": [0, 120], "ENTER_MAX_TICKS": [0, 300],
	"AI_SLOT_OFFSET_TICKS": [0, 90], "REACT_TICKS": [0, 90], "AI_DODGE_MISS_PM": [0, 1000],
	"AI_INTERRUPT_REACT_TICKS": [0, 120], "AI_INTERRUPT_JITTER_TICKS": [0, 120], "AI_INTERRUPT_LATE_PM": [0, 1000],
	"AI_INTERRUPT_LATE_TICKS": [0, 300], "AI_INTERRUPT_GCD_TAIL_TICKS": [0, 45],
	"ESCAPE_MARGIN_CM": [0, 500], "RANDOM_POINT_MIN_CM": [0, 1000], "FLEE_TICKS": [1, 300], "FLEE_WARN_TICKS": [0, 300],
	"DR_THRESHOLD_CM": [1, 200], "DR_VEL_THRESHOLD": [1, 400], "DR_YAW_THRESHOLD": [1, 128], "DR_MAX_TICKS": [1, 300],
	"HEARTBEAT_TICKS": [1, 300], "FORCE_SAMPLE_CM": [0, 100], "MOVE_BUDGET_MM": [0, 5000],
	"MOVE_REFILL_MM_TICK": [0, 100], "SPEED_TOLERANCE_PM": [1000, 3000], "PLAYER_RUN_CM_S": [30, 2000],
	"CAST_CANCEL_SPEED_PM": [0, 1000], "CAST_CANCEL_CM": [0, 500],
	"CELL_HALF_CM": [100, 2400], "ROOM_INNER_CM": [100, 2400], "SET_R_CM": [100, 2400], "DOOR_HALF_CM": [0, 800],
	"MELEE_STOP_CM": [0, 200], "THREAT_SWITCH_PM": [1000, 3000], "TAUNT_TOP_PM": [1000, 3000],
	"TAUNT_RADIUS_CM": [0, 3000], "FIXATE_TICKS": [0, 600], "HEAL_THREAT_PM": [0, 2000], "DEBUFF_THREAT": [0, 1000],
	"COMBO_WINDOW_TICKS": [0, 300], "COMBO_COOLDOWN_TICKS": [0, 900], "COMBO_PM": [1000, 2000],
	"OVERKILL_PM": [0, 2000], "DMG_FACTOR_MAX_PM": [1000, 20000], "PCT_GUARD_PM": [0, 1000],
	"CLOSE_DODGE_TICKS": [0, 60], "HIT_MP_EVERY_TICKS": [1, 300],
	"MAX_PARTY": [1, 4], "MAX_ENEMIES": [1, 12], "MAX_TELEGRAPHS": [1, 32], "MAX_COMBAT_TICKS": [900, 54000],
	"CHECKPOINT_TICKS": [30, 3000], "HP_SCALE_PM": [1000, 10000], "FIXED_SCALE_PM": [1000, 10000],
	"ENEMY_HP_PM": [1000, 20000], "SUMMON_HP_PM": [1000, 20000], "EASY_WARN_PM": [1000, 3000],
	"REVIVE_GUARD_MS": [0, 10000], "REGEN_PERIOD_TICKS": [1, 900], "REGEN_HP_DELAY_TICKS": [0, 1800],
	"REGEN_HP_PM": [0, 1000], "REGEN_MP_PM": [0, 1000], "CHASE_COMBAT_SEC_X10": [0, 600],
}

## The effective values: DEFAULTS overlaid with the known, well-typed values of the file.
var values: Dictionary = {}


func _init() -> void:
	values = DEFAULTS.duplicate(true)


## The balance of `data` (GameData.rt_balance_values(), i.e. data/rt_balance.json → "values"); DEFAULTS without data.
static func from_data(data: GameData) -> RtBalance:
	return from_values(data.rt_balance_values() if data != null else {})


## DEFAULTS overlaid with every known key of `v` whose value has the right shape (integral number, or an object with
## exactly the sub keys of the default); everything else is ignored here (validate() reports it).
static func from_values(v: Dictionary) -> RtBalance:
	var b: RtBalance = RtBalance.new()
	for k: String in DEFAULTS.keys():
		if not v.has(k):
			continue
		var dflt: Variant = DEFAULTS[k]
		var raw: Variant = v[k]
		if dflt is Dictionary:
			if not (raw is Dictionary):
				continue
			var sub: Dictionary = (dflt as Dictionary).duplicate()
			for sk: Variant in (dflt as Dictionary).keys():
				if (raw as Dictionary).has(sk) and JsonUtil.is_integral((raw as Dictionary)[sk]):
					sub[sk] = int((raw as Dictionary)[sk])
			b.values[k] = sub
		elif JsonUtil.is_integral(raw):
			b.values[k] = int(raw)
	return b


## Integer value of `key` (0 for an unknown key or a {sub: int} key).
func i(key: String) -> int:
	var v: Variant = values.get(key, 0)
	return int(v) if not (v is Dictionary) else 0


## Sub value of a {sub: int} key, e.g. sub("SET_R_CM", "boss"); 0 if unknown.
func sub(key: String, sub_key: String) -> int:
	var v: Variant = values.get(key, {})
	return int((v as Dictionary).get(sub_key, 0)) if v is Dictionary else 0


## Deep copy of the values (ints only; core/rt does not depend on core/live, the hashing side canonicalizes).
func to_dict() -> Dictionary:
	return values.duplicate(true)


## V1 + V14 (07 §4.10) of a parsed rt_balance.json: {"schema": 1, "values": {…}} with exactly the keys of DEFAULTS,
## every number integral and in RANGES, the sub keys of the object values exactly those of DEFAULTS, TICKS_PER_SEC 30.
## [] = valid; messages "rt_balance.<key>[.<sub>]: <problem>".
static func validate(file: Variant) -> PackedStringArray:
	var out: PackedStringArray = []
	if not (file is Dictionary):
		out.append("rt_balance: file must contain a JSON object")
		return out
	var f: Dictionary = file
	if not f.has("schema") or not JsonUtil.is_integral(f["schema"]) or int(f["schema"]) != SCHEMA:
		out.append("rt_balance.schema: must be %d" % SCHEMA)
	for k: Variant in f.keys():
		if str(k) != "schema" and str(k) != "values":
			out.append("rt_balance.%s: unknown top-level key" % str(k))
	if not (f.get("values", null) is Dictionary):
		out.append("rt_balance.values: missing (object expected)")
		return out
	var v: Dictionary = f["values"]
	var keys: Array = DEFAULTS.keys()
	keys.sort()
	for k: String in keys:
		if not v.has(k):
			out.append("rt_balance.%s: missing key" % k)
			continue
		var r: Array = RANGES[k]
		if DEFAULTS[k] is Dictionary:
			if not (v[k] is Dictionary):
				out.append("rt_balance.%s: object expected" % k)
				continue
			var subs: Array = (DEFAULTS[k] as Dictionary).keys()
			subs.sort()
			for sk: String in subs:
				if not (v[k] as Dictionary).has(sk):
					out.append("rt_balance.%s.%s: missing key" % [k, sk])
				else:
					_check_int(out, "%s.%s" % [k, sk], (v[k] as Dictionary)[sk], int(r[0]), int(r[1]))
			for sk: Variant in (v[k] as Dictionary).keys():
				if not (DEFAULTS[k] as Dictionary).has(str(sk)):
					out.append("rt_balance.%s.%s: unknown key" % [k, str(sk)])
		else:
			_check_int(out, k, v[k], int(r[0]), int(r[1]))
	var extra: Array = v.keys()
	extra.sort()
	for k: Variant in extra:
		if not DEFAULTS.has(str(k)):
			out.append("rt_balance.%s: unknown key" % str(k))
	return out


static func _check_int(out: PackedStringArray, key: String, value: Variant, lo: int, hi: int) -> void:
	if not JsonUtil.is_integral(value):
		out.append("rt_balance.%s: integer expected (V1)" % key)
	elif int(value) < lo or int(value) > hi:
		out.append("rt_balance.%s: out of range %d..%d (got %d)" % [key, lo, hi, int(value)])
