class_name CTBQueue extends RefCounted
## Tick system, turn order and preview (02_TECH §5.5, GDD §3.2–3.4). Integer arithmetic only (05 CR-12).
## Counters live on the combatants (`Combatant.ctb_counter`); the queue holds the participating units in a stable order
## (party, enemies, then summons/pseudo units in the order they joined). Dead units stay listed but never act.

const FixedMath := preload("res://core/stats/fixed_math.gd")

const TICK_K: int = 1000
const TICK_OFFSET: int = 10
const RANK_DIVISOR: float = 3.0
const RANK_QUICK: int = 2      # ITEM, DEFEND, FLEE
const RANK_NORMAL: int = 3     # ATTACK, default skill rank
const PREVIEW_LENGTH: int = 12         # desktop/gamepad
const PREVIEW_LENGTH_TOUCH: int = 10   # touch UI shows the first 10 of the same list
const START_MIN_PM: int = 500          # NORMAL start: base_delay × [0.5, 1.0] (GDD §2.4), drawn as randi_range in ‰
const START_MAX_PM: int = 1000
const PSEUDO_DEFAULT_CTR: int = 100    # pseudo unit without definition (defensive)

var units: Array[Combatant] = []


## roundi(TICK_K / float(spd + TICK_OFFSET)); spd = effective SPD. Integer form: (2K + d) / 2d.
static func base_delay(spd: int) -> int:
	var d: int = maxi(1, spd + TICK_OFFSET)
	return (TICK_K * 2 + d) / (2 * d)


## maxi(1, roundi(base_delay(c.stat(SPD)) * rank / RANK_DIVISOR * c.speed_mult())).
static func delay_for(c: Combatant, rank: int) -> int:
	var bd: int = base_delay(c.stat(StatBlock.Stat.SPD))
	var den: int = roundi(RANK_DIVISOR * float(FixedMath.PM))
	return maxi(1, FixedMath.div_round(bd * rank * c.speed_pm(), den))


## Start counters (GDD §2.4): NORMAL roundi(base_delay × [0.5, 1.0]) for every unit (in list order, one draw each),
## PREEMPTIVE party 0 / enemies base_delay, AMBUSH enemies 0 / party base_delay. Pseudo units keep their counter.
func setup(combatants: Array[Combatant], advantage: int, rng: RandomNumberGenerator) -> void:
	units.clear()
	for c: Combatant in combatants:
		if c != null and not units.has(c):
			units.append(c)
	for c: Combatant in units:
		if c.is_pseudo:
			continue
		var bd: int = base_delay(c.stat(StatBlock.Stat.SPD))
		match advantage:
			BattleSetup.Advantage.PREEMPTIVE:
				c.ctb_counter = 0 if c.is_party() else bd
			BattleSetup.Advantage.AMBUSH:
				c.ctb_counter = bd if c.is_party() else 0
			_:
				c.ctb_counter = FixedMath.div_round(bd * rng.randi_range(START_MIN_PM, START_MAX_PM), FixedMath.PM)


## Lowest counter among living (incl. pseudo); ties: party → enemy → pseudo, then higher effective SPD, then lower slot;
## subtracts that counter from all living. null if nobody can act.
func next_actor() -> Combatant:
	var best: Combatant = null
	for c: Combatant in units:
		if not c.is_alive():
			continue
		if best == null or _before(c, c.ctb_counter, best, best.ctb_counter):
			best = c
	if best == null:
		return null
	var dt: int = best.ctb_counter
	if dt != 0:
		for c: Combatant in units:
			if c.is_alive():
				c.ctb_counter -= dt
	return best


## c.ctb_counter = delay_for(c, rank); pseudo: PseudoUnitDef.ctr_after.
func on_acted(c: Combatant, rank: int) -> void:
	c.ctb_counter = next_delay(c, rank)


## Pure simulation on a copy, no mutation; index 0 = current/next actor. With `actor` (the unit whose turn is running,
## counter 0) the list starts with it and its first follow-up uses `rank` (pending_rank of the highlighted action,
## -1 → 3); everyone else rank 3, pseudo units ctr_after. overrides: {combatant_id: ctr} for the ghost preview of
## stun/slow/haste targets (GDD §3.4; for `actor` it replaces its follow-up counter).
func preview(count: int, actor: Combatant = null, rank: int = -1, overrides: Dictionary = {}) -> PackedStringArray:
	var out: PackedStringArray = []
	if count <= 0:
		return out
	var live: Array[Combatant] = []
	var ctr: Array[int] = []
	for c: Combatant in units:
		if c.is_alive():
			live.append(c)
			ctr.append(JsonUtil.to_int(overrides[c.id]) if overrides.has(c.id) else c.ctb_counter)
	if live.is_empty():
		return out
	if actor != null:
		var ai: int = live.find(actor)
		if ai >= 0:
			out.append(actor.id)
			if overrides.has(actor.id):
				ctr[ai] = JsonUtil.to_int(overrides[actor.id])
			else:
				ctr[ai] = next_delay(actor, rank if rank > 0 else RANK_NORMAL)
	while out.size() < count:
		var k: int = 0
		for i in range(1, live.size()):
			if _before(live[i], ctr[i], live[k], ctr[k]):
				k = i
		var dt: int = ctr[k]
		if dt != 0:
			for i in live.size():
				ctr[i] -= dt
		out.append(live[k].id)
		ctr[k] = next_delay(live[k], RANK_NORMAL)
	return out


## Summons roundi(base_delay × 0.5), revived base_delay, pseudo per op. Adds the unit if needed and sets its counter.
func add(c: Combatant, counter: int) -> void:
	if c == null:
		return
	if not units.has(c):
		units.append(c)
	c.ctb_counter = counter


func remove(c: Combatant) -> void:
	units.erase(c)


## Stun on apply, stunt fail.
func add_delay(c: Combatant, ticks: int) -> void:
	if c != null:
		c.ctb_counter += ticks


func has_unit(c: Combatant) -> bool:
	return units.has(c)


## Counter a unit gets after acting with `rank` (pseudo: ctr_after).
static func next_delay(c: Combatant, rank: int) -> int:
	if c.is_pseudo:
		return c.pseudo_def.ctr_after if c.pseudo_def != null else PSEUDO_DEFAULT_CTR
	return delay_for(c, rank)


## Snapshot: unit ids in queue order (counters are part of the combatants).
func to_dict() -> Dictionary:
	var ids: Array = []
	for c: Combatant in units:
		ids.append(c.id)
	return {"units": ids}


static func from_dict(d: Dictionary, combatants: Array[Combatant]) -> CTBQueue:
	var q: CTBQueue = CTBQueue.new()
	for v: Variant in (d.get("units", []) as Array):
		for c: Combatant in combatants:
			if c.id == str(v):
				q.units.append(c)
				break
	return q


## a (with counter ca) acts before b (counter cb)?
static func _before(a: Combatant, ca: int, b: Combatant, cb: int) -> bool:
	if ca != cb:
		return ca < cb
	var ga: int = _group(a)
	var gb: int = _group(b)
	if ga != gb:
		return ga < gb
	var sa: int = a.stat(StatBlock.Stat.SPD)
	var sb: int = b.stat(StatBlock.Stat.SPD)
	if sa != sb:
		return sa > sb
	return a.slot < b.slot


static func _group(c: Combatant) -> int:
	if c.is_pseudo:
		return 2
	return 0 if c.is_party() else 1
