extends TestCase
## 09 §11.6 test_09_journal (ST1-B): the command journal of a season slot (09 §9.1, V-3). The line format
## (CommandJournal: the header, the entries, a torn last line dropped, a broken line ends the journal, the open combat,
## the run log it replays as); the journal next to the slot (every recorded command a line before it acts; empty after
## the save — a new journal id in the slot file and in the journal's header); a load continues the save (the journal
## replayed, saved at once, a fresh journal; a stale journal and a torn last line in the real file); the persistent
## save (its own slot only, never in a combat, a finished season does not load, an ST0-shaped season block loads) — and
## the app "closed" at every tenth tick of a combat: after the restart the same result as the autopilot run from the
## start of that combat (the inputs made so far do not count).

const Kit := preload("res://tests/fixtures/season_core/season_core.gd")
const RtLive := preload("res://tests/fixtures/rt_live/rt_live.gd")
const Bot := preload("res://tests/tools/rt_bot_player.gd")
const ROOT: String = "user://test_09_journal"
const SAVES: String = "user://test_09_journal/saves"
const SLOT: int = 1
const ENC: String = "enc_f1_a2"                     # three enemies of floor 1 (a fight of some length)
const SEASON_MIN_SAVE: String = "res://tests/fixtures/season_min/save_v2_season.json"


func before_each() -> void:
	_rmrf(ROOT)
	Save.save_dir = SAVES
	Save.read_only = false


func after_each() -> void:
	_quit()
	Save.save_dir = "user://saves"
	_rmrf(ROOT)


## The app goes away: the live game forgets everything, the journal handle closes (what a killed process leaves: the
## files).
static func _quit() -> void:
	if Game.combat != null:
		Game.combat = null
		Show.abort_battle()
	Game.state = null
	Game.run_log = null
	Game.sim = null
	Game.quest = null
	Game.persona = null
	Game.mode = &"campaign"
	Game.timer_running = false
	Game.in_battle = false
	Save._journal_close()


