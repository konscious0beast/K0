extends SceneTree
## Test runner (02_TECH §11.1). Contains NO class_name references and NO autoload identifiers (-s entry script).
## Usage: godot --headless --path <game> -s res://tests/run_tests.gd [-- --filter=<substr> --verbose --root=<res://dir>]
## A test that raises a SCRIPT ERROR fails even if its asserts passed (counted by a Logger, so the exit code is
## reliable without check.sh's output grep).

const TEST_ROOT: String = "res://tests"
const SKIP_DIRS: PackedStringArray = ["res://tests/lib", "res://tests/fixtures"]
const TEST_CASE_PATH: String = "res://tests/lib/test_case.gd"


## Counts SCRIPT ERRORs (runtime errors in GDScript). Thread-safe: the engine may log from other threads.
class _ScriptErrorCounter extends Logger:
	var _mutex: Mutex = Mutex.new()
	var _count: int = 0

	func _log_error(_function: String, _file: String, _line: int, _code: String, _rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == Logger.ERROR_TYPE_SCRIPT:
			_mutex.lock()
			_count += 1
			_mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass

	func count() -> int:
		_mutex.lock()
		var n: int = _count
		_mutex.unlock()
		return n


func _initialize() -> void:
	var filter: String = ""
	var verbose: bool = false
	var test_root: String = TEST_ROOT
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--filter="):
			filter = a.trim_prefix("--filter=")
		elif a == "--verbose":
			verbose = true
		elif a.begins_with("--root="):
			test_root = a.trim_prefix("--root=")      # harness self-test runs fixture tests (test_m0_harness)
	await process_frame                                   # autoloads ready (DB loaded)
	var errors_log: _ScriptErrorCounter = _ScriptErrorCounter.new()
	OS.add_logger(errors_log)
	var game: Node = root.get_node_or_null("Game")
	if game != null:
		game.set("ephemeral", true)                       # settings defaults (02_TECH §3.4)
	var t0: int = Time.get_ticks_msec()
	var passed: int = 0
	var failed: int = 0
	var skipped: int = 0
	var errors: int = 0
	var total: int = 0
	var tc_script: GDScript = load(TEST_CASE_PATH) as GDScript
	if tc_script == null or not tc_script.can_instantiate():
		printerr("Assertion failed: run_tests: cannot load %s" % TEST_CASE_PATH)
		_finish(errors_log, 1)
		return
	var files: PackedStringArray = []
	_collect(test_root, files, test_root)
	files.sort()
	for path: String in files:
		var file_name: String = path.get_file()
		if filter != "" and not file_name.contains(filter):
			continue
		var script: GDScript = load(path) as GDScript
		if script == null or not script.can_instantiate():
			print("[ERROR] %s: failed to compile" % file_name)
			printerr("Assertion failed: %s: failed to compile" % file_name)
			errors += 1
			continue
		var inst: Object = script.new()
		if inst == null or not inst.has_method("_tc_marker"):
			print("[ERROR] %s: does not extend TestCase" % file_name)
			printerr("Assertion failed: %s: does not extend TestCase" % file_name)
			failed += 1
			continue
		inst.set("tree", self)
		var methods: PackedStringArray = tc_script.call("collect_test_methods", script)
		if verbose:
			print("[FILE] %s: %d tests" % [file_name, methods.size()])
		for method: String in methods:
			total += 1
			print("[RUN] %s :: %s" % [file_name, method])
			var start: int = Time.get_ticks_msec()
			var script_errors_before: int = errors_log.count()
			inst.call("_tc_begin", method)
			await inst.call("before_each")
			await inst.call(method)
			await inst.call("after_each")
			var res: Dictionary = inst.call("_tc_end")
			var ms: int = Time.get_ticks_msec() - start
			var failures: PackedStringArray = res.get("failures", PackedStringArray())
			var skip_reason: String = str(res.get("skipped", ""))
			var crashed: int = errors_log.count() - script_errors_before
			if crashed > 0:
				# A SCRIPT ERROR aborted (part of) the test: asserts after it never ran → never a pass or a skip.
				failures.insert(0, "SCRIPT ERROR (%d, see log above)" % crashed)
				skip_reason = ""
			if skip_reason != "":
				skipped += 1
				print("[SKIP] %s :: %s — %s" % [file_name, method, skip_reason])
			elif failures.is_empty():
				passed += 1
				print("[PASS] %s :: %s (%d ms)" % [file_name, method, ms])
			else:
				failed += 1
				var msg: String = "; ".join(failures)
				print("[FAIL] %s :: %s — %s" % [file_name, method, msg])
				printerr("Assertion failed: %s::%s — %s" % [file_name, method, msg])
	var secs: float = (Time.get_ticks_msec() - t0) / 1000.0
	print("RESULT: %d passed, %d failed, %d skipped, %d errors in %.2f s" % [passed, failed, skipped, errors, secs])
	if failed > 0 or errors > 0 or total == 0:
		if total == 0:
			printerr("Assertion failed: run_tests: no tests found (filter '%s')" % filter)
		_finish(errors_log, 1)
	else:
		_finish(errors_log, 0)


func _finish(errors_log: Logger, code: int) -> void:
	OS.remove_logger(errors_log)
	quit(code)


## Recursive test_*.gd below `dir_path`; SKIP_DIRS are skipped unless one of them is the requested root itself.
func _collect(dir_path: String, out: PackedStringArray, test_root: String) -> void:
	if dir_path != test_root and SKIP_DIRS.has(dir_path):
		return
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if not entry.begins_with("."):
			var full: String = dir_path.path_join(entry)
			if dir.current_is_dir():
				_collect(full, out, test_root)
			elif entry.begins_with("test_") and entry.ends_with(".gd"):
				out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
