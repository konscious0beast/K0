extends TestCase
## R3 HUD layout (07 §8.1, §8.4–8.6, §8.8, §12.5): no two HUD elements overlap at 1280 × 720 and 1920 × 1080 (frames,
## status rows, Partner-Spezial, tactic chip, target / boss block, bar, player cast bar, subtitle slot, ShowOverlay in
## the combat mode with the clock chip), progressive disclosure (tutorial: slot 1 + SHOW; potion + Partner-Spezial from
## the 2nd fight; tactic chip from level 3; threat only after an own taunt; boss frame only for bosses), the pill "DU"
## (moves with a control switch), plates (projection, picking, threat dot), combat text, the screen modes.

const HudRig := preload("res://tests/fixtures/rt_hud/hud_rig.gd")
const HudScenarios := preload("res://tests/fixtures/rt_hud/hud_scenarios.gd")
const FakeSim := preload("res://tests/fixtures/rt_min/fake_rt_sim.gd")
const CombatView := preload("res://scenes/combat/ui/combat_view.gd")
const UnitFrames := preload("res://scenes/combat/ui/unit_frames.gd")
const CombatHudScript := preload("res://scenes/combat/ui/combat_hud.gd")
const CombatStyle := preload("res://scenes/combat/ui/combat_style.gd")
const OVERLAY_SCENE: String = "res://scenes/ui/show_overlay.tscn"
const DIALOG_SCENE: String = "res://scenes/ui/mod_dialog.tscn"

var _size: Vector2i = Vector2i.ZERO


func before_each() -> void:
	Game.new_game(0, "Kai", 11)
	_size = tree.root.size
	SafeAreaContainer.simulated_insets = {}


func after_each() -> void:
	tree.root.size = _size
	SafeAreaContainer.simulated_insets = {}
	CombatInput.apply_input_mode(true)             # the project map (07 §7.7, E36)
	Events.overlay_mode_requested.emit(&"hidden")


func _regular(level: int = 4, data: GameData = null) -> RtSim:
	var d: GameData = data if data != null else FakeSim.load_data()
	var sim: RtSim = HudScenarios.build(d, {"level": level, "enemies": ["enm_kanalratte", "enm_rt_test_caster",
		"enm_kanalratte"]})
	sim.unit("p0").target_id = "e1"
	sim.call("set_cast", "e1", "skl_e_test_hex", 20, 60, true, true)
	HudScenarios.add_status(sim, d, sim.unit("e1"), "sts_slow", 60, 120)
	HudScenarios.add_status(sim, d, sim.unit("p0"), "sts_guard", 90, 180)
	HudScenarios.add_status(sim, d, sim.unit("p1"), "sts_poison", 90, 180, 2)
	sim.call("set_cast", "p0", "skl_kai_heavy_swing", 10, 45)
	return sim


func _overlay() -> CanvasLayer:
	var o: CanvasLayer = (load(OVERLAY_SCENE) as PackedScene).instantiate() as CanvasLayer
	var holder: Node = Node.new()
	add_to_tree(holder)
	holder.add_child(o)
	return o


## Every element rect of the HUD (+ overlay) on screen now (HudRig.rects).
func _rects(hud: Node, overlay: CanvasLayer) -> Dictionary:
	return HudRig.rects(hud, overlay)


func _assert_no_overlap(rects: Dictionary, what: String) -> void:
	var names: Array = rects.keys()
	for i in names.size():
		for j in range(i + 1, names.size()):
			var a: Rect2 = rects[names[i]]
			var b: Rect2 = rects[names[j]]
			assert_false(a.intersects(b), "%s: %s %s overlaps %s %s" % [what, names[i], str(a), names[j], str(b)])


