class_name EnemyDef extends RefCounted
## enemies.json entry (02_TECH §4.4.6). Immutable after loading.

var id: String = ""
var name: String = ""
var level: int = 1
var stats: Dictionary = {}                  # all 8 stat keys → int
var exp: int = 0                            # JSON key; the global exp function is never used in this class (§13.1)
var credits: int = 0
var attack_skill: String = ""
var ai: Dictionary = {"type": "weighted", "actions": []}   # actions: Array[Dictionary] AiAction
# [{"hp_above": float, "on_enter": Array[Dictionary], "actions": Array[Dictionary]}]
var phases: Array[Dictionary] = []
var element_mods: Dictionary = {}
var status_immune: PackedStringArray = []
var status_resist: Dictionary = {}
var drops: Array[Dictionary] = []           # [{"item": String, "chance": float}]
var boss_drops: Array[Dictionary] = []      # [{"kind": "item"|"box", "id": String, "amount": int}]
var tags: PackedStringArray = []
var boss: bool = false
var model: Dictionary = {}                  # ModelSpec, normalized
var explore: Dictionary = {}                # field_speed, patrol_speed, sight_range, … (all keys present)


static func from_dict(d: Dictionary) -> EnemyDef:
	var r: EnemyDef = EnemyDef.new()
	r.id = str(d.get("id", ""))
	r.name = str(d.get("name", ""))
	r.level = int(d.get("level", 1))
	r.stats = (d.get("stats", {}) as Dictionary).duplicate(true)
	r.exp = int(d.get("exp", 0))
	r.credits = int(d.get("credits", 0))
	r.attack_skill = str(d.get("attack_skill", ""))
	r.ai = (d.get("ai", {"type": "weighted", "actions": []}) as Dictionary).duplicate(true)
	r.phases.assign((d.get("phases", []) as Array).duplicate(true))
	r.element_mods = (d.get("element_mods", {}) as Dictionary).duplicate(true)
	r.status_immune = JsonUtil.to_str_array(d.get("status_immune", []))
	r.status_resist = (d.get("status_resist", {}) as Dictionary).duplicate(true)
	r.drops.assign((d.get("drops", []) as Array).duplicate(true))
	r.boss_drops.assign((d.get("boss_drops", []) as Array).duplicate(true))
	r.tags = JsonUtil.to_str_array(d.get("tags", []))
	r.boss = bool(d.get("boss", false))
	r.model = (d.get("model", {}) as Dictionary).duplicate(true)
	r.explore = (d.get("explore", {}) as Dictionary).duplicate(true)
	return r


func is_phased() -> bool:
	return str(ai.get("type", "weighted")) == "phased"
