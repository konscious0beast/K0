extends RefCounted
## Positions of the real-time combat (07 §3.5) — private helper of RtSim (no class_name; preloaded as Movement):
## the player's move samples with their plausibility bounds and dead reckoning (Grad A, step 1a), the cast cancel by
## movement (§3.6.5), sim-driven movement (entry, steering, repulsion, clamping — step 9) and the flight counter.

const FixedMath := preload("res://core/stats/fixed_math.gd")
const StatusFx := preload("res://core/rt/rt_status_fx.gd")


# --- step 1a: player positions --------------------------------------------------------------------------------------

## Step 1a (07 §3.3): every PLAYER unit takes the samples of tick c (submission order, each checked §3.5.2), else dead
## reckoning from its last sample; then the cast cancel check. The position holds for every later step of c.
static func player_positions(sim: RtSim, c: int, samples: Array[Dictionary]) -> void:
	var sampled: Dictionary = {}
	for e: Dictionary in samples:
		var cmd: Dictionary = e["cmd"]
		var u: RtUnit = sim.unit(str(cmd.get("u", "")))
		if u == null or u.driver != RtUnit.Driver.PLAYER or not sim.is_alive(u):
			continue
		var p: Array = cmd.get("p", [])
		if p.size() != 5:
			continue
		apply_sample(sim, u, c, int(p[0]), int(p[1]), int(p[2]), int(p[3]), int(p[4]))
		sampled[u.id] = true
	for u: RtUnit in sim.units_ref():
		if u.driver != RtUnit.Driver.PLAYER or u.side != Combatant.Side.PARTY or not sim.is_alive(u):
			continue
		if not sampled.has(u.id):
			dead_reckon(sim, u, c)
		cast_cancel_check(sim, u, sampled.has(u.id))


## One sample s of unit u at tick c (07 §3.5.2): with the last accepted sample p and Δ = c − p.ct,
##   step_max = ⌈PLAYER_RUN_CM_S × move_pm × Δ / 30000⌉, budget = min(MOVE_BUDGET_MM, budget + Δ × MOVE_REFILL_MM_TICK),
##   excess = max(0, |s − p| − step_max) × 10 mm: within the budget it is spent, else the point is cut back on p → s to
## step_max + budget / 10 and the budget is 0 (POS_CORRECTED). Velocities are clamped to max_v (they only feed the dead
## reckoning); inside the set cell the point must be walkable (party), else the nearest walkable point (POS_CORRECTED).
## Stunned / drinking (no_move): the sample is set to the hold position.
static func apply_sample(sim: RtSim, u: RtUnit, c: int, x: int, z: int, vx: int, vz: int, yaw: int) -> void:
	var bal: RtBalance = sim.bal
	var geo: Dictionary = sim.setup.geo
	var prev: Array[int] = u.sample if u.sample.size() == 6 else [c, u.x, u.z, 0, 0, u.yaw]
	var dt: int = maxi(0, c - prev[0])
	u.move_budget = mini(bal.i("MOVE_BUDGET_MM"), u.move_budget + dt * bal.i("MOVE_REFILL_MM_TICK"))
	var corrected: bool = false
	var nx: int = x
	var nz: int = z
	var nvx: int = vx
	var nvz: int = vz
	if holds(u):
		corrected = x != u.x or z != u.z
		nx = u.x
		nz = u.z
		nvx = 0
		nvz = 0
	else:
		var mpm: int = StatusFx.factor(u, "move_pm")
		var run: int = bal.i("PLAYER_RUN_CM_S")
		var step_max: int = FixedMath.div_ceil(run * mpm * dt, 30 * 1000)
		var d: int = DetMath.dist(prev[1], prev[2], x, z)
		var excess: int = maxi(0, d - step_max) * 10
		if excess <= u.move_budget:
			u.move_budget -= excess
		else:
			var p: Vector2i = DetMath.toward(prev[1], prev[2], x, z, step_max + u.move_budget / 10)
			nx = p.x
			nz = p.y
			u.move_budget = 0
			corrected = true
		var max_v: int = FixedMath.div_ceil(run * 10 * mpm * bal.i("SPEED_TOLERANCE_PM"), 30 * 1000 * 1000)
		nvx = clampi(vx, -max_v, max_v)
		nvz = clampi(vz, -max_v, max_v)
		if in_cell(geo, nx, nz) and not RtGeo.walkable(geo, nx, nz, u.radius, true):
			var q: Vector2i = RtGeo.project_walkable(geo, nx, nz, u.radius, true)
			nx = q.x
			nz = q.y
			corrected = true
	u.x = nx
	u.z = nz
	u.yaw = posmod(yaw, 256)
	u.sample = [c, nx, nz, nvx, nvz, u.yaw]
	if corrected:
		pos_corrected(sim, u)


