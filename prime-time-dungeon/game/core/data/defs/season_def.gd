# STUB(ST0) — owned by 09-ST1-B. Replace completely, keep the public API.
class_name SeasonDef extends RefCounted
## seasons.json entry (09 §9.1, §2.1): a season template (`ssn_`) — format (floors of the season: 6, 12 or 18), its
## days on the calendar, the number of places, the default air time (local "HH:MM") and the season rules (`rules.pvp`,
## 09 §6.2: "arena" = no PvP against sleepers, opt-in arenas only). Immutable after loading.
## ST0 (contract pass): the minimal schema of validators/seasons.gd; ST1-B adds durations, cast numbers and the rest.

const DEFAULT_PLACES: int = 100            # 09 §2.3: 100 places (20–100)
const DEFAULT_AIR_TIME: String = "20:00"   # 09 §2.1: the default air time, local

var id: String = ""
var name: String = ""
var format: int = 6                        # floors of the season (09 §2.1: 6 | 12 | 18)
var days: int = 24                         # calendar days (09 §2.4: 24 | 54 | 84)
var places: int = DEFAULT_PLACES
var air_time: String = DEFAULT_AIR_TIME
var rules: Dictionary = {}                 # {"pvp": "arena"} (09 §6.2)


static func from_dict(d: Dictionary) -> SeasonDef:
	var r: SeasonDef = SeasonDef.new()
	r.id = str(d.get("id", ""))
	r.name = str(d.get("name", ""))
	r.format = int(d.get("format", 6))
	r.days = int(d.get("days", 24))
	r.places = int(d.get("places", DEFAULT_PLACES))
	r.air_time = str(d.get("air_time", DEFAULT_AIR_TIME))
	var ru: Variant = d.get("rules", {})
	r.rules = (ru as Dictionary).duplicate(true) if ru is Dictionary else {}
	return r
