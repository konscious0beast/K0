extends TestCase
## Sponsor-Fenster (user decision 2026-10-08, 05 §6.13): viewers can help only a limited number of times at specific
## times. Unit (RunSim / SponsorWindows / GiftPolicy without autoloads): the periodic schedule in exploration ticks
## (default 300 s / 60 s), battles freeze windows and the countdown, slot limit (first come, first served), per-viewer
## limit, reason codes window_closed / window_full / window_sender_limit (→ E_WINDOW_*), safe room window with idle
## ticks (max 90 s, once per room), Boss-Countdown on the first entry of a boss room (45 s), floor change, grace for
## stamped gifts, exempt cheers, Pur-Liga without windows, dev windows only where allowed, rules validation, replay
## equivalence (RunSim.replay; forged gift outside a window reported). Integration (Game/Show autoloads):
## Show.receive_gift outside/inside a window incl. reservations of queued gifts in battle, signals, stamps, Game
## replay ≡ live, idle ticks in the safe room through Game._process, Boss-Countdown via Game.visit_room, M.O.D. lines
## only in the live presentation, overlay badge texts and the debug tool.

const TPS: int = 30
const FAST: Dictionary = {"sponsor_windows": {"periodic": {"first_sec": 10, "every_sec": 20, "open_sec": 5}}}


func after_each() -> void:
	Game.state = null
	Game.run_log = null
	Game.sim = null
	Game.quest = null
	Game.mode = &"campaign"
	Game.timer_running = false
	Game.safe_room_clock = false
	Game.in_battle = false
	Game.auto_battle = false
	Game.clear_blocking_dialogs()


# --- helpers ----------------------------------------------------------------------------------------------------------

## Campaign RunSim on floor 1 with the countdown running (unit tests; not replayable from create_new).
func _sim(rules: Dictionary = {}, seed: int = 77) -> RunSim:
	var data: GameData = real_data()
	var st: GameState = GameState.create_new(data, 0, "Kai", seed, &"prime")
	var sim: RunSim = RunSim.new(data, st, rules)
	sim.apply({"t": "floor", "floor": 1})
	sim.state.floor_run.timer_started = true
	return sim


func _of(events: Array[ExploreEvent], t: ExploreEvent.Type) -> Array[ExploreEvent]:
	var out: Array[ExploreEvent] = []
	for e: ExploreEvent in events:
		if e.type == t:
			out.append(e)
	return out


func _layout(sim: RunSim) -> FloorLayout:
	return DungeonGenerator.generate(real_data().floor_def(sim.state.floor_run.index), sim.state.floor_run.seed)


func _fight(sim: RunSim) -> void:
	var guard: int = 0
	while sim.battle != null and guard < 600:
		guard += 1
		var cmd: BattleCommand = sim.battle.choose_ai_command()
		sim.apply({"t": "battle", "cmd": cmd.to_dict(), "auto": true})


## Dev gift of a pseudonymous viewer (sender_ref "" = unknown sender, no per-viewer limit).
func _gift(kind: String = "gold", ref: String = "", n: int = 0) -> Dictionary:
	var g: Dictionary = Gift.make_dev(kind, "bronze" if kind == "chest" else "", 100 if kind == "gold" else 0, ref)
	if n > 0:
		g["gift_id"] = "g_dev_sw_%d" % n
	return g


func _open(sim: RunSim, sec: int = 60, slots: int = 3) -> void:
	assert_eq(_of(sim.apply({"t": "sponsor_window", "op": "dev_open", "sec": sec, "slots": slots}),
		ExploreEvent.Type.SPONSOR_WINDOW_OPENED).size(), 1, "dev window opened")


# --- schedule ---------------------------------------------------------------------------------------------------------

func test_defaults_are_the_decided_values() -> void:
	var r: Dictionary = SponsorWindows.rules_of({})
	assert_eq([r["periodic"]["every_sec"], r["periodic"]["open_sec"], r["safe_room"]["max_sec"],
		r["boss"]["countdown_sec"], r["slots_per_player"], r["per_viewer"]], [300, 60, 90, 45, 3, 1],
		"every 300 s for 60 s · safe room ≤ 90 s · Boss-Countdown 45 s · 3 slots · 1 gift per viewer and window")
	var merged: Dictionary = SponsorWindows.rules_of({"sponsor_windows": {"periodic": {"open_sec": 30}}})
	assert_eq([merged["periodic"]["open_sec"], merged["periodic"]["every_sec"]], [30, 300], "nested keys merge")


