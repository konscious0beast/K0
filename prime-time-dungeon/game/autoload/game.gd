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
const TICKS_PER_SEC: int = 30        # simulation clock (05 CR-3): 1 tick = 1/30 s explore time
const EVENTS_PATH: String = "res://data/events.json"
const KEY_MASTER: String = "itm_key_master"        # opens locked chests (§7.3)
## External inputs carry cmd id 0; every other command gets a strictly increasing id from 1 (05 §10.6).
const EXTERNAL_CMDS: PackedStringArray = ["gift", "twist"]
## Deterministic quest metrics (05 CR-13), read from ShowState.stats (Show updates them before the signal).
const METRIC_VIEWERS: String = "viewers_target_peak"
const METRIC_FOLLOWERS: String = "followers_gained_run"
const METRIC_HYPE_100: String = "hype_100_count"

var state: GameState = null          # null until new_game()/Save.load_slot()
var settings: GameSettings           # created in _init(); loaded from user://settings.cfg unless ephemeral
var input_scheme: InputScheme = InputScheme.KEYBOARD_MOUSE
var timer_running: bool = false      # "explore view active": true only via ExplorationScene; Router resets to false on goto/push
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
var _quest_done: bool = false
var _layout: FloorLayout = null      # cached layout of the current floor (floor events, chests, rooms)
var _layout_key: String = ""
var _cmd_id: int = 0                 # last command id given out for _cmd_log
var _cmd_log: RunLog = null          # the log _cmd_id belongs to (Save.load_slot replaces run_log → ids restart at 1)
var _metric_fed: Dictionary = {}     # quest metric → last value fed to the tracker


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
func new_game(slot: int, player_name: String = "Kai", seed: int = -1, difficulty: StringName = &"prime",
		hero_id: String = HeroRules.DEFAULT_HERO) -> void:
	var run_seed: int = seed
	if run_seed == -1:
		run_seed = int(Time.get_unix_time_from_system() * 1000.0) & 0x7FFFFFFF
	_reset_run()
	mode = &"campaign"
	state = GameState.create_new(DB.data, slot, player_name, run_seed, difficulty)
	if state == null:
		push_warning("[Game] GameState.create_new returned null (no game state)")
		return
	run_log = _make_run_log(run_seed, slot, player_name, difficulty, "")
	sim = _make_sim(state, {})
	start_floor(1)
	_choose_initial_hero(hero_id)
	Events.new_game_started.emit(slot)


## M8: EventCatalog → EventDef.run_seed(); mode = &"event_offline"; slot 0 (never saved into campaign slots).
## `hero_id` (06 §1.7): the controlled character, recorded right after "floor" like in new_game.
func start_event_run(event_id: String, hero_id: String = HeroRules.DEFAULT_HERO) -> void:
	var def: EventDef = _load_event_def(event_id)
	if def == null:
		push_warning("[Game] unknown event '%s'" % event_id)
		return
	_reset_run()
	mode = &"event_offline"
	_event_def = def
	var run_seed: int = def.run_seed()
	state = GameState.create_new(DB.data, 0, "Kai", run_seed, &"prime")
	if state == null:
		push_warning("[Game] GameState.create_new returned null (no game state)")
		mode = &"campaign"
		return
	quest = QuestTracker.from_def(def.quest)
	run_log = _make_run_log(run_seed, 0, "Kai", &"prime", event_id)
	sim = _make_sim(state, def.rules)
	start_floor(maxi(1, def.floor_index))
	_choose_initial_hero(hero_id)
	var leagues: Array = def.rules.get("leagues", ["pur"])
	Events.run_started.emit(event_id, str(leagues[0]) if not leagues.is_empty() else "pur")


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
	var def: FloorDef = DB.floor_def(floor_index)
	if def == null:
		push_warning("[Game] start_floor: no floor %d" % floor_index)
		return
	state.floor_run = FloorRun.create(def, state.seed, state.difficulty)
	_acc = 0.0
	_layout = null
	_layout_key = ""
	clear_blocking_dialogs()
	Show.start_floor(floor_index)
	record({"t": "floor", "floor": floor_index})
	if sim != null:
		_dispatch(sim.sponsor_floor())


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
	state.rng_counter += 1
	return SeedUtil.derive(state.seed, purpose, state.rng_counter)


