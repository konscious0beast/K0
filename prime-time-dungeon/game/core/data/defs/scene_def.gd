class_name SceneDef extends RefCounted
## scenes.json entry: Mopsula scene in the safe room (02_TECH §4.4.13). Immutable after loading.

var id: String = ""
var name: String = ""
var condition: String = "true"
var lines: Array[Dictionary] = []           # [{"voice": String, "text": String}]
var set_flag: String = ""
var once: bool = true
var priority: int = 0
var expr: ConditionExpr = null              # parsed `condition` (e. = safe room context)


static func from_dict(d: Dictionary) -> SceneDef:
	var r: SceneDef = SceneDef.new()
	r.id = str(d.get("id", ""))
	r.name = str(d.get("name", ""))
	r.condition = str(d.get("condition", "true"))
	r.lines.assign((d.get("lines", []) as Array).duplicate(true))
	r.set_flag = str(d.get("set_flag", ""))
	r.once = bool(d.get("once", true))
	r.priority = int(d.get("priority", 0))
	r.expr = ConditionExpr.parse(r.condition)
	return r
