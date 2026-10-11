extends TestCase
## 06 §1.2/§1.3 (package A): exploration with the hero choice and Graf Mopsula's field ability "Bellen".
## Pure rules (cone geometry incl. the talent reach factor, DAZED → PREEMPTIVE for contact and strike from every side,
## bosses / Fahrscheinfresser cannot be dazed), the EnemyActor DAZED state (stands still, returns to its previous
## state, 15 s immunity, sleeping tutorial rats fall asleep again), and the scene on the M3 fixture floor: as Mopsula
## the player body is the pug (capsule r 0.35 / h 0.9) and Kai follows; `action` barks (never a battle), dazes the
## group in front, not one behind a wall; walking into the dazed group starts a PREEMPTIVE encounter; Kai still strikes;
## a safe-room switch swaps the bodies on resume; HUD hint / touch icon / chest prompts follow the hero.

const Rules := preload("res://scenes/exploration/encounter_rules.gd")
const M3 := preload("res://tests/test_m3_exploration_scene.gd")
const TouchControlsScript := preload("res://scenes/ui/touch_controls.gd")
const SCENE: String = "res://scenes/exploration/exploration.tscn"
const ENEMY_SCENE: String = "res://scenes/exploration/enemy_actor.tscn"
const ROUTER_FIXTURE: String = "res://tests/fixtures/router/router_screen.tscn"
const MAX_FRAMES: int = 240

var _spy: Array[Array] = []
var _abilities: Array[Array] = []
var _saved_data: GameData = null

static var _fixture: GameData = null


func before_each() -> void:
	Engine.time_scale = 8.0
	_spy.clear()
	_abilities.clear()
	_saved_data = DB.data
	if _fixture == null:
		_fixture = M3.fixture_game_data()
	if _fixture != null:
		DB.data = _fixture
	Events.encounter_triggered.connect(_on_encounter)
	Events.field_ability_used.connect(_on_ability)


func after_each() -> void:
	Engine.time_scale = 1.0
	Events.encounter_triggered.disconnect(_on_encounter)
	Events.field_ability_used.disconnect(_on_ability)
	for a: StringName in [&"move_forward", &"move_back", &"move_left", &"move_right", &"sneak", &"action"]:
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
	Sfx.music(&"", 0.0)
	if _saved_data != null:
		DB.data = _saved_data
	# leave no run behind: later files (e.g. test_m0_autoloads) check the state-less Game
	Game.state = null
	Game.run_log = null
	Game.sim = null
	Game.in_battle = false


func _on_encounter(group_id: String, encounter_id: String, advantage: int) -> void:
	_spy.append([group_id, encounter_id, advantage])


func _on_ability(hero_id: String, ability: StringName, hits: int) -> void:
	_abilities.append([hero_id, ability, hits])


func _make_scene(hero: String) -> ExplorationScene:
	Game.new_game(0, "Kai", 4242, &"prime", hero)
	var scene: ExplorationScene = (load(SCENE) as PackedScene).instantiate() as ExplorationScene
	scene.auto_start_battle = false
	add_to_tree(scene)
	await wait_frames(6)
	return scene


## The player `dist` m in front of the sleeping tutorial group f1_g0 (it looks north, −Z), looking at it.
func _in_front_of_tutorial(scene: ExplorationScene, dist: float) -> Node3D:
	var actor: Node3D = scene.get_enemy("f1_g0")
	var fwd: Vector3 = actor.call("flat_forward")
	var pos: Vector3 = actor.global_position + fwd * dist
	scene.get_player().teleport(pos + Vector3(0.0, 0.05, 0.0), Rules.yaw_of(-fwd))
	return actor


# --- pure rules -----------------------------------------------------------------------------------------------------

func test_bark_cone_geometry() -> void:
	var o: Vector3 = Vector3.ZERO
	var fwd: Vector3 = Vector3(0, 0, -1)
	assert_eq([Rules.BARK_RANGE, Rules.BARK_ARC_DEG, Rules.BARK_COOLDOWN, Rules.DAZE_SEC, Rules.DAZE_IMMUNE_SEC],
		[4.0, 120.0, 3.0, 2.5, 15.0], "06 §1.3 values")
	assert_true(Rules.bark_hits(o, fwd, Vector3(0, 0, -3.9)), "straight ahead inside 4 m")
	assert_false(Rules.bark_hits(o, fwd, Vector3(0, 0, -4.2)), "beyond 4 m")
	assert_true(Rules.bark_hits(o, fwd, Vector3(-2.0, 0, -1.3)), "59° to the side")
	assert_false(Rules.bark_hits(o, fwd, Vector3(-2.0, 0, -1.0)), "63° to the side: outside the 120° cone")
	assert_false(Rules.bark_hits(o, fwd, Vector3(0, 0, 1.0)), "behind")
	assert_true(Rules.bark_hits(o, fwd, Vector3(0, 0, -4.9), 1250), "talent reach +25 % (06 §2.2 field_range_pm)")
	assert_true(Rules.bark_hits(o, fwd, Vector3(0, 0, -4.0)), "edge counts")


