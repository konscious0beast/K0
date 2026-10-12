extends TestCase
## 09 §11.6 test_09_stairs_collapse (ST1-B): the staircase rule at every boundary (floors 1–3 open, from floor 4 one
## floor below the floor on air; Am Stück without a limit; no stairs on the finale floor), the collapse logged in, as a
## sleeper (SeasonRules.advance — the path of ST1-G's "away") and in a combat (it waits for the end, then two minutes),
## at most one fee per seven days (rescue or medics) and the free carry of a sleeper in a safe room, the dress rehearsal
## on floor 1 (also Ohne Netz), Ohne Netz out from floor 2, the floor balance only by the stairs, the last collapse and
## the end of the playable floors (its stairs or its collapse end the season), and Am Stück the countdown's end as the
## collapse.

const Kit := preload("res://tests/fixtures/season_core/season_core.gd")
const RtLive := preload("res://tests/fixtures/rt_live/rt_live.gd")
const DAY: int = Kit.DAY
const DAY0: int = Kit.DAY0


func after_each() -> void:
	if Game.combat != null:
		Game.end_combat()
	Game.state = null
	Game.run_log = null
	Game.sim = null
	Game.mode = &"campaign"
	Game.timer_running = false
	Game.in_battle = false


## The credits and followers of the run (a fee takes −30 % / −10 %).
static func _purse(s: RunSim, credits: int, followers: int) -> void:
	s.state.inventory.credits = credits
	s.state.show.followers = followers


# --- the staircase rule -----------------------------------------------------------------------------------------------

func test_staircase_rule_at_every_boundary() -> void:
	var d: GameData = Kit.data(18)
	var s: RunSim = Kit.sim(d, "ssn_akt3")
	var st: SeasonState = s.state.season
	for collapsed in range(0, 17):
		st.collapsed = collapsed
		for floor in range(collapsed + 1, 19):
			Kit.put_on_floor(s, floor)
			var want: String = ""
			if floor >= 18:
				want = "no_stairs"
			elif floor + 1 > maxi(3, collapsed + 2):
				want = "floor_closed"
			assert_eq(SeasonRules.stairs_refusal(s.state, d), want, "floor %d, %d collapsed" % [floor, collapsed])
	st.collapsed = 0
	for floor: int in [1, 2]:
		Kit.put_on_floor(s, floor)
		assert_eq(SeasonRules.stairs_refusal(s.state, d), "", "09 §2.6: floors 1–3 open from the start")
	Kit.put_on_floor(s, 3)
	assert_eq(SeasonRules.stairs_refusal(s.state, d), "floor_closed", "the first closed stairs: to floor 4")
	assert_eq(RunRules.command_refusal(s.state, d, {}, {"t": "descend"}, false, {}), "floor_closed",
		"the gate refuses the descent in both verifiers")
	st.tempo = "binge"
	assert_eq(SeasonRules.stairs_refusal(s.state, d), "", "Am Stück: no limit")
	var real: RunSim = Kit.sim(real_data())
	assert_eq(SeasonRules.last_floor(real.state, real.data), 6, "the real data: floors 1–6 (ST1-C1; 7–18: ST1-C2)")
	assert_eq(SeasonRules.stairs_refusal(real.state, real.data), "", "floor 1's stairs lead to floor 2")
	var akt2: RunSim = Kit.sim(real_data(), "ssn_akt2", "binge")
	Kit.put_on_floor(akt2, 6)
	assert_eq(SeasonRules.stairs_refusal(akt2.state, akt2.data), "",
		"a longer format (Am Stück): floor 6's stairs lead to the end of the content")
	var none: GameState = GameState.create_new(d, 0, "Kai", 1, &"prime")
	RunRules.start_floor(none, d, 3)
	assert_eq(RunRules.command_refusal(none, d, {}, {"t": "descend"}, false, {}), "", "no season: no rule")


