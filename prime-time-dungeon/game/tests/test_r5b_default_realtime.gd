extends TestCase
## The campaign fights in real time only (07 E33 made it the default in R5b-2a; R5b part 2b, 07 §12.6 / 10 SD1 removed
## the CTB campaign): every new game and dev state is a real-time run (run log header, full real-time HP); there is no
## combat mode to choose any more — no GameSettings.combat_mode, no boot argument --combat=, no GameState.combat_mode;
## a settings file with the old CTB keys loads (they are ignored and not written back); saves carry no combat mode (a
## version-1 CTB save continues in real time, test_r5b_save_v2).

const ROOT: String = "user://test_r5b_default_realtime"
const DIR: String = "user://test_r5b_default_realtime/saves"

var _saved_dir: String = ""
var _saved_ro: bool = true


func before_each() -> void:
	_saved_dir = Save.save_dir
	_saved_ro = Save.read_only


func after_each() -> void:
	Save.save_dir = _saved_dir
	Save.read_only = _saved_ro
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


func test_there_is_no_combat_mode_to_choose() -> void:
	var s: GameSettings = GameSettings.new()
	s.ephemeral = true
	for key: String in ["combat_mode", "battle_speed", "auto_battle_default", "partner_auto"]:
		assert_false(key in s, "GameSettings.%s is gone" % key)
		assert_false(s.to_dict().has(key), "to_dict without " + key)
	var consts: Dictionary = (load("res://autoload/game_settings.gd") as GDScript).get_script_constant_map()
	assert_false(consts.has("COMBAT_MODES") or consts.has("DEFAULT_COMBAT_MODE"), "no combat mode vocabulary")
	assert_false("combat_mode" in GameState.new(), "GameState.combat_mode is gone")
	for prop: String in ["combat_mode_override", "auto_battle"]:
		assert_false(prop in Game, "Game.%s is gone" % prop)
	for fn: String in ["new_game_combat_mode", "combat_mode_from_args", "_rt_new_game"]:
		assert_false(Game.has_method(fn), "Game.%s is gone" % fn)


func test_new_games_fight_in_real_time() -> void:
	Game.new_game(0, "Kai", 4242)
	assert_true(Game.is_realtime())
	assert_eq([str(Game.run_log.header.get("combat_mode", "")), int(Game.run_log.header.get("rt_version", 0))],
		["realtime", RunRules.RT_VERSION], "the run log names a real-time run (07 §10.2)")
	assert_eq(Game.state.member("kai").hp, Progression.total_stats(Game.state.member("kai"), DB.data).values[
		StatBlock.Stat.HP], "full real-time HP (07 §3.9.4, baked in R5b part 2b)")
	assert_false(Game.state.to_dict().has("combat_mode"), "the state carries no mode")


## The boot argument --combat= of R2–R5b-2a is gone: Game no longer reads it.
func test_the_combat_boot_argument_is_gone() -> void:
	var src: String = FileAccess.get_file_as_string("res://autoload/game.gd")
	if src != "":
		assert_false(src.contains("--combat="), "Game no longer parses --combat=")
	Game.new_game(0, "Kai", 4242)
	assert_true(Game.is_realtime())


## A settings file of an older kernel with the CTB keys (game/battle_speed, auto_battle_default, partner_auto,
## combat/combat_mode "ctb") loads: the keys are ignored and the next save does not write them back.
func test_a_settings_file_with_ctb_keys_loads() -> void:
	var path: String = GameSettings.PATH
	var had: bool = FileAccess.file_exists(path)
	var backup: String = FileAccess.get_file_as_string(path) if had else ""
	var old: ConfigFile = ConfigFile.new()
	old.set_value("meta", "version", 2)
	old.set_value("game", "battle_speed", 2.0)
	old.set_value("game", "auto_battle_default", true)
	old.set_value("game", "partner_auto", true)
	old.set_value("game", "text_speed", 2)
	old.set_value("combat", "combat_mode", "ctb")
	old.set_value("combat", "combat_speed_pm", 850)
	assert_eq(old.save(path), OK)
	var r: GameSettings = GameSettings.new()
	r.ephemeral = false
	r.load_from_disk()
	assert_eq([r.text_speed, r.combat_speed_pm], [2, 850], "the other keys stay")
	assert_eq(r.save_to_disk(), OK)
	var cfg: ConfigFile = ConfigFile.new()
	assert_eq(cfg.load(path), OK)
	assert_false(cfg.has_section_key("combat", "combat_mode"), "combat_mode is not written back")
	for key: String in ["battle_speed", "auto_battle_default", "partner_auto"]:
		assert_false(cfg.has_section_key("game", key), key + " is not written back")
	assert_eq(int(cfg.get_value("meta", "version", 0)), GameSettings.FILE_VERSION)
	if had:
		var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		f.store_string(backup)
		f.close()
	else:
		DirAccess.remove_absolute(path)


## Saves carry no combat mode: a new game saves and loads into a real-time run; a version-2 state dict that still
## names "combat_mode": "ctb" (a debug run between save format v2 and SD1) loads into one as well.
func test_saves_carry_no_combat_mode() -> void:
	_rmrf(ROOT)
	Save.save_dir = DIR
	Save.read_only = false
	Game.new_game(1, "Kai", 617)
	assert_eq(Save.save_slot(1), OK)
	var raw: Variant = JsonUtil.read_file(Save.slot_path(1))
	assert_true(raw is Dictionary and not ((raw as Dictionary)["state"] as Dictionary).has("combat_mode"))
	Game.state = null
	assert_eq(Save.load_slot(1), OK)
	assert_true(Game.is_realtime())
	assert_eq(str(Game.run_log.header.get("combat_mode", "")), "realtime")
	var d: Dictionary = Game.state.to_dict()
	var hash: String = StateHash.of(Game.state)
	d["combat_mode"] = "ctb"
	assert_eq(StateHash.of(GameState.from_dict(d)), hash, "the old key is ignored")


## Dev states (standalone scenes, --goto): Game.ensure_state() starts a real-time game with seed 1 or the given one;
## a running game stays.
func test_dev_states() -> void:
	Game.state = null
	Game.ensure_state()
	assert_true(Game.is_realtime(), "a standalone scene's dev state fights in real time")
	assert_eq(Game.state.seed, 1)
	Game.state = null
	Game.ensure_state(7)
	assert_eq(Game.state.seed, 7, "the dev seed (--goto with --seed)")
	Game.ensure_state(9)
	assert_eq(Game.state.seed, 7, "a running game stays")
