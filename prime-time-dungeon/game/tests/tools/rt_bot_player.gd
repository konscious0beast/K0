extends RefCounted
## RtBotPlayer (07 §5.7, R4): plays the controlled unit of an RtSim like a person — through the real commands of the
## live path (move samples with dead reckoning, target changes, ability uses, combat items, Partner-Spezial), never by
## writing into the sim. Private helper of the balance harness (tests/tools/rt_harness.gd; no class_name, loaded with
## preload / load()). Decisions follow the assist (RtSim.suggest: the rules of the assist_preset), plus an error
## profile with its own random stream SeedUtil.derive(seed, "bot", n) — so the bot never shifts a draw of the sim.
##
## Profiles (07 §5.7; `typical` is the start value R5b calibrates from play-test run logs, §11.4): reaction to a
## telegraph in ticks, missed telegraphs ‰, interrupted interrupt-worthy casts ‰, used GCDs ‰, potion below ‰ of the
## max HP, SHOW / FINALE used, adds first, heal before an interrupt the MP do not cover both of (perfect). A missed GCD
## window waits one GCD (the person hesitated) — never a heal while a party member is below the potion threshold.
## Interrupts: the bot sees a worthy cast after its reaction time and
## presses its interrupter (Kai: Leinen-Fallstrick / Kabelpeitsche, Mopsula: Donnerbellen) — walking into range first
## when needed; once a caster is on stage it keeps the interrupter's MP (the AI's filler reserve as a habit, typical
## and perfect). Dodges: from start + reaction it leaves every hostile shape striking within ESCAPE_LOOKAHEAD_TICKS
## that it stands in (grown by ESCAPE_MARGIN_CM) for RtGeo.escape_point — keeping that point while it stays safe —
## and never walks into a zone. Targets: the current one, adds before a boss, a closer enemy when a melee target kept
## out of reach (a caster backing off). Potions: the potion key on the party member lowest in HP under the threshold.
## Position: melee to its target's reach, ranged at keep_cm (Movement.goal_for, the AI's own goal rule), never out of
## the ring (no flight).
## Usage per tick: act() before RtSim.step(), observe(events) after it.

const Ability := preload("res://core/rt/rt_ability.gd")
const Movement := preload("res://core/rt/rt_movement.gd")
const StatusFx := preload("res://core/rt/rt_status_fx.gd")
const FixedMath := preload("res://core/stats/fixed_math.gd")

const PROFILES: Dictionary = {
	"perfect": {"react": 0, "miss_pm": 0, "interrupt_pm": 1000, "gcd_pm": 950, "potion_pm": 350, "show": true,
		"adds": true, "heal_first": true},
	"typical": {"react": 9, "miss_pm": 150, "interrupt_pm": 700, "gcd_pm": 750, "potion_pm": 350, "show": true,
		"adds": true, "heal_first": false},
	"sloppy": {"react": 18, "miss_pm": 400, "interrupt_pm": 300, "gcd_pm": 550, "potion_pm": 200, "show": false,
		"adds": false, "heal_first": false},
}
## Movement: a new sample at least every HEARTBEAT ticks while moving (07 §3.5.1), the bot stops within STOP_CM of its
## goal; MARGIN_CM grows the shapes it reacts to (= ESCAPE_MARGIN_CM of the AI).
const HEARTBEAT: int = 15
const STOP_CM: int = 20
## The person orders the Partner-Spezial at most this often (ticks) and only below these HP shares (‰).
const PARTNER_EVERY: int = 120
const PARTNER_HEAL_BELOW_PM: int = 400
const PARTNER_TAUNT_BELOW_PM: int = 500
## SHOW / FINALE skills are pressed only with the profile's "show" (the FINALE shows in slot 5).
const SLOT_SHOW: int = 5
## While the GCD runs, the bot looks at its off-GCD abilities (taunt, items via the assist) every THINK_TICKS ticks.
const THINK_TICKS: int = 3
## A melee figure switches away from a target out of its reach for this long (3 s) to a closer enemy.
const CHASE_GIVE_UP: int = 90
## The interrupter's MP reserve (_keeps_reserve): from this interrupt rate (‰) on, while the interrupter is ready
## within RESERVE_CD_TICKS (3 s).
const RESERVE_FROM_PM: int = 700
const RESERVE_CD_TICKS: int = 90

