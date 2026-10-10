class_name RunSim extends RefCounted
## Deterministic run simulation in ticks (02_TECH §7.1; thin variant 05 CR-6). No autoloads, no SceneTree, no clock:
## the caller decides when time passes (Game._process accumulates frame delta into whole ticks and calls step(1) per
## tick; a verifier/bot calls step()/apply() directly). 1 tick = 1/30 s of exploration time (timer_mode explore_only).
##
## step(n) — per tick, in this order (02_TECH §7.1):
##   1 timer: floor_run.time_left_ticks −1, stats.time_used_ticks +1 → TIMER_SECOND {"seconds"} on a change of the
##     whole second, TIMER_WARNING {"seconds"} when crossing a FloorDef.timer_warnings value (once, floor_run.warned),
##     TIMER_EXPIRED {} at 0 (the clock stops; the rest of that tick is skipped)
##   2 every 30 ticks of floor time: stat explore_seconds_since_battle +1 → EXPLORE_TICK {"seconds_since_battle"}
##   3 floor_run.decay_ticks +1; at ShowModel.HYPE_DECAY_TICKS: reset, show.hype = ShowModel.decay_step(hype)
##     → HYPE {"hype", "delta"} (only if it changed)
##   4 stray spawners: zone without living stray → spawner_ticks[zone] +1; at interval_sec × 30 → group
##     "f<i>_s<stray_counter>", encounter = pool[SeedUtil.make_rng(SeedUtil.derive(floor_run.seed, "stray",
##     stray_counter)).randi_range(0, size − 1)], floor_run.strays[group] = {"zone", "enc"}, stray_counter +1,
##     ticks reset → STRAY_DUE {"zone", "group_id", "encounter_id"}
##   5 Sponsor-Fenster (SponsorWindows.tick, 05 §6.13): the open window counts down, the periodic countdown runs
##     → SPONSOR_WINDOW_OPENED {"window"} / SPONSOR_WINDOW_CLOSED {"id", "kind", "reason"}
## Idle ticks: while floor_run.location is a safe room (not &"start") a tick only runs step 5 with explore = false —
## the run clock keeps ticking in safe rooms (Sponsor-Fenster max_sec), the floor timer, hype decay, pacifist
## counter, strays and the periodic countdown do not (explore_only: the floor timer runs in the exploration only).
## Game steps idle ticks only while the safe room scene is shown and windows are tracked (Game.is_idle_ticking).
## The clock only runs while the floor timer runs: floor_run.timer_started, time left > 0, no battle started by
## apply(), no floor finished by "descend" — otherwise step() does nothing and tick() does not advance (Game calls it
## only in that situation anyway, so live run and replay tick identically).
##
## apply(cmd) — the recorded commands of 02_TECH §3.4 (Command.TYPES) applied with the core rules only: battles via
## BattleBridge/BattleState (enemy and party commands come from the log), chests/lootboxes via LootRoller, shop,
## equipment, items, floor events (FloorEvent), safe rooms, scenes, flags, difficulty, gifts (GiftApplier outside
## battles, BattleState.apply_gift inside). RNG streams are consumed exactly like the live flow (Game.next_seed
## "battle" + "show" per encounter, "lootbox", "gift"; event/stray seeds from the floor seed, chest seeds from the
## floor's loot_seed, 05 CR-11). What it does NOT
## contain are the reactions of the Show facade (hype/followers from battle events, achievements, milestones, sponsor
## gifts, M.O.D.); a RunSim-only run is therefore a "core run": RunSim.replay of its log reproduces it bit for bit
## (05 §11.4 test_m8_replay), while Game.replay_log reproduces complete live runs.
##
## With `quest` set, apply() feeds it the quest events the core can tell on its own (same shapes as the Game adapter,
## CR-4): battle_started (encounter), enemy_killed (KO of an enemy unit), boss_defeated (boss victory),
## floor_completed (descend), plus the detail events zones (first room visits) and boss_hp (boss damage). Achievement
## and metric events need the Show facade and are not part of a core run.
## With `run_log` set, apply() records every accepted command (k = tick(), cmd id 0 for gifts, else 1, 2, …) and the
## clock writes checkpoints: one every CHECKPOINT_TICKS and one after each battle / descend (request_checkpoint() for a
## Game-driven sim, which records through Game.record instead of apply()), always taken when the clock leaves a tick
## (state after all commands with k' <= k, 05 §10.6), plus close() at the end.
## Event rules (rules.leagues / rules.gifts) are stored in state.flags["live"] on construction, so the gift policy
## of the run (Pur-Liga: no external gifts) holds for every gift path (GiftPolicy.check with the run counters).
## External gifts are checked again when they are applied — the core check is authoritative (05 §6.10, L4/L5):
## gift_refusal() (duplicate id, GiftPolicy.check incl. league/caps/effect factor/deliver_by_tick, max_per_battle).
## A refused gift changes nothing, is not recorded and is listed in `rejected_cmds`; RunSim.replay reports every
## refusal in "errors", so a verifier fails a log that smuggles in gifts. An accepted external gift is stamped with
## the id of its Sponsor-Fenster ("sponsor_window") before it is recorded.
## Sponsor-Fenster triggers (SponsorWindows): "floor" (closes, countdown restarts), first "room" of a boss cell
## (Boss-Countdown), "safe_room" / "safe_room_exit", "sponsor_window" {"op": "dev_open", "sec", "slots"} (QA, only with
## rules.sponsor_windows.dev_open — refused like a gift otherwise). Game calls the same sponsor_*() functions from its
## recording methods, so live run, Game.replay_log and RunSim.replay open and close the same windows at the same ticks.

