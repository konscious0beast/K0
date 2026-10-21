extends TestCase
## 10 §6.9 test_sd_duel (SD2-B): the rules of 10 §1 on the adapter SdDuel around the unchanged BattleState — hand 5,
## drawing, reshuffling an empty pile, the Umlaufmappe, filing (half Ärger, a swapped card, 2 Werktage), every card of
## the rulebook against its printed effect, the four states counted in numbers (10 §1.6), Wiedervorlage "nicht
## doppelt", Zuständigkeiten, immunity, show cards (chance, Patzer), the Durchsage (warning, filing halves it), the
## phases of the Stempelmeister and the Leinen-Fallstrick against his Feierabend-Eilvermerk, ties ("Kundschaft geht
## vor"), Dienstschluss = vertagt, forfeit, the Lernduell (Geduld ≥ 1, the script), the order of the events.

const Sx := preload("res://tests/test_sd_fixture.gd")
const P: int = SdDuel.Side.PLAYER
const O: int = SdDuel.Side.OPPONENT
## Waiting time after a card in ticks by Werktage (10 §1.2: 50 ticks × WT / 3 × state factor).
const DELAY: Dictionary = {1: 17, 2: 33, 3: 50, 4: 67, 5: 83, 6: 100}
const DELAY_EIL: Dictionary = {1: 10, 2: 20, 3: 30, 4: 40}
const DELAY_SLOW: Dictionary = {1: 25, 2: 50, 3: 75, 4: 100}

var _neutral: SdRulebook = null


## The rulebook with Ferdi stripped of his Zuständigkeit: every card hits him with its printed Ärger.
func _neutral_book() -> SdRulebook:
	if _neutral == null:
		var f: Dictionary = Sx.files()
		Sx.entry(f, "opponents", "sdo_ferdi")["element_mods"] = {}
		_neutral = SdRulebook.from_files(f)
	assert_true(_neutral.is_valid(), "neutral rulebook: %s" % "; ".join(_neutral.errors))
	return _neutral


func _ctr(duel: SdDuel, side: int) -> int:
	return duel.combatant(side).ctb_counter


## The player's waiting time after the move just made: (player − opponent) after + the opponent's counter before
## (+ a Wiedervorlage it got) — counters shift together, their difference does not.
static func _player_delay(duel: SdDuel, opp_before: int, opp_extra: int) -> int:
	return duel.combatant(P).ctb_counter - duel.combatant(O).ctb_counter + opp_before + opp_extra


func test_start_deals_five_each_and_shuffles() -> void:
	var b: SdRulebook = Sx.book()
	var a: SdDuel = SdDuel.new(SdSetup.create(b, "sdo_ferdi", b.startmappe_list(), 77), b)
	var ev: Array[SdEvent] = a.start()
	assert_eq([a.hands[P].size(), a.hands[O].size(), a.decks[P].size(), a.decks[O].size()], [5, 5, 15, 15])
	assert_eq([a.discards[P].size(), a.discards[O].size(), a.shuffles[0], a.shuffles[1]], [0, 0, 1, 1])
	var drawn: Array[SdEvent] = Sx.of_kind(ev, SdEvent.Kind.CARD_DRAWN)
	assert_len(drawn, 10, "five cards each")
	for e: SdEvent in drawn:
		assert_eq(e.card_id == "", e.side == O, "the opponent's draws stay hidden")
	assert_eq(Sx.engine_of(ev, ActionEvent.Type.BATTLE_START).size(), 1)
	assert_eq(Sx.engine_of(ev, ActionEvent.Type.TURN_START).size(), 1, "the first number is called")
	assert_eq(a.ticket(), 1, "JETZT 001")
	var all: PackedStringArray = a.hands[P] + a.decks[P]
	all.sort()
	assert_eq(all, b.startmappe_list(), "the shuffled pile is the Mappe")
	var again: SdDuel = SdDuel.new(SdSetup.create(b, "sdo_ferdi", b.startmappe_list(), 77), b)
	again.start()
	assert_eq(again.hands[P] + again.decks[P], a.hands[P] + a.decks[P], "same seed, same order")
	assert_eq(again.decks[O], a.decks[O])
	var other: SdDuel = SdDuel.new(SdSetup.create(b, "sdo_ferdi", b.startmappe_list(), 78), b)
	other.start()
	assert_ne(other.hands[P] + other.decks[P], a.hands[P] + a.decks[P], "another seed, another order")
	assert_eq(Array(a.combatant(P).skills).size() + Array(a.combatant(P).stunts).size() > 0, true, "hand synced")
	var bad: Array[SdSetup] = [SdSetup.create(b, "sdo_ferdi", PackedStringArray(["sdc_stempel"]), 1),
		SdSetup.create(b, "sdo_nobody", b.startmappe_list(), 1), SdSetup.create(b, "sdo_ferdi", b.startmappe_list(), 1)]
	bad[2].rules_hash = "0".repeat(64)
	for s: SdSetup in bad:
		var n: SdDuel = SdDuel.new(s, b)
		assert_eq([n.start().size(), n.started, n.side_to_move(), n.legal_moves().size()], [0, false, -1, 0],
			"a setup with a problem does not start: " + s.problem(b))


