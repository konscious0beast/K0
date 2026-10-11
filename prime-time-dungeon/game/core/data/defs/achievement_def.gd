class_name AchievementDef extends RefCounted
## achievements.json entry (02_TECH §4.4.9). Immutable after loading.

var id: String = ""
var name: String = ""
var desc: String = ""
var trigger: String = ""
var condition: String = "true"
var box: String = ""
var followers: int = -1                     # -1 = by box tier (bronze 20 / silver 40 / gold 80, else 0)
var hidden: bool = false
var mod_tag: String = ""                    # "" → "achievement:<id>" with fallback "achievement_generic"
var expr: ConditionExpr = null              # parsed `condition`
## R5b (07 §9.4): an optional threshold of the real-time combat — "" = `condition` in both modes. A real-time run
## evaluates `condition_rt` and shows `desc_rt` (a real-time combat has many more hits than a CTB battle).
var condition_rt: String = ""
var desc_rt: String = ""
var expr_rt: ConditionExpr = null           # parsed `condition_rt` (null without one)


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
	r.condition_rt = str(d.get("condition_rt", ""))
	r.desc_rt = str(d.get("desc_rt", ""))
	r.expr_rt = ConditionExpr.parse(r.condition_rt) if r.condition_rt != "" else null
	return r


## The condition of the combat mode: expr_rt in a real-time run when there is one, else expr.
func expr_for(realtime: bool) -> ConditionExpr:
	return expr_rt if realtime and expr_rt != null else expr


## The description of the combat mode: desc_rt in a real-time run when there is one, else desc.
func desc_for(realtime: bool) -> String:
	return desc_rt if realtime and desc_rt != "" else desc
