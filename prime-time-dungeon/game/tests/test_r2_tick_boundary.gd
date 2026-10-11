extends TestCase
## The tick loop of the CombatDirector and the live API of Game (07 §9.2, §10.2, §10.6, §2.13, §3.15; R2): per combat
## tick c first the boundary (Game.combat_boundary: at most one gift), then every input with ct == c
## (Game.combat_submit), then Game.combat_step(); a hint card holds the ticks (no tick passes, the hint is recorded at
## the halted ct, inputs given meanwhile keep that ct); at most MAX_CATCHUP ticks per frame; the combat speed scales
## real time per tick; checkpoints every CHECKPOINT_TICKS and at the end; the end order; the combat_speed command and
## the --combat boot argument. The sim is a spy over the world fixture stream (tests/fixtures/rt_world).

const WorldStream := preload("res://tests/fixtures/rt_world/world_stream.gd")
const GEO: Dictionary = {"r": 480, "doors": 0, "closed": false, "blockers": []}


## FakeRtSim that traces the calls the tick loop makes: "fin@c" (is_finished from outside), "submit:<t>@c", "step@c",
## "gift@c".
class SpySim extends FakeRtSim:
	var trace: Array[String] = []
	var _inner: int = 0

	func _init(p_stream: Dictionary, p_data: GameData) -> void:
		super(p_stream, p_data)

	func is_finished() -> bool:
		if _inner == 0:
			trace.append("fin@%d" % _tick)
		return super()

	func submit(cmd: Dictionary) -> String:
		trace.append("submit:%s@%d" % [str(cmd.get("t", "")), _tick])
		_inner += 1
		var r: String = super(cmd)
		_inner -= 1
		return r

	func step() -> Array[ActionEvent]:
		trace.append("step@%d" % _tick)
		_inner += 1
		var out: Array[ActionEvent] = super()
		_inner -= 1
		return out

	func apply_gift(g: Dictionary) -> Array[ActionEvent]:
		trace.append("gift@%d" % _tick)
		return super(g)


var _speed: int = 1000
var _spy: SpySim = null


func before_each() -> void:
	_speed = Game.settings.combat_speed_pm
	Game.new_game(0, "Kai", 4242)
	Game.state.combat_mode = &"realtime"
	_spy = null


func after_each() -> void:
	if Game.combat != null:
		Game.end_combat()
	Game.rt_sim_factory = Callable()
	Game.settings.combat_speed_pm = _speed
	Game.combat_mode_override = &""


## A director without a scene (no bodies: the tick loop alone), armed, and a started combat of `plan`.
func _start(plan: String = "loop", length: int = 900) -> CombatDirector:
	var d: CombatDirector = CombatDirector.new()
	d.present_results = false
	d.use_hud = false
	d.auto_tick = false
	add_to_tree(d)
	d.arm({"cell": Vector2i(1, 4), "origin": Vector3.ZERO, "room_kind": 0, "room_doors": 0, "geo": GEO,
		"closed": false, "boss": false, "groups": PackedStringArray(["f1_g1"]), "waiting": PackedStringArray()})
	Game.rt_sim_factory = func(cmd: Dictionary, seed: int) -> RtSim:
		var b: RefCounted = WorldStream.new()
		b.set("data", DB.data)
		b.set("plan", plan)
		b.set("geo", GEO)
		_spy = SpySim.new(b.call("build", cmd, seed, length), DB.data)
		return _spy
	var setup: RtSetup = Game.make_rt_setup(_cmd())
	assert_not_null(setup, "the combat starts")
	assert_true(d.is_running(), "the armed director runs it")
	return d


static func _cmd() -> Dictionary:
	return {"t": "encounter", "enc": "enc_f1_a2", "adv": 0, "group": "f1_g1", "rt": {"v": 1, "cell": [1, 4],
		"ctl": "p0", "party": [{"u": "p0", "p": [0, 200, 0]}, {"u": "p1", "p": [0, 330, 0]}],
		"groups": [{"group": "f1_g1", "enc": "enc_f1_a2", "lead": [0, -250, 128], "state": "PATROL"}],
		"presets": {"p1": {"preset": "support", "tog": {}}}, "auto": true, "retarget": true, "open": {},
		"diff": "prime"}}


## Recorded commands of the run log after the encounter.
static func _recorded_after_encounter() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen: bool = false
	for row: Dictionary in Game.run_log.cmds():
		var cmd: Dictionary = row["c"]
		if str(cmd.get("t", "")) == "encounter":
			seen = true
			continue
		if seen:
			out.append(cmd)
	return out


