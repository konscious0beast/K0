extends TestCase
## 09 ST0 (Kap. 11.2 Nr. 10): the contract pass of the seasons. Every signature the ST1 packages build against by
## reflection (argument and return types, static flag, defaults), the shared fields and constants, the stub headers and
## their owners (09 §11.4), the switch state.season != null (no season → no_season; the module stubs refuse with
## season_unavailable; the Stempelduell stub "sd" → sd_unavailable in RunRules, RunSim and Game.replay_log), the
## additive fields (a state without a season keeps its exact JSON and hash; the season block round-trips through Save
## v2), persona v2 (v1 stays readable), the data tables, the third validator pass and the mod_lines anchor — and no
## SIM_VERSION bump. A package that has to change one of these signatures files a change request first (09 §11.7).
## ST1-B (2026-10-12): SeasonState, SeasonRules, SeasonDef and validators/seasons.gd are real now (no stub header);
## a season can start (Game.start_season), its "season" / "clock" / "sleep" are SeasonRules' — the start in a running
## run is season_late; the stubs of the packages to come (away, talent v2, prof, gather, craft, cast) still refuse with
## season_unavailable. The season block is complete (the fixture save carries it), the season's M.O.D. lines follow
## the anchor.
## ST1-F (2026-10-12): CastSim is real (no stub header; its public API stays) — "cast" is CastSim's (a season without
## an AI cast: no_cast); the name catalog has its ≥ 300 names, the cast lines follow the anchor too (validators/cast.gd
## stays a stub until its schema hooks come, 02_TECH §0.8).
## ST1-C1 (2026-10-12): ThemeDef and validators/themes.gd are real (the Kulissen with art theme and programme pool);
## the boss lines of the season bosses (floors 2–6, enemies without the floor_1 tag) follow the anchor too.

const R1A := preload("res://tests/test_r1a_contract.gd")
const SeasonMin := preload("res://tests/fixtures/season_min/season_min.gd")
const STUB_HEAD: String = "# STUB(ST0) — owned by 09-ST1-%s. Replace completely, keep the public API."
const ROOT: String = "user://test_09_st0"
const SAVES: String = "user://test_09_st0/saves"
const DAY0: int = 1791921600

