extends Node
## Capture recipes (02_TECH §11.3): named scripted states for `check.sh --shot … --recipe=<name>` (tests/capture.gd).
## Loaded at runtime after the autoloads are ready, so autoloads and class_names are fine here. Private (no
## class_name). run() is a coroutine returning true on success; the screen is already under root (Router.adopt).
## Recipes drive screens through their public APIs and a few private members (test tool only, never game code).
##
## Exploration (exploration.tscn): explore_platform | explore_sewer | explore_cellar (zone room with an enemy group in
##   view), prompt_platform | prompt_sewer | prompt_cellar (Kai in front of a chest: HUD prompt + marker), bigmap,
##   pause_party | pause_inventory | pause_equipment | pause_skills | pause_show (06-C) | pause_settings.
## Safe room (safe_room.tscn): safe_vending, safe_lootbox, safe_lootbox_open, safe_mopsula, safe_equipment,
##   safe_talents_menu (menu + the gold TALENT-SHOW button), safe_talent_show (the Talent-Show, 06 package B),
##   safe_hero_talents (integration A × B: open choices + "Figur wechseln" → TALENT-SHOW and M.O.D. box side by side).
## Exploration + pause: talents_party (party page with talents and an open choice, 06 package B).
## 06 package A: bark_platform | bark_sewer | bark_cellar (Graf Mopsula leads and barks at a group: cone + rings,
##   "?!"), hero_mopsula_<zone> (exploration as Mopsula, Kai follows), safe_hero_switch ("Figur wechseln" pressed:
##   the Count in front), secret_wall (Kai in front of the Kulissenwand), secret_open (the Count barks it over),
##   secret_note (Kai in front of a Regie-Notiz: prompt + marker).
## 06-D (KI-Admin): twist_lights | twist_confetti | twist_live (exploration with a running twist: chip, vignette /
##   confetti, an M.O.D. live line labelled "KI live"), safe_happy (vending machine during a Happy Hour).
## Polish pass: doorway_approach | doorway_through | doorway_mopapproach | doorway_mopthrough (camera in front of /
##   just past an open door, Kai or Graf Mopsula leading).
## Echtzeitkampf in the world (07, R2; tests/fixtures/rt_world/capture_rt.gd): rt_world_regular (a fight in a room
##   with the LED ring), rt_world_two_groups (two groups on one set), rt_world_boss (Gleis 9 with the train lane
##   telegraph), rt_world_boss_intro (the crane), rt_world_flee (Kai in a door lane). The combat HUD stills of R3
##   (rt_tutorial, rt_regular, rt_boss, …) follow in their own section below.
## Echtzeitkampf with the real data (07, R4; tests/tools/capture_r4.gd): rt_r4_regular (zone
##   C, a telegraph filling up), rt_r4_showboss (the Kanalratten-Gala, E26), rt_r4_hausmeister (key throw line),
##   rt_r4_queen (Gleis 9, phase 2, the train on its track), rt_r4_results (R5b: zone A fought to its end, the results
##   panel with the real rewards).
## 08 K1 (Casting): pause_card (exploration + pause menu, party page, the candidate card of the sample persona open),
##   intro_card (intro.tscn with {"capture": true}: the studio with the candidate's lower third and persona_intro line),
##   casting_accents (persona_casting.tscn with {"open": "keyboard"}: the on-screen keyboard's accent layer).
## 08 K2 (Casting, with capture.gd --look=…): safe_mask (safe room → pause → party → candidate card → "Name & Aussehen
##   ändern": the casting's 1/3 in edit mode over the room), safe_look (the candidate in the room, menu open),
##   rt_world_look (rt_world_regular, the camera behind Kai's puppet).
## Staffeln (09 §8.2–8.4, ST1-D; safe_room.tscn, the run turned into a season standing in the room): season_talent_show
##   (the Talent-Show presents a class row: three cards with their branches), season_talent_tree (pause → Party →
##   "Talentbaum": every row, picks in gold, the open row), season_party (party page: Aufholjagd, the cap, the rows of
##   the tree, the button "Talentbaum"), season_skills (the ability book after the Recall: class abilities on their
##   slots, the ranks), season_preview (before the Recall: the Klassen-Vorschau of the Count).
## The pull of a person (07 §2.2, §7, E34–E37): pull_target_<zone> (Kai 2.2 m in front of a group of the zone, its lead
##   targeted: target frame with the slot chips, ring + chevron, the pull hint "1 · Angriff eröffnen"), pull_bark_<zone>
##   (Graf Mopsula barks at a group that has seen her: dazed, the bark's target, "verdutzt · Erstschlag!"),
##   pull_far_<zone> (Graf Mopsula targets a lead 7 m away: the frame steps aside) — with --touch the action button
##   shows slot 1's symbol instead of the hint.
## Staffeln (09 §3, ST1-C; with capture.gd --season-floor=<n>: a basis season Am Stück on floor n): season_q<k> (Kai
##   6 m in front of a group of quarter k, the quarter revealed), season_qb / season_fb (in front of the Revier-Boss /
##   the Etagenboss on its stage), season_door (in front of a closed programme door: its prompt), season_gate (in front
##   of the key gate before the stairs), season_safe (in front of the safe room door of the first quarter),
##   season_map (the big map, every quarter revealed).
## Staffeln (09 §5, ST1-G): sleep_logout_corridor (exploration.tscn with --season-floor=3: the season as a calendar
##   season Ohne Netz, Kai in a room of the restless quarter, pause → "Ausloggen": the logout dialog with the tactic,
##   the risk line, the Sendepause and the opt-in), sleep_logout_safe (safe_room.tscn: a calendar season standing in
##   the room, the menu's "Ausloggen" — the short path), sleep_wake (wake_summary.tscn: a real night — Mit Netz asleep
##   in a corridor of floor 2 through its collapse: the rescue first, the encounters, the Crashkurs, Ausgeruht, the
##   status, the news), sleep_days (the same night, the page "Tag für Tag"), sleep_question (the clock-jump question).

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


