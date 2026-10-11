extends RefCounted
## Enemies beyond the rule walk (07 §6, §3.12) — private helper of RtSim (no class_name; preloaded as Boss): the auto
## target of an enemy, boss phases (PHASE_CHANGE at the start and at the thresholds of step 10, the rules of the phase
## from its start, the on_enter ops, the perfect phase), the enrage timer, summons (MAX_ENEMIES, door / near,
## SUMMON_HP_PM, pop-in, start threat) and the specials of enemy skills (credit theft, escape).

const FixedMath := preload("res://core/stats/fixed_math.gd")
const Ability := preload("res://core/rt/rt_ability.gd")
const Damage := preload("res://core/rt/rt_damage.gd")
const StatusFx := preload("res://core/rt/rt_status_fx.gd")
const Threat := preload("res://core/rt/rt_threat.gd")
const Tele := preload("res://core/rt/rt_tele.gd")


## The auto target of enemy `u` (07 §6.2, rt.auto_target `how`): a running taunt fixation first (Threat.top_target
## has it built in); lowest_hp_pct_enemy / nearest_enemy (ties: unit order); random_enemy keeps a living target and
## draws a new one (combat stream) only without; else threat_top.
static func auto_target(sim: RtSim, u: RtUnit, how: String) -> String:
	if how == "threat_top" or how == "":
		return Threat.top_target(sim, u)
	if u.fixate_id != "" and u.fixate_until > sim.tick():
		var f: RtUnit = sim.unit(u.fixate_id)
		if f != null and f.hp > 0 and not f.left_battle:
			return f.id
	match how:
		"lowest_hp_pct_enemy":
			var best: RtUnit = null
			for v: RtUnit in sim.party_ref():
				if sim.is_alive(v) and (best == null or v.hp * best.max_hp() < best.hp * v.max_hp()):
					best = v
			return best.id if best != null else ""
		"nearest_enemy":
			var near: RtUnit = null
			var nd: int = -1
			for v: RtUnit in sim.party_ref():
				if sim.is_alive(v):
					var d2: int = DetMath.dist2(u.x, u.z, v.x, v.z)
					if near == null or d2 < nd:
						near = v
						nd = d2
			return near.id if near != null else ""
		"random_enemy":
			var cur: RtUnit = sim.unit(u.target_id)
			if cur != null and cur.side == Combatant.Side.PARTY and sim.is_alive(cur):
				return cur.id
			var cands: Array[RtUnit] = []
			for v: RtUnit in sim.party_ref():
				if sim.is_alive(v):
					cands.append(v)
			if cands.is_empty():
				return ""
			return cands[sim.rng().randi_range(0, cands.size() - 1)].id
	return Threat.top_target(sim, u)


## The start (07 §3.4 "PHASE_CHANGE (bosses)"): every enemy with rt.phases enters its first phase.
static func start(sim: RtSim) -> void:
	for u: RtUnit in sim.special_foes():
		if u.phase < 0 and sim.is_alive(u):
			enter_phase(sim, u, 0)


## Step 10 (07 §3.3) before the end check, per enemy with phases or an enrage block (unit order): the boss thresholds
## (every phase it crossed, in order) and the enrage stacks due at c.
static func step(sim: RtSim, c: int) -> void:
	for u: RtUnit in sim.special_foes():
		if u.hp <= 0 or u.left_battle:
			continue
		var ert: Dictionary = sim.enemy_rt(u.def_id)
		var phases: Array = ert.get("phases", [])
		if not phases.is_empty() and u.phase >= 0:
			var want: int = phase_for(u, phases)
			while u.phase < want and sim.is_alive(u):
				enter_phase(sim, u, u.phase + 1)
		var en: Dictionary = ert.get("enrage", {})
		if not en.is_empty() and sim.is_alive(u):
			_enrage(sim, u, en, c)


## The phase the HP of `u` belongs to (07 §4.9): the first one with hp > hp_above_pm ‰ of the max HP, else the last.
static func phase_for(u: RtUnit, phases: Array) -> int:
	for i in phases.size():
		var p: Variant = phases[i]
		if p is Dictionary and u.hp * 1000 > int((p as Dictionary).get("hp_above_pm", 0)) * u.max_hp():
			return i
	return phases.size() - 1


