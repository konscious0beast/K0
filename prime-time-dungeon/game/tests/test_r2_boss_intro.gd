extends "res://tests/fixtures/rt_world/world_case.gd"
## Boss intro in the world (07 §2.9, §12.5 test_r2_boss_intro; R2): the figure comes within 5 m of the floor boss →
## the exploration holds still, the doors close (roll shutters, closed 6 m ring, no gaps), the camera cranes, the
## banner and the blocking M.O.D. line boss_intro:<enemy_id> — the only blocking line in a combat context. The RtSim
## does not exist during the intro: the encounter is recorded only after it, with NORMAL; a dialog presenter holds the
## start until the line is done. After the victory the doors open again.

const BOSS_TAG: String = "boss_intro:enm_boss_rattenkoenigin"

var said: Array[Array] = []                # Events.mod_said: [tag, blocking]


func before_each() -> void:
	super()
	said.clear()
	Events.mod_said.connect(_on_said)


func after_each() -> void:
	if Events.mod_said.is_connected(_on_said):
		Events.mod_said.disconnect(_on_said)
	Game.set_dialog_presenter(false)
	await super()


func _on_said(_text: String, _voice: StringName, tag: String, blocking: bool) -> void:
	said.append([tag, blocking])


func _blocking_tags() -> PackedStringArray:
	var out: PackedStringArray = []
	for s: Array in said:
		if bool(s[1]):
			out.append(str(s[0]))
	return out


## Kai 4 m east of the floor boss (inside its 5 m trigger radius), facing it; returns the boss once the intro runs.
func _approach_boss() -> Node3D:
	var boss: Node3D = scene.get_enemy("f1_fb")
	var center: Vector3 = scene.get_layout().cell_to_world(Vector2i(0, 0))
	var home: Vector3 = boss.get("home")
	var spot: Vector3 = home + Vector3(4.0, 0.0, 0.5)
	place_player(Vector2i(0, 0), spot - center, yaw_to(spot, home))
	assert_true(await wait_until(func() -> bool: return director.is_busy(), 60), "the boss notices the figure")
	return boss


func test_the_intro_runs_before_the_sim_exists() -> void:
	await make_world("boss", 600)
	var boss: Node3D = await _approach_boss()
	assert_eq(director.phase, CombatDirector.Phase.INTRO)
	assert_null(Game.combat, "no RtSim during the intro")
	assert_len(encounters(), 0, "the encounter is recorded only after the intro")
	assert_true(bool(boss.get("puppet")), "the boss is awake (no \"Z z\", no AI)")
	assert_true(bool(director.ring.call("shutters_down")), "the doors close (Rolltor)")
	assert_almost(float(director.ring.get("radius_m")), 6.0, 0.001, "the closed 6 m boss ring")
	assert_len(director.ring.call("ring_arcs", 600, 0) as Array, 1, "closed: no gaps")
	assert_true(bool(scene.get_camera_rig().call("is_craning")), "Boss-Kran")
	assert_false(scene.get_player().input_enabled, "the exploration holds still")
	assert_false(Game.is_timer_ticking(), "the clock stands")
	assert_eq(_blocking_tags(), PackedStringArray([BOSS_TAG]), "the blocking intro line")
	assert_ne(director.intro_line, "")
	# without a dialog presenter nothing waits for the line: the combat starts after the crane (2.5 s)
	assert_true(await wait_until(func() -> bool: return Game.combat != null, 900), "the combat starts")
	assert_len(encounters(), 1)
	var cmd: Dictionary = encounters()[0]
	assert_eq(int(cmd["adv"]), Rules.NORMAL, "bosses: NORMAL")
	assert_eq(str(cmd["group"]), "f1_fb")
	assert_true(Game.combat.setup.is_boss)
	assert_true(director.is_running())
	assert_true(bool(director.ring.call("shutters_down")), "the doors stay closed in the combat")
	assert_true(scene.get_player().input_enabled, "the figure moves again (combat movement)")
	assert_false(bool(scene.get_camera_rig().call("is_craning")))
	# the combat: no further blocking line (07 §8.8: lines in a combat are subtitles)
	assert_true(advance_until(func() -> bool: return not director.is_running(), 1200), "the boss is beaten")
	assert_eq(_blocking_tags(), PackedStringArray([BOSS_TAG]), "the intro line stays the only blocking one")
	assert_eq(int(director.last_result.outcome), BattleResult.Outcome.VICTORY)
	assert_false(bool(director.ring.call("shutters_down")) if director.ring != null else false,
		"after the victory the doors open")


func test_a_dialog_presenter_holds_the_start_until_the_line_is_done() -> void:
	Game.set_dialog_presenter(true)
	await make_world("boss", 600)
	await _approach_boss()
	await await_signal(tree.create_timer(CombatDirector.INTRO_SEC + 0.4).timeout, 1200)
	assert_null(Game.combat, "the crane is over, the line still stands: no sim yet")
	assert_eq(director.phase, CombatDirector.Phase.INTRO)
	Events.dialog_finished.emit(BOSS_TAG)
	assert_true(await wait_until(func() -> bool: return Game.combat != null, 120), "after the line: ct = 0")
	assert_len(encounters(), 1)


func test_the_closed_set_blocks_the_boss_door() -> void:
	await make_world("boss", 600)
	await _approach_boss()
	assert_true(await wait_until(func() -> bool: return Game.combat != null, 900))
	var c: Vector3 = scene.get_layout().cell_to_world(Vector2i(0, 0)) + Vector3(0.0, 0.5, 0.0)
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(c, c + Vector3(6.4, 0.0, 0.0), 1)
	var hit: Dictionary = scene.get_world_3d().direct_space_state.intersect_ray(q)
	assert_false(hit.is_empty(), "the east door (the only one) is closed: no flight from a boss")
	if not hit.is_empty():
		assert_eq(hit["rid"], director.ring.call("body_rid"))
