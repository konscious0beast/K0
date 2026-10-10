extends TestCase
## Command.validate per "t" (02_TECH §3.4, 05 §11.4): required fields, types, ranges, unknown type → error; ExploreEvent
## to_dict/from_dict round trip; every command the live Game records passes the schema (integration with M0's Game).

const VALID: Array[Dictionary] = [
	{"t": "floor", "floor": 1},
	{"t": "encounter", "enc": "enc_f1_a2", "adv": 2, "group": "f1_g3"},
	{"t": "encounter", "enc": "enc_f1_evt_pigeons", "adv": 0, "group": ""},
	{"t": "battle", "cmd": {"kind": "skill", "actor": "p0", "skill": "skl_kai_heavy_swing", "item": "", "targets": ["e1"]},
		"auto": false},
	{"t": "lootbox", "box": "box_bronze"},
	{"t": "buy", "item": "itm_bandage", "qty": 2, "safe_room": "sr_kiosk"},
	{"t": "sell", "item": "itm_bandage", "qty": 1},
	{"t": "equip", "member": "kai", "slot": "weapon", "item": ""},
	{"t": "use_item", "item": "itm_bandage", "member": "kai"},
	{"t": "rest"},
	{"t": "event", "id": "fev_wheel", "choice": "spin"},
	{"t": "chest", "id": "f1_c0"},
	{"t": "gate", "key": "3,5,S"},
	{"t": "room", "cell": [3, -1]},
	{"t": "safe_room", "id": "sr_kiosk"},
	{"t": "safe_room_exit"},
	{"t": "scene", "id": "scn_mop_1"},
	{"t": "flag", "key": "intro_seen", "value": true},
	{"t": "flag", "key": "count", "value": 3},
	{"t": "flag", "key": "name", "value": "Kai"},
	{"t": "difficulty", "to": "vorabend"},
	{"t": "sponsor_window", "op": "dev_open", "sec": 60, "slots": 3},
	{"t": "descend"},
	{"t": "hero", "id": "mopsula"},
	{"t": "hero", "id": "kai"},
]


func test_types_are_the_recorded_list() -> void:
	assert_eq(Command.TYPES, ["floor", "encounter", "battle", "lootbox", "buy", "sell", "equip", "use_item", "rest",
		"event", "chest", "gate", "room", "safe_room", "safe_room_exit", "scene", "flag", "difficulty", "descend",
		"gift", "sponsor_window", "hero"], "02_TECH §3.4 (+ hero, 06 §1.7)")
	var covered: Dictionary = {"gift": true}
	for c: Dictionary in VALID:
		covered[c["t"]] = true
	for t: String in Command.TYPES:
		assert_true(covered.has(t), "test sample for " + t)


func test_valid_commands() -> void:
	for c: Dictionary in VALID:
		assert_eq(Command.validate(c), "", str(c))
	assert_eq(Command.validate({"t": "gift", "gift": Gift.make_dev("chest", "silver", 0)}), "")
	assert_eq(Command.validate({"t": "rest", "note": "extra fields are allowed"}), "", "additive protocol")


func test_valid_after_json_round_trip() -> void:
	for c: Dictionary in VALID:
		var parsed: Variant = JSON.parse_string(JSON.stringify(c))
		assert_eq(Command.validate(parsed), "", "ints became floats: " + str(c))


func test_every_battle_command_kind() -> void:
	var cmds: Array[BattleCommand] = [BattleCommand.attack("p0", "e0"),
		BattleCommand.skill("p1", "skl_x", PackedStringArray(["e0", "e1"])),
		BattleCommand.stunt("p0", "skl_stunt", PackedStringArray()),
		BattleCommand.item("p0", "itm_bandage", PackedStringArray(["p1"])),
		BattleCommand.defend("p1"), BattleCommand.flee("p0")]
	for bc: BattleCommand in cmds:
		assert_eq(Command.validate({"t": "battle", "cmd": bc.to_dict(), "auto": true}), "", bc.kind_name())


