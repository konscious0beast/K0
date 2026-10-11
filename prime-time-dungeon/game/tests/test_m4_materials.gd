extends TestCase
## M4: Palette, Materials cache, MeshUtil, shader contracts (02_TECH §8.2/§8.3, 03_ART §2/§3/§5.2).


func after_each() -> void:
	Materials.clear_cache()


# --- Palette ----------------------------------------------------------------------------------------------------------

func test_palette_contract_constants() -> void:
	assert_eq(Palette.INK.to_html(false), "140d1c")
	assert_eq(Palette.NOVA_MAGENTA.to_html(false), "ff2e88")
	assert_eq(Palette.NOVA_CYAN.to_html(false), "22d3ee")
	assert_eq(Palette.HYPE_GOLD.to_html(false), "ffc93c")
	assert_eq(Palette.DANGER.to_html(false), "ff4d4d")
	assert_eq(Palette.HEAL.to_html(false), "4ade80")
	assert_eq(Palette.MANA.to_html(false), "60a5fa")


func test_palette_hex_parsing() -> void:
	assert_eq(Palette.hex("#ff2e88").to_html(false), "ff2e88")
	assert_eq(Palette.hex("ff2e88").to_html(false), "ff2e88", "without #")
	assert_eq(Palette.hex(" #22D3EE ").to_html(false), "22d3ee", "case + whitespace")
	assert_eq(Palette.hex("nonsense", Color.RED), Color.RED, "invalid → fallback")
	assert_eq(Palette.hex(""), Color.MAGENTA, "empty → default fallback")


func test_theme_palette_has_all_keys_as_colors() -> void:
	for theme: String in ["metro", "mall", "unknown_theme"]:
		var p: Dictionary = Palette.theme_palette(theme)
		for key: String in Palette.PALETTE_KEYS + Palette.ART_KEYS:
			assert_true(p.has(key), "%s has %s" % [theme, key])
			assert_eq(typeof(p.get(key)), TYPE_COLOR, "%s.%s is a Color" % [theme, key])
	assert_eq((Palette.theme_palette("metro")["wall"] as Color).to_html(false), "1f5f66", "metro zone A wall")
	assert_eq((Palette.theme_palette("mall")["accent"] as Color).to_html(false), "ff4fa0")
	assert_eq(Palette.theme_palette("unknown_theme"), Palette.theme_palette("metro"), "unknown → metro")


func test_theme_defaults_match_validator() -> void:
	for theme: String in DataValidator.THEME_PALETTES:
		var src: Dictionary = DataValidator.THEME_PALETTES[theme]
		var p: Dictionary = Palette.theme_palette(theme)
		for key: String in src:
			assert_eq((p[key] as Color).to_html(false), str(src[key]).trim_prefix("#"), "%s.%s" % [theme, key])


func test_resolve_merges_hex_and_picks_zone_art_keys() -> void:
	var sewer: Dictionary = {}
	for key: String in Palette.PALETTE_KEYS:
		sewer[key] = Palette.ZONE_PRESETS["sewer"][key]
	var r: Dictionary = Palette.resolve(sewer, "metro")
	assert_eq((r["floor"] as Color).to_html(false), "24302c")
	assert_eq((r["shade"] as Color).to_html(false), "2f4f5c", "art key from the matched zone preset")
	assert_eq(Palette.zone_style(sewer, "metro"), &"sewer")
	# partial palette (03_ART example) still maps to zone A
	var partial: Dictionary = {"floor": "#2b4a52", "accent": "#ff2e88"}
	assert_eq(Palette.zone_style(partial, "metro"), &"platform")
	assert_eq((Palette.resolve(partial, "metro")["floor"] as Color).to_html(false), "2b4a52", "given key wins")
	# explicit art keys override everything
	var with_art: Dictionary = sewer.duplicate()
	with_art["rim"] = "#123456"
	assert_eq((Palette.resolve(with_art, "metro")["rim"] as Color).to_html(false), "123456")
	# empty palette → theme defaults
	assert_eq(Palette.resolve({}, "metro"), Palette.theme_palette("metro"))


