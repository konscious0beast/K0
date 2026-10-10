extends CanvasLayer
## Pause menu (02_TECH §1.6, §9.4 layer 60, GDD §14.4): tabs Party · Inventar · Ausrüstung · Fähigkeiten · Achievements
## · Bestiarium · Optionen · Zum Titel. Opening pauses the tree (Game timer stops) and emits pause_menu_toggled(true);
## the menu itself closes on pause / ui_cancel (from the tab bar) or the visible "Schließen" button (touch has no
## Esc/Back: the touch pause button sits under the paused HUD), unpauses and emits pause_menu_toggled(false).
## process_mode WHEN_PAUSED — also every page and dialog opened from here (§9.4). tab_prev / tab_next switch tabs.
## Layout: one tab bar (icon over caption, 64 px visible / 88 px hit, 12 px apart) with the close button at its end;
## ui_left/ui_right move along the bar, ui_down enters the page, ui_cancel in a page returns to the bar.
## setup({"tab": "party"|"inventory"|"equipment"|"skills"|"achievements"|"bestiary"|"settings", "context":
## "explore"|"safe_room"}).

signal closed()

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const InputGlyph := preload("res://scenes/ui/input_glyph.gd")
const UiIcon := preload("res://scenes/ui/ui_icon.gd")
const MenuBase := preload("res://scenes/ui/menu_base.gd")
const CONFIRM: String = "res://scenes/ui/confirm_dialog.tscn"
const SETTINGS: String = "res://scenes/ui/settings_menu.tscn"
const TABS: Array[Dictionary] = [
	{"id": "party", "label": "Party", "icon": &"person", "script": "res://scenes/ui/party_menu.gd"},
	{"id": "inventory", "label": "Inventar", "icon": &"potion", "script": "res://scenes/ui/inventory_menu.gd"},
	{"id": "equipment", "label": "Ausrüstung", "icon": &"sword", "script": "res://scenes/ui/equipment_menu.gd"},
	{"id": "skills", "label": "Fähigkeiten", "icon": &"star", "script": "res://scenes/ui/skills_menu.gd"},
	{"id": "achievements", "label": "Achievements", "icon": &"trophy", "script": "res://scenes/ui/achievements_menu.gd"},
	{"id": "bestiary", "label": "Bestiarium", "icon": &"skull", "script": "res://scenes/ui/bestiary_menu.gd"},
	{"id": "settings", "label": "Optionen", "icon": &"gear", "script": ""},
	{"id": "title", "label": "Zum Titel", "icon": &"door", "script": ""},
]

var current_tab: String = "party"
var pages: Dictionary = {}                 # tab id → Control

var _params: Dictionary = {}
var _paused_by_me: bool = false
var _closing: bool = false
var _root: Control
var _panel: PanelContainer
var _tab_buttons: Dictionary = {}          # id → Button
var _tab_list: Array[Control] = []
var close_button: Button
var _content: PanelContainer
var _page_title: Label
var _status: Label
var _info: Label
var _status_tween: Tween = null
var _confirm: Node = null                  # open "Zum Titel" confirm: modal over the menu (input goes to it only)


func setup(params: Dictionary) -> void:
	_params = params
	current_tab = str(params.get("tab", "party"))


func _init() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED


func _ready() -> void:
	Game.ensure_state()
	if not get_tree().paused:
		get_tree().paused = true
		_paused_by_me = true
	Events.pause_menu_toggled.emit(true)
	Sfx.play_ui(&"ui_confirm")
	_build()
	if not _tab_buttons.has(current_tab) or current_tab == "title":
		current_tab = "party"
	show_tab(current_tab)
	var start_in_page: bool = _params.has("tab") and current_tab != "party"
	if start_in_page:
		_focus_page()
	else:
		UiUtil.focus_later((_tab_buttons[current_tab] as Control))
	UiUtil.slide_in(_panel)


func _exit_tree() -> void:
	if not _closing:
		_release_pause()


func _process(_delta: float) -> void:
	_info.text = _info_text()


func _unhandled_input(event: InputEvent) -> void:
	# The confirm dialog is modal: tab switching behind it would pull the focus onto the tab bar under the dialog.
	if _closing or is_confirm_open():
		return
	if event.is_action_pressed(&"tab_next") or event.is_action_pressed(&"tab_prev"):
		get_viewport().set_input_as_handled()
		var ids: Array[String] = _page_ids()
		var i: int = ids.find(current_tab)
		var d: int = 1 if event.is_action_pressed(&"tab_next") else -1
		var in_page: bool = _focus_in_page()
		show_tab(ids[posmod(i + d, ids.size())])
		Sfx.play_ui(&"ui_move")
		if in_page:
			_focus_page()
		else:
			(_tab_buttons[current_tab] as Control).grab_focus()
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		if _focus_in_page():
			var page: Control = pages.get(current_tab) as Control
			if page != null and page.has_method("handle_cancel") and bool(page.call("handle_cancel")):
				Sfx.play_ui(&"ui_cancel")
				return
			Sfx.play_ui(&"ui_cancel")
			(_tab_buttons[current_tab] as Control).grab_focus()
			return
		close()
		return


