extends RefCounted
## Private helper of SdRulebook (no class_name, 02_TECH §0.3): the Stempelduell's own validator (10 §6.4, §3.9) —
## the campaign DataValidator gets no new rule. Works on the parsed files of data/stempel ({"cards": {...}, …}) and
## appends one message per problem to `errors` ("<file>[<i>|<id>].<field>: <message>"). Engine-level rules (field
## ranges, AI target rules, phase rules) are checked afterwards by GameData.load_from_dicts on the converted tables;
## this file covers what the engine cannot know: the file schema, the deck rules (opponent decks, Startmappe, the
## Lernduell), an AI entry for every card of an opponent deck, reachable cards, references between the files (lines
## for every tag the code or the data names, cosmetics, awards), the campaign ids that unlock cards (against the
## campaign GameData when one is given) and the texts: IP words (validators/ip_words.gd plus an own list — no real
## authorities, no famous bureaucracy quotes, no DCC terms), no royalty motif anywhere, no royal plural in Graf
## Mopsula's voice, ≤ 110 characters, known placeholders, no font-less glyphs, short names ≤ 7 characters.

const IpWords := preload("res://core/data/validators/ip_words.gd")

const FILES: PackedStringArray = ["cards", "opponents", "rules", "lines", "cosmetics", "awards"]
const ENTRY_FILES: PackedStringArray = ["cards", "opponents", "lines", "cosmetics", "awards"]
const RULES_KEYS: PackedStringArray = ["schema", "constants", "statuses", "durchsage", "grundakte", "startmappe",
	"heft", "rewards", "autofill", "tutorial"]
const CONSTANT_RANGES: Dictionary = {"deck_size": [5, 40], "hand_size": [1, 8], "max_copies": [1, 4],
	"max_copies_show": [1, 4], "player_geduld": [1, 999], "tempo": [1, 99], "dienstschluss": [10, 999],
	"dienstschluss_warn": [1, 998], "tutorial_dmg_pct": [1, 100], "mappen": [1, 9], "heft_every": [1, 20]}
const CARD_KEYS: PackedStringArray = ["id", "name", "art", "origin", "owner", "max_copies", "show", "form", "text",
	"quip", "campaign", "hand", "skill"]
## Mechanical fields of a card's skill block (SkillDef, CTB meaning) — display fields (anim, vfx, …) stay out so the
## rules_hash only moves with the mechanics.
const SKILL_KEYS: PackedStringArray = ["category", "target", "damage_type", "element", "power", "heal_mode", "hits",
	"rank", "statuses", "cleanse", "success_base", "success_lck", "success_cap", "fail_effect", "cooldown"]
const SHOW_KEYS: PackedStringArray = ["success_base", "success_lck", "success_cap", "fail_effect", "cooldown"]
const CATEGORIES: PackedStringArray = ["attack", "magic", "heal", "buff", "debuff", "stunt"]
const OPPONENT_KEYS: PackedStringArray = ["id", "name", "short", "role", "akte", "rule", "symbol", "geduld",
	"element_mods", "status_immune", "deck", "ai", "phases", "first_win", "season_win", "unlock_after", "open_hand",
	"lines"]
const STATUS_DISPLAY_KEYS: PackedStringArray = ["name", "text", "color", "icon"]
const STATUS_MECH_KEYS: PackedStringArray = ["id", "kind", "default_turns", "stat_mult", "tick_timing", "tick_pct",
	"tick_min", "tick_speed_mult", "flags", "excludes", "element"]
const DURCHSAGE_KEYS: PackedStringArray = ["id", "name", "short", "text", "icon", "action", "ctr_after", "warn_at",
	"warn_tag"]
const LESSON_MOVES: PackedStringArray = ["", "play", "file"]
const VOICES: PackedStringArray = ["mod", "mopsula", "chat", "opp"]
const PLACEHOLDERS: PackedStringArray = ["opp", "ticket", "card", "count", "name"]
const COSMETIC_KINDS: PackedStringArray = ["back", "ink", "mat", "title"]
const MAX_TEXT: int = 110
const MAX_SHORT: int = 7
const MAX_CARD_NAME: int = 24
const MAX_SEASON_FOLLOWERS: int = 50         # 10 §5.3: at most 50 followers per season from the duel
## Tags the code and the presentation (SD2-C…F) rely on: one line at least each (10 §4.5). Opponent tags
## (sd_opp_intro:/sd_opp_win:/sd_opp_lose:/sd_akte:<lines>), the phase `say` tags, the Durchsage warn tag, the
## lesson lines and the hint tags of SdAi are required on top.
const REQUIRED_TAGS: PackedStringArray = ["sd_explain", "sd_intro", "sd_first_card", "sd_turn_player", "sd_turn_opp",
	"sd_wiedervorlage", "sd_abgeprallt", "sd_weak", "sd_resist", "sd_chain", "sd_show_success", "sd_show_fail",
	"sd_durchsage", "sd_reshuffle", "sd_dienstschluss_warn", "sd_win", "sd_loss", "sd_dienstschluss", "sd_forfeit",
	"sd_tie", "sd_hall", "sd_heft", "sd_new_card", "sd_season_win", "sd_album", "sd_chat_show", "sd_chat_chain",
	"sd_chat_win", "sd_chat_loss", "sd_chat_handle", "sd_mopsula_turn"]
