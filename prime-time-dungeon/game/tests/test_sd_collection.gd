extends TestCase
## 10 §6.9 test_sd_collection (SD2-B): the account collection is pure (to_dict / from_dict round trip), a broken
## file gives an empty collection, the deck rules and "Automatisch füllen" hold, the unlocks come as 10 §2.5/§5.2 say
## (Lernduell, first victories, Stempelheft, campaign, album, opponents in order, Dienstauszeichnungen), the seed
## counter moves before a duel, and the file holds catalog ids and numbers only — no names.

const Sx := preload("res://tests/test_sd_fixture.gd")


func _summary(opp: String, result: String, extra: Dictionary = {}) -> Dictionary:
	var s: Dictionary = {"opp": opp, "tut": false, "result": result, "tickets": 20, "geduld": [30, 0],
		"played": [10, 10], "filed": [1, 1], "show_ok": 0, "show_fail": 0, "wiedervorlagen": [0, 0],
		"durchsage_filed": 0, "max_chain": [2, 2]}
	s.merge(extra, true)
	return s


func test_the_lernduell_gives_the_grundakte_and_the_startmappe() -> void:
	var b: SdRulebook = Sx.book()
	var c: SdCollection = SdCollection.create(4711)
	assert_false(c.is_unlocked("sdo_ferdi", b), "nothing before the Lernduell")
	var r: Dictionary = c.complete_tutorial(b)
	assert_eq(Array(r["cards"]), Array(b.grundakte), "the Grundakte (12 cards)")
	assert_eq(Array(r["cosmetics"]), ["sdk_back_durchschlag"])
	assert_eq(Array(r["awards"]), ["sda_tutorial"])
	assert_eq(c.deck("a"), b.startmappe_list(), "the Startmappe is Mappe A")
	assert_eq(c.deck_problem(c.active_deck(), b), "", "and can be chosen")
	assert_eq(c.complete_tutorial(b), {"cards": PackedStringArray(), "cosmetics": PackedStringArray(),
		"awards": PackedStringArray(), "heft": false}, "only once")
	assert_true(c.is_unlocked("sdo_ferdi", b) and c.is_unlocked("sdo_graf", b), "Ferdi and the Graf after it")
	assert_false(c.is_unlocked("sdo_ulla", b), "Ulla after a victory over Ferdi")
	var t: SdCollection = SdCollection.create(1)
	var tr: Dictionary = t.record_duel({"opp": "sdo_ferdi", "tut": true, "result": "won"}, b)
	assert_len(tr["cards"], 12, "a won Lernduell completes the tutorial")
	assert_eq(t.heft, 0, "the Lernduell sets no stamp")


