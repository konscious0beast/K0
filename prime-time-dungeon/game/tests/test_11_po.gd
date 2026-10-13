extends TestCase
## 11-L1 (11 §1.2, §1.12): the PO parser of LocaleLoader — msgctxt, plural, continuation lines, escapes, "fuzzy"
## (missing, like msgfmt), comments, obsolete entries, the header, errors — and the round trip with the extractor's
## writer. The fixtures under tests/fixtures/locale were checked with `msgfmt --check` (GNU gettext 0.21); the test
## checks them again when msgfmt is on the PATH.

const FIX: String = "res://tests/fixtures/locale"
const UI_PO: String = "res://tests/fixtures/locale/root/en/ui.po"


func _parse(path: String, meta: bool = false) -> Dictionary:
	return LocaleLoader.parse_po(FileAccess.get_file_as_string(path), path, meta)


func _find(po: Dictionary, id: String, ctx: String = "") -> Dictionary:
	for e: Dictionary in po["entries"]:
		if str(e["id"]) == id and str(e["ctx"]) == ctx:
			return e
	return {}


func test_entries_contexts_and_plurals() -> void:
	var po: Dictionary = _parse(UI_PO)
	assert_eq(po["errors"], PackedStringArray(), "the fixture parses cleanly")
	assert_eq(_find(po, "Gift")["str"], PackedStringArray(["Poison"]))
	assert_eq(_find(po, "Stand", "season")["str"], PackedStringArray(["Standings"]), "msgctxt")
	assert_true(bool(_find(po, "Stand", "season")["has_ctx"]))
	assert_eq(_find(po, "Stand")["str"], PackedStringArray(["Stand"]), "the same msgid without a context")
	var pl: Dictionary = _find(po, "{count} Kampf")
	assert_eq([pl["plural"], pl["str"]], ["{count} Kämpfe", PackedStringArray(["{count} fight", "{count} fights"])])
	assert_eq(_find(po, "Zwei Zeilen:\ndie zweite")["str"], PackedStringArray(["Two lines:\nthe second"]),
		"continuation lines join")
	assert_eq(_find(po, "Sie sagt \"Hallo\" mit \\ und\tTab")["str"],
		PackedStringArray(["She says \"Hello\" with \\ and\tTab"]), "escapes \\\" \\\\ \\t")
	assert_eq(_find(po, "Oktal A und Hex B")["str"], PackedStringArray(["Octal A and hex B"]), "octal and hex escapes")
	assert_eq(po["header"].get("Language"), "en")
	assert_eq(po["header"].get("Plural-Forms"), "nplurals=2; plural=(n != 1);")
	assert_eq(po["header"].get("Content-Type"), "text/plain; charset=UTF-8")
	assert_true(_find(po, "Entfernt").is_empty(), "obsolete #~ entries are no entries")
	assert_true(_find(po, "").is_empty(), "the header is not an entry")
	assert_eq(int(_find(po, "Gift")["line"]), 14, "the line of the first keyword")


func test_fuzzy_and_untranslated_are_missing() -> void:
	var po: Dictionary = _parse(UI_PO)
	assert_true(bool(_find(po, "Neuer Text")["fuzzy"]), "#, fuzzy")
	assert_false(bool(_find(po, "Gift")["fuzzy"]))
	var ids: PackedStringArray = []
	for e: Dictionary in LocaleLoader.messages(po):
		ids.append(("%s|%s" % [e["ctx"], e["id"]]))
	assert_false(ids.has("|Neuer Text"), "fuzzy counts as missing (like msgfmt)")
	assert_false(ids.has("|Noch nicht übersetzt"), "an empty msgstr is no message")
	assert_true(ids.has("|{count} Truhe"), "one translated form is enough (the other falls back)")
	assert_eq(ids.size(), 9, "Gift, Stand (2), Kampf, Truhe, two lines, quotes, octal, %d Credits: " + str(ids))


