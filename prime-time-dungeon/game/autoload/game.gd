extends Node
## Autoload `Game` (02_TECH §3.4): holds the GameState, the floor timer (facade over RunSim, ticks), settings,
## input scheme and the flow helpers. All gameplay time rules of the exploration run in RunSim.step on whole ticks.
##
## Recording rule (§3.4): every state change requested from outside core/ (scenes, UI) goes through a recording Game
## method (RunLog command); reactions (Show on Events signals, BattleBridge, RunSim) are deterministic and not recorded.
## replay_log() drives exactly these methods again, so live run and replay share one code path.
## Sponsor-Fenster (05 §6.13): start_floor, visit_room, enter/leave_safe_room and open_dev_sponsor_window call the
## matching RunSim.sponsor_*() trigger and dispatch its events (sponsor_window_opened / _closed); the clock also runs
## "idle ticks" while the safe room scene is shown (safe_room_clock, is_idle_ticking) — the floor timer does not.

enum InputScheme { KEYBOARD_MOUSE, GAMEPAD, TOUCH }
const TICKS_PER_SEC: int = RunSim.TICKS_PER_SEC   # simulation clock (05 CR-3): 1 tick = 1/30 s explore time
const EVENTS_PATH: String = RunSim.EVENTS_PATH
## Private helper (02_TECH §0.3): the replay engine behind replay_log (one instance per replay).
const GameReplay := preload("res://autoload/game_replay.gd")
## 06-D: the M.O.D. live link (child node, no class_name; idles while settings.mod_live == &"off").
const ModLiveLinkScript := preload("res://autoload/mod_voice/mod_live_link.gd")
## Deterministic quest metrics (05 CR-13), read from ShowState.stats (Show updates them before the signal).
const METRIC_VIEWERS: String = "viewers_target_peak"
const METRIC_FOLLOWERS: String = "followers_gained_run"
const METRIC_HYPE_100: String = "hype_100_count"

var state: GameState = null          # null until new_game()/Save.load_slot()
var settings: GameSettings           # created in _init(); loaded from user://settings.cfg unless ephemeral
var input_scheme: InputScheme = InputScheme.KEYBOARD_MOUSE
# "explore view active": true only via ExplorationScene; Router resets to false on goto/push
var timer_running: bool = false
var autoplay: bool = false           # set by Boot from --autoplay
var fast_text: bool = false          # dialogs show instantly (Autoplay, text_speed=2)
var ephemeral: bool = false:         # tests, autoplay, capture: settings defaults, never read/written on disk
	set(value):
		ephemeral = value
		if settings != null:
			settings.ephemeral = value
			if value:
				settings.reset_defaults()
var mode: StringName = &"campaign"   # &"campaign" | &"event_offline" (M8)
var run_log: RunLog = null           # Brief §6b.3; created by new_game/start_event_run/Save.load_slot
var quest: QuestTracker = null       # only mode &"event_offline"
var sim: RunSim = null               # deterministic explore clock (thin variant, 05 CR-6)
var in_battle: bool = false          # make_rt_setup → end_combat; Show routes external gifts by it (§3.5)
var replaying: bool = false          # true while replay_log runs: record() is a no-op, no Router/Save side effects
var safe_room_clock: bool = false    # SafeRoomScene shown: the run clock keeps ticking (idle ticks, Sponsor-Fenster)

var _acc: float = 0.0
var _blocking_dialogs: int = 0
var _dialog_presenter: bool = false  # ModDialog registered (set_dialog_presenter); without it lines never block
var _event_def: EventDef = null
var _run_finished: bool = false
var _floor_done: bool = false        # complete_floor ("descend") until the next start_floor: no external gifts
var _scene_ctx: Dictionary = {}      # scene context of the current safe room visit (replay: command_refusal)
var _quest_done: bool = false
var _layout: FloorLayout = null      # cached layout of the current floor (floor events, chests, rooms)
var _layout_key: String = ""
var _cmd_id: int = 0                 # last command id given out for _cmd_log
var _cmd_log: RunLog = null          # the log _cmd_id belongs to (Save.load_slot replaces run_log → ids restart at 1)
var _metric_fed: Dictionary = {}     # quest metric → last value fed to the tracker
var _twist_ids: PackedStringArray = []   # 06-D: active twist ids last seen (twist_ended for battle/visit/floor ends)
var mod_live: Node = null            # 06-D: ModLiveLink (created in _ready unless ephemeral; tests add their own)


## Private child node: detects the input scheme also while the tree is paused (02_TECH §3.4).
class InputSchemeWatcher extends Node:
	const MOTION_THRESHOLD: float = 2.0
	const AXIS_THRESHOLD: float = 0.5

	func _input(event: InputEvent) -> void:
		var scheme: int = -1
		if event is InputEventScreenTouch or event is InputEventScreenDrag:
			scheme = InputScheme.TOUCH
		elif event is InputEventKey:
			scheme = InputScheme.KEYBOARD_MOUSE
		elif event is InputEventMouseButton:
			if event.device != InputEvent.DEVICE_ID_EMULATION:
				scheme = InputScheme.KEYBOARD_MOUSE
		elif event is InputEventMouseMotion:
			var mm: InputEventMouseMotion = event
			if mm.device != InputEvent.DEVICE_ID_EMULATION and mm.relative.length() > MOTION_THRESHOLD:
				scheme = InputScheme.KEYBOARD_MOUSE
		elif event is InputEventJoypadButton:
			scheme = InputScheme.GAMEPAD
		elif event is InputEventJoypadMotion:
			var jm: InputEventJoypadMotion = event
			if absf(jm.axis_value) > AXIS_THRESHOLD:
				scheme = InputScheme.GAMEPAD
		if scheme >= 0:
			Game.set_input_scheme(scheme)


func _init() -> void:
	settings = GameSettings.new()
	ephemeral = _detect_ephemeral()
	if not ephemeral:
		settings.load_from_disk()
	apply_language()                          # Sprachen (11 §1.9, L1): the catalog stands before the first screen
	var watcher: InputSchemeWatcher = InputSchemeWatcher.new()
	watcher.name = "InputSchemeWatcher"
	watcher.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(watcher)


func _ready() -> void:
	Events.mod_said.connect(_on_mod_said)
	Events.dialog_finished.connect(_on_dialog_finished)
	Events.enemy_killed.connect(_on_quest_enemy_killed)
	Events.boss_defeated.connect(_on_quest_boss_defeated)
	Events.boss_hp_changed.connect(_on_quest_boss_hp)
	Events.battle_started.connect(_on_quest_battle_started)
	Events.floor_completed.connect(_on_quest_floor_completed)
	Events.achievement_unlocked.connect(_on_quest_achievement)
	Events.viewers_changed.connect(_on_quest_viewers_changed)
	Events.followers_changed.connect(_on_quest_followers_changed)
	Events.hype_changed.connect(_on_quest_hype_changed)
	get_tree().root.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED   # Sprachen (11 SP-3, L1)
	apply_settings()
	_rt_ready()                               # Echtzeitkampf (07 §10.1, R2): combat_speed
	season_live_clock = not ephemeral         # Staffeln (09 §9.1, ST1-B): tests and tools set the clock themselves
	if not ephemeral:                    # 06-D: M.O.D. live link (off by default, never blocks gameplay)
		mod_live = ModLiveLinkScript.new()
		mod_live.name = "ModLiveLink"
		add_child(mod_live)


func _process(delta: float) -> void:
	_season_notices_process()                     # Staffeln (09 §2.9, ST1-G): desktop notices after a logout
	if state == null:
		return
	state.play_time_sec += delta
	if state.season != null:
		_season_process()                         # Staffeln (09 §9.1, ST1-B): the wall clock, the 60-s save
	if sim == null or not (is_timer_ticking() or is_idle_ticking()):
		return
	_acc += delta
	var n: int = floori(_acc * TICKS_PER_SEC)
	_acc -= n / float(TICKS_PER_SEC)
	# One tick at a time: reactions to a tick's events (Show hype at warnings, achievements on explore_tick) apply
	# before the next tick, independent of the frame rate — replay_log() steps identically. In a safe room RunSim
	# makes them idle ticks (Sponsor-Fenster only), decided by floor_run.location — the replay does the same.
	for _i in n:
		if not (is_timer_ticking() or is_idle_ticking()):
			_acc = 0.0
			break
		_dispatch(sim.step(1))
		_regie_tick()                        # 06-D: offline Regie decision points (from floor 2)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_fullscreen") and not OS.has_feature("mobile"):
		settings.fullscreen = not settings.fullscreen
		settings.save_to_disk()
		apply_settings()
		get_viewport().set_input_as_handled()


static func _detect_ephemeral() -> bool:
	return is_ephemeral_args(OS.get_cmdline_user_args(), OS.get_cmdline_args())


## Tests (-s/--script), capture and autoplay — the smoke run (--autoplay) and the full run (--autoplay=full,
## 02_TECH §11.4) — never read or write user://settings.cfg.
static func is_ephemeral_args(user_args: PackedStringArray, args: PackedStringArray) -> bool:
	if user_args.has("--capture"):
		return true
	for a: String in user_args:
		if a == "--autoplay" or a.begins_with("--autoplay="):
			return true
	return args.has("-s") or args.has("--script")


## Called by the InputSchemeWatcher; emits input_scheme_changed on change.
func set_input_scheme(scheme: int) -> void:
	if scheme == input_scheme:
		return
	input_scheme = scheme as InputScheme
	if input_scheme == InputScheme.GAMEPAD:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Events.input_scheme_changed.emit(scheme)


# ======================================================================================================================
# Game flow
# ======================================================================================================================

func has_state() -> bool:
	return state != null


## seed -1 → time based. Creates GameState, RunLog, RunSim, starts floor 1, records the controlled character
## (`hero_id`, 06 §1: "kai" | "mopsula", right after "floor"), emits new_game_started(slot).
## `p_persona` (08 §2.3, K0): the local candidate persona (Game.persona); its start command follows the hero
## (_choose_initial_persona) — without a profile never a command.
func new_game(slot: int, player_name: String = GameState.DEFAULT_NAME, seed: int = -1,
		difficulty: StringName = &"prime", hero_id: String = HeroRules.DEFAULT_HERO,
		p_persona: PersonaProfile = null) -> void:
	var run_seed: int = seed
	if run_seed == -1:
		run_seed = int(Time.get_unix_time_from_system() * 1000.0) & 0x7FFFFFFF
	_reset_run()
	mode = &"campaign"
	state = GameState.create_new(DB.data, slot, player_name, run_seed, difficulty)
	if state == null:
		push_warning("[Game] GameState.create_new returned null (no game state)")
		return
	run_log = _make_run_log(run_seed, slot, difficulty, "")
	_rt_begin()                               # Echtzeitkampf (07 §12.1): the real-time run's header and start
	sim = _make_sim(state, {})
	persona = p_persona
	start_floor(1)
	_choose_initial_hero(hero_id)
	_choose_initial_persona(p_persona)        # Casting (08 §2.3): floor → hero → persona
	_rt_run_started()                         # Echtzeitkampf (07 §10.1, R2): combat_speed ≠ 1000 at the run start
	Events.new_game_started.emit(slot)


## M8: EventCatalog → EventDef.run_seed(); mode = &"event_offline"; slot 0 (never saved into campaign slots).
## p_league: the league the player plays in a multi-league event (05 §10.1); "" → the single league / "pur".
## `hero_id` (06 §1.7): the controlled character, recorded right after "floor" like in new_game. Every run fights in
## real time (R5b part 2b); the event's rules.combat (part of rules_hash) sets its switches (07 §10.7).
func start_event_run(event_id: String, p_league: String = "", hero_id: String = HeroRules.DEFAULT_HERO) -> void:
	var def: EventDef = _load_event_def(event_id)
	if def == null:
		push_warning("[Game] unknown event '%s'" % event_id)
		return
	_reset_run()
	mode = &"event_offline"
	persona = null                         # Casting (08 §8): event runs have no persona (the canon Kai plays)
	_event_def = def
	var run_seed: int = def.run_seed()
	state = GameState.create_new(DB.data, 0, GameState.DEFAULT_NAME, run_seed, &"prime")
	if state == null:
		push_warning("[Game] GameState.create_new returned null (no game state)")
		mode = &"campaign"
		return
	quest = QuestTracker.from_def(def.quest)
	var league: String = _run_league(def.rules, p_league)
	run_log = _make_run_log(run_seed, 0, &"prime", event_id, league)
	_rt_begin()
	sim = _make_sim(state, def.rules)
	start_floor(maxi(1, def.floor_index))
	_choose_initial_hero(hero_id)
	_rt_run_started()
	Events.run_started.emit(event_id, league)


## Save.load_slot: the decoded save becomes the running campaign. The private run context (event def, finished flag,
## quest state, layout cache, command ids, metric memory, dialog/timer state) is reset as for a new game; run_log =
## p_log (header "from_save"), a fresh RunSim (rules {}) writes its checkpoints into it. Save emits game_loaded.
func adopt_loaded_state(st: GameState, p_log: RunLog) -> void:
	_reset_run()
	mode = &"campaign"
	state = st
	if state == null:
		return
	run_log = p_log
	sim = _make_sim(state, {})


## Show.receive_gift: a run is active and still takes external gifts — not after its floor was completed ("descend")
## or the event run finished (05 §6.4 Fehlerpfad: the gift service refunds). Replays feed the recorded gifts anyway.
func accepts_gifts() -> bool:
	return state != null and not _run_finished and not _floor_done


## The `extra` of GiftPolicy.refusal for Show: the run clock and the run identity (RunSim.gift_context of the live sim
## — the same values RunSim.replay derives from the log header).
func gift_context() -> Dictionary:
	if sim == null:
		return {}
	return sim.gift_context()


## Rules of the running event run (EventDef.rules, 05 §10.1); {} in the campaign. Show passes them to GiftPolicy (§3.5).
func event_rules() -> Dictionary:
	if mode != &"event_offline" or _event_def == null:
		return {}
	return _event_def.rules


## Game is the only emitter of party_changed (§3.2); Show calls this after a gift changed the party outside a battle
## (GiftApplier sponsor_buff heals / MP).
func emit_party_changed() -> void:
	Events.party_changed.emit()


## Standalone scenes, capture, tests: ephemeral-safe new game in slot 0 with seed 1 (`p_seed`).
func ensure_state(p_seed: int = 1) -> void:
	if has_state():
		return
	new_game(0, "Kai", p_seed)


## DB.floor_def(state.floor_run.index); null without state.
func floor_def() -> FloorDef:
	if state == null or state.floor_run == null:
		return null
	return DB.floor_def(state.floor_run.index)


