extends TestCase
## 10 §6.9 test_sd_replay (SD2-B): SdLog.replay plays a duel back bit-exactly (hash, result; also after a JSON round
## trip of the log), forged moves and results are errors, version_status names other versions and rules (such logs
## are not replayed), a snapshot → from_dict continues identically, and the preview never changes the hash (1 000
## calls).

const Sx := preload("res://tests/test_sd_fixture.gd")
const P: int = SdDuel.Side.PLAYER
const O: int = SdDuel.Side.OPPONENT


func _logged(opp: String, deck: String, seed: int, profile: String) -> Dictionary:
	return Sx.full_duel(Sx.book(), opp, Sx.harness_deck(deck), seed, profile)


func test_the_replay_is_bit_exact() -> void:
	var b: SdRulebook = Sx.book()
	var cases: Array = [["sdo_ferdi", "start", 1, "gut"], ["sdo_graf", "start", 2, "zufall"],
		["sdo_ulla", "ulla_passend", 3, "gut"], ["sdo_meister", "meister_passend", 4, "einfach"],
		["sdo_meister", "start", 5, "gut"]]
	for c: Array in cases:
		var r: Dictionary = _logged(str(c[0]), str(c[1]), int(c[2]), str(c[3]))
		var duel: SdDuel = r["duel"]
		var l: SdLog = r["log"]
		assert_true(duel.is_finished(), "%s: finished" % str(c))
		var rep: Dictionary = l.replay(b)
		assert_eq([rep["ok"], rep["error"], rep["hash"], rep["result"]],
			[true, "", duel.state_hash(), l.result], "%s: bit-exact replay" % str(c))
		var parsed: Variant = JSON.parse_string(JSON.stringify(l.to_dict()))
		var back: SdLog = SdLog.from_dict(parsed as Dictionary)
		assert_eq(back.to_dict(), l.to_dict(), "the log survives JSON")
		assert_eq(back.replay(b)["hash"], duel.state_hash(), "%s: replay after JSON" % str(c))
		assert_eq(SdLog.version_status(l.to_dict(), b), SdLog.OK)
		for key: String in ["v", "sd_version", "rh", "seed", "opp", "tut", "deck", "moves", "res", "h"]:
			assert_has(l.to_dict(), key)
	var t: SdDuel = SdDuel.new(SdSetup.lernduell(b, 4), b)
	var tl: SdLog = SdLog.begin(t.setup)
	t.start()
	Sx.play_out(t, "gut", tl)
	var tr: Dictionary = tl.replay(b)
	assert_eq([tr["ok"], tr["result"]], [true, "won"], "the Lernduell replays")
	var f: SdDuel = Sx.player_first(b, "sdo_graf", 1)
	var fl: SdLog = SdLog.begin(f.setup)
	fl.add({"op": "forfeit"})
	f.submit({"op": "forfeit"})
	fl.finish(f)
	assert_eq(fl.replay(b)["result"], "forfeit", "a forfeit replays")


func test_auto_moves_are_marked_and_replay_alike() -> void:
	var b: SdRulebook = Sx.book()
	var d: SdDuel = SdDuel.new(SdSetup.create(b, "sdo_graf", b.startmappe_list(), 21), b)
	var l: SdLog = SdLog.begin(d.setup)
	d.start()
	var n: int = 0
	while not d.is_finished() and n < 300:
		n += 1
		if d.side_to_move() == P:
			var m: Dictionary = SdAi.suggest(d)
			l.add(m, n % 3 == 0)
			d.submit(m)
		else:
			d.submit(d.opponent_move())
	l.finish(d)
	var marked: int = 0
	for m: Dictionary in l.moves:
		assert_false(m.has("hint"), "the hint is not logged")
		marked += 1 if bool(m.get("a", false)) else 0
	assert_gt(marked, 0, "auto moves carry a: true")
	assert_eq(l.replay(b)["hash"], d.state_hash())


func test_forged_moves_and_results_are_errors() -> void:
	var b: SdRulebook = Sx.book()
	var r: Dictionary = _logged("sdo_ulla", "start", 7, "gut")
	var good: Dictionary = (r["log"] as SdLog).to_dict()
	var bad_slot: Dictionary = good.duplicate(true)
	(bad_slot["moves"] as Array)[2] = {"op": "play", "slot": 7}
	var rep: Dictionary = SdLog.from_dict(bad_slot).replay(b)
	assert_eq([rep["ok"], rep["mismatch_at"]], [false, 2], "an illegal move: %s" % str(rep["error"]))
	var other: Dictionary = good.duplicate(true)
	var m0: Dictionary = (other["moves"] as Array)[0]
	m0["op"] = "file" if str(m0["op"]) == "play" else "play"
	m0["slot"] = 0
	rep = SdLog.from_dict(other).replay(b)
	assert_false(rep["ok"], "another legal move: the result or the hash gives it away (%s)" % str(rep["error"]))
	var res: Dictionary = good.duplicate(true)
	res["res"] = "won" if str(good["res"]) != "won" else "lost"
	rep = SdLog.from_dict(res).replay(b)
	assert_eq([rep["ok"], str(rep["error"]).begins_with("result mismatch")], [false, true], str(rep["error"]))
	var short: Dictionary = good.duplicate(true)
	(short["moves"] as Array).pop_back()
	rep = SdLog.from_dict(short).replay(b)
	assert_eq(rep["ok"], false, "a log that ends before the duel: %s" % str(rep["error"]))
	var long: Dictionary = good.duplicate(true)
	(long["moves"] as Array).append({"op": "play", "slot": 0})
	rep = SdLog.from_dict(long).replay(b)
	assert_eq([rep["ok"], rep["mismatch_at"]], [false, (good["moves"] as Array).size()], "moves after the end")
	var reseeded: Dictionary = good.duplicate(true)
	reseeded["seed"] = "8"
	assert_false(SdLog.from_dict(reseeded).replay(b)["ok"], "another seed")
	var deck: Dictionary = good.duplicate(true)
	(deck["deck"] as Array)[0] = "sdc_amtsstempel"
	(deck["deck"] as Array)[1] = "sdc_amtsstempel"
	(deck["deck"] as Array)[2] = "sdc_amtsstempel"
	rep = SdLog.from_dict(deck).replay(b)
	assert_true(str(rep["error"]).begins_with("bad setup"), "3 × Großer Amtsstempel: " + str(rep["error"]))
	var hash_only: Dictionary = good.duplicate(true)
	hash_only["h"] = "0".repeat(64)
	assert_eq(SdLog.from_dict(hash_only).replay(b)["error"], "hash mismatch at the end of the duel")


