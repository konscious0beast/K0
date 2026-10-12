extends TestCase
## Command.validate per "t" (02_TECH §3.4, 05 §11.4): required fields, types, ranges, unknown type → error; ExploreEvent
## to_dict/from_dict round trip; every command the live Game records passes the schema (integration with M0's Game).
## R5b part 2b: an encounter carries its real-time block; the CTB "battle" command is gone (an unknown type now).

const RtLive := preload("res://tests/fixtures/rt_live/rt_live.gd")
## The rt block of a real-time encounter (07 §10.1) for the samples below.
const RT: Dictionary = {"v": 1, "cell": [3, 2], "ctl": "p0", "party": [{"u": "p0", "p": [0, 300, 0]}],
	"groups": [{"group": "f1_g3", "enc": "enc_f1_a2", "lead": [0, -300, 128], "state": "PATROL"}], "presets": {},
	"auto": true, "retarget": true, "open": {}, "diff": "prime"}

const VALID: Array[Dictionary] = [
	{"t": "floor", "floor": 1},
	{"t": "encounter", "enc": "enc_f1_a2", "adv": 2, "group": "f1_g3", "rt": RT},
	{"t": "encounter", "enc": "enc_f1_evt_pigeons", "adv": 0, "group": "", "rt": RT},
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
	{"t": "flag", "key": "intro_seen", "value": 3},
	{"t": "flag", "key": "intro_seen", "value": "Kai"},
	{"t": "difficulty", "to": "vorabend"},
	{"t": "sponsor_window", "op": "dev_open", "sec": 60, "slots": 3},
	{"t": "descend"},
	{"t": "hero", "id": "mopsula"},
	{"t": "hero", "id": "kai"},
	{"t": "secret", "id": "sec_e1_wall_sewer"},
	{"t": "talent", "member": "kai", "id": "tal_kai_wischtechnik"},                     # 06 package B
	{"t": "casting", "member": "mopsula", "species": "spc_original", "class": "cls_mop_zeremonienmeister"},
	{"t": "twist", "twist": {"schema": 1, "id": "tw_overtime", "n": 1, "src": "regie", "params": {"seconds": 60},
		"duration": 0, "tick": 120}},
	# Echtzeitkampf (07 §10.1, R1a): schema in RtCommand.validate
	{"t": "encounter", "enc": "enc_f1_a2", "adv": 0, "group": "f1_g3", "rt": {"v": 1, "cell": [3, 2], "ctl": "p0",
		"party": [{"u": "p0", "p": [0, 300, 0]}, {"u": "p1", "p": [-150, 400, 0]}],
		"groups": [{"group": "f1_g3", "enc": "enc_f1_a2", "lead": [0, -300, 128], "state": "PATROL"}],
		"presets": {"p1": {"preset": "support", "tog": {"interrupt": true, "show": true, "potions": false}}},
		"auto": true, "retarget": true, "open": {}, "diff": "prime"}},
	{"t": "ability_use", "ct": 12, "u": "p0", "skill": "skl_kai_heavy_swing", "target": "e0"},
	{"t": "target_change", "ct": 13, "u": "p0", "target": ""},
	{"t": "move_sample", "ct": 14, "u": "p0", "p": [120, -45, 18, -3, 64]},
	{"t": "combat_item", "ct": 15, "u": "p0", "item": "itm_bandage", "target": "p1"},
	{"t": "partner_preset", "ct": 16, "u": "p1", "preset": "careful", "tog": {"potions": true}},
	{"t": "partner_special", "ct": 17, "u": "p1"},
	{"t": "auto_attack", "ct": 18, "u": "p0", "on": false},
	{"t": "autopilot", "ct": 19, "u": "p0", "on": true},
	{"t": "combat_hint", "ct": 20, "id": "interrupt"},
	{"t": "move_input", "ct": 21, "u": "p0", "dir": [0, -127], "run": true},
	{"t": "combat_speed", "pm": 850},
	{"t": "move_batch", "u": "p0", "id0": 7, "s": [[0, 120, -45, 18, -3, 64], [4, 140, -50, 18, -3, 64]]},
	# Echtzeitkampf (07 §4.1, §5.2; R5a): variants + partner tactic chosen outside a combat
	{"t": "loadout", "member": "kai", "bar": {"4": "skl_kai_deo_torch"}, "preset": "careful", "tog": {"potions": true}},
	{"t": "loadout", "member": "mopsula", "bar": {}, "preset": "", "tog": {}},
	# Casting (08 §2.3, K0): start (bias 0–3 ids); the talent is any String (PersonaRules.check takes only "")
	{"t": "persona", "v": 1, "talent": "tal_org_animals", "bias": ["mar_graf_finale", "mar_variety"]},
	{"t": "persona", "v": 1, "talent": "tal_org_nature", "bias": []},
	{"t": "persona", "v": 1, "talent": "", "bias": ["mar_bio"]},      # K1 (CR-33): the command K1 records
	# Staffeln (09 §9.1, ST0): persona v2 (the casting's command), talent v2 and the season commands; sd (10 §6.8)
	{"t": "persona", "v": 2, "prof": "prf_first_aid", "recipe": "rcp_cooking_hobby", "bias": ["mar_bio"]},
	{"t": "persona", "v": 2, "prof": "", "recipe": "", "bias": []},
	{"t": "talent", "v": 2, "member": "kai", "row": 3, "id": "tal_kai_dicke_haut"},
	{"t": "season", "v": 1, "op": "start", "def": "ssn_basis", "format": 6, "tempo": "calendar", "mode": "net",
		"number": 1, "day0_utc": 1791921600, "collapse_utc": [1792094400, 1792353600, 1792699200, 1793131200,
		1793563200, 1793995200], "cast": {}},
	{"t": "season", "v": 1, "op": "pause", "sec": 86400, "why": "user"},
	{"t": "season", "v": 1, "op": "tempo"},
	{"t": "season", "v": 1, "op": "leave"},
	{"t": "clock", "sec": 60},
	{"t": "away", "sec": 7200},
	{"t": "sleep", "tactic": "careful"},
	{"t": "prof", "op": "learn", "id": "prf_scrap"},
	{"t": "gather", "node": "nod_scrap_heap"},
	{"t": "craft", "recipe": "rcp_cooking_hobby", "n": 2},
	{"t": "cast", "op": "hire", "who": 17},
	{"t": "cast", "op": "trade", "who": 4, "item": "itm_bandage"},
	{"t": "sd", "v": 1, "op": "start", "opp": "sdo_ulla", "deck": ["sdc_stempel"], "rh": "abc"},
	{"t": "sd", "v": 1, "op": "end", "moves": [{"op": "play", "slot": 2}], "res": "won"},
]