## script path → expected method signatures ("name(arg types) -> return[ static]"; "=" marks a default argument).
const METHODS: Dictionary = {
	"res://core/live/run_rules.gd": [
		"season_refusal(GameState, GameData, Dictionary) -> String static",
		"apply_season(GameState, GameData, Dictionary) -> Array[ExploreEvent] static",
		"command_refusal(GameState, GameData, Dictionary, Dictionary, bool, Dictionary, bool=) -> String static"],
	"res://core/live/command.gd": ["validate(Dictionary) -> String static", "is_external(Dictionary) -> bool static"],
	"res://core/live/state_hash.gd": ["of(GameState) -> String static", "hash_input(GameState) -> Dictionary static"],
	"res://autoload/game.gd": [
		"start_season(int, String, Dictionary=, String=, PersonaProfile=) -> bool",
		"season_op(Dictionary) -> bool", "season_clock(int) -> bool", "season_away(int) -> bool",
		"logout(String) -> bool", "pick_talent_row(String, int, String) -> bool",
		"prof_action(String, String) -> bool", "gather(String) -> bool", "craft(String, int=) -> bool",
		"cast_action(String, int, String=) -> bool", "record(Dictionary) -> void"],
	"res://autoload/save.gd": ["journal_path(int) -> String", "journal_append(int, Dictionary) -> Error",
		"journal_replay(int) -> Array[Dictionary]"],
	"res://core/progression/save_codec.gd": ["_sanitize_season_member(PartyMember, GameData) -> void static",
		"_sanitize_season(GameState, GameData) -> void static"],
	"res://core/data/game_data.gd": ["season_def(String) -> SeasonDef", "all_seasons() -> Array[SeasonDef]",
		"profession(String) -> ProfessionDef", "all_professions() -> Array[ProfessionDef]",
		"recipe(String) -> RecipeDef", "all_recipes() -> Array[RecipeDef]", "material(String) -> Dictionary",
		"gather_node(String) -> Dictionary", "cast_profile(String) -> Dictionary",
		"all_cast_profiles() -> Array[Dictionary]", "cast_names() -> Array[Dictionary]", "theme(String) -> ThemeDef",
		"all_themes() -> Array[ThemeDef]"],
	"res://autoload/db.gd": ["season_def(String) -> SeasonDef", "profession(String) -> ProfessionDef",
		"recipe(String) -> RecipeDef", "theme(String) -> ThemeDef"],
	"res://core/progression/persona_rules.gd": ["command_for(GameData, PersonaProfile) -> Dictionary static",
		"head_prof(GameData, String) -> String static", "hobby_recipe(GameData, String) -> String static",
		"head_start(GameState) -> Dictionary static", "check(GameState, GameData, Dictionary, bool) -> String static",
		"apply(GameState, GameData, Dictionary) -> bool static"],
	"res://core/season/season_state.gd": ["to_dict() -> Dictionary", "from_dict(Dictionary) -> SeasonState static"],
	"res://core/season/season_rules.gd": ["refusal(GameState, GameData, Dictionary) -> String static",
		"apply(GameState, GameData, Dictionary) -> Array[ExploreEvent] static"],
	"res://core/season/sleep_resolver.gd": ["refusal(GameState, GameData, Dictionary) -> String static",
		"apply(GameState, GameData, Dictionary) -> Array[ExploreEvent] static"],
	"res://core/season/cast_sim.gd": ["refusal(GameState, GameData, Dictionary) -> String static",
		"apply(GameState, GameData, Dictionary) -> Array[ExploreEvent] static"],
	"res://core/progression/talent_tree.gd": ["refusal(GameState, GameData, Dictionary) -> String static",
		"apply(GameState, GameData, Dictionary) -> Array[ExploreEvent] static"],
	"res://core/progression/professions.gd": ["refusal(GameState, GameData, Dictionary) -> String static",
		"apply(GameState, GameData, Dictionary) -> Array[ExploreEvent] static"],
	"res://core/data/defs/season_def.gd": ["from_dict(Dictionary) -> SeasonDef static"],
	"res://core/data/defs/profession_def.gd": ["from_dict(Dictionary) -> ProfessionDef static"],
	"res://core/data/defs/recipe_def.gd": ["from_dict(Dictionary) -> RecipeDef static"],
	"res://core/data/defs/theme_def.gd": ["from_dict(Dictionary) -> ThemeDef static"],
	"res://core/data/validators/seasons.gd": ["normalize(DataValidator, String, Variant) -> Dictionary static",
		"check(DataValidator) -> void static"],
	"res://core/data/validators/professions.gd": ["normalize(DataValidator, String, Variant) -> Dictionary static",
		"read_extras(DataValidator, Dictionary) -> void static", "check(DataValidator) -> void static"],
	"res://core/data/validators/cast.gd": ["normalize(DataValidator, String, Variant) -> Dictionary static",
		"read_extras(DataValidator, Dictionary) -> void static", "check(DataValidator) -> void static"],
	"res://core/data/validators/themes.gd": ["normalize(DataValidator, String, Variant) -> Dictionary static",
		"check(DataValidator) -> void static"],
}

## script path → property → type.
const PROPERTIES: Dictionary = {
	"res://core/progression/game_state.gd": {"season": "SeasonState"},
	"res://core/progression/party_member.gd": {"rested": "int", "professions": "Dictionary", "prof_head": "String",
		"talent_rows": "Dictionary"},
	"res://core/progression/floor_run.gd": {"gather_nodes": "Dictionary", "respawn": "Dictionary",
		"daily": "PackedStringArray"},
	"res://core/season/season_state.gd": {"def_id": "String", "format": "int", "tempo": "String", "mode": "String",
		"number": "int", "day0_utc": "int", "collapse_utc": "Array[int]", "utc": "int", "seen_unix": "int"},
	"res://core/data/defs/season_def.gd": {"id": "String", "name": "String", "format": "int", "days": "int",
		"places": "int", "air_time": "String", "rules": "Dictionary"},
	"res://core/data/defs/profession_def.gd": {"id": "String", "name": "String", "kind": "String"},
	"res://core/data/defs/recipe_def.gd": {"id": "String", "name": "String", "prof": "String", "grade": "int",
		"req": "int", "hobby_recipe": "bool"},
	"res://core/data/defs/theme_def.gd": {"id": "String", "name": "String", "floors": "PackedInt32Array",
		"program": "Array"},
}

