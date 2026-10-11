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
# --- Echtzeitkampf (07, R1a): optional `rt` block (07 §4.6), {} = no real-time data; filled by RtNorm ---------------
const RtNorm := preload("res://core/data/defs/rt_norm.gd")
## impact_ms -1 = derived from `anim` (RtBalance.IMPACT_TICKS, 07 §3.6.7); statuses[].ms 0 = the status's
## rt.default_ms; power / mp / cleanse default to the CTB fields; moving_cancels defaults to cast_ms / channel_ms > 0.
const RT_SPEC: Array = [["icon", "s", ""], ["cast_ms", "i", 0], ["channel_ms", "i", 0], ["period_ms", "i", 0],
	["cooldown_ms", "i", 0], ["gcd", "b", true], ["range_cm", "i", 0], ["aoe", "d", {}], ["moving_cancels", "b", false],
	["interrupt", "b", false], ["interruptible", "b", true], ["interrupt_worthy", "b", false], ["threat_pm", "i", 1000],
	["impact_ms", "i", -1], ["power", "i", 0], ["mp", "i", 0], ["statuses", "a", []], ["cleanse", "sa", []],
	["telegraph", "d", {}], ["zone", "d", {}], ["dash", "b", false], ["pct_maxhp", "i", 0], ["ignore_guard", "b", false],
	["kill_adds", "b", false], ["fail_ms", "i", 0]]
const RT_AOE_SPEC: Array = [["center", "s", "self"], ["radius_cm", "i", 0], ["cone_deg", "i", 0],
	["max_targets", "i", 0]]
const RT_STATUS_SPEC: Array = [["id", "s", ""], ["chance_pm", "i", 1000], ["ms", "i", 0], ["to", "s", "target"],
	["tick_power", "i", 0]]
const RT_TELEGRAPH_SPEC: Array = [["shape", "s", "circle"], ["anchor", "s", "target_pos"], ["radius_cm", "i", 0],
	["inner_cm", "i", 0], ["angle_deg", "i", 0], ["length_cm", "i", 0], ["width_cm", "i", 0], ["count", "i", 1],
	["lanes", "ia", []]]
const RT_ZONE_SPEC: Array = [["ms", "i", 0], ["period_ms", "i", 0], ["status", "s", ""], ["skill", "s", ""]]
var rt: Dictionary = {}


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
	r.rt = _norm_rt(d.get("rt", {}), r)        # Echtzeitkampf (07, R1a)
	return r


func is_stunt() -> bool:
	return category == "stunt"


func is_damaging() -> bool:
	return damage_type == "physical" or damage_type == "magical" or damage_type == "fixed"


# --- Echtzeitkampf (07, R1a) ------------------------------------------------------------------------------------------

## The filled `rt` block (07 §4.6) — {} without one. CTB defaults: power, mp (mp_cost), cleanse.
static func _norm_rt(raw: Variant, def: SkillDef) -> Dictionary:
	var out: Dictionary = RtNorm.fill(raw, RT_SPEC)
	if out.is_empty():
		return out
	var src: Dictionary = raw
	if not src.has("power"):
		out["power"] = def.power
	if not src.has("mp"):
		out["mp"] = def.mp_cost
	if not src.has("cleanse"):
		out["cleanse"] = Array(def.cleanse)
	if not src.has("moving_cancels"):
		out["moving_cancels"] = int(out["cast_ms"]) > 0 or int(out["channel_ms"]) > 0
	out["aoe"] = RtNorm.fill(out["aoe"], RT_AOE_SPEC)
	var sts: Array = []
	for e: Variant in (out["statuses"] as Array):
		sts.append(RtNorm.fill_all(e, RT_STATUS_SPEC))
	out["statuses"] = sts
	out["telegraph"] = RtNorm.fill(out["telegraph"], RT_TELEGRAPH_SPEC)
	out["zone"] = RtNorm.fill(out["zone"], RT_ZONE_SPEC)
	return out
