class_name LocaleLoader extends RefCounted
## The languages of the game (11 §1.2, §1.9; SP-1, SP-5). Reads the PO files of a language with its own parser
## (msgctxt, msgid, msgid_plural, msgstr[n]; a "fuzzy" entry counts as missing like in msgfmt, obsolete "#~" entries
## and the header are no messages), lays the PO of an active content pack over the base PO (pack > base > msgid,
## 11 §3.6) and builds ONE Translation per language. apply() registers it with the TranslationServer (tr(), tr_text()
## and TranslationServer.translate() keep working while L2 moves the code to Tx) and hands it to Tx. Static, no
## autoloads: Game calls apply() in _init, before the first screen exists (boot order, 11 §1.9).
##
## Layout (11 §1.2): res://locale/<lang>/<domain>.po for the domains ui, data, mod_lines and stempel; no PO for the
## source language (German is the msgid). A pack brings <pack folder>/locale/<lang>.po (11 §3.2) — also for German
## (overrides of German texts, 11 §3.6).

const ROOT: String = "res://locale"
## = PackLoader.ROOT (11 §3.2, 11-P1): the folder of the packs.
const PACK_ROOT: String = "res://packs"
const DOMAINS: PackedStringArray = ["ui", "data", "mod_lines", "stempel"]
const LANGUAGES_FILE: String = "languages.json"
## The value of [game] language that follows the system language (11 §1.9).
const AUTO: String = "auto"
## The language "Automatisch" picks when the system language is none of ours (11 §1.9: German OS → German, else this).
const INTERNATIONAL: String = "en"
const LANG_ARG: String = "--lang="

static var _registered: Translation = null   # the catalog apply() handed to the TranslationServer
static var _languages: Array[Dictionary] = []
static var _re_comment: RegEx = null


# --- languages and the choice of a run (11 §1.9) ---------------------------------------------------------------------

## The languages of locale/languages.json: [{"code", "name"}], the source language first.
static func languages(root: String = ROOT) -> Array[Dictionary]:
	if root == ROOT and not _languages.is_empty():
		return _languages
	var out: Array[Dictionary] = []
	var parsed: Variant = _read_json(root.path_join(LANGUAGES_FILE))
	if parsed is Dictionary:
		for e: Variant in ((parsed as Dictionary).get("languages", []) as Array):
			if e is Dictionary and str((e as Dictionary).get("code", "")) != "":
				out.append({"code": str(e["code"]), "name": str((e as Dictionary).get("name", e["code"]))})
	if out.is_empty():
		out.append({"code": Tx.SOURCE_LANG, "name": "Deutsch"})
	if root == ROOT:
		_languages = out
	return out


static func codes(root: String = ROOT) -> PackedStringArray:
	var out: PackedStringArray = []
	for l: Dictionary in languages(root):
		out.append(str(l["code"]))
	return out


static func is_language(code: String) -> bool:
	return codes().has(code)


## The source language (msgid = its text; no PO of its own): the first entry of languages.json.
static func source_lang() -> String:
	return str(languages()[0]["code"])


## The own name of a language ("Deutsch", "English"); the code if unknown.
static func language_name(code: String) -> String:
	for l: Dictionary in languages():
		if str(l["code"]) == code:
			return str(l["name"])
	return code


## The values of the setting [game] language: "auto" and every language code.
static func setting_values() -> PackedStringArray:
	var out: PackedStringArray = [AUTO]
	out.append_array(codes())
	return out


## "<code>" of a --lang=<code> argument ("" without one).
static func arg_language(user_args: PackedStringArray) -> String:
	for a: String in user_args:
		if a.begins_with(LANG_ARG):
			return a.trim_prefix(LANG_ARG).strip_edges().to_lower()
	return ""


