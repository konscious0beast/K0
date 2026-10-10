extends TestCase
## 06 package B — Talent-Show UI (06 §2.2 "UI Talent-Show", GDD §4.7): the safe room offers a gold call-to-action
## only with an open choice (outside the menu column — seven entries since package A —, first focus, reachable with
## ui_right from every menu row; integration A × B: >= 88 px hit area, top right level with the first row, clear of
## the M.O.D. box at the bottom right); the modal shows two
## cards per choice (name, sentence, effect, stat preview), picks through Game.pick_talent (recorded), walks through
## every open choice of both members and closes by itself; "Später" / ui_cancel close it with choices still open; the
## one-sentence rule line comes once; cards are focusable with >= 88 px hit areas. The battle results show
## "TALENT BEREIT" on a level-up onto L3 / L5 (never a choice there), the party page lists talents and the open
## choice; TalentText formats every effect kind.

const SCENE_SAFE_ROOM: String = "res://scenes/safe_room/safe_room.tscn"
const SCENE_SHOW: String = "res://scenes/ui/talent_show.tscn"
const RESULTS_SCENE: String = "res://scenes/battle/ui/battle_results.tscn"
const TalentText := preload("res://scenes/ui/talent_text.gd")
const UiUtil := preload("res://scenes/ui/ui_util.gd")
const ModDialogScript := preload("res://scenes/ui/mod_dialog.gd")
const WAIT: int = 600


func before_each() -> void:
	Engine.time_scale = 8.0
	tree.paused = false
	Game.new_game(0, "Kai", 3)


func after_each() -> void:
	Engine.time_scale = 1.0
	tree.paused = false
	Game.clear_blocking_dialogs()
	Router.adopt(null)
	Sfx.stop_all()                              # the safe room started its music (later tests expect silence)


func _levels(lv: int) -> void:
	for m: PartyMember in Game.state.party:
		m.level = lv


func _room() -> Node:
	var r: Node = (load(SCENE_SAFE_ROOM) as PackedScene).instantiate()
	r.call("setup", {})
	add_to_tree(r)
	return r


func _modal(r: Node) -> Node:
	for c: Node in r.get_children():
		if c.has_method("pick") and c.has_signal("closed"):
			return c
	return null


func test_safe_room_offers_the_talent_show_only_with_an_open_choice() -> void:
	var r: Node = _room()
	await wait_frames(3)
	assert_false(bool(r.call("talent_show_available")), "L1: no Talent-Show button")
	# package A's menu (06 §1.6): "Figur wechseln" joined, Speichern | Weiter share the bottom row
	var menu7: PackedStringArray = ["lootbox", "vending", "equipment", "hero", "mopsula", "save", "leave"]
	assert_eq(r.call("menu_ids"), menu7, "the menu column keeps its seven entries")
	r.queue_free()
	await wait_frames(2)
	_levels(3)
	var r2: Node = _room()
	await wait_frames(3)
	assert_true(bool(r2.call("talent_show_available")))
	assert_eq(r2.call("menu_ids"), menu7, "the Talent-Show is a separate call-to-action, not an 8th entry")
	var b: Button = (r2.get("menu_buttons") as Dictionary)["talents"] as Button
	assert_eq((b.find_child("Text", true, false) as Label).text, "TALENT-SHOW")
	assert_eq((b.find_child("Sub", true, false) as Label).text, "2 Talentwahlen offen", "one open choice per member")
	assert_true(await wait_until(func() -> bool: return b.has_focus(), 30), "first focus: the open Talent-Show")
	assert_true(b.size.y >= UiTheme.TOUCH_HIT - 8 and b.size.y >= UiTheme.MIN_TOUCH, "button height %.0f" % b.size.y)
	assert_true(b.size.y >= UiTheme.TOUCH_HIT, "hit area >= 88 px (02_TECH §10.2 rule 5): %.0f" % b.size.y)
	var vp: Vector2 = b.get_viewport_rect().size
	var rect: Rect2 = b.get_global_rect()
	assert_true(rect.end.x <= vp.x and rect.end.y <= vp.y - 60, "inside the screen, above the input hints: %s" % rect)
	var buttons: Dictionary = r2.get("menu_buttons") as Dictionary
	var first: Button = buttons["lootbox"] as Button
	assert_almost(rect.position.y, first.get_global_rect().position.y, 1.0, "level with the first menu row")
	var mod_top: float = vp.y - 24.0 - ModDialogScript.BOX_BOTTOM - 2.0 * ModDialogScript.BOX_SIZE.y
	assert_lt(rect.end.y, mod_top, "clear of the right-aligned M.O.D. box, even a three-line one")
	for id: String in ["lootbox", "equipment", "hero", "mopsula", "leave"]:   # the right end of every row
		var e: Button = buttons[id] as Button
		assert_eq(e.get_node(e.focus_neighbor_right), b, "ui_right from %s reaches it" % id)
	assert_eq(b.get_node(b.focus_neighbor_left), first, "ui_left leads back to the menu (the first row)")
	b.pressed.emit()
	await wait_frames(3)
	assert_not_null(_modal(r2), "pressing it opens the Talent-Show")


