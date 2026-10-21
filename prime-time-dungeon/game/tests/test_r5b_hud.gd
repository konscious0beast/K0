extends TestCase
## R5b part 1 (07 §8.3, §8.4; 08 §6): the real-time HUD — Kai's frame symbol is drawn from the running persona's look
## (skin, hair colour and style, beard, glasses; the canon look without a persona), and in the touch layout the boss
## frame keeps clear of the ShowOverlay's hype meter (its "HYPE" ran over the boss's percentage). The autopilot label
## names the key of the input scheme (none on touch; it showed a fixed "T" everywhere).

const UnitFrames := preload("res://scenes/combat/ui/unit_frames.gd")
const IconMesh := preload("res://scenes/ui/icon_mesh.gd")
const HudRig := preload("res://tests/fixtures/rt_hud/hud_rig.gd")
const HudScenarios := preload("res://tests/fixtures/rt_hud/hud_scenarios.gd")
const FakeSim := preload("res://tests/fixtures/rt_min/fake_rt_sim.gd")
const InputGlyph := preload("res://scenes/ui/input_glyph.gd")


func after_each() -> void:
	Game.persona = null


func test_kai_wears_the_persona_look_in_the_frames() -> void:
	var f: Control = UnitFrames.new()
	var canon: Dictionary = f.call("look_of", "kai")
	var model: Dictionary = DB.party_model("kai")
	assert_eq(canon["skin"], Color(str((model["colors"] as Dictionary)["skin"])), "no persona: party.json")
	assert_eq([canon["style"], canon["beard"], canon["glasses"]], ["short", "none", false])
	var p: PersonaProfile = PersonaProfile.canon(DB.data)
	p.look = {"hair": "lk_hair_bun", "hair_color": "lk_hc_pink", "skin": "lk_skin_6", "beard": "lk_beard_full",
		"glasses": "lk_glasses_round", "outfit": "lk_outfit_green"}
	Game.persona = p
	f.set("sim", RtKit.sim(RtKit.dummy_cmd()))           # a new combat: the cached face is read again
	var look: Dictionary = f.call("look_of", "kai")
	assert_eq([look["skin"], look["hair"]], [Color("#8D5A3A"), Color("#E85A9A")], "skin tone and hair colour")
	assert_eq([look["style"], look["beard"], look["glasses"]], ["bun", "full", true])
	for hs: String in ["short", "buzz", "long", "bun", "curls", "ponytail", "braids", "headscarf"]:
		var m: IconMesh = IconMesh.new()
		UnitFrames.face_symbol(m, Rect2(0, 0, 48, 48), {"skin": Color.BEIGE, "hair": Color.BROWN, "style": hs,
			"beard": "stubble", "glasses": true})
		assert_false(m.is_empty(), hs)
		for pt: Vector2 in m.points:
			assert_true(Rect2(-2, -2, 52, 52).has_point(pt), "%s stays in its symbol" % hs)
	f.free()


func test_the_touch_boss_frame_keeps_clear_of_the_hype_meter() -> void:
	var f: Control = UnitFrames.new()
	f.size = Vector2(1232, 672)
	var free: Rect2 = f.call("boss_rect")
	assert_eq(free, Rect2(Vector2((1232.0 - UnitFrames.BOSS_W) * 0.5, 0.0), Vector2(UnitFrames.BOSS_W,
		UnitFrames.BOSS_H)), "PC / no meter: 520 centred")
	f.set("reserve_right", 811.0)                       # the hype meter's left edge (1280 × 720 touch)
	var r: Rect2 = f.call("boss_rect")
	assert_true(r.end.x <= 811.0 - UnitFrames.RESERVE_GAP, "ends before the meter (room for the target sword)")
	assert_true(r.position.x >= UnitFrames.BOSS_LEFT_MIN, "right of the LIVE / viewers block")
	assert_true(r.size.x >= UnitFrames.BOSS_MIN_W)
	f.set("reserve_right", 1200.0)
	assert_eq(f.call("boss_rect"), free, "a meter far right changes nothing")
	f.free()


func test_the_autopilot_label_names_the_key_of_the_scheme() -> void:
	Game.new_game(0, "Kai", 11)
	var data: GameData = FakeSim.load_data()
	for touch: bool in [false, true]:
		var rig: Dictionary = HudRig.make(self, HudScenarios.build(data, {"level": 4}), data, {"force_touch": touch})
		var label: Label = (rig["hud"] as Node).get("_autopilot") as Label
		var key: String = InputGlyph.binding_text(&"toggle_auto", Game.InputScheme.KEYBOARD_MOUSE)
		assert_eq(label.text, "AUTOPILOT" if touch else "AUTOPILOT · " + key, "touch %s" % str(touch))
		assert_ne(key, "", "the keyboard binding of toggle_auto")
		(rig["hud"] as Node).get_parent().queue_free()
