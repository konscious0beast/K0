extends Control
## M.O.D. intro cutscene (GDD §1.4 B0, §14.2): night shift in the shelter basement → the sky becomes a screen, NOVA
## SYNDIKAT "Rückbau", buildings fold away → the floor breaks → TV studio: M.O.D. goes on air, Graf Mopsula speaks.
## Letterboxed 3D shots in a SubViewport, own subtitle box (typewriter), hold-to-skip (1 s, any input device).
## Ends with Game.set_flag("intro_seen", true) → Router.goto(SCENE_EXPLORATION, {"spawn": &"start"}).

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const UiIcon := preload("res://scenes/ui/ui_icon.gd")
const SceneKit := preload("res://scenes/ui/scene_kit.gd")
const HOLD_TO_SKIP: float = 1.0
const CPS: float = 40.0
const LINE_HOLD: float = 1.5
const SET_STUDIO: Vector3 = Vector3(200, 0, 0)
const SET_CITY: Vector3 = Vector3(100, 0, 0)
const DEFAULT_INTRO: PackedStringArray = [
	"Guten Abend, Galaxis! Willkommen bei DUNGEON PRIME TIME – der Show, die Ihren Planeten gekostet hat!",
	"Kandidat:in {name}, Sie sind live. Bitte nicht in die Kamera weinen, das spiegelt."]

## Script: [{"shot", "caption", "lines": [[voice, text], …], "min": seconds}]
var shots: Array[Dictionary] = []
var shot_index: int = -1
var finished: bool = false

var _params: Dictionary = {}
var _vp: SubViewport
var _world: Node3D
var _cam: Camera3D
var _env: Environment
var _drone: Node3D
var _buildings: Array[Node3D] = []
var _floor_tiles: Array[Node3D] = []
var _sky_screen: MeshInstance3D
var _caption: Label
var _sub_panel: PanelContainer
var _speaker: Label
var _text: Label
var _flash: ColorRect
var _skip: Button
var _skip_ring: Control
var _nova_logo: VBoxContainer
var _line_queue: Array[Array] = []
var _line_shown: float = 0.0
var _line_hold: float = 0.0
var _shot_time: float = 0.0
var _t: float = 0.0
var _hold: float = 0.0
var _holding: bool = false
var _shake: float = 0.0


func setup(params: Dictionary) -> void:
	_params = params


func _ready() -> void:
	UiUtil.full_rect(self)
	Game.ensure_state()
	Events.overlay_mode_requested.emit.call_deferred(&"menu")
	Sfx.music(&"")
	_build()
	_make_script()
	UiUtil.focus_later(_skip)
	if bool(_params.get("capture", false)):
		_jump_to(3)
		_line_queue.clear()
		_show_line(["mod", _intro_line(0)])
		_line_shown = 9999.0
		_text.visible_characters = -1
		set_process(true)
	else:
		_next_shot()


func _process(delta: float) -> void:
	if finished:
		return
	_t += delta
	_shot_time += delta
	SceneKit.animate_drone(_drone, _t, 1.9)
	_animate_shot(delta)
	if _holding:
		_hold += delta
		_skip_ring.queue_redraw()
		if _hold >= HOLD_TO_SKIP:
			skip()
			return
	if bool(_params.get("capture", false)):
		return
	var total: int = _text.text.length()
	if _line_shown < total:
		_line_shown = float(total) if Game.fast_text else _line_shown + CPS * delta
		_text.visible_characters = -1 if _line_shown >= total else int(_line_shown)
		if _line_shown >= total:
			_line_hold = 0.35 if Game.fast_text else LINE_HOLD + total * 0.02
	else:
		_line_hold -= delta
		if _line_hold <= 0.0:
			if not _line_queue.is_empty():
				_show_line(_line_queue.pop_front())
			elif _shot_time >= float(shots[shot_index].get("min", 0.0)) * (0.2 if Game.fast_text else 1.0):
				_next_shot()


## Ends the intro now (hold-to-skip, or the end of the script).
func skip() -> void:
	if finished:
		return
	finished = true
	_holding = false
	Game.set_flag("intro_seen", true)
	Sfx.play_ui(&"ui_confirm")
	Router.goto(Router.SCENE_EXPLORATION, {"spawn": &"start"})