## The stub files of ST0 → the ST1 package that owns them (09 §11.3, §11.4); ST1-B replaced its four, ST1-F CastSim,
## ST1-C the Kulissen (REAL).
const STUBS: Dictionary = {
	"res://core/season/sleep_resolver.gd": "G",
	"res://core/progression/talent_tree.gd": "D", "res://core/progression/professions.gd": "E",
	"res://core/data/defs/profession_def.gd": "E",
	"res://core/data/defs/recipe_def.gd": "E",
	"res://core/data/validators/professions.gd": "E",
	"res://core/data/validators/cast.gd": "F",
}
## The former stubs, real since ST1-B, ST1-F and ST1-C (no stub header; the public API above stays).
const REAL: PackedStringArray = ["res://core/season/season_state.gd", "res://core/season/season_rules.gd",
	"res://core/data/defs/season_def.gd", "res://core/data/validators/seasons.gd", "res://core/season/cast_sim.gd",
	"res://core/data/defs/theme_def.gd", "res://core/data/validators/themes.gd"]
## The season commands whose module is still a stub (season_unavailable): ST1-G, -D, -E.
const STUB_CMDS: PackedStringArray = ["away", "talent", "prof", "gather", "craft"]

## One schema-valid sample of every season command (09 §9.1) and talent v2; the first is the start of a season.
const SEASON_CMDS: Array[Dictionary] = [
	{"t": "season", "v": 1, "op": "start", "def": "ssn_basis", "format": 6, "tempo": "calendar", "mode": "net",
		"number": 1, "day0_utc": DAY0, "collapse_utc": [DAY0 + 172800, DAY0 + 432000, DAY0 + 777600,
		DAY0 + 1209600, DAY0 + 1641600, DAY0 + 2073600], "cast": {}},
	{"t": "season", "v": 1, "op": "leave"},
	{"t": "clock", "sec": 60},
	{"t": "away", "sec": 3600},
	{"t": "sleep", "tactic": "careful"},
	{"t": "talent", "v": 2, "member": "kai", "row": 3, "id": "tal_kai_dicke_haut"},
	{"t": "prof", "op": "learn", "id": "prf_scrap"},
	{"t": "gather", "node": "nod_scrap_heap"},
	{"t": "craft", "recipe": "rcp_cooking_hobby", "n": 1},
	{"t": "cast", "op": "help", "who": 3},
]
const SD_START: Dictionary = {"t": "sd", "v": 1, "op": "start", "opp": "sdo_ulla", "deck": ["sdc_stempel"],
	"rh": "rules"}


func before_each() -> void:
	Save.save_dir = SAVES
	Save.read_only = false


func after_each() -> void:
	Game.state = null
	Game.run_log = null
	Game.sim = null
	Game.persona = null
	Game.mode = &"campaign"
	Game.timer_running = false
	Game.in_battle = false
	Save.save_dir = "user://saves"


## A fresh run on floor 1 with its hero chosen (no season).
func _sim(data: GameData) -> RunSim:
	var st: GameState = GameState.create_new(data, 0, GameState.DEFAULT_NAME, 4242, &"prime")
	var sim: RunSim = RunSim.new(data, st, {}, {})
	sim.apply({"t": "floor", "floor": 1})
	sim.apply({"t": "hero", "id": "kai"})
	return sim


## The log of `rl` plus `extra` commands at its last tick (cmd id 0 for external inputs, else the next player id).
static func _with_cmds(rl: RunLog, extra: Array) -> RunLog:
	var d: Dictionary = rl.to_dict()
	var cmds: Array = d["cmds"]
	var k: int = int((cmds.back() as Dictionary)["k"]) if not cmds.is_empty() else 0
	var next_id: int = 0
	for c: Variant in cmds:
		next_id = maxi(next_id, int((c as Dictionary)["id"]))
	for c: Variant in extra:
		var id: int = 0
		if not Command.is_external(c):
			next_id += 1
			id = next_id
		cmds.append({"k": k, "id": id, "c": c})
	d["checkpoints"] = []
	return RunLog.from_dict(d)


func _season() -> SeasonState:
	var s: SeasonState = SeasonState.new()
	s.def_id = "ssn_basis"
	s.number = 1
	s.day0_utc = DAY0
	s.utc = DAY0 + 60
	s.seen_unix = DAY0 + 60
	return s


# --- signatures, fields, stubs, constants -----------------------------------------------------------------------------

