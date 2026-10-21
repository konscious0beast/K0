class_name Materials extends RefCounted
## Material factory with cache (02_TECH §8.2, 03_ART §3.1).
## opts: "outline": bool (true), "outline_width": float (0.025), "rim": float (0.25), "bands": int (2),
##       "emission": Color (black), "shade": Color (palette-derived), "tile_size": float (2.0, env only),
##       "rim_color": Color (palette rim), "spec": float (0.25 = spec_strength), "wobble": float (0.0),
##       "stripes": Dictionary ({} | {"color": Color, "width": float, "speed": float})
## Art extras: "outline_color": Color (INK); env only: "grout": Color, "grout_width": float (0.04), "dirt": float (0.3),
##       "hatch": float (0.5), "albedo": Color (white).
## Same color+opts → same cached instance (fewer material switches).

const TOON_SHADER: Shader = preload("res://art/shaders/toon.gdshader")
const OUTLINE_SHADER: Shader = preload("res://art/shaders/toon_outline.gdshader")
const ENV_SHADER: Shader = preload("res://art/shaders/env_tiles.gdshader")
const GLOW_SHADER: Shader = preload("res://art/shaders/glow.gdshader")
const VFX_SHADER: Shader = preload("res://art/shaders/vfx_additive.gdshader")
const HOLO_SHADER: Shader = preload("res://art/shaders/hologram.gdshader")

## Default rim of characters: metro zone A `rim` (03_ART §2.2).
const DEFAULT_RIM: Color = Color("#ffd9a8")
## Default env shade/grout: metro zone A.
const DEFAULT_ENV_SHADE: Color = Color("#4a3e78")
const DEFAULT_GROUT: Color = Color("#1a1e24")

static var _cache: Dictionary = {}


static func toon(color: Color, opts: Dictionary = {}) -> ShaderMaterial:
	var key: String = "toon|" + color.to_html() + "|" + _opts_key(opts)
	if _cache.has(key):
		return _cache[key]
	var m: ShaderMaterial = _make_toon(opts)
	m.set_shader_parameter(&"albedo", color)
	m.set_shader_parameter(&"use_vertex_color", false)
	_cache[key] = m
	return m


## use_vertex_color = true
static func toon_vc(opts: Dictionary = {}) -> ShaderMaterial:
	var key: String = "toon_vc|" + _opts_key(opts)
	if _cache.has(key):
		return _cache[key]
	var m: ShaderMaterial = _make_toon(opts)
	m.set_shader_parameter(&"albedo", Color.WHITE)
	m.set_shader_parameter(&"use_vertex_color", true)
	_cache[key] = m
	return m


## env_tiles, vertex color, no outline
static func env(opts: Dictionary = {}) -> ShaderMaterial:
	var key: String = "env|" + _opts_key(opts)
	if _cache.has(key):
		return _cache[key]
	var m := ShaderMaterial.new()
	m.shader = ENV_SHADER
	m.set_shader_parameter(&"tile_size", float(opts.get("tile_size", 2.0)))
	m.set_shader_parameter(&"shade_color", _color(opts.get("shade", DEFAULT_ENV_SHADE), DEFAULT_ENV_SHADE))
	m.set_shader_parameter(&"grout_color", _color(opts.get("grout", DEFAULT_GROUT), DEFAULT_GROUT))
	m.set_shader_parameter(&"grout_width", float(opts.get("grout_width", 0.04)))
	m.set_shader_parameter(&"dirt_amount", float(opts.get("dirt", 0.3)))
	m.set_shader_parameter(&"hatch_strength", float(opts.get("hatch", 0.5)))
	m.set_shader_parameter(&"bands", float(opts.get("bands", 3)))
	m.set_shader_parameter(&"use_vertex_color", true)
	m.set_shader_parameter(&"albedo", _color(opts.get("albedo", Color.WHITE), Color.WHITE))
	_cache[key] = m
	return m


static func glow(color: Color, energy: float = 2.0) -> ShaderMaterial:
	return glow_ex(color, energy, 0.0, 0.0)


## Art extra: glow with pulse (Hz) and flicker (0..1, broken neon).
static func glow_ex(color: Color, energy: float, pulse_speed: float, flicker: float) -> ShaderMaterial:
	var key: String = "glow|%s|%.3f|%.3f|%.3f" % [color.to_html(), energy, pulse_speed, flicker]
	if _cache.has(key):
		return _cache[key]
	var m := ShaderMaterial.new()
	m.shader = GLOW_SHADER
	m.set_shader_parameter(&"color", color)
	m.set_shader_parameter(&"energy", energy)
	m.set_shader_parameter(&"pulse_speed", pulse_speed)
	m.set_shader_parameter(&"flicker", flicker)
	_cache[key] = m
	return m


static func vfx_additive(color: Color) -> ShaderMaterial:
	return vfx_additive_ex(color, 0, 0.5, 2.0)


