class_name BattleBridge extends RefCounted
## GameState ↔ BattleSetup/BattleResult (02_TECH §6.1, GDD §3.12/§10.2).

const PEP_TALK_FLAG: String = "mop_pep_talk"
const PEP_TALK_STATUS: String = "sts_guard"
const PEP_TALK_TURNS: int = 2
const LIGHT_FOOTED: String = "sts_light_footed"     # Unterhosen-Liga in the real-time combat (R5b, E31)
const KO_EXP_PCT: int = 50                   # KO'd members get floori(50 %) of the battle EXP


## Party combatants via Progression.to_combatant (ids p0.. in battle_slot order); items = inventory.battle_items;
## credits_available = inventory.credits; owned_equipment (gift duplicates → credits, 05 §6.9); encounter: is_boss,
## can_flee, tutorial; bosses force NORMAL;
## enemy_dmg_mult = (vorabend 0.75) × (tutorial 0.5); exp_mult (vorabend 1.2); show_mods = state.hype_gain_mult /
## follower_mult; floor palette/theme; is_boss and flags["mop_pep_talk"] → both party combatants start with
## sts_guard 2, flag erased (GDD §10.2). Unknown encounter → null. `rules` = the run's rules (campaign {}): the
## Unterhosen-Liga tier (MarottenRules.liga_tier, never in the tutorial) decides who counts liga_stat_pct talents.
static func make_setup(state: GameState, data: GameData, encounter_id: String, advantage: int, group_id: String,
		seed: int, rules: Dictionary = {}) -> BattleSetup:
	if state == null or data == null or not data.has_id("encounters", encounter_id):
		push_warning("[BattleBridge] unknown encounter '%s'" % encounter_id)
		return null
	var enc: EncounterDef = data.encounter(encounter_id)
	var setup: BattleSetup = BattleSetup.new()
	setup.encounter_id = encounter_id
	setup.group_id = group_id
	setup.enemy_ids = enc.enemies.duplicate()
	setup.seed = seed
	setup.is_boss = enc.boss
	setup.can_flee = enc.can_flee
	setup.tutorial = enc.tutorial
	setup.advantage = BattleSetup.Advantage.NORMAL if enc.boss else _advantage(advantage)
	var vorabend: bool = state.difficulty == &"vorabend"
	setup.enemy_dmg_mult = (Balance.EASY_ENEMY_DMG if vorabend else 1.0) \
		* (Balance.TUTORIAL_ENEMY_DMG if enc.tutorial else 1.0)
	setup.exp_mult = Balance.EASY_EXP if vorabend else 1.0
	setup.show_mods = {"hype_gain_mult": state.hype_gain_mult(data), "follower_mult": state.follower_mult(data)}
	setup.floor_index = state.floor_run.index if state.floor_run != null else maxi(1, enc.floor_index)
	var fdef: FloorDef = data.floor_def(setup.floor_index)
	if fdef != null:
		setup.theme_id = fdef.theme
		setup.palette = fdef.palette.duplicate(true)
	if state.inventory != null:
		setup.items = state.inventory.battle_items(data)
		setup.credits_available = state.inventory.credits
	setup.owned_equipment = _owned_equipment(state, data)
	var party: Array[Combatant] = []
	# 06 B × C: the Liga talents follow the battle's Unterhosen-Liga tier — the tier Show freezes in begin_battle
	# (tutorial: none; rules = the run's rules, Game.event_rules / RunSim.rules)
	var liga_tier: int = 0 if enc.tutorial else MarottenRules.liga_tier(state, rules)
	for i in state.party.size():
		var m: PartyMember = state.party[i]
		if m == null or not data.has_id("party", m.id):
			continue
		var c: Combatant = Progression.to_combatant(m, data, "p%d" % party.size(), data.party_member(m.id).battle_slot,
			MarottenRules.in_liga(state, m.id, liga_tier))
		if c != null:
			party.append(c)
	setup.party = party
	if enc.boss and bool(state.flags.get(PEP_TALK_FLAG, false)) and data.has_id("statuses", PEP_TALK_STATUS):
		var guard: StatusDef = data.status(PEP_TALK_STATUS)
		for c: Combatant in setup.party:
			c.statuses.append(StatusEffect.new(guard, PEP_TALK_TURNS, c.id))
		state.flags.erase(PEP_TALK_FLAG)
	return setup