func test_st0_signatures_are_exact() -> void:
	for path: String in METHODS.keys():
		var script: GDScript = load(path) as GDScript
		assert_not_null(script, path)
		if script == null:
			continue
		var have: Dictionary = R1A._own_methods(script)
		for want: String in METHODS[path]:
			var name: String = want.substr(0, want.find("("))
			assert_eq(have.get(name, "<missing>"), want, "%s :: %s" % [path.get_file(), name])


func test_st0_fields_are_exact() -> void:
	for path: String in PROPERTIES.keys():
		var have: Dictionary = R1A._props(load(path) as GDScript)
		var want: Dictionary = PROPERTIES[path]
		for prop: String in want.keys():
			assert_eq(have.get(prop, "<missing>"), want[prop], "%s :: %s" % [path.get_file(), prop])


func test_stub_headers_and_owners() -> void:
	for path: String in STUBS.keys():
		var text: String = FileAccess.get_file_as_string(path)
		assert_true(text.begins_with(STUB_HEAD % str(STUBS[path]) + "\n"), "stub header (09 §11.4): " + path)
		assert_true((load(path) as GDScript).can_instantiate(), "compiles: " + path)
	for path: String in REAL:
		assert_false(FileAccess.get_file_as_string(path).begins_with("# STUB"), "ST1-B replaced the stub: " + path)
		assert_true((load(path) as GDScript).can_instantiate(), "compiles: " + path)
	for path: String in ["res://core/season/season_rules.gd", "res://core/season/sleep_resolver.gd",
			"res://core/season/cast_sim.gd", "res://core/progression/talent_tree.gd",
			"res://core/progression/professions.gd"]:
		assert_eq((load(path) as GDScript).get_script_constant_map().get("UNAVAILABLE", ""), "season_unavailable",
			path)


func test_constants() -> void:
	var tail: Array = Array(Command.TYPES).slice(Command.TYPES.size() - 9)
	assert_eq(tail, ["season", "clock", "away", "sleep", "prof", "gather", "craft", "cast", "sd"],
		"09 §9.1 + 10 §6.8: the new types, appended")
	assert_eq(Command.EXTERNAL, PackedStringArray(["gift", "twist", "clock", "away"]),
		"the clock is an external input (Brief §6b Nr. 4, cmd id 0)")
	assert_eq(Command.SEASON_OPS, PackedStringArray(["start", "tempo", "pause", "leave"]))
	assert_eq([Command.PERSONA_VERSION, Command.PERSONA_V1, PersonaRules.VERSION, PersonaRules.V1], [2, 1, 2, 1])
	assert_eq([Command.TALENT_ROW_VERSION, Command.SEASON_VERSION, Command.SD_VERSION], [2, 1, 1])
	assert_eq(RunSim.SIM_VERSION, 4, "ST0 adds no SIM_VERSION bump (09 §11.1: it comes with the switch to seasons)")
	assert_eq(SaveCodec.VERSION, 2, "the season block is additive in Save v2 (no v3)")
	assert_eq(StateHash.EXCLUDED_SEASON_KEYS, SeasonState.UNHASHED_KEYS, "only the local wall clock is unhashed")
	assert_eq([RunRules.NO_SEASON, RunRules.SD_UNAVAILABLE], ["no_season", "sd_unavailable"])
	assert_eq([SeasonState.TEMPOS, SeasonState.MODES], [PackedStringArray(["calendar", "binge"]),
		PackedStringArray(["net", "no_net"])])
	for t: String in ["seasons", "professions", "cast", "themes"]:
		assert_has(DataValidator.TABLES, t)
	assert_eq(GameData.TABLES, DataValidator.TABLES)
	var patterns: Dictionary = {"seasons": "ssn_", "professions": "prf_", "recipes": "rcp_", "materials": "mat_",
		"nodes": "nod_", "themes": "thm_"}
	for kind: String in patterns.keys():
		assert_eq(DataValidator.ID_PATTERNS[kind], "^%s[a-z0-9_]+$" % patterns[kind], kind)
	assert_eq(DataValidator.ID_PATTERNS["cast"], "^[a-z][a-z0-9_]*$")
	assert_eq(DataValidator.TABLE_EXTRA_KEYS["professions"], ["recipes", "materials", "nodes"])
	assert_eq(DataValidator.TABLE_EXTRA_KEYS["cast"], ["names"])
	for p: String in ["cast_", "season_", "prof_", "sleep_", "daily_", "ssn_"]:
		assert_has(DataValidator.OPTIONAL_MOD_TAG_PREFIXES, p)
	assert_eq(Save.journal_path(2), Save.save_dir + "/slot_2.journal", "09 §9.1: slot_N.journal next to the slot")


