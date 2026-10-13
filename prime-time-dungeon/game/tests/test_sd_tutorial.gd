extends TestCase
## 10 §6.9 test_sd_tutorial (SD2-E): the Lernduell on the table — the six lessons as cards in their order (at their
## numbers, the forced card marked and glowing, the others dimmed), "Ich kenne mich aus" (the Grundakte at once),
## repeating it from the rules (no second reward), the wording per input scheme, and the hall's welcome card before it.

const TABLE: String = "res://scenes/stempel/sd_table.tscn"
const HALL: String = "res://scenes/stempel/sd_hall.tscn"
const ROUTER_FIXTURE: String = "res://tests/fixtures/router/router_screen.tscn"
const SdSession := preload("res://scenes/stempel/sd_session.gd")
const SdTutorial := preload("res://scenes/stempel/sd_tutorial.gd")
const ROOT: String = "user://test_sd_tutorial"

var _saved_dir: String = ""


func before_each() -> void:
	_saved_dir = Save.save_dir
	Save.save_dir = ROOT + "/saves"                       # no campaign slots of other tests (the hall reads them)
	SdSession.reset()
	SdSession.ephemeral = true
	Engine.time_scale = 8.0


func after_each() -> void:
	Engine.time_scale = 1.0
	tree.paused = false
	await _settle_router()
	SdSession.reset()
	SdSession.ephemeral = false
	Save.save_dir = _saved_dir
	CombatInput.apply_for_game()


func test_six_lessons_in_order_then_the_grundakte() -> void:
	var b: SdRulebook = SdSession.book()
	var c: SdCollection = SdCollection.create(99)
	var t: Node = _tutorial_table(c)
	var shown: Array[int] = []
	t.connect("lesson_shown", func(step: int) -> void: shown.append(step))
	var steps: Array[int] = []
	var forced_ok: bool = true
	for i in 3000:
		if bool(t.get("finished")):
			break
		var m: Variant = t.get("modal")
		if m != null and is_instance_valid(m) and str((m as Node).name).begins_with("Lesson"):
			var card: Node = m as Node
			var step: int = str(card.name).trim_prefix("Lesson").to_int()
			steps.append(step)
			var text: Label = card.find_child("Text", true, false) as Label
			assert_true(text != null and text.text.length() > 20, "lesson %d has its line" % step)
			assert_eq(card.find_child("Skip", true, false) != null, step == 1, "„Ich kenne mich aus“ on the first card")
			var duel: SdDuel = t.get("duel") as SdDuel
			var fm: Dictionary = duel.forced_move()
			if str(fm.get("op", "")) == "play":
				var hand: Node = t.get("hand")
				var slot: int = duel.hand(SdDuel.Side.PLAYER).find(str(fm["card"]))
				forced_ok = forced_ok and int(hand.get("marked_slot")) == slot \
					and float((hand.call("view", slot) as Control).get("highlight")) > 0.0
			(card.find_child("Continue", true, false) as Button).emit_signal("pressed")
			await wait_frames(2)
			continue
		if _waits_for_player(t):
			t.call("_submit_player", SdAi.suggest(t.get("duel") as SdDuel))     # runs on; lesson cards come between
		await wait_frames(1)
	await wait_until(func() -> bool: return t.get("results") != null, 300)
	assert_eq(steps, [1, 2, 3, 4, 5, 6], "six lesson cards in order")
	assert_eq(shown, [1, 2, 3, 4, 5, 6], "lesson_shown in order")
	assert_true(forced_ok, "the forced card is marked and glows while its lesson shows")
	var res: Node = t.get("results")
	assert_not_null(res, "the results panel")
	if res != null:
		assert_eq(str((res.find_child("Stamp", true, false) as Control).get("word")), "BEWILLIGT")
		assert_not_null(res.find_child("ZurSchalterhalle", true, false), "the Lernduell ends with „Zur Schalterhalle“")
	assert_true(c.tutorial, "done")
	assert_eq(Array(c.owned), _sorted(b.grundakte), "the Grundakte (12 cards)")
	assert_eq(c.deck("a"), b.startmappe_list(), "the Startmappe as Mappe A")
	assert_eq(c.heft, 0, "no Stempelheft stamp for the Lernduell")
	await wait_frames(2)


func test_ich_kenne_mich_aus_gives_the_grundakte_at_once() -> void:
	var c: SdCollection = SdCollection.create(98)
	var t: Node = _tutorial_table(c)
	var ok: bool = await wait_until(func() -> bool:
		var m: Variant = t.get("modal")
		return m != null and is_instance_valid(m) and str((m as Node).name) == "Lesson1", 600)
	if not ok:
		return
	((t.get("modal") as Node).find_child("Skip", true, false) as Button).emit_signal("pressed")
	await wait_until(func() -> bool: return t.get("results") != null, 120)
	var res: Node = t.get("results")
	assert_not_null(res, "results right away")
	if res != null:
		assert_eq(str((res.find_child("Stamp", true, false) as Control).get("word")), "EINGEARBEITET")
	assert_true(c.tutorial)
	assert_eq(c.owned.size(), SdSession.book().grundakte.size(), "the Grundakte")
	assert_has(c.awards, SdCollection.AWARD_TUTORIAL)
	await wait_frames(2)                                  # the panel's deferred slide-in runs before the teardown


