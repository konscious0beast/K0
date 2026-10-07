extends Label3D
## Pooled floating damage number (03_ART §7.1, 02_TECH §8.6). Private (no class_name), created by Vfx.damage_number.
## Pop 0.4 → 1.25 (0.08 s) → 1.0 (0.10 s), rises 0.8 m in 0.8 s (ease out), fades in the last 0.25 s.

const LIFE: float = 0.8
const STYLES: Dictionary = {
	&"damage": {"color": "#ffffff", "size": 64},
	&"weak": {"color": "#ffe14d", "size": 72, "caption": "SCHWACHSTELLE!"},
	&"crit": {"color": "#ff9a2e", "size": 88, "tilt": 8.0},
	&"heal": {"color": "#6bff8a", "size": 64, "prefix": "+"},
	&"mp": {"color": "#60a5fa", "size": 56, "prefix": "+", "suffix": " MP"},
	&"resist": {"color": "#9aa0a6", "size": 56, "caption": "RESISTENT"},
	&"miss": {"color": "#9c93ad", "size": 48},
	&"status": {"color": "#c9b8ff", "size": 48},
}
const STATUS_WORDS: Dictionary = {"gift": "sts_poison", "vergift": "sts_poison", "betäub": "sts_stun", "stun": "sts_stun",
	"langsam": "sts_slow", "slow": "sts_slow", "eile": "sts_haste", "hast": "sts_haste", "schutz": "sts_guard",
	"guard": "sts_guard", "spott": "sts_taunt", "taunt": "sts_taunt"}

static var _font: FontVariation = null

var active: bool = false
var _t: float = 0.0
var _origin: Vector3 = Vector3.ZERO
var _caption: Label3D = null
var _tilt: float = 0.0


static func bold_font() -> FontVariation:
	if _font == null:
		_font = FontVariation.new()
		_font.base_font = ThemeDB.fallback_font
		_font.variation_embolden = 1.0
	return _font


func _init() -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	fixed_size = false
	pixel_size = 0.004
	outline_size = 12
	outline_modulate = Palette.INK
	render_priority = 10
	outline_render_priority = 9
	font = bold_font()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false
	set_process(false)


## Shows `p_text` in `style` at local position `at` (parent space).
func show_number(p_text: String, style: StringName, at: Vector3) -> void:
	var st: Dictionary = STYLES.get(style, STYLES[&"damage"])
	var shown: String = p_text
	var caption: String = str(st.get("caption", ""))
	match style:
		&"heal", &"mp":
			if not shown.begins_with("+"):
				shown = str(st.get("prefix", "")) + shown
			shown += str(st.get("suffix", ""))
		&"miss":
			if shown == "" or shown == "0":
				shown = "DANEBEN"
		&"resist":
			if shown == "" or shown == "0" or shown.to_upper() == "IMMUN":
				shown = "IMMUN"
				caption = ""
	var col: Color = Palette.hex(str(st["color"]))
	if style == &"status":
		col = _status_color(shown)
	text = shown
	font_size = int(st["size"])
	modulate = col
	_tilt = float(st.get("tilt", 0.0))
	rotation = Vector3(0, 0, deg_to_rad(_tilt))
	if caption != "":
		if _caption == null:
			_caption = Label3D.new()
			_caption.name = "Caption"
			_caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			_caption.no_depth_test = true
			_caption.pixel_size = 0.004
			_caption.outline_size = 10
			_caption.outline_modulate = Palette.INK
			_caption.render_priority = 10
			_caption.outline_render_priority = 9
			_caption.font = bold_font()
			_caption.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(_caption)
		_caption.text = caption
		_caption.font_size = 40
		_caption.modulate = Palette.PAPER if style == &"resist" else col
		_caption.position = Vector3(0, 0.22, 0)
		_caption.visible = true
	elif _caption != null:
		_caption.visible = false
	_origin = at
	position = at
	_t = 0.0
	scale = Vector3.ONE * 0.4
	active = true
	visible = true
	set_process(true)


## Holds the current frame (galleries / screenshots).
func freeze() -> void:
	active = false
	set_process(false)


func _status_color(word: String) -> Color:
	var w: String = word.to_lower()
	for key: String in STATUS_WORDS:
		if w.contains(key):
			return Palette.status_color(str(STATUS_WORDS[key]))
	return Palette.hex(str(STYLES[&"status"]["color"]))


func _process(delta: float) -> void:
	if not active:
		return
	_t += delta
	var u: float = clampf(_t / LIFE, 0.0, 1.0)
	var s: float = 1.0
	if _t < 0.08:
		s = lerpf(0.4, 1.25, _t / 0.08)
	elif _t < 0.18:
		s = lerpf(1.25, 1.0, (_t - 0.08) / 0.10)
	scale = Vector3.ONE * s
	position = _origin + Vector3(0, 0.8 * (1.0 - pow(1.0 - u, 3.0)), 0)
	var a: float = 1.0 - smoothstep(LIFE - 0.25, LIFE, _t)
	modulate.a = a
	outline_modulate.a = a
	if _caption != null:
		_caption.modulate.a = a
		_caption.outline_modulate.a = a
	if _t >= LIFE:
		active = false
		visible = false
		set_process(false)
