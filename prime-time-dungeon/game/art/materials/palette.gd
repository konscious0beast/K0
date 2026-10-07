class_name Palette extends RefCounted
## Color constants, hex parser, theme/zone palettes (02_TECH §8.2, 03_ART §2). All colors are sRGB.
## Palette dictionaries use the keys floor, wall, accent, light, fog, ambient (FloorDef.palette, hex strings) plus the
## art keys shade, rim, grout, key, neon2 (03_ART §2.2); resolve() always returns all eleven keys as Color.

const INK: Color = Color("#140d1c")            # outlines, UI-dark
const NOVA_MAGENTA: Color = Color("#ff2e88")
const NOVA_CYAN: Color = Color("#22d3ee")
const HYPE_GOLD: Color = Color("#ffc93c")
const DANGER: Color = Color("#ff4d4d")
const HEAL: Color = Color("#4ade80")
const MANA: Color = Color("#60a5fa")

# --- art extensions (03_ART §2.1) ---
const LIVE_RED: Color = Color("#ff3b30")
const SODIUM: Color = Color("#ff9a2e")
const EXIT_GREEN: Color = Color("#2bd66b")
const SHADE: Color = Color("#5a4e8c")          # toon shadow tint of characters
const PAPER: Color = Color("#f5f0e6")          # in-game white (pure white only for hit flash)
const PANEL: Color = Color(0.0784, 0.051, 0.1098, 0.88)
const WARN_YELLOW: Color = Color("#f2c230")    # platform edge / warning band
const GRAFFITI: Color = Color("#e23e9b")
const RAIL: Color = Color("#a8b0b8")
const SLEEPER: Color = Color("#4a3a30")
const WOOD: Color = Color("#8a5a32")
const BRASS: Color = Color("#c9a227")
const STEEL: Color = Color("#d8dde2")
const DARK_METAL: Color = Color("#3a3a44")

const PALETTE_KEYS: PackedStringArray = ["floor", "wall", "accent", "light", "fog", "ambient"]
const ART_KEYS: PackedStringArray = ["shade", "rim", "grout", "key", "neon2"]

## Element colors (VFX, dissolve edges, cast flashes). 03_ART §2.1.
const ELEMENT_COLORS: Dictionary = {"physical": "#f2ebdd", "fire": "#ff6a2b", "ice": "#7fd8ff", "shock": "#f5e642",
	"poison": "#7cc242", "none": "#6bffb0", "heal": "#6bffb0", "light": "#f5f0e6", "dark": "#3e2e66"}
const ELEMENT_CORE_COLORS: Dictionary = {"fire": "#ffe08a", "ice": "#e6f8ff", "shock": "#9fe8ff"}
const STATUS_COLORS: Dictionary = {"sts_poison": "#7cc242", "sts_stun": "#f5d90a", "sts_slow": "#5b8def",
	"sts_haste": "#ff7a1a", "sts_guard": "#9aa7b8", "sts_taunt": "#e8455a"}
const RARITY_COLORS: Dictionary = {"common": "#bfc5cc", "rare": "#4aa8ff", "epic": "#b05cff"}
const BOX_COLORS: Dictionary = {"box_bronze": "#cd7f32", "box_silver": "#c0c8d2", "box_gold": "#ffc83d",
	"box_fan": "#ff5fa2"}

