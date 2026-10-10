extends Node
## Full-run bot (02_TECH §11.4.1), added under root by Boot with --autoplay=full (PROCESS_MODE_ALWAYS). Plays Floor 1
## end to end through the game's public APIs and the real interactions:
## title → new game (slot 1, seed 4242, intro) → tutorial fight → room by room over the layout graph (Kai walks with
## the move actions from door to door; only when he is stuck he is teleported to the next waypoint) → chests, gates
## and floor events through the focused interactable + `action` (ExplorationScene.perform_action), regular groups
## by field strike (fallback force_encounter), auto battles (AutoPolicy, levelling naturally) → safe rooms (Mopsula
## scenes, lootboxes, vending purchase, equipment, save; the save of the visit that completes the safe rooms is loaded
## back through the title's "Fortsetzen" and must give the same StateHash) → Der Hausmeister → Generalschlüssel →
## Gleis 9 → optional Die Rattenkönigin (one attempt) → stairs → floor summary → credits "Etage 2 folgt" → title, where
## "Fortsetzen" of the autosave must route straight back into the credits (unplayable floor 2).
## On the way it checks timer pauses, the state after every battle, replay ≡ live (Game.replay_log), the rebuilt map
## after loading and the M.O.D. story beats. Strategies: see `strategy`.
## Deterministic decisions (fixed seed, greedy nearest-objective planner with fixed tie order); run it with
## `--fixed-fps 60` (tools/fullrun.sh) so every frame advances the same game time.
## Output: "FULLRUN: <what>" progress lines, then "FULLRUN: stats {json}" (GDD §13 numbers) and
## "FULLRUN: OK floor_time=<s> battles=<n> level=<kai>/<mopsula> deaths=<n> frames=<n>" + quit(0);
## failure: "Assertion failed: FULLRUN failed in <phase>: <reason>" + quit(1).
## Saves go to SAVE_DIR (cleared before and after the run); settings stay ephemeral.

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const Rules := preload("res://scenes/exploration/encounter_rules.gd")
const TitleFlow := preload("res://scenes/title/title_flow.gd")
const RUN_SEED: int = 4242                 # --seed=<int> overrides it (TitleFlow.boot_seed)
const SAVE_SLOT: int = 1
const SAVE_DIR: String = "user://fullrun_saves"
const TIME_SCALE: float = 5.0
const WATCHDOG_FRAMES: int = 90000
const MAX_DEATHS: int = 3
const FLOOR_BOSS_ATTEMPTS: int = 1
## Frame budgets (60 frames = 1 s × TIME_SCALE of game time).
const BOOT_BUDGET: int = 600
const INTRO_BUDGET: int = 4000
const SETTLE_BUDGET: int = 900
const BATTLE_BUDGET: int = 9000
const WALK_STUCK_SEC: float = 1.5          # game seconds without getting 0.25 m closer → teleport to the waypoint
const WALK_BUDGET: int = 900
const ENGAGE_BUDGET: int = 600
const SAFE_BUDGET: int = 1500
const CREDITS_BUDGET: int = 2400
const STRIKE_RANGE: float = 1.4
const TIMER_SLACK_TICKS: int = 15          # timer ticks a pause may lose to its transitions (fade-in 0.25 s + a frame)
const STAIRS_HUB: float = 1.6              # room middle of the stairs room: in front of the well's entry fence
const STAND_OFF: float = 1.0               # stand this far in front of an interactable (+ its extent)
const HEAL_ITEM_BELOW: float = 0.5         # use a heal item on a member below 50 % HP
const SAFE_ROOM_BELOW: float = 0.45        # party HP ratio below this → back to the nearest safe room
const SAFE_ROOM_MAX_DIST: int = 6
const BOSS_HP_MIN: float = 0.9             # before a boss: heal in a safe room below 90 % HP / 70 % MP
const BOSS_MP_MIN: float = 0.7
const WHEEL_RESERVE: int = 60              # spin the wheel only with cost + reserve credits
const BANDAGES_WANTED: int = 3
const NO_PROGRESS_LIMIT: int = 4
const EQUIP_SLOTS: PackedStringArray = ["weapon", "armor", "accessory"]
const HEAL_ITEMS: PackedStringArray = ["itm_brutzel_burger", "itm_bandage"]

const STRATEGIES: PackedStringArray = ["thorough", "rush", "dawdle"]
const TRY_LOCKED: String = "try without key"  # objective "why" of a negative try (locked chest / gate without key)
const REQUIRED_BEATS: PackedStringArray = ["first_fight", "safe_room_enter", "scene:scn_mop_1",
	"boss_intro:enm_boss_hausmeister", "stairs_found", "floor_end"]
const HOLD_FRAMES: int = 24                # dialogs / pause menu stay open this long (2 s of game time)
const IDLE_BUDGET: int = 30000             # dawdle: frames to wait for the floor collapse (1200 s = 14 400 frames)
const MAX_STRAY_FIGHTS: int = 3
const STRAY_HUNT_DIST: int = 2             # strays are hunted only this many rooms away

enum Walk { ARRIVED, INTERRUPTED }

var frames: int = 0
var finished: bool = false
## Test hook: no quit()/print and no save-directory changes; the result stays in result_code / result_line.
var dry_run: bool = false
var result_code: int = -1
var result_line: String = ""
var phase: String = "boot"
## "thorough" (default): every group, chest, event and room, then the bosses. "rush" (--strategy=rush): only safe
## rooms, gates and the bosses — under-levelled. "dawdle" (--strategy=dawdle): after the first save Kai idles in the
## exploration until the floor collapses (timer warnings 600/300/60 → expiry → Sendeschluss "timer"). After the first
## game over the bot always loads the last save ("Letzten Spielstand laden") and continues "thorough".
var strategy: String = "thorough"
var timer_warnings: PackedInt32Array = []
var timer_expired: int = 0
var attempt_floor_boss: bool = true
## Measured numbers (see stats()).
var battles: Array[Dictionary] = []
var deaths: int = 0
var teleports: int = 0
var direct_interactions: int = 0
var forced_encounters: int = 0
var boss_levels: Dictionary = {}           # encounter id → [kai level, mopsula level] at battle start
var credits_earned: int = 0
var credits_spent: int = 0
var boxes_earned: int = 0
var boxes_opened: int = 0
var purchases: Array[String] = []
var saves: int = 0
var roundtrip_hash: String = ""
var summary: Dictionary = {}
var floor_boss_attempts: int = 0
var strays_spawned: int = 0
var hype_reasons: Dictionary = {}          # reason → summed hype delta of the running battle (diagnostics)
var credits_by_source: Dictionary = {}     # "battle" | "safe_room" | "explore" → credits earned
var replay_checks: int = 0
var paused_checked: bool = false
var tried: Dictionary = {}                 # negative paths tried once (locked chest / gate, ignore, "Noch nicht")
var mod_tags: PackedStringArray = []       # "<tag>@before|countdown" of every M.O.D./Mopsula line (story beats)

var _hype_start: int = 0
var _idle_from_ticks: int = -1             # dawdle: countdown when the idling started
var _roundtrip_done: bool = false
var _verify_scene: bool = false            # after the save/load roundtrip: compare the rebuilt map with the state
var _floor_done: bool = false
var _last_sig: String = ""
var _same_sig: int = 0
var _heal_trips: int = 0
var _saved_events: int = 0
var _log: PackedStringArray = []


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	if not dry_run:
		prepare_saves()
		strategy = strategy_from_args(OS.get_cmdline_user_args())
	# Counters ignore Game.replay_log() (the replay check re-emits the same signals).
	Events.battle_started.connect(_on_battle_started)
	Events.credits_changed.connect(_on_credits_changed)
	Events.lootbox_earned.connect(func(_id: String) -> void:
		if not Game.replaying:
			boxes_earned += 1)
	Events.lootbox_opened.connect(func(_id: String, _r: Array) -> void:
		if not Game.replaying:
			boxes_opened += 1)
	Events.game_saved.connect(func(_slot: int, ok: bool) -> void:
		if ok:
			_saved_events += 1)
	Events.hype_changed.connect(func(_h: float, delta: float, reason: StringName) -> void:
		if Game.in_battle and not Game.replaying:
			hype_reasons[String(reason)] = float(hype_reasons.get(String(reason), 0.0)) + delta)
	Events.mod_said.connect(func(_text: String, _voice: StringName, tag: String, _b: bool) -> void:
		if not Game.replaying:
			mod_tags.append("%s@%s" % [tag, "countdown" if Game.state != null and Game.state.floor_run != null
				and Game.state.floor_run.timer_started else "before"]))
	Events.floor_timer_warning.connect(func(sec: int) -> void:
		if not Game.replaying:
			timer_warnings.append(sec))
	Events.floor_timer_expired.connect(func() -> void:
		if not Game.replaying:
			timer_expired += 1)
	Events.stray_spawn_requested.connect(func(_z: String, _g: String, _e: String) -> void:
		if not Game.replaying:
			strays_spawned += 1)
	Events.item_bought.connect(func(p: Dictionary) -> void:
		if not Game.replaying:
			purchases.append("%s×%d" % [str(p.get("item_id", "")), int(p.get("qty", 1))]))
	if not dry_run:
		_main.call_deferred()


