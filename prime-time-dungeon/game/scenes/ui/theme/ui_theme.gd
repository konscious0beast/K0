class_name UiTheme extends RefCounted
## Base theme for all UI (02_TECH §3.9, 03_ART §9). Built once in code and cached; Router assigns it to
## get_tree().root.theme. Colors are copies of the Palette values (no M0 → M4 dependency).

const FONT_SIZE: int = 22
const FONT_SIZE_SMALL: int = 16
const FONT_SIZE_HEADER: int = 30
const FONT_SIZE_TITLE: int = 56
const MIN_TOUCH: int = 64                     # minimum VISIBLE size of touch controls (reference 1280×720)
const TOUCH_HIT: int = 88                     # minimum HIT area (invisible margin around smaller controls, ART A9)
const C_BG: Color = Color("#140d1c")
const C_PANEL: Color = Color(0.12, 0.08, 0.19, 0.9)
const C_TEXT: Color = Color("#f5f0ff")
const C_TEXT_DIM: Color = Color("#b3a7c9")
const C_ACCENT: Color = Color("#ff2e88")     # NOVA magenta
const C_ACCENT_2: Color = Color("#22d3ee")   # NOVA cyan (focus)
const C_GOLD: Color = Color("#ffc93c")
const C_DANGER: Color = Color("#ff4d4d")
const C_OK: Color = Color("#4ade80")
const C_MANA: Color = Color("#60a5fa")
const C_DISABLED: Color = Color("#5a5266")

## Monospace fallback list (03_ART §9.3).
const MONO_FONT_NAMES: PackedStringArray = ["Consolas", "Roboto Mono", "DejaVu Sans Mono", "monospace"]
const FONT_SIZE_BUTTON_BIG: int = 26
const FONT_SIZE_TIMER: int = 34
const BUTTON_BIG_MIN_HEIGHT: int = 72
const VARIATIONS: PackedStringArray = ["ButtonBig", "ButtonFlat", "PanelShow", "PanelDialog", "PanelMenu", "LabelTitle",
	"LabelHeader", "LabelSmall", "LabelTimer", "LabelLive", "BarHp", "BarMp", "BarHype"]

static var _theme: Theme = null
static var _mono: Font = null
static var _bold: FontVariation = null


## Built once in code, cached.
static func get_theme() -> Theme:
	if _theme == null:
		_theme = _build()
	return _theme


## SystemFont (monospace fallback list, ART §9.3) for counters/timer digits; falls back to the default font.
static func font_mono() -> Font:
	if _mono == null:
		var f: SystemFont = SystemFont.new()
		f.font_names = MONO_FONT_NAMES
		var fallbacks: Array[Font] = [ThemeDB.fallback_font]
		f.fallbacks = fallbacks
		_mono = f
	return _mono


## Default font with variation_embolden 0.5 (headers, title, ButtonBig).
static func font_bold() -> Font:
	if _bold == null:
		var v: FontVariation = FontVariation.new()
		v.base_font = ThemeDB.fallback_font
		v.variation_embolden = 0.5
		_bold = v
	return _bold


## custom_minimum_size >= TOUCH_HIT; the visible part is a centered child (>= MIN_TOUCH), the button's own styleboxes
## are empty. Focus is shown by a centered focus frame child. Idempotent.
static func ensure_hit_area(button: BaseButton) -> void:
	if button == null or button.has_node("HitVisual"):
		return
	var base: Vector2 = button.get_combined_minimum_size()
	var visible_size: Vector2 = Vector2(maxf(base.x, MIN_TOUCH), maxf(base.y, MIN_TOUCH))
	var th: Theme = get_theme()
	var type_name: StringName = button.theme_type_variation if button.theme_type_variation != &"" else &"Button"
	var normal: StyleBox = th.get_stylebox("normal", type_name) if th.has_stylebox("normal", type_name) \
		else th.get_stylebox("normal", "Button")
	var focus: StyleBox = th.get_stylebox("focus", "Button")
	var visual: Panel = _centered_panel("HitVisual", visible_size, normal.duplicate() as StyleBox)
	visual.show_behind_parent = true
	button.add_child(visual)
	var focus_frame: Panel = _centered_panel("HitFocus", visible_size, focus.duplicate() as StyleBox)
	focus_frame.visible = button.has_focus()
	button.add_child(focus_frame)
	button.focus_entered.connect(func() -> void: focus_frame.visible = true)
	button.focus_exited.connect(func() -> void: focus_frame.visible = false)
	for state: String in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed", "normal_mirrored",
			"hover_mirrored", "pressed_mirrored", "disabled_mirrored", "hover_pressed_mirrored"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.custom_minimum_size = Vector2(maxf(visible_size.x, TOUCH_HIT), maxf(visible_size.y, TOUCH_HIT))


