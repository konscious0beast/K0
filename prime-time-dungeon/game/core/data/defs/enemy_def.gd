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
# --- Echtzeitkampf (07, R1a): optional `rt` block (07 §4.9), {} = no real-time data; filled by RtNorm ---------------
const RtNorm := preload("res://core/data/defs/rt_norm.gd")
## hp 0 = stats.hp × hp_pm / 1000; hp_pm 0 = RtBalance ENEMY_HP_PM; rules / phases stay as in the data
## (RtRules.compile).
const RT_SPEC: Array = [["hp", "i", 0], ["hp_pm", "i", 0], ["radius_cm", "i", 30], ["move_cm_s", "i", 360],
	["stationary", "b", false], ["keep_cm", "i", 0], ["auto_skill", "s", ""], ["auto_ranged_skill", "s", ""],
	["swing_ms", "i", 2400], ["reach_cm", "i", 220], ["auto_target", "s", "threat_top"], ["dmg_pm", "i", 1000],
	["immune", "sa", []], ["rules", "a", []], ["phases", "a", []], ["enrage", "d", {}]]
const RT_ENRAGE_SPEC: Array = [["at_ms", "i", 0], ["every_ms", "i", 0], ["status", "s", "sts_enrage"]]
var rt: Dictionary = {}


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
	r.rt = RtNorm.fill(d.get("rt", {}), RT_SPEC)       # Echtzeitkampf (07, R1a)
	if not r.rt.is_empty():
		r.rt["enrage"] = RtNorm.fill(r.rt["enrage"], RT_ENRAGE_SPEC)
	return r


func is_phased() -> bool:
	return str(ai.get("type", "weighted")) == "phased"
