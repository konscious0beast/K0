extends TestCase
## GameData / DataValidator / DB: loading, normalization, getters and ≥ 1 negative test per validation rule 1–10
## (02_TECH §4.5, §11.5). Never calls getters with unknown ids (they push_error, which fails check.sh by design).

const FIXTURE_DIR: String = "res://tests/fixtures/data_min"


func _fixture() -> GameData:
	var d: GameData = GameData.new()
	d.load_dir(FIXTURE_DIR)
	return d


## Fresh deep copy of the fixture files (file-shaped tables).
func _raw() -> Dictionary:
	var raw: Dictionary = {}
	for t: String in GameData.TABLES:
		raw[t] = JsonUtil.read_file(FIXTURE_DIR.path_join(t + ".json"))
	return raw


func _entries(raw: Dictionary, table: String) -> Array:
	return (raw[table] as Dictionary)["entries"]


func _entry(raw: Dictionary, table: String, id: String) -> Dictionary:
	for e: Dictionary in _entries(raw, table):
		if str(e.get("id", "")) == id:
			return e
	fail("fixture has no %s '%s'" % [table, id])
	return {}


func _layout(raw: Dictionary) -> Dictionary:
	return _entry(raw, "floors", "floor_1")["layout"]


func _errors(raw: Dictionary) -> PackedStringArray:
	var d: GameData = GameData.new()
	d.load_from_tables(raw)
	return d.errors


func _expect_error(raw: Dictionary, needle: String, what: String) -> void:
	var errs: PackedStringArray = _errors(raw)
	for e: String in errs:
		if e.contains(needle):
			return
	fail("%s: expected an error containing '%s', got [%s]" % [what, needle, "; ".join(errs)])


# --- positive ---------------------------------------------------------------------------------------------------------

func test_fixture_loads_without_errors() -> void:
	var d: GameData = GameData.new()
	var ok: bool = d.load_dir(FIXTURE_DIR)
	assert_true(ok, "errors: " + "; ".join(d.errors))
	assert_true(d.is_valid())
	assert_len(d.warnings, 0, "warnings: " + "; ".join(d.warnings))
	assert_eq(d.source, FIXTURE_DIR)


func test_real_data_valid_and_db_autoload() -> void:
	assert_true(DB.ok, "DB.ok (res://data): " + "; ".join(DB.data.errors))
	assert_true(DB.data.is_valid())
	assert_not_null(DB.party_member("kai"))
	assert_not_null(DB.party_member("mopsula"))
	assert_not_null(DB.floor_def(1))
	assert_true(DB.has_id("party", "kai"))
	assert_false(DB.has_id("party", "nobody"))
	assert_gt(DB.mod_lines("intro").size(), 0)
	var real: GameData = real_data()
	assert_true(real.is_valid())


func test_events_json_is_separate_and_parses() -> void:
	assert_false(GameData.TABLES.has("events"), "events.json is not a GameData table")
	var parsed: Variant = JsonUtil.read_file("res://data/events.json")
	assert_true(parsed is Dictionary, "events.json parses")
	if parsed is Dictionary:
		assert_eq((parsed as Dictionary).get("schema", 0), 1)
		assert_true((parsed as Dictionary).get("events", null) is Array)


