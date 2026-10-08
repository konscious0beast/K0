extends CanvasLayer
## Battle HUD (02_TECH §1.6, §5.7, §9.4 layer 5; GDD §14.5; 03_ART §9.2): party panels (bottom right), CTB bar with
## 12-entry preview (TOUCH 10) and ghost preview of the highlighted action (right edge), command menu (bottom left),
## action sub menus, target cursor, enemy plates, banners, speed (×1/×2) and auto buttons (top right).
## request_command(state, actor) is the controller's coroutine for player input (keyboard / gamepad focus, touch).
## During playback the BattlePlayer feeds every ActionEvent to on_event() (HUD values = event hp_after / mp_after);
## after each playback the controller calls sync_from_state(). Portraits are ViewportTextures of living SubViewports
## (03_ART §9.2 F9), cached per ModelSpec, owned by this node (max 6). Private M5 script (no class_name).

signal command_done(cmd: BattleCommand)

const HudStyle := preload("res://scenes/battle/ui/hud_style.gd")
const PartyPanel := preload("res://scenes/battle/ui/party_panel.gd")
const CtbBar := preload("res://scenes/battle/ui/ctb_bar.gd")
const CommandMenu := preload("res://scenes/battle/ui/command_menu.gd")
const ActionList := preload("res://scenes/battle/ui/action_list.gd")
const TargetCursor := preload("res://scenes/battle/ui/target_cursor.gd")
const EnemyPlates := preload("res://scenes/battle/ui/enemy_plates.gd")
const Banner := preload("res://scenes/battle/ui/battle_banner.gd")
const PORTRAIT_PX: int = 128
const MAX_PORTRAITS: int = 6
const PANEL_GAP: float = 6.0
const CTB_W: float = 56.0
const SIDE_GAP: float = 16.0
## Bottom clearance in the safe frame: chat ticker of the show overlay (22 px + gap, layer 40).
const BOTTOM: float = 30.0
const LIST_BOTTOM: float = 146.0      # sub menus end above the M.O.D. text box (bottom center, layer 45)
const COLORS: Dictionary = {"kai": "#3aa9a0", "mopsula": "#b07cff"}

var stage: Node3D = null
var camera: Camera3D = null
var setup: BattleSetup = null
var awaiting: bool = false
var level: StringName = &""           # &"menu" | &"list" | &"target" while awaiting

var safe: SafeAreaContainer = null
var frame: Control = null
var panels: Dictionary = {}           # party id → PartyPanel
var party_box: VBoxContainer = null
var ctb: Control = null
var command_menu: PanelContainer = null
var action_list: PanelContainer = null
var target_cursor: Control = null
var plates: Control = null
var banner: Control = null
var speed_button: Button = null
var auto_button: Button = null

var _state: BattleState = null
var _actor: Combatant = null
var _kind: int = -1
var _list_kind: int = -1
var _skill_id: String = ""
var _item_id: String = ""
var _rank: int = CTBQueue.RANK_NORMAL
var _portraits: Dictionary = {}       # ModelSpec key → SubViewport
var _unit_tex: Dictionary = {}        # combatant id → Texture2D
var _weak_seen: Dictionary = {}       # enemy def id → PackedStringArray (this battle)
var _stunt_turn: Dictionary = {}      # party id → true while the actor's stunt turn runs (no cooldown tick)
var _speed_label: Label = null
var _auto_label: Label = null
var _speed_key: Label = null
var _auto_key: Label = null
var _intro: bool = false


func _init() -> void:
	layer = 5


func _ready() -> void:
	safe = SafeAreaContainer.new()
	safe.name = "Safe"
	add_child(safe)
	frame = Control.new()
	frame.name = "Frame"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(frame)
	plates = EnemyPlates.new()
	plates.name = "EnemyPlates"
	add_child(plates)
	move_child(plates, 0)
	banner = Banner.new()
	banner.name = "Banner"
	add_child(banner)
	target_cursor = TargetCursor.new()
	target_cursor.name = "TargetCursor"
	target_cursor.provider = self
	add_child(target_cursor)
	_build_frame()
	Events.input_scheme_changed.connect(_on_scheme_changed)


