extends TestCase
## R3 touch layout (07 §7.3, §12.5): thumb-group centres of the 1280 × 720 reference, hit areas ≥ 88 px, no two touch
## targets overlap (round buttons are circles: 07 checks centre distances), the stick zone only bottom left (x 0–40 %,
## y ≥ 320) and without `sneak`, tap ≠ drag (≤ 0.25 s and < 12 px = target pick, else camera drag), the shift with the
## display safe area (notch), long press = tooltip, hold = item wheel / previous target.

const HudRig := preload("res://tests/fixtures/rt_hud/hud_rig.gd")
const HudScenarios := preload("res://tests/fixtures/rt_hud/hud_scenarios.gd")
const FakeSim := preload("res://tests/fixtures/rt_min/fake_rt_sim.gd")
const CombatTouch := preload("res://scenes/combat/ui/combat_touch.gd")
const TouchScript := preload("res://scenes/ui/touch_controls.gd")
const TOUCH_SCENE: String = "res://scenes/ui/touch_controls.tscn"
## 07 §7.3: centre, hit size.
const EXPECT: Dictionary = {"slot1": [Vector2(1147, 587), 104.0], "slot2": [Vector2(1019, 634), 88.0],
	"slot3": [Vector2(1024, 530), 88.0], "slot4": [Vector2(1100, 459), 88.0], "slot5": [Vector2(1206, 460), 96.0],
	"slot6": [Vector2(907, 638), 88.0], "target": [Vector2(1227, 360), 88.0]}

var _size: Vector2i = Vector2i.ZERO


func before_each() -> void:
	Game.new_game(0, "Kai", 11)
	_size = tree.root.size
	tree.root.size = Vector2i(1280, 720)
	SafeAreaContainer.simulated_insets = {}
	TouchScript.test_now_ms = -1


func after_each() -> void:
	SafeAreaContainer.simulated_insets = {}
	TouchScript.test_now_ms = -1
	tree.root.size = _size
	Engine.time_scale = 1.0


func _touch_hud(level: int = 4) -> Dictionary:
	var data: GameData = FakeSim.load_data()
	var sim: RtSim = HudScenarios.build(data, {"level": level})
	return HudRig.make(self, sim, data, {"force_touch": true})


func _touch_layer() -> CanvasLayer:
	var tc: CanvasLayer = (load(TOUCH_SCENE) as PackedScene).instantiate() as CanvasLayer
	tc.call("setup", {"force_visible": true})
	var holder: Node = Node.new()
	add_to_tree(holder)
	holder.add_child(tc)
	return tc


func test_thumb_group_matches_07() -> void:
	var r: Dictionary = _touch_hud()
	await wait_frames(3)
	var hud: Node = r["hud"]
	assert_true(bool(hud.call("is_touch")), "touch layout")
	assert_false((hud.get("bar") as Control).visible, "no action bar with touch (thumb group instead)")
	var tu: Control = hud.get("touch_ui") as Control
	for n: String in EXPECT.keys():
		var spec: Array = EXPECT[n]
		var rect: Rect2 = tu.call("hit_rect", n) as Rect2
		assert_true(rect.size.x > 0.0, "%s shown" % n)
		assert_almost(rect.get_center().distance_to(spec[0] as Vector2), 0.0, 0.6, "%s centre (07 §7.3)" % n)
		assert_almost(rect.size.x, float(spec[1]), 0.01, "%s hit size" % n)
		assert_true(rect.size.x >= 88.0 and rect.size.y >= 88.0, "%s ≥ 88 px" % n)
		assert_true(rect.get_center().distance_to(Vector2(1147, 587)) <= 250.0 or n == "target",
			"%s within the thumb radius of slot 1" % n)
	var frames: Control = hud.get("frames") as Control
	var sp: Rect2 = frames.call("hit_rect", "special") as Rect2
	assert_almost(sp.get_center().distance_to(Vector2(300, 192)), 0.0, 0.6, "Partner-Spezial at (300, 192)")
	assert_almost(sp.size.x, 88.0, 0.01, "Partner-Spezial hit 88")
	var chip: Rect2 = frames.call("hit_rect", "chip") as Rect2
	assert_eq(chip, Rect2(24, 232, 168, 88), "tactic chip: 168 × 88 between the partner frame and the stick zone")


