class_name BattleScene extends Node3D
## Battle screen (02_TECH §5.7, §9.5): builds the stage (arena, rigs), the FF10-like camera, the HUD (CanvasLayer 5)
## and the results screen, then runs the BattleController. Screen contract: setup(params) only stores the params;
## the work happens in _ready(). Params: {"setup": BattleSetup} (Router.start_battle); missing → Game.ensure_state()
## and a debug setup with the first non-boss encounter of the current floor (seed 1); {"capture": true} → stops at the
## first command menu (§9.5; enemy turns before it play at speed ≥ 3). Optional (tests/tools): "speed" (BattlePlayer
## speed override), "results_auto_sec" (results continue on their own), "stay" (no Router.end_battle at the end),
## "capture_turns" (party turns AutoPolicy plays before a capture stops, default 0), "encounter" (encounter id of the
## debug setup instead of the first non-boss one, e.g. a boss battle still).

const BattleStage := preload("res://scenes/battle/battle_stage.gd")
const BattleCamera := preload("res://scenes/battle/battle_camera.gd")
const BattlePlayer := preload("res://scenes/battle/battle_player.gd")
const BattleController := preload("res://scenes/battle/battle_controller.gd")
const BattleHud := preload("res://scenes/battle/ui/battle_hud.gd")
const BattleResults := preload("res://scenes/battle/ui/battle_results.gd")
const HUD_SCENE: String = "res://scenes/battle/ui/battle_hud.tscn"
const RESULTS_SCENE: String = "res://scenes/battle/ui/battle_results.tscn"
const AUTOPLAY_SPEED: float = 4.0
const CAPTURE_AUTO_TURNS: int = 0
const DEBUG_SEED: int = 1

var battle_setup: BattleSetup = null
var stage: BattleStage = null
var camera: BattleCamera = null
var hud: BattleHud = null
var results: BattleResults = null
var player: BattlePlayer = null
var controller: BattleController = null
var capture: bool = false
var debug_setup_used: bool = false
## >= 0 overrides the playback speed (tests: 4.0); otherwise Settings battle_speed, autoplay 4.0.
var speed_override: float = -1.0

var _params: Dictionary = {}


## {"setup": BattleSetup}; missing → Game.ensure_state() + debug setup; {"capture": true} → stop at first command menu.
func setup(params: Dictionary) -> void:
	_params = params


func _ready() -> void:
	Game.ensure_state()
	capture = bool(_params.get("capture", false))
	speed_override = float(_params.get("speed", -1.0))
	var s: Variant = _params.get("setup", null)
	battle_setup = s as BattleSetup if s is BattleSetup else null
	if battle_setup == null:
		battle_setup = make_debug_setup(str(_params.get("encounter", "")))
		debug_setup_used = true
	if battle_setup == null:
		push_error("[BattleScene] no encounter for a debug battle (res://data/floors.json)")
		return
	var quality: StringName = Game.settings.quality if Game.settings != null else &"high"
	stage = BattleStage.new()
	stage.name = "Stage"
	add_child(stage)
	stage.build(battle_setup, quality)
	camera = BattleCamera.new()
	camera.name = "Camera"
	camera.stage = stage
	camera.wide = battle_setup.enemy_ids.has(BattleStage.QUEEN_ID)
	add_child(camera)
	camera.shot(&"establishing")
	hud = (load(HUD_SCENE) as PackedScene).instantiate() as BattleHud
	add_child(hud)
	hud.setup_hud(stage, camera, battle_setup)
	results = (load(RESULTS_SCENE) as PackedScene).instantiate() as BattleResults
	add_child(results)
	results.auto_continue_sec = 1.0 if Game.autoplay else float(_params.get("results_auto_sec", -1.0))
	player = BattlePlayer.new()
	player.name = "Player"
	player.stage = stage
	player.camera = camera
	player.hud = hud
	player.setup = battle_setup
	add_child(player)
	controller = BattleController.new()
	controller.name = "Controller"
	controller.bind(player, hud, results)
	controller.exit_on_end = not bool(_params.get("stay", false)) and not capture
	if capture:
		controller.force_manual = true
		controller.auto_turns = int(_params.get("capture_turns", CAPTURE_AUTO_TURNS))
	add_child(controller)
	_update_speed()
	Events.overlay_mode_requested.emit(&"battle")
	Sfx.music(music_id(battle_setup), 0.4)
	_start.call_deferred()


func _start() -> void:
	if controller == null or not is_inside_tree():
		return
	controller.run(battle_setup)


func _process(_delta: float) -> void:
	_update_speed()


func _exit_tree() -> void:
	# A battle torn down before its end (tests, debug) must not leave Game in battle mode nor Show with a running
	# battle context (thresholds, gift queue, ShowRules) that the next battle or an exploration gift would see.
	if controller != null and not controller.done and controller.result == null:
		Game.in_battle = false
		Show.abort_battle()


func _update_speed() -> void:
	if player == null:
		return
	var sp: float = Game.settings.battle_speed if Game.settings != null else 1.0
	if Game.autoplay:
		sp = AUTOPLAY_SPEED
	if speed_override >= 0.0:
		sp = speed_override
	if capture:
		sp = maxf(sp, 3.0)
	player.speed = sp
	if camera != null:
		camera.speed = sp


## Debug setup (02_TECH §9.5): first non-boss encounter of the current floor (or `encounter_id` if the current floor
## has it), seed 1.
static func make_debug_setup(encounter_id: String = "") -> BattleSetup:
	if Game.state == null:
		return null
	var fdef: FloorDef = Game.floor_def()
	if fdef == null:
		fdef = DB.floor_def(1)
	if fdef == null:
		return null
	var enc_id: String = ""
	for enc: EncounterDef in fdef.encounters:
		if encounter_id != "" and enc.id == encounter_id:
			enc_id = enc.id
			break
		if not enc.boss and enc_id == "" and encounter_id == "":
			enc_id = enc.id
	if enc_id == "" and encounter_id != "":
		push_warning("[BattleScene] encounter '%s' not on floor %d → first non-boss encounter" % [encounter_id,
			fdef.index])
		for enc2: EncounterDef in fdef.encounters:
			if not enc2.boss:
				enc_id = enc2.id
				break
	if enc_id == "":
		return null
	var s: BattleSetup = BattleBridge.make_setup(Game.state, DB.data, enc_id, BattleSetup.Advantage.NORMAL, "",
		DEBUG_SEED)
	if s != null:
		s.auto_battle = Game.auto_battle
		Game.in_battle = true
	return s


## Encounter music ("" → battle / boss).
static func music_id(s: BattleSetup) -> StringName:
	if s != null and DB.has_id("encounters", s.encounter_id):
		var m: String = DB.encounter(s.encounter_id).music
		if m != "":
			return StringName(m)
	return &"boss" if s != null and s.is_boss else &"battle"
