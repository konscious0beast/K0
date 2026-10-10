extends TestCase
## ExplorationScene (02_TECH §7.3, §9.2, §11.5): headless instancing, spawn not inside a wall, room changes,
## force_encounter → Events.encounter_triggered (signal spy) and — once BattleBridge is real — Router → BattleScene,
## interactions (chest, gates, event dialog, stairs dialog), suspend/resume protocol, safe-room return, strays,
## movement speeds, companion, camera, the enemy state machine and the fallback visuals.
## Independent of the M7 content: every test runs on fixture_game_data() (the real tables with floor_1 replaced by a
## small fixture floor that has every placement type); test_real_floor_1_builds checks the real floor_1 once.

const Rules := preload("res://scenes/exploration/encounter_rules.gd")
const EnemyActor := preload("res://scenes/exploration/enemy_actor.gd")
const GateInteractable := preload("res://scenes/exploration/gate_interactable.gd")
const EventInteractable := preload("res://scenes/exploration/event_interactable.gd")
const PlayerBody := preload("res://scenes/exploration/player_controller.gd")
const FB := preload("res://scenes/exploration/fallback_art.gd")
const CameraRig := preload("res://scenes/exploration/camera_rig.gd")
const SCENE: String = "res://scenes/exploration/exploration.tscn"
const ROUTER_FIXTURE: String = "res://tests/fixtures/router/router_screen.tscn"
const MAX_FRAMES: int = 240

var _spy: Array[Array] = []
var _saved_data: GameData = null

static var _fixture: GameData = null


func before_each() -> void:
	Engine.time_scale = 8.0
	_spy.clear()
	_saved_data = DB.data
	if _fixture == null:
		_fixture = fixture_game_data()
	if _fixture != null:
		DB.data = _fixture
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
	_stop_audio()
	if _saved_data != null:
		DB.data = _saved_data


## Stops every Sfx / music player, so no playback is still alive when the runner quits (ObjectDB leak at exit).
func _stop_audio() -> void:
	Sfx.music(&"", 0.0)
	var sfx: Node = tree.root.get_node_or_null("Sfx")
	if sfx == null:
		return
	for c: Node in sfx.get_children():
		if c is AudioStreamPlayer:
			(c as AudioStreamPlayer).stop()
			(c as AudioStreamPlayer).stream = null


# --- fixture data -----------------------------------------------------------------------------------------------------

## The real tables (res://data) with floor_1 replaced by the fixture floor below; null + fail on a data error.
##   y=4        [3,4 n]   [4,4 n]          key gate (3,5)↑(3,4): itm_key_master · event gate (4,5)↑(4,4): fev_t_lever
##                 ╪         ╪
##   y=5  [2,5 T]-[3,5 n]   [4,5 n]        T stairs, S safe room, n normal, * start
##                 |         |
##   y=6  [2,6 S]-[3,6 n]-[4,6 n]
##                 |
##   y=7          [3,7 *]
## lever_success: params.success of fev_t_lever (0.0 → the pull always floods).
static func fixture_game_data(lever_success: float = 0.6) -> GameData:
	var raw: Dictionary = {}
	for t: String in GameData.TABLES:
		var f: FileAccess = FileAccess.open("res://data/%s.json" % t, FileAccess.READ)
		var parsed: Variant = JSON.parse_string(f.get_as_text()) if f != null else null
		raw[t] = parsed if parsed is Dictionary else {"schema": 1, "entries": []}
	var floors: Array = (raw["floors"] as Dictionary).get("entries", [])
	var base: Dictionary = {}
	for i in floors.size():
		if str((floors[i] as Dictionary).get("id", "")) == "floor_1":
			base = floors[i]
			floors.remove_at(i)
			break
	floors.insert(0, fixture_floor(base, lever_success))
	var data: GameData = GameData.new()
	if not data.load_from_tables(raw, "m3_fixture"):
		printerr("Assertion failed: m3 fixture data invalid: " + "; ".join(data.errors))
		return null
	return data


