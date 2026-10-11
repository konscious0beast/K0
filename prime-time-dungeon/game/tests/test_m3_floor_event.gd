extends TestCase
## FloorEvent (02_TECH §7.4, GDD §2.6): choices / resolve / apply for all 5 types with fixed seeds, plus the
## Game.apply_floor_event integration (seed k × 16 + uses, completion signal) on the exploration fixture floor. Uses its
## own fixture data (independent of the M7 content), including the inventory side effects.

const ExplorationTests := preload("res://tests/test_m3_exploration_scene.gd")

var _saved_db: GameData = null


func after_each() -> void:
	if _saved_db != null:
		DB.data = _saved_db
		_saved_db = null


func _data() -> GameData:
	var model: Dictionary = {"base": "humanoid", "colors": {"primary": "#3aa9a0"}}
	var stats_kai: Dictionary = {"hp": 64, "mp": 12, "str": 12, "mag": 5, "def": 9, "res": 6, "spd": 11, "lck": 8}
	var growth: Dictionary = {"hp": 9.0, "mp": 2.0, "str": 2.0, "mag": 0.6, "def": 1.5, "res": 0.8, "spd": 0.5,
		"lck": 0.5}
	var stats_mop: Dictionary = {"hp": 42, "mp": 30, "str": 5, "mag": 13, "def": 6, "res": 11, "spd": 14, "lck": 12}
	return fixture_data({
		"skills": [{"id": "skl_t_attack", "name": "Hieb", "user": "party", "category": "attack",
			"target": "single_enemy", "damage_type": "physical", "element": "physical"},
			{"id": "skl_item_t_heal", "name": "Heilen", "user": "item", "category": "item", "target": "single_ally",
				"damage_type": "heal", "heal_mode": "fixed", "power": 30}],
		"items": [
			_item("itm_t_bandage", "Verband", ["heal"], 25),
			_item("itm_t_salve", "Salbe", ["heal"], 40),
			_item("itm_t_antidote", "Gegengift", ["cure"], 20),
			_item("itm_t_ticket", "Glückslos", [], 10),
			_item("itm_t_krawumm", "KRAWUMM", [], 30),
		],
		"party": [
			{"id": "kai", "name": "Kai", "battle_slot": 0, "base_stats": stats_kai, "growth": growth,
				"attack_skill": "skl_t_attack", "model": model},
			{"id": "mopsula", "name": "Graf Mopsula", "battle_slot": 1, "base_stats": stats_mop, "growth": growth,
				"attack_skill": "skl_t_attack", "model": model},
		],
		"party_start": {"inventory": {"itm_t_bandage": 2, "itm_t_antidote": 1, "itm_t_salve": 1}, "credits": 50},
	})


static func _item(id: String, item_name: String, tags: Array, price: int) -> Dictionary:
	return {"id": id, "name": item_name, "type": "consumable", "tags": tags, "price": price,
		"use_skill": "skl_item_t_heal", "usable": "both"}


func _state(data: GameData) -> GameState:
	var st: GameState = GameState.create_new(data, 0, "Kai", 1)
	st.floor_run = FloorRun.new()
	st.floor_run.floor_id = "floor_1"
	st.floor_run.index = 1
	st.floor_run.seed = 99
	# Deterministic party HP for the damage tests (independent of M2's level/equipment logic).
	for m: PartyMember in st.party:
		m.level = 1
		m.hp = int(data.party_member(m.id).base_stats["hp"])
	return st


func _ev(type: String, params: Dictionary, id: String = "") -> EventSpawn:
	var e: EventSpawn = EventSpawn.new()
	e.id = id if id != "" else "fev_t_" + type
	e.type = type
	e.cell = Vector2i(1, 1)
	e.params = params
	return e


func _drone() -> EventSpawn:
	return _ev("photo_drone", {"pose_hype": 15, "pose_followers": 20, "smash_credits": 30, "smash_hype": -5})


func _candidate() -> EventSpawn:
	return _ev("lost_candidate", {"tag": "heal", "reward_item": "itm_t_ticket", "followers": 40})


func _wheel(cost: int = 20) -> EventSpawn:
	return _ev("wheel", {"cost": cost, "max_spins": 3, "table": [
		{"weight": 35, "kind": "item", "id": "itm_t_bandage", "amount": 2},
		{"weight": 25, "kind": "credits", "id": "", "amount": 50},
		{"weight": 15, "kind": "box", "id": "box_bronze", "amount": 1},
		{"weight": 15, "kind": "nothing", "id": "", "amount": 0},
		{"weight": 10, "kind": "encounter", "id": "enc_f1_evt_pigeons", "amount": 1}]})