## Dead reckoning (07 §3.5.1): pos(c) = s.pos + v × min(c − s.ct, DR_MAX_TICKS) / 10 (mm per tick → cm); a stunned /
## drinking unit stands (its sample becomes the hold position). Inside the cell the point is clamped silently.
static func dead_reckon(sim: RtSim, u: RtUnit, c: int) -> void:
	if u.sample.size() != 6:
		return
	if holds(u):
		if u.sample[3] != 0 or u.sample[4] != 0:
			u.sample = [c, u.x, u.z, 0, 0, u.yaw]
		return
	var n: int = mini(c - u.sample[0], sim.bal.i("DR_MAX_TICKS"))
	if n <= 0:
		return
	var nx: int = u.sample[1] + FixedMath.div_round(u.sample[3] * n, 10)
	var nz: int = u.sample[2] + FixedMath.div_round(u.sample[4] * n, 10)
	var geo: Dictionary = sim.setup.geo
	if in_cell(geo, nx, nz) and not RtGeo.walkable(geo, nx, nz, u.radius, true):
		var q: Vector2i = RtGeo.project_walkable(geo, nx, nz, u.radius, true)
		nx = q.x
		nz = q.y
	u.x = nx
	u.z = nz


## Movement cancels a cast with moving_cancels only past a threshold (07 §3.6.5, E20): a sample of this tick reporting
## more than CAST_CANCEL_SPEED_PM of the run speed, or the position more than CAST_CANCEL_CM from the cast start.
static func cast_cancel_check(sim: RtSim, u: RtUnit, sampled: bool) -> void:
	if u.cast.is_empty() or not bool(u.cast.get("moving_cancels", false)):
		return
	var bal: RtBalance = sim.bal
	var cancel: bool = false
	if sampled and u.sample.size() == 6:
		var v: int = DetMath.isqrt(u.sample[3] * u.sample[3] + u.sample[4] * u.sample[4])
		var limit: int = FixedMath.div_round(bal.i("PLAYER_RUN_CM_S") * 10 * StatusFx.factor(u, "move_pm") \
			* bal.i("CAST_CANCEL_SPEED_PM"), 30 * 1000 * 1000)
		cancel = v > limit
	var cx: int = int(u.cast.get("x", u.x))
	var cz: int = int(u.cast.get("z", u.z))
	if DetMath.dist2(cx, cz, u.x, u.z) > bal.i("CAST_CANCEL_CM") * bal.i("CAST_CANCEL_CM"):
		cancel = true
	if cancel:
		sim.fail_cast(u, "moved")


## A unit that may not move (stun, drink pause).
static func holds(u: RtUnit) -> bool:
	return StatusFx.has_flag(u, "no_move") or str(u.cast.get("kind", "")) == "item"


static func in_cell(geo: Dictionary, x: int, z: int) -> bool:
	var half: int = int(geo.get("cell_half", RtGeo.DEFAULT_CELL_HALF))
	return absi(x) <= half and absi(z) <= half


static func pos_corrected(sim: RtSim, u: RtUnit) -> void:
	var ev: ActionEvent = sim.ev_target(ActionEvent.Type.POS_CORRECTED, u)
	ev.rt = {"x": u.x, "z": u.z}


# --- goals (step 7) and movement (step 9) ---------------------------------------------------------------------------

