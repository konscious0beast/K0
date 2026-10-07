extends "res://scenes/ui/menu_base.gd"
## Pause tab "Achievements" (02_TECH §1.6, GDD §14.4): all achievements; unlocked (gold) with reward, visible locked
## (dimmed name + description), hidden locked as "???". Progress counter on top.

var _count: Label
var _list: VBoxContainer
var _buttons: Array[Control] = []


func _ready() -> void:
	page_title = "Achievements"
	var col: VBoxContainer = UiUtil.vbox(10)
	UiUtil.full_rect(col)
	add_child(col)
	_count = UiUtil.label("", &"", 20, UiTheme.C_GOLD)
	col.add_child(_count)
	var sl: Dictionary = scroll_list()
	col.add_child(sl["scroll"] as Control)
	_list = sl["list"]
	refresh()


static func unlocked_ids() -> PackedStringArray:
	if Game.state == null or Game.state.show == null:
		return PackedStringArray()
	return Game.state.show.achievements


func refresh() -> void:
	clear(_list)
	_buttons.clear()
	var unlocked: PackedStringArray = unlocked_ids()
	var all: Array[AchievementDef] = DB.data.all_achievements()
	var got: int = 0
	for a: AchievementDef in all:
		if unlocked.has(a.id) or Show.is_unlocked(a.id):
			got += 1
	_count.text = "%d / %d freigeschaltet" % [got, all.size()]
	# Unlocked first, then visible, then hidden.
	all.sort_custom(func(x: AchievementDef, y: AchievementDef) -> bool:
		var ux: int = 0 if (unlocked.has(x.id) or Show.is_unlocked(x.id)) else (1 if not x.hidden else 2)
		var uy: int = 0 if (unlocked.has(y.id) or Show.is_unlocked(y.id)) else (1 if not y.hidden else 2)
		return ux < uy if ux != uy else x.id < y.id)
	for a: AchievementDef in all:
		var is_on: bool = unlocked.has(a.id) or Show.is_unlocked(a.id)
		var b: Button = UiUtil.button("", &"ButtonFlat")
		b.name = "Ach_" + a.id
		b.custom_minimum_size = Vector2(0, 66)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var row: HBoxContainer = UiUtil.hbox(14)
		UiUtil.full_rect(row)
		row.offset_left = 14
		row.offset_right = -14
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(row)
		var ic: Control = UiIcon.make(&"trophy" if is_on else (&"dot" if a.hidden else &"trophy"),
			UiTheme.C_GOLD if is_on else UiUtil.C_DISABLED, 30)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(ic)
		var texts: VBoxContainer = UiUtil.vbox(0)
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(texts)
		var hidden_locked: bool = a.hidden and not is_on
		var t: Label = UiUtil.label("???" if hidden_locked else UiUtil.tr_text(a.name), &"", 20,
			UiTheme.C_TEXT if is_on else UiTheme.C_TEXT_DIM)
		t.add_theme_font_override("font", UiTheme.font_bold())
		texts.add_child(t)
		var d: Label = UiUtil.label("Verborgenes Achievement" if hidden_locked else UiUtil.glyph_safe(UiUtil.tr_text(
			a.desc)), &"LabelSmall", 15)
		d.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		texts.add_child(d)
		if a.box != "" and not hidden_locked:
			var box_ic: Control = UiIcon.make(&"box", UiUtil.box_color(a.box) if is_on else UiUtil.C_DISABLED, 26)
			box_ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(box_ic)
		_list.add_child(b)
		_buttons.append(b)
	if _buttons.is_empty():
		_list.add_child(empty_note("Keine Achievements in den Daten."))
	UiUtil.wire_vertical(_buttons)


func focus_default() -> void:
	if not _buttons.is_empty():
		UiUtil.focus_later(_buttons[0])
