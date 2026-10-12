class_name SdRulebook extends RefCounted
## The Stempelduell rulebook (10 §6.4): data/stempel/*.json → checked by validators/sd_validator.gd → the engine data,
## an own GameData built through GameData.load_from_dicts (like Fx.tables() of the test_m1 fixture; never the campaign
## DB — the files live in a subfolder, DB.data_hash() does not see them) → the rules_hash. Pure RefCounted: no
## autoloads, no SceneTree, no clock.
##
## Conversion (10 §6.4): card sdc_x → skill skl_sdc_x (the card's skill block, user "any", mp_cost 0); the formal basic
## attack skl_sd_none (valid for DataValidator._check_attack_skill, never executed — the duel turns ATTACK into
## filing); the statuses sts_sd_*; opponent sdo_x → enemy enm_sdo_x (Geduld = HP, Tempo 10 for everybody, STR/MAG/DEF/
## RES 1, never an engine boss, SD-14); the Lernduell's Ferdi with his script → enemy enm_sd_lernduell; the Durchsage →
## pseudo unit pu_sd_durchsage. Engine names are the ids, so no display text reaches a battle hash.
##
## rules_hash = SHA-256 over CanonicalJson of the mechanics only — the engine tables, the deck rules of every card
## (max_copies, show, hand effect), the opponent decks, the constants, the Lernduell's decks and forced moves — plus
## SdDuel.SD_VERSION; every number enters in ppm (float-free, 1.5 → 1500000, 9 → 9000000). Names, texts, quips,
## lines, cosmetics, awards, unlocks and rewards stay out: a text fix never invalidates a replay.

const Validator := preload("res://core/stempel/validators/sd_validator.gd")
const FixedMath := preload("res://core/stats/fixed_math.gd")

const DIR: String = "res://data/stempel"
const BASIC_ATTACK: String = "skl_sd_none"
const TUTORIAL_ENEMY: String = "enm_sd_lernduell"
const STAT_ONE: PackedStringArray = ["str", "mag", "def", "res"]

var source: String = ""
var errors: PackedStringArray = []
var warnings: PackedStringArray = []
var files: Dictionary = {}                  # file name → parsed JSON (read only)
var cards: Dictionary = {}                  # id → SdCardDef
var card_ids: PackedStringArray = []        # file order
var opponents: Dictionary = {}              # id → SdOpponentDef
var opponent_ids: PackedStringArray = []    # file order
var constants: Dictionary = {}              # rules.json → constants (ints)
var statuses: Dictionary = {}               # id → entry (display + mechanics)
var status_ids: PackedStringArray = []
var durchsage: Dictionary = {}
var grundakte: PackedStringArray = []
var startmappe: Dictionary = {}             # card id → copies
var heft: PackedStringArray = []            # the Stempelheft order (cards, then cosmetics)
var rewards: Dictionary = {}                # {"tutorial": {...}, "album": {...}}
var autofill: Dictionary = {}               # {"max_per_art", "min_heal"}
var tutorial: Dictionary = {}               # the Lernduell (10 §1.10)
var lines: Dictionary = {}                  # tag → Array[Dictionary] (file order)
var cosmetics: Dictionary = {}              # id → entry
var cosmetic_ids: PackedStringArray = []
var awards: Dictionary = {}                 # id → entry
var award_ids: PackedStringArray = []
var data: GameData = null                   # the engine data
var rules_hash: String = ""

var _skill_cards: Dictionary = {}           # skl id → card id

static var _shared: SdRulebook = null


## Reads and checks data/stempel (or `dir`). `campaign` (optional, e.g. DB.data): also checks the campaign ids that
## unlock cards.
static func load_dir(dir: String = DIR, campaign: GameData = null) -> SdRulebook:
	var f: Dictionary = {}
	var read_errors: PackedStringArray = []
	for name: String in Validator.FILES:
		var path: String = dir.path_join(name + ".json")
		var parsed: Variant = JsonUtil.read_file(path)
		if parsed == null:
			read_errors.append("%s: %s (%s)" % [name, JsonUtil.last_error(), path])
		f[name] = parsed
	var book: SdRulebook = from_files(f, campaign, dir)
	if not read_errors.is_empty():
		read_errors.append_array(book.errors)
		book.errors = read_errors
	return book