## In this order (GDD §3.11/§3.12): (1) hp/mp writeback (KO'd members stay at 0 HP for now); (2) item_delta →
## inventory, credits_delta; (3) stolen credits the enemies kept (result.credits_stolen: escaped or surviving thieves,
## every outcome) are deducted → credits_lost, refunds (result.credits_refunded: VICTORY + refund_on_win + thief KO'd —
## they never left the inventory) are reported as credits_refunded; (4) VICTORY: EXP per member (alive full, KO'd
## floori(50 %) — a level-up does not heal a KO'd member), credits (+overkill), drops, boss_rewards (items → inventory,
## boxes → pending_lootboxes), Werbepause +ceil(max_mp × (150 + Talents.post_battle_mp_pm) ‰) MP for living members
## (06 package B; without talents ceili(max_mp × 0.15)); (5) only now KO → 1 HP unless DEFEAT; (6) VICTORY:
## defeated_groups += group_id, strays.erase(group_id), flags defeated_<boss_id> + quarter/floor boss flags, VICTORY
## over FloorDef.timer_start_after → floor_run.timer_started = true; (7) every outcome: bestiary (defeated += 1 per
## defeated_ids entry, weak_known ∪= weak_found), floor_run.stats.kills += kills, floor_run.stats.party_kos +=
## party_kos (only once > 0).
static func apply_result(state: GameState, data: GameData, result: BattleResult) -> BattleRewards:
	var rw: BattleRewards = BattleRewards.new()
	if state == null or data == null or result == null:
		return rw
	if state.inventory == null:
		state.inventory = Inventory.new()
	var victory: bool = result.outcome == BattleResult.Outcome.VICTORY
	var was_ko: Dictionary = _writeback(state, data, result)
	write_presets(state, result)
	_apply_inventory_delta(state, data, result)
	_apply_stolen(state, result, rw, victory)
	if victory:
		_apply_victory_rewards(state, data, result, rw, was_ko)
	if result.outcome != BattleResult.Outcome.DEFEAT:
		_revive(state, was_ko, rw)
	if victory:
		_floor_bookkeeping(state, data, result)
	_bestiary_and_kills(state, result)
	TwistApplier.on_battle_end(state, data)             # 06-D: "battles" twists count down (every outcome)
	_rt_after_combat(state)                             # Echtzeitkampf (07 §2.7, R1b): regeneration counter
	return rw


## Sorted equipment ids of LootRoller.owned_equipment (the duplicate rule of gifts in battle, 05 §6.9).
static func _owned_equipment(state: GameState, data: GameData) -> PackedStringArray:
	var out: PackedStringArray = []
	for item_id: Variant in LootRoller.owned_equipment(state).keys():
		if data.has_id("items", str(item_id)) and data.item(str(item_id)).is_equipment():
			out.append(str(item_id))
	out.sort()
	return out


static func _advantage(advantage: int) -> BattleSetup.Advantage:
	match advantage:
		BattleSetup.Advantage.PREEMPTIVE:
			return BattleSetup.Advantage.PREEMPTIVE
		BattleSetup.Advantage.AMBUSH:
			return BattleSetup.Advantage.AMBUSH
	return BattleSetup.Advantage.NORMAL


## (1) hp/mp from the result, clamped to the current maxima. Returns {member id: true} of the KO'd members (hp 0).
static func _writeback(state: GameState, data: GameData, result: BattleResult) -> Dictionary:
	var was_ko: Dictionary = {}
	for m: PartyMember in state.party:
		if m == null:
			continue
		var sb: StatBlock = Progression.total_stats(m, data)
		if result.party_hp.has(m.id):
			m.hp = clampi(JsonUtil.to_int(result.party_hp[m.id]), 0, sb.values[StatBlock.Stat.HP])
		if result.party_mp.has(m.id):
			m.mp = clampi(JsonUtil.to_int(result.party_mp[m.id]), 0, sb.values[StatBlock.Stat.MP])
		if m.hp <= 0:
			was_ko[m.id] = true
	return was_ko


## (2) battle inventory changes (used items, gift items) and gift credits.
static func _apply_inventory_delta(state: GameState, data: GameData, result: BattleResult) -> void:
	var delta_ids: Array = result.item_delta.keys()
	delta_ids.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
	for item_id: Variant in delta_ids:
		var n: int = JsonUtil.to_int(result.item_delta[item_id])
		var iid: String = str(item_id)
		if n < 0:
			state.inventory.remove(iid, mini(-n, state.inventory.count(iid)))
		elif n > 0 and data.has_id("items", iid):
			state.inventory.add_item_or_credits(data, iid, n)
	if result.credits_delta != 0:
		state.inventory.add_credits(result.credits_delta)


## (3) GDD §3.11: credits a thief kept (escaped, survived, or the battle was not won) are gone in every outcome;
## the refunded part (VICTORY, refund_on_win, thief KO'd) was never taken from the inventory.
static func _apply_stolen(state: GameState, result: BattleResult, rw: BattleRewards, victory: bool) -> void:
	if result.credits_stolen > 0:
		rw.credits_lost = mini(result.credits_stolen, state.inventory.credits)
		state.inventory.spend_credits(rw.credits_lost)
	if victory:
		rw.credits_refunded = maxi(0, result.credits_refunded)


