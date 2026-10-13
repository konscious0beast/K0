class_name TalentDef extends RefCounted
## talents.json entry (02_TECH §4.4.15, 06 §2.2): one perk of the level-up "Talent-Show". Immutable after loading.
## effects: 1..3 × {"kind": <TalentDef.KINDS>, <fields of the kind>} — integers only (stat values, per-mille factors).
## Staffeln (09 §8.4; contract pass 4): a talent with `row` > 0 is a talent of the talent tree — one of three (`col`
## 1 left, 2 middle, 3 right) in the row opening at level `row` of its `tree` (a party member's base and figure rows,
## a class's class rows); `spec` names the branch (Spezialisierung) of an outer column of a class row. row 0 = a talent
## of the 06-B pool (the offer of the Talent-Show), as every talent today. ST1-D builds the tree on these fields.

## Effect kinds and their fields (06 §2.2). "Value" kinds change numbers, "behaviour" kinds change how something plays.
const KINDS: PackedStringArray = ["stat_flat", "stat_pct", "crit_add_pm", "element_pm", "post_battle_mp_pm",
	"field_range_pm", "field_cd_pm", "preemptive_dmg_pm", "stunt_window_pm", "marotte_heart", "liga_stat_pct",
	"hype_gain_pm", "follower_pm"]
const BEHAVIOUR_KINDS: PackedStringArray = ["field_range_pm", "field_cd_pm", "preemptive_dmg_pm", "stunt_window_pm",
	"marotte_heart", "liga_stat_pct"]
const ICONS: PackedStringArray = ["hp", "mp", "atk", "mag", "def", "res", "spd", "lck", "crit", "element", "show",
	"field", "stunt", "liga"]
## The rows of the talent tree by the level they open at (09 §8.4): base rows and figure rows of a party member (tree =
## member id), class rows of a class (tree = cls_ id).
const BASE_ROWS: PackedInt32Array = [3, 5, 7, 9]
const CLASS_ROWS: PackedInt32Array = [15, 25, 35, 45]
const FIGURE_ROWS: PackedInt32Array = [20, 30, 40, 50]
const COLS: int = 3                         # one of three per row
## Effect kinds only a tree talent may have (09 §8.4, 07 CR-32 b): {"kind": "rt_mod", "op", <the op's fields>} — a
## static modifier of the talent's own unit in the real-time combat (RtMods, source talent:<id>, ST1-D).
const TREE_KINDS: PackedStringArray = ["rt_mod"]

var id: String = ""
var name: String = ""
var desc: String = ""
var for_members: PackedStringArray = []     # JSON key "for"; [] = all
var max_rank: int = 1
var weight: int = 1
var min_level: int = 3
var icon: String = ""
var effects: Array[Dictionary] = []
# --- Staffeln (09 §8.4; contract pass 4) ---
var row: int = 0                            # 0 = 06-B pool; else the level the row opens at (BASE/CLASS/FIGURE_ROWS)
var col: int = 0                            # 1..COLS in a row (left = branch A, middle = show / allround, right = B)
var tree: String = ""                       # party member id (base / figure rows) or cls_ id (class rows)
var spec: String = ""                       # branch of an outer column of a class row ("" elsewhere)


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
	r.row = int(d.get("row", 0))             # Staffeln (contract pass 4)
	r.col = int(d.get("col", 0))
	r.tree = str(d.get("tree", ""))
	r.spec = str(d.get("spec", ""))
	return r


func is_for(member_id: String) -> bool:
	return for_members.is_empty() or for_members.has(member_id)


## True if any effect changes behaviour (field ability, first strike, stunts, show bets, Liga) instead of a number.
func is_behaviour() -> bool:
	for e: Dictionary in effects:
		if BEHAVIOUR_KINDS.has(str(e.get("kind", ""))):
			return true
	return false


## A talent of the talent tree (09 §8.4), not of the 06-B pool.
func is_tree() -> bool:
	return row > 0


## Every row of the tree, ascending (3, 5, 7, 9, 15, 20, 25 … 50).
static func tree_rows() -> PackedInt32Array:
	var out: Array = Array(BASE_ROWS) + Array(CLASS_ROWS) + Array(FIGURE_ROWS)
	out.sort()
	return PackedInt32Array(out)
