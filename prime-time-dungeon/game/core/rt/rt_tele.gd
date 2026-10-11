extends RefCounted
## Telegraphs and zones of the real-time combat (07 §6.3; §3.3 steps 3, 4 and 9) — private helper of RtSim (no
## class_name; preloaded as Tele): the shapes of a telegraph skill by anchor at its cast start (or a phase op), the
## impact in its tick (the Fußpunkt-Regel inside the ring, dodges and close dodges, the skill's effect, train kills,
## the zone, the dash), the zone periods, the "inside" bookkeeping after the movement and the removal of pending shapes
## (interrupt, KO, escape). RtSim.add_telegraph assigns the ids, keeps MAX_TELEGRAPHS and emits TELEGRAPH_START /
## ZONE_START.

const FixedMath := preload("res://core/stats/fixed_math.gd")
const Ability := preload("res://core/rt/rt_ability.gd")
const Damage := preload("res://core/rt/rt_damage.gd")
const StatusFx := preload("res://core/rt/rt_status_fx.gd")

const K := BattleCommand.Kind
const SHAPES: Dictionary = {"circle": RtTelegraph.Shape.CIRCLE, "cone": RtTelegraph.Shape.CONE,
	"ring": RtTelegraph.Shape.RING, "line": RtTelegraph.Shape.LINE}
## Lanes run along +x (yaw 192, DetMath: yaw 0 = −z).
const YAW_PLUS_X: int = 192
## Random points (anchor "random"): at most this far inside the ring edge, this many draws per point (07 §6.3).
const RANDOM_EDGE_CM: int = 60
const RANDOM_TRIES: int = 8


## Warning time of a telegraph cast (07 §6.3): its cast ticks, × EASY_WARN_PM in the Vorabendprogramm; ≥ 1.
static func warn_ticks(sim: RtSim, cast_t: int) -> int:
	var t: int = maxi(1, cast_t)
	if sim.setup.difficulty == &"vorabend":
		t = FixedMath.mul_pm(t, sim.bal.i("EASY_WARN_PM"))
	return maxi(1, t)


## The shapes of telegraph skill `sk` cast by `u` now, striking at `impact_at` (07 §6.3 "Anker"): self — at the
## caster (cones and lines towards the rule target `primary_id`); target_pos — at the rule target (else the caster);
## each_enemy — one at each hostile unit on stage (unit order, up to count); random — count points in the ring (≤ r −
## RANDOM_EDGE_CM from the centre, RANDOM_POINT_MIN_CM apart, RANDOM_TRIES draws each from one combat-stream generator,
## a point without a fit is left out); lane — the chord along x at the z offset of the next entry of `lanes` (the
## caster's lane counter alternates). Returns the id of the first shape, 0 if none could be placed.
static func create(sim: RtSim, u: RtUnit, sk: SkillDef, primary_id: String, impact_at: int) -> int:
	var spec: Dictionary = sk.rt.get("telegraph", {})
	if spec.is_empty():
		return 0
	var hostile: int = Combatant.Side.PARTY if u.side == Combatant.Side.ENEMY else Combatant.Side.ENEMY
	var t_unit: RtUnit = sim.unit(primary_id)
	var count: int = clampi(int(spec.get("count", 1)), 1, 4)
	var r_set: int = int(sim.setup.geo.get("r", 0))
	var spots: Array = []                   # [x, z, yaw]
	match str(spec.get("anchor", "target_pos")):
		"self":
			spots.append([u.x, u.z, _yaw_to(u, t_unit)])
		"each_enemy":
			for v: RtUnit in sim.units_ref():
				if spots.size() < count and v.side == hostile and sim.targetable(v) and v.entry.is_empty():
					spots.append([v.x, v.z, _yaw_to(u, v)])
		"random":
			spots = _random_points(sim, count)
		"lane":
			var lanes: Array = spec.get("lanes", [])
			var n: int = sim.next_lane(u, sk.id)
			spots.append([-r_set, int(lanes[n % lanes.size()]) if not lanes.is_empty() else 0, YAW_PLUS_X])
		_:
			var at: RtUnit = t_unit if t_unit != null and t_unit != u else u
			spots.append([at.x, at.z, _yaw_to(u, at)])
	var shape: RtTelegraph.Shape = SHAPES.get(str(spec.get("shape", "circle")), RtTelegraph.Shape.CIRCLE)
	var first: int = 0
	for s: Array in spots:
		var t: RtTelegraph = RtTelegraph.new()
		t.source_id = u.id
		t.skill_id = sk.id
		t.side = hostile
		t.shape = shape
		t.x = int(s[0])
		t.z = int(s[1])
		t.yaw = posmod(int(s[2]), 256)
		match shape:
			RtTelegraph.Shape.CONE:
				t.r = int(spec.get("radius_cm", 0))
				t.half_deg = int(spec.get("angle_deg", 0)) / 2
			RtTelegraph.Shape.RING:
				t.r = int(spec.get("radius_cm", 0))
				t.r2 = int(spec.get("inner_cm", 0))
			RtTelegraph.Shape.LINE:
				t.r = 2 * r_set if str(spec.get("anchor", "")) == "lane" else int(spec.get("length_cm", 0))
				t.r2 = int(spec.get("width_cm", 0))
			_:
				t.r = int(spec.get("radius_cm", 0))
		t.start = sim.tick()
		t.impact_at = impact_at
		var id: int = sim.add_telegraph(t)
		if first == 0:
			first = id
	return first


