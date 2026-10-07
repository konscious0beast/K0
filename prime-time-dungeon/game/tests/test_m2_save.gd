extends TestCase
## M2 save (02_TECH §3.6/§6.4): SaveCodec round trip (encode → decode → encode identical), v0 migration stub,
## newer versions refused, validation, sanitizing unknown ids; Save slots (atomic write, .bak fallback for broken files,
## grace time 180 s, summaries, newest slot, delete, read_only, autosave, record_game_over) and the local
## leaderboard / replay files (05 CR-8). All files go to user://test_m2 (save_dir redirected), removed afterwards.

const Fx := preload("res://tests/test_m2_fixtures.gd")
const ROOT: String = "user://test_m2"
const DIR: String = "user://test_m2/saves"

var _prev_data: GameData = null


func before_each() -> void:
	_rmrf(ROOT)
	Save.save_dir = DIR
	Save.read_only = false


func after_each() -> void:
	if _prev_data != null:
		Fx.end_world(_prev_data)
		_prev_data = null
	Save.save_dir = "user://saves"
	Save.read_only = false
	_rmrf(ROOT)


static func _rmrf(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for f: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	for sub: String in DirAccess.get_directories_at(path):
		_rmrf(path.path_join(sub))
	DirAccess.remove_absolute(path)


static func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


static func _read(path: String) -> Dictionary:
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return v if v is Dictionary else {}


## A state with progress in every section.
func _rich_state() -> GameState:
	var d: GameData = Fx.data()
	var st: GameState = GameState.create_new(d, 1, "Kai", 123456)
	st.floor_run = FloorRun.create(d.floor_def(1), st.seed, st.difficulty)
	Progression.add_exp(st.member("kai"), 100, d)
	st.inventory.add("itm_wpn_axe")
	Progression.equip(st.member("kai"), st.inventory, d, "weapon", "itm_wpn_axe")
	st.inventory.credits = 140
	st.play_time_sec = 812.5
	st.rng_counter = 41
	st.pity_rare = 2
	st.pity_epic = 5
	st.pending_lootboxes = PackedStringArray(["box_bronze"])
	st.bestiary = {"enm_rat": {"defeated": 4, "weak_known": PackedStringArray(["fire"])}}
	var fr: FloorRun = st.floor_run
	fr.time_left_ticks = 22026
	fr.timer_started = true
	fr.warned = PackedInt32Array([600])
	fr.decay_ticks = 40
	fr.visited = [Vector2i(3, 7), Vector2i(3, 6)]
	fr.opened_chests = PackedStringArray(["f1_c0"])
	fr.defeated_groups = PackedStringArray(["f1_g0"])
	fr.completed_events = PackedStringArray(["fev_photo_drone"])
	fr.event_uses = {"fev_wheel": 2}
	fr.strays = {"f1_s0": {"zone": "zone_platform", "enc": "enc_f1_a"}}
	fr.spawner_ticks = {"zone_platform": 812}
	fr.location = &"sr_kiosk"
	fr.visited_safe_rooms = PackedStringArray(["sr_kiosk"])
	fr.safe_room_visits = 1
	fr.stats = {"time_used_ticks": 13974, "kills": 6, "viewers_peak": 2210, "followers_gained": 420, "achievements": 4}
	st.show.followers = 420
	st.show.hype = 35.0
	st.show.viewers = 1800
	st.show.stats = {"kills_total": 6, "viewers_max": 2210}
	st.show.achievements = PackedStringArray(["ach_first_blood"])
	st.show.milestones = PackedStringArray(["ms_100", "ms_250"])
	st.show.sponsor_uses = {"spn_heal": 1}
	st.flags = {"intro_seen": true, "scene_scn_mop_1": true, "live": {"gift_ids": ["g_x"]}}
	return st


# --- SaveCodec --------------------------------------------------------------------------------------------------------

func test_codec_round_trip_identical() -> void:
	var st: GameState = _rich_state()
	var d1: Dictionary = SaveCodec.encode(st, "0.1.0")
	assert_eq([d1["format"], d1["version"], d1["game_version"], d1["saved_at_unix"]], ["ptd_save", 1, "0.1.0", 0])
	var parsed: Variant = JSON.parse_string(JSON.stringify(d1, "\t"))
	var back: GameState = SaveCodec.decode(parsed, Fx.data())
	assert_not_null(back, "; ".join(SaveCodec.last_errors()))
	assert_eq(SaveCodec.last_errors(), PackedStringArray(), "no warnings for a clean save")
	var d2: Dictionary = SaveCodec.encode(back, "0.1.0")
	assert_eq(d2, d1, "encode → JSON → decode → encode is identical")
	assert_eq(back.member("kai").equipment["weapon"], "itm_wpn_axe")
	assert_eq(back.floor_run.visited, [Vector2i(3, 7), Vector2i(3, 6)])
	assert_eq(back.floor_run.location, &"sr_kiosk")
	assert_eq(back.flags["live"], {"gift_ids": ["g_x"]})


func test_codec_summary() -> void:
	var st: GameState = _rich_state()
	assert_eq(SaveCodec.summary(st), {"player_name": "Kai", "floor_index": 1, "level": 3, "play_time_sec": 812,
		"followers": 420, "location": "sr_kiosk"})
	assert_eq(SaveCodec.summary(null), {})


func test_codec_v0_migration_stub() -> void:
	var v0: Dictionary = {"state": {"slot": 1, "seed": 99, "player_name": "Kai",
		"party": [{"id": "kai", "level": 2, "hp": 50, "mp": 3}, {"id": "mopsula", "hp": 40, "mp": 20}],
		"inventory": {"credits": 12, "counts": {"itm_bandage": 2}},
		"floor_run": {"floor_id": "floor_1", "index": 1, "seed": 7, "time_left": 100.5, "stats": {"time_used": 10.0}}}}
	var m: Dictionary = SaveCodec.migrate(v0)
	assert_eq([m["format"], m["version"]], ["ptd_save", 1])
	assert_eq(m["state"]["floor_run"]["time_left_ticks"], 3015, "seconds → whole ticks (05 CR-3)")
	assert_eq(m["state"]["floor_run"]["stats"]["time_used_ticks"], 300)
	assert_false((m["state"]["floor_run"] as Dictionary).has("time_left"))
	assert_false(v0["state"]["floor_run"].has("time_left_ticks"), "input not modified")
	var st: GameState = SaveCodec.decode(v0, Fx.data())
	assert_not_null(st, "; ".join(SaveCodec.last_errors()))
	assert_eq(st.floor_run.loot_seed, SeedUtil.derive(99, "loot", 1), "loot_seed derived from the run seed")
	assert_eq(st.show.hype, 30.0, "missing fields → defaults")
	assert_eq(st.member("kai").level, 2)
	var v1: Dictionary = SaveCodec.encode(_rich_state(), "x")
	assert_eq(SaveCodec.migrate(v1), v1, "current version passes unchanged")


func test_codec_refuses_newer_and_invalid_saves() -> void:
	var d: GameData = Fx.data()
	var newer: Dictionary = SaveCodec.encode(_rich_state(), "9.9.9")
	newer["version"] = 2
	assert_eq(SaveCodec.migrate(newer), {}, "unknown higher version → {}")
	assert_null(SaveCodec.decode(newer, d))
	assert_true(SaveCodec.last_errors()[0].begins_with("Spielstand stammt aus neuerer Version"))
	assert_null(SaveCodec.decode({}, d))
	var bad: Dictionary = SaveCodec.encode(_rich_state(), "x")
	bad["format"] = "other"
	assert_has(SaveCodec.validate(bad, d)[0], "format")
	var no_state: Dictionary = {"format": "ptd_save", "version": 1}
	assert_has(SaveCodec.validate(no_state, d)[0], "state")
	assert_null(SaveCodec.decode(no_state, d))
	var no_party: Dictionary = SaveCodec.encode(_rich_state(), "x")
	no_party["state"]["party"] = [{"id": "stranger"}]
	assert_null(SaveCodec.decode(no_party, d), "no known party member")
	var bad_floor: Dictionary = SaveCodec.encode(_rich_state(), "x")
	bad_floor["state"]["floor_run"]["floor_id"] = "floor_99"
	assert_null(SaveCodec.decode(bad_floor, d), "unknown floor is fatal")
	var bad_version: Dictionary = SaveCodec.encode(_rich_state(), "x")
	bad_version["version"] = "eins"
	assert_null(SaveCodec.decode(bad_version, d))


func test_codec_drops_unknown_ids_with_warnings() -> void:
	var d: Dictionary = SaveCodec.encode(_rich_state(), "x")
	var st: Dictionary = d["state"]
	st["party"].append({"id": "stranger", "level": 3})
	st["party"][0]["skills"].append("skl_removed")
	st["party"][0]["equipment"]["armor"] = "itm_wpn_mop"
	st["party"][0]["hp"] = 9999
	st["inventory"]["counts"]["itm_removed"] = 3
	st["inventory"]["counts"]["itm_bandage"] = 50
	st["pending_lootboxes"].append("box_removed")
	st["bestiary"]["enm_removed"] = {"defeated": 1, "weak_known": []}
	st["show"]["achievements"].append("ach_removed")
	st["show"]["stats"]["stat_removed"] = 5
	var gs: GameState = SaveCodec.decode(d, Fx.data())
	assert_not_null(gs, "unknown ids are not fatal")
	var warnings: PackedStringArray = SaveCodec.last_errors()
	assert_eq(warnings.size(), 8, "\n".join(warnings))
	for w: String in warnings:
		assert_true(w.begins_with("warning: "), w)
	assert_eq(gs.party.size(), 2)
	assert_false(gs.member("kai").skills.has("skl_removed"))
	assert_eq(gs.member("kai").equipment["armor"], "", "wrong slot dropped")
	assert_eq(gs.member("kai").hp, Progression.total_stats(gs.member("kai"), Fx.data()).values[0], "hp clamped")
	assert_false(gs.inventory.counts.has("itm_removed"))
	assert_eq(gs.inventory.count("itm_bandage"), 9, "clamped to max_stack")
	assert_eq(gs.pending_lootboxes, PackedStringArray(["box_bronze"]))
	assert_false(gs.bestiary.has("enm_removed"))
	assert_eq(gs.show.achievements, PackedStringArray(["ach_first_blood"]))
	assert_false(gs.show.stats.has("stat_removed"))


# --- Save slots -------------------------------------------------------------------------------------------------------

func test_save_and_load_slot_with_grace_time() -> void:
	_prev_data = Fx.begin_world(4242, 1)
	var saved: Array = []
	var loaded: Array = []
	var cb_s: Callable = func(slot: int, ok: bool) -> void: saved.append([slot, ok])
	var cb_l: Callable = func(slot: int) -> void: loaded.append(slot)
	Events.game_saved.connect(cb_s)
	Events.game_loaded.connect(cb_l)
	var live: GameState = Game.state
	live.inventory.credits = 777
	live.floor_run.time_left_ticks = 100
	live.floor_run.location = &"sr_kiosk"
	Show.add_followers(42)
	assert_eq(Save.save_slot(1), OK, Save.last_error())
	assert_eq(saved, [[1, true]])
	assert_true(FileAccess.file_exists(DIR + "/slot_1.json"))
	assert_false(FileAccess.file_exists(DIR + "/slot_1.json.tmp"), "tmp renamed")
	var file: Dictionary = _read(DIR + "/slot_1.json")
	assert_gt(int(file["saved_at_unix"]), 1_700_000_000, "Save stamps the time")
	live.inventory.credits = 0
	assert_eq(Save.load_slot(1), OK, Save.last_error())
	assert_eq(loaded, [1])
	assert_false(Game.state == live, "a new GameState")
	assert_eq(Game.state.inventory.credits, 777)
	assert_eq(Game.state.floor_run.time_left_ticks, 180 * 30, "grace: at least 3:00 left after loading")
	assert_eq(Game.state.floor_run.location, &"sr_kiosk")
	assert_eq(Show.followers(), 42)
	assert_eq(Game.run_log.header.get("from_save", false), true, "new run log marked from_save")
	assert_eq(Game.run_log.header.get("seed", 0), 4242)
	assert_not_null(Game.sim)
	assert_eq([Game.mode, Game.in_battle], [&"campaign", false])
	Game.state.floor_run.time_left_ticks = 9000
	Save.save_slot(1)
	Save.load_slot(1)
	assert_eq(Game.state.floor_run.time_left_ticks, 9000, "more than 3:00 stays untouched")
	Events.game_saved.disconnect(cb_s)
	Events.game_loaded.disconnect(cb_l)


func test_broken_slot_file_falls_back_to_bak() -> void:
	_prev_data = Fx.begin_world(1, 1)
	Game.state.inventory.credits = 1
	Save.save_slot(1)
	Game.state.inventory.credits = 2
	Save.save_slot(1)
	assert_eq(_read(DIR + "/slot_1.json.bak")["state"]["inventory"]["credits"], 1, "previous file kept as .bak")
	_write(DIR + "/slot_1.json", "{\"format\": \"ptd_save\", \"version\": 1, \"sta")
	assert_eq(Save.load_slot(1), OK, "parse error → .bak")
	assert_eq(Game.state.inventory.credits, 1)
	assert_false(bool(Save.slot_summary(1).get("corrupt", false)))
	_write(DIR + "/slot_1.json", "{\"format\": \"ptd_save\", \"version\": 1}")
	assert_eq(Save.load_slot(1), OK, "structurally invalid → .bak")
	_write(DIR + "/slot_1.json.bak", "kaputt")
	assert_eq(Save.load_slot(1), ERR_FILE_CORRUPT)
	assert_ne(Save.last_error(), "")
	assert_eq(Save.slot_summary(1).get("corrupt", false), true)
	var newer: Dictionary = SaveCodec.encode(Game.state, "9")
	newer["version"] = 7
	_write(DIR + "/slot_1.json", JSON.stringify(newer))
	assert_eq(Save.load_slot(1), ERR_FILE_UNRECOGNIZED, "newer version: refused, no fallback")
	assert_true(Save.last_error().begins_with("Spielstand stammt aus neuerer Version"))


func test_slots_summary_newest_and_delete() -> void:
	assert_eq([Save.has_save(1), Save.slot_summary(1), Save.newest_slot()], [false, {}, 0])
	assert_eq(Save.slot_path(2), DIR + "/slot_2.json")
	_prev_data = Fx.begin_world(8, 1)
	assert_eq(Save.save_slot(0), OK, "slot 0 is never written")
	assert_false(FileAccess.file_exists(DIR + "/slot_0.json"))
	assert_eq(Save.save_slot(4), ERR_INVALID_PARAMETER)
	assert_eq(Save.load_slot(0), ERR_INVALID_PARAMETER)
	assert_eq(Save.load_slot(3), ERR_FILE_NOT_FOUND)
	Save.save_slot(1)
	Save.save_slot(2)
	var s: Dictionary = Save.slot_summary(2)
	var keys: Array = s.keys()
	keys.sort()
	assert_eq(keys, ["floor_index", "followers", "level", "location", "play_time_sec", "player_name", "saved_at_unix",
		"slot"])
	assert_eq(s["slot"], 2)
	var f1: Dictionary = _read(DIR + "/slot_1.json")
	f1["saved_at_unix"] = int(f1["saved_at_unix"]) + 100
	_write(DIR + "/slot_1.json", JSON.stringify(f1))
	assert_eq(Save.newest_slot(), 1, "latest saved_at_unix")
	assert_eq(Save.delete_slot(1), OK)
	assert_false(Save.has_save(1))
	assert_false(FileAccess.file_exists(DIR + "/slot_1.json.bak"))
	assert_eq(Save.newest_slot(), 2)
	assert_eq(Save.delete_slot(1), OK, "deleting an empty slot is fine")


func test_read_only_and_autosave() -> void:
	_prev_data = Fx.begin_world(9, 2)
	Save.read_only = true
	assert_eq(Save.save_slot(2), OK)
	assert_eq(Save.autosave(), OK)
	assert_false(Save.has_save(2), "read_only (autoplay) never writes")
	Save.read_only = false
	Game.state.slot = 0
	assert_eq(Save.autosave(), OK)
	assert_false(DirAccess.dir_exists_absolute(DIR) and not DirAccess.get_files_at(DIR).is_empty(), "slot 0: no write")
	Game.state.slot = 2
	assert_eq(Save.autosave(), OK)
	assert_true(Save.has_save(2), "autosave writes the state's slot")
	Game.state = null
	assert_eq(Save.autosave(), OK, "no state → nothing to do")


func test_record_game_over() -> void:
	_prev_data = Fx.begin_world(11, 1)
	Save.save_slot(1)
	assert_eq(Save.record_game_over(1), OK)
	assert_eq(Save.record_game_over(1), OK)
	assert_eq(_read(DIR + "/slot_1.json")["state"]["show"]["stats"]["game_overs"], 2)
	assert_eq(Save.record_game_over(0), OK, "slot 0 → OK")
	assert_eq(Save.record_game_over(3), OK, "no file → nothing to record")
	assert_false(Save.has_save(3))
	Save.load_slot(1)
	assert_eq(Game.state.show.stats["game_overs"], 2)


func test_leaderboards_and_replays() -> void:
	var board: Dictionary = {"schema": 1, "entries": [{"score": 17340, "run_id": "run_local_1"}]}
	assert_eq(Save.save_leaderboard("evt_offline_gleis9", board), OK)
	assert_true(FileAccess.file_exists(ROOT + "/leaderboards/evt_offline_gleis9.json"), "next to the save dir")
	assert_eq(Save.load_leaderboard("evt_offline_gleis9"), board)
	assert_eq(Save.load_leaderboard("evt_unknown"), {})
	assert_eq(Save.save_leaderboard("../evil", board), ERR_INVALID_PARAMETER)
	assert_eq(Save.load_leaderboard("../evil"), {})
	for i in Save.MAX_REPLAYS + 2:
		var rl: RunLog = RunLog.new()
		rl.header = {"run_id": "run_local_%03d" % i}
		assert_eq(Save.save_replay(rl), OK)
	var files: PackedStringArray = DirAccess.get_files_at(ROOT + "/replays")
	var json_files: Array = Array(files).filter(func(f: String) -> bool: return f.ends_with(".json"))
	assert_eq(json_files.size(), Save.MAX_REPLAYS, "max. 20 replay files")
	assert_has(json_files, "run_local_%03d.json" % (Save.MAX_REPLAYS + 1), "the newest replay is kept")
	assert_eq(Save.save_replay(null), ERR_INVALID_PARAMETER)
	Save.read_only = true
	assert_eq(Save.save_leaderboard("evt_x", board), OK)
	assert_false(FileAccess.file_exists(ROOT + "/leaderboards/evt_x.json"), "read_only")
