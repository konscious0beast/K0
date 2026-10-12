class_name CombatInput extends Node
## Inputs of the real-time combat → recorded commands (07 §7, §10.1). Keyboard: 1–6 slots (left click on a slot too,
## right click on the potion = item wheel), Tab / Shift+Tab targets (exact_match, 07 §7.4: Shift+Tab also matches
## target_next without it), left click on an enemy / plate = target, on free floor = no target, F / Space / Enter
## "Angriff!" (nearest enemy + auto attack on), V auto attack, R Partner-Spezial, G tactic (from level 3), T autopilot,
## M blocked ("Nicht während der Aufnahme!"). Gamepad (07 §7.2): A X Y B = slots 1–4, RB SHOW, LB potion (hold 0.4 s =
## item wheel, right stick picks, release uses), RT / LT targets, D-pad up autopilot / right tactic / down auto attack /
## left Partner-Spezial. Touch (07 §7.3): combat_touch.gd buttons and the taps of TouchControls (tap ≠ drag) through
## pick(). Every command carries ct = the sim's current tick and goes through the HUD (→ CombatDirector.submit,
## hint cards). Context split (07 §7.2): the combat never evaluates `action` from a gamepad, `sneak` or `map`.
## The input-map changes of 07 §7.7 for `map` (no Tab) and `toggle_auto` (no Y, D-pad up) are project.godot's map since
## the pull of a person (07 E36); a CTB run gets its legacy map back (Tab = map, Y = auto battle) through
## apply_input_mode / apply_for_game until SD1 moves the CTB battle (07 §12.6).
## Soft target framing (07 §7.5, GameSettings.combat_camera_assist, touch default on): the camera yaw follows the
## enemy target at ≤ 90°/s when it is more than 40° off and the camera was not moved for 1.5 s (stops within 25°).

const CombatView := preload("res://scenes/combat/ui/combat_view.gd")

const BAR_ACTIONS: Array[StringName] = [&"bar_1", &"bar_2", &"bar_3", &"bar_4", &"bar_5", &"bar_6"]
## 07 §7.7 — the new combat actions of project.godot.
const ACTIONS: Array[StringName] = [&"target_next", &"target_prev", &"bar_1", &"bar_2", &"bar_3", &"bar_4", &"bar_5",
	&"bar_6", &"partner_special", &"partner_preset", &"auto_attack_toggle"]
const TAB_CONE_DEG: float = 60.0
const WHEEL_HOLD_SEC: float = 0.4
const ASSIST_START_DEG: float = 40.0
const ASSIST_STOP_DEG: float = 25.0
const ASSIST_IDLE_SEC: float = 1.5
const ASSIST_RATE_DEG: float = 90.0
const MAP_BLOCKED: String = "Nicht während der Aufnahme!"

## The combat HUD (send(cmd), feedback); duck-typed so tests can pass a recorder.
var hud: Node = null
var sim: RtSim = null
## Off while the combat is over / results show.
var active: bool = true

var _lb_held: float = -1.0                   # LB (bar_6 on a pad) held for … seconds, -1 = not held
var _lb_wheel: bool = false
var _cam_idle: float = 0.0
var _assisting: bool = false


func _ready() -> void:
	Events.camera_drag.connect(func(_r: Vector2) -> void: _cam_idle = 0.0)


# --- 07 §7.7 input map, real-time part ---------------------------------------------------------------------------

## The 07 §7.7 map of the existing actions for a real-time run (true: project.godot's own) or the CTB legacy map
## (false): `map` without / with Tab, `toggle_auto` with D-pad up instead of / with Y. Idempotent.
static func apply_input_mode(realtime: bool) -> void:
	_set_key(&"map", KEY_TAB, not realtime)
	_set_joy(&"toggle_auto", JOY_BUTTON_Y, not realtime)
	_set_joy(&"toggle_auto", JOY_BUTTON_DPAD_UP, realtime)


## The input map of the running game: the real-time one while GameState.combat_mode is &"realtime" (exploration
## targets with Tab there, 07 §7.1), else the CTB one. Called by every exploration HUD and after each combat.
static func apply_for_game() -> void:
	apply_input_mode(realtime_game())


static func realtime_game() -> bool:
	return Game.state != null and Game.state.combat_mode == &"realtime"


static func _set_key(action: StringName, key: Key, present: bool) -> void:
	if not InputMap.has_action(action):
		return
	var found: InputEvent = null
	for e: InputEvent in InputMap.action_get_events(action):
		if e is InputEventKey and (e as InputEventKey).physical_keycode == key and not (e as InputEventKey).shift_pressed:
			found = e
	if present and found == null:
		var k: InputEventKey = InputEventKey.new()
		k.physical_keycode = key
		k.device = -1
		InputMap.action_add_event(action, k)
	elif not present and found != null:
		InputMap.action_erase_event(action, found)


