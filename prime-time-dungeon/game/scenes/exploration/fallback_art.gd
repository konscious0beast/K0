extends RefCounted
## Fallback visuals of the exploration (M3-private, no class_name, §0.3). Used ONLY where an M4 builder returns an empty
## node (art-kit stubs during parallel development), so the exploration is visible, testable and playable before M4
## delivers. Follows the world conventions of 02_TECH §7.3/§8.5 and the 03_ART recipes in simplified form:
## room 16 × 16 m, walls 3.5 m / 0.5 m, door openings 4 m, clear zone r 5 m + 3 m door corridors, boxes as collision.
## Own inline shaders (toon bands, rim, outline, tiles) keep this file independent of the art module's shader files.

const META_FALLBACK: StringName = &"m3_fallback"
const ROOM_SIZE: float = 16.0
const HALF: float = 8.0
const WALL_HEIGHT: float = 3.5
const WALL_T: float = 0.5
const DOOR_W: float = 4.0
const INK: Color = Color("#140d1c")
const NOVA_MAGENTA: Color = Color("#ff2e88")
const NOVA_CYAN: Color = Color("#22d3ee")
const HYPE_GOLD: Color = Color("#ffc93c")
const DANGER: Color = Color("#ff4d4d")
const EXIT_GREEN: Color = Color("#2bd66b")
const WARN_YELLOW: Color = Color("#f2c230")
const PAPER: Color = Color("#f5f0e6")
const SODIUM: Color = Color("#ff9a2e")
const AMBIENT_ENERGY: float = 0.8        # 03_ART §4.2 explore
const FOG_DENSITY: float = 0.03          # 03_ART §4.2 explore
const SUN_ENERGY: float = 1.1            # 03_ART §4.3 explore
const ROOM_LIGHT_ENERGY: float = 1.2     # 03_ART §4.3 / 02_TECH §8.5 room omni
const ROOM_LIGHT_RANGE: float = 9.0
const ENV_AMBIENT_DESAT: float = 0.85   # zone ambient on the environment: mostly neutral (pillar 3)
const WALL_CAP_H: float = 0.06           # INK cap on wall crowns (seen from the high camera)
const SIGN_HDR: float = 1.6              # HDR factor of sign text (glows through AgX / fog)
const PIT_DEPTH: float = 2.75            # stair pit below the floor

## Environment (simplified 03_ART §3.4 env_tiles): sRGB vertex colours (linearized like ptd_vertex_albedo: the
## Compatibility renderer hands COLOR over already linear), world-space tile grout, 3 toon bands with the violet shade
## tint in the shadow band, omni lights in stepped thirds. The zone lights and the zone ambient reach the walls mostly
## desaturated (light_desat; own `ambient` term instead of the engine's): warm light × warm wall would otherwise
## compound to a monochrome orange room (03_ART pillar 3: environment ≤ 45 % saturation; figures keep the full light).
const ENV_SHADER: String = """
shader_type spatial;
render_mode specular_disabled, ambient_light_disabled;
uniform vec4 grout_color : source_color = vec4(0.10, 0.11, 0.14, 1.0);
uniform float tile_size = 2.0;
uniform float grout_width = 0.035;
uniform vec4 shade_color : source_color = vec4(0.35, 0.3, 0.5, 1.0);
uniform float light_desat = 0.85;
uniform float albedo_desat = 0.45;
uniform vec3 ambient = vec3(0.03, 0.03, 0.04);
varying vec3 v_wpos;
varying vec3 v_wnrm;
vec3 vertex_albedo(vec3 c) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	return c;
#else
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
#endif
}
void vertex() {
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	vec3 base = vertex_albedo(COLOR.rgb);
	float emit = UV2.x;
	// Dark warm palettes land in the tonemapper's toe, which pushes saturation up: walls / floors are taken a bit
	// towards grey (neon / emissive parts keep their full colour).
	base = mix(mix(base, vec3(dot(base, vec3(0.2126, 0.7152, 0.0722))), albedo_desat), base, step(0.001, emit));
	vec2 uv = abs(v_wnrm.y) > 0.5 ? v_wpos.xz : (abs(v_wnrm.x) > 0.5 ? v_wpos.zy : v_wpos.xy);
	vec2 f = fract(uv / tile_size);
	float g = max(step(f.x, grout_width), step(f.y, grout_width)) * COLOR.a;
	ALBEDO = mix(base, grout_color.rgb, g * 0.8);
	EMISSION = base * emit * 2.0 + ALBEDO * ambient;
}
void light() {
	float ndl = dot(NORMAL, LIGHT);
	float x = ndl;
	float intensity = 1.0;
	if (LIGHT_IS_DIRECTIONAL) {
		x = min(ndl, mix(-0.08, 1.0, ATTENUATION));
	} else {
		intensity = min(1.0, ceil(ATTENUATION * 3.0) / 3.0) * step(0.02, ATTENUATION);
	}
	float b = mix(0.22, 0.6, smoothstep(-0.005, 0.045, x));
	b = mix(b, 1.0, smoothstep(0.395, 0.445, x));
	vec3 tint = mix(shade_color.rgb, vec3(1.0), smoothstep(-0.005, 0.445, x));
	vec3 lc = mix(LIGHT_COLOR, vec3(dot(LIGHT_COLOR, vec3(0.299, 0.587, 0.114))), light_desat);
	DIFFUSE_LIGHT += lc / PI * b * tint * intensity;
}
"""

## Toon (figures, props) and outline: fragments closer than 1.5 m to the camera are dithered out (screen-door, gone
## at 0.6 m), so a camera squeezed against Kai never fills the frame with his head (GeometryInstance3D.transparency
## is not applied to these shaders by the Compatibility renderer).
const NEAR_FADE_GLSL: String = """
void near_fade(vec3 view_pos, vec2 frag) {
	float f = clamp((1.5 - length(view_pos)) / 0.9, 0.0, 1.0);
	if (f > 0.0 && fract(52.9829189 * fract(dot(frag, vec2(0.06711056, 0.00583715)))) < f) {
		discard;
	}
}
"""

const TOON_SHADER: String = """
shader_type spatial;
render_mode specular_disabled;
uniform vec4 albedo : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 rim_color : source_color = vec4(1.0, 0.95, 0.85, 1.0);
uniform float rim_amount = 0.35;
uniform float emission_energy = 0.0;
uniform float light_desat = 0.55;
%s
void fragment() {
	near_fade(VERTEX, FRAGCOORD.xy);
	ALBEDO = albedo.rgb;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0) * rim_amount;
	EMISSION = albedo.rgb * emission_energy + rim_color.rgb * rim;
}
void light() {
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	float b = ndl > 0.4 ? 1.0 : (ndl > 0.06 ? 0.55 : 0.12);
	// Half-neutral light: figure / prop colours read as designed under the coloured zone lights.
	vec3 lc = mix(LIGHT_COLOR, vec3(dot(LIGHT_COLOR, vec3(0.299, 0.587, 0.114))), light_desat);
	DIFFUSE_LIGHT += lc / PI * b;
}
"""

const OUTLINE_SHADER: String = """
shader_type spatial;
render_mode unshaded, cull_front;
uniform vec4 outline_color : source_color = vec4(0.078, 0.051, 0.11, 1.0);
uniform float outline_width = 0.02;
void vertex() {
	VERTEX += NORMAL * outline_width;
}
%s
void fragment() {
	near_fade(VERTEX, FRAGCOORD.xy);
	ALBEDO = outline_color.rgb;
}
"""

const GLOW_SHADER: String = """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec4 color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float energy = 1.5;
uniform float pulse_speed = 0.0;
uniform float bob = 0.0;
void vertex() {
	VERTEX.y += sin(TIME * 6.2832) * bob;
}
void fragment() {
	ALBEDO = color.rgb * energy * (1.0 + 0.2 * sin(TIME * pulse_speed));
}
"""

## Group-size pips (GDD §2.3): one camera-facing plate (INK, 60 %) with `count` INK discs and a PAPER/DANGER rim,
## drawn over everything (no depth test, no fog) so the group size reads on any zone palette.
const PIPS_SHADER: String = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, fog_disabled, shadows_disabled;
uniform int count = 1;
uniform vec4 disc_color : source_color = vec4(0.078, 0.051, 0.11, 1.0);
uniform vec4 rim_color : source_color = vec4(0.96, 0.94, 0.9, 1.0);
uniform vec4 plate_color : source_color = vec4(0.078, 0.051, 0.11, 0.6);
const float PAD = 0.35;
const float STEP = 1.3;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	float w = float(count) * STEP - (STEP - 1.0) + 2.0 * PAD;
	float h = 1.0 + 2.0 * PAD;
	vec2 p = vec2(UV.x * w, (1.0 - UV.y) * h);
	vec2 q = abs(p - vec2(w, h) * 0.5) - (vec2(w, h) * 0.5 - vec2(0.5));
	float plate = 1.0 - step(0.5, length(max(q, 0.0)) + min(max(q.x, q.y), 0.0));
	vec4 c = vec4(plate_color.rgb, plate_color.a * plate);
	for (int i = 0; i < count; i++) {
		float d = length(p - vec2(PAD + 0.5 + float(i) * STEP, h * 0.5));
		if (d < 0.5) {
			c = d > 0.36 ? rim_color : disc_color;
		}
	}
	ALBEDO = c.rgb;
	ALPHA = c.a;
}
"""

const HIGHLIGHT_COLOR: Color = Color("#22d3ee")       # UiTheme.C_ACCENT_2 (focus)
const DIM_GLOW_ENERGY: float = 0.12

const BEAM_SHADER: String = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform vec4 color : source_color = vec4(1.0, 0.8, 0.2, 1.0);
uniform float alpha = 0.2;
void fragment() {
	float fade = clamp(1.0 - UV.y, 0.0, 1.0);
	ALBEDO = color.rgb * alpha * (0.4 + 0.6 * fade) * (0.85 + 0.15 * sin(TIME * 3.0 + UV.y * 12.0));
}
"""

