extends RefCounted
## Validation rules of species.json (06 §3.4, 02_TECH §4.4.16) — package B's part of the DataValidator. A species is a
## subset of ClassDef (stat_mult / growth_add with the class ranges) plus one passive (validated, not evaluated in the
## slice), recommended classes and a look hint. Static; works on the DataValidator instance `v`. No class_name.

const TalentsRules := preload("res://core/data/validators/talents.gd")
const SPEC: Array = [["id", "s"], ["name", "s"], ["desc", "s", ""], ["for", "sa", []], ["min_floor", "i", 3],
	["stat_mult", "d", {}], ["growth_add", "d", {}], ["passive", "d"], ["recommended_classes", "sa", []],
	["model_hint", "d", {}]]
const SPEC_MODEL_HINT: Array = [["props_add", "sa", []], ["colors", "d", {}]]
const NAME_MAX: int = 32
const DESC_MAX: int = 60
## 04 §2.3: no crown motif on Graf Mopsula — also not through a species look.
const MOPSULA_FORBIDDEN_PROPS: PackedStringArray = ["crown", "ticket_crown"]


static func normalize(v: DataValidator, ctx: String, raw: Variant) -> Dictionary:
	var d: Dictionary = v._norm(ctx, raw, SPEC)
	if d.is_empty():
		return d
	TalentsRules.check_text(v, ctx + ".name", str(d["name"]), NAME_MAX, TalentsRules.is_for_mopsula(d))
	TalentsRules.check_text(v, ctx + ".desc", str(d["desc"]), DESC_MAX, TalentsRules.is_for_mopsula(d))
	v._range_i(ctx + ".min_floor", int(d["min_floor"]), 1, 99)
	d["stat_mult"] = v._num_dict(ctx + ".stat_mult", d["stat_mult"], DataValidator.STATS, false, 0.5, 2.0)
	d["growth_add"] = v._num_dict(ctx + ".growth_add", d["growth_add"], DataValidator.STATS, false, 0.0, 20.0)
	var p: Dictionary = v._norm(ctx + ".passive", d["passive"], DataValidator.SPEC_PASSIVE)
	if not p.is_empty() and not v._matches(str(DataValidator.ID_PATTERNS["passives"]), str(p["id"])):
		v._err(ctx + ".passive.id", "invalid passive id '%s' (pas_…)" % str(p["id"]))
	d["passive"] = p
	var mh: Dictionary = v._norm(ctx + ".model_hint", d["model_hint"], SPEC_MODEL_HINT)
	if mh.is_empty():
		mh = {"props_add": PackedStringArray(), "colors": {}}
	v._subset(ctx + ".model_hint.props_add", mh["props_add"], DataValidator.MODEL_PROPS)
	var for_mopsula: bool = TalentsRules.is_for_mopsula(d)
	for prop: String in mh["props_add"]:
		if for_mopsula and MOPSULA_FORBIDDEN_PROPS.has(prop):
			v._err(ctx + ".model_hint.props_add", "'%s': no crown motif on Graf Mopsula (04 §2.3)" % prop)
	var colors: Dictionary = mh["colors"]
	for k: Variant in colors.keys():
		var key: String = str(k)
		if not DataValidator.MODEL_COLOR_KEYS.has(key):
			v._err(ctx + ".model_hint.colors." + key, "unknown color key (%s)" % ", ".join(
				DataValidator.MODEL_COLOR_KEYS))
		elif typeof(colors[k]) != TYPE_STRING or not DataValidator.is_hex_color(str(colors[k])):
			v._err(ctx + ".model_hint.colors." + key, "must be a hex color \"#rrggbb\"")
	d["model_hint"] = mh
	return d


## Rule 5: `for` names party members; recommended classes exist and fit every member the species is for.
static func check_refs(v: DataValidator) -> void:
	var list: Array = v._out.get("species", [])
	for i in list.size():
		var d: Dictionary = list[i]
		var ctx: String = DataValidator._ctx("species", i, d)
		var members: PackedStringArray = (d["for"] as PackedStringArray).duplicate()
		for m: String in members:
			v._ref(ctx + ".for", m, v._party, "party member")
		if members.is_empty():
			for pid: Variant in v._party.keys():
				members.append(str(pid))
		for cid: String in d["recommended_classes"]:
			if not v._ref(ctx + ".recommended_classes", cid, v._classes, "class"):
				continue
			var cls_for: PackedStringArray = (v._classes[cid] as Dictionary)["for"]
			for m: String in members:
				if not cls_for.is_empty() and not cls_for.has(m):
					v._err(ctx + ".recommended_classes", "class '%s' is not for '%s'" % [cid, m])


## Strict content rule: "Original bleiben" is always a full choice (06 §3.1) → spc_original for every member, without
## stat multipliers.
static func check_content(v: DataValidator) -> void:
	var list: Array = v._out.get("species", [])
	for d: Dictionary in list:
		if str(d["id"]) == SpeciesDef.ORIGINAL:
			if not (d["for"] as PackedStringArray).is_empty():
				v._err("species[%s].for" % SpeciesDef.ORIGINAL, "must be [] (every member can stay original)")
			if not (d["stat_mult"] as Dictionary).is_empty():
				v._err("species[%s].stat_mult" % SpeciesDef.ORIGINAL, "must be {} (no stat change)")
			return
	v._err("species", "required species '%s' missing" % SpeciesDef.ORIGINAL)