func test_no_overlaps_at_1280_and_1920() -> void:
	Game.state.floor_run.timer_started = true
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		tree.root.size = size
		var o: CanvasLayer = _overlay()
		var r: Dictionary = HudRig.make(self, _regular(), FakeSim.load_data(), {"modes": true})
		await wait_frames(4)
		var rects: Dictionary = _rects(r["hud"], o)
		assert_true(rects.has("clock_chip_rect"), "%s: the stopped clock shows in combat" % str(size))
		assert_true(rects.has("player_cast") and rects.has("special") and rects.has("chip"), "all elements shown")
		_assert_no_overlap(rects, "%dx%d regular" % [size.x, size.y])
		(r["hud"] as Node).free()
		var data: GameData = FakeSim.load_data()
		var boss: RtSim = HudScenarios.build(data, {"level": 6, "boss": true, "enemies": ["enm_rt_test_boss",
			"enm_kanalratte"]})
		boss.unit("p0").target_id = "e1"
		boss.call("set_cast", "e0", "skl_e_test_hex", 10, 60, true, true)
		var rb: Dictionary = HudRig.make(self, boss, data, {"modes": true})
		await wait_frames(4)
		var rects_b: Dictionary = _rects(rb["hud"], o)
		assert_true(rects_b.has("top_block"), "boss + add target")
		_assert_no_overlap(rects_b, "%dx%d boss" % [size.x, size.y])
		(rb["hud"] as Node).free()
		o.get_parent().remove_child(o)
		o.free()
		await wait_frames(2)


func test_phone_touch_layout_has_no_overlaps() -> void:
	tree.root.size = Vector2i(1600, 720)
	Game.state.floor_run.timer_started = true
	var o: CanvasLayer = _overlay()
	var d: CanvasLayer = (load(DIALOG_SCENE) as PackedScene).instantiate() as CanvasLayer
	var holder: Node = Node.new()
	add_to_tree(holder)
	holder.add_child(d)
	var r: Dictionary = HudRig.make(self, _regular(), FakeSim.load_data(), {"modes": true, "force_touch": true})
	await wait_frames(4)
	var rects: Dictionary = _rects(r["hud"], o)
	assert_false(rects.has("bar"), "touch: no action bar")
	var box: Rect2 = (d.get("_box") as Control).get_global_rect()
	assert_almost(box.get_center().x, 750.0, 0.6, "touch subtitle: centre − 50 (x 330–850 at 1280)")
	assert_almost(box.size.x, 520.0, 0.6, "touch subtitle 520 wide")
	rects["subtitle"] = box
	var hud: Node = r["hud"]
	var tu: Control = hud.get("touch_ui") as Control
	for n: String in ["slot1", "slot2", "slot3", "slot4", "slot5", "slot6", "target"]:
		var t: Rect2 = tu.call("hit_rect", n) as Rect2
		if t.size.x > 0.0:
			rects["touch_" + n] = Rect2(t.get_center() - Vector2.ONE * t.size.x * 0.35, Vector2.ONE * t.size.x * 0.7)
	var cast: Control = (hud.get("_frame") as Control).get_node("PlayerCast") as Control
	assert_almost(cast.get_global_rect().get_center().x, 750.0, 0.6,
		"touch cast bar: centre − 50 (x 590 at 1280, 07 §8.1)")
	_assert_no_overlap(rects, "1600x720 touch")


