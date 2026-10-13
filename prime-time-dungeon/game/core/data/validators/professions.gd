# STUB(ST0) — owned by 09-ST1-E. Replace completely, keep the public API.
extends RefCounted
## Validation of data/professions.json (09 §8.5): the professions (entries, prefix prf_, kind gather | craft | side)
## and the top-level lists recipes (rcp_: profession, grade 1–6, requirement 1–300, at most one hobby_recipe per
## profession — 09 §8.6), materials (mat_: grade) and nodes (nod_: gathering nodes of a profession, grade,
## requirement). Private helper of DataValidator (no class_name; preloaded as ProfessionsCheck). ST0 ships the schema,
## the id patterns and the references; ST1-E adds ingredients, results and its content rules.

const SPEC: Array = [["id", "s"], ["name", "s"], ["kind", "s"]]
const KINDS: PackedStringArray = ["gather", "craft", "side"]
## list → [spec, id pattern kind of DataValidator.ID_PATTERNS]
const LISTS: Dictionary = {
	"recipes": [[["id", "s"], ["name", "s"], ["prof", "s"], ["grade", "i", 1], ["req", "i", 1],
		["hobby_recipe", "b", false]], "recipes"],
	"materials": [[["id", "s"], ["name", "s"], ["grade", "i", 1]], "materials"],
	"nodes": [[["id", "s"], ["name", "s"], ["prof", "s"], ["grade", "i", 1], ["req", "i", 1]], "nodes"],
}
const GRADE_MAX: int = 6
const VALUE_MAX: int = 300


## One profession ({} if not an object).
static func normalize(v: DataValidator, ctx: String, raw: Variant) -> Dictionary:
	var d: Dictionary = v._norm(ctx, raw, SPEC)
	if not d.is_empty():
		v._enum(ctx + ".kind", str(d["kind"]), KINDS)
	return d


## The extra top-level keys of professions.json → v._out["profession_extras"] = {<list>: [...]} (normalized).
static func read_extras(v: DataValidator, f: Dictionary) -> void:
	var out: Dictionary = {}
	for list: String in LISTS.keys():
		var entries: Array[Dictionary] = []
		var raw_l: Variant = f.get(list, [])
		if not (raw_l is Array):
			v._err("professions." + list, "must be an array")
			raw_l = []
		for i in (raw_l as Array).size():
			var e: Dictionary = v._norm(v._ctx("professions." + list, i, (raw_l as Array)[i]), (raw_l as Array)[i],
				LISTS[list][0])
			if not e.is_empty():
				entries.append(e)
		out[list] = entries
	v._out["profession_extras"] = out


## Id patterns and uniqueness of the lists, grades and requirements, the profession of every recipe and node, at most
## one hobby recipe per profession.
static func check(v: DataValidator) -> void:
	var profs: Dictionary = {}
	for d: Dictionary in v._out.get("professions", []):
		profs[str(d["id"])] = true
	var extras: Dictionary = v._out.get("profession_extras", {})
	var seen: Dictionary = {}
	for list: String in LISTS.keys():
		var pattern: String = str(DataValidator.ID_PATTERNS[str(LISTS[list][1])])
		for e: Dictionary in extras.get(list, []):
			var id: String = str(e["id"])
			var ctx: String = "professions.%s[%s]" % [list, id]
			if not v._matches(pattern, id):
				v._err(ctx, "invalid id (pattern %s)" % pattern)
			if seen.has(id) or profs.has(id):
				v._err(ctx, "duplicate id")
			seen[id] = true
			if str(e["name"]) == "":
				v._err(ctx + ".name", "must not be empty")
			v._range_i(ctx + ".grade", int(e["grade"]), 1, GRADE_MAX)
			if e.has("req"):
				v._range_i(ctx + ".req", int(e["req"]), 1, VALUE_MAX)
			if e.has("prof") and not profs.has(str(e["prof"])):
				v._err(ctx + ".prof", "unknown profession '%s'" % str(e["prof"]))
	var hobby: Dictionary = {}
	for r: Dictionary in extras.get("recipes", []):
		if not bool(r["hobby_recipe"]):
			continue
		var prof: String = str(r["prof"])
		if hobby.has(prof):
			v._err("professions.recipes[%s].hobby_recipe" % str(r["id"]),
				"%s already has the hobby recipe %s (one per profession, 09 §8.6)" % [prof, str(hobby[prof])])
		hobby[prof] = str(r["id"])
