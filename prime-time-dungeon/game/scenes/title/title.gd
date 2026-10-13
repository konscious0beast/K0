class_name TitleScreen extends Control
## Title screen (02_TECH §9.5, GDD §14.1, 05 CR-10): 3D TV studio with the M.O.D. drone, logo and the menu
## Fortsetzen (Save.newest_slot() > 0 only) · Neues Spiel · Laden · Event-Lauf · Optionen · Credits ·
## Beenden (not on mobile). New game: slot select → hero choice (06 §1.1) → name entry → intro; every path ends in
## request_new_game().

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const InputGlyph := preload("res://scenes/ui/input_glyph.gd")
const UiIcon := preload("res://scenes/ui/ui_icon.gd")
const TitleFlow := preload("res://scenes/title/title_flow.gd")
const Studio := preload("res://scenes/title/title_studio.gd")
const SLOT_SELECT: String = "res://scenes/title/slot_select.tscn"
const EVENT_LOBBY: String = "res://scenes/ui/event_lobby.tscn"
const SETTINGS: String = "res://scenes/ui/settings_menu.tscn"
const CONFIRM: String = "res://scenes/ui/confirm_dialog.tscn"
const VERSION_FALLBACK: String = "0.1.0"

## Menu entries in display order: id → Button (visible ones only).
var menu_buttons: Dictionary = {}

var _params: Dictionary = {}
var _menu: VBoxContainer
var _modal: Node = null
var _busy: bool = false
var _logo_t: float = 0.0
var _logo_a: Label
var _logo_b: Label
var _on_air_dot: Control


## Same code path as the menu: Game.new_game(...) → goto(SCENE_INTRO) or, if skip_intro,
## goto(SCENE_EXPLORATION, {"spawn": &"start"}).
func request_new_game(slot: int, player_name: String, skip_intro: bool, seed: int = -1,
		difficulty: StringName = &"prime", hero_id: String = "kai") -> void:
	if TitleFlow.start_new_game(slot, player_name, skip_intro, seed, difficulty, hero_id):
		_busy = true


func setup(params: Dictionary) -> void:
	_params = params


func _ready() -> void:
	UiUtil.full_rect(self)
	_build()
	Events.overlay_mode_requested.emit.call_deferred(&"menu")
	Sfx.music(&"title")
	focus_default()


func _process(delta: float) -> void:
	_logo_t += delta
	if _on_air_dot != null:
		_on_air_dot.modulate.a = 0.4 + 0.6 * (0.5 + 0.5 * cos(_logo_t * TAU))
	if _logo_a != null:
		var glitch: float = 1.0 if fmod(_logo_t, 4.0) < 0.06 else 0.0
		_logo_a.position.x = glitch * 4.0


func focus_default() -> void:
	for id: String in ["continue", "new", "load"]:
		if menu_buttons.has(id):
			UiUtil.focus_later((menu_buttons[id] as Control))
			return


## Menu ids in display order (tests / autoplay).
func menu_ids() -> PackedStringArray:
	var out: PackedStringArray = []
	for c: Node in _menu.get_children():
		if c is Button and c.has_meta("menu_id"):
			out.append(str(c.get_meta("menu_id")))
	return out


func activate(id: String) -> void:
	if _busy or (_modal != null and is_instance_valid(_modal)):
		return
	match id:
		"continue":
			var slot: int = Save.newest_slot()
			if slot <= 0:
				return
			var err: Error = TitleFlow.load_and_route(slot)
			if err == OK:
				_busy = true
			else:
				Sfx.play_ui(&"ui_error")
				Events.toast_requested.emit(TitleFlow.load_error_text(err), &"warning")
		"new":
			_busy = true
			Router.goto(SLOT_SELECT, {"mode": "new"})
		"load":
			_busy = true
			Router.goto(SLOT_SELECT, {"mode": "load"})
		"event":
			_busy = true
			Router.goto(EVENT_LOBBY)
		"options":
			_open_settings()
		"credits":
			_busy = true
			Router.goto(Router.SCENE_CREDITS, {"from_title": true})
		"quit":
			_ask_quit()


