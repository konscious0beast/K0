class_name TalentDef extends RefCounted
## talents.json entry (02_TECH §4.4.15, 06 §2.2): one perk of the level-up "Talent-Show". Immutable after loading.
## effects: 1..3 × {"kind": <TalentDef.KINDS>, <fields of the kind>} — integers only (stat values, per-mille factors).

## Effect kinds and their fields (06 §2.2). "Value" kinds change numbers, "behaviour" kinds change how something plays.
const KINDS: PackedStringArray = ["stat_flat", "stat_pct", "crit_add_pm", "element_pm", "post_battle_mp_pm",
	"field_range_pm", "field_cd_pm", "preemptive_dmg_pm", "stunt_window_pm", "marotte_heart", "liga_stat_pct",
	"hype_gain_pm", "follower_pm"]
const BEHAVIOUR_KINDS: PackedStringArray = ["field_range_pm", "field_cd_pm", "preemptive_dmg_pm", "stunt_window_pm",
	"marotte_heart", "liga_stat_pct"]
const ICONS: PackedStringArray = ["hp", "mp", "atk", "mag", "def", "res", "spd", "lck", "crit", "element", "show",
	"field", "stunt", "liga"]

var id: String = ""
var name: String = ""
var desc: String = ""
var for_members: PackedStringArray = []     # JSON key "for"; [] = all
var max_rank: int = 1
var weight: int = 1
var min_level: int = 3
var icon: String = ""
var effects: Array[Dictionary] = []


static func from_dict(d: Dictionary) -> TalentDef:
	var r: TalentDef = TalentDef.new()
	r.id = str(d.get("id", ""))
	r.name = str(d.get("name", ""))
	r.desc = str(d.get("desc", ""))
	r.for_members = JsonUtil.to_str_array(d.get("for", d.get("for_members", [])))
	r.max_rank = int(d.get("max_rank", 1))
	r.weight = int(d.get("weight", 1))
	r.min_level = int(d.get("min_level", 3))
	r.icon = str(d.get("icon", ""))
	r.effects.assign((d.get("effects", []) as Array).duplicate(true))
	return r


func is_for(member_id: String) -> bool:
	return for_members.is_empty() or for_members.has(member_id)


## True if any effect changes behaviour (field ability, first strike, stunts, show bets, Liga) instead of a number.
func is_behaviour() -> bool:
	for e: Dictionary in effects:
		if BEHAVIOUR_KINDS.has(str(e.get("kind", ""))):
			return true
	return false
