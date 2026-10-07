extends TestCase
## Self test of the harness (02_TECH §11.2/§11.5): _deep_eq cases, assert collection, skip, await_signal timeout,
## wait_until, method deduplication, add_to_tree cleanup.


class _Emitter extends RefCounted:
	signal ping(value: int)


class _Base extends TestCase:
	func test_a() -> void:
		pass

	func test_b() -> void:
		pass

	func helper() -> void:
		pass


class _Derived extends _Base:
	func test_b() -> void:
		pass

	func test_c() -> void:
		pass

	func test_with_arg(x: int) -> void:
		pass

	func test_with_default(x: int = 1) -> void:
		pass


func _inner() -> TestCase:
	var tc: TestCase = TestCase.new()
	tc.tree = tree
	tc._tc_begin("inner")
	return tc


func test_deep_eq_packed_vs_array() -> void:
	var p: PackedStringArray = ["a", "b"]
	assert_true(_deep_eq(p, ["a", "b"]), "PackedStringArray vs Array")
	assert_true(_deep_eq(["a", "b"], p), "Array vs PackedStringArray")
	assert_false(_deep_eq(p, ["a", "c"]))
	assert_false(_deep_eq(p, ["a"]))
	var pi: PackedInt32Array = [1, 2]
	assert_true(_deep_eq(pi, [1.0, 2.0]), "PackedInt32Array vs float Array")
	assert_eq(p, ["a", "b"])


func test_deep_eq_int_vs_float() -> void:
	assert_true(_deep_eq(1, 1.0))
	assert_true(_deep_eq([1], [1.0]), "[1] vs [1.0]")
	assert_true(_deep_eq({"a": 1}, {"a": 1.0}), "{a: 1} vs {a: 1.0}")
	assert_true(_deep_eq({1: "x"}, {1.0: "x"}), "int vs float keys")
	assert_false(_deep_eq(1, 1.5))
	assert_false(_deep_eq({"a": 1}, {"a": 2}))


func test_deep_eq_stringname_vs_string() -> void:
	assert_true(_deep_eq(&"x", "x"))
	assert_true(_deep_eq([&"x"], ["x"]), "[&x] vs [x]")
	assert_true(_deep_eq({&"k": 1}, {"k": 1}), "StringName key vs String key")
	assert_false(_deep_eq(&"x", "y"))


func test_deep_eq_type_mismatch_never_errors() -> void:
	assert_false(_deep_eq(1, "1"))
	assert_false(_deep_eq(true, 1))
	assert_false(_deep_eq([1], {"0": 1}))
	assert_false(_deep_eq(null, 0))
	assert_false(_deep_eq(Vector2(1, 1), Vector2i(1, 1)))
	assert_false(_deep_eq(PackedStringArray(["a"]), {"a": 1}))
	assert_true(_deep_eq(null, null))
	assert_true(_deep_eq(Vector2i(2, 3), Vector2i(2, 3)))


func test_deep_eq_nested() -> void:
	var a: Dictionary = {"list": [1, {"x": PackedStringArray(["p"])}], "n": 2}
	var b: Dictionary = {"list": [1.0, {"x": ["p"]}], "n": 2.0}
	assert_true(_deep_eq(a, b))
	b["list"][1]["x"] = ["q"]
	assert_false(_deep_eq(a, b))
	assert_false(_deep_eq({"a": 1}, {"a": 1, "b": 2}))


func test_asserts_collect_all_failures() -> void:
	var tc: TestCase = _inner()
	tc.assert_eq(1, 2)
	tc.assert_true(false)
	tc.assert_false(true)
	tc.assert_has([1, 2], 3)
	tc.assert_len([1], 2)
	tc.assert_between(5, 1, 3)
	tc.assert_null(1)
	tc.assert_not_null(null)
	tc.assert_gt(1, 2)
	tc.assert_lt(2, 1)
	tc.assert_almost(1.0, 1.1)
	tc.assert_ne(1, 1.0)
	tc.fail("explicit")
	var res: Dictionary = tc._tc_end()
	assert_len(res["failures"], 13, "every failed assert is collected")
	assert_eq(res["skipped"], "")


func test_asserts_pass_cases() -> void:
	var tc: TestCase = _inner()
	tc.assert_has({"k": 1}, "k")
	tc.assert_has({&"k": 1}, "k")
	tc.assert_has("hello", "ell")
	tc.assert_has(PackedStringArray(["a", "b"]), "b")
	tc.assert_has([1, 2], 2.0)
	tc.assert_between(2, 1, 3)
	tc.assert_between(1, 1, 1)
	tc.assert_len("abc", 3)
	tc.assert_len({"a": 1}, 1)
	tc.assert_gt(2.5, 2)
	tc.assert_lt("a", "b")
	tc.assert_almost(0.1 + 0.2, 0.3)
	tc.assert_null(null)
	tc.assert_not_null(0)
	tc.assert_ne([1], [2])
	var res: Dictionary = tc._tc_end()
	assert_len(res["failures"], 0, "no false positives: %s" % str(res["failures"]))


func test_incomparable_types_fail_without_script_error() -> void:
	var tc: TestCase = _inner()
	tc.assert_gt("a", 1)
	tc.assert_between([1], 0, 2)
	tc.assert_len(5, 1)
	var res: Dictionary = tc._tc_end()
	assert_len(res["failures"], 3)


