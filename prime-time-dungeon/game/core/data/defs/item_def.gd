class_name ItemDef extends RefCounted
## items.json entry (02_TECH §4.4.3). Immutable after loading.

var id: String = ""
var name: String = ""
var desc: String = ""
var type: String = "consumable"
var rarity: String = "common"
var price: int = 0
var sell: int = -1                          # -1 = floori(price / 2); 0 = not sellable
var max_stack: int = 9
var tags: PackedStringArray = []
var use_skill: String = ""
var usable: String = "none"
var stats: Dictionary = {}                  # stat key → int
var crit_bonus: float = 0.0
var element_mods: Dictionary = {}           # element → float
var status_immune: PackedStringArray = []
var show_mods: Dictionary = {"hype_gain_mult": 1.0, "follower_mult": 1.0}
var equip_by: PackedStringArray = []
var attack_element: String = "physical"
var icon: String = ""
var color: String = "#ffffff"


static func from_dict(d: Dictionary) -> ItemDef:
	var r: ItemDef = ItemDef.new()
	r.id = str(d.get("id", ""))
	r.name = str(d.get("name", ""))
	r.desc = str(d.get("desc", ""))
	r.type = str(d.get("type", "consumable"))
	r.rarity = str(d.get("rarity", "common"))
	r.price = int(d.get("price", 0))
	r.sell = int(d.get("sell", -1))
	r.max_stack = int(d.get("max_stack", 9))
	r.tags = JsonUtil.to_str_array(d.get("tags", []))
	r.use_skill = str(d.get("use_skill", ""))
	r.usable = str(d.get("usable", "none"))
	r.stats = (d.get("stats", {}) as Dictionary).duplicate(true)
	r.crit_bonus = float(d.get("crit_bonus", 0.0))
	r.element_mods = (d.get("element_mods", {}) as Dictionary).duplicate(true)
	r.status_immune = JsonUtil.to_str_array(d.get("status_immune", []))
	r.show_mods = (d.get("show_mods", {"hype_gain_mult": 1.0, "follower_mult": 1.0}) as Dictionary).duplicate(true)
	r.equip_by = JsonUtil.to_str_array(d.get("equip_by", []))
	r.attack_element = str(d.get("attack_element", "physical"))
	r.icon = str(d.get("icon", ""))
	r.color = str(d.get("color", "#ffffff"))
	return r


func is_equipment() -> bool:
	return type == "weapon" or type == "armor" or type == "accessory"


## Effective sell value (ItemDef.sell, −1 → floori(price / 2)).
func sell_value() -> int:
	if sell < 0:
		return floori(price / 2.0)
	return sell
