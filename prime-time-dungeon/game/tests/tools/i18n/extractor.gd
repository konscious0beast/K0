extends RefCounted
## The msgid extractor (11 §1.11, SP-8): three sources, each with its place in the game —
##  1. code: literals in Tx.t / Tx.n / Tx.m and — while L2 moves the code — tr, atr, tr_n, tr_text and
##     TranslationServer.translate under res://scenes, autoload, core and art (not art/gallery: developer galleries);
##     a call whose text is not a literal is reported as "dynamisch" (the data are its source);
##  2. scenes: the text properties of every .tscn / .tres (the list of test_09_terms; empty today);
##  3. data: the player-facing fields of 11 §1.4 per table, read from the JSON files (the authored msgids; the
##     normalisation adds no text defaults), with the table as msgctxt (SP-2: "<table>.<sublist>" for sublists,
##     "<table>:<id>" for the homonyms of locale/contexts.json) and the length limit of the field's validator.
## Domains (11 §1.2): ui (code and scenes), data (data/*.json without the spoken lines), mod_lines (mod_lines.json and
## scenes.json) and stempel (data/stempel/*.json, scenes/stempel/**, core/stempel/**). Output is stable: entries in the
## order of their first place (file, then position), no timestamps — a POT changes only when a text changes.

const GdLiterals := preload("res://tests/tools/i18n/gd_literals.gd")
const VOrigins := preload("res://core/data/validators/origins.gd")
const VTalents := preload("res://core/data/validators/talents.gd")
const VSpecies := preload("res://core/data/validators/species.gd")
const VMarotten := preload("res://core/data/validators/marotten.gd")
const VTwists := preload("res://core/data/validators/twists.gd")
const VLooks := preload("res://core/data/validators/looks.gd")
const VCast := preload("res://core/data/validators/cast.gd")
const VThemes := preload("res://core/data/validators/themes.gd")
const VStempel := preload("res://core/stempel/validators/sd_validator.gd")

const DOMAINS: PackedStringArray = ["ui", "data", "mod_lines", "stempel"]
const CODE_ROOTS: PackedStringArray = ["res://scenes", "res://autoload", "res://core", "res://art"]
const SKIP_CODE: PackedStringArray = ["res://art/gallery/"]
const STEMPEL_CODE: PackedStringArray = ["res://scenes/stempel/", "res://core/stempel/"]
const SCENE_ROOTS: PackedStringArray = ["res://scenes", "res://art"]
## = test_09_terms.SCENE_TEXT_PROPS.
const SCENE_TEXT_PROPS: PackedStringArray = ["text", "tooltip_text", "placeholder_text", "title", "dialog_text"]
## Call heads → kind: t (msgid [, ctx]), n (msgid, plural, count [, ctx]), m (marker: msgid).
const CALLS: Dictionary = {"Tx.t(": "t", "Tx.n(": "n", "Tx.m(": "m", "tr(": "t", "atr(": "t", "tr_n(": "n",
	"atr_n(": "n", "tr_text(": "t", "TranslationServer.translate(": "t", "TranslationServer.translate_plural(": "n"}
