extends TestCase
## 06 package B — species / specialization data model for floor 3 (06 §3, 02_TECH §4.4.16): species.json content and
## validator rules (references to classes and party, passive ids, look hints, no crown on Mopsula, spc_original),
## GameData getters, Casting.options / check (every reason) / choose (species + class multipliers in total_stats,
## bookkeeping for re-spec), the recorded command (Game facade + RunSim) and save round trips. No Casting UI yet.

const Fx := preload("res://tests/test_m2_fixtures.gd")
const SpeciesRules := preload("res://core/data/validators/species.gd")
const UiUtil := preload("res://scenes/ui/ui_util.gd")


func after_each() -> void:
	Game.state = null
	Game.run_log = null
	Game.sim = null


## Real-data state with a floor run on `floor_index` (floor 1's layout; only the index matters for the Casting), in
## safe room `room` ("" = exploration), `visits` safe-room entries so far.
func _state(floor_index: int, room: String = "sr_kiosk", visits: int = 1) -> GameState:
	var d: GameData = real_data()
	var st: GameState = GameState.create_new(d, 0, "Kai", 99)
	st.floor_run = FloorRun.create(d.floor_def(1), st.seed, st.difficulty)
	st.floor_run.index = floor_index
	if room != "":
		st.floor_run.location = StringName(room)
		st.floor_run.visited_safe_rooms.append(room)
	st.floor_run.safe_room_visits = visits
	for m: PartyMember in st.party:
		m.level = 10
	Progression.full_heal(st, d)
	return st


func _species(extra: Dictionary) -> Dictionary:
	var d: Dictionary = {"id": "spc_test", "name": "Test", "desc": "Ein Test.", "for": ["kai"],
		"stat_mult": {"hp": 1.1}, "passive": {"id": "pas_test", "params": {}}}
	d.merge(extra, true)
	return d


func _data_with(species: Array) -> GameData:
	var t: Dictionary = Fx.tables()
	t["species"] = species
	var d: GameData = GameData.new()
	d.load_from_dicts(t)
	return d


# --- content ----------------------------------------------------------------------------------------------------------

func test_eight_species_four_kai_three_mopsula_plus_original() -> void:
	var d: GameData = real_data()
	assert_eq(d.all_species().size(), 8, "06 §3.7: 8 species")
	assert_eq(d.all_species()[0].id, SpeciesDef.ORIGINAL, "Original-Verpackung first")
	var kai: int = 0
	var mop: int = 0
	for s: SpeciesDef in d.all_species():
		assert_eq(s.min_floor, 3, s.id + ": casting from floor 3")
		assert_true(str(s.passive.get("id", "")).begins_with("pas_"), s.id + " has a passive")
		assert_between(s.desc.length(), 1, SpeciesRules.DESC_MAX, s.id)
		assert_eq(UiUtil.missing_glyphs(s.name + s.desc), "", s.id + ": glyphs render")
		if s.id == SpeciesDef.ORIGINAL:
			assert_eq(s.for_members, PackedStringArray(), "everyone can stay original")
			assert_eq(s.stat_mult, {}, "original changes no stat")
			continue
		assert_eq(s.for_members.size(), 1, s.id + " belongs to one member")
		kai += 1 if s.is_for("kai") else 0
		mop += 1 if s.is_for("mopsula") else 0
		assert_false(s.recommended_classes.is_empty(), s.id + " recommends a specialization")
		for cid: String in s.recommended_classes:
			assert_true(d.class_def(cid).is_for(s.for_members[0]), "%s → %s fits" % [s.id, cid])
		if s.is_for("mopsula"):
			for p: String in (s.model_hint.get("props_add", PackedStringArray()) as PackedStringArray):
				assert_false(p.contains("crown"), s.id + ": no crown motif on Mopsula (04 §2.3)")
	assert_eq(kai, 4)
	assert_eq(mop, 3)


