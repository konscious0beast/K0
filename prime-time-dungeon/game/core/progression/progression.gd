class_name Progression extends RefCounted
## EXP curve, level-up, stats, equipment, field item use (02_TECH §6.1, GDD §4).
##
## Integer arithmetic only (05 §3.3 Nr. 5, CR-12): the EXP curve is a precomputed table, growth values are applied in
## per-mille, class multipliers round half up. StatBlocks are built by setting `values` directly.

## exp_to_next(level) for level 1..9 = floori(18 × level^1.7 + 15) (GDD §4.3; table instead of pow, CR-12).
const EXP_TABLE: PackedInt32Array = [33, 73, 131, 205, 292, 393, 506, 632, 769]
const _EQUIP_SLOTS: PackedStringArray = ["weapon", "armor", "accessory"]
const _PM: int = 1000


## level >= Balance.LEVEL_CAP → 0; else floori(18.0 × level^1.7 + 15.0) (EXP_TABLE; beyond it the last entry).
static func exp_to_next(level: int) -> int:
	if level >= Balance.LEVEL_CAP:
		return 0
	var i: int = clampi(level, 1, EXP_TABLE.size()) - 1
	return EXP_TABLE[i]


## floori(base + (growth + growth_add) × (level − 1)) per stat (GDD §4.1).
static func base_stats_at(def: PartyMemberDef, level: int, class_def: ClassDef = null) -> StatBlock:
	var vals: PackedInt32Array = []
	vals.resize(StatBlock.KEYS.size())
	if def == null:
		return _block(vals)
	var steps: int = maxi(0, level - 1)
	for i in StatBlock.KEYS.size():
		var key: String = StatBlock.KEYS[i]
		var growth_pm: int = roundi(float(def.growth.get(key, 0.0)) * _PM)
		if class_def != null:
			growth_pm += roundi(float(class_def.growth_add.get(key, 0.0)) * _PM)
		# growth / growth_add are >= 0 (validator), so integer division is floori
		vals[i] = int(def.base_stats.get(key, 0)) + maxi(0, growth_pm) * steps / _PM
	return _block(vals)


## Level stats + equipment stats, × class stat_mult (round half up). HP >= 1, other stats >= 0.
static func total_stats(member: PartyMember, data: GameData) -> StatBlock:
	var vals: PackedInt32Array = []
	vals.resize(StatBlock.KEYS.size())
	if member == null or data == null or not data.has_id("party", member.id):
		return _block(vals)
	var def: PartyMemberDef = data.party_member(member.id)
	var cls: ClassDef = _class_of(member, data)
	vals = base_stats_at(def, member.level, cls).values.duplicate()
	for item_id: String in _equipped(member, data):
		var item: ItemDef = data.item(item_id)
		for key: Variant in item.stats.keys():
			var i: int = StatBlock.KEYS.find(str(key))
			if i >= 0:
				vals[i] += JsonUtil.to_int(item.stats[key])
	if cls != null:
		for key: Variant in cls.stat_mult.keys():
			var i: int = StatBlock.KEYS.find(str(key))
			if i >= 0:
				var mult_pm: int = roundi(float(cls.stat_mult[key]) * _PM)
				vals[i] = (maxi(0, vals[i]) * mult_pm + _PM / 2) / _PM
	for i in vals.size():
		vals[i] = maxi(1 if i == StatBlock.Stat.HP else 0, vals[i])
	return _block(vals)


## Level up raises hp/mp by the max delta (no full heal; a KO'd member stays at 0 HP); at LEVEL_CAP surplus EXP is
## discarded. Returns one LevelUpInfo spanning all levels gained (empty if none).
static func add_exp(member: PartyMember, amount: int, data: GameData) -> Array[LevelUpInfo]:
	var out: Array[LevelUpInfo] = []
	if member == null or amount <= 0:
		return out
	if member.level >= Balance.LEVEL_CAP:
		member.exp = 0
		return out
	var old_level: int = member.level
	var before: StatBlock = total_stats(member, data)
	member.exp += amount
	while member.level < Balance.LEVEL_CAP:
		var need: int = exp_to_next(member.level)
		if need <= 0 or member.exp < need:
			break
		member.exp -= need
		member.level += 1
	if member.level >= Balance.LEVEL_CAP:
		member.exp = 0
	if member.level == old_level:
		return out
	var after: StatBlock = total_stats(member, data)
	var info: LevelUpInfo = LevelUpInfo.new()
	info.member_id = member.id
	info.old_level = old_level
	info.new_level = member.level
	for i in StatBlock.KEYS.size():
		info.stat_gains[StatBlock.KEYS[i]] = after.values[i] - before.values[i]
	var hp_delta: int = after.values[StatBlock.Stat.HP] - before.values[StatBlock.Stat.HP]
	var mp_delta: int = after.values[StatBlock.Stat.MP] - before.values[StatBlock.Stat.MP]
	if member.hp > 0:
		member.hp = clampi(member.hp + hp_delta, 1, after.values[StatBlock.Stat.HP])
	member.mp = clampi(member.mp + mp_delta, 0, after.values[StatBlock.Stat.MP])
	for skill_id: String in _learnset_between(member, data, old_level, member.level):
		if not member.skills.has(skill_id):
			member.skills.append(skill_id)
			info.learned.append(skill_id)
	out.append(info)
	return out


