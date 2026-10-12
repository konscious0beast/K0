extends RefCounted
## The duel's menu (10 §4.6 "Esc / P / Start", §1.11): Weiter · Regeln · Antrag zurückziehen (Lernduell: überspringen)
## and the Hilfen — Tipps des Grafen, Der Graf übernimmt, Gegnerhand offen, Tempo × 2, Animationen reduzieren,
## Linkshänder, Schriftgröße 100 / 125 / 150 % (10 §4.8). Options are stored in the collection at once (SdCollection
## options, 10 §6.7) and the table re-lays itself out. Private helper: open(table) → the modal.

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const SdStyle := preload("res://scenes/stempel/sd_style.gd")
const SdModal := preload("res://scenes/stempel/sd_modal.gd")
const SdSession := preload("res://scenes/stempel/sd_session.gd")
const SdRulesPage := preload("res://scenes/stempel/sd_rules_page.gd")

const COLS: int = 3

## [option key, label, values, value labels]
const OPTIONS: Array[Array] = [
	["hints", "Tipps des Grafen", [true, false], ["an", "aus"]],
	["auto", "Der Graf übernimmt", [false, true], ["aus", "an"]],
	["open_hand", "Gegnerhand offen", [false, true], ["aus", "an"]],
	["speed", "Tempo", [1, 2], ["× 1", "× 2"]],
	["reduce_motion", "Animationen reduzieren", [false, true], ["aus", "an"]],
	["left_handed", "Linkshänder-Spiegelung", [false, true], ["aus", "an"]],
	["text_size", "Schriftgröße", [100, 125, 150], ["100 %", "125 %", "150 %"]],
]


static func open(table: Node) -> Node:
	var m: Node = SdModal.new()
	m.call("setup", "MENÜ", 900.0)
	m.name = "Menu"
	var box: VBoxContainer = m.get("content") as VBoxContainer
	var top: HBoxContainer = UiUtil.hbox(12)
	box.add_child(top)
	var tut: bool = bool(table.get("tutorial"))
	var weiter: Button = _button(top, "Weiter", func() -> void: m.call("close"))
	var regeln: Button = _button(top, "Regeln", func() -> void: SdRulesPage.open(table))
	var quit_text: String = "Lernduell überspringen" if tut else "Antrag zurückziehen"
	var quit: Button = _button(top, quit_text, func() -> void: _ask_forfeit(table, m, tut))
	quit.disabled = bool(table.get("busy")) or bool(table.get("finished"))
	box.add_child(SdStyle.label("HILFEN", 20, SdStyle.GOLD, true))
	var grid: GridContainer = GridContainer.new()
	grid.name = "Hilfen"
	grid.columns = COLS
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	box.add_child(grid)
	var toggles: Array[Control] = []
	for o: Array in OPTIONS:
		var b: Button = UiUtil.button("", &"ButtonFlat")
		b.name = "Opt_" + str(o[0])
		b.custom_minimum_size = Vector2(276, 0)
		UiUtil.touch_pad(b)
		var key: String = str(o[0])
		b.text = _label(table, o)
		if key == "open_hand":
			var opp: SdOpponentDef = table.get("opp") as SdOpponentDef
			b.disabled = opp != null and opp.open_hand
		b.pressed.connect(func() -> void:
			_cycle(table, o)
			b.text = _label(table, o))
		grid.add_child(b)
		toggles.append(b)
	var head: Array[Control] = [weiter, regeln, quit]
	UiUtil.wire_horizontal(head)
	for i in toggles.size():
		var t: Control = toggles[i]
		var up: Control = toggles[i - COLS] if i >= COLS else weiter
		var down: Control = toggles[i + COLS] if i + COLS < toggles.size() else t
		t.focus_neighbor_top = t.get_path_to(up)
		t.focus_neighbor_bottom = t.get_path_to(down)
		t.focus_neighbor_left = t.get_path_to(toggles[i - 1] if i % COLS > 0 else t)
		t.focus_neighbor_right = t.get_path_to(toggles[i + 1] if i % COLS < COLS - 1 and i + 1 < toggles.size() else t)
	for h: Control in head:
		h.focus_neighbor_bottom = h.get_path_to(toggles[0])
	table.add_child(m)
	return m


static func _button(row: HBoxContainer, text: String, cb: Callable) -> Button:
	var b: Button = UiUtil.button(text, &"ButtonBig")
	b.name = text.replace(" ", "")
	UiUtil.touch_pad(b)
	b.pressed.connect(cb)
	row.add_child(b)
	return b


static func _value(table: Node, key: String) -> Variant:
	if key == "auto":
		return bool(table.get("auto"))
	var c: SdCollection = table.get("collection") as SdCollection
	return c.options.get(key, SdCollection.OPTION_DEFAULTS.get(key))


static func _label(table: Node, o: Array) -> String:
	var values: Array = o[2]
	var names: Array = o[3]
	var i: int = maxi(0, values.find(_value(table, str(o[0]))))
	return "%s: %s" % [str(o[1]), str(names[i])]


static func _cycle(table: Node, o: Array) -> void:
	var key: String = str(o[0])
	var values: Array = o[2]
	var i: int = maxi(0, values.find(_value(table, key)))
	var next: Variant = values[(i + 1) % values.size()]
	if key == "auto":
		table.call("set_auto", bool(next))
		return
	if key == "speed":
		table.call("set_speed", int(next))
		return
	var c: SdCollection = table.get("collection") as SdCollection
	c.set_option(key, next)
	SdSession.save()
	table.call("options_changed")


static func _ask_forfeit(table: Node, menu: Node, tut: bool) -> void:
	var d: Node = (load("res://scenes/ui/confirm_dialog.tscn") as PackedScene).instantiate()
	d.call("setup", {"title": "Lernduell überspringen" if tut else "Antrag zurückziehen", "text": ("Die Grundakte "
		+ "kommt trotzdem. Weiter zur Schalterhalle?") if tut else "Das zählt als abgelehnt, kostet aber nichts.",
		"yes": "Ja", "no": "Nein", "default_no": true})
	d.connect("closed", func(yes: bool) -> void:
		if yes:
			menu.call("close")
			table.call("forfeit"))
	table.add_child(d)
