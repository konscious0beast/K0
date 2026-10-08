extends TestCase
## M5 battle scene (02_TECH §5.7, §9.5, §11.5): headless auto battle through the Router up to BATTLE_END and back,
## HUD values = the last hp_after / mp_after of the events (also at every single event), every event emitted exactly
## once and in order, CTB bar 12 entries (scheme TOUCH 10), the command menu by real ui_accept input, sub menus and
## cancel, auto toggle while the menu is open, ghost preview without mutating the battle, pending sponsor gifts at the
## turn boundary, capture setup, flight by item, defeat card and the results screen; a full Rattenkönigin battle
## (summon plates = real name / max HP / last hp_after, train turn), the HUD ghost preview, UiTheme on the HUD, the
## inert dimmed menu, greyed commands, 12 px touch gaps, scheme switches mid-menu, stable duplicate letters, a rig
## freed mid-dash and the invalid-AI-command fallback.
## Scene tests run with Engine.time_scale 8 and BattlePlayer speed 4 (§11.2).

const SCENE: String = "res://scenes/battle/battle.tscn"
const ROUTER_FIXTURE: String = "res://tests/fixtures/router/router_screen.tscn"
const RESULTS_SCENE: String = "res://scenes/battle/ui/battle_results.tscn"
const BattleHud := preload("res://scenes/battle/ui/battle_hud.gd")
const BattleController := preload("res://scenes/battle/battle_controller.gd")
const EnemyPlates := preload("res://scenes/battle/ui/enemy_plates.gd")
const MAX_FRAMES: int = 20000
const SPEED: float = 4.0

## EnemyAI / AutoPolicy double that proposes an invalid command.
class BadAiState extends RefCounted:
	func choose_ai_command() -> BattleCommand:
		return BattleCommand.attack("e0", "nobody")

	func validate(_cmd: BattleCommand) -> String:
		return "target not valid"


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


func _level_party(exp_gain: int) -> void:
	for m: PartyMember in Game.state.party:
		Progression.add_exp(m, exp_gain, DB.data)
		var sb: StatBlock = Progression.total_stats(m, DB.data)
		m.hp = sb.get_stat(StatBlock.Stat.HP)
		m.mp = sb.get_stat(StatBlock.Stat.MP)


## Smallest distance between two rects (negative = overlap).
static func _gap(a: Rect2, b: Rect2) -> float:
	var dx: float = maxf(b.position.x - a.end.x, a.position.x - b.end.x)
	var dy: float = maxf(b.position.y - a.end.y, a.position.y - b.end.y)
	return maxf(dx, dy)


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


## M5 CR 2: a battle freed before its end leaves neither Game nor Show in battle mode — a gift arriving afterwards in
## the exploration is applied at once (not queued for a dead battle), and the next battle starts clean.
func test_battle_freed_mid_fight_resets_game_and_show() -> void:
	Game.auto_battle = false
	var scene: BattleScene = _scene(_setup("enc_f1_a2"), {"stay": true})
	assert_true(await _wait_menu(scene), "the party command menu is up")
	assert_true(Game.in_battle)
	var queued: Dictionary = Gift.make_dev("gold", "", 100)
	assert_eq(Show.receive_gift(queued)["apply"], "queued")
	scene.get_parent().remove_child(scene)
	scene.queue_free()
	await wait_frames(2)
	assert_false(Game.in_battle, "Game left battle mode")
	var credits: int = Game.state.inventory.credits
	var g: Dictionary = Gift.make_dev("gold", "", 100)
	assert_eq(Show.receive_gift(g)["apply"], "now", "Show has no battle context left")
	assert_eq(Game.state.inventory.credits, credits + 100)
	assert_eq(Show.take_pending_gift(null), {}, "the aborted battle's queue is gone")


## M5 verify: a loop that ends without a BattleResult (BattleState bug) must not strand the player: the controller
## drops the battle (Game + Show reset), reports finished(null) and leaves through the Router when exit_on_end.
func test_controller_without_result_never_strands_the_player() -> void:
	var ctrl: BattleController = BattleController.new()
	ctrl.exit_on_end = false
	add_to_tree(ctrl)
	var got: Array = []
	ctrl.finished.connect(func(r: BattleResult) -> void: got.append(r))
	var s: BattleSetup = _setup("enc_f1_a2")
	Show.begin_battle(s)
	assert_true(Game.in_battle)
	ctrl.abort_unfinished()
	assert_true(ctrl.done)
	assert_eq(got, [null], "finished(null)")
	assert_false(Game.in_battle)
	var g: Dictionary = Gift.make_dev("gold", "", 100)
	assert_eq(Show.receive_gift(g)["apply"], "now", "Show's battle context was dropped")


