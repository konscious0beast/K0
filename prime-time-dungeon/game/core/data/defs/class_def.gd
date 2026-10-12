class_name ClassDef extends RefCounted
## classes.json entry (02_TECH §4.4.4; class choice from floor 3). Immutable after loading.

var id: String = ""
var name: String = ""
var desc: String = ""
var for_members: PackedStringArray = []     # JSON key "for"; [] = all
var min_floor: int = 3
var stat_mult: Dictionary = {}              # stat key → float
var growth_add: Dictionary = {}             # stat key → float
var passives: Array[Dictionary] = []        # [{"id": "pas_…", "params": Dictionary}]
var learnset: Array[Dictionary] = []        # [{"level": int, "skill": String}]
var show_mods: Dictionary = {"hype_gain_mult": 1.0, "stunt_success_add": 0.0, "stunt_cooldown": 3,
	"sponsor_thresholds": PackedInt32Array([70, 85, 100])}
# --- Staffeln (09 §8.3; contract pass 4, 07 CR-32 a/b): the optional `rt` block of a class, {} = none (filled by
# RtNorm like PartyMemberDef.rt, checked by validators/rt.gd) — `bar`: the class abilities as rows of the party bar
# schema (PartyMemberDef.RT_BAR_SPEC: slot, skill, level, variant, finale; every row a variant or the FINALE of a slot,
# unlocked from `level`), `ranks`: Rang II–IV [{"level", "pm"}] — from `level` on every class ability of the bar works
# with pm ‰ power (RtMods skill_pm with the source class:<id>, 07 §9.5). ST1-D builds the ability book on it; nothing
# reads it outside a season.
const RtNorm := preload("res://core/data/defs/rt_norm.gd")
const RT_SPEC: Array = [["bar", "a", []], ["ranks", "a", []]]
const RT_RANK_SPEC: Array = [["level", "i", 0], ["pm", "i", 1000]]
var rt: Dictionary = {}


static func from_dict(d: Dictionary) -> ClassDef:
	var r: ClassDef = ClassDef.new()
	r.id = str(d.get("id", ""))
	r.name = str(d.get("name", ""))
	r.desc = str(d.get("desc", ""))
	r.for_members = JsonUtil.to_str_array(d.get("for", d.get("for_members", [])))
	r.min_floor = int(d.get("min_floor", 3))
	r.stat_mult = (d.get("stat_mult", {}) as Dictionary).duplicate(true)
	r.growth_add = (d.get("growth_add", {}) as Dictionary).duplicate(true)
	r.passives.assign((d.get("passives", []) as Array).duplicate(true))
	r.learnset.assign((d.get("learnset", []) as Array).duplicate(true))
	if d.has("show_mods"):
		r.show_mods = (d["show_mods"] as Dictionary).duplicate(true)
	r.rt = _norm_rt(d.get("rt", {}))         # Staffeln (contract pass 4)
	return r


func is_for(member_id: String) -> bool:
	return for_members.is_empty() or for_members.has(member_id)


## The filled `rt` block — {} without one; every bar row and every rank complete.
static func _norm_rt(raw: Variant) -> Dictionary:
	var out: Dictionary = RtNorm.fill(raw, RT_SPEC)
	if out.is_empty():
		return out
	var bar: Array = []
	for e: Variant in (out["bar"] as Array):
		bar.append(RtNorm.fill_all(e, PartyMemberDef.RT_BAR_SPEC))
	out["bar"] = bar
	var ranks: Array = []
	for e: Variant in (out["ranks"] as Array):
		ranks.append(RtNorm.fill_all(e, RT_RANK_SPEC))
	out["ranks"] = ranks
	return out
