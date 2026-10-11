extends TestCase
## 07 §10.2–§10.5 (R5a): the real-time branch of RunSim — a core run (RunSim-driven: no Show, no system gifts) with a
## flight, a won fight with ~200 inputs, a hint card and an external gift at a boundary, and a lost boss fight replays
## bit for bit through RunSim.replay (state and combat checkpoints); a deviation is caught at its checkpoint; entries
## after a combat's end, out of order, at another k, a second gift of a boundary, a gift after the tick's inputs and a
## recorded system gift are errors; compact() / expand() are lossless and a compacted log replays the same.

const RtLive := preload("res://tests/fixtures/rt_live/rt_live.gd")


func before_each() -> void:
	RtLive.swap_data()


func after_each() -> void:
	RtLive.restore_data()


## The canned commands with an external gift at the boundary of tick 40 (after the hint at 5, before the inputs of 40).
static func _canned_with_gift() -> Array:
	var out: Array = []
	var placed: bool = false
	for c: Dictionary in RtKit.canned_commands():
		if not placed and int(c["ct"]) >= 40:
			out.append({"t": "gift", "ct": 40, "gift": Gift.make_dev("gold", "", 100)})
			placed = true
		out.append(c)
	return out


## The core run of this file; returns [sim, final hash of close()].
func _core_run() -> Array:
	var st: GameState = RtLive.state(6, 20.0, {"itm_smoke": 1, "itm_brutzel_burger": 2, "itm_energy_krawumm": 1,
		"itm_molotov": 1})
	var sim: RunSim = RtLive.core_sim(st)
	sim.apply({"t": "sponsor_window", "op": "dev_open", "sec": 60, "slots": 3})
	sim.apply(RtKit.dummy_cmd())
	assert_eq(RtLive.core_play(sim, [RtCommand.item(12, "p0", "itm_smoke", "")]), [])
	sim.apply({"t": "flag", "key": "intro_seen", "value": true})   # any other command: the combat ends first
	assert_null(sim.combat, "the flight ended the first combat")
	sim.apply(RtKit.canned_encounter())
	assert_not_null(sim.combat, "a real-time combat runs")
	assert_false(sim.is_clock_running(), "the clock stands while it runs")
	var refused: Array = RtLive.core_play(sim, _canned_with_gift())
	for r: Variant in refused:
		assert_true(RtCommand.REASONS.has(str(r)) or str(r) == "combat_cmd_after_end", "a sim refusal: " + str(r))
	# R5b: the canned combat's partner tactic is kept (BattleResult.rt_presets) — the boss fight records the default
	# tactic like the exploration records the partner's (07 §10.1), so it stays the lost fight of this run
	var preset: String = str(RtKit.data().party_member("mopsula").rt.get("default_preset", "support"))
	sim.apply(RtKit.encounter("enc_rt_test_boss", [["g_boss", "enc_rt_test_boss", [0, -200, 128]]],
		{"presets": {"p1": {"preset": preset, "tog": RtVocab.RT_TOGGLE_DEFAULTS.duplicate()}}}))
	RtLive.core_play(sim, [RtCommand.ability(2, "p0", "skl_kai_heavy_swing", "e0")])
	var h: String = sim.close("test")
	assert_null(sim.combat, "close() let the sim finish the boss combat")
	assert_true(sim.is_over(), "the boss won: the run is over")
	return [sim, h]


func test_core_run_replays_bit_for_bit() -> void:
	var run: Array = _core_run()
	var sim: RunSim = run[0]
	var rl: RunLog = RtLive.round_trip(sim.run_log)
	var types: Array = RtLive.cmd_types(rl)
	assert_true(types.has("combat_hint") and types.has("gift") and types.has("move_sample"), str(types))
	var ends: int = 0
	for cp: Dictionary in rl.combat_checkpoints():
		if int(cp["ct"]) % 300 != 0:                        # (none of these combats ends on a multiple of 300)
			ends += 1
	assert_eq(ends, 3, "every combat writes its end checkpoint, all three at the same k (07 §10.2)")
	assert_eq(rl.validate(), PackedStringArray())
	var res: Dictionary = RunSim.replay(RtKit.data(), rl)
	assert_eq(res["errors"], PackedStringArray())
	assert_eq(res["mismatch_at"], -1)
	assert_eq(res["combat_mismatch_at"], -1)
	assert_eq(res["final_hash"], run[1], "RunSim.replay ≡ the recorded core run")
	assert_true(bool((res["result"] as Dictionary)["over"]))
	var gift_row: Dictionary = {}
	for row: Dictionary in rl.cmds():
		if str((row["c"] as Dictionary)["t"]) == "gift":
			gift_row = row
	assert_eq([int(gift_row["id"]), int((gift_row["c"] as Dictionary)["ct"])], [0, 40], "id 0 and its ct")


