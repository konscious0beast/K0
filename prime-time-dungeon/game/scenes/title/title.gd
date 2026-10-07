class_name TitleScreen extends Control
## Title screen (02_TECH §9.5, GDD §14.1, 05 CR-10): 3D TV studio with the M.O.D. drone, logo and the menu
## Fortsetzen (Save.newest_slot() > 0 only) · Neues Spiel · Laden · Event-Lauf · Optionen · Credits ·
## Beenden (not on mobile). New game: slot select → name entry → intro; every path ends in request_new_game().

const UiUtil := preload("res://scenes/ui/ui_util.gd")
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
		difficulty: StringName = &"prime") -> void:
	if TitleFlow.start_new_game(slot, player_name, skip_intro, seed, difficulty):
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
	menu.call("setup", {"framed": true})
	UiUtil.apply_theme(menu)
	layer.add_child(menu)
	add_child(layer)
	_modal = layer
	menu.connect("closed", func() -> void:
		layer.queue_free()
		_modal = null
		UiUtil.focus_later((menu_buttons["options"] as Control)))


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
	col.add_child(UiUtil.label("Eine Sendung des NOVA SYNDIKAT", &"", 17, UiTheme.C_ACCENT_2))
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
	_menu = UiUtil.vbox(4)
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
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var id: String = str(e[0])
		b.pressed.connect(func() -> void: activate(id))
		_menu.add_child(b)
		menu_buttons[id] = b
		list.append(b)
	UiUtil.wire_vertical(list)
	if menu_buttons.has("continue"):
		var info: Dictionary = Save.slot_summary(Save.newest_slot())
		if not info.is_empty() and not bool(info.get("corrupt", false)):
			(menu_buttons["continue"] as Button).text = "Fortsetzen  ·  %s, Etage %d" % [
				str(info.get("player_name", "Kai")), int(info.get("floor_index", 1))]


func _build_footer(frame: Control) -> void:
	var foot: HBoxContainer = UiUtil.hbox(18)
	foot.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	foot.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	foot.grow_vertical = Control.GROW_DIRECTION_BEGIN
	foot.offset_left = -640
	foot.offset_top = -28
	foot.alignment = BoxContainer.ALIGNMENT_END
	frame.add_child(foot)
	foot.add_child(InputGlyph.make(&"ui_accept", "Wählen", 15))
	var version: String = str(ProjectSettings.get_setting("application/config/version", VERSION_FALLBACK))
	foot.add_child(UiUtil.label("v%s · Vertical Slice · Lootboxen sind nicht käuflich" % version, &"LabelSmall", 14))
