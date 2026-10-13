class_name ModLineDef extends RefCounted
## mod_lines.json entry (02_TECH §4.4.12). Immutable after loading.

var id: String = ""
var tag: String = ""
var tag_base: String = ""                   # part of `tag` before the first ":"
var voice: String = "mod"
var text: String = ""
var user: String = ""                       # chat only: fixed sender ("" → random handle)
var weight: int = 1
var min_floor: int = 1
var max_floor: int = 0                      # 0 = unlimited
var min_hype: int = 0
var max_hype: int = 100


static func from_dict(d: Dictionary) -> ModLineDef:
	var r: ModLineDef = ModLineDef.new()
	r.id = str(d.get("id", ""))
	r.tag = str(d.get("tag", ""))
	r.tag_base = r.tag.get_slice(":", 0)
	r.voice = str(d.get("voice", "mod"))
	r.text = str(d.get("text", ""))
	r.user = str(d.get("user", ""))
	r.weight = int(d.get("weight", 1))
	r.min_floor = int(d.get("min_floor", 1))
	r.max_floor = int(d.get("max_floor", 0))
	r.min_hype = int(d.get("min_hype", 0))
	r.max_hype = int(d.get("max_hype", 100))
	return r


## Floor/hype filter (ModAnnouncer).
func fits(floor_index: int, hype: float) -> bool:
	if floor_index < min_floor or (max_floor > 0 and floor_index > max_floor):
		return false
	return hype >= float(min_hype) and hype <= float(max_hype)
