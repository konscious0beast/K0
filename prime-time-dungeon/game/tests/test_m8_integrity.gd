extends TestCase
## Verifier integrity (05 §6.9/§6.10/§10.4/§11.4, final review "live-integrity"): forged logs and commands are refused
## by the core rules and reported by BOTH verifiers (RunSim.replay for core runs, Game.replay_log for live runs):
## difficulty in event runs, header ≠ event (seed, difficulty, league), player flag whitelist, floor order, scenes only
## as the safe room allows, commands and gifts after "descend", run binding of gifts (wrong_target) and the gift-service
## ledger, the minimum interval of service gifts, multi-league runs, unique run ids and board entries tied to their
## replay.

const R := preload("res://tests/test_m8_replay.gd")
const EVENT_ID: String = "evt_offline_gleis9"
const NO_WINDOWS: Dictionary = {"sponsor_windows": {"enabled": false}}


func after_each() -> void:
	Game.state = null
	Game.run_log = null
	Game.sim = null
	Game.quest = null
	Game.mode = &"campaign"
	Game.timer_running = false
	Game.in_battle = false
	Game.auto_battle = false
	Game.safe_room_clock = false


func _event() -> EventDef:
	var cat: EventCatalog = EventCatalog.new()
	cat.load_file("res://data/events.json")
	return cat.get_event(EVENT_ID)


## test_m8_replay's bot on the Pur-Liga event: {"log", "hash", "sim"}.
func _bot(def: EventDef) -> Dictionary:
	return R.new().call("_bot_run", def, false)


## The bot log as a dictionary whose last command (descend) gets `extra` commands in front of it (player ids above the
## log's, same tick).
func _with_cmds_before_descend(run: Dictionary, extra: Array) -> Dictionary:
	var d: Dictionary = (run["log"] as RunLog).to_dict()
	var cmds: Array = d["cmds"]
	var last: Dictionary = cmds.pop_back()
	var next_id: int = int(last["id"])
	for c: Variant in extra:
		cmds.append({"k": int(last["k"]), "id": next_id if Command.is_external(c) == false else 0, "c": c})
		if not Command.is_external(c):
			next_id += 1
	last["id"] = next_id
	cmds.append(last)
	d["checkpoints"] = []
	return d


func _sim(rules: Dictionary, identity: Dictionary = {}, seed: int = 77) -> RunSim:
	var data: GameData = real_data()
	var st: GameState = GameState.create_new(data, 0, "Kai", seed, &"prime")
	var sim: RunSim = RunSim.new(data, st, rules, identity)
	sim.apply({"t": "floor", "floor": 1})
	sim.state.floor_run.timer_started = true
	return sim


## A shop gift (service source) with the buyer pseudonym and the load basis of the run.
func _shop(n: int, load_half: int) -> Dictionary:
	var g: Dictionary = Gift.make_dev("gold", "", 100)
	g["gift_id"] = "g_shop_i_%d" % n
	g["source"] = "shop"
	g["sender"] = {"display_name": "", "anon": true, "sender_ref": "b_" + str(n).pad_zeros(12)}
	g["load_half"] = load_half
	g["effect_pm"] = GiftPolicy.effect_pm(load_half)
	return g


# --- live-integrity-1 / -11: difficulty and header of event runs -----------------------------------------------------

func test_event_runs_keep_their_difficulty_and_header() -> void:
	var def: EventDef = _event()
	var sim: RunSim = _sim(def.rules)
	sim.apply({"t": "difficulty", "to": "vorabend"})
	assert_eq(sim.state.difficulty, &"prime", "event runs play the event's difficulty (05 §10.1)")
	assert_eq(sim.rejected_cmds.back()["reason"], "not_allowed")
	var run: Dictionary = _bot(def)
	var honest: Dictionary = RunSim.replay(real_data(), run["log"])
	assert_eq(honest["errors"], PackedStringArray(), "the honest bot log")
	var forged: Dictionary = _with_cmds_before_descend(run, [{"t": "difficulty", "to": "vorabend"}])
	assert_has("; ".join(RunSim.replay(real_data(), RunLog.from_dict(forged))["errors"]),
		"difficulty '' refused by the core (not_allowed)")
	var hd: Dictionary = (run["log"] as RunLog).to_dict()
	(hd["header"] as Dictionary)["difficulty"] = "vorabend"
	assert_has("; ".join(RunSim.replay(real_data(), RunLog.from_dict(hd))["errors"]), "event runs play 'prime'")
	var hs: Dictionary = (run["log"] as RunLog).to_dict()
	(hs["header"] as Dictionary)["seed"] = 777
	assert_has("; ".join(RunSim.replay(real_data(), RunLog.from_dict(hs))["errors"]),
		"seed 777 is not the fixed seed 424242")


