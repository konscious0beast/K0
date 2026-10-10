extends TestCase
## Full-run bot (02_TECH §11.4.1, scenes/boot/fullrun.gd): arguments (--autoplay=full, --strategy=…, ephemeral
## settings), the pure helpers (path finding over open doors, stick input for camera-relative movement, item scores,
## shopping list, medians, state diffs, report line), the planner on the real Floor 1 in a dry run (tutorial first,
## nearest goal, locked tries, rush strategy) and the story-beat check. The full run itself is tools/fullrun.sh (CI).

const FullRun := preload("res://scenes/boot/fullrun.gd")
const TitleFlow := preload("res://scenes/title/title_flow.gd")
const SCENE_EXPLORATION: String = "res://scenes/exploration/exploration.tscn"
const ROUTER_FIXTURE: String = "res://tests/fixtures/router/router_screen.tscn"
const Rules := preload("res://scenes/exploration/encounter_rules.gd")     # reference values only (test)


func before_each() -> void:
	Engine.time_scale = 8.0
	tree.paused = false


func after_each() -> void:
	Engine.time_scale = 1.0
	for a: StringName in [&"move_forward", &"move_back", &"move_left", &"move_right", &"sneak", &"action"]:
		Input.action_release(a)
	Router.adopt(null)
	Game.timer_running = false
	Sfx.music(&"", 0.0)


## quality-16 (02_TECH §0.3): the bot (M6) no longer preloads M3's private encounter_rules.gd; its own XZ helpers give
## the same results.
func test_bot_geometry_is_its_own_and_matches_the_exploration_rules() -> void:
	var src: String = (FullRun as GDScript).source_code
	if src != "":
		assert_false(src.contains("preload(\"res://scenes/exploration/"), "no cross-module preload of a private M3 helper")
	var pts: Array[Vector3] = [Vector3(1.0, 0.5, 2.0), Vector3(-2.0, 3.0, 6.0), Vector3(0.3, -1.0, -4.5)]
	for a: Vector3 in pts:
		for b: Vector3 in pts:
			assert_almost(FullRun._flat_dist(a, b), Rules.flat_dist(a, b), 0.00001, "flat_dist")
			assert_true(FullRun._flat_dir(a, b).is_equal_approx(Rules.flat_dir(a, b)), "flat_dir")
		var dir: Vector3 = Rules.flat_dir(Vector3.ZERO, a)
		assert_almost(FullRun._yaw_of(dir), Rules.yaw_of(dir), 0.00001, "yaw_of")
		var basis: Basis = Basis(Vector3.UP, Rules.yaw_of(dir)).rotated(Vector3.RIGHT, 0.2)
		assert_true(FullRun._flat_forward(basis).is_equal_approx(Rules.flat_forward(basis)), "flat_forward")


func _bot() -> Node:
	var bot: Node = FullRun.new()
	bot.set("dry_run", true)
	add_to_tree(bot)
	return bot


func _floor1() -> FloorLayout:
	var def: FloorDef = DB.floor_def(1)
	return DungeonGenerator.generate(def, SeedUtil.derive(4242, "floor", 1))


func test_arguments_select_the_full_run_and_keep_settings_ephemeral() -> void:
	var a: Dictionary = TitleFlow.parse_args(PackedStringArray(["--autoplay=full", "--seed=7"]))
	assert_true(bool(a["autoplay"]))
	assert_eq(str(a["autoplay_mode"]), "full")
	assert_eq(int(a["seed"]), 7)
	assert_eq(str(TitleFlow.parse_args(PackedStringArray(["--autoplay"]))["autoplay_mode"]), "smoke",
		"plain --autoplay stays the check.sh smoke run")
	assert_eq(str(TitleFlow.parse_args(PackedStringArray(["--autoplay=what"]))["autoplay_mode"]), "smoke",
		"unknown mode → smoke")
	assert_eq(str(TitleFlow.parse_args(PackedStringArray())["autoplay_mode"]), "")
	# Regression: Game only knew "--autoplay" and read/wrote user://settings.cfg in a --autoplay=full run.
	assert_true(Game.is_ephemeral_args(PackedStringArray(["--autoplay=full"]), PackedStringArray()))
	assert_true(Game.is_ephemeral_args(PackedStringArray(["--autoplay"]), PackedStringArray()))
	assert_true(Game.is_ephemeral_args(PackedStringArray(["--capture"]), PackedStringArray()))
	assert_true(Game.is_ephemeral_args(PackedStringArray(), PackedStringArray(["-s", "res://tests/run_tests.gd"])))
	assert_false(Game.is_ephemeral_args(PackedStringArray(["--seed=3"]), PackedStringArray(["--path", "."])))
	assert_eq(FullRun.strategy_from_args(PackedStringArray()), "thorough")
	assert_eq(FullRun.strategy_from_args(PackedStringArray(["--strategy=rush"])), "rush")
	assert_eq(FullRun.strategy_from_args(PackedStringArray(["--strategy=dawdle"])), "dawdle")
	assert_eq(FullRun.strategy_from_args(PackedStringArray(["--strategy=nope"])), "thorough")
	assert_eq(FullRun.strategy_from_args(PackedStringArray(["--strategy=typical"])), "typical")
	assert_eq(FullRun.pace_from_args(PackedStringArray()), "fast")
	assert_eq(FullRun.pace_from_args(PackedStringArray(["--strategy=rush", "--pace=human"])), "human")
	assert_eq(FullRun.pace_from_args(PackedStringArray(["--pace=slow"])), "fast", "unknown pace → fast")