## Zone presets (03_ART §2.2/§2.3), hex. Matching a FloorDef/zone palette against these yields the art keys and the
## dressing style used by EnvKit (zone_style()).
const ZONE_PRESETS: Dictionary = {
	"platform": {"floor": "#3a3f4b", "wall": "#1f5f66", "accent": "#ff2e88", "light": "#ffd59e", "fog": "#1a1430",
		"ambient": "#2a2440", "shade": "#4a3e78", "rim": "#ffd9a8", "grout": "#1a1e24", "key": "#ffb866", "neon2": "#2bd66b"},
	"sewer": {"floor": "#24302c", "wall": "#3b4a3f", "accent": "#7cc242", "light": "#b8f0c8", "fog": "#12302a",
		"ambient": "#1e3530", "shade": "#2f4f5c", "rim": "#c8ffd0", "grout": "#18201c", "key": "#9fe0c0", "neon2": "#f5d90a"},
	"cellar": {"floor": "#3a2c24", "wall": "#5a4a3e", "accent": "#e23e9b", "light": "#ffd27a", "fog": "#2a1a12",
		"ambient": "#3a2a22", "shade": "#4a2e3e", "rim": "#ffe2b8", "grout": "#241a14", "key": "#ffc98a", "neon2": "#ff3b30"},
	"track9": {"floor": "#2a2530", "wall": "#2e2a38", "accent": "#ff3b30", "light": "#c9b8ff", "fog": "#1e1530",
		"ambient": "#261e38", "shade": "#3e2e66", "rim": "#c9b8ff", "grout": "#16121c", "key": "#c9b8ff", "neon2": "#2bd66b"},
	"safe": {"floor": "#4a3a40", "wall": "#6a5a60", "accent": "#ffc93c", "light": "#ffe2b8", "fog": "#2e242a",
		"ambient": "#5a4860", "shade": "#7a5e86", "rim": "#fff0d8", "grout": "#2e242a", "key": "#ffe2b8", "neon2": "#22d3ee"},
	"boss_office": {"floor": "#3c3a30", "wall": "#5a5e50", "accent": "#e8f0d8", "light": "#e8f0d8", "fog": "#20201a",
		"ambient": "#34322a", "shade": "#3a3a2a", "rim": "#f0ffe0", "grout": "#22201a", "key": "#e8f0d8", "neon2": "#ff3b30"},
	"throne": {"floor": "#1e1a24", "wall": "#241e30", "accent": "#9a6bff", "light": "#ffd27a", "fog": "#1a1230",
		"ambient": "#221a38", "shade": "#2a1f50", "rim": "#9a6bff", "grout": "#120e18", "key": "#9a6bff", "neon2": "#fff2c8"},
	"mall": {"floor": "#9a9080", "wall": "#2a3a44", "accent": "#ff4fa0", "light": "#fff0f5", "fog": "#2a1a2a",
		"ambient": "#3a2a3a", "shade": "#5a3a6a", "rim": "#ffe0f0", "grout": "#6e665a", "key": "#fff0f5", "neon2": "#4fe6ff"},
}
## Presets that can be matched per theme (first = theme default).
const THEME_STYLES: Dictionary = {
	"metro": ["platform", "sewer", "cellar", "track9", "safe", "boss_office", "throne"],
	"mall": ["mall", "safe"],
}
## Below this summed RGB distance (6 base keys) a palette counts as "that zone" and inherits the preset's art keys.
const MATCH_DISTANCE: float = 1.2


## "#rrggbb" / "rrggbb" / "#rgb" / "#rrggbbaa" → Color; anything else → fallback.
static func hex(s: String, fallback: Color = Color.MAGENTA) -> Color:
	var t: String = s.strip_edges()
	if t == "":
		return fallback
	if not t.begins_with("#"):
		t = "#" + t
	if not Color.html_is_valid(t):
		return fallback
	return Color.html(t)


## Keys floor, wall, accent, light, fog, ambient (+ art keys shade, rim, grout, key, neon2) → Color.
## Unknown theme → metro.
static func theme_palette(theme_id: String) -> Dictionary:
	var styles: Array = THEME_STYLES.get(theme_id, THEME_STYLES["metro"])
	return preset(str(styles[0]))


## Colors of a zone preset (ZONE_PRESETS key); unknown → platform.
static func preset(style: String) -> Dictionary:
	var src: Dictionary = ZONE_PRESETS.get(style, ZONE_PRESETS["platform"])
	var out: Dictionary = {}
	for k: String in src:
		out[k] = hex(str(src[k]))
	return out


