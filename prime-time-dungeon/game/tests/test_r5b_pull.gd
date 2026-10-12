extends "res://tests/fixtures/rt_world/world_case.gd"
## The pull of a person outside a combat (07 §2.2, §7.1–§7.4, E34–E37; closes 07 §12.6 "Stand R5b-2a" (6)) on the real
## floor 1 (world fixture stream as the sim) and the RtKit world (real sim): the target per input scheme — keyboard
## Tab / Shift+Tab and the left click (free ground clears), pad RT (once per press; LT stays sneak, B clears), touch tap
## (free ground clears) — and the pull with a bar slot through ExplorationScene.pull: keys 1–5, the pad's A in slot 1's
## range (else the field ability) and X / Y, the touch action button with slot 1's symbol; the advantage of the 07 §2.2
## table, Graf Mopsula's bark → pull = Erstschlag (the bark picks the target, E35), refusals (no target, range, MP, no
## opener, not learned), interaction priority, no pull in safe / stairs rooms, during a dialog or a combat, the sleeping
## tutorial group by pull for both heroes (its cards, E37; slot 1 + SHOW only), the target frame and the pull hint (the
## frame steps aside for a far lead), the project's input map and the legacy map (CombatInput.apply_input_mode(false):
## no campaign run uses it since R5b part 2b — kept for a screen that wants Tab for the map), the exploration's bar =
## the combat's, and Game.replay_log of a run with a person's pull.

const PullRules := preload("res://scenes/exploration/pull_rules.gd")
const HintCards := preload("res://scenes/combat/ui/hint_cards.gd")
const TouchScript := preload("res://scenes/ui/touch_controls.gd")
const InputGlyphScript := preload("res://scenes/ui/input_glyph.gd")
const KIT_CELL: Vector2i = Vector2i(3, 6)
const ROOM: Vector2i = Vector2i(1, 4)          # f1_g1's room on the real floor 1 (seed 4242): N E S doors
const ROOM_3: Vector2i = Vector2i(1, 3)        # f1_g3's room


func before_each() -> void:
	super()
	ExplorationScene.pull_taught = false
	CombatInput.apply_input_mode(true)


func after_each() -> void:
	ExplorationScene.pull_taught = false
	TouchScript.test_now_ms = -1
	Game.set_input_scheme(Game.InputScheme.KEYBOARD_MOUSE)
	Game.settings.combat_hints = true
	CombatInput.apply_input_mode(true)
	await super()


# --- helpers ---------------------------------------------------------------------------------------------------------

static func _key(code: Key, shift: bool = false) -> InputEventKey:
	var k: InputEventKey = InputEventKey.new()
	k.physical_keycode = code
	k.keycode = code
	k.shift_pressed = shift
	k.pressed = true
	return k


static func _joy(button: JoyButton, pressed: bool = true) -> InputEventJoypadButton:
	var j: InputEventJoypadButton = InputEventJoypadButton.new()
	j.button_index = button
	j.pressed = pressed
	return j


static func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var m: InputEventJoypadMotion = InputEventJoypadMotion.new()
	m.axis = axis
	m.axis_value = value
	return m


static func _click(pos: Vector2) -> InputEventMouseButton:
	var c: InputEventMouseButton = InputEventMouseButton.new()
	c.button_index = MOUSE_BUTTON_LEFT
	c.pressed = true
	c.position = pos
	return c


static func _touch(pos: Vector2, pressed: bool) -> InputEventScreenTouch:
	var t: InputEventScreenTouch = InputEventScreenTouch.new()
	t.index = 0
	t.position = pos
	t.pressed = pressed
	return t


static func _action(pressed: bool = true) -> InputEventAction:
	var a: InputEventAction = InputEventAction.new()
	a.action = &"action"
	a.pressed = pressed
	return a


## An input event through the exploration's own handler (the path of a key / pad / click outside the GUI).
func _send(ev: InputEvent) -> void:
	scene.call("_unhandled_input", ev)


## An input event through the player body (its `action`: keyboard F, pad A, the touch button).
func _player_input(ev: InputEvent) -> void:
	scene.get_player().call("_unhandled_input", ev)


## One exploration frame of the pull, synchronously: focus + prompt, the target check, the HUD model.
func _frame() -> void:
	scene.call("_update_focus")
	scene.call("_pull_frame")
	scene.call("_place_marker")


func _hud() -> ExplorationHud:
	return scene.get("_hud") as ExplorationHud


func _view() -> Control:
	return _hud().pull_target_view()


## Screen point of a lead's body (half its height).
func _screen_of(lead: Node3D) -> Vector2:
	var cam: Camera3D = scene.get_camera_rig().call("camera") as Camera3D
	return cam.unproject_position(lead.global_position + Vector3(0.0, 0.5, 0.0))


## Kai (or the hero) 2 m south of a lead in ROOM that faces it, the lead in `state` — in Kai's slot-1 reach.
func _face_off(state: StringName = &"PATROL", lead_dist: float = 2.0) -> Node3D:
	place_player(ROOM, Vector3(0.0, 0.0, lead_dist), 0.0)
	var a: Node3D = place_lead("f1_g1", ROOM, Vector3(0.0, 0.0, 0.0), PI)
	a.call("_set_state", state)
	return a


# --- keyboard / mouse (07 §7.1) ----------------------------------------------------------------------------------

