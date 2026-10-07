extends TestCase
## Game (02_TECH §3.4): command ids, dialog pause reset, quest metric adapter (05 CR-4/CR-13), replay context restore.
## Plus one integration test (live run ≡ replay_log) that is skipped while M1/M2/M8 parts are still M0 stubs.
## Spies subclass RunLog / QuestTracker, so the unit parts do not depend on the M8 implementations.

const STUB_HEADER: String = "# STUB(M0)"
## Files the replay integration test needs as real implementations.
const REPLAY_DEPS: PackedStringArray = ["res://core/live/run_log.gd", "res://core/live/state_hash.gd",
	"res://core/live/canonical_json.gd", "res://core/live/run_sim.gd", "res://core/progression/game_state.gd",
	"res://core/progression/floor_run.gd", "res://core/progression/battle_bridge.gd",
	"res://core/battle/battle_state.gd", "res://core/loot/loot_roller.gd", "res://autoload/show.gd"]


class _SpyLog extends RunLog:
	var entries: Array[Dictionary] = []

	func add_cmd(tick: int, cmd: Dictionary, cmd_id: int = 0) -> void:
		entries.append({"k": tick, "id": cmd_id, "c": cmd})


class _SpyQuest extends QuestTracker:
	var events: Array[Dictionary] = []

	func on_event(ev: Dictionary) -> bool:
		events.append(ev)
		return false


func after_each() -> void:
	Game.state = null
	Game.run_log = null
	Game.sim = null
	Game.quest = null
	Game.mode = &"campaign"
	Game.timer_running = false
	Game.in_battle = false
	Game.set_dialog_presenter(false)
	Game.clear_blocking_dialogs()


func _stubs(paths: PackedStringArray) -> PackedStringArray:
	var out: PackedStringArray = []
	for p: String in paths:
		var f: FileAccess = FileAccess.open(p, FileAccess.READ)
		if f == null or f.get_line().begins_with(STUB_HEADER):
			out.append(p.get_file())
	return out


func test_cmd_ids_strictly_increase_and_external_inputs_get_zero() -> void:
	var log_a: _SpyLog = _SpyLog.new()
	Game.run_log = log_a
	Game.record({"t": "rest"})
	Game.record({"t": "gift", "gift": {}})
	Game.record({"t": "buy", "item": "itm_bandage", "qty": 1, "safe_room": "sr_kiosk"})
	Game.record({"t": "twist"})
	Game.record({"t": "descend"})
	var ids: Array[int] = []
	for e: Dictionary in log_a.entries:
		ids.append(int(e["id"]))
	assert_eq(ids, [1, 0, 2, 0, 3], "player commands 1, 2, 3 …; gift/twist 0 (05 §10.6)")
	var log_b: _SpyLog = _SpyLog.new()
	Game.run_log = log_b
	Game.record({"t": "rest"})
	assert_eq(log_b.entries[0]["id"], 1, "a new run log (new game / Save.load_slot) starts at 1 again")
	Game.replaying = true
	Game.record({"t": "rest"})
	Game.replaying = false
	assert_len(log_b.entries, 1, "no recording while replaying")


func test_blocking_dialogs_pause_only_with_presenter_and_reset() -> void:
	Game.new_game(0, "Kai", 3)
	if not Game.has_state() or Game.state.floor_run == null:
		fail("new_game must create a state with a floor run (M0 stubs / M2)")
		return
	Game.state.floor_run.timer_started = true
	Game.timer_running = true
	assert_true(Game.is_timer_ticking())
	Events.mod_said.emit("Hallo", &"mod", "intro", true)
	assert_true(Game.is_timer_ticking(), "no dialog presenter (no GlobalUi): a blocking line cannot pause forever")
	Game.set_dialog_presenter(true)
	Events.mod_said.emit("Hallo", &"mod", "intro", true)
	assert_false(Game.is_timer_ticking(), "blocking line pauses the countdown")
	Events.dialog_finished.emit("intro")
	assert_true(Game.is_timer_ticking())
	Events.mod_said.emit("Eins", &"mod", "intro", true)
	Events.mod_said.emit("Zwei", &"mod", "intro", true)
	Game.clear_blocking_dialogs()
	assert_true(Game.is_timer_ticking(), "Router goto clears dialogs of freed screens")
	Events.mod_said.emit("Drei", &"mod", "intro", true)
	Game.start_floor(1)
	Game.state.floor_run.timer_started = true
	Game.timer_running = true
	# Show.start_floor may itself start (at most) one blocking line; "Drei" must be gone either way.
	Events.dialog_finished.emit("floor_start")
	assert_true(Game.is_timer_ticking(), "start_floor clears pending dialogs")
	Events.mod_said.emit("Vier", &"mod", "intro", true)
	Game.set_dialog_presenter(false)
	assert_true(Game.is_timer_ticking(), "presenter leaving the tree clears pending dialogs")


