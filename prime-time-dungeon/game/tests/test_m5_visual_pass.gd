extends TestCase
## Visual pass (battle framing / HUD layout found in the screenshot matrix): the HUD reserves the bottom corners of the
## M.O.D. box (command menu / target panel left, party panels right) and its sub menus end above the box incl. its
## speaker tab (keyboard and touch); the enemy-turn shot keeps the acting enemy's whole figure in the frame; the wide
## (Rattenkönigin) command shot shows the queen below the top HUD band and she stands on her wreck's roof; the victory
## orbit ends with the party left of the results panel; the debug setup takes an encounter id (boss stills).

const SCENE: String = "res://scenes/battle/battle.tscn"
const SCENE_DIALOG: String = "res://scenes/ui/mod_dialog.tscn"
const BattleStageScript := preload("res://scenes/battle/battle_stage.gd")
const MAX_FRAMES: int = 20000
const HUD_BAND: float = 90.0            # top HUD band (LIVE pill, hype meter, AUTO / speed buttons) at 1280 × 720

var _saved_auto: bool = false
var _saved_scheme: int = 0
var _reserve: Array = []
var _saved_size: Vector2i = Vector2i.ZERO


## Headless the root is 64 × 64 (visible rect 1280 × 1280): layout / framing checks run in the 16:9 reference frame.
func before_each() -> void:
	_saved_size = tree.root.size
	tree.root.size = Vector2i(1280, 720)
	Engine.time_scale = 8.0
	_saved_auto = Game.auto_battle
	_saved_scheme = Game.input_scheme
	Game.auto_battle = false
	Game.new_game(0, "Kai", 4242)
	_reserve = []
	Events.dialog_reserve_requested.connect(_on_reserve)


func after_each() -> void:
	tree.root.size = _saved_size
	Engine.time_scale = 1.0
	Events.dialog_reserve_requested.disconnect(_on_reserve)
	Game.auto_battle = _saved_auto
	Game.set_input_scheme(_saved_scheme)
	Game.in_battle = false
	Game.clear_blocking_dialogs()
	Router.adopt(null)
	Events.overlay_mode_requested.emit(&"hidden")


func _on_reserve(mode: StringName, left: float, right: float) -> void:
	_reserve = [mode, left, right]


func _scene(enc: String, extra: Dictionary = {}) -> BattleScene:
	var s: BattleSetup = Game.make_battle_setup(enc, BattleSetup.Advantage.NORMAL, "")
	assert_not_null(s, "BattleSetup for %s" % enc)
	var params: Dictionary = {"setup": s, "speed": 4.0, "stay": true, "results_auto_sec": 0.05}
	params.merge(extra, true)
	var scene: BattleScene = (load(SCENE) as PackedScene).instantiate() as BattleScene
	scene.setup(params)
	add_to_tree(scene)
	return scene


func _wait_menu(scene: BattleScene) -> bool:
	return await wait_until(func() -> bool: return scene.hud != null and scene.hud.awaiting, MAX_FRAMES)


func _view() -> Vector2:
	return tree.root.get_visible_rect().size


# --- HUD vs. M.O.D. box -----------------------------------------------------------------------------------------------

func test_hud_reserves_the_dialog_corners_and_sub_menus_end_above_the_box() -> void:
	var d: CanvasLayer = (load(SCENE_DIALOG) as PackedScene).instantiate() as CanvasLayer
	d.call("setup", {})
	add_to_tree(d)
	var scene: BattleScene = _scene("enc_f1_a1_tutorial")
	assert_true(await _wait_menu(scene), "command menu")
	Events.overlay_mode_requested.emit(&"battle")
	scene.hud.call("_layout")
	for touch: bool in [false, true]:
		Game.set_input_scheme(Game.InputScheme.TOUCH if touch else Game.InputScheme.KEYBOARD_MOUSE)
		await wait_frames(2)
		var tag: String = "touch" if touch else "keys"
		var menu: Rect2 = (scene.hud.get("command_menu") as Control).get_global_rect()
		assert_eq(_reserve[0] if not _reserve.is_empty() else &"", &"battle", tag + ": reserve for the battle mode")
		var frame_x: float = (scene.hud.get("frame") as Control).get_global_rect().position.x
		assert_true(float(_reserve[1]) >= menu.end.x - frame_x + 8.0, "%s: left reserve covers the command menu" % tag)
		d.call("enqueue", "Ein langer Tipp der Regie, damit die Box sicher sichtbar ist und umbrechen darf.", &"mod",
			"x", true)
		scene.hud.call("_open_list", BattleCommand.Kind.ITEM)
		await wait_frames(3)
		var box: Rect2 = d.call("box_rect")
		var list: Rect2 = (scene.hud.get("action_list") as Control).get_global_rect()
		assert_gt(box.size.x, 0.0, tag + ": box shown")
		assert_true(box.position.x >= menu.end.x + 4.0, "%s: box right of the command menu (%s / %s)" % [tag,
			str(box), str(menu)])
		assert_true(list.end.y <= box.position.y - 4.0, "%s: sub menu ends above the box and its tab (%s / %s)" % [
			tag, str(list), str(box)])
		d.call("advance")
		d.call("advance")
		scene.hud.call("_open_menu", BattleCommand.Kind.ATTACK)
	scene.hud.call("_begin_targets", scene.hud.get("_actor").attack_skill, "Angriff")
	await wait_frames(1)
	var tp: Rect2 = (scene.hud.get("target_cursor").get("panel") as Control).get_global_rect()
	var fx: float = (scene.hud.get("frame") as Control).get_global_rect().position.x
	assert_true(float(_reserve[1]) >= tp.end.x - fx + 8.0, "target level: reserve covers the target panel")


