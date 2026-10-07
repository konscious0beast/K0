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
	"sponsor_thresholds": PackedInt32Array([50, 75, 100])}


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
	return r


func is_for(member_id: String) -> bool:
	return for_members.is_empty() or for_members.has(member_id)
