extends TestCase
## Integration round 4 (06 §4.3, decision I-8): the Liga follower bonus is capped per floor. Per won Liga battle the
## followers the tier's follower factor adds (followers with the factor − without) are booked in
## ShowState.marotten.liga.followers and paid only up to reward.tiers[].floor_follower_cap of the battle's tier (both
## tiers fill the same floor sum; on_floor starts over; no key = unbounded like package C). The hype factor, the
## Liga achievements and the Mut-Paket are not capped. Saved + hashed: Game.replay_log repeats it.

const BetsMenu := preload("res://scenes/ui/bets_menu.gd")
const CAP_T1: int = 2
const CAP_T2: int = 3
const TEST_F2: int = 1500                      # a big Duo follower factor: the bonus of one battle exceeds the caps

var _prev_data: GameData = null
var _data: GameData = null
var _caps: Dictionary = {}


func before_each() -> void:
	_prev_data = DB.data
	_caps = {1: CAP_T1, 2: CAP_T2}
	_reload()


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
	_data = null


## cap < 0 removes the key (unbounded); the data is loaded again (GameData is read-only) and becomes DB.data.
func _set_cap(tier: int, cap: int) -> void:
	_caps[tier] = cap
	_reload()


## Own GameData from the real tables with the test caps and TEST_F2 (never the shared, cached real_data()).
func _reload() -> void:
	var raw: Dictionary = _raw_tables()
	for t: Dictionary in _liga_tiers(raw):
		var tier: int = int(t["tier"])
		if tier == 2:
			t["follower_pm"] = TEST_F2
		if int(_caps.get(tier, -1)) < 0:
			t.erase("floor_follower_cap")
		else:
			t["floor_follower_cap"] = int(_caps[tier])
	_data = GameData.new()
	_data.load_from_tables(raw)
	assert_eq(_data.errors, PackedStringArray(), "test data")
	DB.data = _data


func test_rules_cap_the_floor_sum() -> void:
	var st: GameState = GameState.create_new(_data, 0, "Kai", 21)
	RunRules.start_floor(st, _data, 1)
	MarottenRules.on_floor(st, _data, 1, {})
	assert_eq([MarottenRules.liga_floor_cap(_data, 0), MarottenRules.liga_floor_cap(_data, 1),
		MarottenRules.liga_floor_cap(_data, 2)], [-1, CAP_T1, CAP_T2])
	assert_eq(MarottenRules.take_liga_followers(st, _data, 1, 1), 1)
	assert_eq(MarottenRules.take_liga_followers(st, _data, 1, 5), 1, "tier 1: at most 2 on this floor")
	assert_eq(MarottenRules.take_liga_followers(st, _data, 1, 5), 0)
	assert_eq(MarottenRules.take_liga_followers(st, _data, 2, 5), 1, "tier 2 fills the same floor sum up to 3")
	assert_eq(MarottenRules.liga_followers_left(st, _data, 2), 0)
	assert_eq(MarottenRules.liga_followers_left(st, _data, 1), 0)
	assert_eq(int(st.show.marotten["liga"]["followers"]), 3)
	assert_eq(MarottenRules.take_liga_followers(st, _data, 2, 0), 0, "nothing wanted, nothing booked")
	MarottenRules.on_floor(st, _data, 2, {})
	assert_eq(MarottenRules.liga_followers_left(st, _data, 2), CAP_T2, "a new floor starts over")
	assert_eq(MarottenRules.take_liga_followers(st, _data, 2, 9), CAP_T2)
	_set_cap(2, -1)
	assert_eq(MarottenRules.liga_followers_left(st, _data, 2), -1, "no key: unbounded")
	assert_eq(MarottenRules.take_liga_followers(st, _data, 2, 40), 40, "package C's uncapped factor")
	assert_eq(int(st.show.marotten["liga"]["followers"]), CAP_T2 + 40, "still booked")
	var bare: GameState = GameState.create_new(_data, 0, "Kai", 22)
	assert_eq(MarottenRules.take_liga_followers(bare, _data, 2, 7), 7, "no floor record (tests): unchanged")
	assert_eq(bare.show.marotten, {}, "nothing booked without a floor record")
	var v: Dictionary = MarottenRules.view(st, _data, {})
	assert_true(v.has("liga_follower_cap") and v.has("liga_followers_left"), "the view carries the cap")


