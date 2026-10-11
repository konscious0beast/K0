extends Node
## Capture recipes (02_TECH §11.3): named scripted states for `check.sh --shot … --recipe=<name>` (tests/capture.gd).
## Loaded at runtime after the autoloads are ready, so autoloads and class_names are fine here. Private (no
## class_name). run() is a coroutine returning true on success; the screen is already under root (Router.adopt).
## Recipes drive screens through their public APIs and a few private members (test tool only, never game code).
##
## Exploration (exploration.tscn): explore_platform | explore_sewer | explore_cellar (zone room with an enemy group in
##   view), prompt_platform | prompt_sewer | prompt_cellar (Kai in front of a chest: HUD prompt + marker), bigmap,
##   pause_party | pause_inventory | pause_equipment | pause_skills | pause_show (06-C) | pause_settings.
## Battle (battle.tscn, optional --params={"encounter": "<enc id>"}): battle_menu, battle_skills, battle_target,
##   battle_damage, battle_enemy_turn, boss_intro, boss_phase, battle_gift, battle_victory, battle_results,
##   battle_results_show (06-C: a won show bet in the results).
## Safe room (safe_room.tscn): safe_vending, safe_lootbox, safe_lootbox_open, safe_mopsula, safe_equipment,
##   safe_talents_menu (menu + the gold TALENT-SHOW button), safe_talent_show (the Talent-Show, 06 package B),
##   safe_hero_talents (integration A × B: open choices + "Figur wechseln" → TALENT-SHOW and M.O.D. box side by side).
## Exploration + pause: talents_party (party page with talents and an open choice, 06 package B).
## 06 package A: bark_platform | bark_sewer | bark_cellar (Graf Mopsula leads and barks at a group: cone + rings,
##   "?!"), hero_mopsula_<zone> (exploration as Mopsula, Kai follows), safe_hero_switch ("Figur wechseln" pressed:
##   the Count in front), battle_partner_auto ("Partner automatisch": DU / AUTO pills at the hero's menu),
##   secret_wall (Kai in front of the Kulissenwand), secret_open (the Count barks it over), secret_note (Kai in
##   front of a Regie-Notiz: prompt + marker).
## 06-D (KI-Admin): twist_lights | twist_confetti | twist_live (exploration with a running twist: chip, vignette /
##   confetti, an M.O.D. live line labelled "KI live"), safe_happy (vending machine during a Happy Hour).
## Polish pass: doorway_approach | doorway_through | doorway_mopapproach | doorway_mopthrough (camera in front of /
##   just past an open door, Kai or Graf Mopsula leading).
## Echtzeitkampf in the world (07, R2; tests/fixtures/rt_world/capture_rt.gd): rt_world_regular (a fight in a room
##   with the LED ring), rt_world_two_groups (two groups on one set), rt_world_boss (Gleis 9 with the train lane
##   telegraph), rt_world_boss_intro (the crane), rt_world_flee (Kai in a door lane). The combat HUD stills of R3
##   (rt_tutorial, rt_regular, rt_boss, …) follow in their own section below.
## Echtzeitkampf with the real data (07, R4; tests/tools/capture_r4.gd, run with --combat=realtime): rt_r4_regular (zone
##   C, a telegraph filling up), rt_r4_showboss (the Kanalratten-Gala, E26), rt_r4_hausmeister (key throw line),
##   rt_r4_queen (Gleis 9, phase 2, the train on its track).
## 08 K1 (Casting): pause_card (exploration + pause menu, party page, the candidate card of the sample persona open),
##   intro_card (intro.tscn with {"capture": true}: the studio with the candidate's lower third and persona_intro line),
##   casting_accents (persona_casting.tscn with {"open": "keyboard"}: the on-screen keyboard's accent layer).

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


## 06 package A: Graf Mopsula leads (bodies swapped), stands 3.4 m in front of a group of `zone` and barks: the violet
## cone and sound rings, the group dazed ("?!"), Kai behind the Count.
func _r_bark(scene: Node, zone_key: String) -> bool:
	if not await _r_hero_mopsula(scene, zone_key, 3.4):
		return false
	scene.call("perform_action")
	await seconds(0.12)
	freeze()
	return true


## 06 package A: exploration with Graf Mopsula as the player body, `dist` m in front of a group of `zone`.
func _r_hero_mopsula(scene: Node, zone_key: String, dist: float = 5.0) -> bool:
	if not await _explore_ready(scene):
		return false
	Game.state.hero = "mopsula"
	scene.call("refresh_hero")
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
	_reveal_zone(scene, layout, zone)
	_place_facing(scene, layout, spawn.cell, actor.global_position, dist)
	await frames(20)
	return true


## 06 §2.7 (package A): the Kulissenwand (5,3)↔(5,2) — "wall": Kai 3.2 m in front of it (cracks, dust); "open": Graf
## Mopsula barks from 2.9 m and the panel tips over (still mid-fall); "note": Kai in front of Regie-Notiz 1 (kiosk).
func _r_secret(scene: Node, what: String) -> bool:
	if not await _explore_ready(scene):
		return false
	var layout: FloorLayout = scene.call("get_layout")
	Game.state.floor_run.defeated_groups.append("f1_g7")
	var g7: Node = scene.call("get_enemy", "f1_g7") as Node
	if g7 != null:
		g7.queue_free()
	_freeze_enemies(scene)
	_reveal_zone(scene, layout, "zone_sewer")
	if what == "note":
		var note: Node3D = scene.call("get_interactable", "sec_e1_note_1") as Node3D
		if note == null:
			return false
		_place_facing(scene, layout, Vector2i(2, 5), note.global_position, 1.3)
		await frames(20)
		return scene.call("focused_interactable") == note
	var w: Node3D = scene.call("get_wall", "sec_e1_wall_sewer") as Node3D
	if w == null:
		return false
	if what == "open":                     # the Count barks it over from 3 m (cone + falling panel in one still)
		Game.state.hero = "mopsula"
		scene.call("refresh_hero")
	var out: Vector3 = w.global_transform.basis.z.normalized()
	var dist: float = 3.2 if what == "wall" else 2.9
	var pos: Vector3 = w.global_position + out * dist + w.global_transform.basis.x * 0.6
	var to: Vector3 = w.global_position - pos
	var yaw: float = atan2(-to.x, -to.z)
	(scene.call("get_player") as Node3D).call("teleport", Vector3(pos.x, 0.05, pos.z), yaw)
	scene.call("get_camera_rig").call("snap", yaw)
	var comp: Node = scene.call("get_companion")
	if comp != null:
		comp.call("snap_behind")
	await frames(20)
	if what == "open":
		scene.call("perform_action")
		await until(func() -> bool: return Secrets.is_open(Game.state, "sec_e1_wall_sewer"), 240)
		await seconds(0.3)
		freeze()
	return true