## The language of a run (11 §1.9): --lang=<code> wins (transient, never saved); ephemeral runs (tests, capture,
## autoplay, fullrun) without it play German, independent of the machine; otherwise the setting — "auto" picks the
## system language if it is one of ours, else INTERNATIONAL. `allowed` (a pack's languages, 11 §3.6) narrows the
## choice; outside it `fallback` (the pack's default_lang) or the first allowed language. Unknown codes: German.
static func resolve(setting: String, user_args: PackedStringArray, ephemeral: bool, os_language: String,
		allowed: PackedStringArray = PackedStringArray(), fallback: String = "") -> String:
	var want: String = arg_language(user_args)
	if want != "" and not is_language(want):
		push_warning("[LocaleLoader] unknown language '%s' (--lang), using '%s'" % [want, source_lang()])
		want = source_lang()
	if want == "":
		if ephemeral:
			want = source_lang()
		elif setting == AUTO or not is_language(setting):
			want = os_language if is_language(os_language) else INTERNATIONAL
		else:
			want = setting
	if not allowed.is_empty() and not allowed.has(want):
		want = fallback if allowed.has(fallback) else allowed[0]
	return want if is_language(want) else source_lang()


# --- build and apply --------------------------------------------------------------------------------------------------

## The merged catalog of `lang`: the base PO files (DOMAINS order) — none for the source language — then the pack's
## locale/<lang>.po on top. {"lang", "translation": Translation (null = no message), "plurals": {"<ctx>\u0004<msgid>":
## PackedStringArray}, "count": int, "files": PackedStringArray (read), "missing": PackedStringArray (base files not
## found), "errors": PackedStringArray}.
static func build(lang: String, pack_dir: String = "", root: String = ROOT) -> Dictionary:
	var catalog: Translation = Translation.new()
	catalog.locale = lang
	var plurals: Dictionary = {}
	var files: PackedStringArray = []
	var missing: PackedStringArray = []
	var errors: PackedStringArray = []
	if lang != source_lang():
		for d: String in DOMAINS:
			var path: String = root.path_join(lang).path_join(d + ".po")
			if not FileAccess.file_exists(path):
				missing.append(path)
				continue
			files.append(path)
			read_messages(FileAccess.get_file_as_string(path), catalog, plurals)
	if pack_dir != "":
		var pack_po: String = pack_dir.path_join("locale").path_join(lang + ".po")
		if FileAccess.file_exists(pack_po):
			files.append(pack_po)
			read_messages(FileAccess.get_file_as_string(pack_po), catalog, plurals)
	var count: int = catalog.get_message_count()
	return {"lang": lang, "translation": catalog if count > 0 else null, "plurals": plurals, "count": count,
		"files": files, "missing": missing, "errors": errors}


## Applies a language to the running game: builds its catalog, swaps it in at the TranslationServer (the previous one
## is removed), sets the locale and hands catalog and language to Tx. A language without any base PO file stays German
## (warning, 11 §1.9). Returns build()'s dictionary; "lang" = the language applied.
static func apply(lang: String, pack_dir: String = "", root: String = ROOT) -> Dictionary:
	var t0: int = Time.get_ticks_usec()
	var code: String = lang if is_language(lang) else source_lang()
	var res: Dictionary = build(code, pack_dir, root)
	if code != source_lang() and (res["missing"] as PackedStringArray).size() == DOMAINS.size():
		push_warning("[LocaleLoader] no PO file for '%s' under %s: German texts" % [code, root])
		code = source_lang()
		res = build(code, pack_dir, root)
	for path: String in res["missing"]:
		if code != source_lang():
			push_warning("[LocaleLoader] missing %s: these texts stay German" % path)
	var errors: PackedStringArray = res["errors"]
	for i in mini(errors.size(), 5):
		push_warning("[LocaleLoader] " + errors[i])
	if _registered != null:
		TranslationServer.remove_translation(_registered)
		_registered = null
	var catalog: Translation = res["translation"]
	if catalog != null:
		TranslationServer.add_translation(catalog)
		_registered = catalog
	TranslationServer.set_locale(code)
	Tx.use_language(code, catalog, res["plurals"])
	if not (res["files"] as PackedStringArray).is_empty():
		print("[LocaleLoader] %s: %d PO files, %d messages (%.1f ms)" % [code, (res["files"] as PackedStringArray).size(),
			int(res["count"]), (Time.get_ticks_usec() - t0) / 1000.0])
	return res


