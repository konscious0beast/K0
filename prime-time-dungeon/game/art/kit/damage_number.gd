extends Label3D
## Pooled floating damage number (03_ART §7.1, 02_TECH §8.6). Private (no class_name), created by Vfx.damage_number.
## Pop 0.4 → 1.25 (0.08 s) → 1.0 (0.10 s), rises 0.8 m in 0.8 s (ease out), fades in the last 0.25 s.
## Captions ("SCHWACHSTELLE!", "RESISTENT") are separate pool entries (caption mode), so the pool never holds more than
## Vfx.DMG_POOL_SIZE Label3D (02_TECH §12.1).
##
## Screen twin: Label3D vertex colors are clamped to 1.0 and then go through the AgX tonemapper (+ fog), so #FFFFFF
## reads
## as ~205 grey and saturated style colors bleach (review M4). When a real renderer draws the parent's viewport, every
## number therefore renders as a 2D Label on a CanvasLayer (layer 4, below the HUD at 5; mouse ignored), projected from
## this node every frame: exact sRGB style colors, outline, world-size scaling and the crit tilt (a billboard drops the
## node rotation). The Label3D keeps all state (text, style colors, position, pop/rise/fade, pooling) and is hidden from
## cameras (layers = 0) while its twin is shown; headless / without a camera it renders itself.

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
const CAPTION_SIZE: int = 40
const CAPTION_OFFSET: float = 0.22
const STATUS_WORDS: Dictionary = {"gift": "sts_poison", "vergift": "sts_poison", "betäub": "sts_stun",
	"stun": "sts_stun",
	"langsam": "sts_slow", "slow": "sts_slow", "eile": "sts_haste", "hast": "sts_haste", "schutz": "sts_guard",
	"guard": "sts_guard", "spott": "sts_taunt", "taunt": "sts_taunt"}
## CanvasLayer of the screen twins (one per parent, below the HUD layer 5 of 02_TECH §9.4).
const SCREEN_LAYER: int = 4
const SCREEN_LAYER_NAME: String = "DamageNumberLayer"
const PIXEL_SIZE: float = 0.004

static var _font: FontVariation = null

var active: bool = false
## true for a caption entry (does not count for stacking).
var is_caption: bool = false
var _t: float = 0.0
var _origin: Vector3 = Vector3.ZERO
var _tilt: float = 0.0
var _color: Color = Color.WHITE
var _screen: Label = null


static func bold_font() -> FontVariation:
	if _font == null:
		_font = FontVariation.new()
		_font.base_font = ThemeDB.fallback_font
		_font.variation_embolden = 1.0
	return _font


## Caption text shown above a number of `style` ("" = none): resist "0"/"IMMUN" has no caption.
static func caption_for(p_text: String, style: StringName) -> String:
	var st: Dictionary = STYLES.get(style, STYLES[&"damage"])
	var caption: String = str(st.get("caption", ""))
	if style == &"resist" and (p_text == "" or p_text == "0" or p_text.to_upper() == "IMMUN"):
		return ""
	return caption


func _init() -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	fixed_size = false
	pixel_size = PIXEL_SIZE
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
	var col: Color = Palette.hex(str(st["color"]))
	if style == &"status":
		col = _status_color(shown)
	is_caption = false
	_start(shown, int(st["size"]), col, float(st.get("tilt", 0.0)), at)


## Caption entry (40 px) above a number at `at`: "SCHWACHSTELLE!" in the style color, "RESISTENT" in PAPER.
func show_caption(p_text: String, style: StringName, at: Vector3) -> void:
	var st: Dictionary = STYLES.get(style, STYLES[&"damage"])
	var col: Color = Palette.PAPER if style == &"resist" else Palette.hex(str(st["color"]))
	is_caption = true
	_start(p_text, CAPTION_SIZE, col, 0.0, at + Vector3(0, CAPTION_OFFSET, 0))


func _start(shown: String, size: int, col: Color, tilt: float, at: Vector3) -> void:
	text = shown
	font_size = size
	outline_size = 10 if size <= CAPTION_SIZE else 12
	_color = col
	modulate = col
	outline_modulate = Palette.INK
	_tilt = tilt
	rotation = Vector3(0, 0, deg_to_rad(_tilt))
	_origin = at
	position = at
	_t = 0.0
	scale = Vector3.ONE * 0.4
	active = true
	visible = true
	set_process(true)
	_update_screen()


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
	if _t >= LIFE:
		active = false
		visible = false
		set_process(false)
	_update_screen()


func _exit_tree() -> void:
	if _screen != null and is_instance_valid(_screen):
		_screen.queue_free()
	_screen = null
	layers = 1


# --- screen twin
# -------------------------------------------------------------------------------------------------------

## Whether the parent's viewport is drawn by a real renderer with a 3D camera (else the Label3D renders itself).
func _screen_camera() -> Camera3D:
	if not is_inside_tree() or DisplayServer.get_name() == "headless":
		return null
	var vp: Viewport = get_viewport()
	return vp.get_camera_3d() if vp != null else null


func _ensure_screen() -> Label:
	if _screen != null and is_instance_valid(_screen):
		return _screen
	var host: Node = get_parent()
	if host == null:
		return null
	var layer: CanvasLayer = host.get_node_or_null(SCREEN_LAYER_NAME) as CanvasLayer
	if layer == null:
		layer = CanvasLayer.new()
		layer.name = SCREEN_LAYER_NAME
		layer.layer = SCREEN_LAYER
		host.add_child(layer)
	_screen = Label.new()
	_screen.name = "Screen_" + String(name)
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_screen.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_screen.add_theme_font_override(&"font", bold_font())
	layer.add_child(_screen)
	return _screen


func _update_screen() -> void:
	var cam: Camera3D = _screen_camera()
	if cam == null:
		layers = 1
		if _screen != null and is_instance_valid(_screen):
			_screen.visible = false
		return
	var lbl: Label = _ensure_screen()
	if lbl == null:
		layers = 1
		return
	layers = 0
	var gp: Vector3 = global_position
	if not visible or cam.is_position_behind(gp):
		lbl.visible = false
		return
	lbl.visible = true
	# world size: font_size px × PIXEL_SIZE m at the node, projected (keeps the Label3D look incl. the pop scale);
	# rasterized near the final pixel size (4 px steps, crisp text) and scaled by the remainder
	var center: Vector2 = cam.unproject_position(gp)
	var up: Vector3 = cam.global_transform.basis.y.normalized()
	var px_per_m: float = (cam.unproject_position(gp + up) - center).length()
	var eff: float = float(font_size) * PIXEL_SIZE * px_per_m * scale.y
	var fs: int = clampi(roundi(eff / 4.0) * 4, 8, 256)
	var k: float = eff / float(fs)
	lbl.text = text
	lbl.add_theme_font_size_override(&"font_size", fs)
	lbl.add_theme_constant_override(&"outline_size", maxi(roundi(float(outline_size) * float(fs) / float(font_size)), 2))
	var a: float = modulate.a
	lbl.add_theme_color_override(&"font_color", Color(_color.r, _color.g, _color.b, a))
	lbl.add_theme_color_override(&"font_outline_color", Color(Palette.INK.r, Palette.INK.g, Palette.INK.b, a))
	lbl.reset_size()
	lbl.pivot_offset = lbl.size * 0.5
	lbl.scale = Vector2(k, k)
	lbl.rotation = -deg_to_rad(_tilt)
	lbl.position = center - lbl.size * 0.5
