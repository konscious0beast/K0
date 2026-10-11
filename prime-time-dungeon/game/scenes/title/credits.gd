extends Control
## "Etage 2 folgt" credits (GDD §1.4 B8, §15): teaser camera ride down a dead escalator into the sunken mall
## "Passage Ewiger Rabatt" (neon pink / cooler cyan / mould green, blinking "NUR HEUTE!" signs), credits roll on the
## left on an ink scrim (signs sit right of it), end card "ETAGE 2 FOLGT". Skippable (ui_accept / ui_cancel / button)
## → title. Params {"from_title": bool}.

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const SceneKit := preload("res://scenes/ui/scene_kit.gd")
const DURATION: float = 26.0
const ROLL_SPEED: float = 38.0
const ROLL: Array[Array] = [
	["h", "PRIME TIME DUNGEON"], ["s", "Vertical Slice · Etage 1 „Die Unterstadt“"], ["gap", ""],
	["r", "Moderation"], ["n", "M.O.D. – Mediale Omnipräsente Direktorin"], ["gap", ""],
	["r", "Kandidat:in"], ["n", "{name}"], ["gap", ""],
	["r", "Publikumsliebling"], ["n", "Graf Mopsula"], ["gap", ""],
	["r", "Bösewicht mit Schlüsselbund"], ["n", "Der Hausmeister"], ["gap", ""],
	["r", "Majestät auf Gleis 9"], ["n", "Die Rattenkönigin"], ["gap", ""],
	["r", "Präsentiert von"], ["n", "Glückwasser · KRAWUMM Energy · Panzerkeks"],
	["n", "Sorgenfrei Versicherungen AG · NovaNet · Brutzel-Burger · DoomScroll+"], ["gap", ""],
	["r", "Eine Produktion des"], ["n", "NOVA SYNDIKAT"], ["gap", ""],
	["r", "Gebaut mit"], ["n", "Godot Engine 4.7 · GDScript · prozedurale Low-Poly-Kunst"], ["gap", ""],
	["s", "Lootboxen in PRIME TIME DUNGEON können nicht gekauft werden."],
	["s", "Kein Mops wurde bei dieser Produktion verletzt. Wir haben gefragt. Er hat abgelehnt zu antworten."],
]
const ROLL_EDGE: float = 56.0       # px of the soft fade at the top / bottom of the credit roll


var elapsed: float = 0.0
var done: bool = false

var _params: Dictionary = {}
var _cam: Camera3D
var _signs: Array[Node3D] = []
var _roll: VBoxContainer
var _end_card: VBoxContainer
var _skip: Button
var _t: float = 0.0


func setup(params: Dictionary) -> void:
	_params = params


func _ready() -> void:
	UiUtil.full_rect(self)
	Events.overlay_mode_requested.emit.call_deferred(&"menu")
	Sfx.music(&"credits")
	_build()
	UiUtil.focus_later(_skip)
	if bool(_params.get("capture", false)):
		elapsed = 9.0
		_roll.position.y = 160.0
		_apply_camera()


func _process(delta: float) -> void:
	_t += delta
	for i in _signs.size():
		_signs[i].visible = fmod(_t * (1.3 + i * 0.4) + i, 1.0) < 0.72
	if done or bool(_params.get("capture", false)):
		return
	elapsed += delta
	_roll.position.y -= ROLL_SPEED * delta
	_apply_camera()
	_end_card.modulate.a = clampf((elapsed - (DURATION - 7.0)) / 1.0, 0.0, 1.0)
	if elapsed >= DURATION:
		finish()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		finish()


func finish() -> void:
	if done:
		return
	done = true
	Router.goto(Router.SCENE_TITLE)


func _apply_camera() -> void:
	var k: float = clampf(elapsed / (DURATION - 6.0), 0.0, 1.0)
	var pos: Vector3 = Vector3(0.0, 6.0, 9.0).lerp(Vector3(0.0, -4.5, -11.0), k)
	SceneKit.look(_cam, pos + Vector3(sin(elapsed * 0.3) * 0.3, 0, 0), pos + Vector3(0.6, -1.7, -6.0))


