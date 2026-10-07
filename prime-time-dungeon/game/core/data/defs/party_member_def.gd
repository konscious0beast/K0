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
	return r
