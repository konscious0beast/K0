extends TestCase
## 07 §10.6 (R5a): scripted live real-time runs through the Game API (the CombatDirector's tick order: hints of the
## halted tick, boundary, inputs, step) and their Game.replay_log give the same GameState hashes, the same combat
## checkpoints and the same Show numbers (hype, followers, viewers, stats, achievements, the Marotten tally per
## combat); RunSim.replay of the same log (the core verifier, no Show) reproduces every combat checkpoint when no
## system gift fell. The runs: a flight (smoke), a won fight with ~200 inputs, hint cards and an external gift, and a
## boss fight with an external and a system gift due in the same tick, a KO with control change and the defeat.

const RtLive := preload("res://tests/fixtures/rt_live/rt_live.gd")

var _snaps: Array = []                       # per finished combat: outcome, ticks, Show numbers (combat_finished)
var _tallies: Array = []                     # per won combat: the MarottenTracker tally (battle_won)
var _gift_events: Array = []                 # [type, tick] of the gift effects at a tick boundary (combat_event)


func before_each() -> void:
	RtLive.swap_data()
	_snaps = []
	_tallies = []
	_gift_events = []
	Events.combat_finished.connect(_on_finished)
	Events.battle_won.connect(_on_won)
	Events.combat_event.connect(_on_event)


func after_each() -> void:
	Events.combat_finished.disconnect(_on_finished)
	Events.battle_won.disconnect(_on_won)
	Events.combat_event.disconnect(_on_event)
	if Game.combat != null:
		Game.end_combat()
	Show.abort_battle()
	Game.state = null
	Game.run_log = null
	Game.sim = null
	Game.in_battle = false
	RtLive.restore_data()


func _on_finished(r: RefCounted) -> void:
	var res: BattleResult = r as BattleResult
	_snaps.append({"outcome": int(res.outcome), "ticks": res.duration_ticks, "party_turns": res.party_turns,
		"hype": Show.hype(), "followers": Show.followers(), "viewers": Show.viewers(),
		"stats": Game.state.show.stats.duplicate(true), "achievements": Array(Game.state.show.achievements),
		"hash": StateHash.of(Game.state)})


func _on_won(_payload: Dictionary) -> void:
	_tallies.append(Show._marotten.tally() if Show._marotten != null else {})


func _on_event(e: RefCounted) -> void:
	var ev: ActionEvent = e as ActionEvent
	if int(ev.rt.get("boundary", 0)) == 1:
		_gift_events.append([ActionEvent.type_name(ev.type), ev.tick])


## The live numbers, then Game.replay_log of the run log: no errors, every checkpoint (state and combat) matches, the
## same final hash and the same per-combat Show numbers / tallies / gift ticks. Returns the replay result.
func _assert_replay_equals_live() -> Dictionary:
	var live_hash: String = StateHash.of(Game.state)
	var snaps: Array = _snaps.duplicate(true)
	var tallies: Array = _tallies.duplicate(true)
	var gifts: Array = _gift_events.duplicate(true)
	_snaps = []
	_tallies = []
	_gift_events = []
	var cps: int = Game.run_log.combat_checkpoints().size()
	assert_gt(cps, 0, "combat checkpoints were written")
	var res: Dictionary = Game.replay_log(Game.run_log)
	assert_eq(res["errors"], PackedStringArray(), "the live log replays without errors")
	assert_eq(res["mismatch_at"], -1, "every checkpoint matches")
	assert_eq(res["combat_mismatch_at"], -1, "every combat checkpoint (StateHash.of_rt) matches")
	assert_eq(res["final_hash"], live_hash, "Game.replay_log ≡ live run")
	assert_eq(_snaps, snaps, "per combat: outcome, ticks, hype, followers, viewers, stats, achievements, hash")
	assert_eq(_tallies, tallies, "the Marotten tally of every won combat")
	assert_eq(_gift_events, gifts, "the gift effects at the same tick boundaries")
	return res