# --- the switch state.season != null ----------------------------------------------------------------------------------

func test_every_season_command_is_refused() -> void:
	var data: GameData = real_data()
	var st: GameState = _sim(data).state
	for c: Dictionary in SEASON_CMDS:
		assert_eq(Command.validate(c), "", "schema: " + str(c))
		var want: String = "season_late" if c == SEASON_CMDS[0] else "no_season"   # ST1-B: the run has started
		assert_eq(RunRules.command_refusal(st, data, {}, c, false, {}), want, "without a season: " + str(c["t"]))
	assert_eq(RunRules.command_refusal(st, data, {}, SD_START, false, {}), "sd_unavailable", "10 §6.8: until SD3")
	assert_eq(RunRules.command_refusal(st, data, {}, {"t": "talent", "member": "kai", "id": "tal_kai_dicke_haut"},
		false, {}), Talents.check_pick(st, data, "kai", "tal_kai_dicke_haut"), "the 06-B pick is unchanged")
	st.season = _season()
	var before: String = StateHash.of(st)
	for c: Dictionary in SEASON_CMDS:
		if not STUB_CMDS.has(str(c["t"])):
			continue
		assert_eq(RunRules.season_refusal(st, data, c), "season_unavailable", "with a season, the stub: " + str(c["t"]))
		assert_eq(RunRules.apply_season(st, data, c).size(), 0, "the stubs change nothing")
	assert_eq(StateHash.of(st), before)
	assert_eq(RunRules.season_refusal(st, data, SEASON_CMDS[9]), "no_cast", "ST1-F: CastSim decides (no AI cast)")
	assert_eq(RunRules.season_refusal(st, data, SEASON_CMDS[0]), "season_started", "ST1-B: SeasonRules decides")
	for c: Dictionary in [{"t": "clock", "sec": 60}, {"t": "sleep", "tactic": "careful"}, {"t": "season", "v": 1,
			"op": "leave"}]:
		assert_eq(RunRules.season_refusal(st, data, c), "", "ST1-B: " + str(c["t"]))
	assert_eq(RunRules.refused_id({"t": "persona", "v": 2, "prof": "prf_lab", "recipe": "", "bias": []}), "prf_lab")


func test_run_sim_refuses_them() -> void:
	var data: GameData = real_data()
	var sim: RunSim = _sim(data)
	var before: String = StateHash.of(sim.state)
	for c: Dictionary in SEASON_CMDS:
		sim.apply(c)
	sim.apply(SD_START)
	var reasons: Array = []
	for rc: Dictionary in sim.rejected_cmds:
		reasons.append(str(rc["reason"]))
	assert_eq(reasons, ["season_late", "no_season", "no_season", "no_season", "no_season", "no_season",
		"no_season", "no_season", "no_season", "no_season", "sd_unavailable"])
	assert_eq(StateHash.of(sim.state), before, "nothing changed")
	assert_null(sim.state.season)


func test_both_verifiers_report_them_in_logs() -> void:
	Game.new_game(0, "Kai", 4242)
	var live: int = Game.run_log.cmds().size()
	var rl: RunLog = _with_cmds(Game.run_log, [SD_START, {"t": "clock", "sec": 60}, SEASON_CMDS[0]])
	assert_eq(rl.rejected, 0, "clock carries cmd id 0 (external), the others the next player ids")
	var g: String = "; ".join(Game.replay_log(rl)["errors"])
	var r: String = "; ".join(RunSim.replay(DB.data, rl)["errors"])
	for want: String in ["sd_unavailable", "no_season", "season_late"]:   # ST1-B: the start comes before the floor
		assert_has(g, want, "Game.replay_log")
		assert_has(r, want, "RunSim.replay")
	assert_eq(Game.run_log.cmds().size(), live, "a replay records nothing")