func test_dazed_groups_are_preemptive_from_every_side() -> void:
	var e: Vector3 = Vector3.ZERO
	var fwd_e: Vector3 = Vector3(0, 0, -1)
	var front: Vector3 = Vector3(0, 0, -1.0)
	var fwd_k: Vector3 = Vector3(0, 0, 1)
	var bd: float = Balance.BACK_DOT
	assert_eq(Rules.contact_advantage(&"IDLE", e, fwd_e, front, fwd_k, false, true, bd), Rules.NORMAL,
		"touching an idle group from the front: normal")
	assert_eq(Rules.contact_advantage(Rules.DAZED, e, fwd_e, front, fwd_k, false, true, bd), Rules.PREEMPTIVE,
		"dazed: preemptive from the front")
	assert_eq(Rules.contact_advantage(Rules.DAZED, e, fwd_e, Vector3(1, 0, 0), Vector3(-1, 0, 0), false, true, bd),
		Rules.PREEMPTIVE, "… and from the side")
	assert_eq(Rules.contact_advantage(Rules.DAZED, e, fwd_e, front, fwd_k, true, true, bd), Rules.NORMAL,
		"bosses stay normal")
	assert_eq(Rules.strike_advantage(Rules.DAZED, e, fwd_e, front, false, bd), Rules.PREEMPTIVE,
		"Kai's strike on a dazed group: preemptive")
	assert_eq(Rules.advantage_for_contact(Rules.DAZED, 0.9), Rules.PREEMPTIVE)
	assert_eq(Rules.advantage_for_contact(&"IDLE", 0.9), Rules.NORMAL)
	assert_eq(Rules.advantage_for_contact(&"IDLE", -0.9), Rules.PREEMPTIVE, "touching the back")
	assert_eq(Rules.advantage_for_contact(&"CHASE", -0.9), Rules.NORMAL)


func test_who_can_be_dazed() -> void:
	assert_true(Rules.can_be_dazed(false, {"sight_range": 10.0, "hear_run": 4.0, "hear_sneak": 1.5}))
	assert_false(Rules.can_be_dazed(true, {"sight_range": 10.0}), "bosses")
	assert_false(Rules.can_be_dazed(false, {"sight_range": 0.0, "hear_run": 0.0, "hear_sneak": 0.0}),
		"Fahrscheinfresser perceives nothing: it only twitches")
	var fs: EnemyDef = real_data().enemy("enm_fahrscheinfresser")
	assert_false(Rules.can_be_dazed(false, Rules.explore_params(fs)), "real Fahrscheinfresser data")


# --- EnemyActor -----------------------------------------------------------------------------------------------------

func _actor(enemy_id: String, state: StringName, boss: bool = false) -> Node3D:
	var enc: EncounterDef = EncounterDef.new()
	enc.id = "enc_test"
	enc.enemies = PackedStringArray([enemy_id])
	enc.boss = boss
	var sp: EnemySpawn = EnemySpawn.make("f1_g9", Vector2i(0, 0), enc, Vector2.ZERO, state)
	var a: Node3D = (load(ENEMY_SCENE) as PackedScene).instantiate() as Node3D
	var def: EnemyDef = real_data().enemy(enemy_id)
	a.call("setup_spawn", sp, Vector3.ZERO, Vector3.ZERO, def, 1, null, null)
	add_to_tree(a)
	return a


func test_daze_state_returns_and_immunity() -> void:
	var a: Node3D = _actor("enm_kanalratte", &"PATROL")
	await wait_frames(2)
	assert_true(bool(a.call("daze")), "a regular group is dazed")
	assert_eq(a.get("state"), Rules.DAZED)
	var bubble: Label3D = a.get_node("AlertBubble") as Label3D
	assert_true(bubble.visible and bubble.text == "?!", "violet ?! bubble")
	assert_false(bool(a.call("daze")), "no second daze while dazed")
	var back: bool = await wait_until(func() -> bool: return a.get("state") != Rules.DAZED, MAX_FRAMES)
	assert_true(back, "the daze ends")
	assert_eq(a.get("state"), &"PATROL", "back to the previous state (no hero around)")
	assert_gt(float(a.call("daze_cooldown")), 0.0, "immune for a while")
	assert_false(bool(a.call("daze")), "15 s immunity (06 §1.3)")
	a.set("_daze_cool", 0.0)
	assert_true(bool(a.call("daze")), "dazable again after the immunity")