func _process(_delta: float) -> void:
	if finished:
		return
	frames += 1
	if frames > WATCHDOG_FRAMES:
		fail("watchdog (%d frames)" % WATCHDOG_FRAMES)


## --strategy=rush|dawdle → that strategy; anything else → "thorough".
static func strategy_from_args(args: PackedStringArray) -> String:
	for st: String in STRATEGIES:
		if args.has("--strategy=" + st):
			return st
	return "thorough"


## Real saves into a private directory (Boot: --autoplay=full), emptied first.
func prepare_saves() -> void:
	Save.save_dir = SAVE_DIR
	Save.read_only = false
	clear_saves()


static func clear_saves() -> void:
	var abs_dir: String = ProjectSettings.globalize_path(SAVE_DIR)
	if not DirAccess.dir_exists_absolute(abs_dir):
		return
	for f: String in DirAccess.get_files_at(abs_dir):
		DirAccess.remove_absolute(abs_dir.path_join(f))


# ======================================================================================================================
# Main flow
# ======================================================================================================================

func _main() -> void:
	phase = "boot_to_title"
	if not await _wait(func() -> bool: return Router.current is TitleScreen and not Router.busy, BOOT_BUDGET, "title"):
		return
	phase = "new_game"
	Game.auto_battle = true
	var run_seed: int = TitleFlow.boot_seed if TitleFlow.boot_seed >= 0 else RUN_SEED
	_note("new game, seed %d, strategy %s" % [run_seed, strategy])
	(Router.current as TitleScreen).request_new_game(SAVE_SLOT, "Kai", false, run_seed)
	if not await _wait(func() -> bool: return Router.current is ExplorationScene and not Router.busy, INTRO_BUDGET,
			"exploration after the intro"):
		return
	_note("floor 1 entered (intro played)")
	while not finished and not _floor_done:
		if not await settle():
			return
		if not paused_checked and Game.state.floor_run.timer_started:
			if not await pause_check(_ex()):
				return
			continue
		var obj: Dictionary = next_objective()
		phase = objective_text(obj)
		if not _check_progress(obj):
			return
		if not await _do(obj):
			return
	if finished:
		return
	if not await _after_stairs():
		return
	if not check_story_beats():
		return
	_finish_ok()


## Waits until the exploration is calm (no battle / dialog / transition): battles, safe rooms and game overs on the
## way are played through. false = the run failed.
func settle() -> bool:
	var n: int = 0
	while not finished:
		var cur: Node = Router.current
		if not Router.busy and cur != null:
			if cur is BattleScene:
				if not await _battle(cur as BattleScene):
					return false
				n = 0
				continue
			if cur is SafeRoomScene:
				if not await _safe_room(cur as SafeRoomScene):
					return false
				n = 0
				continue
			if cur.scene_file_path == Router.SCENE_GAME_OVER:
				if not await _game_over(cur):
					return false
				n = 0
				continue
			if cur is ExplorationScene:
				var ex: ExplorationScene = cur as ExplorationScene
				if ex.active_dialog() != null and not ex.is_revealing():
					ex.active_dialog().cancel()             # a dialog the bot did not open: close it
				elif not ex.is_encounter_pending() and not ex.is_modal():
					return true
			elif not (cur is FloorSummary):
				return fail("unexpected screen %s" % _screen_name(cur))
		n += 1
		if n > SETTLE_BUDGET:
			return fail("exploration did not settle within %d frames (%s)" % [SETTLE_BUDGET, state_text()])
		await get_tree().process_frame
	return false


# ======================================================================================================================
# Planner
# ======================================================================================================================

## Next goal from the game state: {"kind": "group"|"chest"|"event"|"gate"|"safe"|"visit"|"boss"|"stairs"|"idle",
## "id": String, "cell": Vector2i, "why": String}. Nearest reachable candidate first (BFS over open doors, living
## bosses block); none left → quarter boss → floor boss (optional) → stairs.
func next_objective() -> Dictionary:
	var ex: ExplorationScene = _ex()
	var layout: FloorLayout = ex.get_layout()
	var fr: FloorRun = Game.state.floor_run
	var here: Vector2i = ex.get_player_cell()
	var dist: Dictionary = layout.distances(here, fr.opened_gates, false, _boss_blocks(layout, fr, Vector2i(-99, -99)))
	_use_heal_items()
	equip_best()
	if fr.defeated_groups.is_empty() and layout.enemy_by_id("f1_g0") != null:
		return {"kind": "group", "id": "f1_g0", "cell": layout.enemy_by_id("f1_g0").cell, "why": "tutorial"}
	if strategy == "dawdle" and saves > 0:
		return {"kind": "idle", "id": "", "cell": here, "why": "until the floor collapses"}
	if party_ratio("hp") < SAFE_ROOM_BELOW and _heal_trips < 2:
		var sr: Dictionary = _nearest_safe(layout, dist)
		if not sr.is_empty() and int(dist.get(sr["cell"], 99)) <= SAFE_ROOM_MAX_DIST:
			_heal_trips += 1
			sr["why"] = "heal"
			return sr
	var best: Dictionary = {}
	var best_d: int = 1 << 20
	for c: Dictionary in candidates(layout, fr, dist):
		var d: int = int(dist.get(c["cell"], -1))
		if d >= 0 and d < best_d:
			best_d = d
			best = c
	if not best.is_empty():
		return best
	var boss: Dictionary = _boss_objective(layout, fr)
	if not boss.is_empty():
		var need_heal: bool = party_ratio("hp") < BOSS_HP_MIN or party_ratio("mp") < BOSS_MP_MIN
		if need_heal and _heal_trips < 2:
			var sr2: Dictionary = _nearest_safe(layout, dist)
			if not sr2.is_empty():
				_heal_trips += 1
				sr2["why"] = "heal before " + str(boss["id"])
				return sr2
		return boss
	return {"kind": "stairs", "id": "stairs", "cell": layout.stairs, "why": ""}


## Every open goal in a fixed order (groups, chests, events, gates, safe rooms, unvisited rooms); boss rooms and the
## stairs room are not visited for their own sake.
func candidates(layout: FloorLayout, fr: FloorRun, dist: Dictionary = {}) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var rush: bool = strategy == "rush"
	for e: EnemySpawn in layout.enemies:
		if not rush and not e.is_boss and not e.is_stray() and not fr.defeated_groups.has(e.id):
			out.append({"kind": "group", "id": e.id, "cell": e.cell, "why": e.encounter_id})
	# Living strays (GDD §2.7) close by (≤ STRAY_HUNT_DIST rooms), while the budget lasts (they come back every 90 s).
	var ex: ExplorationScene = _ex()
	if not rush and ex != null and strays_fought() < MAX_STRAY_FIGHTS:
		var sids: Array = fr.strays.keys()
		sids.sort()
		for gid: Variant in sids:
			var a: Node3D = ex.get_enemy(str(gid))
			var sc: Vector2i = layout.world_to_cell(a.global_position) if a != null else Vector2i(-99, -99)
			if a != null and int(dist.get(sc, 99)) <= STRAY_HUNT_DIST:
				out.append({"kind": "group", "id": str(gid), "cell": sc,
					"why": "stray " + str((fr.strays[gid] as Dictionary).get("enc", ""))})
	var has_key: bool = Game.state.inventory.has(Game.KEY_MASTER)
	for ch: ChestSpawn in layout.chests:
		if not rush and not fr.opened_chests.has(ch.id) and (ch.type != "locked" or has_key):
			out.append({"kind": "chest", "id": ch.id, "cell": ch.cell, "why": ch.type})
		elif not rush and ch.type == "locked" and not has_key and not tried.has(ch.id):
			out.append({"kind": "chest", "id": ch.id, "cell": ch.cell, "why": TRY_LOCKED})
	for ev: EventSpawn in layout.events:
		var choice: String = event_choice(ev)
		if not rush and choice != "":
			out.append({"kind": "event", "id": ev.id, "cell": ev.cell, "why": choice})
	for g: Dictionary in layout.gates:
		var req: String = str(g["requires"])
		if not fr.opened_gates.has(str(g["key"])) and not req.begins_with("event:") and Game.state.inventory.has(req):
			out.append({"kind": "gate", "id": str(g["key"]), "cell": g["cell"], "why": req})
		elif not rush and not fr.opened_gates.has(str(g["key"])) and not tried.has(str(g["key"])):
			out.append({"kind": "gate", "id": str(g["key"]), "cell": g["cell"], "why": TRY_LOCKED})
	var sids: Array = layout.safe_room_info.keys()
	sids.sort()
	for sid: Variant in sids:
		if not fr.visited_safe_rooms.has(str(sid)):
			out.append({"kind": "safe", "id": str(sid), "cell": (layout.safe_room_info[sid] as Dictionary)["cell"],
				"why": "first visit"})
	for c: Vector2i in layout.sorted_cells():
		var rc: RoomCell = layout.cell_at(c)
		if rush or fr.visited.has(c) or rc.kind == RoomCell.Kind.QUARTER_BOSS or rc.kind == RoomCell.Kind.FLOOR_BOSS \
				or rc.kind == RoomCell.Kind.STAIRS:
			continue
		out.append({"kind": "visit", "id": "", "cell": c, "why": "unvisited"})
	return out


