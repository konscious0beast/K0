extends TestCase
## Polish pass (IP distance + tone, 2026-10-10; 04 §2.3, 06 §0.3): the word lists of the private validator helper
## core/data/validators/ip_words.gd (06 §8.0 Nr. 7 style) — every player-facing text: no "Fan-Box", no "Feinripp", no
## barefoot / shoe words, no real nationality or ethnic group as a punchline; Graf Mopsula's texts: no royalty motif
## (Majestät, Durchlaucht, Hoheit, Thron, Krone) while the Rattenkönigin keeps her title and crown. Plus the shipped
## decisions: Fanpost-Paket, "Gräfliches Gutachten" (new id), neutral Liga achievement names, the Liga rule in full
## ("ohne Rüstung & ohne Accessoire"), and Graf Mopsula's own voice (no royal "Wir/Uns") in the data and in the
## screens' code strings. Follow-up round: class "Zeremonienmeister" (new id), "Ohne Netz und doppelten Boden", no
## false alarm for ambiguous everyday words ("Amerikaner" pastry, "Franzose" wrench), the live line filter
## (mod_filter.json) covers the same lists, and the shelter is "Tierheim Pfotenglück" everywhere.

const IpWords := preload("res://core/data/validators/ip_words.gd")
const LIGA_RULE: String = "ohne Rüstung & ohne Accessoire"
const CODE_DIRS: PackedStringArray = ["res://scenes", "res://autoload"]
## The Count speaks for himself: a capitalized "Wir"/"Uns"/"Unser…" in his lines is the old pluralis majestatis
## (a real plural — Kai and him together — is written in lower case mid-sentence: "dann warten wir").
const ROYAL_PLURAL: String = "\\b(Wir|Uns|Unser[a-z]*)\\b"


func _raw_tables() -> Dictionary:
	var raw: Dictionary = {}
	for t: String in GameData.TABLES:
		raw[t] = JsonUtil.read_file("res://data/%s.json" % t)
	return raw


func _errors(raw: Dictionary) -> PackedStringArray:
	var d: GameData = GameData.new()
	d.load_from_tables(raw)
	return d.errors


func _entry(raw: Dictionary, table: String, id: String) -> Dictionary:
	for e: Variant in (raw[table] as Dictionary)["entries"]:
		if e is Dictionary and str((e as Dictionary).get("id", "")) == id:
			return e
	fail("no %s entry %s" % [table, id])
	return {}


func _expect(raw: Dictionary, needle: String, what: String) -> void:
	var errs: PackedStringArray = _errors(raw)
	for e: String in errs:
		if e.contains(needle):
			return
	fail("%s: expected an error containing '%s', got [%s]" % [what, needle, "; ".join(errs)])


## No error of this rule set (other validator messages are not this file's business).
func _expect_clean(raw: Dictionary, what: String) -> void:
	for e: String in _errors(raw):
		for marker: String in ["(IP distance", "(tone:", "(no royalty motif"]:
			assert_false(e.contains(marker), "%s: %s" % [what, e])


# --- validator: every text --------------------------------------------------------------------------------------------

func test_real_data_passes_the_word_lists() -> void:
	_expect_clean(_raw_tables(), "the shipped data has no IP / tone word")


func test_every_text_rejects_the_ip_and_tone_words() -> void:
	var cases: Array = [
		["lootboxes", "box_fan", "name", "Fan-Box", "contains 'fan-box'"],
		["achievements", "ach_duo_first", "name", "Doppel-Feinripp", "contains 'feinripp'"],
		["items", "itm_bandage", "desc", "Heilt 45 HP. Barfuß aufzutragen.", "contains 'barfuß'"],
		["items", "itm_acc_sneakers", "name", "Turnschuhe (gebraucht)", "contains 'schuh'"],
		["mod_lines", "mod_intro_01", "text", "Ein Paket aus Polen. Der Zoll lacht.", "names 'Polen'"],
		["enemies", "enm_kanalratte", "name", "Kanalratte aus Rumänien? Nein: Rumäne", "names 'Rumäne'"],
	]
	for c: Array in cases:
		var raw: Dictionary = _raw_tables()
		_entry(raw, str(c[0]), str(c[1]))[str(c[2])] = str(c[3])
		_expect(raw, str(c[4]), "%s.%s" % [str(c[0]), str(c[1])])
	# scene lines (any voice) and nested texts (zone names) are checked too
	var raw2: Dictionary = _raw_tables()
	((_entry(raw2, "scenes", "scn_mop_2")["lines"] as Array)[4] as Dictionary)["text"] = \
		"Deine Mutter war aus einem Kofferraum in Polen."
	_expect(raw2, "names 'Polen'", "the removed scene line")
	var raw3: Dictionary = _raw_tables()
	var lay: Dictionary = (_entry(raw3, "floors", "floor_1")["layout"] as Dictionary)
	((lay["zones"] as Array)[0] as Dictionary)["name"] = "Feinripp-Bahnsteig"
	_expect(raw3, "contains 'feinripp'", "a zone name")