static func fixture_floor(base: Dictionary, lever_success: float = 0.6) -> Dictionary:
	var f: Dictionary = base.duplicate(true)
	f["id"] = "floor_1"
	f["index"] = 1
	f["timer_start_after"] = "enc_t_tutorial"
	f["grid"] = {"w": 8, "h": 8}
	# The fixture floor has no bosses: the real floor_1 (M7) names its boss encounters, which are not in this table.
	f["quarter_boss"] = ""
	f["floor_boss"] = ""
	f["encounters"] = [
		{"id": "enc_t_tutorial", "enemies": ["enm_kanalratte", "enm_kanalratte"], "weight": 0, "tutorial": true},
		{"id": "enc_t_patrol", "enemies": ["enm_kanalratte"], "weight": 0}]
	var wheel_table: Array = [
		{"weight": 35, "kind": "item", "id": "itm_bandage", "amount": 2},
		{"weight": 25, "kind": "credits", "id": "", "amount": 50},
		{"weight": 15, "kind": "box", "id": "box_bronze", "amount": 1},
		{"weight": 15, "kind": "nothing", "id": "", "amount": 1},
		{"weight": 10, "kind": "encounter", "id": "enc_t_patrol", "amount": 1}]
	f["layout"] = {
		"zones": [
			{"id": "zone_a", "name": "Bahnsteig", "palette": {"floor": "#3a3f4b", "wall": "#1f5f66",
				"accent": "#ff2e88", "light": "#ffd59e", "fog": "#1a1430", "ambient": "#2a2440"}},
			{"id": "zone_b", "name": "Kanal", "palette": {"floor": "#24302c", "wall": "#3b4a3f", "accent": "#7cc242",
				"light": "#b8f0c8", "fog": "#12302a", "ambient": "#1e3530"}}],
		"cells": [
			{"x": 3, "y": 7, "zone": "zone_a", "kind": "start", "doors": "N"},
			{"x": 3, "y": 6, "zone": "zone_a", "kind": "normal", "doors": "NESW"},
			{"x": 2, "y": 6, "zone": "zone_a", "kind": "safe", "doors": "E"},
			{"x": 3, "y": 5, "zone": "zone_a", "kind": "normal", "doors": "NSW"},
			{"x": 2, "y": 5, "zone": "zone_a", "kind": "stairs", "doors": "E"},
			{"x": 3, "y": 4, "zone": "zone_b", "kind": "normal", "doors": "S"},
			{"x": 4, "y": 6, "zone": "zone_b", "kind": "normal", "doors": "NW"},
			{"x": 4, "y": 5, "zone": "zone_b", "kind": "normal", "doors": "NS"},
			{"x": 4, "y": 4, "zone": "zone_b", "kind": "normal", "doors": "S"}],
		"gates": [{"cell": [3, 5], "dir": "N", "requires": "itm_key_master"},
			{"cell": [4, 5], "dir": "N", "requires": "event:fev_t_lever"}],
		"encounters_placed": [
			{"group_id": "f1_g0", "enc_id": "enc_t_tutorial", "cell": [3, 6], "offset": [0.0, -2.5], "state": "IDLE",
				"turn": false, "waypoints": []},
			{"group_id": "f1_g1", "enc_id": "enc_t_patrol", "cell": [3, 5], "offset": [0.0, 0.0], "state": "PATROL",
				"turn": true, "waypoints": []}],
		"chests": [
			{"id": "f1_c0", "cell": [4, 6], "offset": [-3.5, -3.5], "type": "wood", "contents": []},
			{"id": "f1_c1", "cell": [3, 4], "offset": [3.0, -3.0], "type": "metal",
				"contents": [{"kind": "credits", "id": "", "amount": 40}]},
			{"id": "f1_c2", "cell": [4, 4], "offset": [0.0, -3.0], "type": "locked",
				"contents": [{"kind": "item", "id": "itm_bandage", "amount": 2}]}],
		"events": [
			{"id": "fev_t_drone", "type": "photo_drone", "cell": [4, 6], "offset": [0.0, 0.0],
				"params": {"pose_hype": 15, "pose_followers": 20, "smash_credits": 30, "smash_hype": -5}},
			{"id": "fev_t_wheel", "type": "wheel", "cell": [4, 6], "offset": [3.5, -3.0],
				"params": {"cost": 20, "max_spins": 3, "table": wheel_table}},
			{"id": "fev_t_candidate", "type": "lost_candidate", "cell": [4, 6], "offset": [-3.0, 3.0],
				"params": {"tag": "heal", "reward_item": "itm_antidote", "followers": 40}},
			{"id": "fev_t_lever", "type": "lever", "cell": [4, 5], "offset": [3.0, 2.0],
				"params": {"success": lever_success, "gate": "4,5,N", "flood_pct": 15, "encounter": "enc_t_patrol"}},
			{"id": "fev_t_vending", "type": "broken_vending", "cell": [3, 4], "offset": [-3.0, -2.0],
				"params": {"base": 0.5, "per_lck": 0.02, "reward_item": "itm_bandage", "reward_amount": 2,
					"fail_pct": 10, "fail_hype": 4}}],
		"spawners": [{"zone": "zone_a", "pool": ["enc_t_patrol"], "interval_sec": 90}],
		"safe_rooms": [{"id": "sr_t_kiosk", "cell": [2, 6], "name": "Kiosk 24/7", "theme": "kiosk",
			"shop": ["itm_bandage"]}],
		"stairs": {"cell": [2, 5]},
	}
	return f


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


func _first_non_boss_encounter() -> String:
	for enc: EncounterDef in Game.floor_def().encounters:
		if not enc.boss:
			return enc.id
	return ""


static func _horizontal_speed(body: CharacterBody3D) -> float:
	return Vector2(body.velocity.x, body.velocity.z).length()


static func _first_glow_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		var sm: ShaderMaterial = (n as MeshInstance3D).material_override as ShaderMaterial
		if sm != null and sm.get_shader_parameter("energy") != null and sm.get_shader_parameter("pulse_speed") != null:
			return n as MeshInstance3D
	for c: Node in n.get_children():
		var m: MeshInstance3D = _first_glow_mesh(c)
		if m != null:
			return m
	return null


static func _first_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n as MeshInstance3D
	for c: Node in n.get_children():
		var m: MeshInstance3D = _first_mesh(c)
		if m != null:
			return m
	return null


## First neighbour of the start that is reachable through an open door.
static func _start_neighbor(layout: FloorLayout) -> Vector2i:
	var ns: Array[Vector2i] = layout.neighbors(layout.start)
	return ns[0] if not ns.is_empty() else layout.start


# --- building ---------------------------------------------------------------------------------------------------------

## M3 CR 3: touch pinch (Events.camera_zoom from TouchControls) zooms like the wheel, clamped to 5–9 m.
func test_camera_rig_pinch_zoom() -> void:
	var rig: Node3D = CameraRig.new()
	add_to_tree(rig)
	var arm: float = float(rig.get("arm_length"))
	Events.camera_zoom.emit(-1.5)
	assert_almost(float(rig.get("arm_length")), arm - 1.5, 0.0001, "fingers apart → closer")
	Events.camera_zoom.emit(50.0)
	assert_almost(float(rig.get("arm_length")), CameraRig.ZOOM_MAX, 0.0001, "clamped")
	rig.set("input_enabled", false)
	Events.camera_zoom.emit(-3.0)
	assert_almost(float(rig.get("arm_length")), CameraRig.ZOOM_MAX, 0.0001, "no zoom while input is disabled")


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
	var notes: int = Secrets.list(Game.floor_def()).filter(func(x: Dictionary) -> bool: return x["kind"] == "note").size()
	var expected_interactables: int = layout.chests.size() + layout.events.size() + 1 + layout.safe_rooms.size() \
		+ layout.gates.size() + notes
	assert_eq(scene.get_node("World/Interactables").get_child_count(), expected_interactables,
		"chests + events + stairs + safe doors + closed gates / Kulissenwände + Regie-Notizen (06 §2.7)")
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
	# an observable condition with a generous cap instead of a fixed frame count (headless frames are uncapped)
	await wait_until(func() -> bool: return Rules.flat_dist(p0, scene.get_player_position()) > 1.0, 600)
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


