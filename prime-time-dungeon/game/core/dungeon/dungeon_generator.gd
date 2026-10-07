# STUB(M0) — owned by M3. Replace completely, keep the public API.
class_name DungeonGenerator extends RefCounted
## Floor layout from data (handbuilt) or procedural generation (02_TECH §7.2).

const MAX_ATTEMPTS: int = 20


## def.layout not empty → from_layout(), else procedural.
static func generate(def: FloorDef, floor_seed: int) -> FloorLayout:
	return null


static func from_layout(def: FloorDef, floor_seed: int) -> FloorLayout:
	return null