func test_stairs_by_the_floor_on_air() -> void:
	var d: GameData = Kit.data()
	var s: RunSim = Kit.sim(d)
	for f: int in [1, 2]:
		s.apply({"t": "descend"})
		s.apply({"t": "floor", "floor": f + 1})
	assert_eq([s.state.floor_run.index, s.state.season.stairs], [3, 2], "the first evening: down to floor 3")
	var n: int = s.rejected_cmds.size()
	s.apply({"t": "descend"})
	assert_eq([s.rejected_cmds.size(), s.rejected_cmds.back()["reason"]], [n + 1, "floor_closed"])
	Kit.clock_to(s, DAY0 + 5 * DAY - 60)
	assert_eq(SeasonRules.opens_in(s.state, 4), 60, "Kulissen im Aufbau — öffnet in 1 min")
	Kit.clock_to(s, DAY0 + 5 * DAY)
	assert_eq(s.state.floor_run.index, 3, "the candidate was ahead: no collapse hit")
	s.apply({"t": "descend"})
	s.apply({"t": "floor", "floor": 4})
	assert_eq([s.state.floor_run.index, s.state.season.stairs, s.state.season.descent_at], [4, 3, DAY0 + 5 * DAY])
	s.apply({"t": "descend"})
	assert_eq(s.rejected_cmds.back()["reason"], "floor_closed", "floor 5 opens with the collapse of floor 3")


# --- collapses ------------------------------------------------------------------------------------------------------

func test_collapse_logged_in_with_the_weekly_fee() -> void:
	var d: GameData = Kit.data()
	var s: RunSim = Kit.sim(d)
	var st: SeasonState = s.state.season
	_purse(s, 1000, 500)
	var ev: Array = Kit.clock_to(s, DAY0 + 2 * DAY)
	var r1: Dictionary = Kit.event(ev, "rescue")
	assert_eq([r1["from"], r1["floor"], r1["credits"], r1["waived"]], [1, 2, 0, "rehearsal"],
		"floor 1 is the dress rehearsal: a free rescue")
	assert_eq([st.vest, st.rescues, s.state.inventory.credits], [true, 0, 1000], "the vest stays, nothing counts")
	assert_eq(String(s.state.floor_run.location), r1["location"])
	assert_true(String(s.state.floor_run.location).begins_with("sr_f2_"), "the first safe room of floor 2")
	ev = Kit.clock_to(s, DAY0 + 5 * DAY)
	var r2: Dictionary = Kit.event(ev, "rescue")
	assert_eq([r2["floor"], r2["credits"], r2["followers"], r2["waived"]], [3, 300, 50, ""], "−30 % credits, −10 % fol.")
	assert_eq([s.state.inventory.credits, s.state.show.followers, st.vest, st.rescues, st.fee_at],
		[700, 450, false, 1, DAY0 + 5 * DAY])
	assert_false(Kit.kinds(ev).has("floor_completed"))
	ev = Kit.clock_to(s, DAY0 + 9 * DAY)
	assert_eq(Kit.event(ev, "rescue")["waived"], "week", "four days later: no second fee (V-9)")
	assert_eq([s.state.inventory.credits, st.rescues], [700, 2])
	ev = Kit.clock_to(s, DAY0 + 14 * DAY)
	assert_eq([Kit.event(ev, "rescue")["credits"], s.state.inventory.credits], [210, 490], "nine days later: a fee")
	assert_eq(SeasonRules.quote(s.state), 405 / 10 - 3 * 500, "rescues cost Quote (floor 1 not); followers / 10")


func test_collapse_hits_only_the_floor_on_air() -> void:
	var d: GameData = Kit.data()
	var s: RunSim = Kit.sim(d)
	s.apply({"t": "descend"})
	s.apply({"t": "floor", "floor": 2})
	var ev: Array = Kit.clock_to(s, DAY0 + 2 * DAY)
	assert_eq(Kit.kinds(ev).filter(func(k: String) -> bool: return k == "rescue" or k == "out"), [],
		"wer schon tiefer ist, ist nicht betroffen (09 §2.5 Nr. 1)")
	assert_eq([s.state.season.collapsed, s.state.floor_run.index], [1, 2])


