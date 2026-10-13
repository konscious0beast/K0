extends Node
## Main scene (02_TECH §1.6, §11.4; GDD §14.1): reads the user args (--autoplay[=full], --seed=<int>,
## --goto=explore|safe_room|title|credits|lobby|game_over; combats start in the world, 07 §2), applies the settings,
## adds GlobalUi once under root (deferred) and — with --autoplay — the smoke driver (max_fps 60, time_scale 5,
## read-only saves, fast text, ephemeral), with --autoplay=full the full Floor-1 bot instead (fullrun.gd: time_scale
## FullRun TIME_SCALE, real saves in its own directory). Shows the "NOVA SYNDIKAT präsentiert" card for 2 s (any input
## skips) while pre-warming the shader materials behind it (03_ART §3.10), then routes to the title (or the --goto
## target) — unless the content pack cannot start (11-P1: DB.pack_error), then an error card stays instead.

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const TitleFlow := preload("res://scenes/title/title_flow.gd")
## Loaded only with --autoplay[=full]: both drivers type-check against every screen class, so preloading them here
## compiled the whole game before the first frame (02_TECH §12.1 "Start", §13.2 rule 6).
const AUTOPLAY_SCRIPT: String = "res://scenes/boot/autoplay.gd"
const FULLRUN_SCRIPT: String = "res://scenes/boot/fullrun.gd"
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
		Engine.max_fps = 60
		var ap: Node = null
		if str(args.get("autoplay_mode", "")) == "full":
			# Full Floor-1 bot (§11.4.1): real saves in its own directory (fullrun.gd prepare_saves in _ready).
			var fr: GDScript = load(FULLRUN_SCRIPT) as GDScript
			Engine.time_scale = float(fr.get_script_constant_map().get("TIME_SCALE", 5.0))
			ap = fr.new() as Node
			ap.name = "FullRun"
		else:
			Save.read_only = true
			Engine.time_scale = 5.0
			ap = (load(AUTOPLAY_SCRIPT) as GDScript).new() as Node
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


## Leaves the boot card: --goto target or the title (debug builds: --season starts a season, _season_boot). A content
## pack that cannot start (11-P1) keeps the boot card as an error card instead (_pack_error_card).
func route() -> void:
	if _routed:
		return
	_routed = true
	if _pack_error_card():                      # Inhaltspakete (11-P1, 11 §3.5 Nr. 5)
		return
	if _season_boot():                          # Staffeln (09, ST1-B)
		return
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
			# battle:<enc_id> (the CTB battle scene) left with R5b part 2b: combats start in the world (explore)
			push_warning("[Boot] unknown --goto target '%s' → title" % target)
			Router.goto(Router.SCENE_TITLE)


## The dev state of a --goto target (seed 1 or --seed).
func _ensure_dev_state() -> void:
	var s: int = int(args.get("seed", -1))
	Game.ensure_state(s if s >= 0 else 1)


# --- Inhaltspakete (11-P1, 11 §3.5 Nr. 5, §3.9): the error card of a content pack that cannot start -------------------

## Headline per DB.pack_error (the code itself stays data: it is shown under the headline).
const PACK_ERROR_TEXTS: Dictionary = {
	"pack_ambiguous": "Mehr als ein Inhaltspaket ist aktiviert.",
	"pack_missing": "Das Inhaltspaket wurde nicht gefunden.",
	"pack_engine": "Das Inhaltspaket passt nicht zu dieser Spielversion.",
	"pack_invalid": "Die Daten des Inhaltspakets sind fehlerhaft.",
}
const PACK_ERROR_LINES: int = 5


