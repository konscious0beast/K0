extends RefCounted
## Threat lists, taunts and the target choice of enemies (07 §3.7) — private helper of RtSim (no class_name;
## preloaded as Threat). Threat lives on the enemy (RtUnit.threat: party unit id → int); everything iterates the units
## in their stable order, never the dictionary.

const FixedMath := preload("res://core/stats/fixed_math.gd")


static func add(e: RtUnit, uid: String, amount: int) -> void:
	if e == null or uid == "" or amount <= 0:
		return
	e.threat[uid] = int(e.threat.get(uid, 0)) + amount


static func of(e: RtUnit, uid: String) -> int:
	return int(e.threat.get(uid, 0))


## Damage of `src` on enemy `tgt`: amount × threat_pm(unit) × threat_pm(skill) / 10⁶ (07 §3.7).
static func on_damage(src: RtUnit, tgt: RtUnit, amount: int, skill_threat_pm: int) -> void:
	if src == null or tgt == null or amount <= 0 or src.side != Combatant.Side.PARTY:
		return
	if tgt.side != Combatant.Side.ENEMY:
		return
	add(tgt, src.id, FixedMath.div_round(amount * src.threat_pm * skill_threat_pm, 1000000))


## Healing `h` by a party unit: every living enemy gets max(1, h × HEAL_THREAT_PM / (1000 × n)).
static func on_heal(sim: RtSim, src: RtUnit, h: int) -> void:
	if src == null or h <= 0 or src.side != Combatant.Side.PARTY:
		return
	var foes: Array[RtUnit] = []
	for u: RtUnit in sim.units_ref():
		if u.side == Combatant.Side.ENEMY and sim.is_alive(u):
			foes.append(u)
	if foes.is_empty():
		return
	var per: int = maxi(1, FixedMath.div_round(h * sim.bal.i("HEAL_THREAT_PM"), 1000 * foes.size()))
	for e: RtUnit in foes:
		add(e, src.id, per)


## A fixate status from `src` on enemy `e` (the taunt, 07 §3.7): threat[src] = max(own, top × TAUNT_TOP_PM / 1000 + 1)
## and the fixation until `until` (the status end; −1 = until the combat ends).
static func taunt(sim: RtSim, src: RtUnit, e: RtUnit, until: int) -> void:
	var top: int = 0
	for u: RtUnit in sim.units_ref():
		if u.side == Combatant.Side.PARTY:
			top = maxi(top, of(e, u.id))
	e.threat[src.id] = maxi(of(e, src.id), FixedMath.mul_pm(top, sim.bal.i("TAUNT_TOP_PM")) + 1)
	e.fixate_id = src.id
	e.fixate_until = until if until >= 0 else sim.bal.i("MAX_COMBAT_TICKS")


## A KO'd party unit loses its threat on every enemy (it starts at 0 after a revive).
static func on_ko(sim: RtSim, u: RtUnit) -> void:
	if u.side != Combatant.Side.PARTY:
		return
	for e: RtUnit in sim.units_ref():
		if e.side == Combatant.Side.ENEMY and e.threat.has(u.id):
			e.threat[u.id] = 0


## The threat target of enemy `e` (07 §3.7): an active fixation wins; otherwise the current target stays until another
## party unit has more than current × THREAT_SWITCH_PM / 1000; without a valid current target the highest threat
## (ties: smaller slot, i.e. the first in unit order). "" if no party unit is alive.
static func top_target(sim: RtSim, e: RtUnit) -> String:
	if e.fixate_id != "" and e.fixate_until > sim.tick():
		var f: RtUnit = sim.unit(e.fixate_id)
		if f != null and f.hp > 0 and not f.left_battle:
			return f.id
	var th: Dictionary = e.threat
	var best: RtUnit = null
	var best_t: int = 0
	for u: RtUnit in sim.party_ref():
		if u.hp <= 0 or u.left_battle:
			continue
		var t: int = int(th.get(u.id, 0))
		if best == null or t > best_t:
			best = u
			best_t = t
	if best == null:
		return ""
	var cur: RtUnit = sim.unit(e.target_id)
	if cur != null and cur.side == Combatant.Side.PARTY and cur.hp > 0 and not cur.left_battle:
		if best != cur and best_t * 1000 > int(th.get(cur.id, 0)) * sim.bal.i("THREAT_SWITCH_PM"):
			return best.id
		return cur.id
	return best.id
