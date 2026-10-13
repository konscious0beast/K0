class_name PoFile extends RefCounted
## The PO format for the language tools and tests (11 §1.2, §1.11): the strict parser with errors and translator
## comments, the messages a catalog takes, and the writer (string literals, gettext-style keyword lines). The
## extractor, the rules of test_11_po_rules, tools/i18n.sh and the tests use it. The running game never does: a start
## reads PO files with LocaleLoader.read_messages (lean, lenient; test_11_po keeps both readers equal), so this script
## stays off the boot path and out of its compile time (11-L1: startup ≤ +50 ms).

# --- the parser -------------------------------------------------------------------------------------------------------

## Parses the text of a PO/POT file: {"header": {"Language": …, "Plural-Forms": …}, "entries": [entry], "errors":
## PackedStringArray}. entry = {"ctx": String, "has_ctx": bool, "id": String, "plural": String, "str":
## PackedStringArray (msgstr or msgstr[0..n]), "fuzzy": bool, "line": int}; with `meta` also "flags", "extracted" (#.),
## "refs" (#:) and "comments" (# …) as PackedStringArray. The header (msgid "" without msgctxt) and obsolete "#~"
## entries are not in "entries". Errors read "<source>:<line>: <message>".
static func parse(text: String, source: String = "po", meta: bool = false) -> Dictionary:
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


## The messages a catalog takes from a parsed PO: translated (some msgstr not empty), not fuzzy. An empty plural form
## falls back to the msgid / msgid_plural (like gettext for a missing form).
static func messages(po: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in po.get("entries", []):
		if bool(e["fuzzy"]) or not _translated(e["str"]):
			continue
		out.append(e)
	return out


# --- the writer -------------------------------------------------------------------------------------------------------

## A string as a PO string literal (the extractor and the i18n tools write with it; parse reads it back).
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
	return LocaleLoader.unescape(body, source, line, errors)


## True if the closing quote of `s` is escaped (\" at the end with an odd number of backslashes before it).
static func _open_quote(s: String) -> bool:
	var i: int = s.length() - 2
	var slashes: int = 0
	while i >= 1 and s[i] == "\\":
		slashes += 1
		i -= 1
	return slashes % 2 == 1