## A build whose content pack is ambiguous, missing, incompatible or invalid never starts with the base data (11 §3.5
## Nr. 5): the boot card becomes an error card — "Inhaltspaket fehlerhaft", the code and the first five messages
## (DB.pack_messages) — and stays; there is no route. false = no pack error.
func _pack_error_card() -> bool:
	var code: String = DB.pack_error
	if code == "":
		return false
	push_warning("[Boot] content pack error %s: the game does not start (11 §3.5)" % code)
	var card: CanvasLayer = CanvasLayer.new()
	card.name = "PackErrorCard"
	card.layer = 96                             # above the boot card (95)
	add_child(card)
	var root: Control = Control.new()
	UiUtil.full_rect(root)
	UiUtil.apply_theme(root)
	card.add_child(root)
	var bg: ColorRect = ColorRect.new()
	UiUtil.full_rect(bg)
	bg.color = UiUtil.C_INK
	root.add_child(bg)
	var center: CenterContainer = CenterContainer.new()
	UiUtil.full_rect(center)
	root.add_child(center)
	var col: VBoxContainer = UiUtil.vbox(10)
	col.custom_minimum_size = Vector2(960, 0)
	center.add_child(col)
	col.add_child(UiUtil.label("INHALTSPAKET FEHLERHAFT", &"LabelTitle", 48, UiTheme.C_DANGER))
	col.add_child(UiUtil.label("%s (%s)" % [str(PACK_ERROR_TEXTS.get(code, "")), code], &"", 24, UiTheme.C_ACCENT_2))
	var lines: PackedStringArray = DB.pack_messages
	for i in mini(PACK_ERROR_LINES, lines.size()):
		var l: Label = UiUtil.label(UiUtil.glyph_safe(lines[i]), &"LabelSmall", 16, UiTheme.C_TEXT_DIM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(l)
	if lines.size() > PACK_ERROR_LINES:
		col.add_child(UiUtil.label("… und %d weitere Meldungen im Log." % (lines.size() - PACK_ERROR_LINES),
			&"LabelSmall", 16, UiTheme.C_TEXT_DIM))
	col.add_child(UiUtil.label("Das Spiel startet nicht mit den Grunddaten.", &"", 20))
	return true


# --- Staffeln (09, ST1-B): the debug start of a season ----------------------------------------------------------------

## Debug builds only (09 §11.1: until "Sendung starten" becomes the default, seasons exist in debug builds and the
## harness only): --season=<ssn id> starts a new season (Game.start_season) and goes straight into the exploration of
## floor 1 — no title, casting or intro. Options (season_args): --tempo=calendar|binge, --mode=net|no_net (Ohne Netz
## without the unlock), --speed=<n> (Zeitraffer: season seconds per wall second, 1–10080), --slot=<1..3> (default: the
## first empty slot, else 0 = never saved), --hero=kai|mopsula, --air=HH:MM, --seed=<int>, --floor=<n> (ST1-C: down
## the stairs to floor n at once — recorded "descend" / "floor" pairs, Game.season_debug_descend; the staircase rule
## holds: Am Stück every floor, the calendar floors 1–3 at the start). true = started and routed.
func _season_boot() -> bool:
	var o: Dictionary = season_args(OS.get_cmdline_user_args())
	if o.is_empty():
		return false
	if not OS.is_debug_build():
		push_warning("[Boot] --season is a debug option (09 §11.1): ignored")
		return false
	var slot: int = int(o.get("slot", -1))
	if slot > Save.SLOT_COUNT:
		slot = 0
	if slot < 0:
		slot = 0
		for s in range(1, Save.SLOT_COUNT + 1):
			if not Save.has_save(s):
				slot = s
				break
	var opts: Dictionary = {"tempo": str(o.get("tempo", "calendar")), "mode": str(o.get("mode", "net")),
		"unlock": true, "seed": int(args.get("seed", -1))}
	if o.has("air"):
		opts["air_time"] = str(o["air"])
	if not Game.start_season(slot, str(o["season"]), opts, str(o.get("hero", "kai"))):
		push_warning("[Boot] --season=%s could not start → title" % str(o["season"]))
		return false
	Game.season_speed = clampi(int(o.get("speed", 1)), 1, Game.SEASON_SPEED_MAX)
	while Game.state.floor_run.index < int(o.get("floor", 1)):     # ST1-C: --floor=<n>
		if not Game.season_debug_descend():
			push_warning("[Boot] --floor=%d: the stairs stay closed below floor %d" % [int(o["floor"]),
				Game.state.floor_run.index])
			break
	Router.goto(Router.SCENE_EXPLORATION, {"spawn": &"start"})
	return true


## The season arguments of the user args: {"season", "tempo", "mode", "speed", "slot", "hero", "air", "floor"} — {}
## without --season=<id>; malformed values are left out (the defaults apply).
static func season_args(user_args: PackedStringArray) -> Dictionary:
	var out: Dictionary = {}
	for a: String in user_args:
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		if not a.begins_with("--") or kv.size() != 2 or kv[1] == "":
			continue
		match kv[0]:
			"season", "air":
				out[kv[0]] = kv[1]
			"tempo":
				if SeasonState.TEMPOS.has(kv[1]):
					out["tempo"] = kv[1]
			"mode":
				if SeasonState.MODES.has(kv[1]):
					out["mode"] = kv[1]
			"hero":
				if HeroRules.HEROES.has(kv[1]):
					out["hero"] = kv[1]
			"speed", "slot", "floor":
				if kv[1].is_valid_int():
					out[kv[0]] = kv[1].to_int()
	return out if out.has("season") else {}


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
	var sub: Label = UiUtil.label(Tx.t("präsentiert"), &"", 26, UiTheme.C_ACCENT_2)   # 11 §3.14: a pack may override it
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
