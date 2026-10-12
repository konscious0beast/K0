extends RefCounted
## R2 capture recipes (07 §12.9 Nr. 11; `check.sh --shot res://scenes/exploration/exploration.tscn <png> 30 1280x720
## --recipe=rt_world_<name>`): real-time combats in the world played by the world fixture (world_stream.gd through
## Game.rt_sim_factory: the real data of floor 1 has no rt blocks before R4). Private test helper (no class_name);
## tests/capture_recipes.gd forwards rt_world_regular | _two_groups | _boss | _boss_intro | _flee to run(). `rec` is
## the CaptureRecipes runner (frames, seconds, freeze, until, _explore_ready).

const WorldStream := preload("res://tests/fixtures/rt_world/world_stream.gd")

var rec: Node = null


func run(which: String, scene: Node) -> bool:
	if not await rec.call("_explore_ready", scene):
		return false
	scene.set("auto_start_battle", true)            # _explore_ready turns battles off for the exploration stills
	Game.settings.combat_hints = false              # R3's first-time cards would hold the fixture's ticks (07 §2.13)
	match which:
		"regular":
			return await _regular(scene)
		"two_groups":
			return await _two_groups(scene)
		"boss":
			return await _boss(scene)
		"boss_intro":
			return await _boss(scene, true)
		"flee":
			return await _flee(scene)
	push_warning("[CaptureRt] unknown recipe rt_%s" % which)
	return false


## A regular fight in room (1, 3): Kai pulls the pigeon group from 3 m, the enemies walked in, a circle telegraph on
## Kai and a cone on Graf Mopsula fill up (world fixture "win" at tick 70).
func _regular(scene: Node) -> bool:
	if not await _start(scene, "f1_g3", "win", 3.0, Rules.PREEMPTIVE):
		return false
	await _banner_done(scene)
	_advance(scene, 70)
	await rec.call("frames", 6)
	rec.call("freeze")
	return true


## Two groups in room (1, 3): the platform group of (1, 4) followed Kai into the pigeons' room (3 + 3 units, 07 §2.3).
func _two_groups(scene: Node) -> bool:
	var second: Node3D = scene.call("get_enemy", "f1_g1") as Node3D
	var layout: FloorLayout = scene.call("get_layout")
	if second == null:
		return false
	second.global_position = layout.cell_to_world(Vector2i(1, 3)) + Vector3(2.6, 0.05, 1.2)
	if not await _start(scene, "f1_g3", "win", 3.0, Rules.NORMAL):
		return false
	await _banner_done(scene)
	_advance(scene, 70)
	await rec.call("frames", 6)
	rec.call("freeze")
	return true


## The Rattenkönigin on Gleis 9 (floor boss (0, 0)): intro (closed 6 m ring, shutter, crane), then phase 2 with the
## train lane telegraph along the track at z = -3.3 m and a puddle circle. `intro`: the still is taken 1.2 s into the
## intro (crane on its way, banner, shutter down).
func _boss(scene: Node, intro: bool = false) -> bool:
	var layout: FloorLayout = scene.call("get_layout")
	var boss: Node3D = scene.call("get_enemy", "f1_fb") as Node3D
	if boss == null:
		return false
	Game.rt_sim_factory = WorldStream.factory(scene, "boss", 600)
	var center: Vector3 = layout.cell_to_world(Vector2i(0, 0))
	var player: Node3D = scene.call("get_player") as Node3D
	var spot: Vector3 = boss.global_position + Vector3(4.2, 0.05, 0.8)
	var to: Vector3 = boss.global_position - spot
	player.call("teleport", spot, atan2(-to.x, -to.z))
	scene.call("get_camera_rig").call("snap", atan2(-to.x, -to.z))
	scene.call("get_companion").call("snap_behind")
	scene.call("_update_room", true)
	if center == Vector3.INF:
		return false
	var d: Node = scene.call("get_director") as Node
	_manual(scene)
	if not await rec.call("until", func() -> bool: return d != null and bool(d.call("is_busy")), 300):
		push_warning("[CaptureRt] the boss intro did not start")
		return false
	if intro:
		await rec.call("seconds", 1.2)
		rec.call("freeze")
		return true
	await rec.call("seconds", 2.7)                  # the crane, then the blocking intro line is read
	await rec.call("_quiet_mod_dialog")
	if not await rec.call("until", func() -> bool: return Game.combat != null, 900):
		push_warning("[CaptureRt] the boss combat did not start")
		return false
	await rec.call("_quiet_mod_dialog")
	await _banner_done(scene)
	_advance(scene, 205)
	await _banner_done(scene)                       # "PHASE 2" (tick 150) is long over at tick 205
	await rec.call("frames", 6)
	rec.call("freeze")
	return true


