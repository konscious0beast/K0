extends Node
## Autoload `Router` (02_TECH §3.7, §9): screen stack, transitions, safe room in and out (the real-time combat runs in
## the exploration scene, 07 §2.8 — no screen of its own since R5b part 2b).
## All operations are coroutines; callers need not await. Calls while busy are queued and run in order (never dropped).
## Every operation starts with `await get_tree().process_frame` (also for Transition.NONE).

enum Transition { NONE, FADE }
const SCENE_BOOT: String = "res://scenes/boot/boot.tscn"
const SCENE_TITLE: String = "res://scenes/title/title.tscn"
const SCENE_INTRO: String = "res://scenes/title/intro.tscn"
const SCENE_GAME_OVER: String = "res://scenes/title/game_over.tscn"
const SCENE_CREDITS: String = "res://scenes/title/credits.tscn"
const SCENE_EXPLORATION: String = "res://scenes/exploration/exploration.tscn"
const SCENE_SAFE_ROOM: String = "res://scenes/safe_room/safe_room.tscn"
const SCENE_FLOOR_SUMMARY: String = "res://scenes/ui/floor_summary.tscn"

const LAYER: int = 100
const FADE_OUT_SEC: float = 0.25
const FADE_IN_SEC: float = 0.25
const INK: Color = Color("#140d1c")          # == Palette.INK (no M0 → M4 dependency)

signal _op_finished(ticket: int)

var current: Node = null:                     # top of stack (active screen); null when freed
	get:
		if not is_instance_valid(current):
			return null
		return current
var busy: bool = false                        # true during any transition

var _stack: Array[Node] = []
var _queue: Array[Dictionary] = []            # pending ops {"ticket", "op", "path", "params", "payload", "t"}
var _running: bool = false
var _next_ticket: int = 0
var _last_done: int = 0
var _boot_freed: bool = false
var _safe_room_id: String = ""
var _layer: CanvasLayer
var _fade: ColorRect


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.name = "TransitionLayer"
	_layer.layer = LAYER
	add_child(_layer)
	_fade = ColorRect.new()
	_fade.name = "Fade"
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color(INK, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_fade)


func _ready() -> void:
	get_tree().root.theme = UiTheme.get_theme()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# Android back: send ui_cancel (02_TECH §10.5).
		var ev: InputEventAction = InputEventAction.new()
		ev.action = &"ui_cancel"
		ev.pressed = true
		Input.parse_input_event(ev)
		var up: InputEventAction = InputEventAction.new()
		up.action = &"ui_cancel"
		up.pressed = false
		Input.parse_input_event(up)


# ======================================================================================================================
# Public API
# ======================================================================================================================

func goto(path: String, params: Dictionary = {}, transition: Transition = Transition.FADE) -> void:
	await _enqueue({"op": "goto", "path": path, "params": params, "t": transition})


func push(path: String, params: Dictionary = {}, transition: Transition = Transition.FADE) -> void:
	await _enqueue({"op": "push", "path": path, "params": params, "t": transition})


func pop(payload: Dictionary = {}, transition: Transition = Transition.FADE) -> void:
	await _enqueue({"op": "pop", "payload": payload, "t": transition})


## _stack = [node], current = node (node already under root); used by capture.gd and TestCase.add_to_tree (§9.2).
func adopt(node: Node) -> void:
	_stack.clear()
	if node != null:
		_stack.append(node)
	current = node


func enter_safe_room(safe_room_id: String) -> void:
	_safe_room_id = safe_room_id
	await push(SCENE_SAFE_ROOM, {"safe_room_id": safe_room_id}, Transition.FADE)


func exit_safe_room() -> void:
	var id: String = _safe_room_id
	_safe_room_id = ""
	await pop({"from_safe_room": id}, Transition.FADE)


## Game.on_game_over(reason); goto(SCENE_GAME_OVER, {"reason": reason}, FADE). Staffeln (09 §7, ST1-B): a season has no
## game over — Game.season_defeat_route routes after its death rule (medics: the exploration; Ohne Netz out: the
## Sendeschluss screen).
func game_over(reason: StringName) -> void:
	if Game.season_defeat_route(reason):          # Staffeln (09, ST1-B)
		return
	Game.on_game_over(reason)
	await goto(SCENE_GAME_OVER, {"reason": reason}, Transition.FADE)


func stack_size() -> int:
	_prune()
	return _stack.size()


# ======================================================================================================================
# Queue
# ======================================================================================================================

func _enqueue(op: Dictionary) -> void:
	_next_ticket += 1
	var ticket: int = _next_ticket
	op["ticket"] = ticket
	_queue.append(op)
	busy = true
	if _running:
		while _last_done < ticket:
			await _op_finished
		return
	_running = true
	while not _queue.is_empty():
		var item: Dictionary = _queue.pop_front()
		match str(item["op"]):
			"goto":
				await _do_goto(str(item["path"]), item["params"], item["t"])
			"push":
				await _do_push(str(item["path"]), item["params"], item["t"])
			"pop":
				await _do_pop(item["payload"], item["t"])
		_last_done = int(item["ticket"])
		if _queue.is_empty():
			busy = false
			_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cur: Node = current
		Events.scene_changed.emit(cur.scene_file_path if cur != null else "")
		_op_finished.emit(_last_done)
	_running = false