## 07 §2.2, §7 (E34, E37): Kai 2.2 m in front of a group of `zone` (in his slot-1 reach), its lead targeted — the
## target frame below the timer with the pull hint under it, ring and chevron at the lead (touch: the action button).
func _r_pull_target(scene: Node, zone_key: String) -> bool:
	if not await _explore_ready(scene):
		return false
	ExplorationScene.pull_taught = false
	var layout: FloorLayout = scene.call("get_layout")
	var zone: String = str(ZONES.get(zone_key, zone_key))
	var spawn: EnemySpawn = _zone_group(scene, layout, zone)
	if spawn == null:
		return false
	_freeze_enemies(scene)
	_reveal_zone(scene, layout, zone)
	var actor: Node3D = scene.call("get_enemy", spawn.id) as Node3D
	_place_facing(scene, layout, spawn.cell, actor.global_position, 2.2)
	await frames(20)
	if not bool(scene.call("set_pull_target", spawn.id)):
		push_warning("[CaptureRecipes] %s is no pull candidate" % spawn.id)
		return false
	await seconds(0.3)
	return str(scene.call("pull_target")) == spawn.id


## 07 E35: Graf Mopsula 3.4 m in front of a group of `zone` that has seen her (ALERT) barks: the group is dazed, the
## bark picks its lead, the frame says "verdutzt · Erstschlag!" and the hint shows the key that pulls.
func _r_pull_bark(scene: Node, zone_key: String) -> bool:
	ExplorationScene.pull_taught = false
	if not await _r_hero_mopsula(scene, zone_key, 3.4):
		return false
	var layout: FloorLayout = scene.call("get_layout")
	var spawn: EnemySpawn = _zone_group(scene, layout, str(ZONES.get(zone_key, zone_key)))
	var actor: Node3D = scene.call("get_enemy", spawn.id) as Node3D
	var to: Vector3 = (scene.call("get_player_position") as Vector3) - actor.global_position
	actor.call("face", atan2(-to.x, -to.z))                 # it looks at the Count: a pull alone would be NORMAL
	actor.call("_set_state", &"ALERT")
	scene.call("perform_action")
	await seconds(0.25)
	freeze()
	return str(scene.call("pull_target")) == spawn.id


