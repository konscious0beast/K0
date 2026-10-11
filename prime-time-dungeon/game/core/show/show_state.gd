class_name ShowState extends RefCounted
## Viewers/followers/hype/counters (part of GameState, 02_TECH §6.1).
##
## Hype is kept in whole points (Show.add_hype rounds every change in integer per-mille arithmetic), so the state
## stays integral for the canonical state hash (05 §3.3 Nr. 5/9). `viewers` is the last noise-free value
## (summary/save; display field, not hashed).

var viewers: int = 0                         # last noise-free value (summary/save)
var followers: int = 0
var hype: float = 30.0
var stats: Dictionary = {}                   # StatIds → int
var achievements: PackedStringArray = []     # unlocked ids
var milestones: PackedStringArray = []       # reached ms ids
var sponsor_uses: Dictionary = {}            # sponsor id → total gifts given
## 06-C: M.O.D.'s preferences of the floor and the Liga counters (06 §4; MarottenRules owns every write):
## {"floor": int, "active": [mar ids], "hits": {id: int}, "won": [ids won this floor], "prev": [ids of the previous
## floor], "zones": int (mar_pacifist: new rooms since the last battle / hit), "liga": {"battles", "t1", "t2"} (won
## battles of the floor, of them at Liga tier >= 1 / tier 2) + "followers" (the floor's Liga follower bonus so far,
## capped per floor; after the first won Liga battle), optional "bonus" (06 B × C: the preference that got the talent's
## extra heart this floor)}. {} = none yet (old saves, before the first floor).
var marotten: Dictionary = {}


func to_dict() -> Dictionary:
	return {
		"viewers": viewers,
		"followers": followers,
		"hype": hype,
		"stats": _int_dict(stats),
		"achievements": Array(achievements),
		"milestones": Array(milestones),
		"sponsor_uses": _int_dict(sponsor_uses),
		"marotten": marotten_dict(marotten),                     # 06-C
	}


## Missing fields → defaults; numbers are converted with int()/float() (JSON numbers are floats).
static func from_dict(d: Dictionary) -> ShowState:
	var s: ShowState = ShowState.new()
	s.viewers = maxi(0, JsonUtil.to_int(d.get("viewers", 0)))
	s.followers = maxi(0, JsonUtil.to_int(d.get("followers", 0)))
	s.hype = ShowModel.clamp_hype(JsonUtil.to_float(d.get("hype", ShowModel.HYPE_START), ShowModel.HYPE_START))
	var raw_stats: Variant = d.get("stats", {})
	if raw_stats is Dictionary:
		s.stats = _int_dict(raw_stats)
	s.achievements = _unique(JsonUtil.to_str_array(d.get("achievements", [])))
	s.milestones = _unique(JsonUtil.to_str_array(d.get("milestones", [])))
	var raw_uses: Variant = d.get("sponsor_uses", {})
	if raw_uses is Dictionary:
		s.sponsor_uses = _int_dict(raw_uses)
	s.marotten = marotten_dict(d.get("marotten", {}))           # 06-C
	return s


## 06-C: the marotten record with JSON-stable types (ints, String arrays, sorted int dictionaries); {} for anything
## that is not a Dictionary or an empty one. Keeps "bonus" (06 B × C, "Kamera 3 kennt mich" spent on this floor —
## integration round 4: before, a save → load on the same floor dropped it and the extra heart came again).
static func marotten_dict(raw: Variant) -> Dictionary:
	if not (raw is Dictionary) or (raw as Dictionary).is_empty():
		return {}
	var d: Dictionary = raw
	var hits: Variant = d.get("hits", {})
	var liga: Variant = d.get("liga", {})
	var out: Dictionary = {
		"floor": maxi(0, JsonUtil.to_int(d.get("floor", 0))),
		"active": Array(_unique(JsonUtil.to_str_array(d.get("active", [])))),
		"hits": _int_dict(hits if hits is Dictionary else {}),
		"won": Array(_unique(JsonUtil.to_str_array(d.get("won", [])))),
		"prev": Array(_unique(JsonUtil.to_str_array(d.get("prev", [])))),
		"zones": maxi(0, JsonUtil.to_int(d.get("zones", 0))),
		"liga": _int_dict(liga if liga is Dictionary else {}),
	}
	if d.get("bonus", null) is String and str(d["bonus"]) != "":
		out["bonus"] = str(d["bonus"])
	return out


## Sorted String keys, int values.
static func _int_dict(src: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var keys: Array = src.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
	for k: Variant in keys:
		out[str(k)] = JsonUtil.to_int(src[k])
	return out


static func _unique(a: PackedStringArray) -> PackedStringArray:
	var out: PackedStringArray = []
	for s: String in a:
		if s != "" and not out.has(s):
			out.append(s)
	return out