const MAX_SPOKEN: int = 110                       # DataValidator.MAX_TEXT_LEN (GDD §11.1: two HUD lines)
## Kap. 1.4: per data file [list, path in an element, limit, ctx] — list "" = the file's "entries"; path "a.b" into
## objects, "a[]" through lists; limit 0 = none, -1 = not longer than the German (skill names in the combat bar);
## ctx "" = the table (SP-2).
const DATA_FIELDS: Dictionary = {
	"statuses": [["", "name", 0, ""]],
	"skills": [["", "name", -1, ""], ["", "desc", 0, ""]],
	"items": [["", "name", 0, ""], ["", "desc", 0, ""]],
	"classes": [["", "name", 0, ""], ["", "desc", 0, ""]],
	"party": [["", "name", 0, ""], ["", "title", 0, ""]],
	"enemies": [["", "name", 0, ""], ["pseudo_units", "name", 0, "enemies.pseudo_units"]],
	"floors": [["", "name", 0, ""], ["", "zones[].name", 0, ""], ["", "zones[].safe.name", 0, ""],
		["", "layout.zones[].name", 0, ""], ["", "layout.safe_rooms[].name", 0, ""], ["", "quest.label", 0, ""]],
	"lootboxes": [["", "name", 0, ""]],
	"achievements": [["", "name", 0, ""], ["", "desc", 0, ""]],
	"sponsors": [["", "name", 0, ""], ["", "slogan", 0, ""]],
	"milestones": [["", "title", 0, ""]],
	"talents": [["", "name", "talents.NAME_MAX", ""], ["", "desc", "talents.DESC_MAX", ""]],
	"species": [["", "name", "species.NAME_MAX", ""], ["", "desc", "species.DESC_MAX", ""]],
	"marotten": [["", "name", "marotten.MAX_NAME", ""], ["", "desc", "marotten.MAX_DESC", ""]],
	"twists": [["", "name", "twists.MAX_NAME", ""], ["", "desc", "twists.MAX_DESC", ""]],
	"origins": [["", "name", "origins.NAME_MAX", ""], ["", "role.n", "origins.FORM_MAX", ""],
		["", "role.f", "origins.FORM_MAX", ""], ["", "role.m", "origins.FORM_MAX", ""],
		["", "jobs[].n", "origins.FORM_MAX", ""], ["", "jobs[].f", "origins.FORM_MAX", ""],
		["", "jobs[].m", "origins.FORM_MAX", ""], ["", "flavor", "origins.FLAVOR_MAX", ""],
		["hobbies", "name", "origins.NAME_MAX", "origins.hobbies"],
		["hobbies", "club.text", "origins.FORM_MAX", "origins.hobbies"],
		["traits", "name", "origins.TRAIT_MAX", "origins.traits"],
		["rivals", "name", "origins.LABEL_MAX", "origins.rivals"],
		["brands", "name", "origins.LABEL_MAX", "origins.brands"],
		["gags", "name", "origins.LABEL_MAX", "origins.gags"]],
	"looks": [["", "name", "looks.NAME_MAX", ""]],
	"seasons": [["", "name", 0, ""]],
	"professions": [["", "name", 0, ""], ["recipes", "name", 0, "professions.recipes"],
		["materials", "name", 0, "professions.materials"], ["nodes", "name", 0, "professions.nodes"]],
	"cast": [["", "name", "cast.NAME_MAX", ""]],
	"themes": [["", "name", "themes.NAME_MAX", ""], ["", "program[].name", "themes.NAME_MAX", ""]],
}
## Domain mod_lines (11 §1.4): the spoken lines.
const SPOKEN_FIELDS: Dictionary = {
	"mod_lines": [["", "text", MAX_SPOKEN, ""]],
	"scenes": [["", "name", 0, ""], ["", "lines[].text", MAX_SPOKEN, ""]],
}
## Domain stempel: data/stempel/<file>.json (ctx "stempel.<file>"; rules.json: the display texts of its objects).
const STEMPEL_FIELDS: Dictionary = {
	"awards": [["", "name", 0, ""], ["", "desc", "stempel.MAX_TEXT", ""]],
	"cards": [["", "name", "stempel.MAX_CARD_NAME", ""], ["", "text", "stempel.MAX_TEXT", ""],
		["", "quip", "stempel.MAX_TEXT", ""]],
	"cosmetics": [["", "name", 0, ""], ["", "desc", "stempel.MAX_TEXT", ""]],
	"lines": [["", "text", "stempel.MAX_TEXT", ""]],
	"opponents": [["", "name", "stempel.MAX_TEXT", ""], ["", "short", "stempel.MAX_SHORT", ""],
		["", "role", "stempel.MAX_TEXT", ""], ["", "akte", "stempel.MAX_TEXT", ""], ["", "rule", "stempel.MAX_TEXT", ""]],
	"rules": [["statuses", "name", "stempel.MAX_TEXT", ""], ["statuses", "text", "stempel.MAX_TEXT", ""],
		["durchsage", "name", "stempel.MAX_TEXT", ""], ["durchsage", "short", 0, ""],
		["durchsage", "text", "stempel.MAX_TEXT", ""]],
}
## Example values of placeholders for the translators (11 §1.5: "#. {cand} = Kandidatin|Kandidat|Kandidat:in").
const PLACEHOLDER_HINTS: Dictionary = {
	"cand": "Kandidatin|Kandidat|Kandidat:in (English: contestant — may be left out, 11 §1.6)",
	"job": "a job in the word form, e.g. Tierpfleger:in", "hobby": "a hobby, e.g. Kochen & Backen",
	"club": "„Ihr“/„Ihre“ + the club, e.g. Ihr Kochkurs", "trait": "a trait, e.g. pragmatisch",
	"rival": "a rival's name", "brand": "a brand name", "job_text": "the candidate's own job text",
	"name": "the candidate's name, e.g. Kai", "floor": "a floor number, e.g. 3", "level": "a level, e.g. 12",
	"viewers": "a formatted number, e.g. 12.345", "followers": "a formatted number, e.g. 1.240",
	"count": "a number", "member": "a party member, e.g. Graf Mopsula", "enemy": "an enemy name",
	"item": "an item name", "achievement": "an achievement name", "sponsor": "a sponsor name",
	"seconds": "a number of seconds", "amount": "a number", "pct": "a percentage", "min": "a number of minutes",
	"sender": "a viewer's name",
}

