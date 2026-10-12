extends TestCase
## 10 §6.9 test_sd_ai (SD2-B): the opponents play only from their hand (EnemyAI on the synced skill list), the fallback
## becomes filing with the card of the smallest weight (ties: the leftmost), the profiles' conditions and turn_mod
## work, SdAi.suggest and AutoPolicy give only legal moves, both without dice and without changing the duel, and the
## Graf's hint makes the obvious choices (finish, Wunder Punkt, heal when low, file before a Durchsage, the
## Leinen-Fallstrick against the Feierabend-Eilvermerk, no Wiedervorlage against Ulla).

const Sx := preload("res://tests/test_sd_fixture.gd")
const P: int = SdDuel.Side.PLAYER
const O: int = SdDuel.Side.OPPONENT


func test_opponents_play_only_from_their_hand() -> void:
	var b: SdRulebook = Sx.book()
	var checked: int = 0
	for opp: String in b.opponent_ids:
		for s in 6:
			var d: SdDuel = SdDuel.new(SdSetup.create(b, opp, b.startmappe_list(), 100 + s), b)
			d.start()
			var rng: RandomNumberGenerator = make_rng(s)
			var guard: int = 0
			while not d.is_finished() and guard < 200:
				guard += 1
				if d.side_to_move() == O:
					var hand: PackedStringArray = d.hands[O].duplicate()
					var cmd: BattleCommand = d.battle.choose_ai_command()
					if cmd.kind == BattleCommand.Kind.SKILL:
						assert_has(hand, b.card_of_skill(cmd.skill_id), "%s: EnemyAI picked a hand card" % opp)
					var m: Dictionary = d.opponent_move()
					assert_eq(d.validate(m), "", "a legal opponent move")
					var ev: Array[SdEvent] = d.submit(m)
					var played: Array[SdEvent] = Sx.of_kind(ev, SdEvent.Kind.CARD_PLAYED)
					played.append_array(Sx.of_kind(ev, SdEvent.Kind.CARD_FILED))
					assert_eq(played[0].card_id, hand[played[0].slot], "the card came from the hand")
					checked += 1
				else:
					d.submit(Sx.bot_move(d, "gut", rng))
	assert_gt(checked, 200, "opponent moves checked")


func test_the_fallback_files_the_card_of_the_smallest_weight() -> void:
	var b: SdRulebook = Sx.book()
	var d: SdDuel = _opponent_to_move(b, "sdo_ferdi")
	if d == null:
		return
	# Full Geduld: Ferdi's heals (durchatmen 8, werbepflaster 6, gegengift 4; all below 50 % only) do not pass.
	Sx.set_hand(d, O, ["sdc_durchatmen", "sdc_werbepflaster", "sdc_gegengift", "sdc_durchatmen", "sdc_gegengift"])
	assert_eq(d.battle.choose_ai_command().kind, BattleCommand.Kind.ATTACK, "EnemyAI's fallback")
	assert_eq(d.opponent_move(), {"op": "file", "slot": 2}, "the smallest weight (Gegengift 4), the leftmost of two")
	d.combatant(O).hp = 10
	var m: Dictionary = d.opponent_move()
	assert_eq(str(m["op"]), "play", "below 50 %% Ferdi heals: %s" % str(m))
	var ev: Array[SdEvent] = d.submit(m)
	assert_gt(Sx.engine_of(ev, ActionEvent.Type.HEAL).size(), 0)
	var u: SdDuel = _opponent_to_move(b, "sdo_ulla")
	if u == null:
		return
	Sx.set_hand(u, O, ["sdc_formular_27b", "sdc_gegengift", "sdc_doppelstempel", "sdc_gegengift", "sdc_leinen"])
	u.combatant(O).hp = 50
	var pick: Dictionary = u.opponent_move()
	assert_true(str(pick["op"]) == "play", "Ulla plays a card")