func start_floor(floor_index: int) -> void:
	if state == null:
		push_warning("[Game] start_floor without state")
		return
	if not RunRules.start_floor(state, DB.data, floor_index):
		push_warning("[Game] start_floor: no floor %d" % floor_index)
		return
	_floor_done = false
	_scene_ctx = {}
	_acc = 0.0
	_layout = null
	_layout_key = ""
	clear_blocking_dialogs()
	Show.start_floor(floor_index)
	record({"t": "floor", "floor": floor_index})
	if sim != null:
		_dispatch(sim.sponsor_floor())
	_sync_twist_ends()                       # 06-D: twists end with their floor


## timer_running and state.floor_run.timer_started and no blocking dialog — and never during a battle (07 §2.10,
## §12.9 Nr. 1: the exploration scene stays active in a real-time combat, the clock stands).
func is_timer_ticking() -> bool:
	return timer_running and state != null and state.floor_run != null and state.floor_run.timer_started \
		and _blocking_dialogs == 0 and not in_battle


## Idle ticks of the run clock in a safe room (Sponsor-Fenster max_sec, 05 §6.13): safe room scene shown
## (safe_room_clock), location = a safe room, countdown started, no blocking dialog, no battle, windows tracked.
## RunSim.step makes them idle ticks (no floor timer, no hype decay, no strays).
func is_idle_ticking() -> bool:
	return safe_room_clock and not replaying and not in_battle and _blocking_dialogs == 0 and state != null \
		and state.floor_run != null and state.floor_run.timer_started and state.floor_run.location != &"start" \
		and SponsorWindows.tracked(state)


func complete_floor() -> void:
	if state == null or state.floor_run == null:
		return
	if state.season != null and not _season_stairs_open():   # Staffeln (09 §2.6, ST1-B): the staircase rule
		return
	timer_running = false
	record({"t": "descend"})
	_floor_done = true
	if state.season != null:   # Staffeln (09 §2.7, ST1-B): the Quote counts the stairs; the end of the content
		_dispatch(SeasonRules.on_descend(state, DB.data))
	if sim != null:
		sim.request_checkpoint()
	Events.floor_completed.emit(state.floor_run.index)
	if mode == &"event_offline":
		finish_run(&"floor_completed")
	var summary: Dictionary = state.floor_run.summary()
	var notes: Vector2i = secret_notes()           # 06 package A: "Regie-Notizen 1/3" (only floors with notes)
	if notes.y > 0:
		summary["regie_notes"] = notes.x
		summary["regie_notes_total"] = notes.y
	Router.goto(Router.SCENE_FLOOR_SUMMARY, {"summary": summary}, Router.Transition.FADE)


## Called by FloorSummary "Weiter".
func continue_after_summary() -> void:
	if state == null or state.floor_run == null:
		Router.goto(Router.SCENE_TITLE)
		return
	if state.season != null and state.season.result != "":   # Staffeln (09, ST1-B): the stairs ended the season
		Router.goto(Router.SCENE_CREDITS)
		return
	var idx: int = state.floor_run.index
	var next: FloorDef = DB.floor_def(idx + 1)
	if next != null:
		start_floor(idx + 1)
		Save.autosave()
	if next == null or not next.playable_in(state.season != null):   # Staffeln (ST1-C): season floors need a season
		Router.goto(Router.SCENE_CREDITS)
	else:
		Router.goto(Router.SCENE_EXPLORATION, {"spawn": &"start"})


## Router.game_over calls this first: stat game_overs +1; Save.record_game_over(state.slot) (not while replaying).
## Staffeln (09 §7, ST1-B): a season has no game over — the season rules decided at the end of the combat.
func on_game_over(reason: StringName) -> void:
	timer_running = false
	in_battle = false
	if state == null or state.season != null:
		return
	Show.bump_stat("game_overs", 1)
	if replaying:
		return
	Save.record_game_over(state.slot)
	if mode == &"event_offline":
		finish_run(reason)


## state.rng_counter += 1; SeedUtil.derive(state.seed, purpose, state.rng_counter)
func next_seed(purpose: String) -> int:
	if state == null:
		push_warning("[Game] next_seed('%s') without state" % purpose)
		return SeedUtil.derive(1, purpose, 0)
	return RunRules.next_seed(state, purpose)


## The booking of a finished combat (end_combat; the verifiers book through BattleBridge.apply_result): rewards,
## level-ups, talent choices, the countdown start of the tutorial victory.
func apply_battle_result(result: BattleResult) -> BattleRewards:
	in_battle = false
	if state == null or result == null:
		return BattleRewards.new()
	var credits_before: int = _credits()
	var timer_was_started: bool = state.floor_run != null and state.floor_run.timer_started
	var rewards: BattleRewards = BattleBridge.apply_result(state, DB.data, result)
	if rewards == null:
		rewards = BattleRewards.new()
	if sim != null:
		SponsorWindows.on_battle_result(state, sim.rules, DB.data, result)   # 06-C: comeback mark (06 §6 decision 3)
	if state.season != null:   # Staffeln (09 §7, ST1-B): the death rule (no game over), the finale, the clock grace
		_dispatch(SeasonRules.on_combat_end(state, DB.data, result))
		_dispatch(CastSim.on_combat_end(state, DB.data, result))   # ST1-F: the guest (never in a boss fight)
	if sim != null:
		sim.request_checkpoint()   # 05 §3.3 Nr. 8: a checkpoint after every battle (written when the clock moves on)
	_sync_twist_ends()             # 06-D: "battles" twists counted down in BattleBridge.apply_result
	Events.party_changed.emit()
	Events.inventory_changed.emit()
	Events.credits_changed.emit(_credits(), _credits() - credits_before)
	var tree: bool = TalentTree.governs(state)   # Staffeln (09 §8.4, ST1-D): rows of the tree instead of odd levels
	for info: LevelUpInfo in rewards.level_ups:
		if info == null:
			continue
		Events.member_leveled.emit(info.member_id, info.new_level, info.learned)
		for lv in range(info.old_level + 1, info.new_level + 1):
			Events.level_up.emit({"member": info.member_id, "level": lv})
			if not tree and Talents.is_talent_level(lv):   # 06 package B: a choice waits in the Talent-Show
				Events.talent_pending.emit(info.member_id, lv)
			elif tree and TalentTree.is_row_level(lv) \
					and TalentTree.rows(DB.data, state.member(info.member_id)).has(lv):
				Events.talent_pending.emit(info.member_id, lv)
	if state.season != null:   # Staffeln (09 §8.2–8.4, ST1-D): toasts and M.O.D. lines of the level-ups (live only)
		_level_after_combat(rewards)
	if not timer_was_started and state.floor_run != null and state.floor_run.timer_started:
		Events.floor_timer_started.emit()
	return rewards


func open_lootbox(box_id: String) -> Array[LootReward]:
	var rewards: Array[LootReward] = []
	if state == null:
		return rewards
	if not RunRules.lootbox_pending(state, DB.data, box_id):
		push_warning("[Game] lootbox '%s' is not pending" % box_id)
		return rewards
	record({"t": "lootbox", "box": box_id})
	var credits_before: int = _credits()
	rewards = RunRules.open_lootbox(state, DB.data, box_id)
	_emit_inventory(credits_before)
	Events.lootbox_opened.emit(box_id, rewards)
	return rewards


## Items → inventory (overflow over max_stack → credits at sell value), credits.
func add_rewards(rewards: Array[LootReward]) -> void:
	if state == null or state.inventory == null:
		return
	var credits_before: int = _credits()
	state.inventory.add_rewards(DB.data, rewards)
	_emit_inventory(credits_before)


func buy(item_id: String, qty: int, safe_room_id: String) -> bool:
	if state == null:
		return false
	record({"t": "buy", "item": item_id, "qty": qty, "safe_room": safe_room_id})
	var credits_before: int = _credits()
	var bought: bool = Shop.buy(state, DB.data, item_id, qty)
	if bought:
		Events.inventory_changed.emit()
		Events.credits_changed.emit(_credits(), _credits() - credits_before)
		Events.item_bought.emit({"item_id": item_id, "qty": qty, "cost": credits_before - _credits(),
			"safe_room_id": safe_room_id})
	return bought


func sell(item_id: String, qty: int) -> bool:
	if state == null:
		return false
	record({"t": "sell", "item": item_id, "qty": qty})
	var credits_before: int = _credits()
	var sold: bool = Shop.sell(state, DB.data, item_id, qty)
	if sold:
		Events.inventory_changed.emit()
		Events.credits_changed.emit(_credits(), _credits() - credits_before)
	return sold


func equip(member_id: String, slot: String, item_id: String) -> bool:
	if state == null or rt_party_lock(&"equipment") != "":    # Echtzeitkampf (07, R2): not during a fight
		return false
	record({"t": "equip", "member": member_id, "slot": slot, "item": item_id})
	var m: PartyMember = state.member(member_id)
	if m == null:
		return false
	var equipped: bool = Progression.equip(m, state.inventory, DB.data, slot, item_id)
	if equipped:
		Events.party_changed.emit()
		Events.inventory_changed.emit()
	return equipped


## Field use of a consumable (inventory menu, M6): record; Progression.use_item();
## emits party_changed, inventory_changed.
func use_item(item_id: String, member_id: String) -> bool:
	if state == null or rt_party_lock() != "":                 # Echtzeitkampf (07, R2): the item wheel in a fight
		return false
	record({"t": "use_item", "item": item_id, "member": member_id})
	var used: bool = Progression.use_item(state, DB.data, item_id, member_id)
	if used:
		Events.party_changed.emit()
		Events.inventory_changed.emit()
	return used


## record({"t": "rest"}); Progression.full_heal(state, DB.data); emits party_changed.
func rest_full_heal() -> void:
	if state == null:
		return
	record({"t": "rest"})
	_full_heal()


## §7.4: FloorEvent resolve/apply with rng SeedUtil.derive(floor_run.seed, "event", k × 16 + uses) + Show + record;
## a completed event emits Events.event_completed({"event_id", "choice"}).
func apply_floor_event(event_id: String, choice: String) -> Dictionary:
	if state == null or state.floor_run == null:
		return {}
	var layout: FloorLayout = _current_layout()
	if layout == null:
		push_warning("[Game] apply_floor_event: no layout")
		return {}
	if layout.event_by_id(event_id) == null:
		push_warning("[Game] apply_floor_event: unknown event '%s'" % event_id)
		return {}
	var credits_before: int = _credits()
	var outcome: Dictionary = RunRules.apply_floor_event(state, DB.data, layout, event_id, choice)
	if outcome.get("season", null) is Array:    # Staffeln (09 §8.2, ST1-D): the event's EXP (SEASON event "exp")
		var season_evs: Array[ExploreEvent] = []
		season_evs.assign(outcome["season"] as Array)
		_dispatch(season_evs)
	var hype: float = float(outcome.get("hype", 0.0))
	if hype != 0.0:
		Show.add_hype(hype, &"event")
	var followers: int = int(outcome.get("followers", 0))
	if followers != 0:
		Show.add_followers(followers, &"event")
	RunRules.add_event_boxes(state, outcome)
	var mod_tag: String = str(outcome.get("mod_tag", ""))
	if mod_tag != "":
		Show.say(mod_tag)
	record({"t": "event", "id": event_id, "choice": choice})
	Events.party_changed.emit()
	Events.inventory_changed.emit()
	Events.credits_changed.emit(_credits(), _credits() - credits_before)
	if bool(outcome.get("completed", false)):
		Events.event_completed.emit({"event_id": event_id, "choice": choice})
	return outcome


## M3 on every room change. First visit: floor_run.visited.append(cell), STAIRS → stairs_found = true,
## record({"t": "room", "cell": [x, y]}). Returns first_visit.
func visit_room(cell: Vector2i) -> bool:
	if state == null or state.floor_run == null:
		return false
	var fr: FloorRun = state.floor_run
	if fr.visited.has(cell):
		_comeback_room(cell)                      # 06-C
		return false
	record({"t": "room", "cell": JsonUtil.vec2i_to_arr(cell)})
	var layout: FloorLayout = _current_layout()
	RunRules.visit_room(state, layout, cell)
	var rc: RoomCell = layout.cell_at(cell) if layout != null else null           # 06-C: pacifist preference
	Show.on_room_visited(int(rc.kind) if rc != null else -1, rc.zone if rc != null else "")
	_quest_feed(RunSim.zones_event(fr, layout))   # reach_stairs progress before the stairs (05 §1.3, same as RunSim)
	if sim != null:
		_dispatch(sim.sponsor_room(cell))         # boss room → Boss-Countdown (05 §6.13)
	return true


## §7.3 chest flow without visuals: locked without itm_key_master / unknown / already open → [] (nothing changes);
## else record, RunRules.open_chest (rng derive(floor_run.loot_seed, "chest", k) — 05 CR-11: the layout seed is
## public, the loot seed is not; rewards → inventory; opened_chests), Events.chest_opened(id, rewards).
func open_chest(chest_id: String) -> Array[LootReward]:
	var rewards: Array[LootReward] = []
	if state == null or state.floor_run == null:
		return rewards
	var chest: ChestSpawn = RunRules.openable_chest(state, _current_layout(), chest_id)
	if chest == null:
		return rewards
	record({"t": "chest", "id": chest_id})
	var credits_before: int = _credits()
	rewards = RunRules.open_chest(state, DB.data, chest)
	_emit_inventory(credits_before)
	Events.chest_opened.emit(chest_id, rewards)
	return rewards


## 06-C (06 §6 decision 3): re-entering a boss room while its comeback is due (a lost boss attempt) opens the
## Sponsor-Fenster once more — recorded as a "room" command like a first visit (RunSim._apply_room runs the same rule
## through SponsorWindows.on_room(first = false)). Every other revisit records nothing.
func _comeback_room(cell: Vector2i) -> void:
	var layout: FloorLayout = _current_layout()
	var rc: RoomCell = layout.cell_at(cell) if layout != null else null
	if rc == null or sim == null or not SponsorWindows.comeback_due(state, sim.rules, int(rc.kind)):
		return
	record({"t": "room", "cell": JsonUtil.vec2i_to_arr(cell)})
	_dispatch(sim.sponsor_room(cell, false))


## Gate requirement checked by M3: opened_gates.append(key) (once), record({"t": "gate", "key"}).
func open_gate(key: String) -> void:
	if state == null or state.floor_run == null or state.floor_run.opened_gates.has(key):
		return
	record({"t": "gate", "key": key})
	RunRules.open_gate(state, key)


