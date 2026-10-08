extends Control
## Event run result (05 CR-10, §1.5): cause, quest state, score breakdown (quest / time / show / achievements / KO),
## total with count-up, local rank; "Nochmal" (same event via Game.start_event_run) and "Zum Titel". "Replay ansehen"
## arrives with S1. Summary from params {"summary": …}, else the last Events.run_finished (cached by GlobalUi).

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const UiIcon := preload("res://scenes/ui/ui_icon.gd")
const Backdrop := preload("res://scenes/ui/broadcast_bg.gd")
const EventInfo := preload("res://scenes/ui/event_info.gd")
const BREAKDOWN: Array[Array] = [["quest", "Quest", &"trophy"], ["time", "Zeitbonus", &"clock"],
	["show", "Show (Follower)", &"heart"], ["achievements", "Achievements", &"star"], ["ko", "KO-Abzug", &"skull"]]
const CAUSES: Dictionary = {"floor_completed": ["TREPPE ERREICHT", Color("#4ade80")],
	"timer": ["SENDESCHLUSS – ZEIT ABGELAUFEN", Color("#ff4d4d")], "defeat": ["NIEDERLAGE", Color("#ff4d4d")],
	"window_closed": ["FENSTER GESCHLOSSEN", Color("#ffc93c")], "quit": ["ABGEBROCHEN", Color("#b3a7c9")]}
const DEMO: Dictionary = {"event_id": "evt_offline_gleis9", "cause": "floor_completed", "quest_complete": true,
	"quest_progress": 1.0, "score": 17340, "rank": 2, "time_left_sec": 828, "followers_gained": 2600,
	"breakdown": {"quest": 10000, "time": 4140, "show": 2600, "achievements": 900, "ko": -300}}
const QUEST_MAX_W: float = 880.0             # quest sentences (data, e.g. all_of + achievement names) wrap here
const TITLE_MAX_W: float = 1100.0            # event names (data) wrap here; the safe rect is 1232 px wide at 1280x720

## Last Events.run_finished summary (set by GlobalUi).
static var last_summary: Dictionary = {}

var summary: Dictionary = {}

var _params: Dictionary = {}
var _again: Button
var _title_btn: Button
var _total: Label
var _busy: bool = false


func setup(params: Dictionary) -> void:
	_params = params


func _ready() -> void:
	UiUtil.full_rect(self)
	if bool(_params.get("capture", false)):
		summary = DEMO.duplicate(true)
	elif _params.has("summary") and typeof(_params["summary"]) == TYPE_DICTIONARY:
		summary = (_params["summary"] as Dictionary).duplicate(true)
	else:
		summary = last_summary.duplicate(true)
	Events.overlay_mode_requested.emit.call_deferred(&"menu")
	Sfx.music(&"victory" if bool(summary.get("quest_complete", false)) else &"game_over")
	_build()
	UiUtil.focus_later(_again)


func event_id() -> String:
	var id: String = str(summary.get("event_id", ""))
	if id == "" and Game.run_log != null:
		id = str(Game.run_log.header.get("event_id", ""))
	return id


func score_text() -> String:
	return _total.text


func again() -> void:
	if _busy:
		return
	var id: String = event_id()
	if id == "":
		return
	_busy = true
	Game.start_event_run(id)
	if Game.mode == &"event_offline" and Game.has_state():
		Router.goto(Router.SCENE_EXPLORATION, {"spawn": &"start"})
	else:
		_busy = false
		Events.toast_requested.emit("Event-Lauf konnte nicht gestartet werden.", &"warning")


func to_title() -> void:
	if _busy:
		return
	_busy = true
	Router.goto(Router.SCENE_TITLE)


