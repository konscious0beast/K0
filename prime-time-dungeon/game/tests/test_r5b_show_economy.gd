extends TestCase
## R5b part 2a, decision E32 (07 §0.1, §9.1, §12.6 Nr. 3): the show economy of the real-time combat in the GDD §13 bands
## — auto-attack hits are no actions and bring no crit / weakness hype (the crit still counts as a stat and the M.O.D.
## line tag stays), combos and SHOW results count less (RT_COMBO, RT_SHOW_*), heals are no repetition, after a regular
## real-time combat with a system gift the next RT_GIFT_PAUSE regular ones bring none (bosses and viewer gifts are never
## paced), the followers of a won real-time combat are scaled by RT_FOLLOWER_PM. Every shared rule (thresholds
## 70/85/100, gift caps, viewer and follower formulas) stays as it was; since R5b part 2b every combat is a real-time
## one (the CTB profile left with the CTB battle, so a plain BattleSetup plays these rules too). The change alters what
## Game.replay_log computes for a real-time run, so RunSim.SIM_VERSION went 2 → 3: logs and board entries recorded
## before are an "ältere Version", never a mismatch.

const RtLive := preload("res://tests/fixtures/rt_live/rt_live.gd")
const EventInfo := preload("res://scenes/ui/event_info.gd")
const K := BattleCommand.Kind


func before_each() -> void:
	RtLive.swap_data()


func after_each() -> void:
	if Game.combat != null:
		Game.end_combat()
	Show.abort_battle()
	Game.state = null
	Game.run_log = null
	Game.sim = null
	Game.in_battle = false
	RtLive.restore_data()


static func _ev(t: ActionEvent.Type, fields: Dictionary = {}) -> ActionEvent:
	var e: ActionEvent = ActionEvent.make(t)
	for k: String in fields.keys():
		e.set(k, fields[k])
	return e


static func _rt_rules() -> ShowRules:
	return ShowRules.new(RtKit.data(), RtKit.setup(RtKit.state(6), RtKit.canned_encounter()))


func test_the_values_are_pinned() -> void:
	assert_eq([ShowRules.RT_CRIT, ShowRules.RT_WEAK, ShowRules.RT_COMBO, ShowRules.RT_SHOW_SUCCESS,
		ShowRules.RT_SHOW_FAIL, ShowRules.RT_GIFT_PAUSE, ShowRules.RT_FOLLOWER_PM], [1.0, 1.0, 1.0, 6.0, 2.0, 4, 600],
		"E32 (07 §9.1)")
	assert_eq([ShowRules.RT_VARIETY, ShowRules.RT_REPEAT, ShowRules.RT_INTERRUPT, ShowRules.RT_DODGE,
		ShowRules.RT_DODGE_CLOSE, ShowRules.RT_TRAIN_KILL, ShowRules.RT_PERFECT_PHASE, ShowRules.RT_ENRAGE,
		ShowRules.RT_BORING, ShowRules.RT_DRAG], [1.0, -3.0, 3.0, 2.0, 4.0, 4.0, 8.0, 5.0, -2.0, -3.0],
		"the other real-time values of R5a are unchanged")
	assert_eq([ShowRules.HYPE_KILL_ATTACK, ShowRules.HYPE_KILL_SKILL, ShowRules.HYPE_KILL_STUNT,
		ShowRules.HYPE_OVERKILL, ShowRules.HYPE_KILL_STREAK], [1.0, 2.0, 4.0, 3.0, 5.0], "the shared kill values")
	assert_eq([SponsorSystem.THRESHOLDS, SponsorSystem.MAX_GIFTS_PER_BATTLE, SponsorSystem.MAX_GIFTS_PER_BOSS_BATTLE],
		[PackedInt32Array([70, 85, 100]), 1, 2], "sponsor thresholds and gift caps are shared and unchanged")
	assert_eq([ShowModel.VIEWER_PER_FOLLOWER, ShowModel.FOLLOWER_CONV_BASE, ShowModel.FOLLOWER_CONV_HYPE,
		ShowModel.FOLLOWER_BOSS_MULT], [0.5, 0.007, 0.014, 2.0], "viewer and follower formulas (GDD §7.2 / §7.6)")


