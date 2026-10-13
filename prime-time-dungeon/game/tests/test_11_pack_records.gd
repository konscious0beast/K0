extends TestCase
## 11-P1 (docs/11 §3.8–§3.9, Kap. 5.10): what a content pack writes into the records and how the records of another
## pack are refused. data_hash (the formula of before without a pack, "pack:<id>:<hash>" at its end with one), the
## run-log headers of Game and Save (pack, pack_version, pack_hash only with a pack — key sets and digests without one
## as before), the leaderboard entry, the save block "pack" (SaveCodec.VERSION stays 2), every refusal: other_pack
## (saves, replays, board entries — also the base game against a pack), other_pack_version, the start codes
## pack_engine / pack_invalid / pack_ambiguous / pack_missing with the boot error card, the pack check before
## _sanitize, the slot that names the pack (no backup fallback), and the user data per pack (--pack).

const Kit := preload("res://tests/fixtures/packs/pack_kit.gd")
const BootScript := preload("res://scenes/boot/boot.gd")
const SaveScript := preload("res://autoload/save.gd")
const SlotSelect := preload("res://scenes/title/slot_select.gd")
const ROOT: String = "user://test_11_records"
const SAVES: String = "user://test_11_records/saves"
const EVENT_ID: String = "evt_offline_gleis9"
## The run-log header of a new game (Game._make_run_log + _rt_begin) — before P1 and still without a pack.
const HEADER_KEYS: PackedStringArray = ["schema", "seed", "slot", "mode", "difficulty", "game_version", "sim_hz",
	"sim_version", "event_id", "run_id", "player_id", "window_id", "league", "combat_mode", "rt_version"]
## The header of the log after a load (Save._make_run_log).
const SAVE_HEADER_KEYS: PackedStringArray = ["schema", "seed", "slot", "mode", "difficulty", "game_version", "sim_hz",
	"sim_version", "event_id", "run_id", "player_id", "from_save", "combat_mode", "rt_version"]
## The leaderboard entry of an event run (Game.finish_run, 05 §10.4).
const ENTRY_KEYS: PackedStringArray = ["schema", "event_id", "window_id", "league", "mode", "run_id", "players",
	"score", "breakdown", "quest_complete", "floor_timer_left_sec", "run_wall_ms", "flags", "difficulty", "replay_id",
	"run_log_hash", "data_hash", "sim_version", "client_version", "verified", "finished_at"]
const SAVE_KEYS: PackedStringArray = ["format", "version", "game_version", "saved_at_unix", "summary", "state"]
const PACK_FIELDS: PackedStringArray = ["pack", "pack_version", "pack_hash"]
const CODES: PackedStringArray = ["pack_ambiguous", "pack_missing", "pack_engine", "pack_invalid"]

var _prev_data: GameData = null


func before_each() -> void:
	Kit.rmrf(ROOT)
	_prev_data = DB.data
	Save.save_dir = SAVES
	Save.read_only = false


func after_each() -> void:
	DB.data = _prev_data
	DB.pack = null
	DB.pack_via = ""
	DB.pack_error = ""
	DB.pack_messages = PackedStringArray()
	if Game.combat != null:
		Game.end_combat()
	Game.state = null
	Game.run_log = null
	Game.sim = null
	Game.quest = null
	Game.persona = null
	Game.mode = &"campaign"
	Game.timer_running = false
	Game.in_battle = false
	Game.safe_room_clock = false
	Save.save_dir = "user://saves"
	Save.read_only = false
	Kit.rmrf(ROOT)


