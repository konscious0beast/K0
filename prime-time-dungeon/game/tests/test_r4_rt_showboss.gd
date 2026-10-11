extends TestCase
## 07 §9.6 / §12.5 R4 test_r4_rt_showboss — the floor-1 show boss "Kanalratten-Gala" (E26) on the real data: the
## encounter enc_e1_showboss with its show_boss block (elite × 1.2, the "Strafzettel alle 8 Sekunden" rule, the banner
## line, a Fanpost box), its placement in zone B (f1_g15, real-time runs only), the RtMods of the combat (stats × 1.2,
## the shared rule) and a real combat: the ticket rule fires every 8 s from 4 s on, the reward arrives as a boss reward
## on VICTORY, a regular combat carries no show-boss mod.

const Harness := preload("res://tests/tools/rt_harness.gd")
const FixedMath := preload("res://core/stats/fixed_math.gd")
const ENC: String = "enc_e1_showboss"


func test_data_block_and_lines() -> void:
	var d: GameData = real_data()
	var enc: EncounterDef = d.encounter(ENC)
	assert_not_null(enc, ENC)
	var sb: Dictionary = enc.show_boss
	assert_eq(int(sb.get("elite_pm", 0)), 1200, "elite × 1.2")
	assert_eq(sb.get("reward", {}), {"kind": "box", "id": "box_fan"}, "a Fanpost box")
	var rule: Dictionary = sb.get("rule", {})
	assert_eq([str(rule.get("skill", "")), int(rule.get("first_ms", -1)), int(rule.get("every_ms", -1))],
		["skl_e_showboss_slow", 4000, 8000], "alle 8 s ein Strafzettel")
	assert_true(str(sb.get("banner_tag", "")).begins_with("showboss_"), "banner tag")
	assert_false(d.mod_lines(str(sb["banner_tag"])).is_empty(), "the banner has its M.O.D. line")
	assert_false(enc.boss or enc.tutorial, "an optional regular group")
	assert_false(d.skill("skl_e_showboss_slow").rt.is_empty(), "the rule skill has an rt block")


func test_placement_zone_b() -> void:
	var lay: Dictionary = {}
	for f: Variant in ((JsonUtil.read_file("res://data/floors.json") as Dictionary)["entries"] as Array):
		if int((f as Dictionary)["index"]) == 1:
			lay = (f as Dictionary)["layout"]
	var found: Dictionary = {}
	for p: Variant in (lay.get("encounters_placed", []) as Array):
		if str((p as Dictionary).get("enc_id", "")) == ENC:
			found = p
	assert_eq(str(found.get("group_id", "")), "f1_g15", "own group id after the regular ones")
	assert_eq(found.get("cell", []), [5, 4], "zone B (Kanalisation)")
	assert_eq(str(found.get("state", "")), "IDLE", "waits for the party")
	# off the critical path: without the room every stop of the floor (bosses, stairs, safe rooms, gates) stays as near
	var room := Vector2i(5, 4)
	var stops: Array[Vector2i] = []
	for c: Variant in (lay["cells"] as Array):
		if str((c as Dictionary)["kind"]) in ["quarter_boss", "floor_boss", "stairs"]:
			stops.append(Vector2i(int(c["x"]), int(c["y"])))
	for s: Variant in (lay["safe_rooms"] as Array) + (lay["gates"] as Array):
		stops.append(Vector2i(int(s["cell"][0]), int(s["cell"][1])))
	var with_room: Dictionary = _distances(lay, Vector2i(-99, -99))
	var without: Dictionary = _distances(lay, room)
	assert_eq(stops.size(), 8, "2 bosses, the stairs, 3 safe rooms, 2 gates")
	for s: Vector2i in stops:
		assert_true(with_room.has(s), "stop %s reachable" % s)
		assert_eq(without.get(s, -1), with_room[s], "stop %s needs no way through the show boss room" % s)


