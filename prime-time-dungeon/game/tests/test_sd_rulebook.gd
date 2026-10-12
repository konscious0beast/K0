extends TestCase
## 10 §6.9 test_sd_rulebook (SD2-A): the rulebook data/stempel/*.json is valid (own validator, positive and negative),
## the converter builds valid engine data through GameData.load_from_dicts without errors or warnings (a formally
## valid basic attack, engine names = ids, no engine boss, Tempo 10 for everybody), rules_hash is stable and
## independent of display texts, opponent decks follow the deck rules and every card of them has an AI entry, show
## cards have cooldown 0, the unlock sources exist, the cards match the printed table of 10 §2.3, and the texts keep
## the rules of 10 §3.9 (IP words, ≤ 110 characters, placeholders, glyphs F8, short names ≤ 7 characters).

const Sx := preload("res://tests/test_sd_fixture.gd")
const IpWords := preload("res://core/data/validators/ip_words.gd")

## 10 §2.3: [id, origin, art, Werktage, Ärger per hit, hits, heal, statuses, show chance %].
const PRINTED: Array = [
	["sdc_stempel", "amt", "stempel", 1, 2, 1, 0, [], 0],
	["sdc_doppelstempel", "amt", "stempel", 2, 3, 2, 0, [], 0],
	["sdc_formular_27b", "amt", "stempel", 3, 9, 1, 0, [], 0],
	["sdc_ablehnung", "amt", "eiskalt", 3, 9, 1, 0, [], 0],
	["sdc_wiedervorlage", "amt", "verwaltung", 2, 0, 1, 0, ["sts_sd_wiedervorlage"], 0],
	["sdc_kleingedrucktes", "amt", "papierkram", 2, 2, 1, 0, ["sts_sd_kleingedrucktes"], 0],
	["sdc_durchatmen", "amt", "verwaltung", 2, 0, 1, 8, [], 0],
	["sdc_umlaufmappe", "amt", "verwaltung", 1, 0, 1, 0, [], 0],
	["sdc_wuchtschlag", "kandidat", "stempel", 4, 13, 1, 0, [], 0],
	["sdc_leinen", "kandidat", "stempel", 3, 3, 1, 0, ["sts_sd_vorschrift"], 0],
	["sdc_erste_hilfe", "kandidat", "verwaltung", 2, 0, 1, 10, [], 0],
	["sdc_kabelpeitsche", "kandidat", "rohrpost", 4, 6, 1, 0, ["sts_sd_wiedervorlage"], 0],
	["sdc_suplex", "kandidat", "stempel", 4, 26, 1, 0, [], 60],
	["sdc_adelsflamme", "graf", "eilt", 3, 10, 1, 0, [], 0],
	["sdc_schlabbern", "graf", "verwaltung", 3, 0, 1, 12, [], 0],
	["sdc_frostniesen", "graf", "eiskalt", 2, 6, 1, 0, [], 0],
	["sdc_gutachten", "graf", "verwaltung", 2, 0, 1, 0, ["sts_sd_eilvermerk"], 0],
	["sdc_auftritt", "graf", "eilt", 4, 24, 1, 0, [], 55],
	["sdc_werbepflaster", "gegenstand", "verwaltung", 1, 0, 1, 5, [], 0],
	["sdc_gegengift", "gegenstand", "verwaltung", 1, 0, 1, 3, [], 0],
	["sdc_kaeltespray", "gegenstand", "eiskalt", 1, 2, 1, 0, [], 0],
	["sdc_kaffee", "talent", "verwaltung", 1, 0, 1, 3, ["sts_sd_eilvermerk"], 0],
	["sdc_stereo", "talent", "rohrpost", 2, 3, 2, 0, [], 0],
	["sdc_amtsstempel", "trophaee", "stempel", 6, 22, 1, 0, [], 0],
]
## 10 §3.1: [id, Geduld, element_mods, immune, short].
const OPPONENTS: Array = [
	["sdo_ferdi", 36, {"fire": 1.5}, [], "FERDI"],
	["sdo_graf", 40, {"ice": 0.5}, [], "GRAF"],
	["sdo_ulla", 50, {"ice": 1.5, "physical": 0.5}, ["sts_sd_wiedervorlage"], "ULLA"],
	["sdo_meister", 50, {"shock": 1.5, "fire": 0.5}, [], "MEISTER"],
]