static func _set_joy(action: StringName, button: JoyButton, present: bool) -> void:
	if not InputMap.has_action(action):
		return
	var found: InputEvent = null
	for e: InputEvent in InputMap.action_get_events(action):
		if e is InputEventJoypadButton and (e as InputEventJoypadButton).button_index == button:
			found = e
	if present and found == null:
		var j: InputEventJoypadButton = InputEventJoypadButton.new()
		j.button_index = button
		j.device = -1
		InputMap.action_add_event(action, j)
	elif not present and found != null:
		InputMap.action_erase_event(action, found)


# --- target order (07 §7.4) ----------------------------------------------------------------------------------------

## Tab order: living enemies, first those within ±60° of the camera's flat forward (seen from the controlled figure)
## by distance to it, then the others by distance; ties by unit order. `positions`: unit id → world position.
static func tab_order(sim_ref: RtSim, ctl_pos: Vector3, cam_forward: Vector3,
		positions: Dictionary) -> PackedStringArray:
	var cone: Array[Dictionary] = []
	var rest: Array[Dictionary] = []
	var fwd: Vector2 = Vector2(cam_forward.x, cam_forward.z)
	fwd = fwd.normalized() if fwd.length() > 0.0001 else Vector2(0, -1)
	var cos_lim: float = cos(deg_to_rad(TAB_CONE_DEG))
	var i: int = 0
	for e: RtUnit in CombatView.enemies(sim_ref):
		var p: Vector3 = positions.get(e.id, Vector3(float(e.x) / 100.0, 0.0, float(e.z) / 100.0)) as Vector3
		var d: Vector2 = Vector2(p.x - ctl_pos.x, p.z - ctl_pos.z)
		var entry: Dictionary = {"id": e.id, "d": d.length(), "i": i}
		i += 1
		if d.length() < 0.0001 or d.normalized().dot(fwd) >= cos_lim:
			cone.append(entry)
		else:
			rest.append(entry)
	var by_dist: Callable = func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(float(a["d"]), float(b["d"])):
			return float(a["d"]) < float(b["d"])
		return int(a["i"]) < int(b["i"])
	cone.sort_custom(by_dist)
	rest.sort_custom(by_dist)
	var out: PackedStringArray = []
	for d2: Dictionary in cone + rest:
		out.append(str(d2["id"]))
	return out


## The next (or previous) id after `current` in `order` (wraps; an unknown current starts at the first / last).
static func next_in(order: PackedStringArray, current: String, forward: bool) -> String:
	if order.is_empty():
		return ""
	var i: int = order.find(current)
	if i < 0:
		return order[0] if forward else order[order.size() - 1]
	return order[posmod(i + (1 if forward else -1), order.size())]


# --- commands ------------------------------------------------------------------------------------------------------

func _ct() -> int:
	return sim.tick() if sim != null else 0


func _ctl() -> RtUnit:
	return CombatView.controlled(sim)


func _send(cmd: Dictionary) -> void:
	if hud != null and hud.has_method("send"):
		hud.call("send", cmd)


## Slot `slot` of the bar pressed (key, click, touch, pad).
func press_slot(slot: int) -> void:
	var u: RtUnit = _ctl()
	if u == null or not active:
		return
	var entries: Dictionary = CombatView.bar_entries(sim, u.id)
	if not entries.has(slot):
		return                                          # hidden slot (the bar grows with the level, 07 §4.1)
	var id: String = str(entries[slot])
	var def: SkillDef = CombatView.skill_of(id)
	var target: String = CombatView.target_for(sim, u, def)
	if CombatView.is_item_id(id):
		_send(RtCommand.item(_ct(), u.id, id, target))
	else:
		_send(RtCommand.ability(_ct(), u.id, id, target))


func use_item(item_id: String) -> void:
	var u: RtUnit = _ctl()
	if u == null or not active:
		return
	_send(RtCommand.item(_ct(), u.id, item_id, CombatView.target_for(sim, u, CombatView.skill_of(item_id))))


func set_target(id: String) -> void:
	var u: RtUnit = _ctl()
	if u == null or not active or u.target_id == id:
		return
	_send(RtCommand.target(_ct(), u.id, id))


## Tab / Shift+Tab / RT / LT / the touch target button.
func cycle_target(forward: bool) -> void:
	var u: RtUnit = _ctl()
	if u == null:
		return
	var order: PackedStringArray = tab_order(sim, _world_pos(u.id), _cam_forward(), _positions())
	var cur: String = u.target_id if u.target_id.begins_with("e") else ""
	var nxt: String = next_in(order, cur, forward)
	if nxt != "":
		set_target(nxt)