## Records the encounter, builds the setup (next_seed("battle")) and sets in_battle (until apply_battle_result).
func make_battle_setup(encounter_id: String, advantage: int, group_id: String) -> BattleSetup:
	record({"t": "encounter", "enc": encounter_id, "adv": advantage, "group": group_id})
	if state == null:
		push_warning("[Game] make_battle_setup without state")
		return null
	var setup: BattleSetup = BattleBridge.make_setup(state, DB.data, encounter_id, advantage, group_id, next_seed("battle"))
	if setup != null:
		setup.auto_battle = auto_battle
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
		sim.request_checkpoint()   # 05 §3.3 Nr. 8: a checkpoint after every battle (written when the clock moves on)
	Events.party_changed.emit()
	Events.inventory_changed.emit()
	Events.credits_changed.emit(_credits(), _credits() - credits_before)
	for info: LevelUpInfo in rewards.level_ups:
		if info == null:
			continue
		Events.member_leveled.emit(info.member_id, info.new_level, info.learned)
		for lv in range(info.old_level + 1, info.new_level + 1):
			Events.level_up.emit({"member": info.member_id, "level": lv})
	if not timer_was_started and state.floor_run != null and state.floor_run.timer_started:
		Events.floor_timer_started.emit()
	return rewards


func open_lootbox(box_id: String) -> Array[LootReward]:
	var rewards: Array[LootReward] = []
	if state == null:
		return rewards
	var idx: int = state.pending_lootboxes.find(box_id)
	if idx < 0 or not DB.has_id("lootboxes", box_id):
		push_warning("[Game] lootbox '%s' is not pending" % box_id)
		return rewards
	record({"t": "lootbox", "box": box_id})
	state.pending_lootboxes.remove_at(idx)
	var rng: RandomNumberGenerator = SeedUtil.make_rng(next_seed("lootbox"))
	var floor_index: int = state.floor_run.index if state.floor_run != null else 1
	rewards = LootRoller.roll_lootbox(DB.lootbox(box_id), DB.data, floor_index, state, rng)
	add_rewards(rewards)
	Events.lootbox_opened.emit(box_id, rewards)
	return rewards


## Items → inventory (overflow over max_stack → credits at sell value), credits.
func add_rewards(rewards: Array[LootReward]) -> void:
	if state == null or state.inventory == null:
		return
	var credits_before: int = _credits()
	_add_rewards_to(state, rewards)
	Events.inventory_changed.emit()
	Events.credits_changed.emit(_credits(), _credits() - credits_before)


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
	var k: int = -1
	var ev: EventSpawn = null
	for i in layout.events.size():
		if layout.events[i] != null and layout.events[i].id == event_id:
			k = i
			ev = layout.events[i]
			break
	if ev == null:
		push_warning("[Game] apply_floor_event: unknown event '%s'" % event_id)
		return {}
	var credits_before: int = _credits()
	var uses: int = int(state.floor_run.event_uses.get(event_id, 0))
	var rng: RandomNumberGenerator = SeedUtil.make_rng(SeedUtil.derive(state.floor_run.seed, "event", k * 16 + uses))
	var outcome: Dictionary = FloorEvent.resolve(ev, choice, state, DB.data, rng)
	FloorEvent.apply(outcome, ev, choice, state, DB.data)
	var hype: float = float(outcome.get("hype", 0.0))
	if hype != 0.0:
		Show.add_hype(hype, &"event")
	var followers: int = int(outcome.get("followers", 0))
	if followers != 0:
		Show.add_followers(followers, &"event")
	for box: Variant in outcome.get("boxes", PackedStringArray()):
		state.pending_lootboxes.append(str(box))
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
		return false
	record({"t": "room", "cell": JsonUtil.vec2i_to_arr(cell)})
	fr.visited.append(cell)
	var layout: FloorLayout = _current_layout()
	if layout != null:
		var rc: RoomCell = layout.cell_at(cell)
		if rc != null and rc.kind == RoomCell.Kind.STAIRS:
			fr.stairs_found = true
	_quest_feed(RunSim.zones_event(fr, layout))   # reach_stairs progress before the stairs (05 §1.3, same as RunSim)
	if sim != null:
		_dispatch(sim.sponsor_room(cell))         # boss room → Boss-Countdown (05 §6.13)
	return true