## Polish pass (camera at open doorways): the start corridor's north door (1,7)↔(1,6). `what` = approach (Kai 1.5 m in
## front of the open door, facing it), through (Kai 0.4 m past it, the door behind him), mopapproach / mopthrough (the
## same with Graf Mopsula leading). The hero walks towards the spot first, so the camera is the settled one.
func _r_doorway(scene: Node, what: String) -> bool:
	if not await _explore_ready(scene):
		return false
	_freeze_enemies(scene)
	if what.begins_with("mop"):
		Game.state.hero = "mopsula"
		scene.call("refresh_hero")
	var layout: FloorLayout = scene.call("get_layout")
	_reveal_zone(scene, layout, "zone_platform")
	var door: Vector3 = layout.cell_to_world(Vector2i(1, 7)) + Vector3(0.0, 0.0, -FloorLayout.ROOM_SIZE * 0.5)
	var through: bool = what.ends_with("through")
	var spot: Vector3 = door + Vector3(0.0, 0.0, -0.4 if through else 1.5)
	var start: Vector3 = spot + Vector3(0.0, 0.0, 3.3)     # ~0.6 s of walking before the spot
	var player: Node3D = scene.call("get_player") as Node3D
	player.call("teleport", Vector3(start.x, 0.05, start.z), 0.0)
	scene.call("get_camera_rig").call("snap", 0.0)
	scene.call("get_companion").call("snap_behind")
	scene.call("_update_room", true)
	Input.action_press(&"move_forward")
	await until(func() -> bool: return player.global_position.z <= spot.z, 240)
	Input.action_release(&"move_forward")
	await frames(12)
	freeze()
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
		# Show says "floor_start" on the first explore tick of a running countdown (int-cr, GDD §1.4 B2): in the stills
		# its M.O.D. box would sit over Kai and the prompt, so that line is skipped (test tool: private Show member).
		Show.set("_floor_start_pending", false)
		# 06-C: M.O.D. announces the floor's preference right after "floor_start" — skipped in the stills as well
		Show.set("_announce_queue", PackedStringArray())
	await _quiet_mod_dialog()
	return true


## Ends whatever the M.O.D. box shows or queues (e.g. tutorial hints) so exploration stills show the scene itself.
func _quiet_mod_dialog() -> void:
	var ui: Node = get_tree().root.get_node_or_null("GlobalUi")
	var d: Node = ui.get("mod_dialog") as Node if ui != null else null
	if d == null:
		return
	await frames(2)
	for i in 16:
		if not bool(d.call("is_busy")):
			return
		d.call("advance")                # full text …
		d.call("advance")                # … then end the line
		await frames(1)


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


## 06 package A: "Partner automatisch" on — the menu waits for the hero, the panels read DU / AUTO.
func _r_battle_partner_auto(scene: Node) -> bool:
	Game.settings.partner_auto = true
	var ctrl: Node = scene.get("controller") as Node
	if ctrl == null:
		return false
	ctrl.set("force_manual", false)
	ctrl.set("auto_turns", 0)
	if not await _wait_menu(scene):
		return false
	ctrl.call("mark_roles")
	await frames(10)
	return true


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


## 06-C: like battle_results, but M.O.D.'s preference of the floor is "Kein Schritt zurück" with two hearts already —
## this battle fills the third: the results show the "Show" row and the bet is won (toast + line). Pass
## --params={"capture_turns": 99, "encounter": "enc_f1_a2"}: the debug default is the tutorial battle, which never
## counts for M.O.D.'s preferences.
func _r_battle_results_show(scene: Node) -> bool:
	if Game.state != null and Game.state.show != null:
		Game.state.show.marotten["active"] = ["mar_brave"]
		Game.state.show.marotten["hits"] = {"mar_brave": 2}
		Game.state.show.marotten["won"] = []
		if Game.state.floor_run != null:
			Game.state.floor_run.timer_started = true      # the chip shows once the countdown runs (debug setup: not yet)
	return await _r_battle_results(scene)


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


## 06 package A: "Figur wechseln" pressed — the Count stands in front, M.O.D. comments, the status banner names him.
func _r_safe_hero_switch(scene: Node) -> bool:
	if not await _safe_ready(scene):
		return false
	await frames(10)
	scene.call("activate", "hero")
	await seconds(1.2)
	freeze()
	return true


func _r_safe_mopsula(scene: Node) -> bool:
	if not await _safe_ready(scene):
		return false
	await frames(10)
	scene.call("talk_to_mopsula")
	await frames(90)
	return true


# --- 06 package B: Talent-Show ----------------------------------------------------------------------------------------