## "Angriff!" (F / Space / Enter): no enemy target → the nearest one; auto attack on (07 §7.1).
func attack() -> void:
	var u: RtUnit = _ctl()
	if u == null:
		return
	var t: RtUnit = sim.unit(u.target_id) if u.target_id != "" else null
	if t == null or t.side == u.side or t.hp <= 0:
		var order: PackedStringArray = tab_order(sim, _world_pos(u.id), _cam_forward(), _positions())
		var best: String = ""
		var best_d: float = INF
		for id: String in order:
			var d: float = _world_pos(id).distance_to(_world_pos(u.id))
			if d < best_d:
				best_d = d
				best = id
		if best != "":
			set_target(best)
	if not u.auto_on:
		_send(RtCommand.auto_attack(_ct(), u.id, true))


func toggle_auto_attack() -> void:
	var u: RtUnit = _ctl()
	if u != null:
		_send(RtCommand.auto_attack(_ct(), u.id, not u.auto_on))


func toggle_autopilot() -> void:
	var u: RtUnit = _ctl()
	if u != null:
		_send(RtCommand.autopilot(_ct(), u.id, u.driver != RtUnit.Driver.AUTOPILOT))


func partner_special() -> void:
	var sp: Dictionary = CombatView.partner_special(sim)
	if sp.is_empty():
		return                                          # no button → nothing (never in the tutorial, 07 §2.13)
	_send(RtCommand.partner_special(_ct(), str(sp["unit"])))


## G / D-pad right: the next tactic (only with the chip, from level 3; 07 §5.2).
func cycle_preset() -> void:
	if not CombatView.tactic_visible(sim):
		return
	var p: RtUnit = CombatView.partner(sim)
	var cur: Dictionary = CombatView.partner_preset(sim)
	var i: int = RtVocab.RT_PRESETS.find(str(cur["preset"]))
	var nxt: String = RtVocab.RT_PRESETS[(i + 1) % RtVocab.RT_PRESETS.size()]
	_send(RtCommand.preset(_ct(), p.id, nxt, cur["tog"] as Dictionary))


func set_preset(preset: String, tog: Dictionary) -> void:
	var p: RtUnit = CombatView.partner(sim)
	if p != null:
		_send(RtCommand.preset(_ct(), p.id, preset, tog))


## Tap / click at a screen point: an enemy under it (plate or foot point, ≥ 107 px) becomes the target; free floor
## clears it (PC click only — a touch tap on nothing keeps the target).
func pick(screen_pos: Vector2, clear_on_miss: bool) -> void:
	var id: String = ""
	if hud != null and hud.has_method("pick_unit"):
		id = str(hud.call("pick_unit", screen_pos))
	if id != "":
		set_target(id)
	elif clear_on_miss:
		var u: RtUnit = _ctl()
		if u != null and u.target_id != "":
			set_target("")