func _open_settings() -> void:
	if not ResourceLoader.exists(SETTINGS):
		return
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 60
	layer.name = "SettingsLayer"
	var menu: Control = (load(SETTINGS) as PackedScene).instantiate() as Control
	menu.call("setup", {"framed": true, "language": true})   # Sprachen (11 §1.9): the language row only here
	UiUtil.apply_theme(menu)
	layer.add_child(menu)
	add_child(layer)
	_modal = layer
	menu.connect("closed", func() -> void:
		layer.queue_free()
		_modal = null
		UiUtil.focus_later((menu_buttons["options"] as Control)))
	menu.connect("language_changed", _on_language_changed)   # Sprachen (11 §1.9, L1)


func _ask_quit() -> void:
	if not ResourceLoader.exists(CONFIRM):
		get_tree().quit()
		return
	var d: Node = (load(CONFIRM) as PackedScene).instantiate()
	d.call("setup", {"title": "Beenden", "text": "Sendung wirklich verlassen? M.O.D. wird das persönlich nehmen.",
		"yes": "Beenden", "no": "Bleiben", "default_no": true})
	d.connect("closed", func(yes: bool) -> void:
		_modal = null
		if yes:
			get_tree().quit()
		else:
			UiUtil.focus_later((menu_buttons["quit"] as Control)))
	add_child(d)
	_modal = d


# --- build -----------------------------------------------------------------------------------------------------------

func _build() -> void:
	var view: SubViewportContainer = SubViewportContainer.new()
	view.name = "Studio"
	view.stretch = true
	UiUtil.full_rect(view)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view)
	var vp: SubViewport = SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_2X if Game.settings != null and Game.settings.quality == &"high" \
		else Viewport.MSAA_DISABLED
	view.add_child(vp)
	vp.add_child(Studio.new())
	# Readability gradient on the left half.
	var shade: TextureRect = TextureRect.new()
	UiUtil.full_rect(shade)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grad: Gradient = Gradient.new()
	grad.set_color(0, Color(0.05, 0.03, 0.08, 0.9))
	grad.set_color(1, Color(0.05, 0.03, 0.08, 0.0))
	grad.add_point(0.42, Color(0.05, 0.03, 0.08, 0.62))
	var gt: GradientTexture2D = GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	gt.width = 256
	gt.height = 4
	shade.texture = gt
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(shade)
	var safe: SafeAreaContainer = SafeAreaContainer.new()
	safe.extra = 16
	add_child(safe)
	var frame: Control = Control.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(frame)
	_build_logo(frame)
	_build_menu(frame)
	_build_footer(frame)


func _build_logo(frame: Control) -> void:
	var col: VBoxContainer = UiUtil.vbox(-10)
	col.position = Vector2(8, 0)
	frame.add_child(col)
	_logo_a = UiUtil.label("PRIME TIME", &"LabelTitle", 40, UiTheme.C_ACCENT)
	col.add_child(_logo_a)
	_logo_b = UiUtil.label("DUNGEON", &"LabelTitle", 68)
	_logo_b.add_theme_constant_override("outline_size", 6)
	_logo_b.add_theme_color_override("font_outline_color", Color("#3a1050"))
	col.add_child(_logo_b)
	col.add_child(UiUtil.spacer(10))
	col.add_child(UiUtil.label(Tx.t("Eine Sendung des NOVA SYNDIKAT"), &"", 17, UiTheme.C_ACCENT_2))   # 11 §3.14
	var air: PanelContainer = PanelContainer.new()
	air.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	air.offset_left = -150
	air.offset_right = 0
	air.offset_bottom = 36
	air.add_theme_stylebox_override("panel", UiUtil.box_style(UiUtil.C_LIVE, Color(0, 0, 0, 0), 0, 0.21, 14, 3))
	frame.add_child(air)
	var arow: HBoxContainer = UiUtil.hbox(8)
	arow.alignment = BoxContainer.ALIGNMENT_CENTER
	air.add_child(arow)
	_on_air_dot = UiIcon.make(&"dot", UiUtil.C_PAPER, 12)
	_on_air_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	arow.add_child(_on_air_dot)
	var al: Label = UiUtil.label("ON AIR", &"", 20, UiUtil.C_PAPER)
	al.add_theme_font_override("font", UiTheme.font_bold())
	al.add_theme_constant_override("outline_size", 0)
	arow.add_child(al)


