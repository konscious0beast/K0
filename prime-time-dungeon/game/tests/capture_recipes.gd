extends Node
## Capture recipes (02_TECH §11.3): named scripted states for `check.sh --shot … --recipe=<name>` (tests/capture.gd).
## Loaded at runtime after the autoloads are ready, so autoloads and class_names are fine here. Private (no
## class_name). run() is a coroutine returning true on success; the screen is already under root (Router.adopt).
## Recipes drive screens through their public APIs and a few private members (test tool only, never game code).
##
## Exploration (exploration.tscn): explore_platform | explore_sewer | explore_cellar (zone room with an enemy group in
##   view), prompt_platform | prompt_sewer | prompt_cellar (Kai in front of a chest: HUD prompt + marker), bigmap,
##   pause_party | pause_inventory | pause_equipment | pause_skills | pause_settings.
## Battle (battle.tscn, optional --params={"encounter": "<enc id>"}): battle_menu, battle_skills, battle_target,
##   battle_damage, battle_enemy_turn, boss_intro, boss_phase, battle_gift, battle_victory, battle_results.
## Safe room (safe_room.tscn): safe_vending, safe_lootbox, safe_lootbox_open, safe_mopsula, safe_equipment.

const ZONES: Dictionary = {"platform": "zone_platform", "sewer": "zone_sewer", "cellar": "zone_cellar"}


func run(recipe: String, scene: Node) -> bool:
	var fn: String = "_r_" + recipe
	var arg: String = ""
	if not has_method(fn):
		# "<family>_<arg>" recipes (explore_sewer → _r_explore("sewer"))
		var cut: int = recipe.rfind("_")
		if cut > 0 and has_method("_r_" + recipe.substr(0, cut)):
			fn = "_r_" + recipe.substr(0, cut)
			arg = recipe.substr(cut + 1)
		else:
			push_warning("[CaptureRecipes] unknown recipe '%s'" % recipe)
			return false
	var ok: Variant = await (call(fn, scene, arg) if arg != "" else call(fn, scene))
	return ok == null or bool(ok)


## Waits `n` process frames.
func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Waits `sec` seconds of game time (process delta; frame rates under Xvfb vary a lot).
func seconds(sec: float) -> void:
	var t: float = 0.0
	while t < sec:
		await get_tree().process_frame
		t += get_process_delta_time()


## Freezes the moment for the still: the tree is paused (screens stop, ALWAYS nodes like GlobalUi keep running).
func freeze() -> void:
	get_tree().paused = true


## Waits until `cond` is true (max `limit` frames); false on timeout.
func until(cond: Callable, limit: int = 900) -> bool:
	for i in limit:
		if bool(cond.call()):
			return true
		await get_tree().process_frame
	return bool(cond.call())


# --- exploration ------------------------------------------------------------------------------------------------------

## A non-boss enemy group in `zone`, Kai 6 m in front of it, camera behind Kai looking at the group.
func _r_explore(scene: Node, zone_key: String) -> bool:
	if not await _explore_ready(scene):
		return false
	var layout: FloorLayout = scene.call("get_layout")
	var zone: String = str(ZONES.get(zone_key, zone_key))
	var spawn: EnemySpawn = null
	for e: EnemySpawn in layout.enemies:
		var rc: RoomCell = layout.cell_at(e.cell)
		if rc != null and rc.zone == zone and not e.is_boss and scene.call("get_enemy", e.id) != null:
			spawn = e
			break
	if spawn == null:
		push_warning("[CaptureRecipes] no enemy group in %s" % zone)
		return false
	_freeze_enemies(scene)
	var actor: Node3D = scene.call("get_enemy", spawn.id) as Node3D
	var target: Vector3 = actor.global_position
	_reveal_zone(scene, layout, zone)
	_place_facing(scene, layout, spawn.cell, target, 6.0)
	await frames(20)
	return true


