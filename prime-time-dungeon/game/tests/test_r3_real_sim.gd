extends TestCase
## R3 against the real sim (07 §12.2 "HUD-Tests gegen die echte Sim ab I1"; R1b-I1): the HUD bound to an RtSim of the
## test kit RtKit (rt_min data, a real-time GameState, encounters through BattleBridge.make_rt_setup) and stepped by
## the director double (submit → RtSim.submit, every event of step() into on_event). The bar and the frames show the
## real queries, inputs reach the sim through CombatDirector.submit and are accepted, refusals come back as
## ACTION_REFUSED with their short text, the tutorial cards hold the real sim, the canned combat of the golden test runs
## through the HUD — every event it emits, no overlap, the same end state as headless — and the results take the
## sim's BattleResult. The HudSim tests stay for exact UI states the real sim reaches only by chance.

const HudRig := preload("res://tests/fixtures/rt_hud/hud_rig.gd")
const CombatView := preload("res://scenes/combat/ui/combat_view.gd")
const CombatStyle := preload("res://scenes/combat/ui/combat_style.gd")
const RESULTS: String = "res://scenes/combat/ui/combat_results.gd"
const OVERLAY_SCENE: String = "res://scenes/ui/show_overlay.tscn"

var _hints_setting: bool = true
var _size: Vector2i = Vector2i.ZERO


func before_each() -> void:
	Game.new_game(0, "Kai", 11)
	_hints_setting = Game.settings.combat_hints
	_size = tree.root.size
	var seen: Dictionary = {}
	for id: String in RtVocab.HINT_IDS:
		seen[id] = true
	Game.state.flags["rt_hints"] = seen            # no first-time card unless a test asks for one
	tree.paused = false


func after_each() -> void:
	Game.settings.combat_hints = _hints_setting
	tree.root.size = _size
	tree.paused = false
	CombatInput.apply_input_mode(true)             # the project map (07 §7.7, E36)
	Events.overlay_mode_requested.emit(&"hidden")


## A real sim of `cmd` bound to the HUD; RtSim.start()'s prelude goes to on_event like the director's first events.
func _bind(cmd: Dictionary, level: int = 1, st: GameState = null, extra: Dictionary = {}) -> Dictionary:
	var setup: RtSetup = RtKit.setup(st if st != null else RtKit.state(level), cmd)
	assert_not_null(setup, "BattleBridge.make_rt_setup")
	var sim: RtSim = RtSim.new(setup, RtKit.data())
	var r: Dictionary = HudRig.make(self, sim, RtKit.data(), extra)
	var pre: Array[ActionEvent] = sim.start()
	for e: ActionEvent in pre:
		(r["hud"] as Node).call("on_event", e)
	r["prelude"] = pre.size()
	return r


func _overlay() -> CanvasLayer:
	var o: CanvasLayer = (load(OVERLAY_SCENE) as PackedScene).instantiate() as CanvasLayer
	var holder: Node = Node.new()
	add_to_tree(holder)
	holder.add_child(o)
	return o


func _last_answer(dir: Node) -> String:
	var a: PackedStringArray = dir.get("answers")
	return a[a.size() - 1] if not a.is_empty() else "<none>"


## Every visible slot shows what the sim's pure queries say right now.
func _assert_bar_matches(hud: Node, sim: RtSim, what: String) -> void:
	var bar: Control = hud.get("bar") as Control
	var ctl: String = sim.controlled_id()
	var entries: Dictionary = CombatView.bar_entries(sim, ctl)
	var want: Array[int] = []
	for k: Variant in entries.keys():
		want.append(int(k))
	want.sort()
	assert_eq(bar.call("visible_slots"), want, "%s: the slots of RtSim.bar" % what)
	for slot: int in want:
		var s: Dictionary = bar.call("state_of", slot)
		var id: String = str(entries[slot])
		assert_eq(str(s["id"]), id, "%s: slot %d" % [what, slot])
		if CombatView.is_item_id(id):
			assert_eq([int(s["cd_left"]), int(s["count"])], [sim.item_cd_left(), sim.items_left()],
				"%s: potion cooldown / items_left" % what)
			continue
		assert_eq([int(s["cd_left"]), int(s["cd_total"])], [sim.cooldown_left(ctl, id), sim.cooldown_total(ctl, id)],
			"%s: slot %d cooldown" % [what, slot])
		var gcd: int = sim.gcd_left(ctl) if CombatView.uses_gcd(CombatView.skill_of(id)) else 0
		assert_eq(int(s["gcd_left"]), gcd, "%s: slot %d GCD" % [what, slot])
		assert_eq(str(s["reason"]), sim.can_use(ctl, id, CombatView.target_for(sim, sim.unit(ctl),
			CombatView.skill_of(id))), "%s: slot %d can_use" % [what, slot])