## Art extra: shape 0 dot, 1 star, 2 ring, 3 spark; billboard false keeps the mesh orientation.
static func vfx_additive_ex(color: Color, shape: int, softness: float = 0.5, energy: float = 2.0,
		billboard: bool = true) -> ShaderMaterial:
	var key: String = "vfx|%s|%d|%.3f|%.3f|%s" % [color.to_html(), shape, softness, energy, str(billboard)]
	if _cache.has(key):
		return _cache[key]
	var m := ShaderMaterial.new()
	m.shader = VFX_SHADER
	m.set_shader_parameter(&"color", color)
	m.set_shader_parameter(&"shape", shape)
	m.set_shader_parameter(&"softness", softness)
	m.set_shader_parameter(&"energy", energy)
	m.set_shader_parameter(&"billboard", billboard)
	_cache[key] = m
	return m


## Art extra: hologram material (M.O.D., light columns, shields, screens).
static func hologram(color: Color = Palette.NOVA_CYAN, alpha: float = 0.6, energy: float = 1.6,
		scan_speed: float = 1.5) -> ShaderMaterial:
	var key: String = "holo|%s|%.3f|%.3f|%.3f" % [color.to_html(), alpha, energy, scan_speed]
	if _cache.has(key):
		return _cache[key]
	var m := ShaderMaterial.new()
	m.shader = HOLO_SHADER
	m.set_shader_parameter(&"color", color)
	m.set_shader_parameter(&"alpha", alpha)
	m.set_shader_parameter(&"energy", energy)
	m.set_shader_parameter(&"scan_speed", scan_speed)
	_cache[key] = m
	return m


static func outline(width: float = 0.025, color: Color = Palette.INK) -> ShaderMaterial:
	var key: String = "outline|%.4f|%s" % [width, color.to_html()]
	if _cache.has(key):
		return _cache[key]
	var m := ShaderMaterial.new()
	m.shader = OUTLINE_SHADER
	m.set_shader_parameter(&"outline_width", width)
	m.set_shader_parameter(&"outline_color", color)
	_cache[key] = m
	return m


static func clear_cache() -> void:
	_cache.clear()


## Number of cached materials (budget checks, 02_TECH §12.1).
static func cache_size() -> int:
	return _cache.size()


static func _make_toon(opts: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = TOON_SHADER
	m.set_shader_parameter(&"bands", float(opts.get("bands", 2)))
	m.set_shader_parameter(&"rim_amount", float(opts.get("rim", 0.25)))
	m.set_shader_parameter(&"rim_color", _color(opts.get("rim_color", DEFAULT_RIM), DEFAULT_RIM))
	m.set_shader_parameter(&"shade_color", _color(opts.get("shade", Palette.SHADE), Palette.SHADE))
	m.set_shader_parameter(&"spec_strength", float(opts.get("spec", 0.25)))
	m.set_shader_parameter(&"wobble_amount", float(opts.get("wobble", 0.0)))
	var emission: Color = _color(opts.get("emission", Color.BLACK), Color.BLACK)
	m.set_shader_parameter(&"emission_color", emission)
	m.set_shader_parameter(&"emission_energy", 1.0 if emission.get_luminance() > 0.0 else 0.0)
	var stripes: Dictionary = opts.get("stripes", {})
	if not stripes.is_empty():
		m.set_shader_parameter(&"stripe_color", _color(stripes.get("color", Palette.WARN_YELLOW), Palette.WARN_YELLOW))
		m.set_shader_parameter(&"stripe_duty", float(stripes.get("width", 0.5)))
		m.set_shader_parameter(&"stripe_scroll", float(stripes.get("speed", 0.0)))
		m.set_shader_parameter(&"stripe_mix", 1.0)
	if bool(opts.get("outline", true)):
		m.next_pass = outline(float(opts.get("outline_width", 0.025)),
			_color(opts.get("outline_color", Palette.INK), Palette.INK))
	return m


static func _color(v: Variant, fallback: Color) -> Color:
	if typeof(v) == TYPE_COLOR:
		return v
	if typeof(v) == TYPE_STRING or typeof(v) == TYPE_STRING_NAME:
		return Palette.hex(str(v), fallback)
	return fallback


## Stable string for an opts dictionary (sorted keys; colors as html; nested dictionaries recursively).
static func _opts_key(opts: Dictionary) -> String:
	var keys: Array = opts.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
	var out: PackedStringArray = []
	for k: Variant in keys:
		out.append("%s=%s" % [str(k), _val_key(opts[k])])
	return ",".join(out)


static func _val_key(v: Variant) -> String:
	match typeof(v):
		TYPE_COLOR:
			return (v as Color).to_html()
		TYPE_DICTIONARY:
			return "{" + _opts_key(v) + "}"
		TYPE_FLOAT:
			return "%.4f" % float(v)
		TYPE_INT:
			return "%.4f" % float(v)
		TYPE_BOOL:
			return "1" if bool(v) else "0"
	return str(v)