var dynamic: PackedStringArray = []        # "file:line: head …" calls without a literal text (report)
var errors: PackedStringArray = []

var _entries: Dictionary = {}               # domain → {key → entry}
var _order: Dictionary = {}                 # domain → [key] in order of the first place
var _limits: Dictionary = {}


func _init() -> void:
	for d: String in DOMAINS:
		_entries[d] = {}
		_order[d] = []
	_limits = {"talents": VTalents, "species": VSpecies, "marotten": VMarotten, "twists": VTwists,
		"origins": VOrigins, "looks": VLooks, "cast": VCast, "themes": VThemes, "stempel": VStempel}


## Runs all three sources. Returns {domain → [entry]}; entry = {"ctx", "id", "plural", "refs": PackedStringArray,
## "notes": PackedStringArray (#. lines), "flags": PackedStringArray}.
func extract() -> Dictionary:
	for root: String in CODE_ROOTS:
		for path: String in files_under(root, ".gd"):
			if _skipped(path):
				continue
			extract_code(path, FileAccess.get_file_as_string(path))
	for root: String in SCENE_ROOTS:
		for ext: String in [".tscn", ".tres"]:
			for path: String in files_under(root, ext):
				if not _skipped(path):
					extract_scene(path, FileAccess.get_file_as_string(path))
	for table: String in _sorted_keys(DATA_FIELDS):
		_extract_data("data", "res://data/%s.json" % table, table, DATA_FIELDS[table])
	for table: String in _sorted_keys(SPOKEN_FIELDS):
		_extract_data("mod_lines", "res://data/%s.json" % table, table, SPOKEN_FIELDS[table])
	for file: String in _sorted_keys(STEMPEL_FIELDS):
		_extract_data("stempel", "res://data/stempel/%s.json" % file, "stempel." + file, STEMPEL_FIELDS[file])
	return entries()


func entries() -> Dictionary:
	var out: Dictionary = {}
	for d: String in DOMAINS:
		var list: Array[Dictionary] = []
		for key: String in _order[d]:
			list.append(_entries[d][key])
		out[d] = list
	return out


# --- code -------------------------------------------------------------------------------------------------------------

func extract_code(path: String, source: String) -> void:
	var has_call: bool = false
	for head: String in CALLS:
		if source.contains(head):
			has_call = true
			break
	if not has_call:
		return
	var domain: String = _code_domain(path)
	var rel: String = path.trim_prefix("res://")
	var sc: Dictionary = GdLiterals.scan(source)
	var lits: Array[Dictionary] = sc["lits"]
	var code: PackedStringArray = sc["code"]
	for i in code.size():
		_report_dynamic(rel, code[i], lits[i - 1] if i > 0 else {}, i < lits.size())
	var i: int = 0
	while i < lits.size():
		var kind: String = call_kind(code[i])
		if kind == "":
			i += 1
			continue
		var lit: Dictionary = lits[i]
		var after: String = code[i + 1].strip_edges(true, false)
		var ref: String = "%s:%d" % [rel, int(lit["line"])]
		if kind == "n":
			if not after.begins_with(",") or i + 1 >= lits.size() or code[i + 1].strip_edges() != ",":
				dynamic.append("%s: plural without a literal msgid_plural" % ref)
				i += 1
				continue
			var plural: String = str(lits[i + 1]["text"])
			var rest: String = code[i + 2].strip_edges()
			var ctx: String = ""
			var used: int = 2
			if rest.ends_with(",") and i + 2 < lits.size() and code[i + 3].strip_edges(true, false).begins_with(")"):
				ctx = str(lits[i + 2]["text"])
				used = 3
			_add(domain, ctx, str(lit["text"]), plural, ref, PackedStringArray(), _format_flag(code[i + used]))
			i += used
			continue
		if after.begins_with(")"):
			_add(domain, "", str(lit["text"]), "", ref, PackedStringArray(), _format_flag(after))
			i += 1
			continue
		if after.begins_with(",") and kind == "t" and i + 1 < lits.size() and code[i + 1].strip_edges() == "," \
				and code[i + 2].strip_edges(true, false).begins_with(")"):
			_add(domain, str(lits[i + 1]["text"]), str(lit["text"]), "", ref, PackedStringArray(),
				_format_flag(code[i + 2].strip_edges(true, false)))
			i += 2
			continue
		dynamic.append("%s: the text is not one literal (%s\"%s\"%s)" % [ref, code[i].strip_edges().right(24),
			str(lit["raw"]).left(40), after.left(12)])
		i += 1


