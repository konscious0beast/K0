extends "res://tests/fixtures/rt_world/world_case.gd"
## Real-time combat in the world (07 §2, §3.5.6, §12.5 test_r2_combat_world; R2) on the real floor 1 with the world
## fixture as the sim: the triggers of 07 §2.2 (pull by field strike / ability / item, weapon reach, 4 s of chase,
## being seen alone starts nothing, the sleeping tutorial group also by touch — both heroes; no set in the stairs
## room), the advantage table incl. DAZED (bark opener), the recorded encounter command, the show boss groups,
## "Mitziehen" ≤ 6 units with the others waiting at the ring, hidden actors of other rooms, the set ring
## with its collision and door lanes, closed sets, puppets = sim positions, the interaction lock, flight (reset),
## victory (groups removed) and the control switch with the body swap and the hero restored at the end.


func test_the_field_strike_pulls_preemptive() -> void:
	await make_world()
	place_player(Vector2i(1, 4), Vector3(0.0, 0.0, 2.0), 0.0)
	place_lead("f1_g1", Vector2i(1, 4), Vector3(0.0, 0.0, 0.8), 0.0)
	scene.perform_action()
	assert_true(await wait_until(func() -> bool: return Game.combat != null, 120), "the strike starts the combat")
	assert_len(encounters(), 1)
	var cmd: Dictionary = encounters()[0]
	assert_eq(int(cmd["adv"]), Rules.PREEMPTIVE, "a patrolling lead hit from behind: caught first")
	var rt: Dictionary = cmd["rt"]
	assert_eq(rt["open"], {"kind": "strike", "target": "e0"}, "the field strike opens the combat (pull)")
	assert_eq(RtCommand.validate(cmd), "", "the rt block is valid")
	assert_eq(rt["cell"], [1, 4])
	assert_eq(str(rt["ctl"]), "p0")
	assert_len(rt["party"] as Array, 2, "both party poses")
	assert_eq(str(((rt["groups"] as Array)[0] as Dictionary)["group"]), "f1_g1")
	assert_true((rt["presets"] as Dictionary).has("p1"), "the AI partner's preset")
	assert_true(director.is_running())
	assert_true(Game.in_battle)
	assert_false(Game.is_timer_ticking(), "the floor clock stands in a combat")


func test_pull_with_an_ability_or_an_item_and_the_candidates() -> void:
	await make_world()
	place_player(Vector2i(1, 4), Vector3(0.0, 0.0, 3.0), 0.0)
	place_lead("f1_g1", Vector2i(1, 4), Vector3(1.0, 0.0, -2.0), PI)
	assert_eq(scene.pull_candidates(), PackedStringArray(["f1_g1"]), "leads in the room, nearest first")
	assert_false(scene.pull("f1_g1", "emote", "x"), "only an ability or an item pulls")
	assert_false(scene.pull("f1_fb", "skill", "skl_x"), "never a boss (and only in the own room)")
	assert_true(scene.pull("f1_g1", "item", "itm_molotov"))
	var cmd: Dictionary = encounters()[0]
	assert_eq(int(cmd["adv"]), Rules.PREEMPTIVE, "PATROL lead")
	assert_eq((cmd["rt"] as Dictionary)["open"], {"kind": "item", "u": "p0", "item": "itm_molotov", "target": "e0"})
	assert_false(scene.pull("f1_g1", "skill", "skl_x"), "no second pull while a combat runs")
	assert_eq(scene.pull_candidates(), PackedStringArray(), "no candidates in a combat")


func test_a_dazed_lead_is_caught_first_with_the_bark_opener() -> void:
	await make_world()
	place_player(Vector2i(1, 4), Vector3(0.0, 0.0, 3.0), 0.0)
	var a: Node3D = place_lead("f1_g1", Vector2i(1, 4), Vector3(0.0, 0.0, 0.0), PI)
	assert_true(bool(a.call("daze")), "barked at: DAZED")
	assert_true(scene.pull("f1_g1", "skill", "skl_x"))
	var cmd: Dictionary = encounters()[0]
	assert_eq(int(cmd["adv"]), Rules.PREEMPTIVE)
	assert_eq(str(cmd.get("opener", "")), "bark", "DAZED → PREEMPTIVE from the bark")


func test_weapon_reach_of_a_chasing_lead_normal() -> void:
	await make_world()
	place_player(Vector2i(1, 4), Vector3(0.0, 0.0, 2.0), 0.0)
	var a: Node3D = place_lead("f1_g1", Vector2i(1, 4), Vector3(0.0, 0.0, 0.0), 0.0, true)
	a.call("_set_state", &"CHASE")
	scene.call("_rt_triggers", 0.016)
	assert_len(encounters(), 1, "2 m: inside reach_cm + both radii (2.9 m)")
	assert_eq(int(encounters()[0]["adv"]), Rules.NORMAL, "Kai faces it: NORMAL")


