extends Control
## Banners of the battle HUD (02_TECH §5.7 table): the skill / action name strip (top center, below the hype meter,
## skewed show panel) and big centered announcements ("KAMPF!", "COMBO!", "STUNT GEGLÜCKT!", "PATZER!", "OVERKILL!",
## phase changes, boss names, "SIEG!") with a scale pop. Private M5 helper (no class_name).

const HudStyle := preload("res://scenes/battle/ui/hud_style.gd")

var _skill: PanelContainer = null
var _skill_label: Label = null
var _skill_side: ColorRect = null
var _skill_tw: Tween = null
var _big: VBoxContainer = null
var _big_label: Label = null
var _big_sub: Label = null
var _big_tw: Tween = null
var _box: StyleBoxFlat = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_skill = PanelContainer.new()
	_skill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box = HudStyle.show_box(Color(0.0784, 0.051, 0.1098, 0.9), Color("#ff2e88"), 2, 0.21, Vector4(28, 6, 28, 6))
	_skill.add_theme_stylebox_override("panel", _box)
	_skill.set_anchors_preset(Control.PRESET_CENTER_TOP)
	add_child(_skill)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skill.add_child(row)
	_skill_side = ColorRect.new()
	_skill_side.custom_minimum_size = Vector2(6, 22)
	_skill_side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_skill_side)
	_skill_label = HudStyle.label("", 24, HudStyle.C_PAPER, true, 3)
	row.add_child(_skill_label)
	_skill.visible = false
	_big = VBoxContainer.new()
	_big.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_big.alignment = BoxContainer.ALIGNMENT_CENTER
	_big.set_anchors_preset(Control.PRESET_CENTER)
	add_child(_big)
	_big_label = HudStyle.label("", 64, Color("#ffc93c"), true, 10)
	_big_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_big.add_child(_big_label)
	_big_sub = HudStyle.label("", 24, HudStyle.C_PAPER, true, 5)
	_big_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_big.add_child(_big_sub)
	_big.visible = false


func skill_text() -> String:
	return _skill_label.text if _skill.visible else ""


func big_text() -> String:
	return _big_label.text if _big.visible else ""


## Skill / action strip; party actions edge cyan, enemy actions red. hold < 0 → stays until hide_skill().
func show_skill(text: String, party: bool, hold: float = 1.1) -> void:
	if text == "":
		return
	_skill_label.text = text
	var edge: Color = Color("#22d3ee") if party else Color("#ff4d4d")
	_box.border_color = Color("#ff2e88") if party else Color("#ff4d4d")
	_skill_side.color = edge
	_skill.visible = true
	_skill.reset_size()
	var sz: Vector2 = _skill.get_combined_minimum_size()
	_skill.offset_left = -sz.x * 0.5
	_skill.offset_right = sz.x * 0.5
	_skill.offset_top = 74.0              # below the show overlay's hype meter (top center)
	_skill.offset_bottom = 74.0 + sz.y
	_skill.modulate.a = 0.0
	if _skill_tw != null and _skill_tw.is_valid():
		_skill_tw.kill()
	if not is_inside_tree():
		_skill.modulate.a = 1.0
		return
	_skill.pivot_offset = sz * 0.5
	_skill.scale = Vector2(0.9, 0.9)
	_skill_tw = create_tween().set_parallel(true)
	_skill_tw.tween_property(_skill, "modulate:a", 1.0, 0.12)
	_skill_tw.tween_property(_skill, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if hold >= 0.0:
		_skill_tw.chain().tween_interval(hold)
		_skill_tw.chain().tween_property(_skill, "modulate:a", 0.0, 0.2)
		_skill_tw.chain().tween_callback(func() -> void: _skill.visible = false)


func hide_skill() -> void:
	if _skill_tw != null and _skill_tw.is_valid():
		_skill_tw.kill()
	_skill.visible = false


## Big centered announcement for `duration` seconds.
func announce(text: String, color: Color = Color("#ffc93c"), duration: float = 0.9, sub: String = "",
		font_size: int = 64) -> void:
	_big_label.text = text
	_big_label.add_theme_color_override("font_color", color)
	_big_label.add_theme_font_size_override("font_size", font_size)
	_big_sub.text = sub
	_big_sub.visible = sub != ""
	_big.visible = true
	_big.reset_size()
	var sz: Vector2 = _big.get_combined_minimum_size()
	_big.offset_left = -sz.x * 0.5
	_big.offset_right = sz.x * 0.5
	_big.offset_top = -sz.y * 0.5 - 70.0
	_big.offset_bottom = sz.y * 0.5 - 70.0
	if _big_tw != null and _big_tw.is_valid():
		_big_tw.kill()
	if not is_inside_tree():
		return
	_big.pivot_offset = sz * 0.5
	_big.scale = Vector2(1.6, 1.6)
	_big.modulate.a = 0.0
	_big_tw = create_tween().set_parallel(true)
	_big_tw.tween_property(_big, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_big_tw.tween_property(_big, "modulate:a", 1.0, 0.1)
	_big_tw.chain().tween_interval(maxf(0.1, duration - 0.35))
	_big_tw.chain().tween_property(_big, "modulate:a", 0.0, 0.25)
	_big_tw.chain().tween_callback(func() -> void: _big.visible = false)
