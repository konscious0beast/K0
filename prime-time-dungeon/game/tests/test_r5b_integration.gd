extends TestCase
## R5b part 1 (07 §12.2 "Stand R5b-1"): the real-time combat in the run around it — a partner tactic changed during a
## combat is kept (BattleResult.rt_presets → PartyMember.rt_preset / rt_toggles in BattleBridge.apply_result: no log
## entry, both verifiers write the same), and event runs fight in the combat mode of their rules (rules.combat.mode,
## part of rules_hash — never the player's setting): the shipped events in real time, through both verifiers, with
## the autopilot refused (rules.combat.autopilot false, 07 §10.7); a log whose header names another mode is reported.
## Replay files are stored compacted; the leaderboard's run_log_hash covers the expanded canonical form (07 §10.3).
## The skills page of a real-time run chooses variants and the partner tactic (one loadout command per choice).

const RtLive := preload("res://tests/fixtures/rt_live/rt_live.gd")
const Harness := preload("res://tests/tools/rt_harness.gd")
const Bot := preload("res://tests/tools/rt_bot_player.gd")
const EVENT_ID: String = "evt_offline_gleis9"
const ROOT: String = "user://test_r5b_integration"

var _read_only: bool = false


func before_each() -> void:
	_read_only = Save.read_only


func after_each() -> void:
	Save.save_dir = "user://saves"
	Save.read_only = _read_only
	_rmrf(ROOT)
	if Game.combat != null:
		Game.end_combat()
	Show.abort_battle()
	Game.state = null
	Game.run_log = null
	Game.sim = null
	Game.quest = null
	Game.mode = &"campaign"
	Game.in_battle = false
	RtLive.restore_data()


# --- the partner tactic of a combat is kept (07 §5.2, §12.2 "Stand R5a" Nr. 9) ----------------------------------------

func test_a_partner_tactic_changed_in_a_combat_is_kept() -> void:
	RtLive.swap_data()
	RtLive.adopt(RtLive.state(6, 20.0, {"itm_smoke": 2}))
	var mop: PartyMember = Game.state.member("mopsula")
	var tog: Dictionary = RtVocab.RT_TOGGLE_DEFAULTS.duplicate()
	tog["potions"] = not bool(tog["potions"])
	var first: RtSetup = Game.make_rt_setup(RtKit.dummy_cmd())
	assert_not_null(first)
	var start: String = _unit(first, "p1").preset
	var want: String = "careful" if start != "careful" else "attack"
	var a: Dictionary = RtLive.play([RtCommand.preset(5, "p1", want, tog), RtCommand.item(30, "p0", "itm_smoke", "")],
		900)
	var r: BattleResult = a["result"]
	assert_not_null(r)
	assert_eq(r.rt_presets, {"mopsula": {"preset": want, "tog": tog}}, "the changed tactic travels in the result")
	assert_eq(r.to_dict()["rt_presets"], {"mopsula": {"preset": want, "tog": tog}}, "and in its dictionary")
	assert_eq([mop.rt_preset, mop.rt_toggles], [want, tog], "the member keeps it after the combat")
	assert_false(RtLive.cmd_types(Game.run_log).has("loadout"), "no extra log entry")
	var second: RtSetup = Game.make_rt_setup(RtKit.dummy_cmd())
	assert_eq([_unit(second, "p1").preset, _unit(second, "p1").toggles], [want, tog], "the next combat starts with it")
	var b: Dictionary = RtLive.play([RtCommand.item(30, "p0", "itm_smoke", "")], 900)
	var r2: BattleResult = b["result"]
	assert_eq(r2.rt_presets, {}, "an unchanged tactic: nothing")
	assert_false(r2.to_dict().has("rt_presets"), "the result dictionary of such a combat stays as before (R5a)")
	var live: String = StateHash.of(Game.state)
	var res: Dictionary = Game.replay_log(Game.run_log)
	assert_eq([res["errors"], res["mismatch_at"], res["final_hash"]], [PackedStringArray(), -1, live],
		"Game.replay_log writes the same tactic back")
	var core: Dictionary = RunSim.replay(DB.data, Game.run_log)
	assert_eq([core["errors"], core["combat_mismatch_at"]], [PackedStringArray(), -1], "the core verifier agrees")
	var round: BattleResult = BattleResult.from_dict(JSON.parse_string(JSON.stringify(r.to_dict())))
	assert_eq(round.rt_presets, r.rt_presets, "JSON round trip")