func test_getters_and_sorting() -> void:
	var d: GameData = _fixture()
	assert_len(d.all_statuses(), 6)
	var party: Array[PartyMemberDef] = d.all_party()
	assert_eq(party.size(), 2)
	assert_eq(party[0].id, "kai", "sorted by battle_slot")
	assert_eq(party[1].id, "mopsula")
	assert_eq(d.party_member("mopsula").title, "Graf")
	assert_eq(d.party_member("kai").base_stats["hp"], 64)
	assert_eq(typeof(d.party_member("kai").base_stats["hp"]), TYPE_INT, "int fields converted")
	assert_not_null(d.floor_def(1))
	assert_null(d.floor_def(2), "no floor 2 → null without error")
	assert_eq(d.floor_by_id("floor_1").index, 1)
	var enc: EncounterDef = d.encounter("enc_f1_a1_tutorial")
	assert_true(enc.tutorial)
	assert_eq(enc.enemies, ["enm_kanalratte", "enm_kanalratte"])
	assert_eq(enc.floor_index, 1)
	assert_eq(d.ids("statuses"), ["sts_guard", "sts_haste", "sts_poison", "sts_slow", "sts_stun", "sts_taunt"])
	assert_true(d.has_id("encounters", "enc_f1_a2"))
	assert_false(d.has_id("encounters", "enc_nope"))
	assert_false(d.has_id("no_such_table", "x"))
	assert_len(d.mod_lines("nope"), 0)
	assert_eq(d.mod_lines("intro")[0].tag, "intro")
	assert_eq(d.party_start(), {"inventory": {"itm_bandage": 3, "itm_antidote": 1}, "credits": 50})
	assert_eq(d.pity_limits(), {"rare": 4, "epic": 8})
	assert_len(d.all_achievements_for("enemy_killed"), 1)
	assert_len(d.all_achievements_for("combo"), 0)
	assert_eq(d.all_milestones()[0].id, "ms_100")
	assert_eq(d.all_scenes()[0].id, "scn_mop_1")
	assert_len(d.all_skills(), 10)
	assert_len(d.all_items(), 3)
	assert_len(d.all_classes(), 1)
	assert_len(d.all_enemies(), 1)
	assert_len(d.all_floors(), 1)
	assert_len(d.all_lootboxes(), 4)
	assert_len(d.all_sponsors(), 1)
	assert_len(d.all_pseudo_units(), 0)


func test_loot_pool_fallback() -> void:
	var d: GameData = _fixture()
	assert_len(d.loot_pool(1, "common"), 2)
	assert_len(d.loot_pool(5, "rare"), 2, "highest pool <= floor")
	assert_len(d.loot_pool(1, "fan"), 1)
	assert_len(d.loot_pool(0, "common"), 0, "no pool <= 0")
	var pool: Array[Dictionary] = d.loot_pool(1, "common")
	pool.clear()
	assert_len(d.loot_pool(1, "common"), 2, "returned pools are copies")


func test_normalization_defaults() -> void:
	var d: GameData = _fixture()
	var stun: StatusDef = d.status("sts_stun")
	assert_eq(stun.tick_timing, "turn_end")
	assert_eq(stun.element, "none")
	assert_true(stun.has_flag("delay_on_apply"))
	assert_eq(d.status("sts_slow").excludes, ["sts_haste"])
	assert_eq(d.skill("skl_item_bandage").rank, 2, "item rank default")
	assert_eq(d.skill("skl_stunt_kai_suplex").cooldown, 3)
	assert_eq(d.skill("skl_stunt_kai_suplex").fail_effect,
		{"self_dmg_pct": 10, "delay_pct": 50, "status": "", "status_turns": 0})
	assert_eq(d.skill("skl_attack_kai").accuracy, -1)
	assert_eq(d.skill("skl_item_antidote").cleanse, ["sts_poison"])
	assert_eq(d.item("itm_bandage").sell, -1)
	assert_eq(d.item("itm_bandage").sell_value(), 12)
	assert_eq(d.item("itm_bandage").show_mods, {"hype_gain_mult": 1.0, "follower_mult": 1.0})
	assert_eq(d.item("itm_key_master").max_stack, 1)
	var rat: EnemyDef = d.enemy("enm_kanalratte")
	assert_eq(rat.explore["patrol_speed"], 1.8)
	assert_eq(rat.explore["field_speed"], 4.8)
	assert_eq(rat.ai["actions"][0]["cond"], {})
	assert_eq(rat.model["pose"], "auto")
	assert_false(rat.is_phased())
	var f1: FloorDef = d.floor_def(1)
	assert_true(f1.has_layout())
	assert_eq(f1.timer_warnings, [600, 300, 60])
	assert_eq(typeof(f1.timer_warnings), TYPE_PACKED_INT32_ARRAY)
	assert_eq(f1.palette["wall"], "#5b6270", "given palette keys win")
	assert_eq(f1.encounter("enc_f1_a2").can_flee, true, "can_flee defaults to !boss")
	assert_eq(f1.encounter("enc_f1_a2").weight, 0)
	var placed: Array = f1.layout["encounters_placed"]
	assert_eq(placed[0]["cell"], [3, 6])
	assert_eq(placed[0]["state"], "IDLE")
	assert_eq(f1.layout["chests"][0]["offset"], [3.5, 2.0])
	assert_eq(JsonUtil.arr_to_vec2i(f1.layout["stairs"]["cell"]), Vector2i(3, 5))
	assert_eq(d.lootbox("box_bronze").effective_mod_tag(), "lootbox_open_bronze")
	assert_eq(d.sponsor("spn_gluckwasser").gift[0]["target"], "party")
	assert_eq(d.sponsor("spn_gluckwasser").mod_tag, "sponsor_gift")
	assert_eq(d.milestone("ms_100").mod_tag, "follower_milestone")
	var ml: ModLineDef = d.mod_lines("achievement:ach_first_blood")[0]
	assert_eq(ml.tag_base, "achievement")
	assert_eq(ml.voice, "mod")
	assert_eq(d.class_def("cls_kai_wrecker").for_members, ["kai"])
	assert_eq(d.class_def("cls_kai_wrecker").show_mods["sponsor_thresholds"], [50, 75, 100])
	var ach: AchievementDef = d.achievement("ach_one_hp")
	assert_not_null(ach.expr)
	assert_true(ach.expr.eval({"min_party_hp": 1}, {}, {}))
	assert_eq(ach.followers, -1)
	var sc: SceneDef = d.scene_def("scn_mop_1")
	assert_true(sc.once)
	assert_true(sc.expr.eval({"safe_room_visits": 1}, {}, {}))


