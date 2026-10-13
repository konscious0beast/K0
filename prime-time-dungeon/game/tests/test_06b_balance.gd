extends TestCase
## 06 package B — talents keep the GDD §13 bands (06 §2.2 "Umfang", §8.3 Balance-Band):
##   1. the sum of all talent bonuses per stat at L10 stays <= +15 % for EVERY possible pick sequence (exhaustive over
##      all multisets of the 4 picks L3/L5/L7/L9 within max_rank — a superset of every seeded offer sequence), measured
##      against the level stats without equipment (the strictest base; the Liga talents count, since that member wears
##      neither armor nor accessory there);
##   2. the boss bands with the bot's talent picks are measured in real time since R5b part 2b (07 §12.4: the harness
##      plays the first offer of every choice, tools/rt_balance.sh --hero, test_r4_rt_balance); the CTB fights of
##      test_m7_show_balance that pinned them here are gone with the CTB campaign.

const BAND_PCT_PM: int = 150                 # +15 %
const PICKS_AT_L10: int = 4


# --- 1. the +15 % band, exhaustive ------------------------------------------------------------------------------------

func test_talent_bonus_per_stat_stays_within_15_percent_for_every_pick_sequence() -> void:
	var d: GameData = real_data()
	for mid: String in ["kai", "mopsula"]:
		var pool: Array[TalentDef] = d.talents_for(mid)
		var bare: PartyMember = _bare(mid, 10)
		var base: PackedInt32Array = Progression.total_stats(bare, d).values
		var worst: PackedInt32Array = []
		worst.resize(base.size())
		var combos: Array[Dictionary] = []
		_multisets(pool, 0, PICKS_AT_L10, {}, combos)
		assert_gt(combos.size(), 100, mid + ": enumerated pick multisets")
		var crit_max: int = 0
		var mp_max: int = 0
		for talents: Dictionary in combos:
			bare.talents = talents
			var v: PackedInt32Array = Progression.total_stats(bare, d).values
			for i in v.size():
				worst[i] = maxi(worst[i], v[i] - base[i])
				assert_true((v[i] - base[i]) * 1000 <= base[i] * BAND_PCT_PM, "%s %s: +%d on %d with %s" % [mid,
					StatBlock.KEYS[i], v[i] - base[i], base[i], str(talents)])
			crit_max = maxi(crit_max, Talents.crit_add_pm(bare, d))
			mp_max = maxi(mp_max, Talents.post_battle_mp_pm(bare, d))
		print("[06b_balance] %s: %d pick sets, worst bonus per stat %s on %s, crit +%d pm, MP regen +%d pm" % [mid,
			combos.size(), str(Array(worst)), str(Array(base)), crit_max, mp_max])
		assert_true(crit_max <= 80, mid + ": crit chance at most +8 points")
		assert_true(mp_max <= 100, mid + ": Werbepause at most +10 % MaxMP")


## Every multiset of `left` picks from pool[i..] with count(t) <= t.max_rank → out.
func _multisets(pool: Array[TalentDef], i: int, left: int, cur: Dictionary, out: Array[Dictionary]) -> void:
	if left == 0:
		out.append(cur.duplicate())
		return
	if i >= pool.size():
		return
	var t: TalentDef = pool[i]
	for n in range(0, mini(t.max_rank, left) + 1):
		if n > 0:
			cur[t.id] = n
		_multisets(pool, i + 1, left - n, cur, out)
	cur.erase(t.id)


func _bare(mid: String, level: int) -> PartyMember:
	var m: PartyMember = PartyMember.new()
	m.id = mid
	m.level = level
	return m
