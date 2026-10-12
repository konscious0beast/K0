extends "res://scenes/ui/menu_base.gd"
## Pause tab "Staffel" (09 §2.4, §2.9, §4.6, ST1-H; only in a season — the section "Staffeln (09, ST1-H)" of
## pause_menu.gd adds it): the head line (number, format, tempo, mode — the day and the floor on air), on the left the
## broadcast schedule with every collapse date in local time (Am Stück the countdowns), on the right four segments —
## Rangliste (the counter, the places around the candidate, the AI labelled), Ticker (the last 24 h), Programm (the
## programme points of the floor with NEU, the next air time, the Pechvogel in need with "Helfen", the guest along, the
## favours) and Aktionen (the .ics file of the schedule, the Sendepause, "Am Stück", "Staffel beenden" — each with its
## sentence, 09 §0.5). Read-only views (season_view.gd); a change goes through Game's season commands (cast_action,
## season_pause_days, season_tempo_binge, season_leave) after a dialog (season_dialog: "Staffel beenden" is red and
## starts on "Weiterspielen"). The dialogs are modal over the pause menu (PauseMenu.season_modal).
## Layout (1280 × 720 and the phone canvas 1600 × 720): the schedule column and the segment column side by side; every
## button a 64 px box in an 88 px hit area, 12 px apart; texts ≥ 16 px.

const SeasonView := preload("res://scenes/ui/season_view.gd")
const DIALOG: String = "res://scenes/ui/season_dialog.tscn"
const SEGMENTS: Array[Dictionary] = [
	{"id": "ranking", "label": "Rangliste", "icon": &"trophy"},
	{"id": "ticker", "label": "Ticker", "icon": &"chat"},
	{"id": "programme", "label": "Programm", "icon": &"star"},
	{"id": "actions", "label": "Aktionen", "icon": &"tv"},
]
const KIND_COLORS: Dictionary = {"gone": Color(0.55, 0.55, 0.6), "air": Color("#ffc93c"), "open": Color("#7fd6ff"),
	"closed": Color(0.62, 0.6, 0.7), "done": Color(0.55, 0.55, 0.6), "now": Color("#ffc93c"),
	"next": Color("#7fd6ff")}
const RESULT_WORDS: Dictionary = {"finalist": "Finale", "end": "am Ende", "fallen": "raus", "buried": "raus",
	"left": "ausgestiegen"}
const TICKER_ROWS: int = 5

var segment: String = "ranking"
## The last .ics file written (its absolute path; "" none yet) — tests and the status line.
var ics_path: String = ""

var _tz: int = 0
var _head: Label
var _status_line: Label
var _plan_note: Label
var _plan_list: VBoxContainer
var _seg_buttons: Dictionary = {}            # segment id → Button
var _seg_list: Array[Control] = []
var _content: VBoxContainer
var _content_scroll: ScrollContainer
var _focusables: Array[Control] = []         # the focusable controls of the segment shown
var _actions: Dictionary = {}                # action id → Button (tests)
var _action_note: Label = null               # the sentence of the action in focus (segment Aktionen)


func _ready() -> void:
	page_title = "Staffel"
	_tz = SeasonView.tz_offset()
	_build()
	refresh()


func refresh() -> void:
	if _head == null:
		return
	var st: GameState = Game.state
	var s: SeasonState = st.season if st != null else null
	_head.text = UiUtil.glyph_safe(SeasonView.head_text(st).to_upper()) if s != null else "KEINE STAFFEL"
	_status_line.text = UiUtil.glyph_safe(SeasonView.status_text(st, _tz)) if s != null else ""
	_fill_plan(st)
	show_segment(segment)


func focus_default() -> void:
	var b: Control = _seg_buttons.get(segment) as Control
	if b != null:
		UiUtil.focus_later(b)


## Back from the content to its segment (the pause menu takes the focus to its tab bar from a segment).
func handle_cancel() -> bool:
	var f: Control = get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if f != null and _content.is_ancestor_of(f):
		(_seg_buttons[segment] as Control).grab_focus()
		return true
	return false