func test_game_facades_record_nothing() -> void:
	Game.new_game(0, "Kai", 4242)
	var n: int = Game.run_log.cmds().size()
	var before: String = StateHash.of(Game.state)
	assert_false(Game.season_op(SEASON_CMDS[0]), "season_late: the run has started")
	assert_false(Game.season_op({"t": "season", "v": 1, "op": "leave"}))
	assert_false(Game.season_clock(60))
	assert_false(Game.season_away(3600))
	assert_false(Game.logout("careful"))
	assert_false(Game.pick_talent_row("kai", 3, "tal_kai_dicke_haut"))
	assert_false(Game.prof_action("learn", "prf_scrap"))
	assert_false(Game.gather("nod_scrap_heap"))
	assert_false(Game.craft("rcp_cooking_hobby"))
	assert_false(Game.cast_action("help", 3, "itm_bandage"))
	assert_eq([Game.run_log.cmds().size(), StateHash.of(Game.state)], [n, before], "nothing recorded, nothing changed")
	assert_null(Game.state.season)
	assert_eq(Save.journal_append(1, {"t": "clock", "sec": 60}), OK, "no journal without a season save")
	assert_eq(Save.journal_replay(1), [] as Array[Dictionary], "no journal file")
	var ro: bool = Save.read_only
	Save.read_only = true                         # (no slot, journal or career file of this test stays behind)
	assert_true(Game.start_season(1, "ssn_basis"), "ST1-B: a season starts (debug builds: --season, README §6)")
	Save.read_only = ro
	assert_eq(Game.run_log.cmds()[0]["c"]["t"], "season", "the start before floor → hero")
	assert_not_null(Game.state.season)


# --- additive fields, hash and save -----------------------------------------------------------------------------------

func test_fields_are_additive_and_hashed() -> void:
	var data: GameData = real_data()
	var st: GameState = _sim(data).state
	var d: Dictionary = st.to_dict()
	assert_false(d.has("season"), "no season: no key (every state of today keeps its JSON and hash)")
	for m: Variant in (d["party"] as Array):
		for k: String in ["rested", "professions", "prof_head", "talent_rows"]:
			assert_false((m as Dictionary).has(k), k)
	for k: String in ["gather_nodes", "respawn", "daily"]:
		assert_false((d["floor_run"] as Dictionary).has(k), k)
	var plain: String = StateHash.of(st)
	st.season = _season()
	var with_season: String = StateHash.of(st)
	assert_ne(with_season, plain, "the season block is hashed")
	st.season.seen_unix += 999
	assert_eq(StateHash.of(st), with_season, "the local wall clock is not (09 §9.1)")
	assert_false((StateHash.hash_input(st)["season"] as Dictionary).has("seen_unix"))
	st.season.utc += 60
	assert_ne(StateHash.of(st), with_season, "the season clock is")
	var kai: PartyMember = st.member("kai")
	kai.rested = 50
	kai.professions = {"prf_lab": 12}
	kai.prof_head = "prf_lab"
	kai.talent_rows = {"3": "tal_kai_dicke_haut"}
	st.floor_run.gather_nodes = {"nod_scrap_heap@2,3": 1}
	st.floor_run.respawn = {"f1_g1": DAY0 + 86400}
	st.floor_run.daily = PackedStringArray(["daily_x"])
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(st.to_dict()))
	var back: GameState = GameState.from_dict(parsed)
	assert_eq(back.to_dict(), st.to_dict(), "round trip through JSON")
	assert_eq(StateHash.of(back), StateHash.of(st))
	assert_eq(back.season.collapse_utc, st.season.collapse_utc)


func test_save_v2_with_the_season_block() -> void:
	var data: GameData = SeasonMin.data()
	assert_eq(data.errors, PackedStringArray(), "tests/fixtures/season_min loads")
	var file: Dictionary = JsonUtil.read_file(SeasonMin.SAVE_V2)
	assert_eq(int(file["version"]), 2)
	var st: GameState = SaveCodec.decode(file, data)
	assert_not_null(st, "; ".join(SaveCodec.last_errors()))
	if st == null:
		return
	assert_eq([st.season.def_id, st.season.format, st.season.day0_utc, st.season.collapse_utc.size()],
		["ssn_test", 6, DAY0, 6])
	var kai: PartyMember = st.member("kai")
	assert_eq([kai.rested, kai.professions, kai.prof_head, kai.talent_rows], [120,
		{"prf_cooking": 1, "prf_first_aid": 51}, "prf_first_aid", {"3": "tal_kai_wischtechnik"}])
	assert_eq([st.floor_run.gather_nodes, st.floor_run.daily], [{"nod_test_heap@1,2": 2},
		PackedStringArray(["daily_test_1"])])
	assert_eq(CanonicalJson.normalize(SaveCodec.encode(st, "st0")["state"]), CanonicalJson.normalize(file["state"]),
		"the season block round-trips (JSON numbers compared canonically)")
	var bad: Dictionary = file.duplicate(true)
	(bad["state"] as Dictionary)["season"] = 5
	assert_has(SaveCodec.validate(bad, data), "state.season: not an object")
	var odd: Dictionary = file.duplicate(true)
	(((odd["state"] as Dictionary)["party"] as Array)[0] as Dictionary)["professions"] = {"prf_nope": 9}
	((odd["state"] as Dictionary)["season"] as Dictionary)["def"] = "ssn_gone"
	var fixed: GameState = SaveCodec.decode(odd, data)
	assert_eq(fixed.member("kai").professions, {}, "an unknown profession is dropped")
	assert_eq(fixed.season.def_id, "ssn_gone", "an unknown template keeps its block (a season never turns campaign)")
	assert_has("; ".join(SaveCodec.last_errors()), "season template 'ssn_gone' unknown")
	var campaign: Dictionary = SaveCodec.encode(_sim(real_data()).state, "st0")
	assert_false((campaign["state"] as Dictionary).has("season"), "a campaign save has no season block")