## The movement goal of a sim-driven unit (07 §3.5.3): melee — the point on the line to the target at reach + r_target
## − MELEE_STOP_CM while farther than that (it stops 30 cm inside its reach); ranged (keep_cm > 0) — towards keep_cm
## while nearer than keep − 200 or farther than keep + 200; no target — an AI partner follows the controlled figure up
## to follow_cm.
static func goal_for(sim: RtSim, u: RtUnit, t: RtUnit) -> Array[int]:
	var out: Array[int] = []
	if t == null:
		var ctl: RtUnit = sim.unit(sim.controlled_id())
		if u.side == Combatant.Side.PARTY and ctl != null and ctl != u and sim.is_alive(ctl) and u.follow_cm > 0:
			if DetMath.dist2(u.x, u.z, ctl.x, ctl.z) > u.follow_cm * u.follow_cm:
				var p: Vector2i = DetMath.toward(ctl.x, ctl.z, u.x, u.z, maxi(0, u.follow_cm - sim.bal.i("MELEE_STOP_CM")))
				out.assign([p.x, p.y])
		return out
	var dx: int = u.x - t.x
	var dz: int = u.z - t.z
	var d: int = DetMath.isqrt(dx * dx + dz * dz)
	var want: int = -1                      # the distance to the target to walk to (DetMath.toward from the target)
	if u.keep_cm > 0:
		if d > u.keep_cm + 200 or d < u.keep_cm - 200:
			if d == 0:
				out.append(t.x)
				out.append(t.z + u.keep_cm)
				return out
			want = u.keep_cm
	else:
		var stop: int = maxi(0, u.reach + t.radius - sim.bal.i("MELEE_STOP_CM"))
		if d > stop:
			want = stop
	if want >= 0:
		out.append(t.x + FixedMath.div_round(dx * want, d))
		out.append(t.z + FixedMath.div_round(dz * want, d))
	return out


## Step 9 (07 §3.3): sim-driven units (enemies, AI partner, autopilot) walk — entries first (no repulsion, at most
## ENTER_MAX_TICKS — a summon's entry from its summon tick on (its pop_in_until − POP_IN_TICKS) —, then they stand
## there; stationary units too: they appear at the end; an arriving summon is on stage at once and acts POP_IN_TICKS
## later), then goals (straight towards project_walkable(goal), min(speed, distance)), then enemy repulsion and
## clamping; finally the flight counter of the controlled unit.
static func move_units(sim: RtSim, c: int) -> void:
	var geo: Dictionary = sim.setup.geo
	var bal: RtBalance = sim.bal
	var ctl: RtUnit = sim.unit(sim.controlled_id())
	var ctl_out: bool = ctl != null and sim.is_alive(ctl) and not RtGeo.in_circle(geo, ctl.x, ctl.z, ctl.radius)
	var r: int = int(geo.get("r", 0))
	var plain: bool = r > 0 and (geo.get("blockers", []) as Array).is_empty()   # walkable = inside the circle
	for u: RtUnit in sim.units_ref():
		if u.hp <= 0 or u.left_battle:
			continue
		if u.side == Combatant.Side.PARTY and u.driver == RtUnit.Driver.PLAYER:
			continue
		if not u.entry.is_empty():
			if not u.stationary:
				_walk(u, u.entry[0], u.entry[1], speed(u))
			if (u.x == u.entry[0] and u.z == u.entry[1]) \
					or c + 1 >= maxi(bal.i("ENTER_MAX_TICKS"), u.pop_in_until - bal.i("POP_IN_TICKS")):
				u.x = u.entry[0]
				u.z = u.entry[1]
				u.entry = []
				u.pop_in_until = mini(u.pop_in_until, c + bal.i("POP_IN_TICKS"))
				sim.leader_arrived(u, c)
			continue
		if u.stationary or u.goal.size() != 2 or not u.cast.is_empty() or StatusFx.has_flag(u, "no_move"):
			continue
		var party: bool = u.side == Combatant.Side.PARTY and ctl_out
		var big: int = r - u.radius
		var gx: int = u.goal[0]
		var gz: int = u.goal[1]
		if not plain or big < 0 or gx * gx + gz * gz > big * big:      # (inside the circle: walkable as it is)
			var g: Vector2i = RtGeo.project_walkable(geo, gx, gz, u.radius, party)
			gx = g.x
			gz = g.y
		_walk(u, gx, gz, speed(u))
		if not plain or big < 0 or u.x * u.x + u.z * u.z > big * big:
			var q: Vector2i = RtGeo.project_walkable(geo, u.x, u.z, u.radius, party)
			u.x = q.x
			u.z = q.y
	_repulse(sim)
	_flight(sim, c, ctl)