func test_progressive_disclosure() -> void:
	var data: GameData = FakeSim.load_data()
	var tut: RtSim = HudScenarios.build(data, {"level": 1, "tutorial": true})
	var r: Dictionary = HudRig.make(self, tut, data)
	await wait_frames(3)
	var hud: Node = r["hud"]
	var bar: Control = hud.get("bar") as Control
	var frames: Control = hud.get("frames") as Control
	assert_eq(bar.call("visible_slots"), [1, 5] as Array[int], "tutorial: slot 1 + SHOW")
	assert_eq(frames.call("hit_rect", "special") as Rect2, Rect2(), "no Partner-Spezial in the tutorial")
	assert_eq(frames.call("hit_rect", "chip") as Rect2, Rect2(), "no tactic chip at level 1")
	assert_null((frames.call("model") as Dictionary)["boss"], "no boss frame outside boss fights")
	var second: RtSim = HudScenarios.build(data, {"level": 1})
	var r2: Dictionary = HudRig.make(self, second, data)
	await wait_frames(3)
	var bar2: Control = (r2["hud"] as Node).get("bar") as Control
	var frames2: Control = (r2["hud"] as Node).get("frames") as Control
	assert_eq(bar2.call("visible_slots"), [1, 5, 6] as Array[int], "fight 2: the potion")
	assert_ne(frames2.call("hit_rect", "special") as Rect2, Rect2(), "Graf Mopsula as partner: Partner-Spezial at 1")
	var kai_partner: RtSim = HudScenarios.build(data, {"level": 1, "hero": "mopsula"})
	var r3: Dictionary = HudRig.make(self, kai_partner, data)
	await wait_frames(3)
	var frames3: Control = (r3["hud"] as Node).get("frames") as Control
	assert_eq(frames3.call("hit_rect", "special") as Rect2, Rect2(), "Kai as partner: not before level 2")
	var lvl3: Dictionary = HudRig.make(self, HudScenarios.build(data, {"level": 3}), data)
	await wait_frames(3)
	assert_ne(((lvl3["hud"] as Node).get("frames") as Control).call("hit_rect", "chip") as Rect2, Rect2(),
		"tactic chip from level 3")


func test_threat_only_after_an_own_taunt() -> void:
	var data: GameData = FakeSim.load_data()
	var sim: RtSim = HudScenarios.build(data, {"level": 2})
	sim.unit("e0").target_id = "p0"
	var r: Dictionary = HudRig.make(self, sim, data)
	await wait_frames(3)
	var hud: Node = r["hud"]
	var frames: Control = hud.get("frames") as Control
	assert_false(bool(frames.get("threat_revealed")), "hidden at first")
	var ai: ActionEvent = ActionEvent.make(ActionEvent.Type.ACTION_START)
	ai.actor_id = "p1"
	ai.skill_id = "skl_kai_taunt"
	ai.by_ai = true
	hud.call("on_event", ai)
	assert_false(bool(frames.get("threat_revealed")), "an AI taunt reveals nothing")
	var own: ActionEvent = ActionEvent.make(ActionEvent.Type.ACTION_START)
	own.actor_id = "p0"
	own.skill_id = "skl_kai_taunt"
	hud.call("on_event", own)
	await wait_frames(2)
	assert_true(bool(frames.get("threat_revealed")), "the own taunt reveals the threat display")
	assert_true(bool((hud.get("plates") as Control).get("threat_revealed")), "… on the plates too")
	assert_eq(int((frames.call("model") as Dictionary)["aggro_ctl"]), 1, "aggro counter ×1 at Kai")
	Game.state.show.stats["taunts_total"] = 1
	var r2: Dictionary = HudRig.make(self, HudScenarios.build(data, {"level": 2}), data)
	await wait_frames(2)
	assert_true(bool(((r2["hud"] as Node).get("frames") as Control).get("threat_revealed")),
		"StatId taunts_total > 0: revealed from the start")


func test_pill_du_moves_with_the_control() -> void:
	var data: GameData = FakeSim.load_data()
	var sim: RtSim = HudScenarios.build(data, {"level": 2})
	var r: Dictionary = HudRig.make(self, sim, data)
	await wait_frames(3)
	var hud: Node = r["hud"]
	var frames: Control = hud.get("frames") as Control
	assert_true((frames.get_node("L_pill_ctl") as Label).visible, "pill DU at the hero's frame")
	assert_eq((frames.get_node("L_pill_ctl") as Label).text, "DU")
	assert_false((frames.get_node("L_pill_partner") as Label).visible)
	sim.unit("p0").hp = 0
	sim.call("set_controlled", "p1")
	var e: ActionEvent = ActionEvent.make(ActionEvent.Type.CONTROL_CHANGED)
	e.actor_id = "p0"
	e.target_id = "p1"
	hud.call("on_event", e)
	await wait_frames(2)
	assert_false((frames.get_node("L_pill_ctl") as Label).visible, "frames stay, the pill moves")
	assert_true((frames.get_node("L_pill_partner") as Label).visible)
	assert_true((frames.get_node("L_ctl_ko") as Label).visible, "K.O. at the hero's frame")
	assert_eq(str((hud.get("banner") as Node).call("current_title")), "KAMPF!", "the switch banner is queued")
	assert_gt(int((hud.get("banner") as Node).call("queued")), 0)


