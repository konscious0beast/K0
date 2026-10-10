extends TestCase
## 06 §1 / §8.2 (package A): hero choice — HeroRules (check_initial / check_set / set_hero / partner_of /
## field_ability), GameState.hero (save round trip, old saves → "kai", unknown → "kai"), the "hero" command (recorded
## right after "floor" by Game.new_game / start_event_run, later switches only in a safe room), Game.replay_log and
## RunSim.replay reproduce runs that start as Graf Mopsula and switch in a safe room (same StateHash), a forged hero
## switch outside a safe room is refused, Save.save_slot / load_slot keep the hero, the title flow passes the choice.

const DIR: String = "user://test_06a/saves"
const ROOT: String = "user://test_06a"
const TitleFlow := preload("res://scenes/title/title_flow.gd")

var _changed: Array[String] = []


func before_each() -> void:
	_changed.clear()
	Events.hero_changed.connect(_on_hero_changed)


func after_each() -> void:
	if Events.hero_changed.is_connected(_on_hero_changed):
		Events.hero_changed.disconnect(_on_hero_changed)
	Save.save_dir = "user://saves"
	Save.read_only = false
	_rmrf(ROOT)
	Game.state = null
	Game.run_log = null
	Game.sim = null
	Game.quest = null
	Game.mode = &"campaign"
	Game.timer_running = false
	Game.in_battle = false


func _on_hero_changed(id: String) -> void:
	_changed.append(id)