## Shows the page of `tab` (lazy instancing). "title" opens the confirm dialog instead.
func show_tab(tab: String) -> void:
	if tab == "title":
		return
	current_tab = tab
	for id: Variant in pages.keys():
		(pages[id] as Control).visible = str(id) == tab
	if not pages.has(tab):
		var page: Control = _make_page(tab)
		if page != null:
			pages[tab] = page
			_content.add_child(page)
	var p: Control = pages.get(tab) as Control
	if p != null:
		p.visible = true
		if p.has_method("refresh") and p.is_node_ready():
			p.call("refresh")
	for id: Variant in _tab_buttons.keys():
		var b: Button = _tab_buttons[id]
		b.button_pressed = str(id) == tab
	for t: Dictionary in TABS:
		if str(t["id"]) == tab:
			_page_title.text = str(t["label"]).to_upper()


func close() -> void:
	if _closing:
		return
	_closing = true
	Sfx.play_ui(&"ui_cancel")
	_release_pause()
	closed.emit()
	queue_free()


func page(tab: String) -> Control:
	return pages.get(tab) as Control


## Opens the "Zum Titel" confirm (modal); while one is open, the open one is returned and no second one stacks.
func ask_to_title() -> Node:
	if is_confirm_open():
		return _confirm
	if not ResourceLoader.exists(CONFIRM):
		return null
	var d: Node = (load(CONFIRM) as PackedScene).instantiate()
	_confirm = d
	d.call("setup", {"title": "Zum Titel", "text": "Fortschritt seit dem letzten Safe Room geht verloren.",
		"yes": "Zum Titel", "no": "Weiterspielen", "default_no": true, "danger": true})
	d.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	d.connect("closed", func(yes: bool) -> void:
		if yes:
			_closing = true
			_release_pause()
			Router.goto(Router.SCENE_TITLE)
			queue_free()
		elif is_instance_valid(self) and _tab_buttons.has("title"):
			(_tab_buttons["title"] as Control).grab_focus())
	add_child(d)
	return d


func is_confirm_open() -> bool:
	return is_instance_valid(_confirm) and not bool(_confirm.get("answered"))


# --- internals --------------------------------------------------------------------------------------------------------

func _release_pause() -> void:
	if is_inside_tree() and get_tree().paused:
		get_tree().paused = false
	Events.pause_menu_toggled.emit(false)


func _page_ids() -> Array[String]:
	var out: Array[String] = []
	for t: Dictionary in TABS:
		if str(t["id"]) != "title":
			out.append(str(t["id"]))
	return out


func _make_page(tab: String) -> Control:
	var page: Control = null
	if tab == "settings":
		if ResourceLoader.exists(SETTINGS):
			page = (load(SETTINGS) as PackedScene).instantiate() as Control
			page.call("setup", {"framed": false})
	else:
		for t: Dictionary in TABS:
			if str(t["id"]) == tab and str(t["script"]) != "":
				page = (load(str(t["script"])) as GDScript).new() as Control
	if page == null:
		return null
	page.name = "Page_" + tab
	page.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	if page.has_signal("status"):
		page.connect("status", _show_status)
	if page.has_signal("open_equipment"):
		page.connect("open_equipment", func(member_id: String) -> void:
			show_tab("equipment")
			var eq: Control = pages.get("equipment") as Control
			if eq != null:
				eq.call("select_member", member_id))
	return page


func _focus_page() -> void:
	var p: Control = pages.get(current_tab) as Control
	if p != null and p.has_method("focus_default") and MenuBase.first_focusable(p) != null:
		p.call("focus_default")
		return
	# Nothing focusable on the page (e.g. the Bestiarium of a new run): the focus stays on the tab bar, otherwise
	# keyboard / gamepad would have no focus owner at all (the old page dropped it when it was hidden).
	if _tab_buttons.has(current_tab):
		(_tab_buttons[current_tab] as Control).grab_focus()


func _focus_in_page() -> bool:
	var f: Control = get_viewport().gui_get_focus_owner()
	var p: Control = pages.get(current_tab) as Control
	return f != null and p != null and p.is_ancestor_of(f)


func _show_status(text: String) -> void:
	_status.text = UiUtil.glyph_safe(text)
	_status.modulate.a = 1.0
	if _status_tween != null and _status_tween.is_valid():
		_status_tween.kill()
	_status_tween = create_tween()
	_status_tween.tween_interval(2.5)
	_status_tween.tween_property(_status, "modulate:a", 0.0, 0.4)


func _info_text() -> String:
	var parts: PackedStringArray = []
	if Game.state != null and Game.state.floor_run != null:
		var def: FloorDef = Game.floor_def()
		parts.append("ETAGE %d" % Game.state.floor_run.index if def == null else UiUtil.tr_text(def.name))
		if Game.state.floor_run.timer_started:
			parts.append("Restzeit %s (angehalten)" % UiUtil.fmt_time(floori(Game.time_left())))
	parts.append("%s Cr" % UiUtil.fmt_int(UiUtil.credits()))
	if Game.state != null:
		parts.append("Spielzeit %s" % UiUtil.fmt_time(floori(Game.state.play_time_sec)))
	return "   ·   ".join(parts)


