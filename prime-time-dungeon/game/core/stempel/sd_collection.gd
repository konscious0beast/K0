class_name SdCollection extends RefCounted
## The account collection of the Stempelduell (10 §5.2, §6.7): owned cards, the three Mappen, victories, the
## Stempelheft, cosmetics, Dienstauszeichnungen, options, the duel seed counter. Pure: to_dict / from_dict only — the
## file (user://stempel/collection.json) is written by autoload/save.gd later (SD2 save hook), never here.
## Catalog ids and numbers only — no names, no persona (08 P-1, D-2); "Kandidat:in löschen" leaves it alone.
## A broken or unreadable file gives an empty collection with `was_reset` (the screen toasts „Stempelakte neu
## angelegt"); the Grundakte comes back with the Lernduell, campaign unlocks with the next reading of the slots.
## Rewards (10 §5.2): the Lernduell → Grundakte, Startmappe as Mappe A, cosmetics of rules.json → rewards.tutorial;
## the first victory over an opponent → its first_win cards and cosmetics; every victory a Stempelheft stamp, every
## `heft_every` stamps the next entry of the heft order that is not owned yet (cards first, then cosmetics); the full
## album → rewards.album. Nothing is bought, nothing is rolled, a defeat costs nothing.

const VERSION: int = 1
const MAPPEN: PackedStringArray = ["a", "b", "c"]
const COSMETIC_SLOTS: PackedStringArray = ["back", "ink", "mat", "title"]
const OPTION_DEFAULTS: Dictionary = {"speed": 1, "reduce_motion": false, "hints": true, "open_hand": false,
	"left_handed": false, "text_size": 100}
const SPEEDS: Array = [1, 2]
const TEXT_SIZES: Array = [100, 125, 150]
const AWARD_TUTORIAL: String = "sda_tutorial"
const AWARD_FIRST_WIN: String = "sda_first_win"
const AWARD_CHAIN: String = "sda_chain"
const AWARD_NO_FILE: String = "sda_no_file"
const AWARD_CLOSE: String = "sda_close"
const AWARD_SHOW_5: String = "sda_show_5"
const AWARD_TERMIN: String = "sda_termin"
const AWARD_DURCHSAGE: String = "sda_durchsage"
const AWARD_AMT: String = "sda_amt"
const AWARD_GRAF: String = "sda_graf"
const AMT_OPPONENTS: PackedStringArray = ["sdo_ferdi", "sdo_ulla", "sdo_meister"]
const GRAF_OPPONENT: String = "sdo_graf"
const CHAIN_MIN: int = 3
const CLOSE_MAX: int = 3
const SHOW_MIN: int = 5
const TERMIN_MIN: int = 3

var seed: int = 0                           # account seed (drawn once by the caller; 0 = not set yet)
var n: int = 0                              # duels started: the next free-play seed is derive(seed, "sd", n)
var owned: PackedStringArray = []           # card ids, sorted
var decks: Dictionary = {"a": PackedStringArray(), "b": PackedStringArray(), "c": PackedStringArray()}
var active: String = "a"
var beaten: Dictionary = {}                 # opponent id → victories
var heft: int = 0                           # Stempelheft stamps (= victories outside the Lernduell)
var cosmetics: Dictionary = {"back": "", "ink": "", "mat": "", "title": "", "owned": PackedStringArray()}
var awards: PackedStringArray = []
var options: Dictionary = OPTION_DEFAULTS.duplicate()
var tutorial: bool = false                  # the Lernduell is done (or skipped)
var campaign_seen: PackedStringArray = []   # campaign ids that unlocked cards (10 §2.5)
var stats: Dictionary = {"duels": 0, "wins": 0, "show_ok": 0, "loss_streak": 0}
var was_reset: bool = false                 # from_dict found a broken file


## A fresh collection with the account seed (the caller draws it once, e.g. randi() in the save hook).
static func create(p_seed: int) -> SdCollection:
	var c: SdCollection = SdCollection.new()
	c.seed = p_seed
	return c


# --- seed counter ---------------------------------------------------------------------------------------------------

## The seed of the next free-play duel (10 §6.6): derive(seed, "sd", n), then n + 1 — save the collection before the
## duel starts, so a restart never deals the same duel again.
func next_duel_seed() -> int:
	var s: int = SeedUtil.derive(seed, "sd", n)
	n += 1
	return s


# --- cards and Mappen ------------------------------------------------------------------------------------------------