## 07 E34: Graf Mopsula 7 m in front of a group of `zone`, its lead targeted — far away the lead stands high on the
## screen, and the target frame steps aside so it does not hide the lead.
func _r_pull_far(scene: Node, zone_key: String) -> bool:
	ExplorationScene.pull_taught = false
	if not await _r_hero_mopsula(scene, zone_key, 7.0):
		return false
	var spawn: EnemySpawn = _zone_group(scene, scene.call("get_layout"), str(ZONES.get(zone_key, zone_key)))
	if spawn == null or not bool(scene.call("set_pull_target", spawn.id)):
		return false
	await seconds(0.3)
	return str(scene.call("pull_target")) == spawn.id


## The first living non-boss group of `zone` (null + warning if none).
func _zone_group(scene: Node, layout: FloorLayout, zone: String) -> EnemySpawn:
	for e: EnemySpawn in layout.enemies:
		var rc: RoomCell = layout.cell_at(e.cell)
		if rc != null and rc.zone == zone and not e.is_boss and scene.call("get_enemy", e.id) != null:
			return e
	push_warning("[CaptureRecipes] no enemy group in %s" % zone)
	return null


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
	scene.set("auto_start_combat", false)
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
# exploration.tscn + --recipe=rt_r4_regular | rt_r4_showboss | rt_r4_hausmeister | rt_r4_queen |
# rt_r4_results

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


## The run applies the rewards before the results show them: the party frame agrees.
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


# --- 08 K2: the persona look (capture.gd --look=…) -------------------------------------------------------------------

const CharacterGallery := preload("res://art/gallery/character_gallery.gd")


## capture.gd --look=<n | json>: a new game (seed 1, as Game.ensure_state) whose candidate persona wears LOOKS[n] of
## the look gallery or the look object; false for anything else.
func persona_look(arg: String) -> bool:
	var look: Dictionary = {}
	if arg.is_valid_int():
		var i: int = arg.to_int()
		if i < 0 or i >= CharacterGallery.LOOKS.size():
			return false
		look = CharacterGallery.look_ids(i)
	else:
		var parsed: Variant = JSON.parse_string(arg)
		if not (parsed is Dictionary):
			return false
		look = parsed as Dictionary
	var p: PersonaProfile = PersonaProfile.canon(DB.data)
	p.look = PersonaProfile.clean_look(look, DB.data)
	Game.new_game(0, "Kai", 1, &"prime", HeroRules.DEFAULT_HERO, p)
	return Game.persona != null


## The candidate in the safe room in the persona look, the menu open (the M.O.D. box quiet).
func _r_safe_look(scene: Node) -> bool:
	if not await _safe_ready(scene):
		return false
	await _quiet_mod_dialog()
	await frames(10)
	return true


## The mask: safe room → pause → party → candidate card → "Name & Aussehen ändern" (casting 1/3 in edit mode).
func _r_safe_mask(scene: Node) -> bool:
	if not await _safe_ready(scene):
		return false
	await _quiet_mod_dialog()
	var pm: Node = scene.call("open_pause", "party")
	if pm == null:
		return false
	await frames(10)
	var party: Node = pm.call("page", "party")
	party.call("refresh")
	await frames(2)
	var card: Node = party.call("open_card")
	if card == null:
		return false
	await frames(5)
	var editor: Node = card.call("open_editor")
	if editor == null:
		return false
	await frames(30)
	return true


## rt_world_regular with the camera turned to look at Kai's puppet from the front-left (the look in the fight).
func _r_rt_world_look(scene: Node) -> bool:
	if not await _rt(scene, "regular"):
		return false
	var player: Node3D = scene.call("get_player") as Node3D
	var cam: Node = scene.call("get_camera_rig")
	if player == null or cam == null:
		return false
	cam.call("snap", player.rotation.y + PI * 0.8)
	await frames(4)
	return true


