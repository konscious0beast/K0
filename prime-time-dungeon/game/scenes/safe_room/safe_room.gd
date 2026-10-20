class_name SafeRoomScene extends Node3D
## Safe room (02_TECH §9.5, GDD §10, §14.7): EnvKit.build_safe_room(seed, quality, theme) with fixed camera (FOV 50),
## Kai + Graf Mopsula; Game.enter_safe_room(id) (full heal, scene context), Show.say("safe_room_enter"), overlay
## &"safe_room". Menu (left column, scene right; 06 package A order): Lootboxen (n) · [Automat | Ausrüstung] ·
## Figur wechseln · Mopsula (!) · [Speichern | Weiter] — five rows of 64 px boxes in hit areas >= 88 px, 12 px apart
## (02_TECH §10.2 rule 5), so all seven entries fit between the header and the chat ticker at 720 px height, also in
## the phone touch layout (integration 06 A × B).
## "Figur wechseln" (06 §1.6, package A) makes the partner the controlled character
## (Game.set_hero, recorded; only here, free of charge): the two figures swap places (the hero stands in front, the
## partner rests on the sofa spot), M.O.D. comments (`hero_switch:<id>`).
## Mopsula scenes (scenes.json) play through ModDialog as blocking lines, then Game.mark_scene_seen(); the next
## qualifying scene of the same visit becomes pending right away (several scenes per visit, e.g. scn_mop_2 +
## scn_mop_4, "NEU" badge + "!" stay); without a scene a `mopsula_idle` line. Shop via vending_menu (Game.buy),
## lootboxes via lootbox_opening (Game.open_lootbox).
## ModDialog sits right-aligned here (overlay mode &"safe_room"), so the menu column stays readable while M.O.D. talks.
## 06 package B: while a talent choice is open (L3, L5 …) a gold "TALENT-SHOW · n offen" call-to-action button sits at
## the top right, level with the first menu row (outside the menu column; integration 06 A × B: clear of the
## right-aligned M.O.D. box at the bottom right, which talks on every visit and after "Figur wechseln"); it opens
## scenes/ui/talent_show.tscn (activate("talents")). Focus: first focus after pending lootboxes, ui_right from the
## right end of every menu row.
## Recall (06 §3.5, from floor 3): the RECALL button under the TALENT-SHOW (section at the end) while Casting names a
## member who can choose here; the Recall opens by itself on the first visit of a room while a first choice is open.

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
const TALENT_SHOW: String = "res://scenes/ui/talent_show.tscn"     # 06 package B
const DEFAULT_IDLE: PackedStringArray = [
	"Ich ruhe. Fußnote 4: Weltuntergänge bitte schriftlich einreichen. Und nicht vor Mitternacht.",
	"Ein Sofa. In Zwinger 7 gab es nur Beton. Ich nehme es in meine Memoiren auf."]
const SCENE_TIMEOUT_SEC: float = 600.0
const MENU_SCRIM_W: float = 640.0          # width of the dark gradient behind the menu column
const MENU_GAP: int = 12                   # 02_TECH §10.2 rule 5: 12 px between the hit areas
const MENU_W: float = 380.0                # menu column width (a row of two: 2 × 184 + 12)
const MENU_BOX_H: float = 64.0             # visible box of an entry; its hit area is UiTheme.TOUCH_HIT (88) high
const TITLE_SIZE: int = 32                 # 06 package A: one header line (tag + name) — 7 entries fit above the ticker
const CTA_TOP: float = 142.0               # TALENT-SHOW hit area top in frame px = the first menu row's top (test)
## Menu rows in reading order (menu_ids()): 5 rows × 88 px + 4 × 12 px = 488 px between header and chat ticker.
const MENU_ROWS: Array = [["lootbox"], ["vending", "equipment"], ["hero"], ["mopsula"], ["save", "leave"]]
const MENU_ENTRIES: Dictionary = {"lootbox": ["Lootboxen", &"box"], "vending": ["Automat", &"vending"],
	"equipment": ["Ausrüstung", &"sword"], "hero": ["Figur wechseln", &"swap"], "mopsula": ["Mopsula", &"paw"],
	"save": ["Speichern", &"floppy"], "leave": ["Weiter", &"door"]}

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
var _status_panel: PanelContainer = null
var _status_tween: Tween = null
var _heal_banner: PanelContainer
var _header_sub: Label
var _modal: Node = null
var _busy: bool = false
var _t: float = 0.0
var _idle_i: int = 0
var _leaving: bool = false
var _talent_cta: Button = null             # 06 package B: "TALENT-SHOW · n offen" (menu_buttons["talents"])


## Stores params only: {"safe_room_id": String}; missing → first safe room of the floor.
func setup(params: Dictionary) -> void:
	_params = params


func _ready() -> void:
	Game.ensure_state()
	safe_room_id = _resolve_id()
	_info = UiUtil.safe_room_info(safe_room_id)
	_build_world()
	context = Game.enter_safe_room(safe_room_id)
	Game.safe_room_clock = true                # run clock: idle ticks for the Sponsor-Fenster (05 §6.13)
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
	_recall_on_enter()                         # Recall (06 §3.5): opens by itself while a first choice is open


func _exit_tree() -> void:
	Game.safe_room_clock = false


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


# --- menu actions -----------------------------------------------------------------------------------------------------

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
		"hero":
			switch_hero()
		"mopsula":
			talk_to_mopsula()
		"talents":
			open_talent_show()
		"recall":                              # Recall (06 §3.5)
			open_recall()
		"leave":
			leave()


func open_save() -> Node:
	if Game.state != null and Game.state.season != null:   # Staffeln (09 §5.1, ST1-G): "Ausloggen" instead
		return open_logout()
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
	_set_menu_shown(false)
	layer.connect("closed", func() -> void: _after_modal("lootbox"))
	return layer


func open_vending() -> Node:
	var layer: CanvasLayer = (load(VENDING) as PackedScene).instantiate() as CanvasLayer
	layer.call("setup", {"safe_room_id": safe_room_id})
	add_child(layer)
	_modal = layer
	_set_menu_shown(false)
	layer.connect("closed", func() -> void: _after_modal("vending"))
	return layer


