extends RefCounted
## Validation of data/looks.json (08 §6.1, K2): one entry per look option (prefix lk_) with its category `kind` (hair,
## hair_color, skin, beard, glasses, outfit), a name and its value — `style` (hair: ModelSpec.style.hair, beard:
## ModelSpec.style.beard, glasses: GLASSES_STYLES), `color` (hair_color, skin: "#rrggbb") or `colors` (outfit:
## {"primary", "secondary"}); `canon` marks Kai's option (exactly one per kind). Private helper of DataValidator (no
## class_name; preloaded as LooksCheck). Rules: the value fields of each kind (and no others), known styles, hex
## colours, names (<= NAME_MAX, unique per kind, skin tones only "Ton N" — no attributions, 08 §6.1), no option twice,
## exactly one canon per kind, and the canon look is exactly Kai's model in party.json (the canon Kai keeps his look).
## Counts are the real catalog's business (test_08_avatar_kit) — fixtures may carry the canon only.

const TalentsRules := preload("res://core/data/validators/talents.gd")

const SPEC: Array = [["id", "s"], ["kind", "s"], ["name", "s"], ["style", "s", ""], ["color", "s", ""],
	["colors", "d", {}], ["canon", "b", false]]
const KINDS: PackedStringArray = ["hair", "hair_color", "skin", "beard", "glasses", "outfit"]
## Glasses: none or round (= the ModelSpec prop "glasses", 03_ART §5.4; 08 §6.2: the existing prop, unchanged).
const GLASSES_STYLES: PackedStringArray = ["none", "round"]
const GLASSES_PROP: String = "glasses"
## The value field(s) of each kind; every other value field must stay empty.
const VALUE_FIELD: Dictionary = {"hair": "style", "beard": "style", "glasses": "style", "hair_color": "color",
	"skin": "color", "outfit": "colors"}
const OUTFIT_KEYS: PackedStringArray = ["primary", "secondary"]
const NAME_MAX: int = 16
const MAX_PER_KIND: int = 12
## Skin tones are named neutrally (08 §6.1: "Ton 1–8", no attributions).
const SKIN_NAME_RE: String = "^Ton [1-9][0-9]?$"
## The member whose ModelSpec the look dresses (08 §6.3: DB.party_model mixes the look only for kai).
const MEMBER: String = "kai"


## One look entry ({} if not an object).
static func normalize(v: DataValidator, ctx: String, raw: Variant) -> Dictionary:
	var d: Dictionary = v._norm(ctx, raw, SPEC)
	if d.is_empty():
		return d
	v._enum(ctx + ".kind", str(d["kind"]), KINDS)
	return d


## Cross-entry rules: values per kind, names, duplicates, exactly one canon per kind, canon = Kai's party.json model.
static func check(v: DataValidator) -> void:
	var list: Array = v._out.get("looks", [])
	if list.is_empty():
		return                                   # a data set without looks.json
	var by_kind: Dictionary = {}
	for d: Dictionary in list:
		var kind: String = str(d["kind"])
		if not KINDS.has(kind):
			continue                             # reported by normalize
		_check_entry(v, d)
		if not by_kind.has(kind):
			by_kind[kind] = []
		(by_kind[kind] as Array).append(d)
	var canon: Dictionary = {}
	for kind: String in KINDS:
		var entries: Array = by_kind.get(kind, [])
		var ctx: String = "looks[kind=%s]" % kind
		if entries.is_empty():
			v._err(ctx, "no option (every kind needs its canon option)")
			continue
		if entries.size() > MAX_PER_KIND:
			v._err(ctx, "%d options > %d" % [entries.size(), MAX_PER_KIND])
		var names: Dictionary = {}
		var values: Dictionary = {}
		var canons: PackedStringArray = []
		for d: Dictionary in entries:
			var id: String = str(d["id"])
			var name: String = str(d["name"])
			if names.has(name):
				v._err("looks[%s].name" % id, "'%s' twice in %s (also %s)" % [name, kind, names[name]])
			names[name] = id
			var value: String = _value_key(d)
			if values.has(value):
				v._err("looks[%s]" % id, "the same %s as %s" % [VALUE_FIELD[kind], values[value]])
			values[value] = id
			if bool(d["canon"]):
				canons.append(id)
		if canons.size() != 1:
			v._err(ctx, "exactly one canon option needed (%s)" % (", ".join(canons) if not canons.is_empty() else "none"))
		else:
			canon[kind] = _first(entries, canons[0])
	if canon.size() == KINDS.size():
		_check_canon_is_kai(v, canon)