func test_validator_accepts_a_species_and_rejects_bad_ones() -> void:
	var ok: GameData = _data_with([_species({"recommended_classes": ["cls_kai_test"], "growth_add": {"hp": 1.0},
		"model_hint": {"props_add": ["wings"], "colors": {"primary": "#112233"}}})])
	assert_eq(ok.errors, PackedStringArray())
	assert_eq(ok.species_def("spc_test").stat_mult, {"hp": 1.1})
	assert_eq(ok.species_def("spc_test").recommended_classes, PackedStringArray(["cls_kai_test"]))
	var cases: Array = [
		[_species({"stat_mult": {"hp": 2.5}}), "out of range 0.5..2.0"],
		[_species({"stat_mult": {"luck": 1.1}}), "luck: unknown key"],
		[_species({"growth_add": {"hp": 25.0}}), "out of range 0.0..20.0"],
		[_species({"passive": {"id": "grout", "params": {}}}), "invalid passive id 'grout'"],
		[_species({"passive": {"params": {}}}), "passive.id: missing required field"],
		[{"id": "spc_x", "name": "X", "for": ["kai"]}, "passive: missing required field"],
		[_species({"recommended_classes": ["cls_nope"]}), "unknown class 'cls_nope'"],
		[_species({"for": ["mopsula"], "recommended_classes": ["cls_kai_test"]}), "is not for 'mopsula'"],
		[_species({"for": ["carl"]}), "unknown party member 'carl'"],
		[_species({"id": "species_x"}), "invalid id 'species_x'"],
		[_species({"min_floor": 0}), "min_floor: out of range 1..99"],
		[_species({"model_hint": {"props_add": ["jetpack"]}}), "'jetpack' not in"],
		[_species({"for": ["mopsula"], "model_hint": {"props_add": ["crown"]}}), "no crown motif"],
		[_species({"for": [], "model_hint": {"props_add": ["ticket_crown"]}}), "no crown motif"],
		[_species({"model_hint": {"colors": {"primary": "red"}}}), "hex color"],
		[_species({"model_hint": {"colors": {"glow": "#ffffff"}}}), "unknown color key"],
		[_species({"desc": "Schuhgröße 46."}), "no foot words"],
		[_species({"skin": "tiles"}), "skin: unknown key"],
	]
	for c: Array in cases:
		var d: GameData = _data_with([c[0]])
		var joined: String = " | ".join(d.errors)
		assert_true(joined.contains(str(c[1])), "'%s' in: %s" % [str(c[1]), joined])


func test_strict_load_needs_spc_original_for_everyone() -> void:
	var raw: Dictionary = {}
	for t: String in GameData.TABLES:
		raw[t] = JsonUtil.read_file("res://data/%s.json" % t)
	var ok: GameData = GameData.new()
	assert_true(ok.load_from_tables(raw.duplicate(true)), "; ".join(ok.errors))
	var no_original: Dictionary = raw.duplicate(true)
	(no_original["species"] as Dictionary)["entries"] = ((raw["species"] as Dictionary)["entries"] as Array).slice(1)
	var d: GameData = GameData.new()
	d.load_from_tables(no_original)
	assert_true(" | ".join(d.errors).contains("required species 'spc_original' missing"), " | ".join(d.errors))
	var narrow: Dictionary = raw.duplicate(true)
	(((narrow["species"] as Dictionary)["entries"] as Array)[0] as Dictionary)["for"] = ["kai"]
	var d2: GameData = GameData.new()
	d2.load_from_tables(narrow)
	assert_true(" | ".join(d2.errors).contains("species[spc_original].for"), " | ".join(d2.errors))


func test_gamedata_getters_and_tables() -> void:
	var d: GameData = real_data()
	assert_has(GameData.TABLES, "talents")
	assert_has(GameData.TABLES, "species")
	assert_eq(DataValidator.TABLES, GameData.TABLES)
	assert_true(d.has_id("species", "spc_kai_kachelgolem"))
	assert_eq(d.species_def("spc_kai_kachelgolem").name, "Kachelgolem")
	assert_eq(DB.species_def("spc_mop_glutmops").passive["id"], "pas_ember")
	assert_eq(DB.talent("tal_mop_stereo").effects[0]["kind"], "field_range_pm")
	assert_eq(d.ids("species").size(), 8)
	var ids: PackedStringArray = []
	for t: TalentDef in d.all_talents():
		ids.append(t.id)
	var sorted_ids: PackedStringArray = ids.duplicate()
	sorted_ids.sort()
	assert_eq(ids, sorted_ids, "all_talents() in id order (the offer draws in this order)")


# --- Casting ----------------------------------------------------------------------------------------------------------

func test_options_per_member() -> void:
	var st: GameState = _state(3)
	var o: Dictionary = Casting.options(st, real_data(), "kai")
	assert_eq(o["species"], PackedStringArray(["spc_original", "spc_kai_kachelgolem", "spc_kai_neonfalter",
		"spc_kai_pilzling", "spc_kai_teilautomat"]))
	assert_eq(o["classes"], PackedStringArray(["cls_kai_wrecker", "cls_kai_runner", "cls_kai_tinker",
		"cls_kai_showrunner"]))
	var om: Dictionary = Casting.options(st, real_data(), "mopsula")
	assert_eq((om["species"] as PackedStringArray).size(), 4, "original + 3")
	assert_eq((om["classes"] as PackedStringArray).size(), 4)
	assert_eq(Casting.options(st, real_data(), "carl"), {"species": PackedStringArray(),
		"classes": PackedStringArray()})