## A started duel where the opponent is to move (the first seed from 1 on).
func _opponent_to_move(b: SdRulebook, opp: String) -> SdDuel:
	for s in range(1, 200):
		var d: SdDuel = SdDuel.new(SdSetup.create(b, opp, b.startmappe_list(), s), b)
		d.start()
		if d.side_to_move() == O:
			return d
	fail("no seed where %s starts" % opp)
	return null


func test_profiles_conditions_and_turn_mod() -> void:
	var b: SdRulebook = Sx.book()
	# Ulla: every fourth own card (own_turns % 4 == 0) she prefers the Leinen-Fallstrick (turn_mod [4, 0], 10 §3.3).
	var hits: Array = [0, 0]
	var tries: Array = [0, 0]
	for s in range(1, 120):
		var d: SdDuel = SdDuel.new(SdSetup.create(b, "sdo_ulla", b.startmappe_list(), s), b)
		d.start()
		if d.side_to_move() != O:
			continue
		for turn: int in [0, 1]:
			d.combatant(O).own_turns = turn
			Sx.set_hand(d, O, ["sdc_leinen", "sdc_ablehnung", "sdc_frostniesen", "sdc_formular_27b",
				"sdc_doppelstempel"])
			var m: Dictionary = d.opponent_move()
			tries[turn] += 1
			if str(m["op"]) == "play" and d.hands[O][int(m["slot"])] == "sdc_leinen":
				hits[turn] += 1
	assert_gt(tries[0], 20, "enough opponent starts")
	assert_gt(hits[0] * tries[1], 3 * hits[1] * tries[0], "turn 0: Leinen far more often than at turn 1 %s/%s" % [
		str(hits), str(tries)])
	# The Stempelmeister's action list follows his phase.
	var m: SdDuel = _opponent_to_move(b, "sdo_meister")
	if m == null:
		return
	var boss: Combatant = m.combatant(O)
	assert_eq(EnemyAI.actions_of(boss).size(), 12, "phase 1")
	boss.phase = 2
	var top: Dictionary = EnemyAI.actions_of(boss)[0]
	assert_eq([str(top["skill"]), int(top["weight"])], ["skl_sdc_amtsstempel", 10], "phase 3 prefers the Amtsstempel")


func test_suggest_and_autopolicy_give_only_legal_moves_without_dice() -> void:
	var b: SdRulebook = Sx.book()
	var n: int = 0
	var hints: Dictionary = {}
	for opp: String in b.opponent_ids:
		for deck_name: String in ["start", "meister_passend"]:
			for s in 3:
				var d: SdDuel = SdDuel.new(SdSetup.create(b, opp, Sx.harness_deck(deck_name), 300 + s), b)
				d.start()
				var guard: int = 0
				while not d.is_finished() and guard < 200:
					guard += 1
					if d.side_to_move() == P:
						var h: String = d.state_hash()
						var g: Dictionary = SdAi.suggest(d)
						var e: Dictionary = d.auto_policy_move()
						assert_eq(d.validate(g), "", "SdAi.suggest is legal: %s" % str(g))
						assert_eq(d.validate(e), "", "AutoPolicy is legal: %s" % str(e))
						assert_eq(SdAi.suggest(d), g, "no dice: the same suggestion twice")
						assert_eq(d.auto_policy_move(), e, "no dice: AutoPolicy")
						assert_eq(d.state_hash(), h, "advisers never change the duel")
						assert_has(SdAi.HINTS, str(g["hint"]), "a known hint")
						hints[str(g["hint"])] = true
						n += 1
						d.submit(g if (n % 2 == 0) else e)
					else:
						d.submit(d.opponent_move())
	assert_gt(n, 200, "player decisions checked")
	for h: String in ["damage", "weak", "file", "status", "kill"]:
		assert_true(hints.has(h), "the hint '%s' occurs" % h)
	var t: SdDuel = SdDuel.new(SdSetup.lernduell(b, 1), b)
	t.start()
	assert_eq(t.validate(t.auto_policy_move()), "", "AutoPolicy follows the Lernduell's forced move")
	assert_eq(t.validate(SdAi.suggest(t)), "", "SdAi too")