func test_boss_frame_target_below_and_enrage() -> void:
	var data: GameData = FakeSim.load_data()
	var sim: RtSim = HudScenarios.build(data, {"level": 6, "boss": true, "enemies": ["enm_rt_test_boss",
		"enm_kanalratte"]})
	sim.unit("p0").target_id = "e0"
	var r: Dictionary = HudRig.make(self, sim, data)
	await wait_frames(3)
	var frames: Control = (r["hud"] as Node).get("frames") as Control
	var fo: Vector2 = frames.get_global_rect().position
	assert_eq((frames.call("boss_rect") as Rect2).position.y + fo.y, 24.0, "boss frame at y 24")
	assert_eq((frames.call("boss_rect") as Rect2).size, Vector2(520, 36), "520 × 36")
	assert_null((frames.call("model") as Dictionary)["target"], "target = boss: no second frame")
	assert_true((frames.get_node("L_boss_enrage") as Label).visible, "enrage countdown in the last minute")
	assert_true((frames.get_node("L_boss_enrage") as Label).text.ends_with("in 0:30"), "rt.enrage.at_ms 30000")
	sim.unit("p0").target_id = "e1"
	await wait_frames(2)
	assert_eq((frames.call("target_rect") as Rect2).position.y + fo.y, 84.0, "an add as target: frame at y 84")
	assert_eq((frames.call("target_rect") as Rect2).size, Vector2(300, 56), "300 × 56")


func test_plates_project_pick_and_threat() -> void:
	var data: GameData = FakeSim.load_data()
	var sim: RtSim = HudScenarios.build(data, {"level": 2})
	sim.unit("p0").target_id = "e0"
	sim.unit("e1").target_id = "p1"
	Game.state.show.stats["taunts_total"] = 1
	var cam: Camera3D = Camera3D.new()
	var holder: Node3D = Node3D.new()
	add_to_tree(holder)
	holder.add_child(cam)
	cam.global_position = Vector3(0, 6, 8)
	cam.look_at(Vector3(0, 0, -2), Vector3.UP)
	cam.make_current()
	var r: Dictionary = HudRig.make(self, sim, data)
	(r["director"] as Node).set("positions", {"e0": Vector3(-2, 0, -3), "e1": Vector3(2, 0, -3),
		"p0": Vector3(0, 0, 3), "p1": Vector3(-1, 0, 4)})
	await wait_frames(3)
	var plates: Control = (r["hud"] as Node).get("plates") as Control
	var info: Dictionary = plates.get("plates")
	assert_eq(info.size(), 2, "a plate per living enemy")
	var head0: Vector2 = (info["e0"] as Dictionary)["head"]
	var h: float = float((r["director"] as Node).call("unit_height", "e0"))
	assert_almost(head0.distance_to(cam.unproject_position(Vector3(-2, h + 0.4, -3))), 0.0, 1.0,
		"Camera3D.unproject_position at head height + 0.4 m")
	assert_eq(str(plates.call("pick", head0 + Vector2(3, 2))), "e0", "pick on the plate")
	var foot1: Vector2 = cam.unproject_position(Vector3(2, 0, -3))
	assert_eq(str(plates.call("pick", foot1 + Vector2(20, 0))), "e1", "pick near the foot point (≥ 107 px area)")
	assert_eq(str(plates.call("pick", Vector2(5, 5))), "", "nothing far away")
	assert_true((plates.get_node("Name0") as Label).visible, "the target is named")
	assert_eq((plates.get_node("Name0") as Label).text, "Kanalratte A")
	assert_false((plates.get_node("Name1") as Label).visible, "plain enemies: no name")
	assert_eq(CombatView.threat_color(sim, sim.unit("e1")), CombatStyle.member_color("mopsula"),
		"threat dot in the attacked member's colour (e1 attacks the Count)")
	assert_eq(CombatView.threat_color(sim, sim.unit("e0")).a, 0.0, "no target: no dot")


