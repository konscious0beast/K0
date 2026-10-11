extends TestCase
## 06 package B — talents keep the GDD §13 bands (06 §2.2 "Umfang", §8.3 Balance-Band):
##   1. the sum of all talent bonuses per stat at L10 stays <= +15 % for EVERY possible pick sequence (exhaustive over
##      all multisets of the 4 picks L3/L5/L7/L9 within max_rank — a superset of every seeded offer sequence), measured
##      against the level stats without equipment (the strictest base; the Liga talents count, since that member wears
##      neither armor nor accessory there);
##   2. with the FIRST offer of every choice picked (the full-run bot's rule), the boss fights of test_m7_show_balance
##      (Hausmeister L5 / Königin L7, the bot's loadout, sponsor gifts as they occur, hype at the exploration floor)
##      move the loss rate by at most 5 points against the same fights without talents ("±5 Punkte der heutigen
##      Werte"). Measured on SHIFT_SEEDS = 300 paired fights: a win rate from 100 fights has a sampling error of ~4
##      points — as large as the band itself (while tuning, the final pool measured the Königin at +5 points on the
##      first 100 seeds, +3.7 on 300 and +1.3 on 600; the Hausmeister at -0.2 on 600).
## Tuning record (600 fights each, 06 package B): without talents 84.3 % / 70.2 % wins; with STR/MAG +2 and SPD +1 at
## max_rank 2: 84.8 % / 75.5 % (Königin +5.3 — Mopsula's speed talent alone ~+3); final pool (STR/MAG +1, speed talent
## rare and max_rank 1): 84.2 % / 71.5 %. After the IP renames of integration round 1b (new ids → new id order of the
## pools → other seeded offers, same values) the 300 paired fights measure -1.0 (Hausmeister) / +4.3 (Königin).

const M7 := preload("res://tests/test_m7_balance.gd")
const M7S := preload("res://tests/test_m7_show_balance.gd")
const BAND_PCT_PM: int = 150                 # +15 %
const PICKS_AT_L10: int = 4
const MAX_SHIFT: float = 0.05
const SHIFT_SEEDS: int = 300
const SR: StringName = &"sr_test"

var _m7: Object = null
var _prev_data: GameData = null


func before_each() -> void:
	_m7 = M7.new()
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


# --- 2. boss loss rates with the bot's talent picks -------------------------------------------------------------------

func test_boss_loss_rates_with_first_offer_talents_stay_within_5_points() -> void:
	for enc_id: String in M7S.BOSS_WIN_BAND:
		var level: int = int(M7.PLAN[enc_id][0])
		# paired fights (same seeds) with and without talents
		var without: Dictionary = _series(enc_id, level, false, SHIFT_SEEDS)
		var with_t: Dictionary = _series(enc_id, level, true, SHIFT_SEEDS)
		var shift: float = float(with_t["win_rate"]) - float(without["win_rate"])
		var label: String = "%s at L%d, %d paired fights: without %s / with first-offer talents %s → %+.1f points" % [
			enc_id, level, SHIFT_SEEDS, str(without), str(with_t), shift * 100.0]
		print("[06b_balance] ", label)
		assert_true(absf(shift) <= MAX_SHIFT + 0.0001, "loss rate moves <= 5 points — " + label)
		assert_eq(int(with_t["picks"]), SHIFT_SEEDS * 2 * Talents.pending_levels(_bare("kai", level)).size(),
			"every open choice picked")


## `n` fights like M7S._boss_series (same seed derivation), the party built from PartyMembers
## (Progression.to_combatant) at `level` with the bot loadout; `talents`: every open choice takes the first offer
## (seeded by the state seed).
func _series(enc_id: String, level: int, talents: bool, n: int = M7S.BOSS_SEEDS) -> Dictionary:
	var d: GameData = real_data()
	var wins: int = 0
	var picks: int = 0
	var loadout: Dictionary = M7S.BOSS_LOADOUT[enc_id]
	for i in n:
		Game.state = GameState.create_new(d, 0, "Kai", SeedUtil.derive(4242, "m7_boss_state", i))
		Game.state.show.hype = M7S.BOSS_HYPE_START
		for a: AchievementDef in d.all_achievements():
			Game.state.show.achievements.append(a.id)
		var members: Array[PartyMember] = _party(Game.state, d, level, loadout["gear"] as Dictionary, talents)
		for m: PartyMember in members:
			picks += Talents.picks(m)
		var won: bool = _fight(d, enc_id, members, loadout["items"] as Dictionary, SeedUtil.derive(7331, "m7_boss", i))
		Game.state = null
		wins += 1 if won else 0
	return {"win_rate": snappedf(float(wins) / float(n), 0.001), "picks": picks}


