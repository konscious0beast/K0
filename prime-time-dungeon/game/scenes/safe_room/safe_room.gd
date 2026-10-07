class_name SafeRoomScene extends Node3D
## Safe room (02_TECH §9.5, GDD §10, §14.7): EnvKit.build_safe_room(seed, quality, theme) with fixed camera (FOV 50),
## Kai + Graf Mopsula; Game.enter_safe_room(id) (full heal, scene context), Show.say("safe_room_enter"), overlay
## &"safe_room". Menu (left list, scene right): Speichern · Lootboxen (n) · Automat · Ausrüstung · Mopsula (!) · Weiter.
## Mopsula scenes (scenes.json) play through ModDialog as blocking lines, then Game.mark_scene_seen(); the next
## qualifying scene of the same visit becomes pending right away (several scenes per visit, e.g. scn_mop_2 +
## scn_mop_4, "NEU" badge + "!" stay); without a scene a `mopsula_idle` line. Shop via vending_menu (Game.buy), lootboxes via lootbox_opening (Game.open_lootbox).
## ModDialog sits right-aligned here (overlay mode &"safe_room"), so the menu column stays readable while M.O.D. talks.

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const InputGlyph := preload("res://scenes/ui/input_glyph.gd")
const UiIcon := preload("res://scenes/ui/ui_icon.gd")
const SceneKit := preload("res://scenes/ui/scene_kit.gd")
const SafeRoomSet := preload("res://scenes/safe_room/safe_room_set.gd")
const ModDialogScript := preload("res://scenes/ui/mod_dialog.gd")
const VENDING: String = "res://scenes/safe_room/vending_menu.tscn"
const LOOTBOX: String = "res://scenes/safe_room/lootbox_opening.tscn"
const SLOT_SELECT: String = "res://scenes/title/slot_select.tscn"
const PAUSE_MENU: String = "res://scenes/ui/pause_menu.tscn"
const DEFAULT_IDLE: PackedStringArray = ["Wir ruhen. Störe Uns nur bei Weltuntergang. Erneut.",
	"Ein Sofa. Endlich ein Möbel, das Unseren Stand begreift."]
const SCENE_TIMEOUT_SEC: float = 600.0

var safe_room_id: String = ""
var context: Dictionary = {}               # Game.enter_safe_room() result (scene conditions)
var pending_scene: SceneDef = null
var menu_buttons: Dictionary = {}          # id → Button
var stand_in: bool = false
var played_scenes: PackedStringArray = []  # scene ids played during this visit (never twice per visit)

var _params: Dictionary = {}
var _info: Dictionary = {}
var _room: Node3D
var _tv_drone: Node3D = null
var _hints: HBoxContainer
var _cam: Camera3D
var _kai: Node3D
var _mopsula: Node3D
var _bang: Label3D
var _ui: CanvasLayer
var _menu: VBoxContainer
var _status: Label
var _heal_banner: PanelContainer
var _header_sub: Label
var _modal: Node = null
var _busy: bool = false
var _t: float = 0.0
var _idle_i: int = 0
var _leaving: bool = false


## Stores params only: {"safe_room_id": String}; missing → first safe room of the floor.
func setup(params: Dictionary) -> void:
	_params = params


func _ready() -> void:
	Game.ensure_state()
	safe_room_id = _resolve_id()
	_info = UiUtil.safe_room_info(safe_room_id)
	_build_world()
	context = Game.enter_safe_room(safe_room_id)
	pending_scene = Game.next_scene(context)
	_build_ui()
	_update_bang()
	Events.overlay_mode_requested.emit.call_deferred(&"safe_room")
	Events.inventory_changed.connect(_refresh_menu_labels)
	Sfx.music(&"safe_room")
	Sfx.play(&"heal")
	Vfx.spawn(&"heal", self, _kai.global_position if _kai.is_inside_tree() else Vector3.ZERO)
	Show.say("safe_room_enter")
	_focus_first()


