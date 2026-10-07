extends TestCase
## Fixture of test_m0_harness.test_runner_fails_tests_with_script_errors: run in a child process with
## `--root=res://tests/fixtures/runner_selftest` (the normal run skips res://tests/fixtures).
## Three tests crash on purpose.


func test_a_passes() -> void:
	assert_true(true)


func test_b_crash_before_await() -> void:
	var nothing: Variant = null
	nothing.call(&"no_such_method")
	assert_true(true, "never reached")


func test_c_crash_after_await() -> void:
	await wait_frames(1)
	var nothing: Variant = null
	nothing.call(&"no_such_method")


func test_d_skip_does_not_hide_a_crash() -> void:
	skip("skipped before the crash")
	var nothing: Variant = null
	nothing.call(&"no_such_method")
