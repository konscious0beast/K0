extends RefCounted
## Validation of data/origins.json (08 §3.8, §3.9): the origin tiles (entries: the Vorleben catalog) and the lists
## hobbies, traits, rivals, brands, gags, greetings, plans and the canon persona — plus, until 09 ST0, the dormant K0
## start talents (`talents`, only the test fixtures still carry them; CR-33). Private helper of DataValidator (no
## class_name; preloaded as OriginsCheck). Schema (normalize / read_extras), id patterns and uniqueness (K0) and the
## content rules of 08 §3.9 (K1): text lengths and word lists, `prof` (the Vorleben head start of 09 §8.6 as plain data;
## the reference check against professions.json comes with 09 ST0), references, keywords, icons, broadcast plans and
## the canon persona. Counts are the real catalog's business (test_08_origins_data) — fixtures may carry fewer entries.

const TalentsRules := preload("res://core/data/validators/talents.gd")
const IpWords := preload("res://core/data/validators/ip_words.gd")

const SPEC: Array = [["id", "s"], ["name", "s"], ["icon", "s", ""], ["status", "b", false], ["role", "d", {}],
	["jobs", "a", []], ["keywords", "sa", []], ["talent", "s", ""], ["alt", "s", ""], ["prof", "s", ""],
	["spec_hint", "s", ""], ["flavor", "s", ""], ["mod_tags", "sa", []], ["rivals", "sa", []], ["brand", "s", ""]]
## Start talents (dormant since CR-33, fixtures only): the talents.json fields without for / max_rank / weight /
## min_level (implicitly kai / 1 / 1 / 1).
const SPEC_TALENT: Array = [["id", "s"], ["name", "s"], ["desc", "s", ""], ["icon", "s"], ["effects", "a"]]
const SPEC_JOB: Array = [["id", "s"], ["n", "s"], ["f", "s", ""], ["m", "s", ""]]
## list → [spec, id pattern kind of DataValidator.ID_PATTERNS]
const LISTS: Dictionary = {
	"hobbies": [[["id", "s"], ["name", "s"], ["icon", "s", ""], ["keywords", "sa", []], ["talent", "s", ""],
		["prof", "s", ""], ["title", "s", ""], ["desc", "s", ""], ["club", "d", {}], ["gag", "s", ""],
		["greeting", "s", ""]], "hobbies"],
	"traits": [[["id", "s"], ["name", "s"], ["bias", "s", ""]], "traits"],
	"rivals": [[["id", "s"], ["name", "s"]], "rivals"],
	"brands": [[["id", "s"], ["name", "s"]], "brands"],
	"gags": [[["id", "s"], ["name", "s"]], "gags"],
	"greetings": [[["id", "s"]], "greetings"],
	"plans": [[["id", "s"], ["slots", "a", []]], "plans"],
}
const SPEC_CANON: Array = [["name", "s"], ["form", "s", "n"], ["origin", "s"], ["occupation", "s", ""],
	["hobby", "s", ""], ["traits", "sa", []], ["talent", "s", ""]]

# --- K1 content rules (08 §3.9) ---------------------------------------------------------------------------------------
const NAME_MAX: int = 28                    # tile name (Vorleben / hobby)
const FLAVOR_MAX: int = 90
const FORM_MAX: int = 24                    # role / job forms, club.text
const TRAIT_MAX: int = 16
const LABEL_MAX: int = 24                   # rival / brand / gag names
const PERSONA_NAME_MAX: int = 12            # == TitleFlow.clean_name
const FORMS: PackedStringArray = ["n", "f", "m"]
const CLUB_GENDERS: PackedStringArray = ["f", "m", "n"]
const ALLROUND: String = "org_allround"     # the catch-all origin of "Anderes …" without a match (no tile)
const SPEC_HINT_PREFIX: String = "cls_kai_"
const PROF_RE: String = "^prf_[a-z0-9_]+$"  # 09 §8.5 profession ids (professions.json from 09 ST0)
## Keywords after normalization (08 §3.7): lower-case ASCII words, "=" = whole word, else a part (>= 4 characters);
## a part may span words ("3d druck").
const KEYWORD_RE: String = "^=?[a-z0-9]+( [a-z0-9]+)*$"
const KEYWORD_PART_MIN: int = 4
## Copy of UiIcon.KINDS (scenes/ui/ui_icon.gd, R3) — core/data must not depend on scenes (02_TECH §0.4);
## test_08_origins_data checks that it stays a subset.
const ICON_KINDS: PackedStringArray = ["dot", "eye", "heart", "menu", "hand", "fist", "map", "gear", "box", "star",
	"coin", "clock", "skull", "crown", "check", "cross", "arrow_left", "arrow_right", "arrow_up", "arrow_down",
	"diamond", "key", "floppy", "door", "paw", "person", "chat", "bolt", "flame", "snow", "bubble", "trophy", "gift",
	"play", "pause", "stairs", "vending", "sword", "shield", "ring", "potion", "camera", "mic", "tv", "drone", "bark",
	"swap"]