func test_boundary_then_inputs_then_step_every_tick() -> void:
	var d: CombatDirector = _start()
	for i in 40:
		if i % 7 == 3:
			d.submit(RtCommand.target(0, "p0", "e0"))
		if i % 11 == 5:
			d.submit(RtCommand.auto_attack(0, "p0", i % 2 == 0))
		d.advance(1)
	assert_eq(Game.combat.tick(), 40, "40 ticks")
	# per tick c: an outside is_finished (the boundary) before the first input, every input before step@c
	var c: int = 0
	var boundary_seen: bool = false
	var inputs: int = 0
	for entry: String in _spy.trace:
		var at: int = int(entry.get_slice("@", 1))
		if entry.begins_with("step@"):
			assert_eq(at, c, "steps in order")
			assert_true(boundary_seen, "tick %d: the boundary ran before the step" % c)
			c += 1
			boundary_seen = false
		elif entry.begins_with("fin@") and at == c:
			boundary_seen = true
		elif entry.begins_with("submit:"):
			assert_eq(at, c, "an input is submitted in its own tick")
			assert_true(boundary_seen, "tick %d: boundary before the inputs" % c)
			inputs += 1
	assert_eq(inputs, 10, "every input reached the sim")
	for s: Dictionary in _spy.submitted:
		assert_eq(str(s["answer"]), "", "accepted: %s" % str(s["cmd"]))
		assert_eq(int((s["cmd"] as Dictionary)["ct"]), int(s["tick"]), "ct = the tick it was processed in")
	# recorded in order: ct never falls (07 §10.2)
	var last_ct: int = -1
	for cmd: Dictionary in _recorded_after_encounter():
		if cmd.has("ct"):
			assert_true(int(cmd["ct"]) >= last_ct, "ct not falling in the run log")
			last_ct = int(cmd["ct"])


func test_at_most_one_gift_per_boundary() -> void:
	_start()
	var d: CombatDirector = get_director_in_tree()
	d.advance(120)
	var per_tick: Dictionary = {}
	for entry: String in _spy.trace:
		if entry.begins_with("gift@"):
			per_tick[entry] = int(per_tick.get(entry, 0)) + 1
	for k: Variant in per_tick.keys():
		assert_eq(int(per_tick[k]), 1, "one gift at %s" % str(k))
	assert_eq(_spy.gifts_applied.size(), per_tick.size())
	Game.end_combat()
	Game.combat_boundary()                      # no combat: nothing happens
	assert_null(Game.combat)


func get_director_in_tree() -> CombatDirector:
	for n: Node in tree.root.get_children():
		if n is CombatDirector:
			return n as CombatDirector
	return null


func test_hint_card_holds_the_ticks_and_keeps_the_ct() -> void:
	var d: CombatDirector = _start()
	d.advance(30)
	var halted: int = Game.combat.tick()
	d.pause_for_hint("interrupt")
	assert_true(d.is_paused_for_hint())
	d.advance(10)
	d._physics_process(1.0)
	assert_eq(Game.combat.tick(), halted, "no tick passes while the card stands")
	var hint_cmd: Dictionary = {}
	for cmd: Dictionary in _recorded_after_encounter():
		if str(cmd.get("t", "")) == "combat_hint":
			hint_cmd = cmd
	assert_eq(hint_cmd, {"t": "combat_hint", "ct": halted, "id": "interrupt"}, "recorded at the halted ct")
	assert_true(bool((Game.state.flags.get("rt_hints", {}) as Dictionary).get("interrupt", false)),
		"state.flags.rt_hints marks the card as shown")
	d.submit(RtCommand.target(0, "p0", "e1"))          # an input given during the card
	d.pause_for_hint("zone")                            # a second card cannot stack
	assert_eq(Game.state.flags["rt_hints"].get("zone", false), false)
	d.resume()
	assert_false(d.is_paused_for_hint())
	d.advance(1)
	assert_eq(Game.combat.tick(), halted + 1)
	var last: Dictionary = _spy.submitted[_spy.submitted.size() - 1]
	assert_eq(str((last["cmd"] as Dictionary)["t"]), "target_change")
	assert_eq(int((last["cmd"] as Dictionary)["ct"]), halted, "the input keeps the halted ct")


