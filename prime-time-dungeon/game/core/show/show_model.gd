class_name ShowModel extends RefCounted
## Viewer / follower / hype math (02_TECH §6.1/§6.2, GDD §7.2/§7.6).
##
## Deterministic integer arithmetic (05 §3.3 Nr. 5): the documented float formulas are evaluated on per-mille
## quantized inputs (floor_mult, hype, follower_mult have at most 3 decimals in data) with integer rounding, so the
## result is identical on every platform and never depends on the last ulp of a float product.

const VIEWER_BASE: int = 1000
const VIEWER_PER_FOLLOWER: float = 0.5
const HYPE_START: float = 30.0
const HYPE_EXPLORE_FLOOR: float = 25.0
const HYPE_DECAY_TICKS: int = 60             # one cooling step per 2 s explore time (30 ticks/s)
const HYPE_DECAY_PM: int = 100               # a step takes 10 % of the hype above the floor (per mille), at least 1
const FOLLOWER_CONV_BASE: float = 0.007
const FOLLOWER_CONV_HYPE: float = 0.014
const FOLLOWER_BOSS_MULT: float = 2.0
const FLEE_FOLLOWER_LOSS: float = 0.01

const _PM: int = 1000                        # per-mille scale


## roundi((VIEWER_BASE × floor_mult + followers × VIEWER_PER_FOLLOWER) × (0.4 + hype / 40.0))
## Hype 0 → 0.4×, 50 → 1.65×, 100 → 2.9× (GDD §7.2). Rounds half up.
static func viewers_for(floor_mult: float, hype: float, followers: int) -> int:
	var fm_pm: int = roundi(floor_mult * _PM)
	var vpf_pm: int = roundi(VIEWER_PER_FOLLOWER * _PM)
	var h_pm: int = roundi(clamp_hype(hype) * _PM)
	# base in milli-viewers; factor (0.4 + h / 40) = (16 × PM + h_pm) / (40 × PM)
	var base_m: int = VIEWER_BASE * fm_pm + maxi(0, followers) * vpf_pm
	var num: int = base_m * (16 * _PM + h_pm)
	var den: int = 40 * _PM * _PM
	return maxi(0, (num + den / 2) / den)


## 0..100
static func clamp_hype(h: float) -> float:
	return clampf(h, 0.0, 100.0)


## Cooling toward the floor: hype > HYPE_EXPLORE_FLOOR → hype − maxi(1, (hype − floor) × HYPE_DECAY_PM / 1000)
## (integer per mille on whole points, never below the floor); else unchanged.
static func decay_step(hype: float) -> float:
	if hype > HYPE_EXPLORE_FLOOR:
		var excess: int = roundi(hype - HYPE_EXPLORE_FLOOR)
		var drop: int = maxi(1, excess * HYPE_DECAY_PM / _PM)
		return maxf(HYPE_EXPLORE_FLOOR, hype - float(drop))
	return hype


## floori(viewers_peak_battle × (FOLLOWER_CONV_BASE + FOLLOWER_CONV_HYPE × hype_end / 100.0) × (is_boss ? 2.0 : 1.0)
## × follower_mult) — 0.007 + 0.014 × hype_end / 100 since the balancing (GDD §7.6/§13)
static func followers_for_battle(viewers_peak_battle: int, hype_end: float, is_boss: bool, follower_mult: float) -> int:
	if viewers_peak_battle <= 0:
		return 0
	var h_pm: int = roundi(clamp_hype(hype_end) * _PM)
	# conversion rate in units of 1e-7: 0.007 → 70 000, 0.014 × h / 100 = 0.00014 × h → 1.4 × h_pm
	var base_e7: int = roundi(FOLLOWER_CONV_BASE * 10_000_000.0)
	var hype_e7: int = roundi(FOLLOWER_CONV_HYPE * 100_000.0) * h_pm / _PM
	var boss_pm: int = roundi((FOLLOWER_BOSS_MULT if is_boss else 1.0) * _PM)
	var fmult_pm: int = maxi(0, roundi(follower_mult * _PM))
	var num: int = viewers_peak_battle * (base_e7 + hype_e7) * boss_pm / _PM * fmult_pm
	return maxi(0, num / (10_000_000 * _PM))


## floori(followers × 0.01)
static func followers_lost_on_flee(followers: int) -> int:
	if followers <= 0:
		return 0
	return followers * roundi(FLEE_FOLLOWER_LOSS * 10_000.0) / 10_000
