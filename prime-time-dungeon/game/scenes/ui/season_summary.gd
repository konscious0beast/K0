extends Control
## Staffel-Bilanz and Finale (09 §2.7, §7.2; ST1-H) — where every finished season ends for the candidate: the Abspann
## of the Großes Finale ("Finalist:in"), "Bis zum Ende dabei" after the last collapse, a studio guest's Sendeschluss
## ("Verschüttet / Gefallen auf Etage N") and "Staffel beenden" ("Ausgestiegen auf Etage N"). Game routes here
## instead of the campaign credits (Game._season_end_path; the Sendeschluss screen links here). Shows the result,
## M.O.D.'s line, the titles earned (only cosmetic, 09 §2.7), the figures (classes, no name), the stats of the Quote,
## and on the right the final ranking — for a studio guest or a candidate who left the "Zeitraffer bis zum Finale"
## (09 §7.2, offline ST1: the AI cast plays the rest of the season on a copy of the state, SeasonView.projection). The
## entry of the hall of fame is written once (Save.career_hall_add; Game writes it with the season's save already).
## Buttons: Ruhmeshalle · Zum Titel. Params {"capture": bool}. Reads Game.state; changes nothing recorded.

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const UiIcon := preload("res://scenes/ui/ui_icon.gd")
const InputGlyph := preload("res://scenes/ui/input_glyph.gd")
const Backdrop := preload("res://scenes/ui/broadcast_bg.gd")
const SeasonView := preload("res://scenes/ui/season_view.gd")
const CARD_W: float = 560.0

var buttons: Dictionary = {}                 # id → Button (hall | title)
var entry: Dictionary = {}                   # the hall-of-fame entry shown (SeasonView.hall_entry)
var projected: bool = false                  # the ranking is the Zeitraffer to the finale

var _params: Dictionary = {}
var _busy: bool = false


func setup(params: Dictionary) -> void:
	_params = params


func _ready() -> void:
	UiUtil.full_rect(self)
	Events.overlay_mode_requested.emit.call_deferred(&"menu")
	var st: GameState = Game.state
	if st != null and st.season != null and st.season.result != "":
		entry = SeasonView.hall_entry(st, DB.data, int(Time.get_unix_time_from_system()))
		if not Save.career_hall_has(str(entry["key"])):
			Save.career_hall_add(entry)
	_build()
	UiUtil.focus_later(buttons.get("title") as Control)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		to_title()


func to_title() -> void:
	if _busy:
		return
	_busy = true
	Sfx.play_ui(&"ui_confirm")
	Router.goto(Router.SCENE_TITLE)


func open_hall() -> void:
	if _busy:
		return
	_busy = true
	Sfx.play_ui(&"ui_confirm")
	Router.goto(Game.SCENE_HALL_OF_FAME, {"from": "summary"})


# --- build ------------------------------------------------------------------------------------------------------------

func _build() -> void:
	add_child(Backdrop.new())
	var safe: SafeAreaContainer = SafeAreaContainer.new()
	safe.extra = 0
	add_child(safe)
	var col: VBoxContainer = UiUtil.vbox(8)
	col.name = "Column"
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	safe.add_child(col)
	if entry.is_empty():
		col.add_child(UiUtil.label("KEINE STAFFEL", &"LabelTitle", 44))
		col.add_child(_line("Hier erscheint die Bilanz, sobald eine Staffel für Sie zu Ende ist.", 19,
			UiTheme.C_TEXT_DIM))
		col.add_child(_button_row())
		return
	var st: GameState = Game.state
	var s: SeasonState = st.season
	var result: String = str(entry["result"])
	var finale: bool = result == "finalist"
	var kicker: Label = UiUtil.label(UiUtil.glyph_safe(("ABSPANN · " if finale else "") + "STAFFEL-BILANZ · " +
		SeasonView.head_text(st).to_upper()), &"", 18, UiTheme.C_GOLD if finale else UiTheme.C_ACCENT)
	kicker.name = "Kicker"
	kicker.add_theme_font_override("font", UiTheme.font_bold())
	col.add_child(kicker)
	var title: Label = UiUtil.label(UiUtil.glyph_safe(SeasonView.result_title(result, int(entry["floor"])).to_upper()
		.replace("ß", "SS")), &"LabelTitle", 46)
	title.name = "Title"
	if finale:
		title.add_theme_color_override("font_color", UiTheme.C_GOLD)
	col.add_child(title)
	col.add_child(_line(_sub_text(st), 18, UiTheme.C_TEXT_DIM))
	var quote: String = UiUtil.mod_line(SeasonView.result_tag(result), {"floor": int(entry["floor"]),
		"count": s.number}, s.number)
	if quote != "":
		var q: HBoxContainer = UiUtil.hbox(10)
		q.name = "Mod"
		var tag: Label = UiUtil.label("M.O.D.", &"", 18, UiTheme.C_ACCENT)
		tag.add_theme_font_override("font", UiTheme.font_bold())
		tag.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		q.add_child(tag)
		var ql: Label = UiUtil.label(UiUtil.glyph_safe("„%s“" % quote), &"", 19)
		ql.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ql.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		q.add_child(ql)
		col.add_child(q)
	col.add_child(UiUtil.spacer(4))
	var body: HBoxContainer = UiUtil.hbox(24)
	body.name = "Body"
	col.add_child(body)
	body.add_child(_left_card())
	body.add_child(_right_card(st))
	col.add_child(UiUtil.spacer(4))
	col.add_child(_button_row())


