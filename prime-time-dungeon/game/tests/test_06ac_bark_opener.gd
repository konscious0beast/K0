extends TestCase
## Integration round 4 — package A (Graf Mopsula's bark) × C (sneak-themed show bets): a PREEMPTIVE battle opened from
## the bark (the group is DAZED and is caught from every side) is no sneaking. It still is a preemptive battle for the
## CTB (party first, preemptive hype, "Erster Eindruck"), but:
## - BattleSetup / BattleResult carry opener "bark" (recorded with the encounter: {"opener": "bark"}, replay-safe);
## - the bet "Schleichwerbung" (mar_sneaky) and the achievement "Leise Sohle" (s.preemptives) ask for encounter_type
##   "preemptive" — a bark opener is encounter_type "bark" and counts as the stat bark_openers instead;
## - a sneaked preemptive (field strike from behind / on an idle group, touching a back) counts as before.

const ExplorationScript := preload("res://scenes/exploration/exploration.gd")
const Rules := preload("res://scenes/exploration/encounter_rules.gd")
const EnemyActor := preload("res://scenes/exploration/enemy_actor.gd")
const SEED: int = 777

var _prev_data: GameData = null


func before_each() -> void:
	_prev_data = DB.data
	DB.data = real_data()


func after_each() -> void:
	if Game.state != null:
		Show.end_battle(null)
	Game.auto_battle = false
	Game.in_battle = false
	Game.timer_running = false
	Game.replaying = false
	Game.state = null
	Game.run_log = null
	Game.sim = null
	Game.mode = &"campaign"
	Game.clear_blocking_dialogs()
	if _prev_data != null:
		DB.data = _prev_data
	_prev_data = null


## A won battle through the Game facade (auto battle, like test_06abc_liga_talents).
func _game_battle(enc: String, adv: int, opener: String) -> BattleResult:
	var setup: BattleSetup = Game.make_battle_setup(enc, adv, "", opener)
	var battle: BattleState = BattleState.new(setup, DB.data)
	Show.begin_battle(setup)
	Events.battle_started.emit(setup.encounter_id, setup.is_boss)
	_play(battle, battle.start())
	var guard: int = 0
	while not battle.is_finished() and guard < 600:
		guard += 1
		var cmd: BattleCommand = battle.choose_ai_command()
		Game.record({"t": "battle", "cmd": cmd.to_dict(), "auto": true})
		_play(battle, battle.submit(cmd))
	Events.battle_ended.emit(battle.result.outcome, battle.result.encounter_id)
	Game.apply_battle_result(battle.result)
	Show.end_battle(battle.result)
	return battle.result


func _play(battle: BattleState, events: Array[ActionEvent]) -> void:
	for e: ActionEvent in events:
		Show.on_battle_event(e)
	if battle.is_finished():
		return
	var g: Dictionary = Show.take_pending_gift(battle)
	if not g.is_empty():
		var gift_events: Array[ActionEvent] = battle.apply_gift(g)
		Show.note_battle_gift(g, gift_events)
		for e: ActionEvent in gift_events:
			Show.on_battle_event(e)


func _sneaky_run(hero: String) -> GameState:
	Game.auto_battle = true
	Game.new_game(1, "Kai", SEED, &"prime", hero)
	var st: GameState = Game.state
	for m: PartyMember in st.party:
		m.level = 5
	Progression.full_heal(st, DB.data)
	st.show.marotten["active"] = ["mar_sneaky"]           # M.O.D. mag heute: Schleichwerbung
	return st


