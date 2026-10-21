extends Control
## "Sendung starten" / "Neue Staffel" (09 §2.2, V-6; ST1-H) — the screen between the title and the slot selection of a
## new private season. The first season of the device is one button with the standard values (private, Mit Netz,
## Kalender, Sendezeit 20:00, the largest owned format): the screen shows them with their one-sentence explanations (09
## §0.5) — the tempo comes later (M.O.D. offers "Am Stück" when the Recall closes after the first class choice, the
## pause tab "Staffel" switches it).
## Every further season ("Neue Staffel") chooses: the format (by owned content, H-2 — Basis only for now, then a fixed
## line), Mit Netz or Ohne Netz (once unlocked: the first class choice or a finished season, V-7; with "Ein Leben.
## Ernsthaft?"), the tempo (Kalender | Am Stück) and the air time (calendar: 08:00 … 21:30, H-4). The right card shows
## the dates the season would get now (day 0, the first collapse, the last) and the explanations of the choices.
## "Sendung starten" → TitleFlow.pending_season → the slot selection, the hero choice, the casting, the intro — the
## single new-game path starts the season (Game.start_season). Params {"mode": "first" | "new" (default: by the
## career's season counter), "capture": bool, "now": unix (captures), "tz": seconds}.

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const InputGlyph := preload("res://scenes/ui/input_glyph.gd")
const UiIcon := preload("res://scenes/ui/ui_icon.gd")
const Backdrop := preload("res://scenes/ui/broadcast_bg.gd")
const TitleFlow := preload("res://scenes/title/title_flow.gd")
const SeasonView := preload("res://scenes/ui/season_view.gd")
const SLOT_SELECT: String = "res://scenes/title/slot_select.tscn"
const DIALOG: String = "res://scenes/ui/season_dialog.tscn"
const COL_W: float = 520.0                  # two columns + 28 px fit 1280 px with notch insets (1136 px)
const OPTION_W: float = 196.0
const ROW_GAP: int = 12                     # 02_TECH §10.2 rule 5: 12 px between the 88 px hit areas

var mode: String = "first"                  # first (Sendung starten) | new (Neue Staffel)
var def_id: String = ""
var tempo: String = "calendar"
var net_mode: String = "net"
var air: String = SeasonView.AIR_DEFAULT
var buttons: Dictionary = {}                # id → Button (tests)

var _params: Dictionary = {}
var _busy: bool = false
var _modal: Node = null
var _unlocked: bool = false
var _card: VBoxContainer
var _air_label: Label = null
var _rows: Array[Array] = []                # focus grid: rows of buttons (the last row: Zurück … Sendung starten)


func setup(params: Dictionary) -> void:
	_params = params


func _ready() -> void:
	UiUtil.full_rect(self)
	Events.overlay_mode_requested.emit.call_deferred(&"menu")
	var career: Dictionary = Save.career()
	mode = str(_params.get("mode", "new" if int(career.get("seasons", 0)) > 0 else "first"))
	if mode != "new":
		mode = "first"
	_unlocked = bool(career.get("no_net", false))
	def_id = SeasonView.default_def(DB.data)
	var def: SeasonDef = DB.season_def(def_id) if def_id != "" else null
	air = def.air_time if def != null and SeasonClock.air_seconds(def.air_time) >= 0 else SeasonView.AIR_DEFAULT
	_build()
	_refresh()
	UiUtil.focus_later(buttons.get("start") as Control)


func _unhandled_input(event: InputEvent) -> void:
	if _modal != null and is_instance_valid(_modal):
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		back()


## The options the start uses (Game.start_season `opts`).
func start_opts() -> Dictionary:
	var o: Dictionary = {"tempo": tempo, "mode": net_mode}
	if tempo == "calendar":
		o["air_time"] = air
	return o


func set_tempo(t: String) -> void:
	if mode == "first" or not SeasonState.TEMPOS.has(t):
		return
	tempo = t
	_refresh()


