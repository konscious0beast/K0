extends RefCounted
## Validator rules of the real-time data (07 §4.10, V1–V14): the `rt` blocks of skills / statuses / enemies / items /
## party / floors.encounters and data/rt_balance.json (RtBalance.validate = V1 + V14), plus the show-boss block of
## encounters (07 §9.6, E26: validators/show_boss.gd, called from here — data_validator.gd is frozen). Private helper
## like the 06 validators (no class_name; preloaded by DataValidator as RtCheck), working on the DataValidator `v`
## (`v._out` = the normalized tables with the raw `rt` dictionaries, `v._err` for messages, its lookup tables) and the
## raw file objects (`raw["rt_balance"]` = the parsed data/rt_balance.json or absent). Vocabularies: RtVocab.
##
## Unknown keys of an rt block are errors (the defs drop them silently, RtNorm). The "Pflicht" rules (V10: an rt block
## for every enemy of a playable floor, V12: combat items with an rt use skill) apply to a real-time data set — one
## whose party carries rt blocks; the CTB-only fixtures (tests/fixtures/data_min) stay valid until R5b removes CTB.
## Messages: "<table>[<i>|<id>].rt.<field>: <problem>".

const ShowBossCheck := preload("res://core/data/validators/show_boss.gd")

## V3 upper bounds of skill fields (07 §4.10).
const SKILL_MAX: Dictionary = {"cast_ms": 5000, "channel_ms": 5000, "cooldown_ms": 120000, "impact_ms": 1500,
	"range_cm": 3000, "threat_pm": 10000, "pct_maxhp": 100}
## R5b part 2b (07 §4.11): the real-time power, MP cost, cleanse and statuses are baked into the main fields of a skill
## with an rt block; the rt block no longer carries them. V3 bounds of the baked main fields.
const BAKED_SKILL_KEYS: Dictionary = {"power": "power", "mp": "mp_cost", "cleanse": "cleanse", "statuses": "statuses"}
const BAKED_SKILL_MAX: Dictionary = {"power": 500, "mp_cost": 99}
## V5 (E14): enemy telegraph hits cost 15–35 % of the max HP.
const TELEGRAPH_PCT: Vector2i = Vector2i(15, 35)
const TELEGRAPH_MIN_CAST_MS: int = 600
## V7 ranges of status fields (07 §4.7).
const STATUS_RANGES: Dictionary = {"tick_pct": [-100, 100], "tick_min": [0, 999], "tick_max": [0, 999],
	"boss_tick_pm": [0, 1000], "max_stacks": [1, 9], "move_pm": [0, 5000], "haste_pm": [0, 5000],
	"dmg_dealt_pm": [0, 5000], "dmg_taken_pm": [0, 5000], "boss_ms_pm": [0, 1000], "ai_miss_pm": [0, 1000]}
## Party context variants (07 §4.1).
const CONTEXT_WHEN: PackedStringArray = ["target_ko"]
## Fields of the phase ops (07 §4.9, RtVocab.RT_PHASE_OPS) besides "op".
const OP_FIELDS: Dictionary = {"say": ["tag"], "status_self": ["status", "ms"], "summon": ["enemy", "count", "at"],
	"fixed_damage_self": ["pct_pm"], "set": ["stationary"], "clear_zones": [], "telegraph": ["skill"]}
## Room-local cm bound of a set (07 §10.1: |x|, |z| ≤ 2400).
const MAX_CM: int = 2400


## Appends every problem of the real-time data to v.errors ("<table>[<i>|<id>].rt.<field>: <message>").
static func check(v: DataValidator, raw: Dictionary) -> void:
	var rt_set: bool = _is_rt_data(v)
	_check_statuses(v)
	_check_skills(v)
	_check_items(v, rt_set)
	_check_party(v)
	_check_enemies(v, rt_set)
	_check_encounters(v)
	ShowBossCheck.check(v)
	if raw.has("rt_balance"):
		for e: String in RtBalance.validate(raw["rt_balance"]):             # V1 + V14
			v.errors.append(e)


## A real-time data set: some party member carries an rt block.
static func _is_rt_data(v: DataValidator) -> bool:
	for d: Dictionary in v._out["party"]:
		if not (d.get("rt", {}) as Dictionary).is_empty():
			return true
	return false


# --- statuses (V1, V2, V7) -------------------------------------------------------------------------------------------

