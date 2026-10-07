class_name SponsorSystem extends RefCounted
## Sponsor selection and hype thresholds (02_TECH §6.1/§6.2, GDD §7.4).
##
## In battle, hype rising across 50 / 75 / 100 (each once per battle) makes a system gift due while fewer than
## 2 (boss: 3) gifts were given; after the gift of threshold 100 hype is set to 80. Gifts cost no hype and no ticks.
## Selection is a weighted draw with the Show game rng (integer weights in per-mille, deterministic).

const THRESHOLDS: PackedInt32Array = [50, 75, 100]
const MAX_GIFTS_PER_BATTLE: int = 2
const MAX_GIFTS_PER_BOSS_BATTLE: int = 3
const HYPE_COST: float = 0.0
const HYPE_AFTER_TOP: float = 80.0                     # crossing 100 sets hype to 80


## Upward crossings not yet fired: thresholds t with prev_hype < t <= new_hype (ascending).
static func crossed(prev_hype: float, new_hype: float, fired: PackedInt32Array) -> PackedInt32Array:
	var out: PackedInt32Array = []
	if new_hype <= prev_hype:
		return out
	for t: int in THRESHOLDS:
		if prev_hype < float(t) and new_hype >= float(t) and not fired.has(t):
			out.append(t)
	return out


## weight × Π mult of fulfilled weight_mods.
## ctx {"is_boss": bool, "party": Array[Combatant]}: ally_hp_below / ally_mp_below = a living ally under `value`
## (ratio), ally_ko = a KO'd ally, is_boss.
static func weight_of(def: SponsorDef, ctx: Dictionary) -> float:
	if def == null:
		return 0.0
	var w: float = float(def.weight)
	var party: Array = ctx.get("party", [])
	for mod: Dictionary in def.weight_mods:
		var value: float = float(mod.get("value", 0.0))
		var hit: bool = false
		match str(mod.get("cond", "")):
			"ally_hp_below":
				for c: Variant in party:
					if c is Combatant and _alive(c) and _ratio(c.hp, _max_of(c, StatBlock.Stat.HP)) < value:
						hit = true
			"ally_mp_below":
				for c: Variant in party:
					var mmax: int = _max_of(c, StatBlock.Stat.MP) if c is Combatant else 0
					if c is Combatant and _alive(c) and mmax > 0 and _ratio(c.mp, mmax) < value:
						hit = true
			"ally_ko":
				for c: Variant in party:
					if c is Combatant and not (c as Combatant).is_pseudo and (c as Combatant).hp <= 0:
						hit = true
			"is_boss":
				hit = bool(ctx.get("is_boss", false))
		if hit:
			w *= float(mod.get("mult", 1.0))
	return maxf(0.0, w)


## ctx {"floor_index", "is_boss", "party": Array[Combatant]}; eligible by floor range; weighted; "" if none.
static func pick(data: GameData, ctx: Dictionary, rng: RandomNumberGenerator) -> String:
	if data == null or rng == null:
		return ""
	var floor_index: int = int(ctx.get("floor_index", 1))
	var ids: PackedStringArray = []
	var weights: PackedInt64Array = []
	var total: int = 0
	for def: SponsorDef in data.all_sponsors():
		if def == null or not def.is_available_on(floor_index):
			continue
		var w: int = roundi(weight_of(def, ctx) * 1000.0)
		if w <= 0:
			continue
		ids.append(def.id)
		weights.append(w)
		total += w
	if total <= 0:
		return ""
	var r: int = rng.randi_range(0, total - 1)
	for i in ids.size():
		r -= weights[i]
		if r < 0:
			return ids[i]
	return ids[ids.size() - 1]


static func _alive(c: Combatant) -> bool:
	return not c.is_pseudo and c.hp > 0


## Max HP/MP of a combatant: Combatant.max_hp()/max_mp(), falling back to its stat block.
static func _max_of(c: Combatant, s: StatBlock.Stat) -> int:
	var m: int = c.max_hp() if s == StatBlock.Stat.HP else c.max_mp()
	if m <= 0 and c.stats != null and c.stats.values.size() > int(s):
		m = c.stats.values[int(s)]
	return m


static func _ratio(v: int, m: int) -> float:
	if m <= 0:
		return 1.0
	return float(v) / float(m)