## "" unequips (item back into the inventory). Item must be in the inventory, of the slot's type and allowed by
## equip_by; the replaced item goes back into the inventory. HP/MP are clamped to the new maximum. false = no change.
static func equip(member: PartyMember, inventory: Inventory, data: GameData, slot: String, item_id: String) -> bool:
	if member == null or inventory == null or data == null or not _EQUIP_SLOTS.has(slot):
		return false
	var current: String = str(member.equipment.get(slot, ""))
	if item_id == "":
		if current == "":
			return false
		if inventory.add(current, 1, _max_stack(data, current)) != 1:
			return false
		member.equipment[slot] = ""
		_clamp_vitals(member, data)
		return true
	if item_id == current or not data.has_id("items", item_id):
		return false
	var def: ItemDef = data.item(item_id)
	if def.type != slot or (not def.equip_by.is_empty() and not def.equip_by.has(member.id)):
		return false
	if not inventory.remove(item_id, 1):
		return false
	if current != "" and inventory.add(current, 1, _max_stack(data, current)) != 1:
		inventory.add(item_id, 1, def.max_stack)
		return false
	member.equipment[slot] = item_id
	_clamp_vitals(member, data)
	return true


## Full HP/MP for every member (safe room, rest). Statuses only exist in battle.
static func full_heal(state: GameState, data: GameData) -> void:
	if state == null:
		return
	for m: PartyMember in state.party:
		if m == null:
			continue
		var sb: StatBlock = total_stats(m, data)
		m.hp = sb.values[StatBlock.Stat.HP]
		m.mp = sb.values[StatBlock.Stat.MP]


## Field use (inventory menu via Game.use_item): item with usable "field"/"both" and count > 0; applies its
## use_skill to the member outside battle (heal by heal_mode without variance/crit, cleanse, mp_restore /
## mp_restore_pct, revive only for target single_ally_ko) and removes 1 item. false (nothing changes) if not usable.
## Targets all_allies apply to every member. Statuses do not exist outside battle (cleanse alone changes nothing).
static func use_item(state: GameState, data: GameData, item_id: String, member_id: String) -> bool:
	if state == null or data == null or state.inventory == null or not data.has_id("items", item_id):
		return false
	var item: ItemDef = data.item(item_id)
	if item.type != "consumable" or (item.usable != "field" and item.usable != "both"):
		return false
	if not state.inventory.has(item_id) or not data.has_id("skills", item.use_skill):
		return false
	var skill: SkillDef = data.skill(item.use_skill)
	var targets: Array[PartyMember] = []
	match skill.target:
		"all_allies":
			for m: PartyMember in state.party:
				if m != null:
					targets.append(m)
		"single_ally", "single_ally_ko", "self":
			var t: PartyMember = state.member(member_id)
			if t != null:
				targets.append(t)
	var changed: bool = false
	for m: PartyMember in targets:
		if _apply_field_skill(m, skill, data):
			changed = true
	if changed:
		state.inventory.remove(item_id, 1)
	return changed