func test_weapon_reach_from_behind_is_an_ambush() -> void:
	await make_world()
	place_player(Vector2i(1, 4), Vector3(0.0, 0.0, 2.0), PI)
	var a: Node3D = place_lead("f1_g1", Vector2i(1, 4), Vector3(0.0, 0.0, 0.0), PI, true)
	a.call("_set_state", &"CHASE")
	scene.call("_rt_triggers", 0.016)
	assert_len(encounters(), 1)
	assert_eq(int(encounters()[0]["adv"]), Rules.AMBUSH, "the figure turns its back to it: AMBUSH")


func test_four_seconds_of_chase_in_the_room() -> void:
	await make_world()
	place_player(Vector2i(1, 4), Vector3(0.0, 0.0, 3.0), 0.0)
	var a: Node3D = place_lead("f1_g1", Vector2i(1, 4), Vector3(0.0, 0.0, -2.5), PI, true)
	a.call("_set_state", &"CHASE")
	scene.call("_rt_triggers", 3.0)
	# a room change resets the count
	var home: Vector3 = a.global_position
	a.global_position = scene.get_layout().cell_to_world(Vector2i(1, 5))
	scene.call("_rt_triggers", 0.5)
	a.global_position = home
	scene.call("_rt_triggers", 2.0)
	assert_len(encounters(), 0, "5.5 m away, 3 s + 2 s with a room change in between: nothing")
	scene.call("_rt_triggers", 2.1)
	assert_len(encounters(), 1, "4 s of chase in the player's room")
	assert_eq(int(encounters()[0]["adv"]), Rules.NORMAL, "\"Die Kamera hat euch!\": NORMAL")


func test_being_seen_or_touched_starts_nothing() -> void:
	await make_world()
	place_player(Vector2i(1, 4), Vector3(0.0, 0.0, 2.0), 0.0)
	var a: Node3D = place_lead("f1_g1", Vector2i(1, 4), Vector3(0.0, 0.0, 1.0), PI, true)
	a.call("_set_state", &"ALERT")
	scene.call("_rt_triggers", 5.0)
	scene.call("on_enemy_contact", a)
	assert_len(encounters(), 0, "sighting and contact alone start nothing (07 §2.2)")
	assert_null(Game.combat)


func test_the_sleeping_tutorial_group_by_touch_kai() -> void:
	await make_world()
	await _touch_tutorial("p0")


func test_the_sleeping_tutorial_group_by_touch_mopsula() -> void:
	await make_world("win", 300, "mopsula")
	assert_eq(scene.get_player().hero_id, "mopsula")
	await _touch_tutorial(_unit_of("mopsula"))


func _touch_tutorial(ctl: String) -> void:
	var tut: Node3D = scene.get_enemy("f1_g0")
	place_player(Vector2i(1, 6), tut.global_position - scene.get_layout().cell_to_world(Vector2i(1, 6))
		+ Vector3(0.0, 0.0, 1.0), 0.0)
	scene.call("on_enemy_contact", tut)
	assert_len(encounters(), 1, "touching the sleeping tutorial group starts the combat")
	var cmd: Dictionary = encounters()[0]
	assert_eq(int(cmd["adv"]), Rules.PREEMPTIVE, "always caught first")
	assert_eq(str((cmd["rt"] as Dictionary)["ctl"]), ctl, "the controlled figure")
	assert_true(bool(director.ctx.get("closed", false)), "tutorial: closed set")
	assert_true(bool(director.ring.call("shutters_down")), "the doors close (roll shutters)")


static func _unit_of(member: String) -> String:
	return "p%d" % DB.party_member(member).battle_slot


func test_no_set_in_the_stairs_room() -> void:
	await make_world()
	place_player(Vector2i(1, 0), Vector3(2.0, 0.0, 2.0), 0.0)
	scene.call("_trigger_encounter", "f1_g14", "enc_f1_d3", Rules.NORMAL, "")
	assert_null(Game.combat, "the stairs room has no set: no combat starts there")
	assert_false(director.is_busy())
	var stairs: Vector3 = scene.get_layout().cell_to_world(Vector2i(1, 0))
	assert_true(bool(scene.call("_rt_cell_blocked", stairs)), "enemies never enter the stairs room")
	assert_false(bool(scene.call("_rt_cell_blocked", scene.get_layout().cell_to_world(Vector2i(1, 1)))))