## Wires the stage/camera and builds the party panels, enemy plates and portraits (HUD must be in the tree).
func setup_hud(p_stage: Node3D, p_camera: Camera3D, p_setup: BattleSetup) -> void:
	stage = p_stage
	camera = p_camera
	setup = p_setup
	plates.stage = stage
	plates.camera = camera
	target_cursor.stage = stage
	target_cursor.camera = camera
	for c: Combatant in setup.party:
		if c == null:
			continue
		var p: PanelContainer = PartyPanel.new()
		var col: Color = Color(str(COLORS.get(c.def_id, "#22d3ee")))
		party_box.add_child(p)
		p.call("setup", c.id, c.display_name, c.hp, c.max_hp(), c.mp, c.max_mp(), portrait(c.id), col,
			not c.stunts.is_empty())
		for st: StatusEffect in c.statuses:
			p.call("set_status", st.id(), true)
			stage.call("set_status_visual", c.id, st.id(), true)
		panels[c.id] = p
	for id: String in stage.call("unit_ids"):
		if id.begins_with("e"):
			_add_enemy_plate(id)
	_layout()


# --- layout ----------------------------------------------------------------------------------------------------------

func _build_frame() -> void:
	party_box = VBoxContainer.new()
	party_box.name = "PartyPanels"
	party_box.add_theme_constant_override("separation", int(PANEL_GAP))
	party_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	party_box.alignment = BoxContainer.ALIGNMENT_END
	frame.add_child(party_box)
	ctb = CtbBar.new()
	ctb.name = "CtbBar"
	ctb.provider = self
	frame.add_child(ctb)
	command_menu = CommandMenu.new()
	command_menu.name = "CommandMenu"
	frame.add_child(command_menu)
	command_menu.chosen.connect(_on_command_chosen)
	command_menu.highlighted.connect(_on_command_highlighted)
	action_list = ActionList.new()
	action_list.name = "ActionList"
	frame.add_child(action_list)
	action_list.chosen.connect(_on_list_chosen)
	action_list.highlighted.connect(_on_list_highlighted)
	# the target panel lives in the safe frame; arrows are drawn by the full-screen cursor
	var tp: Control = target_cursor.get("panel")
	target_cursor.remove_child(tp)
	frame.add_child(tp)
	target_cursor.confirmed.connect(_on_targets_confirmed)
	target_cursor.cancelled.connect(_on_targets_cancelled)
	target_cursor.changed.connect(_on_target_changed)
	var top: HBoxContainer = HBoxContainer.new()
	top.name = "TopButtons"
	top.add_theme_constant_override("separation", 12)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(top)
	auto_button = _top_button("Auto", "AUTO", "T")
	top.add_child(auto_button)
	auto_button.pressed.connect(toggle_auto)
	speed_button = _top_button("Speed", "×1", "R")
	top.add_child(speed_button)
	speed_button.pressed.connect(toggle_speed)
	_auto_label = auto_button.get_node("Caption") as Label
	_auto_key = auto_button.get_node("Key") as Label
	_speed_label = speed_button.get_node("Caption") as Label
	_speed_key = speed_button.get_node("Key") as Label
	_refresh_toggles()


func _top_button(node_name: String, caption: String, key: String) -> Button:
	var b: Button = Button.new()
	b.name = node_name
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(64, 64)
	var cap: Label = HudStyle.label(caption, 20, HudStyle.C_PAPER, true, 3)
	cap.name = "Caption"
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cap.offset_bottom = -8
	b.add_child(cap)
	var k: Label = HudStyle.label(key, 12, Color("#b3a7c9"), true, 2)
	k.name = "Key"
	k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	k.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	k.offset_left = -20
	k.offset_right = 20
	k.offset_top = -38
	k.offset_bottom = -22
	b.add_child(k)
	UiTheme.ensure_hit_area(b)
	return b


func _layout() -> void:
	var touch: bool = is_touch()
	ctb.set("count", CTBQueue.PREVIEW_LENGTH_TOUCH if touch else CTBQueue.PREVIEW_LENGTH)
	ctb.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	ctb.offset_left = -CTB_W
	ctb.offset_right = 0
	ctb.offset_top = 0
	ctb.offset_bottom = 500
	var top: Control = frame.get_node("TopButtons") as Control
	top.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	var tw: float = top.get_combined_minimum_size().x
	top.offset_right = -CTB_W - SIDE_GAP
	top.offset_left = top.offset_right - tw
	top.offset_top = -12
	top.offset_bottom = top.offset_top + top.get_combined_minimum_size().y
	party_box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	var pw: float = PartyPanel.SIZE.x
	var ph: float = PartyPanel.SIZE.y * float(maxi(1, panels.size())) + PANEL_GAP * float(maxi(0, panels.size() - 1))
	party_box.offset_right = 0
	party_box.offset_left = -pw
	party_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	party_box.offset_bottom = -BOTTOM
	party_box.offset_top = party_box.offset_bottom - ph
	command_menu.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	command_menu.offset_left = 0
	command_menu.offset_bottom = -BOTTOM
	command_menu.grow_vertical = Control.GROW_DIRECTION_BEGIN
	command_menu.offset_top = command_menu.offset_bottom
	command_menu.offset_right = 0
	var menu_w: float = maxf(240.0, command_menu.get_combined_minimum_size().x)
	action_list.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	action_list.grow_vertical = Control.GROW_DIRECTION_BEGIN
	action_list.offset_left = menu_w + 12.0
	action_list.offset_right = action_list.offset_left + ActionList.WIDTH
	action_list.offset_bottom = -LIST_BOTTOM
	action_list.offset_top = action_list.offset_bottom
	var tp: Control = target_cursor.get("panel")
	tp.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	tp.grow_vertical = Control.GROW_DIRECTION_BEGIN
	tp.offset_left = 0
	tp.offset_bottom = -BOTTOM
	tp.offset_right = 340
	tp.offset_top = tp.offset_bottom