var sim: RtSim = null
var prof: Dictionary = {}
var profile_name: String = "typical"
## Counters of the person's play (harness output): GCD windows seen / used, interrupts tried / landed, telegraphs seen
## / missed, potions, Partner-Spezial orders.
var stats: Dictionary = {"gcd_windows": 0, "gcd_used": 0, "worthy_seen": 0, "interrupt_tries": 0, "shapes": 0,
	"shapes_missed": 0, "potions": 0, "partner_orders": 0, "revives": 0}

var _seed: int = 0
var _n: int = 0
var _uid: String = ""
var _react: Dictionary = {}                 # telegraph id → ct from which the bot reacts (−1 = missed)
var _intr: Dictionary = {}                  # caster unit id → ct from which the bot tries to interrupt it
var _next_gcd: int = 0                      # a missed GCD window: no new try before this ct
var _next_partner: int = 0
var _next_ask: int = 0                      # no assist query before this ct (after an empty suggestion)
var _chase_since: int = -1                  # ct since the melee target is out of reach (−1 = in reach)
var _margin: int = 60
var _escape: Array = []                     # the kept escape point [x, z] ([] = none)
var _proxy: RtUnit = null                   # the unit at its predicted position (_at)
var _intr_of: Dictionary = {}               # unit id → its interrupter ("" = none), see _interrupter
var _casters: Dictionary = {}               # enemy ids that started an interrupt-worthy cast (_keeps_reserve)


## `profile`: a key of PROFILES; `seed`: the bot's own stream (SeedUtil.derive(seed, "bot", n)).
func _init(p_sim: RtSim, profile: String = "typical", seed: int = 0) -> void:
	sim = p_sim
	profile_name = profile if PROFILES.has(profile) else "typical"
	prof = PROFILES[profile_name]
	_seed = seed
	if sim != null:
		_margin = sim.bal.i("ESCAPE_MARGIN_CM")


## The commands of tick sim.tick() (submitted with ct = tick, before RtSim.step()).
func act() -> void:
	if sim == null or sim.is_finished():
		return
	var c: int = sim.tick()
	var u: RtUnit = sim.unit(sim.controlled_id())
	if u == null or not sim.is_alive(u) or u.driver != RtUnit.Driver.PLAYER:
		return
	if u.id != _uid:
		_uid = u.id
		_next_gcd = c
	var pos: Vector2i = _predict(u, c)
	_pick_target(u, c)
	_items(u, c)
	_partner(u, c)
	var goal: Array = _goal(u, c, pos)
	_actions(u, c, pos)
	_move(u, c, pos, goal)


## The events of the tick just stepped: the bot notices interrupt-worthy casts (its interrupt plan) here.
func observe(events: Array[ActionEvent]) -> void:
	for e: ActionEvent in events:
		if e.type != ActionEvent.Type.CAST_START or int(e.rt.get("worthy", 0)) != 1:
			continue
		var caster: RtUnit = sim.unit(e.actor_id)
		if caster == null or caster.side != Combatant.Side.ENEMY:
			continue
		stats["worthy_seen"] = int(stats["worthy_seen"]) + 1
		_casters[caster.id] = true
		if _roll(int(prof["interrupt_pm"])):
			_intr[caster.id] = e.tick + maxi(1, int(prof["react"]))


# --- decisions --------------------------------------------------------------------------------------------------------

