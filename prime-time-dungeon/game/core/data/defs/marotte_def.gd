class_name MarotteDef extends RefCounted
## marotten.json entry (06 §4.9, 02_TECH §4.4.15): one of M.O.D.'s preferences ("Marotte", show bet) or the always-on
## Unterhosen-Liga (kind "liga"). Immutable after loading.
##   kind      battle (hit on a won battle) | explore (hit on a first room visit) | liga (equipment tier, no bet)
##   trigger   marotte_battle | explore_zone — the context the condition sees (MarottenRules.battle_context /
##             zone payload; e-keys in DataValidator's marotten helper)
##   goal      hits (hearts) that win the bet (liga: 0)
##   reward    rotating: {"hit_hype", "hit_follower_pm", "won_box", "won_followers", "won_hype"};
##             liga: {"tiers": [{"tier", "hype_pm", "follower_pm"}], "floor_box"}

var id: String = ""
var name: String = ""                      # HUD name ("M.O.D. mag heute: <name>"), <= 28 characters
var desc: String = ""                      # the rule in one sentence (pause tab "Show"), <= 80 characters
var kind: String = "battle"
var trigger: String = "marotte_battle"
var condition: String = "true"
var goal: int = 3
var rotation: bool = true                  # part of the per-floor rotation (MarottenRules.announce)
var starter: bool = false                  # allowed on floor 1 (the learning floor: easy, readable)
var min_floor: int = 1
var weight: int = 1
var reward: Dictionary = {}
var mod_tag: String = ""
var expr: ConditionExpr = null             # parsed `condition`


static func from_dict(d: Dictionary) -> MarotteDef:
	var r: MarotteDef = MarotteDef.new()
	r.id = str(d.get("id", ""))
	r.name = str(d.get("name", ""))
	r.desc = str(d.get("desc", ""))
	r.kind = str(d.get("kind", "battle"))
	r.trigger = str(d.get("trigger", "marotte_battle"))
	r.condition = str(d.get("condition", "true"))
	r.goal = int(d.get("goal", 3))
	r.rotation = bool(d.get("rotation", true))
	r.starter = bool(d.get("starter", false))
	r.min_floor = int(d.get("min_floor", 1))
	r.weight = int(d.get("weight", 1))
	var rw: Variant = d.get("reward", {})
	r.reward = (rw as Dictionary).duplicate(true) if rw is Dictionary else {}
	r.mod_tag = str(d.get("mod_tag", ""))
	r.expr = ConditionExpr.parse(r.condition)
	return r


## Integer reward value (0 if missing).
func reward_int(key: String) -> int:
	return JsonUtil.to_int(reward.get(key, 0))


## Liga reward tier entry {"tier", "hype_pm", "follower_pm"} for `tier` ({} = none).
func liga_tier_reward(tier: int) -> Dictionary:
	var tiers: Variant = reward.get("tiers", [])
	if tiers is Array:
		for t: Variant in (tiers as Array):
			if t is Dictionary and JsonUtil.to_int((t as Dictionary).get("tier", 0)) == tier:
				return t
	return {}
