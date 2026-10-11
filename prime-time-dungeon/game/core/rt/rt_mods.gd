class_name RtMods extends RefCounted
## Static modifiers of a real-time combat (07 §9.5): one closed list in RtSetup.mods, collected by
## BattleBridge.make_rt_setup in a fixed order (equipment → species → spec → show boss → twists), canonical, never
## changed during the combat (no twists in combat). An entry is {"src": "<species|spec|equip|showboss|twist>:<id>",
## "op": RtVocab.MOD_OPS, "unit": "p0".."p3" | "party" | "enemies" | "boss" | "all", …the fields of the op}:
## - stat_pm {stat, pm}: the stat × pm / 1000 when the setup is built (max_hp / max_mp: a full unit stays full);
## - skill_pm {skill: id | "*" | "tag:<show tag>" | "element:<element>" | "item:*", field: power | cooldown | cast | mp,
##   pm}: the unit's skill values (RtSim.skill_pm);
## - move_pm, swing_pm, threat_pm {pm}: speed, swing time and threat factor of the unit when the setup is built;
## - dmg_dealt_pm, dmg_taken_pm {pm}: factors of the damage fold (07 §3.9.1 "mods_pm"; percent hits and status ticks
##   fold the target's factors only), heal_taken_pm {pm}: healing on the unit, first_hit_taken_pm {pm}: its first
##   damage in the combat;
## - on {event: RtVocab.MOD_EVENTS, effect: {"heal_pct": int} | {"mp": int} | {"status": id, "ms": int}}: on_event;
## - add_rule {rule: RtRule, shared: bool}: the rule on every affected unit in every phase (key "m<list index>:0");
##   shared = one timer for all of them (the first free unit fires, then all wait every_ms; no slot offset);
## - element_swap: weaknesses ↔ resistances of the element factors (pm → 2000 − pm; ≥ 2000 → 500; immunity stays);
## - extra_enemy {enemy: "first" | id, count 1..2}: komparsen of the first group (never in a boss fight, up to
##   MAX_ENEMIES); they are created before every other op, so every other op of the list applies to them too;
## - forbid_skill {skill}, forbid_items {tag}: refused as "forbidden";
## - unlock_variant {slot, skill}: a bar variant (BattleBridge builds the bar with it — no effect in the sim).
## validate checks a list (integers only, the vocabularies of RtVocab); apply_static applies every op except "on" in
## list order while the setup is built; on_event runs the "on" reactions; from_twists / from_show_boss map the battle
## twists and a show-boss encounter (07 §9.5, §9.6). The helpers below them are the sim's view of the list (pure).

const FixedMath := preload("res://core/stats/fixed_math.gd")

## The fields of every op besides src / op / unit: name → "i" int, "s" String, "b" bool, "d" Dictionary.
const OP_FIELDS: Dictionary = {
	"stat_pm": {"stat": "s", "pm": "i"}, "skill_pm": {"skill": "s", "field": "s", "pm": "i"},
	"move_pm": {"pm": "i"}, "swing_pm": {"pm": "i"}, "threat_pm": {"pm": "i"}, "dmg_dealt_pm": {"pm": "i"},
	"dmg_taken_pm": {"pm": "i"}, "heal_taken_pm": {"pm": "i"}, "first_hit_taken_pm": {"pm": "i"},
	"on": {"event": "s", "effect": "d"}, "add_rule": {"rule": "d", "shared": "b"}, "element_swap": {},
	"extra_enemy": {"enemy": "s", "count": "i"}, "forbid_skill": {"skill": "s"}, "forbid_items": {"tag": "s"},
	"unlock_variant": {"slot": "i", "skill": "s"},
}
const OPTIONAL_FIELDS: PackedStringArray = ["shared"]
## Factors are 0…PM_MAX (07 §3.9.1: the validator keeps every factor ≤ 5000).
const PM_MAX: int = 5000
## RtSim.skill_pm: the index of each skill field.
const SKILL_FIELD_AT: Dictionary = {"power": 0, "cooldown": 1, "cast": 2, "mp": 3}
const NEUTRAL4: PackedInt32Array = [1000, 1000, 1000, 1000]