## The choice the bot makes at a floor event ("" = nothing to do there).
func event_choice(ev: EventSpawn) -> String:
	var fr: FloorRun = Game.state.floor_run
	var avail: PackedStringArray = FloorEvent.choices(ev, Game.state, DB.data)
	if ev.type == "wheel":
		var cost: int = int(ev.params.get("cost", 0))
		if not (avail.has("spin") and Game.state.inventory.credits >= cost + WHEEL_RESERVE):
			return ""
		return "spin" if tried.has(ev.id) else "ignore"            # "Ignorieren" once first: closes, changes nothing
	if fr.completed_events.has(ev.id):
		return ""
	match ev.type:
		"photo_drone":
			return "pose" if avail.has("pose") else ""
		"lost_candidate":
			for c: String in avail:
				if c.begins_with(FloorEvent.GIVE_PREFIX):
					return c
			return ""                     # "Weitergehen" keeps it open (02_TECH §7.4): come back with a heal item
		"lever":
			return "pull" if avail.has("pull") else ""
		"broken_vending":
			return "kick" if avail.has("kick") else ""
	return ""


func _boss_objective(layout: FloorLayout, fr: FloorRun) -> Dictionary:
	if layout.quarter_boss != Vector2i(-1, -1) and not fr.quarter_boss_defeated:
		return {"kind": "boss", "id": "f%d_qb" % fr.index, "cell": layout.quarter_boss, "why": "quarter boss"}
	if attempt_floor_boss and layout.floor_boss != Vector2i(-1, -1) and not fr.floor_boss_defeated \
			and floor_boss_attempts < FLOOR_BOSS_ATTEMPTS:
		return {"kind": "boss", "id": "f%d_fb" % fr.index, "cell": layout.floor_boss, "why": "floor boss"}
	return {}