## Kai right in front of a closed chest of `zone`: HUD prompt, touch hand icon, focus marker.
func _r_prompt(scene: Node, zone_key: String) -> bool:
	if not await _explore_ready(scene):
		return false
	var layout: FloorLayout = scene.call("get_layout")
	var zone: String = str(ZONES.get(zone_key, zone_key))
	var chest: ChestSpawn = null
	for c: ChestSpawn in layout.chests:
		var rc: RoomCell = layout.cell_at(c.cell)
		if rc != null and rc.zone == zone and c.type != "locked":
			chest = c
			break
	if chest == null:
		push_warning("[CaptureRecipes] no chest in %s" % zone)
		return false
	_freeze_enemies(scene)
	_reveal_zone(scene, layout, zone)
	var it: Node3D = scene.call("get_interactable", chest.id) as Node3D
	var target: Vector3 = it.global_position if it != null else layout.local_to_world(chest.cell, chest.offset)
	_place_facing(scene, layout, chest.cell, target, 1.6)
	await frames(30)
	return true


func _r_bigmap(scene: Node) -> bool:
	if not await _explore_ready(scene):
		return false
	var layout: FloorLayout = scene.call("get_layout")
	_freeze_enemies(scene)
	for zone: String in ["zone_platform", "zone_sewer", "zone_cellar"]:
		_reveal_zone(scene, layout, zone)
	var hud: Node = scene.get("_hud")
	await frames(5)
	return hud != null and hud.call("open_big_map") != null


func _r_pause(scene: Node, tab: String) -> bool:
	if not await _explore_ready(scene):
		return false
	_freeze_enemies(scene)
	_give_loot()
	var hud: Node = scene.get("_hud")
	await frames(5)
	if hud == null:
		return false
	var pm: Node = hud.call("open_pause_menu", tab)
	if pm == null:
		return false
	get_tree().paused = true
	await frames(10)
	return true


func _explore_ready(scene: Node) -> bool:
	if not await until(func() -> bool: return bool(scene.get("_built")), 300):
		push_warning("[CaptureRecipes] exploration not built")
		return false
	scene.set("auto_start_battle", false)
	# the countdown runs in a real run after the tutorial battle: show the timer like in play
	if Game.state != null and Game.state.floor_run != null and not Game.state.floor_run.timer_started:
		Game.state.floor_run.timer_started = true
		Events.floor_timer_started.emit()
	return true


func _freeze_enemies(scene: Node) -> void:
	var groups: Dictionary = scene.get("_enemies")
	for gid: Variant in groups.keys():
		var a: Node = groups[gid] as Node
		if a != null and is_instance_valid(a):
			a.set("frozen", true)


## Marks the start corridor + every cell of `zone` visited (minimap / big map show the explored area).
func _reveal_zone(scene: Node, layout: FloorLayout, zone: String) -> void:
	var hud: Node = scene.get("_hud")
	for key: Variant in layout.cells.keys():
		var c: Vector2i = key as Vector2i
		var rc: RoomCell = layout.cell_at(c)
		if rc == null:
			continue
		if rc.zone == zone or rc.zone == "zone_platform" or layout.path.has(c):
			if Game.visit_room(c) and hud != null:
				hud.call("mark_visited", c)


## Teleports Kai `dist` m from `target` (inside room `cell`), facing it; snaps camera + Mopsula.
func _place_facing(scene: Node, layout: FloorLayout, cell: Vector2i, target: Vector3, dist: float) -> void:
	var center: Vector3 = layout.cell_to_world(cell)
	var best: Vector3 = Vector3.ZERO
	var best_score: float = -INF
	for d: Vector3 in [Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, -1),
			Vector3(0.7, 0, 0.7), Vector3(-0.7, 0, 0.7), Vector3(0.7, 0, -0.7), Vector3(-0.7, 0, -0.7)]:
		var p: Vector3 = target + d.normalized() * dist
		var local: Vector3 = p - center
		# inside the room interior, preferring spots near the centre (long view over the room)
		var margin: float = 6.0 - maxf(absf(local.x), absf(local.z))
		var score: float = margin + (0.5 if d.z > 0.0 else 0.0)
		if margin > 0.0 and score > best_score:
			best_score = score
			best = p
	if best_score == -INF:
		best = center
	var to: Vector3 = target - best
	var yaw: float = atan2(-to.x, -to.z)
	var player: Node3D = scene.call("get_player") as Node3D
	player.call("teleport", Vector3(best.x, 0.05, best.z), yaw)
	var cam: Node = scene.call("get_camera_rig")
	cam.call("snap", yaw)
	var comp: Node = scene.call("get_companion")
	comp.call("snap_behind")
	scene.call("_update_room", true)