func test_tab_cycles_the_leads_shift_tab_goes_back() -> void:
	await make_world()
	place_player(ROOM_3, Vector3(0.0, 0.0, 3.0), 0.0)                   # looking north (−z)
	place_lead("f1_g3", ROOM_3, Vector3(0.0, 0.0, -1.5), PI)            # ahead: inside the camera's ±60°, 4.5 m
	place_lead("f1_g1", ROOM_3, Vector3(3.0, 0.0, 3.0), 0.0)            # to the right: nearer (3 m), outside the cone
	await wait_frames(2)
	assert_false(_key(KEY_TAB).is_action_pressed(&"map"), "Tab is no map key in a real-time run (07 §7.1)")
	assert_eq(scene.pull_target_order(), PackedStringArray(["f1_g3", "f1_g1"]), "the camera's cone first (07 §7.4)")
	_send(_key(KEY_TAB))
	assert_eq(scene.pull_target(), "f1_g3", "Tab: the first lead")
	_send(_key(KEY_TAB))
	assert_eq(scene.pull_target(), "f1_g1", "Tab: the next one")
	_send(_key(KEY_TAB))
	assert_eq(scene.pull_target(), "f1_g3", "wraps")
	_send(_key(KEY_TAB, true))
	assert_eq(scene.pull_target(), "f1_g1", "Shift+Tab: back")
	assert_false(_hud().is_modal_open(), "no big map")
	assert_len(encounters(), 0, "choosing a target starts nothing")


func test_left_click_targets_a_lead_free_ground_clears() -> void:
	await make_world()
	place_player(ROOM_3, Vector3(0.0, 0.0, 3.0), 0.0)
	var a: Node3D = place_lead("f1_g3", ROOM_3, Vector3(0.5, 0.0, -1.0), PI)
	await wait_frames(3)
	var on: Vector2 = _screen_of(a)
	assert_true(Rect2(Vector2.ZERO, Vector2(scene.get_viewport().get_visible_rect().size)).has_point(on),
		"the lead is on screen: %s" % str(on))
	_send(_click(on))
	assert_eq(scene.pull_target(), "f1_g3", "a left click on the group targets its lead")
	_send(_click(Vector2(60.0, 690.0)))
	assert_eq(scene.pull_target(), "", "a click on free ground clears the target")
	var emu: InputEventMouseButton = _click(on)
	emu.device = InputEvent.DEVICE_ID_EMULATION
	_send(emu)
	assert_eq(scene.pull_target(), "", "an emulated click is the touch layer's (tap)")


func test_key_1_pulls_a_patrolling_lead_first_strike() -> void:
	await make_world()
	_face_off(&"PATROL")
	_send(_key(KEY_TAB))
	assert_eq(scene.pull_check(1), "", "Wuchtschlag reaches 2 m (2.5 m + the lead's radius)")
	_send(_key(KEY_1))
	assert_len(encounters(), 1, "key 1 pulls")
	if encounters().is_empty():
		return
	var cmd: Dictionary = encounters()[0]
	assert_eq(int(cmd["adv"]), Rules.PREEMPTIVE, "a patrolling lead: Erstschlag (07 §2.2)")
	assert_eq((cmd["rt"] as Dictionary)["open"], {"kind": "skill", "u": "p0", "skill": "skl_kai_heavy_swing",
		"target": "e0"}, "the slot-1 skill opens the combat (RtSetup.rt_opener)")
	assert_eq(RtCommand.validate(cmd), "", "the bot's encounter command")
	assert_true(director.is_running())
	assert_eq(scene.pull_target(), "", "in a combat the target is the sim's")
	assert_true(ExplorationScene.pull_taught, "the first pull of the session: the hint is learned")
	_send(_key(KEY_TAB))
	_send(_key(KEY_1))
	assert_eq(scene.pull_target(), "", "no target selection while a combat runs")
	assert_len(encounters(), 1, "no second pull while a combat runs")


func test_a_lead_that_sees_the_figure_is_a_normal_start_from_behind_a_first_strike() -> void:
	await make_world()
	var a: Node3D = _face_off(&"ALERT")
	assert_eq(scene.pull_advantage("f1_g1"), Rules.NORMAL, "ALERT and facing the figure: NORMAL")
	a.call("face", 0.0)
	assert_eq(scene.pull_advantage("f1_g1"), Rules.PREEMPTIVE, "the figure behind the lead: Erstschlag")
	a.call("_set_state", &"CHASE")
	assert_eq(scene.pull_advantage("f1_g1"), Rules.PREEMPTIVE, "CHASE but from behind")
	a.call("face", PI)
	a.call("_set_state", &"IDLE")
	assert_eq(scene.pull_advantage("f1_g1"), Rules.PREEMPTIVE, "IDLE: caught first from every side")
	a.call("_set_state", &"CHASE")
	assert_true(scene.set_pull_target("f1_g1"))
	_send(_key(KEY_1))
	assert_len(encounters(), 1)
	if not encounters().is_empty():
		assert_eq(int(encounters()[0]["adv"]), Rules.NORMAL, "a chasing lead that sees the figure: NORMAL")


