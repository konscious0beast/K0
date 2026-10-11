extends TestCase
## 08 §4 (K1): block K of mod_lines.json and the persona hooks. Placeholders only the persona's ({job_text} only in
## persona_intro:custom), the length rule <= 110 with the longest values; >= 3 general lines per hook, >= 2 intro
## variants and a card line per Vorleben, 2 rivals per Vorleben; 3 broadcast plans chosen from the seed, at most one
## line per hook event (the intro two), every planned tag has lines; persona_* are always said and have no cooldown;
## never during a battle (CTB and the real-time fixture) — no persona and no AI line, a waiting one expires; the word
## lists, foot words, no royal plural and no crown motifs for Graf Mopsula; {club} with its possessive and a singular
## verb, {job} never "von Beruf"; scn_mop_4 with every word form (fixture); the review matrix builds.

const Matrix := preload("res://tests/tools/persona_matrix_builder.gd")
const UiUtil := preload("res://scenes/ui/ui_util.gd")
const FORMS_FIXTURE: String = "res://tests/fixtures/persona/scn_mop_4_forms.json"
const HOOK_TAGS: PackedStringArray = ["persona_intro", "persona_first_chest", "persona_boss_won", "persona_safe_room",
	"persona_floor_end", "persona_game_over", "persona_marotte"]
const HOOKS: Array[StringName] = [&"intro", &"first_chest", &"boss_won", &"safe_room", &"floor_end", &"summary",
	&"game_over", &"floor_start"]
## Tag families of block K → what their suffix names ("" = no suffix).
const FAMILIES: Dictionary = {"persona_intro": "origin|custom", "persona_card": "origin", "persona_first_chest": "",
	"persona_boss_won": "origin", "persona_safe_room": "hobby", "persona_floor_end": "origin",
	"persona_game_over": "origin", "persona_beat_rival": "intro|result|taunt", "persona_beat_greeting": "greeting",
	"persona_beat_sponsor": "intro|thanks", "persona_gag": "gag", "persona_marotte": "", "persona_spec_hint": "class",
	"persona_casting_open": "mopsula", "persona_casting_brief": "", "persona_casting_dice": "",
	"persona_casting_ai_wait": "", "persona_casting_ai_offline": ""}
const FOOT: PackedStringArray = ["barfuß", "barfuss", "schuh", "füße", "füsse", "fuesse", "fuß", "socke", "zehen"]
const CROWN: PackedStringArray = ["krone", "königlich", "majestät", "majestaet", "thron", "zepter", "hoheit", "royal"]
const CLUB_PLURAL: String = "\\{club\\} (haben|sind|waren|schauen|halten|rufen|schicken|lassen|grüßen|drücken|" + \
	"winken|jubeln|fiebern|warten|gießen|lesen|laufen|bauen|kochen|backen)\\b"
const SEED: int = 4711

var _said: Array[String] = []


func before_each() -> void:
	_said.clear()
	Events.mod_said.connect(_on_said)


func after_each() -> void:
	if Events.mod_said.is_connected(_on_said):
		Events.mod_said.disconnect(_on_said)
	Game.state = null
	Game.run_log = null
	Game.sim = null
	Game.persona = null
	Game.combat = null
	Game.mode = &"campaign"
	Game.timer_running = false
	Game.in_battle = false
	Game.safe_room_clock = false


func _on_said(_text: String, _voice: StringName, tag: String, _blocking: bool) -> void:
	_said.append(tag)


func _persona_said() -> PackedStringArray:
	var out: PackedStringArray = []
	for t: String in _said:
		if t.begins_with("persona_"):
			out.append(t)
	return out


static func _lines() -> Array:
	return Matrix.persona_lines()


static func _jana() -> PersonaProfile:
	var p: PersonaProfile = PersonaProfile.canon(DB.data)
	p.name = "Jana"
	p.form = "f"
	p.origin = "org_care"
	p.occupation = "occ_care_midwife"
	p.hobby = "hob_cooking"
	p.traits = PackedStringArray(["trt_chaotic", "trt_caring"])
	p.source = "offline"
	p.make_beats(DB.data, null)
	return p