## The same Duo-Liga battle twice on one floor: unbounded / cap 0 / cap 2 — the capped run pays the base plus at most
## the cap, the floor record holds the paid bonus and the second battle adds none once the cap is used up.
func test_show_pays_the_bonus_only_up_to_the_cap() -> void:
	var none: Dictionary = _two_battles(-1)
	var zero: Dictionary = _two_battles(0)
	var capped: Dictionary = _two_battles(2)
	assert_eq(zero["booked"], [0, 0], "cap 0: no Liga follower bonus at all")
	assert_gt(int(none["booked"][0]), 2, "the factor adds more than the test cap in one battle")
	assert_gt(int(none["booked"][1]), int(none["booked"][0]), "unbounded: the second battle adds its bonus too")
	assert_eq(capped["booked"], [2, 2], "cap 2: the first battle fills it, the second adds nothing")
	assert_eq(int(capped["gains"][0]), int(zero["gains"][0]) + 2, "first battle: base + the capped bonus")
	assert_eq(int(none["gains"][0]), int(zero["gains"][0]) + int(none["booked"][0]), "base + the whole bonus")
	assert_between(int(capped["followers"]) - int(zero["followers"]), 2, 3,
		"after two battles the capped run is ahead only by the cap (+ the viewer feedback of 2 followers)")
	assert_gt(int(none["followers"]), int(capped["followers"]), "the uncapped factor keeps paying")


func _two_battles(cap: int) -> Dictionary:
	_set_cap(2, cap)
	Game.new_game(0, "Kai", 6161)
	var st: GameState = Game.state
	for a: AchievementDef in DB.data.all_achievements():
		st.show.achievements.append(a.id)                 # no achievement followers in between
	st.show.marotten["active"] = []
	for id: String in ["kai", "mopsula"]:
		st.member(id).equipment["armor"] = ""
		st.member(id).equipment["accessory"] = ""
	var gains: Array = []
	var booked: Array = []
	for i in 2:
		gains.append(_battle(st, i))
		booked.append(int((st.show.marotten.get("liga", {}) as Dictionary).get("followers", 0)))
	return {"gains": gains, "booked": booked, "followers": st.show.followers}


func _battle(st: GameState, i: int) -> int:
	var setup: BattleSetup = BattleBridge.make_setup(st, DB.data, "enc_f1_a2", BattleSetup.Advantage.NORMAL, "",
		SeedUtil.derive(1, "cap", i))
	Game.in_battle = true
	Show.begin_battle(setup)
	Show.on_battle_event(ActionEvent.make(ActionEvent.Type.BATTLE_START))
	var r: BattleResult = BattleResult.new()
	r.outcome = BattleResult.Outcome.VICTORY
	r.encounter_id = "enc_f1_a2"
	r.party_turns = 4
	r.min_party_hp_pct = 0.9
	r.damage_taken = 10
	Game.in_battle = false
	return Show.end_battle(r)


## Live through the Game facade: Duo-Liga battles fill the cap; the record survives save → load (SaveCodec) and
## Game.replay_log ≡ live.
func test_live_capped_liga_replays_and_saves() -> void:
	Game.auto_battle = true
	Game.new_game(1, "Kai", 6464)
	for m: PartyMember in Game.state.party:
		m.level = 5
	Progression.full_heal(Game.state, DB.data)
	# the test's level-5 party is no recorded command: save + load so the log starts at that state (its anchor)
	var sr: String = str((DB.floor_def(1).layout.get("safe_rooms", [{}]) as Array)[0].get("id", ""))
	Game.enter_safe_room(sr)
	assert_eq(Save.save_slot(1), OK, Save.last_error())
	assert_eq(Save.load_slot(1), OK, Save.last_error())
	Game.enter_safe_room(sr)
	assert_true(Game.equip("kai", "armor", ""), "Kai: hoodie off")
	assert_true(Game.equip("mopsula", "armor", ""), "Mopsula: sweater off → Duo-Liga")
	Game.leave_safe_room()
	assert_eq(MarottenRules.liga_tier(Game.state), 2)
	for enc: String in ["enc_f1_a2", "enc_f1_a3"]:
		assert_true(_fight(enc), enc + " won")
	Game.auto_battle = false
	assert_eq(int(Game.state.show.stats.get("liga_battles", 0)), 2)
	assert_eq(int(Game.state.show.marotten["liga"]["followers"]), CAP_T2, "two Duo battles fill the cap of 3")
	assert_eq(Show.marotten_view()["liga_followers_left"], 0)
	var copy: GameState = SaveCodec.decode(JSON.parse_string(JSON.stringify(SaveCodec.encode(Game.state, "t"))), DB.data)
	assert_not_null(copy, "; ".join(SaveCodec.last_errors()))
	if copy != null:
		assert_eq(int(copy.show.marotten["liga"]["followers"]), CAP_T2, "saved with the run")
	var h: String = StateHash.of(Game.state)
	var res: Dictionary = Game.replay_log(Game.run_log)
	assert_eq(res["errors"], PackedStringArray())
	assert_eq(res["final_hash"], h, "Game.replay_log ≡ live with the capped Liga bonus")


