class_name TwistDef extends RefCounted
## twists.json entry (06 §5.6, 02_TECH §4.4.14): one whitelisted, parameter-bounded M.O.D. intervention ("Twist").
## The catalog is shared by the offline Regie, the AI admin (mod-brain), viewer votes, event schedules and QA (F6).
## Immutable after loading. Every number is an integer; the effects live in TwistApplier (core/live).

var id: String = ""
var name: String = ""                    # HUD chip / M.O.D. (≤ 28 characters)
var desc: String = ""                    # one sentence for menus and the AI catalog (≤ 80 characters)
var gameplay: bool = true                # false = presentation only (allowed in the Pur-Liga, no caps / cooldown)
var scope: String = "explore"            # explore | instant | battle | safe_room | presentation | room | boss
var spice: String = "neutral"            # helpful | neutral | spicy | none
var slice: bool = false                  # true = TwistApplier implements it now; false → refused (not_in_slice)
var once_per_floor: bool = false
var weight: int = 1                      # Regie draw weight (1..10)
## {"unit": sec | battles | visits | run | none, "default", "min", "max"}
var duration: Dictionary = {"unit": "none", "default": 0, "min": 0, "max": 0}
## param → {"default", "min", "max"} (keys from TwistApplier.PARAM_BOUNDS)
var params: Dictionary = {}
var sources: PackedStringArray = []      # ⊆ TwistApplier.SOURCES
var mod_tag: String = ""                 # M.O.D. line said when the twist starts ("" = none)


static func from_dict(d: Dictionary) -> TwistDef:
	var r: TwistDef = TwistDef.new()
	r.id = str(d.get("id", ""))
	r.name = str(d.get("name", ""))
	r.desc = str(d.get("desc", ""))
	r.gameplay = bool(d.get("gameplay", true))
	r.scope = str(d.get("scope", "explore"))
	r.spice = str(d.get("spice", "neutral"))
	r.slice = bool(d.get("slice", false))
	r.once_per_floor = bool(d.get("once_per_floor", false))
	r.weight = int(d.get("weight", 1))
	var du: Variant = d.get("duration", {})
	if du is Dictionary:
		var dd: Dictionary = du
		r.duration = {"unit": str(dd.get("unit", "none")), "default": int(dd.get("default", 0)),
			"min": int(dd.get("min", 0)), "max": int(dd.get("max", 0))}
	var ps: Variant = d.get("params", {})
	if ps is Dictionary:
		var keys: Array = (ps as Dictionary).keys()
		keys.sort()
		for k: Variant in keys:
			var b: Variant = (ps as Dictionary)[k]
			if b is Dictionary:
				var bd: Dictionary = b
				r.params[str(k)] = {"default": int(bd.get("default", 0)), "min": int(bd.get("min", 0)),
					"max": int(bd.get("max", 0))}
	r.sources = JsonUtil.to_str_array(d.get("sources", []))
	r.mod_tag = str(d.get("mod_tag", ""))
	return r


## Duration unit ("sec" | "battles" | "visits" | "run" | "none").
func unit() -> String:
	return str(duration.get("unit", "none"))


## {param: default} — the parameters a twist gets when the proposer leaves them out.
func default_params() -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in params.keys():
		out[str(k)] = int((params[k] as Dictionary).get("default", 0))
	return out


## JSON view for the AI catalog / protocol (05 §10.5): plain types, keys sorted by the caller's canonical JSON.
func to_dict() -> Dictionary:
	return {"id": id, "name": name, "desc": desc, "gameplay": gameplay, "scope": scope, "spice": spice, "slice": slice,
		"once_per_floor": once_per_floor, "weight": weight, "duration": duration.duplicate(true),
		"params": params.duplicate(true), "sources": Array(sources), "mod_tag": mod_tag}
