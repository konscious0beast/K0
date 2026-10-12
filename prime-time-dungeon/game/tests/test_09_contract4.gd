extends TestCase
## 09 contract pass 4 (ST1-A, 2026-10-12; 02_TECH §0.8 "Stand Vertrag 4"): the schema hooks ST1-C (floors.json: a
## Kulisse as `theme`, `variant`, `level_band`, `zones`), ST1-D (talents.json: the talent tree `row`, `col`, `tree`,
## `spec` and the kind rt_mod; classes.json: `rt` with the class bar and the ranks; party.json: `exp_table`) and ST1-F
## (the class template of a guest: classes.json `rt.bar`) build on. Every field is optional with a default that changes
## nothing: the real data loads as before, a talent of the tree never reaches the Talent-Show, and only a season lifts
## SaveCodec's level cap from 10 to 50. Checked here: signatures, fields and constants, the defaults, one valid sample
## of every hook, broken samples with their messages, the 06-B pool and the season-aware level cap. What needs a line
## in core/rt/** or scenes/combat/** (the guest unit p2, enemy_level_pm, the words of the combat HUD) is a change
## request (07 CR-32 c, d, i; 09 §11.7), not code.

const R1A := preload("res://tests/test_r1a_contract.gd")
const FloorSeasonCheck := preload("res://core/data/validators/floor_season.gd")
const LevelsCheck := preload("res://core/data/validators/levels.gd")
const TalentsRules := preload("res://core/data/validators/talents.gd")
const RtCheck := preload("res://core/data/validators/rt.gd")
const DAY0: int = 1791921600
const ERASE: String = "<erase>"              # a mutation value: remove the key
const APPEND: String = "+"                   # a mutation path step: append to the array

## script path → expected method signatures ("name(arg types) -> return[ static]"; "=" marks a default argument).
const METHODS: Dictionary = {
	"res://core/progression/save_codec.gd": ["level_cap(GameState) -> int static"],
	"res://core/data/game_data.gd": ["exp_table() -> PackedInt32Array", "talents_for(String) -> Array[TalentDef]"],
	"res://core/data/defs/floor_def.gd": ["kulisse() -> String", "has_zones() -> bool", "has_band() -> bool"],
	"res://core/data/defs/talent_def.gd": ["is_tree() -> bool", "tree_rows() -> PackedInt32Array static"],
	"res://core/data/validators/floor_season.gd": ["is_kulisse(String) -> bool static",
		"is_zone_floor(Dictionary) -> bool static",
		"normalize(DataValidator, String, Dictionary, Dictionary) -> void static",
		"zone_ids(Dictionary) -> PackedStringArray static", "check(DataValidator) -> void static"],
	"res://core/data/validators/levels.gd": ["read_exp_table(DataValidator, Dictionary) -> void static"],
	"res://core/data/validators/talents.gd": [
		"normalize_effect(DataValidator, String, Variant, bool=, String=) -> Dictionary static"],
}

## script path → property → type.
const PROPERTIES: Dictionary = {
	"res://core/data/defs/floor_def.gd": {"theme": "String", "variant": "int", "level_band": "PackedInt32Array",
		"zones": "Array[Dictionary]"},
	"res://core/data/defs/talent_def.gd": {"row": "int", "col": "int", "tree": "String", "spec": "String"},
	"res://core/data/defs/class_def.gd": {"rt": "Dictionary"},
}

## Two full rows of the talent tree: Kai's base row 3 and the class row 15 of cls_kai_wrecker (branches abriss, statik).
const TREE: Array = [
	{"id": "tal_tree_kai_3_a", "name": "Doppelwisch", "for": ["kai"], "icon": "atk", "row": 3, "col": 1,
		"tree": "kai", "effects": [{"kind": "stat_flat", "stat": "str", "value": 2}]},
	{"id": "tal_tree_kai_3_b", "name": "Bahnsteigkante", "for": ["kai"], "icon": "spd", "row": 3, "col": 2,
		"tree": "kai", "effects": [{"kind": "rt_mod", "op": "move_pm", "pm": 1100}]},
	{"id": "tal_tree_kai_3_c", "name": "Dicke Jacke", "for": ["kai"], "icon": "def", "row": 3, "col": 3,
		"tree": "kai", "effects": [{"kind": "stat_pct", "stat": "def", "pm": 80}]},
	{"id": "tal_tree_wrk_15_a", "name": "Abrissbirne", "for": ["kai"], "icon": "atk", "min_level": 15, "row": 15,
		"col": 1, "tree": "cls_kai_wrecker", "spec": "abriss", "effects": [{"kind": "rt_mod", "op": "skill_pm",
		"skill": "skl_kai_heavy_swing", "field": "power", "pm": 1150}]},
	{"id": "tal_tree_wrk_15_b", "name": "Bauleitung", "for": ["kai"], "icon": "crit", "min_level": 15, "row": 15,
		"col": 2, "tree": "cls_kai_wrecker", "effects": [{"kind": "crit_add_pm", "pm": 40}]},
	{"id": "tal_tree_wrk_15_c", "name": "Statik", "for": ["kai"], "icon": "def", "min_level": 15, "row": 15,
		"col": 3, "tree": "cls_kai_wrecker", "spec": "statik", "effects": [{"kind": "rt_mod", "op": "on",
		"event": "kill", "effect": {"status": "sts_guard"}}]},
]