# --- 11-P1 hook: the active content pack ------------------------------------------------------------------------------
# DB.pack (11 §3.8) is 11-P1's PackDef. It is read by name here, so L1 builds before P1 lands: the folder is the
# PackDef's "dir" if it has one, else PACK_ROOT/<id>; "languages" and "default_lang" mirror pack.json (11 §3.3).

static func pack_dir(pack: Object) -> String:
	if pack == null:
		return ""
	if "dir" in pack and str(pack.get("dir")) != "":
		return str(pack.get("dir"))
	var id: String = str(pack.get("id")) if "id" in pack else ""
	return PACK_ROOT.path_join(id) if id != "" else ""


static func pack_languages(pack: Object) -> PackedStringArray:
	var out: PackedStringArray = []
	if pack != null and "languages" in pack:
		for c: Variant in pack.get("languages"):
			out.append(str(c))
	return out


static func pack_default_lang(pack: Object) -> String:
	return str(pack.get("default_lang")) if pack != null and "default_lang" in pack else ""


# --- the PO parser (11 §1.2) ------------------------------------------------------------------------------------------

## Parses the text of a PO/POT file: {"header": {"Language": …, "Plural-Forms": …}, "entries": [entry], "errors":
## PackedStringArray}. entry = {"ctx": String, "has_ctx": bool, "id": String, "plural": String, "str":
## PackedStringArray (msgstr or msgstr[0..n]), "fuzzy": bool, "line": int}; with `meta` also "flags", "extracted" (#.),
## "refs" (#:) and "comments" (# …) as PackedStringArray. The header (msgid "" without msgctxt) and obsolete "#~"
## entries are not in "entries". Errors read "<source>:<line>: <message>".
static func parse_po(text: String, source: String = "po", meta: bool = false) -> Dictionary:
	var entries: Array[Dictionary] = []
	var errors: PackedStringArray = []
	var header: Dictionary = {}
	var lines: PackedStringArray = text.split("\n")
	var cur: Dictionary = _new_entry(meta)
	var field: String = ""                        # "ctx" | "id" | "plural" | "str<n>": where a continuation goes
	for n in lines.size():
		var line: String = lines[n].strip_edges()
		if line == "":
			if _flush(cur, entries, header, errors, source):
				cur = _new_entry(meta)
			field = ""
			continue
		var c0: String = line[0]
		if c0 == "#":
			if line.begins_with("#~"):
				continue                          # obsolete entry: not a message
			if bool(cur["done"]) and _flush(cur, entries, header, errors, source):
				cur = _new_entry(meta)
			field = ""
			_comment(cur, line, meta)
			continue
		if c0 == "\"":
			var cont: String = _quoted(line, source, n + 1, errors)
			if field == "":
				errors.append("%s:%d: a string without a keyword" % [source, n + 1])
			else:
				_append(cur, field, cont)
			continue
		var sp: int = line.find(" ")
		var kw: String = line.substr(0, sp) if sp > 0 else line
		var value: String = _quoted(line.substr(sp + 1).strip_edges() if sp > 0 else "", source, n + 1, errors)
		if (kw == "msgctxt" or kw == "msgid") and bool(cur["done"]):
			if _flush(cur, entries, header, errors, source):
				cur = _new_entry(meta)
		if cur["line"] == 0:
			cur["line"] = n + 1
		match kw:
			"msgctxt":
				cur["ctx"] = value
				cur["has_ctx"] = true
				field = "ctx"
			"msgid":
				cur["id"] = value
				cur["has_id"] = true
				field = "id"
			"msgid_plural":
				cur["plural"] = value
				field = "plural"
			"msgstr":
				_push(cur, "str", value)
				cur["done"] = true
				field = "str0"
			_:
				if kw.begins_with("msgstr[") and kw.ends_with("]") and kw.substr(7, kw.length() - 8).is_valid_int():
					var idx: int = int(kw.substr(7, kw.length() - 8))
					var forms: PackedStringArray = cur["str"]
					if idx != forms.size():
						errors.append("%s:%d: %s out of order" % [source, n + 1, kw])
					while forms.size() <= idx:
						forms.append("")
					forms[idx] = value
					cur["str"] = forms
					cur["done"] = true
					field = "str%d" % idx
				else:
					errors.append("%s:%d: unknown keyword '%s'" % [source, n + 1, kw])
					field = ""
	_flush(cur, entries, header, errors, source)
	return {"header": header, "entries": entries, "errors": errors}