func test_auto_attack_hits_make_no_hype() -> void:
	var r: ShowRules = _rt_rules()
	var auto_hit: ShowDelta = r.feed(_ev(ActionEvent.Type.DAMAGE, {"actor_id": "p0", "target_id": "e0", "crit": true,
		"weak": true, "skill_id": "skl_attack_kai", "amount": 9}))
	assert_eq(auto_hit.hype, 0.0, "an auto-attack is no action (07 §9.1)")
	assert_eq(auto_hit.stats, {"crits_total": 1}, "the crit still counts (ach_crit_3, 07 §9.4)")
	assert_eq(auto_hit.reasons, [&"crit", &"weakness"], "the M.O.D. line / chat tags stay (presentation)")
	r.feed(_ev(ActionEvent.Type.ACTION_START, {"actor_id": "p0", "skill_id": "skl_kai_heavy_swing",
		"command": K.SKILL}))
	var ability: ShowDelta = r.feed(_ev(ActionEvent.Type.DAMAGE, {"actor_id": "p0", "target_id": "e0", "crit": true,
		"weak": true, "skill_id": "skl_kai_heavy_swing", "amount": 20}))
	assert_eq(ability.hype, ShowRules.RT_CRIT + ShowRules.RT_WEAK, "an ability hit: crit and weakness")
	var auto_in_action: ShowDelta = r.feed(_ev(ActionEvent.Type.DAMAGE, {"actor_id": "p0", "target_id": "e0",
		"crit": true, "skill_id": "skl_attack_kai", "amount": 9}))
	assert_eq(auto_in_action.hype, 0.0, "an auto-attack hit during an open action is still no action")
	var ai: ShowRules = _rt_rules()
	ai.feed(_ev(ActionEvent.Type.ACTION_START, {"actor_id": "p1", "skill_id": "skl_mop_noble_flame", "by_ai": true,
		"command": K.SKILL}))
	assert_eq(ai.feed(_ev(ActionEvent.Type.DAMAGE, {"actor_id": "p1", "target_id": "e0", "crit": true,
		"skill_id": "skl_mop_noble_flame", "amount": 12})).hype, ShowRules.RT_CRIT,
		"the AI partner's ability crit counts for the party")


func test_quiet_auto_attacks_let_boredom_run() -> void:
	var r: ShowRules = _rt_rules()
	r.feed(_ev(ActionEvent.Type.BATTLE_START))
	var per_sec: Array = []
	for s in range(1, 8):
		r.feed(_ev(ActionEvent.Type.DAMAGE, {"actor_id": "p0", "target_id": "e0", "crit": true,
			"skill_id": "skl_attack_kai", "amount": 9}))
		per_sec.append(r.feed(_ev(ActionEvent.Type.SECOND, {"value": s})).hype)
	assert_eq(per_sec, [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, ShowRules.RT_BORING],
		"auto-attack crits are no positive event: 6 quiet seconds after the start bonus")


func test_combo_and_show_values() -> void:
	var r: ShowRules = _rt_rules()
	assert_eq(r.feed(_ev(ActionEvent.Type.COMBO, {"actor_id": "p1", "target_id": "e0"})).hype, ShowRules.RT_COMBO)
	assert_eq(r.feed(_ev(ActionEvent.Type.STUNT_RESULT, {"actor_id": "p0", "success": true,
		"skill_id": "skl_stunt_kai_suplex"})).hype, ShowRules.RT_SHOW_SUCCESS)
	assert_eq(r.feed(_ev(ActionEvent.Type.STUNT_RESULT, {"actor_id": "p0", "success": false,
		"skill_id": "skl_stunt_kai_suplex"})).hype, ShowRules.RT_SHOW_FAIL)
	var plain: ShowRules = ShowRules.new(RtKit.data(), BattleSetup.new())
	assert_eq(plain.feed(_ev(ActionEvent.Type.COMBO, {"actor_id": "p1", "target_id": "e0"})).hype, ShowRules.RT_COMBO,
		"a plain setup plays the real-time values too (R5b part 2b)")
	assert_eq(plain.feed(_ev(ActionEvent.Type.DAMAGE, {"actor_id": "p0", "target_id": "e0", "crit": true,
		"skill_id": "skl_attack_kai", "amount": 9})).hype, 0.0, "an auto-attack is no action")