func test_catch_up_is_capped_and_the_speed_scales_real_time() -> void:
	var d: CombatDirector = _start()
	d.auto_tick = true
	var t0: int = Game.combat.tick()
	d._physics_process(1.0)                             # a 1 s hitch
	assert_eq(Game.combat.tick() - t0, CombatDirector.MAX_CATCHUP, "at most 4 ticks per frame, the rest dropped")
	t0 = Game.combat.tick()
	for i in 30:
		d._physics_process(1.0 / 60.0)
	assert_between(Game.combat.tick() - t0, 14, 15, "0.5 s = 15 ticks at 1000 ‰")
	Game.settings.combat_speed_pm = 700
	t0 = Game.combat.tick()
	for i in 60:
		d._physics_process(1.0 / 60.0)
	assert_between(Game.combat.tick() - t0, 20, 21, "1 s at 700 ‰ = 21 ticks")
	d.auto_tick = false


func test_end_order_checkpoints_and_cleanup() -> void:
	var order: Array[String] = []
	var on_fin: Callable = func(_r: RefCounted) -> void: order.append("combat_finished")
	var on_end: Callable = func(_o: int, _e: String) -> void: order.append("battle_ended")
	Events.combat_finished.connect(on_fin)
	Events.battle_ended.connect(on_end)
	var d: CombatDirector = _start("win", 700)
	d.advance(2000)
	Events.combat_finished.disconnect(on_fin)
	Events.battle_ended.disconnect(on_end)
	assert_null(Game.combat, "Game.end_combat ran")
	assert_false(Game.in_battle)
	assert_false(d.is_running())
	assert_eq(order, ["combat_finished", "battle_ended"])
	assert_not_null(d.last_result)
	assert_eq(int(d.last_result.outcome), BattleResult.Outcome.VICTORY)
	var cps: Array[int] = []
	for cp: Dictionary in Game.run_log.checkpoints():
		if cp.has("ct"):
			cps.append(int(cp["ct"]))
	assert_true(cps.has(300) and cps.has(600), "every CHECKPOINT_TICKS (300): %s" % str(cps))
	assert_eq(cps[cps.size() - 1], d.ticks_run, "and at the end")


func test_combat_speed_is_recorded_outside_combats() -> void:
	Game.settings.combat_speed_pm = 850
	Events.settings_changed.emit()
	var speeds: Array[int] = _speed_cmds()
	assert_eq(speeds, [850], "a change in a real-time run is recorded")
	Events.settings_changed.emit()
	assert_eq(_speed_cmds(), [850], "unchanged: nothing recorded")
	var d: CombatDirector = _start()
	Game.settings.combat_speed_pm = 700
	Events.settings_changed.emit()
	assert_eq(_speed_cmds(), [850], "in a combat the change waits (a command without ct would end it in a replay)")
	d.advance(5)
	Game.end_combat()
	assert_eq(_speed_cmds(), [850, 700], "recorded at the combat end")


func test_ctb_runs_record_no_combat_speed() -> void:
	Game.state.combat_mode = &"ctb"
	Game.settings.combat_speed_pm = 850
	Events.settings_changed.emit()
	assert_eq(_speed_cmds(), [], "CTB runs stay as they are")


func test_new_game_combat_mode_and_boot_argument() -> void:
	assert_eq(Game.combat_mode_from_args(PackedStringArray(["--autoplay", "--combat=realtime"])), &"realtime")
	assert_eq(Game.combat_mode_from_args(PackedStringArray(["--combat=ctb"])), &"ctb")
	assert_eq(Game.combat_mode_from_args(PackedStringArray(["--combat=turbo"])), &"")
	Game.combat_mode_override = &"realtime"
	Game.settings.combat_speed_pm = 700
	Game.new_game(0, "Kai", 4242)
	assert_true(Game.is_realtime(), "the boot argument wins over the setting")
	assert_eq(str(Game.run_log.header.get("combat_mode", "")), "realtime")
	assert_eq(int(Game.run_log.header.get("rt_version", 0)), 1)
	assert_eq(_speed_cmds(), [700], "a run that starts below 1000 ‰ records its speed")
	Game.combat_mode_override = &""
	Game.settings.combat_speed_pm = 1000
	Game.new_game(0, "Kai", 4242)
	assert_false(Game.is_realtime(), "CTB stays the default (GameSettings.combat_mode)")
	assert_false(Game.run_log.header.has("combat_mode"), "CTB headers unchanged")


static func _speed_cmds() -> Array[int]:
	var out: Array[int] = []
	for row: Dictionary in Game.run_log.cmds():
		var cmd: Dictionary = row["c"]
		if str(cmd.get("t", "")) == "combat_speed":
			out.append(int(cmd["pm"]))
	return out