# --- persona v2 (09 §8.6, §8.7) ---------------------------------------------------------------------------------------

func test_persona_v2() -> void:
	var data: GameData = real_data()
	var st: GameState = _sim(data).state
	var v2: Dictionary = {"t": "persona", "v": 2, "prof": "prf_lab", "recipe": "rcp_cooking_hobby", "bias": []}
	assert_eq(PersonaRules.check(st, data, v2, false), "")
	for c: Array in [[{"prof": "prf_nope"}, "unknown_prof"], [{"recipe": "rcp_nope"}, "unknown_recipe"],
			[{"prof": "org_care"}, "unknown_prof"]]:
		var cmd: Dictionary = v2.duplicate(true)
		cmd.merge(c[0], true)
		assert_eq(PersonaRules.check(st, data, cmd, false), c[1], str(c[0]))
	assert_eq(PersonaRules.check(st, data, v2, true), "event_run")
	assert_true(PersonaRules.apply(st, data, v2))
	assert_eq(st.flags["persona"], {"v": 2, "prof": "prf_lab", "recipe": "rcp_cooking_hobby", "bias": []})
	assert_eq(PersonaRules.head_start(st), {"prof": "prf_lab", "recipe": "rcp_cooking_hobby"})
	var old: GameState = _sim(data).state
	assert_true(PersonaRules.apply(old, data, {"t": "persona", "v": 1, "talent": "", "bias": ["mar_bio"]}))
	assert_eq(old.flags["persona"], {"v": 1, "bias": ["mar_bio"], "swapped": false}, "v1 keeps the K1 shape")
	assert_eq(PersonaRules.head_start(old), {"prof": "", "recipe": ""})
	assert_eq([PersonaRules.head_prof(data, "org_it"), PersonaRules.head_prof(data, "org_retired"),
		PersonaRules.head_prof(data, "org_allround")], ["prf_scrap", "", ""], "09 §8.6 (status tiles pick freely)")
	assert_eq([PersonaRules.hobby_recipe(data, "hob_animals"), PersonaRules.hobby_recipe(data, "")],
		["rcp_cooking_hobby", ""])


# --- data, validator, anchor -----------------------------------------------------------------------------------------

func test_season_data() -> void:
	var data: GameData = real_data()
	var s: SeasonDef = data.season_def("ssn_basis")
	assert_eq([s.format, s.days, s.places, s.air_time, s.rules], [6, 24, 100, "20:00", {"pvp": "arena"}],
		"09 §2.1, §6.2: no PvP against sleepers")
	var kinds: Dictionary = {}
	for p: ProfessionDef in data.all_professions():
		kinds[p.id] = p.kind
	assert_eq(kinds, {"prf_scrap": "gather", "prf_shrooms": "gather", "prf_salvage": "gather", "prf_props": "craft",
		"prf_lab": "craft", "prf_costume": "craft", "prf_cooking": "side", "prf_first_aid": "side"}, "09 §8.5")
	var r: RecipeDef = data.recipe("rcp_cooking_hobby")
	assert_eq([r.prof, r.grade, r.hobby_recipe], ["prf_cooking", 1, true])
	assert_eq(str(data.material("mat_scrap_metal").get("name", "")), "Altmetall")
	assert_eq(str(data.gather_node("nod_scrap_heap").get("prof", "")), "prf_scrap")
	assert_eq(str(data.cast_profile("extra").get("name", "")), "Statist:in")
	assert_true(data.cast_names().size() >= 300, "ST1-F: the name catalog (09 §4.2: ≥ 300 names)")
	assert_eq(data.theme("thm_unterstadt").floors, PackedInt32Array([1]))
	assert_eq(DB.season_def("ssn_basis").id, "ssn_basis")
	assert_eq(DB.profession("prf_lab").name, "Labor")
	assert_eq(DB.recipe("rcp_cooking_hobby").id, "rcp_cooking_hobby")
	assert_eq(DB.theme("thm_unterstadt").name, "Die Unterstadt")
	for t: String in ["seasons", "professions", "recipes", "materials", "nodes", "cast", "themes"]:
		assert_false(data.ids(t).is_empty(), "has_id / ids know " + t)
	assert_eq(data.material("mat_nope"), {}, "unknown entries: {} without an error")