func test_types_are_the_recorded_list() -> void:
	assert_eq(Command.TYPES, ["floor", "encounter", "lootbox", "buy", "sell", "equip", "use_item", "rest",
		"event", "chest", "gate", "room", "safe_room", "safe_room_exit", "scene", "flag", "difficulty", "descend",
		"gift", "sponsor_window", "hero", "talent", "casting", "secret", "twist",
		"ability_use", "target_change", "move_sample", "combat_item", "partner_preset", "partner_special",
		"auto_attack", "autopilot", "combat_hint", "move_input", "combat_speed", "move_batch", "loadout", "persona",
		"season", "clock", "away", "sleep", "prof", "gather", "craft", "cast", "sd"],
		"02_TECH §3.4 (+ hero / secret 06 §1.7 / §2.7, talent / casting 06 §2.2 / §3.4, twist 06 §5.7, real-time "
		+ "combat 07 §10.1, loadout 07 §4.1 (R5a), persona 08 §2.3; R5b part 2b: no CTB battle command; the "
		+ "season commands 09 §9.1 and the sd stub 10 §6.8 since ST0)")
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


## The CTB battle command left with the CTB campaign (R5b part 2b): an unknown type, an encounter without its real-time
## block is refused.
func test_no_ctb_battle_command() -> void:
	var bc: BattleCommand = BattleCommand.attack("p0", "e0")
	assert_eq(Command.validate({"t": "battle", "cmd": bc.to_dict(), "auto": true}), "unknown command type 'battle'")
	assert_has(Command.validate({"t": "encounter", "enc": "enc_f1_a2", "adv": 0, "group": ""}),
		"rt: the real-time block is required")


