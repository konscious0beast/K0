class_name LocaleLoader extends RefCounted
## The languages of the game (11 §1.2, §1.9; SP-1, SP-5). Reads the PO files of a language with its own reader
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
const DOMAINS: PackedStringArray = ["ui", "data", "mod_lines", "stempel"]
const LANGUAGES_FILE: String = "languages.json"
## The value of [game] language that follows the system language (11 §1.9).
const AUTO: String = "auto"
## The language "Automatisch" picks when the system language is none of ours (11 §1.9: German OS → German, else this).
const INTERNATIONAL: String = "en"
const LANG_ARG: String = "--lang="

static var _registered: Translation = null   # the catalog apply() handed to the TranslationServer
static var _languages: Array[Dictionary] = []
static var _re_comment: RegEx = null         # the comment lines but "#," (read_messages)
static var _re_untranslated: RegEx = null    # a whole singular entry with msgstr "" (read_messages)


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


## The values of the setting [game] language: "auto" and every language code — of `allowed` only when it is not empty
## (an active pack's languages, 11 §3.6).
static func setting_values(allowed: PackedStringArray = PackedStringArray()) -> PackedStringArray:
	var out: PackedStringArray = [AUTO]
	for c: String in codes():
		if allowed.is_empty() or allowed.has(c):
			out.append(c)
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
## (warning, 11 §1.9). Returns build()'s dictionary; "lang" = the language applied. No clock here (core/,
## test_m8_no_global_rng): Game.apply_language times and logs the load.
static func apply(lang: String, pack_dir: String = "", root: String = ROOT) -> Dictionary:
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
	return res


# --- the active content pack (11 §3.6, 11-P1: DB.pack) ---------------------------------------------------------------
# A pack's locale/<lang>.po lies over the base PO (pack > base > msgid) — also for German (overrides of German texts);
# the pack's `languages` narrow the choice (resolve, the options row), `default_lang` is the choice outside them.

## The folder whose locale/<lang>.po apply() lays over the base ("" = no pack).
static func pack_dir(pack: PackDef) -> String:
	return pack.root if pack != null else ""


static func pack_languages(pack: PackDef) -> PackedStringArray:
	return pack.languages if pack != null else PackedStringArray()


static func pack_default_lang(pack: PackDef) -> String:
	return pack.default_lang if pack != null else ""


# --- the PO reader of a start (11 §1.2) -------------------------------------------------------------------------------

## The runtime reader (the start of an English game reads every PO): only what the catalog takes, the translated and
## non-fuzzy entries in file order — [[ctx, msgid, msgid_plural, PackedStringArray forms]], or straight into `into`
## (later entries override earlier ones: the pack PO after the base) with the plural forms in `plurals` ("<ctx>\u0004
## <msgid>" → forms, for Tx.n). An empty plural form falls back to msgid / msgid_plural. Lenient and fast: two native
## regex passes first cut the comment lines but "#," and every untranslated singular entry, the loop then sees only
## translations, without a dictionary per entry; malformed lines are skipped — the rules are PoFile.parse's
## (tools/i18n.sh check, test_11_po_rules). test_11_po compares both readers.
static func read_messages(text: String, into: Translation = null, plurals: Dictionary = {}) -> Array:
	if _re_comment == null:
		_re_comment = RegEx.create_from_string("(?m)^#(?!,)[^\\n]*\\n")
		_re_untranslated = RegEx.create_from_string("(?m)^(?:#,[^\\n]*\\n)?(?:msgctxt \"[^\\n]*\"\\n(?:\"[^\\n]*\"\\n)*)?"
			+ "msgid \"[^\\n]*\"\\n(?:\"[^\\n]*\"\\n)*msgstr \"\"\\n(?!\")")
	var out: Array = []
	var lean: String = _re_comment.sub(text.replace("\r\n", "\n"), "", true)
	var lines: PackedStringArray = _re_untranslated.sub(lean, "", true).split("\n")
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
			var cont: String = _value(line, 0)
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
		var value: String = _value(line, sp + 1)
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


## The text of a PO string body, C escapes resolved like gettext (\n \t \r \" \\ \a \b \f \v, octal, \x hex); a
## bad escape appends "<source>:<line>: …" to `errors` (PoFile.parse reports them; the runtime reader ignores them).
static func unescape(body: String, source: String, line: int, errors: PackedStringArray) -> String:
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


# --- internals --------------------------------------------------------------------------------------------------------

static func _translated(forms: PackedStringArray) -> bool:
	for s: String in forms:
		if s != "":
			return true
	return false


## The value of the "…" literal that starts at `from` in a PO line — the fast way for the well-formed lines msgmerge
## writes (the quotes at `from` and at the end, escapes only where a backslash is), else _lenient.
static func _value(line: String, from: int) -> String:
	if line.unicode_at(from) != 34 or not line.ends_with("\"") or line.length() - from < 2:
		return _lenient(line.substr(from))
	var body: String = line.substr(from + 1, line.length() - from - 2)
	return unescape(body, "", 0, PackedStringArray()) if body.contains("\\") else body


## The content of a "…" literal for the runtime reader (no error list: the tools check the files).
static func _lenient(s: String) -> String:
	var t: String = s.strip_edges()
	if t.length() < 2 or not t.begins_with("\"") or not t.ends_with("\""):
		return ""
	var body: String = t.substr(1, t.length() - 2)
	return unescape(body, "", 0, PackedStringArray()) if body.contains("\\") else body


static func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))