func test_refusals_without_target_out_of_range_without_mp_no_opener_not_learned() -> void:
	await make_world()
	place_player(ROOM, Vector3(0.0, 0.0, 3.0), 0.0)
	var a: Node3D = place_lead("f1_g1", ROOM, Vector3(0.0, 0.0, -3.0), PI)
	a.call("_set_state", &"PATROL")
	await wait_frames(1)
	_send(_key(KEY_1))
	assert_eq(str(_view().call("refusal_text")), "Kein Ziel (Tab)", "no target: the key that chooses one")
	assert_true(scene.set_pull_target("f1_g1"))
	_send(_key(KEY_1))
	assert_eq(scene.pull_check(1), "range", "6 m: beyond Wuchtschlag")
	assert_eq(str(_view().call("refusal_text")), "Zu weit weg")
	place_lead("f1_g1", ROOM, Vector3(0.0, 0.0, 1.0), PI)
	var kai: PartyMember = Game.state.member("kai")
	var mp: int = kai.mp
	kai.mp = 0
	_send(_key(KEY_1))
	assert_eq(str(_view().call("refusal_text")), "Nicht genug MP", "the member's MP (Wuchtschlag costs MP)")
	kai.mp = mp
	kai.level = 2                                  # slot 2: Spott (self) — no ability aimed at the lead
	_send(_key(KEY_2))
	assert_eq(scene.pull_check(2), "no_opener")
	assert_eq(str(_view().call("refusal_text")), "Damit eröffnest du keinen Kampf")
	_send(_key(KEY_4))
	assert_eq(scene.pull_check(4), "not_learned", "slot 4 comes with level 4")
	assert_eq(str(_view().call("refusal_text")), "Noch nicht gelernt")
	assert_len(encounters(), 0, "every refusal starts nothing")
	assert_false(ExplorationScene.pull_taught)


# --- gamepad (07 §7.2) -----------------------------------------------------------------------------------------------

func test_pad_rt_targets_once_per_press_lt_stays_sneak_b_clears() -> void:
	await make_world()
	Game.set_input_scheme(Game.InputScheme.GAMEPAD)
	place_player(ROOM_3, Vector3(0.0, 0.0, 3.0), 0.0)
	place_lead("f1_g3", ROOM_3, Vector3(0.0, 0.0, -1.5), PI)
	place_lead("f1_g1", ROOM_3, Vector3(3.0, 0.0, 3.0), 0.0)
	await wait_frames(2)
	_send(_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0))
	assert_eq(scene.pull_target(), "f1_g3", "RT: the next target")
	_send(_axis(JOY_AXIS_TRIGGER_RIGHT, 0.8))
	assert_eq(scene.pull_target(), "f1_g3", "still held: one step per press")
	_send(_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0))
	_send(_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0))
	assert_eq(scene.pull_target(), "f1_g1", "pressed again: the next one")
	_send(_axis(JOY_AXIS_TRIGGER_LEFT, 1.0))
	assert_eq(scene.pull_target(), "f1_g1", "LT stays `sneak` in the exploration (no previous target)")
	_send(_joy(JOY_BUTTON_B))
	assert_eq(scene.pull_target(), "", "B drops the target (E36)")
	_send(_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0))
	_send(_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0))
	assert_eq(scene.pull_target(), "f1_g3")
	scene.open_stairs_dialog()
	_send(_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0))                         # let go while the dialog is open
	scene.active_dialog().call("cancel")
	await wait_frames(2)
	_send(_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0))
	assert_eq(scene.pull_target(), "f1_g1", "the press after the dialog steps")


func test_pad_a_pulls_in_slot_one_range_else_the_field_strike() -> void:
	await make_world()
	Game.set_input_scheme(Game.InputScheme.GAMEPAD)
	var a: Node3D = _face_off(&"PATROL", 5.0)
	assert_true(scene.set_pull_target("f1_g1"))
	_player_input(_joy(JOY_BUTTON_A))
	assert_true(scene.get_player().is_striking(), "out of slot 1's range: A is the field strike")
	assert_true(await wait_until(func() -> bool: return not scene.get_player().is_striking(), 240), "swing over")
	assert_len(encounters(), 0, "the strike hit nothing")
	place_lead("f1_g1", ROOM, Vector3(0.0, 0.0, 3.0), PI)
	a.call("_set_state", &"PATROL")
	assert_eq(scene.pull_check(1), "", "2 m: in range")
	_player_input(_joy(JOY_BUTTON_A))
	assert_len(encounters(), 1, "in range: A pulls with slot 1")
	if not encounters().is_empty():
		assert_eq(str(((encounters()[0]["rt"] as Dictionary)["open"] as Dictionary).get("skill", "")),
			"skl_kai_heavy_swing")
		assert_eq(int(encounters()[0]["adv"]), Rules.PREEMPTIVE)


func test_pad_x_y_pull_with_slots_two_and_three() -> void:
	await make_world()
	Game.set_input_scheme(Game.InputScheme.GAMEPAD)
	Game.state.member("kai").level = 3              # slot 2 Spott, slot 3 Leinen-Lasso (8 m)
	_face_off(&"IDLE", 6.0)
	_send(_joy(JOY_BUTTON_Y))
	assert_len(encounters(), 0, "Y without a target does nothing")
	assert_true(scene.set_pull_target("f1_g1"))
	_send(_joy(JOY_BUTTON_X))
	assert_eq(str(_view().call("refusal_text")), "Damit eröffnest du keinen Kampf", "X: slot 2 (Spott) cannot open")
	_send(_joy(JOY_BUTTON_Y))
	assert_len(encounters(), 1, "Y: slot 3 pulls from 6 m")
	if not encounters().is_empty():
		assert_eq(str(((encounters()[0]["rt"] as Dictionary)["open"] as Dictionary).get("skill", "")),
			"skl_kai_leash_trip")


