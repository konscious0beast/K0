extends TestCase
## Show.receive_gift as the single gift entry (Brief §6b.4, 05 §11.4) with the M8 gift core: a system gift from
## take_pending_gift runs through receive_gift and is NOT in the run log; a dev gift is in the log (cmd id 0) and
## replays; the Pur-Liga rejects dev gifts; duplicates and invalid gifts are rejected.

var _received: Array = []
var _rejected: Array = []


func before_each() -> void:
	_received = []
	_rejected = []
	Events.gift_received.connect(_on_received)
	Events.gift_rejected.connect(_on_rejected)


func after_each() -> void:
	Events.gift_received.disconnect(_on_received)
	Events.gift_rejected.disconnect(_on_rejected)
	Game.state = null
	Game.run_log = null
	Game.sim = null
	Game.quest = null
	Game.mode = &"campaign"
	Game.timer_running = false
	Game.in_battle = false
	Game.auto_battle = false


func _on_received(g: Dictionary) -> void:
	_received.append(str(g.get("gift_id", "")))


func _on_rejected(gift_id: String, reason: String) -> void:
	_rejected.append([gift_id, reason])


func _gift_cmds() -> Array:
	var out: Array = []
	for c: Dictionary in Game.run_log.cmds():
		if c["c"]["t"] == "gift":
			out.append([c["id"], c["c"]["gift"]["gift_id"]])
	return out


## §5.7 battle without scenes: start, then turns with recorded commands. `hook` runs once at the first turn boundary,
## `chooser(battle) -> BattleCommand` may pick a party command (null → AutoPolicy / EnemyAI).
func _battle(enc: String, hook: Callable = Callable(), chooser: Callable = Callable()) -> BattleState:
	var setup: BattleSetup = Game.make_battle_setup(enc, BattleSetup.Advantage.NORMAL, "")
	var battle: BattleState = BattleState.new(setup, DB.data)
	Show.begin_battle(setup)
	Events.battle_started.emit(setup.encounter_id, setup.is_boss)
	_feed(battle.start())
	if hook.is_valid():
		hook.call(battle)
	_boundary(battle)
	var guard: int = 0
	while not battle.is_finished() and guard < 400:
		guard += 1
		var cmd: BattleCommand = chooser.call(battle) as BattleCommand if chooser.is_valid() else null
		if cmd == null:
			cmd = battle.choose_ai_command()
		Game.record({"t": "battle", "cmd": cmd.to_dict(), "auto": not chooser.is_valid()})
		_feed(battle.submit(cmd))
		_boundary(battle)
	Events.battle_ended.emit(battle.result.outcome, battle.result.encounter_id)
	Game.apply_battle_result(battle.result)
	Show.end_battle(battle.result)
	return battle


func _feed(events: Array[ActionEvent]) -> void:
	for e: ActionEvent in events:
		Show.on_battle_event(e)


func _boundary(battle: BattleState) -> void:
	if battle.is_finished():
		return
	var g: Dictionary = Show.take_pending_gift(battle)
	if not g.is_empty():
		var events: Array[ActionEvent] = battle.apply_gift(g)
		Show.note_battle_gift(g, events)
		_feed(events)