func _book(f: Dictionary, campaign: GameData = null) -> SdRulebook:
	return SdRulebook.from_files(f, campaign)


## The first error of a mutated rulebook containing `needle` — fails otherwise.
func _expect(f: Dictionary, needle: String, what: String, campaign: GameData = null) -> void:
	var b: SdRulebook = _book(f, campaign)
	for e: String in b.errors:
		if e.contains(needle):
			assert_false(b.is_valid(), what + ": invalid")
			return
	fail("%s: expected an error containing '%s', got [%s]" % [what, needle, "; ".join(b.errors)])


func test_the_rulebook_loads_without_errors_or_warnings() -> void:
	var b: SdRulebook = SdRulebook.load_dir(SdRulebook.DIR, real_data())
	assert_eq(b.errors, PackedStringArray(), "no errors")
	assert_eq(b.warnings, PackedStringArray(), "no warnings (engine included)")
	assert_true(b.is_valid())
	assert_len(b.card_ids, 24, "24 cards (10 §2.3)")
	assert_eq(Array(b.opponent_ids), ["sdo_ferdi", "sdo_graf", "sdo_ulla", "sdo_meister"], "4 opponents (10 §3)")
	assert_eq(Array(b.status_ids), ["sts_sd_wiedervorlage", "sts_sd_vorschrift", "sts_sd_eilvermerk",
		"sts_sd_kleingedrucktes"], "the 4 states (10 §1.6)")
	assert_eq(str(b.durchsage.get("id", "")), "pu_sd_durchsage")
	var n: int = 0
	for tag: Variant in b.lines.keys():
		n += (b.lines[tag] as Array).size()
	assert_between(n, 80, 140, "≈ 80 lines of M.O.D., the Graf, the opponents and the chat")
	assert_len(b.award_ids, 10, "10 Dienstauszeichnungen (10 §5.2)")
	assert_gt(b.cosmetic_ids.size(), 9, "cosmetics as data")
	assert_eq(b.campaign_problems(real_data()), PackedStringArray(), "every campaign source id exists")
	assert_true(SdRulebook.shared().is_valid(), "the shared rulebook")


func test_the_engine_data() -> void:
	var b: SdRulebook = Sx.book()
	var data: GameData = b.data
	assert_true(data.is_valid(), "GameData.load_from_dicts without errors")
	assert_eq(data.warnings, PackedStringArray(), "… and without warnings")
	var atk: SkillDef = data.skill(SdRulebook.BASIC_ATTACK)
	assert_eq([atk.category, atk.damage_type, atk.element, atk.target, atk.power, atk.rank],
		["attack", "physical", "physical", "single_enemy", 100, 3], "a formally valid basic attack (10 §6.4)")
	for s: SkillDef in data.all_skills():
		assert_eq(s.name, s.id, "engine skill names are ids: " + s.id)
		assert_eq([s.user, s.mp_cost], ["any", 0], s.id)
	for st: StatusDef in data.all_statuses():
		assert_eq(st.name, st.id, "engine status names are ids")
	var enemy_ids: PackedStringArray = data.ids("enemies")
	assert_eq(Array(enemy_ids), ["enm_sd_lernduell", "enm_sdo_ferdi", "enm_sdo_graf", "enm_sdo_meister",
		"enm_sdo_ulla"], "one enemy per opponent + the Lernduell's Ferdi")
	for eid: String in enemy_ids:
		var e: EnemyDef = data.enemy(eid)
		assert_eq(e.name, eid, "engine enemy names are ids")
		assert_false(e.boss, eid + " is no engine boss (SD-14)")
		assert_eq(JsonUtil.to_int(e.stats["spd"]), 10, eid + ": Tempo 10 for everybody")
		assert_eq(e.attack_skill, SdRulebook.BASIC_ATTACK)
	for row: Array in OPPONENTS:
		var e: EnemyDef = data.enemy("enm_" + str(row[0]))
		assert_eq(JsonUtil.to_int(e.stats["hp"]), int(row[1]), "%s: Geduld" % row[0])
		assert_eq(e.element_mods, row[2], "%s: Zuständigkeiten" % row[0])
		assert_eq(Array(e.status_immune), row[3], "%s: immunities" % row[0])
	assert_eq(JsonUtil.to_int(data.enemy(SdRulebook.TUTORIAL_ENEMY).stats["hp"]), 26,
		"the Lernduell's Ferdi has 26 Geduld (Stempel 2 + 27b 9 + Adelsflamme 15)")
	assert_true(data.enemy("enm_sdo_meister").is_phased(), "the Stempelmeister has phases")
	var pu: PseudoUnitDef = data.pseudo_unit("pu_sd_durchsage")
	assert_eq([pu.name, JsonUtil.to_int(pu.action["fixed_pct_maxhp"]), pu.ctr_after, pu.warn_at, pu.warn_tag],
		["pu_sd_durchsage", 8, 100, 2, "sd_durchsage_warn"], "the Durchsage (10 §3.4)")
	for cid: String in b.card_ids:
		var c: SdCardDef = b.card(cid)
		var s: SkillDef = data.skill(c.skill_id())
		assert_not_null(s, cid)
		if c.show:
			assert_eq([s.category, s.cooldown, s.success_lck], ["stunt", 0, 0.0], cid + ": stunt with cooldown 0")
		assert_eq(b.card_of_skill(c.skill_id()), cid)


