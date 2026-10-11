extends Control
## Hero choice of a new game (06 §1.1, package A): "Wen steuerst du?" — two big cards side by side, Kai first
## (default focus), each with a turning 3D preview of the figure, a one-line pitch, the field ability and the role. One
## press chooses and goes on to the name entry ({"slot", "hero"}); `ui_cancel` goes back to the slot select. The duo
## always starts together — the other one follows (and the choice can be changed in every safe room).
## Params {"slot": int, "hero": "kai" | "mopsula" (focused card, default kai), "capture": bool}.

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const InputGlyph := preload("res://scenes/ui/input_glyph.gd")
const UiIcon := preload("res://scenes/ui/ui_icon.gd")
const Backdrop := preload("res://scenes/ui/broadcast_bg.gd")
const SceneKit := preload("res://scenes/ui/scene_kit.gd")
const SLOT_SELECT: String = "res://scenes/title/slot_select.tscn"
## Casting (08 §10.2 Nr. 15, K0): the next screen after the hero card — K1 points it at persona_casting.tscn.
const CASTING_SCENE: String = "res://scenes/title/name_entry.tscn"
const CARD_SIZE: Vector2 = Vector2(540, 452)
const PREVIEW_H: float = 236.0
const TURN_DEG: float = 28.0               # the preview figure turns ±28° (slow turntable)
const HEROES: Array[Dictionary] = [
	{"id": "kai", "title": "KAI", "pitch": "Tierpfleger:in. Wischmopp. Haut zu.", "field_icon": &"fist",
		"field": "Feldschlag: Monster zuerst treffen", "role": "Nahkampf · Tank", "color": "#3aa9a0"},
	{"id": "mopsula", "title": "GRAF MOPSULA", "pitch": "Mops. Magier. Schwer vermittelbar.", "field_icon": &"bark",
		"field": "Bellen: Monster verdutzen, vorbeischleichen", "role": "Magie · Heilung", "color": "#b05cff"},
]

var slot: int = 1
var cards: Dictionary = {}                 # hero id → Button
var chosen: String = ""

var _params: Dictionary = {}
var _busy: bool = false
var _figures: Array[Node3D] = []
var _t: float = 0.0


func setup(params: Dictionary) -> void:
	_params = params
	slot = int(params.get("slot", 1))


func _ready() -> void:
	UiUtil.full_rect(self)
	Events.overlay_mode_requested.emit.call_deferred(&"menu")
	_build()
	focus_default()


func focus_default() -> void:
	var want: String = HeroRules.sanitize(str(_params.get("hero", HeroRules.DEFAULT_HERO)))
	UiUtil.focus_later(cards.get(want, cards.get("kai")) as Control)


func _process(delta: float) -> void:
	_t += delta
	for i in _figures.size():
		var f: Node3D = _figures[i]
		if is_instance_valid(f):
			f.rotation.y = PI + deg_to_rad(TURN_DEG) * sin(_t * 0.6 + float(i) * 1.7)   # rigs look along −Z


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		back()


## The card of `hero_id` was pressed: on to the name entry with this hero.
func choose(hero_id: String) -> void:
	if _busy or not HeroRules.HEROES.has(hero_id):
		return
	_busy = true
	chosen = hero_id
	Sfx.play_ui(&"ui_confirm")
	Router.goto(CASTING_SCENE, {"slot": slot, "hero": hero_id})


func back() -> void:
	if _busy:
		return
	_busy = true
	Sfx.play_ui(&"ui_cancel")
	Router.goto(SLOT_SELECT, {"mode": "new"})


# --- build -----------------------------------------------------------------------------------------------------------

