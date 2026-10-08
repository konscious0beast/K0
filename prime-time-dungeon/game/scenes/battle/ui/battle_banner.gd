extends Control
## Banners of the battle HUD (02_TECH §5.7 table): the skill / action name strip (top center, below the hype meter,
## skewed show panel); big announcements without a subject ("KAMPF!", "COMBO!", "STUNT GEGLÜCKT!", "PATZER!",
## "OVERKILL!", "SIEG!") with a scale pop in the upper third (BIG_Y), never over the shot's subject in the middle;
## and a TV lower third for subject-bound moments (boss intro, phase change, sponsor gift): slanted ink box with an
## accent kicker, its bottom edge 70 % down the safe frame (above the M.O.D. box and its speaker tab), right of center
## and ending left of the CTB bar — the left column belongs to the show overlay (toasts, sponsor bauchbinde, 03_ART
## §9.2), which shows its own sponsor line at the same moment (03_ART §9.1). Private M5 helper (no class_name).

const HudStyle := preload("res://scenes/battle/ui/hud_style.gd")
## Vertical center of the big announcements (fraction of the viewport height).
const BIG_Y: float = 0.27
## Lower third: bottom edge (fraction of the viewport height: 24 + 0.7 × 672 px safe frame ≈ 494 of 720, above
## the M.O.D. speaker tab at 528) and right edge (fraction of the width: 1184 of 1280, left of the CTB bar).
const LOWER_Y: float = 0.686
const LOWER_RIGHT_X: float = 0.925

var _skill: PanelContainer = null
var _skill_label: Label = null
var _skill_side: ColorRect = null
var _skill_tw: Tween = null
var _big: VBoxContainer = null
var _big_label: Label = null
var _big_sub: Label = null
var _big_tw: Tween = null
var _box: StyleBoxFlat = null
var _lower: VBoxContainer = null
var _lower_kicker: PanelContainer = null
var _lower_kicker_box: StyleBoxFlat = null
var _lower_kicker_label: Label = null
var _lower_title: Label = null
var _lower_title_box: StyleBoxFlat = null
var _lower_tw: Tween = null


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
	_big.anchor_left = 0.5
	_big.anchor_right = 0.5
	_big.anchor_top = BIG_Y
	_big.anchor_bottom = BIG_Y
	add_child(_big)
	_big_label = HudStyle.label("", 64, Color("#ffc93c"), true, 10)
	_big_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_big.add_child(_big_label)
	_big_sub = HudStyle.label("", 24, HudStyle.C_PAPER, true, 5)
	_big_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_big.add_child(_big_sub)
	_big.visible = false
	_build_lower_third()


func _build_lower_third() -> void:
	_lower = VBoxContainer.new()
	_lower.name = "LowerThird"
	_lower.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lower.add_theme_constant_override("separation", 0)
	_lower.anchor_left = LOWER_RIGHT_X
	_lower.anchor_right = LOWER_RIGHT_X
	_lower.anchor_top = LOWER_Y
	_lower.anchor_bottom = LOWER_Y
	add_child(_lower)
	_lower_kicker = PanelContainer.new()
	_lower_kicker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lower_kicker.size_flags_horizontal = Control.SIZE_SHRINK_END
	_lower_kicker_box = HudStyle.show_box(Color("#ff4d4d"), Color(0, 0, 0, 0), 0, 0.21, Vector4(22, 2, 22, 2))
	_lower_kicker_box.shadow_size = 0
	_lower_kicker.add_theme_stylebox_override("panel", _lower_kicker_box)
	_lower.add_child(_lower_kicker)
	_lower_kicker_label = HudStyle.label("", 18, HudStyle.C_INK, true, 0)
	_lower_kicker.add_child(_lower_kicker_label)
	var title: PanelContainer = PanelContainer.new()
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.size_flags_horizontal = Control.SIZE_SHRINK_END
	_lower_title_box = HudStyle.show_box(Color(HudStyle.C_INK, 0.9), Color("#ff4d4d"), 0, 0.21, Vector4(30, 4, 34, 6))
	_lower_title_box.border_width_left = 6
	_lower_title_box.border_width_bottom = 2
	title.add_theme_stylebox_override("panel", _lower_title_box)
	_lower.add_child(title)
	_lower_title = HudStyle.label("", 36, HudStyle.C_PAPER, true, 6)
	title.add_child(_lower_title)
	_lower.visible = false


func lower_third_text() -> String:
	return (_lower_kicker_label.text + " | " + _lower_title.text) if _lower.visible else ""


## TV lower third (subject-bound announcement) for `duration` seconds: kicker on the accent color, title on ink.
func lower_third(kicker: String, title: String, color: Color = Color("#ff4d4d"), duration: float = 1.5) -> void:
	_lower_kicker_label.text = kicker.to_upper()
	_lower_kicker.visible = kicker != ""
	_lower_kicker_box.bg_color = color
	_lower_title_box.border_color = color
	_lower_title.text = title
	_lower.visible = true
	_lower.reset_size()
	var sz: Vector2 = _lower.get_combined_minimum_size()
	_lower.offset_left = -sz.x
	_lower.offset_right = 0.0
	_lower.offset_top = -sz.y
	_lower.offset_bottom = 0.0
	if _lower_tw != null and _lower_tw.is_valid():
		_lower_tw.kill()
	if not is_inside_tree():
		return
	# 03_ART §9.1: slide 16 px + fade in 0.18 s (cubic out); out 0.2 s
	_lower.modulate.a = 0.0
	_lower.offset_left = -sz.x + 16.0
	_lower.offset_right = 16.0
	_lower_tw = create_tween().set_parallel(true)
	_lower_tw.tween_property(_lower, "modulate:a", 1.0, 0.18)
	_lower_tw.tween_property(_lower, "offset_left", -sz.x, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_lower_tw.tween_property(_lower, "offset_right", 0.0, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_lower_tw.chain().tween_interval(maxf(0.1, duration - 0.4))
	_lower_tw.chain().tween_property(_lower, "modulate:a", 0.0, 0.2)
	_lower_tw.chain().tween_callback(func() -> void: _lower.visible = false)


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


## Big announcement (upper third, horizontally centered) for `duration` seconds.
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
	_big.offset_top = -sz.y * 0.5
	_big.offset_bottom = sz.y * 0.5
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
