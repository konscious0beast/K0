# STUB(M0) — owned by M4. Replace completely, keep the public API.
class_name CharacterBuilder extends RefCounted
## ModelSpec → CharacterRig (02_TECH §8.4). Stub returns an empty rig.


## model = ModelSpec (§4.4.14). glTF if model.gltf exists, otherwise procedural archetype.
static func build(model: Dictionary, seed: int = 0) -> CharacterRig:
	var rig: CharacterRig = CharacterRig.new()
	rig.model = model
	return rig


## == DataValidator.MODEL_BASES (test asserts)
static func supported_bases() -> PackedStringArray:
	return PackedStringArray()


## == DataValidator.MODEL_PROPS
static func supported_props() -> PackedStringArray:
	return PackedStringArray()


## pose "auto": rodent with scale >= 1.0 → &"upright", else &"quadruped"
static func resolve_pose(model: Dictionary) -> StringName:
	return &"upright"