## Party at L5 (two open choices each), Kai already picked one talent at L3 (so the card shows "Bisher: …").
func _talent_party() -> void:
	if Game.state == null:
		return
	for m: PartyMember in Game.state.party:
		m.level = 5
	Game.state.member("kai").talents = {"tal_kai_wischtechnik": 1}
	Progression.full_heal(Game.state, DB.data)
	Events.party_changed.emit()


func _r_safe_talents_menu(scene: Node) -> bool:
	if not await _safe_ready(scene):
		return false
	_talent_party()
	scene.call("_refresh_menu_labels")
	scene.call("_focus_first")
	await seconds(3.4)                           # the heal banner fades
	return true


## Integration 06 A × B: open talent choices + "Figur wechseln" pressed — the TALENT-SHOW button (top right) stays
## clear of the M.O.D. box (bottom right) that comments on the switch.
func _r_safe_hero_talents(scene: Node) -> bool:
	if not await _safe_ready(scene):
		return false
	_talent_party()
	scene.call("_refresh_menu_labels")
	await frames(10)
	scene.call("activate", "hero")
	await seconds(1.2)
	freeze()
	return true


func _r_safe_talent_show(scene: Node) -> bool:
	if not await _safe_ready(scene):
		return false
	_talent_party()
	await frames(5)
	scene.call("open_talent_show")
	await frames(30)
	return true


func _r_talents_party(scene: Node) -> bool:
	_talent_party()
	return await _r_pause(scene, "party")


# --- 06-D (KI-Admin): twists and M.O.D. live ----------------------------------------------------------------------

## Exploration (sewer group in view) with a running twist (src "dev", recorded like any twist): twist_lights (chip +
## vignette + M.O.D.'s announcement), twist_confetti (chip + rising confetti), twist_live (chip + an M.O.D. live line
## through Show.say_external, labelled "KI live"). Shoot with few --frames (e.g. 3): lines expire while software GL
## renders slowly.
func _r_twist(scene: Node, which: String) -> bool:
	if not await _r_explore(scene, "sewer"):
		return false
	var ids: Dictionary = {"lights": "tw_lights_out", "confetti": "tw_confetti_gravity", "live": "tw_quiet_please"}
	var why: String = Game.apply_twist({"id": str(ids.get(which, "tw_lights_out")), "src": "dev"})
	if why != "":
		push_warning("[CaptureRecipes] twist refused: " + why)
		return false
	if which == "lights":
		await seconds(2.5)                      # the announcement types out
		return true
	await _quiet_mod_dialog()
	if which == "live":
		Show.set("_last_line_at", -INF)
		Show.say_external("Kandidat:in {name} schleicht wie ein Profi. Die Ratten haben jetzt Ohrstöpsel.", &"mod",
			"stunt")
		await seconds(2.5)
	else:
		await seconds(2.0)                      # confetti on its way up
	return true


## Safe room vending machine during a Happy Hour (tw_happy_hour armed in the exploration, visit running): discounted
## prices + the twist chip in the safe-room overlay.
func _r_safe_happy(scene: Node) -> bool:
	if not await _safe_ready(scene):
		return false
	var fr: FloorRun = Game.state.floor_run
	var loc: StringName = fr.location
	fr.location = &"start"                       # armed in the exploration (test tool), then the visit runs
	fr.timer_started = true
	var why: String = Game.apply_twist({"id": "tw_happy_hour", "src": "dev", "params": {"pct": 25}})
	fr.location = loc
	TwistApplier.on_safe_room_enter(Game.state)
	if why != "":
		push_warning("[CaptureRecipes] twist refused: " + why)
		return false
	await frames(5)
	scene.call("open_vending")
	await frames(20)
	return true


# --- Echtzeitkampf (07, R2): real-time combats in the world (tests/fixtures/rt_world/capture_rt.gd) ------------------

func _rt(scene: Node, which: String) -> bool:
	var r: RefCounted = (load("res://tests/fixtures/rt_world/capture_rt.gd") as GDScript).new()
	r.set("rec", self)
	return bool(await r.call("run", which, scene))


func _r_rt_world_regular(scene: Node) -> bool:
	return await _rt(scene, "regular")


func _r_rt_world_two_groups(scene: Node) -> bool:
	return await _rt(scene, "two_groups")


func _r_rt_world_boss(scene: Node) -> bool:
	return await _rt(scene, "boss")


func _r_rt_world_boss_intro(scene: Node) -> bool:
	return await _rt(scene, "boss_intro")


func _r_rt_world_flee(scene: Node) -> bool:
	return await _rt(scene, "flee")


# --- Echtzeitkampf (07, R4): floor-1 combats with the real data (tests/tools/capture_r4.gd) -------------------------
# exploration.tscn + --combat=realtime --recipe=rt_r4_regular | rt_r4_showboss | rt_r4_hausmeister | rt_r4_queen

func _r_rt_r4(scene: Node, which: String) -> bool:
	var r: RefCounted = (load("res://tests/tools/capture_r4.gd") as GDScript).new()
	r.set("rec", self)
	return bool(await r.call("run", which, scene))


# --- Echtzeitkampf (07, R3): combat HUD stills over the exploration ---------------------------------------------------
# exploration.tscn + --recipe=rt_tutorial | rt_regular | rt_boss | rt_hint | rt_results | rt_credits | rt_real, each
# also as rt_<name>_notch (simulated display cutout: left / right 48, bottom 20). The real CombatHud (combat_hud.tscn)
# with all screen modes (ShowOverlay &"combat", M.O.D. subtitles, input map, TouchControls combat mode with --touch)
# is bound to the HudSim double (tests/fixtures/rt_hud: exact fight states, set rather than simulated) — rt_real to
# the real RtSim (R1b-I1) of RtKit's canned combat. Enemy figures are art-kit rigs standing in for R2's puppets; the
# boss still's red floor circle stands in for R2's TelegraphLayer.