func test_collapse_as_a_sleeper() -> void:
	var d: GameData = Kit.data()
	var s: RunSim = Kit.sim(d)
	s.apply({"t": "descend"})
	s.apply({"t": "floor", "floor": 2})
	var layout: FloorLayout = DungeonGenerator.generate(d.floor_def(2), s.state.floor_run.seed)
	var sr: String = str(layout.safe_room_ids[layout.safe_rooms[0]])
	s.apply({"t": "safe_room", "id": sr})
	_purse(s, 1000, 500)
	s.apply({"t": "sleep", "tactic": "careful"})
	var st: SeasonState = s.state.season
	assert_eq([st.asleep, st.sleep_tactic, st.sleep_room], [true, "careful", sr], "09 §5.1: the sleeper stays there")
	assert_eq(SeasonRules.refusal(s.state, d, {"t": "clock", "sec": 60}), "asleep", "the absence is \"away\"")
	assert_eq(RunRules.command_refusal(s.state, d, {}, {"t": "room", "cell": [0, 0]}, false, {}), "asleep")
	var ev: Array = SeasonRules.advance(s.state, d, DAY0 + 5 * DAY - st.utc)   # ST1-G's away goes this way
	var r: Dictionary = Kit.event(ev, "rescue")
	assert_eq([r["floor"], r["waived"], s.state.inventory.credits], [3, "sleeper", 1000],
		"09 §2.5 Nr. 3: a sleeper in a safe room is carried for free")
	assert_eq([st.vest, st.rescues], [false, 1], "still a rescue (the vest goes)")
	assert_eq(st.sleep_room, String(s.state.floor_run.location), "sleeps on in the first safe room of floor 3")
	assert_ne(st.sleep_room, "")
	# a sleeper in a corridor pays (the weekly rule permitting)
	var c: RunSim = Kit.sim(d)
	c.apply({"t": "descend"})
	c.apply({"t": "floor", "floor": 2})
	_purse(c, 1000, 500)
	c.apply({"t": "sleep", "tactic": "attack"})
	assert_eq(c.state.season.sleep_room, "", "a corridor")
	ev = SeasonRules.advance(c.state, d, DAY0 + 5 * DAY - c.state.season.utc)
	assert_eq([Kit.event(ev, "rescue")["credits"], c.state.season.sleep_room != ""], [300, true],
		"the rescue puts the sleeper into a safe room (09 §5.5)")


func test_collapse_waits_for_a_combat_then_two_minutes() -> void:
	var d: GameData = Kit.data()
	var s: RunSim = Kit.sim(d)
	s.apply({"t": "descend"})
	s.apply({"t": "floor", "floor": 2})
	_purse(s, 0, 0)
	Kit.clock_to(s, DAY0 + 5 * DAY - 30)
	SeasonRules.on_combat_end(s.state, d, Kit.result(BattleResult.Outcome.VICTORY))
	var ev: Array = s.apply({"t": "clock", "sec": 90})            # the combat's time, caught up after it (V-17)
	assert_eq(Kit.event(ev, "hold"), {"kind": "hold", "floor": 2, "until": DAY0 + 5 * DAY + 60 + 120},
		"the collapse waits until two minutes after the combat")
	assert_eq([s.state.season.collapsed, s.state.floor_run.index], [1, 2])
	ev = s.apply({"t": "clock", "sec": 119})
	assert_eq(s.state.floor_run.index, 2, "Die Regie wartet. Kurz.")
	ev = s.apply({"t": "clock", "sec": 1})
	assert_eq([Kit.kinds(ev).has("rescue"), s.state.floor_run.index, s.state.season.hold_utc], [true, 3, 0])
	assert_eq(Kit.event(ev, "rescue")["credits"], 0, "no purse, no fee")
	# a second combat during the two minutes: it waits again
	var t: RunSim = Kit.sim(d)
	t.apply({"t": "descend"})
	t.apply({"t": "floor", "floor": 2})
	Kit.clock_to(t, DAY0 + 5 * DAY - 10)
	SeasonRules.on_combat_end(t.state, d, Kit.result(BattleResult.Outcome.FLED))
	t.apply({"t": "clock", "sec": 20})
	SeasonRules.on_combat_end(t.state, d, Kit.result(BattleResult.Outcome.VICTORY))
	ev = t.apply({"t": "clock", "sec": 200})
	assert_eq([Kit.event(ev, "hold")["until"], t.state.floor_run.index], [DAY0 + 5 * DAY + 210 + 120, 2])