## The quarter boss of floor 1 (its first enemy id): H3's first boss of the floor.
static func _quarter_boss() -> String:
	return str(DB.data.encounter(DB.floor_def(1).quarter_boss).enemies[0])


static func _safe_room() -> String:
	return str((DB.floor_def(1).layout.get("safe_rooms", [{}]) as Array)[0].get("id", ""))


# --- block K ------------------------------------------------------------------------------------------------------

func test_block_k_tags_ids_and_coverage() -> void:
	var data: GameData = DB.data
	var lines: Array = _lines()
	assert_true(lines.size() >= 220, "block K ≈ 230 lines (%d)" % lines.size())
	var ids: Dictionary = {}
	var count: Dictionary = {}
	for l: Variant in lines:
		var d: Dictionary = l
		var id: String = str(d["id"])
		assert_false(ids.has(id), "unique id " + id)
		ids[id] = true
		var tag: String = str(d["tag"])
		count[tag] = int(count.get(tag, 0)) + 1
		var family: String = tag.get_slice(":", 0)
		assert_true(FAMILIES.has(family), "known family: " + tag)
		var suffix: String = tag.substr(family.length() + 1) if tag.contains(":") else ""
		var kind: String = str(FAMILIES.get(family, ""))
		if suffix == "":
			continue
		match kind:
			"origin":
				assert_false(data.origin(suffix).is_empty(), tag)
			"origin|custom":
				assert_true(suffix == "custom" or not data.origin(suffix).is_empty(), tag)
			"hobby":
				assert_false(data.hobby(suffix).is_empty(), tag)
			"greeting":
				assert_false(data.persona_entry("greetings", suffix).is_empty(), tag)
			"gag":
				var parts: PackedStringArray = suffix.split(":")
				assert_eq(parts.size(), 2, tag)
				assert_false(data.persona_entry("gags", parts[0]).is_empty(), tag)
				assert_true(["1", "2", "3"].has(parts[1]), tag)
			"class":
				assert_true(data.has_id("classes", suffix), tag)
			_:
				assert_true(kind.split("|").has(suffix), tag)
	for t: String in HOOK_TAGS:
		assert_true(int(count.get(t, 0)) >= 3, "≥ 3 general lines: %s (%d)" % [t, int(count.get(t, 0))])
	for o: Dictionary in data.all_origins():
		var id: String = str(o["id"])
		assert_true(int(count.get("persona_intro:" + id, 0)) >= 2, "≥ 2 intro variants: " + id)
		assert_true(int(count.get("persona_card:" + id, 0)) >= 1, "a card line: " + id)
		assert_eq((o.get("rivals", []) as Array).size(), 2, "2 rivals: " + id)
		for r: Variant in (o.get("rivals", []) as Array):
			assert_false(data.persona_entry("rivals", str(r)).is_empty(), str(r))
		if str(o.get("spec_hint", "")) != "":
			assert_true(int(count.get("persona_spec_hint:" + str(o["spec_hint"]), 0)) >= 1, "Recall tip line: " + id)
	assert_true(int(count.get("persona_intro:custom", 0)) >= 2, "the free-text intro")
	for g: Dictionary in data.persona_list("gags"):
		for n: int in [1, 2, 3]:
			assert_true(int(count.get("persona_gag:%s:%d" % [g["id"], n], 0)) >= 1, "gag part %d: %s" % [n, g["id"]])
	for g: Dictionary in data.persona_list("greetings"):
		assert_true(int(count.get("persona_beat_greeting:" + str(g["id"]), 0)) >= 1, "greeting " + str(g["id"]))
	for b: String in ["rival:intro", "rival:result", "rival:taunt", "sponsor:intro", "sponsor:thanks"]:
		assert_true(int(count.get("persona_beat_" + b, 0)) >= 2, "beat " + b)


