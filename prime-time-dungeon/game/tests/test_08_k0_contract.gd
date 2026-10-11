extends TestCase
## 08 §10.2 K0: the casting contract (one joint pass with 07 R1a). Every K0 signature by reflection (argument and
## return types, static flag, defaults), the shared fields and constants, the start talent from level 1
## (Talents.has_any with empty talents, the four guards of CR-21), PersonaRules.check / apply and the "persona"
## command in both verifiers, the export boundary (canary "ZZKANARI": hash inputs, run-log header, anchor, board entry
## and the files written next to the saves), the one SIM_VERSION bump (an older log or board entry is old_version —
## "ältere Version" — never a mismatch) and the neutral K0 stubs. A package that has to change one of these signatures
## files a change request first (08 §10.7).

const R1A := preload("res://tests/test_r1a_contract.gd")
const EventInfo := preload("res://scenes/ui/event_info.gd")
const CANARY: String = "ZZKANARI"
const ROOT: String = "user://test_08_k0"
const SAVES: String = "user://test_08_k0/saves"
const OLD_LOG: String = "res://tests/fixtures/live/run_log_sim_v1.json"
const EVENT_ID: String = "evt_offline_gleis9"

## script path → expected method signatures ("name(arg types) -> return[ static]"; "=" marks a default argument).
const METHODS: Dictionary = {
	"res://core/progression/persona_rules.gd": [
		"offer(GameData, String, String) -> PackedStringArray static",
		"bias_for(GameData, PackedStringArray) -> PackedStringArray static",
		"command_for(GameData, String, PackedStringArray) -> Dictionary static",
		"swap_command(String) -> Dictionary static",
		"check(GameState, GameData, Dictionary, bool) -> String static",
		"apply(GameState, GameData, Dictionary) -> bool static", "can_swap(GameState) -> bool static",
		"bias(GameState) -> PackedStringArray static", "weight_add(GameState, String, int) -> int static",
		"map_text(GameData, String, StringName) -> String static"],
	"res://core/progression/persona_profile.gd": [
		"canon(GameData) -> PersonaProfile static", "from_dict(Dictionary, GameData) -> PersonaProfile static",
		"to_dict() -> Dictionary", "fill_unset(GameData, PackedStringArray) -> void",
		"validate(GameData) -> PackedStringArray"],
	"res://core/progression/persona_privacy.gd": ["scrub_state_dict(Dictionary) -> Dictionary static",
		"restore_display(GameState, PersonaProfile) -> void static"],
	"res://core/show/persona_text.gd": [
		"ctx(PersonaProfile, GameData, RandomNumberGenerator) -> Dictionary static",
		"plain_line(TalentDef) -> String static", "check_name(String) -> String static",
		"check_free_text(String, int) -> String static",
		"nearest_tile(GameData, String, String) -> String static", "filter_ai_lines(Array, GameData) -> Array static"],
	"res://core/show/persona_beats.gd": ["plan_for(GameData, int) -> String static",
		"tag_for(GameData, PersonaProfile, String, int, StringName, int) -> String static"],
	"res://art/kit/persona_look.gd": ["apply(Dictionary, Dictionary, GameData) -> Dictionary static"],
	"res://autoload/show_persona_hooks.gd": ["_init(Node)", "on_chest(String) -> void",
		"on_boss_won(String) -> void", "on_safe_room(String) -> void", "on_floor_end(int) -> void",
		"on_floor_start(int) -> void", "drop_pending() -> void"],
	"res://core/progression/talents.gd": ["has_any(PartyMember, GameData=) -> bool static",
		"origin_field_range_pm(GameState, GameData) -> int static"],
	"res://core/data/game_data.gd": ["origin(String) -> Dictionary", "all_origins() -> Array[Dictionary]",
		"origin_talent(String) -> TalentDef", "has_origin_talent(String) -> bool", "hobby(String) -> Dictionary",
		"trait_def(String) -> Dictionary", "persona_entry(String, String) -> Dictionary",
		"persona_canon() -> Dictionary", "persona_plans() -> Array", "look(String) -> Dictionary",
		"looks_of(String) -> Array[Dictionary]"],
	"res://autoload/db.gd": ["party_model(String) -> Dictionary"],
	"res://autoload/save.gd": ["persona_path(int) -> String", "save_persona(int, PersonaProfile) -> Error",
		"load_persona(int) -> PersonaProfile", "delete_persona(int) -> Error"],
	"res://autoload/game.gd": ["new_game(int, String=, int=, StringName=, String=, PersonaProfile=) -> void",
		"apply_persona(Dictionary) -> bool", "_choose_initial_persona(PersonaProfile) -> void",
		"_persona_battle_look(BattleSetup) -> void"],
	"res://autoload/show.gd": ["on_safe_room_entered(String, bool) -> void"],
	"res://core/show/mod_announcer.gd": ["set_extra_lines(Callable) -> void"],
	"res://core/show/marotten_rules.gd": ["_draw_weight(GameState, MarotteDef, int) -> int static"],
	"res://core/live/run_sim.gd": ["version_status(Dictionary) -> String static",
		"version_error(Dictionary) -> String static", "is_event_run() -> bool"],
	"res://core/live/run_rules.gd": [
		"command_refusal(GameState, GameData, Dictionary, Dictionary, bool, Dictionary, bool=) -> String static"],
	"res://core/live/leaderboard.gd": ["version_status(Dictionary) -> String static"],
	"res://core/live/event_def.gd": ["persona_rule_errors(Variant) -> PackedStringArray static"],
	"res://core/data/validators/origins.gd": ["normalize(DataValidator, String, Variant) -> Dictionary static",
		"read_extras(DataValidator, Dictionary) -> void static", "check(DataValidator) -> void static"],
	"res://core/data/validators/looks.gd": ["normalize(DataValidator, String, Variant) -> Dictionary static",
		"check(DataValidator) -> void static"],
	"res://scenes/title/title_flow.gd": [
		"start_new_game(int, String, bool, int=, StringName=, String=, PersonaProfile=) -> bool static"],
	"res://scenes/boot/fullrun.gd": ["persona_from_args(PackedStringArray) -> String static",
		"persona_profile() -> PersonaProfile"],
	"res://scenes/ui/settings_menu.gd": ["_persona_section() -> void"],
	"res://scenes/ui/event_info.gd": ["entry_name(Dictionary) -> String static",
		"version_tag(Dictionary) -> String static"],
}

