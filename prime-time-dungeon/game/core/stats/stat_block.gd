class_name StatBlock extends RefCounted
## Eight-value stat block (02_TECH §5.2). Index == StatBlock.Stat value. Integers only.

const FixedMath := preload("res://core/stats/fixed_math.gd")

enum Stat { HP, MP, STR, MAG, DEF, RES, SPD, LCK }
const KEYS: PackedStringArray = ["hp", "mp", "str", "mag", "def", "res", "spd", "lck"]   # index == Stat value

var values: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0])   # size 8


func get_stat(s: StatBlock.Stat) -> int:
	return _at(int(s))


func set_stat(s: StatBlock.Stat, v: int) -> void:
	var i: int = int(s)
	if i < 0 or i >= KEYS.size():
		push_error("StatBlock.set_stat: invalid stat %d" % i)
		return
	_ensure_size()
	values[i] = v


## New block (self + other); `other == null` → copy.
func add(other: StatBlock) -> StatBlock:
	var r: StatBlock = StatBlock.new()
	for i in KEYS.size():
		r.values[i] = _at(i) + (other._at(i) if other != null else 0)
	return r


## New block, each value × mults[key] (key → float, missing = 1.0). Exact decimal rounding (half away from zero):
## 10 × 1.15 → 12 (11.5), not 11 as the float product 11.4999… would give.
func scaled(mults: Dictionary) -> StatBlock:
	var r: StatBlock = StatBlock.new()
	for i in KEYS.size():
		var v: int = _at(i)
		if mults.has(KEYS[i]):
			v = FixedMath.mul_pm(v, FixedMath.pm(float(mults[KEYS[i]])))
		r.values[i] = v
	return r


func duplicate_block() -> StatBlock:
	var r: StatBlock = StatBlock.new()
	for i in KEYS.size():
		r.values[i] = _at(i)
	return r


## {"hp": int, …} with all 8 keys.
func to_dict() -> Dictionary:
	var d: Dictionary = {}
	for i in KEYS.size():
		d[KEYS[i]] = _at(i)
	return d


## Missing keys → 0 (JSON floats are converted to int).
static func from_dict(d: Dictionary) -> StatBlock:
	var r: StatBlock = StatBlock.new()
	for i in KEYS.size():
		r.values[i] = JsonUtil.to_int(d.get(KEYS[i], 0), 0)
	return r


## "spd" → Stat.SPD; unknown key → push_error + Stat.HP.
static func key_to_stat(key: String) -> StatBlock.Stat:
	var i: int = KEYS.find(key)
	if i < 0:
		push_error("StatBlock.key_to_stat: unknown stat key '%s'" % key)
		return Stat.HP
	return i as StatBlock.Stat


func _at(i: int) -> int:
	if i < 0 or i >= values.size():
		return 0
	return values[i]


func _ensure_size() -> void:
	if values.size() < KEYS.size():
		values.resize(KEYS.size())
