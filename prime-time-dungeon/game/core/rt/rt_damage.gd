extends RefCounted
## Damage, healing, MP and KOs of the real-time combat (07 §3.9, §3.10) — private helper of RtSim (no class_name;
## preloaded as Damage). Every formula hit uses DamageCalc unchanged (GDD §3.7); the real-time factors are folded one
## by one around it (fold, 07 §3.9.1 / E4); percent hits carry the element of their skill (E30).

const FixedMath := preload("res://core/stats/fixed_math.gd")
const StatusFx := preload("res://core/rt/rt_status_fx.gd")
const Threat := preload("res://core/rt/rt_threat.gd")

## What caused a hit: decides KO.command, the hit MP of "hit" units, combos and the bookkeeping.
enum Kind { AUTO, ABILITY, ITEM, STATUS, ZONE, TELEGRAPH, SELF }


## 07 §3.9.1: f = 1000; every factor ≠ 1000 folds in with mul_pm, clamped to 0…cap after each step; the result is
## `base` for f = 1000 (no rounding step), 0 for base 0 (immunity) or f 0, else max(1, mul_pm(base, f)).
static func fold(base: int, factors: Array[int], cap: int) -> int:
	var f: int = 1000
	for x: int in factors:
		if x != 1000:
			f = clampi(FixedMath.mul_pm(f, x), 0, cap)
	if f == 1000:
		return base
	if base <= 0 or f == 0:
		return 0
	return maxi(1, FixedMath.mul_pm(base, f))


## The folded factor alone (tests, HUD previews).
static func fold_factor(factors: Array[int], cap: int) -> int:
	var f: int = 1000
	for x: int in factors:
		if x != 1000:
			f = clampi(FixedMath.mul_pm(f, x), 0, cap)
	return f


## A formula (physical / magical) or fixed hit of `sk` from `src` on `tgt` (07 §3.9.1): DamageCalc with the real-time
## power (× the unit's RtMods power factor), then the fold [dmg_dealt_pm of src, dmg_taken_pm of tgt (per status and
## stack), dmg_pm (enemy sources), opener_pm (PREEMPTIVE: dazed targets and the first damaging hit), COMBO_PM, the
## RtMods factors (src dmg_dealt_pm, tgt dmg_taken_pm, its first_hit_taken_pm once)]. Percent skills (rt.pct_maxhp)
## go to pct_hit. Returns the damage dealt (all hits of the skill).
static func skill_hit(sim: RtSim, src: RtUnit, tgt: RtUnit, sk: SkillDef, kind: int, ai: bool, cmd: int,
		item_id: String = "") -> int:
	if sk == null or tgt == null or not sim.is_alive(tgt):
		return 0
	var pct: int = int(sk.rt.get("pct_maxhp", 0))
	if pct > 0:
		return pct_hit(sim, src, tgt, sk, pct, kind, ai, cmd)
	var view: SkillDef = sim.view_for(src, sk)
	var element: String = src.attack_element if src.side == Combatant.Side.PARTY and sk.id == src.attack_skill \
		else sk.element
	var combo: bool = kind == Kind.ABILITY and src.side == Combatant.Side.PARTY and _combo(sim, src, tgt)
	var total: int = 0
	for _h in maxi(1, sk.hits):
		if not sim.is_alive(tgt):
			break
		var r: HitResult
		var enemy_src: bool = src.side == Combatant.Side.ENEMY
		if sk.damage_type == "fixed":
			var value: int = FixedMath.mul_pm(view.power, sim.bal.i("FIXED_SCALE_PM"))
			r = DamageCalc.fixed(tgt, value, element, sim.setup.enemy_dmg_mult) if enemy_src \
				else DamageCalc.fixed(tgt, value, element)
		elif enemy_src:
			r = DamageCalc.compute(src, tgt, view, element, sim.rng(), false, sim.setup.enemy_dmg_mult)
		else:
			r = DamageCalc.compute(src, tgt, view, element, sim.rng())
		var factors: Array[int] = []
		StatusFx.factor_list(src, "dmg_dealt_pm", factors)
		StatusFx.factor_list(tgt, "dmg_taken_pm", factors)
		if enemy_src:
			factors.append(src.dmg_pm)
		if _opener_applies(sim, src, tgt):
			factors.append(src.opener_pm)
		if combo:
			factors.append(sim.bal.i("COMBO_PM"))
		sim.mod_factors(src, tgt, true, factors)
		var amount: int = fold(r.amount, factors, sim.bal.i("DMG_FACTOR_MAX_PM"))
		if src.side == Combatant.Side.PARTY and amount > 0:
			src.opener_done = true
		apply(sim, src, tgt, amount, element, r, sk.id, "", item_id, kind, ai, cmd, int(sk.rt.get("threat_pm", 1000)))
		total += amount
	return total