## Broadcast plans (08 §3.8, §4.7): hooks (+ "summary": the Etagen-Bilanz subtitle of the floor, 08 §4.2) and slots.
const PLAN_HOOKS: PackedStringArray = ["intro", "first_chest", "boss_won", "safe_room", "floor_end", "game_over",
	"floor_start", "summary"]
const PLAN_SLOTS: PackedStringArray = ["card", "line", "rival:intro", "rival:result", "rival:taunt", "greeting",
	"sponsor:intro", "sponsor:thanks", "gag:1", "gag:2", "gag:3", "marotte"]
const PLAN_SLOT_KEYS: PackedStringArray = ["floor", "hook", "n", "slot", "every", "else"]
## The word lists every catalog text is checked against (06 D, the live filter's lists: politics, sexual, slurs,
## violence, real brands, IP distance, origin).
const FILTER_PATH: String = "res://data/mod_filter.json"

static var _filter: Dictionary = {}


## One origin tile ({} if not an object).
static func normalize(v: DataValidator, ctx: String, raw: Variant) -> Dictionary:
	var d: Dictionary = v._norm(ctx, raw, SPEC)
	if d.is_empty():
		return d
	var jobs: Array[Dictionary] = []
	var raw_jobs: Array = d["jobs"]
	for i in raw_jobs.size():
		var j: Dictionary = v._norm("%s.jobs[%d]" % [ctx, i], raw_jobs[i], SPEC_JOB)
		if not j.is_empty():
			for k: String in ["f", "m"]:            # a job without f / m forms uses its neutral form
				if str(j[k]) == "":
					j[k] = j["n"]
			jobs.append(j)
	d["jobs"] = jobs
	return d


## The extra top-level keys of origins.json → v._out["origin_extras"] = {"talents": [...], <list>: [...],
## "canon": {...}} (normalized).
static func read_extras(v: DataValidator, f: Dictionary) -> void:
	var out: Dictionary = {}
	var talents: Array[Dictionary] = []
	var raw_t: Variant = f.get("talents", [])
	if not (raw_t is Array):
		v._err("origins.talents", "must be an array")
		raw_t = []
	for i in (raw_t as Array).size():
		var t: Dictionary = _talent(v, v._ctx("origins.talents", i, (raw_t as Array)[i]), (raw_t as Array)[i])
		if not t.is_empty():
			talents.append(t)
	out["talents"] = talents
	for list: String in LISTS.keys():
		var entries: Array[Dictionary] = []
		var raw_l: Variant = f.get(list, [])
		if not (raw_l is Array):
			v._err("origins." + list, "must be an array")
			raw_l = []
		for i in (raw_l as Array).size():
			var e: Dictionary = v._norm(v._ctx("origins." + list, i, (raw_l as Array)[i]), (raw_l as Array)[i],
				LISTS[list][0])
			if not e.is_empty():
				entries.append(e)
		out[list] = entries
	out["canon"] = v._norm("origins.canon", f.get("canon", {}), SPEC_CANON) if f.has("canon") else {}
	v._out["origin_extras"] = out


