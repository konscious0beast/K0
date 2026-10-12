extends TestCase
## 08 §3, §3.9 (K1): the Vorleben catalog data/origins.json — counts, the content rules of validators/origins.gd
## (positive and negative), references, `prof` (09 §8.6: empty exactly for the status tiles and org_allround, set for
## every hobby), no start talents (CR-33), keyword uniqueness, the icon copy and the offline "Anderes …" mapping of
## tests/fixtures/persona/job_texts.json (>= 90 % hits, 08 §3.7).

const JOB_TEXTS: String = "res://tests/fixtures/persona/job_texts.json"
const UiIcon := preload("res://scenes/ui/ui_icon.gd")
const OriginsCheck := preload("res://core/data/validators/origins.gd")
const STATUS_TILES: PackedStringArray = ["org_school", "org_selfemployed", "org_retired", "org_family",
	"org_reorient"]


func _raw() -> Dictionary:
	var raw: Dictionary = {}
	for t: String in GameData.TABLES:
		raw[t] = JsonUtil.read_file("res://data/%s.json" % t)
	raw["rt_balance"] = JsonUtil.read_file("res://data/" + GameData.RT_BALANCE_FILE)
	return raw


## Loads `raw` with one change of origins.json; returns the joined errors ("" = valid).
func _errors_with(change: Callable) -> String:
	var raw: Dictionary = _raw()
	change.call(raw["origins"] as Dictionary)
	var d: GameData = GameData.new()
	d.load_from_tables(raw, "test_08_origins")
	return "; ".join(d.errors)


func _entry(o: Dictionary, id: String) -> Dictionary:
	for e: Variant in (o["entries"] as Array):
		if str((e as Dictionary)["id"]) == id:
			return e
	return {}


func test_catalog_counts_and_shape() -> void:
	var data: GameData = real_data()
	assert_eq(data.all_origins().size(), 24, "23 tiles + org_allround")
	assert_eq(data.persona_list("hobbies").size(), 17)
	assert_eq(data.persona_list("traits").size(), 12)
	assert_between(data.persona_plans().size(), 2, 3)
	assert_eq(data.persona_list("rivals").size(), 48, "two rivals per Vorleben")
	assert_eq(data.persona_list("gags").size(), 17)
	assert_true(data.persona_list("brands").size() >= 24 + 3, "one sponsor per Vorleben + generic ones")
	assert_eq(data.persona_list("greetings").size(), 19, "16 hobby greetings + Tierheim, Kolleg:innen, Zuhause")
	var raw: Dictionary = JsonUtil.read_file("res://data/origins.json")
	assert_false(raw.has("talents"), "CR-33: no start talents in the catalog")
	for e: Dictionary in data.all_origins():
		assert_false(e.has("talent") or e.has("alt"), "no start talent fields (CR-33, 09 ST0): " + str(e["id"]))
		var status: bool = bool(e["status"]) or str(e["id"]) == "org_allround"
		assert_eq(str(e["prof"]) == "", status, "prof empty exactly for status tiles + org_allround: " + str(e["id"]))
		assert_eq(JsonUtil.to_str_array(e["rivals"]).size(), 2, str(e["id"]))
	for id: String in STATUS_TILES:
		assert_true(bool(data.origin(id)["status"]), id + " is a status tile")
	for h: Dictionary in data.persona_list("hobbies"):
		assert_true(str(h["prof"]).begins_with("prf_"), "every hobby gives a recipe: " + str(h["id"]))


func test_prof_follows_09_8_6() -> void:
	var data: GameData = real_data()
	var want: Dictionary = {"org_animals": "prf_first_aid", "org_care": "prf_first_aid", "org_teach": "prf_first_aid",
		"org_kitchen": "prf_cooking", "org_craft": "prf_props", "org_media": "prf_props", "org_industry": "prf_props",
		"org_office": "prf_lab", "org_science": "prf_lab", "org_stage": "prf_costume", "org_law": "prf_costume",
		"org_beauty": "prf_costume", "org_it": "prf_scrap", "org_transport": "prf_scrap", "org_cleaning": "prf_scrap",
		"org_nature": "prf_shrooms", "org_sales": "prf_salvage", "org_rescue": "prf_salvage"}
	for id: String in want.keys():
		assert_eq(str(data.origin(id)["prof"]), want[id], id)
	var hob: Dictionary = {"hob_cooking": "prf_cooking", "hob_animals": "prf_cooking", "hob_gaming": "prf_scrap",
		"hob_sports": "prf_first_aid", "hob_music": "prf_props", "hob_reading": "prf_lab", "hob_garden": "prf_shrooms",
		"hob_diy": "prf_props", "hob_travel": "prf_costume", "hob_dance": "prf_costume", "hob_photo": "prf_props",
		"hob_social": "prf_costume", "hob_outdoor": "prf_shrooms", "hob_volunteer": "prf_first_aid",
		"hob_boardgames": "prf_lab", "hob_crime": "prf_salvage", "hob_tech": "prf_scrap"}
	for id: String in hob.keys():
		assert_eq(str(data.hobby(id)["prof"]), hob[id], id)


