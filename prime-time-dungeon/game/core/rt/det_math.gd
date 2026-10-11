class_name DetMath extends RefCounted
## Integer geometry of the real-time combat (07 §3.2, §3.14): u8 yaw angles, ×1024 direction vectors from tables,
## the cosine of whole degrees, the exact integer square root, distances and the shape tests of party areas and
## telegraphs. Nothing here uses float math except the single isqrt line (07 §3.14 Nr. 1, the only `det-ok` of
## core/rt). The tables were computed once offline (round half away from zero) and are constants.
##
## Conventions (07 §3.2): yaw 0 = −Z (Godot forward), 64 = −X, 128 = +Z, 192 = +X (counter-clockwise from above, like
## rotation.y); dir(yaw) = (−SIN1024[yaw], −COS1024[yaw]) with COS1024[y] = SIN1024[y + 64].

const FixedMath := preload("res://core/stats/fixed_math.gd")

const ONE: int = 1024
## sin(yaw × 2π / 256) × 1024 for yaw 0..255.
const SIN1024: PackedInt32Array = [
	0, 25, 50, 75, 100, 125, 150, 175, 200, 224, 249, 273, 297, 321, 345, 369,
	392, 415, 438, 460, 483, 505, 526, 548, 569, 590, 610, 630, 650, 669, 688, 706,
	724, 742, 759, 775, 792, 807, 822, 837, 851, 865, 878, 891, 903, 915, 926, 936,
	946, 955, 964, 972, 980, 987, 993, 999, 1004, 1009, 1013, 1016, 1019, 1021, 1023, 1024,
	1024, 1024, 1023, 1021, 1019, 1016, 1013, 1009, 1004, 999, 993, 987, 980, 972, 964, 955,
	946, 936, 926, 915, 903, 891, 878, 865, 851, 837, 822, 807, 792, 775, 759, 742,
	724, 706, 688, 669, 650, 630, 610, 590, 569, 548, 526, 505, 483, 460, 438, 415,
	392, 369, 345, 321, 297, 273, 249, 224, 200, 175, 150, 125, 100, 75, 50, 25,
	0, -25, -50, -75, -100, -125, -150, -175, -200, -224, -249, -273, -297, -321, -345, -369,
	-392, -415, -438, -460, -483, -505, -526, -548, -569, -590, -610, -630, -650, -669, -688, -706,
	-724, -742, -759, -775, -792, -807, -822, -837, -851, -865, -878, -891, -903, -915, -926, -936,
	-946, -955, -964, -972, -980, -987, -993, -999, -1004, -1009, -1013, -1016, -1019, -1021, -1023, -1024,
	-1024, -1024, -1023, -1021, -1019, -1016, -1013, -1009, -1004, -999, -993, -987, -980, -972, -964, -955,
	-946, -936, -926, -915, -903, -891, -878, -865, -851, -837, -822, -807, -792, -775, -759, -742,
	-724, -706, -688, -669, -650, -630, -610, -590, -569, -548, -526, -505, -483, -460, -438, -415,
	-392, -369, -345, -321, -297, -273, -249, -224, -200, -175, -150, -125, -100, -75, -50, -25,
]
## cos(d°) × 1024 for d = 0..90 (91 entries); 91..180 by symmetry.
const COS_DEG1024: PackedInt32Array = [
	1024, 1024, 1023, 1023, 1022, 1020, 1018, 1016, 1014, 1011, 1008, 1005, 1002, 998, 994, 989,
	984, 979, 974, 968, 962, 956, 949, 943, 935, 928, 920, 912, 904, 896, 887, 878,
	868, 859, 849, 839, 828, 818, 807, 796, 784, 773, 761, 749, 737, 724, 711, 698,
	685, 672, 658, 644, 630, 616, 602, 587, 573, 558, 543, 527, 512, 496, 481, 465,
	449, 433, 416, 400, 384, 367, 350, 333, 316, 299, 282, 265, 248, 230, 213, 195,
	178, 160, 143, 125, 107, 89, 71, 54, 36, 18, 0,
]


## sin of a u8 yaw × 1024 (any int, taken mod 256).
static func sin_y(yaw: int) -> int:
	return SIN1024[posmod(yaw, 256)]


## cos of a u8 yaw × 1024 (any int, taken mod 256).
static func cos_y(yaw: int) -> int:
	return SIN1024[posmod(yaw + 64, 256)]


## Unit facing vector of a yaw × 1024: (−sin, −cos).
static func dir(yaw: int) -> Vector2i:
	return Vector2i(-sin_y(yaw), -cos_y(yaw))


## cos of whole degrees × 1024; deg is clamped to 0..180.
static func cos_deg1024(deg: int) -> int:
	var d: int = clampi(deg, 0, 180)
	return COS_DEG1024[d] if d <= 90 else -COS_DEG1024[180 - d]