func test_victories_unlock_cards_cosmetics_opponents_and_the_heft() -> void:
	var b: SdRulebook = Sx.book()
	var c: SdCollection = SdCollection.create(1)
	c.complete_tutorial(b)
	var r: Dictionary = c.record_duel(_summary("sdo_ferdi", "won"), b)
	assert_eq(Array(r["cards"]), ["sdc_gegengift", "sdc_schlabbern"], "Ferdi's first victory (10 §2.5)")
	assert_eq(Array(r["cosmetics"]), ["sdk_ink_kopierblau"])
	assert_has(r["awards"], "sda_first_win")
	assert_true(bool(r["heft"]), "a stamp")
	assert_true(c.is_unlocked("sdo_ulla", b), "Ulla after Ferdi")
	assert_false(c.is_unlocked("sdo_meister", b))
	r = c.record_duel(_summary("sdo_ferdi", "won"), b)
	assert_eq(Array(r["cards"]), [], "the first victory pays once")
	c.apply_campaign(PackedStringArray(["skl_mop_frost_sneeze"]), b)
	r = c.record_duel(_summary("sdo_graf", "won"), b)
	assert_eq(c.heft, 3)
	assert_eq(Array(r["cards"]), ["sdc_gutachten", "sdc_stereo", "sdc_erste_hilfe"],
		"the Graf's cards + the third stamp: Erste Hilfe (Frostniesen is owned already, skipped)")
	assert_eq(Array(r["cosmetics"]), ["sdk_back_monokel"])
	assert_has(r["awards"], "sda_graf")
	assert_eq(c.next_heft_reward(b), "sdc_kaffee")
	r = c.record_duel(_summary("sdo_ulla", "lost"), b)
	assert_false(bool(r["heft"]), "a defeat sets no stamp and costs nothing")
	assert_eq(c.wins_against("sdo_ulla"), 0)
	r = c.record_duel(_summary("sdo_ulla", "adjourned"), b)
	assert_eq(int(c.stats["loss_streak"]), 1, "an adjourned duel changes nothing")
	r = c.record_duel(_summary("sdo_ulla", "forfeit"), b)
	assert_true(c.wants_deck_tip(), "two defeats in a row: the Graf offers a tip (10 §5.5)")
	r = c.record_duel(_summary("sdo_ulla", "won"), b)
	assert_eq(Array(r["cards"]), ["sdc_leinen", "sdc_kabelpeitsche"])
	assert_true(c.is_unlocked("sdo_meister", b), "the Stempelmeister after Ulla")
	assert_false(c.wants_deck_tip())
	r = c.record_duel(_summary("sdo_meister", "won"), b)
	assert_eq(Array(r["cards"]), ["sdc_amtsstempel"], "the trophy")
	assert_eq(Array(r["cosmetics"]), ["sdk_title_stempelmeisterin", "sdk_ink_gold"], "title and gold ink")
	assert_has(r["awards"], "sda_amt", "Ferdi, Ulla and the Stempelmeister beaten")
	# Every remaining heft entry: cards, then cosmetics; then the album.
	var guard: int = 0
	while c.next_heft_reward(b) != "" and guard < 60:
		guard += 1
		r = c.record_duel(_summary("sdo_ferdi", "won"), b)
	assert_eq(c.next_heft_reward(b), "", "the heft is complete")
	assert_eq(c.owned.size(), 24, "all 24 cards without the campaign beyond one id")
	for id: String in ["sdk_back_wartemarke", "sdk_back_rohrpost", "sdk_back_durchsage", "sdk_mat_gummibaum",
			"sdk_title_vollstaendige_akte", "sdk_back_goldschnitt"]:
		assert_true(c.owns_cosmetic(id), id)


func test_awards_of_a_duel() -> void:
	var b: SdRulebook = Sx.book()
	var c: SdCollection = SdCollection.create(1)
	c.complete_tutorial(b)
	var r: Dictionary = c.record_duel(_summary("sdo_graf", "won", {"filed": [0, 3], "geduld": [3, 0],
		"max_chain": [3, 1], "wiedervorlagen": [3, 0], "durchsage_filed": 1, "show_ok": 2}), b)
	for a: String in ["sda_first_win", "sda_no_file", "sda_close", "sda_chain", "sda_termin", "sda_durchsage",
			"sda_graf"]:
		assert_has(r["awards"], a)
	assert_false((r["awards"] as PackedStringArray).has("sda_show_5"), "2 show cards so far")
	r = c.record_duel(_summary("sdo_graf", "lost", {"show_ok": 3}), b)
	assert_eq(Array(r["awards"]), ["sda_show_5"], "5 show cards in total, even in a lost duel")
	r = c.record_duel(_summary("sdo_graf", "won", {"filed": [0, 0], "max_chain": [5, 0]}), b)
	assert_eq(Array(r["awards"]), [], "each award once")
	assert_eq(Array(c.awards).size(), 9)


func test_the_campaign_unlocks_by_id() -> void:
	var b: SdRulebook = Sx.book()
	var c: SdCollection = SdCollection.create(1)
	var new_cards: PackedStringArray = c.apply_campaign(PackedStringArray(["skl_kai_heavy_swing", "itm_antidote",
		"tal_mop_stereo", "skl_kai_taunt", "itm_ice_spray"]), b)
	assert_eq(Array(new_cards), ["sdc_wuchtschlag", "sdc_gegengift", "sdc_kaeltespray", "sdc_stereo"],
		"skills, items, talents → cards (10 §2.5), unknown ids ignored")
	assert_eq(Array(c.campaign_seen), ["itm_antidote", "itm_ice_spray", "skl_kai_heavy_swing", "tal_mop_stereo"])
	assert_eq(Array(c.apply_campaign(PackedStringArray(["skl_kai_heavy_swing"]), b)), [], "once")


