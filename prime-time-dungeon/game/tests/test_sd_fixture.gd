extends TestCase
## Stempelduell test fixture (10 §6.9): static helpers shared by the test_sd_*.gd files (used via
## `const Sx := preload("res://tests/test_sd_fixture.gd")`) — the shared rulebook, harness decks, duels with a chosen
## hand, playing a duel to its end with a bot profile — plus the fixture's self-test.

const DECKS: String = "res://tests/fixtures/stempel/balance_decks.json"
const PROFILES: PackedStringArray = ["gut", "einfach", "zufall"]
const MAX_MOVES: int = 400


static func book() -> SdRulebook:
	return SdRulebook.shared()


## The parsed rulebook files (fresh copies, for negative tests and patched rulebooks).
static func files() -> Dictionary:
	var out: Dictionary = {}
	for f: String in ["cards", "opponents", "rules", "lines", "cosmetics", "awards"]:
		out[f] = JsonUtil.read_file("%s/%s.json" % [SdRulebook.DIR, f])
	return out


## The entry with `id` of a file's "entries" (or {}).
static func entry(f: Dictionary, file: String, id: String) -> Dictionary:
	for e: Variant in (f[file] as Dictionary)["entries"]:
		if e is Dictionary and str((e as Dictionary).get("id", "")) == id:
			return e
	return {}


## {card: copies} → sorted list.
static func deck_of(d: Dictionary) -> PackedStringArray:
	var ids: Array = d.keys()
	ids.sort()
	var out: PackedStringArray = []
	for k: Variant in ids:
		for _i in int(d[k]):
			out.append(str(k))
	return out


## A harness deck: "start" (the Startmappe) or a key of fixtures/stempel/balance_decks.json.
static func harness_deck(name: String) -> PackedStringArray:
	if name == "start":
		return book().startmappe_list()
	var raw: Variant = JsonUtil.read_file(DECKS)
	return deck_of(((raw as Dictionary)["decks"] as Dictionary)[name])


## A started duel against `opp` with the Startmappe whose first number is the player's (the first seed from
## `seed0` on where the player starts).
static func player_first(b: SdRulebook, opp: String, seed0: int = 1,
		deck: PackedStringArray = PackedStringArray()) -> SdDuel:
	var cards: PackedStringArray = deck if not deck.is_empty() else b.startmappe_list()
	for s in range(seed0, seed0 + 200):
		var duel: SdDuel = SdDuel.new(SdSetup.create(b, opp, cards, s), b)
		duel.start()
		if duel.side_to_move() == SdDuel.Side.PLAYER:
			return duel
	return null


## Replaces a side's hand (and syncs the engine's skill lists) — unit tests of single cards.
static func set_hand(duel: SdDuel, side: int, cards: Array) -> void:
	duel.hands[side] = PackedStringArray(cards)
	duel._sync()


## The move of a bot profile for the side to move: the opponent always plays EnemyAI; the player "gut" =
## SdAi.suggest, "einfach" = AutoPolicy, "zufall" = a random hand card, never filing (10 §6.9).
static func bot_move(duel: SdDuel, profile: String, rng: RandomNumberGenerator) -> Dictionary:
	if duel.side_to_move() == SdDuel.Side.OPPONENT:
		return duel.opponent_move()
	match profile:
		"gut":
			return SdAi.suggest(duel)
		"einfach":
			return duel.auto_policy_move()
	var forced: Dictionary = SdAi.forced(duel)
	if not forced.is_empty():
		return forced
	return {"op": "play", "slot": rng.randi_range(0, duel.hands[SdDuel.Side.PLAYER].size() - 1)}


## Plays a started duel to its end with `profile`; returns every event. `log` (optional) records the player's moves.
static func play_out(duel: SdDuel, profile: String, p_log: SdLog = null) -> Array[SdEvent]:
	var out: Array[SdEvent] = []
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = duel.setup.seed
	var n: int = 0
	while not duel.is_finished() and n < MAX_MOVES:
		n += 1
		var side: int = duel.side_to_move()
		var m: Dictionary = bot_move(duel, profile, rng)
		if p_log != null and side == SdDuel.Side.PLAYER:
			p_log.add(m)
		out.append_array(duel.submit(m))
	if p_log != null:
		p_log.finish(duel)
	return out


## A whole duel: setup, start, play out. {"duel", "events", "log"}.
static func full_duel(b: SdRulebook, opp: String, deck: PackedStringArray, seed: int, profile: String) -> Dictionary:
	var setup: SdSetup = SdSetup.create(b, opp, deck, seed)
	var d: SdDuel = SdDuel.new(setup, b)
	var events: Array[SdEvent] = d.start()
	var l: SdLog = SdLog.begin(setup)
	events.append_array(play_out(d, profile, l))
	return {"duel": d, "events": events, "log": l}


static func of_kind(events: Array[SdEvent], k: SdEvent.Kind) -> Array[SdEvent]:
	var out: Array[SdEvent] = []
	for e: SdEvent in events:
		if e.kind == k:
			out.append(e)
	return out


## Engine events of one type.
static func engine_of(events: Array[SdEvent], t: ActionEvent.Type) -> Array[ActionEvent]:
	var out: Array[ActionEvent] = []
	for e: SdEvent in events:
		if e.engine != null and e.engine.type == t:
			out.append(e.engine)
	return out


static func dicts(events: Array[SdEvent]) -> Array:
	var out: Array = []
	for e: SdEvent in events:
		out.append(e.to_dict())
	return out


# --- self-test ---------------------------------------------------------------------------------------------------

func test_fixture_helpers() -> void:
	var b: SdRulebook = book()
	assert_true(b.is_valid(), "the shared rulebook loads: %s" % "; ".join(b.errors))
	assert_len(harness_deck("start"), 20, "Startmappe")
	for name: String in ["ulla_passend", "meister_passend", "meister_erster_besuch"]:
		assert_eq(b.deck_problem(harness_deck(name)), "", name + " follows the deck rules")
	var d: SdDuel = player_first(b, "sdo_ferdi")
	assert_not_null(d, "a seed where the player starts")
	if d != null:
		set_hand(d, SdDuel.Side.PLAYER, ["sdc_stempel", "sdc_stempel", "sdc_suplex"])
		assert_eq(Array(d.combatant(SdDuel.Side.PLAYER).skills), ["skl_sdc_stempel"], "hand = skill list")
		assert_eq(Array(d.combatant(SdDuel.Side.PLAYER).stunts), ["skl_sdc_suplex"], "show cards = stunts")