## "Tag 19 von 24 · Etage 6 · Kandidat:in (Abrissbirne) · Graf Mopsula (…)".
func _sub_text(st: GameState) -> String:
	var s: SeasonState = st.season
	var parts: PackedStringArray = []
	if s.tempo == "calendar":
		parts.append("Tag %d von %d" % [clampi(SeasonView.season_day(st), 0, SeasonClock.format_days(s.format)),
			SeasonClock.format_days(s.format)])
	parts.append("Etage %d" % int(entry["floor"]))
	parts.append(SeasonView.figures_text(DB.data, entry))
	return " · ".join(parts)


## The titles (chips; or why there is none) and the stats of the Quote.
func _left_card() -> Control:
	var card: PanelContainer = _card("Stats")
	card.custom_minimum_size = Vector2(CARD_W, 0)
	var v: VBoxContainer = UiUtil.vbox(8)
	card.add_child(v)
	v.add_child(_head("TITEL", UiTheme.C_GOLD))
	var titles: Array = entry.get("titles", []) as Array
	if titles.is_empty():
		v.add_child(_line("Keine Titel diesmal — sie gibt es für das Finale, die weiße Weste, Ohne Netz und " +
			"Berufe auf 300.", 16, UiTheme.C_TEXT_DIM))
	else:
		var flow: HFlowContainer = HFlowContainer.new()
		flow.name = "Titles"
		flow.add_theme_constant_override("h_separation", 8)
		flow.add_theme_constant_override("v_separation", 8)
		v.add_child(flow)
		for t: Variant in titles:
			flow.add_child(_chip(str(t)))
	v.add_child(UiUtil.spacer(2))
	v.add_child(_head("QUOTE UND ZAHLEN", UiTheme.C_ACCENT_2))
	var grid: GridContainer = GridContainer.new()
	grid.name = "Grid"
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 4)
	v.add_child(grid)
	for pair: Array in SeasonView.stat_pairs(entry):
		var k: Label = UiUtil.label(str(pair[0]), &"", 16, UiTheme.C_TEXT_DIM)
		grid.add_child(k)
		var val: Label = UiUtil.label(UiUtil.glyph_safe(str(pair[1])), &"", 17, UiTheme.C_TEXT)
		val.add_theme_font_override("font", UiTheme.font_bold())
		val.custom_minimum_size = Vector2(110, 0)
		grid.add_child(val)
	return card


## The final ranking (a finalist, the end) or the Zeitraffer bis zum Finale (a studio guest, a candidate who left).
func _right_card(st: GameState) -> Control:
	var card: PanelContainer = _card("Ranking")
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v: VBoxContainer = UiUtil.vbox(4)
	card.add_child(v)
	var s: SeasonState = st.season
	var guest: bool = s.result == "fallen" or s.result == "buried" or s.result == "left"
	var rows: Array[Dictionary] = []
	if CastSim.has_cast(st):
		projected = guest and not SeasonRules.season_over(st)
		rows = SeasonView.projection(st, DB.data, 5, 1) if projected else SeasonView.ranking_rows(st, DB.data, 5, 1)
	v.add_child(_head("ZEITRAFFER BIS ZUM FINALE" if projected else "RANGLISTE", UiTheme.C_ACCENT))
	if rows.is_empty():
		v.add_child(_line(str(SeasonView.CAST_REASONS["no_cast"]), 16, UiTheme.C_TEXT_DIM))
		return card
	v.add_child(_line("So endet die Staffel, wenn die KI ohne Sie weiterspielt — Ihr Platz steht schon fest."
		if projected else str(SeasonView.EXPLAIN["cast"]), 16, UiTheme.C_TEXT_DIM))
	for r: Dictionary in rows:
		v.add_child(_rank_row(r))
	return card