func test_word_helpers_are_precise() -> void:
	assert_eq(IpWords.general_word("Polenta mit Soße"), "", "whole words: no Polenta alarm")
	assert_eq(IpWords.general_word("Ein Fanpost-Paket"), "")
	assert_eq(IpWords.general_word("Die Fan-Box ist da"), "fan-box")
	assert_eq(IpWords.general_word("Turnschuhe (gebraucht)"), "schuh", "substrings: compounds are caught")
	assert_eq(IpWords.general_word("ein Mann aus Polen"), "polen")
	assert_eq(IpWords.mopsula_word("Kopfschmuck aus Fahrscheinen"), "")
	assert_eq(IpWords.mopsula_word("Seine Durchlaucht"), "durchlaucht")
	assert_eq(IpWords.mopsula_word("eine KRONE aus Fahrscheinen"), "krone")


## Follow-up: the origin list leaves out words whose everyday meaning is something else (no false alarm), in the
## validator and in the live filter alike.
func test_ambiguous_everyday_words_are_no_origin_alarm() -> void:
	for text: String in ["Ein Amerikaner vom Kiosk, mit Zuckerguss.", "Zwei Amerikaner, bitte. Mit Schokolade.",
			"Mit dem Franzosen zieht der Hausmeister jede Schraube fest.", "Der Franzose liegt im Werkzeugkasten."]:
		assert_eq(IpWords.general_word(text), "", text)
		assert_ne(ModLineFilter.check(text), "blocked_origin", text)
	assert_eq(IpWords.general_word("Eine Amerikanerin im Publikum"), "amerikanerin", "the people word still counts")
	var raw: Dictionary = _raw_tables()
	_entry(raw, "items", "itm_bandage")["desc"] = "Heilt 45 HP. Riecht nach einem Amerikaner vom Kiosk."
	_expect_clean(raw, "a pastry in an item text")


# --- validator: Graf Mopsula's texts ----------------------------------------------------------------------------------

func test_mopsula_texts_reject_royalty_motifs() -> void:
	var cases: Array = [
		["mod_lines", "mod_mopsula_idle_01", "text", "Wir sind Majestät. Störe Uns nicht."],         # his voice
		["mod_lines", "mod_achievement_ach_queen_flawless_01", "text", "Kein KO. Graf Mopsula verlangt einen Thron."],
		["skills", "skl_mop_expert_opinion", "name", "Königlicher Erlass Seiner Durchlaucht"],      # his skill
		["skills", "skl_stunt_mop_entrance", "name", "Auftritt Seiner Hoheit"],                      # his stunt
		["scenes", "scn_mop_4", "name", "Vor dem Thron"],                                            # Mopsula-Szene
		["items", "itm_wpn_collar_signet", "desc", "Eine Krone für den Hals."],                      # he can wear it
		["classes", "cls_mop_physician", "name", "Leibarzt Seiner Hoheit"],                          # his class
		["twists", "tw_mopsula_moderates", "desc", "Seine Majestät der Mops übernimmt."],           # names him
		["party", "mopsula", "title", "Majestät"],
	]
	for c: Array in cases:
		var raw: Dictionary = _raw_tables()
		_entry(raw, str(c[0]), str(c[1]))[str(c[2])] = str(c[3])
		_expect(raw, "no royalty motif for Graf Mopsula", "%s.%s" % [str(c[0]), str(c[1])])


func test_the_rattenkoenigin_keeps_her_title() -> void:
	var raw: Dictionary = _raw_tables()
	assert_true(str(_entry(raw, "mod_lines", "mod_boss_intro_enm_boss_rattenkoenigin_01")["text"]).contains("Majestät"),
		"M.O.D. still announces Ihre Majestät")
	var lay: Dictionary = (_entry(raw, "floors", "floor_1")["layout"] as Dictionary)
	var zones: Array = (lay["zones"] as Array).map(func(z: Dictionary) -> String: return str(z["name"]))
	assert_has(zones, "Thronsaal", "her throne room")
	assert_eq(str(_entry(raw, "items", "itm_acc_queen_crown")["name"]), "Rattenkrone", "Kai's crown")
	_expect_clean(raw, "royalty words outside Graf Mopsula's texts are fine")


# --- the shipped decisions --------------------------------------------------------------------------------------------