func test_the_cards_match_the_printed_table() -> void:
	var b: SdRulebook = Sx.book()
	for row: Array in PRINTED:
		var c: SdCardDef = b.card(str(row[0]))
		if c == null:
			fail("missing card " + str(row[0]))
			continue
		var origin_ok: bool = c.origin == str(row[1])
		assert_true(origin_ok, "%s origin %s" % [c.id, c.origin])
		assert_eq([c.art, c.rank(), c.power(), c.hits(), c.heal(), Array(c.status_ids())],
			[row[2], row[3], row[4], row[5], row[6], row[7]], c.id + " (10 §2.3)")
		assert_eq(c.show, int(row[8]) > 0, c.id + " show")
		if c.show:
			assert_eq(c.chance_pm(), int(row[8]) * 10, c.id + " chance")
		assert_eq(c.element(), str(SdCardDef.ART_ELEMENTS[c.art]), c.id + ": element of the Formular-Art")
		assert_true(c.max_copies <= (1 if c.show else 2), c.id + " copies")
	assert_eq(b.card("sdc_umlaufmappe").hand, "refresh", "the Umlaufmappe changes the hand")
	assert_eq(b.card("sdc_gutachten").status_turns("sts_sd_eilvermerk"), 3, "Gutachten: this and 2 cards")
	assert_eq(b.card("sdc_kaffee").status_turns("sts_sd_eilvermerk"), 2, "Kaffee: this and 1 card")
	assert_eq(Array(b.card("sdc_erste_hilfe").cleanses()), ["sts_sd_kleingedrucktes"])
	assert_eq(Array(b.card("sdc_gegengift").cleanses()), ["sts_sd_kleingedrucktes"])


