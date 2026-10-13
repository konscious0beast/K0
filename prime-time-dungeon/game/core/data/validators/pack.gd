extends RefCounted
## Private helper of DataValidator (02_TECH §0.3; 06 §8.0 Nr. 7 style — one file per rule set, no class_name): the pack
## rules of a content pack (11 §3.5 Nr. 4, 11-P1). DataValidator.validate runs them only with a provenance (a pack is
## mixed in, PackLoader.provenance) — base data never reach this file.
##   · Every text of the pack — pack.json → name and the text fields of its patches, new entries, sub-list entries and
##     top-level patches (name, desc, text, title, slogan, label, flavor; n / f / m below role and jobs) — against the
##     tone lists of data/mod_filter.json → blocked: politics, sexual, slurs, violence, real_brands, origin. Not
##     ip_distance (that list is ip_words' IP distance, 11 §3.12 layer 2), no language check. A RULE for every pack,
##     licensed ones included; a reviewed false alarm stands in pack.json → tone_exceptions {"ref":
##     "<table>:<id>.<field>", "list": "<category>", "reason": "…"} — never for politics or sexual (F-7).
##   · tone_exceptions name a text of the pack, a tone list and their review reason.
##   · A licence block names its credits (valid_until: a runtime warning, PackLoader.licence_notes; the export refuses
##     a past date, 11-PB).
##   · The PO rules of the pack's locale/<lang>.po (11-L1, validators/po.gd → check_pack_po): placeholders,
##     %-directives, "#. max N", digits, glyphs, the header (its Language names the file's language). The limits of the
##     base entries a pack PO overrides need the base POT files (not in an export): test_11_po_rules and
##     tools/i18n.sh check add them.

const OriginsCheck := preload("res://core/data/validators/origins.gd")
const PoRules := preload("res://core/data/validators/po.gd")
const FILTER_PATH: String = "res://data/mod_filter.json"
const TONE_LISTS: PackedStringArray = ["politics", "sexual", "slurs", "violence", "real_brands", "origin"]
const NO_EXCEPTION: PackedStringArray = ["politics", "sexual"]
const TEXT_KEYS: PackedStringArray = ["name", "desc", "text", "title", "slogan", "label", "flavor"]
## The forms of a job (origins.json: role and jobs[] → n / f / m) are texts too.
const FORM_KEYS: PackedStringArray = ["n", "f", "m"]
const FORM_PARENTS: PackedStringArray = ["role", "jobs"]

static var _blocked: Dictionary = {}


static func check(v: DataValidator, provenance: Dictionary) -> void:
	var pack: PackDef = provenance.get("def", null) as PackDef
	if pack == null:
		return
	var texts: Array[Dictionary] = pack_texts(pack)
	var refs: Dictionary = {}
	for t: Dictionary in texts:
		refs[str(t["ref"])] = true
	var allowed: Dictionary = _exceptions(v, pack, refs)
	for t: Dictionary in texts:
		var cat: String = tone_hit(str(t["text"]))
		if cat != "" and not allowed.has("%s|%s" % [str(t["ref"]), cat]):
			v._err("pack[%s].%s" % [pack.id, str(t["at"])], ("tone list '%s' (data/mod_filter.json → blocked, 11 §3.5 "
				+ "Nr. 4; a reviewed false alarm goes into pack.json → tone_exceptions as '%s')") % [cat, str(t["ref"])])
	if pack.has_licence():
		var credits: Variant = pack.licence.get("credits", [])
		if not (credits is Array) or (credits as Array).is_empty():
			v._err("pack[%s].licence.credits" % pack.id, "a licensed pack names its credits (11 §3.3, F-15)")
	_check_po(v, pack)                            # 11-L1: the PO rules of its locale/<lang>.po


## 11-L1 (11 §3.5 Nr. 4, §3.6): every locale/<lang>.po of the pack keeps the PO rules (validators/po.gd).
static func _check_po(v: DataValidator, pack: PackDef) -> void:
	for f: String in pack.files:
		if not f.begins_with("locale/") or f.get_extension() != "po":
			continue
		var res: Dictionary = PoRules.check_pack_po(FileAccess.get_file_as_string(pack.root.path_join(f)), f,
			f.get_file().get_basename(), {})
		for e: String in res["errors"]:
			v._err("pack[%s]" % pack.id, e)


