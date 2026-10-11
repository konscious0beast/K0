extends TestCase
## 06 §2.7 / §8.2 (package A): E1 secrets — one Kulissenwand (sewer (5,3) ↔ cellar (5,2), a closed door until the field
## strike or the bark knocks it over) and three Regie-Notizen (+15 followers once each, M.O.D. secret_note:<n>; note 2
## hangs behind the wall). Rules (Secrets), the recorded command "secret" (Game.open_secret, RunSim, both replays,
## save), the data rules (validators/secrets.gd), the scene (strike and bark open the wall, "Interagieren" never does,
## notes, loading), the minimap (a standing wall is drawn as wall), the floor summary row and the bot's planner.

const SCENE: String = "res://scenes/exploration/exploration.tscn"
const ROUTER_FIXTURE: String = "res://tests/fixtures/router/router_screen.tscn"
const Rules := preload("res://scenes/exploration/encounter_rules.gd")
const MinimapScript := preload("res://scenes/ui/minimap.gd")
const FullRun := preload("res://scenes/boot/fullrun.gd")
const WALL: String = "sec_e1_wall_sewer"
const WALL_KEY: String = "5,3,N"
const ROOT: String = "user://test_06a_secrets"
const DIR: String = "user://test_06a_secrets/saves"
const MAX_FRAMES: int = 240

var _said: Array[String] = []
var _opened: Array[String] = []
var _gates: Array[Array] = []
var _saved_dir: String = ""
var _saved_ro: bool = true


func before_each() -> void:
	Engine.time_scale = 8.0
	_said.clear()
	_opened.clear()
	_gates.clear()
	_saved_dir = Save.save_dir
	_saved_ro = Save.read_only
	Events.mod_said.connect(_on_said)
	Events.secret_opened.connect(_on_opened)
	Events.gate_opened.connect(_on_gate)


func after_each() -> void:
	Engine.time_scale = 1.0
	for sig: Array in [[Events.mod_said, _on_said], [Events.secret_opened, _on_opened], [Events.gate_opened, _on_gate]]:
		if (sig[0] as Signal).is_connected(sig[1]):
			(sig[0] as Signal).disconnect(sig[1])
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
	Save.save_dir = _saved_dir
	Save.read_only = _saved_ro
	_rmrf(ROOT)
	Game.timer_running = false
	Sfx.music(&"", 0.0)
	Game.state = null
	Game.run_log = null
	Game.sim = null
	Game.in_battle = false


func _on_said(_text: String, _voice: StringName, tag: String, _blocking: bool) -> void:
	_said.append(tag)


func _on_opened(id: String) -> void:
	_opened.append(id)


func _on_gate(cell: Vector2i, dir: int) -> void:
	_gates.append([cell, dir])


