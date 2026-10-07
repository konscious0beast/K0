extends "res://scenes/ui/menu_base.gd"
## Pause tab "Party" (02_TECH §1.6, GDD §14.4): per member level, HP/MP, EXP to the next level, all 8 stats (total with
## equipment), equipment and class. Cards are focusable; pressing one jumps to the equipment page (`open_equipment`).

signal open_equipment(member_id: String)

var _row: HBoxContainer


func _ready() -> void:
	page_title = "Party"
	_row = UiUtil.hbox(18)
	UiUtil.full_rect(_row)
	add_child(_row)
	refresh()


func refresh() -> void:
	clear(_row)
	var cards: Array[Control] = []
	for m: PartyMember in UiUtil.party():
		var card: Button = _card(m)
		_row.add_child(card)
		cards.append(card)
	if cards.is_empty():
		_row.add_child(empty_note("Keine Party – noch kein Spielstand."))
	UiUtil.wire_horizontal(cards)


func _card(m: PartyMember) -> Button:
	var b: Button = UiUtil.button("", &"ButtonFlat")
	b.name = "Card_" + m.id
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_vertical = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(360, 0)
	var col_c: Color = UiUtil.member_color(m.id)
	var bg: StyleBoxFlat = UiUtil.box_style(Color(UiUtil.C_INK, 0.55), Color(col_c, 0.6), 2, 0.0, 16, 12)
	b.add_theme_stylebox_override("normal", bg)
	b.add_theme_stylebox_override("hover", bg)
	b.add_theme_stylebox_override("pressed", bg)
	var mid: String = m.id
	b.pressed.connect(func() -> void: open_equipment.emit(mid))
	var margin: MarginContainer = MarginContainer.new()
	UiUtil.full_rect(margin)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 16)
	b.add_child(margin)
	var col: VBoxContainer = UiUtil.vbox(8)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(col)
	var head: HBoxContainer = UiUtil.hbox(12)
	col.add_child(head)
	var portrait: PanelContainer = PanelContainer.new()
	portrait.custom_minimum_size = Vector2(56, 56)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var psb: StyleBoxFlat = StyleBoxFlat.new()
	psb.bg_color = Color(col_c, 0.3)
	psb.border_color = col_c
	psb.set_border_width_all(2)
	psb.set_corner_radius_all(28)
	portrait.add_theme_stylebox_override("panel", psb)
	portrait.add_child(UiIcon.make(&"paw" if m.id == "mopsula" else &"person", UiUtil.C_PAPER, 36))
	head.add_child(portrait)
	var names: VBoxContainer = UiUtil.vbox(0)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(names)
	var n: Label = UiUtil.label(UiUtil.member_name(m), &"", 24)
	n.add_theme_font_override("font", UiTheme.font_bold())
	names.add_child(n)
	var cls: String = "Klasse: –" if m.class_id == "" else "Klasse: " + (UiUtil.tr_text(DB.class_def(m.class_id).name)
		if DB.has_id("classes", m.class_id) else m.class_id)
	names.add_child(UiUtil.label(cls + "  (Wahl ab Etage 3)", &"LabelSmall", 14))
	var lv: Label = UiUtil.label("Lv %d" % m.level, &"", 28, UiTheme.C_GOLD)
	lv.add_theme_font_override("font", UiTheme.font_bold())
	head.add_child(lv)
	var mhp: int = UiUtil.max_hp(m)
	var mmp: int = UiUtil.max_mp(m)
	col.add_child(_bar_row("HP", m.hp, mhp, &"BarHp"))
	col.add_child(_bar_row("MP", m.mp, mmp, &"BarMp"))
	var need: int = UiUtil.exp_to_next(m.level)
	if need > 0:
		col.add_child(_bar_row("EXP", m.exp, need, &"BarHype"))
	else:
		col.add_child(UiUtil.label("EXP  Maximalstufe erreicht", &"LabelSmall", 15))
	var grid: GridContainer = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 2)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(grid)
	var stats: Dictionary = UiUtil.member_stats(m)
	for k: String in ["str", "mag", "def", "res", "spd", "lck"]:
		var kl: Label = UiUtil.label(str(UiUtil.STAT_NAMES[k]), &"LabelSmall", 16)
		kl.custom_minimum_size = Vector2(92, 0)
		grid.add_child(kl)
		var vl: Label = UiUtil.label(str(int(stats.get(k, 0))), &"", 18)
		vl.add_theme_font_override("font", UiTheme.font_mono())
		vl.custom_minimum_size = Vector2(44, 0)
		grid.add_child(vl)
	col.add_child(UiUtil.spacer(2))
	for slot: String in UiUtil.EQUIP_SLOTS:
		var r: HBoxContainer = UiUtil.hbox(8)
		var item_id: String = str(m.equipment.get(slot, ""))
		r.add_child(UiIcon.make(TYPE_ICONS[slot] as StringName, item_color(item_id) if item_id != "" else
			UiUtil.C_DISABLED, 18))
		var sl: Label = UiUtil.label(str(UiUtil.SLOT_NAMES[slot]), &"LabelSmall", 15)
		sl.custom_minimum_size = Vector2(96, 0)
		r.add_child(sl)
		r.add_child(UiUtil.label(UiUtil.item_name(item_id), &"", 17))
		col.add_child(r)
	return b


func _bar_row(label_text: String, value: int, max_value: int, variation: StringName) -> HBoxContainer:
	var r: HBoxContainer = UiUtil.hbox(8)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l: Label = UiUtil.label(label_text, &"LabelSmall", 15)
	l.custom_minimum_size = Vector2(40, 0)
	r.add_child(l)
	var bar: ProgressBar = UiUtil.bar(variation, value, maxi(max_value, 1), 10.0)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_child(bar)
	var v: Label = UiUtil.label("%d / %d" % [value, max_value], &"", 16)
	v.add_theme_font_override("font", UiTheme.font_mono())
	v.custom_minimum_size = Vector2(92, 0)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	r.add_child(v)
	return r
