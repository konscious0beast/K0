extends RefCounted
## Abilities, items, SHOW / FINALE, the partner order, auto-attacks and the resolution of hits and casts of the
## real-time combat (07 §3.3 steps 1b and 5–8, §3.6, §3.11, §4) — private helper of RtSim (no class_name; preloaded as
## Ability). The checks are one pure function (check) used by the commands, the queue, the partner order and the pure
## queries alike, so a HUD state and the answer to a command never disagree.

const FixedMath := preload("res://core/stats/fixed_math.gd")
const Damage := preload("res://core/rt/rt_damage.gd")
const StatusFx := preload("res://core/rt/rt_status_fx.gd")
const Threat := preload("res://core/rt/rt_threat.gd")

const K := BattleCommand.Kind
## Busy reasons a partner order waits out (it walks into range on its own).
const WAIT_REASONS: PackedStringArray = ["queue", "gcd", "casting", "drinking", "stunned", "range"]


# --- step 1b: commands ----------------------------------------------------------------------------------------------

## Applies the non-sample commands of tick c in submission order (07 §3.3 step 1b).
static func apply_commands(sim: RtSim, due: Array[Dictionary]) -> void:
	for e: Dictionary in due:
		var cmd: Dictionary = e["cmd"]
		var u: RtUnit = sim.unit(str(cmd.get("u", "")))
		if u == null:
			continue
		match str(cmd.get("t", "")):
			"target_change":
				target_change(sim, u, str(cmd.get("target", "")))
			"auto_attack":
				u.auto_on = bool(cmd.get("on", true))
			"autopilot":
				autopilot(sim, u, bool(cmd.get("on", false)))
			"partner_preset":
				set_preset(sim, u, str(cmd.get("preset", "")), cmd.get("tog", {}))
			"partner_special":
				order_partner(sim, u)
			"ability_use":
				use_ability(sim, u, str(cmd.get("skill", "")), str(cmd.get("target", "")), false)
			"combat_item":
				use_item(sim, u, str(cmd.get("item", "")), str(cmd.get("target", "")), false)


## target_change: a living, visible enemy or any ally (KO'd ones too, for revives); "" clears.
static func target_change(sim: RtSim, u: RtUnit, target_id: String) -> void:
	if not sim.is_alive(u):
		return
	if target_id != "":
		var t: RtUnit = sim.unit(target_id)
		var ok: bool = t != null and (t.side == u.side or sim.targetable(t))
		if not ok:
			refuse(sim, u, "", "", "target", false)
			return
	if u.target_id != target_id:
		u.target_id = target_id
		var ev: ActionEvent = sim.ev(ActionEvent.Type.TARGET_CHANGED)
		ev.actor_id = u.id
		ev.target_id = target_id
		ev.def_id = sim.def_of(target_id)


## Autopilot on: the sim plays the controlled unit; off: samples count again from the sim position (07 §5.1).
static func autopilot(sim: RtSim, u: RtUnit, on: bool) -> void:
	if u.side != Combatant.Side.PARTY or u.id != sim.controlled_id():
		return
	if on and u.driver == RtUnit.Driver.PLAYER:
		u.driver = RtUnit.Driver.AUTOPILOT
	elif not on and u.driver == RtUnit.Driver.AUTOPILOT:
		u.driver = RtUnit.Driver.PLAYER
		u.sample = [sim.tick(), u.x, u.z, 0, 0, u.yaw]
		u.goal = []


## partner_preset: tactic + switches of an AI party unit (PRESET_CHANGED, rt.tog as 0/1). A new tactic brings its rules
## (party.json rt.presets, keys "<preset>:<index>": the timers of each tactic are kept) and its distance keep_cm
## (≤ 700, 07 §5.5).
static func set_preset(sim: RtSim, u: RtUnit, preset: String, tog: Variant) -> void:
	if not RtVocab.RT_PRESETS.has(preset):
		return
	if u.preset != preset:
		sim.change_preset(u, preset)
	if tog is Dictionary:
		for k: String in RtVocab.RT_TOGGLES:
			if (tog as Dictionary).has(k):
				u.toggles[k] = bool((tog as Dictionary)[k])
	var ev: ActionEvent = sim.ev(ActionEvent.Type.PRESET_CHANGED)
	ev.actor_id = u.id
	ev.text = preset
	var t: Dictionary = {}
	for k: String in RtVocab.RT_TOGGLES:
		t[k] = 1 if bool(u.toggles.get(k, RtVocab.RT_TOGGLE_DEFAULTS.get(k, false))) else 0
	ev.rt = {"tog": t}


## partner_special: buffers the partner's signature for PARTNER_ORDER_TICKS (07 §3.6.13); a new order replaces the old.
static func order_partner(sim: RtSim, u: RtUnit) -> void:
	var skill: String = sim.partner_special_skill(u.id)
	if skill == "":
		refuse(sim, u, "", "", "not_available", false)
		return
	u.partner_order = {"skill": skill, "until": sim.tick() + sim.bal.i("PARTNER_ORDER_TICKS"), "why": ""}


## ACTION_REFUSED (HUD feedback).
static func refuse(sim: RtSim, u: RtUnit, skill_id: String, item_id: String, reason: String, ai: bool) -> void:
	var ev: ActionEvent = sim.ev(ActionEvent.Type.ACTION_REFUSED)
	ev.actor_id = u.id
	ev.skill_id = skill_id
	ev.item_id = item_id
	ev.text = reason
	ev.by_ai = ai


# --- the one check --------------------------------------------------------------------------------------------------

