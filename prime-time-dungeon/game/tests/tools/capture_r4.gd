extends RefCounted
## R4 capture recipes (07 §12.5): real-time combats of floor 1 with the REAL data and the real RtSim in the world —
## `check.sh --shot res://scenes/exploration/exploration.tscn <png> 30 1280x720 --recipe=rt_r4_<name>` (the campaign
## fights in real time only since R5b part 2b; add --touch for the phone layout). Private test helper (no class_name);
## tests/capture_recipes.gd forwards rt_r4_regular | rt_r4_showboss | rt_r4_hausmeister | rt_r4_queen | rt_r4_results
## (R5b) to run(). `rec` is the CaptureRecipes runner.
## The party gets the level and gear the balance harness gives that point of the floor (tests/tools/rt_harness.gd
## PLAN / GEAR), Kai plays on autopilot (the sim's own AI), the director is stepped tick by tick until the moment of
## the still: a telegraph filling up (regular: the cable salad's short circuit or the sprayer's fumes), the first
## ticket of the Kanalratten-Gala, the Hausmeister's key throw line, the queen's train on Gleis 9a / 9b in phase 2.

const Harness := preload("res://tests/tools/rt_harness.gd")
const Rules := preload("res://scenes/exploration/encounter_rules.gd")

var rec: Node = null


func run(which: String, scene: Node) -> bool:
	if not await rec.call("_explore_ready", scene):
		return false
	scene.set("auto_start_combat", true)
	Game.settings.combat_hints = false               # R3's first-time cards would hold the ticks (07 §2.13)
	match which:
		"regular":
			return await _regular(scene)
		"showboss":
			return await _showboss(scene)
		"hausmeister":
			return await _boss(scene, "f1_qb", "skl_b_keys", 0)
		"queen":
			return await _boss(scene, "f1_fb", "skl_q_train", 1)
		"results":
			return await _results(scene)
	push_warning("[CaptureR4] unknown recipe rt_r4_%s" % which)
	return false


## Zone C, room (6, 0): the sprayer and the cable salad (enc_f1_c2, level 5) — the still at the first telegraph half
## way to its impact.
func _regular(scene: Node) -> bool:
	_party("enc_f1_c2")
	if not await _start(scene, "f1_g10", 3.5, Rules.NORMAL):
		return false
	return await _until_telegraph(scene, "", -1, 1200)


## Zone B, room (5, 4): the Kanalratten-Gala (enc_e1_showboss, level 3, real-time runs only) — elite shaman and rats,
## the still right after the first ticket (4 s) with the show banner and the slowed Kai.
func _showboss(scene: Node) -> bool:
	_party("enc_e1_showboss")
	var actor: Node3D = scene.call("get_enemy", "f1_g15") as Node3D
	if actor == null:                                # the run was CTB when the floor was built: spawn the group now
		var spawn: EnemySpawn = (scene.call("get_layout") as FloorLayout).enemy_by_id("f1_g15")
		if spawn != null:
			scene.call("_spawn_enemy", spawn)
	if not await _start(scene, "f1_g15", 3.5, Rules.NORMAL):
		return false
	var d: Node = scene.call("get_director") as Node
	for i in 400:
		d.call("advance", 1)
		if Game.combat == null:
			return false
		if Game.combat.tick() >= 150:
			break
	await rec.call("_quiet_mod_dialog")
	await rec.call("frames", 6)
	rec.call("freeze")
	return true


## R5b: zone A, room (1, 4): the first group after the tutorial (enc_f1_a2, level 2) fought to its end on autopilot —
## the still of R3's results panel with the real rewards (EXP, credits, drops, level-ups) over the room.
func _results(scene: Node) -> bool:
	_party("enc_f1_a2")
	if not await _start(scene, "f1_g1", 3.5, Rules.NORMAL):
		return false
	var d: Node = scene.call("get_director") as Node
	for i in 3600:
		if Game.combat == null or Game.combat.is_finished():
			break
		d.call("advance", 1)
		if i % 300 == 299:
			await rec.call("frames", 1)
	if not await rec.call("until", func() -> bool: return d.get_node_or_null("CombatResults") != null, 600):
		push_warning("[CaptureR4] no results panel")
		return false
	# after the 2 s grace blink (Kai visible again), within the lower third's 3 s hold; the still keeps the lower third
	await rec.call("seconds", 2.2)
	await rec.call("_quiet_mod_dialog")
	(d.get_node("CombatResults") as Node).process_mode = Node.PROCESS_MODE_PAUSABLE
	rec.call("freeze")
	return true


## A boss with its intro (crane, closed ring), then Kai on autopilot until `phase` (0-based) and the first telegraph
## of `skill` half way to its impact. The queen needs phase 2 (65 %): the director runs the fight up to it.
func _boss(scene: Node, group: String, skill: String, phase: int) -> bool:
	var enc_id: String = "enc_f1_boss_hausmeister" if group == "f1_qb" else "enc_f1_boss_rattenkoenigin"
	_party(enc_id)
	var boss: Node3D = scene.call("get_enemy", group) as Node3D
	if boss == null:
		return false
	var player: Node3D = scene.call("get_player") as Node3D
	var layout: FloorLayout = scene.call("get_layout")
	var room: Vector3 = layout.cell_to_world(layout.world_to_cell(boss.global_position))
	# in front of the only door (Hausmeister W, queen E), 4.4 m from the boss spot: the boss trigger (5 m) fires
	var side: float = -1.0 if group == "f1_qb" else 1.0
	var spot: Vector3 = room + Vector3(4.4 * side, 0.05, 0.6)
	var to: Vector3 = boss.global_position - spot
	player.call("teleport", spot, atan2(-to.x, -to.z))
	scene.call("get_camera_rig").call("snap", atan2(-to.x, -to.z))
	scene.call("get_companion").call("snap_behind")
	scene.call("_update_room", true)
	var d: Node = scene.call("get_director") as Node
	_manual(scene)
	if not await rec.call("until", func() -> bool: return d != null and bool(d.call("is_busy")), 300):
		push_warning("[CaptureR4] the boss intro did not start")
		return false
	await rec.call("seconds", 2.7)
	await rec.call("_quiet_mod_dialog")
	if not await rec.call("until", func() -> bool: return Game.combat != null, 900):
		push_warning("[CaptureR4] the boss combat did not start")
		return false
	await rec.call("_quiet_mod_dialog")
	await _banner_done(scene)
	_autopilot(scene)
	return await _until_telegraph(scene, skill, phase, 9000)


