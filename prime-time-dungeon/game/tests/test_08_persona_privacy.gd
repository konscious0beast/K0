extends TestCase
## 08 §2.5, §2.7 (K1): the canary "ZZKANARI" (name) and "ZZFREITEXT" (free text) go through the casting, a run, save,
## load and an event run and are afterwards only in the persona folder (user://persona/ next to the saves) — never in
## the saves, settings, replays, leaderboards, the run log, StateHash.hash_input, the anchor start_state or
## ModLiveSummary. Deleting a slot deletes its persona file; "Kandidat:in löschen" removes every persona file and the
## leftovers with names (old slots, replays, local board entries) and the running game goes on as the canon Kai; the
## name filter gives a reason; the Android preset keeps user data out of the system backup.

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const CASTING: String = "res://scenes/title/persona_casting.tscn"
const NAME: String = "ZZKANARI"
const FREE: String = "ZZFREITEXT"
const ROOT: String = "user://test_08_privacy"
const SAVES: String = "user://test_08_privacy/saves"
const PERSONA_DIR: String = "user://test_08_privacy/persona"
const EVENT_ID: String = "evt_offline_gleis9"
const PRESETS: String = "res://export_presets.cfg"


func before_each() -> void:
	_rmrf(ROOT)
	Save.save_dir = SAVES
	Save.read_only = false


func after_each() -> void:
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
	_rmrf(ROOT)