## Problems of a mod list (07 §9.5; integers only, vocabularies from RtVocab); [] = valid.
static func validate(mods: Array) -> PackedStringArray:
	var out: PackedStringArray = []
	for i in mods.size():
		var ctx: String = "mods[%d]" % i
		if not (mods[i] is Dictionary):
			out.append(ctx + ": not an object")
			continue
		var m: Dictionary = mods[i]
		if not _integral(m):
			out.append(ctx + ": every number must be an integer")
		var src: String = str(m.get("src", ""))
		var cut: int = src.find(":")
		if not (m.get("src", null) is String) or cut <= 0 or cut >= src.length() - 1 \
				or not RtVocab.MOD_SOURCES.has(src.substr(0, cut)):
			out.append(ctx + ".src: '%s' is not <species|spec|equip|showboss|twist>:<id>" % src)
		var op: String = str(m.get("op", ""))
		if not RtVocab.MOD_OPS.has(op):
			out.append(ctx + ".op: unknown op '%s'" % op)
			continue
		if not unit_ok(str(m.get("unit", ""))):
			out.append(ctx + ".unit: unknown unit '%s'" % str(m.get("unit", "")))
		var fields: Dictionary = OP_FIELDS[op]
		var keys: Array = m.keys()
		keys.sort()
		for k: Variant in keys:
			if not ["src", "op", "unit"].has(str(k)) and not fields.has(str(k)):
				out.append(ctx + ": unknown key '%s' for %s" % [str(k), op])
		var fkeys: Array = fields.keys()
		fkeys.sort()
		var typed: bool = true
		for f: Variant in fkeys:
			if not m.has(f):
				if not OPTIONAL_FIELDS.has(str(f)):
					out.append(ctx + ": %s needs '%s'" % [op, str(f)])
					typed = false
			elif not _typed(m[f], str(fields[f])):
				out.append(ctx + ".%s: wrong type" % str(f))
				typed = false
		if typed:
			out.append_array(_op_problems(ctx, op, m))
	return out


## Applies every op except "on" (07 §9.5) while the setup is built: first the extra enemies (list order), then the
## other ops in list order on every unit they select — stats, speed, swing, threat, element swap, the add_rule rules
## (shared ones ready at first_ms for all). Damage / heal / first-hit factors, skill factors and the forbid ops are
## read by the sim (RtSim, from the same list).
static func apply_static(setup: RtSetup, data: GameData) -> void:
	if setup == null or setup.mods.is_empty():
		return
	var bal: RtBalance = setup.balance
	if bal == null:
		bal = RtBalance.from_data(data) if data != null else RtBalance.new()
	for m: Dictionary in setup.mods:
		if str(m.get("op", "")) == "extra_enemy":
			_extra_enemies(setup, data, bal, m)
	for i in setup.mods.size():
		var m: Dictionary = setup.mods[i]
		var op: String = str(m.get("op", ""))
		if op == "extra_enemy" or op == "on":
			continue
		for u: RtUnit in setup.units:
			if not applies(m, u):
				continue
			if op == "add_rule":
				var r: Dictionary = mod_rule(m, i)
				if not r.is_empty():
					u.rules.append(r)
					if bool(r.get("shared", false)):
						u.rule_ready[str(r["key"])] = int(r["first"])
			else:
				apply_unit_op(u, m)