## Hex dict (FloorDef.palette / zone palette) merged over theme defaults. Missing art keys come from the closest zone
## preset (03_ART §2.2) or are derived from the base colors when no preset is close.
static func resolve(palette: Dictionary, theme_id: String) -> Dictionary:
	var out: Dictionary = theme_palette(theme_id)
	var given: Dictionary = {}
	for k: Variant in palette:
		var key: String = str(k)
		var fb: Color = out.get(key, Color.MAGENTA)
		given[key] = _to_color(palette[k], fb)
	for key: String in PALETTE_KEYS:
		if given.has(key):
			out[key] = given[key]
	var best: Array = _nearest_style(out, theme_id)
	if float(best[1]) <= MATCH_DISTANCE:
		var p: Dictionary = preset(str(best[0]))
		for key: String in ART_KEYS:
			out[key] = p[key]
	else:
		var floor_c: Color = out["floor"]
		var wall_c: Color = out["wall"]
		var light_c: Color = out["light"]
		out["shade"] = wall_c.darkened(0.2).lerp(Color("#4a3e78"), 0.5)
		out["rim"] = light_c.lightened(0.15)
		out["grout"] = floor_c.darkened(0.55)
		out["key"] = light_c.lerp(Color("#ffb866"), 0.3)
	for key: String in given:
		if not PALETTE_KEYS.has(key):
			out[key] = given[key]
	return out


## Dressing style of a palette: the closest ZONE_PRESETS entry of the theme (&"platform", &"sewer", &"cellar",
## &"track9", &"safe", &"boss_office", &"throne", &"mall").
static func zone_style(palette: Dictionary, theme_id: String) -> StringName:
	var merged: Dictionary = theme_palette(theme_id)
	for k: Variant in palette:
		var key: String = str(k)
		if PALETTE_KEYS.has(key):
			merged[key] = _to_color(palette[k], merged[key])
	return StringName(str(_nearest_style(merged, theme_id)[0]))


static func element_color(element: String) -> Color:
	return hex(str(ELEMENT_COLORS.get(element, ELEMENT_COLORS["physical"])))


static func status_color(status_id: String) -> Color:
	return hex(str(STATUS_COLORS.get(status_id, "#f5f0e6")))


static func rarity_color(rarity: String) -> Color:
	return hex(str(RARITY_COLORS.get(rarity, RARITY_COLORS["common"])))


static func box_color(box_id: String) -> Color:
	return hex(str(BOX_COLORS.get(box_id, BOX_COLORS["box_bronze"])))


## Art extra: Label3D sign color at full brightness (max channel 1.0, hue kept). Label3D colors are clamped to 1.0 and
## then pass the AgX tonemapper (white ≈ 205 on screen), so in-world signs use the brightest version of their color.
static func sign_color(c: Color) -> Color:
	var m: float = maxf(c.r, maxf(c.g, c.b))
	if m <= 0.2:
		return c          # dark text (e.g. INK on a light board) stays as designed
	return Color(c.r / m, c.g / m, c.b / m, c.a)


## Multiplies RGB (03_ART notation "primary×0.8"), keeps alpha, clamps to 0..1.
static func mul(c: Color, f: float) -> Color:
	return Color(clampf(c.r * f, 0.0, 1.0), clampf(c.g * f, 0.0, 1.0), clampf(c.b * f, 0.0, 1.0), c.a)


static func _to_color(v: Variant, fallback: Color) -> Color:
	if typeof(v) == TYPE_COLOR:
		return v
	if typeof(v) == TYPE_STRING or typeof(v) == TYPE_STRING_NAME:
		return hex(str(v), fallback)
	return fallback


## [style name, distance]
static func _nearest_style(colors: Dictionary, theme_id: String) -> Array:
	var styles: Array = THEME_STYLES.get(theme_id, THEME_STYLES["metro"])
	var best_name: String = str(styles[0])
	var best_d: float = INF
	for s: Variant in styles:
		var p: Dictionary = ZONE_PRESETS[str(s)]
		var d: float = 0.0
		for key: String in PALETTE_KEYS:
			var a: Color = colors.get(key, Color.BLACK)
			var b: Color = hex(str(p[key]))
			var w: float = 1.5 if key == "accent" or key == "wall" or key == "floor" else 1.0
			d += (absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)) * w
		if d < best_d:
			best_d = d
			best_name = str(s)
	return [best_name, best_d]