const TICKS_PER_SEC: int = 30          # == Game.TICKS_PER_SEC == FloorRun.TICKS_PER_SEC
const CHECKPOINT_TICKS: int = 300      # 05 §3.3 Nr. 8: checkpoint every 300 ticks
const EASY_TIMER_PM: int = 1500        # Balance.EASY_TIMER_MULT (1.5) in per mille (test_m8_run_sim keeps them in sync)
const EVENTS_PATH: String = "res://data/events.json"

var data: GameData = null
var state: GameState = null
var rules: Dictionary = {}
var run_log: RunLog = null             # optional: records applied commands + checkpoints (headless driver)
var battle: BattleState = null         # battle started by apply({"t": "encounter"}) (RunSim-driven runs only)
var quest: QuestTracker = null         # optional: fed by apply() with the core quest events (see _quest_feed)
var last_action_events: Array[ActionEvent] = []   # ActionEvents of the last apply() (battle start/commands/gifts)
## Commands refused by the core rules (gift policy, HeroRules.check for "hero" — 06 §1.7): {"k", "t", "gift_id" (the
## gift id, or the hero id of a refused "hero"), "reason"} in order.
var rejected_cmds: Array[Dictionary] = []

var _tick: int = 0
var _cmd_id: int = 0
var _over: bool = false                # timer expired or battle lost: the run is over
var _floor_done: bool = false          # "descend" applied; the clock waits for the next "floor"
var _checkpoint_due: bool = false
var _battle_external: int = 0          # external gifts applied in the running battle (max_per_battle)
var _layout: FloorLayout = null
var _layout_key: String = ""


func _init(p_data: GameData, p_state: GameState, p_rules: Dictionary) -> void:
	data = p_data
	state = p_state
	rules = CanonicalJson.normalize(p_rules)
	if state != null and not rules.is_empty():
		_store_run_rules()


## n ticks; per tick: 1 timer (TIMER_SECOND/TIMER_WARNING/TIMER_EXPIRED), 2 every 30 ticks EXPLORE_TICK,
## 3 hype decay (HYPE), 4 stray spawners (STRAY_DUE). See 02_TECH §7.1. step(1) × n ≡ step(n).
func step(n: int) -> Array[ExploreEvent]:
	var out: Array[ExploreEvent] = []
	for _i in maxi(0, n):
		if not is_clock_running():
			break
		_checkpoint_at_tick_end()
		_tick += 1
		if _tick_once(out):
			break
	return out


