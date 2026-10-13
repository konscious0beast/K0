extends RefCounted
## The review matrix of the persona lines (08 §4.4 R9, K1; private helper of tests/tools/persona_matrix.gd and
## test_08_persona_lines, no class_name): every persona_* line of data/mod_lines.json rendered for every Vorleben ×
## f / m / n (the role form, a hobby and a trait that rotate with the Vorleben, so every hobby and trait appears), the
## free-text intro (persona_intro:custom) with every sample text of tests/fixtures/persona/job_texts.json. Identical
## renderings of one line are listed once. CSV (comma, RFC 4180 quoting) with an empty "review" column for the humor
## editors (grammar, tone, H-1 … H-7).

const LINES: String = "res://data/mod_lines.json"
const JOB_TEXTS: String = "res://tests/fixtures/persona/job_texts.json"
const HEADER: PackedStringArray = ["id", "tag", "voice", "origin", "form", "hobby", "free_text", "line", "review"]
const NAMES: Dictionary = {"f": "Jana", "m": "Mika", "n": "Kim"}
const CUSTOM_TAG: String = "persona_intro:custom"


## Rows (without the header): [id, tag, voice, origin, form, hobby, free_text, rendered line, ""].
static func build(data: GameData) -> Array[PackedStringArray]:
	var out: Array[PackedStringArray] = []
	var lines: Array = persona_lines()
	var personas: Array[PersonaProfile] = sample_personas(data)
	var free_texts: PackedStringArray = sample_free_texts()
	for l: Variant in lines:
		var d: Dictionary = l
		var seen: Dictionary = {}
		var tag: String = str(d.get("tag", ""))
		if tag == CUSTOM_TAG:
			for t: String in free_texts:
				var p: PersonaProfile = PersonaProfile.canon(data)
				p.name = NAMES["n"]
				p.origin = PersonaProfile.ALLROUND
				p.occupation = ""
				p.job_text = t
				p.make_beats(data, null)
				_add(out, seen, d, p, data, t)
			continue
		for p: PersonaProfile in personas:
			_add(out, seen, d, p, data, "")
	return out


## The persona_* entries of mod_lines.json (file order).
static func persona_lines() -> Array:
	var out: Array = []
	var raw: Variant = JsonUtil.read_file(LINES)
	if raw is Dictionary:
		for e: Variant in ((raw as Dictionary).get("entries", []) as Array):
			if e is Dictionary and str((e as Dictionary).get("tag", "")).begins_with("persona_"):
				out.append(e)
	return out


## One persona per Vorleben (catalog order, without org_allround's free text) × form; hobby and trait rotate.
static func sample_personas(data: GameData) -> Array[PersonaProfile]:
	var out: Array[PersonaProfile] = []
	var hobbies: Array[Dictionary] = data.persona_list("hobbies")
	var traits: Array[Dictionary] = data.persona_list("traits")
	var i: int = 0
	for o: Dictionary in data.all_origins():
		for f: String in PersonaProfile.FORMS:
			var p: PersonaProfile = PersonaProfile.canon(data)
			p.name = str(NAMES[f])
			p.form = f
			p.origin = str(o["id"])
			p.occupation = ""
			p.hobby = str(hobbies[i % hobbies.size()]["id"]) if not hobbies.is_empty() else ""
			p.traits = PackedStringArray([str(traits[i % traits.size()]["id"])]) if not traits.is_empty() \
				else PackedStringArray()
			p.source = "offline"
			p.make_beats(data, null)
			out.append(p)
			i += 1
	return out


## The "Anderes …" sample texts (jobs of job_texts.json).
static func sample_free_texts() -> PackedStringArray:
	var out: PackedStringArray = []
	var raw: Variant = JsonUtil.read_file(JOB_TEXTS)
	if raw is Dictionary:
		for e: Variant in ((raw as Dictionary).get("jobs", []) as Array):
			var t: String = str((e as Dictionary).get("text", "")) if e is Dictionary else str(e)
			if t != "" and not out.has(t):
				out.append(t)
	return out


## The line of `d` filled with the persona's placeholders (the forms of PersonaText.ctx; {name} the sample name,
## {floor} 1). Unknown placeholders stay visible — the matrix shows them.
static func render(d: Dictionary, p: PersonaProfile, data: GameData) -> String:
	var ctx: Dictionary = PersonaText.ctx(p, data, null)
	ctx["name"] = p.name
	ctx["floor"] = 1
	return str(d.get("text", "")).format(ctx)


static func to_csv(rows: Array[PackedStringArray]) -> String:
	var out: PackedStringArray = [_csv_row(HEADER)]
	for r: PackedStringArray in rows:
		out.append(_csv_row(r))
	return "\n".join(out) + "\n"


## Writes the CSV; OK or the file error.
static func write(path: String, data: GameData) -> Error:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(to_csv(build(data)))
	f.close()
	return OK


static func _add(out: Array[PackedStringArray], seen: Dictionary, d: Dictionary, p: PersonaProfile, data: GameData,
		free_text: String) -> void:
	var text: String = render(d, p, data)
	if seen.has(text):
		return
	seen[text] = true
	out.append(PackedStringArray([str(d.get("id", "")), str(d.get("tag", "")), str(d.get("voice", "mod")), p.origin,
		p.form, p.hobby, free_text, text, ""]))


static func _csv_row(cells: PackedStringArray) -> String:
	var q: PackedStringArray = []
	for c: String in cells:
		if c.contains(",") or c.contains("\"") or c.contains("\n"):
			q.append("\"" + c.replace("\"", "\"\"") + "\"")
		else:
			q.append(c)
	return ",".join(q)