## Pure check of an ability use (07 §3.4 "zwei Prüfstufen", §3.6): {"reason": "" (start now) | "queue" (GCD / cast
## ends within QUEUE_TICKS) | a RtCommand.REASONS entry, "ids": target ids, "primary": main target id, "pick": true
## if the primary was picked automatically (it becomes the current target)}. opener: the pull at ct 0 (no range).
static func check(sim: RtSim, u: RtUnit, skill_id: String, target_id: String, opener: bool = false) -> Dictionary:
	var sk: SkillDef = sim.skill_def(skill_id)
	if sk == null or u == null:
		return _no("not_learned")
	var pre: String = precheck(sim, u, sk)
	if pre != "" and pre != "queue":
		return _no(pre)
	var tr: Dictionary = targets(sim, u, sk, target_id, opener)
	if str(tr["reason"]) != "":
		return tr
	if pre == "queue":
		tr["reason"] = "queue"
	return tr


## The target-free part of check (the rule engine runs it before it resolves a rule target): "" (free), "queue" (GCD /
## cast ends within QUEUE_TICKS) or the refusal reason (dead, not_learned, forbidden, stunned, drinking, cooldown,
## locked, casting, gcd, mp).
static func precheck(sim: RtSim, u: RtUnit, sk: SkillDef) -> String:
	if not sim.is_alive(u):
		return "dead"
	if not sim.knows(u, sk.id):
		return "not_learned"
	if sim.forbidden_skill(u, sk.id):
		return "forbidden"
	if StatusFx.has_flag(u, "no_act"):
		return "stunned"
	var c: int = sim.tick()
	var is_cast: bool = cast_ticks(sim, u, sk) > 0 or channel_ticks(sk) > 0
	if str(u.cast.get("kind", "")) == "item":
		return "drinking"
	if sim.is_show_skill(u, sk.id):
		if sim.show_cd_left() > 0 or sim.show_cast_running(u):
			return "cooldown"
	elif cooldown_left(sim, u, sk.id) > 0:
		return "cooldown"
	if is_cast and (u.lockout_until > c or StatusFx.has_flag(u, "no_cast")):
		return "locked"
	var busy: String = ""
	var busy_left: int = 0
	var gcd: bool = bool(sk.rt.get("gcd", true))
	if not u.cast.is_empty() and (is_cast or gcd):
		busy = "casting"
		busy_left = int(u.cast.get("end", c)) - c
	if gcd and u.gcd_until > c and busy == "":
		busy = "gcd"
		busy_left = u.gcd_until - c
	if busy != "" and busy_left > sim.bal.i("QUEUE_TICKS"):
		return busy
	if u.mp < mp_cost(sk):
		return "mp"
	return "queue" if busy != "" else ""


## Pure target resolution of `sk` for `u` (07 §4.4): {"reason", "ids", "primary", "pick"}; opener: no range check.
static func targets(sim: RtSim, u: RtUnit, sk: SkillDef, target_id: String, opener: bool) -> Dictionary:
	var out: Dictionary = {"reason": "", "ids": PackedStringArray(), "primary": "", "pick": false}
	var rt: Dictionary = sk.rt
	var aoe: Dictionary = rt.get("aoe", {})
	var range_cm: int = int(rt.get("range_cm", 0))
	match sk.target:
		"single_enemy", "all_enemies":
			var radius: int = int(aoe.get("radius_cm", 0))
			var cone: int = int(aoe.get("cone_deg", 0))
			var around_self: bool = sk.target == "all_enemies" and str(aoe.get("center", "self")) == "self"
			var needs_target: bool = sk.target == "single_enemy" or not around_self
			var t: RtUnit = _hostile(sim, u, target_id)
			var pick: bool = false
			if t == null and (needs_target or cone > 0):
				t = auto_pick_enemy(sim, u, range_cm if range_cm > 0 else u.reach)
				pick = t != null
			if t == null and needs_target:
				return _no("target")
			if t != null:
				out["primary"] = t.id
				out["pick"] = pick
				if sim.is_finale(u, sk.id) and t.hp * 1000 >= t.max_hp() * sim.bal.i("FINALE_TARGET_BELOW_PM"):
					out["reason"] = "target_hp"
					return out
				if needs_target and not opener:
					if not in_range(u, t, range_cm if range_cm > 0 else u.reach):
						out["reason"] = "range"
						return out
					if not RtGeo.los(sim.setup.geo, u.x, u.z, t.x, t.z):
						out["reason"] = "los"
						return out
			if sk.target == "single_enemy" and radius <= 0:
				out["ids"] = PackedStringArray([t.id])
			elif around_self:
				var yaw: int = DetMath.yaw_of(t.x - u.x, t.z - u.z) if t != null else u.yaw
				out["ids"] = area(sim, u, u.x, u.z, radius, cone, yaw, int(aoe.get("max_targets", 0)))
			else:
				out["ids"] = area(sim, u, t.x, t.z, radius, 0, 0, int(aoe.get("max_targets", 0)))
		"random_enemy":
			if auto_pick_enemy(sim, u, 1 << 20) == null:
				return _no("target")
		"single_ally":
			var a: RtUnit = _ally(sim, u, target_id, false)
			if a == null:
				return _no("target")
			out["primary"] = a.id
			out["ids"] = PackedStringArray([a.id])
			if range_cm > 0 and a != u and not opener and not in_range(u, a, range_cm):
				out["reason"] = "range"
		"single_ally_ko":
			var k: RtUnit = _ally(sim, u, target_id, true)
			if k == null:
				return _no("target")
			out["primary"] = k.id
			out["ids"] = PackedStringArray([k.id])
			if range_cm > 0 and not opener and not in_range(u, k, range_cm):
				out["reason"] = "range"
		"all_allies":
			var radius_a: int = int(aoe.get("radius_cm", 0))
			var ids: PackedStringArray = []
			for v: RtUnit in sim.units_ref():
				if v.side == u.side and sim.is_alive(v) and (radius_a <= 0 \
						or DetMath.dist(u.x, u.z, v.x, v.z) <= radius_a + v.radius):
					ids.append(v.id)
			out["ids"] = ids
		"self":
			out["primary"] = u.id
			out["ids"] = PackedStringArray([u.id])
	return out


