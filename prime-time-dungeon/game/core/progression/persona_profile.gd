class_name PersonaProfile extends RefCounted
## The candidate's local presentation data (08 §2.2): name, word form, Vorleben (origin + optional job), hobby,
## traits, look (K2), story beats, AI lines (K3). Never part of GameState, never recorded, never synced; stored per
## slot in user://persona/slot_N.json (Save.persona_path). Loading checks everything against the catalog again:
## unknown ids show the canon value (08 §2.5), rejected texts are dropped. The K0 fields `talent` and `offer` stay
## empty until 09 ST0 (CR-33).

const FORMAT: String = "ptd_persona"
const VERSION: int = 1
const FORMS: PackedStringArray = ["f", "m", "n"]
const SOURCES: PackedStringArray = ["canon", "offline", "ai"]
## The fields "Rest automatisch" fills when the player did not set them (fill_unset); "origin" covers occupation and
## the free text, "hobby" its free text.
const FIELDS: PackedStringArray = ["name", "form", "origin", "hobby", "traits"]
const MAX_TRAITS: int = 3
const ALLROUND: String = "org_allround"
const COLLEAGUES: String = "gr_colleagues"     # the greeting without a hobby (08 §4.6)
const TAGLINE_MAX: int = 60

var name: String = GameState.DEFAULT_NAME
var form: String = "n"
var origin: String = ""
var occupation: String = ""
var job_text: String = ""
var hobby: String = ""
var hobby_text: String = ""
var traits: PackedStringArray = []
var look: Dictionary = {}
var talent: String = ""
var offer: PackedStringArray = []
var beats: Dictionary = {}
var ai: Dictionary = {}
var source: String = "canon"


## The canon persona ("Rest automatisch" without input, old saves, bots; 08 §3.6): origins.json → canon, with the
## canon beats (first rival, sponsor, gag and greeting of the canon tile and hobby).
static func canon(data: GameData) -> PersonaProfile:
	var p: PersonaProfile = PersonaProfile.new()
	var c: Dictionary = data.persona_canon() if data != null else {}
	p.name = str(c.get("name", GameState.DEFAULT_NAME))
	p.form = str(c.get("form", "n"))
	p.origin = str(c.get("origin", ""))
	p.occupation = str(c.get("occupation", ""))
	p.hobby = str(c.get("hobby", ""))
	p.traits = JsonUtil.to_str_array(c.get("traits", []))
	p.source = "canon"
	p.make_beats(data, null)
	return p


## A persona file dictionary (08 §2.2); another format or a higher "v" → the canon persona (warning). Everything is
## checked against the catalog (unknown ids → canon, warning), the name and the free texts against the filters
## (rejected → canon name / dropped), the AI lines against PersonaText.filter_ai_lines.
static func from_dict(d: Dictionary, data: GameData) -> PersonaProfile:
	if str(d.get("format", "")) != FORMAT or JsonUtil.to_int(d.get("v", 0)) != VERSION:
		push_warning("PersonaProfile: unknown persona file format/version → canon")
		return canon(data)
	var p: PersonaProfile = PersonaProfile.new()
	p.name = str(d.get("name", GameState.DEFAULT_NAME)).strip_edges()
	p.form = str(d.get("form", "n")) if FORMS.has(str(d.get("form", "n"))) else "n"
	p.origin = str(d.get("origin", ""))
	p.occupation = str(d.get("occupation", ""))
	p.job_text = str(d.get("job_text", ""))
	p.hobby = str(d.get("hobby", ""))
	p.hobby_text = str(d.get("hobby_text", ""))
	p.traits = JsonUtil.to_str_array(d.get("traits", []))
	p.look = (d.get("look", {}) as Dictionary).duplicate(true) if d.get("look", {}) is Dictionary else {}
	p.talent = ""                                   # CR-33: never a start talent (K0 field, dormant)
	p.offer = PackedStringArray()
	p.beats = (d.get("beats", {}) as Dictionary).duplicate(true) if d.get("beats", {}) is Dictionary else {}
	p.ai = (d.get("ai", {}) as Dictionary).duplicate(true) if d.get("ai", {}) is Dictionary else {}
	p.source = str(d.get("source", "offline")) if SOURCES.has(str(d.get("source", ""))) else "offline"
	var fixed: PackedStringArray = p.sanitize(data)
	if not fixed.is_empty():
		push_warning("PersonaProfile: persona file corrected (%s)" % ", ".join(fixed))
	return p


