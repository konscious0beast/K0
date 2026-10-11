extends RefCounted
## Status engine of the real-time combat (07 §3.8) — private helper of RtSim (no class_name; preloaded as StatusFx):
## applying (immunity, resistance, chance, stack modes, excludes, flags), periodic effects (power ticks frozen at the
## application, percent ticks with min / max), expiry, cleansing, and the factors statuses fold into speed, haste and
## damage (per stack, application order). Statuses without an `rt` block use the 07 §4.7 defaults.

const FixedMath := preload("res://core/stats/fixed_math.gd")
const Threat := preload("res://core/rt/rt_threat.gd")

const MICRO: int = 1000000

const STACKED_KEYS: PackedStringArray = ["move_pm", "haste_pm", "dmg_dealt_pm", "dmg_taken_pm"]


## `rt` value of a status def with the 07 §4.7 default.
static func rt_of(def: StatusDef, key: String, dflt: Variant) -> Variant:
	return def.rt.get(key, dflt) if def != null else dflt


## Duration of one application in ticks: ms 0 → rt.default_ms, −1 → until the end of the combat (−1); bosses ×
## rt.boss_ms_pm; at least 1 tick.
static func duration_ticks(def: StatusDef, ms: int, tgt: RtUnit) -> int:
	var m: int = ms if ms != 0 else int(rt_of(def, "default_ms", 3000))
	if m < 0:
		return -1
	var t: int = m * 3 / 100
	if tgt != null and tgt.is_boss:
		t = FixedMath.mul_pm(t, int(rt_of(def, "boss_ms_pm", 1000)))
	return maxi(1, t)


## Applies `status_id` from `src_id` to `tgt` (07 §3.8): immunity (status_immune or element immunity) and a resisted
## roll give STATUS_BLOCKED, a failed chance roll nothing; an active status follows its stack_mode (refresh: new end,
## +1 stack up to max_stacks; replace: new end, 1 stack; ignore: STATUS_BLOCKED) and keeps its period phase.
## tick_power > 0 freezes the power tick (formula of `power_skill`'s damage type, element of the status, no crit and
## variance) into RtStatus.amount. force: no resistance roll (start daze, a SHOW's self stun, the revive guard);
## ai: by_ai of the action (an interrupt_on_apply interrupt). Returns the active status or null.
static func apply(sim: RtSim, src_id: String, tgt: RtUnit, status_id: String, ms: int, chance_pm: int,
		tick_power: int = 0, power_skill: SkillDef = null, force: bool = false, ai: bool = false) -> RtStatus:
	var def: StatusDef = sim.status_def(status_id)
	if def == null or tgt == null or not sim.is_alive(tgt):
		return null
	var immune: bool = tgt.status_immune.has(status_id)
	if def.element != Elements.NONE and Elements.multiplier_pm(tgt.element_mods, def.element) <= 0:
		immune = true
	if immune:
		_blocked(sim, tgt, status_id, "immune")
		return null
	var resist_bp: int = FixedMath.bp(JsonUtil.to_float(tgt.status_resist.get(status_id, 0)))
	if not force and resist_bp > 0 and FixedMath.roll_bp(sim.rng(), resist_bp):
		_blocked(sim, tgt, status_id, "resist")
		return null
	if chance_pm < 1000 and not FixedMath.roll_bp(sim.rng(), maxi(0, chance_pm) * 10):
		return null
	var c: int = sim.tick()
	var dur: int = duration_ticks(def, ms, tgt)
	var ends: int = -1 if dur < 0 else c + dur
	var st: RtStatus = find(tgt, status_id)
	if st != null:
		match str(rt_of(def, "stack_mode", "replace")):
			"ignore":
				_blocked(sim, tgt, status_id, "active")
				return null
			"refresh":
				st.stacks = mini(st.stacks + 1, maxi(1, int(rt_of(def, "max_stacks", 1))))
			_:
				st.stacks = 1
		st.ends_at = ends
		st.source_id = src_id
	else:
		for ex: String in def.excludes:
			if ex != status_id:
				remove(sim, tgt, ex)
		st = RtStatus.new(def, ends, src_id)
		st.period = int(rt_of(def, "period_ms", 0)) * 3 / 100
		st.next_tick_at = c + st.period if st.period > 0 else -1
		st.applied_at = c
		tgt.statuses.append(st)
	if tick_power > 0:
		st.amount = power_tick_amount(sim, sim.unit(src_id), tgt, power_skill, def.element, tick_power)
	var ev: ActionEvent = sim.ev_target(ActionEvent.Type.STATUS_ADDED, tgt)
	ev.actor_id = src_id
	ev.status_id = status_id
	ev.value = dur
	ev.rt = {"stacks": st.stacks, "end": ends}
	var src: RtUnit = sim.unit(src_id)
	var flags: Array = rt_of(def, "flags", [])
	if flags.has("interrupt_on_apply"):
		sim.interrupt(src, tgt, ai)
	if flags.has("fixate") and src != null and src.side != tgt.side:
		Threat.taunt(sim, src, tgt, ends)
	if def.kind == "debuff" and src != null and src.side == Combatant.Side.PARTY and tgt.side == Combatant.Side.ENEMY:
		Threat.add(tgt, src.id, sim.bal.i("DEBUFF_THREAT"))
	return st


