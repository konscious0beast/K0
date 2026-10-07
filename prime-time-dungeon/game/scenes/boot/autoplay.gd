extends Node
## Autoplay driver (02_TECH §11.4), added under root by Boot with --autoplay (PROCESS_MODE_ALWAYS). Runs the step table
## boot_to_title → new_game → explore → force_battle → battle → safe_room with frame budgets (sum 600, watchdog 640),
## prints "AUTOPLAY: <step> ok @frame <n>" per step and finally "AUTOPLAY: OK frames=<n>" + quit(0); a failure prints
## "Assertion failed: AUTOPLAY step '<name>' failed: <reason>" + quit(1).
## While modules this run depends on are still Phase-A stubs (first line "# STUB(M0)", or the file is missing), only
## boot_to_title is verified and the driver prints exactly "AUTOPLAY: SKIPPED (stub)" + quit(0).

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const WATCHDOG_FRAMES: int = 640
const MOVE_FRAMES: int = 24
const MIN_MOVE_M: float = 1.0
const AUTOPLAY_SEED: int = 4242
## Scripts the full run needs as real implementations (scene + core + autoload + art kit with collision floors).
const REQUIRED: PackedStringArray = [
	"res://scenes/exploration/exploration.gd", "res://scenes/battle/battle_scene.gd",
	"res://scenes/battle/battle_controller.gd", "res://scenes/safe_room/safe_room.gd", "res://scenes/title/title.gd",
	"res://core/battle/battle_state.gd", "res://core/battle/auto_policy.gd", "res://core/battle/ctb_queue.gd",
	"res://core/battle/action_resolver.gd", "res://core/battle/damage_calc.gd", "res://core/battle/enemy_ai.gd",
	"res://core/battle/combatant.gd", "res://core/stats/stat_block.gd",
	"res://core/progression/game_state.gd", "res://core/progression/floor_run.gd",
	"res://core/progression/battle_bridge.gd", "res://core/progression/progression.gd",
	"res://core/progression/party_member.gd", "res://core/progression/inventory.gd",
	"res://core/dungeon/dungeon_generator.gd", "res://core/dungeon/floor_layout.gd", "res://core/live/run_sim.gd",
	"res://autoload/show.gd", "res://art/kit/env_kit.gd",
]
const STEPS: Array[Dictionary] = [
	{"name": "boot_to_title", "budget": 60},
	{"name": "new_game", "budget": 90},
	{"name": "explore", "budget": 30},
	{"name": "force_battle", "budget": 60},
	{"name": "battle", "budget": 300},
	{"name": "safe_room", "budget": 60},
]

var frames: int = 0
var step: int = 0
var step_frames: int = 0
var stubs: PackedStringArray = []
var finished: bool = false
## Test hook: when set, quit(code) is not called (the result is kept in `result_code` / `result_line`).
var dry_run: bool = false
var result_code: int = -1
var result_line: String = ""

var _entered: bool = false
var _floor_entered: bool = false
var _battle_outcome: int = -1
var _start_pos: Vector3 = Vector3.ZERO
var _move_released: bool = false
var _safe_room_reached: bool = false
var _exit_requested: bool = false


## Missing or still-stub dependencies of the full run (missing = no resource at that path).
static func stub_dependencies(paths: PackedStringArray = REQUIRED) -> PackedStringArray:
	var out: PackedStringArray = []
	for p: String in paths:
		if not ResourceLoader.exists(p) or UiUtil.is_stub(p):
			out.append(p)
	return out


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	stubs = stub_dependencies()
	if not stubs.is_empty():
		var names: PackedStringArray = []
		for p: String in stubs:
			names.append(p.get_file())
		if not dry_run:
			print("AUTOPLAY: waiting for stub modules (%d): %s" % [names.size(), ", ".join(names)])
	Events.floor_entered.connect(func(_i: int) -> void: _floor_entered = true)
	Events.battle_ended.connect(func(outcome: int, _enc: String) -> void: _battle_outcome = outcome)


func current_step_name() -> String:
	return str(STEPS[step]["name"]) if step < STEPS.size() else "done"