func is_touch() -> bool:
	return Game.input_scheme == Game.InputScheme.TOUCH


func _on_scheme_changed(_scheme: int) -> void:
	if not is_inside_tree():
		return
	_layout()
	if awaiting and level == &"menu" and _actor != null:
		_open_menu(command_menu.call("focused_kind"))


## Hides party panels / CTB during the battle intro, slides them in afterwards.
func set_intro(on: bool) -> void:
	_intro = on
	var targets: Array[Control] = [party_box, ctb, frame.get_node("TopButtons") as Control]
	for c: Control in targets:
		if on:
			c.modulate.a = 0.0
		elif is_inside_tree():
			var tw: Tween = c.create_tween()
			tw.tween_property(c, "modulate:a", 1.0, 0.25)
		else:
			c.modulate.a = 1.0


# --- portraits / providers --------------------------------------------------------------------------------------------

## ViewportTexture of a living SubViewport showing the unit's head (cached per ModelSpec, max 6).
func portrait(id: String) -> Texture2D:
	if _unit_tex.has(id):
		return _unit_tex[id]
	if stage == null:
		return null
	var info: Dictionary = stage.call("info", id)
	var model: Dictionary = info.get("model", {})
	if model.is_empty():
		return null
	var key: String = var_to_str(model)
	var vp: SubViewport = _portraits.get(key, null)
	if vp == null:
		if _portraits.size() >= MAX_PORTRAITS or not is_inside_tree():
			return null
		vp = _make_portrait(model)
		_portraits[key] = vp
	var tex: Texture2D = vp.get_texture()
	_unit_tex[id] = tex
	return tex


func _make_portrait(model: Dictionary) -> SubViewport:
	var vp: SubViewport = SubViewport.new()
	vp.name = "Portrait%d" % _portraits.size()
	vp.size = Vector2i(PORTRAIT_PX, PORTRAIT_PX)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(vp)
	var env: WorldEnvironment = WorldEnvironment.new()
	var e: Environment = Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#a89cd0")
	e.ambient_light_energy = 0.75
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.environment = e
	vp.add_child(env)
	var rig: CharacterRig = CharacterBuilder.build(model, 0)
	rig.spawn_effects = false
	vp.add_child(rig)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-30, 210, 0)
	light.light_energy = 1.2
	light.light_specular = 0.0
	vp.add_child(light)
	var cam: Camera3D = Camera3D.new()
	cam.fov = 30.0
	cam.near = 0.02
	vp.add_child(cam)
	var head_node: Node3D = rig.anchor(&"head")
	var head: Vector3 = head_node.global_position if head_node != rig else Vector3(0, rig.height * 0.82, 0)
	var hs: float = clampf(rig.height * 0.38, 0.2, 1.3)
	var d: float = 2.2 * hs
	if str(model.get("base", "")) == "swarm":
		# five birds on an orbit: frame the whole flock instead of one head
		head = Vector3(0, rig.height * 0.5, 0)
		d = 2.5 * maxf(rig.height, 0.6)
	var eye: Vector3 = head + Vector3(0.22 * hs, 0.08 * hs, -d)
	cam.global_transform = Transform3D(Basis.looking_at(head - eye, Vector3.UP), eye)
	cam.current = true
	return vp


func ctb_portrait(id: String) -> Texture2D:
	return portrait(id)


func ctb_kind(id: String) -> String:
	if id.begins_with("u"):
		return "pseudo"
	return "party" if id.begins_with("p") else "enemy"


func ctb_letter(id: String) -> String:
	return str(stage.call("letter", id)) if stage != null else ""


