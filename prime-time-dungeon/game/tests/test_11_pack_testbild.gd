extends TestCase
## 11-P1 (docs/11 §3.14, SP-19): the example pack „Testbild“ — PTD's own content, every pack function once. Base data +
## pack load clean; the renamed boss, the patched and the missing line (the required tags still hold), the new look,
## Graf Mopsula's colours through DB.party_model (art.json, never in the pack hash), data_hash ≠ the base hash with the
## element pack:testbild:<hash>, the run-log header and the save block, the refusals (a Testbild save without the pack:
## other_pack; after an overlay change: other_pack_version) — and without the pack everything as before. The parts with
## the pack's PO files (English boss name, the overrides) come with 11-L1.

const Kit := preload("res://tests/fixtures/packs/pack_kit.gd")
const ROOT: String = "user://test_11_testbild"
const BOSS: String = "enm_boss_rattenkoenigin"
const LINE_PATCHED: String = "mod_boss_intro_enm_boss_rattenkoenigin_02"
const LINE_KEPT: String = "mod_boss_intro_enm_boss_rattenkoenigin_01"
const LINE_GONE: String = "mod_chat_bark_03"

var _prev_data: GameData = null


func before_each() -> void:
	Kit.rmrf(ROOT)
	_prev_data = DB.data


func after_each() -> void:
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