## Party areas hit bodies (07 §4.4): circle — distance ≤ radius + target radius (radius 0 = the whole set); cone —
## distance ≤ length + target radius and the centre inside the opening. Units still walking in (entry) or not on stage
## are not hit. max_targets > 0 keeps the nearest (ties: unit order).
static func area(sim: RtSim, u: RtUnit, cx: int, cz: int, radius: int, cone_deg: int, yaw: int,
		max_targets: int) -> PackedStringArray:
	var hits: Array = []
	for v: RtUnit in sim.units_ref():
		if v.side == u.side or not sim.targetable(v) or not v.entry.is_empty():
			continue
		var d2: int = DetMath.dist2(cx, cz, v.x, v.z)
		if radius > 0:
			var reach: int = radius + v.radius
			if cone_deg > 0:
				if not DetMath.in_cone(v.x, v.z, cx, cz, yaw, reach, cone_deg / 2):
					continue
			elif d2 > reach * reach:
				continue
		hits.append([d2, hits.size(), v.id])
	if max_targets > 0 and hits.size() > max_targets:
		hits.sort_custom(func(a: Array, b: Array) -> bool:
			return int(a[0]) < int(b[0]) or (int(a[0]) == int(b[0]) and int(a[1]) < int(b[1])))
		hits.resize(max_targets)
		hits.sort_custom(func(a: Array, b: Array) -> bool: return int(a[1]) < int(b[1]))
	var out: PackedStringArray = []
	for h: Array in hits:
		out.append(str(h[2]))
	return out


## Without a target (07 §4.4): the nearest enemy in range within ±60° of the facing, else the nearest in range (ties:
## unit order). Pure.
static func auto_pick_enemy(sim: RtSim, u: RtUnit, range_cm: int) -> RtUnit:
	var best_front: RtUnit = null
	var best_front_d: int = -1
	var best: RtUnit = null
	var best_d: int = -1
	var f: Vector2i = DetMath.dir(u.yaw)
	var c60: int = DetMath.cos_deg1024(60)
	for v: RtUnit in sim.units_ref():
		if v.side == u.side or not sim.targetable(v):
			continue
		var d2: int = DetMath.dist2(u.x, u.z, v.x, v.z)
		var reach: int = range_cm + v.radius
		if d2 > reach * reach:
			continue
		if best == null or d2 < best_d:
			best = v
			best_d = d2
		var dot: int = f.x * (v.x - u.x) + f.y * (v.z - u.z)
		if d2 == 0 or (dot >= 0 and dot * dot >= c60 * c60 * d2):
			if best_front == null or d2 < best_front_d:
				best_front = v
				best_front_d = d2
	return best_front if best_front != null else best


## Distance centre to centre ≤ range + target radius (07 §3.6.9).
static func in_range(u: RtUnit, t: RtUnit, range_cm: int) -> bool:
	var reach: int = range_cm + t.radius
	return DetMath.dist2(u.x, u.z, t.x, t.z) <= reach * reach


# --- starting abilities ---------------------------------------------------------------------------------------------

## ability_use (and the queue, the partner order, the AI, the opener): check, then start, queue or refuse. Returns the
## check reason ("" started, "queue" buffered).
static func use_ability(sim: RtSim, u: RtUnit, skill_id: String, target_id: String, ai: bool,
		opener: bool = false) -> String:
	var r: Dictionary = check(sim, u, skill_id, target_id, opener)
	var reason: String = str(r["reason"])
	match reason:
		"":
			start(sim, u, sim.skill_def(skill_id), r, ai)
		"queue":
			u.queued = {"skill": skill_id, "target": target_id, "at": sim.tick()}
		_:
			refuse(sim, u, skill_id, "", reason, ai)
	return reason