## Target panel data: name, hp (BattleState while choosing, else the HUD value), bestiary-gated HP number, weaknesses.
func target_info(id: String) -> Dictionary:
	var out: Dictionary = {"name": str(stage.call("display_name", id)) if stage != null else id}
	var info: Dictionary = stage.call("info", id) if stage != null else {}
	var hp: int = 0
	var mx: int = int(info.get("max_hp", 1))
	var c: Combatant = _state.get_combatant(id) if _state != null else null
	if c != null:
		hp = c.hp
		mx = c.max_hp()
	elif panels.has(id):
		hp = int((panels[id] as Control).get("hp"))
	else:
		hp = int(plates.call("plate_hp", id))
	out["hp"] = maxi(0, hp)
	out["max_hp"] = maxi(1, mx)
	out["show_hp"] = id.begins_with("p") or _bestiary_known(str(info.get("def_id", "")))
	out["weak"] = _known_weak(str(info.get("def_id", ""))) if not id.begins_with("p") else PackedStringArray()
	return out


func _bestiary_known(def_id: String) -> bool:
	if Game.state == null:
		return false
	var b: Variant = Game.state.bestiary.get(def_id, null)
	return b is Dictionary and int((b as Dictionary).get("defeated", 0)) >= 1


func _known_weak(def_id: String) -> PackedStringArray:
	var out: PackedStringArray = []
	if Game.state != null:
		var b: Variant = Game.state.bestiary.get(def_id, null)
		if b is Dictionary:
			for el: String in JsonUtil.to_str_array((b as Dictionary).get("weak_known", [])):
				if not out.has(el):
					out.append(el)
	for el2: String in (_weak_seen.get(def_id, PackedStringArray()) as PackedStringArray):
		if not out.has(el2):
			out.append(el2)
	return out


func _add_enemy_plate(id: String) -> void:
	var info: Dictionary = stage.call("info", id)
	var def_id: String = str(info.get("def_id", ""))
	plates.call("add_plate", id, str(stage.call("display_name", id)), int(info.get("max_hp", 1)),
		int(info.get("max_hp", 1)), _bestiary_known(def_id), _known_weak(def_id))


# --- event feed (playback) -------------------------------------------------------------------------------------------

## Applies the HUD-relevant data of one ActionEvent at the moment the BattlePlayer presents it.
func on_event(e: ActionEvent) -> void:
	match e.type:
		ActionEvent.Type.CTB_ORDER:
			if not awaiting:
				ctb.call("set_order", e.order, PackedStringArray(), not _intro)
		ActionEvent.Type.TURN_START:
			_set_active(e.actor_id)
		ActionEvent.Type.DAMAGE, ActionEvent.Type.HEAL, ActionEvent.Type.REVIVE:
			_apply_hp(e.target_id, e.hp_after)
			if e.type == ActionEvent.Type.DAMAGE and e.weak and e.element != "" and e.target_id.begins_with("e"):
				var def_id: String = str((stage.call("info", e.target_id) as Dictionary).get("def_id", ""))
				var list: PackedStringArray = _weak_seen.get(def_id, PackedStringArray())
				if not list.has(e.element):
					list.append(e.element)
				_weak_seen[def_id] = list
				for id: String in stage.call("unit_ids"):
					if str((stage.call("info", id) as Dictionary).get("def_id", "")) == def_id:
						plates.call("add_weakness", id, e.element)
		ActionEvent.Type.MP_CHANGE:
			if panels.has(e.target_id):
				(panels[e.target_id] as Control).call("set_mp", e.mp_after)
		ActionEvent.Type.STATUS_ADDED:
			_apply_status(e.target_id, e.status_id, true)
		ActionEvent.Type.STATUS_REMOVED:
			_apply_status(e.target_id, e.status_id, false)
		ActionEvent.Type.KO:
			if panels.has(e.target_id):
				(panels[e.target_id] as Control).call("set_hp", 0)
			else:
				plates.call("set_hp", e.target_id, 0)
				plates.call("remove_plate", e.target_id)
		ActionEvent.Type.SUMMON:
			if e.target_id.begins_with("e"):
				_add_enemy_plate(e.target_id)
		ActionEvent.Type.ESCAPED:
			plates.call("remove_plate", e.actor_id)
		ActionEvent.Type.STUNT_RESULT:
			if panels.has(e.actor_id) and DB.has_id("skills", e.skill_id):
				_stunt_turn[e.actor_id] = true
				(panels[e.actor_id] as Control).call("set_stunt", DB.skill(e.skill_id).cooldown)
		ActionEvent.Type.TURN_END:
			if panels.has(e.actor_id):
				var p: Control = panels[e.actor_id]
				if not bool(_stunt_turn.get(e.actor_id, false)):
					p.call("set_stunt", maxi(0, int(p.get("stunt_cooldown")) - 1))
				_stunt_turn.erase(e.actor_id)
		ActionEvent.Type.BATTLE_END:
			_set_active("")
			_fade_battle_widgets()