## Shows segment `id` (ranking | ticker | programme | actions).
func show_segment(id: String) -> void:
	segment = id if _seg_buttons.has(id) else "ranking"
	for sid: Variant in _seg_buttons.keys():
		(_seg_buttons[sid] as Button).button_pressed = str(sid) == segment
	clear(_content)
	_focusables.clear()
	_actions.clear()
	_content.add_theme_constant_override("separation", 3 if segment == "ranking" else 8)   # the ranking fits unscrolled
	var st: GameState = Game.state
	if st == null or st.season == null:
		_content.add_child(empty_note("Keine Staffel."))
		return
	match segment:
		"ranking":
			_fill_ranking(st)
		"ticker":
			_fill_ticker(st)
		"programme":
			_fill_programme(st)
		"actions":
			_fill_actions(st)
	_wire_content()


## The button of action `id` in the segment Aktionen (ics | pause | binge | leave; null when not offered) — tests.
func action(id: String) -> Button:
	return _actions.get(id) as Button


## The schedule rows shown (tests: one per floor of the format).
func plan_rows() -> int:
	return _plan_list.get_child_count() if _plan_list != null else 0


# --- build ------------------------------------------------------------------------------------------------------------

func _build() -> void:
	var col: VBoxContainer = UiUtil.vbox(10)
	col.name = "Season"
	UiUtil.full_rect(col)
	add_child(col)
	var head: HBoxContainer = UiUtil.hbox(10)
	head.name = "Head"
	col.add_child(head)
	var ic: Control = UiIcon.make(&"tv", UiTheme.C_ACCENT, 24)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(ic)
	_head = UiUtil.label("", &"", 18, UiTheme.C_ACCENT)
	_head.name = "HeadText"
	_head.add_theme_font_override("font", UiTheme.font_bold())
	_head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_head.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_head.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_head)
	_status_line = UiUtil.label("", &"", 18, UiTheme.C_GOLD)
	_status_line.name = "Status"
	_status_line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_status_line)
	var body: HBoxContainer = UiUtil.hbox(16)
	body.name = "Body"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	body.add_child(_build_plan())
	body.add_child(_build_segments())


## The schedule column: "SENDEPLAN" with the time note, one row per floor.
func _build_plan() -> Control:
	var pcol: VBoxContainer = UiUtil.vbox(6)
	pcol.name = "Plan"
	pcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pcol.size_flags_stretch_ratio = 0.78
	var ph: HBoxContainer = UiUtil.hbox(10)
	pcol.add_child(ph)
	var pt: Label = UiUtil.label("SENDEPLAN", &"", 17, UiTheme.C_TEXT)
	pt.add_theme_font_override("font", UiTheme.font_bold())
	ph.add_child(pt)
	_plan_note = UiUtil.label("", &"", 16, UiTheme.C_TEXT_DIM)
	_plan_note.name = "PlanNote"
	_plan_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_plan_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_plan_note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	ph.add_child(_plan_note)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "PlanScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pcol.add_child(scroll)
	_plan_list = UiUtil.vbox(4)
	_plan_list.name = "PlanList"
	_plan_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_plan_list)
	return pcol


## The segment column: the four segment buttons over the content.
func _build_segments() -> Control:
	var rcol: VBoxContainer = UiUtil.vbox(8)
	rcol.name = "Segments"
	rcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row: HBoxContainer = UiUtil.hbox(12)
	row.name = "SegmentBar"
	rcol.add_child(row)
	for sd: Dictionary in SEGMENTS:
		var id: String = str(sd["id"])
		var b: Button = _segment_button(str(sd["label"]), sd["icon"] as StringName)
		b.name = "Seg_" + id
		var on: StyleBoxFlat = UiUtil.box_style(Color(UiTheme.C_ACCENT, 0.3), UiTheme.C_ACCENT, 0, 0.0, 6, 4)
		on.border_width_bottom = 4
		on.expand_margin_top = -12.0
		on.expand_margin_bottom = -12.0
		b.add_theme_stylebox_override("pressed", on)
		b.add_theme_stylebox_override("hover_pressed", on)
		b.focus_entered.connect(func() -> void:
			if segment != id:
				show_segment(id))
		b.pressed.connect(func() -> void:
			show_segment(id)
			_focus_content())
		row.add_child(b)
		_seg_buttons[id] = b
		_seg_list.append(b)
	UiUtil.wire_horizontal(_seg_list)
	for c: Control in _seg_list:
		c.focus_neighbor_top = c.get_path_to(c)
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "ContentPanel"
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", UiUtil.box_style(Color(UiUtil.C_INK, 0.45), Color(UiTheme.C_ACCENT_2,
		0.3), 1, 0.0, 14, 10))
	rcol.add_child(panel)
	_content_scroll = ScrollContainer.new()
	_content_scroll.name = "ContentScroll"
	_content_scroll.follow_focus = true
	_content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(_content_scroll)
	_content = UiUtil.vbox(8)
	_content.name = "Content"
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_scroll.add_child(_content)
	return rcol