static func _check_statuses(v: DataValidator) -> void:
	var list: Array = v._out["statuses"]
	for i in list.size():
		var d: Dictionary = list[i]
		var rt: Dictionary = d.get("rt", {})
		if rt.is_empty():
			continue
		var ctx: String = DataValidator._ctx("statuses", i, d) + ".rt"
		_ints(v, ctx, rt)
		_keys(v, ctx, rt, StatusDef.RT_SPEC)
		if rt.has("default_ms"):
			var ms: int = _i(rt["default_ms"])
			if ms != -1 and (ms < 100 or ms % 100 != 0):
				v._err(ctx + ".default_ms", "−1 or ≥ 100 and a multiple of 100 (V2, got %d)" % ms)
		if rt.has("period_ms"):
			var p: int = _i(rt["period_ms"])
			if p != 0 and (p < 500 or p % 100 != 0):
				v._err(ctx + ".period_ms", "0 or ≥ 500 and a multiple of 100 (V7, got %d)" % p)
		for k: String in STATUS_RANGES:
			if rt.has(k):
				_range(v, ctx + "." + k, rt[k], int(STATUS_RANGES[k][0]), int(STATUS_RANGES[k][1]))
		if rt.has("stack_mode"):
			v._enum(ctx + ".stack_mode", str(rt["stack_mode"]), RtVocab.STACK_MODES)
		var flags: Variant = rt.get("flags", [])
		for f: Variant in (flags as Array) if flags is Array else []:
			if not RtVocab.RT_STATUS_FLAGS.has(str(f)) and not DataValidator.STATUS_FLAGS.has(str(f)):
				v._err(ctx + ".flags", "unknown flag '%s' (V7)" % str(f))
		if _i(rt.get("tick_pct", 0)) < 0 and _i(rt.get("tick_max", 0)) <= 0:
			v._err(ctx + ".tick_max", "a harmful tick_pct needs tick_max > 0 (V7)")


# --- skills (V1–V6, V13 skill part) ----------------------------------------------------------------------------------

static func _check_skills(v: DataValidator) -> void:
	var list: Array = v._out["skills"]
	for i in list.size():
		var d: Dictionary = list[i]
		var rt: Dictionary = d.get("rt", {})
		if rt.is_empty():
			continue
		var ctx: String = DataValidator._ctx("skills", i, d) + ".rt"
		_ints(v, ctx, rt)
		_keys(v, ctx, rt, SkillDef.RT_SPEC)
		for k: String in BAKED_SKILL_KEYS:
			if rt.has(k):
				v._err(ctx + "." + k, "baked into the main field %s (R5b, 07 §4.11)" % BAKED_SKILL_KEYS[k])
		var mctx: String = DataValidator._ctx("skills", i, d)
		for k: String in BAKED_SKILL_MAX:
			_range(v, mctx + "." + k, d.get(k, 0), 0, int(BAKED_SKILL_MAX[k]))
		_ms_fields(v, ctx, rt, [])
		for k: String in SKILL_MAX:
			if rt.has(k):
				_range(v, ctx + "." + k, rt[k], 0, int(SKILL_MAX[k]))
		if rt.has("icon") and str(rt["icon"]) != "" and not RtVocab.ICON_IDS.has(str(rt["icon"])):
			v._err(ctx + ".icon", "unknown icon id '%s' (RtVocab.ICON_IDS)" % str(rt["icon"]))
		var channel: int = _i(rt.get("channel_ms", 0))
		var period: int = _i(rt.get("period_ms", 0))
		if channel > 0 and (period <= 0 or channel % period != 0):
			v._err(ctx + ".channel_ms", "needs period_ms > 0 and a multiple of it (V3, got %d / %d)" % [channel,
				period])
		_check_aoe(v, ctx + ".aoe", rt.get("aoe", {}))
		_check_skill_statuses(v, mctx + ".statuses", d.get("statuses", []))
		var tg: Dictionary = rt.get("telegraph", {}) if rt.get("telegraph", {}) is Dictionary else {}
		if not tg.is_empty():
			_check_telegraph(v, ctx, d, rt, tg)
		elif bool(rt.get("kill_adds", false)) or bool(rt.get("dash", false)):
			v._err(ctx, "kill_adds / dash need a telegraph")
		var zone: Dictionary = rt.get("zone", {}) if rt.get("zone", {}) is Dictionary else {}
		if not zone.is_empty():
			_check_zone(v, ctx + ".zone", zone)
		if bool(rt.get("interrupt_worthy", false)) and not bool(rt.get("interruptible", true)):
			v._err(ctx + ".interrupt_worthy", "needs interruptible: true (V13)")


static func _check_aoe(v: DataValidator, ctx: String, aoe: Variant) -> void:
	if not (aoe is Dictionary) or (aoe as Dictionary).is_empty():
		return
	var a: Dictionary = aoe
	_keys(v, ctx, a, SkillDef.RT_AOE_SPEC)
	if a.has("center"):
		v._enum(ctx + ".center", str(a["center"]), RtVocab.AOE_CENTERS)
	_range(v, ctx + ".radius_cm", a.get("radius_cm", 0), 0, 1600)
	_range(v, ctx + ".cone_deg", a.get("cone_deg", 0), 0, 180)
	_range(v, ctx + ".max_targets", a.get("max_targets", 0), 0, 8)


static func _check_skill_statuses(v: DataValidator, ctx: String, sts: Variant) -> void:
	if not (sts is Array):
		v._err(ctx, "an array")
		return
	var list: Array = sts
	for j in list.size():
		var c: String = "%s[%d]" % [ctx, j]
		if not (list[j] is Dictionary):
			v._err(c, "an object")
			continue
		var s: Dictionary = list[j]
		_keys(v, c, s, SkillDef.RT_STATUS_SPEC)
		if str(s.get("id", "")) == "":
			v._err(c + ".id", "missing")
		else:
			v._ref(c + ".id", str(s["id"]), v._statuses, "status")
		_range(v, c + ".chance_pm", s.get("chance_pm", 1000), 1, 1000)
		var ms: int = _i(s.get("ms", 0))
		if ms != -1 and (ms < 0 or ms % 100 != 0):
			v._err(c + ".ms", "−1 or ≥ 0 and a multiple of 100 (V2, got %d)" % ms)
		if s.has("to"):
			v._enum(c + ".to", str(s["to"]), RtVocab.STATUS_TO)
		_range(v, c + ".tick_power", s.get("tick_power", 0), 0, 100)


