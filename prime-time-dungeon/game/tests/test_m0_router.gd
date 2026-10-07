extends TestCase
## Router (02_TECH §3.7, §9.2): empty stack / adopt, push/pop with suspend/resume, queueing, goto freeing, failure
## handling, battle / safe room / game over helpers.
## Generic operations push the fixture screen tests/fixtures/router/router_screen.tscn, so this test never depends on
## what other modules put into their screens. The helpers have fixed targets (M5/M6 scenes): those cases only run while
## the target's root script is still the M0 stub and skip afterwards (then covered by autoplay/integration tests).
## Uses Transition.NONE where possible to stay fast.

const MAX_FRAMES: int = 240
const FIXTURE: String = "res://tests/fixtures/router/router_screen.tscn"
const STUB_HEADER: String = "# STUB(M0)"
## Missing scene outside res:// on purpose: the Router's push_error line then does not match check.sh's ERR_RE.
const MISSING: String = "user://router_test_missing_scene.tscn"


class _Screen extends Node:
	var calls: Array[String] = []
	var params: Dictionary = {}
	var payloads: Array[Dictionary] = []

	func setup(p: Dictionary) -> void:
		params = p
		calls.append("setup")

	func on_suspend() -> void:
		calls.append("suspend")

	func on_resume(payload: Dictionary) -> void:
		payloads.append(payload)
		calls.append("resume")


func after_each() -> void:
	# Leave the Router empty: a goto frees every stack screen (attached or detached), then the fixture top is freed.
	if Router.stack_size() > 0 or Router.busy:
		Router.goto(FIXTURE, {}, Router.Transition.NONE)
		await _idle()
	var cur: Node = Router.current
	if cur != null and is_instance_valid(cur):
		if cur.get_parent() != null:
			cur.get_parent().remove_child(cur)
		cur.free()
	Router.adopt(null)
	Game.timer_running = false


func _idle() -> bool:
	return await wait_until(func() -> bool: return not Router.busy, MAX_FRAMES)


func _screen() -> _Screen:
	var s: _Screen = _Screen.new()
	s.name = "TestScreen"
	add_to_tree(s)
	return s


func _is_fixture(n: Node) -> bool:
	return n != null and n.scene_file_path == FIXTURE


## True while the root script of `scene_path` is still the M0 stub; otherwise marks the test skipped.
func _require_stub(scene_path: String) -> bool:
	var script_path: String = _root_script_path(scene_path)
	if script_path != "":
		var f: FileAccess = FileAccess.open(script_path, FileAccess.READ)
		if f != null and f.get_line().begins_with(STUB_HEADER):
			return true
	skip("%s is no longer the M0 stub (real screen: covered by autoplay/integration)" % scene_path.get_file())
	return false


static func _root_script_path(scene_path: String) -> String:
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		return ""
	var st: SceneState = packed.get_state()
	for i in st.get_node_property_count(0):
		if st.get_node_property_name(0, i) == &"script":
			var scr: Script = st.get_node_property_value(0, i) as Script
			return scr.resource_path if scr != null else ""
	return ""


func test_adopt_sets_stack_and_current() -> void:
	Router.adopt(null)
	assert_eq(Router.stack_size(), 0)
	assert_null(Router.current)
	var s: _Screen = _screen()
	assert_eq(Router.current, s, "add_to_tree adopts screen scenes")
	assert_eq(Router.stack_size(), 1)
	Router.adopt(null)
	assert_eq(Router.stack_size(), 0)


func test_push_and_pop_suspend_resume() -> void:
	var s: _Screen = _screen()
	Game.timer_running = true
	Router.push(FIXTURE, {"a": 1}, Router.Transition.NONE)
	assert_true(Router.busy, "busy right after the call")
	assert_true(await _idle())
	assert_false(Game.timer_running, "push resets timer_running")
	assert_eq(Router.stack_size(), 2)
	var pushed: Node = Router.current
	assert_true(_is_fixture(pushed), "fixture on top")
	if _is_fixture(pushed):
		assert_eq(pushed.get("params"), {"a": 1}, "setup(params) before add_child")
		assert_eq(pushed.get("calls"), ["setup"])
	assert_false(s.is_inside_tree(), "suspended screen is detached, not freed")
	assert_true(is_instance_valid(s))
	assert_eq(s.calls, ["suspend"])
	Router.pop({"x": 5}, Router.Transition.NONE)
	assert_true(await _idle())
	assert_eq(Router.stack_size(), 1)
	assert_eq(Router.current, s)
	assert_true(s.is_inside_tree(), "re-attached")
	assert_eq(s.calls, ["suspend", "resume"])
	assert_eq(s.payloads, [{"x": 5}])
	await wait_frames(1)
	assert_false(is_instance_valid(pushed), "popped screen freed")