## The value fields of one entry and its name.
static func _check_entry(v: DataValidator, d: Dictionary) -> void:
	var id: String = str(d["id"])
	var kind: String = str(d["kind"])
	var ctx: String = "looks[%s]" % id
	var name: String = str(d["name"])
	if name.strip_edges() == "" or name != name.strip_edges():
		v._err(ctx + ".name", "empty or padded")
	TalentsRules.check_text(v, ctx + ".name", name, NAME_MAX)
	if kind == "skin" and not v._matches(SKIN_NAME_RE, name):
		v._err(ctx + ".name", "skin tones are named \"Ton <n>\" (08 §6.1: no attributions)")
	var field: String = VALUE_FIELD[kind]
	for f: String in ["style", "color", "colors"]:
		var empty: bool = (d[f] as Dictionary).is_empty() if f == "colors" else str(d[f]) == ""
		if f != field and not empty:
			v._err(ctx + "." + f, "not a field of kind %s (use %s)" % [kind, field])
	match kind:
		"hair":
			v._enum(ctx + ".style", str(d["style"]), DataValidator.MODEL_HAIR_STYLES)
		"beard":
			v._enum(ctx + ".style", str(d["style"]), DataValidator.MODEL_BEARDS)
		"glasses":
			v._enum(ctx + ".style", str(d["style"]), GLASSES_STYLES)
		"hair_color", "skin":
			if not DataValidator.is_hex_color(str(d["color"])):
				v._err(ctx + ".color", "must be a hex color \"#rrggbb\"")
		"outfit":
			var colors: Dictionary = d["colors"]
			for k: Variant in colors.keys():
				if not OUTFIT_KEYS.has(str(k)):
					v._err(ctx + ".colors." + str(k), "unknown key (primary, secondary)")
			for k: String in OUTFIT_KEYS:
				if not colors.has(k) or typeof(colors[k]) != TYPE_STRING or not DataValidator.is_hex_color(str(colors[k])):
					v._err(ctx + ".colors." + k, "must be a hex color \"#rrggbb\"")


## The canon option of every kind dresses Kai exactly as party.json does (style, glasses prop, accent / skin /
## primary / secondary colours) — so DB.party_model with the canon look is the def model.
static func _check_canon_is_kai(v: DataValidator, canon: Dictionary) -> void:
	var kai: Dictionary = {}
	for p: Dictionary in v._out.get("party", []):
		if str(p.get("id", "")) == MEMBER:
			kai = p.get("model", {})
	if kai.is_empty() or str(kai.get("base", "")) != "humanoid":
		return
	var style: Dictionary = kai.get("style", {})
	var colors: Dictionary = kai.get("colors", {})
	var props: PackedStringArray = kai.get("props", PackedStringArray())
	var want: Dictionary = {
		"hair": str(style.get("hair", DataValidator.MODEL_HAIR_STYLES[0])),
		"beard": str(style.get("beard", DataValidator.MODEL_BEARDS[0])),
		"glasses": GLASSES_STYLES[1] if props.has(GLASSES_PROP) else GLASSES_STYLES[0],
		"hair_color": str(colors.get("accent", "")).to_lower(),
		"skin": str(colors.get("skin", "")).to_lower(),
		"outfit": "%s/%s" % [str(colors.get("primary", "")).to_lower(), str(colors.get("secondary", "")).to_lower()],
	}
	for kind: String in KINDS:
		var have: String = _value_key(canon[kind] as Dictionary)
		if have != str(want[kind]):
			v._err("looks[%s]" % str((canon[kind] as Dictionary)["id"]),
				"the canon %s '%s' is not Kai's '%s' (party.json)" % [kind, have, str(want[kind])])


## The comparable value of an entry: its style, its colour (lower case) or "primary/secondary".
static func _value_key(d: Dictionary) -> String:
	match str(d["kind"]):
		"hair_color", "skin":
			return str(d["color"]).to_lower()
		"outfit":
			var c: Dictionary = d["colors"]
			return "%s/%s" % [str(c.get("primary", "")).to_lower(), str(c.get("secondary", "")).to_lower()]
	return str(d["style"])


static func _first(entries: Array, id: String) -> Dictionary:
	for d: Dictionary in entries:
		if str(d["id"]) == id:
			return d
	return {}