## The runtime reader (the start of an English game reads every PO): only what the catalog takes, the translated and
## non-fuzzy entries in file order — [[ctx, msgid, msgid_plural, PackedStringArray forms]], or straight into `into`
## (later entries override earlier ones: the pack PO after the base) with the plural forms in `plurals` ("<ctx>\u0004
## <msgid>" → forms, for Tx.n). An empty plural form falls back to msgid / msgid_plural. Lenient and fast: the comment
## lines except "#," are cut natively first, there is no dictionary per entry; malformed lines are skipped — the
## rules are parse_po's (tools/i18n.sh check, test_11_po_rules). test_11_po compares both readers.
static func read_messages(text: String, into: Translation = null, plurals: Dictionary = {}) -> Array:
	if _re_comment == null:
		_re_comment = RegEx.create_from_string("(?m)^#(?!,)[^\\n]*\\n")
	var out: Array = []
	var lines: PackedStringArray = _re_comment.sub(text.replace("\r\n", "\n"), "", true).split("\n")
	lines.append("")                              # the last entry ends like every other one
	var ctx: String = ""
	var id: String = ""
	var plural: String = ""
	var forms: PackedStringArray = []
	var fuzzy: bool = false
	var has_id: bool = false
	var done: bool = false                        # a msgstr was read
	var field: int = -1                           # where a continuation goes: 0 ctx, 1 id, 2 plural, 3 + n msgstr[n]
	for line: String in lines:
		var c: int = line.unicode_at(0) if line != "" else 0
		# An entry ends at a blank line, or at a "#," / msgctxt / msgid after its msgstr.
		if (c == 0 and has_id) or (done and (c == 35 or line.begins_with("msgctxt ") or line.begins_with("msgid "))):
			if done and not fuzzy and (ctx != "" or id != "") and _translated(forms):
				if plural != "":
					for i in forms.size():
						if forms[i] == "":
							forms[i] = id if i == 0 else plural
				if into == null:
					out.append([ctx, id, plural, PackedStringArray([forms[0]]) if plural == "" else forms])
				elif plural == "":
					into.add_message(id, forms[0], ctx)
				else:
					into.add_plural_message(id, forms, ctx)
					plurals[ctx + Tx.CTX_SEP + id] = forms
			ctx = ""
			id = ""
			plural = ""
			forms = PackedStringArray()
			fuzzy = false
			has_id = false
			done = false
		if c == 0 or c == 35:                     # a blank line; "#," (the only comment left): the fuzzy flag
			fuzzy = fuzzy or (c == 35 and line.contains("fuzzy"))
			field = -1
			continue
		if c == 34:                               # a continuation string
			var cont: String = _lenient(line)
			match field:
				0:
					ctx += cont
				1:
					id += cont
				2:
					plural += cont
				-1:
					pass
				_:
					if field - 3 < forms.size():
						forms[field - 3] += cont
			continue
		var sp: int = line.find(" ")
		if sp < 0:
			continue
		var kw: String = line.left(sp)
		var value: String = _lenient(line.substr(sp + 1))
		match kw:
			"msgctxt":
				ctx = value
				field = 0
			"msgid":
				id = value
				has_id = true
				field = 1
			"msgid_plural":
				plural = value
				field = 2
			"msgstr":
				forms = PackedStringArray([value])
				done = true
				field = 3
			_:
				var idx: int = int(kw.substr(7, kw.length() - 8)) if kw.begins_with("msgstr[") else -1
				if idx >= 0:
					while forms.size() <= idx:
						forms.append("")
					forms[idx] = value
					done = true
					field = 3 + idx
				else:
					field = -1
	return out