func test_dazed_group_stands_still() -> void:
	var a: Node3D = _actor("enm_kanalratte", &"PATROL")
	await wait_frames(2)
	a.call("daze")
	var p: Vector3 = a.global_position
	await wait_frames(8)
	assert_lt(Rules.flat_dist(p, a.global_position), 0.01, "no patrol while dazed")


func test_bosses_and_fahrscheinfresser_only_twitch() -> void:
	var boss: Node3D = _actor("enm_boss_hausmeister", &"IDLE", true)
	await wait_frames(2)
	assert_false(bool(boss.call("daze")), "bosses: no effect")
	assert_ne(boss.get("state"), Rules.DAZED)
	var fs: Node3D = _actor("enm_fahrscheinfresser", &"IDLE")
	await wait_frames(2)
	assert_false(bool(fs.call("daze")), "Fahrscheinfresser: zuckt nur")
	var bubble: Label3D = fs.get_node("AlertBubble") as Label3D
	assert_true(bubble.visible and bubble.text == "…", "a short '…' twitch bubble")


# --- scene ----------------------------------------------------------------------------------------------------------

func test_mopsula_leads_and_kai_follows() -> void:
	var scene: ExplorationScene = await _make_scene("mopsula")
	var body: CharacterBody3D = scene.get_player()
	assert_eq(body.get("hero_id"), "mopsula")
	assert_eq(body.name, "Mopsula")
	assert_eq(body.call("field_ability"), &"bark")
	var cap: CapsuleShape3D = (body.get_node("Collision") as CollisionShape3D).shape as CapsuleShape3D
	assert_almost(cap.radius, 0.35, 0.001, "06 §1.2 capsule r 0.35")
	assert_almost(cap.height, 0.9, 0.001, "h 0.9")
	assert_not_null(body.get("rig"), "the pug rig is the player body")
	var comp: Node3D = scene.get_companion()
	assert_eq(comp.get("member_id"), "kai", "Kai follows")
	assert_eq(comp.name, "Kai")
	assert_lt(Rules.flat_dist(comp.global_position, body.global_position), 3.0, "next to the Count")
	var hud: Node = scene.find_child("ExplorationHud", true, false)
	if hud != null:
		var hint: Node = hud.find_child("FieldHint", true, false)
		assert_not_null(hint)
		if hint != null:
			assert_eq(str(hint.get("caption")), "Bellen", "control hint names the bark")


func test_kai_keeps_the_strike() -> void:
	var scene: ExplorationScene = await _make_scene("kai")
	var body: CharacterBody3D = scene.get_player()
	assert_eq(body.get("hero_id"), "kai")
	assert_eq(body.call("field_ability"), &"strike")
	var cap: CapsuleShape3D = (body.get_node("Collision") as CollisionShape3D).shape as CapsuleShape3D
	assert_almost(cap.radius, 0.4, 0.001)
	assert_almost(cap.height, 1.7, 0.001)
	assert_eq(scene.get_companion().get("member_id"), "mopsula")
	_in_front_of_tutorial(scene, 1.3)
	await wait_frames(3)
	scene.perform_action()
	var ok: bool = await wait_until(func() -> bool: return not _spy.is_empty(), MAX_FRAMES)
	assert_true(ok, "the strike starts the battle")
	if ok:
		assert_eq(_spy[0][2], Rules.PREEMPTIVE, "sleeping group struck: preemptive")
	assert_eq(_abilities.size(), 1, "field_ability_used once")
	if not _abilities.is_empty():
		assert_eq(_abilities[0], ["kai", &"strike", 1])


func test_bark_dazes_never_starts_a_battle_and_contact_is_preemptive() -> void:
	var scene: ExplorationScene = await _make_scene("mopsula")
	var actor: Node3D = _in_front_of_tutorial(scene, 2.6)
	await wait_frames(3)
	scene.perform_action()
	await wait_frames(2)
	assert_eq(actor.get("state"), Rules.DAZED, "the bark dazes the group in front")
	assert_eq(_abilities, [["mopsula", &"bark", 1]], "field_ability_used(mopsula, bark, 1)")
	await wait_frames(6)
	assert_eq(_spy.size(), 0, "the bark never starts a battle")
	assert_false(bool(scene.get_player().call("bark_ready")), "3 s cooldown")
	# walk into the dazed symbol — from the front
	var fwd: Vector3 = actor.call("flat_forward")
	scene.get_player().teleport(actor.global_position + fwd * 0.8 + Vector3(0.0, 0.05, 0.0), Rules.yaw_of(-fwd))
	var ok: bool = await wait_until(func() -> bool: return not _spy.is_empty(), MAX_FRAMES)
	assert_true(ok, "contact starts the battle")
	if ok:
		assert_eq(_spy[0][0], "f1_g0")
		assert_eq(_spy[0][2], Rules.PREEMPTIVE, "contact with a dazed group = preemptive (06 §1.3)")


