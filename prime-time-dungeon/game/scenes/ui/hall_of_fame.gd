extends Control
## Ruhmeshalle (09 §2.7, §2.8; ST1-H) — every figure of a finished season on this device, newest first (Save.career():
## "hall"), and the titles of the career at the top. Look, do not play on: a finished season does not load (B-18) —
## its slot opens this screen. Left the list (one focusable card per season: number, result, format, Quote and place),
## right the card in focus in full (result, dates, titles as chips, the figures by class — never a name, 08 P-1 — and
## the stats of the Quote). Params {"from": "title" | "setup" | "summary", "slot": int (a finished slot was chosen:
## its season is marked)}; "Zurück" goes back to where it came from (the setup of a new season or the title).

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const UiIcon := preload("res://scenes/ui/ui_icon.gd")
const InputGlyph := preload("res://scenes/ui/input_glyph.gd")
const Backdrop := preload("res://scenes/ui/broadcast_bg.gd")
const SeasonView := preload("res://scenes/ui/season_view.gd")
const SETUP: String = "res://scenes/title/season_setup.tscn"
const LIST_W: float = 500.0

var cards: Array[Button] = []                # one per hall entry (tests)
var back_button: Button
var selected: int = -1

var _params: Dictionary = {}
var _hall: Array[Dictionary] = []
var _busy: bool = false
var _detail: VBoxContainer


func setup(params: Dictionary) -> void:
	_params = params


func _ready() -> void:
	UiUtil.full_rect(self)
	Events.overlay_mode_requested.emit.call_deferred(&"menu")
	_hall = Save.career_hall()
	_build()
	var mark: int = _marked()
	if not cards.is_empty():
		select(maxi(0, mark))
		UiUtil.focus_later(cards[maxi(0, mark)])
	else:
		UiUtil.focus_later(back_button)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		back()


func back() -> void:
	if _busy:
		return
	_busy = true
	Sfx.play_ui(&"ui_cancel")
	if str(_params.get("from", "")) == "setup":
		Router.goto(SETUP, {"mode": "new"})
	else:
		Router.goto(Router.SCENE_TITLE)


## Shows entry `i` in the detail card.
func select(i: int) -> void:
	if i < 0 or i >= _hall.size():
		return
	selected = i
	for j in cards.size():
		cards[j].button_pressed = j == i
	_fill_detail(_hall[i])


# --- build ------------------------------------------------------------------------------------------------------------

func _build() -> void:
	add_child(Backdrop.new())
	var safe: SafeAreaContainer = SafeAreaContainer.new()
	safe.extra = 0
	add_child(safe)
	var col: VBoxContainer = UiUtil.vbox(12)                    # 12 px between the list's targets and "Zurück"
	col.name = "Column"
	safe.add_child(col)
	var head: HBoxContainer = UiUtil.hbox(14)
	col.add_child(head)
	var titles: VBoxContainer = UiUtil.vbox(-2)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(titles)
	var kicker: Label = UiUtil.label("KARRIERE · NUR AUF DIESEM GERÄT", &"", 18, UiTheme.C_ACCENT)
	kicker.add_theme_font_override("font", UiTheme.font_bold())
	titles.add_child(kicker)
	titles.add_child(UiUtil.label("RUHMESHALLE", &"LabelTitle", 46))
	var earned: PackedStringArray = Save.career_titles()
	var tl: Label = UiUtil.label(UiUtil.glyph_safe("Ihre Titel: " + (" · ".join(earned) if not earned.is_empty()
		else "noch keine — Titel gibt es für das Große Finale.")), &"", 18, UiTheme.C_GOLD if not earned.is_empty()
		else UiTheme.C_TEXT_DIM)
	tl.name = "Titles"
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tl.custom_minimum_size = Vector2(700, 0)
	titles.add_child(tl)
	var glyph: Control = InputGlyph.make(&"ui_cancel", "Zurück", 16)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	head.add_child(glyph)
	var body: HBoxContainer = UiUtil.hbox(24)
	body.name = "Body"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	if _hall.is_empty():
		var empty: Label = UiUtil.label(UiUtil.glyph_safe("Noch leer. Wer eine Staffel beendet, bekommt hier einen " +
			"Platz — mit Ergebnis, Quote und Etage. Die Figur bleibt zum Ansehen, nicht zum Weiterspielen."), &"", 20,
			UiTheme.C_TEXT_DIM)
		empty.name = "Empty"
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.add_child(empty)
	else:
		body.add_child(_list())
		var card: PanelContainer = PanelContainer.new()
		card.name = "Detail"
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		card.add_theme_stylebox_override("panel", UiUtil.box_style(Color(UiUtil.C_INK, 0.82),
			Color(UiTheme.C_ACCENT_2, 0.45), 2, 0.0, 20, 14))
		body.add_child(card)
		_detail = UiUtil.vbox(8)
		card.add_child(_detail)
	var brow: HBoxContainer = UiUtil.hbox(16)
	brow.name = "Buttons"
	col.add_child(brow)
	back_button = UiUtil.button("Zurück", &"ButtonBig")
	back_button.name = "Btn_back"
	back_button.custom_minimum_size = Vector2(220, 0)
	UiUtil.touch_pad(back_button, 64.0)
	back_button.pressed.connect(back)
	brow.add_child(back_button)
	_wire()


