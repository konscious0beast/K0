extends Control
## Settings (02_TECH §1.6, §3.4 GameSettings; GDD §14.4 "Optionen"): volumes, battle/text speed, auto battle, camera,
## fullscreen (PC), quality, touch controls, FPS, mode (Prime Time → Vorabendprogramm only, Game.set_difficulty),
## language. Every change: Game.settings field → save_to_disk() → Game.apply_settings() (emits settings_changed).
## setup({"framed": true}) = modal with panel + "Zurück" (title screen); embedded (pause tab) = rows only.

signal closed()

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const CONFIRM: String = "res://scenes/ui/confirm_dialog.tscn"


## Option button: "‹ value ›"; ui_left/ui_right (and press) cycle the options.
class Cycler extends Button:
	signal changed(index: int)
	var options: PackedStringArray = []
	var index: int = 0

	func _init() -> void:
		focus_mode = Control.FOCUS_ALL
		custom_minimum_size = Vector2(260, 44)
		pressed.connect(func() -> void: step(1))

	func set_options(opts: PackedStringArray, idx: int) -> void:
		options = opts
		index = clampi(idx, 0, maxi(opts.size() - 1, 0))
		_update()

	func step(d: int) -> void:
		if options.size() < 2 or disabled:
			return
		index = posmod(index + d, options.size())
		_update()
		Sfx.play_ui(&"ui_move")
		changed.emit(index)

	func _gui_input(event: InputEvent) -> void:
		if event.is_action_pressed(&"ui_left"):
			step(-1)
			accept_event()
		elif event.is_action_pressed(&"ui_right"):
			step(1)
			accept_event()

	func _update() -> void:
		text = "‹  %s  ›" % (options[index] if index < options.size() else "")


var rows: Dictionary = {}          # key → control (tests)

var _params: Dictionary = {}
var _framed: bool = true
var _list: VBoxContainer
var _scroll: ScrollContainer
var _back: Button
var _first: Control = null
var _controls: Array[Control] = []


## {"framed": bool (default true standalone), "capture": bool}
func setup(params: Dictionary) -> void:
	_params = params


func _ready() -> void:
	UiUtil.full_rect(self)
	_framed = bool(_params.get("framed", get_parent() == get_tree().root or _params.has("capture")))
	if _framed:
		UiUtil.apply_theme(self)
	_build()
	if _framed:
		focus_default()


func focus_default() -> void:
	if _first != null:
		UiUtil.focus_later(_first)


func _unhandled_input(event: InputEvent) -> void:
	if not _framed or not is_visible_in_tree():
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	Sfx.play_ui(&"ui_cancel")
	closed.emit()
	if _framed:
		queue_free()


# --- build -----------------------------------------------------------------------------------------------------------