## M8 replay of recorded explore commands (02_TECH §3.4 shapes, Command.validate). Invalid commands are refused with a
## warning (nothing recorded, nothing changes); so are commands after the run ended and external gifts the core
## refuses (gift_refusal → rejected_cmds).
func apply(cmd: Dictionary) -> Array[ExploreEvent]:
	var out: Array[ExploreEvent] = []
	last_action_events = []
	var err: String = Command.validate(cmd)
	if err != "":
		push_warning("[RunSim] rejected command: " + err)
		return out
	if _over:
		push_warning("[RunSim] run is over, command '%s' ignored" % str(cmd.get("t", "")))
		return out
	var c: Dictionary = CanonicalJson.normalize(cmd)
	if str(c["t"]) == "gift":
		var refusal: String = gift_refusal(c["gift"])
		if refusal != "":
			var gid: String = str((c["gift"] as Dictionary).get("gift_id", ""))
			push_warning("[RunSim] gift '%s' refused: %s" % [gid, refusal])
			rejected_cmds.append({"k": _tick, "t": "gift", "gift_id": gid, "reason": refusal})
			return out
		_stamp_window(c["gift"])
	if str(c["t"]) == "sponsor_window" and not SponsorWindows.dev_allowed(state, rules, int(c["sec"]),
			int(c["slots"])):
		push_warning("[RunSim] sponsor_window refused (rules.sponsor_windows.dev_open / not tracked)")
		rejected_cmds.append({"k": _tick, "t": "sponsor_window", "gift_id": "", "reason": "not_allowed"})
		return out
	var hero_refusal: String = HeroRules.check(state, str(c["id"])) if str(c["t"]) == "hero" else ""  # 06 package A
	if hero_refusal != "":
		push_warning("[RunSim] hero '%s' refused: %s" % [str(c["id"]), hero_refusal])
		rejected_cmds.append({"k": _tick, "t": "hero", "gift_id": str(c["id"]), "reason": hero_refusal})
		return out
	if run_log != null:
		var cmd_id: int = 0
		if not Command.is_external(c):
			_cmd_id += 1
			cmd_id = _cmd_id
		run_log.add_cmd(_tick, c, cmd_id)
	match str(c["t"]):
		"floor":
			_apply_floor(int(c["floor"]))
			out.append_array(sponsor_floor())
		"encounter":
			_apply_encounter(str(c["enc"]), int(c["adv"]), str(c["group"]), out)
		"battle":
			_apply_battle(c["cmd"], out)
		"gift":
			_apply_gift(c["gift"], out)
		"room":
			_apply_room(Vector2i(int(c["cell"][0]), int(c["cell"][1])), out)
		"chest":
			_apply_chest(str(c["id"]), out)
		"gate":
			_apply_gate(str(c["key"]), out)
		"lootbox":
			_apply_lootbox(str(c["box"]))
		"buy":
			Shop.buy(state, data, str(c["item"]), int(c["qty"]))
		"sell":
			Shop.sell(state, data, str(c["item"]), int(c["qty"]))
		"equip":
			var m: PartyMember = state.member(str(c["member"]))
			if m != null:
				Progression.equip(m, state.inventory, data, str(c["slot"]), str(c["item"]))
		"use_item":
			Progression.use_item(state, data, str(c["item"]), str(c["member"]))
		"rest":
			Progression.full_heal(state, data)
		"event":
			_apply_event(str(c["id"]), str(c["choice"]), out)
		"safe_room":
			_apply_safe_room(str(c["id"]))
			out.append_array(sponsor_safe_room(str(c["id"])))
		"safe_room_exit":
			if state.floor_run != null:
				state.floor_run.location = &"start"
			out.append_array(sponsor_safe_room_exit())
		"sponsor_window":
			out.append_array(sponsor_dev_open(int(c["sec"]), int(c["slots"])))
		"scene":
			if data != null and data.has_id("scenes", str(c["id"])):
				var sc: SceneDef = data.scene_def(str(c["id"]))
				state.flags["scene_" + sc.id] = true
				if sc.set_flag != "":
					state.flags[sc.set_flag] = true
		"flag":
			state.flags[str(c["key"])] = c["value"]
		"difficulty":
			_apply_difficulty(StringName(str(c["to"])))
		"hero":                                    # 06 package A: HeroRules.check passed above
			HeroRules.set_hero(state, str(c["id"]))
		"descend":
			if state.floor_run != null:
				_floor_done = true
				_checkpoint_due = true
				var fi: int = state.floor_run.index
				out.append(ExploreEvent.make(ExploreEvent.Type.FLOOR_COMPLETED, _tick, {"floor": fi}))
				_quest_feed({"type": "floor_completed", "floor": state.floor_run.index})
	return out


## Ticks since run start.
func tick() -> int:
	return _tick


# --- additions ----------------------------------------------------------------------------------------------------

## True while step() advances the clock (see class doc).
func is_clock_running() -> bool:
	return state != null and state.floor_run != null and state.floor_run.timer_started \
		and state.floor_run.time_left_ticks > 0 and not _over and not _floor_done and battle == null


## The run ended (timer expired or battle lost).
func is_over() -> bool:
	return _over


## Steps tick by tick up to `k` (stops early if the clock stops). Returns all events.
func advance_to(k: int) -> Array[ExploreEvent]:
	var out: Array[ExploreEvent] = []
	while _tick < k:
		var before: int = _tick
		out.append_array(step(1))
		if _tick == before:
			break
	return out


## Same as Game.next_seed: state.rng_counter += 1; SeedUtil.derive(state.seed, purpose, state.rng_counter).
func next_seed(purpose: String) -> int:
	state.rng_counter += 1
	return SeedUtil.derive(state.seed, purpose, state.rng_counter)


## "" or why the core refuses the external gift `g` now (05 §6.10: the check at application is authoritative):
## its id was already applied in this run → duplicate; GiftPolicy.check with the run counters (flags.live), the run's
## rules and the current tick (deliver_by_tick) → league_pur | not_accepting | deadline_missed | effect_mismatch |
## cap_reached | chest_blocked; in battle more than rules.gifts.max_per_battle external gifts → cap_reached.
## System gifts are never refused. Read-only (the state is not touched).
func gift_refusal(g: Dictionary) -> String:
	if not Gift.is_external(g) or state == null:
		return ""
	var live: Variant = state.flags.get("live", {})
	var run: Dictionary = (live as Dictionary).duplicate() if live is Dictionary else {}
	var ids: Variant = run.get("gift_ids", [])
	if ids is Array and (ids as Array).has(str(g.get("gift_id", ""))):
		return "duplicate"
	run["tick"] = _tick
	var reason: String = GiftPolicy.check(run, g, rules)
	if reason != "":
		return reason
	if battle != null and not battle.is_finished():
		var eff: Dictionary = rules if not rules.is_empty() else {"gifts": run.get("gift_rules", {})}
		if not GiftPolicy.can_deliver_in_battle(_battle_external, eff):
			return "cap_reached"
	return ""