## The "on" reactions (07 §9.5) to event `e` of the combat: for every on-mod whose event fits a selected living unit —
## combat_start (BATTLE_START), kill (KO of a foe by the unit), interrupt (CAST_INTERRUPTED by it), dodge
## (TELEGRAPH_DODGED of it), crit (its critical DAMAGE), ko_ally (KO of another unit of its side), show_success (its
## successful STUNT_RESULT) — the effect on the unit: heal_pct % of its max HP, mp, or a status (no resistance roll).
## Returns the events of the effects.
static func on_event(sim: RtSim, e: ActionEvent) -> Array[ActionEvent]:
	var out: Array[ActionEvent] = []
	if sim == null or sim.setup == null or e == null:
		return out
	var mark: int = sim.out_len()
	for m: Dictionary in sim.setup.mods:
		if str(m.get("op", "")) != "on":
			continue
		var event: String = str(m.get("event", ""))
		for u: RtUnit in sim.units_ref():
			if applies(m, u) and sim.is_alive(u) and _triggers(sim, e, event, u):
				_effect(sim, u, m.get("effect", {}))
	out.assign(sim.out_from(mark))
	return out


## The mods of the active battle twists (07 §9.5 table; `twists` = GameState.flags.live.twist.active entries counting
## battles, stored order): tw_mirror_room → element_swap on enemies; tw_elite_guest → stat_pm max_hp and str ×
## elite_pm on enemies; tw_double_trouble → extra_enemy "first" × extra_enemies; tw_boss_mood → aggressive: swing_pm
## 850 + dmg_dealt_pm 1100 on the boss, else dmg_taken_pm 1100 on it. Parameters: the entry's params, else the twist's
## default (twists.json), else the 07 value. Show-only and exploration twists give none (their rewards and Show
## effects stay with TwistApplier / BattleBridge.apply_result).
static func from_twists(twists: Array, data: GameData) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for v: Variant in twists:
		if not (v is Dictionary):
			continue
		var e: Dictionary = v
		var id: String = str(e.get("id", ""))
		var src: String = "twist:" + id
		match id:
			"tw_mirror_room":
				out.append({"src": src, "op": "element_swap", "unit": "enemies"})
			"tw_elite_guest":
				var pm: int = clampi(_twist_param(e, data, "elite_pm", 1200), 0, PM_MAX)
				out.append({"src": src, "op": "stat_pm", "unit": "enemies", "stat": "max_hp", "pm": pm})
				out.append({"src": src, "op": "stat_pm", "unit": "enemies", "stat": "str", "pm": pm})
			"tw_double_trouble":
				out.append({"src": src, "op": "extra_enemy", "unit": "enemies", "enemy": "first",
					"count": clampi(_twist_param(e, data, "extra_enemies", 1), 1, 2)})
			"tw_boss_mood":
				if _twist_param(e, data, "aggressive", 1) != 0:
					out.append({"src": src, "op": "swing_pm", "unit": "boss", "pm": 850})
					out.append({"src": src, "op": "dmg_dealt_pm", "unit": "boss", "pm": 1100})
				else:
					out.append({"src": src, "op": "dmg_taken_pm", "unit": "boss", "pm": 1100})
	return out


## The mods of a show-boss encounter (07 §9.6, E26): EncounterDef.show_boss → stat_pm max_hp and str × elite_pm on the
## enemies (none for 1000) and the shared add_rule of its rule; [] without a show_boss block. The reward goes through
## BattleResult.boss_rewards (rt_result.gd, on VICTORY).
static func from_show_boss(enc: EncounterDef) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if enc == null or enc.show_boss.is_empty():
		return out
	var src: String = "showboss:" + enc.id
	var pm: int = JsonUtil.to_int(enc.show_boss.get("elite_pm", 1000), 1000)
	if pm != 1000:
		out.append({"src": src, "op": "stat_pm", "unit": "enemies", "stat": "max_hp", "pm": pm})
		out.append({"src": src, "op": "stat_pm", "unit": "enemies", "stat": "str", "pm": pm})
	var rule: Variant = enc.show_boss.get("rule", {})
	if rule is Dictionary and not (rule as Dictionary).is_empty():
		out.append({"src": src, "op": "add_rule", "unit": "enemies", "shared": true,
			"rule": (rule as Dictionary).duplicate(true)})
	return out


# --- the sim's view of the list (pure) ---------------------------------------------------------------------------