func test_find_path_follows_open_doors_gates_and_blocks() -> void:
	var layout: FloorLayout = _floor1()
	var none: Array[Vector2i] = []
	assert_eq(FullRun.find_path(layout, layout.start, layout.stairs, PackedStringArray(), none), [] as Array[Vector2i],
		"Gleis 9 is behind the closed key gate")
	var p: Array[Vector2i] = FullRun.find_path(layout, layout.start, layout.stairs, PackedStringArray(["1,3,N"]), none)
	assert_eq(p, [Vector2i(1, 7), Vector2i(1, 6), Vector2i(1, 5), Vector2i(1, 4), Vector2i(1, 3), Vector2i(1, 2),
		Vector2i(1, 1), Vector2i(1, 0)] as Array[Vector2i], "main path through the opened gate")
	var to_qb: Array[Vector2i] = FullRun.find_path(layout, layout.start, layout.quarter_boss, PackedStringArray(), none)
	assert_true(to_qb.has(Vector2i(6, 3)), "without the lever gate the way into C leads through the pump house")
	var short: Array[Vector2i] = FullRun.find_path(layout, layout.start, layout.quarter_boss,
		PackedStringArray(["4,3,N"]), none)
	assert_lt(short.size(), to_qb.size(), "the lever gate is a shortcut")
	var blocked: Array[Vector2i] = [Vector2i(4, 1)]
	assert_eq(FullRun.find_path(layout, layout.start, layout.quarter_boss, PackedStringArray(), blocked),
		[] as Array[Vector2i], "a blocked room on the only way → unreachable")
	for i in range(1, p.size()):
		assert_has(layout.neighbors(p[i - 1], PackedStringArray(["1,3,N"])), p[i], "each step is a door")


func test_steer_input_reproduces_the_world_direction() -> void:
	assert_true(FullRun.steer_input(Vector3(0, 0, -1), 0.0).is_equal_approx(Vector2(0, -1)), "north = forward")
	assert_eq(FullRun.steer_input(Vector3.ZERO, 1.0), Vector2.ZERO)
	var rng: RandomNumberGenerator = make_rng(5)
	for i in 20:
		var a: float = rng.randf_range(-PI, PI)
		var yaw: float = rng.randf_range(-PI, PI)
		var dir: Vector3 = Vector3(sin(a), 0.0, cos(a))
		var v: Vector2 = FullRun.steer_input(dir, yaw)
		assert_almost(v.length(), 1.0, 0.0001, "stick at full deflection")
		var moved: Vector3 = Vector3(v.x, 0.0, v.y).rotated(Vector3.UP, yaw)
		assert_true(moved.is_equal_approx(dir), "PlayerController direction (input rotated by camera yaw) = dir")


