extends TestCase
## RunLog (Brief §6b.3, 05 §10.6, §11.4): to_dict/from_dict round trip, stable digest(), commands in tick order,
## strictly increasing cmd ids (duplicate → rejected), 2 Hz position samples, checkpoints.


func _log() -> RunLog:
	var rl: RunLog = RunLog.new()
	rl.header = {"schema": 1, "seed": 424242, "slot": 0, "player_name": "Kai", "mode": "event_offline",
		"difficulty": "prime", "game_version": "0.1.0", "sim_hz": 30, "event_id": "evt_offline_gleis9",
		"run_id": "run_local_424242"}
	rl.add_cmd(0, {"t": "floor", "floor": 1}, 1)
	rl.add_cmd(0, {"t": "encounter", "enc": "enc_f1_a1_tutorial", "adv": 0, "group": "f1_g0"}, 2)
	rl.add_cmd(0, {"t": "battle", "cmd": {"kind": "attack", "actor": "p0", "skill": "", "item": "", "targets": ["e0"]},
		"auto": true}, 3)
	var gift: Dictionary = Gift.make_dev("gold", "", 100)
	gift["gift_id"] = "g_dev_0001"
	rl.add_cmd(300, {"t": "gift", "gift": gift}, 0)
	rl.add_cmd(395, {"t": "room", "cell": [4, 6]}, 4)
	rl.add_pos(0, Vector3(1.04, 0.0, -2.26))
	rl.add_pos(15, Vector3(2.0, 0.0, -3.0))
	rl.add_checkpoint(300, "9b1e" + "0".repeat(60))
	rl.result = {"cause": "floor_completed", "score": 14210, "final_hash": "77d2" + "0".repeat(60)}
	return rl


func test_round_trip_and_json() -> void:
	var rl: RunLog = _log()
	var d: Dictionary = rl.to_dict()
	for key: String in ["header", "frames", "pos", "cmds", "checkpoints", "result"]:
		assert_true(d.has(key), "05 §10.6 key " + key)
	var back: RunLog = RunLog.from_dict(d)
	assert_eq(back.to_dict(), d, "from_dict(to_dict()) is lossless")
	assert_eq(back.digest(), rl.digest())
	var parsed: Variant = JSON.parse_string(JSON.stringify(d))
	var from_json: RunLog = RunLog.from_dict(parsed)
	assert_eq(from_json.digest(), rl.digest(), "JSON round trip (ints → floats) keeps the digest")
	assert_eq(typeof(from_json.cmds()[0]["c"]["floor"]), TYPE_INT, "numbers normalized back to int")
	assert_eq(from_json.last_cmd_id(), 4)
	assert_eq(from_json.result["score"], 14210)


func test_digest_is_stable_and_sensitive() -> void:
	var a: RunLog = _log()
	var b: RunLog = _log()
	b.cmds()[0]["c"]["floor"] = 2               # cmds() hands out copies
	assert_true(a.digest().length() == 64)
	assert_eq(a.digest(), b.digest(), "same content → same digest; cmds() copies do not leak")
	b.add_cmd(400, {"t": "rest"}, 5)
	assert_ne(a.digest(), b.digest(), "a further command changes the digest")
	var c: RunLog = _log()
	c.header["seed"] = 424243
	assert_ne(a.digest(), c.digest(), "the header is part of the digest")


func test_commands_stay_in_tick_order() -> void:
	var rl: RunLog = RunLog.new()
	rl.add_cmd(10, {"t": "rest"}, 1)
	rl.add_cmd(10, {"t": "rest"}, 2)
	rl.add_cmd(5, {"t": "rest"}, 3)
	assert_eq(rl.size(), 2, "a command with a smaller tick than the last one is rejected")
	assert_eq(rl.rejected, 1)
	rl.add_cmd(-1, {"t": "rest"}, 4)
	assert_eq(rl.size(), 2, "negative ticks are rejected")
	var ks: Array = []
	for e: Dictionary in rl.cmds():
		ks.append(e["k"])
	assert_eq(ks, [10, 10])