func owns(card_id: String) -> bool:
	return owned.has(card_id)


## Adds the cards not owned yet; returns those that are new.
func unlock_cards(ids: PackedStringArray, book: SdRulebook) -> PackedStringArray:
	var out: PackedStringArray = []
	for cid: String in ids:
		if book.card(cid) != null and not owned.has(cid) and not out.has(cid):
			out.append(cid)
	owned.append_array(out)
	owned.sort()
	return out


## Campaign unlocks (10 §2.5): every card whose `campaign` ids meet `source_ids` (learned skills, owned items, chosen
## talents of any save slot — ids only). Returns the newly owned cards; the matching ids go to campaign_seen.
func apply_campaign(source_ids: PackedStringArray, book: SdRulebook) -> PackedStringArray:
	var hit: PackedStringArray = []
	for cid: String in book.card_ids:
		for src: String in (book.card(cid) as SdCardDef).campaign:
			if source_ids.has(src):
				hit.append(cid)
				if not campaign_seen.has(src):
					campaign_seen.append(src)
	campaign_seen.sort()
	return unlock_cards(hit, book)


func deck(name: String) -> PackedStringArray:
	return (decks.get(name, PackedStringArray()) as PackedStringArray).duplicate()


func active_deck() -> PackedStringArray:
	return deck(active)


## Stores `cards` as Mappe `name` (a, b, c); false for an unknown name. Any content is stored (the Aktenschrank
## saves half-built Mappen too); only a Mappe without deck_problem can be chosen for a duel.
func set_deck(name: String, cards: PackedStringArray) -> bool:
	if not MAPPEN.has(name):
		return false
	decks[name] = cards.duplicate()
	return true


func set_active(name: String) -> bool:
	if not MAPPEN.has(name):
		return false
	active = name
	return true


## "" if `cards` can be chosen for a duel, else the reason in one German sentence: the deck rules of the rulebook,
## then ownership ("Nicht im Besitz: Wuchtschlag.").
func deck_problem(cards: PackedStringArray, book: SdRulebook) -> String:
	var rule: String = book.deck_problem(cards)
	if rule != "":
		return rule
	for cid: String in cards:
		if not owned.has(cid):
			return "Nicht im Besitz: %s." % book.card(cid).name
	return ""


## "Automatisch füllen" (10 §2.6): keeps the valid owned part of `cards` (in order, copy limits, at most the deck
## size), then fills up to the deck size with a fixed rule — missing Grundakte cards (one copy each, Grundakte
## order), heals up to autofill.min_heal, then by Ärger per Werktag (show cards by their expectation; ties: file
## order of cards.json) with at most autofill.max_per_art cards per Formular-Art, finally anything owned. Never an
## unplayable deck as long as the Grundakte is owned.
func auto_fill(cards: PackedStringArray, book: SdRulebook) -> PackedStringArray:
	var out: PackedStringArray = []
	var size: int = book.deck_size()
	for cid: String in cards:
		if out.size() < size and _room(out, cid, book):
			out.append(cid)
	for cid: String in book.grundakte:
		if out.size() < size and not out.has(cid) and _room(out, cid, book):
			out.append(cid)
	var min_heal: int = JsonUtil.to_int(book.autofill.get("min_heal", 3), 3)
	for cid: String in _ranked(book, true):
		while out.size() < size and _count_heals(out, book) < min_heal and _room(out, cid, book):
			out.append(cid)
	var max_art: int = JsonUtil.to_int(book.autofill.get("max_per_art", 6), 6)
	var ranked: PackedStringArray = _ranked(book, false)
	for cid: String in ranked:
		while out.size() < size and _room(out, cid, book) and _art_count(out, book.card(cid).art, book) < max_art:
			out.append(cid)
	for cid: String in ranked:
		while out.size() < size and _room(out, cid, book):
			out.append(cid)
	return out


# --- opponents and duels -------------------------------------------------------------------------------------------

## The opponent may be chosen: Lernduell done and its predecessor beaten (10 §3.1 "Frei ab").
func is_unlocked(opponent_id: String, book: SdRulebook) -> bool:
	var o: SdOpponentDef = book.opponent(opponent_id)
	if o == null or not tutorial:
		return false
	return o.unlock_after == "" or wins_against(o.unlock_after) > 0


func wins_against(opponent_id: String) -> int:
	return JsonUtil.to_int(beaten.get(opponent_id, 0))