func test_invalid_commands() -> void:
	var cases: Array = [
		[{}, "missing command type"],
		[{"t": 3}, "missing command type"],
		[{"t": "teleport"}, "unknown command type 'teleport'"],
		[{"t": "floor"}, "floor: floor"],
		[{"t": "floor", "floor": 0}, "floor: floor"],
		[{"t": "floor", "floor": 1.5}, "floor: floor"],
		[{"t": "encounter", "enc": "", "adv": 0, "group": "", "rt": RT}, "encounter: enc"],
		[{"t": "encounter", "enc": "enc_x", "adv": 3, "group": "", "rt": RT}, "encounter: adv"],
		[{"t": "encounter", "enc": "enc_x", "adv": 0, "rt": RT}, "encounter: group"],
		[{"t": "encounter", "enc": "enc_x", "adv": 0, "group": ""}, "encounter: rt"],
		[{"t": "battle", "cmd": {"kind": "attack", "actor": "p0", "targets": []}, "auto": true}, "unknown command type"],
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
		[{"t": "flag", "key": "intro_seen"}, "flag: missing 'value'"],
		[{"t": "flag", "key": "intro_seen", "value": 0.5}, "flag: value"],
		[{"t": "flag", "key": "intro_seen", "value": [1]}, "flag: value"],
		[{"t": "flag", "key": "live", "value": 0}, "flag: key 'live' is not a player flag"],
		[{"t": "flag", "key": "mop_pep_talk", "value": true}, "flag: key 'mop_pep_talk'"],
		[{"t": "difficulty", "to": "hard"}, "difficulty: to"],
		[{"t": "gift"}, "gift: gift must be"],
		[{"t": "gift", "gift": {"schema": 1}}, "gift: invalid_schema"],
		[{"t": "sponsor_window", "op": "close", "sec": 60, "slots": 3}, "sponsor_window: op"],
		[{"t": "sponsor_window", "op": "dev_open", "sec": 0, "slots": 3}, "sponsor_window: sec"],
		[{"t": "sponsor_window", "op": "dev_open", "sec": 601, "slots": 3}, "sponsor_window: sec must be <= 600"],
		[{"t": "sponsor_window", "op": "dev_open", "sec": 60, "slots": 17}, "slots <= 16"],
		[{"t": "hero"}, "hero: id"],
		[{"t": "hero", "id": "rattenkoenigin"}, "hero: id must be one of kai, mopsula"],
		[{"t": "secret"}, "secret: id"],
		[{"t": "secret", "id": ""}, "secret: id must be a non-empty String"],
		[{"t": "secret", "id": "f1_c3"}, "secret: id must start with sec_"],
		[{"t": "talent", "member": "kai"}, "talent: id"],
		[{"t": "talent", "member": "", "id": "tal_kai_wischtechnik"}, "talent: member"],
		[{"t": "casting", "member": "kai", "species": "spc_original"}, "casting: class"],
		[{"t": "casting", "member": "kai", "species": 3, "class": "cls_kai_wrecker"}, "casting: species"],
		[{"t": "twist"}, "twist: twist must be"],
		[{"t": "twist", "twist": {"schema": 2}}, "twist: twist.schema"],
		[{"t": "twist", "twist": {"schema": 1, "id": "", "n": 1, "src": "dev", "params": {}, "duration": 0, "tick": 0}},
			"twist: twist.id"],
		[{"t": "twist", "twist": {"schema": 1, "id": "tw_x", "n": 0, "src": "dev", "params": {}, "duration": 0,
			"tick": 0}}, "twist: twist.n"],
		[{"t": "twist", "twist": {"schema": 1, "id": "tw_x", "n": 1, "src": "hacker", "params": {}, "duration": 0,
			"tick": 0}}, "twist: twist.src"],
		[{"t": "twist", "twist": {"schema": 1, "id": "tw_x", "n": 1, "src": "dev", "params": {"seconds": 1.5},
			"duration": 0, "tick": 0}}, "twist: twist.params.seconds"],
		[{"t": "twist", "twist": {"schema": 1, "id": "tw_x", "n": 1, "src": "dev", "params": {}, "duration": 0,
			"tick": -1}}, "twist: twist.tick"],
		# Casting (08 §2.3, K0)
		[{"t": "persona", "talent": "tal_org_animals", "bias": []}, "persona: v must be 1 or 2"],
		[{"t": "persona", "v": 3, "prof": "", "recipe": "", "bias": []}, "persona: v must be 1 or 2"],
		[{"t": "persona", "v": 2, "talent": "tal_org_animals", "bias": []}, "persona: prof must be a String"],
		[{"t": "persona", "v": 2, "prof": "", "bias": []}, "persona: recipe must be a String"],
		[{"t": "persona", "v": 2, "prof": "org_care", "recipe": "", "bias": []}, "prof must be \"\" or start with prf_"],
		[{"t": "persona", "v": 2, "prof": "", "recipe": "hob_cooking", "bias": []}, "recipe must be \"\" or start"],
		[{"t": "persona", "v": 2, "prof": "", "recipe": ""}, "persona: bias must be an array"],
		[{"t": "persona", "v": 1, "bias": []}, "persona: talent must be a String"],   # 08 K1: "" is allowed
		[{"t": "persona", "v": 1, "talent": "tal_org_animals"}, "persona: bias must be an array"],
		[{"t": "persona", "v": 1, "talent": "tal_org_animals", "bias": ["a", "b", "c", "d"]}, "at most 3"],
		[{"t": "persona", "v": 1, "talent": "tal_org_animals", "bias": [3]}, "bias must contain non-empty Strings"],
		[{"t": "persona", "v": 1, "talent": "", "swap": true}, "persona: bias must be an array"],   # 09 ST0: no swap
		# Echtzeitkampf (07 §4.1, §5.2; R5a)
		[{"t": "loadout", "bar": {}, "preset": "", "tog": {}}, "loadout: member"],
		[{"t": "loadout", "member": "kai", "preset": "", "tog": {}}, "loadout: bar must be a Dictionary"],
		[{"t": "loadout", "member": "kai", "bar": {"5": "skl_x"}, "preset": "", "tog": {}}, "bar keys must be"],
		[{"t": "loadout", "member": "kai", "bar": {"2": ""}, "preset": "", "tog": {}}, "bar.2 must be"],
		[{"t": "loadout", "member": "kai", "bar": {}, "preset": "berserk", "tog": {}}, "loadout: preset must be"],
		[{"t": "loadout", "member": "kai", "bar": {}, "preset": "", "tog": {"heal": true}}, "tog.heal is not a switch"],
		[{"t": "loadout", "member": "kai", "bar": {}, "preset": "", "tog": {"show": 1}}, "tog.show must be a bool"],
		# Staffeln (09 §9.1, ST0)
		[{"t": "talent", "v": 1, "member": "kai", "row": 3, "id": "tal_x"}, "talent: v must be 2"],
		[{"t": "talent", "v": 2, "member": "kai", "row": 0, "id": "tal_x"}, "talent: row must be an integer >= 1"],
		[{"t": "season", "op": "leave"}, "season: v must be 1"],
		[{"t": "season", "v": 1, "op": "reboot"}, "season: op must be one of"],
		[{"t": "season", "v": 1, "op": "start", "def": "basis", "format": 6, "tempo": "calendar", "mode": "net",
			"number": 1, "day0_utc": 0, "collapse_utc": [1, 2, 3, 4, 5, 6], "cast": {}}, "def must start with ssn_"],
		[{"t": "season", "v": 1, "op": "start", "def": "ssn_basis", "format": 7, "tempo": "calendar", "mode": "net",
			"number": 1, "day0_utc": 0, "collapse_utc": [1, 2, 3, 4, 5, 6, 7], "cast": {}}, "format must be 6, 12"],
		[{"t": "season", "v": 1, "op": "start", "def": "ssn_basis", "format": 6, "tempo": "turbo", "mode": "net",
			"number": 1, "day0_utc": 0, "collapse_utc": [1, 2, 3, 4, 5, 6], "cast": {}}, "tempo must be one of"],
		[{"t": "season", "v": 1, "op": "start", "def": "ssn_basis", "format": 6, "tempo": "binge", "mode": "x",
			"number": 1, "day0_utc": 0, "collapse_utc": [1, 2, 3, 4, 5, 6], "cast": {}}, "mode must be one of"],
		[{"t": "season", "v": 1, "op": "start", "def": "ssn_basis", "format": 6, "tempo": "binge", "mode": "net",
			"number": 1, "day0_utc": 0, "collapse_utc": [1, 2, 3], "cast": {}}, "one time per floor"],
		[{"t": "season", "v": 1, "op": "start", "def": "ssn_basis", "format": 6, "tempo": "binge", "mode": "net",
			"number": 1, "day0_utc": 9, "collapse_utc": [1, 2, 3, 4, 5, 6], "cast": {}}, "ascending integers after"],
		[{"t": "season", "v": 1, "op": "start", "def": "ssn_basis", "format": 6, "tempo": "binge", "mode": "net",
			"number": 1, "day0_utc": 0, "collapse_utc": [1, 2, 3, 4, 5, 6]}, "cast must be a Dictionary"],
		[{"t": "season", "v": 1, "op": "pause", "sec": 60, "why": "bored"}, "why must be one of"],
		[{"t": "clock", "sec": 0}, "clock: sec must be an integer >= 1"],
		[{"t": "away", "sec": 1.5}, "away: sec must be an integer >= 1"],
		[{"t": "sleep", "tactic": "berserk"}, "sleep: tactic must be one of"],
		[{"t": "prof", "op": "forget", "id": "prf_scrap"}, "prof: op must be one of"],
		[{"t": "prof", "op": "learn", "id": "job_scrap"}, "id must start with prf_"],
		[{"t": "gather", "node": ""}, "gather: node must be a non-empty String"],
		[{"t": "craft", "recipe": "rcp_x", "n": 0}, "craft: n must be an integer >= 1"],
		[{"t": "cast", "op": "fight", "who": 1}, "cast: op must be one of"],
		[{"t": "cast", "op": "help", "who": -1}, "cast: who must be an integer >= 0"],
		[{"t": "cast", "op": "trade", "who": 1, "item": 3}, "cast: item must be a String"],
		[{"t": "sd", "op": "start"}, "sd: v must be 1"],
		[{"t": "sd", "v": 1, "op": "start", "opp": "sdo_ulla", "deck": [""], "rh": ""}, "deck must contain"],
		[{"t": "sd", "v": 1, "op": "end", "moves": [], "res": ""}, "sd: res must be a non-empty String"],
	]
	for c: Array in cases:
		var err: String = Command.validate(c[0])
		assert_ne(err, "", "rejected: " + str(c[0]))
		assert_has(err, str(c[1]), str(c[0]))


