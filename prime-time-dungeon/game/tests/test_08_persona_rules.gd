extends TestCase
## 08 §2, §3.6, §3.7, §4.4 (K1): the persona profile and its rules — canon, "Rest automatisch" (fill_unset: nothing
## set = canon, partial input keeps what was set), bias_for (distinct, sorted, <= 3, rotating only), the recorded
## command (talent "" — the K1 change request in Command.validate), apply touches only flags.persona, the
## placeholder context ({cand}, {job} forms and status forms, {club} with its possessive, {trait}, {rival}, {brand}),
## the card texts, the name and free-text filters with reasons and the nearest tile, the persona file (round trip,
## unknown ids → canon, rejected texts dropped), save / load (slot without the name, persona file with it) and the
## migration of an old save that still carries a name.

const ROOT: String = "user://test_08_rules"
const SAVES: String = "user://test_08_rules/saves"


func before_each() -> void:
	_rmrf(ROOT)
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
	_rmrf(ROOT)


static func _rmrf(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for f: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	for sub: String in DirAccess.get_directories_at(path):
		_rmrf(path.path_join(sub))
	DirAccess.remove_absolute(path)


func _jana(data: GameData) -> PersonaProfile:
	var p: PersonaProfile = PersonaProfile.canon(data)
	p.name = "Jana"
	p.form = "f"
	p.origin = "org_care"
	p.occupation = "occ_care_midwife"
	p.hobby = "hob_cooking"
	p.traits = PackedStringArray(["trt_chaotic", "trt_caring"])
	p.source = "offline"
	p.make_beats(data, null)
	return p


# --- canon, "Rest automatisch" -----------------------------------------------------------------------------------

func test_canon_persona() -> void:
	var data: GameData = real_data()
	var c: PersonaProfile = PersonaProfile.canon(data)
	assert_eq([c.name, c.form, c.origin, c.occupation, c.hobby, Array(c.traits), c.source],
		["Kai", "n", "org_animals", "occ_animals_keeper", "hob_animals", [], "canon"])
	assert_eq(c.beats, {"rival": "rv_animals_1", "brand": "br_org_animals", "gag": "gag_animals",
		"greeting": "gr_tierheim"}, "08 §3.6: the canon beats")
	assert_true(c.is_canon(data))
	assert_eq(c.validate(data), PackedStringArray())
	assert_eq(PersonaText.job(c, data), "Tierpfleger:in")


func test_rest_automatisch_fills_only_unset_fields() -> void:
	var data: GameData = real_data()
	var none: PersonaProfile = PersonaProfile.new()
	none.fill_unset(data, PackedStringArray())
	assert_eq(none.to_dict(), PersonaProfile.canon(data).to_dict(), "nothing set → the canon persona (Kai)")
	var p: PersonaProfile = PersonaProfile.new()
	p.name = "Jana"
	p.form = "f"
	p.origin = "org_retired"
	p.traits = PackedStringArray(["trt_brave"])
	p.fill_unset(data, PackedStringArray(["name", "origin"]))
	assert_eq([p.name, p.form, p.origin, p.occupation, p.hobby, Array(p.traits), p.source],
		["Jana", "n", "org_retired", "", "hob_animals", [], "offline"], "set: name, origin; the rest → canon")
	assert_eq(str(p.beats["brand"]), "br_org_retired", "the beats follow the set origin")
	assert_true(JsonUtil.to_str_array(data.origin("org_retired")["rivals"]).has(str(p.beats["rival"])))
	assert_false(p.is_canon(data))


func test_bias_and_command() -> void:
	var data: GameData = real_data()
	assert_eq(PersonaRules.bias_for(data, PackedStringArray(["trt_chaotic", "trt_caring", "trt_witty"])),
		PackedStringArray(["mar_graf_finale", "mar_variety"]), "sorted, the bias-free trait skipped")
	assert_eq(PersonaRules.bias_for(data, PackedStringArray(["trt_brave", "trt_brave"])),
		PackedStringArray(["mar_brave"]), "distinct")
	assert_eq(PersonaRules.bias_for(data, PackedStringArray(["trt_nope"])), PackedStringArray())
	var four: PackedStringArray = PersonaRules.bias_for(data, PackedStringArray(["trt_sporty", "trt_natural",
		"trt_brave", "trt_foodie"]))
	assert_eq(four.size(), 3, "at most three")
	var cmd: Dictionary = PersonaRules.command_for(data, "", PackedStringArray(["trt_sporty", "trt_natural"]))
	assert_eq(cmd, {"t": "persona", "v": 1, "talent": "", "bias": ["mar_bio", "mar_stunt"]})
	assert_eq(Command.validate(cmd), "", "Command.validate takes the K1 command (talent \"\")")
	assert_has(Command.validate({"t": "persona", "v": 1, "talent": "org_care", "bias": []}), "tal_org_")
	assert_has(Command.validate({"t": "persona", "v": 1, "bias": []}), "talent must be a String")
	for t: MarotteDef in data.all_marotten():
		if not t.rotation:
			for tr: Dictionary in data.persona_list("traits"):
				assert_ne(str(tr["bias"]), t.id, "no trait biases a non-rotating preference")


func test_apply_sets_only_the_flag() -> void:
	var data: GameData = real_data()
	var st: GameState = GameState.create_new(data, 0, "Kai", 77, &"prime")
	var sim: RunSim = RunSim.new(data, st, {}, {})
	sim.apply({"t": "floor", "floor": 1})
	sim.apply({"t": "hero", "id": "kai"})
	var before: Dictionary = st.to_dict()
	assert_true(PersonaRules.apply(st, data, PersonaRules.command_for(data, "", PackedStringArray(["trt_brave"]))))
	var after: Dictionary = st.to_dict()
	assert_eq((after["flags"] as Dictionary)["persona"], {"v": 1, "bias": ["mar_brave"], "swapped": false})
	(after["flags"] as Dictionary).erase("persona")
	assert_eq(after, before, "nothing else changes (no combat value, 08 §3.4)")


# --- placeholders and texts ------------------------------------------------------------------------------------------

func test_placeholder_context() -> void:
	var data: GameData = real_data()
	var p: PersonaProfile = _jana(data)
	var ctx: Dictionary = PersonaText.ctx(p, data, null)
	assert_eq(ctx["cand"], "Kandidatin")
	assert_eq(ctx["job"], "Hebamme", "the job's form beats the tile's role")
	assert_eq(ctx["hobby"], "Kochen & Backen")
	assert_eq(ctx["club"], "Ihr Kochkurs")
	assert_eq(ctx["trait"], "chaotisch", "no rng → the first trait")
	assert_eq(ctx["rival"], "Dr. Till Tupfer")
	assert_eq(ctx["brand"], "Pflasterpracht")
	p.form = "m"
	assert_eq(PersonaText.job(p, data), "Entbindungspfleger")
	p.occupation = ""
	assert_eq(PersonaText.job(p, data), "Pfleger", "without a job: the tile's role in the form")
	p.form = "n"
	assert_eq([PersonaText.cand(p.form), PersonaText.job(p, data)], ["Kandidat:in", "Pflegekraft"])
	p.hobby = "hob_music"
	assert_eq(PersonaText.club(p, data), "Ihre Band", "feminine club → Ihre")
	p.hobby = ""
	assert_eq([PersonaText.hobby_name(p, data), PersonaText.club(p, data)], ["Freizeit", "Ihr Freundeskreis"])
	p.origin = "org_retired"
	p.form = "f"
	assert_eq(PersonaText.job(p, data), "im Ruhestand", "status tiles have one form for all")
	p.traits = PackedStringArray()
	assert_eq(PersonaText.ctx(p, data, null)["trait"], "undurchschaubar")
	var seen: Dictionary = {}
	var rng: RandomNumberGenerator = make_rng(3)
	p.traits = PackedStringArray(["trt_brave", "trt_witty"])
	for i in 30:
		seen[PersonaText.ctx(p, data, rng)["trait"]] = true
	assert_eq(seen.keys().size(), 2, "{trait} changes with a presentation rng")
	p.origin = "org_allround"
	p.job_text = "Astronaut"
	assert_eq(PersonaText.job(p, data), "Allrounderin", "the free text is never {job}")
	assert_eq(PersonaText.ctx(p, data, null)["job_text"], "Astronaut")


func test_card_texts() -> void:
	var data: GameData = real_data()
	var card: Dictionary = PersonaText.card(_jana(data), data)
	assert_eq(card["title"], "JANA · Kandidatin")
	assert_eq(card["job"], "Hebamme · Hobby: Kochen & Backen")
	assert_eq(card["traits"], "chaotisch · fürsorglich")
	assert_eq(card["free"], "")
	var p: PersonaProfile = _jana(data)
	p.origin = "org_allround"
	p.occupation = ""
	p.job_text = "Astronaut"
	p.hobby = ""
	p.hobby_text = "Origami"
	assert_eq(PersonaText.card(p, data)["free"], "Vorleben: „Astronaut“ · Hobby: „Origami“")


func test_name_and_free_text_filters() -> void:
	var data: GameData = real_data()
	assert_eq(PersonaText.check_name("Jana"), "")
	assert_eq(PersonaText.check_name("Zoë-Marie"), "")
	assert_has(PersonaText.check_name("Netflix"), "Markenwort")
	assert_has(PersonaText.check_name("Netflix"), "nicht sendefähig")
	assert_has(PersonaText.check_name("0171 2345678"), "Kontaktdaten")
	assert_has(PersonaText.check_name("Abcdefghijklm"), "zu lang")
	assert_eq(PersonaText.check_free_text("Hebamme", 24), "")
	assert_eq(PersonaText.check_free_text("Politikerin", 24), "Politik sendet M.O.D. nicht.")
	assert_eq(PersonaText.check_free_text("Bürgermeisterin", 24), "Politik sendet M.O.D. nicht.")
	assert_eq(PersonaText.check_free_text("YouTuberin bei YouTube", 24), "Bitte keine Markennamen.")
	assert_eq(PersonaText.check_free_text("jana@example.org", 24), "Bitte keine Kontaktdaten, Adressen oder Nummern.")
	assert_eq(PersonaText.check_free_text("www.jana.de", 24), "Bitte keine Kontaktdaten, Adressen oder Nummern.")
	assert_eq(PersonaText.check_free_text("@jana_live", 24), "Bitte keine Kontaktdaten, Adressen oder Nummern.")
	assert_eq(PersonaText.check_free_text("x".repeat(25), 24), "Höchstens 24 Zeichen.")
	assert_eq(PersonaText.nearest_tile(data, "Politikerin", "Politik sendet M.O.D. nicht."), "org_office",
		"politics → Büro, Finanzen & Verwaltung")
	assert_eq(PersonaText.nearest_tile(data, "YouTuberin", "Bitte keine Markennamen."), "org_media",
		"a keyword hit in the rejected text")
	assert_eq(PersonaText.nearest_tile(data, "xyz", "Bitte keine Markennamen."), "")


func test_length_rule_and_ai_filter() -> void:
	var data: GameData = real_data()
	assert_eq(PersonaText.effective_length("{name}"), 12)
	assert_eq(PersonaText.effective_length("Sie sind {job}."), "Sie sind .".length() + 24)
	var lines: Array = [
		{"hook": "intro", "voice": "mod", "text": "{name} kommt aus dem Kreißsaal. Der Dungeon ist Feierabend."},
		{"hook": "first_chest", "voice": "mod", "text": "Eine Truhe! {club} hält den Atem an."},
		{"hook": "safe_room", "voice": "mopsula", "text": "Fußnote 2: Ich halte Wache. Sie schlafen."},
		{"hook": "floor_end", "voice": "mod", "text": "Etage geschafft, {cand} {name}."},
		{"hook": "boss", "voice": "mod", "text": "Boss-Zeile im Kampf."},
		{"hook": "game_over", "voice": "mopsula", "text": "Fußnote 3: Ich finde Uns großartig."},
		{"hook": "game_over", "voice": "mod", "text": "Sie sind von Beruf {job}."},
		{"hook": "card", "voice": "mod", "text": "Besuchen Sie www.nova.de!"},
		{"hook": "card", "voice": "mod", "text": "Unbekannt: {telefon}"},
	]
	var kept: Array = PersonaText.filter_ai_lines(lines, data)
	assert_eq(kept.size(), 4, "boss hook, royal plural, \"von Beruf\", URL, unknown placeholder dropped")
	assert_eq(PersonaText.filter_ai_lines(lines.slice(0, 3), data), [], "fewer than 4 valid lines → none (K-7)")
	assert_true(PersonaText.royal_plural("Fußnote 3: Ich bin enttäuscht, sagen Wir."))
	assert_false(PersonaText.royal_plural("Wir sehen uns. Unser Plan: Leberwurst."), "a sentence start is fine")


# --- the persona file -----------------------------------------------------------------------------------------------

func test_persona_file_round_trip_and_corrections() -> void:
	var data: GameData = real_data()
	var p: PersonaProfile = _jana(data)
	assert_eq(PersonaProfile.from_dict(p.to_dict(), data).to_dict(), p.to_dict())
	var d: Dictionary = p.to_dict()
	d["origin"] = "org_gone"
	d["hobby"] = "hob_gone"
	d["traits"] = ["trt_brave", "trt_gone", "trt_brave", "trt_witty", "trt_sporty", "trt_foodie"]
	d["job_text"] = "Politiker"
	d["name"] = "Netflix"
	var q: PersonaProfile = PersonaProfile.from_dict(d, data)
	assert_eq([q.origin, q.occupation, q.hobby], ["org_animals", "occ_animals_keeper", "hob_animals"],
		"unknown ids → canon (display)")
	assert_eq(Array(q.traits), ["trt_brave", "trt_witty", "trt_sporty"], "known, distinct, <= 3")
	assert_eq([q.job_text, q.name], ["", "Kai"], "rejected texts dropped")
	assert_eq(q.validate(data), PackedStringArray())
	var bad: PersonaProfile = _jana(data)
	bad.occupation = "occ_it_dev"
	bad.talent = "tal_org_care"
	assert_eq(bad.validate(data).size(), 2, "a job of another tile, a start talent")


func test_save_and_load_keep_the_name_out_of_the_slot() -> void:
	var p: PersonaProfile = _jana(DB.data)
	Game.new_game(1, p.name, 4242, &"prime", "kai", p)
	assert_eq(Save.save_slot(1), OK, Save.last_error())
	var slot: String = FileAccess.get_file_as_string(Save.slot_path(1))
	assert_false(slot.contains("Jana"), "08 §2.7 Nr. 1: the slot file never has the name")
	assert_true(FileAccess.get_file_as_string(Save.persona_path(1)).contains("Jana"))
	assert_eq(str(Save.slot_summary(1).get("player_name", "")), "Jana", "slot select reads the persona file")
	Game.state = null
	Game.persona = null
	assert_eq(Save.load_slot(1), OK, Save.last_error())
	assert_eq([Game.state.player_name, Game.state.member("kai").display_name], ["Jana", "Jana"])
	assert_eq(Game.persona.to_dict(), p.to_dict(), "the persona comes back")
	assert_eq(PersonaRules.bias(Game.state), PackedStringArray(["mar_graf_finale", "mar_variety"]))
	assert_eq(Save.delete_slot(1), OK)
	assert_false(FileAccess.file_exists(Save.persona_path(1)), "the persona file goes with the slot")


func test_old_save_with_a_name_is_migrated() -> void:
	Game.new_game(2, "Kai", 99)
	assert_eq(Save.save_slot(2), OK)
	var raw: Dictionary = JsonUtil.read_file(Save.slot_path(2))
	(raw["state"] as Dictionary)["player_name"] = "Robin"            # a save written before K1
	for m: Variant in ((raw["state"] as Dictionary)["party"] as Array):
		if str((m as Dictionary)["id"]) == "kai":
			(m as Dictionary)["display_name"] = "Robin"
	var f: FileAccess = FileAccess.open(Save.slot_path(2), FileAccess.WRITE)
	f.store_string(JSON.stringify(raw))
	f.close()
	assert_false(FileAccess.file_exists(Save.persona_path(2)))
	assert_eq(Save.load_slot(2), OK, Save.last_error())
	assert_eq(Game.state.player_name, "Robin")
	assert_true(FileAccess.file_exists(Save.persona_path(2)), "migration: a persona file with that name")
	var p: PersonaProfile = Save.load_persona(2)
	assert_eq([p.name, p.origin, p.source], ["Robin", "org_animals", "canon"], "name + canon values")
	assert_false(FileAccess.get_file_as_string(Save.slot_path(2)).contains("Robin"), "the name moved out of the slot")
	assert_eq(Save.save_slot(2), OK)
	assert_false(FileAccess.get_file_as_string(Save.slot_path(2)).contains("Robin"), "the next save drops it")


func test_a_new_game_without_persona_keeps_a_custom_name() -> void:
	Game.new_game(3, "Mika", 5)
	assert_null(Game.persona)
	assert_eq(Save.save_slot(3), OK)
	assert_false(FileAccess.get_file_as_string(Save.slot_path(3)).contains("Mika"))
	assert_eq(Save.load_slot(3), OK)
	assert_eq(Game.state.player_name, "Mika", "the name lives in the persona file")
	Game.new_game(3, "Kai", 6)
	assert_eq(Save.save_slot(3), OK)
	assert_false(FileAccess.file_exists(Save.persona_path(3)), "a new canon game in the slot removes the old file")