## A target like a person keeps it: the current living enemy, else the nearest one on stage. Adds first (the lesson of
## the Hausmeister's P2): with the profile's "adds", a summoned add on stage pulls the bot off a boss once the bot has
## noticed it (its reaction time after the add can act). A melee figure gives up a target that stayed out of its reach
## for CHASE_GIVE_UP ticks (a caster backing off, "hält 600") when another enemy stands closer.
func _pick_target(u: RtUnit, c: int) -> void:
	var t: RtUnit = sim.unit(u.target_id)
	var keep: bool = t != null and t.side != u.side and sim.targetable(t)
	var adds_only: bool = keep and t.is_boss and bool(prof["adds"])
	var away: bool = false
	if keep and u.keep_cm <= 0 and not t.is_boss:
		var reach: int = u.reach + t.radius + sim.bal.i("MELEE_STOP_CM")
		if DetMath.dist2(u.x, u.z, t.x, t.z) > reach * reach:
			if _chase_since < 0:
				_chase_since = c
			away = c - _chase_since >= CHASE_GIVE_UP
		else:
			_chase_since = -1
	if keep and not adds_only and not away:
		return
	var best: RtUnit = null
	var bd: int = -1
	for v: RtUnit in sim.units_ref():
		if v.side == u.side or not sim.targetable(v) or not v.entry.is_empty():
			continue
		if adds_only and not (v.is_summon and c >= v.pop_in_until + int(prof["react"])):
			continue
		var d2: int = DetMath.dist2(u.x, u.z, v.x, v.z)
		if away and (v == t or d2 >= DetMath.dist2(u.x, u.z, t.x, t.z)):
			continue
		if best == null or d2 < bd:
			best = v
			bd = d2
	if best != null and best != t:
		_chase_since = -1
		sim.submit(RtCommand.target(c, u.id, best.id))


## Potion below the profile's threshold (the potion key picks the item, 07 §3.11) for the party member lowest in HP
## under it — the person's own figure on a tie; the partner as the key's friendly target (its HP bar is on the HUD);
## a KO'd partner gets the smelling salts.
func _items(u: RtUnit, c: int) -> void:
	if sim.items_left() <= 0 or sim.item_cd_left() > 0 or not u.cast.is_empty():
		return
	var low: RtUnit = null
	var below: int = int(prof["potion_pm"])
	if sim.is_alive(u) and u.hp * 1000 < u.max_hp() * below:     # the person's own figure first (it wins a tie)
		low = u
	for v: RtUnit in sim.party_ref():
		if v != u and v.side == u.side and sim.is_alive(v) and v.hp * 1000 < v.max_hp() * below \
				and (low == null or v.hp * 1000 / maxi(1, v.max_hp()) < low.hp * 1000 / maxi(1, low.max_hp())):
			low = v
	if low != null:
		var pick: String = Ability.potion_pick(sim, _aiming_at(u, low))   # the key's pick for that friendly target
		if pick != "" and sim.can_use_item(u.id, pick, low.id) == "":
			if sim.submit(RtCommand.item(c, u.id, pick, low.id)) == "":
				stats["potions"] = int(stats["potions"]) + 1
			return
	if profile_name == "sloppy":
		return
	for v: RtUnit in sim.units_ref():
		if v.side == u.side and v != u and v.is_ko() and not v.left_battle:
			for iid: Variant in sim.items.keys():
				var it: ItemDef = sim.item_def(str(iid))
				if it != null and it.tags.has("revive") and int(sim.items[iid]) > 0 \
						and sim.can_use_item(u.id, str(iid), v.id) == "":
					if sim.submit(RtCommand.item(c, u.id, str(iid), v.id)) == "":
						stats["revives"] = int(stats["revives"]) + 1
					return


## The Partner-Spezial (07 §5.1): Kai as the hero orders Mopsula's heal when low, Mopsula as the hero orders Kai's
## taunt when an enemy attacks her and she is hurt.
func _partner(u: RtUnit, c: int) -> void:
	if profile_name == "sloppy" or c < _next_partner or c % THINK_TICKS != 0:
		return
	for p: RtUnit in sim.party_ref():
		if p.side != u.side or p == u or not sim.is_alive(p):
			continue
		var skill: String = sim.partner_special_skill(p.id)
		if skill == "" or sim.cooldown_left(p.id, skill) > 0 or not p.partner_order.is_empty():
			continue
		var want: bool = false
		var sk: SkillDef = sim.skill_def(skill)
		if sk != null and sk.damage_type == "heal":
			want = u.hp * 1000 < u.max_hp() * PARTNER_HEAL_BELOW_PM
		else:
			var on_me: bool = false
			for e: RtUnit in sim.units_ref():
				if e.side != u.side and sim.targetable(e) and e.target_id == u.id:
					on_me = true
			want = on_me and u.hp * 1000 < u.max_hp() * PARTNER_TAUNT_BELOW_PM
		if want and sim.submit(RtCommand.partner_special(c, p.id)) == "":
			stats["partner_orders"] = int(stats["partner_orders"]) + 1
			_next_partner = c + PARTNER_EVERY