## 06 package B: Talent-Show modal (all open talent choices of both members, one after another).
func open_talent_show() -> Node:
	var layer: CanvasLayer = (load(TALENT_SHOW) as PackedScene).instantiate() as CanvasLayer
	layer.call("setup", {"safe_room_id": safe_room_id})
	add_child(layer)
	_modal = layer
	_set_menu_shown(false)
	layer.connect("closed", func() -> void: _after_modal("talents"))
	return layer


## 06 package B: true while the Talent-Show button is offered (an open talent choice exists).
func talent_show_available() -> bool:
	return _talent_cta != null and _talent_cta.visible


func open_pause(tab: String) -> Node:
	if not ResourceLoader.exists(PAUSE_MENU):
		return null
	var pm: Node = (load(PAUSE_MENU) as PackedScene).instantiate()
	pm.call("setup", {"tab": tab, "context": "safe_room"})
	add_child(pm)
	_modal = pm
	_set_menu_shown(false)
	pm.connect("closed", func() -> void: _after_modal("equipment" if tab == "equipment" else ""))
	return pm


## 06 §1.6: the partner takes the lead (Game.set_hero → recorded "hero" command). The figures swap places, the menu
## label follows, M.O.D. comments. false when the core refuses (not in a safe room, no state).
func switch_hero() -> bool:
	var next: String = Game.partner()
	if not Game.set_hero(next):
		Sfx.play_ui(&"ui_error")
		return false
	Sfx.play_ui(&"ui_confirm")
	_place_figures()
	_refresh_menu_labels()
	_set_status("Jetzt führt: %s." % _hero_name(next), UiTheme.C_GOLD)
	Show.say("hero_switch:" + next)
	var lead: Node3D = _mopsula if next == "mopsula" else _kai
	if lead != null and lead.has_method("play"):
		lead.call("play", &"victory")
	return true


## "Kai" (the player's name) | "Graf Mopsula".
static func _hero_name(member_id: String) -> String:
	return "Graf Mopsula" if member_id == "mopsula" else UiUtil.player_name()


## The controlled character stands on the player spot, the partner on the sofa spot (06 §1.6).
func _place_figures() -> void:
	if _kai == null or _mopsula == null:
		return
	var mop_leads: bool = Game.hero() == "mopsula"
	_kai.transform = SafeRoomSet.anchor(&"mopsula_spot" if mop_leads else &"player_spot", stand_in)
	_mopsula.transform = SafeRoomSet.anchor(&"player_spot" if mop_leads else &"mopsula_spot", stand_in)
	if _bang != null:
		_bang.position = Vector3(0, _bang_base_y(), 0)


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
	Game.safe_room_clock = false
	Sfx.play(&"door")
	Router.exit_safe_room()


## Menu entry ids in reading order (rows top to bottom, a row of two left to right; [Speichern | Weiter] last).
func menu_ids() -> PackedStringArray:
	var out: PackedStringArray = []
	for b: Button in _menu_buttons_in_order():
		out.append(str(b.get_meta("menu_id")))
	return out


func _menu_buttons_in_order() -> Array[Button]:
	var out: Array[Button] = []
	for c: Node in _menu.get_children():
		var row: Array[Node] = [c]
		if not c is Button:
			row = c.get_children()
		for n: Node in row:
			if n is Button and n.has_meta("menu_id"):
				out.append(n as Button)
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
	# the UI header names the room (top left): the same name on the back wall right behind the menu read as a duplicate
	var sign: Node3D = _room.find_child(EnvKit.SAFE_TITLE_SIGN, true, false) as Node3D
	if sign != null:
		sign.visible = false
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
	_place_figures()                           # 06 package A: the hero stands in front
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
	elif talent_show_available():
		UiUtil.focus_later(_talent_cta)
	elif pending_scene != null:
		UiUtil.focus_later((menu_buttons["mopsula"] as Control))
	else:
		UiUtil.focus_later((menu_buttons["save"] as Control))


func _modal_layer() -> CanvasLayer:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 60
	add_child(layer)
	_modal = layer
	_set_menu_shown(false)
	return layer


## The menu column is hidden while a modal (slot select, lootboxes, vending, equipment) covers the room: its buttons
## otherwise shone through the modals' translucent backdrops right under their own lists (visual pass).
func _set_menu_shown(on: bool) -> void:
	if _ui != null:
		_ui.visible = on


func _close_modal(layer: Node, focus_id: String) -> void:
	if is_instance_valid(layer):
		layer.queue_free()
	_after_modal(focus_id)


func _after_modal(focus_id: String) -> void:
	_modal = null
	_set_menu_shown(true)
	_refresh_menu_labels()
	_refresh_candidate()                       # Casting (08 §1.7, K2): the mask may have changed the look
	if is_inside_tree() and menu_buttons.has(focus_id):
		UiUtil.focus_later((menu_buttons[focus_id] as Control))
	elif is_inside_tree():
		_focus_first()


## Casting (08 §1.7, K2): after the pause menu (Kandidatenkarte → "Name & Aussehen ändern") the candidate stands
## here in the persona's current look (DB.party_model); unchanged → nothing is rebuilt.
func _refresh_candidate() -> void:
	if _kai == null or not is_instance_valid(_kai) or _kai.get("model") == DB.party_model("kai"):
		return
	remove_child(_kai)
	_kai.queue_free()
	_kai = SceneKit.party_figure("kai")
	_kai.name = "Kai"
	add_child(_kai)
	_place_figures()


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
	if _status_panel != null:
		_status_panel.add_theme_stylebox_override("panel", UiUtil.box_style(Color(UiTheme.C_PANEL, 0.92), col, 2, 0.21,
			18, 6))
		_status_panel.visible = text != ""
		_status_panel.modulate.a = 1.0
	if _heal_banner != null:
		_heal_banner.visible = false            # one banner at a time
	if _status_tween != null and _status_tween.is_valid():
		_status_tween.kill()
	if is_inside_tree() and _status_panel != null:
		_status_tween = create_tween()
		_status_tween.tween_interval(4.0)
		_status_tween.tween_property(_status_panel, "modulate:a", 0.0, 0.5)