func test_check_reasons() -> void:
	var d: GameData = real_data()
	assert_eq(Casting.check(_state(2), d, "kai", "spc_kai_kachelgolem", "cls_kai_wrecker"), "floor_too_low")
	assert_eq(Casting.check(_state(3, ""), d, "kai", "spc_kai_kachelgolem", "cls_kai_wrecker"), "not_in_safe_room")
	var st: GameState = _state(3)
	assert_eq(Casting.check(st, d, "kai", "spc_mop_glutmops", "cls_kai_wrecker"), "not_for_member")
	assert_eq(Casting.check(st, d, "kai", "spc_kai_kachelgolem", "cls_mop_diva"), "not_for_member")
	assert_eq(Casting.check(st, d, "kai", "spc_nope", "cls_kai_wrecker"), "unknown_species")
	assert_eq(Casting.check(st, d, "kai", "spc_original", "cls_nope"), "unknown_class")
	assert_eq(Casting.check(st, d, "carl", "spc_original", "cls_kai_wrecker"), "not_for_member")
	assert_eq(Casting.check(st, d, "kai", "spc_original", "cls_kai_wrecker"), "", "Original bleiben is a full choice")
	assert_eq(Casting.check(st, d, "mopsula", "spc_original", "cls_mop_diva"), "")


func test_choose_applies_class_then_species_multipliers() -> void:
	var d: GameData = real_data()
	var st: GameState = _state(3)
	var kai: PartyMember = st.member("kai")
	var plain: PackedInt32Array = Progression.total_stats(kai, d).values.duplicate()
	assert_true(Casting.choose(st, d, "kai", "spc_kai_kachelgolem", "cls_kai_wrecker"))
	assert_eq(kai.species_id, "spc_kai_kachelgolem")
	assert_eq(kai.class_id, "cls_kai_wrecker")
	var cls: ClassDef = d.class_def("cls_kai_wrecker")
	var spc: SpeciesDef = d.species_def("spc_kai_kachelgolem")
	var base: PackedInt32Array = Progression.base_stats_at(d.party_member("kai"), 10, cls, spc).values
	var plain_base: PackedInt32Array = Progression.base_stats_at(d.party_member("kai"), 10).values
	var v: PackedInt32Array = Progression.total_stats(kai, d).values
	for i in StatBlock.KEYS.size():
		var key: String = StatBlock.KEYS[i]
		var x: int = plain[i] - plain_base[i] + base[i]         # level stats with class growth_add + equipment
		for mults: Dictionary in [cls.stat_mult, spc.stat_mult]:
			if mults.has(key):
				x = (x * roundi(float(mults[key]) * 1000.0) + 500) / 1000
		assert_eq(v[i], x, "%s: × class, then × species (round half up each)" % key)
	assert_gt(v[StatBlock.Stat.HP], plain[StatBlock.Stat.HP], "Kachelgolem + Abrissbirne: more HP")
	assert_lt(v[StatBlock.Stat.SPD], plain[StatBlock.Stat.SPD] + 1, "… and not faster")
	assert_eq(kai.hp, v[StatBlock.Stat.HP], "a full party stays full (vitals follow the new maximum)")
	assert_eq(kai.casting, {"floor": 3, "visit": 1, "class_floor": 3, "class_visit": 1})


func test_species_is_fixed_after_the_casting_visit_and_class_retrains_once_per_floor() -> void:
	var d: GameData = real_data()
	var st: GameState = _state(3)
	assert_true(Casting.choose(st, d, "kai", "spc_kai_neonfalter", "cls_kai_runner"))
	assert_eq(Casting.check(st, d, "kai", "spc_kai_pilzling", "cls_kai_tinker"), "", "same visit: try freely")
	assert_true(Casting.choose(st, d, "kai", "spc_kai_pilzling", "cls_kai_tinker"))
	# leave and come back (second visit on floor 3): species and class are fixed now
	st.floor_run.safe_room_visits = 2
	assert_eq(Casting.check(st, d, "kai", "spc_kai_neonfalter", "cls_kai_tinker"), "locked", "Vertrag ist Vertrag")
	assert_eq(Casting.check(st, d, "kai", "spc_kai_pilzling", "cls_kai_runner"), "locked", "class: once per floor")
	assert_eq(Casting.check(st, d, "kai", "spc_kai_pilzling", "cls_kai_tinker"), "", "no change is fine")
	# floor 4, first safe room: Umschulung (class only)
	st.floor_run.index = 4
	st.floor_run.safe_room_visits = 1
	st.floor_run.visited_safe_rooms = PackedStringArray(["sr_kiosk"])
	assert_eq(Casting.check(st, d, "kai", "spc_kai_pilzling", "cls_kai_showrunner"), "", "Umschulung on floor 4")
	assert_eq(Casting.check(st, d, "kai", "spc_kai_kachelgolem", "cls_kai_showrunner"), "locked", "species stays")
	# … but not in the second safe room of the floor
	st.floor_run.visited_safe_rooms = PackedStringArray(["sr_kiosk", "sr_pumphouse"])
	st.floor_run.location = &"sr_pumphouse"
	assert_eq(Casting.check(st, d, "kai", "spc_kai_pilzling", "cls_kai_showrunner"), "locked",
		"retraining only in the first safe room of a floor")
	st.floor_run.location = &"sr_kiosk"
	assert_true(Casting.choose(st, d, "kai", "spc_kai_pilzling", "cls_kai_showrunner"))
	assert_eq(int(st.member("kai").casting["class_floor"]), 4)
	assert_eq(int(st.member("kai").casting["floor"]), 3, "species bookkeeping unchanged")
	st.floor_run.safe_room_visits = 2
	assert_eq(Casting.check(st, d, "kai", "spc_kai_pilzling", "cls_kai_wrecker"), "locked", "once per floor")


