extends TestCase
## 06-C (06 §4.3): the Unterhosen-Liga — tiers 0/1/2 by the controlled hero's and the partner's armor / accessory
## slots ("ohne Rüstung & ohne Accessoire"; the weapon stays), the blockers named in the equipment menu, the per-mille
## factors on a battle's hype gains and followers (frozen at battle start, campaign only), the floor bonus, the
## achievement chain "Ohne alles" (all six reachable), event runs (no factors, rules.liga / rules.marotten switches in
## rules_hash), and the UI: equipment line, pause tab "Show", show chip, results row.

var _prev_data: GameData = null


func before_each() -> void:
	_prev_data = DB.data
	DB.data = real_data()


func after_each() -> void:
	if Game.state != null:
		Show.end_battle(null)
	Game.in_battle = false
	Game.timer_running = false
	Game.state = null
	Game.run_log = null
	Game.sim = null
	Game.mode = &"campaign"
	Game.clear_blocking_dialogs()
	if _prev_data != null:
		DB.data = _prev_data
	_prev_data = null


func _state() -> GameState:
	var st: GameState = GameState.create_new(real_data(), 0, "Kai", 11)
	RunRules.start_floor(st, real_data(), 1)
	MarottenRules.on_floor(st, real_data(), 1, {})
	return st


static func _strip(st: GameState, member_id: String) -> void:
	var m: PartyMember = st.member(member_id)
	m.equipment["armor"] = ""
	m.equipment["accessory"] = ""


# --- tiers ------------------------------------------------------------------------------------------------------------

func test_tiers_follow_the_slots() -> void:
	var st: GameState = _state()
	assert_eq(MarottenRules.liga_tier(st), 0, "start kit: Kai wears the hoodie")
	assert_eq(MarottenRules.liga_blockers(st, "kai"), PackedStringArray(["itm_arm_hoodie"]))
	assert_eq(MarottenRules.liga_blockers(st, "mopsula"), PackedStringArray(["itm_arm_pug_sweater"]))
	_strip(st, "kai")
	assert_eq(MarottenRules.liga_tier(st), 1, "the controlled hero without armor and accessory: Unterhosen-Liga")
	assert_eq(st.member("kai").equipment["weapon"], "itm_wpn_mop", "the weapon stays allowed")
	_strip(st, "mopsula")
	assert_eq(MarottenRules.liga_tier(st), 2, "both: Duo-Liga")
	st.member("kai").equipment["accessory"] = "itm_acc_gas_mask"
	assert_eq(MarottenRules.liga_tier(st), 0, "an accessory on the hero ends the Liga, even with a bare partner")
	assert_eq(MarottenRules.liga_blockers(st, "kai"), PackedStringArray(["itm_acc_gas_mask"]))
	assert_eq(MarottenRules.liga_tier(st, {"liga": {"enabled": false}}), 0, "rules.liga.enabled false")
	assert_eq(MarottenRules.hero_of(st), "kai", "the controlled hero (GameState.hero, package A)")


## The Liga refers to the CONTROLLED hero (06 §1.7, GameState.hero of package A — merged in integration round 3; the
## former stand-in subclass with its own `hero` field no longer compiles next to the real one): with Mopsula in
## control his slots decide tier 1.
func test_tier_follows_the_controlled_hero() -> void:
	var st: GameState = _state()
	st.hero = "mopsula"
	assert_eq(MarottenRules.hero_of(st), "mopsula")
	_strip(st, "mopsula")
	assert_eq(MarottenRules.liga_tier(st), 1, "Mopsula controlled and bare: tier 1 although Kai wears his hoodie")
	st.hero = "nobody"
	assert_eq(MarottenRules.hero_of(st), "kai", "an unknown hero falls back to Kai")


func test_factors_and_text() -> void:
	var d: GameData = real_data()
	assert_eq(MarottenRules.liga_pm(d, 0, &"hype"), 1000)
	# 06 §4.3 / §4.10 (integration round 4, 06 §8.8 I-8): tier 1 hype ×1.05 / followers ×1.1 (at most +60 per floor),
	# tier 2 ×1.2 / ×1.35 (at most +180 per floor) — package C had ×1.2 / ×1.15 and ×1.4 / ×1.35 without a cap
	assert_eq(MarottenRules.liga_pm(d, 1, &"hype"), 1050)
	assert_eq(MarottenRules.liga_pm(d, 1, &"follower"), 1100)
	assert_eq(MarottenRules.liga_pm(d, 2, &"hype"), 1200)
	assert_eq(MarottenRules.liga_pm(d, 2, &"follower"), 1350)
	assert_eq([MarottenRules.liga_floor_cap(d, 1), MarottenRules.liga_floor_cap(d, 2)], [60, 180])
	assert_eq(Show.pm_text(1250), "1,25")
	assert_eq(Show.pm_text(1500), "1,5")
	assert_eq(Show.pm_text(1000), "1")
	assert_eq(Show.pm_text(1200), "1,2")