func _refresh_menu_labels() -> void:
	if not is_inside_tree() or _menu == null:
		return
	var n: int = Game.state.pending_lootboxes.size() if Game.state != null else 0
	_set_button_text("lootbox", "Lootboxen (%d)" % n)
	(menu_buttons["lootbox"] as Button).disabled = n <= 0
	_set_button_text("mopsula", "Mopsula")
	var lead_l: Label = (menu_buttons["hero"] as Button).find_child("Lead", true, false) as Label
	if lead_l != null:
		lead_l.text = "%s führt" % ("Graf" if Game.hero() == "mopsula" else UiUtil.player_name())
	var badge: Control = (menu_buttons["mopsula"] as Button).find_child("Badge", true, false) as Control
	if badge != null:
		badge.visible = pending_scene != null
	_set_button_text("save", "Speichern")
	if Game.state != null and Game.state.season != null:   # Staffeln (09 §9.1, ST1-G): no "Speichern" in a season
		_set_button_text("save", "Ausloggen")
	_header_sub.text = "Credits %s  ·  Countdown angehalten%s" % [UiUtil.fmt_int(UiUtil.credits()),
		(": " + UiUtil.fmt_time(floori(Game.time_left()))) if Game.state != null and Game.state.floor_run != null and
		Game.state.floor_run.timer_started else ""]
	_season_header()                           # Staffeln (09 §2.5, ST1-H): the collapse, not a frozen countdown
	for b: Button in _menu_buttons_in_order():
		_style_enabled(b)
	var save_b: Button = menu_buttons.get("save") as Button
	if save_b != null and Game.mode == &"event_offline":   # no saving in event runs: dimmed, the press explains why
		(save_b.find_child("Text", true, false) as Label).add_theme_color_override("font_color", UiTheme.C_TEXT_DIM)
	_refresh_talent_cta()
	_wire_menu_focus()
	_refresh_recall_cta()                      # Recall (06 §3.5): its button and its place in the focus chain
	_season_place()                            # Staffeln (09 §4.3, ST1-H): the guests below those buttons


## 06 package B: the call-to-action shows the open talent choices (its focus: _wire_menu_focus).
func _refresh_talent_cta() -> void:
	if _talent_cta == null:
		return
	var n: int = Talents.open_choices(Game.state, DB.data) if Game.state != null else 0
	_talent_cta.visible = n > 0
	var sub: Label = _talent_cta.find_child("Sub", true, false) as Label
	if sub != null:
		sub.text = "1 Talentwahl offen" if n == 1 else "%d Talentwahlen offen" % n
		if Game.state != null and TalentTree.governs(Game.state):   # Staffeln (09 §8.4, ST1-D): rows of the tree
			sub.text = "1 Talentreihe offen" if n == 1 else "%d Talentreihen offen" % n


## Focus through the menu rows (02_TECH §10.2 rule 2): ui_up / ui_down move between the rows and wrap (from a row of
## two to its left entry), a row of two is crossed with ui_left / ui_right; ui_right from the right end of every row
## reaches the TALENT-SHOW button while it is shown (06 package B), ui_left from there leads back to the first row
## (level with it). Tab order = reading order (menu_ids(), then the TALENT-SHOW button).
func _wire_menu_focus() -> void:
	var rows: Array[Array] = []
	for c: Node in _menu.get_children():
		var kids: Array[Node] = [c]
		if not c is Button:
			kids = c.get_children()
		var row: Array[Control] = []
		for n: Node in kids:
			if n is Button and n.has_meta("menu_id"):
				row.append(n as Control)
		if not row.is_empty():
			rows.append(row)
	var cta: Control = _talent_cta if _talent_cta != null and _talent_cta.visible else null
	var order: Array[Control] = []
	for i in rows.size():
		var row: Array = rows[i]
		var above: Array = rows[(i + rows.size() - 1) % rows.size()]
		var below: Array = rows[(i + 1) % rows.size()]
		for j in row.size():
			var b: Control = row[j]
			b.focus_neighbor_top = b.get_path_to(above[mini(j, above.size() - 1)])
			b.focus_neighbor_bottom = b.get_path_to(below[mini(j, below.size() - 1)])
			b.focus_neighbor_left = b.get_path_to(row[j - 1] if j > 0 else b)
			var right: Control = row[j + 1] if j < row.size() - 1 else (cta if cta != null else b)
			b.focus_neighbor_right = b.get_path_to(right)
			order.append(b)
	if cta != null:
		order.append(cta)
		var first: Array = rows[0]
		cta.focus_neighbor_left = cta.get_path_to(first[first.size() - 1])
		cta.focus_neighbor_top = cta.get_path_to(cta)
		cta.focus_neighbor_bottom = cta.get_path_to(cta)
		cta.focus_neighbor_right = cta.get_path_to(cta)
	for k in order.size():
		order[k].focus_previous = order[k].get_path_to(order[(k + order.size() - 1) % order.size()])
		order[k].focus_next = order[k].get_path_to(order[(k + 1) % order.size()])


