extends Node3D
## Attached by the glTF rig wrapper to the imported scene root (private, no class_name): AnimationPlayer method tracks
## call emit_impact() on the scene root (03_ART §10, post-import), this forwards it to the wrapping CharacterRig.

var rig: Node = null


func emit_impact() -> void:
	if rig != null and is_instance_valid(rig):
		rig.call("emit_impact")
