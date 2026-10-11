extends TestCase
## Base of the R2 scene tests (test_r2_combat_world, test_r2_boss_intro): the real floor 1 (seed 4242) in a real-time
## run, the ExplorationScene in the tree, the world fixture stream as the sim (Game.rt_sim_factory) and the director in
## test mode (no results panel, no HUD, ticks only through advance()). Layout of seed 4242 (tests/fixtures/rt_world):
## start (1,7); tutorial f1_g0 asleep in (1,6); (1,5) NESW; f1_g1 enc_f1_a2 (3 units) in (1,4) N E S; f1_g2 enc_f1_a3
## (2) in (2,4); f1_g3 enc_f1_a4 (3) in (1,3); stairs (1,0); floor boss f1_fb in (0,0) (door E); quarter boss f1_qb in
## (5,0) (door W). Private test helper (no class_name).

const WorldStream := preload("res://tests/fixtures/rt_world/world_stream.gd")
const Rules := preload("res://scenes/exploration/encounter_rules.gd")
const SCENE: String = "res://scenes/exploration/exploration.tscn"
const ROUTER_FIXTURE: String = "res://tests/fixtures/router/router_screen.tscn"
const SEED: int = 4242

var scene: ExplorationScene = null
var director: CombatDirector = null
var triggered: Array[Array] = []           # Events.encounter_triggered (group, encounter, advantage)

var _settings_mode: StringName = &"ctb"
var _saved_data: GameData = null


func before_each() -> void:
	triggered.clear()
	scene = null
	director = null
	_saved_data = null
	_settings_mode = Game.settings.combat_mode
	_new_rt_game()
	Events.encounter_triggered.connect(_on_triggered)


## A new real-time campaign game (07 §12.1: the boot argument path — HP scale, run log header).
func _new_rt_game() -> void:
	Game.combat_mode_override = &"realtime"
	Game.new_game(0, "Kai", SEED)
	Game.combat_mode_override = &""


func after_each() -> void:
	if Events.encounter_triggered.is_connected(_on_triggered):
		Events.encounter_triggered.disconnect(_on_triggered)
	if Game.combat != null:
		Game.end_combat()
	Game.rt_sim_factory = Callable()
	Game.settings.combat_mode = _settings_mode
	Game.combat_mode_override = &""
	if _saved_data != null:
		DB.data = _saved_data
		_saved_data = null
	for a: StringName in [&"move_forward", &"move_back", &"move_left", &"move_right", &"sneak", &"action"]:
		Input.action_release(a)
	var cur0: Node = Router.current
	if Router.stack_size() > 1 or Router.busy or (cur0 != null and not cur0 is ExplorationScene):
		Router.goto(ROUTER_FIXTURE, {}, Router.Transition.NONE)
		await wait_until(func() -> bool: return not Router.busy, 240)
		var cur: Node = Router.current
		if cur != null and is_instance_valid(cur) and cur.scene_file_path == ROUTER_FIXTURE:
			if cur.get_parent() != null:
				cur.get_parent().remove_child(cur)
			cur.free()
	Router.adopt(null)
	Game.timer_running = false
	Sfx.music(&"", 0.0)
	var sfx: Node = tree.root.get_node_or_null("Sfx")
	if sfx != null:
		for c: Node in sfx.get_children():
			if c is AudioStreamPlayer:
				(c as AudioStreamPlayer).stop()
				(c as AudioStreamPlayer).stream = null


func _on_triggered(group_id: String, encounter_id: String, advantage: int) -> void:
	triggered.append([group_id, encounter_id, advantage])


## The exploration of floor 1 with `hero` leading; the world fixture plays `plan` (WorldStream.PLANS).
func make_world(plan: String = "win", length: int = 300, hero: String = "kai") -> ExplorationScene:
	if hero != Game.hero():
		Game.state.hero = hero
	var packed: PackedScene = load(SCENE) as PackedScene
	scene = packed.instantiate() as ExplorationScene
	scene.setup({})
	add_to_tree(scene)
	await wait_until(func() -> bool: return bool(scene.get("_built")) and not scene.is_modal(), 300)
	await wait_frames(2)
	scene.hitstop_sec = 0.0
	director = scene.get_director()
	director.present_results = false
	director.use_hud = false
	director.auto_tick = false
	Game.rt_sim_factory = WorldStream.factory(scene, plan, length)
	return scene


## The exploration of the RtKit fixture floor (tests/fixtures/rt_min: the rt_min tables WITH rt blocks; start (3,7),
## (3,6) NORMAL doors N E S W with the sleeping tutorial group f1_g0, (4,6), stairs (3,5)) and the REAL sim (R1b-I1):
## no world fixture — Game builds the setup with BattleBridge.make_rt_setup_rules.
func make_kit_world(hero: String = "kai") -> ExplorationScene:
	_saved_data = DB.data
	DB.data = RtKit.data()
	_new_rt_game()
	await make_world("win", 300, hero)
	Game.rt_sim_factory = Callable()
	return scene


## Waits `sec` seconds of game time (process frames; real physics runs meanwhile).
func seconds(sec: float) -> void:
	var t: float = 0.0
	while t < sec:
		await tree.process_frame
		t += tree.root.get_process_delta_time()


## Teleports the controlled figure to room `cell` + `offset` (m) facing `yaw`; the room logic follows at once.
func place_player(cell: Vector2i, offset: Vector3, yaw: float = 0.0) -> void:
	var p: Vector3 = scene.get_layout().cell_to_world(cell) + offset
	scene.get_player().teleport(Vector3(p.x, 0.05, p.z), yaw)
	scene.get_camera_rig().call("snap", yaw)
	scene.get_companion().call("snap_behind")
	scene.call("_update_room", true)


## The lead of `group_id` to room `cell` + `offset` (m), facing `yaw`, held still (frozen) unless `free_ai`.
func place_lead(group_id: String, cell: Vector2i, offset: Vector3, yaw: float = 0.0, free_ai: bool = false) -> Node3D:
	var a: Node3D = scene.get_enemy(group_id)
	var p: Vector3 = scene.get_layout().cell_to_world(cell) + offset
	a.global_position = Vector3(p.x, a.global_position.y, p.z)
	a.call("face", yaw)
	a.set("frozen", not free_ai)
	scene.call("_update_actor_visibility")
	return a


## Yaw that faces from `from` to `to` (XZ).
static func yaw_to(from: Vector3, to: Vector3) -> float:
	var d: Vector3 = to - from
	return atan2(-d.x, -d.z)


## The recorded encounter commands of this run (the "c" of every RunLog entry with t == "encounter").
static func encounters() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row: Dictionary in Game.run_log.cmds():
		var cmd: Dictionary = row["c"]
		if str(cmd.get("t", "")) == "encounter":
			out.append(cmd)
	return out


## Steps the running combat until `cond` holds (max `limit` ticks); true when it held.
func advance_until(cond: Callable, limit: int = 3000) -> bool:
	for i in limit:
		if bool(cond.call()):
			return true
		if not director.is_running():
			return bool(cond.call())
		director.advance(1)
	return bool(cond.call())


## World position of room-local cm (x, z) in the set of the running combat.
func world_of(x: int, z: int) -> Vector3:
	var o: Vector3 = director.ctx.get("origin", Vector3.ZERO)
	return o + Vector3(x / 100.0, 0.0, z / 100.0)
