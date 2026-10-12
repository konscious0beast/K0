extends RefCounted
## Shared building blocks of the Stempelduell menu screens (10 §4.7: Schalterhalle, Aktenschrank, Stempelalbum): the
## studio backdrop with the equipped desk mat, the safe frame (02_TECH §10.4) with a header row — title, subtitle, a
## slot on the right and the visible "Zurück" button (the touch way out, 02_TECH §10.3) —, big touch buttons
## (≥ 88 px hit area, 64 px visible) and cycle buttons for filters. Menus keep the theme sizes (≥ 16 px); the text
## size option scales the cards they show. Private helper (no class_name).

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const SdStyle := preload("res://scenes/stempel/sd_style.gd")
const Backdrop := preload("res://scenes/stempel/sd_table_bg.gd")

const GAP: int = 12                                  # between hit areas (02_TECH §10.2 rule 5)


## Backdrop + safe frame + column with the header into `screen`. Returns {"col": VBoxContainer (the column),
## "head": HBoxContainer, "right": HBoxContainer (slot left of "Zurück"), "back": Button, "title": Label,
## "sub": Label}.
static func build(screen: Control, title: String, subtitle: String, mat: String = "") -> Dictionary:
	var bg: Control = Backdrop.new()
	bg.name = "Backdrop"
	bg.set("mat", mat)
	screen.add_child(bg)
	var safe: SafeAreaContainer = SafeAreaContainer.new()
	safe.name = "Safe"
	screen.add_child(safe)
	var col: VBoxContainer = UiUtil.vbox(GAP)
	col.name = "Column"
	safe.add_child(col)
	var head: HBoxContainer = UiUtil.hbox(16)
	head.name = "Header"
	col.add_child(head)
	var tcol: VBoxContainer = UiUtil.vbox(0)
	tcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tcol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(tcol)
	var t: Label = UiUtil.label(title, &"LabelHeader", 30, SdStyle.GOLD)
	t.name = "Title"
	t.add_theme_constant_override("outline_size", 0)
	tcol.add_child(t)
	var s: Label = SdStyle.label(subtitle, 18, SdStyle.TEXT_DIM)
	s.name = "Subtitle"
	s.visible = subtitle != ""
	tcol.add_child(s)
	var right: HBoxContainer = UiUtil.hbox(GAP)
	right.name = "Right"
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(right)
	var back: Button = UiUtil.close_button("Zurück")
	back.name = "Back"
	head.add_child(back)
	return {"col": col, "head": head, "right": right, "back": back, "title": t, "sub": s}


## A big menu button (ButtonBig, 64 px visible / 88 px hit area).
static func big_button(text: String, name: String, min_w: float = 0.0) -> Button:
	var b: Button = UiUtil.button(text, &"ButtonBig")
	b.name = name
	if min_w > 0.0:
		b.custom_minimum_size.x = min_w
	UiUtil.touch_pad(b)
	return b


## A flat button that cycles through `labels` ("Art: alle" → "Art: Stempel" …); `on_change(index)` after each press.
static func cycle_button(prefix: String, labels: PackedStringArray, on_change: Callable, name: String) -> Button:
	var b: Button = UiUtil.button("", &"ButtonFlat")
	b.name = name
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiUtil.touch_pad(b)
	b.set_meta("index", 0)
	b.text = "%s: %s" % [prefix, labels[0]]
	b.pressed.connect(func() -> void:
		var i: int = (int(b.get_meta("index")) + 1) % labels.size()
		b.set_meta("index", i)
		b.text = "%s: %s" % [prefix, labels[i]]
		on_change.call(i))
	return b


## A dark panel box for the screens' sections.
static func section(min_size: Vector2 = Vector2.ZERO) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.add_theme_stylebox_override("panel", SdStyle.panel_box(Color(SdStyle.INK, 0.95), SdStyle.PANEL_LINE, 1, 14.0))
	p.custom_minimum_size = min_size
	return p


## Wires `rows` (each an Array[Control] left → right) as a grid: up / down to the row above / below (same index or
## the last), left / right inside the row (with wrap). Disabled controls stay reachable (they explain themselves).
static func wire_grid(rows: Array[Array]) -> void:
	for r in rows.size():
		var row: Array = rows[r]
		var list: Array[Control] = []
		for c: Variant in row:
			if c is Control:
				list.append(c as Control)
		UiUtil.wire_horizontal(list)
		for i in list.size():
			var c2: Control = list[i]
			if r > 0 and not (rows[r - 1] as Array).is_empty():
				var up: Array = rows[r - 1]
				c2.focus_neighbor_top = c2.get_path_to(up[mini(i, up.size() - 1)] as Control)
			if r + 1 < rows.size() and not (rows[r + 1] as Array).is_empty():
				var down: Array = rows[r + 1]
				c2.focus_neighbor_bottom = c2.get_path_to(down[mini(i, down.size() - 1)] as Control)
