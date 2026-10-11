extends TestCase
## 07 §9.2 (R5a): Show.take_pending_gift_rt at the tick boundary of a real-time combat — the Sponsor-Fenster stands
## with the run clock and still takes gifts, an accepted gift waits for the next boundary and is recorded there with
## cmd id 0 and its "ct", system gifts at most 1 per regular / 2 per boss combat (one gift per boundary), an external
## and a system gift due in the same tick (external first, replayed alike), the Pur-Liga refuses viewer gifts in the
## combat as well.

const RtLive := preload("res://tests/fixtures/rt_live/rt_live.gd")

var _gift_ticks: Array = []                  # [type, tick] of the gift effects (rt.boundary)


func before_each() -> void:
	RtLive.swap_data()
	_gift_ticks = []
	Events.combat_event.connect(_on_event)


func after_each() -> void:
	Events.combat_event.disconnect(_on_event)
	if Game.combat != null:
		Game.end_combat()
	Show.abort_battle()
	Game.state = null
	Game.run_log = null
	Game.sim = null
	Game.in_battle = false
	RtLive.restore_data()


func _on_event(e: RefCounted) -> void:
	var ev: ActionEvent = e as ActionEvent
	if int(ev.rt.get("boundary", 0)) == 1 and (ev.type == ActionEvent.Type.SPONSOR_GIFT
			or ev.type == ActionEvent.Type.CREDITS_GAINED):
		_gift_ticks.append([ActionEvent.type_name(ev.type), ev.tick])


func test_the_standing_window_takes_a_gift_for_the_next_boundary() -> void:
	RtLive.adopt(RtLive.state(3, 20.0))
	assert_true(Game.open_dev_sponsor_window(60, 3))
	var left: int = int(Game.sponsor_window()["left_ticks"])
	assert_true(bool(Game.sponsor_window()["open"]))
	assert_not_null(Game.make_rt_setup(RtKit.dummy_cmd()))
	var k: int = Game.sim.tick()
	var gift: Dictionary = Gift.make_dev("gold", "", 100)
	var res: Dictionary = {}                                    # filled by the callback (captured by reference)
	RtLive.play([], 40, func(c: int) -> void:
		if c == 20:
			res.merge(Show.receive_gift(gift))
			assert_eq(RtLive.cmd_types(Game.run_log).count("gift"), 0, "not recorded on reception"))
	assert_eq([res.get("accepted"), res.get("apply")], [true, "queued"], "the window stands open in the combat")
	assert_eq(int(Game.sponsor_window()["left_ticks"]), left, "the run clock (and the window's countdown) stood still")
	assert_eq(_gift_ticks, [["CREDITS_GAINED", 21]], "applied at the boundary after the tick it arrived in")
	var rows: Array = Game.run_log.cmds().filter(func(r: Dictionary) -> bool: return r["c"]["t"] == "gift")
	assert_eq(rows.size(), 1)
	assert_eq([int(rows[0]["id"]), int(rows[0]["k"]), int(rows[0]["c"]["ct"])], [0, k, 21],
		"cmd id 0, the k of the encounter, its ct (07 §10.1)")


## The system gift of a crossed hype threshold: one per regular combat (a later crossing finds no slot), two per boss
## combat (the third crossing — the top one — only resets the hype to 80), one gift per boundary.
func test_system_gifts_one_per_regular_two_per_boss_combat() -> void:
	RtLive.adopt(RtLive.state(6, 66.0))
	assert_not_null(Game.make_rt_setup(RtKit.dummy_cmd()))
	assert_eq(Show.hype(), 69.0, "+3: no threshold yet")
	RtLive.play([], 30, func(c: int) -> void:
		if c == 2 or c == 5:
			Show.add_hype(16.0))
	assert_eq(_gift_ticks, [["SPONSOR_GIFT", 3]], "regular: crossing 70 → the gift at the next boundary; 85: none")
	_gift_ticks = []
	RtLive.adopt(RtLive.state(6, 66.0))
	assert_not_null(Game.make_rt_setup(RtKit.encounter("enc_rt_test_boss", [["g_boss", "enc_rt_test_boss",
		[0, -200, 128]]])))
	assert_eq(Show.hype(), 74.0, "+8 crossed 70 at the start")
	RtLive.play([], 30, func(c: int) -> void:
		if c == 5 or c == 10:
			Show.add_hype(16.0))
	assert_eq(_gift_ticks, [["SPONSOR_GIFT", 0], ["SPONSOR_GIFT", 6]], "boss: 70 and 85; the crossing of 100 none")
	assert_eq(Show.hype(), SponsorSystem.HYPE_AFTER_TOP, "the top threshold without a gift slot resets the hype")