## §7.3 chest flow without visuals: locked without itm_key_master / unknown / already open → [] (nothing changes);
## else record, LootRoller.roll_chest (rng derive(floor_run.loot_seed, "chest", k) — 05 CR-11: the layout seed is
## public, the loot seed is not), add_rewards, opened_chests, Events.chest_opened(id, rewards).
func open_chest(chest_id: String) -> Array[LootReward]:
	var rewards: Array[LootReward] = []
	if state == null or state.floor_run == null:
		return rewards
	var fr: FloorRun = state.floor_run
	if fr.opened_chests.has(chest_id):
		return rewards
	var layout: FloorLayout = _current_layout()
	var chest: ChestSpawn = null
	if layout != null:
		for ch: ChestSpawn in layout.chests:
			if ch != null and ch.id == chest_id:
				chest = ch
				break
	if chest == null:
		push_warning("[Game] open_chest: unknown chest '%s'" % chest_id)
		return rewards
	if chest.type == "locked" and (state.inventory == null or not state.inventory.has(KEY_MASTER)):
		return rewards
	record({"t": "chest", "id": chest_id})
	var k: int = chest_id.get_slice("_c", 1).to_int()
	var rng: RandomNumberGenerator = SeedUtil.make_rng(SeedUtil.derive(fr.loot_seed, "chest", k))
	var spec: Dictionary = {"id": chest.id, "type": chest.type, "contents": chest.contents}
	rewards = LootRoller.roll_chest(spec, DB.data, fr.index, state, rng)
	add_rewards(rewards)
	fr.opened_chests.append(chest_id)
	Events.chest_opened.emit(chest_id, rewards)
	return rewards


## Gate requirement checked by M3: opened_gates.append(key) (once), record({"t": "gate", "key"}).
func open_gate(key: String) -> void:
	if state == null or state.floor_run == null or state.floor_run.opened_gates.has(key):
		return
	record({"t": "gate", "key": key})
	state.floor_run.opened_gates.append(key)


## record({"t": "safe_room", "id"}); location = id; safe_room_visits += 1; first visit bookkeeping; full heal
## (not recorded separately). Returns the scene condition context.
func enter_safe_room(safe_room_id: String) -> Dictionary:
	if state == null or state.floor_run == null:
		return {"safe_room_id": safe_room_id, "first_visit": false, "safe_room_visits": 0, "kai_level": 1}
	record({"t": "safe_room", "id": safe_room_id})
	var fr: FloorRun = state.floor_run
	fr.location = StringName(safe_room_id)
	fr.safe_room_visits += 1
	var first_visit: bool = not fr.visited_safe_rooms.has(safe_room_id)
	if first_visit:
		fr.visited_safe_rooms.append(safe_room_id)
	_full_heal()
	if sim != null:
		_dispatch(sim.sponsor_safe_room(safe_room_id))
	var kai: PartyMember = state.member("kai")
	return {"safe_room_id": safe_room_id, "first_visit": first_visit, "safe_room_visits": fr.safe_room_visits,
		"kai_level": kai.level if kai != null else 1}