## V5: shape / anchor vocabularies, complete geometry, count, lanes, warning time ≥ 600 ms, enemy user, 15–35 %.
static func _check_telegraph(v: DataValidator, ctx: String, d: Dictionary, rt: Dictionary, tg: Dictionary) -> void:
	var c: String = ctx + ".telegraph"
	_keys(v, c, tg, SkillDef.RT_TELEGRAPH_SPEC)
	var shape: String = str(tg.get("shape", "circle"))
	var anchor: String = str(tg.get("anchor", "target_pos"))
	v._enum(c + ".shape", shape, RtVocab.TELEGRAPH_SHAPES)
	v._enum(c + ".anchor", anchor, RtVocab.TELEGRAPH_ANCHORS)
	var r: int = _i(tg.get("radius_cm", 0))
	match shape:
		"circle":
			if r <= 0:
				v._err(c + ".radius_cm", "a circle needs radius_cm > 0 (V5)")
		"cone":
			if r <= 0:
				v._err(c + ".radius_cm", "a cone needs radius_cm > 0 (V5)")
			_range(v, c + ".angle_deg", tg.get("angle_deg", 0), 1, 180)
		"ring":
			var inner: int = _i(tg.get("inner_cm", 0))
			if inner < 0 or r <= inner:
				v._err(c + ".radius_cm", "a ring needs radius_cm > inner_cm ≥ 0 (V5, got %d / %d)" % [r, inner])
		"line":
			if anchor != "lane" and _i(tg.get("length_cm", 0)) <= 0:
				v._err(c + ".length_cm", "a line needs length_cm > 0 (V5)")
			if _i(tg.get("width_cm", 0)) <= 0:
				v._err(c + ".width_cm", "a line needs width_cm > 0 (V5)")
	for k: String in ["radius_cm", "inner_cm", "length_cm", "width_cm"]:
		_range(v, c + "." + k, tg.get(k, 0), 0, 2 * MAX_CM)
	_range(v, c + ".count", tg.get("count", 1), 1, 4)
	var lanes: Array = tg.get("lanes", []) if tg.get("lanes", []) is Array else []
	if anchor == "lane":
		if shape != "line" or lanes.is_empty():
			v._err(c + ".lanes", "anchor lane needs a line and at least one lane offset (V5)")
		for z: Variant in lanes:
			_range(v, c + ".lanes", z, -MAX_CM, MAX_CM)
	elif not lanes.is_empty():
		v._err(c + ".lanes", "only with anchor lane (V5)")
	if _i(rt.get("cast_ms", 0)) < TELEGRAPH_MIN_CAST_MS:
		v._err(ctx + ".cast_ms", "a telegraph needs a warning time cast_ms ≥ %d (V5)" % TELEGRAPH_MIN_CAST_MS)
	if str(d.get("user", "any")) != "enemy" and str(d.get("user", "any")) != "any":
		v._err(ctx + ".telegraph", "only enemy skills telegraph (V5: user enemy / any)")
	var pct: int = _i(rt.get("pct_maxhp", 0))
	if pct < TELEGRAPH_PCT.x or pct > TELEGRAPH_PCT.y:
		v._err(ctx + ".pct_maxhp", "an enemy telegraph hits %d…%d %% of the max HP (V5, E14, got %d)" % [
			TELEGRAPH_PCT.x, TELEGRAPH_PCT.y, pct])


## V6: ms 1000…30000, period_ms 500…5000, exactly one of status / skill.
static func _check_zone(v: DataValidator, ctx: String, zone: Dictionary) -> void:
	_keys(v, ctx, zone, SkillDef.RT_ZONE_SPEC)
	_range(v, ctx + ".ms", zone.get("ms", 0), 1000, 30000)
	_range(v, ctx + ".period_ms", zone.get("period_ms", 0), 500, 5000)
	var has_status: bool = str(zone.get("status", "")) != ""
	var has_skill: bool = str(zone.get("skill", "")) != ""
	if has_status == has_skill:
		v._err(ctx, "exactly one of status / skill (V6)")
	if has_status:
		v._ref(ctx + ".status", str(zone["status"]), v._statuses, "status")
	if has_skill:
		_skill_ref(v, ctx + ".skill", str(zone["skill"]))


# --- items (V12) -----------------------------------------------------------------------------------------------------