func test_no_two_touch_targets_overlap() -> void:
	var r: Dictionary = _touch_hud()
	var tc: CanvasLayer = _touch_layer()
	tc.call("set_combat_mode", true, Callable(), Callable())
	await wait_frames(3)
	var hud: Node = r["hud"]
	var tu: Control = hud.get("touch_ui") as Control
	var frames: Control = hud.get("frames") as Control
	var circles: Dictionary = {}
	for n: String in EXPECT.keys():
		var rc: Rect2 = tu.call("hit_rect", n) as Rect2
		circles[n] = [rc.get_center(), rc.size.x * 0.5]
	var sp: Rect2 = frames.call("hit_rect", "special") as Rect2
	circles["special"] = [sp.get_center(), sp.size.x * 0.5]
	var rects: Dictionary = {}
	for n2: String in ["ctl_frame", "partner_frame", "chip"]:
		rects[n2] = frames.call("hit_rect", n2) as Rect2
	rects["pause"] = ((tc.get("buttons") as Dictionary)[&"pause"] as Control).get_global_rect()
	rects["stick"] = tc.call("stick_zone") as Rect2
	var names: Array = circles.keys()
	for i in names.size():
		for j in range(i + 1, names.size()):
			var a: Array = circles[names[i]]
			var b: Array = circles[names[j]]
			assert_true((a[0] as Vector2).distance_to(b[0] as Vector2) >= float(a[1]) + float(b[1]) - 0.01,
				"%s / %s: centre distance ≥ sum of the half hit sizes" % [names[i], names[j]])
		for rn: String in rects.keys():
			assert_false(_circle_hits_rect(circles[names[i]] as Array, rects[rn] as Rect2),
				"%s does not overlap %s" % [names[i], rn])
	var rn_list: Array = rects.keys()
	for i2 in rn_list.size():
		for j2 in range(i2 + 1, rn_list.size()):
			assert_false((rects[rn_list[i2]] as Rect2).intersects(rects[rn_list[j2]] as Rect2),
				"%s / %s do not overlap" % [rn_list[i2], rn_list[j2]])


static func _circle_hits_rect(c: Array, r: Rect2) -> bool:
	if r.size.x <= 0.0:
		return false
	var p: Vector2 = c[0]
	var q: Vector2 = Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
	return p.distance_to(q) < float(c[1]) - 0.01


func test_stick_zone_bottom_left_without_sneak() -> void:
	var tc: CanvasLayer = _touch_layer()
	await wait_frames(2)
	var js: Control = tc.get("joystick") as Control
	assert_eq(tc.call("stick_zone") as Rect2, Rect2(0, 0, 512, 720), "exploration: the whole left 40 %")
	tc.call("set_combat_mode", true, Callable(), Callable())
	await wait_frames(1)
	assert_eq(tc.call("stick_zone") as Rect2, Rect2(0, 320, 512, 400), "combat: x 0–512, y 320–720 (07 §7.3)")
	assert_false(bool(js.get("allow_sneak")), "no sneak in combat")
	var buttons: Dictionary = tc.get("buttons")
	assert_false((buttons[&"action"] as Control).visible, "the action button gives way to slot 1")
	assert_false((buttons[&"map"] as Control).visible, "no map in combat")
	assert_true((buttons[&"pause"] as Control).visible, "pause stays")
	var above: Vector2 = js.get_global_transform_with_canvas().affine_inverse() * Vector2(100, 150)
	assert_false(bool(js.call("accepts", above)), "above y 320 the stick does not start")
	var down: InputEventScreenTouch = _touch(0, Vector2(150, 560), true)
	tc.call("_input", down)
	assert_true(bool(js.get("active")), "bottom left starts the stick")
	tc.call("_input", _drag(0, Vector2(150 + 30, 560), Vector2(30, 0)))
	assert_false(Input.is_action_pressed(&"sneak"), "small deflection: still no sneak (always run, 07 §7.3)")
	assert_true(Input.is_action_pressed(&"move_right"), "it moves")
	tc.call("_input", _touch(0, Vector2(180, 560), false))
	assert_false(Input.is_action_pressed(&"move_right"), "released")
	tc.call("set_combat_mode", false, Callable(), Callable())
	await wait_frames(1)
	assert_true(bool(js.get("allow_sneak")), "exploration: sneak again")
	assert_true((buttons[&"action"] as Control).visible and (buttons[&"map"] as Control).visible, "buttons back")