## Finishes the current line immediately (short press).
func fast_forward() -> void:
	if _line_shown < _text.text.length():
		_line_shown = float(_text.text.length())
		_text.visible_characters = -1
	else:
		_line_hold = 0.0


func current_shot() -> String:
	return str(shots[shot_index].get("shot", "")) if shot_index >= 0 and shot_index < shots.size() else ""


func _make_script() -> void:
	var kai: String = UiUtil.player_name()
	shots = [
		{"shot": "night", "caption": "TIERHEIM LINDENHOF · KELLER · NACHTSCHICHT · 23:47", "min": 5.0,
			"lines": [["kai", "Na, Graf? Ein Leckerli noch, dann ist Licht aus."], ["mopsula", "*schnauf*"]]},
		{"shot": "sky", "caption": "AM SELBEN ABEND · ÜBER DER STADT", "min": 6.5,
			"lines": [["mod", "Liebe Erdbevölkerung: Ihr Planet wurde für eine Sendung umgewidmet. Bitte bleiben Sie sitzen."],
				["mod", "Rückbau beginnt. Wir danken für Ihr Verständnis. Sie haben keins? Egal."]]},
		{"shot": "fall", "caption": "", "min": 2.5, "lines": [["kai", "Graf! Komm her!"]]},
		{"shot": "studio", "caption": "LIVE · DUNGEON PRIME TIME", "min": 3.0,
			"lines": [["mod", _intro_line(0)], ["mod", _intro_line(1)], ["mopsula", "Endlich. Man versteht Uns."],
				["kai", "… Graf?"], ["mopsula", "GRAF MOPSULA. Wir bitten um korrekte Anrede, %s." % kai]]},
	]


func _intro_line(i: int) -> String:
	var lines: Array[ModLineDef] = DB.mod_lines("intro")
	var raw: String = DEFAULT_INTRO[i % DEFAULT_INTRO.size()]
	if i < lines.size():
		raw = lines[i].text
	return UiUtil.format_line(raw)


func _next_shot() -> void:
	shot_index += 1
	if shot_index >= shots.size():
		skip()
		return
	_jump_to(shot_index)
	for l: Variant in shots[shot_index].get("lines", []):
		_line_queue.append(l as Array)
	if not _line_queue.is_empty():
		_show_line(_line_queue.pop_front())


func _jump_to(i: int) -> void:
	shot_index = i
	_shot_time = 0.0
	var shot: String = str(shots[i]["shot"]) if not shots.is_empty() else "studio"
	_caption.text = str(shots[i].get("caption", "")) if not shots.is_empty() else "LIVE · DUNGEON PRIME TIME"
	_caption.visible = _caption.text != ""
	_nova_logo.visible = shot == "sky"
	match shot:
		"night":
			SceneKit.look(_cam, Vector3(2.6, 1.7, 4.2), Vector3(0, 0.8, 0))
			_env.background_color = Color("#0b0812")
			_env.ambient_light_color = Color("#3a3050")
		"sky":
			SceneKit.look(_cam, SET_CITY + Vector3(0, 2.0, 14.0), SET_CITY + Vector3(0, 6.0, -10.0))
			_env.background_color = Color("#0a1028")
			_env.ambient_light_color = Color("#3a4a7a")
		"fall":
			SceneKit.look(_cam, Vector3(-1.8, 2.4, 3.6), Vector3(0, 0.4, 0))
			_env.background_color = Color("#0b0812")
			_shake = 1.0
			Sfx.play(&"ko")
		"studio":
			SceneKit.look(_cam, SET_STUDIO + Vector3(0, 1.8, 5.6), SET_STUDIO + Vector3(0, 1.5, 0))
			_env.background_color = Color("#140a22")
			_env.ambient_light_color = Color("#6a4a9a")
			Sfx.music(&"title")
			Sfx.play_ui(&"mod_blip")
			if is_inside_tree():
				_flash.color = Color(1, 1, 1, 0.9)
				create_tween().tween_property(_flash, "color:a", 0.0, 0.5)


