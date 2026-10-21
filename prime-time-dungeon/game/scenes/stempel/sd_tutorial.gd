extends RefCounted
## The Lernduell's lesson cards (10 §1.10): one small card per lesson of rules.json → tutorial.lessons, shown at its
## number (a lesson at an opponent's number after that move), the duel waits until it is dismissed (no clock runs).
## The text is the lesson line (sd_tut:<step>, the touch wording); with keyboard or gamepad a "<tag>:keys" variant is
## used when the data has one, and a row of key symbols (input_glyph.gd) names the keys of the lesson's move. The Graf's
## footnote (note) follows in gold. The first card offers "Ich kenne mich aus" (skip: the Grundakte at once). The
## forced card itself is highlighted on the table (sd_card_view.gd highlight). Private helper.

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const InputGlyph := preload("res://scenes/ui/input_glyph.gd")
const SdStyle := preload("res://scenes/stempel/sd_style.gd")
const SdModal := preload("res://scenes/stempel/sd_modal.gd")

const STEPS: int = 6


## The lesson card over `table` (a modal with "closed"; meta "skipped" when "Ich kenne mich aus" was pressed).
static func lesson_card(table: Node, lesson: Dictionary, first: bool) -> Node:
	var book: SdRulebook = table.get("book") as SdRulebook
	var touch: bool = bool(table.get("touch"))
	var step: int = JsonUtil.to_int(lesson.get("step", 0))
	var m: Node = SdModal.new()
	m.call("setup", "LERNDUELL · Schritt %d von %d" % [step, STEPS], 760.0, SdStyle.GOLD, 0.15, false)
	m.name = "Lesson%d" % step
	(m.get("title_label") as Label).add_theme_font_size_override("font_size", 22)
	var box: VBoxContainer = m.get("content") as VBoxContainer
	box.add_theme_constant_override("separation", 8)
	var text: String = lesson_text(book, lesson, touch)
	var t: Label = SdStyle.label(text, 20, SdStyle.TEXT)
	t.name = "Text"
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(720, 0)
	box.add_child(t)
	var note: String = note_text(book, lesson)
	if note != "":
		var n: Label = SdStyle.label("Graf Mopsula: " + note, 18 if not touch else 20, SdStyle.GOLD)
		n.name = "Note"
		n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		n.custom_minimum_size = Vector2(720, 0)
		box.add_child(n)
	# the key symbols (keyboard / gamepad) left, the buttons right — one row keeps the card low
	var row: HBoxContainer = UiUtil.hbox(12)
	box.add_child(row)
	if not touch:
		var keys: HBoxContainer = UiUtil.hbox(10)
		keys.name = "Keys"
		keys.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		keys.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		for k: Array in key_hints(str(lesson.get("move", ""))):
			keys.add_child(InputGlyph.make(StringName(str(k[0])), str(k[1]), 16))
		row.add_child(keys)
	else:
		row.alignment = BoxContainer.ALIGNMENT_END
	var buttons: Array[Control] = []
	var go: Button = UiUtil.button("Weiter", &"ButtonBig")
	go.name = "Continue"
	go.custom_minimum_size = Vector2(160, 0)
	UiUtil.touch_pad(go)
	go.pressed.connect(func() -> void: m.call("close"))
	row.add_child(go)
	buttons.append(go)
	if first:
		var skip: Button = UiUtil.button("Ich kenne mich aus", &"ButtonBig")
		skip.name = "Skip"
		UiUtil.touch_pad(skip)
		skip.pressed.connect(func() -> void:
			m.set_meta("skipped", true)
			m.call("close"))
		row.add_child(skip)
		buttons.append(skip)
	UiUtil.wire_horizontal(buttons)
	table.add_child(m)
	var above: float = float(table.call("hand_top_y")) if table.has_method("hand_top_y") else -1.0
	if above > 0.0:
		m.call("place_above", above - 6.0)
	return m


## The lesson line: "<line>:keys" for keyboard / gamepad when the data has it, else the line itself.
static func lesson_text(book: SdRulebook, lesson: Dictionary, touch: bool) -> String:
	var tag: String = str(lesson.get("line", ""))
	var lines: Array[Dictionary] = []
	if not touch:
		lines = book.lines_for(tag + ":keys")
	if lines.is_empty():
		lines = book.lines_for(tag)
	return str(lines[0]["text"]) if not lines.is_empty() else ""


static func note_text(book: SdRulebook, lesson: Dictionary) -> String:
	var tag: String = str(lesson.get("note", ""))
	if tag == "":
		return ""
	var lines: Array[Dictionary] = book.lines_for(tag)
	return str(lines[0]["text"]) if not lines.is_empty() else ""


## [action, caption] of the keys a lesson's move needs.
static func key_hints(move: String) -> Array[Array]:
	match move:
		"play":
			return [[&"ui_left", ""], [&"ui_right", "markieren"], [&"ui_accept", "spielen"], [&"map", "Großansicht"]]
		"file":
			return [[&"sd_file", "Abheften"], [&"ui_accept", "Karte bestätigen"], [&"ui_cancel", "zurück"]]
	return [[&"ui_accept", "Weiter"]]