func _build() -> void:
	_root = Control.new()
	_root.name = "Root"
	UiUtil.full_rect(_root)
	UiUtil.apply_theme(_root)
	add_child(_root)
	var dim: ColorRect = ColorRect.new()
	UiUtil.full_rect(dim)
	dim.color = Color(0.03, 0.02, 0.06, 0.78)
	_root.add_child(dim)
	var safe: SafeAreaContainer = SafeAreaContainer.new()
	safe.extra = 12
	safe.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(safe)
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.theme_type_variation = &"PanelMenu"
	safe.add_child(_panel)
	var outer: VBoxContainer = UiUtil.vbox(12)
	_panel.add_child(outer)
	var head: HBoxContainer = UiUtil.hbox(14)
	outer.add_child(head)
	var badge: PanelContainer = PanelContainer.new()
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.add_theme_stylebox_override("panel", UiUtil.box_style(UiTheme.C_ACCENT, Color(0, 0, 0, 0), 0, 0.21, 16, 2))
	head.add_child(badge)
	var bl: Label = UiUtil.label("PAUSE", &"LabelHeader", 26, UiUtil.C_PAPER)
	badge.add_child(bl)
	_page_title = UiUtil.label("", &"LabelHeader", 26)
	_page_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_page_title)
	head.add_child(UiUtil.spacer(0, 0, true))
	_info = UiUtil.label("", &"LabelSmall", 16)
	_info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_info)
	var tabs: HBoxContainer = UiUtil.hbox(12)       # 12 px between the 88 px hit areas
	tabs.name = "Tabs"
	outer.add_child(tabs)
	for t: Dictionary in TABS:
		var id: String = str(t["id"])
		var b: Button = _tab_button(t["icon"] as StringName, str(t["label"]),
			UiTheme.C_DANGER if id == "title" else UiTheme.C_ACCENT_2)
		b.name = "Tab_" + id
		b.toggle_mode = id != "title"
		if id == "title":
			b.pressed.connect(ask_to_title)
		else:
			b.focus_entered.connect(func() -> void: show_tab(id))
			b.pressed.connect(func() -> void:
				show_tab(id)
				_focus_page())
		tabs.add_child(b)
		_tab_buttons[id] = b
		_tab_list.append(b)
	close_button = _tab_button(&"cross", "Schließen", UiTheme.C_TEXT)
	close_button.name = "Close"
	close_button.pressed.connect(close)
	tabs.add_child(close_button)
	var bar: Array[Control] = _tab_list.duplicate()
	bar.append(close_button)
	UiUtil.wire_horizontal(bar)
	for b2: Control in bar:
		var btn: Control = b2
		# ui_down enters the page (handled in the button's own gui_input, before the viewport's focus navigation).
		btn.gui_input.connect(func(ev: InputEvent) -> void:
			if ev.is_action_pressed(&"ui_down") and btn != close_button:
				_focus_page()
				btn.accept_event())
	_content = PanelContainer.new()
	_content.name = "Content"
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_theme_stylebox_override("panel", UiUtil.box_style(Color(UiUtil.C_INK, 0.35), Color(0, 0, 0, 0), 0, 0.0,
		12, 10))
	outer.add_child(_content)
	var foot: HBoxContainer = UiUtil.hbox(20)
	outer.add_child(foot)
	_status = UiUtil.label("", &"", 18, UiTheme.C_OK)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(_status)
	foot.add_child(InputGlyph.make(&"tab_prev", "", 15))
	foot.add_child(InputGlyph.make(&"tab_next", "Reiter", 15))
	foot.add_child(InputGlyph.make(&"ui_accept", "Wählen", 15))
	foot.add_child(InputGlyph.make(&"ui_cancel", "Zurück", 15))


## Tab bar entry: icon over caption; 64 px visible, 88 px hit area (UiUtil.touch_pad).
func _tab_button(icon: StringName, caption: String, icon_color: Color) -> Button:
	var b: Button = UiUtil.button("", &"ButtonFlat")
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(UiTheme.MIN_TOUCH, 0)
	var col: VBoxContainer = UiUtil.vbox(2)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiUtil.full_rect(col)
	b.add_child(col)
	var ic: Control = UiIcon.make(icon, icon_color, 24)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(ic)
	var l: Label = UiUtil.label(caption, &"", 16)
	l.name = "Text"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(l)
	var flat: StyleBoxFlat = UiUtil.box_style(Color(UiTheme.C_PANEL, 0.6), Color(UiTheme.C_ACCENT_2, 0.35), 1, 0.0, 6, 4)
	b.add_theme_stylebox_override("normal", flat)
	var on: StyleBoxFlat = UiUtil.box_style(Color(UiTheme.C_ACCENT, 0.3), UiTheme.C_ACCENT, 0, 0.0, 6, 4)
	on.border_width_bottom = 4
	b.add_theme_stylebox_override("pressed", on)
	b.add_theme_stylebox_override("hover_pressed", on)
	UiUtil.touch_pad(b)
	return b
