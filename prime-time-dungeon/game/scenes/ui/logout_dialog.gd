extends CanvasLayer
## The logout dialog of a season (09 §5.1 Nr. 5, ST1-G; modal layer 61 — above the pause menu): what happens where the
## figure lies (SleepResolver.logout_info through Game.season_logout_info — a safe room: "sicher, Sie werden
## ausgeruht"; a corridor: its danger, up to three encounters, the next safe room, Ohne Netz "Hier können Sie
## sterben."; Am Stück: always safe), the sleeping tactic in a corridor ([Vorsichtig] default, [Unterstützen],
## [Angriff]), a Sendepause in whole days (private calendar seasons, the rest of the 14 days), and at the first logout
## the opt-in of the notices ("Sollen wir Sie vor dem Einsturz wecken?", off unless ticked — 09 §2.9). "Hier schlafen"
## → Game.season_logout → the title; "Zurück" closes. Usage: load the scene, setup({"context": "explore" |
## "safe_room", "capture": bool, "info": {…} (captures: the words to show)}), add it anywhere; `closed(bool)` tells
## whether the figure sleeps now. process_mode ALWAYS (opened from the paused pause menu too). No class_name.

signal closed(slept: bool)

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const UiIcon := preload("res://scenes/ui/ui_icon.gd")
const TACTICS: Array[Dictionary] = [
	{"id": "careful", "label": "Vorsichtig", "text": "flieht am ehesten und nutzt Tränke"},
	{"id": "support", "label": "Unterstützen", "text": "hält die andere Figur am Leben"},
	{"id": "attack", "label": "Angriff", "text": "macht eine Streife am schnellsten fertig"},
]
const DAY: int = 86400

var answered: bool = false
var tactic: String = "careful"
var pause_days: int = 0
var notify: bool = false

var _params: Dictionary = {}
var _info: Dictionary = {}
var _days_left: int = 0
var _ask_notify: bool = false
var _root: Control
var _panel: PanelContainer
var _tactic_buttons: Dictionary = {}       # id → Button
var _tactic_text: Label
var _pause_label: Label
var _notify_box: CheckButton
var _sleep: Button
var _back: Button
var _error: Label


func setup(params: Dictionary) -> void:
	_params = params


func _init() -> void:
	layer = 61
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_info = _params.get("info", {}) if _params.get("info", null) is Dictionary else {}
	if _info.is_empty():
		_info = Game.season_logout_info()
	_days_left = int(_params.get("pause_days_left", Game.season_pause_days_left()))
	_ask_notify = bool(_params.get("ask_notify", not Game.settings.notify_asked))
	notify = Game.settings.notify_collapse
	var last: String = Game.state.season.sleep_tactic if Game.state != null and Game.state.season != null else ""
	tactic = last if RtVocab.RT_PRESETS.has(last) else "careful"
	_build()
	_select_tactic(tactic)
	_set_pause(0)
	UiUtil.focus_later(_sleep)
	UiUtil.slide_in(_panel)


func _unhandled_input(event: InputEvent) -> void:
	if answered:
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		Sfx.play_ui(&"ui_cancel")
		cancel()


## "Hier schlafen": the opt-in is kept, the logout recorded, the title follows. A refused logout (a combat started, the
## season ended meanwhile) leaves the dialog open with a line.
func confirm() -> void:
	if answered:
		return
	if _ask_notify:
		Game.settings.notify_asked = true
		Game.settings.notify_collapse = notify
		Game.settings.save_to_disk()
	if bool(_params.get("capture", false)):
		return
	if not Game.season_logout(tactic, Game.season_cell(), pause_days * DAY):
		_error.text = "Ausloggen geht gerade nicht."
		return
	answered = true
	closed.emit(true)
	if get_tree().paused:
		get_tree().paused = false
	Events.pause_menu_toggled.emit(false)
	Router.goto(Router.SCENE_TITLE)
	queue_free()


func cancel() -> void:
	if answered:
		return
	answered = true
	closed.emit(false)
	queue_free()


func sleep_button() -> Button:
	return _sleep


func back_button() -> Button:
	return _back


## The tactic of the night (a corridor only).
func _select_tactic(id: String) -> void:
	tactic = id
	for t: Dictionary in TACTICS:
		var b: Button = _tactic_buttons.get(str(t["id"])) as Button
		if b != null:
			b.button_pressed = str(t["id"]) == id
		if str(t["id"]) == id and _tactic_text != null:
			_tactic_text.text = UiUtil.glyph_safe("%s: %s." % [str(t["label"]), str(t["text"])])


func _set_pause(days: int) -> void:
	pause_days = clampi(days, 0, _days_left)
	if _pause_label != null:
		_pause_label.text = "keine" if pause_days == 0 else ("1 Tag" if pause_days == 1 else "%d Tage" % pause_days)