const OPPONENT_TAG_PREFIXES: PackedStringArray = ["sd_opp_intro:", "sd_opp_win:", "sd_opp_lose:", "sd_akte:"]
## Dienstauszeichnungen the collection awards (10 §5.2, SdCollection.AWARD_*).
const REQUIRED_AWARDS: PackedStringArray = ["sda_tutorial", "sda_first_win", "sda_chain", "sda_no_file", "sda_close",
	"sda_show_5", "sda_termin", "sda_durchsage", "sda_amt", "sda_graf"]
## Own word list (10 §3.9; lower case): no DCC terms, no real authorities or institutions, no famous bureaucracy
## quotes. Substrings for the long words, whole words for the short ones (no alarm for "gezogen").
const WORDS: PackedStringArray = ["crawler", "donut", "passierschein", "asterix", "obelix", "finanzamt", "jobcenter",
	"arbeitsagentur", "bundesagentur", "krankenkasse", "bürgeramt", "einwohnermeldeamt", "ordnungsamt",
	"zulassungsstelle", "rundfunkbeitrag", "bundesamt", "landratsamt", "standesamt", "sozialamt", "jugendamt",
	"gesundheitsamt", "ausländerbehörde", "rentenversicherung", "finanzbehörde"]
const WHOLE_WORDS: PackedStringArray = ["carl", "gez", "tüv", "aok", "a38", "dcc", "mordecai", "borant", "schufa"]
## The Count speaks for himself (06 §0.3, test_06_ip_words): no capitalized royal "Wir"/"Uns"/"Unser…".
const ROYAL_PLURAL: String = "\\b(Wir|Uns|Unser[a-z]*)\\b"
## Characters the default font lacks (03_ART F8; tests check every text against the font itself).
const BAD_GLYPHS: String = "→←↑↓●★♥▼▲☰✓✔✗✘⌫"

var errors: PackedStringArray = []
var warnings: PackedStringArray = []

var _cards: Dictionary = {}                 # id → raw entry
var _opponents: Dictionary = {}
var _statuses: Dictionary = {}
var _tags: Dictionary = {}                  # tag → line count
var _cosmetics: Dictionary = {}
var _awards: Dictionary = {}
var _constants: Dictionary = {}
var _words_re: RegEx = null
var _royal_re: RegEx = null


## Checks the parsed files (file name → parsed JSON or null). `campaign` (optional): the campaign data whose skill,
## item and talent ids may unlock cards.
func check(files: Dictionary, campaign: GameData = null) -> void:
	errors.clear()
	warnings.clear()
	_words_re = RegEx.create_from_string("(?i)\\b(%s)\\b" % "|".join(WHOLE_WORDS))
	_royal_re = RegEx.create_from_string(ROYAL_PLURAL)
	for f: String in FILES:
		if not files.get(f, null) is Dictionary:
			_err(f, "file missing or not a JSON object")
			continue
		var d: Dictionary = files[f]
		if not d.has("schema") or not JsonUtil.is_integral(d["schema"]) or int(d["schema"]) != 1:
			_err(f + ".schema", "must be 1")
		if ENTRY_FILES.has(f):
			for k: Variant in d.keys():
				if str(k) != "schema" and str(k) != "entries":
					_err("%s.%s" % [f, str(k)], "unknown top-level key")
			if not d.get("entries", null) is Array:
				_err(f + ".entries", "missing or not an array")
	if not errors.is_empty():
		return
	var rules: Dictionary = files["rules"]
	_index_lines(files["lines"]["entries"])
	_index(files["cosmetics"]["entries"], "cosmetics", "^sdk_[a-z0-9_]+$", _cosmetics)
	_index(files["awards"]["entries"], "awards", "^sda_[a-z0-9_]+$", _awards)
	_check_constants(rules)
	_check_statuses(rules)
	_index(files["cards"]["entries"], "cards", "^sdc_[a-z0-9_]+$", _cards)
	_index(files["opponents"]["entries"], "opponents", "^sdo_[a-z0-9_]+$", _opponents)
	for k: Variant in rules.keys():
		if not RULES_KEYS.has(str(k)):
			_err("rules." + str(k), "unknown top-level key")
	_check_cards(campaign)
	_check_opponents()
	_check_rules(rules)
	_check_lines(files["lines"]["entries"])
	_check_cosmetics_awards()
	_check_required_tags(rules)


# --- indexes ------------------------------------------------------------------------------------------------------

func _index(list: Array, file: String, pattern: String, out: Dictionary) -> void:
	var re: RegEx = RegEx.create_from_string(pattern)
	for i in list.size():
		if not list[i] is Dictionary:
			_err("%s[%d]" % [file, i], "entry must be an object")
			continue
		var e: Dictionary = list[i]
		var id: String = str(e.get("id", ""))
		if re.search(id) == null:
			_err("%s[%d].id" % [file, i], "invalid id '%s' (pattern %s)" % [id, pattern])
			continue
		if out.has(id):
			_err("%s[%d].id" % [file, i], "duplicate id '%s'" % id)
			continue
		out[id] = e


