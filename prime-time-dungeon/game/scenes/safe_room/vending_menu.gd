extends CanvasLayer
## Vending machine (02_TECH §1.6/§9.5, GDD §6.5/§10.1): Kaufen / Verkaufen, quantity 1–9 (limited by credits and
## max_stack, respectively by the owned count), stat preview for equipment (green/red per member), Game.buy(item, qty,
## safe_room_id) / Game.sell(item, qty) (recorded). Modal layer 60; ui_cancel goes back / closes (signal `closed`).
## Stock: Shop.stock(Game.floor_def(), id) (fallback: the layout shop of the safe room).

signal closed()

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const UiIcon := preload("res://scenes/ui/ui_icon.gd")
const MenuBase := preload("res://scenes/ui/menu_base.gd")
const MAX_QTY: int = 9

var safe_room_id: String = ""
var mode: String = "buy"                    # "buy" | "sell"
var selected: String = ""
var qty: int = 1

var _params: Dictionary = {}
var _root: Control
var _panel: PanelContainer
var _credits: Label
var _tab_buy: Button
var _tab_sell: Button
var _list: VBoxContainer
var _buttons: Array[Control] = []
var _detail: Dictionary = {}
var _qty_button: Button
var _total: Label
var _preview: VBoxContainer
var _status: Label
var _closing: bool = false


func setup(params: Dictionary) -> void:
	_params = params
	safe_room_id = str(params.get("safe_room_id", ""))


func _init() -> void:
	layer = 60


func _ready() -> void:
	Game.ensure_state()
	if safe_room_id == "":
		var rooms: Array[Dictionary] = UiUtil.floor_safe_rooms(Game.floor_def())
		safe_room_id = str(rooms[0]["id"]) if not rooms.is_empty() else ""
	_build()
	set_mode("buy")
	focus_default()
	UiUtil.slide_in(_panel)
	Sfx.play(&"vending")


func focus_default() -> void:
	if not _buttons.is_empty():
		UiUtil.focus_later(_buttons[0])
	else:
		UiUtil.focus_later(_tab_buy)


func _unhandled_input(event: InputEvent) -> void:
	if _closing:
		return
	if event.is_action_pressed(&"tab_next") or event.is_action_pressed(&"tab_prev"):
		get_viewport().set_input_as_handled()
		set_mode("sell" if mode == "buy" else "buy")
		focus_default()
	elif event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		var f: Control = get_viewport().gui_get_focus_owner()
		if f == _qty_button:
			Sfx.play_ui(&"ui_cancel")
			_focus_selected()
		else:
			close()


func close() -> void:
	if _closing:
		return
	_closing = true
	Sfx.play_ui(&"ui_cancel")
	closed.emit()
	queue_free()


func set_mode(m: String) -> void:
	mode = m
	_tab_buy.button_pressed = m == "buy"
	_tab_sell.button_pressed = m == "sell"
	selected = ""
	_refresh_list()


## Items offered in the current mode.
func items() -> PackedStringArray:
	if mode == "buy":
		return UiUtil.shop_stock(safe_room_id)
	var out: PackedStringArray = []
	var counts: Dictionary = UiUtil.inventory_counts()
	var keys: Array = counts.keys()
	keys.sort()
	for k: Variant in keys:
		out.append(str(k))
	return out


## Allowed quantity range for `item_id` in the current mode: max (0 = not possible).
func max_qty(item_id: String) -> int:
	var def: ItemDef = UiUtil.item_def(item_id)
	if def == null:
		return 0
	var owned: int = int(UiUtil.inventory_counts().get(item_id, 0))
	if mode == "sell":
		return owned if UiUtil.sell_value(item_id) > 0 else 0
	var price: int = UiUtil.price_of(item_id)
	var by_credits: int = UiUtil.credits() / price if price > 0 else MAX_QTY
	return clampi(mini(by_credits, def.max_stack - owned), 0, MAX_QTY)


## Executes buy/sell of `qty` × selected item; returns the Game result.
func confirm() -> bool:
	if selected == "" or max_qty(selected) <= 0:
		Sfx.play_ui(&"ui_error")
		_say(_blocked_reason(selected), UiTheme.C_DANGER)
		return false
	var n: int = clampi(qty, 1, max_qty(selected))
	var credits_before: int = UiUtil.credits()
	var ok: bool = Game.buy(selected, n, safe_room_id) if mode == "buy" else Game.sell(selected, n)
	if ok:
		Sfx.play(&"coin")
		var diff: int = UiUtil.credits() - credits_before
		_say("%s %d× %s (%s Cr)" % ["Gekauft:" if mode == "buy" else "Verkauft:", n, UiUtil.item_name(selected),
			UiUtil.fmt_signed(diff)], UiTheme.C_OK)
	else:
		Sfx.play_ui(&"ui_error")
		_say("Der Automat verweigert. (%s)" % ("Credits?" if mode == "buy" else "nicht verkäuflich"), UiTheme.C_DANGER)
	var keep: String = selected
	_refresh_list()
	_select(keep)
	_focus_selected()
	return ok