# --- live-integrity-3 / -14: forged commands --------------------------------------------------------------------------

func test_forged_commands_are_refused_and_reported() -> void:
	var def: EventDef = _event()
	var run: Dictionary = _bot(def)
	var d: Dictionary = _with_cmds_before_descend(run, [{"t": "floor", "floor": 1}, {"t": "scene", "id": "scn_mop_4"}])
	var res: Dictionary = RunSim.replay(real_data(), RunLog.from_dict(d))
	var errs: String = "; ".join(res["errors"])
	assert_has(errs, "floor '' refused by the core (not_allowed)", "a second start of the same floor (timer reset)")
	assert_has(errs, "scene '' refused by the core (not_allowed)", "a scene outside its safe room (pep talk buff)")
	assert_eq(res["final_hash"], run["hash"], "refused commands change nothing")
	# commands after "descend"
	var after: Dictionary = (run["log"] as RunLog).to_dict()
	var cmds: Array = after["cmds"]
	var last: Dictionary = cmds.back()
	cmds.append({"k": int(last["k"]), "id": int(last["id"]) + 1, "c": {"t": "rest"}})
	assert_has("; ".join(RunSim.replay(real_data(), RunLog.from_dict(after))["errors"]),
		"rest '' refused by the core (run_not_active)")
	# player flags are whitelisted: "live" (gift counters) and the pep talk flag are no player writes
	var flags: Dictionary = _with_cmds_before_descend(run, [{"t": "flag", "key": "mop_pep_talk", "value": true}])
	assert_has("; ".join(RunSim.replay(real_data(), RunLog.from_dict(flags))["errors"]), "not a player flag")
	var sim: RunSim = _sim({})
	var live: Variant = (sim.state.flags.get("live", {}) as Dictionary).duplicate(true)
	sim.apply({"t": "flag", "key": "live", "value": 0})
	assert_eq(sim.state.flags.get("live", {}), live, "refused by the schema: the gift counters stay (reviewer probe)")


func test_gifts_after_descend_are_refused() -> void:
	var sim: RunSim = _sim({})
	sim.apply({"t": "sponsor_window", "op": "dev_open", "sec": 600, "slots": 3})
	assert_eq(sim.gift_refusal(Gift.make_dev("gold", "", 100)), "")
	sim.apply({"t": "descend"})
	assert_eq(sim.gift_refusal(Gift.make_dev("gold", "", 100)), "run_not_active", "the floor is done")
	# Game/Show: a gift recorded after "descend" is refused by Show (Game.accepts_gifts) → an error of Game.replay_log
	Game.new_game(0, "Kai", 909)
	assert_true(Game.open_dev_sponsor_window())
	assert_true(Game.accepts_gifts())
	Game.record({"t": "descend"})
	Game.run_log.add_cmd(Game.sim.tick(), {"t": "gift", "gift": Gift.make_dev("gold", "", 100)}, 0)
	var res: Dictionary = Game.replay_log(Game.run_log)
	assert_has("; ".join(res["errors"]), "refused (run_not_active)")


# --- live-integrity-2: Game.replay_log has the verifier contract ------------------------------------------------------

