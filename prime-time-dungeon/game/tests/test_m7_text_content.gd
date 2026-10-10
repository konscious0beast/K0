extends TestCase
## M7 texts (01_GDD §10.2, §11; 02_TECH §4.1, §4.4.12–13): M.O.D./chat/Mopsula lines per tag with the GDD minimum
## counts, voices, length/placeholder rules, line ids, Mopsula scenes (conditions, order, flags) and German-only display
## texts.
## Scene conditions follow GDD §10.2 (`scn_mop_1` `>= 1`, `scn_mop_4` without `first_visit`: a scene skipped on the
## first visit stays available); 02_TECH §4.4.13 was aligned to it in the integration phase.

## GDD §11.2/§11.3: tag → minimum number of lines.
const MIN_LINES: Dictionary = {
	"intro": 3, "floor_start": 2, "first_fight": 2, "achievement_generic": 4, "low_hp": 3, "kill_streak": 3, "crit": 2,
	"weakness": 2, "overkill": 2, "stunt_success": 3, "stunt_fail": 3, "boring_fight": 3, "flee": 3, "flee_fail": 2,
	"sponsor_gift": 3, "timer_warn_300": 3, "timer_warn_60": 3, "timer_expired": 2, "lootbox_open_bronze": 3,
	"lootbox_open_silver": 2, "lootbox_open_gold": 2, "lootbox_open_fan": 2, "lootbox_pity": 1, "death": 3,
	"mopsula_ko": 2, "kai_ko": 2, "revive": 1, "boss_intro:enm_boss_hausmeister": 2,
	"boss_phase:enm_boss_hausmeister:2": 1, "boss_phase:enm_boss_hausmeister:3": 1,
	"boss_intro:enm_boss_rattenkoenigin": 2, "boss_phase:enm_boss_rattenkoenigin:2": 1, "boss_train_warning": 1,
	"boss_phase:enm_boss_rattenkoenigin:3": 1, "boss_defeated": 2, "level_up": 2, "follower_milestone": 2,
	"safe_room_enter": 3, "vendor_buy": 2, "stairs_found": 2, "floor_end": 2,
	"timer_warn_600": 2, "chat_handle": 8, "chat_hype_high": 3, "chat_hype_mid": 3, "chat_hype_low": 3, "chat_crit": 3,
	"chat_stunt_fail": 3, "chat_boring": 3, "chat_mopsula": 3, "mopsula_idle": 5, "event_photo_drone_pose": 1,
	"event_photo_drone_smash": 1, "event_lost_candidate_give": 1, "event_lost_candidate_leave": 1,
	"event_wheel_spin": 2, "event_lever_open": 1, "event_lever_flood": 1, "event_broken_vending_ok": 1,
	"event_broken_vending_fail": 1,
}
## 05_LIVE_MODUS CR-9: optional SHOWRUN tags provided for the offline event run.
const LIVE_TAGS: PackedStringArray = ["event_run_start", "event_quest_progress", "event_quest_complete", "event_result",
	"gift_received", "gift_received:credits", "gift_received:anon"]


## Every loaded line (GameData has no id getter for mod lines: collect them per tag of the source file).
func _all_lines() -> Array[ModLineDef]:
	var d: GameData = real_data()
	var out: Array[ModLineDef] = []
	var raw: Variant = JsonUtil.read_file("res://data/mod_lines.json")
	if not raw is Dictionary:
		fail("mod_lines.json does not parse")
		return out
	var tags: Dictionary = {}
	for e: Dictionary in (raw as Dictionary)["entries"]:
		tags[str(e["tag"])] = true
	for tag: Variant in tags:
		out.append_array(d.mod_lines(str(tag)))
	assert_eq(out.size(), d.ids("mod_lines").size(), "every line reachable via its tag")
	return out


func test_line_counts_cover_the_gdd() -> void:
	var d: GameData = real_data()
	var lines: Array[ModLineDef] = _all_lines()
	assert_gt(lines.size(), 164, "GDD §11: 90 + 46 + 29 = 165 lines (+ live tags)")
	for tag: String in MIN_LINES:
		assert_true(d.mod_lines(tag).size() >= int(MIN_LINES[tag]), "%s: %d lines, need %d" % [tag,
			d.mod_lines(tag).size(), int(MIN_LINES[tag])])
	for tag: String in DataValidator.REQUIRED_MOD_TAGS:
		assert_gt(d.mod_lines(tag).size(), 0, "required tag " + tag)
	for a: AchievementDef in d.all_achievements():
		assert_len(d.mod_lines("achievement:" + a.id), 1, "one line per achievement: " + a.id)
	for tag: String in LIVE_TAGS:
		assert_gt(d.mod_lines(tag).size(), 0, "live tag " + tag)
	for f: FloorDef in d.all_floors():
		for v: int in f.timer_warnings:
			assert_gt(d.mod_lines("timer_warn_%d" % v).size(), 0, "timer_warn_%d" % v)