func _process(delta: float) -> void:
	_t += delta
	if _bang != null and _bang.visible:
		_bang.position.y = _bang_base_y() + sin(_t * 4.0) * 0.06
	if _tv_drone != null:
		SceneKit.animate_drone(_tv_drone, _t, 2.4)
	if _hints != null:
		var md: Node = ModDialogScript.current
		_hints.visible = not (md != null and is_instance_valid(md) and bool(md.call("is_busy")))


func _unhandled_input(event: InputEvent) -> void:
	if _busy or _leaving or (_modal != null and is_instance_valid(_modal)) or Router.busy:
		return
	if event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		open_pause("party")


# --- menu actions -------------------------------------------------------------------------------------------------------

func activate(id: String) -> void:
	if _busy or _leaving or (_modal != null and is_instance_valid(_modal)):
		return
	match id:
		"save":
			open_save()
		"lootbox":
			open_lootboxes()
		"vending":
			open_vending()
		"equipment":
			open_pause("equipment")
		"mopsula":
			talk_to_mopsula()
		"leave":
			leave()


func open_save() -> Node:
	if Game.mode == &"event_offline":
		_set_status("Im Event-Lauf wird nicht gespeichert – der Lauf zählt am Stück.", UiTheme.C_GOLD)
		Sfx.play_ui(&"ui_error")
		return null
	var layer: CanvasLayer = _modal_layer()
	var sel: Control = (load(SLOT_SELECT) as PackedScene).instantiate() as Control
	sel.call("setup", {"mode": "save", "embedded": true})
	layer.add_child(sel)
	sel.connect("slot_chosen", func(slot: int) -> void:
		var err: Error = Save.save_slot(slot)
		_close_modal(layer, "save")
		if err == OK:
			_set_status("Gespeichert in Slot %d – Startpunkt: dieser Safe Room." % slot, UiTheme.C_OK)
		else:
			_set_status("Speichern fehlgeschlagen: %s" % Save.last_error(), UiTheme.C_DANGER))
	sel.connect("cancelled", func() -> void: _close_modal(layer, "save"))
	return layer


func open_lootboxes() -> Node:
	var layer: CanvasLayer = (load(LOOTBOX) as PackedScene).instantiate() as CanvasLayer
	layer.call("setup", {"safe_room_id": safe_room_id})
	add_child(layer)
	_modal = layer
	layer.connect("closed", func() -> void: _after_modal("lootbox"))
	return layer


func open_vending() -> Node:
	var layer: CanvasLayer = (load(VENDING) as PackedScene).instantiate() as CanvasLayer
	layer.call("setup", {"safe_room_id": safe_room_id})
	add_child(layer)
	_modal = layer
	layer.connect("closed", func() -> void: _after_modal("vending"))
	return layer


func open_pause(tab: String) -> Node:
	if not ResourceLoader.exists(PAUSE_MENU):
		return null
	var pm: Node = (load(PAUSE_MENU) as PackedScene).instantiate()
	pm.call("setup", {"tab": tab, "context": "safe_room"})
	add_child(pm)
	_modal = pm
	pm.connect("closed", func() -> void: _after_modal("equipment" if tab == "equipment" else ""))
	return pm


