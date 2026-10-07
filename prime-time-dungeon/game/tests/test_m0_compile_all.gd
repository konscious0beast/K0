extends TestCase
## Loads every .gd / .tscn / .gdshader under res:// → catches parse errors early (02_TECH §1.7).
## Also checks the M0 conventions that are cheap to verify statically (§13.4 tscn format, §0.2 stub header).

const SKIP_DIRS: PackedStringArray = ["res://.godot", "res://build"]
const STUB_HEADER: String = "STUB(M0) — owned by M"


func _walk(dir_path: String, exts: PackedStringArray, out: PackedStringArray) -> void:
	if SKIP_DIRS.has(dir_path):
		return
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if not entry.begins_with("."):
			var full: String = dir_path.path_join(entry)
			if dir.current_is_dir():
				_walk(full, exts, out)
			else:
				for ext: String in exts:
					if entry.ends_with(ext):
						out.append(full)
						break
		entry = dir.get_next()
	dir.list_dir_end()


func test_all_scripts_compile() -> void:
	var files: PackedStringArray = []
	_walk("res://", [".gd"], files)
	assert_gt(files.size(), 100, "found the project scripts")
	for path: String in files:
		var script: GDScript = load(path) as GDScript
		assert_not_null(script, "load " + path)
		if script != null:
			assert_true(script.can_instantiate(), "compile " + path)


func test_all_scenes_load() -> void:
	var files: PackedStringArray = []
	_walk("res://", [".tscn"], files)
	assert_gt(files.size(), 5)
	for path: String in files:
		var packed: PackedScene = load(path) as PackedScene
		assert_not_null(packed, "load " + path)
		if packed != null:
			assert_true(packed.can_instantiate(), "instantiable " + path)


func test_all_shaders_load() -> void:
	var files: PackedStringArray = []
	_walk("res://", [".gdshader"], files)
	assert_gt(files.size(), 7, "at least the 8 shaders of §1.5")
	for path: String in files:
		var shader: Shader = load(path) as Shader
		assert_not_null(shader, "load " + path)
		if shader != null:
			assert_gt(shader.get_shader_uniform_list().size(), 0, "uniforms in " + path)


func test_shader_uniforms_match_contract() -> void:
	var expected: Dictionary = {
		"toon": ["albedo", "use_vertex_color", "shade_color", "bands", "rim_color", "rim_amount", "emission_color", "emission_energy"],
		"toon_outline": ["outline_color", "outline_width"],
		"env_tiles": ["tile_size", "grout_color", "grout_width", "dirt_amount", "shade_color", "bands", "use_vertex_color"],
		"glow": ["color", "energy", "pulse_speed"],
		"vfx_additive": ["color", "softness"],
		"hologram": ["color", "scan_speed", "alpha"],
		"ui_swirl": ["progress", "snapshot", "tint", "aspect"],
		"ui_tv_overlay": ["scanline_alpha", "vignette", "aberration"],
	}
	for shader_name: String in expected.keys():
		var shader: Shader = load("res://art/shaders/%s.gdshader" % shader_name) as Shader
		if shader == null:
			fail("missing shader " + shader_name)
			continue
		var names: PackedStringArray = []
		for u: Dictionary in shader.get_shader_uniform_list():
			names.append(str(u["name"]))
		for want: String in expected[shader_name]:
			assert_has(names, want, "%s uniform %s" % [shader_name, want])
	# Instance uniforms: same names in the same order in toon and toon_outline (§8.3 order rule).
	var re: RegEx = RegEx.create_from_string("^\\s*instance\\s+uniform\\s+\\w+\\s+(\\w+)")
	for shader_name: String in ["toon", "toon_outline"]:
		var src: String = FileAccess.get_file_as_string("res://art/shaders/%s.gdshader" % shader_name)
		var order: PackedStringArray = []
		for line: String in src.split("\n"):
			var m: RegExMatch = re.search(line)
			if m != null:
				order.append(m.get_string(1))
		var head: PackedStringArray = order.slice(0, 4)
		assert_eq(head, ["flash_amount", "flash_color", "highlight", "dissolve"], shader_name + " instance uniform order")


func test_tscn_files_are_handwritten_format() -> void:
	var files: PackedStringArray = []
	_walk("res://", [".tscn"], files)
	for path: String in files:
		var head: String = FileAccess.get_file_as_string(path).get_slice("\n", 0)
		assert_true(head.contains("format=3"), "format=3 in " + path)


func test_stub_headers() -> void:
	# Every file that still is a Phase-A stub starts with the exact STUB header line.
	var files: PackedStringArray = []
	_walk("res://", [".gd", ".gdshader"], files)
	for path: String in files:
		if path.begins_with("res://tests/"):
			continue
		var text: String = FileAccess.get_file_as_string(path)
		if not text.contains(STUB_HEADER):
			continue
		var first: String = text.get_slice("\n", 0)
		assert_true(first.begins_with("# STUB(M0) — owned by M") or first.begins_with("// STUB(M0) — owned by M"),
			"stub header must be the first line: " + path)
		assert_true(first.ends_with("Replace completely, keep the public API."), "stub header text: " + path)