## The messages a catalog takes from a parsed PO: translated (some msgstr not empty), not fuzzy. An empty plural form
## falls back to the msgid / msgid_plural (like gettext for a missing form).
static func messages(po: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in po.get("entries", []):
		if bool(e["fuzzy"]) or not _translated(e["str"]):
			continue
		out.append(e)
	return out


## A string as a PO string literal (the extractor and the i18n tools write with it; parse_po reads it back).
static func po_string(s: String) -> String:
	return "\"" + s.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\t", "\\t") \
		.replace("\r", "\\r") + "\""


## A keyword line, gettext style for multi-line texts: msgid "" then one string per line (each ends with \n).
static func po_field(keyword: String, s: String) -> String:
	var cut: int = s.find("\n")
	if cut < 0 or cut == s.length() - 1:
		return keyword + " " + po_string(s)
	var out: PackedStringArray = [keyword + " \"\""]
	var rest: String = s
	while rest != "":
		var at: int = rest.find("\n")
		var part: String = rest if at < 0 else rest.substr(0, at + 1)
		out.append(po_string(part))
		rest = "" if at < 0 else rest.substr(at + 1)
	return "\n".join(out)


# --- internals --------------------------------------------------------------------------------------------------------

static func _translated(forms: PackedStringArray) -> bool:
	for s: String in forms:
		if s != "":
			return true
	return false


static func _new_entry(meta: bool) -> Dictionary:
	var e: Dictionary = {"ctx": "", "has_ctx": false, "id": "", "has_id": false, "plural": "",
		"str": PackedStringArray(), "fuzzy": false, "line": 0, "done": false}
	if meta:
		e["flags"] = PackedStringArray()
		e["extracted"] = PackedStringArray()
		e["refs"] = PackedStringArray()
		e["comments"] = PackedStringArray()
	return e


## Ends the entry `e`: the header goes to `header`, a message to `entries`. True if something was taken (a new entry
## starts), false if `e` was empty (only comments so far: they belong to the next msgid).
static func _flush(e: Dictionary, entries: Array[Dictionary], header: Dictionary, errors: PackedStringArray,
		source: String) -> bool:
	if not bool(e["has_id"]):
		return false
	if not bool(e["done"]):
		errors.append("%s:%d: msgid without msgstr" % [source, int(e["line"])])
	e.erase("has_id")
	e.erase("done")
	if str(e["id"]) == "" and not bool(e["has_ctx"]):
		var forms: PackedStringArray = e["str"]
		for row: String in (forms[0] if not forms.is_empty() else "").split("\n", false):
			var colon: int = row.find(":")
			if colon > 0:
				header[row.substr(0, colon).strip_edges()] = row.substr(colon + 1).strip_edges()
		return true
	if str(e["plural"]) == "" and (e["str"] as PackedStringArray).size() > 1:
		errors.append("%s:%d: msgstr[n] without msgid_plural" % [source, int(e["line"])])
	entries.append(e)
	return true


static func _comment(e: Dictionary, line: String, meta: bool) -> void:
	var kind: String = line.substr(0, 2)
	var body: String = line.substr(2).strip_edges()
	if kind == "#,":
		for f: String in body.split(",", false):
			var flag: String = f.strip_edges()
			if flag == "fuzzy":
				e["fuzzy"] = true
			if meta:
				_push(e, "flags", flag)
		return
	if not meta:
		return
	match kind:
		"#.":
			_push(e, "extracted", body)
		"#:":
			_push(e, "refs", body)
		"#|":
			pass                                  # previous msgid of a fuzzy entry (msgmerge): not needed
		_:
			_push(e, "comments", line.substr(1).strip_edges())


## Appends to a PackedStringArray held by a Dictionary (a packed array is a value: append to it, store it back).
static func _push(d: Dictionary, key: String, value: String) -> void:
	var a: PackedStringArray = d[key]
	a.append(value)
	d[key] = a


static func _append(e: Dictionary, field: String, s: String) -> void:
	match field:
		"ctx":
			e["ctx"] = str(e["ctx"]) + s
		"id":
			e["id"] = str(e["id"]) + s
		"plural":
			e["plural"] = str(e["plural"]) + s
		_:
			var idx: int = int(field.substr(3))
			var forms: PackedStringArray = e["str"]
			if idx < forms.size():
				forms[idx] = forms[idx] + s
				e["str"] = forms


## The content of a "…" literal, unescaped (C escapes like gettext: \n \t \r \" \\ \a \b \f \v, octal, \x hex).
static func _quoted(s: String, source: String, line: int, errors: PackedStringArray) -> String:
	if s.length() < 2 or not s.begins_with("\"") or not s.ends_with("\"") or _open_quote(s):
		errors.append("%s:%d: not a closed string: %s" % [source, line, s])
		return ""
	var body: String = s.substr(1, s.length() - 2)
	if not body.contains("\\"):
		return body
	return _unescape(body, source, line, errors)


## The content of a "…" literal for the runtime reader (no error list: the tools check the files).
static func _lenient(s: String) -> String:
	var t: String = s.strip_edges()
	if t.length() < 2 or not t.begins_with("\"") or not t.ends_with("\""):
		return ""
	var body: String = t.substr(1, t.length() - 2)
	return _unescape(body, "", 0, PackedStringArray()) if body.contains("\\") else body


## True if the closing quote of `s` is escaped (\" at the end with an odd number of backslashes before it).
static func _open_quote(s: String) -> bool:
	var i: int = s.length() - 2
	var slashes: int = 0
	while i >= 1 and s[i] == "\\":
		slashes += 1
		i -= 1
	return slashes % 2 == 1


static func _unescape(body: String, source: String, line: int, errors: PackedStringArray) -> String:
	var out: String = ""
	var i: int = 0
	var count: int = body.length()
	while i < count:
		var ch: String = body[i]
		if ch != "\\":
			out += ch
			i += 1
			continue
		if i + 1 >= count:
			errors.append("%s:%d: a backslash at the end of a string" % [source, line])
			break
		var e: String = body[i + 1]
		i += 2
		match e:
			"n":
				out += "\n"
			"t":
				out += "\t"
			"r":
				out += "\r"
			"\"", "\\", "'", "?":
				out += e
			"a":
				out += char(7)
			"b":
				out += char(8)
			"f":
				out += char(12)
			"v":
				out += char(11)
			"x":
				var hex: String = ""
				while i < count and hex.length() < 2 and "0123456789abcdefABCDEF".contains(body[i]):
					hex += body[i]
					i += 1
				if hex == "":
					errors.append("%s:%d: \\x without hex digits" % [source, line])
				else:
					out += char(hex.hex_to_int())
			_:
				if "01234567".contains(e):
					var oct: String = e
					while i < count and oct.length() < 3 and "01234567".contains(body[i]):
						oct += body[i]
						i += 1
					var code: int = 0
					for d: String in oct:
						code = code * 8 + int(d)
					out += char(code)
				else:
					errors.append("%s:%d: unknown escape \\%s" % [source, line, e])
					out += e
	return out


static func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))