func test_talent_show_walks_through_every_choice_and_records_picks() -> void:
	_levels(5)
	var r: Node = _room()
	await wait_frames(3)
	var n0: int = Game.run_log.cmds().size()
	r.call("activate", "talents")
	await wait_frames(3)
	var ts: Node = _modal(r)
	assert_not_null(ts, "Talent-Show opens as a modal")
	if ts == null:
		return
	assert_eq(str(ts.get("member_id")), "kai", "Kai first (party order), oldest level first")
	var cards: Array = ts.get("card_buttons")
	assert_eq(cards.size(), 2, "two cards")
	assert_true(await wait_until(func() -> bool: return (cards[0] as Button).has_focus(), 30), "card 1 has focus")
	for c: Variant in cards:
		var card: Button = c
		assert_true(card.size.y >= UiTheme.TOUCH_HIT, "card hit area %.0f" % card.size.y)
		assert_ne((card.find_child("Name", true, false) as Label).text, "")
		assert_ne((card.find_child("Effect", true, false) as Label).text, "", "every card shows its effect")
	assert_eq(str(ts.call("progress_text")), "Wahl 1 von 4")
	var offer: PackedStringArray = ts.get("offer")
	(cards[1] as Button).pressed.emit()                     # touch / mouse path
	assert_true(await wait_until(func() -> bool: return (str(ts.get("offer")) != str(offer)
		or str(ts.get("member_id")) != "kai"), WAIT), "the next choice follows")
	var cmds: Array[Dictionary] = Game.run_log.cmds()
	assert_eq(cmds[n0]["c"], {"t": "talent", "member": "kai", "id": offer[1]}, "recorded through Game.pick_talent")
	assert_eq(str(ts.call("progress_text")), "Wahl 2 von 4")
	var closed: Array[bool] = [false]
	ts.connect("closed", func() -> void: closed[0] = true)
	for i in 3:
		if not is_instance_valid(ts):
			break
		await ts.call("pick", 0)
	assert_true(closed[0], "after the last choice the show closes by itself")
	assert_eq(Talents.open_choices(Game.state, DB.data), 0)
	assert_eq(Talents.picks(Game.state.member("kai")), 2)
	assert_eq(Talents.picks(Game.state.member("mopsula")), 2)
	await wait_frames(3)
	assert_false(bool(r.call("talent_show_available")), "button gone when nothing is open")


func test_later_keeps_choices_open() -> void:
	_levels(3)
	var r: Node = _room()
	await wait_frames(3)
	var ts: Node = r.call("open_talent_show")
	await wait_frames(3)
	var ev: InputEventAction = InputEventAction.new()
	ev.action = &"ui_cancel"
	ev.pressed = true
	Input.parse_input_event(ev)
	assert_true(await wait_until(_gone(ts), 60), "ui_cancel = Später")
	assert_eq(Talents.open_choices(Game.state, DB.data), 2, "nothing was picked")
	assert_true(bool(r.call("talent_show_available")), "the button stays")
	var ts2: Node = r.call("open_talent_show")
	await wait_frames(3)
	var close: Button = ts2.get("close_button")
	assert_eq((close.find_child("Text", true, false) as Label).text, "Später")
	assert_true(close.size.y >= UiTheme.TOUCH_HIT, "Später hit area")
	close.pressed.emit()
	assert_true(await wait_until(_gone(ts2), 60))