func _build() -> void:
	var host: Control = self
	if _framed:
		var dim: ColorRect = ColorRect.new()
		UiUtil.full_rect(dim)
		dim.color = Color(0.03, 0.02, 0.06, 0.78)
		add_child(dim)
		var center: CenterContainer = CenterContainer.new()
		UiUtil.full_rect(center)
		add_child(center)
		var panel: PanelContainer = UiUtil.panel(&"PanelMenu")
		panel.custom_minimum_size = Vector2(780, 600)
		center.add_child(panel)
		var outer: VBoxContainer = UiUtil.vbox(10)
		panel.add_child(outer)
		var head: HBoxContainer = UiUtil.hbox(12)
		outer.add_child(head)
		head.add_child(UiUtil.label("OPTIONEN", &"LabelHeader"))
		head.add_child(UiUtil.spacer(0, 0, true))
		head.add_child(InputGlyph.make(&"ui_cancel", "Zurück", 16))
		host = outer
	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	_scroll.follow_focus = true
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not _framed:
		UiUtil.full_rect(_scroll)
	host.add_child(_scroll)
	_list = UiUtil.vbox(6)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	var s: GameSettings = Game.settings
	_section("Audio")
	_slider("master_volume", "Gesamtlautstärke", s.master_volume)
	_slider("music_volume", "Musik", s.music_volume)
	_slider("sfx_volume", "Effekte & Menü", s.sfx_volume)
	_section("Spiel")
	_cycler("battle_speed", "Kampftempo", ["× 1", "× 2"], 1 if s.battle_speed >= 1.5 else 0)
	_cycler("text_speed", "Textgeschwindigkeit", ["Langsam", "Normal", "Sofort"], s.text_speed)
	_cycler("auto_battle_default", "Auto-Kampf (Standard)", ["Aus", "An"], 1 if s.auto_battle_default else 0)
	_mode_row()
	_section("Kamera & Steuerung")
	_slider("camera_sensitivity", "Kamera-Empfindlichkeit", inverse_lerp(0.25, 3.0, s.camera_sensitivity))
	_cycler("camera_invert_x", "Kamera horizontal invertieren", ["Aus", "An"], 1 if s.camera_invert_x else 0)
	_cycler("camera_invert_y", "Kamera vertikal invertieren", ["Aus", "An"], 1 if s.camera_invert_y else 0)
	_cycler("touch_controls", "Touch-Steuerung", ["Automatisch", "An", "Aus"],
		["auto", "on", "off"].find(String(s.touch_controls)))
	_section("Anzeige")
	if not UiUtil.is_mobile():
		_cycler("fullscreen", "Vollbild", ["Aus", "An"], 1 if s.fullscreen else 0)
	_cycler("quality", "Grafikqualität", ["Hoch", "Niedrig"], 0 if s.quality == &"high" else 1)
	_cycler("show_fps", "FPS anzeigen", ["Aus", "An"], 1 if s.show_fps else 0)
	var lang: Cycler = _cycler("language", "Sprache", ["Deutsch"], 0)
	lang.disabled = true
	lang.text = "Deutsch"
	UiUtil.wire_vertical(_controls)
	if _framed:
		_back = UiUtil.button("Zurück", &"ButtonBig")
		_back.custom_minimum_size = Vector2(240, 64)
		_back.size_flags_horizontal = Control.SIZE_SHRINK_END
		_back.pressed.connect(close)
		host.add_child(_back)
		_controls.append(_back)
		UiUtil.wire_vertical(_controls)


func _section(title: String) -> void:
	var l: Label = UiUtil.label(title.to_upper(), &"", 15, UiTheme.C_ACCENT)
	l.add_theme_font_override("font", UiTheme.font_bold())
	if _list.get_child_count() > 0:
		_list.add_child(UiUtil.spacer(6))
	_list.add_child(l)


func _row(label_text: String) -> HBoxContainer:
	var row: HBoxContainer = UiUtil.hbox(16)
	row.custom_minimum_size = Vector2(0, 46)
	_list.add_child(row)
	var l: Label = UiUtil.label(label_text, &"", 20)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	return row


func _register(key: String, c: Control) -> void:
	rows[key] = c
	_controls.append(c)
	if _first == null:
		_first = c


func _slider(key: String, label_text: String, value01: float) -> HSlider:
	var row: HBoxContainer = _row(label_text)
	var sl: HSlider = HSlider.new()
	sl.min_value = 0
	sl.max_value = 100
	sl.step = 5
	sl.value = roundf(clampf(value01, 0.0, 1.0) * 100.0)
	sl.custom_minimum_size = Vector2(220, 32)
	sl.focus_mode = Control.FOCUS_ALL
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(sl)
	var v: Label = UiUtil.label("%d %%" % int(sl.value), &"", 18)
	v.custom_minimum_size = Vector2(64, 0)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_theme_font_override("font", UiTheme.font_mono())
	row.add_child(v)
	if key == "camera_sensitivity":
		v.text = "%.2f×" % lerpf(0.25, 3.0, sl.value / 100.0)
	sl.value_changed.connect(func(val: float) -> void:
		_set_slider(key, val / 100.0)
		v.text = ("%.2f×" % lerpf(0.25, 3.0, val / 100.0)) if key == "camera_sensitivity" else "%d %%" % int(val))
	_register(key, sl)
	return sl


