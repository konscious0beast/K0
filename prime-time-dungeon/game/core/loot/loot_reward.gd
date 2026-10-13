class_name LootReward extends RefCounted
## One reward line (02_TECH §6.1): an item stack or a credit amount, with display rarity and markers for the
## lootbox UI ("DUPLIKAT → +X Cr", "GARANTIE!").

var kind: String = "item"         # "item" | "credits"
var id: String = ""               # item id
var amount: int = 1
var rarity: String = "common"
var converted_from: String = ""   # item id when a duplicate piece of equipment became credits ("DUPLIKAT → +X Cr")
var pity: bool = false            # forced by pity ("GARANTIE!")


func to_dict() -> Dictionary:
	return {"kind": kind, "id": id, "amount": amount, "rarity": rarity, "converted_from": converted_from, "pity": pity}