func test_resolve_unmatched_palette_derives_art_keys() -> void:
	var odd: Dictionary = {"floor": "#ffffff", "wall": "#00ff00", "accent": "#0000ff", "light": "#ff0000",
		"fog": "#ffff00", "ambient": "#00ffff"}
	var r: Dictionary = Palette.resolve(odd, "metro")
	for key: String in Palette.ART_KEYS:
		assert_eq(typeof(r[key]), TYPE_COLOR, key)
	assert_ne((r["grout"] as Color).to_html(false), Palette.theme_palette("metro")["grout"].to_html(false),
		"grout derived from the floor, not the preset")
	assert_true((r["grout"] as Color).get_luminance() < (r["floor"] as Color).get_luminance(), "grout darker than floor")


func test_floor_data_palettes_resolve() -> void:
	var data: GameData = real_data()
	for f: FloorDef in data.all_floors():
		var r: Dictionary = Palette.resolve(f.palette, f.theme)
		assert_eq(r.size() >= 11, true, "resolved palette of " + f.id)
		var zones: Array = f.layout.get("zones", []) as Array
		for z: Variant in zones:
			var zd: Dictionary = z
			var zr: Dictionary = Palette.resolve(zd.get("palette", {}) as Dictionary, f.theme)
			assert_eq(typeof(zr["shade"]), TYPE_COLOR, "zone " + str(zd.get("id", "")))


# --- Materials -----------------------------------------------------------------------------------------------------

func test_materials_cache_identity() -> void:
	var a: ShaderMaterial = Materials.toon(Palette.NOVA_MAGENTA, {"bands": 3, "rim": 0.45})
	var b: ShaderMaterial = Materials.toon(Palette.NOVA_MAGENTA, {"rim": 0.45, "bands": 3})
	assert_true(a == b, "same color + opts (any key order) → same instance")
	var c: ShaderMaterial = Materials.toon(Palette.NOVA_MAGENTA, {"bands": 2, "rim": 0.45})
	assert_true(a != c, "different opts → different instance")
	assert_true(Materials.toon_vc({"bands": 3}) == Materials.toon_vc({"bands": 3.0}), "int/float opts are the same key")
	var before: int = Materials.cache_size()
	assert_gt(before, 0)
	Materials.clear_cache()
	assert_eq(Materials.cache_size(), 0)
	assert_true(Materials.toon(Palette.NOVA_MAGENTA, {"bands": 3, "rim": 0.45}) != a, "new instance after clear_cache")


func test_toon_options_map_to_uniforms() -> void:
	var m: ShaderMaterial = Materials.toon_vc({"bands": 3, "rim": 0.8, "rim_color": Color("#9a6bff"), "spec": 0.6,
		"wobble": 0.03, "shade": Color("#112233"), "emission": Color("#ff0000"),
		"stripes": {"color": Color("#f2c230"), "width": 0.15, "speed": 0.8}})
	assert_eq(m.shader.resource_path, "res://art/shaders/toon.gdshader")
	assert_eq(m.get_shader_parameter(&"use_vertex_color"), true)
	assert_almost(float(m.get_shader_parameter(&"bands")), 3.0)
	assert_almost(float(m.get_shader_parameter(&"rim_amount")), 0.8)
	assert_eq((m.get_shader_parameter(&"rim_color") as Color).to_html(false), "9a6bff")
	assert_almost(float(m.get_shader_parameter(&"spec_strength")), 0.6)
	assert_almost(float(m.get_shader_parameter(&"wobble_amount")), 0.03)
	assert_eq((m.get_shader_parameter(&"shade_color") as Color).to_html(false), "112233")
	assert_almost(float(m.get_shader_parameter(&"emission_energy")), 1.0)
	assert_almost(float(m.get_shader_parameter(&"stripe_mix")), 1.0)
	assert_almost(float(m.get_shader_parameter(&"stripe_duty")), 0.15)
	assert_almost(float(m.get_shader_parameter(&"stripe_scroll")), 0.8)
	var outline: ShaderMaterial = m.next_pass as ShaderMaterial
	assert_not_null(outline, "outline next_pass by default")
	if outline != null:
		assert_eq(outline.shader.resource_path, "res://art/shaders/toon_outline.gdshader")
		assert_almost(float(outline.get_shader_parameter(&"outline_width")), 0.025)
	var plain: ShaderMaterial = Materials.toon(Palette.INK, {"outline": false})
	assert_null(plain.next_pass, "outline: false → no next_pass")
	assert_eq(plain.get_shader_parameter(&"use_vertex_color"), false)
	var thin: ShaderMaterial = Materials.toon_vc({"outline_width": 0.02})
	assert_almost(float((thin.next_pass as ShaderMaterial).get_shader_parameter(&"outline_width")), 0.02)


