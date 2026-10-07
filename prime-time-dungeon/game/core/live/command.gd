# STUB(M0) — owned by M8. Replace completely, keep the public API.
class_name Command extends RefCounted
## Schema check of recorded commands (02_TECH §3.4 "t" types).
## Shapes recorded by Game: floor {"floor"}, encounter {"enc", "adv", "group"}, battle {"cmd", "auto"},
## lootbox {"box"}, buy {"item", "qty", "safe_room"}, sell {"item", "qty"}, equip {"member", "slot", "item"},
## use_item {"item", "member"}, rest {}, event {"id", "choice"}, chest {"id"}, gate {"key"}, room {"cell": [x, y]},
## safe_room {"id"}, safe_room_exit {}, scene {"id"}, flag {"key", "value"}, difficulty {"to"}, descend {},
## gift {"gift"} (external input, cmd id 0).

const TYPES: PackedStringArray = ["floor", "encounter", "battle", "lootbox", "buy", "sell", "equip", "use_item", "rest",
	"event", "chest", "gate", "room", "safe_room", "safe_room_exit", "scene", "flag", "difficulty", "descend", "gift"]


## "" = valid.
static func validate(d: Dictionary) -> String:
	return ""