## Back in the exploration (M3 on_resume from a safe room): location = &"start"; record({"t": "safe_room_exit"}).
func leave_safe_room() -> void:
	if state == null or state.floor_run == null:
		return
	record({"t": "safe_room_exit"})
	state.floor_run.location = &"start"
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
	var stats: Dictionary = state.show.stats if state.show != null else {}
	for sc: SceneDef in DB.data.all_scenes():
		if sc.once and bool(get_flag("scene_" + sc.id, false)):
			continue
		if sc.expr != null and sc.expr.eval(ctx, stats, state.flags):
			return sc
	return null


## record({"t": "scene", "id"}); flags scene_<id> = true and the scene's set_flag (e.g. mop_pep_talk).
func mark_scene_seen(scene: SceneDef) -> void:
	if scene == null or state == null:
		return
	record({"t": "scene", "id": scene.id})
	state.flags["scene_" + scene.id] = true
	if scene.set_flag != "":
		state.flags[scene.set_flag] = true


## Only &"prime" → &"vorabend" (never up); remaining timer ticks × 1.5; record({"t": "difficulty", "to"}).
func set_difficulty(d: StringName) -> bool:
	if state == null or state.difficulty != &"prime" or d != &"vorabend":
		return false
	record({"t": "difficulty", "to": String(d)})
	state.difficulty = d
	if state.floor_run != null:
		state.floor_run.time_left_ticks = roundi(state.floor_run.time_left_ticks * Balance.EASY_TIMER_MULT)
	return true


# --- 06 package A: hero choice (HeroRules) ------------------------------------------------------------------------------

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
## cmd_id: 0 for external inputs (EXTERNAL_CMDS), else strictly increasing from 1 per run log (05 §10.6).
func record(cmd: Dictionary) -> void:
	if run_log == null or replaying:
		return
	if _cmd_log != run_log:
		_cmd_log = run_log
		_cmd_id = 0
	var cmd_id: int = 0
	if not EXTERNAL_CMDS.has(str(cmd.get("t", ""))):
		_cmd_id += 1
		cmd_id = _cmd_id
	run_log.add_cmd(sim.tick() if sim != null else 0, cmd, cmd_id)


## Recorded ({"t": "flag", "key", "value"}); value bool/int/String (JSON-safe).
func set_flag(key: String, value: Variant) -> void:
	if state == null:
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
			var is_fs: bool = cur == DisplayServer.WINDOW_MODE_FULLSCREEN or cur == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
			if is_fs != settings.fullscreen:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if settings.fullscreen \
					else DisplayServer.WINDOW_MODE_WINDOWED)
	Events.settings_changed.emit()


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
	var entry: Dictionary = {
		"schema": 1, "event_id": event_id, "window_id": "", "league": "pur", "mode": "solo",
		"run_id": str(run_log.header.get("run_id", "")) if run_log != null else "",
		"players": [{"player_id": "local", "display_name": state.player_name, "role": "kai"}],
		"score": summary["score"], "breakdown": summary["breakdown"], "quest_complete": summary["quest_complete"],
		"floor_timer_left_sec": int(time_left()), "run_wall_ms": 0, "flags": [], "verified": "local",
		"finished_at": Time.get_datetime_string_from_system(true) + "Z",
	}
	summary["rank"] = board.add(entry)
	Save.save_leaderboard(event_id, board.to_dict())
	if sim != null:
		# final checkpoint + run_log.result {"cause", "final_hash", "ticks", "score"} (05 §10.6)
		summary["final_hash"] = sim.close(String(cause), {"score": summary["score"]})
	if run_log != null:
		Save.save_replay(run_log)
	Events.run_finished.emit(summary)
	return summary


