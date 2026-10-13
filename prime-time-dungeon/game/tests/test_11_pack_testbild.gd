extends TestCase
## 11-P1 (docs/11 §3.14, SP-19): the example pack „Testbild“ — PTD's own content, every pack function once. Base data +
## pack load clean; the renamed boss, the patched and the missing line (the required tags still hold), the new look,
## Graf Mopsula's colours through DB.party_model (art.json, never in the pack hash), data_hash ≠ the base hash with the
## element pack:testbild:<hash>, the run-log header and the save block, the refusals (a Testbild save without the pack:
## other_pack; after an overlay change: other_pack_version) — and without the pack everything as before. 11-L1 adds the
## pack's PO files: its texts in English through locale/en.po, the override of a base entry (pack PO > base PO > msgid)
## and of a German code text through locale/de.po.

const Kit := preload("res://tests/fixtures/packs/pack_kit.gd")
const ROOT: String = "user://test_11_testbild"
const BOSS: String = "enm_boss_rattenkoenigin"
const LINE_PATCHED: String = "mod_boss_intro_enm_boss_rattenkoenigin_02"
const LINE_KEPT: String = "mod_boss_intro_enm_boss_rattenkoenigin_01"
const LINE_GONE: String = "mod_chat_bark_03"

var _prev_data: GameData = null
var _lang_was: String = "de"


func before_each() -> void:
	Kit.rmrf(ROOT)
	_prev_data = DB.data
	_lang_was = Tx.lang()


func after_each() -> void:
	LocaleLoader.apply(_lang_was)                  # 11-L1: the base catalog again (no pack PO)
	Kit.rmrf(BASE_LOCALE)
	DB.data = _prev_data
	Game.state = null
	Game.run_log = null
	Game.sim = null
	Game.persona = null
	Game.mode = &"campaign"
	Kit.rmrf(ROOT)


static func _line_ids(lines: Array[ModLineDef]) -> PackedStringArray:
	var out: PackedStringArray = []
	for l: ModLineDef in lines:
		out.append(l.id)
	return out


func test_testbild_loads_clean() -> void:
	var p: PackDef = PackLoader.read(Kit.PACKS, Kit.TESTBILD)
	assert_eq(p.errors, PackedStringArray())
	var d: GameData = Kit.testbild_data()
	assert_eq(d.errors, PackedStringArray(), "base data + Testbild pass every rule (with the pack rules)")
	assert_eq([d.pack_id, d.pack_version, d.pack_hash], ["testbild", "1.0.0", p.pack_hash])
	assert_eq(PackLoader.compat(p, str(ProjectSettings.get_setting("application/config/version", ""))), "")


func test_boss_is_renamed() -> void:
	assert_eq(Kit.testbild_data().enemy(BOSS).name, "Die Testbild-Königin von Gleis 9")
	assert_eq(real_data().enemy(BOSS).name, "Die Rattenkönigin von Gleis 9", "the base data are untouched")
	var model: Dictionary = Kit.testbild_data().enemy(BOSS).model
	assert_eq(model, real_data().enemy(BOSS).model, "a patch of the name leaves the figure alone")


func test_lines_patched_and_disabled() -> void:
	var d: GameData = Kit.testbild_data()
	var base: GameData = real_data()
	assert_true(d.has_id("mod_lines", LINE_PATCHED))
	var text: String = ""
	for l: ModLineDef in d.mod_lines("boss_intro:" + BOSS):
		if l.id == LINE_PATCHED:
			text = l.text
	assert_true(text.contains("Testbild-Königin"), "the patched boss intro: " + text)
	assert_eq(_line_ids(d.mod_lines("boss_intro:" + BOSS)), PackedStringArray([LINE_KEPT, LINE_PATCHED]),
		"both intro lines stay, in file order")
	assert_false(d.has_id("mod_lines", LINE_GONE), "the disabled chat line is gone")
	assert_true(base.has_id("mod_lines", LINE_GONE))
	assert_eq(d.mod_lines("chat_bark").size(), base.mod_lines("chat_bark").size() - 1)
	assert_gt(d.mod_lines("chat_bark").size(), 0, "the tag keeps lines (required and referenced tags hold)")