## Starts an ability (07 §3.6): ACTION_START, GCD, then a cast / channel (CAST_START) or an instant whose effect lands
## max(1, impact) ticks later (step 5). Instants and channels pay MP and start their cooldown now, casts at their end.
static func start(sim: RtSim, u: RtUnit, sk: SkillDef, r: Dictionary, ai: bool) -> void:
	var c: int = sim.tick()
	var primary: String = str(r.get("primary", ""))
	var ids: PackedStringArray = r.get("ids", PackedStringArray())
	if bool(r.get("pick", false)) and primary != "" and u.target_id != primary:
		target_change(sim, u, primary)
	if not u.queued.is_empty() and str(u.queued.get("skill", "")) == sk.id:
		u.queued = {}
	var show: bool = sim.is_show_skill(u, sk.id)
	var cmd: int = K.STUNT if show or sk.is_stunt() else K.SKILL
	var ev: ActionEvent = sim.ev(ActionEvent.Type.ACTION_START)
	ev.actor_id = u.id
	ev.command = cmd
	ev.skill_id = sk.id
	ev.target_ids = ids
	ev.text = sk.name
	ev.by_ai = ai
	sim.note_action(u, ai)
	u.last_action_key = sk.id
	var t: RtUnit = sim.unit(primary)
	if t != null and t != u:
		u.yaw = DetMath.yaw_of(t.x - u.x, t.z - u.z)
	if bool(sk.rt.get("gcd", true)):
		u.gcd_len = gcd_ticks(sim, u)
		u.gcd_until = c + u.gcd_len
	var chan: int = channel_ticks(sk)
	var cast_t: int = cast_ticks(sim, u, sk)
	if chan > 0 or cast_t > 0:
		if chan > 0:
			_pay(sim, u, sk)
		var period: int = maxi(1, int(sk.rt.get("period_ms", 0)) * 3 / 100) if chan > 0 else 0
		u.cast = {"skill": sk.id, "target": primary, "targets": Array(ids), "x": u.x, "z": u.z, "start": c,
			"end": c + (chan if chan > 0 else cast_t), "interruptible": bool(sk.rt.get("interruptible", true)),
			"worthy": bool(sk.rt.get("interrupt_worthy", false)), "moving_cancels": bool(sk.rt.get("moving_cancels",
			false)), "channel": chan > 0, "period": period, "next_tick": c + period if chan > 0 else -1, "tele": -1,
			"kind": "ability", "item": "", "ai": ai, "cmd": cmd}
		var cs: ActionEvent = sim.ev(ActionEvent.Type.CAST_START)
		cs.actor_id = u.id
		cs.skill_id = sk.id
		cs.target_id = primary
		cs.def_id = sim.def_of(primary)
		cs.value = int(u.cast["end"]) - c
		cs.success = bool(u.cast["interruptible"])
		cs.rt = {"end": int(u.cast["end"]), "worthy": 1 if bool(u.cast["worthy"]) else 0}
		cs.by_ai = ai
		if bool(u.cast["worthy"]) and bool(u.cast["interruptible"]):
			sim.notice_cast(u)
		return
	_pay(sim, u, sk)
	sim.add_hit({"at": c + impact_ticks(sim, sk), "src": u.id, "skill": sk.id, "item": "", "targets": Array(ids),
		"primary": primary, "kind": Damage.Kind.ABILITY, "ai": ai, "cmd": cmd})


## MP and cooldown of an ability (SHOW / FINALE: the party SHOW cooldown).
static func _pay(sim: RtSim, u: RtUnit, sk: SkillDef) -> void:
	var cost: int = mp_cost(sk)
	if cost > 0:
		Damage.change_mp(sim, u, -cost)
	if sim.is_show_skill(u, sk.id):
		sim.start_show_cd()
		return
	var cd: int = int(sk.rt.get("cooldown_ms", 0)) * 3 / 100
	if cd > 0:
		u.cooldowns[sk.id] = [sim.tick() + cd, cd]


# --- items ----------------------------------------------------------------------------------------------------------

## Pure check of a combat item (07 §3.11): {"reason", "ids", "primary", "pick"}. opener: the pull at ct 0 (no range).
static func check_item(sim: RtSim, u: RtUnit, item_id: String, target_id: String, opener: bool = false) -> Dictionary:
	if u == null:
		return _no("unknown_unit")
	if not sim.is_alive(u):
		return _no("dead")
	var it: ItemDef = sim.item_def(item_id)
	var sk: SkillDef = sim.skill_def(it.use_skill) if it != null else null
	if it == null or sk == null or it.type != "consumable" or not (it.usable == "battle" or it.usable == "both"):
		return _no("no_item")
	if sim.forbidden_item(u, item_id):
		return _no("forbidden")
	if StatusFx.has_flag(u, "no_act"):
		return _no("stunned")
	if str(u.cast.get("kind", "")) == "item":
		return _no("drinking")
	if not u.cast.is_empty():
		return _no("casting")
	if sim.items_left() <= 0:
		return _no("items_max")
	if sim.item_cd_left() > 0:
		return _no("item_cd")
	if int(sim.items.get(item_id, 0)) <= 0:
		return _no("no_item")
	var tid: String = target_id
	if tid == "" and (sk.target == "single_ally"):
		var cur: RtUnit = sim.unit(u.target_id)
		tid = u.target_id if cur != null and cur.side == u.side and sim.is_alive(cur) else u.id
	return targets(sim, u, sk, tid, opener)


## combat_item: check, then the drink pause (DRINK_TICKS, GCD free) — the item is used up now, its effect comes at the
## end of the pause (step 6). opener: the pull at ct 0 (no range check).
static func use_item(sim: RtSim, u: RtUnit, item_id: String, target_id: String, ai: bool,
		opener: bool = false) -> String:
	var r: Dictionary = check_item(sim, u, item_id, target_id, opener)
	var reason: String = str(r["reason"])
	if reason != "":
		var it: ItemDef = sim.item_def(item_id)
		refuse(sim, u, it.use_skill if it != null else "", item_id, reason, ai)
		return reason
	var c: int = sim.tick()
	var it2: ItemDef = sim.item_def(item_id)
	var sk: SkillDef = sim.skill_def(it2.use_skill)
	var primary: String = str(r.get("primary", ""))
	if bool(r.get("pick", false)) and primary != "" and u.target_id != primary:
		target_change(sim, u, primary)
	var ev: ActionEvent = sim.ev(ActionEvent.Type.ACTION_START)
	ev.actor_id = u.id
	ev.command = K.ITEM
	ev.skill_id = sk.id
	ev.item_id = item_id
	ev.target_ids = r.get("ids", PackedStringArray())
	ev.text = it2.name
	ev.by_ai = ai
	sim.note_action(u, ai)
	u.last_action_key = item_id
	sim.use_up_item(item_id)
	var drink: int = maxi(1, sim.bal.i("DRINK_TICKS"))
	u.cast = {"skill": sk.id, "target": primary, "targets": Array(r.get("ids", PackedStringArray())), "x": u.x,
		"z": u.z, "start": c, "end": c + drink, "interruptible": false, "worthy": false, "moving_cancels": false,
		"channel": false, "period": 0, "next_tick": -1, "tele": -1, "kind": "item", "item": item_id, "ai": ai,
		"cmd": K.ITEM}
	return ""


