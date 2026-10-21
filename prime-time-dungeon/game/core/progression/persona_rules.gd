class_name PersonaRules extends RefCounted
## Rules of the candidate persona in the core (08 §2.3, §3.7, §4.8). Only ids go into the core (P-1): the recorded
## command — once per run, before the run begins (Game.new_game records floor → hero → persona) — and its effect
## flags["persona"]:
## - v2 (09 §8.6/§8.7, ST0; what the casting records): {"t": "persona", "v": 2, "prof", "recipe", "bias": [...]} →
##   {"v": 2, "prof", "recipe", "bias"}. `prof` is the profession of the Vorleben head start (+50, origins.json →
##   prof; "" = free pick in the Gewerke-Büro: status tiles, Allrounder:in, the canon Kai of "Rest automatisch"),
##   `recipe` the hobby recipe (the hobby's profession → its hobby_recipe in professions.json; "" = none). No origin or
##   hobby id in the command (08 D-2). The head start acts only in a season (ST1-E reads head_start).
## - v1 (K0/K1, old logs): {"t": "persona", "v": 1, "talent": "", "bias"} → {"v": 1, "bias", "swapped": false} (the
##   K1 shape bit for bit: K1 logs and saves replay and hash the same). `talent` must be "" (CR-33: no start talent).
## The persona never changes a combat value; outside a season its only effect in the core is the Marotten bias from
## floor 2 (weight_add). The dormant K0 start-talent API (offer, swap, PartyMember.origin_talent) left in 09 ST0.
## Also the offline mapping of "Anderes …" free texts to catalog ids (map_text, 08 §3.7). Static and pure (core): no
## autoloads, integer math only.

const MAX_BIAS: int = 3
const BIAS_WEIGHT_ADD: int = 1
const BIAS_MIN_FLOOR: int = 2
const VERSION: int = 2                       # the command the casting records (09 ST0)
const V1: int = 1                            # K0/K1 logs: still readable
const FLAG: String = "persona"
const MEMBER: String = "kai"                 # the persona is the candidate (party id kai)
const REASONS: PackedStringArray = ["bad_version", "unknown_talent", "bad_bias", "already_set", "run_started",
	"event_run", "unknown_prof", "unknown_recipe"]
## "Anderes …" mapping (08 §3.7 Nr. 1): ä → ae, ö → oe, ü → ue, ß → ss; other accents of the on-screen keyboard's
## accent layer fold to their base letter.
const FOLD: Dictionary = {"ä": "ae", "ö": "oe", "ü": "ue", "ß": "ss", "à": "a", "á": "a", "â": "a", "å": "a",
	"æ": "ae", "ç": "c", "č": "c", "è": "e", "é": "e", "ê": "e", "ë": "e", "ğ": "g", "ì": "i", "í": "i", "î": "i",
	"ï": "i", "ł": "l", "ñ": "n", "ò": "o", "ó": "o", "ô": "o", "ø": "o", "œ": "oe", "š": "s", "ş": "s", "ù": "u",
	"ú": "u", "û": "u", "ý": "y", "ž": "z"}


## The Marotten bias of the chosen traits (08 §3.7): their `bias` preferences (empty ones skipped), only rotating
## marotten, distinct, sorted ascending, at most MAX_BIAS.
static func bias_for(data: GameData, trait_ids: PackedStringArray) -> PackedStringArray:
	var out: PackedStringArray = []
	if data == null:
		return out
	for t: String in trait_ids:
		var b: String = str(data.trait_def(t).get("bias", ""))
		if b == "" or out.has(b) or not data.has_id("marotten", b) or not data.marotte(b).rotation:
			continue
		out.append(b)
	out.sort()
	return out.slice(0, MAX_BIAS)


