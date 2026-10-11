class_name RtRules extends RefCounted
## Rule engine of the AI partner, the autopilot, the assist and (R1b-I3) the enemy AI (07 §5.3, §6.2): compile turns the
## data rules of a preset / phase into tick-based dictionaries, choose picks the action of a sim-driven unit for this
## tick, suggest the assist's skill for the person, eval_cond tests the conditions. All of them are pure: no random draw
## (a random_enemy target only lists its candidates — the sim draws when it applies the pick), no write, no event
## (07 §3.4 "Reinheit").
##
## Fixed engine rules (§5.3 Nr. 3) for sim-driven units: a filler keeps the MP of the unit's own interrupter (on its
## bar, switch "interrupt" on, RtSim.interrupter_mp); party SHOW rules wait until the party SHOW has been ready for
## AI_SHOW_GRACE_TICKS; item rules fire only in "careful" or with the switch "potions", never take the last item of
## their kind (RT_ITEM_KINDS tag: at least 2 left) and stay within the party limits (ITEM_MAX_PER_COMBAT, the item
## cooldown); the FINALE never. E25: a sim-driven unit sees an interrupt-worthy cast only from its ai_seen tick on (the
## person at once), and rules that need such a cast (target "caster", caster_within_cm, target_casting) wait while it is
## in the last AI_INTERRUPT_GCD_TAIL_TICKS of its GCD; while it escapes a telegraph it starts no cast that walking would
## break (§5.5). A rule that fails only on range leaves a movement goal towards its target (the first such rule) and
## the evaluation goes on (§5.3 Nr. 4).

const Ability := preload("res://core/rt/rt_ability.gd")
const StatusFx := preload("res://core/rt/rt_status_fx.gd")
const Threat := preload("res://core/rt/rt_threat.gd")

## rule_ready of a used "once" rule: never again in this combat.
const NEVER: int = 1 << 40
## Conditions that look at interrupt-worthy casts (E25 visibility, GCD tail).
const CAST_CONDS: PackedStringArray = ["caster_within_cm", "target_casting"]
## _conds: the conditions on the unit and the field (before the rule target is resolved), on the rule target, all.
const SELF_CONDS: int = 0
const TARGET_CONDS: int = 1
const ALL_CONDS: int = 2
## Indices of RtSim.skill_meta: known to the data, GCD, MP cost, cast or channel, moving_cancels, SHOW (stunt).
const M_OK: int = 0
const M_GCD: int = 1
const M_MP: int = 2
const M_CAST: int = 3
const M_MOVE: int = 4
const M_STUNT: int = 5


