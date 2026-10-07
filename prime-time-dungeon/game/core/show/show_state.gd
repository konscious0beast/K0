# STUB(M0) — owned by M2. Replace completely, keep the public API.
class_name ShowState extends RefCounted
## Viewers/followers/hype/counters (part of GameState, 02_TECH §6.1).

var viewers: int = 0                         # last noise-free value (summary/save)
var followers: int = 0
var hype: float = 30.0
var stats: Dictionary = {}                   # StatIds → int
var achievements: PackedStringArray = []     # unlocked ids
var milestones: PackedStringArray = []       # reached ms ids
var sponsor_uses: Dictionary = {}            # sponsor id → total gifts given


func to_dict() -> Dictionary:
	return {}


static func from_dict(d: Dictionary) -> ShowState:
	return null