func test_deck_rules_and_auto_fill() -> void:
	var b: SdRulebook = Sx.book()
	var c: SdCollection = SdCollection.create(1)
	c.complete_tutorial(b)
	var start: PackedStringArray = b.startmappe_list()
	assert_eq(c.deck_problem(start.slice(0, 17), b), "Noch 3 Karten bis 20.")
	assert_eq(c.deck_problem(start.slice(0, 19), b), "Noch 1 Karte bis 20.")
	var three: PackedStringArray = start.slice(0, 17)
	three.append_array(PackedStringArray(["sdc_doppelstempel", "sdc_doppelstempel", "sdc_doppelstempel"]))
	assert_eq(c.deck_problem(three, b), "Höchstens 2 × Doppelstempel.")
	var foreign: PackedStringArray = start.slice(0, 19)
	foreign.append("sdc_suplex")
	assert_eq(c.deck_problem(foreign, b), "Nicht im Besitz: Bahnsteig-Suplex.")
	var more: PackedStringArray = start.duplicate()
	more.append("sdc_stempel")
	assert_eq(c.deck_problem(more, b), "1 Karte zu viel (genau 20).")
	c.unlock_cards(PackedStringArray(["sdc_suplex"]), b)
	var two_show: PackedStringArray = start.slice(0, 18)
	two_show.append_array(PackedStringArray(["sdc_suplex", "sdc_suplex"]))
	assert_eq(c.deck_problem(two_show, b), "Höchstens 1 × Bahnsteig-Suplex.", "show cards at most once")
	var filled: PackedStringArray = c.auto_fill(PackedStringArray(), b)
	assert_eq(c.deck_problem(filled, b), "", "Automatisch füllen gives a playable deck: %s" % str(filled))
	for cid: String in b.grundakte:
		assert_has(filled, cid, "missing Grundakte first")
	var heals: int = 0
	var arts: Dictionary = {}
	for cid: String in filled:
		heals += 1 if b.card(cid).heal() > 0 else 0
		arts[b.card(cid).art] = int(arts.get(b.card(cid).art, 0)) + 1
	assert_true(heals >= 3, "heals at least 3")
	assert_eq(c.auto_fill(PackedStringArray(), b), filled, "a fixed rule (no dice)")
	var kept: PackedStringArray = c.auto_fill(PackedStringArray(["sdc_suplex", "sdc_amtsstempel", "sdc_suplex"]), b)
	assert_eq(kept[0], "sdc_suplex", "the given part stays")
	assert_eq(kept.count("sdc_suplex"), 1, "… within the copy limit; unowned cards are dropped")
	assert_false(kept.has("sdc_amtsstempel"))
	assert_eq(c.deck_problem(kept, b), "")
	var empty: SdCollection = SdCollection.create(1)
	assert_eq(empty.auto_fill(PackedStringArray(), b), PackedStringArray(), "nothing owned, nothing to fill")


