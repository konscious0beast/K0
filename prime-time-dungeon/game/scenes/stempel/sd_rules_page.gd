extends RefCounted
## The rules page (10 §4.7 "Regeln"): the five sentences, the glossary and the controls of the current input scheme;
## from the hall also "Lernduell wiederholen". A modal with a scroll column. Private helper: open(parent, on_tutorial)
## (on_tutorial invalid = no button).

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const SdStyle := preload("res://scenes/stempel/sd_style.gd")
const SdModal := preload("res://scenes/stempel/sd_modal.gd")
const SdTexts := preload("res://scenes/stempel/sd_texts.gd")


static func open(parent: Node, on_tutorial: Callable = Callable()) -> Node:
	var body: int = SdStyle.min_text(Game.input_scheme == Game.InputScheme.TOUCH) + 2
	var m: Node = SdModal.new()
	m.call("setup", "REGELN", 860.0)
	m.name = "Rules"
	var box: VBoxContainer = m.get("content") as VBoxContainer
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(820, 430)
	scroll.focus_mode = Control.FOCUS_ALL
	box.add_child(scroll)
	var col: VBoxContainer = UiUtil.vbox(8)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(col)
	col.add_child(SdStyle.label("In fünf Sätzen", 22, SdStyle.GOLD, true))
	for row: Array in SdTexts.rules_rows():
		var h: HBoxContainer = UiUtil.hbox(12)
		col.add_child(h)
		var k: Label = SdStyle.label(str(row[0]), body, SdStyle.GOLD, true)
		k.custom_minimum_size = Vector2(190, 0)
		h.add_child(k)
		var v: Label = SdStyle.label(str(row[1]), body, SdStyle.TEXT)
		v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.custom_minimum_size = Vector2(560, 0)
		h.add_child(v)
		if str(row[0]) == "5.":
			col.add_child(UiUtil.spacer(6))
			col.add_child(SdStyle.label("Wörterbuch", 22, SdStyle.GOLD, true))
	col.add_child(UiUtil.spacer(6))
	var scheme: int = Game.input_scheme
	var idx: int = 1 if scheme == Game.InputScheme.KEYBOARD_MOUSE else (2 if scheme == Game.InputScheme.GAMEPAD else 3)
	col.add_child(SdStyle.label("Steuerung (%s)" % ["", "Tastatur", "Gamepad", "Touch"][idx], 22, SdStyle.GOLD, true))
	for c: Array in SdTexts.CONTROLS:
		var h2: HBoxContainer = UiUtil.hbox(12)
		col.add_child(h2)
		var k2: Label = SdStyle.label(str(c[0]), body, SdStyle.TEXT_DIM, true)
		k2.custom_minimum_size = Vector2(190, 0)
		h2.add_child(k2)
		var v2: Label = SdStyle.label(str(c[idx]), body, SdStyle.TEXT)
		v2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v2.custom_minimum_size = Vector2(560, 0)
		h2.add_child(v2)
	if on_tutorial.is_valid():
		var b: Button = UiUtil.button("Lernduell wiederholen", &"ButtonBig")
		b.name = "Tutorial"
		UiUtil.touch_pad(b)
		b.pressed.connect(func() -> void:
			m.call("close")
			on_tutorial.call())
		box.add_child(b)
	parent.add_child(m)
	return m