## Interrupts due now, the FINALE, then the assist's suggestion on a free GCD (used with the profile's rate).
func _actions(u: RtUnit, c: int, pos: Vector2i) -> void:
	var intr: String = _interrupter(u)
	for cid: Variant in _intr.keys():
		var caster: RtUnit = sim.unit(str(cid))
		if caster == null or not sim.is_alive(caster) or not bool(caster.cast.get("worthy", false)):
			_intr.erase(cid)
			continue
		if c < int(_intr[cid]) or intr == "":
			continue
		if _in_interrupt_range(u, intr, caster, pos):
			if _heal_first(u, intr):
				_intr.erase(cid)                      # the heal due now wins; the partner may interrupt
				continue
			var why: String = sim.can_use(u.id, intr, caster.id)
			if why == "":
				sim.submit(RtCommand.ability(c, u.id, intr, caster.id))
				stats["interrupt_tries"] = int(stats["interrupt_tries"]) + 1
				_intr.erase(cid)
				return
			if why == "cooldown" or why == "mp" or why == "not_learned" or why == "locked":
				stats["intr_" + why] = int(stats.get("intr_" + why, 0)) + 1
				_intr.erase(cid)
	var fin: String = sim.finale_of(u) if bool(prof["show"]) else ""
	if fin != "" and _finale_shown(u, fin) and sim.can_use(u.id, fin, u.target_id) == "":
		sim.submit(RtCommand.ability(c, u.id, fin, u.target_id))
		return
	if not u.cast.is_empty() or c < _next_gcd or c < _next_ask:
		return
	if sim.gcd_left(u.id) > 0 and c % THINK_TICKS != 0:
		return                                   # off-GCD abilities: the person looks every THINK_TICKS ticks
	var s: String = sim.suggest(u.id)
	if s == "" or s == intr or _is_interrupter(s):
		_next_ask = c + THINK_TICKS              # nothing to press (MP, cooldowns): look again a moment later
		return
	var sk: SkillDef = sim.skill_def(s)
	if sk == null:
		return
	if sk.is_stunt() and not bool(prof["show"]):
		return
	if _keeps_reserve(u, sk, intr):
		_next_ask = c + THINK_TICKS
		return
	var gcd: bool = bool(sk.rt.get("gcd", true))
	if gcd and sim.gcd_left(u.id) > 0:
		return
	if gcd:
		stats["gcd_windows"] = int(stats["gcd_windows"]) + 1
		if not _emergency_heal(u, sk) and not _roll(int(prof["gcd_pm"])):
			_next_gcd = c + sim.bal.i("GCD_TICKS")
			return
		stats["gcd_used"] = int(stats["gcd_used"]) + 1
	var tid: String = u.target_id if sk.target == "single_enemy" or sk.target == "all_enemies" else ""
	sim.submit(RtCommand.ability(c, u.id, s, tid))


## The movement goal: escape > interrupt approach > combat position; [] = stand.
func _goal(u: RtUnit, c: int, pos: Vector2i) -> Array:
	if _threatened(u, c, pos):
		var p: Vector2i = _escape_point(u, pos)
		if p != pos:
			return [p.x, p.y]
		return []
	_escape = []
	if not u.cast.is_empty() and bool(u.cast.get("moving_cancels", false)):
		return []
	var intr: String = _interrupter(u)
	for cid: Variant in _intr.keys():
		var caster: RtUnit = sim.unit(str(cid))
		if caster != null and c >= int(_intr[cid]) and intr != "" and not _in_interrupt_range(u, intr, caster, pos):
			var reach: int = _interrupt_reach(u, intr) + caster.radius - sim.bal.i("MELEE_STOP_CM")
			var q: Vector2i = DetMath.toward(caster.x, caster.z, pos.x, pos.y, maxi(0, reach))
			return _safe([q.x, q.y], u, pos)
	var t: RtUnit = sim.unit(u.target_id)
	if t == null or t.side == u.side or not sim.targetable(t):
		return []
	return _safe(Movement.goal_for(sim, _at(u, pos), t), u, pos)