func set_mode(m: String) -> void:
	if mode == "first" or not SeasonState.MODES.has(m) or (m == "no_net" and not _unlocked):
		return
	net_mode = m
	_refresh()


func step_air(steps: int) -> void:
	if mode == "first" or tempo != "calendar":
		return
	air = SeasonView.air_step(air, steps)
	_refresh()


## "Sendung starten": Ohne Netz asks first ("Ein Leben. Ernsthaft?", 09 §7.2); then the slot selection with the
## pending season.
func start() -> void:
	if _busy or (_modal != null and is_instance_valid(_modal)) or def_id == "":
		return
	if net_mode == "no_net":
		_ask_no_net()
		return
	_go()


func back() -> void:
	if _busy:
		return
	_busy = true
	Sfx.play_ui(&"ui_cancel")
	TitleFlow.pending_season = {}
	Router.goto(Router.SCENE_TITLE)


func open_hall() -> void:
	if _busy:
		return
	_busy = true
	Router.goto(Game.SCENE_HALL_OF_FAME, {"from": "setup"})


func _go() -> void:
	if bool(_params.get("capture", false)):
		return
	_busy = true
	TitleFlow.pending_season = {"def": def_id, "opts": start_opts()}
	Router.goto(SLOT_SELECT, {"mode": "new"})


func _ask_no_net() -> void:
	var d: Node = (load(DIALOG) as PackedScene).instantiate()
	d.call("setup", {"title": "Ein Leben. Ernsthaft?", "danger": true, "kicker": "OHNE NETZ",
		"lines": ["Keine Rettung, keine Sanitäter: Ab Etage 2 sind Sie nach einem Einsturz oder einer Niederlage raus " +
			"und schauen als Studiogast zu.", "Etage 1 bleibt die Generalprobe. Im Safe Room schlafen Sie sicher."],
		"buttons": [{"id": "net", "text": "Lieber mit Netz"}, {"id": "go", "text": "Ein Leben. Los.",
			"danger": true}], "focus": "net", "cancel_id": "net"})
	d.connect("closed", func(id: String, _days: int) -> void:
		_modal = null
		if id == "go":
			_go()
		else:
			net_mode = "net"
			_refresh()
			UiUtil.focus_later(buttons.get("start") as Control))
	add_child(d)
	_modal = d


# --- build ------------------------------------------------------------------------------------------------------------

