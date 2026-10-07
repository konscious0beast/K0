extends TestCase
## ExplorationScene (02_TECH §7.3, §9.2, §11.5): headless instancing, spawn not inside a wall, room changes,
## force_encounter → Events.encounter_triggered (signal spy) and — once BattleBridge is real — Router → BattleScene,
## interactions (chest, event dialog, stairs dialog), suspend/resume protocol, safe-room return, strays, movement,
## companion and camera. Generic over the floor_1 data (cells are looked up by kind, not hard-coded).

const Rules := preload("res://scenes/exploration/encounter_rules.gd")
const EnemyActor := preload("res://scenes/exploration/enemy_actor.gd")
const GateInteractable := preload("res://scenes/exploration/gate_interactable.gd")
const SCENE: String = "res://scenes/exploration/exploration.tscn"
const ROUTER_FIXTURE: String = "res://tests/fixtures/router/router_screen.tscn"
const STUB_HEADER: String = "# STUB(M0)"
const MAX_FRAMES: int = 240

var _spy: Array[Array] = []


func before_each() -> void:
	Engine.time_scale = 8.0
	_spy.clear()
	Game.new_game(0, "Kai", 4242)


func after_each() -> void:
	Engine.time_scale = 1.0
	for a: StringName in [&"move_forward", &"move_back", &"move_left", &"move_right", &"sneak", &"action",
			&"cam_left", &"cam_right"]:
		Input.action_release(a)
	var cur0: Node = Router.current
	if Router.stack_size() > 1 or Router.busy or (cur0 != null and not cur0 is ExplorationScene):
		Router.goto(ROUTER_FIXTURE, {}, Router.Transition.NONE)
		await wait_until(func() -> bool: return not Router.busy, MAX_FRAMES)
		var cur: Node = Router.current
		if cur != null and is_instance_valid(cur) and cur.scene_file_path == ROUTER_FIXTURE:
			if cur.get_parent() != null:
				cur.get_parent().remove_child(cur)
			cur.free()
	Router.adopt(null)
	Game.timer_running = false


func _record(a0: Variant = null, a1: Variant = null, a2: Variant = null) -> void:
	_spy.append([a0, a1, a2])


## Instantiates the scene (optionally with setup params), adds it to the tree, waits for physics to settle.
func _make_scene(params: Dictionary = {}) -> ExplorationScene:
	var packed: PackedScene = load(SCENE) as PackedScene
	var scene: ExplorationScene = packed.instantiate() as ExplorationScene
	scene.setup(params)
	add_to_tree(scene)
	await wait_frames(6)
	return scene


static func _cell_center(layout: FloorLayout, c: Vector2i) -> Vector3:
	return layout.cell_to_world(c)


## First neighbour of the start that is reachable through an open door.
static func _start_neighbor(layout: FloorLayout) -> Vector2i:
	var ns: Array[Vector2i] = layout.neighbors(layout.start)
	return ns[0] if not ns.is_empty() else layout.start


func _is_stub(path: String) -> bool:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	return f == null or f.get_line().begins_with(STUB_HEADER)


# --- building ----------------------------------------------------------------------------------------------------------

func test_scene_builds_the_floor() -> void:
	Events.floor_entered.connect(_record)
	Events.room_entered.connect(_record)
	var scene: ExplorationScene = await _make_scene()
	Events.floor_entered.disconnect(_record)
	Events.room_entered.disconnect(_record)
	var layout: FloorLayout = scene.get_layout()
	assert_not_null(layout)
	if layout == null:
		return
	assert_eq(layout.validate(), PackedStringArray())
	var rooms: Node = scene.get_node_or_null("World/Rooms")
	assert_not_null(rooms)
	if rooms != null:
		assert_eq(rooms.get_child_count(), layout.cells.size(), "one room node per cell")
		var start_room: Node3D = rooms.get_node_or_null("Room_%d_%d" % [layout.start.x, layout.start.y]) as Node3D
		assert_not_null(start_room, "rooms are named Room_<x>_<y>")
		if start_room != null:
			assert_eq(start_room.position, layout.cell_to_world(layout.start))
			assert_gt(start_room.get_child_count(), 0, "art kit or fallback built the room")
	var expected_interactables: int = layout.chests.size() + layout.events.size() + 1 + layout.safe_rooms.size() \
		+ layout.gates.size()
	assert_eq(scene.get_node("World/Interactables").get_child_count(), expected_interactables,
		"chests + events + stairs + safe doors + closed gates")
	assert_eq(scene.living_groups().size(), layout.enemies.size(), "every group of a fresh floor is alive")
	assert_eq(scene.get_player_cell(), layout.start, "Kai starts in the START cell")
	assert_true(Game.timer_running, "exploration view active")
	assert_has(Game.state.floor_run.visited, layout.start)
	var floor_entered: int = 0
	var start_entered: bool = false
	for call: Array in _spy:
		if call[0] is int and call[1] == null:
			floor_entered += 1
		elif call[0] is Vector2i and call[0] == layout.start:
			start_entered = bool(call[2])
	assert_eq(floor_entered, 1, "Events.floor_entered once on the first entry")
	assert_true(start_entered, "Events.room_entered(start, kind, first_visit = true)")
	assert_not_null(scene.get_companion())
	assert_true(scene.get_camera_rig().camera().current, "exploration camera is current")
	assert_false(scene.recent_events().is_empty(), "ExploreEvents are logged")
	for ev: ExploreEvent in scene.recent_events():
		assert_not_null(JSON.parse_string(JSON.stringify(ev.to_dict())), "ExploreEvent is JSON-safe")