func test_version_status() -> void:
	var b: SdRulebook = Sx.book()
	var good: Dictionary = (_logged("sdo_ferdi", "start", 3, "gut")["log"] as SdLog).to_dict()
	var cases: Array = [["sd_version", SdDuel.SD_VERSION - 1, SdLog.OLD_VERSION],
		["sd_version", SdDuel.SD_VERSION + 1, SdLog.NEW_VERSION], ["v", SdLog.LOG_VERSION + 1, SdLog.NEW_VERSION],
		["v", 0, SdLog.OLD_VERSION], ["rh", "f".repeat(64), SdLog.OTHER_RULES]]
	for c: Array in cases:
		var d: Dictionary = good.duplicate(true)
		d[str(c[0])] = c[1]
		assert_eq(SdLog.version_status(d, b), str(c[2]), "%s = %s" % [c[0], str(c[1])])
		var rep: Dictionary = SdLog.from_dict(d).replay(b)
		assert_eq([rep["ok"], rep["version"], rep["hash"]], [false, str(c[2]), ""], "not replayed: " + str(c[2]))
	assert_eq(SdLog.version_status(good, b), SdLog.OK)
	assert_eq(SdLog.version_status(good, null), SdLog.OTHER_RULES)


func test_a_snapshot_continues_identically() -> void:
	var b: SdRulebook = Sx.book()
	for opp: String in ["sdo_meister", "sdo_ulla"]:
		var d: SdDuel = SdDuel.new(SdSetup.create(b, opp, Sx.harness_deck("meister_erster_besuch"), 13), b)
		d.start()
		var rng: RandomNumberGenerator = make_rng(13)
		var cut: int = 0
		while not d.is_finished() and cut < 200:
			cut += 1
			if cut % 7 == 0:
				var snap: Dictionary = d.to_dict()
				var copy: SdDuel = SdDuel.from_dict(JSON.parse_string(JSON.stringify(snap)) as Dictionary, b)
				assert_eq(copy.to_dict(), snap, "%s @%d: from_dict(to_dict()) round trip" % [opp, cut])
				assert_eq(copy.state_hash(), d.state_hash(), "the same hash")
				var a: SdDuel = SdDuel.from_dict(snap, b)
				var ea: Array = []
				var ec: Array = []
				var guard: int = 0
				while not a.is_finished() and guard < 200:
					guard += 1
					var m: Dictionary = Sx.bot_move(a, "gut", rng)
					ea.append_array(Sx.dicts(a.submit(m)))
					ec.append_array(Sx.dicts(copy.submit(m)))
				assert_eq(ec, ea, "%s @%d: identical events to the end" % [opp, cut])
				assert_eq(copy.state_hash(), a.state_hash(), "… and the same final hash")
			d.submit(Sx.bot_move(d, "gut", rng))


func test_the_preview_never_changes_the_hash() -> void:
	var b: SdRulebook = Sx.book()
	var calls: int = 0
	var checked: int = 0
	var s: int = 0
	while calls < 1000 and s < 40:
		s += 1
		var d: SdDuel = SdDuel.new(SdSetup.create(b, b.opponent_ids[s % 4], Sx.harness_deck("meister_passend"),
			500 + s), b)
		d.start()
		var rng: RandomNumberGenerator = make_rng(s)
		var guard: int = 0
		while not d.is_finished() and guard < 200 and calls < 1000:
			guard += 1
			if d.side_to_move() == P:
				var h: String = d.state_hash()
				var snap: Dictionary = d.to_dict()
				for m: Dictionary in d.legal_moves():
					d.preview(m)
					calls += 1
				assert_eq(d.state_hash(), h, "previews leave the hash alone")
				assert_eq(d.to_dict(), snap, "… and the whole state")
				var move: Dictionary = Sx.bot_move(d, "gut", rng)
				var pv: Dictionary = d.preview(move)
				var before: Array[int] = [d.geduld(P), d.geduld(O)]
				d.submit(move)
				if not pv.is_empty():
					assert_eq(pv["geduld"], [d.geduld(P), d.geduld(O)], "the dry run predicted the Geduld")
					assert_eq(pv["delta"], [d.geduld(P) - before[0], d.geduld(O) - before[1]])
					assert_eq(bool(pv["ends"]), d.is_finished())
					checked += 1
			else:
				d.submit(d.opponent_move())
	assert_true(calls >= 1000, "1 000 preview calls (%d)" % calls)
	assert_gt(checked, 50, "previews compared with the real move")
