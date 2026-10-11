class_name ModLineFilter extends RefCounted
## Post-filter for live (AI-generated) M.O.D. lines (06 §5.9 Nr. 3, package D). The game runs it in
## Show.say_external, services/mod-brain runs the same rules (safety.py) on every line before it leaves the server —
## tests/fixtures/live/line_filter_cases.json is checked by both sides. Scripted lines (mod_lines.json) are reviewed by
## people and never pass through here. Pure and static; the word lists live in res://data/mod_filter.json.
##
## check(text) → "" (ok) or the first failing rule, in this order:
##   empty · too_long (> max_len characters) · placeholder (any {…} other than {name}, stray braces) · url (http, www.,
##   ://, name.tld) · digits (6+ digits in a row, also with spaces / . / - / between them: phone numbers)
##   · blocked_<category> (politics, sexual, slurs, violence, real_brands — single-word hits, "*" = prefix; hyphenated
##   words are checked whole and per part) · money (€ or a money word: real money, donations, subscriptions are never
##   mentioned, L13/L16) · purchase_pressure (an urgency word/phrase TOGETHER with a purchase word: "Schnell,
##   Sponsor-Fenster!" fails, "Schnellschnitt!" and "nur noch zwei Räume" pass) · language (not German: English stop
##   words that are no German ones > en_max_pm ‰ of the words in lines of lang_min_words+ words, or German stop words
##   < de_min_pm ‰ in lines of lang_de_min_words+ words — tuned so that < 1 % of the written lines trip it).
## Words: lower case, runs of [a-zäöüß] joined by single hyphens; {name} is not a word.

const PATH: String = "res://data/mod_filter.json"
const VOICES: PackedStringArray = ["mod", "mopsula", "chat"]
const BLOCKED_ORDER: PackedStringArray = ["politics", "sexual", "slurs", "violence", "real_brands"]

static var _words: Dictionary = {}
static var _re_word: RegEx = null
static var _re_brace: RegEx = null
static var _re_url: RegEx = null
static var _re_digits: RegEx = null


## The word lists (cached after the first read; {} when the file is missing → only the structural rules run).
static func words() -> Dictionary:
	if _words.is_empty():
		var parsed: Variant = JsonUtil.read_file(PATH)
		_words = parsed if parsed is Dictionary else {"max_len": 110}
	return _words


## "" = the line may be shown; else the rule it failed (see class doc). `lists` overrides words() (tests).
static func check(text: String, lists: Dictionary = {}) -> String:
	var w: Dictionary = lists if not lists.is_empty() else words()
	_compile()
	var t: String = text.strip_edges()
	if t == "":
		return "empty"
	if t.length() > int(w.get("max_len", 110)):
		return "too_long"
	for m: RegExMatch in _re_brace.search_all(t):
		if m.get_string(0) != "{name}":
			return "placeholder"
	if _re_brace.sub(t, "", true).contains("{") or _re_brace.sub(t, "", true).contains("}"):
		return "placeholder"
	var low: String = t.to_lower()
	if low.contains("http") or low.contains("www.") or low.contains("://") or _re_url.search(low) != null:
		return "url"
	if _re_digits.search(low) != null:
		return "digits"
	var tokens: PackedStringArray = tokenize(low.replace("{name}", " "))
	var parts: PackedStringArray = tokens.duplicate()
	for tok: String in tokens:
		if tok.contains("-"):
			parts.append_array(tok.split("-", false))
	var blocked: Dictionary = w.get("blocked", {}) if w.get("blocked", {}) is Dictionary else {}
	for cat: String in BLOCKED_ORDER:
		if _any_hit(parts, blocked.get(cat, [])):
			return "blocked_" + cat
	if low.contains("€") or _any_hit(parts, w.get("money", [])):
		return "money"
	if _any_hit(parts, w.get("purchase", [])) and _has_phrase(tokens, w.get("urgency", [])):
		return "purchase_pressure"
	var n: int = tokens.size()
	if n >= int(w.get("lang_min_words", 4)):
		var de_list: Variant = w.get("de_stopwords", [])
		var de: int = _count(tokens, de_list)
		var en: int = 0
		for tok: String in tokens:
			if (w.get("en_stopwords", []) as Array).has(tok) and not (de_list as Array).has(tok):
				en += 1
		if en * 1000 / n > int(w.get("en_max_pm", 150)) \
				or (n >= int(w.get("lang_de_min_words", 6)) and de * 1000 / n < int(w.get("de_min_pm", 100))):
			return "language"
	return ""


## Lower-case words of a text: runs of a–z, ä, ö, ü, ß joined by single hyphens ("sponsor-fenster").
static func tokenize(low: String) -> PackedStringArray:
	_compile()
	var out: PackedStringArray = []
	for m: RegExMatch in _re_word.search_all(low.to_lower()):
		out.append(m.get_string(0))
	return out


static func _compile() -> void:
	if _re_word != null:
		return
	_re_word = RegEx.create_from_string("[a-zäöüß]+(?:-[a-zäöüß]+)*")
	_re_brace = RegEx.create_from_string("\\{[^{}]*\\}")
	_re_url = RegEx.create_from_string("[a-z0-9-]+\\.(?:de|com|net|org|io|tv|gg|eu|info|app|ly)\\b")
	_re_digits = RegEx.create_from_string("[0-9](?:[ ./-]?[0-9]){5,}")


static func _any_hit(tokens: PackedStringArray, list: Variant) -> bool:
	if not (list is Array):
		return false
	for entry: Variant in (list as Array):
		var e: String = str(entry).to_lower()
		if e == "" or e.contains(" "):
			continue
		if e.ends_with("*"):
			var stem: String = e.trim_suffix("*")
			for tok: String in tokens:
				if tok.begins_with(stem):
					return true
		elif tokens.has(e):
			return true
	return false


static func _has_phrase(tokens: PackedStringArray, list: Variant) -> bool:
	if not (list is Array):
		return false
	var joined: String = " " + " ".join(tokens) + " "
	for entry: Variant in (list as Array):
		var e: String = str(entry).to_lower().strip_edges()
		if e != "" and joined.contains(" " + e + " "):
			return true
	return false


static func _count(tokens: PackedStringArray, list: Variant) -> int:
	if not (list is Array):
		return 0
	var n: int = 0
	for tok: String in tokens:
		if (list as Array).has(tok):
			n += 1
	return n
