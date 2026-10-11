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
var auto_battle: bool = false        # party uses AutoPolicy (toggle_auto / Settings / Autoplay)
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
var in_battle: bool = false          # make_battle_setup → apply_battle_result; Show routes external gifts by it (§3.5)
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
	auto_battle = settings.auto_battle_default
	apply_settings()
	if not ephemeral:                    # 06-D: M.O.D. live link (off by default, never blocks gameplay)
		mod_live = ModLiveLinkScript.new()
		mod_live.name = "ModLiveLink"
		add_child(mod_live)


func _process(delta: float) -> void:
	if state == null:
		return
	state.play_time_sec += delta
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
	sim = _make_sim(state, {})
	persona = p_persona
	start_floor(1)
	_choose_initial_hero(hero_id)
	_choose_initial_persona(p_persona)        # Casting (08 §2.3): floor → hero → persona
	Events.new_game_started.emit(slot)


## M8: EventCatalog → EventDef.run_seed(); mode = &"event_offline"; slot 0 (never saved into campaign slots).
## p_league: the league the player plays in a multi-league event (05 §10.1); "" → the single league / "pur".
## `hero_id` (06 §1.7): the controlled character, recorded right after "floor" like in new_game.
func start_event_run(event_id: String, p_league: String = "", hero_id: String = HeroRules.DEFAULT_HERO) -> void:
	var def: EventDef = _load_event_def(event_id)
	if def == null:
		push_warning("[Game] unknown event '%s'" % event_id)
		return
	_reset_run()
	mode = &"event_offline"
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
	sim = _make_sim(state, def.rules)
	start_floor(maxi(1, def.floor_index))
	_choose_initial_hero(hero_id)
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


## Standalone scenes, capture, tests: ephemeral-safe new game in slot 0 with seed 1.
func ensure_state() -> void:
	if not has_state():
		new_game(0, "Kai", 1)


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


## timer_running and state.floor_run.timer_started and no blocking dialog.
func is_timer_ticking() -> bool:
	return timer_running and state != null and state.floor_run != null and state.floor_run.timer_started \
		and _blocking_dialogs == 0


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
	timer_running = false
	record({"t": "descend"})
	_floor_done = true
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
	var idx: int = state.floor_run.index
	var next: FloorDef = DB.floor_def(idx + 1)
	if next != null:
		start_floor(idx + 1)
		Save.autosave()
	if next == null or not next.playable:
		Router.goto(Router.SCENE_CREDITS)
	else:
		Router.goto(Router.SCENE_EXPLORATION, {"spawn": &"start"})


## Router.game_over calls this first: stat game_overs +1; Save.record_game_over(state.slot) (not while replaying).
func on_game_over(reason: StringName) -> void:
	timer_running = false
	in_battle = false
	if state == null:
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


## Records the encounter, builds the setup (next_seed("battle")) and sets in_battle (until apply_battle_result).
## `opener` (06 integration A × C): "bark" when Graf Mopsula's bark dazed the group that a PREEMPTIVE battle starts
## from — recorded only then ({"opener": "bark"}), so sneak-themed bets / stats can tell it from sneaking up.
func make_battle_setup(encounter_id: String, advantage: int, group_id: String, opener: String = "") -> BattleSetup:
	var o: String = opener if advantage == BattleSetup.Advantage.PREEMPTIVE and BattleSetup.OPENERS.has(opener) else ""
	var cmd: Dictionary = {"t": "encounter", "enc": encounter_id, "adv": advantage, "group": group_id}
	if o != "":
		cmd["opener"] = o
	record(cmd)
	if state == null:
		push_warning("[Game] make_battle_setup without state")
		return null
	var setup: BattleSetup = BattleBridge.make_setup(state, DB.data, encounter_id, advantage, group_id,
		next_seed("battle"), event_rules())
	if setup != null:
		setup.opener = o
		setup.auto_battle = auto_battle
		_persona_battle_look(setup)            # Casting (08 §6.3, K2): kai's look — presentation only
		in_battle = true
	return setup


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
	if sim != null:
		sim.request_checkpoint()   # 05 §3.3 Nr. 8: a checkpoint after every battle (written when the clock moves on)
	_sync_twist_ends()             # 06-D: "battles" twists counted down in BattleBridge.apply_result
	Events.party_changed.emit()
	Events.inventory_changed.emit()
	Events.credits_changed.emit(_credits(), _credits() - credits_before)
	for info: LevelUpInfo in rewards.level_ups:
		if info == null:
			continue
		Events.member_leveled.emit(info.member_id, info.new_level, info.learned)
		for lv in range(info.old_level + 1, info.new_level + 1):
			Events.level_up.emit({"member": info.member_id, "level": lv})
			if Talents.is_talent_level(lv):                # 06 package B: a choice waits in the Talent-Show
				Events.talent_pending.emit(info.member_id, lv)
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
	if state == null:
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
	if state == null:
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