## Plays the pending Mopsula scene (blocking ModDialog lines, then Game.mark_scene_seen) or an idle line.
func talk_to_mopsula() -> void:
	if pending_scene == null:
		_idle_line()
		return
	var scene: SceneDef = pending_scene
	pending_scene = null
	_busy = true
	_update_bang()
	_mopsula.call("play", &"victory")
	var tag: String = "scene:" + scene.id
	var dialog: Node = ModDialogScript.current
	if dialog != null and is_instance_valid(dialog):
		for line: Dictionary in scene.lines:
			var voice: StringName = StringName(str(line.get("voice", "mopsula")))
			Events.mod_said.emit(UiUtil.format_line(str(line.get("text", ""))), voice, tag, true)
		var waited: float = 0.0
		while is_instance_valid(dialog) and bool(dialog.call("is_busy")) and waited < SCENE_TIMEOUT_SEC:
			await get_tree().process_frame
			waited += get_process_delta_time()
	else:
		_set_status("Szene: %s" % UiUtil.tr_text(scene.name), UiTheme.C_GOLD)
	if not is_inside_tree():
		return
	Game.mark_scene_seen(scene)
	played_scenes.append(scene.id)
	# Another scene may qualify on the same visit (first_visit stays true in `context`): offer it right away.
	pending_scene = next_unplayed_scene()
	_mopsula.call("play", &"idle")
	_busy = false
	_update_bang()
	_refresh_menu_labels()
	(menu_buttons["mopsula"] as Control).grab_focus()


## Game.next_scene(context) without the scenes already played on this visit. A repeatable scene (once = false) that
## still qualifies would otherwise come back first every time and hide every later qualifying scene (DB order) for the
## rest of the visit. Game.next_scene has no skip list, so its filter is repeated here for that case only.
func next_unplayed_scene() -> SceneDef:
	var first: SceneDef = Game.next_scene(context)
	if first == null or not played_scenes.has(first.id):
		return first
	if Game.state == null or DB.data == null:
		return null
	var stats: Dictionary = Game.state.show.stats if Game.state.show != null else {}
	for sc: SceneDef in DB.data.all_scenes():
		if played_scenes.has(sc.id) or (sc.once and bool(Game.get_flag("scene_" + sc.id, false))):
			continue
		if sc.expr != null and sc.expr.eval(context, stats, Game.state.flags):
			return sc
	return null


func leave() -> void:
	if _leaving:
		return
	_leaving = true
	Sfx.play(&"door")
	Router.exit_safe_room()


func menu_ids() -> PackedStringArray:
	var out: PackedStringArray = []
	for c: Node in _menu.get_children():
		if c.has_meta("menu_id"):
			out.append(str(c.get_meta("menu_id")))
	return out


func status_text() -> String:
	return _status.text


# --- internals --------------------------------------------------------------------------------------------------------

func _resolve_id() -> String:
	var id: String = str(_params.get("safe_room_id", ""))
	if id != "":
		return id
	var def: FloorDef = Game.floor_def()
	var rooms: Array[Dictionary] = UiUtil.floor_safe_rooms(def)
	if not rooms.is_empty():
		return str(rooms[0]["id"])
	if def != null and Game.state != null and Game.state.floor_run != null:
		var layout: FloorLayout = DungeonGenerator.generate(def, Game.state.floor_run.seed)
		if layout != null and not layout.safe_room_ids.is_empty():
			var ids: Array = layout.safe_room_ids.values()
			ids.sort()
			return str(ids[0])
	return "sr_unknown"


func _theme() -> StringName:
	return StringName(str(_info.get("theme", "kiosk")))


