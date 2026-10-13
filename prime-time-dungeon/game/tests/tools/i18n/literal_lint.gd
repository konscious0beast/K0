extends RefCounted
## The lint of 11 §1.12 (SP-8, R11): German literals in player code outside Tx. A literal is a finding when it looks
## German — an umlaut, ß, „ or a whole word of a small German stopword list — and it sits in a script under
## res://scenes, autoload, core or art, outside a Tx.t / Tx.n / Tx.m call (the innermost open call around it), outside
## the developer calls (print*, push_warning, push_error, assert) and the developer files (validators, checks,
## galleries, the language machinery), on a line without "# no-i18n: <reason>". tr("…") and tr_text("…") are no Tx
## yet: they count (L2). Shared by test_11_literals (with its PENDING list) and tools/i18n.sh lint.

const GdLiterals := preload("res://tests/tools/i18n/gd_literals.gd")

const ROOTS: PackedStringArray = ["res://scenes", "res://autoload", "res://core", "res://art"]
## Developer code (11 §1.3: developer and log texts stay as they are) → why.
const DEV_PATHS: Dictionary = {
	"res://core/data/data_validator.gd": "validator messages",
	"res://core/data/validators/": "validator messages and the word lists of the IP and tone checks",
	"res://core/stempel/validators/": "validator messages of the Stempelduell",
	"res://core/rt/rt_check.gd": "RtCheck messages",
	"res://art/gallery/": "developer galleries (not exported)",
	"res://core/data/tx.gd": "the German formats (fallback of locale/formats.json)",
	"res://core/data/locale_loader.gd": "the language machinery",
	"res://core/stempel/ctb/": "the frozen CTB engine (10 §7.5): TEXT_PREEMPTIVE stays, the Stempelduell's display "
		+ "translates the event (11 §5.5)",
	"res://scenes/boot/fullrun.gd": "the full-run bot (02_TECH §11.4.1): log and failure lines",
	"res://scenes/boot/autoplay.gd": "the smoke bot (02_TECH §11.4): log lines",
	"res://scenes/ui/debug_overlay.gd": "the debug overlay (11 §1.3: developer text)",
}
const DEV_CALLS: PackedStringArray = ["print", "prints", "printt", "printerr", "print_rich", "print_debug",
	"print_verbose", "push_warning", "push_error", "assert"]
const TX_CALLS: PackedStringArray = ["Tx.t", "Tx.n", "Tx.m"]
const NO_I18N: String = "no-i18n:"
## Function words and a few frequent game words that only German has (no English homographs like "die", "an", "was").
const STOPWORDS: PackedStringArray = ["der", "das", "und", "nicht", "ist", "ein", "eine", "einen", "einem", "einer",
	"mit", "auf", "Sie", "Ihr", "Ihre", "Ihren", "Ihnen", "wird", "werden", "noch", "kein", "keine", "zum", "zur",
	"vom", "dem", "des", "sich", "oder", "auch", "schon", "jetzt", "hier", "nach", "bei", "aus", "wenn", "dann", "aber",
	"nur", "mehr", "alle", "dich", "ich", "wir", "sind", "kann", "muss", "gibt", "Der", "Die", "Das", "Ein",
	"Eine", "Kein", "Keine", "Mit", "Und", "Noch", "Bitte", "bitte", "Etage", "Stufe", "Kampf", "Gegner", "Spiel",
	"Neues", "Neue", "Neuer", "Zuschauer", "Kandidat:in", "Sendung"]
const GERMAN_CHARS: String = "äöüÄÖÜß„"

static var _re_word: RegEx = null


## The files the lint reads.
static func files() -> PackedStringArray:
	var out: PackedStringArray = []
	for root: String in ROOTS:
		_collect(root, out)
	out.sort()
	var kept: PackedStringArray = []
	for p: String in out:
		if dev_reason(p) == "":
			kept.append(p)
	return kept


static func dev_reason(path: String) -> String:
	for k: String in DEV_PATHS:
		if path == k or (k.ends_with("/") and path.begins_with(k)):
			return str(DEV_PATHS[k])
	return ""


## "line: text" of every finding in a script's source.
static func findings(source: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var sc: Dictionary = GdLiterals.scan(source)
	var lits: Array[Dictionary] = sc["lits"]
	var german: Array[int] = []
	for i in lits.size():
		if looks_german(str(lits[i]["text"])):
			german.append(i)
	if german.is_empty():
		return out
	var code: PackedStringArray = sc["code"]
	var comments: Dictionary = sc["comments"]
	var stack: Array[String] = []                 # the calls open at the current position (names)
	var next: int = 0
	for i in lits.size():
		_track(code[i], stack)
		if next >= german.size() or german[next] != i:
			continue
		next += 1
		var line: int = int(lits[i]["line"])
		if str(comments.get(line, "")).contains(NO_I18N):
			continue
		if not stack.is_empty() and TX_CALLS.has(stack.back()):
			continue
		var dev: bool = false
		for name: String in stack:
			dev = dev or DEV_CALLS.has(name)
		if dev:
			continue
		out.append("%d: %s" % [line, str(lits[i]["text"]).replace("\n", "\\n")])
	return out


## Looks German: an umlaut, ß, „ or a stopword as a whole word (a single character is no text: "ä" in a list).
static func looks_german(text: String) -> bool:
	if text.length() < 2:
		return false
	for i in GERMAN_CHARS.length():
		if text.contains(GERMAN_CHARS[i]):
			return true
	if _re_word == null:
		_re_word = RegEx.create_from_string("[\\p{L}:]+")
	for m: RegExMatch in _re_word.search_all(text):
		if STOPWORDS.has(m.get_string(0)):
			return true
	return false


## Updates the stack of open calls with the parentheses of a code segment.
static func _track(segment: String, stack: Array[String]) -> void:
	var i: int = 0
	while true:
		var o: int = segment.find("(", i)
		var c: int = segment.find(")", i)
		if o < 0 and c < 0:
			return
		if o >= 0 and (c < 0 or o < c):
			stack.append(_name_before(segment, o))
			i = o + 1
		else:
			if not stack.is_empty():
				stack.pop_back()
			i = c + 1


static func _name_before(s: String, at: int) -> String:
	var j: int = at
	while j > 0 and (GdLiterals.IDENT.contains(s[j - 1]) or s[j - 1] == "."):
		j -= 1
	return s.substr(j, at - j)


static func _collect(dir_path: String, out: PackedStringArray) -> void:
	var d: DirAccess = DirAccess.open(dir_path)
	if d == null:
		return
	for sub: String in d.get_directories():
		if not sub.begins_with("."):
			_collect(dir_path.path_join(sub), out)
	for f: String in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir_path.path_join(f))
