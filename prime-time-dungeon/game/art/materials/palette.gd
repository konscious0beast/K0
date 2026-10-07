# STUB(M0) — owned by M4. Replace completely, keep the public API.
class_name Palette extends RefCounted
## Color constants, hex parser, theme palettes (02_TECH §8.2, 03_ART §2).

const INK: Color = Color("#140d1c")            # outlines, UI-dark
const NOVA_MAGENTA: Color = Color("#ff2e88")
const NOVA_CYAN: Color = Color("#22d3ee")
const HYPE_GOLD: Color = Color("#ffc93c")
const DANGER: Color = Color("#ff4d4d")
const HEAL: Color = Color("#4ade80")
const MANA: Color = Color("#60a5fa")


static func hex(s: String, fallback: Color = Color.MAGENTA) -> Color:
	return fallback


## Keys floor, wall, accent, light, fog, ambient → Color.
static func theme_palette(theme_id: String) -> Dictionary:
	return {}


## Hex dict (FloorDef.palette) merged over theme defaults.
static func resolve(palette: Dictionary, theme_id: String) -> Dictionary:
	return {}