## The potion key (07 §3.11): the smallest heal item (tag "heal") that covers the missing HP of the target (current
## friendly target, else the unit), else the biggest; ties by item id. "" if none is left. Pure.
static func potion_pick(sim: RtSim, u: RtUnit) -> String:
	var cur: RtUnit = sim.unit(u.target_id)
	var t: RtUnit = cur if cur != null and cur.side == u.side and sim.is_alive(cur) else u
	var missing: int = t.max_hp() - t.hp
	var ids: Array = sim.items.keys()
	ids.sort()
	var best_cover: String = ""
	var best_cover_amt: int = -1
	var best_big: String = ""
	var best_big_amt: int = -1
	for iid: Variant in ids:
		var it: ItemDef = sim.item_def(str(iid))
		if it == null or int(sim.items[iid]) <= 0 or not it.tags.has("heal"):
			continue
		var sk: SkillDef = sim.skill_def(it.use_skill)
		if sk == null or sk.damage_type != "heal":
			continue
		var amt: int = heal_preview(sim, u, t, sk)
		if amt >= missing and (best_cover_amt < 0 or amt < best_cover_amt):
			best_cover = str(iid)
			best_cover_amt = amt
		if amt > best_big_amt:
			best_big = str(iid)
			best_big_amt = amt
	return best_cover if best_cover != "" else best_big


## Expected heal of `sk` on `t` without the variance draw (pure; the potion pick, the AI).
static func heal_preview(sim: RtSim, u: RtUnit, t: RtUnit, sk: SkillDef) -> int:
	var view: SkillDef = sim.view(sk)
	match view.heal_mode:
		"fixed":
			return FixedMath.mul_pm(view.power, sim.bal.i("FIXED_SCALE_PM"))
		"pct":
			return FixedMath.div_round(t.max_hp() * view.power, 100)
		"mag":
			var base_milli: int = u.stat(StatBlock.Stat.MAG) * FixedMath.pm(Balance.HEAL_STAT_MULT) \
				+ FixedMath.pm(Balance.HEAL_BASE)
			return FixedMath.div_round(base_milli * view.power, 100000)
	return 0


# --- step 5: pending hits, step 6: casts ----------------------------------------------------------------------------

## Step 5 (07 §3.3): instant effects, auto-attacks due at c, creation order; a hit of a KO'd source lapses.
static func resolve_hits(sim: RtSim, c: int) -> void:
	var due: Array[Dictionary] = sim.take_due_hits(c)
	for h: Dictionary in due:
		var src: RtUnit = sim.unit(str(h["src"]))
		var kind: int = int(h["kind"])
		if src == null or not sim.is_alive(src):
			if kind != Damage.Kind.AUTO:
				sim.end_action(str(h["src"]), str(h["skill"]), str(h["item"]))
			continue
		var sk: SkillDef = sim.skill_def(str(h["skill"]))
		if sk == null:
			continue
		var ids: PackedStringArray = PackedStringArray(h["targets"])
		if kind == Damage.Kind.AUTO:
			var t: RtUnit = sim.unit(str(h["primary"]))
			if t != null and sim.is_alive(t):
				Damage.skill_hit(sim, src, t, sk, Damage.Kind.AUTO, bool(h["ai"]), K.ATTACK)
			continue
		resolve_skill(sim, src, sk, ids, bool(h["ai"]), int(h["cmd"]), Damage.Kind.ABILITY, "")
		sim.end_action(src.id, sk.id, "")


## Step 6 (07 §3.3): casts ending at c (effect; MP and cooldown now — CAST_FAILED mp without MP), drinks ending at c
## (the item effect), channel ticks due at c.
static func end_casts(sim: RtSim, c: int) -> void:
	for u: RtUnit in sim.units_ref():
		if u.cast.is_empty() or not sim.is_alive(u):
			continue
		var cast: Dictionary = u.cast
		var sk: SkillDef = sim.skill_def(str(cast.get("skill", "")))
		if sk == null:
			sim.cast_over(u)
			continue
		var ai: bool = bool(cast.get("ai", false))
		if str(cast.get("kind", "")) == "item":
			if int(cast["end"]) == c:
				sim.cast_over(u)
				var ids_i: PackedStringArray = _cast_targets(sim, u, sk, cast)
				resolve_skill(sim, u, sk, ids_i, ai, K.ITEM, Damage.Kind.ITEM, str(cast.get("item", "")))
				sim.end_action(u.id, sk.id, str(cast.get("item", "")))
			continue
		if bool(cast.get("channel", false)):
			if int(cast.get("next_tick", -1)) == c:
				var ids_c: PackedStringArray = _cast_targets(sim, u, sk, cast)
				resolve_skill(sim, u, sk, ids_c, ai, int(cast.get("cmd", K.SKILL)), Damage.Kind.ABILITY, "")
				if is_same(u.cast, cast):
					cast["next_tick"] = c + int(cast.get("period", 1))
			if is_same(u.cast, cast) and int(cast["end"]) <= c:
				sim.cast_over(u)
				sim.end_action(u.id, sk.id, "")
			continue
		if int(cast["end"]) != c:
			continue
		if u.mp < mp_cost(sk):
			sim.fail_cast(u, "mp")
			continue
		var ids: PackedStringArray = _cast_targets(sim, u, sk, cast)
		if ids.is_empty() and (sk.target == "single_enemy" or sk.target == "single_ally" \
				or sk.target == "single_ally_ko"):
			sim.fail_cast(u, "target")
			continue
		sim.cast_over(u)
		_pay(sim, u, sk)
		resolve_skill(sim, u, sk, ids, ai, int(cast.get("cmd", K.SKILL)), Damage.Kind.ABILITY, "")
		sim.end_action(u.id, sk.id, "")


