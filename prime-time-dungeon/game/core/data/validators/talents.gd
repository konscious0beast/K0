extends RefCounted
## Validation rules of talents.json (06 §2.2, 02_TECH §4.4.15) — package B's part of the DataValidator (06 §8.0 Nr. 7:
## one file per new table, called from DataValidator). Static; works on the DataValidator instance `v` (its _norm /
## _err / range helpers and lookup tables). No class_name (preloaded by DataValidator).

const SPEC: Array = [["id", "s"], ["name", "s"], ["desc", "s", ""], ["for", "sa", []], ["max_rank", "i", 1],
	["weight", "i", 1], ["min_level", "i", 3], ["icon", "s"], ["effects", "a"]]
const NAME_MAX: int = 32                    # card title
const DESC_MAX: int = 90                    # at most two card lines (06 §2.2; the Liga talents name their rule)
const MAX_EFFECTS: int = 3
## Fields per effect kind (besides "kind") and the allowed range of its number (06 §2.2 table; all integers).
## [field, type, lo, hi] — type "stat" (DataValidator.STATS), "element" (ELEMENTS without none) or "i".
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
	"liga_stat_pct": [["stat", "stat"], ["pm", "i", 30, 50]],
	"hype_gain_pm": [["pm", "i", 1000, 1200]],
	"follower_pm": [["pm", "i", 1000, 1200]],
}
## IP distance (06 §0.3 Nr. 2): no foot / barefoot words in any talent text (lower-case substrings).
const FORBIDDEN_WORDS: PackedStringArray = ["barfuß", "barfuss", "schuh", "füße", "fuß", "socke"]
## IP distance (orchestrator decision 2026-10-10): no royalty / majesty motif for Graf Mopsula — checked in the texts of
## every entry that is for Mopsula (`for` empty or containing "mopsula"); lower-case substrings.
const MOPSULA_FORBIDDEN_WORDS: PackedStringArray = ["majestät", "majestaet", "majestat"]


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
	var raw_e: Array = d["effects"]
	if raw_e.is_empty() or raw_e.size() > MAX_EFFECTS:
		v._err(ctx + ".effects", "needs 1..%d effects (got %d)" % [MAX_EFFECTS, raw_e.size()])
	var effects: Array[Dictionary] = []
	for i in raw_e.size():
		var e: Dictionary = normalize_effect(v, "%s.effects[%d]" % [ctx, i], raw_e[i])
		if not e.is_empty():
			effects.append(e)
	d["effects"] = effects
	return d


## {"kind", <fields>} with exactly the fields of the kind, every number in its range; {} if unusable.
static func normalize_effect(v: DataValidator, ctx: String, raw: Variant) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		v._err(ctx, "expected object")
		return {}
	var kind: String = str((raw as Dictionary).get("kind", ""))
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
			"element":
				var els: PackedStringArray = DataValidator.ELEMENTS.duplicate()
				els.remove_at(els.find("none"))
				v._enum(ctx + "." + field, str(e[field]), els)
			"i":
				v._range_i(ctx + "." + field, int(e[field]), int(f[2]), int(f[3]))
	return e


## Rule 5 (references): `for` names party members.
static func check_refs(v: DataValidator) -> void:
	var list: Array = v._out.get("talents", [])
	for i in list.size():
		var d: Dictionary = list[i]
		var ctx: String = DataValidator._ctx("talents", i, d)
		for m: String in d["for"]:
			v._ref(ctx + ".for", m, v._party, "party member")


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
