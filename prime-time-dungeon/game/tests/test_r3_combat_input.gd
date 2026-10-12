extends TestCase
## R3 combat input (07 §7.1–7.5, §7.7, §12.5): keys / gamepad / touch → recorded commands with ct = the sim's tick
## (CombatDirector.submit), Shift+Tab with exact_match, R = Partner-Spezial, the Tab order (±60° camera cone, then
## distance), click / tap picking, the context split exploration / combat (map blocked, `action` from a pad = slot 1,
## the 07 §7.7 input-map changes only for real-time runs), LB hold = item wheel, soft target framing.

const HudRig := preload("res://tests/fixtures/rt_hud/hud_rig.gd")
const HudScenarios := preload("res://tests/fixtures/rt_hud/hud_scenarios.gd")
const FakeSim := preload("res://tests/fixtures/rt_min/fake_rt_sim.gd")


## Duck-typed HUD for CombatInput alone (send / pick_unit / toast / open_wheel …).
class Recorder extends Node:
	var sent: Array[Dictionary] = []
	var pick_answer: String = ""
	var toasts: PackedStringArray = []
	var wheel_opened: int = 0
	var wheel_confirmed: int = 0
	var positions: Dictionary = {}

	func send(cmd: Dictionary) -> void:
		sent.append(cmd.duplicate(true))

	func pick_unit(_p: Vector2) -> String:
		return pick_answer

	func toast(text: String) -> void:
		toasts.append(text)

	func open_wheel(_pad: bool = false) -> void:
		wheel_opened += 1

	func wheel_confirm() -> void:
		wheel_confirmed += 1

	func unit_world_position(id: String) -> Vector3:
		return positions.get(id, Vector3.ZERO) as Vector3


func before_each() -> void:
	Game.new_game(0, "Kai", 11)


func after_each() -> void:
	CombatInput.apply_input_mode(true)             # the project map (07 §7.7, E36)


func _key(code: Key, shift: bool = false, pressed: bool = true) -> InputEventKey:
	var k: InputEventKey = InputEventKey.new()
	k.physical_keycode = code
	k.keycode = code
	k.shift_pressed = shift
	k.pressed = pressed
	return k


func _joy(button: JoyButton, pressed: bool = true) -> InputEventJoypadButton:
	var j: InputEventJoypadButton = InputEventJoypadButton.new()
	j.button_index = button
	j.pressed = pressed
	return j


func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var m: InputEventJoypadMotion = InputEventJoypadMotion.new()
	m.axis = axis
	m.axis_value = value
	return m


## CombatInput + Recorder over a level-`lvl` HudSim with the target e0 and tick 77.
func _input_rig(lvl: int = 4, data: GameData = null) -> Array:
	var d: GameData = data if data != null else FakeSim.load_data()
	var sim: RtSim = HudScenarios.build(d, {"level": lvl, "enemies": ["enm_kanalratte", "enm_kanalratte",
		"enm_rt_test_caster"]})
	sim.call("set_tick", 77)
	sim.unit("p0").target_id = "e0"
	var rec: Recorder = Recorder.new()
	add_to_tree(rec)
	var ci: CombatInput = CombatInput.new()
	ci.hud = rec
	ci.sim = sim
	rec.add_child(ci)
	return [ci, rec, sim]


func test_keys_1_to_6_send_the_bar() -> void:
	var r: Array = _input_rig()
	var ci: CombatInput = r[0]
	var rec: Recorder = r[1]
	var expect: Array = ["skl_kai_heavy_swing", "skl_kai_taunt", "skl_kai_leash_trip", "skl_kai_sweep",
		"skl_stunt_kai_suplex"]
	for i in 5:
		assert_true(ci.handle(_key(KEY_1 + i)), "key %d used" % (i + 1))
		var c: Dictionary = rec.sent[rec.sent.size() - 1]
		assert_eq(str(c["t"]), "ability_use", "key %d" % (i + 1))
		assert_eq(str(c["skill"]), str(expect[i]), "key %d → slot %d" % [i + 1, i + 1])
		assert_eq(int(c["ct"]), 77, "ct = the sim's current tick")
		assert_eq(str(c["u"]), "p0")
	assert_eq(str(rec.sent[0]["target"]), "e0", "enemy skill → the current enemy target")
	assert_eq(str(rec.sent[1]["target"]), "", "self skill (Spott) → no target, the sim decides")
	assert_true(ci.handle(_key(KEY_6)))
	var pot: Dictionary = rec.sent[rec.sent.size() - 1]
	assert_eq([str(pot["t"]), str(pot["item"])], ["combat_item", "itm_bandage"], "6 = potion (auto pick)")
	for c2: Dictionary in rec.sent:
		assert_eq(RtCommand.validate(c2), "", "schema-valid command %s" % str(c2))