func test_playing_draws_and_an_empty_pile_is_reshuffled() -> void:
	var b: SdRulebook = Sx.book()
	var d: SdDuel = SdDuel.new(SdSetup.create(b, "sdo_ulla", b.startmappe_list(), 5), b)
	d.start()
	var reshuffles: int = 0
	var guard: int = 0
	var rng: RandomNumberGenerator = make_rng(5)
	while not d.is_finished() and guard < 200:
		guard += 1
		var side: int = d.side_to_move()
		var ev: Array[SdEvent] = d.submit(Sx.bot_move(d, "gut", rng))
		reshuffles += Sx.of_kind(ev, SdEvent.Kind.RESHUFFLED).size()
		for s: int in [P, O]:
			assert_eq(d.hands[s].size() + d.decks[s].size() + d.discards[s].size(), 20, "no card gets lost")
		if not d.is_finished():
			assert_eq(d.hands[side].size(), 5, "the hand has five cards again after every move")
	assert_gt(reshuffles, 0, "a long duel reshuffles a discard pile")
	assert_gt(d.shuffles[0] + d.shuffles[1], 2, "the shuffle counters count up")


func test_every_card_does_what_it_says() -> void:
	var b: SdRulebook = _neutral_book()
	for cid: String in b.card_ids:
		var c: SdCardDef = b.card(cid)
		if c.show:
			continue
		var d: SdDuel = Sx.player_first(b, "sdo_ferdi", 1)
		Sx.set_hand(d, P, [cid, "sdc_stempel", "sdc_stempel", "sdc_stempel", "sdc_stempel"])
		Sx.set_hand(d, O, ["sdc_stempel", "sdc_stempel", "sdc_stempel", "sdc_stempel", "sdc_stempel"])
		var me: Combatant = d.combatant(P)
		var foe: Combatant = d.combatant(O)
		me.hp = 30                                            # room for heals
		var hp_before: Array[int] = [me.hp, foe.hp]
		var opp_ctr: int = _ctr(d, O)
		var ev: Array[SdEvent] = d.submit({"op": "play", "slot": 0})
		var dealt: int = 0
		var healed: int = 0
		for e: ActionEvent in Sx.engine_of(ev, ActionEvent.Type.DAMAGE):
			dealt += e.amount if e.skill_id == c.skill_id() and e.target_id == foe.id else 0
		for e: ActionEvent in Sx.engine_of(ev, ActionEvent.Type.HEAL):
			healed += e.amount if e.skill_id == c.skill_id() and e.target_id == me.id else 0
		assert_eq(dealt, c.damage(), cid + ": Ärger as printed (%d)" % c.damage())
		assert_eq(me.hp - hp_before[0], c.heal(), cid + ": Geduld as printed (+%d)" % c.heal())
		assert_eq(healed, c.heal(), cid + ": HEAL events")
		var extra: int = 50 if c.status_ids().has("sts_sd_wiedervorlage") else 0
		var table: Dictionary = DELAY_EIL if c.status_ids().has("sts_sd_eilvermerk") else DELAY
		assert_eq(_player_delay(d, opp_ctr, extra), int(table[c.rank()]),
			"%s: %d Werktage = %d ticks" % [cid, c.rank(), int(table[c.rank()])])
		for sid: String in c.status_ids():
			var holder: Combatant = me if c.targets_self() else foe
			if sid == "sts_sd_wiedervorlage":
				var added: bool = false
				for e: ActionEvent in Sx.engine_of(ev, ActionEvent.Type.STATUS_ADDED):
					added = added or (e.status_id == sid and e.target_id == foe.id)
				assert_true(added, cid + ": Wiedervorlage on the opponent")
			else:
				assert_true(holder.has_status(sid), "%s: %s" % [cid, sid])
		if c.hand == "refresh":
			assert_eq(Sx.of_kind(ev, SdEvent.Kind.HAND_REFRESHED).size(), 1, "Umlaufmappe")
			assert_eq(d.discards[P].size(), 5, "the whole hand on the discard pile")
			assert_len(d.hands[P], 5, "five new cards")
		else:
			assert_eq(d.discards[P], PackedStringArray([cid]), cid + " lies on the discard pile")
	# cleansing: Erste Hilfe and the Gegengift remove Kleingedrucktes
	for cid: String in ["sdc_erste_hilfe", "sdc_gegengift"]:
		var d2: SdDuel = Sx.player_first(b, "sdo_ferdi", 1)
		Sx.set_hand(d2, P, [cid, "sdc_stempel", "sdc_stempel", "sdc_stempel", "sdc_stempel"])
		d2.battle.current_actor().statuses.append(StatusEffect.new(b.data.status("sts_sd_kleingedrucktes"), 3, "e0"))
		d2.submit({"op": "play", "slot": 0})
		assert_false(d2.combatant(P).has_status("sts_sd_kleingedrucktes"), cid + " removes Kleingedrucktes")