func _rank_row(r: Dictionary) -> Control:
	if bool(r.get("gap", false)):
		var g: Label = UiUtil.label("· · ·", &"", 16, UiTheme.C_TEXT_DIM)
		g.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		return g
	var me: bool = bool(r["me"])
	var col: Color = UiTheme.C_GOLD if me else UiTheme.C_TEXT
	var row: HBoxContainer = UiUtil.hbox(10)
	row.name = "Rank_%d" % int(r["rank"])
	var n: Label = UiUtil.label("%d." % int(r["rank"]), &"", 17, col)
	n.add_theme_font_override("font", UiTheme.font_mono())
	n.custom_minimum_size = Vector2(52, 0)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(n)
	var who: Label = UiUtil.label(UiUtil.glyph_safe(str(r["label"]) + (" · Sie" if me else "")), &"", 17, col)
	if me:
		who.add_theme_font_override("font", UiTheme.font_bold())
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(who)
	var res: String = str(r["result"])
	var words: Dictionary = {"finalist": "Finale", "end": "am Ende", "fallen": "raus", "buried": "raus",
		"left": "ausgestiegen"}
	var where: Label = UiUtil.label(str(words.get(res, "Etage %d" % int(r["floor"]))), &"", 16, UiTheme.C_TEXT_DIM)
	where.custom_minimum_size = Vector2(100, 0)
	row.add_child(where)
	var q: Label = UiUtil.label(UiUtil.fmt_int(int(r["quote"])), &"", 16, col)
	q.add_theme_font_override("font", UiTheme.font_mono())
	q.custom_minimum_size = Vector2(80, 0)
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(q)
	return row


func _button_row() -> HBoxContainer:
	var row: HBoxContainer = UiUtil.hbox(16)
	row.name = "Buttons"
	var list: Array[Control] = []
	if not Save.career_hall().is_empty():
		var hall: Button = _big("hall", "Ruhmeshalle", 260.0)
		hall.pressed.connect(open_hall)
		row.add_child(hall)
		list.append(hall)
	row.add_child(UiUtil.spacer(0, 0, true))
	var glyph: Control = InputGlyph.make(&"ui_cancel", "Zum Titel", 16)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(glyph)
	var title: Button = _big("title", "Zum Titel", 260.0)
	var gold: StyleBoxFlat = UiUtil.box_style(Color(0.25, 0.17, 0.08, 0.95), UiTheme.C_GOLD, 3, 0.0, 24, 20)
	gold.expand_margin_top = -12.0
	gold.expand_margin_bottom = -12.0
	title.add_theme_stylebox_override("normal", gold)
	title.add_theme_color_override("font_color", UiTheme.C_GOLD)
	title.pressed.connect(to_title)
	row.add_child(title)
	list.append(title)
	UiUtil.wire_horizontal(list)
	for c: Control in list:
		c.focus_neighbor_top = c.get_path_to(c)
		c.focus_neighbor_bottom = c.get_path_to(c)
	return row


func _big(id: String, text: String, w: float) -> Button:
	var b: Button = UiUtil.button(text, &"ButtonBig")
	b.name = "Btn_" + id
	b.custom_minimum_size = Vector2(w, 0)
	UiUtil.touch_pad(b, 64.0)
	buttons[id] = b
	return b


func _card(node_name: String) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.name = node_name
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	card.add_theme_stylebox_override("panel", UiUtil.box_style(Color(UiUtil.C_INK, 0.82), Color(UiTheme.C_ACCENT_2,
		0.45), 2, 0.0, 20, 14))
	return card


func _head(text: String, color: Color) -> Label:
	var l: Label = UiUtil.label(text, &"", 17, color)
	l.add_theme_font_override("font", UiTheme.font_bold())
	return l


func _line(text: String, px: int, color: Color) -> Label:
	var l: Label = UiUtil.label(UiUtil.glyph_safe(text), &"", px, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


## A title as a gold chip (09 §2.7: only cosmetic).
func _chip(text: String) -> Control:
	var p: PanelContainer = PanelContainer.new()
	p.name = "Chip"
	p.add_theme_stylebox_override("panel", UiUtil.box_style(Color(UiTheme.C_GOLD, 0.16), UiTheme.C_GOLD, 2, 0.0, 12, 5))
	var h: HBoxContainer = UiUtil.hbox(6)
	p.add_child(h)
	var ic: Control = UiIcon.make(&"star", UiTheme.C_GOLD, 18)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	var l: Label = UiUtil.label(UiUtil.glyph_safe(text), &"", 17, UiTheme.C_GOLD)
	l.add_theme_font_override("font", UiTheme.font_bold())
	h.add_child(l)
	return p