func test_periodic_window_in_exploration_ticks() -> void:
	var sim: RunSim = _sim()
	assert_true(SponsorWindows.tracked(sim.state), "campaign: windows with the default rules")
	assert_eq(_of(sim.step(300 * TPS - 1), ExploreEvent.Type.SPONSOR_WINDOW_OPENED), [], "not before 300 s")
	assert_eq(sim.sponsor_window()["next_in_sec"], 1)
	var opened: Array[ExploreEvent] = _of(sim.step(1), ExploreEvent.Type.SPONSOR_WINDOW_OPENED)
	assert_eq(opened.size(), 1, "the first periodic window opens at tick 9000")
	assert_eq(opened[0].tick, 9000)
	var w: Dictionary = opened[0].data["window"]
	assert_eq([w["id"], w["kind"], w["slots"], w["used"], w["left_ticks"], w["left_sec"]],
		["sw_1", "periodic", 3, 0, 60 * TPS, 60])
	assert_eq(_of(sim.step(60 * TPS - 1), ExploreEvent.Type.SPONSOR_WINDOW_CLOSED), [], "open for 60 s")
	assert_eq(sim.sponsor_window()["left_sec"], 1)
	var closed: Array[ExploreEvent] = _of(sim.step(1), ExploreEvent.Type.SPONSOR_WINDOW_CLOSED)
	assert_eq(closed.size(), 1)
	assert_eq([closed[0].tick, closed[0].data["id"], closed[0].data["reason"]], [10800, "sw_1", "time"])
	assert_false(sim.sponsor_window()["open"])
	assert_eq(sim.sponsor_window()["next_in_sec"], 240, "windows start every 300 s")


func test_step_one_by_one_equals_step_n() -> void:
	var a: RunSim = _sim(FAST)
	var b: RunSim = _sim(FAST)
	var ea: Array = []
	for i in 3000:
		for e: ExploreEvent in a.step(1):
			if e.type in [ExploreEvent.Type.SPONSOR_WINDOW_OPENED, ExploreEvent.Type.SPONSOR_WINDOW_CLOSED]:
				ea.append(e.to_dict())
	var eb: Array = []
	for e: ExploreEvent in b.step(3000):
		if e.type in [ExploreEvent.Type.SPONSOR_WINDOW_OPENED, ExploreEvent.Type.SPONSOR_WINDOW_CLOSED]:
			eb.append(e.to_dict())
	assert_eq(ea, eb)
	assert_eq(ea.size(), 10, "FAST rules: windows at 10 s, 30 s, 50 s, 70 s, 90 s, each closed after 5 s")
	assert_eq(StateHash.of(a.state), StateHash.of(b.state))


func test_battle_freezes_the_window_and_the_countdown() -> void:
	var sim: RunSim = _sim(FAST)
	sim.step(10 * TPS)
	assert_true(sim.sponsor_window()["open"], "open at 10 s")
	sim.step(2 * TPS)
	var left: int = sim.sponsor_window()["left_ticks"]
	var next: int = sim.sponsor_window()["next_in_ticks"]
	sim.apply({"t": "encounter", "enc": real_data().floor_def(1).timer_start_after, "adv": 0, "group": ""})
	assert_not_null(sim.battle)
	assert_eq(sim.step(10 * TPS), [], "the run clock stands in battle: no window opens or closes")
	assert_eq([sim.sponsor_window()["left_ticks"], sim.sponsor_window()["next_in_ticks"]], [left, next], "frozen")
	assert_eq(sim.gift_refusal(_gift("gold", "v1")), "", "the window opened before the battle takes gifts")
	sim.apply({"t": "gift", "gift": _gift("gold", "v1", 1)})
	assert_eq(sim.sponsor_window()["used"], 1, "booked in battle (BattleState.apply_gift + note_battle_gift)")
	_fight(sim)
	assert_null(sim.battle)
	var closed: Array[ExploreEvent] = _of(sim.step(left), ExploreEvent.Type.SPONSOR_WINDOW_CLOSED)
	assert_eq(closed.size(), 1, "the rest of the window runs after the battle")


func test_no_window_opens_during_a_battle() -> void:
	var sim: RunSim = _sim(FAST)
	sim.step(10 * TPS - 1)
	sim.apply({"t": "encounter", "enc": real_data().floor_def(1).timer_start_after, "adv": 0, "group": ""})
	assert_eq(sim.step(TPS), [])
	assert_false(sim.sponsor_window()["open"], "the due window waits for the battle end")
	assert_eq(sim.gift_refusal(_gift()), "window_closed", "no gift lands mid-battle without a window")
	_fight(sim)
	assert_eq(_of(sim.step(1), ExploreEvent.Type.SPONSOR_WINDOW_OPENED).size(), 1, "opens on the next tick")


# --- slots, viewers, codes
# ----------------------------------------------------------------------------------------------

