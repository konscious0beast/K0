extends RefCounted
## Private helper of DataValidator (02_TECH §0.3; 06 §8.0 Nr. 7 style — one file per rule set, called from
## DataValidator, no class_name): IP-distance and tone word lists for every written player-facing text of the data
## (04 §2.3 Distanz-Review, 06 §0.3 and the orchestrator decisions of the polish pass, 2026-10-10):
##   · every text: no "Fan-Box" (the box is the „Fanpost-Paket“, id box_fan), no "Feinripp" (the Liga is a play style,
##     never underwear), no barefoot / shoe words, no real nationality or ethnic group (a curated list, whole words —
##     the show is set in a fictional galaxy, an origin is never a punchline);
##   · texts for, by or about Graf Mopsula: no royalty motif (Majestät, Durchlaucht, Hoheit, Thron, Krone) — he is a
##     count and a scholar, not a king. Mopsula's texts: lines in his voice, every scene name, his skills (attack,
##     stunts, the rt bar), equipment he can wear, classes / talents / species for him, his party entry and every text
##     that names him ("Graf", "Grafen", "Mopsula", "Mops" as whole words).
## Texts = the fields "name", "desc", "text", "title" and "slogan" at any depth of the normalized tables (mod lines,
## scene lines, floors with their zones and safe rooms included). Substrings are checked case-insensitively; the origin
## list as whole words. The Rattenkönigin keeps her title and crown — only Mopsula's texts are checked for royalty.

const TEXT_KEYS: PackedStringArray = ["name", "desc", "text", "title", "slogan"]
## Every player-facing text (lower-case substrings; the live line filter blocks them too: mod_filter.json →
## blocked.ip_distance).
const ALL_WORDS: PackedStringArray = ["fan-box", "fanbox", "fan box", "feinripp", "barfuß", "barfuss", "schuh"]
## Real nationalities / ethnic groups as joke targets (lower-case whole words; curated, extend when needed). Left out on
## purpose because the everyday word means something else: "Amerikaner" (pastry), "Franzose" / "Franzosen" (adjustable
## wrench) — no false alarm for the Kiosk's pastry or the Hausmeister's toolbox. The live line filter blocks the same
## words (res://data/mod_filter.json → blocked.origin; test_06_ip_words checks that it covers this list).
const ORIGIN_WORDS: PackedStringArray = ["polen", "polin", "polnisch", "polnische", "polnischen", "türke", "türkin",
	"türken", "türkisch", "russe", "russin", "russen", "russisch", "rumäne", "rumänin", "rumänen", "italiener",
	"italienerin", "französin", "amerikanerin", "chinese", "chinesin", "chinesen", "japaner", "afrikaner", "asiate",
	"asiatin", "asiaten", "ossi", "ossis", "wessi", "wessis", "zigeuner", "eskimo", "indianer"]
## Graf Mopsula's texts (lower-case substrings): no crown, throne or royal title (live: mod_filter.json →
## mopsula_royalty, for lines in his voice or naming him).
const MOPSULA_WORDS: PackedStringArray = ["majestät", "majestaet", "majestat", "durchlaucht", "hoheit", "thron",
	"krone"]
const MOPSULA_NAME_RE: String = "(?i)\\b(graf|grafen|mopsula|mops)\\b"
const EQUIPMENT: PackedStringArray = ["weapon", "armor", "accessory"]


## Appends one error per offending text to the validator `v` (works on its normalized output).
static func check(v: DataValidator) -> void:
	var names: RegEx = RegEx.create_from_string(MOPSULA_NAME_RE)
	var origin: RegEx = RegEx.create_from_string("(?i)\\b(%s)\\b" % "|".join(ORIGIN_WORDS))
	var mop_skills: Dictionary = _mopsula_skills(v._out.get("party", []))
	for t: String in DataValidator.TABLES:
		var list: Array = v._out.get(t, [])
		for i in list.size():
			var d: Variant = list[i]
			if not d is Dictionary:
				continue
			var ctx: String = DataValidator._ctx(t, i, d)
			_walk(v, ctx, d, _entry_for_mopsula(t, d as Dictionary, mop_skills), names, origin)


