class_name PersonaText extends RefCounted
## Pure text helpers of the persona (08 §4.4, §5.6, §7): the placeholder context of M.O.D. lines ({cand}, {job},
## {hobby}, {club}, {trait}, {rival}, {brand}, {job_text}), the card texts, the name and free-text filters (D-3, D-4,
## D-9) with a reason sentence and the nearest tile, the filter for AI lines (K-7) and the length rule of the persona
## lines. No autoloads: the word lists come from res://data/mod_filter.json (ModLineFilter.words()).

## Fallbacks of 08 §4.4 (no persona, canon "Rest automatisch", unknown ids).
const FALLBACK: Dictionary = {"cand": "Kandidat:in", "job": "Tierpfleger:in", "hobby": "Freizeit",
	"club": "Ihr Freundeskreis", "trait": "undurchschaubar"}
## Placeholders the persona context provides ({name} stays Show's: the display name; {job_text} only for the one
## quoting line persona_intro:custom).
const KEYS: PackedStringArray = ["cand", "job", "hobby", "club", "trait", "rival", "brand", "job_text"]
## The word form of {cand} (08 §1.2: M.O.D. siezt, there is no "Frau/Herr").
const CANDIDATE: Dictionary = {"f": "Kandidatin", "m": "Kandidat", "n": "Kandidat:in"}
## Longest value per placeholder (08 §4.4): a persona line + Σ (max − placeholder length) <= LINE_MAX.
const MAX_LEN: Dictionary = {"name": 12, "cand": 11, "job": 24, "hobby": 24, "club": 30, "trait": 16, "rival": 24,
	"brand": 24, "job_text": 24}
const LINE_MAX: int = 110
const NAME_MAX: int = 12
const FREE_MAX: int = 24                      # "Anderes …" (Vorleben / Hobby)
const ABOUT_MAX: int = 200                    # the self description of the AI casting (K3)
const ALLROUND: String = "org_allround"
const ALLROUND_PARENT: String = "org_office" # politics words → "Büro, Finanzen & Verwaltung" (08 §1.3, D-9)
## Reason sentences of the free-text filter (08 §1.3, D-4) per blocked list of mod_filter.json (+ "pii", "length").
const REASONS: Dictionary = {
	"politics": "Politik sendet M.O.D. nicht.",
	"sexual": "Das ist nicht jugendfrei. Bitte etwas anderes.",
	"slurs": "Beleidigungen sendet M.O.D. nicht.",
	"violence": "Gewalt sendet M.O.D. nicht.",
	"real_brands": "Bitte keine Markennamen.",
	"ip_distance": "Dieses Wort lässt die Redaktion lieber weg.",
	"origin": "Herkunftsangaben sendet M.O.D. nicht.",
	"pii": "Bitte keine Kontaktdaten, Adressen oder Nummern.",
	"length": "Höchstens %d Zeichen.",
}
## The name filter (D-3): "Dieser Name ist leider nicht sendefähig: <why>."
const NAME_REASONS: Dictionary = {
	"politics": "enthält Politik", "sexual": "ist nicht jugendfrei", "slurs": "enthält eine Beleidigung",
	"violence": "enthält Gewalt", "real_brands": "enthält ein Markenwort", "ip_distance": "enthält ein gesperrtes Wort",
	"origin": "enthält eine Herkunftsangabe", "pii": "enthält Kontaktdaten oder Nummern",
}
## Casting-only additions to the politics list of mod_filter.json (D-9: "Politiker", "Parlament" … are no catalog
## jobs and never broadcast). Same entry syntax as mod_filter.json.
const EXTRA_POLITICS: PackedStringArray = ["politik*", "*politiker", "*politikerin", "parlament*", "extremis*",
	"rechtsextrem*", "linksextrem*", "bürgermeister*", "gemeinderat*", "stadtrat*", "stadträtin*", "landrat*",
	"landrätin*", "staatssekretär*", "diktat*", "propaganda*", "wahlhelfer*"]