func _show_line(line: Array) -> void:
	var voice: String = str(line[0])
	_text.text = UiUtil.glyph_safe(str(line[1]))
	_text.visible_characters = 0
	_line_shown = 0.0
	_line_hold = 0.0
	var col: Color = UiTheme.C_ACCENT_2
	var who: String = "M.O.D."
	if voice == "kai":
		col = UiUtil.member_color("kai")
		who = UiUtil.player_name()
	elif voice == "mopsula":
		col = UiUtil.member_color("mopsula").lightened(0.25)
		who = "Graf Mopsula" if shot_index >= 3 else "Der Mops"
	_speaker.text = who
	_speaker.add_theme_color_override("font_color", col)
	var sb: StyleBoxFlat = UiUtil.box_style(Color(UiUtil.C_INK, 0.82), col, 2, 0.0, 22, 10)
	_sub_panel.add_theme_stylebox_override("panel", sb)
	if voice == "mod":
		Sfx.play_ui(&"mod_blip")


func _animate_shot(delta: float) -> void:
	var shot: String = current_shot()
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 0.8)
		_cam.h_offset = randf_range(-1.0, 1.0) * 0.08 * _shake
		_cam.v_offset = randf_range(-1.0, 1.0) * 0.08 * _shake
	else:
		_cam.h_offset = 0.0
		_cam.v_offset = 0.0
	match shot:
		"night":
			_cam.position.x = 2.6 - _shot_time * 0.12
		"sky":
			var k: float = clampf((_shot_time - 1.2) / 4.0, 0.0, 1.0)
			_env.background_color = Color("#0a1028").lerp(Color("#5a0f3a"), clampf(_shot_time / 1.5, 0.0, 1.0))
			_sky_screen.visible = _shot_time > 0.6
			for i in _buildings.size():
				var b: Node3D = _buildings[i]
				var local_k: float = clampf(k * 1.6 - float(i) / _buildings.size() * 0.6, 0.0, 1.0)
				b.rotation.x = -local_k * PI * 0.5
				b.position.y = -local_k * 2.0
			if _shot_time > 1.2:
				_shake = maxf(_shake, 0.35)
		"fall":
			for i in _floor_tiles.size():
				var tile: Node3D = _floor_tiles[i]
				var drop: float = maxf(0.0, _shot_time - 0.2 - i * 0.07)
				tile.position.y = -drop * drop * 4.0
				tile.rotation = Vector3(drop * (0.8 + 0.1 * i), 0.0, drop * (0.5 - 0.15 * i))
			if _shot_time > 1.8 and _flash.color.a < 0.95:
				_flash.color = Color(UiUtil.C_INK, clampf((_shot_time - 1.8) * 1.5, 0.0, 1.0))
		"studio":
			_cam.position.z = SET_STUDIO.z + 5.6 - minf(_shot_time, 6.0) * 0.12


# --- build -----------------------------------------------------------------------------------------------------------

func _build() -> void:
	var view: SubViewportContainer = SubViewportContainer.new()
	view.stretch = true
	UiUtil.full_rect(view)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view)
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	view.add_child(_vp)
	_world = Node3D.new()
	_vp.add_child(_world)
	var we: WorldEnvironment = WorldEnvironment.new()
	_env = SceneKit.environment(Color("#0b0812"), Color("#3a3050"), 0.6, true)
	we.environment = _env
	_world.add_child(we)
	_cam = SceneKit.camera(Vector3(2.6, 1.7, 4.2), Vector3(0, 0.8, 0), 50.0)
	_world.add_child(_cam)
	_build_basement()
	_build_city()
	_build_studio()
	_build_ui()