## The kind of the call whose first argument follows `code_before` ("" = not a translation call).
static func call_kind(code_before: String) -> String:
	var s: String = code_before.strip_edges(false, true)
	for head: String in CALLS:
		if s.ends_with(head) and _boundary(s, s.length() - head.length(), head):
			return str(CALLS[head])
	return ""


## Translation calls in a code segment whose first argument is no literal ("dynamisch").
func _report_dynamic(rel: String, segment: String, lit_before: Dictionary, lit_follows: bool) -> void:
	for head: String in CALLS:
		var p: int = segment.find(head)
		while p >= 0:
			var at_end: bool = segment.substr(p + head.length()).strip_edges() == "" and lit_follows
			if _boundary(segment, p, head) and not at_end and not segment.substr(maxi(0, p - 5), 5).ends_with("func "):
				var line: int = int(lit_before.get("line", 1)) + segment.substr(0, p).count("\n")
				var arg: String = segment.substr(p + head.length()).strip_edges().get_slice("\n", 0).left(40)
				dynamic.append("%s:%d: dynamisch %s%s" % [rel, line, head, arg])
			p = segment.find(head, p + head.length())


## The character before `at` does not continue an identifier; a method head (tr(, tr_text( …) may follow a "."
## (node.tr, UiUtil.tr_text), a qualified one (Tx.t(, TranslationServer.translate() may not.
static func _boundary(s: String, at: int, head: String) -> bool:
	if at <= 0:
		return true
	var c: String = s[at - 1]
	if GdLiterals.IDENT.contains(c):
		return false
	return c != "." or not head.contains(".")


## "c-format" when the text is used with the % operator after the call (GDScript's C-like format; msgfmt
## --check-format then compares the directives of msgid and msgstr). `rest` = the code after the call's literals.
static func _format_flag(rest: String) -> PackedStringArray:
	var depth: int = 0
	for i in rest.length():
		var c: String = rest[i]
		if c == "(":
			depth += 1
		elif c == ")":
			if depth == 0:
				var tail: String = rest.substr(i + 1).strip_edges(true, false)
				return PackedStringArray(["c-format"]) if tail.begins_with("%") else PackedStringArray()
			depth -= 1
	return PackedStringArray()


func _code_domain(path: String) -> String:
	for p: String in STEMPEL_CODE:
		if path.begins_with(p):
			return "stempel"
	return "ui"


func _skipped(path: String) -> bool:
	for p: String in SKIP_CODE:
		if path.begins_with(p):
			return true
	return false


# --- scenes ----------------------------------------------------------------------------------------------------------

func extract_scene(path: String, source: String) -> void:
	var lines: PackedStringArray = source.split("\n")
	var rel: String = path.trim_prefix("res://")
	for n in lines.size():
		for prop: String in SCENE_TEXT_PROPS:
			if not lines[n].begins_with(prop + " = \""):
				continue
			var value: String = lines[n].substr(prop.length() + 4)
			var k: int = n
			while not _closed(value) and k + 1 < lines.size():
				k += 1
				value += "\n" + lines[k]
			var text: String = GdLiterals.unescape(value.substr(0, value.length() - 1))
			if text.strip_edges() != "":
				_add(_code_domain(path), "", text, "", "%s:%d" % [rel, n + 1], PackedStringArray(), PackedStringArray())


static func _closed(value: String) -> bool:
	if not value.ends_with("\""):
		return false
	var slashes: int = 0
	var i: int = value.length() - 2
	while i >= 0 and value[i] == "\\":
		slashes += 1
		i -= 1
	return slashes % 2 == 0


# --- data -------------------------------------------------------------------------------------------------------------