func test_an_interaction_prompt_keeps_its_priority() -> void:
	await make_world()
	Game.set_input_scheme(Game.InputScheme.GAMEPAD)
	var layout: FloorLayout = scene.get_layout()
	var ch: ChestSpawn = null
	for c: ChestSpawn in layout.chests:
		if c.type != "locked" and layout.cell_at(c.cell).kind == RoomCell.Kind.NORMAL:
			ch = c
			break
	assert_not_null(ch, "a closed chest in a normal room")
	if ch == null:
		return
	var it: Node3D = scene.get_interactable(ch.id) as Node3D
	var center: Vector3 = layout.cell_to_world(ch.cell)
	var away: Vector3 = Rules.flat_dir(it.global_position, center)
	var stand: Vector3 = it.global_position + away * 1.3
	place_player(ch.cell, stand - center, yaw_to(stand, it.global_position))
	var side: Vector3 = Vector3(-away.z, 0.0, away.x)
	var lead: Node3D = place_lead("f1_g1", ch.cell, stand - center + side * 1.8, 0.0)
	lead.call("_set_state", &"IDLE")
	_frame()
	assert_true(scene.focused_interactable() == it, "the chest is focused (prompt)")
	assert_true(scene.set_pull_target("f1_g1"))
	assert_eq(scene.pull_check(1), "", "the lead is in slot 1's range")
	_player_input(_joy(JOY_BUTTON_A))
	assert_true(Game.state.floor_run.opened_chests.has(ch.id), "A opens the chest (the prompt has priority)")
	assert_len(encounters(), 0, "no pull")


# --- touch (07 §7.3) -------------------------------------------------------------------------------------------------

func test_touch_tap_targets_free_ground_clears_the_action_button_pulls() -> void:
	await make_world()
	var touch: CanvasLayer = _hud().touch
	touch.set("force_visible", true)
	touch.call("refresh_visibility")
	Game.set_input_scheme(Game.InputScheme.TOUCH)
	TouchScript.test_now_ms = 1000
	var a: Node3D = _face_off(&"PATROL")
	await wait_frames(3)
	var on: Vector2 = _screen_of(a)
	assert_gt(on.x, 520.0, "the lead is on the camera side (right of the stick zone)")
	touch.call("_input", _touch(on, true))
	touch.call("_input", _touch(on, false))
	assert_eq(scene.pull_target(), "f1_g1", "a tap on the group targets its lead")
	_frame()
	assert_eq(str(touch.call("action_symbol")), "pull:skl_kai_heavy_swing", "the action button shows slot 1")
	assert_false(bool(_view().call("hint_shown")), "touch: no hint pill, the button carries slot 1 (E37)")
	touch.call("_input", _touch(Vector2(760.0, 120.0), true))
	touch.call("_input", _touch(Vector2(760.0, 120.0), false))
	assert_eq(scene.pull_target(), "", "a tap on free ground clears it")
	_frame()
	assert_eq(str(touch.call("action_symbol")), "fist", "back to Kai's field strike")
	touch.call("_input", _touch(on, true))
	touch.call("_input", _touch(on, false))
	assert_eq(scene.pull_target(), "f1_g1")
	_player_input(_action())
	assert_len(encounters(), 1, "the action button pulls with slot 1")
	if not encounters().is_empty():
		assert_eq(int(encounters()[0]["adv"]), Rules.PREEMPTIVE)
		assert_eq(str(((encounters()[0]["rt"] as Dictionary)["open"] as Dictionary).get("skill", "")),
			"skl_kai_heavy_swing")


func test_touch_out_of_range_the_button_refuses() -> void:
	await make_world()
	Game.set_input_scheme(Game.InputScheme.TOUCH)
	_face_off(&"PATROL", 5.0)
	assert_true(scene.set_pull_target("f1_g1"))
	_player_input(_action())
	assert_len(encounters(), 0, "out of range: no pull")
	assert_false(scene.get_player().is_striking(), "with a target the button is the pull, never the strike")
	assert_eq(str(_view().call("refusal_text")), "Zu weit weg")


# --- Graf Mopsula: bark → pull = Erstschlag (07 §2.2, E7, E35) ---------------------------------------------------

func test_mopsula_barks_then_key_1_is_a_first_strike() -> void:
	await make_world("win", 300, "mopsula")
	var a: Node3D = _face_off(&"ALERT", 3.0)
	assert_eq(scene.pull_advantage("f1_g1"), Rules.NORMAL, "the group has seen the Count: no first strike")
	assert_eq(scene.bark_now(), 1, "the bark dazes the group")
	assert_true(bool(a.call("is_dazed")))
	assert_eq(scene.pull_target(), "f1_g1", "the bark picks the dazed lead (E35)")
	assert_eq(scene.pull_advantage("f1_g1"), Rules.PREEMPTIVE, "DAZED: caught first from every side")
	_frame()
	assert_eq(str(_view().call("state_text")), "verdutzt · Erstschlag!", "the target frame says it")
	_send(_key(KEY_1))
	assert_len(encounters(), 1, "key 1 pulls")
	if encounters().is_empty():
		return
	var cmd: Dictionary = encounters()[0]
	assert_eq(int(cmd["adv"]), Rules.PREEMPTIVE, "bark → pull = Erstschlag")
	assert_eq(str(cmd.get("opener", "")), "bark", "the first strike came from the bark (stats, bets)")
	assert_eq(str(((cmd["rt"] as Dictionary)["open"] as Dictionary).get("skill", "")), "skl_mop_noble_flame")
	assert_eq(str(((cmd["rt"] as Dictionary)["open"] as Dictionary).get("u", "")),
		"p%d" % DB.party_member("mopsula").battle_slot, "the Count's unit opens")