func test_load_from_dicts_partial_tables() -> void:
	var d: GameData = GameData.new()
	var ok: bool = d.load_from_dicts({
		"statuses": [{"id": "sts_poison", "name": "Gift", "kind": "debuff"}],
		"skills": [{"id": "skl_x", "name": "X", "category": "magic", "target": "single_enemy", "damage_type": "magical",
			"element": "fire", "statuses": [{"id": "sts_poison"}]}],
		"mod_lines": [{"id": "mod_crit_01", "tag": "crit", "text": "Krit {weird}!"}],
	})
	assert_true(ok, "rules 7–9 are skipped for fixtures: " + "; ".join(d.errors))
	assert_eq(d.source, "dicts")
	assert_eq(d.skill("skl_x").statuses, [{"id": "sts_poison", "chance": 1.0, "turns": 0}])
	assert_eq(d.party_start(), {"inventory": {}, "credits": 0})
	var bad: GameData = GameData.new()
	assert_false(bad.load_from_dicts({"skills": [{"id": "skl_x", "name": "X", "category": "magic",
		"target": "single_enemy", "statuses": [{"id": "sts_missing"}]}]}), "references are still checked")


func test_reload_clears_previous_state() -> void:
	var d: GameData = _fixture()
	assert_true(d.has_id("party", "kai"))
	d.load_from_dicts({})
	assert_false(d.has_id("party", "kai"))
	assert_true(d.is_valid())


# --- rule 1: file structure ------------------------------------------------------------------------------------------

func test_rule1_file_structure() -> void:
	var raw: Dictionary = _raw()
	raw.erase("skills")
	_expect_error(raw, "skills: file missing", "missing file")
	raw = _raw()
	(raw["statuses"] as Dictionary)["schema"] = 2
	_expect_error(raw, "statuses.schema", "schema != 1")
	raw = _raw()
	(raw["items"] as Dictionary)["extra"] = 1
	_expect_error(raw, "items.extra: unknown top-level key", "unknown top-level key")
	raw = _raw()
	(raw["party"] as Dictionary).erase("start")
	_expect_error(raw, "party.start", "party.start required")
	raw = _raw()
	(raw["lootboxes"] as Dictionary).erase("pity")
	_expect_error(raw, "lootboxes.pity", "pity required")
	raw = _raw()
	(raw["classes"] as Dictionary)["entries"] = {}
	_expect_error(raw, "classes.entries: must be an array", "entries not an array")
	raw = _raw()
	raw["scenes"] = [1, 2]
	_expect_error(raw, "scenes: file must contain a JSON object", "file not an object")
	var d: GameData = GameData.new()
	assert_false(d.load_dir("res://tests/fixtures/does_not_exist"))
	assert_has(d.errors[0], "file not found")


# --- rule 2: required fields, types, unknown keys -------------------------------------------------------------------