# --- encounters -------------------------------------------------------------------------------------------------------

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
		if nearest != "":
			assert_eq(_spy[0][1], layout.enemy_by_id(nearest).encounter_id, "the group's encounter")
		else:
			assert_eq(_spy[0][1], _first_non_boss_encounter(), "no group: first non-boss encounter of the floor")
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
	var first_enc: String = _first_non_boss_encounter()
	assert_len(_spy, 1)
	if _spy.size() == 1:
		assert_eq(_spy[0][0], "")
		assert_eq(_spy[0][1], first_enc)


func test_force_encounter_starts_battle_via_router() -> void:
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
	assert_false(Rules.in_arc(e, north, Vector3(1.5, 0, -0.2), Rules.STRIKE_RANGE, Rules.STRIKE_ARC_DEG),
		"outside 100°")
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


# --- stack protocol ---------------------------------------------------------------------------------------------------

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


# --- interactions -----------------------------------------------------------------------------------------------------

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
	assert_true(bool(it.call("is_dimmed")), "completed event is dimmed")
	var glow_mesh: MeshInstance3D = _first_glow_mesh(it.get_node("Prop"))
	assert_not_null(glow_mesh, "the drone has glow parts")
	if glow_mesh != null:
		var sm: ShaderMaterial = glow_mesh.material_override as ShaderMaterial
		assert_almost(float(sm.get_shader_parameter("energy")), FB.DIM_GLOW_ENERGY, 0.001, "glow off")
		assert_almost(float(sm.get_shader_parameter("pulse_speed")), 0.0, 0.001, "no pulse")
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
	await wait_until(func() -> bool: return gate.get_node_or_null("Blocker") == null, 600)
	assert_null(gate.get_node_or_null("Blocker"), "blocking body removed")


func test_gate_interactable_rules() -> void:
	var holder: Node3D = Node3D.new()
	add_to_tree(holder)
	var gate: GateInteractable = GateInteractable.new()
	holder.add_child(gate)
	gate.setup_gate({"cell": Vector2i(1, 3), "dir": RoomCell.DOOR_N, "requires": "itm_key_master", "key": "1,3,N"},
		{}, 1)
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


# --- actors -----------------------------------------------------------------------------------------------------------

func test_enemy_patrol_alert_chase_return() -> void:
	var scene: ExplorationScene = await _make_scene()
	scene.auto_start_battle = false
	var actor: EnemyActor = scene.get_enemy("f1_g1")
	assert_not_null(actor, "fixture patrol group f1_g1")
	if actor == null:
		return
	assert_true(actor.can_ambush() and not actor.is_asleep(), "mobile and awake")
	assert_eq(actor.state, &"PATROL")
	var states: Array[StringName] = []
	var home_dist: Array[float] = []
	var on_state: Callable = func(_gid: String, st: StringName) -> void:
		states.append(st)
		if st == &"PATROL" and states.has(&"RETURN"):
			home_dist.append(Rules.flat_dist(actor.global_position, actor.home))
	actor.state_changed.connect(on_state)
	Events.enemy_alerted.connect(_record)
	# Kai stands 6 m in front of the group (inside its sight cone, room centre side) → ALERT (0.6 s) → CHASE.
	actor.frozen = true
	await wait_frames(1)
	var center: Vector3 = scene.get_layout().cell_to_world(actor.spawn.cell)
	var to_c: Vector3 = Rules.flat_dir(actor.global_position, center)
	if to_c == Vector3.ZERO:
		to_c = Vector3.FORWARD
	actor.face(Rules.yaw_of(to_c))
	scene.get_player().teleport(actor.global_position + to_c * 6.0 + Vector3(0.0, 0.05, 0.0), Rules.yaw_of(-to_c))
	await wait_frames(1)
	actor.frozen = false
	var chased: bool = await wait_until(func() -> bool: return actor.state == &"CHASE", 3000)
	assert_true(chased, "PATROL → ALERT → CHASE")
	assert_false(_spy.is_empty(), "Events.enemy_alerted")
	assert_true(states.find(&"ALERT") >= 0 and states.find(&"ALERT") < states.find(&"CHASE"), "ALERT before CHASE")
	var d0: float = Rules.flat_dist(actor.global_position, scene.get_player_position())
	await wait_frames(4)
	var d1: float = Rules.flat_dist(actor.global_position, scene.get_player_position())
	assert_lt(d1, d0, "the chasing group closes in on Kai")
	# Kai hidden (grace) and gone → no sight for giveup_no_sight s → RETURN → back at the leash point → PATROL.
	scene.get_player().set_grace(120.0)
	scene.get_player().teleport(scene.get_layout().cell_to_world(scene.get_layout().start), 0.0)
	var back: bool = await wait_until(func() -> bool: return not home_dist.is_empty(), 8000)
	assert_true(back, "chase given up and the group walked home")
	assert_has(states, &"RETURN")
	if not home_dist.is_empty():
		assert_lt(home_dist[0], EnemyActor.HOME_EPS + 0.001, "ends at its leash point (home)")
	actor.state_changed.disconnect(on_state)
	Events.enemy_alerted.disconnect(_record)