func _lever(success: float) -> EventSpawn:
	return _ev("lever", {"success": success, "gate": "4,3,N", "flood_pct": 15, "encounter": "enc_f1_evt_slime"})


func _vending(base: float, per_lck: float) -> EventSpawn:
	return _ev("broken_vending", {"base": base, "per_lck": per_lck, "reward_item": "itm_t_krawumm", "reward_amount": 2,
		"fail_pct": 10, "fail_hype": 4})


# --- photo_drone ------------------------------------------------------------------------------------------------------

func test_photo_drone() -> void:
	var data: GameData = _data()
	var st: GameState = _state(data)
	var ev: EventSpawn = _drone()
	assert_eq(FloorEvent.choices(ev, st, data), PackedStringArray(["pose", "smash"]))
	var pose: Dictionary = FloorEvent.resolve(ev, "pose", st, data, make_rng(1))
	assert_true(bool(pose["valid"]))
	assert_true(bool(pose["completed"]))
	assert_almost(float(pose["hype"]), 15.0)
	assert_eq(pose["followers"], 20)
	assert_eq(pose["credits"], 0)
	assert_eq(pose["mod_tag"], "event_photo_drone_pose")
	var smash: Dictionary = FloorEvent.resolve(ev, "smash", st, data, make_rng(1))
	assert_eq(smash["credits"], 30)
	assert_almost(float(smash["hype"]), -5.0)
	assert_eq(smash["mod_tag"], "event_photo_drone_smash")
	assert_true(bool(smash["completed"]))
	# resolve is pure.
	assert_false(st.floor_run.completed_events.has(ev.id))
	FloorEvent.apply(pose, ev, "pose", st, data)
	assert_has(st.floor_run.completed_events, ev.id)
	assert_eq(int(st.floor_run.event_uses[ev.id]), 1)
	assert_eq(FloorEvent.choices(ev, st, data), PackedStringArray(), "completed → nothing left")
	var again: Dictionary = FloorEvent.resolve(ev, "smash", st, data, make_rng(1))
	assert_false(bool(again["valid"]), "a completed event cannot be repeated")
	FloorEvent.apply(again, ev, "smash", st, data)
	assert_eq(st.floor_run.completed_events.size(), 1, "invalid outcome changes nothing")


func test_photo_drone_credits() -> void:
	var data: GameData = _data()
	var st: GameState = _state(data)
	var before: int = st.inventory.credits
	var ev: EventSpawn = _drone()
	FloorEvent.apply(FloorEvent.resolve(ev, "smash", st, data, make_rng(1)), ev, "smash", st, data)
	assert_eq(st.inventory.credits, before + 30)


# --- lost_candidate ---------------------------------------------------------------------------------------------------

func test_lost_candidate() -> void:
	var data: GameData = _data()
	var st: GameState = _state(data)
	var ev: EventSpawn = _candidate()
	assert_eq(FloorEvent.choices(ev, st, data),
		PackedStringArray(["give:itm_t_bandage", "give:itm_t_salve", "leave"]), "heal items sorted, cure excluded")
	var give: Dictionary = FloorEvent.resolve(ev, "give:itm_t_salve", st, data, make_rng(3))
	assert_true(bool(give["completed"]))
	assert_eq(give["items_remove"], {"itm_t_salve": 1})
	assert_eq(give["items_add"], {"itm_t_ticket": 1})
	assert_eq(give["followers"], 40)
	assert_eq(give["mod_tag"], "event_lost_candidate_give")
	var bad: Dictionary = FloorEvent.resolve(ev, "give:itm_t_antidote", st, data, make_rng(3))
	assert_false(bool(bad["valid"]), "only heal items can be given")
	var leave: Dictionary = FloorEvent.resolve(ev, "leave", st, data, make_rng(3))
	assert_true(bool(leave["valid"]))
	assert_false(bool(leave["completed"]), "leave keeps the event open (§7.4)")
	assert_eq(leave["mod_tag"], "event_lost_candidate_leave")
	FloorEvent.apply(leave, ev, "leave", st, data)
	assert_false(st.floor_run.completed_events.has(ev.id))
	assert_false(st.floor_run.event_uses.has(ev.id), "passive choices are no uses")
	FloorEvent.apply(give, ev, "give:itm_t_salve", st, data)
	assert_has(st.floor_run.completed_events, ev.id)
	assert_eq(FloorEvent.choices(ev, st, data), PackedStringArray())
	# Without heal items only "leave" is possible.
	var st2: GameState = _state(data)
	st2.inventory.counts = {"itm_t_antidote": 2}
	assert_eq(FloorEvent.choices(ev, st2, data), PackedStringArray(["leave"]))