## Builds the rulebook from parsed files ({"cards": {...}, "opponents": {...}, "rules", "lines", "cosmetics",
## "awards"}) — tests use it for negative cases.
static func from_files(p_files: Dictionary, campaign: GameData = null, p_source: String = "files") -> SdRulebook:
	var b: SdRulebook = SdRulebook.new()
	b.source = p_source
	b._load(p_files, campaign)
	return b


## The rulebook of data/stempel, loaded once per session (read only; without the campaign id check).
static func shared() -> SdRulebook:
	if _shared == null:
		_shared = load_dir(DIR)
	return _shared


func is_valid() -> bool:
	return errors.is_empty() and data != null and rules_hash != ""


# --- lookups ----------------------------------------------------------------------------------------------------------

func card(id: String) -> SdCardDef:
	return cards.get(id, null) as SdCardDef


func opponent(id: String) -> SdOpponentDef:
	return opponents.get(id, null) as SdOpponentDef


## Card id of an engine skill id ("" for skl_sd_none and unknown ids).
func card_of_skill(skill_id: String) -> String:
	return str(_skill_cards.get(skill_id, ""))


func constant(key: String) -> int:
	return int(constants.get(key, 0))


func hand_size() -> int:
	return constant("hand_size")


func deck_size() -> int:
	return constant("deck_size")