func test_the_barks_target_goes_with_the_daze_a_chosen_one_stays() -> void:
	await make_world("win", 300, "mopsula")
	var a: Node3D = _face_off(&"PATROL", 3.0)
	scene.bark_now()
	assert_eq(scene.pull_target(), "f1_g1")
	a.call("_set_state", &"RETURN")                  # the daze is over
	scene.call("_pull_frame")
	assert_eq(scene.pull_target(), "", "a target the bark picked goes with the daze")
	assert_true(scene.set_pull_target("f1_g1"))
	a.call("_set_state", &"PATROL")
	a.set("_daze_cool", 0.0)
	scene.bark_now()
	a.call("_set_state", &"RETURN")
	scene.call("_pull_frame")
	assert_eq(scene.pull_target(), "f1_g1", "a target the person chose stays")


func test_the_pad_a_a_and_the_touch_button_twice_bark_then_pull() -> void:
	await make_world("win", 300, "mopsula")
	Game.set_input_scheme(Game.InputScheme.GAMEPAD)
	_face_off(&"ALERT", 3.0)
	_player_input(_joy(JOY_BUTTON_A))
	assert_eq(scene.pull_target(), "f1_g1", "A barks (no target yet) and the bark picks the lead")
	assert_len(encounters(), 0)
	_player_input(_joy(JOY_BUTTON_A))
	assert_len(encounters(), 1, "A again: the pull with slot 1 (Adelsflamme, 20 m)")
	if not encounters().is_empty():
		assert_eq(int(encounters()[0]["adv"]), Rules.PREEMPTIVE)


# --- where and when (07 §2.4, E34) ----------------------------------------------------------------------------------

func test_no_pull_in_a_safe_room_or_the_stairs_room() -> void:
	await make_world()
	var layout: FloorLayout = scene.get_layout()
	var safe: Vector2i = Vector2i(-1, -1)
	for key: Variant in layout.cells.keys():
		if layout.cell_at(key as Vector2i).kind == RoomCell.Kind.SAFE:
			safe = key as Vector2i
			break
	assert_ne(safe, Vector2i(-1, -1), "floor 1 has a safe room")
	for cell: Vector2i in [safe, Vector2i(1, 0)]:
		place_player(cell, Vector3(0.0, 0.0, 2.0), 0.0)
		place_lead("f1_g1", cell, Vector3(0.0, 0.0, 0.5), PI)
		assert_false(scene.pull_room_allowed(cell), "%s: no pull here" % str(cell))
		assert_eq(scene.pull_candidates(), PackedStringArray(), "%s: no candidates" % str(cell))
		_send(_key(KEY_TAB))
		assert_eq(scene.pull_target(), "", "%s: Tab finds nothing" % str(cell))
		assert_false(scene.set_pull_target("f1_g1"))
		assert_false(scene.pull("f1_g1", "skill", "skl_kai_heavy_swing"), "%s: not even the bot's pull" % str(cell))
	assert_len(encounters(), 0)


func test_no_pull_during_a_dialog() -> void:
	await make_world()
	_face_off(&"PATROL")
	_send(_key(KEY_TAB))
	assert_eq(scene.pull_target(), "f1_g1")
	scene.open_stairs_dialog()
	assert_true(scene.is_modal())
	_send(_key(KEY_1))
	assert_false(scene.pull_slot(1), "a dialog blocks the pull")
	assert_len(encounters(), 0)
	scene.active_dialog().call("cancel")
	await wait_frames(2)
	_send(_key(KEY_1))
	assert_len(encounters(), 1, "after the dialog the key pulls again")


# --- the tutorial group (07 §2.2 "Tutorial-Gruppe", §2.13, E21, E28, E37) --------------------------------------------

func test_the_tutorial_group_by_pull_kai() -> void:
	await _tutorial_pull("kai")


func test_the_tutorial_group_by_pull_mopsula() -> void:
	await _tutorial_pull("mopsula")


func _tutorial_pull(hero: String) -> void:
	await make_kit_world(hero)
	director.use_hud = true
	var tut: Node3D = scene.get_enemy("f1_g0")
	var center: Vector3 = scene.get_layout().cell_to_world(KIT_CELL)
	place_player(KIT_CELL, tut.global_position - center + Vector3(0.0, 0.0, 2.0), 0.0)
	assert_true(bool(tut.call("is_asleep")), "the tutorial group sleeps")
	_send(_key(KEY_TAB))
	assert_eq(scene.pull_target(), "f1_g0", "the sleeping group can be targeted")
	assert_eq(scene.pull_advantage("f1_g0"), Rules.PREEMPTIVE, "asleep: always caught first")
	_send(_key(KEY_1))
	assert_not_null(Game.combat, "key 1 wakes it: the tutorial combat (real sim)")
	if Game.combat == null:
		return
	assert_true(Game.combat.setup.tutorial)
	assert_eq(int(Game.combat.setup.advantage), Rules.PREEMPTIVE)
	var slot1: String = str(PullRules.bar_slots(Game.state.member(hero), DB.party_member(hero)).get(1, ""))
	assert_eq(str(Game.combat.setup.rt_opener.get("skill", "")), slot1, "the slot-1 skill opens")
	assert_true(HintCards.done_by_pull(Game.combat, "target"), "the target was chosen before")
	assert_true(HintCards.done_by_pull(Game.combat, "bar1"), "slot 1 opened the combat")
	assert_false(HintCards.done_by_pull(Game.combat, "show"), "SHOW and dodge still come")
	var hints: Node = director.hud.get("hints") as Node if director.hud != null else null
	assert_not_null(hints, "the combat HUD with its cards")
	if hints != null:
		assert_eq(str(hints.call("current")), "", "no 'target' / 'bar1' card after the pull (E37)")
	director.advance(30)
	assert_gt(Game.combat.tick() if Game.combat != null else 99, 0, "the combat runs (no card holds it)")


