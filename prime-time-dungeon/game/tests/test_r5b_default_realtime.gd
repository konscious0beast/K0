extends TestCase
## 07 E33 (R5b-2a): real time is the default of new games — GameSettings.DEFAULT_COMBAT_MODE, Game.new_game and the dev
## state of a standalone scene take it; the boot argument --combat=ctb and the debug-only switch still give CTB; a CTB
## debug save keeps its mode ("combat_mode": "ctb", save v2 of R5b part 2b — a version-1 CTB save continues in real
## time, test_r5b_save_v2); a settings file of version 1 (its combat_mode "ctb" was the old default, not a choice) is
## read as real time; the CTB battle scene keeps a CTB dev state.

const ROOT: String = "user://test_r5b_default_realtime"
const DIR: String = "user://test_r5b_default_realtime/saves"

var _saved_dir: String = ""
var _saved_ro: bool = true
var _saved_mode: StringName = &""


func before_each() -> void:
	_saved_dir = Save.save_dir
	_saved_ro = Save.read_only
	_saved_mode = Game.settings.combat_mode
	Game.combat_mode_override = &""


func after_each() -> void:
	Save.save_dir = _saved_dir
	Save.read_only = _saved_ro
	Game.settings.combat_mode = _saved_mode
	Game.combat_mode_override = &""
	_rmrf(ROOT)
	Game.state = null


static func _rmrf(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for f: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	for sub: String in DirAccess.get_directories_at(path):
		_rmrf(path.path_join(sub))
	DirAccess.remove_absolute(path)


func test_settings_default_is_real_time() -> void:
	assert_eq(GameSettings.DEFAULT_COMBAT_MODE, &"realtime", "07 E33")
	var s: GameSettings = GameSettings.new()
	s.ephemeral = true
	assert_eq(s.combat_mode, &"realtime", "a fresh GameSettings")
	s.combat_mode = &"ctb"
	s.reset_defaults()
	assert_eq(s.combat_mode, &"realtime", "reset_defaults")
	assert_eq(GameSettings.FILE_VERSION, 2, "the settings file version of E33")


func test_new_games_fight_in_real_time() -> void:
	Game.new_game(0, "Kai", 4242)
	assert_eq(Game.new_game_combat_mode(), &"realtime")
	assert_true(Game.is_realtime(), "Game.new_game takes the setting")
	assert_eq(str(Game.run_log.header.get("combat_mode", "")), "realtime", "the run log names it (07 §10.2)")
	assert_eq(Game.state.member("kai").hp, Progression.total_stats(Game.state.member("kai"), DB.data).values[
		StatBlock.Stat.HP], "full real-time HP (07 §3.9.4, baked in R5b part 2b)")
	Game.combat_mode_override = &"ctb"
	Game.new_game(0, "Kai", 4242)
	assert_false(Game.is_realtime(), "--combat=ctb still gives a CTB game")
	assert_false(Game.run_log.header.has("combat_mode"), "with the CTB header of before")
	Game.combat_mode_override = &""
	Game.settings.combat_mode = &"ctb"
	Game.new_game(0, "Kai", 4242)
	assert_false(Game.is_realtime(), "so does the debug switch (07 §12.1)")


## Save v2 (R5b part 2b): a real-time state needs no combat_mode key — the campaign's mode; a CTB debug run names
## "combat_mode": "ctb" and keeps it.
func test_saves_keep_their_combat_mode() -> void:
	_rmrf(ROOT)
	Save.save_dir = DIR
	Save.read_only = false
	Game.combat_mode_override = &"ctb"
	Game.new_game(1, "Kai", 616)
	Game.combat_mode_override = &""
	assert_eq(Game.state.to_dict().get("combat_mode", ""), "ctb", "a CTB debug state names its mode")
	assert_eq(Save.save_slot(1), OK)
	Game.state = null
	assert_eq(Save.load_slot(1), OK)
	assert_false(Game.is_realtime(), "a CTB debug save continues in CTB")
	assert_false(Game.run_log.header.has("combat_mode"), "its run log stays a CTB log")
	Game.new_game(2, "Kai", 617)
	assert_true(Game.is_realtime())
	assert_false(Game.state.to_dict().has("combat_mode"), "a real-time state needs no key")
	assert_eq(Save.save_slot(2), OK)
	Game.state = null
	assert_eq(Save.load_slot(2), OK)
	assert_true(Game.is_realtime(), "a real-time save stays real time")
	assert_eq(str(Game.run_log.header.get("combat_mode", "")), "realtime")


## A settings file without meta/version was written before E33: its combat_mode "ctb" was the default then (the switch
## is debug-only), so it is read as real time; a file of FILE_VERSION keeps the debug choice in debug builds.
func test_settings_file_of_version_1_is_read_as_real_time() -> void:
	var path: String = GameSettings.PATH
	var had: bool = FileAccess.file_exists(path)
	var backup: String = FileAccess.get_file_as_string(path) if had else ""
	var old: ConfigFile = ConfigFile.new()
	old.set_value("combat", "combat_mode", "ctb")
	old.set_value("combat", "combat_speed_pm", 850)
	assert_eq(old.save(path), OK)
	var r: GameSettings = GameSettings.new()
	r.ephemeral = false
	r.load_from_disk()
	assert_eq(r.combat_mode, &"realtime", "version 1: the stored \"ctb\" was the old default")
	assert_eq(r.combat_speed_pm, 850, "the other [combat] keys stay")
	r.combat_mode = &"ctb"                                 # the debug switch
	assert_eq(r.save_to_disk(), OK)
	var cfg: ConfigFile = ConfigFile.new()
	assert_eq(cfg.load(path), OK)
	assert_eq(int(cfg.get_value("meta", "version", 0)), GameSettings.FILE_VERSION, "written with its version")
	var r2: GameSettings = GameSettings.new()
	r2.ephemeral = false
	r2.load_from_disk()
	assert_eq(r2.combat_mode, &"ctb" if OS.is_debug_build() else &"realtime",
		"a version-2 file keeps the debug choice; release builds always take the default")
	if had:
		var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		f.store_string(backup)
		f.close()
	else:
		DirAccess.remove_absolute(path)


## Dev states: Game.ensure_state() takes the default; the CTB battle scene asks for a CTB one unless the boot argument
## --combat= decides; the override is restored and a running game stays.
func test_dev_states() -> void:
	Game.state = null
	Game.ensure_state()
	assert_true(Game.is_realtime(), "a standalone scene's dev state fights in real time")
	Game.state = null
	Game.ensure_state(&"ctb")
	assert_false(Game.is_realtime(), "the CTB battle scene's dev state")
	assert_eq(Game.combat_mode_override, &"", "the override is restored")
	Game.state = null
	Game.combat_mode_override = &"realtime"
	Game.ensure_state(&"ctb", 7)
	assert_true(Game.is_realtime(), "the boot argument decides")
	assert_eq(Game.combat_mode_override, &"realtime")
	assert_eq(Game.state.seed, 7, "the dev seed (--goto with --seed)")
	Game.ensure_state(&"ctb")
	assert_true(Game.is_realtime(), "a running game stays")