func test_validator_third_pass() -> void:
	var cases: Array = [
		["professions", func(f: Dictionary) -> void: ((f["entries"] as Array)[0] as Dictionary)["id"] = "job_scrap",
			"invalid id"],
		["professions", func(f: Dictionary) -> void: ((f["recipes"] as Array)[0] as Dictionary)["prof"] = "prf_nope",
			"unknown profession 'prf_nope'"],
		["professions", func(f: Dictionary) -> void: (f["recipes"] as Array).append({"id": "rcp_second",
			"name": "Zweitrezept", "prof": "prf_cooking", "hobby_recipe": true}), "one per profession"],
		["professions", func(f: Dictionary) -> void: f["tools"] = [], "unknown top-level key"],
		["seasons", func(f: Dictionary) -> void: ((f["entries"] as Array)[0] as Dictionary)["format"] = 7,
			"6, 12 or 18"],
		["seasons", func(f: Dictionary) -> void: ((f["entries"] as Array)[0] as Dictionary)["rules"] = {"pvp": "open"},
			"no PvP against sleepers"],
		["themes", func(f: Dictionary) -> void: ((f["entries"] as Array)[0] as Dictionary)["floors"] = [19],
			"floor 19"],
		["cast", func(f: Dictionary) -> void: (f["names"] as Array).append({"name": "Hanne Hammerschlag"}), "twice"],
		["origins", func(f: Dictionary) -> void: ((f["entries"] as Array)[0] as Dictionary)["prof"] = "prf_nope",
			"unknown profession (professions.json) 'prf_nope'"],
	]
	for c: Array in cases:
		var raw: Dictionary = {}
		for t: String in GameData.TABLES:
			raw[t] = JsonUtil.read_file("res://data/%s.json" % t)
		(c[1] as Callable).call(raw[str(c[0])] as Dictionary)
		var d: GameData = GameData.new()
		assert_false(d.load_from_tables(raw, "test_09_st0"), str(c[2]))
		assert_has("; ".join(d.errors), str(c[2]), str(c[2]))


func test_mod_lines_anchor() -> void:
	var lines: Array = (JsonUtil.read_file("res://data/mod_lines.json") as Dictionary)["entries"]
	var at: int = -1
	for i in lines.size():
		if str((lines[i] as Dictionary)["id"]) == "mod_ssn_anchor_01":
			at = i
	assert_gt(at, 0, "the anchor")
	assert_eq(str((lines[at] as Dictionary)["tag"]), "ssn_anchor")
	var data: GameData = real_data()
	for i in range(at + 1, lines.size()):        # ST1-B: the block of the seasons grows behind it (09 §11.4)
		var tag: String = str((lines[i] as Dictionary)["tag"])
		var season_boss: bool = false             # ST1-C1: the lines of a season boss (no floor_1 tag)
		if tag.begins_with("boss_intro:") or tag.begins_with("boss_phase:"):
			var eid: String = tag.split(":")[1]
			var e: EnemyDef = data.enemy(eid) if data.has_id("enemies", eid) else null
			season_boss = e != null and e.boss and not e.tags.has("floor_1")
		assert_true(tag.begins_with("season_") or tag.begins_with("cast_") or season_boss,
			"behind the anchor: season lines only (%s)" % tag)
	assert_true(DataValidator.is_valid_mod_tag("ssn_anchor"))
	assert_true(str((lines[at - 1] as Dictionary)["tag"]).begins_with("persona_"), "behind block K")