func set_qty(n: int) -> void:
	var mx: int = maxi(max_qty(selected), 1)
	qty = clampi(n, 1, mx)
	_update_qty()


# --- internals --------------------------------------------------------------------------------------------------------

func _blocked_reason(item_id: String) -> String:
	var def: ItemDef = UiUtil.item_def(item_id)
	if def == null:
		return "Nichts gewählt."
	if mode == "sell":
		return "Das kauft der Automat nicht an." if UiUtil.sell_value(item_id) <= 0 else "Nichts mehr da."
	var owned: int = int(UiUtil.inventory_counts().get(item_id, 0))
	if owned >= def.max_stack:
		return "Lager voll (max. %d)." % def.max_stack
	return "Nicht genug Credits."


func _refresh_list() -> void:
	_credits.text = UiUtil.fmt_int(UiUtil.credits()) + " Cr"
	MenuBase.clear(_list)
	_buttons.clear()
	var counts: Dictionary = UiUtil.inventory_counts()
	for id: String in items():
		var price: int = UiUtil.price_of(id) if mode == "buy" else UiUtil.sell_value(id)
		var right: String = ("%d Cr" % price) if price > 0 else "–"
		var b: Button = MenuBase.list_button(UiUtil.item_name(id), MenuBase.item_icon(id), MenuBase.item_color(id), right)
		b.name = "Item_" + id
		var owned: int = int(counts.get(id, 0))
		var own_l: Label = UiUtil.label("×%d" % owned if owned > 0 else "", &"LabelSmall", 15)
		own_l.custom_minimum_size = Vector2(36, 0)
		own_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		(b.get_child(0) as HBoxContainer).add_child(own_l)
		(b.get_child(0) as HBoxContainer).move_child(own_l, 2)
		if max_qty(id) <= 0:
			(b.find_child("Right", true, false) as Label).add_theme_color_override("font_color", UiUtil.C_DISABLED)
		var iid: String = id
		b.focus_entered.connect(func() -> void: _select(iid))
		b.pressed.connect(func() -> void:
			_select(iid)
			if max_qty(iid) > 0:
				_qty_button.grab_focus()
			else:
				Sfx.play_ui(&"ui_error")
				_say(_blocked_reason(iid), UiTheme.C_DANGER))
		_list.add_child(b)
		_buttons.append(b)
	if _buttons.is_empty():
		_list.add_child(MenuBase.empty_note("Leer. Der Automat schaut dich vorwurfsvoll an." if mode == "buy" else
			"Nichts zu verkaufen."))
		_select("")
	else:
		_select(items()[0])
	UiUtil.wire_vertical(_buttons)


func _focus_selected() -> void:
	for b: Control in _buttons:
		if b.name == "Item_" + selected:
			UiUtil.focus_later(b)
			return
	focus_default()


func _select(id: String) -> void:
	selected = id
	qty = 1
	var def: ItemDef = UiUtil.item_def(id)
	var title: Label = _detail["title"]
	var sub: Label = _detail["sub"]
	var body: Label = _detail["body"]
	MenuBase.clear(_preview)
	if def == null:
		title.text = "–"
		sub.text = ""
		body.text = ""
		_qty_button.disabled = true
		_update_qty()
		return
	title.text = UiUtil.item_name(id)
	title.add_theme_color_override("font_color", MenuBase.item_color(id))
	var parts: PackedStringArray = [str(UiUtil.TYPE_NAMES.get(def.type, def.type))]
	if def.is_equipment():
		parts.append(UiUtil.rarity_name(def.rarity))
	parts.append("im Besitz: %d / %d" % [int(UiUtil.inventory_counts().get(id, 0)), def.max_stack])
	sub.text = "  ·  ".join(parts)
	var stats: String = MenuBase.item_stat_text(def)
	body.text = UiUtil.glyph_safe(UiUtil.tr_text(def.desc) + ("\n" + stats if stats != "" else ""))
	if def.is_equipment():
		for m: PartyMember in UiUtil.party():
			if not UiUtil.can_equip(m.id, id):
				continue
			var delta: Dictionary = UiUtil.equip_delta(m, def.type, id)
			var row: HBoxContainer = UiUtil.hbox(10)
			row.add_child(UiUtil.label(UiUtil.member_name(m) + ":", &"", 17))
			if delta.is_empty():
				row.add_child(UiUtil.label("keine Änderung", &"LabelSmall", 16))
			for k: String in UiUtil.STAT_KEYS:
				if delta.has(k):
					var d: int = int(delta[k])
					row.add_child(UiUtil.label("%s %s" % [str(UiUtil.STAT_SHORT[k]), UiUtil.fmt_signed(d)], &"", 17,
						UiTheme.C_OK if d > 0 else UiTheme.C_DANGER))
			_preview.add_child(row)
	_qty_button.disabled = max_qty(id) <= 0
	_update_qty()


func _update_qty() -> void:
	var unit: int = UiUtil.price_of(selected) if mode == "buy" else UiUtil.sell_value(selected)
	var verb: String = "Kaufen" if mode == "buy" else "Verkaufen"
	_qty_button.text = "‹  %d×  ›   %s" % [qty, verb]
	_total.text = "Summe: %s Cr" % UiUtil.fmt_int(unit * qty) if selected != "" else ""