func test_rule2_types_required_unknown() -> void:
	var raw: Dictionary = _raw()
	_entry(raw, "skills", "skl_attack_kai").erase("category")
	_expect_error(raw, "skills[0|skl_attack_kai].category: missing required field", "missing required")
	raw = _raw()
	_entry(raw, "skills", "skl_kai_heavy_swing")["power"] = "160"
	_expect_error(raw, "skl_kai_heavy_swing].power: expected integer", "wrong type")
	raw = _raw()
	_entry(raw, "skills", "skl_kai_heavy_swing")["power"] = 160.5
	_expect_error(raw, "power: expected integer (got 160.5)", "int must be integral")
	raw = _raw()
	_entry(raw, "statuses", "sts_poison")["colour"] = "#ffffff"
	_expect_error(raw, "statuses[0|sts_poison].colour: unknown key", "unknown key")
	raw = _raw()
	(_layout(raw)["cells"] as Array)[0]["foo"] = 1
	_expect_error(raw, "layout.cells[0].foo: unknown key", "unknown nested key")
	raw = _raw()
	_entry(raw, "enemies", "enm_kanalratte")["explore"] = {"field_speed": 4.8, "sight": 3}
	_expect_error(raw, "explore.sight: unknown key", "unknown key in fixed nested schema")
	raw = _raw()
	_entry(raw, "items", "itm_bandage")["tags"] = "heal"
	_expect_error(raw, "itm_bandage].tags: expected array of strings", "array type")
	raw = _raw()
	_entry(raw, "skills", "skl_kai_heavy_swing")["power"] = 1e30
	_expect_error(raw, "skl_kai_heavy_swing].power: expected integer", "huge float is not an int (no int64 overflow)")
	assert_false(JsonUtil.is_integral(1e30))
	assert_false(JsonUtil.is_integral(-9.2e18))
	assert_true(JsonUtil.is_integral(8.0e15))
	assert_true(JsonUtil.is_integral(-12.0))


# --- rule 3: id regex + global uniqueness
# ------------------------------------------------------------------------------

func test_rule3_ids() -> void:
	var raw: Dictionary = _raw()
	_entry(raw, "statuses", "sts_poison")["id"] = "poison"
	_expect_error(raw, "invalid id 'poison'", "id regex")
	raw = _raw()
	(_entries(raw, "achievements") as Array).append((_entries(raw, "achievements")[0] as Dictionary).duplicate(true))
	_expect_error(raw, "duplicate id 'ach_first_blood'", "duplicate id")
	raw = _raw()
	var encs: Array = _entry(raw, "floors", "floor_1")["encounters"]
	encs[1]["id"] = "enc_f1_a1_tutorial"
	_expect_error(raw, "duplicate id 'enc_f1_a1_tutorial'", "duplicate encounter id")
	raw = _raw()
	(_layout(raw)["safe_rooms"] as Array)[0]["id"] = "kiosk"
	_expect_error(raw, "invalid id 'kiosk'", "safe room id regex")


# --- rule 4: enums, ranges, text length -------------------------------------------------------------------------------

func test_rule4_enums_ranges_texts() -> void:
	var raw: Dictionary = _raw()
	_entry(raw, "statuses", "sts_poison")["kind"] = "neutral"
	_expect_error(raw, "sts_poison].kind: 'neutral' not in", "enum")
	raw = _raw()
	_entry(raw, "skills", "skl_kai_heavy_swing")["power"] = 2000
	_expect_error(raw, "power: out of range 0..1000", "range")
	raw = _raw()
	(_entries(raw, "mod_lines")[0] as Dictionary)["text"] = "x".repeat(111)
	_expect_error(raw, "text longer than 110", "text length")
	raw = _raw()
	_entry(raw, "party", "kai")["model"]["base"] = "dragon"
	_expect_error(raw, "model.base: 'dragon' not in", "model base")
	raw = _raw()
	_entry(raw, "floors", "floor_1")["timer_warnings"] = [300, 600]
	_expect_error(raw, "timer_warnings[1]", "timer warnings descending")
	raw = _raw()
	_entry(raw, "items", "itm_key_master")["sell"] = 5
	_expect_error(raw, "key items must have sell 0", "key sell")
	raw = _raw()
	(_layout(raw)["chests"] as Array)[0]["type"] = "metal"
	_expect_error(raw, "required for metal/locked chests", "metal chest needs contents")
	raw = _raw()
	_entry(raw, "statuses", "sts_poison")["color"] = "green"
	_expect_error(raw, "color: must be a hex color", "hex color")


# --- rule 5: references
# -------------------------------------------------------------------------------------------------