func _assert_no_overlap(rects: Dictionary, what: String) -> void:
	var names: Array = rects.keys()
	for i in names.size():
		for j in range(i + 1, names.size()):
			var a: Rect2 = rects[names[i]]
			var b: Rect2 = rects[names[j]]
			assert_false(a.intersects(b), "%s: %s %s overlaps %s %s" % [what, names[i], str(a), names[j], str(b)])


func test_bar_and_frames_read_the_real_sim() -> void:
	var r: Dictionary = _bind(RtKit.canned_encounter(), 6, RtKit.canned_state())
	await wait_frames(2)
	var hud: Node = r["hud"]
	var sim: RtSim = r["sim"]
	_assert_bar_matches(hud, sim, "ct 0")
	var bar: Control = hud.get("bar") as Control
	assert_eq(bar.call("visible_slots"), [1, 2, 3, 4, 5, 6] as Array[int], "Kai level 6 with a potion: every slot")
	var s6: Dictionary = bar.call("state_of", 6)
	assert_eq(int(s6["max_count"]), sim.bal.i("ITEM_MAX_PER_COMBAT"), "potion count of ITEM_MAX_PER_COMBAT")
	var model: Dictionary = (hud.get("frames") as Control).call("model")
	assert_eq((model["ctl"] as RtUnit).id, sim.controlled_id(), "the controlled unit's frame")
	assert_eq((model["partner"] as RtUnit).id, "p1", "the AI partner's frame")
	assert_null(model["boss"], "no boss")
	assert_eq(CombatView.enemies(sim).size(), 4, "two groups: four enemies")


func test_inputs_reach_the_real_sim() -> void:
	var r: Dictionary = _bind(RtKit.dummy_cmd(), 1)
	await wait_frames(2)
	var hud: Node = r["hud"]
	var dir: Node = r["director"]
	var sim: RtSim = r["sim"]
	var input: CombatInput = hud.get("input") as CombatInput
	input.set_target("e0")
	assert_eq(_last_answer(dir), "", "target_change accepted by RtSim.submit")
	dir.call("advance", 1)
	assert_eq(sim.unit("p0").target_id, "e0", "the sim took the target")
	await wait_frames(2)
	var tgt: RtUnit = ((hud.get("frames") as Control).call("model") as Dictionary)["target"]
	assert_true(tgt != null and tgt.id == "e0", "target frame: the dummy")
	input.press_slot(1)
	var sub: Dictionary = (dir.get("submitted") as Array).back()
	assert_eq([str(sub["t"]), str(sub["skill"]), str(sub["target"])], ["ability_use", "skl_kai_heavy_swing", "e0"],
		"slot 1 = Wuchtschlag on the target")
	assert_eq(_last_answer(dir), "", "ability_use accepted")
	dir.call("advance", 2)
	var started: Array = (dir.get("events") as Array).filter(func(e: ActionEvent) -> bool:
		return e.type == ActionEvent.Type.ACTION_START and e.actor_id == "p0")
	assert_eq(started.size(), 1, "the swing started (ACTION_START p0)")
	await wait_frames(2)
	_assert_bar_matches(hud, sim, "after the swing")
	assert_gt(sim.gcd_left("p0") + sim.cast_progress("p0").y, 0, "GCD or cast running")
	assert_gt(int(hud.get("events_seen")), int(r["prelude"]), "the HUD got the tick's events")


func test_refusals_come_back_with_their_text() -> void:
	var far: Dictionary = RtKit.dummy_cmd({"party": [{"u": "p0", "p": [0, 700, 0]}, {"u": "p1", "p": [-150, 800, 0]}]})
	var r: Dictionary = _bind(far, 1)
	await wait_frames(2)
	var hud: Node = r["hud"]
	var dir: Node = r["director"]
	var input: CombatInput = hud.get("input") as CombatInput
	input.set_target("e0")
	dir.call("advance", 1)
	input.press_slot(1)
	assert_eq(_last_answer(dir), "", "statically fine: the range check is dynamic (07 §3.4)")
	dir.call("advance", 1)
	var refused: Array = (dir.get("events") as Array).filter(func(e: ActionEvent) -> bool:
		return e.type == ActionEvent.Type.ACTION_REFUSED and e.actor_id == "p0")
	assert_eq(refused.size(), 1, "ACTION_REFUSED for the swing 7 m away")
	if refused.size() == 1:
		var reason: String = (refused[0] as ActionEvent).text
		assert_eq(reason, "range")
		var bar: Control = hud.get("bar") as Control
		assert_eq(bar.call("refusal_text"), CombatStyle.refusal_text(reason), "the short text over the bar")
		assert_eq(bar.call("refusal_text"), "Zu weit weg")
		assert_true((bar.get("_shake") as Dictionary).has(1), "slot 1 shakes")
	for reason: String in RtCommand.REASONS:
		assert_ne(CombatStyle.refusal_text(reason), reason, "German short text for '%s'" % reason)