static func _rmrf(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for f: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	for sub: String in DirAccess.get_directories_at(path):
		_rmrf(path.path_join(sub))
	DirAccess.remove_absolute(path)


## path → text of every file below `dir` except `skip` (a sub folder).
static func _files(dir: String, skip: String = "") -> Dictionary:
	var out: Dictionary = {}
	if not DirAccess.dir_exists_absolute(dir) or dir == skip:
		return out
	for f: String in DirAccess.get_files_at(dir):
		out[dir.path_join(f)] = FileAccess.get_file_as_string(dir.path_join(f))
	for sub: String in DirAccess.get_directories_at(dir):
		out.merge(_files(dir.path_join(sub), skip))
	return out


func _leaks(where: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	for path: Variant in where.keys():
		var text: String = str(where[path])
		if text.contains(NAME) or text.contains(FREE):
			out.append(str(path))
	return out


static func _safe_room() -> String:
	return str((DB.floor_def(1).layout.get("safe_rooms", [{}]) as Array)[0].get("id", ""))


## The casting as a player fills it in: name on 1/3, "Anderes …" Vorleben (free text) on 2/3, the card on 3/3.
func _cast() -> PersonaProfile:
	var n: Node = (load(CASTING) as PackedScene).instantiate()
	n.call("setup", {"slot": 1, "seed": 4242})
	add_to_tree(n)
	await wait_frames(2)
	n.call("set_player_name", NAME)
	n.call("next")
	assert_eq(int(n.get("page")), 2, "the canary name is a valid name")
	assert_eq(str(n.call("set_custom", "origin", FREE)), "", "the free text is accepted (mapped to Allrounder:in)")
	n.call("next")
	var final: PersonaProfile = n.get("final") as PersonaProfile
	assert_eq([final.name, final.origin, final.job_text], [NAME, "org_allround", FREE])
	return final


func _fight() -> void:
	var setup: BattleSetup = Game.make_battle_setup(DB.floor_def(1).timer_start_after,
		BattleSetup.Advantage.PREEMPTIVE, "")
	var battle: BattleState = BattleState.new(setup, DB.data)
	Show.begin_battle(setup)
	for e: ActionEvent in battle.start():
		Show.on_battle_event(e)
	var guard: int = 0
	while not battle.is_finished() and guard < 400:
		guard += 1
		var cmd: BattleCommand = battle.choose_ai_command()
		Game.record({"t": "battle", "cmd": cmd.to_dict(), "auto": true})
		for e: ActionEvent in battle.submit(cmd):
			Show.on_battle_event(e)
	Game.apply_battle_result(battle.result)
	Show.end_battle(battle.result)


func test_canary_stays_in_the_persona_folder() -> void:
	var p: PersonaProfile = await _cast()
	Game.new_game(1, p.name, 4242, &"prime", "kai", p)        # TitleFlow.start_new_game without the routing
	assert_eq(Game.state.player_name, NAME, "display only (P-2)")
	_fight()
	var sr: String = _safe_room()
	Game.enter_safe_room(sr)
	assert_eq(Save.save_slot(1), OK, Save.last_error())
	assert_eq(Save.load_slot(1), OK, Save.last_error())
	assert_eq(Game.state.player_name, NAME, "the name comes back from the persona file")
	assert_eq(Game.persona.job_text, FREE, "and the free text")
	Game.leave_safe_room()
	var mid: Dictionary = {
		"run log": JSON.stringify(Game.run_log.to_dict()),
		"StateHash.hash_input": JSON.stringify(StateHash.hash_input(Game.state)),
		"anchor start_state": JSON.stringify(Game.run_log.header.get("start_state", {})),
		"ModLiveSummary": JSON.stringify(ModLiveSummary.build(Game.state, DB.data, {}, Game.sim.tick(), false, [],
			PackedStringArray(), "req_1", "run_ref_1")),
	}
	var settings: Dictionary = {}
	for prop: Dictionary in Game.settings.get_property_list():
		settings[str(prop["name"])] = str(Game.settings.get(str(prop["name"])))
	mid["settings"] = JSON.stringify(settings)
	assert_eq(_leaks(mid), PackedStringArray(), "no canary in hashes, logs, the live summary or the settings")
	assert_eq(Save.save_slot(1), OK)
	Game.start_event_run(EVENT_ID)
	assert_null(Game.persona, "event runs have no persona (08 §8)")
	assert_eq(Game.state.player_name, GameState.DEFAULT_NAME)
	var summary: Dictionary = Game.finish_run(&"timer")
	assert_false(JSON.stringify(summary).contains(NAME))
	var outside: Dictionary = _files(ROOT, PERSONA_DIR)
	assert_true(outside.size() >= 3, "slot, replay and board were written: %s" % str(outside.keys()))
	assert_eq(_leaks(outside), PackedStringArray(), "saves/, replays/, leaderboards/ without the canary")
	var inside: Dictionary = _files(PERSONA_DIR)
	for path: Variant in inside.keys():
		assert_true(str(path).begins_with(Save.persona_path(1)), "one persona file per slot (+ its backup): " + str(path))
	assert_has(str(inside[Save.persona_path(1)]), NAME, "the name lives in the persona file")
	assert_has(str(inside[Save.persona_path(1)]), FREE, "and the free text")
	assert_true(Save.persona_path(1).begins_with(PERSONA_DIR), "user://persona/ next to the saves")


func test_deleting_a_slot_deletes_its_persona_file() -> void:
	var p: PersonaProfile = PersonaProfile.canon(DB.data)
	p.name = NAME
	Game.new_game(2, p.name, 7, &"prime", "kai", p)
	Game.enter_safe_room(_safe_room())
	assert_eq(Save.save_slot(2), OK, Save.last_error())
	assert_true(FileAccess.file_exists(Save.persona_path(2)))
	assert_eq(Save.slot_summary(2).get("player_name", ""), NAME, "the slot list shows the name (persona file)")
	assert_eq(Save.delete_slot(2), OK)
	assert_false(FileAccess.file_exists(Save.slot_path(2)))
	assert_false(FileAccess.file_exists(Save.persona_path(2)), "the persona file goes with the slot")


func test_kandidat_in_loeschen_removes_names_everywhere() -> void:
	var p: PersonaProfile = PersonaProfile.canon(DB.data)
	p.name = NAME
	p.origin = PersonaProfile.ALLROUND
	p.job_text = FREE
	Game.new_game(1, p.name, 11, &"prime", "kai", p)
	Game.enter_safe_room(_safe_room())
	assert_eq(Save.save_slot(1), OK)
	assert_eq(Save.save_persona(3, p), OK, "another slot's card")
	# leftovers from before K1: a slot whose state still names the player, a replay header and a local board entry
	var old: Dictionary = JsonUtil.read_file(Save.slot_path(1))
	(old["state"] as Dictionary)["player_name"] = NAME
	DirAccess.make_dir_recursive_absolute(SAVES)
	var f: FileAccess = FileAccess.open(Save.slot_path(2), FileAccess.WRITE)
	f.store_string(JSON.stringify(old))
	f.close()
	var rdir: String = ROOT.path_join(Save.REPLAY_DIR)
	DirAccess.make_dir_recursive_absolute(rdir)
	f = FileAccess.open(rdir.path_join("run_old.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"header": {"player_name": NAME, "seed": 1}, "cmds": []}))
	f.close()
	var ldir: String = ROOT.path_join(Save.LEADERBOARD_DIR)
	DirAccess.make_dir_recursive_absolute(ldir)
	f = FileAccess.open(ldir.path_join(EVENT_ID + ".json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"entries": [{"score": 5, "players": [{"player_id": "local", "display_name": NAME}]},
		{"score": 4, "players": [{"player_id": "p7", "display_name": "Pendlerin_42"}]}]}))
	f.close()
	assert_eq(_leaks(_files(ROOT)).size(), 5, "precondition: the canary is in five files")
	assert_eq(Save.delete_candidate(), OK, Save.last_error())
	assert_eq(_files(PERSONA_DIR).size(), 0, "every persona file is gone")
	assert_eq(_leaks(_files(ROOT)), PackedStringArray(), "no file names the candidate any more")
	assert_false(FileAccess.file_exists(rdir.path_join("run_old.json")), "a replay naming the player is deleted")
	assert_has(FileAccess.get_file_as_string(ldir.path_join(EVENT_ID + ".json")), "Pendlerin_42",
		"other players' entries stay")
	assert_true(FileAccess.file_exists(Save.slot_path(1)) and FileAccess.file_exists(Save.slot_path(2)),
		"the saves stay")
	assert_true(Game.persona.is_canon(DB.data), "the running game goes on as the canon Kai")
	assert_eq(Game.state.player_name, GameState.DEFAULT_NAME)
	assert_eq(Save.load_slot(2), OK, Save.last_error())
	assert_eq(Game.state.player_name, GameState.DEFAULT_NAME, "a cleaned old slot loads as Kai (no migration)")
	assert_false(FileAccess.file_exists(Save.persona_path(2)))


func test_name_filter_gives_a_reason() -> void:
	assert_eq(PersonaText.check_name("Jana"), "")
	assert_eq(PersonaText.check_name("Zoé"), "", "accents are names")
	assert_eq(PersonaText.check_name("Tel 0151234"), "Dieser Name ist leider nicht sendefähig: enthält Kontaktdaten " +
		"oder Nummern.")
	assert_eq(PersonaText.check_name("Parlamentia"), "Dieser Name ist leider nicht sendefähig: enthält Politik.")
	var n: Node = (load(CASTING) as PackedScene).instantiate()
	n.call("setup", {"slot": 1})
	add_to_tree(n)
	await wait_frames(2)
	n.call("set_player_name", "Tel 0151234")
	n.call("next")
	assert_eq(int(n.get("page")), 1, "a rejected name keeps page 1")
	var hint: Label = n.find_child("NameHint", true, false) as Label
	assert_has(hint.text, "nicht sendefähig", "the reason is shown")
	n.call("rest_auto")
	assert_eq(int(n.get("page")), 1, "\"Rest automatisch\" does not skip a rejected name")
	n.call("set_player_name", "")
	n.call("rest_auto")
	assert_eq(int(n.get("page")), 3, "an empty name is the canon Kai")
	assert_eq((n.get("final") as PersonaProfile).name, "Kai")


func test_android_backup_excludes_user_data() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	assert_eq(cfg.load(PRESETS), OK)
	var section: String = ""
	for s: String in cfg.get_sections():
		if not s.ends_with(".options") and str(cfg.get_value(s, "platform", "")) == "Android":
			section = s + ".options"
	assert_ne(section, "", "an Android preset")
	assert_true(cfg.has_section_key(section, "user_data_backup/allow"), "the backup option is set explicitly")
	assert_false(bool(cfg.get_value(section, "user_data_backup/allow", true)),
		"user:// (persona/ with the name) never goes into the Android backup (08 R12)")