## The class bar and ranks of the sample (cls_kai_wrecker): a variant of slot 3 from 15, a FINALE from 25, Rang II–IV.
const CLASS_RT: Dictionary = {
	"bar": [{"slot": 3, "skill": "skl_kai_cable_whip", "level": 15, "variant": true},
		{"slot": 5, "skill": "skl_kai_prime_finisher", "level": 25, "finale": true}],
	"ranks": [{"level": 20, "pm": 1100}, {"level": 30, "pm": 1200}, {"level": 40, "pm": 1300}]}

## Floor 2's two quarters in the sample: the second one with the default rooms (10–14) and pool ([]).
const ZONES: Array = [
	{"id": "zone_f2_eingang", "name": "Eingangshalle", "rooms": {"min": 8, "max": 11},
		"pool": ["enc_f2_puppen", "enc_f2_wagen"]},
	{"id": "zone_f2_food", "name": "Food Court", "palette": {"accent": "#ffaa00"}}]

const PROBE_ZONE: Dictionary = {"id": "zone_probe_a", "name": "Probe A"}
const FIVE_ZONES: Array = [{"id": "zone_probe_1", "name": "Probe 1", "rooms": {"min": 3, "max": 4}},
	{"id": "zone_probe_2", "name": "Probe 2", "rooms": {"min": 3, "max": 4}},
	{"id": "zone_probe_3", "name": "Probe 3", "rooms": {"min": 3, "max": 4}},
	{"id": "zone_probe_4", "name": "Probe 4", "rooms": {"min": 3, "max": 4}},
	{"id": "zone_probe_5", "name": "Probe 5", "rooms": {"min": 3, "max": 4}}]
const PROBE_BOSS: Dictionary = {"id": "enc_f2_probe_boss", "enemies": ["enm_rabattschild"], "boss": true}
const PROBE_ROW_25: Dictionary = {"id": "tal_tree_wrk_25_a", "name": "Nachbeben", "for": ["kai"], "icon": "atk",
	"min_level": 25, "row": 25, "col": 1, "tree": "cls_kai_wrecker", "spec": "statik",
	"effects": [{"kind": "crit_add_pm", "pm": 20}]}