func test_show_cards_chance_and_patzer() -> void:
	var b: SdRulebook = _neutral_book()
	for row: Array in [["sdc_suplex", 26, 600], ["sdc_auftritt", 24, 550]]:
		var ok: int = 0
		var n: int = 200
		for s in n:
			var d: SdDuel = Sx.player_first(b, "sdo_ferdi", 1 + s * 37)
			Sx.set_hand(d, P, [str(row[0]), "sdc_stempel", "sdc_stempel", "sdc_stempel", "sdc_stempel"])
			var me: Combatant = d.combatant(P)
			var foe: Combatant = d.combatant(O)
			var before: Array[int] = [me.hp, foe.hp]
			var opp_ctr: int = _ctr(d, O)
			assert_eq(d.preview({"op": "play", "slot": 0}), {}, "no dry run for show cards (it would tell the dice)")
			var ev: Array[SdEvent] = d.submit({"op": "play", "slot": 0})
			var res: Array[ActionEvent] = Sx.engine_of(ev, ActionEvent.Type.STUNT_RESULT)
			assert_len(res, 1, "one STUNT_RESULT")
			if res.is_empty():
				continue
			if res[0].success:
				ok += 1
				assert_eq(before[1] - foe.hp, int(row[1]), "%s: %d Ärger" % [row[0], row[1]])
				assert_eq(_player_delay(d, opp_ctr, 0), 67, "4 Werktage")
			elif str(row[0]) == "sdc_suplex":
				assert_eq(before[0] - me.hp, 5, "Patzer: 10 % of the own Geduld")
				assert_eq(_player_delay(d, opp_ctr, 0), 67 + 33, "Patzer: the next number 2 Werktage later")
			else:
				assert_eq(me.hp, before[0], "the Auftritt's Patzer costs no Geduld")
				assert_eq(_player_delay(d, opp_ctr, 0), 67 + 50, "Patzer: a Wiedervorlage for oneself (3 Werktage)")
			assert_eq(foe.hp == before[1], not res[0].success, "a Patzer deals no Ärger")
		assert_between(ok * 1000 / n, int(row[2]) - 80, int(row[2]) + 80, "%s: printed chance %d ‰" % [row[0], row[2]])
	var d1: SdDuel = Sx.player_first(b, "sdo_ferdi", 3)
	Sx.set_hand(d1, P, ["sdc_suplex", "sdc_stempel", "sdc_stempel", "sdc_stempel", "sdc_stempel"])
	d1.combatant(P).hp = 1
	d1.submit({"op": "play", "slot": 0})
	assert_gt(d1.combatant(P).hp, 0, "a Patzer never costs the last Geduld")


