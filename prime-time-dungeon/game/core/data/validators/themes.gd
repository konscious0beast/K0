extends RefCounted
## Validation of data/themes.json (09 §3.1, §3.3; ST1-C): one Kulisse per entry (prefix thm_) — its floors (1–18, each
## floor in one Kulisse at most), the art theme its floors render with (`art`: an art theme of DataValidator.THEMES;
## the Kulisse → art-theme mapping) and its pool of Programmpunkte (`program`: [{"id": daily_…, "name"}], ids unique
## over every Kulisse, a name the daily programme shows). Private helper of DataValidator (no class_name; preloaded as
## ThemesCheck).

const SPEC: Array = [["id", "s"], ["name", "s"], ["floors", "ia", []], ["art", "s", "metro"], ["program", "a", []]]
const POINT_SPEC: Array = [["id", "s"], ["name", "s"]]
const FLOOR_MAX: int = 18
const POINT_PATTERN: String = "^daily_[a-z0-9_]+$"
const NAME_MAX: int = 40


## One Kulisse ({} if not an object); `program` becomes the normalized points.
static func normalize(v: DataValidator, ctx: String, raw: Variant) -> Dictionary:
	var d: Dictionary = v._norm(ctx, raw, SPEC)
	if d.is_empty():
		return d
	var points: Array[Dictionary] = []
	var raw_p: Array = d["program"]
	for i in raw_p.size():
		var p: Dictionary = v._norm(DataValidator._ctx(ctx + ".program", i, raw_p[i]), raw_p[i], POINT_SPEC)
		if not p.is_empty():
			points.append(p)
	d["program"] = points
	return d


## Names, art themes, floors 1–18 and every floor in one Kulisse at most; the programme points: id pattern, unique over
## every Kulisse, a name of 1–40 characters.
static func check(v: DataValidator) -> void:
	var taken: Dictionary = {}
	var points: Dictionary = {}
	for d: Dictionary in v._out.get("themes", []):
		var ctx: String = "themes[%s]" % str(d["id"])
		if str(d["name"]) == "":
			v._err(ctx + ".name", "must not be empty")
		v._enum(ctx + ".art", str(d["art"]), DataValidator.THEMES)
		for f: int in d["floors"]:
			if f < 1 or f > FLOOR_MAX:
				v._err(ctx + ".floors", "floor %d is not 1..%d" % [f, FLOOR_MAX])
			elif taken.has(f):
				v._err(ctx + ".floors", "floor %d is already in %s" % [f, str(taken[f])])
			else:
				taken[f] = str(d["id"])
		for p: Dictionary in d["program"]:
			var pid: String = str(p["id"])
			var pctx: String = "%s.program[%s]" % [ctx, pid]
			if not v._matches(POINT_PATTERN, pid):
				v._err(pctx + ".id", "invalid id (pattern %s)" % POINT_PATTERN)
			if points.has(pid):
				v._err(pctx + ".id", "already in %s" % str(points[pid]))
			points[pid] = str(d["id"])
			var pname: String = str(p["name"])
			if pname == "" or pname.length() > NAME_MAX:
				v._err(pctx + ".name", "1..%d characters" % NAME_MAX)
