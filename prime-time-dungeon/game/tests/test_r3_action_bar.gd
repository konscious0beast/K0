extends TestCase
## R3 action bar (07 §4.1, §8.2, §12.5): every slot state comes from the pure RtSim queries (cooldown, GCD, MP, range,
## target, queue, assist), SHOW turns into FINALE when RtSim.bar puts the FINALE into slot 5, the bar grows with the
## level (tutorial: slot 1 + SHOW), the potion shows "2/3", refusals shake + short text, all sweeps share ONE
## ShaderMaterial (one canvas draw call). Runs against the HudSim double; the real sim (R1b-I1) answers the same
## queries.

const HudRig := preload("res://tests/fixtures/rt_hud/hud_rig.gd")
const HudScenarios := preload("res://tests/fixtures/rt_hud/hud_scenarios.gd")
const FakeSim := preload("res://tests/fixtures/rt_min/fake_rt_sim.gd")
const CombatView := preload("res://scenes/combat/ui/combat_view.gd")
const ActionBar := preload("res://scenes/combat/ui/action_bar.gd")

var _assist: int = -1


func before_each() -> void:
	Game.new_game(0, "Kai", 11)
	_assist = Game.settings.combat_assist


func after_each() -> void:
	Game.settings.combat_assist = _assist


func _data() -> GameData:
	return FakeSim.load_data()


func _rig(sim: RtSim, data: GameData, extra: Dictionary = {}) -> Dictionary:
	return HudRig.make(self, sim, data, extra)


func test_slot_states_come_from_the_sim() -> void:
	var data: GameData = _data()
	var sim: RtSim = HudScenarios.build(data, {"level": 4, "enemies": ["enm_kanalratte", "enm_rt_test_caster"]})
	var p0: RtUnit = sim.unit("p0")
	p0.target_id = "e0"
	sim.call("set_cd", "p0", "skl_kai_leash_trip", 120, 360)
	sim.set("gcds", {"p0": Vector2i(30, 45)})
	sim.call("set_reason", "p0", "skl_kai_heavy_swing", "mp")
	sim.call("set_reason", "p0", "skl_kai_leash_trip", "range")
	sim.call("set_reason", "p0", "skl_kai_taunt", "target")
	sim.set("items", 2)
	sim.set("item_cd", Vector2i(150, 450))
	p0.queued = {"skill": "skl_kai_sweep", "target": "", "at": 0}
	sim.set("suggestions", {"p0": "skl_stunt_kai_suplex"})
	Game.settings.combat_assist = 1
	var r: Dictionary = _rig(sim, data)
	await wait_frames(3)
	var bar: Control = (r["hud"] as Node).get("bar") as Control
	assert_eq(bar.call("visible_slots"), [1, 2, 3, 4, 5, 6] as Array[int], "level 4: every slot")
	var s1: Dictionary = bar.call("state_of", 1)
	var s2: Dictionary = bar.call("state_of", 2)
	var s3: Dictionary = bar.call("state_of", 3)
	var s4: Dictionary = bar.call("state_of", 4)
	var s5: Dictionary = bar.call("state_of", 5)
	var s6: Dictionary = bar.call("state_of", 6)
	assert_true(bool(s1["no_mp"]), "slot 1: can_use 'mp' → no MP tint")
	assert_eq(int(s1["mp"]), 2, "Wuchtschlag costs rt.mp 2")
	assert_eq(int(s1["gcd_left"]), 30, "GCD skill shows the GCD ring")
	assert_eq(int(s3["gcd_left"]), 0, "rt.gcd false (Leinen-Fallstrick): no GCD ring")
	assert_eq([int(s3["cd_left"]), int(s3["cd_total"])], [120, 360], "cooldown_left / cooldown_total")
	assert_true(bool(s3["out_of_range"]), "can_use 'range' → red tint")
	assert_true(bool(s2["no_target"]), "can_use 'target' → dimmed")
	assert_true(bool(s4["queued"]), "RtUnit.queued → gold frame")
	assert_true(bool(s5["assist"]), "suggest() with assist on → pulsing ring")
	assert_true(bool(s5["show"]) and not bool(s5["finale"]), "slot 5 is SHOW")
	assert_eq([int(s6["count"]), int(s6["max_count"])], [2, 3], "potion: items_left of ITEM_MAX_PER_COMBAT")
	assert_eq([int(s6["cd_left"]), int(s6["cd_total"])], [150, 450], "potion: party item cooldown")
	var sweep: ColorRect = bar.get_node("Sweep3") as ColorRect
	assert_almost(float(sweep.get_instance_shader_parameter(&"cd_left")), 120.0 / 360.0, 0.001,
		"the sweep reads cooldown_left / cooldown_total")
	assert_almost(float((bar.get_node("Sweep1") as ColorRect).get_instance_shader_parameter(&"gcd_left")),
		30.0 / 45.0, 0.001, "GCD ring = gcd_left / gcd_total")
	assert_eq((bar.get_node("Secs3") as Label).text, "4", "remaining seconds in the middle (120 ticks = 4 s)")
	assert_eq((bar.get_node("Small6") as Label).text, "2/3", "potion count bottom right")
	assert_eq((bar.get_node("Small1") as Label).text, "2 MP", "missing MP: the cost bottom left")
	Game.settings.combat_assist = 0
	await wait_frames(2)
	assert_false(bool((bar.call("state_of", 5) as Dictionary)["assist"]), "assist off: no ring")


