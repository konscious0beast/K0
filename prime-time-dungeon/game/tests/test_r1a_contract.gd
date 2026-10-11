extends TestCase
## 07 §12.2 / §12.5 R1a: the real-time contract. Every cross-phase signature of the R1a stub list exactly (reflection:
## argument and return types, static flag, defaults), the additive fields / enum values / signals / constants of the
## shared files, the rt_balance.json start values, the rt normalization of the defs, the R1a guards (no real-time
## combat path before R5a, say_external in battle), and the fake sim playing every canned stream of
## tests/fixtures/rt_min. A phase that has to change one of these signatures files a change request first (07 §12.2).

const BUILDER: String = "res://tests/fixtures/rt_min/stream_builder.gd"
const STATIC: String = " static"

## script path → expected method signatures ("name(arg types) -> return[ static]"; "=" marks a default argument).
const METHODS: Dictionary = {
	"res://core/rt/rt_sim.gd": [
		"_init(RtSetup, GameData)", "start() -> Array[ActionEvent]", "submit(Dictionary) -> String",
		"step() -> Array[ActionEvent]", "tick() -> int", "is_finished() -> bool", "controlled_id() -> String",
		"unit(String) -> RtUnit", "units() -> Array[RtUnit]", "telegraphs() -> Array[RtTelegraph]",
		"apply_gift(Dictionary) -> Array[ActionEvent]", "run_to_end(int) -> Array[ActionEvent]",
		"snapshot() -> Dictionary", "can_use(String, String, String) -> String",
		"can_use_item(String, String, String) -> String", "suggest(String) -> String", "bar(String) -> Dictionary",
		"partner_special_skill(String) -> String", "cooldown_left(String, String) -> int",
		"cooldown_total(String, String) -> int", "gcd_left(String) -> int", "gcd_total(String) -> int",
		"cast_progress(String) -> Vector2i", "item_cd_left() -> int", "item_cd_total() -> int",
		"items_left() -> int"],
	"res://core/rt/rt_setup.gd": ["to_dict() -> Dictionary"],
	"res://core/rt/rt_unit.gd": ["snapshot() -> Dictionary"],
	"res://core/rt/rt_status.gd": ["to_dict() -> Dictionary"],
	"res://core/rt/rt_telegraph.gd": ["contains(int, int) -> bool", "to_dict() -> Dictionary"],
	"res://core/rt/rt_command.gd": [
		"ability(int, String, String, String) -> Dictionary static", "target(int, String, String) -> Dictionary static",
		"move(int, String, int, int, int, int, int) -> Dictionary static",
		"item(int, String, String, String) -> Dictionary static",
		"preset(int, String, String, Dictionary) -> Dictionary static",
		"auto_attack(int, String, bool) -> Dictionary static", "autopilot(int, String, bool) -> Dictionary static",
		"partner_special(int, String) -> Dictionary static", "hint(int, String) -> Dictionary static",
		"speed(int) -> Dictionary static", "validate(Dictionary) -> String static"],
	"res://core/rt/rt_geo.gd": [
		"set_radius(int, RtBalance) -> int static", "make_geo(int, int, bool, RtBalance) -> Dictionary static",
		"in_set(Dictionary, int, int) -> bool static", "walkable(Dictionary, int, int, int, bool) -> bool static",
		"project_walkable(Dictionary, int, int, int, bool) -> Vector2i static",
		"los(Dictionary, int, int, int, int) -> bool static", "formation(int, int, int, int) -> Vector2i static",
		"group_anchor(Dictionary, int, int) -> Vector2i static", "escape_point(RtSim, RtUnit) -> Vector2i static"],
	"res://core/rt/rt_rules.gd": [
		"compile(Array, String) -> Array[Dictionary] static", "choose(RtSim, RtUnit) -> Dictionary static",
		"eval_cond(RtSim, RtUnit, Dictionary, String) -> bool static"],
	"res://core/rt/rt_mods.gd": [
		"validate(Array) -> PackedStringArray static", "apply_static(RtSetup, GameData) -> void static",
		"on_event(RtSim, ActionEvent) -> Array[ActionEvent] static",
		"from_twists(Array, GameData) -> Array[Dictionary] static",
		"from_show_boss(EncounterDef) -> Array[Dictionary] static"],
	"res://core/rt/rt_balance.gd": ["from_data(GameData) -> RtBalance static"],
	"res://core/data/validators/rt.gd": ["check(DataValidator, Dictionary) -> void static"],
	"res://core/progression/battle_bridge.gd": ["make_rt_setup(GameState, GameData, Dictionary, int) -> RtSetup static"],
	"res://core/live/state_hash.gd": ["of_rt(RtSim) -> String static"],
	"res://core/live/run_log.gd": ["add_checkpoint(int, String, int=) -> void", "compact() -> void",
		"expand() -> void"],
	"res://autoload/game.gd": ["make_rt_setup(Dictionary) -> RtSetup", "combat_boundary() -> void",
		"combat_submit(Dictionary) -> String", "combat_hint(String) -> void", "combat_step() -> Array[ActionEvent]",
		"end_combat() -> BattleRewards"],
	"res://autoload/show.gd": ["take_pending_gift_rt(RtSim) -> Dictionary"],
	"res://scenes/combat/combat_director.gd": ["submit(Dictionary) -> void", "pause_for_hint(String) -> void",
		"resume() -> void", "unit_position(String) -> Vector3"],
	"res://scenes/combat/ui/combat_results.gd": ["present(BattleResult, BattleRewards) -> void"],
	"res://scenes/exploration/exploration.gd": ["control_temporarily(String) -> void"],
}