func test_chasing_group_needs_the_sight_cone() -> void:
	var scene: ExplorationScene = await _make_scene()
	scene.auto_start_battle = false
	var actor: EnemyActor = scene.get_enemy("f1_g1")
	if actor == null:
		fail("fixture patrol group f1_g1 missing")
		return
	actor.frozen = true
	await wait_frames(1)
	var fwd: Vector3 = actor.flat_forward()
	# 3 m straight behind the group: outside the 110° cone, beyond hearing while Kai stands → no sight.
	scene.get_player().teleport(actor.global_position - fwd * 3.0 + Vector3(0.0, 0.05, 0.0), Rules.yaw_of(fwd))
	await wait_frames(2)
	assert_false(bool(actor.call("_sees", scene.get_player_position())), "behind the group: not seen")
	scene.get_player().teleport(actor.global_position + fwd * 3.0 + Vector3(0.0, 0.05, 0.0), Rules.yaw_of(-fwd))
	await wait_frames(2)
	assert_true(bool(actor.call("_sees", scene.get_player_position())), "in front: seen")


func test_companion_follows_trail() -> void:
	var scene: ExplorationScene = await _make_scene()
	var kai: Node3D = scene.get_player()
	var mop: Node3D = scene.get_companion()
	var start: Vector3 = kai.global_position
	Input.action_press(&"move_forward")
	await wait_until(func() -> bool: return Rules.flat_dist(start, kai.global_position) > 1.5, 600)
	Input.action_release(&"move_forward")
	# Mopsula catches up along the trail: settled = within 4 m and no longer moving
	var last: Array[Vector3] = [mop.global_position]
	var settled: Callable = func() -> bool:
		var ok: bool = Rules.flat_dist(kai.global_position, mop.global_position) <= 4.0 \
			and mop.global_position.distance_to(last[0]) < 0.01
		last[0] = mop.global_position
		return ok
	await wait_until(settled, 600)
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


# --- real data, speeds, dialogs ---------------------------------------------------------------------------------------

func test_real_floor_1_builds() -> void:
	if _saved_data == null:
		skip("no real data")
		return
	DB.data = _saved_data
	Game.new_game(0, "Kai", 4242)
	var scene: ExplorationScene = await _make_scene()
	var layout: FloorLayout = scene.get_layout()
	assert_not_null(layout, "real floor_1 layout")
	if layout == null:
		return
	assert_eq(layout.validate(), PackedStringArray())
	assert_eq(scene.get_node("World/Rooms").get_child_count(), layout.cells.size(), "one room per cell")
	assert_eq(scene.get_player_cell(), layout.start)
	assert_eq(scene.living_groups().size(), layout.enemies.size())


func test_player_speeds_ignore_stick_deflection() -> void:
	var scene: ExplorationScene = await _make_scene()
	scene.auto_start_battle = false
	var kai: PlayerBody = scene.get_player()
	# Touch: deflection 0.6 holds sneak → 2.5 m/s (GDD §2.1, TECH §10.3), never 0.6 × something.
	Input.action_press(&"sneak")
	Input.action_press(&"move_forward", 0.6)
	var ok: bool = await wait_until(func() -> bool: return _horizontal_speed(kai) >= PlayerBody.SNEAK_SPEED - 0.05,
		600)
	assert_true(ok, "sneak speed reached")
	await wait_frames(3)
	assert_almost(_horizontal_speed(kai), PlayerBody.SNEAK_SPEED, 0.05, "sneak at stick 0.6 = 2.5 m/s")
	Input.action_release(&"sneak")
	Input.action_release(&"move_forward")
	await wait_frames(2)
	Input.action_press(&"move_forward", 0.65)
	ok = await wait_until(func() -> bool: return _horizontal_speed(kai) >= PlayerBody.RUN_SPEED - 0.05, 600)
	assert_true(ok, "run speed reached")
	assert_almost(_horizontal_speed(kai), PlayerBody.RUN_SPEED, 0.05, "stick 0.65 = 5.5 m/s")
	Input.action_release(&"move_forward")


func test_choice_dialog_hit_area_focus_and_guard() -> void:
	var scene: ExplorationScene = await _make_scene()
	Events.floor_completed.connect(_record)
	scene.open_stairs_dialog()
	var dlg: Node = scene.active_dialog()
	assert_not_null(dlg)
	if dlg == null:
		Events.floor_completed.disconnect(_record)
		return
	await wait_frames(3)
	var buttons: Array[Button] = dlg.call("buttons")
	for i in buttons.size():
		assert_true(buttons[i].size.y >= UiTheme.TOUCH_HIT, "hit area >= 88 px (TECH §10.2)")
		if i > 0:
			var gap: float = buttons[i].position.y - (buttons[i - 1].position.y + buttons[i - 1].size.y)
			assert_true(gap >= 12.0, "12 px between hit areas")
	var focus: Control = dlg.get_viewport().gui_get_focus_owner()
	assert_not_null(focus, "default focus set at once (call_deferred)")
	if focus != null:
		assert_eq(str(focus.get_meta(&"choice_id", "")), "stay", "stairs: the safe option has the focus")
	# Mashing confirm right after opening does nothing (guard window) …
	assert_true(bool(dlg.call("is_guarded")))
	await _press_action(&"ui_accept")
	await wait_frames(3)
	assert_false(bool(dlg.call("is_closed")), "confirm inside the guard window is swallowed")
	# … and after it, confirm picks the focused safe option: the floor is not left.
	dlg.set("_opened_msec", Time.get_ticks_msec() - 5000)
	await _press_action(&"ui_accept")
	await wait_frames(3)
	Events.floor_completed.disconnect(_record)
	assert_true(not is_instance_valid(dlg) or bool(dlg.call("is_closed")), "confirm after the guard closes it")
	assert_eq(_spy.size(), 0, "the default confirm never descends")
	assert_false(scene.is_modal())