## The start command of the persona `p` (v2, 09 §8.6): the head-start profession of its origin ("" for the canon Kai
## of "Rest automatisch" — PersonaText.is_canon — who picks freely), the hobby recipe of its hobby and the bias of its
## traits — ids of the catalog only, never the origin or hobby id itself (08 D-2). p == null: the canon persona.
static func command_for(data: GameData, p: PersonaProfile) -> Dictionary:
	var canon: bool = p == null or p.is_canon(data)
	var hobby: String = p.hobby if p != null else ""
	if p == null and data != null:
		hobby = str(data.persona_canon().get("hobby", ""))
	var traits: PackedStringArray = p.traits if p != null else PackedStringArray()
	return {"t": "persona", "v": VERSION, "prof": "" if canon else head_prof(data, p.origin),
		"recipe": hobby_recipe(data, hobby), "bias": Array(bias_for(data, traits))}


## 09 §8.6: the profession of the Vorleben head start (+50): origins.json → prof of `origin_id`; "" = free pick in the
## Gewerke-Büro (status tiles, Allrounder:in, an unknown origin).
static func head_prof(data: GameData, origin_id: String) -> String:
	if data == null or origin_id == "":
		return ""
	var prof: String = str(data.origin(origin_id).get("prof", ""))
	return prof if data.has_id("professions", prof) else ""


## 09 §8.6: the hobby recipe of `hobby_id`: the hobby's profession (origins.json → hobbies → prof) → its recipe with
## hobby_recipe (professions.json); "" without a hobby or without such a recipe (it then costs credits, ST1-E).
static func hobby_recipe(data: GameData, hobby_id: String) -> String:
	if data == null or hobby_id == "":
		return ""
	var prof: String = str(data.hobby(hobby_id).get("prof", ""))
	if prof == "":
		return ""
	for r: RecipeDef in data.all_recipes():
		if r.hobby_recipe and r.prof == prof:
			return r.id
	return ""


## "" or why `cmd` is refused now (08 §2.3): bad_version (neither v2 nor v1) | event_run (event runs never have a
## persona, 08 §8) | v1: unknown_talent (any non-empty talent — CR-33; also a state without kai) | v2: unknown_prof
## (not "" and not in professions.json; also a state without kai), unknown_recipe (not "" and not a hobby_recipe) |
## already_set | run_started (HeroRules.run_started) | bad_bias (0–3 distinct ascending ids of rotating marotten).
static func check(state: GameState, data: GameData, cmd: Dictionary, event_run: bool) -> String:
	var v: int = int(cmd["v"]) if _is_int(cmd.get("v", null)) else -1
	if v != VERSION and v != V1:
		return "bad_version"
	if event_run:
		return "event_run"
	var no_kai: bool = state == null or data == null or state.member(MEMBER) == null
	if v == V1 and (no_kai or str(cmd.get("talent", "")) != ""):
		return "unknown_talent"
	if v == VERSION:
		var prof: String = str(cmd.get("prof", ""))
		if no_kai or (prof != "" and not data.has_id("professions", prof)):
			return "unknown_prof"
		var recipe: String = str(cmd.get("recipe", ""))
		if recipe != "" and (not data.has_id("recipes", recipe) or not data.recipe(recipe).hobby_recipe):
			return "unknown_recipe"
	if state.flags.get(FLAG, null) != null:
		return "already_set"
	if HeroRules.run_started(state):
		return "run_started"
	return _bias_refusal(data, cmd.get("bias", []))


## Applies a valid command: flags["persona"] = {"v": 2, "prof", "recipe", "bias"} (v2) or {"v": 1, "bias",
## "swapped": false} (v1, the K1 shape; nothing reads "swapped"). No combat value changes (CR-33). false (nothing
## changes) if check() refuses.
static func apply(state: GameState, data: GameData, cmd: Dictionary) -> bool:
	if check(state, data, cmd, false) != "":
		return false
	var bias: Array = []
	for b: Variant in (cmd.get("bias", []) as Array):
		bias.append(str(b))
	if int(cmd["v"]) == V1:
		state.flags[FLAG] = {"v": V1, "bias": bias, "swapped": false}
	else:
		state.flags[FLAG] = {"v": VERSION, "prof": str(cmd.get("prof", "")), "recipe": str(cmd.get("recipe", "")),
			"bias": bias}
	return true