func test_slots_first_come_first_served_and_reason_codes() -> void:
	var sim: RunSim = _sim()
	assert_eq(sim.gift_refusal(_gift("gold", "a")), "window_closed", "no window open")
	assert_eq(SponsorWindows.protocol_code("window_closed"), "E_WINDOW_CLOSED")
	_open(sim)
	sim.apply({"t": "gift", "gift": _gift("gold", "a", 1)})
	assert_eq(sim.gift_refusal(_gift("gold", "a")), "window_sender_limit", "1 gift per viewer and window")
	sim.apply({"t": "gift", "gift": _gift("gold", "b", 2)})
	sim.apply({"t": "gift", "gift": _gift("gold", "c", 3)})
	assert_eq(sim.rejected_cmds, [] as Array[Dictionary], "three viewers, three slots")
	var v: Dictionary = sim.sponsor_window()
	assert_eq([v["used"], v["free"], v["full"]], [3, 0, true])
	assert_eq(sim.gift_refusal(_gift("gold", "d")), "window_full", "4th viewer: the window is full")
	assert_eq(SponsorWindows.protocol_code("window_full"), "E_WINDOW_FULL")
	sim.apply({"t": "gift", "gift": _gift("gold", "d", 4)})
	assert_eq(sim.rejected_cmds.back()["reason"], "window_full", "refused at application too (authoritative)")
	assert_eq((sim.state.flags["live"]["gift_ids"] as Array).size(), 3)
	sim.step(60 * TPS)
	assert_eq(sim.gift_refusal(_gift("gold", "d")), "window_closed")


func test_per_viewer_limit_is_data_driven_and_pending_reservations_count() -> void:
	var sim: RunSim = _sim({"sponsor_windows": {"per_viewer": 2, "slots_per_player": 4}})
	_open(sim, 60, 4)
	sim.apply({"t": "gift", "gift": _gift("gold", "a", 1)})
	assert_eq(sim.gift_refusal(_gift("gold", "a")), "", "per_viewer 2")
	sim.apply({"t": "gift", "gift": _gift("gold", "a", 2)})
	assert_eq(sim.gift_refusal(_gift("gold", "a")), "window_sender_limit")
	# Show's queue: gifts accepted but not applied hold their slot and their viewer's share
	var run: Dictionary = (sim.state.flags["live"] as Dictionary).duplicate()
	run[SponsorWindows.PENDING_KEY] = [["sw_1", "b"], ["sw_1", "b"]]
	assert_eq(SponsorWindows.check(run, _gift("gold", "c")), "window_full", "2 used + 2 pending = 4 slots")
	run[SponsorWindows.PENDING_KEY] = [["sw_0", "b"]]
	assert_eq(SponsorWindows.check(run, _gift("gold", "c")), "", "a reservation of another window does not count")
	var one: RunSim = _sim()
	_open(one, 60, 3)
	var run1: Dictionary = (one.state.flags["live"] as Dictionary).duplicate()
	run1[SponsorWindows.PENDING_KEY] = [["sw_1", "b"]]
	assert_eq(SponsorWindows.check(run1, _gift("gold", "b")), "window_sender_limit", "b's pending gift counts")
	assert_eq(SponsorWindows.check(run1, _gift("gold", "c")), "")


func test_cheers_need_no_window_and_take_no_slot() -> void:
	var sim: RunSim = _sim()
	assert_eq(sim.gift_refusal(_gift("cheer", "a")), "", "exempt_kinds: cheer (cosmetic)")
	_open(sim)
	sim.apply({"t": "gift", "gift": _gift("cheer", "a", 1)})
	assert_eq(sim.sponsor_window()["used"], 0)
	assert_eq(sim.gift_refusal(_gift("gold", "a")), "", "the cheer did not use the viewer's gift")


func test_stamped_gift_has_grace_after_the_window_closed() -> void:
	var sim: RunSim = _sim()
	_open(sim, 10, 3)
	var g: Dictionary = _gift("gold", "a", 1)
	g["sponsor_window"] = "sw_1"                     # reserved by the gift service while the window was open
	var late: Dictionary = _gift("gold", "b", 2)
	late["sponsor_window"] = "sw_1"
	sim.step(10 * TPS)
	assert_false(sim.sponsor_window()["open"])
	assert_eq(sim.gift_refusal(_gift("gold", "c")), "window_closed", "unstamped gifts need an open window")
	assert_eq(sim.gift_refusal(g), "", "stamped: accepted within grace_sec (15 s) after the close")
	sim.apply({"t": "gift", "gift": g})
	var other: Dictionary = _gift("gold", "c", 3)
	other["sponsor_window"] = "sw_7"
	assert_eq(sim.gift_refusal(other), "window_closed", "a stamp of another window")
	sim.step(15 * TPS)
	assert_eq(sim.gift_refusal(late), "window_closed", "grace is over")
	assert_eq(Gift.validate(g), "", "sponsor_window is part of the gift schema")
	var bad: Dictionary = _gift()
	bad["sponsor_window"] = "window 1"
	assert_eq(Gift.validate(bad), "invalid_schema")


# --- safe room, boss, floor
# ---------------------------------------------------------------------------------------------

