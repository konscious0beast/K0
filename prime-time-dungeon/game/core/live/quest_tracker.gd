class_name QuestTracker extends RefCounted
## Quest progress from normalized events (05 §1.3, §11.2). Only core events feed it (deterministic, identical in a
## replay); the adapter in Game (CR-4) translates signals into:
##   {"type": "enemy_killed", "enemy_id"}, {"type": "boss_defeated", "boss_id"}, {"type": "battle_started"},
##   {"type": "floor_completed", "floor"}, {"type": "achievement", "id"}, {"type": "metric", "name", "value": int}
##   with name ∈ viewers_target_peak | followers_gained_run | hype_100_count (never the noisy display viewers, CR-13).
## Optional detail events (progress before completion, 05 §1.3 "Fortschritt"):
##   {"type": "zones", "explored": int, "total": int}          → reach_stairs: explored / total × 0.9
##   {"type": "boss_hp", "boss_id", "hp": int, "max_hp": int}   → defeat_boss: 1 − best HP share
## S0 types: reach_stairs, defeat_boss, bounty, hype_peak, pacifist (then: sub quest), achievement_hunt, all_of.
## Progress is computed exactly in integer parts per million (progress_ppm); progress() is that / 1e6 (display).
## Completion latches: once complete, a quest stays complete (quest_completed fires once).

const TYPES: PackedStringArray = ["reach_stairs", "defeat_boss", "bounty", "hype_peak", "pacifist", "achievement_hunt",
	"all_of"]
const METRICS: PackedStringArray = ["viewers_target_peak", "followers_gained_run", "hype_100_count"]
const PPM: int = 1000000
const ZONE_SHARE_PM: int = 900          # reach_stairs before the stairs: explored zones × 0.9

var type: String = ""
var params: Dictionary = {}
var label_key: String = ""
var subs: Array[QuestTracker] = []      # all_of: sub quests; pacifist: [then]

var _done: bool = false
var _count: int = 0                     # bounty kills | pacifist battles | hype_peak metric value
var _seen: PackedStringArray = []       # achievement_hunt: listed achievements received
var _best_ppm: int = 0                  # defeat_boss: best (1 − hp share); reach_stairs: zone share × 0.9


## null (and a warning) if `q` is not a valid S0 quest (validate_def).
static func from_def(q: Dictionary) -> QuestTracker:
	var errs: PackedStringArray = validate_def(q)
	if not errs.is_empty():
		push_warning("[QuestTracker] invalid quest: " + "; ".join(errs))
		return null
	return _build(q)


## true = progress or completion changed.
func on_event(ev: Dictionary) -> bool:
	var before_p: int = progress_ppm()
	var before_d: bool = _done
	_feed(ev)
	return progress_ppm() != before_p or _done != before_d


func progress() -> float:
	return progress_ppm() / float(PPM)


func is_complete() -> bool:
	return _done


func to_dict() -> Dictionary:
	var sd: Array = []
	for s: QuestTracker in subs:
		sd.append(s.to_dict())
	return {"type": type, "params": CanonicalJson.normalize(params), "label_key": label_key,
		"state": {"done": _done, "count": _count, "seen": Array(_seen), "best_ppm": _best_ppm}, "subs": sd}


## Inverse of to_dict (also after a JSON round trip); null if the quest definition is invalid.
static func from_dict(d: Dictionary) -> QuestTracker:
	var q: Dictionary = {"type": d.get("type", ""), "params": d.get("params", {})}
	if d.get("label_key", null) is String:
		q["label_key"] = d["label_key"]
	if not validate_def(q).is_empty():
		return null
	var t: QuestTracker = _build(q)
	t._restore(d)
	return t


# --- additions ----------------------------------------------------------------------------------------------------

## Exact progress 0 … 1 000 000.
func progress_ppm() -> int:
	if _done:
		return PPM
	match type:
		"reach_stairs", "defeat_boss":
			return clampi(_best_ppm, 0, PPM - 1)
		"bounty":
			return _share(_count, int(params["count"]))
		"hype_peak":
			return _share(_count, int(params["target"]))
		"achievement_hunt":
			return _share(_seen.size(), int(params["min"]))
		"pacifist":
			if failed():
				return 0
			return mini(subs[0].progress_ppm(), PPM - 1) if not subs.is_empty() else 0
		"all_of":
			if subs.is_empty():
				return 0
			var total: int = 0
			for s: QuestTracker in subs:
				total += s.progress_ppm()
			return total / subs.size()
	return 0


## pacifist: the battle limit was exceeded (the quest can no longer be completed).
func failed() -> bool:
	if type == "pacifist":
		return not _done and _count > int(params["max_battles"])
	for s: QuestTracker in subs:
		if type == "all_of" and s.failed():
			return true
	return false