func test_helpers_scores_median_diff_and_texts() -> void:
	assert_eq(FullRun.item_score(""), -1, "empty slot")
	assert_eq(FullRun.item_score("itm_wpn_mop"), 5, "1 + str 4")
	assert_eq(FullRun.item_score("itm_acc_rubber_boots"), 1, "stat-less accessory beats an empty slot")
	assert_gt(FullRun.item_score("itm_wpn_fire_axe"), FullRun.item_score("itm_wpn_pipe_wrench"))
	assert_eq(FullRun.median([] as Array[int]), 0.0)
	assert_eq(FullRun.median([3, 1, 2] as Array[int]), 2.0)
	assert_eq(FullRun.median([4, 1, 3, 2] as Array[int]), 2.5)
	assert_eq(FullRun.dict_diff({"a": 1, "b": {"c": 2}}, {"a": 1, "b": {"c": 2}}), "")
	var d: String = FullRun.dict_diff({"a": 1, "b": {"c": 2, "d": 1}}, {"a": 1, "b": {"c": 3, "d": 1}, "e": true})
	assert_has(d, "b.c: 2 != 3")
	assert_has(d, "e: null != true")
	assert_eq(FullRun.objective_text({"kind": "chest", "id": "f1_c3", "cell": Vector2i(1, 3), "why": "wood"}),
		"chest f1_c3 (1,3) [wood]")


func test_shopping_list_buys_upgrades_then_bandages() -> void:
	Game.new_game(0, "Kai", 4242)
	Game.state.inventory.remove("itm_bandage", Game.state.inventory.count("itm_bandage"))    # start kit has 3
	Game.state.inventory.credits = 30
	var bot: Node = _bot()
	assert_eq(bot.call("shopping_list", "sr_kiosk"), [["itm_bandage", 1]] as Array[Array],
		"30 Cr: one bandage (25 Cr), no equipment")
	Game.state.inventory.credits = 2000
	var plan: Array = bot.call("shopping_list", "sr_kiosk")
	var ids: PackedStringArray = []
	for e: Variant in plan:
		ids.append(str((e as Array)[0]))
	assert_has(ids, "itm_wpn_pipe_wrench", "Kai's weapon upgrade (str 8 > mop 4)")
	assert_has(ids, "itm_arm_velvet_cape", "Mopsula's armour upgrade")
	assert_false(ids.has("itm_wpn_collar_leather"), "nothing worse than the equipped item")
	assert_eq(str((plan.back() as Array)[0]), "itm_bandage", "bandages last")
	Game.state.inventory.add("itm_bandage", 3)
	var plan2: Array = bot.call("shopping_list", "sr_kiosk")
	for e: Variant in plan2:
		assert_ne(str((e as Array)[0]), "itm_bandage", "already 3 bandages")


func test_planner_on_floor_1() -> void:
	Game.new_game(0, "Kai", 4242)
	var ex: ExplorationScene = (load(SCENE_EXPLORATION) as PackedScene).instantiate() as ExplorationScene
	ex.auto_start_battle = false
	add_to_tree(ex)
	await wait_frames(2)
	var bot: Node = _bot()
	var obj: Dictionary = bot.call("next_objective")
	assert_eq(str(obj["kind"]), "group")
	assert_eq(str(obj["id"]), "f1_g0", "the tutorial fight comes first")
	Game.state.floor_run.defeated_groups.append("f1_g0")
	obj = bot.call("next_objective")
	assert_eq(obj["cell"], Vector2i(1, 6), "then the nearest open goal (the unvisited tutorial corridor)")
	var cands: Array[Dictionary] = bot.call("candidates", ex.get_layout(), Game.state.floor_run, {})
	var texts: PackedStringArray = []
	for c: Dictionary in cands:
		texts.append(FullRun.objective_text(c))
		var cell: Vector2i = c["cell"]
		assert_ne(cell, ex.get_layout().quarter_boss, "boss rooms are no regular goal")
	assert_has(texts, "chest f1_c12 (4,1) [%s]" % FullRun.TRY_LOCKED, "locked chest is tried once without key")
	assert_has(texts, "gate 1,3,N (1,3) [%s]" % FullRun.TRY_LOCKED, "key gate is tried once without key")
	assert_has(texts, "safe sr_kiosk (2,5) [first visit]")
	assert_false(texts.has("chest f1_c12 (4,1) [locked]"), "no real opening without the key")
	bot.set("strategy", "rush")
	var rush: Array[Dictionary] = bot.call("candidates", ex.get_layout(), Game.state.floor_run, {})
	for c: Dictionary in rush:
		assert_true(str(c["kind"]) == "safe" or str(c["kind"]) == "gate", "rush: only safe rooms and gates")
	bot.set("strategy", "typical")
	var groups: PackedStringArray = []
	var typical: Array[Dictionary] = bot.call("candidates", ex.get_layout(), Game.state.floor_run, {})
	for c: Dictionary in typical:
		if str(c["kind"]) == "group":
			groups.append(str(c["id"]))
	assert_len(groups, 11, "typical: 12 of the 15 regular groups (the tutorial is already defeated)")
	for gid: String in FullRun.TYPICAL_SKIP:
		assert_false(groups.has(gid), "typical leaves %s alone" % gid)
	bot.set("grind_fights", 2)
	var wait: Dictionary = bot.call("next_objective")
	assert_eq(str(wait["kind"]), "wait", "grinding after a boss defeat without a living stray: wait for one")