func _build() -> void:
	var view: SubViewportContainer = SubViewportContainer.new()
	view.stretch = true
	UiUtil.full_rect(view)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view)
	var vp: SubViewport = SubViewport.new()
	vp.own_world_3d = true
	view.add_child(vp)
	var world: Node3D = Node3D.new()
	vp.add_child(world)
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = SceneKit.environment(Color("#160a18"), Color("#5a3a6a"), 0.6, true, Color("#2a1a2a"), 0.03)
	world.add_child(we)
	_cam = SceneKit.camera(Vector3(0, 6, 9), Vector3(0, 3, 3), 55.0)
	world.add_child(_cam)
	_build_escalator(world)
	_build_mall(world)
	var shade: ColorRect = ColorRect.new()
	UiUtil.full_rect(shade)
	shade.color = Color(0.05, 0.02, 0.06, 0.35)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	# Left-to-right ink gradient behind the roll so the names stay readable over the neon signs.
	var grad: Gradient = Gradient.new()
	grad.set_color(0, Color(UiUtil.C_INK, 0.92))
	grad.set_color(1, Color(UiUtil.C_INK, 0.0))
	grad.add_point(0.7, Color(UiUtil.C_INK, 0.85))
	var gtex: GradientTexture2D = GradientTexture2D.new()
	gtex.gradient = grad
	gtex.width = 256
	gtex.height = 4
	var fade: TextureRect = TextureRect.new()
	fade.texture = gtex
	fade.stretch_mode = TextureRect.STRETCH_SCALE
	fade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fade.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	fade.offset_right = 760
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)
	var clip: Control = Control.new()
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	clip.offset_left = 48
	clip.offset_right = 600
	clip.offset_top = 40
	clip.offset_bottom = -90
	add_child(clip)
	_roll = UiUtil.vbox(4)
	_roll.custom_minimum_size = Vector2(540, 0)
	_roll.position = Vector2(0, 600)
	clip.add_child(_roll)
	# soft top / bottom edges: lines fade out instead of being cut mid-letter at the clip border (visual pass)
	for top: bool in [true, false]:
		var eg: Gradient = Gradient.new()
		eg.set_color(0, Color(UiUtil.C_INK, 0.95))
		eg.set_color(1, Color(UiUtil.C_INK, 0.0))
		var et: GradientTexture2D = GradientTexture2D.new()
		et.gradient = eg
		et.width = 4
		et.height = 64
		et.fill_from = Vector2(0, 0) if top else Vector2(0, 1)
		et.fill_to = Vector2(0, 1) if top else Vector2(0, 0)
		var edge: TextureRect = TextureRect.new()
		edge.name = "RollEdgeTop" if top else "RollEdgeBottom"
		edge.texture = et
		edge.stretch_mode = TextureRect.STRETCH_SCALE
		edge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		edge.set_anchors_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		edge.offset_top = 0.0 if top else -ROLL_EDGE
		edge.offset_bottom = ROLL_EDGE if top else 0.0
		clip.add_child(edge)
	for e: Array in ROLL:
		var kind: String = str(e[0])
		var text: String = UiUtil.format_line(str(e[1])) if str(e[1]).contains("{") else str(e[1])
		match kind:
			"h":
				_roll.add_child(UiUtil.label(text, &"LabelTitle", 46, UiTheme.C_ACCENT))
			"s":
				var s: Label = UiUtil.label(text, &"", 18, UiTheme.C_TEXT_DIM)
				s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				s.custom_minimum_size = Vector2(520, 0)
				_roll.add_child(s)
			"r":
				_roll.add_child(UiUtil.label(text.to_upper(), &"", 16, UiTheme.C_ACCENT_2))
			"n":
				var n: Label = UiUtil.label(text, &"", 24)
				n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				n.custom_minimum_size = Vector2(520, 0)
				_roll.add_child(n)
			_:
				_roll.add_child(UiUtil.spacer(18))
	_end_card = UiUtil.vbox(0)
	_end_card.set_anchors_preset(Control.PRESET_CENTER)
	_end_card.offset_left = -360
	_end_card.offset_right = 360
	_end_card.offset_top = -90
	_end_card.offset_bottom = 90
	_end_card.modulate.a = 0.0
	_end_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_end_card)
	var e1: Label = UiUtil.label("ETAGE 2 FOLGT", &"LabelTitle", 72, UiUtil.C_PAPER)
	e1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_card.add_child(e1)
	var e2: Label = UiUtil.label("„Passage Ewiger Rabatt“ – Bleiben Sie dran!", &"", 24, Color("#ff4fa0"))
	e2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_card.add_child(e2)
	var safe: SafeAreaContainer = SafeAreaContainer.new()
	safe.extra = 0
	add_child(safe)
	var frame: Control = Control.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(frame)
	_skip = UiUtil.button("Überspringen", &"")
	_skip.name = "Skip"
	_skip.add_theme_font_size_override("font_size", 16)
	UiUtil.touch_pad(_skip)
	_skip.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_skip.offset_left = -196
	_skip.offset_right = 0
	_skip.offset_top = -float(UiTheme.TOUCH_HIT)
	_skip.offset_bottom = 0
	_skip.pressed.connect(finish)
	frame.add_child(_skip)


