class_name LootboxDef extends RefCounted
## lootboxes.json entry (02_TECH §4.4.8). Pools/pity are top-level (GameData.loot_pool / pity_limits).

var id: String = ""
var name: String = ""
var tier: int = 1
var color: String = "#ffffff"
var rolls: int = 2
var rarity_weights: Dictionary = {"common": 1, "rare": 0, "epic": 0}
var guarantee: String = ""                  # "" | "rare" | "epic" (last roll)
var fixed_pool: String = ""                 # "" | "fan"
var mod_tag: String = ""                    # "" → "lootbox_open_<id without box_>" (see effective_mod_tag())


static func from_dict(d: Dictionary) -> LootboxDef:
	var r: LootboxDef = LootboxDef.new()
	r.id = str(d.get("id", ""))
	r.name = str(d.get("name", ""))
	r.tier = int(d.get("tier", 1))
	r.color = str(d.get("color", "#ffffff"))
	r.rolls = int(d.get("rolls", 2))
	r.rarity_weights = (d.get("rarity_weights", {"common": 1, "rare": 0, "epic": 0}) as Dictionary).duplicate(true)
	r.guarantee = str(d.get("guarantee", ""))
	r.fixed_pool = str(d.get("fixed_pool", ""))
	r.mod_tag = str(d.get("mod_tag", ""))
	return r


func effective_mod_tag() -> String:
	if mod_tag != "":
		return mod_tag
	return "lootbox_open_" + id.trim_prefix("box_")