## Targets at the end of a cast / at a channel tick: single targets stay (alive; KO'd for revives), areas are taken
## anew around the caster or the main target.
static func _cast_targets(sim: RtSim, u: RtUnit, sk: SkillDef, cast: Dictionary) -> PackedStringArray:
	var primary: RtUnit = sim.unit(str(cast.get("target", "")))
	var aoe: Dictionary = sk.rt.get("aoe", {})
	var radius: int = int(aoe.get("radius_cm", 0))
	var out: PackedStringArray = []
	match sk.target:
		"single_enemy", "all_enemies":
			var around_self: bool = sk.target == "all_enemies" and str(aoe.get("center", "self")) == "self"
			if sk.target == "single_enemy" and radius <= 0:
				if primary != null and sim.is_alive(primary):
					out.append(primary.id)
			elif around_self:
				var yaw: int = DetMath.yaw_of(primary.x - u.x, primary.z - u.z) if primary != null else u.yaw
				out = area(sim, u, u.x, u.z, radius, int(aoe.get("cone_deg", 0)), yaw, int(aoe.get("max_targets", 0)))
			elif primary != null:
				out = area(sim, u, primary.x, primary.z, radius, 0, 0, int(aoe.get("max_targets", 0)))
		"single_ally":
			if primary != null and sim.is_alive(primary):
				out.append(primary.id)
		"single_ally_ko":
			if primary != null and primary.is_ko():
				out.append(primary.id)
		"all_allies":
			for v: RtUnit in sim.units_ref():
				if v.side == u.side and sim.is_alive(v) and (radius <= 0 \
						or DetMath.dist(u.x, u.z, v.x, v.z) <= radius + v.radius):
					out.append(v.id)
		"self":
			out.append(u.id)
		_:
			for id: Variant in (cast.get("targets", []) as Array):
				out.append(str(id))
	return out


## The effect of an ability / item on its targets (07 §3.9, §4): a SHOW rolls its success (FINALE never fails),
## then per target damage or healing / revive, interrupt, statuses (to "target"), cleanse, MP; statuses to "self" /
## "all_enemies" / "all_allies" once; the smoke bomb flees.
static func resolve_skill(sim: RtSim, u: RtUnit, sk: SkillDef, ids: PackedStringArray, ai: bool, cmd: int,
		kind: int, item_id: String) -> void:
	if sim.is_show_skill(u, sk.id):
		var finale: bool = sim.is_finale(u, sk.id)
		var ok: bool = finale or FixedMath.roll_bp(sim.rng(), stunt_chance_bp(sim, u, sk, ids))
		var sr: ActionEvent = sim.ev(ActionEvent.Type.STUNT_RESULT)
		sr.actor_id = u.id
		sr.skill_id = sk.id
		sr.success = ok
		sr.by_ai = ai
		if not ok:
			_stunt_fail(sim, u, sk, ai)
			return
	var rt: Dictionary = sk.rt
	var damaging: bool = sk.is_damaging() or int(rt.get("pct_maxhp", 0)) > 0
	var sts: Array = rt.get("statuses", [])
	for id: String in ids:
		var t: RtUnit = sim.unit(id)
		if t == null:
			continue
		if damaging:
			if sim.is_alive(t):
				Damage.skill_hit(sim, u, t, sk, kind, ai, cmd, item_id)
		elif sk.damage_type == "heal":
			if t.is_ko():
				if sk.target == "single_ally_ko":
					Damage.revive(sim, u, t, heal_preview(sim, u, t, sk), sk.id)
			else:
				var view: SkillDef = sim.view(sk)
				var amount: int = DamageCalc.heal_amount(u, t, view, sim.rng()) if view.heal_mode == "mag" \
					else heal_preview(sim, u, t, sk)
				Damage.heal(sim, u, t, amount, sk.id, "")
		if not sim.is_alive(t):
			continue
		if bool(rt.get("interrupt", false)):
			sim.interrupt(u, t, ai)
		for s: Variant in sts:
			var sd: Dictionary = s
			if str(sd.get("to", "target")) == "target" and sim.is_alive(t):
				StatusFx.apply(sim, u.id, t, str(sd.get("id", "")), int(sd.get("ms", 0)), int(sd.get("chance_pm", 1000)),
					int(sd.get("tick_power", 0)), sk, false, ai)
		if sim.is_alive(t):
			StatusFx.cleanse(sim, t, rt.get("cleanse", []))
			var mp_gain: int = sk.mp_restore + FixedMath.div_round(t.max_mp() * sk.mp_restore_pct, 100)
			if mp_gain > 0:
				Damage.change_mp(sim, t, mp_gain)
	for s: Variant in sts:
		var sd: Dictionary = s
		var to: String = str(sd.get("to", "target"))
		if to == "target":
			continue
		for v: RtUnit in sim.units_ref():
			var hit: bool = (to == "self" and v == u) or (to == "all_enemies" and v.side != u.side) \
				or (to == "all_allies" and v.side == u.side)
			if hit and sim.is_alive(v) and (v.side == u.side or sim.targetable(v)):
				StatusFx.apply(sim, u.id, v, str(sd.get("id", "")), int(sd.get("ms", 0)), int(sd.get("chance_pm", 1000)),
					int(sd.get("tick_power", 0)), sk, false, ai)
	if sk.flee_guaranteed:
		sim.flee_now(u)