func test_cmd_ids_strictly_increase() -> void:
	var rl: RunLog = RunLog.new()
	rl.add_cmd(0, {"t": "rest"}, 1)
	rl.add_cmd(0, {"t": "rest"}, 1)
	assert_eq(rl.size(), 1, "duplicate cmd id → rejected")
	rl.add_cmd(0, {"t": "gift", "gift": {}}, 0)
	rl.add_cmd(0, {"t": "gift", "gift": {}}, 0)
	assert_eq(rl.size(), 3, "external inputs carry id 0, any number of them")
	rl.add_cmd(1, {"t": "rest"}, 3)
	rl.add_cmd(2, {"t": "rest"}, 2)
	assert_eq(rl.size(), 4, "a smaller id after a larger one is rejected")
	assert_eq(rl.last_cmd_id(), 3)
	rl.add_cmd(2, {"t": "rest"}, -2)
	assert_eq(rl.size(), 4, "negative ids are rejected")
	assert_eq(rl.rejected, 3)


func test_from_dict_rejects_manipulated_entries() -> void:
	var d: Dictionary = _log().to_dict()
	var cmds: Array = []
	cmds.assign(d["cmds"])
	d["cmds"] = cmds
	cmds.insert(2, {"k": 0, "id": 2, "c": {"t": "rest"}})       # duplicate id 2
	cmds.append({"k": 1, "id": 9, "c": {"t": "rest"}})          # tick goes backwards
	cmds.append("garbage")
	var rl: RunLog = RunLog.from_dict(d)
	assert_eq(rl.size(), 5, "only the original five commands survive")
	assert_eq(rl.rejected, 3)
	assert_eq(RunLog.from_dict({}).size(), 0, "empty input → empty log")
	assert_eq(RunLog.from_dict({"cmds": "x", "header": 3}).header, {}, "malformed parts are ignored")


func test_positions_are_2hz_decimeters() -> void:
	var rl: RunLog = RunLog.new()
	for t: int in [0, 5, 14, 15, 20, 31, 45]:
		rl.add_pos(t, Vector3(t * 0.1, 0.25, -1.25))
	var pos: Array = rl.to_dict()["pos"]
	assert_eq(pos, [[0, 0, 3, -13], [15, 15, 3, -13], [31, 31, 3, -13]], "≥ 15 ticks apart, dm, rounded half away")


func test_checkpoints() -> void:
	var rl: RunLog = RunLog.new()
	var h1: String = "a".repeat(64)
	var h2: String = "b".repeat(64)
	rl.add_checkpoint(300, h1)
	rl.add_checkpoint(300, h2)
	assert_eq(rl.checkpoints(), [{"k": 300, "h": h2}], "one checkpoint per tick; the later state wins")
	rl.add_checkpoint(200, h1)
	rl.add_checkpoint(400, "")
	assert_eq(rl.checkpoints().size(), 1, "out of order / empty hashes are rejected")
	rl.add_checkpoint(600, h1)
	assert_eq(rl.to_dict()["checkpoints"], [{"k": 300, "h": h2}, {"k": 600, "h": h1}])


func test_commands_are_stored_normalized_and_validated() -> void:
	var rl: RunLog = RunLog.new()
	var cmd: Dictionary = {"t": &"floor", "floor": 1.0}
	rl.add_cmd(0, cmd, 1)
	cmd["floor"] = 7
	var stored: Dictionary = rl.cmds()[0]["c"]
	assert_eq(typeof(stored["t"]), TYPE_STRING, "StringName → String")
	assert_eq(typeof(stored["floor"]), TYPE_INT, "integral float → int")
	assert_eq(stored["floor"], 1, "a deep copy: later changes by the caller do not leak in")
	assert_len(rl.validate(), 0)
	rl.add_cmd(0, {"t": "teleport"}, 2)
	rl.add_cmd(0, {"t": "buy", "item": "itm_bandage", "qty": 0, "safe_room": ""}, 3)
	var errs: PackedStringArray = rl.validate()
	assert_eq(errs.size(), 2, "validate() reports schema problems: %s" % "; ".join(errs))
	assert_has(errs[0], "cmd 1 (k 0)")
