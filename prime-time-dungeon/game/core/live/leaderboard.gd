class_name Leaderboard extends RefCounted
## Local top 10 of an event (05 §1.5, §10.4; S0: user://leaderboards/<event_id>.json via Save).
## Entries are leaderboard dictionaries (schema 05 §10.4: "score", "run_wall_ms", "finished_at", "players", …),
## stored normalized (integral floats → int). Order: score descending → run_wall_ms ascending → finished_at
## ascending (ISO-8601 UTC strings compare chronologically); full ties keep the earlier entry first.
## from_dict() never fails: a corrupt file yields an empty board (the game keeps running, 05 §2 S0).

const SCHEMA: int = 1
const MAX_ENTRIES: int = 10

var _entries: Array[Dictionary] = []


## Rank, 1-based; top 10 kept. An entry that does not make the top 10 (or has no numeric score) is not stored → 0.
func add(entry: Dictionary) -> int:
	if not _valid_entry(entry):
		push_warning("[Leaderboard] entry without a numeric score ignored")
		return 0
	var e: Dictionary = CanonicalJson.normalize(entry)
	var pos: int = _entries.size()
	for i in _entries.size():
		if is_better(e, _entries[i]):
			pos = i
			break
	if pos >= MAX_ENTRIES:
		return 0
	_entries.insert(pos, e)
	if _entries.size() > MAX_ENTRIES:
		_entries.resize(MAX_ENTRIES)
	return pos + 1


func top(n: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in mini(maxi(0, n), _entries.size()):
		out.append(_entries[i].duplicate(true))
	return out


## a ranks strictly before b.
static func is_better(a: Dictionary, b: Dictionary) -> bool:
	var sa: int = _int(a.get("score", 0))
	var sb: int = _int(b.get("score", 0))
	if sa != sb:
		return sa > sb
	var wa: int = _wall(a)
	var wb: int = _wall(b)
	if wa != wb:
		return wa < wb
	var fa: String = str(a.get("finished_at", ""))
	var fb: String = str(b.get("finished_at", ""))
	if fa != fb:
		if fa == "" or fb == "":
			return fb == ""           # a known finishing time ranks before an unknown one
		return fa < fb
	return false


func to_dict() -> Dictionary:
	return {"schema": SCHEMA, "entries": top(MAX_ENTRIES)}


## Corrupt → empty board (never null). Invalid entries are dropped, the rest re-sorted and capped at 10.
static func from_dict(d: Dictionary) -> Leaderboard:
	var board: Leaderboard = Leaderboard.new()
	if d.has("schema") and _int(d["schema"]) != SCHEMA:
		return board
	var raw: Variant = d.get("entries", [])
	if not (raw is Array):
		return board
	for e: Variant in (raw as Array):
		if e is Dictionary and _valid_entry(e):
			board.add(e)
	return board


func size() -> int:
	return _entries.size()


static func _valid_entry(e: Dictionary) -> bool:
	var s: Variant = e.get("score", null)
	return (typeof(s) == TYPE_INT) or (typeof(s) == TYPE_FLOAT and is_finite(float(s)) and float(s) == floorf(float(s)))


## run_wall_ms; missing/invalid/0 (S0 local runs) counts as unknown → after every measured time.
static func _wall(e: Dictionary) -> int:
	var w: int = _int(e.get("run_wall_ms", 0))
	return w if w > 0 else 9223372036854775807


static func _int(v: Variant) -> int:
	if typeof(v) == TYPE_INT:
		return v
	if typeof(v) == TYPE_FLOAT and is_finite(float(v)):
		return int(v)
	return 0


# --- Casting (08, K0) / Echtzeitkampf (07, R1a): the one SIM_VERSION bump --------------------------------------------

## "" for an entry of this kernel (or one without "sim_version"), else RunSim.OLD_VERSION / NEW_VERSION — the UI tags
## such entries "ältere Version" (RunSim.OLD_VERSION_TAG, 08 §10.2 Nr. 7: K1 shows it in the lobby and the results)
## instead of treating them as a mismatch; they keep their rank.
static func version_status(entry: Dictionary) -> String:
	return RunSim.version_status(entry)