func _build_talent_cta(frame: Control) -> void:
	var b: Button = UiUtil.button("", &"ButtonBig")
	b.name = "TalentShowButton"
	b.set_meta("menu_id", "talents")
	b.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	b.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	b.offset_left = -380
	b.offset_right = -8
	b.offset_top = CTA_TOP                     # hit area 88 px, visible box 80 px (touch_pad below)
	b.offset_bottom = CTA_TOP + UiTheme.TOUCH_HIT
	var normal: StyleBoxFlat = UiUtil.box_style(Color(UiTheme.C_PANEL, 0.95), UiTheme.C_GOLD, 3, 0.0, 16, 8)
	normal.set_corner_radius_all(8)
	var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.25, 0.17, 0.08, 0.95)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	var row: HBoxContainer = UiUtil.hbox(14)
	UiUtil.full_rect(row)
	row.offset_left = 18
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var ic: Control = UiIcon.make(&"star", UiTheme.C_GOLD, 36)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	var col: VBoxContainer = UiUtil.vbox(-2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(col)
	var t: Label = UiUtil.label("TALENT-SHOW", &"", 26, UiTheme.C_GOLD)
	t.name = "Text"
	t.add_theme_font_override("font", UiTheme.font_bold())
	col.add_child(t)
	var sub: Label = UiUtil.label("", &"", 17, UiTheme.C_TEXT)
	sub.name = "Sub"
	col.add_child(sub)
	b.pressed.connect(func() -> void: activate("talents"))
	UiUtil.touch_pad(b, 80.0)
	b.visible = false
	frame.add_child(b)
	_talent_cta = b
	menu_buttons["talents"] = b


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


# --- UI ---------------------------------------------------------------------------------------------------------------

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
	grad.offset_right = MENU_SCRIM_W
	grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# scrim behind the menu column: solid enough that props and their emissive signs (vending machine) read as
	# background, fading out right of the column (visual pass)
	var g: Gradient = Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.62, 1.0])
	g.colors = PackedColorArray([Color(0.06, 0.03, 0.08, 0.9), Color(0.06, 0.03, 0.08, 0.72),
		Color(0.06, 0.03, 0.08, 0.0)])
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
	# 06 package A: tag and room name share one line (7 menu entries must fit above the chat ticker)
	var head: HBoxContainer = UiUtil.hbox(12)
	col.add_child(head)
	var tag: PanelContainer = PanelContainer.new()
	tag.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tag.add_theme_stylebox_override("panel", UiUtil.box_style(UiUtil.C_EXIT, Color(0, 0, 0, 0), 0, 0.21, 14, 2))
	head.add_child(tag)
	var tl: Label = UiUtil.label("SAFE ROOM", &"", 15, UiUtil.C_INK)
	tl.add_theme_font_override("font", UiTheme.font_bold())
	tl.add_theme_constant_override("outline_size", 0)
	tag.add_child(tl)
	var title: Label = UiUtil.label(str(_info.get("name", "Safe Room")).to_upper(), &"LabelTitle", TITLE_SIZE)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(title)
	_header_sub = UiUtil.label("", &"LabelSmall", 16)
	col.add_child(_header_sub)
	col.add_child(UiUtil.spacer(2))
	_menu = UiUtil.vbox(MENU_GAP)            # 12 px between the hit areas (02_TECH §10.2 rule 5)
	_menu.name = "Menu"
	col.add_child(_menu)
	for ids: Array in MENU_ROWS:
		if ids.size() == 1:
			_menu.add_child(_menu_button(str(ids[0]), false))
			continue
		var pair: HBoxContainer = UiUtil.hbox(MENU_GAP)
		pair.name = "Row_" + "_".join(PackedStringArray(ids))
		_menu.add_child(pair)
		for id_v: Variant in ids:
			pair.add_child(_menu_button(str(id_v), true))
	# 06 package A: the status (saved, switched, …) is a top-centre banner like the heal banner — the menu column has
	# no room left below its 7 entries
	_status_panel = PanelContainer.new()
	_status_panel.name = "StatusBanner"
	_status_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_status_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_status_panel.offset_top = 70
	_status_panel.offset_left = -40
	_status_panel.offset_right = 120
	_status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_panel.visible = false
	frame.add_child(_status_panel)
	_status = UiUtil.label("", &"", 18, UiTheme.C_OK)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(380, 0)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_panel.add_child(_status)
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
	_build_talent_cta(frame)                    # 06 package B
	_build_recall_cta(frame)                    # Recall (06 §3.5)
	_season_build(frame)                        # Staffeln (09 §4.3, ST1-H): the AI candidates in this safe room
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


## One menu entry (icon + bold label; Mopsula: "NEU" badge, Figur wechseln: "… führt"): a 64 px visible box inside a
## hit area of UiTheme.TOUCH_HIT (UiUtil.touch_pad, 02_TECH §10.2 rule 5) — full width or half of a row of two.
func _menu_button(id: String, half: bool) -> Button:
	var entry: Array = MENU_ENTRIES[id]
	var b: Button = UiUtil.button("", &"ButtonBig")
	b.name = "Menu_" + id
	b.set_meta("menu_id", id)
	b.custom_minimum_size = Vector2((MENU_W - MENU_GAP) * 0.5 if half else MENU_W, MENU_BOX_H)
	var row: HBoxContainer = UiUtil.hbox(8 if half else 14)
	UiUtil.full_rect(row)
	row.offset_left = 12 if half else 20
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var icon_col: Color = UiUtil.C_EXIT if id == "leave" else (UiTheme.C_GOLD if id == "mopsula" else UiTheme.C_ACCENT_2)
	var ic: Control = UiIcon.make(entry[1] as StringName, icon_col, 26 if half else 28)
	ic.name = "Icon"
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	var l: Label = UiUtil.label(str(entry[0]), &"", 21 if half else 24)   # "Ausrüstung" fits a half row
	l.name = "Text"
	l.add_theme_font_override("font", UiTheme.font_bold())
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	if id == "mopsula":
		row.add_child(_new_badge())
	if id == "hero":
		var lead: Label = UiUtil.label("", &"", 16, UiTheme.C_TEXT_DIM)
		lead.name = "Lead"
		lead.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(lead)
	row.add_child(UiUtil.spacer(0, 8 if half else 16))
	b.pressed.connect(func() -> void: activate(id))
	UiUtil.touch_pad(b, MENU_BOX_H)
	menu_buttons[id] = b
	return b


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


# --- Staffeln (09, ST1-G) ---------------------------------------------------------------------------------------------
# A season saves by itself (09 §9.1): the menu's "Speichern" says "Ausloggen" and opens the logout dialog — the short
# path of a safe room ("sicher, Sie werden ausgeruht", no tactic); "Hier schlafen" goes to the title.

const LOGOUT: String = "res://scenes/ui/logout_dialog.tscn"


