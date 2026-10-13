extends RefCounted
## Private helper of DataValidator (02_TECH §0.3; no class_name, preloaded as PoRules): the rules of a translation
## (11 §1.5, §1.8, §1.12), per translated, non-fuzzy entry of a PO file:
##  - placeholders: the {…} of msgstr are a subset of the msgid's (SP-9: English may drop {cand}, never invent one);
##  - c-format entries (used with %): the same %-directives in the same order (what msgfmt --check-format checks);
##  - length: "#. max N" of the extractor (the field's validator limit; persona placeholders count with their longest
##    value, PersonaText.effective_length, 08 §4.4);
##  - digits: the same digit runs as the msgid (a balance change in the data changes the msgid → the entry turns
##    fuzzy, the number cannot go stale; a translator comment "# digits-ok: <reason>" allows an exception);
##  - glyphs: nothing the default font lacks (like UiUtil.missing_glyphs, 03_ART F8);
##  - a warning (no error): "{count}" right before a word in a data text — data have no plural forms (F-16).
## The header needs Language, Plural-Forms and UTF-8. Users: validators/pack.gd (a content pack's locale/<lang>.po
## when the pack loads, 11 §3.5 Nr. 4: check_pack_po — its Language header names the file's language), test_11_po_rules
## and tools/i18n.sh check (the base PO; for pack PO also the limits of the base entries they override, base_limits).

const DIGITS_OK: String = "digits-ok:"

static var _re_digits: RegEx = null
static var _re_directive: RegEx = null
static var _re_count_word: RegEx = null


## {"errors": PackedStringArray, "warnings": PackedStringArray, "counts": {"total", "translated", "fuzzy", "empty"}};
## `limits` ("<ctx>\u0004<msgid>" → N, base_limits) for entries without their own "#. max N".
static func check_text(text: String, source: String, limits: Dictionary = {}) -> Dictionary:
	var po: Dictionary = PoFile.parse(text, source, true)
	var errors: PackedStringArray = (po["errors"] as PackedStringArray).duplicate()
	var warnings: PackedStringArray = []
	var header: Dictionary = po["header"]
	if str(header.get("Language", "")) == "":
		errors.append("%s: header without Language" % source)
	if not str(header.get("Content-Type", "")).to_lower().contains("charset=utf-8"):
		errors.append("%s: header without charset=UTF-8" % source)
	if not str(header.get("Plural-Forms", "")).begins_with("nplurals=2;"):
		errors.append("%s: Plural-Forms must be nplurals=2 (one_other, Tx.PLURAL_RULES)" % source)
	var counts: Dictionary = {"total": 0, "translated": 0, "fuzzy": 0, "empty": 0}
	for e: Dictionary in po["entries"]:
		counts["total"] = int(counts["total"]) + 1
		var forms: PackedStringArray = e["str"]
		var translated: bool = false
		for f: String in forms:
			translated = translated or f != ""
		if bool(e["fuzzy"]):
			counts["fuzzy"] = int(counts["fuzzy"]) + 1
			continue
		if not translated:
			counts["empty"] = int(counts["empty"]) + 1
			continue
		counts["translated"] = int(counts["translated"]) + 1
		var where: String = "%s:%d (%s)" % [source, int(e["line"]), str(e["id"]).left(48)]
		for i in forms.size():
			if forms[i] == "":
				continue
			var msgid: String = str(e["plural"]) if i > 0 and str(e["plural"]) != "" else str(e["id"])
			errors.append_array(entry_errors(msgid, forms[i], e, where,
				int(limits.get(str(e["ctx"]) + Tx.CTX_SEP + str(e["id"]), 0))))
			var w: String = count_warning(forms[i], str(e["ctx"]))
			if w != "":
				warnings.append("%s: %s" % [where, w])
	return {"errors": errors, "warnings": warnings, "counts": counts}


## The rule errors of one msgstr against its msgid ("" ctx = code text); `fallback_limit` when the entry has no
## "#. max N" of its own.
static func entry_errors(msgid: String, msgstr: String, e: Dictionary, where: String,
		fallback_limit: int = 0) -> PackedStringArray:
	var out: PackedStringArray = []
	for ph: String in placeholders(msgstr):
		if not placeholders(msgid).has(ph):
			out.append("%s: {%s} is not in the msgid (SP-9: a subset only)" % [where, ph])
	if (e.get("flags", PackedStringArray()) as PackedStringArray).has("c-format") \
			and directives(msgid) != directives(msgstr):
		out.append("%s: %%-directives %s, the msgid has %s" % [where, str(directives(msgstr)),
			str(directives(msgid))])
	var limit: int = max_of(e) if max_of(e) > 0 else fallback_limit
	if limit > 0:
		var ok_msgid: bool = PersonaText.effective_length(msgid) <= limit
		var len_str: int = PersonaText.effective_length(msgstr) if ok_msgid else msgstr.length()
		if len_str > limit:
			out.append("%s: %d characters, the field allows %d" % [where, len_str, limit])
	if digits(msgid) != digits(msgstr) and not _digits_ok(e):
		out.append("%s: digits %s, the msgid has %s" % [where, str(digits(msgstr)), str(digits(msgid))])
	var missing: String = missing_glyphs(msgstr)
	if missing != "":
		out.append("%s: glyphs the font lacks: %s" % [where, missing])
	return out