## The lines of a tag (file order; [] if none): {"id", "tag", "voice", "text"}.
func lines_for(tag: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.assign(lines.get(tag, []))
	return out


## The Startmappe as a list (sorted ids, repeated by count).
func startmappe_list() -> PackedStringArray:
	return Validator._expand(startmappe)


## Engine enemy id of a duel against `opponent_id` (the Lernduell has its own enemy with the script).
func enemy_id(opponent_id: String, p_tutorial: bool) -> String:
	return TUTORIAL_ENEMY if p_tutorial else "enm_" + opponent_id


## The Lernduell's opponent id (display: name, plate, symbol).
func tutorial_opponent() -> String:
	return str(tutorial.get("opponent", ""))


## Deck rules (10 §2.1) for a player deck — "" if it may be chosen, else the reason in one German sentence for the
## Aktenschrank ("Noch 3 Karten bis 20.", "Höchstens 2 × Doppelstempel."). Ownership is SdCollection's business.
func deck_problem(deck: PackedStringArray) -> String:
	var size: int = deck_size()
	if deck.size() < size:
		return "Noch %d %s bis %d." % [size - deck.size(), "Karte" if size - deck.size() == 1 else "Karten", size]
	if deck.size() > size:
		return "%d %s zu viel (genau %d)." % [deck.size() - size, "Karte" if deck.size() - size == 1 else "Karten",
			size]
	var counts: Dictionary = {}
	for cid: String in deck:
		var c: SdCardDef = card(cid)
		if c == null:
			return "Unbekannte Karte in der Mappe."
		counts[cid] = int(counts.get(cid, 0)) + 1
		var cap: int = mini(c.max_copies, constant("max_copies_show") if c.show else constant("max_copies"))
		if int(counts[cid]) > cap:
			return "Höchstens %d × %s." % [cap, c.name]
	return ""


## Campaign ids (skills, items, talents) that unlock cards and are unknown to `campaign` (10 §2.5).
func campaign_problems(campaign: GameData) -> PackedStringArray:
	var out: PackedStringArray = []
	for cid: String in card_ids:
		for src: String in (cards[cid] as SdCardDef).campaign:
			if campaign == null or not campaign.has_id(Validator._campaign_table(src), src):
				out.append("cards[%s].campaign: unknown campaign id '%s'" % [cid, src])
	return out


# --- engine data ----------------------------------------------------------------------------------------------------

## The tables for GameData.load_from_dicts (statuses, skills, enemies, pseudo_units) — mechanics only, names = ids.
func engine_tables() -> Dictionary:
	var sts: Array = []
	for sid: String in status_ids:
		var s: Dictionary = statuses[sid]
		var e: Dictionary = {"id": sid, "name": sid}
		for k: String in Validator.STATUS_MECH_KEYS:
			if k != "id" and s.has(k):
				e[k] = _copy(s[k])
		sts.append(e)
	var skills: Array = [{"id": BASIC_ATTACK, "name": BASIC_ATTACK, "user": "any", "category": "attack",
		"target": "single_enemy", "damage_type": "physical", "element": "physical", "power": 100, "rank": 3}]
	for cid: String in card_ids:
		var c: SdCardDef = cards[cid]
		var e: Dictionary = {"id": c.skill_id(), "name": c.skill_id(), "user": "any", "mp_cost": 0}
		for k: Variant in c.skill.keys():
			if Validator.SKILL_KEYS.has(str(k)):
				e[str(k)] = _copy(c.skill[k])
		skills.append(e)
	var enemies: Array = []
	for oid: String in opponent_ids:
		var o: SdOpponentDef = opponents[oid]
		enemies.append(_enemy(o.enemy_id(), o.geduld, o.element_mods, o.status_immune, o.ai, o.phases))
	var tut_opp: SdOpponentDef = opponent(tutorial_opponent())
	if tut_opp != null:
		var tai: Variant = tutorial.get("ai", {})
		enemies.append(_enemy(TUTORIAL_ENEMY, JsonUtil.to_int(tutorial.get("geduld", 1), 1), tut_opp.element_mods,
			tut_opp.status_immune, tai if tai is Dictionary else {}, []))
	var pseudo: Array = []
	if not durchsage.is_empty():
		var pid: String = str(durchsage.get("id", ""))
		pseudo.append({"id": pid, "name": pid, "icon": "", "action": _copy(durchsage.get("action", {})),
			"ctr_after": durchsage.get("ctr_after", 100), "warn_tag": str(durchsage.get("warn_tag", "")),
			"warn_at": durchsage.get("warn_at", 2)})
	return {"statuses": sts, "skills": skills, "enemies": enemies, "pseudo_units": pseudo}


## The mechanics that rules_hash covers (see the header).
func hash_input() -> Dictionary:
	var deck_rules: Dictionary = {}
	for cid: String in card_ids:
		var c: SdCardDef = cards[cid]
		deck_rules[cid] = {"max_copies": c.max_copies, "show": c.show, "hand": c.hand}
	var decks: Dictionary = {}
	for oid: String in opponent_ids:
		decks[oid] = Array((opponents[oid] as SdOpponentDef).deck_list())
	var forced: Array = []
	for l: Variant in tutorial.get("lessons", []):
		if l is Dictionary:
			forced.append({"ticket": (l as Dictionary).get("ticket", 0), "move": str((l as Dictionary).get("move", "")),
				"card": str((l as Dictionary).get("card", ""))})
	var tut: Dictionary = {"opponent": tutorial_opponent(), "player_deck": _copy(tutorial.get("player_deck", [])),
		"opponent_deck": _copy(tutorial.get("opponent_deck", [])), "forced": forced}
	return {"sd_version": SdDuel.SD_VERSION, "engine": _ppm_numbers(engine_tables()),
		"duel": _ppm_numbers({"constants": constants, "cards": deck_rules, "decks": decks, "tutorial": tut})}


# --- loading --------------------------------------------------------------------------------------------------------

func _load(p_files: Dictionary, campaign: GameData) -> void:
	files = p_files
	var v: Validator = Validator.new()
	v.check(p_files, campaign)
	errors = v.errors.duplicate()
	warnings = v.warnings.duplicate()
	for f: String in Validator.FILES:
		if not p_files.get(f, null) is Dictionary:
			return
	_build()
	var tables: Dictionary = engine_tables()
	data = GameData.new()
	data.load_from_dicts(tables)
	for e: String in data.errors:
		errors.append("engine: " + e)
	for w: String in data.warnings:
		warnings.append("engine: " + w)
	rules_hash = CanonicalJson.sha256_hex(hash_input()) if errors.is_empty() else ""


func _build() -> void:
	for e: Variant in _entries("cards"):
		var c: SdCardDef = SdCardDef.from_dict(e)
		if c.id != "" and not cards.has(c.id):
			cards[c.id] = c
			card_ids.append(c.id)
			_skill_cards[c.skill_id()] = c.id
	for e: Variant in _entries("opponents"):
		var o: SdOpponentDef = SdOpponentDef.from_dict(e)
		if o.id != "" and not opponents.has(o.id):
			opponents[o.id] = o
			opponent_ids.append(o.id)
	var rules: Dictionary = files["rules"]
	var c_raw: Variant = rules.get("constants", {})
	for k: Variant in ((c_raw as Dictionary).keys() if c_raw is Dictionary else []):
		constants[str(k)] = JsonUtil.to_int((c_raw as Dictionary)[k])
	for s: Variant in (rules.get("statuses", []) if rules.get("statuses", []) is Array else []):
		if s is Dictionary and not statuses.has(str((s as Dictionary).get("id", ""))):
			statuses[str((s as Dictionary)["id"])] = (s as Dictionary).duplicate(true)
			status_ids.append(str((s as Dictionary)["id"]))
	durchsage = _dict(rules.get("durchsage", {}))
	grundakte = JsonUtil.to_str_array(rules.get("grundakte", []))
	var sm: Dictionary = _dict(rules.get("startmappe", {}))
	for k: Variant in sm.keys():
		startmappe[str(k)] = JsonUtil.to_int(sm[k])
	heft = JsonUtil.to_str_array(rules.get("heft", []))
	rewards = _dict(rules.get("rewards", {}))
	autofill = _dict(rules.get("autofill", {}))
	tutorial = _dict(rules.get("tutorial", {}))
	for e: Variant in _entries("lines"):
		var tag: String = str((e as Dictionary).get("tag", ""))
		if not lines.has(tag):
			lines[tag] = []
		(lines[tag] as Array).append((e as Dictionary).duplicate(true))
	for e: Variant in _entries("cosmetics"):
		var id: String = str((e as Dictionary).get("id", ""))
		if id != "" and not cosmetics.has(id):
			cosmetics[id] = (e as Dictionary).duplicate(true)
			cosmetic_ids.append(id)
	for e: Variant in _entries("awards"):
		var id: String = str((e as Dictionary).get("id", ""))
		if id != "" and not awards.has(id):
			awards[id] = (e as Dictionary).duplicate(true)
			award_ids.append(id)


func _entries(file: String) -> Array:
	var out: Array = []
	var f: Variant = files.get(file, {})
	var list: Variant = (f as Dictionary).get("entries", []) if f is Dictionary else []
	for e: Variant in (list as Array if list is Array else []):
		if e is Dictionary:
			out.append(e)
	return out


func _enemy(eid: String, geduld: int, mods: Dictionary, immune: PackedStringArray, ai: Dictionary,
		phases: Array[Dictionary]) -> Dictionary:
	var stats: Dictionary = {"hp": geduld, "mp": 0, "spd": constant("tempo"), "lck": 0}
	for k: String in STAT_ONE:
		stats[k] = 1
	return {"id": eid, "name": eid, "level": 1, "stats": stats, "exp": 0, "credits": 0,
		"attack_skill": BASIC_ATTACK, "ai": _copy(ai), "phases": _copy(phases), "element_mods": _copy(mods),
		"status_immune": Array(immune), "boss": false,
		"model": {"base": "humanoid", "colors": {"primary": "#808080"}}, "explore": {"field_speed": 0.0}}


static func _dict(v: Variant) -> Dictionary:
	return (v as Dictionary).duplicate(true) if v is Dictionary else {}


static func _copy(v: Variant) -> Variant:
	if v is Dictionary:
		return (v as Dictionary).duplicate(true)
	if v is Array:
		return (v as Array).duplicate(true)
	return v


## Deep copy with every number as ppm int (JSON floats and ints alike: 1.5 → 1500000, 9 → 9000000), packed arrays as
## arrays — a float-free, canonical form of the mechanics.
static func _ppm_numbers(v: Variant) -> Variant:
	match typeof(v):
		TYPE_INT, TYPE_FLOAT:
			return FixedMath.ppm(float(v))
		TYPE_DICTIONARY:
			var out: Dictionary = {}
			for k: Variant in (v as Dictionary).keys():
				out[str(k)] = _ppm_numbers((v as Dictionary)[k])
			return out
		TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY:
			var arr: Array = []
			for e: Variant in Array(v):
				arr.append(_ppm_numbers(e))
			return arr
	return v