func open_logout() -> Node:
	var d: CanvasLayer = (load(LOGOUT) as PackedScene).instantiate() as CanvasLayer
	d.call("setup", {"context": "safe_room"})
	add_child(d)
	_modal = d
	d.connect("closed", func(slept: bool) -> void:
		_modal = null
		if not slept and menu_buttons.has("save"):
			UiUtil.focus_later(menu_buttons["save"] as Control))
	return d


# --- Recall (06 §3.5) -------------------------------------------------------------------------------------------------
# From floor 3 on (06 §0.6; the wish behind it: species and class from floor 3, not from level 3): the Recall
# (scenes/ui/recall.tscn) — the show segment where M.O.D. sits on the jury and every party member chooses a species
# and a class. A RECALL button at the top right (under the TALENT-SHOW while that one is shown) is there while
# Casting.open_members names a member who can choose here: a first choice (any safe room of the floor), trying again
# during the visit of the choice, the Umschulung in the first safe room of a later floor (06 §3.6). The first visit of
# a room while a first choice is open opens the Recall by itself (06 §3.5 step 1); a revisit only offers the button.

const RECALL: String = "res://scenes/ui/recall.tscn"
const RECALL_SUBS: Dictionary = {"first": "Spezies & Klasse wählen", "redo": "Umentscheiden – noch frei",
	"retrain": "Umschulung: Klasse wechseln"}
const C_RECALL: Color = Color("#ff2e88")    # M.O.D.'s jury colour (NOVA magenta, 03_ART §2.4)

var _recall_cta: Button = null


## The Recall modal for every member Casting.open_members names (the hero first); null when nobody can choose here.
func open_recall() -> Node:
	if Game.state == null or Casting.open_members(Game.state, DB.data).is_empty():
		return null
	var layer: CanvasLayer = (load(RECALL) as PackedScene).instantiate() as CanvasLayer
	layer.call("setup", {"safe_room_id": safe_room_id})
	add_child(layer)
	_modal = layer
	_set_menu_shown(false)
	layer.connect("closed", _recall_closed)
	_season_watch_recall(layer)                # Staffeln (09 §0.6, ST1-H): the tempo offer after a first class choice
	return layer


## True while the RECALL button is offered (someone can choose here).
func recall_available() -> bool:
	return _recall_cta != null and _recall_cta.visible


## The strongest mode among the members who can choose here: first > retrain > redo ("" = none).
func recall_mode() -> String:
	if Game.state == null:
		return ""
	var modes: PackedStringArray = []
	for mid: String in Casting.open_members(Game.state, DB.data):
		modes.append(Casting.mode(Game.state, DB.data, mid))
	for m: String in ["first", "retrain", "redo"]:
		if modes.has(m):
			return m
	return ""


## 06 §3.5 step 1: the first visit of a room while a first choice is open opens the Recall (deferred: the room is
## built and entered first). A capture or test can keep the room alone ({"recall": false}). Otherwise the button takes
## the first focus when nothing more pressing waits (lootboxes, the Talent-Show).
func _recall_on_enter() -> void:
	if Game.state == null:
		return
	if recall_mode() == "first" and bool(context.get("first_visit", false)) and bool(_params.get("recall", true)):
		_recall_auto.call_deferred()
	elif recall_available() and Game.state.pending_lootboxes.is_empty() and not talent_show_available():
		UiUtil.focus_later(_recall_cta)


func _recall_auto() -> void:
	if is_inside_tree() and not _leaving and not _busy and (_modal == null or not is_instance_valid(_modal)):
		open_recall()


func _recall_closed() -> void:
	_after_modal("")
	if recall_available():
		UiUtil.focus_later(_recall_cta)