static var _shaders: Dictionary = {}
static var _materials: Dictionary = {}


# ======================================================================================================================
# Colors, materials
# ======================================================================================================================

## Palette value (hex string) → Color; invalid / missing → fallback.
static func col(palette: Dictionary, key: String, fallback: Color) -> Color:
	var v: Variant = palette.get(key, null)
	if v is Color:
		return v
	if v is String or v is StringName:
		var s: String = str(v)
		if Color.html_is_valid(s):
			return Color.html(s)
	return fallback


static func _shader(key: String, code: String) -> Shader:
	if not _shaders.has(key):
		var sh: Shader = Shader.new()
		sh.code = code
		_shaders[key] = sh
	return _shaders[key]


## Toon material (banded light + rim) with an inverted-hull outline pass; cached per color/options.
static func toon(color: Color, outline: bool = true, emission: float = 0.0, outline_width: float = 0.02) -> Material:
	var key: String = "toon|%s|%s|%.2f|%.3f" % [color.to_html(), str(outline), emission, outline_width]
	if _materials.has(key):
		return _materials[key]
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = _shader("toon", TOON_SHADER % NEAR_FADE_GLSL)
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("emission_energy", emission)
	if outline:
		var o: ShaderMaterial = ShaderMaterial.new()
		o.shader = _shader("outline", OUTLINE_SHADER % NEAR_FADE_GLSL)
		o.set_shader_parameter("outline_width", outline_width)
		m.next_pass = o
	_materials[key] = m
	return m


## Environment material per zone palette: vertex colors (alpha = tile grout on/off), UV2.x = emission mask, the zone's
## shade (`shade`, default the violet SHADE), grout (`grout`) and ambient (desaturated, × AMBIENT_ENERGY) as uniforms.
static func env_material(palette: Dictionary = {}) -> Material:
	var shade: Color = col(palette, "shade", Color("#5a4e8c"))
	var grout: Color = col(palette, "grout", Color("#1a1e24"))
	var amb_src: Color = col(palette, "ambient", Color("#2a2440"))
	var key: String = "env|%s|%s|%s" % [shade.to_html(), grout.to_html(), amb_src.to_html()]
	if not _materials.has(key):
		var m: ShaderMaterial = ShaderMaterial.new()
		m.shader = _shader("env", ENV_SHADER)
		m.set_shader_parameter("shade_color", shade)
		m.set_shader_parameter("grout_color", grout)
		var luma: float = amb_src.r * 0.299 + amb_src.g * 0.587 + amb_src.b * 0.114
		var amb: Color = amb_src.lerp(Color(luma, luma, luma), ENV_AMBIENT_DESAT).srgb_to_linear()
		m.set_shader_parameter("ambient", Vector3(amb.r, amb.g, amb.b) * AMBIENT_ENERGY)
		_materials[key] = m
	return _materials[key]


static func glow(color: Color, energy: float = 1.5, pulse: float = 0.0, bob: float = 0.0) -> Material:
	var key: String = "glow|%s|%.2f|%.2f|%.3f" % [color.to_html(), energy, pulse, bob]
	if not _materials.has(key):
		var m: ShaderMaterial = ShaderMaterial.new()
		m.shader = _shader("glow", GLOW_SHADER)
		m.set_shader_parameter("color", color)
		m.set_shader_parameter("energy", energy)
		m.set_shader_parameter("pulse_speed", pulse)
		m.set_shader_parameter("bob", bob)
		_materials[key] = m
	return _materials[key]


## Pip plate material for a group of `count` (1–4); bosses get a DANGER rim.
static func pips_material(count: int, boss: bool) -> Material:
	var key: String = "pips|%d|%s" % [count, str(boss)]
	if not _materials.has(key):
		var m: ShaderMaterial = ShaderMaterial.new()
		m.shader = _shader("pips", PIPS_SHADER)
		m.set_shader_parameter("count", clampi(count, 1, 4))
		m.set_shader_parameter("rim_color", DANGER if boss else PAPER)
		m.render_priority = 2
		_materials[key] = m
	return _materials[key]


## Billboard plate of `count` pips; quad size in metres (pip diameter 0.17 m).
static func build_pips(count: int, boss: bool) -> MeshInstance3D:
	var unit: float = 0.17
	var n: int = clampi(count, 1, 4)
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2((n * 1.3 - 0.3 + 0.7) * unit, 1.7 * unit)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = pips_material(n, boss)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 1.0
	return mi


## Inverted-hull outline used as material_overlay for the focused interactable.
static func highlight_material() -> Material:
	if not _materials.has("highlight"):
		var m: ShaderMaterial = ShaderMaterial.new()
		m.shader = _shader("outline", OUTLINE_SHADER % NEAR_FADE_GLSL)
		m.set_shader_parameter("outline_color", HIGHLIGHT_COLOR)
		m.set_shader_parameter("outline_width", 0.035)
		_materials["highlight"] = m
	return _materials["highlight"]


## Focus highlight on/off for every mesh under `n` (per instance, the cached materials stay untouched).
static func set_highlight(n: Node, on: bool) -> void:
	if n is MeshInstance3D:
		(n as MeshInstance3D).material_overlay = highlight_material() if on else null
	for c: Node in n.get_children():
		set_highlight(c, on)