func _build_world() -> void:
	var quality: StringName = Game.settings.quality if Game.settings != null else &"high"
	var seed_value: int = Game.state.seed if Game.state != null else 1
	var built: Dictionary = SafeRoomSet.build(seed_value + safe_room_id.hash(), quality, _theme())
	_room = built["room"]
	stand_in = bool(built["stand_in"])
	_room.name = "Room"
	add_child(_room)
	_tv_drone = _room.find_child("TvDrone", true, false) as Node3D     # cached: animated every frame
	var we: WorldEnvironment = WorldEnvironment.new()
	if stand_in:
		we.environment = SceneKit.environment(Color("#1a1218"), Color("#8a6a7a"), 0.7, true)
	else:
		we.environment = EnvKit.make_environment("metro", {}, &"safe", quality)
		add_child(EnvKit.make_sun("metro", &"safe", quality))
	add_child(we)
	_cam = Camera3D.new()
	_cam.name = "Camera"
	_cam.fov = 50.0
	_cam.current = true
	_cam.transform = SafeRoomSet.anchor(&"camera", stand_in)
	add_child(_cam)
	if not stand_in and _cam.transform.origin.is_equal_approx(Vector3.ZERO):
		_cam.transform = SafeRoomSet.anchor(&"camera", true)
	_kai = SceneKit.party_figure("kai")
	_kai.name = "Kai"
	_kai.transform = SafeRoomSet.anchor(&"player_spot", stand_in)
	add_child(_kai)
	_mopsula = SceneKit.party_figure("mopsula")
	_mopsula.name = "Mopsula"
	_mopsula.transform = SafeRoomSet.anchor(&"mopsula_spot", stand_in)
	add_child(_mopsula)
	_bang = Label3D.new()
	_bang.name = "SceneMarker"
	_bang.text = "!"
	_bang.font_size = 160
	_bang.pixel_size = 0.004
	_bang.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bang.no_depth_test = true
	_bang.modulate = UiTheme.C_GOLD
	_bang.outline_size = 24
	_bang.outline_modulate = Color("#140d1c")
	_mopsula.add_child(_bang)
	_bang.position = Vector3(0, _bang_base_y(), 0)


func _bang_base_y() -> float:
	var h: float = float(_mopsula.get("height")) if _mopsula != null else 0.6
	return maxf(h, 0.6) + 0.45


func _update_bang() -> void:
	if _bang != null:
		_bang.visible = pending_scene != null


func _focus_first() -> void:
	if menu_buttons.has("lootbox") and not (menu_buttons["lootbox"] as Button).disabled and \
			Game.state != null and not Game.state.pending_lootboxes.is_empty():
		UiUtil.focus_later((menu_buttons["lootbox"] as Control))
	elif pending_scene != null:
		UiUtil.focus_later((menu_buttons["mopsula"] as Control))
	else:
		UiUtil.focus_later((menu_buttons["save"] as Control))


func _modal_layer() -> CanvasLayer:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 60
	add_child(layer)
	_modal = layer
	return layer


func _close_modal(layer: Node, focus_id: String) -> void:
	if is_instance_valid(layer):
		layer.queue_free()
	_after_modal(focus_id)


func _after_modal(focus_id: String) -> void:
	_modal = null
	_refresh_menu_labels()
	if is_inside_tree() and menu_buttons.has(focus_id):
		UiUtil.focus_later((menu_buttons[focus_id] as Control))
	elif is_inside_tree():
		_focus_first()


func _idle_line() -> void:
	var said: String = Show.say("mopsula_idle")
	if said == "":
		var lines: Array[ModLineDef] = DB.mod_lines("mopsula_idle")
		var text: String = DEFAULT_IDLE[_idle_i % DEFAULT_IDLE.size()]
		if not lines.is_empty():
			text = lines[_idle_i % lines.size()].text
		_idle_i += 1
		Events.mod_said.emit(UiUtil.format_line(text), &"mopsula", "mopsula_idle", false)
	_mopsula.call("play", &"victory")
	Sfx.play_ui(&"ui_confirm")


func _set_status(text: String, col: Color) -> void:
	_status.text = UiUtil.glyph_safe(text)
	_status.add_theme_color_override("font_color", col)
	_status.modulate.a = 1.0
	if is_inside_tree():
		var tw: Tween = create_tween()
		tw.tween_interval(4.0)
		tw.tween_property(_status, "modulate:a", 0.0, 0.5)