func test_collapse_in_a_real_combat_through_run_sim() -> void:
	var d: GameData = Kit.data()
	var s: RunSim = Kit.sim(d)
	s.state.member("kai").level = 6
	Kit.clock_to(s, DAY0 + 2 * DAY - 5)
	var cmd: Dictionary = _rt_encounter(s)
	s.apply(cmd)
	assert_not_null(s.combat, "a real-time combat runs in the season")
	s.apply(RtCommand.autopilot(0, s.combat.controlled_id(), true))
	var ev: Array = s.apply({"t": "clock", "sec": 60})          # after the combat: its time (RunSim ends it first)
	assert_null(s.combat)
	assert_eq(Kit.event(ev, "hold")["until"], DAY0 + 2 * DAY + 55 + 120)
	assert_eq(s.state.floor_run.index, 1)
	ev = s.apply({"t": "clock", "sec": 120})
	assert_eq([Kit.event(ev, "rescue")["waived"], s.state.floor_run.index], ["rehearsal", 2])
	assert_eq(s.rejected_cmds, [] as Array[Dictionary])


func _rt_encounter(s: RunSim) -> Dictionary:
	var prev: GameState = Game.state
	Game.state = s.state
	var cmd: Dictionary = RtLive.encounter(real_data().floor_def(1).timer_start_after, BattleSetup.Advantage.PREEMPTIVE,
		"st1b_g1")
	Game.state = prev
	return cmd


# --- the dress rehearsal, Ohne Netz, the end ------------------------------------------------------------------------

func test_dress_rehearsal_and_ohne_netz() -> void:
	var d: GameData = Kit.data()
	var s: RunSim = Kit.sim(d, "ssn_basis", "calendar", "no_net")
	var ev: Array = Kit.clock_to(s, DAY0 + 2 * DAY)
	assert_eq([Kit.event(ev, "rescue")["waived"], s.state.season.result], ["rehearsal", ""],
		"09 §7.3: floor 1 is the dress rehearsal — also Ohne Netz")
	ev = Kit.clock_to(s, DAY0 + 5 * DAY)
	assert_eq(Kit.event(ev, "out"), {"kind": "out", "why": "buried", "floor": 2}, "Ohne Netz: raus ab Etage 2")
	var st: SeasonState = s.state.season
	assert_eq([st.result, st.result_floor, s.state.floor_run.index], ["buried", 2, 2])
	assert_true(SeasonRules.is_spectator(s.state), "a studio guest (09 §7.2)")
	assert_eq(RunRules.command_refusal(s.state, d, {}, {"t": "room", "cell": [0, 0]}, false, {}), "season_over")
	assert_eq(SeasonRules.refusal(s.state, d, {"t": "clock", "sec": 60}), "", "the season goes on for the guest")
	assert_eq(SeasonRules.titles(s.state, d), PackedStringArray(["Studiogast, verschüttet auf Etage 2 (privat)"]))
	Kit.clock_to(s, DAY0 + 24 * DAY)
	assert_eq([st.collapsed, st.result, SeasonRules.season_over(s.state)], [6, "buried", true])
	assert_eq(SeasonRules.refusal(s.state, d, {"t": "clock", "sec": 60}), "season_over")