## (4) VICTORY: EXP (KO'd members still at 0 HP: half EXP, no level-up heal), credits, drops, boss rewards,
## Werbepause MP for the living.
static func _apply_victory_rewards(state: GameState, data: GameData, result: BattleResult, rw: BattleRewards,
		was_ko: Dictionary) -> void:
	rw.exp = maxi(0, result.exp)
	for m: PartyMember in state.party:
		if m == null:
			continue
		var gain: int = rw.exp * KO_EXP_PCT / 100 if was_ko.has(m.id) else rw.exp
		rw.level_ups.append_array(Progression.add_exp(m, gain, data))
	rw.credits = maxi(0, result.credits)
	rw.credits += TwistApplier.take_bonus_credits(state, rw.credits)   # 06-D: tw_double_credits
	rw.overkill_credits = maxi(0, result.overkill_credits)
	state.inventory.add_credits(rw.credits)
	for item_id: String in result.drops:
		if item_id != "" and data.has_id("items", item_id):
			state.inventory.add_item_or_credits(data, item_id, 1)
			rw.items.append(item_id)
	for br: Dictionary in result.boss_rewards:
		var kind: String = str(br.get("kind", "item"))
		var rid: String = str(br.get("id", ""))
		var amount: int = maxi(1, JsonUtil.to_int(br.get("amount", 1), 1))
		if kind == "box" and data.has_id("lootboxes", rid):
			for _i in amount:
				state.pending_lootboxes.append(rid)
				rw.boxes.append(rid)
		elif kind == "item" and data.has_id("items", rid):
			state.inventory.add_item_or_credits(data, rid, amount)
			for _i in amount:
				rw.items.append(rid)
	# "Werbepause": living members (not KO at battle end) +ceili(max_mp × (0.15 + talent bonus)) MP
	var regen_pm: int = roundi(Balance.POST_BATTLE_MP_REGEN * 1000.0)
	for m: PartyMember in state.party:
		if m == null or was_ko.has(m.id):
			continue
		var max_mp: int = Progression.total_stats(m, data).values[StatBlock.Stat.MP]
		var pm: int = regen_pm + Talents.post_battle_mp_pm(m, data)     # 06 package B: "Automatenkaffee"
		var regen: int = (max_mp * pm + 999) / 1000
		var before: int = m.mp
		m.mp = mini(max_mp, m.mp + regen)
		rw.mp_regen[m.id] = m.mp - before


## (5) after the EXP (GDD §3.12 "Danach stehen KO-Mitglieder mit 1 HP auf"): KO → KO_REVIVE_HP (not after a DEFEAT).
static func _revive(state: GameState, was_ko: Dictionary, rw: BattleRewards) -> void:
	for m: PartyMember in state.party:
		if m != null and was_ko.has(m.id):
			m.hp = Balance.KO_REVIVE_HP
			rw.revived.append(m.id)


## (6) VICTORY: floor bookkeeping (defeated groups, strays, boss flags, timer start).
static func _floor_bookkeeping(state: GameState, data: GameData, result: BattleResult) -> void:
	var fr: FloorRun = state.floor_run
	if fr != null:
		if result.group_id != "":
			if not fr.defeated_groups.has(result.group_id):
				fr.defeated_groups.append(result.group_id)
			fr.strays.erase(result.group_id)
		for gid: String in result.group_ids:                  # Echtzeitkampf (07, R1a): every group of the combat
			if gid != "" and not fr.defeated_groups.has(gid):
				fr.defeated_groups.append(gid)
			fr.strays.erase(gid)
		var fdef: FloorDef = data.floor_def(fr.index)
		if fdef != null:
			if result.encounter_id != "" and result.encounter_id == fdef.quarter_boss:
				fr.quarter_boss_defeated = true
			if result.encounter_id != "" and result.encounter_id == fdef.floor_boss:
				fr.floor_boss_defeated = true
			if fdef.timer_start_after != "" and result.encounter_id == fdef.timer_start_after:
				fr.timer_started = true
		if result.group_id.ends_with("_qb"):
			fr.quarter_boss_defeated = true
		elif result.group_id.ends_with("_fb"):
			fr.floor_boss_defeated = true
	if result.boss_id != "":
		state.flags["defeated_" + result.boss_id] = true


## (7) every outcome: bestiary, kills, party KOs of the floor (event score KO penalty, 05 §1.5; the key appears with
## the first KO).
static func _bestiary_and_kills(state: GameState, result: BattleResult) -> void:
	for enemy_id: String in result.defeated_ids:
		var entry: Dictionary = _bestiary_entry(state, enemy_id)
		entry["defeated"] = int(entry["defeated"]) + 1
	var weak_ids: Array = result.weak_found.keys()
	weak_ids.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
	for enemy_id: Variant in weak_ids:
		var entry: Dictionary = _bestiary_entry(state, str(enemy_id))
		var known: PackedStringArray = entry["weak_known"]
		for el: String in JsonUtil.to_str_array(result.weak_found[enemy_id]):
			if not known.has(el):
				known.append(el)
		entry["weak_known"] = known
	var fr: FloorRun = state.floor_run
	if fr != null:
		fr.stats["kills"] = int(fr.stats.get("kills", 0)) + maxi(0, result.kills)
		if result.party_kos > 0:
			fr.stats["party_kos"] = int(fr.stats.get("party_kos", 0)) + result.party_kos


static func _bestiary_entry(state: GameState, enemy_id: String) -> Dictionary:
	if not state.bestiary.has(enemy_id) or not (state.bestiary[enemy_id] is Dictionary):
		state.bestiary[enemy_id] = {"defeated": 0, "weak_known": PackedStringArray()}
	var entry: Dictionary = state.bestiary[enemy_id]
	if not entry.has("defeated"):
		entry["defeated"] = 0
	entry["weak_known"] = JsonUtil.to_str_array(entry.get("weak_known", []))
	return entry


# --- Echtzeitkampf (07, R1b) ------------------------------------------------------------------------------------------

## The start data of a real-time combat (07 §3.4, §10.5) from the recorded encounter command `cmd` ({"t": "encounter",
## "enc", "adv", "group", "opener"?, "rt": {…}}, 07 §10.1) and the battle seed (next_seed "battle"): campaign rules
## ({}). null for an invalid command, an unknown encounter or a cell without a set (stairs). See make_rt_setup_rules.
static func make_rt_setup(state: GameState, data: GameData, cmd: Dictionary, seed: int) -> RtSetup:
	return make_rt_setup_rules(state, data, cmd, seed, {})


