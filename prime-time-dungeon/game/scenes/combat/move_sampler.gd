extends RefCounted
## MoveSampler (07 §3.5.1, R2): turns the physics body of the controlled figure into recorded position samples
## (`move_sample`, grade A). Once per combat tick, BEFORE submit / step, the CombatDirector asks sample_for() with the
## body's room-local state; a sample [x, z, vx, vz, yaw] is due when one of the conditions of 07 §3.5.1 holds:
##   - first sample of the combat (the sim takes the controlled figure's start position from it, 07 §3.5.5),
##   - deviation actual ↔ dead reckoning > DR_THRESHOLD_CM (15 cm),
##   - velocity change on an axis > DR_VEL_THRESHOLD (15 mm/tick),
##   - yaw change while standing > DR_YAW_THRESHOLD (8 steps),
##   - heartbeat while moving: ≥ HEARTBEAT_TICKS (15) since the last sample,
##   - standstill reached: once with vx = vz = 0,
##   - forced sample before an impact: an enemy telegraph impacts at ct + 1 (and, for an exact position in the impact
##     tick itself, at ct) and the deviation is > FORCE_SAMPLE_CM (2 cm).
## Values: x, z = rounded room-local cm of the feet; vx, vz = roundi(v_m_s × 1000 / 30) mm/tick (≤ 400); yaw u8 =
## posmod(roundi(rotation.y × 256 / τ), 256). Dead reckoning = 07 §3.5.1 in closed form (cm from mm/tick via
## FixedMath-style rounding half away from zero). Private helper of scenes/combat (no class_name); pure — no node, no
## clock — so test_r2_move_sampler drives it directly.

const FixedMath := preload("res://core/stats/fixed_math.gd")
const POS_MAX_CM: int = 2400                  # RtCommand schema
const VEL_MAX_MM: int = 400

var dr_threshold_cm: int = 15
var dr_vel_threshold: int = 15
var dr_yaw_threshold: int = 8
var dr_max_ticks: int = 30
var heartbeat_ticks: int = 15
var force_sample_cm: int = 2

var last: Array[int] = []                     # last sent sample [ct, x, z, vx, vz, yaw]; [] = none yet
var sent: int = 0
var reasons: Dictionary = {}                  # reason → count (tests, diagnostics)


## Thresholds from RtBalance (07 §3.16); null keeps the start values.
func configure(bal: RtBalance) -> void:
	if bal == null:
		return
	dr_threshold_cm = bal.i("DR_THRESHOLD_CM")
	dr_vel_threshold = bal.i("DR_VEL_THRESHOLD")
	dr_yaw_threshold = bal.i("DR_YAW_THRESHOLD")
	dr_max_ticks = bal.i("DR_MAX_TICKS")
	heartbeat_ticks = bal.i("HEARTBEAT_TICKS")
	force_sample_cm = bal.i("FORCE_SAMPLE_CM")


func reset() -> void:
	last = []
	sent = 0
	reasons = {}


## The sample due at tick `ct` for the body state (room-local cm, mm/tick, yaw u8), or [] when none is due.
## `impact_soon`: an enemy telegraph impacts at ct or ct + 1.
func sample_for(ct: int, x: int, z: int, vx: int, vz: int, yaw: int, impact_soon: bool = false) -> Array[int]:
	var s: Array[int] = [clampi(x, -POS_MAX_CM, POS_MAX_CM), clampi(z, -POS_MAX_CM, POS_MAX_CM),
		clampi(vx, -VEL_MAX_MM, VEL_MAX_MM), clampi(vz, -VEL_MAX_MM, VEL_MAX_MM), posmod(yaw, 256)]
	var why: String = _reason(ct, s, impact_soon)
	if why == "":
		var none: Array[int] = []
		return none
	last = [ct, s[0], s[1], s[2], s[3], s[4]]
	sent += 1
	reasons[why] = int(reasons.get(why, 0)) + 1
	return s


func _reason(ct: int, s: Array[int], impact_soon: bool) -> String:
	if last.is_empty():
		return "first"
	var dr: Vector2i = dead_reckon(last, ct, dr_max_ticks)
	var dev: int = dist_cm(dr.x - s[0], dr.y - s[1])
	var moving: bool = s[2] != 0 or s[3] != 0
	var was_moving: bool = last[3] != 0 or last[4] != 0
	if impact_soon and dev > force_sample_cm:
		return "impact"
	if dev > dr_threshold_cm:
		return "deviation"
	if absi(s[2] - last[3]) > dr_vel_threshold or absi(s[3] - last[4]) > dr_vel_threshold:
		return "velocity"
	if not moving and was_moving:
		return "stop"
	if not moving and yaw_diff(s[4], last[5]) > dr_yaw_threshold:
		return "yaw"
	if moving and ct - last[0] >= heartbeat_ticks:
		return "heartbeat"
	return ""


## 07 §3.5.1: pos(c) = (s.x + div_round(s.vx × n, 10), s.z + div_round(s.vz × n, 10)), n = min(c − s.ct, DR_MAX_TICKS).
static func dead_reckon(s: Array[int], c: int, dr_max: int) -> Vector2i:
	var n: int = clampi(c - s[0], 0, dr_max)
	return Vector2i(s[1] + FixedMath.div_round(s[3] * n, 10), s[2] + FixedMath.div_round(s[4] * n, 10))


## Integer length (cm) of (dx, dz), rounded down (exact integer square root).
static func dist_cm(dx: int, dz: int) -> int:
	var n: int = dx * dx + dz * dz
	var r: int = int(sqrt(float(n)))
	while r * r > n:
		r -= 1
	while (r + 1) * (r + 1) <= n:
		r += 1
	return r


## Circular difference of two u8 yaws (0..128).
static func yaw_diff(a: int, b: int) -> int:
	var d: int = posmod(a - b, 256)
	return mini(d, 256 - d)


## Room-local cm of a world position (origin = the set cell centre).
static func local_cm(world: Vector3, origin: Vector3) -> Vector2i:
	return Vector2i(roundi((world.x - origin.x) * 100.0), roundi((world.z - origin.z) * 100.0))


## mm per tick of a velocity in m/s (07 §3.5.1: roundi(v × 1000 / 30)).
static func vel_mm(v: Vector3) -> Vector2i:
	return Vector2i(roundi(v.x * 1000.0 / 30.0), roundi(v.z * 1000.0 / 30.0))


## Scene yaw → u8 (07 §3.2).
static func yaw_u8(rot_y: float) -> int:
	return posmod(roundi(rot_y * 256.0 / TAU), 256)


## u8 → scene yaw (radians).
static func yaw_rad(yaw: int) -> float:
	return float(yaw) * TAU / 256.0