## M5 verify: several enemies high in the frame — a plate pushed up into the top HUD band is not clamped back down
## onto the plates below it; it slides sideways (or below) and never overlaps one, and never enters the band.
func test_plate_placement_never_overlaps_at_the_top_band() -> void:
	var sz: Vector2 = Vector2(136, 50)
	var placed: Array[Rect2] = []
	for i in 4:
		var want: Rect2 = Rect2(Vector2(500 + i * 10, 100), sz)     # all heads at the same spot just under the band
		var r: Rect2 = EnemyPlates.place_rect(want, placed, 1280.0 - EnemyPlates.RIGHT_CLEAR)
		assert_true(r.position.y >= EnemyPlates.TOP_BAND, "plate %d below the top band" % i)
		for o: Rect2 in placed:
			assert_false(r.grow(1.0).intersects(o), "plate %d overlaps a placed plate" % i)
		assert_true(r.position.x >= 4.0 and r.end.x <= 1280.0 - EnemyPlates.RIGHT_CLEAR, "inside the free area")
		placed.append(r)
	var free: Rect2 = EnemyPlates.place_rect(Rect2(Vector2(100, 400), sz), placed, 1188.0)
	assert_eq(free.position, Vector2(100, 400), "a free plate stays where it wants to be")


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
			if e.target_id.begins_with("e") and bool(hud.plates.call("is_full", e.target_id)):
				mismatches.append("full plate of %s covers the damage number during playback" % e.target_id)
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
	var cmd_buttons: Array[Button] = scene.hud.command_menu.get("buttons")
	for b: Button in cmd_buttons:
		assert_true(b.custom_minimum_size.y >= UiTheme.TOUCH_HIT, "touch hit area >= 88 (%s)" % b.name)
	for i in cmd_buttons.size():
		for j in range(i + 1, cmd_buttons.size()):
			var g: float = _gap(cmd_buttons[i].get_global_rect(), cmd_buttons[j].get_global_rect())
			assert_true(g >= 11.99, "hit areas %s / %s are %.1f px apart (>= 12, 02_TECH §10.2)" % [cmd_buttons[i].name,
				cmd_buttons[j].name, g])
	assert_eq(str(scene.hud.get("_auto_key").text), "", "no keyboard hint in TOUCH")


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
	for en: Combatant in state.living(Combatant.Side.ENEMY):
		assert_true(bool(hud.plates.call("is_full", en.id)), "full plate of %s while choosing" % en.id)
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
	for c: Dictionary in scene.controller.commands:
		assert_true(str((c["cmd"] as Dictionary)["actor"]).begins_with("e"), "§9.5: the first party turn is the menu")


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
	var renamed: Array[PackedStringArray] = []
	qstage.connect("letters_changed", func(ids: PackedStringArray) -> void: renamed.append(ids))
	qstage.call("add_enemy", "e1", "enm_kanalratte", 1, false)
	assert_eq(qstage.call("letter", "e1"), "", "a lone Kanalratte has no letter")
	qstage.call("add_enemy", "e2", "enm_kanalratte", 2, true)
	assert_eq([qstage.call("letter", "e1"), qstage.call("letter", "e2")], ["A", "B"], "second rat → A / B")
	assert_eq(qstage.call("display_name", "e1"), "Kanalratte A")
	assert_eq(renamed.back() if not renamed.is_empty() else PackedStringArray(), PackedStringArray(["e1", "e2"]),
		"letters_changed names the renamed lone unit too")
	qstage.call("add_enemy", "e10", "enm_kanalratte", 3, true)
	assert_eq([qstage.call("letter", "e1"), qstage.call("letter", "e2"), qstage.call("letter", "e10")],
		["A", "B", "C"], "spawn order by id number (e10 after e2), existing letters stay")
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
		assert_true(b.size.y >= UiTheme.TOUCH_HIT, "Weiter hit area >= 88 px (%.0f)" % b.size.y)
		assert_eq(b.get_theme_font_size("font_size"), UiTheme.FONT_SIZE_BUTTON_BIG, "ButtonBig resolves (UiTheme)")
		b.pressed.emit()
	assert_true(await wait_until(func() -> bool: return done[0], 120), "present() returns after Weiter")
	assert_false(bool(results.get("shown")))


