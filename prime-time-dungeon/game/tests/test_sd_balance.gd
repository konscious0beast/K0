extends TestCase
## 10 §6.9 test_sd_balance (SD2-B): the balance harness against the bands of 10 §6.9. Bot profiles: "gut" =
## SdAi.suggest, "einfach" = AutoPolicy, "zufall" = a random hand card, never filing; decks: the Startmappe or a
## harness deck (tests/fixtures/stempel/balance_decks.json: "passend" built from the opponent's file, "erster
## Besuch" = what one owns at the first visit). CI runs SEEDS (50) seeds per cell; the nightly harness sets
## SD_BALANCE_SEEDS=1000. The measured values are printed ("[SD BALANCE] …").
##
## With 50 seeds a win rate has a sampling error of up to 7 points, so a cell passes when it is within 2 standard
## errors of its band (binomial, at the band's edge; with 1 000 seeds this shrinks to ≈ 3 points). Also checked:
## Dienstschluss in < 1 % of the duels, the first number moves the win rate by ≤ 10 points ("gut" cells pooled), and no
## card sits in > 80 % of the winning random Mappen of "gut" (random legal decks from the full collection, one duel
## per opponent) — every card in ≥ 5 %.

const Sx := preload("res://tests/test_sd_fixture.gd")
const SEEDS: int = 50
const SEED_BASE: int = 1000
const SEED_STEP: int = 7919
const RANDOM_DECKS: int = 20
## [opponent, profile, deck, band min %, band max %, median numbers min, max (0 = not checked)] — 10 §6.9; the
## Stempelmeister's "passend" (the full collection) is 70–90 % since SD2 (10 §7.3 "Stand SD2-A/B").
const BANDS: Array = [
	["sdo_ferdi", "gut", "start", 95, 100, 14, 24],
	["sdo_ferdi", "einfach", "start", 85, 100, 0, 0],
	["sdo_ferdi", "zufall", "start", 70, 100, 0, 0],
	["sdo_graf", "gut", "start", 85, 97, 24, 34],
	["sdo_graf", "einfach", "start", 15, 40, 0, 0],
	["sdo_graf", "zufall", "start", 15, 40, 0, 0],
	["sdo_ulla", "gut", "start", 30, 50, 28, 40],
	["sdo_ulla", "gut", "ulla_passend", 80, 100, 0, 0],
	["sdo_ulla", "einfach", "start", 0, 15, 0, 0],
	["sdo_meister", "gut", "start", 0, 10, 20, 30],
	["sdo_meister", "gut", "meister_passend", 70, 90, 0, 0],
	["sdo_meister", "gut", "meister_erster_besuch", 40, 55, 0, 0],
	["sdo_meister", "einfach", "start", 0, 10, 0, 0],
]


static func seeds() -> int:
	var env: String = OS.get_environment("SD_BALANCE_SEEDS")
	return maxi(1, env.to_int()) if env.is_valid_int() else SEEDS


## Allowed sampling slack in per-mille for a share near `edge_pct` with `n` duels: 2 binomial standard errors.
static func slack_pm(edge_pct: int, n: int) -> int:
	var p: float = clampf(float(edge_pct) / 100.0, 0.05, 0.95)
	return roundi(2000.0 * sqrt(p * (1.0 - p) / float(n)))


## One cell: {"wins", "n", "adjourned", "median", "first": [[wins, n] with the first number, [wins, n] without]}.
func _cell(b: SdRulebook, opp: String, profile: String, deck: PackedStringArray, n: int) -> Dictionary:
	var wins: int = 0
	var adjourned: int = 0
	var tickets: Array[int] = []
	var first: Array = [[0, 0], [0, 0]]
	for i in n:
		var d: SdDuel = SdDuel.new(SdSetup.create(b, opp, deck, SEED_BASE + i * SEED_STEP), b)
		d.start()
		var had_first: int = 0 if d.side_to_move() == SdDuel.Side.PLAYER else 1
		Sx.play_out(d, profile)
		var won: bool = d.result == SdDuel.Result.WON
		wins += 1 if won else 0
		adjourned += 1 if d.result == SdDuel.Result.ADJOURNED else 0
		tickets.append(d.ticket())
		(first[had_first] as Array)[0] += 1 if won else 0
		(first[had_first] as Array)[1] += 1
	tickets.sort()
	return {"wins": wins, "n": n, "adjourned": adjourned, "median": tickets[n / 2], "first": first}


