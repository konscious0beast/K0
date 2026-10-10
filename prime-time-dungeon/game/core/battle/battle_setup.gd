class_name BattleSetup extends RefCounted
## Input for one battle (02_TECH §5.4). Built by BattleBridge (M2); BattleState never mutates it (it works on copies).

const FixedMath := preload("res://core/stats/fixed_math.gd")

enum Advantage { NORMAL, PREEMPTIVE, AMBUSH }

var encounter_id: String = ""
var group_id: String = ""                    # exploration group ("" for forced/debug)
var enemy_ids: PackedStringArray = []        # 1..4 EnemyDef ids, slot order
var party: Array[Combatant] = []             # built by BattleBridge, ids p0.., current hp/mp, start statuses applied
var items: Dictionary = {}                   # item_id -> count (battle-usable consumables)
var credits_available: int = 0               # party credits (limit for steal_credits)
# equipment ids the party owns (inventory/equipped, sorted): a gift piece of
var owned_equipment: PackedStringArray = []
                                             # one of them becomes credits (ItemDef.duplicate_credits, GDD §9.3)
var advantage: BattleSetup.Advantage = Advantage.NORMAL
var seed: int = 1
var is_boss: bool = false
var can_flee: bool = true
var tutorial: bool = false                   # enemy damage × 0.5, flee locked, party HP never below 1
var enemy_dmg_mult: float = 1.0              # Vorabendprogramm 0.75 × tutorial 0.5
var exp_mult: float = 1.0                    # Vorabendprogramm 1.2
var show_mods: Dictionary = {"hype_gain_mult": 1.0, "follower_mult": 1.0}   # product over equipped items
var theme_id: String = "metro"
var palette: Dictionary = {}
var floor_index: int = 1
var auto_battle: bool = false


## Float-free snapshot (floats as ppm ints, canonical JSON 05 §3.3 Nr. 9); party combatants as Combatant.to_dict().
func to_dict() -> Dictionary:
	var members: Array = []
	for c: Combatant in party:
		members.append(c.to_dict())
	var mods: Dictionary = {}
	for k: Variant in show_mods.keys():
		mods[str(k)] = FixedMath.ppm(float(show_mods[k]))
	var pal: Dictionary = {}
	for k: Variant in palette.keys():
		pal[str(k)] = str(palette[k]) if not (palette[k] is Color) else "#" + (palette[k] as Color).to_html(false)
	var its: Dictionary = {}
	for k: Variant in items.keys():
		its[str(k)] = JsonUtil.to_int(items[k])
	return {
		"encounter_id": encounter_id, "group_id": group_id, "enemy_ids": Array(enemy_ids), "party": members,
		"items": its, "credits_available": credits_available, "owned_equipment": Array(owned_equipment),
		"advantage": int(advantage), "seed": seed,
		"is_boss": is_boss, "can_flee": can_flee, "tutorial": tutorial,
		"enemy_dmg_mult_ppm": FixedMath.ppm(enemy_dmg_mult), "exp_mult_ppm": FixedMath.ppm(exp_mult),
		"show_mods_ppm": mods, "theme_id": theme_id, "palette": pal, "floor_index": floor_index,
		"auto_battle": auto_battle,
	}


static func from_dict(d: Dictionary, data: GameData) -> BattleSetup:
	var s: BattleSetup = BattleSetup.new()
	s.encounter_id = str(d.get("encounter_id", ""))
	s.group_id = str(d.get("group_id", ""))
	s.enemy_ids = JsonUtil.to_str_array(d.get("enemy_ids", []))
	for v: Variant in (d.get("party", []) as Array):
		if v is Dictionary:
			var c: Combatant = Combatant.from_dict(v, data)
			if c != null:
				s.party.append(c)
	var its: Variant = d.get("items", {})
	if its is Dictionary:
		for k: Variant in (its as Dictionary).keys():
			s.items[str(k)] = JsonUtil.to_int((its as Dictionary)[k])
	s.credits_available = JsonUtil.to_int(d.get("credits_available", 0))
	s.owned_equipment = JsonUtil.to_str_array(d.get("owned_equipment", []))
	s.advantage = clampi(JsonUtil.to_int(d.get("advantage", 0)), 0, 2) as BattleSetup.Advantage
	s.seed = JsonUtil.to_int(d.get("seed", 1), 1)
	s.is_boss = bool(d.get("is_boss", false))
	s.can_flee = bool(d.get("can_flee", true))
	s.tutorial = bool(d.get("tutorial", false))
	s.enemy_dmg_mult = FixedMath.from_ppm(JsonUtil.to_int(d.get("enemy_dmg_mult_ppm", FixedMath.PPM)))
	s.exp_mult = FixedMath.from_ppm(JsonUtil.to_int(d.get("exp_mult_ppm", FixedMath.PPM)))
	var mods: Variant = d.get("show_mods_ppm", {})
	if mods is Dictionary:
		for k: Variant in (mods as Dictionary).keys():
			s.show_mods[str(k)] = FixedMath.from_ppm(JsonUtil.to_int((mods as Dictionary)[k]))
	s.theme_id = str(d.get("theme_id", "metro"))
	var pal: Variant = d.get("palette", {})
	if pal is Dictionary:
		s.palette = (pal as Dictionary).duplicate(true)
	s.floor_index = JsonUtil.to_int(d.get("floor_index", 1), 1)
	s.auto_battle = bool(d.get("auto_battle", false))
	return s