# --- Show: factors of a battle ----------------------------------------------------------------------------------------

## The same synthetic battle at tier 0 and tier 2: hype gains ×1.2 (start hype 3 → 3.6 → 4) and the follower
## conversion ×1.35 (its bonus capped per floor, test_06c_liga_cap); the tier is frozen at battle start (putting the
## hoodie on mid-battle changes nothing).
func test_show_scales_hype_and_followers_by_tier() -> void:
	var plain: Dictionary = _battle(false)
	var liga: Dictionary = _battle(true)
	assert_eq(plain["start_hype"], 3, "normal battle start +3")
	assert_eq(liga["start_hype"], 4, "Duo-Liga: 3 × 1.2 = 3.6 → 4 (per mille, half up)")
	assert_gt(int(liga["followers"]), int(plain["followers"]), "more followers in the Duo-Liga")
	assert_eq(liga["liga_tier"], 2)
	assert_eq(Show.last_marotten()["liga_tier"], 2, "results screen: the battle's tier")


func _battle(bare: bool) -> Dictionary:
	Game.new_game(0, "Kai", 6161)
	var st: GameState = Game.state
	for a: AchievementDef in DB.data.all_achievements():
		st.show.achievements.append(a.id)                 # no achievement hype in between
	st.show.marotten["active"] = []
	if bare:
		_strip(st, "kai")
		_strip(st, "mopsula")
	var setup: BattleSetup = BattleBridge.make_setup(st, DB.data, "enc_f1_a2", BattleSetup.Advantage.NORMAL, "",
		SeedUtil.derive(1, "t", 1))
	Game.in_battle = true
	Show.begin_battle(setup)
	var h0: float = Show.hype()
	var start: ActionEvent = ActionEvent.make(ActionEvent.Type.BATTLE_START)
	Show.on_battle_event(start)
	var start_hype: int = roundi(Show.hype() - h0)
	st.member("kai").equipment["armor"] = "itm_arm_hoodie"   # mid-battle change: the frozen tier counts
	var r: BattleResult = BattleResult.new()
	r.outcome = BattleResult.Outcome.VICTORY
	r.encounter_id = "enc_f1_a2"
	r.party_turns = 4
	r.min_party_hp_pct = 0.9
	r.damage_taken = 10
	Game.in_battle = false
	var f: int = Show.end_battle(r)
	return {"start_hype": start_hype, "followers": f, "liga_tier": Show.last_marotten().get("liga_tier", -1)}


## Event runs: the tier is shown, but no factor applies (06 §4.8 Nr. 4: the score never depends on the Liga).
func test_event_runs_have_no_factors() -> void:
	Game.new_game(0, "Kai", 6262)
	_strip(Game.state, "kai")
	_strip(Game.state, "mopsula")
	var setup: BattleSetup = BattleBridge.make_setup(Game.state, DB.data, "enc_f1_a2", BattleSetup.Advantage.NORMAL, "",
		SeedUtil.derive(1, "t", 2))
	var rules: Dictionary = {"leagues": ["pur"], "mode": "solo"}
	assert_false(MarottenRules.rewards_on(rules))
	Show.begin_battle(setup)
	assert_eq(Show.get("_liga_hype_pm"), 1200, "campaign: the Duo-Liga factor is set")
	Show.end_battle(null)
	Game.mode = &"event_offline"
	Game.set("_event_def", _event())
	Show.begin_battle(setup)
	assert_eq(Show.get("_liga_hype_pm"), 1000, "event run: neutral")
	assert_eq(Show.get("_liga_follower_pm"), 1000)
	assert_eq(Show.marotten_view()["liga_tier"], 2, "the tier is still shown")
	assert_false(Show.marotten_view()["rewards"])
	Show.end_battle(null)
	Game.set("_event_def", null)


func _event() -> EventDef:
	var cat: EventCatalog = EventCatalog.new()
	cat.load_file("res://data/events.json")
	return cat.get_event("evt_offline_gleis9")