const RtScenarios := preload("res://tests/fixtures/rt_hud/hud_scenarios.gd")
const RtDirector := preload("res://tests/fixtures/rt_hud/hud_director.gd")
const RtView := preload("res://scenes/combat/ui/combat_view.gd")
const RT_HUD: String = "res://scenes/combat/ui/combat_hud.tscn"
const RT_RESULTS: String = "res://scenes/combat/ui/combat_results.gd"
const RT_NOTCH: Dictionary = {"left": 48, "top": 0, "right": 48, "bottom": 20}


## The first tutorial fight (E28): slot 1 + SHOW, frames, the first card ("Wähle ein Ziel"), banner "KAMPF!".
func _r_rt_tutorial(scene: Node, variant: String = "") -> bool:
	var st: Dictionary = await _rt_stage(scene, "platform", ["enm_kanalratte", "enm_kanalratte"],
		{"level": 1, "tutorial": true}, variant)
	if st.is_empty():
		return false
	await seconds(0.5)
	freeze()
	return true


## A regular fight at level 4: every slot (cooldowns, GCD, a queued press, the potion 2/3), plates with threat dots
## and a casting shaman, statuses, Partner-Spezial, tactic chip, combat text.
func _r_rt_regular(scene: Node, variant: String = "") -> bool:
	var st: Dictionary = await _rt_stage(scene, "sewer", ["enm_rattenschamane", "enm_kanalratte", "enm_kanalratte"],
		{"level": 4, "threat": true}, variant)
	if st.is_empty():
		return false
	var sim: RtSim = st["sim"]
	var hud: Node = st["hud"]
	_rt_regular_state(sim)
	await seconds(1.7)                           # the "KAMPF!" banner is gone
	_rt_hits(hud, sim)
	await seconds(0.25)
	freeze()
	return true


## Boss fight (Der Hausmeister, phase 2 of 3): boss frame with phase diamonds and "Feierabend in 0:42", a worthy cast
## (gold), a red floor warning under the party, an add as target (frame at y 84), the Count casting (player cast bar).
func _r_rt_boss(scene: Node, variant: String = "") -> bool:
	_rt_boss_data()
	var st: Dictionary = await _rt_stage(scene, "cellar", ["enm_boss_hausmeister", "enm_kanalratte",
		"enm_kanalratte"], {"level": 6, "hero": "mopsula", "boss": true, "encounter": "enc_f1_boss_hausmeister",
		"dist": 4.0}, variant)                           # the Count's camera is steeper (polish pass): closer
	if st.is_empty():
		return false
	var sim: RtSim = st["sim"]
	var hud: Node = st["hud"]
	var boss: RtUnit = sim.unit("e0")
	boss.phase = 1
	boss.hp = boss.max_hp() * 58 / 100
	sim.call("set_tick", 30 * 60 * 3 - 42 * 30)         # enrage at 3:00 → 0:42 left
	sim.call("set_cast", "e0", "skl_b_rules", 50, 90, true, true)
	sim.unit("e1").hp = sim.unit("e1").max_hp() * 40 / 100
	var ctl: RtUnit = RtView.controlled(sim)
	ctl.target_id = "e1"
	ctl.mp = ctl.max_mp() * 55 / 100
	sim.call("set_cast", ctl.id, "skl_mop_noble_flame", 20, 45)
	var kai: RtUnit = RtView.partner(sim)
	kai.hp = kai.max_hp() * 62 / 100
	kai.target_id = "e0"
	boss.target_id = kai.id
	sim.unit("e1").target_id = ctl.id
	sim.unit("e2").target_id = kai.id
	sim.call("set_cd", ctl.id, "skl_mop_frost_sneeze", 70, 180)
	sim.set("gcds", {ctl.id: Vector2i(25, 45)})
	_rt_telegraph(scene, st["positions"]["p0"] as Vector3, 2.6)
	var banner: Node = hud.get("banner")
	await until(func() -> bool: return not bool(banner.call("is_showing")), 600)   # "KAMPF!" is over
	var e: ActionEvent = ActionEvent.make(ActionEvent.Type.PHASE_CHANGE)
	e.actor_id = "e0"
	e.value = 2
	hud.call("on_event", e)                      # the HUD's own phase banner
	await seconds(0.45)
	freeze()
	return bool(banner.call("is_showing"))


## The first-time hint "interrupt" (07 §2.13): the shaman starts a worthy cast, the card (where the subtitles sit)
## names the key; the sim holds while it shows.
func _r_rt_hint(scene: Node, variant: String = "") -> bool:
	var st: Dictionary = await _rt_stage(scene, "sewer", ["enm_rattenschamane", "enm_kanalratte", "enm_kanalratte"],
		{"level": 4, "unseen": ["interrupt"], "threat": true}, variant)
	if st.is_empty():
		return false
	var sim: RtSim = st["sim"]
	var hud: Node = st["hud"]
	_rt_regular_state(sim)
	sim.call("set_cd", "p0", "skl_kai_leash_trip", 0, 0)    # the interrupter is ready (the card asks for it)
	await seconds(1.7)
	sim.call("set_cast", "e0", "skl_e_zap", 6, 60, true, true)
	var e: ActionEvent = ActionEvent.make(ActionEvent.Type.CAST_START)
	e.actor_id = "e0"
	e.skill_id = "skl_e_zap"
	e.target_id = "p0"
	e.rt = {"end": sim.tick() + 54, "worthy": 1}
	hud.call("on_event", e)
	await seconds(0.4)
	freeze()
	return (hud.get("hints") as Node).call("current") == "interrupt"