# --- review round: summons, ghosts, theme, menus, letters, robustness ------------------------------------------------

func test_queen_battle_summon_plates_and_train_follow_the_events() -> void:
	Game.auto_battle = true
	_level_party(4000)
	var scene: BattleScene = _scene(_setup("enc_f1_boss_rattenkoenigin"))
	var hud: BattleHud = scene.hud
	var seen: Array[ActionEvent] = []
	var mismatches: PackedStringArray = []
	var summoned: PackedStringArray = []
	var train_turns: Array[int] = [0]
	scene.player.event_played.connect(func(e: ActionEvent) -> void:
		seen.append(e)
		if e.type == ActionEvent.Type.SUMMON and e.target_id.begins_with("e"):
			summoned.append(e.target_id)
			if str(hud.plates.call("plate_name", e.target_id)) == e.target_id:
				mismatches.append("plate of %s shows the raw id" % e.target_id)
			if int(hud.plates.call("plate_max_hp", e.target_id)) != int(DB.enemy(e.def_id).stats.get("hp", 0)):
				mismatches.append("plate max_hp of %s = %d" % [e.target_id, int(hud.plates.call("plate_max_hp",
					e.target_id))])
		elif e.type == ActionEvent.Type.ACTION_START and e.actor_id.begins_with("u"):
			train_turns[0] += 1
		elif e.type in [ActionEvent.Type.DAMAGE, ActionEvent.Type.HEAL, ActionEvent.Type.REVIVE] and e.hp_after >= 0:
			var shown: int = hud.panel_hp(e.target_id) if e.target_id.begins_with("p") else hud.plate_hp(e.target_id)
			if shown != e.hp_after:
				mismatches.append("%s %s: hud %d, event %d" % [ActionEvent.type_name(e.type), e.target_id, shown,
					e.hp_after]))
	assert_true(await _wait_done(scene))
	var state: BattleState = scene.controller.state
	assert_eq(seen.size(), state.history.size(), "one event_played per event")
	for i in mini(seen.size(), state.history.size()):
		if seen[i] != state.history[i]:
			fail("event %d out of order" % i)
			break
	assert_eq(mismatches, PackedStringArray(), "HUD = event data at every event (summons included)")
	assert_gt(summoned.size(), 1, "the queen summoned her rats")
	assert_gt(train_turns[0], 0, "the Gleis-9 train had its pseudo turn")
	for id: String in summoned:
		var c: Combatant = state.get_combatant(id)
		assert_eq(int(hud.plates.call("plate_max_hp", id)), c.max_hp(), "plate max HP of %s" % id)
		assert_eq(str(hud.plates.call("plate_name", id)), str(scene.stage.call("display_name", id)),
			"plate name of %s follows the stage letters" % id)
	var last_hp: Dictionary = {}
	for e: ActionEvent in state.history:
		if e.type in [ActionEvent.Type.DAMAGE, ActionEvent.Type.HEAL, ActionEvent.Type.REVIVE] and e.hp_after >= 0:
			last_hp[e.target_id] = e.hp_after
		elif e.type == ActionEvent.Type.KO:
			last_hp[e.target_id] = 0
	for id2: Variant in last_hp.keys():
		var sid: String = str(id2)
		var shown2: int = hud.panel_hp(sid) if sid.begins_with("p") else hud.plate_hp(sid)
		assert_eq(shown2, int(last_hp[id2]), "%s = last hp_after" % sid)