## Is the bot standing in a pending hostile shape it has noticed (reaction time passed, not missed) that strikes within
## RtSim.ESCAPE_LOOKAHEAD_TICKS (the window the AI and RtGeo.escape_point judge safety in, 07 §5.5), or in a zone?
func _threatened(u: RtUnit, c: int, pos: Vector2i) -> bool:
	for t: RtTelegraph in sim.telegraphs_ref():
		if t.side != u.side:
			continue
		if t.is_zone:
			if t.contains(pos.x, pos.y):
				return true
			continue
		if t.impact_at <= c:
			continue
		if not _react.has(t.id):
			stats["shapes"] = int(stats["shapes"]) + 1
			var missed: bool = _roll(int(prof["miss_pm"]))
			if missed:
				stats["shapes_missed"] = int(stats["shapes_missed"]) + 1
			_react[t.id] = -1 if missed else t.start + int(prof["react"])
		var at: int = int(_react[t.id])
		if at >= 0 and c >= at and t.impact_at - c <= RtSim.ESCAPE_LOOKAHEAD_TICKS \
				and t.contains_inflated(pos.x, pos.y, _margin):
			return true
	return false


## The escape point (RtGeo.escape_point), kept while it stays safe like the AI's (07 §5.5): a person picks a spot and
## runs there instead of changing direction every tick; the bot's own spot is never kept.
func _escape_point(u: RtUnit, pos: Vector2i) -> Vector2i:
	if _escape.size() == 2 and Vector2i(int(_escape[0]), int(_escape[1])) != pos \
			and sim.safe_point(_at(u, pos), int(_escape[0]), int(_escape[1])):
		return Vector2i(int(_escape[0]), int(_escape[1]))
	var p: Vector2i = RtGeo.escape_point(sim, _at(u, pos))
	_escape = [p.x, p.y] if p != pos else []
	return p


## A goal inside a pending hostile shape or a zone becomes "stand" (the bot waits outside).
func _safe(g: Array, u: RtUnit, pos: Vector2i) -> Array:
	if g.size() != 2:
		return g
	if not sim.safe_point(_at(u, pos), int(g[0]), int(g[1])):
		return []
	return g


# --- movement ---------------------------------------------------------------------------------------------------------

## Walks towards `goal` at the run speed (× move_pm) with honest samples: a new sample when the velocity changes,
## every HEARTBEAT ticks while moving, and one stop sample. Steps stay walkable in the ring (sliding along an axis).
func _move(u: RtUnit, c: int, pos: Vector2i, goal: Array) -> void:
	var vx: int = 0
	var vz: int = 0
	if goal.size() == 2 and not Movement.holds(u):
		var gx: int = int(goal[0])
		var gz: int = int(goal[1])
		var d: int = DetMath.dist(pos.x, pos.y, gx, gz)
		if d > STOP_CM:
			var speed: int = maxi(1, FixedMath.mul_pm(sim.bal.i("PLAYER_RUN_CM_S"), StatusFx.factor(u, "move_pm")) / 30)
			var step: int = mini(speed, d)
			var sx: int = FixedMath.div_round((gx - pos.x) * step, d)
			var sz: int = FixedMath.div_round((gz - pos.y) * step, d)
			if not sim.walkable_ring(pos.x + sx, pos.y + sz, u.radius):
				if sx != 0 and sim.walkable_ring(pos.x + sx, pos.y, u.radius):
					sz = 0
				elif sz != 0 and sim.walkable_ring(pos.x, pos.y + sz, u.radius):
					sx = 0
				else:
					sx = 0
					sz = 0
			vx = sx * 10
			vz = sz * 10
	var s: Array[int] = u.sample
	var last_v: Vector2i = Vector2i(s[3], s[4]) if s.size() == 6 else Vector2i.ZERO
	var due: bool = s.size() != 6 or (vx != 0 or vz != 0) and c - s[0] >= HEARTBEAT
	if Vector2i(vx, vz) == last_v and not due:
		return
	var yaw: int = DetMath.yaw_of(vx, vz) if (vx != 0 or vz != 0) else u.yaw
	sim.submit(RtCommand.move(c, u.id, pos.x, pos.y, vx, vz, yaw))


