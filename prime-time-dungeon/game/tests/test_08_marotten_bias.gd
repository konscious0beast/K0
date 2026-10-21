extends TestCase
## 08 §4.8 (C-8, K1): the card's traits weight M.O.D.'s preferences from floor 2 on — the floor-1 announcement is the
## same with and without bias, from floor 2 every biased id draws with weight + 1 (PersonaRules.weight_add →
## MarottenRules._draw_weight), deterministic per seed, and live, RunSim.replay and Game.replay_log agree.


func _state(data: GameData, seed: int, bias: Array) -> GameState:
	var st: GameState = GameState.create_new(data, 0, "Kai", seed, &"prime")
	var sim: RunSim = RunSim.new(data, st, {}, {})
	sim.apply({"t": "floor", "floor": 1})
	sim.apply({"t": "hero", "id": "kai"})
	if not bias.is_empty():
		assert_true(PersonaRules.apply(st, data, {"t": "persona", "v": 1, "talent": "", "bias": bias}))
	return st


func test_floor_1_is_unchanged() -> void:
	var data: GameData = real_data()
	for seed: int in [1, 2, 3, 4, 5, 77, 4242]:
		var plain: GameState = _state(data, seed, [])
		var biased: GameState = _state(data, seed, ["mar_bio", "mar_brave", "mar_stunt"])
		assert_eq(MarottenRules.announce(biased, data, 1, PackedStringArray()),
			MarottenRules.announce(plain, data, 1, PackedStringArray()), "floor 1, seed %d" % seed)


func test_weight_from_floor_2() -> void:
	var data: GameData = real_data()
	var st: GameState = _state(data, 9, ["mar_brave"])
	var brave: MarotteDef = data.marotte("mar_brave")
	assert_eq(MarottenRules._draw_weight(st, brave, 1), maxi(1, brave.weight), "floor 1: no bias")
	assert_eq(MarottenRules._draw_weight(st, brave, 2), maxi(1, brave.weight) + PersonaRules.BIAS_WEIGHT_ADD)
	assert_eq(MarottenRules._draw_weight(st, data.marotte("mar_stunt"), 2), maxi(1, data.marotte("mar_stunt").weight))


func test_bias_shifts_the_draw_but_stays_deterministic() -> void:
	var data: GameData = real_data()
	var hits_plain: int = 0
	var hits_biased: int = 0
	for seed in range(1, 401):
		var plain: GameState = _state(data, seed, [])
		var biased: GameState = _state(data, seed, ["mar_brave"])
		if MarottenRules.announce(plain, data, 2, PackedStringArray()).has("mar_brave"):
			hits_plain += 1
		var a: PackedStringArray = MarottenRules.announce(biased, data, 2, PackedStringArray())
		if a.has("mar_brave"):
			hits_biased += 1
		assert_eq(a, MarottenRules.announce(_state(data, seed, ["mar_brave"]), data, 2, PackedStringArray()),
			"same seed, same bias → same announcement")
	assert_gt(hits_biased, hits_plain, "08 §4.8: a biased preference comes more often (%d vs %d of 400)" % [
		hits_biased, hits_plain])
	assert_lt(hits_biased, 400, "noticeable, never certain")


func test_replay_matches_with_a_persona() -> void:
	var p: PersonaProfile = PersonaProfile.canon(DB.data)
	p.traits = PackedStringArray(["trt_sporty", "trt_brave"])
	Game.new_game(0, "Kai", 31337, &"prime", "kai", p)
	assert_eq(PersonaRules.bias(Game.state), PackedStringArray(["mar_brave", "mar_stunt"]))
	var live: String = StateHash.of(Game.state)
	var a: Dictionary = Game.replay_log(Game.run_log, Game.sim.tick())
	assert_eq(a["errors"], PackedStringArray())
	assert_eq(a["final_hash"], live, "Game.replay_log ≡ live")
	var r: Dictionary = RunSim.replay(DB.data, Game.run_log)
	assert_eq(r["errors"], PackedStringArray(), "RunSim.replay")
	Game.state = null
	Game.run_log = null
	Game.sim = null
	Game.persona = null