func _build_basement() -> void:
	for x in 4:
		for z in 3:
			var tile: MeshInstance3D = SceneKit.box(Vector3(1.48, 0.2, 1.48), Color("#3a3440") if (x + z) % 2 == 0 else
				Color("#332e3a"), Vector3(-2.25 + x * 1.5, -0.1, -1.5 + z * 1.5))
			_world.add_child(tile)
			_floor_tiles.append(tile)
	_world.add_child(SceneKit.box(Vector3(7, 4, 0.3), Color("#4a4250"), Vector3(0, 2, -2.4)))
	_world.add_child(SceneKit.box(Vector3(0.3, 4, 5), Color("#423a48"), Vector3(-3.2, 2, 0)))
	_world.add_child(SceneKit.box(Vector3(1.4, 0.9, 0.08), Color("#1a2a4a"), Vector3(0.8, 2.6, -2.22), 0.4))
	for i in 3:
		_world.add_child(SceneKit.box(Vector3(1.1, 1.2, 0.8), Color("#5a4a3a"), Vector3(-2.4 + i * 1.2, 0.6, -1.9)))
		_world.add_child(SceneKit.box(Vector3(1.0, 0.06, 0.04), Color("#9a9aa8"), Vector3(-2.4 + i * 1.2, 0.9, -1.48)))
	_world.add_child(SceneKit.cylinder(0.55, 0.6, 0.18, Color("#7b2cbf"), Vector3(0.6, 0.09, 0.3), 0.0, 20))
	var kai: Node3D = SceneKit.party_figure("kai")
	kai.position = Vector3(-0.6, 0, 0.6)
	kai.rotation.y = deg_to_rad(-60)
	_world.add_child(kai)
	var pug: Node3D = SceneKit.party_figure("mopsula")
	pug.position = Vector3(0.6, 0.18, 0.3)
	pug.rotation.y = deg_to_rad(40)
	_world.add_child(pug)
	_world.add_child(SceneKit.omni(Color("#ffc98a"), 1.6, 7.0, Vector3(0.2, 3.2, 1.0)))
	_world.add_child(SceneKit.sphere(0.12, Color("#ffe2b8"), Vector3(0.2, 3.4, 1.0), 3.0))


func _build_city() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 47
	_world.add_child(SceneKit.box(Vector3(80, 0.2, 60), Color("#1a1a24"), SET_CITY + Vector3(0, -0.1, -10)))
	for i in 14:
		var pivot: Node3D = Node3D.new()
		var x: float = -18.0 + i * 2.8 + rng.randf_range(-0.4, 0.4)
		var z: float = -6.0 - rng.randf_range(0.0, 8.0)
		pivot.position = SET_CITY + Vector3(x, 0, z)
		_world.add_child(pivot)
		var h: float = rng.randf_range(4.0, 11.0)
		var w: float = rng.randf_range(1.8, 2.6)
		pivot.add_child(SceneKit.box(Vector3(w, h, 2.0), Color("#2a2838").lerp(Color("#3a3448"), rng.randf()),
			Vector3(0, h * 0.5, 0)))
		for wy in int(h / 1.4):
			for wx in 2:
				if rng.randf() < 0.55:
					pivot.add_child(SceneKit.box(Vector3(0.4, 0.5, 0.05), Color("#ffd59e"), Vector3(-w * 0.25 + wx *
						w * 0.5, 1.0 + wy * 1.4, 1.02), 1.5))
		_buildings.append(pivot)
	_sky_screen = SceneKit.box(Vector3(18, 7, 0.2), Color("#ff2e88"), SET_CITY + Vector3(0, 13, -24), 1.4)
	_sky_screen.visible = false
	_world.add_child(_sky_screen)
	_world.add_child(SceneKit.sphere(1.0, Color("#e6e0ff"), SET_CITY + Vector3(-12, 16, -30), 1.2))


func _build_studio() -> void:
	_world.add_child(SceneKit.cylinder(3.6, 3.8, 0.3, Color("#24183a"), SET_STUDIO + Vector3(0, -0.15, 0), 0.0, 32))
	_world.add_child(SceneKit.cylinder(3.85, 3.85, 0.05, Color("#ff2e88"), SET_STUDIO + Vector3(0, 0.01, 0), 1.8, 40))
	_world.add_child(SceneKit.cylinder(3.7, 3.7, 0.06, Color("#24183a"), SET_STUDIO + Vector3(0, 0.02, 0), 0.0, 40))
	for i in 9:
		var a: float = deg_to_rad(-60.0 + i * 15.0)
		var p: Vector3 = SET_STUDIO + Vector3(sin(a) * 6.5, 2.2, -cos(a) * 6.5)
		var panel: MeshInstance3D = SceneKit.box(Vector3(1.6, 4.6, 0.2), Color("#1d1430"), p, 0.0,
			Vector3(0, -rad_to_deg(a), 0))
		_world.add_child(panel)
		var strip: MeshInstance3D = SceneKit.box(Vector3(0.08, 4.2, 0.08), Color("#22d3ee") if i % 2 == 0 else
			Color("#ff2e88"), p + Vector3(0, 0, 0.15), 2.2, Vector3(0, -rad_to_deg(a), 0))
		_world.add_child(strip)
	_drone = SceneKit.build_drone(1.6)
	_drone.position = SET_STUDIO + Vector3(0, 1.9, -0.5)
	_world.add_child(_drone)
	var kai: Node3D = SceneKit.party_figure("kai")
	kai.position = SET_STUDIO + Vector3(-1.6, 0.05, 1.2)
	kai.rotation.y = deg_to_rad(-20)
	_world.add_child(kai)
	var pug: Node3D = SceneKit.party_figure("mopsula")
	pug.position = SET_STUDIO + Vector3(1.5, 0.05, 1.3)
	pug.rotation.y = deg_to_rad(25)
	_world.add_child(pug)
	_world.add_child(SceneKit.omni(Color("#22d3ee"), 2.4, 7.0, SET_STUDIO + Vector3(0, 2.4, 1.5)))
	_world.add_child(SceneKit.omni(Color("#ff2e88"), 1.8, 9.0, SET_STUDIO + Vector3(-3, 3, 2)))
	_world.add_child(SceneKit.omni(Color("#ffc93c"), 1.2, 8.0, SET_STUDIO + Vector3(3, 3, 2)))


