class_name MilestoneDef extends RefCounted
## milestones.json entry (02_TECH §4.4.11). Immutable after loading.

var id: String = ""
var followers: int = 0
var reward_box: String = ""
var credits: int = 0
var item: String = ""
var title: String = ""
var min_floor: int = 1
var mod_tag: String = "follower_milestone"


static func from_dict(d: Dictionary) -> MilestoneDef:
	var r: MilestoneDef = MilestoneDef.new()
	r.id = str(d.get("id", ""))
	r.followers = int(d.get("followers", 0))
	r.reward_box = str(d.get("reward_box", ""))
	r.credits = int(d.get("credits", 0))
	r.item = str(d.get("item", ""))
	r.title = str(d.get("title", ""))
	r.min_floor = int(d.get("min_floor", 1))
	r.mod_tag = str(d.get("mod_tag", "follower_milestone"))
	return r