## Door distances (cells) from the start cell of a floor layout, never entering `skip`.
static func _distances(lay: Dictionary, skip: Vector2i) -> Dictionary:
	const STEP: Dictionary = {"N": Vector2i(0, -1), "E": Vector2i(1, 0), "S": Vector2i(0, 1), "W": Vector2i(-1, 0)}
	var doors: Dictionary = {}
	var start := Vector2i(-1, -1)
	for c: Variant in (lay["cells"] as Array):
		var p := Vector2i(int(c["x"]), int(c["y"]))
		doors[p] = str(c["doors"])
		if str(c["kind"]) == "start":
			start = p
	var dist: Dictionary = {start: 0}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var p: Vector2i = queue.pop_front()
		for d: String in str(doors[p]):
			var q: Vector2i = p + (STEP[d] as Vector2i)
			if q != skip and doors.has(q) and not dist.has(q):
				dist[q] = int(dist[p]) + 1
				queue.append(q)
	return dist


func test_mods_of_the_combat() -> void:
	var d: GameData = real_data()
	var mods: Array[Dictionary] = RtMods.from_show_boss(d.encounter(ENC))
	var ops: Array = []
	for m: Dictionary in mods:
		ops.append([str(m["op"]), str(m.get("stat", "")), int(m.get("pm", 0))])
	assert_eq(ops, [["stat_pm", "max_hp", 1200], ["stat_pm", "str", 1200], ["add_rule", "", 0]])
	assert_eq(RtMods.validate(mods), PackedStringArray(), "valid mods")
	var st: GameState = Harness.state_for(d, ENC, "kai", 0, 0)
	var setup: RtSetup = BattleBridge.make_rt_setup(st, d, Harness.command_for(ENC, "kai", BattleSetup.Advantage.NORMAL),
		7)
	var srcs: Dictionary = {}
	for m: Dictionary in setup.mods:
		srcs[str(m["src"])] = true
	assert_true(srcs.has("showboss:" + ENC), "make_rt_setup carries the show-boss mods")
	var plain: RtSetup = BattleBridge.make_rt_setup(st, d, Harness.command_for("enc_f1_b2", "kai",
		BattleSetup.Advantage.NORMAL), 7)
	for m: Dictionary in plain.mods:
		assert_false(str(m["src"]).begins_with("showboss:"), "a regular combat has no show-boss mod")
	var elite: int = 0
	var normal: int = 0
	for u: RtUnit in RtSim.new(setup, d).units():
		if u.def_id == "enm_rattenschamane":
			elite = u.max_hp()
	for u: RtUnit in RtSim.new(plain, d).units():
		if u.def_id == "enm_rattenschamane":
			normal = u.max_hp()
	assert_eq(elite, FixedMath.mul_pm(normal, 1200), "the shaman of the gala: max HP × 1.2")


func test_ticket_rule_and_reward_in_a_real_combat() -> void:
	var d: GameData = real_data()
	var st: GameState = Harness.state_for(d, ENC, "kai", 0, 1)
	var sim: RtSim = RtSim.new(BattleBridge.make_rt_setup(st, d,
		Harness.command_for(ENC, "kai", BattleSetup.Advantage.NORMAL), SeedUtil.derive(4242, "harness", 1)), d)
	var bot: RefCounted = (load("res://tests/tools/rt_bot_player.gd") as GDScript).new(sim, "perfect", 11)
	var tickets: Array[int] = []
	sim.start()
	while not sim.is_finished() and sim.tick() < 3000:
		bot.call("act")
		var evs: Array[ActionEvent] = sim.step()
		bot.call("observe", evs)
		for e: ActionEvent in evs:
			if e.skill_id == "skl_e_showboss_slow" and (e.type == ActionEvent.Type.ACTION_START
					or e.type == ActionEvent.Type.CAST_START):
				tickets.append(e.tick)
	assert_true(sim.is_finished(), "the gala ends")
	assert_gt(tickets.size(), 0, "the gala hands out tickets")
	if tickets.size() > 0:
		assert_between(tickets[0], 120, 150, "first ticket at 4 s (+ AI think offset)")
	for i in range(1, tickets.size()):
		assert_between(tickets[i] - tickets[i - 1], 240, 270, "every 8 s (07 §9.6 rule)")
	assert_eq(sim.result.outcome, BattleResult.Outcome.VICTORY, "won with the perfect bot")
	var boxes: Array = []
	for r: Dictionary in sim.result.boss_rewards:
		if str(r.get("kind", "")) == "box":
			boxes.append(str(r.get("id", "")))
	assert_eq(boxes, ["box_fan"], "the Fanpost box as a boss reward")
