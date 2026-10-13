extends Control
## "Während Sie schliefen …" — the login summary of a season (09 §5.4, ST1-G): one screen before playing on, at any
## time skippable, the title and at most six lines (a rescue or the Sendeschluss first, in plain words), the sub line
## (how long, where, how dangerous, which tactic); with the daily summary switched on (09 §2.9, settings, off by
## default) a second page "Tag für Tag". Before it, a clock jump over seven days asks first (09 §5.5, V-17: "Sie waren
## 23 Tage weg?" — yes: seven days count, the rest becomes a Sendepause; no: nothing counts). Reads Game.season_wake
## (SleepResolver.report); "Weiter" → Game.season_wake_done (the world, the Sendeschluss screen or the Abspann).
## setup({"capture": true}) without a pending summary shows DEMO (stills); {"wake": {…}} shows that one.

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const UiIcon := preload("res://scenes/ui/ui_icon.gd")
const Backdrop := preload("res://scenes/ui/broadcast_bg.gd")
const LINE_W: float = 980.0
## The icon and colour of a line by its kind (SleepText.Prio).
const KIND_ICON: Dictionary = {"out": &"skull", "rescue": &"stairs", "death": &"skull", "meet": &"sword",
	"crash": &"star", "rested": &"snow", "status": &"clock", "clamp": &"pause", "quiet": &"pause", "offer": &"gift",
	"note": &"chat", "news": &"tv"}
const DEMO: Dictionary = {"title": "WÄHREND SIE SCHLIEFEN …",
	"sub": "3 Tage 4 Stunden · Gang „Sortierhalle“, unruhig · Taktik „Vorsichtig“",
	"lines": ["Etage 4 ist eingestürzt. Die Regie hat Sie gerettet: −30 % Credits, −10 % Follower (nächste Gebühr " +
		"frühestens Mo 20:00).", "2 Begegnungen: Hanne Hammerschlag (KI) hielt Wache, 1 Streife besiegt (+1.840 EP, " +
		"120 Credits, Kabelrest ×2)", "Regie-Crashkurs: Kai Stufe 13 auf 14. Das Aufholpaket liegt im Inventar.",
		"Ausgeruht: 40 % (+35 % in 7 Stunden). Ihre nächsten Kampf-EP zählen doppelt.",
		"Etage 5 ist auf Sendung · Einsturz in 1 T 20 Std. (Do 20:00) · neu im Programm: 2 Punkte",
		"Eilmeldung: Kira Katzenjammer (KI) eröffnet Etage 6. Die Regie hat noch nicht mal das Licht an."],
	"kinds": ["rescue", "meet", "crash", "rested", "status", "news"], "more": 1, "result": "",
	"days": [{"day": 4, "label": "Sendetag 5 · Mo 19.10.", "lines": ["1 Begegnung: 1 Streife besiegt (+920 EP)"]},
		{"day": 5, "label": "Sendetag 6 · Di 20.10.", "lines": ["Etage 4 ist eingestürzt. Die Regie hat Sie gerettet."]}]}

var wake: Dictionary = {}

var _params: Dictionary = {}
var _page: Control = null
var _continue: Button = null
var _done: bool = false


func setup(params: Dictionary) -> void:
	_params = params


func _ready() -> void:
	UiUtil.full_rect(self)
	add_child(Backdrop.new())
	if _params.get("wake", null) is Dictionary:
		wake = (_params["wake"] as Dictionary).duplicate(true)
	elif not Game.season_wake.is_empty():
		wake = Game.season_wake.duplicate(true)
	elif bool(_params.get("capture", false)):
		wake = DEMO.duplicate(true)
	Events.overlay_mode_requested.emit.call_deferred(&"menu")
	rebuild()