## Enters phase k of `u` (07 §6.4): PHASE_CHANGE (value k + 1, success = the previous phase was perfect — counted for
## the result), a fresh perfect phase, the rules of the phase (keys "<k>:<index>", ready first_ms + slot offset after
## the phase start, 07 §6.6 "Zeiten ab Phasenbeginn") plus the add_rule mods, then the on_enter ops.
static func enter_phase(sim: RtSim, u: RtUnit, k: int) -> void:
	var phases: Array = sim.enemy_rt(u.def_id).get("phases", [])
	if k < 0 or k >= phases.size() or not (phases[k] is Dictionary):
		return
	var ph: Dictionary = phases[k]
	var perfect: bool = u.phase >= 0 and u.phase_perfect
	u.phase = k
	var e: ActionEvent = sim.ev(ActionEvent.Type.PHASE_CHANGE)
	e.actor_id = u.id
	e.value = k + 1
	e.success = perfect
	if perfect:
		sim.tally["perfect_phases"] = int(sim.tally["perfect_phases"]) + 1
	u.phase_perfect = true
	var rules: Array[Dictionary] = RtRules.compile(ph.get("rules", []) as Array, str(k))
	var at: int = sim.tick() + u.slot * sim.bal.i("AI_SLOT_OFFSET_TICKS")
	for r: Dictionary in rules:
		u.rule_ready[str(r["key"])] = at + int(r["first"])
	rules.append_array(sim.mod_rules(u))
	u.rules = rules
	run_ops(sim, u, ph.get("on_enter", []) as Array)


## The on_enter ops of a phase (07 §4.9, RtVocab.RT_PHASE_OPS) in order: say {tag} → MOD_LINE; status_self {status,
## ms} (no resistance roll; ms −1 = until the end); summon {enemy, count, at}; fixed_damage_self {pct_pm} (never below
## 1 HP); set {stationary}; clear_zones (every zone of its side); telegraph {skill} — the skill's shapes now, striking
## after its warning time, without a cast.
static func run_ops(sim: RtSim, u: RtUnit, ops: Array) -> void:
	for o: Variant in ops:
		if not (o is Dictionary) or not sim.is_alive(u):
			continue
		var op: Dictionary = o
		match str(op.get("op", "")):
			"say":
				var m: ActionEvent = sim.ev(ActionEvent.Type.MOD_LINE)
				m.actor_id = u.id
				m.text = str(op.get("tag", ""))
			"status_self":
				StatusFx.apply(sim, u.id, u, str(op.get("status", "")), JsonUtil.to_int(op.get("ms", 0)), 1000, 0,
					null, true, true)
			"summon":
				for k in maxi(1, JsonUtil.to_int(op.get("count", 1), 1)):
					summon(sim, u, str(op.get("enemy", "")), str(op.get("at", "door")), k)
			"fixed_damage_self":
				var amt: int = mini(FixedMath.div_round(u.max_hp() * JsonUtil.to_int(op.get("pct_pm", 0)), 1000),
					u.hp - 1)
				if amt > 0:
					Damage.apply(sim, u, u, amt, Elements.NONE, HitResult.new(), "", "", "", Damage.Kind.SELF, true,
						-1, 0)
			"set":
				if op.has("stationary"):
					u.stationary = bool(op["stationary"])
					if u.stationary:
						u.goal = []
			"clear_zones":
				Tele.clear_zones(sim, Combatant.Side.PARTY if u.side == Combatant.Side.ENEMY else Combatant.Side.ENEMY)
			"telegraph":
				var sk: SkillDef = sim.skill_def(str(op.get("skill", "")))
				if sk != null:
					var warn: int = Tele.warn_ticks(sim, Ability.cast_ticks(sim, u, sk))
					Tele.create(sim, u, sk, u.target_id, sim.tick() + warn)


## A summon (07 §3.12): an enemy of `enemy_id` while fewer than MAX_ENEMIES enemies live — "near": formation slot
## 1 + k around the summoner; "door": RtGeo.door_spot towards the party centre (open set: the end of the door lane,
## then the walk in, ENTER_MAX_TICKS at most; closed set: the ring point in front of the door) — with SUMMON_HP_PM,
## is_summon (no EXP / loot), the next enemy number, its rules from the summon on, pop-in (acts POP_IN_TICKS later),
## SUMMON (value = its number) and threat 1 on the nearest party unit. Returns the unit or null.
static func summon(sim: RtSim, src: RtUnit, enemy_id: String, at: String, k: int = 0) -> RtUnit:
	var def: EnemyDef = sim.enemy_def(enemy_id)
	if def == null or sim.living_enemies() >= sim.bal.i("MAX_ENEMIES"):
		return null
	var n: int = sim.take_enemy_number()
	var u: RtUnit = RtUnit.from_enemy(def, "e%d" % n, n, sim.bal, true)
	var c: int = sim.tick()
	var geo: Dictionary = sim.setup.geo
	var mid: Vector2i = sim.party_center()
	var p: Vector2i
	if at == "near" and src != null:
		var f: Vector2i = RtGeo.formation(1 + k, src.x, src.z, src.yaw)
		p = RtGeo.project_walkable(geo, f.x, f.y, u.radius, false)
	else:
		p = RtGeo.door_spot(geo, mid.x, mid.y, u.radius)
	u.x = p.x
	u.z = p.y
	u.yaw = DetMath.yaw_of(mid.x - u.x, mid.y - u.z) if (mid.x != u.x or mid.y != u.z) else u.yaw
	u.pop_in_until = c + sim.bal.i("POP_IN_TICKS")
	if not RtGeo.walkable(geo, u.x, u.z, u.radius, false):
		var q: Vector2i = RtGeo.project_walkable(geo, u.x, u.z, u.radius, false)
		u.entry.assign([q.x, q.y])
		u.pop_in_until += sim.bal.i("ENTER_MAX_TICKS")
	var offset: int = c + u.slot * sim.bal.i("AI_SLOT_OFFSET_TICKS")
	for r: Dictionary in u.rules:
		u.rule_ready[str(r["key"])] = offset + int(r["first"])
	sim.add_unit(u)
	var e: ActionEvent = sim.ev(ActionEvent.Type.SUMMON)
	e.actor_id = src.id if src != null else ""
	e.target_id = u.id
	e.def_id = u.def_id
	e.value = n
	var near: RtUnit = null
	var nd: int = -1
	for v: RtUnit in sim.units_ref():
		if v.side != u.side and sim.is_alive(v):
			var d2: int = DetMath.dist2(u.x, u.z, v.x, v.z)
			if near == null or d2 < nd:
				near = v
				nd = d2
	if near != null:
		Threat.add(u, near.id, 1)
	if u.phase < 0:
		enter_phase(sim, u, 0)
	return u