## Id patterns and uniqueness (start talents never share an id with talents.json) and the K1 content rules.
static func check(v: DataValidator) -> void:
	var extras: Dictionary = v._out.get("origin_extras", {})
	var pool: Dictionary = {}
	for t: Dictionary in v._out.get("talents", []):
		pool[str(t["id"])] = true
	_ids(v, "origins.talents", extras.get("talents", []), "origin_talents", pool)
	for list: String in LISTS.keys():
		_ids(v, "origins." + list, extras.get(list, []), str(LISTS[list][1]), {})
	var occupations: Dictionary = {}
	for o: Dictionary in v._out.get("origins", []):
		for j: Dictionary in o.get("jobs", []):
			var jid: String = str(j["id"])
			if not v._matches(str(DataValidator.ID_PATTERNS["occupations"]), jid):
				v._err("origins[%s].jobs.%s" % [str(o["id"]), jid], "invalid occupation id")
			if occupations.has(jid):
				v._err("origins[%s].jobs.%s" % [str(o["id"]), jid], "duplicate occupation id")
			occupations[jid] = true
	if (v._out.get("origins", []) as Array).is_empty() and (extras.get("canon", {}) as Dictionary).is_empty():
		return                                   # a data set without origins.json
	var ids: Dictionary = _id_sets(v, extras)
	_check_entries(v, ids)
	_check_hobbies(v, ids)
	_check_lists(v, extras, ids)
	_check_plans(v, extras.get("plans", []))
	_check_canon(v, extras.get("canon", {}), ids)
	_check_keywords(v, "origins", v._out.get("origins", []))
	_check_keywords(v, "origins.hobbies", extras.get("hobbies", []))


# --- K1 rules ------------------------------------------------------------------------------------------------------

