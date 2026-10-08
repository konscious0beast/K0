extends TestCase
## StateHash (05 §3.3 Nr. 8, CR-14): SHA-256 over the canonical GameState without display fields; of_battle over the
## BattleState snapshot. Integration with the real M2 GameState / M1 BattleState (no autoloads).

var _hex: RegEx = RegEx.create_from_string("^[0-9a-f]{64}$")


func _state(seed: int = 4242) -> GameState:
	var st: GameState = GameState.create_new(real_data(), 0, "Kai", seed, &"prime")
	st.floor_run = FloorRun.create(real_data().floor_def(1), seed, &"prime")
	return st


func test_hash_is_sha256_hex_and_deterministic() -> void:
	var h: String = StateHash.of(_state())
	assert_true(_hex.search(h) != null, "64 lower-case hex characters: " + h)
	assert_eq(StateHash.of(_state()), h, "same seed → same hash")
	assert_ne(StateHash.of(_state(4243)), h, "other seed → other hash")
	assert_eq(StateHash.of(null), "")


func test_display_fields_are_not_hashed() -> void:
	var st: GameState = _state()
	var h: String = StateHash.of(st)
	st.play_time_sec = 812.25
	st.show.viewers = 99999
	st.slot = 3
	assert_eq(StateHash.of(st), h, "play_time_sec, show.viewers and slot are display/bookkeeping fields")
	var input: Dictionary = StateHash.hash_input(st)
	assert_false(input.has("play_time_sec"))
	assert_false(input.has("slot"))
	assert_false((input["show"] as Dictionary).has("viewers"))
	assert_true(st.to_dict()["show"].has("viewers"), "hash_input does not modify the state's own dictionary")


func test_game_relevant_fields_change_the_hash() -> void:
	var base: String = StateHash.of(_state())
	var changes: Array[Callable] = [
		func(s: GameState) -> void: s.show.hype = 31.0,
		func(s: GameState) -> void: s.inventory.add_credits(1),
		func(s: GameState) -> void: s.floor_run.time_left_ticks -= 1,
		func(s: GameState) -> void: s.rng_counter += 1,
		func(s: GameState) -> void: s.flags["live"] = {"load_half": 1},
		func(s: GameState) -> void: s.party[0].hp -= 1,
		func(s: GameState) -> void: s.show.stats["explore_seconds_since_battle"] = 1,
	]
	for i in changes.size():
		var st: GameState = _state()
		changes[i].call(st)
		assert_ne(StateHash.of(st), base, "change %d is game-relevant" % i)


func test_hash_survives_a_json_round_trip() -> void:
	var st: GameState = _state()
	st.flags["intro_seen"] = true
	st.show.stats["kills_total"] = 3
	var parsed: Variant = JSON.parse_string(JSON.stringify(st.to_dict()))
	var back: GameState = GameState.from_dict(parsed)
	assert_eq(StateHash.of(back), StateHash.of(st), "save/JSON round trip (ints become floats) keeps the hash")


func test_unserializable_state_gives_no_hash() -> void:
	var st: GameState = _state()
	st.flags["ratio"] = 0.5
	assert_eq(StateHash.of(st), "", "a non-integral float makes the state unhashable (never a fake hash)")


func test_battle_hash_snapshot_round_trip() -> void:
	var data: GameData = real_data()
	var st: GameState = _state()
	var enc: String = data.floor_def(1).timer_start_after
	var setup: BattleSetup = BattleBridge.make_setup(st, data, enc, BattleSetup.Advantage.NORMAL, "", 77)
	assert_not_null(setup)
	if setup == null:
		return
	var battle: BattleState = BattleState.new(setup, data)
	battle.start()
	var h0: String = StateHash.of_battle(battle)
	assert_true(_hex.search(h0) != null, "battle hash: " + h0)
	var copy: BattleState = BattleState.from_dict(JSON.parse_string(JSON.stringify(battle.to_dict())), data)
	assert_eq(StateHash.of_battle(copy), h0, "snapshot → from_dict → same hash (resync, 05 §3.4)")
	var cmd: BattleCommand = battle.choose_ai_command()
	battle.submit(cmd)
	copy.submit(BattleCommand.from_dict(cmd.to_dict()))
	assert_ne(StateHash.of_battle(battle), h0, "an action changes the hash")
	assert_eq(StateHash.of_battle(copy), StateHash.of_battle(battle), "restored battle continues identically")
	assert_eq(StateHash.of_battle(null), "")
