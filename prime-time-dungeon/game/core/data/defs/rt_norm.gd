extends RefCounted
## Echtzeitkampf (07, R1a): normalization of the optional `rt` blocks of the data defs (07 §4.6–4.9). Private helper of
## the defs (no class_name; preloaded as RtNorm). A def keeps `rt = {}` when its entry has no (or an empty) `rt` block —
## "no real-time data" — and otherwise a complete dictionary: every field of its spec, missing ones with the default of
## 07 §4.6–4.9, numbers as int (JSON floats converted), unknown keys dropped (validators/rt.gd, R4, reports them).
## Defaults that depend on other data are sentinels the sim resolves (R1b): see the specs of the defs.
## Spec rows: [name, type, default] with type "i" int, "b" bool, "s" String, "d" Dictionary, "a" Array, "sa" Array of
## Strings (kept as Array for JSON-like reading), "ia" Array of ints.


## The filled block of `raw` against `spec` ({} if raw is not a non-empty Dictionary).
static func fill(raw: Variant, spec: Array) -> Dictionary:
	if not (raw is Dictionary) or (raw as Dictionary).is_empty():
		return {}
	return fill_all(raw, spec)


## Like fill, but also an empty / missing block gets every default (sub objects that always exist once a block does).
static func fill_all(raw: Variant, spec: Array) -> Dictionary:
	var src: Dictionary = raw if raw is Dictionary else {}
	var out: Dictionary = {}
	for row: Array in spec:
		var key: String = str(row[0])
		out[key] = as_type(src.get(key, row[2]), str(row[1]), row[2])
	return out


## `v` as `typ`; the default when it has the wrong type.
static func as_type(v: Variant, typ: String, dflt: Variant) -> Variant:
	match typ:
		"i":
			return int(v) if JsonUtil.is_integral(v) else int(dflt)
		"b":
			return bool(v) if v is bool else bool(dflt)
		"s":
			return str(v) if (v is String or v is StringName) else str(dflt)
		"d":
			return ints((v as Dictionary).duplicate(true)) if v is Dictionary else (dflt as Dictionary).duplicate(true)
		"a":
			return ints((v as Array).duplicate(true)) if v is Array else (dflt as Array).duplicate(true)
		"sa":
			var out: Array = []
			if v is Array or v is PackedStringArray:
				for e: Variant in Array(v):
					out.append(str(e))
			return out
		"ia":
			var outi: Array = []
			if v is Array:
				for e: Variant in (v as Array):
					if JsonUtil.is_integral(e):
						outi.append(int(e))
			return outi
	return v


## Deep copy with integral JSON floats as int (rt blocks are integers only, 07 §4.10 V1).
static func ints(v: Variant) -> Variant:
	match typeof(v):
		TYPE_DICTIONARY:
			var out: Dictionary = {}
			for k: Variant in (v as Dictionary).keys():
				out[str(k)] = ints((v as Dictionary)[k])
			return out
		TYPE_ARRAY:
			var out_a: Array = []
			for e: Variant in (v as Array):
				out_a.append(ints(e))
			return out_a
		TYPE_FLOAT:
			return int(v) if JsonUtil.is_integral(v) else v
	return v
