# STUB(ST0) — owned by 09-ST1-E. Replace completely, keep the public API.
class_name ProfessionDef extends RefCounted
## professions.json entry (09 §8.5): a profession (`prf_`) — its kind ("gather" Sammeln, "craft" Handwerk, "side"
## Nebenberuf: Kochen and Erste Hilfe for everybody). Recipes (`rcp_`, RecipeDef), materials (`mat_`) and gathering
## nodes (`nod_`) live in the same file (top-level keys recipes / materials / nodes). Immutable after loading.
## ST0 (contract pass): the minimal schema of validators/professions.gd; ST1-E adds ranks, colours and the rest.

const KINDS: PackedStringArray = ["gather", "craft", "side"]

var id: String = ""
var name: String = ""
var kind: String = "craft"


static func from_dict(d: Dictionary) -> ProfessionDef:
	var r: ProfessionDef = ProfessionDef.new()
	r.id = str(d.get("id", ""))
	r.name = str(d.get("name", ""))
	r.kind = str(d.get("kind", "craft"))
	return r
