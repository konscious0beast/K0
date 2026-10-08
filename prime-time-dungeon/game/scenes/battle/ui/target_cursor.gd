extends Control
## Target selection of the battle HUD (02_TECH §1.6, GDD §14.5/§14.8): bouncing gold arrow(s) over the selected
## target(s) (projected from the rig's overhead anchor), rig highlight, and a focusable target panel with name, HP
## (number only when the bestiary knows the type), known weaknesses and Ausführen / Zurück buttons.
## Keys: left/right (up/down) switch, accept executes, cancel goes back. Touch/mouse: tapping a target (hit box
## ≥ 107 px) selects it, tapping it again (or "Ausführen") executes. Modes: single, all, random, self.
## Private M5 helper (no class_name).

signal confirmed(ids: PackedStringArray)
signal cancelled
signal changed(id: String)

const HudStyle := preload("res://scenes/battle/ui/hud_style.gd")
const TAP_MIN: float = 107.0
const ARROW: Color = Color("#ffc93c")


## Focusable target panel: consumes navigation so focus never leaves it while targeting.
class Selector extends PanelContainer:
	var cursor: Control = null

	func _gui_input(event: InputEvent) -> void:
		if cursor == null:
			return
		if event.is_action_pressed(&"ui_left") or event.is_action_pressed(&"ui_up"):
			cursor.call("move", -1)
			accept_event()
		elif event.is_action_pressed(&"ui_right") or event.is_action_pressed(&"ui_down"):
			cursor.call("move", 1)
			accept_event()
		elif event.is_action_pressed(&"ui_accept"):
			cursor.call("confirm")
			accept_event()
		elif event.is_action_pressed(&"ui_cancel"):
			cursor.call("cancel")
			accept_event()
		elif event.is_action_pressed(&"ui_focus_next") or event.is_action_pressed(&"ui_focus_prev"):
			accept_event()


var stage: Node3D = null
var camera: Camera3D = null
## Provider (BattleHud): target_info(id) -> {"name", "hp", "max_hp", "show_hp", "weak": PackedStringArray}.
var provider: Object = null
var candidates: PackedStringArray = []
var mode: String = "single"
var index: int = 0
var active: bool = false

var panel: Selector = null
var ok_button: Button = null
var back_button: Button = null
var _title: Label = null
var _name: Label = null
var _hp_bar: HudStyle.Bar = null
var _hp_label: Label = null
var _weak_row: HBoxContainer = null
var _weak_label: Label = null
var _t: float = 0.0
var _highlighted: PackedStringArray = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel = Selector.new()
	panel.cursor = self
	panel.name = "TargetPanel"
	panel.focus_mode = Control.FOCUS_ALL
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", HudStyle.show_box(HudStyle.C_PANEL, Color("#ffc93c"), 2, 0.0,
		Vector4(12, 8, 12, 10)))
	var focus_box: StyleBoxFlat = HudStyle.show_box(Color(0, 0, 0, 0), Color("#22d3ee"), 3, 0.0)
	focus_box.draw_center = false
	focus_box.shadow_size = 0
	focus_box.set_expand_margin_all(2.0)
	panel.add_theme_stylebox_override("focus", focus_box)
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(v)
	_title = HudStyle.label("", 15, Color("#b3a7c9"), true, 2)
	v.add_child(_title)
	_name = HudStyle.label("", 22, HudStyle.C_PAPER, true, 3)
	v.add_child(_name)
	var hp_row: HBoxContainer = HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 6)
	hp_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(hp_row)
	_hp_bar = HudStyle.Bar.new(HudStyle.C_HP, 8.0)
	_hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hp_row.add_child(_hp_bar)
	_hp_label = HudStyle.mono_label("", 15)
	_hp_label.custom_minimum_size = Vector2(80, 0)
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hp_row.add_child(_hp_label)
	_weak_row = HBoxContainer.new()
	_weak_row.add_theme_constant_override("separation", 4)
	_weak_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_weak_row)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(buttons)
	ok_button = Button.new()
	ok_button.name = "Execute"
	ok_button.text = tr("Ausführen")
	ok_button.custom_minimum_size = Vector2(150, 46)
	ok_button.focus_mode = Control.FOCUS_NONE
	ok_button.pressed.connect(confirm)
	buttons.add_child(ok_button)
	back_button = Button.new()
	back_button.name = "Back"
	back_button.text = tr("Zurück")
	back_button.custom_minimum_size = Vector2(120, 46)
	back_button.focus_mode = Control.FOCUS_NONE
	back_button.pressed.connect(cancel)
	buttons.add_child(back_button)
	for b: Button in [ok_button, back_button]:
		var accent: Color = Color("#ffc93c") if b == ok_button else Color("#b3a7c9")
		var normal: StyleBoxFlat = HudStyle.show_box(Color(0.16, 0.1, 0.24, 0.95), Color(accent, 0.8), 2, 0.0,
			Vector4(14, 6, 14, 6))
		normal.shadow_size = 0
		var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
		hover.border_color = Color("#ff2e88")
		hover.bg_color = Color(0.26, 0.12, 0.3, 0.98)
		b.add_theme_stylebox_override("normal", normal)
		b.add_theme_stylebox_override("hover", hover)
		b.add_theme_stylebox_override("pressed", hover)
		b.add_theme_font_override("font", UiTheme.font_bold())
		b.add_theme_font_size_override("font_size", 19)
	add_child(panel)
	panel.visible = false
	visible = false