## AI lines (K-7): hooks (never "boss", R6), voices, at most this many lines, at least AI_MIN_VALID valid ones.
const AI_HOOKS: PackedStringArray = ["card", "intro", "first_chest", "safe_room", "floor_end", "game_over"]
const AI_VOICES: PackedStringArray = ["mod", "mopsula"]
const AI_MAX_LINES: int = 12
const AI_MIN_VALID: int = 4
const AI_PLACEHOLDERS: PackedStringArray = ["name", "cand", "job", "hobby", "club", "trait", "rival", "brand"]
## Graf Mopsula's voice: no royal "Wir/Uns/Unser…" outside the sentence start (06 D, R20; K-7).
const ROYAL_PLURAL: String = "\\b(Wir|Uns|Unser[a-zäöü]*)\\b"

static var _re_ph: RegEx = null
static var _re_email: RegEx = null
static var _re_url: RegEx = null
static var _re_digits: RegEx = null
static var _re_handle: RegEx = null
static var _re_iban: RegEx = null
static var _re_royal: RegEx = null


## Placeholder values for `p` (null = canon). `rng`: a presentation RNG (Show._fx_rng) for the changing value
## {trait}; null (UiUtil.format_line, the casting) → the first chosen trait, no draw.
static func ctx(p: PersonaProfile, data: GameData, rng: RandomNumberGenerator) -> Dictionary:
	var out: Dictionary = FALLBACK.duplicate()
	var prof: PersonaProfile = p if p != null else PersonaProfile.canon(data)
	out["cand"] = cand(prof.form)
	out["job"] = job(prof, data)
	out["hobby"] = hobby_name(prof, data)
	out["club"] = club(prof, data)
	if not prof.traits.is_empty():
		var i: int = rng.randi_range(0, prof.traits.size() - 1) if rng != null else 0
		var t: String = str(data.trait_def(prof.traits[i]).get("name", "")) if data != null else ""
		if t != "":
			out["trait"] = t
	out["rival"] = rival_name(prof, data)
	out["brand"] = brand_name(prof, data)
	out["job_text"] = prof.job_text
	return out


## {cand} of a word form ("f" | "m" | "n"; anything else → "n").
static func cand(form: String) -> String:
	return str(CANDIDATE.get(form, CANDIDATE["n"]))


## {job} (08 §3.7): the "genauer" job's form > the tile's role form, in the word form (status tiles: one form);
## never the free text. Unknown origin → the canon fallback "Tierpfleger:in".
static func job(p: PersonaProfile, data: GameData) -> String:
	if p == null or data == null:
		return str(FALLBACK["job"])
	var o: Dictionary = data.origin(p.origin)
	if o.is_empty():
		return str(FALLBACK["job"])
	var form: String = p.form if PersonaProfile.FORMS.has(p.form) else "n"
	for j: Dictionary in o.get("jobs", []):
		if str(j.get("id", "")) == p.occupation and p.occupation != "":
			return str(j.get(form, j.get("n", "")))
	var role: Dictionary = o.get("role", {})
	return str(role.get(form, role.get("n", FALLBACK["job"])))


## {hobby}: the hobby tile's name; without a hobby (or "Anderes …" without a match) "Freizeit".
static func hobby_name(p: PersonaProfile, data: GameData) -> String:
	if p == null or data == null or p.hobby == "":
		return str(FALLBACK["hobby"])
	var n: String = str(data.hobby(p.hobby).get("name", ""))
	return n if n != "" else str(FALLBACK["hobby"])


## {club}: the hobby's club with its possessive ("Ihr Kochkurs", "Ihre Band"); fallback "Ihr Freundeskreis".
static func club(p: PersonaProfile, data: GameData) -> String:
	if p == null or data == null or p.hobby == "":
		return str(FALLBACK["club"])
	var c: Dictionary = data.hobby(p.hobby).get("club", {})
	var text: String = str(c.get("text", ""))
	if text == "":
		return str(FALLBACK["club"])
	return ("Ihre " if str(c.get("g", "m")) == "f" else "Ihr ") + text