## A regular victory: the HUD fades out, the "Applaus!" lower third with EXP / credits / loot and the level-up lower
## third with the talent chip (07 §8.9).
func _r_rt_results(scene: Node, variant: String = "") -> bool:
	var st: Dictionary = await _rt_stage(scene, "sewer", ["enm_rattenschamane", "enm_kanalratte", "enm_kanalratte"],
		{"level": 2}, variant)
	if st.is_empty():
		return false
	await seconds(1.0)
	var hud: Node = st["hud"]
	hud.call("finish", null)
	(st["sim"] as RtSim).call("finish", BattleResult.Outcome.VICTORY)
	for r: Node3D in st["rigs"] as Array:
		r.visible = false
	var res: CanvasLayer = (load(RT_RESULTS) as GDScript).new() as CanvasLayer
	get_tree().root.add_child(res)
	var result: BattleResult = BattleResult.new()
	result.outcome = BattleResult.Outcome.VICTORY
	result.exp = 54
	result.credits = 21
	var rw: BattleRewards = BattleRewards.new()
	rw.exp = 54
	rw.credits = 21
	rw.items = PackedStringArray(["itm_bandage", "itm_bandage"])
	var info: LevelUpInfo = LevelUpInfo.new()
	info.member_id = "kai"
	info.old_level = 2
	info.new_level = 3
	info.stat_gains = {"hp": 9, "mp": 2, "str": 2}
	rw.level_ups = [info]
	_rt_apply_level(info)
	res.call("present", result, rw)
	await seconds(0.9)
	res.process_mode = Node.PROCESS_MODE_PAUSABLE     # the still keeps the lower thirds (their tweens pause too)
	freeze()
	return true


## A boss victory: the credits panel ("Abspann", layer 60) over the boss room.
func _r_rt_credits(scene: Node, variant: String = "") -> bool:
	_rt_boss_data()
	var st: Dictionary = await _rt_stage(scene, "cellar", ["enm_boss_hausmeister"],
		{"level": 6, "boss": true, "encounter": "enc_f1_boss_hausmeister"}, variant)
	if st.is_empty():
		return false
	await seconds(0.8)
	(st["hud"] as Node).call("finish", null)
	(st["rigs"] as Array)[0].visible = false
	var res: CanvasLayer = (load(RT_RESULTS) as GDScript).new() as CanvasLayer
	get_tree().root.add_child(res)
	var result: BattleResult = BattleResult.new()
	result.outcome = BattleResult.Outcome.VICTORY
	result.is_boss = true
	result.boss_id = "enm_boss_hausmeister"
	var rw: BattleRewards = BattleRewards.new()
	rw.exp = 740
	rw.credits = 120
	rw.followers = 380
	if DB.has_id("lootboxes", "box_gold"):
		rw.boxes = PackedStringArray(["box_gold"])
	var info: LevelUpInfo = LevelUpInfo.new()
	info.member_id = "kai"
	info.old_level = 6
	info.new_level = 7
	info.stat_gains = {"hp": 9, "mp": 2, "str": 2, "def": 1}
	rw.level_ups = [info]
	_rt_apply_level(info)
	res.call("present", result, rw)
	await seconds(0.6)
	freeze()
	return true


## The run applies the rewards before the results show them (like the CTB flow): the party frame agrees.
func _rt_apply_level(info: LevelUpInfo) -> void:
	for m: PartyMember in Game.state.party:
		if m.id == info.member_id:
			m.level = info.new_level
	Events.party_changed.emit()


## Canvas draw calls with the combat HUD (07 §8.10 budget "UI-Draw-Calls ≤ 180"): the regular still (or "boss"), the
## maximum over 30 frames of the whole canvas (ShowOverlay, M.O.D. box, HUD, touch layer, combat text) with the combat
## HUD and with its layers hidden. Prints "R3 DRAW CALLS …" (tools: check.sh --shot …, --touch for the phone layout).
func _r_rt_drawcalls(scene: Node, variant: String = "") -> bool:
	var boss: bool = variant == "boss"
	if boss:
		_rt_boss_data()
	var st: Dictionary = await _rt_stage(scene, "cellar" if boss else "sewer", ["enm_boss_hausmeister",
		"enm_kanalratte", "enm_kanalratte"] if boss else ["enm_rattenschamane", "enm_kanalratte", "enm_kanalratte"],
		{"level": 6 if boss else 4, "boss": boss, "threat": true}, "")
	if st.is_empty():
		return false
	var sim: RtSim = st["sim"]
	var hud: Node = st["hud"]
	_rt_regular_state(sim)
	if boss:
		sim.call("set_cast", "e0", "skl_b_rules", 50, 90, true, true)
		sim.unit("p0").target_id = "e1"
	await seconds(1.7)
	_rt_hits(hud, sim)
	await frames(3)
	var with_hud: int = await _rt_canvas_dc(30)
	(hud as CanvasLayer).visible = false
	for c: Node in hud.get_children():
		if c is CanvasLayer:
			(c as CanvasLayer).visible = false
	var without: int = await _rt_canvas_dc(30)
	print("R3 DRAW CALLS %s%s: canvas %d with the combat HUD, %d without it (HUD %d)" % ["boss" if boss else "regular",
		" touch" if bool(hud.call("is_touch")) else "", with_hud, without, with_hud - without])
	(hud as CanvasLayer).visible = true
	for c2: Node in hud.get_children():
		if c2 is CanvasLayer:
			(c2 as CanvasLayer).visible = true
	await frames(2)
	freeze()
	return true


## The HUD on the REAL sim (R1b-I1): RtKit's canned combat (rt_min data: Kai level 6 and Graf Mopsula, two groups —
## two rats, a rat and the test shaman — and the scripted commands of the golden test) played through the director
## double to REAL_TICK, the last second one tick per frame (combat text as it comes): Kai guarding, taunted enemies,
## the Count casting, slot cooldowns and the GCD from the sim. Rigs stand at the sim's positions around a sewer room.
const REAL_TICK: int = 180