func test_rules_switches_validate_and_change_the_rules_hash() -> void:
	var def: EventDef = _event()
	assert_not_null(def)
	if def == null:
		return
	var base: String = def.rules_hash()
	var off: EventDef = EventDef.from_dict(_event_dict(def, {"marotten": {"enabled": false},
		"liga": {"enabled": false}}))
	assert_ne(off.rules_hash(), base, "rules.marotten / rules.liga are part of rules_hash")
	assert_eq(off.validate(real_data()), PackedStringArray(), "valid switches")
	var bad: EventDef = EventDef.from_dict(_event_dict(def, {"liga": {"enabled": 1, "extra": true}}))
	var errs: String = "; ".join(bad.validate(real_data()))
	assert_has(errs, "rules.liga.enabled must be a bool")
	assert_has(errs, "rules.liga: unknown key 'extra'")
	assert_false(MarottenRules.enabled({"marotten": {"enabled": false}}))
	assert_true(MarottenRules.enabled({"leagues": ["pur"]}), "default on")


func _event_dict(def: EventDef, extra_rules: Dictionary) -> Dictionary:
	var raw: Dictionary = {}
	for e: Variant in (JsonUtil.read_file("res://data/events.json") as Dictionary)["events"]:
		if str((e as Dictionary).get("id", "")) == def.id:
			raw = (e as Dictionary).duplicate(true)
	(raw["rules"] as Dictionary).merge(extra_rules, true)
	return raw


# --- floor bonus and achievement chain --------------------------------------------------------------------------------

func test_floor_bonus_needs_every_battle_in_the_liga() -> void:
	var st: GameState = _state()
	var d: GameData = real_data()
	st.show.marotten["liga"] = {"battles": 3, "t1": 3, "t2": 0}
	var r1: Dictionary = MarottenRules.on_floor_end(st, d, 1, {})
	assert_eq(r1["boxes"], ["box_fan"], "3 of 3 battles in the Liga: the Mut-Paket")
	assert_eq(r1["floor_tier"], 1)
	st.show.marotten["liga"] = {"battles": 4, "t1": 3, "t2": 0}
	assert_eq(MarottenRules.on_floor_end(st, d, 1, {})["boxes"], [], "one battle outside the Liga: no bonus")
	st.show.marotten["liga"] = {"battles": 2, "t1": 2, "t2": 2}
	assert_eq(MarottenRules.on_floor_end(st, d, 1, {})["boxes"], [], "fewer than 3 battles")
	st.show.marotten["liga"] = {"battles": 5, "t1": 5, "t2": 5}
	var r2: Dictionary = MarottenRules.on_floor_end(st, d, 1, {})
	assert_eq(r2["floor_tier"], 2)
	var p: Dictionary = (r2["show_bet"] as Array)[0]
	assert_eq([p["kind"], p["event"], p["floor_tier"], p["battles"]], ["liga", "floor", 2, 5])
	assert_eq(MarottenRules.on_floor_end(st, d, 1, {"leagues": ["pur"]})["boxes"], [], "event runs: no box")


## All six achievements of the chain "Ohne alles" unlock from MarottenRules payloads through Show.trigger.
func test_achievement_chain_is_reachable() -> void:
	Game.new_game(0, "Kai", 6363)
	var st: GameState = Game.state
	_strip(st, "kai")
	_strip(st, "mopsula")
	var d: GameData = real_data()
	st.show.marotten["active"] = []
	var boss: BattleResult = BattleResult.new()
	boss.outcome = BattleResult.Outcome.VICTORY
	boss.is_boss = true
	boss.encounter_id = DB.floor_def(1).floor_boss
	boss.boss_id = "enm_boss_rattenkoenigin"
	boss.party_kos = 0
	var res: Dictionary = MarottenRules.on_battle_end(st, d, boss, {"liga_tier": 2, "tutorial": false}, {})
	for p: Variant in res["show_bet"]:
		Show.trigger("show_bet", p as Dictionary)
	for id: String in ["ach_ul_first", "ach_ul_boss", "ach_duo_first", "ach_duo_flawless"]:
		assert_true(Show.is_unlocked(id), id + " (a won floor boss in the Duo-Liga without K.O.)")
	st.show.marotten["liga"] = {"battles": 5, "t1": 5, "t2": 5}
	for p2: Variant in MarottenRules.on_floor_end(st, d, 1, {})["show_bet"]:
		Show.trigger("show_bet", p2 as Dictionary)
	assert_true(Show.is_unlocked("ach_duo_floor"))
	st.show.stats["bets_won"] = 5
	Show.trigger("show_bet", {"kind": "marotte", "event": "won", "id": "mar_mop_only", "tier": 0, "floor_tier": 0,
		"battles": 0, "is_boss": false, "is_floor_boss": false, "boss_id": "", "party_kos": 0, "floor": 1})
	assert_true(Show.is_unlocked("ach_bets_5"))


