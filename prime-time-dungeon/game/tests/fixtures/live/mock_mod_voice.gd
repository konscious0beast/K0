extends ModVoiceProvider
## Test provider (06-D): answers request_turn with the next queued answer — immediately (sync) or held until
## release() (async, like the network). Records every request batch for assertions.

var answers: Array = []                        # [{"lines": Array, "twist": Dictionary}]
var batches: Array = []
var hold: bool = false                     # true: answers wait for release()
var _held: Array = []                      # [[req_id, answer]]


func kind() -> StringName:
	return &"mock"


func is_available() -> bool:
	return true


func request_turn(batch: Dictionary) -> String:
	var id: String = _req_id_of(batch)
	batches.append(batch.duplicate(true))
	var a: Dictionary = answers.pop_front() if not answers.is_empty() else {"lines": [], "twist": {}}
	if hold:
		_held.append([id, a])
	else:
		turn_ready.emit(id, a.get("lines", []), a.get("twist", {}))
	return id


func release() -> void:
	var held: Array = _held.duplicate()
	_held.clear()
	for h: Array in held:
		var a: Dictionary = h[1]
		turn_ready.emit(str(h[0]), a.get("lines", []), a.get("twist", {}))


func fail() -> void:
	status_changed.emit(&"degraded")