func _index_lines(list: Array) -> void:
	for e: Variant in list:
		if e is Dictionary:
			var tag: String = str((e as Dictionary).get("tag", ""))
			_tags[tag] = int(_tags.get(tag, 0)) + 1


# --- rules.json ---------------------------------------------------------------------------------------------------

func _check_constants(rules: Dictionary) -> void:
	var c: Variant = rules.get("constants", null)
	if not c is Dictionary:
		_err("rules.constants", "missing or not an object")
		return
	for k: Variant in (c as Dictionary).keys():
		if not CONSTANT_RANGES.has(str(k)):
			_err("rules.constants." + str(k), "unknown constant")
	for k: String in CONSTANT_RANGES:
		var v: Variant = (c as Dictionary).get(k, null)
		var r: Array = CONSTANT_RANGES[k]
		if not JsonUtil.is_integral(v) or int(v) < int(r[0]) or int(v) > int(r[1]):
			_err("rules.constants." + k, "integer %d..%d required (got %s)" % [int(r[0]), int(r[1]), str(v)])
			continue
		_constants[k] = int(v)
	if _constants.size() == CONSTANT_RANGES.size():
		if _c("hand_size") >= _c("deck_size"):
			_err("rules.constants.hand_size", "must be below deck_size")
		if _c("max_copies_show") > _c("max_copies"):
			_err("rules.constants.max_copies_show", "must not exceed max_copies")
		if _c("dienstschluss_warn") >= _c("dienstschluss"):
			_err("rules.constants.dienstschluss_warn", "must be below dienstschluss")


func _c(key: String) -> int:
	return int(_constants.get(key, 0))


func _check_statuses(rules: Dictionary) -> void:
	var list: Variant = rules.get("statuses", null)
	if not list is Array:
		_err("rules.statuses", "missing or not an array")
		return
	_index(list, "rules.statuses", "^sts_sd_[a-z0-9_]+$", _statuses)
	for sid: String in _statuses:
		var s: Dictionary = _statuses[sid]
		var ctx: String = "rules.statuses[%s]" % sid
		for k: Variant in s.keys():
			if not STATUS_MECH_KEYS.has(str(k)) and not STATUS_DISPLAY_KEYS.has(str(k)):
				_err("%s.%s" % [ctx, str(k)], "unknown key")
		for k: String in STATUS_DISPLAY_KEYS:
			if str(s.get(k, "")) == "":
				_err("%s.%s" % [ctx, k], "required")
		_texts(ctx, s, ["name", "text"], false)
		for ex: String in JsonUtil.to_str_array(s.get("excludes", [])):
			if not _statuses.has(ex):
				_err(ctx + ".excludes", "unknown status '%s'" % ex)


func _check_rules(rules: Dictionary) -> void:
	_check_durchsage(rules.get("durchsage", null))
	var grund: PackedStringArray = _id_list("rules.grundakte", rules.get("grundakte", null), _cards, "card")
	var start: Variant = rules.get("startmappe", null)
	if not start is Dictionary:
		_err("rules.startmappe", "missing or not an object {card: copies}")
	else:
		var list: PackedStringArray = _expand(start as Dictionary)
		_check_deck("rules.startmappe", list, true)
		for cid: String in list:
			if not grund.has(cid):
				_err("rules.startmappe", "'%s' is not part of the Grundakte" % cid)
	var known: Dictionary = _cards.duplicate()
	known.merge(_cosmetics)
	var heft: PackedStringArray = _id_list("rules.heft", rules.get("heft", null), known, "card or cosmetic")
	var rewards: Variant = rules.get("rewards", null)
	if not rewards is Dictionary:
		_err("rules.rewards", "missing or not an object")
	else:
		for k: String in ["tutorial", "album"]:
			var r: Variant = (rewards as Dictionary).get(k, null)
			if not r is Dictionary:
				_err("rules.rewards." + k, "missing or not an object")
				continue
			_id_list("rules.rewards.%s.cosmetics" % k, (r as Dictionary).get("cosmetics", []), _cosmetics, "cosmetic")
	var af: Variant = rules.get("autofill", null)
	if not af is Dictionary:
		_err("rules.autofill", "missing or not an object")
	else:
		for k: String in ["max_per_art", "min_heal"]:
			var v: Variant = (af as Dictionary).get(k, null)
			if not JsonUtil.is_integral(v) or int(v) < 0 or int(v) > _c("deck_size"):
				_err("rules.autofill." + k, "integer 0..deck_size required")
	_check_tutorial(rules.get("tutorial", null))
	# 10 §2.5: every card comes without the campaign too — Grundakte, a first victory or the Stempelheft.
	var reachable: Dictionary = {}
	for cid: String in grund:
		reachable[cid] = true
	for cid: String in heft:
		reachable[cid] = true
	for oid: String in _opponents:
		var fw: Variant = (_opponents[oid] as Dictionary).get("first_win", {})
		for cid: String in JsonUtil.to_str_array((fw as Dictionary).get("cards", []) if fw is Dictionary else []):
			reachable[cid] = true
	for cid: String in _cards:
		if not reachable.has(cid):
			_err("cards[%s]" % cid, "unreachable without the campaign (not in Grundakte, a first win or the heft)")


