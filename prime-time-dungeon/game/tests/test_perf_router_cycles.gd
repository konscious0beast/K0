extends TestCase
## Performance / robustness (02_TECH §12.1, §12.5): Router transitions free their screens — N cycles of exploration
## (rebuilt by goto) → battle (auto, Autoplay pacing) → safe room → back, with the real screens; the node / resource /
## object minima must not grow between an early and the last window (perf_runner.leak_growth) and no orphan nodes
## remain. Also: the Sfx exit drain, the floor build budget, and the physics / light-layer setup of the floor.

const PerfRunner := preload("res://tests/perf/perf_runner.gd")
const FloorBuilderScript := preload("res://scenes/exploration/floor_builder.gd")
const CYCLES: int = 8
const WARMUP: int = 2
const WINDOW: int = 3
const OBJECT_SLACK: int = 64           # tweens / function states / timers alive at the snapshot frame
const LEAK_ENCOUNTER: String = "enc_f1_a1_tutorial"
const FLOOR_BUILD_MS_MAX: float = 1500.0   # §12.1 mobile budget as generous CI guard (PC 500 ms: tools/perf.sh)

var _autoplay: bool = false
var _fast_text: bool = false
var _auto_battle: bool = false


func before_each() -> void:
	_autoplay = Game.autoplay
	_fast_text = Game.fast_text
	_auto_battle = Game.auto_battle
	Engine.time_scale = 8.0
	Save.read_only = true


func after_each() -> void:
	Engine.time_scale = 1.0
	Game.autoplay = _autoplay
	Game.fast_text = _fast_text
	Game.auto_battle = _auto_battle
	Save.read_only = false
	await wait_until(func() -> bool: return not Router.busy, 600)
	var cur: Node = Router.current
	if cur != null and is_instance_valid(cur):
		if cur.get_parent() != null:
			cur.get_parent().remove_child(cur)
		cur.free()
	Router.adopt(null)
	Game.timer_running = false
	Game.in_battle = false


func _wait_screen(check: Callable, max_frames: int) -> bool:
	return await wait_until(func() -> bool:
		var c: Node = Router.current
		return c != null and not Router.busy and bool(check.call(c)), max_frames)


func test_router_cycles_do_not_leak() -> void:
	Game.new_game(0, "Kai", 4242)
	Game.autoplay = true                  # BattleScene speed 4, results continue after 1 s (§11.4)
	Game.fast_text = true
	Game.auto_battle = true
	var rooms: Array = Game.floor_def().layout.get("safe_rooms", [])
	var sr_id: String = str((rooms[0] as Dictionary).get("id", "")) if not rooms.is_empty() else ""
	var snaps: Array[Dictionary] = []
	for cycle in CYCLES:
		Game.state.floor_run.spawner_ticks.clear()   # same floor every cycle: a stray is game state, not a leak
		Router.goto(Router.SCENE_EXPLORATION, {"spawn": &"start"}, Router.Transition.NONE)
		if not await _wait_screen(func(c: Node) -> bool: return c is ExplorationScene, 600):
			return
		Progression.full_heal(Game.state, DB.data)
		Router.start_battle(Game.make_battle_setup(LEAK_ENCOUNTER, 0, ""))
		if not await _wait_screen(func(c: Node) -> bool: return c is BattleScene, 600):
			return
		if not await _wait_screen(func(c: Node) -> bool: return c is ExplorationScene, 3000):
			return
		if sr_id != "":
			Router.enter_safe_room(sr_id)
			if not await _wait_screen(func(c: Node) -> bool: return c is SafeRoomScene, 600):
				return
			Router.exit_safe_room()
			if not await _wait_screen(func(c: Node) -> bool: return c is ExplorationScene, 600):
				return
		await wait_frames(4)
		snaps.append({"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
			"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
			"resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
			"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
			"ram": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0})
	var growth: PackedStringArray = PerfRunner.leak_growth(snaps, WARMUP, WINDOW, OBJECT_SLACK)
	assert_eq(growth, PackedStringArray(), "no growth over %d Router cycles: %s" % [CYCLES,
		", ".join(snaps.map(func(d: Dictionary) -> String: return "%d/%d" % [int(d["nodes"]), int(d["objects"])]))])
	assert_eq(Router.stack_size(), 1, "only the exploration screen is left on the stack")


func test_leak_verdict_detects_growth() -> void:
	var flat: Array[Dictionary] = []
	var leaking: Array[Dictionary] = []
	for i in 8:
		flat.append({"objects": 1000 + (i % 3) * 20, "nodes": 500 + (i % 2) * 6, "resources": 50, "orphans": 0,
			"ram": 100.0})
		leaking.append({"objects": 1000 + i * 40, "nodes": 500 + i, "resources": 50, "orphans": 0, "ram": 100.0})
	assert_eq(PerfRunner.leak_growth(flat, 2, 3, 64), PackedStringArray(), "transient noise is no leak")
	var out: PackedStringArray = PerfRunner.leak_growth(leaking, 2, 3, 64)
	assert_true(out.size() >= 1 and out[0].begins_with("nodes"), "one node per cycle is reported: %s" % [out])
	assert_eq(PerfRunner.leak_growth(flat.slice(0, 4), 2, 3, 64).size(), 1, "too few cycles is a failure, not OK")


