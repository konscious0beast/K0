extends Control
## Partner tactic panel (07 §5.2, §7.1–§7.3): opened from the Taktik-Chip (click / tap / the partner_tactic hint card,
## 07 §2.13 E29). Three tactics (Angriff · Unterstützen · Vorsichtig) and the three switches (Unterbrechen ·
## Show-Einlagen · Tränke) of the AI partner; every change goes to the sim as ONE partner_preset command with the full
## preset + switches (07 §10.1). 64 px visible / 88 px hit per button. The combat keeps running. Private R3 script.

signal preset_changed(preset: String, tog: Dictionary)
signal closed()

const CombatStyle := preload("res://scenes/combat/ui/combat_style.gd")

const PRESET_NAMES: Dictionary = {"attack": "Angriff", "support": "Unterstützen", "careful": "Vorsichtig"}
const PRESET_HINTS: Dictionary = {"attack": "drauf und dran", "support": "heilt, hilft, hält Abstand",
	"careful": "weicht früh aus, nutzt Tränke"}
const TOGGLE_NAMES: Dictionary = {"interrupt": "Unterbrechen", "show": "Show-Einlagen", "potions": "Tränke"}
const BTN: Vector2 = Vector2(150, 64)
const HIT_H: float = 88.0

var preset: String = "support"
var tog: Dictionary = {}
var partner_name: String = ""

var _panel: PanelContainer
var _title: Label
var _buttons: Dictionary = {}               # "preset:attack" / "tog:interrupt" → Button


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb: StyleBoxFlat = CombatStyle.panel_box(CombatStyle.C_PANEL_SOLID, CombatStyle.C_CYAN, 2)
	sb.set_content_margin_all(12.0)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	_panel.add_child(col)
	_title = CombatStyle.label("TAKTIK", 16, CombatStyle.C_CYAN, true)
	col.add_child(_title)
	var row1: HBoxContainer = HBoxContainer.new()
	row1.add_theme_constant_override("separation", 8)
	col.add_child(row1)
	for p: String in RtVocab.RT_PRESETS:
		row1.add_child(_make("preset:" + p, str(PRESET_NAMES[p])))
	var row2: HBoxContainer = HBoxContainer.new()
	row2.add_theme_constant_override("separation", 8)
	col.add_child(row2)
	for k: String in RtVocab.RT_TOGGLES:
		row2.add_child(_make("tog:" + k, str(TOGGLE_NAMES[k])))


func _make(key: String, text: String) -> Button:
	var b: Button = Button.new()
	b.name = key.replace(":", "_")
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(BTN.x, HIT_H)        # 88 px hit, 64 px drawn (inset styleboxes)
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_constant_override("outline_size", 0)
	b.pressed.connect(_on_pressed.bind(key))
	_buttons[key] = b
	return b


func open(p_preset: String, p_tog: Dictionary, p_partner_name: String, at: Vector2) -> void:
	preset = p_preset
	tog = p_tog.duplicate()
	partner_name = p_partner_name
	_title.text = UiUtilRef.glyph_safe("TAKTIK · %s" % partner_name if partner_name != "" else "TAKTIK")
	_refresh()
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.reset_size()
	var sz: Vector2 = _panel.get_combined_minimum_size()
	var vp: Vector2 = get_viewport_rect().size if is_inside_tree() else Vector2(1280, 720)
	_panel.position = Vector2(clampf(at.x, 8.0, vp.x - sz.x - 8.0), clampf(at.y, 8.0, vp.y - sz.y - 8.0))
	_panel.size = sz


func is_open() -> bool:
	return visible


func close() -> void:
	if not visible:
		return
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	closed.emit()


## The next tactic (G / Steuerkreuz rechts): Angriff → Unterstützen → Vorsichtig → Angriff.
static func next_preset(p: String) -> String:
	var i: int = RtVocab.RT_PRESETS.find(p)
	return RtVocab.RT_PRESETS[(i + 1) % RtVocab.RT_PRESETS.size()]


func button(key: String) -> Button:
	return _buttons.get(key, null) as Button


func _on_pressed(key: String) -> void:
	var parts: PackedStringArray = key.split(":")
	if parts[0] == "preset":
		preset = parts[1]
	else:
		tog[parts[1]] = not bool(tog.get(parts[1], false))
	_refresh()
	preset_changed.emit(preset, tog.duplicate())


func _refresh() -> void:
	for key: String in _buttons.keys():
		var b: Button = _buttons[key]
		var parts: PackedStringArray = key.split(":")
		var on: bool = preset == parts[1] if parts[0] == "preset" else bool(tog.get(parts[1], false))
		var sb: StyleBoxFlat = CombatStyle.panel_box(Color("#2a1f3d") if on else CombatStyle.C_SLOT,
			CombatStyle.C_GOLD if on else Color(CombatStyle.C_PAPER, 0.35), 3 if on else 1)
		sb.expand_margin_top = -12.0                       # drawn 64 px of the 88 px hit area
		sb.expand_margin_bottom = -12.0
		for st: String in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			b.add_theme_stylebox_override(st, sb)
		b.add_theme_color_override("font_color", CombatStyle.C_GOLD if on else CombatStyle.C_TEXT)
		b.add_theme_color_override("font_hover_color", CombatStyle.C_GOLD if on else CombatStyle.C_PAPER)
		b.add_theme_color_override("font_pressed_color", CombatStyle.C_GOLD)
		if parts[0] == "tog":
			b.text = "%s: %s" % [str(TOGGLE_NAMES[parts[1]]), "an" if on else "aus"]


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		close()
		accept_event()


const UiUtilRef := preload("res://scenes/ui/ui_util.gd")
