class_name SeasonState extends RefCounted
## The season block of GameState (09 §9.1: GameState.season; null = no season — the switch of every rule of 09, so a
## run without a season stays bit-identical). Set once by the command {"t": "season", "op": "start"} (template id,
## format, tempo, mode, number, day0_utc, collapse_utc; SeasonRules.apply) and moved by the clock commands "clock" /
## "away" (the season clock `utc` grows only through them, 09 V-17) and by the season hooks of the run (floor start,
## safe room, stairs, combat end, the Am-Stück countdown). Part of the save (Save v2 season block) and of StateHash.of —
## everything except UNHASHED_KEYS (the local wall clock seen last, offline only). Pure data: the rules are
## SeasonRules', the schedule arithmetic SeasonClock's.
##
## Season time ("now", SeasonRules.now): in the calendar tempo the season clock `utc`; Am Stück the binge clock
## binge_utc0 + 144 × explored seconds (SeasonClock.BINGE_FACTOR: one season day ≙ ten minutes of exploration time,
## 09 §2.1) — fee_at, finale_at, descent_at and reached are season times.

const VERSION: int = 1
const TEMPOS: PackedStringArray = ["calendar", "binge"]   # Kalender | Am Stück (09 §2.1)
const MODES: PackedStringArray = ["net", "no_net"]        # Mit Netz | Ohne Netz (09 §7)
## The candidate's season result ("" = still playing; every other value makes them a studio guest, 09 §2.7, §7.2):
## finalist (Großes Finale won), end (the last collapse — "Bis zum Ende dabei" — or the end of the content, 09 ST1-B
## decision), fallen / buried (Ohne Netz: died / collapsed from floor 2 on), left (Staffel beenden, 09 §2.2).
const RESULTS: PackedStringArray = ["", "finalist", "end", "fallen", "buried", "left"]
## to_dict keys StateHash.of leaves out (== StateHash.EXCLUDED_SEASON_KEYS): the local wall clock (09 §9.1).
const UNHASHED_KEYS: PackedStringArray = ["seen_unix"]

# --- the start command (09 §9.1) ----------------------------------------------------------------------------------
var def_id: String = ""                    # ssn_ template (seasons.json)
var format: int = 6                        # floors of the season (6 | 12 | 18)
var tempo: String = "calendar"
var mode: String = "net"
var number: int = 0                        # "Staffel 37"
var day0_utc: int = 0                      # unix seconds of day 0 (the first air time at / after the start, V-17)
var collapse_utc: Array[int] = []          # unix seconds of every collapse, one per floor (pauses move the open ones)
var cast: Dictionary = {}                  # the start command's cast block (09 §4, ST1-F)
# --- the clock --------------------------------------------------------------------------------------------------------
var utc: int = 0                           # the season clock (unix seconds; only clock / away move it)
var seen_unix: int = 0                     # the local wall clock seen last (offline only, never hashed)
var collapsed: int = 0                     # floors collapsed so far — the floor on air is collapsed + 1
var hold_utc: int = 0                      # a collapse that fell into a combat waits until here (0 = none; V-17)
var after_combat: bool = false             # a combat ended since the last clock command (its time comes next)
var next_air_utc: int = 0                  # the next air time (the daily programme, 09 §3.3)
var airs: int = 0                          # air times passed (day 0 is the first)
var pause_sec: int = 0                     # Sendepause used ("why": "user"; at most 14 days, 09 §2.9)
var binge_utc0: int = 0                    # Am Stück: the season time the binge clock starts from
var binge_sec: int = 0                     # Am Stück: explored seconds counted on finished floors
var binge_mark: int = 0                    # Am Stück: explored seconds of the current floor not counted (switch)
# --- the floors ------------------------------------------------------------------------------------------------------
var programme: Array[int] = []             # programme points per floor (index floor − 1), at most 5 (09 §3.3)
var reached: Array[int] = []               # season time the candidate first stood on floor N (index N − 1), -1 = never
var last_safe_room: String = ""            # the safe room entered last on the current floor (the medics' goal, §7.1)
# --- the candidate ---------------------------------------------------------------------------------------------------
var vest: bool = true                      # weiße Weste: never rescued, never died (from floor 2 on, 09 §2.3)
var rescues: int = 0                       # rescues from floor 2 on (the Quote counts them; floor 1 does not)
var deaths: int = 0                        # deaths from floor 2 on
var fee_at: int = -1                       # season time of the last fee (rescue or medics; -1 = never; 7 days)
var stairs: int = 0                        # floors left by the stairs (the Quote)
var qbosses: int = 0                       # Revier-Bosse defeated (the Quote)
var fbosses: int = 0                       # Etagenbosse defeated (the Quote; the finale's boss counts too)
var finale_at: int = -1                    # season time of the finale victory (tie-break, 09 §2.7)
var descent_at: int = -1                   # season time of the last descent by the stairs (tie-break)
var result: String = ""                    # RESULTS
var result_floor: int = 0                  # the floor of the result ("verschüttet auf Etage N")
# --- the sleeper (09 §5; ST1-B records the logout, ST1-G resolves the absence) --------------------------------------
var asleep: bool = false
var sleep_tactic: String = ""              # RtVocab.RT_PRESETS (careful | support | attack)
var sleep_room: String = ""                # the safe room the sleeper lies in ("" = a corridor)
# --- Staffeln (09, ST1-G) ---
## The night of a sleeper (SleepResolver.on_sleep fills it, "away" resolves and clears it): {"v", "at" (season time
## of the logout), "cell" ([x, y] where the figure lies), "floor", "seq" (the cast's newest event then — the news of
## the login summary start after it), "quiet" (seconds of Sendepause taken during this night: the clock stands)} —
## integers only (SLEEPER_KEYS). Written only while it holds something, so every season state of ST1-B, D and F keeps
## its JSON and hash.
const SLEEPER_KEYS: PackedStringArray = ["v", "at", "floor", "seq", "quiet"]
var sleeper: Dictionary = {}