## script path → property → type (as _type_str prints it).
const PROPERTIES: Dictionary = {
	"res://core/rt/rt_sim.gd": {"setup": "RtSetup", "result": "BattleResult"},
	"res://core/rt/rt_setup.gd": {"cell": "Vector2i", "room_kind": "int", "geo": "Dictionary",
		"units": "Array[RtUnit]", "groups": "Array[Dictionary]", "controlled_id": "String", "presets": "Dictionary",
		"auto_attack": "bool", "auto_retarget": "bool", "rt_opener": "Dictionary", "mods": "Array[Dictionary]",
		"rules": "Dictionary", "difficulty": "StringName", "tutorial_steps": "PackedStringArray",
		"balance": "RtBalance", "opener": "String"},
	"res://core/rt/rt_unit.gd": {"driver": "RtUnit.Driver", "x": "int", "z": "int", "yaw": "int", "radius": "int",
		"move_cm_tick": "int", "stationary": "bool", "keep_cm": "int", "follow_cm": "int", "sample": "Array[int]",
		"move_budget": "int", "goal": "Array[int]", "entry": "Array[int]", "target_id": "String", "auto_on": "bool",
		"auto_skill": "String", "auto_ranged_skill": "String", "swing_ticks": "int", "reach": "int",
		"swing_ready": "int", "gcd_until": "int", "gcd_len": "int", "cast": "Dictionary", "queued": "Dictionary",
		"partner_order": "Dictionary", "cooldowns": "Dictionary", "lockout_until": "int", "threat": "Dictionary",
		"fixate_id": "String", "fixate_until": "int", "rules": "Array[Dictionary]", "rule_ready": "Dictionary",
		"follow_up": "Dictionary", "preset": "String", "toggles": "Dictionary", "react_at": "int",
		"ai_seen": "Dictionary", "mp_regen": "Dictionary", "mp_regen_next": "int", "mp_hit_ready": "int",
		"threat_pm": "int", "dmg_pm": "int", "ko_at": "int", "outside_since": "int", "pop_in_until": "int",
		"phase_perfect": "bool", "opener_done": "bool", "opener_pm": "int", "stunt_pm": "int", "bar": "Dictionary"},
	"res://core/rt/rt_status.gd": {"ends_at": "int", "period": "int", "next_tick_at": "int", "stacks": "int",
		"applied_at": "int", "amount": "int"},
	"res://core/rt/rt_telegraph.gd": {"id": "int", "source_id": "String", "skill_id": "String", "side": "int",
		"shape": "RtTelegraph.Shape", "x": "int", "z": "int", "yaw": "int", "r": "int", "r2": "int",
		"half_deg": "int", "start": "int", "impact_at": "int", "is_zone": "bool", "ends_at": "int", "period": "int",
		"next_tick_at": "int", "status_id": "String", "tick_skill": "String", "inside_last": "Dictionary"},
	"res://autoload/game.gd": {"combat": "RtSim"},
	"res://scenes/combat/ui/combat_results.gd": {"show_slot": "Control"},
	"res://core/battle/action_event.gd": {"tick": "int", "rt": "Dictionary", "by_ai": "bool"},
	"res://core/battle/battle_result.gd": {"group_ids": "PackedStringArray", "duration_ticks": "int",
		"interrupts": "int", "dodges": "int", "telegraph_hits": "int", "train_kills": "int", "perfect_phases": "int",
		"potions_used": "int", "flee_attempts": "int"},
	"res://core/progression/party_member.gd": {"hp_scale_pm": "int", "rt_preset": "String",
		"rt_toggles": "Dictionary", "rt_loadout": "Dictionary"},
	"res://core/progression/game_state.gd": {"combat_mode": "StringName"},
	"res://core/progression/floor_run.gd": {"regen_ticks": "int"},
	"res://autoload/game_settings.gd": {"combat_mode": "StringName", "combat_speed_pm": "int", "combat_assist": "int",
		"combat_camera_assist": "int", "combat_hints": "bool", "telegraph_contrast": "StringName",
		"auto_attack_default": "bool", "auto_retarget": "bool", "floating_text_scale": "int", "camera_shake": "bool"},
	"res://core/data/defs/skill_def.gd": {"rt": "Dictionary"},
	"res://core/data/defs/status_def.gd": {"rt": "Dictionary"},
	"res://core/data/defs/enemy_def.gd": {"rt": "Dictionary"},
	"res://core/data/defs/item_def.gd": {"rt": "Dictionary"},
	"res://core/data/defs/party_member_def.gd": {"rt": "Dictionary"},
	"res://core/data/defs/encounter_def.gd": {"rt": "Dictionary", "show_boss": "Dictionary"},
}

## 07 §3.13: appended after BATTLE_END in exactly this order.
const NEW_EVENT_TYPES: PackedStringArray = ["SWING", "ACTION_END", "ACTION_REFUSED", "CAST_START", "CAST_INTERRUPTED",
	"CAST_FAILED", "TELEGRAPH_START", "TELEGRAPH_IMPACT", "TELEGRAPH_DODGED", "TELEGRAPH_CANCELLED", "ZONE_START",
	"ZONE_END", "TARGET_CHANGED", "CONTROL_CHANGED", "POS_CORRECTED", "FLEE_WARNING", "ENRAGE", "PRESET_CHANGED",
	"SECOND"]

var _hex: RegEx = RegEx.create_from_string("^[0-9a-f]{64}$")


func after_each() -> void:
	Game.in_battle = false


# --- reflection helpers ----------------------------------------------------------------------------------------------