func test_safe_room_window_with_idle_ticks() -> void:
	var sim: RunSim = _sim()
	var layout: FloorLayout = _layout(sim)
	var srs: Array = layout.safe_room_ids.values()
	var sr: String = str(srs[0])
	var ev: Array[ExploreEvent] = _of(sim.apply({"t": "safe_room", "id": sr}), ExploreEvent.Type.SPONSOR_WINDOW_OPENED)
	assert_eq(ev.size(), 1)
	assert_eq([ev[0].data["window"]["kind"], ev[0].data["window"]["ref"], ev[0].data["window"]["left_sec"]],
		["safe_room", sr, 90])
	var left: int = sim.state.floor_run.time_left_ticks
	var hype: float = sim.state.show.hype
	var t0: int = sim.tick()
	var closed: Array[ExploreEvent] = _of(sim.step(90 * TPS), ExploreEvent.Type.SPONSOR_WINDOW_CLOSED)
	assert_eq(sim.tick(), t0 + 90 * TPS, "the run clock keeps ticking in the safe room (idle ticks)")
	assert_eq(sim.state.floor_run.time_left_ticks, left, "… the floor timer does not (explore_only)")
	assert_eq(sim.state.show.hype, hype, "no hype decay in the safe room")
	assert_eq([closed.size(), closed[0].data["reason"]], [1, "time"], "at most 90 s")
	assert_eq(sim.sponsor_window()["next_in_ticks"], 300 * TPS, "the periodic countdown runs in exploration only")
	assert_eq(_of(sim.apply({"t": "safe_room_exit"}), ExploreEvent.Type.SPONSOR_WINDOW_CLOSED), [])
	assert_eq(_of(sim.apply({"t": "safe_room", "id": sr}), ExploreEvent.Type.SPONSOR_WINDOW_OPENED), [],
		"once per safe room and floor")
	sim.apply({"t": "safe_room_exit"})
	if srs.size() > 1:
		sim.apply({"t": "safe_room", "id": str(srs[1])})
		assert_true(sim.sponsor_window()["open"], "another safe room has its own window")
		var left_ev: Array[ExploreEvent] = _of(sim.apply({"t": "safe_room_exit"}),
			ExploreEvent.Type.SPONSOR_WINDOW_CLOSED)
		assert_eq(left_ev[0].data["reason"], "left", "leaving closes it")


func test_boss_countdown_on_entering_the_boss_room() -> void:
	var sim: RunSim = _sim()
	var layout: FloorLayout = _layout(sim)
	assert_ne(layout.quarter_boss, Vector2i(-1, -1), "floor 1 has a quarter boss")
	_open(sim)
	var ev: Array[ExploreEvent] = sim.apply({"t": "room", "cell": [layout.quarter_boss.x, layout.quarter_boss.y]})
	var closed: Array[ExploreEvent] = _of(ev, ExploreEvent.Type.SPONSOR_WINDOW_CLOSED)
	var opened: Array[ExploreEvent] = _of(ev, ExploreEvent.Type.SPONSOR_WINDOW_OPENED)
	assert_eq([closed.size(), closed[0].data["reason"]], [1, "superseded"], "the Boss-Countdown replaces the window")
	assert_eq([opened[0].data["window"]["kind"], opened[0].data["window"]["ref"], opened[0].data["window"]["left_sec"],
		opened[0].data["window"]["used"]], ["boss", "quarter_boss", 45, 0], "45 s, fresh slots")
	assert_eq(_of(sim.apply({"t": "room", "cell": [layout.quarter_boss.x, layout.quarter_boss.y]}),
		ExploreEvent.Type.SPONSOR_WINDOW_OPENED), [], "first entry only")
	sim.apply({"t": "room", "cell": [layout.floor_boss.x, layout.floor_boss.y]})
	assert_eq(sim.sponsor_window()["ref"], "floor_boss", "the floor boss too")
	sim.apply({"t": "room", "cell": [layout.start.x, layout.start.y]})
	assert_eq(sim.sponsor_window()["kind"], "boss", "other rooms change nothing")


func test_floor_change_closes_the_window_and_restarts_the_countdown() -> void:
	var sim: RunSim = _sim(FAST)
	sim.step(12 * TPS)
	assert_true(sim.sponsor_window()["open"])
	sim.apply({"t": "descend"})                       # the next floor follows a descend (RunRules.command_refusal)
	var ev: Array[ExploreEvent] = _of(sim.apply({"t": "floor", "floor": 2}), ExploreEvent.Type.SPONSOR_WINDOW_CLOSED)
	assert_eq(ev.size(), 1)
	if ev.is_empty():
		return
	assert_eq(ev[0].data["reason"], "floor")
	assert_eq(sim.sponsor_window()["next_in_sec"], 10, "first_sec again")


# --- rules ------------------------------------------------------------------------------------------------------------

func test_pur_league_and_disabled_gifts_have_no_windows() -> void:
	var pur: RunSim = _sim({"leagues": ["pur"], "gifts": {"enabled": false}, "timer_mode": "explore_only"})
	assert_false(SponsorWindows.tracked(pur.state), "L5: no viewer gifts → no Sponsor-Fenster")
	assert_eq(_of(pur.step(300 * TPS), ExploreEvent.Type.SPONSOR_WINDOW_OPENED), [])
	assert_eq(pur.gift_refusal(_gift()), "league_pur", "the league decides first")
	assert_eq(pur.apply({"t": "sponsor_window", "op": "dev_open", "sec": 60, "slots": 3}), [])
	assert_eq(pur.rejected_cmds.back()["t"], "sponsor_window", "no QA window in the Pur-Liga")
	var off: RunSim = _sim({"sponsor_windows": {"enabled": false}})
	assert_false(SponsorWindows.tracked(off.state))
	assert_eq(off.gift_refusal(_gift()), "", "windows switched off: gifts follow the other rules only")