## Broken samples: {"want": a part of the expected message, "set": [[table, entry id ("" = the file object), path
## inside it (APPEND appends), value (ERASE removes the key)], …]} — each on a fresh copy of the valid sample.
const BROKEN: Array[Dictionary] = [
	# floors.json (ST1-C)
	{"want": "floor_2].variant: out of range 0..3 (got 4)", "set": [["floors", "floor_2", ["variant"], 4]]},
	{"want": "floor_2].variant: floor 2 is place 1 of its Kulisse 'thm_passage' (got 2)",
		"set": [["floors", "floor_2", ["variant"], 2]]},
	{"want": "floor_2].variant: floor 2 is in no Kulisse (themes.json floors)",
		"set": [["themes", "thm_passage", ["floors"], []], ["floors", "floor_2", ["theme"], "mall"]]},
	{"want": "floor_2].theme: unknown Kulisse (themes.json) 'thm_nirgendwo'",
		"set": [["floors", "floor_2", ["theme"], "thm_nirgendwo"]]},
	{"want": "floor_2].theme: Kulisse 'thm_unterstadt' does not list floor 2 (themes.json floors)",
		"set": [["floors", "floor_2", ["theme"], "thm_unterstadt"]]},
	{"want": "floor_2].theme: 'dschungel' not in", "set": [["floors", "floor_2", ["theme"], "dschungel"]]},
	{"want": "floor_2].level_band: [] or [from, to] (got 1 numbers)",
		"set": [["floors", "floor_2", ["level_band"], [5]]]},
	{"want": "floor_2].level_band: needs 1 <= from <= to <= 50 (got [6, 3])",
		"set": [["floors", "floor_2", ["level_band"], [6, 3]]]},
	{"want": "floor_2].level_band: needs 1 <= from <= to <= 50 (got [40, 51])",
		"set": [["floors", "floor_2", ["level_band"], [40, 51]]]},
	{"want": "floor_2].level_band: falls below the band of floor 1 ([5, 9] → [3, 6])",
		"set": [["floors", "floor_1", ["level_band"], [5, 9]]]},
	{"want": "floor_1].zones: only for procedural floors (a hand-built layout has its own zones)",
		"set": [["floors", "floor_1", ["zones"], [PROBE_ZONE, {"id": "zone_probe_b", "name": "Probe B"}]]]},
	{"want": "floor_2].zones: needs 2..4 quarters (got 1)", "set": [["floors", "floor_2", ["zones"], [PROBE_ZONE]]]},
	{"want": "floor_2].zones: needs 2..4 quarters (got 5)", "set": [["floors", "floor_2", ["zones"], FIVE_ZONES]]},
	{"want": "zones[1|zone_f2_eingang].id: 'zone_f2_eingang' twice on this floor",
		"set": [["floors", "floor_2", ["zones", 1, "id"], "zone_f2_eingang"]]},
	{"want": "invalid id 'viertel_eins' (pattern ^zone_[a-z0-9_]+$)",
		"set": [["floors", "floor_2", ["zones", 1, "id"], "viertel_eins"]]},
	{"want": "zone_f2_food].name: 1..32 characters", "set": [["floors", "floor_2", ["zones", 1, "name"], ""]]},
	{"want": "zone_f2_food].rooms: needs 1 <= min <= max <= 30",
		"set": [["floors", "floor_2", ["zones", 1, "rooms"], {"min": 0, "max": 5}]]},
	{"want": "floor_2].zones: the quarters' rooms (4..6) miss the floor's rooms (16..22)",
		"set": [["floors", "floor_2", ["zones", 0, "rooms"], {"min": 2, "max": 3}],
			["floors", "floor_2", ["zones", 1, "rooms"], {"min": 2, "max": 3}]]},
	{"want": "floor_2].safe_rooms: at most one safe room per quarter (2 quarters)",
		"set": [["floors", "floor_2", ["safe_rooms"], 3]]},
	{"want": "floor_2].safe_rooms: out of range 0..4 (got 5)", "set": [["floors", "floor_2", ["safe_rooms"], 5]]},
	{"want": "floor_2].grid.w: out of range 3..12 (got 13)", "set": [["floors", "floor_2", ["zones"], ERASE]]},
	{"want": "zones[zone_f2_eingang].pool: 'enc_f1_a2' is no encounter of this floor",
		"set": [["floors", "floor_2", ["zones", 0, "pool"], ["enc_f1_a2"]]]},
	{"want": "zones[zone_f2_eingang].pool: 'enc_f2_probe_boss' is a boss (bosses have their own rooms)",
		"set": [["floors", "floor_2", ["encounters", APPEND], PROBE_BOSS],
			["floors", "floor_2", ["zones", 0, "pool"], ["enc_f2_probe_boss"]]]},
	{"want": "zone_f2_eingang].danger: unknown key", "set": [["floors", "floor_2", ["zones", 0, "danger"], 2]]},
	{"want": "zone_f2_food].palette.glow: unknown palette key",
		"set": [["floors", "floor_2", ["zones", 1, "palette", "glow"], "#ffffff"]]},
	# talents.json (ST1-D)
	{"want": "tal_tree_kai_3_a].row: 4 is no row of the talent tree",
		"set": [["talents", "tal_tree_kai_3_a", ["row"], 4], ["talents", "tal_tree_kai_3_a", ["min_level"], 4]]},
	{"want": "tal_tree_kai_3_c].col: out of range 1..3 (got 4)", "set": [["talents", "tal_tree_kai_3_c", ["col"], 4]]},
	{"want": "tal_tree_kai_3_a].tree: a tree talent names its tree",
		"set": [["talents", "tal_tree_kai_3_a", ["tree"], ""]]},
	{"want": "tal_tree_kai_3_a].max_rank: 1 in the talent tree",
		"set": [["talents", "tal_tree_kai_3_a", ["max_rank"], 2]]},
	{"want": "tal_tree_wrk_15_b].min_level: the level of its row (15)",
		"set": [["talents", "tal_tree_wrk_15_b", ["min_level"], 3]]},
	{"want": "tal_tree_wrk_15_a].spec: the outer columns of a class row carry the class's branch",
		"set": [["talents", "tal_tree_wrk_15_a", ["spec"], ERASE]]},
	{"want": "tal_tree_kai_3_a].spec: a branch only on the left / right column of a class row",
		"set": [["talents", "tal_tree_kai_3_a", ["spec"], "abriss"]]},
	{"want": "tal_tree_wrk_15_b].spec: a branch only on the left / right column of a class row",
		"set": [["talents", "tal_tree_wrk_15_b", ["spec"], "mitte"]]},
	{"want": "tal_tree_wrk_15_c].spec: invalid branch id 'Statik!'",
		"set": [["talents", "tal_tree_wrk_15_c", ["spec"], "Statik!"]]},
	{"want": "tal_kai_wischtechnik].col: only for a talent of the talent tree (row > 0, 09 §8.4)",
		"set": [["talents", "tal_kai_wischtechnik", ["col"], 2]]},
	{"want": "tal_kai_wischtechnik].effects[1].kind: 'rt_mod' only for a talent of the talent tree",
		"set": [["talents", "tal_kai_wischtechnik", ["effects", APPEND], {"kind": "rt_mod", "op": "move_pm",
			"pm": 1100}]]},
	{"want": "tal_tree_kai_3_b].effects[0].op: 'extra_enemy' not in [stat_pm",
		"set": [["talents", "tal_tree_kai_3_b", ["effects", 0], {"kind": "rt_mod", "op": "extra_enemy",
			"enemy": "enm_rabattschild", "count": 1}]]},
	{"want": "tal_tree_kai_3_b].effects[0].pm: 6000 outside 0..5000",
		"set": [["talents", "tal_tree_kai_3_b", ["effects", 0, "pm"], 6000]]},
	{"want": "tal_tree_kai_3_b].effects[0].unit: set by the talent",
		"set": [["talents", "tal_tree_kai_3_b", ["effects", 0, "unit"], "party"]]},
	{"want": "tal_tree_wrk_15_a].effects[0].skill: unknown skill 'skl_gibts_nicht'",
		"set": [["talents", "tal_tree_wrk_15_a", ["effects", 0, "skill"], "skl_gibts_nicht"]]},
	{"want": "tal_tree_wrk_15_c].effects[0].effect.status: unknown status 'sts_gibts_nicht'",
		"set": [["talents", "tal_tree_wrk_15_c", ["effects", 0, "effect", "status"], "sts_gibts_nicht"]]},
	{"want": "tal_tree_kai_3_a].effects[0].value: out of range 1..6 (got 7)",
		"set": [["talents", "tal_tree_kai_3_a", ["effects", 0, "value"], 7]]},
	{"want": "tal_kai_wischtechnik].effects[0].value: out of range 1..3 (got 4)",
		"set": [["talents", "tal_kai_wischtechnik", ["effects", 0, "value"], 4]]},
	{"want": "tal_tree_kai_3_a].for: a talent of kai's tree is for [\"kai\"] (got [\"mopsula\"])",
		"set": [["talents", "tal_tree_kai_3_a", ["for"], ["mopsula"]]]},
	{"want": "tal_tree_kai_3_a].tree: unknown party member 'niemand'",
		"set": [["talents", "tal_tree_kai_3_a", ["tree"], "niemand"]]},
	{"want": "tal_tree_wrk_15_a].tree: unknown class 'cls_gibts_nicht'",
		"set": [["talents", "tal_tree_wrk_15_a", ["tree"], "cls_gibts_nicht"]]},
	{"want": "tal_tree_wrk_15_b].for: a class row talent names its members (those of class 'cls_kai_wrecker')",
		"set": [["talents", "tal_tree_wrk_15_b", ["for"], []]]},
	{"want": "tal_tree_wrk_15_b].for: class 'cls_kai_wrecker' is not for 'mopsula'",
		"set": [["talents", "tal_tree_wrk_15_b", ["for"], ["mopsula"]]]},
	{"want": "tal_tree_kai_3_b].col: row 3 column 1 of 'kai' is taken by 'tal_tree_kai_3_a'",
		"set": [["talents", "tal_tree_kai_3_b", ["col"], 1]]},
	{"want": "talents: row 3 of the tree 'kai' needs all 3 columns",
		"set": [["talents", "tal_tree_kai_3_c", ["tree"], "mopsula"], ["talents", "tal_tree_kai_3_c", ["for"],
			["mopsula"]]]},
	{"want": "talents: 'cls_kai_wrecker': the left and the right column are two branches (both 'abriss')",
		"set": [["talents", "tal_tree_wrk_15_c", ["spec"], "abriss"]]},
	{"want": "tal_tree_wrk_25_a].spec: column 1 of 'cls_kai_wrecker' is the branch 'abriss' (got 'statik')",
		"set": [["talents", "", ["entries", APPEND], PROBE_ROW_25]]},
	# classes.json (07 CR-32 a, ST1-D)
	{"want": "cls_kai_wrecker].rt.guest: unknown key", "set": [["classes", "cls_kai_wrecker", ["rt", "guest"], {}]]},
	{"want": "cls_kai_wrecker].rt.bar[0].slot: out of range 1…5 (V3, got 6)",
		"set": [["classes", "cls_kai_wrecker", ["rt", "bar", 0, "slot"], 6]]},
	{"want": "cls_kai_wrecker].rt.bar[0].level: out of range 1…50 (V3, got 51)",
		"set": [["classes", "cls_kai_wrecker", ["rt", "bar", 0, "level"], 51]]},
	{"want": "cls_kai_wrecker].rt.bar[0].skill: 'skl_e_strike' is no party skill (V8)",
		"set": [["classes", "cls_kai_wrecker", ["rt", "bar", 0, "skill"], "skl_e_strike"]]},
	{"want": "cls_kai_wrecker].rt.bar[1].skill: 'skl_kai_cable_whip' twice on the class bar",
		"set": [["classes", "cls_kai_wrecker", ["rt", "bar", 1, "skill"], "skl_kai_cable_whip"]]},
	{"want": "cls_kai_wrecker].rt.bar[0].finale: only in slot 5 (V8)",
		"set": [["classes", "cls_kai_wrecker", ["rt", "bar", 0, "finale"], true]]},
	{"want": "cls_kai_wrecker].rt.bar[0].variant: a class ability is a variant (or the FINALE) of a slot",
		"set": [["classes", "cls_kai_wrecker", ["rt", "bar", 0, "variant"], false]]},
	{"want": "cls_kai_wrecker].rt.bar[0].cast_ms: unknown key",
		"set": [["classes", "cls_kai_wrecker", ["rt", "bar", 0, "cast_ms"], 500]]},
	{"want": "cls_kai_wrecker].rt.ranks: at most 3 ranks (Rang II–IV, 09 §8.3; got 4)",
		"set": [["classes", "cls_kai_wrecker", ["rt", "ranks", APPEND], {"level": 50, "pm": 1400}]]},
	{"want": "cls_kai_wrecker].rt.ranks[0].pm: out of range 1001…2000 (V3, got 1000)",
		"set": [["classes", "cls_kai_wrecker", ["rt", "ranks", 0, "pm"], 1000]]},
	{"want": "cls_kai_wrecker].rt.ranks[1]: level and pm rise from rank to rank",
		"set": [["classes", "cls_kai_wrecker", ["rt", "ranks", 1, "level"], 20]]},
	{"want": "cls_kai_wrecker].rt.ranks[0].name: unknown key",
		"set": [["classes", "cls_kai_wrecker", ["rt", "ranks", 0, "name"], "Rang II"]]},
]