func test_external_commands() -> void:
	assert_true(Command.is_external({"t": "gift"}))
	assert_false(Command.is_external({"t": "rest"}))
	for t: String in ["clock", "away"]:
		assert_true(Command.is_external({"t": t}), "09 §9.1: the clock is set from outside (cmd id 0): " + t)
	for t: String in ["season", "sleep", "prof", "gather", "craft", "cast", "sd"]:
		assert_false(Command.is_external({"t": t}), t + " is the player's")


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
	assert_false(RtLive.autopilot_fight(DB.floor_def(1).timer_start_after, BattleSetup.Advantage.NORMAL, "").is_empty(),
		"a real-time combat: encounter + combat entries recorded")
	assert_true(Game.open_dev_sponsor_window(), "QA Sponsor-Fenster (recorded)")
	assert_eq(Show.receive_gift(Gift.make_dev("gold", "", 100))["apply"], "now", "dev gift recorded on application")
	var errs: PackedStringArray = Game.run_log.validate()
	assert_eq(errs, PackedStringArray(), "Game.record shapes == Command schema")
	assert_gt(Game.run_log.size(), 10)
	Game.state = null
	Game.run_log = null
	Game.sim = null
	Game.in_battle = false


## quality-12: a new command type needs a case in BOTH dispatchers — RunSim.apply (core verifier) and the Game replay
## engine (GameReplay._cmd / _apply) — the recording side is Command.TYPES. Source scan of the match cases.
func test_every_command_type_has_both_dispatchers() -> void:
	var sim_body: String = _func_body("res://core/live/run_sim.gd", "func apply(")
	var replay_body: String = _func_body("res://autoload/game_replay.gd", "func _cmd(") \
		+ _func_body("res://autoload/game_replay.gd", "func _apply(")
	assert_gt(sim_body.length(), 100)
	assert_gt(replay_body.length(), 100)
	for t: String in Command.TYPES:
		assert_true(sim_body.contains("\"%s\":" % t), "RunSim.apply handles '%s'" % t)
		assert_true(replay_body.contains("\"%s\":" % t), "GameReplay handles '%s'" % t)


## Source of one function: from `header` up to the next top-level func.
func _func_body(path: String, header: String) -> String:
	var src: String = FileAccess.get_file_as_string(path)
	var start: int = src.find(header)
	if start < 0:
		return ""
	var end: int = src.find("\nfunc ", start + header.length())
	var end_static: int = src.find("\nstatic func ", start + header.length())
	if end < 0 or (end_static >= 0 and end_static < end):
		end = end_static
	return src.substr(start, (end - start) if end >= 0 else -1)
