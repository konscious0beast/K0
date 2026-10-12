extends TestCase
## 10 §6.3 / §6.9 test_sd_boundaries (SD1 row 5): the campaign is CTB-free. The five classes of the CTB engine —
## BattleState, CTBQueue, ActionResolver, EnemyAI, AutoPolicy, in core/stempel/ctb since R5b part 2b — appear in code
## lines (comments stripped) only in core/stempel/**, scenes/stempel/**, core/live/state_hash.gd (of_battle /
## battle_hash_input) and the engine's tests (tests/test_m1_*, tests/test_sd_*); the victory drop rule is
## BattleResult.roll_drops, BattleState has none. The campaign side of the boundary: a CTB campaign log of the old
## kernel (sim version 3, kernel 2246c31: no combat_mode in the header, "battle" commands) is an "ältere Version" in
## both verifiers, the leaderboard and the lobby — tagged, never replayed, never a mismatch.

const EventInfo := preload("res://scenes/ui/event_info.gd")
const ENGINE: PackedStringArray = ["BattleState", "CTBQueue", "ActionResolver", "EnemyAI", "AutoPolicy"]
const ENGINE_FILES: PackedStringArray = ["ctb_queue", "battle_state", "action_resolver", "enemy_ai", "auto_policy"]
const ALLOWED: PackedStringArray = ["res://core/stempel/", "res://scenes/stempel/", "res://core/live/state_hash.gd",
	"res://tests/test_m1_", "res://tests/test_sd_"]
const CTB_LOG: String = "res://tests/fixtures/live/run_log_sim_v3_ctb.json"


## Every .gd file below `dir` (hidden folders such as .godot skipped).
static func _scripts(dir: String, out: PackedStringArray) -> void:
	for f: String in DirAccess.get_files_at(dir):
		if f.get_extension() == "gd":
			out.append(dir.path_join(f))
	for sub: String in DirAccess.get_directories_at(dir):
		if not sub.begins_with("."):
			_scripts(dir.path_join(sub), out)


## The line without its comment: everything from a "#" outside a string literal on.
static func _code(line: String) -> String:
	var quote: String = ""
	var i: int = 0
	while i < line.length():
		var ch: String = line[i]
		if quote != "":
			if ch == "\\":
				i += 1
			elif ch == quote:
				quote = ""
		elif ch == "\"" or ch == "'":
			quote = ch
		elif ch == "#":
			return line.substr(0, i)
		i += 1
	return line


static func _allowed(path: String) -> bool:
	for prefix: String in ALLOWED:
		if path.begins_with(prefix):
			return true
	return false


func test_only_the_stempelduell_names_the_engine() -> void:
	var files: PackedStringArray = []
	_scripts("res://", files)
	assert_gt(files.size(), 300, "the scan sees the project")
	var word: RegEx = RegEx.create_from_string("\\b(" + "|".join(ENGINE) + ")\\b")
	var hits: PackedStringArray = []
	var allowed_hits: int = 0
	for path: String in files:
		var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
		for n in lines.size():
			var m: RegExMatch = word.search(_code(lines[n]))
			if m == null:
				continue
			if _allowed(path):
				allowed_hits += 1
			else:
				hits.append("%s:%d %s" % [path, n + 1, m.get_string()])
	assert_eq(hits, PackedStringArray(), "the five engine classes outside the Stempelduell (10 §6.3)")
	assert_gt(allowed_hits, 100, "the engine and its tests still name them (the scan finds code lines)")


func test_the_engine_lives_in_core_stempel_ctb() -> void:
	for f: String in ENGINE_FILES:
		assert_true(FileAccess.file_exists("res://core/stempel/ctb/%s.gd" % f), f + " moved (SD1 row 1)")
		assert_false(FileAccess.file_exists("res://core/battle/%s.gd" % f), f + " left core/battle")
	assert_true(FileAccess.file_exists("res://core/battle/battle_command.gd"), "BattleCommand stays shared (CR-34)")
	assert_false(DirAccess.dir_exists_absolute("res://scenes/battle"), "the CTB presentation stays deleted (10 §4.1)")


func test_the_drop_rule_is_battle_results() -> void:
	var state_methods: Array = []
	for m: Dictionary in (load("res://core/stempel/ctb/battle_state.gd") as GDScript).get_script_method_list():
		state_methods.append(str(m["name"]))
	assert_false(state_methods.has("roll_drops"), "BattleState.roll_drops is gone (SD1 row 0)")
	var result_methods: Array = []
	for m: Dictionary in (load("res://core/battle/battle_result.gd") as GDScript).get_script_method_list():
		result_methods.append(str(m["name"]))
	assert_has(result_methods, "roll_drops", "the one victory drop rule of both combats (GDD §3.12)")


func test_an_old_ctb_campaign_log_is_an_older_version() -> void:
	var raw: Variant = JsonUtil.read_file(CTB_LOG)
	assert_true(raw is Dictionary, CTB_LOG)
	if not raw is Dictionary:
		return
	var old: RunLog = RunLog.from_dict(raw as Dictionary)
	assert_eq([JsonUtil.to_int(old.header.get("sim_version", 0)), old.header.has("combat_mode"),
		str(old.header.get("mode", ""))], [3, false, "campaign"], "fixture: a CTB campaign log of kernel 2246c31")
	var kinds: Dictionary = {}
	for c: Dictionary in old.cmds():
		kinds[str((c["c"] as Dictionary).get("t", ""))] = true
	assert_true(kinds.has("battle") and kinds.has("encounter"), "with its CTB battle commands: %s" % [kinds.keys()])
	assert_eq(RunSim.version_status(old.header), RunSim.OLD_VERSION)
	var core: Dictionary = RunSim.replay(DB.data, old)
	assert_eq([core["version"], core["mismatch_at"], core["final_hash"]], [RunSim.OLD_VERSION, -1, ""],
		"the core verifier: tagged, not replayed, never a mismatch")
	assert_has("; ".join(core["errors"]), RunSim.OLD_VERSION_TAG)
	var game: Dictionary = Game.replay_log(old)
	assert_eq([game["version"], game["mismatch_at"], game["final_hash"]], [RunSim.OLD_VERSION, -1, ""],
		"the game verifier alike")
	var entry: Dictionary = {"score": 1, "sim_version": JsonUtil.to_int(old.header["sim_version"])}
	assert_eq(Leaderboard.version_status(entry), RunSim.OLD_VERSION, "the leaderboard")
	assert_eq(EventInfo.version_tag(entry), RunSim.OLD_VERSION_TAG, "the lobby's tag")