static func _keys(d: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	for k: Variant in d.keys():
		out.append(str(k))
	out.sort()
	return out


static func _sorted(a: PackedStringArray, b: PackedStringArray = PackedStringArray()) -> PackedStringArray:
	var out: PackedStringArray = a.duplicate()
	out.append_array(b)
	out.sort()
	return out


## Every Label text below `n`.
static func _texts(n: Node) -> PackedStringArray:
	var out: PackedStringArray = []
	if n is Label:
		out.append((n as Label).text)
	for c: Node in n.get_children():
		out.append_array(_texts(c))
	return out


static func _has_text(texts: PackedStringArray, needle: String) -> bool:
	for t: String in texts:
		if t.contains(needle):
			return true
	return false


## A Testbild copy in ROOT/packs whose boss has another name: the same pack id, another pack_hash.
func _updated_testbild() -> GameData:
	Kit.copy_pack(Kit.PACKS, Kit.TESTBILD, ROOT.path_join("packs"))
	var path: String = ROOT.path_join("packs/testbild/data/enemies.json")
	var ov: Dictionary = Kit.read_json(path)
	((ov["patch"] as Dictionary)["enm_boss_rattenkoenigin"] as Dictionary)["name"] = "Die Testbild-Königin, Folge 2"
	Kit.write_json(path, ov)
	var d: GameData = Kit.data_with(PackLoader.read(ROOT.path_join("packs"), Kit.TESTBILD))
	assert_eq(d.errors, PackedStringArray())
	return d


# --- data_hash -------------------------------------------------------------------------------------------------------------

func test_data_hash_without_and_with_a_pack() -> void:
	var names: PackedStringArray = []
	for f: String in DirAccess.get_files_at("res://data"):
		if f.get_extension() == "json":
			names.append(f)
	names.sort()
	var parts: PackedStringArray = []
	for f: String in names:
		parts.append(f + ":" + FileAccess.get_sha256("res://data".path_join(f)))
	var before_p1: String = "|".join(parts).sha256_text()
	assert_eq(DB.data_hash(), before_p1, "without a pack: exactly the data_hash of before P1")
	assert_eq(DB.data_hash_input(), parts)
	DB.data = Kit.testbild_data()
	var input: PackedStringArray = DB.data_hash_input()
	assert_eq(input.slice(0, parts.size()), parts, "the same list of files …")
	assert_eq(input.slice(parts.size()), PackedStringArray(["pack:testbild:" + Kit.testbild_data().pack_hash]),
		"… plus one element pack:<id>:<pack_hash>")
	var with_pack: String = DB.data_hash()
	assert_ne(with_pack, before_p1)
	DB.data = _updated_testbild()
	assert_ne(DB.data_hash(), with_pack, "another pack version, another data_hash (separate leaderboards)")
	DB.data = _prev_data
	assert_eq(DB.data_hash(), before_p1)


# --- headers and digests ---------------------------------------------------------------------------------------------------

func test_run_log_headers_carry_the_pack_only_with_a_pack() -> void:
	Game.new_game(0, "Kai", 4242)
	var base_h: Dictionary = Game.run_log.header.duplicate(true)
	assert_eq(_keys(base_h), _sorted(HEADER_KEYS), "the header of before — no pack key without a pack")
	var base_st: GameState = Game.state
	assert_eq(_keys(Save._make_run_log(base_st).header), _sorted(SAVE_HEADER_KEYS), "Save's header too")
	DB.data = Kit.testbild_data()
	Game.new_game(0, "Kai", 4242)
	var pack_h: Dictionary = Game.run_log.header.duplicate(true)
	assert_eq(_keys(pack_h), _sorted(HEADER_KEYS, PACK_FIELDS))
	assert_eq([pack_h["pack"], pack_h["pack_version"], pack_h["pack_hash"]],
		["testbild", "1.0.0", Kit.testbild_data().pack_hash])
	var save_h: Dictionary = Save._make_run_log(Game.state).header
	assert_eq(_keys(save_h), _sorted(SAVE_HEADER_KEYS, PACK_FIELDS))
	assert_eq(save_h["pack_hash"], Kit.testbild_data().pack_hash)
	for k: String in PACK_FIELDS:
		pack_h.erase(k)
	pack_h["run_id"] = base_h["run_id"]                  # unique per attempt by design (05 §10.4)
	assert_eq(pack_h, base_h, "the pack fields are the only difference")
	var a: RunLog = RunLog.new()
	a.header = base_h
	var b: RunLog = RunLog.new()
	b.header = pack_h
	assert_eq(a.digest(), b.digest(), "without the pack fields: the same digest")


func test_leaderboard_entry() -> void:
	Game.start_event_run(EVENT_ID)
	var e: Dictionary = (Game.finish_run(&"timer") as Dictionary).get("entry", {})
	assert_eq(_keys(e), _sorted(ENTRY_KEYS), "the entry of before — no pack key without a pack")
	DB.data = Kit.testbild_data()
	Game.start_event_run(EVENT_ID)
	var e2: Dictionary = (Game.finish_run(&"timer") as Dictionary).get("entry", {})
	assert_eq(_keys(e2), _sorted(ENTRY_KEYS, PACK_FIELDS))
	assert_eq([e2["pack"], e2["pack_version"], e2["pack_hash"]], ["testbild", "1.0.0", Kit.testbild_data().pack_hash])
	assert_eq(e2["data_hash"], DB.data_hash(), "the data_hash with the pack element")
	assert_ne(e2["data_hash"], e["data_hash"])
	var tb: GameData = Kit.testbild_data()
	var base: GameData = real_data()
	assert_eq([Leaderboard.version_status(e2, tb), Leaderboard.version_status(e2, base)], ["", RunSim.OTHER_PACK],
		"an entry of the pack: its own build shows it, the base game hides it")
	assert_eq([Leaderboard.version_status(e, base), Leaderboard.version_status(e, tb)], ["", RunSim.OTHER_PACK],
		"a base entry in the pack build: other_pack too")
	var older: Dictionary = e2.duplicate(true)
	older["pack_hash"] = "0".repeat(64)
	assert_eq(Leaderboard.version_status(older, tb), RunSim.OTHER_PACK_VERSION, "tagged like an older version")
	assert_eq([Leaderboard.version_status(e2), Leaderboard.version_status(older)], ["", ""],
		"without the build's data: the check of before (sim_version only)")


# --- the save block --------------------------------------------------------------------------------------------------------

func test_save_block_only_with_a_pack() -> void:
	var st: GameState = GameState.create_new(real_data(), 1, "Kai", 99)
	assert_eq(_keys(SaveCodec.encode(st, "0.3.0")), _sorted(SAVE_KEYS), "the save of before")
	assert_eq(_keys(SaveCodec.encode(st, "0.3.0", real_data().pack_record())), _sorted(SAVE_KEYS))
	var d: Dictionary = SaveCodec.encode(st, "0.3.0", Kit.testbild_data().pack_record())
	assert_eq(_keys(d), _sorted(SAVE_KEYS, PackedStringArray(["pack"])))
	assert_eq(d["pack"], {"id": "testbild", "version": "1.0.0", "hash": Kit.testbild_data().pack_hash})
	assert_eq(d["version"], 2, "SaveCodec.VERSION stays 2")
	var back: GameState = SaveCodec.decode(d, Kit.testbild_data())
	assert_not_null(back)
	assert_eq(SaveCodec.last_errors(), PackedStringArray(), "the own pack: no hint")
	assert_eq(SaveCodec.encode(back, "0.3.0", Kit.testbild_data().pack_record()), d, "round trip")


func test_save_refusals() -> void:
	var st: GameState = GameState.create_new(real_data(), 1, "Kai", 99)
	var base_save: Dictionary = SaveCodec.encode(st, "0.3.0")
	var pack_save: Dictionary = SaveCodec.encode(st, "0.3.0", Kit.testbild_data().pack_record())
	var tb: GameData = Kit.testbild_data()
	var base: GameData = real_data()
	assert_eq([SaveCodec.pack_status(base_save, base), SaveCodec.pack_status(pack_save, tb)], ["", ""])
	assert_eq([SaveCodec.pack_status(pack_save, base), SaveCodec.pack_status(base_save, tb)],
		[SaveCodec.OTHER_PACK, SaveCodec.OTHER_PACK], "a pack save in the base game and the other way round")
	var junk: Dictionary = base_save.duplicate(true)
	junk["pack"] = "testbild"
	assert_eq([SaveCodec.pack_status(junk, tb), SaveCodec.pack_id_of(junk)], [SaveCodec.OTHER_PACK, "?"],
		"a block that is no object")
	assert_null(SaveCodec.decode(pack_save, base))
	assert_eq(SaveCodec.last_errors(), PackedStringArray(["%s (other_pack: 'testbild', this build plays '')"
		% SaveCodec.MSG_OTHER_PACK]))
	assert_null(SaveCodec.decode(base_save, tb))
	assert_true(SaveCodec.last_errors()[0].contains("other_pack: '', this build plays 'testbild'"))
	var older: Dictionary = pack_save.duplicate(true)
	(older["pack"] as Dictionary)["hash"] = "0".repeat(64)
	assert_eq(SaveCodec.pack_status(older, tb), SaveCodec.OTHER_PACK_VERSION)
	assert_not_null(SaveCodec.decode(older, tb), "other_pack_version loads like a save after a game update")
	assert_true(Kit.has_error(SaveCodec.last_errors(), "warning: %s (other_pack_version" % SaveCodec.MSG_PACK_UPDATED))
	var newer: Dictionary = pack_save.duplicate(true)
	newer["version"] = SaveCodec.VERSION + 1
	assert_null(SaveCodec.decode(newer, base))
	assert_true(SaveCodec.last_errors()[0].begins_with(SaveCodec.MSG_NEWER), "the version header is read first")


## 11 §3.9: _sanitize drops unknown ids silently — a pack save loaded without its pack would lose its content quietly.
## The pack check runs first and refuses it.
func test_pack_check_runs_before_sanitize() -> void:
	var st: GameState = GameState.create_new(real_data(), 1, "Kai", 99)
	st.inventory.counts["itm_nur_im_paket"] = 2
	var pack_save: Dictionary = SaveCodec.encode(st, "0.3.0", {"id": "fremd", "version": "1.0.0",
		"hash": "ab".repeat(32)})
	assert_null(SaveCodec.decode(pack_save, real_data()), "refused …")
	assert_false(Kit.has_error(SaveCodec.last_errors(), "dropped"), "… before anything was sanitized away")
	var plain: Dictionary = pack_save.duplicate(true)
	plain.erase("pack")
	var loaded: GameState = SaveCodec.decode(plain, real_data())
	assert_not_null(loaded)
	assert_true(Kit.has_error(SaveCodec.last_errors(), "warning: item 'itm_nur_im_paket' dropped (unknown)"),
		"what _sanitize would have done without the check")
	assert_false(loaded.inventory.counts.has("itm_nur_im_paket"))


func test_slot_of_another_pack_is_refused_and_named() -> void:
	DB.data = Kit.testbild_data()
	Game.new_game(1, "Kai", 77)
	assert_eq(Save.save_slot(1), OK)
	assert_eq((Kit.read_json(Save.slot_path(1)).get("pack", {}) as Dictionary).get("id", ""), "testbild")
	var base_st: GameState = GameState.create_new(real_data(), 1, "Kai", 77)
	Kit.write_json(Save.slot_path(1) + ".bak", SaveCodec.encode(base_st, "0.3.0"))   # a loadable base backup
	DB.data = _prev_data
	Game.state = null
	assert_eq(Save.load_slot(1), ERR_FILE_UNRECOGNIZED, "refused like a newer save — no backup fallback")
	assert_true(Save.last_error().begins_with(SaveCodec.MSG_OTHER_PACK), Save.last_error())
	assert_null(Game.state, "nothing was loaded")
	var info: Dictionary = Save.slot_summary(1)
	assert_eq([info.get("corrupt", false), info.get("refusal", ""), info.get("pack", "")],
		[true, "other_pack", "testbild"], "the slot names the pack")
	assert_eq(Save.newest_slot(), 0, "never offered as „Fortsetzen“")
	var sel: Control = SlotSelect.new()
	sel.mode = "load"
	var card: Button = sel.call("_slot_card", 1)
	var texts: PackedStringArray = _texts(card)
	assert_true(_has_text(texts, "Spielstand eines anderen Inhaltspakets"), str(texts))
	assert_true(_has_text(texts, "Paket „testbild“"), str(texts))
	assert_true(card.disabled, "not loadable")
	card.free()
	sel.free()
	DB.data = Kit.testbild_data()
	assert_eq(Save.load_slot(1), OK, "in the Testbild build the slot loads")
	assert_eq(Game.run_log.header.get("pack", ""), "testbild", "the log after the load names the pack")


# --- replays -----------------------------------------------------------------------------------------------------------------

func test_replay_refusals() -> void:
	DB.data = Kit.testbild_data()
	Game.new_game(0, "Kai", 4242)
	var pack_log: RunLog = RunLog.from_dict(Game.run_log.to_dict())
	DB.data = _prev_data
	Game.new_game(0, "Kai", 4242)
	var base_log: RunLog = RunLog.from_dict(Game.run_log.to_dict())
	var tb: GameData = Kit.testbild_data()
	var base: GameData = real_data()
	var res: Dictionary = RunSim.replay(base, pack_log)
	assert_eq(res["version"], RunSim.OTHER_PACK, "a pack log is never replayed by the base game")
	assert_true(str((res["errors"] as PackedStringArray)[0]).begins_with("header: other_pack — content pack "
		+ "'testbild' 1.0.0, this build plays ''"), str(res["errors"]))
	assert_eq(RunSim.replay(tb, base_log)["version"], RunSim.OTHER_PACK, "nor a base log by the pack build")
	assert_eq(RunSim.replay(tb, pack_log)["version"], "", "its own build replays it")
	assert_eq(Game.replay_log(pack_log)["version"], RunSim.OTHER_PACK, "Game.replay_log against DB.data")
	DB.data = tb
	assert_eq(Game.replay_log(pack_log)["version"], "")
	var h2: Dictionary = pack_log.header.duplicate(true)
	h2["pack_hash"] = "0".repeat(64)
	assert_eq(RunSim.version_status(h2, tb), RunSim.OTHER_PACK_VERSION)
	assert_true(RunSim.version_error(h2, tb).begins_with("header: other_pack_version"))
	var cat: EventCatalog = EventCatalog.new()
	cat.load_file("res://data/events.json")
	var def: EventDef = cat.get_event(EVENT_ID)
	assert_true(Kit.has_error(RunSim.header_errors(pack_log.header, def, def.rules, base), "header: other_pack"))
	assert_false(Kit.has_error(RunSim.header_errors(pack_log.header, def, def.rules), "other_pack"),
		"without the build's data: the checks of before")
	var old: Dictionary = {"sim_version": RunSim.SIM_VERSION - 1}
	assert_eq([RunSim.version_status(old), RunSim.version_status(old, base)], [RunSim.OLD_VERSION, RunSim.OLD_VERSION])
	old["pack"] = "testbild"
	assert_eq(RunSim.version_status(old, base), RunSim.OTHER_PACK, "the pack is checked first")
	assert_eq(RunSim.pack_status({}, base), "")
	assert_eq(RunSim.pack_status({"pack": "testbild", "pack_hash": tb.pack_hash}, tb), "")


# --- start codes and the boot error card -----------------------------------------------------------------------------

func test_boot_error_card_for_every_code() -> void:
	var msgs: PackedStringArray = []
	for i in 7:
		msgs.append("Meldung %d (res://packs/probe)" % (i + 1))
	for code: String in CODES:
		DB.pack_error = code
		DB.pack_messages = msgs
		var boot: Node = BootScript.new()
		assert_true(bool(boot.call("_pack_error_card")), code)
		var card: Node = boot.get_node_or_null("PackErrorCard")
		assert_not_null(card, code)
		var texts: PackedStringArray = _texts(boot)
		assert_true(_has_text(texts, "INHALTSPAKET FEHLERHAFT"), code)
		assert_true(_has_text(texts, "(%s)" % code), code)
		for i in 5:
			assert_true(_has_text(texts, "Meldung %d" % (i + 1)), "%s: line %d" % [code, i + 1])
		assert_false(_has_text(texts, "Meldung 6"), "%s: only the first five" % code)
		assert_true(_has_text(texts, "und 2 weitere Meldungen"), code)
		assert_true(_has_text(texts, "Das Spiel startet nicht mit den Grunddaten."), code)
		boot.free()
	DB.pack_error = ""
	DB.pack_messages = PackedStringArray()
	var ok: Node = BootScript.new()
	assert_false(bool(ok.call("_pack_error_card")), "no pack error: the boot routes as before")
	assert_null(ok.get_node_or_null("PackErrorCard"))
	ok.free()
	assert_eq([DB.pack_error, DB.ok], ["", true], "this test run started without a pack error")


# --- user data per pack ----------------------------------------------------------------------------------------------------

func test_user_data_per_pack() -> void:
	var fresh: Node = SaveScript.new()
	assert_eq(fresh.get("save_dir"), "user://saves", "the base game keeps user://saves")
	fresh.free()
	DB.pack = PackLoader.read(Kit.PACKS, Kit.TESTBILD)
	DB.pack_via = "feature"
	fresh = SaveScript.new()
	assert_eq(fresh.get("save_dir"), "user://saves", "a pack export has a user folder of its own")
	fresh.free()
	DB.pack_via = "arg"
	fresh = SaveScript.new()
	assert_eq(fresh.get("save_dir"), "user://packs/testbild/saves", "a debug run with --pack=testbild")
	fresh.free()
	Save.save_dir = "user://packs/testbild/saves"
	for p: String in [Save.slot_path(1), Save.journal_path(1), Save.career_path(), Save.persona_path(1),
			Save.sd_collection_path(), Save._leaderboard_path("evt_x"), Save._data_root().path_join(Save.REPLAY_DIR)]:
		assert_true(p.begins_with("user://packs/testbild/"), p)