static func _check_items(v: DataValidator, rt_set: bool) -> void:
	var list: Array = v._out["items"]
	for i in list.size():
		var d: Dictionary = list[i]
		var ctx: String = DataValidator._ctx("items", i, d)
		var rt: Dictionary = d.get("rt", {})
		if not rt.is_empty():
			_ints(v, ctx + ".rt", rt)
			_keys(v, ctx + ".rt", rt, ItemDef.RT_SPEC)
			_range(v, ctx + ".rt.wheel", rt.get("wheel", 0), 0, 99)
			var mods: Variant = rt.get("mods", [])
			if not (mods is Array):
				v._err(ctx + ".rt.mods", "must be an array of RtMods (R5b)")
			elif not (mods as Array).is_empty():
				if str(d.get("type", "")) not in ["weapon", "armor", "accessory"]:
					v._err(ctx + ".rt.mods", "only equipment carries real-time mods (R5b)")
				for e: String in RtMods.validate(RtMods.from_equipment(str(d.get("id", "")), mods as Array, "p0")):
					v._err(ctx + ".rt.mods", e)
		var usable: String = str(d.get("usable", "none"))
		if rt_set and str(d.get("type", "")) == "consumable" and (usable == "battle" or usable == "both"):
			_skill_ref(v, ctx + ".use_skill", str(d.get("use_skill", "")))


# --- party (V8, V9 party part) ---------------------------------------------------------------------------------------

static func _check_party(v: DataValidator) -> void:
	var list: Array = v._out["party"]
	for i in list.size():
		var d: Dictionary = list[i]
		var rt: Dictionary = d.get("rt", {})
		if rt.is_empty():
			continue
		var ctx: String = DataValidator._ctx("party", i, d) + ".rt"
		_ints(v, ctx, rt)
		_keys(v, ctx, rt, PartyMemberDef.RT_SPEC)
		for row: Array in PartyMemberDef.RT_SPEC:
			if not rt.has(str(row[0])):
				v._err(ctx + "." + str(row[0]), "missing (V8: every party field)")
		_ms_fields(v, ctx, rt, ["presets"])
		_range(v, ctx + ".radius_cm", rt.get("radius_cm", 40), 20, 150)
		_range(v, ctx + ".swing_ms", rt.get("swing_ms", 2000), 1000, 5000)
		_range(v, ctx + ".reach_cm", rt.get("reach_cm", 250), 100, 1500)
		_range(v, ctx + ".threat_pm", rt.get("threat_pm", 1000), 0, 10000)
		_range(v, ctx + ".follow_cm", rt.get("follow_cm", 600), 0, 1600)
		_skill_ref(v, ctx + ".auto_skill", str(rt.get("auto_skill", "")))
		var mpr: Dictionary = rt.get("mp_regen", {}) if rt.get("mp_regen", {}) is Dictionary else {}
		_keys(v, ctx + ".mp_regen", mpr, PartyMemberDef.RT_MP_REGEN_SPEC)
		v._enum(ctx + ".mp_regen.mode", str(mpr.get("mode", "")), RtVocab.MP_REGEN_MODES)
		var keep: Dictionary = rt.get("keep_cm", {}) if rt.get("keep_cm", {}) is Dictionary else {}
		_keys(v, ctx + ".keep_cm", keep, PartyMemberDef.RT_KEEP_SPEC)
		for p: Variant in keep.keys():
			_range(v, ctx + ".keep_cm." + str(p), keep[p], 0, 700)
		var known: Dictionary = _check_bar(v, ctx, rt)
		var ps: String = str(rt.get("partner_special", ""))
		if ps != "" and not known.has(ps):
			v._err(ctx + ".partner_special", "'%s' is not on this member's bar (V8)" % ps)
		v._enum(ctx + ".default_preset", str(rt.get("default_preset", "")), RtVocab.RT_PRESETS)
		v._enum(ctx + ".assist_preset", str(rt.get("assist_preset", "")), RtVocab.RT_PRESETS)
		var presets: Dictionary = rt.get("presets", {}) if rt.get("presets", {}) is Dictionary else {}
		var pkeys: Array = presets.keys()
		pkeys.sort()
		var want: Array = Array(RtVocab.RT_PRESETS)
		want.sort()
		if pkeys != want:
			v._err(ctx + ".presets", "exactly attack, support, careful (V8, got %s)" % str(pkeys))
		for p: String in RtVocab.RT_PRESETS:
			var rules: Variant = presets.get(p, [])
			if not (rules is Array):
				v._err(ctx + ".presets." + p, "an array of rules")
				continue
			for j in (rules as Array).size():
				_check_rule(v, "%s.presets.%s[%d]" % [ctx, p, j], (rules as Array)[j], true, known)