## make_rt_setup with the run's rules (Game.event_rules / RunSim.rules; the contract signature has none): they decide
## the Unterhosen-Liga tier of liga talents (as in make_setup) and give RtSetup.rules its combat part (rules.combat,
## 07 §10.7). Built like make_setup — encounter flags, advantage (bosses NORMAL), damage / EXP factors of the recorded
## difficulty, show mods, floor palette, battle items, credits, the pep talk guard of bosses — plus:
## - the set of the recorded cell (kind and open doors from the floor layout; a gate counts as open once opened;
##   closed for bosses, the tutorial and can_flee = false), RtGeo.make_geo;
## - party RtUnits from Progression.to_combatant (talent crit / element), ids "p<battle_slot>", display_name = the Def
##   name (never the persona, 08 §2.7 Nr. 5), the recorded poses, party.json rt (radius, speed, threat, auto-attack,
##   MP regeneration, keep / follow distances, the bar by level and loadout — tutorial: slots 1 + 5 of the controlled
##   unit), opener_pm = Talents.preemptive_dmg_pm, stunt_pm = Talents.stunt_window_pm (07 §9.6), tactic and switches
##   (recorded presets, else PartyMember.rt_preset / rt_toggles, else the defaults) with the compiled rules of the
##   tactic (RtRules.preset_rules — the AI partner's, and the autopilot's of the controlled unit);
## - enemies of every recorded group (encounter rt.enemies or its CTB list) while ≤ MAX_ENEMIES (the first group
##   always), ids e0… in group order, enemies.json rt (HP scale, radius, speed, auto-attack, reach, dmg_pm,
##   immunities), the leader at its recorded position (outside the ring: entry to its ring point), the komparsen in
##   formation around the entry point with pop_in_until (07 §2.3, §3.5.5); a group-less combat takes
##   RtGeo.group_anchor;
## - the opening action, auto-attack / retarget switches, tutorial steps, RtBalance.from_data;
## - RtMods in their fixed order (07 §9.5): equipment → species → spec (_rt_member_mods; a unit's unlock_variant
##   mods widen its bar) → show boss (every encounter of the combat's groups, RtMods.from_show_boss) → battle twists
##   (RtMods.from_twists) → Unterhosen-Liga (R5b, E31: _rt_liga_mods), then RtMods.apply_static.
static func make_rt_setup_rules(state: GameState, data: GameData, cmd: Dictionary, seed: int,
		rules: Dictionary) -> RtSetup:
	if state == null or data == null or str(cmd.get("t", "")) != "encounter" or RtCommand.validate(cmd) != "":
		push_warning("[BattleBridge] make_rt_setup: not a real-time encounter command")
		return null
	var enc_id: String = str(cmd.get("enc", ""))
	if not data.has_id("encounters", enc_id):
		push_warning("[BattleBridge] unknown encounter '%s'" % enc_id)
		return null
	var enc: EncounterDef = data.encounter(enc_id)
	var rt: Dictionary = cmd["rt"]
	var bal: RtBalance = RtBalance.from_data(data)
	var s: RtSetup = RtSetup.new()
	s.encounter_id = enc_id
	s.group_id = str(cmd.get("group", ""))
	s.seed = seed
	s.is_boss = enc.boss
	s.can_flee = enc.can_flee
	s.tutorial = enc.tutorial
	s.advantage = BattleSetup.Advantage.NORMAL if enc.boss else _advantage(JsonUtil.to_int(cmd.get("adv", 0)))
	var op: String = str(cmd.get("opener", ""))
	s.opener = op if s.advantage == BattleSetup.Advantage.PREEMPTIVE and BattleSetup.OPENERS.has(op) else ""
	var vorabend: bool = str(rt.get("diff", "prime")) == "vorabend"
	s.difficulty = &"vorabend" if vorabend else &"prime"
	s.enemy_dmg_mult = (Balance.EASY_ENEMY_DMG if vorabend else 1.0) \
		* (Balance.TUTORIAL_ENEMY_DMG if enc.tutorial else 1.0)
	s.exp_mult = Balance.EASY_EXP if vorabend else 1.0
	s.show_mods = {"hype_gain_mult": state.hype_gain_mult(data), "follower_mult": state.follower_mult(data)}
	s.floor_index = state.floor_run.index if state.floor_run != null else maxi(1, enc.floor_index)
	var fdef: FloorDef = data.floor_def(s.floor_index)
	if fdef != null:
		s.theme_id = fdef.theme
		s.palette = fdef.palette.duplicate(true)
	if state.inventory != null:
		s.items = state.inventory.battle_items(data)
		s.credits_available = state.inventory.credits
	s.owned_equipment = _owned_equipment(state, data)
	s.balance = bal
	if rules.get("combat", null) is Dictionary:
		s.rules = {"combat": (rules["combat"] as Dictionary).duplicate(true)}
	var cell: Vector2i = Vector2i(int((rt["cell"] as Array)[0]), int((rt["cell"] as Array)[1]))
	var info: Array = _rt_cell(state, data, cell, enc)
	if int(info[0]) == RoomCell.Kind.STAIRS:
		push_warning("[BattleBridge] make_rt_setup: the stairs room has no set (07 §2.4)")
		return null
	s.cell = cell
	s.room_kind = int(info[0])
	s.geo = RtGeo.make_geo(s.room_kind, int(info[1]), enc.boss or enc.tutorial or not enc.can_flee, bal)
	if not (enc.rt.get("blockers", []) as Array).is_empty():     # R4: the set pieces of the stage (07 §3.5.4, §6.7)
		s.geo["blockers"] = (enc.rt["blockers"] as Array).duplicate(true)
	var mods: Array[Dictionary] = _rt_member_mods(state, data)
	s.mods = mods
	_rt_party(s, state, data, rt, rules, enc, bal)
	_rt_enemies(s, data, rt, rules, enc, bal)
	s.presets = {}
	for u: RtUnit in s.units:
		if u.side == Combatant.Side.PARTY and u.id != s.controlled_id:
			s.presets[u.id] = {"preset": u.preset, "tog": u.toggles.duplicate()}
	s.rt_opener = (rt.get("open", {}) as Dictionary).duplicate(true)
	s.auto_attack = bool(rt.get("auto", true))
	s.auto_retarget = bool(rt.get("retarget", true))
	s.tutorial_steps = PackedStringArray(enc.rt.get("tutorial", []))
	var seen: Dictionary = {}
	for g: Dictionary in s.groups:
		var gid: String = str(g.get("encounter_id", ""))
		if not seen.has(gid) and data.has_id("encounters", gid):
			seen[gid] = true
			mods.append_array(RtMods.from_show_boss(data.encounter(gid)))
	mods.append_array(RtMods.from_twists(_battle_twists(state), data))
	mods.append_array(_rt_liga_mods(state, data, 0 if enc.tutorial else MarottenRules.liga_tier(state, rules)))
	s.mods = mods
	RtMods.apply_static(s, data)
	if enc.boss and bool(state.flags.get(PEP_TALK_FLAG, false)) and data.has_id("statuses", PEP_TALK_STATUS):
		var guard: StatusDef = data.status(PEP_TALK_STATUS)
		var ms: int = int(guard.rt.get("default_ms", 3000))
		for u: RtUnit in s.units:
			if u.side == Combatant.Side.PARTY:
				u.statuses.append(RtStatus.new(guard, ms * 3 / 100 if ms > 0 else -1, u.id))
		state.flags.erase(PEP_TALK_FLAG)
	return s