## SHOW success chance in basis points (07 §9.6): clampi(div_round((base + LCK × lck) × stunt_pm, 1000) + boss,
## STUNT_MIN, cap) — the boss term when a target (all targets for areas) is a living enemy boss.
static func stunt_chance_bp(sim: RtSim, u: RtUnit, sk: SkillDef, ids: PackedStringArray) -> int:
	var base: int = FixedMath.bp(sk.success_base) + u.stat(StatBlock.Stat.LCK) * FixedMath.pm(sk.success_lck) * 10
	var chance: int = FixedMath.div_round(base * u.stunt_pm, 1000)
	for id: String in ids:
		var t: RtUnit = sim.unit(id)
		if t != null and t.is_boss and t.side != u.side and sim.is_alive(t):
			chance += FixedMath.pm(sk.success_boss_mod) * 10
			break
	var lo: int = FixedMath.bp(Balance.STUNT_CHANCE_MIN)
	return clampi(chance, lo, maxi(lo, FixedMath.bp(sk.success_cap)))


## A failed SHOW (07 §4.2/4.3): fail_effect.self_dmg_pct % of the own max HP, then the self stun (fail_effect.status,
## default sts_stun) for rt.fail_ms (else the status default) — no resistance roll.
static func _stunt_fail(sim: RtSim, u: RtUnit, sk: SkillDef, ai: bool) -> void:
	var fe: Dictionary = sk.fail_effect
	var pct: int = JsonUtil.to_int(fe.get("self_dmg_pct", 0))
	if pct > 0:
		Damage.self_damage(sim, u, pct, sk.id, ai)
	var ms: int = int(sk.rt.get("fail_ms", 0))
	var sid: String = str(fe.get("status", ""))
	if sim.is_alive(u) and (ms > 0 or sid != ""):
		StatusFx.apply(sim, u.id, u, sid if sid != "" else "sts_stun", ms, 1000, 0, null, true)


# --- step 7: queue, partner order, AI -------------------------------------------------------------------------------

## Step 7 (07 §3.3): per unit the buffered ability once GCD / cast are free, then a buffered partner order, then the
## sim-driven choice (enemies, AI partner, autopilot: RtSim.ai_step). The pull opener runs here at ct 0.
static func queue_and_ai(sim: RtSim, c: int) -> void:
	if c == 0:
		sim.run_opener()
	for u: RtUnit in sim.units_ref():
		if u.hp <= 0 or u.left_battle:
			continue
		if not u.queued.is_empty():
			var q: Dictionary = u.queued
			var r: Dictionary = check(sim, u, str(q.get("skill", "")), str(q.get("target", "")))
			if str(r["reason"]) != "queue":
				u.queued = {}
				if str(r["reason"]) == "":
					start(sim, u, sim.skill_def(str(q["skill"])), r, false)
				else:
					refuse(sim, u, str(q.get("skill", "")), "", str(r["reason"]), false)
		var ordered: bool = false
		if not u.partner_order.is_empty():
			ordered = _partner_order(sim, u, c)
		if u.side == Combatant.Side.ENEMY or u.driver != RtUnit.Driver.PLAYER:
			sim.ai_step(u, ordered)


## The Partner-Spezial (07 §3.6.13): starts as soon as the partner is free (no cast, GCD free if needed, in range —
## else it walks there first) with the normal checks and by_ai = false; a failed check or the end of the order gives
## ACTION_REFUSED. Returns true while it holds the partner's movement (walking into range).
static func _partner_order(sim: RtSim, u: RtUnit, c: int) -> bool:
	var o: Dictionary = u.partner_order
	var skill_id: String = str(o.get("skill", ""))
	var sk: SkillDef = sim.skill_def(skill_id)
	if sk == null:
		u.partner_order = {}
		return false
	var tid: String = ""
	if sk.target == "single_enemy" or sk.target == "all_enemies":
		tid = sim.assist_target(u)
	var r: Dictionary = check(sim, u, skill_id, tid)
	var reason: String = str(r["reason"])
	if reason == "":
		u.partner_order = {}
		start(sim, u, sk, r, false)
		return false
	if c >= int(o.get("until", c)) or not WAIT_REASONS.has(reason):
		u.partner_order = {}
		refuse(sim, u, skill_id, "", "gcd" if reason == "queue" else reason, false)
		return false
	o["why"] = reason
	if reason == "range":
		var t: RtUnit = sim.unit(str(r.get("primary", "")))
		if t != null:
			var reach: int = int(sk.rt.get("range_cm", 0))
			var want: int = maxi(0, (reach if reach > 0 else u.reach) + t.radius - sim.bal.i("MELEE_STOP_CM"))
			var p: Vector2i = DetMath.toward(t.x, t.z, u.x, u.z, want)
			u.goal = [p.x, p.y]
			return true
	return false


# --- step 8: auto-attacks -------------------------------------------------------------------------------------------