## M8: replays a RunLog against a fresh GameState by driving the SAME Game/Show methods as the live run (record() is a
## no-op meanwhile, no Router/Save calls): RNG consumption (next_seed "battle"/"show"/"lootbox"/"gift"), Show reactions
## (hype, followers, milestones, achievements), safe-room bookkeeping and event rules (header.event_id → EventDef.rules)
## are identical by construction. Battles follow §5.7 (BattleState + Show.begin_battle/on_battle_event/
## take_pending_gift/end_battle). The live context (state, log, sim, quest, …) is restored afterwards.
## Not during a battle (Show's battle state would be overwritten). Checkpoint k = state after all commands with k' <= k.
## Returns {"final_hash": String, "result": Dictionary, "mismatch_at": int (first failing checkpoint index, -1 = none)}.
## until_tick >= 0: the clock steps on to that tick after the last command (the live sim.tick() — idle ticks in a safe
## room move the clock without a command).
func replay_log(p_log: RunLog, until_tick: int = -1) -> Dictionary:
	var out: Dictionary = {"final_hash": "", "result": {}, "mismatch_at": -1}
	if p_log == null:
		return out
	if replaying or in_battle:
		push_warning("[Game] replay_log is not possible during a replay or a battle")
		return out
	var header: Dictionary = p_log.header
	if bool(header.get("from_save", false)):
		push_warning("[Game] replay_log: log starts at a loaded save (not replayable from create_new)")
		return out
	var run_seed: int = int(header.get("seed", header.get("run_seed", 1)))
	var difficulty: StringName = StringName(str(header.get("difficulty", "prime")))
	var event_id: String = str(header.get("event_id", ""))
	var saved: Dictionary = _capture_context()
	replaying = true
	_reset_run()
	var rules: Dictionary = {}
	mode = &"campaign"
	if event_id != "":
		mode = &"event_offline"
		_event_def = _load_event_def(event_id)
		if _event_def != null:
			rules = _event_def.rules
			quest = QuestTracker.from_def(_event_def.quest)
		else:
			push_warning("[Game] replay_log: unknown event '%s' (rules missing)" % event_id)
	state = GameState.create_new(DB.data, int(header.get("slot", 0)), str(header.get("player_name", "Kai")), run_seed,
		difficulty)
	if state != null:
		sim = RunSim.new(DB.data, state, rules)
		_replay_commands(p_log, out)
		if until_tick >= 0:
			_replay_advance(until_tick)
		out["final_hash"] = StateHash.of(state)
		out["result"] = {"ticks": sim.tick(), "cmds": p_log.cmds().size(), "floor": _replay_floor(state),
			"quest_complete": quest.is_complete() if quest != null else false,
			"quest_progress": quest.progress() if quest != null else 0.0}
	_restore_context(saved)
	replaying = false
	if state != null:
		Show.sync_from_state()
		Events.party_changed.emit()
		Events.inventory_changed.emit()
	return out


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
	_quest_done = false
	_layout = null
	_layout_key = ""
	_cmd_id = 0
	_cmd_log = null
	_metric_fed = {}
	quest = null
	run_log = null
	sim = null


func _make_run_log(run_seed: int, slot: int, player_name: String, difficulty: StringName, event_id: String) -> RunLog:
	var rl: RunLog = RunLog.new()
	rl.header = {
		"schema": 1,
		"seed": run_seed,
		"slot": slot,
		"player_name": player_name,
		"mode": String(mode),
		"difficulty": String(difficulty),
		"game_version": str(ProjectSettings.get_setting("application/config/version", "")),
		"sim_hz": TICKS_PER_SEC,
		"event_id": event_id,
		"run_id": "run_local_%d" % run_seed,
	}
	return rl


## The live clock: RunSim over `st` that writes its checkpoints into the current run_log (every 300 ticks, after
## battles / floor ends via request_checkpoint, close() at finish_run; 05 §3.3 Nr. 8). Replays build their own sim
## without a log.
func _make_sim(st: GameState, rules: Dictionary) -> RunSim:
	var s: RunSim = RunSim.new(DB.data, st, rules)
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