func _press_action(action: StringName) -> void:
	var down: InputEventAction = InputEventAction.new()
	down.action = action
	down.pressed = true
	Input.parse_input_event(down)
	await wait_frames(1)
	var up: InputEventAction = InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)


func test_disabled_options_are_not_focusable() -> void:
	var scene: ExplorationScene = await _make_scene()
	Game.state.inventory.counts = {}           # no heal item → "Heilitem geben" disabled
	var it: EventInteractable = scene.get_interactable("fev_t_candidate") as EventInteractable
	assert_not_null(it)
	if it == null:
		return
	scene.open_event_dialog(it)
	var dlg: Node = scene.active_dialog()
	await wait_frames(3)
	var buttons: Array[Button] = dlg.call("buttons")
	assert_eq(buttons.size(), 2)
	var give: Button = buttons[0]
	var leave: Button = buttons[1]
	assert_true(give.disabled)
	assert_eq(give.focus_mode, Control.FOCUS_NONE, "disabled options are not focusable")
	assert_eq(leave.get_node(leave.focus_neighbor_bottom), leave, "focus ring only over enabled options")
	assert_eq(dlg.get_viewport().gui_get_focus_owner(), leave, "default focus on 'Weitergehen'")
	dlg.call("cancel")


func test_wheel_copy() -> void:
	var scene: ExplorationScene = await _make_scene()
	var it: EventInteractable = scene.get_interactable("fev_t_wheel") as EventInteractable
	assert_not_null(it)
	if it == null:
		return
	assert_has(it.description(), "Noch 3 Drehungen.")
	Game.state.floor_run.event_uses["fev_t_wheel"] = 2
	assert_has(it.description(), "Noch 1 Drehung.")
	Game.state.inventory.credits = 5
	var spin: Dictionary = it.options()[0]
	assert_false(bool(spin["enabled"]))
	assert_has(str(spin["label"]), "zu wenig Credits", "a greyed-out option says what is missing")
	assert_eq(it.default_choice(), "ignore")


func test_event_reveal_waits_for_the_prop() -> void:
	var scene: ExplorationScene = await _make_scene()
	scene.auto_start_battle = false
	var it: EventInteractable = scene.get_interactable("fev_t_wheel") as EventInteractable
	assert_not_null(it)
	if it == null:
		return
	Events.toast_requested.connect(_record)
	scene.open_event_dialog(it)
	var dlg: Node = scene.active_dialog()
	dlg.call("choose", "spin")
	assert_true(scene.is_revealing(), "the wheel spins first")
	assert_true(scene.is_modal())
	assert_eq(_spy.size(), 0, "no result toast while the wheel spins")
	assert_false(Game.timer_running, "timer paused during the reveal")
	assert_false(scene.get_player().input_enabled, "Kai frozen during the reveal")
	scene.force_encounter("")
	assert_false(scene.is_encounter_pending(), "no forced encounter behind the reveal")
	var done: bool = await wait_until(func() -> bool: return not scene.is_revealing(), 6000)
	Events.toast_requested.disconnect(_record)
	assert_true(done, "reveal finished")
	assert_eq(_spy.size(), 1, "result toast after the spin")
	assert_true(Game.timer_running, "timer runs again")


func test_lever_reveal_waits_for_the_prop() -> void:
	# Flood path (lever success 0): the result toast and the follow-up fight both have to wait for the lever.
	var flood: GameData = fixture_game_data(0.0)
	assert_not_null(flood)
	if flood == null:
		return
	DB.data = flood                                     # after_each restores the real data
	Game.new_game(0, "Kai", 4242)
	var scene: ExplorationScene = await _make_scene()
	scene.auto_start_battle = false
	var it: EventInteractable = scene.get_interactable("fev_t_lever") as EventInteractable
	assert_not_null(it)
	if it == null:
		return
	var toasts: Array[String] = []
	var fights: Array[String] = []
	var gates: Array[Vector2i] = []
	var on_toast: Callable = func(text: String, _icon: StringName) -> void: toasts.append(text)
	var on_fight: Callable = func(_group_id: String, enc_id: String, _adv: int) -> void: fights.append(enc_id)
	var on_gate: Callable = func(cell: Vector2i, _dir: int) -> void: gates.append(cell)
	Events.toast_requested.connect(on_toast)
	Events.encounter_triggered.connect(on_fight)
	Events.gate_opened.connect(on_gate)
	scene.open_event_dialog(it)
	var t0: int = Time.get_ticks_msec()
	scene.active_dialog().call("choose", "pull")
	assert_true(scene.is_revealing(), "the lever moves first (art-kit or fallback lever)")
	assert_false(Game.timer_running, "timer paused during the reveal")
	await wait_frames(3)
	assert_true(toasts.is_empty() and fights.is_empty() and gates.is_empty(),
		"no toast, gate or flood fight while the lever moves")
	assert_false(scene.is_encounter_pending())
	var done: bool = await wait_until(func() -> bool: return not scene.is_revealing(), 6000)
	var elapsed_ms: int = int(float(Time.get_ticks_msec() - t0) * Engine.time_scale)   # game time (suite runs ×8)
	Events.toast_requested.disconnect(on_toast)
	Events.encounter_triggered.disconnect(on_fight)
	Events.gate_opened.disconnect(on_gate)
	assert_true(done, "reveal finished")
	assert_true(elapsed_ms >= int(EventInteractable.LEVER_SEC * 1000.0),
		"reveal lasts at least the lever pull (%d ms)" % elapsed_ms)
	assert_eq(toasts.size(), 1, "result toast after the pull")
	assert_eq(fights, ["enc_t_patrol"], "flood fight after the reveal")
	assert_true(gates.is_empty(), "the gate stays shut after a flood")