# --- Stempelduell (10, SD2) -------------------------------------------------------------------------------------------
## Scenes of scenes/stempel/ get {"capture": true}: the fixed sample collection in memory (sd_session.gd use_sample,
## never saved) and the M.O.D. lines on. Table recipes (sd_table.tscn, --params={"opp": …, "mappe": "a", "seed": …}):
## sd_table — the player's first number: the recommended card marked (ghost tickets, the real number on the card, the
## pale segment on the opponent's bar) and an M.O.D. line in the box; sd_table_touch — the same, run with --touch (fan,
## 170 × 236 cards, 8 tickets); sd_boss_durchsage (opp sdo_meister) — the Graf's suggestions play the duel until the
## Stempelmeister is in phase 2 and the Durchsage stands at the second place (blinking) with its warning in the box;
## sd_results (opp sdo_ferdi) — played to its end, the results panel. sd_deck_builder (sd_deck_builder.tscn,
## --params={"mappe": "b"}) — Mappe B half built with the Aktenschrank's sentence; sd_album (sd_album.tscn,
## --params={"page": "graf"}) — owned cards and outlines with the way there. Review stills: sd_hall (sd_hall.tscn),
## sd_akte (the hall with Ulla's Akte and the Graf's tip), sd_lernduell (sd_table.tscn, --params={"tutorial": true}:
## the first lesson card), sd_menu (the table's menu), sd_bigview (the marked card's big view).

## Waits until the table waits for the player (no events playing, duel running).
func _sd_ready(scene: Node, limit: int = 1500) -> bool:
	return await until(func() -> bool:
		var d: SdDuel = scene.get("duel") as SdDuel
		return d != null and not bool(scene.get("busy")) and not bool(scene.get("finished")) \
			and d.side_to_move() == SdDuel.Side.PLAYER, limit)


## Says `tag` through the table's announcer, typed at once (Game.fast_text: the reading time starts now, so the still
## shows the whole line).
func _sd_line(scene: Node, tag: String) -> void:
	await _quiet_mod_dialog()
	var game: Node = get_tree().root.get_node_or_null("Game")
	if game != null:
		game.set("fast_text", true)
	var host: RefCounted = scene.get("host") as RefCounted
	if host != null:
		host.call("say_now", tag)
	await frames(3)


## Plays the Graf's suggestions with the table's waits off until `cond` holds on the player's number (or the end).
func _sd_play_until(scene: Node, cond: Callable, max_moves: int = 120) -> bool:
	scene.set("instant", true)
	for i in max_moves:
		var d: SdDuel = scene.get("duel") as SdDuel
		if d == null or bool(scene.get("finished")):
			break
		if d.side_to_move() == SdDuel.Side.PLAYER and not bool(scene.get("busy")) and bool(cond.call()):
			scene.set("instant", false)
			return true
		if d.side_to_move() != SdDuel.Side.PLAYER or bool(scene.get("busy")):
			await frames(1)
			continue
		var m: Dictionary = SdAi.suggest(d)
		await scene.call("_submit_player", m)
	scene.set("instant", false)
	return bool(cond.call())


func _r_sd_table(scene: Node) -> bool:
	if not await _sd_ready(scene):
		return false
	await _sd_line(scene, "sd_first_card")
	await seconds(0.3)
	return true


func _r_sd_table_touch(scene: Node) -> bool:
	return await _r_sd_table(scene)


func _r_sd_boss_durchsage(scene: Node) -> bool:
	if not await _sd_ready(scene):
		return false
	var ok: bool = await _sd_play_until(scene, func() -> bool:
		var d: SdDuel = scene.get("duel") as SdDuel
		var foe: Combatant = d.combatant(SdDuel.Side.OPPONENT)
		var order: PackedStringArray = d.order()
		return foe != null and foe.phase >= 1 and order.size() > 1 and order[1].begins_with("u"))
	if not ok:
		push_warning("[CaptureRecipes] sd_boss_durchsage: no Durchsage at the second place (another seed?)")
		return false
	scene.call("_player_turn")
	await _sd_line(scene, "sd_durchsage_warn")
	await seconds(0.6)
	return true


func _r_sd_results(scene: Node) -> bool:
	if not await _sd_ready(scene):
		return false
	await _sd_play_until(scene, func() -> bool: return false, 200)
	return await until(func() -> bool: return scene.get("results") != null, 300)