## Every text of the pack: [{"ref": "<table>:<id>.<field>" (tone_exceptions), "at": "<table>[<id>].<field>" (errors),
## "text"}], pack.json → name first ("pack:name"), then the overlays in table order (sub lists as "<table>.<list>").
static func pack_texts(pack: PackDef) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if pack.name != "":
		out.append({"ref": "pack:name", "at": "pack.json.name", "text": pack.name})
	var tables: Array = pack.overlays.keys()
	tables.sort()
	for tv: Variant in tables:
		var t: String = str(tv)
		if t == PackLoader.RT_BALANCE:
			continue
		var ov: Dictionary = pack.overlays[tv]
		_op_texts(out, t, ov)
		var sub: Dictionary = ov.get("sub", {}) if ov.get("sub", {}) is Dictionary else {}
		var lists: Array = sub.keys()
		lists.sort()
		for lv: Variant in lists:
			_op_texts(out, "%s.%s" % [t, str(lv)], sub[lv] as Dictionary)
		var top: Dictionary = ov.get("top", {}) if ov.get("top", {}) is Dictionary else {}
		var keys: Array = top.keys()
		keys.sort()
		for k: Variant in keys:
			_walk(out, t, str(k), "", top[k], "")
	return out


## The first tone list of `text` ("" = none); same word semantics as the live filter and validators/origins.gd.
static func tone_hit(text: String) -> String:
	if _blocked.is_empty():
		var raw: Variant = JsonUtil.read_file(FILTER_PATH)
		_blocked = (raw as Dictionary).get("blocked", {}) if raw is Dictionary else {}
		if _blocked.is_empty():
			_blocked = {"_": []}
	var tokens: PackedStringArray = OriginsCheck.words(text)
	var parts: PackedStringArray = tokens.duplicate()
	for tok: String in tokens:
		if tok.contains("-"):
			parts.append_array(tok.split("-", false))
	var joined: String = " " + " ".join(tokens) + " "
	for cat: String in TONE_LISTS:
		var list: Variant = _blocked.get(cat, [])
		for entry: Variant in (list as Array if list is Array else []):
			var w: String = str(entry).to_lower()
			if (w.contains(" ") and joined.contains(" " + w + " ")) or (not w.contains(" ")
					and OriginsCheck.word_hit(parts, w)):
				return cat
	return ""


static func _op_texts(out: Array[Dictionary], table: String, ops: Dictionary) -> void:
	var patch: Dictionary = ops.get("patch", {}) if ops.get("patch", {}) is Dictionary else {}
	var ids: Array = patch.keys()
	ids.sort()
	for id: Variant in ids:
		_walk(out, table, str(id), "", patch[id], "")
	var add: Array = ops.get("add", []) if ops.get("add", []) is Array else []
	for e: Variant in add:
		if e is Dictionary:
			_walk(out, table, str((e as Dictionary).get("id", "")), "", e, "")


static func _walk(out: Array[Dictionary], table: String, id: String, path: String, node: Variant,
		parent: String) -> void:
	if node is Dictionary:
		var d: Dictionary = node
		var keys: Array = d.keys()
		keys.sort()
		for k: Variant in keys:
			var key: String = str(k)
			var p: String = key if path == "" else path + "." + key
			var val: Variant = d[k]
			if val is String and (TEXT_KEYS.has(key) or (FORM_KEYS.has(key) and FORM_PARENTS.has(parent))):
				out.append({"ref": "%s:%s.%s" % [table, id, p], "at": "%s[%s].%s" % [table, id, p], "text": val})
			elif val is Dictionary or val is Array:
				_walk(out, table, id, p, val, key)
	elif node is Array:
		var a: Array = node
		for i in a.size():
			_walk(out, table, id, "%s[%d]" % [path, i], a[i], parent)


## "<ref>|<list>" → true for every well-formed exception; errors for the others.
static func _exceptions(v: DataValidator, pack: PackDef, refs: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for i in pack.tone_exceptions.size():
		var e: Dictionary = pack.tone_exceptions[i]
		var at: String = "pack[%s].tone_exceptions[%d]" % [pack.id, i]
		var list: String = str(e.get("list", ""))
		if not TONE_LISTS.has(list):
			v._err(at + ".list", "'%s' is no tone list (%s)" % [list, ", ".join(TONE_LISTS)])
		elif NO_EXCEPTION.has(list):
			v._err(at + ".list", "'%s' never has an exception (F-7)" % list)
		elif str(e.get("reason", "")).strip_edges() == "":
			v._err(at + ".reason", "every exception names its review (11 §3.3)")
		elif not refs.has(str(e.get("ref", ""))):
			v._err(at + ".ref", "'%s' is no text of this pack (<table>:<id>.<field>)" % str(e.get("ref", "")))
		else:
			out["%s|%s" % [str(e["ref"]), list]] = true
	return out