func test_shipped_names_and_the_liga_rule() -> void:
	var d: GameData = real_data()
	assert_eq(d.lootbox("box_fan").name, "Fanpost-Paket", "04 §2.3 E2: display name, id box_fan stays")
	assert_false(d.has_id("skills", "skl_mop_royal_decree"), "the royal id is gone")
	assert_eq(d.skill("skl_mop_expert_opinion").name, "Gräfliches Gutachten")
	var st: Array[Dictionary] = d.skill("skl_mop_expert_opinion").statuses
	assert_len(st, 1, "same effect as before: Turbo")
	assert_eq(str(st[0]["id"]), "sts_haste")
	assert_eq(int(st[0]["turns"]), 3)
	assert_has(d.party_member("mopsula").learnset.map(func(l: Dictionary) -> String: return str(l["skill"])),
		"skl_mop_expert_opinion", "Mopsula learns it (level 4)")
	assert_eq(d.achievement("ach_duo_first").name, "Leichtes Gepäck im Doppelpack")
	assert_eq(d.achievement("ach_duo_floor").name, "Eine Etage leichtes Gepäck")
	for id: String in ["ach_ul_first", "ach_ul_boss", "ach_duo_first", "ach_duo_floor", "ach_duo_flawless"]:
		assert_true(d.achievement(id).desc.contains(LIGA_RULE), id + ": the Liga rule in full")
	assert_true(d.marotte("mar_unterhose").desc.to_lower().contains(LIGA_RULE.to_lower()), "the Liga Marotte")
	for tag: String in ["liga_hint", "liga_enter:1", "liga_enter:2", "liga_win"]:
		for l: ModLineDef in d.mod_lines(tag):
			assert_false(l.text.to_lower().contains("feinripp"), l.id)
			if l.text.contains("Rüstung"):
				assert_true(l.text.to_lower().contains(LIGA_RULE.to_lower()), l.id + ": the rule in full when it is named")


func test_the_count_speaks_in_his_own_voice() -> void:
	var d: GameData = real_data()
	var royal: RegEx = RegEx.create_from_string(ROYAL_PLURAL)
	var texts: PackedStringArray = []
	for l: ModLineDef in _mopsula_voice_lines(d):
		texts.append(l.text)
	for s: SceneDef in d.all_scenes():
		for line: Dictionary in s.lines:
			if str(line["voice"]) == "mopsula":
				texts.append(str(line["text"]))
	assert_gt(texts.size(), 20, "his lines")
	var footnotes: int = 0
	var shelter: int = 0
	var midnight: int = 0
	for t: String in texts:
		assert_null(royal.search(t), "no pluralis majestatis: " + t)
		footnotes += 1 if t.contains("Fußnote") else 0
		shelter += 1 if t.contains("Zwinger 7") else 0
		midnight += 1 if t.contains("Mitternacht") else 0
	assert_gt(footnotes, 3, "the lecturing scholar quotes his footnotes")
	assert_gt(shelter, 1, "shelter biography (Zwinger 7)")
	assert_gt(midnight, 0, "midnight pathos")
	var latin: RegEx = RegEx.create_from_string("„[A-Z][a-z]+ [a-z]+!“")
	var formulas: int = 0
	for s: SkillDef in d.all_skills():
		if s.id.begins_with("skl_mop_") and latin.search(s.desc) != null:
			formulas += 1
	assert_gt(formulas, 1, "pseudo-Latin spell formulas in his skills")
	assert_false(d.skill("skl_attack_mopsula").desc.contains("Wir"), "his bite, in his own voice")
	assert_false(d.item("itm_wpn_collar_signet").desc.contains("Wir"))


func test_screens_speak_in_the_counts_voice() -> void:
	var royal: RegEx = RegEx.create_from_string(ROYAL_PLURAL)
	var ne: Object = (load("res://scenes/title/name_entry.gd") as GDScript).new()
	ne.set("hero", "mopsula")
	var q: String = str(ne.call("question"))
	assert_null(royal.search(q.trim_prefix("Graf Mopsula: ")), "name entry: " + q)
	(ne as Node).free()
	var idle: PackedStringArray = (load("res://scenes/safe_room/safe_room.gd") as GDScript).get_script_constant_map()[
		"DEFAULT_IDLE"]
	for t: String in idle:
		assert_null(royal.search(t), "safe-room fallback: " + t)
		assert_eq(IpWords.mopsula_word(t), "", t)
	var intro: String = FileAccess.get_file_as_string("res://scenes/title/intro.gd")
	var said: RegEx = RegEx.create_from_string("\\[\"mopsula\", \"([^\"]*)\"")
	var n: int = 0
	for m: RegExMatch in said.search_all(intro):
		n += 1
		assert_null(royal.search(m.get_string(1)), "intro: " + m.get_string(1))
		assert_eq(IpWords.mopsula_word(m.get_string(1)), "", m.get_string(1))
	assert_gt(n, 2, "the intro's Mopsula lines were found")