func test_lost_candidate_items() -> void:
	var data: GameData = _data()
	var st: GameState = _state(data)
	var ev: EventSpawn = _candidate()
	var bandages: int = st.inventory.count("itm_t_bandage")
	FloorEvent.apply(FloorEvent.resolve(ev, "give:itm_t_bandage", st, data, make_rng(1)), ev, "give:itm_t_bandage",
		st, data)
	assert_eq(st.inventory.count("itm_t_bandage"), bandages - 1)
	assert_eq(st.inventory.count("itm_t_ticket"), 1)


# --- wheel ------------------------------------------------------------------------------------------------------------

func test_wheel_spin_rules() -> void:
	var data: GameData = _data()
	var st: GameState = _state(data)
	var ev: EventSpawn = _wheel()
	var cost: int = int(ev.params["cost"])
	var max_spins: int = int(ev.params["max_spins"])
	# The real Inventory pays every spin: credits for one spin more than allowed, so only max_spins can stop the wheel.
	st.inventory.credits = cost * (max_spins + 1)
	assert_eq(FloorEvent.choices(ev, st, data), PackedStringArray(["spin", "ignore"]))
	var first: Dictionary = FloorEvent.resolve(ev, "spin", st, data, make_rng(5))
	assert_true(bool(first["completed"]), "first spin completes the event")
	assert_eq(first["mod_tag"], "event_wheel_spin")
	var entry: Dictionary = first["wheel"]
	assert_false(entry.is_empty(), "a wheel entry was hit")
	var expected_credits: int = -cost + (int(entry["amount"]) if str(entry["kind"]) == "credits" else 0)
	assert_eq(first["credits"], expected_credits, "spin costs the wheel's cost (20 Cr)")
	# Same seed → same entry.
	assert_eq(FloorEvent.resolve(ev, "spin", st, data, make_rng(5))["wheel"], entry)
	FloorEvent.apply(first, ev, "spin", st, data)
	assert_eq(int(st.floor_run.event_uses[ev.id]), 1)
	assert_has(st.floor_run.completed_events, ev.id)
	var second: Dictionary = FloorEvent.resolve(ev, "spin", st, data, make_rng(6))
	assert_true(bool(second["valid"]), "further spins after completion")
	assert_false(bool(second["completed"]), "no second completion bonus")
	FloorEvent.apply(second, ev, "spin", st, data)
	FloorEvent.apply(FloorEvent.resolve(ev, "spin", st, data, make_rng(7)), ev, "spin", st, data)
	assert_eq(int(st.floor_run.event_uses[ev.id]), max_spins)
	assert_true(st.inventory.credits >= cost, "credits left for a 4th spin")
	assert_eq(FloorEvent.choices(ev, st, data), PackedStringArray(), "max_spins reached")
	# Not enough credits → only ignore.
	var poor: GameState = _state(data)
	poor.inventory.credits = cost - 1
	assert_eq(FloorEvent.choices(ev, poor, data), PackedStringArray(["ignore"]))
	var ign: Dictionary = FloorEvent.resolve(ev, "ignore", poor, data, make_rng(1))
	assert_true(bool(ign["valid"]))
	assert_false(bool(ign["completed"]))


func test_wheel_kinds_and_weights() -> void:
	var data: GameData = _data()
	var st: GameState = _state(data)
	var ev: EventSpawn = _wheel()
	var counts: Dictionary = {}
	var n: int = 4000
	for s in n:
		var o: Dictionary = FloorEvent.resolve(ev, "spin", st, data, make_rng(s + 1))
		var kind: String = str((o["wheel"] as Dictionary)["kind"])
		counts[kind] = int(counts.get(kind, 0)) + 1
		match kind:
			"item":
				assert_eq(o["items_add"], {"itm_t_bandage": 2})
			"credits":
				assert_eq(o["credits"], 30)
			"box":
				assert_eq(o["boxes"], PackedStringArray(["box_bronze"]))
			"encounter":
				assert_eq(o["encounter_id"], "enc_f1_evt_pigeons")
			"nothing":
				assert_eq(o["credits"], -20)
	var expect: Dictionary = {"item": 0.35, "credits": 0.25, "box": 0.15, "nothing": 0.15, "encounter": 0.10}
	for k: String in expect.keys():
		assert_almost(int(counts.get(k, 0)) / float(n), float(expect[k]), 0.03, "weight of %s" % k)