## Step 8 (07 §3.6.2): every unit with auto on, a hostile living target in reach, not casting / drinking / stunned /
## dazed and swing_ready ≤ c swings: SWING now, the hit at c + impact (step 5), swing_ready = c + swing time.
## Out of reach an enemy with auto_ranged_skill uses that one. The pull strike swings at ct 0 regardless of reach.
static func auto_attacks(sim: RtSim, c: int) -> void:
	for u: RtUnit in sim.units_ref():
		if not u.auto_on or c < u.swing_ready or u.auto_skill == "" or u.hp <= 0 or u.left_battle:
			continue
		if not u.cast.is_empty() or c < u.pop_in_until or not u.entry.is_empty():
			continue
		if StatusFx.has_flag(u, "no_act"):
			continue
		var t: RtUnit = sim.unit(u.target_id)
		if t == null or t.side == u.side or not sim.targetable(t):
			continue
		var skill_id: String = u.auto_skill
		var forced: bool = c == 0 and sim.opener_strike(u, t)
		if not forced and not in_range(u, t, u.reach):
			var ranged: SkillDef = sim.skill_def(u.auto_ranged_skill)
			if ranged == null or not in_range(u, t, int(ranged.rt.get("range_cm", 0))):
				continue
			skill_id = ranged.id
		var sk: SkillDef = sim.skill_def(skill_id)
		if sk == null:
			continue
		var ai: bool = sim.is_ai_driven(u)
		u.yaw = DetMath.yaw_of(t.x - u.x, t.z - u.z) if (t.x != u.x or t.z != u.z) else u.yaw
		var ev: ActionEvent = sim.ev(ActionEvent.Type.SWING)
		ev.actor_id = u.id
		ev.target_id = t.id
		ev.def_id = t.def_id
		ev.skill_id = skill_id
		sim.add_hit({"at": c + impact_ticks(sim, sk), "src": u.id, "skill": skill_id, "item": "", "targets": [t.id],
			"primary": t.id, "kind": Damage.Kind.AUTO, "ai": ai, "cmd": K.ATTACK})
		u.swing_ready = c + swing_interval(u)


# --- timing ---------------------------------------------------------------------------------------------------------

## GCD of a unit (07 §3.6.1): GCD_TICKS × haste factor of its statuses, never below GCD_MIN_TICKS.
static func gcd_ticks(sim: RtSim, u: RtUnit) -> int:
	return maxi(sim.bal.i("GCD_MIN_TICKS"), FixedMath.mul_pm(sim.bal.i("GCD_TICKS"), StatusFx.factor(u, "haste_pm")))


## Cast time (07 §3.6.3): cast_ms × 3 / 100 × haste, at least CAST_MIN_TICKS; 0 for instants.
static func cast_ticks(sim: RtSim, u: RtUnit, sk: SkillDef) -> int:
	var t: int = int(sk.rt.get("cast_ms", 0)) * 3 / 100
	if t <= 0:
		return 0
	return maxi(sim.bal.i("CAST_MIN_TICKS"), FixedMath.mul_pm(t, StatusFx.factor(u, "haste_pm")))


static func channel_ticks(sk: SkillDef) -> int:
	return int(sk.rt.get("channel_ms", 0)) * 3 / 100


## Effect delay of an instant (07 §3.6.7): rt.impact_ms, else IMPACT_TICKS by animation; at least 1 tick.
static func impact_ticks(sim: RtSim, sk: SkillDef) -> int:
	var ms: int = int(sk.rt.get("impact_ms", -1))
	var t: int = ms * 3 / 100 if ms >= 0 else sim.bal.sub("IMPACT_TICKS", _anim_kind(sk.anim))
	return maxi(1, t)


static func _anim_kind(anim: String) -> String:
	match anim:
		"cast", "stunt", "item":
			return anim
	return "attack"


## Swing time (07 §3.6.2): swing_ticks × haste factor, at least 1.
static func swing_interval(u: RtUnit) -> int:
	return maxi(1, FixedMath.mul_pm(u.swing_ticks, StatusFx.factor(u, "haste_pm")))


static func mp_cost(sk: SkillDef) -> int:
	return maxi(0, int(sk.rt.get("mp", sk.mp_cost)))


static func cooldown_left(sim: RtSim, u: RtUnit, skill_id: String) -> int:
	var cd: Variant = u.cooldowns.get(skill_id, null)
	return maxi(0, int((cd as Array)[0]) - sim.tick()) if cd is Array and (cd as Array).size() == 2 else 0


# --- private --------------------------------------------------------------------------------------------------------

static func _no(reason: String) -> Dictionary:
	return {"reason": reason, "ids": PackedStringArray(), "primary": "", "pick": false}


## The hostile target of a command / the unit (explicit id, else its current target), if valid.
static func _hostile(sim: RtSim, u: RtUnit, target_id: String) -> RtUnit:
	var t: RtUnit = sim.unit(target_id if target_id != "" else u.target_id)
	if t != null and t.side != u.side and sim.targetable(t):
		return t
	return null


## The friendly target (07 §4.4): explicit / current friendly target (alive, or KO'd for ko); else the lowest HP share
## (ties: the controlled unit, then slot) or the KO'd ally with the smallest slot.
static func _ally(sim: RtSim, u: RtUnit, target_id: String, ko: bool) -> RtUnit:
	var t: RtUnit = sim.unit(target_id if target_id != "" else u.target_id)
	if t != null and t.side == u.side and (t.is_ko() if ko else sim.is_alive(t)):
		return t
	if target_id != "":
		return null
	var best: RtUnit = null
	for v: RtUnit in sim.units_ref():
		if v.side != u.side:
			continue
		if ko:
			if v.is_ko() and best == null:
				best = v
			continue
		if not sim.is_alive(v):
			continue
		if best == null:
			best = v
			continue
		var lhs: int = v.hp * best.max_hp()
		var rhs: int = best.hp * v.max_hp()
		if lhs < rhs or (lhs == rhs and v.id == sim.controlled_id()):
			best = v
	return best