## Living boss rooms (never walked through unless they are the goal).
func _boss_blocks(layout: FloorLayout, fr: FloorRun, goal: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if layout.quarter_boss != Vector2i(-1, -1) and not fr.quarter_boss_defeated and layout.quarter_boss != goal:
		out.append(layout.quarter_boss)
	if layout.floor_boss != Vector2i(-1, -1) and not fr.floor_boss_defeated and layout.floor_boss != goal:
		out.append(layout.floor_boss)
	return out


func _nearest_safe(layout: FloorLayout, dist: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_d: int = 1 << 20
	var sids: Array = layout.safe_room_info.keys()
	sids.sort()
	for sid: Variant in sids:
		var cell: Vector2i = (layout.safe_room_info[sid] as Dictionary)["cell"]
		var d: int = int(dist.get(cell, -1))
		if d >= 0 and d < best_d:
			best_d = d
			best = {"kind": "safe", "id": str(sid), "cell": cell, "why": ""}
	return best


static func objective_text(obj: Dictionary) -> String:
	var c: Vector2i = obj.get("cell", Vector2i.ZERO)
	var why: String = str(obj.get("why", ""))
	return "%s %s (%d,%d)%s" % [str(obj.get("kind", "")), str(obj.get("id", "")), c.x, c.y,
		(" [" + why + "]") if why != "" else ""]


## Fails when the same objective comes back NO_PROGRESS_LIMIT times without any change of the floor state.
func _check_progress(obj: Dictionary) -> bool:
	var fr: FloorRun = Game.state.floor_run
	var uses: int = 0
	for v: Variant in fr.event_uses.values():
		uses += int(v)
	var sig: String = "%s|%d|%d|%d|%d|%d|%d|%s|%s|%d|%d|%d" % [objective_text(obj), fr.visited.size(),
		fr.opened_chests.size(), fr.defeated_groups.size(), fr.completed_events.size(), fr.opened_gates.size(),
		fr.safe_room_visits, str(fr.quarter_boss_defeated), str(fr.floor_boss_defeated), battles.size(), uses,
		tried.size()]
	if sig == _last_sig:
		_same_sig += 1
		if _same_sig >= NO_PROGRESS_LIMIT:
			return fail("no progress after %d attempts (%s)" % [_same_sig, state_text()])
	else:
		_same_sig = 0
		_last_sig = sig
	return true


# ======================================================================================================================
# Objectives
# ======================================================================================================================

func _do(obj: Dictionary) -> bool:
	var kind: String = str(obj["kind"])
	var cell: Vector2i = obj["cell"]
	if kind == "idle":
		return await _idle_until_collapse()
	if kind != "safe" and kind != "boss":
		_heal_trips = 0
	var w: int = await travel(cell)
	if finished:
		return false
	if w == Walk.INTERRUPTED:
		return true
	var ex: ExplorationScene = _ex()
	match kind:
		"group":
			return await _engage(ex, str(obj["id"]))
		"chest", "event", "safe", "stairs":
			var it: Node = ex.get_interactable(str(obj["id"]))
			if it == null:
				return fail("no interactable '%s' in the scene" % str(obj["id"]))
			return await _use_interactable(ex, it, obj)
		"gate":
			var gate: Node = ex.get_interactable(str(obj["id"]))
			if gate == null:
				return fail("no gate '%s' in the scene" % str(obj["id"]))
			return await _use_interactable(ex, gate, obj)
		"boss":
			# Walking into the room triggers the boss (5 m around boss_spot); stand on the spot if it did not.
			if await walk_to(ex, ex.get_layout().cell_to_world(cell)) == Walk.INTERRUPTED:
				return true
			if Router.current == ex and not ex.is_encounter_pending():
				forced_encounters += 1
				ex.force_encounter(str(obj["id"]))
			return true
	return true


## Keeps the open dialog / menu up for HOLD_FRAMES: the floor timer must not move meanwhile (GDD §2.9).
func _hold_and_check_timer(what: String) -> bool:
	var tl0: int = Game.state.floor_run.time_left_ticks
	for _i in HOLD_FRAMES:
		await get_tree().process_frame
		if finished:
			return false
	if Game.state.floor_run.time_left_ticks != tl0:
		return fail("the floor timer ran %d ticks while the %s was open" % [tl0 - Game.state.floor_run.time_left_ticks,
			what])
	return true


## Pause menu over the exploration (action `pause` → ExplorationHud → PauseMenu): tree paused, timer stopped; ui_cancel
## closes it and the countdown goes on. Once per run, right after the countdown started.
func pause_check(ex: ExplorationScene) -> bool:
	phase = "pause menu"
	var fr: FloorRun = Game.state.floor_run
	UiUtil.tap_action(&"pause", true)
	await get_tree().process_frame
	UiUtil.tap_action(&"pause", false)
	if not await _wait(func() -> bool: return get_tree().paused, 60, "the pause menu (tree paused)"):
		return false
	if not await _hold_and_check_timer("pause menu"):
		return false
	UiUtil.tap_action(&"ui_cancel", true)
	await get_tree().process_frame
	UiUtil.tap_action(&"ui_cancel", false)
	if not await _wait(func() -> bool: return not get_tree().paused, 60, "the pause menu to close"):
		return false
	var tl1: int = fr.time_left_ticks
	if not await _wait(func() -> bool: return fr.time_left_ticks < tl1, 60, "the countdown after the pause menu"):
		return false
	_note("pause menu: tree paused, timer stopped; closed with ui_cancel, countdown runs again")
	paused_checked = true
	if Router.current != ex:
		return await settle()
	return true


## dawdle: stands still until the countdown expires; checks the warnings (600/300/60 in that order, once each) and that
## the collapse leads to the Sendeschluss screen with reason &"timer".
func _idle_until_collapse() -> bool:
	var ex: ExplorationScene = _ex()
	if _idle_from_ticks < 0:
		_idle_from_ticks = Game.state.floor_run.time_left_ticks     # a stray fight may interrupt the idling
	var tl0: int = _idle_from_ticks
	_note("idling at %s with %d s on the clock" % [str(ex.get_player_cell()), tl0 / Game.TICKS_PER_SEC])
	var n: int = 0
	while not finished and Router.current == ex:
		n += 1
		if n > IDLE_BUDGET:
			return fail("the floor timer did not expire within %d frames (%s)" % [IDLE_BUDGET, state_text()])
		await get_tree().process_frame
	if not await _wait(func() -> bool: return Router.current != null and not Router.busy, 600, "screen after idling"):
		return false
	if Router.current is BattleScene:
		return true                                # a stray found Kai: fight, then idle on
	var cur: Node = Router.current
	if cur.scene_file_path != Router.SCENE_GAME_OVER or StringName(str(cur.get("reason"))) != &"timer":
		return fail("idling ended on %s (reason %s), expected Sendeschluss by timer" % [_screen_name(cur),
			str(cur.get("reason"))])
	var want: PackedInt32Array = []
	for w: int in Game.floor_def().timer_warnings:
		if w * Game.TICKS_PER_SEC < tl0:
			want.append(w)
	want.sort()
	want.reverse()
	if timer_warnings != want or timer_expired != 1:
		return fail("timer warnings %s (expected %s), expired %d×" % [str(timer_warnings), str(want), timer_expired])
	_note("floor collapsed after %d frames (warnings %s)" % [n, str(timer_warnings)])
	return true


## Group fight: walk up to the symbol and hit it with a field strike (preemptive for IDLE/PATROL), else contact; the
## bot falls back to ExplorationScene.force_encounter(group) after ENGAGE_BUDGET frames.
func _engage(ex: ExplorationScene, group_id: String) -> bool:
	var n: int = 0
	while not finished:
		if _interrupted(ex):
			UiUtil.release_move_actions()
			return true
		var a: Node3D = ex.get_enemy(group_id)
		if a == null:
			return true
		var p: Vector3 = ex.get_player_position()
		if Rules.flat_dist(p, a.global_position) <= STRIKE_RANGE:
			UiUtil.release_move_actions()
			var body: CharacterBody3D = ex.get_player()
			_face(body, a.global_position)
			await get_tree().physics_frame
			if not _interrupted(ex) and ex.focused_interactable() == null:
				ex.perform_action()
			for _i in 12:
				await get_tree().physics_frame
				if _interrupted(ex):
					return true
		else:
			_steer(ex, a.global_position)
			await get_tree().physics_frame
		n += 1
		if n > ENGAGE_BUDGET:
			UiUtil.release_move_actions()
			forced_encounters += 1
			_note("strike on %s did not start a battle → force_encounter" % group_id)
			ex.force_encounter(group_id)
			return true
	return false


## Walks to the stand point in front of `it`, faces it and presses `action` while it is focused (fallback: interact()
## directly). Then plays the follow-up (event dialog choice, stairs confirmation) and checks the effect.
func _use_interactable(ex: ExplorationScene, it: Node, obj: Dictionary) -> bool:
	var kind: String = str(obj["kind"])
	var cell: Vector2i = obj["cell"]
	var layout: FloorLayout = ex.get_layout()
	var center: Vector3 = layout.cell_to_world(cell)
	var rp: Vector3 = it.call("reach_point", center)
	var away: Vector3 = Rules.flat_dir(rp, center)
	if away == Vector3.ZERO:
		away = Rules.flat_forward((it as Node3D).global_transform.basis) * -1.0
	var extent: float = float(it.get("extent"))
	for attempt in 2:
		var stand: Vector3 = rp + away * (extent + (STAND_OFF if attempt == 0 else 0.55))
		if await walk_to(ex, stand, 0.3) == Walk.INTERRUPTED:
			return true
		var body: CharacterBody3D = ex.get_player()
		_face(body, rp)
		for _i in 3:
			await get_tree().physics_frame
		if _interrupted(ex):
			return true
		if ex.focused_interactable() == it:
			ex.perform_action()
			break
		if attempt == 1:
			direct_interactions += 1
			_note("%s not focused (focus: %s) → interact()" % [str(obj["id"]), _focus_name(ex)])
			it.call("interact")
	await get_tree().process_frame
	var fr: FloorRun = Game.state.floor_run
	match kind:
		"chest", "gate":
			var id: String = str(obj["id"])
			var opened: bool = fr.opened_chests.has(id) if kind == "chest" else fr.opened_gates.has(id)
			if str(obj["why"]) == TRY_LOCKED:
				tried[id] = true
				if opened:
					return fail("%s %s opened without its key" % [kind, id])
				if ex.is_modal() or not Game.is_timer_ticking():
					return fail("trying the locked %s %s left the exploration blocked" % [kind, id])
				_note("%s %s stays locked without its key (prompt: %s)" % [kind, id, str(it.call("prompt_text"))])
			elif not opened:
				return fail("%s %s did not open" % [kind, id])
			else:
				_note("%s %s opened" % [kind, id])
		"event":
			return await _event_dialog(ex, str(obj["id"]), str(obj["why"]))
		"stairs":
			var dlg: Node = ex.active_dialog()
			if dlg == null:
				return fail("stairs did not ask for confirmation")
			if not await _hold_and_check_timer("stairs dialog"):
				return false
			if not tried.has("stairs"):
				# "Noch nicht" first: the dialog closes, Kai stays on the floor, the countdown goes on.
				tried["stairs"] = true
				dlg.call("choose", "stay")
				if not await _wait(func() -> bool: return not ex.is_modal(), 60, "stairs dialog closed"):
					return false
				var tl: int = fr.time_left_ticks
				if not await _wait(func() -> bool: return fr.time_left_ticks < tl, 60, "countdown after Noch nicht"):
					return false
				if Router.current != ex or Game.state.floor_run.index != 1:
					return fail("\"Noch nicht\" at the stairs left the floor")
				_note("stairs: \"Noch nicht\" keeps Kai on the floor")
				return true
			_note("stairs: descend")
			dlg.call("choose", "descend")
			_floor_done = true
		"safe":
			if not await _wait(func() -> bool: return Router.current is SafeRoomScene and not Router.busy, 300,
					"safe room %s" % str(obj["id"])):
				return false
	return true


func _event_dialog(ex: ExplorationScene, event_id: String, choice: String) -> bool:
	var dlg: Node = ex.active_dialog()
	if dlg == null:
		return fail("event %s opened no dialog" % event_id)
	var fr: FloorRun = Game.state.floor_run
	var uses: int = int(fr.event_uses.get(event_id, 0))
	var done_before: bool = fr.completed_events.has(event_id)
	if not await _hold_and_check_timer("event dialog " + event_id):
		return false
	dlg.call("choose", choice)
	if not await _wait(func() -> bool: return Router.current != ex or not ex.is_modal() or ex.is_encounter_pending(),
			300, "event %s outcome" % event_id):
		return false
	var used: bool = int(fr.event_uses.get(event_id, 0)) > uses or (fr.completed_events.has(event_id)
		and not done_before)
	if FloorEvent.PASSIVE_CHOICES.has(choice):
		tried[event_id] = true
		if used:
			return fail("event %s: '%s' should only close the dialog" % [event_id, choice])
		_note("event %s: %s closes the dialog, event stays open" % [event_id, choice])
		return true
	if not used:
		return fail("event %s: choice '%s' changed nothing" % [event_id, choice])
	_note("event %s: %s%s" % [event_id, choice, " → battle" if ex.is_encounter_pending() else ""])
	return true


# ======================================================================================================================
# Walking
# ======================================================================================================================

## Walks door by door to `cell` (shortest path over open doors; living boss rooms only as the goal).
func travel(cell: Vector2i) -> Walk:
	var ex: ExplorationScene = _ex()
	var layout: FloorLayout = ex.get_layout()
	var fr: FloorRun = Game.state.floor_run
	var path: Array[Vector2i] = find_path(layout, ex.get_player_cell(), cell, fr.opened_gates,
		_boss_blocks(layout, fr, cell))
	if path.is_empty():
		fail("no path from %s to %s" % [str(ex.get_player_cell()), str(cell)])
		return Walk.INTERRUPTED
	var p: Vector3 = ex.get_player_position()
	var here: Vector3 = hub(ex, path[0])
	if path.size() > 1 and Rules.flat_dist(p, here) > 3.0:
		if await walk_to(ex, here, 1.0) == Walk.INTERRUPTED:
			return Walk.INTERRUPTED
	for i in range(1, path.size()):
		var a: Vector3 = layout.cell_to_world(path[i - 1])
		var b: Vector3 = hub(ex, path[i])
		if await walk_to(ex, (a + layout.cell_to_world(path[i])) * 0.5, 0.8) == Walk.INTERRUPTED:
			return Walk.INTERRUPTED
		var last: bool = i == path.size() - 1
		var rc: RoomCell = layout.cell_at(path[i])
		var boss_room: bool = rc.kind == RoomCell.Kind.QUARTER_BOSS or rc.kind == RoomCell.Kind.FLOOR_BOSS
		if last and boss_room:
			return Walk.ARRIVED                    # the boss objective walks in itself
		if await walk_to(ex, b, 1.2 if not last else 0.8) == Walk.INTERRUPTED:
			return Walk.INTERRUPTED
	return Walk.ARRIVED


## Walkable middle of a room: its centre, in the stairs room 1.6 m in front of the fenced well (the well sits on the
## centre, EnvKit anchor &"stairs", entry edge at local z 0, well toward local −Z).
func hub(ex: ExplorationScene, cell: Vector2i) -> Vector3:
	var layout: FloorLayout = ex.get_layout()
	if cell == layout.stairs:
		var st: Node3D = ex.get_interactable("stairs") as Node3D
		if st != null:
			var h: Vector3 = st.global_transform * Vector3(0.0, 0.0, STAIRS_HUB)
			return Vector3(h.x, 0.0, h.z)
	return layout.cell_to_world(cell)


## BFS path from → to over the open doors (closed gates and `blocked` cells excluded); [] if unreachable.
static func find_path(layout: FloorLayout, from: Vector2i, to: Vector2i, opened: PackedStringArray,
		blocked: Array[Vector2i]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if layout == null or layout.cell_at(from) == null or layout.cell_at(to) == null:
		return out
	var parent: Dictionary = {from: from}
	var queue: Array[Vector2i] = [from]
	var head: int = 0
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		if cur == to:
			break
		for n: Vector2i in layout.neighbors(cur, opened):
			if parent.has(n) or (blocked.has(n) and n != to):
				continue
			parent[n] = cur
			queue.append(n)
	if not parent.has(to):
		return out
	var c: Vector2i = to
	while c != from:
		out.push_front(c)
		c = parent[c]
	out.push_front(from)
	return out


## Steers Kai with the move actions until he is within `tolerance` of `target` (XZ). Stuck (no 0.25 m of progress for
## WALK_STUCK_SEC of game time) or over WALK_BUDGET frames → teleport onto the target (counted).
func walk_to(ex: ExplorationScene, target: Vector3, tolerance: float = 0.5) -> Walk:
	var best: float = INF
	var stuck: float = 0.0
	var n: int = 0
	while not finished:
		if _interrupted(ex):
			UiUtil.release_move_actions()
			return Walk.INTERRUPTED
		var p: Vector3 = ex.get_player_position()
		var d: float = Rules.flat_dist(p, target)
		if d <= tolerance:
			UiUtil.release_move_actions()
			return Walk.ARRIVED
		if d < best - 0.25:
			best = d
			stuck = 0.0
		else:
			stuck += get_physics_process_delta_time()        # already scaled by Engine.time_scale
		n += 1
		if stuck > WALK_STUCK_SEC or n > WALK_BUDGET:
			UiUtil.release_move_actions()
			teleports += 1
			var body: CharacterBody3D = ex.get_player()
			_note("stuck at %s (%.1f m before %s, cell %s) → teleport [input %s vel %s vec %s yaw %.2f floor %s]" % [
				_v(p), d, _v(target), str(ex.get_player_cell()), str(body.get("input_enabled")), str(body.velocity),
				str(Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")),
				ex.get_camera_rig().yaw, str(body.is_on_floor())])
			body.call("teleport", Vector3(target.x, p.y + 0.05, target.z), body.rotation.y)
			await get_tree().physics_frame
			return Walk.INTERRUPTED if _interrupted(ex) else Walk.ARRIVED
		_steer(ex, target)
		await get_tree().physics_frame
	UiUtil.release_move_actions()
	return Walk.INTERRUPTED


## Move actions for the world direction to `target`, relative to the camera yaw like a stick (PlayerController moves
## camera relative: dir = Vector3(input.x, 0, input.y).rotated(UP, camera_yaw)).
func _steer(ex: ExplorationScene, target: Vector3) -> void:
	var dir: Vector3 = Rules.flat_dir(ex.get_player_position(), target)
	var yaw: float = ex.get_camera_rig().yaw if ex.get_camera_rig() != null else 0.0
	var v: Vector2 = steer_input(dir, yaw)
	_press(&"move_right", v.x)
	_press(&"move_left", -v.x)
	_press(&"move_back", v.y)
	_press(&"move_forward", -v.y)


## Input vector (x = right, y = back) that makes the camera-relative movement go along `dir`; length 1.
static func steer_input(dir: Vector3, camera_yaw: float) -> Vector2:
	var local: Vector3 = dir.rotated(Vector3.UP, -camera_yaw)
	var v: Vector2 = Vector2(local.x, local.z)
	return v.normalized() if v.length_squared() > 0.000001 else Vector2.ZERO


static func _press(action: StringName, strength: float) -> void:
	if strength > 0.001:
		Input.action_press(action, clampf(strength, 0.0, 1.0))
	elif Input.is_action_pressed(action):
		Input.action_release(action)


func _face(body: CharacterBody3D, target: Vector3) -> void:
	var d: Vector3 = Rules.flat_dir(body.global_position, target)
	if d != Vector3.ZERO:
		body.call("teleport", body.global_position, Rules.yaw_of(d))


func _interrupted(ex: ExplorationScene) -> bool:
	return finished or not is_instance_valid(ex) or Router.current != ex or Router.busy or not ex.is_inside_tree() \
		or ex.is_encounter_pending() or ex.is_modal()


# ======================================================================================================================
# Battles, game over
# ======================================================================================================================

func _battle(bs: BattleScene) -> bool:
	phase = "battle %s" % (bs.battle_setup.encounter_id if bs.battle_setup != null else "?")
	var setup: BattleSetup = bs.battle_setup
	var max_hp: int = 0
	for m: PartyMember in Game.state.party:
		max_hp += Progression.total_stats(m, DB.data).values[StatBlock.Stat.HP]
	var res: BattleResult = null
	var rw: BattleRewards = null
	var tl0: int = Game.state.floor_run.time_left_ticks
	var n: int = 0
	while not finished:
		if is_instance_valid(bs) and bs.controller != null and bs.controller.result != null:
			res = bs.controller.result
			rw = bs.controller.rewards
		var cur: Node = Router.current
		if not Router.busy and cur != bs and cur != null and res != null:
			break
		n += 1
		if n > BATTLE_BUDGET:
			return fail("battle %s did not end within %d frames (%s)" % [setup.encounter_id if setup != null else "?",
				BATTLE_BUDGET, state_text()])
		await get_tree().process_frame
	if finished:
		return false
	var rec: Dictionary = {"enc": res.encounter_id, "group": res.group_id, "outcome": res.outcome_name(),
		"boss": res.is_boss, "adv": res.advantage, "party_turns": res.party_turns, "turns": res.turns,
		"hp_loss_pct": roundi(100.0 * res.damage_taken / maxf(1.0, float(max_hp))), "frames": n,
		"level": _levels(), "followers": rw.followers if rw != null else 0,
		"hype_end": roundi(Game.state.show.hype) if Game.state.show != null else 0, "hype_start": _hype_start,
		"hype_reasons": _reasons_text()}
	battles.append(rec)
	_note("battle %d %s %s: %s, adv %d, party turns %d, turns %d, HP loss %d%%, level %s, +%d followers, hype %d" % [
		battles.size(), res.encounter_id, res.group_id, res.outcome_name(), res.advantage, res.party_turns, res.turns,
		int(rec["hp_loss_pct"]), str(rec["level"]), int(rec["followers"]), int(rec["hype_end"])])
	_note("  hype %d → %d: %s" % [_hype_start, int(rec["hype_end"]), str(rec["hype_reasons"])])
	if res.outcome == BattleResult.Outcome.VICTORY and not (Router.current is ExplorationScene):
		return fail("victory but the screen after the battle is %s" % _screen_name(Router.current))
	if res.outcome == BattleResult.Outcome.VICTORY and res.group_id != "" \
			and not Game.state.floor_run.defeated_groups.has(res.group_id):
		return fail("victory over %s but the group is not marked defeated" % res.group_id)
	if res.outcome != BattleResult.Outcome.DEFEAT:
		return _check_after_battle(res, tl0)
	return true


## Back in the exploration after a battle: Game out of battle mode, the symbol gone, no member below 1 HP, the timer
## paused during the fight (only the fade-in may tick), the countdown started after the tutorial.
func _check_after_battle(res: BattleResult, tl0: int) -> bool:
	var fr: FloorRun = Game.state.floor_run
	if Game.in_battle:
		return fail("Game.in_battle still true after %s" % res.encounter_id)
	var ex: ExplorationScene = _ex()
	if ex != null and res.group_id != "" and res.outcome == BattleResult.Outcome.VICTORY \
			and ex.get_enemy(res.group_id) != null:
		return fail("the symbol of %s is still on the map after the victory" % res.group_id)
	for m: PartyMember in Game.state.party:
		if m.hp < 1:
			return fail("%s has %d HP after %s" % [m.id, m.hp, res.encounter_id])
	var used: int = tl0 - fr.time_left_ticks
	if used > TIMER_SLACK_TICKS:
		return fail("the floor timer ran %d ticks during the battle %s" % [used, res.encounter_id])
	var def: FloorDef = Game.floor_def()
	if def != null and res.encounter_id == def.timer_start_after and not fr.timer_started:
		return fail("the countdown did not start after %s" % res.encounter_id)
	if ex != null and not ex.is_modal() and fr.timer_started and not Game.is_timer_ticking():
		return fail("the floor timer does not tick in the exploration after %s" % res.encounter_id)
	return true


func _game_over(screen: Node) -> bool:
	deaths += 1
	_note("GAME OVER #%d (%s)" % [deaths, phase])
	if deaths > MAX_DEATHS:
		return fail("%d game overs" % deaths)
	if not await _wait(func() -> bool: return bool(screen.call("buttons_ready")), 300, "game over buttons"):
		return false
	if not bool(screen.call("can_load")):
		return fail("game over without a save to load")
	screen.call("load_last")
	if strategy != "thorough":
		_note("strategy %s → thorough after the game over" % strategy)
		strategy = "thorough"
	if Game.state.floor_run.time_left_ticks < Save.GRACE_SECONDS * Game.TICKS_PER_SEC:
		return fail("loaded the last save with %d s on the clock (grace %d s)" % [int(Game.time_left()),
			Save.GRACE_SECONDS])
	return await _wait(func() -> bool: return (Router.current is ExplorationScene or Router.current is SafeRoomScene) \
		and not Router.busy, 600, "exploration after loading the last save")


# ======================================================================================================================
# Safe room
# ======================================================================================================================

func _safe_room(scene: SafeRoomScene) -> bool:
	phase = "safe room %s" % scene.safe_room_id
	await get_tree().process_frame
	var sid: String = scene.safe_room_id
	var tl0: int = Game.state.floor_run.time_left_ticks
	_note("safe room %s (visit %d)" % [sid, Game.state.floor_run.safe_room_visits])
	if not _replay_check():
		return false
	# Mopsula scenes
	var guard: int = 0
	while scene.pending_scene != null and guard < 4:
		guard += 1
		var played: int = scene.played_scenes.size()
		var scene_id: String = scene.pending_scene.id
		scene.activate("mopsula")
		if not await _wait(func() -> bool: return scene.played_scenes.size() > played, SAFE_BUDGET,
				"Mopsula scene %s" % scene_id):
			return false
		_note("Mopsula scene %s" % scene_id)
	if not Game.state.pending_lootboxes.is_empty():
		if not await _open_lootboxes(scene):
			return false
	equip_best()
	if not await _shop(scene):
		return false
	equip_best()
	if not await _save(scene):
		return false
	var fr: FloorRun = Game.state.floor_run
	if tl0 - fr.time_left_ticks > TIMER_SLACK_TICKS:
		return fail("the floor timer ran %d ticks in the safe room" % (tl0 - fr.time_left_ticks))
	if not _roundtrip_done and fr.visited_safe_rooms.size() >= _layout_safe_rooms():
		_roundtrip_done = true
		return await _save_load_roundtrip()
	scene.activate("leave")
	if not await _wait(func() -> bool: return Router.current is ExplorationScene and not Router.busy, 300,
			"exploration after leaving %s" % sid):
		return false
	if _verify_scene:
		_verify_scene = false
		return check_scene_state(_ex())
	return true


## Number of safe rooms of the current floor (from the floor's layout).
func _layout_safe_rooms() -> int:
	var def: FloorDef = Game.floor_def()
	if def == null or Game.state.floor_run == null:
		return 0
	var layout: FloorLayout = DungeonGenerator.generate(def, Game.state.floor_run.seed)
	return layout.safe_rooms.size() if layout != null else 0


## Game.replay_log(run log) must reproduce the live StateHash (Brief §6b; only while the log starts at new_game).
func _replay_check() -> bool:
	if Game.run_log == null or bool(Game.run_log.header.get("from_save", false)):
		return true
	var live: String = StateHash.of(Game.state)
	# the run clock keeps ticking in the safe room (idle ticks, Sponsor-Fenster 05 §6.13): replay up to the live tick
	var out: Dictionary = Game.replay_log(Game.run_log, Game.sim.tick() if Game.sim != null else -1)
	replay_checks += 1
	if str(out.get("final_hash", "")) != live:
		return fail("replay of the run log (%d commands) does not reproduce the live state (mismatch at checkpoint %d)"
			% [Game.run_log.cmds().size(), int(out.get("mismatch_at", -1))])
	_note("replay check: %d commands reproduce the live StateHash" % Game.run_log.cmds().size())
	return true


## The exploration scene shows what the state says (after loading a save): opened chests open, defeated groups gone,
## living groups and strays present, opened gates open, completed events without prompt.
func check_scene_state(ex: ExplorationScene) -> bool:
	if ex == null:
		return fail("no exploration to verify")
	var fr: FloorRun = Game.state.floor_run
	var layout: FloorLayout = ex.get_layout()
	for ch: ChestSpawn in layout.chests:
		var it: Node = ex.get_interactable(ch.id)
		if it != null and bool(it.get("is_open")) != fr.opened_chests.has(ch.id):
			return fail("chest %s: open %s on the map, %s in the state" % [ch.id, str(it.get("is_open")),
				str(fr.opened_chests.has(ch.id))])
	for e: EnemySpawn in layout.enemies:
		if fr.defeated_groups.has(e.id) and ex.get_enemy(e.id) != null:
			return fail("defeated group %s is back on the map" % e.id)
		if not e.is_boss and not fr.defeated_groups.has(e.id) and ex.get_enemy(e.id) == null:
			return fail("living group %s is missing on the map" % e.id)
	for gid: Variant in fr.strays.keys():
		if ex.get_enemy(str(gid)) == null:
			return fail("living stray %s is missing on the map" % str(gid))
	for g: Dictionary in layout.gates:
		var gate: Node = ex.get_interactable(str(g["key"]))
		if fr.opened_gates.has(str(g["key"])) and gate != null and not bool(gate.get("opened")):
			return fail("gate %s is closed on the map but open in the state" % str(g["key"]))
	for ev: EventSpawn in layout.events:
		var evi: Node = ex.get_interactable(ev.id)
		if evi != null and fr.completed_events.has(ev.id) and ev.type != "wheel" and str(evi.call("prompt_text")) != "":
			return fail("completed event %s still offers an interaction" % ev.id)
	_note("scene matches the loaded state (chests, groups, gates, events)")
	return true


func _open_lootboxes(scene: SafeRoomScene) -> bool:
	var layer: Node = scene.open_lootboxes()
	var n: int = 0
	while is_instance_valid(layer) and not layer.is_queued_for_deletion():
		match StringName(str(layer.get("state"))):
			&"select":
				if (layer.call("pending") as Dictionary).is_empty():
					layer.call("finish")
				else:
					layer.call("tap")
			&"tease":
				layer.call("tap")
			&"reveal":
				layer.call("reveal_all")
			&"done":
				if (layer.call("pending") as Dictionary).is_empty():
					layer.call("finish")
				else:
					layer.call("next_box")
		n += 1
		if n > SAFE_BUDGET:
			return fail("lootbox opening did not finish (state %s)" % str(layer.get("state")))
		await get_tree().process_frame
	if not Game.state.pending_lootboxes.is_empty():
		return fail("%d lootboxes still pending after the opening" % Game.state.pending_lootboxes.size())
	_note("lootboxes opened (%d so far)" % boxes_opened)
	return true


## Vending (item button → quantity → confirm, the menu's own path): shopping_list() of this safe room.
func _shop(scene: SafeRoomScene) -> bool:
	var plan: Array[Array] = shopping_list(scene.safe_room_id)
	if plan.is_empty():
		return true
	var layer: Node = scene.open_vending()
	await get_tree().process_frame
	for entry: Array in plan:
		var item_id: String = str(entry[0])
		var b: Button = layer.find_child("Item_" + item_id, true, false) as Button
		if b == null:
			return fail("vending: no button for %s" % item_id)
		b.pressed.emit()
		layer.call("set_qty", int(entry[1]))
		if not bool(layer.call("confirm")):
			return fail("vending: buying %d× %s failed" % [int(entry[1]), item_id])
		_note("bought %d× %s" % [int(entry[1]), item_id])
	layer.call("close")
	return await _wait(func() -> bool: return not is_instance_valid(layer) or layer.is_queued_for_deletion(), 60,
		"vending closed")


## [[item_id, qty], …] the bot buys in `safe_room_id` with the current credits: affordable equipment upgrades in stock
## order, then bandages up to BANDAGES_WANTED.
func shopping_list(safe_room_id: String) -> Array[Array]:
	var out: Array[Array] = []
	var credits: int = Game.state.inventory.credits
	var stock: PackedStringArray = Shop.stock(Game.floor_def(), safe_room_id)
	for item_id: String in stock:
		var def: ItemDef = DB.item(item_id)
		if def.type == "consumable" or def.price <= 0 or def.price > credits:
			continue
		if _upgrade_for(def) != "":
			out.append([item_id, 1])
			credits -= def.price
	if stock.has("itm_bandage"):
		var price: int = Shop.price_of(DB.data, "itm_bandage")
		var want: int = mini(BANDAGES_WANTED - Game.state.inventory.count("itm_bandage"), credits / maxi(1, price))
		if want > 0:
			out.append(["itm_bandage", want])
	return out


## Member id that would equip `def` as an upgrade ("" = nobody).
func _upgrade_for(def: ItemDef) -> String:
	if not EQUIP_SLOTS.has(def.type):
		return ""
	for m: PartyMember in Game.state.party:
		if not def.equip_by.is_empty() and not def.equip_by.has(m.id):
			continue
		if item_score(def.id) > item_score(str(m.equipment.get(def.type, ""))):
			return m.id
	return ""


## Equips the best owned item per member and slot (Game.equip, the equipment menu's path).
func equip_best() -> void:
	for m: PartyMember in Game.state.party:
		for slot: String in EQUIP_SLOTS:
			var best: String = ""
			var best_score: int = item_score(str(m.equipment.get(slot, "")))
			for item_id: String in Game.state.inventory.ids_of_type(DB.data, slot):
				var def: ItemDef = DB.item(item_id) if DB.has_id("items", item_id) else null
				if def == null or def.type != slot or (not def.equip_by.is_empty() and not def.equip_by.has(m.id)):
					continue
				if item_score(item_id) > best_score:
					best_score = item_score(item_id)
					best = item_id
			if best != "" and Game.equip(m.id, slot, best):
				_note("%s equips %s" % [m.id, best])


## Sum of the item's stat bonuses (+1 so a stat-less accessory beats an empty slot); "" = -1.
static func item_score(item_id: String) -> int:
	if item_id == "" or not DB.has_id("items", item_id):
		return -1
	var s: int = 1
	for v: Variant in DB.item(item_id).stats.values():
		s += int(v)
	return s


func _save(scene: SafeRoomScene) -> bool:
	var before: int = _saved_events
	var layer: Node = scene.open_save()
	if layer == null:
		return fail("safe room offers no save")
	await get_tree().process_frame
	var sel: Node = null
	for c: Node in layer.get_children():
		if c.has_method("choose"):
			sel = c
	if sel == null:
		return fail("save: no slot selection")
	sel.call("choose", SAVE_SLOT)
	await get_tree().process_frame
	if _saved_events == before:
		var confirm: Node = _find_method(sel, "answer")
		if confirm == null:
			return fail("save: slot %d neither saved nor asked to overwrite" % SAVE_SLOT)
		confirm.call("answer", true)
	if not await _wait(func() -> bool: return _saved_events > before, 120, "game_saved"):
		return false
	saves += 1
	roundtrip_hash = StateHash.of(Game.state)
	_note("saved slot %d in %s" % [SAVE_SLOT, scene.safe_room_id])
	return true


## "Zum Titel" → "Fortsetzen" (Save.load_slot + routing) right after the save: the loaded state must hash like the
## saved one, and the exploration must bring Kai back into that safe room (check_scene_state after leaving it).
func _save_load_roundtrip() -> bool:
	phase = "save/load roundtrip"
	var want: Dictionary = StateHash.hash_input(Game.state)
	Router.goto(Router.SCENE_TITLE)
	if not await _wait(func() -> bool: return Router.current is TitleScreen and not Router.busy, 300, "title"):
		return false
	var title: TitleScreen = Router.current as TitleScreen
	if not title.menu_ids().has("continue"):
		return fail("the title offers no \"Fortsetzen\" after saving")
	title.activate("continue")
	if StateHash.of(Game.state) != roundtrip_hash:
		return fail("loaded state differs from the saved one: %s" % dict_diff(want, StateHash.hash_input(Game.state)))
	_note("save → title → Fortsetzen: StateHash identical")
	_verify_scene = true
	return await _wait(func() -> bool: return Router.current is SafeRoomScene and not Router.busy, 600,
		"safe room after loading")


static func _find_method(root: Node, method: String) -> Node:
	for c: Node in root.get_children():
		if c.has_method(method):
			return c
		var deeper: Node = _find_method(c, method)
		if deeper != null:
			return deeper
	return null


## "key: a != b" for the differing (nested) keys of two dictionaries.
static func dict_diff(a: Dictionary, b: Dictionary, prefix: String = "") -> String:
	var parts: PackedStringArray = []
	var keys: Array = a.keys()
	for k: Variant in b.keys():
		if not keys.has(k):
			keys.append(k)
	keys.sort_custom(func(x: Variant, y: Variant) -> bool: return str(x) < str(y))
	for k: Variant in keys:
		var va: Variant = a.get(k, null)
		var vb: Variant = b.get(k, null)
		if va is Dictionary and vb is Dictionary:
			var sub: String = dict_diff(va, vb, prefix + str(k) + ".")
			if sub != "":
				parts.append(sub)
		elif JSON.stringify(va) != JSON.stringify(vb):
			parts.append("%s%s: %s != %s" % [prefix, str(k), JSON.stringify(va).left(80), JSON.stringify(vb).left(80)])
	return "; ".join(parts)


# ======================================================================================================================
# Stairs → summary → credits → title
# ======================================================================================================================

func _after_stairs() -> bool:
	phase = "floor summary"
	if not await _wait(func() -> bool: return Router.current is FloorSummary and not Router.busy, 300,
			"floor summary"):
		return false
	var fs: FloorSummary = Router.current as FloorSummary
	summary = fs.summary.duplicate()
	_note("floor summary %s" % JSON.stringify(summary))
	fs.continue_pressed()
	phase = "credits"
	if not await _wait(func() -> bool: return Router.current != null and not Router.busy \
			and Router.current.scene_file_path == Router.SCENE_CREDITS, 300, "credits"):
		return false
	if Game.state.floor_run == null or Game.state.floor_run.index != 2:
		return fail("after the summary the run is not on floor 2 (autosave stand)")
	var sum2: Dictionary = Save.slot_summary(SAVE_SLOT)
	if int(sum2.get("floor_index", 0)) != 2 or str(sum2.get("location", "")) != "start":
		return fail("autosave of slot %d is not on floor 2: %s" % [SAVE_SLOT, JSON.stringify(sum2)])
	if not await _wait(func() -> bool: return Router.current is TitleScreen and not Router.busy, CREDITS_BUDGET,
			"title after the credits"):
		return false
	phase = "continue into the credits"
	var title: TitleScreen = Router.current as TitleScreen
	if not title.menu_ids().has("continue"):
		return fail("no \"Fortsetzen\" after the autosave")
	title.activate("continue")
	if not await _wait(func() -> bool: return Router.current != null and not Router.busy \
			and Router.current.scene_file_path == Router.SCENE_CREDITS, 300, "credits after Fortsetzen (floor 2)"):
		return false
	Router.current.call("finish")
	return await _wait(func() -> bool: return Router.current is TitleScreen and not Router.busy, 300, "title")


# ======================================================================================================================
# Party upkeep
# ======================================================================================================================

## Field heal items on members below HEAL_ITEM_BELOW (Game.use_item, the inventory menu's path); Krawumm for MP.
func _use_heal_items() -> void:
	for m: PartyMember in Game.state.party:
		var sb: StatBlock = Progression.total_stats(m, DB.data)
		var max_hp: int = sb.values[StatBlock.Stat.HP]
		for item_id: String in HEAL_ITEMS:
			while m.hp < max_hp * HEAL_ITEM_BELOW and Game.state.inventory.has(item_id):
				if not Game.use_item(item_id, m.id):
					break
				_note("used %s on %s" % [item_id, m.id])
		var max_mp: int = sb.values[StatBlock.Stat.MP]
		if m.mp < max_mp * 0.25 and Game.state.inventory.has("itm_energy_krawumm"):
			if Game.use_item("itm_energy_krawumm", m.id):
				_note("used itm_energy_krawumm on %s" % m.id)


## Party HP or MP ratio (sum / sum of maxima).
static func party_ratio(what: String) -> float:
	var cur: int = 0
	var mx: int = 0
	for m: PartyMember in Game.state.party:
		var sb: StatBlock = Progression.total_stats(m, DB.data)
		if what == "mp":
			cur += m.mp
			mx += sb.values[StatBlock.Stat.MP]
		else:
			cur += m.hp
			mx += sb.values[StatBlock.Stat.HP]
	return float(cur) / float(maxi(1, mx))


func _levels() -> Array[int]:
	var out: Array[int] = []
	for m: PartyMember in Game.state.party:
		out.append(m.level)
	return out


# ======================================================================================================================
# Report
# ======================================================================================================================

## M.O.D. beats of GDD §1.4 that every run must have heard: floor_start once and only once the countdown runs (B2),
## first_fight, safe_room_enter, Mopsula scene 1 (B3), the Hausmeister intro (B5), stairs_found (B6), floor_end (B8).
func check_story_beats() -> bool:
	phase = "story beats"
	var starts: int = 0
	for t: String in mod_tags:
		if t.begins_with("floor_start@"):
			starts += 1
			if t != "floor_start@countdown":
				return fail("floor_start was said before the countdown started (%s)" % t)
	if starts != 1:
		return fail("floor_start was said %d× (expected once, when the countdown starts)" % starts)
	for tag: String in REQUIRED_BEATS:
		var found: bool = false
		for t: String in mod_tags:
			found = found or t.get_slice("@", 0) == tag
		if not found:
			return fail("M.O.D. beat '%s' never played" % tag)
	return true


## The GDD §13 numbers of this run.
func stats() -> Dictionary:
	var regular: Array[Dictionary] = []
	var strays: int = 0
	var groups: PackedStringArray = []
	for b: Dictionary in battles:
		var gid: String = str(b["group"])
		if gid.get_slice("_", 1).begins_with("s"):
			strays += 1
		elif gid != "" and not bool(b["boss"]) and str(b["outcome"]) == "victory" and not groups.has(gid):
			groups.append(gid)
		if not bool(b["boss"]) and gid != "f1_g0":
			regular.append(b)
	var pt: Array[int] = []
	var tt: Array[int] = []
	var hp: Array[int] = []
	for b: Dictionary in regular:
		pt.append(int(b["party_turns"]))
		tt.append(int(b["turns"]))
		hp.append(int(b["hp_loss_pct"]))
	var boss_turns: Dictionary = {}
	for b: Dictionary in battles:
		if bool(b["boss"]):
			boss_turns[str(b["enc"])] = int(b["party_turns"])
	var show: ShowState = Game.state.show if Game.state != null else null
	return {
		"floor_time_used_sec": int(summary.get("time_used_sec", 0)),
		"floor_time_left_sec": int(summary.get("time_left_sec", 0)),
		"battles": battles.size(), "regular_battles": regular.size(), "strays": strays,
		"groups_defeated": groups.size(), "deaths": deaths,
		"party_turns_median": median(pt), "turns_median": median(tt), "hp_loss_pct_median": median(hp),
		"boss_levels": boss_levels, "boss_party_turns": boss_turns, "level_end": _levels(),
		"credits_earned": credits_earned, "credits_by_source": credits_by_source, "credits_spent": credits_spent,
		"strays_spawned": strays_spawned, "followers_battles": _sum_key("followers"),
		"boxes_earned": boxes_earned, "boxes_opened": boxes_opened,
		"achievements": show.achievements.size() if show != null else 0,
		"followers": show.followers if show != null else 0,
		"viewers_peak": int(summary.get("viewers_peak", 0)), "kills": int(summary.get("kills", 0)),
		"purchases": purchases, "saves": saves, "teleports": teleports, "direct_interactions": direct_interactions,
		"forced_encounters": forced_encounters, "replay_checks": replay_checks, "frames": frames,
		"mod_tags": mod_tags,
	}


## Battles against stray groups so far.
func strays_fought() -> int:
	var n: int = 0
	for b: Dictionary in battles:
		if str(b["group"]).get_slice("_", 1).begins_with("s"):
			n += 1
	return n


func _sum_key(key: String) -> int:
	var t: int = 0
	for b: Dictionary in battles:
		t += int(b.get(key, 0))
	return t


static func median(values: Array[int]) -> float:
	if values.is_empty():
		return 0.0
	var s: Array[int] = values.duplicate()
	s.sort()
	var n: int = s.size()
	return float(s[n / 2]) if n % 2 == 1 else (s[n / 2 - 1] + s[n / 2]) / 2.0


func ok_line() -> String:
	var lv: Array[int] = _levels() if Game.state != null else [0, 0]
	return "FULLRUN: OK floor_time=%d battles=%d level=%s deaths=%d frames=%d" % [int(summary.get("time_used_sec", 0)),
		battles.size(), "/".join(PackedStringArray(lv.map(func(x: int) -> String: return str(x)))), deaths, frames]


func _finish_ok() -> void:
	if finished:
		return
	finished = true
	result_code = 0
	result_line = ok_line()
	UiUtil.release_move_actions()
	if not dry_run:
		print("FULLRUN: stats ", JSON.stringify(stats()))
		print(result_line)
		clear_saves()
		get_tree().quit(0)


## Ends the run with the failure line (check.sh / fullrun.sh ERR_RE); always returns false.
func fail(reason: String) -> bool:
	if finished:
		return false
	finished = true
	UiUtil.release_move_actions()
	result_code = 1
	result_line = "Assertion failed: FULLRUN failed in %s: %s" % [phase, reason]
	if not dry_run:
		for l: String in _log.slice(maxi(0, _log.size() - 8)):
			print("FULLRUN: (last) ", l)
		printerr(result_line)
		get_tree().quit(1)
	return false


func state_text() -> String:
	var cur: Node = Router.current
	var s: String = "screen=%s busy=%s" % [_screen_name(cur), str(Router.busy)]
	if cur is ExplorationScene:
		var ex: ExplorationScene = cur as ExplorationScene
		s += " cell=%s modal=%s pending=%s" % [str(ex.get_player_cell()), str(ex.is_modal()),
			str(ex.is_encounter_pending())]
	if Game.state != null and Game.state.floor_run != null:
		s += " time_left=%d" % int(Game.time_left())
	return s


func _note(text: String) -> void:
	var line: String = "[%d] %s" % [frames, text]
	_log.append(line)
	if not dry_run:
		print("FULLRUN: ", line)


func _wait(cond: Callable, budget: int, what: String) -> bool:
	var n: int = 0
	while not finished and not bool(cond.call()):
		n += 1
		if n > budget:
			return fail("waited %d frames for %s (%s)" % [budget, what, state_text()])
		await get_tree().process_frame
	return not finished


func _reasons_text() -> String:
	var keys: Array = hype_reasons.keys()
	keys.sort()
	var parts: PackedStringArray = []
	for k: Variant in keys:
		parts.append("%s %+d" % [str(k), roundi(float(hype_reasons[k]))])
	return ", ".join(parts)


static func _v(p: Vector3) -> String:
	return "(%.1f, %.1f)" % [p.x, p.z]


func _ex() -> ExplorationScene:
	return Router.current as ExplorationScene


static func _screen_name(n: Node) -> String:
	if n == null:
		return "null"
	return n.scene_file_path.get_file() if n.scene_file_path != "" else str(n.name)


func _focus_name(ex: ExplorationScene) -> String:
	var f: Node = ex.focused_interactable()
	return str(f.get("interact_id")) if f != null else "none"


func _on_battle_started(encounter_id: String, is_boss: bool) -> void:
	if Game.replaying:
		return
	hype_reasons = {}
	_hype_start = roundi(Game.state.show.hype) if Game.state != null and Game.state.show != null else 0
	if is_boss and Game.state != null:
		boss_levels[encounter_id] = _levels()
		if Game.state.floor_run != null and DB.floor_def(Game.state.floor_run.index) != null \
				and DB.floor_def(Game.state.floor_run.index).floor_boss == encounter_id:
			floor_boss_attempts += 1


func _on_credits_changed(_credits: int, delta: int) -> void:
	if Game.replaying:
		return
	if delta > 0:
		credits_earned += delta
		var src: String = "battle" if Router.current is BattleScene else ("safe_room" if Router.current is SafeRoomScene
			else "explore")
		credits_by_source[src] = int(credits_by_source.get(src, 0)) + delta
	elif delta < 0:
		credits_spent -= delta