func test_rule5_references() -> void:
	var raw: Dictionary = _raw()
	(_entry(raw, "enemies", "enm_kanalratte")["drops"] as Array)[0]["item"] = "itm_nope"
	_expect_error(raw, "unknown item 'itm_nope'", "drop item")
	raw = _raw()
	_entry(raw, "party", "kai")["attack_skill"] = "skl_nope"
	_expect_error(raw, "unknown skill 'skl_nope'", "attack skill")
	raw = _raw()
	(_entry(raw, "floors", "floor_1")["encounters"] as Array)[0]["enemies"] = ["enm_ghost"]
	_expect_error(raw, "unknown enemy 'enm_ghost'", "encounter enemy")
	raw = _raw()
	_entry(raw, "achievements", "ach_first_blood")["box"] = "box_platinum"
	_expect_error(raw, "unknown lootbox 'box_platinum'", "achievement box")
	raw = _raw()
	_entry(raw, "floors", "floor_1")["timer_start_after"] = "enc_nope"
	_expect_error(raw, "timer_start_after: unknown encounter 'enc_nope'", "timer_start_after")
	raw = _raw()
	(raw["party"] as Dictionary)["start"]["inventory"]["itm_nope"] = 1
	_expect_error(raw, "unknown item 'itm_nope'", "start inventory")
	raw = _raw()
	_entry(raw, "statuses", "sts_slow")["excludes"] = ["sts_nope"]
	_expect_error(raw, "unknown status 'sts_nope'", "status excludes")


func test_rule5_class_learnset_missing_skill_is_warning_from_floor_3() -> void:
	var raw: Dictionary = _raw()
	(_entry(raw, "classes", "cls_kai_wrecker")["learnset"] as Array)[0]["skill"] = "skl_kai_wrecking_ball"
	var d: GameData = GameData.new()
	assert_true(d.load_from_tables(raw), "only a warning: " + "; ".join(d.errors))
	assert_len(d.warnings, 1)
	_entry(raw, "classes", "cls_kai_wrecker")["min_floor"] = 1
	_expect_error(raw, "unknown skill 'skl_kai_wrecking_ball'", "min_floor 1 → error")


# --- rule 6: type consistency
# ---------------------------------------------------------------------------------------------

func test_rule6_type_consistency() -> void:
	var raw: Dictionary = _raw()
	_entry(raw, "items", "itm_bandage")["use_skill"] = "skl_attack_kai"
	_expect_error(raw, "must have user \"item\"", "use_skill user")
	raw = _raw()
	_entry(raw, "skills", "skl_stunt_kai_suplex").erase("success_base")
	_expect_error(raw, "stunts need success_base", "stunt success_base")
	raw = _raw()
	_entry(raw, "skills", "skl_mop_holy_lick").erase("heal_mode")
	_expect_error(raw, "heal_mode: required for damage_type heal", "heal needs heal_mode")
	raw = _raw()
	_entry(raw, "enemies", "enm_kanalratte")["ai"] = {"type": "phased", "actions": []}
	_expect_error(raw, "ai.type phased needs phases", "phased without phases")
	raw = _raw()
	_entry(raw, "party", "kai")["stunts"] = ["skl_kai_heavy_swing"]
	_expect_error(raw, "must have category stunt", "stunt category")
	raw = _raw()
	_entry(raw, "party", "kai")["equipment"]["weapon"] = "itm_bandage"
	_expect_error(raw, "has type consumable", "equipment slot type")
	raw = _raw()
	var ai_actions: Array = _entry(raw, "enemies", "enm_kanalratte")["ai"]["actions"]
	ai_actions[0]["target"] = "all_enemies"
	_expect_error(raw, "does not fit skill target single_enemy", "AI target rule vs skill target")
	raw = _raw()
	_entry(raw, "floors", "floor_1")["quarter_boss"] = "enc_f1_a2"
	_expect_error(raw, "must have boss: true", "boss encounter flag")
	raw = _raw()
	_entry(raw, "party", "kai")["learnset"] = [{"level": 1, "skill": "skl_e_bite"}]
	_expect_error(raw, "kai].learnset[0].skill: skill 'skl_e_bite' has user \"enemy\"", "party learnset user")
	raw = _raw()
	_entry(raw, "party", "mopsula")["attack_skill"] = "skl_e_strike"
	_expect_error(raw, "mopsula].attack_skill: skill 'skl_e_strike' has user \"enemy\"", "party attack skill user")


# --- rule 7: party ----------------------------------------------------------------------------------------------------