## M3 verify (§9.4): pausing during the event reveal (PauseMenu sets get_tree().paused) also pauses the reveal timer —
## no result toast, gate or follow-up fight under the open pause menu; it finishes after unpausing.
func test_event_reveal_pauses_with_the_tree() -> void:
	var scene: ExplorationScene = await _make_scene()
	scene.auto_start_battle = false
	var it: EventInteractable = scene.get_interactable("fev_t_wheel") as EventInteractable
	assert_not_null(it)
	if it == null:
		return
	Events.toast_requested.connect(_record)
	scene.open_event_dialog(it)
	scene.active_dialog().call("choose", "spin")
	assert_true(scene.is_revealing())
	tree.paused = true
	var t0: int = Time.get_ticks_msec()
	var reveal_ms: int = int((EventInteractable.WHEEL_SEC + 1.0) * 1000.0 / Engine.time_scale)
	while Time.get_ticks_msec() - t0 < reveal_ms:
		await wait_frames(1)
	var still: bool = scene.is_revealing()
	var toasts: int = _spy.size()
	tree.paused = false
	assert_true(still, "the reveal timer waits while the tree is paused")
	assert_eq(toasts, 0, "no result toast under the pause menu")
	var done: bool = await wait_until(func() -> bool: return not scene.is_revealing(), 6000)
	Events.toast_requested.disconnect(_record)
	assert_true(done, "reveal finishes after the pause")
	assert_eq(_spy.size(), 1, "result toast after unpausing")


func test_force_encounter_is_ignored_behind_a_dialog() -> void:
	var scene: ExplorationScene = await _make_scene()
	scene.auto_start_battle = false
	scene.open_stairs_dialog()
	Events.encounter_triggered.connect(_record)
	scene.force_encounter("")
	Events.encounter_triggered.disconnect(_record)
	assert_eq(_spy.size(), 0, "dialogs block (GDD §2.6)")
	scene.on_suspend()
	scene.on_resume({})
	assert_false(Game.timer_running, "resume with an open dialog keeps the timer paused")
	assert_false(scene.get_player().input_enabled, "… and Kai frozen")
	scene.active_dialog().call("cancel")
	await wait_frames(1)
	assert_true(Game.timer_running)
	assert_true(scene.get_player().input_enabled)


# --- visuals ----------------------------------------------------------------------------------------------------------

func test_room_visibility() -> void:
	var scene: ExplorationScene = await _make_scene()
	var rooms: Node = scene.get_node("World/Rooms")
	assert_true((rooms.get_node("Room_3_7") as Node3D).visible, "current room drawn")
	assert_true((rooms.get_node("Room_3_6") as Node3D).visible, "door-linked neighbour drawn")
	assert_false((rooms.get_node("Room_4_6") as Node3D).visible, "rooms beyond walls hidden")
	assert_false(scene.get_enemy("f1_g1").visible, "groups in hidden rooms hidden")
	assert_true(scene.get_enemy("f1_g0").visible)
	scene.get_player().teleport(scene.get_layout().cell_to_world(Vector2i(4, 6)) + Vector3(2.0, 0.05, 2.0), 0.0)
	await wait_frames(3)
	assert_true((rooms.get_node("Room_4_6") as Node3D).visible)
	assert_true((rooms.get_node("Room_4_5") as Node3D).visible)
	assert_false((rooms.get_node("Room_3_7") as Node3D).visible)
	assert_true((scene.get_interactable("fev_t_drone") as Node3D).visible)
	assert_true((scene.get_interactable("4,5,N") as Node3D).visible, "gates seen from both cells")
	assert_true(scene.get_enemy("f1_g0").visible, "the hub is door-linked to (4,6)")
	assert_false(scene.get_enemy("f1_g1").visible, "(3,5) is behind a wall")


func test_camera_clears_walls_and_looks_ahead() -> void:
	var scene: ExplorationScene = await _make_scene()
	var rig: Node3D = scene.get_camera_rig()
	var start: Vector3 = scene.get_layout().cell_to_world(scene.get_layout().start)
	# Kai 2 m in front of the solid south wall of the start room, looking north: the wall is behind him.
	scene.get_player().teleport(start + Vector3(0.0, 0.05, 5.5), 0.0)
	rig.call("snap", 0.0)
	await wait_frames(20)
	assert_gt(float(rig.call("current_arm")), 6.5, "arm not collapsed by the wall behind Kai")
	assert_lt(float(rig.call("effective_pitch")), deg_to_rad(-45.0), "pitch raised instead")
	var cam_z: float = scene.get_camera_rig().camera().global_position.z
	assert_lt(cam_z, start.z + 7.5, "the camera stays inside the room (in front of the wall)")
	assert_almost(rad_to_deg(float(rig.get("pitch"))), -38.0, 0.01, "the player's pitch is untouched")
	# Look-ahead: the pivot sits in front of Kai along the camera's forward → Kai in the lower part of the frame.
	var cam: Camera3D = scene.get_camera_rig().camera()
	var on_screen: Vector2 = cam.unproject_position(scene.get_player_position() + Vector3(0.0, 1.0, 0.0))
	var vp: Vector2 = cam.get_viewport().get_visible_rect().size
	assert_gt(on_screen.y, vp.y * 0.55, "Kai below the screen centre")
	# Kai fades out when the camera comes very close to his head.
	var kai: PlayerBody = scene.get_player()
	cam.global_position = kai.global_position + Vector3(0.0, 1.7, 0.3)
	rig.call("_update_fade")
	var mesh: MeshInstance3D = _first_mesh(kai.rig)
	assert_not_null(mesh)
	if mesh != null:
		assert_gt(mesh.transparency, 0.9, "camera inside 0.6 m → Kai's rig is faded out")


