class_name AchievementDef extends RefCounted
## achievements.json entry (02_TECH §4.4.9). Immutable after loading.

var id: String = ""
var name: String = ""
var desc: String = ""
var trigger: String = ""
var condition: String = "true"
var box: String = ""
var followers: int = -1                     # -1 = by box tier (bronze 25 / silver 50 / gold 100, else 0)
var hidden: bool = false
var mod_tag: String = ""                    # "" → "achievement:<id>" with fallback "achievement_generic"
var expr: ConditionExpr = null              # parsed `condition`


static func from_dict(d: Dictionary) -> AchievementDef:
	var r: AchievementDef = AchievementDef.new()
	r.id = str(d.get("id", ""))
	r.name = str(d.get("name", ""))
	r.desc = str(d.get("desc", ""))
	r.trigger = str(d.get("trigger", ""))
	r.condition = str(d.get("condition", "true"))
	r.box = str(d.get("box", ""))
	r.followers = int(d.get("followers", -1))
	r.hidden = bool(d.get("hidden", false))
	r.mod_tag = str(d.get("mod_tag", ""))
	r.expr = ConditionExpr.parse(r.condition)
	return r
