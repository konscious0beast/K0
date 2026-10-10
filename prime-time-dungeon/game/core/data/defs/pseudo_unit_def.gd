class_name PseudoUnitDef extends RefCounted
## enemies.json → pseudo_units entry (02_TECH §4.4.6). Immutable after loading.

var id: String = ""
var name: String = ""
var icon: String = ""
# {"fixed_pct_maxhp": int, "element": String, "ignores_guard": bool, "target": "all_party"}
var action: Dictionary = {}
var ctr_after: int = 100
var warn_tag: String = ""
var warn_at: int = 2


static func from_dict(d: Dictionary) -> PseudoUnitDef:
	var r: PseudoUnitDef = PseudoUnitDef.new()
	r.id = str(d.get("id", ""))
	r.name = str(d.get("name", ""))
	r.icon = str(d.get("icon", ""))
	r.action = (d.get("action", {}) as Dictionary).duplicate(true)
	r.ctr_after = int(d.get("ctr_after", 100))
	r.warn_tag = str(d.get("warn_tag", ""))
	r.warn_at = int(d.get("warn_at", 2))
	return r