## record({"t": "safe_room", "id"}); location = id; safe_room_visits += 1; first visit bookkeeping; full heal
## (not recorded separately). Returns the scene condition context.
func enter_safe_room(safe_room_id: String) -> Dictionary:
	if state == null or state.floor_run == null:
		return {"safe_room_id": safe_room_id, "first_visit": false, "safe_room_visits": 0, "kai_level": 1}
	record({"t": "safe_room", "id": safe_room_id})
	var ctx: Dictionary = RunRules.enter_safe_room(state, DB.data, safe_room_id)
	_scene_ctx = ctx.duplicate()
	Events.party_changed.emit()
	if sim != null:
		_dispatch(sim.sponsor_safe_room(safe_room_id))
	Show.on_safe_room_entered(safe_room_id, bool(ctx.get("first_visit", false)))   # 08 §4.3 H4 (presentation)
	if state.season != null:
		_season_autosave()                        # Staffeln (09 §9.1, ST1-B): the save at every safe-room visit
	return ctx


## Back in the exploration (M3 on_resume from a safe room): location = &"start"; record({"t": "safe_room_exit"}).
func leave_safe_room() -> void:
	if state == null or state.floor_run == null:
		return
	record({"t": "safe_room_exit"})
	RunRules.leave_safe_room(state)
	_sync_twist_ends()                       # 06-D: a visit twist (happy hour) ends with its visit
	_scene_ctx = {}
	if sim != null:
		_dispatch(sim.sponsor_safe_room_exit())


## QA/debug (05 §6.13): opens a Sponsor-Fenster of `sec` seconds with `slots` slots — recorded
## ({"t": "sponsor_window", "op": "dev_open", "sec", "slots"}), only where rules.sponsor_windows.dev_open allows it
## (campaign/offline defaults; live events switch it off). false = not allowed / no run.
func open_dev_sponsor_window(sec: int = 60, slots: int = 3) -> bool:
	if state == null or sim == null or not SponsorWindows.dev_allowed(state, sim.rules, sec, slots):
		return false
	record({"t": "sponsor_window", "op": "dev_open", "sec": sec, "slots": slots})
	_dispatch(sim.sponsor_dev_open(sec, slots))
	return true


## SponsorWindows.view of the run ({"tracked": false, …} without a run): open window, slots, seconds left, next
## periodic window.
func sponsor_window() -> Dictionary:
	if sim == null or state == null:
		return SponsorWindows.view(null, {})
	return sim.sponsor_window()


## First SceneDef (priority order) whose condition holds and that was not seen; null.
func next_scene(ctx: Dictionary) -> SceneDef:
	if state == null:
		return null
	for sc: SceneDef in DB.data.all_scenes():
		if RunRules.scene_allowed(state, sc, ctx):
			return sc
	return null


## record({"t": "scene", "id"}); flags scene_<id> = true and the scene's set_flag (e.g. mop_pep_talk).
func mark_scene_seen(scene: SceneDef) -> void:
	if scene == null or state == null:
		return
	record({"t": "scene", "id": scene.id})
	RunRules.mark_scene_seen(state, scene)


# --- 06 package B: Talent-Show + Casting ----------------------------------------------------------------------------

## Talent-Show pick (06 §2.2): only a valid pick (Talents.check_pick: in a safe room, from the offer of the member's
## oldest open level) is recorded ({"t": "talent", "member", "id"}) and applied; emits talent_picked, party_changed.
func pick_talent(member_id: String, talent_id: String) -> bool:
	if state == null or Talents.check_pick(state, DB.data, member_id, talent_id) != "":
		return false
	record({"t": "talent", "member": member_id, "id": talent_id})
	Talents.pick(state, DB.data, member_id, talent_id)
	Events.talent_picked.emit(member_id, talent_id)
	Events.party_changed.emit()
	return true


## Casting (06 §3.4; the Recall screen of floor 3, 06 §3.5): only an allowed choice (Casting.check) is recorded
## ({"t": "casting", "member", "species", "class"}) and applied; emits party_changed.
func choose_casting(member_id: String, species_id: String, class_id: String) -> bool:
	if state == null or Casting.check(state, DB.data, member_id, species_id, class_id) != "":
		return false
	record({"t": "casting", "member": member_id, "species": species_id, "class": class_id})
	Casting.choose(state, DB.data, member_id, species_id, class_id)
	_recall_unlock()                           # Recall (06 §3.5): the first class choice unlocks Ohne Netz
	Events.party_changed.emit()
	return true


## Only &"prime" → &"vorabend" (never up), campaign only (event runs play the event's difficulty, 05 §10.1 —
## RunSim refuses the command there too); record({"t": "difficulty", "to"}). Damage/EXP apply from the next battle,
## the timer factor ×1.5 from the next floor start (FloorRun.create, GDD §2.9) — the running floor timer is unchanged.
func set_difficulty(d: StringName) -> bool:
	if not can_lower_difficulty() or d != &"vorabend":
		return false
	record({"t": "difficulty", "to": String(d)})
	RunRules.lower_difficulty(state, d)
	return true


## The settings menu offers lowering the mode only where set_difficulty would accept it.
func can_lower_difficulty() -> bool:
	return state != null and mode == &"campaign" and state.difficulty == &"prime"


# --- Recall (06 §3.5) -------------------------------------------------------------------------------------------------

## 09 §2.2 (B-14): the first class choice unlocks "Ohne Netz" for the device — kept right away in the career file (the
## season autosave would at its next save), so the Recall can say so. Live only: a replay never writes the career.
func _recall_unlock() -> void:
	if state.season != null and not replaying and SeasonRules.unlocks_no_net(state):
		Save.career_set("no_net", true)


# --- 06 package A: hero choice (HeroRules) ----------------------------------------------------------------------------

## The controlled character (06 §1): "kai" | "mopsula" ("kai" without a run).
func hero() -> String:
	return state.hero if state != null else HeroRules.DEFAULT_HERO


## The character that follows / may fight on its own ("Partner automatisch").
func partner() -> String:
	return HeroRules.partner_of(state)


## Records {"t": "hero", "id"} and makes `hero_id` the controlled character. Before the run started (new game, event
## run) HeroRules.check_initial applies, afterwards check_set (only in a safe room, only a real change). false (nothing
## recorded, nothing changes) when the check refuses. Emits hero_changed when the hero actually changed.
func set_hero(hero_id: String) -> bool:
	if state == null or HeroRules.check(state, hero_id) != "":
		return false
	record({"t": "hero", "id": hero_id})
	var changed: bool = state.hero != hero_id
	HeroRules.set_hero(state, hero_id)
	if changed:
		Events.hero_changed.emit(hero_id)
	return true


## 06 §2.7 (package A): opens an E1 secret — a Kulissenwand (knocked over by the field strike / bark; its door joins
## opened_gates) or a Regie-Notiz (+15 followers). Secrets.check_open refuses (unknown, already open, note behind a
## standing wall) → false, nothing recorded. Else record({"t": "secret", "id"}), Secrets.open, followers / M.O.D. line
## via Show (like the floor events), emits secret_opened(id). The visuals (wall falls, gate_opened) are the
## ExplorationScene's (open_secret_visual), like open_gate.
func open_secret(secret_id: String) -> bool:
	var def: FloorDef = floor_def() if state != null and state.floor_run != null else null
	if Secrets.check_open(state, def, secret_id) != "":
		return false
	record({"t": "secret", "id": secret_id})
	var fx: Dictionary = Secrets.open(state, def, secret_id)
	var followers: int = int(fx.get("followers", 0))
	if followers != 0:
		Show.add_followers(followers, &"secret")
	var tag: String = str(fx.get("mod_tag", ""))
	if tag != "":
		Show.say(tag)
	Events.secret_opened.emit(secret_id)
	return true


## Regie-Notizen of the current floor: Vector2i(found, total) (floor summary "Regie-Notizen 1/3").
func secret_notes() -> Vector2i:
	if state == null or state.floor_run == null:
		return Vector2i.ZERO
	return Secrets.notes_found(state, floor_def())


func _choose_initial_hero(hero_id: String) -> void:
	var id: String = HeroRules.sanitize(hero_id)
	if id != hero_id:
		push_warning("[Game] unknown hero '%s' → %s" % [hero_id, id])
	if not set_hero(id):
		push_warning("[Game] hero choice '%s' refused (%s)" % [id, HeroRules.check(state, id)])


## run_log.add_cmd(sim.tick(), cmd, cmd_id); no-op if run_log == null or while replaying.
## cmd_id: 0 for external inputs (Command.EXTERNAL), else strictly increasing from 1 per run log (05 §10.6).
## Staffeln (09 §9.1, ST0): with a season the command also goes to the slot's journal (Save.journal_append).
func record(cmd: Dictionary) -> void:
	if run_log == null or replaying:
		return
	if _cmd_log != run_log:
		_cmd_log = run_log
		_cmd_id = 0
	var cmd_id: int = 0
	if not Command.is_external(cmd):
		_cmd_id += 1
		cmd_id = _cmd_id
	run_log.add_cmd(sim.tick() if sim != null else 0, cmd, cmd_id)
	if state != null and state.season != null:     # Staffeln (09 §9.1, ST0): the journal line before the command acts
		Save.journal_append(state.slot, cmd)


## Recorded ({"t": "flag", "key", "value"}); value bool/int/String (JSON-safe). Only player flags (Command.FLAG_KEYS:
## the intro) — every other flag is a core reaction and never a recorded write.
func set_flag(key: String, value: Variant) -> void:
	if state == null:
		return
	if not Command.FLAG_KEYS.has(key):
		push_warning("[Game] set_flag: '%s' is not a player flag" % key)
		return
	record({"t": "flag", "key": key, "value": value})
	state.flags[key] = value


func get_flag(key: String, default: Variant = null) -> Variant:
	if state == null:
		return default
	return state.flags.get(key, default)


## Display only.
func time_left() -> float:
	if state == null or state.floor_run == null:
		return 0.0
	return state.floor_run.time_left_ticks / float(TICKS_PER_SEC)


## Router at every goto (old screens freed) and start_floor: blocking dialogs of freed screens can never finish.
func clear_blocking_dialogs() -> void:
	_blocking_dialogs = 0


## ModDialog (M6) registers in _ready (true) and unregisters in _exit_tree (false). Blocking mod_said lines pause the
## timer only while a presenter is registered (tests/standalone scenes without GlobalUi never freeze the countdown).
func set_dialog_presenter(active: bool) -> void:
	_dialog_presenter = active
	if not active:
		_blocking_dialogs = 0


## Audio volumes (Sfx), fullscreen, quality (scaling_3d_scale, MSAA); emits settings_changed.
func apply_settings() -> void:
	if settings == null:
		return
	Sfx.set_volume(&"Master", settings.master_volume)
	Sfx.set_volume(Sfx.BUS_MUSIC, settings.music_volume)
	Sfx.set_volume(Sfx.BUS_SFX, settings.sfx_volume)
	Sfx.set_volume(Sfx.BUS_UI, settings.sfx_volume)
	fast_text = autoplay or settings.text_speed == 2
	if is_inside_tree():
		var root: Window = get_tree().root
		var mobile: bool = OS.has_feature("mobile")
		if settings.quality == &"low":
			root.scaling_3d_scale = 0.7
			root.msaa_3d = Viewport.MSAA_DISABLED
		else:
			root.scaling_3d_scale = 0.85 if mobile else 1.0
			root.msaa_3d = Viewport.MSAA_2X
		if not mobile and DisplayServer.get_name() != "headless":
			var cur: DisplayServer.WindowMode = DisplayServer.window_get_mode()
			var is_fs: bool = cur == DisplayServer.WINDOW_MODE_FULLSCREEN \
				or cur == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
			if is_fs != settings.fullscreen:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if settings.fullscreen \
					else DisplayServer.WINDOW_MODE_WINDOWED)
	Events.settings_changed.emit()


# ======================================================================================================================
# KI-Admin: twists (06 §5, package D)
# ======================================================================================================================

## THE entry of every M.O.D. intervention (Regie, M.O.D. live, votes, QA): `twist` = {"id", "src", "params"?,
## "duration"?, "req"?, "vote_id"?} → TwistApplier.complete (n, tick = sim.tick(), default params) →
## RunRules.twist_refusal (the check both verifiers run: run over / after "descend" → run_not_active, in a battle →
## wrong_phase, a tick that is not now → tick_mismatch, …) → record({"t": "twist", "twist": …}) (external, cmd id 0)
## → apply → Events.twist_applied. Returns "" (applied) or the refusal reason (TwistApplier.REASONS,
## "run_not_active"). Never waits for anything: proposals from the network arrive here already decided.
func apply_twist(twist: Dictionary) -> String:
	if state == null or sim == null:
		return "run_not_active"
	var t: Dictionary = TwistApplier.complete(state, DB.data, twist, sim.tick())
	var why: String = RunRules.twist_refusal(state, DB.data, sim.rules, t, sim.tick(), in_battle,
		not (_run_finished or _floor_done), false, _current_layout())
	if why != "":
		return why
	record({"t": "twist", "twist": t})
	_dispatch(TwistApplier.apply(state, DB.data, t, _current_layout()))
	_twist_ids = TwistApplier.active_ids(state)
	return ""


## Effect of the active twists on `key` (TwistApplier.effect_pm; scenes: "enemy_sight_pm", "enemy_hear_pm").
func twist_effect_pm(key: String, default_pm: int) -> int:
	return TwistApplier.effect_pm(state, key, default_pm) if state != null else default_pm


## QA (debug overlay F6): a random twist the "dev" source may apply now, picked with
## SeedUtil.derive(seed, "dev_twist", next n) — recorded like every twist. {"id", "reason"} ("" = applied; with no
## candidate the reason of tw_lights_out tells why).
func dev_random_twist() -> Dictionary:
	if state == null or sim == null:
		return {"id": "", "reason": "run_not_active"}
	var layout: FloorLayout = _current_layout()
	var ids: PackedStringArray = TwistApplier.allowed_now(state, DB.data, sim.rules, sim.tick(),
		in_battle or _floor_done, "dev", layout)
	if ids.is_empty():
		return {"id": "", "reason": TwistApplier.validate(state, DB.data, {"id": "tw_lights_out", "src": "dev"},
			sim.rules, sim.tick(), in_battle or _floor_done, layout)}
	var n: int = int(TwistApplier.state_of(state).get("n", 0)) + 1
	var rng: RandomNumberGenerator = SeedUtil.make_rng(SeedUtil.derive(state.seed, "dev_twist", n))
	var id: String = ids[rng.randi_range(0, ids.size() - 1)]
	return {"id": id, "reason": apply_twist({"id": id, "src": "dev"})}


## Offline Regie (06 §5.7a): at every RegieDirector decision point of the exploration (live only, setting
## "Regie-Eingriffe"), unless M.O.D. live chooses the twists itself.
func _regie_tick() -> void:
	if replaying or state == null or sim == null or not settings.regie_twists or in_battle or _floor_done:
		return
	if mod_live != null and bool(mod_live.call("replaces_regie")):
		return
	if not RegieDirector.is_due(state, sim.rules):
		return
	var tw: Dictionary = RegieDirector.decide(state, DB.data, sim.rules, sim.tick(), _current_layout())
	if not tw.is_empty():
		apply_twist(tw)


