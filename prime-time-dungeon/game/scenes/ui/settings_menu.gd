extends Control
## Settings (02_TECH §1.6, §3.4 GameSettings; GDD §14.4 "Optionen"): volumes, battle/text speed, auto battle, camera,
## fullscreen (PC), quality, touch controls, FPS, mode (Prime Time → Vorabendprogramm only, Game.set_difficulty),
## language. Every change applies live (Game.apply_settings(), emits settings_changed); writing user://settings.cfg
## happens once per change for cyclers and only at the end of a slider drag / when the menu closes (no disk write per
## slider step). setup({"framed": true}) = modal with panel + "Zurück" (title screen); embedded (pause tab) = rows only.
## Rows are 88 px hit areas (64 px visible, 02_TECH §10.2 rule 5) 12 px apart; a focused row shows the pulsing arrow
## on the left, slider rows additionally the 3 px cyan focus frame (Slider has no focus stylebox of its own).

signal closed()

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const InputGlyph := preload("res://scenes/ui/input_glyph.gd")
const UiIcon := preload("res://scenes/ui/ui_icon.gd")
const CONFIRM: String = "res://scenes/ui/confirm_dialog.tscn"
const ROW_H: float = 88.0                  # = UiTheme.TOUCH_HIT
const CAM_MIN: float = 0.25
const CAM_MAX: float = 3.0
const GRABBER_PX: int = 32
const SCROLLBAR_GUTTER: int = 20         # px between the rows and the scroll bar

static var _grabber: Texture2D = null


## Option button: "‹ value ›"; ui_left/ui_right (and press) cycle the options.
class Cycler extends Button:
	signal changed(index: int)
	var options: PackedStringArray = []
	var index: int = 0

	func _init() -> void:
		focus_mode = Control.FOCUS_ALL
		custom_minimum_size = Vector2(300, 0)
		UiUtil.touch_pad(self)
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
var _dirty: bool = false                   # settings changed but not yet written to disk
var _arrows: Array[Control] = []
var _t: float = 0.0


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


func _process(delta: float) -> void:
	_t += delta
	var a: float = 0.6 + 0.4 * (0.5 + 0.5 * sin(_t * TAU * 2.0))
	for arrow: Control in _arrows:
		if arrow.visible:
			arrow.modulate.a = a


func _unhandled_input(event: InputEvent) -> void:
	if not _framed or not is_visible_in_tree():
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		close()


func _exit_tree() -> void:
	flush()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		flush()


func close() -> void:
	Sfx.play_ui(&"ui_cancel")
	flush()
	closed.emit()
	if _framed:
		queue_free()


## Writes pending changes to user://settings.cfg (once; no-op if nothing changed).
func flush() -> void:
	if not _dirty or Game.settings == null:
		return
	_dirty = false
	Game.settings.save_to_disk()


func is_dirty() -> bool:
	return _dirty


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
	_list = UiUtil.vbox(12)                 # 12 px between the 88 px hit areas
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# rows end left of the scroll bar (the value labels / focus frame touched it; visual pass)
	var gutter: MarginContainer = MarginContainer.new()
	gutter.name = "Gutter"
	gutter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gutter.add_theme_constant_override("margin_right", SCROLLBAR_GUTTER)
	gutter.add_theme_constant_override("margin_left", 0)
	gutter.add_theme_constant_override("margin_top", 0)
	gutter.add_theme_constant_override("margin_bottom", 0)
	_scroll.add_child(gutter)
	gutter.add_child(_list)
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
	_camera_slider(s.camera_sensitivity)
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
	_list.add_child(UiUtil.spacer(8))
	UiUtil.wire_vertical(_controls)
	if _framed:
		_back = UiUtil.button("Zurück", &"ButtonBig")
		_back.custom_minimum_size = Vector2(240, 0)
		UiUtil.touch_pad(_back)
		_back.size_flags_horizontal = Control.SIZE_SHRINK_END
		_back.pressed.connect(close)
		host.add_child(_back)
		_controls.append(_back)
		UiUtil.wire_vertical(_controls)


