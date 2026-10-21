extends TestCase
## R5b part 2a, text pass (07 E33: new games fight in real time): what a real-time player reads names no CTB turns —
## skill details and the touch tooltip give real-time costs, cooldowns and status durations in seconds (since the data
## bake of part 2b the descriptions themselves speak real time, 07 E38), the SHOW row its party cooldown; the talent
## cards and the M.O.D. lines a real-time combat says are worded for both modes.

const CombatView := preload("res://scenes/combat/ui/combat_view.gd")
const CombatTouch := preload("res://scenes/combat/ui/combat_touch.gd")
const TalentText := preload("res://scenes/ui/talent_text.gd")
## CTB turn words ("Zug" alone stays: the train of Gleis 9).
const TURN_WORDS: PackedStringArray = [" Züge", " Zügen", " Runde", "dran ist", "Befehl", "Zugfolge", "1. Zug"]


func _turn_word(text: String) -> String:
	for w: String in TURN_WORDS:
		if text.contains(w):
			return w
	return ""


func test_real_time_skill_text_counts_seconds() -> void:
	var taunt: SkillDef = DB.skill("skl_kai_taunt")
	assert_eq(taunt.desc, "Sie ziehen alle Blicke auf sich.", "the data speak real time (baked in part 2b, E38)")
	assert_eq(CombatView.skill_text(taunt),
		"Sie ziehen alle Blicke auf sich.\nWirkung: Provoziert (alle Gegner) 4 s · Gepanzert (selbst) 6 s")
	assert_eq(CombatView.skill_text(DB.skill("skl_kai_leash_trip")),
		"Bremst einen Gegner aus. Meistens.\nWirkung: Verlangsamt 4 s (90 %)", "a chance below 100 %")
	assert_eq(CombatView.skill_text(DB.skill("skl_kai_heavy_swing")), DB.skill("skl_kai_heavy_swing").desc,
		"without statuses: the description as it is")
	assert_eq([CombatView.seconds_text(1500), CombatView.seconds_text(10000)], ["1,5 s", "10 s"])
	for sid: String in ["skl_kai_taunt", "skl_mop_expert_opinion", "skl_kai_cable_whip", "skl_mop_mass_lick"]:
		assert_eq(_turn_word(CombatView.skill_text(DB.skill(sid))), "", sid)


func test_touch_tooltip_has_no_turns() -> void:
	var s: Dictionary = {"id": "skl_kai_taunt", "name": "Hier spielt die Musik!", "mp": 2, "show": false,
		"is_item": false}
	var text: String = CombatTouch.tooltip_text(s)
	assert_true(text.begins_with("Hier spielt die Musik! · 2 MP · Abklingzeit 15 s\n"), text)
	assert_has(text, "Provoziert (alle Gegner) 4 s")
	assert_eq(_turn_word(text), "", text)


func test_skills_page_details() -> void:
	Game.new_game(0, "Kai", 11)
	assert_true(Game.is_realtime(), "07 E33")
	var page: Control = (load("res://scenes/ui/skills_menu.gd") as GDScript).new() as Control
	page.set("member_id", "kai")
	var holder: Control = Control.new()
	add_to_tree(holder)
	holder.add_child(page)
	await wait_frames(2)
	var d: Dictionary = page.get("_detail")
	page.call("_rt_show", {"skill": "skl_kai_taunt", "learned": true, "kind": "", "slot": 2, "level": 2})
	var sub: String = (d["sub"] as Label).text
	var body: String = (d["body"] as Label).text
	assert_eq(sub, "Stärkung  ·  Selbst  ·  2 MP  ·  Abklingzeit 15 s", "real-time costs, no CTB rank")
	assert_has(body, "Wirkung: Provoziert (alle Gegner) 4 s · Gepanzert (selbst) 6 s")
	assert_eq(_turn_word(body), "", body)
	page.call("_rt_show", {"skill": "skl_stunt_kai_suplex", "learned": true, "kind": "", "slot": 5, "level": 1})
	body = (d["body"] as Label).text
	assert_has(body, "SHOW-Abklingzeit 30 s (ganze Party)")
	assert_eq(_turn_word(body), "", body)
	page.call("_rt_show", {"skill": "skl_mop_holy_lick", "learned": true, "kind": "", "slot": 2, "level": 1})
	assert_has((d["sub"] as Label).text, "Zauberzeit 1,5 s", "a cast time")
	page.call("_show", {"skill": "skl_kai_taunt", "learned": true})
	assert_false((d["sub"] as Label).text.contains("Rang"), "no CTB rank any more (R5b part 2b)")
	assert_has((d["body"] as Label).text, "Sie ziehen alle Blicke auf sich.", "the real-time description")


func test_texts_a_real_time_run_shows_name_no_turns() -> void:
	for id: String in ["tal_kai_erster_eindruck", "tal_mop_taktgefuehl"]:
		var t: TalentDef = DB.talent(id)
		assert_eq(_turn_word(" " + t.desc + " "), "", id)
		assert_eq(_turn_word(" " + TalentText.effects_line(t, t.for_members[0]) + " "), "", id + " effect")
	for tag: String in ["first_fight", "tutorial_battle", "tutorial_explore", "tutorial_sneak"]:
		for l: ModLineDef in DB.data.mod_lines(tag):
			assert_eq(_turn_word(" " + l.text + " "), "", l.id)
	var raw: Variant = JsonUtil.read_file("res://data/mod_lines.json")
	var n: int = 0
	for e: Variant in ((raw as Dictionary).get("entries", []) as Array) if raw is Dictionary else []:
		var line: Dictionary = (e as Dictionary) if e is Dictionary else {}
		if str(line.get("tag", "")).begins_with("rt_"):
			n += 1
			assert_eq(_turn_word(" " + str(line.get("text", "")) + " "), "", str(line.get("id", "")))
	assert_gt(n, 20, "the real-time block of mod_lines.json")