func test_bark_opener_is_no_sneak_for_the_bet_and_the_stats() -> void:
	for hero: String in ["mopsula", "kai"]:
		var st: GameState = _sneaky_run(hero)
		var r: BattleResult = _game_battle("enc_f1_a2", BattleSetup.Advantage.PREEMPTIVE, "bark")
		assert_eq(r.outcome, BattleResult.Outcome.VICTORY)
		assert_eq(r.advantage, BattleSetup.Advantage.PREEMPTIVE, "the CTB still opens first (%s)" % hero)
		assert_eq(r.opener, "bark")
		assert_eq(st.show.marotten.get("hits", {}), {}, "a bark-daze first strike is no Schleichwerbung (%s)" % hero)
		assert_eq(int(st.show.stats.get("preemptives", 0)), 0, "no sneak counted")
		assert_eq(int(st.show.stats.get("bark_openers", 0)), 1, "counted as a bark opener instead")
		Progression.full_heal(st, DB.data)
		var r2: BattleResult = _game_battle("enc_f1_a3", BattleSetup.Advantage.PREEMPTIVE, "")
		assert_eq(r2.opener, "")
		assert_eq(st.show.marotten.get("hits", {}), {"mar_sneaky": 1}, "a sneaked preemptive fills the heart")
		assert_eq(int(st.show.stats.get("preemptives", 0)), 1)
		assert_eq(int(st.show.stats.get("bark_openers", 0)), 1)
		Game.auto_battle = false


func test_bark_opener_is_recorded_and_replays() -> void:
	_sneaky_run("mopsula")
	# the test's level-5 party is no recorded command: save + load so the log starts at that state (its anchor)
	var sr: String = str((DB.floor_def(1).layout.get("safe_rooms", [{}]) as Array)[0].get("id", ""))
	Game.enter_safe_room(sr)
	assert_eq(Save.save_slot(1), OK, Save.last_error())
	assert_eq(Save.load_slot(1), OK, Save.last_error())
	Game.enter_safe_room(sr)
	Game.leave_safe_room()
	var st: GameState = Game.state
	_game_battle("enc_f1_a2", BattleSetup.Advantage.PREEMPTIVE, "bark")
	var enc: Dictionary = {}
	for e: Dictionary in Game.run_log.cmds():
		if str((e["c"] as Dictionary)["t"]) == "encounter":
			enc = e["c"]
	assert_eq(str(enc.get("opener", "")), "bark", "recorded with the encounter")
	var live: String = StateHash.of(st)
	var rep: Dictionary = Game.replay_log(Game.run_log, Game.sim.tick())
	assert_eq(rep["errors"], PackedStringArray())
	assert_eq(rep["final_hash"], live, "Game.replay_log ≡ live with a bark opener (no heart, bark_openers 1)")
	# no opener field without a bark (old logs stay byte-identical), never on a non-preemptive battle
	Progression.full_heal(st, DB.data)
	_game_battle("enc_f1_a3", BattleSetup.Advantage.NORMAL, "bark")
	var last: Dictionary = {}
	for e: Dictionary in Game.run_log.cmds():
		if str((e["c"] as Dictionary)["t"]) == "encounter":
			last = e["c"]
	assert_false(last.has("opener"), "a NORMAL battle has no opener")
	Game.auto_battle = false


func test_command_schema_and_setup_round_trip() -> void:
	assert_eq(Command.validate({"t": "encounter", "enc": "enc_f1_a2", "adv": 1, "group": "", "opener": "bark"}), "")
	assert_has(Command.validate({"t": "encounter", "enc": "enc_f1_a2", "adv": 0, "group": "", "opener": "bark"}),
		"opener")
	assert_has(Command.validate({"t": "encounter", "enc": "enc_f1_a2", "adv": 1, "group": "", "opener": "sneak"}),
		"opener")
	var s: BattleSetup = BattleSetup.new()
	assert_false(s.to_dict().has("opener"), "no opener → the snapshot is unchanged")
	s.opener = "bark"
	assert_eq(BattleSetup.from_dict(s.to_dict(), real_data()).opener, "bark")
	var r: BattleResult = BattleResult.new()
	r.opener = "bark"
	assert_eq(BattleResult.from_dict(JSON.parse_string(JSON.stringify(r.to_dict()))).opener, "bark")


func test_exploration_names_a_dazed_group_a_bark_opener() -> void:
	var actor: EnemyActor = EnemyActor.new()
	actor.state = Rules.DAZED
	assert_eq(ExplorationScript._opener(actor, Rules.PREEMPTIVE), "bark", "contact with a dazed group")
	actor.state = &"IDLE"
	assert_eq(ExplorationScript._opener(actor, Rules.PREEMPTIVE), "", "sneaked up on an idle group")
	actor.state = Rules.DAZED
	assert_eq(ExplorationScript._opener(actor, Rules.NORMAL), "", "no preemptive, no opener")
	actor.free()