func test_new_look() -> void:
	var d: GameData = Kit.testbild_data()
	var look: Dictionary = d.look("lk_outfit_testbild")
	assert_eq([look.get("kind", ""), look.get("name", "")], ["outfit", "Testbildstreifen"])
	assert_eq(look.get("colors", {}), {"primary": "#F2F2F2", "secondary": "#1A1A1A"})
	var outfits: Array[Dictionary] = d.looks_of("outfit")
	assert_eq(str(outfits[outfits.size() - 1].get("id", "")), "lk_outfit_testbild", "added at the end of its kind")
	assert_eq(outfits.size(), real_data().looks_of("outfit").size() + 1)
	assert_true(real_data().look("lk_outfit_testbild").is_empty())


func test_mopsula_colours_through_party_model() -> void:
	DB.data = Kit.testbild_data()
	var model: Dictionary = DB.party_model("mopsula")
	var base: Dictionary = real_data().party_member("mopsula").model
	assert_eq([(model["colors"] as Dictionary)["primary"], (model["colors"] as Dictionary)["secondary"]],
		["#3C6EA5", "#F2EBDD"], "art.json → DB.party_model")
	assert_eq((model["colors"] as Dictionary)["accent"], (base["colors"] as Dictionary)["accent"], "colors only")
	assert_eq([model["base"], model["props"]], [base["base"], base["props"]])
	Kit.copy_pack(Kit.PACKS, Kit.TESTBILD, ROOT)
	Kit.write_json(ROOT.path_join("testbild/art.json"), {"schema": 1, "models": {"mopsula": {"colors":
		{"primary": "#101010"}}}})
	var other: PackDef = PackLoader.read(ROOT, Kit.TESTBILD)
	assert_eq(other.pack_hash, PackLoader.read(Kit.PACKS, Kit.TESTBILD).pack_hash,
		"art.json is presentation: not in the pack hash (11 §3.7)")
	assert_eq((Kit.data_with(other).party_member("mopsula").model["colors"] as Dictionary)["primary"], "#101010")


func test_data_hash_names_the_pack() -> void:
	var base_hash: String = DB.data_hash()
	DB.data = Kit.testbild_data()
	var input: PackedStringArray = DB.data_hash_input()
	assert_eq(input[input.size() - 1], "pack:testbild:" + Kit.testbild_data().pack_hash, "the last element")
	assert_ne(DB.data_hash(), base_hash)
	assert_eq(DB.data_hash(), "|".join(input).sha256_text())
	DB.data = _prev_data
	assert_eq(DB.data_hash(), base_hash, "without the pack: the base hash again")


func test_header_and_save_block() -> void:
	DB.data = Kit.testbild_data()
	Game.new_game(0, "Kai", 4242)
	var h: Dictionary = Game.run_log.header
	assert_eq([h.get("pack", ""), h.get("pack_version", ""), h.get("pack_hash", "")],
		["testbild", "1.0.0", Kit.testbild_data().pack_hash])
	var d: Dictionary = SaveCodec.encode(Game.state, "0.3.0", DB.data.pack_record())
	assert_eq(d.get("pack", {}), {"id": "testbild", "version": "1.0.0", "hash": Kit.testbild_data().pack_hash})
	var back: GameState = SaveCodec.decode(d, DB.data)
	assert_not_null(back, "a Testbild save loads in the Testbild build: %s" % str(SaveCodec.last_errors()))