func test_spawn_is_not_inside_a_wall() -> void:
	var scene: ExplorationScene = await _make_scene()
	await wait_frames(10)
	var pos: Vector3 = scene.get_player_position()
	assert_eq(scene.get_player_cell(), scene.get_layout().start)
	assert_between(pos.y, -0.05, 0.3, "Kai stands on the floor")
	var params: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.7
	params.shape = cap
	params.transform = Transform3D(Basis(), pos + Vector3(0.0, 0.95, 0.0))
	params.collision_mask = 1
	var hits: Array[Dictionary] = scene.get_world_3d().direct_space_state.intersect_shape(params, 4)
	assert_eq(hits.size(), 0, "no world collider overlaps Kai's capsule at the spawn")
	var comp: Vector3 = scene.get_companion().global_position
	assert_lt(Rules.flat_dist(comp, pos), 3.0, "Mopsula next to Kai")


func test_player_moves_with_input() -> void:
	var scene: ExplorationScene = await _make_scene()
	var p0: Vector3 = scene.get_player_position()
	Input.action_press(&"move_forward")
	await wait_frames(12)
	Input.action_release(&"move_forward")
	await wait_frames(2)
	var moved: float = Rules.flat_dist(p0, scene.get_player_position())
	assert_gt(moved, 1.0, "Kai walked forward (camera relative)")
	var cam_fwd: Vector3 = scene.get_camera_rig().flat_forward()
	var dir: Vector3 = Rules.flat_dir(p0, scene.get_player_position())
	assert_gt(cam_fwd.dot(dir), 0.9, "move_forward follows the camera direction")


func test_room_change_visits_the_room() -> void:
	var scene: ExplorationScene = await _make_scene()
	var layout: FloorLayout = scene.get_layout()
	var target: Vector2i = _start_neighbor(layout)
	assert_ne(target, layout.start, "start has a neighbour")
	Events.room_entered.connect(_record)
	# Stand 4 m inside the neighbour room, away from its centre (placed groups stand around the centre).
	var dir: Vector2i = target - layout.start
	var pos: Vector3 = _cell_center(layout, target) - Vector3(dir.x, 0.0, dir.y) * 4.0
	scene.get_player().teleport(pos + Vector3(0.0, 0.05, 0.0), 0.0)
	await wait_frames(4)
	Events.room_entered.disconnect(_record)
	assert_eq(scene.get_player_cell(), target)
	assert_has(Game.state.floor_run.visited, target, "Game.visit_room recorded the first visit")
	var seen: bool = false
	for call: Array in _spy:
		if call[0] == target and call[1] == int(layout.cell_at(target).kind) and bool(call[2]):
			seen = true
	assert_true(seen, "Events.room_entered(cell, kind, true)")


# --- encounters --------------------------------------------------------------------------------------------------------