## script path → property → type.
const PROPERTIES: Dictionary = {
	"res://core/progression/party_member.gd": {"origin_talent": "String"},
	"res://autoload/game.gd": {"persona": "PersonaProfile"},
	"res://core/progression/persona_profile.gd": {"name": "String", "form": "String", "origin": "String",
		"occupation": "String", "job_text": "String", "hobby": "String", "hobby_text": "String",
		"traits": "PackedStringArray", "look": "Dictionary", "talent": "String", "offer": "PackedStringArray",
		"beats": "Dictionary", "ai": "Dictionary", "source": "String"},
}

const STUBS: PackedStringArray = ["res://core/progression/persona_rules.gd",
	"res://core/progression/persona_profile.gd", "res://core/progression/persona_privacy.gd",
	"res://core/show/persona_text.gd", "res://core/show/persona_beats.gd", "res://art/kit/persona_look.gd",
	"res://autoload/show_persona_hooks.gd", "res://core/data/validators/origins.gd",
	"res://core/data/validators/looks.gd"]


func before_each() -> void:
	_rmrf(ROOT)
	Save.save_dir = SAVES
	Save.read_only = false


func after_each() -> void:
	Game.state = null
	Game.run_log = null
	Game.sim = null
	Game.quest = null
	Game.persona = null
	Game.mode = &"campaign"
	Game.timer_running = false
	Game.in_battle = false
	Game.safe_room_clock = false
	Save.save_dir = "user://saves"
	Save.read_only = false
	_rmrf(ROOT)