func test_refusals_without_the_pack_and_after_an_update() -> void:
	DB.data = Kit.testbild_data()
	Game.new_game(0, "Kai", 4242)
	var save: Dictionary = SaveCodec.encode(Game.state, "0.3.0", DB.data.pack_record())
	var header: Dictionary = Game.run_log.header.duplicate(true)
	assert_null(SaveCodec.decode(save, real_data()), "a Testbild save without the pack")
	assert_true(SaveCodec.last_errors()[0].begins_with(SaveCodec.MSG_OTHER_PACK), str(SaveCodec.last_errors()))
	assert_true(SaveCodec.last_errors()[0].contains("other_pack"))
	assert_eq(RunSim.version_status(header, real_data()), RunSim.OTHER_PACK, "its replay too")
	Kit.copy_pack(Kit.PACKS, Kit.TESTBILD, ROOT)
	var ov: Dictionary = Kit.read_json(ROOT.path_join("testbild/data/enemies.json"))
	((ov["patch"] as Dictionary)[BOSS] as Dictionary)["name"] = "Die Testbild-Königin (neu)"
	Kit.write_json(ROOT.path_join("testbild/data/enemies.json"), ov)
	var updated: GameData = Kit.data_with(PackLoader.read(ROOT, Kit.TESTBILD))
	assert_eq(updated.errors, PackedStringArray())
	assert_ne(updated.pack_hash, Kit.testbild_data().pack_hash)
	var st: GameState = SaveCodec.decode(save, updated)
	assert_not_null(st, "after an overlay change the save still loads (other_pack_version)")
	assert_true(Kit.has_error(SaveCodec.last_errors(), "warning: " + SaveCodec.MSG_PACK_UPDATED),
		str(SaveCodec.last_errors()))
	assert_eq(RunSim.version_status(header, updated), RunSim.OTHER_PACK_VERSION, "its replay is not replayed")
	assert_eq(updated.enemy(BOSS).name, "Die Testbild-Königin (neu)")


func test_without_the_pack_everything_is_as_before() -> void:
	var base: GameData = real_data()
	assert_eq([base.pack_id, base.pack_version, base.pack_hash], ["", "", ""])
	assert_eq([base.pack_fields(), base.pack_record()], [{}, {}])
	assert_eq(PackLoader.hash_element(base), "")
	var names: PackedStringArray = []
	for f: String in DirAccess.get_files_at("res://data"):
		if f.get_extension() == "json":
			names.append(f)
	names.sort()
	var parts: PackedStringArray = []
	for f: String in names:
		parts.append(f + ":" + FileAccess.get_sha256("res://data".path_join(f)))
	assert_eq(DB.data_hash(), "|".join(parts).sha256_text(), "data_hash: the formula of before P1, no pack element")
	assert_eq(DB.pack, null, "the test run plays the base game")
	assert_eq([DB.pack_error, DB.pack_via, DB.ok], ["", "", true])


# --- 11-L1: the pack's PO files (11 §3.6, §3.14) ----------------------------------------------------------------------

const SUBTITLE: String = "Eine Sendung des NOVA SYNDIKAT"     # the title screen's subtitle (a base entry)
const BOOT_SUB: String = "präsentiert"                         # the boot card's second line (a German code text)
const BASE_LOCALE: String = "user://test_11_testbild_locale"


## English with the pack: its three texts through locale/en.po by their table contexts (11 §1.4) and the override of the
## subtitle; German with the pack: the override of the boot card's code text; without the pack: the msgids again.
func test_english_texts_and_the_overrides_through_the_pack_po() -> void:
	var p: PackDef = PackLoader.read(Kit.PACKS, Kit.TESTBILD)
	var d: GameData = Kit.testbild_data()
	var line: String = ""
	for l: ModLineDef in d.mod_lines("boss_intro:" + BOSS):
		if l.id == LINE_PATCHED:
			line = l.text
	var look: String = str(d.look("lk_outfit_testbild").get("name", ""))
	var en: Dictionary = LocaleLoader.apply("en", LocaleLoader.pack_dir(p))
	assert_eq(en["lang"], "en")
	assert_eq((en["files"] as PackedStringArray)[(en["files"] as PackedStringArray).size() - 1],
		"res://packs/testbild/locale/en.po", "the pack PO after the four base files")
	assert_eq(Tx.data("enemies", BOSS, d.enemy(BOSS).name), "The Test Pattern Queen of Track 9", "the boss name")
	assert_eq(Tx.data("mod_lines", LINE_PATCHED, line),
		"Signal trouble on Track 9! The Test Pattern Queen has taken over the picture. Don't touch that dial!")
	assert_eq(Tx.data("looks", "lk_outfit_testbild", look), "Test Pattern")
	assert_eq(Tx.t(SUBTITLE), "A NOVA Media Group test broadcast", "the override of a base entry")
	assert_eq(Tx.t(BOOT_SUB), BOOT_SUB, "German overrides stay in de.po")
	var de: Dictionary = LocaleLoader.apply("de", LocaleLoader.pack_dir(p))
	assert_eq(de["files"], PackedStringArray(["res://packs/testbild/locale/de.po"]), "German: no base PO, the pack's")
	assert_eq(Tx.t(BOOT_SUB), "präsentiert im Testbild", "a German code text overridden (11 §3.6)")
	assert_eq(Tx.data("enemies", BOSS, d.enemy(BOSS).name), "Die Testbild-Königin von Gleis 9",
		"German shows the overlay's own text")
	LocaleLoader.apply("de")
	assert_eq([Tx.t(BOOT_SUB), Tx.t(SUBTITLE)], [BOOT_SUB, SUBTITLE], "without the pack: the msgids")