func _refresh_menu_labels() -> void:
	if not is_inside_tree() or _menu == null:
		return
	var n: int = Game.state.pending_lootboxes.size() if Game.state != null else 0
	_set_button_text("lootbox", "Lootboxen (%d)" % n)
	(menu_buttons["lootbox"] as Button).disabled = n <= 0
	_set_button_text("mopsula", "Mopsula")
	var badge: Control = (menu_buttons["mopsula"] as Button).find_child("Badge", true, false) as Control
	if badge != null:
		badge.visible = pending_scene != null
	_set_button_text("save", "Speichern" if Game.mode != &"event_offline" else "Speichern (Event: aus)")
	_header_sub.text = "Credits %s  ·  Countdown angehalten%s" % [UiUtil.fmt_int(UiUtil.credits()),
		(": " + UiUtil.fmt_time(floori(Game.time_left()))) if Game.state != null and Game.state.floor_run != null and
		Game.state.floor_run.timer_started else ""]
	var list: Array[Control] = []
	for c: Node in _menu.get_children():
		if c is Button:
			list.append(c as Control)
			_style_enabled(c as Button)
	UiUtil.wire_vertical(list)


## Label + icon are children of the button, so the theme's font_disabled_color never reaches them: dim them here.
func _style_enabled(b: Button) -> void:
	var l: Label = b.find_child("Text", true, false) as Label
	if l != null:
		l.add_theme_color_override("font_color", UiTheme.C_TEXT_DIM if b.disabled else UiTheme.C_TEXT)
	var ic: Control = b.find_child("Icon", true, false) as Control
	if ic != null:
		ic.modulate = Color(0.55, 0.55, 0.6, 0.5) if b.disabled else Color.WHITE


func _set_button_text(id: String, text: String) -> void:
	var b: Button = menu_buttons.get(id) as Button
	if b != null:
		var l: Label = b.find_child("Text", true, false) as Label
		if l != null:
			l.text = text