func test_sleeping_group_and_pips() -> void:
	var scene: ExplorationScene = await _make_scene()
	var sleeper: EnemyActor = scene.get_enemy("f1_g0")
	var patrol: EnemyActor = scene.get_enemy("f1_g1")
	assert_true(sleeper.is_asleep())
	assert_true((sleeper.get_node("SleepZz") as Node3D).visible, "\"Z z\" over sleeping groups")
	assert_false((patrol.get_node("SleepZz") as Node3D).visible)
	var pips: MeshInstance3D = sleeper.get_node("GroupPips") as MeshInstance3D
	assert_not_null(pips)
	if pips != null:
		assert_eq(int((pips.material_override as ShaderMaterial).get_shader_parameter("count")), 2, "2 rats")
	sleeper.frozen = true
	sleeper.call("_set_state", &"ALERT")
	assert_false((sleeper.get_node("SleepZz") as Node3D).visible, "hidden once alerted")


func test_strike_arc_and_hit_flash() -> void:
	var scene: ExplorationScene = await _make_scene()
	scene.auto_start_battle = false
	var kai: PlayerBody = scene.get_player()
	var arc: Node3D = kai.get_node("StrikeArc") as Node3D
	assert_not_null(arc)
	scene.perform_action()
	var shown: bool = await wait_until(func() -> bool: return arc.visible, 300)
	assert_true(shown, "the swing flashes a gold arc")
	var gone: bool = await wait_until(func() -> bool: return not arc.visible, 300)
	assert_true(gone, "only briefly")
	var rig: Node3D = scene.get_enemy("f1_g0").rig
	FB.flash_rig(rig, 10.0)
	assert_true(_is_flashing(rig), "hit flash on the struck group")


## CharacterRig (M4) flashes via the instance uniform flash_amount; fallback figures via a white material_overlay.
static func _is_flashing(n: Node) -> bool:
	if n is MeshInstance3D:
		var mi: MeshInstance3D = n as MeshInstance3D
		var amount: Variant = mi.get_instance_shader_parameter(&"flash_amount")
		if mi.material_overlay != null or (amount != null and float(amount) > 0.0):
			return true
	for c: Node in n.get_children():
		if _is_flashing(c):
			return true
	return false


func test_focus_highlight_and_marker() -> void:
	var scene: ExplorationScene = await _make_scene()
	var it: Node3D = scene.get_interactable("f1_c0") as Node3D
	var spot: Vector3 = it.global_position + Rules.flat_forward(it.global_transform.basis) * 1.1
	scene.get_player().teleport(spot, Rules.yaw_of(Rules.flat_dir(spot, it.global_position)))
	await wait_frames(4)
	assert_eq(scene.focused_interactable(), it)
	var marker: Node3D = scene.get_node_or_null("World/FocusMarker") as Node3D
	assert_not_null(marker, "focus marker")
	if marker != null:
		assert_true(marker.visible)
		assert_lt(Rules.flat_dist(marker.global_position, it.global_position), 0.01, "marker above the object")
		assert_gt(marker.global_position.y, it.global_position.y + 0.6)
	var mesh: MeshInstance3D = _first_mesh(it.get_node("Prop"))
	assert_eq(mesh.material_overlay, FB.highlight_material(), "cyan outline on the focused prop")
	scene.get_player().teleport(scene.get_layout().cell_to_world(scene.get_layout().start), 0.0)
	await wait_frames(4)
	assert_null(mesh.material_overlay, "highlight removed on focus loss")
	if marker != null:
		assert_false(marker.visible)


# --- encounters vs. Router transitions and modal input (review scenes-flow-1/2/3) -------------------------------------

## Kai 1.5 m behind the first regular group (frozen), facing it; null when the floor has none.
func _behind_first_group(scene: ExplorationScene) -> EnemyActor:
	for gid: String in scene.living_groups():
		var a: EnemyActor = scene.get_enemy(gid)
		if a.is_boss():
			continue
		a.frozen = true
		var fwd: Vector3 = a.flat_forward()
		scene.get_player().teleport(a.global_position - fwd * 1.5, Rules.yaw_of(fwd))
		return a
	return null


func _hud_of(scene: ExplorationScene) -> ExplorationHud:
	for c: Node in scene.get_children():
		if c is ExplorationHud:
			return c as ExplorationHud
	return null


## Delivers a press + release of `action` synchronously (Viewport.push_input, no frame in between).
func _push_action(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var ev: InputEventAction = InputEventAction.new()
		ev.action = action
		ev.pressed = pressed
		tree.root.push_input(ev)


## scenes-flow-1: the run clock stops with the field-strike hit. A countdown at its last tick can no longer expire
## inside the hitstop (that queued the game over and then pushed the battle on top of the Sendeschluss screen); the
## pause / map keys wait for the battle as well.
func test_strike_hit_stops_the_run_clock_during_the_hitstop() -> void:
	var scene: ExplorationScene = await _make_scene()
	scene.auto_start_battle = false
	scene.hitstop_sec = 30.0                    # stays in the hitstop for the whole test
	var target: EnemyActor = _behind_first_group(scene)
	if target == null:
		skip("floor has no regular group")
		return
	await wait_frames(2)
	Game.state.floor_run.timer_started = true
	assert_true(Game.is_timer_ticking(), "precondition: the countdown runs while exploring")
	scene.perform_action()
	var pending: bool = await wait_until(func() -> bool: return scene.is_encounter_pending(), 120)
	assert_true(pending, "the swing hit the group (hitstop running)")
	assert_false(Game.timer_running, "the hit stops the run clock at once")
	assert_false(Game.is_timer_ticking())
	var hud: ExplorationHud = _hud_of(scene)
	if hud != null:
		assert_null(hud.open_pause_menu(), "no pause menu while the battle is about to start")
	Game.state.floor_run.time_left_ticks = 1
	var t0: int = Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - t0) * Engine.time_scale < 500.0:   # 0.5 s game time ≫ 1 tick
		await wait_frames(1)
	assert_eq(Game.state.floor_run.time_left_ticks, 1, "no tick inside the hitstop")
	assert_eq(Router.current, scene, "no game over queued under the pending battle")
	assert_false(Router.busy)


