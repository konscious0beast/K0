extends TestCase
## 06 §1.1/§1.5/§1.6 (package A): the new-game flow slot → hero choice → name entry (simple, keyboard / gamepad /
## touch): two cards, Kai focused first, left/right between them, one press chooses, back returns; the name entry
## keeps Kai's name and asks in the Count's voice when he leads; the intro ends with the M.O.D. line of the choice;
## the safe room's "Figur wechseln" switches (recorded), swaps the figures and says hero_switch:<id>; the M.O.D. lines
## of the block exist for both heroes; the B1 tutorial hints explain the bark when the Count leads.

const SCENE_HERO: String = "res://scenes/title/hero_select.tscn"
const SCENE_NAME: String = "res://scenes/title/name_entry.tscn"
const SCENE_SLOTS: String = "res://scenes/title/slot_select.tscn"
const SCENE_SAFE: String = "res://scenes/safe_room/safe_room.tscn"
const SCENE_INTRO: String = "res://scenes/title/intro.tscn"
const ROUTER_FIXTURE: String = "res://tests/fixtures/router/router_screen.tscn"
const WAIT: int = 1500

var _said: Array[Array] = []


func before_each() -> void:
	Engine.time_scale = 8.0
	tree.paused = false
	_said.clear()
	Events.mod_said.connect(_on_said)


func after_each() -> void:
	Engine.time_scale = 1.0
	tree.paused = false
	if Events.mod_said.is_connected(_on_said):
		Events.mod_said.disconnect(_on_said)
	await _settle_router()
	Game.state = null
	Game.run_log = null
	Game.sim = null
	Game.timer_running = false


func _on_said(text: String, voice: StringName, tag: String, _blocking: bool) -> void:
	_said.append([tag, text, voice])


func _scene(path: String, params: Dictionary) -> Node:
	var n: Node = (load(path) as PackedScene).instantiate()
	n.call("setup", params)
	return n


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
	Game.timer_running = false


func _wait_screen(path: String) -> bool:
	return await wait_until(func() -> bool:
		return Router.current != null and is_instance_valid(Router.current) \
			and Router.current.scene_file_path == path and not Router.busy, WAIT)


# --- hero select -------------------------------------------------------------------------------------------------------

func test_hero_select_cards_focus_and_navigation() -> void:
	Game.ensure_state()
	var n: Node = _scene(SCENE_HERO, {"slot": 2})
	add_to_tree(n)
	await wait_frames(3)
	var cards: Dictionary = n.get("cards")
	assert_eq(cards.keys(), ["kai", "mopsula"], "two cards, Kai first")
	var kai: Button = cards["kai"] as Button
	var mop: Button = cards["mopsula"] as Button
	assert_eq(tree.root.gui_get_focus_owner(), kai, "Kai's card has the focus")
	assert_eq(kai.get_node(kai.focus_neighbor_right), mop, "right → the Count")
	assert_eq(mop.get_node(mop.focus_neighbor_right), kai, "wraps")
	assert_eq(mop.get_node(mop.focus_neighbor_left), kai)
	for b: Button in [kai, mop]:
		assert_true(b.size.x >= UiTheme.TOUCH_HIT and b.size.y >= UiTheme.TOUCH_HIT, "big touch cards")
	var texts: String = ""
	for l: Node in n.find_children("*", "Label", true, false):
		texts += (l as Label).text + "\n"
	for want: String in ["WEN STEUERST DU?", "KAI", "GRAF MOPSULA", "Feldschlag", "Bellen", "Safe Room"]:
		assert_has(texts, want, "text '%s'" % want)
	var n2: Node = _scene(SCENE_HERO, {"slot": 1, "hero": "mopsula"})
	add_to_tree(n2)
	await wait_frames(3)
	assert_eq(tree.root.gui_get_focus_owner(), (n2.get("cards") as Dictionary)["mopsula"], "coming back: the last pick")


func test_hero_select_chooses_and_goes_to_the_name_entry() -> void:
	Game.ensure_state()
	var n: Node = _scene(SCENE_HERO, {"slot": 3})
	add_to_tree(n)
	await wait_frames(3)
	((n.get("cards") as Dictionary)["mopsula"] as Button).pressed.emit()
	assert_eq(str(n.get("chosen")), "mopsula")
	assert_true(await _wait_screen(SCENE_NAME), "→ name entry")
	var ne: Node = Router.current
	assert_eq(int(ne.get("slot")), 3)
	assert_eq(str(ne.get("hero")), "mopsula")
	assert_eq(str(ne.call("heading")), "BEGLEITER:IN", "the Count names his companion (06 §1.1)")
	assert_has(str(ne.call("question")), "Wie heißt Unser:e Begleiter:in?")
	assert_eq((ne.get("name_edit") as LineEdit).text, "Kai", "the name is still Kai's")
	ne.call("back")
	assert_true(await _wait_screen(SCENE_HERO), "back → hero choice")
	assert_eq(tree.root.gui_get_focus_owner(), (Router.current.get("cards") as Dictionary)["mopsula"],
		"focus on the Count again")
	Router.current.call("back")
	assert_true(await _wait_screen(SCENE_SLOTS), "back → slot select")


func test_slot_select_new_leads_to_the_hero_choice() -> void:
	Game.ensure_state()
	var s: Node = _scene(SCENE_SLOTS, {"mode": "new"})
	add_to_tree(s)
	await wait_frames(3)
	s.call("_confirmed", 2)
	assert_true(await _wait_screen(SCENE_HERO), "Neues Spiel: slot → hero choice")
	assert_eq(int(Router.current.get("slot")), 2)