func _play(battle: BattleState, events: Array[ActionEvent]) -> void:
	for e: ActionEvent in events:
		Show.on_battle_event(e)
	if battle.is_finished():
		return
	var g: Dictionary = Show.take_pending_gift(battle)
	if not g.is_empty():
		var ge: Array[ActionEvent] = battle.apply_gift(g)
		Show.note_battle_gift(g, ge)
		for e: ActionEvent in ge:
			Show.on_battle_event(e)


func test_game_replay_log_verifies_a_live_event_run() -> void:
	Game.auto_battle = true
	Game.start_event_run(EVENT_ID)
	var fdef: FloorDef = DB.floor_def(1)
	var setup: BattleSetup = Game.make_battle_setup(fdef.timer_start_after, BattleSetup.Advantage.NORMAL, "")
	var battle: BattleState = BattleState.new(setup, DB.data)
	Show.begin_battle(setup)
	Events.battle_started.emit(setup.encounter_id, setup.is_boss)
	_play(battle, battle.start())
	var guard: int = 0
	while not battle.is_finished() and guard < 400:
		guard += 1
		var cmd: BattleCommand = battle.choose_ai_command()
		Game.record({"t": "battle", "cmd": cmd.to_dict(), "auto": true})
		_play(battle, battle.submit(cmd))
	Events.battle_ended.emit(battle.result.outcome, battle.result.encounter_id)
	Game.apply_battle_result(battle.result)
	Show.end_battle(battle.result)
	Game.timer_running = true
	for i in 30:
		Game._process(0.5)
	Game.timer_running = false
	var live_hash: String = Game.sim.close("probe")
	var res: Dictionary = Game.replay_log(Game.run_log)
	assert_eq(res["errors"], PackedStringArray(), "an honest live run verifies with zero errors")
	assert_eq(res["final_hash"], live_hash)
	assert_eq(res["mismatch_at"], -1)
	var d: Dictionary = Game.run_log.to_dict()
	(d["header"] as Dictionary)["event_id"] = "evt_missing"
	var missing: Dictionary = Game.replay_log(RunLog.from_dict(d))
	assert_has("; ".join(missing["errors"]), "event 'evt_missing' not found", "abort: no replay without the rules")
	assert_eq(missing["final_hash"], "")
	var dup: Dictionary = Game.run_log.to_dict()
	(dup["cmds"] as Array).insert(1, (dup["cmds"] as Array)[1])
	assert_has("; ".join(Game.replay_log(RunLog.from_dict(dup))["errors"]), "rejected", "RunLog rejections")


# --- live-integrity-5: the league is part of the run identity -------------------------------------------------------

func test_multi_league_runs_need_their_league() -> void:
	var rules: Dictionary = {"leagues": ["show", "pur"], "gifts": {"enabled": true, "sources": ["dev"]},
		"sponsor_windows": {"enabled": false}}
	var unknown: RunSim = _sim(rules)
	assert_false((unknown.state.flags["live"] as Dictionary).has("league"))
	assert_eq(unknown.gift_refusal(Gift.make_dev("gold", "", 100)), "not_accepting", "no league → no external gifts")
	var pur: RunSim = _sim(rules, {"league": "pur"})
	assert_eq(pur.state.flags["live"]["league"], "pur")
	assert_eq(pur.gift_refusal(Gift.make_dev("gold", "", 100)), "league_pur", "a Pur-Liga player of a mixed event")
	var show: RunSim = _sim(rules, {"league": "show"})
	assert_eq(show.gift_refusal(Gift.make_dev("gold", "", 100)), "")
	var def: EventDef = _event()
	assert_eq(RunSim.header_errors({"seed": def.run_seed(), "difficulty": "prime"}, def, rules).size(), 1,
		"a mixed event's log must name the league")
	assert_eq(RunSim.header_errors({"seed": def.run_seed(), "difficulty": "prime", "league": "pur"}, def, rules),
		PackedStringArray())
	Game.start_event_run(EVENT_ID)
	assert_eq(Game.run_log.header["league"], "pur", "the RunLog header records the league")


# --- live-integrity-6: run binding and the gift-service ledger
# ---------------------------------------------------------