func test_states_count_in_numbers() -> void:
	var b: SdRulebook = _neutral_book()
	# Wiedervorlage: +3 WT on the opponent's next number, gone at that number, never doubled.
	var d: SdDuel = Sx.player_first(b, "sdo_ferdi", 1)
	Sx.set_hand(d, P, ["sdc_wiedervorlage", "sdc_wiedervorlage", "sdc_stempel", "sdc_stempel", "sdc_stempel"])
	var c0: int = _ctr(d, O)
	var pv: Dictionary = d.preview({"op": "play", "slot": 0})
	d.submit({"op": "play", "slot": 0})
	assert_true(d.combatant(O).has_status("sts_sd_wiedervorlage"))
	assert_eq(_ctr(d, O) - _ctr(d, P), c0 + 50 - 33, "the opponent's number moves 3 WT back")
	assert_eq(PackedStringArray(pv["order"]), _order_now(d, pv), "the dry run predicted the order")
	if d.side_to_move() == P:
		var c1: int = _ctr(d, O)
		var pv2: Dictionary = d.preview({"op": "play", "slot": 0})
		assert_has(pv2["blocked"], "sts_sd_wiedervorlage", "the preview shows 'keine Wirkung'")
		var ev: Array[SdEvent] = d.submit({"op": "play", "slot": 0})
		assert_eq(Sx.engine_of(ev, ActionEvent.Type.STATUS_BLOCKED).size(), 1, "nicht doppelt")
		assert_eq(_ctr(d, O) - _ctr(d, P), c1 - 33, "no second delay")
	while d.side_to_move() == P:
		d.submit({"op": "play", "slot": 0})
	assert_false(d.combatant(O).has_status("sts_sd_wiedervorlage"), "ends at the opponent's number")
	# Dienst nach Vorschrift: the opponent's next 2 numbers take 50 % longer, the third does not.
	var v: SdDuel = Sx.player_first(b, "sdo_ferdi", 1)
	Sx.set_hand(v, P, ["sdc_leinen", "sdc_stempel", "sdc_stempel", "sdc_stempel", "sdc_stempel"])
	Sx.set_hand(v, O, ["sdc_formular_27b", "sdc_formular_27b", "sdc_formular_27b", "sdc_formular_27b",
		"sdc_formular_27b"])
	v.submit({"op": "play", "slot": 0})
	var opp_delays: Array = []
	var guard: int = 0
	while opp_delays.size() < 3 and guard < 40 and not v.is_finished():
		guard += 1
		if v.side_to_move() == O:
			Sx.set_hand(v, O, ["sdc_formular_27b", "sdc_formular_27b", "sdc_formular_27b", "sdc_formular_27b",
				"sdc_formular_27b"])
			var p_before: int = _ctr(v, P)
			v.submit(v.opponent_move())
			opp_delays.append(_ctr(v, O) - _ctr(v, P) + p_before)
		else:
			Sx.set_hand(v, P, ["sdc_stempel", "sdc_stempel", "sdc_stempel", "sdc_stempel", "sdc_stempel"])
			v.submit({"op": "play", "slot": 0})
	assert_eq(opp_delays, [75, 75, 50], "3 WT become 4,5 WT twice, then 3 again (10 §1.6)")
	# Eilvermerk: this and the next 2 cards 40 % faster (Gutachten), the fourth normal again.
	var e: SdDuel = Sx.player_first(b, "sdo_ferdi", 1)
	Sx.set_hand(e, P, ["sdc_gutachten", "sdc_formular_27b", "sdc_formular_27b", "sdc_formular_27b",
		"sdc_formular_27b"])
	var mine: Array = []
	guard = 0
	while mine.size() < 4 and guard < 40 and not e.is_finished():
		guard += 1
		if e.side_to_move() == P:
			var o_before: int = _ctr(e, O)
			e.submit({"op": "play", "slot": 0})
			mine.append(_player_delay(e, o_before, 0))
			Sx.set_hand(e, P, ["sdc_formular_27b", "sdc_formular_27b", "sdc_formular_27b", "sdc_formular_27b",
				"sdc_formular_27b"])
		else:
			Sx.set_hand(e, O, ["sdc_umlaufmappe", "sdc_umlaufmappe", "sdc_umlaufmappe", "sdc_umlaufmappe",
				"sdc_umlaufmappe"])
			e.submit(e.opponent_move())
	assert_eq(mine, [20, 30, 30, 50], "Gutachten 2 WT × 0,6, two 27b × 0,6, then 3 WT again")
	# Kleingedrucktes: 2 Geduld at the start of each of the opponent's next 3 numbers.
	var k: SdDuel = Sx.player_first(b, "sdo_ferdi", 1)
	Sx.set_hand(k, P, ["sdc_kleingedrucktes", "sdc_wiedervorlage", "sdc_wiedervorlage", "sdc_wiedervorlage",
		"sdc_wiedervorlage"])
	var ev2: Array[SdEvent] = k.submit({"op": "play", "slot": 0})
	var ticks: int = 0
	guard = 0
	while guard < 60 and not k.is_finished() and k.combatant(O).own_turns < 5:
		guard += 1
		for dmg: ActionEvent in Sx.engine_of(ev2, ActionEvent.Type.DAMAGE):
			if dmg.status_id == "sts_sd_kleingedrucktes":
				ticks += 1
				assert_eq(dmg.amount, 2, "always 2 (tick_pct −1, tick_min 2)")
		if k.side_to_move() == O:
			Sx.set_hand(k, O, ["sdc_umlaufmappe", "sdc_umlaufmappe", "sdc_umlaufmappe", "sdc_umlaufmappe",
				"sdc_umlaufmappe"])
			ev2 = k.submit(k.opponent_move())
		else:
			ev2 = k.submit({"op": "file", "slot": 0})
	assert_eq(ticks, 3, "three numbers")
	assert_false(k.combatant(O).has_status("sts_sd_kleingedrucktes"), "then it is over")
	# Eilvermerk and Dienst nach Vorschrift cancel each other.
	var x: SdDuel = Sx.player_first(b, "sdo_ferdi", 1)
	x.combatant(P).statuses.append(StatusEffect.new(b.data.status("sts_sd_vorschrift"), 3, "e0"))
	Sx.set_hand(x, P, ["sdc_kaffee", "sdc_stempel", "sdc_stempel", "sdc_stempel", "sdc_stempel"])
	x.submit({"op": "play", "slot": 0})
	assert_false(x.combatant(P).has_status("sts_sd_vorschrift"), "Eilvermerk removes Dienst nach Vorschrift")
	assert_true(x.combatant(P).has_status("sts_sd_eilvermerk"))


## The order the board shows now, rebuilt like preview(): the mover, the numbers called on the way, the forecast.
func _order_now(d: SdDuel, pv: Dictionary) -> PackedStringArray:
	var order: PackedStringArray = pv["order"]
	var now: PackedStringArray = d.order(SdDuel.ORDER_LENGTH)
	var out: PackedStringArray = PackedStringArray([order[0]])
	for i in now.size():
		if out.size() >= order.size():
			break
		out.append(now[i])
	return out