func test_env_glow_vfx_outline_factories() -> void:
	var e: ShaderMaterial = Materials.env({"tile_size": 1.0, "shade": Color("#4a3e78"), "grout_width": 0.0})
	assert_eq(e.shader.resource_path, "res://art/shaders/env_tiles.gdshader")
	assert_null(e.next_pass, "environment never gets an outline")
	assert_almost(float(e.get_shader_parameter(&"tile_size")), 1.0)
	assert_almost(float(e.get_shader_parameter(&"grout_width")), 0.0)
	assert_eq(e.get_shader_parameter(&"use_vertex_color"), true)
	var g: ShaderMaterial = Materials.glow(Palette.HYPE_GOLD, 3.0)
	assert_eq(g.shader.resource_path, "res://art/shaders/glow.gdshader")
	assert_almost(float(g.get_shader_parameter(&"energy")), 3.0)
	assert_true(Materials.glow(Palette.HYPE_GOLD, 3.0) == g, "glow cached")
	var v: ShaderMaterial = Materials.vfx_additive(Palette.NOVA_CYAN)
	assert_eq(v.shader.resource_path, "res://art/shaders/vfx_additive.gdshader")
	var o: ShaderMaterial = Materials.outline(0.05, Palette.DANGER)
	assert_almost(float(o.get_shader_parameter(&"outline_width")), 0.05)
	assert_eq((o.get_shader_parameter(&"outline_color") as Color).to_html(false), "ff4d4d")
	var h: ShaderMaterial = Materials.hologram(Palette.HYPE_GOLD, 0.15)
	assert_eq(h.shader.resource_path, "res://art/shaders/hologram.gdshader")
	assert_almost(float(h.get_shader_parameter(&"alpha")), 0.15)


# --- shaders ----------------------------------------------------------------------------------------------------------