func test_the_bands_of_10_6_9() -> void:
	var b: SdRulebook = Sx.book()
	var n: int = seeds()
	var t0: int = Time.get_ticks_msec()
	var total: int = 0
	var adjourned: int = 0
	var first_diff_pm: Array[int] = []
	for band: Array in BANDS:
		var r: Dictionary = _cell(b, str(band[0]), str(band[1]), Sx.harness_deck(str(band[2])), n)
		var pm: int = int(r["wins"]) * 1000 / n
		var lo: int = int(band[3]) * 10 - (slack_pm(int(band[3]), n) if int(band[3]) > 0 else 0)
		var hi: int = int(band[4]) * 10 + (slack_pm(int(band[4]), n) if int(band[4]) < 100 else 0)
		var label: String = "%s %s %s" % [band[0], band[1], band[2]]
		print("[SD BALANCE] %-42s win %5.1f %%  band %d–%d %%  median %d numbers  (%d seeds)" % [label, pm / 10.0,
			int(band[3]), int(band[4]), int(r["median"]), n])
		assert_between(pm, lo, hi, "%s: %.1f %% within %d–%d %% (± sampling slack)" % [label, pm / 10.0, band[3],
			band[4]])
		if int(band[6]) > 0:
			assert_between(int(r["median"]), int(band[5]), int(band[6]), label + ": numbers per duel (median)")
		total += n
		adjourned += int(r["adjourned"])
		var f: Array = r["first"]
		if str(band[1]) == "gut" and int(f[0][1]) >= 5 and int(f[1][1]) >= 5:
			first_diff_pm.append(int(f[0][0]) * 1000 / int(f[0][1]) - int(f[1][0]) * 1000 / int(f[1][1]))
	var mean_diff: int = 0
	for v: int in first_diff_pm:
		mean_diff += v
	mean_diff = mean_diff / maxi(1, first_diff_pm.size())
	print("[SD BALANCE] Dienstschluss %d of %d duels; the first number: %+.1f points (gut cells, mean)" % [adjourned,
		total, mean_diff / 10.0])
	assert_true(adjourned * 100 < total, "Dienstschluss in < 1 % of the duels")
	assert_lt(absi(mean_diff), 100 + slack_pm(50, n * 4), "the first number moves the win rate by ≤ 10 points")
	assert_time_budget(float(Time.get_ticks_msec() - t0), 60000.0, "test_sd_balance: the band cells")


## Random legal Mappen from the full collection, one "gut" duel each against every opponent: the share of the
## winning Mappen that hold a card (10 §6.9: none in > 80 %, every card in ≥ 5 %).
func test_no_card_is_too_strong_or_too_weak() -> void:
	var b: SdRulebook = Sx.book()
	var rng: RandomNumberGenerator = make_rng(4242)
	var winners: Array[PackedStringArray] = []
	var count: int = maxi(RANDOM_DECKS, seeds() / 2)
	for i in count:
		var deck: PackedStringArray = _random_deck(b, rng)
		assert_eq(b.deck_problem(deck), "", "a random legal Mappe")
		for opp: String in b.opponent_ids:
			var d: SdDuel = SdDuel.new(SdSetup.create(b, opp, deck, 9000 + i), b)
			d.start()
			Sx.play_out(d, "gut")
			if d.result == SdDuel.Result.WON:
				winners.append(deck)
	assert_gt(winners.size(), count, "enough winning Mappen")
	var shares: Array = []
	for cid: String in b.card_ids:
		var k: int = 0
		for deck: PackedStringArray in winners:
			k += 1 if deck.has(cid) else 0
		var pm: int = k * 1000 / maxi(1, winners.size())
		shares.append("%s %d" % [cid.trim_prefix("sdc_"), pm / 10])
		assert_lt(pm, 800 + slack_pm(80, winners.size()), "%s in %.1f %% of the winning Mappen" % [cid, pm / 10.0])
		assert_gt(pm, 50 - slack_pm(5, winners.size()), "%s in %.1f %% of the winning Mappen" % [cid, pm / 10.0])
	print("[SD BALANCE] cards in winning random Mappen (%d), %%: %s" % [winners.size(), ", ".join(shares)])


## A random legal Mappe: card kinds in random order, each with its full copy limit, until the deck is full — about ten
## kinds per Mappe, so a card's base share is ≈ 45 % and a share far above it means the card wins duels.
static func _random_deck(b: SdRulebook, rng: RandomNumberGenerator) -> PackedStringArray:
	var kinds: PackedStringArray = b.card_ids.duplicate()
	for i in range(kinds.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: String = kinds[i]
		kinds[i] = kinds[j]
		kinds[j] = tmp
	var deck: PackedStringArray = []
	for cid: String in kinds:
		var c: SdCardDef = b.card(cid)
		var cap: int = mini(c.max_copies, b.constant("max_copies_show") if c.show else b.constant("max_copies"))
		for _k in mini(cap, b.deck_size() - deck.size()):
			deck.append(cid)
		if deck.size() >= b.deck_size():
			break
	deck.sort()
	return deck