func _r_rt_real(scene: Node, variant: String = "") -> bool:
	if not await _explore_ready(scene):
		return false
	if variant == "notch":
		SafeAreaContainer.simulated_insets = RT_NOTCH
		get_tree().root.size_changed.emit()
	var layout: FloorLayout = scene.call("get_layout")
	var spawn: EnemySpawn = null
	for e: EnemySpawn in layout.enemies:
		var rc: RoomCell = layout.cell_at(e.cell)
		if rc != null and rc.zone == "zone_sewer" and not e.is_boss and scene.call("get_enemy", e.id) != null:
			spawn = e
			break
	if spawn == null:
		return false
	_freeze_enemies(scene)
	var actor: Node3D = scene.call("get_enemy", spawn.id) as Node3D
	actor.process_mode = Node.PROCESS_MODE_DISABLED
	actor.global_position += Vector3(0, -60, 0)
	_reveal_zone(scene, layout, "zone_sewer")
	var seen: Dictionary = {}
	for id: String in RtVocab.HINT_IDS:
		seen[id] = true
	Game.state.flags["rt_hints"] = seen
	Game.state.show.stats["taunts_total"] = 1
	var center: Vector3 = layout.cell_to_world(spawn.cell)
	center.y = 0.0
	var sim: RtSim = RtSim.new(RtKit.setup(RtKit.canned_state(), RtKit.canned_encounter()), RtKit.data())
	var dir: Node = RtDirector.new()
	dir.name = "RtDirector"
	dir.set("sim", sim)
	dir.set("origin", center)
	dir.set("heights", {"p0": 1.7, "p1": 1.0})
	get_tree().root.add_child(dir)
	var cam_rig: Node3D = scene.call("get_camera_rig") as Node3D
	cam_rig.set("arm_length", 8.0)
	cam_rig.set("_look", 1.0)
	var hud: CanvasLayer = (load(RT_HUD) as PackedScene).instantiate() as CanvasLayer
	hud.call("setup", {"director": dir, "sim": sim, "data": RtKit.data(), "auto_events": false, "modes": true,
		"camera_rig": cam_rig})
	get_tree().root.add_child(hud)
	dir.set("hud", hud)
	for e: ActionEvent in sim.start():
		hud.call("on_event", e)
	var rigs: Dictionary = {}
	_rt_real_place(scene, sim, center, rigs)
	await seconds(1.4)                                         # "KAMPF!" is over
	var cmds: Array[Dictionary] = RtKit.canned_commands()
	var i: int = 0
	while sim.tick() < REAL_TICK and not sim.is_finished():
		while i < cmds.size() and int(cmds[i]["ct"]) <= sim.tick():
			dir.call("submit", cmds[i])
			i += 1
		dir.call("advance", 1)
		if sim.tick() == REAL_TICK - 30:
			_rt_real_place(scene, sim, center, rigs)
			await seconds(1.3)                                 # the burst of the fast-forward fades
		elif sim.tick() > REAL_TICK - 30:
			_rt_real_place(scene, sim, center, rigs)
			await frames(1)
	await frames(3)
	freeze()
	return true


## Player body, companion and one rig per living enemy at the sim's positions (origin + cm / 100); the camera behind
## the controlled unit, looking at the enemies' centre.
func _rt_real_place(scene: Node, sim: RtSim, origin: Vector3, rigs: Dictionary) -> void:
	var player: Node3D = scene.call("get_player") as Node3D
	var comp: Node3D = scene.call("get_companion") as Node3D
	var ctl: RtUnit = sim.unit(sim.controlled_id())
	if ctl == null:
		return
	var me: Vector3 = origin + Vector3(float(ctl.x) / 100.0, 0.0, float(ctl.z) / 100.0)
	var foes: Vector3 = Vector3.ZERO
	var n: int = 0
	for u: RtUnit in sim.units():
		var pos: Vector3 = origin + Vector3(float(u.x) / 100.0, 0.0, float(u.z) / 100.0)
		if u.side == Combatant.Side.ENEMY:
			var alive: bool = u.hp > 0 and not u.left_battle
			if alive:
				foes += pos
				n += 1
			if not rigs.has(u.id):
				var rig: Node3D = CharacterBuilder.build(RtKit.data().enemy(u.def_id).model, rigs.size())
				scene.add_child(rig)
				rigs[u.id] = rig
			var r: Node3D = rigs[u.id]
			r.visible = alive
			r.global_position = pos
			if pos.distance_to(me) > 0.05:
				r.look_at(Vector3(me.x, pos.y, me.z), Vector3.UP, true)
		elif u.id != ctl.id and comp != null:
			comp.process_mode = Node.PROCESS_MODE_DISABLED
			comp.global_position = Vector3(pos.x, comp.global_position.y, pos.z)
	var to: Vector3 = (foes / float(maxi(1, n))) - me if n > 0 else Vector3(0, 0, -1)
	var yaw: float = atan2(-to.x, -to.z)
	player.call("teleport", Vector3(me.x, 0.05, me.z), yaw)
	if comp != null:
		comp.rotation.y = yaw
	scene.call("get_camera_rig").call("snap", yaw)


## Maximum canvas draw calls of the root viewport over `n` frames.
func _rt_canvas_dc(n: int) -> int:
	var best: int = 0
	var vp: RID = get_tree().root.get_viewport_rid()
	for i in n:
		await RenderingServer.frame_post_draw
		best = maxi(best, RenderingServer.viewport_get_render_info(vp,
			RenderingServer.VIEWPORT_RENDER_INFO_TYPE_CANVAS, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME))
	return best


