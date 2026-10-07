# STUB(M0) — owned by M1. Replace completely, keep the public API.
class_name CTBQueue extends RefCounted
## Tick system, turn order and preview (02_TECH §5.5, GDD §3.2–3.4).

const TICK_K: int = 1000
const TICK_OFFSET: int = 10
const RANK_DIVISOR: float = 3.0
const RANK_QUICK: int = 2      # ITEM, DEFEND, FLEE
const RANK_NORMAL: int = 3     # ATTACK, default skill rank
const PREVIEW_LENGTH: int = 12         # desktop/gamepad
const PREVIEW_LENGTH_TOUCH: int = 10   # touch UI shows the first 10 of the same list


## roundi(TICK_K / float(spd + TICK_OFFSET)); spd = effective SPD.
static func base_delay(spd: int) -> int:
	return 0


## maxi(1, roundi(base_delay(c.stat(SPD)) * rank / RANK_DIVISOR * c.speed_mult())).
static func delay_for(c: Combatant, rank: int) -> int:
	return 0


func setup(combatants: Array[Combatant], advantage: int, rng: RandomNumberGenerator) -> void:
	pass


## Lowest counter among living (incl. pseudo); ties: party → enemy → pseudo, then higher effective SPD, then lower slot;
## subtracts that counter from all living.
func next_actor() -> Combatant:
	return null


## c.ctb_counter = delay_for(c, rank); pseudo: PseudoUnitDef.ctr_after.
func on_acted(c: Combatant, rank: int) -> void:
	pass


## Pure simulation on a copy, no mutation; index 0 = current/next actor (see 02_TECH §5.5).
func preview(count: int, actor: Combatant = null, rank: int = -1, overrides: Dictionary = {}) -> PackedStringArray:
	return PackedStringArray()


## Summons roundi(base_delay × 0.5), revived base_delay, pseudo per op.
func add(c: Combatant, counter: int) -> void:
	pass


func remove(c: Combatant) -> void:
	pass


## Stun on apply, stunt fail.
func add_delay(c: Combatant, ticks: int) -> void:
	pass
