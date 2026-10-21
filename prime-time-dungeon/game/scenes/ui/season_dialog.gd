extends CanvasLayer
## A modal of the season UI (09 ST1-H; layer 61 — above the pause menu, like the logout dialog): a title, a few lines
## (one sentence each, 09 §0.5), an optional day counter (−/+, the Sendepause) and two or three buttons — "Staffel
## beenden" with its clear confirmation (danger), the tempo offer after the class choice ("Weiter im Kalender" / "Am
## Stück"), the Sendepause of the pause tab, the hire of a Helfer:in, "Ohne Netz" at the start. Every button is a 64 px
## box in an 88 px hit area (02_TECH §10.2 rule 5), 16 px apart; Esc / B / the pause key answer with `cancel_id`.
## Usage: load the scene, setup({"title", "kicker", "lines": [String], "danger": bool, "buttons": [{"id", "text",
## "danger"}], "focus": id, "cancel_id": id, "days": {"max", "value"}}), add it anywhere; `closed(id, days)` answers
## once, then the dialog frees itself. process_mode ALWAYS (the pause menu has the tree paused). No class_name.

signal closed(id: String, days: int)

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const UiIcon := preload("res://scenes/ui/ui_icon.gd")
const PANEL_W: float = 760.0
const BUTTON_W: float = 250.0

var answered: bool = false
var days: int = 0

var _params: Dictionary = {}
var _root: Control
var _panel: PanelContainer
var _buttons: Dictionary = {}              # id → Button
var _days_label: Label = null
var _days_less: Button = null
var _days_more: Button = null


func setup(params: Dictionary) -> void:
	_params = params


func _init() -> void:
	layer = 61
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	var d: Dictionary = _params.get("days", {}) if _params.get("days", null) is Dictionary else {}
	days = clampi(int(d.get("value", 1)), 0, int(d.get("max", 0))) if not d.is_empty() else 0
	_build()
	var focus: String = str(_params.get("focus", ""))
	var target: Button = _buttons.get(focus) as Button
	if target == null and not _buttons.is_empty():
		target = _buttons.values()[0] as Button
	UiUtil.focus_later(target)
	UiUtil.slide_in(_panel)


func _unhandled_input(event: InputEvent) -> void:
	if answered:
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		Sfx.play_ui(&"ui_cancel")
		answer(str(_params.get("cancel_id", "")))


## Answers with button `id` ("" = cancelled) and the day count; frees the dialog.
func answer(id: String) -> void:
	if answered:
		return
	answered = true
	closed.emit(id, days)
	queue_free()


func button(id: String) -> Button:
	return _buttons.get(id) as Button


func panel() -> Control:
	return _panel


func _set_days(n: int) -> void:
	var d: Dictionary = _params.get("days", {}) as Dictionary
	days = clampi(n, 1, maxi(1, int(d.get("max", 1))))
	if _days_label != null:
		_days_label.text = "1 Tag" if days == 1 else "%d Tage" % days