## The special of an enemy skill at its effect (07 §3.12, §6.5): steal_credits — at most special.max of what the party
## still has (credits_available − stolen so far), CREDITS_STOLEN, the thief's ledger {amount, refund (refund_on_win)};
## escape — the unit leaves the combat.
static func special(sim: RtSim, u: RtUnit, sk: SkillDef) -> void:
	match str(sk.special.get("kind", "")):
		"steal_credits":
			if u.side == Combatant.Side.PARTY:
				return
			var thieves: Dictionary = sim.tally["thieves"]
			var stolen: int = 0
			for k: Variant in thieves.keys():
				stolen += int((thieves[k] as Dictionary).get("amount", 0))
			var amount: int = maxi(0, mini(JsonUtil.to_int(sk.special.get("max", 0)),
				sim.setup.credits_available - stolen))
			var entry: Dictionary = thieves.get(u.id, {"amount": 0, "refund": false})
			entry["amount"] = int(entry.get("amount", 0)) + amount
			entry["refund"] = bool(entry.get("refund", false)) or bool(sk.special.get("refund_on_win", false))
			thieves[u.id] = entry
			var e: ActionEvent = sim.ev(ActionEvent.Type.CREDITS_STOLEN)
			e.actor_id = u.id
			e.value = amount
		"escape":
			escape(sim, u)


## An enemy escapes (07 §3.12): its cast and pending telegraphs end, it leaves (ESCAPED; no rewards, it no longer
## counts for VICTORY), the controlled unit retargets.
static func escape(sim: RtSim, u: RtUnit) -> void:
	if u.side == Combatant.Side.PARTY or not sim.is_alive(u):
		return
	if not u.cast.is_empty():
		sim.cast_over(u)
	Tele.cancel(sim, u.id, -1, "")
	u.left_battle = true
	u.queued = {}
	u.follow_up = {}
	u.goal = []
	(sim.tally["escaped"] as Array).append(u.def_id)
	var e: ActionEvent = sim.ev(ActionEvent.Type.ESCAPED)
	e.actor_id = u.id
	e.def_id = u.def_id
	sim.retarget_after_kill(u)


# --- private --------------------------------------------------------------------------------------------------------

## Enrage (07 §6.4): at at_ms ENRAGE (value = stacks), the M.O.D. line rt_enrage:<enemy id> and the first stack of the
## status; then every every_ms another stack (no resistance roll, until the end of the combat).
static func _enrage(sim: RtSim, u: RtUnit, en: Dictionary, c: int) -> void:
	var at: int = int(en.get("at_ms", 0)) * 3 / 100
	if at <= 0 or c < at:
		return
	var every: int = int(en.get("every_ms", 0)) * 3 / 100
	if c != at and (every <= 0 or (c - at) % every != 0):
		return
	var e: ActionEvent = sim.ev(ActionEvent.Type.ENRAGE)
	e.actor_id = u.id
	if c == at:
		var m: ActionEvent = sim.ev(ActionEvent.Type.MOD_LINE)
		m.actor_id = u.id
		m.text = "rt_enrage:%s" % u.def_id
	var st: RtStatus = StatusFx.apply(sim, u.id, u, str(en.get("status", "sts_enrage")), -1, 1000, 0, null, true, true)
	e.value = st.stacks if st != null else 0