## {list → {id → entry}} of every persona list, plus "origins", "talents", "classes", "marotten".
static func _id_sets(v: DataValidator, extras: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for list: String in LISTS.keys():
		out[list] = _by_id(extras.get(list, []))
	out["origins"] = _by_id(v._out.get("origins", []))
	out["talents"] = _by_id(extras.get("talents", []))
	out["classes"] = _by_id(v._out.get("classes", []))
	out["marotten"] = _by_id(v._out.get("marotten", []))
	return out


static func _by_id(list: Array) -> Dictionary:
	var out: Dictionary = {}
	for e: Variant in list:
		if e is Dictionary:
			out[str((e as Dictionary).get("id", ""))] = e
	return out


static func _check_entries(v: DataValidator, ids: Dictionary) -> void:
	for o: Dictionary in v._out.get("origins", []):
		var ctx: String = "origins[%s]" % str(o["id"])
		var status: bool = bool(o["status"])
		_text(v, ctx + ".name", str(o["name"]), NAME_MAX)
		_text(v, ctx + ".flavor", str(o["flavor"]), FLAVOR_MAX)
		_icon(v, ctx + ".icon", str(o["icon"]))
		var forms: Dictionary = _forms(v, ctx + ".role", o["role"])
		if status and not forms.is_empty() and (str(forms["f"]) != str(forms["n"]) or str(forms["m"]) != str(forms["n"])):
			v._err(ctx + ".role", "a status tile has one form for all (08 §3.2)")
		for j: Dictionary in o["jobs"]:
			for k: String in FORMS:
				_text(v, "%s.jobs.%s.%s" % [ctx, str(j["id"]), k], str(j[k]), FORM_MAX)
		var prof: String = str(o["prof"])
		var free_pick: bool = status or str(o["id"]) == ALLROUND
		if free_pick and prof != "":
			v._err(ctx + ".prof", "status tiles and %s pick the profession freely (\"\", 09 §8.6)" % ALLROUND)
		elif not free_pick and not v._matches(PROF_RE, prof):
			v._err(ctx + ".prof", "needs a profession id prf_* (09 §8.6), got '%s'" % prof)
		var hint: String = str(o["spec_hint"])
		if not hint.begins_with(SPEC_HINT_PREFIX) or not (ids["classes"] as Dictionary).has(hint):
			v._err(ctx + ".spec_hint", "needs a Kai class %s* (classes.json), got '%s'" % [SPEC_HINT_PREFIX, hint])
		var rivals: PackedStringArray = o["rivals"]
		if rivals.size() != 2 or (rivals.size() == 2 and rivals[0] == rivals[1]):
			v._err(ctx + ".rivals", "needs exactly two different rivals (08 §4.6)")
		for r: String in rivals:
			_ref(v, ctx + ".rivals", r, ids["rivals"], "rival")
		_ref(v, ctx + ".brand", str(o["brand"]), ids["brands"], "brand")
		var talent: String = str(o["talent"])          # dormant K0 start talent (fixtures only, CR-33)
		if talent != "" and not (ids["talents"] as Dictionary).has(talent):
			v._err(ctx + ".talent", "unknown start talent '%s'" % talent)
		for t: String in o["mod_tags"]:
			if t == "" or t.length() > FORM_MAX:
				v._err(ctx + ".mod_tags", "tags are 1..%d characters" % FORM_MAX)


static func _check_hobbies(v: DataValidator, ids: Dictionary) -> void:
	for h: Dictionary in (ids["hobbies"] as Dictionary).values():
		var ctx: String = "origins.hobbies[%s]" % str(h["id"])
		_text(v, ctx + ".name", str(h["name"]), NAME_MAX)
		_icon(v, ctx + ".icon", str(h["icon"]))
		if not v._matches(PROF_RE, str(h["prof"])):
			v._err(ctx + ".prof", "every hobby gives a recipe of a profession prf_* (09 §8.6), got '%s'" %
				str(h["prof"]))
		var club: Dictionary = h["club"]
		if not (club.get("text", null) is String) or str(club.get("text", "")) == "":
			v._err(ctx + ".club.text", "needs the club noun (\"Kochkurs\", 08 §3.5)")
		else:
			_text(v, ctx + ".club.text", str(club["text"]), FORM_MAX)
		if not CLUB_GENDERS.has(str(club.get("g", ""))):
			v._err(ctx + ".club.g", "must be f | m | n (the possessive Ihr / Ihre)")
		for k: Variant in club.keys():
			if not ["text", "g"].has(str(k)):
				v._err(ctx + ".club." + str(k), "unknown key")
		_ref(v, ctx + ".gag", str(h["gag"]), ids["gags"], "gag")
		_ref(v, ctx + ".greeting", str(h["greeting"]), ids["greetings"], "greeting")
		var talent: String = str(h["talent"])
		if talent != "" and not (ids["talents"] as Dictionary).has(talent):
			v._err(ctx + ".talent", "unknown start talent '%s'" % talent)


static func _check_lists(v: DataValidator, extras: Dictionary, ids: Dictionary) -> void:
	for t: Dictionary in extras.get("traits", []):
		var ctx: String = "origins.traits[%s]" % str(t["id"])
		_text(v, ctx + ".name", str(t["name"]), TRAIT_MAX)
		var bias: String = str(t["bias"])
		if bias != "":
			var m: Variant = (ids["marotten"] as Dictionary).get(bias, null)
			if not (m is Dictionary) or not bool((m as Dictionary).get("rotation", false)):
				v._err(ctx + ".bias", "'%s' is no rotating preference of marotten.json (08 §4.8)" % bias)
	for list: String in ["rivals", "brands", "gags"]:
		for e: Dictionary in extras.get(list, []):
			_text(v, "origins.%s[%s].name" % [list, str(e["id"])], str(e["name"]), LABEL_MAX)


static func _check_plans(v: DataValidator, plans: Array) -> void:
	for p: Dictionary in plans:
		var ctx: String = "origins.plans[%s]" % str(p["id"])
		var slots: Array = p["slots"]
		if slots.is_empty():
			v._err(ctx + ".slots", "a plan needs slots")
		for i in slots.size():
			var sctx: String = "%s.slots[%d]" % [ctx, i]
			var s: Variant = slots[i]
			if not (s is Dictionary):
				v._err(sctx, "expected object")
				continue
			var d: Dictionary = s
			for k: Variant in d.keys():
				if not PLAN_SLOT_KEYS.has(str(k)):
					v._err(sctx + "." + str(k), "unknown key")
			for k: String in ["floor", "n"]:
				if not JsonUtil.is_integral(d.get(k, null)) or int(d.get(k, -1)) < 0:
					v._err(sctx + "." + k, "must be an integer >= 0")
			if not PLAN_HOOKS.has(str(d.get("hook", ""))):
				v._err(sctx + ".hook", "must be one of %s" % ", ".join(PLAN_HOOKS))
			if not PLAN_SLOTS.has(str(d.get("slot", ""))):
				v._err(sctx + ".slot", "must be one of %s" % ", ".join(PLAN_SLOTS))
			if d.has("every") or d.has("else"):
				if not JsonUtil.is_integral(d.get("every", null)) or int(d.get("every", 0)) < 2:
					v._err(sctx + ".every", "must be an integer >= 2")
				if not PLAN_SLOTS.has(str(d.get("else", ""))):
					v._err(sctx + ".else", "must be a slot (%s)" % ", ".join(PLAN_SLOTS))


static func _check_canon(v: DataValidator, c: Dictionary, ids: Dictionary) -> void:
	if c.is_empty():
		v._err("origins.canon", "missing the canon persona (08 §3.6)")
		return
	var name: String = str(c["name"])
	if name == "" or name.length() > PERSONA_NAME_MAX:
		v._err("origins.canon.name", "1..%d characters" % PERSONA_NAME_MAX)
	if not FORMS.has(str(c["form"])):
		v._err("origins.canon.form", "must be n | f | m")
	var origin: Variant = (ids["origins"] as Dictionary).get(str(c["origin"]), null)
	if not (origin is Dictionary):
		v._err("origins.canon.origin", "unknown origin '%s'" % str(c["origin"]))
	elif str(c["occupation"]) != "":
		var found: bool = false
		for j: Dictionary in (origin as Dictionary)["jobs"]:
			found = found or str(j["id"]) == str(c["occupation"])
		if not found:
			v._err("origins.canon.occupation", "'%s' is no job of %s" % [str(c["occupation"]), str(c["origin"])])
	if str(c["hobby"]) != "":
		_ref(v, "origins.canon.hobby", str(c["hobby"]), ids["hobbies"], "hobby")
	var traits: PackedStringArray = c["traits"]
	if traits.size() > 3:
		v._err("origins.canon.traits", "at most 3 traits")
	for t: String in traits:
		_ref(v, "origins.canon.traits", t, ids["traits"], "trait")
	var talent: String = str(c["talent"])
	if talent != "" and not (ids["talents"] as Dictionary).has(talent):
		v._err("origins.canon.talent", "unknown start talent '%s'" % talent)


## Lower-case ASCII, parts >= 4 characters, whole words with "=", never the same keyword in two entries of one list.
static func _check_keywords(v: DataValidator, ctx: String, entries: Array) -> void:
	var seen: Dictionary = {}
	for e: Variant in entries:
		var d: Dictionary = e
		var id: String = str(d.get("id", ""))
		for k: String in d.get("keywords", PackedStringArray()):
			var kctx: String = "%s[%s].keywords" % [ctx, id]
			if not v._matches(KEYWORD_RE, k):
				v._err(kctx, "'%s' must be lower-case ASCII (normalized: ä → ae, ß → ss)" % k)
			elif not k.begins_with("=") and k.length() < KEYWORD_PART_MIN:
				v._err(kctx, "'%s': a part keyword needs >= %d characters (whole words: \"=%s\")" % [k,
					KEYWORD_PART_MIN, k])
			if seen.has(k):
				v._err(kctx, "'%s' is also a keyword of %s" % [k, str(seen[k])])
			seen[k] = id


static func _forms(v: DataValidator, ctx: String, raw: Variant) -> Dictionary:
	if not (raw is Dictionary):
		v._err(ctx, "expected {n, f, m}")
		return {}
	var d: Dictionary = raw
	var out: Dictionary = {}
	for k: Variant in d.keys():
		if not FORMS.has(str(k)):
			v._err(ctx + "." + str(k), "unknown key")
	for k: String in FORMS:
		var s: Variant = d.get(k, null)
		if not (s is String) or str(s) == "":
			v._err(ctx + "." + k, "missing form '%s'" % k)
			continue
		_text(v, ctx + "." + k, str(s), FORM_MAX)
		out[k] = str(s)
	return out if out.size() == FORMS.size() else {}


static func _icon(v: DataValidator, ctx: String, icon: String) -> void:
	if icon != "" and not ICON_KINDS.has(icon):
		v._err(ctx, "unknown icon '%s' (UiIcon.KINDS or \"\")" % icon)


static func _ref(v: DataValidator, ctx: String, id: String, known: Dictionary, what: String) -> void:
	if not known.has(id):
		v._err(ctx, "unknown %s '%s'" % [what, id])


## Length, the foot words of talents.gd, the IP / tone lists of ip_words.gd and the live filter's blocked lists.
static func _text(v: DataValidator, ctx: String, text: String, max_len: int) -> void:
	if text == "":
		v._err(ctx, "must not be empty")
		return
	TalentsRules.check_text(v, ctx, text, max_len)
	var ip: String = IpWords.general_word(text)
	if ip != "":
		v._err(ctx, "contains '%s' (IP / tone word list)" % ip)
	var hit: String = blocked_hit(text)
	if hit != "":
		v._err(ctx, "contains a blocked word (%s, data/mod_filter.json)" % hit)


## The first blocked category ("politics", "real_brands", …) of mod_filter.json → blocked that `text` hits ("" = none).
## Same word semantics as ModLineFilter: lower-case words joined by hyphens (also checked per part); an entry "x*" =
## prefix, "*x" = suffix, "*x*" = part of a word, "a b" = a phrase of whole words.
static func blocked_hit(text: String) -> String:
	if _filter.is_empty():
		var raw: Variant = JsonUtil.read_file(FILTER_PATH)
		_filter = (raw as Dictionary).get("blocked", {}) if raw is Dictionary else {}
		if _filter.is_empty():
			_filter = {"_": []}
	var tokens: PackedStringArray = words(text)
	var parts: PackedStringArray = tokens.duplicate()
	for t: String in tokens:
		if t.contains("-"):
			parts.append_array(t.split("-", false))
	var joined: String = " " + " ".join(tokens) + " "
	for cat: Variant in _filter.keys():
		var list: Variant = _filter[cat]
		if not (list is Array):
			continue
		for entry: Variant in (list as Array):
			var w: String = str(entry).to_lower()
			if w.contains(" "):
				if joined.contains(" " + w + " "):
					return str(cat)
			elif word_hit(parts, w):
				return str(cat)
	return ""


## Lower-case words (runs of letters and digits, inner hyphens kept) of `text`.
static func words(text: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var cur: String = ""
	for ch: String in text.to_lower():
		var c: int = ch.unicode_at(0)
		var letter: bool = (c >= 97 and c <= 122) or (c >= 48 and c <= 57) or c >= 0xC0
		if letter or (ch == "-" and cur != ""):
			cur += ch
		else:
			if cur.trim_suffix("-") != "":
				out.append(cur.trim_suffix("-"))
			cur = ""
	if cur.trim_suffix("-") != "":
		out.append(cur.trim_suffix("-"))
	return out


## One word-list entry against the words: "x*" prefix, "*x" suffix, "*x*" part, else the whole word.
static func word_hit(tokens: PackedStringArray, entry: String) -> bool:
	var pre: bool = entry.ends_with("*")
	var suf: bool = entry.begins_with("*")
	var core: String = entry.trim_prefix("*").trim_suffix("*")
	if core == "":
		return false
	for t: String in tokens:
		if pre and suf:
			if t.contains(core):
				return true
		elif pre:
			if t.begins_with(core):
				return true
		elif suf:
			if t.ends_with(core):
				return true
		elif t == core:
			return true
	return false


static func _talent(v: DataValidator, ctx: String, raw: Variant) -> Dictionary:
	var d: Dictionary = v._norm(ctx, raw, SPEC_TALENT)
	if d.is_empty():
		return d
	var effects: Array[Dictionary] = []
	var raw_e: Array = d["effects"]
	for i in raw_e.size():
		var e: Dictionary = TalentsRules.normalize_effect(v, "%s.effects[%d]" % [ctx, i], raw_e[i])
		if not e.is_empty():
			effects.append(e)
	d["effects"] = effects
	d["for"] = PackedStringArray(["kai"])
	d["max_rank"] = 1
	d["weight"] = 1
	d["min_level"] = 1
	return d


static func _ids(v: DataValidator, ctx: String, entries: Array, kind: String, taken: Dictionary) -> void:
	var seen: Dictionary = {}
	for e: Variant in entries:
		var id: String = str((e as Dictionary).get("id", ""))
		if not v._matches(str(DataValidator.ID_PATTERNS[kind]), id):
			v._err("%s.%s" % [ctx, id], "invalid id (pattern %s)" % str(DataValidator.ID_PATTERNS[kind]))
		if seen.has(id) or taken.has(id):
			v._err("%s.%s" % [ctx, id], "duplicate id")
		seen[id] = true