# --- camera framing ---------------------------------------------------------------------------------------------------

func _projected(cam: Camera3D, p: Vector3) -> Vector2:
	return cam.unproject_position(p)


func test_enemy_turn_shot_keeps_the_acting_enemy_in_the_frame() -> void:
	var scene: BattleScene = _scene("enc_f1_a1_tutorial")
	await wait_frames(3)
	var cam: Camera3D = scene.camera
	cam.call("shot", &"enemy_turn", {"actor": "e0"})
	cam.set("_blend", 0.0)
	cam.call("_evaluate")
	var head: Vector2 = _projected(cam, scene.stage.call("anchor_pos", "e0", &"head"))
	var feet: Vector2 = _projected(cam, scene.stage.call("home", "e0"))
	var v: Vector2 = _view()
	assert_between(head.y, 0.0, v.y, "acting enemy's head inside the frame (%s)" % str(head))
	assert_between(feet.y, 0.0, v.y, "and its feet (no giant paws at the bottom edge) (%s)" % str(feet))
	var party: Vector2 = _projected(cam, scene.stage.call("party_center") + Vector3(0, 0.9, 0))
	assert_between(party.y, 0.0, v.y * 0.75, "the party beyond it in the frame")


func test_wide_command_shot_shows_the_queen_on_her_wreck() -> void:
	var scene: BattleScene = _scene("enc_f1_boss_rattenkoenigin")
	await wait_frames(3)
	var qid: String = ""
	for id: String in scene.stage.call("unit_ids"):
		if bool((scene.stage.call("info", id) as Dictionary).get("boss", false)):
			qid = id
	assert_ne(qid, "", "queen on the stage")
	assert_eq(scene.stage.call("home", qid), BattleStageScript.QUEEN_POS)
	# feet on the roof, not inside the car (wreck collision box top at x 0). The stage strips the wreck's body (no
	# physics in battle, 02_TECH §12.1), so the roof is measured on a fresh PropKit wreck placed like the stage's one.
	var wreck: Node3D = scene.stage.get_node("Wreck") as Node3D
	assert_eq(wreck.find_children("*", "CollisionObject3D", true, false).size(), 0, "stage wreck without physics body")
	var probe: Node3D = PropKit.build(&"wreck", 0)
	var shapes: Array[Node] = probe.find_children("*", "CollisionShape3D", true, false)
	assert_false(shapes.is_empty(), "PropKit wreck keeps its collision box (prop contract)")
	if shapes.is_empty():
		probe.free()
		return
	var cs: CollisionShape3D = shapes[0] as CollisionShape3D
	var local: Transform3D = cs.transform
	var up: Node = cs.get_parent()
	while up != probe:
		local = (up as Node3D).transform * local
		up = up.get_parent()
	var top: Vector3 = wreck.global_transform * local * Vector3(0, (cs.shape as BoxShape3D).size.y * 0.5, 0)
	probe.free()
	assert_true(BattleStageScript.QUEEN_POS.y >= top.y, "queen's feet above the wreck body (%.2f / %.2f)" % [
		BattleStageScript.QUEEN_POS.y, top.y])
	var cam: Camera3D = scene.camera
	cam.call("shot", &"command", {"actor": "p0"})
	cam.set("_blend", 0.0)
	cam.call("_evaluate")
	var head: Vector2 = _projected(cam, scene.stage.call("anchor_pos", qid, &"head"))
	assert_between(head.y, HUD_BAND, _view().y * 0.6, "queen's head below the top HUD band (%s)" % str(head))


func test_victory_orbit_ends_with_the_party_left_of_the_results_panel() -> void:
	var scene: BattleScene = _scene("enc_f1_a1_tutorial")
	await wait_frames(3)
	var cam: Camera3D = scene.camera
	cam.call("shot", &"victory")
	cam.set("_blend", 0.0)
	cam.set("_t", 0.0)
	cam.call("_evaluate")
	var pc: Vector3 = scene.stage.call("party_center") + Vector3(0, 0.9, 0)
	assert_almost(_projected(cam, pc).x, _view().x * 0.5, 4.0, "orbit starts centred on the party")
	cam.set("_t", 3.0)
	cam.call("_evaluate")
	var end: Vector2 = _projected(cam, pc)
	assert_lt(end.x, _view().x * 0.4, "orbit end: party left of the results panel (%s)" % str(end))


func test_debug_setup_takes_an_encounter_id() -> void:
	var s: BattleSetup = BattleScene.make_debug_setup("enc_f1_boss_hausmeister")
	assert_not_null(s)
	if s != null:
		assert_eq(s.encounter_id, "enc_f1_boss_hausmeister", "boss still from the debug setup")
		assert_true(s.is_boss)
	var d: BattleSetup = BattleScene.make_debug_setup()
	assert_not_null(d)
	if d != null:
		assert_false(d.is_boss, "default: first non-boss encounter")
	Game.in_battle = false
