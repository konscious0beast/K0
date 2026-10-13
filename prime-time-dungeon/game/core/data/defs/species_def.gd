class_name SpeciesDef extends RefCounted
## species.json entry (02_TECH §4.4.16, 06 §3.4): the "Wer bist du?" half of the Casting on floor 3 — stat character
## (stat_mult / growth_add like ClassDef), one passive (validated, not evaluated in the slice) and a look hint.
## Immutable after loading. "spc_original" (for all members, no multipliers) is the always-available "stay yourself".

const ORIGINAL: String = "spc_original"

var id: String = ""
var name: String = ""
var desc: String = ""
var for_members: PackedStringArray = []     # JSON key "for"; [] = all
var min_floor: int = 3
var stat_mult: Dictionary = {}              # stat key → float (0.5..2.0)
var growth_add: Dictionary = {}             # stat key → float (0..20)
var passive: Dictionary = {}                # {"id": "pas_…", "params": Dictionary}
var recommended_classes: PackedStringArray = []
var model_hint: Dictionary = {}             # {"props_add": [MODEL_PROPS], "colors": {key: "#rrggbb"}}


static func from_dict(d: Dictionary) -> SpeciesDef:
	var r: SpeciesDef = SpeciesDef.new()
	r.id = str(d.get("id", ""))
	r.name = str(d.get("name", ""))
	r.desc = str(d.get("desc", ""))
	r.for_members = JsonUtil.to_str_array(d.get("for", d.get("for_members", [])))
	r.min_floor = int(d.get("min_floor", 3))
	r.stat_mult = (d.get("stat_mult", {}) as Dictionary).duplicate(true)
	r.growth_add = (d.get("growth_add", {}) as Dictionary).duplicate(true)
	r.passive = (d.get("passive", {}) as Dictionary).duplicate(true)
	r.recommended_classes = JsonUtil.to_str_array(d.get("recommended_classes", []))
	r.model_hint = (d.get("model_hint", {}) as Dictionary).duplicate(true)
	return r


func is_for(member_id: String) -> bool:
	return for_members.is_empty() or for_members.has(member_id)
