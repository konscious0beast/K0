# STUB(M0) — owned by M5. Replace completely, keep the public API.
class_name BattleScene extends Node3D
## Battle screen stub (02_TECH §9.5).

var _params: Dictionary = {}


## {"setup": BattleSetup}; missing → Game.ensure_state() + debug setup; {"capture": true} → stop at first command menu.
func setup(params: Dictionary) -> void:
	_params = params