## Builds the page for `wake` (the question, else the summary).
func rebuild() -> void:
	if _page != null:
		_page.queue_free()
	var safe: SafeAreaContainer = SafeAreaContainer.new()
	safe.extra = 0
	add_child(safe)
	_page = safe
	var col: VBoxContainer = UiUtil.vbox(8)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	safe.add_child(col)
	if wake.has("question"):
		_question(col)
	else:
		_summary(col)


## "Weiter": the world (or the Sendeschluss / the Abspann) — Game.season_wake_done.
func continue_pressed() -> void:
	if _done or bool(_params.get("capture", false)):
		return
	_done = true
	Game.season_wake_done()


## The answer of the clock-jump question: the night is booked, then the summary.
func answer(confirmed: bool) -> void:
	if bool(_params.get("capture", false)):
		return
	Game.season_login_answer(confirmed)
	wake = Game.season_wake.duplicate(true)
	rebuild()


## The daily summary (09 §2.9): the night day by day.
func show_days() -> void:
	if _page != null:
		_page.queue_free()
	var safe: SafeAreaContainer = SafeAreaContainer.new()
	safe.extra = 0
	add_child(safe)
	_page = safe
	var col: VBoxContainer = UiUtil.vbox(8)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	safe.add_child(col)
	col.add_child(_kicker("TAGESZUSAMMENFASSUNG"))
	col.add_child(_title("TAG FÜR TAG"))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(LINE_W + 40.0, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(scroll)
	var list: VBoxContainer = UiUtil.vbox(6)
	scroll.add_child(list)
	for day: Variant in (wake.get("days", []) as Array):
		var d: Dictionary = day
		list.add_child(UiUtil.label(UiUtil.glyph_safe(str(d.get("label", ""))), &"", 18, UiTheme.C_GOLD))
		for l: Variant in (d.get("lines", []) as Array):
			list.add_child(_line_text("• " + str(l), 18, UiTheme.C_TEXT))
	var brow: HBoxContainer = UiUtil.hbox(16)
	brow.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(brow)
	var back: Button = UiUtil.button("Zurück zur Bilanz", &"ButtonBig")
	back.name = "BackToSummary"
	UiUtil.touch_pad(back, 72.0)
	back.pressed.connect(rebuild)
	brow.add_child(back)
	UiUtil.focus_later(back)


func _question(col: VBoxContainer) -> void:
	var sec: int = int(wake["question"])
	col.add_child(_kicker("LOGIN"))
	col.add_child(_title("SIE WAREN %s WEG?" % SleepResolver.duration_text(sec).to_upper()))
	col.add_child(UiUtil.spacer(6))
	var t: Label = _line_text("Bestätigt zählen höchstens 7 Tage — der Rest wird Sendepause, alle Termine rücken mit. " +
		"Verneint zählt die Zeit nicht: Die Staffel macht dort weiter, wo Sie aufgehört haben.", 21, UiTheme.C_TEXT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t)
	col.add_child(UiUtil.spacer(10))
	var brow: HBoxContainer = UiUtil.hbox(16)
	brow.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(brow)
	var no: Button = UiUtil.button("Nein, zählt nicht", &"ButtonBig")
	no.name = "No"
	no.custom_minimum_size = Vector2(300, 0)
	UiUtil.touch_pad(no, 72.0)
	no.pressed.connect(func() -> void: answer(false))
	brow.add_child(no)
	var yes: Button = UiUtil.button("Ja, stimmt", &"ButtonBig")
	yes.name = "Yes"
	yes.custom_minimum_size = Vector2(300, 0)
	UiUtil.touch_pad(yes, 72.0)
	yes.pressed.connect(func() -> void: answer(true))
	brow.add_child(yes)
	UiUtil.wire_horizontal([no, yes] as Array[Control])
	UiUtil.focus_later(yes)


func _summary(col: VBoxContainer) -> void:
	var s: SeasonState = Game.state.season if Game.state != null else null
	var kicker: String = "LOGIN-BILANZ"
	if s != null and s.number > 0:
		kicker += " · STAFFEL %d" % s.number
	if Game.state != null and Game.state.floor_run != null:
		kicker += " · ETAGE %d" % Game.state.floor_run.index
	col.add_child(_kicker(kicker))
	col.add_child(_title(str(wake.get("title", "WÄHREND SIE SCHLIEFEN …"))))
	var sub: Label = UiUtil.label(UiUtil.glyph_safe(str(wake.get("sub", ""))), &"", 19, UiTheme.C_TEXT_DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size = Vector2(LINE_W, 0)
	sub.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(sub)
	col.add_child(UiUtil.spacer(4))
	var lines: Array = wake.get("lines", []) as Array
	var kinds: Array = wake.get("kinds", []) as Array
	var box: VBoxContainer = UiUtil.vbox(6)
	box.name = "Lines"
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(box)
	for i in lines.size():
		var kind: String = str(kinds[i]) if i < kinds.size() else ""
		box.add_child(_row(str(lines[i]), kind))
	if lines.is_empty():
		box.add_child(_row("Nichts passiert. Die Figur hat einfach geschlafen.", "rested"))
	var more: int = int(wake.get("more", 0))
	var daily: bool = bool(wake.get("daily", false)) and (wake.get("days", []) as Array).size() > 1
	if more > 0:
		var m: Label = UiUtil.label("+%d weitere Meldung%s%s" % [more, "" if more == 1 else "en",
			" — Tag für Tag" if daily else ""], &"LabelSmall", 16)
		m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(m)
	var brow: HBoxContainer = UiUtil.hbox(16)
	brow.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(brow)
	var row: Array[Control] = []
	if daily:
		var days: Button = UiUtil.button("Tag für Tag", &"ButtonBig")
		days.name = "Days"
		days.custom_minimum_size = Vector2(260, 0)
		UiUtil.touch_pad(days, 72.0)
		days.pressed.connect(show_days)
		brow.add_child(days)
		row.append(days)
	_continue = UiUtil.button("Weiter", &"ButtonBig")
	_continue.name = "Continue"
	_continue.custom_minimum_size = Vector2(300, 0)
	UiUtil.touch_pad(_continue, 72.0)
	_continue.pressed.connect(continue_pressed)
	brow.add_child(_continue)
	row.append(_continue)
	UiUtil.wire_horizontal(row)
	UiUtil.focus_later(_continue)


func _row(text: String, kind: String) -> PanelContainer:
	var bad: bool = kind == "out" or kind == "death"
	var row: PanelContainer = PanelContainer.new()
	row.custom_minimum_size = Vector2(LINE_W, 0)
	row.add_theme_stylebox_override("panel", UiUtil.box_style(Color(UiTheme.C_PANEL, 0.9),
		Color(UiTheme.C_DANGER if bad else (UiTheme.C_GOLD if kind == "rescue" else UiTheme.C_ACCENT_2), 0.5), 1,
		0.0, 16, 6))
	var h: HBoxContainer = UiUtil.hbox(12)
	row.add_child(h)
	var ic: Control = UiIcon.make(KIND_ICON.get(kind, &"dot") as StringName, UiTheme.C_DANGER if bad else
		(UiTheme.C_GOLD if kind == "rescue" or kind == "crash" else UiTheme.C_ACCENT_2), 24)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	var l: Label = _line_text(text, 19, UiTheme.C_TEXT)
	l.custom_minimum_size = Vector2(LINE_W - 60.0, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	return row


func _kicker(text: String) -> Label:
	var k: Label = UiUtil.label(text, &"", 18, UiTheme.C_ACCENT)
	k.add_theme_font_override("font", UiTheme.font_bold())
	k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return k


func _title(text: String) -> Label:
	var t: Label = UiUtil.label(UiUtil.glyph_safe(text), &"LabelTitle", 44)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return t


func _line_text(text: String, size: int, color: Color) -> Label:
	var l: Label = UiUtil.label(UiUtil.glyph_safe(text), &"", size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(LINE_W, 0)
	l.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return l