func test_gifts_are_bound_to_the_run_and_checked_against_the_ledger() -> void:
	var sim: RunSim = _sim(NO_WINDOWS, {"run_id": "run_local_1_aa", "player_id": "local", "event_id": ""})
	var g: Dictionary = Gift.make_dev("gold", "", 100)
	g["target"] = {"player_id": "someone_else", "run_id": "run_other"}
	assert_eq(sim.gift_refusal(g), "wrong_target", "issued to another run (reviewer probe)")
	g["target"] = {"player_id": "local", "run_id": "run_local_1_aa"}
	g["event_id"] = "evt_other"
	assert_eq(sim.gift_refusal(g), "wrong_target", "issued for an event, applied in a campaign run")
	g["event_id"] = ""
	assert_eq(sim.gift_refusal(g), "")
	var errs: PackedStringArray = RunSim.ledger_errors([{"gift_id": "g_a"}, {"gift_id": "g_b", "deliver_by_tick": 10},
		{"gift_id": "g_d"}], {"g_a": 5, "g_b": 20, "g_c": 1})
	var text: String = "; ".join(errs)
	assert_has(text, "'g_c': injected")
	assert_has(text, "'g_b': late")
	assert_has(text, "'g_d': missing")
	assert_eq(errs.size(), 3)
	# through RunSim.replay: the gift log of the bot with a ledger that knows only one of its gifts
	var def: EventDef = _event()
	var h: Object = R.new()
	var run: Dictionary = h.call("_bot_run", def, true)
	var res: Dictionary = RunSim.replay(real_data(), run["log"], h.call("_show_rules", def), def.quest,
		[{"gift_id": "g_dev_bot_1"}])
	assert_has("; ".join(res["errors"]), "'g_dev_bot_2': injected")
	var ok: Dictionary = RunSim.replay(real_data(), run["log"], h.call("_show_rules", def), def.quest,
		[{"gift_id": "g_dev_bot_1"}, {"gift_id": "g_dev_bot_2"}])
	assert_eq(ok["errors"], PackedStringArray(), "the complete ledger")


# --- live-integrity-7: minimum interval of service gifts
# ---------------------------------------------------------------

func test_service_gifts_keep_the_minimum_interval() -> void:
	var sim: RunSim = _sim({})
	sim.apply({"t": "sponsor_window", "op": "dev_open", "sec": 600, "slots": 3})
	sim.apply({"t": "gift", "gift": _shop(1, 0)})
	assert_eq(sim.rejected_cmds, [] as Array[Dictionary])
	assert_eq(sim.gift_refusal(_shop(2, 1)), "too_soon", "two deliveries on the same tick (reviewer probe)")
	sim.step(GiftPolicy.DEFAULT_GIFT_RULES["min_interval_sec"] * RunSim.TICKS_PER_SEC)
	assert_eq(sim.gift_refusal(_shop(2, 1)), "", "45 s later")


# --- live-integrity-12 / -13: unique run ids, board entries tied to their replay ------------------------------------

func test_attempts_get_their_own_run_id_and_board_entry() -> void:
	Game.start_event_run(EVENT_ID)
	var first: String = str(Game.run_log.header["run_id"])
	Game.start_event_run(EVENT_ID)
	var second: String = str(Game.run_log.header["run_id"])
	assert_true(first.begins_with("run_local_424242_"), first)
	assert_ne(first, second, "every attempt gets its own replay file")
	var summary: Dictionary = Game.finish_run(&"timer")
	var entry: Dictionary = summary.get("entry", {})
	assert_eq(entry.get("replay_id", ""), second, "replay file user://replays/<run_id>.json")
	assert_eq(entry.get("run_log_hash", ""), Game.run_log.digest(), "the entry names the exact replay")
	assert_eq([entry.get("difficulty", ""), entry.get("league", ""), entry.get("verified", "")], ["prime", "pur", "local"])
	assert_eq(str(entry.get("data_hash", "")).length(), 64, "sha256 of res://data")
	assert_eq(entry.get("sim_version", 0), RunSim.SIM_VERSION)