func test_heals_are_no_repetition() -> void:
	var r: ShowRules = _rt_rules()
	var heal: Array = []
	var jab: Array = []
	for i in 5:
		heal.append(r.feed(_ev(ActionEvent.Type.ACTION_START, {"actor_id": "p0", "skill_id": "skl_kai_first_aid",
			"command": K.SKILL})).hype)
	for i in 4:
		jab.append(r.feed(_ev(ActionEvent.Type.ACTION_START, {"actor_id": "p0", "skill_id": "skl_kai_leash_trip",
			"command": K.SKILL})).hype)
	assert_eq(heal, [ShowRules.RT_VARIETY, 0.0, 0.0, 0.0, 0.0], "healing four times in a row is work, no repetition")
	assert_eq(jab, [ShowRules.RT_VARIETY, 0.0, 0.0, ShowRules.RT_REPEAT], "other skills: the 4th time in a row")


## A regular real-time combat of the running run (RtLive.adopt), in battle like Game.make_rt_setup; `hype` before the
## crossing of 70 → the system gift of the boundary ({} = none).
func _regular_gift(hype: float, boss: bool = false) -> Dictionary:
	var cmd: Dictionary = RtKit.encounter("enc_rt_test_boss", [["g_boss", "enc_rt_test_boss", [0, -200, 128]]]) \
		if boss else RtKit.dummy_cmd()
	Game.state.show.hype = hype
	Show.begin_battle(RtKit.setup(Game.state, cmd))
	Game.in_battle = true
	Show.add_hype(75.0 - hype)
	var g: Dictionary = Show._take_pending([], 3)
	Show.abort_battle()
	Game.in_battle = false
	return g


func _pause() -> int:
	return int(Game.state.floor_run.stats.get(Show.RT_GIFT_PAUSE_KEY, 0))


func test_sponsors_pause_after_a_regular_real_time_gift() -> void:
	RtLive.adopt(RtLive.state(6, 40.0))
	assert_eq(_pause(), 0, "no pause on a fresh floor")
	assert_eq(str(_regular_gift(60.0).get("source", "")), "system", "crossing 70: the system gift")
	assert_eq(_pause(), ShowRules.RT_GIFT_PAUSE, "the sponsors' pause starts")
	var floor_dict: Dictionary = Game.state.floor_run.to_dict()
	assert_eq(int(FloorRun.from_dict(floor_dict).stats[Show.RT_GIFT_PAUSE_KEY]), ShowRules.RT_GIFT_PAUSE,
		"saved with the floor run")
	assert_eq(str(_regular_gift(60.0, true).get("source", "")), "system", "a boss combat is never paused")
	assert_eq(_pause(), ShowRules.RT_GIFT_PAUSE, "and does not count")
	for i in ShowRules.RT_GIFT_PAUSE:
		assert_eq(_regular_gift(60.0), {}, "regular combat %d of the pause: no system gift" % (i + 1))
		assert_eq(_pause(), ShowRules.RT_GIFT_PAUSE - 1 - i)
	assert_false(Game.state.floor_run.stats.has(Show.RT_GIFT_PAUSE_KEY), "the key is gone after the pause")
	assert_eq(str(_regular_gift(60.0).get("source", "")), "system", "the next regular combat may get one again")


