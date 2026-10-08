extends TestCase
## M5 battle scene (02_TECH §5.7, §9.5, §11.5): headless auto battle through the Router up to BATTLE_END and back,
## HUD values = the last hp_after / mp_after of the events (also at every single event), every event emitted exactly
## once and in order, CTB bar 12 entries (scheme TOUCH 10), the command menu by real ui_accept input, sub menus and
## cancel, auto toggle while the menu is open, ghost preview without mutating the battle, pending sponsor gifts at the
## turn boundary, capture setup, flight by item, defeat card and the results screen.
## Scene tests run with Engine.time_scale 8 and BattlePlayer speed 4 (§11.2).

const SCENE: String = "res://scenes/battle/battle.tscn"
const ROUTER_FIXTURE: String = "res://tests/fixtures/router/router_screen.tscn"
const RESULTS_SCENE: String = "res://scenes/battle/ui/battle_results.tscn"
const BattleHud := preload("res://scenes/battle/ui/battle_hud.gd")
const MAX_FRAMES: int = 20000
const SPEED: float = 4.0

var _saved_auto: bool = false
var _saved_scheme: int = 0
var _ended: Array[int] = []


func before_each() -> void:
	Engine.time_scale = 8.0
	_saved_auto = Game.auto_battle
	_saved_scheme = Game.input_scheme
	_ended.clear()
	Game.new_game(0, "Kai", 4242)
	Events.battle_ended.connect(_on_battle_ended)


func after_each() -> void:
	Engine.time_scale = 1.0
	if Events.battle_ended.is_connected(_on_battle_ended):
		Events.battle_ended.disconnect(_on_battle_ended)
	Game.auto_battle = _saved_auto
	Game.set_input_scheme(_saved_scheme)
	Game.in_battle = false
	if Router.stack_size() > 1 or Router.busy:
		Router.goto(ROUTER_FIXTURE, {}, Router.Transition.NONE)
		await wait_until(func() -> bool: return not Router.busy, 600)
		var cur: Node = Router.current
		if cur != null and is_instance_valid(cur) and cur.scene_file_path == ROUTER_FIXTURE:
			if cur.get_parent() != null:
				cur.get_parent().remove_child(cur)
			cur.free()
	Router.adopt(null)
	Sfx.music(&"", 0.0)


func _on_battle_ended(outcome: int, _enc: String) -> void:
	_ended.append(outcome)


func _setup(enc: String, group: String = "") -> BattleSetup:
	var s: BattleSetup = Game.make_battle_setup(enc, BattleSetup.Advantage.NORMAL, group)
	assert_not_null(s, "BattleSetup for %s" % enc)
	return s


## Standalone battle scene (stays after the end; results continue on their own).
func _scene(s: BattleSetup, extra: Dictionary = {}) -> BattleScene:
	var params: Dictionary = {"setup": s, "speed": SPEED, "stay": true, "results_auto_sec": 0.05}
	params.merge(extra, true)
	var scene: BattleScene = (load(SCENE) as PackedScene).instantiate() as BattleScene
	scene.setup(params)
	add_to_tree(scene)
	return scene


func _wait_done(scene: BattleScene) -> bool:
	return await wait_until(func() -> bool: return scene.controller != null and scene.controller.done, MAX_FRAMES)


func _wait_menu(scene: BattleScene) -> bool:
	return await wait_until(func() -> bool: return scene.hud != null and scene.hud.awaiting, MAX_FRAMES)


func _press(action: StringName) -> void:
	var ev: InputEventAction = InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await wait_frames(2)
	var up: InputEventAction = InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await wait_frames(2)


# --- full flow -----------------------------------------------------------------------------------------------------