## The first forbidden word of `text` for every player-facing text ("" = none).
static func general_word(text: String) -> String:
	var low: String = text.to_lower()
	for w: String in ALL_WORDS:
		if low.contains(w):
			return w
	var m: RegExMatch = RegEx.create_from_string("(?i)\\b(%s)\\b" % "|".join(ORIGIN_WORDS)).search(text)
	return m.get_string(1).to_lower() if m != null else ""


## The first royalty word of a text for / about Graf Mopsula ("" = none).
static func mopsula_word(text: String) -> String:
	var low: String = text.to_lower()
	for w: String in MOPSULA_WORDS:
		if low.contains(w):
			return w
	return ""


static func _walk(v: DataValidator, ctx: String, node: Variant, for_mopsula: bool, names: RegEx, origin: RegEx) -> void:
	if node is Dictionary:
		var d: Dictionary = node
		var mop: bool = for_mopsula or (d.has("voice") and str(d["voice"]) == "mopsula") \
			or (d.has("tag") and str(d["tag"]).contains("mopsula"))
		for k: Variant in d.keys():
			var key: String = str(k)
			var val: Variant = d[k]
			if val is String and TEXT_KEYS.has(key):
				_check_text(v, ctx + "." + key, str(val), mop, names, origin)
			elif val is Dictionary or val is Array:
				_walk(v, ctx + "." + key, val, mop, names, origin)
	elif node is Array:
		var a: Array = node
		for i in a.size():
			_walk(v, "%s[%d]" % [ctx, i], a[i], for_mopsula, names, origin)


static func _check_text(v: DataValidator, ctx: String, text: String, for_mopsula: bool, names: RegEx,
		origin: RegEx) -> void:
	var low: String = text.to_lower()
	for w: String in ALL_WORDS:
		if low.contains(w):
			v._err(ctx, "contains '%s' (IP distance: Fanpost-Paket, no underwear / foot words, 04 §2.3, 06 §0.3)" % w)
	var m: RegExMatch = origin.search(text)
	if m != null:
		v._err(ctx, "names '%s' (tone: no nationality or ethnic group as a joke target)" % m.get_string(1))
	if for_mopsula or names.search(text) != null:
		var bad: String = mopsula_word(text)
		if bad != "":
			v._err(ctx, "contains '%s' (no royalty motif for Graf Mopsula)" % bad)


## Is the whole entry Graf Mopsula's (his skills, equipment he can wear, his classes / talents / species, his party
## entry, every Mopsula scene)?
static func _entry_for_mopsula(table: String, d: Dictionary, mop_skills: Dictionary) -> bool:
	match table:
		"scenes":
			return true                          # Mopsula-Szenen (GDD §10.2): name and lines
		"skills":
			return mop_skills.has(str(d.get("id", "")))
		"items":
			var by: PackedStringArray = d.get("equip_by", PackedStringArray())
			return EQUIPMENT.has(str(d.get("type", ""))) and (by.is_empty() or by.has("mopsula"))
		"classes", "talents", "species":
			var members: PackedStringArray = d.get("for", PackedStringArray())
			return members.is_empty() or members.has("mopsula")
		"party":
			return str(d.get("id", "")) == "mopsula"
	return false


## Skill ids Graf Mopsula uses: attack skill and stunts of the party entry "mopsula", and from its rt block the
## auto-attack, the bar (FINALE and variants included), the context abilities and the Partner-Spezial.
static func _mopsula_skills(party: Array) -> Dictionary:
	var out: Dictionary = {}
	for p: Variant in party:
		if not p is Dictionary or str((p as Dictionary).get("id", "")) != "mopsula":
			continue
		var d: Dictionary = p
		out[str(d.get("attack_skill", ""))] = true
		for s: Variant in d.get("stunts", []):
			out[str(s)] = true
		var rt: Dictionary = d.get("rt", {}) if d.get("rt", {}) is Dictionary else {}
		for key: String in ["auto_skill", "partner_special"]:
			if str(rt.get(key, "")) != "":
				out[str(rt[key])] = true
		for list_key: String in ["bar", "context"]:
			var rows: Variant = rt.get(list_key, [])
			for r: Variant in (rows as Array if rows is Array else []):
				if r is Dictionary and str((r as Dictionary).get("skill", "")) != "":
					out[str((r as Dictionary)["skill"])] = true
	return out