## Compiled rules (ms → ticks) of a preset / phase: [{"key": "<key_prefix>:<index>", "skill", "item", "target",
## "cond" (integral numbers as int), "first", "every" (ticks), "once", "filler", "then": {} | {"skill", "delay"}}].
## Entries that are no object are left out (their index stays taken).
static func compile(rules: Array, key_prefix: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in rules.size():
		if not (rules[i] is Dictionary):
			continue
		var d: Dictionary = rules[i]
		var then_d: Dictionary = {}
		var th: Variant = d.get("then", {})
		if th is Dictionary and str((th as Dictionary).get("skill", "")) != "":
			then_d = {"skill": str((th as Dictionary)["skill"]),
				"delay": JsonUtil.to_int((th as Dictionary).get("delay_ms", 0)) * 3 / 100}
		var cond: Variant = d.get("cond", {})
		out.append({"key": "%s:%d" % [key_prefix, i], "skill": str(d.get("skill", "")), "item": str(d.get("item", "")),
			"target": str(d.get("target", "none")), "cond": _ints(cond) if cond is Dictionary else {},
			"first": JsonUtil.to_int(d.get("first_ms", 0)) * 3 / 100,
			"every": JsonUtil.to_int(d.get("every_ms", 0)) * 3 / 100, "once": bool(d.get("once", false)),
			"filler": bool(d.get("filler", false)), "then": then_d})
	return out


## The compiled rules of party preset `preset` from a party.json rt block (07 §5.4; keys "<preset>:<index>").
static func preset_rules(prt: Dictionary, preset: String) -> Array[Dictionary]:
	var presets: Variant = prt.get("presets", {})
	var list: Variant = (presets as Dictionary).get(preset, []) if presets is Dictionary else []
	return compile(list if list is Array else [], preset)


## The action of the sim-driven unit `u` this tick (07 §5.3) from its compiled rules (RtUnit.rules): {} (nothing),
## {"goal": [x, z]} (a rule waits for range only), or {"skill": id | "item": id, "target": id, "at": index of the rule
## in u.rules, "goal"?: [x, z], "random"?: [candidate ids] (random_enemy: the sim draws one)}. Pure.
static func choose(sim: RtSim, u: RtUnit) -> Dictionary:
	if not may_act(sim, u):
		return {}
	return _pick(sim, u, u.rules, true)


## The assist's suggestion for the person (07 §5.6): the skill of the first rule of `rules` that `u` could use now —
## usable like can_use ("" or buffered), no items, no movement, no AI reserve, no rule timers; "" if none. Pure.
static func suggest(sim: RtSim, u: RtUnit, rules: Array) -> String:
	if u == null or not sim.is_alive(u):
		return ""
	return str(_pick(sim, u, rules, false).get("skill", ""))


## May the unit pick an action now (07 §5.3): alive, not stunned or dazed (no_act), no cast / channel / drink of its
## own, popped in, entered.
static func may_act(sim: RtSim, u: RtUnit) -> bool:
	return u != null and sim.is_alive(u) and u.cast.is_empty() and u.entry.is_empty() and sim.tick() >= u.pop_in_until \
		and not StatusFx.has_flag(u, "no_act")


## Does every condition of `cond` hold for `u` and the rule target `target_id` (07 §5.3 "Bedingungen")? Unknown keys
## are false. Allies / enemies are relative to the unit; HP and MP shares compare in ‰ without rounding.
static func eval_cond(sim: RtSim, u: RtUnit, cond: Dictionary, target_id: String) -> bool:
	return cond.is_empty() or _conds(sim, u, cond, sim.unit(target_id), ALL_CONDS)


## The rule target (07 §5.3 "Ziele") of `u` for skill `sk` (null: an item rule): {"ok": bool, "id": String} plus
## "random": [candidate ids] for random_enemy ("id" is then the first candidate).
static func rule_target(sim: RtSim, u: RtUnit, target: String, sk: SkillDef) -> Dictionary:
	match target:
		"", "none":
			return _tgt("")
		"self":
			return _tgt(u.id)
		"current":
			var cur: RtUnit = sim.unit(u.target_id)
			if cur != null and ((cur.side != u.side and sim.targetable(cur)) or (cur.side == u.side and sim.is_alive(cur))):
				return _tgt(cur.id)
			return _no()
		"assist":
			return _tgt_or_no(sim.assist_target(u) if u.side == Combatant.Side.PARTY else Threat.top_target(sim, u))
		"threat_top":
			return _tgt_or_no(Threat.top_target(sim, u))
		"controlled":
			var ctl: RtUnit = sim.unit(sim.controlled_id())
			return _tgt(ctl.id) if ctl != null and ctl.side == u.side and sim.is_alive(ctl) else _no()
		"ko_ally":
			for v: RtUnit in sim.units_ref():
				if v.side == u.side and v.hp <= 0 and not v.left_battle:
					return _tgt(v.id)
			return _no()
		"lowest_hp_pct_ally":
			return _tgt_or_no(_lowest_ally(sim, u))
		"lowest_hp_pct_enemy", "nearest_enemy", "farthest_enemy":
			return _tgt_or_no(_enemy_by(sim, u, target))
		"caster":
			var range_cm: int = _range_of(u, sk)
			var best: RtUnit = null
			for e: RtUnit in sim.units_ref():
				if e.cast.is_empty() or e.side == u.side or not sees_cast(sim, u, e) or not sim.targetable(e):
					continue
				if not Ability.in_range(u, e, range_cm):
					continue
				if best == null or int(e.cast["end"]) < int(best.cast["end"]):
					best = e
			return _tgt(best.id) if best != null else _no()
		"random_enemy":
			var range_r: int = _range_of(u, sk)
			var any_range: bool = sk == null or _self_area(sk)
			var cands: Array = []
			for e: RtUnit in sim.units_ref():
				if e.side != u.side and sim.targetable(e) and (any_range or Ability.in_range(u, e, range_r)):
					cands.append(e.id)
			if cands.is_empty():
				return _no()
			return {"ok": true, "id": str(cands[0]), "random": cands}
	return _no()


## Does `u` see the interrupt-worthy cast of `e` (E25)? A sim-driven unit from its ai_seen tick on, the person at once.
static func sees_cast(sim: RtSim, u: RtUnit, e: RtUnit) -> bool:
	if e == null or e.cast.is_empty() or not bool(e.cast.get("worthy", false)) \
			or not bool(e.cast.get("interruptible", true)):
		return false
	if not sim.is_ai_driven(u):
		return true
	return u.ai_seen.has(e.id) and int(u.ai_seen[e.id]) <= sim.tick()


## The item an AI rule of `kind` (heal / revive / mp / cure, the RtVocab.RT_ITEM_KINDS tags) uses on `target_id`: none
## unless at least 2 items of the kind are left (never the last one); heal like the potion key (07 §3.11: the smallest
## covering the missing HP, else the biggest, ties by id), the other kinds the first by id. "" if none. Pure.
static func pick_item(sim: RtSim, u: RtUnit, kind: String, target_id: String) -> String:
	var t: RtUnit = sim.unit(target_id) if target_id != "" else u
	var ids: Array = sim.items.keys()
	ids.sort()
	var left: int = 0
	var usable: Array = []
	for iid: Variant in ids:
		var n: int = int(sim.items[iid])
		var it: ItemDef = sim.item_def(str(iid))
		if n <= 0 or it == null or not it.tags.has(kind) or sim.skill_def(it.use_skill) == null:
			continue
		left += n
		usable.append(str(iid))
	if left < 2 or usable.is_empty():
		return ""
	if kind != "heal":
		return str(usable[0])
	var best_cover: String = ""
	var best_cover_amt: int = -1
	var best_big: String = ""
	var best_big_amt: int = -1
	for iid: String in usable:
		var sk: SkillDef = sim.skill_def(sim.item_def(iid).use_skill)
		if sk.damage_type != "heal" or t == null:
			continue
		var amt: int = Ability.heal_preview(sim, u, t, sk)
		if amt >= t.max_hp() - t.hp and (best_cover_amt < 0 or amt < best_cover_amt):
			best_cover = iid
			best_cover_amt = amt
		if amt > best_big_amt:
			best_big = iid
			best_big_amt = amt
	return best_cover if best_cover != "" else best_big


## The filler reserve (07 §3.10, §5.3 Nr. 3): with the switch "interrupt" on, the unit still has the MP of its own
## interrupter after `sk`.
static func reserve_ok(sim: RtSim, u: RtUnit, sk: SkillDef) -> bool:
	if not bool(u.toggles.get("interrupt", RtVocab.RT_TOGGLE_DEFAULTS.get("interrupt", true))):
		return true
	var need: int = sim.interrupter_mp(u)
	return need <= 0 or u.mp - Ability.mp_cost(sk) >= need


# --- private --------------------------------------------------------------------------------------------------------

## The walk over `rules` (07 §5.3): ai = the AI's evaluation (rule timers, fixed engine rules, E25, range goals,
## items, start now only), else the assist's (usable now or buffered, none of the rest). Cheap tests first: the timer,
## the usability of the skill (AI: _ai_free on the static facts of RtSim.skill_meta — the unit may act, so no cast,
## stun or drink is running; assist: Ability.precheck), the conditions on the unit, the rule target, the conditions on
## it, the filler reserve, then the target resolution (range).
static func _pick(sim: RtSim, u: RtUnit, rules: Array, ai: bool) -> Dictionary:
	var c: int = sim.tick()
	var goal: Array = []
	var party: bool = u.side == Combatant.Side.PARTY
	var tail: bool = ai and u.gcd_until - c > 0 and u.gcd_until - c <= sim.bal.i("AI_INTERRUPT_GCD_TAIL_TICKS")
	var grace: bool = ai and party and c < sim.show_ready_at() + sim.bal.i("AI_SHOW_GRACE_TICKS")
	var escaping: bool = ai and sim.escaping(u)
	var offset: int = u.slot * sim.bal.i("AI_SLOT_OFFSET_TICKS") if ai and not party else 0
	var known: Dictionary = sim.known_skills(u)
	var fin: String = sim.finale_of(u)
	for pos in rules.size():
		var r: Dictionary = rules[pos]
		if ai:
			var key: String = r["key"]
			if (int(u.rule_ready[key]) if u.rule_ready.has(key) else int(r["first"]) + offset) > c:
				continue
		var cond: Dictionary = r["cond"]
		if tail and (r["target"] == "caster" or _cast_cond(cond)):
			continue
		var skill_id: String = r["skill"]
		if skill_id == "":
			if ai and party and r["item"] != "":
				var it: Dictionary = _item_rule(sim, u, r, pos, goal)
				if it.has("item"):
					return it
				if goal.is_empty() and it.has("goal"):
					goal = it["goal"]
			continue
		if skill_id == fin or (party and not known.has(skill_id)):
			continue
		var m: PackedInt32Array = sim.skill_meta(skill_id)
		if m[M_OK] == 0:
			continue
		if ai:
			if not _ai_free(sim, u, skill_id, m, c, grace and party and m[M_STUNT] == 1):
				continue
			if escaping and m[M_CAST] == 1 and m[M_MOVE] == 1:
				continue
		else:
			var pre: String = Ability.precheck(sim, u, sim.skill_def(skill_id))
			if pre != "" and pre != "queue":
				continue
		if not cond.is_empty() and not _conds(sim, u, cond, null, SELF_CONDS):
			continue
		var sk: SkillDef = sim.skill_def(skill_id)
		var tg: Dictionary = rule_target(sim, u, r["target"], sk)
		if not bool(tg["ok"]):
			continue
		if not cond.is_empty() and not _conds(sim, u, cond, sim.unit(tg["id"]), TARGET_CONDS):
			continue
		if ai and bool(r["filler"]) and not reserve_ok(sim, u, sk):
			continue
		var tr: Dictionary = Ability.targets(sim, u, sk, tg["id"], false)
		var reason: String = tr["reason"]
		if reason == "range":
			if ai and goal.is_empty():
				var prim: String = tr["primary"]
				goal = _range_goal(sim, u, _range_of(u, sk), prim if prim != "" else str(tg["id"]))
			continue
		if reason != "":
			continue
		return _result({"skill": skill_id, "target": str(tg["id"]), "at": pos}, tg, goal)
	return {"goal": goal} if not goal.is_empty() else {}


## Ability.precheck == "" for a unit that may act (RtRules.may_act: alive, entered, no cast / drink / no_act), on the
## static facts `m` of the skill (the unit knows it and it is no FINALE): the party SHOW cooldown (and the AI grace,
## `show_wait`) or the own cooldown, the lockout of casts, the GCD (the AI starts now only — no queue), the MP, RtMods.
static func _ai_free(sim: RtSim, u: RtUnit, skill_id: String, m: PackedInt32Array, c: int, show_wait: bool) -> bool:
	if u.side == Combatant.Side.PARTY and m[M_STUNT] == 1:
		if show_wait or sim.show_cd_left() > 0 or sim.show_cast_running(u):
			return false
	else:
		var cd: Variant = u.cooldowns.get(skill_id)
		if cd is Array and int(cd[0]) > c:
			return false
	if m[M_CAST] == 1 and (u.lockout_until > c or StatusFx.has_flag(u, "no_cast")):
		return false
	if m[M_GCD] == 1 and u.gcd_until > c:
		return false
	return u.mp >= m[M_MP] and not sim.forbidden_skill(u, skill_id)


## An item rule of the AI (party only): {"item", "target", "at"} when it fires, {"goal": …} when only the range is
## missing, else {}.
static func _item_rule(sim: RtSim, u: RtUnit, r: Dictionary, pos: int, goal: Array) -> Dictionary:
	if u.preset != "careful" and not bool(u.toggles.get("potions", RtVocab.RT_TOGGLE_DEFAULTS.get("potions", false))):
		return {}
	if sim.items_left() <= 0 or sim.item_cd_left() > 0:
		return {}
	var tg: Dictionary = rule_target(sim, u, str(r["target"]), null)
	if not bool(tg["ok"]) or not eval_cond(sim, u, r["cond"], str(tg["id"])):
		return {}
	var item_id: String = pick_item(sim, u, str(r["item"]), str(tg["id"]))
	if item_id == "":
		return {}
	var ir: Dictionary = Ability.check_item(sim, u, item_id, str(tg["id"]))
	var reason: String = str(ir["reason"])
	if reason == "range":
		var isk: SkillDef = sim.skill_def(sim.item_def(item_id).use_skill)
		var tid: String = str(ir["primary"]) if str(ir["primary"]) != "" else str(tg["id"])
		return {"goal": _range_goal(sim, u, int(isk.rt.get("range_cm", 0)), tid)} if goal.is_empty() else {}
	if reason != "":
		return {}
	return _result({"item": item_id, "target": str(tg["id"]), "at": pos}, tg, goal)


static func _result(out: Dictionary, tg: Dictionary, goal: Array) -> Dictionary:
	if tg.has("random"):
		out["random"] = tg["random"]
	if not goal.is_empty():
		out["goal"] = goal
	return out


## The point towards `target_id` from which a skill of `range_cm` (+ its radius − MELEE_STOP_CM) reaches it.
static func _range_goal(sim: RtSim, u: RtUnit, range_cm: int, target_id: String) -> Array:
	var t: RtUnit = sim.unit(target_id)
	if t == null:
		return []
	var want: int = maxi(0, (range_cm if range_cm > 0 else u.reach) + t.radius - sim.bal.i("MELEE_STOP_CM"))
	var p: Vector2i = DetMath.toward(t.x, t.z, u.x, u.z, want)
	return [p.x, p.y]


## The reach of a skill (rt.range_cm, else the unit's melee reach).
static func _range_of(u: RtUnit, sk: SkillDef) -> int:
	var r: int = int(sk.rt.get("range_cm", 0)) if sk != null else 0
	return r if r > 0 else u.reach


## A skill whose area lies around the unit itself (needs no target in range).
static func _self_area(sk: SkillDef) -> bool:
	if sk.target != "all_enemies":
		return false
	var aoe: Dictionary = sk.rt.get("aoe", {})
	return str(aoe.get("center", "self")) == "self"


## The conditions of `cond` of one kind (`which`: SELF_CONDS — on the unit and the field, TARGET_CONDS — on the rule
## target `t` (the keys "target_…"), ALL_CONDS) hold.
static func _conds(sim: RtSim, u: RtUnit, cond: Dictionary, t: RtUnit, which: int) -> bool:
	for key: String in cond:
		if which != ALL_CONDS and key.begins_with("target_") != (which == TARGET_CONDS):
			continue
		if not _cond_ok(sim, u, key, cond[key], t):
			return false
	return true


## One condition of 07 §5.3 (unknown keys are false).
static func _cond_ok(sim: RtSim, u: RtUnit, key: String, v: Variant, t: RtUnit) -> bool:
	match key:
		"toggle":
			return bool(u.toggles.get(str(v), RtVocab.RT_TOGGLE_DEFAULTS.get(str(v), false)))
		"enemies_in_radius":
			var er: Dictionary = v if v is Dictionary else {}
			return _enemies_within(sim, u, int(er.get("r_cm", 0))) >= int(er.get("min", 1))
		"ally_hp_below_pm":
			return _allies_below(sim, u, int(v)) >= 1
		"caster_within_cm":
			return _caster_within(sim, u, int(v)) != null
		"enemy_on_ally":
			return _enemy_on_ally(sim, u) == bool(v)
		"self_hp_below_pm":
			return u.hp * 1000 < int(v) * u.max_hp()
		"ally_ko":
			return _ally_ko(sim, u) == bool(v)
		"target_hp_above_pm":
			return t != null and t.hp * 1000 > int(v) * t.max_hp()
		"allies_below_pm":
			var ab: Dictionary = v if v is Dictionary else {}
			return _allies_below(sim, u, int(ab.get("pm", 0))) >= int(ab.get("min", 1))
		"self_mp_above_pm":
			return u.mp * 1000 > int(v) * u.max_mp()
		"boss_fight":
			return sim.setup.is_boss == bool(v)
		"target_no_status":
			return t != null and not t.has_status(str(v))
		"target_hp_below_pm":
			return t != null and t.hp * 1000 < int(v) * t.max_hp()
		"self_hp_above_pm":
			return u.hp * 1000 > int(v) * u.max_hp()
		"self_no_status":
			return not u.has_status(str(v))
		"self_mp_min":
			return u.mp >= int(v)
		"target_casting":
			return (t != null and t.side != u.side and sees_cast(sim, u, t)) == bool(v)
		"adds_below":
			return _allies_alive(sim, u) - 1 < int(v)
		"phase":
			return u.phase + 1 == int(v)
		"after_ms":
			return sim.tick() * 100 >= int(v) * 3
	return false


static func _cast_cond(cond: Dictionary) -> bool:
	for k: String in CAST_CONDS:
		if cond.has(k):
			return true
	return false


static func _tgt(id: String) -> Dictionary:
	return {"ok": true, "id": id}


static func _no() -> Dictionary:
	return {"ok": false, "id": ""}


static func _tgt_or_no(id: String) -> Dictionary:
	return _tgt(id) if id != "" else _no()


static func _allies_below(sim: RtSim, u: RtUnit, pm: int) -> int:
	var n: int = 0
	for v: RtUnit in sim.units_ref():
		if v.side == u.side and v.hp > 0 and not v.left_battle and v.hp * 1000 < pm * v.max_hp():
			n += 1
	return n


static func _allies_alive(sim: RtSim, u: RtUnit) -> int:
	var n: int = 0
	for v: RtUnit in sim.units_ref():
		if v.side == u.side and v.hp > 0 and not v.left_battle:
			n += 1
	return n


static func _ally_ko(sim: RtSim, u: RtUnit) -> bool:
	for v: RtUnit in sim.units_ref():
		if v.side == u.side and v.hp <= 0 and not v.left_battle:
			return true
	return false


## Living enemies on stage (entered) within r (+ their radius) around the unit.
static func _enemies_within(sim: RtSim, u: RtUnit, r: int) -> int:
	var n: int = 0
	for v: RtUnit in sim.units_ref():
		if v.side == u.side or v.hp <= 0 or not v.entry.is_empty():
			continue
		var reach: int = r + v.radius
		var dx: int = v.x - u.x
		var dz: int = v.z - u.z
		if dx * dx + dz * dz <= reach * reach and sim.targetable(v):
			n += 1
	return n


## An enemy not fixed on the unit attacks another living ally.
static func _enemy_on_ally(sim: RtSim, u: RtUnit) -> bool:
	for e: RtUnit in sim.units_ref():
		if e.side == u.side or not sim.targetable(e) or e.target_id == "" or e.target_id == u.id:
			continue
		if e.fixate_id == u.id and e.fixate_until > sim.tick():
			continue
		var t: RtUnit = sim.unit(e.target_id)
		if t != null and t.side == u.side and sim.is_alive(t):
			return true
	return false


## The first enemy (unit order) with a cast the unit sees within r (+ its radius).
static func _caster_within(sim: RtSim, u: RtUnit, r: int) -> RtUnit:
	for e: RtUnit in sim.units_ref():
		if e.cast.is_empty() or e.side == u.side:
			continue
		if sees_cast(sim, u, e) and sim.targetable(e) and Ability.in_range(u, e, r):
			return e
	return null


## The lowest HP share among the living allies (the unit included); ties: the controlled figure, then unit order.
static func _lowest_ally(sim: RtSim, u: RtUnit) -> String:
	var best: RtUnit = null
	for v: RtUnit in sim.units_ref():
		if v.side != u.side or v.hp <= 0 or v.left_battle:
			continue
		if best == null:
			best = v
			continue
		var lhs: int = v.hp * best.max_hp()
		var rhs: int = best.hp * v.max_hp()
		if lhs < rhs or (lhs == rhs and v.id == sim.controlled_id()):
			best = v
	return best.id if best != null else ""


## An enemy by HP share (lowest) or distance (nearest / farthest); ties: unit order.
static func _enemy_by(sim: RtSim, u: RtUnit, how: String) -> String:
	var best: RtUnit = null
	var best_d: int = 0
	for v: RtUnit in sim.units_ref():
		if v.side == u.side or not sim.targetable(v):
			continue
		var d2: int = DetMath.dist2(u.x, u.z, v.x, v.z)
		var better: bool = best == null
		if not better:
			match how:
				"lowest_hp_pct_enemy":
					better = v.hp * best.max_hp() < best.hp * v.max_hp()
				"nearest_enemy":
					better = d2 < best_d
				"farthest_enemy":
					better = d2 > best_d
		if better:
			best = v
			best_d = d2
	return best.id if best != null else ""


## A deep copy of a JSON value with integral numbers as int.
static func _ints(v: Variant) -> Variant:
	match typeof(v):
		TYPE_DICTIONARY:
			var out: Dictionary = {}
			for k: Variant in (v as Dictionary).keys():
				out[str(k)] = _ints((v as Dictionary)[k])
			return out
		TYPE_ARRAY:
			var out_a: Array = []
			for e: Variant in (v as Array):
				out_a.append(_ints(e))
			return out_a
	if JsonUtil.is_integral(v) and typeof(v) != TYPE_INT:
		return int(v)
	return v