## Layout fits the 24 px safe rect at 1280×720 (compact rows; nothing leaves the SafeAreaContainer).
func _build() -> void:
	add_child(Backdrop.new())
	var safe: SafeAreaContainer = SafeAreaContainer.new()
	safe.extra = 0
	add_child(safe)
	var col: VBoxContainer = UiUtil.vbox(6)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	safe.add_child(col)
	var info: Dictionary = EventInfo.find(event_id())
	var kicker: Label = UiUtil.label("EVENT-LAUF · AUSWERTUNG", &"", 18, UiTheme.C_ACCENT)
	kicker.add_theme_font_override("font", UiTheme.font_bold())
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(kicker)
	var title: Label = UiUtil.label(str(info.get("name", "Event-Lauf")).to_upper(), &"LabelTitle", 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	UiUtil.wrap_label(title, TITLE_MAX_W)    # natural width up to the cap, never squeezed to the other rows' width
	var cause: Array = CAUSES.get(str(summary.get("cause", "")), ["LAUF BEENDET", UiTheme.C_TEXT_DIM])
	var badge_c: CenterContainer = CenterContainer.new()
	col.add_child(badge_c)
	var badge: PanelContainer = PanelContainer.new()
	badge.add_theme_stylebox_override("panel", UiUtil.box_style(cause[1] as Color, Color(0, 0, 0, 0), 0, 0.21, 18, 4))
	badge_c.add_child(badge)
	var bl: Label = UiUtil.label(str(cause[0]), &"", 20, UiUtil.C_INK)
	bl.add_theme_font_override("font", UiTheme.font_bold())
	bl.add_theme_constant_override("outline_size", 0)
	badge.add_child(bl)
	var quest_done: bool = bool(summary.get("quest_complete", false))
	var qtext: String = EventInfo.quest_text(info.get("quest", {}) as Dictionary) if not info.is_empty() else ""
	var qrow: HBoxContainer = UiUtil.hbox(10)
	qrow.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(qrow)
	qrow.add_child(UiIcon.make(&"check" if quest_done else &"cross", UiTheme.C_OK if quest_done else UiTheme.C_DANGER,
		22))
	var ql: Label = UiUtil.label(("Quest erfüllt: " if quest_done else "Quest offen (%d %%): " % roundi(float(
		summary.get("quest_progress", 0.0)) * 100.0)) + qtext, &"", 20)
	ql.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER    # wrapped lines stay centered like the rest of col
	qrow.add_child(ql)
	UiUtil.wrap_label(ql, QUEST_MAX_W)
	var center: CenterContainer = CenterContainer.new()
	col.add_child(center)
	var table: VBoxContainer = UiUtil.vbox(0)
	table.custom_minimum_size = Vector2(620, 0)
	center.add_child(table)
	var breakdown: Dictionary = summary.get("breakdown", {}) if typeof(summary.get("breakdown", {})) == \
		TYPE_DICTIONARY else {}
	for b: Array in BREAKDOWN:
		var row: HBoxContainer = UiUtil.hbox(12)
		row.custom_minimum_size = Vector2(0, 34)
		table.add_child(row)
		row.add_child(UiIcon.make(b[2] as StringName, UiTheme.C_ACCENT_2, 22))
		var l: Label = UiUtil.label(str(b[1]), &"", 21)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var val: int = int(breakdown.get(str(b[0]), 0))
		var v: Label = UiUtil.label(UiUtil.fmt_signed(val) if breakdown.has(str(b[0])) else "–", &"", 22,
			UiTheme.C_DANGER if val < 0 else UiTheme.C_TEXT)
		v.add_theme_font_override("font", UiTheme.font_mono())
		row.add_child(v)
	var line: ColorRect = ColorRect.new()
	line.custom_minimum_size = Vector2(0, 2)
	line.color = Color(UiTheme.C_ACCENT, 0.7)
	table.add_child(line)
	var trow: HBoxContainer = UiUtil.hbox(12)
	table.add_child(trow)
	var tl: Label = UiUtil.label("PUNKTE", &"LabelHeader")
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	trow.add_child(tl)
	_total = UiUtil.label("0", &"", 40, UiTheme.C_GOLD)
	_total.add_theme_font_override("font", UiTheme.font_mono())
	trow.add_child(_total)
	var target: int = int(summary.get("score", 0))
	_total.text = UiUtil.fmt_int(target)
	if is_inside_tree() and target != 0:
		var tw: Tween = create_tween()
		tw.tween_method(func(x: float) -> void: _total.text = UiUtil.fmt_int(roundi(x)), 0.0, float(target), 1.2)
	var rank: int = int(summary.get("rank", 0))
	var rank_text: String = "Platz %d der lokalen Bestenliste" % rank if rank > 0 else "Nicht in den Top 10"
	var rk: Label = UiUtil.label(rank_text, &"", 20, UiTheme.C_GOLD if rank in [1, 2, 3] else UiTheme.C_TEXT_DIM)
	rk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(rk)
	var brow: HBoxContainer = UiUtil.hbox(18)
	brow.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(brow)
	_again = UiUtil.button("Nochmal", &"ButtonBig")
	_again.name = "Again"
	_again.custom_minimum_size = Vector2(260, 0)
	UiUtil.touch_pad(_again, 72.0)
	_again.pressed.connect(again)
	brow.add_child(_again)
	_title_btn = UiUtil.button("Zum Titel", &"ButtonBig")
	_title_btn.name = "Title"
	_title_btn.custom_minimum_size = Vector2(260, 0)
	UiUtil.touch_pad(_title_btn, 72.0)
	_title_btn.pressed.connect(to_title)
	brow.add_child(_title_btn)
	UiUtil.wire_horizontal([_again, _title_btn] as Array[Control])
	var note: Label = UiUtil.label("Replays ansehen folgt mit den Online-Events.", &"LabelSmall", 16)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(note)