func _build() -> void:
	add_child(Backdrop.new())
	var safe: SafeAreaContainer = SafeAreaContainer.new()
	safe.extra = 24
	add_child(safe)
	var col: VBoxContainer = UiUtil.vbox(10)
	safe.add_child(col)
	var head: HBoxContainer = UiUtil.hbox(14)
	col.add_child(head)
	head.add_child(UiUtil.label("WEN STEUERST DU?", &"LabelTitle", 48))
	var slot_l: Label = UiUtil.label("Slot %d" % slot, &"", 18, UiTheme.C_ACCENT_2)
	slot_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(slot_l)
	head.add_child(UiUtil.spacer(0, 0, true))
	head.add_child(InputGlyph.make(&"ui_accept", "Wählen", 16))
	head.add_child(InputGlyph.make(&"ui_cancel", "Zurück", 16))
	col.add_child(UiUtil.label("M.O.D.: „Wen steuern Sie? Der andere kommt mit – ob er will oder nicht.“", &"", 20,
		UiTheme.C_TEXT_DIM))
	var center: CenterContainer = CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(center)
	var row: HBoxContainer = UiUtil.hbox(40)
	center.add_child(row)
	var list: Array[Control] = []
	for h: Dictionary in HEROES:
		var card: Button = _card(h)
		row.add_child(card)
		cards[str(h["id"])] = card
		list.append(card)
	UiUtil.wire_horizontal(list)
	var hint: Label = UiUtil.label("Ihr startet immer zu zweit. Wechseln kannst du jederzeit im Safe Room.", &"", 18,
		UiTheme.C_TEXT_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(hint)


func _card(h: Dictionary) -> Button:
	var id: String = str(h["id"])
	var accent: Color = Color(str(h["color"]))
	var b: Button = UiUtil.button("", &"ButtonBig")
	b.name = "Card_" + id
	b.custom_minimum_size = CARD_SIZE
	b.pressed.connect(func() -> void: choose(id))
	b.focus_entered.connect(func() -> void: Sfx.play_ui(&"ui_move"))
	var inner: VBoxContainer = UiUtil.vbox(6)
	UiUtil.full_rect(inner)
	inner.offset_left = 18
	inner.offset_right = -18
	inner.offset_top = 16
	inner.offset_bottom = -16
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(inner)
	inner.add_child(_preview(id, accent))
	var name_l: Label = UiUtil.label(str(h["title"]), &"", 34)
	name_l.add_theme_font_override("font", UiTheme.font_bold())
	inner.add_child(name_l)
	var pitch: Label = UiUtil.label(str(h["pitch"]), &"", 20, UiTheme.C_TEXT)
	inner.add_child(pitch)
	var field: HBoxContainer = UiUtil.hbox(10)
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(field)
	var ic: Control = UiIcon.make(h["field_icon"] as StringName, accent.lightened(0.25), 26)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	field.add_child(ic)
	field.add_child(UiUtil.label(str(h["field"]), &"", 18, UiTheme.C_ACCENT_2))
	inner.add_child(UiUtil.label("Rolle: " + str(h["role"]), &"LabelSmall", 17))
	return b


## Turning 3D figure on a small round stage (own world, rendered only while visible).
func _preview(member_id: String, accent: Color) -> Control:
	var view: SubViewportContainer = SubViewportContainer.new()
	view.name = "Preview"
	view.stretch = true
	view.custom_minimum_size = Vector2(0, PREVIEW_H)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vp: SubViewport = SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	view.add_child(vp)
	var world: Node3D = Node3D.new()
	vp.add_child(world)
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = SceneKit.environment(Color("#1b1026"), Color("#6a5a8a"), 0.9, false)
	world.add_child(we)
	world.add_child(SceneKit.sun(Color("#fff2e0"), 1.3, Vector3(-40, -30, 0)))
	world.add_child(SceneKit.omni(accent, 2.2, 6.0, Vector3(-1.4, 1.6, 1.2)))
	var fig: Node3D = SceneKit.party_figure(member_id)
	fig.name = "Figure"
	fig.rotation.y = PI                          # face the camera (rigs look along −Z)
	world.add_child(fig)
	_figures.append(fig)
	if fig.has_method("play"):
		fig.call("play", &"idle")
	var height: float = maxf(0.6, float(fig.get("height")) if "height" in fig else 1.0)
	var r: float = 0.5 + height * 0.35          # the stage disc follows the figure's size
	world.add_child(SceneKit.cylinder(r, r, 0.12, Color("#2a1c3a"), Vector3(0, -0.06, 0)))
	world.add_child(SceneKit.cylinder(r + 0.02, r + 0.02, 0.02, accent.darkened(0.2), Vector3(0, 0.005, 0), 0.6))
	# both stages read the same (camera 1.3 m up, looking down on the disc); the small pug gets a closer camera
	var dist: float = height * 1.25 + 1.7
	var cam: Camera3D = SceneKit.camera(Vector3(0.0, 1.3, dist), Vector3(0.0, height * 0.5, 0.0), 40.0)
	world.add_child(cam)
	return view