func _say(text: String, col: Color) -> void:
	_status.text = UiUtil.glyph_safe(text)
	_status.add_theme_color_override("font_color", col)


func _build() -> void:
	_root = Control.new()
	UiUtil.full_rect(_root)
	UiUtil.apply_theme(_root)
	add_child(_root)
	var dim: ColorRect = ColorRect.new()
	UiUtil.full_rect(dim)
	dim.color = Color(0.03, 0.02, 0.06, 0.7)
	_root.add_child(dim)
	var safe: SafeAreaContainer = SafeAreaContainer.new()
	safe.extra = 24
	safe.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(safe)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiUtil.box_style(Color("#101820", 0.96), Color("#3ce0c0"), 3, 0.0, 22, 16))
	safe.add_child(_panel)
	var col: VBoxContainer = UiUtil.vbox(12)
	_panel.add_child(col)
	var head: HBoxContainer = UiUtil.hbox(14)
	col.add_child(head)
	head.add_child(UiIcon.make(&"vending", Color("#3ce0c0"), 40))
	var hc: VBoxContainer = UiUtil.vbox(-2)
	head.add_child(hc)
	hc.add_child(UiUtil.label("AUTOMAT", &"LabelHeader", 30, Color("#3ce0c0")))
	var info: Dictionary = UiUtil.safe_room_info(safe_room_id)
	hc.add_child(UiUtil.label(str(info.get("name", "Safe Room")) + " · Snacks, Pflaster, Fragwürdiges", &"LabelSmall", 15))
	head.add_child(UiUtil.spacer(0, 0, true))
	head.add_child(UiIcon.make(&"coin", UiTheme.C_GOLD, 26))
	_credits = UiUtil.label("", &"", 26, UiTheme.C_GOLD)
	_credits.add_theme_font_override("font", UiTheme.font_mono())
	head.add_child(_credits)
	var tabs: HBoxContainer = UiUtil.hbox(8)
	col.add_child(tabs)
	_tab_buy = UiUtil.button("Kaufen", &"ButtonFlat")
	_tab_buy.toggle_mode = true
	_tab_buy.custom_minimum_size = Vector2(180, 48)
	_tab_buy.pressed.connect(func() -> void:
		set_mode("buy")
		focus_default())
	tabs.add_child(_tab_buy)
	_tab_sell = UiUtil.button("Verkaufen", &"ButtonFlat")
	_tab_sell.toggle_mode = true
	_tab_sell.custom_minimum_size = Vector2(180, 48)
	_tab_sell.pressed.connect(func() -> void:
		set_mode("sell")
		focus_default())
	tabs.add_child(_tab_sell)
	tabs.add_child(InputGlyph.make(&"tab_prev", "", 14))
	tabs.add_child(InputGlyph.make(&"tab_next", "Wechseln", 14))
	var body: HBoxContainer = UiUtil.hbox(18)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	var sl: Dictionary = MenuBase.scroll_list()
	(sl["scroll"] as Control).custom_minimum_size = Vector2(470, 0)
	(sl["scroll"] as Control).size_flags_horizontal = Control.SIZE_FILL
	body.add_child(sl["scroll"] as Control)
	_list = sl["list"]
	var right: VBoxContainer = UiUtil.vbox(10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)
	_detail = MenuBase.detail_panel()
	right.add_child(_detail["panel"] as Control)
	_preview = UiUtil.vbox(4)
	(_detail["extra"] as VBoxContainer).add_child(_preview)
	var buy_row: HBoxContainer = UiUtil.hbox(16)
	right.add_child(buy_row)
	_qty_button = UiUtil.button("", &"ButtonBig")
	_qty_button.name = "Quantity"
	_qty_button.custom_minimum_size = Vector2(300, 72)
	_qty_button.gui_input.connect(func(ev: InputEvent) -> void:
		if ev.is_action_pressed(&"ui_left"):
			set_qty(qty - 1)
			Sfx.play_ui(&"ui_move")
			_qty_button.accept_event()
		elif ev.is_action_pressed(&"ui_right"):
			set_qty(qty + 1)
			Sfx.play_ui(&"ui_move")
			_qty_button.accept_event())
	_qty_button.pressed.connect(confirm)
	buy_row.add_child(_qty_button)
	_total = UiUtil.label("", &"", 22, UiTheme.C_GOLD)
	_total.add_theme_font_override("font", UiTheme.font_mono())
	_total.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buy_row.add_child(_total)
	_status = UiUtil.label("", &"", 18, UiTheme.C_OK)
	right.add_child(_status)
	var foot: HBoxContainer = UiUtil.hbox(18)
	col.add_child(foot)
	foot.add_child(UiUtil.label("Preise inkl. Showsteuer. Rückgabe ausgeschlossen. Natürlich.", &"LabelSmall", 14))
	foot.add_child(UiUtil.spacer(0, 0, true))
	foot.add_child(InputGlyph.make(&"ui_accept", "Wählen", 14))
	foot.add_child(InputGlyph.make(&"ui_cancel", "Zurück", 14))