func test_the_tutorial_group_offers_slot_one_and_show_only() -> void:
	await make_kit_world("kai")
	var tut: Node3D = scene.get_enemy("f1_g0")
	var center: Vector3 = scene.get_layout().cell_to_world(KIT_CELL)
	place_player(KIT_CELL, tut.global_position - center + Vector3(0.0, 0.0, 2.0), 0.0)
	var kai_bar: Dictionary = PullRules.bar_slots(Game.state.member("kai"), DB.party_member("kai"))
	assert_eq(str(kai_bar.get(3, "")), "skl_kai_leash_trip", "the kit's Kai has slot 3 on level 1")
	_send(_key(KEY_TAB))
	assert_eq(scene.pull_target(), "f1_g0")
	_frame()
	var slots: Array[int] = []
	for s: Variant in scene.pull_frame_model().get("slots", []) as Array:
		slots.append(int((s as Dictionary)["slot"]))
	assert_eq(slots, [1, 5] as Array[int], "the tutorial combat's bar: slot 1 + SHOW (E28)")
	_send(_key(KEY_3))
	assert_null(Game.combat, "slot 3 does not open the tutorial combat")
	assert_eq(str(_view().call("refusal_text")), "Noch nicht gelernt")
	_send(_key(KEY_1))
	assert_not_null(Game.combat, "slot 1 does")
	if Game.combat != null:
		var bar: Array = Game.combat.bar(str(Game.combat.setup.rt_opener.get("u", ""))).keys()
		bar.sort()
		assert_eq(bar, [1, 5], "the same slots as the frame")


func test_the_field_strike_keeps_the_tutorial_cards() -> void:
	await make_kit_world("kai")
	var tut: Node3D = scene.get_enemy("f1_g0")
	var center: Vector3 = scene.get_layout().cell_to_world(KIT_CELL)
	place_player(KIT_CELL, tut.global_position - center + Vector3(0.0, 0.0, 1.2), 0.0)
	scene.perform_action()
	assert_true(await wait_until(func() -> bool: return Game.combat != null, 120), "the field strike starts it")
	if Game.combat == null:
		return
	assert_eq(str(Game.combat.setup.rt_opener.get("kind", "")), "strike")
	assert_false(HintCards.done_by_pull(Game.combat, "target"), "the strike's tutorial keeps every card")
	assert_false(HintCards.done_by_pull(Game.combat, "bar1"))


# --- the target frame, the hint, the input map (07 §7.7, E36, E37) -------------------------------------------------

func test_the_target_frame_and_the_pull_hint() -> void:
	await make_world()
	var hud: ExplorationHud = _hud()
	var hint: Node = hud.find_child("TargetHint", true, false)
	assert_not_null(hint, "the control hints name the target key")
	if hint != null:
		assert_eq(StringName(hint.get("action")), &"target_next")
		assert_eq(InputGlyphScript.binding_text(&"target_next", Game.InputScheme.KEYBOARD_MOUSE), "Tab")
	var a: Node3D = _face_off(&"PATROL")
	_send(_key(KEY_TAB))
	_frame()
	var view: Control = _view()
	assert_true(bool(view.call("is_shown")), "the target frame shows")
	assert_eq(str(view.call("state_text")), "auf Streife · Erstschlag!")
	assert_true(bool(view.call("hint_shown")), "the pull hint under the frame (E37)")
	assert_eq(hud.prompt_text(), "", "the interaction prompt stays the interactables'")
	var model: Dictionary = scene.pull_frame_model()
	assert_true(DB.has_id("enemies", str(model.get("lead", ""))), "the lead's combat unit")
	assert_eq(int(model.get("count", 0)), 3, "three units in enc_f1_a2")
	assert_eq((model["slots"] as Array).map(func(s: Dictionary) -> int: return int(s["slot"])), [1, 5],
		"Kai level 1: slot 1 and SHOW")
	place_lead("f1_g1", ROOM, Vector3(0.0, 0.0, -3.0), PI)
	a.call("_set_state", &"PATROL")
	_frame()
	assert_false(bool(view.call("hint_shown")), "out of slot 1's range: no hint")
	assert_eq(str((scene.pull_frame_model()["slots"] as Array)[0]["reason"]), "range", "the chip shows the range")
	place_lead("f1_g1", ROOM, Vector3(0.0, 0.0, 0.0), PI)
	Game.settings.combat_hints = false
	_frame()
	assert_false(bool(view.call("hint_shown")), "combat hints off: no pull hint")
	Game.settings.combat_hints = true
	_frame()
	assert_true(bool(view.call("hint_shown")), "on again")
	ExplorationScene.pull_taught = true
	_frame()
	assert_false(bool(view.call("hint_shown")), "after the first pull of the session the hint is learned")
	scene.set_pull_target("")
	_frame()
	assert_false(bool(view.call("is_shown")), "no target: no frame")


