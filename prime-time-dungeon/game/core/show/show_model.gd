# STUB(M0) — owned by M2. Replace completely, keep the public API.
class_name ShowModel extends RefCounted
## Viewer / follower / hype math (02_TECH §6.1/§6.2).

const VIEWER_BASE: int = 1000
const VIEWER_PER_FOLLOWER: float = 1.0
const HYPE_START: float = 30.0
const HYPE_EXPLORE_FLOOR: float = 15.0
const HYPE_DECAY_TICKS: int = 150            # −1 hype per 5 s explore time (30 ticks/s)
const FOLLOWER_CONV_BASE: float = 0.01
const FOLLOWER_CONV_HYPE: float = 0.02
const FOLLOWER_BOSS_MULT: float = 2.0
const FLEE_FOLLOWER_LOSS: float = 0.01


## roundi((VIEWER_BASE × floor_mult + followers × VIEWER_PER_FOLLOWER) × (0.4 + hype / 40.0))
static func viewers_for(floor_mult: float, hype: float, followers: int) -> int:
	return 0


## 0..100
static func clamp_hype(h: float) -> float:
	return 0.0


## hype > 15 → maxf(15.0, hype − 1.0); else unchanged
static func decay_step(hype: float) -> float:
	return hype


## floori(viewers_peak_battle × (0.01 + 0.02 × hype_end / 100.0) × (is_boss ? 2.0 : 1.0) × follower_mult)
static func followers_for_battle(viewers_peak_battle: int, hype_end: float, is_boss: bool, follower_mult: float) -> int:
	return 0


## floori(followers × 0.01)
static func followers_lost_on_flee(followers: int) -> int:
	return 0
