# STUB(M0) — owned by M1. Replace completely, keep the public API.
class_name StatBlock extends RefCounted
## Eight-value stat block (02_TECH §5.2). Index == StatBlock.Stat value.

enum Stat { HP, MP, STR, MAG, DEF, RES, SPD, LCK }
const KEYS: PackedStringArray = ["hp", "mp", "str", "mag", "def", "res", "spd", "lck"]   # index == Stat value

var values: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0])   # size 8


func get_stat(s: StatBlock.Stat) -> int:
	return 0


func set_stat(s: StatBlock.Stat, v: int) -> void:
	pass


## New block (self + other).
func add(other: StatBlock) -> StatBlock:
	return null


## mults: key → float; roundi.
func scaled(mults: Dictionary) -> StatBlock:
	return null


func duplicate_block() -> StatBlock:
	return null


func to_dict() -> Dictionary:
	return {}


## Missing keys → 0.
static func from_dict(d: Dictionary) -> StatBlock:
	return null


static func key_to_stat(key: String) -> StatBlock.Stat:
	return Stat.HP