func test_show_boss_groups_spawn() -> void:
	await make_world()
	var spawn: EnemySpawn = scene.get_layout().enemies[0]
	var enc: EncounterDef = Game.floor_def().encounter(spawn.encounter_id)
	var saved: Dictionary = enc.show_boss
	enc.show_boss = {"id": "test"}
	assert_true(bool(scene.call("_rt_spawn_allowed", spawn)), "the show boss spawns (every run fights in real time)")
	enc.show_boss = {}
	assert_true(bool(scene.call("_rt_spawn_allowed", spawn)), "groups without show_boss always spawn")
	enc.show_boss = saved


func test_mitziehen_up_to_six_units_the_rest_waits_at_the_ring() -> void:
	await make_world("win", 300)
	var cell: Vector2i = Vector2i(1, 3)
	place_player(cell, Vector3(0.0, 0.0, 2.5), 0.0)
	place_lead("f1_g3", cell, Vector3(0.0, 0.0, -1.0), PI)
	place_lead("f1_g1", cell, Vector3(1.5, 0.0, 0.0), PI)          # 3 units, nearer to the centre
	var waiting: Node3D = place_lead("f1_g2", cell, Vector3(-3.0, 0.0, 2.0), 0.0)   # 2 units: 3 + 3 + 2 > 6
	var far: Node3D = scene.get_enemy("f1_g0")
	assert_true(scene.pull("f1_g3", "skill", "skl_x"))
	assert_eq(director.ctx["groups"], PackedStringArray(["f1_g3", "f1_g1"]), "trigger group, then by distance")
	assert_eq(director.ctx["waiting"], PackedStringArray(["f1_g2"]), "the group that would exceed 6 units waits")
	var gs: Array = (encounters()[0]["rt"] as Dictionary)["groups"]
	assert_len(gs, 2, "both participating groups recorded with their lead poses")
	assert_eq(Game.combat.units().size(), 2 + 6, "party + 6 enemy units")
	var center: Vector3 = scene.get_layout().cell_to_world(cell)
	var r: float = float(int((director.ctx["geo"] as Dictionary)["r"])) / 100.0
	assert_gt(Rules.flat_dist(waiting.global_position, center), r + 0.5, "the waiting lead stands outside the ring")
	assert_true(waiting.visible, "… visible")
	assert_true(bool(waiting.get("frozen")), "… frozen")
	assert_false(far.visible, "actors of other rooms are hidden during the combat")
	assert_true(advance_until(func() -> bool: return not director.is_running(), 2000), "the combat ends")
	assert_null(scene.get_enemy("f1_g3"), "victory: the defeated groups are gone")
	assert_null(scene.get_enemy("f1_g1"))
	assert_not_null(scene.get_enemy("f1_g2"), "the waiting group stays …")
	assert_eq(StringName(waiting.get("state")), &"RETURN", "… and goes RETURN")
	assert_false(bool(waiting.get("frozen")))
	await wait_frames(2)
	assert_false(Game.in_battle)
	assert_true(scene.get_player().is_hidden(), "after-battle grace")


func test_ring_collision_and_door_lanes() -> void:
	await make_world("loop", 900)
	var cell: Vector2i = Vector2i(1, 4)
	place_player(cell, Vector3(0.0, 0.0, 2.0), 0.0)
	place_lead("f1_g1", cell, Vector3(0.0, 0.0, -1.0), PI)
	assert_true(scene.pull("f1_g1", "skill", "skl_x"))
	var doors: int = scene.rt_room_doors(cell)
	assert_true(doors & RoomCell.DOOR_E != 0, "(1,4) has an open east door")
	assert_true(doors & RoomCell.DOOR_W == 0, "… and a wall in the west")
	await wait_frames(2)
	var c: Vector3 = scene.get_layout().cell_to_world(cell) + Vector3(0.0, 0.5, 0.0)
	var west: Dictionary = _ray(c, c + Vector3(-5.9, 0.0, 0.0))
	assert_false(west.is_empty(), "the collision ring stops the figure")
	if not west.is_empty():
		assert_between(c.distance_to(west["position"] as Vector3), 4.6, 4.81, "at the ring (4.8 m)")
		assert_eq(west["rid"], director.ring.call("body_rid"))
	assert_true(_ray(c, c + Vector3(5.9, 0.0, 0.0)).is_empty(), "the east door lane is open (flight)")
	var lane_wall: Dictionary = _ray(c + Vector3(5.4, 0.0, -1.0), c + Vector3(5.4, 0.0, -3.0))
	assert_false(lane_wall.is_empty(), "the lane has side walls (no walking around the ring outside)")
	assert_eq(int(director.ring.call("ring_arcs", 480, doors).size()), _bits(doors), "one gap per open door")
	var mesh_count: int = 0
	for n: Node in director.ring.find_children("*", "MeshInstance3D", true, false):
		if (n as MeshInstance3D).visible and n.get_parent() == director.ring:
			mesh_count += 1
	assert_eq(mesh_count, 1, "the LED ring is ONE mesh (1 draw call)")


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 1)
	return scene.get_world_3d().direct_space_state.intersect_ray(q)