func test_the_frame_steps_aside_for_a_far_lead() -> void:
	await make_world("win", 300, "mopsula")                         # the Count pulls from afar (Adelsflamme 20 m)
	place_player(ROOM, Vector3(0.0, 0.0, 3.0), 0.0)
	var a: Node3D = place_lead("f1_g1", ROOM, Vector3(0.0, 0.0, 1.0), PI)
	a.call("_set_state", &"PATROL")
	assert_true(scene.set_pull_target("f1_g1"))
	var view: Control = _view()
	var centre: float = roundf((view.size.x - 300.0) * 0.5)
	var aside: bool = false
	for d: float in [2.0, 4.0, 5.5, 7.0, 8.0, 2.0]:
		place_lead("f1_g1", ROOM, Vector3(0.0, 0.0, 3.0 - d), PI)
		await wait_frames(1)
		_frame()
		view.call("_process", 1.0)                                  # the slide is over
		var mr: Rect2 = view.call("marker_rect")
		assert_true(mr.has_area(), "the lead is on screen (%.1f m)" % d)
		assert_false((view.call("block_rect") as Rect2).intersects(mr), "the frame never hides its lead (%.1f m)" % d)
		aside = aside or (view.call("frame_rect") as Rect2).position.x != centre
	assert_eq(scene.pull_target(), "f1_g1")
	assert_true(aside, "far away the lead stands high on the screen: the frame stepped aside")
	assert_eq((view.call("frame_rect") as Rect2).position.x, centre, "close again: back to the centre")


func test_the_projects_input_map_tab_and_y() -> void:
	var map: Dictionary = ProjectSettings.get_setting("input/map")
	var keys: Array = []
	var joys: Array = []
	for e: Variant in map["events"] as Array:
		if e is InputEventKey:
			keys.append(int((e as InputEventKey).physical_keycode))
		elif e is InputEventJoypadButton:
			joys.append(int((e as InputEventJoypadButton).button_index))
	assert_eq([keys, joys], [[KEY_M], [JOY_BUTTON_BACK]], "map: M and Back, Tab targets (07 §7.1, §7.7)")
	var auto: Dictionary = ProjectSettings.get_setting("input/toggle_auto")
	joys = []
	for e: Variant in auto["events"] as Array:
		if e is InputEventJoypadButton:
			joys.append(int((e as InputEventJoypadButton).button_index))
	assert_eq(joys, [JOY_BUTTON_DPAD_UP], "toggle_auto on the D-pad up, Y is slot 3 (07 §7.2)")
	var tab: InputEventKey = _key(KEY_TAB)
	CombatInput.apply_input_mode(true)
	assert_false(tab.is_action_pressed(&"map"), "real time: the project's map")
	assert_eq(InputMap.action_get_events(&"toggle_auto").size(), 2, "T + D-pad up (idempotent)")
	CombatInput.apply_input_mode(false)
	assert_true(tab.is_action_pressed(&"map"), "the legacy map: Tab opens the map")
	assert_true(_joy(JOY_BUTTON_Y).is_action_pressed(&"toggle_auto"), "… and Y toggles auto")
	assert_false(_joy(JOY_BUTTON_DPAD_UP).is_action_pressed(&"toggle_auto"))


# --- the rules (pure) ------------------------------------------------------------------------------------------------

func test_the_exploration_bar_is_the_combats() -> void:
	var loadouts: Dictionary = {"kai": [{}, {"2": "skl_kai_first_aid", "3": "skl_kai_cable_whip", "4":
		"skl_kai_deo_torch"}], "mopsula": [{}, {"2": "skl_mop_mass_lick", "3": "skl_mop_expert_opinion"}]}
	for hero: String in ["kai", "mopsula"]:
		var def: PartyMemberDef = DB.party_member(hero)
		for lvl in range(1, 11):
			for lo: Variant in loadouts[hero] as Array:
				var m: PartyMember = PartyMember.new()
				m.id = hero
				m.level = lvl
				m.rt_loadout = (lo as Dictionary).duplicate()
				assert_eq(PullRules.bar_slots(m, def), BattleBridge._rt_bar(def.rt, m),
					"%s level %d %s: the combat's bar" % [hero, lvl, str(lo)])