## A segment: icon + caption centred (18 px, the four fit 1280 px beside the schedule); 64 px box, 88 px hit area.
func _segment_button(text: String, icon: StringName) -> Button:
	var b: Button = UiUtil.button("", &"ButtonFlat")
	b.toggle_mode = true
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size.x = 120.0
	UiUtil.touch_pad(b)
	var row: HBoxContainer = UiUtil.hbox(8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiUtil.full_rect(row)
	b.add_child(row)
	var ic: Control = UiIcon.make(icon, UiTheme.C_ACCENT_2, 22)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	var l: Label = UiUtil.label(text, &"", 18)
	l.name = "Text"
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	return b


# --- the schedule -----------------------------------------------------------------------------------------------------

func _fill_plan(st: GameState) -> void:
	clear(_plan_list)
	var s: SeasonState = st.season if st != null else null
	if s == null:
		return
	_plan_note.text = "Countdown je Etage, er läuft nur beim Erkunden" if s.tempo == "binge" \
		else "Einsturz zur Sendezeit · Ihre Ortszeit"
	for row: Dictionary in SeasonView.schedule(st, DB.data, _tz):
		_plan_list.add_child(_plan_row(row))


## One floor: number plaque, name, the date / countdown; below (FINALE and) the status in words.
func _plan_row(row: Dictionary) -> Control:
	var kind: String = str(row["kind"])
	var col: Color = KIND_COLORS.get(kind, UiTheme.C_TEXT) as Color
	var here: bool = bool(row["here"])
	var p: PanelContainer = PanelContainer.new()
	p.name = "Floor_%d" % int(row["floor"])
	var sb: StyleBoxFlat = UiUtil.box_style(Color(UiTheme.C_PANEL, 0.75 if here else 0.45),
		Color(UiTheme.C_GOLD, 0.9) if here else Color(0, 0, 0, 0), 2 if here else 0, 0.0, 10, 3)
	sb.border_width_left = 5
	sb.border_color = UiTheme.C_GOLD if here else col
	p.add_theme_stylebox_override("panel", sb)
	var h: HBoxContainer = UiUtil.hbox(10)
	p.add_child(h)
	var num: Label = UiUtil.label(str(int(row["floor"])), &"", 22, col)
	num.add_theme_font_override("font", UiTheme.font_mono())
	num.custom_minimum_size = Vector2(30, 0)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(num)
	var texts: VBoxContainer = UiUtil.vbox(0)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(texts)
	var top: HBoxContainer = UiUtil.hbox(8)
	texts.add_child(top)
	if here:
		var me: Control = UiIcon.make(&"person", UiTheme.C_GOLD, 18)
		me.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(me)
	var name_l: Label = UiUtil.label(UiUtil.glyph_safe(str(row["name"])), &"", 17,
		UiTheme.C_TEXT if kind != "gone" and kind != "done" else UiTheme.C_TEXT_DIM)
	name_l.name = "Name"
	name_l.add_theme_font_override("font", UiTheme.font_bold())
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top.add_child(name_l)
	var line: Label = UiUtil.label(str(row["line"]), &"", 16, col)
	line.name = "When"
	line.add_theme_font_override("font", UiTheme.font_mono())
	top.add_child(line)
	var bottom: HBoxContainer = UiUtil.hbox(8)      # FINALE in front of the status: the name keeps the width (notch)
	texts.add_child(bottom)
	if bool(row["finale"]):
		var fin: Label = UiUtil.label("FINALE", &"", 16, UiTheme.C_GOLD)
		fin.name = "Finale"
		fin.add_theme_font_override("font", UiTheme.font_bold())
		bottom.add_child(fin)
	var sub: Label = UiUtil.label(UiUtil.glyph_safe(str(row["sub"])), &"", 16, col if kind == "air" or kind == "now"
		else UiTheme.C_TEXT_DIM)
	sub.name = "Sub"
	sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	bottom.add_child(sub)
	return p


# --- the segments -----------------------------------------------------------------------------------------------------

func _fill_ranking(st: GameState) -> void:
	var c: Dictionary = SeasonView.counter(st, DB.data)
	var rank: String = SeasonView.rank_text(st, DB.data)
	var top: Label = UiUtil.label(UiUtil.glyph_safe(str(c.get("text", "")) + (" · Sie: " + rank if rank != "" else "")),
		&"", 18, UiTheme.C_GOLD)
	top.name = "Counter"
	top.add_theme_font_override("font", UiTheme.font_bold())
	_content.add_child(top)
	if not CastSim.has_cast(st):
		_content.add_child(_note(str(SeasonView.CAST_REASONS["no_cast"])))
		return
	for r: Dictionary in SeasonView.ranking_rows(st, DB.data):
		_content.add_child(_rank_row(r))
	_content.add_child(_note(str(SeasonView.EXPLAIN["cast"])))


func _rank_row(r: Dictionary) -> Control:
	if bool(r.get("gap", false)):                 # skipped places: a thin rule (the list must fit without scrolling)
		var g: CenterContainer = CenterContainer.new()
		g.name = "Gap"
		g.custom_minimum_size = Vector2(0, 8)
		var line: ColorRect = ColorRect.new()
		line.color = Color(UiTheme.C_TEXT_DIM, 0.5)
		line.custom_minimum_size = Vector2(120, 2)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		g.add_child(line)
		return g
	var me: bool = bool(r["me"])
	var row: HBoxContainer = UiUtil.hbox(10)
	row.name = "Rank_%d" % int(r["rank"])
	var col: Color = UiTheme.C_GOLD if me else (UiTheme.C_TEXT if str(r["result"]) != "fallen" \
		and str(r["result"]) != "buried" else UiTheme.C_TEXT_DIM)
	var n: Label = UiUtil.label("%d." % int(r["rank"]), &"", 16, col)
	n.add_theme_font_override("font", UiTheme.font_mono())
	n.custom_minimum_size = Vector2(52, 0)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(n)
	var who: Label = UiUtil.label(UiUtil.glyph_safe(str(r["label"]) + (" · Sie" if me else "")), &"", 16, col)
	who.name = "Who"
	if me:
		who.add_theme_font_override("font", UiTheme.font_bold())
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(who)
	var res: String = str(r["result"])
	var where: Label = UiUtil.label(str(RESULT_WORDS.get(res, "Etage %d" % int(r["floor"]))), &"", 16,
		UiTheme.C_TEXT_DIM)
	where.custom_minimum_size = Vector2(96, 0)
	row.add_child(where)
	var q: Label = UiUtil.label(UiUtil.fmt_int(int(r["quote"])), &"", 16, col)
	q.add_theme_font_override("font", UiTheme.font_mono())
	q.custom_minimum_size = Vector2(80, 0)
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(q)
	return row


func _fill_ticker(st: GameState) -> void:
	if not CastSim.has_cast(st):
		_content.add_child(_note(str(SeasonView.CAST_REASONS["no_cast"])))
		return
	var rows: Array[Dictionary] = SeasonView.ticker_rows(st, DB.data, 24, TICKER_ROWS)
	if rows.is_empty():
		_content.add_child(_note("Keine Eilmeldungen in den letzten 24 Stunden. Erstaunlich ruhig da unten."))
		return
	for r: Dictionary in rows:
		var item: VBoxContainer = UiUtil.vbox(0)
		item.name = "News"
		var ago: Label = UiUtil.label(str(r["ago"]).to_upper(), &"", 16, UiTheme.C_ACCENT)
		ago.add_theme_font_override("font", UiTheme.font_bold())
		item.add_child(ago)
		var t: Label = UiUtil.label(UiUtil.glyph_safe(str(r["text"])), &"", 17)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		item.add_child(t)
		_content.add_child(item)


## The floor's programme (09 §3.3): the title with the next air time, the Pechvogel in need first (it has a button),
## the points in two columns (NEU: its room not entered yet), the guest along and the favours.
func _fill_programme(st: GameState) -> void:
	var s: SeasonState = st.season
	var fr: FloorRun = st.floor_run
	var v: Dictionary = SeasonView.floor_view(st, DB.data, _tz)
	var head: HBoxContainer = UiUtil.hbox(10)
	_content.add_child(head)
	var title: Label = UiUtil.label("TAGESPROGRAMM · ETAGE %d" % (fr.index if fr != null else 0), &"", 17,
		UiTheme.C_ACCENT)
	title.add_theme_font_override("font", UiTheme.font_bold())
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var next: String = str(v.get("next", ""))
	if s.tempo == "calendar" and next != "":
		head.add_child(UiUtil.label("Nächster Punkt: %s" % next, &"", 16, UiTheme.C_TEXT_DIM))
	if CastSim.has_cast(st) and not (v.get("need", {}) as Dictionary).is_empty():
		_content.add_child(_need_row(st, v["need"] as Dictionary))
	var points: Array = v.get("points", []) as Array
	var grid: GridContainer = GridContainer.new()
	grid.name = "Points"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 2)
	_content.add_child(grid)
	for p: Variant in points:
		var pd: Dictionary = p
		var row: HBoxContainer = UiUtil.hbox(8)
		row.name = "Point_%d" % int(pd["n"])
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var n: Label = UiUtil.label("%d" % int(pd["n"]), &"", 16, UiTheme.C_TEXT_DIM)
		n.add_theme_font_override("font", UiTheme.font_mono())
		n.custom_minimum_size = Vector2(18, 0)
		n.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(n)
		var nm: Label = UiUtil.label(UiUtil.glyph_safe(str(pd["name"])), &"", 16)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.custom_minimum_size = Vector2(120, 0)
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # a long name takes a second line, never "…"
		row.add_child(nm)
		if bool(pd["new"]):
			var tag: Control = _new_tag()
			tag.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			row.add_child(tag)
		grid.add_child(row)
	if s.tempo == "binge":
		_content.add_child(_note("Am Stück bringt jede Etage beim Betreten einen Programmpunkt mit."))
	elif points.is_empty():
		_content.add_child(_note("Noch kein Programmpunkt — der erste kommt zur Sendezeit."))
	elif points.size() < SeasonClock.DAILY_MAX:
		_content.add_child(_note("Neue Punkte kommen zur Sendezeit und bleiben bis zum Einsturz."))
	else:
		_content.add_child(_note("Alle fünf Programmpunkte dieser Etage sind da."))
	if not CastSim.has_cast(st):
		return
	var guest: Dictionary = v.get("guest", {}) as Dictionary
	if not guest.is_empty():
		var gl: String = "Begleitung: %s · " % str(guest["label"])
		gl += "hilft im nächsten Kampf" if str(guest["kind"]) == "help" else ("noch %d Kämpfe" % int(guest["left"])
			if int(guest["left"]) != 1 else "noch 1 Kampf")
		_content.add_child(_note(gl, UiTheme.C_OK))
	var favors: int = int(v.get("favors", 0))
	if favors > 0:
		_content.add_child(_note("Gefallen gut: %d — der nächste bezahlt eine Helfer:in im Safe Room." % favors,
			UiTheme.C_GOLD))


