# STUB(ST0) — owned by 09-ST1-B. Replace completely, keep the public API.
extends RefCounted
## Validation of data/seasons.json (09 §9.1, §2.1): one season template per entry (prefix ssn_) — format 6 | 12 | 18
## (the floors) with its calendar days 24 | 54 | 84 (09 §2.4), places 20–100 (§2.3), the default air time "HH:MM"
## (§2.1) and rules.pvp "arena" (§6.2: no PvP against sleepers, opt-in arenas only). Private helper of DataValidator
## (no class_name; preloaded as SeasonsCheck). ST0 ships the schema and these ranges; ST1-B adds the rest.

const SPEC: Array = [["id", "s"], ["name", "s"], ["format", "i"], ["days", "i"], ["places", "i", 100],
	["air_time", "s", "20:00"], ["rules", "d", {}]]
## Floors of a format → its calendar days (09 §2.4).
const FORMATS: Dictionary = {6: 24, 12: 54, 18: 84}
const PLACES_MIN: int = 20
const PLACES_MAX: int = 100
const RULE_KEYS: PackedStringArray = ["pvp"]
## 09 §6.2 (F-6): no PvP against sleepers — the only value is the opt-in arena.
const PVP: PackedStringArray = ["arena"]
const AIR_TIME_RE: String = "^([01][0-9]|2[0-3]):[0-5][0-9]$"


## One season template ({} if not an object).
static func normalize(v: DataValidator, ctx: String, raw: Variant) -> Dictionary:
	return v._norm(ctx, raw, SPEC)


## Ranges of every template (format with its days, places, air time, rules).
static func check(v: DataValidator) -> void:
	for d: Dictionary in v._out.get("seasons", []):
		var ctx: String = "seasons[%s]" % str(d["id"])
		if str(d["name"]) == "":
			v._err(ctx + ".name", "must not be empty")
		var format: int = int(d["format"])
		if not FORMATS.has(format):
			v._err(ctx + ".format", "must be 6, 12 or 18 floors (09 §2.1)")
		elif int(d["days"]) != int(FORMATS[format]):
			v._err(ctx + ".days", "a %d-floor season has %d days (09 §2.4)" % [format, int(FORMATS[format])])
		v._range_i(ctx + ".places", int(d["places"]), PLACES_MIN, PLACES_MAX)
		if not v._matches(AIR_TIME_RE, str(d["air_time"])):
			v._err(ctx + ".air_time", "must be \"HH:MM\" (local time)")
		var rules: Dictionary = d["rules"]
		for k: Variant in rules.keys():
			if not RULE_KEYS.has(str(k)):
				v._err(ctx + ".rules." + str(k), "unknown key")
		if not PVP.has(str(rules.get("pvp", "arena"))):
			v._err(ctx + ".rules.pvp", "must be one of %s (09 §6.2: no PvP against sleepers)" % ", ".join(PVP))