## Live: taking the hoodie off (recorded equip) puts the next battle in the Liga — tier line, toast, stat, replay.
func test_live_liga_battle_replays() -> void:
	Game.auto_battle = true
	Game.new_game(0, "Kai", 6464)
	var toasts: Array = []
	var cb: Callable = func(_text: String, icon: StringName) -> void: toasts.append(String(icon))
	Events.toast_requested.connect(cb)
	var tiers: Array = []
	var cb2: Callable = func(t: int) -> void: tiers.append(t)
	Events.liga_changed.connect(cb2)
	_fight(DB.floor_def(1).timer_start_after)
	assert_true(Game.equip("kai", "armor", ""), "hoodie off")
	var won: bool = _fight("enc_f1_a2")
	Events.toast_requested.disconnect(cb)
	Events.liga_changed.disconnect(cb2)
	Game.auto_battle = false
	assert_true(won, "the Liga battle is won")
	assert_has(toasts, "liga", "the Liga toast with its rule")
	assert_eq(tiers, [0, 1], "tutorial outside, then the Liga")
	assert_eq(int(Game.state.show.stats.get("liga_battles", 0)), 1)
	assert_true(Show.is_unlocked("ach_ul_first"), "Einmal ohne alles")
	var h: String = StateHash.of(Game.state)
	var res: Dictionary = Game.replay_log(Game.run_log)
	assert_eq(res["errors"], PackedStringArray())
	assert_eq(res["final_hash"], h, "replay ≡ live with the Liga factors")


func _fight(enc_id: String) -> bool:
	var setup: BattleSetup = Game.make_battle_setup(enc_id, BattleSetup.Advantage.PREEMPTIVE, "")
	var battle: BattleState = BattleState.new(setup, DB.data)
	Show.begin_battle(setup)
	_play(battle, battle.start())
	var guard: int = 0
	while not battle.is_finished() and guard < 400:
		guard += 1
		var cmd: BattleCommand = battle.choose_ai_command()
		Game.record({"t": "battle", "cmd": cmd.to_dict(), "auto": true})
		_play(battle, battle.submit(cmd))
	Game.apply_battle_result(battle.result)
	Show.end_battle(battle.result)
	return battle.result.outcome == BattleResult.Outcome.VICTORY


func _play(battle: BattleState, events: Array[ActionEvent]) -> void:
	for e: ActionEvent in events:
		Show.on_battle_event(e)
	if battle.is_finished():
		return
	var g: Dictionary = Show.take_pending_gift(battle)
	if not g.is_empty():
		var gift_events: Array[ActionEvent] = battle.apply_gift(g)
		Show.note_battle_gift(g, gift_events)
		for e: ActionEvent in gift_events:
			Show.on_battle_event(e)


# --- UI ---------------------------------------------------------------------------------------------------------------

func test_equipment_menu_names_the_blockers() -> void:
	Game.new_game(0, "Kai", 6565)
	var page: Control = (load("res://scenes/ui/equipment_menu.gd") as GDScript).new() as Control
	add_to_tree(page)
	await wait_frames(2)
	var line: Label = page.get("liga_line") as Label
	assert_eq(line.text, "Liga blockiert durch: Tierheim-Hoodie")
	assert_eq((page.get("liga_tier_line") as Label).text, "Aktuell: keine Liga")
	page.call("equip", "armor", "")
	await wait_frames(1)
	assert_eq(line.text, "Liga-bereit: ohne Rüstung & ohne Accessoire")
	assert_eq((page.get("liga_tier_line") as Label).text, "Aktuell: Unterhosen-Liga (Hype ×1,05)")
	page.queue_free()


func test_show_tab_lists_preferences_and_liga() -> void:
	Game.new_game(0, "Kai", 6666)
	var page: Control = (load("res://scenes/ui/bets_menu.gd") as GDScript).new() as Control
	add_to_tree(page)
	await wait_frames(2)
	assert_eq(page.call("row_count"), 1 + 2, "one preference (floor 1) + one row per member")
	var bet: Node = page.find_child("Bet_" + str(Game.state.show.marotten["active"][0]), true, false)
	assert_not_null(bet, "the preference row")
	var kai_row: Button = page.find_child("Member_kai", true, false) as Button
	assert_not_null(kai_row)
	var opened: Array = []
	page.connect("open_equipment", func(id: String) -> void: opened.append(id))
	kai_row.pressed.emit()
	assert_eq(opened, ["kai"], "a member row opens that member's equipment")
	page.queue_free()


