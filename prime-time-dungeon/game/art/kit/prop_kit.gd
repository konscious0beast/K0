# STUB(M0) — owned by M4. Replace completely, keep the public API.
class_name PropKit extends RefCounted
## Props (02_TECH §8.5). Stub returns empty nodes ("chest" → ChestProp).

const IDS: PackedStringArray = ["chest", "stairs_down", "safe_door", "vending_machine", "save_terminal", "couch", "crate",
	"barrel", "bench", "pillar", "lamp", "trash_bin", "turnstile", "poster", "camera_drone", "billboard", "rail", "wreck", "pipe",
	"gate", "phone_booth", "fortune_wheel", "lever", "broken_vending"]   # gate: closed door bar; last four: floor events (§7.4)


## "chest" returns ChestProp.
static func build(prop_id: StringName, seed: int = 0, palette: Dictionary = {}) -> Node3D:
	if prop_id == &"chest":
		return ChestProp.new()
	return Node3D.new()