func _build_menu(frame: Control) -> void:
	_menu = UiUtil.vbox(12)                 # 12 px between entries (02_TECH §10.2 rule 5)
	_menu.name = "Menu"
	_menu.position = Vector2(8, 168)
	_menu.custom_minimum_size = Vector2(360, 0)
	frame.add_child(_menu)
	var entries: Array[Array] = []
	if Save.newest_slot() > 0:
		entries.append(["continue", "Fortsetzen"])
	entries.append(["new", "Neues Spiel"])
	entries.append(["load", "Laden"])
	entries.append(["event", "Event-Lauf"])
	entries.append(["options", "Optionen"])
	entries.append(["credits", "Credits"])
	if not UiUtil.is_mobile():
		entries.append(["quit", "Beenden"])
	var list: Array[Control] = []
	for e: Array in entries:
		var b: Button = UiUtil.button(str(e[1]), &"ButtonBig")
		b.name = "Menu_" + str(e[0])
		b.set_meta("menu_id", str(e[0]))
		b.custom_minimum_size = Vector2(360, 64)
		UiUtil.set_vmargin(b, 8.0)          # exactly 64 px high: 7 entries fit the safe rect
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var id: String = str(e[0])
		b.pressed.connect(func() -> void: activate(id))
		_menu.add_child(b)
		menu_buttons[id] = b
		list.append(b)
	UiUtil.wire_vertical(list)
	if entries.size() >= 7:
		_menu.position.y = 150.0
	if menu_buttons.has("continue"):
		var info: Dictionary = Save.slot_summary(Save.newest_slot())
		if not info.is_empty() and not bool(info.get("corrupt", false)):
			(menu_buttons["continue"] as Button).text = "Fortsetzen  ·  %s, Etage %d" % [
				str(info.get("player_name", "Kai")), int(info.get("floor_index", 1))]


## Footer on an ink strip (lower third): the "not purchasable" notice must stay legible over the pink stage glow.
func _build_footer(frame: Control) -> void:
	var strip: PanelContainer = PanelContainer.new()
	strip.name = "Footer"
	strip.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	strip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	strip.grow_vertical = Control.GROW_DIRECTION_BEGIN
	strip.offset_right = 0
	strip.offset_bottom = 0
	strip.add_theme_stylebox_override("panel", UiUtil.box_style(Color(UiTheme.C_PANEL, 0.85), Color(UiTheme.C_ACCENT_2,
		0.35), 1, 0.21, 18, 5))
	frame.add_child(strip)
	var foot: HBoxContainer = UiUtil.hbox(18)
	foot.alignment = BoxContainer.ALIGNMENT_END
	strip.add_child(foot)
	foot.add_child(InputGlyph.make(&"ui_accept", "Wählen", 16))
	var version: String = str(ProjectSettings.get_setting("application/config/version", VERSION_FALLBACK))
	var v: Label = UiUtil.label("v%s · Vertical Slice · Lootboxen sind nicht käuflich" % version, &"", 16, UiTheme.C_TEXT)
	v.add_theme_constant_override("outline_size", 2)
	v.add_theme_color_override("font_outline_color", UiUtil.C_INK)
	foot.add_child(v)


# --- Stempelduell (10, SD2) -------------------------------------------------------------------------------------------
## Titel → Extras → Stempelduell (Vorschau) (10 §4.7). "Extras" shares the Event-Lauf row as a half-width button: an
## eighth full row does not fit 720 px next to "Fortsetzen" and "Beenden" (menu_ids() keeps its entries). Hooked in
## additively: the member initializer connects `ready` (build the button) and `tree_entered` (back from the
## Schalterhalle: title music, overlay mode &"menu", focus on Extras). The rest lives in scenes/stempel/.
const SdExtras := preload("res://scenes/stempel/sd_extras.gd")