func test_placeholders_and_the_length_rule() -> void:
	var allowed: PackedStringArray = ["name", "cand", "job", "hobby", "club", "trait", "rival", "brand"]
	for l: Variant in _lines():
		var d: Dictionary = l
		var text: String = str(d["text"])
		var tag: String = str(d["tag"])
		var ok: PackedStringArray = allowed.duplicate()
		if tag == "persona_intro:custom":
			ok.append("job_text")
		assert_true(PersonaText.only_placeholders(text, ok), "only the persona placeholders: %s %s" % [d["id"], text])
		if tag == "persona_intro:custom":
			assert_has(text, "„{job_text}“", "the free text only quoted: " + str(d["id"]))
		assert_true(PersonaText.effective_length(text) <= PersonaText.LINE_MAX,
			"≤ 110 with the longest values: %s (%d)" % [d["id"], PersonaText.effective_length(text)])
		assert_true(text.format(PersonaText.probe_ctx()).length() <= PersonaText.LINE_MAX, str(d["id"]))
	for f: String in ["mod_lines.json"]:
		var raw: Dictionary = JsonUtil.read_file("res://data/" + f)
		for e: Variant in (raw["entries"] as Array):
			if not str((e as Dictionary)["tag"]).begins_with("persona_intro:custom"):
				assert_false(str((e as Dictionary)["text"]).contains("{job_text}"),
					"{job_text} only in persona_intro:custom: " + str((e as Dictionary)["id"]))


func test_word_lists_foot_words_and_the_counts_voice() -> void:
	var probe: Dictionary = PersonaText.probe_ctx()
	for l: Variant in _lines():
		var d: Dictionary = l
		var text: String = str(d["text"])
		var voice: String = str(d.get("voice", "mod"))
		var filled: String = text.format(probe)
		var why: String = ModLineFilter.check(filled, {}, voice)
		assert_false(why.begins_with("blocked_"), "word lists (%s): %s %s" % [why, d["id"], text])
		var low: String = text.to_lower().replace("fußnote", "")
		for w: String in FOOT:
			assert_false(low.contains(w), "foot word '%s': %s" % [w, d["id"]])
		assert_false(low.contains("von beruf"), "never \"von Beruf\": " + str(d["id"]))
		assert_true(["mod", "mopsula"].has(voice), str(d["id"]))
		if voice == "mopsula" or str(d["tag"]).ends_with(":mopsula"):
			assert_false(PersonaText.royal_plural(filled), "no royal plural for the Count: " + str(d["id"]))
			for w: String in CROWN:
				assert_false(text.to_lower().contains(w), "no crown motif for the Count: " + str(d["id"]))
		# CR-23: the hook lines never name the canon candidate (the candidate may be anyone)
		if not str(d["tag"]).begins_with("persona_casting") and not str(d["tag"]).begins_with("persona_card"):
			assert_false(text.contains("Kai"), "no \"Kai\" in a hook line: " + str(d["id"]))
			assert_false(text.contains("Tierpfleger"), "no \"Tierpfleger\" in a hook line: " + str(d["id"]))