## The Pechvogel in need (09 §4.3): who, what helping brings, "Helfen" — or why it cannot be now.
func _need_row(st: GameState, need: Dictionary) -> Control:
	var place: int = int(need["place"])
	var box: HBoxContainer = UiUtil.hbox(12)
	box.name = "Need"
	var why: String = CastSim.refusal(st, DB.data, {"t": "cast", "op": "help", "who": place})
	var text: String = "Pechvogel in Not: %s steckt in einem Kampf fest. " % str(need["label"])
	text += "Helfen bringt Follower und einen Gefallen, Absagen kostet nichts."
	if why != "":
		text += " " + SeasonView.cast_reason(why)
	var t: Label = UiUtil.label(UiUtil.glyph_safe(text), &"", 17)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(t)
	if why == "":
		var b: Button = UiUtil.button("Helfen", &"")
		b.name = "Help"
		b.custom_minimum_size = Vector2(140, 0)
		UiUtil.touch_pad(b)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(func() -> void: _help(place))
		box.add_child(b)
		_focusables.append(b)
		_actions["help"] = b
	return box


## The actions in a 2 × 2 grid with the sentence of the action in focus (hover, touch: the first) below them — 09 §0.5;
## Am Stück only "Staffel beenden" (and why there is nothing else); a finished season none.
func _fill_actions(st: GameState) -> void:
	var s: SeasonState = st.season
	var grid: GridContainer = GridContainer.new()
	grid.name = "Actions"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(grid)
	_action_note = _note("")
	_action_note.name = "ActionNote"
	var over: bool = s.result != ""
	if over:
		_action_note.text = "Diese Staffel ist für Sie vorbei."
	elif s.tempo == "calendar":
		var left_days: int = Game.season_pause_days_left()
		grid.add_child(_action_button("ics", "Kalender-Datei", false, "Speichert alle Einstürze als .ics-Datei für " +
			"Ihren Kalender — nur auf diesem Gerät, ohne Namen."))
		if left_days > 0:
			grid.add_child(_action_button("pause", "Sendepause", false, "Sendepause: Die Uhr steht, alle Termine rücken " +
				"nach hinten — noch %s in dieser Staffel." % ("1 Tag" if left_days == 1 else "%d Tage" % left_days)))
		grid.add_child(_action_button("binge", "Am Stück spielen", false, str(SeasonView.EXPLAIN["binge"]) +
			" Nur in diese Richtung."))
	else:
		_action_note.text = "Am Stück steht die Uhr, solange niemand spielt: keine Termine, keine Sendepause nötig."
	if not over:
		grid.add_child(_action_button("leave", "Staffel beenden", true, "Die Figur geht in die Ruhmeshalle, der " +
			"Speicherplatz wird frei. Das lässt sich nicht rückgängig machen."))
	if s.tempo == "calendar" and not over and Game.season_pause_days_left() <= 0:
		_action_note.text = "Die 14 Tage Sendepause dieser Staffel sind aufgebraucht."
	elif _action_note.text == "" and not _focusables.is_empty():
		_action_note.text = UiUtil.glyph_safe(str(_focusables[0].get_meta(&"sentence", "")))
	_content.add_child(_action_note)