func test_a_deviation_is_caught_at_its_checkpoint() -> void:
	var rl: RunLog = (_core_run()[0] as RunSim).run_log
	var good: Dictionary = rl.to_dict()
	var cps: Array = good["checkpoints"]
	var i_cp: int = -1
	for i in cps.size():
		if (cps[i] as Dictionary).has("ct") and int((cps[i] as Dictionary)["ct"]) == 300:
			i_cp = i
			break
	assert_true(i_cp >= 0, "a periodic combat checkpoint (CHECKPOINT_TICKS)")
	var d1: Dictionary = good.duplicate(true)
	((d1["checkpoints"] as Array)[i_cp] as Dictionary)["h"] = "f".repeat(64)
	var r1: Dictionary = RunSim.replay(RtKit.data(), RunLog.from_dict(d1))
	assert_eq([r1["mismatch_at"], r1["combat_mismatch_at"]], [i_cp, i_cp], "the replay stops trusting at that index")
	var d2: Dictionary = good.duplicate(true)
	for i in (d2["cmds"] as Array).size():
		var c: Dictionary = ((d2["cmds"] as Array)[i] as Dictionary)["c"]
		if str(c["t"]) == "combat_item":
			c["item"] = "itm_energy_krawumm"                # another item at the same tick
			break
	assert_true(int(RunSim.replay(RtKit.data(), RunLog.from_dict(d2))["combat_mismatch_at"]) >= 0, "a changed input")


## Forged combat entries: the log check (RunLog.validate) and the core (combat_refusal, RtSim.submit) report them.
func test_forged_combat_entries_are_errors() -> void:
	var st: GameState = RtLive.state(3, 20.0, {"itm_smoke": 1})
	var sim: RunSim = RtLive.core_sim(st)
	sim.apply({"t": "sponsor_window", "op": "dev_open", "sec": 60, "slots": 3})
	sim.apply(RtKit.dummy_cmd())
	RtLive.core_play(sim, [RtCommand.target(0, "p0", "e0"), RtCommand.ability(4, "p0", "skl_kai_heavy_swing", "e0")])
	var sync: Array = RtLive.core_play(sim, [RtCommand.item(30, "p0", "itm_smoke", ""), RtCommand.hint(30, "flee")])
	assert_eq(sync, [], "smoke and a hint")
	sim.close("test")
	var good: Dictionary = sim.run_log.to_dict()
	assert_eq(RunSim.replay(RtKit.data(), RunLog.from_dict(good))["errors"], PackedStringArray())
	var k: int = int(((good["cmds"] as Array)[1] as Dictionary)["k"])
	# (a) an input after the end; (b) the hint of the last tick passes; (c) ct out of order; (d) another k
	var end_ct: int = -1
	for cp: Dictionary in RunLog.from_dict(good).combat_checkpoints():
		end_ct = int(cp["ct"])
	var cases: Array = [
		[[k, RtCommand.target(end_ct + 5, "p0", "")], "combat_cmd_after_end"],
		[[k, RtCommand.hint(end_ct, "zone")], ""],
		[[k + 1, RtCommand.target(end_ct, "p0", "")], "its combat runs at k"],
	]
	for case: Array in cases:
		var d: Dictionary = good.duplicate(true)
		var cmds: Array = d["cmds"]
		var at: int = cmds.size()
		for i in cmds.size():
			if str(((cmds[i] as Dictionary)["c"] as Dictionary)["t"]) == "combat_hint":
				at = i + 1
		var last_id: int = int((cmds[at - 1] as Dictionary)["id"])
		for i in range(at, cmds.size()):
			(cmds[i] as Dictionary)["id"] = int((cmds[i] as Dictionary)["id"]) + 1
		cmds.insert(at, {"k": int((case[0] as Array)[0]), "id": last_id + 1, "c": (case[0] as Array)[1]})
		var res: Dictionary = RunSim.replay(RtKit.data(), RunLog.from_dict(d))
		var errs: String = ", ".join(res["errors"])
		if str(case[1]) == "":
			assert_eq(res["errors"], PackedStringArray(), "the hint of the end tick: " + errs)
		else:
			assert_true(errs.contains(str(case[1])), "%s: %s" % [str(case[1]), errs])
	# (e) ct out of order inside a combat: the first target change moved behind the ability of tick 4
	var d5: Dictionary = good.duplicate(true)
	for row: Variant in (d5["cmds"] as Array):
		var c5: Dictionary = (row as Dictionary)["c"]
		if str(c5["t"]) == "target_change":
			c5["ct"] = 10
			break
	var v5: String = ", ".join(RunLog.from_dict(d5).validate())
	assert_true(v5.contains("ct 4 is out of order (last 10)"), v5)
	assert_true(", ".join(RunSim.replay(RtKit.data(), RunLog.from_dict(d5))["errors"]).contains("past_tick"))


