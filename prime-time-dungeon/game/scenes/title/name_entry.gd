extends Control
## Name entry (02_TECH §1.6, GDD §14.2): LineEdit (max_length 12, default "Kai"), on-screen keyboard for gamepad /
## touch (QWERTZ incl. Ä Ö Ü ß, shift, space, delete) and the mode choice Prime Time / Vorabendprogramm. "Sendung
## starten" → the single new-game path (TitleFlow.start_new_game → intro). Params {"slot": int}.

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const UiIcon := preload("res://scenes/ui/ui_icon.gd")
const Backdrop := preload("res://scenes/ui/broadcast_bg.gd")
const TitleFlow := preload("res://scenes/title/title_flow.gd")
const SLOT_SELECT: String = "res://scenes/title/slot_select.tscn"
const MAX_LEN: int = 12
const ROWS: Array[String] = ["QWERTZUIOPÜ", "ASDFGHJKLÖÄ", "YXCVBNMß-."]
const MODES: Array[Dictionary] = [
	{"id": &"prime", "title": "Prime Time", "text": "Die echte Sendung. Etagen-Timer 20:00, volle Härte."},
	{"id": &"vorabend", "title": "Vorabendprogramm", "text": "Timer × 1,5 (30:00), Gegnerschaden × 0,75, EXP × 1,2. " +
		"Später nur absenkbar, nie anhebbar."},
]

var slot: int = 1
var difficulty: StringName = &"prime"
var name_edit: LineEdit

var _params: Dictionary = {}
var _shift: bool = true
var _keys: Array[Button] = []
var _mode_buttons: Array[Button] = []
var _start: Button
var _busy: bool = false


func setup(params: Dictionary) -> void:
	_params = params
	slot = int(params.get("slot", 1))


func _ready() -> void:
	UiUtil.full_rect(self)
	Events.overlay_mode_requested.emit.call_deferred(&"menu")
	_build()
	UiUtil.focus_later(name_edit)
	name_edit.caret_column = name_edit.text.length()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		back()


func entered_name() -> String:
	return TitleFlow.clean_name(name_edit.text)


func type_char(c: String) -> void:
	if name_edit.text.length() >= MAX_LEN:
		Sfx.play_ui(&"ui_error")
		return
	var ch: String = c if _shift else c.to_lower()
	if c == "ß":
		ch = "ß"
	name_edit.text += ch
	name_edit.caret_column = name_edit.text.length()
	if _shift and name_edit.text.length() >= 1:
		_set_shift(false)


func backspace() -> void:
	if name_edit.text.is_empty():
		return
	name_edit.text = name_edit.text.substr(0, name_edit.text.length() - 1)
	name_edit.caret_column = name_edit.text.length()
	if name_edit.text.is_empty():
		_set_shift(true)


func set_difficulty(d: StringName) -> void:
	difficulty = d
	for b: Button in _mode_buttons:
		b.button_pressed = StringName(str(b.get_meta("mode_id"))) == d


func start() -> void:
	if _busy:
		return
	_busy = true
	Sfx.play_ui(&"stunt_success")
	if not TitleFlow.start_new_game(slot, entered_name(), false, -1, difficulty):
		_busy = false
		Events.toast_requested.emit("Neues Spiel konnte nicht gestartet werden.", &"warning")


func back() -> void:
	if _busy:
		return
	_busy = true
	Sfx.play_ui(&"ui_cancel")
	Router.goto(SLOT_SELECT, {"mode": "new"})


func _set_shift(on: bool) -> void:
	_shift = on
	for k: Button in _keys:
		if k.has_meta("char"):
			var c: String = str(k.get_meta("char"))
			k.text = c if on or c == "ß" else c.to_lower()


