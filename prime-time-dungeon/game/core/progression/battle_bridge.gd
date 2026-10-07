class_name BattleBridge extends RefCounted
## GameState ↔ BattleSetup/BattleResult (02_TECH §6.1, GDD §3.12/§10.2).

const PEP_TALK_FLAG: String = "mop_pep_talk"
const PEP_TALK_STATUS: String = "sts_guard"
const PEP_TALK_TURNS: int = 2
const KO_EXP_PCT: int = 50                   # KO'd members get floori(50 %) of the battle EXP


## Party combatants via Progression.to_combatant (ids p0.. in battle_slot order); items = inventory.battle_items;
## credits_available = inventory.credits; encounter: is_boss, can_flee, tutorial; bosses force NORMAL;
## enemy_dmg_mult = (vorabend 0.75) × (tutorial 0.5); exp_mult (vorabend 1.2); show_mods = state.hype_gain_mult /
## follower_mult; floor palette/theme; is_boss and flags["mop_pep_talk"] → both party combatants start with
## sts_guard 2, flag erased (GDD §10.2). Unknown encounter → null.
static func make_setup(state: GameState, data: GameData, encounter_id: String, advantage: int, group_id: String,
		seed: int) -> BattleSetup:
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
	var party: Array[Combatant] = []
	for i in state.party.size():
		var m: PartyMember = state.party[i]
		if m == null or not data.has_id("party", m.id):
			continue
		var c: Combatant = Progression.to_combatant(m, data, "p%d" % party.size(), data.party_member(m.id).battle_slot)
		if c != null:
			party.append(c)
	setup.party = party
	if enc.boss and bool(state.flags.get(PEP_TALK_FLAG, false)) and data.has_id("statuses", PEP_TALK_STATUS):
		var guard: StatusDef = data.status(PEP_TALK_STATUS)
		for c: Combatant in setup.party:
			c.statuses.append(StatusEffect.new(guard, PEP_TALK_TURNS, c.id))
		state.flags.erase(PEP_TALK_FLAG)
	return setup


## hp/mp writeback; KO → 1 HP unless DEFEAT; item_delta → inventory; credits_delta; VICTORY: EXP per member
## (alive full, KO'd floori(50 %)), credits (+overkill), drops, boss_rewards (items → inventory, boxes →
## pending_lootboxes), Werbepause +ceili(max_mp × 0.15) MP for living members, stolen credits refunded;
## FLED/DEFEAT: stolen credits lost; VICTORY: defeated_groups += group_id, strays.erase(group_id), flags defeated_<boss_id> + quarter/floor boss flags;
## bestiary (defeated += 1 per defeated_ids entry, weak_known ∪= weak_found); floor_run.stats.kills += kills;
## VICTORY over FloorDef.timer_start_after → floor_run.timer_started = true.
static func apply_result(state: GameState, data: GameData, result: BattleResult) -> BattleRewards:
	var rw: BattleRewards = BattleRewards.new()
	if state == null or data == null or result == null:
		return rw
	if state.inventory == null:
		state.inventory = Inventory.new()
	var victory: bool = result.outcome == BattleResult.Outcome.VICTORY
	var defeat: bool = result.outcome == BattleResult.Outcome.DEFEAT
	# 1. hp/mp writeback, KO → 1 HP unless DEFEAT
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
			if not defeat:
				m.hp = Balance.KO_REVIVE_HP
				rw.revived.append(m.id)
	# 2. battle inventory changes (used items, gift items) and gift credits
	var delta_ids: Array = result.item_delta.keys()
	delta_ids.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
	for item_id: Variant in delta_ids:
		var n: int = JsonUtil.to_int(result.item_delta[item_id])
		var iid: String = str(item_id)
		if n < 0:
			state.inventory.remove(iid, mini(-n, state.inventory.count(iid)))
		elif n > 0 and data.has_id("items", iid):
			_add_item(state, data, iid, n)
	if result.credits_delta != 0:
		state.inventory.add_credits(result.credits_delta)
	# 3. stolen credits
	if result.credits_stolen > 0:
		if victory:
			rw.credits_refunded = result.credits_stolen
		else:
			rw.credits_lost = mini(result.credits_stolen, state.inventory.credits)
			state.inventory.spend_credits(rw.credits_lost)
	var fr: FloorRun = state.floor_run
	if victory:
		# 4. EXP, credits, drops, boss rewards
		rw.exp = maxi(0, result.exp)
		for m: PartyMember in state.party:
			if m == null:
				continue
			var gain: int = rw.exp * KO_EXP_PCT / 100 if was_ko.has(m.id) else rw.exp
			rw.level_ups.append_array(Progression.add_exp(m, gain, data))
		rw.credits = maxi(0, result.credits)
		rw.overkill_credits = maxi(0, result.overkill_credits)
		state.inventory.add_credits(rw.credits)
		for item_id: String in result.drops:
			if item_id != "" and data.has_id("items", item_id):
				_add_item(state, data, item_id, 1)
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
				_add_item(state, data, rid, amount)
				for _i in amount:
					rw.items.append(rid)
		# 5. "Werbepause": living members (not KO at battle end) +ceili(max_mp × 0.15) MP
		var regen_pct: int = roundi(Balance.POST_BATTLE_MP_REGEN * 100.0)
		for m: PartyMember in state.party:
			if m == null or was_ko.has(m.id):
				continue
			var max_mp: int = Progression.total_stats(m, data).values[StatBlock.Stat.MP]
			var regen: int = (max_mp * regen_pct + 99) / 100
			var before: int = m.mp
			m.mp = mini(max_mp, m.mp + regen)
			rw.mp_regen[m.id] = m.mp - before
		# 6. floor bookkeeping
		if fr != null:
			if result.group_id != "":
				if not fr.defeated_groups.has(result.group_id):
					fr.defeated_groups.append(result.group_id)
				fr.strays.erase(result.group_id)
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
	# 7. bestiary + kills (every outcome)
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
	if fr != null:
		fr.stats["kills"] = int(fr.stats.get("kills", 0)) + maxi(0, result.kills)
	return rw


static func _advantage(advantage: int) -> BattleSetup.Advantage:
	match advantage:
		BattleSetup.Advantage.PREEMPTIVE:
			return BattleSetup.Advantage.PREEMPTIVE
		BattleSetup.Advantage.AMBUSH:
			return BattleSetup.Advantage.AMBUSH
	return BattleSetup.Advantage.NORMAL


## Adds n items; overflow over max_stack becomes credits at sell value (like Game.add_rewards).
static func _add_item(state: GameState, data: GameData, item_id: String, n: int) -> void:
	var def: ItemDef = data.item(item_id)
	var added: int = state.inventory.add(item_id, n, def.max_stack)
	if added < n:
		state.inventory.add_credits((n - added) * def.sell_value())


static func _bestiary_entry(state: GameState, enemy_id: String) -> Dictionary:
	if not state.bestiary.has(enemy_id) or not (state.bestiary[enemy_id] is Dictionary):
		state.bestiary[enemy_id] = {"defeated": 0, "weak_known": PackedStringArray()}
	var entry: Dictionary = state.bestiary[enemy_id]
	if not entry.has("defeated"):
		entry["defeated"] = 0
	entry["weak_known"] = JsonUtil.to_str_array(entry.get("weak_known", []))
	return entry