var _sample_raw: Dictionary = {}


# --- helpers ----------------------------------------------------------------------------------------------------------

## The parsed data files (file objects) as GameData.load_from_tables takes them.
static func _raw_tables() -> Dictionary:
	var raw: Dictionary = {}
	for t: String in GameData.TABLES:
		raw[t] = JsonUtil.read_file("res://data/%s.json" % t)
	raw["rt_balance"] = JsonUtil.read_file("res://data/" + GameData.RT_BALANCE_FILE)
	return raw


## The entry `id` of `table` in the raw tables `raw` ({} if missing); id "" = the file object itself.
static func _entry(raw: Dictionary, table: String, id: String) -> Dictionary:
	if id == "":
		return raw[table]
	for e: Variant in ((raw[table] as Dictionary)["entries"] as Array):
		if e is Dictionary and str((e as Dictionary).get("id", "")) == id:
			return e
	return {}


## A level curve for the samples: levels 1–9 as GDD §4.3 (Progression.EXP_TABLE), then + 150 per level (49 entries).
static func _exp_curve() -> Array:
	var out: Array = Array(Progression.EXP_TABLE)
	while out.size() < Balance.SEASON_LEVEL_CAP - 1:
		out.append(int(out.back()) + 150)
	return out


## The real data plus one sample of every hook (a fresh deep copy): floor 2 in its own Kulisse thm_passage (place 1,
## band 3–6, two quarters on a 13 × 13 grid), floor 1 banded 1–3 at place 1 of thm_unterstadt, the level curve to 50,
## cls_kai_wrecker's class bar with three ranks and two full rows of the talent tree (TREE). Since 09 ST1-D the real
## data carry their own tree: the samples stand alone, so the real tree rows (talents with "row") are left out here.
func _sample() -> Dictionary:
	if _sample_raw.is_empty():
		var raw: Dictionary = _raw_tables()
		var pool: Array = []
		for e: Variant in ((raw["talents"] as Dictionary)["entries"] as Array):
			if not (e as Dictionary).has("row"):
				pool.append(e)
		(raw["talents"] as Dictionary)["entries"] = pool
		((raw["themes"] as Dictionary)["entries"] as Array).append({"id": "thm_passage", "name": "Die Passage",
			"floors": [2], "program": []})
		var f1: Dictionary = _entry(raw, "floors", "floor_1")
		f1.merge({"variant": 1, "level_band": [1, 3]}, true)
		var f2: Dictionary = _entry(raw, "floors", "floor_2")
		f2.merge({"theme": "thm_passage", "variant": 1, "level_band": [3, 6], "grid": {"w": 13, "h": 13},
			"zones": ZONES.duplicate(true)}, true)
		(raw["party"] as Dictionary)["exp_table"] = _exp_curve()
		_entry(raw, "classes", "cls_kai_wrecker").merge({"rt": CLASS_RT.duplicate(true)}, true)
		((raw["talents"] as Dictionary)["entries"] as Array).append_array(TREE.duplicate(true))
		_sample_raw = raw
	return _sample_raw.duplicate(true)