func test_auto_battle_reaches_battle_end_through_the_router() -> void:
	Game.auto_battle = true
	var fx: Node = (load(ROUTER_FIXTURE) as PackedScene).instantiate()
	add_to_tree(fx)
	var s: BattleSetup = _setup("enc_f1_a1_tutorial", "f1_g0")
	assert_true(Game.in_battle, "make_battle_setup → in_battle")
	Router.push(Router.SCENE_BATTLE, {"setup": s, "speed": SPEED, "results_auto_sec": 0.05}, Router.Transition.NONE)
	assert_true(await wait_until(func() -> bool: return Router.current is BattleScene and not Router.busy, 600))
	var battle: BattleScene = Router.current as BattleScene
	if battle == null:
		return
	assert_false(battle.debug_setup_used)
	assert_eq(battle.battle_setup, s, "the Router setup is used")
	assert_true(await wait_until(func() -> bool: return Router.current == fx and not Router.busy, MAX_FRAMES),
		"Router.end_battle pops back to the previous screen")
	assert_eq(_ended, [BattleResult.Outcome.VICTORY] as Array[int], "battle_ended once with VICTORY (tutorial)")
	var payloads: Array = fx.get("payloads")
	assert_len(payloads, 1)
	if payloads.size() == 1:
		var r: BattleResult = (payloads[0] as Dictionary).get("battle_result") as BattleResult
		assert_not_null(r, "on_resume payload carries the BattleResult")
		if r != null:
			assert_eq(r.outcome, BattleResult.Outcome.VICTORY)
	assert_false(Game.in_battle, "apply_battle_result ended the battle")
	assert_true(Game.state.floor_run.timer_started, "tutorial victory starts the floor countdown")
	assert_true(Game.state.floor_run.defeated_groups.has("f1_g0"))


func test_every_event_is_emitted_once_in_order_and_ends_with_battle_end() -> void:
	Game.auto_battle = true
	var scene: BattleScene = _scene(_setup("enc_f1_a2"))
	var seen: Array[ActionEvent] = []
	scene.player.event_played.connect(func(e: ActionEvent) -> void: seen.append(e))
	assert_true(await _wait_done(scene))
	var history: Array[ActionEvent] = scene.controller.state.history
	assert_gt(history.size(), 10)
	assert_eq(seen.size(), history.size(), "one event_played per event")
	var same: bool = seen.size() == history.size()
	for i in mini(seen.size(), history.size()):
		if seen[i] != history[i]:
			same = false
			fail("event %d out of order: %s vs %s" % [i, str(seen[i].to_dict()), str(history[i].to_dict())])
			break
	assert_true(same)
	assert_eq(ActionEvent.type_name(history.back().type), "BATTLE_END", "BATTLE_END is the last event")
	assert_eq(scene.player.emitted, history.size())
	assert_true(scene.controller.state.is_finished())
	assert_eq(_ended.size(), 1)
	assert_true(scene.results != null and not scene.results.shown, "results continued on their own")


func test_hud_values_equal_last_hp_after() -> void:
	Game.auto_battle = true
	var scene: BattleScene = _scene(_setup("enc_f1_a2"))
	var hud: BattleHud = scene.hud
	var mismatches: PackedStringArray = []
	scene.player.event_played.connect(func(e: ActionEvent) -> void:
		if e.type in [ActionEvent.Type.DAMAGE, ActionEvent.Type.HEAL, ActionEvent.Type.REVIVE] and e.hp_after >= 0:
			var shown: int = hud.panel_hp(e.target_id) if e.target_id.begins_with("p") else hud.plate_hp(e.target_id)
			if shown != e.hp_after:
				mismatches.append("%s %s: hud %d, event %d" % [ActionEvent.type_name(e.type), e.target_id, shown,
					e.hp_after])
		elif e.type == ActionEvent.Type.MP_CHANGE and e.target_id.begins_with("p"):
			if hud.panel_mp(e.target_id) != e.mp_after:
				mismatches.append("MP %s: hud %d, event %d" % [e.target_id, hud.panel_mp(e.target_id), e.mp_after]))
	assert_true(await _wait_done(scene))
	assert_eq(mismatches, PackedStringArray(), "HUD shows hp_after / mp_after at each event")
	var last_hp: Dictionary = {}
	var last_mp: Dictionary = {}
	for e: ActionEvent in scene.controller.state.history:
		if e.type in [ActionEvent.Type.DAMAGE, ActionEvent.Type.HEAL, ActionEvent.Type.REVIVE] and e.hp_after >= 0:
			last_hp[e.target_id] = e.hp_after
		elif e.type == ActionEvent.Type.KO:
			last_hp[e.target_id] = 0
		elif e.type == ActionEvent.Type.MP_CHANGE:
			last_mp[e.target_id] = e.mp_after
	assert_gt(last_hp.size(), 0, "the battle had hits")
	for id: Variant in last_hp.keys():
		var sid: String = str(id)
		if sid.begins_with("p"):
			assert_eq(hud.panel_hp(sid), int(last_hp[id]), "party panel %s = last hp_after" % sid)
			assert_eq(hud.panel_hp(sid), maxi(0, scene.controller.state.get_combatant(sid).hp))
		else:
			assert_eq(hud.plate_hp(sid), int(last_hp[id]), "enemy plate %s = last hp_after" % sid)
	for id2: Variant in last_mp.keys():
		if str(id2).begins_with("p"):
			assert_eq(hud.panel_mp(str(id2)), int(last_mp[id2]), "party panel MP %s" % str(id2))