func _build() -> void:
	_root = Control.new()
	_root.name = "Root"
	UiUtil.full_rect(_root)
	UiUtil.apply_theme(_root)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var dim: ColorRect = ColorRect.new()
	UiUtil.full_rect(dim)
	dim.color = Color(0.03, 0.02, 0.06, 0.74)
	_root.add_child(dim)
	var safe: SafeAreaContainer = SafeAreaContainer.new()
	safe.extra = 8
	_root.add_child(safe)
	var center: CenterContainer = CenterContainer.new()
	safe.add_child(center)
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.custom_minimum_size = Vector2(PANEL_W, 0)
	var danger: bool = bool(_params.get("danger", false))
	var sb: StyleBoxFlat = UiUtil.box_style(UiTheme.C_PANEL, UiTheme.C_DANGER if danger else UiTheme.C_ACCENT_2, 3, 0.0,
		28, 18)
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 10
	_panel.add_theme_stylebox_override("panel", sb)
	center.add_child(_panel)
	var col: VBoxContainer = UiUtil.vbox(10)
	_panel.add_child(col)
	var kicker: String = str(_params.get("kicker", ""))
	if kicker != "":
		var k: Label = UiUtil.label(UiUtil.glyph_safe(kicker), &"", 16, UiTheme.C_ACCENT)
		k.add_theme_font_override("font", UiTheme.font_bold())
		col.add_child(k)
	var head: HBoxContainer = UiUtil.hbox(10)
	col.add_child(head)
	var ic: Control = UiIcon.make(&"tv", UiTheme.C_DANGER if danger else UiTheme.C_ACCENT_2, 30)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(ic)
	var t: Label = UiUtil.label(UiUtil.glyph_safe(str(_params.get("title", ""))), &"LabelHeader", 28)
	t.name = "Title"
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(PANEL_W - 110.0, 0)
	head.add_child(t)
	var first: bool = true
	for l: Variant in (_params.get("lines", []) as Array):
		var line: Label = UiUtil.label(UiUtil.glyph_safe(str(l)), &"", 21 if first else 18,
			UiTheme.C_TEXT if first else UiTheme.C_TEXT_DIM)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.custom_minimum_size = Vector2(PANEL_W - 56.0, 0)
		col.add_child(line)
		first = false
	if _params.get("days", null) is Dictionary and int((_params["days"] as Dictionary).get("max", 0)) > 0:
		col.add_child(_days_row())
	col.add_child(UiUtil.spacer(4))
	var row: HBoxContainer = UiUtil.hbox(16)
	row.name = "Buttons"
	row.alignment = BoxContainer.ALIGNMENT_END
	col.add_child(row)
	var list: Array[Control] = []
	for b: Variant in (_params.get("buttons", []) as Array):
		var bd: Dictionary = b
		var id: String = str(bd.get("id", ""))
		var btn: Button = UiUtil.button(UiUtil.glyph_safe(str(bd.get("text", id))), &"ButtonBig")
		btn.name = "Btn_" + id
		btn.custom_minimum_size = Vector2(BUTTON_W, 0)
		if bool(bd.get("danger", false)):
			var red: StyleBoxFlat = UiUtil.box_style(Color(UiTheme.C_DANGER, 0.25), UiTheme.C_DANGER, 2, 0.0, 24, 20)
			btn.add_theme_stylebox_override("normal", red)
		UiUtil.touch_pad(btn, 64.0)
		btn.pressed.connect(func() -> void: answer(id))
		row.add_child(btn)
		_buttons[id] = btn
		list.append(btn)
	UiUtil.wire_horizontal(list)
	for c: Control in list:
		c.focus_neighbor_top = c.get_path_to(c if _days_less == null else _days_less)
		c.focus_neighbor_bottom = c.get_path_to(c)
	if _days_less != null and not list.is_empty():
		for c2: Control in [_days_less, _days_more]:
			c2.focus_neighbor_bottom = c2.get_path_to(list[list.size() - 1])
			c2.focus_neighbor_top = c2.get_path_to(c2)


## The day counter of a Sendepause: − n Tage +.
func _days_row() -> HBoxContainer:
	var prow: HBoxContainer = UiUtil.hbox(12)
	prow.name = "Days"
	var pl: Label = UiUtil.label("Sendepause:", &"", 20)
	pl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	prow.add_child(pl)
	var minus: Button = UiUtil.button("−", &"")
	minus.name = "DaysLess"
	minus.custom_minimum_size = Vector2(UiTheme.TOUCH_HIT, 0)
	UiUtil.touch_pad(minus, 64.0)
	minus.pressed.connect(func() -> void: _set_days(days - 1))
	prow.add_child(minus)
	_days_label = UiUtil.label("", &"", 22, UiTheme.C_GOLD)
	_days_label.custom_minimum_size = Vector2(110, 0)
	_days_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_days_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	prow.add_child(_days_label)
	var plus: Button = UiUtil.button("+", &"")
	plus.name = "DaysMore"
	plus.custom_minimum_size = Vector2(UiTheme.TOUCH_HIT, 0)
	UiUtil.touch_pad(plus, 64.0)
	plus.pressed.connect(func() -> void: _set_days(days + 1))
	prow.add_child(plus)
	_days_less = minus
	_days_more = plus
	UiUtil.wire_horizontal([minus, plus] as Array[Control], false)
	_set_days(days)
	return prow
