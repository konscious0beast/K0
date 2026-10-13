extends TestCase
## 11-L1 (11 §1.5, §1.8, §1.12): the rules of every translation in locale/en/*.po — the checks of
## core/data/validators/po.gd, which tools/i18n.sh check and the pack rules (validators/pack.gd) run too: placeholders
## ⊆ msgid (SP-9), the %-directives of c-format entries, the length limit of the field ("#. max N", persona
## placeholders at their longest), the same digit runs, no glyph the font lacks; "{count}" right before a word in a
## data text is a warning (F-16). Coverage is only reported: the gate "100 % translated, 0 fuzzy" is for builds shipped
## in English (L4, 11 §5.9). The PO files of the content packs (packs/<id>/locale/<lang>.po) keep the same rules (with
## the limits of the base entries they override). Plus the rules themselves on made-up entries.

const PoRules := preload("res://core/data/validators/po.gd")
const HEADER: String = "msgid \"\"\nmsgstr \"\"\n\"Language: en\\n\"\n" \
	+ "\"Content-Type: text/plain; charset=UTF-8\\n\"\n\"Plural-Forms: nplurals=2; plural=(n != 1);\\n\"\n\n"


func test_every_english_translation_keeps_the_rules() -> void:
	for d: String in LocaleLoader.DOMAINS:
		var path: String = "res://locale/en/%s.po" % d
		assert_true(FileAccess.file_exists(path), path)
		var res: Dictionary = PoRules.check_text(FileAccess.get_file_as_string(path), path)
		var c: Dictionary = res["counts"]
		print("[INFO] %s: %d entries — %d translated, %d fuzzy, %d empty" % [path, int(c["total"]),
			int(c["translated"]), int(c["fuzzy"]), int(c["empty"])])
		for w: String in res["warnings"]:
			print("[INFO] warning " + w)
		assert_eq(res["errors"], PackedStringArray(), "the rules of 11 §1.12 in " + path)
		assert_gt(int(c["total"]), 0, path + " is merged with its POT (tools/i18n.sh merge)")


## The PO files of the content packs (11 §3.5, §3.6; the Testbild pack, 11 §3.14): the same rules, an override keeps
## the limit of the base entry it replaces, the Language header names the file's language.
func test_every_pack_po_keeps_the_rules() -> void:
	var limits: Dictionary = PoRules.base_limits()
	assert_gt(limits.size(), 500, "the limits of the base POT files")
	var files: PackedStringArray = PoRules.pack_po_files()
	assert_has(files, "res://packs/testbild/locale/en.po")
	assert_has(files, "res://packs/testbild/locale/de.po")
	for path: String in files:
		var res: Dictionary = PoRules.check_pack_po(FileAccess.get_file_as_string(path), path,
			path.get_file().get_basename(), limits)
		assert_eq(res["errors"], PackedStringArray(), "the rules of 11 §1.12 in " + path)
		assert_gt(int((res["counts"] as Dictionary)["translated"]), 0, path + " carries translations")
	var text: String = HEADER + "\n".join(PackedStringArray([
		"msgctxt \"looks\"", "msgid \"Tierheim-Petrol\"", "msgstr \"Animal Shelter Petrol Blue\"", ""]))
	var long: Dictionary = PoRules.check_pack_po(text, "pack.po", "en", limits)
	assert_eq(long["errors"], PackedStringArray(["pack.po:7 (Tierheim-Petrol): 26 characters, the field allows 16"]),
		"an override without its own \"#. max\" keeps the base limit of looks.name")
	var other: Dictionary = PoRules.check_pack_po(text.replace("Animal Shelter Petrol Blue", "Shelter Petrol"),
		"pack.po", "de", limits)
	assert_eq(other["errors"], PackedStringArray(["pack.po: header Language 'en', the file is locale/de.po"]))