func test_force_encounter_signal_spy_nearest_group() -> void:
	var scene: ExplorationScene = await _make_scene()
	scene.auto_start_battle = false
	var layout: FloorLayout = scene.get_layout()
	var nearest: String = ""
	var best: float = INF
	for gid: String in scene.living_groups():
		var a: EnemyActor = scene.get_enemy(gid)
		if a.is_boss():
			continue
		var d: float = a.global_position.distance_to(scene.get_player_position())
		if d < best:
			best = d
			nearest = gid
	Events.encounter_triggered.connect(_record)
	scene.force_encounter("")
	Events.encounter_triggered.disconnect(_record)
	assert_len(_spy, 1, "exactly one encounter")
	if _spy.size() == 1:
		assert_eq(_spy[0][0], nearest, "nearest living non-boss group")
		assert_eq(_spy[0][1], layout.enemy_by_id(nearest).encounter_id if nearest != "" else _spy[0][1])
		assert_eq(_spy[0][2], Rules.NORMAL, "forced encounters are NORMAL")
	var last: ExploreEvent = scene.recent_events().back()
	assert_eq(last.type, ExploreEvent.Type.ENCOUNTER)
	assert_false(scene.is_encounter_pending(), "spy mode returns to exploring")
	assert_true(scene.get_player().is_hidden(), "after-battle grace")


func test_force_encounter_specific_and_fallback() -> void:
	var scene: ExplorationScene = await _make_scene()
	scene.auto_start_battle = false
	var groups: PackedStringArray = scene.living_groups()
	Events.encounter_triggered.connect(_record)
	if not groups.is_empty():
		scene.force_encounter(groups[groups.size() - 1])
		assert_eq(_spy.back()[0], groups[groups.size() - 1], "explicit group id")
	# No living group left → first non-boss encounter of the floor with group "".
	for gid: String in groups:
		Game.state.floor_run.defeated_groups.append(gid)
	scene.on_resume({})
	await wait_frames(2)
	assert_eq(scene.living_groups().size(), 0, "defeated groups are removed on resume")
	_spy.clear()
	scene.force_encounter("")
	Events.encounter_triggered.disconnect(_record)
	var first_enc: String = ""
	for enc: EncounterDef in Game.floor_def().encounters:
		if not enc.boss:
			first_enc = enc.id
			break
	assert_len(_spy, 1)
	if _spy.size() == 1:
		assert_eq(_spy[0][0], "")
		assert_eq(_spy[0][1], first_enc)


func test_force_encounter_starts_battle_via_router() -> void:
	if _is_stub("res://core/progression/battle_bridge.gd"):
		skip("BattleBridge (M2) is still the M0 stub: no BattleSetup")
		return
	var scene: ExplorationScene = await _make_scene()
	assert_eq(Router.current, scene, "add_to_tree adopted the screen")
	scene.force_encounter("")
	var ok: bool = await wait_until(func() -> bool: return Router.current is BattleScene and not Router.busy,
		MAX_FRAMES)
	assert_true(ok, "Router.current is BattleScene")
	assert_false(scene.is_inside_tree(), "exploration detached, not freed (stack model)")
	assert_false(Game.timer_running)