## Applies one mutation [table, id, path, value] of BROKEN to the raw tables `raw`.
static func _mutate(raw: Dictionary, m: Array) -> void:
	var node: Variant = _entry(raw, str(m[0]), str(m[1]))
	var path: Array = m[2]
	for i in path.size() - 1:
		node = (node as Dictionary)[path[i]] if node is Dictionary else (node as Array)[int(path[i])]
	var key: Variant = path.back()
	var value: Variant = m[3]
	if value is Dictionary or value is Array:
		value = (value as Dictionary).duplicate(true) if value is Dictionary else (value as Array).duplicate(true)
	if node is Array:
		if str(key) == APPEND:
			(node as Array).append(value)
		else:
			(node as Array)[int(key)] = value
	elif value is String and str(value) == ERASE:
		(node as Dictionary).erase(key)
	else:
		(node as Dictionary)[key] = value


func _load(raw: Dictionary) -> GameData:
	var data: GameData = GameData.new()
	assert_true(data.load_from_tables(raw), "the sample loads: " + "; ".join(data.errors))
	return data


func _season() -> SeasonState:
	var s: SeasonState = SeasonState.new()
	s.def_id = "ssn_basis"
	s.number = 1
	s.day0_utc = DAY0
	s.utc = DAY0 + 60
	s.seen_unix = DAY0 + 60
	return s