func test_openers_ranges_and_refusals() -> void:
	var sk: Callable = func(id: String) -> SkillDef: return DB.skill(id)
	assert_true(PullRules.is_opener(sk.call("skl_kai_heavy_swing")), "single enemy")
	assert_true(PullRules.is_opener(sk.call("skl_mop_noble_flame")))
	assert_true(PullRules.is_opener(sk.call("skl_stunt_kai_suplex")), "Kai's SHOW hits one enemy")
	assert_true(PullRules.is_opener(sk.call("skl_mop_inferno")), "an area at the target point")
	for id: String in ["skl_kai_taunt", "skl_mop_holy_lick", "skl_kai_sweep", "skl_mop_thunder_bark",
			"skl_stunt_mop_entrance"]:
		assert_false(PullRules.is_opener(sk.call(id)), "%s: no ability aimed at the lead" % id)
	assert_eq(PullRules.range_cm(sk.call("skl_kai_heavy_swing"), 250), 250)
	assert_eq(PullRules.range_cm(sk.call("skl_stunt_kai_suplex"), 250), 250)
	assert_eq(PullRules.range_cm(sk.call("skl_mop_noble_flame"), 1000), 2000)
	var hs: SkillDef = sk.call("skl_kai_heavy_swing")
	var cost: int = PullRules.mp_cost(hs)
	assert_gt(cost, 0, "Wuchtschlag costs MP")
	assert_eq(PullRules.refusal(hs, cost, 280, 250, 30), "", "range + radius is still in range")
	assert_eq(PullRules.refusal(hs, cost, 281, 250, 30), "range")
	assert_eq(PullRules.refusal(hs, cost - 1, 100, 250, 30), "mp")
	assert_eq(PullRules.refusal(sk.call("skl_kai_taunt"), 99, 100, 250, 30), "no_opener")
	assert_eq(PullRules.refusal(null, 99, 100, 250, 30), "not_learned")
	var cands: Array[Dictionary] = [{"id": "b", "pos": Vector3(0, 0, -5)}, {"id": "a", "pos": Vector3(3, 0, 0)},
		{"id": "c", "pos": Vector3(0, 0, 4)}, {"id": "d", "pos": Vector3(0, 0, -2)}]
	assert_eq(PullRules.tab_order(cands, Vector3.ZERO, Vector3(0, 0, -1)), PackedStringArray(["d", "b", "a", "c"]),
		"±60° of the camera by distance, then the rest by distance")
	assert_eq(PullRules.next_in(PackedStringArray(["d", "b"]), "", false), "b", "backwards from none: the last")
	assert_eq(PullRules.state_text(&"PATROL", true), "schläft", "asleep wins")
	assert_eq(PullRules.state_text(&"DAZED", false), "verdutzt")


# --- replay (07 §10.6) -----------------------------------------------------------------------------------------------

func test_a_run_with_a_persons_pull_replays_kai() -> void:
	await _replay_world("kai")
	var tut: Node3D = scene.get_enemy("f1_g0")
	var center: Vector3 = scene.get_layout().cell_to_world(KIT_CELL)
	place_player(KIT_CELL, tut.global_position - center + Vector3(0.0, 0.0, 2.0), 0.0)
	_send(_key(KEY_TAB))
	_send(_key(KEY_1))
	await _fight_and_replay("")


func test_a_run_with_a_persons_pull_replays_mopsula_bark() -> void:
	await _replay_world("mopsula")
	var tut: Node3D = scene.get_enemy("f1_g0")
	var center: Vector3 = scene.get_layout().cell_to_world(KIT_CELL)
	place_player(KIT_CELL, tut.global_position - center + Vector3(0.0, 0.0, 3.0), 0.0)
	assert_eq(scene.bark_now(), 1, "the Count barks at the sleeping group")
	assert_eq(scene.pull_target(), "f1_g0", "and it becomes the target")
	_send(_key(KEY_1))
	await _fight_and_replay("bark")


## The RtKit world (real sim) of a game whose hero is recorded from its start (Game.new_game with `hero`): make_world
## alone would set GameState.hero without a log entry.
func _replay_world(hero: String) -> void:
	set("_saved_data", DB.data)
	DB.data = RtKit.data()
	Game.new_game(0, "Kai", SEED, &"prime", hero)
	await make_world("win", 300, hero)
	Game.rt_sim_factory = Callable()


## The pull started the combat (opener `opener`): slot 1 every 1.5 s until it is over, then Game.replay_log and
## RunSim.replay of the run log reproduce the live run.
func _fight_and_replay(opener: String) -> void:
	assert_not_null(Game.combat, "the pull starts the combat with the real sim")
	if Game.combat == null:
		return
	assert_false(Game.combat is FakeRtSim)
	assert_eq(int(encounters()[0]["adv"]), Rules.PREEMPTIVE)
	assert_eq(str(encounters()[0].get("opener", "")), opener)
	assert_eq(str(((encounters()[0]["rt"] as Dictionary)["open"] as Dictionary).get("kind", "")), "skill")
	var ctl: String = director.controlled_unit()
	var slot1: String = str(Game.combat.bar(ctl).get(1, ""))
	for i in 5000:
		if not director.is_running():
			break
		if i % 45 == 0:
			director.submit(RtCommand.ability(0, ctl, slot1, ""))
		director.advance(1)
	# the live hash right after the combat's last tick: afterwards the exploration clock runs on without an entry
	var live: String = StateHash.of(Game.state)
	assert_not_null(director.last_result, "the combat ended")
	if director.last_result != null:
		assert_eq(int(director.last_result.outcome), BattleResult.Outcome.VICTORY)
	var res: Dictionary = Game.replay_log(Game.run_log)
	assert_eq(res["errors"], PackedStringArray(), "Game.replay_log takes every entry")
	assert_eq([res["mismatch_at"], res["combat_mismatch_at"]], [-1, -1], "every checkpoint matches")
	assert_eq(res["final_hash"], live, "Game.replay_log ≡ the live run with the person's pull")
	var core: Dictionary = RunSim.replay(DB.data, Game.run_log)
	assert_eq([core["errors"], core["combat_mismatch_at"]], [PackedStringArray(), -1], "the core verifier agrees")