## A few items / equipment so the inventory and equipment pages are not empty.
func _give_loot() -> void:
	if Game.state == null or Game.state.inventory == null:
		return
	var inv: Inventory = Game.state.inventory
	for id: String in ["itm_bandage", "itm_antidote", "itm_energy_krawumm", "itm_brutzel_burger", "itm_molotov",
			"itm_smoke", "itm_wpn_pipe_wrench", "itm_arm_safety_vest", "itm_acc_lucky_ticket", "itm_wpn_collar_studded"]:
		if DB.has_id("items", id):
			inv.add(id, 2)
	inv.add_credits(250)


# --- battle ----------------------------------------------------------------------------------------------------------

func _hud(scene: Node) -> Node:
	return scene.get("hud") as Node


func _wait_menu(scene: Node, limit: int = 1500) -> bool:
	var ok: bool = await until(func() -> bool:
		var h: Node = _hud(scene)
		return h != null and bool(h.get("awaiting")) and h.get("level") == &"menu", limit)
	if not ok:
		push_warning("[CaptureRecipes] no command menu")
	return ok


## Slow playback (speed 1) for mid-action stills.
func _slow(scene: Node) -> void:
	scene.set("capture", false)
	scene.set("speed_override", 1.0)


## Waits until the BattlePlayer presents an event of `type` (optionally by an actor id starting with `actor_prefix`).
func _wait_event(scene: Node, type: ActionEvent.Type, limit: int = 1800, actor_prefix: String = "") -> bool:
	var seen: Array[bool] = [false]
	var player: Node = scene.get("player") as Node
	var cb: Callable = func(e: ActionEvent) -> void:
		if e.type == type and (actor_prefix == "" or e.actor_id.begins_with(actor_prefix)):
			seen[0] = true
	player.connect("event_played", cb)
	var ok: bool = await until(func() -> bool: return seen[0], limit)
	player.disconnect("event_played", cb)
	return ok


func _actor(scene: Node) -> Combatant:
	var h: Node = _hud(scene)
	return h.get("_actor") as Combatant if h != null else null


## Command menu of the first party member that has skills (Mopsula's magic list reads best).
func _skill_turn(scene: Node) -> bool:
	for i in 4:
		if not await _wait_menu(scene):
			return false
		var a: Combatant = _actor(scene)
		if a != null and a.skills.size() > 1:
			return true
		_hud(scene).call("_submit", BattleCommand.defend(a.id))
		await frames(2)
	return false


func _r_battle_menu(scene: Node) -> bool:
	return await _wait_menu(scene)


func _r_battle_skills(scene: Node) -> bool:
	if not await _skill_turn(scene):
		return false
	_hud(scene).call("_on_command_chosen", BattleCommand.Kind.SKILL)
	await frames(20)
	return true


func _r_battle_target(scene: Node) -> bool:
	if not await _wait_menu(scene):
		return false
	_hud(scene).call("_on_command_chosen", BattleCommand.Kind.ATTACK)
	await frames(30)
	return _hud(scene).get("level") == &"target"


func _attack_first_enemy(scene: Node) -> void:
	var a: Combatant = _actor(scene)
	var st: BattleState = _hud(scene).get("_state") as BattleState
	var target: String = st.default_target(a, a.attack_skill)
	_hud(scene).call("_submit", BattleCommand.attack(a.id, target))


func _r_battle_damage(scene: Node) -> bool:
	if not await _wait_menu(scene):
		return false
	_slow(scene)
	_attack_first_enemy(scene)
	if not await _wait_event(scene, ActionEvent.Type.DAMAGE, 1800, "p"):
		return false
	await seconds(0.25)
	freeze()
	return true


func _r_battle_enemy_turn(scene: Node) -> bool:
	if not await _wait_menu(scene):
		return false
	_slow(scene)
	_hud(scene).call("_submit", BattleCommand.defend(_actor(scene).id))
	if not await _wait_event(scene, ActionEvent.Type.ACTION_START, 1800, "e"):
		return false
	await seconds(0.3)
	freeze()
	return true


## Boss intro (lower third + crane), frozen mid-crane: pass --params={"encounter": "enc_f1_boss_…", "capture": false,
## "speed": 1.0} (a capture battle plays at speed ≥ 3 from its first frame, before a recipe can slow it down).
func _r_boss_intro(scene: Node) -> bool:
	if not await until(func() -> bool: return _hud(scene) != null and bool(_hud(scene).get("_intro")), 600):
		return false
	await seconds(1.25)
	freeze()
	return true


