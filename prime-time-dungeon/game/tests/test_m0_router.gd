extends TestCase
## Router (02_TECH §3.7, §9.2): empty stack / adopt, push/pop with suspend/resume, queueing, goto freeing, failure
## handling, battle / safe room / game over helpers.
## Generic operations push the fixture screen tests/fixtures/router/router_screen.tscn, so this test never depends on
## what other modules put into their screens. The helpers have fixed targets: those cases run against the real scenes
## (title, battle, safe room, game over) and check the routing — Router.current.scene_file_path == Router.SCENE_*, the
## params the screen received and the payloads handed back — never screen internals.
## Uses Transition.NONE where possible to stay fast.

const MAX_FRAMES: int = 240
const FIXTURE: String = "res://tests/fixtures/router/router_screen.tscn"
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
	Game.in_battle = false
	Game.safe_room_clock = false
	Sfx.stop_all()                         # the real title / battle / game over screens start their music


func _idle() -> bool:
	return await wait_until(func() -> bool: return not Router.busy, MAX_FRAMES)


func _screen() -> _Screen:
	var s: _Screen = _Screen.new()
	s.name = "TestScreen"
	add_to_tree(s)
	return s


func _is_fixture(n: Node) -> bool:
	return n != null and n.scene_file_path == FIXTURE


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
	# Prints one expected "ERROR: [Router] scene not found: user://…" line (+ a warning).
	var s: _Screen = _screen()
	Router.goto(MISSING, {}, Router.Transition.NONE)
	assert_true(await _idle())
	assert_not_null(Router.current)
	if Router.current == null:
		return
	assert_eq(Router.current.scene_file_path, Router.SCENE_TITLE, "title instead of an empty tree")
	assert_true(Router.current is TitleScreen)
	assert_eq(Router.stack_size(), 1)
	await wait_frames(1)
	assert_false(is_instance_valid(s), "the old stack is freed by the goto")


func test_pop_with_empty_stack_goes_to_title() -> void:
	Router.adopt(null)
	Router.pop({}, Router.Transition.NONE)
	assert_true(await _idle())
	assert_not_null(Router.current)
	if Router.current == null:
		return
	assert_eq(Router.current.scene_file_path, Router.SCENE_TITLE, "never an empty tree")
	assert_eq(Router.stack_size(), 1)


func test_battle_helpers() -> void:
	Game.new_game(0, "Kai", 3)
	var s: _Screen = _screen()
	var setup: BattleSetup = Game.make_battle_setup(DB.floor_def(1).timer_start_after, 0, "")
	assert_not_null(setup)
	Router.start_battle(setup)
	assert_true(await _idle())
	assert_eq(Router.current.scene_file_path, Router.SCENE_BATTLE, "start_battle pushes the battle scene")
	assert_eq(Router.current.get("battle_setup"), setup, "the setup reaches the battle scene ({\"setup\": setup})")
	assert_eq(Router.stack_size(), 2)
	assert_eq(s.calls, ["suspend"], "the exploration screen is suspended, not freed")
	var result: BattleResult = BattleResult.new()
	result.outcome = BattleResult.Outcome.VICTORY
	Router.end_battle(result)
	assert_true(await _idle())
	assert_eq(Router.current, s, "end_battle pops back to the suspended screen")
	assert_eq(s.payloads, [{"battle_result": result}])
	assert_eq(Router.stack_size(), 1)


func test_safe_room_helpers() -> void:
	Game.new_game(0, "Kai", 3)
	var sr_id: String = str(Game._current_layout().safe_room_ids.values()[0])
	var s: _Screen = _screen()
	Router.enter_safe_room(sr_id)
	assert_true(await _idle())
	assert_eq(Router.current.scene_file_path, Router.SCENE_SAFE_ROOM)
	assert_eq(Router.current.get("safe_room_id"), sr_id, "the id reaches the safe room ({\"safe_room_id\": id})")
	assert_eq(Router.stack_size(), 2)
	Router.exit_safe_room()
	assert_true(await _idle())
	assert_eq(Router.current, s)
	assert_eq(s.payloads, [{"from_safe_room": sr_id}])


func test_defeat_goes_to_game_over() -> void:
	Game.new_game(0, "Kai", 3)
	_screen()
	var stat_before: int = int(Game.state.show.stats.get("game_overs", 0))
	var result: BattleResult = BattleResult.new()
	result.outcome = BattleResult.Outcome.DEFEAT
	Router.end_battle(result)
	assert_true(await _idle())
	assert_eq(Router.current.scene_file_path, Router.SCENE_GAME_OVER, "DEFEAT → game over instead of a pop")
	assert_eq(Router.current.get("reason"), &"defeat", "params {\"reason\": &\"defeat\"}")
	assert_eq(Router.stack_size(), 1, "goto: the whole stack is replaced")
	assert_eq(int(Game.state.show.stats.get("game_overs", 0)), stat_before + 1, "Game.on_game_over ran first")


func test_theme_and_process_mode() -> void:
	assert_eq(tree.root.theme, UiTheme.get_theme(), "Router assigns UiTheme to the root")
	assert_eq(Router.process_mode, Node.PROCESS_MODE_ALWAYS)
	var layer: CanvasLayer = Router.get_node("TransitionLayer") as CanvasLayer
	assert_not_null(layer)
	if layer != null:
		assert_eq(layer.layer, 100)