## Recorded path to a hype threshold: a dev gold gift pays for a Hype-Megafon (Automat), used in battle: 30 + 5
## (battle start) + 25 → crosses 50 → system gift. Everything that changes the state is in the log.
func test_system_gift_runs_through_receive_gift_and_is_not_logged() -> void:
	Game.new_game(0, "Kai", 4711)
	assert_true(Game.open_dev_sponsor_window(), "viewer gifts need an open Sponsor-Fenster (05 §6.13, recorded)")
	var sr: String = str((DB.floor_def(1).layout.get("safe_rooms", []) as Array)[0]["id"])
	assert_eq(Show.receive_gift(Gift.make_dev("gold", "", 100))["apply"], "now")
	Game.enter_safe_room(sr)
	assert_true(Game.buy("itm_hype_megaphone", 1, sr), "150 credits buy the megaphone (120)")
	Game.leave_safe_room()
	var used: Array = [false]
	_battle(DB.floor_def(1).timer_start_after, Callable(), func(battle: BattleState) -> BattleCommand:
		var actor: Combatant = battle.current_actor()
		if used[0] or actor == null or not actor.is_party() or not battle.usable_items().has("itm_hype_megaphone"):
			return null
		used[0] = true
		return BattleCommand.item(actor.id, "itm_hype_megaphone", PackedStringArray([actor.id])))
	assert_true(used[0], "megaphone used")
	var sys: Array = _received.filter(func(id: String) -> bool: return id.begins_with("g_sys_"))
	assert_gt(sys.size(), 0, "hype 50 crossed → system gift delivered through receive_gift (gift_received)")
	var logged: Array = []
	for c: Array in _gift_cmds():
		logged.append(c[1])
	assert_eq(logged.size(), 1, "only the dev gift is in the log")
	for id: Variant in sys:
		assert_false(logged.has(id), "system gift %s is reproducible from the show rng → not logged" % id)
	var live_hash: String = StateHash.of(Game.state)
	var res: Dictionary = Game.replay_log(Game.run_log)
	assert_eq(res["final_hash"], live_hash, "the replay recreates the system gift by itself")
	_assert_game_checkpoints(Game.run_log, res)


func test_dev_gift_outside_battle_is_logged_and_replays() -> void:
	Game.new_game(0, "Kai", 815)
	assert_true(Game.open_dev_sponsor_window(), "viewer gifts need an open Sponsor-Fenster (05 §6.13, recorded)")
	var credits: int = Game.state.inventory.credits
	var dev: Dictionary = Gift.make_dev("gold", "", 100)
	var res: Dictionary = Show.receive_gift(dev)
	assert_eq([res["ok"], res["reason"], res["apply"]], [true, "", "now"])
	assert_eq(Game.state.inventory.credits, credits + 100, "GiftApplier → Game.add_rewards")
	assert_eq(_gift_cmds(), [[0, dev["gift_id"]]], "recorded at application with cmd id 0")
	var live: Dictionary = Game.state.flags["live"]
	assert_eq([live["load_half"], live["external"]], [1, 1], "run counters (GiftPolicy.note_applied)")
	assert_eq(Show.receive_gift(dev)["reason"], "duplicate", "same gift id twice")
	var bad: Dictionary = Gift.make_dev("chest", "bronze", 0)
	bad["run_bound"] = false
	assert_eq(Show.receive_gift(bad)["reason"], "invalid_schema")
	assert_eq(_rejected, [[dev["gift_id"], "duplicate"], [bad["gift_id"], "invalid_schema"]], "gift_rejected")
	var live_hash: String = StateHash.of(Game.state)
	var rep: Dictionary = Game.replay_log(Game.run_log)
	assert_eq(rep["final_hash"], live_hash, "Game.replay_log feeds the gift command to Show.receive_gift")
	_assert_game_checkpoints(Game.run_log, rep)


func test_dev_gift_in_battle_is_logged_at_delivery_and_replays() -> void:
	Game.new_game(0, "Kai", 2323)
	assert_true(Game.open_dev_sponsor_window(), "viewer gifts need an open Sponsor-Fenster (05 §6.13, recorded)")
	var dev: Dictionary = Gift.make_dev("chest", "bronze", 0)
	_battle(DB.floor_def(1).timer_start_after, func(_battle_state: BattleState) -> void:
		assert_eq(Show.receive_gift(dev)["apply"], "queued", "in battle: queued")
		assert_eq(_gift_cmds(), [], "not recorded on reception"))
	var kinds: Array = []
	for c: Dictionary in Game.run_log.cmds():
		kinds.append(c["c"]["t"])
	assert_eq(kinds.slice(0, 5), ["floor", "hero", "sponsor_window", "encounter", "gift"],
		"recorded at the turn boundary where it was delivered (hero: the new game's choice, 06 §1.7)")
	assert_has(_received, dev["gift_id"])
	var live_hash: String = StateHash.of(Game.state)
	var rep: Dictionary = Game.replay_log(Game.run_log)
	assert_eq(rep["final_hash"], live_hash, "replayed at the same _play boundary (02_TECH §3.4)")
	_assert_game_checkpoints(Game.run_log, rep)