func test_rule7_party() -> void:
	var raw: Dictionary = _raw()
	(_entries(raw, "party") as Array).pop_back()
	_expect_error(raw, "required member 'mopsula' missing", "mopsula required")
	raw = _raw()
	_entry(raw, "party", "mopsula")["battle_slot"] = 0
	_expect_error(raw, "duplicate battle_slot 0", "battle_slot unique")


# --- rule 8: floors + layout ------------------------------------------------------------------------------------------

func test_rule8_floors_and_layout() -> void:
	var raw: Dictionary = _raw()
	var f: Dictionary = _entry(raw, "floors", "floor_1")
	f["id"] = "floor_2"
	f["index"] = 2
	_expect_error(raw, "contiguous from 1", "index gap")
	raw = _raw()
	_entry(raw, "floors", "floor_1")["playable"] = false
	_expect_error(raw, "floor_1 must be playable", "floor_1 playable")
	raw = _raw()
	(_layout(raw)["cells"] as Array)[4]["doors"] = ""
	_expect_error(raw, "is not mirrored", "door symmetry")
	raw = _raw()
	(_layout(raw)["cells"] as Array)[4]["doors"] = ""
	(_layout(raw)["cells"] as Array)[1]["doors"] = "ESW"
	_expect_error(raw, "not reachable from start", "reachability")
	raw = _raw()
	(_layout(raw)["encounters_placed"] as Array)[0]["offset"] = [5.0, 0.0]
	_expect_error(raw, "offset: |x|, |z| must be <= 4.5", "offset limit")
	raw = _raw()
	(_layout(raw)["encounters_placed"] as Array)[0]["group_id"] = "g0"
	_expect_error(raw, "must match f1_g<k>", "group id format")
	raw = _raw()
	(_layout(raw)["cells"] as Array)[0]["kind"] = "normal"
	_expect_error(raw, "needs exactly 1 start cell", "one start")
	raw = _raw()
	(_layout(raw)["safe_rooms"] as Array)[0]["cell"] = [4, 6]
	_expect_error(raw, "must have kind safe", "safe room cell kind")
	raw = _raw()
	(_layout(raw)["cells"] as Array)[1]["zone"] = "zone_nope"
	_expect_error(raw, "unknown zone 'zone_nope'", "zone exists")
	raw = _raw()
	(_layout(raw)["cells"] as Array)[0]["x"] = 9
	_expect_error(raw, "outside grid", "grid bounds")


func test_rule8_waypoints_and_gates() -> void:
	var raw: Dictionary = _raw()
	(_layout(raw)["encounters_placed"] as Array)[0]["waypoints"] = [[1.0, 1.0], [9.0, 0.0]]
	_expect_error(raw, "waypoints[1]: |x|, |z| must be <= 4.5", "waypoint limit (room-local like offsets)")
	raw = _raw()
	_layout(raw)["gates"] = [{"cell": [3, 6], "dir": "N", "requires": "itm_key_master"},
		{"cell": [3, 5], "dir": "S", "requires": "itm_key_master"}]
	_expect_error(raw, "closes the same door as gates[0]", "both sides of one door are one door")


func test_lever_gate_is_normalized_to_the_defined_side() -> void:
	var raw: Dictionary = _raw()
	var lay: Dictionary = _layout(raw)
	lay["gates"] = [{"cell": [3, 5], "dir": "S", "requires": "event:fev_lever"}]
	(lay["events"] as Array).append({"id": "fev_lever", "type": "lever", "cell": [4, 6], "offset": [0.0, 0.0],
		"params": {"success": 0.6, "gate": "3,6,N", "flood_pct": 15, "encounter": "enc_f1_a2"}})
	var d: GameData = GameData.new()
	assert_true(d.load_from_tables(raw), "other side of the door resolves: " + "; ".join(d.errors))
	var events: Array = d.floor_def(1).layout["events"]
	assert_eq(events[1]["params"]["gate"], "3,5,S", "runtime key = side the gate is defined on")
	assert_eq(DataValidator.door_key(Vector2i(3, 6), "N"), DataValidator.door_key(Vector2i(3, 5), "S"))
	lay["gates"] = [{"cell": [4, 6], "dir": "W", "requires": "event:fev_lever"}]
	_expect_error(raw, "no layout gate at 3,6,N", "lever gate must name a gated door")