## crit_bonus = Σ equipment crit_bonus; element_mods = Π; status_immune = ∪; status_resist from def;
## attack_element from weapon.
static func to_combatant(member: PartyMember, data: GameData, id: String, slot: int) -> Combatant:
	if member == null or data == null or not data.has_id("party", member.id):
		return null
	var def: PartyMemberDef = data.party_member(member.id)
	var stats: StatBlock = total_stats(member, data)
	var max_hp: int = stats.values[StatBlock.Stat.HP]
	var max_mp: int = stats.values[StatBlock.Stat.MP]
	var hp: int = clampi(member.hp, 0, max_hp)
	var mp: int = clampi(member.mp, 0, max_mp)
	var element_mods: Dictionary = def.element_mods.duplicate(true)
	var immune: PackedStringArray = def.status_immune.duplicate()
	var crit: float = 0.0
	var attack_element: String = "physical"
	for item_id: String in _equipped(member, data):
		var item: ItemDef = data.item(item_id)
		crit += item.crit_bonus
		for el: Variant in item.element_mods.keys():
			element_mods[str(el)] = float(element_mods.get(str(el), 1.0)) * float(item.element_mods[el])
		for s: String in item.status_immune:
			if not immune.has(s):
				immune.append(s)
		if item.type == "weapon" and item.attack_element != "":
			attack_element = item.attack_element
	var skills: PackedStringArray = member.skills.duplicate()
	var stunts: PackedStringArray = def.stunts.duplicate()
	var c: Combatant = Combatant.create_party(def, id, slot, member.display_name, member.level, stats, hp, mp, skills,
		stunts, def.attack_skill, element_mods, immune, attack_element, crit)
	if c == null:
		c = Combatant.new()
		c.id = id
		c.def_id = def.id
		c.side = Combatant.Side.PARTY
		c.is_pseudo = false
		c.slot = slot
		c.display_name = member.display_name
		c.level = member.level
		c.stats = stats
		c.hp = hp
		c.mp = mp
		c.attack_skill = def.attack_skill
		c.skills = skills
		c.stunts = stunts
		c.element_mods = element_mods
		c.status_immune = immune
		c.attack_element = attack_element
		c.crit_bonus = crit
		c.model = def.model.duplicate(true)
	c.status_resist = def.status_resist.duplicate(true)
	return c


# --- helpers ----------------------------------------------------------------------------------------------------------

static func _block(vals: PackedInt32Array) -> StatBlock:
	var sb: StatBlock = StatBlock.new()
	sb.values = vals
	return sb


static func _class_of(member: PartyMember, data: GameData) -> ClassDef:
	if member.class_id == "" or not data.has_id("classes", member.class_id):
		return null
	return data.class_def(member.class_id)


## Known equipped item ids in slot order.
static func _equipped(member: PartyMember, data: GameData) -> PackedStringArray:
	var out: PackedStringArray = []
	for slot: String in _EQUIP_SLOTS:
		var item_id: String = str(member.equipment.get(slot, ""))
		if item_id != "" and data.has_id("items", item_id):
			out.append(item_id)
	return out


static func _max_stack(data: GameData, item_id: String) -> int:
	return data.item(item_id).max_stack if data.has_id("items", item_id) else 9


static func _clamp_vitals(member: PartyMember, data: GameData) -> void:
	var sb: StatBlock = total_stats(member, data)
	member.hp = mini(member.hp, sb.values[StatBlock.Stat.HP])
	member.mp = mini(member.mp, sb.values[StatBlock.Stat.MP])


## Skills of the member's learnset (+ class learnset, known skills only) with old < level <= new, in data order.
static func _learnset_between(member: PartyMember, data: GameData, old_level: int, new_level: int) -> PackedStringArray:
	var out: PackedStringArray = []
	if data == null or not data.has_id("party", member.id):
		return out
	var sets: Array[Array] = [data.party_member(member.id).learnset]
	var cls: ClassDef = _class_of(member, data)
	if cls != null:
		sets.append(cls.learnset)
	for learnset: Array in sets:
		for entry: Variant in learnset:
			var e: Dictionary = entry
			var lv: int = int(e.get("level", 0))
			var skill_id: String = str(e.get("skill", ""))
			if lv > old_level and lv <= new_level and data.has_id("skills", skill_id) and not out.has(skill_id):
				out.append(skill_id)
	return out


## One field-use effect on one member; true if anything changed.
static func _apply_field_skill(m: PartyMember, skill: SkillDef, data: GameData) -> bool:
	var sb: StatBlock = total_stats(m, data)
	var max_hp: int = sb.values[StatBlock.Stat.HP]
	var max_mp: int = sb.values[StatBlock.Stat.MP]
	var hp0: int = m.hp
	var mp0: int = m.mp
	var revive: bool = skill.target == "single_ally_ko"
	if revive != (m.hp <= 0):
		return false   # revive items only on KO'd members, everything else only on living ones
	if skill.damage_type == "heal":
		var amount: int = 0
		match skill.heal_mode:
			"mag":
				amount = ((sb.values[StatBlock.Stat.MAG] * 15 + 100) * skill.power + 500) / 1000
			"pct":
				amount = (max_hp * skill.power + 50) / 100
			"fixed":
				amount = skill.power
		if revive:
			m.hp = clampi(amount, 1, max_hp)
		else:
			m.hp = clampi(m.hp + maxi(0, amount), 0, max_hp)
	var mp_gain: int = maxi(0, skill.mp_restore) + (max_mp * maxi(0, skill.mp_restore_pct) + 50) / 100
	if mp_gain > 0 and m.hp > 0:
		m.mp = clampi(m.mp + mp_gain, 0, max_mp)
	return m.hp != hp0 or m.mp != mp0