## twist_ended for twists that ended outside the clock (battle count, safe-room visit, floor change).
func _sync_twist_ends() -> void:
	var now: PackedStringArray = TwistApplier.active_ids(state)
	for id: String in _twist_ids:
		if not now.has(id):
			Events.twist_ended.emit(id)
	_twist_ids = now


# ======================================================================================================================
# Live hooks (M8, 05 §11.3)
# ======================================================================================================================

## Event run end: summary → ScoreCalc → Leaderboard → Save; emits run_finished(summary). Once per run.
func finish_run(cause: StringName) -> Dictionary:
	if _run_finished or mode != &"event_offline" or state == null or replaying:
		return {}
	_run_finished = true
	var event_id: String = _event_def.id if _event_def != null else ""
	var summary: Dictionary = {}
	if state.floor_run != null:
		summary = state.floor_run.summary().duplicate(true)
	summary["cause"] = String(cause)
	summary["event_id"] = event_id
	summary["quest_complete"] = quest.is_complete() if quest != null else false
	summary["quest_progress"] = quest.progress() if quest != null else 0.0
	summary["quest_progress_ppm"] = quest.progress_ppm() if quest != null else 0
	summary["party_kos"] = int(state.floor_run.stats.get("party_kos", 0)) if state.floor_run != null else 0
	if state.show != null:
		summary["followers"] = state.show.followers
		summary["followers_gained_run"] = int(state.show.stats.get("followers_gained_run", 0))
		summary["achievements_total"] = state.show.achievements.size()
		# an event run starts from GameState.create_new: every achievement it holds was unlocked in this run
		summary["achievements_in_run"] = state.show.achievements.size()
	var scoring: Dictionary = _event_def.scoring if _event_def != null else {}
	var sc: Dictionary = ScoreCalc.score(summary, scoring)
	summary["score"] = int(sc.get("score", 0))
	summary["breakdown"] = sc.get("breakdown", {})
	var board: Leaderboard = Leaderboard.from_dict(Save.load_leaderboard(event_id))
	if board == null:
		board = Leaderboard.new()
	if sim != null:
		# final checkpoint + run_log.result {"cause", "final_hash", "ticks", "score"} (05 §10.6)
		summary["final_hash"] = sim.close(String(cause), {"score": summary["score"]})
	var header: Dictionary = run_log.header if run_log != null else {}
	# 05 §10.4 schema (S0 local: league "pur", verified "local"); replay_id + run_log_hash tie the entry to its replay
	# file (user://replays/<run_id>.json, stored compacted; run_log_hash covers the expanded form, R5b) so a later
	# uploader/verifier can check it. Local boards and replays are plain,
	# editable JSON — never uploaded, never trusted (05 §10.4). Casting (08 §2.7 Nr. 4): the entry carries no name —
	# display_name "" (EventInfo.entry_name shows the local player as "Sie").
	var entry: Dictionary = {
		"schema": 1, "event_id": event_id, "window_id": str(header.get("window_id", "")),
		"league": str(header.get("league", "pur")), "mode": "solo", "run_id": str(header.get("run_id", "")),
		"players": [{"player_id": "local", "display_name": "", "role": "kai"}],
		"score": summary["score"], "breakdown": summary["breakdown"], "quest_complete": summary["quest_complete"],
		"floor_timer_left_sec": int(time_left()), "run_wall_ms": 0, "flags": [],
		"difficulty": String(state.difficulty), "replay_id": str(header.get("run_id", "")),
		"run_log_hash": run_log.canonical_digest() if run_log != null else "", "data_hash": DB.data_hash(),
		"sim_version": RunSim.SIM_VERSION, "client_version": str(header.get("game_version", "")),
		"verified": "local", "finished_at": Time.get_datetime_string_from_system(true) + "Z",
	}
	summary["rank"] = board.add(entry)
	summary["entry"] = entry.duplicate(true)
	Save.save_leaderboard(event_id, board.to_dict())
	if run_log != null:
		Save.save_replay(run_log)
	Events.run_finished.emit(summary)
	return summary


## M8 — THE verifier of complete live runs (05 §11.4): replays a RunLog against a fresh GameState (a log that starts at
## a loaded save: against its anchor, the loaded state Save.load_slot stored in the header — RunSim.anchor_state) by
## driving the SAME Game/Show methods as the live run (record() is a no-op meanwhile, no Router/Save calls): RNG
## consumption (next_seed "battle"/"show"/"lootbox"/"gift"), Show reactions (hype, followers, milestones, achievements,
## sponsor gifts), safe-room bookkeeping and event rules (header.event_id → EventDef.rules) are identical by
## construction. The live context (state, log, sim, quest, …) is restored afterwards. Not during a combat (Show's battle
## state would be overwritten). Checkpoint k = state after all commands with k' <= k; the walk is RunLog.walk (shared
## with RunSim.replay). Same "errors" contract as RunSim.replay — a verifier needs errors == []: log schema / id
## problems (RunLog.validate), entries the RunLog rejected, a log from a save without a valid anchor and an unknown
## event (abort: no replay without its start state / rules), header ≠ event (RunSim.header_errors: fixed seed,
## difficulty, league), commands the rules refuse (RunRules.command_refusal, QA windows not allowed, combat entries
## without a combat) — they are skipped — and every gift Show refuses (gift_rejected: duplicates, caps, wrong target,
## run over …). Returns {"final_hash": String, "result": Dictionary, "mismatch_at": int (first failing checkpoint index,
## -1 = none), "errors": PackedStringArray, "version": String (RunSim.version_status: a log of another sim_version is
## not replayed — one error, mismatch_at -1, shown as "ältere Version", 08 §10.2 Nr. 7)}. until_tick >= 0: the clock
## steps on to that tick after the last command (the live sim.tick() — idle ticks in a safe room move the clock without
## a command). Echtzeitkampf (07 §10.6, R5a): real-time combats replay through this section's API in the loop of
## GameReplay._combat (combat checkpoints compared per tick; "combat_mismatch_at" in the result); a new run starts from
## RunRules.rt_start; a compacted log replays expanded.
func replay_log(p_log: RunLog, until_tick: int = -1) -> Dictionary:
	return GameReplay.new(self).run(p_log, until_tick)


# ======================================================================================================================
# Private helpers
# ======================================================================================================================

func _reset_run() -> void:
	timer_running = false
	safe_room_clock = false
	in_battle = false
	combat = null                             # Echtzeitkampf (07, R2): a new run never inherits a combat
	_acc = 0.0
	_blocking_dialogs = 0
	_event_def = null
	_run_finished = false
	_floor_done = false
	_scene_ctx = {}
	_quest_done = false
	_layout = null
	_layout_key = ""
	_cmd_id = 0
	_cmd_log = null
	_metric_fed = {}
	_twist_ids = PackedStringArray()
	quest = null
	run_log = null
	sim = null


## Header of a new run log (05 §10.6): run identity (run_id unique per attempt, player_id "local", event_id,
## window_id "" offline, league) + seed, slot, mode, difficulty, versions. No name (08 §2.7 Nr. 2: the replay builds
## its state with GameState.DEFAULT_NAME).
func _make_run_log(run_seed: int, slot: int, difficulty: StringName, event_id: String,
		league: String = "") -> RunLog:
	var rl: RunLog = RunLog.new()
	rl.header = {
		"schema": 1,
		"seed": run_seed,
		"slot": slot,
		"mode": String(mode),
		"difficulty": String(difficulty),
		"game_version": str(ProjectSettings.get_setting("application/config/version", "")),
		"sim_hz": TICKS_PER_SEC,
		"sim_version": RunSim.SIM_VERSION,
		"event_id": event_id,
		"run_id": RunLog.local_run_id(run_seed),
		"player_id": "local",
		"window_id": "",
		"league": league,
	}
	return rl


## The run's league (05 §10.1): `wanted` if it is one of rules.leagues, else the single league, else "pur" (S0 local
## runs are Pur-Liga, 05 §10.4).
static func _run_league(rules: Dictionary, wanted: String) -> String:
	var leagues: Variant = rules.get("leagues", ["pur"])
	if leagues is Array and (leagues as Array).has(wanted):
		return wanted
	if leagues is Array and (leagues as Array).has("pur"):
		return "pur"
	return str((leagues as Array)[0]) if leagues is Array and not (leagues as Array).is_empty() else "pur"


## The live clock: RunSim over `st` with the run identity of the run log header that writes its checkpoints into the
## current run_log (every 300 ticks, after battles / floor ends via request_checkpoint, close() at finish_run; 05 §3.3
## Nr. 8). Replays build their own sim without a log.
func _make_sim(st: GameState, rules: Dictionary) -> RunSim:
	var s: RunSim = RunSim.new(DB.data, st, rules, RunSim.identity_of(run_log.header if run_log != null else {}))
	s.run_log = run_log
	return s


func _load_event_def(event_id: String) -> EventDef:
	var catalog: EventCatalog = EventCatalog.new()
	if not catalog.load_file(EVENTS_PATH):
		push_warning("[Game] could not load %s: %s" % [EVENTS_PATH, "; ".join(catalog.errors)])
	return catalog.get_event(event_id)


func _credits() -> int:
	if state == null or state.inventory == null:
		return 0
	return state.inventory.credits


func _full_heal() -> void:
	Progression.full_heal(state, DB.data)
	Events.party_changed.emit()


## inventory_changed + credits_changed(credits, delta since `credits_before`).
func _emit_inventory(credits_before: int) -> void:
	Events.inventory_changed.emit()
	Events.credits_changed.emit(_credits(), _credits() - credits_before)


func _current_layout() -> FloorLayout:
	var def: FloorDef = floor_def()
	if def == null:
		return null
	var key: String = "%d:%d" % [state.floor_run.index, state.floor_run.seed]
	if _layout == null or _layout_key != key:
		_layout = DungeonGenerator.generate(def, state.floor_run.seed)
		_layout_key = key
	return _layout


func _dispatch(events: Array[ExploreEvent]) -> void:
	for ev: ExploreEvent in events:
		if ev == null:
			continue
		match ev.type:
			ExploreEvent.Type.TIMER_SECOND:
				Events.floor_timer_changed.emit(int(ev.data.get("seconds", floori(time_left()))))
			ExploreEvent.Type.TIMER_WARNING:
				Events.floor_timer_warning.emit(int(ev.data.get("seconds", 0)))
			ExploreEvent.Type.TIMER_EXPIRED:
				if state != null and state.season != null:   # Staffeln (09 §2.5, ST1-B): the collapse follows (SEASON)
					Events.floor_timer_expired.emit()
				else:
					timer_running = false
					Events.floor_timer_expired.emit()
					if replaying:
						on_game_over(&"timer")
					else:
						Router.game_over(&"timer")
					return
			ExploreEvent.Type.EXPLORE_TICK:
				Events.explore_tick.emit(ev.data.duplicate())
			ExploreEvent.Type.HYPE:
				Show.sync_from_state()
			ExploreEvent.Type.STRAY_DUE:
				Events.stray_spawn_requested.emit(str(ev.data.get("zone", "")), str(ev.data.get("group_id", "")),
					str(ev.data.get("encounter_id", "")))
			ExploreEvent.Type.SPONSOR_WINDOW_OPENED:
				Events.sponsor_window_opened.emit((ev.data.get("window", {}) as Dictionary).duplicate(true))
			ExploreEvent.Type.SPONSOR_WINDOW_CLOSED:
				Events.sponsor_window_closed.emit(str(ev.data.get("id", "")), str(ev.data.get("reason", "")))
			ExploreEvent.Type.TWIST_APPLIED:                 # 06-D
				var tv: Dictionary = (ev.data.get("twist", {}) as Dictionary).duplicate(true)
				tv["src"] = str(ev.data.get("src", ""))
				tv["n"] = int(ev.data.get("n", 0))
				_twist_ids = TwistApplier.active_ids(state)
				Events.twist_applied.emit(tv)
			ExploreEvent.Type.TWIST_ENDED:
				_twist_ids = TwistApplier.active_ids(state)
				Events.twist_ended.emit(str(ev.data.get("id", "")))
			ExploreEvent.Type.SEASON:                        # Staffeln (09, ST1-B)
				_season_event(ev)


func _on_mod_said(_text: String, _voice: StringName, _tag: String, blocking: bool) -> void:
	if blocking and _dialog_presenter:
		_blocking_dialogs += 1


func _on_dialog_finished(_tag: String) -> void:
	_blocking_dialogs = maxi(0, _blocking_dialogs - 1)


# --- quest adapter (05 CR-4): signals → normalized quest events ------------------------------------------------------

func _quest_feed(ev: Dictionary) -> void:
	if mode != &"event_offline" or quest == null or ev.is_empty():
		return
	if quest.on_event(ev):
		Events.quest_progress.emit(quest.progress())
	if quest.is_complete() and not _quest_done:
		_quest_done = true
		Events.quest_completed.emit()


func _on_quest_enemy_killed(payload: Dictionary) -> void:
	_quest_feed({"type": "enemy_killed", "enemy_id": str(payload.get("enemy_id", ""))})


func _on_quest_boss_defeated(payload: Dictionary) -> void:
	_quest_feed({"type": "boss_defeated", "boss_id": str(payload.get("boss_id", ""))})


## defeat_boss progress before the victory (05 §1.3; same rule as RunSim._quest_feed_battle).
func _on_quest_boss_hp(payload: Dictionary) -> void:
	_quest_feed({"type": "boss_hp", "boss_id": str(payload.get("boss_id", "")), "hp": int(payload.get("hp", 0)),
		"max_hp": int(payload.get("max_hp", 0))})


func _on_quest_battle_started(_encounter_id: String, _is_boss: bool) -> void:
	_quest_feed({"type": "battle_started"})


func _on_quest_floor_completed(floor_index: int) -> void:
	_quest_feed({"type": "floor_completed", "floor": floor_index})


func _on_quest_achievement(achievement_id: String) -> void:
	_quest_feed({"type": "achievement", "id": achievement_id})


func _on_quest_viewers_changed(_viewers: int) -> void:
	_quest_metric(METRIC_VIEWERS)


func _on_quest_followers_changed(_followers: int, _delta: int) -> void:
	_quest_metric(METRIC_FOLLOWERS)


func _on_quest_hype_changed(_hype: float, _delta: float, _reason: StringName) -> void:
	_quest_metric(METRIC_HYPE_100)


## {"type": "metric", "name", "value": int} from ShowState.stats (deterministic; never the noisy display viewers).
func _quest_metric(metric: String) -> void:
	if mode != &"event_offline" or quest == null or state == null or state.show == null:
		return
	var value: int = int(state.show.stats.get(metric, 0))
	if _metric_fed.has(metric) and int(_metric_fed[metric]) == value:
		return
	_metric_fed[metric] = value
	_quest_feed({"type": "metric", "name": metric, "value": value})


