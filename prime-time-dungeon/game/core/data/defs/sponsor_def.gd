class_name SponsorDef extends RefCounted
## sponsors.json entry (02_TECH §4.4.10). Immutable after loading.

var id: String = ""
var name: String = ""
var slogan: String = ""
var color: String = "#ffffff"
var gift: Array[Dictionary] = []            # GiftEffect: {"kind", "value", "status", "turns", "item", "target", "ignore_resist"}
var weight: int = 1
var weight_mods: Array[Dictionary] = []     # [{"cond": String, "value": float, "mult": float}]
var min_floor: int = 1
var max_floor: int = 0                      # 0 = unlimited
var mod_tag: String = "sponsor_gift"


static func from_dict(d: Dictionary) -> SponsorDef:
	var r: SponsorDef = SponsorDef.new()
	r.id = str(d.get("id", ""))
	r.name = str(d.get("name", ""))
	r.slogan = str(d.get("slogan", ""))
	r.color = str(d.get("color", "#ffffff"))
	r.gift.assign((d.get("gift", []) as Array).duplicate(true))
	r.weight = int(d.get("weight", 1))
	r.weight_mods.assign((d.get("weight_mods", []) as Array).duplicate(true))
	r.min_floor = int(d.get("min_floor", 1))
	r.max_floor = int(d.get("max_floor", 0))
	r.mod_tag = str(d.get("mod_tag", "sponsor_gift"))
	return r


func is_available_on(floor_index: int) -> bool:
	return floor_index >= min_floor and (max_floor == 0 or floor_index <= max_floor)