## True once `n` is freed or queued for deletion (weakref: a lambda capturing the node errors once it is freed).
func _gone(n: Node) -> Callable:
	var w: WeakRef = weakref(n)
	return func() -> bool: return w.get_ref() == null or (w.get_ref() as Node).is_queued_for_deletion()


func test_first_show_explains_the_rule_once() -> void:
	_levels(3)
	Game.state.floor_run.location = &"sr_kiosk"
	var tags: Array[String] = []
	var cb: Callable = func(_t: String, _v: StringName, tag: String, _b: bool) -> void: tags.append(tag)
	Events.mod_said.connect(cb)
	var ts: Node = (load(SCENE_SHOW) as PackedScene).instantiate()
	add_to_tree(ts)
	await wait_frames(2)
	assert_has(tags, "talent_show_open", "06 §0.5 one-sentence rule on the first Talent-Show")
	await ts.call("pick", 0)
	assert_true(tags.has("talent_pick") or tags.has("talent_pick:kai"), "a pick line (fallback talent_pick)")
	tags.clear()
	if is_instance_valid(ts):
		ts.call("close")
	var ts2: Node = (load(SCENE_SHOW) as PackedScene).instantiate()
	add_to_tree(ts2)
	await wait_frames(2)
	assert_false(tags.has("talent_show_open"), "not again once a talent was picked")
	Events.mod_said.disconnect(cb)


func test_value_card_previews_the_real_numbers() -> void:
	_levels(3)
	Game.state.floor_run.location = &"sr_kiosk"
	var ts: Node = (load(SCENE_SHOW) as PackedScene).instantiate()
	add_to_tree(ts)
	await wait_frames(2)
	var kai: PartyMember = Game.state.member("kai")
	var preview: String = str(ts.call("_preview", kai, DB.talent("tal_kai_wischtechnik")))
	var str_now: int = int(UiUtil.member_stats(kai)["str"])
	assert_eq(preview, "Jetzt: Stärke %d -> %d" % [str_now, str_now + 1])
	assert_eq(str(ts.call("_preview", kai, DB.talent("tal_kai_liga_routine"))),
		"Ruht gerade: Kai trägt Rüstung oder Accessoire.", "a Liga talent says when it rests")
	assert_eq(Talents.rank(kai, "tal_kai_wischtechnik"), 0, "the preview never changes the member")


func test_battle_results_chip_on_talent_levels_only() -> void:
	for case: Array in [[2, 3, true], [1, 2, false], [3, 4, false], [4, 6, true]]:
		var results: CanvasLayer = (load(RESULTS_SCENE) as PackedScene).instantiate() as CanvasLayer
		add_to_tree(results)
		var r: BattleResult = BattleResult.new()
		r.outcome = BattleResult.Outcome.VICTORY
		r.party_hp = {"kai": 10, "mopsula": 10}
		var rw: BattleRewards = BattleRewards.new()
		rw.exp = 40
		var info: LevelUpInfo = LevelUpInfo.new()
		info.member_id = "kai"
		info.old_level = int(case[0])
		info.new_level = int(case[1])
		info.stat_gains = {"hp": 9}
		rw.level_ups = [info]
		results.set("auto_continue_sec", 0.05)
		await results.call("present", r, rw)
		var chip: Node = results.find_child("TalentChip", true, false)
		assert_eq(chip != null, bool(case[2]), "L%d → L%d: chip %s" % [int(case[0]), int(case[1]), str(case[2])])
		if chip != null:
			var texts: PackedStringArray = []
			for l: Node in chip.find_children("*", "Label", true, false):
				texts.append((l as Label).text)
			assert_eq(" ".join(texts), "TALENT BEREIT im Safe Room wählen", "chip text")
		await wait_frames(1)                    # the harness frees the results layers after the test