## A unit selector of 07 §9.5: "party", "enemies", "boss" (bosses), "all", or a party unit id "p0".."p3".
static func unit_ok(unit: String) -> bool:
	if RtVocab.MOD_UNITS.has(unit):
		return true
	return unit.length() == 2 and unit.begins_with("p") and unit.substr(1).is_valid_int() \
		and unit.substr(1).to_int() >= 0 and unit.substr(1).to_int() < 4


## Does mod `m` select unit `u`?
static func applies(m: Dictionary, u: RtUnit) -> bool:
	match str(m.get("unit", "")):
		"all":
			return true
		"party":
			return u.side == Combatant.Side.PARTY
		"enemies":
			return u.side == Combatant.Side.ENEMY
		"boss":
			return u.side == Combatant.Side.ENEMY and u.is_boss
	return str(m.get("unit", "")) == u.id


## The factors (list order) of the factor op `op` (dmg_dealt_pm, dmg_taken_pm, heal_taken_pm, first_hit_taken_pm)
## that select `u`.
static func pms(mods: Array, u: RtUnit, op: String) -> Array[int]:
	var out: Array[int] = []
	for m: Dictionary in mods:
		if str(m.get("op", "")) == op and applies(m, u):
			out.append(clampi(JsonUtil.to_int(m.get("pm", 1000), 1000), 0, PM_MAX))
	return out


## The compiled add_rule rules of `u` (list order; keys "m<index>:0", "shared": true for shared ones).
static func unit_rules(mods: Array, u: RtUnit) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in mods.size():
		var m: Dictionary = mods[i]
		if str(m.get("op", "")) == "add_rule" and applies(m, u):
			var r: Dictionary = mod_rule(m, i)
			if not r.is_empty():
				out.append(r)
	return out


## The compiled rule of add_rule mod `m` at list index `i` ({} if it has none).
static func mod_rule(m: Dictionary, i: int) -> Dictionary:
	var rule: Variant = m.get("rule", {})
	if not (rule is Dictionary) or (rule as Dictionary).is_empty():
		return {}
	var compiled: Array[Dictionary] = RtRules.compile([rule], "m%d" % i)
	if compiled.is_empty():
		return {}
	var r: Dictionary = compiled[0]
	if bool(m.get("shared", false)):
		r["shared"] = true
	return r


## The skill ids forbidden for `u` ({id: true}) and the forbidden item tags: {"skills", "tags"}.
static func forbidden(mods: Array, u: RtUnit) -> Dictionary:
	var skills: Dictionary = {}
	var tags: PackedStringArray = []
	for m: Dictionary in mods:
		if not applies(m, u):
			continue
		match str(m.get("op", "")):
			"forbid_skill":
				skills[str(m.get("skill", ""))] = true
			"forbid_items":
				tags.append(str(m.get("tag", "")))
	return {"skills": skills, "tags": tags}


## [power, cooldown, cast, mp] factors of skill `sk` for `u` (skill_pm mods, list order, each step mul_pm).
static func skill_factors(mods: Array, u: RtUnit, sk: SkillDef) -> PackedInt32Array:
	var out: PackedInt32Array = NEUTRAL4.duplicate()
	if sk == null:
		return out
	for m: Dictionary in mods:
		if str(m.get("op", "")) != "skill_pm" or not applies(m, u) or not skill_selected(str(m.get("skill", "")), sk):
			continue
		var at: int = int(SKILL_FIELD_AT.get(str(m.get("field", "")), -1))
		if at >= 0:
			out[at] = FixedMath.mul_pm(out[at], clampi(JsonUtil.to_int(m.get("pm", 1000), 1000), 0, PM_MAX))
	return out


## Does the skill selector of skill_pm pick `sk` ("*", an id, "tag:<show tag>", "element:<element>", "item:*" — the
## use skills of items)?
static func skill_selected(sel: String, sk: SkillDef) -> bool:
	if sel == "*" or sel == sk.id:
		return true
	if sel.begins_with("tag:"):
		return sk.show_tags.has(sel.substr(4))
	if sel.begins_with("element:"):
		return sk.element == sel.substr(8)
	return sel == "item:*" and sk.user == "item"