func test_dev_windows_only_where_allowed() -> void:
	var rl: RunLog = RunLog.new()
	var sim: RunSim = _sim({"sponsor_windows": {"dev_open": false}})
	sim.run_log = rl
	assert_eq(sim.apply({"t": "sponsor_window", "op": "dev_open", "sec": 60, "slots": 3}), [])
	assert_eq(rl.size(), 0, "refused, not recorded")
	assert_false(SponsorWindows.dev_allowed(sim.state, sim.rules, 60, 3))
	assert_false(SponsorWindows.dev_allowed(_sim().state, {}, 601, 3), "at most 600 s")


func test_rules_validation() -> void:
	assert_eq(SponsorWindows.validate_rules(null), PackedStringArray(), "missing = defaults")
	assert_eq(SponsorWindows.validate_rules(SponsorWindows.DEFAULT_RULES), PackedStringArray())
	var errs: PackedStringArray = SponsorWindows.validate_rules({"slots": 3, "per_viewer": 0,
		"periodic": {"open_sec": 2.5}, "boss": "on", "exempt_kinds": ["confetti"], "dev_open": 1})
	var all: String = "; ".join(errs)
	for want: String in ["unknown key 'slots'", "per_viewer must be an integer >= 1", "periodic.open_sec",
			"boss must be a Dictionary", "unknown gift kind 'confetti'", "dev_open must be a bool"]:
		assert_has(all, want)
	var live: Dictionary = {"id": "evt_test_live", "kind": "weekly", "name_key": "x", "floor": 1,
		"windows": [{"id": "w", "open_at": "2026-11-07T19:00:00Z", "close_at": "2026-11-07T20:30:00Z"}],
		"seed_policy": {"type": "commit_reveal", "commits": {"w": "ab"}},
		"quest": {"type": "reach_stairs", "params": {"floor": 1}},
		"rules": {"mode": "solo", "leagues": ["show"], "timer_mode": "explore_only", "party_preset": "x"}}
	assert_has("; ".join(EventDef.from_dict(live).validate()), "rules.sponsor_windows.dev_open must be false",
		"live events must switch QA windows off explicitly")
	(live["rules"] as Dictionary)["sponsor_windows"] = {"dev_open": false, "boss": {"countdown_sec": 30}}
	assert_eq(EventDef.from_dict(live).validate(), PackedStringArray())


# --- replay -----------------------------------------------------------------------------------------------------------

## Recorded RunSim run with windows (periodic, safe room, boss, dev) and gifts inside them: RunSim.replay gives the
## same hash and checkpoints, without errors; a gift smuggled in outside any window is refused and reported.
func test_replay_equivalence_and_forged_gift_outside_a_window() -> void:
	var data: GameData = real_data()
	var seed: int = 4711
	var st: GameState = GameState.create_new(data, 0, "Kai", seed, &"prime")
	var sim: RunSim = RunSim.new(data, st, FAST)
	var rl: RunLog = RunLog.new()
	rl.header = {"schema": 1, "seed": seed, "slot": 0, "player_name": "Kai", "difficulty": "prime"}
	sim.run_log = rl
	sim.apply({"t": "floor", "floor": 1})
	var fdef: FloorDef = data.floor_def(1)
	var layout: FloorLayout = DungeonGenerator.generate(fdef, st.floor_run.seed)
	sim.apply({"t": "encounter", "enc": fdef.timer_start_after, "adv": BattleSetup.Advantage.PREEMPTIVE, "group": ""})
	_fight(sim)
	assert_true(st.floor_run.timer_started, "tutorial victory starts the clock")
	sim.step(11 * TPS)                                               # periodic window open (10 s)
	sim.apply({"t": "gift", "gift": _gift("gold", "a", 1)})
	sim.apply({"t": "gift", "gift": _gift("chest", "b", 2)})
	sim.step(30 * TPS)
	sim.apply({"t": "safe_room", "id": str(layout.safe_room_ids.values()[0])})
	sim.step(20 * TPS)                                               # idle ticks
	sim.apply({"t": "gift", "gift": _gift("gold", "a", 3)})
	sim.apply({"t": "safe_room_exit"})
	sim.apply({"t": "room", "cell": [layout.quarter_boss.x, layout.quarter_boss.y]})
	sim.apply({"t": "gift", "gift": _gift("gold", "c", 4)})
	sim.step(50 * TPS)
	sim.apply({"t": "sponsor_window", "op": "dev_open", "sec": 30, "slots": 2})
	sim.apply({"t": "gift", "gift": _gift("gold", "", 5)})
	sim.step(40 * TPS)
	assert_eq(sim.rejected_cmds, [] as Array[Dictionary], "every gift landed in a window")
	var h: String = sim.close("test")
	var gifts: Array = []
	for c: Dictionary in rl.cmds():
		if c["c"]["t"] == "gift":
			gifts.append([c["c"]["gift"]["gift_id"], c["c"]["gift"]["sponsor_window"]])
	assert_eq(gifts.size(), 5)
	assert_eq(gifts[0][1], gifts[1][1], "both periodic gifts in the same window")
	var res: Dictionary = RunSim.replay(data, rl, FAST)
	assert_eq(res["errors"], PackedStringArray())
	assert_eq(res["mismatch_at"], -1, "every checkpoint matches (windows are part of the state hash)")
	assert_eq(res["final_hash"], h, "replay ≡ live")
	# forged: the same log plus a gift at tick 0 (right after the floor command) — no window is open there
	var d: Dictionary = rl.to_dict()
	var forged: Dictionary = _gift("gold", "z", 9)
	var cmds: Array = d["cmds"]
	cmds.insert(1, {"k": 0, "id": 0, "c": {"t": "gift", "gift": forged}})
	var res2: Dictionary = RunSim.replay(data, RunLog.from_dict(d), FAST)
	assert_has("; ".join(res2["errors"]), "g_dev_sw_9' refused by the core (window_closed)")