func test_contact_and_strike_advantage_rules() -> void:
	var back: float = Balance.BACK_DOT
	var e: Vector3 = Vector3.ZERO
	var north: Vector3 = Vector3(0, 0, -1)
	var kai_behind: Vector3 = Vector3(0, 0, 1.0)     # south of an enemy looking north
	var kai_front: Vector3 = Vector3(0, 0, -1.0)
	# Strike: IDLE/PATROL always preemptive, ALERT/CHASE only from behind, bosses never.
	assert_eq(Rules.strike_advantage(&"IDLE", e, north, kai_front, false, back), Rules.PREEMPTIVE)
	assert_eq(Rules.strike_advantage(&"PATROL", e, north, kai_front, false, back), Rules.PREEMPTIVE)
	assert_eq(Rules.strike_advantage(&"CHASE", e, north, kai_front, false, back), Rules.NORMAL)
	assert_eq(Rules.strike_advantage(&"ALERT", e, north, kai_behind, false, back), Rules.PREEMPTIVE)
	assert_eq(Rules.strike_advantage(&"IDLE", e, north, kai_behind, true, back), Rules.NORMAL)
	# Contact: Kai touches a non-chasing group from behind → preemptive; from the front → normal.
	assert_eq(Rules.contact_advantage(&"PATROL", e, north, kai_behind, north, false, true, back), Rules.PREEMPTIVE)
	assert_eq(Rules.contact_advantage(&"IDLE", e, north, kai_front, Vector3(0, 0, 1), false, true, back), Rules.NORMAL)
	assert_eq(Rules.contact_advantage(&"CHASE", e, north, kai_behind, north, false, true, back), Rules.NORMAL,
		"a chasing group touched from behind is NORMAL (not preemptive)")
	# Chasing group comes from behind Kai: Kai looks away from it → ambush.
	var kai_fwd_away: Vector3 = Vector3(0, 0, 1)      # Kai at (0,0,1) looks south, enemy at origin is behind him
	assert_eq(Rules.contact_advantage(&"CHASE", e, Vector3(0, 0, 1), kai_behind, kai_fwd_away, false, true, back),
		Rules.AMBUSH)
	assert_eq(Rules.contact_advantage(&"CHASE", e, Vector3(0, 0, 1), kai_behind, kai_fwd_away, false, false, back),
		Rules.NORMAL, "immobile groups never ambush")
	assert_eq(Rules.contact_advantage(&"CHASE", e, Vector3(0, 0, 1), kai_behind, kai_fwd_away, true, true, back),
		Rules.NORMAL, "bosses always NORMAL")
	# Side contact: 90° is not "behind" (110° threshold).
	assert_eq(Rules.contact_advantage(&"PATROL", e, north, Vector3(1, 0, 0), north, false, true, back), Rules.NORMAL)
	# Arc / cone helpers.
	assert_true(Rules.in_arc(e, north, Vector3(0.5, 0, -1.5), Rules.STRIKE_RANGE, Rules.STRIKE_ARC_DEG))
	assert_false(Rules.in_arc(e, north, Vector3(0, 0, -1.9), Rules.STRIKE_RANGE, Rules.STRIKE_ARC_DEG), "out of reach")
	assert_false(Rules.in_arc(e, north, Vector3(1.5, 0, -0.2), Rules.STRIKE_RANGE, Rules.STRIKE_ARC_DEG), "outside 100°")
	assert_almost(Rules.hearing_radius({"hear_run": 4.0, "hear_sneak": 1.5}, true, false), 4.0)
	assert_almost(Rules.hearing_radius({"hear_run": 4.0, "hear_sneak": 1.5}, true, true), 1.5)
	assert_true(Rules.should_give_up(4.0, 0.0, 0.0, {"giveup_no_sight": 4.0, "leash": 20.0, "max_chase": 8.0}))
	assert_true(Rules.should_give_up(0.0, 20.5, 0.0, {"giveup_no_sight": 4.0, "leash": 20.0, "max_chase": 8.0}))
	assert_true(Rules.should_give_up(0.0, 0.0, 8.0, {"giveup_no_sight": 4.0, "leash": 20.0, "max_chase": 8.0}))
	assert_false(Rules.should_give_up(1.0, 5.0, 2.0, {"giveup_no_sight": 4.0, "leash": 20.0, "max_chase": 8.0}))
	assert_almost(Rules.yaw_of(Vector3(0, 0, -1)), 0.0)
	assert_almost(Rules.flat_forward(Basis(Vector3.UP, Rules.yaw_of(Vector3(1, 0, 0)))).x, 1.0)


func test_field_strike_from_behind_is_preemptive() -> void:
	var scene: ExplorationScene = await _make_scene()
	scene.auto_start_battle = false
	var target: EnemyActor = null
	for gid: String in scene.living_groups():
		var a: EnemyActor = scene.get_enemy(gid)
		if not a.is_boss():
			target = a
			break
	if target == null:
		skip("floor has no regular group")
		return
	target.frozen = true
	var fwd: Vector3 = target.flat_forward()
	var kai_pos: Vector3 = target.global_position - fwd * 1.5
	scene.get_player().teleport(kai_pos, Rules.yaw_of(fwd))
	await wait_frames(2)
	Events.encounter_triggered.connect(_record)
	scene.perform_action()
	await wait_until(func() -> bool: return not _spy.is_empty(), 60)
	Events.encounter_triggered.disconnect(_record)
	assert_len(_spy, 1, "the swing hit the group")
	if _spy.size() == 1:
		assert_eq(_spy[0][0], target.group_id())
		assert_eq(_spy[0][2], Rules.PREEMPTIVE)