## {rival}: the persona's rival beat, else the first rival of the origin, else of the canon origin.
static func rival_name(p: PersonaProfile, data: GameData) -> String:
	if data == null:
		return ""
	var id: String = str(p.beats.get("rival", "")) if p != null else ""
	if id == "" or data.persona_entry("rivals", id).is_empty():
		id = _first_rival(data, p.origin if p != null else "")
	return str(data.persona_entry("rivals", id).get("name", ""))


## {brand}: the persona's sponsor beat, else the origin's sponsor, else the canon origin's.
static func brand_name(p: PersonaProfile, data: GameData) -> String:
	if data == null:
		return ""
	var id: String = str(p.beats.get("brand", "")) if p != null else ""
	if id == "" or data.persona_entry("brands", id).is_empty():
		id = str(data.origin(p.origin if p != null else "").get("brand", ""))
		if id == "":
			id = str(data.origin(str(data.persona_canon().get("origin", ""))).get("brand", ""))
	return str(data.persona_entry("brands", id).get("name", ""))


## The card texts (08 §1.4, §1.7): {"title": "JANA · Kandidatin", "job": "Hebamme · Hobby: Kochen & Backen",
## "traits": "chaotisch · fürsorglich" ("" without), "free": "Anderes: Astronaut · Hobby: Origami" ("" without)}.
static func card(p: PersonaProfile, data: GameData) -> Dictionary:
	var prof: PersonaProfile = p if p != null else PersonaProfile.canon(data)
	var traits: PackedStringArray = []
	for t: String in prof.traits:
		var n: String = str(data.trait_def(t).get("name", "")) if data != null else ""
		if n != "":
			traits.append(n)
	var free: PackedStringArray = []
	if prof.job_text != "":
		free.append("Vorleben: „%s“" % prof.job_text)
	if prof.hobby_text != "":
		free.append("Hobby: „%s“" % prof.hobby_text)
	return {"title": "%s · %s" % [prof.name.to_upper(), cand(prof.form)],
		"job": "%s · Hobby: %s" % [job(prof, data), hobby_name(prof, data)],
		"traits": " · ".join(traits), "free": " · ".join(free)}


## The canon persona (08 §3.6) — what CR-23's client rule calls "Kanon": no profile, or the canon name with the
## canon origin (and its canon job or none).
static func is_canon(p: PersonaProfile, data: GameData) -> bool:
	if p == null or data == null:
		return true
	var c: Dictionary = data.persona_canon()
	return p.name == str(c.get("name", GameState.DEFAULT_NAME)) and p.origin == str(c.get("origin", "")) \
		and (p.occupation == "" or p.occupation == str(c.get("occupation", "")))


## Dormant since CR-33 (no start talents): always "".
static func plain_line(_def: TalentDef) -> String:
	return ""


## "" or the reason sentence why a name cannot be broadcast (08 D-3): "Dieser Name ist leider nicht sendefähig: …".
## The name is TitleFlow.clean_name's (<= 12 glyphs the font has); this checks length, PII patterns and the word lists.
static func check_name(name: String) -> String:
	var t: String = name.strip_edges()
	if t.length() > NAME_MAX:
		return "Dieser Name ist leider zu lang: höchstens %d Zeichen." % NAME_MAX
	var why: String = _problem(t)
	if why == "":
		return ""
	return "Dieser Name ist leider nicht sendefähig: %s." % str(NAME_REASONS.get(why, "enthält ein gesperrtes Wort"))


