extends RefCounted
## Validation rules of talents.json (06 §2.2, 02_TECH §4.4.15) — package B's part of the DataValidator (06 §8.0 Nr. 7:
## one file per new table, called from DataValidator). Static; works on the DataValidator instance `v` (its _norm /
## _err / range helpers and lookup tables). No class_name (preloaded by DataValidator).
## Staffeln (09 §8.4; contract pass 4, ST1-D builds on it): the talent tree fields `row`, `col`, `tree`, `spec`
## (TalentDef) — a tree talent sits in exactly one cell (tree, row, col), every row of a tree has all three columns,
## the outer columns of a class row carry the class's two branches, its effects may hold what two ranks of a 06-B talent
## held (TREE_RANGES) and the tree-only kind `rt_mod` (a static modifier of the own unit, RtMods). row 0 (the default)
## is a talent of the 06-B pool with the rules of before.

const SPEC: Array = [["id", "s"], ["name", "s"], ["desc", "s", ""], ["for", "sa", []], ["max_rank", "i", 1],
	["weight", "i", 1], ["min_level", "i", 3], ["icon", "s"], ["effects", "a"],
	["row", "i", 0], ["col", "i", 0], ["tree", "s", ""], ["spec", "s", ""]]     # Staffeln (contract pass 4)
const NAME_MAX: int = 32                    # card title
const DESC_MAX: int = 90                    # at most two card lines (06 §2.2; the Liga talents name their rule)
const MAX_EFFECTS: int = 3
## Fields per effect kind (besides "kind") and the allowed range of its number (06 §2.2 table; all integers).
## [field, type, lo, hi] — type "stat" (DataValidator.STATS), "battle_stat" (STATS without hp / mp), "element"
## (ELEMENTS without none) or "i".
const KIND_FIELDS: Dictionary = {
	"stat_flat": [["stat", "stat"], ["value", "i", 1, 3]],
	"stat_pct": [["stat", "stat"], ["pm", "i", 30, 50]],
	"crit_add_pm": [["pm", "i", 10, 30]],
	"element_pm": [["element", "element"], ["pm", "i", 700, 1000]],
	"post_battle_mp_pm": [["pm", "i", 30, 50]],
	"field_range_pm": [["pm", "i", 1000, 1500]],
	"field_cd_pm": [["pm", "i", 500, 1000]],
	"preemptive_dmg_pm": [["pm", "i", 1000, 1200]],
	"stunt_window_pm": [["pm", "i", 1000, 1250]],
	"marotte_heart": [["per_floor", "i", 1, 1]],
	"liga_stat_pct": [["stat", "battle_stat"], ["pm", "i", 30, 50]],   # 06 B × C: never HP / MP (see LIGA_STATS)
	"hype_gain_pm": [["pm", "i", 1000, 1200]],
	"follower_pm": [["pm", "i", 1000, 1200]],
}
## liga_stat_pct follows package C's Liga tier, which only exists in battle (and the UI): max HP / MP stay
## member-local, so a Liga talent may only raise the battle stats.
const LIGA_STATS: PackedStringArray = ["str", "mag", "def", "res", "spd", "lck"]
## IP distance (06 §0.3 Nr. 2): no foot / barefoot words in any talent text (lower-case substrings).
const FORBIDDEN_WORDS: PackedStringArray = ["barfuß", "barfuss", "schuh", "füße", "fuß", "socke"]
## IP distance (orchestrator decision 2026-10-10): no royalty / majesty motif for Graf Mopsula — checked in the texts of
## every entry that is for Mopsula (`for` empty or containing "mopsula"); lower-case substrings.
const MOPSULA_FORBIDDEN_WORDS: PackedStringArray = ["majestät", "majestaet", "majestat"]
# --- Staffeln (09 §8.4; contract pass 4) ------------------------------------------------------------------------------
## The number range of a value kind in a tree talent: a tree talent holds what two ranks held (09 §8.4: "Wischtechnik
## STR +2 statt 2 × +1", stat_pct up to 100 ‰, crit_add_pm up to 60, post_battle_mp_pm up to 100); every other kind
## keeps its KIND_FIELDS range. The caps over a whole tree are ST1-D's test (09 §8.4 "Deckel").
const TREE_RANGES: Dictionary = {"stat_flat": [1, 6], "stat_pct": [30, 100], "crit_add_pm": [10, 60],
	"post_battle_mp_pm": [30, 100]}
