extends Node
## Main scene (02_TECH §1.6, §11.4; GDD §14.1): reads the user args (--autoplay, --seed=<int>,
## --goto=explore|safe_room|battle:<enc_id>|title|credits|lobby|game_over), applies the settings, adds GlobalUi once
## under root (deferred) and — with --autoplay — the autoplay driver (max_fps 60, time_scale 5, read-only saves, fast
## text, ephemeral). Shows the "NOVA SYNDIKAT präsentiert" card for 2 s (any input skips) while pre-warming the shader
## materials behind it (03_ART §3.10), then routes to the title (or the --goto target).

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const TitleFlow := preload("res://scenes/title/title_flow.gd")
## Loaded only with --autoplay: the driver type-checks against every screen class, so preloading it here compiled
## the whole game before the first frame (02_TECH §12.1 "Start").
const AUTOPLAY_SCRIPT: String = "res://scenes/boot/autoplay.gd"
const GLOBAL_UI: String = "res://scenes/ui/global_ui.tscn"
const EVENT_LOBBY: String = "res://scenes/ui/event_lobby.tscn"
const LOGO_SEC: float = 2.0
const PREWARM_FRAMES: int = 2

var args: Dictionary = {}

var _routed: bool = false
var _logo: CanvasLayer
var _prewarm: Node3D
var _frames: int = 0
var _elapsed: float = 0.0


func _ready() -> void:
	args = TitleFlow.parse_args(OS.get_cmdline_user_args())
	TitleFlow.boot_seed = int(args["seed"])
	if bool(args["autoplay"]):
		Game.autoplay = true
		Game.ephemeral = true
		Game.fast_text = true
		Save.read_only = true
		Engine.max_fps = 60
		Engine.time_scale = 5.0
		var ap: Node = (load(AUTOPLAY_SCRIPT) as GDScript).new() as Node
		ap.name = "Autoplay"
		get_tree().root.add_child.call_deferred(ap)
	Game.apply_settings()
	if ResourceLoader.exists(GLOBAL_UI):
		var ui: Node = (load(GLOBAL_UI) as PackedScene).instantiate()
		ui.name = "GlobalUi"
		get_tree().root.add_child.call_deferred(ui)
	_build_logo()
	_build_prewarm()


func _process(delta: float) -> void:
	if _routed:
		return
	_frames += 1
	_elapsed += delta
	if _frames > PREWARM_FRAMES and _prewarm != null:
		_prewarm.queue_free()
		_prewarm = null
	if _elapsed >= LOGO_SEC:
		route()


func _input(event: InputEvent) -> void:
	if _routed or _frames <= PREWARM_FRAMES:
		return
	var pressed: bool = (event is InputEventKey and (event as InputEventKey).pressed) \
		or (event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed) \
		or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) \
		or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	if pressed:
		get_viewport().set_input_as_handled()
		route()


## Leaves the boot card: --goto target or the title.
func route() -> void:
	if _routed:
		return
	_routed = true
	var target: String = str(args.get("goto", ""))
	if target == "" or target == "title":
		Router.goto(Router.SCENE_TITLE)
		return
	match target:
		"explore":
			_ensure_dev_state()
			Router.goto(Router.SCENE_EXPLORATION, {"spawn": &"start"})
		"safe_room":
			_ensure_dev_state()
			Router.goto(Router.SCENE_EXPLORATION, {"spawn": &"start"})
			var rooms: Array[Dictionary] = UiUtil.floor_safe_rooms(Game.floor_def())
			Router.enter_safe_room(str(rooms[0]["id"]) if not rooms.is_empty() else "")
		"credits":
			Router.goto(Router.SCENE_CREDITS, {"from_title": true})
		"game_over":
			_ensure_dev_state()
			Router.goto(Router.SCENE_GAME_OVER, {"reason": &"timer"})
		"lobby":
			Router.goto(EVENT_LOBBY)
		_:
			if target.begins_with("battle:"):
				_ensure_dev_state()
				var enc: String = target.trim_prefix("battle:")
				Router.goto(Router.SCENE_EXPLORATION, {"spawn": &"start"})
				var setup: BattleSetup = Game.make_battle_setup(enc, 0, "")
				if setup != null:
					Router.start_battle(setup)
			else:
				push_warning("[Boot] unknown --goto target '%s' → title" % target)
				Router.goto(Router.SCENE_TITLE)


func _ensure_dev_state() -> void:
	if Game.has_state():
		return
	var s: int = int(args.get("seed", -1))
	if s >= 0:
		Game.new_game(0, "Kai", s)
	else:
		Game.ensure_state()


func _build_logo() -> void:
	_logo = CanvasLayer.new()
	_logo.name = "BootCard"
	_logo.layer = 95
	add_child(_logo)
	var root: Control = Control.new()
	UiUtil.full_rect(root)
	UiUtil.apply_theme(root)
	_logo.add_child(root)
	var bg: ColorRect = ColorRect.new()
	UiUtil.full_rect(bg)
	bg.color = UiUtil.C_INK
	root.add_child(bg)
	var center: CenterContainer = CenterContainer.new()
	UiUtil.full_rect(center)
	root.add_child(center)
	var col: VBoxContainer = UiUtil.vbox(4)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(col)
	var top: Label = UiUtil.label("NOVA SYNDIKAT", &"LabelTitle", 64, UiTheme.C_ACCENT)
	top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(top)
	var sub: Label = UiUtil.label("präsentiert", &"", 26, UiTheme.C_ACCENT_2)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	root.modulate.a = 0.0
	var tw: Tween = create_tween()
	tw.tween_property(root, "modulate:a", 1.0, 0.35)


## Renders every Materials factory result for 2 frames on cubes behind the boot card (03_ART §3.10).
func _build_prewarm() -> void:
	_prewarm = Node3D.new()
	_prewarm.name = "ShaderPrewarm"
	add_child(_prewarm)
	var cam: Camera3D = Camera3D.new()
	cam.position = Vector3(0, 0, 4)
	cam.current = true
	_prewarm.add_child(cam)
	var mats: Array[Material] = []
	for m: Variant in [Materials.toon(Color("#ff2e88")), Materials.toon_vc(), Materials.env(), Materials.glow(
			Color("#22d3ee")), Materials.vfx_additive(Color("#ffc93c")), Materials.outline()]:
		if m is Material:
			mats.append(m as Material)
	var i: int = 0
	for m: Material in mats:
		var mi: MeshInstance3D = MeshInstance3D.new()
		var bm: BoxMesh = BoxMesh.new()
		bm.size = Vector3.ONE * 0.5
		mi.mesh = bm
		mi.material_override = m
		mi.position = Vector3(-1.5 + i * 0.6, 0, 0)
		_prewarm.add_child(mi)
		i += 1
