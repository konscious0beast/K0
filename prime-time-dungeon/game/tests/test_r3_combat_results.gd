extends TestCase
## R3 CombatResults (07 §8.9, §12.4, §12.5): the successor of battle_results.gd with the same docking points — signal
## results_shown(BattleResult), var show_slot (06 C hangs its show-bet effect onto it), the chip "TALENT BEREIT · im
## Safe Room wählen" on a talent level (never a choice here), present(); the regular win as a non-blocking lower third
## "Applaus!", the boss win as the credits panel (layer 60, tree paused, auto_continue_sec), the flight lower third.

const RESULTS: String = "res://scenes/combat/ui/combat_results.gd"


var _size: Vector2i = Vector2i.ZERO


func before_each() -> void:
	Game.new_game(0, "Kai", 11)
	tree.paused = false
	_size = tree.root.size
	tree.root.size = Vector2i(1280, 720)


func after_each() -> void:
	tree.paused = false
	tree.root.size = _size


func _results() -> CanvasLayer:
	var res: CanvasLayer = (load(RESULTS) as GDScript).new() as CanvasLayer
	var holder: Node = Node.new()
	add_to_tree(holder)
	holder.add_child(res)
	return res


func _victory(exp_v: int = 36, cr: int = 12) -> Array:
	var r: BattleResult = BattleResult.new()
	r.outcome = BattleResult.Outcome.VICTORY
	r.exp = exp_v
	r.credits = cr
	var rw: BattleRewards = BattleRewards.new()
	rw.exp = exp_v
	rw.credits = cr
	rw.items = PackedStringArray(["itm_bandage"])
	return [r, rw]


func test_public_api() -> void:
	var script: GDScript = load(RESULTS) as GDScript
	assert_false(script.source_code.begins_with("# STUB(R1a)"), "R3 replaced the R1a stub")
	var sigs: Array = script.get_script_signal_list()
	assert_eq(sigs.size(), 1, "exactly results_shown")
	if sigs.size() == 1:
		assert_eq(str(sigs[0]["name"]), "results_shown")
		assert_eq(str(((sigs[0]["args"] as Array)[0] as Dictionary)["class_name"]), "BattleResult")
	var props: Dictionary = {}
	for p: Dictionary in script.get_script_property_list():
		props[str(p["name"])] = p
	assert_true(props.has("show_slot"), "var show_slot")
	assert_eq(str((props["show_slot"] as Dictionary)["class_name"]), "Control")
	assert_true(props.has("auto_continue_sec"), "auto_continue_sec (autoplay 1.0)")
	var found: bool = false
	for m: Dictionary in script.get_script_method_list():
		if str(m["name"]) == "present":
			found = true
			var args: Array = m["args"]
			assert_eq([str((args[0] as Dictionary)["class_name"]), str((args[1] as Dictionary)["class_name"])],
				["BattleResult", "BattleRewards"], "present(result, rewards)")
	assert_true(found, "present()")


func test_regular_win_is_a_lower_third() -> void:
	var res: CanvasLayer = _results()
	var shown: Array[BattleResult] = []
	res.connect("results_shown", func(r: BattleResult) -> void: shown.append(r))
	var v: Array = _victory()
	res.call("present", v[0], v[1])
	assert_eq(res.get("form"), &"applaus", "regular win: Applaus!")
	assert_eq(shown.size(), 1, "results_shown(result)")
	assert_eq(shown[0], v[0])
	assert_eq(res.call("lower_texts"), PackedStringArray(["+36 EXP · +12 Cr · Werbepflaster"]), "07 §8.9 line")
	var slot: Control = res.get("show_slot") as Control
	assert_not_null(slot, "show_slot inside the lower third (06 C)")
	assert_false(tree.paused, "never blocking: the exploration goes on")
	var lower: Control = slot.get_parent() as Control
	await wait_until(func() -> bool: return absf(lower.get_global_rect().position.x - 24.0) < 0.6, 600)
	var r: Rect2 = lower.get_global_rect()
	assert_almost(r.position.x, 24.0, 0.6, "bottom left at the safe edge")
	assert_lt(r.end.y, 720.0 - 24.0 - 22.0, "above the chat ticker")
	assert_almost((lower.get_node("Body") as Control).size.x, 380.0, 0.6, "380 px wide (never over the bar)")