func _extract_data(domain: String, path: String, table: String, specs: Array) -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) \
		else null
	if not parsed is Dictionary:
		errors.append("%s: missing or not a JSON object" % path)
		return
	var rel: String = path.trim_prefix("res://")
	var lists: PackedStringArray = []            # the lists in the order of their first spec
	for spec: Array in specs:
		var lk: String = str(spec[0]) if str(spec[0]) != "" else "entries"
		if not lists.has(lk):
			lists.append(lk)
	for list_key: String in lists:
		var holder: Variant = (parsed as Dictionary).get(list_key, null)
		var elements: Array = holder if holder is Array else ([holder] if holder is Dictionary else [])
		for idx in elements.size():
			var el: Variant = elements[idx]
			if not el is Dictionary:
				continue
			var id: String = str((el as Dictionary).get("id", "%s[%d]" % [list_key, idx]))
			for spec: Array in specs:
				if (str(spec[0]) if str(spec[0]) != "" else "entries") != list_key:
					continue
				var ctx_table: String = str(spec[3]) if str(spec[3]) != "" else table
				for hit: Array in _walk(el, str(spec[1]).split("."), ""):
					var text: String = str(hit[1])
					if text.strip_edges() == "":
						continue
					var notes: PackedStringArray = _data_notes(table, str(hit[0]), text, spec[2], el as Dictionary)
					_add(domain, Tx.data_ctx(ctx_table, id), text, "", "%s:%s.%s" % [rel, id, str(hit[0])], notes,
						PackedStringArray())


## [[path, value]] of the string values at `parts` below `v` (a[] walks a list; ids name the list elements).
func _walk(v: Variant, parts: PackedStringArray, at: String) -> Array:
	if parts.is_empty():
		return [[at, v]] if v is String else []
	var head: String = parts[0]
	var rest: PackedStringArray = parts.slice(1)
	var out: Array = []
	if head.ends_with("[]"):
		var key: String = head.trim_suffix("[]")
		var list: Variant = (v as Dictionary).get(key, []) if v is Dictionary else []
		if list is Array:
			for i in (list as Array).size():
				var el: Variant = (list as Array)[i]
				var tag: String = str((el as Dictionary).get("id", i)) if el is Dictionary else str(i)
				out.append_array(_walk(el, rest, _join(at, "%s[%s]" % [key, tag])))
	elif v is Dictionary and (v as Dictionary).has(head):
		out.append_array(_walk((v as Dictionary)[head], rest, _join(at, head)))
	return out


static func _join(at: String, part: String) -> String:
	return part if at == "" else at + "." + part


func _data_notes(table: String, field: String, text: String, limit: Variant, el: Dictionary) -> PackedStringArray:
	var notes: PackedStringArray = []
	var n: int = _limit_of(limit, text)
	if n > 0:
		notes.append("max %d" % n)
	if table == "mod_lines":
		notes.append("tag %s, voice %s" % [str(el.get("tag", "")), str(el.get("voice", "mod"))])
	elif table == "stempel.lines":
		notes.append("tag %s, voice %s" % [str(el.get("tag", "")), str(el.get("voice", "mod"))])
	elif table == "scenes" and field.begins_with("lines["):
		notes.append("voice %s" % _scene_voice(el, field))
	if table == "origins" and (field.ends_with(".f") or field.ends_with(".m")):
		notes.append("same as the n form in English (one neutral job title, 11 §1.6)")
	return notes


func _scene_voice(el: Dictionary, field: String) -> String:
	var lines: Array = el.get("lines", [])
	var idx: int = int(field.get_slice("[", 1).get_slice("]", 0))
	return str((lines[idx] as Dictionary).get("voice", "")) if idx < lines.size() and lines[idx] is Dictionary else ""


## A field's limit: an int, -1 = the German length, "<validator>.<CONST>" = that validator constant.
func _limit_of(limit: Variant, text: String) -> int:
	if limit is int or limit is float:
		return text.length() if int(limit) < 0 else int(limit)
	var s: String = str(limit)
	var script: Variant = _limits.get(s.get_slice(".", 0), null)
	if script is GDScript:
		return int((script as GDScript).get_script_constant_map().get(s.get_slice(".", 1), 0))
	errors.append("unknown limit %s" % s)
	return 0


# --- entries ----------------------------------------------------------------------------------------------------------

