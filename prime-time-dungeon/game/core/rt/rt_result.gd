extends RefCounted
## End of a real-time combat (07 §2.11, §3.12) — private helper of RtSim (no class_name; preloaded as Result): the end
## check of step 10 and the BattleResult (filled like the CTB result, plus the real-time fields).

const FixedMath := preload("res://core/stats/fixed_math.gd")


## Step 10 (07 §3.3): every enemy KO / escaped → VICTORY (also when the party fell in the same tick), every party unit
## KO → DEFEAT, flight → FLED, ct ≥ MAX_COMBAT_TICKS → FLED ("Sendezeit überzogen!"). Returns the outcome or −1.
static func check_end(sim: RtSim, c: int) -> int:
	var enemies_left: bool = false
	var party_left: bool = false
	for u: RtUnit in sim.units_ref():
		if u.hp <= 0 or u.left_battle:
			continue
		if u.side == Combatant.Side.ENEMY:
			enemies_left = true
		else:
			party_left = true
	if not enemies_left:
		return BattleResult.Outcome.VICTORY
	if not party_left:
		return BattleResult.Outcome.DEFEAT
	if sim.fled or c + 1 >= sim.max_combat_ticks:
		return BattleResult.Outcome.FLED
	return -1


## The result after tick c (07 §3.12): like the CTB result (EXP, credits, overkill credits, loot, boss rewards plus
## the show-boss reward on VICTORY — 07 §9.6, E26 —, theft and refunds: a thief's credits come back on VICTORY with
## refund_on_win when it was KO'd, else they are stolen) plus the real-time counters.
static func build(sim: RtSim, outcome: int, c: int) -> BattleResult:
	var setup: RtSetup = sim.setup
	var tally: Dictionary = sim.tally
	var r: BattleResult = BattleResult.new()
	r.outcome = outcome as BattleResult.Outcome
	r.encounter_id = setup.encounter_id
	r.group_id = setup.group_id
	for g: Dictionary in setup.groups:
		var gid: String = str(g.get("group_id", ""))
		if gid != "" and not r.group_ids.has(gid):
			r.group_ids.append(gid)
	if r.group_ids.is_empty() and setup.group_id != "":
		r.group_ids.append(setup.group_id)
	r.is_boss = setup.is_boss
	r.advantage = int(setup.advantage)
	r.opener = setup.opener if setup.advantage == BattleSetup.Advantage.PREEMPTIVE else ""
	r.turns = int(tally["turns"])
	r.party_turns = int(tally["party_turns"])
	for u: RtUnit in sim.units_ref():
		if u.side == Combatant.Side.ENEMY and u.is_boss and not u.is_summon:
			r.boss_id = u.def_id
			r.is_boss = true
			break
	var killed: Array = tally["killed"]
	var overkill: Array = tally["overkill"]
	for id: Variant in killed:
		var e: RtUnit = sim.unit(str(id))
		if e != null:
			r.defeated_ids.append(e.def_id)
	r.kills = killed.size()
	if outcome == BattleResult.Outcome.VICTORY:
		var exp_sum: int = 0
		var lck_sum: int = 0
		var members: int = 0
		for m: RtUnit in sim.units_ref():
			if m.side == Combatant.Side.PARTY:
				lck_sum += m.stat(StatBlock.Stat.LCK)
				members += 1
		var rng: RandomNumberGenerator = SeedUtil.make_rng(SeedUtil.derive(setup.seed, "drops", 0))
		for id: Variant in killed:
			var e: RtUnit = sim.unit(str(id))
			if e == null or e.is_summon:
				continue
			exp_sum += e.exp_reward
			var cr: int = e.credit_reward
			if overkill.has(e.id):
				var bonus: int = FixedMath.mul_pm(cr, FixedMath.pm(Balance.OVERKILL_CREDIT_MULT))
				r.overkill_credits += bonus - cr
				cr = bonus
			r.credits += cr
			r.drops.append_array(BattleResult.roll_drops(e.drops, lck_sum, members, rng))
			if e.is_boss:
				for bd: Dictionary in e.boss_drops:
					r.boss_rewards.append({"kind": str(bd.get("kind", "")), "id": str(bd.get("id", "")),
						"amount": JsonUtil.to_int(bd.get("amount", 1), 1)})
		r.exp = exp_sum * FixedMath.pm(setup.exp_mult) / FixedMath.PM
		r.boss_rewards.append_array(show_boss_rewards(sim))
	var thieves: Dictionary = tally["thieves"]
	var tkeys: Array = thieves.keys()
	tkeys.sort()
	for k: Variant in tkeys:
		var t: Dictionary = thieves[k]
		var amount: int = int(t.get("amount", 0))
		if outcome == BattleResult.Outcome.VICTORY and bool(t.get("refund", false)) and killed.has(str(k)):
			r.credits_refunded += amount
		else:
			r.credits_stolen += amount
	r.credits_delta = int(tally["credits_delta"])
	r.item_delta = (tally["item_delta"] as Dictionary).duplicate(true)
	var wf: Dictionary = tally["weak_found"]
	var wkeys: Array = wf.keys()
	wkeys.sort()
	for k: Variant in wkeys:
		r.weak_found[str(k)] = PackedStringArray(wf[k])
	r.escaped = PackedStringArray(tally["escaped"])
	r.damage_taken = int(tally["damage_taken"])
	r.crits = int(tally["crits"])
	r.weakness_hits = int(tally["weakness_hits"])
	r.items_used = int(tally["potions_used"])
	r.party_kos = int(tally["party_kos"])
	var min_hp: int = -1
	var low: RtUnit = null
	for m: RtUnit in sim.units_ref():
		if m.side != Combatant.Side.PARTY:
			continue
		r.party_hp[m.def_id] = maxi(0, m.hp)
		r.party_mp[m.def_id] = maxi(0, m.mp)
		if sim.is_alive(m):
			if min_hp < 0 or m.hp < min_hp:
				min_hp = m.hp
			if low == null or m.hp * low.max_hp() < low.hp * m.max_hp():
				low = m
	r.min_party_hp = maxi(0, min_hp)
	r.min_party_hp_pct = low.hp_ratio() if low != null else FixedMath.from_ppm(0)
	r.duration_ticks = c + 1
	for k: String in ["interrupts", "dodges", "telegraph_hits", "train_kills", "perfect_phases", "potions_used",
			"flee_attempts"]:
		r.set(k, int(tally[k]))
	r.rt_presets = changed_presets(sim)
	return r