func test_the_rules_on_made_up_entries() -> void:
	var text: String = HEADER + "\n".join(PackedStringArray([
		"msgid \"{name} gewinnt\"", "msgstr \"{player} wins\"", "",
		"msgid \"{cand} {name} ist da\"", "msgstr \"{name} is here\"", "",
		"#, c-format", "msgid \"%d Credits\"", "msgstr \"%s credits\"", "",
		"#, c-format", "msgid \"%d Credits für %s\"", "msgstr \"%d credits for %s\"", "",
		"#. max 10", "msgid \"Kurz\"", "msgstr \"Far too long here\"", "",
		"#. max 20", "msgid \"{cand} ist da\"", "msgstr \"{cand} is here!\"", "",
		"#. max 20", "msgid \"{cand} kommt\"", "msgstr \"{cand} is coming now\"", "",
		"msgctxt \"items\"", "msgid \"Heilt 180 HP\"", "msgstr \"Heals 18 HP\"", "",
		"# digits-ok: a deliberate change", "msgctxt \"items\"", "msgid \"Heilt 50 HP\"", "msgstr \"Heals fifty HP\"", "",
		"msgctxt \"items\"", "msgid \"Heilt 1.840 HP\"", "msgstr \"Heals 1,840 HP\"", "",
		"msgid \"Notenschlüssel\"", "msgstr \"Clef 𝄞\"", "",
		"msgctxt \"achievements\"", "msgid \"Kämpfe bisher: {count}\"", "msgstr \"{count} fights so far\"", "",
		"msgid \"{count} Kampf\"", "msgstr \"{count} fights\"", "",
		"#, fuzzy", "msgid \"{a} alt\"", "msgstr \"{zzz} old 99\"", "",
	]))
	var res: Dictionary = PoRules.check_text(text, "made_up.po")
	var errors: String = "\n".join(res["errors"])
	for want: String in ["({name} gewinnt): {player} is not in the msgid",
			"(%d Credits): %-directives [\"%s\"], the msgid has [\"%d\"]",
			"(Kurz): 17 characters, the field allows 10",
			"({cand} kommt): 25 characters, the field allows 20",
			"(Heilt 180 HP): digits [\"18\"], the msgid has [\"180\"]",
			"(Notenschlüssel): glyphs the font lacks: 𝄞"]:
		assert_has(errors, want)
	for not_want: String in ["{cand} {name} ist da", "%d Credits für", "({cand} ist da)", "Heilt 50 HP", "Heilt 1.840",
			"{a} alt"]:
		assert_false(errors.contains(not_want), "fine: " + not_want)
	assert_eq((res["errors"] as PackedStringArray).size(), 6, errors)
	assert_eq(res["warnings"], PackedStringArray(["made_up.po:49 (Kämpfe bisher: {count}): {count} before a word: "
		+ "data texts have no plural forms — write them number-neutral (F-16)"]),
		"a data text only: code texts have Tx.n")
	assert_eq(res["counts"], {"total": 14, "translated": 13, "fuzzy": 1, "empty": 0})
	var bad_header: Dictionary = PoRules.check_text("msgid \"\"\nmsgstr \"\"\n\"Language: en\\n\"\n", "h.po")
	assert_eq((bad_header["errors"] as PackedStringArray).size(), 2, "charset and Plural-Forms missing")


func test_helpers() -> void:
	assert_eq(PoRules.placeholders("{b} und {a}, {b} — {nicht ein platzhalter} {1}"), PackedStringArray(["a", "b"]))
	assert_eq(PoRules.directives("%d %% %s %.1f %02d % "), PackedStringArray(["%d", "%s", "%.1f", "%02d"]))
	assert_eq(PoRules.digits("1.840 EP und 120 Credits, Etage 3"), PackedStringArray(["1", "120", "3", "840"]))
	assert_eq(PoRules.max_of({"extracted": PackedStringArray(["tag x", "max 32"])}), 32)
	assert_eq(PoRules.max_of({}), 0)
	assert_eq(PoRules.count_warning("{count} Kämpfe", ""), "", "code texts (no context) have Tx.n")
	assert_eq(PoRules.count_warning("Kämpfe: {count}", "talents"), "")
	assert_ne(PoRules.count_warning("{count} Kämpfe", "talents"), "")
