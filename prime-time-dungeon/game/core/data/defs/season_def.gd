class_name SeasonDef extends RefCounted
## seasons.json entry (09 §9.1, §2.1–§2.3): a season template (`ssn_`) — its format (the floors: 6, 12 or 18, from the
## content one owns, V-14) with its calendar days (24 / 54 / 84; the days per floor are SeasonClock's: 2, 3, 4, then 5),
## the kind (private | friends | public — ST1 starts private seasons only), the minimum number of humans (private 1,
## friends 2, public 10), the number of places (20–100, the rest is the AI cast), the default air time (local "HH:MM")
## and the season rules (`rules.pvp`, 09 §6.2: "arena" = no PvP against sleepers, opt-in arenas only). Immutable after
## loading (GameData freezes it).

const DEFAULT_PLACES: int = 100            # 09 §2.3: 100 places (20–100)
const DEFAULT_AIR_TIME: String = "20:00"   # 09 §2.1: the default air time, local
const KINDS: PackedStringArray = ["private", "friends", "public"]   # 09 §2.1
## The minimum humans per kind (09 §2.1, S-6): private 1, friends 2, public 10 (adjustable, F-5).
const MIN_HUMANS: Dictionary = {"private": 1, "friends": 2, "public": 10}

var id: String = ""
var name: String = ""
var format: int = 6                        # floors of the season (09 §2.1: 6 | 12 | 18)
var days: int = 24                         # calendar days (09 §2.4: 24 | 54 | 84)
var places: int = DEFAULT_PLACES
var air_time: String = DEFAULT_AIR_TIME
var rules: Dictionary = {}                 # {"pvp": "arena"} (09 §6.2)
var kind: String = "private"               # 09 §2.1: private | friends | public
var min_humans: int = 1                    # 09 §2.1: who must be there before the start


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
	r.kind = str(d.get("kind", "private"))
	r.min_humans = int(d.get("min_humans", int(MIN_HUMANS.get(r.kind, 1))))
	return r


## True for a private season (09 §2.1: Am Stück, Sendepause and the Vorabendprogramm exist only there).
func is_private() -> bool:
	return kind == "private"