## The RtStatus with `status_id` on `u` (null if none).
static func find(u: RtUnit, status_id: String) -> RtStatus:
	for s: StatusEffect in u.statuses:
		if s is RtStatus and s.id() == status_id:
			return s as RtStatus
	return null


## Removes `status_id` (STATUS_REMOVED); false if it was not active.
static func remove(sim: RtSim, u: RtUnit, status_id: String) -> bool:
	for i in u.statuses.size():
		if u.statuses[i].id() == status_id:
			u.statuses.remove_at(i)
			var ev: ActionEvent = sim.ev_target(ActionEvent.Type.STATUS_REMOVED, u)
			ev.status_id = status_id
			_after_removal(u)
			return true
	return false


## Removes every status (KO, end): no events — the KO / BATTLE_END event says it.
static func clear_all(u: RtUnit) -> void:
	u.statuses.clear()
	u.fixate_id = ""
	u.fixate_until = 0


## Step 2 (07 §3.3): per unit and status in application order the periodic effect when next_tick_at == c (then
## next_tick_at += period), then the expiry when ends_at == c (a tick on ends_at acts before the expiry).
static func tick_all(sim: RtSim, c: int) -> void:
	for u: RtUnit in sim.units_ref():
		if u.statuses.is_empty() or not sim.is_alive(u):
			continue
		var i: int = 0
		while i < u.statuses.size():
			var st: RtStatus = u.statuses[i] as RtStatus
			if st == null:
				i += 1
				continue
			if st.period > 0 and st.next_tick_at == c:
				st.next_tick_at += st.period
				periodic(sim, u, st)
				if not sim.is_alive(u):
					break
			if i < u.statuses.size() and u.statuses[i] == st and st.ends_at == c:
				u.statuses.remove_at(i)
				var ev: ActionEvent = sim.ev_target(ActionEvent.Type.STATUS_REMOVED, u)
				ev.status_id = st.id()
				_after_removal(u)
				continue
			i += 1


## One periodic effect per stack (07 §3.8): power ticks (frozen amount × stacks), else percent ticks
## max(tick_min, max_hp × |tick_pct| / 100) capped at tick_max, × stacks; on bosses × boss_tick_pm. Damage carries the
## status element (percent ticks: element factor here, power ticks: frozen with it) and folds dmg_taken_pm.
static func periodic(sim: RtSim, u: RtUnit, st: RtStatus) -> void:
	var def: StatusDef = st.def
	var stacks: int = maxi(1, st.stacks)
	var boss_pm: int = int(rt_of(def, "boss_tick_pm", 1000)) if u.is_boss else 1000
	if st.amount > 0:
		var amt: int = FixedMath.mul_pm(st.amount * stacks, boss_pm)
		sim.status_damage(st.source_id, u, amt, def)
		return
	var pct: int = int(rt_of(def, "tick_pct", 0))
	if pct == 0:
		return
	var per: int = maxi(int(rt_of(def, "tick_min", 0)), FixedMath.div_round(u.max_hp() * absi(pct), 100))
	var cap: int = int(rt_of(def, "tick_max", 0))
	if cap > 0:
		per = mini(per, cap)
	var total: int = FixedMath.mul_pm(per * stacks, boss_pm)
	if pct > 0:
		sim.heal_unit(sim.unit(st.source_id), u, total, "", def.id)
		return
	var elem: int = Elements.multiplier_pm(u.element_mods, def.element)
	sim.status_damage(st.source_id, u, FixedMath.mul_pm(total, elem) if elem != 1000 else total, def)