func _build() -> void:
	add_child(Backdrop.new())
	var safe: SafeAreaContainer = SafeAreaContainer.new()
	safe.extra = 0
	add_child(safe)
	var col: VBoxContainer = UiUtil.vbox(8)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	safe.add_child(col)
	var head: HBoxContainer = UiUtil.hbox(14)
	col.add_child(head)
	var titles: VBoxContainer = UiUtil.vbox(-2)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(titles)
	var number: int = int(Save.career().get("seasons", 0)) + 1
	var kicker: Label = UiUtil.label("STAFFEL %d · PRIVAT · SIE UND DIE KI-BESETZUNG" % number, &"", 18,
		UiTheme.C_ACCENT)
	kicker.add_theme_font_override("font", UiTheme.font_bold())
	titles.add_child(kicker)
	titles.add_child(UiUtil.label("SENDUNG STARTEN" if mode == "first" else "NEUE STAFFEL", &"LabelTitle", 48))
	var def: SeasonDef = DB.season_def(def_id) if def_id != "" else null
	var sub: Label = UiUtil.label(UiUtil.glyph_safe(SeasonView.format_text(def) + " · " +
		str(SeasonView.EXPLAIN["season"])), &"", 19, UiTheme.C_TEXT_DIM)
	titles.add_child(sub)
	var glyph: Control = InputGlyph.make(&"ui_cancel", "Zurück", 16)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	head.add_child(glyph)
	col.add_child(UiUtil.spacer(6))
	var body: HBoxContainer = UiUtil.hbox(28)
	col.add_child(body)
	var left: VBoxContainer = UiUtil.vbox(ROW_GAP)
	left.name = "Options"
	left.custom_minimum_size = Vector2(COL_W, 0)
	body.add_child(left)
	if mode == "first":
		_first_rows(left)
	else:
		_option_rows(left, def)
	var card: PanelContainer = PanelContainer.new()
	card.name = "Card"
	card.custom_minimum_size = Vector2(COL_W, 0)
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	card.add_theme_stylebox_override("panel", UiUtil.box_style(Color(UiUtil.C_INK, 0.82), Color(UiTheme.C_ACCENT_2,
		0.45), 2, 0.0, 20, 14))
	body.add_child(card)
	_card = UiUtil.vbox(6)
	card.add_child(_card)
	col.add_child(UiUtil.spacer(4))
	var brow: HBoxContainer = UiUtil.hbox(16)
	brow.name = "Buttons"
	col.add_child(brow)
	var bottom: Array = []
	var back_b: Button = _big("back", "Zurück", 220.0)
	back_b.pressed.connect(back)
	brow.add_child(back_b)
	bottom.append(back_b)
	if not Save.career_hall().is_empty():
		var hall: Button = _big("hall", "Ruhmeshalle", 250.0)
		hall.pressed.connect(open_hall)
		brow.add_child(hall)
		bottom.append(hall)
	brow.add_child(UiUtil.spacer(0, 0, true))
	var go: Button = _big("start", "Sendung starten", 320.0)
	var gold: StyleBoxFlat = UiUtil.box_style(Color(0.25, 0.17, 0.08, 0.95), UiTheme.C_GOLD, 3, 0.0, 24, 20)
	gold.expand_margin_top = -12.0                # the 64 px box inside the 88 px hit area (touch_pad)
	gold.expand_margin_bottom = -12.0
	go.add_theme_stylebox_override("normal", gold)
	go.add_theme_color_override("font_color", UiTheme.C_GOLD)
	go.pressed.connect(start)
	brow.add_child(go)
	bottom.append(go)
	_rows.append(bottom)
	_wire()


## The first season: the standard values as fixed lines (V-6: one button) and where the tempo comes from.
func _first_rows(left: VBoxContainer) -> void:
	for pair: Array in [["MODUS", "Mit Netz"], ["TEMPO", "Kalender"], ["SENDEZEIT", "%s Uhr" % air]]:
		var row: HBoxContainer = UiUtil.hbox(14)
		row.custom_minimum_size = Vector2(0, 56)
		var k: Label = UiUtil.label(str(pair[0]), &"", 17, UiTheme.C_ACCENT_2)
		k.add_theme_font_override("font", UiTheme.font_bold())
		k.custom_minimum_size = Vector2(140, 0)
		k.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(k)
		var v: Label = UiUtil.label(str(pair[1]), &"", 24)
		v.add_theme_font_override("font", UiTheme.font_bold())
		v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(v)
		left.add_child(row)
	var note: Label = UiUtil.label(UiUtil.glyph_safe("Die erste Staffel startet mit diesen Werten. „Am Stück“ bietet " +
		"M.O.D. nach dem Recall auf Etage 3 an — umschalten geht auch später im Pausemenü unter „Staffel“."), &"", 17,
		UiTheme.C_TEXT_DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(COL_W, 0)
	left.add_child(note)


## "Neue Staffel": the choices — format (several owned only), mode, tempo, air time.
func _option_rows(left: VBoxContainer, def: SeasonDef) -> void:
	var defs: Array[SeasonDef] = SeasonView.owned_defs(DB.data)
	if defs.size() > 1:
		var fmt: Array[Array] = []
		for d: SeasonDef in defs:
			fmt.append(["fmt_" + d.id, str(SeasonView.FORMAT_NAMES.get(d.format, d.name)), d.id])
		left.add_child(_choice_row("FORMAT", fmt, func(arg: String) -> void:
			def_id = arg
			_refresh()))
	elif def != null:
		pass                                       # one owned format: the sub line names it
	left.add_child(_choice_row("MODUS", [["mode_net", "Mit Netz", "net"], ["mode_no_net", "Ohne Netz", "no_net"]],
		set_mode))
	left.add_child(_choice_row("TEMPO", [["tempo_calendar", "Kalender", "calendar"], ["tempo_binge", "Am Stück",
		"binge"]], set_tempo))
	var row: HBoxContainer = UiUtil.hbox(12)
	row.name = "Row_air"
	row.add_child(_row_key("SENDEZEIT"))
	var minus: Button = _small("air_less", "−")
	minus.pressed.connect(func() -> void: step_air(-1))
	row.add_child(minus)
	_air_label = UiUtil.label("", &"", 26, UiTheme.C_GOLD)
	_air_label.add_theme_font_override("font", UiTheme.font_mono())
	_air_label.custom_minimum_size = Vector2(110, 0)
	_air_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_air_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_air_label)
	var plus: Button = _small("air_more", "+")
	plus.pressed.connect(func() -> void: step_air(1))
	row.add_child(plus)
	left.add_child(row)
	_rows.append([minus, plus])