## The mandatory case of 07 §9.2 in a boss combat (two gift slots): a viewer gift arrives in the tick in which the
## fight's own hype crosses 70 (the system gift falls due) → the external one at the boundary c + 1, the system gift
## at c + 2; Game.replay_log gives the same gift ticks and effects, the same combat checkpoints and the same final
## hash. In a regular combat (one slot, shared as in CTB) the external gift takes it and the threshold lapses.
func test_external_and_system_gift_due_in_the_same_tick() -> void:
	var gift: Dictionary = Gift.make_dev("gold", "", 100)
	var due: Array = []                                         # the tick of the crossing (captured by reference)
	var arrive: Callable = func(c: int) -> void:
		if due.is_empty() and Show.hype() >= SponsorSystem.THRESHOLDS[0]:
			due.append(c)
			assert_eq(Show.receive_gift(gift)["apply"], "queued")
	RtLive.adopt(RtLive.state(6, 50.0))
	assert_true(Game.open_dev_sponsor_window(60, 3))
	var boss: Dictionary = RtKit.encounter("enc_rt_test_boss", [["g_boss", "enc_rt_test_boss", [0, -200, 128]]])
	assert_not_null(Game.make_rt_setup(boss))
	assert_lt(Show.hype(), 70.0, "no threshold at the start (+8)")
	RtLive.play([RtCommand.ability(2, "p0", "skl_kai_heavy_swing", "e0")], 18000, arrive)
	assert_eq(due.size(), 1, "the combat's own hype crossed 70 (KOs, low HP)")
	var c: int = int(due[0]) if not due.is_empty() else -10
	var live: Array = _gift_ticks.duplicate(true)
	assert_eq(live.slice(0, 2), [["CREDITS_GAINED", c + 1], ["SPONSOR_GIFT", c + 2]],
		"external at the boundary after the tick, the system gift one boundary later")
	var h: String = StateHash.of(Game.state)
	_gift_ticks = []
	var res: Dictionary = Game.replay_log(Game.run_log)
	assert_eq([res["errors"], res["mismatch_at"], res["combat_mismatch_at"], res["final_hash"]],
		[PackedStringArray(), -1, -1, h], "the replay: no errors, every checkpoint, the same final hash")
	assert_eq(_gift_ticks, live, "the replay applies both gifts at the same boundaries with the same effects")
	# a regular combat: the external gift takes the one slot
	_gift_ticks = []
	due.clear()
	RtLive.adopt(RtLive.state(6, 64.0, {"itm_brutzel_burger": 2, "itm_energy_krawumm": 1, "itm_molotov": 1}))
	assert_true(Game.open_dev_sponsor_window(60, 3))
	RtLive.fight(RtKit.canned_encounter(), RtKit.canned_commands(), 6000, arrive)
	assert_eq(due.size(), 1)
	c = int(due[0]) if not due.is_empty() else -10
	assert_eq(_gift_ticks, [["CREDITS_GAINED", c + 1]], "regular: no second slot for the system gift")


func test_pur_liga_refuses_viewer_gifts_in_a_combat() -> void:
	var st: GameState = RtLive.state(3, 20.0)
	st.flags["live"] = {"league": "pur"}
	RtLive.adopt(st)
	assert_not_null(Game.make_rt_setup(RtKit.dummy_cmd()))
	var rejected: Array = []
	var cb: Callable = func(id: String, reason: String) -> void: rejected.append([id, reason])
	Events.gift_rejected.connect(cb)
	var g: Dictionary = Gift.make_dev("gold", "", 100)
	assert_eq(Show.receive_gift(g)["reason"], "league_pur", "05 L5: no viewer gifts in the Pur-Liga")
	Events.gift_rejected.disconnect(cb)
	RtLive.play([], 10)
	assert_eq(rejected, [[g["gift_id"], "league_pur"]])
	assert_eq(_gift_ticks, [], "nothing applied")
	# the core verifier refuses a forged one as well
	var sim: RunSim = RtLive.core_sim(RtLive.state(3, 20.0))
	sim.state.flags["live"] = {"league": "pur"}
	sim.apply(RtKit.dummy_cmd())
	assert_eq(RtLive.core_play(sim, [{"t": "gift", "ct": 2, "gift": Gift.make_dev("gold", "", 100)}]), ["league_pur"])