## Gold prism (tip down) that floats over the focused interactable.
static func focus_marker() -> MeshInstance3D:
	var prism: PrismMesh = PrismMesh.new()
	prism.size = Vector3(0.32, 0.3, 0.12)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = prism
	mi.material_override = glow(HYPE_GOLD, 2.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	return mi


## White hit flash (hitstop) on a character: CharacterRig.flash (M4) plus a white overlay on fallback figures.
static func flash_rig(rig: Node3D, sec: float) -> void:
	if rig == null or not is_instance_valid(rig):
		return
	if rig.has_method("flash"):
		rig.call("flash", Color.WHITE, sec)
	if not rig.has_meta(META_FALLBACK):
		return
	if not _materials.has("flash"):
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(1.0, 1.0, 1.0, 0.85)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_materials["flash"] = m
	_set_overlay(rig, _materials["flash"])
	if rig.is_inside_tree():
		rig.get_tree().create_timer(sec).timeout.connect(_clear_flash.bind(rig))


## `rig` is untyped on purpose: it may already be freed when the timer fires (group defeated / scene left).
static func _clear_flash(rig: Variant) -> void:
	if is_instance_valid(rig):
		_set_overlay(rig as Node, null)


static func _set_overlay(n: Node, m: Material) -> void:
	if n is MeshInstance3D:
		(n as MeshInstance3D).material_overlay = m
	for c: Node in n.get_children():
		_set_overlay(c, m)


## Dims a completed event prop (or restores it): glow parts nearly off and without pulse, toon albedo −40 %, labels
## darker. Fallback materials are swapped for dimmed cached variants; other materials get a darkening overlay.
static func dim_prop(root: Node, dim: bool) -> void:
	for c: Node in root.get_children():
		dim_prop(c, dim)
	if root is MeshInstance3D:
		var mi: MeshInstance3D = root as MeshInstance3D
		if dim and not mi.has_meta(&"m3_undim"):
			mi.set_meta(&"m3_undim", mi.material_override)
			var dm: Material = _dimmed(mi.material_override)
			if dm != null:
				mi.material_override = dm
			else:
				mi.material_overlay = _dark_overlay()
		elif not dim and mi.has_meta(&"m3_undim"):
			mi.material_override = mi.get_meta(&"m3_undim") as Material
			mi.material_overlay = null
			mi.remove_meta(&"m3_undim")
	elif root is Label3D:
		var l: Label3D = root as Label3D
		if dim and not l.has_meta(&"m3_undim"):
			l.set_meta(&"m3_undim", l.modulate)
			l.modulate = Color(l.modulate.darkened(0.6), 0.6)
		elif not dim and l.has_meta(&"m3_undim"):
			l.modulate = l.get_meta(&"m3_undim") as Color
			l.remove_meta(&"m3_undim")


static func _dimmed(m: Material) -> Material:
	var sm: ShaderMaterial = m as ShaderMaterial
	if sm == null or sm.shader == null:
		return null
	if sm.shader == _shader("glow", GLOW_SHADER):
		return glow(sm.get_shader_parameter("color") as Color, DIM_GLOW_ENERGY, 0.0)
	if sm.shader == Materials.GLOW_SHADER:
		# PropKit (M4) glow parts (drone lens, wheel bulbs, …): same shader, nearly off, no pulse / flicker.
		return Materials.glow_ex(sm.get_shader_parameter("color") as Color, DIM_GLOW_ENERGY, 0.0, 0.0)
	if sm.shader == _shader("toon", TOON_SHADER % NEAR_FADE_GLSL):
		var width: float = 0.02
		if sm.next_pass is ShaderMaterial:
			width = float((sm.next_pass as ShaderMaterial).get_shader_parameter("outline_width"))
		return toon((sm.get_shader_parameter("albedo") as Color).darkened(0.4), sm.next_pass != null, 0.0, width)
	if sm.shader == _shader("beam", BEAM_SHADER):
		return beam(sm.get_shader_parameter("color") as Color, float(sm.get_shader_parameter("alpha")) * 0.3)
	return null


static func _dark_overlay() -> Material:
	if not _materials.has("dark"):
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(0.6, 0.6, 0.6)
		m.blend_mode = BaseMaterial3D.BLEND_MODE_MUL
		_materials["dark"] = m
	return _materials["dark"]


## Flat 100° ring sector (front = −Z, r 0.5–1.8 m) for the field-strike swoosh; UV.y 0 at the outer edge.
static func strike_arc_mesh() -> ArrayMesh:
	var verts: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var segs: int = 14
	var half: float = deg_to_rad(50.0)
	for i in segs:
		var a0: float = -half + 2.0 * half * i / segs
		var a1: float = -half + 2.0 * half * (i + 1) / segs
		var o0: Vector3 = Vector3(sin(a0), 0.0, -cos(a0))
		var o1: Vector3 = Vector3(sin(a1), 0.0, -cos(a1))
		var quad: Array[Vector3] = [o0 * 1.8, o1 * 1.8, o1 * 0.5, o0 * 0.5]
		var quv: Array[Vector2] = [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
		for k: int in [0, 1, 2, 0, 2, 3]:
			verts.append(quad[k])
			uvs.append(quv[k])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func beam(color: Color, alpha: float = 0.2) -> Material:
	var key: String = "beam|%s|%.2f" % [color.to_html(), alpha]
	if not _materials.has(key):
		var m: ShaderMaterial = ShaderMaterial.new()
		m.shader = _shader("beam", BEAM_SHADER)
		m.set_shader_parameter("color", color)
		m.set_shader_parameter("alpha", alpha)
		_materials[key] = m
	return _materials[key]


## True when an M4 builder returned an empty placeholder (stub phase).
static func is_empty(n: Node) -> bool:
	return n == null or n.get_child_count() == 0


# ======================================================================================================================
# Merged environment meshes
# ======================================================================================================================

## Collects boxes/prisms with vertex colors into one ArrayMesh (one draw call per room part).
class MeshBuilder extends RefCounted:
	var verts: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	var uv2: PackedVector2Array = PackedVector2Array()

	func is_empty() -> bool:
		return verts.is_empty()

	## Vertex colour of the fallback environment: the sRGB palette value (the shader linearizes it per renderer).
	func _vc(color: Color) -> Color:
		return color

	## Triangles are given counter-clockwise around the outward normal; Godot's front faces are clockwise, so the
	## vertices are stored in reverse order.
	func _tri(a: Vector3, b: Vector3, c: Vector3, n: Vector3, col: Color, emission: float) -> void:
		verts.append(a)
		verts.append(c)
		verts.append(b)
		for _i in 3:
			normals.append(n)
			colors.append(col)
			uv2.append(Vector2(emission, 0.0))

	func _quad(p: Array[Vector3], n: Vector3, col: Color, emission: float) -> void:
		_tri(p[0], p[1], p[2], n, col, emission)
		_tri(p[0], p[2], p[3], n, col, emission)

	## Box of `size` centred at xform.origin; `tiled` draws the tile grout on it.
	func add_box(size: Vector3, xform: Transform3D, color: Color, emission: float = 0.0, tiled: bool = false) -> void:
		var h: Vector3 = size * 0.5
		var c: Color = _vc(color)
		c.a = 1.0 if tiled else 0.0
		var p: Array[Vector3] = []
		for i in 8:
			var lp: Vector3 = Vector3(h.x if (i & 1) else -h.x, h.y if (i & 2) else -h.y, h.z if (i & 4) else -h.z)
			p.append(xform * lp)
		var faces: Array = [[[1, 3, 7, 5], Vector3.RIGHT], [[0, 4, 6, 2], Vector3.LEFT], [[2, 6, 7, 3], Vector3.UP],
			[[0, 1, 5, 4], Vector3.DOWN], [[4, 5, 7, 6], Vector3.BACK], [[0, 2, 3, 1], Vector3.FORWARD]]
		for f: Array in faces:
			var idx: Array = f[0]
			var n: Vector3 = (xform.basis * (f[1] as Vector3)).normalized()
			var q: Array[Vector3] = [p[int(idx[0])], p[int(idx[1])], p[int(idx[2])], p[int(idx[3])]]
			_quad(q, n, c, emission)

	## Upright n-sided prism (cylinder approximation), centred at xform.origin.
	func add_prism(radius: float, height: float, sides: int, xform: Transform3D, color: Color,
			emission: float = 0.0) -> void:
		var c: Color = _vc(color)
		c.a = 0.0
		var hh: float = height * 0.5
		var ring_lo: Array[Vector3] = []
		var ring_hi: Array[Vector3] = []
		for i in sides:
			var a: float = TAU * i / sides
			var o: Vector3 = Vector3(cos(a) * radius, 0.0, sin(a) * radius)
			ring_lo.append(xform * (o + Vector3(0.0, -hh, 0.0)))
			ring_hi.append(xform * (o + Vector3(0.0, hh, 0.0)))
		var top: Vector3 = xform * Vector3(0.0, hh, 0.0)
		var bottom: Vector3 = xform * Vector3(0.0, -hh, 0.0)
		var up: Vector3 = (xform.basis * Vector3.UP).normalized()
		for i in sides:
			var j: int = (i + 1) % sides
			var mid: float = TAU * (i + 0.5) / sides
			var n: Vector3 = (xform.basis * Vector3(cos(mid), 0.0, sin(mid))).normalized()
			var q: Array[Vector3] = [ring_lo[i], ring_hi[i], ring_hi[j], ring_lo[j]]
			_quad(q, n, c, emission)
			_tri(top, ring_hi[j], ring_hi[i], up, c, emission)
			_tri(bottom, ring_lo[i], ring_lo[j], -up, c, emission)

	func commit() -> ArrayMesh:
		var mesh: ArrayMesh = ArrayMesh.new()
		if verts.is_empty():
			return mesh
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_TEX_UV2] = uv2
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return mesh


static func _xf(pos: Vector3, yaw: float = 0.0, roll: float = 0.0) -> Transform3D:
	var b: Basis = Basis(Vector3.UP, yaw)
	if roll != 0.0:
		b = b * Basis(Vector3.BACK, roll)
	return Transform3D(b, pos)


static func _add_collision_box(body: StaticBody3D, size: Vector3, pos: Vector3, yaw: float = 0.0) -> void:
	var cs: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.transform = _xf(pos, yaw)
	body.add_child(cs)


# ======================================================================================================================
# Rooms
# ======================================================================================================================

## Room-local anchor transforms (02_TECH §8.5): player_spawn / stairs / boss_spot at the centre; safe_door at the centre
## of the first wall WITHOUT a door in N, E, S, W order, 0.6 m in front of it, facing the room centre (front = −Z);
## a room with 4 doors → centre, facing +Z.
static func anchor_for(spec: RoomSpec, anchor: StringName) -> Transform3D:
	if anchor != &"safe_door":
		return Transform3D.IDENTITY
	var dist: float = HALF - WALL_T - 0.6
	for b: int in RoomCell.DIR_BITS:
		if spec.doors & b:
			continue
		var off: Vector2i = RoomCell.dir_offset(b)
		var pos: Vector3 = Vector3(off.x, 0.0, off.y) * dist
		var to_center: Vector3 = -Vector3(off.x, 0.0, off.y)
		return Transform3D(Basis(Vector3.UP, atan2(-to_center.x, -to_center.z)), pos)
	return Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)