static func _rmrf(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for f: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	for sub: String in DirAccess.get_directories_at(path):
		_rmrf(path.path_join(sub))
	DirAccess.remove_absolute(path)


## Every file below `path` as one string (canary search in what the game wrote next to the saves).
static func _all_text(path: String) -> String:
	var out: String = ""
	if not DirAccess.dir_exists_absolute(path):
		return out
	for f: String in DirAccess.get_files_at(path):
		out += FileAccess.get_file_as_string(path.path_join(f)) + "\n"
	for sub: String in DirAccess.get_directories_at(path):
		out += _all_text(path.path_join(sub))
	return out


## res://data as file-shaped tables, with extra start talents in origins.json → talents.
func _data_with_talents(extra: Array) -> GameData:
	var raw: Dictionary = {}
	for t: String in GameData.TABLES:
		raw[t] = JsonUtil.read_file("res://data/%s.json" % t)
	raw["rt_balance"] = JsonUtil.read_file("res://data/" + GameData.RT_BALANCE_FILE)
	((raw["origins"] as Dictionary)["talents"] as Array).append_array(extra.duplicate(true))
	var data: GameData = GameData.new()
	if not data.load_from_tables(raw, "test_08_k0"):
		fail("data invalid: " + "; ".join(data.errors))
	return data


## A fresh run state on floor 1 with its hero chosen (the moment the persona command is recorded, 08 §2.3).
func _sim(data: GameData, rules: Dictionary = {}, event_id: String = "") -> RunSim:
	var st: GameState = GameState.create_new(data, 0, GameState.DEFAULT_NAME, 4242, &"prime")
	var sim: RunSim = RunSim.new(data, st, rules, {"event_id": event_id})
	sim.apply({"t": "floor", "floor": 1})
	sim.apply({"t": "hero", "id": "kai"})
	return sim


static func _start(talent: String, bias: Array = []) -> Dictionary:
	return {"t": "persona", "v": 1, "talent": talent, "bias": bias}


static func _safe_room(data: GameData) -> String:
	return str((data.floor_def(1).layout.get("safe_rooms", [{}]) as Array)[0].get("id", ""))


## The log of `rl` plus `extra` commands at its last tick (player cmd ids after the log's).
static func _with_cmds(rl: RunLog, extra: Array) -> RunLog:
	var d: Dictionary = rl.to_dict()
	var cmds: Array = d["cmds"]
	var k: int = int((cmds.back() as Dictionary)["k"]) if not cmds.is_empty() else 0
	var next_id: int = 0
	for c: Variant in cmds:
		next_id = maxi(next_id, int((c as Dictionary)["id"]))
	for c: Variant in extra:
		next_id += 1
		cmds.append({"k": k, "id": next_id, "c": c})
	d["checkpoints"] = []
	return RunLog.from_dict(d)


# --- signatures ------------------------------------------------------------------------------------------------------

func test_k0_signatures_are_exact() -> void:
	for path: String in METHODS.keys():
		var script: GDScript = load(path) as GDScript
		assert_not_null(script, path)
		if script == null:
			continue
		var have: Dictionary = R1A._own_methods(script)
		for want: String in METHODS[path]:
			var name: String = want.substr(0, want.find("("))
			assert_eq(have.get(name, "<missing>"), want, "%s :: %s" % [path.get_file(), name])


func test_k0_fields_are_exact() -> void:
	for path: String in PROPERTIES.keys():
		var script: GDScript = load(path) as GDScript
		assert_not_null(script, path)
		if script == null:
			continue
		var have: Dictionary = R1A._props(script)
		var want: Dictionary = PROPERTIES[path]
		for prop: String in want.keys():
			assert_eq(have.get(prop, "<missing>"), want[prop], "%s :: %s" % [path.get_file(), prop])


func test_stub_headers_and_constants() -> void:
	for path: String in STUBS:
		assert_true(FileAccess.get_file_as_string(path).begins_with("# STUB(K0) — owned by 08-K"), "stub header " + path)
	assert_eq([PersonaRules.MAX_BIAS, PersonaRules.BIAS_WEIGHT_ADD, PersonaRules.BIAS_MIN_FLOOR], [3, 1, 2])
	assert_eq(PersonaRules.REASONS, PackedStringArray(["bad_version", "unknown_talent", "bad_bias", "already_set",
		"run_started", "event_run", "no_swap", "same"]), "08 §2.3")
	assert_eq(GameState.DEFAULT_NAME, "Kai")
	assert_eq(RunSim.SIM_VERSION, 2, "the ONE joint bump of 07 R1a + 08 K0 (1 → 2)")
	assert_eq([RunSim.OLD_VERSION, RunSim.NEW_VERSION, RunSim.OLD_VERSION_TAG],
		["old_version", "new_version", "ältere Version"])
	assert_eq(Command.TYPES[Command.TYPES.size() - 1], "persona")
	assert_eq([Command.PERSONA_VERSION, Command.PERSONA_MAX_BIAS], [PersonaRules.VERSION, PersonaRules.MAX_BIAS])
	assert_eq(ModAnnouncer.ALWAYS_SAID_PREFIXES, PackedStringArray(["persona_"]))
	assert_true(ModAnnouncer.NO_COOLDOWN_PREFIXES.has("persona_"))
	assert_eq(ModAnnouncer.EXTRA_WEIGHT, 2)
	assert_true(ModAnnouncer.always_said("persona_intro:org_animals"), "persona_* queue behind the running line")
	assert_true(GameData.TABLES.has("origins") and GameData.TABLES.has("looks"))
	for ph: String in ["cand", "job", "hobby", "club", "trait", "rival", "brand", "job_text"]:
		assert_true(DataValidator.TEXT_PLACEHOLDERS.has(ph), "placeholder {%s}" % ph)
	assert_true(DataValidator.OPTIONAL_MOD_TAG_PREFIXES.has("persona_"))
	assert_eq(DataValidator.MODEL_HAIR_STYLES, PackedStringArray(["short", "buzz", "long", "bun", "curls",
		"ponytail", "bald"]))
	assert_eq(DataValidator.MODEL_BEARDS, PackedStringArray(["none", "stubble", "moustache", "full"]))
	assert_eq(EventInfo.LOCAL_NAME, "Sie")
	assert_eq(Save.PERSONA_DIR, "persona")
	var hero_select: Dictionary = (load("res://scenes/title/hero_select.gd") as GDScript).get_script_constant_map()
	assert_eq(hero_select.get("CASTING_SCENE", ""), "res://scenes/title/name_entry.tscn", "K1 points it at casting")
	assert_false(hero_select.has("NAME_ENTRY"))


# --- data ------------------------------------------------------------------------------------------------------------

func test_origins_and_looks_data() -> void:
	var data: GameData = real_data()
	assert_eq(data.all_origins().size(), 1, "K0: the canon tile only (K1: the catalog)")
	assert_eq(str(data.origin("org_animals").get("talent", "")), "tal_org_animals")
	assert_true(data.has_origin_talent("tal_org_animals") and data.has_origin_talent("tal_org_nature"))
	assert_false(data.has_id("talents", "tal_org_animals"), "start talents are never in the Talent-Show pool")
	var t: TalentDef = data.origin_talent("tal_org_nature")
	assert_eq([t.max_rank, Array(t.for_members)], [1, ["kai"]])
	assert_eq(data.persona_canon(), {"name": "Kai", "form": "n", "origin": "org_animals",
		"occupation": "occ_animals_keeper", "hobby": "hob_animals", "traits": [], "talent": "tal_org_animals"})
	assert_eq(str(data.hobby("hob_animals").get("talent", "")), "tal_org_animals")
	assert_eq(str(data.trait_def("trt_caring").get("bias", "")), "mar_graf_finale")
	assert_eq(str(data.persona_entry("rivals", "rv_animals_1").get("name", "")), "Kira Katzenjammer")
	assert_eq(data.origin("org_nope"), {}, "unknown ids: {} without an error (display falls back to canon)")
	assert_eq(data.persona_plans().size(), 1)
	for kind: String in ["hair", "hair_color", "skin", "beard", "glasses", "outfit"]:
		assert_eq(data.looks_of(kind).size(), 1, "one canon look per kind: " + kind)
	assert_eq(str(data.look("lk_hair_short").get("style", "")), "short")
	for e: Dictionary in (JsonUtil.read_file("res://data/origins.json") as Dictionary)["talents"]:
		assert_false(Talents.offer(GameState.create_new(data, 0, "Kai", 1, &"prime"), data, "kai", 2).has(e["id"]))
	var fixture: GameData = GameData.new()
	assert_true(fixture.load_dir("res://tests/fixtures/data_min"), "; ".join(fixture.errors))
	assert_true(fixture.has_origin_talent("tal_org_animals"), "fixtures carry origins.json / looks.json")
	var again: GameData = GameData.new()
	assert_true(again.load_dir("res://data"))
	assert_true(again.load_dir("res://data"), "reloading clears the (frozen) persona tables")
	assert_eq(again.all_origins().size(), 1)


func test_mod_lines_anchor_order() -> void:
	var lines: Array = (JsonUtil.read_file("res://data/mod_lines.json") as Dictionary)["entries"]
	var ids: Array = [str((lines[lines.size() - 2] as Dictionary)["id"]), str((lines.back() as Dictionary)["id"])]
	assert_eq(ids, ["mod_rt_set_quiet_01", "mod_persona_intro_01"], "08 §10.7: block K grows behind its anchor")
	assert_eq(str((lines.back() as Dictionary)["tag"]), "persona_intro")


func test_validator_k0_rules() -> void:
	var raw: Dictionary = {}
	for t: String in GameData.TABLES:
		raw[t] = JsonUtil.read_file("res://data/%s.json" % t)
	var ml: Array = (raw["mod_lines"] as Dictionary)["entries"]
	ml.append({"id": "mod_k0_test_cand_01", "tag": "level_up", "voice": "mod", "text": "{cand} {name} levelt.",
		"weight": 1})
	var ok: GameData = GameData.new()
	assert_true(ok.load_from_tables(raw.duplicate(true)), "{cand} is allowed in every line: "
		+ "; ".join(ok.errors))
	var cases: Array = [
		[{"id": "mod_k0_test_job_01", "tag": "level_up", "voice": "mod", "text": "Sie sind {job}."},
			"{job} only in persona_* lines and scenes"],
		[{"id": "mod_k0_test_jt_01", "tag": "persona_intro", "voice": "mod", "text": "'{job_text}'?"},
			"{job_text} only in persona_intro:custom lines"],
	]
	for c: Array in cases:
		var r: Dictionary = raw.duplicate(true)
		((r["mod_lines"] as Dictionary)["entries"] as Array).append(c[0])
		var d: GameData = GameData.new()
		assert_false(d.load_from_tables(r), str(c[0]))
		assert_has("; ".join(d.errors), str(c[1]))
	var custom: Dictionary = raw.duplicate(true)
	((custom["mod_lines"] as Dictionary)["entries"] as Array).append({"id": "mod_k0_test_jt_02",
		"tag": "persona_intro:custom", "voice": "mod", "text": "'{job_text}'? Steht nicht in der Kartei."})
	var cd: GameData = GameData.new()
	assert_true(cd.load_from_tables(custom), "; ".join(cd.errors))
	var bad_id: Dictionary = raw.duplicate(true)
	(((bad_id["origins"] as Dictionary)["rivals"] as Array)[0] as Dictionary)["id"] = "rival_1"
	var bd: GameData = GameData.new()
	assert_false(bd.load_from_tables(bad_id))
	assert_has("; ".join(bd.errors), "invalid id")
	var style: Dictionary = raw.duplicate(true)
	var kai: Dictionary = {}
	for e: Variant in ((style["party"] as Dictionary)["entries"] as Array):
		if str((e as Dictionary)["id"]) == "kai":
			kai = e
	(kai["model"] as Dictionary)["style"] = {"hair": "mohawk"}
	var sd: GameData = GameData.new()
	assert_false(sd.load_from_tables(style))
	assert_has("; ".join(sd.errors), "style.hair")
	(kai["model"] as Dictionary)["style"] = {"hair": "bun", "beard": "full"}
	assert_true(sd.load_from_tables(style), "; ".join(sd.errors))
	assert_eq(sd.party_member(str(kai["id"])).model.get("style", {}), {"hair": "bun", "beard": "full"})
	assert_false(real_data().party_member("kai").model.has("style"), "no style = today's Kai (dropped when empty)")


# --- start talent from level 1 (R1, CR-21) ---------------------------------------------------------------------------

func test_start_talent_works_from_level_1_with_empty_talents() -> void:
	var data: GameData = _data_with_talents([
		{"id": "tal_org_test_stats", "name": "Test", "icon": "stat",
			"effects": [{"kind": "stat_pct", "stat": "str", "pm": 50}, {"kind": "stat_flat", "stat": "hp", "value": 3}]},
		{"id": "tal_org_test_field", "name": "Test", "icon": "field", "effects": [{"kind": "field_range_pm", "pm": 1200}]},
	])
	var st: GameState = GameState.create_new(data, 0, "Kai", 4242, &"prime")
	var kai: PartyMember = st.member("kai")
	assert_eq([kai.level, kai.talents.size(), kai.origin_talent], [1, 0, ""])
	assert_false(Talents.has_any(kai, data), "no pool talent, no start talent")
	var str_before: int = Progression.total_stats(kai, data).values[StatBlock.Stat.STR]
	var hp_before: int = Progression.total_stats(kai, data).values[StatBlock.Stat.HP]
	kai.origin_talent = "tal_org_test_stats"
	assert_true(Talents.has_any(kai, data), "a valid start talent counts with empty talents")
	assert_gt(Progression.total_stats(kai, data).values[StatBlock.Stat.STR], str_before, "stat_pct at L1")
	assert_gt(Progression.total_stats(kai, data).values[StatBlock.Stat.HP], hp_before, "stat_flat at L1")
	kai.origin_talent = "tal_org_nature"
	assert_eq([Talents.element_pm(kai, data, "poison"), Talents.element_pm(kai, data, "shock")], [900, 850])
	assert_eq(Talents.elements(kai, data), PackedStringArray(["poison", "shock"]))
	var c: Combatant = Progression.to_combatant(kai, data, "p0", 0)
	assert_almost(float(c.element_mods.get("poison", 1.0)), 0.9, 0.0001, "to_combatant guard (CR-21)")
	kai.origin_talent = "tal_org_animals"
	assert_eq(Talents.marotte_bonus_hearts(st, data), 1, "the heart talent of the canon persona")
	kai.origin_talent = "tal_org_test_field"
	st.hero = "kai"
	assert_eq(int(HeroRules.field_mods(st, data)["range_pm"]), 1200, "Kai's own field strike")
	st.hero = "mopsula"
	assert_eq(Talents.origin_field_range_pm(st, data), 1200)
	assert_eq(int(HeroRules.field_mods(st, data)["range_pm"]), 1200, "the leading Graf carries it (CR-21)")
	assert_eq([Talents.picks(kai), Talents.pending_levels(kai).size()], [0, 0], "picks / open levels unchanged")
	kai.origin_talent = "tal_org_gone"
	assert_false(Talents.has_any(kai, data), "an unknown start talent is skipped")
	assert_true(Talents.has_any(kai), "without data a set origin_talent counts (SaveCodec dropped unknown ones)")
	assert_eq(Talents.element_pm(kai, data, "poison"), 1000)
	var saved: Dictionary = SaveCodec.encode(st, "test")
	var back: GameState = SaveCodec.decode(saved, data)
	assert_eq(back.member("kai").origin_talent, "", "SaveCodec._sanitize drops it")
	assert_has("; ".join(SaveCodec.last_errors()), "origin talent 'tal_org_gone' of kai dropped (unknown)")
	kai.origin_talent = "tal_org_nature"
	back = SaveCodec.decode(SaveCodec.encode(st, "test"), data)
	assert_eq(back.member("kai").origin_talent, "tal_org_nature", "a known one survives the round trip")


# --- PersonaRules + the command in both verifiers (08 §2.3) ----------------------------------------------------------

func test_persona_rules_check_reasons() -> void:
	var data: GameData = real_data()
	var st: GameState = _sim(data).state
	assert_eq(PersonaRules.check(st, data, {"t": "persona", "v": 2, "talent": "tal_org_animals", "bias": []}, false),
		"bad_version")
	assert_eq(PersonaRules.check(st, data, _start("tal_org_animals"), true), "event_run")
	assert_eq(PersonaRules.check(st, data, _start("tal_org_nope"), false), "unknown_talent")
	assert_eq(PersonaRules.check(st, data, _start("tal_kai_wischtechnik"), false), "unknown_talent", "pool talent")
	for bias: Array in [["mar_variety", "mar_graf_finale"], ["mar_variety", "mar_variety"], ["mar_nope"], [3],
			["mar_bio", "mar_brave", "mar_graf_finale", "mar_variety"]]:
		assert_eq(PersonaRules.check(st, data, _start("tal_org_animals", bias), false), "bad_bias", str(bias))
	for def: MarotteDef in data.all_marotten():
		if not def.rotation:
			assert_eq(PersonaRules.check(st, data, _start("tal_org_animals", [def.id]), false), "bad_bias", def.id)
	assert_eq(PersonaRules.check(st, data, PersonaRules.swap_command("tal_org_nature"), false), "no_swap",
		"no swap before a start")
	var cmd: Dictionary = _start("tal_org_animals", ["mar_graf_finale", "mar_variety"])
	assert_eq(PersonaRules.check(st, data, cmd, false), "")
	assert_true(PersonaRules.apply(st, data, cmd))
	assert_eq(st.member("kai").origin_talent, "tal_org_animals")
	assert_eq(st.flags.get("persona"), {"v": 1, "bias": ["mar_graf_finale", "mar_variety"], "swapped": false})
	assert_eq(PersonaRules.bias(st), PackedStringArray(["mar_graf_finale", "mar_variety"]))
	assert_eq(PersonaRules.check(st, data, cmd, false), "already_set")
	assert_false(PersonaRules.apply(st, data, cmd), "apply refuses like check")
	assert_eq(PersonaRules.check(st, data, PersonaRules.swap_command("tal_org_nature"), false), "no_swap",
		"swap only in a safe room")
	assert_false(PersonaRules.can_swap(st))
	RunRules.enter_safe_room(st, data, _safe_room(data))
	assert_true(PersonaRules.can_swap(st))
	assert_eq(PersonaRules.check(st, data, PersonaRules.swap_command("tal_org_animals"), false), "same")
	assert_true(PersonaRules.apply(st, data, PersonaRules.swap_command("tal_org_nature")))
	assert_eq(st.member("kai").origin_talent, "tal_org_nature")
	assert_eq(bool((st.flags["persona"] as Dictionary)["swapped"]), true)
	assert_eq(PersonaRules.check(st, data, PersonaRules.swap_command("tal_org_animals"), false), "no_swap", "once")
	var late: GameState = _sim(data).state
	late.rng_counter = 1
	assert_eq(PersonaRules.check(late, data, _start("tal_org_animals"), false), "run_started")
	var picked: GameState = _sim(data).state
	PersonaRules.apply(picked, data, _start("tal_org_animals"))
	RunRules.enter_safe_room(picked, data, _safe_room(data))
	picked.member("kai").talents = {"tal_kai_wischtechnik": 1}
	assert_eq(PersonaRules.check(picked, data, PersonaRules.swap_command("tal_org_nature"), false), "no_swap",
		"not after the first pool talent")


func test_persona_apply_follows_max_vitals() -> void:
	var data: GameData = _data_with_talents([{"id": "tal_org_test_hp", "name": "Test", "icon": "stat",
		"effects": [{"kind": "stat_pct", "stat": "hp", "pm": 50}, {"kind": "stat_flat", "stat": "hp", "value": 3}]}])
	var st: GameState = _sim(data).state
	var kai: PartyMember = st.member("kai")
	var before: int = Progression.total_stats(kai, data).values[StatBlock.Stat.HP]
	assert_eq(kai.hp, before, "starts at full HP")
	assert_true(PersonaRules.apply(st, data, _start("tal_org_test_hp")))
	var after: int = Progression.total_stats(kai, data).values[StatBlock.Stat.HP]
	assert_gt(after, before)
	assert_eq(kai.hp, after, "HP follow the raised maximum (Progression.follow_max_vitals, like Talents.pick)")


func test_run_sim_applies_and_refuses_persona() -> void:
	var data: GameData = real_data()
	var sim: RunSim = _sim(data)
	sim.apply(_start("tal_org_animals"))
	assert_eq(sim.rejected_cmds, [] as Array[Dictionary])
	assert_eq(sim.state.member("kai").origin_talent, "tal_org_animals")
	sim.apply(_start("tal_org_nature"))
	assert_eq(sim.rejected_cmds.size(), 1)
	assert_eq([str(sim.rejected_cmds[0]["gift_id"]), str(sim.rejected_cmds[0]["reason"])],
		["tal_org_nature", "already_set"], "RunRules.refused_id names the talent")
	var ev: RunSim = _sim(data, {}, EVENT_ID)
	assert_true(ev.is_event_run())
	ev.apply(_start("tal_org_animals"))
	assert_eq(str(ev.rejected_cmds[0]["reason"]), "event_run", "08 §8: event runs never take a persona")
	assert_eq(ev.state.member("kai").origin_talent, "")


func test_both_verifiers_replay_the_persona_command() -> void:
	Game.new_game(0, "Kai", 4242)
	assert_true(Game.apply_persona(PersonaRules.command_for(DB.data, "tal_org_nature", PackedStringArray())))
	assert_eq(Game.state.member("kai").origin_talent, "tal_org_nature")
	assert_false(Game.apply_persona(_start("tal_org_animals")), "already_set: refused, nothing recorded")
	var types: Array = []
	for c: Dictionary in Game.run_log.cmds():
		types.append(str((c["c"] as Dictionary)["t"]))
	assert_eq(types, ["floor", "hero", "persona"], "floor → hero → persona (08 §2.3)")
	var live: String = StateHash.of(Game.state)
	var a: Dictionary = Game.replay_log(Game.run_log, Game.sim.tick())
	assert_eq(a["errors"], PackedStringArray(), "Game.replay_log")
	assert_eq([a["final_hash"], a["version"]], [live, ""], "replay ≡ live")
	assert_eq(RunSim.replay(DB.data, Game.run_log)["errors"], PackedStringArray(), "RunSim.replay")
	var twice: RunLog = _with_cmds(Game.run_log, [_start("tal_org_animals")])
	assert_has("; ".join(Game.replay_log(twice)["errors"]), "already_set")
	assert_has("; ".join(RunSim.replay(DB.data, twice)["errors"]), "already_set")
	Game.start_event_run(EVENT_ID)
	assert_false(Game.apply_persona(_start("tal_org_animals")), "event run: refused")
	var ev: RunLog = _with_cmds(Game.run_log, [_start("tal_org_animals")])
	assert_has("; ".join(Game.replay_log(ev)["errors"]), "event_run")
	assert_has("; ".join(RunSim.replay(DB.data, ev)["errors"]), "event_run")


func test_k0_records_no_persona_command() -> void:
	var p: PersonaProfile = PersonaProfile.canon(DB.data)
	Game.new_game(0, "Kai", 4242, &"prime", "kai", p)
	assert_eq(Game.persona, p, "Game.persona: the local profile")
	for c: Dictionary in Game.run_log.cmds():
		assert_ne(str((c["c"] as Dictionary)["t"]), "persona", "K0 records no persona command (08 §10.2)")
	assert_eq(Game.state.member("kai").origin_talent, "")
	assert_false(Game.state.flags.has("persona"))


# --- export boundary (08 §2.7) ---------------------------------------------------------------------------------------

func test_privacy_canary_in_hashes_header_and_anchor() -> void:
	Game.new_game(1, CANARY, 4242)
	assert_eq([Game.state.player_name, Game.state.member("kai").display_name], [CANARY, CANARY], "display only")
	assert_false(JSON.stringify(StateHash.hash_input(Game.state)).contains(CANARY), "StateHash.hash_input")
	assert_false(Game.run_log.header.has("player_name"), "run-log header without a name")
	assert_false(JSON.stringify(Game.run_log.to_dict()).contains(CANARY), "run log")
	var renamed: Dictionary = Game.state.to_dict()
	var before: String = StateHash.of(Game.state)
	Game.state.player_name = "Jana"
	Game.state.member("kai").display_name = "Jana"
	assert_eq(StateHash.of(Game.state), before, "renaming changes no hash (P-2)")
	Game.state.player_name = CANARY
	Game.state.member("kai").display_name = CANARY
	assert_true(JSON.stringify(renamed).contains(CANARY), "(the plain state dictionary does carry it)")
	var scrubbed: Dictionary = PersonaPrivacy.scrub_state_dict(renamed)
	assert_false(JSON.stringify(scrubbed).contains(CANARY))
	assert_eq(str(scrubbed["player_name"]), GameState.DEFAULT_NAME)
	var setup: BattleSetup = Game.make_battle_setup(DB.floor_def(1).timer_start_after, 0, "")
	var battle: BattleState = BattleState.new(setup, DB.data)
	battle.start()
	assert_true(JSON.stringify(battle.to_dict()).contains(CANARY), "(the battle dictionary does carry it)")
	assert_false(JSON.stringify(StateHash.battle_hash_input(battle)).contains(CANARY), "StateHash.of_battle input")
	Game.in_battle = false
	var sr: String = _safe_room(DB.data)
	Game.enter_safe_room(sr)
	assert_eq(Save.save_slot(1), OK, Save.last_error())
	assert_eq(Save.load_slot(1), OK, Save.last_error())
	var h: Dictionary = Game.run_log.header
	assert_false(JSON.stringify(h).contains(CANARY), "anchor start_state + header (08 §2.7 Nr. 3)")
	assert_eq(str(h.get("start_hash", "")), StateHash.of(Game.state), "start_hash stays valid")
	assert_eq(int(h.get("sim_version", 0)), RunSim.SIM_VERSION, "Save's header names the kernel too")
	assert_eq(Game.state.player_name, CANARY, "K0: the slot keeps the name until K1 writes the persona file")
	Game.enter_safe_room(sr)
	Game.leave_safe_room()
	var live: String = StateHash.of(Game.state)
	var a: Dictionary = Game.replay_log(Game.run_log)
	assert_eq(a["errors"], PackedStringArray(), "the post-load segment replays from the nameless anchor")
	assert_eq(a["final_hash"], live)
	assert_false(_all_text(ROOT.path_join("replays")).contains(CANARY))


func test_privacy_canary_in_the_board_entry() -> void:
	Game.start_event_run(EVENT_ID)
	assert_eq(Game.state.player_name, GameState.DEFAULT_NAME)
	Game.state.player_name = CANARY                      # a display name must never reach a board or replay
	Game.state.member("kai").display_name = CANARY
	var summary: Dictionary = Game.finish_run(&"timer")
	var entry: Dictionary = summary.get("entry", {})
	assert_eq(str(((entry["players"] as Array)[0] as Dictionary)["display_name"]), "", "08 §2.7 Nr. 4")
	assert_eq(EventInfo.entry_name(entry), "Sie")
	assert_eq(EventInfo.entry_name({"players": [{"player_id": "p7", "display_name": "Pendlerin_42"}]}),
		"Pendlerin_42")
	assert_false(JSON.stringify(entry).contains(CANARY))
	var files: String = _all_text(ROOT)
	assert_true(files.contains(EVENT_ID), "(the board and the replay were written)")
	assert_false(files.contains(CANARY), "leaderboards/ and replays/ without the name")


# --- the one SIM_VERSION bump (08 §10.2 Nr. 7, 07 §10.2) -------------------------------------------------------------

func test_an_old_log_is_old_version_not_a_mismatch() -> void:
	var raw: Dictionary = JsonUtil.read_file(OLD_LOG)
	assert_eq(int((raw["header"] as Dictionary)["sim_version"]), 1, "fixture: recorded by the kernel before the bump")
	var old: RunLog = RunLog.from_dict(raw)
	var r: Dictionary = RunSim.replay(DB.data, old)
	assert_eq([r["version"], r["mismatch_at"], r["final_hash"]], ["old_version", -1, ""])
	assert_eq((r["errors"] as PackedStringArray).size(), 1)
	assert_has("; ".join(r["errors"]), "old_version")
	assert_has("; ".join(r["errors"]), "ältere Version")
	var g: Dictionary = Game.replay_log(old)
	assert_eq([g["version"], g["mismatch_at"], g["final_hash"]], ["old_version", -1, ""])
	assert_has("; ".join(g["errors"]), "old_version")
	assert_false(Game.replaying)
	var cat: EventCatalog = EventCatalog.new()
	cat.load_file(RunSim.EVENTS_PATH)
	var def: EventDef = cat.get_event(EVENT_ID)
	assert_has("; ".join(RunSim.header_errors(old.header, def, def.rules)), "old_version")
	# without the version check the same log would be a mismatch: its checkpoints hashed the name ("Robin")
	var patched: Dictionary = raw.duplicate(true)
	(patched["header"] as Dictionary)["sim_version"] = RunSim.SIM_VERSION
	var p: Dictionary = RunSim.replay(DB.data, RunLog.from_dict(patched))
	assert_eq(p["version"], "")
	assert_true(int(p["mismatch_at"]) >= 0, "a version-1 checkpoint never matches the version-2 hash")
	var newer: Dictionary = raw.duplicate(true)
	(newer["header"] as Dictionary)["sim_version"] = RunSim.SIM_VERSION + 1
	assert_eq(RunSim.replay(DB.data, RunLog.from_dict(newer))["version"], "new_version")
	assert_eq(RunSim.version_status({}), "", "hand-made logs without sim_version stay replayable")


func test_board_entries_of_an_older_version() -> void:
	assert_eq(Leaderboard.version_status({"score": 5, "sim_version": 1}), RunSim.OLD_VERSION)
	assert_eq(Leaderboard.version_status({"score": 5, "sim_version": RunSim.SIM_VERSION}), "")
	assert_eq(Leaderboard.version_status({"score": 5, "sim_version": RunSim.SIM_VERSION + 1}), RunSim.NEW_VERSION)
	assert_eq(Leaderboard.version_status({"score": 5}), "")
	var board: Leaderboard = Leaderboard.new()
	assert_eq(board.add({"score": 10, "sim_version": 1}), 1, "an old entry keeps its rank (tagged, not dropped)")
	assert_eq(board.add({"score": 20, "sim_version": RunSim.SIM_VERSION}), 1)
	assert_eq(EventInfo.version_tag({"score": 10, "sim_version": 1}), "ältere Version", "the lobby's tag")
	assert_eq(EventInfo.version_tag({"score": 20, "sim_version": RunSim.SIM_VERSION}), "")


# --- the neutral K0 stubs ---------------------------------------------------------------------------------------------

func test_k0_stubs_are_neutral() -> void:
	var data: GameData = real_data()
	var st: GameState = _sim(data).state
	assert_eq(PersonaRules.offer(data, "org_animals", "hob_animals"), PackedStringArray())
	assert_eq(PersonaRules.bias_for(data, PackedStringArray(["trt_caring"])), PackedStringArray())
	assert_eq(PersonaRules.command_for(data, "tal_org_animals", PackedStringArray()), _start("tal_org_animals"))
	assert_eq(PersonaRules.swap_command("tal_org_nature"), {"t": "persona", "v": 1, "talent": "tal_org_nature",
		"swap": true})
	assert_eq(Command.validate(PersonaRules.swap_command("tal_org_nature")), "")
	for def: MarotteDef in data.all_marotten():
		assert_eq(PersonaRules.weight_add(st, def.id, 3), 0)
		assert_eq(MarottenRules._draw_weight(st, def, 3), maxi(1, def.weight), "announce draw unchanged: " + def.id)
	assert_eq(PersonaRules.map_text(data, "Zoo", &"job"), "")
	var ctx: Dictionary = PersonaText.ctx(null, data, null)
	assert_eq(ctx, {"cand": "Kandidat:in", "job": "Tierpfleger:in", "hobby": "Freizeit", "club": "Ihr Freundeskreis",
		"trait": "undurchschaubar", "rival": "Kira Katzenjammer", "brand": "Wedelwurst"}, "08 §4.4 fallbacks")
	assert_eq([PersonaText.check_name(CANARY), PersonaText.check_free_text("x", 24)], ["", ""])
	assert_eq(PersonaBeats.plan_for(data, 4242), "plan_a")
	assert_eq(PersonaBeats.tag_for(data, null, "plan_a", 1, &"intro", 0), "")
	assert_eq(DB.party_model("kai"), DB.data.party_member("kai").model)
	assert_eq(DB.party_model("nobody"), {})
	var model: Dictionary = DB.data.party_member("kai").model
	assert_eq(PersonaLook.apply(model, {"hair": "lk_hair_short"}, data), model)
	assert_true(Save.persona_path(1).ends_with("persona/slot_1.json"), Save.persona_path(1))
	assert_null(Save.load_persona(1))
	assert_eq([Save.save_persona(1, PersonaProfile.canon(data)), Save.delete_persona(1)], [OK, OK])
	assert_false(DirAccess.dir_exists_absolute(ROOT.path_join("persona")), "K0 writes no persona file")
	var p: PersonaProfile = PersonaProfile.canon(data)
	assert_eq(PersonaProfile.from_dict(p.to_dict(), data).to_dict(), p.to_dict(), "persona file round trip")
	assert_eq(PersonaProfile.from_dict({"format": "ptd_persona", "v": 2}, data).to_dict(), p.to_dict(),
		"a newer file version → canon")
	assert_eq(EventDef.persona_rule_errors(null), PackedStringArray())
	assert_eq(EventDef.persona_rule_errors({"talent": false, "bias": false}), PackedStringArray())
	for bad: Variant in [{"talent": true, "bias": false}, {}, {"talent": false}, "off"]:
		assert_eq(EventDef.persona_rule_errors(bad).size(), 1, str(bad))
	var fr: GDScript = load("res://scenes/boot/fullrun.gd") as GDScript
	assert_eq([fr.call("persona_from_args", PackedStringArray(["--persona=canon"])),
		fr.call("persona_from_args", PackedStringArray(["--persona=org_media"])),
		fr.call("persona_from_args", PackedStringArray(["--persona=xyz"])),
		fr.call("persona_from_args", PackedStringArray())], ["canon", "org_media", "none", "none"])


func test_mod_announcer_extra_lines_hook() -> void:
	var data: GameData = real_data()
	var ann: ModAnnouncer = ModAnnouncer.new(data, make_rng(5))
	assert_eq(ann.pick("persona_intro", 1, 50.0, 0.0).id, "mod_persona_intro_01")
	assert_not_null(ann.pick("persona_intro", 1, 50.0, 0.5), "persona_* have no key cooldown")
	var extra: ModLineDef = ModLineDef.from_dict({"id": "mod_k0_extra_01", "tag": "persona_intro", "voice": "mod",
		"text": "Extra."})
	ann.set_extra_lines(func(tag: String) -> Array:
		return [extra] if tag == "persona_intro" else [])
	var seen: Dictionary = {}
	for i in 12:
		seen[ann.pick("persona_intro", 1, 50.0, 100.0 + i).id] = true
	assert_eq(seen.keys().size(), 2, "data line and provider line alternate (never twice in a row)")
	assert_true(seen.has("mod_k0_extra_01"))
	ann.set_extra_lines(Callable())
	for i in 4:
		assert_eq(ann.pick("persona_intro", 1, 50.0, 200.0 + i).id, "mod_persona_intro_01", "provider removed")