## The ops of an rt_mod effect: the RtVocab.MOD_OPS that act on the talent's own unit (07 §9.5).
const TREE_MOD_OPS: PackedStringArray = ["stat_pm", "skill_pm", "move_pm", "swing_pm", "threat_pm", "dmg_dealt_pm",
	"dmg_taken_pm", "heal_taken_pm", "first_hit_taken_pm", "on"]
## A branch (Spezialisierung) id on a talent of a class row.
const SPEC_ID: String = "^[a-z][a-z0-9_]*$"
const RtNorm := preload("res://core/data/defs/rt_norm.gd")


## Normalized talent entry ({} if not an object). Errors go to v.errors.
static func normalize(v: DataValidator, ctx: String, raw: Variant) -> Dictionary:
	var d: Dictionary = v._norm(ctx, raw, SPEC)
	if d.is_empty():
		return d
	check_text(v, ctx + ".name", str(d["name"]), NAME_MAX, is_for_mopsula(d))
	check_text(v, ctx + ".desc", str(d["desc"]), DESC_MAX, is_for_mopsula(d))
	v._range_i(ctx + ".max_rank", int(d["max_rank"]), 1, 2)
	v._range_i(ctx + ".weight", int(d["weight"]), 1, 10)
	v._range_i(ctx + ".min_level", int(d["min_level"]), 3, 99)
	v._enum(ctx + ".icon", str(d["icon"]), TalentDef.ICONS)
	var tree_talent: bool = _check_cell(v, ctx, d)               # Staffeln (contract pass 4)
	var raw_e: Array = d["effects"]
	if raw_e.is_empty() or raw_e.size() > MAX_EFFECTS:
		v._err(ctx + ".effects", "needs 1..%d effects (got %d)" % [MAX_EFFECTS, raw_e.size()])
	var effects: Array[Dictionary] = []
	for i in raw_e.size():
		var e: Dictionary = normalize_effect(v, "%s.effects[%d]" % [ctx, i], raw_e[i], tree_talent, str(d["id"]))
		if not e.is_empty():
			effects.append(e)
	d["effects"] = effects
	return d


## {"kind", <fields>} with exactly the fields of the kind, every number in its range; {} if unusable. A tree talent
## (`tree`) uses TREE_RANGES and may hold the kind rt_mod (`talent_id` names the source talent:<id> of its mod).
static func normalize_effect(v: DataValidator, ctx: String, raw: Variant, tree: bool = false,
		talent_id: String = "") -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		v._err(ctx, "expected object")
		return {}
	var kind: String = str((raw as Dictionary).get("kind", ""))
	if TalentDef.TREE_KINDS.has(kind):
		if not tree:
			v._err(ctx + ".kind", "'%s' only for a talent of the talent tree (row > 0, 09 §8.4)" % kind)
			return {}
		return _rt_mod_effect(v, ctx, raw as Dictionary, talent_id)
	if not KIND_FIELDS.has(kind):
		v._err(ctx + ".kind", "'%s' not in [%s]" % [kind, ", ".join(TalentDef.KINDS)])
		return {}
	var spec: Array = [["kind", "s"]]
	for f: Array in KIND_FIELDS[kind]:
		spec.append([f[0], "s" if str(f[1]) != "i" else "i"])
	var e: Dictionary = v._norm(ctx, raw, spec)
	if e.is_empty():
		return e
	for f: Array in KIND_FIELDS[kind]:
		var field: String = str(f[0])
		match str(f[1]):
			"stat":
				v._enum(ctx + "." + field, str(e[field]), DataValidator.STATS)
			"battle_stat":
				v._enum(ctx + "." + field, str(e[field]), LIGA_STATS)
			"element":
				var els: PackedStringArray = DataValidator.ELEMENTS.duplicate()
				els.remove_at(els.find("none"))
				v._enum(ctx + "." + field, str(e[field]), els)
			"i":
				var lo_hi: Array = TREE_RANGES[kind] if tree and TREE_RANGES.has(kind) else [f[2], f[3]]
				v._range_i(ctx + "." + field, int(e[field]), int(lo_hi[0]), int(lo_hi[1]))
	return e


