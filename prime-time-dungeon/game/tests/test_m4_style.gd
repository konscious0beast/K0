extends TestCase
## M4 code style (02_TECH §13.1): lines ≤ 120 characters (tabs count as one) in every art/** script and shader and in
## the M4 test files.

const LIMIT: int = 120
const ROOTS: PackedStringArray = ["res://art"]
const EXTENSIONS: PackedStringArray = ["gd", "gdshader", "gdshaderinc"]


func _collect(dir_path: String, out: PackedStringArray) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	for f: String in dir.get_files():
		if EXTENSIONS.has(f.get_extension()):
			out.append(dir_path.path_join(f))
	for d: String in dir.get_directories():
		_collect(dir_path.path_join(d), out)


func test_line_length_of_m4_files() -> void:
	var files: PackedStringArray = []
	for root: String in ROOTS:
		_collect(root, files)
	var tests: DirAccess = DirAccess.open("res://tests")
	if tests != null:
		for f: String in tests.get_files():
			if f.begins_with("test_m4_") and f.get_extension() == "gd":
				files.append("res://tests".path_join(f))
	assert_gt(files.size(), 20, "found the M4 sources")
	var long_lines: PackedStringArray = []
	for path: String in files:
		var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
		for i in lines.size():
			if lines[i].length() > LIMIT:
				long_lines.append("%s:%d (%d)" % [path, i + 1, lines[i].length()])
	assert_eq(long_lines, PackedStringArray(), "lines > %d characters (02_TECH §13.1)" % LIMIT)