func _build_recall_cta(frame: Control) -> void:
	var b: Button = UiUtil.button("", &"ButtonBig")
	b.name = "RecallButton"
	b.set_meta("menu_id", "recall")
	b.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	b.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	b.offset_left = -380
	b.offset_right = -8
	b.offset_top = CTA_TOP
	b.offset_bottom = CTA_TOP + UiTheme.TOUCH_HIT
	var normal: StyleBoxFlat = UiUtil.box_style(Color(UiTheme.C_PANEL, 0.95), C_RECALL, 3, 0.0, 16, 8)
	normal.set_corner_radius_all(8)
	var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.3, 0.07, 0.18, 0.95)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	var row: HBoxContainer = UiUtil.hbox(14)
	UiUtil.full_rect(row)
	row.offset_left = 18
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var ic: Control = UiIcon.make(&"mic", C_RECALL, 34)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	var col: VBoxContainer = UiUtil.vbox(-2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(col)
	var t: Label = UiUtil.label("RECALL", &"", 26, C_RECALL.lightened(0.25))
	t.name = "Text"
	t.add_theme_font_override("font", UiTheme.font_bold())
	col.add_child(t)
	var sub: Label = UiUtil.label("", &"", 17, UiTheme.C_TEXT)
	sub.name = "Sub"
	col.add_child(sub)
	b.pressed.connect(func() -> void: activate("recall"))
	UiUtil.touch_pad(b, 80.0)
	b.visible = false
	frame.add_child(b)
	_recall_cta = b
	menu_buttons["recall"] = b


## Shown while someone can choose here; under the TALENT-SHOW (one hit area and the 12-px gap lower) while that one
## is shown, else level with the first menu row.
func _refresh_recall_cta() -> void:
	if _recall_cta == null:
		return
	var mode: String = recall_mode()
	_recall_cta.visible = mode != ""
	var top: float = CTA_TOP + (float(UiTheme.TOUCH_HIT + MENU_GAP) if talent_show_available() else 0.0)
	_recall_cta.offset_top = top
	_recall_cta.offset_bottom = top + UiTheme.TOUCH_HIT
	var sub: Label = _recall_cta.find_child("Sub", true, false) as Label
	if sub != null:
		sub.text = str(RECALL_SUBS.get(mode, ""))
	_wire_recall_focus()


## The button in the focus chain (after _wire_menu_focus): ui_right from every row reaches it when no TALENT-SHOW is
## shown, ui_down from the TALENT-SHOW otherwise; ui_left leads back to the first row; Tab after the last entry.
func _wire_recall_focus() -> void:
	var r: Button = _recall_cta
	if r == null or not r.visible:
		return
	var order: Array[Button] = _menu_buttons_in_order()
	if order.is_empty():
		return
	var talent: Control = _talent_cta if talent_show_available() else null
	if talent == null:
		for ids: Array in MENU_ROWS:
			var e: Control = menu_buttons.get(str(ids.back())) as Control
			if e != null:
				e.focus_neighbor_right = e.get_path_to(r)
		r.focus_neighbor_top = r.get_path_to(r)
	else:
		talent.focus_neighbor_bottom = talent.get_path_to(r)
		r.focus_neighbor_top = r.get_path_to(talent)
	var first_end: Control = menu_buttons.get(str((MENU_ROWS[0] as Array).back())) as Control
	r.focus_neighbor_left = r.get_path_to(first_end if first_end != null else order[0])
	r.focus_neighbor_bottom = r.get_path_to(r)
	r.focus_neighbor_right = r.get_path_to(r)
	var prev: Control = talent if talent != null else order[order.size() - 1]
	var first: Control = order[0]
	prev.focus_next = prev.get_path_to(r)
	r.focus_previous = r.get_path_to(prev)
	r.focus_next = r.get_path_to(first)
	first.focus_previous = first.get_path_to(r)


# --- Staffeln (09, ST1-H) ---------------------------------------------------------------------------------------------
# 09 §4.3: up to two AI candidates of the floor sit in this safe room (CastSim.safe_room_guests, deterministic per
# visit) — a panel on the right below the call-to-action buttons (TALENT-SHOW, RECALL; the TALENT-SHOW's place stays
# free without them), clear of the M.O.D. box at the bottom right: one button per guest with the name (labelled "KI"),
# profile, place and level. Below both buttons only one guest fits (a Helfer:in who can come first). Pressing it:
# "Reden" (M.O.D. quotes them, season_guest_<profile>) or, for a Helfer:in who can come, "Anheuern" (three combats,
# never a boss fight; a favour pays first, else credits — a dialog names the price; Game.cast_action("hire") records
# it, a refusal names its reason). The header names the collapse of the floor (calendar) or the standing countdown (Am
# Stück) instead of "Countdown angehalten". The tempo offer (09 §0.6: the Recall on floor 3, "danach das
# Tempo-Angebot"): when the Recall closes after a first class choice, M.O.D. offers "Am Stück" once on this device in
# a private calendar season (season_dialog; career "seen"). The Recall's end page names the Ohne-Netz unlock itself.

const SeasonView := preload("res://scenes/ui/season_view.gd")
const SEASON_DIALOG: String = "res://scenes/ui/season_dialog.tscn"
const GUESTS_W: float = 560.0
const GUESTS_MAX: int = 2                   # 09 §4.3: up to two AI candidates in a safe room

var season_guests: PanelContainer = null
var season_guest_buttons: Dictionary = {}    # "talk_<place>" | "hire_<place>" → Button (tests)
var _season_guest_list: VBoxContainer
var _season_limit: int = GUESTS_MAX         # guests shown: below two call-to-action buttons one (_season_place)
var _season_offering: bool = false


func _season_build(frame: Control) -> void:
	if Game.state == null or Game.state.season == null:
		return
	season_guests = PanelContainer.new()
	season_guests.name = "SeasonGuests"
	season_guests.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	season_guests.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	season_guests.offset_left = -GUESTS_W - 8.0
	season_guests.offset_right = -8.0
	season_guests.offset_top = CTA_TOP + UiTheme.TOUCH_HIT + MENU_GAP   # below the TALENT-SHOW (_season_place)
	season_guests.add_theme_stylebox_override("panel", UiUtil.box_style(Color(UiTheme.C_PANEL, 0.88),
		Color(UiTheme.C_ACCENT_2, 0.45), 1, 0.0, 14, 8))
	frame.add_child(season_guests)
	_season_guest_list = UiUtil.vbox(MENU_GAP)
	season_guests.add_child(_season_guest_list)
	season_refresh_guests()


## Rebuilds the guest rows (after a hire the Helfer:in shows as Begleitung); hidden without guests.
func season_refresh_guests() -> void:
	if season_guests == null:
		return
	for c: Node in _season_guest_list.get_children():
		_season_guest_list.remove_child(c)
		c.queue_free()
	season_guest_buttons.clear()
	var rows: Array[Dictionary] = []
	if CastSim.has_cast(Game.state):
		rows = _season_pick(SeasonView.guest_rows(Game.state, DB.data), _season_limit)
	season_guests.visible = not rows.is_empty()
	if rows.is_empty():
		return
	var head: Label = _season_flat(UiUtil.label("KI-KANDIDAT:INNEN IM SAFE ROOM", &"", 16, UiTheme.C_ACCENT))
	head.add_theme_font_override("font", UiTheme.font_bold())
	_season_guest_list.add_child(head)
	var guest: Dictionary = CastSim.guest(Game.state, DB.data)
	for r: Dictionary in rows:
		_season_guest_list.add_child(_season_guest_row(r, guest))


## One guest is one button: the name (labelled "KI"), below the profile, place and level — or the Begleitung, or why a
## Helfer:in cannot come — and on the right what pressing does: "Anheuern" (a Helfer:in who can come: the dialog with
## the price) or "Reden" (M.O.D. quotes the guest). One box per guest keeps the panel at ≈ 8 UI draw calls (the safe
## room's budget is 100, PERFORMANCE.md §3.11).
func _season_guest_row(r: Dictionary, guest: Dictionary) -> Control:
	var place: int = int(r["place"])
	var hire: bool = r.has("hire_refusal") and str(r["hire_refusal"]) == ""
	var b: Button = UiUtil.button("", &"")
	b.name = "Guest_%d" % place
	b.custom_minimum_size = Vector2(0, MENU_BOX_H)
	var row: HBoxContainer = UiUtil.hbox(MENU_GAP)
	UiUtil.full_rect(row)
	row.offset_left = 16
	row.offset_right = -16
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var texts: VBoxContainer = UiUtil.vbox(0)
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(texts)
	var n: Label = _season_flat(UiUtil.label(UiUtil.glyph_safe(str(r["label"])), &"", 19, UiTheme.C_TEXT))
	n.name = "Name"
	n.add_theme_font_override("font", UiTheme.font_bold())
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	texts.add_child(n)
	var line: String = "%s · %s" % [str(r["profile_name"]), str(r["line"])]
	if not guest.is_empty() and int(guest.get("who", -1)) == place:
		line = "Ihre Begleitung · noch %d %s" % [int(guest["left"]), "Kampf" if int(guest["left"]) == 1 else "Kämpfe"]
	elif r.has("hire_refusal") and str(r["hire_refusal"]) != "" and str(r["hire_refusal"]) != "not_here":
		line = SeasonView.cast_reason(str(r["hire_refusal"]))
	var sub: Label = _season_flat(UiUtil.label(UiUtil.glyph_safe(line), &"", 16, UiTheme.C_TEXT_DIM))
	sub.name = "Line"
	sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	texts.add_child(sub)
	var act: Label = _season_flat(UiUtil.label("Anheuern" if hire else "Reden", &"", 16,
		UiTheme.C_GOLD if hire else UiTheme.C_ACCENT_2))
	act.name = "Action"
	act.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(act)
	if hire:
		b.pressed.connect(func() -> void: season_ask_hire(place))
	else:
		b.pressed.connect(func() -> void: _season_talk(r))
	UiUtil.touch_pad(b, MENU_BOX_H)
	season_guest_buttons[("hire_%d" if hire else "talk_%d") % place] = b
	return b


## A label of the guest panel without the theme's outline: it sits on the panel, and an outline costs a second draw
## call per label (02_TECH §12.1).
func _season_flat(l: Label) -> Label:
	l.add_theme_constant_override("outline_size", 0)
	return l


## "Reden": M.O.D. quotes the guest (season_guest_<profile>, the line by the visit).
func _season_talk(r: Dictionary) -> void:
	if _modal != null and is_instance_valid(_modal):
		return
	Sfx.play_ui(&"ui_confirm")
	var tag: String = "season_guest_" + str(r["profile"])
	if Show.say(tag, {"cand": str(r["label"])}) == "":
		Events.mod_said.emit(UiUtil.mod_line(tag, {"cand": str(r["label"])}, Game.state.floor_run.safe_room_visits),
			&"mod", tag, false)


## "Anheuern" asks first: who, for how long, the price (a favour or credits), then records the hire.
func season_ask_hire(place: int) -> Node:
	if (_modal != null and is_instance_valid(_modal)) or not ResourceLoader.exists(SEASON_DIALOG):
		return null
	var why: String = CastSim.refusal(Game.state, DB.data, {"t": "cast", "op": "hire", "who": place})
	if why != "":
		Sfx.play_ui(&"ui_error")
		_set_status(SeasonView.cast_reason(why), UiTheme.C_DANGER)
		return null
	var d: Node = (load(SEASON_DIALOG) as PackedScene).instantiate()
	var cost: String = SeasonView.hire_cost_text(Game.state, DB.data)
	var who: String = CastSim.label(Game.state, DB.data, place)
	d.call("setup", {"title": "%s anheuern?" % who, "kicker": "HELFER:IN",
		"lines": [UiUtil.mod_line("season_guest_helper", {"cand": who}, Game.state.floor_run.safe_room_visits),
		"Kommt für %d Kämpfe mit — nie in einen Bosskampf." % CastSim.HIRE_FIGHTS,
		"Kosten: %s · Sie haben %s Credits." % [cost, UiUtil.fmt_int(UiUtil.credits())]],
		"buttons": [{"id": "no", "text": "Lieber nicht"}, {"id": "hire", "text": "Anheuern"}], "focus": "hire",
		"cancel_id": "no"})
	_modal = d
	add_child(d)
	d.connect("closed", func(id: String, _days: int) -> void:
		_modal = null
		if id == "hire":
			if Game.cast_action("hire", place):
				Sfx.play_ui(&"ui_confirm")
				_set_status("%s kommt für %d Kämpfe mit." % [CastSim.label(Game.state, DB.data, place),
					CastSim.HIRE_FIGHTS], UiTheme.C_OK)
			else:
				Sfx.play_ui(&"ui_error")
				_set_status(SeasonView.cast_reason(CastSim.refusal(Game.state, DB.data, {"t": "cast", "op": "hire",
					"who": place})), UiTheme.C_DANGER)
		season_refresh_guests()
		_refresh_menu_labels()                  # the credits, and the guests' place and focus (_season_place)
		var back: Control = season_guest_buttons.get("talk_%d" % place, season_guest_buttons.get("hire_%d" % place,
			null)) as Control
		UiUtil.focus_later(back if back != null else menu_buttons["save"] as Control))
	return d


## The header in a season: credits · the collapse of the floor (calendar) or the standing countdown (Am Stück).
func _season_header() -> void:
	var st: GameState = Game.state
	if st == null or st.season == null or _header_sub == null:
		return
	var parts: PackedStringArray = ["Credits %s" % UiUtil.fmt_int(UiUtil.credits())]
	var cv: Dictionary = SeasonView.collapse_view(st, 0, SeasonView.tz_offset())
	if not cv.is_empty():
		parts.append("%s (%s)" % [str(cv["text"]), str(cv["sub"])])
	elif st.season.tempo == "binge" and st.floor_run != null and st.floor_run.timer_started:
		parts.append("Countdown steht: %s" % UiUtil.fmt_time(floori(Game.time_left())))
	_header_sub.text = UiUtil.glyph_safe("  ·  ".join(parts))


## The `n` guests shown when not all fit: a Helfer:in who can come first (her button hires), then CastSim's order.
static func _season_pick(rows: Array[Dictionary], n: int) -> Array[Dictionary]:
	if rows.size() <= n:
		return rows
	var out: Array[Dictionary] = []
	for r: Dictionary in rows:
		if out.size() < n and str(r.get("hire_refusal", "-")) == "":
			out.append(r)
	for r: Dictionary in rows:
		if out.size() < n and not out.has(r):
			out.append(r)
	return out


## The guests' place (after _refresh_recall_cta): below the lowest call-to-action button on the right (TALENT-SHOW,
## RECALL), else below the TALENT-SHOW's place; below both only one guest fits above M.O.D.'s box (every format draws
## on a 720-px-high canvas). Then their focus.
func _season_place() -> void:
	if season_guests == null:
		return
	var above: Control = null
	var bottom: float = CTA_TOP + UiTheme.TOUCH_HIT
	var shown: int = 0
	for c: Control in [_talent_cta, _recall_cta]:
		if c != null and c.visible:
			shown += 1
			if c.offset_bottom >= bottom:
				bottom = c.offset_bottom
				above = c
	season_guests.offset_top = bottom + MENU_GAP
	var limit: int = 1 if shown >= 2 else GUESTS_MAX
	if limit != _season_limit:
		_season_limit = limit
		season_refresh_guests()
	_season_wire(above)


## Focus with guests (after the menu, the TALENT-SHOW and the RECALL wired theirs): ui_down from the lowest of those
## buttons — without one ui_right from the right end of every menu row — reaches the first guest; up / down between the
## guests, the first one up to that button; ui_left to the first menu row (as from RECALL); Tab after that button (or
## the last menu entry), then back to the first menu entry.
func _season_wire(above: Control) -> void:
	var list: Array[Control] = []
	if season_guests == null or not season_guests.visible:
		return
	for c: Node in _season_guest_list.get_children():
		if c is Button:
			list.append(c as Control)
	var order: Array[Button] = _menu_buttons_in_order()
	if list.is_empty() or order.is_empty():
		return
	var home: Control = menu_buttons.get(str((MENU_ROWS[0] as Array).back()), order[0]) as Control
	if above != null:
		above.focus_neighbor_bottom = above.get_path_to(list[0])
	else:
		for ids: Array in MENU_ROWS:
			var e: Control = menu_buttons.get(str(ids.back())) as Control
			if e != null:
				e.focus_neighbor_right = e.get_path_to(list[0])
	for i in list.size():
		var b: Control = list[i]
		b.focus_neighbor_left = b.get_path_to(home)
		b.focus_neighbor_right = b.get_path_to(b)
		b.focus_neighbor_top = b.get_path_to(list[i - 1] if i > 0 else (above if above != null else b))
		b.focus_neighbor_bottom = b.get_path_to(list[i + 1] if i < list.size() - 1 else b)
	var prev: Control = above if above != null else order[order.size() - 1]
	var chain: Array[Control] = [prev]
	chain.append_array(list)
	chain.append(order[0])
	for k in range(1, chain.size()):
		chain[k - 1].focus_next = chain[k - 1].get_path_to(chain[k])
		chain[k].focus_previous = chain[k].get_path_to(chain[k - 1])


## The Recall opened (open_recall): who chooses for the first time now (Casting.mode "first"). When it closes and one of
## them holds a class, the first class choice just happened — the tempo offer follows (09 §0.6, §2.1).
func _season_watch_recall(recall: Node) -> void:
	var st: GameState = Game.state
	if st == null or st.season == null:
		return
	var first: PackedStringArray = []
	for mid: String in Casting.open_members(st, DB.data):
		if Casting.mode(st, DB.data, mid) == "first":
			first.append(mid)
	if first.is_empty():
		return
	recall.connect("closed", func() -> void:
		for mid: String in first:
			var m: PartyMember = Game.state.member(mid) if Game.state != null else null
			if m != null and m.class_id != "":
				_season_offer.call_deferred()  # after the Recall's own close (_recall_closed: the menu is back)
				return)


## The tempo offer once on this device (career "seen") in a private calendar season (SeasonRules: only calendar →
## Am Stück, only private) — never over another modal or while leaving.
func _season_offer() -> void:
	var st: GameState = Game.state
	if not is_inside_tree() or st == null or st.season == null or st.season.result != "" or _season_offering:
		return
	if _leaving or _busy or (_modal != null and is_instance_valid(_modal)):
		return
	var c: Dictionary = {"t": "season", "v": Command.SEASON_VERSION, "op": "tempo"}
	if Save.career_seen("season_tempo_offer") or SeasonRules.refusal(st, DB.data, c) != "":
		return
	season_open_tempo_offer()


## The tempo offer (09 §2.1, V-6): "Weiter im Kalender" or "Am Stück" — once on this device.
func season_open_tempo_offer() -> Node:
	if not ResourceLoader.exists(SEASON_DIALOG):
		return null
	_season_offering = true
	var fr: FloorRun = Game.state.floor_run
	var mins: int = SeasonClock.binge_ticks(fr.index, Game.state.difficulty == &"vorabend") / SeasonClock.TICKS_PER_MIN
	var d: Node = (load(SEASON_DIALOG) as PackedScene).instantiate()
	d.call("setup", {"title": "Weiter wie im Fernsehen?", "kicker": "TEMPO · STAFFEL %d" % Game.state.season.number,
		"lines": ["M.O.D.: „%s“" % UiUtil.mod_line("season_tempo_offer"), str(SeasonView.EXPLAIN["calendar"]),
		str(SeasonView.EXPLAIN["binge"]) + " Etage %d bekommt dann %d:00." % [fr.index, mins],
		"Umschalten geht nur in diese Richtung — später auch im Pausemenü unter „Staffel“."],
		"buttons": [{"id": "calendar", "text": "Weiter im Kalender"}, {"id": "binge", "text": "Am Stück"}],
		"focus": "calendar", "cancel_id": "calendar"})
	_modal = d
	add_child(d)
	Save.career_mark("season_tempo_offer")
	d.connect("closed", func(id: String, _days: int) -> void:
		_season_offering = false
		if id == "binge" and Game.season_tempo_binge():
			Show.say("season_tempo_binge")
		_after_modal("recall" if recall_available() else ""))   # the focus where the Recall left it
	return d