func _cycler(key: String, label_text: String, options: Array, idx: int) -> Cycler:
	var row: HBoxContainer = _row(label_text)
	var c: Cycler = Cycler.new()
	var opts: PackedStringArray = []
	for o: Variant in options:
		opts.append(str(o))
	c.set_options(opts, maxi(idx, 0))
	row.add_child(c)
	c.changed.connect(func(i: int) -> void: _set_choice(key, i))
	_register(key, c)
	return c


func _mode_row() -> void:
	if Game.state == null:
		return
	var row: HBoxContainer = _row("Modus")
	var b: Button = UiUtil.button("", &"", 44)
	b.custom_minimum_size = Vector2(320, 44)
	b.add_theme_font_size_override("font_size", 18)
	b.clip_text = false
	row.add_child(b)
	_update_mode_button(b)
	b.pressed.connect(func() -> void: _ask_lower_mode(b))
	_register("difficulty", b)


func _update_mode_button(b: Button) -> void:
	var easy: bool = Game.state != null and Game.state.difficulty == &"vorabend"
	b.text = "Vorabendprogramm" if easy else "Prime Time · senken …"
	b.disabled = easy or Game.state == null


func _ask_lower_mode(b: Button) -> void:
	if not ResourceLoader.exists(CONFIRM):
		return
	var d: Node = (load(CONFIRM) as PackedScene).instantiate()
	d.call("setup", {"title": "Modus senken", "text": "Auf „Vorabendprogramm“ wechseln? Mehr Zeit (×1,5), weniger " +
		"Schaden, mehr EXP. Das lässt sich nicht rückgängig machen.", "yes": "Senken", "no": "Abbrechen",
		"default_no": true})
	d.process_mode = process_mode if process_mode != Node.PROCESS_MODE_INHERIT else Node.PROCESS_MODE_ALWAYS
	if get_tree().paused:
		d.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	d.connect("closed", func(yes: bool) -> void:
		if yes:
			Game.set_difficulty(&"vorabend")
		_update_mode_button(b)
		if is_instance_valid(b):
			UiUtil.focus_later(b))
	add_child(d)


# --- apply -----------------------------------------------------------------------------------------------------------

func _set_slider(key: String, v01: float) -> void:
	var s: GameSettings = Game.settings
	match key:
		"master_volume":
			s.master_volume = v01
		"music_volume":
			s.music_volume = v01
		"sfx_volume":
			s.sfx_volume = v01
			Sfx.play_ui(&"ui_move")
		"camera_sensitivity":
			s.camera_sensitivity = lerpf(0.25, 3.0, v01)
	_commit()


func _set_choice(key: String, i: int) -> void:
	var s: GameSettings = Game.settings
	match key:
		"battle_speed":
			s.battle_speed = 2.0 if i == 1 else 1.0
		"text_speed":
			s.text_speed = clampi(i, 0, 2)
		"auto_battle_default":
			s.auto_battle_default = i == 1
			Game.auto_battle = s.auto_battle_default
		"camera_invert_x":
			s.camera_invert_x = i == 1
		"camera_invert_y":
			s.camera_invert_y = i == 1
		"touch_controls":
			s.touch_controls = [&"auto", &"on", &"off"][clampi(i, 0, 2)]
		"fullscreen":
			s.fullscreen = i == 1
		"quality":
			s.quality = &"high" if i == 0 else &"low"
		"show_fps":
			s.show_fps = i == 1
	_commit()


func _commit() -> void:
	Game.settings.save_to_disk()
	Game.apply_settings()
