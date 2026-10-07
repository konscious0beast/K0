# STUB(M0) — owned by M2. Replace completely, keep the public API.
class_name LevelUpInfo extends RefCounted
## One level-up of one member (02_TECH §6.1).

var member_id: String = ""
var old_level: int = 1
var new_level: int = 1
var stat_gains: Dictionary = {}        # stat key → int
var learned: PackedStringArray = []
