# STUB(K0) — owned by 08-K1. Replace completely, keep the public API.
class_name PersonaProfile extends RefCounted
## The candidate's local presentation data (08 §2.2): name, word form, origin, occupation, hobby, traits, look, talent
## offer, story beats, AI lines. Never part of GameState, never recorded, never synced; stored per slot in
## user://persona/slot_N.json (Save.persona_path). K0: fields + canon + a plain file round trip; K1 adds the catalog
## checks (unknown ids → canon, filters, fill_unset rules).

const FORMAT: String = "ptd_persona"
const VERSION: int = 1
const FORMS: PackedStringArray = ["f", "m", "n"]
const SOURCES: PackedStringArray = ["canon", "offline", "ai"]

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


## The canon persona ("Rest automatisch" without input, old saves, bots): origins.json → canon.
static func canon(data: GameData) -> PersonaProfile:
	var p: PersonaProfile = PersonaProfile.new()
	var c: Dictionary = data.persona_canon() if data != null else {}
	p.name = str(c.get("name", GameState.DEFAULT_NAME))
	p.form = str(c.get("form", "n"))
	p.origin = str(c.get("origin", ""))
	p.occupation = str(c.get("occupation", ""))
	p.hobby = str(c.get("hobby", ""))
	p.traits = JsonUtil.to_str_array(c.get("traits", []))
	p.talent = str(c.get("talent", ""))
	p.source = "canon"
	return p


## A persona file dictionary (08 §2.2); another format or a higher "v" → the canon persona (warning).
static func from_dict(d: Dictionary, data: GameData) -> PersonaProfile:
	if str(d.get("format", "")) != FORMAT or JsonUtil.to_int(d.get("v", 0)) != VERSION:
		push_warning("PersonaProfile: unknown persona file format/version → canon")
		return canon(data)
	var p: PersonaProfile = PersonaProfile.new()
	p.name = str(d.get("name", GameState.DEFAULT_NAME))
	p.form = str(d.get("form", "n")) if FORMS.has(str(d.get("form", "n"))) else "n"
	p.origin = str(d.get("origin", ""))
	p.occupation = str(d.get("occupation", ""))
	p.job_text = str(d.get("job_text", ""))
	p.hobby = str(d.get("hobby", ""))
	p.hobby_text = str(d.get("hobby_text", ""))
	p.traits = JsonUtil.to_str_array(d.get("traits", []))
	p.look = (d.get("look", {}) as Dictionary).duplicate(true) if d.get("look", {}) is Dictionary else {}
	p.talent = str(d.get("talent", ""))
	p.offer = JsonUtil.to_str_array(d.get("offer", []))
	p.beats = (d.get("beats", {}) as Dictionary).duplicate(true) if d.get("beats", {}) is Dictionary else {}
	p.ai = (d.get("ai", {}) as Dictionary).duplicate(true) if d.get("ai", {}) is Dictionary else {}
	p.source = str(d.get("source", "offline")) if SOURCES.has(str(d.get("source", ""))) else "offline"
	return p


## The persona file (08 §2.2).
func to_dict() -> Dictionary:
	return {"format": FORMAT, "v": VERSION, "name": name, "form": form, "origin": origin, "occupation": occupation,
		"job_text": job_text, "hobby": hobby, "hobby_text": hobby_text, "traits": Array(traits),
		"look": look.duplicate(true), "talent": talent, "offer": Array(offer), "beats": beats.duplicate(true),
		"ai": ai.duplicate(true), "source": source}


## "Rest automatisch": every field not in `set_fields` gets its canon value. Stub: name / origin / hobby / talent.
func fill_unset(data: GameData, set_fields: PackedStringArray) -> void:
	var c: PersonaProfile = canon(data)
	for f: String in ["name", "form", "origin", "occupation", "hobby", "talent"]:
		if not set_fields.has(f):
			set(f, c.get(f))


## Problems against the catalog (unknown ids, lengths, filters). Stub: [].
func validate(_data: GameData) -> PackedStringArray:
	return PackedStringArray()