func test_hidden_slots_send_nothing() -> void:
	var r: Array = _input_rig(1)
	var ci: CombatInput = r[0]
	var rec: Recorder = r[1]
	ci.handle(_key(KEY_2))
	ci.handle(_key(KEY_3))
	ci.handle(_key(KEY_4))
	assert_eq(rec.sent.size(), 0, "level 1: slots 2–4 are not on the bar (07 §4.1)")
	ci.handle(_key(KEY_1))
	assert_eq(rec.sent.size(), 1, "slot 1 is")


func test_tab_shift_tab_exact_match() -> void:
	var r: Array = _input_rig()
	var ci: CombatInput = r[0]
	var rec: Recorder = r[1]
	rec.positions = {"p0": Vector3.ZERO, "e0": Vector3(0, 0, -3), "e1": Vector3(1, 0, -5), "e2": Vector3(0, 0, 4)}
	var shift_tab: InputEventKey = _key(KEY_TAB, true)
	assert_true(shift_tab.is_action_pressed(&"target_next"), "07 §7.4: Shift+Tab matches target_next without exact")
	assert_false(shift_tab.is_action_pressed(&"target_next", false, true), "… but not with exact_match")
	assert_true(shift_tab.is_action_pressed(&"target_prev", false, true))
	assert_true(ci.handle(_key(KEY_TAB)))
	assert_eq(str(rec.sent[rec.sent.size() - 1]["target"]), "e1", "Tab: next after e0 in the order e0, e1, e2")
	(r[2] as RtSim).unit("p0").target_id = "e1"
	assert_true(ci.handle(shift_tab))
	var c: Dictionary = rec.sent[rec.sent.size() - 1]
	assert_eq([str(c["t"]), str(c["target"])], ["target_change", "e0"], "Shift+Tab: the previous one")


func test_tab_order_cone_then_distance() -> void:
	var sim: RtSim = HudScenarios.build(FakeSim.load_data(), {"level": 1, "enemies": ["enm_kanalratte",
		"enm_kanalratte", "enm_kanalratte", "enm_kanalratte"]})
	var pos: Dictionary = {"e0": Vector3(0, 0, -5), "e1": Vector3(3, 0, -2), "e2": Vector3(0, 0, 4),
		"e3": Vector3(-6, 0, -1)}
	var order: PackedStringArray = CombatInput.tab_order(sim, Vector3.ZERO, Vector3(0, 0, -1), pos)
	assert_eq(order, PackedStringArray(["e1", "e0", "e2", "e3"]),
		"±60° cone first by distance (e1 56°, e0 0°), then the rest by distance")
	assert_eq(CombatInput.next_in(order, "e3", true), "e1", "wraps")
	assert_eq(CombatInput.next_in(order, "", true), "e1", "no target: the first")
	assert_eq(CombatInput.next_in(order, "", false), "e3", "backwards: the last")
	sim.unit("e1").hp = 0
	assert_false(CombatInput.tab_order(sim, Vector3.ZERO, Vector3(0, 0, -1), pos).has("e1"), "only living enemies")


func test_partner_special_r_and_dpad_left() -> void:
	var r: Array = _input_rig(4)
	var ci: CombatInput = r[0]
	var rec: Recorder = r[1]
	assert_true(ci.handle(_key(KEY_R)), "R")
	var c: Dictionary = rec.sent[rec.sent.size() - 1]
	assert_eq([str(c["t"]), str(c["u"])], ["partner_special", "p1"], "R orders the partner (07 §4.1)")
	assert_true(ci.handle(_joy(JOY_BUTTON_DPAD_LEFT)), "D-pad left")
	assert_eq(str(rec.sent[rec.sent.size() - 1]["t"]), "partner_special")
	var tut: Array = _input_rig(1)
	(tut[2] as RtSim).set("specials", {})
	(tut[0] as CombatInput).handle(_key(KEY_R))
	assert_eq((tut[1] as Recorder).sent.size(), 0, "no Partner-Spezial yet → nothing")