## Walking speed in cm per tick (07 §3.5.3): move_cm_tick × move_pm of the statuses.
static func speed(u: RtUnit) -> int:
	return FixedMath.mul_pm(u.move_cm_tick, StatusFx.factor(u, "move_pm"))


## One straight step of at most `step_cm` cm towards (gx, gz), facing the way.
static func _walk(u: RtUnit, gx: int, gz: int, step_cm: int) -> void:
	var dx: int = gx - u.x
	var dz: int = gz - u.z
	var d: int = DetMath.isqrt(dx * dx + dz * dz)
	if d == 0 or step_cm <= 0:
		return
	u.yaw = DetMath.yaw_of(dx, dz)
	if step_cm >= d:
		u.x = gx
		u.z = gz
		return
	u.x += FixedMath.div_round(dx * step_cm, d)
	u.z += FixedMath.div_round(dz * step_cm, d)


## Enemies push each other apart (07 §3.5.3): every pair i < j closer than r_i + r_j moves by half the overlap along
## the connection (same spot: i to −x, j to +x); stationary units stay; afterwards both are clamped again.
static func _repulse(sim: RtSim) -> void:
	var geo: Dictionary = sim.setup.geo
	var list: Array[RtUnit] = []
	var on_stage: int = sim.tick() + sim.bal.i("POP_IN_TICKS")            # targetable: tick ≥ pop_in_until − POP_IN
	for u: RtUnit in sim.units_ref():
		if u.side == Combatant.Side.ENEMY and u.hp > 0 and not u.left_battle and u.entry.is_empty() \
				and on_stage >= u.pop_in_until:
			list.append(u)
	for i in list.size():
		for j in range(i + 1, list.size()):
			var a: RtUnit = list[i]
			var b: RtUnit = list[j]
			var minimum: int = a.radius + b.radius
			var dx: int = b.x - a.x
			var dz: int = b.z - a.z
			var d2: int = dx * dx + dz * dz
			if d2 >= minimum * minimum:
				continue
			var d: int = DetMath.isqrt(d2)
			var push: int = (minimum - d + 1) / 2
			var px: int = -push
			var pz: int = 0
			if d > 0:
				px = -FixedMath.div_round(dx * push, d)
				pz = -FixedMath.div_round(dz * push, d)
			if not a.stationary:
				var qa: Vector2i = RtGeo.project_walkable(geo, a.x + px, a.z + pz, a.radius, false)
				a.x = qa.x
				a.z = qa.y
			if not b.stationary:
				var qb: Vector2i = RtGeo.project_walkable(geo, b.x - px, b.z - pz, b.radius, false)
				b.x = qb.x
				b.z = qb.y


## Flight (07 §2.5): the controlled unit outside the ring (door lane or beyond) FLEE_TICKS consecutive ticks flees;
## at FLEE_WARN_TICKS a FLEE_WARNING (value = ticks left) and a flight attempt are counted.
static func _flight(sim: RtSim, c: int, ctl: RtUnit) -> void:
	if ctl == null or not sim.is_alive(ctl):
		return
	if RtGeo.in_circle(sim.setup.geo, ctl.x, ctl.z, ctl.radius):
		ctl.outside_since = -1
		return
	if ctl.outside_since < 0:
		ctl.outside_since = c
	var n: int = c - ctl.outside_since + 1
	var flee_ticks: int = sim.bal.i("FLEE_TICKS")
	if n == sim.bal.i("FLEE_WARN_TICKS"):
		var ev: ActionEvent = sim.ev(ActionEvent.Type.FLEE_WARNING)
		ev.actor_id = ctl.id
		ev.value = flee_ticks - n
		sim.tally["flee_attempts"] = int(sim.tally["flee_attempts"]) + 1
	if n >= flee_ticks:
		sim.flee_now(null)