func test_bar_grows_with_the_level() -> void:
	var data: GameData = _data()
	var expect: Dictionary = {1: [1, 5, 6], 2: [1, 2, 5, 6], 3: [1, 2, 3, 5, 6], 4: [1, 2, 3, 4, 5, 6]}
	for lvl: int in expect.keys():
		var sim: RtSim = HudScenarios.build(data, {"level": lvl})
		assert_eq(CombatView.slots(sim).map(func(s: Dictionary) -> int: return int(s["slot"])), expect[lvl],
			"Kai level %d" % lvl)
	var tut: RtSim = HudScenarios.build(data, {"level": 1, "tutorial": true})
	assert_eq(CombatView.slots(tut).map(func(s: Dictionary) -> int: return int(s["slot"])), [1, 5],
		"tutorial fight: slot 1 + SHOW only (07 §2.13)")
	var mop: RtSim = HudScenarios.build(data, {"level": 1, "hero": "mopsula"})
	assert_eq(CombatView.slots(mop).map(func(s: Dictionary) -> int: return int(s["slot"])), [1, 2, 5, 6],
		"Graf Mopsula level 1: 1 + 2 + 5 + 6")
	var r: Dictionary = _rig(HudScenarios.build(data, {"level": 2}), data)
	await wait_frames(3)
	var bar: Control = (r["hud"] as Node).get("bar") as Control
	assert_almost(bar.size.x, ActionBar.width_for([1, 2, 5, 6]), 0.5, "width of the visible slots")
	assert_almost(ActionBar.width_for([1, 2, 3, 4, 5, 6]), 436.0, 0.01, "07 §8.1: 6 slots = 436 px")
	var frame: Control = bar.get_parent() as Control
	assert_almost(bar.position.x + bar.size.x * 0.5, frame.size.x * 0.5, 0.5, "centred")
	assert_almost(frame.size.y - bar.position.y - bar.size.y, 36.0, 0.5, "bottom edge −36 (07 §8.1)")
	var r2: Rect2 = bar.call("slot_rect", 5) as Rect2
	var r6: Rect2 = bar.call("slot_rect", 6) as Rect2
	assert_almost(r6.position.x - r2.end.x, 20.0, 0.01, "8 px gap + 12 px more before the potion")