func test_invalid_commands() -> void:
	var cases: Array = [
		[{}, "missing command type"],
		[{"t": 3}, "missing command type"],
		[{"t": "teleport"}, "unknown command type 'teleport'"],
		[{"t": "floor"}, "floor: floor"],
		[{"t": "floor", "floor": 0}, "floor: floor"],
		[{"t": "floor", "floor": 1.5}, "floor: floor"],
		[{"t": "encounter", "enc": "", "adv": 0, "group": ""}, "encounter: enc"],
		[{"t": "encounter", "enc": "enc_x", "adv": 3, "group": ""}, "encounter: adv"],
		[{"t": "encounter", "enc": "enc_x", "adv": 0}, "encounter: group"],
		[{"t": "battle", "cmd": {"kind": "attack", "actor": "p0", "targets": []}}, "battle: auto"],
		[{"t": "battle", "cmd": {"kind": "dance", "actor": "p0"}, "auto": true}, "battle: cmd.kind"],
		[{"t": "battle", "cmd": {"kind": "attack", "actor": ""}, "auto": true}, "battle: cmd.actor"],
		[{"t": "battle", "cmd": {"kind": "attack", "actor": "p0", "targets": [1]}, "auto": true}, "battle: cmd.targets"],
		[{"t": "battle", "cmd": "attack", "auto": true}, "battle: cmd must be"],
		[{"t": "lootbox"}, "lootbox: box"],
		[{"t": "buy", "item": "itm_bandage", "qty": 0, "safe_room": ""}, "buy: qty"],
		[{"t": "buy", "item": "itm_bandage", "qty": 1}, "buy: safe_room"],
		[{"t": "sell", "item": "", "qty": 1}, "sell: item"],
		[{"t": "equip", "member": "kai", "slot": "hat", "item": ""}, "equip: slot"],
		[{"t": "use_item", "item": "itm_bandage"}, "use_item: member"],
		[{"t": "event", "id": "fev_wheel"}, "event: choice"],
		[{"t": "chest", "id": 5}, "chest: id"],
		[{"t": "gate", "key": "3;5;S"}, "gate: key"],
		[{"t": "room", "cell": [1]}, "room: cell"],
		[{"t": "room", "cell": [1, 0.5]}, "room: cell"],
		[{"t": "flag", "key": "x"}, "flag: missing 'value'"],
		[{"t": "flag", "key": "x", "value": 0.5}, "flag: value"],
		[{"t": "flag", "key": "x", "value": [1]}, "flag: value"],
		[{"t": "difficulty", "to": "hard"}, "difficulty: to"],
		[{"t": "gift"}, "gift: gift must be"],
		[{"t": "gift", "gift": {"schema": 1}}, "gift: invalid_schema"],
		[{"t": "sponsor_window", "op": "close", "sec": 60, "slots": 3}, "sponsor_window: op"],
		[{"t": "sponsor_window", "op": "dev_open", "sec": 0, "slots": 3}, "sponsor_window: sec"],
		[{"t": "sponsor_window", "op": "dev_open", "sec": 601, "slots": 3}, "sponsor_window: sec must be <= 600"],
		[{"t": "sponsor_window", "op": "dev_open", "sec": 60, "slots": 17}, "slots <= 16"],
		[{"t": "hero"}, "hero: id"],
		[{"t": "hero", "id": "rattenkoenigin"}, "hero: id must be one of kai, mopsula"],
	]
	for c: Array in cases:
		var err: String = Command.validate(c[0])
		assert_ne(err, "", "rejected: " + str(c[0]))
		assert_has(err, str(c[1]), str(c[0]))


func test_external_commands() -> void:
	assert_true(Command.is_external({"t": "gift"}))
	assert_false(Command.is_external({"t": "rest"}))


func test_explore_event_round_trip() -> void:
	for t: int in ExploreEvent.TYPE_NAMES.size():
		var ev: ExploreEvent = ExploreEvent.make(t as ExploreEvent.Type, 300 + t, {"seconds": 299, "cell": [2, 5],
			"group_id": "f1_s0"})
		var d: Dictionary = ev.to_dict()
		var back: ExploreEvent = ExploreEvent.from_dict(d)
		assert_not_null(back, ExploreEvent.type_name(t as ExploreEvent.Type))
		assert_eq(back.to_dict(), d, "to_dict/from_dict round trip")
		var parsed: Variant = JSON.parse_string(JSON.stringify(d))
		var from_json: ExploreEvent = ExploreEvent.from_dict(parsed)
		assert_eq(int(from_json.type), t, "JSON round trip keeps the type")
		assert_eq(from_json.tick, 300 + t)
	assert_null(ExploreEvent.from_dict({"type": "warp"}), "unknown type → null")
	assert_null(ExploreEvent.from_dict({"tick": 3}), "missing type → null")


## Integration with M0's Game: every command the live game records has a valid schema (no drift between
## Game.record shapes and Command).
func test_commands_recorded_by_game_are_valid() -> void:
	Game.new_game(0, "Kai", 31337)
	if not Game.has_state():
		fail("Game.new_game must create a state")
		return
	var sr_id: String = str((DB.floor_def(1).layout.get("safe_rooms", [{}]) as Array)[0].get("id", "sr_kiosk"))
	Game.enter_safe_room(sr_id)
	Game.buy("itm_bandage", 1, sr_id)
	Game.sell("itm_bandage", 1)
	Game.rest_full_heal()
	Game.leave_safe_room()
	Game.set_flag("intro_seen", true)
	Game.visit_room(Vector2i(3, 6))
	Game.equip("kai", "accessory", "")
	Game.set_difficulty(&"vorabend")
	var setup: BattleSetup = Game.make_battle_setup(DB.floor_def(1).timer_start_after, 0, "")
	var battle: BattleState = BattleState.new(setup, DB.data)
	battle.start()
	var cmd: BattleCommand = battle.choose_ai_command()
	Game.record({"t": "battle", "cmd": cmd.to_dict(), "auto": true})
	Game.in_battle = false
	assert_true(Game.open_dev_sponsor_window(), "QA Sponsor-Fenster (recorded)")
	assert_eq(Show.receive_gift(Gift.make_dev("gold", "", 100))["apply"], "now", "dev gift recorded on application")
	var errs: PackedStringArray = Game.run_log.validate()
	assert_eq(errs, PackedStringArray(), "Game.record shapes == Command schema")
	assert_gt(Game.run_log.size(), 10)
	Game.state = null
	Game.run_log = null
	Game.sim = null
	Game.in_battle = false