func test_recall_tips_are_spread() -> void:
	var count: Dictionary = {}
	for e: Dictionary in real_data().all_origins():
		if str(e["id"]) == "org_allround":
			continue
		count[str(e["spec_hint"])] = int(count.get(str(e["spec_hint"]), 0)) + 1
	assert_eq(count.keys().size(), 4, "all four Kai classes are recommended")
	for cls: Variant in count.keys():
		assert_between(int(count[cls]), 5, 7, "08 §3.2: about equally spread (%s)" % str(cls))


func test_validator_accepts_the_catalog_and_the_fixture() -> void:
	assert_eq(_errors_with(func(_o: Dictionary) -> void: pass), "")
	var fixture: GameData = GameData.new()
	assert_true(fixture.load_dir("res://tests/fixtures/data_min"), "; ".join(fixture.errors))


func test_validator_rejects_bad_content() -> void:
	var cases: Array = [
		[func(o: Dictionary) -> void: _entry(o, "org_care")["prof"] = "", "needs a profession id"],
		[func(o: Dictionary) -> void: _entry(o, "org_retired")["prof"] = "prf_lab", "pick the profession freely"],
		[func(o: Dictionary) -> void: _entry(o, "org_care")["prof"] = "first_aid", "needs a profession id"],
		[func(o: Dictionary) -> void: ((o["hobbies"] as Array)[0] as Dictionary)["prof"] = "", "recipe"],
		[func(o: Dictionary) -> void: _entry(o, "org_care")["name"] = "Pflege, Medizin & sehr viel Geduld", "longer"],
		[func(o: Dictionary) -> void: _entry(o, "org_care")["flavor"] = "x".repeat(91), "longer"],
		[func(o: Dictionary) -> void: _entry(o, "org_care")["rivals"] = ["rv_care_1"], "exactly two"],
		[func(o: Dictionary) -> void: _entry(o, "org_care")["rivals"] = ["rv_care_1", "rv_nope"], "unknown rival"],
		[func(o: Dictionary) -> void: _entry(o, "org_care")["brand"] = "br_nope", "unknown brand"],
		[func(o: Dictionary) -> void: _entry(o, "org_care")["spec_hint"] = "cls_mop_archmage", "Kai class"],
		[func(o: Dictionary) -> void: _entry(o, "org_care")["icon"] = "stethoscope", "unknown icon"],
		[func(o: Dictionary) -> void: _entry(o, "org_retired")["role"] = {"n": "im Ruhestand", "f": "Rentnerin",
			"m": "Rentner"}, "one form for all"],
		[func(o: Dictionary) -> void: (_entry(o, "org_care")["keywords"] as Array).append("Pflege"), "lower-case"],
		[func(o: Dictionary) -> void: (_entry(o, "org_care")["keywords"] as Array).append("pfl"), ">= 4"],
		[func(o: Dictionary) -> void: (_entry(o, "org_care")["keywords"] as Array).append("koch"), "also a keyword"],
		[func(o: Dictionary) -> void: _entry(o, "org_care")["flavor"] = "Sie kennen jeden Schuhkarton.", "schuh"],
		[func(o: Dictionary) -> void: _entry(o, "org_care")["flavor"] = "Wie bei Netflix.", "blocked word"],
		[func(o: Dictionary) -> void: ((o["hobbies"] as Array)[0] as Dictionary)["club"] = {"text": "Kochkurs", "g": "x"},
			"club.g"],
		[func(o: Dictionary) -> void: ((o["hobbies"] as Array)[0] as Dictionary)["gag"] = "gag_nope", "unknown gag"],
		[func(o: Dictionary) -> void: ((o["traits"] as Array)[0] as Dictionary)["bias"] = "mar_unterhose",
			"rotating preference"],
		[func(o: Dictionary) -> void: ((o["plans"] as Array)[0] as Dictionary)["slots"] = [{"floor": 1, "hook": "boss",
			"n": 1, "slot": "line"}], "hook"],
		[func(o: Dictionary) -> void: ((o["plans"] as Array)[0] as Dictionary)["slots"] = [{"floor": 1, "hook": "intro",
			"n": 1, "slot": "talent"}], "slot"],
		[func(o: Dictionary) -> void: ((o["plans"] as Array)[0] as Dictionary)["slots"] = [{"floor": 1,
			"hook": "game_over", "n": 0, "slot": "line", "every": 1, "else": "line"}], "every"],
		[func(o: Dictionary) -> void: (o["canon"] as Dictionary)["occupation"] = "occ_care_nurse", "no job of"],
		[func(o: Dictionary) -> void: (o["canon"] as Dictionary)["origin"] = "org_nope", "unknown origin"],
		[func(o: Dictionary) -> void: _entry(o, "org_it")["talent"] = "tal_org_it", "org_it].talent: unknown key"],
		[func(o: Dictionary) -> void: o["talents"] = [], "origins.talents: unknown top-level key"],
	]
	for c: Array in cases:
		var errs: String = _errors_with(c[0] as Callable)
		assert_has(errs, str(c[1]), "expected an error with '%s'" % str(c[1]))