## End of battle: CTB bar, AUTO / speed buttons and enemy plates fade out (the results panel takes over).
func _fade_battle_widgets() -> void:
	var targets: Array[Control] = [ctb, frame.get_node("TopButtons") as Control, plates]
	for c: Control in targets:
		if c == null:
			continue
		if is_inside_tree():
			var tw: Tween = c.create_tween()
			tw.tween_property(c, "modulate:a", 0.0, 0.3)
		else:
			c.modulate.a = 0.0


func _apply_hp(id: String, hp_after: int) -> void:
	if hp_after < 0:
		return
	if panels.has(id):
		(panels[id] as Control).call("set_hp", hp_after)
	else:
		plates.call("set_hp", id, hp_after)


func _apply_status(id: String, status_id: String, on: bool) -> void:
	if panels.has(id):
		(panels[id] as Control).call("set_status", status_id, on)
	else:
		plates.call("set_status", id, status_id, on)


func _set_active(id: String) -> void:
	for k: Variant in panels.keys():
		(panels[k] as Control).call("set_active", str(k) == id)


## HP / MP / statuses / stunt cooldowns from the BattleState after a playback (02_TECH §5.3).
func sync_from_state(state: BattleState) -> void:
	if state == null:
		return
	for c: Combatant in state.combatants:
		if c.is_pseudo:
			continue
		var ids: PackedStringArray = []
		for st: StatusEffect in c.statuses:
			ids.append(st.id())
		if panels.has(c.id):
			var p: Control = panels[c.id]
			p.call("set_hp", maxi(0, c.hp))
			p.call("set_mp", maxi(0, c.mp))
			p.call("set_stunt", c.stunt_cooldown)
			for old: String in (p.get("statuses") as PackedStringArray).duplicate():
				if not ids.has(old):
					p.call("set_status", old, false)
			for sid: String in ids:
				p.call("set_status", sid, true)
		elif c.id.begins_with("e") and bool(plates.call("has_plate", c.id)):
			if c.is_alive():
				plates.call("set_hp", c.id, c.hp, false)
				for sid2: String in ids:
					plates.call("set_status", c.id, sid2, true)
		if stage != null and c.is_alive():
			for sid3: String in ids:
				stage.call("set_status_visual", c.id, sid3, true)


func panel_hp(id: String) -> int:
	return int((panels[id] as Control).get("hp")) if panels.has(id) else -1


func panel_mp(id: String) -> int:
	return int((panels[id] as Control).get("mp")) if panels.has(id) else -1


func plate_hp(id: String) -> int:
	return int(plates.call("plate_hp", id))


# --- speed / auto ----------------------------------------------------------------------------------------------------

func toggle_auto() -> void:
	Game.auto_battle = not Game.auto_battle
	Sfx.play_ui(&"ui_confirm")
	_refresh_toggles()
	if Game.auto_battle and awaiting:
		_finish(null)


func toggle_speed() -> void:
	if Game.settings != null:
		Game.settings.battle_speed = 1.0 if Game.settings.battle_speed >= 1.5 else 2.0
		Game.settings.save_to_disk()
	Sfx.play_ui(&"ui_confirm")
	_refresh_toggles()


func _refresh_toggles() -> void:
	if _auto_label == null:
		return
	var fast: bool = Game.settings != null and Game.settings.battle_speed >= 1.5
	_speed_label.text = "×2" if fast else "×1"
	_speed_label.add_theme_color_override("font_color", Color("#ffc93c") if fast else HudStyle.C_PAPER)
	_auto_label.add_theme_color_override("font_color", Color("#4ade80") if Game.auto_battle else HudStyle.C_PAPER)
	var keys: bool = Game.input_scheme == Game.InputScheme.KEYBOARD_MOUSE
	var pad: bool = Game.input_scheme == Game.InputScheme.GAMEPAD
	_auto_key.text = "T" if keys else ("Y" if pad else "")
	_speed_key.text = "R" if keys else ("R3" if pad else "")
	auto_button.modulate = Color(1, 1, 1, 1) if Game.auto_battle else Color(1, 1, 1, 0.85)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed(&"toggle_auto"):
		toggle_auto()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"toggle_speed"):
		toggle_speed()
		get_viewport().set_input_as_handled()
	elif awaiting and event.is_action_pressed(&"ui_cancel") and level == &"list":
		Sfx.play_ui(&"ui_cancel")
		get_viewport().set_input_as_handled()
		_open_menu(_list_kind)


