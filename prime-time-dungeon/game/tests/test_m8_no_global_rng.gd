extends TestCase
## Determinism lint (Brief §6b.1, 05 §3.3 Nr. 5/6, §11.4): res://core/**/*.gd must not use the global RNG
## (randf(, randi(, randomize(, randf_range(/randi_range( without object prefix, seed(), any randf / randfn even with a
## prefix), the clock (Time., OS.get_ticks), libm float math (pow(, exp(, sin(, cos(, atan2(, lerp…() or autoloads /
## the SceneTree (02_TECH §0.4). Comments and string literals are ignored; a line may opt out with a whitelist comment
## `# det-ok: <reason>` (display-only helpers). Findings are reported as "file:line: rule — code".
##
## TOLERATED: findings in files of other modules that predate the lint (a maximum per file and rule — any additional
## finding fails). Empty since the integration phase: FloorEvent chances draw in basis points and the procedural
## chest offsets in centimeters (05 CR-12), so no file in core/ uses float randomness any more.

const ROOT: String = "res://core"
const TOLERATED: Dictionary = {}
const RULES: Array = [
	["global_rng", "(?<![\\w.])(randf|randi|randomize|randf_range|randi_range|randfn|seed)\\s*\\("],
	["randf", "randf"],
	["clock", "(?<![\\w.])(Time\\s*\\.|OS\\s*\\.\\s*get_ticks)"],
	["float_math", "(?<![\\w])(pow|exp|sin|cos|atan2)\\s*\\("],
	["lerp", "[A-Za-z_]*lerp[A-Za-z_]*\\s*\\("],
	["autoload", "(?<![\\w.])(Events|DB|Game|Show|Save|Router|Sfx)\\s*\\.|get_tree\\s*\\(|Engine\\s*\\.\\s*get_main_loop"],
]

var _compiled: Array = []


func _rules() -> Array:
	if _compiled.is_empty():
		for r: Array in RULES:
			_compiled.append([r[0], RegEx.create_from_string(r[1])])
	return _compiled


## [{"line": int, "rule": String, "code": String}] for one source text.
func scan_source(text: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var in_triple: String = ""
	var lines: PackedStringArray = text.split("\n")
	for n in lines.size():
		var parsed: Array = _strip(lines[n], in_triple)
		var code: String = parsed[0]
		var comment: String = parsed[1]
		in_triple = parsed[2]
		if comment.contains("det-ok:"):
			continue
		for r: Array in _rules():
			if (r[1] as RegEx).search(code) != null:
				out.append({"line": n + 1, "rule": str(r[0]), "code": lines[n].strip_edges()})
	return out


## [code without strings/comments, comment text, open triple-quote delimiter carried to the next line].
static func _strip(line: String, triple: String) -> Array:
	var code: String = ""
	var i: int = 0
	var n: int = line.length()
	while i < n:
		if triple != "":
			var end: int = line.find(triple, i)
			if end < 0:
				return [code, "", triple]
			i = end + 3
			triple = ""
			code += "\"\""
			continue
		var ch: String = line[i]
		if ch == "#":
			return [code, line.substr(i), ""]
		if ch == "\"" or ch == "'":
			if line.substr(i, 3) == ch.repeat(3):
				triple = ch.repeat(3)
				i += 3
				continue
			var j: int = i + 1
			while j < n:
				if line[j] == "\\":
					j += 2
					continue
				if line[j] == ch:
					break
				j += 1
			i = j + 1
			code += "\"\""
			continue
		code += ch
		i += 1
	return [code, "", triple]


func _core_files() -> PackedStringArray:
	var out: PackedStringArray = []
	_collect(ROOT, out)
	out.sort()
	return out


func _collect(dir_path: String, out: PackedStringArray) -> void:
	var d: DirAccess = DirAccess.open(dir_path)
	if d == null:
		return
	for sub: String in d.get_directories():
		_collect(dir_path.path_join(sub), out)
	for f: String in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir_path.path_join(f))


