# STUB(ST0) — owned by 09-ST1-C. Replace completely, keep the public API.
extends RefCounted
## Validation of data/themes.json (09 §3.1, §3.3): one Kulisse per entry (prefix thm_) — its floors (1–18, each floor
## in one Kulisse at most) and its pool of Programmpunkte (`program`, ST1-C). Private helper of DataValidator (no
## class_name; preloaded as ThemesCheck). ST0 ships the schema and the floor rule; ST1-C adds the pool rules.

const SPEC: Array = [["id", "s"], ["name", "s"], ["floors", "ia", []], ["program", "a", []]]
const FLOOR_MAX: int = 18


## One Kulisse ({} if not an object).
static func normalize(v: DataValidator, ctx: String, raw: Variant) -> Dictionary:
	return v._norm(ctx, raw, SPEC)


## Names, floors 1–18 and every floor in one Kulisse at most.
static func check(v: DataValidator) -> void:
	var taken: Dictionary = {}
	for d: Dictionary in v._out.get("themes", []):
		var ctx: String = "themes[%s]" % str(d["id"])
		if str(d["name"]) == "":
			v._err(ctx + ".name", "must not be empty")
		for f: int in d["floors"]:
			if f < 1 or f > FLOOR_MAX:
				v._err(ctx + ".floors", "floor %d is not 1..%d" % [f, FLOOR_MAX])
			elif taken.has(f):
				v._err(ctx + ".floors", "floor %d is already in %s" % [f, str(taken[f])])
			else:
				taken[f] = str(d["id"])