# --- command input (02_TECH §5.7: hud.request_command) ----------------------------------------------------------------

## Coroutine: menus → (sub menu) → target → BattleCommand; null when auto battle was switched on meanwhile.
func request_command(state: BattleState, actor: Combatant) -> BattleCommand:
	_state = state
	_actor = actor
	awaiting = true
	_rank = CTBQueue.RANK_NORMAL
	if camera != null:
		camera.call("shot", &"command", {"actor": actor.id})
	plates.set("shown", true)
	_open_menu(-1)
	var cmd: BattleCommand = await command_done
	return cmd


func _finish(cmd: BattleCommand) -> void:
	if not awaiting:
		return
	awaiting = false
	level = &""
	command_menu.call("close")
	action_list.call("close")
	target_cursor.call("end")
	plates.set("shown", false)
	_state = null
	_actor = null
	command_done.emit(cmd)


func _open_menu(focus_kind: int) -> void:
	level = &"menu"
	action_list.call("close")
	target_cursor.call("end")
	var available: Array[int] = _state.available_commands(_actor)
	var col: Color = Color(str(COLORS.get(_actor.def_id, "#22d3ee")))
	command_menu.call("open", str(stage.call("display_name", _actor.id)), col, available, _actor.stunt_cooldown,
		not _actor.stunts.is_empty(), is_touch())
	_layout()
	if focus_kind >= 0:
		command_menu.call("focus_kind", focus_kind)
	_preview(_rank_of_kind(focus_kind if focus_kind >= 0 else BattleCommand.Kind.ATTACK))
	if camera != null and _actor != null:
		camera.call("shot", &"command", {"actor": _actor.id})


func _rank_of_kind(kind: int) -> int:
	match kind:
		BattleCommand.Kind.ATTACK:
			return CTBQueue.RANK_NORMAL
		BattleCommand.Kind.STUNT:
			if _actor != null and not _actor.stunts.is_empty():
				var sk: SkillDef = _state.skill_def(_actor.stunts[0])
				return sk.rank if sk != null else 4
			return 4
		BattleCommand.Kind.SKILL:
			return CTBQueue.RANK_NORMAL
	return CTBQueue.RANK_QUICK


func _on_command_highlighted(kind: int) -> void:
	if awaiting and level == &"menu":
		_preview(_rank_of_kind(kind))


func _on_command_chosen(kind: int) -> void:
	if not awaiting or level != &"menu":
		return
	_kind = kind
	match kind:
		BattleCommand.Kind.ATTACK:
			_skill_id = _actor.attack_skill
			_item_id = ""
			_begin_targets(_actor.attack_skill, tr("Angriff"))
		BattleCommand.Kind.SKILL, BattleCommand.Kind.STUNT, BattleCommand.Kind.ITEM:
			_open_list(kind)
		BattleCommand.Kind.DEFEND:
			_submit(BattleCommand.defend(_actor.id))
		BattleCommand.Kind.FLEE:
			_submit(BattleCommand.flee(_actor.id))


func _open_list(kind: int, focus_id: String = "") -> void:
	level = &"list"
	_list_kind = kind
	var entries: Array[Dictionary] = []
	var title: String = ""
	match kind:
		BattleCommand.Kind.SKILL:
			title = tr("Fähigkeiten")
			entries = _skill_entries()
		BattleCommand.Kind.STUNT:
			title = tr("Stunts")
			entries = _stunt_entries()
		BattleCommand.Kind.ITEM:
			title = tr("Items")
			entries = _item_entries()
	command_menu.call("close")
	action_list.call("open", title, entries, is_touch(), focus_id)
	command_menu.visible = true          # stays visible (dimmed) left of the sub menu
	command_menu.modulate = Color(1, 1, 1, 0.55)
	_layout()


func _skill_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var usable: PackedStringArray = _state.usable_skills(_actor)
	for sid: String in _actor.skills:
		var sk: SkillDef = _state.skill_def(sid)
		if sk == null or sk.is_stunt():
			continue
		var ok: bool = usable.has(sid) and not _state.valid_targets(_actor, sid).is_empty()
		out.append({"id": sid, "label": tr(sk.name), "enabled": ok, "cost": ("%d MP" % sk.mp_cost) if sk.mp_cost > 0
			else "", "element": _icon_element(sk), "icon": _icon_kind(sk), "icon_color": _icon_color(sk),
			"rank": sk.rank, "desc": tr(sk.desc)})
	return out