func test_comments_with_meta() -> void:
	var po: Dictionary = _parse(UI_PO, true)
	var g: Dictionary = _find(po, "Gift")
	assert_eq([g["extracted"], g["refs"], g["comments"]], [PackedStringArray(["max 24"]),
		PackedStringArray(["scenes/ui/ui_util.gd:26"]), PackedStringArray(["a translator comment"])])
	assert_eq(_find(po, "%d Credits")["flags"], PackedStringArray(["c-format"]))
	assert_eq(_find(po, "Neuer Text")["flags"], PackedStringArray(["fuzzy"]))
	assert_false(_parse(UI_PO).get("entries", [])[0].has("refs"), "without meta: no comment fields (the loader)")


func test_line_endings_and_errors() -> void:
	var crlf: String = "msgid \"\"\r\nmsgstr \"Language: en\\n\"\r\n\r\nmsgid \"A\"\r\nmsgstr \"B\"\r\n"
	var po: Dictionary = LocaleLoader.parse_po(crlf, "crlf")
	assert_eq([po["errors"], _find(po, "A")["str"]], [PackedStringArray(), PackedStringArray(["B"])], "CRLF")
	var bad: Dictionary = LocaleLoader.parse_po("\n".join(PackedStringArray([
		"msgid \"open", "msgstr \"x\"", "",
		"msgid \"a\"", "msgstr[1] \"b\"", "",
		"msgid \"c\"", "msgtext \"d\"", "",
		"msgid \"e\"", "",
		"\"stray\"", "",
		"msgid \"f\\q\"", "msgstr \"g\"",
	])), "bad.po")
	var errors: String = "\n".join(bad["errors"])
	for want: String in ["bad.po:1: not a closed string", "bad.po:5: msgstr[1] out of order",
			"msgstr[n] without msgid_plural", "bad.po:8: unknown keyword 'msgtext'", "msgid without msgstr",
			"bad.po:12: a string without a keyword", "bad.po:14: unknown escape \\q"]:
		assert_has(errors, want)
	var esc: Dictionary = LocaleLoader.parse_po("msgid \"a\\\"\"\nmsgstr \"b\\\\\"\n", "esc")
	assert_eq([esc["errors"], _find(esc, "a\"")["str"]], [PackedStringArray(), PackedStringArray(["b\\"])],
		"an escaped quote before the closing one; a backslash at the end")


func test_round_trip_with_the_writer() -> void:
	var po: Dictionary = _parse(UI_PO)
	var out: PackedStringArray = []
	for e: Dictionary in po["entries"]:
		if bool(e["has_ctx"]):
			out.append(LocaleLoader.po_field("msgctxt", str(e["ctx"])))
		out.append(LocaleLoader.po_field("msgid", str(e["id"])))
		var forms: PackedStringArray = e["str"]
		if str(e["plural"]) != "":
			out.append(LocaleLoader.po_field("msgid_plural", str(e["plural"])))
			for i in forms.size():
				out.append(LocaleLoader.po_field("msgstr[%d]" % i, forms[i]))
		else:
			out.append(LocaleLoader.po_field("msgstr", forms[0]))
		out.append("")
	var back: Dictionary = LocaleLoader.parse_po("\n".join(out), "round trip")
	assert_eq(back["errors"], PackedStringArray())
	assert_eq(back["entries"].size(), po["entries"].size())
	for i in mini(back["entries"].size(), po["entries"].size()):
		var a: Dictionary = po["entries"][i]
		var b: Dictionary = back["entries"][i]
		assert_eq([b["ctx"], b["id"], b["plural"], b["str"]], [a["ctx"], a["id"], a["plural"], a["str"]], str(a["id"]))
	assert_eq(LocaleLoader.po_field("msgid", "a\nb"), "msgid \"\"\n\"a\\n\"\n\"b\"", "gettext style for two lines")
	assert_eq(LocaleLoader.po_field("msgid", "a\n"), "msgid \"a\\n\"", "one line with its newline stays one line")


