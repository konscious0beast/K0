# STUB(K0) — owned by 08-K1. Replace completely, keep the public API.
extends RefCounted
## Validation of data/origins.json (08 §3.8, §3.9): the origin tiles (entries) and the lists talents, hobbies,
## traits, rivals, brands, gags, greetings, plans and the canon persona. Private helper of DataValidator (no
## class_name; preloaded as OriginsCheck). K0 ships the schema (normalization of every list, the start talents with
## their effect ranges from validators/talents.gd), the id patterns and id uniqueness; K1 adds the content rules of
## 08 §3.9 (texts and lengths, references, counts, keywords, allowed effect kinds, canon validity).

const TalentsRules := preload("res://core/data/validators/talents.gd")

const SPEC: Array = [["id", "s"], ["name", "s"], ["icon", "s", ""], ["status", "b", false], ["role", "d", {}],
	["jobs", "a", []], ["keywords", "sa", []], ["talent", "s"], ["alt", "s", ""], ["spec_hint", "s", ""],
	["flavor", "s", ""], ["mod_tags", "sa", []], ["rivals", "sa", []], ["brand", "s", ""]]
## Start talents: the talents.json fields without for / max_rank / weight / min_level (implicitly kai / 1 / 1 / 1).
const SPEC_TALENT: Array = [["id", "s"], ["name", "s"], ["desc", "s", ""], ["icon", "s"], ["effects", "a"]]
const SPEC_JOB: Array = [["id", "s"], ["n", "s"], ["f", "s", ""], ["m", "s", ""]]
## list → [spec, id pattern kind of DataValidator.ID_PATTERNS]
const LISTS: Dictionary = {
	"hobbies": [[["id", "s"], ["name", "s"], ["icon", "s", ""], ["keywords", "sa", []], ["talent", "s"],
		["title", "s", ""], ["desc", "s", ""], ["club", "d", {}], ["gag", "s", ""], ["greeting", "s", ""]], "hobbies"],
	"traits": [[["id", "s"], ["name", "s"], ["bias", "s", ""]], "traits"],
	"rivals": [[["id", "s"], ["name", "s"]], "rivals"],
	"brands": [[["id", "s"], ["name", "s"]], "brands"],
	"gags": [[["id", "s"], ["name", "s"]], "gags"],
	"greetings": [[["id", "s"]], "greetings"],
	"plans": [[["id", "s"], ["slots", "a", []]], "plans"],
}
const SPEC_CANON: Array = [["name", "s"], ["form", "s", "n"], ["origin", "s"], ["occupation", "s", ""],
	["hobby", "s", ""], ["traits", "sa", []], ["talent", "s"]]


## One origin tile ({} if not an object).
static func normalize(v: DataValidator, ctx: String, raw: Variant) -> Dictionary:
	var d: Dictionary = v._norm(ctx, raw, SPEC)
	if d.is_empty():
		return d
	var jobs: Array[Dictionary] = []
	var raw_jobs: Array = d["jobs"]
	for i in raw_jobs.size():
		var j: Dictionary = v._norm("%s.jobs[%d]" % [ctx, i], raw_jobs[i], SPEC_JOB)
		if not j.is_empty():
			jobs.append(j)
	d["jobs"] = jobs
	return d


## The extra top-level keys of origins.json → v._out["origin_extras"] = {"talents": [...], <list>: [...],
## "canon": {...}} (normalized).
static func read_extras(v: DataValidator, f: Dictionary) -> void:
	var out: Dictionary = {}
	var talents: Array[Dictionary] = []
	var raw_t: Variant = f.get("talents", [])
	if not (raw_t is Array):
		v._err("origins.talents", "must be an array")
		raw_t = []
	for i in (raw_t as Array).size():
		var t: Dictionary = _talent(v, v._ctx("origins.talents", i, (raw_t as Array)[i]), (raw_t as Array)[i])
		if not t.is_empty():
			talents.append(t)
	out["talents"] = talents
	for list: String in LISTS.keys():
		var entries: Array[Dictionary] = []
		var raw_l: Variant = f.get(list, [])
		if not (raw_l is Array):
			v._err("origins." + list, "must be an array")
			raw_l = []
		for i in (raw_l as Array).size():
			var e: Dictionary = v._norm(v._ctx("origins." + list, i, (raw_l as Array)[i]), (raw_l as Array)[i],
				LISTS[list][0])
			if not e.is_empty():
				entries.append(e)
		out[list] = entries
	out["canon"] = v._norm("origins.canon", f.get("canon", {}), SPEC_CANON) if f.has("canon") else {}
	v._out["origin_extras"] = out


## Id patterns and uniqueness of the origin talents and lists (start talents never share an id with talents.json).
## K1 adds the content rules of 08 §3.9.
static func check(v: DataValidator) -> void:
	var extras: Dictionary = v._out.get("origin_extras", {})
	var pool: Dictionary = {}
	for t: Dictionary in v._out.get("talents", []):
		pool[str(t["id"])] = true
	_ids(v, "origins.talents", extras.get("talents", []), "origin_talents", pool)
	for list: String in LISTS.keys():
		_ids(v, "origins." + list, extras.get(list, []), str(LISTS[list][1]), {})
	for o: Dictionary in v._out.get("origins", []):
		for j: Dictionary in o.get("jobs", []):
			if not v._matches(str(DataValidator.ID_PATTERNS["occupations"]), str(j["id"])):
				v._err("origins[%s].jobs.%s" % [str(o["id"]), str(j["id"])], "invalid occupation id")


static func _talent(v: DataValidator, ctx: String, raw: Variant) -> Dictionary:
	var d: Dictionary = v._norm(ctx, raw, SPEC_TALENT)
	if d.is_empty():
		return d
	var effects: Array[Dictionary] = []
	var raw_e: Array = d["effects"]
	for i in raw_e.size():
		var e: Dictionary = TalentsRules.normalize_effect(v, "%s.effects[%d]" % [ctx, i], raw_e[i])
		if not e.is_empty():
			effects.append(e)
	d["effects"] = effects
	d["for"] = PackedStringArray(["kai"])
	d["max_rank"] = 1
	d["weight"] = 1
	d["min_level"] = 1
	return d


static func _ids(v: DataValidator, ctx: String, entries: Array, kind: String, taken: Dictionary) -> void:
	var seen: Dictionary = {}
	for e: Variant in entries:
		var id: String = str((e as Dictionary).get("id", ""))
		if not v._matches(str(DataValidator.ID_PATTERNS[kind]), id):
			v._err("%s.%s" % [ctx, id], "invalid id (pattern %s)" % str(DataValidator.ID_PATTERNS[kind]))
		if seen.has(id) or taken.has(id):
			v._err("%s.%s" % [ctx, id], "duplicate id")
		seen[id] = true