func _build() -> void:
	add_child(Backdrop.new())
	var safe: SafeAreaContainer = SafeAreaContainer.new()
	safe.extra = 24
	add_child(safe)
	var col: VBoxContainer = UiUtil.vbox(12)
	safe.add_child(col)
	var head: HBoxContainer = UiUtil.hbox(14)
	col.add_child(head)
	head.add_child(UiUtil.label("KANDIDAT:IN", &"LabelTitle", 48))
	var slot_l: Label = UiUtil.label("Slot %d" % slot, &"", 18, UiTheme.C_ACCENT_2)
	slot_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(slot_l)
	head.add_child(UiUtil.spacer(0, 0, true))
	head.add_child(InputGlyph.make(&"ui_cancel", "Zurück", 16))
	var body: HBoxContainer = UiUtil.hbox(28)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	var left: VBoxContainer = UiUtil.vbox(10)
	body.add_child(left)
	left.add_child(UiUtil.label("Wie sollen die Zuschauer:innen dich nennen?", &"", 20, UiTheme.C_TEXT_DIM))
	name_edit = LineEdit.new()
	name_edit.name = "NameEdit"
	name_edit.max_length = MAX_LEN
	name_edit.text = "Kai"
	name_edit.placeholder_text = "Kai"
	name_edit.custom_minimum_size = Vector2(0, 64)
	name_edit.add_theme_font_size_override("font_size", 32)
	name_edit.focus_mode = Control.FOCUS_ALL
	name_edit.text_submitted.connect(func(_t: String) -> void: _start.grab_focus())
	name_edit.text_changed.connect(func(t: String) -> void:
		var clean: String = UiUtil.glyph_safe(t)
		if clean != t:
			name_edit.text = clean.replace("?", "")
			name_edit.caret_column = name_edit.text.length())
	left.add_child(name_edit)
	var kb: VBoxContainer = UiUtil.vbox(6)
	left.add_child(kb)
	for r: String in ROWS:
		var row: HBoxContainer = UiUtil.hbox(6)
		kb.add_child(row)
		for i in r.length():
			var c: String = r[i]
			var k: Button = UiUtil.button(c, &"")
			k.custom_minimum_size = Vector2(64, 64)
			k.set_meta("char", c)
			k.add_theme_font_size_override("font_size", 22)
			k.pressed.connect(func() -> void: type_char(c))
			row.add_child(k)
			_keys.append(k)
	var srow: HBoxContainer = UiUtil.hbox(6)
	kb.add_child(srow)
	var shift_b: Button = UiUtil.button("Aa", &"")
	shift_b.custom_minimum_size = Vector2(134, 64)
	shift_b.pressed.connect(func() -> void: _set_shift(not _shift))
	srow.add_child(shift_b)
	var space_b: Button = UiUtil.button("Leerzeichen", &"")
	space_b.custom_minimum_size = Vector2(344, 64)
	space_b.pressed.connect(func() -> void:
		if name_edit.text.length() < MAX_LEN and not name_edit.text.ends_with(" ") and name_edit.text != "":
			name_edit.text += " "
			name_edit.caret_column = name_edit.text.length())
	srow.add_child(space_b)
	var del_b: Button = UiUtil.button("Löschen", &"")
	del_b.custom_minimum_size = Vector2(206, 64)
	del_b.pressed.connect(backspace)
	srow.add_child(del_b)
	_set_shift(false)
	var right: VBoxContainer = UiUtil.vbox(12)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)
	right.add_child(UiUtil.label("SENDEFORMAT", &"", 15, UiTheme.C_ACCENT))
	var group: ButtonGroup = ButtonGroup.new()
	var mode_list: Array[Control] = []
	for m: Dictionary in MODES:
		var b: Button = UiUtil.button("", &"ButtonBig")
		b.name = "Mode_" + str(m["id"])
		b.toggle_mode = true
		b.button_group = group
		b.set_meta("mode_id", str(m["id"]))
		b.custom_minimum_size = Vector2(0, 142)
		var mid: StringName = m["id"]
		b.pressed.connect(func() -> void: set_difficulty(mid))
		var inner: VBoxContainer = UiUtil.vbox(4)
		UiUtil.full_rect(inner)
		inner.offset_left = 22
		inner.offset_right = -18
		inner.offset_top = 12
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(inner)
		var t: Label = UiUtil.label(str(m["title"]), &"", 26)
		t.add_theme_font_override("font", UiTheme.font_bold())
		inner.add_child(t)
		var d: Label = UiUtil.label(str(m["text"]), &"LabelSmall", 16)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		inner.add_child(d)
		right.add_child(b)
		_mode_buttons.append(b)
		mode_list.append(b)
	var pressed_sb: StyleBoxFlat = UiUtil.box_style(Color(UiTheme.C_ACCENT, 0.35), UiTheme.C_ACCENT, 3, 0.0, 24, 20)
	for b: Button in _mode_buttons:
		b.add_theme_stylebox_override("pressed", pressed_sb)
		b.add_theme_stylebox_override("hover_pressed", pressed_sb)
	set_difficulty(&"prime")
	right.add_child(UiUtil.spacer(0, 0, true))
	_start = UiUtil.button("Sendung starten", &"ButtonBig")
	_start.name = "Start"
	_start.custom_minimum_size = Vector2(0, 80)
	_start.pressed.connect(start)
	right.add_child(_start)
	mode_list.append(_start)
	UiUtil.wire_vertical(mode_list)
	var hint: Label = UiUtil.label("Tastatur: tippen und Enter · Gamepad/Touch: Bildschirmtastatur", &"LabelSmall", 14)
	col.add_child(hint)
