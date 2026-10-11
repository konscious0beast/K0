# STUB(R1a) — owned by R1b. Replace completely, keep the public API.
class_name RtTelegraph extends RefCounted
## Announced ground shape (telegraph) or lingering zone (07 §3.4, §6.3). Geometry in room-local cm; read by the
## TelegraphLayer (R2). contains() is the "Fußpunkt-Regel" shape test (center point only, inside the set ring) — R1b
## implements it with DetMath; the stub contains nothing.

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


## DetMath shape test of the point (px, pz) (R1b). Stub: false.
func contains(_px: int, _pz: int) -> bool:
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
		"status_id": status_id, "tick_skill": tick_skill, "inside_last": inside}
