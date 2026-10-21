class_name ThemeDef extends RefCounted
## themes.json entry (09 §3.1, §3.3; ST1-C): a Kulisse (`thm_`) — its floors, the art theme its floors render with
## (`art`, an art theme of DataValidator.THEMES: the Kulisse → art-theme mapping of FloorBuilder and BattleBridge) and
## its pool of Programmpunkte (`program`: [{"id": daily_…, "name"}] — SeasonRules.daily_id draws the floor's points from
## it, point n opens programme door n of a generator-v2 floor, ZoneGenerator). Immutable after loading.

const ART_DEFAULT: String = "metro"

var id: String = ""
var name: String = ""
var floors: PackedInt32Array = []          # the floors this Kulisse covers (09 §3.1)
var art: String = ART_DEFAULT              # the art theme of its floors (metro | mall)
var program: Array = []                    # Programmpunkt pool: [{"id", "name"}]


static func from_dict(d: Dictionary) -> ThemeDef:
	var r: ThemeDef = ThemeDef.new()
	r.id = str(d.get("id", ""))
	r.name = str(d.get("name", ""))
	var fl: Variant = d.get("floors", [])
	if fl is PackedInt32Array:                 # the validator's normalized form ("ia")
		r.floors = (fl as PackedInt32Array).duplicate()
	elif fl is Array:                          # a raw JSON entry
		for f: Variant in (fl as Array):
			r.floors.append(int(f))
	r.art = str(d.get("art", ART_DEFAULT))
	var pr: Variant = d.get("program", [])
	r.program = (pr as Array).duplicate(true) if pr is Array else []
	return r


## The art theme a floor renders with (09 §3.1; FloorBuilder.theme_id, BattleBridge): `theme` itself when it is an art
## theme, else the art theme of its Kulisse (themes.json `art`; metro when the Kulisse is unknown).
static func art_of(def: FloorDef, data: GameData) -> String:
	if def == null:
		return ART_DEFAULT
	var k: String = def.kulisse()
	if k == "":
		return def.theme
	if data == null or not data.has_id("themes", k):
		return ART_DEFAULT
	return data.theme(k).art


## The name of programme point `point_id` of this Kulisse ("" if the pool has no such point).
func point_name(point_id: String) -> String:
	for e: Variant in program:
		if e is Dictionary and str((e as Dictionary).get("id", "")) == point_id:
			return str((e as Dictionary).get("name", ""))
	return ""