# --- integration: Show.receive_gift / Game ----------------------------------------------------------------------------

func test_receive_gift_outside_and_inside_a_window() -> void:
	Game.new_game(0, "Kai", 3131)
	var opened: Array = []
	var closed: Array = []
	var updated: Array = []
	var rejected: Array = []
	var cb_o: Callable = func(w: Dictionary) -> void: opened.append(w)
	var cb_c: Callable = func(id: String, reason: String) -> void: closed.append([id, reason])
	var cb_u: Callable = func(w: Dictionary) -> void: updated.append(w)
	var cb_r: Callable = func(id: String, reason: String) -> void: rejected.append([id, reason])
	Events.sponsor_window_opened.connect(cb_o)
	Events.sponsor_window_closed.connect(cb_c)
	Events.sponsor_window_updated.connect(cb_u)
	Events.gift_rejected.connect(cb_r)
	var g0: Dictionary = _gift("gold", "a", 1)
	var res: Dictionary = Show.receive_gift(g0)
	assert_eq([res["ok"], res["reason"]], [false, "window_closed"], "outside a window: refused")
	assert_eq(rejected, [[g0["gift_id"], "window_closed"]])
	assert_eq(Show.sponsor_window_view()["next_in_sec"], 300, "the UI can show when the next window opens")
	assert_true(Game.open_dev_sponsor_window(60, 2))
	assert_eq(opened.size(), 1)
	assert_eq([opened[0]["kind"], opened[0]["slots"]], ["dev", 2])
	assert_eq(Show.receive_gift(g0)["apply"], "now", "inside the window")
	assert_eq(updated.size(), 1, "sponsor_window_updated after the slot was taken")
	assert_eq(Show.receive_gift(_gift("gold", "a", 2))["reason"], "window_sender_limit")
	assert_eq(Show.receive_gift(_gift("gold", "b", 3))["apply"], "now")
	assert_eq(Show.receive_gift(_gift("gold", "c", 4))["reason"], "window_full")
	var logged: Array = []
	for c: Dictionary in Game.run_log.cmds():
		if c["c"]["t"] == "gift":
			logged.append(c["c"]["gift"]["sponsor_window"])
	assert_eq(logged, ["sw_1", "sw_1"], "recorded with the window stamp")
	var live_hash: String = StateHash.of(Game.state)
	var rep: Dictionary = Game.replay_log(Game.run_log)
	assert_eq(rep["final_hash"], live_hash, "Game.replay_log ≡ live (QA window and gifts replay)")
	Events.sponsor_window_opened.disconnect(cb_o)
	Events.sponsor_window_closed.disconnect(cb_c)
	Events.sponsor_window_updated.disconnect(cb_u)
	Events.gift_rejected.disconnect(cb_r)


## In battle the window opened before stays open (frozen); gifts wait in the queue and hold their slot — a third
## viewer finds the window full although nothing was applied yet; live ≡ Game.replay_log.
func test_queued_gifts_in_battle_reserve_their_slots() -> void:
	Game.new_game(0, "Kai", 3132)
	assert_true(Game.open_dev_sponsor_window(60, 2))
	var setup: BattleSetup = Game.make_battle_setup(DB.floor_def(1).timer_start_after, BattleSetup.Advantage.NORMAL, "")
	var battle: BattleState = BattleState.new(setup, DB.data)
	Show.begin_battle(setup)
	Events.battle_started.emit(setup.encounter_id, setup.is_boss)
	for e: ActionEvent in battle.start():
		Show.on_battle_event(e)
	assert_eq(Show.receive_gift(_gift("gold", "a", 1))["apply"], "queued")
	assert_eq(Show.receive_gift(_gift("gold", "b", 2))["apply"], "queued")
	assert_eq(Show.sponsor_window_view()["free"], 0, "two reservations")
	assert_eq(Show.receive_gift(_gift("gold", "c", 3))["reason"], "window_full", "reserved slots count")
	assert_eq(Show.receive_gift(_gift("gold", "a", 4))["reason"], "window_full")
	var guard: int = 0
	while not battle.is_finished() and guard < 400:
		guard += 1
		var g: Dictionary = Show.take_pending_gift(battle)
		if not g.is_empty():
			var gev: Array[ActionEvent] = battle.apply_gift(g)
			Show.note_battle_gift(g, gev)
			for e: ActionEvent in gev:
				Show.on_battle_event(e)
		var cmd: BattleCommand = battle.choose_ai_command()
		Game.record({"t": "battle", "cmd": cmd.to_dict(), "auto": true})
		for e: ActionEvent in battle.submit(cmd):
			Show.on_battle_event(e)
	Events.battle_ended.emit(battle.result.outcome, battle.result.encounter_id)
	Game.apply_battle_result(battle.result)
	Show.end_battle(battle.result)
	var v: Dictionary = Show.sponsor_window_view()
	assert_eq([v["used"], v["full"]], [2, true], "one delivered in battle, one after it")
	var live_hash: String = StateHash.of(Game.state)
	assert_eq(Game.replay_log(Game.run_log)["final_hash"], live_hash)