# --- signatures, fields, constants ------------------------------------------------------------------------------------

func test_contract4_signatures_and_fields() -> void:
	for path: String in METHODS.keys():
		var have: Dictionary = R1A._own_methods(load(path) as GDScript)
		for want: String in METHODS[path]:
			var name: String = want.substr(0, want.find("("))
			assert_eq(have.get(name, "<missing>"), want, "%s :: %s" % [path.get_file(), name])
	for path: String in PROPERTIES.keys():
		var props: Dictionary = R1A._props(load(path) as GDScript)
		var want_props: Dictionary = PROPERTIES[path]
		for prop: String in want_props.keys():
			assert_eq(props.get(prop, "<missing>"), want_props[prop], "%s :: %s" % [path.get_file(), prop])


func test_contract4_constants() -> void:
	assert_eq([Balance.LEVEL_CAP, Balance.SEASON_LEVEL_CAP], [10, 50], "09 §8.2: 10 outside a season, 50 inside")
	assert_eq([DataValidator.LEVEL_CAP, DataValidator.SEASON_LEVEL_CAP], [Balance.LEVEL_CAP, Balance.SEASON_LEVEL_CAP],
		"core/data keeps copies of the caps")
	assert_eq(LevelsCheck.GDD_EXP, Progression.EXP_TABLE, "levels 1–9 of exp_table keep the GDD §4.3 curve")
	assert_eq(DataValidator.TABLE_EXTRA_KEYS["party"], ["start", "exp_table"])
	assert_eq(TalentDef.tree_rows(), PackedInt32Array([3, 5, 7, 9, 15, 20, 25, 30, 35, 40, 45, 50]), "09 §8.4")
	assert_eq([TalentDef.COLS, TalentDef.TREE_KINDS], [3, PackedStringArray(["rt_mod"])])
	for op: String in TalentsRules.TREE_MOD_OPS:
		assert_has(RtVocab.MOD_OPS, op, "an rt_mod op is a RtMods op")
	for src: String in ["class", "talent"]:
		assert_has(RtVocab.MOD_SOURCES, src, "07 CR-32 b: class:<id> and talent:<id>")
	assert_eq([FloorSeasonCheck.KULISSE_PREFIX, FloorDef.KULISSE_PREFIX], ["thm_", "thm_"])
	assert_eq(DataValidator.ID_PATTERNS["themes"], "^%s[a-z0-9_]+$" % FloorDef.KULISSE_PREFIX)
	assert_eq([FloorSeasonCheck.ZONE_GRID_MAX, FloorSeasonCheck.ZONE_SAFE_ROOMS_MAX], [13, 4], "09 §3.6")
	assert_eq([FloorSeasonCheck.ZONES_MIN, FloorSeasonCheck.ZONES_MAX, FloorSeasonCheck.VARIANT_MAX], [2, 4, 3])
	assert_eq([RtCheck.CLASS_RANKS_MAX, RtCheck.CLASS_RANK_PM], [3, Vector2i(1001, 2000)], "Rang II–IV (09 §8.3)")
	var specs: Array = []
	for row: Array in ClassDef.RT_SPEC + ClassDef.RT_RANK_SPEC:
		specs.append(row[0])
	assert_eq(specs, ["bar", "ranks", "level", "pm"])