static func _rmrf(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for f: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	for sub: String in DirAccess.get_directories_at(path):
		_rmrf(path.path_join(sub))
	DirAccess.remove_absolute(path)


static func _write(path: String, text: String) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


static func _start(seed: int) -> bool:
	return Game.start_season(SLOT, "ssn_basis", {"now": Kit.START, "tz_sec": 0, "seed": seed})


static func _slot_journal_id() -> String:
	return str(JsonUtil.read_file(Save.slot_path(SLOT)).get(Save.JOURNAL_KEY, ""))


static func _commands(entries: Array) -> Array:
	var out: Array = []
	for e: Variant in entries:
		out.append((e as Dictionary)["c"])
	return out


# --- the line format (CommandJournal) -----------------------------------------------------------------------------

func test_the_line_format() -> void:
	var head: String = CommandJournal.header_line("abc", 7)
	var a: String = CommandJournal.line(3, {"t": "clock", "sec": 60})
	var b: String = CommandJournal.line(9, {"t": "room", "cell": [2, 3]})
	assert_false((head + a + b).contains("\n"), "one line each")
	var j: Dictionary = CommandJournal.parse(head + "\n" + a + "\n" + b + "\n")
	assert_eq(j["header"], {"journal": CommandJournal.VERSION, "id": "abc", "k0": 7})
	assert_eq(j["entries"], [{"k": 3, "c": {"t": "clock", "sec": 60}}, {"k": 9, "c": {"t": "room", "cell": [2, 3]}}])
	assert_eq([j["torn"], j["bad"]], [false, 0])
	var torn: Dictionary = CommandJournal.parse(head + "\n" + a + "\n" + b.left(b.length() - 5))
	assert_eq([(torn["entries"] as Array).size(), torn["torn"], torn["bad"]], [1, true, 0], "a torn last line is dropped")
	var no_end: Dictionary = CommandJournal.parse(head + "\n" + a + "\n" + b)
	assert_eq([(no_end["entries"] as Array).size(), no_end["torn"]], [1, true],
		"a last line without its line end was still being written")
	var broken: Dictionary = CommandJournal.parse(head + "\n" + a + "\n{kaputt\n" + b + "\n")
	assert_eq([(broken["entries"] as Array).size(), broken["torn"], broken["bad"]], [1, false, 2],
		"a broken line ends the journal there")
	var headless: Dictionary = CommandJournal.parse(a + "\n" + b + "\n")
	assert_eq([headless["header"], (headless["entries"] as Array).size()], [{}, 0], "no header: nothing to replay")
	assert_eq((CommandJournal.parse("")["entries"] as Array).size(), 0)


func test_the_open_combat_and_the_run_log() -> void:
	var enc: Dictionary = {"t": "encounter", "enc": ENC, "group": "g", "rt": {"v": 1}}
	var entries: Array = [{"k": 0, "c": {"t": "clock", "sec": 60}}, {"k": 4, "c": {"t": "room", "cell": [1, 1]}},
		{"k": 9, "c": enc}, {"k": 9, "c": RtCommand.autopilot(0, "p0", true)},
		{"k": 9, "c": {"t": "gift", "gift_id": "x", "ct": 12}}]
	assert_eq(CommandJournal.open_combat(entries), 2, "the journal ends in the combat of entry 2")
	assert_eq(CommandJournal.open_combat(entries.slice(0, 3)), 2, "right after its start")
	assert_eq(CommandJournal.open_combat(entries + [{"k": 9, "c": {"t": "safe_room", "id": "s"}}]), -1, "it ended")
	assert_eq(CommandJournal.open_combat(entries.slice(0, 2)), -1, "no combat")
	var plain: Dictionary = enc.duplicate(true)
	plain.erase("rt")
	assert_eq(CommandJournal.open_combat([{"k": 1, "c": plain}]), -1, "an encounter without its rt block is no combat")
	var rl: RunLog = CommandJournal.to_run_log({"seed": 1}, entries, 2)
	assert_eq(_commands(rl.cmds()), _commands(entries.slice(0, 3)), "the open combat's inputs are dropped")
	var ids: Array = []
	for row: Dictionary in rl.cmds():
		ids.append(int(row["id"]))
	assert_eq(ids, [0, 1, 2], "fresh ids; the clock is external (id 0)")
	assert_eq(CommandJournal.to_run_log({}, entries).size(), entries.size(), "without an open combat: every entry")


# --- the journal next to the slot ---------------------------------------------------------------------------------

func test_the_journal_follows_the_save() -> void:
	assert_true(_start(11))
	var id1: String = _slot_journal_id()
	assert_eq(id1.length(), 16, "the slot file names its journal (8 random bytes, hex)")
	var j: Dictionary = Save.journal_read(SLOT)
	assert_eq([str((j["header"] as Dictionary).get("id", "")), (j["entries"] as Array).size()], [id1, 0],
		"the save starts its journal: empty")
	assert_true(Game.season_clock(60))
	assert_true(Game.season_clock(120))
	assert_eq(_commands(Save.journal_replay(SLOT)), [{"t": "clock", "sec": 60}, {"t": "clock", "sec": 120}],
		"every recorded command, in order")
	assert_eq(Save.save_slot(SLOT), OK)
	var id2: String = _slot_journal_id()
	assert_ne(id2, id1, "every save a new journal id")
	j = Save.journal_read(SLOT)
	assert_eq([str((j["header"] as Dictionary).get("id", "")), (j["entries"] as Array).size()], [id2, 0],
		"the journal after the save: empty (09 §11.6)")
	assert_true(Game.season_clock(30))
	var live: String = StateHash.of(Game.state)
	var utc: int = Game.state.season.utc
	_quit()                                       # the app is killed: the save plus one journal line
	assert_eq(Save.load_slot(SLOT), OK, Save.last_error())
	assert_eq([Game.state.season.utc, StateHash.of(Game.state)], [utc, live], "the journal replayed onto the save")
	var id3: String = _slot_journal_id()
	assert_ne(id3, id2, "saved at once after the replay")
	assert_eq(Save.journal_replay(SLOT), [] as Array[Dictionary], "and a fresh journal")
	assert_eq(StateHash.of(SaveCodec.decode(JsonUtil.read_file(Save.slot_path(SLOT)), DB.data)), live,
		"the slot holds the replayed state")


func test_a_stale_journal_and_a_torn_line() -> void:
	assert_true(_start(12))
	assert_true(Game.season_clock(90))
	var stale: String = FileAccess.get_file_as_string(Save.journal_path(SLOT))
	assert_eq(Save.save_slot(SLOT), OK)               # the save already holds the clock of the old journal
	var utc: int = Game.state.season.utc
	_quit()
	_write(Save.journal_path(SLOT), stale)
	assert_eq(Save.load_slot(SLOT), OK)
	assert_eq(Game.state.season.utc, utc, "a journal of an older save is ignored (nothing twice)")
	assert_true(Game.season_clock(45))
	assert_true(Game.season_clock(15))
	var text: String = FileAccess.get_file_as_string(Save.journal_path(SLOT))
	_quit()
	_write(Save.journal_path(SLOT), text.left(text.length() - 6))   # the app died while writing the last line
	assert_eq(Save.load_slot(SLOT), OK)
	assert_eq(Game.state.season.utc, utc + 45, "the torn last line is dropped, the rest replayed")


func test_the_persistent_save() -> void:
	assert_true(_start(13))
	assert_eq(Save.save_slot(2), ERR_UNAVAILABLE, "a season saves only into its own slot (no reloading)")
	assert_has(Save.last_error(), "own slot")
	assert_false(Save.has_save(2))
	Game.combat = RtKit.sim(RtKit.dummy_cmd())
	assert_eq(Save.save_slot(SLOT), ERR_UNAVAILABLE, "never during a combat")
	Game.combat = null
	Game.state.floor_run.time_left_ticks = 10
	assert_eq(Save.save_slot(SLOT), OK)
	_quit()
	assert_eq(Save.load_slot(SLOT), OK)
	assert_eq(Game.state.floor_run.time_left_ticks, 10, "no load grace in a season (02 §0.8; the campaign: %d s)"
		% Save.GRACE_SECONDS)
	Game.state.season.result = "left"
	assert_eq(Save.save_slot(SLOT), OK)
	_quit()
	assert_eq(Save.load_slot(SLOT), ERR_UNAVAILABLE, "a finished season does not load")
	assert_has(Save.last_error(), Save.MSG_SEASON_OVER)
	var file: Dictionary = JsonUtil.read_file(SEASON_MIN_SAVE)
	var block: Dictionary = (file["state"] as Dictionary)["season"]
	for k: String in block.keys():
		if not ["v", "def", "format", "tempo", "mode", "number", "day0_utc", "collapse_utc", "utc", "seen_unix"].has(k):
			block.erase(k)
	var st0: SeasonState = SeasonState.from_dict(block)
	assert_eq([st0.programme, st0.reached, st0.airs, st0.next_air_utc, st0.points(2), st0.reached_at(1)],
		[[], [], 0, st0.day0_utc, 0, -1], "an ST0-shaped block loads; the per-floor values read as 0 / -1")



# --- the app closed in a combat (09 §9.1, §11.6) ----------------------------------------------------------------------

func test_closed_at_every_tenth_tick_of_a_combat() -> void:
	assert_true(_start(21))
	assert_true(Game.season_clock(300))
	var slot_text: String = FileAccess.get_file_as_string(Save.slot_path(SLOT))
	var journal_text: String = FileAccess.get_file_as_string(Save.journal_path(SLOT))
	var cmd: Dictionary = RtLive.encounter(ENC, BattleSetup.Advantage.NORMAL, "st1b_journal")
	var auto: Dictionary = RtLive.autopilot_fight(ENC, BattleSetup.Advantage.NORMAL, "st1b_journal")
	assert_false(auto.is_empty(), "the reference: the autopilot from the combat's start")
	var reference: String = StateHash.of(Game.state)
	# the same moment again (the save and its journal), now with a person playing
	_quit()
	_write(Save.slot_path(SLOT), slot_text)
	_write(Save.journal_path(SLOT), journal_text)
	assert_eq(Save.load_slot(SLOT), OK)
	var before: String = FileAccess.get_file_as_string(Save.slot_path(SLOT))
	assert_not_null(Game.make_rt_setup(cmd))
	var snaps: Array[String] = [FileAccess.get_file_as_string(Save.journal_path(SLOT))]
	var bot: RefCounted = Bot.new(Game.combat, "typical", 7)
	bot.set("submitter", Game.combat_submit)
	while Game.combat != null and not Game.combat.is_finished() and Game.combat.tick() < 18000:
		Game.combat_boundary()
		bot.call("act")
		bot.call("observe", Game.combat_step())
		if Game.combat.tick() % 10 == 0:
			snaps.append(FileAccess.get_file_as_string(Save.journal_path(SLOT)))
	assert_true(Game.combat.is_finished(), "the person's fight ends")
	var inputs: int = CommandJournal.parse(snaps.back())["entries"].size()
	Game.end_combat()
	assert_ne(StateHash.of(Game.state), reference, "the person's inputs make a different fight")
	assert_gt(snaps.size(), 10, "%d moments to close the app at" % snaps.size())
	assert_gt(inputs, 3, "the journal holds the person's inputs")
	var differ: int = 0
	for i in snaps.size():
		_quit()
		_write(Save.slot_path(SLOT), before)
		_write(Save.journal_path(SLOT), snaps[i])
		if Save.load_slot(SLOT) != OK or Game.state == null or StateHash.of(Game.state) != reference:
			differ += 1
			if differ == 1:
				fail("closed at combat tick %d: not the autopilot's result (%s)" % [i * 10, Save.last_error()])
		elif Game.combat != null or Game.in_battle:
			fail("closed at combat tick %d: the combat is over after the restart" % (i * 10))
	assert_eq(differ, 0, "every moment: the autopilot's result")