func _r_sd_deck_builder(scene: Node) -> bool:
	await frames(6)
	var tiles: Dictionary = scene.get("tiles")
	if tiles.has("sdc_frostniesen"):
		(tiles["sdc_frostniesen"] as Control).grab_focus()
	await frames(4)
	return true


func _r_sd_album(scene: Node) -> bool:
	await frames(6)
	var items: Array = scene.get("items")
	if not items.is_empty():
		(items[0] as Control).grab_focus()
	await frames(4)
	return true


func _r_sd_hall(scene: Node) -> bool:
	await frames(10)
	return true


func _r_sd_akte(scene: Node) -> bool:
	await frames(6)
	scene.call("open_akte", "sdo_ulla")
	return await until(func() -> bool: return scene.get("modal") != null, 120)


func _r_sd_lernduell(scene: Node) -> bool:
	var ok: bool = await until(func() -> bool:
		var m: Variant = scene.get("modal")
		return m != null and is_instance_valid(m) and str((m as Node).name).begins_with("Lesson"), 1500)
	await seconds(0.4)
	return ok


func _r_sd_menu(scene: Node) -> bool:
	if not await _sd_ready(scene):
		return false
	scene.call("open_menu")
	await seconds(0.4)
	return scene.get("modal") != null


func _r_sd_bigview(scene: Node) -> bool:
	if not await _sd_ready(scene):
		return false
	scene.call("open_big_view", int((scene.get("hand") as Node).get("marked_slot")))
	await seconds(0.4)
	return scene.get("modal") != null


# --- Staffeln (09 §3, ST1-C): the floors of the basis season ----------------------------------------------------------

## capture.gd --season-floor=<n>: a basis season (Am Stück, seed 1, a fixed start) taken down the stairs to floor `n`
## (Game.season_debug_descend); false when it does not get there.
func season_floor(n: int) -> bool:
	if not Game.start_season(0, "ssn_basis", {"tempo": "binge", "seed": 1, "unlock": true, "now": SEASON_NOW}):
		return false
	while Game.state.floor_run.index < n:
		if not Game.season_debug_descend():
			return false
	return Game.state.floor_run.index == n


func _r_season(scene: Node, what: String) -> bool:
	if not await _explore_ready(scene):
		return false
	var layout: FloorLayout = scene.call("get_layout")
	_freeze_enemies(scene)
	if what.begins_with("q") and what.substr(1).is_valid_int():
		var zone: String = _season_zone(layout, what.substr(1).to_int())
		for e: EnemySpawn in layout.enemies:
			var rc: RoomCell = layout.cell_at(e.cell)
			if rc != null and rc.zone == zone and not e.is_boss and scene.call("get_enemy", e.id) != null:
				_reveal_zone(scene, layout, zone)
				_place_facing(scene, layout, e.cell, (scene.call("get_enemy", e.id) as Node3D).global_position, 6.0)
				await frames(20)
				await _quiet_mod_queue()
				return true
		push_warning("[CaptureRecipes] no group in quarter %s" % zone)
		return false
	match what:
		"qb", "fb":
			var cell: Vector2i = layout.quarter_boss if what == "qb" else layout.floor_boss
			for e: EnemySpawn in layout.enemies:
				if e.is_boss and e.cell == cell and scene.call("get_enemy", e.id) != null:
					_reveal_zone(scene, layout, layout.cell_at(cell).zone)
					_place_facing(scene, layout, cell, (scene.call("get_enemy", e.id) as Node3D).global_position, 7.0)
					await frames(20)
					await _quiet_mod_queue()
					return true
			return false
		"door", "gate":
			var key: String = ""
			for g: Dictionary in layout.gates:          # a closed one, a room without a group in front first
				var programme: bool = ZoneGenerator.programme_number(str(g["requires"])) > 0
				if (what == "door") != programme or Game.state.floor_run.opened_gates.has(str(g["key"])):
					continue
				var busy: bool = false
				for e: EnemySpawn in layout.enemies:
					busy = busy or e.cell == (g["cell"] as Vector2i)
				if key == "" or not busy:
					key = str(g["key"])
				if not busy:
					break
			var gate: Node3D = (scene.get("_gates") as Dictionary).get(key) as Node3D
			if gate == null:
				return false
			var gc: Vector2i = layout.gate_by_key(key)["cell"]
			_reveal_zone(scene, layout, layout.cell_at(gc).zone)
			var inward: Vector3 = layout.cell_to_world(gc) - gate.global_position     # 1.4 m in front of the gate
			inward.y = 0.0
			var spot: Vector3 = gate.global_position + inward.normalized() * 1.4
			var to: Vector3 = gate.global_position - spot
			var yaw: float = atan2(-to.x, -to.z)
			(scene.call("get_player") as Node).call("teleport", Vector3(spot.x, 0.05, spot.z), yaw)
			(scene.call("get_camera_rig") as Node).call("snap", yaw)
			(scene.call("get_companion") as Node).call("snap_behind")
			scene.call("_update_room", true)
			await frames(30)
			await _quiet_mod_queue()
			return true
		"safe":
			var sc: Vector2i = layout.safe_rooms[0]
			_reveal_zone(scene, layout, layout.cell_at(sc).zone)
			_place_facing(scene, layout, sc, layout.cell_to_world(sc), 4.0)
			await frames(30)
			await _quiet_mod_queue()
			return true
		"map":
			for zid: Variant in layout.zones.keys():
				_reveal_zone(scene, layout, str(zid))
			var hud: Node = scene.get("_hud")
			await frames(5)
			return hud != null and hud.call("open_big_map") != null
	push_warning("[CaptureRecipes] unknown season view '%s'" % what)
	return false


