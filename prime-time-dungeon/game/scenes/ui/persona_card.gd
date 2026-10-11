extends Control
## The candidate card (08 §1.4, §1.7, K1): the casting's page 3 builds the card panel with card_panel(); the pause menu
## (Party → "Kandidatenkarte") opens this modal: the card, the story beats (Rival:in, Sponsor) and — from K3 — the AI
## lines. The Vorsprung line (09 §8.6) appears only from 09 ST1-E; name and look change in the safe room with K2.
## Params {"capture": bool}. Esc / B / "Schließen" close it (signal closed).

signal closed()

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const InputGlyph := preload("res://scenes/ui/input_glyph.gd")
const Figure := preload("res://scenes/ui/persona_figure.gd")
const CARD_W: float = 720.0
const FIGURE_SIZE: Vector2 = Vector2(200, 236)

var persona: PersonaProfile = null

var _params: Dictionary = {}
var _close: Button
var _done: bool = false


func setup(params: Dictionary) -> void:
	_params = params


func _ready() -> void:
	UiUtil.full_rect(self)
	UiUtil.apply_theme(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	persona = Game.persona
	if persona == null and bool(_params.get("capture", false)):
		persona = demo(DB.data)
	if persona == null:
		persona = PersonaProfile.canon(DB.data)
	_build()
	UiUtil.focus_later(_close)


func _input(event: InputEvent) -> void:
	if _done or not is_visible_in_tree():
		return
	var esc: bool = event is InputEventKey and (event as InputEventKey).pressed \
		and (event as InputEventKey).keycode == KEY_ESCAPE
	var b: bool = event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed \
		and ((event as InputEventJoypadButton).button_index == JOY_BUTTON_B
			or (event as InputEventJoypadButton).button_index == JOY_BUTTON_START)
	if esc or b or (event is InputEventKey and (event as InputEventKey).pressed
			and (event as InputEventKey).keycode == KEY_P):
		get_viewport().set_input_as_handled()
		close()
	elif event.is_action(&"tab_next") or event.is_action(&"tab_prev"):
		get_viewport().set_input_as_handled()      # modal: the pause menu's tabs stay where they are


func close() -> void:
	if _done:
		return
	_done = true
	Sfx.play_ui(&"ui_cancel")
	closed.emit()
	queue_free()


## The card of `p` (08 §1.4): the stamp "STAFFEL 1 · FOLGE <floor>" (never a start number, C-17), the 3D figure, name
## and word form, Vorleben · hobby, the traits and the free texts. `text_scale` multiplies every font size (130 %).
static func card_panel(p: PersonaProfile, data: GameData, text_scale: float = 1.0, folge: int = 1) -> PanelContainer:
	var c: Dictionary = PersonaText.card(p, data)
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "Card"
	panel.custom_minimum_size = Vector2(CARD_W, 0)
	panel.add_theme_stylebox_override("panel", UiUtil.box_style(Color("#1e1430"), UiTheme.C_GOLD, 3, 0.0, 22, 16))
	var col: VBoxContainer = UiUtil.vbox(10)
	panel.add_child(col)
	var stamp_row: HBoxContainer = UiUtil.hbox(8)
	stamp_row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(stamp_row)
	var stamp: Label = UiUtil.label("STAFFEL 1 · FOLGE %d" % maxi(1, folge), &"", roundi(16 * text_scale),
		UiUtil.C_INK)
	stamp.name = "Stamp"
	stamp.add_theme_font_override("font", UiTheme.font_bold())
	stamp.add_theme_constant_override("outline_size", 0)
	var stamp_panel: PanelContainer = PanelContainer.new()
	stamp_panel.add_theme_stylebox_override("panel", UiUtil.box_style(UiTheme.C_GOLD, Color(0, 0, 0, 0), 0, 0.21, 16,
		3))
	stamp_panel.add_child(stamp)
	stamp_row.add_child(stamp_panel)
	var body: HBoxContainer = UiUtil.hbox(20)
	col.add_child(body)
	var fig: SubViewportContainer = Figure.new("kai", UiUtil.member_color("kai"))
	fig.custom_minimum_size = FIGURE_SIZE
	fig.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	body.add_child(fig)
	var texts: VBoxContainer = UiUtil.vbox(6)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(texts)
	var title: Label = UiUtil.label(UiUtil.glyph_safe(str(c["title"])), &"", roundi(32 * text_scale), UiTheme.C_TEXT)
	title.name = "Title"
	title.add_theme_font_override("font", UiTheme.font_bold())
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(title)
	for pair: Array in [["Job", str(c["job"]), UiTheme.C_ACCENT_2], ["Traits", str(c["traits"]), UiTheme.C_TEXT_DIM],
			["Free", str(c["free"]), UiTheme.C_GOLD]]:
		if str(pair[1]) == "":
			continue
		var l: Label = UiUtil.label(UiUtil.glyph_safe(str(pair[1])), &"", roundi(22 * text_scale), pair[2] as Color)
		l.name = str(pair[0])
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		texts.add_child(l)
	return panel


## A filled sample persona for stills and tests (Jana, Hebamme, Kochen & Backen, chaotisch · fürsorglich).
static func demo(data: GameData) -> PersonaProfile:
	var p: PersonaProfile = PersonaProfile.canon(data)
	p.name = "Jana"
	p.form = "f"
	p.origin = "org_care"
	p.occupation = "occ_care_midwife"
	p.hobby = "hob_cooking"
	p.traits = PackedStringArray(["trt_chaotic", "trt_caring"])
	p.source = "offline"
	p.make_beats(data, null)
	return p


func _build() -> void:
	var dim: ColorRect = ColorRect.new()
	UiUtil.full_rect(dim)
	dim.color = Color(0.03, 0.02, 0.06, 0.86)
	add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	UiUtil.full_rect(center)
	add_child(center)
	var outer: PanelContainer = UiUtil.panel(&"PanelMenu")
	center.add_child(outer)
	var col: VBoxContainer = UiUtil.vbox(12)
	outer.add_child(col)
	var head: HBoxContainer = UiUtil.hbox(14)
	col.add_child(head)
	var h: Label = UiUtil.label("KANDIDATENKARTE", &"LabelHeader")
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(h)
	head.add_child(InputGlyph.make(&"ui_cancel", "Schließen", 16))
	var folge: int = Game.state.floor_run.index if Game.state != null and Game.state.floor_run != null else 1
	col.add_child(card_panel(persona, DB.data, 1.0, folge))
	var beats: VBoxContainer = UiUtil.vbox(4)
	beats.name = "Beats"
	col.add_child(beats)
	var ctx: Dictionary = PersonaText.ctx(persona, DB.data, null)
	for pair: Array in [["Rival:in", str(ctx["rival"])], ["Sponsor", str(ctx["brand"])]]:
		var row: HBoxContainer = UiUtil.hbox(12)
		var k: Label = UiUtil.label(str(pair[0]), &"", 22, UiTheme.C_ACCENT)
		k.custom_minimum_size = Vector2(150, 0)
		row.add_child(k)
		row.add_child(UiUtil.label(UiUtil.glyph_safe(str(pair[1])), &"", 22))
		beats.add_child(row)
	var note: Label = UiUtil.label("Vorleben, Hobby und Eigenschaften gelten für die ganze Sendung. Vertrag ist Vertrag.",
		&"LabelSmall", 16, UiTheme.C_TEXT_DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(CARD_W, 0)
	col.add_child(note)
	_close = UiUtil.close_button("Schließen")
	_close.size_flags_horizontal = Control.SIZE_SHRINK_END
	_close.pressed.connect(close)
	col.add_child(_close)
	for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:   # modal: the focus never leaves the card
		_close.set_focus_neighbor(side, _close.get_path_to(_close))
	_close.focus_next = _close.get_path_to(_close)
	_close.focus_previous = _close.get_path_to(_close)
