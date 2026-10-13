extends TestCase
## 11-L1 (11 §1.10; O-5, SP-4): the language never reaches the simulation. The same scripted runs — a campaign start
## (a safe room in and out, a real-time combat on autopilot, a lootbox, a rest), a season night (the sleep in Gleis 9,
## a Sendepause, 30 hours away; recorded by RunSim, replayed through Game) and the golden Stempelduell — are played in
## German and in English with a full English catalog: every msgid of the four POT files translated (data texts also
## without their context, so tr(def.name) and tr_text() answer in English too), English number formats. Both languages
## give the same StateHash, the same run log (its random run_id aside), the same combat events without their "text"
## and the same duel; a German run log replays in English to the same hash.

const RtLive := preload("res://tests/fixtures/rt_live/rt_live.gd")
const Kit := preload("res://tests/fixtures/season_core/season_core.gd")
const SdGolden := preload("res://tests/test_sd_golden.gd")
const UiUtil := preload("res://scenes/ui/ui_util.gd")
const GameReplayScript := preload("res://autoload/game_replay.gd")
const FULL: String = "user://test_11_lang_full"
const SAVES: String = "user://test_11_lang_saves"

var _lang_was: String = "de"
var _data: GameData = null


func before_each() -> void:
	_lang_was = Tx.lang()
	_data = DB.data
	Save.save_dir = SAVES
	Save.read_only = false


func after_each() -> void:
	LocaleLoader.apply(_lang_was)
	DB.data = _data
	if Game.combat != null:
		Game.end_combat()
	Show.abort_battle()
	Game.state = null
	Game.run_log = null
	Game.sim = null
	Game.season_wake = {}
	Game.timer_running = false
	Game.in_battle = false
	Save._journal_close()
	Save.save_dir = "user://saves"
	_rmrf(SAVES)
	_rmrf(FULL)


# --- the runs ---------------------------------------------------------------------------------------------------------

func _campaign() -> Dictionary:
	Game.new_game(0, "Kai", 4242)
	var srs: Array = DB.floor_def(1).layout.get("safe_rooms", [])
	if not srs.is_empty():
		Game.enter_safe_room(str(srs[0]["id"]))
		Game.leave_safe_room()
	Game.set_flag("intro_seen", true)
	var fight: Dictionary = RtLive.autopilot_fight(DB.floor_def(1).timer_start_after, BattleSetup.Advantage.NORMAL, "")
	if not Game.state.pending_lootboxes.is_empty():
		Game.open_lootbox(Game.state.pending_lootboxes[0])
	Game.rest_full_heal()
	return {"hash": StateHash.of(Game.state), "digest": _digest(Game.run_log), "log": Game.run_log,
		"events": _without_text(fight.get("events", [])), "ticks": int(fight.get("ticks", 0))}


func _night() -> Dictionary:
	var d: GameData = Kit.data(6)
	var sim: RunSim = Kit.sim(d, "ssn_basis", "calendar", "net", 33)
	var layout: FloorLayout = DungeonGenerator.generate(d.floor_def(1), sim.state.floor_run.seed)
	var cell: Vector2i = SleepResolver.NO_CELL
	for c: Vector2i in layout.sorted_cells():
		if SleepResolver.danger_of(d.floor_def(1), layout, c) == 2 and cell == SleepResolver.NO_CELL:
			cell = c
	var ev: Array = []
	ev.append_array(sim.apply({"t": "clock", "sec": 600}))
	ev.append_array(sim.apply({"t": "sleep", "tactic": "attack", "cell": [cell.x, cell.y]}))
	ev.append_array(sim.apply({"t": "season", "v": 1, "op": "pause", "sec": 3 * 3600, "why": "user"}))
	ev.append_array(sim.apply({"t": "away", "sec": 30 * 3600}))
	DB.data = sim.data
	var gr: RefCounted = GameReplayScript.new(Game)
	var g: Dictionary = gr.call("run", sim.run_log, -1)
	var shown: GameState = gr.get("_final_state")
	DB.data = _data
	return {"hash": StateHash.of(sim.state), "digest": _digest(sim.run_log), "meets": Kit.kinds(ev).count("meet"),
		"replayed": StateHash.of(shown) if shown != null else "", "errors": g.get("errors", PackedStringArray())}


func _duel() -> Dictionary:
	var golden: Object = SdGolden.new()
	var run: Dictionary = golden.call("_run")
	var values: Dictionary = SdGolden._values(run)
	values["log"] = CanonicalJson.sha256_hex((run["log"] as SdLog).to_dict())
	return values


# --- the comparison ---------------------------------------------------------------------------------------------------