## V8 bar + context; returns every skill the member can have on its bar {id: true} (bar, FINALE, context).
static func _check_bar(v: DataValidator, ctx: String, rt: Dictionary) -> Dictionary:
	var known: Dictionary = {}
	var base: Dictionary = {}
	var first: Dictionary = {}
	var bar: Array = rt.get("bar", []) if rt.get("bar", []) is Array else []
	for j in bar.size():
		var c: String = "%s.bar[%d]" % [ctx, j]
		if not (bar[j] is Dictionary):
			v._err(c, "an object")
			continue
		var b: Dictionary = bar[j]
		_keys(v, c, b, PartyMemberDef.RT_BAR_SPEC)
		var slot: int = _i(b.get("slot", 0))
		var lvl: int = _i(b.get("level", 1))
		var skill: String = str(b.get("skill", ""))
		_range(v, c + ".slot", slot, 1, 5)
		_range(v, c + ".level", lvl, 1, 99)
		if _skill_ref(v, c + ".skill", skill) and str((v._skills[skill] as Dictionary).get("user", "")) != "party":
			v._err(c + ".skill", "'%s' is no party skill (V8)" % skill)
		known[skill] = true
		var variant: bool = bool(b.get("variant", false))
		var finale: bool = bool(b.get("finale", false))
		if finale and slot != 5:
			v._err(c + ".finale", "only in slot 5 (V8)")
		if not variant and not finale:
			if base.has(slot):
				v._err(c + ".slot", "slot %d has two base abilities (V8)" % slot)
			base[slot] = skill
			if lvl == 1:
				first[slot] = true
	for slot: int in [1, 5]:
		if not first.has(slot):
			v._err(ctx + ".bar", "slot %d needs a base ability with level 1 (V8)" % slot)
	var cx: Array = rt.get("context", []) if rt.get("context", []) is Array else []
	for j in cx.size():
		var c: String = "%s.context[%d]" % [ctx, j]
		if not (cx[j] is Dictionary):
			v._err(c, "an object")
			continue
		var e: Dictionary = cx[j]
		_keys(v, c, e, PartyMemberDef.RT_CONTEXT_SPEC)
		_range(v, c + ".slot", e.get("slot", 0), 1, 5)
		_range(v, c + ".level", e.get("level", 1), 1, 99)
		v._enum(c + ".when", str(e.get("when", "")), CONTEXT_WHEN)
		if _skill_ref(v, c + ".skill", str(e.get("skill", ""))):
			known[str(e["skill"])] = true
	return known


## V9: one rule (party: skills of its bar / context or an item kind; enemy: any skill with rt, every_ms ≥ 1000).
static func _check_rule(v: DataValidator, ctx: String, raw: Variant, party: bool, known: Dictionary) -> void:
	if not (raw is Dictionary):
		v._err(ctx, "a rule object")
		return
	var r: Dictionary = raw
	_ints(v, ctx, r)
	for k: Variant in r.keys():
		if not RtVocab.RT_RULE_KEYS.has(str(k)):
			v._err(ctx + "." + str(k), "unknown rule key")
	var skill: String = str(r.get("skill", ""))
	var item: String = str(r.get("item", ""))
	if skill == "" and item == "":
		v._err(ctx, "a rule needs a skill (or, party only, an item kind)")
	if skill != "" and item != "":
		v._err(ctx, "skill or item, not both")
	if item != "":
		if not party:
			v._err(ctx + ".item", "item rules are party rules (V9)")
		v._enum(ctx + ".item", item, RtVocab.RT_ITEM_KINDS)
	if skill != "" and _skill_ref(v, ctx + ".skill", skill) and party and not known.has(skill):
		v._err(ctx + ".skill", "'%s' is not on this member's bar / context (V9)" % skill)
	v._enum(ctx + ".target", str(r.get("target", "none")), RtVocab.RT_TARGETS)
	_check_cond(v, ctx + ".cond", r.get("cond", {}))
	for k: String in ["first_ms", "every_ms"]:
		if r.has(k):
			var ms: int = _i(r[k])
			if ms < 0 or ms % 100 != 0:
				v._err(ctx + "." + k, "≥ 0 and a multiple of 100 (V2, got %d)" % ms)
	if not party and not bool(r.get("once", false)) and _i(r.get("every_ms", 0)) < 1000:
		v._err(ctx + ".every_ms", "enemy rules repeat after ≥ 1000 ms unless once (V9)")
	var th: Variant = r.get("then", {})
	if th is Dictionary and not (th as Dictionary).is_empty():
		var t: Dictionary = th
		for k: Variant in t.keys():
			if str(k) != "skill" and str(k) != "delay_ms":
				v._err(ctx + ".then." + str(k), "unknown key (skill, delay_ms)")
		_skill_ref(v, ctx + ".then.skill", str(t.get("skill", "")))
		var dl: int = _i(t.get("delay_ms", 0))
		if dl < 0 or dl % 100 != 0:
			v._err(ctx + ".then.delay_ms", "≥ 0 and a multiple of 100 (V2)")
	elif not (th is Dictionary):
		v._err(ctx + ".then", "an object")


## V9: condition keys ⊆ RT_CONDITIONS with the value types of RtVocab.RT_CONDITION_TYPES.
static func _check_cond(v: DataValidator, ctx: String, raw: Variant) -> void:
	if not (raw is Dictionary):
		v._err(ctx, "an object")
		return
	var cond: Dictionary = raw
	for k: Variant in cond.keys():
		var key: String = str(k)
		if not RtVocab.RT_CONDITIONS.has(key):
			v._err(ctx + "." + key, "unknown condition (V9)")
			continue
		var val: Variant = cond[k]
		if not _cond_value_ok(key, val):
			v._err(ctx + "." + key, "wrong value type (V9, 07 §5.3)")
		elif key == "toggle":
			v._enum(ctx + ".toggle", str(val), RtVocab.RT_TOGGLES)
		elif key.ends_with("_status"):
			v._ref(ctx + "." + key, str(val), v._statuses, "status")


