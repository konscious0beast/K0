extends CanvasLayer
## Choice dialog of the exploration (M3-private): floor events (§7.4 "Wahl-Dialog") and the stairs confirmation.
## CanvasLayer 60 (modal menus, §9.4), focus-navigable (keyboard / gamepad), ButtonBig options with a hit area of
## UiTheme.TOUCH_HIT (88 px) and 16 px between them (TECH §10.2 rule 5). ui_cancel / pause close it without a choice
## (chosen("")). The default option (`default_id`, the safe one: "Noch nicht" / "Lassen") gets the focus at once via
## grab_focus.call_deferred() (§10.2 rule 1); confirm presses (ui_accept / action) are ignored for GUARD_SEC after
## opening, so mashing the key that opened the dialog never picks an option by accident.
## Disabled options stay visible for information but are not focusable (FOCUS_NONE, not in the focus ring).

signal chosen(choice_id: String)

const LAYER: int = 60
const GUARD_SEC: float = 0.35
const PANEL_WIDTH: float = 660.0
const OPTION_SEPARATION: int = 16

var _buttons: Array[Button] = []
var _closed: bool = false
var _opened_msec: int = 0
var _default_id: String = ""
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
	panel.offset_bottom = -24.0
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
	_list.name = "Options"
	_list.add_theme_constant_override("separation", OPTION_SEPARATION)
	box.add_child(_list)


## options: [{"id": String, "label": String, "enabled": bool}]; `default_id` = option focused first ("" → first
## enabled). The dialog frees itself after a choice / cancel.
func open(title: String, text: String, options: Array[Dictionary], default_id: String = "") -> void:
	_title.text = title
	_text.text = text
	_text.visible = text != ""
	_default_id = default_id
	_opened_msec = Time.get_ticks_msec()
	for opt: Dictionary in options:
		var b: Button = Button.new()
		b.text = str(opt.get("label", opt.get("id", "")))
		b.theme_type_variation = &"ButtonBig"
		b.custom_minimum_size = Vector2(0.0, float(UiTheme.TOUCH_HIT))
		b.disabled = not bool(opt.get("enabled", true))
		b.focus_mode = Control.FOCUS_NONE if b.disabled else Control.FOCUS_ALL
		var id: String = str(opt.get("id", ""))
		b.set_meta(&"choice_id", id)
		b.pressed.connect(func() -> void: _choose(id))
		_list.add_child(b)
		_buttons.append(b)
	_link_focus()
	if is_inside_tree():
		focus_default.call_deferred()
	else:
		ready.connect(func() -> void: focus_default.call_deferred(), CONNECT_ONE_SHOT)


## Focus on the default option (if enabled), else the first enabled one.
func focus_default() -> void:
	if _closed:
		return
	var target: Button = default_button()
	if target != null and target.is_inside_tree():
		target.grab_focus()


## The option that gets the first focus (null when every option is disabled).
func default_button() -> Button:
	for b: Button in _buttons:
		if not b.disabled and _default_id != "" and _id_of(b) == _default_id:
			return b
	return first_enabled()


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


## True while confirm presses are still ignored after opening.
func is_guarded() -> bool:
	return Time.get_ticks_msec() - _opened_msec < int(GUARD_SEC * 1000.0)


func _id_of(b: Button) -> String:
	return str(b.get_meta(&"choice_id", ""))


## Up/down ring over the enabled options only (TECH §10.2 rule 2: wrap set explicitly).
func _link_focus() -> void:
	var ring: Array[Button] = []
	for b: Button in _buttons:
		if not b.disabled:
			ring.append(b)
	var n: int = ring.size()
	for i in n:
		var b: Button = ring[i]
		b.focus_neighbor_top = b.get_path_to(ring[(i - 1 + n) % n])
		b.focus_neighbor_bottom = b.get_path_to(ring[(i + 1) % n])
		b.focus_neighbor_left = b.get_path_to(b)
		b.focus_neighbor_right = b.get_path_to(b)
		b.focus_previous = b.focus_neighbor_top
		b.focus_next = b.focus_neighbor_bottom


func _choose(choice_id: String) -> void:
	if _closed:
		return
	_closed = true
	Sfx.play_ui(&"ui_confirm" if choice_id != "" else &"ui_cancel")
	chosen.emit(choice_id)
	queue_free()


## Runs before the GUI: swallows confirm presses during the guard window and every echo of a held confirm key.
func _input(event: InputEvent) -> void:
	if _closed:
		return
	if event.is_action(&"ui_accept") or event.is_action(&"action"):
		if event.is_echo() or (event.is_pressed() and is_guarded()):
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if _closed:
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		cancel()