func test_skip_ignores_further_asserts() -> void:
	var tc: TestCase = _inner()
	tc.skip("needs display")
	tc.assert_true(false)
	tc.fail("ignored")
	var res: Dictionary = tc._tc_end()
	assert_eq(res["skipped"], "needs display")
	assert_len(res["failures"], 0)


func test_await_signal_timeout_returns_false_and_fails() -> void:
	var tc: TestCase = _inner()
	var em: _Emitter = _Emitter.new()
	var ok: bool = await tc.await_signal(em.ping, 3)
	assert_false(ok)
	var res: Dictionary = tc._tc_end()
	assert_len(res["failures"], 1, "timeout records exactly one failure")
	assert_len(em.ping.get_connections(), 0, "await_signal disconnects its callback")


func test_await_signal_fires() -> void:
	var ok: bool = await await_signal(tree.create_timer(0.01).timeout, 60)
	assert_true(ok)
	var em: _Emitter = _Emitter.new()
	var emit_later: Callable = func() -> void: em.ping.emit(7)
	emit_later.call_deferred()
	var ok2: bool = await await_signal(em.ping, 10)
	assert_true(ok2, "signal with argument")


func test_wait_until() -> void:
	var counter: Array[int] = [0]
	var cond: Callable = func() -> bool:
		counter[0] += 1
		return counter[0] >= 3
	var ok: bool = await wait_until(cond, 10)
	assert_true(ok)
	assert_eq(counter[0], 3)
	var tc: TestCase = _inner()
	var ok2: bool = await tc.wait_until(func() -> bool: return false, 2)
	assert_false(ok2)
	assert_len(tc._tc_end()["failures"], 1)


func test_wait_frames_advances_frames() -> void:
	var start: int = Engine.get_process_frames()
	await wait_frames(3)
	assert_gt(Engine.get_process_frames(), start + 2)


func test_collect_test_methods_dedups_and_filters() -> void:
	var names: PackedStringArray = TestCase.collect_test_methods(_Derived)
	assert_eq(names.count("test_b"), 1, "overridden method listed once")
	assert_has(names, "test_a", "inherited test")
	assert_has(names, "test_c")
	assert_has(names, "test_with_default", "default args count as 0 required args")
	assert_false(names.has("test_with_arg"), "methods with required args are skipped")
	assert_false(names.has("helper"))
	assert_eq(names, ["test_b", "test_c", "test_with_default", "test_a"], "own methods first, declaration order")


func test_add_to_tree_frees_nodes_after_test() -> void:
	var tc: TestCase = _inner()
	var n: Node = Node.new()
	tc.add_to_tree(n)
	assert_true(n.is_inside_tree())
	tc._tc_end()
	assert_false(is_instance_valid(n), "node freed by _tc_end")


func test_make_rng_is_seeded() -> void:
	var a: RandomNumberGenerator = make_rng(42)
	var b: RandomNumberGenerator = make_rng(42)
	assert_eq(a.randi(), b.randi())
	assert_eq(make_rng().seed, 1)


func test_fixture_data_fails_on_invalid_tables() -> void:
	var tc: TestCase = _inner()
	var d: GameData = tc.fixture_data({"statuses": [{"id": "bad"}]})
	assert_false(d.is_valid())
	assert_len(tc._tc_end()["failures"], 1)
	var ok: GameData = fixture_data({"statuses": [{"id": "sts_x", "name": "X", "kind": "buff"}]})
	assert_true(ok.is_valid())


# --- runner (§11.1): a SCRIPT ERROR fails the test, the exit code is reliable without check.sh ---------------------

const SELFTEST_ROOT: String = "res://tests/fixtures/runner_selftest"
const CHILD_TIMEOUT_MS: int = 60000


func test_runner_fails_tests_with_script_errors() -> void:
	# Runs the runner in a child process on fixture tests that crash on purpose; their SCRIPT ERROR output stays in
	# the child's pipes (it would otherwise fail check.sh).
	var args: PackedStringArray = ["--headless", "--path", ProjectSettings.globalize_path("res://"), "-s",
		"res://tests/run_tests.gd", "--", "--root=" + SELFTEST_ROOT]
	var proc: Dictionary = OS.execute_with_pipe(OS.get_executable_path(), args)
	if proc.is_empty():
		fail("cannot start a child Godot process")
		return
	var pid: int = int(proc["pid"])
	var deadline: int = Time.get_ticks_msec() + CHILD_TIMEOUT_MS
	while OS.is_process_running(pid) and Time.get_ticks_msec() < deadline:
		await tree.process_frame
	if OS.is_process_running(pid):
		OS.kill(pid)
		fail("child runner did not finish within %d ms" % CHILD_TIMEOUT_MS)
		return
	var out: String = (proc["stdio"] as FileAccess).get_as_text()
	(proc["stderr"] as FileAccess).get_as_text()
	var file: String = "test_selftest_cases.gd :: "
	assert_eq(OS.get_process_exit_code(pid), 1, "exit code 1 when a test crashed")
	assert_has(out, "[PASS] " + file + "test_a_passes")
	assert_has(out, "[FAIL] " + file + "test_b_crash_before_await — SCRIPT ERROR", "crash before an await")
	assert_has(out, "[FAIL] " + file + "test_c_crash_after_await — SCRIPT ERROR", "crash after an await")
	assert_has(out, "[FAIL] " + file + "test_d_skip_does_not_hide_a_crash — SCRIPT ERROR", "skip() does not hide it")
	assert_has(out, "RESULT: 1 passed, 3 failed, 0 skipped, 0 errors")