func _choice_row(key: String, options: Array, on_pick: Callable) -> HBoxContainer:
	var row: HBoxContainer = UiUtil.hbox(12)
	row.name = "Row_" + key.to_lower()
	row.add_child(_row_key(key))
	var list: Array = []
	for o: Variant in options:
		var op: Array = o
		var b: Button = UiUtil.button(str(op[1]), &"")
		b.name = str(op[0])
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(OPTION_W, 0)
		UiUtil.touch_pad(b, 64.0)
		var arg: String = str(op[2])
		b.pressed.connect(func() -> void: on_pick.call(arg))
		row.add_child(b)
		buttons[str(op[0])] = b
		list.append(b)
	_rows.append(list)
	return row


func _row_key(key: String) -> Label:
	var k: Label = UiUtil.label(key, &"", 17, UiTheme.C_ACCENT_2)
	k.add_theme_font_override("font", UiTheme.font_bold())
	k.custom_minimum_size = Vector2(130, 0)
	k.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return k


func _big(id: String, text: String, w: float) -> Button:
	var b: Button = UiUtil.button(text, &"ButtonBig")
	b.name = "Btn_" + id
	b.custom_minimum_size = Vector2(w, 0)
	UiUtil.touch_pad(b, 64.0)
	buttons[id] = b
	return b


func _small(id: String, text: String) -> Button:
	var b: Button = UiUtil.button(text, &"")
	b.name = "Btn_" + id
	b.custom_minimum_size = Vector2(UiTheme.TOUCH_HIT, 0)        # an 88 px target (02_TECH §10.2 rule 5)
	UiUtil.touch_pad(b, 64.0)
	buttons[id] = b
	return b


## Focus (02_TECH §10.2): ui_left / ui_right inside a row, ui_up / ui_down between the rows (to the nearest entry), the
## last row is Zurück · (Ruhmeshalle) · Sendung starten; wrap at the ends.
func _wire() -> void:
	for i in _rows.size():
		var row: Array = _rows[i]
		var typed: Array[Control] = []
		for c: Variant in row:
			typed.append(c as Control)
		UiUtil.wire_horizontal(typed, false)
		var above: Array = _rows[(i + _rows.size() - 1) % _rows.size()]
		var below: Array = _rows[(i + 1) % _rows.size()]
		for j in row.size():
			var c2: Control = row[j]
			c2.focus_neighbor_top = c2.get_path_to(above[mini(j, above.size() - 1)] as Control)
			c2.focus_neighbor_bottom = c2.get_path_to(below[mini(j, below.size() - 1)] as Control)