func test_gamepad_layout() -> void:
	var r: Array = _input_rig(4)
	var ci: CombatInput = r[0]
	var rec: Recorder = r[1]
	var pad: Dictionary = {JOY_BUTTON_A: "skl_kai_heavy_swing", JOY_BUTTON_X: "skl_kai_taunt",
		JOY_BUTTON_Y: "skl_kai_leash_trip", JOY_BUTTON_B: "skl_kai_sweep",
		JOY_BUTTON_RIGHT_SHOULDER: "skl_stunt_kai_suplex"}
	for b: int in pad.keys():
		assert_true(ci.handle(_joy(b as JoyButton)), "button %d" % b)
		assert_eq(str(rec.sent[rec.sent.size() - 1].get("skill", "")), str(pad[b]), "07 §7.2 button %d" % b)
	var n: int = rec.sent.size()
	assert_true(ci.handle(_joy(JOY_BUTTON_LEFT_SHOULDER)), "LB down")
	assert_eq(rec.sent.size(), n, "LB acts on release (hold = wheel)")
	assert_true(ci.handle(_joy(JOY_BUTTON_LEFT_SHOULDER, false)), "LB up")
	assert_eq(str(rec.sent[rec.sent.size() - 1]["t"]), "combat_item", "short LB = potion")
	ci.handle(_joy(JOY_BUTTON_DPAD_DOWN))
	assert_eq(str(rec.sent[rec.sent.size() - 1]["t"]), "auto_attack", "D-pad down = auto attack on/off")
	ci.handle(_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0))
	assert_eq(str(rec.sent[rec.sent.size() - 1]["t"]), "target_change", "RT = next target")
	n = rec.sent.size()
	ci.handle(_joy(JOY_BUTTON_DPAD_RIGHT))
	assert_eq(str(rec.sent[rec.sent.size() - 1]["t"]), "partner_preset", "D-pad right = tactic (level ≥ 3)")
	assert_eq(str(rec.sent[rec.sent.size() - 1]["preset"]), "careful", "cycles attack → support → careful")
	assert_gt(rec.sent.size(), n)
	CombatInput.apply_input_mode(true)
	ci.handle(_joy(JOY_BUTTON_DPAD_UP))
	var last: Dictionary = rec.sent[rec.sent.size() - 1]
	assert_eq([str(last["t"]), bool(last["on"])], ["autopilot", true], "D-pad up = autopilot (07 §7.7)")


func test_lb_hold_opens_the_item_wheel() -> void:
	var r: Array = _input_rig(4)
	var ci: CombatInput = r[0]
	var rec: Recorder = r[1]
	Engine.time_scale = 8.0
	ci.handle(_joy(JOY_BUTTON_LEFT_SHOULDER))
	await wait_until(func() -> bool: return rec.wheel_opened > 0, 1200)
	Engine.time_scale = 1.0
	var before: int = rec.sent.size()
	ci.handle(_joy(JOY_BUTTON_LEFT_SHOULDER, false))
	assert_eq(rec.wheel_confirmed, 1, "release = use the picked item")
	assert_eq(rec.sent.size(), before, "no extra potion press after the wheel")


func test_click_and_tap_picking() -> void:
	var r: Array = _input_rig(4)
	var ci: CombatInput = r[0]
	var rec: Recorder = r[1]
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(640, 300)
	rec.pick_answer = "e2"
	assert_true(ci.handle(click))
	assert_eq(str(rec.sent[rec.sent.size() - 1]["target"]), "e2", "click on an enemy / plate = target")
	(r[2] as RtSim).unit("p0").target_id = "e2"
	rec.pick_answer = ""
	ci.handle(click)
	assert_eq(str(rec.sent[rec.sent.size() - 1]["target"]), "", "click on free floor clears the target")
	(r[2] as RtSim).unit("p0").target_id = "e2"
	var n: int = rec.sent.size()
	ci.pick(Vector2(10, 10), false)
	assert_eq(rec.sent.size(), n, "a touch tap on nothing keeps the target")