func _add(domain: String, ctx: String, id: String, plural: String, ref: String, notes: PackedStringArray,
		flags: PackedStringArray) -> void:
	var key: String = ctx + Tx.CTX_SEP + id
	var map: Dictionary = _entries[domain]
	if not map.has(key):
		map[key] = {"ctx": ctx, "id": id, "plural": plural, "refs": PackedStringArray(), "notes": PackedStringArray(),
			"flags": PackedStringArray()}
		(_order[domain] as Array).append(key)
	var e: Dictionary = map[key]
	if plural != "" and str(e["plural"]) == "":
		e["plural"] = plural
	var refs: PackedStringArray = e["refs"]
	refs.append(ref)
	e["refs"] = refs
	for note: String in notes:
		_merge_note(e, note)
	var have: PackedStringArray = e["flags"]
	for f: String in flags:
		if not have.has(f):
			have.append(f)
	e["flags"] = have
	for ph: String in placeholders(id):
		if PLACEHOLDER_HINTS.has(ph):
			_merge_note(e, "{%s} = %s" % [ph, str(PLACEHOLDER_HINTS[ph])])


## Notes stay unique; of two "max N" the smaller wins (one msgid, several fields).
static func _merge_note(e: Dictionary, note: String) -> void:
	var notes: PackedStringArray = e["notes"]
	if notes.has(note):
		return
	if note.begins_with("max "):
		for i in notes.size():
			if notes[i].begins_with("max "):
				if int(note.substr(4)) < int(notes[i].substr(4)):
					notes[i] = note
				e["notes"] = notes
				return
	notes.append(note)
	e["notes"] = notes


## The {name} placeholders of a text, in order, each once.
static func placeholders(text: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var i: int = text.find("{")
	while i >= 0:
		var j: int = text.find("}", i + 1)
		if j < 0:
			break
		var name: String = text.substr(i + 1, j - i - 1)
		if name.is_valid_ascii_identifier() and not out.has(name):
			out.append(name)
		i = text.find("{", j + 1)
	return out


# --- POT --------------------------------------------------------------------------------------------------------------

## The POT text of a domain (gettext layout: #. notes, #: places, #, flags, msgctxt, msgid, msgid_plural, msgstr).
static func pot_text(domain: String, list: Array) -> String:
	var out: PackedStringArray = [
		"# PRIME TIME DUNGEON — the msgid template of the domain \"%s\" (11 §1.2, §1.11). msgid = the German" % domain,
		"# source text. Written by tools/i18n.sh extract — never edit by hand.",
		"msgid \"\"",
		"msgstr \"\"",
		"\"Project-Id-Version: PRIME TIME DUNGEON\\n\"",
		"\"Report-Msgid-Bugs-To: \\n\"",
		"\"Language: \\n\"",
		"\"MIME-Version: 1.0\\n\"",
		"\"Content-Type: text/plain; charset=UTF-8\\n\"",
		"\"Content-Transfer-Encoding: 8bit\\n\"",
		"\"Plural-Forms: nplurals=2; plural=(n != 1);\\n\"",
		"\"X-Domain: %s\\n\"" % domain,
		"",
	]
	for e: Dictionary in list:
		for note: String in e["notes"]:
			out.append("#. " + note)
		for ref: String in e["refs"]:
			out.append("#: " + ref)
		var flags: PackedStringArray = e["flags"]
		if not flags.is_empty():
			out.append("#, " + ", ".join(flags))
		if str(e["ctx"]) != "":
			out.append(LocaleLoader.po_field("msgctxt", str(e["ctx"])))
		out.append(LocaleLoader.po_field("msgid", str(e["id"])))
		if str(e["plural"]) != "":
			out.append(LocaleLoader.po_field("msgid_plural", str(e["plural"])))
			out.append("msgstr[0] \"\"")
			out.append("msgstr[1] \"\"")
		else:
			out.append("msgstr \"\"")
		out.append("")
	return "\n".join(out)


# --- files ------------------------------------------------------------------------------------------------------------

static func files_under(root: String, ext: String) -> PackedStringArray:
	var out: PackedStringArray = []
	_collect(root, ext, out)
	out.sort()
	return out


static func _collect(dir_path: String, ext: String, out: PackedStringArray) -> void:
	var d: DirAccess = DirAccess.open(dir_path)
	if d == null:
		return
	for sub: String in d.get_directories():
		if not sub.begins_with("."):
			_collect(dir_path.path_join(sub), ext, out)
	for f: String in d.get_files():
		if f.ends_with(ext):
			out.append(dir_path.path_join(f))


static func _sorted_keys(d: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	for k: Variant in d.keys():
		out.append(str(k))
	out.sort()
	return out