func test_story_beats_check() -> void:
	var bot: Node = _bot()
	var ok_tags: PackedStringArray = ["first_fight@before", "floor_start@countdown", "safe_room_enter@countdown",
		"scene:scn_mop_1@countdown", "boss_intro:enm_boss_hausmeister@countdown", "stairs_found@countdown",
		"floor_end@countdown"]
	bot.set("mod_tags", ok_tags)
	assert_true(bool(bot.call("check_story_beats")), "all GDD beats, floor_start once with the countdown")
	var early: PackedStringArray = ok_tags.duplicate()
	early.insert(0, "floor_start@before")
	var bot2: Node = _bot()
	bot2.set("mod_tags", early)
	assert_false(bool(bot2.call("check_story_beats")))
	assert_has(str(bot2.get("result_line")), "before the countdown started", "regression: line over title / intro")
	var missing: PackedStringArray = ok_tags.duplicate()
	missing.remove_at(missing.find("stairs_found@countdown"))
	var bot3: Node = _bot()
	bot3.set("mod_tags", missing)
	assert_false(bool(bot3.call("check_story_beats")))
	assert_has(str(bot3.get("result_line")), "'stairs_found' never played")
	assert_has(str(bot3.get("result_line")), "Assertion failed: FULLRUN failed in", "ERR_RE line of tools/fullrun.sh")


func test_report_lines() -> void:
	Game.new_game(0, "Kai", 4242)
	var bot: Node = _bot()
	bot.set("summary", {"time_used_sec": 240, "time_left_sec": 960, "kills": 40, "viewers_peak": 9000})
	var b: Array[Dictionary] = [
		{"enc": "enc_f1_a1_tutorial", "group": "f1_g0", "outcome": "victory", "boss": false, "party_turns": 3,
			"turns": 3, "hp_loss_pct": 0},
		{"enc": "enc_f1_a2", "group": "f1_g1", "outcome": "victory", "boss": false, "party_turns": 6, "turns": 12,
			"hp_loss_pct": 40},
		{"enc": "enc_f1_b1", "group": "f1_s0", "outcome": "victory", "boss": false, "party_turns": 4, "turns": 6,
			"hp_loss_pct": 10},
		{"enc": "enc_f1_boss_hausmeister", "group": "f1_qb", "outcome": "defeat", "boss": true, "party_turns": 9,
			"turns": 14, "hp_loss_pct": 100, "gifts": 1},
		{"enc": "enc_f1_boss_hausmeister", "group": "f1_qb", "outcome": "victory", "boss": true, "party_turns": 18,
			"turns": 28, "hp_loss_pct": 90, "gifts": 2},
	]
	b[1]["hype_start"] = 30
	b[1]["hype_end"] = 52
	b[1]["gifts"] = 1
	bot.set("battles", b)
	bot.set("deaths", 1)
	var line: String = bot.call("ok_line")
	assert_true(line.begins_with("FULLRUN: OK floor_time=240 battles=5 level=1/1 deaths=1 frames="), line)
	var st: Dictionary = bot.call("stats")
	assert_eq(int(st["regular_battles"]), 2, "tutorial and bosses are no regular battles")
	assert_eq(int(st["strays"]), 1)
	assert_eq(int(st["groups_defeated"]), 2, "f1_g0 + f1_g1 (strays and bosses not counted)")
	assert_eq(float(st["party_turns_median"]), 5.0)
	assert_eq(int((st["boss_party_turns"] as Dictionary)["enc_f1_boss_hausmeister"]), 18)
	assert_eq(int(st["floor_time_used_sec"]), 240)
	assert_eq(st["boss_outcomes"], {"enc_f1_boss_hausmeister": ["defeat", "victory"]}, "every boss attempt, in order")
	assert_eq(int(st["gifts_regular"]), 1)
	assert_eq(int(st["gifts_boss"]), 3)
	assert_eq(float(st["hype_end_median"]), 26.0, "regular battles only (missing values count as 0)")
	assert_eq(str(st["pace"]), "fast")