## "" or the reason sentence for a free text (08 D-4, D-9; K-4's client part): length, PII patterns (e-mail, URL,
## phone numbers / digit runs >= 6, @handles, IBAN-like), the blocked lists of mod_filter.json and the casting's
## politics additions. A rejected field is dropped, never cleaned and kept.
static func check_free_text(text: String, max_len: int) -> String:
	var t: String = text.strip_edges()
	if t.length() > max_len:
		return str(REASONS["length"]) % max_len
	var why: String = _problem(t)
	return str(REASONS.get(why, "")) if why != "" else ""


## The origin tile closest to a rejected free text (08 §1.3): a keyword hit in the text (PersonaRules.map_text), for
## politics "Büro, Finanzen & Verwaltung"; "" if none.
static func nearest_tile(data: GameData, rejected_text: String, reason: String) -> String:
	if data == null:
		return ""
	if reason == str(REASONS["politics"]) or reason == "politics":
		return ALLROUND_PARENT if not data.origin(ALLROUND_PARENT).is_empty() else ""
	var id: String = PersonaRules.map_text(data, rejected_text, &"job")
	return id if id != ALLROUND else ""


## AI lines that pass the filters (08 §5.5 K-7): {hook, voice, text} with a known hook (never "boss") and voice, only
## the persona placeholders, every line with the longest probe values <= 110 and through ModLineFilter.check, Graf
## Mopsula without the royal plural or royalty words, never "von Beruf". At most AI_MAX_LINES; fewer than
## AI_MIN_VALID valid lines → none (the mapping stays). Returns copies {hook, voice, text}.
static func filter_ai_lines(lines: Array, data: GameData) -> Array:
	var out: Array = []
	_compile()
	var probe: Dictionary = probe_ctx()
	for l: Variant in lines:
		if out.size() >= AI_MAX_LINES:
			break
		if not (l is Dictionary):
			continue
		var d: Dictionary = l
		var hook: String = str(d.get("hook", ""))
		var voice: String = str(d.get("voice", "mod"))
		var text: String = str(d.get("text", "")).strip_edges()
		if not AI_HOOKS.has(hook) or not AI_VOICES.has(voice) or text == "":
			continue
		if not only_placeholders(text, AI_PLACEHOLDERS) or effective_length(text) > LINE_MAX:
			continue
		var filled: String = text.format(probe)
		if ModLineFilter.check(filled, {}, voice) != "" or filled.to_lower().contains("von beruf"):
			continue
		if voice == "mopsula" and (royal_plural(filled) or _royal_word(filled)):
			continue
		out.append({"hook": hook, "voice": voice, "text": text})
	if data == null or out.size() < AI_MIN_VALID:
		return []
	return out


## Raw length + Σ (max length − placeholder length) of every persona placeholder (08 §4.4 length rule).
static func effective_length(text: String) -> int:
	_compile()
	var n: int = text.length()
	for m: RegExMatch in _re_ph.search_all(text):
		var key: String = m.get_string(1)
		if MAX_LEN.has(key):
			n += int(MAX_LEN[key]) - m.get_string(0).length()
	return n


## True when every {…} of `text` is one of `allowed`.
static func only_placeholders(text: String, allowed: PackedStringArray) -> bool:
	_compile()
	for m: RegExMatch in _re_ph.search_all(text):
		if not allowed.has(m.get_string(1)):
			return false
	var stripped: String = _re_ph.sub(text, "", true)
	return not stripped.contains("{") and not stripped.contains("}")


## The longest probe value per placeholder (08 §4.4) — the length rule and the AI filter fill lines with these.
static func probe_ctx() -> Dictionary:
	var out: Dictionary = {}
	for k: String in MAX_LEN.keys():
		out[k] = "M".repeat(int(MAX_LEN[k])) if k != "name" else "Maximiliane"
	out["name"] = "Mmmmmmmmmmmm"
	out["cand"] = "Kandidat:in"
	return out