## Fills `root` (an empty node returned by EnvKit.build_room) with "Geometry", "Props", "Collision", "Light" and the
## kind-specific set pieces (STAIRS → stairs, SAFE → safe door) — same child names as the art kit.
static func build_room(spec: RoomSpec, root: Node3D) -> void:
	root.set_meta(META_FALLBACK, true)
	var pal: Dictionary = spec.palette
	var c_floor: Color = col(pal, "floor", Color("#3a3f4b"))
	var c_wall: Color = col(pal, "wall", Color("#1f5f66"))
	var c_accent: Color = col(pal, "accent", NOVA_MAGENTA)
	var c_light: Color = col(pal, "light", Color("#ffd59e"))
	var geo: MeshBuilder = MeshBuilder.new()
	var props: MeshBuilder = MeshBuilder.new()
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = 1
	body.collision_mask = 0
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = spec.seed
	# Floor (tiled) + collision. STAIRS: the floor leaves the stair pit open (x ±2, z 0..−5 at the stairs anchor).
	if int(spec.kind) == RoomSpec.Kind.STAIRS:
		for part: Array in [[Vector3(-5.0, -0.1, 0.0), Vector3(6.0, 0.2, ROOM_SIZE)],
				[Vector3(5.0, -0.1, 0.0), Vector3(6.0, 0.2, ROOM_SIZE)],
				[Vector3(0.0, -0.1, 4.0), Vector3(4.0, 0.2, 8.0)], [Vector3(0.0, -0.1, -6.5), Vector3(4.0, 0.2, 3.0)]]:
			geo.add_box(part[1], _xf(part[0]), c_floor, 0.0, true)
	else:
		geo.add_box(Vector3(ROOM_SIZE, 0.2, ROOM_SIZE), _xf(Vector3(0.0, -0.1, 0.0)), c_floor, 0.0, true)
	_add_collision_box(body, Vector3(ROOM_SIZE, 0.2, ROOM_SIZE), Vector3(0.0, -0.1, 0.0))
	# Walls with door openings.
	for b: int in RoomCell.DIR_BITS:
		_wall_side(geo, body, b, (spec.doors & b) != 0, c_wall, c_accent, spec.variant)
	# Corner pillars (A-style warning band).
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var p: Vector3 = Vector3(sx * (HALF - 0.35), WALL_HEIGHT * 0.5, sz * (HALF - 0.35))
			geo.add_box(Vector3(0.7, WALL_HEIGHT, 0.7), _xf(p), c_wall.darkened(0.2))
			geo.add_box(Vector3(0.74, 0.3, 0.74), _xf(Vector3(p.x, 1.0, p.z)), WARN_YELLOW)
			geo.add_box(Vector3(0.9, 0.3, 0.9), _xf(Vector3(p.x, WALL_HEIGHT - 0.15, p.z)), c_wall.darkened(0.1))
			geo.add_box(Vector3(0.94, 0.08, 0.94), _xf(Vector3(p.x, WALL_HEIGHT + 0.04, p.z)), INK)
	# Decoration variant (03_ART §6.2) on walls without doors.
	_variant_deco(props, spec, c_accent)
	# Corner clutter in the border strip (outside the clear zone and the door corridors).
	_clutter(props, body, rng, c_wall)
	# Kind specific floor markings.
	match int(spec.kind):
		RoomSpec.Kind.START:
			_ring(props, 1.6, NOVA_CYAN, 0.8)
		RoomSpec.Kind.QUARTER_BOSS, RoomSpec.Kind.FLOOR_BOSS:
			_ring(props, 3.2, DANGER, 0.9)
			_ring(props, 5.0, DANGER.darkened(0.3), 0.5)
	var gmi: MeshInstance3D = MeshInstance3D.new()
	gmi.name = "Geometry"
	gmi.mesh = geo.commit()
	gmi.material_override = env_material(pal)
	gmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(gmi)
	var pmi: MeshInstance3D = MeshInstance3D.new()
	pmi.name = "Props"
	pmi.mesh = props.commit()
	pmi.material_override = env_material(pal)
	pmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(pmi)
	root.add_child(body)
	if spec.with_light:
		var light: OmniLight3D = OmniLight3D.new()
		light.name = "Light"
		light.position = Vector3(0.0, 3.0, 0.0)
		light.omni_range = ROOM_LIGHT_RANGE
		light.light_energy = ROOM_LIGHT_ENERGY
		light.light_color = c_light
		light.shadow_enabled = false
		light.distance_fade_enabled = true
		light.distance_fade_begin = 24.0
		light.distance_fade_length = 6.0
		root.add_child(light)
	match int(spec.kind):
		RoomSpec.Kind.STAIRS:
			var st: Node3D = build_prop(&"stairs_down", spec.palette)
			st.name = "Stairs"
			st.transform = anchor_for(spec, &"stairs")
			root.add_child(st)
			# One box over the pit + railings: Kai stands at the top edge (z ≥ 0), never walks down the flight.
			_add_collision_box(body, Vector3(4.5, 1.0, 5.4), Vector3(0.0, 0.5, -2.6))
		RoomSpec.Kind.SAFE:
			var door: Node3D = build_prop(&"safe_door", spec.palette)
			door.name = "SafeDoor"
			door.transform = anchor_for(spec, &"safe_door")
			root.add_child(door)


static func _wall_side(geo: MeshBuilder, body: StaticBody3D, bit: int, has_door: bool, c_wall: Color, c_accent: Color,
		variant: int) -> void:
	var off: Vector2i = RoomCell.dir_offset(bit)
	var along_x: bool = off.y != 0           # N/S walls run along X
	var line: float = HALF - WALL_T * 0.5
	var segs: Array = []                      # [center_along, length]
	if has_door:
		var seg_len: float = (ROOM_SIZE - DOOR_W) * 0.5
		segs = [[-(DOOR_W * 0.5 + seg_len * 0.5), seg_len], [DOOR_W * 0.5 + seg_len * 0.5, seg_len]]
	else:
		segs = [[0.0, ROOM_SIZE]]
	var inward: Vector3 = -Vector3(off.x, 0.0, off.y)
	var tilt: float = 0.0
	for s: Array in segs:
		var center: float = float(s[0])
		var length: float = float(s[1])
		var pos: Vector3 = Vector3(center, WALL_HEIGHT * 0.5, off.y * line) if along_x \
			else Vector3(off.x * line, WALL_HEIGHT * 0.5, center)
		var yaw: float = 0.0 if along_x else PI * 0.5
		if variant == 3 and not has_door:
			tilt = 0.02
		var wall_xf: Transform3D = Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, tilt), pos)
		geo.add_box(Vector3(length, WALL_HEIGHT, WALL_T), wall_xf, c_wall, 0.0, true)
		_add_collision_box(body, Vector3(length, WALL_HEIGHT, WALL_T), pos, yaw)
		# Skirting, top trim and accent strip on the inner face.
		var inner: Vector3 = pos + inward * (WALL_T * 0.5)
		geo.add_box(Vector3(length, 0.3, 0.12), _xf(Vector3(inner.x, 0.15, inner.z), yaw), c_wall.darkened(0.35))
		geo.add_box(Vector3(length, 0.12, 0.14), _xf(Vector3(inner.x, WALL_HEIGHT - 0.06, inner.z), yaw),
			c_wall.lightened(0.15))
		geo.add_box(Vector3(length, 0.07, 0.05), _xf(Vector3(inner.x, 2.55, inner.z) + inward * 0.03, yaw), c_accent,
			0.7)
		# INK crown over wall + top trim: clean dark silhouette from the high camera, no coplanar tops.
		var cap_c: Vector3 = Vector3(pos.x, WALL_HEIGHT + WALL_CAP_H * 0.5, pos.z) + inward * 0.04
		geo.add_box(Vector3(length, WALL_CAP_H, WALL_T + 0.18), _xf(cap_c, yaw), INK)
	if has_door:
		# Door frame: jambs + lintel (03_ART §6.2). Jambs 0.54 wide at ±2.23: the inner face sits 0.04 m inside the
		# opening, the wall segment's end face (±2.0) lies inside the jamb → no coplanar faces (z-fighting).
		var frame_c: Color = Color("#3a3a44")
		var frame_yaw: float = 0.0 if along_x else PI * 0.5
		for side: float in [-1.0, 1.0]:
			var a: float = side * (DOOR_W * 0.5 + 0.23)
			var jp: Vector3 = Vector3(a, 1.5, off.y * line) if along_x else Vector3(off.x * line, 1.5, a)
			geo.add_box(Vector3(0.54, 3.0, 0.62), _xf(jp, frame_yaw), frame_c)
		var lp: Vector3 = Vector3(0.0, 3.25, off.y * line) if along_x else Vector3(off.x * line, 3.25, 0.0)
		geo.add_box(Vector3(DOOR_W + 1.0, 0.5, 0.62), _xf(lp, frame_yaw), frame_c)
		geo.add_box(Vector3(DOOR_W + 1.06, WALL_CAP_H, 0.7), _xf(lp + Vector3(0.0, 0.25 + WALL_CAP_H * 0.5, 0.0),
			frame_yaw), INK)
		geo.add_box(Vector3(DOOR_W, 0.06, 0.64), _xf(lp + Vector3(0.0, -0.27, 0.0), 0.0 if along_x else PI * 0.5),
			WARN_YELLOW, 0.4)


