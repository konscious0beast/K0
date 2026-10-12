extends RefCounted
## Validation of the level curve of the seasons (09 §8.2; CR-27; contract pass 4): party.json → exp_table, the EXP each
## level 1–49 needs for the next one (level 50 is the cap of a season, Balance.SEASON_LEVEL_CAP). Optional: without
## the key the table is [] and nothing changes — outside a season Progression.EXP_TABLE and Balance.LEVEL_CAP (10)
## rule as before. Levels 1–9 keep the curve of GDD §4.3 (GDD_EXP, a copy of Progression.EXP_TABLE: core/data must not
## depend on core/progression; test_09_contract4 compares them); from level 10 the curve goes on, strictly rising.
## Private helper of DataValidator (no class_name; preloaded as LevelsCheck; read_exp_table is called while party.json
## is read). Owned by 09-ST1-D (the harness may tune levels 10–49, 09 §8.2).

const GDD_EXP: PackedInt32Array = [33, 73, 131, 205, 292, 393, 506, 632, 769]   # == Progression.EXP_TABLE
const EXP_MAX: int = 1000000
const KEY: String = "exp_table"


## party.json → exp_table into v._out["exp_table"] (PackedInt32Array; [] without the key or when it is broken).
static func read_exp_table(v: DataValidator, f: Dictionary) -> void:
	v._out[KEY] = PackedInt32Array()
	if not f.has(KEY):
		return
	var ctx: String = "party." + KEY
	var conv: Array = v._convert(f[KEY], "ia")
	if not bool(conv[0]):
		v._err(ctx, str(conv[2]))
		return
	var t: PackedInt32Array = conv[1]
	var want: int = DataValidator.SEASON_LEVEL_CAP - 1
	if t.size() != want:
		v._err(ctx, "needs %d entries — the EXP of level 1..%d to the next (got %d)" % [want, want, t.size()])
		return
	var ok: bool = true
	for i in t.size():
		if i < GDD_EXP.size() and t[i] != GDD_EXP[i]:
			v._err("%s[%d]" % [ctx, i], "level %d keeps the GDD §4.3 curve: %d (got %d)" % [i + 1, GDD_EXP[i], t[i]])
			ok = false
		elif t[i] < 1 or t[i] > EXP_MAX:
			v._err("%s[%d]" % [ctx, i], "out of range 1..%d (got %d)" % [EXP_MAX, t[i]])
			ok = false
		elif i > 0 and t[i] <= t[i - 1]:
			v._err("%s[%d]" % [ctx, i], "must rise from level to level (%d after %d)" % [t[i], t[i - 1]])
			ok = false
	if ok:
		v._out[KEY] = t