## [RoomCell.Kind, open door bits] of the set cell: from the current floor layout (a gate is a closed door until it is
## opened); without a floor run / layout cell: FLOOR_BOSS for bosses, else NORMAL, no doors.
static func _rt_cell(state: GameState, data: GameData, cell: Vector2i, enc: EncounterDef) -> Array:
	var fr: FloorRun = state.floor_run
	var fdef: FloorDef = data.floor_def(fr.index) if fr != null else null
	if fdef != null:
		var layout: FloorLayout = DungeonGenerator.generate(fdef, fr.seed)
		var rc: RoomCell = layout.cell_at(cell) if layout != null else null
		if rc != null:
			var doors: int = 0
			for d: int in RoomCell.DIR_BITS:
				if (rc.doors & d) == 0:
					continue
				var g: Dictionary = layout.gate_at(cell, d)
				if g.is_empty() or fr.opened_gates.has(str(g.get("key", ""))):
					doors |= d
			return [int(rc.kind), doors]
	return [RoomCell.Kind.FLOOR_BOSS if enc.boss else RoomCell.Kind.NORMAL, 0]


## Party RtUnits (07 §4.8, §5.1, §9.6) in battle_slot order.
static func _rt_party(s: RtSetup, state: GameState, data: GameData, rt: Dictionary, rules: Dictionary,
		enc: EncounterDef, bal: RtBalance) -> void:
	var poses: Dictionary = {}
	for p: Variant in (rt.get("party", []) as Array):
		poses[str((p as Dictionary).get("u", ""))] = (p as Dictionary).get("p", [0, 0, 0])
	var hero_id: String = ""
	var liga_tier: int = 0 if enc.tutorial else MarottenRules.liga_tier(state, rules)
	var members: Array[PartyMember] = []
	for m: PartyMember in state.party:
		if m != null and data.has_id("party", m.id):
			members.append(m)
	members.sort_custom(func(a: PartyMember, b: PartyMember) -> bool:
		return data.party_member(a.id).battle_slot < data.party_member(b.id).battle_slot)
	var ctl: String = str(rt.get("ctl", ""))
	var party: Array[Combatant] = []
	for m: PartyMember in members:
		var def: PartyMemberDef = data.party_member(m.id)
		var uid: String = "p%d" % def.battle_slot
		if m.id == state.hero:
			hero_id = uid
		var c: Combatant = Progression.to_combatant(m, data, uid, def.battle_slot,
			MarottenRules.in_liga(state, m.id, liga_tier))
		if c == null:
			continue
		var u: RtUnit = RtUnit.from_combatant(c)
		u.display_name = def.name
		var pose: Array = poses.get(uid, [0, 0, 0])
		u.x = int(pose[0])
		u.z = int(pose[1])
		u.yaw = posmod(int(pose[2]), 256)
		_rt_party_fields(u, m, def, data, bal, rt.get("presets", {}), s.mods)
		_rt_species_unit(u, m, state, data)
		party.append(u)
		s.units.append(u)
	s.party = party
	s.controlled_id = ctl if poses.has(ctl) or _has_unit(s, ctl) else hero_id
	if not _has_unit(s, s.controlled_id) and not s.units.is_empty():
		s.controlled_id = s.units[0].id
	for u: RtUnit in s.units:
		var own: bool = u.id == s.controlled_id
		u.driver = RtUnit.Driver.PLAYER if own else RtUnit.Driver.AI
		if own:
			u.auto_on = bool(rt.get("auto", true))
			if enc.tutorial:
				for slot: int in u.bar.keys():
					if slot != 1 and slot != 5:
						u.bar.erase(slot)


