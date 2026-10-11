extends Control
## Game over "Sendeschluss" (GDD §14.6, 03_ART §7.2): colour-bar test card (0→1 in 0.2 s), M.O.D. `death` or
## `timer_expired` line, statistics from FloorRun (time, kills, viewer peak); buttons after 1.5 s: "Letzten
## Spielstand laden" (grace time 3:00, only with a saved slot) · "Zum Titel"; event runs: "Auswertung" first.
## Params {"reason": &"defeat" | &"timer"}. Save.record_game_over already ran in Game.on_game_over (Router.game_over).
## The buttons stay disabled (and unfocused) until BUTTONS_AFTER, so a confirm press carried over from the lost battle
## cannot fire them before the screen was seen; {"capture": true} skips the delay.

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const UiIcon := preload("res://scenes/ui/ui_icon.gd")
const TitleFlow := preload("res://scenes/title/title_flow.gd")
const TEST_CARD_SHADER: String = "res://scenes/title/test_card.gdshader"
const RUN_RESULT: String = "res://scenes/ui/run_result.tscn"
const CARD_IN: float = 0.2
const BUTTONS_AFTER: float = 1.5

var reason: StringName = &"defeat"
var buttons: Dictionary = {}               # id → Button

var _params: Dictionary = {}
var _card: ColorRect
var _panel: PanelContainer
var _button_row: HBoxContainer
var _busy: bool = false
var _ready_for_input: bool = false


## Capture still (fresh ephemeral state): sample statistics of a lost run.
const CAPTURE_STATS: Dictionary = {"time_used_sec": 11 * 60 + 47, "kills": 14, "viewers_peak": 4380}


func setup(params: Dictionary) -> void:
	_params = params
	reason = StringName(str(params.get("reason", "defeat")))


func _ready() -> void:
	UiUtil.full_rect(self)
	Events.overlay_mode_requested.emit.call_deferred(&"game_over")
	Sfx.music(&"game_over")
	_build()
	if is_inside_tree() and not bool(_params.get("capture", false)):
		var mat: ShaderMaterial = _card.material as ShaderMaterial
		if mat != null:
			mat.set_shader_parameter("test_card", 0.0)
			create_tween().tween_method(func(v: float) -> void: mat.set_shader_parameter("test_card", v), 0.0, 1.0,
				CARD_IN)
		_panel.modulate.a = 0.0
		_button_row.modulate.a = 0.0
		_set_buttons_enabled(false)
		var tw: Tween = create_tween()
		tw.tween_interval(0.5)
		tw.tween_property(_panel, "modulate:a", 1.0, 0.3)
		tw.tween_interval(maxf(0.0, BUTTONS_AFTER - 0.8))
		tw.tween_callback(_enable_buttons)
		tw.tween_property(_button_row, "modulate:a", 1.0, 0.25)
	else:
		_enable_buttons()


## True once the buttons accept input (after BUTTONS_AFTER).
func buttons_ready() -> bool:
	return _ready_for_input


func load_last() -> void:
	if _busy or Game.state == null:
		return
	var slot: int = Game.state.slot
	if slot <= 0 or not Save.has_save(slot):
		return
	var err: Error = TitleFlow.load_and_route(slot)
	if err == OK:
		_busy = true
	else:
		Sfx.play_ui(&"ui_error")
		Events.toast_requested.emit(TitleFlow.load_error_text(err), &"warning")


func to_title() -> void:
	if _busy:
		return
	_busy = true
	Router.goto(Router.SCENE_TITLE)


func to_result() -> void:
	if _busy:
		return
	_busy = true
	Router.goto(RUN_RESULT)


func can_load() -> bool:
	return Game.state != null and Game.state.slot > 0 and Save.has_save(Game.state.slot)


func _set_buttons_enabled(on: bool) -> void:
	for id: Variant in buttons.keys():
		(buttons[id] as Button).disabled = not on


func _enable_buttons() -> void:
	_ready_for_input = true
	_set_buttons_enabled(true)
	if buttons.has("load"):
		(buttons["load"] as Button).disabled = not can_load()
	UiUtil.focus_later(_first_button())


func _first_button() -> Button:
	for id: String in ["result", "load", "title"]:
		if buttons.has(id) and not (buttons[id] as Button).disabled:
			return buttons[id]
	return buttons["title"]