func test_the_write_back_takes_known_values_only() -> void:
	var st: GameState = RtKit.state(1)
	var m: PartyMember = st.member("mopsula")
	m.rt_preset = "support"
	var r: BattleResult = BattleResult.new()
	r.rt_presets = {"mopsula": {"preset": "no_such_tactic", "tog": {"potions": true, "x": true}}, "nobody": {}}
	BattleBridge.write_presets(st, r)
	assert_eq([m.rt_preset, m.rt_toggles], ["support", {"potions": true}], "unknown tactic / switch / member ignored")


func _unit(s: RtSetup, id: String) -> RtUnit:
	for u: RtUnit in s.units:
		if u.id == id:
			return u
	return null


# --- the skills page is the loadout (07 §4.1, §5.2; R5b) -----------------------------------------------------------

func test_the_skills_page_chooses_variants_and_the_tactic() -> void:
	Game.combat_mode_override = &"realtime"
	Game.new_game(0, "Kai", 4242)
	Game.combat_mode_override = &""
	var kai: PartyMember = Game.state.member("kai")
	kai.level = 6                                        # (variants of slots 2 and 4 learned, slot 3's at 7 not yet)
	var page: Control = (load("res://scenes/ui/skills_menu.gd") as GDScript).new() as Control
	page.set("member_id", "kai")
	var said: Array = []
	page.connect("status", func(t: String) -> void: said.append(t))
	var holder: Control = Control.new()
	add_to_tree(holder)
	holder.add_child(page)
	await wait_frames(2)
	var list: VBoxContainer = page.get("_list") as VBoxContainer
	assert_eq(_right(list, "RtSkill_skl_kai_sweep"), "belegt", "slot 4 holds the base ability")
	(list.get_node("RtSkill_skl_kai_deo_torch") as Button).pressed.emit()
	assert_eq(kai.rt_loadout, {"4": "skl_kai_deo_torch"}, "a learned variant")
	assert_eq(RtLive.cmd_types(Game.run_log).count("loadout"), 1, "one recorded loadout command")
	assert_eq(_right(list, "RtSkill_skl_kai_deo_torch"), "belegt")
	assert_ne(_right(list, "RtSkill_skl_kai_sweep"), "belegt")
	(list.get_node("RtSkill_skl_kai_cable_whip") as Button).pressed.emit()
	assert_eq(kai.rt_loadout, {"4": "skl_kai_deo_torch"}, "a variant above the level: nothing")
	assert_has(str(said.back()), "Level 7")
	(list.get_node("RtSkill_skl_kai_heavy_swing") as Button).pressed.emit()
	assert_eq(RtLive.cmd_types(Game.run_log).count("loadout"), 1, "slot 1 has no choice")
	(list.get_node("RtPreset_careful") as Button).pressed.emit()
	(list.get_node("RtToggle_potions") as Button).pressed.emit()
	assert_eq([kai.rt_loadout, kai.rt_preset, bool(kai.rt_toggles["potions"])], [{"4": "skl_kai_deo_torch"}, "careful",
		not bool(RtVocab.RT_TOGGLE_DEFAULTS["potions"])], "the complete choice in every command")
	assert_eq(_right(list, "RtPreset_careful"), "aktiv")
	(list.get_node("RtSkill_skl_kai_sweep") as Button).pressed.emit()
	assert_eq([kai.rt_loadout, kai.rt_preset], [{}, "careful"], "the base ability back, the tactic stays")
	var last: Dictionary = Game.run_log.cmds().back()["c"]
	assert_eq(last, RunRules.loadout_cmd("kai", {}, "careful", kai.rt_toggles), "the recorded command")
	var n: int = RtLive.cmd_types(Game.run_log).count("loadout")
	Game.combat = RtKit.sim(RtKit.dummy_cmd())            # a running combat locks the party (rt_party_lock)
	(list.get_node("RtPreset_attack") as Button).pressed.emit()
	Game.combat = null
	assert_eq([kai.rt_preset, RtLive.cmd_types(Game.run_log).count("loadout")], ["careful", n], "refused in combat")
	assert_has(str(said.back()), "Kampfes")
	holder.queue_free()


## The right-hand text of a list button ("" without one).
static func _right(list: Node, button: String) -> String:
	var r: Label = list.get_node(button).find_child("Right", true, false) as Label
	return r.text if r != null else ""


# --- event runs fight in the mode of their rules (07 §10.7, R5b) ------------------------------------------------------