## A capitalized "Wir" / "Uns" / "Unser…" that does not start a sentence (K-7: Graf Mopsula is a count, no royal
## plural; the sentence start is the text start or the first word after . ! ? : or an opening quote).
static func royal_plural(text: String) -> bool:
	_compile()
	for m: RegExMatch in _re_royal.search_all(text):
		var before: String = text.substr(0, m.get_start()).strip_edges(false, true)
		before = before.trim_suffix("„").trim_suffix("\"").trim_suffix("‚").strip_edges(false, true)
		if before != "" and not (before.ends_with(".") or before.ends_with("!") or before.ends_with("?")
				or before.ends_with(":")):
			return true
	return false


# --- internals --------------------------------------------------------------------------------------------------------

## "" or the failing list: "pii", a blocked list of mod_filter.json, "politics" (extras).
static func _problem(t: String) -> String:
	_compile()
	var low: String = t.to_lower()
	if _re_email.search(t) != null or _re_url.search(low) != null or low.contains("www.") or low.contains("://") \
			or _re_digits.search(t) != null or _re_handle.search(t) != null or _re_iban.search(t) != null:
		return "pii"
	var tokens: PackedStringArray = ModLineFilter.tokenize(low)
	var parts: PackedStringArray = tokens.duplicate()
	for tok: String in tokens:
		if tok.contains("-"):
			parts.append_array(tok.split("-", false))
	var blocked: Variant = ModLineFilter.words().get("blocked", {})
	if blocked is Dictionary:
		for cat: String in ModLineFilter.BLOCKED_ORDER:
			for entry: Variant in ((blocked as Dictionary).get(cat, []) as Array):
				if _entry_hit(tokens, parts, str(entry).to_lower()):
					return cat
	for entry: String in EXTRA_POLITICS:
		if _entry_hit(tokens, parts, entry):
			return "politics"
	return ""


static func _entry_hit(tokens: PackedStringArray, parts: PackedStringArray, entry: String) -> bool:
	if entry.contains(" "):
		return (" " + " ".join(tokens) + " ").contains(" " + entry + " ")
	var pre: bool = entry.ends_with("*")
	var suf: bool = entry.begins_with("*")
	var core: String = entry.trim_prefix("*").trim_suffix("*")
	if core == "":
		return false
	for t: String in parts:
		if (pre and suf and t.contains(core)) or (pre and not suf and t.begins_with(core)) \
				or (suf and not pre and t.ends_with(core)) or (not pre and not suf and t == core):
			return true
	return false


static func _royal_word(text: String) -> bool:
	var low: String = text.to_lower()
	for w: Variant in (ModLineFilter.words().get("mopsula_royalty", []) as Array):
		if low.contains(str(w).trim_prefix("*").trim_suffix("*")):
			return true
	return false


static func _first_rival(data: GameData, origin_id: String) -> String:
	var rivals: PackedStringArray = JsonUtil.to_str_array(data.origin(origin_id).get("rivals", []))
	if rivals.is_empty():
		rivals = JsonUtil.to_str_array(data.origin(str(data.persona_canon().get("origin", ""))).get("rivals", []))
	return rivals[0] if not rivals.is_empty() else ""


static func _compile() -> void:
	if _re_ph != null:
		return
	_re_ph = RegEx.create_from_string("\\{([a-z_]+)\\}")
	_re_email = RegEx.create_from_string("[^\\s@]+@[^\\s@]+\\.[a-zA-Z]{2,}")
	_re_url = RegEx.create_from_string("\\b[a-z0-9-]+\\.(de|com|net|org|io|at|ch|eu|info|biz|tv|app|me)\\b")
	_re_digits = RegEx.create_from_string("\\d(?:[\\s./-]?\\d){5,}")
	_re_handle = RegEx.create_from_string("(^|\\s)@\\w")
	_re_iban = RegEx.create_from_string("(?i)\\b[a-z]{2}\\d{2}(?:\\s?[a-z0-9]){8,}")
	_re_royal = RegEx.create_from_string(ROYAL_PLURAL)