## Rule 5 (references): `for` names party members. Staffeln (contract pass 4): the tree of a tree talent (a party
## member for base / figure rows — the talent is for exactly that member —, a class for class rows — the talent is for
## members of the class), one talent per cell, three columns per row, two branches per class (left and right), the
## skills and statuses an rt_mod names.
static func check_refs(v: DataValidator) -> void:
	var list: Array = v._out.get("talents", [])
	var cells: Dictionary = {}                     # "tree|row|col" → talent id
	var rows: Dictionary = {}                      # "tree|row" → {col: true}
	var branches: Dictionary = {}                  # "tree|col" → spec (class rows)
	for i in list.size():
		var d: Dictionary = list[i]
		var ctx: String = DataValidator._ctx("talents", i, d)
		for m: String in d["for"]:
			v._ref(ctx + ".for", m, v._party, "party member")
		var row: int = int(d["row"])
		if row <= 0:
			continue
		var tree: String = str(d["tree"])
		var members: PackedStringArray = d["for"]
		if TalentDef.CLASS_ROWS.has(row):
			if v._ref(ctx + ".tree", tree, v._classes, "class"):
				var cls_for: PackedStringArray = (v._classes[tree] as Dictionary)["for"]
				if members.is_empty():
					v._err(ctx + ".for", "a class row talent names its members (those of class '%s')" % tree)
				for m: String in members:
					if not cls_for.is_empty() and not cls_for.has(m):
						v._err(ctx + ".for", "class '%s' is not for '%s'" % [tree, m])
		elif v._ref(ctx + ".tree", tree, v._party, "party member") and members != PackedStringArray([tree]):
			v._err(ctx + ".for", "a talent of %s's tree is for [\"%s\"] (got %s)" % [tree, tree, str(Array(members))])
		var cell: String = "%s|%d|%d" % [tree, row, int(d["col"])]
		if cells.has(cell):
			v._err(ctx + ".col", "row %d column %d of '%s' is taken by '%s'" % [row, int(d["col"]), tree,
				str(cells[cell])])
		cells[cell] = str(d["id"])
		var rk: String = "%s|%d" % [tree, row]
		if not rows.has(rk):
			rows[rk] = {}
		(rows[rk] as Dictionary)[int(d["col"])] = true
		if str(d["spec"]) != "":
			var bk: String = "%s|%d" % [tree, int(d["col"])]
			if branches.has(bk) and str(branches[bk]) != str(d["spec"]):
				v._err(ctx + ".spec", "column %d of '%s' is the branch '%s' (got '%s')" % [int(d["col"]), tree,
					str(branches[bk]), str(d["spec"])])
			branches[bk] = str(d["spec"])
		for j in (d["effects"] as Array).size():
			_rt_mod_refs(v, "%s.effects[%d]" % [ctx, j], (d["effects"] as Array)[j])
	var keys: Array = rows.keys()
	keys.sort()
	for rk: Variant in keys:
		if (rows[rk] as Dictionary).size() != TalentDef.COLS:
			v._err("talents", "row %s of the tree '%s' needs all %d columns (1 of %d, 09 §8.4; has %s)" % [
				str(rk).get_slice("|", 1), str(rk).get_slice("|", 0), TalentDef.COLS, TalentDef.COLS,
				str((rows[rk] as Dictionary).keys())])
	for bk: Variant in branches.keys():
		var tree_id: String = str(bk).get_slice("|", 0)
		var right: String = "%s|%d" % [tree_id, TalentDef.COLS]
		if int(str(bk).get_slice("|", 1)) == 1 and branches.has(right) and str(branches[right]) == str(branches[bk]):
			v._err("talents", "'%s': the left and the right column are two branches (both '%s')" % [tree_id,
				str(branches[bk])])


## Length, foot words (everyone) and — `for_mopsula` — the majesty words (Graf Mopsula's texts).
static func check_text(v: DataValidator, ctx: String, text: String, max_len: int, for_mopsula: bool = false) -> void:
	if text.length() > max_len:
		v._err(ctx, "longer than %d characters (%d)" % [max_len, text.length()])
	var low: String = text.to_lower()
	for w: String in FORBIDDEN_WORDS:
		if low.contains(w):
			v._err(ctx, "contains '%s' (06 §0.3: no foot words)" % w)
	if for_mopsula:
		for w: String in MOPSULA_FORBIDDEN_WORDS:
			if low.contains(w):
				v._err(ctx, "contains '%s' (no majesty motif for Graf Mopsula)" % w)


