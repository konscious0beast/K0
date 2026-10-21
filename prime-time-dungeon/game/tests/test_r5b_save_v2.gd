extends TestCase
## R5b part 2b, save format v2 (02_TECH §6.4, 07 §12.6 step 2): the data carry the real-time HP since the bake, so a
## version-1 save migrates once — a CTB save's party HP × 4 (a K.O. stays 0, capped at the new max HP), a real-time
## save keeps its HP; both lose combat_mode and hp_scale_pm and fight in real time; every 06 / 08 field stays (talents,
## species, casting, hero, Marotten, persona bias, rt_loadout / rt_preset / rt_toggles, rt_hints, inventory, bestiary,
## floor run). The fixtures are genuine version-1 files of kernel 2246c31 written by Save.save_slot: a CTB game led by
## Graf Mopsula and a real-time game led by Kai, both on level 5 in the Kiosk. Round trips keep the StateHash, a slot
## the game over rewrote (Save.record_game_over migrates the file) loads with the HP converted once, a newer file is
## refused.

const Harness := preload("res://tests/tools/rt_harness.gd")
const ROOT: String = "user://test_r5b_save_v2"
const DIR: String = "user://test_r5b_save_v2/saves"
const CTB_FILE: String = "res://tests/fixtures/saves/save_v1_ctb.json"
const RT_FILE: String = "res://tests/fixtures/saves/save_v1_realtime.json"


func before_each() -> void:
	_rmrf(ROOT)
	Save.save_dir = DIR
	Save.read_only = false


func after_each() -> void:
	if Game.combat != null:
		Game.end_combat()
	Save.save_dir = "user://saves"
	Save.read_only = false
	_rmrf(ROOT)
	Game.state = null
	Game.run_log = null
	Game.sim = null
	Game.in_battle = false