## Exploration + a bound CombatHud: Kai (or the Count) 5.5 m (opts "dist") in front of a group of `zone_key`, the
## group's actor replaced by one rig per enemy unit in a fan, the director double with their positions. {} on failure,
## else {"sim", "hud", "director", "rigs", "positions"}.
func _rt_stage(scene: Node, zone_key: String, enemy_ids: Array, opts: Dictionary, variant: String) -> Dictionary:
	if not await _explore_ready(scene):
		return {}
	if variant == "notch":
		SafeAreaContainer.simulated_insets = RT_NOTCH
		get_tree().root.size_changed.emit()
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
		return {}
	_freeze_enemies(scene)
	var actor: Node3D = scene.call("get_enemy", spawn.id) as Node3D
	var center: Vector3 = actor.global_position
	actor.process_mode = Node.PROCESS_MODE_DISABLED           # the rigs below stand in for its group
	actor.global_position = center + Vector3(0, -60, 0)
	_reveal_zone(scene, layout, zone)
	var seen: Dictionary = {}
	for id: String in RtVocab.HINT_IDS:
		if not (opts.get("unseen", []) as Array).has(id):
			seen[id] = true                       # first-time cards already seen (the tutorial steps stay)
	Game.state.flags["rt_hints"] = seen
	if bool(opts.get("threat", false)):
		Game.state.show.stats["taunts_total"] = 1    # threat dots + aggro counters unlocked (07 §8.1)
	if str(opts.get("hero", "kai")) == "mopsula":
		Game.state.hero = "mopsula"
		scene.call("refresh_hero")
	_place_facing(scene, layout, spawn.cell, center, float(opts.get("dist", 5.5)))
	var cam_rig: Node3D = scene.call("get_camera_rig") as Node3D
	cam_rig.set("arm_length", 9.0 if bool(opts.get("boss", false)) else 8.0)   # 07 §7.5 combat zoom
	cam_rig.set("_look", 1.0)                                                   # LOOK_AHEAD 2.5 → 1.0
	await frames(10)
	var data: GameData = DB.data
	var sim: RtSim = RtScenarios.build(data, {"level": int(opts.get("level", 1)), "enemies": enemy_ids,
		"tutorial": bool(opts.get("tutorial", false)), "boss": bool(opts.get("boss", false)),
		"hero": str(opts.get("hero", "kai")), "encounter": str(opts.get("encounter", "enc_rt_capture"))})
	for m: PartyMember in Game.state.party:
		m.level = int(opts.get("level", 1))
		m.exp = Progression.exp_to_next(m.level) * 2 / 5
		var c: Combatant = Progression.to_combatant(m, data, "x", 0)
		m.hp = c.max_hp() if c != null else m.hp
		m.mp = c.max_mp() if c != null else m.mp
	Events.party_changed.emit()
	var player: Node3D = scene.call("get_player") as Node3D
	var comp: Node3D = scene.call("get_companion") as Node3D
	var ppos: Vector3 = player.global_position
	var fwd: Vector3 = (center - ppos)
	fwd.y = 0.0
	fwd = fwd.normalized()
	var side: Vector3 = fwd.cross(Vector3.UP).normalized()
	comp.process_mode = Node.PROCESS_MODE_DISABLED       # side by side for the still (R2 places the real puppets)
	comp.global_position = ppos - side * 1.6 + fwd * 0.5
	comp.rotation.y = player.rotation.y
	var positions: Dictionary = {}
	var heights: Dictionary = {}
	var ctl_id: String = sim.controlled_id()
	for u: RtUnit in sim.units():
		if u.side == Combatant.Side.PARTY:
			positions[u.id] = ppos if u.id == ctl_id else comp.global_position
			heights[u.id] = 1.7 if u.def_id == "kai" else 1.0
	var rigs: Array = []
	var n: int = enemy_ids.size()
	for i in n:
		var def: EnemyDef = data.enemy(str(enemy_ids[i]))
		var rig: Node3D = CharacterBuilder.build(def.model, i)
		scene.add_child(rig)
		var lateral: float = (float(i) - float(n - 1) * 0.5) * 1.9
		var depth: float = 0.0 if i == 0 else 0.7
		var pos: Vector3 = center + side * lateral + fwd * depth
		pos.y = 0.0
		rig.global_position = pos
		rig.look_at(Vector3(ppos.x, pos.y, ppos.z), Vector3.UP, true)
		positions["e%d" % i] = pos
		heights["e%d" % i] = float(rig.get("height")) * rig.scale.y if "height" in rig else 1.0
		rigs.append(rig)
	var dir: Node = RtDirector.new()
	dir.name = "RtDirector"
	dir.set("sim", sim)
	dir.set("positions", positions)
	dir.set("heights", heights)
	get_tree().root.add_child(dir)
	var hud: CanvasLayer = (load(RT_HUD) as PackedScene).instantiate() as CanvasLayer
	hud.call("setup", {"director": dir, "sim": sim, "data": data, "auto_events": false, "modes": true,
		"camera_rig": scene.call("get_camera_rig")})
	get_tree().root.add_child(hud)
	dir.set("hud", hud)
	var ctl: RtUnit = sim.unit(ctl_id)
	if not bool(opts.get("tutorial", false)):
		ctl.target_id = "e0"
	await frames(4)
	return {"sim": sim, "hud": hud, "director": dir, "rigs": rigs, "positions": {"p0": ppos}}