func test_club_job_and_trait_grammar() -> void:
	var data: GameData = DB.data
	var p: PersonaProfile = _jana()
	assert_eq(PersonaText.club(p, data), "Ihr Kochkurs", "{club} with the possessive (m)")
	p.hobby = "hob_music"
	assert_eq(PersonaText.club(p, data), "Ihre Band", "(f)")
	p.hobby = "hob_animals"
	assert_eq(PersonaText.club(p, data), "Ihr Tierheim-Team", "(n)")
	for h: Dictionary in data.persona_list("hobbies"):
		var c: Dictionary = h.get("club", {})
		assert_true(["m", "f", "n"].has(str(c.get("g", ""))), "club genus: " + str(h["id"]))
		assert_false(str(c.get("text", "")).begins_with("Ihr"), "the possessive comes from the code: " + str(h["id"]))
	var re: RegEx = RegEx.create_from_string(CLUB_PLURAL)
	for l: Variant in _lines():
		var text: String = str((l as Dictionary)["text"])
		assert_null(re.search(text), "{club} is singular: " + text)
		assert_false(text.contains("ein {job}") or text.contains("eine {job}") or text.contains("der {job}")
			or text.contains("die {job}"), "{job} never with an article: " + text)
	for o: Dictionary in data.all_origins():
		for f: String in PersonaProfile.FORMS:
			var q: PersonaProfile = PersonaProfile.canon(data)
			q.form = f
			q.origin = str(o["id"])
			q.occupation = ""
			assert_ne(PersonaText.job(q, data), "", "{job} %s %s" % [o["id"], f])
			assert_false(PersonaText.job(q, data).to_lower().contains("beruf"), str(o["id"]))


func test_scn_mop_4_with_every_form() -> void:
	var fx: Dictionary = JsonUtil.read_file(FORMS_FIXTURE)
	var scene: SceneDef = DB.data.scene_def(str(fx["scene"]))
	assert_not_null(scene)
	var raw: String = str((scene.lines[int(fx["line"])] as Dictionary)["text"])
	assert_has(raw, "{job}", "the scene follows the persona (CR-21)")
	assert_false(raw.contains("Tierpfleger"))
	for c: Variant in (fx["cases"] as Array):
		var cd: Dictionary = c
		var p: PersonaProfile = PersonaProfile.canon(DB.data)
		for k: Variant in (cd["persona"] as Dictionary).keys():
			p.set(str(k), (cd["persona"] as Dictionary)[k])
		Game.persona = p
		assert_eq(UiUtil.format_line(raw), str(cd["text"]), str(cd["persona"]))
	# every Vorleben × job × form: a predicative {job} without leftovers
	for o: Dictionary in DB.data.all_origins():
		var jobs: Array = [""]
		for j: Variant in (o.get("jobs", []) as Array):
			jobs.append(str((j as Dictionary)["id"]))
		for occ: Variant in jobs:
			for f: String in PersonaProfile.FORMS:
				var p: PersonaProfile = PersonaProfile.canon(DB.data)
				p.origin = str(o["id"])
				p.occupation = str(occ)
				p.form = f
				Game.persona = p
				var line: String = UiUtil.format_line(raw)
				assert_true(line.begins_with("Und du bist ") and not line.contains("{") and not line.contains(" ."),
					line)
	Game.persona = null


# --- broadcast plans ----------------------------------------------------------------------------------------------

func test_three_plans_from_the_seed_one_line_per_hook() -> void:
	var data: GameData = DB.data
	var plans: Array = data.persona_plans()
	assert_eq(plans.size(), 3, "three broadcast plans")
	var seen: Dictionary = {}
	for seed: int in range(1, 121):
		var id: String = PersonaBeats.plan_for(data, seed)
		assert_eq(id, PersonaBeats.plan_for(data, seed), "deterministic")
		seen[id] = true
	assert_eq(seen.size(), 3, "every plan is drawn: %s" % str(seen.keys()))
	var personas: Array[PersonaProfile] = Matrix.sample_personas(data)
	var ann: ModAnnouncer = ModAnnouncer.new(data, make_rng(1))
	var missing: Dictionary = {}
	for plan: Variant in plans:
		var pid: String = str((plan as Dictionary)["id"])
		for floor_index: int in [1, 2, 3, 4]:
			for hook: StringName in HOOKS:
				for n: int in [0, 1, 2, 3, 4]:
					for p: PersonaProfile in personas:
						var tags: PackedStringArray = PersonaBeats.tags_for(data, p, pid, floor_index, hook, n)
						assert_true(tags.size() <= (2 if hook == &"intro" else 1),
							"%s F%d %s #%d: %s" % [pid, floor_index, hook, n, str(tags)])
						for t: String in tags:
							if not ann.has_lines(t):
								missing[t] = true
	assert_eq(missing.keys(), [], "every planned tag has lines")
	# floor 1 of every plan: the card and one beat in the intro, a line for the first chest
	for plan: Variant in plans:
		var pid: String = str((plan as Dictionary)["id"])
		assert_eq(PersonaBeats.tags_for(data, _jana(), pid, 1, &"intro", 1).size(), 2, pid + ": the intro")
		assert_eq(PersonaBeats.tag_for(data, _jana(), pid, 1, &"intro", 1), "persona_intro:org_care")


