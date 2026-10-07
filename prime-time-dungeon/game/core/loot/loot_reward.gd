# STUB(M0) — owned by M2. Replace completely, keep the public API.
class_name LootReward extends RefCounted
## One reward line (02_TECH §6.1).

var kind: String = "item"         # "item" | "credits"
var id: String = ""               # item id
var amount: int = 1
var rarity: String = "common"
var converted_from: String = ""   # item id when a duplicate piece of equipment became credits ("DUPLIKAT → +X Cr")
var pity: bool = false            # forced by pity ("GARANTIE!")


func to_dict() -> Dictionary:
	return {}