func _check_durchsage(d: Variant) -> void:
	if not d is Dictionary:
		_err("rules.durchsage", "missing or not an object")
		return
	var ds: Dictionary = d
	for k: Variant in ds.keys():
		if not DURCHSAGE_KEYS.has(str(k)):
			_err("rules.durchsage." + str(k), "unknown key")
	if not RegEx.create_from_string("^pu_sd_[a-z0-9_]+$").search(str(ds.get("id", ""))):
		_err("rules.durchsage.id", "must match ^pu_sd_[a-z0-9_]+$")
	_texts("rules.durchsage", ds, ["name", "text"], false)
	var short: String = str(ds.get("short", ""))
	if short == "" or short != short.to_upper():
		_err("rules.durchsage.short", "upper-case display word required")
	var tag: String = str(ds.get("warn_tag", ""))
	if tag == "" or not _tags.has(tag):
		_err("rules.durchsage.warn_tag", "needs a line in lines.json ('%s')" % tag)


func _check_tutorial(t: Variant) -> void:
	if not t is Dictionary:
		_err("rules.tutorial", "missing or not an object")
		return
	var tut: Dictionary = t
	var opp: String = str(tut.get("opponent", ""))
	if not _opponents.has(opp):
		_err("rules.tutorial.opponent", "unknown opponent '%s'" % opp)
	var g: Variant = tut.get("geduld", null)
	if not JsonUtil.is_integral(g) or int(g) < 1 or int(g) > 999:
		_err("rules.tutorial.geduld", "integer 1..999 required")
	var player: PackedStringArray = JsonUtil.to_str_array(tut.get("player_deck", []))
	var oppdeck: PackedStringArray = JsonUtil.to_str_array(tut.get("opponent_deck", []))
	_check_deck("rules.tutorial.player_deck", player, true)
	_check_deck("rules.tutorial.opponent_deck", oppdeck, false)
	var ai: Variant = tut.get("ai", null)
	if not ai is Dictionary or str((ai as Dictionary).get("type", "")) != "weighted":
		_err("rules.tutorial.ai", "a weighted AI table required (the script, 10 §1.10)")
	else:
		_check_ai_cards("rules.tutorial.ai.actions", (ai as Dictionary).get("actions", []), oppdeck)
	var lessons: Variant = tut.get("lessons", null)
	if not lessons is Array or (lessons as Array).is_empty():
		_err("rules.tutorial.lessons", "missing or empty")
		return
	var last_ticket: int = 1
	for i in (lessons as Array).size():
		var ctx: String = "rules.tutorial.lessons[%d]" % i
		var l: Variant = (lessons as Array)[i]
		if not l is Dictionary:
			_err(ctx, "must be an object")
			continue
		var ld: Dictionary = l
		if JsonUtil.to_int(ld.get("step", 0)) != i + 1:
			_err(ctx + ".step", "steps count 1, 2, 3 … (got %s)" % str(ld.get("step", "")))
		var ticket: int = JsonUtil.to_int(ld.get("ticket", 0))
		if ticket < last_ticket:
			_err(ctx + ".ticket", "tickets must not go back (%d after %d)" % [ticket, last_ticket])
		last_ticket = maxi(last_ticket, ticket)
		var move: String = str(ld.get("move", ""))
		if not LESSON_MOVES.has(move):
			_err(ctx + ".move", "'%s' not in %s" % [move, ", ".join(LESSON_MOVES)])
		var card: String = str(ld.get("card", ""))
		if move == "play" and not player.has(card):
			_err(ctx + ".card", "the forced card '%s' is not in the Lernduell deck" % card)
		if move != "play" and card != "":
			_err(ctx + ".card", "only a play lesson names a card")
		for key: String in ["line", "note"]:
			var tag: String = str(ld.get(key, ""))
			if (key == "line" or tag != "") and not _tags.has(tag):
				_err("%s.%s" % [ctx, key], "needs a line in lines.json ('%s')" % tag)


# --- cards --------------------------------------------------------------------------------------------------------

