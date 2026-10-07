extends CanvasLayer
## Choice dialog of the exploration (M3-private): floor events (§7.4 "Wahl-Dialog") and the stairs confirmation.
## CanvasLayer 60 (modal menus, §9.4), focus-navigable (keyboard / gamepad), ButtonBig options (72 px), touch-friendly.
## ui_cancel / pause close it without a choice (chosen("")). The first focus is set after a short delay so the
## `action` press that opened the dialog cannot also confirm the first option.

signal chosen(choice_id: String)

const LAYER: int = 60
const FOCUS_DELAY_SEC: float = 0.15
const PANEL_WIDTH: float = 660.0

var _buttons: Array[Button] = []
var _closed: bool = false
var _title: Label
var _text: Label
var _list: VBoxContainer


func _init() -> void:
	layer = LAYER
	name = "ChoiceDialog"
	var root: Control = Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.theme = UiTheme.get_theme()
	add_child(root)
	var dim: ColorRect = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(UiTheme.C_BG, 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "Panel"
	panel.theme_type_variation = &"PanelDialog"
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -PANEL_WIDTH * 0.5
	panel.offset_right = PANEL_WIDTH * 0.5
	panel.offset_bottom = -40.0
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	_title = Label.new()
	_title.theme_type_variation = &"LabelHeader"
	_title.add_theme_color_override("font_color", UiTheme.C_GOLD)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_title)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(PANEL_WIDTH - 40.0, 0.0)
	box.add_child(_text)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 16)
	box.add_child(_list)


## options: [{"id": String, "label": String, "enabled": bool}]; the dialog frees itself after a choice / cancel.
func open(title: String, text: String, options: Array[Dictionary]) -> void:
	_title.text = title
	_text.text = text
	_text.visible = text != ""
	for opt: Dictionary in options:
		var b: Button = Button.new()
		b.text = str(opt.get("label", opt.get("id", "")))
		b.theme_type_variation = &"ButtonBig"
		b.custom_minimum_size = Vector2(0.0, float(UiTheme.BUTTON_BIG_MIN_HEIGHT))
		b.focus_mode = Control.FOCUS_ALL
		b.disabled = not bool(opt.get("enabled", true))
		var id: String = str(opt.get("id", ""))
		b.set_meta(&"choice_id", id)
		b.pressed.connect(func() -> void: _choose(id))
		_list.add_child(b)
		_buttons.append(b)
	_link_focus()
	if is_inside_tree():
		get_tree().create_timer(FOCUS_DELAY_SEC).timeout.connect(focus_default)
	else:
		ready.connect(func() -> void: get_tree().create_timer(FOCUS_DELAY_SEC).timeout.connect(focus_default),
			CONNECT_ONE_SHOT)


## Focus on the first enabled option (or the first option).
func focus_default() -> void:
	if _closed:
		return
	var target: Button = first_enabled()
	if target == null and not _buttons.is_empty():
		target = _buttons[0]
	if target != null and target.is_inside_tree():
		target.grab_focus()


func first_enabled() -> Button:
	for b: Button in _buttons:
		if not b.disabled:
			return b
	return null


func buttons() -> Array[Button]:
	return _buttons


## Picks an option programmatically (tests, autoplay); disabled / unknown ids are ignored.
func choose(choice_id: String) -> void:
	for b: Button in _buttons:
		if not b.disabled and _id_of(b) == choice_id:
			_choose(choice_id)
			return


func cancel() -> void:
	_choose("")


func is_closed() -> bool:
	return _closed


func _id_of(b: Button) -> String:
	return str(b.get_meta(&"choice_id", ""))


func _link_focus() -> void:
	var n: int = _buttons.size()
	for i in n:
		var b: Button = _buttons[i]
		b.focus_neighbor_top = b.get_path_to(_buttons[(i - 1 + n) % n])
		b.focus_neighbor_bottom = b.get_path_to(_buttons[(i + 1) % n])
		b.focus_neighbor_left = b.get_path_to(b)
		b.focus_neighbor_right = b.get_path_to(b)


func _choose(choice_id: String) -> void:
	if _closed:
		return
	_closed = true
	Sfx.play_ui(&"ui_confirm" if choice_id != "" else &"ui_cancel")
	chosen.emit(choice_id)
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if _closed:
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		cancel()