## Frozen power tick (07 §3.8): A²/(A + D·guard) × tick_power / 100 × element, without crit and variance; A/D by the
## damage type of the applying skill (magical: MAG vs RES, else STR vs DEF); immune → 0, else at least 1.
static func power_tick_amount(_sim: RtSim, src: RtUnit, tgt: RtUnit, skill: SkillDef, element: String,
		power: int) -> int:
	if src == null or tgt == null:
		return 0
	var elem: int = Elements.multiplier_pm(tgt.element_mods, element)
	if elem <= 0:
		return 0
	var magical: bool = skill != null and skill.damage_type == "magical"
	var a: int = src.stat(StatBlock.Stat.MAG if magical else StatBlock.Stat.STR)
	var d: int = tgt.stat(StatBlock.Stat.RES if magical else StatBlock.Stat.DEF)
	var guard_pm: int = guard_def_pm() if tgt.has_flag("guard") else 1000
	var den: int = a * 1000 + d * guard_pm
	if den <= 0:
		return 0
	var micro: int = FixedMath.div_round(a * a * power * 10000 * 1000, den)
	return maxi(1, FixedMath.div_round(FixedMath.mul_pm(micro, elem), MICRO))


## Guarded DEF/RES factor in ‰ (sts_guard, Balance.GUARD_DEF_MULT — the CTB value, 07 §3.8 "bestehend").
static func guard_def_pm() -> int:
	return FixedMath.pm(Balance.GUARD_DEF_MULT)


## Removes the statuses of `ids` that are active (cleanse, 07 §3.8).
static func cleanse(sim: RtSim, u: RtUnit, ids: Array) -> void:
	for sid: Variant in ids:
		remove(sim, u, str(sid))


## Product of a per-stack factor over the statuses (application order, mul_pm step by step, never below 0).
static func factor(u: RtUnit, key: String) -> int:
	var f: int = 1000
	for s: StatusEffect in u.statuses:
		if s.def == null or s.def.rt.is_empty():
			continue
		var x: int = int(s.def.rt.get(key, 1000))
		if x == 1000:
			continue
		var n: int = (s as RtStatus).stacks if s is RtStatus else 1
		for _i in maxi(1, n):
			f = maxi(0, FixedMath.mul_pm(f, x))
	return f


## The per-stack factors of `key` as a list (damage fold, 07 §3.9.1), application order, neutral ones left out.
static func factor_list(u: RtUnit, key: String, out: Array[int]) -> void:
	for s: StatusEffect in u.statuses:
		if s.def == null or s.def.rt.is_empty():
			continue
		var x: int = int(s.def.rt.get(key, 1000))
		if x == 1000:
			continue
		var n: int = (s as RtStatus).stacks if s is RtStatus else 1
		for _i in maxi(1, n):
			out.append(x)


## Any active status carries the real-time flag (07 §4.7: no_act, no_move, no_cast, fixate, …).
static func has_flag(u: RtUnit, flag: String) -> bool:
	for s: StatusEffect in u.statuses:
		if s.def != null and not s.def.rt.is_empty() and (s.def.rt.get("flags", []) as Array).has(flag):
			return true
	return false


## A taunt ends with its fixate status (expired or cleansed).
static func _after_removal(u: RtUnit) -> void:
	if u.fixate_id != "" and not has_flag(u, "fixate"):
		u.fixate_id = ""
		u.fixate_until = 0


static func _blocked(sim: RtSim, tgt: RtUnit, status_id: String, why: String) -> void:
	var ev: ActionEvent = sim.ev_target(ActionEvent.Type.STATUS_BLOCKED, tgt)
	ev.status_id = status_id
	ev.text = why