func test_context_split() -> void:
	var r: Array = _input_rig(4)
	var ci: CombatInput = r[0]
	var rec: Recorder = r[1]
	var m: InputEventKey = _key(KEY_M)
	ci._input(m)
	assert_eq(rec.toasts, PackedStringArray(["Nicht während der Aufnahme!"]), "map blocked in combat (07 §7.1)")
	assert_eq(rec.sent.size(), 0)
	assert_false(ci.handle(_key(KEY_SHIFT)), "sneak is not a combat input")
	(r[2] as RtSim).unit("p0").auto_on = false
	assert_true(ci.handle(_key(KEY_F)), "F = Angriff! (keyboard `action`)")
	assert_eq(rec.sent.size(), 1, "one command")
	if rec.sent.size() == 1:
		assert_eq([str(rec.sent[0]["t"]), bool(rec.sent[0]["on"])], ["auto_attack", true], "Angriff! = auto on")
	ci.active = false
	var n: int = rec.sent.size()
	ci._unhandled_input(_key(KEY_1))
	assert_eq(rec.sent.size(), n, "inactive (combat over): nothing")
	# 07 §7.7 changes of existing actions: only for real-time runs
	CombatInput.apply_input_mode(false)
	assert_true(_key(KEY_TAB).is_action_pressed(&"map"), "CTB: Tab still opens the map")
	assert_true(_joy(JOY_BUTTON_Y).is_action_pressed(&"toggle_auto"), "CTB: Y toggles auto")
	CombatInput.apply_input_mode(true)
	assert_false(_key(KEY_TAB).is_action_pressed(&"map"), "real time: map = M only")
	assert_true(_key(KEY_M).is_action_pressed(&"map"))
	assert_false(_joy(JOY_BUTTON_Y).is_action_pressed(&"toggle_auto"), "real time: Y is slot 3")
	assert_true(_joy(JOY_BUTTON_DPAD_UP).is_action_pressed(&"toggle_auto"), "real time: D-pad up = autopilot")
	CombatInput.apply_input_mode(true)
	assert_eq(InputMap.action_get_events(&"toggle_auto").size(), 2, "idempotent")
	Game.state.combat_mode = &"realtime"
	CombatInput.apply_input_mode(false)
	CombatInput.apply_for_game()
	assert_false(_key(KEY_TAB).is_action_pressed(&"map"), "a real-time run keeps the map in exploration too")
	Game.state.combat_mode = &"ctb"
	CombatInput.apply_for_game()
	assert_true(_key(KEY_TAB).is_action_pressed(&"map"), "a CTB run gets its map back")


func test_new_actions_in_the_input_map() -> void:
	var expect: Dictionary = {&"target_next": [KEY_TAB], &"target_prev": [KEY_TAB], &"bar_1": [KEY_1],
		&"bar_6": [KEY_6], &"partner_special": [KEY_R], &"partner_preset": [KEY_G], &"auto_attack_toggle": [KEY_V]}
	for a: StringName in expect.keys():
		assert_true(InputMap.has_action(a), "project.godot has %s (07 §7.7)" % a)
		var keys: Array = []
		for e: InputEvent in InputMap.action_get_events(a):
			if e is InputEventKey:
				keys.append(int((e as InputEventKey).physical_keycode))
		assert_eq(keys, expect[a], "keys of %s" % a)
	var joy: Dictionary = {&"bar_1": JOY_BUTTON_A, &"bar_2": JOY_BUTTON_X, &"bar_3": JOY_BUTTON_Y,
		&"bar_4": JOY_BUTTON_B, &"bar_5": JOY_BUTTON_RIGHT_SHOULDER, &"bar_6": JOY_BUTTON_LEFT_SHOULDER,
		&"partner_special": JOY_BUTTON_DPAD_LEFT, &"partner_preset": JOY_BUTTON_DPAD_RIGHT,
		&"auto_attack_toggle": JOY_BUTTON_DPAD_DOWN}
	for a2: StringName in joy.keys():
		assert_true(_joy(joy[a2] as JoyButton).is_action_pressed(a2), "pad button of %s" % a2)
	assert_true(_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0).is_action_pressed(&"target_next"), "RT")
	assert_true(_axis(JOY_AXIS_TRIGGER_LEFT, 1.0).is_action_pressed(&"target_prev"), "LT")


