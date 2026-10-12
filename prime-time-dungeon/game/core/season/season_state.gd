# STUB(ST0) — owned by 09-ST1-B. Replace completely, keep the public API.
class_name SeasonState extends RefCounted
## The season block of GameState (09 §9.1: GameState.season; null = no season — the switch of every rule of 09, so a
## run without a season stays bit-identical). Set once by the command {"t": "season", "op": "start"} (template id,
## format, tempo, mode, number, day0_utc, collapse_utc) and moved by the clock commands "clock" / "away" (the season
## clock `utc` grows only through them, 09 V-17). Part of the save (Save v2 season block) and of StateHash.of —
## everything except UNHASHED_KEYS (the local wall clock seen last, offline only).
## ST0 (contract pass): the fields of the start command plus the clock; ST1-B adds the rest of 09 §9.1 (pauses,
## collapses, rescues, deaths, vest, out, first ascents, sleep tactic, programme) and keeps this API.

const VERSION: int = 1
const TEMPOS: PackedStringArray = ["calendar", "binge"]   # Kalender | Am Stück (09 §2.1)
const MODES: PackedStringArray = ["net", "no_net"]        # Mit Netz | Ohne Netz (09 §7)
## to_dict keys StateHash.of leaves out (== StateHash.EXCLUDED_SEASON_KEYS): the local wall clock (09 §9.1).
const UNHASHED_KEYS: PackedStringArray = ["seen_unix"]

var def_id: String = ""                    # ssn_ template (seasons.json)
var format: int = 6                        # floors of the season (6 | 12 | 18)
var tempo: String = "calendar"
var mode: String = "net"
var number: int = 0                        # "Staffel 37"
var day0_utc: int = 0                      # unix seconds of day 0 (the first air time after the start, V-17)
var collapse_utc: Array[int] = []          # unix seconds of every collapse, one per floor
var utc: int = 0                           # the season clock (unix seconds; only clock / away move it)
var seen_unix: int = 0                     # the local wall clock seen last (offline only, never hashed)


## The save / hash form (integers and strings only).
func to_dict() -> Dictionary:
	return {"v": VERSION, "def": def_id, "format": format, "tempo": tempo, "mode": mode, "number": number,
		"day0_utc": day0_utc, "collapse_utc": collapse_utc.duplicate(), "utc": utc, "seen_unix": seen_unix}


## Missing fields → defaults; numbers through JsonUtil (JSON numbers are floats).
static func from_dict(d: Dictionary) -> SeasonState:
	var s: SeasonState = SeasonState.new()
	s.def_id = str(d.get("def", ""))
	s.format = JsonUtil.to_int(d.get("format", 6), 6)
	s.tempo = str(d.get("tempo", "calendar"))
	s.mode = str(d.get("mode", "net"))
	s.number = maxi(0, JsonUtil.to_int(d.get("number", 0)))
	s.day0_utc = JsonUtil.to_int(d.get("day0_utc", 0))
	var raw: Variant = d.get("collapse_utc", [])
	if raw is Array:
		for v: Variant in (raw as Array):
			s.collapse_utc.append(JsonUtil.to_int(v))
	s.utc = JsonUtil.to_int(d.get("utc", 0))
	s.seen_unix = JsonUtil.to_int(d.get("seen_unix", 0))
	return s