static func _type_str(p: Dictionary) -> String:
	var t: int = int(p.get("type", 0))
	var cls: String = str(p.get("class_name", ""))
	if t == TYPE_OBJECT:
		return cls
	if t == TYPE_ARRAY and int(p.get("hint", 0)) == PROPERTY_HINT_ARRAY_TYPE:
		return "Array[%s]" % str(p.get("hint_string", ""))
	if t == TYPE_INT and cls != "":
		return cls                                        # typed enum property
	if t == TYPE_NIL:
		return "Variant" if (int(p.get("usage", 0)) & PROPERTY_USAGE_NIL_IS_VARIANT) != 0 else "void"
	return type_string(t)


static func _sig(m: Dictionary) -> String:
	var args: PackedStringArray = []
	var argv: Array = m.get("args", [])
	var defaults: int = (m.get("default_args", []) as Array).size()
	for i in argv.size():
		args.append(_type_str(argv[i]) + ("=" if i >= argv.size() - defaults else ""))
	var s: String = "%s(%s)" % [str(m["name"]), ", ".join(args)]
	if str(m["name"]) != "_init":
		s += " -> " + _type_str(m.get("return", {}))
	if (int(m.get("flags", 0)) & METHOD_FLAG_STATIC) != 0:
		s += STATIC
	return s


static func _own_methods(script: GDScript) -> Dictionary:
	var out: Dictionary = {}
	for m: Dictionary in script.get_script_method_list():
		if not out.has(str(m["name"])):                   # the most derived definition comes first
			out[str(m["name"])] = _sig(m)
	return out