func test_soft_target_framing() -> void:
	var to: Vector2 = Vector2(5, 0)                      # target 90° to the right of a camera looking down −z
	var none: Dictionary = CombatInput.framing_step(0.0, to, 1.0, false, 0.1)
	assert_false(bool(none["assisting"]), "camera moved in the last 1.5 s: no help")
	var step: Dictionary = CombatInput.framing_step(0.0, to, 2.0, false, 0.1)
	assert_true(bool(step["assisting"]), "> 40° off and 1.5 s idle: turn")
	assert_almost(absf(float(step["yaw"])), deg_to_rad(9.0), 0.0001, "at most 90°/s")
	var close: Dictionary = CombatInput.framing_step(0.0, Vector2(-1, -5), 2.0, false, 0.1)
	assert_false(bool(close["assisting"]), "within 40°: leave it")
	var keep: Dictionary = CombatInput.framing_step(0.0, Vector2(-3, -5), 2.0, true, 0.1)
	assert_true(bool(keep["assisting"]), "once turning, until within 25°")
	var done: Dictionary = CombatInput.framing_step(0.0, Vector2(-1, -5), 2.0, true, 0.1)
	assert_false(bool(done["assisting"]), "≤ 25°: stop")


func test_hud_sends_through_the_director() -> void:
	var data: GameData = FakeSim.load_data()
	var sim: RtSim = HudScenarios.build(data, {"level": 4})
	sim.call("set_tick", 42)
	sim.unit("p0").target_id = "e1"
	var rig: Dictionary = HudRig.make(self, sim, data)
	await wait_frames(2)
	var input: CombatInput = (rig["hud"] as Node).get("input") as CombatInput
	input.handle(_key(KEY_1))
	var dir: Node = rig["director"]
	var sub: Array = dir.get("submitted")
	assert_eq(sub.size(), 1, "CombatDirector.submit")
	assert_eq([str(sub[0]["t"]), int(sub[0]["ct"]), str(sub[0]["target"])], ["ability_use", 42, "e1"])
	assert_eq((dir.get("answers") as PackedStringArray)[0], "", "accepted by the sim")


func test_item_wheel_and_tactic_panel_send_commands() -> void:
	var data: GameData = FakeSim.load_data()
	var sim: RtSim = HudScenarios.build(data, {"level": 4, "items": {"itm_bandage": 2, "itm_antidote": 1}})
	sim.call("set_tick", 12)
	var rig: Dictionary = HudRig.make(self, sim, data)
	await wait_frames(2)
	var hud: Node = rig["hud"]
	var dir: Node = rig["director"]
	hud.call("open_wheel")
	var wheel: Control = hud.get("wheel") as Control
	assert_true(bool(wheel.call("is_open")), "right click / hold: the item wheel")
	var entries: Array = wheel.get("entries")
	assert_eq(entries.map(func(e: Dictionary) -> String: return str(e["id"])), ["itm_bandage", "itm_antidote"],
		"the combat's items in wheel order (rt.wheel)")
	wheel.call("choose", 1)
	var sub: Array = dir.get("submitted")
	assert_eq([str(sub[sub.size() - 1]["t"]), str(sub[sub.size() - 1]["item"])], ["combat_item", "itm_antidote"],
		"the chosen item")
	assert_false(bool(wheel.call("is_open")), "closed after the choice")
	hud.call("open_tactic")
	var tactic: Control = hud.get("tactic") as Control
	assert_true(bool(tactic.call("is_open")), "the chip opens tactic + switches (level ≥ 3)")
	(tactic.call("button", "preset:careful") as Button).pressed.emit()
	var c: Dictionary = (dir.get("submitted") as Array).back()
	assert_eq([str(c["t"]), str(c["u"]), str(c["preset"])], ["partner_preset", "p1", "careful"], "Vorsichtig")
	(tactic.call("button", "tog:potions") as Button).pressed.emit()
	var c2: Dictionary = (dir.get("submitted") as Array).back()
	assert_true(bool((c2["tog"] as Dictionary)["potions"]), "switch Tränke an")
	assert_eq(RtCommand.validate(c2), "", "schema-valid")
