class_name ChestSpawn extends RefCounted
## Chest placement (02_TECH §7.1). Contents of wood chests are rolled when opened (Game.open_chest → LootRoller);
## handbuilt metal/locked chests carry fixed contents; procedural floors fill `contents` via roll_chest_table.

const TYPES: PackedStringArray = ["wood", "metal", "locked"]

var id: String = ""                    # "f1_c0"
var cell: Vector2i = Vector2i.ZERO
var offset: Vector2 = Vector2.ZERO     # room-local XZ, |x|,|y| <= 4.5
var type: String = "wood"              # "wood" | "metal" | "locked" (locked needs itm_key_master)
var contents: Array[Dictionary] = []   # fixed contents (metal/locked): [{"kind", "id", "amount"}]


## Index k of the runtime id "f<i>_c<k>" (SeedUtil.derive(floor_seed, "chest", k)); -1 if malformed.
func index() -> int:
	var tail: String = id.get_slice("_c", 1)
	return tail.to_int() if tail.is_valid_int() else -1


func to_dict() -> Dictionary:
	return {"id": id, "cell": [cell.x, cell.y], "offset": [offset.x, offset.y], "type": type,
		"contents": contents.duplicate(true)}