static func _cond_value_ok(key: String, val: Variant) -> bool:
	match str(RtVocab.RT_CONDITION_TYPES[key]):
		"i":
			return (val is int or val is float) and JsonUtil.is_integral(val)
		"b":
			return val is bool
		"s":
			return val is String and str(val) != ""
		"d":
			if not (val is Dictionary):
				return false
			var keys: Array = (val as Dictionary).keys()
			keys.sort()
			var want: Array = (RtVocab.RT_CONDITION_FIELDS[key] as Array).duplicate()
			want.sort()
			if keys != want:
				return false
			for x: Variant in (val as Dictionary).values():
				if not JsonUtil.is_integral(x):
					return false
			return true
	return false


# --- enemies (V9 enemy part, V10, V13) -------------------------------------------------------------------------------

static func _check_enemies(v: DataValidator, rt_set: bool) -> void:
	var list: Array = v._out["enemies"]
	for i in list.size():
		var d: Dictionary = list[i]
		var rt: Dictionary = d.get("rt", {})
		if rt.is_empty():
			continue
		var ctx: String = DataValidator._ctx("enemies", i, d) + ".rt"
		_ints(v, ctx, rt)
		_keys(v, ctx, rt, EnemyDef.RT_SPEC)
		_ms_fields(v, ctx, rt, ["rules", "phases"])
		_range(v, ctx + ".summon_hp", rt.get("summon_hp", 0), 0, 99999)      # R5b part 2b: stats.hp is baked
		_range(v, ctx + ".radius_cm", rt.get("radius_cm", 30), 20, 150)
		_range(v, ctx + ".reach_cm", rt.get("reach_cm", 220), 100, 600)
		_range(v, ctx + ".dmg_pm", rt.get("dmg_pm", 1000), 100, 5000)
		_range(v, ctx + ".keep_cm", rt.get("keep_cm", 0), 0, 700)
		_range(v, ctx + ".move_cm_s", rt.get("move_cm_s", 360), 0, 1500)
		if rt.has("auto_target"):
			v._enum(ctx + ".auto_target", str(rt["auto_target"]), RtVocab.AUTO_TARGETS)
		var auto: String = str(rt.get("auto_skill", ""))
		if auto != "":
			_skill_ref(v, ctx + ".auto_skill", auto)
			_range(v, ctx + ".swing_ms", rt.get("swing_ms", 2400), 1000, 5000)
		if str(rt.get("auto_ranged_skill", "")) != "":
			_skill_ref(v, ctx + ".auto_ranged_skill", str(rt["auto_ranged_skill"]))
		var immune: Variant = rt.get("immune", [])
		for s: Variant in (immune as Array) if immune is Array else []:
			v._ref(ctx + ".immune", str(s), v._statuses, "status")
		var rules: Array = rt.get("rules", []) if rt.get("rules", []) is Array else []
		for j in rules.size():
			_check_enemy_rule(v, "%s.rules[%d]" % [ctx, j], rules[j])
		var phases: Array = rt.get("phases", []) if rt.get("phases", []) is Array else []
		if bool(d.get("boss", false)):
			if phases.is_empty():
				v._err(ctx + ".phases", "a boss needs phases (V10)")
		_check_phases(v, ctx + ".phases", phases)
		var en: Variant = rt.get("enrage", {})
		if en is Dictionary and not (en as Dictionary).is_empty():
			_keys(v, ctx + ".enrage", en, EnemyDef.RT_ENRAGE_SPEC)
			if _i((en as Dictionary).get("at_ms", 0)) <= 0:
				v._err(ctx + ".enrage.at_ms", "> 0")
			v._ref(ctx + ".enrage.status", str((en as Dictionary).get("status", "sts_enrage")), v._statuses, "status")
	if rt_set:
		_check_enemy_coverage(v)


static func _check_enemy_rule(v: DataValidator, ctx: String, raw: Variant) -> void:
	_check_rule(v, ctx, raw, false, {})
	if not (raw is Dictionary):
		return
	var r: Dictionary = raw
	var sid: String = str(r.get("skill", ""))
	if not v._skills.has(sid):
		return
	var srt: Dictionary = (v._skills[sid] as Dictionary).get("rt", {})
	var cast: int = _i(srt.get("cast_ms", 0))
	var tele: bool = srt.get("telegraph", {}) is Dictionary and not (srt.get("telegraph", {}) as Dictionary).is_empty()
	if cast > 0 and not tele and _i(r.get("every_ms", 0)) <= 4000 and not bool(r.get("once", false)) \
			and bool(srt.get("interruptible", true)):
		v._err(ctx + ".skill", "'%s' is a filler (cast, no telegraph, every ≤ 4 s): interruptible: false (V13)" % sid)


