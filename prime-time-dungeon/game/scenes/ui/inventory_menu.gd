extends "res://scenes/ui/menu_base.gd"
## Pause tab "Inventar" (02_TECH §1.6, GDD §14.4): items grouped by type, details, field use of consumables via
## Game.use_item(item, member) (recorded command, §3.4) with target choice and visible HP/MP result. Credits on top.

const TYPE_ORDER: PackedStringArray = ["consumable", "weapon", "armor", "accessory", "key"]

var selected_item: String = ""

var _credits: Label
var _list: VBoxContainer
var _detail: Dictionary = {}
var _targets: VBoxContainer
var _buttons: Array[Control] = []


func _ready() -> void:
	page_title = "Inventar"
	var row: HBoxContainer = UiUtil.hbox(18)
	UiUtil.full_rect(row)
	add_child(row)
	var left: VBoxContainer = UiUtil.vbox(8)
	left.custom_minimum_size = Vector2(380, 0)
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	var top: HBoxContainer = UiUtil.hbox(8)
	left.add_child(top)
	top.add_child(UiIcon.make(&"coin", UiTheme.C_GOLD, 22))
	_credits = UiUtil.label("", &"", 20, UiTheme.C_GOLD)
	_credits.add_theme_font_override("font", UiTheme.font_mono())
	top.add_child(_credits)
	var sl: Dictionary = scroll_list()
	left.add_child(sl["scroll"] as Control)
	_list = sl["list"]
	_detail = detail_panel()
	row.add_child(_detail["panel"] as Control)
	_targets = UiUtil.vbox(8)
	(_detail["extra"] as VBoxContainer).add_child(_targets)
	refresh()


func refresh() -> void:
	_credits.text = UiUtil.fmt_int(UiUtil.credits()) + " Cr"
	clear(_list)
	_buttons.clear()
	var counts: Dictionary = UiUtil.inventory_counts()
	var ids: Array[String] = []
	for k: Variant in counts.keys():
		ids.append(str(k))
	ids.sort_custom(_sort_items)
	var last_type: String = ""
	for id: String in ids:
		var def: ItemDef = UiUtil.item_def(id)
		var t: String = def.type if def != null else "consumable"
		if t != last_type:
			last_type = t
			var h: Label = UiUtil.label(str(UiUtil.TYPE_NAMES.get(t, t)).to_upper(), &"", 13, UiTheme.C_ACCENT)
			h.add_theme_font_override("font", UiTheme.font_bold())
			_list.add_child(h)
		var b: Button = list_button(UiUtil.item_name(id), item_icon(id), item_color(id), "×%d" % int(counts[id]))
		b.name = "Item_" + id
		b.focus_entered.connect(func() -> void: _show_item(id))
		b.pressed.connect(func() -> void: _activate(id))
		_list.add_child(b)
		_buttons.append(b)
	if ids.is_empty():
		_list.add_child(empty_note("Das Inventar ist leer. Truhen, Kämpfe und der Automat helfen."))
		_show_item("")
	UiUtil.wire_vertical(_buttons)
	if selected_item != "" and counts.has(selected_item):
		_show_item(selected_item)
	elif not ids.is_empty():
		_show_item(ids[0])


func focus_default() -> void:
	for b: Control in _buttons:
		if b.name == "Item_" + selected_item:
			UiUtil.focus_later(b)
			return
	if not _buttons.is_empty():
		UiUtil.focus_later(_buttons[0])


func handle_cancel() -> bool:
	if _targets.get_child_count() > 0:
		clear(_targets)
		focus_default()
		return true
	return false