static func _rmrf(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for f: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	for sub: String in DirAccess.get_directories_at(path):
		_rmrf(path.path_join(sub))
	DirAccess.remove_absolute(path)


func _state(data: GameData = null) -> GameState:
	var d: GameData = data if data != null else real_data()
	var st: GameState = GameState.create_new(d, 0, "Kai", 77)
	st.floor_run = FloorRun.create(d.floor_def(1), st.seed, st.difficulty)
	return st


func _cmd_types() -> Array:
	var out: Array = []
	for c: Dictionary in Game.run_log.cmds():
		out.append(str((c["c"] as Dictionary)["t"]))
	return out


# --- HeroRules ------------------------------------------------------------------------------------------------------

func test_rules_vocabulary_partner_and_field_ability() -> void:
	assert_eq(HeroRules.HEROES, PackedStringArray(["kai", "mopsula"]))
	assert_eq(HeroRules.field_ability("kai"), &"strike")
	assert_eq(HeroRules.field_ability("mopsula"), &"bark")
	assert_eq(HeroRules.field_ability("??"), &"strike", "unknown → strike")
	var st: GameState = _state()
	assert_eq(st.hero, "kai", "default hero")
	assert_eq(HeroRules.partner_of(st), "mopsula")
	st.hero = "mopsula"
	assert_eq(HeroRules.partner_of(st), "kai")
	assert_eq(HeroRules.partner_of(null), "mopsula")
	assert_eq(HeroRules.sanitize("mopsula"), "mopsula")
	assert_eq(HeroRules.sanitize("rattenkoenigin"), "kai")
	assert_eq(HeroRules.sanitize(""), "kai")


func test_check_initial_only_before_the_run_started() -> void:
	var st: GameState = _state()
	assert_false(HeroRules.run_started(st))
	assert_eq(HeroRules.check_initial(st, "mopsula"), "")
	assert_eq(HeroRules.check_initial(st, "kai"), "", "choosing the default is fine too")
	assert_eq(HeroRules.check_initial(st, "dog"), "unknown_hero")
	assert_eq(HeroRules.check(st, "mopsula"), "", "check() → check_initial before the run")
	st.rng_counter = 1                          # an encounter drew from the run RNG
	assert_true(HeroRules.run_started(st))
	assert_eq(HeroRules.check_initial(st, "mopsula"), "run_started")
	var st2: GameState = _state()
	st2.floor_run.stats["time_used_ticks"] = 1  # the countdown ran one tick
	assert_eq(HeroRules.check_initial(st2, "mopsula"), "run_started")
	assert_true(HeroRules.run_started(null))


func test_check_set_only_in_a_safe_room_and_only_a_real_change() -> void:
	var st: GameState = _state()
	st.rng_counter = 3
	assert_eq(HeroRules.check_set(st, "mopsula"), "not_in_safe_room")
	assert_eq(HeroRules.check(st, "mopsula"), "not_in_safe_room", "check() → check_set once the run started")
	assert_false(HeroRules.set_hero(st, "mopsula"))
	assert_eq(st.hero, "kai", "a refused switch changes nothing")
	st.floor_run.location = &"sr_kiosk"
	assert_eq(HeroRules.check_set(st, "kai"), "same")
	assert_eq(HeroRules.check_set(st, "graf"), "unknown_hero")
	assert_eq(HeroRules.check_set(st, "mopsula"), "")
	assert_true(HeroRules.set_hero(st, "mopsula"))
	assert_eq(st.hero, "mopsula")
	assert_eq(HeroRules.check_set(null, "kai"), "not_in_safe_room")


# --- GameState / save -----------------------------------------------------------------------------------------------

func test_state_round_trip_old_saves_and_unknown_heroes() -> void:
	var st: GameState = _state()
	st.hero = "mopsula"
	var d: Dictionary = st.to_dict()
	assert_eq(d["hero"], "mopsula", "to_dict carries the hero")
	assert_eq(GameState.from_dict(d).hero, "mopsula")
	var old: Dictionary = d.duplicate(true)
	old.erase("hero")
	assert_eq(GameState.from_dict(old).hero, "kai", "a save from before 06 → Kai leads (no version bump)")
	old["hero"] = "rattenkoenigin"
	assert_eq(GameState.from_dict(old).hero, "kai", "unknown hero → Kai")
	assert_true(StateHash.hash_input(st).has("hero"), "the hero is part of the state hash")
	var kai_st: GameState = _state()
	assert_ne(StateHash.of(kai_st), StateHash.of(st), "a different hero is a different state")


func test_save_slot_round_trip_keeps_the_hero() -> void:
	_rmrf(ROOT)
	Save.save_dir = DIR
	Save.read_only = false
	Game.new_game(1, "Lena", 515, &"prime", "mopsula")
	assert_eq(Game.hero(), "mopsula")
	Game.enter_safe_room("sr_kiosk")
	assert_eq(Save.save_slot(1), OK)
	Game.state = null
	assert_eq(Save.load_slot(1), OK)
	assert_eq(Game.hero(), "mopsula", "the loaded run is led by the Count")
	assert_eq(Game.partner(), "kai")


# --- Game: new game, switch, replay ---------------------------------------------------------------------------------

func test_new_game_records_the_choice_right_after_the_floor() -> void:
	Game.new_game(0, "Kai", 101)
	assert_eq(Game.hero(), "kai", "default: Kai leads")
	assert_eq(_cmd_types().slice(0, 2), ["floor", "hero"])
	assert_eq((Game.run_log.cmds()[1]["c"] as Dictionary)["id"], "kai")
	assert_eq(_changed, [] as Array[String], "choosing the default changes nothing")
	Game.new_game(0, "Kai", 102, &"prime", "mopsula")
	assert_eq(Game.hero(), "mopsula")
	assert_eq(Game.partner(), "kai")
	assert_eq(_cmd_types().slice(0, 2), ["floor", "hero"])
	assert_eq((Game.run_log.cmds()[1]["c"] as Dictionary)["id"], "mopsula")
	assert_eq(_changed, ["mopsula"] as Array[String], "hero_changed")
	assert_eq(Game.run_log.validate(), PackedStringArray(), "the hero command passes the log schema")


func test_unknown_hero_on_new_game_falls_back_to_kai() -> void:
	Game.new_game(0, "Kai", 103, &"prime", "pudel")
	assert_eq(Game.hero(), "kai")
	assert_eq((Game.run_log.cmds()[1]["c"] as Dictionary)["id"], "kai", "recorded as Kai")


func test_switch_only_in_a_safe_room() -> void:
	Game.new_game(0, "Kai", 104)
	_live_battle(DB.floor_def(1).timer_start_after, BattleSetup.Advantage.PREEMPTIVE, "f1_g0")
	var n: int = Game.run_log.cmds().size()
	assert_false(Game.set_hero("mopsula"), "not in the exploration")
	assert_eq(Game.run_log.cmds().size(), n, "a refused switch is not recorded")
	Game.enter_safe_room("sr_kiosk")
	assert_false(Game.set_hero("kai"), "no switch to the same hero")
	assert_true(Game.set_hero("mopsula"))
	assert_eq(Game.hero(), "mopsula")
	assert_eq(_cmd_types().back(), "hero")
	assert_true(Game.set_hero("kai"), "and back")
	assert_eq(_changed, ["mopsula", "kai"] as Array[String])
	Game.leave_safe_room()
	assert_false(Game.set_hero("mopsula"), "outside again")


## The live battle path of BattleController (§5.7): events → Show, gift at every turn boundary, auto commands.
func _live_battle(enc: String, adv: int, group: String) -> BattleState:
	var setup: BattleSetup = Game.make_battle_setup(enc, adv, group)
	assert_not_null(setup)
	var battle: BattleState = BattleState.new(setup, DB.data)
	Show.begin_battle(setup)
	Events.battle_started.emit(setup.encounter_id, setup.is_boss)
	_feed(battle.start())
	_boundary(battle)
	var guard: int = 0
	while not battle.is_finished() and guard < 400:
		guard += 1
		var cmd: BattleCommand = battle.choose_ai_command()
		Game.record({"t": "battle", "cmd": cmd.to_dict(), "auto": true})
		_feed(battle.submit(cmd))
		_boundary(battle)
	Events.battle_ended.emit(battle.result.outcome, battle.result.encounter_id)
	Game.apply_battle_result(battle.result)
	Show.end_battle(battle.result)
	return battle


func _feed(events: Array[ActionEvent]) -> void:
	for e: ActionEvent in events:
		Show.on_battle_event(e)


func _boundary(battle: BattleState) -> void:
	if battle.is_finished():
		return
	var g: Dictionary = Show.take_pending_gift(battle)
	if not g.is_empty():
		var events: Array[ActionEvent] = battle.apply_gift(g)
		Show.note_battle_gift(g, events)
		_feed(events)


func test_replay_of_a_run_that_starts_as_mopsula_and_switches() -> void:
	Game.new_game(0, "Kai", 4242, &"prime", "mopsula")
	_live_battle(DB.floor_def(1).timer_start_after, BattleSetup.Advantage.PREEMPTIVE, "f1_g0")
	Game.enter_safe_room("sr_kiosk")
	assert_true(Game.set_hero("kai"), "switch in the safe room")
	Game.leave_safe_room()
	Game.enter_safe_room("sr_kiosk")
	assert_true(Game.set_hero("mopsula"), "and back")
	var live: String = StateHash.of(Game.state)
	var rep: Dictionary = Game.replay_log(Game.run_log, Game.sim.tick())
	assert_eq(rep["final_hash"], live, "Game.replay_log: same StateHash with hero commands")
	assert_eq(rep["mismatch_at"], -1)
	assert_eq(Game.hero(), "mopsula", "the live context is restored after the replay")
	var types: Array = _cmd_types()
	assert_eq(types.count("hero"), 3, "the choice + two switches")


func test_event_run_records_the_choice() -> void:
	Game.start_event_run("evt_offline_gleis9", "", "mopsula")   # (event id, league "" = default, hero)
	if not Game.has_state():
		skip("event catalog not available")
		return
	assert_eq(Game.mode, &"event_offline")
	assert_eq(Game.hero(), "mopsula")
	assert_eq(_cmd_types().slice(0, 2), ["floor", "hero"])


# --- RunSim ---------------------------------------------------------------------------------------------------------

func test_runsim_applies_refuses_and_replays_hero_commands() -> void:
	var data: GameData = real_data()
	var st: GameState = GameState.create_new(data, 0, "Kai", 909, &"prime")
	var sim: RunSim = RunSim.new(data, st, {})
	var rl: RunLog = RunLog.new()
	rl.header = {"schema": 1, "seed": 909, "slot": 0, "player_name": "Kai", "difficulty": "prime", "mode": "campaign",
		"sim_hz": RunSim.TICKS_PER_SEC, "event_id": "", "run_id": "run_hero_909"}
	sim.run_log = rl
	sim.apply({"t": "floor", "floor": 1})
	sim.apply({"t": "hero", "id": "mopsula"})
	assert_eq(st.hero, "mopsula", "initial choice")
	sim.apply({"t": "encounter", "enc": DB.floor_def(1).timer_start_after, "adv": BattleSetup.Advantage.PREEMPTIVE,
		"group": "f1_g0"})
	var guard: int = 0
	while sim.battle != null and guard < 400:
		guard += 1
		sim.apply({"t": "battle", "cmd": sim.battle.choose_ai_command().to_dict(), "auto": true})
	sim.apply({"t": "hero", "id": "kai"})
	assert_eq(st.hero, "mopsula", "no switch outside a safe room")
	assert_eq(sim.rejected_cmds.back()["reason"], "not_in_safe_room")
	assert_eq(sim.rejected_cmds.back()["gift_id"], "kai", "the refused hero id is reported")
	var refused: int = sim.rejected_cmds.size()
	sim.apply({"t": "safe_room", "id": "sr_kiosk"})
	sim.apply({"t": "hero", "id": "kai"})
	assert_eq(st.hero, "kai", "switch in the safe room")
	assert_eq(sim.rejected_cmds.size(), refused)
	var h: String = sim.close("test")
	var res: Dictionary = RunSim.replay(data, rl)
	assert_eq(res["final_hash"], h, "RunSim.replay → same hash")
	assert_eq(res["errors"], PackedStringArray(), "the refused command was never recorded")
	# a forged log: a switch outside a safe room → refused and reported by the verifier
	var forged: RunLog = RunLog.new()
	forged.header = rl.header.duplicate()
	var next_id: int = 0
	var i: int = 0
	for c: Dictionary in rl.cmds():
		i += 1
		var cid: int = int(c["id"])
		if cid > 0:
			next_id += 1
			cid = next_id
		forged.add_cmd(int(c["k"]), c["c"], cid)
		if i == 3:                              # right after the encounter: in battle, outside a safe room
			next_id += 1
			forged.add_cmd(int(c["k"]), {"t": "hero", "id": "kai"}, next_id)
	assert_eq(forged.rejected, 0, "a well-formed log")
	var res2: Dictionary = RunSim.replay(data, forged)
	var found: bool = false
	for e: String in res2["errors"]:
		found = found or (e.contains("hero") and e.contains("refused by the core"))
	assert_true(found, "forged hero switch reported: %s" % str(res2["errors"]))


# --- title flow ------------------------------------------------------------------------------------------------------

func test_title_flow_passes_the_choice_to_the_new_game() -> void:
	var prev: int = TitleFlow.boot_seed
	TitleFlow.boot_seed = 31
	var ok: bool = TitleFlow.start_new_game(0, "Lena", true, 31, &"prime", "mopsula")
	TitleFlow.boot_seed = prev
	assert_true(ok)
	assert_eq(Game.hero(), "mopsula")
	assert_eq(Game.state.player_name, "Lena", "the name stays the player's (Kai's) name")
	await wait_until(func() -> bool: return not Router.busy, 600)
	Router.goto("res://tests/fixtures/router/router_screen.tscn", {}, Router.Transition.NONE)
	await wait_until(func() -> bool: return not Router.busy, 600)
	Router.adopt(null)