func _check_cards(campaign: GameData) -> void:
	var src_re: RegEx = RegEx.create_from_string("^(skl|itm|tal)_[a-z0-9_]+$")
	for cid: String in _cards:
		var c: Dictionary = _cards[cid]
		var ctx: String = "cards[%s]" % cid
		for k: Variant in c.keys():
			if not CARD_KEYS.has(str(k)):
				_err("%s.%s" % [ctx, str(k)], "unknown key")
		_texts(ctx, c, ["name", "text", "quip"], _is_graf_card(c))
		if str(c.get("name", "")).length() > MAX_CARD_NAME:
			_err(ctx + ".name", "longer than %d characters" % MAX_CARD_NAME)
		var art: String = str(c.get("art", ""))
		if not SdCardDef.ARTS.has(art):
			_err(ctx + ".art", "'%s' not in %s" % [art, ", ".join(SdCardDef.ARTS)])
		var origin: String = str(c.get("origin", ""))
		if not SdCardDef.ORIGINS.has(origin):
			_err(ctx + ".origin", "'%s' not in %s" % [origin, ", ".join(SdCardDef.ORIGINS)])
		var owner: String = str(c.get("owner", ""))
		if (origin == "talent") != (owner == "kandidat" or owner == "graf"):
			_err(ctx + ".owner", "talent cards name their owner (kandidat/graf), other cards none")
		var show: bool = bool(c.get("show", false))
		var copies: Variant = c.get("max_copies", null)
		var cap: int = _c("max_copies_show") if show else _c("max_copies")
		if not JsonUtil.is_integral(copies) or int(copies) < 1 or int(copies) > cap:
			_err(ctx + ".max_copies", "integer 1..%d required" % cap)
		if not RegEx.create_from_string("^[0-9]{3}$").search(str(c.get("form", ""))):
			_err(ctx + ".form", "three digits required (decorative form number)")
		if not SdCardDef.HAND_EFFECTS.has(str(c.get("hand", ""))):
			_err(ctx + ".hand", "'%s' not in [\"\", \"refresh\"]" % str(c.get("hand", "")))
		for src: String in JsonUtil.to_str_array(c.get("campaign", [])):
			if src_re.search(src) == null:
				_err(ctx + ".campaign", "'%s' is no skill, item or talent id" % src)
			elif campaign != null and not campaign.has_id(_campaign_table(src), src):
				_err(ctx + ".campaign", "unknown campaign id '%s'" % src)
		_check_skill(ctx, c, art, show)


func _check_skill(ctx: String, c: Dictionary, art: String, show: bool) -> void:
	var sk_v: Variant = c.get("skill", null)
	if not sk_v is Dictionary:
		_err(ctx + ".skill", "missing or not an object")
		return
	var sk: Dictionary = sk_v
	var sctx: String = ctx + ".skill"
	for k: Variant in sk.keys():
		if not SKILL_KEYS.has(str(k)):
			_err("%s.%s" % [sctx, str(k)], "not a mechanical skill field of the duel")
	var cat: String = str(sk.get("category", ""))
	if not CATEGORIES.has(cat):
		_err(sctx + ".category", "'%s' not in %s" % [cat, ", ".join(CATEGORIES)])
	if (cat == "stunt") != show:
		_err(sctx + ".category", "show cards are stunts and only show cards are")
	if not sk.has("rank") or not JsonUtil.is_integral(sk["rank"]) or int(sk["rank"]) < 1 or int(sk["rank"]) > 6:
		_err(sctx + ".rank", "Bearbeitungszeit 1..6 Werktage required")
	var element: String = str(sk.get("element", "none"))
	var art_element: String = str(SdCardDef.ART_ELEMENTS.get(art, element))
	if element != art_element:
		_err(sctx + ".element", "the Formular-Art %s is element %s (got %s)" % [art, art_element, element])
	var dt: String = str(sk.get("damage_type", "none"))
	var target: String = str(sk.get("target", ""))
	match dt:
		"fixed":
			if target != "single_enemy":
				_err(sctx + ".target", "Ärger always hits the other side (single_enemy)")
			if JsonUtil.to_int(sk.get("power", 0)) < 1:
				_err(sctx + ".power", "Ärger needs power >= 1")
		"heal":
			if target != "single_ally" or str(sk.get("heal_mode", "")) != "fixed":
				_err(sctx, "heals are fixed (heal_mode fixed) and land on the player (single_ally)")
		"none":
			if not ["single_enemy", "self"].has(target):
				_err(sctx + ".target", "single_enemy or self required")
		_:
			_err(sctx + ".damage_type", "fixed, heal or none (no dice in Ärger, 10 SD-8)")
	var sts: Variant = sk.get("statuses", [])
	for s: Variant in (sts as Array if sts is Array else []):
		var sid: String = str((s as Dictionary).get("id", "")) if s is Dictionary else ""
		if not _statuses.has(sid):
			_err(sctx + ".statuses", "unknown status '%s'" % sid)
		elif float((s as Dictionary).get("chance", 1.0)) != 1.0:
			_err(sctx + ".statuses", "every status works at 100 %% (10 §1.6), '%s' has a chance" % sid)
	for sid: String in JsonUtil.to_str_array(sk.get("cleanse", [])):
		if not _statuses.has(sid):
			_err(sctx + ".cleanse", "unknown status '%s'" % sid)
	if show:
		if not sk.has("cooldown") or JsonUtil.to_int(sk["cooldown"], -1) != 0:
			_err(sctx + ".cooldown", "show cards set cooldown 0 explicitly (10 §2.7)")
		if float(sk.get("success_lck", 0.01)) != 0.0:
			_err(sctx + ".success_lck", "must be 0 (the duel has no luck values)")
		var base: float = float(sk.get("success_base", 0.0))
		if base < 0.05 or base > float(sk.get("success_cap", 0.85)):
			_err(sctx + ".success_base", "0.05..success_cap required (the printed chance)")
		if not sk.get("fail_effect", null) is Dictionary or (sk["fail_effect"] as Dictionary).is_empty():
			_err(sctx + ".fail_effect", "a show card prints its Patzer")
		else:
			var fs: String = str((sk["fail_effect"] as Dictionary).get("status", ""))
			if fs != "" and not _statuses.has(fs):
				_err(sctx + ".fail_effect.status", "unknown status '%s'" % fs)
	else:
		for k: String in SHOW_KEYS:
			if sk.has(k):
				_err("%s.%s" % [sctx, k], "only show cards have a chance, a Patzer or a cooldown")


