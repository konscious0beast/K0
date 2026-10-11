class_name RtTelegraph extends RefCounted
## Announced ground shape (telegraph) or lingering zone (07 §3.4, §6.3). Geometry in room-local cm; read by the
## TelegraphLayer (R2). contains() is the "Fußpunkt-Regel" shape test (centre point only, inside the set ring, DetMath);
## contains_inflated() grows the shape by a margin for the AI's dodging (ESCAPE_MARGIN_CM, 07 §5.5). R1b-I2 brings the
## geometry and the AI reaction to a new telegraph (RtSim.add_telegraph); impacts, zones and the enemy rules that
## create telegraphs follow in R1b-I3.

enum Shape { CIRCLE, CONE, RING, LINE }

var id: int = 0                             # unique per combat, increasing
var source_id: String = ""
var skill_id: String = ""
var side: int = 0                           # Combatant.Side that gets hit
var shape: RtTelegraph.Shape = Shape.CIRCLE
var x: int = 0                              # center (circle/ring), apex (cone), start (line)
var z: int = 0
var yaw: int = 0                            # cone/line direction
var r: int = 0                              # radius (circle/ring outer/cone length) or line length
var r2: int = 0                             # ring inner radius or line width
var half_deg: int = 0                       # cone half angle
var start: int = 0                          # ct of the announcement
var impact_at: int = 0                      # ct of the impact (telegraph) / -1 for zones
var is_zone: bool = false
var ends_at: int = -1                       # zones
var period: int = 0                         # zones
var next_tick_at: int = -1                  # zones
var status_id: String = ""                  # zones: status applied per period
var tick_skill: String = ""                 # zones: skill applied per period
var inside_last: Dictionary = {}            # unit id → last ct inside (dodge detection, §6.3)
var set_r: int = 0                          # the set radius the shape is clipped to (in_set, §3.5.4); 0 = unclipped


## The shape test of the point (px, pz) (07 §6.3): circle — distance ≤ r; cone — distance ≤ r and inside ±half_deg of
## yaw (the apex included); ring — r2 ≤ distance ≤ r; line — 0 ≤ längs ≤ r and |quer| ≤ r2 / 2. Only inside the set
## ring (|p| ≤ set_r) when set_r > 0.
func contains(px: int, pz: int) -> bool:
	if set_r > 0 and px * px + pz * pz > set_r * set_r:
		return false
	match shape:
		Shape.CIRCLE:
			return DetMath.in_circle(px, pz, x, z, r)
		Shape.CONE:
			return DetMath.in_cone(px, pz, x, z, yaw, r, half_deg)
		Shape.RING:
			return DetMath.in_ring(px, pz, x, z, r2, r)
		Shape.LINE:
			return DetMath.in_line(px, pz, x, z, yaw, r, r2)
	return false


## The shape grown by `margin` cm on every side (07 §5.5: does a unit stand within ESCAPE_MARGIN_CM of it?): circle
## r + m; ring r2 − m … r + m; line −m ≤ längs ≤ r + m and |quer| ≤ r2 / 2 + m; cone — within m of the apex, or within
## r + m and inside the opening or within m of one of its edges. The ring clip grows by the margin as well.
func contains_inflated(px: int, pz: int, margin: int) -> bool:
	var m: int = maxi(0, margin)
	if set_r > 0 and px * px + pz * pz > (set_r + m) * (set_r + m):
		return false
	var vx: int = px - x
	var vz: int = pz - z
	var d2: int = vx * vx + vz * vz
	match shape:
		Shape.CIRCLE:
			return d2 <= (r + m) * (r + m)
		Shape.RING:
			var inner: int = maxi(0, r2 - m)
			return d2 >= inner * inner and d2 <= (r + m) * (r + m)
		Shape.LINE:
			var f: Vector2i = DetMath.dir(yaw)
			var along: int = f.x * vx + f.y * vz                       # längs × 1024
			var across: int = f.x * vz - f.y * vx                      # quer × 1024
			return along >= -m * DetMath.ONE and along <= (r + m) * DetMath.ONE \
				and absi(across) * 2 <= (r2 + 2 * m) * DetMath.ONE
		Shape.CONE:
			if d2 <= m * m:
				return true
			if d2 > (r + m) * (r + m):
				return false
			if DetMath.in_cone(px, pz, x, z, yaw, r + m, half_deg):
				return true
			return _near_edge(vx, vz, m, 1) or _near_edge(vx, vz, m, -1)
	return false


## Canonical snapshot: every field, `shape` as int, inside_last with sorted keys.
func to_dict() -> Dictionary:
	var inside: Dictionary = {}
	var keys: Array = inside_last.keys()
	keys.sort()
	for k: Variant in keys:
		inside[str(k)] = int(inside_last[k])
	return {"id": id, "source_id": source_id, "skill_id": skill_id, "side": side, "shape": int(shape), "x": x,
		"z": z, "yaw": yaw, "r": r, "r2": r2, "half_deg": half_deg, "start": start, "impact_at": impact_at,
		"is_zone": is_zone, "ends_at": ends_at, "period": period, "next_tick_at": next_tick_at,
		"status_id": status_id, "tick_skill": tick_skill, "inside_last": inside, "set_r": set_r}


## Is the offset (vx, vz) from the apex within m of the cone edge turned by ±half_deg (sign) from the facing? The edge
## direction is the facing rotated with cos / sin of half_deg (× 1024²); only the ray in front of the apex counts.
func _near_edge(vx: int, vz: int, m: int, sign: int) -> bool:
	var f: Vector2i = DetMath.dir(yaw)
	var c: int = DetMath.cos_deg1024(half_deg)
	var s: int = DetMath.cos_deg1024(90 - half_deg) * sign
	var ex: int = f.x * c - f.y * s
	var ez: int = f.x * s + f.y * c
	if ex * vx + ez * vz <= 0:
		return false
	var cross: int = ex * vz - ez * vx
	return absi(cross) <= m * DetMath.ONE * DetMath.ONE