## scenes-flow-1 (safety net): a hitstop that ends while a goto is running (game over, "Zum Titel") starts no battle —
## nothing is pushed on top of the next screen, no encounter is emitted.
func test_hitstop_ending_during_a_goto_starts_no_battle() -> void:
	var scene: ExplorationScene = await _make_scene()
	scene.hitstop_sec = 30.0                    # the real hitstop never ends inside this test
	var target: EnemyActor = _behind_first_group(scene)
	if target == null:
		skip("floor has no regular group")
		return
	await wait_frames(2)
	scene.perform_action()
	var pending: bool = await wait_until(func() -> bool: return scene.is_encounter_pending(), 120)
	assert_true(pending, "the swing hit the group")
	Events.encounter_triggered.connect(_record)
	Router.goto(ROUTER_FIXTURE, {}, Router.Transition.FADE)       # like Router.game_over(&"timer")
	assert_true(Router.busy, "goto queued")
	scene.call("_after_hitstop", target.group_id(), target.encounter_id(), Rules.PREEMPTIVE)   # hitstop ends mid-fade
	var done: bool = await wait_until(func() -> bool: return not Router.busy, MAX_FRAMES)
	await wait_frames(10)
	Events.encounter_triggered.disconnect(_record)
	assert_true(done, "goto finished")
	assert_eq(_spy.size(), 0, "no encounter while the screen is being replaced")
	var cur: Node = Router.current
	assert_true(cur != null and cur.scene_file_path == ROUTER_FIXTURE, "the goto's screen is on top")
	assert_eq(Router.stack_size(), 1, "no battle pushed on top of it")


## scenes-flow-1: contacts (and force_encounter) never start a battle while a Router transition runs — no side effects
## (pending flag, run clock); a contact simply tries again the next frame once the screen is settled.
func test_no_encounter_while_the_router_is_busy() -> void:
	var scene: ExplorationScene = await _make_scene()
	scene.auto_start_battle = false
	Events.encounter_triggered.connect(_record)
	Router.busy = true                          # a transition of another screen op (restored below)
	scene.force_encounter("")
	var pending_busy: bool = scene.is_encounter_pending()
	var timer_busy: bool = Game.timer_running
	Router.busy = false
	scene.force_encounter("")
	Events.encounter_triggered.disconnect(_record)
	assert_false(pending_busy, "no encounter during a transition")
	assert_true(timer_busy, "and the run clock untouched")
	assert_len(_spy, 1, "settled: the encounter starts")


## scenes-flow-2: `action` during the fade back in (results / safe-room menu skipped with Enter) neither reaches Kai nor
## strikes / interacts; once the transition is over it works again.
func test_action_is_ignored_while_the_router_fades_back_in() -> void:
	var scene: ExplorationScene = await _make_scene()
	scene.auto_start_battle = false
	await wait_frames(2)
	assert_null(scene.focused_interactable(), "precondition: nothing to interact with at the start")
	var kai: PlayerBody = scene.get_player()
	var requested: Array[int] = [0]
	var cb: Callable = func() -> void: requested[0] += 1
	kai.action_requested.connect(cb)
	Engine.time_scale = 1.0                     # a 0.25 s fade-in window at real speed
	Router.push(ROUTER_FIXTURE, {}, Router.Transition.NONE)
	var covered: bool = await wait_until(func() -> bool: return not Router.busy and not scene.is_inside_tree(),
		MAX_FRAMES)
	assert_true(covered, "a screen was pushed over the exploration")
	Router.pop({}, Router.Transition.FADE)
	var fading_in: bool = await wait_until(func() -> bool: return scene.is_inside_tree() and Router.busy, MAX_FRAMES)
	assert_true(fading_in, "back in the tree while the fade-in still runs")
	_push_action(&"action")
	scene.perform_action()
	assert_eq(requested[0], 0, "Kai ignores `action` during the transition")
	assert_lt(float(kai.get("_strike_t")), 0.0, "no field strike during the transition")
	var settled: bool = await wait_until(func() -> bool: return not Router.busy, MAX_FRAMES)
	assert_true(settled, "fade-in over")
	_push_action(&"action")
	kai.action_requested.disconnect(cb)
	assert_eq(requested[0], 1, "afterwards `action` reaches Kai again")
	assert_true(float(kai.get("_strike_t")) >= 0.0, "… and swings")


## scenes-flow-3: `map` / pause behind an open choice dialog do nothing — the dialog keeps the focus (a BigMap over it
## left it without one after closing).
func test_map_and_pause_are_blocked_while_a_choice_dialog_is_open() -> void:
	var scene: ExplorationScene = await _make_scene()
	var hud: ExplorationHud = _hud_of(scene)
	assert_not_null(hud, "exploration HUD")
	if hud == null:
		return
	scene.open_stairs_dialog()
	var dlg: Node = scene.active_dialog()
	var focused: bool = await wait_until(func() -> bool:
		var f0: Control = tree.root.gui_get_focus_owner()
		return f0 != null and dlg.is_ancestor_of(f0), 60)
	assert_true(focused, "the dialog owns the focus")
	_push_action(&"map")
	await wait_frames(2)
	assert_false(hud.is_modal_open(), "no big map over the dialog")
	assert_false(tree.paused, "tree not paused")
	assert_null(hud.open_big_map(), "open_big_map refuses as well")
	assert_null(hud.open_pause_menu(), "open_pause_menu refuses as well")
	var f: Control = tree.root.gui_get_focus_owner()
	assert_true(f != null and dlg.is_ancestor_of(f), "the focus stays on the dialog")
	dlg.call("cancel")
	await wait_frames(2)
	var bm: Node = hud.open_big_map()
	assert_not_null(bm, "without the dialog the map opens")
	if bm != null:
		bm.call("close")
	await wait_frames(2)
	tree.paused = false