func test_build_merges_domains_and_the_pack() -> void:
	var base: Dictionary = LocaleLoader.build("en", "", FIX + "/root")
	assert_eq(base["errors"], PackedStringArray())
	assert_eq(base["missing"], PackedStringArray())
	assert_eq((base["files"] as PackedStringArray).size(), 4, "ui, data, mod_lines, stempel")
	var tr: Translation = base["translation"]
	assert_not_null(tr)
	if tr == null:
		return
	assert_eq(tr.locale, "en")
	assert_eq([String(tr.get_message("Gift")), String(tr.get_message("Gift", "items")),
		String(tr.get_message("Provoziert", "statuses:sts_taunt")), String(tr.get_message("Provoziert",
		"statuses:sts_taunted")), String(tr.get_message("Willkommen, {cand}!", "mod_lines"))],
		["Poison", "Poison flask", "Taunting", "Taunted", "Welcome!"], "one catalog for the four domains")
	assert_eq(String(tr.get_message("Neuer Text")), "", "fuzzy is not in the catalog")
	assert_eq((base["plurals"] as Dictionary).get(Tx.CTX_SEP + "{count} Truhe"),
		PackedStringArray(["{count} chest", "{count} Truhen"]), "an empty form falls back to msgid_plural")
	var with_pack: Dictionary = LocaleLoader.build("en", FIX + "/pack", FIX + "/root")
	var tp: Translation = with_pack["translation"]
	assert_eq([String(tp.get_message("Gift")), String(tp.get_message("Testbild")), String(tp.get_message("Gift",
		"items"))], ["Venom", "Test Card", "Poison flask"], "pack PO > base PO; other entries stay")
	assert_eq(String(tp.get_plural_message("{count} Kampf", "{count} Kämpfe", 3)), "{count} bouts")
	assert_eq((with_pack["files"] as PackedStringArray)[-1], FIX + "/pack/locale/en.po", "the pack comes last")
	var de: Dictionary = LocaleLoader.build("de", FIX + "/pack", FIX + "/root")
	assert_eq(de["missing"], PackedStringArray(), "German has no base PO")
	assert_eq(String((de["translation"] as Translation).get_message("Graf Mopsula")), "Graf Testbild",
		"a pack's de.po overrides German texts")
	var none: Dictionary = LocaleLoader.build("de")
	assert_null(none["translation"], "German without a pack: no catalog (msgids)")


## The fixtures are what msgfmt accepts (checked when GNU gettext is installed; the tests never need it).
func test_fixtures_pass_msgfmt_when_installed() -> void:
	var probe: Array = []
	if OS.execute("msgfmt", PackedStringArray(["--version"]), probe) != 0:
		print("[INFO] msgfmt not on the PATH: the fixtures were checked when they were written")
		return
	for rel: String in ["root/en/ui.po", "root/en/data.po", "root/en/mod_lines.po", "root/en/stempel.po",
			"pack/locale/en.po", "pack/locale/de.po"]:
		var out: Array = []
		var code: int = OS.execute("msgfmt", PackedStringArray(["--check", "-o", "/dev/null",
			ProjectSettings.globalize_path(FIX.path_join(rel))]), out, true)
		assert_eq(code, 0, "msgfmt --check %s: %s" % [rel, "".join(out)])


