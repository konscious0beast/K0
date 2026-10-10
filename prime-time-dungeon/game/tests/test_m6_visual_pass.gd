extends TestCase
## Visual pass (UI layout contracts found in the screenshot matrix): the M.O.D. box centres between the bottom corners a
## screen reserves (Events.dialog_reserve_requested) and grows upwards with its tab on top; the exploration prompt sits
## above its world anchor inside the band between top HUD and M.O.D. box; the safe room hides its back-wall name sign
## and its menu column under modals; the opened lootbox shrinks away during the reveal; the battle results scene has a
## capture still; the capture recipes (tests/capture_recipes.gd, 02_TECH §11.3) cover the screenshot matrix.

const ModDialogScript := preload("res://scenes/ui/mod_dialog.gd")
const SCENE_DIALOG: String = "res://scenes/ui/mod_dialog.tscn"
const SCENE_HUD: String = "res://scenes/ui/exploration_hud.tscn"
const SCENE_SAFE: String = "res://scenes/safe_room/safe_room.tscn"
const SCENE_LOOTBOX: String = "res://scenes/safe_room/lootbox_opening.tscn"
const SCENE_RESULTS: String = "res://scenes/battle/ui/battle_results.tscn"
const RECIPES: String = "res://tests/capture_recipes.gd"
const LONG_LINE: String = "Ein sehr langer Satz der M.O.D., der in einer schmalen Box ganz sicher auf mehr als zwei " \
	+ "Zeilen umbrechen muss, damit die Box nach oben wachsen muss."

var _saved_fast_text: bool = false
var _saved_size: Vector2i = Vector2i.ZERO


## Headless the root is 64 × 64 (visible rect 1280 × 1280): layout / framing checks run in the 16:9 reference frame.
func before_each() -> void:
	_saved_size = tree.root.size
	tree.root.size = Vector2i(1280, 720)
	Engine.time_scale = 8.0
	tree.paused = false
	Game.ensure_state()
	_saved_fast_text = Game.fast_text
	Game.fast_text = true


func after_each() -> void:
	tree.root.size = _saved_size
	Engine.time_scale = 1.0
	Game.fast_text = _saved_fast_text
	Game.clear_blocking_dialogs()
	tree.paused = false
	Events.dialog_reserve_requested.emit(&"battle", 0.0, 0.0)
	Events.overlay_mode_requested.emit(&"hidden")


func _dialog() -> CanvasLayer:
	var d: CanvasLayer = (load(SCENE_DIALOG) as PackedScene).instantiate() as CanvasLayer
	d.call("setup", {})
	add_to_tree(d)
	return d


func _view() -> Vector2:
	return tree.root.get_visible_rect().size


# --- M.O.D. box -------------------------------------------------------------------------------------------------------

func test_dialog_box_centres_between_the_reserved_corners() -> void:
	var d: CanvasLayer = _dialog()
	await wait_frames(1)
	Events.overlay_mode_requested.emit(&"battle")
	Events.dialog_reserve_requested.emit(&"battle", 300.0, 258.0)
	d.call("enqueue", "Kurz und mittig.", &"mod", "x", false)
	await wait_frames(3)
	var r: Rect2 = d.call("box_rect")
	var w: float = _view().x
	assert_gt(r.size.x, 0.0, "box laid out")
	assert_true(r.position.x >= 24.0 + 300.0 - 0.5, "box right of the reserved left corner (%s)" % str(r))
	assert_true(r.end.x <= w - 24.0 - 258.0 + 0.5, "box left of the reserved right corner (%s)" % str(r))
	var mid: float = (24.0 + 300.0 + w - 24.0 - 258.0) * 0.5
	assert_almost((r.position.x + r.end.x) * 0.5, mid, 2.0, "centred in the free span")
	Events.overlay_mode_requested.emit(&"explore")
	await wait_frames(2)
	var r2: Rect2 = d.call("box_rect")
	assert_almost(r2.size.x, ModDialogScript.BOX_SIZE.x, 0.5, "other modes: full width (battle reserve not applied)")
	assert_almost((r2.position.x + r2.end.x) * 0.5, w * 0.5, 2.0, "other modes: bottom centre")
	d.call("advance")


func test_narrow_dialog_box_grows_upwards_with_its_tab_on_top() -> void:
	var d: CanvasLayer = _dialog()
	await wait_frames(1)
	Events.overlay_mode_requested.emit(&"battle")
	var w: float = _view().x - 48.0
	Events.dialog_reserve_requested.emit(&"battle", (w - ModDialogScript.MIN_BOX_W) * 0.5,
		(w - ModDialogScript.MIN_BOX_W) * 0.5)
	d.call("enqueue", LONG_LINE, &"mod", "x", true)
	await wait_frames(4)
	var box: PanelContainer = d.get("_box") as PanelContainer
	var tab: PanelContainer = d.get("_speaker_panel") as PanelContainer
	assert_almost(box.size.x, ModDialogScript.MIN_BOX_W, 0.5, "never narrower than MIN_BOX_W")
	assert_gt(box.size.y, ModDialogScript.BOX_SIZE.y + 1.0, "long line in a narrow box: taller box")
	var bottom: float = box.get_global_rect().end.y
	assert_almost(bottom, _view().y - 24.0 - ModDialogScript.BOX_BOTTOM, 1.0, "bottom edge stays above the ticker")
	assert_almost(tab.get_global_rect().end.y, box.get_global_rect().position.y + ModDialogScript.TAB_SIZE.y
		- ModDialogScript.TAB_INSET.y, 1.0, "speaker tab follows the taller box")
	d.call("advance")
	d.call("advance")