func _build_escalator(world: Node3D) -> void:
	for i in 26:
		var y: float = 4.0 - i * 0.42
		var z: float = 6.0 - i * 0.62
		world.add_child(SceneKit.box(Vector3(2.4, 0.4, 0.6), Color("#5a5a66") if i % 2 == 0 else Color("#4e4e5a"),
			Vector3(0, y, z)))
		world.add_child(SceneKit.box(Vector3(2.4, 0.03, 0.05), Color("#ffc93c"), Vector3(0, y + 0.21, z - 0.27), 0.6))
	for side: float in [-1.5, 1.5]:
		for i in 13:
			var y2: float = 4.6 - i * 0.84
			var z2: float = 6.0 - i * 1.24
			world.add_child(SceneKit.box(Vector3(0.18, 0.9, 1.3), Color("#2a2a34"), Vector3(side, y2, z2), 0.0,
				Vector3(-34, 0, 0)))
			world.add_child(SceneKit.box(Vector3(0.06, 0.06, 1.3), Color("#ff4fa0") if side < 0 else Color("#4fe6ff"),
				Vector3(side, y2 + 0.5, z2), 2.4, Vector3(-34, 0, 0)))


## Shop fronts sit right of the credits scrim and deeper in the mall; sign text is INK on the pink sign (readable,
## no pink-on-pink); lamps hang from cables; a back wall with the mall's neon name fills the upper half.
func _build_mall(world: Node3D) -> void:
	world.add_child(SceneKit.box(Vector3(40, 0.2, 40), Color("#9a9080"), Vector3(0, -6.9, -18)))
	world.add_child(SceneKit.box(Vector3(40, 16, 0.4), Color("#2a1a2a"), Vector3(0, 0.0, -30)))
	world.add_child(SceneKit.box(Vector3(14, 0.14, 0.2), Color("#ff4fa0"), Vector3(6, 4.2, -29.7), 1.8))
	world.add_child(SceneKit.box(Vector3(14, 0.14, 0.2), Color("#4fe6ff"), Vector3(6, 1.6, -29.7), 1.8))
	var mall: Label3D = Label3D.new()
	mall.text = "PASSAGE EWIGER RABATT"
	mall.font_size = 96
	mall.pixel_size = 0.012
	mall.modulate = Color("#fff0f5")
	mall.outline_size = 18
	mall.outline_modulate = Color("#ff4fa0")
	mall.position = Vector3(6, 2.9, -29.6)
	world.add_child(mall)
	for i in 5:
		var x: float = -0.5 + i * 3.4
		var z: float = -17.0 - (i % 2) * 4.0
		world.add_child(SceneKit.box(Vector3(3.0, 3.4, 0.2), Color("#2a3a44"), Vector3(x, -5.1, z)))
		world.add_child(SceneKit.box(Vector3(2.6, 2.2, 0.05), Color("#7a5a6e") if i % 2 == 0 else Color("#2e8a9a"),
			Vector3(x, -5.4, z + 0.12), 0.35))
		var sign_node: Node3D = SceneKit.box(Vector3(2.4, 0.5, 0.08), Color("#ff4fa0"), Vector3(x, -3.2, z + 0.16), 0.6)
		world.add_child(sign_node)
		var l3: Label3D = Label3D.new()
		l3.text = "NUR HEUTE!" if i % 2 == 0 else "-90 %"
		l3.font_size = 64
		l3.pixel_size = 0.005
		l3.modulate = UiUtil.C_INK
		l3.outline_size = 0
		l3.position = Vector3(x, -3.2, z + 0.25)
		world.add_child(l3)
		_signs.append(l3)
	for i in 3:
		var lamp: Vector3 = Vector3(-1.0 + i * 4.5, -4.2, -10.0 - (i % 2) * 3.0)
		world.add_child(SceneKit.cylinder(0.02, 0.02, 6.0, Color("#3a3036"), lamp + Vector3(0, 3.3, 0)))
		world.add_child(SceneKit.cylinder(0.12, 0.42, 0.25, Color("#3a3036"), lamp + Vector3(0, 0.38, 0), 0.0, 16, true))
		world.add_child(SceneKit.sphere(0.24, Color("#c8e04a"), lamp + Vector3(0, 0.2, 0), 1.2))
	world.add_child(SceneKit.omni(Color("#ff4fa0"), 2.0, 14.0, Vector3(-4, -3, -10)))
	world.add_child(SceneKit.omni(Color("#4fe6ff"), 2.0, 14.0, Vector3(4, -3, -14)))
	world.add_child(SceneKit.omni(Color("#ffd59e"), 1.0, 10.0, Vector3(0, 5, 6)))