## The next tick end writes a checkpoint (like after a battle / descend applied here). Game calls it after its own
## battles and floor ends, because a Game-driven sim never sees those commands in apply().
func request_checkpoint() -> void:
	_checkpoint_due = true


# --- Sponsor-Fenster (05 §6.13) -------------------------------------------------------------------------------------
# Game calls these from its recording methods (start_floor, visit_room, enter/leave_safe_room,
# open_dev_sponsor_window) and dispatches the events; apply() calls them for the same commands.

## Floor start: closes the open window, restarts the periodic countdown and the safe rooms of the floor.
func sponsor_floor() -> Array[ExploreEvent]:
	return _sponsor_events(SponsorWindows.on_floor(state, rules))


## First entry of `cell` (a boss cell opens the Boss-Countdown).
func sponsor_room(cell: Vector2i) -> Array[ExploreEvent]:
	var layout: FloorLayout = _current_layout()
	var rc: RoomCell = layout.cell_at(cell) if layout != null else null
	if rc == null:
		return []
	return _sponsor_events(SponsorWindows.on_room(state, rules, int(rc.kind)))


func sponsor_safe_room(room_id: String) -> Array[ExploreEvent]:
	return _sponsor_events(SponsorWindows.on_safe_room_enter(state, rules, room_id))


func sponsor_safe_room_exit() -> Array[ExploreEvent]:
	return _sponsor_events(SponsorWindows.on_safe_room_exit(state, rules))


## QA window (rules.sponsor_windows.dev_open); [] when not allowed.
func sponsor_dev_open(sec: int, slots: int) -> Array[ExploreEvent]:
	return _sponsor_events(SponsorWindows.dev_open(state, rules, sec, slots))


## SponsorWindows.view of the run (UI, debug, protocol).
func sponsor_window() -> Dictionary:
	return SponsorWindows.view(state, rules)


## Quest detail event {"type": "zones", "explored", "total"} of a floor: distinct zones of the visited cells of a
## handbuilt layout; {} for a layout without zones (procedural floors). Shared by RunSim and the Game quest adapter.
static func zones_event(fr: FloorRun, layout: FloorLayout) -> Dictionary:
	if fr == null or layout == null or layout.zones.is_empty():
		return {}
	var seen: Dictionary = {}
	for c: Vector2i in fr.visited:
		var rc: RoomCell = layout.cell_at(c)
		if rc != null and layout.zones.has(rc.zone):
			seen[rc.zone] = true
	return {"type": "zones", "explored": seen.size(), "total": layout.zones.size()}


## Ends a recorded run: final checkpoint + run_log.result {"cause", "final_hash", "ticks"} (+ extra, e.g. "score").
## Returns the final state hash.
func close(cause: String, extra: Dictionary = {}) -> String:
	var h: String = StateHash.of(state)
	if run_log != null:
		run_log.add_checkpoint(_tick, h)
		var res: Dictionary = {"cause": cause, "final_hash": h, "ticks": _tick}
		res.merge(CanonicalJson.normalize(extra), true)
		run_log.result = res
	return h