func _build() -> void:
	var bg: ColorRect = ColorRect.new()
	UiUtil.full_rect(bg)
	bg.color = UiUtil.C_INK
	add_child(bg)
	_card = ColorRect.new()
	UiUtil.full_rect(_card)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(TEST_CARD_SHADER):
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = load(TEST_CARD_SHADER) as Shader
		mat.set_shader_parameter("test_card", 1.0)
		_card.material = mat
	add_child(_card)
	var center: CenterContainer = CenterContainer.new()
	UiUtil.full_rect(center)
	add_child(center)
	var col: VBoxContainer = UiUtil.vbox(14)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(col)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(760, 0)
	_panel.add_theme_stylebox_override("panel", UiUtil.box_style(Color(UiUtil.C_INK, 0.92), UiTheme.C_DANGER, 3, 0.0,
		32, 22))
	col.add_child(_panel)
	var inner: VBoxContainer = UiUtil.vbox(10)
	_panel.add_child(inner)
	var head: HBoxContainer = UiUtil.hbox(14)
	inner.add_child(head)
	head.add_child(UiIcon.make(&"tv", UiTheme.C_DANGER, 48))
	var hc: VBoxContainer = UiUtil.vbox(-4)
	head.add_child(hc)
	hc.add_child(UiUtil.label("SENDESCHLUSS", &"LabelTitle", 58, UiTheme.C_DANGER))
	var why: String = "Die Etage ist eingestürzt." if reason == &"timer" else "Die Party ist gefallen."
	hc.add_child(UiUtil.label(why, &"", 22, UiTheme.C_TEXT_DIM))
	var quote: String = UiUtil.mod_line("timer_expired" if reason == &"timer" else "death")
	if quote != "":
		var q: Label = UiUtil.label("M.O.D.: „%s“" % quote, &"", 20, UiTheme.C_ACCENT_2)
		q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		inner.add_child(q)
	var summary: Dictionary = Game.state.floor_run.summary() if Game.state != null and Game.state.floor_run != null \
		else {}
	if bool(_params.get("capture", false)) and int(summary.get("time_used_sec", 0)) == 0:
		summary = CAPTURE_STATS.duplicate()     # standalone still of a fresh state: sample numbers, not 00:00 / 0 / 0
	var stats: HBoxContainer = UiUtil.hbox(28)
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_child(stats)
	for s: Array in [[&"clock", "Zeit", UiUtil.fmt_time(int(summary.get("time_used_sec", 0)))],
			[&"skull", "Kills", UiUtil.fmt_int(int(summary.get("kills", 0)))],
			[&"eye", "Zuschauer-Spitze", UiUtil.fmt_int(int(summary.get("viewers_peak", 0)))]]:
		var box: VBoxContainer = UiUtil.vbox(0)
		var r: HBoxContainer = UiUtil.hbox(8)
		r.alignment = BoxContainer.ALIGNMENT_CENTER
		r.add_child(UiIcon.make(s[0] as StringName, UiTheme.C_TEXT_DIM, 20))
		r.add_child(UiUtil.label(str(s[1]), &"LabelSmall", 16))
		box.add_child(r)
		var v: Label = UiUtil.label(str(s[2]), &"", 30)
		v.add_theme_font_override("font", UiTheme.font_mono())
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(v)
		stats.add_child(box)
	inner.add_child(UiUtil.spacer(6))
	_button_row = UiUtil.hbox(16)
	_button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_child(_button_row)
	var list: Array[Control] = []
	if Game.mode == &"event_offline":
		var rb: Button = _button("result", "Auswertung", to_result)
		list.append(rb)
	else:
		var lb: Button = _button("load", "Letzten Spielstand laden", load_last)
		lb.disabled = not can_load()
		if lb.disabled:
			lb.tooltip_text = "Kein gespeicherter Spielstand in diesem Slot."
		list.append(lb)
	list.append(_button("title", "Zum Titel", to_title))
	UiUtil.wire_horizontal(list)
	if not (Game.mode == &"event_offline"):
		var load_ok: bool = not (buttons["load"] as Button).disabled
		var note: Label = UiUtil.label("Beim Laden gibt es mindestens 3:00 Gnadenfrist." if load_ok
			else "Kein gespeicherter Spielstand in diesem Slot.", &"LabelSmall", 15)
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		inner.add_child(note)


func _button(id: String, text: String, cb: Callable) -> Button:
	var b: Button = UiUtil.button(text, &"ButtonBig")
	b.name = "Btn_" + id
	b.custom_minimum_size = Vector2(320, 0)
	UiUtil.touch_pad(b, 72.0)
	b.pressed.connect(cb)
	_button_row.add_child(b)
	buttons[id] = b
	return b
