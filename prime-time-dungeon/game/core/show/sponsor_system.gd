# STUB(M0) — owned by M2. Replace completely, keep the public API.
class_name SponsorSystem extends RefCounted
## Sponsor selection and hype thresholds (02_TECH §6.1/§6.2).

const THRESHOLDS: PackedInt32Array = [50, 75, 100]
const MAX_GIFTS_PER_BATTLE: int = 2
const MAX_GIFTS_PER_BOSS_BATTLE: int = 3
const HYPE_COST: float = 0.0
const HYPE_AFTER_TOP: float = 80.0                     # crossing 100 sets hype to 80


## Upward crossings not yet fired.
static func crossed(prev_hype: float, new_hype: float, fired: PackedInt32Array) -> PackedInt32Array:
	return PackedInt32Array()


## weight × Π mult of fulfilled weight_mods.
static func weight_of(def: SponsorDef, ctx: Dictionary) -> float:
	return 0.0


## ctx {"floor_index", "is_boss", "party": Array[Combatant]}; eligible by floor range; weighted; "" if none.
static func pick(data: GameData, ctx: Dictionary, rng: RandomNumberGenerator) -> String:
	return ""