func test_calls_while_busy_are_queued_in_order() -> void:
	var s: _Screen = _screen()
	var changes: Array[String] = []
	var on_change: Callable = func(path: String) -> void: changes.append(path)
	Events.scene_changed.connect(on_change)
	Router.push(FIXTURE, {}, Router.Transition.NONE)
	Router.pop({"queued": true}, Router.Transition.NONE)
	Router.push(FIXTURE, {}, Router.Transition.NONE)
	assert_true(await _idle())
	Events.scene_changed.disconnect(on_change)
	assert_eq(changes, [FIXTURE, "", FIXTURE], "three ops, none dropped")
	assert_eq(Router.stack_size(), 2)
	assert_eq(s.payloads, [{"queued": true}])
	assert_eq(s.calls, ["suspend", "resume", "suspend"])


func test_goto_frees_whole_stack() -> void:
	var s: _Screen = _screen()
	Router.push(FIXTURE, {}, Router.Transition.NONE)
	assert_true(await _idle())
	var first: Node = Router.current
	Router.goto(FIXTURE, {"summary": {"floor": 1}}, Router.Transition.NONE)
	assert_true(await _idle())
	await wait_frames(1)
	assert_false(is_instance_valid(s), "detached stack screen freed")
	assert_false(is_instance_valid(first), "top screen freed")
	assert_eq(Router.stack_size(), 1)
	assert_true(_is_fixture(Router.current))
	if _is_fixture(Router.current):
		assert_eq(Router.current.get("params"), {"summary": {"floor": 1}}, "setup(params) before add_child")


func test_await_returns_after_transition() -> void:
	_screen()
	await Router.push(FIXTURE, {}, Router.Transition.FADE)
	assert_false(Router.busy)
	assert_true(_is_fixture(Router.current))
	await Router.pop({}, Router.Transition.FADE)
	assert_false(Router.busy)
	assert_true(Router.current is _Screen)


func test_push_failure_keeps_old_screen() -> void:
	# Prints one expected "ERROR: [Router] scene not found: user://…" line.
	var s: _Screen = _screen()
	Router.push(MISSING, {}, Router.Transition.NONE)
	assert_true(await _idle())
	assert_eq(Router.current, s, "old screen stays current")
	assert_true(s.is_inside_tree(), "old screen stays attached")
	assert_eq(Router.stack_size(), 1)
	assert_eq(s.calls, ["suspend", "resume"], "suspend is undone by on_resume({})")
	assert_eq(s.payloads, [{}])


func test_goto_failure_falls_back_to_title() -> void:
	if not _require_stub(Router.SCENE_TITLE):
		return
	# Prints one expected "ERROR: [Router] scene not found: user://…" line (+ a warning).
	_screen()
	Router.goto(MISSING, {}, Router.Transition.NONE)
	assert_true(await _idle())
	assert_true(Router.current is TitleScreen, "title instead of an empty tree")
	assert_eq(Router.stack_size(), 1)


func test_pop_with_empty_stack_goes_to_title() -> void:
	if not _require_stub(Router.SCENE_TITLE):
		return
	Router.adopt(null)
	Router.pop({}, Router.Transition.NONE)
	assert_true(await _idle())
	assert_true(Router.current is TitleScreen)
	assert_eq(Router.stack_size(), 1)


func test_battle_helpers() -> void:
	if not _require_stub(Router.SCENE_BATTLE):
		return
	var s: _Screen = _screen()
	var setup: BattleSetup = BattleSetup.new()
	Router.start_battle(setup)
	assert_true(await _idle())
	assert_true(Router.current is BattleScene, "start_battle pushes the battle scene (SWIRL → FADE headless)")
	assert_eq(Router.current.get("_params"), {"setup": setup})
	var result: BattleResult = BattleResult.new()
	result.outcome = BattleResult.Outcome.VICTORY
	Router.end_battle(result)
	assert_true(await _idle())
	assert_eq(Router.current, s)
	assert_eq(s.payloads, [{"battle_result": result}])


func test_safe_room_helpers() -> void:
	if not _require_stub(Router.SCENE_SAFE_ROOM):
		return
	var s: _Screen = _screen()
	Router.enter_safe_room("sr_kiosk")
	assert_true(await _idle())
	assert_true(Router.current is SafeRoomScene)
	assert_eq(Router.current.get("_params"), {"safe_room_id": "sr_kiosk"})
	Router.exit_safe_room()
	assert_true(await _idle())
	assert_eq(Router.current, s)
	assert_eq(s.payloads, [{"from_safe_room": "sr_kiosk"}])


func test_defeat_goes_to_game_over() -> void:
	if not _require_stub(Router.SCENE_GAME_OVER):
		return
	_screen()
	var result: BattleResult = BattleResult.new()
	result.outcome = BattleResult.Outcome.DEFEAT
	Router.end_battle(result)
	assert_true(await _idle())
	assert_eq(Router.current.scene_file_path, Router.SCENE_GAME_OVER)
	assert_eq(Router.current.get("_params"), {"reason": &"defeat"})
	assert_eq(Router.stack_size(), 1)


func test_theme_and_process_mode() -> void:
	assert_eq(tree.root.theme, UiTheme.get_theme(), "Router assigns UiTheme to the root")
	assert_eq(Router.process_mode, Node.PROCESS_MODE_ALWAYS)
	var layer: CanvasLayer = Router.get_node("TransitionLayer") as CanvasLayer
	assert_not_null(layer)
	if layer != null:
		assert_eq(layer.layer, 100)
