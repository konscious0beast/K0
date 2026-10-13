# STUB(ST0) — owned by 09-ST1-E. Replace completely, keep the public API.
class_name RecipeDef extends RefCounted
## professions.json → recipes entry (09 §8.5): a recipe (`rcp_`) of one profession with its grade (Güte 1–6) and its
## requirement R (the profession value the recipe needs). `hobby_recipe`: the one free recipe of its profession that
## a hobby gives (09 §8.6, persona v2 "recipe"). Immutable after loading.
## ST0 (contract pass): the minimal schema of validators/professions.gd; ST1-E adds ingredients and results.

var id: String = ""
var name: String = ""
var prof: String = ""                      # prf_ id of its profession
var grade: int = 1                         # Güte 1–6
var req: int = 1                           # requirement R (profession value 1–300)
var hobby_recipe: bool = false


static func from_dict(d: Dictionary) -> RecipeDef:
	var r: RecipeDef = RecipeDef.new()
	r.id = str(d.get("id", ""))
	r.name = str(d.get("name", ""))
	r.prof = str(d.get("prof", ""))
	r.grade = int(d.get("grade", 1))
	r.req = int(d.get("req", 1))
	r.hobby_recipe = bool(d.get("hobby_recipe", false))
	return r