## R5b: the party tactics that changed during the combat — member def id → {"preset", "tog"} of every party unit whose
## preset or switches differ from its start values (RtSetup.units, the setup's own copies); {} without a change, so the
## result (and every hash over it) stays the same for the combats that never touch the tactic.
static func changed_presets(sim: RtSim) -> Dictionary:
	var out: Dictionary = {}
	var start: Dictionary = {}
	for su: RtUnit in sim.setup.units:
		start[su.id] = su
	for u: RtUnit in sim.party_ref():
		var su: RtUnit = start.get(u.id, null)
		if su == null or (u.preset == su.preset and u.toggles == su.toggles):
			continue
		var tog: Dictionary = {}
		for k: String in RtVocab.RT_TOGGLES:
			tog[k] = bool(u.toggles.get(k, RtVocab.RT_TOGGLE_DEFAULTS.get(k, false)))
		out[u.def_id] = {"preset": u.preset, "tog": tog}
	return out


## The rewards of the show bosses of the combat (07 §9.6, E26): show_boss.reward of every encounter named by a
## "showboss:<encounter id>" mod (list order, each once) as a boss reward {"kind", "id", "amount": 1}.
static func show_boss_rewards(sim: RtSim) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var data: GameData = sim.game_data()
	var seen: Dictionary = {}
	for m: Dictionary in sim.setup.mods:
		var src: String = str(m.get("src", ""))
		if not src.begins_with("showboss:") or seen.has(src):
			continue
		seen[src] = true
		var enc_id: String = src.substr(9)
		if data == null or not data.has_id("encounters", enc_id):
			continue
		var reward: Variant = data.encounter(enc_id).show_boss.get("reward", {})
		if reward is Dictionary and str((reward as Dictionary).get("id", "")) != "":
			out.append({"kind": str((reward as Dictionary).get("kind", "")), "id": str((reward as Dictionary)["id"]),
				"amount": 1})
	return out