## Exact floor(√n) for n ≥ 0 (0 for n ≤ 0): one float estimate, corrected with integers (07 §3.2).
static func isqrt(n: int) -> int:
	if n <= 0:
		return 0
	var r: int = int(sqrt(n))  # det-ok: exact integer sqrt with correction
	while r > 0 and r * r > n:
		r -= 1
	while (r + 1) * (r + 1) <= n:
		r += 1
	return r


## Squared distance (cm²).
static func dist2(ax: int, az: int, bx: int, bz: int) -> int:
	return (bx - ax) * (bx - ax) + (bz - az) * (bz - az)


## Distance, floor of the exact value (cm).
static func dist(ax: int, az: int, bx: int, bz: int) -> int:
	return isqrt(dist2(ax, az, bx, bz))


## The yaw whose dir() points along (dx, dz), nearest of the 256 steps (±1 against the exact angle; 0 for the zero
## vector). Integer search over the table: rotate into the first quadrant, then bisect the cross product.
static func yaw_of(dx: int, dz: int) -> int:
	if dx == 0 and dz == 0:
		return 0
	var a: int = -dx                     # sine component of the facing
	var b: int = -dz                     # cosine component
	var q: int = 0
	while not (a >= 0 and b > 0):        # rotate by −90° until θ ∈ [0°, 90°)
		var t: int = a
		a = -b
		b = t
		q += 1
	# f(k) = a·cos(k) − b·sin(k) (first quadrant): > 0 while the vector's angle is above step k; inlined (every step)
	var lo: int = 0                      # f(lo) ≥ 0
	var hi: int = 64                     # f(hi) < 0
	while hi - lo > 1:
		var mid: int = (lo + hi) / 2
		if a * SIN1024[64 - mid] - b * SIN1024[mid] >= 0:
			lo = mid
		else:
			hi = mid
	var f_lo: int = a * SIN1024[64 - lo] - b * SIN1024[lo]
	var f_next: int = a * SIN1024[63 - lo] - b * SIN1024[lo + 1]
	return posmod(q * 64 + (lo + 1 if -f_next < f_lo else lo), 256)


## Circle of radius r around (cx, cz) contains (px, pz) (boundary included).
static func in_circle(px: int, pz: int, cx: int, cz: int, r: int) -> bool:
	return r >= 0 and dist2(cx, cz, px, pz) <= r * r


## Ring inner ≤ |p − c| ≤ outer.
static func in_ring(px: int, pz: int, cx: int, cz: int, inner: int, outer: int) -> bool:
	var d2: int = dist2(cx, cz, px, pz)
	return d2 >= inner * inner and d2 <= outer * outer


## Cone with apex (ax, az), facing yaw, length len and half opening angle half_deg (07 §6.3: distance ≤ len and
## dot(dir, d) ≥ cos(half) × distance, all ×1024). The apex itself is inside.
static func in_cone(px: int, pz: int, ax: int, az: int, yaw: int, length: int, half_deg: int) -> bool:
	var vx: int = px - ax
	var vz: int = pz - az
	var d2: int = vx * vx + vz * vz
	if d2 > length * length:
		return false
	if d2 == 0:
		return true
	var f: Vector2i = dir(yaw)
	var dot: int = f.x * vx + f.y * vz
	var c: int = cos_deg1024(half_deg)
	# dot ≥ c·|v| ⇔ (dot ≥ 0 or c < 0) and comparing squares with the signs kept
	if c >= 0:
		return dot >= 0 and dot * dot >= c * c * d2
	return dot >= 0 or dot * dot <= c * c * d2


## Line (strip) from (sx, sz) along yaw: 0 ≤ längs ≤ length and |quer| ≤ width / 2 (07 §6.3).
static func in_line(px: int, pz: int, sx: int, sz: int, yaw: int, length: int, width: int) -> bool:
	var vx: int = px - sx
	var vz: int = pz - sz
	var f: Vector2i = dir(yaw)
	var along: int = f.x * vx + f.y * vz                   # längs × 1024
	if along < 0 or along > length * ONE:
		return false
	var across: int = f.x * vz - f.y * vx                  # quer × 1024
	return absi(across) * 2 <= width * ONE


## Rotates the local offset (dx right, dz behind) of a unit facing `yaw` into room coordinates (07 §3.5.5).
static func rotate_local(dx: int, dz: int, yaw: int) -> Vector2i:
	var s: int = sin_y(yaw)
	var c: int = cos_y(yaw)
	return Vector2i(FixedMath.div_round(dx * c + dz * s, ONE), FixedMath.div_round(-dx * s + dz * c, ONE))


## The point at distance `want` from (fx, fz) towards (tx, tz) (rounded; (fx, fz) itself when the points coincide).
static func toward(fx: int, fz: int, tx: int, tz: int, want: int) -> Vector2i:
	var vx: int = tx - fx
	var vz: int = tz - fz
	var d: int = isqrt(vx * vx + vz * vz)
	if d == 0:
		return Vector2i(fx, fz)
	return Vector2i(fx + FixedMath.div_round(vx * want, d), fz + FixedMath.div_round(vz * want, d))

