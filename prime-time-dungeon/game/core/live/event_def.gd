# STUB(M0) — owned by M8. Replace completely, keep the public API.
class_name EventDef extends RefCounted
## Live/offline event incl. quest and windows (05 §10.1, Brief §6b.5). Fields mirror data/events.json.

var id: String = ""
var kind: String = "offline"
var name_key: String = ""
var floor_index: int = 1          # JSON key "floor" (floor() is a builtin, §13.1)
var windows: Array[Dictionary] = []
var late_entry: String = "none"
var seed_policy: Dictionary = {}
var quest: Dictionary = {}
var rules: Dictionary = {}
var votes: Dictionary = {}
var scoring: Dictionary = {}
var rewards: Dictionary = {}


static func from_dict(d: Dictionary) -> EventDef:
	return null


func validate() -> PackedStringArray:
	return PackedStringArray()


## &"always", &"scheduled", &"open", &"last_entry", &"closing", &"closed"
func window_state(now_unix: int) -> StringName:
	return &"always"


func can_start(now_unix: int) -> bool:
	return false


## Only seed_policy "fixed".
func run_seed() -> int:
	return 0