static func _rt_party_fields(u: RtUnit, m: PartyMember, def: PartyMemberDef, data: GameData, bal: RtBalance,
		presets: Variant, mods: Array[Dictionary]) -> void:
	var prt: Dictionary = def.rt
	u.radius = int(prt.get("radius_cm", 40))
	u.move_cm_tick = int(prt.get("move_cm_s", 540)) / 30
	u.threat_pm = int(prt.get("threat_pm", 1000))
	u.auto_skill = str(prt.get("auto_skill", ""))
	u.swing_ticks = maxi(1, int(prt.get("swing_ms", 2000)) * 3 / 100)
	u.reach = int(prt.get("reach_cm", 250))
	u.follow_cm = int(prt.get("follow_cm", 600))
	u.swing_ready = 0
	var rec: Dictionary = (presets as Dictionary).get(u.id, {}) if presets is Dictionary else {}
	var preset: String = str(rec.get("preset", m.rt_preset if m.rt_preset != "" else prt.get("default_preset",
		"attack")))
	u.preset = preset if RtVocab.RT_PRESETS.has(preset) else "attack"
	var tog: Dictionary = RtVocab.RT_TOGGLE_DEFAULTS.duplicate()
	var src: Dictionary = rec.get("tog", m.rt_toggles) if rec.get("tog", m.rt_toggles) is Dictionary else {}
	for k: String in RtVocab.RT_TOGGLES:
		if src.has(k):
			tog[k] = bool(src[k])
	u.toggles = tog
	u.keep_cm = clampi(int((prt.get("keep_cm", {}) as Dictionary).get(u.preset, 0)), 0, 700)
	u.rules = RtRules.preset_rules(prt, u.preset)
	var mpr: Dictionary = prt.get("mp_regen", {})
	u.mp_regen = {"mode": str(mpr.get("mode", "time")), "amount": int(mpr.get("amount", 0)),
		"taken": int(mpr.get("taken", 0)), "taken_every_ticks": int(mpr.get("taken_every_ms", 0)) * 3 / 100,
		"every_ticks": int(mpr.get("every_ms", 0)) * 3 / 100}
	u.mp_regen_next = int(u.mp_regen["every_ticks"])
	u.mp_hit_ready = 0
	u.move_budget = bal.i("MOVE_BUDGET_MM")
	var unlocked: Dictionary = {}
	for md: Dictionary in mods:
		if str(md.get("op", "")) == "unlock_variant" and RtMods.applies(md, u):
			unlocked[str(md.get("skill", ""))] = JsonUtil.to_int(md.get("slot", 0))
	u.bar = _rt_bar(prt, m, unlocked)
	u.opener_pm = Talents.preemptive_dmg_pm(m, data)
	u.stunt_pm = Talents.stunt_window_pm(m, data)