func test_tutorial_cards_hold_the_real_sim() -> void:
	Game.state.flags["rt_hints"] = {}
	Game.settings.combat_hints = true
	var cmd: Dictionary = RtKit.encounter("enc_f1_a1_tutorial", [["g_tut", "enc_f1_a1_tutorial", [0, -50, 128]]])
	var r: Dictionary = _bind(cmd, 1)
	var sim: RtSim = r["sim"]
	assert_true(sim.setup.tutorial, "the tutorial encounter (floors.json rt.tutorial)")
	await wait_frames(2)
	var hud: Node = r["hud"]
	var dir: Node = r["director"]
	var cards: Node = hud.get("hints")
	assert_eq(cards.call("current"), "target", "step 1 at ct 0")
	assert_true(bool(dir.get("paused")), "pause_for_hint")
	assert_eq(int(dir.call("advance", 30)), 0, "no tick of the real sim while the card shows")
	assert_eq(sim.tick(), 0)
	assert_eq((hud.get("bar") as Control).call("visible_slots"), [1, 5] as Array[int],
		"RtSim.bar in the tutorial: slot 1 + SHOW (E28)")
	var input: CombatInput = hud.get("input") as CombatInput
	input.set_target("e0")
	assert_eq(_last_answer(dir), "", "target_change accepted at the held ct")
	assert_eq(cards.call("current"), "bar1", "step 2")
	input.press_slot(1)
	assert_eq(_last_answer(dir), "", "slot 1 accepted")
	assert_eq(cards.call("current"), "", "slot 1 used: the combat runs")
	assert_gt(int(dir.call("advance", 90)), 0, "ticks again")
	var hit: bool = (dir.get("events") as Array).any(func(e: ActionEvent) -> bool:
		return e.type == ActionEvent.Type.DAMAGE and e.actor_id.begins_with("p") and e.amount > 0)
	assert_true(hit, "a party hit within 3 s")
	assert_eq(cards.call("current"), "show", "after the first party hit: SHOW (step 3)")
	assert_true(bool(dir.get("paused")), "and the sim waits again")
	var ids: Array = (dir.get("hints") as Array).map(func(h: Dictionary) -> String: return str(h["id"]))
	assert_eq(ids, ["target", "bar1", "show"], "the steps in order, each recorded")


func test_canned_combat_runs_through_the_hud() -> void:
	tree.root.size = Vector2i(1280, 720)
	Game.state.floor_run.timer_started = true
	var o: CanvasLayer = _overlay()
	var r: Dictionary = _bind(RtKit.canned_encounter(), 6, RtKit.canned_state(), {"modes": true})
	var hud: Node = r["hud"]
	var dir: Node = r["director"]
	var sim: RtSim = r["sim"]
	var cmds: Array[Dictionary] = RtKit.canned_commands()
	var i: int = 0
	var checks: int = 0
	while not sim.is_finished() and sim.tick() < 1800:
		while i < cmds.size() and int(cmds[i]["ct"]) <= sim.tick():
			dir.call("submit", cmds[i])
			i += 1
		dir.call("advance", 1)
		if sim.tick() % 30 == 0 and not sim.is_finished():
			await wait_frames(2)
			_assert_bar_matches(hud, sim, "ct %d" % sim.tick())
			_assert_no_overlap(HudRig.rects(hud, o), "ct %d" % sim.tick())
			checks += 1
	assert_true(sim.is_finished() and sim.result.outcome == BattleResult.Outcome.VICTORY, "the canned fight is won")
	assert_gt(checks, 20, "checked every second")
	var evs: Array = dir.get("events")
	var types: Dictionary = {}
	for e: ActionEvent in evs:
		types[ActionEvent.type_name(e.type)] = true
	assert_gt(types.size(), 10, "many event kinds: %s" % str(types.keys()))
	assert_eq(int(hud.get("events_seen")), evs.size() + int(r["prelude"]), "every event reached on_event")
	var head: RtSim = RtKit.canned_sim()
	var run: Dictionary = RtKit.play(head, RtKit.canned_commands(), 1800)
	assert_eq(StateHash.of_rt(sim), StateHash.of_rt(head), "the HUD only reads: same end state as headless")
	assert_eq(evs.size(), (run["events"] as Array).size(), "same event stream length")
	hud.call("finish", sim.result)
	await wait_frames(2)
	assert_false(bool(hud.call("is_bound")), "finished: the HUD lets go")
	var res: CanvasLayer = (load(RESULTS) as GDScript).new() as CanvasLayer
	add_to_tree(res)
	var rw: BattleRewards = BattleRewards.new()
	rw.exp = sim.result.exp
	rw.credits = sim.result.credits
	res.call("present", sim.result, rw)
	assert_eq(res.get("form"), &"applaus", "the real VICTORY: Applaus!")
	var texts: PackedStringArray = res.call("lower_texts")
	assert_true(not texts.is_empty() and texts[0].contains("EXP"), "the lower third reads the result: %s" % str(texts))