func test_defeat_shows_the_ko_card() -> void:
	Game.auto_battle = true
	for m: PartyMember in Game.state.party:
		m.hp = 1
	var scene: BattleScene = _scene(_setup("enc_f1_boss_hausmeister"), {"speed": 8.0})
	assert_true(await _wait_done(scene))
	assert_eq(_ended, [BattleResult.Outcome.DEFEAT] as Array[int])
	assert_eq(scene.results.outcome, BattleResult.Outcome.DEFEAT)
	for id: String in ["p0", "p1"]:
		assert_eq(scene.hud.panel_hp(id), 0, "%s KO in the HUD" % id)


# --- HUD -----------------------------------------------------------------------------------------------------------

func test_ctb_bar_shows_12_entries_and_10_on_touch() -> void:
	Game.auto_battle = false
	Game.set_input_scheme(Game.InputScheme.KEYBOARD_MOUSE)
	var scene: BattleScene = _scene(_setup("enc_f1_a2"))
	assert_true(await _wait_menu(scene))
	await wait_frames(3)
	var ctb: Control = scene.hud.ctb
	assert_eq(int(ctb.call("entry_count")), CTBQueue.PREVIEW_LENGTH, "12 entries (desktop / gamepad)")
	assert_eq(ctb.call("shown_ids"), scene.controller.state.preview_order(12, CTBQueue.RANK_NORMAL),
		"preview of the highlighted Angriff (rank 3)")
	Game.set_input_scheme(Game.InputScheme.TOUCH)
	await wait_frames(3)
	assert_eq(int(ctb.call("entry_count")), CTBQueue.PREVIEW_LENGTH_TOUCH, "10 entries (touch)")
	assert_true(scene.hud.command_menu.get("touch"), "touch command grid")
	for b: Button in scene.hud.command_menu.get("buttons"):
		assert_true(b.custom_minimum_size.y >= UiTheme.TOUCH_HIT, "touch hit area >= 88 (%s)" % b.name)


func test_command_menu_by_input_attacks_the_default_target() -> void:
	Game.auto_battle = false
	Game.set_input_scheme(Game.InputScheme.KEYBOARD_MOUSE)
	var scene: BattleScene = _scene(_setup("enc_f1_a2"))
	assert_true(await _wait_menu(scene))
	await wait_frames(3)
	var hud: BattleHud = scene.hud
	var state: BattleState = scene.controller.state
	var actor: Combatant = state.current_actor()
	assert_eq(hud.level, &"menu")
	assert_eq(int(hud.command_menu.call("focused_kind")), BattleCommand.Kind.ATTACK, "default focus: Angriff")
	var expected: String = state.default_target(actor, "")
	await _press(&"ui_accept")
	assert_eq(hud.level, &"target", "Angriff → target selection")
	await wait_frames(2)
	assert_eq(str(hud.target_cursor.call("current_id")), expected, "default target (lowest HP)")
	await _press(&"ui_accept")
	assert_true(await wait_until(func() -> bool: return scene.controller.commands.size() >= 1, MAX_FRAMES))
	if scene.controller.commands.is_empty():
		return
	var c: Dictionary = scene.controller.commands[0]
	assert_eq(c["cmd"], BattleCommand.attack(actor.id, expected).to_dict())
	assert_false(bool(c["auto"]), "chosen by the player")