## A flight through a door: a fight in (1, 4), Kai runs east into the door lane (ring gap) — the still shows him in the
## lane, the ring with its gap and the lane tape, and R3's flee countdown (world fixture "flee": FLEE_WARNING at 30).
func _flee(scene: Node) -> bool:
	if not await _start(scene, "f1_g1", "flee", 3.5, Rules.NORMAL, Vector3(0.0, 0.0, 0.0), -PI * 0.5):
		return false
	await _banner_done(scene)
	var player: Node3D = scene.call("get_player") as Node3D
	var center: Vector3 = (scene.call("get_layout") as FloorLayout).cell_to_world(Vector2i(1, 4))
	scene.call("get_camera_rig").set("yaw", -PI * 0.5)
	Input.action_press(&"move_forward")
	var ok: bool = await rec.call("until", func() -> bool: return player.global_position.x - center.x >= 5.3, 600)
	Input.action_release(&"move_forward")
	_advance(scene, 40)                             # 1.3 s outside: the countdown runs (07 §2.5)
	await rec.call("frames", 4)
	rec.call("freeze")
	return ok


## Kai stands `dist` m from the lead of `group_id` (or at `at` relative to the room centre with yaw `yaw`), the world
## fixture plays `plan`, the combat starts with `adv`.
func _start(scene: Node, group_id: String, plan: String, dist: float, adv: int, at: Vector3 = Vector3.INF,
		yaw: float = INF) -> bool:
	var actor: Node3D = scene.call("get_enemy", group_id) as Node3D
	if actor == null:
		push_warning("[CaptureRt] no group %s" % group_id)
		return false
	var layout: FloorLayout = scene.call("get_layout")
	var cell: Vector2i = layout.world_to_cell(actor.global_position)
	var player: Node3D = scene.call("get_player") as Node3D
	var pos: Vector3
	var face: float
	if at != Vector3.INF:
		pos = layout.cell_to_world(cell) + at
		face = yaw
	else:
		var center: Vector3 = layout.cell_to_world(cell)
		var away: Vector3 = (center - actor.global_position)
		away.y = 0.0
		away = away.normalized() if away.length() > 0.3 else Vector3.BACK
		pos = actor.global_position + away * dist
		var to: Vector3 = actor.global_position - pos
		face = atan2(-to.x, -to.z)
	player.call("teleport", Vector3(pos.x, 0.05, pos.z), face)
	scene.call("get_camera_rig").call("snap", face)
	scene.call("get_companion").call("snap_behind")
	scene.call("_update_room", true)
	await rec.call("frames", 3)
	_manual(scene)
	Game.rt_sim_factory = WorldStream.factory(scene, plan, 900)
	scene.call("_trigger_encounter", group_id, str(actor.call("encounter_id")), adv, "")
	if not await rec.call("until", func() -> bool: return Game.combat != null, 60):
		return false
	await rec.call("_quiet_mod_dialog")             # the M.O.D. box is a subtitle in a combat (R3, 07 §8.8)
	return true


## R3's start banner ("KAMPF!" / "ERSTSCHLAG!", 1.2 s) is over before the still (it shows the fight seconds later).
func _banner_done(scene: Node) -> void:
	var d: Node = scene.call("get_director") as Node
	var hud: Node = d.get("hud") as Node if d != null else null
	var banner: Node = hud.get("banner") as Node if hud != null and is_instance_valid(hud) else null
	if banner != null:
		await rec.call("until", func() -> bool: return not bool(banner.call("is_showing")), 600)


## The director steps the combat only through advance() (the still shows an exact tick).
func _manual(scene: Node) -> void:
	var d: Node = scene.call("get_director") as Node
	if d != null:
		d.set("auto_tick", false)


func _advance(scene: Node, ticks: int) -> void:
	var d: Node = scene.call("get_director") as Node
	if d != null:
		d.call("advance", ticks)


const Rules := preload("res://scenes/exploration/encounter_rules.gd")