static func _props(script: GDScript) -> Dictionary:
	var out: Dictionary = {}
	for p: Dictionary in script.get_script_property_list():
		if (int(p.get("usage", 0)) & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0:
			out[str(p["name"])] = _type_str(p)
	return out


# --- signatures ------------------------------------------------------------------------------------------------------

func test_stub_signatures_are_exact() -> void:
	for path: String in METHODS.keys():
		var script: GDScript = load(path) as GDScript
		assert_not_null(script, path)
		if script == null:
			continue
		assert_true(script.can_instantiate(), "compiles: " + path)
		var have: Dictionary = _own_methods(script)
		for want: String in METHODS[path]:
			var name: String = want.substr(0, want.find("("))
			assert_eq(have.get(name, "<missing>"), want, "%s :: %s" % [path.get_file(), name])


func test_stub_fields_are_exact() -> void:
	for path: String in PROPERTIES.keys():
		var script: GDScript = load(path) as GDScript
		assert_not_null(script, path)
		if script == null:
			continue
		var have: Dictionary = _props(script)
		var want: Dictionary = PROPERTIES[path]
		for prop: String in want.keys():
			assert_eq(have.get(prop, "<missing>"), want[prop], "%s :: %s" % [path.get_file(), prop])


func test_class_hierarchy_constants_and_stub_headers() -> void:
	assert_true(RtSetup.new() is BattleSetup, "RtSetup extends BattleSetup")
	assert_true(RtUnit.new() is Combatant, "RtUnit extends Combatant")
	assert_true(RtStatus.new() is StatusEffect, "RtStatus extends StatusEffect")
	assert_eq(RtSim.TICKS_PER_SEC, 30)
	assert_eq(RtUnit.Driver.keys(), ["PLAYER", "AI", "AUTOPILOT"])
	assert_eq(RtTelegraph.Shape.keys(), ["CIRCLE", "CONE", "RING", "LINE"])
	assert_eq(RtCommand.REASONS, PackedStringArray(["schema", "past_tick", "finished", "unknown_unit",
		"not_controlled", "dead", "not_learned", "stunned", "casting", "drinking", "gcd", "cooldown", "mp", "range",
		"los", "target", "target_hp", "item_cd", "items_max", "no_item", "forbidden", "locked", "not_available",
		"grade_b"]), "07 §3.4 refusal reasons, fixed list")
	assert_eq(RtCommand.TYPES, RtVocab.COMMAND_TYPES)
	var director: Node = CombatDirector.new()
	assert_true(director is Node)
	assert_eq(director.get_script().get_script_signal_list().size(), 0, "no signals of its own (Events.combat_*)")
	director.free()
	var results: GDScript = load("res://scenes/combat/ui/combat_results.gd") as GDScript
	var sigs: Array = results.get_script_signal_list()
	assert_eq(sigs.size(), 1)
	if sigs.size() == 1:
		assert_eq(str(sigs[0]["name"]), "results_shown")
		assert_eq(_type_str((sigs[0]["args"] as Array)[0]), "BattleResult")
	for path: String in ["res://core/rt/rt_sim.gd", "res://core/rt/rt_setup.gd", "res://core/rt/rt_unit.gd",
			"res://core/rt/rt_status.gd", "res://core/rt/rt_telegraph.gd", "res://core/rt/rt_command.gd",
			"res://core/rt/rt_geo.gd", "res://core/rt/rt_rules.gd", "res://core/rt/rt_mods.gd",
			"res://core/rt/rt_balance.gd", "res://core/data/validators/rt.gd",
			"res://scenes/combat/combat_director.gd", "res://scenes/combat/ui/combat_results.gd"]:
		assert_true(FileAccess.get_file_as_string(path).begins_with("# STUB(R1a) — owned by "), "stub header " + path)


func test_events_signals_and_settings() -> void:
	var have: Dictionary = {}
	for sig: Dictionary in (load("res://autoload/events.gd") as GDScript).get_script_signal_list():
		var args: PackedStringArray = []
		for a: Dictionary in sig["args"]:
			args.append(_type_str(a))
		have[str(sig["name"])] = ", ".join(args)
	assert_eq(have.get("combat_started"), "RefCounted", "RtSim (bus without core classes)")
	assert_eq(have.get("combat_event"), "RefCounted", "ActionEvent")
	assert_eq(have.get("combat_finished"), "RefCounted", "BattleResult")
	assert_eq(have.get("dialog_layout_requested"), "StringName, Dictionary")
	assert_eq(have.get("show_boss_spotted"), "String")
	var s: GameSettings = GameSettings.new()
	s.ephemeral = true
	assert_eq(s.combat_mode, &"ctb", "CTB stays the default until R5b (07 §12.1)")
	assert_eq(s.combat_speed_pm, 1000)
	assert_eq([s.combat_assist, s.combat_camera_assist], [-1, -1])
	assert_eq([s.combat_hints, s.auto_attack_default, s.auto_retarget, s.camera_shake], [true, true, true, true])
	assert_eq([s.telegraph_contrast, s.floating_text_scale], [&"normal", 100])
	var d: Dictionary = s.to_dict()
	for key: String in ["combat_mode", "combat_speed_pm", "combat_assist", "combat_camera_assist", "combat_hints",
			"telegraph_contrast", "auto_attack_default", "auto_retarget", "floating_text_scale", "camera_shake"]:
		assert_true(d.has(key), "settings key " + key)


func test_settings_combat_section_round_trip() -> void:
	var path: String = GameSettings.PATH
	var had: bool = FileAccess.file_exists(path)
	var backup: String = FileAccess.get_file_as_string(path) if had else ""
	var w: GameSettings = GameSettings.new()
	w.ephemeral = false
	w.combat_mode = &"realtime"
	w.combat_speed_pm = 850
	w.telegraph_contrast = &"high"
	w.floating_text_scale = 130
	assert_eq(w.save_to_disk(), OK)
	var r: GameSettings = GameSettings.new()
	r.ephemeral = false
	r.load_from_disk()
	assert_eq([r.combat_mode, r.combat_speed_pm, r.telegraph_contrast, r.floating_text_scale],
		[&"realtime", 850, &"high", 130], "[combat] section round trip")
	var cfg: ConfigFile = ConfigFile.new()
	assert_eq(cfg.load(path), OK)
	assert_true(cfg.has_section("combat"), "keys live under [combat] (07 §7.8)")
	if had:
		var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		f.store_string(backup)
		f.close()
	else:
		DirAccess.remove_absolute(path)


# --- additive fields keep CTB states, results and events bit-identical -------------------------------------------

func test_new_fields_are_serialized_only_when_set() -> void:
	var e: ActionEvent = ActionEvent.make(ActionEvent.Type.DAMAGE)
	assert_false(e.to_dict().has("tick") or e.to_dict().has("rt") or e.to_dict().has("by_ai"), "CTB event JSON")
	e.tick = 12
	e.rt = {"x": 3}
	e.by_ai = true
	var back: ActionEvent = ActionEvent.from_dict(JSON.parse_string(JSON.stringify(e.to_dict())))
	assert_eq([back.tick, back.rt, back.by_ai], [12, {"x": 3}, true], "round trip (integral floats back to int)")
	var r: BattleResult = BattleResult.new()
	var plain: Dictionary = r.to_dict()
	for k: String in ["group_ids"] + Array(BattleResult.RT_INT_FIELDS):
		assert_false(plain.has(k), "CTB result without " + k)
	r.group_ids = PackedStringArray(["f1_g1", "f1_g2"])
	r.duration_ticks = 300
	r.flee_attempts = 2
	var rb: BattleResult = BattleResult.from_dict(JSON.parse_string(JSON.stringify(r.to_dict())))
	assert_eq([Array(rb.group_ids), rb.duration_ticks, rb.flee_attempts], [["f1_g1", "f1_g2"], 300, 2])
	var st: GameState = GameState.create_new(real_data(), 0, "Kai", 11, &"prime")
	st.floor_run = FloorRun.create(real_data().floor_def(1), 11, &"prime")
	var before: String = StateHash.of(st)
	var d: Dictionary = st.to_dict()
	assert_false(d.has("combat_mode"), "ctb is not serialized")
	assert_false((d["floor_run"] as Dictionary).has("regen_ticks"))
	for m: Dictionary in d["party"]:
		for k: String in ["hp_scale_pm", "rt_preset", "rt_toggles", "rt_loadout"]:
			assert_false(m.has(k), "member without " + k)
	st.combat_mode = &"realtime"
	st.floor_run.regen_ticks = 40
	st.party[0].hp_scale_pm = 4000
	st.party[0].rt_preset = "careful"
	st.party[0].rt_toggles = {"potions": true}
	st.party[0].rt_loadout = {"2": "skl_kai_first_aid"}
	assert_ne(StateHash.of(st), before, "set real-time fields are game-relevant (hashed)")
	var back_st: GameState = GameState.from_dict(JSON.parse_string(JSON.stringify(st.to_dict())))
	assert_eq(StateHash.of(back_st), StateHash.of(st), "and survive a JSON round trip")
	assert_eq([back_st.combat_mode, back_st.floor_run.regen_ticks, back_st.party[0].hp_scale_pm],
		[&"realtime", 40, 4000])


func test_hp_scale_is_the_last_step_of_total_stats() -> void:
	var data: GameData = real_data()
	var st: GameState = GameState.create_new(data, 0, "Kai", 3, &"prime")
	var kai: PartyMember = st.member("kai")
	var base: int = Progression.total_stats(kai, data).values[StatBlock.Stat.HP]
	kai.hp_scale_pm = 4000
	assert_eq(Progression.total_stats(kai, data).values[StatBlock.Stat.HP], base * 4, "07 §3.9.4 HP × 4")
	kai.hp_scale_pm = 1000
	assert_eq(Progression.total_stats(kai, data).values[StatBlock.Stat.HP], base, "1000 = CTB, unchanged")


func test_validator_constants_of_r1a() -> void:
	for p: String in ["rt_", "showboss_"]:
		assert_has(DataValidator.OPTIONAL_MOD_TAG_PREFIXES, p)
	assert_true(DataValidator.is_valid_mod_tag("rt_set_quiet"))
	assert_true(DataValidator.is_valid_mod_tag("showboss_spotted"))
	for k: String in ["duration_sec", "interrupts", "dodges", "telegraph_hits", "train_kills", "perfect_phases"]:
		assert_has(DataValidator.payload_keys("battle_won"), k, "07 §9.4 payload key")
	for s: String in ["interrupts_total", "dodges_total", "train_kills", "taunts_total"]:
		assert_has(StatIds.ALL, s)
	assert_eq(DataValidator.STAT_IDS, StatIds.ALL)
	for t: String in RtCommand.TYPES:
		assert_has(Command.TYPES, t, "Command.TYPES delegates " + t)
	assert_true(real_data().mod_lines("rt_set_quiet").size() == 1, "anchor mod_rt_set_quiet_01 (07 §9.3)")
	assert_eq(real_data().mod_lines("rt_set_quiet")[0].id, "mod_rt_set_quiet_01")
	var types: Array = ActionEvent.Type.keys()
	var end: int = types.find("BATTLE_END")
	assert_eq(types.slice(end + 1), Array(NEW_EVENT_TYPES), "new event types appended after BATTLE_END")
	assert_eq(end, 27, "existing event values stay stable (BATTLE_END is the 28th)")


func test_rt_balance_file_and_defaults() -> void:
	var raw: Variant = JsonUtil.read_file("res://data/rt_balance.json")
	assert_eq(RtBalance.validate(raw), PackedStringArray(), "data/rt_balance.json valid (V1, V14)")
	assert_eq((raw as Dictionary)["values"], RtBalance.DEFAULTS, "start values = 07 §3.16")
	assert_eq(RtBalance.DEFAULTS.keys().size(), RtBalance.RANGES.keys().size())
	var bal: RtBalance = RtBalance.from_data(real_data())
	assert_eq(bal.values, RtBalance.DEFAULTS)
	assert_eq([bal.i("GCD_TICKS"), bal.sub("SET_R_CM", "boss"), bal.sub("REACT_TICKS", "careful")], [45, 600, 6])
	assert_eq(RtBalance.from_data(null).values, RtBalance.DEFAULTS, "no data → defaults")
	var bad: Dictionary = (raw as Dictionary).duplicate(true)
	bad["values"]["TICKS_PER_SEC"] = 60
	bad["values"]["GCD_TICKS"] = 1.5
	(bad["values"] as Dictionary).erase("MAX_PARTY")
	bad["values"]["NEW_KEY"] = 1
	(bad["values"]["SET_R_CM"] as Dictionary)["huge"] = 5
	var errs: PackedStringArray = RtBalance.validate(bad)
	for want: String in ["TICKS_PER_SEC: out of range", "GCD_TICKS: integer expected", "MAX_PARTY: missing key",
			"NEW_KEY: unknown key", "SET_R_CM.huge: unknown key"]:
		assert_true(Array(errs).any(func(e: String) -> bool: return e.contains(want)), want + " in " + str(errs))


# --- data: rt normalization ---------------------------------------------------------------------------------------

func test_real_data_has_no_rt_blocks_yet() -> void:
	var d: GameData = real_data()
	for s: SkillDef in d.all_skills():
		assert_eq(s.rt, {}, s.id + ": R4 adds the rt blocks")
	for e: EnemyDef in d.all_enemies():
		assert_eq(e.rt, {}, e.id)
	assert_eq(d.encounter(d.floor_def(1).timer_start_after).show_boss, {}, "no show boss before R4 (E26)")


func test_def_rt_normalization_fills_defaults() -> void:
	var d: GameData = FakeRtSim.load_data()
	assert_true(d.is_valid(), "rt_min fixture loads: " + "; ".join(d.errors))
	var noble: Dictionary = d.skill("skl_mop_noble_flame").rt
	assert_eq([noble["cast_ms"], noble["gcd"], noble["moving_cancels"], noble["power"], noble["mp"]],
		[1500, true, true, 110, 4], "defaults: gcd on, moving cancels a cast, power / mp from the CTB fields")
	assert_eq(noble["impact_ms"], -1, "impact_ms -1 = derived from anim")
	var bite: Dictionary = d.skill("skl_e_bite").rt
	assert_eq(bite["statuses"], [{"id": "sts_poison", "chance_pm": 300, "ms": 6000, "to": "target", "tick_power": 0}])
	assert_eq(bite["moving_cancels"], false)
	var slam: Dictionary = d.skill("skl_e_test_slam").rt
	assert_eq(slam["telegraph"]["count"], 1, "telegraph block filled")
	assert_eq(d.skill("skl_item_antidote").rt["cleanse"], ["sts_poison"], "cleanse defaults to the CTB field")
	assert_eq(d.status("sts_poison").rt["boss_ms_pm"], 1000)
	assert_eq(d.status("sts_stun").rt["stack_mode"], "replace")
	var boss: Dictionary = d.enemy("enm_rt_test_boss").rt
	assert_eq([boss["hp"], boss["dmg_pm"], boss["enrage"]["status"]], [1600, 1000, "sts_enrage"])
	assert_eq(d.enemy("enm_kanalratte").rt["enrage"], {}, "no enrage block → {}")
	var kai: Dictionary = d.party_member("kai").rt
	assert_eq(kai["bar"][0], {"slot": 1, "skill": "skl_kai_heavy_swing", "level": 1, "variant": false,
		"finale": false})
	assert_eq(kai["mp_regen"]["every_ms"], 0)
	assert_eq(d.item("itm_bandage").rt, {"wheel": 1})
	assert_eq(d.encounter("enc_f1_a1_tutorial").rt["tutorial"], ["target", "bar1", "show", "dodge"])
	assert_eq(d.encounter("enc_f1_a2").rt["music"], "")
	assert_true(d.skill("skl_e_test_hex").rt.is_read_only(), "defs stay immutable (02_TECH §4.5)")


# --- commands -----------------------------------------------------------------------------------------------------

func test_rt_command_builders_and_schema() -> void:
	var good: Array[Dictionary] = [RtCommand.ability(3, "p0", "skl_kai_heavy_swing", "e0"),
		RtCommand.target(4, "p0", ""), RtCommand.move(5, "p0", -2400, 2400, 400, -400, 255),
		RtCommand.item(6, "p1", "itm_bandage", "p0"),
		RtCommand.preset(7, "p1", "careful", {"interrupt": true, "potions": false}),
		RtCommand.auto_attack(8, "p0", false), RtCommand.autopilot(9, "p0", true), RtCommand.partner_special(10, "p1"),
		RtCommand.hint(11, "interrupt"), RtCommand.hint(12, "bar1"), RtCommand.speed(850),
		{"t": "move_input", "ct": 1, "u": "p0", "dir": [127, -127], "run": true},
		{"t": "move_batch", "u": "p0", "id0": 4, "s": [[0, 1, 2, 3, 4, 5], [1, 1, 2, 3, 4, 5]]}]
	for c: Dictionary in good:
		assert_eq(RtCommand.validate(c), "", str(c))
		assert_eq(Command.validate(c), "", "Command delegates " + str(c))
	var bad: Array[Dictionary] = [RtCommand.ability(-1, "p0", "x", ""), RtCommand.ability(1, "q0", "x", ""),
		RtCommand.ability(1, "p0", "", ""), RtCommand.target(1, "p0", "zz"), RtCommand.move(1, "p0", 2401, 0, 0, 0, 0),
		RtCommand.move(1, "p0", 0, 0, 401, 0, 0), RtCommand.move(1, "p0", 0, 0, 0, 0, 256),
		RtCommand.preset(1, "p1", "wild", {}), RtCommand.preset(1, "p1", "attack", {"dance": true}),
		RtCommand.auto_attack(1, "p0", true).merged({"on": 1}, true), RtCommand.hint(1, "nope"),
		RtCommand.speed(900), {"t": "move_input", "ct": 1, "u": "p0", "dir": [128, 0], "run": true}]
	for c: Dictionary in bad:
		assert_ne(RtCommand.validate(c), "", "rejected: " + str(c))
		assert_ne(Command.validate(c), "", "Command rejects " + str(c))
	var enc: Dictionary = {"t": "encounter", "enc": "enc_f1_a2", "adv": 0, "group": "f1_g2", "rt": {"v": 1,
		"cell": [2, 1], "ctl": "p0", "party": [{"u": "p0", "p": [0, 300, 0]}, {"u": "p1", "p": [-150, 400, 0]}],
		"groups": [{"group": "f1_g2", "enc": "enc_f1_a2", "lead": [0, -300, 128], "state": "PATROL"}],
		"presets": {"p1": {"preset": "support", "tog": {"interrupt": true, "show": true, "potions": false}}},
		"auto": true, "retarget": true, "open": {}, "diff": "prime"}}
	assert_eq(Command.validate(enc), "", "encounter with the 07 §10.1 rt block")
	var enc_bad: Dictionary = enc.duplicate(true)
	enc_bad["rt"]["v"] = 2
	assert_ne(Command.validate(enc_bad), "")
	enc_bad = enc.duplicate(true)
	enc_bad["rt"]["ctl"] = "e0"
	assert_ne(Command.validate(enc_bad), "", "the controlled unit is a party unit")


func test_no_real_time_combat_path_before_r5a() -> void:
	var data: GameData = real_data()
	var st: GameState = GameState.create_new(data, 0, "Kai", 21, &"prime")
	var sim: RunSim = RunSim.new(data, st, {})
	var rl: RunLog = RunLog.new()
	sim.run_log = rl
	sim.apply({"t": "floor", "floor": 1})
	var cmds: Array[Dictionary] = [RtCommand.ability(0, "p0", "skl_kai_heavy_swing", "e0"), RtCommand.speed(850),
		{"t": "encounter", "enc": data.floor_def(1).timer_start_after, "adv": 0, "group": "", "rt": {"v": 1,
		"cell": [0, 0], "ctl": "p0", "party": [{"u": "p0", "p": [0, 0, 0]}], "groups": [], "presets": {},
		"auto": true, "retarget": true, "open": {}, "diff": "prime"}},
		{"t": "gift", "ct": 3, "gift": Gift.make_dev("chest", "bronze", 100)}]
	for c: Dictionary in cmds:
		var before: int = sim.rejected_cmds.size()
		sim.apply(c)
		assert_eq(sim.rejected_cmds.size(), before + 1, "refused: " + str(c.get("t")))
		if sim.rejected_cmds.size() > before:
			assert_eq(sim.rejected_cmds.back()["reason"], "rt_unavailable")
	assert_null(sim.battle, "no battle started from an rt encounter")
	assert_eq(rl.size(), 1, "nothing but the floor was recorded")
	var forged: RunLog = RunLog.new()
	forged.add_cmd(0, {"t": "floor", "floor": 1}, 1)
	forged.add_cmd(0, RtCommand.ability(0, "p0", "skl_kai_heavy_swing", "e0"), 2)
	var errs: PackedStringArray = forged.validate()
	assert_eq(errs.size(), 1)
	assert_true(errs.size() == 1 and errs[0].contains("outside a real-time combat"), str(errs))
	assert_eq(RunRules.rt_refusal({"t": "rest"}), "")


func test_run_log_combat_checkpoints_and_ct_order() -> void:
	var rl: RunLog = RunLog.new()
	rl.add_checkpoint(10, "a".repeat(64))
	rl.add_checkpoint(12, "b".repeat(64), 0)
	rl.add_checkpoint(12, "c".repeat(64), 300)
	rl.add_checkpoint(12, "d".repeat(64), 300)
	rl.add_checkpoint(12, "e".repeat(64))
	rl.add_checkpoint(12, "f".repeat(64))
	assert_eq(rl.checkpoints(), [{"k": 10, "h": "a".repeat(64)}, {"k": 12, "ct": 0, "h": "b".repeat(64)},
		{"k": 12, "ct": 300, "h": "d".repeat(64)}, {"k": 12, "h": "f".repeat(64)}],
		"combat checkpoints share their k in ct order; the same ct / a state checkpoint again replaces")
	var back: RunLog = RunLog.from_dict(JSON.parse_string(JSON.stringify(rl.to_dict())))
	assert_eq(back.checkpoints(), rl.checkpoints(), "ct survives a JSON round trip")
	assert_eq(back.rejected, 0)
	var order: RunLog = RunLog.new()
	order.add_cmd(0, {"t": "floor", "floor": 1}, 1)
	order.add_cmd(5, {"t": "encounter", "enc": "enc_x", "adv": 0, "group": "", "rt": {"v": 1, "cell": [0, 0],
		"ctl": "p0", "party": [{"u": "p0", "p": [0, 0, 0]}], "groups": [], "presets": {}, "auto": true,
		"retarget": true, "open": {}, "diff": "prime"}}, 2)
	order.add_cmd(5, RtCommand.ability(30, "p0", "skl_a", "e0"), 3)
	order.add_cmd(5, RtCommand.speed(700), 4)
	order.add_cmd(5, RtCommand.target(29, "p0", "e1"), 5)
	order.add_cmd(5, {"t": "rest"}, 6)
	order.add_cmd(5, RtCommand.target(40, "p0", "e1"), 7)
	var errs: PackedStringArray = order.validate()
	assert_eq(errs.size(), 2, str(errs))
	if errs.size() == 2:
		assert_true(errs[0].contains("ct 29 is out of order"), errs[0])
		assert_true(errs[1].contains("outside a real-time combat"), errs[1])
	rl.compact()
	rl.expand()
	assert_eq(rl.checkpoints().size(), 4, "compact / expand stubs change nothing (R5a)")


func test_say_external_refuses_during_a_battle() -> void:
	Game.new_game(0, "Robin", 5)
	Show._last_line_at = -INF
	Game.in_battle = true
	assert_false(Show.say_external("Eine Live-Zeile.", &"mod", "x"), "07 §9.3: no live lines in a battle")
	Game.in_battle = false
	Show._last_line_at = -INF
	assert_true(Show.say_external("Eine Live-Zeile.", &"mod", "x"), "outside a battle as before")


func test_stubs_are_neutral() -> void:
	var data: GameData = real_data()
	assert_null(BattleBridge.make_rt_setup(GameState.create_new(data, 0, "Kai", 1, &"prime"), data, {}, 1))
	assert_null(Game.make_rt_setup({}))
	assert_null(Game.combat)
	assert_eq(Game.combat_submit(RtCommand.ability(0, "p0", "x", "e0")), "finished")
	assert_eq(Game.combat_step(), [] as Array[ActionEvent])
	assert_not_null(Game.end_combat())
	assert_eq(Show.take_pending_gift_rt(null), {})
	assert_eq(StateHash.of_rt(null), "")
	var setup: RtSetup = RtSetup.new()
	var u: RtUnit = RtUnit.new()
	u.id = "p0"
	u.display_name = "Persona"
	setup.units.append(u)
	var sim: RtSim = RtSim.new(setup, data)
	assert_eq(sim.start(), [] as Array[ActionEvent])
	assert_eq(sim.submit(RtCommand.ability(0, "p0", "skl_kai_heavy_swing", "")), "")
	assert_eq(sim.submit(RtCommand.ability(0, "p3", "skl_kai_heavy_swing", "")), "unknown_unit")
	assert_eq(sim.submit({"t": "ability_use"}), "schema")
	assert_eq(sim.submit({"t": "move_input", "ct": 0, "u": "p0", "dir": [0, 1], "run": false}), "grade_b")
	sim.run_to_end(7)
	assert_eq(sim.tick(), 7, "run_to_end stops at max_ticks")
	assert_eq(sim.submit(RtCommand.ability(3, "p0", "skl_kai_heavy_swing", "")), "past_tick")
	var h: String = StateHash.of_rt(sim)
	assert_true(_hex.search(h) != null, h)
	u.display_name = "Jemand anderes"
	assert_eq(StateHash.of_rt(sim), h, "display names are not hashed (08 §2.7 Nr. 5)")
	u.hp = 3
	assert_ne(StateHash.of_rt(sim), h, "unit state is")
	assert_eq(RtMods.validate([]), PackedStringArray())
	assert_eq(RtRules.choose(sim, u), {})
	assert_false(RtTelegraph.new().contains(0, 0))


# --- fake sim + streams -----------------------------------------------------------------------------------------

func test_fake_sim_plays_every_stream() -> void:
	var data: GameData = FakeRtSim.load_data()
	assert_true(data.is_valid(), "; ".join(data.errors))
	var outcomes: Dictionary = {"regular_win": BattleResult.Outcome.VICTORY,
		"boss_phases": BattleResult.Outcome.VICTORY, "flee": BattleResult.Outcome.FLED,
		"ko_control_defeat": BattleResult.Outcome.DEFEAT, "gifts": BattleResult.Outcome.VICTORY}
	for n: String in FakeRtSim.STREAMS:
		var sim: FakeRtSim = FakeRtSim.load_stream(n, data)
		assert_not_null(sim, n)
		if sim == null:
			continue
		var pre: Array[ActionEvent] = sim.start()
		assert_gt(pre.size(), 0, n + ": prelude")
		if not pre.is_empty():
			assert_eq(pre[0].type, ActionEvent.Type.BATTLE_START, n)
		var types: Dictionary = {}
		var boundary: int = 0
		var guard: int = 0
		while not sim.is_finished() and guard < 5000:
			guard += 1
			boundary += sim.apply_gift({"gift_id": "probe"}).size() if n == "gifts" else 0
			for e: ActionEvent in sim.step():
				assert_eq(e.tick, sim.tick() - 1, "%s: event tick = processed tick" % n)
				types[ActionEvent.type_name(e.type)] = true
		assert_true(sim.is_finished(), n + " finishes")
		assert_not_null(sim.result, n + ": result")
		if sim.result != null:
			assert_eq(int(sim.result.outcome), int(outcomes[n]), n + " outcome")
			assert_eq(Array(sim.result.group_ids), [sim.setup.group_id], n + ": group_ids")
			assert_gt(sim.result.duration_ticks, 0, n)
		assert_true(types.has("BATTLE_END"), n)
		assert_true(_hex.search(StateHash.of_rt(sim)) != null, n + ": snapshot hashes")
		match n:
			"regular_win":
				for t: String in ["TARGET_CHANGED", "SWING", "CAST_START", "CAST_INTERRUPTED", "TELEGRAPH_START",
						"TELEGRAPH_IMPACT", "TELEGRAPH_DODGED", "KO", "SECOND", "ACTION_END"]:
					assert_true(types.has(t), "regular_win has " + t)
			"boss_phases":
				for t: String in ["PHASE_CHANGE", "SUMMON", "TELEGRAPH_IMPACT", "ENRAGE", "STUNT_RESULT"]:
					assert_true(types.has(t), "boss_phases has " + t)
				assert_eq(sim.result.train_kills, 2)
			"flee":
				assert_true(types.has("FLEE_WARNING") and types.has("FLEE_RESULT"), "flee events")
			"ko_control_defeat":
				assert_eq(sim.controlled_id(), "p1", "control followed life")
				assert_true(types.has("CONTROL_CHANGED"))
			"gifts":
				assert_eq(boundary, 4, "two gifts at the boundaries of ticks 40 and 41 (SPONSOR_GIFT + HEAL each)")
				assert_eq(sim.gifts_applied.size(), sim.tick(), "every boundary offered a gift")


func test_fake_sim_logs_commands_and_answers_queries() -> void:
	var data: GameData = FakeRtSim.load_data()
	var sim: FakeRtSim = FakeRtSim.load_stream("regular_win", data)
	if sim == null:
		fail("stream missing")
		return
	sim.start()
	assert_eq(sim.units().size(), 5)
	assert_eq(sim.unit("p0").driver, RtUnit.Driver.PLAYER)
	assert_eq(sim.unit("p0").display_name, "Kai", "the Def name, never a persona name")
	assert_eq(sim.submit(RtCommand.ability(0, "p0", "skl_kai_heavy_swing", "e0")), "")
	for _i in 31:
		sim.step()
	assert_eq(sim.cast_progress("e2"), Vector2i(1, 60), "the caster's bar from the snapshot overlay")
	assert_eq(sim.submit(RtCommand.target(0, "p0", "e1")), "past_tick")
	assert_eq(sim.submit({"t": "move_input", "ct": 40, "u": "p0", "dir": [0, 1], "run": true}), "grade_b")
	assert_eq(sim.submitted.size(), 3)
	assert_eq(sim.submitted[1]["answer"], "past_tick")
	assert_eq(sim.bar("p0"), {1: "skl_kai_heavy_swing", 3: "skl_kai_leash_trip", 5: "skl_stunt_kai_suplex"})


func test_streams_match_their_builder() -> void:
	var builder: Object = (load(BUILDER) as GDScript).new(FakeRtSim.load_data())
	var built: Dictionary = builder.call("build_all")
	for n: String in FakeRtSim.STREAMS:
		var text: String = FileAccess.get_file_as_string(FakeRtSim.STREAM_DIR.path_join(n + ".json"))
		assert_eq(text, (load(BUILDER) as GDScript).call("to_text", built[n]),
			n + ".json is the builder's output (regenerate: tests/tools/make_rt_streams.gd)")