func test_contact_triggers_encounter() -> void:
	var scene: ExplorationScene = await _make_scene()
	scene.auto_start_battle = false
	var target: EnemyActor = null
	for gid: String in scene.living_groups():
		var a: EnemyActor = scene.get_enemy(gid)
		if not a.is_boss():
			target = a
			break
	if target == null:
		skip("floor has no regular group")
		return
	Events.encounter_triggered.connect(_record)
	var fwd: Vector3 = target.flat_forward()
	scene.get_player().teleport(target.global_position + fwd * 0.8, Rules.yaw_of(-fwd))
	await wait_until(func() -> bool: return not _spy.is_empty(), 30)
	Events.encounter_triggered.disconnect(_record)
	assert_false(_spy.is_empty(), "contact ≤ 1.1 m starts an encounter")
	if not _spy.is_empty():
		assert_eq(_spy[0][0], target.group_id())
		assert_ne(_spy[0][2], Rules.PREEMPTIVE, "touching the front is not a preemptive strike")


# --- stack protocol ----------------------------------------------------------------------------------------------------

func test_suspend_and_resume_after_battle() -> void:
	var scene: ExplorationScene = await _make_scene()
	var groups: PackedStringArray = scene.living_groups()
	Input.action_press(&"move_forward")
	scene.on_suspend()
	assert_false(Game.timer_running, "on_suspend stops the floor timer")
	assert_false(Input.is_action_pressed(&"move_forward"), "move actions released")
	if groups.is_empty():
		scene.on_resume({})
		assert_true(Game.timer_running)
		return
	var fled: BattleResult = BattleResult.new()
	fled.outcome = BattleResult.Outcome.FLED
	fled.group_id = groups[0]
	scene.on_resume({"battle_result": fled})
	await wait_frames(2)
	assert_true(Game.timer_running, "on_resume restarts the floor timer")
	assert_has(scene.living_groups(), groups[0], "a fled-from group stays")
	assert_true(scene.get_player().is_hidden(), "2 s grace after a battle")
	scene.on_suspend()
	var won: BattleResult = BattleResult.new()
	won.outcome = BattleResult.Outcome.VICTORY
	won.group_id = groups[0]
	scene.on_resume({"battle_result": won})
	await wait_frames(2)
	assert_false(scene.living_groups().has(groups[0]), "a defeated group disappears")


func test_resume_from_safe_room_places_kai_at_the_door() -> void:
	var scene: ExplorationScene = await _make_scene()
	var layout: FloorLayout = scene.get_layout()
	if layout.safe_rooms.is_empty():
		skip("floor has no safe room")
		return
	var sid: String = layout.safe_room_at(layout.safe_rooms[0])
	Game.enter_safe_room(sid)
	assert_eq(Game.state.floor_run.location, StringName(sid))
	scene.on_suspend()
	scene.on_resume({"from_safe_room": sid})
	await wait_frames(3)
	assert_eq(Game.state.floor_run.location, &"start", "Game.leave_safe_room")
	assert_eq(scene.get_player_cell(), layout.safe_rooms[0], "Kai stands in the safe-room cell")
	var door: Node3D = scene.get_interactable(sid) as Node3D
	assert_not_null(door, "safe door interactable")
	if door != null:
		assert_almost(Rules.flat_dist(door.global_position, scene.get_player_position()), 1.2, 0.25,
			"1.2 m in front of the safe_door anchor")
		var to_center: Vector3 = Rules.flat_dir(scene.get_player_position(), layout.cell_to_world(layout.safe_rooms[0]))
		if to_center != Vector3.ZERO:
			assert_gt(scene.get_player().flat_forward().dot(to_center), 0.9, "looking at the room centre")


func test_capture_spawn_at_safe_room_does_not_push() -> void:
	var probe: FloorLayout = DungeonGenerator.generate(Game.floor_def(), Game.state.floor_run.seed)
	if probe.safe_rooms.is_empty():
		skip("floor has no safe room")
		return
	var sid: String = probe.safe_room_at(probe.safe_rooms[0])
	var scene: ExplorationScene = await _make_scene({"spawn": StringName(sid), "capture": true})
	await wait_frames(4)
	assert_eq(scene.get_player_cell(), probe.safe_rooms[0], "spawn in front of the safe-room door")
	assert_eq(Router.current, scene, "capture mode never enters the safe room")


# --- interactions ------------------------------------------------------------------------------------------------------

