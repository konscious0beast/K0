class_name LevelUpInfo extends RefCounted
## Level-up(s) of one member from one EXP gain (02_TECH §6.1): old → new level (may span several levels),
## gained base stats and newly learned skills. Game emits Events.level_up once per level in old+1..new.

var member_id: String = ""
var old_level: int = 1
var new_level: int = 1
var stat_gains: Dictionary = {}        # stat key → int
var learned: PackedStringArray = []
