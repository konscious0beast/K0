# STUB(M0) — owned by M2. Replace completely, keep the public API.
class_name Progression extends RefCounted
## EXP curve, level-up, stats, equipment (02_TECH §6.1, GDD §4).


## level >= Balance.LEVEL_CAP → 0; else floori(15.0 × level^1.7 + 15.0)
static func exp_to_next(level: int) -> int:
	return 0


## floori(base + (growth + growth_add) × (level − 1)) per stat (GDD §4.1).
static func base_stats_at(def: PartyMemberDef, level: int, class_def: ClassDef = null) -> StatBlock:
	return null


## + equipment stats, × class stat_mult.
static func total_stats(member: PartyMember, data: GameData) -> StatBlock:
	return null


## Level up raises hp/mp by the max delta (no full heal); at LEVEL_CAP surplus EXP is discarded.
static func add_exp(member: PartyMember, amount: int, data: GameData) -> Array[LevelUpInfo]:
	return []


## "" unequips.
static func equip(member: PartyMember, inventory: Inventory, data: GameData, slot: String, item_id: String) -> bool:
	return false


static func full_heal(state: GameState, data: GameData) -> void:
	pass


## Field use (inventory menu via Game.use_item): item with usable "field"/"both" and count > 0; applies its
## use_skill to the member outside battle (heal by heal_mode without variance/crit, cleanse, mp_restore /
## mp_restore_pct, revive only for target single_ally_ko) and removes 1 item. false (nothing changes) if not usable.
static func use_item(state: GameState, data: GameData, item_id: String, member_id: String) -> bool:
	return false


## crit_bonus = Σ equipment crit_bonus; element_mods = Π; status_immune = ∪; status_resist from def; attack_element from weapon.
static func to_combatant(member: PartyMember, data: GameData, id: String, slot: int) -> Combatant:
	return null
