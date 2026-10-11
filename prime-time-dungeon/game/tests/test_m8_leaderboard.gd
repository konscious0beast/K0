extends TestCase
## Leaderboard (05 §10.4, §11.4): insert + rank, top 10, sorting, persistence round trip (also through Save's file I/O),
## corrupt data → empty board (the game keeps running).

const TEST_DIR: String = "user://test_m8_leaderboard"
const EVENT_ID: String = "evt_m8_test"

var _saved_dir: String = ""


func before_each() -> void:
	_saved_dir = Save.save_dir


func after_each() -> void:
	Save.save_dir = _saved_dir
	_remove_tree(TEST_DIR)


func _entry(score: int, name: String, finished: String = "") -> Dictionary:
	return {"schema": 1, "event_id": EVENT_ID, "window_id": "", "league": "pur", "mode": "solo",
		"run_id": "run_local_" + name, "players": [{"player_id": "local", "display_name": name, "role": "kai"}],
		"score": score, "breakdown": {"quest": score}, "quest_complete": true, "floor_timer_left_sec": 0,
		"run_wall_ms": 0, "flags": [], "verified": "local", "finished_at": finished}


func _names(board: Leaderboard) -> Array:
	var out: Array = []
	for e: Dictionary in board.top(99):
		out.append(e["players"][0]["display_name"])
	return out


func test_insert_rank_and_sorting() -> void:
	var b: Leaderboard = Leaderboard.new()
	assert_eq(b.add(_entry(500, "a")), 1)
	assert_eq(b.add(_entry(900, "b")), 1, "new best")
	assert_eq(b.add(_entry(700, "c")), 2)
	assert_eq(b.add(_entry(700, "d")), 3, "equal score, no tie-break data: the earlier entry stays ahead")
	assert_eq(_names(b), ["b", "c", "d", "a"])
	assert_eq(b.top(2).size(), 2)
	assert_eq(b.top(-1), [])
	var copy: Array[Dictionary] = b.top(1)
	copy[0]["score"] = 1
	assert_eq(b.top(1)[0]["score"], 900, "top() hands out copies")


func test_top_ten_kept() -> void:
	var b: Leaderboard = Leaderboard.new()
	for i in 12:
		b.add(_entry(1000 + i * 10, "p%d" % i))
	assert_eq(b.size(), 10, "only the top 10 stay")
	assert_eq(b.top(1)[0]["score"], 1110)
	assert_eq(b.top(10)[9]["score"], 1020, "the two weakest dropped")
	assert_eq(b.add(_entry(5, "late")), 0, "not in the top 10 → rank 0, not stored (run_result: 'Nicht in den Top 10')")
	assert_eq(b.size(), 10)
	assert_eq(b.add(_entry(1025, "mid")), 10, "squeezes in at the end")
	assert_eq(b.add({"score": "viel"}), 0, "entry without a numeric score")


func test_round_trip() -> void:
	var b: Leaderboard = Leaderboard.new()
	for i in 4:
		b.add(_entry(100 * i, "p%d" % i, "2026-11-07T19:0%d:00Z" % i))
	var d: Dictionary = b.to_dict()
	assert_eq(d["schema"], 1)
	var back: Leaderboard = Leaderboard.from_dict(JSON.parse_string(JSON.stringify(d)))
	assert_eq(back.to_dict(), d, "JSON round trip lossless (ints normalized)")
	assert_eq(_names(back), ["p3", "p2", "p1", "p0"])


func test_corrupt_data_gives_an_empty_board() -> void:
	for raw: Dictionary in [{}, {"entries": "kaputt"}, {"schema": 99, "entries": []}, {"entries": [1, "x", null]}]:
		var b: Leaderboard = Leaderboard.from_dict(raw)
		assert_not_null(b, "never null: " + str(raw))
		assert_eq(b.size(), 0, str(raw))
	var mixed: Leaderboard = Leaderboard.from_dict({"schema": 1, "entries": [_entry(10, "ok"), {"name": "no score"},
		_entry(30, "ok2"), "junk"]})
	assert_eq(_names(mixed), ["ok2", "ok"], "valid entries survive, re-sorted")
	var many: Array = []
	for i in 15:
		many.append(_entry(i, "e%d" % i))
	assert_eq(Leaderboard.from_dict({"schema": 1, "entries": many}).size(), 10, "capped at 10 on load")


## Save I/O (M2, CR-8): survives a "restart" (new board from the file); a corrupt file is discarded.
func test_persistence_through_save() -> void:
	Save.save_dir = TEST_DIR + "/saves"
	var b: Leaderboard = Leaderboard.new()
	b.add(_entry(4242, "Kai"))
	assert_eq(Save.save_leaderboard(EVENT_ID, b.to_dict()), OK)
	var loaded: Leaderboard = Leaderboard.from_dict(Save.load_leaderboard(EVENT_ID))
	assert_eq(loaded.to_dict(), b.to_dict(), "board restored from user://…/leaderboards/<event_id>.json")
	var path: String = TEST_DIR + "/leaderboards/" + EVENT_ID + ".json"
	assert_true(FileAccess.file_exists(path), path)
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{ kaputt")
	f.close()
	var broken: Leaderboard = Leaderboard.from_dict(Save.load_leaderboard(EVENT_ID))
	assert_eq(broken.size(), 0, "corrupt file → empty board, no crash")
	assert_eq(broken.add(_entry(1, "neu")), 1, "the game keeps running")


func _remove_tree(dir_path: String) -> void:
	var d: DirAccess = DirAccess.open(dir_path)
	if d == null:
		return
	for sub: String in d.get_directories():
		_remove_tree(dir_path + "/" + sub)
	for file: String in d.get_files():
		DirAccess.remove_absolute(dir_path + "/" + file)
	DirAccess.remove_absolute(dir_path)