func test_persona_lines_are_always_said_without_cooldown() -> void:
	Game.new_game(0, "Jana", SEED, &"prime", "kai", _jana())
	_said.clear()
	assert_ne(Show.say("boss_defeated"), "", "a priority-4 line")
	assert_ne(Show.say("persona_boss_won"), "", "persona_* are always said (no priority window)")
	assert_ne(Show.say("persona_boss_won"), "", "and have no key cooldown")
	assert_true(ModAnnouncer.always_said("persona_beat_rival:intro"))
	assert_eq(_persona_said(), PackedStringArray(["persona_boss_won", "persona_boss_won"]))


# --- never in a battle (08 §4.3 R6) ---------------------------------------------------------------------------------

func test_no_persona_line_in_a_ctb_battle() -> void:
	var p: PersonaProfile = _jana()
	p.ai = {"lines": [{"hook": "safe_room", "voice": "mod", "text": "Eine KI-Zeile für {name}."}]}
	Game.new_game(0, p.name, SEED, &"prime", "kai", p)
	var hooks: RefCounted = Show.persona_hooks()
	Game.enter_safe_room(_safe_room())
	var waiting: PackedStringArray = hooks.call("pending_tags")
	assert_eq(waiting.size(), 1, "H4 waits for safe_room_enter")
	Game.leave_safe_room()
	_said.clear()
	var setup: BattleSetup = Game.make_battle_setup(DB.floor_def(1).timer_start_after,
		BattleSetup.Advantage.PREEMPTIVE, "")
	assert_true(Game.in_battle)
	Events.battle_started.emit(setup.encounter_id, setup.is_boss)
	assert_eq((hooks.call("pending_tags") as PackedStringArray).size(), 0, "a waiting line expires at the battle start")
	Show.say("safe_room_enter")
	Game.state.floor_run.opened_chests.append("chest_test")
	hooks.call("on_chest", "chest_test")
	hooks.call("on_floor_end", 1)
	Game.state.floor_run.quarter_boss_defeated = true
	hooks.call("on_boss_won", _quarter_boss())
	Events.explore_tick.emit({})
	assert_eq((hooks.call("extra_lines", "persona_safe_room") as Array).size(), 0, "no AI line in a battle")
	assert_eq(_persona_said(), PackedStringArray(), "nothing persona_* during the battle")
	assert_eq((hooks.call("pending_tags") as PackedStringArray).size(), 1, "H3 waits for the battle end")
	Game.in_battle = false
	Events.explore_tick.emit({})
	assert_eq(_persona_said().size(), 1, "the boss line comes in the next exploration second")
	assert_eq((hooks.call("extra_lines", "persona_safe_room") as Array).size(), 1, "AI lines outside the battle")
	assert_eq((hooks.call("extra_lines", "persona_safe_room") as Array).size(), 0, "each AI line once per floor")