# --- events ------------------------------------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not active or sim == null:
		return
	if event.is_action_pressed(&"map"):                # gesperrt im Kampf (07 §7.1)
		get_viewport().set_input_as_handled()
		if hud != null and hud.has_method("toast"):
			hud.call("toast", MAP_BLOCKED)
		return
	if _is_any_press(event) and hud != null and hud.has_method("any_input"):
		hud.call("any_input", event)
	if event is InputEventMouseMotion and ((event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0:
		_cam_idle = 0.0


static func _is_any_press(event: InputEvent) -> bool:
	if event is InputEventKey:
		return (event as InputEventKey).pressed and not (event as InputEventKey).echo
	if event is InputEventJoypadButton:
		return (event as InputEventJoypadButton).pressed
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).pressed and event.device != InputEvent.DEVICE_ID_EMULATION
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	return false


func _unhandled_input(event: InputEvent) -> void:
	if not active or sim == null:
		return
	if handle(event):
		get_viewport().set_input_as_handled()


## Maps one input event to its combat action; true when it was used (tests feed events here directly).
func handle(event: InputEvent) -> bool:
	if event is InputEventKey and (event as InputEventKey).echo:
		return false
	var pad: bool = event is InputEventJoypadButton or event is InputEventJoypadMotion
	if hud != null and hud.has_method("overlay_open") and bool(hud.call("overlay_open")):
		if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
			hud.call("close_overlays")
			return true
	for i in BAR_ACTIONS.size():
		var a: StringName = BAR_ACTIONS[i]
		if i == 5 and pad:
			if event.is_action_pressed(a):
				_lb_held = 0.0
				_lb_wheel = false
				return true
			if event.is_action_released(a):
				_release_lb()
				return true
			continue
		if event.is_action_pressed(a, false, true):
			press_slot(i + 1)
			return true
	if event.is_action_pressed(&"target_prev", false, true):
		cycle_target(false)
		return true
	if event.is_action_pressed(&"target_next", false, true):
		cycle_target(true)
		return true
	if event.is_action_pressed(&"partner_special", false, true):
		partner_special()
		return true
	if event.is_action_pressed(&"partner_preset", false, true):
		cycle_preset()
		return true
	if event.is_action_pressed(&"auto_attack_toggle", false, true):
		toggle_auto_attack()
		return true
	if event.is_action_pressed(&"toggle_auto", false, true):
		toggle_autopilot()
		return true
	if event.is_action_pressed(&"action") and event is InputEventKey:
		attack()                                        # the pad's A is Slot 1 here (07 §7.2)
		return true
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and mb.device != InputEvent.DEVICE_ID_EMULATION:
			pick(mb.position, true)
			return true
	return false


func _release_lb() -> void:
	var was: float = _lb_held
	_lb_held = -1.0
	if _lb_wheel:
		_lb_wheel = false
		if hud != null and hud.has_method("wheel_confirm"):
			hud.call("wheel_confirm")
	elif was >= 0.0:
		press_slot(CombatView.SLOT_POTION)


func _process(delta: float) -> void:
	if _lb_held >= 0.0:
		_lb_held += delta
		if not _lb_wheel and _lb_held >= WHEEL_HOLD_SEC:
			_lb_wheel = true
			if hud != null and hud.has_method("open_wheel"):
				hud.call("open_wheel", true)
		if _lb_wheel and hud != null and hud.has_method("wheel_stick"):
			hud.call("wheel_stick", Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)))
	_cam_idle += delta
	if absf(Input.get_axis(&"cam_left", &"cam_right")) > 0.0 or absf(Input.get_axis(&"cam_up", &"cam_down")) > 0.0:
		_cam_idle = 0.0
	_soft_framing(delta)


# --- soft target framing (07 §7.5) ---------------------------------------------------------------------------------

## New camera yaw after one frame of soft framing, or `yaw` unchanged. Pure: tests drive it with numbers.
## `to_target` = flat world vector from the camera pivot (figure) to the target.
static func framing_step(yaw: float, to_target: Vector2, idle_sec: float, assisting: bool, delta: float) -> Dictionary:
	if to_target.length() < 0.01 or idle_sec < ASSIST_IDLE_SEC:
		return {"yaw": yaw, "assisting": false}
	var want: float = atan2(-to_target.x, -to_target.y)
	var diff: float = wrapf(want - yaw, -PI, PI)
	var off: float = absf(rad_to_deg(diff))
	if not assisting and off <= ASSIST_START_DEG:
		return {"yaw": yaw, "assisting": false}
	if off <= ASSIST_STOP_DEG:
		return {"yaw": yaw, "assisting": false}
	var step: float = deg_to_rad(ASSIST_RATE_DEG) * delta
	return {"yaw": yaw + clampf(diff, -step, step), "assisting": true}


func _soft_framing(delta: float) -> void:
	if hud == null or not hud.has_method("camera_rig") or not hud.has_method("camera_assist_on"):
		return
	if not bool(hud.call("camera_assist_on")):
		_assisting = false
		return
	var rig: Node3D = hud.call("camera_rig") as Node3D
	var u: RtUnit = _ctl()
	if rig == null or u == null or not ("yaw" in rig):
		return
	var t: RtUnit = sim.unit(u.target_id) if u.target_id != "" else null
	if t == null or t.side == u.side or t.hp <= 0:
		_assisting = false
		return
	var from: Vector3 = _world_pos(u.id)
	var to: Vector3 = _world_pos(t.id)
	var r: Dictionary = framing_step(float(rig.get("yaw")), Vector2(to.x - from.x, to.z - from.z), _cam_idle,
		_assisting, delta)
	_assisting = bool(r["assisting"])
	if _assisting:
		rig.set("yaw", float(r["yaw"]))


# --- world helpers -------------------------------------------------------------------------------------------------

func _world_pos(id: String) -> Vector3:
	if hud != null and hud.has_method("unit_world_position"):
		return hud.call("unit_world_position", id) as Vector3
	var u: RtUnit = sim.unit(id) if sim != null else null
	return Vector3(float(u.x) / 100.0, 0.0, float(u.z) / 100.0) if u != null else Vector3.ZERO


func _positions() -> Dictionary:
	var out: Dictionary = {}
	for e: RtUnit in CombatView.enemies(sim):
		out[e.id] = _world_pos(e.id)
	return out


func _cam_forward() -> Vector3:
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return Vector3(0, 0, -1)
	var f: Vector3 = -cam.global_transform.basis.z
	return Vector3(f.x, 0.0, f.z)