## Follow-up: the live line filter (res://data/mod_filter.json, ModLineFilter / mod-brain safety.py) blocks every word
## of the validator's lists — a live M.O.D. line cannot say what a written one must not.
func test_live_filter_covers_the_validator_lists() -> void:
	for w: String in IpWords.ALL_WORDS:
		assert_eq(ModLineFilter.check("Heute gibt es %s im Studio." % w), "blocked_ip_distance", w)
	for w: String in IpWords.ORIGIN_WORDS:
		var why: String = ModLineFilter.check("Heute gibt es %s im Studio." % w)
		assert_true(why == "blocked_origin" or why == "blocked_slurs", "%s: %s" % [w, why])
	for w: String in IpWords.MOPSULA_WORDS:
		assert_eq(ModLineFilter.check("Der Graf und die %s im Studio." % w), "blocked_mopsula_royalty", w)
		assert_eq(ModLineFilter.check("Die %s im Studio, sehr hübsch." % w, {}, "mopsula"), "blocked_mopsula_royalty", w)
		assert_eq(ModLineFilter.check("Die %s im Studio, sehr hübsch." % w, {}, "mod"), "", w + ": not about him")


## Follow-up: Graf Mopsula's class and the Liga boss achievement, renamed (ids, names, references).
func test_follow_up_names() -> void:
	var d: GameData = real_data()
	assert_false(d.has_id("classes", "cls_mop_diva"), "the diva id is gone")
	assert_eq(d.class_def("cls_mop_zeremonienmeister").name, "Zeremonienmeister")
	assert_eq(d.class_def("cls_mop_zeremonienmeister").desc,
		"Buffs mit Protokoll. Sponsoren kommen früher, Applaus sowieso.")
	assert_eq(d.class_def("cls_mop_zeremonienmeister").show_mods["sponsor_thresholds"], [65, 80, 95], "same values")
	for sp: String in ["spc_mop_spukmops", "spc_mop_flattermops"]:
		assert_has(d.species_def(sp).recommended_classes, "cls_mop_zeremonienmeister", sp)
	assert_eq(d.achievement("ach_ul_boss").name, "Ohne Netz und doppelten Boden")
	for l: ModLineDef in d.mod_lines("achievement:ach_ul_boss"):
		assert_false(l.text.to_lower().contains("brise"), l.id)


## Follow-up: the shelter is "Tierheim Pfotenglück" (GDD §1.2) — the intro caption included, nowhere "Lindenhof".
func test_the_shelter_is_pfotenglueck() -> void:
	var intro: String = FileAccess.get_file_as_string("res://scenes/title/intro.gd")
	assert_true(intro.contains("TIERHEIM PFOTENGLÜCK"), "intro caption")
	var files: PackedStringArray = _gd_files("res://scenes")
	files.append_array(_gd_files("res://autoload"))
	for t: String in GameData.TABLES:
		files.append("res://data/%s.json" % t)
	for f: String in files:
		assert_false(FileAccess.get_file_as_string(f).to_lower().contains("lindenhof"), f)


## Code strings (screens, autoloads): no "Fan-Box", "Feinripp", barefoot or shoe word in any string literal.
func test_code_string_literals_avoid_the_ip_words() -> void:
	var lit: RegEx = RegEx.create_from_string("\"((?:[^\"\\\\]|\\\\.)*)\"")
	var files: PackedStringArray = []
	for dir: String in CODE_DIRS:
		files.append_array(_gd_files(dir))
	assert_gt(files.size(), 30, "scanned the screens")
	for f: String in files:
		var lines: PackedStringArray = FileAccess.get_file_as_string(f).split("\n")
		for i in lines.size():
			var line: String = lines[i].strip_edges()
			if line.begins_with("#"):
				continue
			for m: RegExMatch in lit.search_all(line):
				var w: String = IpWords.general_word(m.get_string(1))
				assert_eq(w, "", "%s:%d: '%s'" % [f, i + 1, m.get_string(1)])


func _gd_files(dir: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var da: DirAccess = DirAccess.open(dir)
	if da == null:
		return out
	for f: String in da.get_files():
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for sub: String in da.get_directories():
		out.append_array(_gd_files(dir.path_join(sub)))
	return out


func _mopsula_voice_lines(d: GameData) -> Array[ModLineDef]:
	var out: Array[ModLineDef] = []
	var raw: Variant = JsonUtil.read_file("res://data/mod_lines.json")
	var tags: Dictionary = {}
	for e: Dictionary in (raw as Dictionary)["entries"]:
		if str(e.get("voice", "")) == "mopsula":
			tags[str(e["tag"])] = true
	for tag: Variant in tags:
		for l: ModLineDef in d.mod_lines(str(tag)):
			if l.voice == "mopsula":
				out.append(l)
	return out