func test_filing_halves_swaps_and_is_quick() -> void:
	var b: SdRulebook = _neutral_book()
	var d: SdDuel = Sx.player_first(b, "sdo_ferdi", 1)
	Sx.set_hand(d, P, ["sdc_stempel", "sdc_umlaufmappe", "sdc_formular_27b", "sdc_formular_27b",
		"sdc_formular_27b"])
	var top: String = d.decks[P][0]
	var opp_ctr: int = _ctr(d, O)
	var ev: Array[SdEvent] = d.submit({"op": "file", "slot": 1})
	assert_eq(Sx.of_kind(ev, SdEvent.Kind.CARD_FILED).size(), 1)
	assert_eq(d.discards[P], PackedStringArray(["sdc_umlaufmappe"]), "the filed card goes to the discard pile")
	assert_eq(d.hands[P][4], top, "and a new card is drawn")
	assert_eq(Sx.of_kind(ev, SdEvent.Kind.HAND_REFRESHED).size(), 0, "filing never triggers the card")
	assert_eq(_player_delay(d, opp_ctr, 0), 33, "Abheften: 2 Werktage")
	assert_true(d.combatant(P).defending)
	var hits: int = 0
	var guard: int = 0
	while d.side_to_move() == O and guard < 10:
		guard += 1
		Sx.set_hand(d, O, ["sdc_formular_27b", "sdc_formular_27b", "sdc_formular_27b", "sdc_formular_27b",
			"sdc_formular_27b"])
		for dmg: ActionEvent in Sx.engine_of(d.submit(d.opponent_move()), ActionEvent.Type.DAMAGE):
			assert_eq(dmg.amount, 5, "9 Ärger halved (4,5 rounds to 5)")
			hits += 1
	assert_gt(hits, 0, "the opponent hit while the player was filing")
	if d.side_to_move() == P:
		assert_false(d.combatant(P).defending, "filing ends with the own next number")


func test_zustaendigkeiten_and_immunity() -> void:
	var b: SdRulebook = Sx.book()
	var cases: Array = [["sdo_ferdi", "sdc_adelsflamme", 15, "weak"], ["sdo_graf", "sdc_ablehnung", 5, "resist"],
		["sdo_ulla", "sdc_ablehnung", 14, "weak"], ["sdo_ulla", "sdc_doppelstempel", 4, "resist"],
		["sdo_meister", "sdc_stereo", 10, "weak"], ["sdo_meister", "sdc_adelsflamme", 5, "resist"]]
	for c: Array in cases:
		var d: SdDuel = Sx.player_first(b, str(c[0]), 1)
		Sx.set_hand(d, P, [str(c[1]), "sdc_stempel", "sdc_stempel", "sdc_stempel", "sdc_stempel"])
		var before: int = d.combatant(O).hp
		var pv: Dictionary = d.preview({"op": "play", "slot": 0})
		assert_eq(int((pv["delta"] as Array)[1]), -int(c[2]), "the card shows the real number: %s" % str(c))
		assert_true(bool(pv[str(c[3])]), "%s flagged %s" % [c[1], c[3]])
		var ev: Array[SdEvent] = d.submit({"op": "play", "slot": 0})
		assert_eq(before - d.combatant(O).hp, int(c[2]), "%s against %s" % [c[1], c[0]])
		var flagged: bool = false
		for e: ActionEvent in Sx.engine_of(ev, ActionEvent.Type.DAMAGE):
			flagged = flagged or (e.weak if str(c[3]) == "weak" else e.resist)
		assert_true(flagged, "DAMAGE event flag %s" % str(c[3]))
	var u: SdDuel = Sx.player_first(b, "sdo_ulla", 1)
	Sx.set_hand(u, P, ["sdc_kabelpeitsche", "sdc_wiedervorlage", "sdc_stempel", "sdc_stempel", "sdc_stempel"])
	var hp: int = u.combatant(O).hp
	var ev2: Array[SdEvent] = u.submit({"op": "play", "slot": 0})
	assert_eq(hp - u.combatant(O).hp, 6, "the Kabelpeitsche still deals its Ärger")
	assert_eq(Sx.engine_of(ev2, ActionEvent.Type.STATUS_BLOCKED).size(), 1, "Wiedervorlage: ABGEPRALLT")
	assert_false(u.combatant(O).has_status("sts_sd_wiedervorlage"), "Ulla is immune")