func test_rules_hash_is_stable_and_independent_of_texts() -> void:
	var h0: String = Sx.book().rules_hash
	assert_true(RegEx.create_from_string("^[0-9a-f]{64}$").search(h0) != null, "sha-256: " + h0)
	assert_eq(_book(Sx.files()).rules_hash, h0, "a second load gives the same hash")
	var texts: Dictionary = Sx.files()
	Sx.entry(texts, "cards", "sdc_stempel")["name"] = "Stempelchen"
	Sx.entry(texts, "cards", "sdc_formular_27b")["quip"] = "Ein anderer Spruch."
	Sx.entry(texts, "cards", "sdc_wiedervorlage")["text"] = "Ein anderer Kartentext."
	Sx.entry(texts, "opponents", "sdo_ulla")["name"] = "Ulla Rundschreiben"
	Sx.entry(texts, "opponents", "sdo_ulla")["akte"] = "Eine andere Akte."
	Sx.entry(texts, "cosmetics", "sdk_back_monokel")["name"] = "Zwicker"
	var line: Dictionary = ((texts["lines"] as Dictionary)["entries"] as Array)[0]
	line["text"] = "Ein anderer Satz von M.O.D."
	((texts["rules"] as Dictionary)["statuses"] as Array)[0]["name"] = "Termin"
	var tb: SdRulebook = _book(texts)
	assert_true(tb.is_valid(), "texts changed: %s" % "; ".join(tb.errors))
	assert_eq(tb.rules_hash, h0, "names, quips, lines, cosmetics and status names stay out of rules_hash")
	var mech: Array = [
		["cards", "sdc_stempel", "skill", "power", 3],
		["opponents", "sdo_ferdi", "", "geduld", 37],
		["cards", "sdc_suplex", "skill", "success_base", 0.65],
	]
	for m: Array in mech:
		var f: Dictionary = Sx.files()
		var e: Dictionary = Sx.entry(f, str(m[0]), str(m[1]))
		if str(m[2]) != "":
			e = e[str(m[2])]
		e[str(m[3])] = m[4]
		var mb: SdRulebook = _book(f)
		assert_true(mb.is_valid(), "%s: %s" % [str(m), "; ".join(mb.errors)])
		assert_ne(mb.rules_hash, h0, "a mechanic changes the hash: %s" % str(m))
	var f2: Dictionary = Sx.files()
	var ai: Dictionary = Sx.entry(f2, "opponents", "sdo_ferdi")["ai"]
	((ai["actions"] as Array)[3] as Dictionary)["weight"] = 5
	assert_ne(_book(f2).rules_hash, h0, "an AI weight changes the hash")
	var f3: Dictionary = Sx.files()
	((f3["rules"] as Dictionary)["constants"] as Dictionary)["dienstschluss"] = 81
	assert_ne(_book(f3).rules_hash, h0, "a constant changes the hash")


func test_opponent_decks_follow_the_rules_and_every_card_has_an_ai_entry() -> void:
	var b: SdRulebook = Sx.book()
	for oid: String in b.opponent_ids:
		var o: SdOpponentDef = b.opponent(oid)
		var deck: PackedStringArray = o.deck_list()
		assert_len(deck, 20, oid + ": 20 cards")
		assert_eq(b.deck_problem(deck), "", oid + ": deck rules")
		var lists: Array = o.action_lists()
		assert_eq(lists.size(), 3 if oid == "sdo_meister" else 1, oid + ": action lists")
		for actions: Variant in lists:
			var covered: Dictionary = {}
			for a: Variant in (actions as Array):
				var cid: String = b.card_of_skill(str((a as Dictionary)["skill"]))
				assert_true(deck.has(cid), "%s: the AI plays only deck cards (%s)" % [oid, cid])
				covered[cid] = true
			for cid: String in deck:
				assert_true(covered.has(cid), "%s: %s has an AI entry" % [oid, cid])
		for cid: String in deck:
			assert_false(b.card(cid).show, oid + ": no show cards (10 §1.7)")
	var tut: PackedStringArray = JsonUtil.to_str_array(b.tutorial["opponent_deck"])
	assert_eq(b.deck_problem(tut), "", "the Lernduell's Ferdi deck")
	assert_eq(b.deck_problem(JsonUtil.to_str_array(b.tutorial["player_deck"])), "", "the Lernduell's player deck")
	var sorted_tut: PackedStringArray = JsonUtil.to_str_array(b.tutorial["player_deck"])
	sorted_tut.sort()
	assert_eq(sorted_tut, b.startmappe_list(), "the Lernduell plays the Startmappe in a fixed order")