func begin(p_candidates: PackedStringArray, p_mode: String, default_id: String, title: String) -> void:
	candidates = p_candidates.duplicate()
	mode = p_mode
	index = maxi(0, candidates.find(default_id))
	active = true
	visible = true
	panel.visible = true
	# touch: the buttons themselves are the >= 88 px hit areas (02_TECH §10.2); keys/pad: compact
	var touch: bool = Game.input_scheme == Game.InputScheme.TOUCH
	ok_button.custom_minimum_size = Vector2(170, UiTheme.TOUCH_HIT) if touch else Vector2(150, 46)
	back_button.custom_minimum_size = Vector2(130, UiTheme.TOUCH_HIT) if touch else Vector2(120, 46)
	_title.text = title.to_upper()
	_refresh()
	panel.grab_focus.call_deferred()


func end() -> void:
	active = false
	visible = false
	panel.visible = false
	_set_highlights(PackedStringArray())
	if panel.has_focus():
		panel.release_focus()


func selected_ids() -> PackedStringArray:
	if candidates.is_empty():
		return PackedStringArray()
	if mode == "all" or mode == "random":
		return candidates.duplicate()
	return PackedStringArray([candidates[clampi(index, 0, candidates.size() - 1)]])


func current_id() -> String:
	return candidates[clampi(index, 0, candidates.size() - 1)] if not candidates.is_empty() else ""


func move(step: int) -> void:
	if not active or candidates.is_empty() or mode != "single":
		return
	index = (index + step + candidates.size()) % candidates.size()
	Sfx.play_ui(&"ui_move")
	_refresh()


func select_id(id: String) -> void:
	var i: int = candidates.find(id)
	if i < 0 or not active:
		return
	if mode == "single":
		index = i
	_refresh()


func confirm() -> void:
	if not active or candidates.is_empty():
		return
	var ids: PackedStringArray = selected_ids()
	Sfx.play_ui(&"ui_confirm")
	end()
	confirmed.emit(ids)


func cancel() -> void:
	if not active:
		return
	Sfx.play_ui(&"ui_cancel")
	end()
	cancelled.emit()


func _process(delta: float) -> void:
	_t += delta
	if active:
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not active or camera == null:
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var hit: String = _pick(mb.position)
	if hit == "":
		return
	get_viewport().set_input_as_handled()
	if mode != "single" or hit == current_id():
		confirm()
	else:
		select_id(hit)
		Sfx.play_ui(&"ui_move")