# --- replay context (GameReplay) -------------------------------------------------------------------------------------

func _capture_context() -> Dictionary:
	return {"state": state, "run_log": run_log, "sim": sim, "quest": quest, "mode": mode, "event_def": _event_def,
		"run_finished": _run_finished, "floor_done": _floor_done, "scene_ctx": _scene_ctx, "quest_done": _quest_done,
		"layout": _layout,
		"layout_key": _layout_key,
		"acc": _acc, "blocking": _blocking_dialogs, "timer_running": timer_running, "in_battle": in_battle,
		"safe_room_clock": safe_room_clock,
		"cmd_id": _cmd_id, "cmd_log": _cmd_log, "metric_fed": _metric_fed, "twist_ids": _twist_ids}


func _restore_context(saved: Dictionary) -> void:
	state = saved["state"] as GameState
	run_log = saved["run_log"] as RunLog
	sim = saved["sim"] as RunSim
	quest = saved["quest"] as QuestTracker
	mode = saved["mode"]
	_event_def = saved["event_def"] as EventDef
	_run_finished = bool(saved["run_finished"])
	_floor_done = bool(saved["floor_done"])
	_scene_ctx = saved["scene_ctx"]
	_quest_done = bool(saved["quest_done"])
	_layout = saved["layout"] as FloorLayout
	_layout_key = str(saved["layout_key"])
	_acc = float(saved["acc"])
	_blocking_dialogs = int(saved["blocking"])
	timer_running = bool(saved["timer_running"])
	safe_room_clock = bool(saved["safe_room_clock"])
	in_battle = bool(saved["in_battle"])
	_cmd_id = int(saved["cmd_id"])
	_cmd_log = saved["cmd_log"] as RunLog
	_metric_fed = saved["metric_fed"]
	_twist_ids = saved["twist_ids"]


# ======================================================================================================================
# Echtzeitkampf (07, R1a → R2 live part, R5a replay branch) — the API of 07 §10.6 / §9.2
# ======================================================================================================================
# --- Echtzeitkampf (07, R2) ---
# The live CombatDirector (R2) and GameReplay (R5a) use exactly these functions, per combat tick c:
# combat_boundary() → combat_submit(cmd) for every input with ct == c → combat_step(). Every run fights in real time
# (R5b part 2b: the CTB battle left the campaign for the Stempelduell, 10 SD1).

var combat: RtSim = null             # the running real-time combat; null outside one (a save never contains it)
## Test / capture seam (R2): when valid, make_rt_setup takes the combat from `rt_sim_factory.call(cmd, seed)` (an RtSim,
## e.g. the FakeRtSim of tests/fixtures/rt_world) instead of BattleBridge.make_rt_setup + RtSim.new — everything else
## (recording, seeds, Show, signals) is the live path. Never set by game code.
var rt_sim_factory: Callable = Callable()

var _rt_checkpoint_ct: int = -1       # last combat tick a combat checkpoint was written for

## Hints of the pause menu while a real-time fight runs (rt_party_lock).
const RT_LOCK_ITEMS: String = "Im Kampf: Gegenstände über das Item-Rad"
const RT_LOCK_EQUIP: String = "Im Kampf: Ausrüstung erst nach dem Kampf"


## While a real-time fight runs, the party changes only through the recorded combat commands: the pause menu pauses
## the sim (07 O2: offline, the tree is paused), field item use and equipment changes are refused (use_item / equip
## return false and record nothing) and the menu pages show this hint (`what` = &"items" | &"equipment"); "" when
## allowed.
func rt_party_lock(what: StringName = &"items") -> String:
	if combat == null:
		return ""
	return RT_LOCK_EQUIP if what == &"equipment" else RT_LOCK_ITEMS


## Records the encounter (with its "rt" block), draws the seeds "battle" (here) and "show" (Show.begin_battle), builds
## the setup with BattleBridge.make_rt_setup_rules (the run's rules: event_rules()), creates `combat`, sets in_battle,
## Show.begin_battle(setup), emits Events.combat_started(combat) and Events.battle_started, then feeds the ct-0 prelude
## of combat.start() to Show.on_battle_event / Events.combat_event (begin, battle_started, start events — listeners
## know the combat before its first event). null (nothing started, in_battle stays false) without a run, for a command
## without "rt" block or when no setup can be built (e.g. the stairs room): then only the encounter is recorded and the
## seed drawn — the replay draws the same seed.
func make_rt_setup(cmd: Dictionary) -> RtSetup:
	if state == null or cmd.is_empty() or str(cmd.get("t", "")) != "encounter" or not (cmd.get("rt", null) is Dictionary):
		return null
	if combat != null:
		push_warning("[Game] make_rt_setup: a real-time combat is already running")
		return null
	record(cmd)
	var seed_battle: int = next_seed("battle")
	var sim_new: RtSim = null
	if rt_sim_factory.is_valid():
		sim_new = rt_sim_factory.call(cmd, seed_battle) as RtSim
	else:
		# the run's rules (event / league: liga talents, rules.combat; R1b API)
		var built: RtSetup = BattleBridge.make_rt_setup_rules(state, DB.data, cmd, seed_battle, event_rules())
		if built != null:
			sim_new = RtSim.new(built, DB.data)
	if sim_new == null or sim_new.setup == null:
		push_warning("[Game] no RtSetup for '%s' (BattleBridge.make_rt_setup not ready?) — combat skipped"
			% str(cmd.get("enc", "")))
		return null
	combat = sim_new
	_rt_checkpoint_ct = -1
	in_battle = true
	var setup: RtSetup = combat.setup
	Show.begin_battle(setup)
	Events.combat_started.emit(combat)
	Events.battle_started.emit(setup.encounter_id, setup.is_boss)
	for e: ActionEvent in combat.start():
		Show.on_battle_event(e)
		Events.combat_event.emit(e)
	return setup


## One tick boundary before combat tick c = combat.tick() (07 §9.2): at most one gift (external first, then system)
## via Show.take_pending_gift_rt → combat.apply_gift → Show.on_battle_event / Events.combat_event /
## Show.note_battle_gift. Nothing without a running combat.
func combat_boundary() -> void:
	if combat == null or combat.is_finished():
		return
	var g: Dictionary = Show.take_pending_gift_rt(combat)   # external first (records {"t": "gift", …, "ct"}), then system
	if g.is_empty():
		return
	var ev: Array[ActionEvent] = combat.apply_gift(g)
	for e: ActionEvent in ev:
		Show.on_battle_event(e)
		Events.combat_event.emit(e)
	Show.note_battle_gift(g, ev)


## RtSim.submit + record (accepted commands only, 07 §10.2); "" or one of RtCommand.REASONS ("finished" without a
## running combat). R5a: a combat_hint is no input — hint cards go through combat_hint (it marks the card; recorded
## as an input it would replay differently) → "schema".
func combat_submit(cmd: Dictionary) -> String:
	if combat == null:
		return "finished"
	if str(cmd.get("t", "")) == "combat_hint":
		return "schema"
	var why: String = combat.submit(cmd)
	if why == "":
		record(cmd)
	return why


## A hint card was shown at the current combat tick: records {"t": "combat_hint", "ct", "id"} and sets
## state.flags["rt_hints"][id] = true (the sim ignores it, 07 §2.13). Nothing without a running combat or for an id
## that is neither a tutorial step nor a hint id.
func combat_hint(id: String) -> void:
	if combat == null or state == null:
		return
	var cmd: Dictionary = RtCommand.hint(combat.tick(), id)
	if RtCommand.validate(cmd) != "":
		push_warning("[Game] combat_hint: unknown hint id '%s'" % id)
		return
	record(cmd)
	RunRules.mark_hint(state, id)               # R5a: the rule RunSim applies too


## One combat tick: combat.step(), every event to Show.on_battle_event and Events.combat_event, combat checkpoints
## (07 §10.2: every CHECKPOINT_TICKS processed ticks and at the end, RunLog.add_checkpoint(k, StateHash.of_rt(combat),
## ct) with ct = combat.tick() after the step = processed ticks). [] without a running combat.
func combat_step() -> Array[ActionEvent]:
	var out: Array[ActionEvent] = []
	if combat == null or combat.is_finished():
		return out
	out = combat.step()
	for e: ActionEvent in out:
		Show.on_battle_event(e)
		Events.combat_event.emit(e)
	_combat_checkpoint()
	return out


## apply_battle_result(combat.result), Show.end_battle, Events.combat_finished(result), Events.battle_ended, then
## combat = null (07 §2.11, §10.6). Without a finished combat: an empty BattleRewards (an unfinished combat is
## dropped: no rewards, in_battle false, Show.abort_battle).
func end_combat() -> BattleRewards:
	if combat == null:
		return BattleRewards.new()
	var result: BattleResult = combat.result
	if result == null:
		combat = null
		in_battle = false
		Show.abort_battle()
		if _rt_speed_due:
			_rt_record_speed()
		return BattleRewards.new()
	_combat_checkpoint(true)
	var rewards: BattleRewards = apply_battle_result(result)
	rewards.followers = Show.end_battle(result)
	rewards.achievements = Show.unlocked_this_battle()
	combat = null
	Events.combat_finished.emit(result)
	Events.battle_ended.emit(result.outcome, result.encounter_id)
	if _rt_speed_due:
		_rt_record_speed()
	if state != null and state.season != null:
		_season_after_combat()                    # Staffeln (09 §9.1, ST1-B): its time next, the save after a combat
	return rewards


## Combat checkpoint at the explore tick of the encounter (the clock stands): every CHECKPOINT_TICKS processed ticks
## and once at the end; live only (the replay compares its own).
func _combat_checkpoint(force: bool = false) -> void:
	if combat == null or run_log == null or replaying:
		return
	var ct: int = combat.tick()
	var every: int = combat.setup.balance.i("CHECKPOINT_TICKS") if combat.setup.balance != null else 300
	var due: bool = force or combat.is_finished() or (every > 0 and ct > 0 and ct % every == 0)
	if not due or ct == _rt_checkpoint_ct:
		return
	var h: String = StateHash.of_rt(combat)
	if h == "":
		return
	_rt_checkpoint_ct = ct
	run_log.add_checkpoint(sim.tick() if sim != null else 0, h, ct)


var _rt_speed_pm: int = 1000          # the combat speed this run recorded last (07 §10.1 combat_speed)
var _rt_speed_due: bool = false       # a change during a combat: recorded at its end


## Game._ready: the combat speed recording (07 §10.1).
func _rt_ready() -> void:
	Events.settings_changed.connect(_rt_on_settings_changed)


## The start of a run (new game, event run): the run log header names the real-time run (07 §10.2: "combat_mode":
## "realtime", "rt_version": 1) and RunRules.rt_start gives full HP / MP (the real-time HP are in the data since R5b
## part 2b, 07 §3.9.4) — both verifiers repeat it for a new log.
func _rt_begin() -> void:
	_rt_speed_pm = 1000
	_rt_speed_due = false
	if state == null:
		return
	if run_log != null:
		run_log.header["combat_mode"] = String(RunRules.REALTIME)
		run_log.header["rt_version"] = RunRules.RT_VERSION
	RunRules.rt_start(state, DB.data)


## After the start commands of a new real-time run (floor, hero, persona): its combat speed when it is not 1000 ‰.
func _rt_run_started() -> void:
	_rt_record_speed()


## 07 §10.1 / §7.6 (O1): a real-time run records every change of GameSettings.combat_speed_pm as {"t":
## "combat_speed", "pm"} (no sim effect; leaderboards mark "Zeitlupe"). During a combat the change is recorded at its
## end — a command without "ct" inside a combat would end it in the replay (07 §10.5).
func _rt_on_settings_changed() -> void:
	if combat != null:
		_rt_speed_due = state != null and settings != null and settings.combat_speed_pm != _rt_speed_pm
		return
	_rt_record_speed()


func _rt_record_speed() -> void:
	_rt_speed_due = false
	if state == null or settings == null or run_log == null or replaying:
		return
	var pm: int = settings.combat_speed_pm
	if pm == _rt_speed_pm or not RtVocab.COMBAT_SPEEDS.has(pm):
		return
	_rt_speed_pm = pm
	record(RtCommand.speed(pm))


## True with a running game: every run fights in real time since R5b part 2b (the CTB battle went to the Stempelduell,
## 10 SD1). No game code asks any more (ST0 asks has_state); kept as public API for tools and tests.
func is_realtime() -> bool:
	return state != null


## A ModDialog presents lines (blocking lines wait for the player): the boss intro waits for its line only then.
func has_dialog_presenter() -> bool:
	return _dialog_presenter


# --- Echtzeitkampf (07, R5a) ---

## The recording entry of the loadout command (R5a; 07 §4.1 action bar variants, §5.2 partner tactic — chosen outside
## a combat in the skills menu): Command.validate (schema) + RunRules.loadout_refusal (a real-time run, a party member,
## variants of their slot up to the member's level), never during a combat (rt_party_lock) → record →
## RunRules.apply_loadout → party_changed. false = refused, nothing recorded. The command comes from
## RunRules.loadout_cmd(member, bar, preset, tog); GameReplay replays "loadout" through here, RunSim.apply runs the same
## check and rule. The next combat's setup reads the choice (BattleBridge.make_rt_setup).
func apply_loadout(cmd: Dictionary) -> bool:
	if state == null or str(cmd.get("t", "")) != "loadout" or Command.validate(cmd) != "" or rt_party_lock() != "":
		return false
	if RunRules.loadout_refusal(state, DB.data, cmd) != "":
		return false
	record(cmd)
	RunRules.apply_loadout(state, cmd)
	Events.party_changed.emit()
	return true


# ======================================================================================================================
# Casting (08, K0 → K1 persona command / K2 look) — the API of 08 §10.2 Nr. 8
# ======================================================================================================================
# K1: the persona command is recorded for every new game with a profile (the casting; the full-run bot). K2: the look
# reaches the real-time combat through the puppets (DB.party_model, 07 §12.9 Nr. 16; presentation only).

## The candidate persona of the running slot (08 §2.2): local presentation data (name, form, job, look, …), never
## part of GameState, the run log or a hash; the core only sees the ids of the "persona" command. null = no persona
## (a game started without the casting: tests, autoplay, event runs) — no persona lines then.
var persona: PersonaProfile = null


## The one recording entry of the "persona" command (08 §2.3): Command.validate (schema) + PersonaRules.check (event
## runs → event_run) → record → PersonaRules.apply; emits party_changed. false = refused, nothing recorded.
## GameReplay replays "persona" through it (same check, same apply as RunSim.apply).
func apply_persona(cmd: Dictionary) -> bool:
	if state == null or str(cmd.get("t", "")) != "persona" or Command.validate(cmd) != "":
		return false
	if PersonaRules.check(state, DB.data, cmd, sim != null and sim.is_event_run()) != "":
		return false
	record(cmd)
	PersonaRules.apply(state, DB.data, cmd)
	Events.party_changed.emit()
	return true