## The boundary rules of a recorded gift (07 §9.2): one per boundary, before the inputs of its tick, external only.
func test_gift_boundary_rules() -> void:
	var st: GameState = RtLive.state(3, 20.0)
	var sim: RunSim = RtLive.core_sim(st)
	sim.apply({"t": "sponsor_window", "op": "dev_open", "sec": 60, "slots": 3})
	sim.apply(RtKit.dummy_cmd())
	var reasons: Array = RtLive.core_play(sim, [
		{"t": "gift", "ct": 3, "gift": Gift.make_dev("gold", "", 50)},
		{"t": "gift", "ct": 3, "gift": Gift.make_dev("gold", "", 60)},
		RtCommand.target(5, "p0", "e0"),
		{"t": "gift", "ct": 5, "gift": Gift.make_dev("gold", "", 70)},
		{"t": "gift", "ct": 6, "gift": Gift.make_system("spn_gluckwasser", 1, 0)},
		{"t": "gift", "ct": 2, "gift": Gift.make_dev("gold", "", 80)},
	])
	assert_eq(reasons, ["gift_twice", "gift_order", "system_gift", "past_tick"])
	var gifts: Array = []
	for row: Dictionary in sim.run_log.cmds():
		if str((row["c"] as Dictionary)["t"]) == "gift":
			gifts.append(int((row["c"] as Dictionary)["ct"]))
	assert_eq(gifts, [3], "only the accepted gift is recorded")


func test_compact_and_expand_are_lossless() -> void:
	var run: Array = _core_run()
	var rl: RunLog = (run[0] as RunSim).run_log
	var digest: String = rl.digest()
	var n: int = rl.size()
	var c: RunLog = RtLive.round_trip(rl)
	c.compact()
	assert_true(c.has_batches())
	assert_lt(c.size(), n, "runs of move samples became move_batch entries")
	assert_ne(c.digest(), digest, "the stored form differs")
	assert_eq(c.validate(), PackedStringArray(), "a compacted log is valid as it is")
	var batch: Dictionary = {}
	for row: Dictionary in c.cmds():
		if str((row["c"] as Dictionary)["t"]) == "move_batch" and batch.is_empty():
			batch = row
	var s: Array = (batch["c"] as Dictionary)["s"]
	assert_eq(int((batch["c"] as Dictionary)["id0"]), int(batch["id"]), "the entry carries id0")
	assert_true(s.size() >= 2 and int((s[1] as Array)[0]) >= 0, "the first row holds ct, the others differences")
	var stored: RunLog = RtLive.round_trip(c)              # what Save.save_replay writes and reads back
	assert_eq(stored.digest(), c.digest())
	assert_eq(stored.last_cmd_id(), rl.last_cmd_id(), "a batch holds its ids (the next command continues after them)")
	stored.expand()
	assert_false(stored.has_batches())
	assert_eq(stored.digest(), digest, "expand() restores the entries bit for bit")
	assert_eq(JSON.stringify(stored.to_dict(), "", true), JSON.stringify(rl.to_dict(), "", true))
	var res: Dictionary = RunSim.replay(RtKit.data(), RtLive.round_trip(c))
	assert_eq(res["errors"], PackedStringArray(), "the verifier replays the expanded form")
	assert_eq(res["final_hash"], run[1])
	assert_eq(res["mismatch_at"], -1)
	# a forged batch (id0 not its entry's id) is not expanded and reported
	var d: Dictionary = c.to_dict()
	for row: Variant in (d["cmds"] as Array):
		var cc: Dictionary = (row as Dictionary)["c"]
		if str(cc["t"]) == "move_batch":
			cc["id0"] = int(cc["id0"]) + 1
			break
	var bad: RunLog = RunLog.from_dict(d)
	assert_true(", ".join(bad.expanded().validate()).contains("move_batch id0"), "a malformed batch stays visible")