func test_show_turns_into_finale() -> void:
	var data: GameData = real_data()
	var sim: RtSim = HudScenarios.build(data, {"level": 6})
	var r: Dictionary = _rig(sim, data)
	await wait_frames(2)
	var bar: Control = (r["hud"] as Node).get("bar") as Control
	assert_false(bool((bar.call("state_of", 5) as Dictionary)["finale"]), "SHOW while bar() shows the stunt")
	assert_false((bar.get_node("Finale") as Label).visible, "no FINALE caption")
	var bars: Dictionary = {"p0": HudScenarios.bar_for("kai", 6, false, true)}
	(bars["p0"] as Dictionary)[5] = "skl_kai_prime_finisher"   # RtSim.bar: level ≥ 6 and target < 30 % (in the sim)
	sim.set("bars", bars)
	await wait_frames(2)
	var s5: Dictionary = bar.call("state_of", 5)
	assert_true(bool(s5["finale"]), "slot 5 shows the FINALE")
	assert_eq(str(s5["name"]), "Prime-Time-Finisher")
	assert_true((bar.get_node("Finale") as Label).visible, "FINALE caption over the slot")
	sim.call("set_reason", "p0", "skl_kai_prime_finisher", "target_hp")
	await wait_frames(1)
	assert_true(bool((bar.call("state_of", 5) as Dictionary)["no_target"]), "target_hp: dimmed like no target")


func test_refusals_shake_and_explain() -> void:
	var data: GameData = _data()
	var sim: RtSim = HudScenarios.build(data, {"level": 3})
	var r: Dictionary = _rig(sim, data)
	await wait_frames(2)
	var hud: Node = r["hud"]
	var bar: Control = hud.get("bar") as Control
	var cases: Dictionary = {"cooldown": "Abklingzeit", "mp": "Nicht genug MP", "range": "Zu weit weg",
		"target": "Kein Ziel", "locked": "Gesperrt", "target_hp": "Ziel noch zu fit"}
	for reason: String in cases.keys():
		var e: ActionEvent = ActionEvent.make(ActionEvent.Type.ACTION_REFUSED)
		e.actor_id = "p0"
		e.skill_id = "skl_kai_leash_trip"
		e.text = reason
		hud.call("on_event", e)
		assert_eq(bar.call("refusal_text"), cases[reason], "07 §8.2 short text for '%s'" % reason)
	assert_true((bar.get("_shake") as Dictionary).has(3), "the refused slot shakes")


func test_sweeps_share_one_material() -> void:
	var data: GameData = _data()
	var r: Dictionary = _rig(HudScenarios.build(data, {"level": 4}), data)
	await wait_frames(2)
	var bar: Control = (r["hud"] as Node).get("bar") as Control
	var mats: Dictionary = {}
	for slot in range(1, 7):
		var sw: ColorRect = bar.get_node("Sweep%d" % slot) as ColorRect
		mats[sw.material.get_instance_id()] = true
		assert_eq((sw.material as ShaderMaterial).shader.resource_path, "res://art/shaders/ui_cooldown_sweep.gdshader")
	assert_eq(mats.size(), 1, "one ShaderMaterial for every sweep (instance uniforms, 07 §8.2)")
	var frames: Control = (r["hud"] as Node).get("frames") as Control
	var special: ColorRect = frames.get("_special_sweep") as ColorRect
	assert_true(special != null and special.material == ActionBar.sweep_material(), "partner button: the same one")


func test_ready_again_flashes() -> void:
	var data: GameData = _data()
	var sim: RtSim = HudScenarios.build(data, {"level": 3})
	sim.call("set_cd", "p0", "skl_kai_leash_trip", 2, 360)
	var r: Dictionary = _rig(sim, data)
	await wait_frames(2)
	var bar: Control = (r["hud"] as Node).get("bar") as Control
	sim.call("set_cd", "p0", "skl_kai_leash_trip", 0, 0)
	await wait_frames(1)
	assert_true((bar.get("_flash") as Dictionary).has(3), "cooldown over → white flash (0.15 s)")
	await wait_until(func() -> bool: return not (bar.get("_flash") as Dictionary).has(3), 120)