## K1 (08 §2.3): with a profile, the display fields follow it (P-2: never in the hash or a file) and the start
## command PersonaRules.command_for(DB.data, p) — v2 since 09 ST0: the head-start profession and the hobby recipe
## (ids only, no origin or hobby id), the bias from the traits — is recorded through apply_persona right after the
## hero (floor → hero → persona). Never in event runs (they have no persona, 08 §8); without a profile nothing
## happens.
func _choose_initial_persona(p: PersonaProfile) -> void:
	if p == null or state == null or mode != &"campaign":
		return
	if p.beats.is_empty():
		p.make_beats(DB.data, null)
	PersonaPrivacy.restore_display(state, p)
	apply_persona(PersonaRules.command_for(DB.data, p))


# ======================================================================================================================
# Staffeln (09 §9.1, ST0 → ST1-B) — the season facades and the live season; ST1-B (season, clock, sleep, the wall clock,
# saving, journal, routing), ST1-G (away), ST1-D (talent rows), ST1-E (professions) and ST1-F (cast) fill the rules
# ======================================================================================================================
# Every facade builds its command (09 §9.1) and goes the one recording path of _season_command: Command.validate +
# RunRules.command_refusal (SeasonRules.gate, season_refusal: no season → no_season, the module stubs of the packages to
# come → season_unavailable) → record (and the slot's journal) → RunRules.apply_season → the explore events through
# _dispatch (_season_event). false = refused, nothing recorded. GameReplay replays the season commands through these
# facades. Seasons start only through start_season — in ST1 from the debug boot argument --season (boot.gd, debug builds
# only, README §6) until "Sendung starten" becomes the default (ST1-H, the ST1 gate).
#
# The live season (ST1-B, never while replaying): the wall clock (_season_process: one "clock" command per 60 s of wall
# time in the season views — exploration, safe room —, the time of a combat right after it, × season_speed in debug
# builds; a backwards clock stands until it catches up; a gap over 10 min is an absence → "away", ST1-G), the
# persistent save (after every combat, at every safe-room visit, at a floor change, at logout, at the latest every 60 s;
# Save writes the journal in between), the routing of the season events (rescue → the next floor, out → Sendeschluss,
# end / finale → Abspann, left → title, death → Router.game_over → season_defeat_route) and M.O.D.'s season lines.

## Zeitraffer (09 §2.1: debug builds and the harness only): season seconds per wall-clock second of the live clock.
var season_speed: int = 1
## The live season clock records "clock" from the wall clock (_season_process); off in tests and tools (ephemeral).
var season_live_clock: bool = false

const SEASON_CLOCK_STEP_SEC: int = 60      # 09 §9.1: one clock command per 60 s of wall time
const SEASON_AWAY_SEC: int = 600           # 09 §5.1: more than 10 min of pause or background is an absence
const SEASON_SAVE_SEC: int = 60            # 09 §9.1: a season saves at the latest every 60 s
const SEASON_SPEED_MAX: int = 10080        # Zeitraffer: 60 s × speed stays one clock jump (7 days)

var _season_fight_ended: bool = false      # a combat ended: its time is recorded right away (V-17: + 2 min grace)
var _season_saved_at: int = 0              # wall clock of the last season save


## A new game in a season ("Sendung starten" / "Neue Staffel", 09 §2.2): like new_game, with the "season" start
## command before floor → hero → persona. `opts`: "tempo" (calendar | binge — binge private only), "mode" (net | no_net
## — Ohne Netz needs the account's unlock, Save.career(), unless "unlock": true, the debug boot argument), "air_time"
## ("HH:MM" local; default the template's), "seed" (-1 = time based), "difficulty", "name", "now" (unix seconds of the
## start; default the wall clock), "tz_sec" (the local UTC offset; default the system's), "number" (default the career
## counter + 1). Day 0 is the first air time at or after the start, every collapse date follows from it (SeasonClock,
## V-17). Saves the slot at once (the journal starts; slot 0 is never written). false = refused (unknown template, a
## start SeasonRules refuses, a locked Ohne Netz) — nothing changes then.
func start_season(slot: int, def_id: String, opts: Dictionary = {}, hero_id: String = HeroRules.DEFAULT_HERO,
		p_persona: PersonaProfile = null) -> bool:
	if DB.data == null or not DB.data.has_id("seasons", def_id):
		push_warning("[Game] start_season: unknown season template '%s'" % def_id)
		return false
	var def: SeasonDef = DB.season_def(def_id)
	var season_mode: String = str(opts.get("mode", "net"))
	if season_mode == "no_net" and not bool(opts.get("unlock", false)) and not bool(Save.career().get("no_net", false)):
		push_warning("[Game] start_season: Ohne Netz is locked (09 §2.2: after the first class choice or a season)")
		return false
	var now_utc: int = int(opts.get("now", int(Time.get_unix_time_from_system())))
	var air: int = SeasonClock.air_seconds(str(opts.get("air_time", def.air_time)))
	if air < 0:
		air = SeasonClock.air_seconds(def.air_time)
	var day0: int = SeasonClock.day0(now_utc, air, int(opts.get("tz_sec", _season_tz_offset())))
	var cmd: Dictionary = {"t": "season", "v": Command.SEASON_VERSION, "op": "start", "def": def_id,
		"format": def.format, "tempo": str(opts.get("tempo", "calendar")), "mode": season_mode,
		"number": maxi(1, int(opts.get("number", int(Save.career().get("seasons", 0)) + 1))), "day0_utc": day0,
		"collapse_utc": SeasonClock.schedule(day0, def.format), "cast": CastSim.start_block(def, def.min_humans),
		"utc": now_utc}
	var run_seed: int = int(opts.get("seed", -1))
	if run_seed == -1:
		run_seed = int(Time.get_unix_time_from_system() * 1000.0) & 0x7FFFFFFF
	var difficulty: StringName = StringName(str(opts.get("difficulty", "prime")))
	var fresh: GameState = GameState.create_new(DB.data, slot, str(opts.get("name", GameState.DEFAULT_NAME)), run_seed,
		difficulty)
	var why: String = Command.validate(cmd) if fresh != null else "no game state"
	if why == "":
		why = RunRules.command_refusal(fresh, DB.data, {}, cmd, false, {})
	if why != "":
		push_warning("[Game] start_season refused: %s" % why)
		return false
	_reset_run()
	mode = &"campaign"
	state = fresh
	run_log = _make_run_log(run_seed, slot, difficulty, "")
	_rt_begin()
	sim = _make_sim(state, {})
	persona = p_persona
	_season_command(cmd)
	state.season.seen_unix = int(Time.get_unix_time_from_system())   # the wall clock (never hashed)
	start_floor(1)
	_choose_initial_hero(hero_id)
	_choose_initial_persona(p_persona)
	_rt_run_started()
	Save.career_set("seasons", maxi(int(Save.career().get("seasons", 0)), int(cmd["number"])))
	Events.new_game_started.emit(slot)
	if not replaying:
		Show.say("season_start")
	_cast_news_reset(0)                       # ST1-F: every breaking news of the new season is still to come
	_season_autosave()
	return true


## A "season" command (09 §9.1: tempo, pause, leave; the replay also passes its start).
func season_op(cmd: Dictionary) -> bool:
	return str(cmd.get("t", "")) == "season" and _season_command(cmd)


## The season clock (09 §9.1, external input): `sec` of wall-clock time ({"t": "clock", "sec"}).
func season_clock(sec: int) -> bool:
	return _season_command({"t": "clock", "sec": sec})


## Login after an absence (09 §5.5, external input): {"t": "away", "sec"}.
func season_away(sec: int) -> bool:
	return _season_command({"t": "away", "sec": sec})


## Logout with the sleeping tactic (09 §5.1; RtVocab.RT_PRESETS): {"t": "sleep", "tactic", "cell"}, then the save (09
## §9.1: "sleep → Speichern → Titel" — the caller, ST1-G's logout dialog, goes to the title). ST1-G: season_logout.
func logout(tactic: String) -> bool:
	return season_logout(tactic, season_cell())


## A row of the talent tree (09 §8.4): {"t": "talent", "v": 2, "member", "row", "id"}.
func pick_talent_row(member_id: String, row: int, talent_id: String) -> bool:
	return _season_command({"t": "talent", "v": Command.TALENT_ROW_VERSION, "member": member_id, "row": row,
		"id": talent_id})


## The Gewerke-Büro (09 §8.5): {"t": "prof", "op": learn | unlearn | rank | head, "id"}.
func prof_action(op: String, prof_id: String) -> bool:
	return _season_command({"t": "prof", "op": op, "id": prof_id})


## A gathering node (09 §8.5): {"t": "gather", "node"}.
func gather(node_id: String) -> bool:
	return _season_command({"t": "gather", "node": node_id})


## Crafting in a safe room (09 §8.5): {"t": "craft", "recipe", "n"}.
func craft(recipe_id: String, n: int = 1) -> bool:
	return _season_command({"t": "craft", "recipe": recipe_id, "n": n})


## The AI candidates (09 §4.3): {"t": "cast", "op": hire | trade | help, "who" (their place), "item"?}.
func cast_action(op: String, who: int, item: String = "") -> bool:
	var cmd: Dictionary = {"t": "cast", "op": op, "who": who}
	if item != "":
		cmd["item"] = item
	return _season_command(cmd)


## Never during a combat (09 §9.1: the clock and every season command act outside a combat; the time of a combat comes
## after it).
func _season_command(cmd: Dictionary) -> bool:
	if state == null or combat != null or Command.validate(cmd) != "":
		return false
	var rules: Dictionary = sim.rules if sim != null else {}
	if RunRules.command_refusal(state, DB.data, rules, cmd, _floor_done, _scene_ctx,
			sim != null and sim.is_event_run()) != "":
		return false
	record(cmd)
	_season_last_events = RunRules.apply_season(state, DB.data, cmd)   # ST1-G: the login summary reads them
	_dispatch(_season_last_events)
	return true


# --- Staffeln (09, ST1-B): the live season ---------------------------------------------------------------------------

## Save.load_slot replays the journal of a season slot (09 §9.1, V-3) from the loaded save `st` (GameReplay.resume —
## Game.replay_log's engine; a combat the journal ends in is decided by the autopilot from its start). {"state":
## GameState (null on a failure), "errors": PackedStringArray, "autopilot": bool}.
func season_resume(st: GameState, entries: Array) -> Dictionary:
	return GameReplay.new(self).resume(st, entries)


## Save.load_slot after a season slot was adopted (09 §9.1, "Login: away → Login-Bilanz → Welt"): the absence since the
## wall clock seen last (× Zeitraffer) wakes the sleeper — ST1-G: _season_wake_up (an awake figure gone over 10 min
## sleeps first, a jump over seven days waits for the question of the wake summary); the wall clock is seen now.
func season_login() -> void:
	if replaying or state == null or state.season == null:
		return
	var wall: int = int(Time.get_unix_time_from_system())
	var s: SeasonState = state.season
	var sec: int = 0
	if season_live_clock and s.seen_unix > 0 and wall > s.seen_unix and s.tempo == "calendar":
		sec = (wall - s.seen_unix) * clampi(season_speed, 1, SEASON_SPEED_MAX)
	_season_saved_at = wall
	season_wake = {}                              # Staffeln (09 §5.5, ST1-G): this login's summary only
	_season_wake_n += 1
	_season_wake_up(sec)
	if season_wake.has("question"):               # the absence is not booked before the answer (V-17)
		return
	s.seen_unix = maxi(s.seen_unix, wall)
	_cast_news_reset(CastSim.last_seq(state))   # ST1-F: the news until the login are the Login-Bilanz's (ST1-G)


## Router.game_over in a season (09 §7): no game over — the death rule ran at the end of the combat
## (SeasonRules.on_combat_end): Mit Netz and the dress rehearsal go back into the exploration at the medics'
## destination (a safe room is entered from there), an Ohne-Netz candidate who is out sees the Sendeschluss screen.
## true = routed (Router does nothing more); false without a season.
func season_defeat_route(reason: StringName) -> bool:
	if state == null or state.season == null:
		return false
	timer_running = false
	in_battle = false
	if state.season.result != "" or state.floor_run == null:
		Router.goto(Router.SCENE_GAME_OVER, {"reason": reason})
	else:
		Router.goto(Router.SCENE_EXPLORATION, {"spawn": state.floor_run.location})
	return true


## The stairs lead down now (SeasonRules.gate for "descend": asleep, over, the staircase rule) — else M.O.D. says why
## ("Kulissen im Aufbau"; the stairs dialog itself is ST1-H's).
func _season_stairs_open() -> bool:
	var why: String = SeasonRules.gate(state, DB.data, {"t": "descend"}, false)
	if why == "":
		return true
	push_warning("[Game] the stairs are closed in this season (%s)" % why)
	if not replaying and why == "floor_closed":
		Show.say("season_stairs_closed")
	return false


## A SEASON event (09, ST1-B; SeasonRules' class doc) of the live run and of Game.replay_log: a rescue moved the run to
## a new floor — the twists of the old floor end (RunRules.season_moved), the floor context, Show.start_floor (hype and
## the floor's preferences, like start_floor), the Sponsor-Fenster floor trigger. Live only: M.O.D.'s line, the save and
## the route.
func _season_event(ev: ExploreEvent) -> void:
	var kind: String = str(ev.data.get("kind", ""))
	_level_event(ev)                              # ST1-D: EXP, the Regie-Crashkurs, the talent tree
	if kind == "rescue":
		var idx: int = int(ev.data.get("floor", 0))
		RunRules.season_moved(state, idx)
		_floor_done = false
		_scene_ctx = {}
		_acc = 0.0
		_layout = null
		_layout_key = ""
		clear_blocking_dialogs()
		Show.start_floor(idx)
		if sim != null:
			_dispatch(sim.sponsor_floor())
		_sync_twist_ends()
	if kind == "rescue" or kind == "death":
		Show.sync_from_state()
		Events.party_changed.emit()
		Events.inventory_changed.emit()
		Events.credits_changed.emit(_credits(), 0)
	if _season_quiet():                           # ST1-G: a night being booked is told by the wake summary
		return
	var waived: String = str(ev.data.get("waived", ""))
	match kind:
		"rescue":
			Show.say("season_rescue_free" if waived != "" else "season_rescue")
			_season_autosave()
			_season_goto.call_deferred(Router.SCENE_EXPLORATION, str(ev.data.get("location", "start")))
		"death":
			Show.say("season_medics" if waived == "" else "season_medics_" + ("rehearsal" if waived == "rehearsal"
				else "free"))
		"daily":
			Show.say("season_daily")
		"out":
			Show.say("season_out")
			_season_autosave()
			if combat == null:                    # buried (a death goes Router.game_over → season_defeat_route)
				_season_goto.call_deferred(Router.SCENE_GAME_OVER, "timer")
		"finale", "end":
			Show.say("season_content" if str(ev.data.get("why", "")) == "content" else "season_" + kind)
			_season_autosave()
			if not _floor_done:                   # by the stairs: the floor summary first (continue_after_summary)
				_season_goto.call_deferred(Router.SCENE_CREDITS, "")
		"left":
			_season_autosave()
			_season_goto.call_deferred(Router.SCENE_TITLE, "")
		"cast":                                   # ST1-F: the answers to the candidate's own "cast" commands
			_cast_answer(ev)