## Variants (03_ART §6.2): 0 plain, 1 posters, 2 pipes, 3 graffiti; placed on the first wall without a door.
static func _variant_deco(props: MeshBuilder, spec: RoomSpec, c_accent: Color) -> void:
	var wall_bit: int = 0
	for b: int in RoomCell.DIR_BITS:
		if not (spec.doors & b):
			wall_bit = b
			break
	if wall_bit == 0 or spec.variant == 0:
		return
	var off: Vector2i = RoomCell.dir_offset(wall_bit)
	var along_x: bool = off.y != 0
	var face: float = HALF - WALL_T - 0.04
	var yaw: float = 0.0 if along_x else PI * 0.5
	match spec.variant:
		1:
			for a: float in [-3.5, 3.5]:
				var p: Vector3 = Vector3(a, 1.7, off.y * face) if along_x else Vector3(off.x * face, 1.7, a)
				props.add_box(Vector3(1.3, 1.7, 0.05), _xf(p, yaw), INK)
				props.add_box(Vector3(1.2, 1.6, 0.07), _xf(p, yaw), c_accent, 0.6)
				props.add_box(Vector3(0.9, 0.18, 0.08), _xf(p + Vector3(0.0, 0.35, 0.0), yaw), PAPER, 0.3)
		2:
			for h: float in [0.8, 3.0]:
				var p: Vector3 = Vector3(0.0, h, off.y * (face - 0.15)) if along_x \
					else Vector3(off.x * (face - 0.15), h, 0.0)
				props.add_box(Vector3(ROOM_SIZE - 1.6, 0.24, 0.24), _xf(p, yaw), Color("#8a4b2a"))
				for a: float in [-4.0, 0.0, 4.0]:
					var mp: Vector3 = p + (Vector3(a, 0.0, 0.0) if along_x else Vector3(0.0, 0.0, a))
					props.add_box(Vector3(0.12, 0.34, 0.34), _xf(mp, yaw), Color("#6b3a22"))
		3:
			for i in 3:
				var a: float = -2.0 + i * 1.6
				var p: Vector3 = Vector3(a, 1.6 + i * 0.2, off.y * face) if along_x \
					else Vector3(off.x * face, 1.6 + i * 0.2, a)
				var xf: Transform3D = Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, 0.5 - i * 0.35), p)
				props.add_box(Vector3(1.6, 0.16, 0.05), xf, Color("#e23e9b"), 0.4)


## Crates / barrels in the corner squares (border strip: |x|, |z| >= 5.4 — outside the clear zone r 5 and away from
## the 4 m door corridors in the middle of each edge).
static func _clutter(props: MeshBuilder, body: StaticBody3D, rng: RandomNumberGenerator, c_wall: Color) -> void:
	var corners: Array[Vector2] = [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	for corner: Vector2 in corners:
		if rng.randf() < 0.35:
			continue
		var base: Vector2 = corner * rng.randf_range(5.9, 6.3)
		if rng.randf() < 0.5:
			var size: float = rng.randf_range(0.7, 0.95)
			var stack: int = rng.randi_range(1, 2)
			for k in stack:
				var yaw: float = rng.randf_range(-0.3, 0.3)
				var p: Vector3 = Vector3(base.x, size * 0.5 + k * size, base.y)
				props.add_box(Vector3(size, size, size), _xf(p, yaw), Color("#8a5a32"))
				props.add_box(Vector3(size + 0.04, 0.1, size + 0.04), _xf(p + Vector3(0.0, size * 0.25, 0.0), yaw),
					Color("#6b4a2e"))
			_add_collision_box(body, Vector3(size, size * stack, size), Vector3(base.x, size * stack * 0.5, base.y))
		else:
			var green: bool = rng.randf() < 0.5
			var bc: Color = Color("#3e6b4a") if green else WARN_YELLOW
			props.add_prism(0.32, 0.9, 8, _xf(Vector3(base.x, 0.45, base.y)), bc)
			props.add_prism(0.34, 0.06, 8, _xf(Vector3(base.x, 0.25, base.y)), c_wall.darkened(0.4))
			props.add_prism(0.34, 0.06, 8, _xf(Vector3(base.x, 0.7, base.y)), c_wall.darkened(0.4))
			if not green:
				props.add_prism(0.26, 0.04, 8, _xf(Vector3(base.x, 0.92, base.y)), Color("#7cc242"), 0.8)
			_add_collision_box(body, Vector3(0.66, 0.9, 0.66), Vector3(base.x, 0.45, base.y))


static func _ring(props: MeshBuilder, radius: float, color: Color, emission: float) -> void:
	var n: int = 24
	for i in n:
		var a: float = TAU * (i + 0.5) / n
		var p: Vector3 = Vector3(cos(a) * radius, 0.012, sin(a) * radius)
		props.add_box(Vector3(radius * TAU / n * 0.7, 0.02, 0.12), Transform3D(Basis(Vector3.UP, -a + PI * 0.5), p),
			color, emission)


## Fallback environment with the 03_ART §4.2 `explore` values: background = fog × 0.6, ambient = palette `ambient`
## at 0.80, exponential fog 0.030 in the fog colour, AgX at exposure 1.0, glow 0.8 on quality high.
static func environment(palette: Dictionary, quality: StringName) -> Environment:
	var env: Environment = Environment.new()
	env.set_meta(META_FALLBACK, true)
	var fog: Color = col(palette, "fog", Color("#1a1430"))
	env.background_mode = Environment.BG_COLOR
	env.background_color = background_of(fog)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = col(palette, "ambient", Color("#2a2440"))
	env.ambient_light_energy = AMBIENT_ENERGY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.0
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = fog
	env.fog_density = FOG_DENSITY
	env.fog_sky_affect = 0.0
	env.glow_enabled = quality == &"high"
	env.glow_intensity = 0.8
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.0
	return env


## 03_ART §4.2: BG_COLOR = palette fog × 0.6.
static func background_of(fog: Color) -> Color:
	return Color(fog.r * 0.6, fog.g * 0.6, fog.b * 0.6, 1.0)


## 03_ART §4.3 explore sun: palette `key`, energy 1.1, rotation (−55°, 35°, 0), shadows on high (30 m).
static func sun(palette: Dictionary, quality: StringName) -> DirectionalLight3D:
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation = Vector3(deg_to_rad(-55.0), deg_to_rad(35.0), 0.0)
	light.light_color = col(palette, "key", Color("#ffb866"))
	light.light_energy = SUN_ENERGY
	light.shadow_enabled = quality == &"high"
	light.shadow_bias = 0.03
	light.shadow_normal_bias = 1.0
	light.directional_shadow_max_distance = 30.0
	return light


# ======================================================================================================================
# Props
# ======================================================================================================================

static func _mesh_part(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO,
		part_name: String = "") -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = rot
	mi.material_override = mat
	if part_name != "":
		mi.name = part_name
	parent.add_child(mi)
	return mi


static func _box(size: Vector3) -> BoxMesh:
	var m: BoxMesh = BoxMesh.new()
	m.size = size
	return m


static func _cyl(top: float, bottom: float, height: float, radial: int = 8) -> CylinderMesh:
	var m: CylinderMesh = CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	m.radial_segments = radial
	m.rings = 1
	return m


static func _sphere(radius: float, height: float = -1.0) -> SphereMesh:
	var m: SphereMesh = SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0 if height < 0.0 else height
	m.radial_segments = 10
	m.rings = 6
	return m


static func _capsule(radius: float, height: float) -> CapsuleMesh:
	var m: CapsuleMesh = CapsuleMesh.new()
	m.radius = radius
	m.height = maxf(height, radius * 2.0)
	m.radial_segments = 10
	m.rings = 2
	return m


## Sign text: thick INK outline and an HDR modulate (× SIGN_HDR) so it glows through AgX and fog, on an INK backing
## plate (same billboard / depth mode as the text; drawn first via render priority) for ≥ 4.5:1 contrast on any wall.
static func _label(parent: Node3D, text: String, pos: Vector3, color: Color, size: int = 48,
		billboard: BaseMaterial3D.BillboardMode = BaseMaterial3D.BILLBOARD_DISABLED, no_depth: bool = false) -> Label3D:
	var l: Label3D = Label3D.new()
	l.text = text
	l.position = pos
	l.modulate = Color(color.r * SIGN_HDR, color.g * SIGN_HDR, color.b * SIGN_HDR, 1.0)
	l.font_size = size
	l.outline_size = 18
	l.outline_modulate = INK
	l.pixel_size = 0.006
	l.billboard = billboard
	l.no_depth_test = no_depth
	l.render_priority = 2
	l.outline_render_priority = 1
	parent.add_child(l)
	var font: Font = ThemeDB.fallback_font
	var px: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size) if font != null \
		else Vector2(size * 0.6 * text.length(), size)
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(px.x * l.pixel_size + 0.3, size * l.pixel_size * 1.35)
	var plate: MeshInstance3D = MeshInstance3D.new()
	plate.name = "Plate"
	plate.mesh = quad
	plate.position = Vector3(0.0, 0.0, -0.02)
	plate.material_override = _plate_material(billboard, no_depth)
	plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	l.add_child(plate)
	return l