func test_chest_interaction_opens_chest() -> void:
	var scene: ExplorationScene = await _make_scene()
	var layout: FloorLayout = scene.get_layout()
	var chest: ChestSpawn = null
	for ch: ChestSpawn in layout.chests:
		if ch.type != "locked":
			chest = ch
			break
	if chest == null:
		skip("floor has no unlocked chest")
		return
	var it: Node3D = scene.get_interactable(chest.id) as Node3D
	assert_not_null(it)
	var spot: Vector3 = it.global_position + Rules.flat_forward(it.global_transform.basis) * 1.1
	scene.get_player().teleport(spot, Rules.yaw_of(Rules.flat_dir(spot, it.global_position)))
	await wait_frames(4)
	assert_eq(scene.focused_interactable(), it, "chest in reach and in front → focused")
	Events.chest_opened.connect(_record)
	scene.perform_action()
	await wait_frames(2)
	Events.chest_opened.disconnect(_record)
	assert_has(Game.state.floor_run.opened_chests, chest.id, "Game.open_chest")
	assert_true(bool(it.get("is_open")))
	assert_eq(_spy.size(), 1, "Events.chest_opened once")
	assert_eq(it.call("prompt_text"), "", "open chests have no prompt")
	await wait_frames(2)
	assert_ne(scene.focused_interactable(), it)


func test_locked_chest_needs_the_key() -> void:
	var scene: ExplorationScene = await _make_scene()
	var locked: ChestSpawn = null
	for ch: ChestSpawn in scene.get_layout().chests:
		if ch.type == "locked":
			locked = ch
	if locked == null:
		skip("floor has no locked chest")
		return
	var it: Node = scene.get_interactable(locked.id)
	assert_has(str(it.call("prompt_text")), "Verschlossen")
	it.call("interact")
	assert_false(Game.state.floor_run.opened_chests.has(locked.id))


func test_event_dialog_choice_and_timer_pause() -> void:
	var scene: ExplorationScene = await _make_scene()
	var ev: EventSpawn = null
	for e: EventSpawn in scene.get_layout().events:
		if e.type == "photo_drone":
			ev = e
	if ev == null:
		skip("floor has no photo_drone event")
		return
	var it: Node = scene.get_interactable(ev.id)
	assert_has(str(it.call("prompt_text")), "Untersuchen")
	it.call("interact")
	var dlg: Node = scene.active_dialog()
	assert_not_null(dlg, "choice dialog open")
	assert_true(scene.is_modal())
	assert_false(Game.timer_running, "event dialogs pause the floor timer")
	assert_false(scene.get_player().input_enabled, "Kai frozen while the dialog is open")
	await wait_frames(4)
	assert_ne(dlg.get_viewport().gui_get_focus_owner(), null, "dialog has a focused option")
	Events.event_completed.connect(_record)
	dlg.call("choose", "pose")
	await wait_frames(2)
	Events.event_completed.disconnect(_record)
	assert_false(scene.is_modal())
	assert_true(Game.timer_running, "timer runs again")
	assert_has(Game.state.floor_run.completed_events, ev.id)
	assert_eq(_spy.size(), 1, "Events.event_completed")
	assert_eq(str(it.call("prompt_text")), "", "completed event has no prompt")
	var last: ExploreEvent = scene.recent_events().back()
	assert_eq(last.type, ExploreEvent.Type.EVENT_CHOICE)


func test_stairs_dialog_cancel_keeps_floor() -> void:
	var scene: ExplorationScene = await _make_scene()
	var stairs: Node = scene.get_interactable("stairs")
	assert_not_null(stairs)
	assert_eq(str(stairs.call("prompt_text")), "Treppe nach unten: Etage verlassen")
	stairs.call("interact")
	var dlg: Node = scene.active_dialog()
	assert_not_null(dlg)
	assert_eq(int(dlg.call("buttons").size()), 2, "[Abstieg] [Noch nicht]")
	Events.floor_completed.connect(_record)
	dlg.call("cancel")
	await wait_frames(2)
	Events.floor_completed.disconnect(_record)
	assert_eq(_spy.size(), 0, "cancel does not descend")
	assert_false(scene.is_modal())