func test_sfx_stop_all_releases_every_player() -> void:
	Sfx.play(&"coin")
	Sfx.play_ui(&"ui_confirm")
	Sfx.music(&"explore", 0.0)
	await wait_frames(2)
	assert_true(Sfx.stop_all(), "something was playing")
	assert_eq(Sfx.current_music(), &"", "music id cleared")
	for c: Node in Sfx.get_children():
		if c is AudioStreamPlayer:
			assert_false((c as AudioStreamPlayer).has_stream_playback(), "%s released its playback" % c.name)
	assert_false(Sfx.stop_all(), "nothing left to stop")


func test_floor_build_time_and_physics_layout() -> void:
	Game.new_game(0, "Kai", 4242)
	var t0: int = Time.get_ticks_usec()
	var scene: ExplorationScene = (load(Router.SCENE_EXPLORATION) as PackedScene).instantiate() as ExplorationScene
	scene.setup({"spawn": &"start"})
	add_to_tree(scene)
	var ms: float = (Time.get_ticks_usec() - t0) / 1000.0
	assert_time_budget(ms, FLOOR_BUILD_MS_MAX, "floor 1 build time")
	# §12.1 Physik: one static body for all room boxes + lintels, one for the permanent prop blockers, gates own.
	var statics: Array[String] = []
	var kinematic: int = 0
	var stack: Array[Node] = [scene]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c: Node in n.get_children():
			stack.append(c)
		if n is StaticBody3D:
			statics.append(str(n.name))
		elif n is CharacterBody3D:
			kinematic += 1
	assert_has(statics, "FloorCollision")
	assert_has(statics, "PropBlockers")
	assert_eq(statics.count("Collision"), 0, "no per-room / per-prop bodies left: %s" % [statics])
	assert_lt(statics.size() + kinematic, 41, "≤ 40 physics bodies (%d static, %d kinematic)" % [statics.size(),
		kinematic])
	# Room checkerboard: room meshes on the parity layer, room lights skip the other parity (lights per mesh).
	var layout: FloorLayout = scene.get_layout()
	for c: Vector2i in layout.sorted_cells():
		var room: Node3D = scene.find_child("Room_%d_%d" % [c.x, c.y], true, false) as Node3D
		if room == null:
			fail("room %s missing" % c)
			continue
		var own: int = FloorBuilderScript.room_layer(c)
		var light: Light3D = room.get_node_or_null("Light") as Light3D
		if light != null:
			var other: int = FloorBuilderScript.ROOM_LAYER_ODD if own == FloorBuilderScript.ROOM_LAYER_EVEN \
				else FloorBuilderScript.ROOM_LAYER_EVEN
			assert_eq(light.light_cull_mask & other, 0, "room %s light skips the neighbour parity" % c)
			assert_ne(light.light_cull_mask & 1, 0, "room %s light still lights actors (layer 1)" % c)
		var geo: GeometryInstance3D = room.get_node_or_null("Geometry") as GeometryInstance3D
		if geo != null:
			assert_eq(geo.layers, own, "room %s geometry on its parity layer" % c)
		for n2: Vector2i in layout.linked(c):
			assert_ne(FloorBuilderScript.room_layer(n2), own, "linked rooms %s/%s differ in parity" % [c, n2])


func test_low_quality_lights_only_the_current_room() -> void:
	# §3.4 / §12.1: quality low allows ≤ 2 active omni lights → only the room Kai is in keeps its light (instantly on
	# build, faded on room changes); quality high keeps every shown room lit.
	var old_quality: StringName = Game.settings.quality
	Game.settings.quality = &"low"
	Game.new_game(0, "Kai", 4242)
	var scene: ExplorationScene = (load(Router.SCENE_EXPLORATION) as PackedScene).instantiate() as ExplorationScene
	scene.setup({"spawn": &"start"})
	add_to_tree(scene)
	Game.settings.quality = old_quality
	await wait_frames(2)
	var layout: FloorLayout = scene.get_layout()
	var lit: Array[Vector2i] = _lit_rooms(scene, layout)
	assert_eq(lit, [scene.get_player_cell()] as Array[Vector2i], "only the current room is lit on low")
	var next: Vector2i = layout.linked(scene.get_player_cell())[0]
	scene.get_player().teleport(layout.cell_to_world(next) + Vector3(0.0, 0.05, 0.0), 0.0)
	await wait_until(func() -> bool: return scene.get_player_cell() == next, 60)
	var want: Array[Vector2i] = [next]
	# the 0.4 s light fade ends whenever the frames do: wait for the observable state, not a frame count
	await wait_until(func() -> bool: return _lit_rooms(scene, layout) == want, 600)
	assert_eq(_lit_rooms(scene, layout), want, "the light follows Kai into the next room")


func _lit_rooms(scene: Node, layout: FloorLayout) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c: Vector2i in layout.sorted_cells():
		var room: Node3D = scene.find_child("Room_%d_%d" % [c.x, c.y], true, false) as Node3D
		var light: OmniLight3D = room.get_node_or_null("Light") as OmniLight3D if room != null else null
		if room != null and room.visible and light != null and light.visible and light.light_energy > 0.01:
			out.append(c)
	return out
