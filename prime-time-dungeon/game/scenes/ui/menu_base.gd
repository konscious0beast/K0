extends Control
## Private base of the pause-menu pages (party, inventory, equipment, skills, achievements, bestiary; §0.3 no
## class_name). Contract used by PauseMenu / SafeRoom: refresh(), focus_default(), handle_cancel() -> bool (true =
## consumed, e.g. back from a sub level), status(text) feedback. Pages fill their parent (content panel).

signal status(text: String)

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const UiIcon := preload("res://scenes/ui/ui_icon.gd")
const TYPE_ICONS: Dictionary = {"consumable": &"potion", "weapon": &"sword", "armor": &"shield",
	"accessory": &"ring", "key": &"key"}

var page_title: String = ""


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL


func refresh() -> void:
	pass


func focus_default() -> void:
	var c: Control = first_focusable(self)
	if c != null:
		UiUtil.focus_later(c)


func handle_cancel() -> bool:
	return false


func say(text: String) -> void:
	status.emit(text)


# --- helpers
# -----------------------------------------------------------------------------------------------------------

static func first_focusable(root: Node) -> Control:
	for c: Node in root.get_children():
		var ctl: Control = c as Control
		if ctl != null and ctl.is_visible_in_tree() and ctl.focus_mode == Control.FOCUS_ALL and \
				not (ctl is BaseButton and (ctl as BaseButton).disabled):
			return ctl
		var deeper: Control = first_focusable(c)
		if deeper != null:
			return deeper
	return null


static func clear(node: Node) -> void:
	for c: Node in node.get_children():
		node.remove_child(c)
		c.queue_free()


## Flat list entry: icon + text (+ right aligned text), focusable; 64 px visible, 88 px hit area (02_TECH §10.2 rule 5,
## UiUtil.touch_pad). Lists put them 12 px apart (scroll_list()).
static func list_button(text: String, icon_kind: StringName = &"", icon_color: Color = Color.WHITE,
		right_text: String = "", text_color: Color = Color(0, 0, 0, 0)) -> Button:
	var b: Button = UiUtil.button("", &"ButtonFlat")
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiUtil.touch_pad(b)
	var row: HBoxContainer = UiUtil.hbox(10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiUtil.full_rect(row)
	row.offset_left = 14
	row.offset_right = -14
	b.add_child(row)
	if icon_kind != &"":
		var ic: Control = UiIcon.make(icon_kind, icon_color, 24)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(ic)
	var l: Label = UiUtil.label(UiUtil.glyph_safe(text), &"", 20, text_color)
	l.name = "Text"
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(l)
	if right_text != "":
		var r: Label = UiUtil.label(right_text, &"", 18, UiTheme.C_TEXT_DIM)
		r.name = "Right"
		r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.add_theme_font_override("font", UiTheme.font_mono())
		row.add_child(r)
	return b


## Member tabs (Kai | Graf Mopsula); calls `on_select(member_id)` on focus/press. Returns the button row.
static func member_tabs(selected: String, on_select: Callable) -> HBoxContainer:
	var row: HBoxContainer = UiUtil.hbox(12)
	var buttons: Array[Control] = []
	for m: PartyMember in UiUtil.party():
		var b: Button = UiUtil.button(UiUtil.member_name(m), &"ButtonFlat")
		b.name = "Tab_" + m.id
		b.custom_minimum_size = Vector2(200, 0)
		UiUtil.touch_pad(b)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.toggle_mode = true
		b.button_pressed = m.id == selected
		var col: Color = UiUtil.member_color(m.id)
		if m.id == selected:
			b.add_theme_color_override("font_color", col.lightened(0.3))
			b.add_theme_color_override("font_focus_color", col.lightened(0.3))
		var mid: String = m.id
		b.pressed.connect(func() -> void: on_select.call(mid))
		row.add_child(b)
		buttons.append(b)
	UiUtil.wire_horizontal(buttons)
	return row


static func item_icon(item_id: String) -> StringName:
	var def: ItemDef = UiUtil.item_def(item_id)
	return TYPE_ICONS.get(def.type, &"box") if def != null else &"box"


static func item_color(item_id: String) -> Color:
	var def: ItemDef = UiUtil.item_def(item_id)
	if def == null:
		return UiTheme.C_TEXT
	if def.is_equipment():
		return UiUtil.rarity_color(def.rarity)
	return UiUtil.hex(def.color, UiTheme.C_TEXT)


## Stat lines of an item ("STR +12", element / immunity notes).
static func item_stat_text(def: ItemDef) -> String:
	if def == null:
		return ""
	var parts: PackedStringArray = []
	for k: String in UiUtil.STAT_KEYS:
		if def.stats.has(k) and int(def.stats[k]) != 0:
			var label_k: String = "ATK" if (k == "str" and def.type == "weapon") else str(UiUtil.STAT_SHORT[k])
			parts.append("%s %s" % [label_k, UiUtil.fmt_signed(int(def.stats[k]))])
	if def.crit_bonus > 0.0:
		parts.append("Krit +%d %%" % roundi(def.crit_bonus * 100.0))
	for e: Variant in def.element_mods.keys():
		var v: float = float(def.element_mods[e])
		var en: String = str(UiUtil.ELEMENT_NAMES.get(str(e), str(e)))
		parts.append("%s-immun" % en if v <= 0.0 else ("%s-resistent" % en if v < 1.0 else "%s-anfällig" % en))
	if float(def.show_mods.get("hype_gain_mult", 1.0)) != 1.0:
		parts.append("Hype ×%s" % str(def.show_mods.get("hype_gain_mult", 1.0)).replace(".", ","))
	if float(def.show_mods.get("follower_mult", 1.0)) != 1.0:
		parts.append("Follower ×%s" % str(def.show_mods.get("follower_mult", 1.0)).replace(".", ","))
	return "  ·  ".join(parts)


## Detail panel scaffold: returns {"panel", "title", "sub", "body", "extra"}.
static func detail_panel() -> Dictionary:
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiUtil.box_style(Color(UiUtil.C_INK, 0.55), Color(UiTheme.C_ACCENT_2,
		0.35), 1, 0.0, 16, 12))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var col: VBoxContainer = UiUtil.vbox(8)
	panel.add_child(col)
	var title: Label = UiUtil.label("", &"LabelHeader", 26)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(title)
	var sub: Label = UiUtil.label("", &"LabelSmall", 16)
	col.add_child(sub)
	var body: Label = UiUtil.label("", &"", 19)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(body)
	var extra: VBoxContainer = UiUtil.vbox(8)
	col.add_child(extra)
	return {"panel": panel, "title": title, "sub": sub, "body": body, "extra": extra}


static func scroll_list() -> Dictionary:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var list: VBoxContainer = UiUtil.vbox(12)      # 12 px between the 88 px hit areas
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	return {"scroll": scroll, "list": list}


static func empty_note(text: String) -> Label:
	var l: Label = UiUtil.label(text, &"", 19, UiTheme.C_TEXT_DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l