## The party of the harness plan for `enc_id` (level, gear; talents need a safe room and stay open), full HP / MP.
func _party(enc_id: String) -> void:
	var plan: Array = Harness.PLAN[enc_id]
	for m: PartyMember in Game.state.party:
		Harness.level_to(m, DB.data, int(plan[0]))
		var g: Array = (Harness.GEAR[str(plan[1])] as Dictionary)[m.id]
		m.equipment = {"weapon": str(g[0]), "armor": str(g[1]), "accessory": str(g[2])}
	for iid: String in (Harness.ITEMS[str(plan[2])] as Dictionary):
		Game.state.inventory.add(iid, int((Harness.ITEMS[str(plan[2])] as Dictionary)[iid]), 9)
	Progression.full_heal(Game.state, DB.data)


## Kai `dist` m in front of the lead of `group_id`, the combat starts with `adv`, Kai on autopilot.
func _start(scene: Node, group_id: String, dist: float, adv: int) -> bool:
	var actor: Node3D = scene.call("get_enemy", group_id) as Node3D
	if actor == null:
		push_warning("[CaptureR4] no group %s" % group_id)
		return false
	var layout: FloorLayout = scene.call("get_layout")
	var center: Vector3 = layout.cell_to_world(layout.world_to_cell(actor.global_position))
	var away: Vector3 = center - actor.global_position
	away.y = 0.0
	away = away.normalized() if away.length() > 0.3 else Vector3.BACK
	var pos: Vector3 = actor.global_position + away * dist
	var to: Vector3 = actor.global_position - pos
	var face: float = atan2(-to.x, -to.z)
	var player: Node3D = scene.call("get_player") as Node3D
	player.call("teleport", Vector3(pos.x, 0.05, pos.z), face)
	scene.call("get_camera_rig").call("snap", face)
	scene.call("get_companion").call("snap_behind")
	scene.call("_update_room", true)
	await rec.call("frames", 3)
	_manual(scene)
	scene.call("_trigger_encounter", group_id, str(actor.call("encounter_id")), adv, "")
	if not await rec.call("until", func() -> bool: return Game.combat != null, 60):
		return false
	await rec.call("_quiet_mod_dialog")
	await _banner_done(scene)
	_autopilot(scene)
	return true


## Steps the combat until a pending enemy telegraph (of `skill`, "" = any; in boss phase ≥ `phase`, −1 = any) is half
## way to its impact, then freezes the still. False if the combat ended first or `limit` ticks passed.
func _until_telegraph(scene: Node, skill: String, phase: int, limit: int) -> bool:
	var d: Node = scene.call("get_director") as Node
	var settled: bool = phase <= 0
	for i in limit:
		if Game.combat == null:
			push_warning("[CaptureR4] the combat ended before the still")
			return false
		var sim: RtSim = Game.combat
		if not settled and _boss_phase(sim) >= phase:
			settled = true                           # the phase banner and its M.O.D. line run in real time
			await _banner_done(scene)
			await rec.call("_quiet_mod_dialog")
		if phase < 0 or _boss_phase(sim) >= phase:
			for t: RtTelegraph in sim.telegraphs():
				var mid: int = t.start + (t.impact_at - t.start) / 2
				if not t.is_zone and t.impact_at > sim.tick() and sim.tick() >= mid \
						and (skill == "" or t.skill_id == skill):
					await rec.call("_quiet_mod_dialog")
					await rec.call("frames", 6)
					rec.call("freeze")
					return true
		d.call("advance", 1)
		if i % 300 == 299:
			await rec.call("frames", 1)
	push_warning("[CaptureR4] no telegraph %s within %d ticks" % [skill, limit])
	return false


## R3's banners ("KAMPF!", "PHASE 2", 1.2 s of real time) are over before the still.
func _banner_done(scene: Node) -> void:
	var d: Node = scene.call("get_director") as Node
	var hud: Node = d.get("hud") as Node if d != null else null
	var banner: Node = hud.get("banner") as Node if hud != null and is_instance_valid(hud) else null
	if banner != null:
		await rec.call("until", func() -> bool: return not bool(banner.call("is_showing")), 600)


static func _boss_phase(sim: RtSim) -> int:
	for u: RtUnit in sim.units():
		if u.is_boss and u.side == Combatant.Side.ENEMY:
			return u.phase
	return -1


func _autopilot(scene: Node) -> void:
	var d: Node = scene.call("get_director") as Node
	if d != null and Game.combat != null:
		d.call("submit", RtCommand.autopilot(Game.combat.tick(), Game.combat.controlled_id(), true))


func _manual(scene: Node) -> void:
	var d: Node = scene.call("get_director") as Node
	if d != null:
		d.set("auto_tick", false)