func test_stairs_descend_completes_floor() -> void:
	var scene: ExplorationScene = await _make_scene()
	Events.floor_completed.connect(_record)
	scene.open_stairs_dialog()
	var dlg: Node = scene.active_dialog()
	assert_not_null(dlg)
	if dlg == null:
		Events.floor_completed.disconnect(_record)
		return
	dlg.call("choose", "descend")
	# The Router frees the exploration with the next frames: inspect it now (never touch a freed screen).
	assert_eq(scene.recent_events().back().type, ExploreEvent.Type.FLOOR_COMPLETED)
	Events.floor_completed.disconnect(_record)
	assert_eq(_spy.size(), 1, "Game.complete_floor → Events.floor_completed")
	assert_false(Game.timer_running, "timer stopped")
	var ok: bool = await wait_until(func() -> bool: return Router.current != null and not Router.busy \
		and Router.current.scene_file_path == Router.SCENE_FLOOR_SUMMARY, MAX_FRAMES)
	assert_true(ok, "floor summary shown")


func test_open_gate_visual_emits_gate_opened() -> void:
	var scene: ExplorationScene = await _make_scene()
	var layout: FloorLayout = scene.get_layout()
	if layout.gates.is_empty():
		skip("floor has no gate")
		return
	var g: Dictionary = layout.gates[0]
	var key: String = str(g["key"])
	var cell: Vector2i = g["cell"]
	var other: Vector2i = cell + RoomCell.dir_offset(int(g["dir"]))
	assert_false(layout.neighbors(cell, Game.state.floor_run.opened_gates).has(other), "closed gate blocks")
	var gate: Node = scene.get_interactable(key)
	assert_not_null(gate)
	Events.gate_opened.connect(_record)
	Game.open_gate(key)
	scene.open_gate_visual(key)
	Events.gate_opened.disconnect(_record)
	assert_len(_spy, 1)
	if _spy.size() == 1:
		assert_eq(_spy[0][0], cell)
		assert_eq(_spy[0][1], int(g["dir"]))
	assert_true(bool(gate.get("opened")))
	assert_true(layout.neighbors(cell, Game.state.floor_run.opened_gates).has(other), "open gate passes")
	await wait_frames(30)
	assert_null(gate.get_node_or_null("Blocker"), "blocking body removed")


func test_gate_interactable_rules() -> void:
	var holder: Node3D = Node3D.new()
	add_to_tree(holder)
	var gate: GateInteractable = GateInteractable.new()
	holder.add_child(gate)
	gate.setup_gate({"cell": Vector2i(1, 3), "dir": RoomCell.DOOR_N, "requires": "itm_key_master", "key": "1,3,N"}, {}, 1)
	assert_eq(gate.key, "1,3,N")
	assert_has(gate.prompt_text(), "Benötigt", "without the key")
	gate.interact()
	assert_false(gate.opened, "no key → stays closed")
	assert_not_null(gate.get_node_or_null("Blocker"), "blocks the door")
	var ev_gate: GateInteractable = GateInteractable.new()
	holder.add_child(ev_gate)
	ev_gate.setup_gate({"cell": Vector2i(4, 3), "dir": RoomCell.DOOR_N, "requires": "event:fev_lever", "key": "4,3,N"},
		{}, 2)
	assert_true(ev_gate.is_event_gate())
	ev_gate.interact()
	assert_false(ev_gate.opened, "event gates do not open by hand")
	ev_gate.open_visual(false)
	assert_true(ev_gate.opened)
	assert_eq(ev_gate.prompt_text(), "")
	await wait_frames(2)
	assert_null(ev_gate.get_node_or_null("Blocker"), "blocker removed")
	# Closest point on the 4 m gate line.
	var p: Vector3 = gate.reach_point(gate.global_position + Vector3(5.0, 0.0, 1.0))
	assert_almost(p.x - gate.global_position.x, 2.0, 0.001)


func test_stray_spawn_far_from_kai() -> void:
	var scene: ExplorationScene = await _make_scene()
	var layout: FloorLayout = scene.get_layout()
	if layout.spawners.is_empty():
		skip("floor has no spawner")
		return
	var zone: String = str(layout.spawners[0]["zone"])
	var pool: PackedStringArray = layout.spawners[0]["pool"]
	var gid: String = "f%d_s9" % layout.floor_index
	var cell: Vector2i = scene.stray_cell(zone)
	assert_ne(cell, Vector2i(-999, -999), "the zone has a stray cell")
	Game.state.floor_run.strays[gid] = {"zone": zone, "enc": pool[0]}
	Events.stray_spawn_requested.emit(zone, gid, pool[0])
	await wait_frames(2)
	var actor: EnemyActor = scene.get_enemy(gid)
	assert_not_null(actor, "stray spawned")
	if actor == null:
		return
	assert_eq(actor.spawn.cell, cell)
	assert_eq(actor.state, &"PATROL")
	assert_eq(layout.cell_at(cell).zone, zone)
	var dist: Dictionary = layout.distances(scene.get_player_cell(), Game.state.floor_run.opened_gates)
	for c: Vector2i in layout.zone_cells(zone):
		var rc: RoomCell = layout.cell_at(c)
		if (rc.kind == RoomCell.Kind.NORMAL or rc.kind == RoomCell.Kind.GATE) and dist.has(c) and c != cell:
			var occupied: bool = false
			for g: String in scene.living_groups():
				if g != gid and scene.get_enemy(g).spawn.cell == c:
					occupied = true
			if not occupied and int(dist[c]) >= 2:
				assert_true(int(dist[c]) <= int(dist[cell]), "largest BFS distance to Kai")