func test_sub_menu_cancel_and_target_back() -> void:
	Game.auto_battle = false
	var scene: BattleScene = _scene(_setup("enc_f1_a2"))
	assert_true(await _wait_menu(scene))
	await wait_frames(3)
	var hud: BattleHud = scene.hud
	hud.command_menu.call("choose", BattleCommand.Kind.SKILL)
	assert_eq(hud.level, &"list")
	assert_true(hud.action_list.visible)
	var entries: Array = hud.action_list.get("entries")
	assert_gt(entries.size(), 0, "skills listed")
	await wait_frames(2)
	await _press(&"ui_cancel")
	assert_eq(hud.level, &"menu", "cancel → back to the commands")
	assert_false(hud.action_list.visible)
	hud.command_menu.call("choose", BattleCommand.Kind.ATTACK)
	assert_eq(hud.level, &"target")
	hud.target_cursor.call("cancel")
	assert_eq(hud.level, &"menu", "target cancel → commands")
	assert_true(hud.awaiting)
	assert_eq(scene.controller.commands.size(), 0, "nothing submitted")


func test_auto_toggle_in_the_menu_hands_the_turn_to_auto_policy() -> void:
	Game.auto_battle = false
	var scene: BattleScene = _scene(_setup("enc_f1_a2"))
	assert_true(await _wait_menu(scene))
	await _press(&"toggle_auto")
	assert_true(Game.auto_battle, "toggle_auto switches auto battle on")
	assert_true(await wait_until(func() -> bool: return scene.controller.commands.size() >= 1, MAX_FRAMES))
	if not scene.controller.commands.is_empty():
		assert_true(bool(scene.controller.commands[0]["auto"]), "recorded as auto")
	assert_true(await _wait_done(scene))


func test_flight_by_smoke_item_ends_fled() -> void:
	Game.auto_battle = false
	Game.state.inventory.add("itm_smoke", 1)
	var scene: BattleScene = _scene(_setup("enc_f1_a2"))
	assert_true(await _wait_menu(scene))
	await wait_frames(3)
	var hud: BattleHud = scene.hud
	hud.command_menu.call("choose", BattleCommand.Kind.ITEM)
	assert_eq(hud.level, &"list")
	hud.action_list.call("choose_id", "itm_smoke")
	assert_true(await _wait_done(scene))
	assert_eq(_ended, [BattleResult.Outcome.FLED] as Array[int])
	assert_eq(scene.results.outcome, BattleResult.Outcome.FLED)
	assert_eq(scene.controller.commands[0]["cmd"]["item"], "itm_smoke")


func test_ghost_preview_moves_a_slowed_target_without_mutating_the_battle() -> void:
	var s: BattleSetup = _setup("enc_f1_a2")
	var state: BattleState = BattleState.new(s, DB.data)
	state.start()
	var actor: Combatant = state.current_actor()
	assert_not_null(actor)
	if actor == null:
		return
	var target: String = state.living(Combatant.Side.ENEMY)[0].id
	var before: Dictionary = state.to_dict()
	var base: PackedStringArray = state.preview_order(12, 3)
	var ghost: PackedStringArray = BattleHud.ghost_order(state, actor, "skl_kai_leash_trip",
		PackedStringArray([target]), 3, 12)
	assert_eq(ghost.size(), 12)
	assert_ne(ghost, base, "slow changes the order")
	assert_lt(ghost.count(target), base.count(target) + 1, "the slowed target does not act more often")
	assert_eq(state.to_dict(), before, "the ghost preview never mutates the BattleState")


func test_threshold_gift_is_delivered_at_the_turn_boundary() -> void:
	Game.auto_battle = true
	Show.add_hype(46.0 - Show.hype())
	var scene: BattleScene = _scene(_setup("enc_f1_a2"))
	var gifts: Array[ActionEvent] = []
	scene.player.event_played.connect(func(e: ActionEvent) -> void:
		if e.type == ActionEvent.Type.SPONSOR_GIFT:
			gifts.append(e))
	assert_true(await _wait_done(scene))
	assert_gt(scene.controller.gifts.size(), 0, "a hype threshold made a sponsor gift due")
	assert_gt(gifts.size(), 0, "SPONSOR_GIFT played")
	if not gifts.is_empty():
		assert_true(DB.has_id("sponsors", gifts[0].sponsor_id))