# ======================================================================================================================
# Operations
# ======================================================================================================================

func _do_goto(path: String, params: Dictionary, transition: Transition) -> void:
	await get_tree().process_frame
	Game.timer_running = false
	print("[Router] goto ", path)
	await _transition_out(transition)
	var root: Window = get_tree().root
	# Instantiate first: a missing/invalid scene falls back to the title instead of leaving no screen at all.
	var node: Node = _instantiate(path, params)
	if node == null and path != SCENE_TITLE:
		push_warning("[Router] goto %s failed → title" % path)
		node = _instantiate(SCENE_TITLE, {})
	_prune()
	var top: Node = _stack.back() if not _stack.is_empty() else null
	for n: Node in _stack:
		if not is_instance_valid(n):
			continue
		if n == top and n.is_inside_tree():
			n.get_parent().remove_child(n)
			n.queue_free()
		elif n.is_inside_tree():
			n.queue_free()
		else:
			n.free()
	_stack.clear()
	current = null
	if not _boot_freed:
		_boot_freed = true
		var boot: Node = get_tree().current_scene
		if boot != null and is_instance_valid(boot) and boot != top:
			if boot.get_parent() == root:
				root.remove_child(boot)
			boot.queue_free()
	# Dialogs of the freed screens can no longer finish (02_TECH §3.4 dialog pause).
	Game.clear_blocking_dialogs()
	if node != null:
		root.add_child(node)
		get_tree().current_scene = node
		_stack.append(node)
		current = node
	await _transition_in(transition)


func _do_push(path: String, params: Dictionary, transition: Transition) -> void:
	await get_tree().process_frame
	Game.timer_running = false
	print("[Router] push ", path)
	var root: Window = get_tree().root
	_prune()
	var top: Node = current
	if top != null and top.has_method("on_suspend"):
		top.call("on_suspend")
	await _transition_out(transition)
	# Instantiate before detaching: on failure the old screen stays attached and resumes (no screen-less tree).
	var node: Node = _instantiate(path, params)
	if node == null:
		top = current
		if top != null and top.has_method("on_resume"):
			top.call("on_resume", {})
		await _transition_in(transition)
		return
	if top != null and is_instance_valid(top) and top.get_parent() == root:
		root.remove_child(top)
	root.add_child(node)
	get_tree().current_scene = node
	_stack.append(node)
	current = node
	await _transition_in(transition)


func _do_pop(payload: Dictionary, transition: Transition) -> void:
	_prune()
	if _stack.size() <= 1:
		push_warning("[Router] pop with stack size %d → title" % _stack.size())
		await _do_goto(SCENE_TITLE, {}, transition)
		return
	await get_tree().process_frame
	print("[Router] pop")
	await _transition_out(transition)
	var root: Window = get_tree().root
	var top: Node = _stack.pop_back()
	if is_instance_valid(top):
		if top.get_parent() == root:
			root.remove_child(top)
		top.queue_free()
	_prune()
	var prev: Node = _stack.back() if not _stack.is_empty() else null
	current = prev
	if prev != null:
		if prev.get_parent() == null:
			root.add_child(prev)
		get_tree().current_scene = prev
		if prev.has_method("on_resume"):
			prev.call("on_resume", payload)
	await _transition_in(transition)


func _instantiate(path: String, params: Dictionary) -> Node:
	if not ResourceLoader.exists(path):
		push_error("[Router] scene not found: %s" % path)
		return null
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		push_error("[Router] not a scene: %s" % path)
		return null
	var node: Node = packed.instantiate()
	if node == null:
		push_error("[Router] cannot instantiate: %s" % path)
		return null
	if node.has_method("setup"):
		node.call("setup", params)
	return node


func _prune() -> void:
	var valid: Array[Node] = []
	for n: Node in _stack:
		if is_instance_valid(n):
			valid.append(n)
	_stack = valid


# ======================================================================================================================
# Transitions (CanvasLayer 100)
# ======================================================================================================================

func _transition_out(transition: Transition) -> void:
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	match transition:
		Transition.NONE:
			_fade.color = Color(INK, 0.0)
		Transition.FADE:
			await _tween_fade(1.0, FADE_OUT_SEC)


func _transition_in(transition: Transition) -> void:
	match transition:
		Transition.NONE:
			_fade.color = Color(INK, 0.0)
		Transition.FADE:
			await _tween_fade(0.0, FADE_IN_SEC)
	if not _running or _queue.is_empty():
		_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _tween_fade(alpha: float, sec: float) -> void:
	var tween: Tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_fade, "color:a", alpha, sec)
	await tween.finished