## Step 3 (07 §3.3): every zone (creation order) applies its status / skill to the units of its side inside it when a
## period is due (the first one period after the impact), then ends at ends_at (ZONE_END).
static func zones(sim: RtSim, c: int) -> void:
	var list: Array[RtTelegraph] = sim.telegraphs_ref()
	if list.is_empty():
		return
	var zs: Array[RtTelegraph] = []
	for t: RtTelegraph in list:
		# only the zones with something due (a period or the end; a zone's own timers change only here — the same
		# zones act as with the whole list)
		if t.is_zone and ((t.period > 0 and t.next_tick_at == c) or (t.ends_at >= 0 and t.ends_at <= c)):
			zs.append(t)
	for z: RtTelegraph in zs:
		if z.period > 0 and z.next_tick_at == c:
			z.next_tick_at += z.period
			_zone_tick(sim, z)
		if z.ends_at >= 0 and z.ends_at <= c and list.has(z):
			sim.end_zone(z)


## Step 4 (07 §3.3, §6.3): every telegraph striking at c, creation order (a shape whose source fell earlier in this
## step is gone already).
static func impacts(sim: RtSim, c: int) -> void:
	var list: Array[RtTelegraph] = sim.telegraphs_ref()
	if list.is_empty():
		return
	var due: Array[RtTelegraph] = []
	for t: RtTelegraph in list:
		if not t.is_zone and t.impact_at == c:
			due.append(t)
	for t: RtTelegraph in due:
		if list.has(t):
			sim.remove_telegraph(t)
			_impact(sim, t, c)


## After the movement of step 9 (07 §6.3): every pending telegraph notes the units of its side standing in it now
## (inside_last = c) — the dodge test of the impact.
static func track(sim: RtSim, c: int) -> void:
	var list: Array[RtTelegraph] = sim.telegraphs_ref()
	if list.is_empty():
		return
	var side_units: Array[RtUnit] = []
	for v: RtUnit in sim.party_ref():
		if v.hp > 0 and not v.left_battle:
			side_units.append(v)
	for t: RtTelegraph in list:
		if t.is_zone or t.impact_at <= c:
			continue
		if t.side == Combatant.Side.PARTY:
			var tx: int = t.x
			var tz: int = t.z
			var far2: int = t.far2
			for v: RtUnit in side_units:
				var vx: int = v.x
				var vz: int = v.z
				if (far2 < 0 or (vx - tx) * (vx - tx) + (vz - tz) * (vz - tz) <= far2) and t.contains(vx, vz):
					t.inside_last[v.id] = c
			continue
		for v: RtUnit in sim.units_ref():
			if v.side == t.side and v.hp > 0 and not v.left_battle and t.contains(v.x, v.z):
				t.inside_last[v.id] = c


## Removes the pending telegraphs (no zones) of `src_id` — those of one cast (`start_ct`, `skill_id`) or, with
## start_ct −1, all of them (KO, escape): TELEGRAPH_CANCELLED each, creation order.
static func cancel(sim: RtSim, src_id: String, start_ct: int, skill_id: String) -> void:
	var list: Array[RtTelegraph] = sim.telegraphs_ref()
	if list.is_empty():
		return
	var drop: Array[RtTelegraph] = []
	for t: RtTelegraph in list:
		if t.is_zone or t.source_id != src_id:
			continue
		if start_ct >= 0 and (t.start != start_ct or t.skill_id != skill_id):
			continue
		drop.append(t)
	for t: RtTelegraph in drop:
		sim.remove_telegraph(t)
		sim.ev(ActionEvent.Type.TELEGRAPH_CANCELLED).value = t.id