# --- lever ------------------------------------------------------------------------------------------------------------

func test_lever_success_and_flood() -> void:
	var data: GameData = _data()
	var st: GameState = _state(data)
	var ok: Dictionary = FloorEvent.resolve(_lever(1.0), "pull", st, data, make_rng(1))
	assert_true(bool(ok["success"]))
	assert_eq(ok["open_gate"], "4,3,N")
	assert_eq(ok["encounter_id"], "")
	assert_eq(ok["mod_tag"], "event_lever_open")
	assert_true(bool(ok["completed"]))
	var ev_fail: EventSpawn = _lever(0.0)
	var fail: Dictionary = FloorEvent.resolve(ev_fail, "pull", st, data, make_rng(1))
	assert_false(bool(fail["success"]))
	assert_eq(fail["open_gate"], "")
	assert_eq(fail["encounter_id"], "enc_f1_evt_slime")
	assert_eq(fail["party_damage_pct"], {"kai": 15, "mopsula": 15})
	assert_true(bool(fail["completed"]), "the flood also completes the event")
	var kai: PartyMember = st.member("kai")
	var mop: PartyMember = st.member("mopsula")
	var kai_max: int = FloorEvent.max_hp_of(kai, data)
	var kai_hp: int = kai.hp
	mop.hp = 3
	FloorEvent.apply(fail, ev_fail, "pull", st, data)
	assert_eq(kai.hp, kai_hp - maxi(1, floori(kai_max * 0.15)), "−15 % MaxHP")
	assert_eq(mop.hp, 1, "never below 1 HP")
	assert_has(st.floor_run.completed_events, ev_fail.id)
	assert_false(st.floor_run.opened_gates.has("4,3,N"))
	var st2: GameState = _state(data)
	var ev_ok: EventSpawn = _lever(1.0)
	FloorEvent.apply(FloorEvent.resolve(ev_ok, "pull", st2, data, make_rng(1)), ev_ok, "pull", st2, data)
	assert_has(st2.floor_run.opened_gates, "4,3,N")
	# KO'd members are not hit by the flood.
	var st3: GameState = _state(data)
	st3.member("mopsula").hp = 0
	assert_eq(FloorEvent.resolve(ev_fail, "pull", st3, data, make_rng(1))["party_damage_pct"], {"kai": 15})


func test_lever_chance_over_seeds() -> void:
	var data: GameData = _data()
	var st: GameState = _state(data)
	var ev: EventSpawn = _lever(0.6)
	var wins: int = 0
	for s in 2000:
		if bool(FloorEvent.resolve(ev, "pull", st, data, make_rng(s + 1))["success"]):
			wins += 1
	assert_almost(wins / 2000.0, 0.6, 0.04)
	assert_eq(FloorEvent.resolve(ev, "pull", st, data, make_rng(42))["success"],
		FloorEvent.resolve(ev, "pull", st, data, make_rng(42))["success"], "fixed seed → fixed result")
	var leave: Dictionary = FloorEvent.resolve(ev, "leave", st, data, make_rng(1))
	assert_true(bool(leave["valid"]))
	assert_false(bool(leave["completed"]))


# --- broken_vending ---------------------------------------------------------------------------------------------------

func test_broken_vending() -> void:
	var data: GameData = _data()
	var st: GameState = _state(data)
	var ok: Dictionary = FloorEvent.resolve(_vending(1.0, 0.0), "kick", st, data, make_rng(1))
	assert_true(bool(ok["success"]))
	assert_eq(ok["items_add"], {"itm_t_krawumm": 2})
	assert_eq(ok["mod_tag"], "event_broken_vending_ok")
	var ev_fail: EventSpawn = _vending(0.0, 0.0)
	var fail: Dictionary = FloorEvent.resolve(ev_fail, "kick", st, data, make_rng(1))
	assert_false(bool(fail["success"]))
	assert_eq(fail["party_damage_pct"], {"kai": 10})
	assert_almost(float(fail["hype"]), 4.0)
	assert_eq(fail["mod_tag"], "event_broken_vending_fail")
	var kai: PartyMember = st.member("kai")
	var before: int = kai.hp
	FloorEvent.apply(fail, ev_fail, "kick", st, data)
	assert_eq(kai.hp, before - maxi(1, floori(FloorEvent.max_hp_of(kai, data) * 0.10)))
	assert_has(st.floor_run.completed_events, ev_fail.id)
	assert_eq(FloorEvent.choices(ev_fail, st, data), PackedStringArray())


