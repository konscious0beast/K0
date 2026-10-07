# STUB(M0) — owned by M4. Replace completely, keep the public API.
class_name ChestProp extends Node3D
## Chest with open() (02_TECH §8.5).

signal opened

var is_open: bool = false


## Lid tween 0.5 s + glow; emits opened. Outside the tree: set_open_instant() + opened + push_warning.
func open(animated: bool = true) -> void:
	set_open_instant()
	opened.emit()


func set_open_instant() -> void:
	is_open = true
