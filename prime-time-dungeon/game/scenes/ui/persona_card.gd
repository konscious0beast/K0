extends Control
## The candidate card (08 §1.4, §1.7, K1): the casting's page 3 builds the card panel with card_panel(); the pause menu
## (Party → "Kandidatenkarte") opens this modal: the card, the story beats (Rival:in, Sponsor) and — from K3 — the AI
## lines. The Vorsprung line (09 §8.6) appears only from 09 ST1-E. K2 (08 §1.7): the figure wears the card's look, and
## "Name & Aussehen ändern" opens the casting's 1/3 in edit mode — only in a safe room ("Bitte in die Maske — nur im
## Safe Room." elsewhere); after "Übernehmen" the card shows the new name and look.
## Params {"capture": bool, "edit_open": bool (stills: the editor at once)}. Esc / B / "Schließen" close it (signal
## closed).

signal closed()

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const InputGlyph := preload("res://scenes/ui/input_glyph.gd")
const Figure := preload("res://scenes/ui/persona_figure.gd")
const CASTING: String = "res://scenes/title/persona_casting.tscn"
const CARD_W: float = 720.0
const FIGURE_SIZE: Vector2 = Vector2(200, 236)
const MASK_NOTE: String = "Bitte in die Maske — nur im Safe Room."
## A look for the demo persona (stills, tests): Jana the midwife.
const DEMO_LOOK: Dictionary = {"hair": "lk_hair_bun", "hair_color": "lk_hc_chestnut", "skin": "lk_skin_4",
	"beard": "lk_beard_none", "glasses": "lk_glasses_round", "outfit": "lk_outfit_white"}

var persona: PersonaProfile = null
var edit_button: Button = null              # K2: "Name & Aussehen ändern"
var editor: Control = null                  # K2: the open casting 1/3 in edit mode

var _params: Dictionary = {}
var _close: Button
var _done: bool = false
var _note: Label = null


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
	if bool(_params.get("edit_open", false)):
		open_editor.call_deferred()


## K2 (08 §1.7): name and look change only in a safe room (RunRules.in_safe_room) and only for the running persona.
func can_edit() -> bool:
	return Game.persona != null and Game.state != null and RunRules.in_safe_room(Game.state)


## K2: "Name & Aussehen ändern" — the casting's 1/3 in edit mode above the card (same canvas layer, input goes to it
## first), or outside a safe room the note "Bitte in die Maske — nur im Safe Room.". Returns the editor (or null).
func open_editor() -> Control:
	if editor != null and is_instance_valid(editor):
		return editor
	if not can_edit():
		Sfx.play_ui(&"ui_error")
		if _note != null:
			_note.text = MASK_NOTE
			_note.add_theme_color_override("font_color", UiTheme.C_GOLD)
		return null
	var e: Control = (load(CASTING) as PackedScene).instantiate() as Control
	e.call("setup", {"edit": true, "slot": Game.state.slot, "hero": Game.hero()})
	e.process_mode = Node.PROCESS_MODE_ALWAYS     # the pause menu pauses the tree
	e.connect("edit_finished", _on_editor_finished)
	add_child(e)
	editor = e
	return e


func _on_editor_finished(applied: bool) -> void:
	editor = null
	if applied:
		persona = Game.persona
		for c: Node in get_children():
			c.queue_free()
		_build.call_deferred()
		UiUtil.focus_later.call_deferred(_close)
	elif edit_button != null and is_instance_valid(edit_button):
		UiUtil.focus_later(edit_button)


func _input(event: InputEvent) -> void:
	if _done or not is_visible_in_tree() or (editor != null and is_instance_valid(editor)):
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
	var fig: SubViewportContainer = Figure.new("kai", UiUtil.member_color("kai"), p.look)   # K2: the card's look
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
	p.look = PersonaProfile.clean_look(DEMO_LOOK, data)
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
	_note = UiUtil.label("Vorleben, Hobby und Eigenschaften gelten für die ganze Sendung. Vertrag ist Vertrag.",
		&"LabelSmall", 16, UiTheme.C_TEXT_DIM)
	_note.name = "Note"
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size = Vector2(CARD_W, 0)
	col.add_child(_note)
	var foot: HBoxContainer = UiUtil.hbox(16)
	col.add_child(foot)
	edit_button = null
	if Game.persona != null:                     # K2 (08 §1.7): name and look — in the safe room
		edit_button = UiUtil.button("Name & Aussehen ändern", &"")
		edit_button.name = "EditLook"
		edit_button.custom_minimum_size = Vector2(320, 0)
		edit_button.add_theme_font_size_override("font_size", 22)
		UiUtil.touch_pad(edit_button)
		edit_button.pressed.connect(open_editor)
		foot.add_child(edit_button)
	foot.add_child(UiUtil.spacer(0.0, 0.0, true))
	_close = UiUtil.close_button("Schließen")
	_close.size_flags_horizontal = Control.SIZE_SHRINK_END
	_close.pressed.connect(close)
	foot.add_child(_close)
	var stops: Array[Control] = []
	if edit_button != null:
		stops.append(edit_button)
	stops.append(_close)
	for i in stops.size():                       # modal: the focus never leaves the card
		var c: Control = stops[i]
		var other: Control = stops[(i + 1) % stops.size()]
		for side: Side in [SIDE_LEFT, SIDE_RIGHT]:
			c.set_focus_neighbor(side, c.get_path_to(other))
		for side: Side in [SIDE_TOP, SIDE_BOTTOM]:
			c.set_focus_neighbor(side, c.get_path_to(c))
		c.focus_next = c.get_path_to(other)
		c.focus_previous = c.get_path_to(other)