## Mid-fight state of the regular still (level 4).
func _rt_regular_state(sim: RtSim) -> void:
	var p0: RtUnit = sim.unit("p0")
	var p1: RtUnit = sim.unit("p1")
	p0.hp = p0.max_hp() * 72 / 100
	p0.mp = 7
	p1.hp = p1.max_hp() * 46 / 100
	p1.mp = p1.max_mp() * 60 / 100
	sim.unit("e0").hp = sim.unit("e0").max_hp() * 64 / 100
	sim.unit("e1").hp = sim.unit("e1").max_hp() * 35 / 100
	sim.unit("e0").target_id = "p1"
	sim.unit("e1").target_id = "p0"
	sim.unit("e2").target_id = "p0"
	sim.call("set_tick", 900)
	sim.call("set_cd", "p0", "skl_kai_leash_trip", 150, 360)
	sim.call("set_cd", "p0", "skl_kai_sweep", 70, 240)
	sim.call("set_cd", "p0", "skl_kai_taunt", 0, 0)
	sim.set("gcds", {"p0": Vector2i(20, 45)})
	sim.set("items_count", 2)
	p0.queued = {"skill": "skl_kai_heavy_swing", "target": "e0", "at": 899}
	sim.call("set_reason", "p0", "skl_kai_sweep", "mp")
	sim.call("set_cast", "e0", "skl_e_zap", 25, 60, false, true)
	var data: GameData = DB.data
	RtScenarios.add_status(sim, data, p0, "sts_guard", 110, 180)
	RtScenarios.add_status(sim, data, p1, "sts_poison", 140, 180, 2)
	RtScenarios.add_status(sim, data, sim.unit("e1"), "sts_slow", 60, 120)


## Combat text of the regular still: a crit on the target, a hit on Kai, a heal.
func _rt_hits(hud: Node, sim: RtSim) -> void:
	var d: ActionEvent = ActionEvent.make(ActionEvent.Type.DAMAGE)
	d.actor_id = "p0"
	d.target_id = "e0"
	d.amount = 96
	d.crit = true
	d.command = BattleCommand.Kind.SKILL
	hud.call("on_event", d)
	var t: ActionEvent = ActionEvent.make(ActionEvent.Type.DAMAGE)
	t.actor_id = "e1"
	t.target_id = "p0"
	t.amount = 14
	hud.call("on_event", t)
	var h: ActionEvent = ActionEvent.make(ActionEvent.Type.HEAL)
	h.actor_id = "p1"
	h.target_id = "p1"
	h.amount = 38
	hud.call("on_event", h)


## rt blocks the boss stills need until R4 writes them (phases, enrage at 3:00) — capture process only.
func _rt_boss_data() -> void:
	if not DB.has_id("enemies", "enm_boss_hausmeister"):
		return
	var def: EnemyDef = DB.enemy("enm_boss_hausmeister")
	if def.rt.is_empty():
		def.rt = {"phases": [{"hp_above_pm": 650}, {"hp_above_pm": 300}, {"hp_above_pm": 0}],
			"enrage": {"at_ms": 180000, "every_ms": 10000, "status": "sts_enrage"}}
	if DB.has_id("skills", "skl_b_rules"):
		var sk: SkillDef = DB.skill("skl_b_rules")
		if sk.rt.is_empty():
			sk.rt = {"icon": "whistle", "cast_ms": 3000, "interruptible": true, "interrupt_worthy": true}


## Stand-in for R2's TelegraphLayer: a flat red circle (07 §8.7 colours) at `at` with radius `r`.
func _rt_telegraph(scene: Node, at: Vector3, r: float) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = r
	cyl.bottom_radius = r
	cyl.height = 0.02
	cyl.radial_segments = 48
	mi.mesh = cyl
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.3, 0.3, 0.42)
	mi.material_override = mat
	scene.add_child(mi)
	mi.global_position = Vector3(at.x, 0.05, at.z)
	var ring: MeshInstance3D = MeshInstance3D.new()
	var tor: TorusMesh = TorusMesh.new()
	tor.inner_radius = r - 0.08
	tor.outer_radius = r
	ring.mesh = tor
	var rmat: StandardMaterial3D = StandardMaterial3D.new()
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rmat.albedo_color = Color(1.0, 0.85, 0.85, 1.0)
	ring.material_override = rmat
	scene.add_child(ring)
	ring.global_position = Vector3(at.x, 0.06, at.z)
	ring.scale = Vector3(1.0, 0.2, 1.0)


# --- 08 K1: the candidate persona ---------------------------------------------------------------------------------

const PersonaCard := preload("res://scenes/ui/persona_card.gd")


func _r_pause_card(scene: Node) -> bool:
	if not await _explore_ready(scene):
		return false
	Game.persona = PersonaCard.demo(DB.data)
	PersonaPrivacy.restore_display(Game.state, Game.persona)
	_freeze_enemies(scene)
	var hud: Node = scene.get("_hud")
	await frames(5)
	if hud == null:
		return false
	var pm: Node = hud.call("open_pause_menu", "party")
	if pm == null:
		return false
	get_tree().paused = true
	await frames(10)
	var party: Node = pm.call("page", "party")
	party.call("refresh")
	await frames(2)
	if party.call("open_card") == null:
		return false
	await frames(5)
	return true


func _r_intro_card(scene: Node) -> bool:
	Game.persona = PersonaCard.demo(DB.data)
	PersonaPrivacy.restore_display(Game.state, Game.persona)
	var lines: Array = scene.call("persona_lines")
	if lines.is_empty():
		return false
	await frames(30)                           # the studio's white flash is over
	scene.call("_show_line", lines[0])
	scene.set("_line_shown", 9999.0)
	(scene.get("_text") as Label).visible_characters = -1
	await frames(2)
	(scene.get("_flash") as ColorRect).color = Color(1, 1, 1, 0)
	freeze()                                   # the lower third stays (its fade-out tween pauses with the intro)
	return true


func _r_casting_accents(scene: Node) -> bool:
	await frames(2)
	var k: Node = scene.get("overlay") as Node
	if k == null or not k.has_method("toggle_accents"):
		return false
	k.call("toggle_accents")
	await frames(3)
	return true