func test_the_lernduell_can_be_repeated_from_the_rules_without_a_second_reward() -> void:
	var c: SdCollection = SdCollection.create(97)
	c.complete_tutorial(SdSession.book())
	SdSession.use(c)
	var h: Node = (load(HALL) as PackedScene).instantiate()
	h.call("setup", {"mute": true})
	add_to_tree(h)
	await wait_frames(3)
	var owned: PackedStringArray = c.owned.duplicate()   # after opening: the campaign may have added cards (10 §2.5)
	h.call("open_rules")
	await wait_frames(2)
	var rules: Node = h.get("modal")
	var again: Button = rules.find_child("Tutorial", true, false) as Button if rules != null else null
	assert_true(again != null and again.text == "Lernduell wiederholen", "the rules offer it again")
	if again == null:
		return
	again.emit_signal("pressed")
	var pushed: bool = await wait_until(func() -> bool:
		return Router.current != null and is_instance_valid(Router.current) and not Router.busy \
			and Router.current.scene_file_path == TABLE, 600)
	if not pushed:
		return
	var t: Node = Router.current
	assert_true(bool(t.get("tutorial")), "a Lernduell")
	await wait_until(func() -> bool: return t.get("modal") != null, 600)
	t.call("skip_tutorial")
	await wait_frames(2)
	assert_eq(c.owned, owned, "nothing twice")
	var res: Node = t.get("results")
	assert_not_null(res)
	t.call("leave")
	var back: bool = await wait_until(func() -> bool: return Router.current == h and not Router.busy, 600)
	assert_true(back, "back in the Schalterhalle")


func test_lesson_wording_follows_the_input_scheme() -> void:
	var b: SdRulebook = SdSession.book()
	var l1: Dictionary = (b.tutorial["lessons"] as Array)[0]
	var touch_text: String = SdTutorial.lesson_text(b, l1, true)
	var keys_text: String = SdTutorial.lesson_text(b, l1, false)
	assert_true(touch_text.contains("Tippen"), "touch: tap")
	assert_true(keys_text.contains("Markieren") and not keys_text.contains("Tippen"), "keys: mark")
	var acts: Array = []
	for k: Array in SdTutorial.key_hints("play"):
		acts.append(k[0])
	assert_eq(acts, [&"ui_left", &"ui_right", &"ui_accept", &"map"])
	var l2: Dictionary = (b.tutorial["lessons"] as Array)[1]
	assert_eq(SdTutorial.lesson_text(b, l2, true), SdTutorial.lesson_text(b, l2, false), "neutral lines stay")
	assert_ne(SdTutorial.note_text(b, l2), "", "lesson 2 has the Graf's footnote")


func test_the_hall_welcomes_before_the_lernduell() -> void:
	var c: SdCollection = SdCollection.create(96)
	SdSession.use(c)
	var h: Node = (load(HALL) as PackedScene).instantiate()
	h.call("setup", {"mute": true})
	add_to_tree(h)
	var ok: bool = await wait_until(func() -> bool:
		var m: Variant = h.get("modal")
		return m != null and is_instance_valid(m) and str((m as Node).name) == "Welcome", 60)
	if not ok:
		return
	var m2: Node = h.get("modal")
	assert_not_null(m2.find_child("StartTutorial", true, false), "Lernduell starten")
	var toasts: Array[String] = []
	var cb: Callable = func(text: String, _icon: StringName) -> void: toasts.append(text)
	Events.toast_requested.connect(cb)
	(m2.find_child("Skip", true, false) as Button).emit_signal("pressed")
	await wait_frames(3)
	Events.toast_requested.disconnect(cb)
	assert_true(c.tutorial, "Ich kenne mich aus")
	assert_true(toasts.size() >= 1 and toasts[0].begins_with("Grundakte"), "the rewards as toasts")
	var ferdi: Node = (h.get("tickets") as Dictionary)["sdo_ferdi"]
	assert_eq((ferdi.find_child("State", true, false) as Label).text, "NEU", "Ferdi is open now")


# --- helpers ----------------------------------------------------------------------------------------------------------

func _tutorial_table(c: SdCollection) -> Node:
	var t: Node = (load(TABLE) as PackedScene).instantiate()
	t.call("setup", {"tutorial": true, "collection": c, "mute": true})
	add_to_tree(t)
	return t


func _waits_for_player(t: Node) -> bool:
	var d: SdDuel = t.get("duel") as SdDuel
	var m: Variant = t.get("modal")
	return d != null and not bool(t.get("busy")) and not bool(t.get("finished")) \
		and d.side_to_move() == SdDuel.Side.PLAYER and (m == null or not is_instance_valid(m))


static func _sorted(ids: PackedStringArray) -> Array:
	var a: Array = Array(ids)
	a.sort()
	return a


func _settle_router() -> void:
	for i in 600:
		if not Router.busy:
			break
		await tree.process_frame
	var cur: Node = Router.current
	if cur != null and is_instance_valid(cur) and not _nodes.has(cur):
		Router.goto(ROUTER_FIXTURE, {}, Router.Transition.NONE)
		for j in 240:
			if not Router.busy:
				break
			await tree.process_frame
		cur = Router.current
		if cur != null and is_instance_valid(cur):
			if cur.get_parent() != null:
				cur.get_parent().remove_child(cur)
			cur.free()
	Router.adopt(null)