func test_the_hint_makes_the_obvious_choices() -> void:
	var b: SdRulebook = Sx.book()
	var d: SdDuel = Sx.player_first(b, "sdo_ferdi", 1)
	d.combatant(O).hp = 8
	Sx.set_hand(d, P, ["sdc_stempel", "sdc_wiedervorlage", "sdc_formular_27b", "sdc_durchatmen", "sdc_kaeltespray"])
	assert_eq(SdAi.suggest(d), {"op": "play", "slot": 2, "hint": "kill"}, "finish him")
	d.combatant(O).hp = 36
	Sx.set_hand(d, P, ["sdc_formular_27b", "sdc_adelsflamme", "sdc_durchatmen", "sdc_kaeltespray",
		"sdc_kleingedrucktes"])
	assert_eq(SdAi.suggest(d), {"op": "play", "slot": 1, "hint": "weak"}, "Wunder Punkt: 15 instead of 9")
	d.combatant(P).hp = 7
	Sx.set_hand(d, P, ["sdc_formular_27b", "sdc_schlabbern", "sdc_durchatmen", "sdc_kaeltespray", "sdc_stempel"])
	var low: Dictionary = SdAi.suggest(d)
	assert_true(str(low["op"]) == "play" and b.card(d.hands[P][int(low["slot"])]).heal() > 0,
		"7 Geduld left: heal first (%s)" % str(low))
	var u: SdDuel = Sx.player_first(b, "sdo_ulla", 1)
	Sx.set_hand(u, P, ["sdc_wiedervorlage", "sdc_ablehnung", "sdc_wiedervorlage", "sdc_stempel", "sdc_stempel"])
	var um: Dictionary = SdAi.suggest(u)
	assert_ne(u.hands[P][int(um["slot"])] if str(um["op"]) == "play" else "", "sdc_wiedervorlage",
		"no Wiedervorlage against Ulla (immune)")
	var m: SdDuel = Sx.player_first(b, "sdo_meister", 1)
	var boss: Combatant = m.combatant(O)
	boss.hp = 12
	boss.phase = 2
	boss.statuses.append(StatusEffect.new(b.data.status("sts_sd_eilvermerk"), 99, boss.id))
	m.combatant(P).hp = 50
	Sx.set_hand(m, P, ["sdc_stempel", "sdc_leinen", "sdc_kaeltespray", "sdc_durchatmen", "sdc_werbepflaster"])
	assert_eq(SdAi.suggest(m), {"op": "play", "slot": 1, "hint": "counter"}, "the Leinen-Fallstrick ends Feierabend")
	# The Durchsage comes before the own next number and the hand is poor: file.
	var f: SdDuel = Sx.player_first(b, "sdo_meister", 3)
	Sx.set_hand(f, P, ["sdc_amtsstempel", "sdc_stempel", "sdc_stempel", "sdc_stempel", "sdc_stempel"])
	f.submit({"op": "play", "slot": 0})
	var unit: Combatant = f.battle.pseudo_units()[0] if not f.battle.pseudo_units().is_empty() else null
	var guard: int = 0
	while f.side_to_move() != P and guard < 10:
		guard += 1
		f.submit(f.opponent_move())
	assert_not_null(unit, "the Durchsage is in the order")
	if unit != null and f.side_to_move() == P:
		unit.ctb_counter = 1                                     # the Durchsage and the Stempelmeister come before
		f.combatant(O).ctb_counter = 5                           # any next number of the player
		f.combatant(P).hp = 6
		Sx.set_hand(f, P, ["sdc_wuchtschlag", "sdc_formular_27b", "sdc_wuchtschlag", "sdc_formular_27b",
			"sdc_formular_27b"])
		var fm: Dictionary = SdAi.suggest(f)
		assert_eq([str(fm["op"]), str(fm["hint"])], ["file", "durchsage"], "abheften before the Durchsage")
	var dslot: int = SdAi.discard_slot(d, P)
	assert_between(dslot, 0, 4, "a discard slot")