## The Lernduell is done or skipped ("Ich kenne mich aus"): Grundakte, the Startmappe as Mappe A (if A is empty),
## rules.json → rewards.tutorial, the award. Only the first call gives something. Returns the rewards
## {"cards", "cosmetics", "awards", "heft": false}.
func complete_tutorial(book: SdRulebook) -> Dictionary:
	var r: Dictionary = _rewards()
	if tutorial:
		return r
	tutorial = true
	r["cards"] = unlock_cards(book.grundakte, book)
	if (decks["a"] as PackedStringArray).is_empty():
		decks["a"] = book.startmappe_list()
	var tut: Dictionary = book.rewards.get("tutorial", {})
	r["cosmetics"] = _unlock_cosmetics(JsonUtil.to_str_array(tut.get("cosmetics", [])), book)
	_award(AWARD_TUTORIAL, r)
	return r


## Books a finished duel (SdDuel.summary()) and returns its rewards {"cards", "cosmetics", "awards", "heft": bool
## (a stamp was set)}. The Lernduell completes the tutorial when won; an adjourned duel changes nothing.
func record_duel(summary: Dictionary, book: SdRulebook) -> Dictionary:
	if bool(summary.get("tut", false)):
		return complete_tutorial(book) if str(summary.get("result", "")) == "won" else _rewards()
	var r: Dictionary = _rewards()
	var result: String = str(summary.get("result", ""))
	if result == "adjourned" or result == "running":
		return r
	var opp: String = str(summary.get("opp", ""))
	stats["duels"] = int(stats["duels"]) + 1
	stats["show_ok"] = int(stats["show_ok"]) + JsonUtil.to_int(summary.get("show_ok", 0))
	if _first(summary.get("max_chain", [0]), 0) >= CHAIN_MIN:
		_award(AWARD_CHAIN, r)
	if _first(summary.get("wiedervorlagen", [0]), 0) >= TERMIN_MIN:
		_award(AWARD_TERMIN, r)
	if JsonUtil.to_int(summary.get("durchsage_filed", 0)) >= 1:
		_award(AWARD_DURCHSAGE, r)
	if int(stats["show_ok"]) >= SHOW_MIN:
		_award(AWARD_SHOW_5, r)
	if result != "won":
		stats["loss_streak"] = int(stats["loss_streak"]) + 1
		return r
	stats["loss_streak"] = 0
	stats["wins"] = int(stats["wins"]) + 1
	var o: SdOpponentDef = book.opponent(opp)
	if o == null:
		return r
	beaten[opp] = wins_against(opp) + 1
	if wins_against(opp) == 1:
		r["cards"] = unlock_cards(o.first_win_cards(), book)
		r["cosmetics"] = _unlock_cosmetics(o.first_win_cosmetics(), book)
	_award(AWARD_FIRST_WIN, r)
	if _first(summary.get("filed", [0]), 0) == 0:
		_award(AWARD_NO_FILE, r)
	if _first(summary.get("geduld", [0]), 0) <= CLOSE_MAX:
		_award(AWARD_CLOSE, r)
	if opp == GRAF_OPPONENT:
		_award(AWARD_GRAF, r)
	var amt: bool = true
	for a: String in AMT_OPPONENTS:
		amt = amt and wins_against(a) > 0
	if amt:
		_award(AWARD_AMT, r)
	heft += 1
	r["heft"] = true
	if heft % maxi(1, book.constant("heft_every")) == 0:
		_heft_reward(book, r)
	_album_reward(book, r)
	return r


## The next entry of the Stempelheft order that is not owned yet ("" when the heft is complete).
func next_heft_reward(book: SdRulebook) -> String:
	for id: String in book.heft:
		if not owned.has(id) and not (cosmetics["owned"] as PackedStringArray).has(id):
			return id
	return ""


## Two defeats in a row: the Graf offers a tip for the Mappe (10 §5.5).
func wants_deck_tip() -> bool:
	return int(stats["loss_streak"]) >= 2


# --- cosmetics and options ---------------------------------------------------------------------------------------

func owns_cosmetic(id: String) -> bool:
	return (cosmetics["owned"] as PackedStringArray).has(id)


## Equips an owned cosmetic in its slot (back, ink, mat, title); false if unknown or not owned.
func equip(id: String, book: SdRulebook) -> bool:
	var c: Dictionary = book.cosmetics.get(id, {})
	if c.is_empty() or not owns_cosmetic(id):
		return false
	cosmetics[str(c.get("kind", ""))] = id
	return true