## Valid quarter boss setup on the fixture floor: cell (4, 6) becomes the boss room.
func _with_quarter_boss(raw: Dictionary) -> Dictionary:
	var f: Dictionary = _entry(raw, "floors", "floor_1")
	(f["encounters"] as Array).append({"id": "enc_f1_boss_x", "enemies": ["enm_kanalratte"], "weight": 0, "boss": true})
	f["quarter_boss"] = "enc_f1_boss_x"
	for c: Dictionary in (_layout(raw)["cells"] as Array):
		if int(c["x"]) == 4 and int(c["y"]) == 6:
			c["kind"] = "quarter_boss"
	(_layout(raw)["encounters_placed"] as Array).append({"group_id": "f1_qb", "enc_id": "enc_f1_boss_x",
		"cell": [4, 6], "state": "IDLE"})
	return _layout(raw)


func test_rule8_boss_placements() -> void:
	var raw: Dictionary = _raw()
	_with_quarter_boss(raw)
	var d: GameData = GameData.new()
	assert_true(d.load_from_tables(raw), "valid boss placement: " + "; ".join(d.errors))
	raw = _raw()
	(_with_quarter_boss(raw)["encounters_placed"] as Array)[1]["cell"] = [3, 6]
	_expect_error(raw, "group f1_qb must stand in a cell of kind quarter_boss", "boss group in a normal cell")
	raw = _raw()
	(_with_quarter_boss(raw)["encounters_placed"] as Array)[1]["enc_id"] = "enc_f1_a2"
	_expect_error(raw, "group f1_qb must use FloorDef.quarter_boss 'enc_f1_boss_x'", "boss group with another encounter")
	raw = _raw()
	(_with_quarter_boss(raw)["encounters_placed"] as Array)[1]["group_id"] = "f1_g5"
	_expect_error(raw, "may only be placed as group f1_qb", "boss encounter under a normal group id")
	raw = _raw()
	(_with_quarter_boss(raw)["encounters_placed"] as Array).pop_back()
	_expect_error(raw, "needs exactly 1 placement with group f1_qb (got 0)", "boss without placement")
	raw = _raw()
	(_layout(raw)["encounters_placed"] as Array)[0]["group_id"] = "f1_fb"
	_expect_error(raw, "group f1_fb but FloorDef.floor_boss is empty", "floor boss group without floor boss")


# --- rule 9: mod lines ------------------------------------------------------------------------------------------------

func test_rule9_mod_lines() -> void:
	var raw: Dictionary = _raw()
	var lines: Array = _entries(raw, "mod_lines")
	for i in range(lines.size() - 1, -1, -1):
		if str(lines[i]["tag"]) == "intro":
			lines.remove_at(i)
	_expect_error(raw, "required tag 'intro' has no line", "required tag")
	raw = _raw()
	(_entries(raw, "mod_lines")[0] as Dictionary)["text"] = "Hallo {player}!"
	_expect_error(raw, "unknown placeholder {player}", "placeholder")
	raw = _raw()
	lines = _entries(raw, "mod_lines")
	for i in range(lines.size() - 1, -1, -1):
		if str(lines[i]["tag"]) == "timer_warn_600":
			lines.remove_at(i)
	_expect_error(raw, "tag 'timer_warn_600'", "timer warning tag")
	raw = _raw()
	_entry(raw, "lootboxes", "box_gold")["mod_tag"] = "lootbox_open_golden"
	_expect_error(raw, "referenced tag 'lootbox_open_golden' has no line", "referenced tag")
	raw = _raw()
	(_entries(raw, "mod_lines")[0] as Dictionary)["tag"] = "made_up_tag"
	_expect_error(raw, "unknown tag 'made_up_tag'", "tag vocabulary")
	for bad: String in ["Hallo {Name}!", "Hallo {name", "Hallo name}", "Etage { floor }"]:
		raw = _raw()
		(_entries(raw, "mod_lines")[0] as Dictionary)["text"] = bad
		_expect_error(raw, "malformed placeholder", "malformed placeholder in '%s'" % bad)


func test_rule9_referenced_tags_are_valid_tags() -> void:
	var raw: Dictionary = _raw()
	(raw["enemies"] as Dictionary)["pseudo_units"] = [{"id": "pu_train_gleis9", "name": "Zug", "icon": "train",
		"action": {"fixed_pct_maxhp": 35, "element": "physical", "ignores_guard": true, "target": "all_party"},
		"ctr_after": 160, "warn_tag": "boss_train_warning", "warn_at": 2}]
	_expect_error(raw, "referenced tag 'boss_train_warning' has no line", "warn_tag needs a line")
	(_entries(raw, "mod_lines") as Array).append({"id": "mod_boss_train_warning_01", "tag": "boss_train_warning",
		"text": "Zug fährt ein!"})
	var d: GameData = GameData.new()
	assert_true(d.load_from_tables(raw), "referenced tag is a valid tag: " + "; ".join(d.errors))
	assert_eq(d.pseudo_unit("pu_train_gleis9").ctr_after, 160)


