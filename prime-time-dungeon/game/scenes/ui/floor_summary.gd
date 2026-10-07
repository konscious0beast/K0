# STUB(M0) — owned by M6. Replace completely, keep the public API.
class_name FloorSummary extends Control
## Floor summary stub (02_TECH §9.5).

var _params: Dictionary = {}


## Stores {"summary": FloorRun.summary()}; "Weiter" → Game.continue_after_summary().
func setup(params: Dictionary) -> void:
	_params = params