## The M.O.D. box after the descents of --season-floor: the lines of every stairs and level-up queue up (ST1-D adds the
## season's EXP lines), the floor start and M.O.D.'s preferences of the day follow one per explore tick (Show) — every
## line ended until Show has none left to say (at most ≈ 5 s; _quiet_mod_dialog ends at most 16 lines per call).
func _quiet_mod_queue() -> void:
	for i in 60:
		await _quiet_mod_dialog()
		var queue: Variant = Show.get("_announce_queue")
		if not bool(Show.get("_floor_start_pending")) and (queue == null or queue.size() == 0):
			break
		await frames(5)
	for i in 4:
		await _quiet_mod_dialog()


## The id of quarter `order` (0 = the first) of a generator-v2 layout; "" if none.
static func _season_zone(layout: FloorLayout, order: int) -> String:
	for zid: Variant in layout.zones.keys():
		if int((layout.zones[zid] as Dictionary).get("order", -1)) == order:
			return str(zid)
	return ""


# --- Staffeln (09 §8.2–8.4, ST1-D): levels, the ability book, the talent tree ------------------------------------

const SEASON_NOW: int = 1791918000            # one hour before day 0 of the test seasons (Kit.START)


## The run becomes a season (Game.start_season, seed 7) standing in this safe room; the run says floor `floor` (its
## band of 09 §2.4 — the rooms stay floor 1's: a still only). Kai and the Count at `levels`, of `classes` ("" = before
## the Recall), with the left talent of every reached row in `picks` (the class rows of Kai's class: as `class_col`).
func _season_party(scene: Node, floor: int, levels: Array, classes: Array, picks: Array, class_col: int = 0) -> bool:
	var room: String = str(scene.get("safe_room_id"))
	if not Game.start_season(0, "ssn_basis", {"now": SEASON_NOW, "tz_sec": 0, "seed": 7}):
		return false
	Game.enter_safe_room(room)
	Game.state.floor_run.index = floor
	var ids: Array = ["kai", "mopsula"]
	for i in ids.size():
		var m: PartyMember = Game.state.member(str(ids[i]))
		m.level = int(levels[i])
		m.class_id = str(classes[i])
		m.exp = LevelBand.exp_to_next(Game.state, DB.data, m.level) * 2 / 5
		for row: int in picks:
			var three: Array[TalentDef] = TalentTree.row_talents(DB.data, m, row)
			if row <= m.level and three.size() == 3:
				var col: int = class_col if TalentDef.CLASS_ROWS.has(row) else 0
				m.talent_rows[str(row)] = three[col].id
	Progression.full_heal(Game.state, DB.data)
	Events.party_changed.emit()
	await frames(5)
	await _quiet_mod_dialog()
	return true