func test_global_ui_created_after_a_screen_takes_its_overlay_mode() -> void:
	var d: CanvasLayer = _dialog()
	await wait_frames(1)
	d.call("set_overlay_mode", &"battle")
	Events.dialog_reserve_requested.emit(&"battle", 400.0, 260.0)
	assert_eq(d.call("bottom_reserve"), Vector2(400.0, 260.0), "reserve of the active mode")
	d.call("set_overlay_mode", &"explore")
	assert_eq(d.call("bottom_reserve"), Vector2.ZERO, "no reserve in other modes")


# --- exploration prompt -----------------------------------------------------------------------------------------------

func test_prompt_sits_above_its_anchor_inside_the_band() -> void:
	var hud: CanvasLayer = (load(SCENE_HUD) as PackedScene).instantiate() as CanvasLayer
	add_to_tree(hud)
	await wait_frames(2)
	hud.call("set_prompt", "Kiste öffnen")
	hud.call("set_prompt_anchor", Vector2(640, 450))
	await wait_frames(2)
	var r: Rect2 = hud.call("prompt_rect")
	assert_gt(r.size.x, 0.0, "prompt shown")
	assert_true(r.end.y <= 450.0 - 8.0, "prompt above the anchor, never over the object (%s)" % str(r))
	assert_almost(r.get_center().x, 640.0, 1.5, "centred on the anchor")
	hud.call("set_prompt_anchor", Vector2(640, 40))
	await wait_frames(1)
	r = hud.call("prompt_rect")
	assert_true(r.position.y >= 24.0 + 112.0 - 1.0, "kept below the timer / hype band (%s)" % str(r))
	hud.call("set_prompt_anchor", Vector2(2.0, 700))
	await wait_frames(1)
	r = hud.call("prompt_rect")
	assert_true(r.position.x >= 24.0, "kept inside the safe frame (%s)" % str(r))
	assert_true(r.end.y <= _view().y - 24.0 - 190.0 + 1.0, "kept above the M.O.D. box (%s)" % str(r))
	hud.call("set_prompt_anchor", Vector2.INF)
	await wait_frames(1)
	r = hud.call("prompt_rect")
	assert_almost(r.get_center().x, _view().x * 0.5, 1.5, "no anchor: default slot bottom centre")
	hud.call("set_prompt", "")
	assert_eq(hud.call("prompt_rect"), Rect2(), "hidden prompt has no rect")


# --- safe room / lootbox / results ------------------------------------------------------------------------------------

func test_safe_room_hides_the_name_sign_and_the_menu_under_modals() -> void:
	var room: Node3D = (load(SCENE_SAFE) as PackedScene).instantiate() as Node3D
	room.call("setup", {})
	add_to_tree(room)
	var built: bool = await wait_until(func() -> bool: return room.get("_ui") != null, 300)
	assert_true(built, "safe room built")
	var sign: Node3D = room.find_child(EnvKit.SAFE_TITLE_SIGN, true, false) as Node3D
	assert_not_null(sign, "set has the name sign")
	if sign != null:
		assert_false(sign.visible, "the UI header names the room: no duplicate sign behind the menu")
	var ui: CanvasLayer = room.get("_ui") as CanvasLayer
	assert_true(ui.visible, "menu shown")
	var layer: Node = room.call("open_vending")
	await wait_frames(2)
	assert_false(ui.visible, "menu column hidden while the vending machine covers the room")
	layer.call("close")
	var back: bool = await wait_until(func() -> bool: return ui.visible, 300)
	assert_true(back, "menu back after the modal closed")


func test_lootbox_reveal_shrinks_the_opened_box_away() -> void:
	var lb: CanvasLayer = (load(SCENE_LOOTBOX) as PackedScene).instantiate() as CanvasLayer
	lb.call("setup", {"capture": true})
	add_to_tree(lb)
	await wait_frames(3)
	var pivot: Node3D = lb.get("_box_pivot") as Node3D
	assert_eq(lb.get("state"), &"done", "demo still: revealed")
	assert_lt(pivot.scale.x, 0.05, "the opened box (and its upright lid) is gone behind the cards")
	lb.call("next_box")
	await wait_frames(2)
	assert_almost((lb.get("_box_pivot") as Node3D).scale.x, 1.0, 0.001, "back to selection: box shown again")


func test_battle_results_scene_has_a_capture_still() -> void:
	var res: CanvasLayer = (load(SCENE_RESULTS) as PackedScene).instantiate() as CanvasLayer
	res.call("setup", {"capture": true})
	add_to_tree(res)
	var shown: bool = await wait_until(func() -> bool: return bool(res.get("shown")), 120)
	assert_true(shown, "standalone capture shows a sample victory")
	res.call("_close")


func test_capture_recipes_cover_the_screenshot_matrix() -> void:
	var script: GDScript = load(RECIPES) as GDScript
	assert_true(script != null and script.can_instantiate(), "recipes load")
	if script == null:
		return
	var r: Node = script.new() as Node
	for m: String in ["_r_explore", "_r_prompt", "_r_bigmap", "_r_pause", "_r_battle_menu", "_r_battle_skills",
			"_r_battle_target", "_r_battle_damage", "_r_battle_enemy_turn", "_r_boss_intro", "_r_boss_phase",
			"_r_battle_gift", "_r_battle_victory", "_r_battle_results", "_r_safe_vending", "_r_safe_equipment",
			"_r_safe_lootbox", "_r_safe_lootbox_open", "_r_safe_mopsula",
			"_r_bark", "_r_hero_mopsula", "_r_battle_partner_auto", "_r_safe_hero_switch"]:   # 06 package A
		assert_true(r.has_method(m), "recipe " + m)
	var ok: Variant = await r.call("run", "no_such_recipe", r)
	assert_false(bool(ok), "unknown recipe → false")
	r.free()