func test_flight_victory_hints_and_an_external_gift() -> void:
	var st: GameState = RtLive.state(6, 20.0, {"itm_smoke": 2, "itm_brutzel_burger": 2, "itm_energy_krawumm": 1,
		"itm_molotov": 1})
	RtLive.adopt(st)
	assert_true(Game.is_realtime(), "the anchored state plays real-time combats")
	assert_true(Game.open_dev_sponsor_window(60, 3), "viewer gifts need an open Sponsor-Fenster (recorded)")
	var r1: Dictionary = RtLive.fight(RtKit.dummy_cmd(), [RtCommand.item(12, "p0", "itm_smoke", "")])
	assert_eq(int((r1["result"] as BattleResult).outcome), BattleResult.Outcome.FLED, "the smoke ends it")
	var gift: Dictionary = Gift.make_dev("gold", "", 100)
	var arrive: Callable = func(c: int) -> void:
		if c == 39:
			assert_eq(Show.receive_gift(gift)["apply"], "queued", "in a combat a gift waits for the next boundary")
	var r2: Dictionary = RtLive.fight(RtKit.canned_encounter(), RtKit.canned_commands(), 6000, arrive)
	assert_eq(int((r2["result"] as BattleResult).outcome), BattleResult.Outcome.VICTORY)
	assert_gt(int((r2["answers"] as Dictionary).get("", 0)), 100, "most of the ~200 inputs were taken")
	var gifts: Array = []
	var hints: Array = []
	var k_enc: int = -1
	for row: Dictionary in Game.run_log.cmds():
		var c: Dictionary = row["c"]
		match str(c["t"]):
			"encounter":
				k_enc = int(row["k"])
			"gift":
				gifts.append([int(row["id"]), int(c.get("ct", -1)), int(row["k"]) == k_enc])
			"combat_hint":
				hints.append([str(c["id"]), int(c["ct"])])
	assert_eq(gifts, [[0, 40, true]], "recorded at its application: cmd id 0, ct 40, the k of its combat")
	assert_eq(hints, [["bar1", 5]], "the hint card at its halted tick")
	assert_true(bool((Game.state.flags.get("rt_hints", {}) as Dictionary).get("bar1", false)))
	assert_true(_gift_events.has(["CREDITS_GAINED", 40]), "applied at the boundary of tick 40: " + str(_gift_events))
	var r3: Dictionary = RtLive.fight(RtKit.dummy_cmd(), [RtCommand.item(6, "p0", "itm_smoke", "")])
	assert_eq(int((r3["result"] as BattleResult).outcome), BattleResult.Outcome.FLED, "a third combat at the same k")
	assert_eq(_snaps.size(), 3)
	var compacted: RunLog = RtLive.round_trip(Game.run_log)
	compacted.compact()
	var res: Dictionary = _assert_replay_equals_live()
	var res_c: Dictionary = Game.replay_log(compacted)
	assert_true(compacted.has_batches(), "the stored form has move batches")
	assert_eq([res_c["errors"], res_c["mismatch_at"], res_c["final_hash"]], [PackedStringArray(), -1,
		res["final_hash"]], "a compacted live log replays the same (07 §10.3)")
	# the core verifier: no Show (no system gift fell here) — every combat checkpoint of the live run again
	var core: Dictionary = RunSim.replay(DB.data, Game.run_log)
	assert_eq(core["errors"], PackedStringArray(), "RunSim takes every entry of the live log")
	assert_eq(core["combat_mismatch_at"], -1, "RunSim.replay ≡ live combats (StateHash.of_rt at every checkpoint)")