func _touch(index: int, pos: Vector2, pressed: bool) -> InputEventScreenTouch:
	var t: InputEventScreenTouch = InputEventScreenTouch.new()
	t.index = index
	t.position = pos
	t.pressed = pressed
	return t


func _drag(index: int, pos: Vector2, rel: Vector2) -> InputEventScreenDrag:
	var d: InputEventScreenDrag = InputEventScreenDrag.new()
	d.index = index
	d.position = pos
	d.relative = rel
	return d


func test_tap_is_not_a_drag() -> void:
	var tc: CanvasLayer = _touch_layer()
	await wait_frames(2)
	var taps: Array[Vector2] = []
	var drags: Array[Vector2] = []
	var blocked: Array[Rect2] = [Rect2(1000, 500, 200, 200)]
	tc.call("set_combat_mode", true, func(p: Vector2) -> void: taps.append(p),
		func(p: Vector2) -> bool: return blocked[0].has_point(p))
	var cb: Callable = func(rel: Vector2) -> void: drags.append(rel)
	Events.camera_drag.connect(cb)
	TouchScript.test_now_ms = 1000
	tc.call("_input", _touch(1, Vector2(800, 300), true))
	TouchScript.test_now_ms = 1200
	tc.call("_input", _drag(1, Vector2(805, 304), Vector2(5, 4)))
	tc.call("_input", _touch(1, Vector2(805, 304), false))
	assert_eq(taps.size(), 1, "≤ 0.25 s and < 12 px: a tap (target pick)")
	assert_eq(drags.size(), 0, "a tap never turns the camera")
	TouchScript.test_now_ms = 2000
	tc.call("_input", _touch(1, Vector2(800, 300), true))
	tc.call("_input", _drag(1, Vector2(806, 300), Vector2(6, 0)))
	assert_eq(drags.size(), 0, "under 12 px: no drag yet")
	tc.call("_input", _drag(1, Vector2(815, 300), Vector2(9, 0)))
	tc.call("_input", _drag(1, Vector2(830, 300), Vector2(15, 0)))
	assert_eq(drags.size(), 2, "from the frame it passes 12 px: camera drag")
	TouchScript.test_now_ms = 2100
	tc.call("_input", _touch(1, Vector2(830, 300), false))
	assert_eq(taps.size(), 1, "a drag is no tap")
	TouchScript.test_now_ms = 3000
	tc.call("_input", _touch(1, Vector2(700, 200), true))
	TouchScript.test_now_ms = 3300
	tc.call("_input", _touch(1, Vector2(700, 200), false))
	assert_eq(taps.size(), 1, "held longer than 0.25 s: no tap")
	tc.call("_input", _touch(2, Vector2(1100, 600), true))
	tc.call("_input", _touch(2, Vector2(1100, 600), false))
	assert_eq(taps.size(), 1, "a combat control's point is left to the GUI")
	Events.camera_drag.disconnect(cb)