# --- the defaults change nothing --------------------------------------------------------------------------------------

func test_real_data_keeps_the_defaults() -> void:
	var data: GameData = real_data()
	var raw: Dictionary = _raw_tables()
	for f: FloorDef in data.all_floors():
		var e: Dictionary = _entry(raw, "floors", f.id)
		if not e.has("variant"):
			assert_eq(f.variant, 0, f.id)
		if not e.has("level_band"):
			assert_false(f.has_band(), f.id)
		if not e.has("zones"):
			assert_false(f.has_zones(), f.id)
		if not FloorSeasonCheck.is_kulisse(f.theme):
			assert_eq(f.kulisse(), "", f.id)
	for t: TalentDef in data.all_talents():
		if not _entry(raw, "talents", t.id).has("row"):
			assert_eq([t.row, t.col, t.tree, t.spec, t.is_tree()], [0, 0, "", "", false], t.id)
	for c: ClassDef in data.all_classes():
		if not _entry(raw, "classes", c.id).has("rt"):
			assert_eq(c.rt, {}, c.id)
	if not (raw["party"] as Dictionary).has("exp_table"):
		assert_eq(data.exp_table(), PackedInt32Array(), "no exp_table: [] (Progression.EXP_TABLE rules)")


# --- the valid samples ------------------------------------------------------------------------------------------------

func test_season_samples_load() -> void:
	var data: GameData = _load(_sample())
	var f1: FloorDef = data.floor_def(1)
	assert_eq([f1.theme, f1.kulisse(), f1.variant, f1.level_band], ["metro", "", 1, PackedInt32Array([1, 3])],
		"an art theme stays; the Kulisse lists the floor in themes.json")
	var f2: FloorDef = data.floor_def(2)
	assert_eq([f2.kulisse(), f2.variant, f2.level_band, f2.has_zones()],
		["thm_passage", 1, PackedInt32Array([3, 6]), true])
	assert_eq(f2.grid, {"w": 13, "h": 13}, "a floor with quarters may use 13 × 13")
	assert_eq(f2.zones.size(), 2)
	assert_eq(f2.zones[0]["pool"], PackedStringArray(["enc_f2_puppen", "enc_f2_wagen"]))
	assert_eq([f2.zones[1]["rooms"], f2.zones[1]["pool"], f2.zones[1]["palette"]],
		[{"min": 10, "max": 14}, PackedStringArray(), {"accent": "#ffaa00"}], "the quarter defaults")
	assert_eq(f2.palette, real_data().floor_def(2).palette, "floor 2 names its colours: a Kulisse as theme changes none")
	var curve: PackedInt32Array = data.exp_table()
	assert_eq(curve.size(), 49)
	assert_eq(curve.slice(0, 9), Progression.EXP_TABLE)
	curve[0] = 1
	assert_eq(data.exp_table()[0], 33, "exp_table() is a copy")
	var cls: ClassDef = data.class_def("cls_kai_wrecker")
	assert_eq((cls.rt["bar"] as Array).size(), 2)
	assert_eq(cls.rt["bar"][0], {"slot": 3, "skill": "skl_kai_cable_whip", "level": 15, "variant": true,
		"finale": false}, "a bar row gets every field of the party bar schema")
	assert_eq(cls.rt["ranks"], [{"level": 20, "pm": 1100}, {"level": 30, "pm": 1200}, {"level": 40, "pm": 1300}])
	var t: TalentDef = data.talent("tal_tree_wrk_15_c")
	assert_eq([t.row, t.col, t.tree, t.spec, t.is_tree(), t.max_rank], [15, 3, "cls_kai_wrecker", "statik", true, 1])
	assert_eq(t.effects[0], {"kind": "rt_mod", "op": "on", "event": "kill", "effect": {"status": "sts_guard"}})
	assert_eq(data.talent("tal_tree_kai_3_a").effects[0]["value"], 2, "a tree talent may hold two ranks in one")