static func _bits(v: int) -> int:
	var n: int = 0
	for b: int in RoomCell.DIR_BITS:
		n += 1 if v & b != 0 else 0
	return n


func test_puppets_show_the_sim_positions() -> void:
	await make_world("win", 600)
	var cell: Vector2i = Vector2i(1, 4)
	place_player(cell, Vector3(0.0, 0.0, 2.0), 0.0)
	place_lead("f1_g1", cell, Vector3(0.0, 0.0, -1.5), PI)
	assert_true(scene.pull("f1_g1", "skill", "skl_x"))
	for step: int in [10, 25, 40]:
		director.advance(step)
		for u: RtUnit in Game.combat.units():
			if u.id == director.controlled_unit() or u.hp <= 0:
				continue
			var p: Vector3 = director.unit_position(u.id)
			var want: Vector3 = world_of(u.x, u.z)
			assert_lt(Vector2(p.x - want.x, p.z - want.z).length(), 0.0101, "%s at the sim position" % u.id)
	assert_true(bool(scene.get_enemy("f1_g1").get("puppet")), "the lead is a puppet (no AI, no physics)")
	assert_true(bool(scene.get_companion().get("puppet")), "the AI partner too")
	assert_false("puppet" in scene.get_player(), "the controlled figure is never a puppet")


func test_interactions_are_locked_in_a_combat() -> void:
	await make_world("loop", 900)
	place_player(Vector2i(1, 4), Vector3(0.0, 0.0, 2.0), 0.0)
	place_lead("f1_g1", Vector2i(1, 4), Vector3(0.0, 0.0, -1.0), PI)
	assert_true(scene.pull("f1_g1", "skill", "skl_x"))
	scene.perform_action()
	assert_false(scene.get_player().is_striking(), "the action key has its combat meaning: no field strike")
	assert_false(scene.pull("f1_g1", "item", "itm_x"))
	assert_true(bool(scene.call("_rt_busy")))
	assert_true(bool(scene.get_player().get("rt_combat")), "combat movement (no sneaking)")


func test_flight_resets_the_groups() -> void:
	await make_world("flee", 300)
	var cell: Vector2i = Vector2i(1, 4)
	place_player(cell, Vector3(0.0, 0.0, 2.0), 0.0)
	var a: Node3D = place_lead("f1_g1", cell, Vector3(0.0, 0.0, -1.0), PI)
	assert_true(scene.pull("f1_g1", "skill", "skl_x"))
	assert_true(advance_until(func() -> bool: return not director.is_running(), 400))
	assert_eq(int(director.last_result.outcome), BattleResult.Outcome.FLED)
	assert_not_null(scene.get_enemy("f1_g1"), "a fled-from group stays")
	assert_eq(StringName(a.get("state")), &"RETURN", "… resets to its leash point (RETURN)")
	assert_false(bool(a.get("puppet")))
	assert_false(bool(a.get("frozen")))
	assert_false(Game.in_battle)
	assert_null(Game.combat)
	assert_true(scene.get_player().is_hidden(), "2 s grace")
	assert_false(bool(scene.get_player().get("rt_combat")))
	assert_true(await wait_until(func() -> bool: return director.ring == null, 900),
		"the ring faded out and left with its collision")


func test_control_follows_life_and_the_hero_returns() -> void:
	await make_world("defeat", 600)
	var cell: Vector2i = Vector2i(1, 4)
	place_player(cell, Vector3(0.0, 0.0, 2.0), 0.0)
	place_lead("f1_g1", cell, Vector3(0.0, 0.0, -1.0), PI)
	assert_true(scene.pull("f1_g1", "skill", "skl_x"))
	var kai_unit: String = director.controlled_unit()
	assert_true(advance_until(func() -> bool: return director.controlled_unit() != kai_unit, 600), "Kai falls")
	assert_eq(scene.get_player().hero_id, "mopsula", "the player body becomes Graf Mopsula")
	assert_eq(str(scene.get_companion().get("member_id")), "kai", "the follower body takes the fallen Kai")
	assert_true(bool(director.puppets.call("is_ko", kai_unit)), "… lying K.O.")
	assert_eq(Game.hero(), "kai", "GameState.hero does not change")
	assert_true(advance_until(func() -> bool: return not director.is_running(), 1200))
	assert_eq(int(director.last_result.outcome), BattleResult.Outcome.DEFEAT)
	assert_eq(scene.get_player().hero_id, "kai", "the roles swap back at the end (refresh_hero)")
	assert_eq(str(scene.get_companion().get("member_id")), "mopsula")