## The deferred route of a season event (after the frame's processing): the exploration of the new floor at
## `arg` (its first safe room — entered from there — or the entrance; a floor without playable content shows the
## Abspann, like the campaign's last floor), the Sendeschluss screen (reason `arg`), the credits or the title.
func _season_goto(path: String, arg: String) -> void:
	if state == null or replaying:
		return
	timer_running = false
	if path == Router.SCENE_EXPLORATION:
		var def: FloorDef = floor_def()
		if def == null or not def.playable:
			Router.goto(Router.SCENE_CREDITS)
		else:
			Router.goto(Router.SCENE_EXPLORATION, {"spawn": StringName(arg if arg != "" else "start")})
	elif path == Router.SCENE_GAME_OVER:
		Router.goto(Router.SCENE_GAME_OVER, {"reason": StringName(arg)})
	else:
		Router.goto(path)


## Game.end_combat in a season (live): the combat's time comes with the next clock command (the wall clock ran on), then
## the save after every combat (09 §9.1) — it starts a new journal.
func _season_after_combat() -> void:
	if replaying:
		return
	_season_fight_ended = true
	_season_autosave()


## The persistent save of a season (09 §9.1: after a combat, at a safe-room visit, at a floor change, at logout, at the
## latest every 60 s): never during a combat or a replay; slot 0 is never written. The account keeps the Ohne-Netz
## unlock once the season earned it (SeasonRules.unlocks_no_net: the first class choice, a season played to its end).
func _season_autosave() -> void:
	if replaying or state == null or state.season == null or combat != null or in_battle:
		return
	_season_saved_at = int(Time.get_unix_time_from_system())
	if SeasonRules.unlocks_no_net(state):
		Save.career_set("no_net", true)
	if state.slot > 0:
		Save.autosave()


## The live wall clock of a calendar season (_process; 09 §9.1, V-17): in the season views (exploration, safe room;
## never in a combat) one "clock" command per 60 s of wall time — right away after a combat (its time, V-17) and every
## second under the Zeitraffer; a backwards wall clock stands until it catches up; a gap over 10 min is an absence
## (_season_absence). The 60-s save.
func _season_process() -> void:
	if replaying or not season_live_clock or state.season == null or combat != null or in_battle:
		return
	if not (timer_running or safe_room_clock):
		return
	var s: SeasonState = state.season
	var wall: int = int(Time.get_unix_time_from_system())
	if s.seen_unix <= 0:
		s.seen_unix = wall
	var speed: int = clampi(season_speed, 1, SEASON_SPEED_MAX)
	if wall > s.seen_unix and s.tempo == "calendar" and not s.asleep:
		var gap: int = wall - s.seen_unix
		var step: int = maxi(1, SEASON_CLOCK_STEP_SEC / speed)
		if gap > SEASON_AWAY_SEC:
			_season_absence(gap * speed)
			s.seen_unix = wall
		elif gap >= step or (_season_fight_ended and gap >= 1):
			season_clock(gap * speed)
			s.seen_unix = wall
			_season_fight_ended = false
	if wall - _season_saved_at >= SEASON_SAVE_SEC:
		_season_autosave()
	_cast_news()                              # ST1-F: the breaking news of the AI cast


## An absence of `sec` season seconds in the live views (09 §5.1 Nr. 2: over 10 min of pause or background count as a
## logout) — ST1-G: the figure sleeps where it stood, the night is booked (or the clock-jump question waits), and the
## wake summary shows it.
func _season_absence(sec: int) -> void:
	if state == null or state.season == null or sec <= 0:
		return
	_season_wake_n += 1
	_season_wake_up(sec)
	if not season_wake.is_empty():
		_season_wake_route.call_deferred(_season_wake_n)


## The local UTC offset in seconds (Time zone bias of the system; the client's, never the core's).
static func _season_tz_offset() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0)) * 60


# --- Staffeln (09 §11.1, ST1-C): the debug stairs --------------------------------------------------------------------

## Debug builds and the test tools only (boot --floor, the capture recipes, the perf probe): the stairs of the running
## season without walking to them — "descend" and the next "floor" as recorded commands, like complete_floor and
## continue_after_summary without the Etagen-Bilanz (both verifiers accept the pair; the staircase rule applies: Am
## Stück every floor, the calendar the open ones). false when refused or when the stairs ended the season.
func season_debug_descend() -> bool:
	if state == null or state.season == null or state.floor_run == null or not _season_stairs_open():
		return false
	timer_running = false
	record({"t": "descend"})
	_dispatch(SeasonRules.on_descend(state, DB.data))
	if state.season.result != "":
		return false
	start_floor(state.floor_run.index + 1)
	return true


# --- Staffeln (09 §4.6, ST1-F): the breaking news of the AI cast -----------------------------------------------------
# The cast's newsworthy events (CastSim: the ticker of the season block) become M.O.D. lines cast_<kind> — at most one
# per CAST_NEWS_GAP_SEC of play time, never in a combat, the most important one first (the rest stays in the ticker for
# ST1-H's Staffel tab); in a session on floor 1 the introduction comes first (09 §0.5). Live only, never recorded:
# presentation like every M.O.D. line (_cast_news at the end of _season_process: the season views, no combat, no
# replay). The candidate's own "cast" commands get their answer right away (_cast_answer).

const CAST_NEWS_GAP_SEC: float = 600.0     # 09 §4.6: höchstens eine Eilmeldung je 10 min Spielzeit
## The answers to the candidate's "cast" commands and their guest (CastEvent kind → M.O.D. tag).
const CAST_ANSWER_TAGS: Dictionary = {"hired": "cast_hired", "help": "cast_help", "helped": "cast_helped",
	"guest_end": "cast_guest_end"}

var _cast_news_seq: int = 0                # the cast's events up to this number were news (or are the login's)
var _cast_news_at: float = -1.0e9          # play time of the last breaking news
var _cast_intro_said: bool = false         # the introduction of the cast (09 §0.5) in this session


## The next breaking news when it is due: the most important news since the last one (CastSim.news) as its M.O.D. line;
## the less important ones leave the news (they stay in the ticker). A line Show suppresses comes again later.
func _cast_news() -> void:
	if replaying or state == null or state.season == null or combat != null or in_battle:
		return
	if state.play_time_sec - _cast_news_at < CAST_NEWS_GAP_SEC or not CastSim.has_cast(state):
		return
	var items: Array[Dictionary] = CastSim.news(state, DB.data, _cast_news_seq)
	if items.is_empty():
		return
	var tag: String = str(items[0]["tag"])
	var ctx: Dictionary = items[0]["ctx"]
	if not _cast_intro_said and state.floor_run != null and state.floor_run.index == 1:
		tag = "cast_intro"                    # 09 §0.5: "Sie sind nicht allein …" — the news follow
		ctx = {}
	if Show.say(tag, ctx) == "":
		return
	_cast_news_at = state.play_time_sec
	if tag == "cast_intro":
		_cast_intro_said = true
	else:
		_cast_news_seq = CastSim.last_seq(state)


## A new season (0) or a login (the newest event: what happened before belongs to the Login-Bilanz, ST1-G).
func _cast_news_reset(seq: int) -> void:
	_cast_news_seq = seq
	_cast_news_at = -1.0e9
	_cast_intro_said = false


## M.O.D. answers the candidate's own "cast" command (hire, help) and the guest's farewell (live only).
func _cast_answer(ev: ExploreEvent) -> void:
	var kind: String = str(ev.data.get("ev", ""))
	if CAST_ANSWER_TAGS.has(kind):
		Show.say(str(CAST_ANSWER_TAGS[kind]), {"cand": CastSim.label(state, DB.data, int(ev.data.get("who", -1))),
			"count": int(ev.data.get("n", 0))})


# --- Staffeln (09 §8.2–8.4, ST1-D): levels, the ability book, the talent tree -----------------------------------------
# The core decides (LevelBand, AbilityBook, TalentTree); here the signals of a level-up that came without a combat (the
# SEASON events "exp" — stairs, floor event — and "crash"; live and in Game.replay_log alike, Show counts them for its
# achievements) and, live only, the toasts and M.O.D.'s one-sentence lines (09 §0.5): new abilities ("Neue
# Fähigkeit"), a class rank, the rows of the talent tree ("TALENT-SHOW BEREIT"), Überstunden, Aufholjagd, Crashkurs.

## The level part of a SEASON event (_season_event): "exp" and "crash" bring level-ups, "talent" is a pick of the tree
## (Game.pick_talent_row), "rescue" may put the party into the catch-up of its new floor.
func _level_event(ev: ExploreEvent) -> void:
	match str(ev.data.get("kind", "")):
		"exp":
			var members: Dictionary = ev.data.get("members", {})
			var ids: Array = members.keys()
			ids.sort()
			for mid: Variant in ids:
				var e: Dictionary = members[mid]
				_level_signals(str(mid), int(e.get("from", 0)), int(e.get("level", 0)),
					PackedStringArray(e.get("learned", [])))
			Events.party_changed.emit()
			if int(ev.data.get("overtime", 0)) > 0:
				Events.credits_changed.emit(_credits(), int(ev.data.get("overtime", 0)))
			if not _season_quiet():               # ST1-G: quiet while a night is booked
				_level_exp_notes(ev.data)
		"crash":
			var lifted: Dictionary = ev.data.get("members", {})
			var lids: Array = lifted.keys()
			lids.sort()
			for mid: Variant in lids:
				var span: Array = lifted[mid]
				var m: PartyMember = state.member(str(mid))
				var learned: PackedStringArray = PackedStringArray()
				if m != null:
					learned = AbilityBook.new_between(m, DB.data, int(span[0]), int(span[1]))
				_level_signals(str(mid), int(span[0]), int(span[1]), learned)
			Events.party_changed.emit()
			Events.inventory_changed.emit()
			if not _season_quiet():               # ST1-G: the wake summary tells the Crashkurs
				Show.say("season_crash_course")
				var parts: PackedStringArray = []
				for mid: Variant in lids:
					var m2: PartyMember = state.member(str(mid))
					var span2: Array = lifted[mid]
					parts.append("%s: Stufe %d auf %d" % [_level_who(m2) if m2 != null else str(mid),
						int(span2[0]), int(span2[1])])
				Events.toast_requested.emit(", ".join(parts) + " · Aufholpaket im Inventar", &"crash")
		"talent":
			Events.talent_picked.emit(str(ev.data.get("member", "")), str(ev.data.get("id", "")))
			Events.party_changed.emit()
		"rescue":
			if not _season_quiet():               # ST1-G
				_level_floor_notes()


## The signals of a level-up from `from` to `to` (like apply_battle_result): member_leveled, one level_up per level,
## talent_pending for every row of the tree it opens; live the toasts of _level_notes.
func _level_signals(mid: String, from: int, to: int, learned: PackedStringArray) -> void:
	var m: PartyMember = state.member(mid) if state != null else null
	if m == null or to <= from:
		return
	Events.member_leveled.emit(mid, to, learned)
	for lv in range(from + 1, to + 1):
		Events.level_up.emit({"member": mid, "level": lv})
	for row: int in TalentTree.rows_between(DB.data, m, from, to):
		Events.talent_pending.emit(mid, row)
	if not _season_quiet():                       # ST1-G: quiet while a night is booked
		_level_notes(m, from, to, learned)


## Live: after a combat in a season — the notes of every level-up, the Überstunden.
func _level_after_combat(rw: BattleRewards) -> void:
	if replaying:
		return
	for info: LevelUpInfo in rw.level_ups:
		var m: PartyMember = state.member(info.member_id) if info != null else null
		if m != null:
			_level_notes(m, info.old_level, info.new_level, info.learned)
	if rw.overtime > 0:
		Events.toast_requested.emit("+%d Credits: EXP über dem Deckel dieser Etage" % rw.overtime, &"overtime")
		Show.say("season_overtime")


## Live: the toasts of a level-up — new abilities (09 §8.3 banner), a class rank, the rows of the tree.
func _level_notes(m: PartyMember, from: int, to: int, learned: PackedStringArray) -> void:
	var who: String = _level_who(m)
	for sid: String in learned:
		var sk: SkillDef = DB.skill(sid) if DB.has_id("skills", sid) else null
		Events.toast_requested.emit("%s: %s — im Fähigkeitenbuch auf die Leiste legen" % [who,
			sk.name if sk != null else sid], &"ability")
	if not learned.is_empty():
		Show.say("season_ability")
	var ranks: Array = DB.class_def(m.class_id).rt.get("ranks", []) as Array \
		if m.class_id != "" and DB.has_id("classes", m.class_id) else []
	for i in ranks.size():
		var lv: int = int((ranks[i] as Dictionary).get("level", 99))
		if lv > from and lv <= to:
			Events.toast_requested.emit("%s: Rang %s — alle Klassenfähigkeiten stärker" % [who,
				AbilityBook.RANK_NAMES[i + 2]], &"ability")
			Show.say("season_rank", {"count": AbilityBook.RANK_NAMES[i + 2]})
	var rows: PackedInt32Array = TalentTree.rows_between(DB.data, m, from, to)
	if not rows.is_empty():
		Events.toast_requested.emit("%s: neue Talentreihe (Stufe %d) — im Safe Room wählen" % [who, rows[0]],
			&"talent")


## Live: the stairs / event EXP in one toast per member ("+120 EXP · Etagen-Abschluss").
func _level_exp_notes(data: Dictionary) -> void:
	var members: Dictionary = data.get("members", {})
	var ids: Array = members.keys()
	ids.sort()
	var what: String = "Etagen-Abschluss" if str(data.get("source", "")) == "stairs" else "Etagen-Event"
	for mid: Variant in ids:
		var e: Dictionary = members[mid]
		var m: PartyMember = state.member(str(mid))
		if int(e.get("gained", 0)) > 0 and m != null:
			Events.toast_requested.emit("%s: +%d EXP · %s" % [_level_who(m), int(e["gained"]), what],
				&"exp")
	if int(data.get("overtime", 0)) > 0:
		Events.toast_requested.emit("+%d Credits: EXP über dem Deckel dieser Etage" % int(data["overtime"]),
			&"overtime")