static func _centered_panel(node_name: String, size: Vector2, box: StyleBox) -> Panel:
	var p: Panel = Panel.new()
	p.name = node_name
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.focus_mode = Control.FOCUS_NONE
	p.add_theme_stylebox_override("panel", box)
	p.anchor_left = 0.5
	p.anchor_right = 0.5
	p.anchor_top = 0.5
	p.anchor_bottom = 0.5
	p.offset_left = -size.x * 0.5
	p.offset_right = size.x * 0.5
	p.offset_top = -size.y * 0.5
	p.offset_bottom = size.y * 0.5
	return p


# --- theme construction
# ------------------------------------------------------------------------------------------------

static func _box(bg: Color, border: Color = Color(0, 0, 0, 0), border_width: int = 0, margin_h: float = 12.0,
		margin_v: float = 8.0) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(0)
	sb.content_margin_left = margin_h
	sb.content_margin_right = margin_h
	sb.content_margin_top = margin_v
	sb.content_margin_bottom = margin_v
	return sb


static func _focus_box() -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = C_ACCENT_2
	sb.set_border_width_all(3)
	sb.set_expand_margin_all(2.0)
	return sb


static func _build() -> Theme:
	var t: Theme = Theme.new()
	t.default_font_size = FONT_SIZE
	var bold: Font = font_bold()

	# Label
	t.set_color("font_color", "Label", C_TEXT)
	t.set_color("font_outline_color", "Label", C_BG)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0))
	t.set_constant("outline_size", "Label", 2)
	t.set_font_size("font_size", "Label", FONT_SIZE)
	t.set_color("default_color", "RichTextLabel", C_TEXT)
	t.set_color("font_outline_color", "RichTextLabel", C_BG)
	t.set_constant("outline_size", "RichTextLabel", 2)

	# Button (base)
	var accent_frame: Color = Color(C_ACCENT_2, 0.6)
	t.set_stylebox("normal", "Button", _box(C_PANEL, accent_frame, 2, 16.0, 10.0))
	t.set_stylebox("hover", "Button", _box(Color(0.2, 0.12, 0.3, 0.95), C_ACCENT, 2, 16.0, 10.0))
	t.set_stylebox("pressed", "Button", _box(Color(C_ACCENT, 0.55), C_ACCENT, 2, 16.0, 10.0))
	t.set_stylebox("hover_pressed", "Button", _box(Color(C_ACCENT, 0.65), C_ACCENT, 2, 16.0, 10.0))
	t.set_stylebox("disabled", "Button", _box(Color(C_DISABLED, 0.35), Color(C_DISABLED, 0.6), 2, 16.0, 10.0))
	t.set_stylebox("focus", "Button", _focus_box())
	for c: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color",
		"font_focus_color"]:
		t.set_color(c, "Button", C_TEXT)
	t.set_color("font_disabled_color", "Button", C_TEXT_DIM)
	t.set_color("font_outline_color", "Button", C_BG)
	t.set_constant("outline_size", "Button", 2)
	t.set_font_size("font_size", "Button", FONT_SIZE)

	# ButtonBig: min 72 px high, 26 px bold (main menu, battle commands)
	t.set_type_variation("ButtonBig", "Button")
	t.set_font("font", "ButtonBig", bold)
	t.set_font_size("font_size", "ButtonBig", FONT_SIZE_BUTTON_BIG)
	var big_v: float = 20.0
	t.set_stylebox("normal", "ButtonBig", _box(C_PANEL, accent_frame, 2, 24.0, big_v))
	t.set_stylebox("hover", "ButtonBig", _box(Color(0.2, 0.12, 0.3, 0.95), C_ACCENT, 2, 24.0, big_v))
	t.set_stylebox("pressed", "ButtonBig", _box(Color(C_ACCENT, 0.55), C_ACCENT, 2, 24.0, big_v))
	t.set_stylebox("hover_pressed", "ButtonBig", _box(Color(C_ACCENT, 0.65), C_ACCENT, 2, 24.0, big_v))
	t.set_stylebox("disabled", "ButtonBig", _box(Color(C_DISABLED, 0.35), Color(C_DISABLED, 0.6), 2, 24.0, big_v))

	# ButtonFlat: transparent, hover/focus bar (list entries)
	t.set_type_variation("ButtonFlat", "Button")
	var flat: StyleBoxFlat = _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 16.0, 6.0)
	var flat_bar: StyleBoxFlat = _box(Color(C_ACCENT, 0.15), C_ACCENT, 0, 16.0, 6.0)
	flat_bar.border_width_left = 4
	t.set_stylebox("normal", "ButtonFlat", flat)
	t.set_stylebox("hover", "ButtonFlat", flat_bar)
	t.set_stylebox("pressed", "ButtonFlat", flat_bar)
	t.set_stylebox("hover_pressed", "ButtonFlat", flat_bar)
	t.set_stylebox("disabled", "ButtonFlat", flat)
	var flat_focus: StyleBoxFlat = _focus_box()
	flat_focus.draw_center = true
	flat_focus.bg_color = Color(C_ACCENT, 0.15)
	t.set_stylebox("focus", "ButtonFlat", flat_focus)

	# Panels
	var panel: StyleBoxFlat = _box(C_PANEL, accent_frame, 2, 12.0, 8.0)
	panel.shadow_color = Color(0, 0, 0, 0.5)
	panel.shadow_size = 4
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)
	t.set_type_variation("PanelShow", "PanelContainer")
	var show_box: StyleBoxFlat = _box(Color(C_PANEL, 0.75), C_ACCENT, 2, 14.0, 6.0)
	show_box.skew = Vector2(0.21, 0.0)
	t.set_stylebox("panel", "PanelShow", show_box)
	t.set_type_variation("PanelDialog", "PanelContainer")
	t.set_stylebox("panel", "PanelDialog", _box(C_PANEL, C_ACCENT_2, 3, 16.0, 12.0))
	t.set_type_variation("PanelMenu", "PanelContainer")
	# modal menus cover the HUD / show overlay: opaque, so no HUD text ghosts through the page (visual pass)
	t.set_stylebox("panel", "PanelMenu", _box(Color(C_PANEL, 1.0), accent_frame, 2, 12.0, 12.0))

	# Label variations
	t.set_type_variation("LabelTitle", "Label")
	t.set_font("font", "LabelTitle", bold)
	t.set_font_size("font_size", "LabelTitle", FONT_SIZE_TITLE)
	t.set_constant("outline_size", "LabelTitle", 4)
	t.set_type_variation("LabelHeader", "Label")
	t.set_font("font", "LabelHeader", bold)
	t.set_font_size("font_size", "LabelHeader", FONT_SIZE_HEADER)
	t.set_type_variation("LabelSmall", "Label")
	t.set_font_size("font_size", "LabelSmall", FONT_SIZE_SMALL)
	t.set_color("font_color", "LabelSmall", C_TEXT_DIM)
	t.set_type_variation("LabelTimer", "Label")
	t.set_font("font", "LabelTimer", font_mono())
	t.set_font_size("font_size", "LabelTimer", FONT_SIZE_TIMER)
	t.set_constant("outline_size", "LabelTimer", 4)
	t.set_type_variation("LabelLive", "Label")
	t.set_stylebox("normal", "LabelLive", _box(C_DANGER, Color(0, 0, 0, 0), 0, 10.0, 2.0))
	t.set_color("font_color", "LabelLive", Color.WHITE)
	t.set_font("font", "LabelLive", bold)
	t.set_font_size("font_size", "LabelLive", 20)
	t.set_constant("outline_size", "LabelLive", 0)

	# Progress bars (no percentage text: transparent font)
	var bar_bg: StyleBoxFlat = _box(Color(C_BG, 0.85), Color(C_TEXT_DIM, 0.4), 1, 0.0, 0.0)
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", _box(C_ACCENT_2, Color(0, 0, 0, 0), 0, 0.0, 0.0))
	t.set_color("font_color", "ProgressBar", C_TEXT)
	for pair: Array in [["BarHp", C_OK], ["BarMp", C_MANA], ["BarHype", C_GOLD]]:
		var bar_name: String = pair[0]
		t.set_type_variation(bar_name, "ProgressBar")
		t.set_stylebox("fill", bar_name, _box(pair[1] as Color, Color(0, 0, 0, 0), 0, 0.0, 0.0))
		t.set_color("font_color", bar_name, Color(0, 0, 0, 0))
		t.set_color("font_outline_color", bar_name, Color(0, 0, 0, 0))

	# LineEdit (name entry)
	t.set_stylebox("normal", "LineEdit", _box(Color(C_BG, 0.9), accent_frame, 2, 12.0, 8.0))
	t.set_stylebox("focus", "LineEdit", _focus_box())
	t.set_stylebox("read_only", "LineEdit", _box(Color(C_BG, 0.6), Color(C_DISABLED, 0.6), 2, 12.0, 8.0))
	t.set_color("font_color", "LineEdit", C_TEXT)
	t.set_color("caret_color", "LineEdit", C_ACCENT_2)
	t.set_color("selection_color", "LineEdit", Color(C_ACCENT, 0.4))
	t.set_color("font_placeholder_color", "LineEdit", C_TEXT_DIM)

	# Misc focusable controls share the focus frame.
	for type_name: String in ["CheckBox", "CheckButton", "OptionButton", "HSlider", "VSlider", "ItemList", "SpinBox"]:
		t.set_stylebox("focus", type_name, _focus_box())
	t.set_color("font_color", "CheckBox", C_TEXT)
	t.set_color("font_color", "CheckButton", C_TEXT)
	t.set_stylebox("panel", "TooltipPanel", _box(C_PANEL, accent_frame, 1, 8.0, 4.0))
	t.set_color("font_color", "TooltipLabel", C_TEXT)
	return t