func test_the_event_rules_bind_the_combat_mode() -> void:
	var cat: EventCatalog = EventCatalog.new()
	cat.load_file(RunSim.EVENTS_PATH)
	for def: EventDef in cat.all():
		assert_eq(RunRules.rules_combat_mode(def.rules), RunRules.REALTIME, "%s fights in real time" % def.id)
		assert_false(bool((def.rules["combat"] as Dictionary).get("autopilot", true)), "%s: no autopilot" % def.id)
		assert_eq(def.validate(DB.data), PackedStringArray(), def.id)
	var def: EventDef = cat.get_event(EVENT_ID)
	var ctb_rules: Dictionary = def.rules.duplicate(true)
	(ctb_rules["combat"] as Dictionary)["mode"] = "ctb"
	assert_eq(RunRules.rules_combat_mode(ctb_rules), &"ctb")
	assert_eq(RunRules.rules_combat_mode({}), &"ctb", "an event without the key (before R5b) fights in CTB")
	assert_ne(CanonicalJson.sha256_hex(ctb_rules), def.rules_hash(), "the mode is part of rules_hash")
	for bad: Variant in [{"mode": "turns"}, {"mode": 1}, {"autopilot": "no"}, {"max_enemies": 0}, {"speed": 2}, "rt"]:
		var r: Dictionary = def.rules.duplicate(true)
		r["combat"] = bad
		assert_false(RunRules.combat_rules_errors(r).is_empty(), "rules.combat %s is refused" % str(bad))
	var rt_header: Dictionary = {"seed": def.run_seed(), "difficulty": "prime", "league": "pur", "event_id": EVENT_ID,
		"sim_version": RunSim.SIM_VERSION, "combat_mode": "realtime", "rt_version": RunRules.RT_VERSION}
	assert_eq(RunSim.header_errors(rt_header, def, def.rules), PackedStringArray())
	var ctb_header: Dictionary = rt_header.duplicate()
	ctb_header.erase("combat_mode")
	ctb_header.erase("rt_version")
	assert_has("; ".join(RunSim.header_errors(ctb_header, def, def.rules)),
		"combat_mode 'ctb' — event '%s' fights 'realtime'" % EVENT_ID, "a CTB log of a real-time event")
	assert_has("; ".join(RunSim.header_errors(rt_header, def, ctb_rules)), "combat_mode 'realtime'",
		"a real-time log of a CTB event")


func test_an_event_run_fights_in_real_time_and_replays_in_both_verifiers() -> void:
	Game.combat_mode_override = &"ctb"                    # the player's setting never decides an event's mode
	Game.start_event_run(EVENT_ID)
	Game.combat_mode_override = &""
	if not Game.has_state():
		fail("start_event_run must create a state")
		return
	assert_true(Game.is_realtime(), "the event's rules: real time")
	var h: Dictionary = Game.run_log.header
	assert_eq([h.get("combat_mode", ""), h.get("rt_version", 0)], ["realtime", RunRules.RT_VERSION])
	var scale: int = RtBalance.from_data(DB.data).i("HP_SCALE_PM")
	for m: PartyMember in Game.state.party:
		assert_eq(m.hp_scale_pm, scale, "%s: real-time HP (07 §3.9.4)" % m.id)
	var cmd: Dictionary = _tutorial_cmd()
	assert_false(cmd.is_empty(), "the tutorial group of the event's floor")
	assert_not_null(Game.make_rt_setup(cmd), "a real-time combat")
	assert_eq(Game.combat_submit(RtCommand.autopilot(Game.combat.tick(), Game.combat.controlled_id(), true)),
		"forbidden", "rules.combat.autopilot false (07 §10.7)")
	var gifts: Array = []                                 # system gifts at a tick boundary (Show: not in RunSim)
	var on_event: Callable = func(e: RefCounted) -> void:
		var ev: ActionEvent = e as ActionEvent
		if int(ev.rt.get("boundary", 0)) == 1 and ev.type == ActionEvent.Type.SPONSOR_GIFT:
			gifts.append(ev.tick)
	Events.combat_event.connect(on_event)
	var r: BattleResult = _bot_play(9000)
	Events.combat_event.disconnect(on_event)
	assert_not_null(r)
	if r == null:
		return
	assert_eq(r.outcome, BattleResult.Outcome.VICTORY, "the bot wins the tutorial fight")
	Game.end_combat()
	assert_true(Game.state.floor_run.timer_started, "the tutorial victory starts the countdown")
	assert_has(RtLive.cmd_types(Game.run_log), "move_sample", "the bot's inputs are recorded")
	var live: String = StateHash.of(Game.state)
	var a: Dictionary = Game.replay_log(Game.run_log)
	assert_eq([a["errors"], a["mismatch_at"], a["final_hash"]], [PackedStringArray(), -1, live], "Game.replay_log")
	var core: Dictionary = RunSim.replay(DB.data, Game.run_log)
	assert_eq(core["errors"], PackedStringArray(), "RunSim.replay: the entries pass the core")
	if gifts.is_empty():                                  # the core verifier has no Show: equal without system gifts
		assert_eq(core["combat_mismatch_at"], -1, "RunSim.replay: every combat checkpoint")
	var stripped: Dictionary = Game.run_log.to_dict()
	(stripped["header"] as Dictionary).erase("combat_mode")
	(stripped["header"] as Dictionary).erase("rt_version")
	var forged: RunLog = RunLog.from_dict(stripped)
	assert_has("; ".join(Game.replay_log(forged)["errors"]), "fights 'realtime'", "Game.replay_log: header vs rules")
	assert_has("; ".join(RunSim.replay(DB.data, forged)["errors"]), "fights 'realtime'", "RunSim.replay too")