func test_target_ghost_preview_is_drawn_by_the_hud_ctb_bar() -> void:
	Game.auto_battle = false
	var scene: BattleScene = _scene(_setup("enc_f1_a2"))
	assert_true(await _wait_menu(scene))
	await wait_frames(3)
	var hud: BattleHud = scene.hud
	var state: BattleState = scene.controller.state
	var actor: Combatant = state.current_actor()
	var skill: String = "skl_kai_leash_trip"
	hud.set("_kind", BattleCommand.Kind.SKILL)
	hud.set("_skill_id", skill)
	hud.call("_begin_targets", skill, "Test")
	assert_eq(hud.level, &"target")
	var rank: int = state.skill_def(skill).rank
	var count: int = int(hud.ctb.get("count"))
	var moved_any: bool = false
	for t: String in state.valid_targets(actor, skill):
		hud.target_cursor.call("select_id", t)
		var ghost: PackedStringArray = BattleHud.ghost_order(state, actor, skill, PackedStringArray([t]), rank, count)
		var base: PackedStringArray = state.preview_order(count, rank)
		if ghost.find(t) == base.find(t) and ghost.count(t) == base.count(t):
			assert_false(bool(hud.ctb.call("is_ghost", t)), "%s does not move → no ghost" % t)
			continue
		moved_any = true
		assert_true(bool(hud.ctb.call("is_ghost", t)), "the slowed %s is drawn as a ghost" % t)
		assert_eq(hud.ctb.call("shown_ids"), ghost, "the bar shows the hypothetical order")
	assert_true(moved_any, "the slow moves at least one enemy")


func test_hud_uses_ui_theme_greyed_commands_and_an_inert_dimmed_menu() -> void:
	Game.auto_battle = false
	Game.set_input_scheme(Game.InputScheme.KEYBOARD_MOUSE)
	var scene: BattleScene = _scene(_setup("enc_f1_a1_tutorial", "f1_g0"))
	assert_true(await _wait_menu(scene))
	await wait_frames(3)
	var hud: BattleHud = scene.hud
	var menu: PanelContainer = hud.command_menu
	var buttons: Array[Button] = menu.get("buttons")
	var focus: StyleBoxFlat = buttons[0].get_theme_stylebox("focus") as StyleBoxFlat
	assert_not_null(focus)
	if focus != null:
		assert_eq(focus.border_color, UiTheme.C_ACCENT_2, "3 px cyan focus frame (03_ART §9.1)")
		assert_eq(focus.border_width_top, 3)
		assert_eq(focus.expand_margin_left, 0.0, "drawn inside the row (never clipped)")
	assert_eq(buttons[0].get_theme_stylebox("normal"), UiTheme.get_theme().get_stylebox("normal", "ButtonFlat"),
		"the HUD inherits UiTheme (ButtonFlat resolves under the CanvasLayer)")
	assert_eq(hud.speed_button.focus_mode, Control.FOCUS_NONE, "×1 never steals the menu focus")
	assert_eq(hud.auto_button.focus_mode, Control.FOCUS_NONE, "AUTO never steals the menu focus")
	var flee: Button = buttons[BattleCommand.Kind.FLEE]
	assert_false((menu.get("enabled") as Array)[BattleCommand.Kind.FLEE], "no flight in the tutorial")
	assert_false(flee.disabled, "greyed, but pressable")
	flee.pressed.emit()
	assert_eq(hud.level, &"menu", "rejected: still in the menu")
	assert_eq(str(hud.banner.call("skill_text")), "Flucht unmöglich", "the reason is shown")
	menu.call("choose", BattleCommand.Kind.SKILL)
	assert_eq(hud.level, &"list")
	assert_true(menu.visible, "the command menu stays visible (dimmed)")
	for b: Button in buttons:
		assert_eq(b.focus_mode, Control.FOCUS_NONE, "dimmed %s takes no focus" % b.name)
		assert_eq(b.mouse_filter, Control.MOUSE_FILTER_IGNORE, "dimmed %s takes no clicks" % b.name)
	buttons[BattleCommand.Kind.ATTACK].pressed.emit()
	assert_eq(hud.level, &"list", "a click on a dimmed command does nothing")
	var rows: Array[Button] = hud.action_list.get("buttons")
	assert_gt(rows.size(), 0)
	if not rows.is_empty():
		var rf: StyleBoxFlat = rows[0].get_theme_stylebox("focus") as StyleBoxFlat
		assert_true(rf != null and rf.expand_margin_left == 0.0 and rf.border_color == UiTheme.C_ACCENT_2,
			"list rows: cyan focus frame inside the row (ScrollContainer clipping)")
	await wait_frames(2)
	await _press(&"ui_cancel")
	assert_eq(hud.level, &"menu")
	for b2: Button in menu.get("buttons"):
		assert_eq(b2.focus_mode, Control.FOCUS_ALL, "menu active again")


