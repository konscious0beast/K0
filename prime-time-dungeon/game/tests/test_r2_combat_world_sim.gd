extends "res://tests/fixtures/rt_world/world_case.gd"
## The world integration against the REAL sim (R1b stage I1; 07 §12.2 R2 gate "Szenentests gegen die echte Sim ab
## I1"): the exploration on the RtKit fixture data (rt_min tables with rt blocks) — Game builds the setup with
## BattleBridge.make_rt_setup_rules and runs RtSim; no world fixture stream. The tutorial combat with both heroes to
## its victory in the world (closed set, puppets on the sim positions, the group gone), honest movement of the body
## under real physics against the plausibility check of the sim (never a correction), a flight through a door lane,
## a group-less combat (anchor) and the set geometry of scene and sim being the same.

const CELL: Vector2i = Vector2i(3, 6)


func test_the_tutorial_combat_with_the_real_sim_kai() -> void:
	await _tutorial("kai")


func test_the_tutorial_combat_with_the_real_sim_mopsula() -> void:
	await _tutorial("mopsula")


func _tutorial(hero: String) -> void:
	await make_kit_world(hero)
	var tut: Node3D = scene.get_enemy("f1_g0")
	var center: Vector3 = scene.get_layout().cell_to_world(CELL)
	place_player(CELL, tut.global_position - center + Vector3(0.0, 0.0, 1.2), 0.0)
	scene.call("on_enemy_contact", tut)
	assert_not_null(Game.combat, "touching the sleeping tutorial group starts the combat")
	if Game.combat == null:
		return
	assert_false(Game.combat is FakeRtSim, "the real RtSim")
	var sim: RtSim = Game.combat
	assert_true(sim.setup.tutorial)
	assert_true(bool(sim.setup.geo.get("closed", false)), "tutorial: closed set")
	assert_eq(int(sim.setup.advantage), Rules.PREEMPTIVE)
	var ctl: String = director.controlled_unit()
	assert_eq(ctl, "p%d" % DB.party_member(hero).battle_slot, "the hero is the controlled unit")
	var member: PartyMember = Game.state.member(hero)
	assert_eq(sim.unit(ctl).max_hp(), Progression.total_stats(member, DB.data).values[StatBlock.Stat.HP])
	assert_eq(member.hp_scale_pm, 4000, "a real-time game scales the party HP (07 §3.9.4)")
	assert_true(director.puppets.call("node_of", "e0") == tut, "the lead is shown by its EnemyActor")
	var bar: Dictionary = sim.bar(ctl)
	assert_true(bar.has(1), "slot 1 in the tutorial")
	director.submit(RtCommand.target(0, ctl, "e0"))
	var checked: int = 0
	for i in 4000:
		if not director.is_running():
			break
		if i % 45 == 0:
			director.submit(RtCommand.ability(0, ctl, str(bar[1]), ""))
		director.advance(1)
		if i % 90 == 45 and director.is_running():
			checked += _puppets_on_sim_positions()
	assert_gt(checked, 0, "puppet positions checked during the combat")
	assert_not_null(director.last_result)
	if director.last_result != null:
		assert_eq(int(director.last_result.outcome), BattleResult.Outcome.VICTORY, "the tutorial is won")
	assert_null(scene.get_enemy("f1_g0"), "the defeated group is gone")
	assert_eq(director.corrections, 0, "no correction of the standing figure")
	assert_false(Game.in_battle)
	var kinds: Dictionary = {}
	for row: Dictionary in Game.run_log.cmds():
		kinds[str((row["c"] as Dictionary).get("t", ""))] = true
	assert_true(kinds.has("encounter") and kinds.has("target_change") and kinds.has("ability_use"),
		"encounter + combat commands recorded: %s" % str(kinds.keys()))
	var end_cp: bool = false
	for cp: Dictionary in Game.run_log.checkpoints():
		end_cp = end_cp or int(cp.get("ct", -1)) == director.ticks_run
	assert_true(end_cp, "the end checkpoint of the combat")