## V10: phases strictly descending by hp_above_pm (1…999), the last one 0; their ops and rules.
static func _check_phases(v: DataValidator, ctx: String, phases: Array) -> void:
	var prev: int = 1000
	for k in phases.size():
		var c: String = "%s[%d]" % [ctx, k]
		if not (phases[k] is Dictionary):
			v._err(c, "an object")
			continue
		var ph: Dictionary = phases[k]
		for key: Variant in ph.keys():
			if not ["hp_above_pm", "on_enter", "rules"].has(str(key)):
				v._err(c + "." + str(key), "unknown phase key (hp_above_pm, on_enter, rules)")
		var hp: int = _i(ph.get("hp_above_pm", -1))
		var last: bool = k == phases.size() - 1
		if last and hp != 0:
			v._err(c + ".hp_above_pm", "the last phase has hp_above_pm 0 (V10)")
		elif not last and (hp < 1 or hp > 999):
			v._err(c + ".hp_above_pm", "1…999 (V10, got %d)" % hp)
		if hp >= prev:
			v._err(c + ".hp_above_pm", "strictly descending (V10)")
		prev = hp
		var ops: Array = ph.get("on_enter", []) if ph.get("on_enter", []) is Array else []
		for j in ops.size():
			_check_op(v, "%s.on_enter[%d]" % [c, j], ops[j])
		var rules: Array = ph.get("rules", []) if ph.get("rules", []) is Array else []
		for j in rules.size():
			_check_enemy_rule(v, "%s.rules[%d]" % [c, j], rules[j])


## One phase op of RtVocab.RT_PHASE_OPS (07 §4.9).
static func _check_op(v: DataValidator, ctx: String, raw: Variant) -> void:
	if not (raw is Dictionary):
		v._err(ctx, "an op object")
		return
	var o: Dictionary = raw
	_ints(v, ctx, o)
	var op: String = str(o.get("op", ""))
	if not RtVocab.RT_PHASE_OPS.has(op):
		v._err(ctx + ".op", "unknown op '%s' (RtVocab.RT_PHASE_OPS)" % op)
		return
	for k: Variant in o.keys():
		if str(k) != "op" and not (OP_FIELDS[op] as Array).has(str(k)):
			v._err(ctx + "." + str(k), "unknown key of op %s" % op)
	match op:
		"say":
			if not DataValidator.is_valid_mod_tag(str(o.get("tag", ""))):
				v._err(ctx + ".tag", "a valid M.O.D. tag")
		"status_self":
			v._ref(ctx + ".status", str(o.get("status", "")), v._statuses, "status")
			var ms: int = _i(o.get("ms", 0))
			if ms != -1 and (ms < 0 or ms % 100 != 0):
				v._err(ctx + ".ms", "−1 or ≥ 0 and a multiple of 100 (V2)")
		"summon":
			_ref_enemy_rt(v, ctx + ".enemy", str(o.get("enemy", "")))
			_range(v, ctx + ".count", o.get("count", 1), 1, 4)
			v._enum(ctx + ".at", str(o.get("at", "door")), RtVocab.SUMMON_AT)
		"fixed_damage_self":
			_range(v, ctx + ".pct_pm", o.get("pct_pm", 0), 1, 999)
		"set":
			if not (o.get("stationary", null) is bool):
				v._err(ctx + ".stationary", "a bool")
		"telegraph":
			if _skill_ref(v, ctx + ".skill", str(o.get("skill", ""))):
				var srt: Dictionary = (v._skills[str(o["skill"])] as Dictionary).get("rt", {})
				if not (srt.get("telegraph", {}) is Dictionary) or (srt.get("telegraph", {}) as Dictionary).is_empty():
					v._err(ctx + ".skill", "op telegraph needs a telegraph skill")


## V10: every enemy of an encounter on a playable floor (CTB list and rt.enemies) carries an rt block.
static func _check_enemy_coverage(v: DataValidator) -> void:
	for f: Dictionary in v._out["floors"]:
		if not bool(f.get("playable", true)):
			continue
		var encs: Array = f["encounters"]
		for j in encs.size():
			var e: Dictionary = encs[j]
			var ctx: String = DataValidator._ctx("floors[%d].encounters" % int(f["index"]), j, e)
			var ids: Array = Array(e.get("enemies", []))
			var ert: Variant = e.get("rt", {})
			if ert is Dictionary and (ert as Dictionary).get("enemies", []) is Array:
				ids.append_array((ert as Dictionary).get("enemies", []))
			for id: Variant in ids:
				if v._enemies.has(str(id)) and ((v._enemies[str(id)] as Dictionary).get("rt", {}) as Dictionary) \
						.is_empty():
					v._err(ctx + ".enemies", "enemy '%s' has no rt block (V10: playable floor)" % str(id))


# --- encounters (V11, R4 blockers) -----------------------------------------------------------------------------------

