# STUB(ST0) — owned by 09-ST1-C. Replace completely, keep the public API.
class_name ThemeDef extends RefCounted
## themes.json entry (09 §3.1, §3.3): a Kulisse (`thm_`) — its floors and its pool of Programmpunkte (event rooms,
## show-boss variants, preferences; ids of the pool are the theme package's). Immutable after loading.
## ST0 (contract pass): the minimal schema of validators/themes.gd; ST1-C adds palettes, pools and the rest.

var id: String = ""
var name: String = ""
var floors: PackedInt32Array = []          # the floors this Kulisse covers (09 §3.1)
var program: Array = []                    # Programmpunkt pool (ST1-C)


static func from_dict(d: Dictionary) -> ThemeDef:
	var r: ThemeDef = ThemeDef.new()
	r.id = str(d.get("id", ""))
	r.name = str(d.get("name", ""))
	var fl: Variant = d.get("floors", [])
	if fl is Array:
		for f: Variant in (fl as Array):
			r.floors.append(int(f))
	var pr: Variant = d.get("program", [])
	r.program = (pr as Array).duplicate(true) if pr is Array else []
	return r