## Errors of a quest definition {"type", "params", "label_key"?} (S0 types only); [] = valid.
static func validate_def(q: Variant, path: String = "quest") -> PackedStringArray:
	var out: PackedStringArray = []
	if not (q is Dictionary):
		out.append(path + ": must be a Dictionary")
		return out
	var qd: Dictionary = q
	var t: String = str(qd.get("type", ""))
	if not TYPES.has(t):
		out.append("%s: unknown quest type '%s'" % [path, t])
		return out
	if qd.has("label_key") and not (qd["label_key"] is String):
		out.append(path + ".label_key: must be a String")
	if not (qd.get("params", null) is Dictionary):
		out.append(path + ".params: must be a Dictionary")
		return out
	var p: Dictionary = qd["params"]
	match t:
		"reach_stairs":
			_need_int(p, "floor", 1, path, out)
		"defeat_boss":
			_need_id(p, "boss_id", path, out)
		"bounty":
			_need_id(p, "enemy_id", path, out)
			_need_int(p, "count", 1, path, out)
		"hype_peak":
			if not METRICS.has(str(p.get("metric", ""))):
				out.append("%s.params.metric: must be one of %s" % [path, ", ".join(METRICS)])
			_need_int(p, "target", 1, path, out)
		"pacifist":
			_need_int(p, "max_battles", 0, path, out)
			out.append_array(validate_def(p.get("then", null), path + ".then"))
		"achievement_hunt":
			var ids: Variant = p.get("ids", null)
			if not (ids is Array) or (ids as Array).is_empty():
				out.append(path + ".params.ids: must be a non-empty Array")
			else:
				for a: Variant in (ids as Array):
					if not (a is String) or str(a) == "":
						out.append(path + ".params.ids: entries must be non-empty Strings")
				if _is_int(p.get("min", null)) and (int(p["min"]) < 1 or int(p["min"]) > (ids as Array).size()):
					out.append(path + ".params.min: must be 1..%d" % (ids as Array).size())
			_need_int(p, "min", 1, path, out)
		"all_of":
			var qs: Variant = p.get("quests", null)
			if not (qs is Array) or (qs as Array).is_empty():
				out.append(path + ".params.quests: must be a non-empty Array")
			else:
				for i in (qs as Array).size():
					out.append_array(validate_def((qs as Array)[i], "%s.quests[%d]" % [path, i]))
	return out


# --- internals ----------------------------------------------------------------------------------------------------

static func _build(q: Dictionary) -> QuestTracker:
	var t: QuestTracker = QuestTracker.new()
	t.type = str(q["type"])
	t.params = CanonicalJson.normalize(q["params"])
	t.label_key = str(q.get("label_key", ""))
	match t.type:
		"pacifist":
			t.subs.append(_build(t.params["then"]))
		"all_of":
			for sub: Variant in (t.params["quests"] as Array):
				t.subs.append(_build(sub))
	return t


func _feed(ev: Dictionary) -> void:
	for s: QuestTracker in subs:
		s._feed(ev)
	var et: String = str(ev.get("type", ""))
	match type:
		"reach_stairs":
			if et == "floor_completed" and _int(ev.get("floor", -1)) == int(params["floor"]):
				_done = true
			elif et == "zones" and _int(ev.get("total", 0)) > 0:
				var share: int = clampi(_int(ev.get("explored", 0)), 0, _int(ev["total"])) * ZONE_SHARE_PM \
					* (PPM / 1000) / _int(ev["total"])
				_best_ppm = maxi(_best_ppm, share)
		"defeat_boss":
			if str(ev.get("boss_id", "")) != str(params["boss_id"]):
				return
			if et == "boss_defeated":
				_done = true
			elif et == "boss_hp" and _int(ev.get("max_hp", 0)) > 0:
				var hp: int = clampi(_int(ev.get("hp", 0)), 0, _int(ev["max_hp"]))
				_best_ppm = maxi(_best_ppm, PPM - hp * PPM / _int(ev["max_hp"]))
		"bounty":
			if et == "enemy_killed" and str(ev.get("enemy_id", "")) == str(params["enemy_id"]):
				_count += 1
				_done = _done or _count >= int(params["count"])
		"hype_peak":
			if et == "metric" and str(ev.get("name", "")) == str(params["metric"]):
				_count = maxi(_count, _int(ev.get("value", 0)))
				_done = _done or _count >= int(params["target"])
		"achievement_hunt":
			var aid: String = str(ev.get("id", ""))
			if et == "achievement" and (params["ids"] as Array).has(aid) and not _seen.has(aid):
				_seen.append(aid)
				_done = _done or _seen.size() >= int(params["min"])
		"pacifist":
			if et == "battle_started":
				_count += 1
			if not _done and not subs.is_empty() and subs[0].is_complete() and _count <= int(params["max_battles"]):
				_done = true
		"all_of":
			if not _done:
				var every: bool = true
				for s: QuestTracker in subs:
					every = every and s.is_complete()
				_done = every


func _restore(d: Dictionary) -> void:
	var st: Variant = d.get("state", {})
	if st is Dictionary:
		var s: Dictionary = st
		_done = bool(s.get("done", false))
		_count = maxi(0, _int(s.get("count", 0)))
		_best_ppm = clampi(_int(s.get("best_ppm", 0)), 0, PPM)
		_seen = PackedStringArray()
		for a: Variant in (s.get("seen", []) if s.get("seen", []) is Array else []):
			if not _seen.has(str(a)):
				_seen.append(str(a))
	var sd: Variant = d.get("subs", [])
	if sd is Array:
		for i in mini(subs.size(), (sd as Array).size()):
			if (sd as Array)[i] is Dictionary:
				subs[i]._restore((sd as Array)[i])


static func _share(have: int, need: int) -> int:
	if need <= 0:
		return 0
	return mini(PPM - 1, maxi(0, have) * PPM / need)


static func _need_int(p: Dictionary, key: String, lo: int, path: String, out: PackedStringArray) -> void:
	if not _is_int(p.get(key, null)) or int(p[key]) < lo:
		out.append("%s.params.%s: must be an integer >= %d" % [path, key, lo])


static func _need_id(p: Dictionary, key: String, path: String, out: PackedStringArray) -> void:
	if not (p.get(key, null) is String) or str(p[key]) == "":
		out.append("%s.params.%s: must be a non-empty String" % [path, key])


static func _is_int(v: Variant) -> bool:
	if typeof(v) == TYPE_INT:
		return true
	return typeof(v) == TYPE_FLOAT and is_finite(float(v)) and float(v) == floorf(float(v))


static func _int(v: Variant) -> int:
	if typeof(v) == TYPE_INT:
		return v
	if typeof(v) == TYPE_FLOAT and is_finite(float(v)):
		return int(v)
	return 0