## The save / hash form (integers, bools and strings only; every field, always — a season has no older form).
func to_dict() -> Dictionary:
	return {"v": VERSION, "def": def_id, "format": format, "tempo": tempo, "mode": mode, "number": number,
		"day0_utc": day0_utc, "collapse_utc": collapse_utc.duplicate(), "cast": cast.duplicate(true),
		"utc": utc, "seen_unix": seen_unix, "collapsed": collapsed, "hold_utc": hold_utc,
		"after_combat": after_combat, "next_air_utc": next_air_utc, "airs": airs, "pause_sec": pause_sec,
		"binge_utc0": binge_utc0, "binge_sec": binge_sec, "binge_mark": binge_mark,
		"programme": programme.duplicate(), "reached": reached.duplicate(), "last_safe_room": last_safe_room,
		"vest": vest, "rescues": rescues, "deaths": deaths, "fee_at": fee_at, "stairs": stairs, "qbosses": qbosses,
		"fbosses": fbosses, "finale_at": finale_at, "descent_at": descent_at, "result": result,
		"result_floor": result_floor, "asleep": asleep, "sleep_tactic": sleep_tactic, "sleep_room": sleep_room
		}.merged({"sleeper": sleeper.duplicate(true)} if not sleeper.is_empty() else {})   # Staffeln (09, ST1-G)