func test_quest_adapter_feeds_metrics_from_stats() -> void:
	Game.new_game(0, "Kai", 5)
	if not Game.has_state() or Game.state.show == null:
		fail("new_game must create a state with a ShowState (M0 stubs / M2)")
		return
	var spy: _SpyQuest = _SpyQuest.new()
	Game.mode = &"event_offline"
	Game.quest = spy
	Game.state.show.stats["hype_100_count"] = 1
	Events.hype_changed.emit(100.0, 12.0, &"crit")
	Events.hype_changed.emit(96.0, -4.0, &"boring_fight")
	Game.state.show.stats["viewers_target_peak"] = 2900
	Events.viewers_changed.emit(2900)
	Game.state.show.stats["followers_gained_run"] = 40
	Events.followers_changed.emit(40, 40)
	Events.enemy_killed.emit({"enemy_id": "enm_kanalratte"})
	assert_eq(spy.events, [
		{"type": "metric", "name": "hype_100_count", "value": 1},
		{"type": "metric", "name": "viewers_target_peak", "value": 2900},
		{"type": "metric", "name": "followers_gained_run", "value": 40},
		{"type": "enemy_killed", "enemy_id": "enm_kanalratte"},
	], "metrics only when the stat value changed")
	assert_has(StatIds.ALL, "viewers_target_peak", "CR-13 stat ids")
	assert_has(StatIds.ALL, "followers_gained_run")
	assert_has(StatIds.ALL, "hype_100_count")
	Game.mode = &"campaign"
	Events.viewers_changed.emit(3000)
	assert_len(spy.events, 4, "campaign mode feeds no quest")


func test_replay_restores_the_live_context() -> void:
	Game.new_game(0, "Kai", 7)
	var live: GameState = Game.state
	var live_log: RunLog = Game.run_log
	var live_sim: RunSim = Game.sim
	var spy: _SpyLog = _SpyLog.new()
	spy.header = {"seed": 7, "slot": 0, "player_name": "Kai", "difficulty": "prime", "event_id": ""}
	var res: Dictionary = Game.replay_log(spy)
	assert_true(res.has("final_hash") and res.has("result") and res.has("mismatch_at"))
	assert_eq(res["mismatch_at"], -1)
	assert_true(Game.state == live, "live state restored")
	assert_true(Game.run_log == live_log, "live run log restored")
	assert_true(Game.sim == live_sim, "live sim restored")
	assert_false(Game.replaying)
	assert_eq(Game.mode, &"campaign")
	Game.in_battle = true
	assert_eq(Game.replay_log(spy)["final_hash"], "", "refused during a battle")
	Game.in_battle = false


func test_replay_matches_live_run_integration() -> void:
	var stubs: PackedStringArray = _stubs(REPLAY_DEPS)
	if not stubs.is_empty():
		skip("integration: needs real M1/M2/M8 (still stubs: %s)" % ", ".join(stubs))
		return
	Game.auto_battle = true
	Game.new_game(0, "Kai", 4242)
	assert_true(Game.has_state())
	if not Game.has_state():
		return
	var sr_id: String = ""
	var srs: Array = DB.floor_def(1).layout.get("safe_rooms", [])
	if not srs.is_empty():
		sr_id = str(srs[0]["id"])
	if sr_id != "":
		Game.enter_safe_room(sr_id)
		Game.leave_safe_room()
	Game.set_flag("intro_seen", true)
	# §5.7 battle loop without scenes (auto battle for both sides).
	var enc_id: String = DB.floor_def(1).timer_start_after
	var setup: BattleSetup = Game.make_battle_setup(enc_id, BattleSetup.Advantage.NORMAL, "")
	assert_not_null(setup)
	if setup == null:
		return
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
	assert_true(battle.is_finished(), "battle ends")
	Events.battle_ended.emit(battle.result.outcome, battle.result.encounter_id)
	Game.apply_battle_result(battle.result)
	Show.end_battle(battle.result)
	if not Game.state.pending_lootboxes.is_empty():
		Game.open_lootbox(Game.state.pending_lootboxes[0])
	Game.rest_full_heal()
	var live_hash: String = StateHash.of(Game.state)
	assert_ne(live_hash, "")
	var res: Dictionary = Game.replay_log(Game.run_log)
	assert_eq(res["mismatch_at"], -1)
	assert_eq(res["final_hash"], live_hash, "replay of the live log reproduces the state hash")
	var as_json: Variant = JSON.parse_string(JSON.stringify(Game.run_log.to_dict()))
	var reloaded: RunLog = RunLog.from_dict(as_json if as_json is Dictionary else {})
	assert_eq(Game.replay_log(reloaded)["final_hash"], live_hash, "also after a JSON round trip (ints become floats)")
	Game.auto_battle = false


## §5.7 _play without presentation.
func _play(battle: BattleState, events: Array[ActionEvent]) -> void:
	for e: ActionEvent in events:
		Show.on_battle_event(e)
	if battle.is_finished():
		return
	var g: Dictionary = Show.take_pending_gift(battle)
	if not g.is_empty():
		for e: ActionEvent in battle.apply_gift(g):
			Show.on_battle_event(e)