# --- actors ------------------------------------------------------------------------------------------------------------

func test_enemy_patrol_alert_chase_return() -> void:
	var scene: ExplorationScene = await _make_scene()
	scene.auto_start_battle = false
	var actor: EnemyActor = null
	for gid: String in scene.living_groups():
		var a: EnemyActor = scene.get_enemy(gid)
		if not a.is_boss() and a.can_ambush() and not a.is_asleep():
			actor = a
			break
	if actor == null:
		skip("no mobile awake group on this floor")
		return
	# Kai steps into the group's sight cone (4 m in front of it) → ALERT (0.6 s telegraph) → CHASE.
	Events.enemy_alerted.connect(_record)
	actor.frozen = true
	await wait_frames(1)
	var fwd: Vector3 = actor.flat_forward()
	var spot: Vector3 = actor.global_position + fwd * 4.0
	scene.get_player().teleport(spot, Rules.yaw_of(-fwd))
	actor.frozen = false
	await wait_until(func() -> bool: return actor.state == &"ALERT" or actor.state == &"CHASE", 120)
	Events.enemy_alerted.disconnect(_record)
	assert_false(_spy.is_empty(), "Events.enemy_alerted")
	# Hide Kai (grace) → the group loses sight and returns home.
	scene.get_player().set_grace(30.0)
	scene.get_player().teleport(scene.get_layout().cell_to_world(scene.get_layout().start), 0.0)
	var ok: bool = await wait_until(func() -> bool: return actor.state == &"RETURN" or actor.state == &"PATROL" \
		or actor.state == &"IDLE", 400)
	assert_true(ok, "chase given up")


func test_companion_follows_trail() -> void:
	var scene: ExplorationScene = await _make_scene()
	var kai: Node3D = scene.get_player()
	var mop: Node3D = scene.get_companion()
	Input.action_press(&"move_forward")
	await wait_frames(10)
	Input.action_release(&"move_forward")
	await wait_frames(20)
	var d: float = Rules.flat_dist(kai.global_position, mop.global_position)
	assert_between(d, 0.5, 4.0, "Mopsula keeps about 1.8 m behind Kai")
	# Too far → teleport.
	var layout: FloorLayout = scene.get_layout()
	var far: Vector2i = _start_neighbor(layout)
	scene.get_player().teleport(layout.cell_to_world(far) + Vector3(3.0, 0.05, 3.0), 0.0)
	await wait_frames(3)
	assert_lt(Rules.flat_dist(kai.global_position, mop.global_position), 10.0, "teleported after > 10 m")


func test_camera_rig_values_and_input() -> void:
	var scene: ExplorationScene = await _make_scene()
	var rig: Node3D = scene.get_camera_rig()
	var cam: Camera3D = scene.get_camera_rig().camera()
	assert_almost(cam.fov, 60.0)
	assert_almost(float(rig.get("arm_length")), 7.0)
	assert_almost(rad_to_deg(float(rig.get("pitch"))), -38.0, 0.01)
	var yaw0: float = float(rig.get("yaw"))
	Input.action_press(&"cam_right")
	await wait_frames(6)
	Input.action_release(&"cam_right")
	assert_lt(float(rig.get("yaw")), yaw0, "cam_right turns the view to the right")
	rig.set("pitch", deg_to_rad(-80.0))
	await wait_frames(4)
	assert_almost(rad_to_deg(float(rig.get("pitch"))), -65.0, 0.01, "pitch clamped to −65°")
	var arm: SpringArm3D = rig.get_node("Pitch/SpringArm") as SpringArm3D
	assert_eq(arm.collision_mask, 1, "spring arm collides with world only")