## The runtime reader (LocaleLoader.read_messages: no dictionary per entry) takes exactly what messages(parse_po())
## takes — on the fixtures and on a fully translated copy of the real POT files.
func test_the_runtime_reader_matches_the_parser() -> void:
	var texts: Dictionary = {}
	for rel: String in ["root/en/ui.po", "root/en/data.po", "pack/locale/en.po"]:
		texts[rel] = FileAccess.get_file_as_string(FIX.path_join(rel))
	for d: String in LocaleLoader.DOMAINS:
		texts["full " + d] = _translated_copy(FileAccess.get_file_as_string("res://locale/pot/%s.pot" % d))
	texts["crlf"] = "msgid \"\"\r\nmsgstr \"Language: en\\n\"\r\n\r\n#, fuzzy\r\nmsgid \"A\"\r\nmsgstr \"B\"\r\n\r\n" \
		+ "msgid \"C\"\r\nmsgstr \"D\"\r\n"
	for k: String in texts:
		var fast: Array = LocaleLoader.read_messages(str(texts[k]))
		var full: Array = []
		var po: Dictionary = LocaleLoader.parse_po(str(texts[k]), k)
		for e: Dictionary in LocaleLoader.messages(po):
			var forms: PackedStringArray = (e["str"] as PackedStringArray).duplicate()
			if str(e["plural"]) == "":
				forms = PackedStringArray([forms[0]])
			else:
				for i in forms.size():
					if forms[i] == "":
						forms[i] = str(e["id"]) if i == 0 else str(e["plural"])
			full.append([str(e["ctx"]), str(e["id"]), str(e["plural"]), forms])
		assert_eq(po["errors"], PackedStringArray(), k + ": a well-formed file")
		assert_eq(fast.size(), full.size(), k + ": the same messages")
		assert_eq(fast, full, k)
	assert_eq(LocaleLoader.read_messages(str(texts["crlf"])), [["", "C", "", PackedStringArray(["D"])]],
		"CRLF, fuzzy skipped")
	var tr: Translation = Translation.new()
	var plurals: Dictionary = {}
	LocaleLoader.read_messages(str(texts["root/en/ui.po"]), tr, plurals)
	assert_eq([String(tr.get_message("Gift")), String(tr.get_message("Stand", "season")), plurals.keys().size()],
		["Poison", "Standings", 2], "straight into a catalog; the plural forms for Tx")


## The start of an English game reads the four PO files: a fully translated catalog (every msgid of the POTs) builds in
## ≤ 50 ms (11 §1.2 Messziel; asserted with PTD_PERF_ASSERTS=1 like every timing, printed otherwise).
func test_a_full_catalog_builds_fast() -> void:
	var root: String = "user://test_11_po_full"
	DirAccess.make_dir_recursive_absolute(root.path_join("en"))
	var keys: Dictionary = {}
	for d: String in LocaleLoader.DOMAINS:
		var text: String = _translated_copy(FileAccess.get_file_as_string("res://locale/pot/%s.pot" % d))
		for e: Dictionary in LocaleLoader.parse_po(text, d)["entries"]:
			keys[str(e["ctx"]) + Tx.CTX_SEP + str(e["id"])] = true
		var f: FileAccess = FileAccess.open(root.path_join("en").path_join(d + ".po"), FileAccess.WRITE)
		f.store_string(text)
		f.close()
	var best: float = INF
	var res: Dictionary = {}
	for i in 3:
		var t0: int = Time.get_ticks_usec()
		res = LocaleLoader.build("en", "", root)
		best = minf(best, (Time.get_ticks_usec() - t0) / 1000.0)
	assert_eq(res["errors"], PackedStringArray())
	assert_eq(int(res["count"]), keys.size(), "every msgid of the four POTs")
	assert_time_budget(best, 50.0, "build of a full English catalog (%d messages)" % int(res["count"]))
	for d: String in LocaleLoader.DOMAINS:
		DirAccess.remove_absolute(root.path_join("en").path_join(d + ".po"))
	DirAccess.remove_absolute(root.path_join("en"))
	DirAccess.remove_absolute(root)


## A POT with every msgstr filled ("EN " + the msgid; plural forms too) — a stand-in for the finished translation.
static func _translated_copy(pot: String) -> String:
	var out: PackedStringArray = []
	var last_id: String = ""
	var last_plural: String = ""
	for line: String in pot.split("\n"):
		if line.begins_with("msgid \"") and line != "msgid \"\"":
			last_id = line.substr(6)
		elif line.begins_with("msgid_plural \""):
			last_plural = line.substr(13)
		if line == "msgstr \"\"" and last_id != "":
			out.append("msgstr \"EN " + last_id.substr(1))
			continue
		if line == "msgstr[0] \"\"":
			out.append("msgstr[0] \"EN " + last_id.substr(1))
			continue
		if line == "msgstr[1] \"\"":
			out.append("msgstr[1] \"EN " + last_plural.substr(1))
			continue
		out.append(line)
		if line == "":
			last_id = ""
			last_plural = ""
	return "\n".join(out)