func test_line_rules() -> void:
	var lines: Array[ModLineDef] = _all_lines()
	var ids: Dictionary = {}
	for l: ModLineDef in lines:
		assert_false(ids.has(l.id), "unique id " + l.id)
		ids[l.id] = true
		var expected_prefix: String = "mod_" + l.tag.replace(":", "_") + "_"
		assert_true(l.id.begins_with(expected_prefix), "%s follows mod_<tag>_<nn> (%s)" % [l.id, expected_prefix])
		assert_true(l.id.trim_prefix(expected_prefix).is_valid_int(), l.id + " ends with a number")
		assert_between(l.text.length(), 1, 110, l.id)
		assert_eq(l.text, l.text.strip_edges(), l.id + " has no surrounding whitespace")
		for ph: String in DataValidator.placeholders_in(l.text):
			assert_has(DataValidator.TEXT_PLACEHOLDERS, ph, l.id)
		# Voices: chat_* and the 10-minute warning are chat; mopsula_idle and the Regie monologue (06-D,
		# tw_mopsula_monologue) are the count himself; the rest is M.O.D.
		var want_voice: String = "mod"
		if l.tag.begins_with("chat_") or l.tag == "timer_warn_600":
			want_voice = "chat"
		elif l.tag == "mopsula_idle" or l.tag.begins_with("regie_monologue_"):
			want_voice = "mopsula"
		assert_eq(l.voice, want_voice, l.id + " voice")
		assert_eq(l.user, "", l.id + ": senders come from chat_handle")
		assert_true(l.min_floor <= 1 or l.max_floor == 0 or l.min_floor <= l.max_floor, l.id)


func test_lines_exist_for_every_floor() -> void:
	# Floor-specific lines (max_floor 1) must leave a generic fallback for later floors.
	var d: GameData = real_data()
	for tag: String in ["timer_warn_300", "stairs_found", "floor_end", "floor_start"]:
		for floor_index: int in [1, 2]:
			var n: int = 0
			for l: ModLineDef in d.mod_lines(tag):
				if l.fits(floor_index, 50.0):
					n += 1
			assert_gt(n, 0, "%s has a line on floor %d" % [tag, floor_index])


func test_placeholders_match_their_tags() -> void:
	# Lines only use placeholders their caller can provide.
	var d: GameData = real_data()
	var allowed: Dictionary = {
		"sponsor_gift": ["sponsor", "name"], "vendor_buy": ["item", "name"], "level_up": ["level", "member", "name"],
		"follower_milestone": ["followers", "name"], "achievement_generic": ["achievement", "name"],
		"floor_start": ["floor", "name"], "floor_end": ["floor", "name"],
	}
	for tag: String in allowed:
		for l: ModLineDef in d.mod_lines(tag):
			for ph: String in DataValidator.placeholders_in(l.text):
				assert_has(allowed[tag], ph, l.id)
	assert_true(d.mod_lines("sponsor_gift")[0].text.contains("{sponsor}"))
	var milestone_has_count: bool = false
	for l: ModLineDef in d.mod_lines("follower_milestone"):
		if l.text.contains("{followers}"):
			milestone_has_count = true
	assert_true(milestone_has_count)