func test_clear_saves_only_touches_the_bot_directory() -> void:
	var dir: String = ProjectSettings.globalize_path(FullRun.SAVE_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	var f: FileAccess = FileAccess.open(dir.path_join("slot_1.json"), FileAccess.WRITE)
	f.store_string("{}")
	f.close()
	FullRun.clear_saves()
	assert_false(FileAccess.file_exists(dir.path_join("slot_1.json")), "bot saves removed")
	assert_ne(Save.save_dir, FullRun.SAVE_DIR, "a dry run never redirects the real save directory")
	DirAccess.remove_absolute(dir)


## A lost battle, deterministic and independent of the seed (the bot loses bosses only now and then since the GDD §13
## balancing, ~20 % / ~35 % on the first try). Real screens:
## exploration (saved in slot 1) → boss battle at 1 HP with auto battle → DEFEAT → Sendeschluss (reason defeat,
## game_overs +1 in the slot) → "Letzten Spielstand laden" → exploration with the saved party and the countdown grace.
func test_lost_battle_game_over_and_load_last() -> void:
	var prev_dir: String = Save.save_dir
	var prev_autoplay: bool = Game.autoplay
	Save.save_dir = "user://test_m6_fullrun/saves"
	Game.autoplay = true                     # battle speed 4, results continue on their own
	Game.auto_battle = true
	Game.new_game(1, "Kai", 4242)
	assert_eq(Save.save_slot(1), OK, "saved in slot 1 (location start)")
	var ex: ExplorationScene = (load(SCENE_EXPLORATION) as PackedScene).instantiate() as ExplorationScene
	add_to_tree(ex)
	await wait_frames(2)
	for m: PartyMember in Game.state.party:
		m.hp = 1
	var setup: BattleSetup = Game.make_battle_setup("enc_f1_boss_rattenkoenigin", 0, "f1_fb")
	Router.start_battle(setup)
	var lost: bool = await wait_until(func() -> bool: return Router.current != null and not Router.busy \
		and Router.current.scene_file_path == Router.SCENE_GAME_OVER, 3000)
	assert_true(lost, "a lost battle ends on the Sendeschluss screen")
	if lost:
		var go: Node = Router.current
		assert_eq(StringName(str(go.get("reason"))), &"defeat")
		assert_false(Game.in_battle, "Game left battle mode")
		assert_eq(int((Save.slot_summary(1)).get("slot", 0)), 1)
		var ready: bool = await wait_until(func() -> bool: return bool(go.call("buttons_ready")), 600)
		assert_true(ready and bool(go.call("can_load")), "\"Letzten Spielstand laden\" offered")
		go.call("load_last")
		var back: bool = await wait_until(func() -> bool: return Router.current is ExplorationScene \
			and not Router.busy, 600)
		assert_true(back, "loading routes back into the exploration")
		for m: PartyMember in Game.state.party:
			assert_gt(m.hp, 1, "party as saved (full HP), not the lost battle's")
		assert_true(Game.state.floor_run.time_left_ticks >= Save.GRACE_SECONDS * Game.TICKS_PER_SEC)
		var raw: Variant = JsonUtil.read_file(Save.slot_path(1))
		var overs: int = int(((((raw as Dictionary).get("state", {}) as Dictionary).get("show", {}) as Dictionary)
			.get("stats", {}) as Dictionary).get("game_overs", 0))
		assert_eq(overs, 1, "Sendeschluss counted in the slot (Save.record_game_over)")
	# Leave the Router with a disposable screen, like the exploration tests do.
	Router.goto(ROUTER_FIXTURE, {}, Router.Transition.NONE)
	await wait_until(func() -> bool: return not Router.busy, 300)
	var cur: Node = Router.current
	if cur != null and is_instance_valid(cur) and cur.scene_file_path == ROUTER_FIXTURE:
		if cur.get_parent() != null:
			cur.get_parent().remove_child(cur)
		cur.free()
	Save.delete_slot(1)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.save_dir))
	Save.save_dir = prev_dir
	if Game.state != null:
		Game.state.slot = 0                 # never let a later test autosave into the real user://saves slot 1
	Game.autoplay = prev_autoplay
	Game.auto_battle = false
