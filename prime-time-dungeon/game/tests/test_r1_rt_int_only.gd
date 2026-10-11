extends TestCase
## 07 §3.14 Nr. 1 / §12.5 test_r1_rt_int_only: core/rt computes with integers only — no `float`, no sqrt( / pow( /
## other float functions, no decimal or exponent literals; the one exception is the isqrt line of DetMath
## ("# det-ok: exact integer sqrt with correction"). Comments and strings do not count (same stripper as the M8 lint).
## Plus: everything the sim hands out (snapshot, events, setup) is float-free canonical data (07 §3.14 Nr. 6).

const Lint := preload("res://tests/test_m8_no_global_rng.gd")
const DIR: String = "res://core/rt"
const ISQRT_OK: String = "det-ok: exact integer sqrt with correction"
const RULES: Array = [
	["float", "\\bfloat\\b"],
	["sqrt_pow", "(?<![\\w])(sqrt|pow)\\s*\\("],
	["float_func", "(?<![\\w.])(floorf|ceilf|roundf|absf|clampf|maxf|minf|signf|fmod|fposmod|lerpf|snappedf|is_finite|"
		+ "is_nan|is_inf|deg_to_rad|rad_to_deg|sin|cos|tan|asin|acos|atan|atan2|exp|log|roundi|floori|ceili)\\s*\\("],
	["decimal", "(?<![\\w.])\\d+\\.\\d*(?![\\w])|(?<![\\w.\\d])\\.\\d+"],
	["exponent", "(?<![\\w.])\\d+[eE][+-]?\\d+"],
]


## [{"line", "rule", "code"}] of one source text.
static func scan(text: String) -> Array[Dictionary]:
	var res: Array = []
	for r: Array in RULES:
		res.append([r[0], RegEx.create_from_string(r[1])])
	var out: Array[Dictionary] = []
	var triple: String = ""
	var lines: PackedStringArray = text.split("\n")
	for n in lines.size():
		var parsed: Array = Lint._strip(lines[n], triple)
		triple = parsed[2]
		if str(parsed[1]).contains(ISQRT_OK):
			continue
		for r: Array in res:
			if (r[1] as RegEx).search(str(parsed[0])) != null:
				out.append({"line": n + 1, "rule": r[0], "code": lines[n].strip_edges()})
	return out


func test_core_rt_is_integer_only() -> void:
	var d: DirAccess = DirAccess.open(DIR)
	assert_not_null(d, DIR)
	if d == null:
		return
	var problems: PackedStringArray = []
	var files: int = 0
	var exceptions: int = 0
	for f: String in d.get_files():
		if not f.ends_with(".gd"):
			continue
		files += 1
		var text: String = FileAccess.get_file_as_string(DIR.path_join(f))
		exceptions += text.count(ISQRT_OK)
		for hit: Dictionary in scan(text):
			problems.append("%s:%d: %s — %s" % [f, hit["line"], hit["rule"], hit["code"]])
	assert_gt(files, 14, "core/rt scanned")
	assert_eq(problems, PackedStringArray(), "float math in core/rt:\n" + "\n".join(problems))
	assert_eq(exceptions, 1, "exactly one exception: DetMath.isqrt")
	assert_true(FileAccess.get_file_as_string(DIR.path_join("det_math.gd")).contains(ISQRT_OK))


func test_scanner_rules() -> void:
	var src: String = "\n".join(PackedStringArray([
		"var a: float = 1",                         # 1 float
		"var b: int = 3 * 2",                       # ok
		"var c = sqrt(9)",                          # 3 sqrt
		"var d = 1.5",                              # 4 decimal
		"var e = x.y + v.size()",                   # ok: member access
		"# 0.5 in a comment",                       # ok
		"var f = \"1.5 sqrt( float\"",              # ok: string
		"var g = roundi(h)",                        # 8 float_func
		"var i = 2e3",                              # 9 exponent
		"var j = int(sqrt(n))  # " + ISQRT_OK,      # ok: the one exception
		"var k = DetMath.isqrt(n)",                 # ok
		"var l = absi(m) + maxi(1, 2)",             # ok: integer helpers
		"var o = .5",                               # 13 decimal
	]))
	var got: Array = []
	for f: Dictionary in scan(src):
		got.append([f["line"], f["rule"]])
	assert_eq(got, [[1, "float"], [3, "sqrt_pow"], [4, "decimal"], [8, "float_func"], [9, "exponent"],
		[13, "decimal"]])


## Snapshot, events and setup of a running combat contain no float at all (canonical JSON, 07 §3.14 Nr. 6).
func test_sim_output_is_float_free() -> void:
	var st: GameState = RtKit.state(6, "kai", {"itm_brutzel_burger": 1})
	var sim: RtSim = RtKit.sim(RtKit.encounter("enc_rt_rats", [["g1", "enc_rt_rats", [0, -300, 128]]]), 6, "kai", st)
	assert_not_null(sim)
	if sim == null:
		return
	var events: Array[ActionEvent] = []
	sim.submit(RtCommand.target(0, "p0", "e0"))
	sim.submit(RtCommand.ability(0, "p0", "skl_kai_sweep", ""))
	for c in 900:
		if c == 100:
			sim.submit(RtCommand.item(sim.tick(), "p0", "itm_brutzel_burger", ""))
		if c == 200:
			sim.submit(RtCommand.ability(sim.tick(), "p0", "skl_stunt_kai_suplex", ""))
		events.append_array(sim.step())
		if sim.is_finished():
			break
	assert_true(sim.is_finished(), "the fight ends")
	assert_eq(_floats(sim.snapshot(), "snapshot"), PackedStringArray())
	assert_eq(_floats(sim.setup.to_dict(), "setup"), PackedStringArray())
	var bad: PackedStringArray = []
	for e: ActionEvent in events:
		bad.append_array(_floats(e.to_dict(), ActionEvent.type_name(e.type)))
	assert_eq(bad, PackedStringArray())
	assert_true(StateHash.of_rt(sim).length() == 64, "canonically hashable")


static func _floats(v: Variant, path: String) -> PackedStringArray:
	var out: PackedStringArray = []
	match typeof(v):
		TYPE_FLOAT:
			out.append(path)
		TYPE_DICTIONARY:
			for k: Variant in (v as Dictionary).keys():
				out.append_array(_floats((v as Dictionary)[k], "%s.%s" % [path, str(k)]))
		TYPE_ARRAY:
			var a: Array = v
			for i in a.size():
				out.append_array(_floats(a[i], "%s[%d]" % [path, i]))
	return out