func test_the_same_runs_in_german_and_english() -> void:
	var de: Dictionary = {"campaign": _campaign(), "night": _night(), "duel": _duel()}
	assert_eq(Tx.lang(), "de")
	var shown_de: String = UiUtil.tr_text("Kanalratte")
	_english()
	assert_eq([Tx.lang(), Tx.fmt_int(12345)], ["en", "12,345"], "English with the full catalog")
	assert_ne(UiUtil.tr_text("Kanalratte"), shown_de, "the display really is English now (tr_text without a context)")
	var en: Dictionary = {"campaign": _campaign(), "night": _night(), "duel": _duel()}
	for part: String in ["campaign", "night"]:
		var a: Dictionary = de[part]
		var b: Dictionary = en[part]
		assert_eq(b["hash"], a["hash"], part + ": StateHash")
		assert_eq(b["digest"], a["digest"], part + ": the run log")
	var ca: Dictionary = de["campaign"]
	var cb: Dictionary = en["campaign"]
	assert_gt(int(ca["ticks"]), 0, "the combat ran")
	assert_eq(cb["events"], ca["events"], "the combat's events without their text")
	var na: Dictionary = de["night"]
	var nb: Dictionary = en["night"]
	assert_gt(int(na["meets"]), 0, "the night met something")
	assert_eq([na["errors"], nb["errors"]], [PackedStringArray(), PackedStringArray()], "Game.replay_log accepts it")
	assert_eq(nb["replayed"], na["replayed"], "the night through Game.replay_log")
	assert_ne(na["replayed"], "")
	assert_eq(en["duel"], de["duel"], "the Stempelduell: hash, events, stream, result, moves, log")
	# a run recorded in German replays in English to the same hash (11 §1.10)
	var replay: Dictionary = Game.replay_log(ca["log"] as RunLog)
	assert_eq([replay["mismatch_at"], replay["final_hash"]], [-1, ca["hash"]], "a German log replays in English")


## The full English catalog: every POT entry "EN " + its msgid (plural forms too); the data texts once more without a
## context — tr_text(def.name) of today's code finds them.
func _english() -> void:
	DirAccess.make_dir_recursive_absolute(FULL.path_join("en"))
	var out: PackedStringArray = ["msgid \"\"", "msgstr \"\"", "\"Language: en\\n\"",
		"\"Content-Type: text/plain; charset=UTF-8\\n\"", "\"Plural-Forms: nplurals=2; plural=(n != 1);\\n\"", ""]
	var seen: Dictionary = {}
	for d: String in LocaleLoader.DOMAINS:
		var pot: Dictionary = LocaleLoader.parse_po(FileAccess.get_file_as_string("res://locale/pot/%s.pot" % d), d)
		for e: Dictionary in pot["entries"]:
			for ctx: String in [str(e["ctx"]), ""]:
				var key: String = ctx + Tx.CTX_SEP + str(e["id"])
				if seen.has(key):
					continue
				seen[key] = true
				if ctx != "":
					out.append(LocaleLoader.po_field("msgctxt", ctx))
				out.append(LocaleLoader.po_field("msgid", str(e["id"])))
				if str(e["plural"]) != "":
					out.append(LocaleLoader.po_field("msgid_plural", str(e["plural"])))
					out.append(LocaleLoader.po_field("msgstr[0]", "EN " + str(e["id"])))
					out.append(LocaleLoader.po_field("msgstr[1]", "EN " + str(e["plural"])))
				else:
					out.append(LocaleLoader.po_field("msgstr", "EN " + str(e["id"])))
				out.append("")
	for d: String in LocaleLoader.DOMAINS:
		var f: FileAccess = FileAccess.open(FULL.path_join("en").path_join(d + ".po"), FileAccess.WRITE)
		f.store_string("\n".join(out) if d == "ui" else "\n".join(out.slice(0, 6)))
		f.close()
	var res: Dictionary = LocaleLoader.apply("en", "", FULL)
	assert_gt(int(res["count"]), 2000, "the full catalog")


## The run log without its random run_id (RunLog.local_run_id): commands, frames, checkpoints, result.
static func _digest(rl: RunLog) -> String:
	var d: Dictionary = rl.to_dict()
	(d["header"] as Dictionary).erase("run_id")
	return CanonicalJson.sha256_hex(d)


static func _without_text(events: Array) -> Array:
	var out: Array = []
	for e: Variant in events:
		var d: Dictionary = (e as ActionEvent).to_dict() if e is ActionEvent else (e as Dictionary).duplicate(true)
		d.erase("text")
		out.append(d)
	return out


static func _rmrf(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for f: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	for sub: String in DirAccess.get_directories_at(path):
		_rmrf(path.path_join(sub))
	DirAccess.remove_absolute(path)