## Pack PO > base PO > msgid (11 §3.6): over a base catalog that translates the subtitle, the pack's entry wins; base
## entries the pack does not name stay.
func test_the_pack_po_wins_over_the_base_po() -> void:
	var p: PackDef = PackLoader.read(Kit.PACKS, Kit.TESTBILD)
	Kit.write_text(BASE_LOCALE.path_join("en/ui.po"), "\n".join(PackedStringArray([
		"msgid \"\"", "msgstr \"\"", "\"Language: en\\n\"", "\"Content-Type: text/plain; charset=UTF-8\\n\"",
		"\"Plural-Forms: nplurals=2; plural=(n != 1);\\n\"", "",
		PoFile.po_field("msgid", SUBTITLE), PoFile.po_field("msgstr", "A NOVA Media Group broadcast"), "",
		PoFile.po_field("msgid", BOOT_SUB), PoFile.po_field("msgstr", "presents"), ""])))
	var base: Translation = LocaleLoader.build("en", "", BASE_LOCALE)["translation"]
	var both: Translation = LocaleLoader.build("en", p.root, BASE_LOCALE)["translation"]
	assert_eq(String(base.get_message(SUBTITLE)), "A NOVA Media Group broadcast", "the base entry")
	assert_eq(String(both.get_message(SUBTITLE)), "A NOVA Media Group test broadcast", "the pack's entry wins")
	assert_eq(String(both.get_message(BOOT_SUB)), "presents", "a base entry the pack does not name stays")
	assert_eq(String(both.get_message("Die Testbild-Königin von Gleis 9", "enemies")),
		"The Test Pattern Queen of Track 9", "the pack's own texts")


## 11 §3.5 Nr. 4: the PO rules run when a pack loads (validators/pack.gd) — a pack PO that breaks them makes the pack
## invalid (DB: pack_invalid, the boot error card), like every other pack rule.
func test_a_pack_po_breaking_the_rules_fails_the_pack() -> void:
	Kit.copy_pack(Kit.PACKS, Kit.TESTBILD, ROOT)
	var path: String = ROOT.path_join("testbild/locale/en.po")
	Kit.write_text(path, FileAccess.get_file_as_string(path).replace("on Track 9!", "on Track {floor}!"))
	var d: GameData = Kit.data_with(PackLoader.read(ROOT, Kit.TESTBILD))
	assert_true(Kit.has_error(d.errors, "pack[testbild]: locale/en.po:"), str(d.errors))
	assert_true(Kit.has_error(d.errors, "{floor} is not in the msgid"), "a placeholder the msgid lacks")
	assert_true(Kit.has_error(d.errors, "digits [], the msgid has [\"9\"]"), "a number the msgid has")
	Kit.write_text(ROOT.path_join("testbild/locale/de.po"),
		FileAccess.get_file_as_string(Kit.PACKS.path_join("testbild/locale/de.po")).replace("Language: de", "Language: en"))
	var d2: GameData = Kit.data_with(PackLoader.read(ROOT, Kit.TESTBILD))
	assert_true(Kit.has_error(d2.errors, "header Language 'en', the file is locale/de.po"), str(d2.errors))
	assert_eq(Kit.testbild_data().errors, PackedStringArray(), "the real Testbild keeps every rule")