## Screen-space hit box of a candidate (≥ 107 px around the projected rig).
func hit_rect(id: String) -> Rect2:
	if stage == null or camera == null:
		return Rect2()
	var top: Vector3 = stage.call("anchor_pos", id, &"overhead")
	var feet: Vector3 = stage.call("anchor_pos", id, &"feet")
	if camera.is_position_behind(top) or camera.is_position_behind(feet):
		return Rect2()
	var a: Vector2 = camera.unproject_position(top)
	var b: Vector2 = camera.unproject_position(feet)
	var h: float = maxf(TAP_MIN, absf(b.y - a.y))
	var w: float = maxf(TAP_MIN, h * 0.7)
	var c: Vector2 = (a + b) * 0.5
	return Rect2(c - Vector2(w, h) * 0.5, Vector2(w, h))


func _pick(p: Vector2) -> String:
	var best: String = ""
	var best_d: float = INF
	for id: String in candidates:
		var r: Rect2 = hit_rect(id)
		if r.has_point(p):
			var d: float = r.get_center().distance_to(p)
			if d < best_d:
				best_d = d
				best = id
	return best


func _refresh() -> void:
	var ids: PackedStringArray = selected_ids()
	_set_highlights(ids)
	var id: String = current_id()
	var info: Dictionary = provider.call("target_info", id) if provider != null and id != "" else {}
	match mode:
		"all":
			_name.text = tr("Alle Ziele")
		"random":
			_name.text = tr("Zufälliges Ziel")
		_:
			_name.text = str(info.get("name", id))
	var single: bool = mode == "single" or mode == "self"
	_hp_bar.get_parent().visible = single and not info.is_empty()
	if single and not info.is_empty():
		var mx: int = maxi(1, int(info.get("max_hp", 1)))
		var hp: int = int(info.get("hp", 0))
		_hp_bar.set_ratio(float(hp) / float(mx), false)
		_hp_bar.fill = HudStyle.C_HP if hp * 4 >= mx else HudStyle.C_HP_LOW
		_hp_label.text = "%d/%d" % [hp, mx] if bool(info.get("show_hp", true)) else "???"
	for c: Node in _weak_row.get_children():
		c.queue_free()
	var weak: PackedStringArray = info.get("weak", PackedStringArray()) if single else PackedStringArray()
	_weak_row.visible = not weak.is_empty()
	if not weak.is_empty():
		_weak_row.add_child(HudStyle.label(tr("Schwach:"), 15, Color("#ffe14d"), true, 2))
		for el: String in weak:
			_weak_row.add_child(HudStyle.Icon.new("element_" + el, HudStyle.element_color(el), 16))
	changed.emit(id)


func _set_highlights(ids: PackedStringArray) -> void:
	if stage == null:
		_highlighted = ids.duplicate()
		return
	for old: String in _highlighted:
		if not ids.has(old):
			var r: CharacterRig = stage.call("rig", old)
			if r != null:
				r.set_highlight(false)
	for id: String in ids:
		var r2: CharacterRig = stage.call("rig", id)
		if r2 != null:
			r2.set_highlight(true)
	_highlighted = ids.duplicate()


func _draw() -> void:
	if not active or stage == null or camera == null:
		return
	var bob: float = 6.0 * absf(sin(_t * 5.0))
	for id: String in selected_ids():
		var top: Vector3 = stage.call("anchor_pos", id, &"overhead")
		if camera.is_position_behind(top):
			continue
		var p: Vector2 = camera.unproject_position(top) - Vector2(0, 14.0 + bob)
		var pts: PackedVector2Array = PackedVector2Array([p + Vector2(-15, -22), p + Vector2(15, -22), p])
		var outline: PackedVector2Array = pts.duplicate()
		outline.append(pts[0])
		draw_colored_polygon(pts, ARROW)
		draw_polyline(outline, HudStyle.C_INK, 3.0, true)
		draw_line(p + Vector2(-8, -18), p + Vector2(0, -6), Color(1, 1, 1, 0.55), 2.0)
