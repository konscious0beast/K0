class_name SdSetup extends RefCounted
## Input of one Stempelduell (10 §6.5): seed, opponent, the player's deck, the Lernduell flag and the rules_hash the
## duel was set up with. Float-free; no names, no persona (10 §6.6). The free-play seed is
## SeedUtil.derive(collection seed, "sd", n) (SdCollection.next_duel_seed), on floor 8 RunRules.next_seed(state, "sd")
## (SD3).

var seed: int = 1
var opponent_id: String = ""
var player_deck: PackedStringArray = []     # the Mappe as chosen (order irrelevant: the duel sorts, then shuffles)
var tutorial: bool = false                  # the Lernduell (10 §1.10): fixed order, script, half Ärger, Geduld >= 1
var rules_hash: String = ""


static func create(book: SdRulebook, p_opponent: String, p_deck: PackedStringArray, p_seed: int) -> SdSetup:
	var s: SdSetup = SdSetup.new()
	s.seed = p_seed
	s.opponent_id = p_opponent
	s.player_deck = p_deck.duplicate()
	s.rules_hash = book.rules_hash if book != null else ""
	return s


## The Lernduell against Ferdi with its fixed deck (any seed plays the same script).
static func lernduell(book: SdRulebook, p_seed: int = 1) -> SdSetup:
	var s: SdSetup = create(book, book.tutorial_opponent(), JsonUtil.to_str_array(book.tutorial.get("player_deck", [])),
		p_seed)
	s.tutorial = true
	return s


## "" if a duel can start with this setup, else the reason (English, for logs): the rulebook is valid, the rules_hash
## is the current one, the opponent is known, the deck follows the deck rules (the Lernduell: exactly its deck).
## Ownership of the cards is the collection's business (10 §6.8: the campaign command does not check it either).
func problem(book: SdRulebook) -> String:
	if book == null or not book.is_valid():
		return "invalid rulebook"
	if rules_hash != book.rules_hash:
		return "other rules (rules_hash)"
	if book.opponent(opponent_id) == null:
		return "unknown opponent '%s'" % opponent_id
	if tutorial:
		if opponent_id != book.tutorial_opponent() \
				or player_deck != JsonUtil.to_str_array(book.tutorial.get("player_deck", [])):
			return "the Lernduell plays its own deck"
		return ""
	var deck_problem: String = book.deck_problem(player_deck)
	if deck_problem != "":
		return "deck: " + deck_problem
	return ""


func to_dict() -> Dictionary:
	return {"seed": str(seed), "opp": opponent_id, "deck": Array(player_deck), "tut": tutorial, "rh": rules_hash}


## Inverse of to_dict; seeds as decimal strings or numbers.
static func from_dict(d: Dictionary) -> SdSetup:
	var s: SdSetup = SdSetup.new()
	s.seed = JsonUtil.to_int(d.get("seed", 1), 1)
	s.opponent_id = str(d.get("opp", ""))
	s.player_deck = JsonUtil.to_str_array(d.get("deck", []))
	s.tutorial = bool(d.get("tut", false))
	s.rules_hash = str(d.get("rh", ""))
	return s