func test_capture_setup_stops_at_the_first_command_menu() -> void:
	Game.auto_battle = true
	var scene: BattleScene = (load(SCENE) as PackedScene).instantiate() as BattleScene
	scene.setup({"capture": true, "speed": SPEED})
	add_to_tree(scene)
	assert_true(scene.debug_setup_used, "no setup → debug setup")
	assert_eq(scene.battle_setup.seed, BattleScene.DEBUG_SEED)
	assert_false(DB.encounter(scene.battle_setup.encounter_id).boss, "first non-boss encounter")
	assert_true(await _wait_menu(scene))
	assert_false(scene.controller.state.is_finished())
	assert_true(scene.controller.state.current_actor().is_party())
	assert_false(scene.controller.exit_on_end, "a capture never leaves the scene")


# --- stage / results ------------------------------------------------------------------------------------------------

func test_stage_slots_and_the_queen_on_her_wreck() -> void:
	var s: BattleSetup = _setup("enc_f1_a2")
	var scene: BattleScene = _scene(s)
	await wait_frames(2)
	var stage: Node3D = scene.stage
	assert_eq(stage.call("home", "e0"), Vector3(-2.4, 0, -2.6), "3 enemies: 03_ART §8.2 layout")
	assert_eq(stage.call("home", "e1"), Vector3(0, 0, -3.4))
	assert_eq(stage.call("home", "p0"), Vector3(-1.3, 0, 3.0))
	assert_eq(stage.call("letter", "e0"), "A", "duplicate Kanalratten get letters")
	assert_eq(stage.call("letter", "e1"), "", "single Taubenschwarm has none")
	var q: BattleSetup = BattleBridge.make_setup(Game.state, DB.data, "enc_f1_boss_rattenkoenigin", 0, "", 7)
	var qstage: Node3D = (load("res://scenes/battle/battle_stage.gd") as GDScript).new()
	add_to_tree(qstage)
	qstage.call("build", q, &"low")
	assert_eq(qstage.call("home", "e0"), Vector3(0, 3.0, -6.0), "Rattenkönigin on the wreck")
	assert_not_null(qstage.get_node_or_null("Wreck"))
	assert_eq(qstage.call("home", "p0"), Vector3(-1.3, 0, 4.0), "party one metre back")
	qstage.call("add_pseudo", "u0", "pu_train_gleis9")
	var train: Node3D = qstage.get("train")
	assert_not_null(train, "pseudo unit → train staged")
	if train != null:
		var hit: Array[bool] = [false]
		train.connect("hit", func() -> void: hit[0] = true)
		train.call("pass_through", 0.3)
		assert_true(await wait_until(func() -> bool: return hit[0], 600), "the train hits the party line")


func test_results_screen_lists_rewards_and_continues() -> void:
	var results: CanvasLayer = (load(RESULTS_SCENE) as PackedScene).instantiate() as CanvasLayer
	add_to_tree(results)
	var r: BattleResult = BattleResult.new()
	r.outcome = BattleResult.Outcome.VICTORY
	r.party_hp = {"kai": 10, "mopsula": 0}
	var rw: BattleRewards = BattleRewards.new()
	rw.exp = 38
	rw.credits = 23
	rw.overkill_credits = 3
	rw.followers = 94
	rw.items = PackedStringArray(["itm_bandage", "itm_bandage"])
	rw.achievements = PackedStringArray(["ach_first_blood"]) if DB.has_id("achievements", "ach_first_blood") \
		else PackedStringArray()
	var info: LevelUpInfo = LevelUpInfo.new()
	info.member_id = "kai"
	info.old_level = 1
	info.new_level = 2
	info.stat_gains = {"hp": 9, "str": 2}
	rw.level_ups = [info]
	var done: Array[bool] = [false]
	var run: Callable = func() -> void:
		await results.call("present", r, rw)
		done[0] = true
	run.call()
	await wait_frames(3)
	assert_true(bool(results.get("shown")))
	var texts: PackedStringArray = []
	for l: Node in results.find_children("*", "Label", true, false):
		texts.append((l as Label).text)
	var all: String = " | ".join(texts)
	for want: String in ["SIEG!", "+38 EXP", "LEVEL UP!", "+23 Cr", "+94 Follower", "Werbepflaster ×2"]:
		assert_true(all.contains(want), "results show '%s' (%s)" % [want, all])
	var b: Button = results.get("continue_button")
	assert_not_null(b)
	if b != null:
		assert_true(b.has_focus(), "Weiter has the default focus")
		b.pressed.emit()
	assert_true(await wait_until(func() -> bool: return done[0], 120), "present() returns after Weiter")
	assert_false(bool(results.get("shown")))