func test_the_pause_keeps_viewer_gifts_and_the_top_reset() -> void:
	RtLive.adopt(RtLive.state(6, 40.0))
	_regular_gift(60.0)
	assert_true(Game.open_dev_sponsor_window(60, 3), "viewer gifts need an open Sponsor-Fenster")
	Game.state.show.hype = 90.0
	Show.begin_battle(RtKit.setup(Game.state, RtKit.dummy_cmd()))
	Game.in_battle = true
	var gift: Dictionary = Gift.make_dev("gold", "", 100)
	assert_eq(Show.receive_gift(gift)["apply"], "queued")
	assert_eq(str(Show._take_pending([], 4).get("gift_id", "")), str(gift["gift_id"]),
		"an external gift is never paced (05 §6.13: Sponsor-Fenster rules untouched)")
	Show.add_hype(15.0)
	assert_eq(Show.hype(), SponsorSystem.HYPE_AFTER_TOP, "crossing 100 without a gift slot: back to 80 (GDD §7.4)")
	Show.abort_battle()
	Game.in_battle = false


func test_followers_of_a_real_time_combat_are_scaled() -> void:
	Game.state = RtKit.state(6)
	var pm: int = Game.state.follower_pm(DB.data)
	Show.begin_battle(RtKit.setup(Game.state, RtKit.canned_encounter()))
	assert_eq(Show._battle_follower_pm(Game.state, {}, 1000), (pm * ShowRules.RT_FOLLOWER_PM + 500) / 1000,
		"real time: × RT_FOLLOWER_PM as the last step")
	var hearts: int = (pm * 1150 + 500) / 1000
	assert_eq(Show._battle_follower_pm(Game.state, {"follower_pm": 1150}, 1000),
		(hearts * ShowRules.RT_FOLLOWER_PM + 500) / 1000, "after the hearts' factor (06 §4.5)")
	Show.abort_battle()
	Show.begin_battle(BattleSetup.new())
	assert_eq(Show._battle_follower_pm(Game.state, {}, 1000), (pm * ShowRules.RT_FOLLOWER_PM + 500) / 1000,
		"every combat is a real-time one (R5b part 2b)")
	Show.abort_battle()
	var base: int = ShowModel.followers_for_battle_pm(4000, 60.0, false, pm)
	var scaled: int = ShowModel.followers_for_battle_pm(4000, 60.0, false, (pm * ShowRules.RT_FOLLOWER_PM + 500) / 1000)
	assert_true(scaled < base and scaled >= base * ShowRules.RT_FOLLOWER_PM / 1000 - 1, "%d of %d" % [scaled, base])


## Logs of version 2 (before E32) and 3 (before the HP bake of R5b part 2b, 07 §12.6) are an "ältere Version" in both
## verifiers, the leaderboard and the lobby — tagged, not replayed, never a mismatch.
func test_older_logs_are_an_older_version() -> void:
	assert_eq(RunSim.SIM_VERSION, 4, "07 E32: 2 → 3; R5b part 2b: 3 → 4")
	RtLive.adopt(RtLive.state(6, 30.0, {"itm_brutzel_burger": 2, "itm_energy_krawumm": 1, "itm_molotov": 1}))
	var r: Dictionary = RtLive.fight(RtKit.canned_encounter(), RtKit.canned_commands())
	assert_false(r.is_empty(), "a live real-time combat")
	var live: Dictionary = Game.replay_log(Game.run_log)
	assert_eq([live["errors"], live["mismatch_at"], live["version"]], [PackedStringArray(), -1, ""],
		"this kernel replays its own log")
	for v: int in [2, 3]:
		var raw: Dictionary = Game.run_log.to_dict()
		(raw["header"] as Dictionary)["sim_version"] = v
		var old: RunLog = RunLog.from_dict(raw)
		var g: Dictionary = Game.replay_log(old)
		assert_eq([g["version"], g["mismatch_at"], g["final_hash"]], [RunSim.OLD_VERSION, -1, ""],
			"a real-time log of version %d: tagged, not replayed, never a mismatch" % v)
		assert_has("; ".join(g["errors"]), "ältere Version")
		var c: Dictionary = RunSim.replay(RtKit.data(), old)
		assert_eq([c["version"], c["mismatch_at"]], [RunSim.OLD_VERSION, -1], "the core verifier alike")
		assert_eq(Leaderboard.version_status({"score": 9, "sim_version": v}), RunSim.OLD_VERSION)
		assert_eq(EventInfo.version_tag({"score": 9, "sim_version": v}), RunSim.OLD_VERSION_TAG, "the lobby's tag")