func unequip(slot: String) -> void:
	if COSMETIC_SLOTS.has(slot):
		cosmetics[slot] = ""


## Sets an option (keys of OPTION_DEFAULTS; speed 1/2, text_size 100/125/150, the rest bools); false if refused.
func set_option(key: String, value: Variant) -> bool:
	if not OPTION_DEFAULTS.has(key):
		return false
	var v: Variant = _option_value(key, value)
	if v == null:
		return false
	options[key] = v
	return true


# --- file ----------------------------------------------------------------------------------------------------------

## {"v", "seed", "n", "owned", "decks", "active", "beaten", "heft", "cosmetics", "awards", "options", "tutorial",
## "campaign_seen", "stats"} — ids and numbers only (10 §6.7).
func to_dict() -> Dictionary:
	var dk: Dictionary = {}
	for m: String in MAPPEN:
		dk[m] = Array(deck(m))
	var cos: Dictionary = {}
	for s: String in COSMETIC_SLOTS:
		cos[s] = str(cosmetics.get(s, ""))
	cos["owned"] = Array(cosmetics["owned"] as PackedStringArray)
	var bt: Dictionary = {}
	var keys: Array = beaten.keys()
	keys.sort()
	for k: Variant in keys:
		bt[str(k)] = wins_against(str(k))
	return {"v": VERSION, "seed": str(seed), "n": n, "owned": Array(owned), "decks": dk, "active": active,
		"beaten": bt, "heft": heft, "cosmetics": cos, "awards": Array(awards), "options": options.duplicate(),
		"tutorial": tutorial, "campaign_seen": Array(campaign_seen), "stats": stats.duplicate()}


## Inverse of to_dict (also after a JSON round trip). Unknown ids are dropped (against `book`); a broken file — not
## an object, another version, the card lists of the wrong type — gives an empty collection with was_reset = true.
static func from_dict(v: Variant, book: SdRulebook) -> SdCollection:
	var c: SdCollection = SdCollection.new()
	if not v is Dictionary or JsonUtil.to_int((v as Dictionary).get("v", 0)) != VERSION \
			or not (v as Dictionary).get("owned", null) is Array or not (v as Dictionary).get("decks", null) is Dictionary:
		c.was_reset = true
		return c
	var d: Dictionary = v
	c.seed = JsonUtil.to_int(d.get("seed", 0))
	c.n = maxi(0, JsonUtil.to_int(d.get("n", 0)))
	c.unlock_cards(JsonUtil.to_str_array(d["owned"]), book)
	for m: String in MAPPEN:
		var cards: PackedStringArray = []
		for cid: String in JsonUtil.to_str_array((d["decks"] as Dictionary).get(m, [])):
			if book.card(cid) != null:
				cards.append(cid)
		c.decks[m] = cards
	c.active = str(d.get("active", "a")) if MAPPEN.has(str(d.get("active", "a"))) else "a"
	var bt: Variant = d.get("beaten", {})
	for k: Variant in ((bt as Dictionary).keys() if bt is Dictionary else []):
		if book.opponent(str(k)) != null and JsonUtil.to_int((bt as Dictionary)[k]) > 0:
			c.beaten[str(k)] = JsonUtil.to_int((bt as Dictionary)[k])
	c.heft = maxi(0, JsonUtil.to_int(d.get("heft", 0)))
	var cos: Variant = d.get("cosmetics", {})
	if cos is Dictionary:
		c._unlock_cosmetics(JsonUtil.to_str_array((cos as Dictionary).get("owned", [])), book)
		for s: String in COSMETIC_SLOTS:
			var id: String = str((cos as Dictionary).get(s, ""))
			if c.owns_cosmetic(id) and str((book.cosmetics.get(id, {}) as Dictionary).get("kind", "")) == s:
				c.cosmetics[s] = id
	for a: String in JsonUtil.to_str_array(d.get("awards", [])):
		if book.awards.has(a) and not c.awards.has(a):
			c.awards.append(a)
	var opts: Variant = d.get("options", {})
	for k: String in OPTION_DEFAULTS:
		if opts is Dictionary and (opts as Dictionary).has(k):
			c.set_option(k, (opts as Dictionary)[k])
	c.tutorial = bool(d.get("tutorial", false))
	var source_id: RegEx = RegEx.create_from_string("^(skl|itm|tal)_[a-z0-9_]+$")
	for src: String in JsonUtil.to_str_array(d.get("campaign_seen", [])):
		if source_id.search(src) != null and not c.campaign_seen.has(src):
			c.campaign_seen.append(src)
	c.campaign_seen.sort()
	var st: Variant = d.get("stats", {})
	for k: String in c.stats.keys():
		if st is Dictionary:
			c.stats[k] = maxi(0, JsonUtil.to_int((st as Dictionary).get(k, 0)))
	return c