## A per-unit op of apply_static on one unit: stat_pm, move_pm, swing_pm, threat_pm, element_swap (others: none).
static func apply_unit_op(u: RtUnit, m: Dictionary) -> void:
	var pm: int = clampi(JsonUtil.to_int(m.get("pm", 1000), 1000), 0, PM_MAX)
	match str(m.get("op", "")):
		"stat_pm":
			_stat(u, str(m.get("stat", "")), pm)
		"move_pm":
			u.move_cm_tick = maxi(0, FixedMath.mul_pm(u.move_cm_tick, pm))
		"swing_pm":
			u.swing_ticks = maxi(1, FixedMath.mul_pm(u.swing_ticks, pm))
		"threat_pm":
			u.threat_pm = maxi(0, FixedMath.mul_pm(u.threat_pm, pm))
		"element_swap":
			_swap(u)


# --- private --------------------------------------------------------------------------------------------------------

static func _op_problems(ctx: String, op: String, m: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	if m.has("pm") and (int(m["pm"]) < 0 or int(m["pm"]) > PM_MAX):
		out.append(ctx + ".pm: %d outside 0..%d" % [int(m["pm"]), PM_MAX])
	match op:
		"stat_pm":
			if not RtVocab.MOD_STATS.has(str(m["stat"])):
				out.append(ctx + ".stat: unknown stat '%s'" % str(m["stat"]))
		"skill_pm":
			if not RtVocab.MOD_SKILL_FIELDS.has(str(m["field"])):
				out.append(ctx + ".field: unknown field '%s'" % str(m["field"]))
			var sel: String = str(m["skill"])
			if sel == "" or sel == "tag:" or sel == "element:" or (sel.begins_with("item:") and sel != "item:*"):
				out.append(ctx + ".skill: bad selector '%s'" % sel)
		"on":
			if not RtVocab.MOD_EVENTS.has(str(m["event"])):
				out.append(ctx + ".event: unknown event '%s'" % str(m["event"]))
			out.append_array(_effect_problems(ctx + ".effect", m["effect"]))
		"add_rule":
			out.append_array(_rule_problems(ctx + ".rule", m["rule"]))
		"extra_enemy":
			if str(m["enemy"]) == "" or int(m["count"]) < 1 or int(m["count"]) > 2:
				out.append(ctx + ": extra_enemy needs an enemy and count 1..2")
		"forbid_skill":
			if str(m["skill"]) == "":
				out.append(ctx + ".skill: empty")
		"forbid_items":
			if str(m["tag"]) == "":
				out.append(ctx + ".tag: empty")
		"unlock_variant":
			if int(m["slot"]) < 1 or int(m["slot"]) > 5 or str(m["skill"]) == "":
				out.append(ctx + ": unlock_variant needs slot 1..5 and a skill")
	return out


static func _effect_problems(ctx: String, eff: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	var keys: Array = eff.keys()
	keys.sort()
	if keys == ["heal_pct"]:
		if not _typed(eff["heal_pct"], "i") or int(eff["heal_pct"]) < 1 or int(eff["heal_pct"]) > 100:
			out.append(ctx + ".heal_pct: 1..100")
	elif keys == ["mp"]:
		if not _typed(eff["mp"], "i"):
			out.append(ctx + ".mp: an integer")
	elif keys == ["ms", "status"] or keys == ["status"]:
		if not (eff["status"] is String) or str(eff["status"]) == "":
			out.append(ctx + ".status: a status id")
		if eff.has("ms") and (not _typed(eff["ms"], "i") or int(eff["ms"]) < -1):
			out.append(ctx + ".ms: −1 or ≥ 0")
	else:
		out.append(ctx + ": one of {heal_pct} | {mp} | {status, ms}")
	return out


static func _rule_problems(ctx: String, rule: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	var keys: Array = rule.keys()
	keys.sort()
	for k: Variant in keys:
		if not RtVocab.RT_RULE_KEYS.has(str(k)):
			out.append(ctx + ": unknown key '%s'" % str(k))
	if str(rule.get("skill", "")) == "" and not RtVocab.RT_ITEM_KINDS.has(str(rule.get("item", ""))):
		out.append(ctx + ": a rule needs a skill (or an item kind)")
	if rule.has("target") and not RtVocab.RT_TARGETS.has(str(rule["target"])):
		out.append(ctx + ".target: unknown target '%s'" % str(rule["target"]))
	var cond: Variant = rule.get("cond", {})
	if cond is Dictionary:
		var ckeys: Array = (cond as Dictionary).keys()
		ckeys.sort()
		for k: Variant in ckeys:
			if not RtVocab.RT_CONDITIONS.has(str(k)):
				out.append(ctx + ".cond: unknown condition '%s'" % str(k))
	else:
		out.append(ctx + ".cond: an object")
	for k: String in ["first_ms", "every_ms"]:
		if rule.has(k) and (not _typed(rule[k], "i") or int(rule[k]) < 0):
			out.append(ctx + ".%s: an integer ≥ 0" % k)
	return out


static func _typed(v: Variant, typ: String) -> bool:
	match typ:
		"i":
			return (v is int or typeof(v) == TYPE_FLOAT) and JsonUtil.is_integral(v)
		"s":
			return v is String
		"b":
			return v is bool
		"d":
			return v is Dictionary
	return false


## Every number in `v` is integral (JSON numbers without a fraction count as integers).
static func _integral(v: Variant) -> bool:
	match typeof(v):
		TYPE_DICTIONARY:
			for k: Variant in (v as Dictionary).keys():
				if not _integral((v as Dictionary)[k]):
					return false
		TYPE_ARRAY:
			for e: Variant in (v as Array):
				if not _integral(e):
					return false
		TYPE_FLOAT:
			return JsonUtil.is_integral(v)
	return true


static func _triggers(sim: RtSim, e: ActionEvent, event: String, u: RtUnit) -> bool:
	match event:
		"combat_start":
			return e.type == ActionEvent.Type.BATTLE_START
		"kill":
			var t: RtUnit = sim.unit(e.target_id)
			return e.type == ActionEvent.Type.KO and e.actor_id == u.id and t != null and t.side != u.side
		"interrupt":
			return e.type == ActionEvent.Type.CAST_INTERRUPTED and e.actor_id == u.id
		"dodge":
			return e.type == ActionEvent.Type.TELEGRAPH_DODGED and e.target_id == u.id
		"crit":
			return e.type == ActionEvent.Type.DAMAGE and e.crit and e.actor_id == u.id
		"ko_ally":
			var a: RtUnit = sim.unit(e.target_id)
			return e.type == ActionEvent.Type.KO and a != null and a != u and a.side == u.side
		"show_success":
			return e.type == ActionEvent.Type.STUNT_RESULT and e.success and e.actor_id == u.id
	return false


static func _effect(sim: RtSim, u: RtUnit, eff: Variant) -> void:
	if not (eff is Dictionary):
		return
	var d: Dictionary = eff
	if d.has("heal_pct"):
		sim.heal_unit(u, u, FixedMath.div_round(u.max_hp() * JsonUtil.to_int(d["heal_pct"]), 100), "", "")
	elif d.has("mp"):
		sim.change_unit_mp(u, JsonUtil.to_int(d["mp"]))
	elif d.has("status"):
		sim.add_status(u.id, u, str(d["status"]), JsonUtil.to_int(d.get("ms", 0)))


## stat_pm on one unit: max_hp / max_mp keep a full unit full (else the value is capped); the other stats at least 1.
static func _stat(u: RtUnit, stat: String, pm: int) -> void:
	match stat:
		"max_hp":
			var old: int = u.max_hp()
			var nv: int = maxi(1, FixedMath.mul_pm(old, pm))
			u.stats.values[StatBlock.Stat.HP] = nv
			u.hp = nv if u.hp >= old else mini(u.hp, nv)
		"max_mp":
			var old_mp: int = u.max_mp()
			var nmp: int = maxi(0, FixedMath.mul_pm(old_mp, pm))
			u.stats.values[StatBlock.Stat.MP] = nmp
			u.mp = nmp if u.mp >= old_mp else mini(u.mp, nmp)
		_:
			var idx: int = StatBlock.KEYS.find(stat)
			if idx >= 2:
				u.stats.values[idx] = maxi(1, FixedMath.mul_pm(u.stats.values[idx], pm))


## element_swap: every element factor > 1000 or < 1000 (not immunity) becomes 2000 − pm (≥ 2000 → 500).
static func _swap(u: RtUnit) -> void:
	var keys: Array = u.element_mods.keys()
	keys.sort()
	for k: Variant in keys:
		var pm: int = Elements.multiplier_pm(u.element_mods, str(k))
		if pm <= 0 or pm == 1000:
			continue
		u.element_mods[k] = FixedMath.from_ppm((500 if pm >= 2000 else 2000 - pm) * 1000)


## extra_enemy: `count` komparsen of the first group (formation slots after its members around its entry point /
## leader, popping in like the others), never in a boss fight, only while fewer than MAX_ENEMIES enemies.
static func _extra_enemies(setup: RtSetup, data: GameData, bal: RtBalance, m: Dictionary) -> void:
	if setup.is_boss or data == null or setup.groups.is_empty():
		return
	var enemy_id: String = str(m.get("enemy", "first"))
	var n: int = 0
	var enemies: int = 0
	for u: RtUnit in setup.units:
		if u.side != Combatant.Side.ENEMY:
			continue
		enemies += 1
		if enemy_id == "first":
			enemy_id = u.def_id
		if u.id.begins_with("e"):
			n = maxi(n, u.id.substr(1).to_int() + 1)
	if not data.has_id("enemies", enemy_id):
		return
	var g: Dictionary = setup.groups[0]
	var ids: Array = g.get("units", [])
	var lead: Array = g.get("lead", [0, 0, 0])
	var entry: Array = g.get("entry", [])
	var ax: int = int(entry[0]) if entry.size() == 2 else int(lead[0])
	var az: int = int(entry[1]) if entry.size() == 2 else int(lead[1])
	var yaw: int = posmod(int(lead[2]) if lead.size() == 3 else 0, 256)
	for _k in clampi(JsonUtil.to_int(m.get("count", 1), 1), 1, 2):
		if enemies >= bal.i("MAX_ENEMIES"):
			return
		var u: RtUnit = RtUnit.from_enemy(data.enemy(enemy_id), "e%d" % n, n, bal)
		var f: Vector2i = RtGeo.formation(ids.size(), ax, az, yaw)
		var p: Vector2i = RtGeo.project_walkable(setup.geo, f.x, f.y, u.radius, false)
		u.x = p.x
		u.z = p.y
		u.yaw = yaw
		u.pop_in_until = bal.i("POP_IN_TICKS") + (bal.i("ENTER_MAX_TICKS") if entry.size() == 2 else 0)
		setup.units.append(u)
		ids.append(u.id)
		g["units"] = ids
		n += 1
		enemies += 1


## A twist parameter: the entry's params, else the default of twists.json, else `dflt`.
static func _twist_param(e: Dictionary, data: GameData, key: String, dflt: int) -> int:
	var p: Variant = e.get("params", {})
	if p is Dictionary and JsonUtil.is_integral((p as Dictionary).get(key, null)):
		return int((p as Dictionary)[key])
	var id: String = str(e.get("id", ""))
	if data != null and data.has_id("twists", id):
		var spec: Variant = data.twist(id).params.get(key, {})
		if spec is Dictionary and JsonUtil.is_integral((spec as Dictionary).get("default", null)):
			return int((spec as Dictionary)["default"])
	return dflt