func _fight(enc_id: String) -> bool:
	var setup: BattleSetup = Game.make_battle_setup(enc_id, BattleSetup.Advantage.PREEMPTIVE, "")
	var battle: BattleState = BattleState.new(setup, DB.data)
	Show.begin_battle(setup)
	_play(battle, battle.start())
	var guard: int = 0
	while not battle.is_finished() and guard < 400:
		guard += 1
		var cmd: BattleCommand = battle.choose_ai_command()
		Game.record({"t": "battle", "cmd": cmd.to_dict(), "auto": true})
		_play(battle, battle.submit(cmd))
	Game.apply_battle_result(battle.result)
	Show.end_battle(battle.result)
	return battle.result.outcome == BattleResult.Outcome.VICTORY


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


func test_validator_checks_the_cap() -> void:
	for c: Array in [[-1, "floor_follower_cap: out of range 0..2000"], ["viel", "floor_follower_cap: expected integer"],
			[2500, "out of range 0..2000"]]:
		var raw: Dictionary = _raw_tables()
		_liga_tiers(raw)[1]["floor_follower_cap"] = c[0]
		_expect(raw, str(c[1]))
	var raw2: Dictionary = _raw_tables()
	_liga_tiers(raw2)[0]["follower_cap"] = 10
	_expect(raw2, "follower_cap: unknown key")
	var raw3: Dictionary = _raw_tables()
	_liga_tiers(raw3)[0].erase("floor_follower_cap")
	var d: GameData = GameData.new()
	d.load_from_tables(raw3)
	assert_eq(d.errors, PackedStringArray(), "the key is optional")


func test_show_tab_names_the_cap() -> void:
	var text: String = BetsMenu._tier_text({"liga_tier": 2, "rewards": true, "liga_followers_left": 1})
	assert_has(text, "(bis +%d je Etage)" % CAP_T1)
	assert_has(text, "(bis +%d je Etage)" % CAP_T2)
	assert_has(text, "noch +1 Follower")
	assert_false(BetsMenu._tier_text({"liga_tier": 0, "rewards": true, "liga_followers_left": -1}).contains("noch"),
		"outside the Liga no rest")
	_set_cap(1, -1)
	_set_cap(2, -1)
	assert_false(BetsMenu._tier_text({"liga_tier": 1, "rewards": true}).contains("je Etage"), "no cap, no text")


func _raw_tables() -> Dictionary:
	var raw: Dictionary = {}
	for t: String in GameData.TABLES:
		raw[t] = JsonUtil.read_file("res://data/%s.json" % t)
	return raw


func _liga_tiers(raw: Dictionary) -> Array:
	for e: Dictionary in raw["marotten"]["entries"]:
		if str(e.get("kind", "")) == "liga":
			return e["reward"]["tiers"]
	return []


func _expect(raw: Dictionary, needle: String) -> void:
	var d: GameData = GameData.new()
	d.load_from_tables(raw)
	for e: String in d.errors:
		if e.contains(needle):
			return
	fail("expected an error containing '%s', got [%s]" % [needle, "; ".join(d.errors)])