func test_round_trip_and_broken_files() -> void:
	var b: SdRulebook = Sx.book()
	var c: SdCollection = SdCollection.create(123456789)
	c.complete_tutorial(b)
	c.record_duel(_summary("sdo_ferdi", "won"), b)
	c.apply_campaign(PackedStringArray(["tal_kai_kaffee"]), b)
	c.set_deck("b", c.auto_fill(PackedStringArray(), b))
	c.set_active("b")
	c.equip("sdk_back_durchschlag", b)
	c.set_option("text_size", 150)
	c.set_option("speed", 2)
	c.next_duel_seed()
	var d: Dictionary = c.to_dict()
	var back: SdCollection = SdCollection.from_dict(JSON.parse_string(JSON.stringify(d)), b)
	assert_false(back.was_reset)
	assert_eq(back.to_dict(), d, "to_dict → JSON → from_dict → to_dict")
	assert_eq(d.keys().size(), 14, "v, seed, n, owned, decks, active, beaten, heft, cosmetics, awards, options, "
		+ "tutorial, campaign_seen, stats")
	for broken: Variant in [null, "kaputt", 42, [], {}, {"v": 2, "owned": [], "decks": {}},
			{"v": 1, "owned": "sdc_stempel", "decks": {}}, {"v": 1, "owned": [], "decks": []}]:
		var e: SdCollection = SdCollection.from_dict(broken, b)
		assert_true(e.was_reset, "broken file %s → empty collection" % str(broken))
		assert_eq([e.owned.size(), e.tutorial, e.seed], [0, false, 0])
	var dirty: Dictionary = d.duplicate(true)
	(dirty["owned"] as Array).append("sdc_gibt_es_nicht")
	(dirty["decks"] as Dictionary)["a"] = ["sdc_stempel", "sdc_unbekannt"]
	(dirty["cosmetics"] as Dictionary)["back"] = "sdk_back_goldschnitt"
	(dirty["options"] as Dictionary)["text_size"] = 200
	(dirty["beaten"] as Dictionary)["sdo_niemand"] = 3
	var clean: SdCollection = SdCollection.from_dict(dirty, b)
	assert_false(clean.owns("sdc_gibt_es_nicht"), "unknown cards are dropped")
	assert_eq(Array(clean.deck("a")), ["sdc_stempel"])
	assert_eq(str(clean.cosmetics["back"]), "", "an unowned cosmetic is not equipped")
	assert_eq(int(clean.options["text_size"]), 100, "an invalid option falls back")
	assert_false(clean.beaten.has("sdo_niemand"))
	assert_false(c.equip("sdk_back_goldschnitt", b), "only owned cosmetics")
	assert_false(c.set_option("speed", 3))
	assert_false(c.set_option("volume", 1))
	assert_false(c.set_deck("d", PackedStringArray()))


func test_the_seed_counter_moves_before_the_duel() -> void:
	var c: SdCollection = SdCollection.create(99)
	var s0: int = c.next_duel_seed()
	assert_eq(c.n, 1, "the counter is up before the duel starts — save now")
	assert_eq(JsonUtil.to_int(c.to_dict()["n"]), 1)
	var s1: int = c.next_duel_seed()
	assert_ne(s0, s1, "a restart never deals the same duel again")
	assert_eq(s0, SeedUtil.derive(99, "sd", 0), "derive(account seed, \"sd\", n) (10 §6.6)")
	var again: SdCollection = SdCollection.create(99)
	assert_eq(again.next_duel_seed(), s0, "deterministic")


func test_the_file_holds_ids_and_numbers_only() -> void:
	var b: SdRulebook = Sx.book()
	var c: SdCollection = SdCollection.create(5)
	c.complete_tutorial(b)
	for opp: String in b.opponent_ids:
		c.record_duel(_summary(opp, "won", {"max_chain": [4, 0], "filed": [0, 0]}), b)
	c.apply_campaign(PackedStringArray(["skl_mop_frost_sneeze", "itm_bandage"]), b)
	var ids: RegEx = RegEx.create_from_string("^((sdc|sdo|sdk|sda|skl|itm|tal)_[a-z0-9_]+|[abc]|[0-9]+|)$")
	var strings: PackedStringArray = []
	_strings(c.to_dict(), strings)
	assert_gt(strings.size(), 30, "the scan sees the file")
	for s: String in strings:
		assert_true(ids.search(s) != null, "only catalog ids and numbers in the file: '%s'" % s)
	var text: String = JSON.stringify(c.to_dict())
	for name: String in ["Kai", "Mopsula", "Ferdi", "Ulla", "Graf", "Kandidat"]:
		assert_false(text.contains(name), "no name: " + name)


## Every string value (keys excluded) of a nested structure.
static func _strings(v: Variant, out: PackedStringArray) -> void:
	match typeof(v):
		TYPE_STRING:
			out.append(str(v))
		TYPE_DICTIONARY:
			for k: Variant in (v as Dictionary).keys():
				_strings((v as Dictionary)[k], out)
		TYPE_ARRAY:
			for e: Variant in (v as Array):
				_strings(e, out)
