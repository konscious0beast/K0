extends TestCase
## 07 §11.4 / §12.5 R4 test_r4_rt_balance — the CI balance gate of the real-time combat (< 60 s): the harness
## (tests/tools/rt_harness.gd: the real RtSim, RtBotPlayer `typical`, fixed seeds SeedUtil.derive(4242, "harness", n))
## against the bands of 07 §11.1 (rt_harness.BANDS), widened for the small samples as §11.4 says — regular encounters
## 5 seeds (Kai; duration ± 20 %, HP loss ± 5 points), each boss 10 seeds per hero (first-try loss roughly 0–60 %
## Hausmeister / 10–70 % Königin, duration ± 20 %), the show boss 5 seeds per hero (losses ≤ 20 %, duration 20–40 s
## ± 20 %). The narrow bands are the nightly job's (tools/rt_balance.sh --nightly, 200 seeds). Deterministic.

const Harness := preload("res://tests/tools/rt_harness.gd")

const WIDEN_PM: float = 0.2
const WIDEN_POINTS: float = 5.0
## boss → the CI band of the first-try loss rate (07 §11.4; floats, not Vector2: 0.1 must stay 0.1 for 1 of 10)
const BOSS_CI_LOSS: Dictionary = {
	"enc_f1_boss_hausmeister": [0.0, 0.6],
	"enc_f1_boss_rattenkoenigin": [0.1, 0.7],
}


static func _band(key: String, what: String) -> Vector2:
	var b: Array = (Harness.BANDS[key] as Dictionary)[what]
	return Vector2(float(b[0]), float(b[1]))


static func _widen(band: Vector2) -> Vector2:
	return Vector2(band.x * (1.0 - WIDEN_PM), band.y * (1.0 + WIDEN_PM))


func test_regular_encounters() -> void:
	var data: GameData = real_data()
	var medians: Array = []
	var sec: Vector2 = _widen(_band("regular", "sec"))
	var hp: Vector2 = _band("regular", "hp") + Vector2(-WIDEN_POINTS, WIDEN_POINTS)
	for enc: String in Harness.REGULAR:
		var s: Dictionary = Harness.series(data, enc, "kai", 0, 5)
		print("[BALANCE] " + Harness.line(s))
		var med: float = float((s["sec"] as Dictionary)["median"])
		medians.append(med)
		assert_eq(int(s["losses"]), 0, enc + ": no regular fight lost")
		assert_between(med, sec.x, sec.y, enc + ": duration median (07 §11.1 15–35 s ± 20 %)")
		assert_between(float((s["hp_loss"] as Dictionary)["median"]), hp.x, hp.y,
			enc + ": HP loss median without potions (20–35 % ± 5 points)")
	var m: float = float(Harness.quantiles(medians)["median"])
	print("[BALANCE] regular median of medians %.1f s" % m)
	var band: Vector2 = _widen(Vector2(Harness.BAND_REGULAR_MEDIAN[0], Harness.BAND_REGULAR_MEDIAN[1]))
	assert_between(m, band.x, band.y, "median over the regular encounters (20–25 s ± 20 %)")
	var tut: Dictionary = Harness.series(data, "enc_f1_a1_tutorial", "kai", 0, 5)
	print("[BALANCE] " + Harness.line(tut))
	assert_eq(int(tut["losses"]), 0, "the tutorial is never lost")
	assert_between(float((tut["sec"] as Dictionary)["median"]), sec.x, sec.y, "tutorial duration")


func test_bosses_per_hero() -> void:
	var data: GameData = real_data()
	for enc: String in Harness.BOSSES:
		var sec: Vector2 = _widen(_band(enc, "sec"))
		var loss: Array = BOSS_CI_LOSS[enc]
		for hero: String in ["kai", "mopsula"]:
			var s: Dictionary = Harness.series(data, enc, hero, 0, 10)
			print("[BALANCE] " + Harness.line(s))
			assert_between(float(s["loss_rate"]), float(loss[0]), float(loss[1]),
				"%s / %s: first-try losses (CI band of 07 §11.4)" % [enc, hero])
			assert_between(float((s["sec"] as Dictionary)["median"]), sec.x, sec.y,
				"%s / %s: duration median (07 §11.1 ± 20 %%)" % [enc, hero])


func test_show_boss_per_hero() -> void:
	var data: GameData = real_data()
	var sec: Vector2 = _widen(_band(Harness.SHOW_BOSS, "sec"))
	for hero: String in ["kai", "mopsula"]:
		var s: Dictionary = Harness.series(data, Harness.SHOW_BOSS, hero, 0, 5)
		print("[BALANCE] " + Harness.line(s))
		assert_true(float(s["loss_rate"]) <= 0.2, hero + ": show boss losses ≤ 20 % (E26)")
		assert_between(float((s["sec"] as Dictionary)["median"]), sec.x, sec.y, hero + ": show boss 20–40 s ± 20 %")


## The harness itself: reproducible (same seed → same fight), the bot plays through the live command path, the
## statistics and the band verdicts of the nightly run.
func test_harness_is_deterministic() -> void:
	var data: GameData = real_data()
	var a: Dictionary = Harness.fight(data, "enc_f1_b2", "mopsula", 0, 3)
	var b: Dictionary = Harness.fight(data, "enc_f1_b2", "mopsula", 0, 3)
	assert_eq([a["ticks"], a["hp_loss_pm"], a["outcome"]], [b["ticks"], b["hp_loss_pm"], b["outcome"]], "same seed")
	assert_gt(int(a["gcd_windows"]), 0, "the bot pressed abilities through RtSim.submit")
	var ci: Vector2 = Harness.wilson(3, 10)
	assert_almost(ci.x, 0.108, 0.002, "Wilson 95 % lower bound of 3/10")
	assert_almost(ci.y, 0.603, 0.002, "Wilson 95 % upper bound of 3/10")
	var s0: Dictionary = Harness.summarize([{"won": true, "ticks": 5400}, {"won": false, "ticks": 6000}])
	s0.merge({"enc": "enc_f1_boss_hausmeister", "hero": "kai", "liga": 0, "profile": "typical"})
	var s1: Dictionary = s0.duplicate(true)
	s1["liga"] = 1
	var v: PackedStringArray = Harness.band_report([s0, s1], [])
	assert_true(v.has("OUT enc_f1_boss_hausmeister kai L0: first-try losses % 50.0 [10–30]"), str(v))
	assert_true(v.has("ok  enc_f1_boss_hausmeister kai L0: duration median s 180.0 [150–210]"), str(v))
	assert_true(v.has("OUT enc_f1_boss_hausmeister kai L1: first-try losses % 50.0 [0–40]"), str(v))
	assert_true(v.has("OUT enc_f1_boss_hausmeister kai: Liga 1 − Liga 0 losses (points) 0.0 [5–15]"), str(v))
	s0["profile"] = "perfect"
	assert_eq(Harness.band_report([s0], []).size(), 0, "yardstick profiles carry no band")
