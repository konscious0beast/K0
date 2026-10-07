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


func to_dict() -> Dictionary:
	return {
		"viewers": viewers,
		"followers": followers,
		"hype": hype,
		"stats": _int_dict(stats),
		"achievements": Array(achievements),
		"milestones": Array(milestones),
		"sponsor_uses": _int_dict(sponsor_uses),
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
	return s


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