## Percent hit (07 §3.9.1, E30): base = max_hp(tgt) × pct / 100 without formula, crit, variance and dmg_pm; folded:
## first the target's element factor for the skill's element (500…1500 ‰, immunity counts as 500; no element → no
## step), then enemy_dmg_mult of an enemy source (the difficulty: Vorabend, tutorial — decided after I1), then the
## target's dmg_taken_pm factors (statuses, then RtMods incl. its first hit), then sts_guard as PCT_GUARD_PM (unless
## rt.ignore_guard).
static func pct_hit(sim: RtSim, src: RtUnit, tgt: RtUnit, sk: SkillDef, pct: int, kind: int, ai: bool,
		cmd: int) -> int:
	if tgt == null or not sim.is_alive(tgt):
		return 0
	var factors: Array[int] = []
	var r: HitResult = HitResult.new()
	var elem: int = pct_element_pm(tgt, sk.element)
	if sk.element != "" and sk.element != Elements.NONE:
		factors.append(elem)
		r.weak = elem > 1000
		r.resist = elem < 1000
	if src != null and src.side == Combatant.Side.ENEMY:
		factors.append(FixedMath.pm(sim.setup.enemy_dmg_mult))
	StatusFx.factor_list(tgt, "dmg_taken_pm", factors)
	sim.mod_factors(src, tgt, false, factors)
	if tgt.has_flag("guard") and not bool(sk.rt.get("ignore_guard", false)):
		factors.append(sim.bal.i("PCT_GUARD_PM"))
	var amount: int = fold(FixedMath.div_round(tgt.max_hp() * pct, 100), factors, sim.bal.i("DMG_FACTOR_MAX_PM"))
	apply(sim, src, tgt, amount, sk.element, r, sk.id, "", "", kind, ai, cmd, int(sk.rt.get("threat_pm", 1000)))
	return amount


## E30: the element factor of a percent hit, clamped to 500…1500 ‰, immunity counts as 500 ("none" → 1000).
static func pct_element_pm(tgt: RtUnit, element: String) -> int:
	if element == "" or element == Elements.NONE:
		return 1000
	var pm: int = Elements.multiplier_pm(tgt.element_mods, element)
	return 500 if pm <= 0 else clampi(pm, 500, 1500)


## A periodic status hit (07 §3.8): `amount` already holds stacks, element and boss factor; the target's dmg_taken_pm
## (statuses, RtMods incl. its first hit) folds in. The DAMAGE event has no actor (status tick, like CTB), the KO
## names the status source with command −1.
static func status_damage(sim: RtSim, src_id: String, tgt: RtUnit, amount: int, def: StatusDef) -> void:
	if tgt == null or not sim.is_alive(tgt):
		return
	var factors: Array[int] = []
	StatusFx.factor_list(tgt, "dmg_taken_pm", factors)
	sim.mod_factors(null, tgt, false, factors)
	var amt: int = fold(amount, factors, sim.bal.i("DMG_FACTOR_MAX_PM"))
	var r: HitResult = HitResult.new()
	r.immune = amount <= 0
	apply(sim, sim.unit(src_id), tgt, amt, def.element, r, "", def.id, "", Kind.STATUS, false, -1, 1000)


## Self damage of a failed stunt: pct % of the unit's own max HP (07 §4.2).
static func self_damage(sim: RtSim, u: RtUnit, pct: int, skill_id: String, ai: bool) -> void:
	var amt: int = FixedMath.div_round(u.max_hp() * pct, 100)
	if amt > 0:
		apply(sim, u, u, amt, Elements.NONE, HitResult.new(), skill_id, "", "", Kind.SELF, ai,
			BattleCommand.Kind.STUNT, 0)