func test_broken_vending_luck() -> void:
	var data: GameData = _data()
	var st: GameState = _state(data)
	var lck: int = FloorEvent.stat_of(st.member("kai"), data, "lck")
	assert_eq(lck, 8, "Kai LCK at level 1 without equipment")
	var ev: EventSpawn = _vending(0.0, 0.05)    # chance = 8 × 0.05 = 0.40
	var wins: int = 0
	for s in 2000:
		if bool(FloorEvent.resolve(ev, "kick", st, data, make_rng(s + 1))["success"]):
			wins += 1
	assert_almost(wins / 2000.0, 0.40, 0.04, "chance = base + LCK × per_lck")


func test_unknown_type_and_bad_input() -> void:
	var data: GameData = _data()
	var st: GameState = _state(data)
	var ev: EventSpawn = _ev("bogus", {})
	assert_eq(FloorEvent.choices(ev, st, data), PackedStringArray())
	assert_false(bool(FloorEvent.resolve(ev, "x", st, data, make_rng(1))["valid"]))
	assert_eq(FloorEvent.choices(null, st, data), PackedStringArray())
	var no_floor: GameState = GameState.create_new(data, 0, "Kai", 1)
	assert_eq(FloorEvent.choices(_drone(), no_floor, data), PackedStringArray())
	FloorEvent.apply({}, _drone(), "pose", st, data)
	assert_true(st.floor_run.completed_events.is_empty())


# --- Game integration -------------------------------------------------------------------------------------------------

func test_game_apply_floor_event_integration() -> void:
	# Fixture floor (independent of M7 content): the wheel is event k = 1 and draws random numbers, so the seed
	# contract of §7.4 (derive(floor_run.seed, "event", k × 16 + event_uses)) is really checked.
	var fixture: GameData = ExplorationTests.fixture_game_data()
	if fixture == null:
		fail("m3 exploration fixture data invalid")
		return
	_saved_db = DB.data
	DB.data = fixture
	Game.new_game(0, "Kai", 4242)
	var layout: FloorLayout = DungeonGenerator.generate(Game.floor_def(), Game.state.floor_run.seed)
	var k: int = -1
	for i in layout.events.size():
		if layout.events[i].id == "fev_t_wheel":
			k = i
	assert_gt(k, 0, "wheel is not the first event")
	var ev: EventSpawn = layout.events[k]
	var spy: Array[Dictionary] = []
	var cb: Callable = func(payload: Dictionary) -> void: spy.append(payload)
	Events.event_completed.connect(cb)
	var fseed: int = Game.state.floor_run.seed
	for n in 2:
		assert_eq(int(Game.state.floor_run.event_uses.get(ev.id, 0)), n, "event_uses before spin %d" % n)
		var rng: RandomNumberGenerator = SeedUtil.make_rng(SeedUtil.derive(fseed, "event", k * 16 + n))
		var expected: Dictionary = FloorEvent.resolve(ev, "spin", Game.state, DB.data, rng)
		var out: Dictionary = Game.apply_floor_event(ev.id, "spin")
		assert_eq(out, expected, "spin %d = resolve() with derive(seed, \"event\", k × 16 + %d)" % [n, n])
		assert_true(bool(out.get("valid", false)), "spin %d valid" % n)
	Events.event_completed.disconnect(cb)
	assert_eq(int(Game.state.floor_run.event_uses.get(ev.id, 0)), 2, "event_uses 0 → 1 → 2")
	assert_has(Game.state.floor_run.completed_events, ev.id)
	assert_len(spy, 1, "only the first spin completes the event")
	if spy.size() == 1:
		assert_eq(spy[0], {"event_id": ev.id, "choice": "spin"})
	# A different use count would draw differently somewhere over the table (the seed really advances). The two spins
	# above were paid from the start credits; top them up so a further spin is affordable.
	Game.state.inventory.credits = int(ev.params["cost"])
	var differs: bool = false
	for n in 8:
		var a: Dictionary = FloorEvent.resolve(ev, "spin", Game.state, DB.data,
			SeedUtil.make_rng(SeedUtil.derive(fseed, "event", k * 16 + n)))
		var b: Dictionary = FloorEvent.resolve(ev, "spin", Game.state, DB.data,
			SeedUtil.make_rng(SeedUtil.derive(fseed, "event", k * 16 + n + 1)))
		differs = differs or a["wheel"] != b["wheel"]
	assert_true(differs, "the wheel outcome depends on the use count")