## 09 §8.6 (read by ST1-E): {"prof", "recipe"} of the recorded persona v2 — {"prof": "", "recipe": ""} for a v1
## persona or none.
static func head_start(state: GameState) -> Dictionary:
	var f: Variant = state.flags.get(FLAG, null) if state != null else null
	if f is Dictionary and JsonUtil.to_int((f as Dictionary).get("v", 0)) == VERSION:
		return {"prof": str((f as Dictionary).get("prof", "")), "recipe": str((f as Dictionary).get("recipe", ""))}
	return {"prof": "", "recipe": ""}


## The recorded bias of the run ([] without a persona).
static func bias(state: GameState) -> PackedStringArray:
	var out: PackedStringArray = []
	var f: Variant = state.flags.get(FLAG, null) if state != null else null
	if f is Dictionary:
		for b: Variant in ((f as Dictionary).get("bias", []) as Array):
			out.append(str(b))
	return out


## Extra draw weight of a preference in MarottenRules.announce (08 §4.8): BIAS_WEIGHT_ADD from floor BIAS_MIN_FLOOR
## for an id of the recorded bias, else 0 (floor 1 is the learning floor with the starter preferences, 06 L-2).
static func weight_add(state: GameState, marotte_id: String, floor_index: int) -> int:
	if floor_index < BIAS_MIN_FLOOR or marotte_id == "":
		return 0
	return BIAS_WEIGHT_ADD if bias(state).has(marotte_id) else 0


## Offline "Anderes …" mapping (08 §3.7) of a free text to an origin (&"job": origins.json → entries) or a hobby
## (&"hobby": → hobbies) id; "" without a hit (job: the caller takes org_allround; hobby: none). The text is normalized
## (normalize_text), every keyword is tried ("=word" = a whole word, else a part of the text, >= 4 characters); the
## LONGEST hit wins, a tie keeps the file order.
static func map_text(data: GameData, text: String, kind: StringName) -> String:
	if data == null:
		return ""
	var norm: String = normalize_text(text)
	if norm == "":
		return ""
	var padded: String = " " + norm + " "
	var entries: Array[Dictionary] = data.all_origins() if kind == &"job" else data.persona_list("hobbies")
	var best: String = ""
	var best_len: int = 0
	for d: Dictionary in entries:
		for k: String in d.get("keywords", PackedStringArray()):
			var whole: bool = k.begins_with("=")
			var w: String = k.trim_prefix("=")
			var hit: bool = padded.contains(" " + w + " ") if whole else norm.contains(w)
			if hit and w.length() > best_len:
				best = str(d.get("id", ""))
				best_len = w.length()
	return best


## Lower case, ä → ae, ö → oe, ü → ue, ß → ss (other accents to their base letter), every other character that is
## not a-z / 0-9 → a space, runs of spaces collapsed (08 §3.7 Nr. 1).
static func normalize_text(text: String) -> String:
	var out: String = ""
	var space: bool = true
	for ch: String in text.to_lower():
		for c: String in str(FOLD.get(ch, ch)):
			var u: int = c.unicode_at(0)
			if (u >= 97 and u <= 122) or (u >= 48 and u <= 57):
				out += c
				space = false
			elif not space:
				out += " "
				space = true
	return out.strip_edges()


static func _bias_refusal(data: GameData, v: Variant) -> String:
	if not (v is Array) or (v as Array).size() > MAX_BIAS:
		return "bad_bias"
	var last: String = ""
	for b: Variant in (v as Array):
		var id: String = str(b)
		if not (b is String) or id <= last or not data.has_id("marotten", id) or not data.marotte(id).rotation:
			return "bad_bias"
		last = id
	return ""


static func _is_int(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or (typeof(v) == TYPE_FLOAT and is_finite(float(v)) and float(v) == floorf(float(v)))