static func _plate_material(billboard: BaseMaterial3D.BillboardMode, no_depth: bool) -> Material:
	var key: String = "plate|%d|%s" % [billboard, str(no_depth)]
	if not _materials.has(key):
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(INK, 0.9)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.billboard_mode = billboard
		m.no_depth_test = no_depth
		m.disable_fog = true
		m.render_priority = 0
		_materials[key] = m
	return _materials[key]


## Fallback prop by PropKit id (only the ids the exploration uses). `opts.type` for chests (wood/metal/locked).
static func build_prop(id: StringName, palette: Dictionary = {}, opts: Dictionary = {}) -> Node3D:
	var root: Node3D = Node3D.new()
	fill_prop(root, id, palette, opts)
	return root


## Same as build_prop but fills an existing (empty) node, e.g. the ChestProp returned by the art-kit stub.
static func fill_prop(root: Node3D, id: StringName, palette: Dictionary = {}, opts: Dictionary = {}) -> void:
	root.set_meta(META_FALLBACK, true)
	var accent: Color = col(palette, "accent", NOVA_MAGENTA)
	match id:
		&"chest":
			_chest(root, str(opts.get("type", "wood")))
		&"gate":
			var dark: Color = Color("#2a2530")
			_mesh_part(root, _box(Vector3(4.2, 0.3, 0.3)), Vector3(0.0, 2.85, 0.0), toon(dark))
			_mesh_part(root, _box(Vector3(4.2, 0.2, 0.25)), Vector3(0.0, 0.25, 0.0), toon(dark))
			for i in 9:
				var x: float = -1.8 + i * 0.45
				_mesh_part(root, _cyl(0.05, 0.05, 2.7, 6), Vector3(x, 1.4, 0.0),
					toon(Color("#8a8f96"), true, 0.0, 0.012))
			for i in 4:
				var x2: float = -1.6 + i * 1.07
				_mesh_part(root, _box(Vector3(0.5, 0.18, 0.32)), Vector3(x2, 1.5, 0.0),
					toon(WARN_YELLOW if i % 2 == 0 else INK, false))
			_mesh_part(root, _sphere(0.09), Vector3(0.0, 2.85, -0.18), glow(DANGER, 2.0, 4.0))
		&"stairs_down":
			# 03_ART §6.3: 10 steps 4.0 × 0.25 × 0.5 (each −0.25 y, −0.5 z) into an open pit (the STAIRS room floor
			# leaves x ±2, z 0..−5 open), gold edge strips, dark pit walls, railings, light column, sign + arrow.
			var pit_c: Color = Color("#1e1826")
			for i in 10:
				var top: float = -0.25 * (i + 1)
				var shade: Color = Color("#6e6a72").lerp(INK, minf(1.0, i / 9.0) * 0.85)
				var h: float = top + PIT_DEPTH
				_mesh_part(root, _box(Vector3(4.0, h, 0.5)), Vector3(0.0, top - h * 0.5, -0.25 - 0.5 * i),
					toon(shade, false))
				_mesh_part(root, _box(Vector3(4.0, 0.03, 0.06)), Vector3(0.0, top + 0.015, -0.03 - 0.5 * i),
					toon(WARN_YELLOW.lerp(INK, i / 12.0), false, 0.3))
			for side: float in [-1.0, 1.0]:
				_mesh_part(root, _box(Vector3(0.2, PIT_DEPTH, 5.0)), Vector3(side * 2.1, -PIT_DEPTH * 0.5, -2.5),
					toon(pit_c, false))
			_mesh_part(root, _box(Vector3(4.4, PIT_DEPTH, 0.2)), Vector3(0.0, -PIT_DEPTH * 0.5, -5.1),
				toon(pit_c, false))
			_mesh_part(root, _box(Vector3(4.4, 0.05, 0.1)), Vector3(0.0, 0.025, 0.02), toon(WARN_YELLOW, false, 0.5))
			var rail_c: Color = Color("#4a4e58")
			for side: float in [-1.0, 1.0]:
				for z: float in [-0.2, -2.6, -5.0]:
					_mesh_part(root, _cyl(0.04, 0.04, 1.0, 6), Vector3(side * 2.1, 0.5, z),
						toon(rail_c, true, 0.0, 0.01))
				_mesh_part(root, _box(Vector3(0.08, 0.08, 5.0)), Vector3(side * 2.1, 1.0, -2.6),
					toon(rail_c, true, 0.0, 0.01))
			_mesh_part(root, _box(Vector3(4.3, 0.08, 0.08)), Vector3(0.0, 1.0, -5.05), toon(rail_c, true, 0.0, 0.01))
			var col_mi: MeshInstance3D = _mesh_part(root, _cyl(1.2, 1.2, 4.5, 16), Vector3(0.0, -0.25, -2.5),
				beam(HYPE_GOLD, 0.07))
			col_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			# Beacon inside the −38° frame from 4–12 m: arrow at 1.9 m (bobs 0.1 m @ 1 Hz), sign at 2.4 m.
			var arrow: PrismMesh = PrismMesh.new()
			arrow.size = Vector3(0.6, 0.5, 0.1)
			var ami: MeshInstance3D = _mesh_part(root, arrow, Vector3(0.0, 1.9, -2.5), glow(HYPE_GOLD, 2.0, 0.0, 0.1),
				Vector3(PI, 0.0, 0.0), "Arrow")
			ami.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var next_floor: int = int(opts.get("next_floor", 2))
			_label(root, "ETAGE %d" % next_floor, Vector3(0.0, 2.45, -2.5), HYPE_GOLD, 64,
				BaseMaterial3D.BILLBOARD_ENABLED, true)
		&"safe_door":
			var frame: Color = Color("#4a5a60")
			_mesh_part(root, _box(Vector3(3.0, 0.3, 0.4)), Vector3(0.0, 3.0, 0.0), toon(frame))
			for side: float in [-1.0, 1.0]:
				_mesh_part(root, _box(Vector3(0.3, 3.0, 0.4)), Vector3(side * 1.35, 1.5, 0.0), toon(frame))
				_mesh_part(root, _box(Vector3(1.15, 2.8, 0.15)), Vector3(side * 0.6, 1.4, -0.05),
					toon(Color("#6a7a80"), true, 0.0, 0.012))
				_mesh_part(root, _box(Vector3(0.08, 2.6, 0.18)), Vector3(side * 0.05, 1.4, -0.06),
					glow(EXIT_GREEN, 1.6))
			_mesh_part(root, _box(Vector3(2.4, 0.1, 0.12)), Vector3(0.0, 2.95, -0.2), glow(EXIT_GREEN, 2.0))
			var sl: Label3D = _label(root, "SAFE ROOM", Vector3(0.0, 3.45, -0.22), EXIT_GREEN, 56)
			sl.rotation = Vector3(0.0, PI, 0.0)
		&"camera_drone":
			_mesh_part(root, _box(Vector3(0.5, 0.15, 0.5)), Vector3(0.0, 1.6, 0.0), toon(Color("#1a1420")))
			for sx: float in [-1.0, 1.0]:
				for sz: float in [-1.0, 1.0]:
					_mesh_part(root, _cyl(0.14, 0.14, 0.02, 10), Vector3(sx * 0.32, 1.7, sz * 0.32),
						toon(Color("#8a8f96"), false))
			_mesh_part(root, _sphere(0.07), Vector3(0.0, 1.58, -0.27), glow(Color("#ff3b30"), 2.2, 6.0))
			_mesh_part(root, _cyl(0.02, 0.02, 1.6, 6), Vector3(0.0, 0.8, 0.0), toon(INK, false))
			_mesh_part(root, _cyl(0.5, 0.5, 0.04, 16), Vector3(0.0, 0.02, 0.0), glow(accent, 0.8, 2.0))
		&"phone_booth":
			_mesh_part(root, _box(Vector3(1.1, 2.4, 1.1)), Vector3(0.0, 1.2, 0.0), toon(Color("#c23b22")))
			_mesh_part(root, _box(Vector3(0.9, 1.6, 1.12)), Vector3(0.0, 1.3, 0.0), glow(Color("#ffe9b0"), 0.9))
			_mesh_part(root, _box(Vector3(1.2, 0.25, 1.2)), Vector3(0.0, 2.5, 0.0), toon(INK))
			_label(root, "TELEFON", Vector3(0.0, 2.9, 0.0), PAPER, 40, BaseMaterial3D.BILLBOARD_FIXED_Y)
		&"fortune_wheel":
			_mesh_part(root, _box(Vector3(0.3, 2.2, 0.3)), Vector3(0.0, 1.1, 0.15), toon(Color("#3a3a44")))
			# "Wheel" tilts the disc upright (axle along Z), "Wheel/Spin" turns around the axle.
			var wheel: Node3D = Node3D.new()
			wheel.name = "Wheel"
			wheel.position = Vector3(0.0, 2.0, -0.05)
			wheel.rotation = Vector3(PI * 0.5, 0.0, 0.0)
			root.add_child(wheel)
			var spin: Node3D = Node3D.new()
			spin.name = "Spin"
			wheel.add_child(spin)
			_mesh_part(spin, _cyl(1.1, 1.1, 0.12, 20), Vector3.ZERO, toon(PAPER))
			var seg_cols: Array[Color] = [NOVA_MAGENTA, HYPE_GOLD, NOVA_CYAN, EXIT_GREEN, Color("#b05cff"), DANGER]
			for i in 6:
				var a: float = TAU * i / 6.0
				_mesh_part(spin, _box(Vector3(0.28, 0.06, 0.95)), Vector3(cos(a) * 0.55, -0.07, sin(a) * 0.55),
					glow(seg_cols[i], 1.1), Vector3(0.0, -a + PI * 0.5, 0.0))
			_mesh_part(root, _sphere(0.16), Vector3(0.0, 2.0, -0.18), toon(HYPE_GOLD, true, 0.4))
			_mesh_part(root, _box(Vector3(0.12, 0.3, 0.08)), Vector3(0.0, 3.15, -0.15), toon(DANGER, true, 0.3))
			_label(root, "DOOMSCROLL+", Vector3(0.0, 3.55, -0.1), Color("#c890ff"), 40,
				BaseMaterial3D.BILLBOARD_FIXED_Y)
		&"lever":
			_mesh_part(root, _box(Vector3(0.8, 0.9, 0.5)), Vector3(0.0, 0.45, 0.0), toon(Color("#5a6270")))
			var pivot: Node3D = Node3D.new()
			pivot.name = "Handle"
			pivot.position = Vector3(0.0, 0.9, 0.0)
			pivot.rotation = Vector3(deg_to_rad(-35.0), 0.0, 0.0)
			root.add_child(pivot)
			_mesh_part(pivot, _cyl(0.05, 0.05, 0.9, 6), Vector3(0.0, 0.45, 0.0), toon(Color("#8a8f96")))
			_mesh_part(pivot, _sphere(0.12), Vector3(0.0, 0.92, 0.0), toon(DANGER, true, 0.3))
			_mesh_part(root, _box(Vector3(0.5, 0.1, 0.52)), Vector3(0.0, 0.7, 0.0), toon(WARN_YELLOW, false))
		&"broken_vending":
			var body: Node3D = Node3D.new()
			body.rotation = Vector3(0.0, 0.0, deg_to_rad(6.0))
			root.add_child(body)
			_mesh_part(body, _box(Vector3(1.0, 1.9, 0.8)), Vector3(0.0, 0.95, 0.0), toon(Color("#7a1f3a")))
			_mesh_part(body, _box(Vector3(0.6, 1.0, 0.04)), Vector3(-0.1, 1.15, -0.41),
				glow(Color("#ffe9b0"), 0.6, 9.0))
			_mesh_part(body, _box(Vector3(1.0, 0.25, 0.12)), Vector3(0.0, 1.78, -0.42), glow(NOVA_MAGENTA, 1.2))
			_mesh_part(body, _box(Vector3(0.12, 0.3, 0.05)), Vector3(0.33, 1.0, -0.42), glow(NOVA_CYAN, 1.5))
		_:
			_mesh_part(root, _box(Vector3(0.8, 0.8, 0.8)), Vector3(0.0, 0.4, 0.0), toon(accent))