func test_no_persona_line_in_a_realtime_battle() -> void:
	Game.new_game(0, "Jana", SEED, &"prime", "kai", _jana())
	var hooks: RefCounted = Show.persona_hooks()
	Game.enter_safe_room(_safe_room())
	Game.leave_safe_room()
	assert_eq((hooks.call("pending_tags") as PackedStringArray).size(), 1)
	_said.clear()
	var rt_data: GameData = FakeRtSim.load_data()
	var sim: FakeRtSim = FakeRtSim.load_stream("boss_phases", rt_data)
	assert_not_null(sim, "the real-time fixture stream")
	Game.combat = sim                                  # a real-time combat runs (07: in the exploration world)
	Game.in_battle = true
	Events.battle_started.emit("enc_rt_fixture", true)
	assert_eq((hooks.call("pending_tags") as PackedStringArray).size(), 0, "the waiting line expired")
	sim.start()
	var guard: int = 0
	while not sim.is_finished() and guard < 2000:
		guard += 1
		sim.step()
		if guard % 30 == 0:                            # the world keeps ticking during a real-time combat
			Events.explore_tick.emit({})
			Show.say("safe_room_enter")
			hooks.call("on_floor_end", 1)
	assert_true(sim.is_finished(), "the stream played to its end")
	Game.state.floor_run.quarter_boss_defeated = true
	hooks.call("on_boss_won", _quarter_boss())
	Events.explore_tick.emit({})
	assert_eq(_persona_said(), PackedStringArray(), "no persona line during the real-time combat")
	Game.combat = null
	Game.in_battle = false
	Events.explore_tick.emit({})
	assert_eq(_persona_said().size(), 1, "after the combat: the boss line")


func test_hooks_follow_the_plan() -> void:
	var p: PersonaProfile = _jana()
	Game.new_game(0, p.name, SEED, &"prime", "kai", p)
	var plan: String = PersonaBeats.plan_for(DB.data, SEED)
	var hooks: RefCounted = Show.persona_hooks()
	assert_eq(str(hooks.call("plan")), plan)
	_said.clear()
	Game.state.floor_run.opened_chests.append("chest_test")
	Events.chest_opened.emit("chest_test", [])
	var want: String = PersonaBeats.tag_for(DB.data, p, plan, 1, &"first_chest", 1)
	if want != "":
		assert_eq(_persona_said().size(), 1, "H2: one line for the first chest")
		assert_true(_persona_said()[0] == want or want.begins_with(_persona_said()[0]), str(_persona_said()))
	Game.state.floor_run.opened_chests.append("chest_test_2")
	Events.chest_opened.emit("chest_test_2", [])
	assert_true(_persona_said().size() <= 1, "only the first chest of the floor")
	_said.clear()
	Game.enter_safe_room(_safe_room())
	assert_eq(_persona_said(), PackedStringArray(), "H4 waits for the safe room's own line")
	Show.say("safe_room_enter")
	assert_eq(_said.size(), 2, "safe_room_enter, then the persona line: " + str(_said))
	assert_true(_said[1].begins_with("persona_"), str(_said))
	Game.leave_safe_room()
	# no persona → no persona line (tests, autoplay, event runs)
	Game.new_game(0, "Kai", SEED)
	_said.clear()
	Game.state.floor_run.opened_chests.append("chest_test")
	Events.chest_opened.emit("chest_test", [])
	Game.enter_safe_room(_safe_room())
	Show.say("safe_room_enter")
	assert_eq(_persona_said(), PackedStringArray(), "without a persona nothing")


func test_review_matrix_builds() -> void:
	var rows: Array[PackedStringArray] = Matrix.build(DB.data)
	assert_true(rows.size() > 1000, "every line × Vorleben × form (%d rows)" % rows.size())
	var ids: Dictionary = {}
	for r: PackedStringArray in rows:
		assert_eq(r.size(), Matrix.HEADER.size())
		ids[r[0]] = true
		assert_false(r[7].contains("{") and not r[7].contains("{name}"), "rendered: " + r[7])
	assert_eq(ids.size(), _lines().size(), "every persona line appears")
	var csv: String = Matrix.to_csv(rows)
	assert_true(csv.begins_with(",".join(Matrix.HEADER)), "CSV header")
	var path: String = "user://test_08_persona_matrix.csv"
	assert_eq(Matrix.write(path, DB.data), OK)
	assert_true(FileAccess.get_file_as_string(path).length() > 10000)
	DirAccess.remove_absolute(path)