func test_last_collapse_and_the_end_of_the_data() -> void:
	var d: GameData = Kit.data()
	var s: RunSim = Kit.sim(d)
	Kit.put_on_floor(s, 6)
	s.state.season.collapsed = 5
	s.state.season.next_air_utc = DAY0 + 25 * DAY
	s.state.season.utc = DAY0 + 23 * DAY
	var ev: Array = s.apply({"t": "clock", "sec": DAY})
	assert_eq(Kit.event(ev, "end"), {"kind": "end", "why": "last", "floor": 6}, "Letzter Einsturz = Staffelende")
	assert_eq(s.state.season.result, "end")
	assert_true(SeasonRules.unlocks_no_net(s.state), "a season played to its end unlocks Ohne Netz (V-7)")
	# ST1-C1: the real data end after floor 6 — the finale floor of the basis format, so only a longer format (Akt 2;
	# Am Stück: its stairs are open) still meets the end of the content there.
	var real: RunSim = Kit.sim(real_data(), "ssn_akt2", "binge")
	Kit.put_on_floor(real, 6)
	ev = real.apply({"t": "descend"})
	assert_eq(Kit.kinds(ev), ["end"], "ST1-B decision: the stairs of the last playable floor end the season")
	assert_eq(Kit.event(ev, "end"), {"kind": "end", "why": "content", "floor": 6})
	assert_eq([real.state.season.result, real.state.season.stairs], ["end", 1], "Bis zum Ende dabei; the stairs count")
	real.apply({"t": "floor", "floor": 7})
	assert_eq(real.rejected_cmds.back()["reason"], "season_over", "no floor after the end")
	var stay: RunSim = Kit.sim(real_data(), "ssn_akt2")
	Kit.put_on_floor(stay, 6)
	stay.state.season.collapsed = 5
	ev = Kit.clock_to(stay, stay.state.season.collapse_utc[5])
	assert_eq(Kit.event(ev, "end"), {"kind": "end", "why": "content", "floor": 6},
		"or its collapse: a rescue never goes to a floor without content")
	assert_false(Kit.kinds(ev).has("rescue"))


func test_floor_balance_only_by_the_stairs() -> void:
	var d: GameData = Kit.data()
	var s: RunSim = Kit.sim(d)
	var ev: Array = s.apply({"t": "descend"})
	assert_eq([ev.size(), (ev[0] as ExploreEvent).type], [1, ExploreEvent.Type.FLOOR_COMPLETED],
		"the stairs: the Etagen-Bilanz as today (09 §2.5 Nr. 7)")
	s.apply({"t": "floor", "floor": 2})
	ev = Kit.clock_to(s, DAY0 + 5 * DAY)
	for e: ExploreEvent in ev:
		assert_ne(e.type, ExploreEvent.Type.FLOOR_COMPLETED, "a rescue has no balance (09 §2.5 Nr. 3)")
	assert_eq([s.state.season.stairs, s.state.season.rescues], [1, 1])


func test_binge_countdown_end_is_the_collapse() -> void:
	var d: GameData = Kit.data()
	var s: RunSim = Kit.sim(d, "ssn_basis", "binge")
	var fr: FloorRun = s.state.floor_run
	fr.timer_started = true
	var ev: Array = s.step(36000)
	assert_eq(Kit.kinds(ev), ["collapse", "rescue"], "20:00 Am Stück: floor 1 collapses at 0:00")
	assert_false(s.is_over(), "never the end of the run in a season")
	assert_eq([s.state.floor_run.index, s.state.floor_run.time_left_ticks, s.state.season.vest], [2, 54000, true])
	s.apply({"t": "safe_room_exit"})
	ev = s.step(54000)
	assert_eq(Kit.kinds(ev), ["collapse", "rescue"])
	assert_eq([s.state.floor_run.index, s.state.season.rescues, s.state.season.vest], [3, 1, false])
	assert_eq(s.rejected_cmds, [] as Array[Dictionary])