func _add_rewards_to(st: GameState, rewards: Array[LootReward]) -> void:
	if st == null or st.inventory == null:
		return
	for r: LootReward in rewards:
		if r == null:
			continue
		if r.kind == "credits":
			st.inventory.add_credits(r.amount)
		elif r.kind == "item" and DB.has_id("items", r.id):
			var def: ItemDef = DB.item(r.id)
			var added: int = st.inventory.add(r.id, r.amount, def.max_stack)
			var overflow: int = r.amount - added
			if overflow > 0:
				st.inventory.add_credits(overflow * Shop.sell_value(DB.data, r.id))


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


# --- replay helpers ----------------------------------------------------------------------------------------------------

func _capture_context() -> Dictionary:
	return {"state": state, "run_log": run_log, "sim": sim, "quest": quest, "mode": mode, "event_def": _event_def,
		"run_finished": _run_finished, "quest_done": _quest_done, "layout": _layout, "layout_key": _layout_key,
		"acc": _acc, "blocking": _blocking_dialogs, "timer_running": timer_running, "in_battle": in_battle,
		"safe_room_clock": safe_room_clock,
		"cmd_id": _cmd_id, "cmd_log": _cmd_log, "metric_fed": _metric_fed}


func _restore_context(saved: Dictionary) -> void:
	state = saved["state"] as GameState
	run_log = saved["run_log"] as RunLog
	sim = saved["sim"] as RunSim
	quest = saved["quest"] as QuestTracker
	mode = saved["mode"]
	_event_def = saved["event_def"] as EventDef
	_run_finished = bool(saved["run_finished"])
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


func _replay_floor(st: GameState) -> int:
	return st.floor_run.index if st != null and st.floor_run != null else 1


func _replay_commands(p_log: RunLog, out: Dictionary) -> void:
	var checkpoints: Array = p_log.to_dict().get("checkpoints", [])
	var cmds: Array[Dictionary] = p_log.cmds()
	var cp: int = 0
	var battle: BattleState = null
	var i: int = 0
	while i < cmds.size():
		var entry: Dictionary = cmds[i]
		var k: int = int(entry.get("k", 0))
		var c: Dictionary = entry.get("c", {})
		while cp < checkpoints.size() and int((checkpoints[cp] as Dictionary).get("k", 0)) < k:
			cp = _replay_checkpoint(checkpoints, cp, out)
		_replay_advance(k)
		i += 1
		match str(c.get("t", "")):
			"encounter":
				battle = _replay_begin_battle(c)
				if battle != null:
					i = _replay_play(battle, battle.start(), cmds, i)
					if battle.is_finished():
						_replay_end_battle(battle)
						battle = null
			"battle":
				if battle == null or battle.is_finished():
					push_warning("[Game] replay: battle command without an active battle (cmd %d)" % (i - 1))
				else:
					var bc: BattleCommand = BattleCommand.from_dict(c.get("cmd", {}))
					if bc != null:
						i = _replay_play(battle, battle.submit(bc), cmds, i)
					if battle.is_finished():
						_replay_end_battle(battle)
						battle = null
			_:
				_replay_apply(c)
	while cp < checkpoints.size():
		cp = _replay_checkpoint(checkpoints, cp, out)


## Steps the clock tick by tick to `k` with the live dispatch (stops if the clock stops: expired timer / stub).
func _replay_advance(k: int) -> void:
	while sim.tick() < k:
		var before: int = sim.tick()
		_dispatch(sim.step(1))
		if sim.tick() == before:
			break


func _replay_checkpoint(checkpoints: Array, cp: int, out: Dictionary) -> int:
	var want: String = str((checkpoints[cp] as Dictionary).get("h", ""))
	_replay_advance(int((checkpoints[cp] as Dictionary).get("k", 0)))
	if int(out["mismatch_at"]) < 0 and want != "" and StateHash.of(state) != want:
		out["mismatch_at"] = cp
	return cp + 1


## §5.7 BattleController.run: setup (next_seed "battle"), BattleState, Show.begin_battle (next_seed "show"),
## Events.battle_started.
func _replay_begin_battle(c: Dictionary) -> BattleState:
	var setup: BattleSetup = make_battle_setup(str(c.get("enc", "")), int(c.get("adv", 0)), str(c.get("group", "")))
	if setup == null:
		return null
	var battle: BattleState = BattleState.new(setup, DB.data)
	Show.begin_battle(setup)
	Events.battle_started.emit(setup.encounter_id, setup.is_boss)
	return battle