## Every bound, living, non-controlled unit at its sim position (±1 cm, alpha 1 after advance); the count checked.
func _puppets_on_sim_positions() -> int:
	var n: int = 0
	for u: RtUnit in Game.combat.units():
		if u.id == director.controlled_unit() or u.hp <= 0 or not bool(director.puppets.call("has", u.id)):
			continue
		var p: Vector3 = director.unit_position(u.id)
		var want: Vector3 = world_of(u.x, u.z)
		assert_lt(Vector2(p.x - want.x, p.z - want.z).length(), 0.0101, "%s on its sim position" % u.id)
		n += 1
	return n


func test_honest_movement_is_never_corrected_by_the_real_sim() -> void:
	await make_kit_world("kai")
	place_player(CELL, Vector3(0.0, 0.0, 1.5), 0.0)
	scene.call("_trigger_encounter", "", "enc_rt_dummy", Rules.NORMAL, "")
	assert_not_null(Game.combat, "a group-less combat (event) starts")
	if Game.combat == null:
		return
	assert_false(bool(Game.combat.setup.geo.get("closed", true)), "open set")
	director.auto_tick = true
	for step: Array in [[&"move_forward", 0.9], [&"move_right", 1.0], [&"move_back", 1.4], [&"move_left", 1.6],
			[&"move_forward", 0.6], [&"move_right", 0.5]]:
		Input.action_press(step[0])
		await seconds(float(step[1]))
		Input.action_release(step[0])
	await seconds(0.4)
	assert_true(director.is_running(), "still in the set (the dummy stands, nobody fled)")
	assert_gt(director.samples_sent, 8, "the walk produced samples")
	assert_eq(director.corrections, 0, "the sim corrected nothing (07 §3.5.2: honest runs never hit the limits)")
	director.auto_tick = false


func test_a_flight_through_a_door_lane_with_the_real_sim() -> void:
	await make_kit_world("kai")
	place_player(CELL, Vector3(0.0, 0.0, 0.0), -PI * 0.5)
	scene.call("_trigger_encounter", "", "enc_rt_dummy", Rules.NORMAL, "")
	assert_not_null(Game.combat)
	if Game.combat == null:
		return
	scene.get_camera_rig().set("yaw", -PI * 0.5)
	director.auto_tick = true
	Input.action_press(&"move_forward")
	var fled: bool = await wait_until(func() -> bool: return not director.is_running(), 2400)
	Input.action_release(&"move_forward")
	assert_true(fled, "the combat ends")
	assert_not_null(director.last_result)
	if director.last_result != null:
		assert_eq(int(director.last_result.outcome), BattleResult.Outcome.FLED, "2 s outside the ring: FLED")
	assert_eq(director.corrections, 0, "the lane is walkable for the sim (it starts at the room centre)")
	assert_false(Game.in_battle)


func test_scene_and_sim_agree_on_the_set() -> void:
	await make_kit_world("kai")
	place_player(CELL, Vector3(0.0, 0.0, 1.0), 0.0)
	scene.call("_trigger_encounter", "", "enc_rt_dummy", Rules.NORMAL, "")
	assert_not_null(Game.combat)
	if Game.combat == null:
		return
	var geo: Dictionary = Game.combat.setup.geo
	var mine: Dictionary = scene.rt_geo(CELL, false)
	for k: String in ["r", "doors", "closed"]:
		assert_eq(mine.get(k), geo.get(k), "rt_geo %s" % k)
	assert_almost(float(director.ring.get("radius_m")), float(int(geo["r"])) / 100.0, 0.0001, "the ring = geo.r")
	assert_eq(int(director.ring.get("gap_doors")), int(geo["doors"]), "one lane per open door")
	# the floor event's dummy first (group-less: from the anchor), then the tutorial group of the cell (Mitziehen)
	assert_eq(Game.combat.units().size(), 5, "Kai, Graf Mopsula, the dummy, two rats")
	assert_eq(Game.combat.unit("e0").def_id, "enm_rt_dummy")
	assert_true(director.puppets.call("node_of", "e0") is CharacterRig, "a group-less enemy: an extra rig")
	assert_true(director.puppets.call("node_of", "e1") == scene.get_enemy("f1_g0"), "the joined group's lead")
	director.abort()
	assert_null(Game.combat, "abort drops the combat")
	assert_false(Game.in_battle)
	assert_false(bool(scene.call("_rt_busy")), "the world explores again")