# --- stored replays are compacted, the board binds the expanded log (07 §10.3, R5b) ---------------------------------

func test_the_replay_file_is_compacted_and_the_board_binds_the_expanded_log() -> void:
	Save.save_dir = ROOT.path_join("saves")
	Save.read_only = false
	Game.start_event_run(EVENT_ID)
	assert_not_null(Game.make_rt_setup(_tutorial_cmd()))
	assert_not_null(_bot_play(9000))
	Game.end_combat()
	var summary: Dictionary = Game.finish_run(&"timer")
	var entry: Dictionary = summary.get("entry", {})
	var live: String = StateHash.of(Game.state)
	assert_false(Game.run_log.has_batches(), "the live log stays expanded")
	assert_eq(str(entry.get("run_log_hash", "")), Game.run_log.digest(), "the entry binds the expanded form")
	var path: String = ROOT.path_join("replays").path_join(str(entry.get("replay_id", "")) + ".json")
	var stored: RunLog = RunLog.from_dict(JsonUtil.read_file(path))
	assert_true(stored.has_batches(), "the replay file holds move_batch entries")
	assert_lt(stored.size(), Game.run_log.size(), "fewer entries on disk")
	assert_ne(stored.digest(), str(entry["run_log_hash"]), "(the stored form hashes differently)")
	assert_eq(stored.canonical_digest(), str(entry["run_log_hash"]), "the file expands to the bound log")
	var res: Dictionary = Game.replay_log(stored)
	assert_eq([res["errors"], res["mismatch_at"], res["final_hash"]], [PackedStringArray(), -1, live],
		"the stored file replays (expanded) to the live state")


static func _rmrf(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for f: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	for sub: String in DirAccess.get_directories_at(path):
		_rmrf(path.path_join(sub))
	DirAccess.remove_absolute(path)


## The encounter command of the event floor's tutorial group (the harness poses in its room).
func _tutorial_cmd() -> Dictionary:
	var fdef: FloorDef = DB.floor_def(Game.state.floor_run.index)
	var layout: FloorLayout = DungeonGenerator.generate(fdef, Game.state.floor_run.seed)
	for g: EnemySpawn in layout.enemies:
		if g.encounter_id == fdef.timer_start_after:
			var cmd: Dictionary = Harness.command_for(g.encounter_id, Game.hero(), 0)
			cmd["group"] = g.id
			(((cmd["rt"] as Dictionary)["groups"] as Array)[0] as Dictionary)["group"] = g.id
			(cmd["rt"] as Dictionary)["cell"] = [g.cell.x, g.cell.y]
			return cmd
	return {}


## The running Game.combat played by the bot through the Game API in the director's order (boundary, inputs, step).
func _bot_play(max_ticks: int) -> BattleResult:
	var bot: RefCounted = Bot.new(Game.combat, "typical", 7)
	bot.set("submitter", Game.combat_submit)
	var n: int = 0
	while Game.combat != null and not Game.combat.is_finished() and n < max_ticks:
		Game.combat_boundary()
		bot.call("act")
		bot.call("observe", Game.combat_step())
		n += 1
	return Game.combat.result if Game.combat != null else null
