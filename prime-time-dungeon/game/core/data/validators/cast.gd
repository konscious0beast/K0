# STUB(ST0) — owned by 09-ST1-F. Replace completely, keep the public API.
extends RefCounted
## Validation of data/cast.json (09 §4.2, §4.4): the profiles of the AI candidates (entries: id, name, weight of the
## profile in the population — Statist:in 50, Rival:in 15, …) and the top-level list `names` (the invented name
## catalog: {"name", "form": n | f | m}, unique, no origin or age markers). Private helper of DataValidator (no
## class_name; preloaded as CastCheck). ST0 ships the schema; ST1-F adds the profile rules and the catalog size.

const SPEC: Array = [["id", "s"], ["name", "s"], ["weight", "i", 1]]
const SPEC_NAME: Array = [["name", "s"], ["form", "s", "n"]]
const FORMS: PackedStringArray = ["n", "f", "m"]
const NAME_MAX: int = 28


## One profile ({} if not an object).
static func normalize(v: DataValidator, ctx: String, raw: Variant) -> Dictionary:
	var d: Dictionary = v._norm(ctx, raw, SPEC)
	if not d.is_empty():
		v._range_i(ctx + ".weight", int(d["weight"]), 1, 100)
	return d


## The extra top-level key of cast.json → v._out["cast_extras"] = {"names": [...]} (normalized).
static func read_extras(v: DataValidator, f: Dictionary) -> void:
	var names: Array[Dictionary] = []
	var raw_n: Variant = f.get("names", [])
	if not (raw_n is Array):
		v._err("cast.names", "must be an array")
		raw_n = []
	for i in (raw_n as Array).size():
		var e: Dictionary = v._norm("cast.names[%d]" % i, (raw_n as Array)[i], SPEC_NAME)
		if not e.is_empty():
			names.append(e)
	v._out["cast_extras"] = {"names": names}


## Profile names, the name catalog (length, word form, unique).
static func check(v: DataValidator) -> void:
	for d: Dictionary in v._out.get("cast", []):
		if str(d["name"]) == "":
			v._err("cast[%s].name" % str(d["id"]), "must not be empty")
	var seen: Dictionary = {}
	var names: Array = (v._out.get("cast_extras", {}) as Dictionary).get("names", [])
	for i in names.size():
		var e: Dictionary = names[i]
		var ctx: String = "cast.names[%d]" % i
		var n: String = str(e["name"])
		if n == "" or n.length() > NAME_MAX:
			v._err(ctx + ".name", "1..%d characters" % NAME_MAX)
		if seen.has(n):
			v._err(ctx + ".name", "'%s' twice" % n)
		seen[n] = true
		v._enum(ctx + ".form", str(e["form"]), FORMS)