## §5.7 _play: events → Show.on_battle_event; then (battle not finished) one pending gift. An external gift is recorded
## when it is delivered (§3.5), i.e. as the "gift" command directly after this boundary → fed before take_pending_gift.
## Returns the index of the next command.
func _replay_play(battle: BattleState, events: Array[ActionEvent], cmds: Array[Dictionary], i: int) -> int:
	for e: ActionEvent in events:
		if e != null:
			Show.on_battle_event(e)
	if battle.is_finished():
		return i
	if i < cmds.size() and str((cmds[i].get("c", {}) as Dictionary).get("t", "")) == "gift":
		Show.receive_gift((cmds[i]["c"] as Dictionary).get("gift", {}))
		i += 1
	var g: Dictionary = Show.take_pending_gift(battle)
	if not g.is_empty():
		var gift_events: Array[ActionEvent] = battle.apply_gift(g)
		Show.note_battle_gift(g, gift_events)
		for e: ActionEvent in gift_events:
			if e != null:
				Show.on_battle_event(e)
	return i


## §5.7 after the loop: battle_ended, apply_battle_result, Show.end_battle; DEFEAT → on_game_over(&"defeat").
func _replay_end_battle(battle: BattleState) -> void:
	var result: BattleResult = battle.result
	if result == null:
		in_battle = false
		return
	Events.battle_ended.emit(result.outcome, result.encounter_id)
	apply_battle_result(result)
	Show.end_battle(result)
	if result.outcome == BattleResult.Outcome.DEFEAT:
		on_game_over(&"defeat")


## Non-battle commands → the same Game/Show method the live run used.
func _replay_apply(c: Dictionary) -> void:
	match str(c.get("t", "")):
		"floor":
			start_floor(int(c.get("floor", 1)))
		"lootbox":
			open_lootbox(str(c.get("box", "")))
		"buy":
			buy(str(c.get("item", "")), int(c.get("qty", 1)), str(c.get("safe_room", "")))
		"sell":
			sell(str(c.get("item", "")), int(c.get("qty", 1)))
		"equip":
			equip(str(c.get("member", "")), str(c.get("slot", "")), str(c.get("item", "")))
		"use_item":
			use_item(str(c.get("item", "")), str(c.get("member", "")))
		"rest":
			rest_full_heal()
		"event":
			apply_floor_event(str(c.get("id", "")), str(c.get("choice", "")))
		"chest":
			open_chest(str(c.get("id", "")))
		"gate":
			open_gate(str(c.get("key", "")))
		"room":
			visit_room(JsonUtil.arr_to_vec2i(c.get("cell", []), Vector2i(-999, -999)))
		"safe_room":
			enter_safe_room(str(c.get("id", "")))
		"safe_room_exit":
			leave_safe_room()
		"scene":
			var scene_id: String = str(c.get("id", ""))
			if DB.has_id("scenes", scene_id):
				mark_scene_seen(DB.scene_def(scene_id))
		"flag":
			set_flag(str(c.get("key", "")), c.get("value", null))
		"difficulty":
			set_difficulty(StringName(str(c.get("to", ""))))
		"descend":
			timer_running = false
			if state.floor_run != null:
				Events.floor_completed.emit(state.floor_run.index)
		"gift":
			Show.receive_gift(c.get("gift", {}))
		"sponsor_window":
			open_dev_sponsor_window(int(c.get("sec", 0)), int(c.get("slots", 0)))
		"hero":                                    # 06 package A
			set_hero(str(c.get("id", "")))
		"secret":                                  # 06 package A
			open_secret(str(c.get("id", "")))
		_:
			push_warning("[Game] replay: unknown command '%s'" % str(c.get("t", "")))