## The sim's own position of `u` at tick c before step 1a (dead reckoning from its last sample, clamped like
## Movement.dead_reckon) — where a sample submitted now must start.
func _predict(u: RtUnit, c: int) -> Vector2i:
	var s: Array[int] = u.sample
	if s.size() != 6 or Movement.holds(u):
		return Vector2i(u.x, u.z)
	var n: int = mini(c - s[0], sim.bal.i("DR_MAX_TICKS"))
	if n <= 0:
		return Vector2i(u.x, u.z)
	var x: int = s[1] + FixedMath.div_round(s[3] * n, 10)
	var z: int = s[2] + FixedMath.div_round(s[4] * n, 10)
	var half: int = sim.geo_cell_half
	if absi(x) <= half and absi(z) <= half and not sim.walkable_party(x, z, u.radius):
		var q: Vector2i = RtGeo.project_walkable(sim.setup.geo, x, z, u.radius, true)
		x = q.x
		z = q.y
	return Vector2i(x, z)


# --- helpers ----------------------------------------------------------------------------------------------------------

## `u` with `friend` as its friendly target (the potion key's pick reads the target's missing HP, 07 §3.11): `u`
## itself for its own figure, else the proxy aimed at `friend` (the sim's unit keeps its hostile target).
func _aiming_at(u: RtUnit, friend: RtUnit) -> RtUnit:
	if friend == u:
		return u
	var v: RtUnit = _at(u, Vector2i(u.x + 1, u.z))     # a proxy copy (position irrelevant here)
	v.x = u.x
	v.target_id = friend.id
	return v


## `u` at `pos` for the pure geometry helpers (Movement.goal_for, RtGeo.escape_point, RtSim.safe_point read id, side,
## position, radius, reach, keep / follow distance and the target): a reused proxy with those fields — the sim's unit
## stays untouched and no full copy is made per tick.
func _at(u: RtUnit, pos: Vector2i) -> RtUnit:
	if u.x == pos.x and u.z == pos.y:
		return u
	if _proxy == null:
		_proxy = RtUnit.new()
	_proxy.id = u.id
	_proxy.def_id = u.def_id
	_proxy.side = u.side
	_proxy.driver = u.driver
	_proxy.x = pos.x
	_proxy.z = pos.y
	_proxy.yaw = u.yaw
	_proxy.radius = u.radius
	_proxy.reach = u.reach
	_proxy.keep_cm = u.keep_cm
	_proxy.follow_cm = u.follow_cm
	_proxy.target_id = u.target_id
	return _proxy


## A person who learned to interrupt (the profile's interrupt rate ≥ RESERVE_FROM_PM) keeps its interrupter's MP once
## an enemy still standing has cast something worth interrupting: a damaging ability that would leave less is skipped
## while the interrupter is ready within RESERVE_CD_TICKS — the AI's filler reserve (07 §3.10, §5.3 Nr. 3) as a habit
## of the person; heals and buffs are never held back.
func _keeps_reserve(u: RtUnit, sk: SkillDef, intr: String) -> bool:
	if intr == "" or sk.id == intr or int(prof["interrupt_pm"]) < RESERVE_FROM_PM:
		return false
	var caster_alive: bool = false
	for cid: Variant in _casters.keys():
		var e: RtUnit = sim.unit(str(cid))
		caster_alive = caster_alive or (e != null and sim.is_alive(e))
	if not caster_alive:
		return false
	if sk.damage_type != "physical" and sk.damage_type != "magical":
		return false
	var cost: int = int(sk.rt.get("mp", sk.mp_cost))
	var keep: SkillDef = sim.skill_def(intr)
	if cost <= 0 or keep == null or sim.cooldown_left(u.id, intr) > RESERVE_CD_TICKS:
		return false
	return u.mp - cost < int(keep.rt.get("mp", keep.mp_cost))