static func _rmrf(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for f: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	for sub: String in DirAccess.get_directories_at(path):
		_rmrf(path.path_join(sub))
	DirAccess.remove_absolute(path)


static func _fixture(path: String) -> Dictionary:
	var raw: Variant = JsonUtil.read_file(path)
	return (raw as Dictionary).duplicate(true) if raw is Dictionary else {}


## `raw` as slot file `slot` (the save directory of the test).
static func _put_slot(raw: Dictionary, slot: int) -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var f: FileAccess = FileAccess.open(Save.slot_path(slot), FileAccess.WRITE)
	f.store_string(JSON.stringify(raw, "\t"))
	f.close()


static func _max_hp(m: PartyMember) -> int:
	return Progression.total_stats(m, DB.data).values[StatBlock.Stat.HP]


# --- the migration ----------------------------------------------------------------------------------------------------

func test_a_ctb_save_continues_in_real_time_with_four_times_the_hp() -> void:
	var raw: Dictionary = _fixture(CTB_FILE)
	assert_eq([JsonUtil.to_int(raw.get("version", 0)), (raw["state"] as Dictionary).has("combat_mode")], [1, false],
		"fixture: a version-1 CTB save of kernel 2246c31")
	var m: Dictionary = SaveCodec.migrate(raw)
	assert_eq(m["version"], SaveCodec.VERSION)
	var party: Array = m["state"]["party"]
	assert_eq([JsonUtil.to_int(party[0]["hp"]), JsonUtil.to_int(party[1]["hp"])], [148, 0], "37 × 4; the K.O. stays 0")
	assert_eq([JsonUtil.to_int(party[0]["mp"]), JsonUtil.to_int(party[1]["mp"])], [5, 46], "MP unchanged")
	assert_false((m["state"] as Dictionary).has("combat_mode"))
	assert_eq(int((raw["state"]["party"] as Array)[0]["hp"]), 37, "the input is not modified")
	var st: GameState = SaveCodec.decode(raw, DB.data)
	assert_not_null(st, "; ".join(SaveCodec.last_errors()))
	if st == null:
		return
	assert_eq(SaveCodec.last_errors(), PackedStringArray(), "no warnings")
	assert_false(st.to_dict().has("combat_mode"), "a CTB save continues in real time (no mode any more)")
	var kai: PartyMember = st.member("kai")
	var mop: PartyMember = st.member("mopsula")
	assert_eq([kai.hp, kai.mp, mop.hp, mop.mp], [148, 5, 0, 46])
	assert_between(_max_hp(kai), 437, 443, "Kai's max HP on level 5 in real-time units (110 × 4)")
	# 06 / 08 fields
	assert_eq(st.hero, "mopsula", "06 A")
	assert_eq([kai.talents, mop.talents], [{"tal_kai_wischtechnik": 1}, {"tal_mop_liga_gelassen": 1}], "06 B")
	assert_eq([kai.species_id, kai.casting], ["spc_kai_pilzling", {"floor": 2, "visit": 1, "class_floor": 0,
		"class_visit": 0}], "06 B casting")
	assert_eq(Array(st.show.marotten.get("active", [])), ["mar_sneaky"], "06 C")
	assert_eq(PersonaRules.bias(st), PackedStringArray(["mar_brave", "mar_stunt"]), "08 persona bias")
	assert_eq([st.inventory.count("itm_bandage"), st.inventory.credits], [6, 50])
	assert_eq(int(st.bestiary["enm_kanalratte"]["defeated"]), 3)
	assert_eq([st.floor_run.location, st.floor_run.time_left_ticks], [&"sr_kiosk", 36000])


func test_hp_above_the_new_maximum_is_capped() -> void:
	var raw: Dictionary = _fixture(CTB_FILE)
	(raw["state"]["party"] as Array)[0]["hp"] = 120               # above the old max 110: × 4 = 480
	var st: GameState = SaveCodec.decode(raw, DB.data)
	assert_not_null(st)
	if st != null:
		assert_eq(st.member("kai").hp, _max_hp(st.member("kai")), "capped at the new max HP (_sanitize)")


func test_a_real_time_save_keeps_its_hp_and_its_real_time_fields() -> void:
	var raw: Dictionary = _fixture(RT_FILE)
	assert_eq(str(raw["state"].get("combat_mode", "")), "realtime", "fixture: a version-1 real-time save")
	assert_eq(int((raw["state"]["party"] as Array)[0].get("hp_scale_pm", 0)), 4000)
	var m: Dictionary = SaveCodec.migrate(raw)
	assert_false((m["state"] as Dictionary).has("combat_mode"), "v2: no combat mode")
	for e: Variant in (m["state"]["party"] as Array):
		assert_false((e as Dictionary).has("hp_scale_pm"), "v2: no HP scale")
	var st: GameState = SaveCodec.decode(raw, DB.data)
	assert_not_null(st, "; ".join(SaveCodec.last_errors()))
	if st == null:
		return
	assert_eq(SaveCodec.last_errors(), PackedStringArray(), "no warnings")
	var kai: PartyMember = st.member("kai")
	var mop: PartyMember = st.member("mopsula")
	assert_eq([kai.hp, kai.mp, mop.hp, mop.mp], [150, 20, 99, 7], "already real-time units")
	assert_between(_max_hp(kai), 437, 443)
	assert_eq([kai.rt_loadout, mop.rt_loadout], [{"2": "skl_kai_first_aid"}, {"3": "skl_mop_expert_opinion"}])
	assert_eq([mop.rt_preset, mop.rt_toggles], ["careful", {"interrupt": true, "potions": true, "show": false}])
	assert_eq(st.flags.get("rt_hints", {}), {"interrupt": true, "zone": true})
	assert_eq([st.hero, kai.talents, kai.species_id], ["kai", {"tal_kai_liga_routine": 1}, "spc_kai_pilzling"])
	assert_eq(PersonaRules.bias(st), PackedStringArray(["mar_brave", "mar_stunt"]))


func test_round_trips_keep_the_state_hash() -> void:
	for path: String in [CTB_FILE, RT_FILE]:
		var st: GameState = SaveCodec.decode(_fixture(path), DB.data)
		assert_not_null(st, path)
		if st == null:
			continue
		var d2: Dictionary = SaveCodec.encode(st, "test")
		assert_eq(d2["version"], 2, path)
		assert_false((d2["state"] as Dictionary).has("combat_mode"), "%s: a real-time state needs no key" % path)
		var back: GameState = SaveCodec.decode(JSON.parse_string(JSON.stringify(d2, "\t")), DB.data)
		assert_not_null(back, path)
		if back == null:
			continue
		assert_eq(StateHash.of(back), StateHash.of(st), path + ": encode → JSON → decode keeps the StateHash")
		assert_eq(SaveCodec.encode(back, "test"), d2, path + ": and the file")
		assert_eq(SaveCodec.migrate(d2), d2, path + ": a version-2 file passes unchanged")


# --- through the Save autoload ----------------------------------------------------------------------------------------

## A migrated CTB slot loads into a real-time run: the run log names it, a real-time combat builds the party from the
## converted HP, and the next save writes version 2 (loading it again changes nothing).
func test_a_migrated_slot_plays_and_saves_in_real_time() -> void:
	_put_slot(_fixture(CTB_FILE), 1)
	assert_eq(Save.load_slot(1), OK, Save.last_error())
	assert_true(Game.is_realtime(), "a CTB save continues in real time")
	assert_eq([str(Game.run_log.header.get("combat_mode", "")), int(Game.run_log.header.get("rt_version", 0))],
		["realtime", RunRules.RT_VERSION], "the run log names a real-time run")
	assert_eq(Game.state.member("kai").hp, 148)
	var setup: RtSetup = BattleBridge.make_rt_setup(Game.state, DB.data,
		Harness.command_for("enc_f1_a2", "mopsula", BattleSetup.Advantage.NORMAL), 7)
	assert_not_null(setup, "a real-time combat")
	if setup != null:
		for u: RtUnit in setup.units:
			if u.side == Combatant.Side.PARTY and u.def_id == "kai":
				assert_eq([u.hp, u.max_hp()], [148, _max_hp(Game.state.member("kai"))], "the combat takes the HP")
	var hash: String = StateHash.of(Game.state)
	assert_eq(Save.save_slot(1), OK)
	var file: Variant = JsonUtil.read_file(Save.slot_path(1))
	assert_eq(int((file as Dictionary)["version"]), 2, "written as version 2")
	assert_false(((file as Dictionary)["state"] as Dictionary).has("combat_mode"))
	Game.state = null
	assert_eq(Save.load_slot(1), OK)
	assert_eq([StateHash.of(Game.state), Game.state.member("kai").hp], [hash, 148], "loaded again: unchanged")


## The game over of a run loaded from a version-1 slot rewrites the slot (Save.record_game_over: migrate, game_overs +1)
## — the HP are converted exactly once, the next load continues from there.
func test_load_after_a_game_over() -> void:
	_put_slot(_fixture(CTB_FILE), 1)
	assert_eq(Save.load_slot(1), OK, Save.last_error())
	Game.state.member("kai").hp = 0                       # the lost fight of the live run (not saved)
	Game.on_game_over(&"defeat")
	var file: Dictionary = JsonUtil.read_file(Save.slot_path(1))
	assert_eq(int(file["version"]), 2, "the game over wrote the migrated slot")
	assert_eq(int(file["state"]["show"]["stats"].get("game_overs", 0)), 1)
	assert_eq(int((file["state"]["party"] as Array)[0]["hp"]), 148, "the saved HP, converted once")
	Game.state = null
	assert_eq(Save.load_slot(1), OK, Save.last_error())
	assert_true(Game.is_realtime())
	assert_eq([Game.state.member("kai").hp, Game.state.member("mopsula").hp], [148, 0])
	assert_eq(int(Game.state.show.stats.get("game_overs", 0)), 1)


func test_a_newer_file_is_refused() -> void:
	var newer: Dictionary = _fixture(RT_FILE)
	newer["version"] = SaveCodec.VERSION + 1
	assert_eq(SaveCodec.migrate(newer), {})
	assert_null(SaveCodec.decode(newer, DB.data))
	assert_true(SaveCodec.last_errors()[0].begins_with(SaveCodec.MSG_NEWER))
	_put_slot(newer, 2)
	assert_eq(Save.load_slot(2), ERR_FILE_UNRECOGNIZED, "refused, no fallback")