## The entry (talent or species) is for Graf Mopsula: `for` is empty (everyone) or contains "mopsula".
static func is_for_mopsula(d: Dictionary) -> bool:
	var members: PackedStringArray = d.get("for", PackedStringArray())
	return members.is_empty() or members.has("mopsula")


# --- Staffeln (09 §8.4; contract pass 4) ------------------------------------------------------------------------------

## The cell rules of one entry; true for a talent of the tree. row 0: no col / tree / spec. row > 0: a row of
## TalentDef.tree_rows(), col 1..3, a tree, max_rank 1 (the ranks went into one value), min_level = row, a branch only
## in the outer columns of a class row (and there always).
static func _check_cell(v: DataValidator, ctx: String, d: Dictionary) -> bool:
	var row: int = int(d["row"])
	if row == 0:
		for k: String in ["col", "tree", "spec"]:
			if (k == "col" and int(d[k]) != 0) or (k != "col" and str(d[k]) != ""):
				v._err(ctx + "." + k, "only for a talent of the talent tree (row > 0, 09 §8.4)")
		return false
	if not TalentDef.tree_rows().has(row):
		v._err(ctx + ".row", "%d is no row of the talent tree (%s)" % [row, str(Array(TalentDef.tree_rows()))])
	v._range_i(ctx + ".col", int(d["col"]), 1, TalentDef.COLS)
	if str(d["tree"]) == "":
		v._err(ctx + ".tree", "a tree talent names its tree (party member or cls_)")
	if int(d["max_rank"]) != 1:
		v._err(ctx + ".max_rank", "1 in the talent tree (the ranks became one value, 09 §8.4)")
	if int(d["min_level"]) != row:
		v._err(ctx + ".min_level", "the level of its row (%d)" % row)
	var spec: String = str(d["spec"])
	var outer: bool = TalentDef.CLASS_ROWS.has(row) and (int(d["col"]) == 1 or int(d["col"]) == TalentDef.COLS)
	if outer and spec == "":
		v._err(ctx + ".spec", "the outer columns of a class row carry the class's branch (09 §8.4)")
	elif not outer and spec != "":
		v._err(ctx + ".spec", "a branch only on the left / right column of a class row (15/25/35/45)")
	elif spec != "" and not v._matches(SPEC_ID, spec):
		v._err(ctx + ".spec", "invalid branch id '%s' (%s)" % [spec, SPEC_ID])
	return true


## {"kind": "rt_mod", "op", <fields of the op>}: an op of TREE_MOD_OPS, the shape of RtMods.validate (types, fields,
## vocabularies, pm 0..5000) with the source talent:<id> on the talent's own unit — `src` and `unit` are the talent's,
## never written in the data.
static func _rt_mod_effect(v: DataValidator, ctx: String, raw: Dictionary, talent_id: String) -> Dictionary:
	var e: Dictionary = raw.duplicate(true)
	var op: String = str(e.get("op", ""))
	if not TREE_MOD_OPS.has(op):
		v._err(ctx + ".op", "'%s' not in [%s]" % [op, ", ".join(TREE_MOD_OPS)])
		return {}
	for k: String in ["src", "unit"]:
		if e.has(k):
			v._err(ctx + "." + k, "set by the talent (source talent:<id>, its own unit)")
	var mod: Dictionary = e.duplicate(true)
	mod.erase("kind")
	mod["src"] = "talent:" + (talent_id if talent_id != "" else "tal_?")
	mod["unit"] = "p0"
	for p: String in RtMods.validate([mod]):
		v.errors.append(ctx + p.substr("mods[0]".length()))
	return RtNorm.ints(e) as Dictionary


## Rule 5 of an rt_mod effect: a skill_pm skill id (not a selector) and an on-effect status exist.
static func _rt_mod_refs(v: DataValidator, ctx: String, e: Variant) -> void:
	if not (e is Dictionary) or str((e as Dictionary).get("kind", "")) != "rt_mod":
		return
	var m: Dictionary = e
	var skill: String = str(m.get("skill", ""))
	if str(m.get("op", "")) == "skill_pm" and skill.begins_with("skl_"):
		v._ref(ctx + ".skill", skill, v._skills, "skill")
	var eff: Variant = m.get("effect", {})
	if eff is Dictionary and (eff as Dictionary).has("status"):
		v._ref(ctx + ".effect.status", str((eff as Dictionary)["status"]), v._statuses, "status")