## The Talent-Show of a season: Kai's class row 25 (Abrissbirne: Bollwerk · Show · Abrissunternehmen) is open.
func _r_season_talent_show(scene: Node) -> bool:
	if not await _safe_ready(scene):
		return false
	if not await _season_party(scene, 8, [25, 25], ["cls_kai_wrecker", "cls_mop_physician"], [3, 5, 7, 9, 15, 20]):
		return false
	scene.call("open_talent_show")
	await frames(40)
	await _quiet_mod_dialog()
	return true


## Pause → Party → "Talentbaum" in the safe room: Kai's tree with the picks so far and the open row 25.
func _r_season_talent_tree(scene: Node) -> bool:
	if not await _safe_ready(scene):
		return false
	if not await _season_party(scene, 8, [27, 25], ["cls_kai_wrecker", "cls_mop_physician"], [3, 5, 7, 9, 15, 20]):
		return false
	var pm: Node = scene.call("open_pause", "party")
	if pm == null:
		return false
	get_tree().paused = true
	await frames(10)
	var party: Node = pm.call("page", "party")
	if party.call("open_tree", "kai") == null:
		return false
	await frames(20)
	await _quiet_mod_dialog()
	return true


## The party page of a season on floor 4 (band 13–16): Kai at 12 (Aufholjagd × 2, rested EXP), the Count at the cap.
func _r_season_party(scene: Node) -> bool:
	if not await _safe_ready(scene):
		return false
	if not await _season_party(scene, 4, [12, 16], ["", "cls_mop_physician"], [3, 5, 7, 9, 15]):
		return false
	Game.state.member("kai").rested = 120
	var pm: Node = scene.call("open_pause", "party")
	if pm == null:
		return false
	get_tree().paused = true
	await frames(20)
	await _quiet_mod_dialog()
	return true


## The ability book after the Recall: Kai (Abrissbirne, 27) with the signature on slot 1 and Schnellbeton on slot 3.
func _r_season_skills(scene: Node) -> bool:
	if not await _safe_ready(scene):
		return false
	if not await _season_party(scene, 9, [27, 27], ["cls_kai_wrecker", "cls_mop_physician"], [3, 5, 7, 9, 15, 20, 25]):
		return false
	Game.apply_loadout(RunRules.loadout_cmd("kai", {"1": "skl_kai_wrecking_ball", "3": "skl_kai_quick_concrete"}))
	var pm: Node = scene.call("open_pause", "skills")
	if pm == null:
		return false
	get_tree().paused = true
	await frames(20)
	await _quiet_mod_dialog()
	return true


## Before the Recall: the Count's Klassen-Vorschau (all four classes, their abilities and levels).
func _r_season_preview(scene: Node) -> bool:
	if not await _safe_ready(scene):
		return false
	if not await _season_party(scene, 2, [8, 8], ["", ""], [3, 5, 7]):
		return false
	var pm: Node = scene.call("open_pause", "skills")
	if pm == null:
		return false
	get_tree().paused = true
	await frames(10)
	var page: Node = pm.call("page", "skills")
	page.call("select_member", "mopsula")
	page.call("show_view", "preview")
	await frames(20)
	await _quiet_mod_dialog()
	return true


# --- Staffeln (09 §5, ST1-G): the sleeper — the logout dialog and the login summary -----------------------------------