## Phase change: the boss is set just above its first phase threshold, Kai's attack crosses it.
func _r_boss_phase(scene: Node) -> bool:
	if not await _wait_menu(scene, 2400):
		return false
	var st: BattleState = _hud(scene).get("_state") as BattleState
	var boss: Combatant = null
	for c: Combatant in st.enemies():
		if c.is_boss:
			boss = c
	if boss == null:
		return false
	var phases: Array = DB.enemy(boss.def_id).phases
	var limit: float = float((phases[0] as Dictionary).get("hp_above", 0.5)) if not phases.is_empty() else 0.5
	boss.hp = int(ceil(float(boss.max_hp()) * limit)) + 1
	_slow(scene)
	var a: Combatant = _actor(scene)
	_hud(scene).call("_submit", BattleCommand.attack(a.id, boss.id))
	if not await _wait_event(scene, ActionEvent.Type.PHASE_CHANGE):
		return false
	await seconds(0.45)
	freeze()
	return true


func _r_battle_gift(scene: Node) -> bool:
	if not await _wait_menu(scene):
		return false
	# hype over the 50 threshold → the sponsor system gift arrives at the next turn boundary (lower third)
	Show.add_hype(maxf(0.0, 55.0 - Show.hype()), &"capture")
	_slow(scene)
	_hud(scene).call("_submit", BattleCommand.defend(_actor(scene).id))
	if not await _wait_event(scene, ActionEvent.Type.SPONSOR_GIFT):
		return false
	await seconds(0.7)
	freeze()
	return true


## Pass --params={"capture_turns": 99}: AutoPolicy plays every party turn.
func _r_battle_victory(scene: Node) -> bool:
	_slow(scene)                                 # constant speed 1: banner, orbit and results keep their timing
	if not await _wait_event(scene, ActionEvent.Type.BATTLE_END, 12000):
		return false
	await seconds(0.9)
	freeze()
	return true


func _r_battle_results(scene: Node) -> bool:
	_slow(scene)
	var ok: bool = await until(func() -> bool:
		var r: Node = scene.get("results") as Node
		return r != null and bool(r.get("shown")), 15000)
	await seconds(1.2)
	return ok


# --- safe room -------------------------------------------------------------------------------------------------------

func _safe_ready(scene: Node) -> bool:
	return await until(func() -> bool: return scene.get("_ui") != null and not scene.get("menu_buttons").is_empty(),
		300)


func _r_safe_vending(scene: Node) -> bool:
	if not await _safe_ready(scene):
		return false
	await frames(5)
	scene.call("open_vending")
	await frames(20)
	return true


func _r_safe_equipment(scene: Node) -> bool:
	if not await _safe_ready(scene):
		return false
	_give_loot()
	await frames(5)
	scene.call("open_pause", "equipment")
	get_tree().paused = true
	await frames(20)
	return true


func _add_boxes() -> void:
	if Game.state == null:
		return
	for id: String in ["box_silver", "box_bronze", "box_bronze", "box_gold", "box_fan"]:
		if DB.has_id("lootboxes", id):
			Game.state.pending_lootboxes.append(id)


func _r_safe_lootbox(scene: Node) -> bool:
	if not await _safe_ready(scene):
		return false
	_add_boxes()
	await frames(5)
	var lb: Node = scene.call("open_lootboxes")
	await frames(10)
	lb.call("select_box", "box_silver")
	await frames(40)
	return true


func _r_safe_lootbox_open(scene: Node) -> bool:
	if not await _safe_ready(scene):
		return false
	_add_boxes()
	await frames(5)
	var lb: Node = scene.call("open_lootboxes")
	await frames(10)
	lb.call("select_box", "box_gold")
	await frames(5)
	lb.call("start_opening")
	for i in 12:
		await frames(15)
		if lb.get("state") == &"reveal" or lb.get("state") == &"done":
			break
		lb.call("tap")
	if lb.get("state") == &"reveal":
		lb.call("reveal_all")
	await frames(60)
	return true


func _r_safe_mopsula(scene: Node) -> bool:
	if not await _safe_ready(scene):
		return false
	await frames(10)
	scene.call("talk_to_mopsula")
	await frames(90)
	return true