func _stunt_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ready: bool = _state.available_commands(_actor).has(BattleCommand.Kind.STUNT)
	for sid: String in _actor.stunts:
		var sk: SkillDef = _state.skill_def(sid)
		if sk == null:
			continue
		var pct: int = roundi(_state.stunt_chance(_actor, sk) * 100.0)
		var desc: String = tr(sk.desc) if sk.desc != "" else ""
		desc = (desc + " " if desc != "" else "") + tr("Erfolgschance: %d %%") % pct
		out.append({"id": sid, "label": tr(sk.name), "enabled": ready, "cost": "%d %%" % pct,
			"element": _icon_element(sk), "icon": "star", "icon_color": Color("#ffc93c"), "rank": sk.rank, "desc": desc})
	return out


func _item_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for iid: String in _state.usable_items():
		var it: ItemDef = _state.item_def(iid)
		var sk: SkillDef = _state.skill_def(it.use_skill) if it != null else null
		if it == null or sk == null:
			continue
		var ok: bool = sk.flee_guaranteed or sk.target == "self" or not _state.valid_targets(_actor, sk.id).is_empty()
		var n: int = JsonUtil.to_int(_state.items.get(iid, 0))
		out.append({"id": iid, "label": tr(it.name), "enabled": ok, "cost": "×%d" % n, "element": _icon_element(sk),
			"icon": _icon_kind(sk), "icon_color": _icon_color(sk), "rank": sk.rank, "desc": tr(it.desc)})
	return out


static func _icon_element(sk: SkillDef) -> String:
	return sk.element if sk.element != "" else "none"


static func _icon_kind(sk: SkillDef) -> String:
	if sk.damage_type == "heal" or sk.category == "heal":
		return "heal"
	if sk.category == "buff":
		return "sparkle"
	if sk.category == "item" and sk.damage_type == "none":
		return "box"
	return "element_" + _icon_element(sk)


static func _icon_color(sk: SkillDef) -> Color:
	if sk.damage_type == "heal" or sk.category == "heal":
		return Color("#6bffb0")
	if sk.category == "buff":
		return Color("#ffc93c")
	if sk.category == "item" and sk.damage_type == "none":
		return Color("#4ade80")
	return HudStyle.element_color(_icon_element(sk))


func _on_list_highlighted(id: String) -> void:
	if not awaiting or level != &"list":
		return
	var sk: SkillDef = _list_skill(id)
	_preview(sk.rank if sk != null else CTBQueue.RANK_NORMAL)


func _list_skill(id: String) -> SkillDef:
	if _list_kind == BattleCommand.Kind.ITEM:
		var it: ItemDef = _state.item_def(id)
		return _state.skill_def(it.use_skill) if it != null else null
	return _state.skill_def(id)


func _on_list_chosen(id: String) -> void:
	if not awaiting or level != &"list":
		return
	_kind = _list_kind
	var sk: SkillDef = _list_skill(id)
	if sk == null:
		return
	_item_id = id if _kind == BattleCommand.Kind.ITEM else ""
	_skill_id = sk.id
	if _kind == BattleCommand.Kind.ITEM and sk.flee_guaranteed:
		_submit(BattleCommand.item(_actor.id, _item_id, PackedStringArray()))
		return
	_begin_targets(sk.id, tr(sk.name) if _kind != BattleCommand.Kind.ITEM else tr(_state.item_def(id).name))


func _begin_targets(skill_id: String, title: String) -> void:
	var sk: SkillDef = _state.skill_def(skill_id)
	if sk == null:
		return
	var cands: PackedStringArray = _state.valid_targets(_actor, skill_id)
	var mode: String = "single"
	match sk.target:
		"all_enemies", "all_allies":
			mode = "all"
		"random_enemy":
			mode = "random"
		"self":
			mode = "self"
		"none":
			_submit(_make_command(PackedStringArray()))
			return
	if cands.is_empty():
		Sfx.play_ui(&"ui_error")
		return
	level = &"target"
	_rank = sk.rank if _kind != BattleCommand.Kind.ATTACK else CTBQueue.RANK_NORMAL
	action_list.call("close")
	command_menu.call("close")
	var def_id: String = _state.default_target(_actor, skill_id)
	target_cursor.call("begin", cands, mode, def_id, title)
	_layout()


