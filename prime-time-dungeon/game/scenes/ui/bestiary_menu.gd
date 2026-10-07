extends "res://scenes/ui/menu_base.gd"
## Pause tab "Bestiarium" (02_TECH §1.6, GDD §14.4): entries from GameState.bestiary (enemy id → {defeated,
## weak_known}); name + level always, HP/stats from defeated ≥ 1, weaknesses one by one after discovery.

var _list: VBoxContainer
var _detail: Dictionary = {}
var _buttons: Array[Control] = []


func _ready() -> void:
	page_title = "Bestiarium"
	var row: HBoxContainer = UiUtil.hbox(18)
	UiUtil.full_rect(row)
	add_child(row)
	var sl: Dictionary = scroll_list()
	(sl["scroll"] as Control).custom_minimum_size = Vector2(360, 0)
	(sl["scroll"] as Control).size_flags_horizontal = Control.SIZE_FILL
	row.add_child(sl["scroll"] as Control)
	_list = sl["list"]
	_detail = detail_panel()
	row.add_child(_detail["panel"] as Control)
	refresh()


static func entries() -> Dictionary:
	if Game.state == null:
		return {}
	return Game.state.bestiary


func refresh() -> void:
	clear(_list)
	_buttons.clear()
	var best: Dictionary = entries()
	var ids: Array[String] = []
	for k: Variant in best.keys():
		ids.append(str(k))
	ids.sort()
	for id: String in ids:
		var e: Dictionary = best[id] if typeof(best[id]) == TYPE_DICTIONARY else {}
		var def: EnemyDef = DB.enemy(id) if DB.has_id("enemies", id) else null
		var n: String = UiUtil.tr_text(def.name) if def != null else id
		var b: Button = list_button(n, &"skull" if def != null and def.boss else &"eye",
			UiTheme.C_DANGER if def != null and def.boss else UiTheme.C_TEXT, "×%d" % int(e.get("defeated", 0)))
		b.name = "Enemy_" + id
		b.focus_entered.connect(func() -> void: _show(id))
		_list.add_child(b)
		_buttons.append(b)
	if ids.is_empty():
		_list.add_child(empty_note("Noch keine Einträge. Jeder besiegte Gegner landet hier – für die Wissenschaft."))
		_clear_detail()
	else:
		_show(ids[0])
	UiUtil.wire_vertical(_buttons)


func focus_default() -> void:
	if not _buttons.is_empty():
		UiUtil.focus_later(_buttons[0])


func _clear_detail() -> void:
	(_detail["title"] as Label).text = "Bestiarium"
	(_detail["sub"] as Label).text = ""
	(_detail["body"] as Label).text = ""
	clear(_detail["extra"] as Node)


func _show(id: String) -> void:
	var e: Dictionary = entries().get(id, {}) if typeof(entries().get(id, {})) == TYPE_DICTIONARY else {}
	var def: EnemyDef = DB.enemy(id) if DB.has_id("enemies", id) else null
	var title: Label = _detail["title"]
	var sub: Label = _detail["sub"]
	var body: Label = _detail["body"]
	var extra: VBoxContainer = _detail["extra"]
	clear(extra)
	if def == null:
		title.text = id
		sub.text = ""
		body.text = ""
		return
	var defeated: int = int(e.get("defeated", 0))
	title.text = UiUtil.tr_text(def.name)
	title.add_theme_color_override("font_color", UiTheme.C_DANGER if def.boss else UiTheme.C_TEXT)
	sub.text = "Lv %d%s  ·  besiegt: %d" % [def.level, "  ·  BOSS" if def.boss else "", defeated]
	if defeated >= 1:
		var lines: PackedStringArray = []
		lines.append("HP %d   MP %d" % [int(def.stats.get("hp", 0)), int(def.stats.get("mp", 0))])
		var parts: PackedStringArray = []
		for k: String in ["str", "mag", "def", "res", "spd", "lck"]:
			parts.append("%s %d" % [str(UiUtil.STAT_SHORT[k]), int(def.stats.get(k, 0))])
		lines.append("  ".join(parts))
		lines.append("EXP %d   Credits %d" % [def.exp, def.credits])
		body.text = "\n".join(lines)
	else:
		body.text = "Werte nach dem ersten Sieg."
	var weak: PackedStringArray = []
	var weak_v: Variant = e.get("weak_known", [])
	if typeof(weak_v) == TYPE_ARRAY or typeof(weak_v) == TYPE_PACKED_STRING_ARRAY:
		for w: Variant in weak_v:
			weak.append(str(w))
	var wl: Label = UiUtil.label("SCHWÄCHEN", &"", 13, UiTheme.C_ACCENT)
	wl.add_theme_font_override("font", UiTheme.font_bold())
	extra.add_child(wl)
	if weak.is_empty():
		extra.add_child(UiUtil.label("Noch unbekannt – probier Elemente aus.", &"LabelSmall", 16))
	else:
		var row: HBoxContainer = UiUtil.hbox(10)
		for el: String in weak:
			var c: Color = UiUtil.ELEMENT_COLORS.get(el, UiTheme.C_TEXT) as Color
			var tag: PanelContainer = PanelContainer.new()
			tag.add_theme_stylebox_override("panel", UiUtil.box_style(Color(c, 0.25), c, 1, 0.0, 10, 2))
			tag.add_child(UiUtil.label(str(UiUtil.ELEMENT_NAMES.get(el, el)), &"", 16, c))
			row.add_child(tag)
		extra.add_child(row)