## Live, on a new floor of a season: M.O.D. explains the Aufholjagd when a member stands below the band (09 §0.5).
func _level_floor_notes() -> void:
	if state == null or state.season == null:
		return
	for m: PartyMember in state.party:
		if m != null and LevelBand.catch_up_pm(state, DB.data, m) > LevelBand.PM:
			Show.say("season_catch_up")
			return


## "Graf Mopsula" / the candidate's name (the toasts' wording, like the party page).
func _level_who(m: PartyMember) -> String:
	var def: PartyMemberDef = DB.party_member(m.id) if DB.has_id("party", m.id) else null
	var n: String = m.display_name if m.display_name != "" else (def.name if def != null else m.id)
	return def.title + " " + n if def != null and def.title != "" and m.id != "kai" else n


# --- Staffeln (09 §5, §2.9, ST1-G): the sleeper — logout, login, wake summary, notices -------------------------------
# Logout (09 §5.1): the pause menu's "Ausloggen" and the safe room's open the logout dialog (scenes/ui/logout_dialog:
# what happens where the figure lies, the sleeping tactic, a Sendepause, the opt-in of the notices) → season_logout:
# "sleep" {tactic, cell} — the cell of the room the exploration last told (season_note_cell) — and a Sendepause
# ("season" pause "user", its days belong to the night) → the save → the plan of the notices → the title.
# Login (09 §5.5, V-17): season_login / _season_absence → _season_wake_up: an asleep figure wakes with "away" {sec};
# an awake one gone over 10 min (the app closed or crashed, the pause or the background; calendar) sleeps first where
# it stood (careful, "automatisch ausgeloggt"); a jump over seven days plus the rest of a running Sendepause waits for
# the question of the wake summary (season_login_answer: confirmed → a pause "clamp" for the rest and "away" for the
# seven days; denied → "away" for one second: nothing counts). The night's SEASON events stay quiet while it is booked
# (_season_quiet: no M.O.D. line, no toast, no route) — SleepResolver.report turns them into season_wake, the wake
# summary (scenes/ui/wake_summary) shows it and "Weiter" (season_wake_done) leads into the world.
# Notices (09 §2.9, §5.6; opt-in, settings.notify_collapse): Godot 4.7 has no system notifications on desktop and
# none without a plugin on Android / iOS (09 Kap. 11.3 ST1-G, G-12) — while the app stays open after a logout, a due
# warning goes into the window title (and asks for attention); the login summary repeats the next collapse.

const SCENE_WAKE_SUMMARY: String = "res://scenes/ui/wake_summary.tscn"
const SCENE_LOGOUT_DIALOG: String = "res://scenes/ui/logout_dialog.tscn"
const SEASON_NOTICE_POLL_SEC: float = 1.0

## The wake summary pending: SleepResolver.report (+ "auto"), or {"question": seconds, "auto"} for a clock jump over
## seven days (V-17); {} without one.
var season_wake: Dictionary = {}
## The notices planned at the logout: [{"wall" (unix seconds of the local clock), "kind", "text"}], oldest first.
var season_notices: Array[Dictionary] = []
## The notice shown last ("" none): the window title says it until the next login.
var season_notice_text: String = ""

var _season_last_events: Array[ExploreEvent] = []   # the events of the last season command (_season_command)
var _season_waking: bool = false            # a night is being booked: its SEASON events stay quiet
var _season_wake_n: int = 0                 # logins and absences so far (a deferred route belongs to one of them)
var _season_cell: Vector2i = SleepResolver.NO_CELL  # the room the figure stands in (the exploration tells it)
var _season_notice_poll: float = 0.0


## The exploration tells the room the figure stands in (presentation only, never recorded): the cell of a logout.
func season_note_cell(cell: Vector2i) -> void:
	_season_cell = cell


## The cell a logout puts the figure to sleep at: the room the exploration told last, else the last room entered.
func season_cell() -> Vector2i:
	if _season_cell != SleepResolver.NO_CELL:
		return _season_cell
	var fr: FloorRun = state.floor_run if state != null else null
	return fr.visited.back() if fr != null and not fr.visited.is_empty() else SleepResolver.NO_CELL


## A logout is possible now (09 §5.1 Nr. 1): a season that is not over, awake, outside a combat.
func season_can_logout() -> bool:
	return state != null and state.season != null and not state.season.asleep and state.season.result == "" \
		and state.floor_run != null and combat == null and not in_battle


## The logout (09 §5.1): "sleep" {tactic, cell} (the cell only outside a safe room), then a Sendepause of `pause_sec`
## when asked (private calendar seasons, the budget of 14 days — a refused one changes nothing), the wall clock seen,
## the plan of the notices, the save. false = refused (in a combat, asleep, the season over).
func season_logout(tactic: String, cell: Vector2i = SleepResolver.NO_CELL, pause_sec: int = 0) -> bool:
	if not season_can_logout():
		return false
	var cmd: Dictionary = {"t": "sleep", "tactic": tactic if RtVocab.RT_PRESETS.has(tactic) else "careful"}
	if state.floor_run.location == RunRules.LOCATION_START and cell != SleepResolver.NO_CELL \
			and SleepResolver.layout_of(state, DB.data) != null \
			and SleepResolver.layout_of(state, DB.data).cell_at(cell) != null:
		cmd["cell"] = [cell.x, cell.y]
	if not _season_command(cmd):
		return false
	if pause_sec > 0:
		season_op({"t": "season", "v": Command.SEASON_VERSION, "op": "pause", "sec": pause_sec, "why": "user"})
	state.season.seen_unix = maxi(state.season.seen_unix, int(Time.get_unix_time_from_system()))
	_season_notices_plan()
	_season_autosave()
	return true


## The replay of a recorded "sleep" (GameReplay): the command as it was recorded (its cell included).
func season_sleep_cmd(c: Dictionary) -> bool:
	if not _season_command(c.duplicate(true)):
		return false
	_season_autosave()
	return true


## The whole days of Sendepause a logout may still take (09 §2.9: private calendar seasons, 14 days per season;
## SeasonRules decides — Am Stück, a public template or a season over: none).
func season_pause_days_left() -> int:
	var s: SeasonState = state.season if state != null else null
	if s == null:
		return 0
	var days: int = maxi(0, (SeasonClock.PAUSE_MAX_SEC - s.pause_sec) / SeasonClock.DAY_SEC)
	var c: Dictionary = {"t": "season", "v": Command.SEASON_VERSION, "op": "pause", "sec": SeasonClock.DAY_SEC,
		"why": "user"}
	return days if days > 0 and SeasonRules.refusal(state, DB.data, c) == "" else 0


## What the logout dialog says for the figure now (SleepResolver.logout_info at season_cell()).
func season_logout_info() -> Dictionary:
	if state == null or state.season == null:
		return {}
	return SleepResolver.logout_info(state, DB.data, season_cell(), _season_tz_offset())


## The answer of the clock-jump question (V-17): confirmed → seven days (plus the rest of the night's Sendepause)
## count and the rest becomes a pause "clamp"; denied → nothing counts (one second). Books the night.
func season_login_answer(confirmed: bool) -> void:
	if state == null or state.season == null or not season_wake.has("question"):
		return
	var sec: int = int(season_wake["question"])
	var auto: bool = bool(season_wake.get("auto", false))
	season_wake = {}
	var events: Array[ExploreEvent] = []
	var away: int = 1
	if confirmed:
		away = SleepResolver.max_away(state)
		if season_op({"t": "season", "v": Command.SEASON_VERSION, "op": "pause", "sec": sec - away, "why": "clamp"}):
			events.append_array(_season_last_events)
	_season_book_night(away, auto, events)
	state.season.seen_unix = maxi(state.season.seen_unix, int(Time.get_unix_time_from_system()))
	_cast_news_reset(CastSim.last_seq(state))


## "Weiter" of the wake summary: the world — the exploration at the figure's place (a floor without playable content:
## the Abspann), the Sendeschluss screen when the season is over for the candidate (out), the Abspann at its end.
func season_wake_done() -> void:
	season_wake = {}
	if state == null or state.season == null:
		Router.goto(Router.SCENE_TITLE)
		return
	var s: SeasonState = state.season
	match s.result:
		"":
			_season_goto(Router.SCENE_EXPLORATION, String(state.floor_run.location) if state.floor_run != null
				else "start")
		"fallen", "buried":
			_season_goto(Router.SCENE_GAME_OVER, "timer" if s.result == "buried" else "defeat")
		_:
			_season_goto(Router.SCENE_CREDITS, "")


## The deferred route to the wake summary after absence number `n` in the live views — only while that one is pending.
func _season_wake_route(n: int) -> void:
	if n == _season_wake_n and state != null and not replaying and not season_wake.is_empty():
		_season_goto(SCENE_WAKE_SUMMARY, "")


## True while a SEASON event's presentation stays quiet: a replay, or a night being booked (the wake summary tells it).
func _season_quiet() -> bool:
	return replaying or _season_waking


## The login after `sec` season seconds without the figure (09 §5.5): wakes the sleeper, makes the awake one gone over
## 10 min a sleeper first (an automatic logout), asks about a jump over seven days, or moves the clock for a short gap.
func _season_wake_up(sec: int) -> void:
	var s: SeasonState = state.season
	if s.result != "" or state.floor_run == null:
		return
	var auto: bool = false
	if not s.asleep:
		if s.tempo != "calendar" or sec <= SEASON_AWAY_SEC:
			if sec > 0:
				season_clock(mini(sec, SeasonClock.MAX_JUMP_SEC))
			return
		var tactic: String = s.sleep_tactic if RtVocab.RT_PRESETS.has(s.sleep_tactic) else "careful"
		var cmd: Dictionary = {"t": "sleep", "tactic": tactic}
		var cell: Vector2i = season_cell()
		if state.floor_run.location == RunRules.LOCATION_START and cell != SleepResolver.NO_CELL:
			cmd["cell"] = [cell.x, cell.y]
		if not _season_command(cmd) and not _season_command({"t": "sleep", "tactic": tactic}):
			return
		auto = true
	if s.tempo == "calendar" and sec > SleepResolver.max_away(state):
		season_wake = {"question": sec, "auto": auto}
		return
	var none: Array[ExploreEvent] = []
	_season_book_night(maxi(1, sec), auto, none)


## "away" {sec} with the night's events kept quiet, then the wake summary (season_wake) and the save.
func _season_book_night(sec: int, auto: bool, before: Array[ExploreEvent]) -> void:
	_season_waking = true
	var ok: bool = season_away(sec)
	_season_waking = false
	if not ok:
		return
	var events: Array[ExploreEvent] = before.duplicate()
	events.append_array(_season_last_events)
	season_wake = SleepResolver.report(state, DB.data, events, _season_tz_offset(), auto)
	season_wake["auto"] = auto
	season_wake["daily"] = settings.daily_summary
	season_notices.clear()
	if season_notice_text != "":
		season_notice_text = ""
		_season_window_title("")
	_season_autosave()


## The plan of the notices after a logout (09 §2.9; opt-in): SleepResolver.notice_plan in local wall time (the season
## clock runs with the wall clock — × Zeitraffer in debug builds).
func _season_notices_plan() -> void:
	season_notices.clear()
	var s: SeasonState = state.season if state != null else null
	if s == null or not settings.notify_collapse:
		return
	var wall: int = int(Time.get_unix_time_from_system())
	var speed: int = clampi(season_speed, 1, SEASON_SPEED_MAX)
	for n: Dictionary in SleepResolver.notice_plan(state, DB.data, s.utc, {"collapse": true}, _season_tz_offset()):
		season_notices.append({"wall": wall + (int(n["at"]) - s.utc) / speed, "kind": n["kind"], "text": n["text"]})


## Desktop (no system notifications in Godot 4.7, G-12): a due notice goes into the window title and asks for
## attention; on a phone the plan waits for a notification plugin (open question of 09 ST1-G).
func _season_notices_process() -> void:
	if season_notices.is_empty():
		return
	_season_notice_poll -= get_process_delta_time()
	if _season_notice_poll > 0.0:
		return
	_season_notice_poll = SEASON_NOTICE_POLL_SEC
	var wall: int = int(Time.get_unix_time_from_system())
	while not season_notices.is_empty() and int(season_notices[0]["wall"]) <= wall:
		season_notice_text = str(season_notices.pop_front()["text"])
		_season_window_title(season_notice_text)


func _season_window_title(text: String) -> void:
	if DisplayServer.get_name() == "headless" or OS.has_feature("mobile"):
		return
	var base: String = str(ProjectSettings.get_setting("application/config/name", "PRIME TIME DUNGEON"))
	DisplayServer.window_set_title(base + (" — " + text if text != "" else ""))
	if text != "":
		DisplayServer.window_request_attention()


# ======================================================================================================================
# Sprachen (11 §1.9, 11-L1) — the language of the run. _init applies it after the settings are read, so the catalog
# stands before the first screen exists (DB loaded the data before: the autoload order Events, DB, Game). _ready turns
# the automatic translation of the root off (SP-3; project setting internationalization/rendering/
# root_node_auto_translate too): texts are translated once, through Tx — an English text that happens to equal a German
# msgid ("Gift") must not be translated a second time. The language never reaches the state (11 §1.10, SP-4).
# ======================================================================================================================

## Applies the language of the run (LocaleLoader.resolve → apply) and returns it: --lang=<code> (transient), ephemeral
## runs German, else settings.language ("auto" = the system language if it is one of ours, else English). An active
## content pack (11-P1, DB.pack) adds its PO and may narrow the languages. `from_menu`: the options row on the title
## changed the setting — the choice wins over --lang and the ephemeral default. Reading PO files is logged with its time
## (German reads none and stays silent).
func apply_language(from_menu: bool = false) -> String:
	var t0: int = Time.get_ticks_usec()
	var pack: Object = DB.get("pack") as Object       # 11-P1's PackDef (null without a pack); read by name
	var args: PackedStringArray = PackedStringArray() if from_menu else OS.get_cmdline_user_args()
	var setting: String = settings.language if settings != null else LocaleLoader.AUTO
	var lang: String = LocaleLoader.resolve(setting, args, ephemeral and not from_menu, OS.get_locale_language(),
		LocaleLoader.pack_languages(pack), LocaleLoader.pack_default_lang(pack))
	var res: Dictionary = LocaleLoader.apply(lang, LocaleLoader.pack_dir(pack))
	var files: PackedStringArray = res.get("files", PackedStringArray())
	if not files.is_empty():
		print("[LocaleLoader] %s: %d PO files, %d messages (%.1f ms)" % [str(res.get("lang", lang)), files.size(),
			int(res.get("count", 0)), (Time.get_ticks_usec() - t0) / 1000.0])
	return str(res.get("lang", lang))