static func _campaign_table(src: String) -> String:
	if src.begins_with("skl_"):
		return "skills"
	if src.begins_with("itm_"):
		return "items"
	return "talents"


static func _is_graf_card(c: Dictionary) -> bool:
	return str(c.get("origin", "")) == "graf" or str(c.get("owner", "")) == "graf"


# --- opponents ----------------------------------------------------------------------------------------------------

func _check_opponents() -> void:
	var followers: int = 0
	var roots: int = 0
	for oid: String in _opponents:
		var o: Dictionary = _opponents[oid]
		var ctx: String = "opponents[%s]" % oid
		for k: Variant in o.keys():
			if not OPPONENT_KEYS.has(str(k)):
				_err("%s.%s" % [ctx, str(k)], "unknown key (no engine boss flag: SD-14)")
		_texts(ctx, o, ["name", "role", "akte", "rule"], oid == "sdo_graf")
		var short: String = str(o.get("short", ""))
		if short == "" or short.length() > MAX_SHORT or short != short.to_upper():
			_err(ctx + ".short", "1..%d upper-case characters for the ticket display (got '%s')" % [MAX_SHORT, short])
		var g: Variant = o.get("geduld", null)
		if not JsonUtil.is_integral(g) or int(g) < 1 or int(g) > 999:
			_err(ctx + ".geduld", "integer 1..999 required")
		var mods: Variant = o.get("element_mods", {})
		for k: Variant in ((mods as Dictionary).keys() if mods is Dictionary else []):
			var f: float = float((mods as Dictionary)[k])
			if not SdCardDef.ART_ELEMENTS.values().has(str(k)) or str(k) == "none":
				_err("%s.element_mods.%s" % [ctx, str(k)], "unknown Formular-Art element")
			elif f != 1.5 and f != 0.5:
				_err("%s.element_mods.%s" % [ctx, str(k)], "Wunder Punkt 1.5 or Nicht zuständig 0.5 (got %s)" % str(f))
		for sid: String in JsonUtil.to_str_array(o.get("status_immune", [])):
			if not _statuses.has(sid):
				_err(ctx + ".status_immune", "unknown status '%s'" % sid)
		var deck: PackedStringArray = []
		if not o.get("deck", null) is Dictionary:
			_err(ctx + ".deck", "missing or not an object {card: copies}")
		else:
			deck = _expand(o["deck"] as Dictionary)
			_check_deck(ctx + ".deck", deck, false)
		var ai: Variant = o.get("ai", null)
		var phases: Variant = o.get("phases", [])
		if not ai is Dictionary:
			_err(ctx + ".ai", "missing or not an object")
		elif str((ai as Dictionary).get("type", "weighted")) == "phased":
			if not phases is Array or (phases as Array).is_empty():
				_err(ctx + ".phases", "a phased opponent needs phases")
			else:
				for i in (phases as Array).size():
					var p: Variant = (phases as Array)[i]
					if not p is Dictionary:
						continue
					_check_ai_cards("%s.phases[%d].actions" % [ctx, i], (p as Dictionary).get("actions", []), deck)
					for op: Variant in (p as Dictionary).get("on_enter", []):
						_check_phase_op("%s.phases[%d].on_enter" % [ctx, i], op)
		else:
			_check_ai_cards(ctx + ".ai.actions", (ai as Dictionary).get("actions", []), deck)
		var fw: Variant = o.get("first_win", {})
		if not fw is Dictionary:
			_err(ctx + ".first_win", "not an object")
		else:
			_id_list(ctx + ".first_win.cards", (fw as Dictionary).get("cards", []), _cards, "card")
			_id_list(ctx + ".first_win.cosmetics", (fw as Dictionary).get("cosmetics", []), _cosmetics, "cosmetic")
		var sw: Variant = o.get("season_win", {})
		var fol: int = JsonUtil.to_int((sw as Dictionary).get("followers", 0)) if sw is Dictionary else -1
		if fol < 0:
			_err(ctx + ".season_win.followers", "must be >= 0")
		followers += maxi(0, fol)
		var after: String = str(o.get("unlock_after", ""))
		if after == "":
			roots += 1
		elif not _opponents.has(after) or after == oid:
			_err(ctx + ".unlock_after", "unknown opponent '%s'" % after)
		var lines_key: String = str(o.get("lines", ""))
		if lines_key == "":
			_err(ctx + ".lines", "required (tag suffix of the opponent's lines)")
		for prefix: String in OPPONENT_TAG_PREFIXES:
			if lines_key != "" and not _tags.has(prefix + lines_key):
				_err(ctx + ".lines", "needs a line tagged %s%s" % [prefix, lines_key])
	if followers > MAX_SEASON_FOLLOWERS:
		_err("opponents", "season rewards add up to %d followers (at most %d, 10 §5.3)" % [followers,
			MAX_SEASON_FOLLOWERS])
	if not _opponents.is_empty() and roots == 0:
		_err("opponents", "no opponent is open after the Lernduell (unlock_after \"\")")
	_check_unlock_cycles()