## Replays a log with a fresh GameState from its header (seed/run_seed, slot, player_name, difficulty) through
## RunSim alone (no autoloads — what a verifier runs): before each command the clock steps to its tick, checkpoints
## with a smaller tick are compared on the way. p_rules / p_quest: the event rules / quest; {} → the event of
## header.event_id from EVENTS_PATH (EventCatalog, validated against p_data) — never from the log itself; no event_id
## → none (campaign). An unknown event is an error (no replay without its rules).
## → {"final_hash": String, "result": {"ticks", "cmds", "over", "floor", "quest_complete", "quest_progress_ppm"},
##    "mismatch_at": int (first failing checkpoint index, -1 = none), "errors": PackedStringArray (log schema / id
##    problems, entries the RunLog rejected, gifts the core refused, unknown event) — a verifier needs errors == []}
static func replay(p_data: GameData, p_log: RunLog, p_rules: Dictionary = {}, p_quest: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {"final_hash": "", "result": {}, "mismatch_at": -1, "errors": PackedStringArray()}
	if p_log == null:
		return out
	var errors: PackedStringArray = p_log.validate()
	out["errors"] = errors
	if p_log.rejected > 0:
		errors.append("log: %d entries rejected (out of tick order, duplicate / invalid cmd ids, malformed)"
			% p_log.rejected)
	var h: Dictionary = p_log.header
	var r: Dictionary = p_rules
	var q: Dictionary = p_quest
	var event_id: String = str(h.get("event_id", ""))
	if (r.is_empty() or q.is_empty()) and event_id != "":
		var cat: EventCatalog = EventCatalog.new()
		cat.data = p_data
		cat.load_file(EVENTS_PATH)
		var def: EventDef = cat.get_event(event_id)
		if def == null:
			errors.append("header: event '%s' not found in %s (no replay without its rules)" % [event_id, EVENTS_PATH])
			out["errors"] = errors
			return out
		if r.is_empty():
			r = def.rules
		if q.is_empty():
			q = def.quest
	var seed_v: Variant = h.get("seed", h.get("run_seed", 1))
	var st: GameState = GameState.create_new(p_data, int(h.get("slot", 0)), str(h.get("player_name", "Kai")),
		int(seed_v) if typeof(seed_v) == TYPE_INT or typeof(seed_v) == TYPE_FLOAT else 1,
		StringName(str(h.get("difficulty", "prime"))))
	var sim: RunSim = RunSim.new(p_data, st, r)
	if not q.is_empty():
		sim.quest = QuestTracker.from_def(q)
	var cps: Array[Dictionary] = p_log.checkpoints()
	var cp: int = 0
	var cmds: Array[Dictionary] = p_log.cmds()
	for entry: Dictionary in cmds:
		var k: int = int(entry.get("k", 0))
		while cp < cps.size() and int(cps[cp]["k"]) < k:
			cp = sim._compare_checkpoint(cps, cp, out)
		sim.advance_to(k)
		sim.apply(entry.get("c", {}))
	while cp < cps.size():
		cp = sim._compare_checkpoint(cps, cp, out)
	for rc: Dictionary in sim.rejected_cmds:
		errors.append("k %d: %s '%s' refused by the core (%s)" % [int(rc["k"]), str(rc["t"]), str(rc["gift_id"]),
			str(rc["reason"])])
	out["errors"] = errors
	out["final_hash"] = StateHash.of(st)
	out["result"] = {"ticks": sim.tick(), "cmds": cmds.size(), "over": sim.is_over(),
		"floor": st.floor_run.index if st.floor_run != null else 0,
		"quest_complete": sim.quest.is_complete() if sim.quest != null else false,
		"quest_progress_ppm": sim.quest.progress_ppm() if sim.quest != null else 0}
	return out


# --- clock ----------------------------------------------------------------------------------------------------------

## Checkpoint of the tick that is about to end (every CHECKPOINT_TICKS and after battles/descend).
func _checkpoint_at_tick_end() -> void:
	if run_log == null:
		return
	if _checkpoint_due or (_tick > 0 and _tick % CHECKPOINT_TICKS == 0):
		run_log.add_checkpoint(_tick, StateHash.of(state))
		_checkpoint_due = false


## One tick (02_TECH §7.1 order). true = the clock stopped (timer expired).
func _tick_once(out: Array[ExploreEvent]) -> bool:
	var fr: FloorRun = state.floor_run
	if fr.location != &"start":
		# idle tick in a safe room: only the Sponsor-Fenster clock (5)
		out.append_array(_sponsor_events(SponsorWindows.tick(state, rules, false)))
		return false
	var def: FloorDef = data.floor_def(fr.index) if data != null else null
	var warnings: PackedInt32Array = def.timer_warnings if def != null else PackedInt32Array()
	# 1 timer
	var t: Dictionary = fr.tick_timer(1, warnings)
	if bool(t.get("second_changed", false)):
		var secs_left: int = fr.time_left_ticks / TICKS_PER_SEC
		out.append(ExploreEvent.make(ExploreEvent.Type.TIMER_SECOND, _tick, {"seconds": secs_left}))
	for w: int in (t.get("warnings", PackedInt32Array()) as PackedInt32Array):
		out.append(ExploreEvent.make(ExploreEvent.Type.TIMER_WARNING, _tick, {"seconds": w}))
	if bool(t.get("expired", false)):
		out.append(ExploreEvent.make(ExploreEvent.Type.TIMER_EXPIRED, _tick, {}))
		_over = true
		return true
	# 2 explore seconds (pacifist counter)
	if state.show != null and int(fr.stats.get("time_used_ticks", 0)) % TICKS_PER_SEC == 0:
		var secs: int = int(state.show.stats.get("explore_seconds_since_battle", 0)) + 1
		state.show.stats["explore_seconds_since_battle"] = secs
		out.append(ExploreEvent.make(ExploreEvent.Type.EXPLORE_TICK, _tick, {"seconds_since_battle": secs}))
	# 3 hype decay
	fr.decay_ticks += 1
	if fr.decay_ticks >= ShowModel.HYPE_DECAY_TICKS:
		fr.decay_ticks = 0
		if state.show != null:
			var old: float = state.show.hype
			var now: float = ShowModel.decay_step(old)
			if now != old:
				state.show.hype = now
				out.append(ExploreEvent.make(ExploreEvent.Type.HYPE, _tick, {"hype": roundi(now),
					"delta": roundi(now - old)}))
	# 4 stray spawners
	_tick_spawners(fr, out)
	# 5 Sponsor-Fenster
	out.append_array(_sponsor_events(SponsorWindows.tick(state, rules, true)))
	return false


func _tick_spawners(fr: FloorRun, out: Array[ExploreEvent]) -> void:
	var layout: FloorLayout = _current_layout()
	if layout == null:
		return
	for sp: Dictionary in layout.spawners:
		var zone: String = str(sp.get("zone", ""))
		var pool: PackedStringArray = JsonUtil.to_str_array(sp.get("pool", []))
		var interval: int = int(sp.get("interval_sec", 0)) * TICKS_PER_SEC
		if zone == "" or pool.is_empty() or interval <= 0 or _zone_has_stray(fr, zone):
			continue
		var ticks: int = int(fr.spawner_ticks.get(zone, 0)) + 1
		if ticks < interval:
			fr.spawner_ticks[zone] = ticks
			continue
		var group: String = "f%d_s%d" % [fr.index, fr.stray_counter]
		var rng: RandomNumberGenerator = SeedUtil.make_rng(SeedUtil.derive(fr.seed, "stray", fr.stray_counter))
		var enc: String = pool[rng.randi_range(0, pool.size() - 1)]
		fr.strays[group] = {"zone": zone, "enc": enc}
		fr.stray_counter += 1
		fr.spawner_ticks[zone] = 0
		out.append(ExploreEvent.make(ExploreEvent.Type.STRAY_DUE, _tick, {"zone": zone, "group_id": group,
			"encounter_id": enc}))


static func _zone_has_stray(fr: FloorRun, zone: String) -> bool:
	for g: Variant in fr.strays.keys():
		var s: Variant = fr.strays[g]
		if s is Dictionary and str((s as Dictionary).get("zone", "")) == zone:
			return true
	return false


func _current_layout() -> FloorLayout:
	if data == null or state.floor_run == null:
		return null
	var key: String = "%d:%d" % [state.floor_run.index, state.floor_run.seed]
	if _layout == null or _layout_key != key:
		var def: FloorDef = data.floor_def(state.floor_run.index)
		_layout = DungeonGenerator.generate(def, state.floor_run.seed) if def != null else null
		_layout_key = key
	return _layout


# --- commands -------------------------------------------------------------------------------------------------------

func _apply_floor(index: int) -> void:
	var def: FloorDef = data.floor_def(index) if data != null else null
	if def == null:
		push_warning("[RunSim] no floor %d" % index)
		return
	state.floor_run = FloorRun.create(def, state.seed, state.difficulty)
	if state.show != null:
		state.show.hype = ShowModel.HYPE_START
	_floor_done = false
	_layout = null
	_layout_key = ""


## §5.7 without presentation: setup ("battle" stream), BattleState, the "show" stream draw of Show.begin_battle,
## pacifist counter reset, start().
func _apply_encounter(enc: String, adv: int, group: String, out: Array[ExploreEvent]) -> void:
	if battle != null:
		push_warning("[RunSim] encounter '%s' while a battle is running" % enc)
		return
	var setup: BattleSetup = BattleBridge.make_setup(state, data, enc, adv, group, next_seed("battle"))
	if setup == null:
		return
	battle = BattleState.new(setup, data)
	_battle_external = 0
	next_seed("show")
	if state.show != null:
		state.show.stats["explore_seconds_since_battle"] = 0
	out.append(ExploreEvent.make(ExploreEvent.Type.ENCOUNTER, _tick, {"group_id": group, "encounter_id": enc,
		"advantage": adv}))
	_quest_feed({"type": "battle_started"})
	last_action_events = battle.start()
	_quest_feed_battle(last_action_events)
	if battle.is_finished():
		_end_battle()


func _apply_battle(cmd_dict: Dictionary, _out: Array[ExploreEvent]) -> void:
	if battle == null or battle.is_finished():
		push_warning("[RunSim] battle command without an active battle")
		return
	var bc: BattleCommand = BattleCommand.from_dict(cmd_dict)
	var reason: String = battle.validate(bc)
	if reason != "":
		push_warning("[RunSim] battle command refused: " + reason)
		return
	last_action_events = battle.submit(bc)
	_quest_feed_battle(last_action_events)
	if battle.is_finished():
		_end_battle()


func _end_battle() -> void:
	var result: BattleResult = battle.result
	battle = null
	_checkpoint_due = true
	if result == null:
		return
	BattleBridge.apply_result(state, data, result)
	if result.outcome == BattleResult.Outcome.VICTORY and result.is_boss:
		_quest_feed({"type": "boss_defeated", "boss_id": result.boss_id})
	if result.outcome == BattleResult.Outcome.DEFEAT:
		_over = true


## Applies a gift that passed gift_refusal(): external ids → flags.live.gift_ids; in battle BattleState.apply_gift +
## GiftApplier.note_battle_gift (gift items + run counters, as GiftApplier.apply does outside battles).
func _apply_gift(g: Dictionary, out: Array[ExploreEvent]) -> void:
	if Gift.is_external(g):
		var live: Dictionary = GiftApplier.live_counters(state)
		if not (live.get("gift_ids", null) is Array):
			live["gift_ids"] = []
		(live["gift_ids"] as Array).append(str(g.get("gift_id", "")))
	if battle != null and not battle.is_finished():
		last_action_events = battle.apply_gift(g)
		_quest_feed_battle(last_action_events)
		GiftApplier.note_battle_gift(state, g, last_action_events)
		if Gift.is_external(g):
			_battle_external += 1
	else:
		var rewards: Array[LootReward] = GiftApplier.apply(state, data, g, SeedUtil.make_rng(next_seed("gift")))
		_add_rewards(rewards)
	out.append(ExploreEvent.make(ExploreEvent.Type.GIFT_DELIVERED, _tick, {"gift_id": str(g.get("gift_id", "")),
		"kind": str(g.get("kind", ""))}))


func _apply_room(cell: Vector2i, out: Array[ExploreEvent]) -> void:
	var fr: FloorRun = state.floor_run
	if fr == null:
		return
	var first: bool = not fr.visited.has(cell)
	var kind: String = ""
	var layout: FloorLayout = _current_layout()
	var rc: RoomCell = layout.cell_at(cell) if layout != null else null
	if rc != null:
		kind = str(RoomCell.Kind.keys()[int(rc.kind)]).to_lower()
	if first:
		fr.visited.append(cell)
		if rc != null and rc.kind == RoomCell.Kind.STAIRS:
			fr.stairs_found = true
		_quest_feed_zones(fr, layout)
	out.append(ExploreEvent.make(ExploreEvent.Type.ROOM_ENTERED, _tick, {"cell": [cell.x, cell.y], "kind": kind,
		"first_visit": first}))
	if first:
		out.append_array(sponsor_room(cell))


## Like Game.open_chest (02_TECH §3.4): unknown / opened / locked without itm_key_master → nothing; else
## LootRoller.roll_chest with SeedUtil.derive(floor_run.loot_seed, "chest", k) (05 CR-11: never the public layout seed).
func _apply_chest(chest_id: String, out: Array[ExploreEvent]) -> void:
	var fr: FloorRun = state.floor_run
	var layout: FloorLayout = _current_layout()
	if fr == null or layout == null or fr.opened_chests.has(chest_id):
		return
	var chest: ChestSpawn = null
	for ch: ChestSpawn in layout.chests:
		if ch != null and ch.id == chest_id:
			chest = ch
			break
	if chest == null:
		push_warning("[RunSim] unknown chest '%s'" % chest_id)
		return
	if chest.type == "locked" and (state.inventory == null or not state.inventory.has("itm_key_master")):
		return
	var k: int = chest_id.get_slice("_c", 1).to_int()
	var rng: RandomNumberGenerator = SeedUtil.make_rng(SeedUtil.derive(fr.loot_seed, "chest", k))
	var spec: Dictionary = {"id": chest.id, "type": chest.type, "contents": chest.contents}
	var rewards: Array[LootReward] = LootRoller.roll_chest(spec, data, fr.index, state, rng)
	_add_rewards(rewards)
	fr.opened_chests.append(chest_id)
	var rd: Array = []
	for r: LootReward in rewards:
		rd.append(r.to_dict())
	out.append(ExploreEvent.make(ExploreEvent.Type.CHEST_OPENED, _tick, {"chest_id": chest_id, "rewards": rd}))


func _apply_gate(key: String, out: Array[ExploreEvent]) -> void:
	if state.floor_run == null or state.floor_run.opened_gates.has(key):
		return
	state.floor_run.opened_gates.append(key)
	out.append(ExploreEvent.make(ExploreEvent.Type.GATE_OPENED, _tick, {"key": key}))


func _apply_lootbox(box_id: String) -> void:
	var idx: int = state.pending_lootboxes.find(box_id)
	if idx < 0 or data == null or not data.has_id("lootboxes", box_id):
		push_warning("[RunSim] lootbox '%s' is not pending" % box_id)
		return
	state.pending_lootboxes.remove_at(idx)
	var rng: RandomNumberGenerator = SeedUtil.make_rng(next_seed("lootbox"))
	var floor_index: int = state.floor_run.index if state.floor_run != null else 1
	_add_rewards(LootRoller.roll_lootbox(data.lootbox(box_id), data, floor_index, state, rng))


## Like Game.apply_floor_event (§7.4) without the Show part (hype/followers/M.O.D.): k = index of the event in the
## layout, rng SeedUtil.derive(floor_run.seed, "event", k × 16 + event_uses[id]); boxes → pending_lootboxes.
func _apply_event(event_id: String, choice: String, out: Array[ExploreEvent]) -> void:
	var fr: FloorRun = state.floor_run
	var layout: FloorLayout = _current_layout()
	if fr == null or layout == null:
		return
	var k: int = -1
	for i in layout.events.size():
		if layout.events[i] != null and layout.events[i].id == event_id:
			k = i
			break
	if k < 0:
		push_warning("[RunSim] unknown floor event '%s'" % event_id)
		return
	var ev: EventSpawn = layout.events[k]
	var uses: int = int(fr.event_uses.get(event_id, 0))
	var rng: RandomNumberGenerator = SeedUtil.make_rng(SeedUtil.derive(fr.seed, "event", k * 16 + uses))
	var outcome: Dictionary = FloorEvent.resolve(ev, choice, state, data, rng)
	FloorEvent.apply(outcome, ev, choice, state, data)
	for box: Variant in outcome.get("boxes", PackedStringArray()):
		state.pending_lootboxes.append(str(box))
	out.append(ExploreEvent.make(ExploreEvent.Type.EVENT_CHOICE, _tick, {"event_id": event_id, "choice": choice,
		"completed": bool(outcome.get("completed", false))}))


## Like Game.enter_safe_room: location, visits, first-visit bookkeeping, full heal.
func _apply_safe_room(safe_room_id: String) -> void:
	var fr: FloorRun = state.floor_run
	if fr == null:
		return
	fr.location = StringName(safe_room_id)
	fr.safe_room_visits += 1
	if not fr.visited_safe_rooms.has(safe_room_id):
		fr.visited_safe_rooms.append(safe_room_id)
	Progression.full_heal(state, data)


## Like Game.set_difficulty: only prime → vorabend, remaining timer ticks × 1.5 in integers (05 §3.3 Nr. 5):
## (ticks × EASY_TIMER_PM + 500) // 1000 (== roundi(ticks × 1.5) for ticks >= 0).
func _apply_difficulty(d: StringName) -> void:
	if state.difficulty != &"prime" or d != &"vorabend":
		return
	state.difficulty = d
	if state.floor_run != null:
		var left: int = maxi(0, state.floor_run.time_left_ticks)
		state.floor_run.time_left_ticks = (left * EASY_TIMER_PM + 500) / 1000


## Like Game.add_rewards: items → inventory (overflow over max_stack → credits at sell value), credits.
func _add_rewards(rewards: Array[LootReward]) -> void:
	if state.inventory == null:
		return
	for r: LootReward in rewards:
		if r == null:
			continue
		if r.kind == "credits":
			state.inventory.add_credits(r.amount)
		elif r.kind == "item" and data != null and data.has_id("items", r.id):
			var added: int = state.inventory.add(r.id, r.amount, data.item(r.id).max_stack)
			if r.amount - added > 0:
				state.inventory.add_credits((r.amount - added) * Shop.sell_value(data, r.id))


## Event runs: the run's league (single league of rules.leagues) and rules.gifts → state.flags["live"].
func _store_run_rules() -> void:
	var leagues: Variant = rules.get("leagues", null)
	var single_league: bool = leagues is Array and (leagues as Array).size() == 1
	var has_gifts: bool = rules.get("gifts", null) is Dictionary
	if not single_league and not has_gifts:
		return
	var live: Dictionary = GiftApplier.live_counters(state)
	if single_league and not live.has("league"):
		live["league"] = str((leagues as Array)[0])
	if has_gifts and not live.has("gift_rules"):
		live["gift_rules"] = (rules["gifts"] as Dictionary).duplicate(true)


func _quest_feed(ev: Dictionary) -> void:
	if quest != null:
		quest.on_event(ev)


## Enemy KOs of a battle event list → enemy_killed (same rule as ShowRules: KO with an enemy target "e…"); HP of
## boss targets → boss_hp {"boss_id", "hp", "max_hp"} (defeat_boss progress before the victory).
func _quest_feed_battle(events: Array[ActionEvent]) -> void:
	if quest == null:
		return
	for e: ActionEvent in events:
		if e == null or not e.target_id.begins_with("e"):
			continue
		if e.type == ActionEvent.Type.KO:
			quest.on_event({"type": "enemy_killed", "enemy_id": e.def_id})
		if e.hp_after >= 0 and e.max_hp > 0 and data != null and data.has_id("enemies", e.def_id) \
				and data.enemy(e.def_id).boss:
			quest.on_event({"type": "boss_hp", "boss_id": e.def_id, "hp": e.hp_after, "max_hp": e.max_hp})


## Explored zones of the floor (zones_event) → reach_stairs progress before the stairs (handbuilt floors only).
func _quest_feed_zones(fr: FloorRun, layout: FloorLayout) -> void:
	if quest == null:
		return
	var ev: Dictionary = zones_event(fr, layout)
	if not ev.is_empty():
		quest.on_event(ev)


## SponsorWindows event dictionaries → ExploreEvents at the current tick.
func _sponsor_events(events: Array[Dictionary]) -> Array[ExploreEvent]:
	var out: Array[ExploreEvent] = []
	for e: Dictionary in events:
		if str(e.get("type", "")) == "opened":
			out.append(ExploreEvent.make(ExploreEvent.Type.SPONSOR_WINDOW_OPENED, _tick, {"window": e["window"]}))
		else:
			out.append(ExploreEvent.make(ExploreEvent.Type.SPONSOR_WINDOW_CLOSED, _tick, {"id": str(e.get("id", "")),
				"kind": str(e.get("kind", "")), "reason": str(e.get("reason", ""))}))
	return out


## An accepted external gift without stamp gets the id of its Sponsor-Fenster (recorded with it).
func _stamp_window(g: Dictionary) -> void:
	if str(g.get("sponsor_window", "")) != "":
		return
	var live: Variant = state.flags.get("live", {})
	var wid: String = SponsorWindows.window_for(live if live is Dictionary else {}, g)
	if wid != "":
		g["sponsor_window"] = wid


func _compare_checkpoint(cps: Array[Dictionary], cp: int, out: Dictionary) -> int:
	advance_to(int(cps[cp]["k"]))
	if int(out["mismatch_at"]) < 0 and StateHash.of(state) != str(cps[cp]["h"]):
		out["mismatch_at"] = cp
	return cp + 1