## Applies `amount` damage (DAMAGE event, HP, tutorial floor, bookkeeping, threat, hit MP, KO). `src` may be null.
static func apply(sim: RtSim, src: RtUnit, tgt: RtUnit, amount: int, element: String, r: HitResult, skill_id: String,
		status_id: String, item_id: String, kind: int, ai: bool, cmd: int, skill_threat_pm: int) -> void:
	var ev: ActionEvent = sim.ev_target(ActionEvent.Type.DAMAGE, tgt)
	if kind != Kind.STATUS and src != null:
		ev.actor_id = src.id
	ev.amount = amount
	ev.element = element
	ev.crit = r.crit
	ev.weak = r.weak
	ev.resist = r.resist
	ev.immune = r.immune
	ev.skill_id = skill_id
	ev.status_id = status_id
	ev.item_id = item_id
	var before: int = tgt.hp
	var after: int = maxi(0, before - amount)
	if sim.setup.tutorial and tgt.side == Combatant.Side.PARTY:
		after = maxi(1, after)
	tgt.hp = after
	ev.hp_after = after
	ev.max_hp = tgt.max_hp()
	var tally: Dictionary = sim.tally
	if tgt.side == Combatant.Side.PARTY:
		tally["damage_taken"] = int(tally["damage_taken"]) + (before - after)
	elif src != null and src.side == Combatant.Side.PARTY:
		if r.crit:
			tally["crits"] = int(tally["crits"]) + 1
		if r.weak and element != "":
			tally["weakness_hits"] = int(tally["weakness_hits"]) + 1
			var wf: Dictionary = tally["weak_found"]
			var known: Array = wf.get(tgt.def_id, [])
			if not known.has(element):
				known.append(element)
				known.sort()
			wf[tgt.def_id] = known
		Threat.on_damage(src, tgt, amount, skill_threat_pm)
	if src != null and src != tgt and kind == Kind.AUTO and src.side == Combatant.Side.PARTY:
		_hit_mp(sim, src, false)
	if after > 0 and tgt.side == Combatant.Side.PARTY and (kind == Kind.AUTO or kind == Kind.ABILITY \
			or kind == Kind.TELEGRAPH or kind == Kind.ITEM) and src != null and src.side != tgt.side:
		_hit_mp(sim, tgt, true)
	if after == 0 and before > 0:
		var overkill: bool = amount * 1000 >= sim.bal.i("OVERKILL_PM") * tgt.max_hp()
		var kcmd: int = cmd
		match kind:
			Kind.AUTO:
				kcmd = BattleCommand.Kind.ATTACK
			Kind.STATUS, Kind.ZONE, Kind.TELEGRAPH:
				kcmd = -1
		ko(sim, tgt, src, skill_id, item_id, amount, overkill, kcmd, ai)


## "hit" MP (07 §3.10): +amount per own landed auto-attack; +taken per taken hit, at most once per
## taken_every_ticks.
static func _hit_mp(sim: RtSim, u: RtUnit, taken: bool) -> void:
	if str(u.mp_regen.get("mode", "")) != "hit" or not sim.is_alive(u):
		return
	if not taken:
		change_mp(sim, u, int(u.mp_regen.get("amount", 0)))
		return
	var c: int = sim.tick()
	if c < u.mp_hit_ready:
		return
	if change_mp(sim, u, int(u.mp_regen.get("taken", 0))) != 0:
		var every: int = int(u.mp_regen.get("taken_every_ticks", 0))
		u.mp_hit_ready = c + (every if every > 0 else sim.bal.i("HIT_MP_EVERY_TICKS"))


## Heals `tgt` by up to `amount` × its RtMods heal_taken_pm (capped at the missing HP): HEAL with the effective
## amount, heal threat of a party source. 0 for a KO'd / full target (no event).
static func heal(sim: RtSim, src: RtUnit, tgt: RtUnit, amount: int, skill_id: String, status_id: String) -> int:
	if tgt == null or not sim.is_alive(tgt) or amount <= 0:
		return 0
	var h: int = mini(sim.heal_taken(tgt, amount), tgt.max_hp() - tgt.hp)
	if h <= 0:
		return 0
	tgt.hp += h
	var ev: ActionEvent = sim.ev_target(ActionEvent.Type.HEAL, tgt)
	ev.actor_id = src.id if src != null and status_id == "" else ""
	ev.amount = h
	ev.hp_after = tgt.hp
	ev.max_hp = tgt.max_hp()
	ev.skill_id = skill_id
	ev.status_id = status_id
	if src != null:
		Threat.on_heal(sim, src, h)
	return h