func _process(_delta: float) -> void:
	if finished:
		return
	frames += 1
	step_frames += 1
	if frames > WATCHDOG_FRAMES:
		_fail("watchdog (%d frames)" % WATCHDOG_FRAMES)
		return
	if step >= STEPS.size():
		_done()
		return
	var step_name: String = current_step_name()
	if not _entered:
		_entered = true
		_enter(step_name)
		if finished:
			return
	if _check(step_name):
		if not dry_run:
			print("AUTOPLAY: %s ok @frame %d" % [step_name, frames])
		if step_name == "boot_to_title" and not stubs.is_empty():
			_finish(0, "AUTOPLAY: SKIPPED (stub)")
			return
		step += 1
		step_frames = 0
		_entered = false
		if step >= STEPS.size():
			_done()
		return
	if step_frames > int(STEPS[step]["budget"]):
		_fail("budget of %d frames exceeded (%s)" % [int(STEPS[step]["budget"]), _state_text()])


func _enter(step_name: String) -> void:
	match step_name:
		"new_game":
			var title: Node = Router.current
			if title == null or not title.has_method("request_new_game"):
				_fail("title screen not active")
				return
			_floor_entered = false
			title.call("request_new_game", 0, "Kai", true, AUTOPLAY_SEED)
		"explore":
			var ex: Node = Router.current
			_start_pos = ex.call("get_player_position") if ex != null and ex.has_method("get_player_position") \
				else Vector3.ZERO
			_move_released = false
			Input.action_press(&"move_forward")
		"force_battle":
			var ex2: Node = Router.current
			if ex2 == null or not ex2.has_method("force_encounter"):
				_fail("exploration not active")
				return
			Game.auto_battle = true
			_battle_outcome = -1
			ex2.call("force_encounter", "")
		"safe_room":
			var ex3: Node = Router.current
			var layout: FloorLayout = ex3.call("get_layout") if ex3 != null and ex3.has_method("get_layout") else null
			var id: String = smallest_safe_room(layout)
			if id == "":
				_fail("no safe room in the floor layout")
				return
			_safe_room_reached = false
			_exit_requested = false
			Router.enter_safe_room(id)


func _check(step_name: String) -> bool:
	var cur: Node = Router.current
	match step_name:
		"boot_to_title":
			return cur is TitleScreen and not Router.busy
		"new_game":
			return cur is ExplorationScene and not Router.busy and _floor_entered
		"explore":
			if step_frames >= MOVE_FRAMES and not _move_released:
				_move_released = true
				Input.action_release(&"move_forward")
			if cur == null or not cur.has_method("get_player_position"):
				return false
			var moved: float = (cur.call("get_player_position") as Vector3).distance_to(_start_pos)
			if moved >= MIN_MOVE_M:
				if not _move_released:
					_move_released = true
					Input.action_release(&"move_forward")
				return true
			return false
		"force_battle":
			return cur is BattleScene and not Router.busy
		"battle":
			if _battle_outcome >= 0 and _battle_outcome != BattleResult.Outcome.VICTORY:
				_fail("battle ended with outcome %d (expected VICTORY)" % _battle_outcome)
				return false
			return _battle_outcome == BattleResult.Outcome.VICTORY and cur is ExplorationScene and not Router.busy
		"safe_room":
			if not _safe_room_reached:
				if cur is SafeRoomScene and not Router.busy:
					_safe_room_reached = true
					_exit_requested = true
					Router.exit_safe_room()
				return false
			if not (_exit_requested and cur is ExplorationScene and not Router.busy):
				return false
			if Game.state == null or Game.state.floor_run == null or not Game.state.floor_run.timer_started:
				_fail("floor timer did not start after the tutorial battle")
				return false
			return true
	return false


## Smallest safe room id of the layout ("" if none).
static func smallest_safe_room(layout: FloorLayout) -> String:
	if layout == null:
		return ""
	var ids: PackedStringArray = []
	for v: Variant in layout.safe_room_ids.values():
		ids.append(str(v))
	ids.sort()
	return ids[0] if not ids.is_empty() else ""


func _state_text() -> String:
	var cur: Node = Router.current
	return "current=%s busy=%s" % [cur.name if cur != null else "null", str(Router.busy)]


func _done() -> void:
	_finish(0, "AUTOPLAY: OK frames=%d" % frames)


func _fail(reason: String) -> void:
	if finished:
		return
	UiUtil.release_move_actions()
	var line: String = "Assertion failed: AUTOPLAY step '%s' failed: %s" % [current_step_name(), reason]
	finished = true
	result_code = 1
	result_line = line
	if not dry_run:
		printerr(line)
		get_tree().quit(1)


func _finish(code: int, line: String) -> void:
	finished = true
	result_code = code
	result_line = line
	UiUtil.release_move_actions()
	if not dry_run:
		print(line)
		get_tree().quit(code)