func _check_unlock_cycles() -> void:
	for oid: String in _opponents:
		var seen: Dictionary = {}
		var cur: String = oid
		while cur != "" and _opponents.has(cur):
			if seen.has(cur):
				_err("opponents[%s].unlock_after" % oid, "unlock chain loops")
				break
			seen[cur] = true
			cur = str((_opponents[cur] as Dictionary).get("unlock_after", ""))


func _check_phase_op(ctx: String, op: Variant) -> void:
	if not op is Dictionary:
		return
	var o: Dictionary = op
	match str(o.get("op", "")):
		"say":
			if not _tags.has(str(o.get("tag", ""))):
				_err(ctx, "say '%s' needs a line in lines.json" % str(o.get("tag", "")))
		"status_self":
			if not _statuses.has(str(o.get("status", ""))):
				_err(ctx, "unknown status '%s'" % str(o.get("status", "")))
		"add_pseudo", "remove_pseudo":
			pass                                        # the engine checks the unit id (load_from_dicts)
		_:
			_err(ctx, "op '%s' is not used by the duel (say, status_self, add_pseudo, remove_pseudo)" % str(o.get("op", "")))


## Every AI entry names a card of the deck, every card of the deck has an entry (else the opponent never plays it and
## files all the time, 10 §2.7).
func _check_ai_cards(ctx: String, actions: Variant, deck: PackedStringArray) -> void:
	if not actions is Array:
		_err(ctx, "not an array")
		return
	var covered: Dictionary = {}
	for i in (actions as Array).size():
		var a: Variant = (actions as Array)[i]
		var sid: String = str((a as Dictionary).get("skill", "")) if a is Dictionary else ""
		var cid: String = sid.trim_prefix("skl_")
		if not sid.begins_with("skl_sdc_") or not deck.has(cid):
			_err("%s[%d].skill" % [ctx, i], "'%s' is no card of this deck" % sid)
			continue
		covered[cid] = true
	for cid: String in deck:
		if not covered.has(cid):
			_err(ctx, "the deck card '%s' has no AI entry" % cid)
			covered[cid] = true


## Deck rules (10 §2.1): deck_size cards, at most max_copies of a kind (show cards max_copies_show and only for the
## player), every card known.
func _check_deck(ctx: String, deck: PackedStringArray, player: bool) -> void:
	if deck.size() != _c("deck_size"):
		_err(ctx, "%d cards (exactly %d required)" % [deck.size(), _c("deck_size")])
	var counts: Dictionary = {}
	for cid: String in deck:
		counts[cid] = int(counts.get(cid, 0)) + 1
	for cid: String in counts:
		if not _cards.has(cid):
			_err(ctx, "unknown card '%s'" % cid)
			continue
		var c: Dictionary = _cards[cid]
		var show: bool = bool(c.get("show", false))
		if show and not player:
			_err(ctx, "'%s' is a show card (the office has no sense for show, 10 §1.7)" % cid)
		var cap: int = mini(_c("max_copies_show") if show else _c("max_copies"), JsonUtil.to_int(c.get("max_copies", 2)))
		if int(counts[cid]) > cap:
			_err(ctx, "%d × '%s' (at most %d)" % [int(counts[cid]), cid, cap])


static func _expand(deck: Dictionary) -> PackedStringArray:
	var ids: PackedStringArray = []
	for k: Variant in deck.keys():
		ids.append(str(k))
	ids.sort()
	var out: PackedStringArray = []
	for cid: String in ids:
		var n: Variant = deck[cid]
		for _i in (maxi(0, int(n)) if JsonUtil.is_integral(n) else 0):
			out.append(cid)
	return out


func _id_list(ctx: String, v: Variant, known: Dictionary, what: String) -> PackedStringArray:
	if not v is Array:
		_err(ctx, "missing or not an array")
		return PackedStringArray()
	var out: PackedStringArray = JsonUtil.to_str_array(v)
	var seen: Dictionary = {}
	for id: String in out:
		if not known.has(id):
			_err(ctx, "unknown %s '%s'" % [what, id])
		if seen.has(id):
			_err(ctx, "'%s' listed twice" % id)
		seen[id] = true
	return out


# --- lines, cosmetics, awards -------------------------------------------------------------------------------------