func test_the_durchsage_and_the_phases() -> void:
	var b: SdRulebook = Sx.book()
	var d: SdDuel = Sx.player_first(b, "sdo_meister", 1)
	var boss: Combatant = d.combatant(O)
	assert_eq(d.battle.history.filter(func(e: ActionEvent) -> bool:
		return e.type == ActionEvent.Type.MOD_LINE and e.text == "sd_boss_intro").size(), 1, "phase 1: the intro")
	Sx.set_hand(d, P, ["sdc_amtsstempel", "sdc_stempel", "sdc_stempel", "sdc_stempel", "sdc_stempel"])
	var ev: Array[SdEvent] = d.submit({"op": "play", "slot": 0})           # 50 → 28: phase 2
	var lines: Array = Sx.engine_of(ev, ActionEvent.Type.MOD_LINE).map(func(e: ActionEvent) -> String: return e.text)
	assert_has(lines, "sd_boss_phase:2")
	assert_eq(Sx.engine_of(ev, ActionEvent.Type.PHASE_CHANGE).size(), 1, "one phase change")
	var unit: Combatant = null
	for c: Combatant in d.battle.pseudo_units():
		unit = c
	assert_not_null(unit, "the Durchsage joins the ticket display")
	if unit == null:
		return
	assert_eq(unit.def_id, "pu_sd_durchsage")
	var warned: bool = false
	var hits: Array = []
	var tickets_seen: Dictionary = {}
	var guard: int = 0
	while hits.size() < 2 and guard < 60 and not d.is_finished():
		guard += 1
		var order: PackedStringArray = d.order(3)
		var file_now: bool = d.side_to_move() == P and hits.size() == 1 and order.find(unit.id) > 0
		var evs: Array[SdEvent] = []
		if d.side_to_move() == P:
			Sx.set_hand(d, P, ["sdc_stempel", "sdc_stempel", "sdc_stempel", "sdc_stempel", "sdc_stempel"])
			d.combatant(O).hp = maxi(d.combatant(O).hp, 20)                   # stay in phase 2
			evs = d.submit({"op": "file" if file_now else "play", "slot": 0})
		else:
			Sx.set_hand(d, O, ["sdc_umlaufmappe", "sdc_umlaufmappe", "sdc_umlaufmappe", "sdc_umlaufmappe",
				"sdc_umlaufmappe"])
			evs = d.submit(d.opponent_move())
		for m: ActionEvent in Sx.engine_of(evs, ActionEvent.Type.MOD_LINE):
			warned = warned or m.text == "sd_durchsage_warn"
		for t: ActionEvent in Sx.engine_of(evs, ActionEvent.Type.TURN_START):
			tickets_seen[t.actor_id] = true
		for dmg: ActionEvent in Sx.engine_of(evs, ActionEvent.Type.DAMAGE):
			if dmg.actor_id == unit.id:
				hits.append(dmg.amount)
	assert_true(warned, "M.O.D. warns when the Durchsage is second on the display")
	assert_eq(hits, [4, 2], "4 Ärger (8 % of 50), 2 when filed")
	assert_true(tickets_seen.has(unit.id), "the Durchsage draws numbers too")
	# Phase 3 and the counter: the Feierabend-Eilvermerk, then the Leinen-Fallstrick takes it away.
	var m3: SdDuel = Sx.player_first(b, "sdo_meister", 2)
	Sx.set_hand(m3, P, ["sdc_amtsstempel", "sdc_amtsstempel", "sdc_leinen", "sdc_stempel", "sdc_stempel"])
	m3.combatant(O).hp = 20
	m3.submit({"op": "play", "slot": 0})
	assert_eq(m3.result, SdDuel.Result.WON, "22 Ärger on 20 Geduld end the duel at once")
	var m4: SdDuel = Sx.player_first(b, "sdo_meister", 2)
	Sx.set_hand(m4, P, ["sdc_formular_27b", "sdc_leinen", "sdc_stempel", "sdc_stempel", "sdc_stempel"])
	m4.combatant(O).hp = 20                                               # phase 1 by its index, 40 % left
	var ev3: Array[SdEvent] = m4.submit({"op": "play", "slot": 0})        # 20 → 11 = 22 %: phases 2 and 3
	var tags: Array = Sx.engine_of(ev3, ActionEvent.Type.MOD_LINE).map(func(e: ActionEvent) -> String: return e.text)
	assert_eq(tags, ["sd_boss_phase:2", "sd_boss_phase:3"], "crossing two thresholds enters both phases in order")
	assert_true(m4.combatant(O).has_status("sts_sd_eilvermerk"), "Feierabend naht: Eilvermerk for 99 numbers")
	var guard2: int = 0
	while m4.side_to_move() != P and guard2 < 10 and not m4.is_finished():
		guard2 += 1
		Sx.set_hand(m4, O, ["sdc_umlaufmappe", "sdc_umlaufmappe", "sdc_umlaufmappe", "sdc_umlaufmappe",
			"sdc_umlaufmappe"])
		m4.submit(m4.opponent_move())
	if m4.side_to_move() == P:
		Sx.set_hand(m4, P, ["sdc_leinen", "sdc_stempel", "sdc_stempel", "sdc_stempel", "sdc_stempel"])
		m4.submit({"op": "play", "slot": 0})
		assert_false(m4.combatant(O).has_status("sts_sd_eilvermerk"), "the Leinen-Fallstrick ends the Feierabend")
		assert_true(m4.combatant(O).has_status("sts_sd_vorschrift"))


