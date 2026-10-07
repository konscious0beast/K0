# STUB(M0) — owned by M4. Replace completely, keep the public API.
class_name Materials extends RefCounted
## Material factory with cache (02_TECH §8.2).
## opts: "outline": bool (true), "outline_width": float (0.025), "rim": float (0.25), "bands": int (2),
##       "emission": Color (black), "shade": Color (palette-derived), "tile_size": float (2.0, env only),
##       "rim_color": Color (palette rim), "spec": float (0.25 = spec_strength), "wobble": float (0.0),
##       "stripes": Dictionary ({} | {"color": Color, "width": float, "speed": float})
## Same color+opts → same cached instance (fewer material switches).


static func toon(color: Color, opts: Dictionary = {}) -> ShaderMaterial:
	return null


## use_vertex_color = true
static func toon_vc(opts: Dictionary = {}) -> ShaderMaterial:
	return null


## env_tiles, vertex color, no outline
static func env(opts: Dictionary = {}) -> ShaderMaterial:
	return null


static func glow(color: Color, energy: float = 2.0) -> ShaderMaterial:
	return null


static func vfx_additive(color: Color) -> ShaderMaterial:
	return null


static func outline(width: float = 0.025, color: Color = Palette.INK) -> ShaderMaterial:
	return null


static func clear_cache() -> void:
	pass