## Revives a KO'd unit with `hp` (at least 1) and the "Comeback" guard (REVIVE_GUARD_MS, 07 §2.6).
static func revive(sim: RtSim, src: RtUnit, tgt: RtUnit, hp: int, skill_id: String) -> void:
	if tgt == null or not tgt.is_ko():
		return
	tgt.hp = clampi(hp, 1, tgt.max_hp())
	tgt.ko_at = -1
	tgt.swing_ready = sim.tick() + 1
	var ev: ActionEvent = sim.ev_target(ActionEvent.Type.REVIVE, tgt)
	ev.actor_id = src.id if src != null else ""
	ev.skill_id = skill_id
	ev.hp_after = tgt.hp
	ev.max_hp = tgt.max_hp()
	StatusFx.apply(sim, src.id if src != null else tgt.id, tgt, "sts_guard", sim.bal.i("REVIVE_GUARD_MS"), 1000, 0,
		null, true)


## MP change clamped to 0…max (MP_CHANGE with the effective delta; none for 0). Returns the delta.
static func change_mp(sim: RtSim, u: RtUnit, delta: int) -> int:
	if u == null or delta == 0:
		return 0
	var before: int = u.mp
	u.mp = clampi(u.mp + delta, 0, u.max_mp())
	var d: int = u.mp - before
	if d != 0:
		var ev: ActionEvent = sim.ev_target(ActionEvent.Type.MP_CHANGE, u)
		ev.amount = d
		ev.mp_after = u.mp
	return d


## KO (07 §2.6, §3.3): the unit loses every status, its cast fails, its queue and orders are dropped (its pending hits
## lapse when they come due), its pending telegraphs end (TELEGRAPH_CANCELLED; its zones stay); party: threat reset, KO
## count, control follows life; enemies: kill bookkeeping and the controlled unit's automatic retarget.
static func ko(sim: RtSim, tgt: RtUnit, src: RtUnit, skill_id: String, item_id: String, amount: int, overkill: bool,
		cmd: int, ai: bool) -> void:
	var c: int = sim.tick()
	tgt.hp = 0
	tgt.ko_at = c
	var ev: ActionEvent = sim.ev_target(ActionEvent.Type.KO, tgt)
	ev.actor_id = src.id if src != null else ""
	ev.skill_id = skill_id
	ev.item_id = item_id
	ev.amount = amount
	ev.max_hp = tgt.max_hp()
	ev.value = 1 if overkill else 0
	ev.command = cmd
	ev.by_ai = ai
	if not tgt.cast.is_empty():
		sim.fail_cast(tgt, "dead")
	sim.drop_telegraphs(tgt)
	tgt.queued = {}
	tgt.partner_order = {}
	tgt.follow_up = {}
	tgt.goal = []
	tgt.react_at = -1
	tgt.outside_since = -1
	StatusFx.clear_all(tgt)
	var tally: Dictionary = sim.tally
	if tgt.side == Combatant.Side.PARTY:
		tally["party_kos"] = int(tally["party_kos"]) + 1
		Threat.on_ko(sim, tgt)
		if tgt.id == sim.controlled_id():
			sim.control_follows_life(tgt)
	else:
		(tally["killed"] as Array).append(tgt.id)
		if overkill:
			(tally["overkill"] as Array).append(tgt.id)
		sim.retarget_after_kill(tgt)


## Combo (07 §3.9.1): both party members hit the same target with damaging abilities within COMBO_WINDOW_TICKS —
## the second hit is a combo (COMBO event, × COMBO_PM), at most one per COMBO_COOLDOWN_TICKS.
static func _combo(sim: RtSim, src: RtUnit, tgt: RtUnit) -> bool:
	var c: int = sim.tick()
	var last: Array = sim.combo.get(tgt.id, [])
	var hit: bool = false
	if last.size() == 2 and str(last[0]) != src.id and c - int(last[1]) <= sim.bal.i("COMBO_WINDOW_TICKS") \
			and c >= sim.combo_ready:
		hit = true
		sim.combo_ready = c + sim.bal.i("COMBO_COOLDOWN_TICKS")
		var ev: ActionEvent = sim.ev_target(ActionEvent.Type.COMBO, tgt)
		ev.actor_id = src.id
	sim.combo[tgt.id] = [src.id, c]
	return hit


## "Erster Eindruck" (07 §9.6): with a PREEMPTIVE start opener_pm folds into every hit of the unit on a dazed target
## and into its first damaging hit of the combat.
static func _opener_applies(sim: RtSim, src: RtUnit, tgt: RtUnit) -> bool:
	if src.side != Combatant.Side.PARTY or src.opener_pm == 1000:
		return false
	if sim.setup.advantage != BattleSetup.Advantage.PREEMPTIVE:
		return false
	return not src.opener_done or StatusFx.find(tgt, "sts_dazed") != null