## Idle ticks through the Game facade: the safe room scene flag lets Game._process tick the run clock (not the floor
## timer); the safe room window closes after 90 s (replay of idle ticks: test_replay_equivalence_…, fullrun).
func test_idle_ticks_in_the_safe_room_through_game() -> void:
	Game.new_game(0, "Kai", 3133)
	Game.state.floor_run.timer_started = true            # (the tutorial battle is not part of this test)
	var srs: Array = DB.floor_def(1).layout.get("safe_rooms", [])
	var sr: String = str((srs[0] as Dictionary)["id"])
	Game.enter_safe_room(sr)
	assert_eq(Show.sponsor_window_view()["kind"], "safe_room")
	var left: int = Game.state.floor_run.time_left_ticks
	Game.safe_room_clock = true
	for i in 100:
		Game._process(1.0)
	assert_eq(Game.sim.tick(), 100 * TPS, "100 s of idle ticks")
	assert_eq(Game.state.floor_run.time_left_ticks, left, "the floor timer stood still")
	assert_false(Show.sponsor_window_view()["open"], "max 90 s")
	assert_eq(Show.receive_gift(_gift("gold", "a", 1))["reason"], "window_closed")
	Game.safe_room_clock = false
	Game._process(1.0)
	assert_eq(Game.sim.tick(), 100 * TPS, "no idle ticks outside the safe room scene")


func test_boss_countdown_through_game_visit_room() -> void:
	Game.new_game(0, "Kai", 3134)
	var opened: Array = []
	var cb: Callable = func(w: Dictionary) -> void: opened.append(w)
	Events.sponsor_window_opened.connect(cb)
	var layout: FloorLayout = DungeonGenerator.generate(DB.floor_def(1), Game.state.floor_run.seed)
	assert_true(Game.visit_room(layout.quarter_boss))
	Events.sponsor_window_opened.disconnect(cb)
	assert_eq(opened.size(), 1)
	assert_eq([opened[0]["kind"], opened[0]["left_sec"]], ["boss", 45], "Boss-Countdown 45 s")
	assert_eq(Show.receive_gift(_gift("gold", "a", 1))["apply"], "now", "before the boss fight")


## M.O.D. announces windows only in the live presentation (event/live runs that take viewer gifts) — the campaign stays
## subtle (badge only). L13: the lines never ask for a purchase.
func test_mod_lines_only_in_the_live_presentation() -> void:
	Game.new_game(0, "Kai", 3135)
	var tags: Array = []
	var cb: Callable = func(_text: String, _v: StringName, tag: String, _b: bool) -> void: tags.append(tag)
	Events.mod_said.connect(cb)
	assert_eq(Show.sponsor_presentation(), &"subtle", "campaign")
	Game.open_dev_sponsor_window(60, 1)
	assert_false(tags.any(func(t: String) -> bool: return t.begins_with("sponsor_window")), "campaign: no lines")
	Game.mode = &"event_offline"                        # a run that takes viewer gifts (S2+); offline events are Pur
	assert_eq(Show.sponsor_presentation(), &"live")
	tags.clear()
	Game.open_dev_sponsor_window(60, 1)
	assert_has(tags, "sponsor_window_open:dev")
	Show.receive_gift(_gift("gold", "a", 1))
	assert_has(tags, "sponsor_window_full")
	Events.mod_said.disconnect(cb)
	for tag: String in ["sponsor_window_open", "sponsor_window_open:safe_room", "sponsor_window_open:boss",
			"sponsor_window_open:boss_comeback", "sponsor_window_closed", "sponsor_window_full"]:
		assert_gt(DB.data.mod_lines(tag).size(), 0, "lines for " + tag)
		assert_true(DataValidator.is_valid_mod_tag(tag), tag)
	# L13/L16 + 06 §6 decision 1 (06-C): no purchase pressure, no urgency words, no seconds / slot counts
	var checked: int = 0
	for raw: Variant in (JsonUtil.read_file("res://data/mod_lines.json") as Dictionary)["entries"]:
		var l: Dictionary = raw
		if not str(l.get("tag", "")).begins_with("sponsor_window_"):
			continue
		checked += 1
		var text: String = str(l.get("text", ""))
		for word: String in ["kauf", "jetzt", "schick", "schnell", "nur noch", "letzte chance", "sekunde"]:
			assert_false(text.to_lower().contains(word), "L13/L16 no pressure ('%s'): %s" % [word, str(l["id"])])
		for ph: String in ["seconds", "count"]:
			assert_false(DataValidator.placeholders_in(text).has(ph), "no {%s} in %s (06 §6)" % [ph, str(l["id"])])
	assert_gt(checked, 7, "every sponsor_window_* line checked")