# --- rule 10: conditions
# ------------------------------------------------------------------------------------------------

func test_rule10_conditions() -> void:
	var raw: Dictionary = _raw()
	_entry(raw, "achievements", "ach_one_hp")["condition"] = "e.min_party_hp = 1"
	_expect_error(raw, "ach_one_hp].condition: parse error", "parse error")
	raw = _raw()
	_entry(raw, "achievements", "ach_one_hp")["condition"] = "s.kills_totl > 3"
	_expect_error(raw, "unknown stat s.kills_totl", "unknown stat")
	raw = _raw()
	_entry(raw, "achievements", "ach_one_hp")["condition"] = "e.enemy_id == \"enm_kanalratte\""
	_expect_error(raw, "unknown key e.enemy_id for battle_won", "payload key of trigger")
	raw = _raw()
	_entry(raw, "scenes", "scn_mop_1")["condition"] = "e.kai_lvl >= 2"
	_expect_error(raw, "unknown key e.kai_lvl", "scene context key")


func test_defs_are_read_only() -> void:
	# Defs are shared (DB.data, real_data() cache): containers are locked recursively after loading. Writing to them
	# would raise a SCRIPT ERROR (fails the test run by design), so only the lock state and copies are checked here.
	var kai: PartyMemberDef = real_data().party_member("kai")
	assert_true(kai.base_stats.is_read_only(), "real data: base_stats")
	assert_true(kai.learnset.is_read_only(), "real data: learnset")
	assert_true((kai.learnset[0] as Dictionary).is_read_only(), "real data: nested learnset entry")
	assert_true((kai.model["colors"] as Dictionary).is_read_only(), "real data: nested model colors")
	assert_true(DB.party_member("kai").base_stats.is_read_only(), "DB.data too")
	var hp: int = int(kai.base_stats["hp"])
	var copy: Dictionary = kai.base_stats.duplicate(true)
	assert_false(copy.is_read_only(), "duplicate(true) gives a writable copy")
	copy["hp"] = hp + 100
	assert_eq(kai.base_stats["hp"], hp, "copy is independent")
	var d: GameData = _fixture()
	var f1: FloorDef = d.floor_def(1)
	assert_true(f1.layout.is_read_only())
	assert_true((f1.layout["cells"] as Array).is_read_only(), "layout.cells")
	assert_true(((f1.layout["cells"] as Array)[0] as Dictionary).is_read_only(), "layout cell")
	assert_true(((f1.layout["encounters_placed"] as Array)[0]["offset"] as Array).is_read_only(), "offset array")
	assert_true(f1.encounters.is_read_only(), "encounter list")
	var rat: EnemyDef = d.enemy("enm_kanalratte")
	assert_true((rat.ai["actions"] as Array).is_read_only(), "ai.actions")
	assert_true(((rat.ai["actions"] as Array)[0]["cond"] as Dictionary).is_read_only(), "ai action cond")
	assert_true(d.skill("skl_kai_heavy_swing").statuses.is_read_only(), "skill statuses")
	assert_true(d.mod_lines("intro").size() > 0 and not d.mod_lines("intro").is_read_only(), "getter lists are copies")


func test_vocabulary_copies_are_consistent() -> void:
	assert_eq(DataValidator.STAT_IDS, StatIds.ALL, "DataValidator.STAT_IDS == StatIds.ALL")
	assert_eq(DataValidator.ELEMENTS, Elements.ALL)
	assert_eq(DataValidator.SFX_IDS, SfxSynth.SFX_IDS)
	assert_eq(DataValidator.MUSIC_IDS, SfxSynth.MUSIC_IDS)
	var kinds: Array = []
	for k: StringName in Vfx.KINDS:
		kinds.append(String(k))
	assert_eq(DataValidator.VFX_KINDS, kinds)
	assert_eq(DataValidator.TABLES, GameData.TABLES)
	for trig: String in DataValidator.ACH_TRIGGERS:
		assert_true(DataValidator.TRIGGER_PAYLOAD_KEYS.has(trig), "payload keys for " + trig)