## The persona file (08 §2.2).
func to_dict() -> Dictionary:
	return {"format": FORMAT, "v": VERSION, "name": name, "form": form, "origin": origin, "occupation": occupation,
		"job_text": job_text, "hobby": hobby, "hobby_text": hobby_text, "traits": Array(traits),
		"look": look.duplicate(true), "talent": talent, "offer": Array(offer), "beats": beats.duplicate(true),
		"ai": ai.duplicate(true), "source": source}


## "Rest automatisch" (08 §1.5): every field of FIELDS that is not in `set_fields` gets its canon value ("origin"
## with its job and free text, "hobby" with its free text); without any input the result is the canon persona.
## The beats follow the (new) origin and hobby; the source is "canon" when nothing was set, else "offline".
func fill_unset(data: GameData, set_fields: PackedStringArray) -> void:
	var c: PersonaProfile = canon(data)
	if not set_fields.has("name"):
		name = c.name
	if not set_fields.has("form"):
		form = c.form
	if not set_fields.has("origin"):
		origin = c.origin
		occupation = c.occupation
		job_text = ""
	if not set_fields.has("hobby"):
		hobby = c.hobby
		hobby_text = ""
	if not set_fields.has("traits"):
		traits = c.traits.duplicate()
	var any: bool = false
	for f: String in FIELDS:
		any = any or set_fields.has(f)
	source = "offline" if any else "canon"
	make_beats(data, null, true)


## Problems against the catalog and the filters ([] = a valid persona): unknown ids, a job of another tile, more
## than MAX_TRAITS or repeated traits, lengths, the name and free-text filters, a bad word form.
func validate(data: GameData) -> PackedStringArray:
	var out: PackedStringArray = []
	if name == "" or name.length() > PersonaText.NAME_MAX:
		out.append("name: 1..%d characters" % PersonaText.NAME_MAX)
	elif PersonaText.check_name(name) != "":
		out.append("name: " + PersonaText.check_name(name))
	if not FORMS.has(form):
		out.append("form: must be f | m | n")
	if data == null:
		return out
	if data.origin(origin).is_empty():
		out.append("origin: unknown '%s'" % origin)
	elif occupation != "" and not _job_ids(data, origin).has(occupation):
		out.append("occupation: '%s' is no job of %s" % [occupation, origin])
	if hobby != "" and data.hobby(hobby).is_empty():
		out.append("hobby: unknown '%s'" % hobby)
	for pair: Array in [["job_text", job_text], ["hobby_text", hobby_text]]:
		if str(pair[1]) != "" and PersonaText.check_free_text(str(pair[1]), PersonaText.FREE_MAX) != "":
			out.append("%s: %s" % [pair[0], PersonaText.check_free_text(str(pair[1]), PersonaText.FREE_MAX)])
	if traits.size() > MAX_TRAITS:
		out.append("traits: at most %d" % MAX_TRAITS)
	var seen: Dictionary = {}
	for t: String in traits:
		if data.trait_def(t).is_empty():
			out.append("traits: unknown '%s'" % t)
		if seen.has(t):
			out.append("traits: '%s' twice" % t)
		seen[t] = true
	if talent != "":
		out.append("talent: must be empty (CR-33)")
	return out


# --- K1 helpers (presentation; not part of the K0 contract) -----------------------------------------------------------