func _section(title: String) -> void:
	var l: Label = UiUtil.label(title.to_upper(), &"", 16, UiTheme.C_ACCENT)
	l.add_theme_font_override("font", UiTheme.font_bold())
	if _list.get_child_count() > 0:
		_list.add_child(UiUtil.spacer(4))
	_list.add_child(l)


## Row = PanelContainer frame (focus frame for sliders) around: pulsing focus arrow · label · control.
func _row(label_text: String) -> HBoxContainer:
	var frame: PanelContainer = PanelContainer.new()
	frame.name = "Row"
	frame.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_list.add_child(frame)
	var row: HBoxContainer = UiUtil.hbox(14)
	row.custom_minimum_size = Vector2(0, ROW_H)
	frame.add_child(row)
	var arrow: Control = UiIcon.make(&"arrow_right", UiTheme.C_ACCENT_2, 18)
	arrow.name = "FocusArrow"
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	arrow.visible = false
	row.add_child(arrow)
	_arrows.append(arrow)
	var l: Label = UiUtil.label(label_text, &"", 20)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	return row


func _register(key: String, c: Control) -> void:
	rows[key] = c
	_controls.append(c)
	if _first == null:
		_first = c
	var row: Node = c.get_parent()
	var arrow: Control = row.get_node_or_null("FocusArrow") as Control
	var frame: PanelContainer = row.get_parent() as PanelContainer
	var framed_focus: bool = c is Range
	c.focus_entered.connect(func() -> void:
		if arrow != null:
			arrow.visible = true
		if framed_focus and frame != null:
			frame.add_theme_stylebox_override("panel", _row_focus_box()))
	c.focus_exited.connect(func() -> void:
		if arrow != null:
			arrow.visible = false
		if framed_focus and frame != null:
			frame.add_theme_stylebox_override("panel", StyleBoxEmpty.new()))


## 3 px NOVA_CYAN frame (UiTheme focus look) drawn around a focused slider row.
static func _row_focus_box() -> StyleBox:
	var sb: StyleBox = UiTheme.get_theme().get_stylebox("focus", "Button").duplicate() as StyleBox
	if sb is StyleBoxFlat:
		(sb as StyleBoxFlat).set_expand_margin_all(0.0)
		(sb as StyleBoxFlat).set_content_margin_all(0.0)
	return sb


func _slider(key: String, label_text: String, value01: float) -> HSlider:
	var row: HBoxContainer = _row(label_text)
	var sl: HSlider = _make_slider(0.0, 100.0, 5.0, roundf(clampf(value01, 0.0, 1.0) * 100.0))
	row.add_child(sl)
	var v: Label = _value_label("%d %%" % int(sl.value))
	row.add_child(v)
	sl.value_changed.connect(func(val: float) -> void:
		_set_slider(key, val / 100.0)
		v.text = "%d %%" % int(val))
	_register(key, sl)
	return sl


## Camera sensitivity 0.25×–3.00× in 0.05 steps (slider value = sensitivity × 100): 1.00× is always selectable.
func _camera_slider(sens: float) -> HSlider:
	var row: HBoxContainer = _row("Kamera-Empfindlichkeit")
	var sl: HSlider = _make_slider(CAM_MIN * 100.0, CAM_MAX * 100.0, 5.0,
		roundf(clampf(sens, CAM_MIN, CAM_MAX) * 20.0) * 5.0)
	row.add_child(sl)
	var v: Label = _value_label(_sens_text(sl.value))
	row.add_child(v)
	sl.value_changed.connect(func(val: float) -> void:
		_set_slider("camera_sensitivity", val / 100.0)
		v.text = _sens_text(val))
	_register("camera_sensitivity", sl)
	return sl


static func _sens_text(slider_value: float) -> String:
	return ("%.2f×" % (slider_value / 100.0)).replace(".", ",")