func _build() -> void:
	_root = Control.new()
	_root.name = "Root"
	UiUtil.full_rect(_root)
	UiUtil.apply_theme(_root)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var dim: ColorRect = ColorRect.new()
	UiUtil.full_rect(dim)
	dim.color = Color(0.03, 0.02, 0.06, 0.72)
	_root.add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	UiUtil.full_rect(center)
	_root.add_child(center)
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.custom_minimum_size = Vector2(900, 0)
	var risk: String = str(_info.get("risk", ""))
	var sb: StyleBoxFlat = UiUtil.box_style(UiTheme.C_PANEL, UiTheme.C_DANGER if risk != "" else UiTheme.C_ACCENT_2, 3,
		0.0, 28, 16)
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 10
	_panel.add_theme_stylebox_override("panel", sb)
	center.add_child(_panel)
	var col: VBoxContainer = UiUtil.vbox(10)
	_panel.add_child(col)
	var head: HBoxContainer = UiUtil.hbox(10)
	col.add_child(head)
	var icon: Control = UiIcon.make(&"door", UiTheme.C_ACCENT_2, 30)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(icon)
	head.add_child(UiUtil.label("AUSLOGGEN", &"LabelHeader"))
	head.add_child(UiUtil.spacer(0, 0, true))
	var kind: String = str(_info.get("kind", "corridor"))
	var tag: Label = UiUtil.label({"safe": "SAFE ROOM", "boss": "BOSSRAUM", "stairs": "TREPPE", "binge": "AM STÜCK"}
		.get(kind, "IM GANG"), &"", 16, UiTheme.C_OK if kind != "corridor" else UiTheme.C_GOLD)
	tag.add_theme_font_override("font", UiTheme.font_bold())
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(tag)
	col.add_child(_text(str(_info.get("head", "")), 22, UiTheme.C_TEXT))
	for l: Variant in (_info.get("lines", []) as Array):
		if str(l) != "":
			col.add_child(_text("• " + str(l), 18, UiTheme.C_TEXT_DIM))
	if risk != "":
		var r: Label = _text(risk, 22, UiTheme.C_DANGER)
		r.add_theme_font_override("font", UiTheme.font_bold())
		col.add_child(r)
	if bool(_info.get("tactics", false)):
		col.add_child(UiUtil.spacer(2))
		col.add_child(_text("Ihre Figur schläft:", 18, UiTheme.C_TEXT))
		var row: HBoxContainer = UiUtil.hbox(12)
		col.add_child(row)
		var list: Array[Control] = []
		for t: Dictionary in TACTICS:
			var id: String = str(t["id"])
			var b: Button = UiUtil.button(str(t["label"]), &"")
			b.name = "Tactic_" + id
			b.toggle_mode = true
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			UiUtil.touch_pad(b, 56.0)
			b.pressed.connect(func() -> void: _select_tactic(id))
			row.add_child(b)
			_tactic_buttons[id] = b
			list.append(b)
		UiUtil.wire_horizontal(list)
		_tactic_text = _text("", 17, UiTheme.C_ACCENT_2)
		col.add_child(_tactic_text)
	if _days_left > 0:
		var prow: HBoxContainer = UiUtil.hbox(10)
		col.add_child(prow)
		var pl: Label = UiUtil.label("Sendepause:", &"", 18)
		pl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		prow.add_child(pl)
		var minus: Button = UiUtil.button("−", &"")
		minus.name = "PauseLess"
		UiUtil.touch_pad(minus, 48.0)
		minus.pressed.connect(func() -> void: _set_pause(pause_days - 1))
		prow.add_child(minus)
		_pause_label = UiUtil.label("", &"", 20, UiTheme.C_GOLD)
		_pause_label.custom_minimum_size = Vector2(90, 0)
		_pause_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_pause_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		prow.add_child(_pause_label)
		var plus: Button = UiUtil.button("+", &"")
		plus.name = "PauseMore"
		UiUtil.touch_pad(plus, 48.0)
		plus.pressed.connect(func() -> void: _set_pause(pause_days + 1))
		prow.add_child(plus)
		var pt: Label = UiUtil.label(UiUtil.glyph_safe("Die Uhr steht, alle Termine rücken mit (noch %d Tage)." %
			_days_left), &"LabelSmall", 15)
		pt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		prow.add_child(pt)
	if _ask_notify:
		_notify_box = CheckButton.new()
		_notify_box.name = "Notify"
		_notify_box.text = "Sollen wir Sie vor dem Einsturz wecken?"
		_notify_box.button_pressed = notify
		_notify_box.add_theme_font_size_override("font_size", 18)
		_notify_box.toggled.connect(func(on: bool) -> void: notify = on)
		col.add_child(_notify_box)
		col.add_child(_text("Höchstens drei Hinweise am Tag, nie zwischen 22 und 8 Uhr. Jederzeit in den Optionen " +
			"abschaltbar.", 15, UiTheme.C_TEXT_DIM))
	_error = UiUtil.label("", &"", 16, UiTheme.C_DANGER)
	col.add_child(_error)
	var brow: HBoxContainer = UiUtil.hbox(16)
	brow.alignment = BoxContainer.ALIGNMENT_END
	col.add_child(brow)
	_back = UiUtil.button("Zurück", &"ButtonBig")
	_back.name = "Back"
	_back.custom_minimum_size = Vector2(220, 72)
	_back.pressed.connect(cancel)
	brow.add_child(_back)
	_sleep = UiUtil.button("Hier schlafen", &"ButtonBig")
	_sleep.name = "Sleep"
	_sleep.custom_minimum_size = Vector2(260, 72)
	_sleep.pressed.connect(confirm)
	brow.add_child(_sleep)
	UiUtil.wire_horizontal([_back, _sleep] as Array[Control])


func _text(text: String, size: int, color: Color) -> Label:
	var l: Label = UiUtil.label(UiUtil.glyph_safe(text), &"", size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(840, 0)
	return l