func test_safe_area_shifts_everything() -> void:
	var r: Dictionary = _touch_hud()
	var tc: CanvasLayer = _touch_layer()
	tc.call("set_combat_mode", true, Callable(), Callable())
	await wait_frames(3)
	var hud: Node = r["hud"]
	var tu: Control = hud.get("touch_ui") as Control
	var frames: Control = hud.get("frames") as Control
	SafeAreaContainer.simulated_insets = {"left": 48, "top": 0, "right": 48, "bottom": 20}
	tree.root.size_changed.emit()
	await wait_frames(3)
	for n: String in EXPECT.keys():
		var c: Vector2 = (tu.call("hit_rect", n) as Rect2).get_center()
		assert_almost(c.distance_to((EXPECT[n] as Array)[0] as Vector2 + Vector2(-48, -20)), 0.0, 0.6,
			"%s moves with the notch insets" % n)
	var sp: Vector2 = (frames.call("hit_rect", "special") as Rect2).get_center()
	assert_almost(sp.distance_to(Vector2(348, 192)), 0.0, 0.6, "left column moves right by the left inset")
	var zone: Rect2 = tc.call("stick_zone") as Rect2
	assert_almost(zone.position.x, 48.0, 0.01, "stick zone starts after the left inset")
	assert_almost(zone.end.y, 700.0, 0.01, "… and ends above the bottom inset")


func test_long_press_tooltip_and_holds() -> void:
	var r: Dictionary = _touch_hud()
	await wait_frames(3)
	var hud: Node = r["hud"]
	var tu: Control = hud.get("touch_ui") as Control
	var pressed: Array[int] = []
	var wheels: Array[int] = [0]
	var cycles: Array[bool] = []
	tu.connect("slot_pressed", func(s: int) -> void: pressed.append(s))
	tu.connect("wheel_requested", func() -> void: wheels[0] += 1)
	tu.connect("target_cycle", func(fwd: bool) -> void: cycles.append(fwd))
	var b1: Button = (tu.get("buttons") as Dictionary)["slot1"]
	b1.button_down.emit()
	b1.button_up.emit()
	assert_eq(pressed, [1] as Array[int], "a tap on slot 1 presses it")
	Engine.time_scale = 8.0
	var b3: Button = (tu.get("buttons") as Dictionary)["slot3"]
	b3.button_down.emit()
	await wait_until(func() -> bool: return str(tu.call("tooltip_shown")) != "", 600)
	assert_true(str(tu.call("tooltip_shown")).begins_with("Leinen-Fallstrick"), "long press: name, cost, cooldown")
	b3.button_up.emit()
	assert_eq(pressed, [1] as Array[int], "a long press triggers nothing")
	var b6: Button = (tu.get("buttons") as Dictionary)["slot6"]
	b6.button_down.emit()
	await wait_until(func() -> bool: return wheels[0] > 0, 600)
	b6.button_up.emit()
	assert_eq(pressed, [1] as Array[int], "holding the potion opens the wheel instead")
	var bt: Button = (tu.get("buttons") as Dictionary)["target"]
	bt.button_down.emit()
	bt.button_up.emit()
	bt.button_down.emit()
	await wait_until(func() -> bool: return cycles.size() >= 2, 600)
	bt.button_up.emit()
	assert_eq(cycles, [true, false] as Array[bool], "tap = next target, hold = previous")


func test_partner_button_and_frame_taps() -> void:
	var r: Dictionary = _touch_hud()
	await wait_frames(3)
	var hud: Node = r["hud"]
	var frames: Control = hud.get("frames") as Control
	var down: InputEventMouseButton = InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	var up: InputEventMouseButton = down.duplicate() as InputEventMouseButton
	up.pressed = false
	frames.call("_on_hit_input", down, "special")
	frames.call("_on_hit_input", up, "special")
	var sub: Array = (r["director"] as Node).get("submitted")
	assert_eq(str(sub[sub.size() - 1]["t"]), "partner_special", "tap on the partner button")
	frames.call("_on_hit_input", down, "partner_frame")
	frames.call("_on_hit_input", up, "partner_frame")
	assert_eq([str(sub[sub.size() - 1]["t"]), str(sub[sub.size() - 1]["target"])], ["target_change", "p1"],
		"tap on the partner frame = friendly target")
	assert_true(bool(hud.call("blocks_touch", Vector2(300, 192))), "TouchControls leaves the partner button alone")
	assert_false(bool(hud.call("blocks_touch", Vector2(640, 300))), "free space is a tap / drag area")