func _list() -> Control:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "List"
	scroll.custom_minimum_size = Vector2(LIST_W, 0)
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var list: VBoxContainer = UiUtil.vbox(12)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for i in _hall.size():
		var b: Button = _entry_card(_hall[i], i)
		list.add_child(b)
		cards.append(b)
	return scroll


## One season: "Staffel 3 · Großes Finale gewonnen" over "Basis · Kalender · Mit Netz · Quote 12.400 · Platz 4".
func _entry_card(e: Dictionary, i: int) -> Button:
	var b: Button = UiUtil.button("", &"ButtonFlat")
	b.name = "Entry_%d" % i
	b.toggle_mode = true
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiUtil.touch_pad(b, 76.0)
	var row: HBoxContainer = UiUtil.hbox(12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiUtil.full_rect(row)
	row.offset_left = 14
	row.offset_right = -14
	b.add_child(row)
	var res: String = str(e.get("result", ""))
	var finale: bool = res == "finalist"
	var ic: Control = UiIcon.make(&"trophy" if finale else (&"star" if res == "end" else &"tv"),
		UiTheme.C_GOLD if finale else UiTheme.C_ACCENT_2, 26)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	var texts: VBoxContainer = UiUtil.vbox(0)
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(texts)
	var t: Label = UiUtil.label(UiUtil.glyph_safe("Staffel %d · %s" % [int(e.get("number", 0)),
		SeasonView.result_title(res, int(e.get("floor", 0)))]), &"", 18, UiTheme.C_GOLD if finale else UiTheme.C_TEXT)
	t.name = "Text"
	t.add_theme_font_override("font", UiTheme.font_bold())
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	texts.add_child(t)
	var sub: Label = UiUtil.label(UiUtil.glyph_safe(_short_line(e)), &"", 16, UiTheme.C_TEXT_DIM)
	sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	texts.add_child(sub)
	b.focus_entered.connect(func() -> void: select(i))
	b.pressed.connect(func() -> void: select(i))
	return b


func _short_line(e: Dictionary) -> String:
	var parts: PackedStringArray = [str(SeasonView.FORMAT_NAMES.get(int(e.get("format", 6)), "Staffel")),
		str(SeasonView.TEMPO_NAMES.get(str(e.get("tempo", "")), "")), str(SeasonView.MODE_NAMES.get(str(e.get("mode",
		"")), "")), "Quote %s" % UiUtil.fmt_int(int(e.get("quote", 0)))]
	if int(e.get("rank", 0)) > 0:
		parts.append("Platz %d" % int(e["rank"]))
	return " · ".join(parts)


func _fill_detail(e: Dictionary) -> void:
	if _detail == null:
		return
	for c: Node in _detail.get_children():
		_detail.remove_child(c)
		c.queue_free()
	var res: String = str(e.get("result", ""))
	var k: Label = UiUtil.label(UiUtil.glyph_safe(("STAFFEL %d · " % int(e.get("number", 0))) + _short_line(e).to_upper()),
		&"", 16, UiTheme.C_ACCENT)
	k.add_theme_font_override("font", UiTheme.font_bold())
	k.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_detail.add_child(k)
	var t: Label = UiUtil.label(UiUtil.glyph_safe(SeasonView.result_title(res, int(e.get("floor", 0)))),
		&"LabelHeader", 28, UiTheme.C_GOLD if res == "finalist" else UiTheme.C_TEXT)
	t.name = "Result"
	_detail.add_child(t)
	var dates: Label = UiUtil.label("Tag 0: %s · beendet: %s" % [_date(int(e.get("day0", 0))), _date(int(e.get("ended",
		0)))], &"", 16, UiTheme.C_TEXT_DIM)
	_detail.add_child(dates)
	var fig: Label = UiUtil.label(UiUtil.glyph_safe(SeasonView.figures_text(DB.data, e)), &"", 17, UiTheme.C_TEXT)
	fig.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(fig)
	var titles: Array = e.get("titles", []) as Array
	if not titles.is_empty():
		var flow: HFlowContainer = HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 8)
		flow.add_theme_constant_override("v_separation", 8)
		_detail.add_child(flow)
		for tt: Variant in titles:
			flow.add_child(_chip(str(tt)))
	var grid: GridContainer = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 4)
	_detail.add_child(grid)
	for pair: Array in SeasonView.stat_pairs(e):
		grid.add_child(UiUtil.label(str(pair[0]), &"", 16, UiTheme.C_TEXT_DIM))
		var v: Label = UiUtil.label(UiUtil.glyph_safe(str(pair[1])), &"", 17, UiTheme.C_TEXT)
		v.add_theme_font_override("font", UiTheme.font_bold())
		v.custom_minimum_size = Vector2(100, 0)
		grid.add_child(v)


