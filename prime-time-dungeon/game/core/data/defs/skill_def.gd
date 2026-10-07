class_name SkillDef extends RefCounted
## skills.json entry (02_TECH §4.4.2). Immutable after loading.

var id: String = ""
var name: String = ""
var desc: String = ""
var user: String = "any"
var category: String = "attack"
var target: String = "single_enemy"
var damage_type: String = "none"
var element: String = "none"
var power: int = 100
var heal_mode: String = ""
var hits: int = 1
var mp_cost: int = 0
var rank: int = 3
var accuracy: int = -1
var crit_bonus: float = 0.0
var statuses: Array[Dictionary] = []        # [{"id": String, "chance": float, "turns": int}]
var cleanse: PackedStringArray = []
var mp_restore: int = 0
var mp_restore_pct: int = 0
var summon: PackedStringArray = []
var flee_guaranteed: bool = false
var special: Dictionary = {}                # {} | {"kind": String, "max": int, "refund_on_win": bool}
var success_base: float = 0.0
var success_lck: float = 0.01
var success_cap: float = 0.85
var success_boss_mod: float = -0.15
var fail_effect: Dictionary = {}            # {} | {"self_dmg_pct", "delay_pct", "status", "status_turns"}
var cooldown: int = 0
var anim: String = "attack"
var vfx: String = ""
var sfx: String = ""
var hype: int = 0
var kill_hype: int = 0
var show_tags: PackedStringArray = []


static func from_dict(d: Dictionary) -> SkillDef:
	var r: SkillDef = SkillDef.new()
	r.id = str(d.get("id", ""))
	r.name = str(d.get("name", ""))
	r.desc = str(d.get("desc", ""))
	r.user = str(d.get("user", "any"))
	r.category = str(d.get("category", "attack"))
	r.target = str(d.get("target", "single_enemy"))
	r.damage_type = str(d.get("damage_type", "none"))
	r.element = str(d.get("element", "none"))
	r.power = int(d.get("power", 100))
	r.heal_mode = str(d.get("heal_mode", ""))
	r.hits = int(d.get("hits", 1))
	r.mp_cost = int(d.get("mp_cost", 0))
	r.rank = int(d.get("rank", 3))
	r.accuracy = int(d.get("accuracy", -1))
	r.crit_bonus = float(d.get("crit_bonus", 0.0))
	r.statuses.assign((d.get("statuses", []) as Array).duplicate(true))
	r.cleanse = JsonUtil.to_str_array(d.get("cleanse", []))
	r.mp_restore = int(d.get("mp_restore", 0))
	r.mp_restore_pct = int(d.get("mp_restore_pct", 0))
	r.summon = JsonUtil.to_str_array(d.get("summon", []))
	r.flee_guaranteed = bool(d.get("flee_guaranteed", false))
	r.special = (d.get("special", {}) as Dictionary).duplicate(true)
	r.success_base = float(d.get("success_base", 0.0))
	r.success_lck = float(d.get("success_lck", 0.01))
	r.success_cap = float(d.get("success_cap", 0.85))
	r.success_boss_mod = float(d.get("success_boss_mod", -0.15))
	r.fail_effect = (d.get("fail_effect", {}) as Dictionary).duplicate(true)
	r.cooldown = int(d.get("cooldown", 0))
	r.anim = str(d.get("anim", "attack"))
	r.vfx = str(d.get("vfx", ""))
	r.sfx = str(d.get("sfx", ""))
	r.hype = int(d.get("hype", 0))
	r.kill_hype = int(d.get("kill_hype", 0))
	r.show_tags = JsonUtil.to_str_array(d.get("show_tags", []))
	return r


func is_stunt() -> bool:
	return category == "stunt"


func is_damaging() -> bool:
	return damage_type == "physical" or damage_type == "magical" or damage_type == "fixed"