func test_unlock_sources_and_the_startmappe() -> void:
	var b: SdRulebook = Sx.book()
	assert_len(b.grundakte, 12, "Grundakte: 12 cards (10 §2.4)")
	assert_eq(b.startmappe_list().size(), 20)
	assert_eq(b.deck_problem(b.startmappe_list()), "")
	for cid: String in b.startmappe_list():
		assert_has(b.grundakte, cid, "Startmappe ⊆ Grundakte")
	var reachable: Dictionary = {}
	for cid: String in b.grundakte:
		reachable[cid] = true
	for id: String in b.heft:
		reachable[id] = true
		assert_true(b.card(id) != null or b.cosmetics.has(id), "heft entry " + id)
	for oid: String in b.opponent_ids:
		for cid: String in b.opponent(oid).first_win_cards():
			reachable[cid] = true
		for kid: String in b.opponent(oid).first_win_cosmetics():
			assert_true(b.cosmetics.has(kid), oid + " first win cosmetic " + kid)
	for cid: String in b.card_ids:
		assert_true(reachable.has(cid), cid + " comes without the campaign (10 §2.5)")
	assert_eq(Array(b.heft.slice(0, 5)), ["sdc_frostniesen", "sdc_erste_hilfe", "sdc_kaffee", "sdc_suplex",
		"sdc_auftritt"], "the Stempelheft order (10 §2.5)")
	assert_eq(Array(b.opponent("sdo_ferdi").first_win_cards()), ["sdc_gegengift", "sdc_schlabbern"])
	assert_eq(Array(b.opponent("sdo_meister").first_win_cards()), ["sdc_amtsstempel"])
	var followers: int = 0
	for oid: String in b.opponent_ids:
		followers += JsonUtil.to_int(b.opponent(oid).season_win.get("followers", 0))
	assert_eq(followers, 50, "10 / 0 / 15 / 25 followers, at most 50 per season (10 §5.3)")


func test_texts_keep_the_rules() -> void:
	var b: SdRulebook = Sx.book()
	var font: Font = ThemeDB.fallback_font
	var texts: Array = []
	for cid: String in b.card_ids:
		var c: SdCardDef = b.card(cid)
		texts.append_array([c.name, c.text, c.quip])
	for oid: String in b.opponent_ids:
		var o: SdOpponentDef = b.opponent(oid)
		texts.append_array([o.name, o.role, o.akte, o.rule, o.short])
		assert_between(o.short.length(), 1, 7, oid + ": short name ≤ 7 characters (10 §3.1)")
		assert_eq(o.short, o.short.to_upper(), oid + ": short name upper case")
	for sid: String in b.status_ids:
		texts.append_array([str(b.statuses[sid]["name"]), str(b.statuses[sid]["text"])])
	texts.append_array([str(b.durchsage["name"]), str(b.durchsage["text"]), str(b.durchsage["short"])])
	for id: String in b.cosmetic_ids:
		texts.append_array([str(b.cosmetics[id]["name"]), str(b.cosmetics[id]["desc"])])
	for id: String in b.award_ids:
		texts.append_array([str(b.awards[id]["name"]), str(b.awards[id]["desc"])])
	var placeholder: RegEx = RegEx.create_from_string("\\{([a-z_]+)\\}")
	for tag: Variant in b.lines.keys():
		for l: Dictionary in b.lines[tag]:
			var t: String = str(l["text"])
			texts.append(t)
			assert_between(t.length(), 1, 110, str(l["id"]))
			for m: RegExMatch in placeholder.search_all(t):
				assert_has(["opp", "ticket", "card", "count", "name"], m.get_string(1), str(l["id"]))
	for v: Variant in texts:
		var t: String = str(v)
		assert_true(t.length() <= 110, "≤ 110 characters: " + t)
		assert_eq(IpWords.general_word(t), "", "IP / tone word in: " + t)
		assert_eq(IpWords.mopsula_word(t), "", "royalty motif in: " + t)
		for word: String in ["Carl", "Donut", "Crawler", "Fan-Box", "A38", "Passierschein"]:
			assert_false(t.contains(word), "%s in: %s" % [word, t])
		for i in t.length():
			if t.unicode_at(i) >= 32 and not font.has_char(t.unicode_at(i)):
				fail("glyph %s the font lacks (03_ART F8) in: %s" % [t[i], t])