## The FINALE stands in slot 5 of RtSim.bar — its slot skill, or the target an enemy below FINALE_TARGET_BELOW_PM; the
## bar itself (with its potion pick) is only built when one of the two holds (the same answer, a fraction of the cost).
func _finale_shown(u: RtUnit, fin: String) -> bool:
	var t: RtUnit = sim.unit(u.target_id)
	var low: bool = t != null and t.side != u.side and sim.targetable(t) \
		and t.hp * 1000 < t.max_hp() * sim.bal.i("FINALE_TARGET_BELOW_PM")
	if not low and not u.bar.values().has(fin):
		return false
	return sim.bar_slot(u.id, SLOT_SHOW) == fin


## The expert's priority (profile "heal_first", perfect): when the assist suggests a heal now and the MP do not cover
## the interrupter and that heal, the heal goes first (Mopsula's Donnerbellen costs 5 MP — interrupting at any price
## starved her heals at the queen). The partner AI still interrupts.
func _heal_first(u: RtUnit, intr: String) -> bool:
	if not bool(prof.get("heal_first", false)):
		return false
	var s: String = sim.suggest(u.id)
	var heal: SkillDef = sim.skill_def(s) if s != "" else null
	var keep: SkillDef = sim.skill_def(intr)
	if heal == null or heal.damage_type != "heal" or keep == null:
		return false
	return u.mp < int(keep.rt.get("mp", keep.mp_cost)) + int(heal.rt.get("mp", heal.mp_cost))


## A heal while a party member stands below the profile's potion threshold: the person does not let that GCD pass
## (the GCD-use rate models hesitation, not a healer watching the tank fall).
func _emergency_heal(u: RtUnit, sk: SkillDef) -> bool:
	if sk.damage_type != "heal":
		return false
	for v: RtUnit in sim.party_ref():
		if sim.is_alive(v) and v.hp * 1000 < v.max_hp() * int(prof["potion_pm"]):
			return true
	return false


## The unit's interrupter on its bar (the first skill with rt.interrupt in slot order), "" if none — fixed for the
## combat (loadout and level), so it is looked up once per controlled unit.
func _interrupter(u: RtUnit) -> String:
	if _intr_of.has(u.id):
		return str(_intr_of[u.id])
	var out: String = ""
	var bar: Dictionary = sim.bar(u.id)
	var slots: Array = bar.keys()
	slots.sort()
	for s: Variant in slots:
		if out == "" and _is_interrupter(str(bar[s])):
			out = str(bar[s])
	_intr_of[u.id] = out
	return out


func _is_interrupter(skill_id: String) -> bool:
	var sk: SkillDef = sim.skill_def(skill_id)
	return sk != null and bool(sk.rt.get("interrupt", false))


## The reach of an interrupter: its range, or the radius of its area around the unit (Donnerbellen).
func _interrupt_reach(u: RtUnit, skill_id: String) -> int:
	var sk: SkillDef = sim.skill_def(skill_id)
	if sk == null:
		return u.reach
	var r: int = int(sk.rt.get("range_cm", 0))
	if r <= 0:
		r = int((sk.rt.get("aoe", {}) as Dictionary).get("radius_cm", 0))
	return r if r > 0 else u.reach


func _in_interrupt_range(u: RtUnit, skill_id: String, caster: RtUnit, pos: Vector2i) -> bool:
	var reach: int = _interrupt_reach(u, skill_id) + caster.radius
	return DetMath.dist2(pos.x, pos.y, caster.x, caster.z) <= reach * reach


## One draw of the bot's own stream: true with `pm` ‰.
func _roll(pm: int) -> bool:
	if pm <= 0:
		return false
	if pm >= 1000:
		return true
	_n += 1
	var rng: RandomNumberGenerator = SeedUtil.make_rng(SeedUtil.derive(_seed, "bot", _n))
	return rng.randi_range(0, 999) < pm