func test_first_casting_works_in_any_safe_room_of_floor_3() -> void:
	var st: GameState = _state(3, "sr_pumphouse", 3)
	st.floor_run.visited_safe_rooms = PackedStringArray(["sr_kiosk", "sr_pumphouse"])
	assert_eq(Casting.check(st, real_data(), "mopsula", "spc_mop_spukmops", "cls_mop_hexer"), "",
		"a player who skipped the first room is not locked out")


func test_game_choose_casting_records_and_runsim_replays() -> void:
	Game.new_game(0, "Kai", 31)
	var st: GameState = Game.state
	var n0: int = Game.run_log.cmds().size()
	assert_false(Game.choose_casting("kai", "spc_kai_kachelgolem", "cls_kai_wrecker"), "floor 1: refused")
	assert_eq(Game.run_log.cmds().size(), n0, "a refused casting is not recorded")
	st.floor_run.index = 3
	st.floor_run.location = &"sr_kiosk"
	st.floor_run.visited_safe_rooms.append("sr_kiosk")
	assert_true(Game.choose_casting("kai", "spc_kai_kachelgolem", "cls_kai_wrecker"))
	var last: Dictionary = Game.run_log.cmds().back()["c"]
	assert_eq(last, {"t": "casting", "member": "kai", "species": "spc_kai_kachelgolem", "class": "cls_kai_wrecker"})
	assert_eq(Command.validate(last), "")
	# the verifier applies the same command through Casting.choose
	var d: GameData = real_data()
	var other: GameState = _state(3)
	var sim: RunSim = RunSim.new(d, other, {})
	sim.apply(last)
	assert_eq(other.member("kai").species_id, "spc_kai_kachelgolem")
	assert_eq(other.member("kai").class_id, "cls_kai_wrecker")
	var refused: GameState = _state(2)
	RunSim.new(d, refused, {}).apply(last)
	assert_eq(refused.member("kai").species_id, "", "RunSim refuses what Casting.check refuses")


func test_save_round_trip_and_sanitize() -> void:
	var d: GameData = real_data()
	var st: GameState = _state(3)
	assert_true(Casting.choose(st, d, "mopsula", "spc_mop_flattermops", "cls_mop_diva"))
	var json: Variant = JSON.parse_string(JSON.stringify(SaveCodec.encode(st, "test")))
	var back: GameState = SaveCodec.decode(json, d)
	assert_not_null(back)
	if back == null:
		return
	var m: PartyMember = back.member("mopsula")
	assert_eq(m.species_id, "spc_mop_flattermops")
	assert_eq(m.class_id, "cls_mop_diva")
	assert_eq(m.casting, {"floor": 3, "visit": 1, "class_floor": 3, "class_visit": 1})
	for mid: String in ["kai", "mopsula"]:
		assert_eq(back.member(mid).to_dict(), st.member(mid).to_dict(), mid + " round trip (fake floor index)")
	st.member("kai").species_id = "spc_mop_glutmops"          # not for Kai
	st.member("mopsula").species_id = "spc_gone"
	var cleaned: GameState = SaveCodec.decode(JSON.parse_string(JSON.stringify(SaveCodec.encode(st, "test"))), d)
	assert_eq(cleaned.member("kai").species_id, "", "foreign species dropped")
	assert_eq(cleaned.member("mopsula").species_id, "", "unknown species dropped")


func test_party_page_casting_line() -> void:
	var page: Script = load("res://scenes/ui/party_menu.gd") as Script
	var m: PartyMember = PartyMember.new()
	m.id = "kai"
	assert_eq(page.call("casting_text", m), "Spezies & Klasse: Casting ab Etage 3")
	m.species_id = "spc_kai_kachelgolem"
	m.class_id = "cls_kai_wrecker"
	assert_eq(page.call("casting_text", m), "Kachelgolem · Abrissbirne")