## "15.10.2026" (local).
static func _date(utc: int) -> String:
	if utc <= 0:
		return "—"
	var d: Dictionary = Time.get_datetime_dict_from_unix_time(utc + SeasonView.tz_offset())
	return "%d.%d.%d" % [int(d["day"]), int(d["month"]), int(d["year"])]


func _chip(text: String) -> Control:
	var p: PanelContainer = PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiUtil.box_style(Color(UiTheme.C_GOLD, 0.16), UiTheme.C_GOLD, 2, 0.0, 12, 5))
	var l: Label = UiUtil.label(UiUtil.glyph_safe(text), &"", 17, UiTheme.C_GOLD)
	l.add_theme_font_override("font", UiTheme.font_bold())
	p.add_child(l)
	return p


## The card of the season of the chosen slot (params "slot"); -1 without one.
func _marked() -> int:
	var slot: int = int(_params.get("slot", 0))
	if slot <= 0:
		return -1
	var sm: Variant = Save.slot_summary(slot).get("season", null)
	if not sm is Dictionary:
		return -1
	var ss: Dictionary = sm
	for i in _hall.size():
		if str(_hall[i].get("def", "")) == str(ss.get("def", "")) and int(_hall[i].get("number", 0)) == int(ss.get(
				"number", -1)):
			return i
	return -1


## The cards top to bottom, "Zurück" below them (and up from it to the last card).
func _wire() -> void:
	var list: Array[Control] = []
	for c: Button in cards:
		list.append(c)
	list.append(back_button)
	UiUtil.wire_vertical(list)
	for c2: Control in list:
		c2.focus_neighbor_left = c2.get_path_to(c2)
		c2.focus_neighbor_right = c2.get_path_to(c2)