## Corrects the profile in place against the catalog and the filters; returns what was changed (field names).
func sanitize(data: GameData) -> PackedStringArray:
	var fixed: PackedStringArray = []
	var c: PersonaProfile = canon(data) if data != null else PersonaProfile.new()
	if name == "" or name.length() > PersonaText.NAME_MAX or PersonaText.check_name(name) != "":
		name = c.name
		fixed.append("name")
	if data == null:
		return fixed
	if data.origin(origin).is_empty():
		origin = c.origin
		occupation = c.occupation
		fixed.append("origin")
	elif occupation != "" and not _job_ids(data, origin).has(occupation):
		occupation = ""
		fixed.append("occupation")
	if hobby != "" and data.hobby(hobby).is_empty():
		hobby = c.hobby
		fixed.append("hobby")
	if job_text != "" and PersonaText.check_free_text(job_text, PersonaText.FREE_MAX) != "":
		job_text = ""
		fixed.append("job_text")
	if hobby_text != "" and PersonaText.check_free_text(hobby_text, PersonaText.FREE_MAX) != "":
		hobby_text = ""
		fixed.append("hobby_text")
	var clean: PackedStringArray = []
	for t: String in traits:
		if not data.trait_def(t).is_empty() and not clean.has(t) and clean.size() < MAX_TRAITS:
			clean.append(t)
	if clean != traits:
		traits = clean
		fixed.append("traits")
	if not _beats_valid(data):
		make_beats(data, null, true)
		fixed.append("beats")
	var lines: Array = (ai.get("lines", []) as Array) if ai.get("lines", []) is Array else []
	if not lines.is_empty() or ai.has("tagline"):
		var kept: Array = PersonaText.filter_ai_lines(lines, data)
		if kept.size() != lines.size():
			fixed.append("ai.lines")
		var tagline: String = str(ai.get("tagline", ""))
		if tagline.length() > TAGLINE_MAX:
			tagline = ""
			fixed.append("ai.tagline")
		var hidden: Array = []
		for h: Variant in (ai.get("hidden", []) as Array) if ai.get("hidden", []) is Array else []:
			if JsonUtil.is_integral(h) and int(h) >= 0 and int(h) < kept.size():
				hidden.append(int(h))
		ai = {"tagline": tagline, "lines": kept, "hidden": hidden}
	return fixed


## The story beats from the catalog (08 §4.6): the rival is one of the two of the origin (`rng`: the casting's
## presentation RNG; null → the first), the sponsor the origin's, gag and greeting the hobby's (without a hobby: no
## gag, the colleagues' greeting). `keep_rival`: a rival of the same origin stays.
func make_beats(data: GameData, rng: RandomNumberGenerator, keep_rival: bool = false) -> void:
	if data == null:
		return
	var o: Dictionary = data.origin(origin)
	var rivals: PackedStringArray = JsonUtil.to_str_array(o.get("rivals", []))
	var rival: String = str(beats.get("rival", ""))
	if not (keep_rival and rivals.has(rival)):
		rival = ""
		if not rivals.is_empty():
			rival = rivals[rng.randi_range(0, rivals.size() - 1)] if rng != null else rivals[0]
	var h: Dictionary = data.hobby(hobby) if hobby != "" else {}
	beats = {"rival": rival, "brand": str(o.get("brand", "")), "gag": str(h.get("gag", "")),
		"greeting": str(h.get("greeting", COLLEAGUES)) if not h.is_empty() else COLLEAGUES}


## The persona plays the canon (PersonaText.is_canon).
func is_canon(data: GameData) -> bool:
	return PersonaText.is_canon(self, data)


## A deep copy.
func copy() -> PersonaProfile:
	var p: PersonaProfile = PersonaProfile.new()
	for f: String in ["name", "form", "origin", "occupation", "job_text", "hobby", "hobby_text", "talent", "source"]:
		p.set(f, get(f))
	p.traits = traits.duplicate()
	p.offer = offer.duplicate()
	p.look = look.duplicate(true)
	p.beats = beats.duplicate(true)
	p.ai = ai.duplicate(true)
	return p


func _beats_valid(data: GameData) -> bool:
	var rival: String = str(beats.get("rival", ""))
	if not JsonUtil.to_str_array(data.origin(origin).get("rivals", [])).has(rival):
		return false
	for pair: Array in [["brand", "brands"], ["greeting", "greetings"]]:
		if data.persona_entry(str(pair[1]), str(beats.get(str(pair[0]), ""))).is_empty():
			return false
	var gag: String = str(beats.get("gag", ""))
	return gag == "" or not data.persona_entry("gags", gag).is_empty()


static func _job_ids(data: GameData, origin_id: String) -> PackedStringArray:
	var out: PackedStringArray = []
	for j: Dictionary in data.origin(origin_id).get("jobs", []):
		out.append(str(j.get("id", "")))
	return out