static func _rmrf(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for f: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	for sub: String in DirAccess.get_directories_at(path):
		_rmrf(path.path_join(sub))
	DirAccess.remove_absolute(path)


func _cmds(t: String) -> Array:
	return Game.run_log.cmds().filter(func(c: Dictionary) -> bool: return str((c["c"] as Dictionary)["t"]) == t)


# --- data + rules ----------------------------------------------------------------------------------------------------

func test_floor_1_secrets_in_the_data() -> void:
	var def: FloorDef = real_data().floor_def(1)
	var list: Array[Dictionary] = Secrets.list(def)
	var walls: Array = list.filter(func(s: Dictionary) -> bool: return s["kind"] == "wall")
	var notes: Array = list.filter(func(s: Dictionary) -> bool: return s["kind"] == "note")
	assert_eq(walls.size(), 1, "E1: one Kulissenwand (06 §2.7)")
	assert_eq(notes.size(), 3, "E1: three Regie-Notizen")
	assert_eq(Secrets.gate_key_of(walls[0]), WALL_KEY, "between the sewer (5,3) and the cellar (5,2)")
	assert_eq(notes.map(func(s: Dictionary) -> int: return int(s["n"])), [1, 2, 3])
	assert_eq(str(Secrets.find(def, "sec_e1_note_2").get("behind", "")), WALL, "note 2 hangs behind the wall")
	var layout: FloorLayout = DungeonGenerator.generate(def, 4242)
	var g: Dictionary = layout.gate_by_key(WALL_KEY)
	assert_eq(str(g.get("requires", "")), "secret:" + WALL, "the wall is a closed door of the layout")
	assert_eq(layout.validate(), PackedStringArray())


func test_rules_check_open_and_open() -> void:
	Game.new_game(0, "Kai", 4242)
	var def: FloorDef = Game.floor_def()
	var st: GameState = Game.state
	assert_eq(Secrets.check_open(st, def, "sec_e1_nope"), "unknown_secret")
	assert_eq(Secrets.check_open(st, def, "sec_e1_note_2"), "locked", "behind the standing wall")
	assert_eq(Secrets.check_open(null, def, WALL), "no_floor")
	assert_eq(Secrets.check_open(st, def, WALL), "")
	var fx: Dictionary = Secrets.open(st, def, WALL)
	assert_eq(fx["kind"], "wall")
	assert_eq(fx["gate_key"], WALL_KEY)
	assert_eq(fx["mod_tag"], "secret_wall")
	assert_eq(fx["followers"], 0)
	assert_has(st.floor_run.opened_gates, WALL_KEY, "the door is open now")
	assert_eq(Secrets.opened(st), PackedStringArray([WALL]), "flags[\"secrets\"]")
	assert_eq(Secrets.check_open(st, def, WALL), "already_open")
	assert_eq(Secrets.open(st, def, WALL), {}, "a refused opening changes nothing")
	assert_eq(Secrets.check_open(st, def, "sec_e1_note_2"), "", "note 2 can be read now")
	var fx2: Dictionary = Secrets.open(st, def, "sec_e1_note_2")
	assert_eq(fx2["followers"], Secrets.NOTE_FOLLOWERS)
	assert_eq(fx2["mod_tag"], "secret_note:2")
	assert_eq(Secrets.notes_found(st, def), Vector2i(1, 3))
	assert_true(StateHash.hash_input(st)["flags"].has("secrets"), "secrets are part of the state hash")


func test_wall_blocks_the_door_until_it_falls() -> void:
	Game.new_game(0, "Kai", 4242)
	var layout: FloorLayout = DungeonGenerator.generate(Game.floor_def(), Game.state.floor_run.seed)
	var fr: FloorRun = Game.state.floor_run
	assert_false(layout.neighbors(Vector2i(5, 3), fr.opened_gates).has(Vector2i(5, 2)), "closed: no way through")
	assert_true(layout.linked(Vector2i(5, 3)).has(Vector2i(5, 2)), "but a door of the room graph")
	var mm: Control = MinimapScript.new()
	mm.call("bind", layout, [Vector2i(5, 3), Vector2i(5, 2)] as Array[Vector2i])
	assert_true(bool(mm.call("_closed_secret", Vector2i(5, 3), RoomCell.DOOR_N, fr.opened_gates)),
		"minimap: drawn as wall while it stands")
	assert_true(bool(mm.call("_closed_secret", Vector2i(5, 2), RoomCell.DOOR_S, fr.opened_gates)), "from both sides")
	assert_true(Game.open_secret(WALL))
	assert_true(layout.neighbors(Vector2i(5, 3), fr.opened_gates).has(Vector2i(5, 2)), "open: a shortcut")
	assert_false(bool(mm.call("_closed_secret", Vector2i(5, 3), RoomCell.DOOR_N, fr.opened_gates)), "a plain door")
	mm.free()
	var display: FloorLayout = MinimapScript.layout_from_def(Game.floor_def())
	assert_eq(str(display.gate_by_key(WALL_KEY).get("requires", "")), "secret:" + WALL, "display copy knows the wall")


# --- Game.open_secret: record, show, replay, save --------------------------------------------------------------------

func test_open_secret_records_and_pays_once() -> void:
	Game.new_game(0, "Kai", 4242)
	var f0: int = Game.state.show.followers
	var n: int = Game.run_log.cmds().size()
	assert_false(Game.open_secret("sec_e1_note_2"), "locked behind the wall")
	assert_false(Game.open_secret("sec_e1_unknown"))
	assert_eq(Game.run_log.cmds().size(), n, "refusals are not recorded")
	assert_true(Game.open_secret("sec_e1_note_1"))
	assert_eq(Game.state.show.followers, f0 + 15, "+15 followers (06 §2.7)")
	assert_has(_said, "secret_note:1", "M.O.D. reads the note")
	assert_eq(_opened, ["sec_e1_note_1"] as Array[String], "secret_opened")
	assert_eq((_cmds("secret").back()["c"] as Dictionary), {"t": "secret", "id": "sec_e1_note_1"}, "recorded")
	assert_false(Game.open_secret("sec_e1_note_1"), "only once")
	assert_eq(Game.state.show.followers, f0 + 15, "no second payout")
	assert_true(Game.open_secret(WALL))
	assert_has(_said, "secret_wall")
	assert_true(Game.open_secret("sec_e1_note_2"), "readable once the wall fell")
	assert_eq(Game.secret_notes(), Vector2i(2, 3))
	assert_eq(_cmds("secret").size(), 3)
	assert_eq(Game.run_log.validate(), PackedStringArray(), "secret commands pass the log schema")


func test_replay_and_runsim_verify_secret_commands() -> void:
	Game.new_game(0, "Kai", 4242)
	assert_true(Game.open_secret("sec_e1_note_1"))
	assert_true(Game.open_secret(WALL))
	assert_true(Game.open_secret("sec_e1_note_2"))
	var live: String = StateHash.of(Game.state)
	var rep: Dictionary = Game.replay_log(Game.run_log, Game.sim.tick())
	assert_eq(rep["final_hash"], live, "Game.replay_log: same StateHash with secret commands")
	assert_eq(rep["mismatch_at"], -1)
	# RunSim: identical core rules (without the show part: followers come from Show, like the floor events)
	var data: GameData = real_data()
	var st: GameState = GameState.create_new(data, 0, "Kai", 515, &"prime")
	var sim: RunSim = RunSim.new(data, st, {})
	var rl: RunLog = RunLog.new()
	rl.header = {"schema": 1, "seed": 515, "slot": 0, "player_name": "Kai", "difficulty": "prime", "mode": "campaign",
		"sim_hz": RunSim.TICKS_PER_SEC, "event_id": "", "run_id": "run_secret_515"}
	sim.run_log = rl
	sim.apply({"t": "floor", "floor": 1})
	sim.apply({"t": "secret", "id": "sec_e1_note_2"})
	assert_eq(sim.rejected_cmds.back()["reason"], "locked", "RunSim refuses like the live game")
	assert_eq(sim.rejected_cmds.back()["gift_id"], "sec_e1_note_2")
	sim.apply({"t": "secret", "id": WALL})
	assert_has(st.floor_run.opened_gates, WALL_KEY)
	sim.apply({"t": "secret", "id": "sec_e1_note_2"})
	assert_eq(Secrets.opened(st), PackedStringArray([WALL, "sec_e1_note_2"]))
	sim.apply({"t": "secret", "id": WALL})
	assert_eq(sim.rejected_cmds.back()["reason"], "already_open")
	var h: String = sim.close("test")
	var res: Dictionary = RunSim.replay(data, rl)
	assert_eq(res["final_hash"], h, "RunSim.replay → same hash")
	assert_eq(res["errors"], PackedStringArray(), "refused commands were never recorded")


func test_save_round_trip_keeps_the_secrets() -> void:
	_rmrf(ROOT)
	Save.save_dir = DIR
	Save.read_only = false
	Game.new_game(1, "Lena", 616)
	assert_true(Game.open_secret(WALL))
	assert_true(Game.open_secret("sec_e1_note_3"))
	Game.enter_safe_room("sr_kiosk")
	var before: String = StateHash.of(Game.state)
	assert_eq(Save.save_slot(1), OK)
	Game.state = null
	assert_eq(Save.load_slot(1), OK)
	assert_eq(Secrets.opened(Game.state), PackedStringArray([WALL, "sec_e1_note_3"]), "flags.secrets survive")
	assert_has(Game.state.floor_run.opened_gates, WALL_KEY, "the open door survives")
	assert_eq(StateHash.of(Game.state).length(), before.length())
	assert_false(Game.open_secret("sec_e1_note_3"), "a read note stays read after loading")


# --- data rules ------------------------------------------------------------------------------------------------------

func _raw_real() -> Dictionary:
	var raw: Dictionary = {}
	for t: String in GameData.TABLES:
		raw[t] = JsonUtil.read_file("res://data".path_join(t + ".json"))
	return raw


func _secrets_of(raw: Dictionary) -> Array:
	for e: Dictionary in (raw["floors"] as Dictionary)["entries"]:
		if str(e["id"]) == "floor_1":
			return (e["layout"] as Dictionary)["secrets"]
	return []


func _errors_with(change: Callable) -> String:
	var raw: Dictionary = _raw_real()
	change.call(_secrets_of(raw), raw)
	var d: GameData = GameData.new()
	d.load_from_tables(raw)
	return "\n".join(d.errors)


func test_validator_rules_for_secrets() -> void:
	assert_eq(_errors_with(func(_s: Array, _r: Dictionary) -> void: pass), "", "the real data is valid")
	assert_has(_errors_with(func(s: Array, _r: Dictionary) -> void: s[0]["id"] = "wall_x"), "must match sec_e1_")
	assert_has(_errors_with(func(s: Array, _r: Dictionary) -> void: s[1]["id"] = WALL), "duplicate secret id")
	assert_has(_errors_with(func(s: Array, _r: Dictionary) -> void: s[0]["kind"] = "door"), "not in [wall, note]")
	assert_has(_errors_with(func(s: Array, _r: Dictionary) -> void:
		s[0]["cell"] = [5, 2]
		s[0]["dir"] = "N"), "has no door N")
	assert_has(_errors_with(func(s: Array, _r: Dictionary) -> void: s[0]["cell"] = [7, 7]), "no cell at")
	assert_has(_errors_with(func(s: Array, _r: Dictionary) -> void:
		s[0]["cell"] = [1, 3]
		s[0]["dir"] = "N"), "already has a gate")
	assert_has(_errors_with(func(s: Array, _r: Dictionary) -> void: s[1]["offset"] = [5.0, 0.0]), "must be <= 4.5")
	assert_has(_errors_with(func(s: Array, _r: Dictionary) -> void: s[3]["n"] = 1), "duplicate note number 1")
	assert_has(_errors_with(func(s: Array, _r: Dictionary) -> void: s[2]["behind"] = "sec_e1_none"),
		"is not a wall of this floor")
	assert_has(_errors_with(func(s: Array, _r: Dictionary) -> void: s[3]["unknown"] = 1), "unknown key")
	# a wall on the only door of a dead end would make the secret mandatory
	assert_has(_errors_with(func(s: Array, _r: Dictionary) -> void:
		s[0]["cell"] = [6, 0]
		s[0]["dir"] = "S"), "only reachable through a secret wall")


# --- scene -----------------------------------------------------------------------------------------------------------

func _make_scene(hero: String, prepare: Callable = Callable()) -> ExplorationScene:
	Game.new_game(0, "Kai", 4242, &"prime", hero)
	Game.state.floor_run.defeated_groups.append("f1_g7")     # the patrol of (5,3) stays out of the way
	if prepare.is_valid():
		prepare.call()
	var scene: ExplorationScene = (load(SCENE) as PackedScene).instantiate() as ExplorationScene
	scene.auto_start_battle = false
	add_to_tree(scene)
	await wait_frames(6)
	return scene


## The hero `dist` m in front of the Kulissenwand on the sewer side (5,3), looking at it.
func _before_wall(scene: ExplorationScene, dist: float, aside: float = 0.0) -> Node3D:
	var w: Node3D = scene.get_wall(WALL)
	var out: Vector3 = w.global_transform.basis.z.normalized()
	var side: Vector3 = w.global_transform.basis.x.normalized()
	scene.get_player().teleport(w.global_position + out * dist + side * aside + Vector3(0.0, 0.05, 0.0),
		Rules.yaw_of(-out))
	return w


func test_kai_knocks_the_wall_over_with_the_strike() -> void:
	var scene: ExplorationScene = await _make_scene("kai")
	var w: Node3D = scene.get_wall(WALL)
	assert_not_null(w, "the wall stands in the door (5,3)N")
	if w == null:
		return
	assert_eq(scene.standing_walls(), PackedStringArray([WALL]))
	assert_eq(str(w.call("prompt_text")), "", "no prompt: never focused")
	_before_wall(scene, 1.3)
	await wait_frames(4)
	assert_null(scene.focused_interactable(), "nothing to interact with in front of the wall")
	scene.perform_action()
	assert_true(await wait_until(func() -> bool: return Secrets.is_open(Game.state, WALL), MAX_FRAMES),
		"the field strike knocks it over")
	assert_true(bool(w.get("opened")))
	await wait_frames(12)
	var panel: Node3D = w.get("panel") as Node3D
	var away: Vector3 = Rules.flat_dir(scene.get_player_position(), w.global_position)
	assert_gt(panel.global_transform.basis.y.dot(away), 0.3, "the panel tips away from the hero")
	assert_eq(_cmds("secret").size(), 1, "recorded once")
	assert_eq(_gates, [[Vector2i(5, 3), RoomCell.DOOR_N]], "gate_opened for the minimap / log")
	assert_true(scene.get_layout().neighbors(Vector2i(5, 3), Game.state.floor_run.opened_gates).has(Vector2i(5, 2)))
	assert_eq(scene.standing_walls(), PackedStringArray())
	# the door is walkable now: walk through into the cellar
	scene.get_player().teleport(w.global_position + w.global_transform.basis.z * 1.0 + Vector3(0, 0.05, 0),
		Rules.yaw_of(-w.global_transform.basis.z))
	Input.action_press(&"move_forward", 1.0)
	var through: bool = await wait_until(func() -> bool: return scene.get_player_cell() == Vector2i(5, 2), MAX_FRAMES)
	Input.action_release(&"move_forward")
	assert_true(through, "Kai walks through the opening")


func test_mopsula_barks_the_wall_over_from_three_metres() -> void:
	var scene: ExplorationScene = await _make_scene("mopsula")
	var w: Node3D = _before_wall(scene, 3.0, 0.8)
	await wait_frames(4)
	scene.perform_action()
	assert_true(await wait_until(func() -> bool: return Secrets.is_open(Game.state, WALL), MAX_FRAMES),
		"the bark knocks it over (06 §2.7: a second use for the bark)")
	assert_true(bool(w.get("opened")))


func test_interact_never_opens_the_wall() -> void:
	var scene: ExplorationScene = await _make_scene("kai")
	var w: Node3D = _before_wall(scene, 1.3)
	await wait_frames(4)
	w.call("interact")
	await wait_frames(2)
	assert_false(Secrets.is_open(Game.state, WALL), "Interagieren does nothing")
	assert_false(scene.knock_wall("sec_e1_note_1"), "only walls can be knocked over")
	# out of reach: a strike 4 m away does not open it
	_before_wall(scene, 4.0)
	await wait_frames(3)
	scene.perform_action()
	await wait_frames(40)
	assert_false(Secrets.is_open(Game.state, WALL), "the strike reaches 1.8 m")


func test_notes_pay_once_and_the_hidden_note_appears_behind_the_wall() -> void:
	var scene: ExplorationScene = await _make_scene("kai")
	var n1: Node3D = scene.get_interactable("sec_e1_note_1") as Node3D
	var n2: Node3D = scene.get_interactable("sec_e1_note_2") as Node3D
	assert_not_null(n1)
	assert_not_null(n2)
	if n1 == null or n2 == null:
		return
	assert_eq(str(n1.call("prompt_text")), "Regie-Notiz lesen")
	assert_true(bool(n2.get("hidden_behind")), "note 2 hides behind the standing wall")
	assert_eq(str(n2.call("prompt_text")), "", "… without a prompt")
	var f0: int = Game.state.show.followers
	var c: Vector3 = scene.get_layout().cell_to_world(Vector2i(2, 5))
	var toward: Vector3 = Rules.flat_dir(n1.global_position, c)
	scene.get_player().teleport(n1.global_position - toward * 1.0 + Vector3(0.0, 0.05, 0.0), Rules.yaw_of(toward))
	assert_true(await wait_until(func() -> bool: return scene.focused_interactable() == n1, 60), "focus on the note")
	scene.perform_action()
	assert_true(Secrets.is_open(Game.state, "sec_e1_note_1"))
	assert_eq(Game.state.show.followers, f0 + 15)
	assert_eq(str(n1.call("prompt_text")), "", "read: no prompt any more")
	scene.perform_action()
	assert_eq(Game.state.show.followers, f0 + 15, "pays once")
	assert_true(scene.knock_wall(WALL))
	assert_false(bool(n2.get("hidden_behind")), "the fallen wall reveals note 2")
	assert_eq(str(n2.call("prompt_text")), "Regie-Notiz lesen")
	Game.state.hero = "mopsula"
	assert_eq(str(n2.call("prompt_text")), "Regie-Notiz beschnuppern", "the Count sniffs")


func test_a_rebuilt_floor_keeps_opened_secrets() -> void:
	var scene: ExplorationScene = await _make_scene("kai", func() -> void:
		assert_true(Game.open_secret(WALL))
		assert_true(Game.open_secret("sec_e1_note_2")))
	assert_null(scene.get_wall(WALL), "a fallen wall is not rebuilt")
	assert_null(scene.get_interactable("sec_e1_note_2"), "a read note is gone")
	assert_not_null(scene.get_interactable("sec_e1_note_1"), "an unread note stays")
	assert_true(scene.get_layout().neighbors(Vector2i(5, 3), Game.state.floor_run.opened_gates).has(Vector2i(5, 2)))


func test_floor_summary_shows_the_notes() -> void:
	Game.new_game(0, "Kai", 4242)
	assert_true(Game.open_secret("sec_e1_note_3"))
	var fs: Control = (load(Router.SCENE_FLOOR_SUMMARY) as PackedScene).instantiate() as Control
	var summary: Dictionary = Game.state.floor_run.summary()
	summary["regie_notes"] = Game.secret_notes().x
	summary["regie_notes_total"] = Game.secret_notes().y
	fs.call("setup", {"summary": summary})
	add_to_tree(fs)
	await wait_frames(2)
	var rows: Array = fs.call("rows")
	assert_eq(str((rows.back() as Dictionary)["label"]), "Regie-Notizen", "extra row on floors with notes")
	assert_eq(str(fs.call("_fmt_row", 1, "of")), "1/3")
	var plain: Control = (load(Router.SCENE_FLOOR_SUMMARY) as PackedScene).instantiate() as Control
	plain.call("setup", {"summary": Game.state.floor_run.summary()})
	add_to_tree(plain)
	await wait_frames(2)
	assert_eq((plain.call("rows") as Array).size(), FloorSummary.ROWS.size(), "no row without notes")


func test_bot_plans_the_secrets() -> void:
	var scene: ExplorationScene = await _make_scene("kai")
	var bot: Node = FullRun.new()
	bot.set("dry_run", true)
	add_to_tree(bot)
	var fr: FloorRun = Game.state.floor_run
	var texts: PackedStringArray = []
	for c: Dictionary in bot.call("candidates", scene.get_layout(), fr, {}):
		texts.append(FullRun.objective_text(c))
	assert_has(texts, "wall %s (5,3) [Kulissenwand]" % WALL, "thorough knocks the wall over")
	assert_has(texts, "note sec_e1_note_1 (2,5) [Regie-Notiz 1]")
	assert_has(texts, "note sec_e1_note_3 (6,0) [Regie-Notiz 3]")
	assert_false(texts.has("note sec_e1_note_2 (5,2) [Regie-Notiz 2]"), "not while the wall stands")
	for t: String in texts:
		assert_false(t.begins_with("gate " + WALL_KEY), "a Kulissenwand is never tried as a gate")
	bot.set("strategy", "rush")
	for c2: Dictionary in bot.call("candidates", scene.get_layout(), fr, {}):
		assert_false(str(c2["kind"]) == "wall" or str(c2["kind"]) == "note", "rush skips the secrets")
	bot.set("strategy", "thorough")
	assert_true(Game.open_secret(WALL))
	texts.clear()
	for c3: Dictionary in bot.call("candidates", scene.get_layout(), fr, {}):
		texts.append(FullRun.objective_text(c3))
	assert_has(texts, "note sec_e1_note_2 (5,2) [Regie-Notiz 2]", "behind the fallen wall")
	# shortcut bookkeeping: (4,3) → (5,2) runs through the opened wall and saves two cell changes
	var path: Array[Vector2i] = FullRun.find_path(scene.get_layout(), Vector2i(5, 3), Vector2i(5, 2), fr.opened_gates,
		[] as Array[Vector2i])
	assert_eq(path, [Vector2i(5, 3), Vector2i(5, 2)] as Array[Vector2i])
	bot.call("_note_shortcut", scene.get_layout(), fr, path, Vector2i(5, 2))
	assert_eq(int(bot.get("shortcut_trips")), 1)
	assert_eq(int(bot.get("shortcut_cells")), 2, "(5,3) → (6,3) → (6,2) → (5,2) without the wall")