## Fan pack of a service source with a load basis stamped by the gift service (05 §6.10).
func _fan_pack(n: int, load_half: int) -> Dictionary:
	var g: Dictionary = Gift.make_dev("fan_pack", "", 0)
	g["gift_id"] = "g_fan_cr_%d" % n
	g["source"] = "fan"
	g["sender"] = {"display_name": "Fan %d" % n, "anon": false, "sender_ref": "b_" + str(n).pad_zeros(12)}
	g["load_half"] = load_half
	g["effect_pm"] = GiftPolicy.effect_pm(load_half)
	return g


## M8 CR 3 / M2 VERIFY: gifts queued in a battle are checked AGAIN when they are applied (in battle at the turn
## boundary, or after the battle) and booked into the run counters like RunSim does — two service gifts with the same
## load basis: the first is applied, the second is refused as effect_mismatch at application (not on reception), and
## live run ≡ Game.replay_log.
func test_queued_gifts_are_rechecked_and_booked_at_application() -> void:
	Game.new_game(0, "Kai", 5150)
	assert_true(Game.open_dev_sponsor_window(), "viewer gifts need an open Sponsor-Fenster (05 §6.13, recorded)")
	var g1: Dictionary = _fan_pack(1, 0)
	var g2: Dictionary = _fan_pack(2, 0)
	assert_eq(Gift.validate(g1), "", Gift.last_detail)
	_battle(DB.floor_def(1).timer_start_after, func(_b: BattleState) -> void:
		assert_eq(Show.receive_gift(g1)["apply"], "queued")
		assert_eq(Show.receive_gift(g2)["apply"], "queued", "same basis is fine while nothing was applied"))
	assert_has(_received, g1["gift_id"], "first gift delivered at a turn boundary")
	assert_false(_received.has(g2["gift_id"]), "second gift not applied")
	assert_has(_rejected, [g2["gift_id"], "effect_mismatch"], "refused when it was due (after the battle)")
	var logged: Array = []
	for c: Array in _gift_cmds():
		logged.append(c[1])
	assert_eq(logged, [g1["gift_id"]], "only the applied gift is in the log")
	var live: Dictionary = Game.state.flags["live"]
	assert_eq(live["gift_ids"], [g1["gift_id"]], "in-battle delivery remembered once")
	assert_false(live.has("counted"), "booked once at the hand-out — no second id list (quality-6)")
	assert_eq([live["load_half"], live["external"]], [2, 1], "fan_pack weight 2 half-points")
	assert_true(live.get("gift_items", null) is Dictionary, "gift items booked (GiftApplier.note_battle_gift)")
	var live_hash: String = StateHash.of(Game.state)
	var rep: Dictionary = Game.replay_log(Game.run_log)
	assert_eq(rep["final_hash"], live_hash, "live run ≡ replay (the refused gift is in neither)")
	_assert_game_checkpoints(Game.run_log, rep)


## The deadline (deliver_by_tick, client sim) is checked against the run clock at application.
func test_queued_gift_past_its_deadline_is_refused_at_application() -> void:
	Game.new_game(0, "Kai", 5151)
	assert_true(Game.open_dev_sponsor_window(), "viewer gifts need an open Sponsor-Fenster (05 §6.13, recorded)")
	var late: Dictionary = Gift.make_dev("gold", "", 100)
	late["deliver_by_tick"] = 1
	Game.sim._tick = 5                        # the run clock is past the deadline
	assert_eq(Show.receive_gift(late)["reason"], "deadline_missed", "outside a battle: checked on reception")
	Game.sim._tick = 0
	Game.in_battle = true
	Show.begin_battle(Game.make_battle_setup(DB.floor_def(1).timer_start_after, BattleSetup.Advantage.NORMAL, ""))
	assert_eq(Show.receive_gift(late)["apply"], "queued", "tick 0: still in time")
	Game.sim._tick = 5
	assert_eq(Show.take_pending_gift(null), {}, "past the deadline when it is due")
	assert_has(_rejected, [late["gift_id"], "deadline_missed"])
	Show.abort_battle()
	Game.in_battle = false