func test_lines_cover_every_tag_the_code_names() -> void:
	var b: SdRulebook = Sx.book()
	for tag: String in ["sd_boss_intro", "sd_boss_phase:2", "sd_boss_phase:3", "sd_durchsage_warn", "sd_explain",
			"sd_turn_player", "sd_turn_opp", "sd_win", "sd_loss", "sd_dienstschluss", "sd_forfeit", "sd_tie"]:
		assert_gt(b.lines_for(tag).size(), 0, tag)
	for reason: String in SdAi.HINTS:
		assert_gt(b.lines_for("sd_hint:" + reason).size(), 0, "the Graf's footnote for hint " + reason)
	for l: Variant in b.tutorial["lessons"]:
		assert_gt(b.lines_for(str((l as Dictionary)["line"])).size(), 0, "lesson line")
	for oid: String in b.opponent_ids:
		for prefix: String in ["sd_opp_intro:", "sd_opp_win:", "sd_opp_lose:", "sd_akte:"]:
			assert_gt(b.lines_for(prefix + b.opponent(oid).lines).size(), 0, prefix + oid)
	for line: Dictionary in b.lines_for("sd_tut_note:2") + b.lines_for("sd_hint:file"):
		assert_eq(str(line["voice"]), "mopsula", "the Graf speaks his footnotes")
	assert_eq(str(b.lines_for("sd_explain")[0]["text"]),
		"Stempelduell an Schalter 3! Lange Formulare, lange Wartezeit. Wer zuerst die Geduld verliert, verliert.",
		"the one-sentence explanation (10 §0.4)")