## Field use: Game.use_item (recorded); returns its result. HP/MP changes are reported via `status`.
func use_on(item_id: String, member_id: String) -> bool:
	var m: PartyMember = Game.state.member(member_id) if Game.state != null else null
	var hp0: int = m.hp if m != null else 0
	var mp0: int = m.mp if m != null else 0
	var ok: bool = Game.use_item(item_id, member_id)
	if ok:
		Sfx.play_ui(&"heal")
		var parts: PackedStringArray = []
		if m != null and m.hp != hp0:
			parts.append("HP %s" % UiUtil.fmt_signed(m.hp - hp0))
		if m != null and m.mp != mp0:
			parts.append("MP %s" % UiUtil.fmt_signed(m.mp - mp0))
		say("%s: %s" % [UiUtil.member_name(m) if m != null else member_id, ", ".join(parts) if not parts.is_empty()
			else "angewendet"])
	else:
		Sfx.play_ui(&"ui_error")
		say("%s zeigt keine Wirkung." % UiUtil.item_name(item_id))
	return ok


func _sort_items(a: String, b: String) -> bool:
	var da: ItemDef = UiUtil.item_def(a)
	var db: ItemDef = UiUtil.item_def(b)
	var ta: int = TYPE_ORDER.find(da.type) if da != null else 99
	var tb: int = TYPE_ORDER.find(db.type) if db != null else 99
	if ta != tb:
		return ta < tb
	return UiUtil.item_name(a) < UiUtil.item_name(b)


func _show_item(id: String) -> void:
	selected_item = id
	clear(_targets)
	var def: ItemDef = UiUtil.item_def(id)
	var title: Label = _detail["title"]
	var sub: Label = _detail["sub"]
	var body: Label = _detail["body"]
	if def == null:
		title.text = "–"
		sub.text = ""
		body.text = ""
		return
	title.text = UiUtil.item_name(id)
	title.add_theme_color_override("font_color", item_color(id))
	var sub_parts: PackedStringArray = [str(UiUtil.TYPE_NAMES.get(def.type, def.type))]
	if def.is_equipment():
		sub_parts.append(UiUtil.rarity_name(def.rarity))
	if def.type == "consumable":
		sub_parts.append({"field": "nur außerhalb des Kampfes", "battle": "nur im Kampf", "both": "Kampf & Feld",
			"none": "nicht benutzbar"}.get(def.usable, def.usable))
	var sv: int = UiUtil.sell_value(id)
	sub_parts.append("Verkauf %d Cr" % sv if sv > 0 else "unverkäuflich")
	sub.text = "  ·  ".join(sub_parts)
	var text: String = UiUtil.tr_text(def.desc)
	var stats: String = item_stat_text(def)
	body.text = UiUtil.glyph_safe(text + ("\n" + stats if stats != "" else ""))


func _activate(id: String) -> void:
	var def: ItemDef = UiUtil.item_def(id)
	if def == null:
		return
	if def.type != "consumable":
		say("Ausrüstung legst du im Reiter „Ausrüstung“ an." if def.is_equipment() else "Ein Schlüsselgegenstand.")
		Sfx.play_ui(&"ui_error")
		return
	if def.usable != "field" and def.usable != "both":
		say("%s kann nur im Kampf benutzt werden." % UiUtil.item_name(id))
		Sfx.play_ui(&"ui_error")
		return
	clear(_targets)
	_targets.add_child(UiUtil.label("Auf wen anwenden?", &"LabelSmall", 16))
	var targets: Array[Control] = []
	for m: PartyMember in UiUtil.party():
		var t: Button = list_button(UiUtil.member_name(m), &"paw" if m.id == "mopsula" else &"person",
			UiUtil.member_color(m.id), "HP %d/%d  MP %d/%d" % [m.hp, UiUtil.max_hp(m), m.mp, UiUtil.max_mp(m)])
		t.name = "Target_" + m.id
		var mid: String = m.id
		t.pressed.connect(func() -> void:
			use_on(id, mid)
			refresh()
			focus_default())
		_targets.add_child(t)
		targets.append(t)
	UiUtil.wire_vertical(targets)
	if not targets.is_empty():
		UiUtil.focus_later(targets[0])
