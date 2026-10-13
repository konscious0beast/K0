extends Logger
## Captures engine log lines containing one of `needles` (e.g. "different indices", 02_TECH §8.3/§11.5 M4).
## Private helper (no class_name): used by the render probe (real renderer under check.sh --shot) and the M4 tests.

var needles: PackedStringArray = []
var hits: PackedStringArray = []
var _mutex: Mutex = Mutex.new()


func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String,
		_editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	_check(code + " " + rationale)


func _log_message(message: String, _error: bool) -> void:
	_check(message)


func _check(text: String) -> void:
	for n: String in needles:
		if text.contains(n):
			_mutex.lock()
			hits.append(text.strip_edges())
			_mutex.unlock()


func found() -> PackedStringArray:
	_mutex.lock()
	var out: PackedStringArray = hits.duplicate()
	_mutex.unlock()
	return out