func test_tree_talents_never_reach_the_talent_show() -> void:
	var data: GameData = _load(_sample())
	var tree: int = 0
	for t: TalentDef in data.all_talents():
		tree += 1 if t.is_tree() else 0
	assert_eq(tree, TREE.size())
	for mid: String in ["kai", "mopsula"]:
		var ids: PackedStringArray = []
		for t: TalentDef in data.talents_for(mid):
			ids.append(t.id)
		var real_ids: PackedStringArray = []
		for t: TalentDef in real_data().talents_for(mid):
			real_ids.append(t.id)
		assert_eq(ids, real_ids, "the 06-B pool of %s is the same with the tree" % mid)
	for seed: int in [1, 7, 4242]:
		var st: GameState = GameState.create_new(data, 0, GameState.DEFAULT_NAME, seed, &"prime")
		var real_st: GameState = GameState.create_new(real_data(), 0, GameState.DEFAULT_NAME, seed, &"prime")
		for lv: int in [3, 5, 7, 9]:
			assert_eq(Talents.offer(st, data, "kai", lv), Talents.offer(real_st, real_data(), "kai", lv),
				"seed %d, level %d: the same offer" % [seed, lv])


# --- broken samples ---------------------------------------------------------------------------------------------------

func test_broken_season_samples_are_refused() -> void:
	for c: Dictionary in BROKEN:
		var raw: Dictionary = _sample()
		for m: Variant in (c["set"] as Array):
			_mutate(raw, m as Array)
		var v: DataValidator = DataValidator.new()           # the validator alone: GameData would only add its defs
		v.validate(raw)
		assert_has("; ".join(v.errors), str(c["want"]), "refused")


func test_broken_exp_tables_are_refused() -> void:
	var short: Array = _exp_curve().slice(0, 48)
	var off: Array = _exp_curve()
	off[0] = 34
	var flat: Array = _exp_curve()
	flat[20] = flat[19]
	var zero: Array = _exp_curve()
	zero[30] = 0
	var cases: Array = [
		[short, "party.exp_table: needs 49 entries — the EXP of level 1..49 to the next (got 48)"],
		[off, "party.exp_table[0]: level 1 keeps the GDD §4.3 curve: 33 (got 34)"],
		[flat, "party.exp_table[20]: must rise from level to level"],
		[zero, "party.exp_table[30]: out of range 1..1000000 (got 0)"],
		["viel", "party.exp_table: expected array of integers"],
	]
	for c: Array in cases:
		var raw: Dictionary = _sample()
		(raw["party"] as Dictionary)["exp_table"] = c[0]
		var data: GameData = GameData.new()
		assert_false(data.load_from_tables(raw), str(c[1]))
		assert_has("; ".join(data.errors), str(c[1]))
		assert_eq(data.exp_table(), PackedInt32Array(), "a broken table is []")


# --- SaveCodec: the level cap follows the season (09 §8.2) ------------------------------------------------------------

func test_save_codec_level_cap_follows_the_season() -> void:
	var data: GameData = real_data()
	assert_eq(SaveCodec.level_cap(null), Balance.LEVEL_CAP)
	var st: GameState = GameState.create_new(data, 0, GameState.DEFAULT_NAME, 4242, &"prime")
	assert_eq(SaveCodec.level_cap(st), Balance.LEVEL_CAP, "a campaign keeps 10")
	st.member("kai").level = 23
	st.member("kai").exp = 40
	var camp: GameState = SaveCodec.decode(SaveCodec.encode(st, "test"), data)
	assert_not_null(camp, "; ".join(SaveCodec.last_errors()))
	assert_eq([camp.member("kai").level, camp.member("kai").exp], [10, 0], "outside a season 10 stays the cap")
	st.season = _season()
	assert_eq(SaveCodec.level_cap(st), Balance.SEASON_LEVEL_CAP)
	var ssn: GameState = SaveCodec.decode(SaveCodec.encode(st, "test"), data)
	assert_not_null(ssn, "; ".join(SaveCodec.last_errors()))
	assert_eq([ssn.member("kai").level, ssn.member("kai").exp], [23, 40], "a season keeps level 23 and its EXP")
	st.member("kai").level = 60
	var top: GameState = SaveCodec.decode(SaveCodec.encode(st, "test"), data)
	assert_eq([top.member("kai").level, top.member("kai").exp], [50, 0], "50 is the cap of a season")