## Ten pause tabs since "Show": every caption fits its tab (regression: "Achievements" was cut to "Achievemen…").
func test_pause_tabs_show_full_captions() -> void:
	Game.new_game(0, "Kai", 6868)
	var pm: Node = (load("res://scenes/ui/pause_menu.tscn") as PackedScene).instantiate()
	pm.call("setup", {"tab": "show", "context": "explore"})
	add_to_tree(pm)
	await wait_frames(3)
	var tabs: Dictionary = pm.get("_tab_buttons")
	assert_true(tabs.has("show"), "the Show tab exists")
	var checked: int = 0
	for id: Variant in tabs.keys():
		var l: Label = (tabs[id] as Node).find_child("Text", true, false) as Label
		if l == null or l.text == "":
			continue
		var w: float = l.get_theme_font(&"font").get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		assert_true(w <= l.size.x + 0.5, "tab '%s': caption %.0f px fits %.0f px" % [l.text, w, l.size.x])
		checked += 1
	assert_gt(checked, 8, "all captions checked")
	tree.paused = false
	pm.queue_free()


## The chip: hidden before the countdown, then "M.O.D. mag heute: <name>" with hearts; the Liga appends its tier.
func test_show_chip_in_the_overlay() -> void:
	Game.new_game(0, "Kai", 6767)
	var o: CanvasLayer = (load("res://scenes/ui/show_overlay.tscn") as PackedScene).instantiate() as CanvasLayer
	o.call("setup", {})
	add_to_tree(o)
	await wait_frames(1)
	o.call("set_mode", &"explore")
	assert_eq(o.call("show_chip_text"), "", "floor 1 before the tutorial: no chip (one new thing at a time)")
	Game.state.floor_run.timer_started = true
	o.call("refresh_show_chip")
	var id: String = str(Game.state.show.marotten["active"][0])
	assert_eq(o.call("show_chip_text"), "M.O.D. mag heute: " + DB.data.marotte(id).name)
	assert_eq(o.call("show_chip_hearts"), "♡♡♡")
	assert_eq(o.call("show_chip_liga"), "")
	Game.state.show.marotten["hits"] = {id: 2}
	_strip(Game.state, "kai")
	o.call("refresh_show_chip")
	assert_eq(o.call("show_chip_hearts"), "♥♥♡")
	assert_eq(o.call("show_chip_liga"), "LIGA ×1,05")
	Game.state.show.marotten["won"] = [id]
	o.call("refresh_show_chip")
	assert_eq(o.call("show_chip_hearts"), "✓", "a won bet: golden check")
	var r: Rect2 = o.call("show_chip_rect")
	assert_true(r.size.x > 0.0 and r.position.y >= 200.0, "explore: below the minimap column (%s)" % str(r))
	o.call("set_mode", &"safe_room")
	assert_eq(o.call("show_chip_text"), "", "not in the safe room")
	o.call("set_mode", &"battle")
	assert_ne(o.call("show_chip_text"), "", "battle: under the hype meter")
	Events.battle_ended.emit(BattleResult.Outcome.VICTORY, "enc_f1_a2")
	assert_eq(o.call("show_chip_text"), "", "results screen: the panel shows the hearts, the chip waits")
	Events.battle_started.emit("enc_f1_a3", false)
	assert_ne(o.call("show_chip_text"), "", "next battle: back")
	Events.battle_ended.emit(BattleResult.Outcome.VICTORY, "enc_f1_a3")
	o.call("set_mode", &"explore")
	assert_ne(o.call("show_chip_text"), "", "exploration after the results: back")
	o.call("set_mode", &"battle")
	# 06 §4.8 Nr. 8: Optionen → "Show-Wetten anzeigen" switches the chip off (the bets keep counting)
	var was: bool = Game.settings.show_bets_hud
	Game.settings.show_bets_hud = false
	Events.settings_changed.emit()
	assert_eq(o.call("show_chip_text"), "", "switched off in the options")
	Game.settings.show_bets_hud = was
	Events.settings_changed.emit()
	assert_ne(o.call("show_chip_text"), "", "back on")
	o.queue_free()