func _on_target_changed(id: String) -> void:
	if not awaiting or level != &"target":
		return
	if camera != null and id != "":
		var mode: String = str(target_cursor.get("mode"))
		if mode == "single" or mode == "self":
			camera.call("shot", &"target_select", {"actor": _actor.id, "target": id})
		else:
			camera.call("shot", &"command", {"actor": _actor.id})
	_preview(_rank, target_cursor.call("selected_ids") as PackedStringArray)


func _on_targets_confirmed(ids: PackedStringArray) -> void:
	if not awaiting or level != &"target":
		return
	var cmd: BattleCommand = _make_command(ids)
	if not _submit(cmd):
		_begin_targets(_skill_id, tr("Ziel"))


func _on_targets_cancelled() -> void:
	if not awaiting:
		return
	if _kind == BattleCommand.Kind.ATTACK:
		_open_menu(BattleCommand.Kind.ATTACK)
	else:
		_open_list(_kind, _item_id if _kind == BattleCommand.Kind.ITEM else _skill_id)


func _make_command(ids: PackedStringArray) -> BattleCommand:
	var t: PackedStringArray = ids
	var sk: SkillDef = _state.skill_def(_skill_id)
	if sk != null and sk.target == "self":
		t = PackedStringArray([_actor.id])
	match _kind:
		BattleCommand.Kind.ATTACK:
			return BattleCommand.attack(_actor.id, t[0] if not t.is_empty() else "")
		BattleCommand.Kind.SKILL:
			return BattleCommand.skill(_actor.id, _skill_id, t)
		BattleCommand.Kind.STUNT:
			return BattleCommand.stunt(_actor.id, _skill_id, t)
		BattleCommand.Kind.ITEM:
			return BattleCommand.item(_actor.id, _item_id, t)
	return BattleCommand.defend(_actor.id)


## Validates and hands the command to the controller; false (error sound) when the core would reject it.
func _submit(cmd: BattleCommand) -> bool:
	if _state == null or cmd == null:
		return false
	var reason: String = _state.validate(cmd)
	if reason != "":
		push_warning("[BattleHud] command rejected: %s" % reason)
		Sfx.play_ui(&"ui_error")
		return false
	command_menu.modulate = Color.WHITE
	_finish(cmd)
	return true


# --- CTB preview ------------------------------------------------------------------------------------------------------

## Preview with the pending rank of the highlighted action (GDD §3.4); with targets of a stun / slow / haste action
## the moved targets are shown as ghosts (50 %).
func _preview(rank: int, targets: PackedStringArray = PackedStringArray()) -> void:
	if _state == null:
		return
	var count: int = int(ctb.get("count"))
	var base: PackedStringArray = _state.preview_order(count, rank)
	if targets.is_empty() or _skill_id == "":
		ctb.call("set_order", base, PackedStringArray())
		return
	var ghost: PackedStringArray = ghost_order(_state, _actor, _skill_id, targets, rank, count)
	var moved: PackedStringArray = []
	for id: String in targets:
		if base.find(id) != ghost.find(id) or base.count(id) != ghost.count(id):
			moved.append(id)
	ctb.call("set_order", ghost if not moved.is_empty() else base, moved)


## Hypothetical order if `skill_id` lands on `targets`: stun via BattleState.ghost_overrides, haste/slow on a
## snapshot copy (the real BattleState is never mutated).
static func ghost_order(state: BattleState, actor: Combatant, skill_id: String, targets: PackedStringArray,
		rank: int, count: int) -> PackedStringArray:
	var sk: SkillDef = state.skill_def(skill_id)
	if sk == null:
		return state.preview_order(count, rank)
	var overrides: Dictionary = state.ghost_overrides(actor, skill_id, targets)
	var speed_defs: Array[StatusDef] = []
	for s: Dictionary in sk.statuses:
		var def: StatusDef = state.status_def(str(s.get("id", "")))
		if def != null and not is_equal_approx(def.tick_speed_mult, 1.0):
			speed_defs.append(def)
	if speed_defs.is_empty():
		return state.preview_order(count, rank, overrides)
	var copy: BattleState = BattleState.from_dict(state.to_dict(), state.data)
	for tid: String in targets:
		var t: Combatant = copy.get_combatant(tid)
		if t == null or not t.is_alive() or t.is_pseudo:
			continue
		for def2: StatusDef in speed_defs:
			if t.status_immune.has(def2.id):
				continue
			for ex: String in def2.excludes:
				var old: StatusEffect = t.get_status(ex)
				if old != null:
					t.statuses.erase(old)
			if not t.has_status(def2.id):
				t.statuses.append(StatusEffect.new(def2, def2.default_turns, actor.id if actor != null else ""))
	return copy.preview_order(count, rank, overrides)