## "{count}" right before a word in a data text (a msgctxt: data or spoken lines) — "" if fine.
static func count_warning(text: String, ctx: String) -> String:
	if ctx == "" or not text.contains("{count}"):
		return ""
	if _re_count_word == null:
		_re_count_word = RegEx.create_from_string("\\{count\\}\\s+\\p{L}")
	return "{count} before a word: data texts have no plural forms — write them number-neutral (F-16)" \
		if _re_count_word.search(text) != null else ""


## The length limits of the base POT files ("<ctx>\u0004<msgid>" → N): a pack PO's override of a base entry keeps the
## limit of the field it replaces, with or without its own "#. max N".
static func base_limits(pot_dir: String = "res://locale/pot") -> Dictionary:
	var out: Dictionary = {}
	for d: String in LocaleLoader.DOMAINS:
		var path: String = pot_dir.path_join(d + ".pot")
		if not FileAccess.file_exists(path):
			continue
		for e: Dictionary in PoFile.parse(FileAccess.get_file_as_string(path), path, true)["entries"]:
			var n: int = max_of(e)
			if n > 0:
				out[str(e["ctx"]) + Tx.CTX_SEP + str(e["id"])] = n
	return out


## The PO files of the content packs: <packs root>/<id>/locale/*.po, sorted.
static func pack_po_files(packs_root: String = "res://packs") -> PackedStringArray:
	var out: PackedStringArray = []
	for id: String in DirAccess.get_directories_at(packs_root):
		var dir: String = packs_root.path_join(id).path_join("locale")
		for f: String in DirAccess.get_files_at(dir):
			if f.get_extension() == "po":
				out.append(dir.path_join(f))
	out.sort()
	return out


## check_text for a pack's locale/<lang>.po: the base limits for its overrides, and its Language header must be `lang`.
static func check_pack_po(text: String, source: String, lang: String, limits: Dictionary) -> Dictionary:
	var res: Dictionary = check_text(text, source, limits)
	var header_lang: String = str((PoFile.parse(text, source)["header"] as Dictionary).get("Language", ""))
	if header_lang != lang:
		var errors: PackedStringArray = res["errors"]   # a packed array is a value: append, then store it back
		errors.append("%s: header Language '%s', the file is locale/%s.po" % [source, header_lang, lang])
		res["errors"] = errors
	return res


## The characters of `text` the default font lacks (= UiUtil.missing_glyphs; core/ cannot preload scenes/).
static func missing_glyphs(text: String) -> String:
	var font: Font = ThemeDB.fallback_font
	var out: String = ""
	if font == null:
		return out
	for i in text.length():
		var c: int = text.unicode_at(i)
		if c >= 32 and not font.has_char(c) and not out.contains(text[i]):
			out += text[i]
	return out


## The "#. max N" of an entry (0 = none).
static func max_of(e: Dictionary) -> int:
	for note: String in e.get("extracted", PackedStringArray()):
		if note.begins_with("max ") and note.substr(4).is_valid_int():
			return int(note.substr(4))
	return 0


## The {name} placeholders of a text (identifiers only: "{" in prose does not count).
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
	out.sort()
	return out


## The %-directives of a C-like format, in order ("%%" is no directive).
static func directives(text: String) -> PackedStringArray:
	if _re_directive == null:
		_re_directive = RegEx.create_from_string("%(%|[-+ 0#]*[0-9]*(?:\\.[0-9]+)?[a-zA-Z])")
	var out: PackedStringArray = []
	for m: RegExMatch in _re_directive.search_all(text):
		if m.get_string(1) != "%":
			out.append(m.get_string(0))
	return out


## The digit runs of a text, sorted ("1.840 EP" and "1,840 XP" both give ["1", "840"]).
static func digits(text: String) -> PackedStringArray:
	if _re_digits == null:
		_re_digits = RegEx.create_from_string("[0-9]+")
	var out: PackedStringArray = []
	for m: RegExMatch in _re_digits.search_all(text):
		out.append(m.get_string(0))
	out.sort()
	return out


static func _digits_ok(e: Dictionary) -> bool:
	for c: String in e.get("comments", PackedStringArray()):
		if c.begins_with(DIGITS_OK):
			return true
	return false