## Ends every zone that hits `side` (phase op clear_zones): ZONE_END each, creation order.
static func clear_zones(sim: RtSim, side: int) -> void:
	var zs: Array[RtTelegraph] = []
	for t: RtTelegraph in sim.telegraphs_ref():
		if t.is_zone and t.side == side:
			zs.append(t)
	for z: RtTelegraph in zs:
		sim.end_zone(z)


# --- private --------------------------------------------------------------------------------------------------------

## One impact (07 §6.3): the hits — units of the hit side on stage whose centre is in the shape (inside the ring), with
## kill_adds also the caster's own side (not the caster) —, TELEGRAPH_IMPACT (target_ids = all of them), the dodges of
## the hit side (in the shape at a step 9 since the start, out of it now: TELEGRAPH_DODGED, success = close, i.e. still
## inside CLOSE_DODGE_TICKS before), the skill's effect (Kind.TELEGRAPH; once-effects such as a self status also
## without hits), own summons KO'd at once (train kills) and other own units hit like the hit side, the zone, the dash
## (a caster that is not stationary jumps to the end of its line, POS_CORRECTED).
static func _impact(sim: RtSim, t: RtTelegraph, c: int) -> void:
	var src: RtUnit = sim.unit(t.source_id)
	var sk: SkillDef = sim.skill_def(t.skill_id)
	var kill_adds: bool = sk != null and bool(sk.rt.get("kill_adds", false))
	var hits: PackedStringArray = []
	var own: Array[RtUnit] = []
	var gate: int = sim.on_stage_gate()
	for v: RtUnit in sim.units_ref():
		if v.hp <= 0 or v.left_battle or (v.side == Combatant.Side.ENEMY and v.pop_in_until > gate) \
				or not t.contains(v.x, v.z):             # (RtSim.targetable inlined)
			continue
		if v.side == t.side:
			hits.append(v.id)
		elif kill_adds and v != src:
			own.append(v)
	var ev: ActionEvent = sim.ev(ActionEvent.Type.TELEGRAPH_IMPACT)
	ev.actor_id = t.source_id
	ev.skill_id = t.skill_id
	ev.value = t.id
	ev.target_ids = hits.duplicate()
	for v: RtUnit in own:
		ev.target_ids.append(v.id)
	if not t.inside_last.is_empty():
		var close: int = sim.bal.i("CLOSE_DODGE_TICKS")
		for v: RtUnit in sim.units_ref():
			if v.side == t.side and t.inside_last.has(v.id) and not hits.has(v.id) and sim.is_alive(v):
				_dodged(sim, v, t, int(t.inside_last[v.id]) >= c - close)
	if sk == null or src == null:
		return
	if not hits.is_empty() and t.side == Combatant.Side.PARTY:
		_party_hit(sim, hits)
	Ability.resolve_skill(sim, src, sk, hits, true, K.SKILL, Damage.Kind.TELEGRAPH, "")
	for v: RtUnit in own:
		if not sim.is_alive(v):
			continue
		if v.is_summon:
			sim.tally["train_kills"] = int(sim.tally["train_kills"]) + 1
			Damage.ko(sim, v, src, sk.id, "", v.hp, false, -1, true)
		else:
			Damage.skill_hit(sim, src, v, sk, Damage.Kind.TELEGRAPH, true, K.SKILL)
	var zone: Dictionary = sk.rt.get("zone", {})
	if not zone.is_empty():
		_add_zone(sim, t, zone, c)
	if bool(sk.rt.get("dash", false)) and t.shape == RtTelegraph.Shape.LINE and sim.is_alive(src) and not src.stationary:
		var f: Vector2i = DetMath.dir(t.yaw)
		var p: Vector2i = RtGeo.project_walkable(sim.setup.geo, t.x + FixedMath.div_round(f.x * t.r, DetMath.ONE),
			t.z + FixedMath.div_round(f.y * t.r, DetMath.ONE), src.radius, false)
		if p.x != src.x or p.y != src.z:
			src.x = p.x
			src.z = p.y
			var pe: ActionEvent = sim.ev_target(ActionEvent.Type.POS_CORRECTED, src)
			pe.rt = {"x": src.x, "z": src.z}