func test_display_texts_are_german_and_complete() -> void:
	var d: GameData = real_data()
	for s: SkillDef in d.all_skills():
		assert_ne(s.name, "", s.id + " name")
		assert_ne(s.desc, "", s.id + " desc")
	for it: ItemDef in d.all_items():
		assert_ne(it.name, "", it.id)
		assert_ne(it.desc, "", it.id + " desc")
		assert_ne(it.icon, "", it.id + " icon")
	for e: EnemyDef in d.all_enemies():
		assert_ne(e.name, "", e.id)
	for a: AchievementDef in d.all_achievements():
		assert_ne(a.desc, "", a.id)
	# Spot checks: GDD names are used verbatim (gettext msgids).
	assert_eq(d.skill("skl_kai_heavy_swing").name, "Wuchtschlag")
	assert_eq(d.skill("skl_mop_holy_lick").name, "Heiliges Schlabbern")
	assert_eq(d.skill("skl_stunt_mop_entrance").name, "Auftritt Seiner Durchlaucht")
	assert_eq(d.item("itm_bandage").name, "Werbepflaster")
	assert_eq(d.item("itm_key_master").name, "Generalschlüssel")
	assert_eq(d.enemy("enm_boss_rattenkoenigin").name, "Die Rattenkönigin von Gleis 9")
	assert_eq(d.achievement("ach_queen").name, "Gleis 9 geräumt")
	assert_eq(d.floor_def(1).name, "Etage 1 – Die Unterstadt")
	assert_eq(d.status("sts_haste").name, "Turbo")


# --- scenes --------------------------------------------------------------------------------------------------------

func test_scenes_match_gdd() -> void:
	var d: GameData = real_data()
	var order: Array = []
	for s: SceneDef in d.all_scenes():
		order.append(s.id)
		assert_true(s.once, s.id)
		assert_between(s.lines.size(), 4, 40, s.id)
		var voices: Dictionary = {}
		for l: Dictionary in s.lines:
			voices[str(l["voice"])] = true
			assert_between(str(l["text"]).length(), 1, 110, s.id)
		assert_true(voices.has("mopsula") and voices.has("kai"), s.id + " is a Mopsula/Kai dialogue")
	assert_eq(order, ["scn_mop_4", "scn_mop_1", "scn_mop_2", "scn_mop_3"], "sorted by priority")
	assert_eq(d.scene_def("scn_mop_4").set_flag, "mop_pep_talk")
	for id: String in ["scn_mop_1", "scn_mop_2", "scn_mop_3"]:
		assert_eq(d.scene_def(id).set_flag, "", id)
	assert_eq(d.scene_def("scn_mop_1").name, "Seine Durchlaucht")
	assert_eq(d.scene_def("scn_mop_4").name, "Vor dem Thron")
	assert_eq(str(d.scene_def("scn_mop_2").lines[5]["text"]), "EIN SEHR VORNEHMER KOFFERRAUM.")


func test_scene_conditions() -> void:
	var d: GameData = real_data()
	var first_kiosk: Dictionary = {"safe_room_id": "sr_kiosk", "first_visit": true, "safe_room_visits": 1, "kai_level": 2}
	var later_kiosk: Dictionary = {"safe_room_id": "sr_kiosk", "first_visit": false, "safe_room_visits": 3,
		"kai_level": 4}
	var signalbox: Dictionary = {"safe_room_id": "sr_signalbox", "first_visit": true, "safe_room_visits": 4,
		"kai_level": 6}
	var s1: ConditionExpr = d.scene_def("scn_mop_1").expr
	var s2: ConditionExpr = d.scene_def("scn_mop_2").expr
	var s3: ConditionExpr = d.scene_def("scn_mop_3").expr
	var s4: ConditionExpr = d.scene_def("scn_mop_4").expr
	assert_true(s1.eval(first_kiosk, {}, {}), "scene 1 on the first safe-room visit")
	assert_true(s1.eval(later_kiosk, {}, {}), "…and stays available if skipped (GDD §10.2)")
	assert_false(s2.eval(first_kiosk, {}, {}), "scene 2 needs the Hausmeister defeated")
	assert_true(s2.eval(first_kiosk, {}, {"defeated_enm_boss_hausmeister": true}))
	assert_false(s3.eval(later_kiosk, {}, {}), "scene 3 needs scene 1 seen")
	assert_false(s3.eval(first_kiosk, {}, {"scene_scn_mop_1": true}), "scene 3 needs Kai level 4")
	assert_true(s3.eval(later_kiosk, {}, {"scene_scn_mop_1": true}))
	assert_false(s4.eval(later_kiosk, {}, {}), "scene 4 only in the Stellwerk")
	assert_true(s4.eval(signalbox, {}, {}))


# --- open content gaps (blocked by M0 vocabularies) ----------------------------------------------------------------

