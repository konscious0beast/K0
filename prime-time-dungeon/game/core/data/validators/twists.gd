class_name TwistValidator extends RefCounted
## Validation of data/twists.json (06 §5.6, package D) — called by DataValidator for the table "twists" (rules 2/4:
## normalize, rule 5: references / mod tags). Owned by 06-D so that the other packages never touch it.
##
## Per entry: id ^tw_…, name ≤ 28 characters (HUD chip), desc ≤ 80, scope / spice / duration.unit from the
## TwistApplier vocabularies, sources ⊆ TwistApplier.SOURCES (non-empty), weight 1..10, duration {unit, default, min,
## max} integers with min ≤ default ≤ max inside TwistApplier.DURATION_BOUNDS of the unit, params {key: {default, min,
## max}} with keys from TwistApplier.PARAM_BOUNDS and min ≤ default ≤ max inside those hard bounds ("parameter-bounded":
## data can narrow a bound, never widen it), gameplay: false only for scope presentation (and vice versa), slice: true
## only for TwistApplier.IMPLEMENTED ids, mod_tag "" or a valid M.O.D. tag (referenced → rule 9 needs a line).

const SPEC: Array = [["id", "s"], ["name", "s"], ["desc", "s", ""], ["gameplay", "b", true], ["scope", "s"],
	["spice", "s"], ["slice", "b", false], ["once_per_floor", "b", false], ["weight", "i", 1], ["duration", "d"],
	["params", "d", {}], ["sources", "sa"], ["mod_tag", "s", ""]]
const SPEC_DURATION: Array = [["unit", "s"], ["default", "i", 0], ["min", "i", 0], ["max", "i", 0]]
const SPEC_BOUND: Array = [["default", "i"], ["min", "i"], ["max", "i"]]
const MAX_NAME: int = 28
const MAX_DESC: int = 80


## Rules 2/4 for one twists.json entry: the normalized dictionary ({} if not an object).
static func normalize(v: DataValidator, ctx: String, raw: Variant) -> Dictionary:
	var d: Dictionary = v._norm(ctx, raw, SPEC)
	if d.is_empty():
		return d
	if str(d["name"]).length() > MAX_NAME:
		v._err(ctx + ".name", "longer than %d characters (HUD chip)" % MAX_NAME)
	if str(d["desc"]).length() > MAX_DESC:
		v._err(ctx + ".desc", "longer than %d characters" % MAX_DESC)
	v._enum(ctx + ".scope", str(d["scope"]), TwistApplier.SCOPES)
	v._enum(ctx + ".spice", str(d["spice"]), TwistApplier.SPICES)
	v._range_i(ctx + ".weight", int(d["weight"]), 1, 10)
	var sources: PackedStringArray = d["sources"]
	if sources.is_empty():
		v._err(ctx + ".sources", "needs at least one source")
	v._subset(ctx + ".sources", sources, TwistApplier.SOURCES)
	var presentation: bool = str(d["scope"]) == "presentation"
	if bool(d["gameplay"]) == presentation:
		v._err(ctx + ".gameplay", "must be false exactly for scope presentation")
	if bool(d["slice"]) and not TwistApplier.IMPLEMENTED.has(str(d["id"])):
		v._err(ctx + ".slice", "'%s' has no effect in this build (TwistApplier.IMPLEMENTED)" % str(d["id"]))
	d["duration"] = _duration(v, ctx + ".duration", d["duration"])
	d["params"] = _params(v, ctx + ".params", d["params"])
	return d


## Rule 5: the mod tag must be a valid tag; it counts as referenced (rule 9: a line must exist).
static func check(v: DataValidator, entries: Array) -> void:
	for i in entries.size():
		var d: Dictionary = entries[i]
		var tag: String = str(d.get("mod_tag", ""))
		if tag == "":
			continue
		var ctx: String = DataValidator._ctx("twists", i, d) + ".mod_tag"
		if not DataValidator.is_valid_mod_tag(tag):
			v._err(ctx, "unknown tag '%s'" % tag)
		else:
			v._referenced_tags[tag] = ctx


static func _duration(v: DataValidator, ctx: String, raw: Variant) -> Dictionary:
	var d: Dictionary = v._norm(ctx, raw, SPEC_DURATION)
	if d.is_empty():
		return {"unit": "none", "default": 0, "min": 0, "max": 0}
	var unit: String = str(d["unit"])
	v._enum(ctx + ".unit", unit, TwistApplier.UNITS)
	var hard: Array = TwistApplier.DURATION_BOUNDS.get(unit, [0, 0])
	_bounds(v, ctx, int(d["default"]), int(d["min"]), int(d["max"]), int(hard[0]), int(hard[1]))
	return d


static func _params(v: DataValidator, ctx: String, raw: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var keys: Array = raw.keys()
	keys.sort()
	for k: Variant in keys:
		var key: String = str(k)
		var pctx: String = ctx + "." + key
		if not TwistApplier.PARAM_BOUNDS.has(key):
			v._err(pctx, "unknown parameter (allowed: %s)" % ", ".join(PackedStringArray(TwistApplier.PARAM_BOUNDS.keys())))
			continue
		var b: Dictionary = v._norm(pctx, raw[k], SPEC_BOUND)
		if b.is_empty():
			continue
		var hard: Array = TwistApplier.PARAM_BOUNDS[key]
		_bounds(v, pctx, int(b["default"]), int(b["min"]), int(b["max"]), int(hard[0]), int(hard[1]))
		out[key] = b
	return out


static func _bounds(v: DataValidator, ctx: String, dflt: int, lo: int, hi: int, hard_lo: int, hard_hi: int) -> void:
	if lo > hi or dflt < lo or dflt > hi:
		v._err(ctx, "needs min <= default <= max (got %d <= %d <= %d)" % [lo, dflt, hi])
	if lo < hard_lo or hi > hard_hi:
		v._err(ctx, "bounds %d..%d exceed the hard bounds %d..%d" % [lo, hi, hard_lo, hard_hi])