## An action: a 64 px box in an 88 px hit area ("Staffel beenden" red); focus and hover show its sentence below.
func _action_button(id: String, text: String, danger: bool, sentence: String) -> Button:
	var b: Button = UiUtil.button(text, &"")
	b.name = "Act_" + id
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size.x = 200.0
	if danger:
		b.add_theme_stylebox_override("normal", UiUtil.box_style(Color(UiTheme.C_DANGER, 0.2), UiTheme.C_DANGER, 2,
			0.0, 14, 4))
	UiUtil.touch_pad(b, 64.0)
	b.set_meta(&"sentence", sentence)
	var show_it: Callable = func() -> void:
		if _action_note != null and is_instance_valid(_action_note):
			_action_note.text = UiUtil.glyph_safe(sentence)
	b.focus_entered.connect(show_it)
	b.mouse_entered.connect(show_it)
	b.pressed.connect(func() -> void: _on_action(id))
	_focusables.append(b)
	_actions[id] = b
	return b


func _note(text: String, color: Color = Color(0, 0, 0, 0)) -> Label:
	var l: Label = UiUtil.label(UiUtil.glyph_safe(text), &"", 16, UiTheme.C_TEXT_DIM if color.a == 0.0 else color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _new_tag() -> Control:
	var p: PanelContainer = PanelContainer.new()
	p.name = "New"
	p.add_theme_stylebox_override("panel", UiUtil.box_style(UiTheme.C_GOLD, Color(0, 0, 0, 0), 0, 0.0, 6, 0))
	var l: Label = UiUtil.label("NEU", &"", 16, UiUtil.C_INK)
	l.add_theme_font_override("font", UiTheme.font_bold())
	p.add_child(l)
	return p


## Focus: the segment bar ↔ the content (down / up); inside the content in reading order.
func _wire_content() -> void:
	var seg: Control = _seg_buttons.get(segment) as Control
	if _focusables.is_empty():
		for c: Control in _seg_list:
			c.focus_neighbor_bottom = c.get_path_to(c)
		return
	if segment == "actions" and _focusables.size() > 1:
		_wire_grid(_focusables)
	else:
		UiUtil.wire_vertical(_focusables, false)
	for c: Control in _seg_list:
		c.focus_neighbor_bottom = c.get_path_to(_focusables[0])
	for f: Control in _focusables:
		if f.focus_neighbor_top == NodePath() or f.get_node_or_null(f.focus_neighbor_top) == f:
			f.focus_neighbor_top = f.get_path_to(seg)
	if _focusables.size() == 1:
		_focusables[0].focus_neighbor_bottom = _focusables[0].get_path_to(_focusables[0])


## The action buttons of the 2-column grid: left / right in a row, up / down in a column; the top row goes up to the
## segment, the bottom row stays.
func _wire_grid(list: Array[Control]) -> void:
	var seg: Control = _seg_buttons.get(segment) as Control
	for i in list.size():
		var c: Control = list[i]
		var left: Control = list[i - 1] if i % 2 == 1 else c
		var right: Control = list[i + 1] if i % 2 == 0 and i + 1 < list.size() else c
		var up: Control = list[i - 2] if i >= 2 else seg
		var down: Control = list[i + 2] if i + 2 < list.size() else c
		c.focus_neighbor_left = c.get_path_to(left)
		c.focus_neighbor_right = c.get_path_to(right)
		c.focus_neighbor_top = c.get_path_to(up)
		c.focus_neighbor_bottom = c.get_path_to(down)
		c.focus_previous = c.get_path_to(left if left != c else up)
		c.focus_next = c.get_path_to(right if right != c else down)


func _focus_content() -> void:
	if not _focusables.is_empty():
		UiUtil.focus_later(_focusables[0])


# --- the actions ------------------------------------------------------------------------------------------------------

func _on_action(id: String) -> void:
	match id:
		"ics":
			_export_ics()
		"pause":
			_ask_pause()
		"binge":
			_ask_binge()
		"leave":
			_ask_leave()


## The .ics file (09 §2.4, V-9): written locally; the path in the status line, desktop "Ordner zeigen".
func export_ics() -> String:
	ics_path = SeasonView.export_ics(Game.state, DB.data, int(Time.get_unix_time_from_system()))
	return ics_path


func _export_ics() -> void:
	if export_ics() == "":
		Sfx.play_ui(&"ui_error")
		say("Die Kalender-Datei ließ sich nicht schreiben.")
		return
	Sfx.play_ui(&"ui_confirm")
	say("Kalender-Datei gespeichert: " + ics_path.get_file())
	var buttons: Array = [{"id": "ok", "text": "Gut"}]
	if OS.has_feature("pc") and not OS.has_feature("web"):
		buttons.insert(0, {"id": "folder", "text": "Ordner zeigen"})
	var d: Node = _dialog({"title": "Kalender-Datei gespeichert", "kicker": "SENDEPLAN · STAFFEL %d" % \
		Game.state.season.number, "lines": ["Alle Einstürze dieser Staffel als Termine, in Ihrer Kalender-App zu " +
		"öffnen.", ics_path, "Die Datei liegt nur auf diesem Gerät und enthält keinen Namen."], "buttons": buttons,
		"focus": "ok", "cancel_id": "ok"}, "ics")
	if d != null:
		d.connect("closed", func(answer: String, _days: int) -> void:
			if answer == "folder":
				OS.shell_show_in_file_manager(ics_path))


func _ask_pause() -> void:
	var left_days: int = Game.season_pause_days_left()
	if left_days <= 0:
		Sfx.play_ui(&"ui_error")
		return
	var d: Node = _dialog({"title": "Sendepause", "kicker": "STAFFEL %d" % Game.state.season.number,
		"lines": ["Die Uhr steht, alle offenen Termine rücken um die Pause nach hinten.",
		"Noch %d Tage in dieser Staffel, am Stück oder in Teilen." % left_days],
		"days": {"max": left_days, "value": 1}, "buttons": [{"id": "back", "text": "Zurück"},
		{"id": "pause", "text": "Pause machen"}], "focus": "pause", "cancel_id": "back"}, "pause")
	if d != null:
		d.connect("closed", func(answer: String, days: int) -> void:
			if answer == "pause":
				_do_pause(days))


func _do_pause(days: int) -> void:
	if not Game.season_pause_days(days):
		Sfx.play_ui(&"ui_error")
		say("Eine Sendepause geht gerade nicht.")
		return
	Sfx.play_ui(&"ui_confirm")
	refresh()
	var s: SeasonState = Game.state.season
	var at: int = SeasonView.collapse_at(s, s.on_air())
	# 09 §2.4: after a pause the tab offers the new file
	var d: Node = _dialog({"title": "Sendepause: %s" % ("1 Tag" if days == 1 else "%d Tage" % days),
		"kicker": "SENDEPLAN VERSCHOBEN", "lines": ["Etage %d stürzt jetzt %s ein." % [s.on_air(),
		SeasonView.when_text(at, _tz)], "Möchten Sie die neue Kalender-Datei speichern?"],
		"buttons": [{"id": "no", "text": "Nicht nötig"}, {"id": "ics", "text": "Kalender-Datei"}], "focus": "ics",
		"cancel_id": "no"}, "pause")
	if d != null:
		d.connect("closed", func(answer: String, _days: int) -> void:
			if answer == "ics":
				_export_ics.call_deferred())


func _ask_binge() -> void:
	var fr: FloorRun = Game.state.floor_run
	var mins: int = SeasonClock.binge_ticks(fr.index, Game.state.difficulty == &"vorabend") / SeasonClock.TICKS_PER_MIN
	var d: Node = _dialog({"title": "Am Stück weiterspielen?", "kicker": "TEMPO", "lines": [
		str(SeasonView.EXPLAIN["binge"]), "Der Countdown von Etage %d startet neu: %d:00." % [fr.index, mins],
		"Zurück in den Kalender geht es in dieser Staffel nicht mehr."], "buttons": [
		{"id": "stay", "text": "Im Kalender bleiben"}, {"id": "binge", "text": "Am Stück spielen"}],
		"focus": "stay", "cancel_id": "stay"}, "binge")
	if d != null:
		d.connect("closed", func(answer: String, _days: int) -> void:
			if answer == "binge":
				_do_binge())


func _do_binge() -> void:
	if not Game.season_tempo_binge():
		Sfx.play_ui(&"ui_error")
		say("Der Wechsel geht gerade nicht.")
		return
	Sfx.play_ui(&"ui_confirm")
	Show.say("season_tempo_binge")
	refresh()
	say("Ab jetzt: Am Stück.")


## "Staffel beenden" (09 §2.2, V-18): the clear confirmation — red, "Weiterspielen" first.
func _ask_leave() -> void:
	var s: SeasonState = Game.state.season
	var fr: FloorRun = Game.state.floor_run
	var d: Node = _dialog({"title": "Staffel %d beenden?" % s.number, "kicker": "STAFFEL BEENDEN", "danger": true,
		"lines": ["Ihre Figur steigt auf Etage %d aus und geht in die Ruhmeshalle." % (fr.index if fr != null else 1),
		"Der Speicherplatz wird frei. Die Staffel lässt sich danach nicht weiterspielen.",
		"Die KI-Kandidat:innen spielen ohne Sie weiter."], "buttons": [{"id": "stay", "text": "Weiterspielen"},
		{"id": "leave", "text": "Staffel beenden", "danger": true}], "focus": "stay", "cancel_id": "stay"}, "leave")
	if d != null:
		d.connect("closed", func(answer: String, _days: int) -> void:
			if answer == "leave":
				_do_leave())


func _do_leave() -> void:
	var menu: Node = _menu()
	if menu != null:
		menu.call("season_close")
	if not Game.season_leave():
		Sfx.play_ui(&"ui_error")
		push_warning("[SeasonTab] the season could not be left")


func _help(place: int) -> void:
	if not Game.cast_action("help", place):
		Sfx.play_ui(&"ui_error")
		say(SeasonView.cast_reason(CastSim.refusal(Game.state, DB.data, {"t": "cast", "op": "help", "who": place})))
		return
	Sfx.play_ui(&"ui_confirm")
	say("%s kommt im nächsten Kampf mit." % CastSim.label(Game.state, DB.data, place))
	show_segment("programme")
	if _focusables.is_empty():
		UiUtil.focus_later(_seg_buttons[segment] as Control)
	else:
		_focus_content()


## A season dialog over the pause menu (modal: PauseMenu.season_modal); the focus returns to `from` afterwards.
func _dialog(params: Dictionary, from: String) -> Node:
	if not ResourceLoader.exists(DIALOG):
		return null
	var d: Node = (load(DIALOG) as PackedScene).instantiate()
	d.call("setup", params)
	var menu: Node = _menu()
	if menu != null:
		menu.call("season_modal", d)
	add_child(d)
	d.connect("closed", func(_id: String, _days: int) -> void:
		if not is_inside_tree():
			return
		var back: Control = _actions.get(from) as Control
		if back == null or not is_instance_valid(back) or not back.is_visible_in_tree():
			back = _seg_buttons.get(segment) as Control
		if back != null:
			UiUtil.focus_later(back))
	return d


## The pause menu this page lives in (null in a standalone test).
func _menu() -> Node:
	var n: Node = get_parent()
	while n != null:
		if n.has_method("season_modal"):
			return n
		n = n.get_parent()
	return null