## The toggles, the air time and the card follow the choices.
func _refresh() -> void:
	for m: String in ["net", "no_net"]:
		var b: Button = buttons.get("mode_" + m) as Button
		if b != null:
			b.button_pressed = net_mode == m
			b.disabled = m == "no_net" and not _unlocked
	for t: String in ["calendar", "binge"]:
		var b2: Button = buttons.get("tempo_" + t) as Button
		if b2 != null:
			b2.button_pressed = tempo == t
	for d: SeasonDef in SeasonView.owned_defs(DB.data):
		var b3: Button = buttons.get("fmt_" + d.id) as Button
		if b3 != null:
			b3.button_pressed = def_id == d.id
	if _air_label != null:
		_air_label.text = air if tempo == "calendar" else "—"
		for id: String in ["air_less", "air_more"]:
			(buttons[id] as Button).disabled = tempo != "calendar"
	_fill_card()


## The right card: the dates the season would get when it starts now, then one sentence per choice.
func _fill_card() -> void:
	for c: Node in _card.get_children():
		_card.remove_child(c)
		c.queue_free()
	var def: SeasonDef = DB.season_def(def_id) if def_id != "" else null
	var k: Label = UiUtil.label("IHR SENDEPLAN", &"", 17, UiTheme.C_ACCENT)
	k.add_theme_font_override("font", UiTheme.font_bold())
	_card.add_child(k)
	var now: int = int(_params.get("now", int(Time.get_unix_time_from_system())))
	var tz: int = int(_params.get("tz", SeasonView.tz_offset()))
	if tempo == "calendar" and def != null:
		var p: Dictionary = SeasonView.preview_dates(def, air, now, tz)
		_card.add_child(_fact("Tag 0", SeasonView.when_text(int(p["day0"]), tz)))
		_card.add_child(_fact("Etage 1 stürzt ein", SeasonView.when_text(int(p["first"]), tz)))
		_card.add_child(_fact("Letzter Einsturz", SeasonView.when_text(int(p["last"]), tz)))
	elif def != null:
		_card.add_child(_fact("Countdown", "20, 30, 40, dann je 50 Minuten"))
		_card.add_child(_fact("Etagen", "%d · ohne Termine" % def.format))
	_card.add_child(UiUtil.spacer(4))
	var lines: PackedStringArray = [str(SeasonView.EXPLAIN[tempo])]   # the Generalprobe: M.O.D. in the intro
	if tempo == "calendar":
		lines.append(str(SeasonView.EXPLAIN["air"]) % air)
	lines.append(str(SeasonView.EXPLAIN[net_mode]))
	if mode == "new" and not _unlocked:
		lines.append(str(SeasonView.EXPLAIN["no_net_locked"]))
	lines.append(str(SeasonView.EXPLAIN["nothing_for_sale"]))
	for l: String in lines:
		var row: HBoxContainer = UiUtil.hbox(8)
		var dot: Control = UiIcon.make(&"dot", UiTheme.C_ACCENT_2, 8)
		dot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		dot.custom_minimum_size = Vector2(8, 22)
		row.add_child(dot)
		var t: Label = UiUtil.label(UiUtil.glyph_safe(l), &"", 16, UiTheme.C_TEXT)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.custom_minimum_size = Vector2(COL_W - 60.0, 0)
		row.add_child(t)
		_card.add_child(row)


func _fact(key: String, value: String) -> HBoxContainer:
	var row: HBoxContainer = UiUtil.hbox(10)
	var k: Label = UiUtil.label(key, &"", 17, UiTheme.C_TEXT_DIM)
	k.custom_minimum_size = Vector2(190, 0)
	row.add_child(k)
	var v: Label = UiUtil.label(value, &"", 19, UiTheme.C_TEXT)
	v.add_theme_font_override("font", UiTheme.font_bold())
	row.add_child(v)
	return row