func _uniform_names(path: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var sh: Shader = load(path) as Shader
	if sh == null:
		fail("cannot load " + path)
		return out
	for u: Dictionary in sh.get_shader_uniform_list():
		out.append(str(u["name"]))
	return out


func test_shader_contract_uniforms_and_extras() -> void:
	var toon: PackedStringArray = _uniform_names("res://art/shaders/toon.gdshader")
	for n: String in ["albedo", "use_vertex_color", "shade_color", "bands", "rim_color", "rim_amount", "emission_color",
			"emission_energy", "spec_strength", "wobble_amount", "stripe_mix"]:
		assert_has(toon, n, "toon." + n)
	var low: PackedStringArray = _uniform_names("res://art/shaders/ui_tv_overlay.gdshader")
	var high: PackedStringArray = _uniform_names("res://art/shaders/ui_tv_overlay_aberration.gdshader")
	for n: String in low:
		assert_has(high, n, "aberration variant has the same uniform " + n)

	var screen_read := RegEx.create_from_string("uniform[^;]*hint_(screen|depth)_texture")
	var low_src: String = FileAccess.get_file_as_string("res://art/shaders/ui_tv_overlay.gdshader")
	assert_null(screen_read.search(low_src), "quality low overlay never reads the screen (03_ART F7)")
	var high_src: String = FileAccess.get_file_as_string("res://art/shaders/ui_tv_overlay_aberration.gdshader")
	assert_not_null(screen_read.search(high_src), "aberration variant samples the screen")
	for path: String in ["res://art/shaders/toon.gdshader", "res://art/shaders/env_tiles.gdshader",
			"res://art/shaders/vfx_additive.gdshader"]:
		var src: String = FileAccess.get_file_as_string(path)
		assert_true(src.contains("ptd_color.gdshaderinc") and src.contains("ptd_vertex_albedo("),
			"COLOR goes through ptd_vertex_albedo in " + path)
	for path: String in ["res://art/shaders/toon.gdshader", "res://art/shaders/toon_outline.gdshader",
			"res://art/shaders/env_tiles.gdshader", "res://art/shaders/glow.gdshader", "res://art/shaders/hologram.gdshader",
			"res://art/shaders/vfx_additive.gdshader"]:
		var src2: String = FileAccess.get_file_as_string(path)
		assert_null(screen_read.search(src2), "no screen/depth reads in spatial shader " + path)
	var env_src: String = FileAccess.get_file_as_string("res://art/shaders/env_tiles.gdshader")
	assert_null(RegEx.create_from_string("\\bdiscard\\s*;").search(env_src), "env_tiles has no discard (03_ART §3.10)")
	var outline_src: String = FileAccess.get_file_as_string("res://art/shaders/toon_outline.gdshader")
	assert_true(outline_src.contains("abs(PROJECTION_MATRIX[1][1])"), "outline uses abs() of the flipped projection (F6)")


## 02_TECH §8.3: names, types and defaults of the contract uniforms are binding (also for the TV overlay LOW variant).
const CONTRACT_DEFAULTS: Dictionary = {
	"res://art/shaders/toon.gdshader": {"albedo": Color(1, 1, 1, 1), "use_vertex_color": false,
		"shade_color": Color(0.35, 0.3, 0.5, 1), "bands": 2.0, "rim_color": Color(1, 0.95, 0.85, 1), "rim_amount": 0.25,
		"emission_color": Color(0, 0, 0, 1), "emission_energy": 0.0},
	"res://art/shaders/toon_outline.gdshader": {"outline_color": Palette.INK, "outline_width": 0.025},
	"res://art/shaders/env_tiles.gdshader": {"tile_size": 2.0, "grout_width": 0.04, "dirt_amount": 0.3, "bands": 3.0,
		"use_vertex_color": true},
	"res://art/shaders/glow.gdshader": {"energy": 2.0, "pulse_speed": 0.0},
	"res://art/shaders/vfx_additive.gdshader": {"softness": 0.5},
	"res://art/shaders/hologram.gdshader": {"color": Palette.NOVA_CYAN, "scan_speed": 1.5, "alpha": 0.6},
	"res://art/shaders/ui_swirl.gdshader": {"progress": 0.0, "tint": Palette.INK, "aspect": 1.7778},
	"res://art/shaders/ui_tv_overlay.gdshader": {"scanline_alpha": 0.08, "vignette": 0.35, "aberration": 0.6},
	"res://art/shaders/ui_tv_overlay_aberration.gdshader": {"scanline_alpha": 0.08, "vignette": 0.35, "aberration": 0.6},
}
const INSTANCE_CONTRACT: PackedStringArray = ["flash_amount", "flash_color", "highlight", "dissolve"]


func test_shader_contract_defaults() -> void:
	for path: String in CONTRACT_DEFAULTS:
		var sh: Shader = load(path) as Shader
		assert_not_null(sh, path)
		if sh == null:
			continue
		var defaults: Dictionary = CONTRACT_DEFAULTS[path]
		for uname: String in defaults:
			var want: Variant = defaults[uname]
			var got: Variant = _source_default(sh.code, uname)
			var ctx: String = "%s: %s default" % [path.get_file(), uname]
			if want is Color:
				assert_true(got is Color, ctx + " is a color")
				if got is Color:
					var g: Color = got
					var w: Color = want
					assert_true(absf(g.r - w.r) < 0.003 and absf(g.g - w.g) < 0.003 and absf(g.b - w.b) < 0.003
						and absf(g.a - w.a) < 0.003, "%s = %s, expected %s" % [ctx, g, w])
			elif want is bool:
				assert_eq(bool(got), want, ctx)
			else:
				assert_almost(float(got), float(want), 0.0001, ctx)


## Default value written in the shader source for `uname` (float, bool or vecN → Color); null when none.
static func _source_default(code: String, uname: String) -> Variant:
	var re := RegEx.create_from_string("uniform\\s+\\w+\\s+" + uname + "\\b[^=;]*=\\s*([^;]+);")
	var m: RegExMatch = re.search(code)
	if m == null:
		return null
	var v: String = m.get_string(1).strip_edges()
	if v == "true" or v == "false":
		return v == "true"
	if v.begins_with("vec"):
		var args: PackedStringArray = v.substr(v.find("(") + 1, v.rfind(")") - v.find("(") - 1).split(",")
		var f: Array[float] = []
		for a: String in args:
			f.append(a.strip_edges().to_float())
		if f.size() == 1:
			return Color(f[0], f[0], f[0], f[0])
		while f.size() < 4:
			f.append(1.0)
		return Color(f[0], f[1], f[2], f[3])
	return v.to_float()


## Declared `instance uniform` names of a shader, in source order.
static func _instance_uniforms(path: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var re := RegEx.create_from_string("(?m)^\\s*instance\\s+uniform\\s+\\w+\\s+(\\w+)")
	for m: RegExMatch in re.search_all(FileAccess.get_file_as_string(path)):
		out.append(m.get_string(1))
	return out


## Headless guard for the "different indices" rule (02_TECH §8.3/§11.5): the dummy rasterizer never logs the warning,
## so every material/next_pass pair the kit builds is checked statically — shared instance uniforms in the same order.
func test_instance_uniform_order_of_next_pass_pairs() -> void:
	var toon: PackedStringArray = _instance_uniforms("res://art/shaders/toon.gdshader")
	var outline: PackedStringArray = _instance_uniforms("res://art/shaders/toon_outline.gdshader")
	assert_eq(toon.slice(0, INSTANCE_CONTRACT.size()), INSTANCE_CONTRACT,
		"toon: contract instance uniforms first, in order")
	assert_eq(outline.slice(0, INSTANCE_CONTRACT.size()), INSTANCE_CONTRACT, "outline: same order as toon")
	var pairs: Dictionary = {}
	for m: ShaderMaterial in [Materials.toon(Color.RED), Materials.toon_vc({"bands": 3}), Materials.toon(Color.BLUE,
			{"outline_width": 0.05}), Materials.toon_vc({"stripes": {"color": Color.YELLOW, "width": 0.5, "speed": 0.8}})]:
		var mat: Material = m
		while mat != null and mat.next_pass != null:
			var a: ShaderMaterial = mat as ShaderMaterial
			var b: ShaderMaterial = mat.next_pass as ShaderMaterial
			if a != null and b != null:
				pairs[[a.shader.resource_path, b.shader.resource_path]] = true
			mat = mat.next_pass
	assert_gt(pairs.size(), 0, "the kit builds material + next_pass pairs")
	for pv: Variant in pairs:
		var pair: Array = pv
		var ua: PackedStringArray = _instance_uniforms(str(pair[0]))
		var ub: PackedStringArray = _instance_uniforms(str(pair[1]))
		var shared_a: PackedStringArray = []
		var shared_b: PackedStringArray = []
		for n: String in ua:
			if ub.has(n):
				shared_a.append(n)
		for n: String in ub:
			if ua.has(n):
				shared_b.append(n)
		assert_eq(shared_b, shared_a, "%s + next_pass %s: shared instance uniforms in the same order" % pair)
		for i in shared_a.size():
			assert_eq(ua.find(shared_a[i]), ub.find(shared_a[i]), "%s: same index in both shaders" % shared_a[i])


# --- MeshUtil ---------------------------------------------------------------------------------------------------------

func test_meshutil_primitive_segments() -> void:
	var s: SphereMesh = MeshUtil.sphere(0.3)
	assert_eq(s.radial_segments, 10)
	assert_eq(s.rings, 6)
	var small: SphereMesh = MeshUtil.sphere(0.03)
	assert_eq(small.radial_segments, 6, "small part")
	assert_eq(small.rings, 3)
	var c: CapsuleMesh = MeshUtil.capsule(0.2, 0.3)
	assert_eq(c.radial_segments, 10)
	assert_eq(c.rings, 2)
	assert_almost(c.height, 0.4, 0.0001, "capsule height ≥ 2 r")
	var cy: CylinderMesh = MeshUtil.cylinder(0.1, 0.2, 1.0)
	assert_eq(cy.radial_segments, 8)
	assert_eq(MeshUtil.cylinder(0.02, 0.02, 1.0).radial_segments, 6)
	assert_eq(MeshUtil.box(Vector3(1, 2, 3)).size, Vector3(1, 2, 3))
	assert_eq(MeshUtil.tri_count(MeshUtil.sphere(0.5)), 140, "sphere 10×6 = 140 tris (03_ART §5.1)")
	assert_eq(MeshUtil.tri_count(MeshUtil.sphere(0.05)), 48, "small sphere 6×3 = 48 tris")
	assert_eq(MeshUtil.tri_count(MeshUtil.box(Vector3.ONE)), 12)
	assert_eq(MeshUtil.tri_count(MeshUtil.icosahedron(0.32)), 20)


func test_meshutil_merge_writes_vertex_data() -> void:
	var parts: Array[Dictionary] = [
		{"mesh": MeshUtil.box(Vector3(1, 1, 1)), "xform": MeshUtil.xform(Vector3(2, 0, 0)), "color": Color("#ff0000"),
			"emission": 1.0},
		{"mesh": MeshUtil.sphere(0.5), "xform": MeshUtil.xform(Vector3(-2, 0, 0)), "color": Color("#00ff00"), "metal": 1.0},
	]
	var m: ArrayMesh = MeshUtil.merge(parts)
	assert_eq(m.get_surface_count(), 1, "one surface → one material per figure")
	assert_eq(MeshUtil.tri_count(m), 12 + 140)
	var arr: Array = m.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var cols: PackedColorArray = arr[Mesh.ARRAY_COLOR]
	var uv2: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV2]
	var custom: Variant = arr[Mesh.ARRAY_CUSTOM0]
	assert_eq(cols.size(), verts.size())
	assert_eq(uv2.size(), verts.size())
	assert_not_null(custom, "CUSTOM0 = smoothed outline normals")
	var red_emit: int = 0
	var green_metal: int = 0
	for i in verts.size():
		if verts[i].x > 1.0:
			if cols[i].is_equal_approx(Color("#ff0000")) and is_equal_approx(uv2[i].x, 1.0) and is_equal_approx(uv2[i].y, 0.0):
				red_emit += 1
		elif verts[i].x < -1.0:
			if cols[i].is_equal_approx(Color("#00ff00")) and is_equal_approx(uv2[i].y, 1.0):
				green_metal += 1
	assert_eq(red_emit, 24, "box vertices: sRGB color + emission mask")
	assert_gt(green_metal, 0, "sphere vertices: metal mask")
	var aabb: AABB = m.get_aabb()
	assert_between(aabb.position.x, -2.5, -2.45, "sphere part at x = -2 (decagon extent)")
	assert_almost(aabb.end.x, 2.5, 0.001, "box part at x = 2")
	var no_hull: ArrayMesh = MeshUtil.merge_no_hull(parts)
	assert_eq(MeshUtil.tri_count(no_hull), MeshUtil.tri_count(m))
	assert_eq(MeshUtil.merge([] as Array[Dictionary]).get_surface_count(), 0, "empty merge")


func test_meshutil_smoothed_normals_are_unit_and_shared() -> void:
	var verts := PackedVector3Array([Vector3.ZERO, Vector3.ZERO, Vector3(1, 0, 0)])
	var norms := PackedVector3Array([Vector3.UP, Vector3.RIGHT, Vector3.UP])
	var sn: PackedFloat32Array = MeshUtil.smoothed_normals(verts, norms)
	assert_eq(sn.size(), 12)
	var n0 := Vector3(sn[0], sn[1], sn[2])
	var n1 := Vector3(sn[4], sn[5], sn[6])
	assert_almost(n0.length(), 1.0, 0.0001)
	assert_true(n0.is_equal_approx(n1), "same position → same averaged normal")
	assert_true(n0.is_equal_approx(Vector3(1, 1, 0).normalized()))


func test_meshutil_xform_scales_local_axes() -> void:
	# 03_ART F10: a capsule rotated 90° around X and stretched along its OWN Y axis grows along world Z
	var parts: Array[Dictionary] = [{"mesh": MeshUtil.capsule(0.1, 1.0), "color": Color.WHITE,
		"xform": MeshUtil.xform(Vector3.ZERO, Vector3(90, 0, 0), Vector3(1, 2, 1))}]
	var aabb: AABB = MeshUtil.merge(parts).get_aabb()
	assert_almost(aabb.size.z, 2.0, 0.01, "length along world Z")
	assert_almost(aabb.size.y, 0.2, 0.01, "thickness along world Y")


func test_meshutil_box_sizes_and_mirroring() -> void:
	var a: ArrayMesh = MeshUtil.merge([{"mesh": MeshUtil.box(Vector3(1, 2, 3)),
		"color": Color.WHITE}] as Array[Dictionary])
	assert_true(a.get_aabb().size.is_equal_approx(Vector3(1, 2, 3)), "unit-box cache keeps sizes")
	var b: ArrayMesh = MeshUtil.merge([{"mesh": MeshUtil.box(Vector3(0.5, 0.5, 0.5)),
		"color": Color.WHITE}] as Array[Dictionary])
	assert_true(b.get_aabb().size.is_equal_approx(Vector3(0.5, 0.5, 0.5)), "second box size from the same cache")
	var mirrored: ArrayMesh = MeshUtil.merge([{"mesh": MeshUtil.box(Vector3.ONE), "color": Color.WHITE,
		"xform": Transform3D(Basis.from_scale(Vector3(-1, 1, 1)), Vector3.ZERO)}] as Array[Dictionary])
	var plain: ArrayMesh = MeshUtil.merge([{"mesh": MeshUtil.box(Vector3.ONE), "color": Color.WHITE}] as Array[Dictionary])
	assert_eq(_winding_signs(mirrored), _winding_signs(plain),
		"mirrored part keeps the front-face winding relative to its normals (every triangle)")


## Per triangle: sign of (face normal from winding) · (vertex normal); identical for all triangles of a valid mesh.
func _winding_signs(m: ArrayMesh) -> PackedInt32Array:
	var arr: Array = m.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var nrm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var out: PackedInt32Array = []
	for i in range(0, idx.size(), 3):
		var face_n: Vector3 = (v[idx[i + 1]] - v[idx[i]]).cross(v[idx[i + 2]] - v[idx[i]])
		out.append(1 if face_n.dot(nrm[idx[i]]) > 0.0 else -1)
	return out