## party.json rt.bar (07 §4.1): the base ability of each slot reached by the level, a chosen variant
## (PartyMember.rt_loadout "2".."4") once its level is reached — or unlocked by an RtMods unlock_variant (`unlocked`:
## skill → slot, 07 §9.5); FINALE and context variants stay out (the sim shows them in RtSim.bar).
static func _rt_bar(prt: Dictionary, m: PartyMember, unlocked: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {}
	var variants: Dictionary = {}
	for b: Variant in (prt.get("bar", []) as Array):
		var e: Dictionary = b
		var free: bool = bool(e.get("variant", false)) and int(unlocked.get(str(e.get("skill", "")), -1)) \
			== int(e.get("slot", 0))
		if (int(e.get("level", 1)) > m.level and not free) or bool(e.get("finale", false)):
			continue
		if bool(e.get("variant", false)):
			variants[str(e.get("skill", ""))] = int(e.get("slot", 0))
		elif not out.has(int(e.get("slot", 0))):
			out[int(e.get("slot", 0))] = str(e.get("skill", ""))
	for k: Variant in m.rt_loadout.keys():
		var sid: String = str(m.rt_loadout[k])
		if variants.has(sid) and int(variants[sid]) == str(k).to_int():
			out[str(k).to_int()] = sid
	return out


## Enemy RtUnits of every recorded group (07 §2.3, §3.5.5, §4.9).
static func _rt_enemies(s: RtSetup, data: GameData, rt: Dictionary, rules: Dictionary, enc: EncounterDef,
		bal: RtBalance) -> void:
	var groups: Array = (rt.get("groups", []) as Array).duplicate(true)
	if groups.is_empty():
		var ctl_pose: Array = [0, 0, 0]
		for p: Variant in (rt.get("party", []) as Array):
			if str((p as Dictionary).get("u", "")) == s.controlled_id:
				ctl_pose = (p as Dictionary).get("p", [0, 0, 0])
		var anchor: Vector2i = RtGeo.group_anchor(s.geo, int(ctl_pose[0]), int(ctl_pose[1]))
		var yaw: int = DetMath.yaw_of(-anchor.x, -anchor.y)
		groups.append({"group": s.group_id, "enc": enc.id, "lead": [anchor.x, anchor.y, yaw], "state": "IDLE"})
	var cap: int = int((rules.get("combat", {}) as Dictionary).get("max_enemies", bal.i("MAX_ENEMIES"))) \
		if rules.get("combat", null) is Dictionary else bal.i("MAX_ENEMIES")
	var n: int = 0
	for gi in groups.size():
		var g: Dictionary = groups[gi]
		var genc_id: String = str(g.get("enc", ""))
		if not data.has_id("encounters", genc_id):
			continue
		var genc: EncounterDef = data.encounter(genc_id)
		var ids: PackedStringArray = PackedStringArray(genc.rt.get("enemies", [])) if not genc.rt.is_empty() \
			and not (genc.rt.get("enemies", []) as Array).is_empty() else genc.enemies.duplicate()
		if gi > 0 and n + ids.size() > cap:
			continue
		var lead: Array = g.get("lead", [0, 0, 0])
		var yaw_l: int = posmod(int(lead[2]), 256)
		var unit_ids: Array = []
		var entry: Array[int] = []
		var anchor_p: Vector2i = Vector2i(int(lead[0]), int(lead[1]))
		for k in ids.size():
			if not data.has_id("enemies", ids[k]):
				continue
			var u: RtUnit = RtUnit.from_enemy(data.enemy(ids[k]), "e%d" % n, n, bal)
			u.yaw = yaw_l
			if unit_ids.is_empty():
				u.x = int(lead[0])
				u.z = int(lead[1])
				if not RtGeo.walkable(s.geo, u.x, u.z, u.radius, false):
					var q: Vector2i = RtGeo.project_walkable(s.geo, u.x, u.z, u.radius, false)
					entry.assign([q.x, q.y])
					anchor_p = q
					u.entry = entry.duplicate()
			else:
				var f: Vector2i = RtGeo.formation(unit_ids.size(), anchor_p.x, anchor_p.y, yaw_l)
				var p: Vector2i = RtGeo.project_walkable(s.geo, f.x, f.y, u.radius, false)
				u.x = p.x
				u.z = p.y
				u.pop_in_until = bal.i("POP_IN_TICKS") + (bal.i("ENTER_MAX_TICKS") if not entry.is_empty() else 0)
			unit_ids.append(u.id)
			s.units.append(u)
			n += 1
		if unit_ids.is_empty():
			continue
		if s.enemy_ids.is_empty():
			s.enemy_ids = ids
		s.groups.append({"group_id": str(g.get("group", "")), "encounter_id": genc_id, "enemy_ids": Array(ids),
			"lead": [int(lead[0]), int(lead[1]), yaw_l], "state": str(g.get("state", "")), "entry": Array(entry),
			"units": unit_ids})


static func _has_unit(s: RtSetup, id: String) -> bool:
	for u: RtUnit in s.units:
		if u.id == id:
			return true
	return false


## The active battle twists (06 §5.6, 07 §9.5): GameState.flags.live.twist.active entries counting battles with
## battles left, in stored order — RtMods.from_twists maps them.
static func _battle_twists(state: GameState) -> Array:
	var out: Array = []
	var live: Variant = state.flags.get("live", {})
	var tw: Variant = (live as Dictionary).get("twist", {}) if live is Dictionary else {}
	var active: Variant = (tw as Dictionary).get("active", []) if tw is Dictionary else []
	if active is Array:
		for e: Variant in (active as Array):
			if e is Dictionary and str((e as Dictionary).get("unit", "")) == "battles" \
					and JsonUtil.to_int((e as Dictionary).get("left", 0)) > 0:
				out.append((e as Dictionary).duplicate(true))
	return out


## RtMods of the party members (07 §9.5) in the fixed order equipment → species → spec: equipment carries none yet
## (items.json rt has only "wheel"; equipment acts through the Combatant values), species passives map as proposed in
## 07 §9.6 (_rt_species_mods; built with floor 3), specialisations (classes) have no real-time mapping yet (their
## passives are CTB rules; unlock_variant waits for data). Members in battle_slot order.
static func _rt_member_mods(state: GameState, data: GameData) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var members: Array[PartyMember] = []
	for m: PartyMember in state.party:
		if m != null and data.has_id("party", m.id):
			members.append(m)
	members.sort_custom(func(a: PartyMember, b: PartyMember) -> bool:
		return data.party_member(a.id).battle_slot < data.party_member(b.id).battle_slot)
	for m: PartyMember in members:
		out.append_array(_rt_species_mods(m, "p%d" % data.party_member(m.id).battle_slot, data))
	return out


## Unterhosen-Liga in the real-time combat (R5b, E31, 06 §4.3): every Liga member at `tier` (MarottenRules.in_liga,
## frozen at the combat start, never the tutorial) is "leichtfüßig" — on combat_start the status LIGHT_FOOTED for the
## whole combat (move_pm 1080: 8 % faster; ai_miss_pm 750: as a sim-driven unit it overlooks a quarter fewer
## telegraphs; flag "keep": it survives a KO). Nothing when the data have no such status (fixtures).
static func _rt_liga_mods(state: GameState, data: GameData, tier: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if tier <= 0 or not data.has_id("statuses", LIGHT_FOOTED):
		return out
	var members: Array[PartyMember] = []
	for m: PartyMember in state.party:
		if m != null and data.has_id("party", m.id) and MarottenRules.in_liga(state, m.id, tier):
			members.append(m)
	members.sort_custom(func(a: PartyMember, b: PartyMember) -> bool:
		return data.party_member(a.id).battle_slot < data.party_member(b.id).battle_slot)
	for m: PartyMember in members:
		out.append({"src": "liga:mar_unterhose", "op": "on", "unit": "p%d" % data.party_member(m.id).battle_slot,
			"event": "combat_start", "effect": {"status": LIGHT_FOOTED, "ms": -1}})
	return out


## The species passive of a member as RtMods (07 §9.6 proposal): pas_grout / pas_see_through → first_hit_taken_pm
## (params.first_hit_taken_pm), pas_coin_slot → skill_pm "item:*" power (params.consumable_pm), pas_ember → skill_pm
## "element:fire" power (params.fire_skill_pm), pas_court_flight → on combat_start sts_haste 3 s, pas_spores (R4) →
## on combat_start sts_spores for the whole combat (+1 % max HP every 3 s; its poison immunity is a unit field, see
## _rt_species_unit). pas_authentic (Show only) and pas_lightdrunk (a unit field) map to no mod.
static func _rt_species_mods(m: PartyMember, uid: String, data: GameData) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if m.species_id == "" or not data.has_id("species", m.species_id):
		return out
	var sp: SpeciesDef = data.species_def(m.species_id)
	var params: Dictionary = sp.passive.get("params", {}) if sp.passive.get("params", {}) is Dictionary else {}
	var src: String = "species:" + sp.id
	match str(sp.passive.get("id", "")):
		"pas_grout", "pas_see_through":
			out.append({"src": src, "op": "first_hit_taken_pm", "unit": uid,
				"pm": JsonUtil.to_int(params.get("first_hit_taken_pm", 1000), 1000)})
		"pas_coin_slot":
			out.append({"src": src, "op": "skill_pm", "unit": uid, "skill": "item:*", "field": "power",
				"pm": JsonUtil.to_int(params.get("consumable_pm", 1000), 1000)})
		"pas_ember":
			out.append({"src": src, "op": "skill_pm", "unit": uid, "skill": "element:fire", "field": "power",
				"pm": JsonUtil.to_int(params.get("fire_skill_pm", 1000), 1000)})
		"pas_court_flight":
			out.append({"src": src, "op": "on", "unit": uid, "event": "combat_start",
				"effect": {"status": "sts_haste", "ms": 3000}})
		"pas_spores":
			if data.has_id("statuses", "sts_spores"):
				out.append({"src": src, "op": "on", "unit": uid, "event": "combat_start",
					"effect": {"status": "sts_spores", "ms": -1}})
	return out


## The species passives that act on unit fields (07 §9.6, R4): pas_spores → its params.status_immune join the unit's
## immunities (Pilzling: poison); pas_lightdrunk → + params.crit_add_pm ‰ crit while the show's hype stands at
## params.min_hype or more at the start of the combat (Neonfalter: +10 % from hype 70; frozen for the combat like the
## Liga tier). Pure function of the state at the start → the same setup live, in the replay and in the verifier.
static func _rt_species_unit(u: RtUnit, m: PartyMember, state: GameState, data: GameData) -> void:
	if m.species_id == "" or not data.has_id("species", m.species_id):
		return
	var sp: SpeciesDef = data.species_def(m.species_id)
	var params: Dictionary = sp.passive.get("params", {}) if sp.passive.get("params", {}) is Dictionary else {}
	match str(sp.passive.get("id", "")):
		"pas_spores":
			for sid: String in JsonUtil.to_str_array(params.get("status_immune", [])):
				if not u.status_immune.has(sid):
					u.status_immune.append(sid)
		"pas_lightdrunk":
			var hype: int = int(state.show.hype) if state.show != null else 0
			if hype >= JsonUtil.to_int(params.get("min_hype", 101), 101):
				u.crit_bonus += float(JsonUtil.to_int(params.get("crit_add_pm", 0))) / 1000.0


## After every combat (apply_result, live and replay alike): the out-of-combat regeneration counts from 0 again
## (07 §2.7; CTB runs never count, the field stays 0 there).
static func _rt_after_combat(state: GameState) -> void:
	if state.floor_run != null:
		state.floor_run.regen_ticks = 0


## R5b (07 §5.2, §12.2 "Stand R5a" Nr. 9): a partner tactic changed during a real-time combat is kept — the member's
## rt_preset / rt_toggles become the tactic of BattleResult.rt_presets (its known switches, as RunRules.apply_loadout
## stores them). Deterministic from the result, so the live game and both verifiers write the same; no log entry.
static func write_presets(state: GameState, result: BattleResult) -> void:
	var ids: Array = result.rt_presets.keys()
	ids.sort()
	for id: Variant in ids:
		var m: PartyMember = state.member(str(id))
		var e: Dictionary = result.rt_presets[id]
		if m == null:
			continue
		var preset: String = str(e.get("preset", ""))
		m.rt_preset = preset if RtVocab.RT_PRESETS.has(preset) else m.rt_preset
		var tog: Dictionary = {}
		var src: Dictionary = e.get("tog", {}) as Dictionary
		for k: String in RtVocab.RT_TOGGLES:
			if src.has(k):
				tog[k] = bool(src[k])
		m.rt_toggles = tog
