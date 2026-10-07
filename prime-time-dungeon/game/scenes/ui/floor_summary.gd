class_name FloorSummary extends Control
## Floor summary "Etagen-Bilanz" (02_TECH §9.5, GDD §2.8 / B8): time used / left, kills, viewer peak, new followers,
## achievements — rows slide in and count up; M.O.D. `floor_end` quote; "Weiter" → Game.continue_after_summary()
## (campaign) or the event run result (Game.mode == &"event_offline").

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const UiIcon := preload("res://scenes/ui/ui_icon.gd")
const Backdrop := preload("res://scenes/ui/broadcast_bg.gd")
const RUN_RESULT: String = "res://scenes/ui/run_result.tscn"
const ROW_DELAY: float = 0.18
const COUNT_SEC: float = 0.8
const ROWS: Array[Dictionary] = [
	{"key": "time_used_sec", "label": "Benötigte Zeit", "icon": &"clock", "fmt": "time"},
	{"key": "time_left_sec", "label": "Restzeit", "icon": &"clock", "fmt": "time"},
	{"key": "kills", "label": "Besiegte Gegner", "icon": &"skull", "fmt": "int"},
	{"key": "viewers_peak", "label": "Zuschauer-Spitze", "icon": &"eye", "fmt": "int"},
	{"key": "followers_gained", "label": "Neue Follower", "icon": &"heart", "fmt": "signed"},
	{"key": "achievements", "label": "Achievements", "icon": &"trophy", "fmt": "int"},
]
const DEMO: Dictionary = {"floor": 1, "time_used_sec": 872, "time_left_sec": 328, "kills": 23, "viewers_peak": 7250,
	"followers_gained": 1234, "achievements": 9}

var summary: Dictionary = {}

var _params: Dictionary = {}
var _continue: Button
var _value_labels: Dictionary = {}       # key → Label
var _done: bool = false


## Stores {"summary": FloorRun.summary()}; "Weiter" → Game.continue_after_summary().
func setup(params: Dictionary) -> void:
	_params = params


func _ready() -> void:
	UiUtil.full_rect(self)
	if bool(_params.get("capture", false)):
		summary = DEMO.duplicate()
	elif _params.has("summary") and typeof(_params["summary"]) == TYPE_DICTIONARY:
		summary = (_params["summary"] as Dictionary).duplicate()
	else:
		Game.ensure_state()
		summary = Game.state.floor_run.summary() if Game.state != null and Game.state.floor_run != null else {}
	Events.overlay_mode_requested.emit.call_deferred(&"menu")
	Sfx.music(&"victory")
	_build()
	UiUtil.focus_later(_continue)


func value_text(key: String) -> String:
	var l: Label = _value_labels.get(key) as Label
	return l.text if l != null else ""


func continue_pressed() -> void:
	if _done:
		return
	_done = true
	if Game.mode == &"event_offline":
		Router.goto(RUN_RESULT)
	else:
		Game.continue_after_summary()


## Layout fits the 24 px safe rect at 1280×720 (rows in two columns; everything stays inside the SafeAreaContainer).
func _build() -> void:
	add_child(Backdrop.new())
	var safe: SafeAreaContainer = SafeAreaContainer.new()
	safe.extra = 0
	add_child(safe)
	var col: VBoxContainer = UiUtil.vbox(8)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	safe.add_child(col)
	var floor_index: int = int(summary.get("floor", 1))
	var def: FloorDef = DB.floor_def(floor_index)
	var kicker: Label = UiUtil.label("SENDUNG BEENDET · ETAGE %d" % floor_index, &"", 18, UiTheme.C_ACCENT)
	kicker.add_theme_font_override("font", UiTheme.font_bold())
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(kicker)
	var title: Label = UiUtil.label("ETAGEN-BILANZ", &"LabelTitle", 48)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	if def != null:
		var sub: Label = UiUtil.label(UiUtil.tr_text(def.name), &"", 20, UiTheme.C_TEXT_DIM)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(sub)
	col.add_child(UiUtil.spacer(4))
	var center: CenterContainer = CenterContainer.new()
	col.add_child(center)
	var table: GridContainer = GridContainer.new()
	table.name = "Table"
	table.columns = 2
	table.add_theme_constant_override("h_separation", 16)
	table.add_theme_constant_override("v_separation", 8)
	center.add_child(table)
	var i: int = 0
	for r: Dictionary in ROWS:
		var row: PanelContainer = PanelContainer.new()
		row.custom_minimum_size = Vector2(440, 0)
		row.add_theme_stylebox_override("panel", UiUtil.box_style(Color(UiTheme.C_PANEL, 0.9),
			Color(UiTheme.C_ACCENT_2, 0.35), 1, 0.21, 22, 5))
		table.add_child(row)
		var h: HBoxContainer = UiUtil.hbox(14)
		row.add_child(h)
		var ic: Control = UiIcon.make(r["icon"] as StringName, UiTheme.C_ACCENT if r["icon"] == &"heart" else
			(UiTheme.C_GOLD if r["icon"] == &"trophy" else UiTheme.C_ACCENT_2), 26)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(ic)
		var l: Label = UiUtil.label(str(r["label"]), &"", 21)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		var v: Label = UiUtil.label("", &"", 25, UiTheme.C_GOLD if r["key"] == "followers_gained" else UiTheme.C_TEXT)
		v.add_theme_font_override("font", UiTheme.font_mono())
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(v)
		_value_labels[str(r["key"])] = v
		var target: int = int(summary.get(str(r["key"]), 0))
		var fmt: String = str(r["fmt"])
		v.text = _fmt(target, fmt)
		if is_inside_tree():
			row.modulate.a = 0.0
			var tw: Tween = create_tween()
			tw.tween_interval(ROW_DELAY * i)
			tw.tween_property(row, "modulate:a", 1.0, 0.2)
			tw.tween_method(func(x: float) -> void: v.text = _fmt(roundi(x), fmt), 0.0, float(target), COUNT_SEC)
			tw.tween_callback(func() -> void:
				v.text = _fmt(target, fmt)
				Sfx.play_ui(&"coin"))
		i += 1
	col.add_child(UiUtil.spacer(4))
	var quote: String = UiUtil.mod_line("floor_end", {"floor": floor_index})
	if quote != "":
		var q: Label = UiUtil.label("M.O.D.: „%s“" % quote, &"", 19, UiTheme.C_ACCENT_2)
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		q.custom_minimum_size = Vector2(880, 0)
		q.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(q)
	var note: String = ""
	if Game.mode == &"event_offline":
		note = "Event-Lauf beendet – gleich folgt die Auswertung."
	elif Game.state != null and Game.state.slot > 0:
		note = "„Weiter“ speichert automatisch in Slot %d." % Game.state.slot
	if note != "":
		var n: Label = UiUtil.label(note, &"LabelSmall", 16)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(n)
	var brow: HBoxContainer = UiUtil.hbox(16)
	brow.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(brow)
	_continue = UiUtil.button("Weiter", &"ButtonBig")
	_continue.name = "Continue"
	_continue.custom_minimum_size = Vector2(300, 0)
	UiUtil.touch_pad(_continue, 72.0)
	_continue.pressed.connect(continue_pressed)
	brow.add_child(_continue)


static func _fmt(v: int, fmt: String) -> String:
	match fmt:
		"time":
			return UiUtil.fmt_time(v)
		"signed":
			return UiUtil.fmt_signed(v)
	return UiUtil.fmt_int(v)