func test_close_plates_stack() -> void:
	var plates_gd: GDScript = load("res://scenes/combat/ui/nameplates.gd") as GDScript
	var shown: Array[Dictionary] = [{"id": "e1", "head": Vector2(610, 396), "named": false},
		{"id": "e0", "head": Vector2(600, 400), "named": true}, {"id": "e2", "head": Vector2(620, 392), "named": false},
		{"id": "e3", "head": Vector2(900, 300), "named": false}]
	plates_gd.call("stack", shown)
	var boxes: Dictionary = {}
	for p: Dictionary in shown:
		boxes[str(p["id"])] = plates_gd.call("plate_box", p["head"], bool(p["named"])) as Rect2
	_assert_no_overlap(boxes, "a melee pile of plates")
	var by_id: Dictionary = {}
	for p2: Dictionary in shown:
		by_id[str(p2["id"])] = p2["head"]
	assert_eq(by_id["e0"], Vector2(600, 400), "the lowest plate (the target) keeps its place")
	assert_eq(by_id["e3"], Vector2(900, 300), "a plate apart keeps its place")
	assert_lt((by_id["e2"] as Vector2).y, (by_id["e1"] as Vector2).y, "the pile stacks upwards")


func test_combat_text_styles_and_cap() -> void:
	var holder: Node3D = Node3D.new()
	add_to_tree(holder)
	var cam: Camera3D = Camera3D.new()
	holder.add_child(cam)
	cam.position = Vector3(0, 2, 6)
	cam.make_current()
	for i in 14:
		Vfx.combat_text(holder, Vector3(0, 1, 0), str(10 + i), &"rt_dealt")
	assert_eq(Vfx.combat_text_count(holder), Vfx.RT_MAX, "at most 10 at once — the oldest gives way (07 §8.6)")
	assert_almost(Vfx.RT_LIFE, 0.6, 0.0001, "life 0.6 s")
	for style: StringName in Vfx.RT_STYLES:
		Vfx.combat_text(holder, Vector3.ZERO, "X", style)
	assert_eq(Vfx.combat_text_count(holder), Vfx.RT_MAX)


func test_screen_modes_applied_and_restored() -> void:
	Game.state.floor_run.timer_started = true
	var o: CanvasLayer = _overlay()
	var d: CanvasLayer = (load(DIALOG_SCENE) as PackedScene).instantiate() as CanvasLayer
	var holder: Node = Node.new()
	add_to_tree(holder)
	holder.add_child(d)
	Events.overlay_mode_requested.emit(&"explore")
	var r: Dictionary = HudRig.make(self, _regular(), FakeSim.load_data(), {"modes": true})
	await wait_frames(3)
	assert_eq(o.get("mode"), &"combat", "ShowOverlay in the combat mode")
	assert_true(str(o.call("clock_chip_text")).begins_with("Uhr steht · "), "the stopped clock as a chip")
	assert_true(bool(d.call("is_subtitle")), "M.O.D. box as subtitle")
	assert_eq((d.call("subtitle_layout") as Dictionary)["bottom"], 130, "PC: bottom −130, 600 wide")
	var tab: InputEventKey = InputEventKey.new()
	tab.physical_keycode = KEY_TAB
	tab.pressed = true
	assert_false(tab.is_action_pressed(&"map"), "real-time combat: Tab is targeting, not the map")
	Game.state.combat_mode = &"ctb"            # 07 E33: new games fight in real time — the CTB case of the input map
	(r["hud"] as Node).call("finish", null)
	await wait_frames(2)
	assert_true(tab.is_action_pressed(&"map"), "a CTB run gets its map back")
	assert_eq(o.get("mode"), &"explore", "back to the exploration overlay")
	assert_false(bool(d.call("is_subtitle")), "the normal box again")
	assert_eq(str(o.call("clock_chip_text")), "", "no chip outside combat")
	Game.state.combat_mode = &"realtime"
	CombatInput.apply_for_game()
	assert_false(tab.is_action_pressed(&"map"), "a real-time run targets with Tab in the exploration too (07 §7.1)")