func test_bark_is_blocked_by_walls_and_ignores_groups_behind() -> void:
	var scene: ExplorationScene = await _make_scene("mopsula")
	var layout: FloorLayout = scene.get_layout()
	# f1_g1 patrols (3,5); (4,5) is the room east of it without a door between them
	var actor: Node3D = scene.get_enemy("f1_g1")
	actor.set("frozen", true)
	var near_wall: Vector3 = layout.cell_to_world(Vector2i(3, 5)) + Vector3(6.6, 0.05, 0.0)
	actor.global_position = near_wall
	var other_side: Vector3 = layout.cell_to_world(Vector2i(4, 5)) + Vector3(-6.4, 0.05, 0.0)
	scene.get_player().teleport(other_side, Rules.yaw_of(Vector3(-1, 0, 0)))
	await wait_frames(3)
	assert_lt(Rules.flat_dist(scene.get_player_position(), actor.global_position), Rules.BARK_RANGE,
		"inside the bark reach …")
	assert_eq(scene.bark_now(), 0, "… but behind a wall")
	assert_ne(actor.get("state"), Rules.DAZED)
	# in the open middle of the room: a group behind the Count is not dazed, in front it is
	var mid: Vector3 = layout.cell_to_world(Vector2i(3, 5)) + Vector3(0.0, 0.05, 0.0)
	actor.global_position = mid
	scene.get_player().teleport(mid + Vector3(-2.5, 0.0, 0.0), Rules.yaw_of(Vector3(-1, 0, 0)))
	await wait_frames(3)
	assert_eq(scene.bark_now(), 0, "behind the bark cone")
	scene.get_player().teleport(mid + Vector3(-2.5, 0.0, 0.0), Rules.yaw_of(Vector3(1, 0, 0)))
	await wait_frames(3)
	assert_eq(scene.bark_now(), 1, "turned around: dazed")
	assert_eq(actor.get("state"), Rules.DAZED)


func test_chest_prompt_and_touch_icon_follow_the_hero() -> void:
	var scene: ExplorationScene = await _make_scene("mopsula")
	var chest: Node = scene.get_interactable("f1_c0")
	assert_not_null(chest)
	if chest != null:
		assert_eq(str(chest.call("prompt_text")), "Kiste mit der Schnauze öffnen", "06 §1.2: with the snout")
	assert_eq(TouchControlsScript.field_icon(), &"bark")
	var t: CanvasLayer = (load("res://scenes/ui/touch_controls.tscn") as PackedScene).instantiate() as CanvasLayer
	t.call("setup", {"capture": true})
	add_to_tree(t)
	await wait_frames(2)
	t.call("set_prompt_active", false)
	var icon: Node = (t.get("buttons") as Dictionary)[&"action"].get_node("Icon")
	assert_eq(icon.get("kind"), &"bark", "idle action icon: sound waves")
	t.call("set_prompt_active", true)
	assert_eq(icon.get("kind"), &"hand", "prompt: hand")
	Game.state.hero = "kai"
	t.call("refresh_hero")
	t.call("set_prompt_active", false)
	assert_eq(icon.get("kind"), &"fist", "Kai: fist")
	if chest != null:
		assert_eq(str(chest.call("prompt_text")), "Kiste öffnen")


func test_safe_room_switch_swaps_the_bodies_on_resume() -> void:
	var scene: ExplorationScene = await _make_scene("kai")
	Game.state.floor_run.stats["time_used_ticks"] = 30   # the run has started: only check_set applies
	assert_false(Game.set_hero("mopsula"), "not in the exploration")
	Game.enter_safe_room("sr_t_kiosk")
	assert_true(Game.set_hero("mopsula"), "switch in the safe room")
	Game.leave_safe_room()
	scene.on_resume({})
	await wait_frames(3)
	assert_eq(scene.get_player().get("hero_id"), "mopsula", "the player body is the Count now")
	assert_eq(scene.get_player().name, "Mopsula")
	assert_eq(scene.get_companion().get("member_id"), "kai")
	assert_eq(scene.get_companion().name, "Kai")
	var hud: Node = scene.find_child("ExplorationHud", true, false)
	if hud != null:
		assert_eq(str(hud.find_child("FieldHint", true, false).get("caption")), "Bellen")
	scene.refresh_hero()                         # idempotent
	assert_eq(scene.get_player().get("hero_id"), "mopsula")