# --- UI -----------------------------------------------------------------------------------------------------------------

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.name = "SafeRoomUi"
	_ui.layer = 5
	add_child(_ui)
	var root: Control = Control.new()
	UiUtil.full_rect(root)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiUtil.apply_theme(root)
	_ui.add_child(root)
	var grad: TextureRect = TextureRect.new()
	grad.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	grad.offset_right = 560
	grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var g: Gradient = Gradient.new()
	g.set_color(0, Color(0.06, 0.03, 0.08, 0.85))
	g.set_color(1, Color(0.06, 0.03, 0.08, 0.0))
	var gt: GradientTexture2D = GradientTexture2D.new()
	gt.gradient = g
	gt.width = 128
	gt.height = 4
	grad.texture = gt
	grad.stretch_mode = TextureRect.STRETCH_SCALE
	grad.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	root.add_child(grad)
	var safe: SafeAreaContainer = SafeAreaContainer.new()
	safe.extra = 0
	root.add_child(safe)
	var frame: Control = Control.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(frame)
	var col: VBoxContainer = UiUtil.vbox(4)
	col.position = Vector2(8, 60)
	col.custom_minimum_size = Vector2(380, 0)
	frame.add_child(col)
	var tag: PanelContainer = PanelContainer.new()
	tag.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tag.add_theme_stylebox_override("panel", UiUtil.box_style(UiUtil.C_EXIT, Color(0, 0, 0, 0), 0, 0.21, 14, 2))
	col.add_child(tag)
	var tl: Label = UiUtil.label("SAFE ROOM", &"", 15, UiUtil.C_INK)
	tl.add_theme_font_override("font", UiTheme.font_bold())
	tl.add_theme_constant_override("outline_size", 0)
	tag.add_child(tl)
	var title: Label = UiUtil.label(str(_info.get("name", "Safe Room")).to_upper(), &"LabelTitle", 38)
	col.add_child(title)
	_header_sub = UiUtil.label("", &"LabelSmall", 16)
	col.add_child(_header_sub)
	col.add_child(UiUtil.spacer(4))
	_menu = UiUtil.vbox(12)                  # 12 px between hit areas (02_TECH §10.2 rule 5)
	_menu.name = "Menu"
	col.add_child(_menu)
	for e: Array in [["save", "Speichern", &"floppy"], ["lootbox", "Lootboxen", &"box"], ["vending", "Automat", &"vending"],
			["equipment", "Ausrüstung", &"sword"], ["mopsula", "Mopsula", &"paw"], ["leave", "Weiter", &"door"]]:
		var b: Button = UiUtil.button("", &"ButtonBig")
		b.name = "Menu_" + str(e[0])
		b.set_meta("menu_id", str(e[0]))
		b.custom_minimum_size = Vector2(380, 64)
		var row: HBoxContainer = UiUtil.hbox(14)
		UiUtil.full_rect(row)
		row.offset_left = 20
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(row)
		var icon_col: Color = UiUtil.C_EXIT if str(e[0]) == "leave" else (UiTheme.C_GOLD if str(e[0]) == "mopsula"
			else UiTheme.C_ACCENT_2)
		var ic: Control = UiIcon.make(e[2] as StringName, icon_col, 28)
		ic.name = "Icon"
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(ic)
		var l: Label = UiUtil.label(str(e[1]), &"", 24)
		l.name = "Text"
		l.add_theme_font_override("font", UiTheme.font_bold())
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		if str(e[0]) == "mopsula":
			row.add_child(_new_badge())
		row.add_child(UiUtil.spacer(0, 16))
		var id: String = str(e[0])
		b.pressed.connect(func() -> void: activate(id))
		_menu.add_child(b)
		menu_buttons[id] = b
	_status = UiUtil.label("", &"", 17, UiTheme.C_OK)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(380, 0)
	col.add_child(_status)
	var hints: HBoxContainer = UiUtil.hbox(14)
	_hints = hints
	hints.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hints.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hints.offset_left = -420
	hints.offset_bottom = -22 - 14
	hints.offset_top = -22 - 14 - 26
	hints.alignment = BoxContainer.ALIGNMENT_END
	frame.add_child(hints)
	hints.add_child(InputGlyph.make(&"ui_accept", "Wählen", 16))
	hints.add_child(InputGlyph.make(&"pause", "Party-Menü", 16))
	_heal_banner = PanelContainer.new()
	_heal_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_heal_banner.offset_left = -150
	_heal_banner.offset_right = 230
	_heal_banner.offset_top = 70
	_heal_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_heal_banner.add_theme_stylebox_override("panel", UiUtil.box_style(Color(UiTheme.C_PANEL, 0.9), UiTheme.C_OK, 2, 0.21,
		18, 6))
	frame.add_child(_heal_banner)
	var hb: HBoxContainer = UiUtil.hbox(10)
	_heal_banner.add_child(hb)
	hb.add_child(UiIcon.make(&"heart", UiTheme.C_OK, 26))
	hb.add_child(UiUtil.label("VOLLE HEILUNG · HP & MP aufgefüllt", &"", 18, UiTheme.C_OK))
	if is_inside_tree() and not bool(_params.get("capture", false)):
		var tw: Tween = create_tween()
		tw.tween_interval(2.6)
		tw.tween_property(_heal_banner, "modulate:a", 0.0, 0.5)
	_refresh_menu_labels()


## Gold "NEU" pill on the Mopsula entry while a scene is pending (HYPE_GOLD with INK text, 03_ART §2.4).
func _new_badge() -> PanelContainer:
	var badge: PanelContainer = PanelContainer.new()
	badge.name = "Badge"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb: StyleBoxFlat = UiUtil.box_style(UiTheme.C_GOLD, UiUtil.C_INK, 2, 0.0, 10, 1)
	sb.set_corner_radius_all(14)
	badge.add_theme_stylebox_override("panel", sb)
	var t: Label = UiUtil.label("NEU", &"", 16, UiUtil.C_INK)
	t.add_theme_font_override("font", UiTheme.font_bold())
	t.add_theme_constant_override("outline_size", 0)
	badge.add_child(t)
	badge.visible = false
	return badge
