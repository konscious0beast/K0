extends TestCase
## R5b part 1 (07 §9.4, §12.2 "Stand R5a" Nr. 6): ach_crit_3 and ach_weakness_5 measured in the real-time combat —
## a real-time fight has many more hits than a CTB battle (auto attacks, both units): with the bot `typical` 52–63 % of
## the regular fights land 3 crits and the tutorial alone ≈ 7 weakness hits, so both came in the first fights (CTB
## thorough: crit 3 never, weakness 5 after the Hausmeister). achievements.json condition_rt / desc_rt hold the
## real-time thresholds (15 crits: ≈ every second Hausmeister fight, every Königin; 10 weakness hits: about one regular
## fight in twenty, mostly d2), AchievementDef.expr_for / desc_for pick them in a real-time run; CTB stays as it was.


func _payload(crits: int, weak: int) -> Dictionary:
	return {"party_turns": 10, "min_party_hp": 50, "min_party_hp_pct": 0.5, "crits": crits, "weakness_hits": weak,
		"items_used": 0, "party_kos": 0, "damage_taken": 100, "is_boss": false, "boss_id": "",
		"encounter_type": "normal", "group_id": "f1_g1", "duration_sec": 20, "interrupts": 0, "dodges": 0,
		"telegraph_hits": 0, "train_kills": 0, "perfect_phases": 0}


func _won(realtime: bool, crits: int, weak: int) -> PackedStringArray:
	var d: GameData = real_data()
	var st: GameState = GameState.create_new(d, 0, "Kai", 1)
	var t: AchievementTracker = AchievementTracker.new(d, st.show, st.flags)
	t.realtime = realtime
	var got: PackedStringArray = t.evaluate("battle_won", _payload(crits, weak))
	var out: PackedStringArray = []
	for id: String in got:
		if id == "ach_crit_3" or id == "ach_weakness_5":
			out.append(id)
	return out


func test_the_real_time_thresholds() -> void:
	var d: GameData = real_data()
	var crit: AchievementDef = d.achievement("ach_crit_3")
	var weak: AchievementDef = d.achievement("ach_weakness_5")
	assert_eq([crit.condition, crit.condition_rt], ["e.crits >= 3", "e.crits >= 15"])
	assert_eq([weak.condition, weak.condition_rt], ["e.weakness_hits >= 5", "e.weakness_hits >= 10"])
	assert_eq(crit.desc_for(true), "Lande 15 kritische Treffer in einem Kampf.")
	assert_eq(crit.desc_for(false), crit.desc, "CTB keeps its text")
	assert_eq(weak.desc_for(true), "Triff 10× eine Schwachstelle in einem Kampf.")
	assert_eq(_won(false, 3, 5), PackedStringArray(["ach_crit_3", "ach_weakness_5"]), "CTB as before")
	assert_eq(_won(true, 14, 9), PackedStringArray(), "real time: below the thresholds")
	assert_eq(_won(true, 15, 10), PackedStringArray(["ach_crit_3", "ach_weakness_5"]))
	for a: AchievementDef in d.all_achievements():
		if a.condition_rt == "":
			assert_eq(a.expr_for(true), a.expr, a.id + ": one condition for both modes")
			assert_eq(a.desc_for(true), a.desc)
		else:
			assert_eq(a.expr_rt.error, "", a.id)