func test_external_and_system_gift_due_in_one_tick_then_control_change_and_defeat() -> void:
	var st: GameState = RtLive.state(6, 62.0)
	RtLive.adopt(st)
	assert_true(Game.open_dev_sponsor_window(60, 3))
	var boss: Dictionary = RtKit.encounter("enc_rt_test_boss", [["g_boss", "enc_rt_test_boss", [0, -200, 128]]])
	assert_not_null(Game.make_rt_setup(boss), "the boss combat starts")
	assert_true(Show.hype() >= 70.0, "the boss start (+8) crossed 70: a system gift is due (hype %s)" % Show.hype())
	var gift: Dictionary = Gift.make_dev("gold", "", 150)
	assert_eq(Show.receive_gift(gift)["apply"], "queued", "an external gift due at the same boundary")
	var r: Dictionary = RtLive.play([RtCommand.ability(2, "p0", "skl_kai_heavy_swing", "e0"),
		RtCommand.hint(3, "enrage")], 18000)
	var result: BattleResult = r["result"]
	assert_eq(int(result.outcome), BattleResult.Outcome.DEFEAT, "the test boss wins")
	var types: Array = (r["events"] as Array).map(func(e: ActionEvent) -> String: return ActionEvent.type_name(e.type))
	assert_true(types.has("CONTROL_CHANGED"), "control follows life after the hero's KO")
	assert_eq(_gift_events.slice(0, 2), [["CREDITS_GAINED", 0], ["SPONSOR_GIFT", 1]],
		"external at the boundary c, the system gift at c + 1 (07 §9.2)")
	var gifts: Array = []
	for row: Dictionary in Game.run_log.cmds():
		if str((row["c"] as Dictionary)["t"]) == "gift":
			gifts.append([int(row["id"]), int((row["c"] as Dictionary).get("ct", -1))])
	assert_eq(gifts, [[0, 0]], "only the external gift is recorded (the system gift comes back from the Show rng)")
	_assert_replay_equals_live()


## A tampered live log is caught by Game.replay_log: a corrupted combat checkpoint, a missing input, an entry after the
## end, a second gift at one boundary.
func test_tampered_live_logs_are_refused() -> void:
	var st: GameState = RtLive.state(6, 20.0, {"itm_brutzel_burger": 2, "itm_energy_krawumm": 1, "itm_molotov": 1})
	RtLive.adopt(st)
	assert_true(Game.open_dev_sponsor_window(60, 3))
	var gift: Dictionary = Gift.make_dev("gold", "", 100)
	RtLive.fight(RtKit.canned_encounter(), RtKit.canned_commands(), 6000, func(c: int) -> void:
		if c == 9:
			Show.receive_gift(gift))
	var good: Dictionary = Game.run_log.to_dict()
	assert_eq(Game.replay_log(RunLog.from_dict(good))["errors"], PackedStringArray())
	# a corrupted combat checkpoint
	var d1: Dictionary = good.duplicate(true)
	var i_cp: int = -1
	for i in (d1["checkpoints"] as Array).size():
		if ((d1["checkpoints"] as Array)[i] as Dictionary).has("ct") and i_cp < 0:
			i_cp = i
			((d1["checkpoints"] as Array)[i] as Dictionary)["h"] = "0".repeat(64)
	var r1: Dictionary = Game.replay_log(RunLog.from_dict(d1))
	assert_eq(r1["combat_mismatch_at"], i_cp, "the corrupted combat checkpoint")
	assert_eq(r1["mismatch_at"], i_cp)
	# an input taken out (the first item use): the combat replays differently
	var d2: Dictionary = good.duplicate(true)
	var cmds: Array = d2["cmds"]
	for i in cmds.size():
		if str(((cmds[i] as Dictionary)["c"] as Dictionary)["t"]) == "combat_item":
			cmds.remove_at(i)
			break
	assert_true(int(Game.replay_log(RunLog.from_dict(d2))["combat_mismatch_at"]) >= 0, "a missing input is a mismatch")
	# an input after the end of the combat
	var d3: Dictionary = good.duplicate(true)
	var last: Dictionary = ((d3["cmds"] as Array).back() as Dictionary)
	(d3["cmds"] as Array).append({"k": int(last["k"]), "id": int(last["id"]) + 1,
		"c": RtCommand.target(9000, "p0", "")})
	var r3: Dictionary = Game.replay_log(RunLog.from_dict(d3))
	assert_true(", ".join(r3["errors"]).contains("combat_cmd_after_end"), str(r3["errors"]))
	# a second gift at one boundary
	var d4: Dictionary = good.duplicate(true)
	var cmds4: Array = d4["cmds"]
	for i in cmds4.size():
		if str(((cmds4[i] as Dictionary)["c"] as Dictionary)["t"]) == "gift":
			var twin: Dictionary = (cmds4[i] as Dictionary).duplicate(true)
			((twin["c"] as Dictionary)["gift"] as Dictionary)["gift_id"] = "g_dev_twin"
			cmds4.insert(i + 1, twin)
			break
	var r4: Dictionary = Game.replay_log(RunLog.from_dict(d4))
	assert_true(", ".join(r4["errors"]).contains("gift_twice"), str(r4["errors"]))