static func _chest(root: Node3D, type: String) -> void:
	var body_c: Color = Color("#8a5a32")
	var trim_c: Color = Color("#cd7f32")
	if type == "metal":
		body_c = Color("#7c8a94")
		trim_c = Color("#c0c8d2")
	elif type == "locked":
		body_c = Color("#33507e")
		trim_c = Color("#ffc93c")
	_mesh_part(root, _box(Vector3(0.9, 0.45, 0.6)), Vector3(0.0, 0.225, 0.0), toon(body_c))
	var lid: Node3D = Node3D.new()
	lid.name = "LidPivot"
	lid.position = Vector3(0.0, 0.45, 0.3)
	root.add_child(lid)
	_mesh_part(lid, _box(Vector3(0.92, 0.15, 0.62)), Vector3(0.0, 0.075, -0.31), toon(body_c.lightened(0.08)))
	_mesh_part(lid, _box(Vector3(0.94, 0.05, 0.08)), Vector3(0.0, 0.1, -0.6), toon(trim_c, false, 0.2))
	for sx: float in [-1.0, 1.0]:
		_mesh_part(root, _box(Vector3(0.08, 0.47, 0.62)), Vector3(sx * 0.43, 0.235, 0.0), toon(trim_c, false, 0.15))
	if type == "locked":
		_mesh_part(root, _box(Vector3(0.18, 0.2, 0.06)), Vector3(0.0, 0.32, -0.32), toon(DANGER, true, 0.5))
	# Sparkle of an unopened chest: above the closed lid (0.45–0.60 m) at the front corner.
	var glint: MeshInstance3D = _mesh_part(root, _sphere(0.05), Vector3(0.3, 0.7, -0.25), glow(HYPE_GOLD, 2.5, 5.0),
		Vector3.ZERO, "Glint")
	glint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Lid animation of a fallback chest (the art-kit stub ChestProp has no visuals of its own).