## sleep_logout_<where>: corridor (exploration.tscn, --season-floor=3) | safe (safe_room.tscn).
func _r_sleep_logout(scene: Node, where: String) -> bool:
	if where == "safe":
		var room: String = str(scene.get("safe_room_id"))
		if not Game.start_season(0, "ssn_basis", {"now": SEASON_NOW, "tz_sec": 0, "seed": 7, "mode": "no_net",
				"unlock": true}):
			return false
		Game.enter_safe_room(room)
		scene.call("_refresh_menu_labels")
		await frames(5)
		await _quiet_mod_dialog()
		return scene.call("open_save") != null and await _settle(10)
	if not await _explore_ready(scene):
		return false
	_freeze_enemies(scene)
	var s: SeasonState = Game.state.season
	s.tempo = "calendar"                         # the --season-floor season runs Am Stück: the logout of a calendar one
	s.mode = "no_net"
	var layout: FloorLayout = scene.call("get_layout")
	var def: FloorDef = DB.floor_def(Game.state.floor_run.index)
	var cell: Vector2i = SleepResolver.NO_CELL
	var reach: Dictionary = layout.distances(layout.start, Game.state.floor_run.opened_gates)   # no closed door between
	for c: Vector2i in layout.sorted_cells():
		var busy: bool = false
		for e: EnemySpawn in layout.enemies:
			busy = busy or e.cell == c
		if not busy and reach.has(c) and SleepResolver.danger_of(def, layout, c) == 1 and cell == SleepResolver.NO_CELL:
			cell = c
	if cell == SleepResolver.NO_CELL:
		return false
	_reveal_zone(scene, layout, layout.cell_at(cell).zone)
	_place_facing(scene, layout, cell, layout.cell_to_world(cell) + Vector3(2.0, 0.0, 2.0), 2.5)
	scene.call("_update_room", true)
	await frames(20)
	await _quiet_mod_queue()
	var hud: Node = scene.get("_hud")
	var pm: Node = hud.call("open_pause_menu", "party") if hud != null else null
	if pm == null:
		return false
	get_tree().paused = true
	await frames(5)
	return pm.call("ask_to_title") != null and await _settle(12)


## sleep_wake | sleep_days | sleep_question (wake_summary.tscn).
func _r_sleep(scene: Node, what: String) -> bool:
	if what == "question":
		scene.set("wake", {"question": 23 * 86400})
		scene.call("rebuild")
		return await _settle(8)
	if not Game.start_season(0, "ssn_basis", {"now": SEASON_NOW, "tz_sec": 0, "seed": 5, "mode": "net"}):
		return false
	if not Game.season_debug_descend():          # floor 2 (calendar: floors 1–3 are open from the start)
		return false
	var st: GameState = Game.state
	for m: PartyMember in st.party:
		m.level = 7
	st.inventory.credits = 840
	st.inventory.counts = {"itm_bandage": 3, "itm_antidote": 1, "itm_brutzel_burger": 2}
	Progression.full_heal(st, DB.data)
	var layout: FloorLayout = SleepResolver.layout_of(st, DB.data)
	var cell: Vector2i = SleepResolver.NO_CELL
	for c: Vector2i in layout.sorted_cells():
		if SleepResolver.danger_of(DB.floor_def(2), layout, c) == 0 and cell == SleepResolver.NO_CELL:
			cell = c
	Game.settings.daily_summary = true
	if not Game.season_logout("careful", cell):
		return false
	var ro: bool = Save.read_only
	Save.read_only = true
	Game.season_live_clock = true
	st.season.seen_unix = int(Time.get_unix_time_from_system()) - (st.season.collapse_utc[1] - st.season.utc
		+ 7 * 3600)                              # through the collapse of floor 2, seven hours after it
	Game.season_login()
	Game.season_live_clock = false
	Save.read_only = ro
	if Game.season_wake.is_empty():
		return false
	scene.set("wake", Game.season_wake.duplicate(true))
	scene.call("rebuild")
	await _settle(8)
	if what == "days":
		scene.call("show_days")
		await _settle(8)
	return true


## Waits `n` frames, ends M.O.D.'s box and the toasts of the setup (a descent's level-ups); true.
func _settle(n: int) -> bool:
	await frames(n)
	await _quiet_mod_dialog()
	var ui: Node = get_tree().root.get_node_or_null("GlobalUi")
	var toasts: Node = ui.get("toasts") as Node if ui != null else null
	var list: Node = toasts.get("_list") as Node if toasts != null else null
	if list != null:
		for c: Node in list.get_children():
			c.queue_free()
	await frames(2)
	return true