func test_keywords_are_unique_per_list() -> void:
	var data: GameData = real_data()
	for list: Array in [data.all_origins(), data.persona_list("hobbies")]:
		var seen: Dictionary = {}
		for e: Dictionary in list:
			for k: String in e["keywords"]:
				assert_false(seen.has(k), "'%s' in %s and %s" % [k, str(seen.get(k, "")), str(e["id"])])
				seen[k] = str(e["id"])


func test_icon_copy_is_a_subset_of_ui_icon() -> void:
	for k: String in OriginsCheck.ICON_KINDS:
		assert_true(UiIcon.KINDS.has(StringName(k)), "UiIcon has '%s'" % k)


func test_job_texts_map_offline() -> void:
	var data: GameData = real_data()
	var cases: Dictionary = JsonUtil.read_file(JOB_TEXTS)
	var jobs: Array = cases["jobs"]
	var hobbies: Array = cases["hobbies"]
	assert_true(jobs.size() + hobbies.size() >= 60, "08 §3.7: >= 60 examples")
	var hit: int = 0
	var misses: PackedStringArray = []
	for c: Dictionary in jobs:
		var got: String = PersonaRules.map_text(data, str(c["text"]), &"job")
		if got == str(c["origin"]):
			hit += 1
		else:
			misses.append("%s → %s (want %s)" % [str(c["text"]), got, str(c["origin"])])
	for c: Dictionary in hobbies:
		var got: String = PersonaRules.map_text(data, str(c["text"]), &"hobby")
		if got == str(c["hobby"]):
			hit += 1
		else:
			misses.append("%s → %s (want %s)" % [str(c["text"]), got, str(c["hobby"])])
	var total: int = jobs.size() + hobbies.size()
	assert_true(hit * 100 >= total * 90, "%d / %d hits: %s" % [hit, total, "; ".join(misses)])


func test_mapping_rules() -> void:
	var data: GameData = real_data()
	assert_eq(PersonaRules.normalize_text("  Kfz-Mechatronikerin (Azubi)! "), "kfz mechatronikerin azubi")
	assert_eq(PersonaRules.normalize_text("Größe ÄÖÜ é"), "groesse aeoeue e")
	assert_eq(PersonaRules.map_text(data, "IT", &"job"), "org_it", "=it is a whole word")
	assert_eq(PersonaRules.map_text(data, "Bitterstoffe", &"job"), "", "…not a part of a word")
	assert_eq(PersonaRules.map_text(data, "Tierpflegerin", &"job"), "org_animals", "the longest hit wins (pfleg)")
	assert_eq(PersonaRules.map_text(data, "Altenpflegerin", &"job"), "org_care")
	assert_eq(PersonaRules.map_text(data, "", &"job"), "")
	assert_eq(PersonaRules.map_text(data, "Origami", &"hobby"), "hob_diy")
	assert_eq(PersonaRules.map_text(data, "Origami", &"job"), "", "jobs and hobbies are separate lists")