func test_party_page_lists_talents_and_the_open_choice() -> void:
	_levels(5)
	Game.state.member("kai").talents = {"tal_kai_wischtechnik": 1}
	var page: Control = (load("res://scenes/ui/party_menu.gd") as GDScript).new() as Control
	add_to_tree(page)
	await wait_frames(2)
	var kai_card: Node = page.find_child("Card_kai", true, false)
	assert_not_null(kai_card)
	var names: Label = kai_card.find_child("TalentNames", true, false) as Label
	assert_eq(names.text, "Wischtechnik")
	assert_eq((kai_card.find_child("TalentHint", true, false) as Label).text, "1 Wahl offen")
	var mop_card: Node = page.find_child("Card_mopsula", true, false)
	assert_eq((mop_card.find_child("TalentNames", true, false) as Label).text, "noch keine (ab Level 3)")
	assert_eq((mop_card.find_child("TalentHint", true, false) as Label).text, "2 Wahlen offen")


func test_effect_texts_for_every_kind() -> void:
	var want: Dictionary = {
		"stat_flat": [{"kind": "stat_flat", "stat": "str", "value": 2}, "kai", "Stärke +2"],
		"stat_pct": [{"kind": "stat_pct", "stat": "hp", "pm": 50}, "kai", "HP +5 %"],
		"crit_add_pm": [{"kind": "crit_add_pm", "pm": 30}, "kai", "Kritische Treffer +3 %"],
		"element_pm": [{"kind": "element_pm", "element": "poison", "pm": 750}, "kai", "Gift-Schaden -25 %"],
		"post_battle_mp_pm": [{"kind": "post_battle_mp_pm", "pm": 50}, "kai", "+5 % MP nach jedem Sieg"],
		"field_range_pm": [{"kind": "field_range_pm", "pm": 1250}, "mopsula", "Bellen reicht 25 % weiter"],
		"field_cd_pm": [{"kind": "field_cd_pm", "pm": 700}, "mopsula", "Bellen 30 % schneller wieder bereit"],
		"preemptive_dmg_pm": [{"kind": "preemptive_dmg_pm", "pm": 1150}, "kai",
			"Nach Präventivschlag: 1. Zug +15 % Schaden"],
		"stunt_window_pm": [{"kind": "stunt_window_pm", "pm": 1200}, "mopsula", "Stunts gelingen 20 % öfter"],
		"marotte_heart": [{"kind": "marotte_heart", "per_floor": 1}, "kai",
			"1× je Etage: +1 Herz für M.O.D.s Vorliebe"],
		"liga_stat_pct": [{"kind": "liga_stat_pct", "stat": "def", "pm": 50}, "kai",
			"Ohne Rüstung & ohne Accessoire: Abwehr +5 %"],
		"hype_gain_pm": [{"kind": "hype_gain_pm", "pm": 1100}, "kai", "Hype +10 %"],
		"follower_pm": [{"kind": "follower_pm", "pm": 1150}, "kai", "Follower +15 %"],
	}
	for k: String in TalentDef.KINDS:
		assert_true(want.has(k), "text for " + k)
		var c: Array = want[k]
		assert_eq(TalentText.effect_text(c[0], str(c[1])), str(c[2]))
	assert_eq(TalentText.effects_line(DB.talent("tal_kai_glueckspfote"), "kai"), "Glück +1 · Kritische Treffer +2 %")
	assert_eq(TalentText.ranked_name(DB.talent("tal_kai_wischtechnik"), 2), "Wischtechnik II")
	for t: TalentDef in DB.data.all_talents():
		assert_ne(TalentText.icon_kind(t.icon), &"", t.id)
		assert_eq(UiUtil.missing_glyphs(TalentText.effects_line(t, t.for_members[0])), "", t.id + ": effect renders")
