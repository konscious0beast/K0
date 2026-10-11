extends Control
## On-screen keyboard (08 §1.6, K1; private helper, no class_name — the casting's name and "Anderes …" fields, from
## the name entry's keyboard): a modal panel with the text, QWERTZ with Ä Ö Ü ß, "Aa" (shift: the first letter is upper
## case), "Akzente" (a second layer é è ê á à â ó ò ô ú ù û í ì î ñ ç ł ø å æ œ č š ž ğ ş …; keys the font cannot draw
## are left out, TitleFlow.clean_name would drop them anyway), space, delete and "Fertig". Keys are 88 × 88 hit areas
## (76 px visible) 12 px apart (02_TECH §10.2 rule 5). Gamepad: d-pad over the keys, A types, X deletes, Start =
## Fertig, B = cancel. Keyboard: typing goes straight in, Enter = Fertig, Esc = cancel. Touch: tap the keys;
## "Abbrechen" in the head (every scheme) cancels.
## The caller checks the text on `submitted` and calls show_error(reason[, suggestion]) to keep the panel open.

signal submitted(text: String)
signal cancelled()
signal changed(text: String)
## The suggestion button of show_error was pressed (e.g. the nearest Vorleben tile of a rejected free text).
signal suggestion_chosen(id: String)

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const ROWS: Array[String] = ["QWERTZUIOPÜ", "ASDFGHJKLÖÄ", "YXCVBNMß-.'"]
const ACCENT_ROWS: Array[String] = ["ÉÈÊÁÀÂÓÒÔÚÙ", "ÛÍÌÎÑÇŁØÅÆŒ", "ČŠŽĞŞÝËÏ-.'"]
const KEY: float = 88.0                    # hit area (UiTheme.TOUCH_HIT)
const KEY_VISIBLE: float = 76.0
const GAP: int = 12

var title: String = ""
var max_len: int = 12
var text_scale: float = 1.0
var edit: LineEdit
var shift: bool = true
var accents: bool = false

var _params: Dictionary = {}
var _rows: Array[HBoxContainer] = []
var _keys: Array[Button] = []              # character keys of the current layer
var _controls: Array[Button] = []          # Aa, Akzente, space, delete, Fertig
var _error: Label
var _suggest: Button
var _suggest_id: String = ""
var _layer_btn: Button
var _done: Button


## {"title", "text", "max_len", "placeholder", "hint", "text_scale"}.
func setup(params: Dictionary) -> void:
	_params = params
	title = str(params.get("title", "EINGABE"))
	max_len = maxi(1, int(params.get("max_len", 12)))
	text_scale = clampf(float(params.get("text_scale", 1.0)), 1.0, 1.5)


func _ready() -> void:
	UiUtil.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	edit.text = str(_params.get("text", "")).substr(0, max_len)
	_set_shift(edit.text == "")
	UiUtil.focus_later(_keys[0] if not _keys.is_empty() else _done)


## Text and focus stay; only the keyboard input of the panel (children first: before the casting).
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
		match (event as InputEventJoypadButton).button_index:
			JOY_BUTTON_B:
				_handled()
				cancel()
			JOY_BUTTON_START:
				_handled()
				submit()
			JOY_BUTTON_X:
				_handled()
				backspace()
		return
	if not (event is InputEventKey) or not (event as InputEventKey).pressed:
		return
	var k: InputEventKey = event
	if k.keycode == KEY_ESCAPE:
		_handled()
		cancel()
	elif k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER:
		_handled()
		submit()
	elif edit.has_focus():
		return                                 # the LineEdit types itself
	elif k.keycode == KEY_BACKSPACE:
		_handled()
		backspace()
	elif k.unicode >= 32 and not k.ctrl_pressed and not k.alt_pressed and not k.meta_pressed:
		_handled()
		insert(String.chr(k.unicode))


## A key of the layer: upper case while shift is on (then shift goes off), else lower case.
func type_char(c: String) -> void:
	insert(c if shift else c.to_lower())
	if shift and edit.text.length() >= 1:
		_set_shift(false)


## Appends `s` (glyphs the font lacks are dropped); full → error sound.
func insert(s: String) -> void:
	var clean: String = UiUtil.glyph_safe(s).replace("?", "") if s != "?" else s
	if clean == "":
		return
	if edit.text.length() + clean.length() > max_len:
		Sfx.play_ui(&"ui_error")
		return
	edit.text += clean
	edit.caret_column = edit.text.length()
	hide_error()
	changed.emit(edit.text)


func backspace() -> void:
	if edit.text.is_empty():
		return
	edit.text = edit.text.substr(0, edit.text.length() - 1)
	edit.caret_column = edit.text.length()
	if edit.text.is_empty():
		_set_shift(true)
	hide_error()
	changed.emit(edit.text)