func test_status_seconds_only_on_long_press() -> void:
	var data: GameData = FakeSim.load_data()
	var sim: RtSim = HudScenarios.build(data, {"level": 2})
	sim.call("set_tick", 100)
	HudScenarios.add_status(sim, data, sim.unit("p0"), "sts_guard", 75, 180)
	var r: Dictionary = HudRig.make(self, sim, data)
	await wait_frames(2)
	var frames: Control = (r["hud"] as Node).get("frames") as Control
	assert_false((frames.get_node("L_sec0") as Label).visible, "no seconds by default (07 §8.1)")
	frames.set("seconds_for", "p0")
	await wait_frames(2)
	assert_true((frames.get_node("L_sec0") as Label).visible, "long press on the frame: seconds")
	assert_eq((frames.get_node("L_sec0") as Label).text, "3", "75 ticks = 3 s (whole seconds from 1 s)")


## 03_ART F8: every text the combat UI shows passes ThemeDB.fallback_font.has_char (like test_m6_ui_scenes).
func test_texts_use_available_glyphs() -> void:
	var data: GameData = FakeSim.load_data()
	var sim: RtSim = _regular(4, data)
	var r: Dictionary = HudRig.make(self, sim, data, {"force_touch": true})
	await wait_frames(3)
	var hud: Node = r["hud"]
	hud.call("open_wheel")
	hud.call("open_tactic")
	(hud.get("banner") as Node).call("show_banner", "STEUERUNGSWECHSEL",
		"Kai ist K.O. — du spielst jetzt Graf Mopsula!")
	var cards: Node = hud.get("hints")
	for id: String in ["target", "bar1", "show", "dodge"] + Array(RtVocab.HINT_IDS):
		for touch: bool in [false, true]:
			assert_eq(_missing(str(cards.call("default_text", id, touch, false))), "", "card %s" % id)
	for reason: String in RtCommand.REASONS:
		assert_eq(_missing(CombatStyle.refusal_text(reason)), "", "refusal %s" % reason)
	await wait_frames(2)
	assert_eq(_bad_glyphs(hud), PackedStringArray(), "HUD texts")
	var res: CanvasLayer = (load("res://scenes/combat/ui/combat_results.gd") as GDScript).new() as CanvasLayer
	var holder: Node = Node.new()
	add_to_tree(holder)
	holder.add_child(res)
	var br: BattleResult = BattleResult.new()
	br.exp = 10
	res.call("present", br, BattleRewards.new())
	assert_eq(_bad_glyphs(res), PackedStringArray(), "result texts")


static func _missing(text: String) -> String:
	var out: String = ""
	for i in text.length():
		var code: int = text.unicode_at(i)
		if code >= 32 and not ThemeDB.fallback_font.has_char(code) and not out.contains(text[i]):
			out += text[i]
	return out


func _bad_glyphs(root: Node) -> PackedStringArray:
	var out: PackedStringArray = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c: Node in n.get_children():
			stack.append(c)
		var text: String = ""
		if n is Label:
			text = (n as Label).text
		elif n is Button:
			text = (n as Button).text
		var missing: String = _missing(text)
		if missing != "":
			out.append("%s: '%s' (%s)" % [n.name, text, missing])
	return out