func test_the_validator_rejects_bad_data() -> void:
	var cases: Array = [
		["cards", "sdc_suplex", "skill", "cooldown", null, "cooldown 0 explicitly"],
		["cards", "sdc_ablehnung", "skill", "element", "physical", "is element ice"],
		["cards", "sdc_ablehnung", "", "bogus", 1, "unknown key"],
		["cards", "sdc_stempel", "skill", "anim", "attack", "not a mechanical skill field"],
		["cards", "sdc_stempel", "skill", "rank", 7, "1..6 Werktage"],
		["cards", "sdc_formular_27b", "", "quip", "Bitte den Passierschein A38 vorlegen.", "passierschein"],
		["cards", "sdc_adelsflamme", "", "quip", "Eine Krone für die Ablage.", "royalty"],
		["cards", "sdc_stempel", "", "name", "Carl stempelt", "names 'Carl'"],
		["cards", "sdc_stempel", "", "text", "Gilt beim Finanzamt.", "finanzamt"],
		["cards", "sdc_stempel", "", "text", "2 Ärger → sofort.", "glyph"],
		["cards", "sdc_kaeltespray", "", "max_copies", 3, "max_copies"],
		["cards", "sdc_suplex", "", "max_copies", 2, "max_copies"],
		["opponents", "sdo_ulla", "", "short", "ABTEILUNG", "upper-case characters"],
		["opponents", "sdo_ulla", "", "boss", true, "no engine boss flag"],
		["opponents", "sdo_ferdi", "", "element_mods", {"fire": 2.0}, "Wunder Punkt 1.5"],
		["opponents", "sdo_ferdi", "", "role", "Ein Crawler am Schalter", "crawler"],
		["opponents", "sdo_meister", "", "unlock_after", "sdo_niemand", "unknown opponent"],
		["opponents", "sdo_ferdi", "season_win", "followers", 99, "at most 50"],
	]
	for c: Array in cases:
		var f: Dictionary = Sx.files()
		var e: Dictionary = Sx.entry(f, str(c[0]), str(c[1]))
		if str(c[2]) != "":
			e = e[str(c[2])]
		if c[4] == null:
			e.erase(str(c[3]))
		else:
			e[str(c[3])] = c[4]
		_expect(f, str(c[5]), "%s %s.%s" % [c[1], c[2], c[3]])
	var f1: Dictionary = Sx.files()
	(Sx.entry(f1, "opponents", "sdo_ferdi")["deck"] as Dictionary)["sdc_stempel"] = 1
	_expect(f1, "19 cards (exactly 20", "a 19-card opponent deck")
	var f2: Dictionary = Sx.files()
	var d2: Dictionary = Sx.entry(f2, "opponents", "sdo_ferdi")["deck"]
	d2.erase("sdc_gegengift")
	d2["sdc_suplex"] = 1
	d2["sdc_auftritt"] = 1
	_expect(f2, "is a show card", "show cards in an opponent deck")
	var f3: Dictionary = Sx.files()
	var acts: Array = (Sx.entry(f3, "opponents", "sdo_ferdi")["ai"] as Dictionary)["actions"]
	acts.remove_at(acts.size() - 1)
	_expect(f3, "'sdc_umlaufmappe' has no AI entry", "a deck card without an AI entry")
	var f4: Dictionary = Sx.files()
	((Sx.entry(f4, "opponents", "sdo_ferdi")["ai"] as Dictionary)["actions"] as Array).append(
		{"skill": "skl_sdc_wuchtschlag", "weight": 1, "target": "random"})
	_expect(f4, "is no card of this deck", "an AI entry for a card outside the deck")
	var f5: Dictionary = Sx.files()
	((Sx.entry(f5, "opponents", "sdo_ferdi")["ai"] as Dictionary)["actions"] as Array)[0]["target"] = "random"
	_expect(f5, "engine: ", "an engine rule (a heal with the target rule random)")
	var f6: Dictionary = Sx.files()
	(f6["rules"] as Dictionary)["heft"] = ["sdc_frostniesen", "sdc_erste_hilfe", "sdc_kaffee", "sdc_suplex"]
	_expect(f6, "unreachable without the campaign", "the Auftritt only via the campaign")
	var f7: Dictionary = Sx.files()
	(Sx.entry(f7, "cards", "sdc_wuchtschlag")["campaign"] as Array).append("skl_kai_gibt_es_nicht")
	_expect(f7, "unknown campaign id", "a campaign id the campaign does not know", real_data())
	var f8: Dictionary = Sx.files()
	var lines: Array = (f8["lines"] as Dictionary)["entries"]
	for i in range(lines.size() - 1, -1, -1):
		if str((lines[i] as Dictionary)["tag"]) == "sd_boss_phase:3":
			lines.remove_at(i)
	_expect(f8, "say 'sd_boss_phase:3' needs a line", "a phase line without text")
	var f9: Dictionary = Sx.files()
	var l9: Dictionary = (f9["lines"] as Dictionary)["entries"][0]
	l9["text"] = "x".repeat(111)
	_expect(f9, "longer than 110", "a line over 110 characters")
	var f10: Dictionary = Sx.files()
	(f10["lines"] as Dictionary)["entries"][1]["text"] = "Hallo {kandidat}!"
	_expect(f10, "unknown placeholder {kandidat}", "an unknown placeholder")
	var f11: Dictionary = Sx.files()
	for l: Variant in (f11["lines"] as Dictionary)["entries"]:
		if str((l as Dictionary)["voice"]) == "mopsula":
			(l as Dictionary)["text"] = "Wir sind erfreut, Kolleg:in."
			break
	_expect(f11, "royal plural", "the Graf's pluralis majestatis")
	var f12: Dictionary = Sx.files()
	(((f12["rules"] as Dictionary)["tutorial"] as Dictionary)["lessons"] as Array)[0]["card"] = "sdc_amtsstempel"
	_expect(f12, "not in the Lernduell deck", "a forced card outside the Lernduell deck")
	var f13: Dictionary = Sx.files()
	(f13["rules"] as Dictionary).erase("tutorial")
	_expect(f13, "rules.tutorial", "no Lernduell")
	var broken: Dictionary = Sx.files()
	broken["cards"] = null
	var bb: SdRulebook = _book(broken)
	assert_false(bb.is_valid(), "a missing file")
	assert_eq(bb.rules_hash, "", "no hash for an invalid rulebook")