## 05 §6.12 gift lines with their placeholders: {sender} only for a non-anonymous sender, {amount} = credits applied,
## gift_diminished {pct} below full effect, gift_capped / gift_declined on those refusals.
func test_gift_lines_name_sender_amount_and_refusals() -> void:
	Game.new_game(0, "Kai", 5152)
	assert_true(Game.open_dev_sponsor_window(), "viewer gifts need an open Sponsor-Fenster (05 §6.13, recorded)")
	var lines: Array = []
	var cb: Callable = func(text: String, _v: StringName, tag: String, _b: bool) -> void: lines.append([tag, text])
	Events.mod_said.connect(cb)
	var fan: Dictionary = _fan_pack(9, 0)
	Show.receive_gift(fan)
	assert_eq(str(lines[0][0]), "fan_pack_received")
	assert_true(str(lines[0][1]).contains("Fan 9"), "{sender} = display name: " + str(lines[0][1]))
	lines.clear()
	var gold: Dictionary = Gift.make_dev("gold", "", 250)
	gold["load_half"] = 2
	gold["effect_pm"] = GiftPolicy.effect_pm(2)
	Show.receive_gift(gold)
	var tags: Array = lines.map(func(l: Array) -> String: return str(l[0]))
	assert_eq(tags, ["gift_received:credits", "gift_diminished"])
	var credits: int = GiftPolicy.scale(250, gold["effect_pm"])
	assert_true(str(lines[0][1]).begins_with(str(credits)), "{amount}: " + str(lines[0][1]))
	assert_true(str(lines[1][1]).contains("%d Prozent" % (int(gold["effect_pm"]) / 10)), "{pct}: " + str(lines[1][1]))
	assert_false(str(lines[0][1]).contains("{"), "no raw placeholder left")
	lines.clear()
	Game.state.flags["live"]["gift_accept"] = "none"
	Show.receive_gift(Gift.make_dev("gold", "", 100))
	assert_eq(lines.map(func(l: Array) -> String: return str(l[0])), ["gift_declined"])
	Events.mod_said.disconnect(cb)


func test_pur_league_rejects_dev_gifts() -> void:
	Game.start_event_run("evt_offline_gleis9")
	if not Game.has_state():
		fail("start_event_run must create a state")
		return
	var credits: int = Game.state.inventory.credits
	var dev: Dictionary = Gift.make_dev("gold", "", 100)
	var res: Dictionary = Show.receive_gift(dev)
	assert_eq([res["ok"], res["reason"]], [false, "league_pur"], "L5: no viewer gifts in the Pur-Liga")
	assert_eq(_rejected, [[dev["gift_id"], "league_pur"]])
	assert_eq(Game.state.inventory.credits, credits, "nothing applied")
	assert_eq(_gift_cmds(), [], "nothing recorded")
	assert_eq(Show.receive_gift(Gift.make_system("spn_gluckwasser", 1, 0))["ok"], true,
		"system sponsor gifts stay part of the base game in the Pur-Liga")


## Game.replay_log compares checkpoints, but Game does not record any yet (pending CR 1: Game sets sim.run_log) — on
## such a log mismatch_at is -1 by construction and proves nothing, so the facade tests rely on final_hash. Once Game
## records checkpoints this checks both directions: all match, and a corrupted checkpoint hash is detected.
func _assert_game_checkpoints(rl: RunLog, res: Dictionary) -> void:
	if rl.checkpoints().is_empty():
		return
	assert_eq(res["mismatch_at"], -1, "every checkpoint of the live run matches")
	var d: Dictionary = rl.to_dict()
	((d["checkpoints"] as Array)[0] as Dictionary)["h"] = "0".repeat(64)
	assert_true(int(Game.replay_log(RunLog.from_dict(d))["mismatch_at"]) >= 0, "a corrupted checkpoint is detected")