func _build_ui() -> void:
	for top: bool in [true, false]:
		var bar: ColorRect = ColorRect.new()
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.set_anchors_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		if top:
			bar.offset_bottom = 56
		else:
			bar.offset_top = -56
		add_child(bar)
	_nova_logo = UiUtil.vbox(-6)
	_nova_logo.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_nova_logo.offset_left = -300
	_nova_logo.offset_right = 300
	_nova_logo.offset_top = 92
	_nova_logo.visible = false
	add_child(_nova_logo)
	var n1: Label = UiUtil.label("NOVA SYNDIKAT", &"LabelTitle", 64, UiUtil.C_PAPER)
	n1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_nova_logo.add_child(n1)
	var n2: Label = UiUtil.label("+++ RÜCKBAU GENEHMIGT +++", &"", 24, UiTheme.C_GOLD)
	n2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n2.add_theme_font_override("font", UiTheme.font_bold())
	_nova_logo.add_child(n2)
	_caption = UiUtil.label("", &"", 16, UiTheme.C_TEXT_DIM)
	_caption.add_theme_font_override("font", UiTheme.font_bold())
	_caption.position = Vector2(40, 18)
	add_child(_caption)
	_sub_panel = PanelContainer.new()
	_sub_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_sub_panel.offset_left = -400
	_sub_panel.offset_right = 400
	_sub_panel.offset_top = -56 - 24 - 104
	_sub_panel.offset_bottom = -56 - 24
	_sub_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sub_panel)
	var col: VBoxContainer = UiUtil.vbox(2)
	_sub_panel.add_child(col)
	_speaker = UiUtil.label("", &"", 17)
	_speaker.add_theme_font_override("font", UiTheme.font_bold())
	col.add_child(_speaker)
	_text = UiUtil.label("", &"", 22)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_text)
	_flash = ColorRect.new()
	UiUtil.full_rect(_flash)
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	_skip = UiUtil.button("Überspringen (halten)", &"")
	_skip.name = "Skip"
	_skip.add_theme_font_size_override("font_size", 16)
	_skip.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_skip.offset_left = -280
	_skip.offset_right = -24
	_skip.offset_top = -50
	_skip.offset_bottom = -8
	_skip.button_down.connect(func() -> void:
		_holding = true
		_hold = 0.0)
	_skip.button_up.connect(func() -> void:
		if _holding and _hold < HOLD_TO_SKIP:
			fast_forward()
		_holding = false
		_hold = 0.0
		_skip_ring.queue_redraw())
	add_child(_skip)
	_skip_ring = Control.new()
	_skip_ring.custom_minimum_size = Vector2(26, 26)
	_skip_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skip_ring.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_skip_ring.offset_left = -312
	_skip_ring.offset_right = -286
	_skip_ring.offset_top = -42
	_skip_ring.offset_bottom = -16
	_skip_ring.draw.connect(func() -> void:
		var c: Vector2 = _skip_ring.size * 0.5
		_skip_ring.draw_arc(c, 11.0, 0.0, TAU, 32, Color(1, 1, 1, 0.25), 3.0, true)
		if _hold > 0.0:
			_skip_ring.draw_arc(c, 11.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(_hold / HOLD_TO_SKIP, 0.0, 1.0), 32,
				UiTheme.C_ACCENT, 3.0, true))
	add_child(_skip_ring)