static func open_chest(root: Node3D, animated: bool) -> void:
	var lid: Node3D = root.get_node_or_null("LidPivot") as Node3D
	var glint: Node3D = root.get_node_or_null("Glint") as Node3D
	if glint != null:
		glint.visible = false
	if lid == null:
		return
	var target: float = deg_to_rad(-110.0)
	if animated and root.is_inside_tree():
		var tw: Tween = root.create_tween()
		tw.tween_property(lid, "rotation:x", target, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		lid.rotation.x = target


# ======================================================================================================================
# Characters
# ======================================================================================================================

## Simplified figure per ModelSpec.base (03_ART §5.3 sizes, front = −Z) added under `rig` (the empty CharacterRig of the
## art-kit stub). Sets rig.height (top of head) when the rig has that property.
static func build_character(model: Dictionary, rig: Node3D) -> void:
	rig.set_meta(META_FALLBACK, true)
	var body: Node3D = Node3D.new()
	body.name = "FallbackBody"
	rig.add_child(body)
	var cols: Dictionary = model.get("colors", {})
	var prim: Color = col(cols, "primary", Color("#8a8f96"))
	var sec: Color = col(cols, "secondary", prim.darkened(0.3))
	var acc: Color = col(cols, "accent", sec.darkened(0.2))
	var skin: Color = col(cols, "skin", Color("#e8b48f"))
	var eye: Color = col(cols, "eyes", INK)
	var s: float = maxf(0.2, float(model.get("scale", 1.0)))
	var height: float = 1.0
	match str(model.get("base", "humanoid")):
		"humanoid":
			# Chibi (03_ART pillar 1): head Ø 0.58 m ≈ 1/3 of 1.75 m, eyes at ~47 % of the head height.
			height = 1.75
			for sx: float in [-1.0, 1.0]:
				_mesh_part(body, _capsule(0.11, 0.62), Vector3(sx * 0.12, 0.31, 0.0), toon(sec))
				_mesh_part(body, _box(Vector3(0.17, 0.09, 0.27)), Vector3(sx * 0.12, 0.045, -0.04), toon(acc))
				_mesh_part(body, _capsule(0.08, 0.5), Vector3(sx * 0.31, 0.86, 0.0), toon(prim),
					Vector3(0.0, 0.0, sx * 0.16))
				_mesh_part(body, _sphere(0.08), Vector3(sx * 0.36, 0.62, 0.0), toon(skin))
				_mesh_part(body, _sphere(0.05, 0.075), Vector3(sx * 0.1, 1.43, -0.255), toon(eye, false))
				_mesh_part(body, _sphere(0.016), Vector3(sx * 0.1 - 0.018, 1.455, -0.3), glow(PAPER, 1.2))
			_mesh_part(body, _capsule(0.23, 0.62), Vector3(0.0, 0.86, 0.0), toon(prim))
			_mesh_part(body, _sphere(0.29), Vector3(0.0, 1.45, 0.0), toon(skin))
			_mesh_part(body, _sphere(0.305, 0.36), Vector3(0.0, 1.6, 0.04), toon(acc))
		"pug":
			height = 0.6
			_mesh_part(body, _capsule(0.17, 0.56), Vector3(0.0, 0.3, 0.06), toon(prim), Vector3(PI * 0.5, 0.0, 0.0))
			_mesh_part(body, _sphere(0.17), Vector3(0.0, 0.46, -0.24), toon(prim))
			_mesh_part(body, _sphere(0.09, 0.12), Vector3(0.0, 0.41, -0.38), toon(sec))
			for sx: float in [-1.0, 1.0]:
				_mesh_part(body, _box(Vector3(0.1, 0.12, 0.05)), Vector3(sx * 0.13, 0.6, -0.22), toon(sec),
					Vector3(0.0, 0.0, sx * 0.5))
				_mesh_part(body, _sphere(0.035), Vector3(sx * 0.07, 0.5, -0.38), toon(eye, false))
				for sz: float in [-1.0, 1.0]:
					_mesh_part(body, _capsule(0.05, 0.22), Vector3(sx * 0.1, 0.11, 0.06 + sz * 0.16), toon(prim))
			_mesh_part(body, _sphere(0.06), Vector3(0.0, 0.46, 0.33), toon(prim))
			_mesh_part(body, _box(Vector3(0.36, 0.3, 0.04)), Vector3(0.0, 0.36, 0.2), toon(acc),
				Vector3(-0.35, 0.0, 0.0))
		"rodent" when _rodent_upright(model):
			# Pose rule (03_ART §5.3, 02_TECH resolve_pose): "auto" → upright from scale 1.0, else quadruped.
			height = 1.15
			for sx: float in [-1.0, 1.0]:
				_mesh_part(body, _capsule(0.08, 0.4), Vector3(sx * 0.12, 0.2, 0.0), toon(prim))
				_mesh_part(body, _box(Vector3(0.14, 0.05, 0.22)), Vector3(sx * 0.12, 0.025, -0.06), toon(sec))
				_mesh_part(body, _capsule(0.06, 0.36), Vector3(sx * 0.24, 0.62, -0.06), toon(prim),
					Vector3(0.5, 0.0, sx * 0.3))
				_mesh_part(body, _sphere(0.08, 0.04), Vector3(sx * 0.13, 1.14, 0.0), toon(sec),
					Vector3(PI * 0.5, 0.0, 0.0))
				_mesh_part(body, _sphere(0.04), Vector3(sx * 0.08, 0.98, -0.2), glow(eye, 1.6))
			_mesh_part(body, _capsule(0.22, 0.62), Vector3(0.0, 0.6, 0.0), toon(prim))
			_mesh_part(body, _sphere(0.18), Vector3(0.0, 0.98, -0.04), toon(prim))
			_mesh_part(body, _sphere(0.07), Vector3(0.0, 0.94, -0.24), toon(sec))
			_mesh_part(body, _cyl(0.02, 0.05, 0.7, 6), Vector3(0.0, 0.25, 0.35), toon(sec),
				Vector3(PI * 0.5 + 0.6, 0.0, 0.0))
		"rodent":
			height = 0.7
			_mesh_part(body, _capsule(0.16, 0.56), Vector3(0.0, 0.22, 0.05), toon(prim), Vector3(PI * 0.5, 0.0, 0.0))
			_mesh_part(body, _sphere(0.13), Vector3(0.0, 0.3, -0.28), toon(prim))
			_mesh_part(body, _sphere(0.05), Vector3(0.0, 0.27, -0.42), toon(sec))
			for sx: float in [-1.0, 1.0]:
				_mesh_part(body, _sphere(0.06, 0.03), Vector3(sx * 0.09, 0.43, -0.26), toon(sec),
					Vector3(PI * 0.5, 0.0, 0.0))
				_mesh_part(body, _sphere(0.03), Vector3(sx * 0.06, 0.34, -0.38), glow(eye, 1.6))
				for sz: float in [-1.0, 1.0]:
					_mesh_part(body, _capsule(0.04, 0.14), Vector3(sx * 0.1, 0.07, 0.05 + sz * 0.15), toon(prim))
			_mesh_part(body, _cyl(0.015, 0.035, 0.6, 6), Vector3(0.0, 0.14, 0.55), toon(sec),
				Vector3(PI * 0.5 + 0.25, 0.0, 0.0))
		"blob":
			height = 0.9
			_mesh_part(body, _sphere(0.45, 0.7), Vector3(0.0, 0.35, 0.0), toon(prim, true, 0.25))
			for sx: float in [-1.0, 1.0]:
				_mesh_part(body, _sphere(0.07), Vector3(sx * 0.14, 0.5, -0.36), toon(PAPER, false))
				_mesh_part(body, _sphere(0.035), Vector3(sx * 0.14, 0.5, -0.42), toon(eye, false))
		"insect":
			height = 0.8
			_mesh_part(body, _sphere(0.24, 0.3), Vector3(0.0, 0.35, 0.1), toon(prim))
			_mesh_part(body, _sphere(0.14), Vector3(0.0, 0.38, -0.2), toon(sec))
			for sx: float in [-1.0, 1.0]:
				for k in 3:
					_mesh_part(body, _box(Vector3(0.45, 0.04, 0.04)), Vector3(sx * 0.3, 0.25, -0.05 + k * 0.15),
						toon(INK, false), Vector3(0.0, 0.0, sx * -0.6))
				_mesh_part(body, _sphere(0.035), Vector3(sx * 0.06, 0.42, -0.32), glow(eye, 1.6))
		"robot":
			height = 1.5
			_mesh_part(body, _box(Vector3(0.9, 1.3, 0.6)), Vector3(0.0, 0.65, 0.0), toon(prim))
			_mesh_part(body, _box(Vector3(0.6, 0.35, 0.04)), Vector3(0.0, 1.0, -0.31), glow(sec.lightened(0.3), 1.2))
			_mesh_part(body, _box(Vector3(0.5, 0.25, 0.4)), Vector3(0.0, 1.43, 0.0), toon(acc))
			_mesh_part(body, _box(Vector3(0.3, 0.05, 0.04)), Vector3(0.0, 0.6, -0.31), toon(INK, false))
		"brute":
			height = 2.2
			for sx: float in [-1.0, 1.0]:
				_mesh_part(body, _capsule(0.18, 0.9), Vector3(sx * 0.22, 0.45, 0.0), toon(sec))
				_mesh_part(body, _capsule(0.14, 0.95), Vector3(sx * 0.62, 1.3, 0.0), toon(prim),
					Vector3(0.0, 0.0, sx * 0.12))
				_mesh_part(body, _sphere(0.035), Vector3(sx * 0.08, 2.0, -0.2), toon(eye, false))
			_mesh_part(body, _box(Vector3(0.95, 0.95, 0.6)), Vector3(0.0, 1.35, 0.0), toon(prim))
			_mesh_part(body, _sphere(0.22), Vector3(0.0, 1.98, 0.0), toon(skin))
			_mesh_part(body, _cyl(0.24, 0.24, 0.1, 10), Vector3(0.0, 2.15, 0.0), toon(acc))
			_mesh_part(body, _box(Vector3(0.32, 0.04, 0.18)), Vector3(0.0, 2.12, -0.22), toon(acc))
		"specter":
			height = 1.6
			_mesh_part(body, _cyl(0.08, 0.42, 1.2, 10), Vector3(0.0, 0.9, 0.0), toon(prim, true, 0.3))
			_mesh_part(body, _sphere(0.26), Vector3(0.0, 1.45, 0.0), toon(prim, true, 0.3))
			for sx: float in [-1.0, 1.0]:
				_mesh_part(body, _sphere(0.05), Vector3(sx * 0.09, 1.48, -0.22), glow(eye, 2.0))
		"swarm":
			height = 0.8
			for i in 5:
				var a: float = TAU * i / 5.0
				var p: Vector3 = Vector3(cos(a) * 0.45, 0.45 + 0.12 * sin(a * 2.0), sin(a) * 0.45)
				_mesh_part(body, _sphere(0.11, 0.18), p, toon(prim))
				_mesh_part(body, _sphere(0.06), p + Vector3(0.0, 0.08, -0.1), toon(sec))
				_mesh_part(body, _box(Vector3(0.03, 0.03, 0.08)), p + Vector3(0.0, 0.06, -0.18), toon(HYPE_GOLD, false))
		_:
			_mesh_part(body, _capsule(0.3, 1.2), Vector3(0.0, 0.6, 0.0), toon(prim))
	body.scale = Vector3.ONE * s
	if "height" in rig:
		rig.set("height", height * s)


static func _rodent_upright(model: Dictionary) -> bool:
	var pose: String = str(model.get("pose", "auto"))
	if pose == "upright":
		return true
	if pose == "quadruped":
		return false
	return float(model.get("scale", 1.0)) >= 1.0


## Simple procedural motion of a fallback figure: bob while moving, breathing while idle.
static func animate_character(rig: Node3D, time_sec: float, speed: float) -> void:
	if rig == null or not rig.has_meta(META_FALLBACK):
		return
	var body: Node3D = rig.get_node_or_null("FallbackBody") as Node3D
	if body == null:
		return
	if speed > 0.2:
		var freq: float = 2.0 + speed * 1.2
		body.position.y = absf(sin(time_sec * freq)) * 0.06
		body.rotation.z = sin(time_sec * freq) * 0.05
	else:
		body.position.y = sin(time_sec * 2.4) * 0.012
		body.rotation.z = 0.0