## GDD §1.4 B1/B2 tutorial hints and the B4 banner need a tag prefix (e.g. `tutorial_`/`story_`), and 05 §6.12 gift
## lines need `{sender}`/`{amount}`; DataValidator (M0) knows neither yet. Skipped (= visibly open) until the M0 change
## requests land; then it fails until the lines are added and the 05 §6.12 texts restored verbatim.
func test_pending_story_and_gift_lines() -> void:
	var missing: PackedStringArray = []
	for p: String in ["tutorial_", "story_"]:
		if not DataValidator.OPTIONAL_MOD_TAG_PREFIXES.has(p):
			missing.append("tag prefix " + p)
	for ph: String in ["sender", "amount"]:
		if not DataValidator.TEXT_PLACEHOLDERS.has(ph):
			missing.append("placeholder {%s}" % ph)
	if not missing.is_empty():
		skip("open M0 CR: DataValidator lacks " + ", ".join(missing))
		return
	var d: GameData = real_data()
	var prefixed: Dictionary = {"tutorial_": 0, "story_": 0}
	var queen_banner: bool = false
	for l: ModLineDef in _all_lines():
		for p: String in prefixed:
			if l.tag.begins_with(p):
				prefixed[p] = int(prefixed[p]) + 1
		queen_banner = queen_banner or l.text == "Die Königin hört von euch."
	assert_gt(int(prefixed["tutorial_"]), 0, "GDD §1.4 B1/B2 tutorial hints")
	assert_gt(int(prefixed["story_"]), 0, "GDD §1.4 story beats")
	assert_true(queen_banner, "GDD §1.4 B4 banner „Die Königin hört von euch.“")
	for l: ModLineDef in d.mod_lines("gift_received"):
		assert_true(l.text.contains("{sender}"), "05 §6.12: gift_received names {sender}")
	for l: ModLineDef in d.mod_lines("gift_received:credits"):
		assert_true(l.text.contains("{amount}"), "05 §6.12: gift_received:credits names {amount}")
	# story_battle:<encounter_id> (the validator checks the format only, fixtures replace the floor tables)
	for l: ModLineDef in _all_lines():
		if l.tag.begins_with("story_battle:"):
			assert_true(d.has_id("encounters", l.tag.get_slice(":", 1)), l.id + " names an existing encounter")
	for tag: String in ["gift_diminished", "gift_capped", "gift_declined", "fan_pack_received", "live_closing",
			"vote_open"]:
		assert_false(d.mod_lines(tag).is_empty(), "05 §6.12 line " + tag)


## GDD §1.4 story beats are spoken by Show (consumers of the tutorial_/story_ lines): B1 hints on the first entry of
## floor 1 (countdown not started), B2 skill hint at the start and stunt hint after the 2nd party turn of the tutorial
## battle, B4 banner at the start of enc_f1_b2.
func test_story_lines_are_spoken() -> void:
	var lines: Array = []
	var cb: Callable = func(text: String, _v: StringName, tag: String, _b: bool) -> void: lines.append([tag, text])
	Events.mod_said.connect(cb)
	Game.new_game(0, "Kai", 1234)
	lines.clear()
	Events.floor_entered.emit(1)
	var tags: Array = lines.map(func(l: Array) -> String: return str(l[0]))
	assert_eq(tags, ["tutorial_explore", "tutorial_sneak"], "B1 hints before the tutorial battle")
	var tut: BattleSetup = Game.make_battle_setup("enc_f1_a1_tutorial", BattleSetup.Advantage.NORMAL, "f1_g0")
	lines.clear()
	Show.begin_battle(tut)
	tags = lines.map(func(l: Array) -> String: return str(l[0]))
	assert_has(tags, "tutorial_battle", "B2 hint at the tutorial battle start")
	for i in 2:
		var e: ActionEvent = ActionEvent.new()
		e.type = ActionEvent.Type.TURN_END
		e.actor_id = "p%d" % i
		Show.on_battle_event(e)
	assert_eq(str((lines.back() as Array)[0]), "tutorial_stunt", "B2 stunt hint after the 2nd party turn")
	Show.abort_battle()
	Game.state.floor_run.timer_started = true
	lines.clear()
	Events.floor_entered.emit(1)
	assert_eq(lines, [], "no tutorial hints once the countdown runs")
	var b2: BattleSetup = Game.make_battle_setup("enc_f1_b2", BattleSetup.Advantage.NORMAL, "f1_g6")
	lines.clear()
	Show.begin_battle(b2)
	assert_has(lines, ["story_battle:enc_f1_b2", "Die Königin hört von euch."], "B4 banner")
	Show.abort_battle()
	Events.mod_said.disconnect(cb)
	Game.in_battle = false
	Game.state = null
	Game.run_log = null
	Game.sim = null