func _make_slider(lo: float, hi: float, p_step: float, value: float) -> HSlider:
	var sl: HSlider = HSlider.new()
	sl.min_value = lo
	sl.max_value = hi
	sl.step = p_step
	sl.value = value
	sl.custom_minimum_size = Vector2(300, ROW_H)        # whole row height is the hit area
	sl.focus_mode = Control.FOCUS_ALL
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_style_slider(sl)
	sl.drag_ended.connect(func(_changed: bool) -> void: flush())
	return sl


func _value_label(text: String) -> Label:
	var v: Label = UiUtil.label(text, &"", 18)
	v.custom_minimum_size = Vector2(76, 0)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.add_theme_font_override("font", UiTheme.font_mono())
	return v


## 12 px track, filled part in NOVA_CYAN, 32 px round grabber (the default grabber is a 16 px dot).
static func _style_slider(sl: HSlider) -> void:
	var track: StyleBoxFlat = UiUtil.box_style(Color(UiUtil.C_INK, 0.9), Color(UiTheme.C_ACCENT_2, 0.6), 2, 0.0, 0, 6)
	track.set_corner_radius_all(6)
	sl.add_theme_stylebox_override("slider", track)
	var fill: StyleBoxFlat = UiUtil.box_style(Color(UiTheme.C_ACCENT_2, 0.75), Color(0, 0, 0, 0), 0, 0.0, 0, 6)
	fill.set_corner_radius_all(6)
	sl.add_theme_stylebox_override("grabber_area", fill)
	sl.add_theme_stylebox_override("grabber_area_highlight", fill)
	sl.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var g: Texture2D = _grabber_texture()
	sl.add_theme_icon_override("grabber", g)
	sl.add_theme_icon_override("grabber_highlight", g)


static func _grabber_texture() -> Texture2D:
	if _grabber != null:
		return _grabber
	var n: int = GRABBER_PX
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c: Vector2 = Vector2(n, n) * 0.5
	var r: float = float(n) * 0.5 - 1.0
	for y in n:
		for x in n:
			var d: float = Vector2(x + 0.5, y + 0.5).distance_to(c)
			var a: float = clampf(r - d + 0.5, 0.0, 1.0)
			var col: Color = UiUtil.C_PAPER if d < r - 3.0 else UiTheme.C_ACCENT_2
			img.set_pixel(x, y, Color(col, a))
	_grabber = ImageTexture.create_from_image(img)
	return _grabber


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
	var b: Button = UiUtil.button("", &"")
	b.custom_minimum_size = Vector2(320, 0)
	b.add_theme_font_size_override("font_size", 18)
	b.clip_text = false
	UiUtil.touch_pad(b)
	row.add_child(b)
	_update_mode_button(b)
	b.pressed.connect(func() -> void: _ask_lower_mode(b))
	_register("difficulty", b)


func _update_mode_button(b: Button) -> void:
	var easy: bool = Game.state != null and Game.state.difficulty == &"vorabend"
	var event_run: bool = Game.state != null and Game.mode != &"campaign"
	if easy:
		b.text = "Vorabendprogramm"
	elif event_run:
		b.text = "Prime Time · Event-Regel"       # event runs play the event's difficulty (05 §10.1)
	else:
		b.text = "Prime Time · senken …"
	b.disabled = not Game.can_lower_difficulty()


func _ask_lower_mode(b: Button) -> void:
	if not ResourceLoader.exists(CONFIRM):
		return
	var d: Node = (load(CONFIRM) as PackedScene).instantiate()
	d.call("setup", {"title": "Modus senken", "text": "Auf „Vorabendprogramm“ wechseln? Weniger Schaden, mehr EXP, " +
		"ab der nächsten Etage mehr Zeit (×1,5). Das lässt sich nicht rückgängig machen.", "yes": "Senken", "no": "Abbrechen",
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
			s.camera_sensitivity = clampf(v01, CAM_MIN, CAM_MAX)
	_commit(false)            # live; written on drag end / close (flush)


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


func _commit(save_now: bool = true) -> void:
	_dirty = true
	Game.apply_settings()
	if save_now:
		flush()