var extras_button: Button = null
var _sd_hooked: bool = _sd_hook()


func _sd_hook() -> bool:
	ready.connect(_sd_build_extras, CONNECT_ONE_SHOT)
	tree_entered.connect(_sd_on_tree_entered)
	return true


func _sd_build_extras() -> void:
	var ev: Button = menu_buttons.get("event") as Button
	if ev == null or _menu == null:
		return
	ev.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	ev.custom_minimum_size.x = 174.0
	extras_button = UiUtil.button("Extras", &"ButtonBig")
	extras_button.name = "Menu_extras"
	extras_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	extras_button.custom_minimum_size = Vector2(0, 64)
	UiUtil.set_vmargin(extras_button, 8.0)
	extras_button.pressed.connect(_sd_open_extras)
	_menu.get_parent().add_child(extras_button)
	ev.item_rect_changed.connect(_sd_place_extras)
	_menu.item_rect_changed.connect(_sd_place_extras)
	_sd_place_extras()
	var up: Node = ev.get_node_or_null(ev.focus_neighbor_top)
	var down: Node = ev.get_node_or_null(ev.focus_neighbor_bottom)
	if up != null:
		extras_button.focus_neighbor_top = extras_button.get_path_to(up)
	if down != null:
		extras_button.focus_neighbor_bottom = extras_button.get_path_to(down)
		extras_button.focus_next = extras_button.get_path_to(down)
	extras_button.focus_neighbor_left = extras_button.get_path_to(ev)
	extras_button.focus_neighbor_right = extras_button.get_path_to(ev)
	extras_button.focus_previous = extras_button.get_path_to(ev)
	ev.focus_neighbor_right = ev.get_path_to(extras_button)
	ev.focus_neighbor_left = ev.get_path_to(extras_button)
	ev.focus_next = ev.get_path_to(extras_button)


## Right of the (now half-width) Event-Lauf button, same row, up to the menu column's width.
func _sd_place_extras() -> void:
	var ev: Button = menu_buttons.get("event") as Button
	if extras_button == null or ev == null:
		return
	var x: float = ev.position.x + ev.size.x + 12.0
	extras_button.position = _menu.position + Vector2(x, ev.position.y)
	extras_button.size = Vector2(maxf(_menu.size.x - x, 120.0), ev.size.y)


func _sd_open_extras() -> void:
	if _busy or (_modal != null and is_instance_valid(_modal)):
		return
	var m: Node = SdExtras.open(self)
	_modal = m
	m.connect("closed", func() -> void: _modal = null)


## Back on top of the stack (Router.pop from the Schalterhalle): music, overlay and focus as after _ready.
func _sd_on_tree_entered() -> void:
	if extras_button == null:
		return
	Events.overlay_mode_requested.emit.call_deferred(&"menu")
	Sfx.music(&"title")
	UiUtil.focus_later(extras_button)


# --- Sprachen (11 §1.9, 11-L1) ----------------------------------------------------------------------------------------
## A new language from the options: the title rebuilds itself in it (Router.goto(SCENE_TITLE)) and reopens the options
## on the language row (setup {"options": "language"}). Hooked in additively like the Stempelduell section above.

var _lang_hooked: bool = _lang_hook()


func _lang_hook() -> bool:
	ready.connect(_lang_reopen_options, CONNECT_ONE_SHOT)
	return true


func _on_language_changed(_code: String) -> void:
	if _busy:
		return                                  # one rebuild; it shows the language applied last
	_busy = true
	Router.goto(Router.SCENE_TITLE, {"options": "language"})


func _lang_reopen_options() -> void:
	var row: String = str(_params.get("options", ""))
	if row == "":
		return
	_open_settings()
	var layer: Node = _modal
	var menu: Node = layer.get_child(0) if layer != null and layer.get_child_count() > 0 else null
	if menu != null and menu.has_method("focus_row"):
		menu.call("focus_row", row)
