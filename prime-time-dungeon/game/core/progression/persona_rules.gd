class_name PersonaRules extends RefCounted
## Rules of the candidate persona in the core (08 §2.3, §3.7, §4.8). Only ids go into the core (P-1): the recorded
## command {"t": "persona", "v": 1, "talent": "", "bias": [...]} — once per run, before the run begins (Game.new_game
## records floor → hero → persona) — and its effect flags["persona"] = {"v": 1, "bias": [...], "swapped": false}.
## CR-33 (09 §8.6): there is no start talent any more. `talent` is always "" (any other value → unknown_talent), the
## swap is gone (no_swap), the persona never changes a combat value; its only effect in the core is the Marotten
## bias from floor 2 (weight_add). The dormant K0 start-talent API (offer, swap_command, can_swap, kai.origin_talent)
## keeps its signatures until 09 ST0 removes it (09 §11.2 Nr. 2).
## Also the offline mapping of "Anderes …" free texts to catalog ids (map_text, 08 §3.7). Static and pure (core): no
## autoloads, integer math only.

const MAX_BIAS: int = 3
const BIAS_WEIGHT_ADD: int = 1
const BIAS_MIN_FLOOR: int = 2
const VERSION: int = 1
const FLAG: String = "persona"
const MEMBER: String = "kai"                 # the persona is the candidate (party id kai)
const REASONS: PackedStringArray = ["bad_version", "unknown_talent", "bad_bias", "already_set", "run_started",
	"event_run", "no_swap", "same"]
## "Anderes …" mapping (08 §3.7 Nr. 1): ä → ae, ö → oe, ü → ue, ß → ss; other accents of the on-screen keyboard's
## accent layer fold to their base letter.
const FOLD: Dictionary = {"ä": "ae", "ö": "oe", "ü": "ue", "ß": "ss", "à": "a", "á": "a", "â": "a", "å": "a",
	"æ": "ae", "ç": "c", "č": "c", "è": "e", "é": "e", "ê": "e", "ë": "e", "ğ": "g", "ì": "i", "í": "i", "î": "i",
	"ï": "i", "ł": "l", "ñ": "n", "ò": "o", "ó": "o", "ô": "o", "ø": "o", "œ": "oe", "š": "s", "ş": "s", "ù": "u",
	"ú": "u", "û": "u", "ý": "y", "ž": "z"}


## Dormant since CR-33 (start talents are gone): always [].
static func offer(_data: GameData, _origin_id: String, _hobby_id: String) -> PackedStringArray:
	return PackedStringArray()


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


## The start command: K1 always passes talent_id "" (CR-33).
static func command_for(data: GameData, talent_id: String, trait_ids: PackedStringArray) -> Dictionary:
	return {"t": "persona", "v": VERSION, "talent": talent_id, "bias": Array(bias_for(data, trait_ids))}


## Dormant since CR-33 (the swap is gone): the K0 command shape, refused by check (no_swap).
static func swap_command(talent_id: String) -> Dictionary:
	return {"t": "persona", "v": VERSION, "talent": talent_id, "swap": true}


## "" or why `cmd` is refused now (08 §2.3): bad_version | event_run (event runs never have a persona, 08 §8) |
## unknown_talent (any non-empty talent — CR-33; also a state without kai) | no_swap (the swap is gone) | already_set |
## run_started (HeroRules.run_started) | bad_bias (0–3 distinct ascending ids of rotating marotten).
static func check(state: GameState, data: GameData, cmd: Dictionary, event_run: bool) -> String:
	if not _is_int(cmd.get("v", null)) or int(cmd["v"]) != VERSION:
		return "bad_version"
	if event_run:
		return "event_run"
	if state == null or data == null or state.member(MEMBER) == null or str(cmd.get("talent", "")) != "":
		return "unknown_talent"
	if cmd.has("swap"):
		return "no_swap"
	if state.flags.get(FLAG, null) != null:
		return "already_set"
	if HeroRules.run_started(state):
		return "run_started"
	return _bias_refusal(data, cmd.get("bias", []))


## Applies a valid command: flags["persona"] = {"v", "bias", "swapped": false}. No combat value changes (CR-33).
## false (nothing changes) if check() refuses.
static func apply(state: GameState, data: GameData, cmd: Dictionary) -> bool:
	if check(state, data, cmd, false) != "":
		return false
	var bias: Array = []
	for b: Variant in (cmd.get("bias", []) as Array):
		bias.append(str(b))
	state.flags[FLAG] = {"v": VERSION, "bias": bias, "swapped": false}
	return true


## Dormant since CR-33: the swap is gone — always false.
static func can_swap(_state: GameState) -> bool:
	return false


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