func _party(st: GameState, d: GameData, level: int, gear: Dictionary, talents: bool) -> Array[PartyMember]:
	st.floor_run = FloorRun.create(d.floor_def(1), st.seed, st.difficulty)
	st.floor_run.location = SR
	var out: Array[PartyMember] = []
	for m: PartyMember in st.party:
		m.level = level
		var g: Array = gear[m.id]
		m.equipment = {"weapon": str(g[0]), "armor": str(g[1]), "accessory": str(g[2])}
		var skills: PackedStringArray = []
		for l: Dictionary in d.party_member(m.id).learnset:
			if int(l["level"]) <= level:
				skills.append(str(l["skill"]))
		m.skills = skills
		if talents:
			while Talents.has_choice(st, d, m.id):
				Talents.pick(st, d, m.id, Talents.current_offer(st, d, m.id)[0])
		out.append(m)
	Progression.full_heal(st, d)
	return out


## One boss fight with the Show in the loop and gifts at the turn boundary (M7S.show_battle, PartyMember party).
func _fight(d: GameData, enc_id: String, members: Array[PartyMember], items: Dictionary, seed: int) -> bool:
	var enc: EncounterDef = d.encounter(enc_id)
	var setup: BattleSetup = BattleSetup.new()
	setup.encounter_id = enc_id
	setup.enemy_ids = enc.enemies.duplicate()
	setup.seed = seed
	setup.is_boss = enc.boss
	setup.can_flee = enc.can_flee and not enc.tutorial
	setup.items = items.duplicate()
	setup.credits_available = 200
	setup.auto_battle = true
	setup.floor_index = 1
	var party: Array[Combatant] = []
	for i in members.size():
		party.append(Progression.to_combatant(members[i], d, "p%d" % i, i))
	setup.party = party
	Game.in_battle = true
	Show.begin_battle(setup)
	var st: BattleState = BattleState.new(setup, d)
	var events: Array[ActionEvent] = st.start()
	var submits: int = 0
	while true:
		for e: ActionEvent in events:
			Show.on_battle_event(e)
		if st.is_finished() or submits >= M7.MAX_SUBMITS:
			break
		var g: Dictionary = Show.take_pending_gift(st)
		if not g.is_empty():
			for e: ActionEvent in st.apply_gift(g):
				Show.on_battle_event(e)
		events = st.submit(st.choose_ai_command())
		submits += 1
	Game.in_battle = false
	var won: bool = st.result != null and st.result.outcome == BattleResult.Outcome.VICTORY
	Show.end_battle(st.result)
	return won


func test_party_builder_matches_the_m7_baseline_without_talents() -> void:
	# the paired baseline above is the same party test_m7_show_balance fights with (stats, skills, crit, elements)
	var d: GameData = real_data()
	var st: GameState = GameState.create_new(d, 0, "Kai", 1)
	var loadout: Dictionary = M7S.BOSS_LOADOUT["enc_f1_boss_hausmeister"]
	var members: Array[PartyMember] = _party(st, d, 5, loadout["gear"] as Dictionary, false)
	for i in members.size():
		var mine: Combatant = Progression.to_combatant(members[i], d, "p%d" % i, i)
		var def: PartyMemberDef = d.party_member(members[i].id)
		var ref: Combatant = _m7.call("_make_member", d, def, i, 5, (loadout["gear"] as Dictionary)[def.id])
		assert_eq(mine.stats.values, ref.stats.values, def.id + " stats")
		assert_eq(mine.skills, ref.skills, def.id + " skills")
		assert_almost(mine.crit_bonus, ref.crit_bonus)
		assert_eq(mine.hp, ref.hp)
		assert_eq(mine.talent_mods, {})