func test_core_is_deterministic() -> void:
	var files: PackedStringArray = _core_files()
	assert_gt(files.size(), 50, "core scripts found")
	var problems: PackedStringArray = []
	for path: String in files:
		var findings: Array[Dictionary] = scan_source(FileAccess.get_file_as_string(path))
		var per_rule: Dictionary = {}
		for f: Dictionary in findings:
			per_rule[f["rule"]] = int(per_rule.get(f["rule"], 0)) + 1
		var allowed: Dictionary = TOLERATED.get(path, {})
		for f: Dictionary in findings:
			if int(per_rule[f["rule"]]) > int(allowed.get(f["rule"], 0)):
				problems.append("%s:%d: %s — %s" % [path, f["line"], f["rule"], f["code"]])
	assert_eq(problems, PackedStringArray(), "non-deterministic code in core/:\n" + "\n".join(problems))


func test_live_core_has_no_exceptions() -> void:
	for path: String in _core_files():
		if path.begins_with("res://core/live/"):
			assert_false(TOLERATED.has(path), path)
			var findings: Array[Dictionary] = scan_source(FileAccess.get_file_as_string(path))
			assert_eq(findings, [], path)
			assert_false(FileAccess.get_file_as_string(path).contains("det-ok:"), path + " needs no whitelist")


func test_tolerated_entries_still_exist() -> void:
	for path: String in TOLERATED.keys():
		assert_true(FileAccess.file_exists(path), path)
		var count: Dictionary = {}
		for f: Dictionary in scan_source(FileAccess.get_file_as_string(path)):
			count[f["rule"]] = int(count.get(f["rule"], 0)) + 1
		for rule: String in (TOLERATED[path] as Dictionary).keys():
			if int(count.get(rule, 0)) < int(TOLERATED[path][rule]):
				print("[test_m8_no_global_rng] %s: only %d × %s left — the allowance can shrink" % [path,
					int(count.get(rule, 0)), rule])


func test_scanner_rules() -> void:
	var src: String = "\n".join(PackedStringArray([
		"var a: float = randf()",                          # 1 global_rng + randf
		"var b: int = rng.randi_range(0, 3)",              # ok: seeded rng with prefix
		"var c: int = randi_range(0, 3)",                  # 3 global_rng
		"var d: bool = rng.randf() < 0.5",                 # 4 randf (prefix does not help)
		"# randf() in a comment is fine",                  # ok
		"var e: String = \"randf() Time.now pow(\"",       # ok: string literal
		"var f: float = pow(2.0, 3.0)",                    # 7 float_math
		"m.exp = add_exp(m, 3)",                           # ok: identifiers, not exp()
		"var g: int = Time.get_ticks_msec()",              # 9 clock
		"var h: float = lerp(0.0, 1.0, t)  # det-ok: display only",   # ok: whitelisted
		"var i: GameState = Game.state",                   # 11 autoload
		"var k: RoomCell.Kind = RoomCell.Kind.STAIRS",     # ok
		"var s: String = \"\"\"multi",                     # opens a triple-quoted string
		"randf() inside the string",                       # ok: still inside the string
		"\"\"\" + str(sin(x))",                            # 15 float_math after the string closed
		"seed(42)",                                        # 16 global_rng
		"rng.seed = 42",                                   # ok
		"var t: SceneTree = get_tree()",                   # 18 autoload
		"x = inverse_lerp(a, b, c)",                       # 19 lerp
	]))
	var got: Array = []
	for f: Dictionary in scan_source(src):
		got.append([f["line"], f["rule"]])
	assert_eq(got, [[1, "global_rng"], [1, "randf"], [3, "global_rng"], [4, "randf"], [7, "float_math"],
		[9, "clock"], [11, "autoload"], [15, "float_math"], [16, "global_rng"], [18, "autoload"], [19, "lerp"]])