func space() -> void:
	if edit.text != "" and not edit.text.ends_with(" "):
		insert(" ")


func toggle_accents() -> void:
	accents = not accents
	_fill_rows()
	_layer_btn.text = "ABC" if accents else "Akzente"
	UiUtil.focus_later(_keys[0] if not _keys.is_empty() else _done)


func submit() -> void:
	submitted.emit(edit.text.strip_edges())


func cancel() -> void:
	Sfx.play_ui(&"ui_cancel")
	cancelled.emit()


## Keeps the panel open with a reason sentence (red) and, optionally, a suggestion button ("Stattdessen: …").
func show_error(reason: String, suggestion_label: String = "", suggestion_id: String = "") -> void:
	_error.text = reason
	_error.visible = reason != ""
	_suggest_id = suggestion_id
	_suggest.text = "Stattdessen: " + suggestion_label if suggestion_label != "" else ""
	_suggest.visible = suggestion_label != ""
	Sfx.play_ui(&"ui_error")
	if _suggest.visible:
		UiUtil.focus_later(_suggest)


func hide_error() -> void:
	if _error != null:
		_error.visible = false
		_suggest.visible = false


func error_text() -> String:
	return _error.text if _error != null and _error.visible else ""


## The character keys of the current layer (tests).
func key_buttons() -> Array[Button]:
	return _keys.duplicate()


## Aa, Akzente, Leerzeichen, Löschen, Fertig (tests).
func control_buttons() -> Array[Button]:
	return _controls.duplicate()


# --- build ------------------------------------------------------------------------------------------------------------

func _fs(px: int) -> int:
	return roundi(px * text_scale)


func _handled() -> void:
	get_viewport().set_input_as_handled()


func _set_shift(on: bool) -> void:
	shift = on
	for k: Button in _keys:
		var c: String = str(k.get_meta("char"))
		k.text = c if on or not _has_lower(c) else c.to_lower()


static func _has_lower(c: String) -> bool:
	return c.to_lower() != c and c != "ß"


func _build() -> void:
	var dim: ColorRect = ColorRect.new()
	UiUtil.full_rect(dim)
	dim.color = Color(0.03, 0.02, 0.06, 0.84)
	add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	UiUtil.full_rect(center)
	add_child(center)
	var panel: PanelContainer = UiUtil.panel(&"PanelMenu")
	panel.name = "Keyboard"
	center.add_child(panel)
	var col: VBoxContainer = UiUtil.vbox(GAP)
	panel.add_child(col)
	var head: HBoxContainer = UiUtil.hbox(14)
	col.add_child(head)
	var t: Label = UiUtil.label(title, &"", _fs(20), UiTheme.C_ACCENT_2)
	t.add_theme_font_override("font", UiTheme.font_bold())
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(t)
	var cancel_b: Button = UiUtil.button("Abbrechen", &"")   # touch has no Esc / B: a visible way back
	cancel_b.name = "Cancel"
	cancel_b.custom_minimum_size = Vector2(200, 0)
	cancel_b.add_theme_font_size_override("font_size", _fs(22))
	UiUtil.touch_pad(cancel_b)
	cancel_b.pressed.connect(cancel)
	head.add_child(cancel_b)
	edit = LineEdit.new()
	edit.name = "Text"
	edit.max_length = max_len
	edit.placeholder_text = str(_params.get("placeholder", ""))
	edit.virtual_keyboard_enabled = false
	edit.custom_minimum_size = Vector2(0, UiTheme.TOUCH_HIT)
	edit.add_theme_font_size_override("font_size", _fs(30))
	edit.focus_mode = Control.FOCUS_ALL
	edit.text_changed.connect(func(txt: String) -> void:
		var clean: String = UiUtil.glyph_safe(txt).replace("?", "") if not txt.contains("?") else txt
		if clean != txt:
			edit.text = clean
			edit.caret_column = edit.text.length()
		hide_error()
		changed.emit(edit.text))
	edit.text_submitted.connect(func(_t: String) -> void: submit())
	col.add_child(edit)
	var hint: String = str(_params.get("hint", ""))
	if hint != "":
		var h: Label = UiUtil.label(hint, &"LabelSmall", _fs(16), UiTheme.C_TEXT_DIM)
		h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(h)
	var err_row: HBoxContainer = UiUtil.hbox(14)
	col.add_child(err_row)
	_error = UiUtil.label("", &"", _fs(18), UiTheme.C_DANGER)
	_error.name = "Error"
	_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_error.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_error.visible = false
	err_row.add_child(_error)
	_suggest = UiUtil.button("", &"")
	_suggest.name = "Suggestion"
	_suggest.add_theme_font_size_override("font_size", _fs(18))
	UiUtil.touch_pad(_suggest)
	_suggest.visible = false
	_suggest.pressed.connect(func() -> void: suggestion_chosen.emit(_suggest_id))
	err_row.add_child(_suggest)
	var keys: VBoxContainer = UiUtil.vbox(GAP)
	keys.name = "Keys"
	col.add_child(keys)
	for i in ROWS.size():
		var row: HBoxContainer = UiUtil.hbox(GAP)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		keys.add_child(row)
		_rows.append(row)
	var crow: HBoxContainer = UiUtil.hbox(GAP)
	crow.alignment = BoxContainer.ALIGNMENT_CENTER
	keys.add_child(crow)
	var shift_b: Button = _control_key("Aa", 128.0, func() -> void: _set_shift(not shift))
	shift_b.name = "Shift"
	crow.add_child(shift_b)
	_layer_btn = _control_key("Akzente", 168.0, toggle_accents)
	_layer_btn.name = "Accents"
	crow.add_child(_layer_btn)
	var space_b: Button = _control_key("Leerzeichen", 264.0, space)
	space_b.name = "Space"
	crow.add_child(space_b)
	var del_b: Button = _control_key("Löschen", 168.0, backspace)
	del_b.name = "Delete"
	crow.add_child(del_b)
	_done = _control_key("Fertig", 168.0, submit)
	_done.name = "Done"
	_done.theme_type_variation = &"ButtonBig"
	crow.add_child(_done)
	_fill_rows()