## Missing fields → defaults (an ST0-shaped block loads; the per-floor arrays stay as they are — SeasonRules reads a
## missing entry as 0 / -1 and grows them when it writes); numbers through JsonUtil (JSON numbers are floats).
static func from_dict(d: Dictionary) -> SeasonState:
	var s: SeasonState = SeasonState.new()
	s.def_id = str(d.get("def", ""))
	s.format = JsonUtil.to_int(d.get("format", 6), 6)
	s.tempo = str(d.get("tempo", "calendar"))
	s.mode = str(d.get("mode", "net"))
	s.number = maxi(0, JsonUtil.to_int(d.get("number", 0)))
	s.day0_utc = JsonUtil.to_int(d.get("day0_utc", 0))
	s.collapse_utc = _ints(d.get("collapse_utc", []))
	var raw_cast: Variant = d.get("cast", {})
	s.cast = (raw_cast as Dictionary).duplicate(true) if raw_cast is Dictionary else {}
	s.utc = JsonUtil.to_int(d.get("utc", 0))
	s.seen_unix = JsonUtil.to_int(d.get("seen_unix", 0))
	s.collapsed = clampi(JsonUtil.to_int(d.get("collapsed", 0)), 0, maxi(0, s.format))
	s.hold_utc = maxi(0, JsonUtil.to_int(d.get("hold_utc", 0)))
	s.after_combat = bool(d.get("after_combat", false))
	s.next_air_utc = JsonUtil.to_int(d.get("next_air_utc", s.day0_utc), s.day0_utc)
	s.airs = maxi(0, JsonUtil.to_int(d.get("airs", 0)))
	s.pause_sec = maxi(0, JsonUtil.to_int(d.get("pause_sec", 0)))
	s.binge_utc0 = JsonUtil.to_int(d.get("binge_utc0", s.utc), s.utc)
	s.binge_sec = JsonUtil.to_int(d.get("binge_sec", 0))
	s.binge_mark = JsonUtil.to_int(d.get("binge_mark", 0))
	s.programme = _ints(d.get("programme", []))
	s.reached = _ints(d.get("reached", []))
	s.last_safe_room = str(d.get("last_safe_room", ""))
	s.vest = bool(d.get("vest", true))
	s.rescues = maxi(0, JsonUtil.to_int(d.get("rescues", 0)))
	s.deaths = maxi(0, JsonUtil.to_int(d.get("deaths", 0)))
	s.fee_at = JsonUtil.to_int(d.get("fee_at", -1), -1)
	s.stairs = maxi(0, JsonUtil.to_int(d.get("stairs", 0)))
	s.qbosses = maxi(0, JsonUtil.to_int(d.get("qbosses", 0)))
	s.fbosses = maxi(0, JsonUtil.to_int(d.get("fbosses", 0)))
	s.finale_at = JsonUtil.to_int(d.get("finale_at", -1), -1)
	s.descent_at = JsonUtil.to_int(d.get("descent_at", -1), -1)
	s.result = str(d.get("result", ""))
	s.result_floor = maxi(0, JsonUtil.to_int(d.get("result_floor", 0)))
	s.asleep = bool(d.get("asleep", false))
	s.sleep_tactic = str(d.get("sleep_tactic", ""))
	s.sleep_room = str(d.get("sleep_room", ""))
	s.sleeper = sleeper_from(d.get("sleeper", {}))                 # Staffeln (09, ST1-G)
	return s


## Staffeln (09, ST1-G): the sleeper block in its canonical form — the integer keys of SLEEPER_KEYS and "cell" as
## [x, y] (JSON numbers are floats); {} for anything that is not a block.
static func sleeper_from(raw: Variant) -> Dictionary:
	var out: Dictionary = {}
	if not (raw is Dictionary) or (raw as Dictionary).is_empty():
		return out
	var d: Dictionary = raw
	for k: String in SLEEPER_KEYS:
		out[k] = JsonUtil.to_int(d.get(k, 0))
	var cell: Variant = d.get("cell", [])
	if cell is Array and (cell as Array).size() == 2:
		out["cell"] = [JsonUtil.to_int((cell as Array)[0]), JsonUtil.to_int((cell as Array)[1])]
	return out


## The floor on air (09 §1.1: the floor whose collapse comes next); format + 1 once every floor collapsed.
func on_air() -> int:
	return collapsed + 1


## Programme points of `floor` (0 for a floor the array does not reach).
func points(floor: int) -> int:
	return programme[floor - 1] if floor >= 1 and floor <= programme.size() else 0


## Season time the candidate first stood on `floor`; -1 = never (or beyond the array).
func reached_at(floor: int) -> int:
	return reached[floor - 1] if floor >= 1 and floor <= reached.size() else -1


## Sets the programme points of `floor` (the array grows as needed).
func set_points(floor: int, n: int) -> void:
	while programme.size() < floor:
		programme.append(0)
	programme[floor - 1] = n


## Sets the season time the candidate first stood on `floor` (the array grows as needed).
func set_reached(floor: int, t: int) -> void:
	while reached.size() < floor:
		reached.append(-1)
	reached[floor - 1] = t


static func _ints(raw: Variant) -> Array[int]:
	var out: Array[int] = []
	if raw is Array:
		for v: Variant in (raw as Array):
			out.append(JsonUtil.to_int(v))
	return out


## `a` cut or padded with `fill` to `n` entries.
static func _sized(a: Array[int], n: int, fill: int) -> Array[int]:
	var out: Array[int] = []
	for i in maxi(0, n):
		out.append(a[i] if i < a.size() else fill)
	return out