func test_ties_go_to_the_customer() -> void:
	var b: SdRulebook = Sx.book()
	var ties: int = 0
	for s in range(1, 400):
		var d: SdDuel = SdDuel.new(SdSetup.create(b, "sdo_ferdi", b.startmappe_list(), s), b)
		d.start()
		# Equal start numbers leave both counters at 0 once the first number is called.
		if d.combatant(P).ctb_counter == 0 and d.combatant(O).ctb_counter == 0:
			ties += 1
			assert_eq(d.side_to_move(), P, "seed %d: on a tie the customer goes first" % s)
	assert_gt(ties, 0, "some seeds draw equal start numbers")
	var t: SdDuel = Sx.player_first(b, "sdo_meister", 1)
	Sx.set_hand(t, P, ["sdc_amtsstempel", "sdc_stempel", "sdc_stempel", "sdc_stempel", "sdc_stempel"])
	t.submit({"op": "play", "slot": 0})
	var units: Array[Combatant] = t.battle.pseudo_units()
	assert_len(units, 1, "the Durchsage is in the order")
	if units.is_empty():
		return
	for c: Combatant in [t.combatant(P), t.combatant(O), units[0]]:
		c.ctb_counter = 30
	assert_eq(Array(t.battle.queue.preview(3)), ["p0", "e0", "u0"],
		"Kundschaft vor Gegenüber vor Durchsage (10 §1.9)")


func test_dienstschluss_adjourns_at_number_80() -> void:
	var b: SdRulebook = Sx.book()
	var d: SdDuel = SdDuel.new(SdSetup.create(b, "sdo_ferdi", b.startmappe_list(), 9), b)
	d.start()
	var warned_at: int = -1
	var guard: int = 0
	while not d.is_finished() and guard < 300:
		guard += 1
		if d.dienstschluss_near() and warned_at < 0:
			warned_at = d.ticket()
		var side: int = d.side_to_move()
		d.combatant(P).hp = 50
		d.combatant(O).hp = 36
		d.submit({"op": "file", "slot": 0} if side == P else {"op": "file", "slot": d.lowest_weight_slot()})
	assert_eq(d.result, SdDuel.Result.ADJOURNED, "Dienstschluss: vertagt")
	assert_eq(d.ticket(), 80, "number 80 is called and not served")
	assert_eq(warned_at, 60, "'Dienstschluss bei Nummer 80' from number 60")
	assert_eq(d.summary()["result"], "adjourned")
	assert_eq(d.legal_moves(), [], "nothing after the end")


func test_forfeit() -> void:
	var b: SdRulebook = Sx.book()
	var d: SdDuel = Sx.player_first(b, "sdo_graf", 1)
	assert_has(d.legal_moves(), {"op": "forfeit"}, "the player can always withdraw the application")
	var ev: Array[SdEvent] = d.submit({"op": "forfeit"})
	assert_eq(d.result, SdDuel.Result.FORFEIT)
	assert_eq(Sx.of_kind(ev, SdEvent.Kind.DUEL_END)[0].value, SdDuel.Result.FORFEIT)
	assert_true(d.is_finished())
	assert_ne(d.validate({"op": "play", "slot": 0}), "", "nothing after a forfeit")
	var o: SdDuel = Sx.player_first(b, "sdo_graf", 1)
	o.submit({"op": "play", "slot": 0})
	while o.side_to_move() == P:
		o.submit({"op": "play", "slot": 0})
	if o.side_to_move() == O:
		assert_ne(o.validate({"op": "forfeit"}), "", "only on the player's turn")
		assert_false(o.legal_moves().has({"op": "forfeit"}))


func test_legal_moves_and_validation() -> void:
	var b: SdRulebook = Sx.book()
	var d: SdDuel = Sx.player_first(b, "sdo_ferdi", 1)
	assert_len(d.legal_moves(), 11, "5 × play, 5 × file, forfeit")
	for bad: Dictionary in [{}, {"op": "play"}, {"op": "play", "slot": 5}, {"op": "play", "slot": -1},
			{"op": "steal", "slot": 0}, {"op": "file", "slot": "x"}]:
		assert_ne(d.validate(bad), "", "refused: %s" % str(bad))
	var before: String = d.state_hash()
	assert_eq(d.submit({"op": "play", "slot": 9}), [], "an invalid move changes nothing")
	assert_eq(d.state_hash(), before)
	assert_eq(d.validate({"op": "play", "slot": 0, "a": true, "hint": "damage"}), "", "extra keys are ignored")
	var notyet: SdDuel = SdDuel.new(SdSetup.create(b, "sdo_ferdi", b.startmappe_list(), 1), b)
	assert_ne(notyet.validate({"op": "play", "slot": 0}), "", "not started")
	assert_eq(notyet.side_to_move(), -1)