func test_touch_lifts_the_lower_thirds_over_the_stick() -> void:
	var tc: CanvasLayer = (load("res://scenes/ui/touch_controls.tscn") as PackedScene).instantiate() as CanvasLayer
	tc.call("setup", {"force_visible": true})
	var holder: Node = Node.new()
	add_to_tree(holder)
	holder.add_child(tc)
	await wait_frames(2)
	var res: CanvasLayer = _results()
	var v: Array = _victory()
	res.call("present", v[0], v[1])
	var lower: Control = (res.get("show_slot") as Control).get_parent() as Control
	await wait_until(func() -> bool: return absf(lower.get_global_rect().position.x - 24.0) < 0.6, 600)
	var js: Control = tc.get("joystick") as Control
	var ring_top: float = js.get_global_rect().position.y + (js.call("rest_position") as Vector2).y - 90.0
	assert_lt(lower.get_global_rect().end.y, ring_top, "touch: above the stick's rest ring, never under the thumb")


func test_level_up_and_talent_chip() -> void:
	var res: CanvasLayer = _results()
	var v: Array = _victory()
	var info: LevelUpInfo = LevelUpInfo.new()
	info.member_id = "kai"
	info.old_level = 2
	info.new_level = 3
	info.stat_gains = {"hp": 9}
	(v[1] as BattleRewards).level_ups = [info]
	res.call("present", v[0], v[1])
	var texts: PackedStringArray = res.call("lower_texts")
	assert_eq(texts.size(), 2, "level-up as a second lower third")
	assert_eq(texts[1], "Kai: Level 3")
	assert_eq(int(res.call("talent_count", v[1])), 1 if Talents.is_talent_level(3) else 0)
	if Talents.is_talent_level(3):
		var chip: Label = res.find_child("TalentChip", true, false) as Label
		assert_not_null(chip, "chip on a talent level (06 B)")
		if chip != null:
			assert_eq(chip.text, "TALENT BEREIT · im Safe Room wählen", "never a choice in the result")


func test_boss_win_credits_panel() -> void:
	var res: CanvasLayer = _results()
	var v: Array = _victory(740, 120)
	(v[0] as BattleResult).is_boss = true
	(v[0] as BattleResult).boss_id = "enm_boss_hausmeister"
	res.set("auto_continue_sec", 0.15)
	var done: Array[bool] = [false]
	var run: Callable = func() -> void:
		await res.call("present", v[0], v[1])
		done[0] = true
	run.call()
	assert_eq(res.get("form"), &"boss")
	assert_eq(res.layer, 60, "credits on layer 60")
	assert_true(tree.paused, "the tree waits behind the credits")
	assert_not_null(res.get("show_slot"), "show_slot in the panel")
	assert_not_null(res.find_child("Credits", true, false), "the credits panel")
	await wait_until(func() -> bool: return done[0], 600)
	assert_false(tree.paused, "closed: the tree runs again")
	assert_true(bool(res.call("is_done")))


func test_flight_and_defeat() -> void:
	var res: CanvasLayer = _results()
	var r: BattleResult = BattleResult.new()
	r.outcome = BattleResult.Outcome.FLED
	res.call("present", r, BattleRewards.new())
	assert_eq(res.get("form"), &"flee")
	assert_true((res.call("lower_texts") as PackedStringArray)[0].begins_with("Die Kamera hat alles gesehen"))
	var res2: CanvasLayer = _results()
	var d: BattleResult = BattleResult.new()
	d.outcome = BattleResult.Outcome.DEFEAT
	res2.call("present", d, null)
	assert_eq(res2.get("form"), &"defeat", "defeat: the existing Sendeschluss flow, nothing here")
	assert_false(bool(res2.get("shown")))
	assert_null(res2.get("show_slot"))


func test_applaus_line_counts_items() -> void:
	var script: GDScript = load(RESULTS) as GDScript
	var v: Array = _victory(50, 0)
	(v[1] as BattleRewards).items = PackedStringArray(["itm_bandage", "itm_bandage", "itm_antidote"])
	var line: String = script.call("applaus_line", v[0], v[1])
	assert_true(line.begins_with("+50 EXP · Werbepflaster ×2 · "), line)
	var empty: Array = _victory(0, 0)
	(empty[1] as BattleRewards).items = PackedStringArray()
	assert_eq(script.call("applaus_line", empty[0], empty[1]), "Die Show geht weiter.")
