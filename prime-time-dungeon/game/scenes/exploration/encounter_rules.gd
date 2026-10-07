extends RefCounted
## Pure exploration rules (02_TECH §7.3, GDD §2.1/§2.3/§2.4): perception, field strike arc, contact and the
## advantage table. Private helper of M3 (no class_name, §0.3); used via preload by the actors and tests.
## All directions are taken in the XZ plane.

const CONTACT_RADIUS: float = 1.1          # GDD §2.3: symbol ≤ 1.1 m at Kai → battle
const BOSS_TRIGGER_RADIUS: float = 5.0     # §7.3: bosses fight when Kai enters 5 m around boss_spot
const STRIKE_RANGE: float = 1.8            # field strike reach
const STRIKE_ARC_DEG: float = 100.0        # field strike arc
const STRIKE_DURATION: float = 0.45
const STRIKE_COOLDOWN: float = 0.6
const STRIKE_HIT_FROM: float = 0.08        # the arc hits from this moment of the swing until STRIKE_DURATION
const INTERACT_RADIUS: float = 1.5         # interactables within 1.5 m …
const INTERACT_CONE_DEG: float = 120.0     # … and in the 120° cone in front of Kai
const GRACE_SEC: float = 2.0               # after a battle / flight: Kai unhittable + invisible
const GRACE_RETURN_RADIUS: float = 6.0     # enemies within 6 m go RETURN after a battle

## BattleSetup.Advantage values (mirrored; BattleSetup is M1's class, the ints are the contract of encounter_triggered).
const NORMAL: int = 0
const PREEMPTIVE: int = 1
const AMBUSH: int = 2


## XZ direction (normalized, y = 0) from `from` to `to`; Vector3.ZERO if they coincide.
static func flat_dir(from: Vector3, to: Vector3) -> Vector3:
	var d: Vector3 = Vector3(to.x - from.x, 0.0, to.z - from.z)
	return d.normalized() if d.length_squared() > 0.000001 else Vector3.ZERO


static func flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Forward (−Z of the node basis) flattened to XZ.
static func flat_forward(basis: Basis) -> Vector3:
	var f: Vector3 = -basis.z
	f.y = 0.0
	return f.normalized() if f.length_squared() > 0.000001 else Vector3.FORWARD


## Yaw (rotation.y) that makes −Z point along `dir`.
static func yaw_of(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)


## True when `target` lies inside the arc of `arc_deg` around `fwd` within `max_dist` (XZ).
static func in_arc(origin: Vector3, fwd: Vector3, target: Vector3, max_dist: float, arc_deg: float) -> bool:
	var dist: float = flat_dist(origin, target)
	if dist > max_dist:
		return false
	if dist < 0.0001:
		return true
	var dir: Vector3 = flat_dir(origin, target)
	return fwd.dot(dir) >= cos(deg_to_rad(arc_deg * 0.5)) - 0.000001


## True when `other` stands behind an actor that looks along `fwd`: dot(fwd, dir actor→other) < back_dot.
static func is_behind(actor_pos: Vector3, fwd: Vector3, other_pos: Vector3, back_dot: float) -> bool:
	var d: Vector3 = flat_dir(actor_pos, other_pos)
	if d == Vector3.ZERO:
		return false
	return fwd.dot(d) < back_dot


## Field strike hits a group (§7.3 row 1): PREEMPTIVE if the group is IDLE/PATROL or Kai stands behind it
## (dot(fwd_e, d_ek) < BACK_DOT); NORMAL otherwise and always for bosses.
static func strike_advantage(state: StringName, enemy_pos: Vector3, fwd_e: Vector3, kai_pos: Vector3, is_boss: bool,
		back_dot: float) -> int:
	if is_boss:
		return NORMAL
	if state == &"IDLE" or state == &"PATROL":
		return PREEMPTIVE
	if is_behind(enemy_pos, fwd_e, kai_pos, back_dot):
		return PREEMPTIVE
	return NORMAL


## Contact ≤ 1.1 m (§7.3 rows 2–4): Kai touches a group that is not chasing from behind → PREEMPTIVE; a chasing group
## (that can move at all) touches Kai from behind (dot(fwd_k, d_ke) < BACK_DOT) → AMBUSH; else NORMAL; bosses NORMAL.
static func contact_advantage(state: StringName, enemy_pos: Vector3, fwd_e: Vector3, kai_pos: Vector3, fwd_k: Vector3,
		is_boss: bool, can_ambush: bool, back_dot: float) -> int:
	if is_boss:
		return NORMAL
	if state != &"CHASE" and is_behind(enemy_pos, fwd_e, kai_pos, back_dot):
		return PREEMPTIVE
	if state == &"CHASE" and can_ambush and is_behind(kai_pos, fwd_k, enemy_pos, back_dot):
		return AMBUSH
	return NORMAL


## Sight cone check without the line-of-sight raycast (that needs the physics space).
static func in_sight_cone(enemy_pos: Vector3, fwd_e: Vector3, kai_pos: Vector3, sight_range: float,
		sight_angle_deg: float) -> bool:
	if sight_range <= 0.0 or sight_angle_deg <= 0.0:
		return false
	return in_arc(enemy_pos, fwd_e, kai_pos, sight_range, sight_angle_deg)


## Hearing radius for Kai's current movement (GDD §2.3): walking/running → hear_run, sneaking or standing → hear_sneak.
static func hearing_radius(explore: Dictionary, moving: bool, sneaking: bool) -> float:
	if moving and not sneaking:
		return float(explore.get("hear_run", 4.0))
	return float(explore.get("hear_sneak", 1.5))


## Explore parameters with defaults (EnemyDef.explore is normalized by GameData; null def → defaults that never react).
static func explore_params(def: EnemyDef) -> Dictionary:
	var p: Dictionary = {"field_speed": 0.0, "patrol_speed": 1.8, "sight_range": 10.0, "sight_angle_deg": 110.0,
		"hear_run": 4.0, "hear_sneak": 1.5, "giveup_no_sight": 4.0, "leash": 20.0, "max_chase": 8.0}
	if def == null:
		p["sight_range"] = 0.0
		p["hear_run"] = 0.0
		p["hear_sneak"] = 0.0
		return p
	for k: Variant in def.explore.keys():
		p[str(k)] = float(def.explore[k])
	return p


## Chase give-up (§7.3): no sight for giveup_no_sight s, OR farther than leash from the leash point, OR max_chase s.
static func should_give_up(no_sight_sec: float, dist_from_leash: float, chase_sec: float, explore: Dictionary) -> bool:
	return no_sight_sec >= float(explore.get("giveup_no_sight", 4.0)) \
		or dist_from_leash > float(explore.get("leash", 20.0)) \
		or chase_sec >= float(explore.get("max_chase", 8.0))