func test_the_lernduell_follows_its_script() -> void:
	var b: SdRulebook = Sx.book()
	for s: int in [1, 99]:
		var d: SdDuel = SdDuel.new(SdSetup.lernduell(b, s), b)
		assert_eq(SdSetup.lernduell(b, s).problem(b), "")
		var ev: Array[SdEvent] = d.start()
		assert_eq(Array(d.hands[P]), ["sdc_stempel", "sdc_formular_27b", "sdc_ablehnung", "sdc_kaeltespray",
			"sdc_durchatmen"], "fixed order, no shuffle")
		assert_eq(d.side_to_move(), P, "Präventivschlag: the player has number 001")
		assert_eq(d.max_geduld(O), 26)
		var steps: Array = []
		var ferdi: Array = []
		var guard: int = 0
		while not d.is_finished() and guard < 30:
			guard += 1
			for l: Dictionary in d.lessons_now():
				if not steps.has(int(l["step"])):
					steps.append(int(l["step"]))
			if d.side_to_move() == P:
				var forced: Dictionary = d.forced_move()
				assert_false(forced.is_empty(), "every player number of the script is a lesson (%d)" % d.ticket())
				assert_eq(d.legal_moves().size(), (5 if str(forced.get("op", "")) == "file" else 1) + 1,
					"only the lesson's move (and withdrawing)")
				if str(forced.get("op", "")) == "play":
					var other: int = (d.hands[P].find(str(forced["card"])) + 1) % 5
					assert_ne(d.validate({"op": "play", "slot": other}), "", "another card is refused")
				ev = d.submit(SdAi.suggest(d))
			else:
				var m: Dictionary = d.opponent_move()
				ferdi.append([d.ticket(), d.hands[O][int(m["slot"])]])
				ev = d.submit(m)
			assert_gt(d.geduld(P), 0, "Geduld never below 1 in the Lernduell")
		assert_eq(d.result, SdDuel.Result.WON, "the Adelsflamme wins")
		assert_eq(d.ticket(), 7, "seven numbers")
		assert_eq(steps, [1, 2, 3, 4, 5, 6], "six lessons in order")
		assert_eq(ferdi, [[3, "sdc_wiedervorlage"], [4, "sdc_formular_27b"], [6, "sdc_ablehnung"]], "Ferdi's script")
		var weak: bool = false
		for e: ActionEvent in Sx.engine_of(ev, ActionEvent.Type.DAMAGE):
			weak = weak or (e.weak and e.amount == 15)
		assert_true(weak, "Wunder Punkt: 15 instead of 10")
		assert_gt(d.geduld(P), 40, "half Ärger for Ferdi and the filed Ablehnung")
	var t: SdDuel = SdDuel.new(SdSetup.lernduell(b, 1), b)
	t.start()
	t.submit({"op": "play", "slot": 0})
	t.combatant(P).hp = 1
	t.submit({"op": "play", "slot": 0})
	while t.side_to_move() == O:
		t.submit(t.opponent_move())
	assert_eq(t.geduld(P), 1, "the Lernduell cannot be lost (Geduld stays at 1)")


func test_the_order_of_the_events() -> void:
	var b: SdRulebook = Sx.book()
	var d: SdDuel = Sx.player_first(b, "sdo_ferdi", 1)
	var ev: Array[SdEvent] = d.submit({"op": "play", "slot": 0})
	assert_eq(ev[0].kind, SdEvent.Kind.CARD_PLAYED, "the card first")
	var turn_end: int = -1
	var drawn: int = -1
	var next_start: int = -1
	for i in ev.size():
		var e: SdEvent = ev[i]
		if e.engine != null and e.engine.type == ActionEvent.Type.TURN_END and turn_end < 0:
			turn_end = i
		if e.kind == SdEvent.Kind.CARD_DRAWN and drawn < 0:
			drawn = i
		if e.engine != null and e.engine.type == ActionEvent.Type.TURN_START and next_start < 0:
			next_start = i
	assert_true(turn_end >= 0 and drawn > turn_end and next_start > drawn,
		"draw after the actor's TURN_END, before the next number (%d, %d, %d)" % [turn_end, drawn, next_start])
	var back: SdEvent = SdEvent.from_dict(JSON.parse_string(JSON.stringify(ev[0].to_dict())))
	assert_eq(back.to_dict(), ev[0].to_dict(), "events serialize")
	var eng: SdEvent = SdEvent.from_dict(JSON.parse_string(JSON.stringify(ev[1].to_dict())))
	assert_eq(eng.to_dict(), ev[1].to_dict(), "engine events too")


func test_the_basic_attack_never_runs() -> void:
	var b: SdRulebook = Sx.book()
	for opp: String in b.opponent_ids:
		for profile: String in Sx.PROFILES:
			var r: Dictionary = Sx.full_duel(b, opp, b.startmappe_list(), 11, profile)
			for e: SdEvent in r["events"]:
				if e.engine != null:
					assert_ne(e.engine.skill_id, SdRulebook.BASIC_ATTACK, "%s/%s: skl_sd_none is never executed" % [
						opp, profile])
					if e.engine.type == ActionEvent.Type.ACTION_START:
						assert_ne(e.engine.command, BattleCommand.Kind.ATTACK, "no ATTACK (it becomes filing)")