func test_name_entry_for_kai_stays_as_before() -> void:
	Game.ensure_state()
	var ne: Node = _scene(SCENE_NAME, {"slot": 1})
	add_to_tree(ne)
	await wait_frames(2)
	assert_eq(str(ne.get("hero")), "kai", "no hero param → Kai")
	assert_eq(str(ne.call("heading")), "KANDIDAT:IN")
	assert_eq(str(ne.call("question")), "Wie sollen die Zuschauer:innen dich nennen?")


func test_name_entry_starts_the_game_with_the_hero_and_the_intro_says_it() -> void:
	Game.ensure_state()
	var ne: Node = _scene(SCENE_NAME, {"slot": 0, "hero": "mopsula"})
	add_to_tree(ne)
	await wait_frames(2)
	ne.call("start")
	assert_true(await _wait_screen(SCENE_INTRO), "→ intro")
	assert_eq(Game.hero(), "mopsula", "new game led by the Count")
	var intro: Node = Router.current
	var lines: Array = []
	for shot: Dictionary in intro.get("shots"):
		lines.append_array(shot.get("lines", []))
	var last: Array = lines.back()
	assert_eq(str(last[0]), "mod")
	assert_has(str(last[1]), "Fernbedienung", "the studio ends with hero_pick:mopsula")
	assert_has(str(last[1]), Game.state.player_name, "{name} filled in")


# --- safe room -------------------------------------------------------------------------------------------------------

func test_safe_room_switch_records_swaps_and_comments() -> void:
	Game.new_game(0, "Kai", 77)
	Game.state.floor_run.stats["time_used_ticks"] = 30      # the run has started: only the safe room allows a switch
	var r: Node = _scene(SCENE_SAFE, {})
	add_to_tree(r)
	await wait_frames(3)
	assert_has(r.call("menu_ids"), "hero", "'Figur wechseln' in the menu")
	var kai3d: Node3D = r.get("_kai") as Node3D
	var mop3d: Node3D = r.get("_mopsula") as Node3D
	var kai_pos: Vector3 = kai3d.position
	var mop_pos: Vector3 = mop3d.position
	var n_cmds: int = Game.run_log.cmds().size()
	_said.clear()
	r.call("activate", "hero")
	assert_eq(Game.hero(), "mopsula", "the Count leads")
	assert_eq(Game.run_log.cmds().size(), n_cmds + 1)
	assert_eq(Game.run_log.cmds().back()["c"], {"t": "hero", "id": "mopsula"}, "recorded")
	assert_true(kai3d.position.is_equal_approx(mop_pos) and mop3d.position.is_equal_approx(kai_pos),
		"the figures swap places: the hero stands in front")
	assert_has(str(r.call("status_text")), "Graf Mopsula")
	var tags: Array = _said.map(func(l: Array) -> String: return str(l[0]))
	assert_has(tags, "hero_switch:mopsula", "M.O.D. comments the switch")
	var lead: Label = ((r.get("menu_buttons") as Dictionary)["hero"] as Button).find_child("Lead", true, false) as Label
	assert_eq(lead.text, "Graf führt")
	r.call("activate", "hero")
	assert_eq(Game.hero(), "kai", "and back")
	assert_true(kai3d.position.is_equal_approx(kai_pos), "Kai in front again")
	assert_eq(lead.text, "Kai führt")


func test_safe_room_menu_fits_above_the_chat_ticker() -> void:
	Game.new_game(0, "Kai", 78)
	var r: Node = _scene(SCENE_SAFE, {})
	add_to_tree(r)
	await wait_frames(4)
	var buttons: Dictionary = r.get("menu_buttons")
	var last: Button = buttons["leave"] as Button
	assert_lt(last.get_global_rect().end.y, 672.0, "7 entries end above the chat ticker (y 675)")
	var prev: Rect2 = Rect2()
	var first: bool = true
	for id: String in r.call("menu_ids"):
		var b: Button = buttons[id] as Button
		assert_true(b.size.y >= UiTheme.MIN_TOUCH, "%s is >= 64 px high" % id)
		var rect: Rect2 = b.get_global_rect()
		if not first:
			var gap: float = maxf(maxf(rect.position.x - prev.end.x, prev.position.x - rect.end.x),
				maxf(rect.position.y - prev.end.y, prev.position.y - rect.end.y))
			assert_true(gap >= 11.99, "12 px between %s and its neighbour (§10.2), got %.1f" % [id, gap])
		prev = rect
		first = false


# --- lines ------------------------------------------------------------------------------------------------------------

func test_mod_lines_of_the_hero_block() -> void:
	var d: GameData = real_data()
	for tag: String in ["hero_pick:kai", "hero_pick:mopsula", "hero_switch:kai", "hero_switch:mopsula", "chat_bark",
			"tutorial_explore:mopsula", "tutorial_sneak:mopsula"]:
		assert_false(d.mod_lines(tag).is_empty(), "lines for " + tag)
		for l: ModLineDef in d.mod_lines(tag):
			assert_false(l.text.to_lower().contains("barfu"), "no foot motifs (06 §0.3)")
			assert_false(l.text.contains("Carl") or l.text.contains("Donut"), "own IP only (06 §0.3)")
	for l: ModLineDef in d.mod_lines("chat_bark"):
		assert_eq(l.voice, "chat")


func test_tutorial_hints_explain_the_bark_when_the_count_leads() -> void:
	Game.new_game(0, "Kai", 1234, &"prime", "mopsula")
	_said.clear()
	Events.floor_entered.emit(1)
	var tags: Array = _said.map(func(l: Array) -> String: return str(l[0]))
	assert_eq(tags, ["tutorial_explore:mopsula", "tutorial_sneak:mopsula"], "B1 hints in the Count's version")
	assert_has(str(_said[1][1]), "Bellen", "the hint names the bark")