# --- overlay badge and debug tool -------------------------------------------------------------------------------------

## 06 §6 decision 1 (06-C): the badge shows the window STATE — open / full / next in ~N minutes — never a seconds
## countdown (the slots are pips next to the text, tested in test_06c_sponsor_display).
func test_badge_texts() -> void:
	var OverlayScript: GDScript = load("res://scenes/ui/show_overlay.gd")
	var live_open: Dictionary = {"tracked": true, "mode": "live", "open": true, "left_sec": 45, "slots": 3, "free": 1,
		"full": false}
	assert_eq(OverlayScript.call("sponsor_text", live_open), "SPONSOR-FENSTER OFFEN")
	assert_eq(OverlayScript.call("sponsor_slots", live_open), Vector2i(2, 3), "2 of 3 slots taken (pips)")
	live_open["free"] = 0
	live_open["full"] = true
	assert_eq(OverlayScript.call("sponsor_text", live_open), "SPONSOR-FENSTER VOLL – danke!")
	assert_eq(OverlayScript.call("sponsor_text", {"tracked": true, "mode": "live", "open": false, "next_in_sec": 192}),
		"Nächstes Fenster in ~4 Min.")
	assert_eq(OverlayScript.call("sponsor_text", {"tracked": true, "mode": "subtle", "open": true, "left_sec": 60,
		"slots": 3, "free": 3}), "Sponsor-Fenster offen")
	assert_eq(OverlayScript.call("sponsor_text", {"tracked": true, "mode": "off", "open": true}), "", "Pur-Liga")
	assert_eq(OverlayScript.call("sponsor_text", {"tracked": true, "mode": "live", "open": false, "next_in_sec": -1}),
		"", "nothing scheduled")


func test_overlay_badge_follows_the_run() -> void:
	Game.new_game(0, "Kai", 3136)
	var o: CanvasLayer = (load("res://scenes/ui/show_overlay.tscn") as PackedScene).instantiate() as CanvasLayer
	o.call("setup", {})
	add_to_tree(o)
	await wait_frames(1)
	o.call("set_mode", &"explore")
	o.call("refresh_sponsor_badge")
	assert_eq(o.call("sponsor_badge_text"), "Nächstes Fenster in ~5 Min.")
	assert_eq(o.call("sponsor_badge_style"), "subtle", "campaign: dim line")
	Game.open_dev_sponsor_window(60, 3)
	await wait_frames(1)
	assert_eq(o.call("sponsor_badge_text"), "Sponsor-Fenster offen", "refreshed on the signal")
	assert_eq(o.call("sponsor_badge_pips"), "○○○", "three free slots")
	Game.mode = &"event_offline"
	o.call("refresh_sponsor_badge")
	assert_eq(o.call("sponsor_badge_style"), "live_open")
	assert_eq(o.call("sponsor_badge_text"), "SPONSOR-FENSTER OFFEN")
	var demo: CanvasLayer = (load("res://scenes/ui/show_overlay.tscn") as PackedScene).instantiate() as CanvasLayer
	demo.call("setup", {"capture": true})
	add_to_tree(demo)
	await wait_frames(1)
	assert_eq(demo.call("sponsor_badge_text"), "SPONSOR-FENSTER OFFEN", "capture still")
	assert_eq(demo.call("sponsor_badge_pips"), "●●○", "capture still: 2 of 3 taken")
	o.queue_free()
	demo.queue_free()


func test_debug_tool_respects_windows() -> void:
	Game.new_game(0, "Kai", 3137)
	var dbg: CanvasLayer = (load("res://scenes/ui/debug_overlay.gd") as GDScript).new() as CanvasLayer
	add_to_tree(dbg)
	var res: Dictionary = dbg.call("send_test_gift")
	assert_eq(res["reason"], "window_closed", "the dev gift is a viewer gift like any other")
	assert_eq(dbg.call("refusal_text", "window_closed", Show.sponsor_window_view()),
		"Sponsor-Fenster zu – nächstes in 5:00")
	assert_true(dbg.call("open_test_window"))
	for i in 3:
		assert_eq((dbg.call("send_test_gift") as Dictionary)["apply"], "now", "a new test viewer each time")
	assert_eq((dbg.call("send_test_gift") as Dictionary)["reason"], "window_full")
	assert_has(str(dbg.call("info_text")), "Sponsor    voll")
	dbg.queue_free()