func _fill_rows() -> void:
	for k: Button in _keys:
		k.get_parent().remove_child(k)
		k.queue_free()
	_keys.clear()
	var layer: Array[String] = ACCENT_ROWS if accents else ROWS
	var font: Font = ThemeDB.fallback_font
	for i in layer.size():
		for j in layer[i].length():
			var c: String = layer[i][j]
			if not font.has_char(c.unicode_at(0)) or not font.has_char(c.to_lower().unicode_at(0)):
				continue
			var k: Button = UiUtil.button(c, &"")
			k.name = "Key_%d_%d" % [i, j]
			k.set_meta("char", c)
			k.custom_minimum_size = Vector2(KEY, 0)
			k.add_theme_font_size_override("font_size", _fs(26))
			UiUtil.touch_pad(k, KEY_VISIBLE)
			k.pressed.connect(func() -> void: type_char(c))
			_rows[i].add_child(k)
			_keys.append(k)
	_set_shift(shift)
	_wire()


func _control_key(caption: String, width: float, cb: Callable) -> Button:
	var b: Button = UiUtil.button(caption, &"")
	b.custom_minimum_size = Vector2(width, 0)
	b.add_theme_font_size_override("font_size", _fs(22))
	UiUtil.touch_pad(b, KEY_VISIBLE)
	b.pressed.connect(cb)
	_controls.append(b)
	return b


## Grid focus with wrap: left / right within a row, up / down to the nearest key of the next row (the control row
## last); Tab runs through all keys.
func _wire() -> void:
	var grid: Array[Array] = []
	for r: HBoxContainer in _rows:
		var row: Array = []
		for c: Node in r.get_children():
			if c is Button and not (c as Button).is_queued_for_deletion():
				row.append(c)
		if not row.is_empty():
			grid.append(row)
	grid.append(_controls.duplicate())
	var flat: Array[Control] = []
	for ri in grid.size():
		var row: Array = grid[ri]
		var horiz: Array[Control] = []
		for c: Variant in row:
			horiz.append(c as Control)
			flat.append(c as Control)
		UiUtil.wire_horizontal(horiz)
		for ci in row.size():
			var b: Control = row[ci]
			var up: Array = grid[posmod(ri - 1, grid.size())]
			var down: Array = grid[posmod(ri + 1, grid.size())]
			b.focus_neighbor_top = b.get_path_to(up[_nearest(row.size(), ci, up.size())] as Control)
			b.focus_neighbor_bottom = b.get_path_to(down[_nearest(row.size(), ci, down.size())] as Control)
	for i in flat.size():
		flat[i].focus_next = flat[i].get_path_to(flat[(i + 1) % flat.size()])
		flat[i].focus_previous = flat[i].get_path_to(flat[posmod(i - 1, flat.size())])


static func _nearest(n_from: int, i: int, n_to: int) -> int:
	if n_from <= 1:
		return 0
	return clampi(roundi(float(i) * float(n_to - 1) / float(n_from - 1)), 0, n_to - 1)
