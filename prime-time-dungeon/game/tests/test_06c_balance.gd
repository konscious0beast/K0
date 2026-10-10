extends TestCase
## 06-C balance bands (06 §4.10, GDD §13) with the real Show in the loop (test_m7_show_balance helpers): the
## Unterhosen-Liga makes the bosses harder but stays winnable — first-try loss rates with the sponsor gifts as they
## occur, 100 seeds each, the bot's boss loadout without armor / accessory (tier 1: Kai, tier 2: both); a whole Floor-1
## season in the Liga keeps the follower feedback damped (<= 2 000) and the lootboxes bounded; the reference player
## (no Liga, auto battles) wins at most the one bet of floor 1.

const M7 := preload("res://tests/test_m7_balance.gd")
const M7S := preload("res://tests/test_m7_show_balance.gd")
const BOSS_SEEDS: int = 100
## Maximum first-try loss rate per Liga tier (06 §4.10: tier 1 <= 40 % / 55 %, tier 2 <= 55 % / 70 %).
const MAX_LOSS: Dictionary = {
	1: {"enc_f1_boss_hausmeister": 0.40, "enc_f1_boss_rattenkoenigin": 0.55},
	2: {"enc_f1_boss_hausmeister": 0.55, "enc_f1_boss_rattenkoenigin": 0.70},
}
const SEASON_SEEDS: int = 8
const MAX_FOLLOWERS_LIGA: float = 2000.0
## GDD §13 lootbox band of the reference player (06 §4.5: 15–22 with the show bets) and the bound of a Duo-Liga
## season (+ the Mut-Paket and the "Ohne alles" chain).
const BAND_BOXES: Vector2 = Vector2(15, 22)
const MAX_BOXES_LIGA: float = 28.0

var _h: Object = null
var _prev_data: GameData = null


func before_each() -> void:
	_h = M7S.new()
	_h.set("_m7", M7.new())
	_prev_data = DB.data
	DB.data = real_data()


func after_each() -> void:
	Game.in_battle = false
	if Game.state != null:
		Show.end_battle(null)
	Game.state = null
	if _prev_data != null:
		DB.data = _prev_data
	_prev_data = null


func test_liga_boss_loss_rates_stay_winnable() -> void:
	for tier: int in [1, 2]:
		for enc_id: String in MAX_LOSS[tier]:
			var r: Dictionary = _boss_series(enc_id, tier)
			var label: String = "%s, Liga %d: %s" % [enc_id, tier, str(r)]
			print("[06c_balance] ", label)
			assert_true(float(r["loss_rate"]) <= float(MAX_LOSS[tier][enc_id]), "first-try loss rate — " + label)
			assert_gt(float(r["loss_rate"]), 0.0, "the Liga is harder: some attempts are lost — " + label)


func _boss_series(enc_id: String, tier: int) -> Dictionary:
	var p: Array = M7.PLAN[enc_id]
	var lost: int = 0
	var turns: int = 0
	for i in BOSS_SEEDS:
		Game.state = GameState.create_new(real_data(), 0, "Kai", SeedUtil.derive(4242, "m7_boss_state", i))
		M7S.strip_liga(Game.state, tier)
		Game.state.show.hype = M7S.BOSS_HYPE_START
		for a: AchievementDef in real_data().all_achievements():
			Game.state.show.achievements.append(a.id)
		var r: Dictionary = _h.call("show_battle", enc_id, int(p[0]), str(p[1]), str(p[2]),
			SeedUtil.derive(7331, "m7_boss", i), M7S.AUTO, true, BattleSetup.Advantage.NORMAL,
			M7S.BOSS_LOADOUT[enc_id], tier)
		Game.state = null
		if bool(r["win"]):
			turns += int(r["turns"])
		else:
			lost += 1
	return {"loss_rate": snappedf(float(lost) / float(BOSS_SEEDS), 0.01),
		"turns": snappedf(float(turns) / float(maxi(1, BOSS_SEEDS - lost)), 0.1)}


## Floor 1 as one show season (auto battles, human pace): the reference player and the two Liga tiers.
func test_liga_season_economy() -> void:
	var ref: Dictionary = _medians(0)
	print("[06c_balance] reference season: ", ref)
	assert_between(float(ref["boxes"]), BAND_BOXES.x, BAND_BOXES.y, "lootboxes of the reference player")
	assert_true(float(ref["bets_max"]) <= 1.0, "floor 1 has one bet: at most one won")
	for tier: int in [1, 2]:
		var m: Dictionary = _medians(tier)
		print("[06c_balance] Liga %d season: " % tier, m)
		assert_true(float(m["followers"]) <= MAX_FOLLOWERS_LIGA, "Liga %d: followers bounded (GDD §7.2) %s" % [tier,
			str(m)])
		assert_gt(float(m["followers"]), float(ref["followers"]), "Liga %d: the audience loves courage" % tier)
		assert_true(float(m["boxes"]) <= MAX_BOXES_LIGA, "Liga %d: lootboxes bounded %s" % [tier, str(m)])
		assert_gt(float(m["liga_battles"]), 10.0, "Liga %d: the battles counted in the Liga" % tier)
		if tier == 2:
			assert_gt(float(m["followers"]), float(_medians(1)["followers"]), "the Duo-Liga pays most (ultimate)")


func _medians(tier: int) -> Dictionary:
	var f: Array = []
	var b: Array = []
	var lb: Array = []
	var bets_max: int = 0
	for i in SEASON_SEEDS:
		var row: Dictionary = _season(SeedUtil.derive(4242, "m7_show_season", i), tier)
		f.append(int(row["followers"]))
		b.append(int(row["boxes"]))
		lb.append(int(row["liga_battles"]))
		bets_max = maxi(bets_max, int(row["bets_won"]))
	return {"followers": M7S.median(f), "boxes": M7S.median(b), "liga_battles": M7S.median(lb), "bets_max": bets_max}


func _season(seed: int, tier: int) -> Dictionary:
	return _h.call("run_season", seed, M7S.AUTO, M7S.PACE_HUMAN, PackedStringArray(), tier)
