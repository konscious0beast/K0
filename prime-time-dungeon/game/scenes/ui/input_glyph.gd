extends HBoxContainer
## Key / button symbol for an input action in the current input scheme (02_TECH §1.6, §10). Keyboard: key cap
## ("F", "Esc"); gamepad: round face button (A/B/X/Y in Xbox colors) or shoulder/menu pill; touch: hidden (touch has
## its own buttons) unless `show_on_touch`. Optional trailing caption ("Öffnen"). Updates on input_scheme_changed.
## Private M6 helper (§0.3/§13.2: no class_name): `const InputGlyph := preload("res://scenes/ui/input_glyph.gd")`.
## Font sizes below 15 px are raised to 15 (03_ART §9.3 minimum).

const MIN_FONT: int = 15

const PAD_FACE: Dictionary = {0: ["A", Color("#3fbf5f")], 1: ["B", Color("#e04848")], 2: ["X", Color("#3f7fe0")],
	3: ["Y", Color("#e0b83f")]}
const PAD_NAMES: Dictionary = {4: "Back", 5: "Guide", 6: "Start", 7: "L3", 8: "R3", 9: "LB", 10: "RB", 11: "Hoch",
	12: "Runter", 13: "Links", 14: "Rechts"}
const KEY_NAMES: Dictionary = {"Escape": "Esc", "Space": "Leertaste", "Enter": "Enter", "Kp Enter": "Enter",
	"PageUp": "Bild auf", "PageDown": "Bild ab", "Shift": "Shift", "Tab": "Tab", "Up": "Hoch", "Down": "Runter",
	"Left": "Links", "Right": "Rechts"}

@export var action: StringName = &"ui_accept":
	set(v):
		action = v
		_refresh()
@export var caption: String = "":
	set(v):
		caption = v
		_refresh()
@export var show_on_touch: bool = false:
	set(v):
		show_on_touch = v
		_refresh()
@export var font_size: int = 16

var _cap: PanelContainer
var _cap_label: Label
var _caption_label: Label


static func make(p_action: StringName, p_caption: String = "", p_font_size: int = 16) -> HBoxContainer:
	var g: HBoxContainer = (load("res://scenes/ui/input_glyph.gd") as GDScript).new() as HBoxContainer
	g.set("font_size", maxi(p_font_size, MIN_FONT))
	g.set("action", p_action)
	g.set("caption", p_caption)
	return g


## Text of the binding for `p_action` in `scheme` (Game.InputScheme), e.g. "F" / "A" / "Esc". "" if unbound.
static func binding_text(p_action: StringName, scheme: int) -> String:
	if not InputMap.has_action(p_action):
		return ""
	var events: Array[InputEvent] = InputMap.action_get_events(p_action)
	if scheme == Game.InputScheme.GAMEPAD:
		for e: InputEvent in events:
			if e is InputEventJoypadButton:
				var idx: int = (e as InputEventJoypadButton).button_index
				if PAD_FACE.has(idx):
					return str((PAD_FACE[idx] as Array)[0])
				return str(PAD_NAMES.get(idx, "Btn %d" % idx))
		for e: InputEvent in events:
			if e is InputEventJoypadMotion:
				var jm: InputEventJoypadMotion = e
				if jm.axis == JOY_AXIS_TRIGGER_LEFT:
					return "LT"
				if jm.axis == JOY_AXIS_TRIGGER_RIGHT:
					return "RT"
				return "L-Stick" if jm.axis <= 1 else "R-Stick"
		return ""
	for e: InputEvent in events:
		if e is InputEventKey:
			var k: InputEventKey = e
			var code: Key = k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
			var key_name: String = OS.get_keycode_string(code)
			return str(KEY_NAMES.get(key_name, key_name))
	return ""


static func pad_color(p_action: StringName) -> Color:
	if not InputMap.has_action(p_action):
		return Color("#5a5266")
	for e: InputEvent in InputMap.action_get_events(p_action):
		if e is InputEventJoypadButton and PAD_FACE.has((e as InputEventJoypadButton).button_index):
			return (PAD_FACE[(e as InputEventJoypadButton).button_index] as Array)[1]
	return Color("#5a5266")


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 6)
	alignment = BoxContainer.ALIGNMENT_CENTER
	_cap = PanelContainer.new()
	_cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(_cap)
	_cap_label = Label.new()
	_cap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cap_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cap_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cap.add_child(_cap_label)
	_caption_label = Label.new()
	_caption_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(_caption_label)


func _ready() -> void:
	Events.input_scheme_changed.connect(func(_s: int) -> void: _refresh())
	_refresh()


func current_scheme() -> int:
	return Game.input_scheme


func _refresh() -> void:
	if _cap == null:
		return
	var scheme: int = current_scheme()
	var txt: String = binding_text(action, scheme)
	var touch: bool = scheme == Game.InputScheme.TOUCH
	visible = txt != "" and (not touch or show_on_touch)
	_cap_label.text = txt
	_cap_label.add_theme_font_size_override("font_size", font_size)
	_caption_label.text = caption
	_caption_label.visible = caption != ""
	_caption_label.add_theme_font_size_override("font_size", font_size)
	_caption_label.add_theme_color_override("font_color", UiTheme.C_TEXT)
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.content_margin_left = 7
	sb.content_margin_right = 7
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	if scheme == Game.InputScheme.GAMEPAD:
		var face: bool = txt.length() == 1
		sb.bg_color = pad_color(action) if face else Color("#3a3248")
		sb.set_corner_radius_all(64 if face else 10)
		sb.border_color = Color(1, 1, 1, 0.35)
		sb.set_border_width_all(1)
		_cap_label.add_theme_color_override("font_color", Color.WHITE)
	else:
		sb.bg_color = Color("#f5f0e6")
		sb.set_corner_radius_all(4)
		sb.border_color = Color("#8a7fa6")
		sb.border_width_bottom = 3
		_cap_label.add_theme_color_override("font_color", Color("#140d1c"))
	_cap_label.add_theme_constant_override("outline_size", 0)
	var min_w: float = float(font_size) + 10.0
	_cap.custom_minimum_size = Vector2(min_w, float(font_size) + 8.0)
	_cap.add_theme_stylebox_override("panel", sb)