## Casting (06 §3.4; UI with floor 3): only an allowed choice (Casting.check) is recorded
## ({"t": "casting", "member", "species", "class"}) and applied; emits party_changed.
func choose_casting(member_id: String, species_id: String, class_id: String) -> bool:
	if state == null or Casting.check(state, DB.data, member_id, species_id, class_id) != "":
		return false
	record({"t": "casting", "member": member_id, "species": species_id, "class": class_id})
	Casting.choose(state, DB.data, member_id, species_id, class_id)
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
	# file (user://replays/<run_id>.json) so a later uploader/verifier can check it. Local boards and replays are plain,
	# editable JSON — never uploaded, never trusted (05 §10.4). Casting (08 §2.7 Nr. 4): the entry carries no name —
	# display_name "" (EventInfo.entry_name shows the local player as "Sie").
	var entry: Dictionary = {
		"schema": 1, "event_id": event_id, "window_id": str(header.get("window_id", "")),
		"league": str(header.get("league", "pur")), "mode": "solo", "run_id": str(header.get("run_id", "")),
		"players": [{"player_id": "local", "display_name": "", "role": "kai"}],
		"score": summary["score"], "breakdown": summary["breakdown"], "quest_complete": summary["quest_complete"],
		"floor_timer_left_sec": int(time_left()), "run_wall_ms": 0, "flags": [],
		"difficulty": String(state.difficulty), "replay_id": str(header.get("run_id", "")),
		"run_log_hash": run_log.digest() if run_log != null else "", "data_hash": DB.data_hash(),
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
## construction. Battles follow §5.7 (BattleState + Show.begin_battle/on_battle_event/take_pending_gift/end_battle). The
## live context (state, log, sim, quest, …) is restored afterwards. Not during a battle (Show's battle state would be
## overwritten). Checkpoint k = state after all commands with k' <= k; the walk is RunLog.walk (shared with
## RunSim.replay). Same "errors" contract as RunSim.replay — a verifier needs errors == []: log schema / id problems
## (RunLog.validate), entries the RunLog rejected, a log from a save without a valid anchor and an unknown event (abort:
## no replay without its start state / rules), header ≠ event (RunSim.header_errors: fixed seed, difficulty, league),
## commands the rules refuse (RunRules.command_refusal, QA windows not allowed, battle commands without a battle) — they
## are skipped — and every gift Show refuses (gift_rejected: duplicates, caps, wrong target, run over …). Returns
## {"final_hash": String, "result": Dictionary, "mismatch_at": int (first failing checkpoint index, -1 = none),
## "errors": PackedStringArray, "version": String (RunSim.version_status: a log of another sim_version is not replayed
## — one error, mismatch_at -1, shown as "ältere Version", 08 §10.2 Nr. 7)}. until_tick >= 0: the clock steps on to
## that tick after the last command (the live sim.tick() — idle ticks in a safe room move the clock without a command).
func replay_log(p_log: RunLog, until_tick: int = -1) -> Dictionary:
	return GameReplay.new(self).run(p_log, until_tick)


# ======================================================================================================================
# Private helpers
# ======================================================================================================================

func _reset_run() -> void:
	timer_running = false
	safe_room_clock = false
	in_battle = false
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
# STUB(R1a) — owned by R2 (live) and R5a (replay branch). Replace completely, keep the public API.
# The live CombatDirector (R2) and GameReplay (R5a) use exactly these functions, per combat tick c:
# combat_boundary() → combat_submit(cmd) for every input with ct == c → combat_step(). Until R2 nothing starts a
# real-time combat (GameSettings.combat_mode stays &"ctb"), so `combat` stays null and nothing is recorded.

var combat: RtSim = null             # the running real-time combat; null outside one (a save never contains it)


## Records the encounter (with its "rt" block), draws the seeds "battle" and "show", builds the setup with
## BattleBridge.make_rt_setup, creates `combat`, sets in_battle, Show.begin_battle(setup), feeds combat.start() to
## Show.on_battle_event / Events.combat_event, emits Events.combat_started(combat) and Events.battle_started.
## Stub: nothing recorded, returns null.
func make_rt_setup(_cmd: Dictionary) -> RtSetup:
	return null


## One tick boundary before combat tick c = combat.tick() (07 §9.2): at most one gift (external first, then system)
## via Show.take_pending_gift_rt → combat.apply_gift → Show.on_battle_event / Events.combat_event /
## Show.note_battle_gift. Stub: nothing.
func combat_boundary() -> void:
	pass


## RtSim.submit + record (accepted commands only, 07 §10.2); "" or one of RtCommand.REASONS. Stub: "finished" (there
## is no running combat before R2).
func combat_submit(_cmd: Dictionary) -> String:
	return "finished"


## A hint card was shown at the current combat tick: records {"t": "combat_hint", "ct", "id"} and sets
## state.flags["rt_hints"][id] (the sim ignores it, 07 §2.13). Stub: nothing.
func combat_hint(_id: String) -> void:
	pass


## One combat tick: combat.step(), every event to Show.on_battle_event and Events.combat_event, combat checkpoints
## (RunLog.add_checkpoint(k, StateHash.of_rt(combat), ct)). Stub: [].
func combat_step() -> Array[ActionEvent]:
	var out: Array[ActionEvent] = []
	return out


## apply_battle_result(combat.result), Show.end_battle, Events.combat_finished(result), Events.battle_ended, then
## combat = null. Stub: empty rewards.
func end_combat() -> BattleRewards:
	return BattleRewards.new()


# ======================================================================================================================
# Casting (08, K0 → K1 persona command / K2 look) — the API of 08 §10.2 Nr. 8
# ======================================================================================================================
# STUB(K0) — owned by 08-K1 (_choose_initial_persona) and 08-K2 (_persona_battle_look). Replace completely, keep the
# public API. K0 records no persona command: Title / FullRun pass no profile yet, so nothing changes.

## The candidate persona of the running slot (08 §2.2): local presentation data (name, form, job, look, …), never
## part of GameState, the run log or a hash; the core only sees the ids of the "persona" command. null = canon / none.
var persona: PersonaProfile = null


## The one recording entry of the "persona" command (08 §2.3) — the start (_choose_initial_persona, K1) and the swap in
## the first Talent-Show (K1): Command.validate (schema) + PersonaRules.check (event runs → event_run) → record →
## PersonaRules.apply; emits party_changed. false = refused, nothing recorded. GameReplay replays "persona" through it
## (same check, same apply as RunSim.apply).
func apply_persona(cmd: Dictionary) -> bool:
	if state == null or str(cmd.get("t", "")) != "persona" or Command.validate(cmd) != "":
		return false
	if PersonaRules.check(state, DB.data, cmd, sim != null and sim.is_event_run()) != "":
		return false
	record(cmd)
	PersonaRules.apply(state, DB.data, cmd)
	Events.party_changed.emit()
	return true


## K1: with a profile, records the start command PersonaRules.command_for(DB.data, p.talent, p.traits) through
## apply_persona right after the hero (floor → hero → persona); never in event runs. Stub: nothing.
func _choose_initial_persona(_p: PersonaProfile) -> void:
	pass


## K2 (08 §6.3): the kai combatant's presentation model from the persona look, `model = DB.party_model("kai")` right
## after BattleBridge.make_setup (Combatant.model is not in to_dict, the hash or the log). Stub: nothing.
func _persona_battle_look(_setup: BattleSetup) -> void:
	pass