func test_scheme_switch_reopens_the_list_with_touch_rows() -> void:
	Game.auto_battle = false
	Game.set_input_scheme(Game.InputScheme.KEYBOARD_MOUSE)
	var scene: BattleScene = _scene(_setup("enc_f1_a2"))
	assert_true(await _wait_menu(scene))
	await wait_frames(3)
	var hud: BattleHud = scene.hud
	hud.command_menu.call("choose", BattleCommand.Kind.SKILL)
	assert_eq(hud.level, &"list")
	assert_eq(str(hud.get("_auto_key").text), "T")
	Game.set_input_scheme(Game.InputScheme.TOUCH)
	await wait_frames(3)
	assert_eq(hud.level, &"list", "still in the sub menu")
	assert_true(bool(hud.action_list.get("touch")), "list re-opened for TOUCH")
	assert_eq(str(hud.get("_auto_key").text), "", "key hints follow the scheme")
	var rows: Array[Button] = hud.action_list.get("buttons")
	for i in rows.size():
		assert_true(rows[i].size.y >= UiTheme.TOUCH_HIT, "touch row %d >= 88 px" % i)
		if i > 0 and rows[i].is_visible_in_tree() and rows[i - 1].is_visible_in_tree():
			assert_true(_gap(rows[i - 1].get_global_rect(), rows[i].get_global_rect()) >= 11.99,
				"touch rows %d / %d >= 12 px apart" % [i - 1, i])
	assert_eq(int(hud.ctb.call("entry_count")), CTBQueue.PREVIEW_LENGTH_TOUCH)
	Game.set_input_scheme(Game.InputScheme.KEYBOARD_MOUSE)
	await wait_frames(3)
	assert_false(bool(hud.action_list.get("touch")))
	assert_eq(int(hud.ctb.call("entry_count")), CTBQueue.PREVIEW_LENGTH, "back to 12 entries")


func test_a_rig_freed_mid_dash_still_plays_every_event() -> void:
	Game.auto_battle = false
	var scene: BattleScene = _scene(_setup("enc_f1_a2"))
	assert_true(await _wait_menu(scene))
	var state: BattleState = scene.controller.state
	var actor: Combatant = state.current_actor()
	var target: Combatant = state.living(Combatant.Side.ENEMY)[0]
	var start: ActionEvent = ActionEvent.make(ActionEvent.Type.ACTION_START)
	start.actor_id = actor.id
	start.command = BattleCommand.Kind.ATTACK
	start.skill_id = actor.attack_skill
	start.target_ids = PackedStringArray([target.id])
	var dmg: ActionEvent = ActionEvent.make(ActionEvent.Type.DAMAGE)
	dmg.actor_id = actor.id
	dmg.target_id = target.id
	dmg.amount = 1
	dmg.max_hp = target.max_hp()
	dmg.hp_after = target.hp - 1
	var end: ActionEvent = ActionEvent.make(ActionEvent.Type.TURN_END)
	end.actor_id = actor.id
	var got: Array[ActionEvent] = []
	scene.player.event_played.connect(func(e: ActionEvent) -> void: got.append(e))
	var done: Array[bool] = [false]
	var events: Array[ActionEvent] = [start, dmg, end]
	var run: Callable = func() -> void:
		await scene.player.play(events)
		done[0] = true
	run.call()
	assert_false(done[0], "the melee dash is running")
	scene.stage.call("remove_unit", actor.id)
	assert_true(await wait_until(func() -> bool: return done[0], 900), "playback finishes without the rig")
	assert_eq(got, events, "every event emitted once, in order")
	assert_eq(scene.hud.plate_hp(target.id), target.hp - 1, "the HUD got the hp_after")


func test_invalid_ai_command_falls_back_to_defend() -> void:
	var cmd: BattleCommand = BattleController.safe_ai_command(BadAiState.new(), "e0", false)
	assert_not_null(cmd)
	if cmd != null:
		assert_eq(cmd.to_dict(), BattleCommand.defend("e0").to_dict(), "invalid AI command → Verteidigen")
	var state: BattleState = BattleState.new(_setup("enc_f1_a2"), DB.data)
	state.start()
	var actor: Combatant = state.current_actor()
	var ok: BattleCommand = BattleController.safe_ai_command(state, actor.id, false)
	assert_eq(state.validate(ok), "", "a valid AI command passes unchanged")
	assert_gt(state.submit(ok).size(), 0, "and consumes the turn")
