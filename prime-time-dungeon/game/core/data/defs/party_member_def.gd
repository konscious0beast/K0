class_name PartyMemberDef extends RefCounted
## party.json entry (02_TECH §4.4.5). Immutable after loading.

var id: String = ""
var name: String = ""
var title: String = ""
var base_stats: Dictionary = {}             # all 8 stat keys → int
var growth: Dictionary = {}                 # all 8 stat keys → float
var attack_skill: String = ""
var learnset: Array[Dictionary] = []        # [{"level": int, "skill": String}]
var stunts: PackedStringArray = []
var equipment: Dictionary = {"weapon": "", "armor": "", "accessory": ""}
var element_mods: Dictionary = {}
var status_immune: PackedStringArray = []
var status_resist: Dictionary = {}          # status id → float 0..1
var battle_slot: int = 0
var model: Dictionary = {}                  # ModelSpec (§4.4.14), normalized
var portrait_color: String = "#ffffff"
# --- Echtzeitkampf (07, R1a): optional `rt` block (07 §4.8), {} = no real-time data; filled by RtNorm ---------------
const RtNorm := preload("res://core/data/defs/rt_norm.gd")
const RT_SPEC: Array = [["radius_cm", "i", 40], ["move_cm_s", "i", 540], ["threat_pm", "i", 1000],
	["auto_skill", "s", ""], ["swing_ms", "i", 2000], ["reach_cm", "i", 250], ["mp_regen", "d", {}], ["keep_cm", "d", {}],
	["follow_cm", "i", 600], ["partner_special", "s", ""], ["bar", "a", []], ["context", "a", []], ["presets", "d", {}],
	["default_preset", "s", "attack"], ["assist_preset", "s", "attack"]]
const RT_MP_REGEN_SPEC: Array = [["mode", "s", "time"], ["amount", "i", 0], ["taken", "i", 0],
	["taken_every_ms", "i", 0], ["every_ms", "i", 0]]
const RT_KEEP_SPEC: Array = [["attack", "i", 0], ["support", "i", 0], ["careful", "i", 0]]
const RT_BAR_SPEC: Array = [["slot", "i", 0], ["skill", "s", ""], ["level", "i", 1], ["variant", "b", false],
	["finale", "b", false]]
const RT_CONTEXT_SPEC: Array = [["slot", "i", 0], ["skill", "s", ""], ["when", "s", ""], ["level", "i", 1]]
const RT_PRESETS_SPEC: Array = [["attack", "a", []], ["support", "a", []], ["careful", "a", []]]
var rt: Dictionary = {}


static func from_dict(d: Dictionary) -> PartyMemberDef:
	var r: PartyMemberDef = PartyMemberDef.new()
	r.id = str(d.get("id", ""))
	r.name = str(d.get("name", ""))
	r.title = str(d.get("title", ""))
	r.base_stats = (d.get("base_stats", {}) as Dictionary).duplicate(true)
	r.growth = (d.get("growth", {}) as Dictionary).duplicate(true)
	r.attack_skill = str(d.get("attack_skill", ""))
	r.learnset.assign((d.get("learnset", []) as Array).duplicate(true))
	r.stunts = JsonUtil.to_str_array(d.get("stunts", []))
	r.equipment = (d.get("equipment", {"weapon": "", "armor": "", "accessory": ""}) as Dictionary).duplicate(true)
	r.element_mods = (d.get("element_mods", {}) as Dictionary).duplicate(true)
	r.status_immune = JsonUtil.to_str_array(d.get("status_immune", []))
	r.status_resist = (d.get("status_resist", {}) as Dictionary).duplicate(true)
	r.battle_slot = int(d.get("battle_slot", 0))
	r.model = (d.get("model", {}) as Dictionary).duplicate(true)
	r.portrait_color = str(d.get("portrait_color", "#ffffff"))
	r.rt = _norm_rt(d.get("rt", {}))         # Echtzeitkampf (07, R1a)
	return r


# --- Echtzeitkampf (07, R1a) ------------------------------------------------------------------------------------------

## The filled `rt` block (07 §4.8) — {} without one; mp_regen, keep_cm and presets always complete, bar / context
## entries filled per row.
static func _norm_rt(raw: Variant) -> Dictionary:
	var out: Dictionary = RtNorm.fill(raw, RT_SPEC)
	if out.is_empty():
		return out
	out["mp_regen"] = RtNorm.fill_all(out["mp_regen"], RT_MP_REGEN_SPEC)
	out["keep_cm"] = RtNorm.fill_all(out["keep_cm"], RT_KEEP_SPEC)
	out["presets"] = RtNorm.fill_all(out["presets"], RT_PRESETS_SPEC)
	var bar: Array = []
	for e: Variant in (out["bar"] as Array):
		bar.append(RtNorm.fill_all(e, RT_BAR_SPEC))
	out["bar"] = bar
	var ctx: Array = []
	for e: Variant in (out["context"] as Array):
		ctx.append(RtNorm.fill_all(e, RT_CONTEXT_SPEC))
	out["context"] = ctx
	return out
