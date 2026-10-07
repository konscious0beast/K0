# STUB(M0) — owned by M2. Replace completely, keep the public API.
class_name ModAnnouncer extends RefCounted
## Picks and formats M.O.D. / chat lines (02_TECH §6.1).

const KEY_COOLDOWN_SEC: float = 20.0


func _init(p_data: GameData, p_rng: RandomNumberGenerator) -> void:
	pass


## Fallback "a:b:c" → "a:b" → "a"; filters floor/hype range; never the same line twice in a row per tag;
## key cooldown 20 s per base tag except boss_*, death, timer_*, intro (null while cooling down).
func pick(tag: String, floor_index: int, hype: float, now_sec: float) -> ModLineDef:
	return null


## death 5 > boss_* 4 > timer_* 3 > achievement* 2 > lootbox_* 1 > rest 0
static func priority(tag: String) -> int:
	return 0


## text.format(ctx); missing keys stay visible. Show always adds ctx name, floor, level, viewers, followers.
func format(line: ModLineDef, ctx: Dictionary) -> String:
	return ""