func _check_lines(list: Array) -> void:
	var tag_re: RegEx = RegEx.create_from_string("^sd_[a-z0-9_]+(:[a-z0-9_]+)*$")
	var counts: Dictionary = {}
	var ids: Dictionary = {}
	for i in list.size():
		var ctx: String = "lines[%d]" % i
		if not list[i] is Dictionary:
			_err(ctx, "entry must be an object")
			continue
		var l: Dictionary = list[i]
		for k: Variant in l.keys():
			if not ["id", "tag", "voice", "text"].has(str(k)):
				_err("%s.%s" % [ctx, str(k)], "unknown key")
		var tag: String = str(l.get("tag", ""))
		if tag_re.search(tag) == null:
			_err(ctx + ".tag", "invalid tag '%s' (sd_…)" % tag)
		counts[tag] = int(counts.get(tag, 0)) + 1
		var expected: String = "sdl_%s_%02d" % [tag.trim_prefix("sd_").replace(":", "_"), int(counts[tag])]
		var id: String = str(l.get("id", ""))
		if id != expected:
			_err(ctx + ".id", "'%s' should be '%s' (sdl_<tag>_<nn>)" % [id, expected])
		if ids.has(id):
			_err(ctx + ".id", "duplicate id '%s'" % id)
		ids[id] = true
		var voice: String = str(l.get("voice", ""))
		if not VOICES.has(voice):
			_err(ctx + ".voice", "'%s' not in %s" % [voice, ", ".join(VOICES)])
		_texts(ctx, l, ["text"], voice == "mopsula")
		for ph: String in DataValidator.placeholders_in(str(l.get("text", ""))):
			if not PLACEHOLDERS.has(ph):
				_err(ctx + ".text", "unknown placeholder {%s}" % ph)


func _check_cosmetics_awards() -> void:
	for cid: String in _cosmetics:
		var c: Dictionary = _cosmetics[cid]
		if not COSMETIC_KINDS.has(str(c.get("kind", ""))):
			_err("cosmetics[%s].kind" % cid, "'%s' not in %s" % [str(c.get("kind", "")), ", ".join(COSMETIC_KINDS)])
		_texts("cosmetics[%s]" % cid, c, ["name", "desc"], false)
	for aid: String in _awards:
		_texts("awards[%s]" % aid, _awards[aid], ["name", "desc"], false)
	for aid: String in REQUIRED_AWARDS:
		if not _awards.has(aid):
			_err("awards", "missing award '%s' (10 §5.2)" % aid)


func _check_required_tags(rules: Dictionary) -> void:
	for tag: String in REQUIRED_TAGS:
		if not _tags.has(tag):
			_err("lines", "no line for the required tag '%s'" % tag)
	for reason: String in SdAi.HINTS:
		if not _tags.has("sd_hint:" + reason):
			_err("lines", "no line for the hint tag 'sd_hint:%s' (SdAi)" % reason)
	if rules.get("tutorial", null) is Dictionary and not _tags.has("sd_tut:1"):
		_err("lines", "the Lernduell has no lines")


# --- texts --------------------------------------------------------------------------------------------------------

## Text rules for the fields `keys` of `d` (all required, non-empty): length, IP / tone words, glyphs; `graf` texts
## (Graf Mopsula's voice) also without the royal plural.
func _texts(ctx: String, d: Dictionary, keys: Array, graf: bool) -> void:
	for k: Variant in keys:
		var key: String = str(k)
		var text: String = str(d.get(key, ""))
		var tctx: String = "%s.%s" % [ctx, key]
		if text.strip_edges() == "" or text != text.strip_edges():
			_err(tctx, "required, without surrounding whitespace")
			continue
		if text.length() > MAX_TEXT:
			_err(tctx, "longer than %d characters (%d)" % [MAX_TEXT, text.length()])
		var bad: String = text_problem(text, graf)
		if bad != "":
			_err(tctx, bad)


## First problem of a player-facing text ("" = fine): IP / tone words of ip_words.gd, the own list, royalty motifs,
## the royal plural in the Count's voice (`graf`), font-less glyphs.
func text_problem(text: String, graf: bool) -> String:
	var w: String = IpWords.general_word(text)
	if w != "":
		return "contains '%s' (IP distance / tone, 04 §2.3, 06 §0.3)" % w
	w = IpWords.mopsula_word(text)
	if w != "":
		return "contains '%s' (no royalty motif in the Stempelduell, 10 §3.9)" % w
	var low: String = text.to_lower()
	for word: String in WORDS:
		if low.contains(word):
			return "contains '%s' (no DCC terms, real authorities or famous quotes, 10 §3.9)" % word
	var m: RegExMatch = _words_re.search(text) if _words_re != null else null
	if m != null:
		return "names '%s' (no DCC terms, real authorities or famous quotes, 10 §3.9)" % m.get_string(1)
	if graf and _royal_re != null and _royal_re.search(text) != null:
		return "royal plural in Graf Mopsula's voice (he speaks for himself)"
	for i in BAD_GLYPHS.length():
		if text.contains(BAD_GLYPHS[i]):
			return "uses the glyph '%s' the font lacks (03_ART F8)" % BAD_GLYPHS[i]
	for i in text.length():
		if text.unicode_at(i) >= 0x1F000:
			return "uses an emoji (03_ART F8: symbols are drawn)"
	return ""


func _err(ctx: String, msg: String) -> void:
	errors.append("%s: %s" % [ctx, msg])
