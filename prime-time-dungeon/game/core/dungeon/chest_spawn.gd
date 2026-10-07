# STUB(M0) — owned by M3. Replace completely, keep the public API.
class_name ChestSpawn extends RefCounted
## Chest placement (02_TECH §7.1).

var id: String = ""                    # "f1_c0"
var cell: Vector2i = Vector2i.ZERO
var offset: Vector2 = Vector2.ZERO     # room-local XZ, |x|,|y| <= 4.5
var type: String = "wood"              # "wood" | "metal" | "locked" (locked needs itm_key_master)
var contents: Array[Dictionary] = []   # fixed contents (metal/locked)