## TELEGRAPH_DODGED (by_ai: a sim-driven unit); the controlled figure's own dodges count for the result (07 §3.12).
static func _dodged(sim: RtSim, v: RtUnit, t: RtTelegraph, close: bool) -> void:
	var e: ActionEvent = sim.ev_target(ActionEvent.Type.TELEGRAPH_DODGED, v)
	e.value = t.id
	e.success = close
	e.by_ai = sim.is_ai_driven(v)
	if v.id == sim.controlled_id() and not e.by_ai:
		sim.tally["dodges"] = int(sim.tally["dodges"]) + 1


## A telegraph hit party units: no boss phase is perfect any more (07 §6.4); a hit on the person's own figure counts
## (telegraph_hits, 07 §3.12).
static func _party_hit(sim: RtSim, hits: PackedStringArray) -> void:
	for v: RtUnit in sim.units_ref():
		if v.side == Combatant.Side.ENEMY and v.is_boss:
			v.phase_perfect = false
	var ctl: RtUnit = sim.unit(sim.controlled_id())
	if ctl != null and hits.has(ctl.id) and not sim.is_ai_driven(ctl):
		sim.tally["telegraph_hits"] = int(sim.tally["telegraph_hits"]) + 1


## The zone left by an impact (07 §6.3): the telegraph's geometry for zone.ms, a period every zone.period_ms (the first
## one period after the impact), status or tick skill.
static func _add_zone(sim: RtSim, t: RtTelegraph, zone: Dictionary, c: int) -> void:
	var z: RtTelegraph = RtTelegraph.new()
	z.source_id = t.source_id
	z.skill_id = t.skill_id
	z.side = t.side
	z.shape = t.shape
	z.x = t.x
	z.z = t.z
	z.yaw = t.yaw
	z.r = t.r
	z.r2 = t.r2
	z.half_deg = t.half_deg
	z.set_r = t.set_r
	z.is_zone = true
	z.start = c
	z.impact_at = -1
	z.period = maxi(1, int(zone.get("period_ms", 0)) * 3 / 100)
	z.next_tick_at = c + z.period
	z.ends_at = c + maxi(1, int(zone.get("ms", 0)) * 3 / 100)
	z.status_id = str(zone.get("status", ""))
	z.tick_skill = str(zone.get("skill", ""))
	sim.add_telegraph(z)


## One zone period: its status (default duration, resistance rolled) or its tick skill (Kind.ZONE: no telegraph hit)
## on every unit of its side on stage inside it.
static func _zone_tick(sim: RtSim, z: RtTelegraph) -> void:
	var ids: PackedStringArray = []
	for v: RtUnit in sim.units_ref():
		if v.side == z.side and v.hp > 0 and not v.left_battle and sim.targetable(v) and z.contains(v.x, v.z):
			ids.append(v.id)
	if ids.is_empty():
		return
	if z.status_id != "":
		for id: String in ids:
			StatusFx.apply(sim, z.source_id, sim.unit(id), z.status_id, 0, 1000, 0, null, false, true)
		return
	var sk: SkillDef = sim.skill_def(z.tick_skill)
	var src: RtUnit = sim.unit(z.source_id)
	if sk != null and src != null:
		Ability.resolve_skill(sim, src, sk, ids, true, -1, Damage.Kind.ZONE, "")


static func _yaw_to(u: RtUnit, t: RtUnit) -> int:
	if t == null or (t.x == u.x and t.z == u.z):
		return u.yaw
	return DetMath.yaw_of(t.x - u.x, t.z - u.z)


## `count` random points (07 §6.3 "random"), one combat-stream generator for the whole set.
static func _random_points(sim: RtSim, count: int) -> Array:
	var out: Array = []
	var r: int = int(sim.setup.geo.get("r", 0)) - RANDOM_EDGE_CM
	if r <= 0:
		return out
	var min_d: int = sim.bal.i("RANDOM_POINT_MIN_CM")
	var rng: RandomNumberGenerator = sim.rng()
	for _k in count:
		for _try in RANDOM_TRIES:
			var x: int = rng.randi_range(-r, r)
			var z: int = rng.randi_range(-r, r)
			if x * x + z * z > r * r:
				continue
			var ok: bool = true
			for p: Array in out:
				if DetMath.dist2(x, z, int(p[0]), int(p[1])) < min_d * min_d:
					ok = false
					break
			if ok:
				out.append([x, z, 0])
				break
	return out