# --- internals -----------------------------------------------------------------------------------------------------

static func _rewards() -> Dictionary:
	return {"cards": PackedStringArray(), "cosmetics": PackedStringArray(), "awards": PackedStringArray(),
		"heft": false}


func _award(id: String, r: Dictionary) -> void:
	if awards.has(id):
		return
	awards.append(id)
	var list: PackedStringArray = r["awards"]
	list.append(id)
	r["awards"] = list


func _unlock_cosmetics(ids: PackedStringArray, book: SdRulebook) -> PackedStringArray:
	var have: PackedStringArray = cosmetics["owned"]
	var out: PackedStringArray = []
	for id: String in ids:
		if book.cosmetics.has(id) and not have.has(id) and not out.has(id):
			out.append(id)
	have.append_array(out)
	have.sort()
	cosmetics["owned"] = have
	return out


func _heft_reward(book: SdRulebook, r: Dictionary) -> void:
	var id: String = next_heft_reward(book)
	if id == "":
		return
	if book.card(id) != null:
		var cards: PackedStringArray = r["cards"]
		cards.append_array(unlock_cards(PackedStringArray([id]), book))
		r["cards"] = cards
	else:
		var cos: PackedStringArray = r["cosmetics"]
		cos.append_array(_unlock_cosmetics(PackedStringArray([id]), book))
		r["cosmetics"] = cos


func _album_reward(book: SdRulebook, r: Dictionary) -> void:
	if owned.size() < book.card_ids.size():
		return
	var cos: PackedStringArray = r["cosmetics"]
	var album: Dictionary = book.rewards.get("album", {})
	cos.append_array(_unlock_cosmetics(JsonUtil.to_str_array(album.get("cosmetics", [])), book))
	r["cosmetics"] = cos


## `cid` may be added to `deck`: a known, owned card below its copy limit.
func _room(deck_list: PackedStringArray, cid: String, book: SdRulebook) -> bool:
	var c: SdCardDef = book.card(cid)
	if c == null or not owned.has(cid):
		return false
	var cap: int = mini(c.max_copies, book.constant("max_copies_show") if c.show else book.constant("max_copies"))
	return deck_list.count(cid) < cap


## Owned cards by Ärger per Werktag (`heal`: Geduld per Werktag, heal cards only), best first; show cards by their
## expected Ärger; ties: cards.json order.
func _ranked(book: SdRulebook, heal: bool) -> PackedStringArray:
	var rows: Array = []
	for i in book.card_ids.size():
		var c: SdCardDef = book.card(book.card_ids[i])
		if not owned.has(c.id) or (heal and c.heal() <= 0):
			continue
		var value_pm: int = c.heal() * 1000 if heal else c.damage() * c.chance_pm()
		rows.append([value_pm * 1000 / maxi(1, c.rank()), i, c.id])
	rows.sort_custom(func(a: Array, b: Array) -> bool:
		return int(a[0]) > int(b[0]) if int(a[0]) != int(b[0]) else int(a[1]) < int(b[1]))
	var out: PackedStringArray = []
	for row: Array in rows:
		out.append(str(row[2]))
	return out


static func _count_heals(deck_list: PackedStringArray, book: SdRulebook) -> int:
	var k: int = 0
	for cid: String in deck_list:
		if book.card(cid) != null and book.card(cid).heal() > 0:
			k += 1
	return k


static func _art_count(deck_list: PackedStringArray, art: String, book: SdRulebook) -> int:
	var k: int = 0
	for cid: String in deck_list:
		if book.card(cid) != null and book.card(cid).art == art:
			k += 1
	return k


static func _first(v: Variant, fallback: int) -> int:
	return JsonUtil.to_int((v as Array)[0]) if v is Array and not (v as Array).is_empty() else fallback


static func _option_value(key: String, value: Variant) -> Variant:
	match key:
		"speed":
			return int(value) if JsonUtil.is_integral(value) and SPEEDS.has(int(value)) else null
		"text_size":
			return int(value) if JsonUtil.is_integral(value) and TEXT_SIZES.has(int(value)) else null
	return bool(value) if typeof(value) == TYPE_BOOL else null