static func _check_encounters(v: DataValidator) -> void:
	for f: Dictionary in v._out["floors"]:
		var encs: Array = f["encounters"]
		for j in encs.size():
			var e: Dictionary = encs[j]
			var rt: Variant = e.get("rt", {})
			if not (rt is Dictionary) or (rt as Dictionary).is_empty():
				continue
			var ctx: String = DataValidator._ctx("floors[%d].encounters" % int(f["index"]), j, e) + ".rt"
			var r: Dictionary = rt
			_ints(v, ctx, r)
			_keys(v, ctx, r, EncounterDef.RT_SPEC)
			if r.has("enemies"):
				var ids: Array = r["enemies"] if r["enemies"] is Array else []
				if ids.is_empty() or ids.size() > 4:
					v._err(ctx + ".enemies", "1…4 enemy ids (V11, got %d)" % ids.size())
				for id: Variant in ids:
					_ref_enemy_rt(v, ctx + ".enemies", str(id))
			var steps: Array = r.get("tutorial", []) if r.get("tutorial", []) is Array else []
			for s: Variant in steps:
				v._enum(ctx + ".tutorial", str(s), RtVocab.TUTORIAL_STEPS)
			if not steps.is_empty() and not bool(e.get("tutorial", false)):
				v._err(ctx + ".tutorial", "tutorial steps only on a tutorial encounter (V11)")
			var bl: Array = r.get("blockers", []) if r.get("blockers", []) is Array else []
			for k in bl.size():
				_check_blocker(v, "%s.blockers[%d]" % [ctx, k], bl[k])


## [x0, z0, x1, z1] in room-local cm, x0 < x1, z0 < z1 (07 §3.5.4).
static func _check_blocker(v: DataValidator, ctx: String, b: Variant) -> void:
	if not (b is Array) or (b as Array).size() != 4:
		v._err(ctx, "[x0, z0, x1, z1] in cm")
		return
	var a: Array = b
	for x: Variant in a:
		if not JsonUtil.is_integral(x) or absi(int(x)) > MAX_CM:
			v._err(ctx, "[x0, z0, x1, z1] in cm (integers, |v| ≤ %d)" % MAX_CM)
			return
	if int(a[0]) >= int(a[2]) or int(a[1]) >= int(a[3]):
		v._err(ctx, "x0 < x1 and z0 < z1")


# --- helpers ---------------------------------------------------------------------------------------------------------

## V1: every number in `value` is integral.
static func _ints(v: DataValidator, ctx: String, value: Variant) -> void:
	match typeof(value):
		TYPE_DICTIONARY:
			for k: Variant in (value as Dictionary).keys():
				_ints(v, ctx + "." + str(k), (value as Dictionary)[k])
		TYPE_ARRAY:
			var a: Array = value
			for j in a.size():
				_ints(v, "%s[%d]" % [ctx, j], a[j])
		TYPE_FLOAT:
			if not JsonUtil.is_integral(value):
				v._err(ctx, "integer expected (V1, got %s)" % str(value))


## Unknown keys of a block against a def spec ([name, type, default] rows).
static func _keys(v: DataValidator, ctx: String, block: Variant, spec: Array) -> void:
	if not (block is Dictionary):
		v._err(ctx, "an object")
		return
	var known: Dictionary = {}
	for row: Array in spec:
		known[str(row[0])] = true
	for k: Variant in (block as Dictionary).keys():
		if not known.has(str(k)):
			v._err(ctx + "." + str(k), "unknown key")


## V2: the *_ms fields of a block (not those under `skip` keys) ≥ 0 and a multiple of 100, move_cm_s % 30 == 0.
static func _ms_fields(v: DataValidator, ctx: String, block: Dictionary, skip: Array) -> void:
	for k: Variant in block.keys():
		var key: String = str(k)
		if skip.has(key):
			continue
		var val: Variant = block[k]
		if val is Dictionary:
			_ms_fields(v, ctx + "." + key, val, skip)
		elif key.ends_with("_ms") and JsonUtil.is_integral(val):
			if int(val) < 0 or int(val) % 100 != 0:
				v._err(ctx + "." + key, "≥ 0 and a multiple of 100 (V2, got %d)" % int(val))
		elif key == "move_cm_s" and JsonUtil.is_integral(val) and int(val) % 30 != 0:
			v._err(ctx + ".move_cm_s", "a multiple of 30 (V2, got %d)" % int(val))


static func _range(v: DataValidator, ctx: String, value: Variant, lo: int, hi: int) -> void:
	if not JsonUtil.is_integral(value):
		v._err(ctx, "integer expected (V1)")
		return
	if int(value) < lo or int(value) > hi:
		v._err(ctx, "out of range %d…%d (V3, got %d)" % [lo, hi, int(value)])


static func _i(value: Variant) -> int:
	return int(value) if JsonUtil.is_integral(value) else 0


## A skill id with an rt block (V4).
static func _skill_ref(v: DataValidator, ctx: String, id: String) -> bool:
	if id == "":
		v._err(ctx, "a skill id (V4)")
		return false
	if not v._ref(ctx, id, v._skills, "skill"):
		return false
	if ((v._skills[id] as Dictionary).get("rt", {}) as Dictionary).is_empty():
		v._err(ctx, "skill '%s' has no rt block (V4)" % id)
		return false
	return true


## An enemy id with an rt block (V4, V11).
static func _ref_enemy_rt(v: DataValidator, ctx: String, id: String) -> bool:
	if id == "":
		v._err(ctx, "an enemy id (V4)")
		return false
	if not v._ref(ctx, id, v._enemies, "enemy"):
		return false
	if ((v._enemies[id] as Dictionary).get("rt", {}) as Dictionary).is_empty():
		v._err(ctx, "enemy '%s' has no rt block (V4)" % id)
		return false
	return true
