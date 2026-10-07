extends TestCase
## Autoplay driver (02_TECH §11.4): stub detection (missing or "# STUB(M0)" first line), the step table budgets, the
## skip path ("AUTOPLAY: SKIPPED (stub)" after boot_to_title while modules are stubs) in dry-run mode (no quit, no
## print), the safe room choice, and the boot arguments.

const AutoplayScript := preload("res://scenes/boot/autoplay.gd")
const TitleFlow := preload("res://scenes/title/title_flow.gd")
const ROUTER_FIXTURE: String = "res://tests/fixtures/router/router_screen.tscn"
const SCENE_TITLE: String = "res://scenes/title/title.tscn"
const STUB_PROBE: String = "user://m6_autoplay_stub_probe.gd"
const REAL_PROBE: String = "user://m6_autoplay_real_probe.gd"


func before_each() -> void:
	Engine.time_scale = 8.0
	tree.paused = false


func after_each() -> void:
	Engine.time_scale = 1.0
	for p: String in [STUB_PROBE, REAL_PROBE]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	Router.adopt(null)


func test_step_table_matches_spec() -> void:
	var names: Array[String] = []
	var total: int = 0
	for s: Dictionary in AutoplayScript.STEPS:
		names.append(str(s["name"]))
		total += int(s["budget"])
	assert_eq(names, ["boot_to_title", "new_game", "explore", "force_battle", "battle", "safe_room"] as Array[String])
	assert_eq([60, 90, 30, 60, 300, 60], AutoplayScript.STEPS.map(func(s: Dictionary) -> int: return int(s["budget"])))
	assert_eq(total, 600, "budgets sum to 600 frames")
	assert_eq(AutoplayScript.WATCHDOG_FRAMES, 640, "watchdog well before --quit-after 900")
	assert_eq(AutoplayScript.AUTOPLAY_SEED, 4242)


func test_stub_detection() -> void:
	var f: FileAccess = FileAccess.open(STUB_PROBE, FileAccess.WRITE)
	f.store_string("# STUB(M0) — probe\nextends RefCounted\n")
	f.close()
	var g: FileAccess = FileAccess.open(REAL_PROBE, FileAccess.WRITE)
	g.store_string("extends RefCounted\n## real implementation\n")
	g.close()
	var missing: String = "res://scenes/does_not_exist_m6_probe.gd"
	var out: PackedStringArray = AutoplayScript.stub_dependencies(PackedStringArray([STUB_PROBE, REAL_PROBE, missing]))
	assert_eq(out, PackedStringArray([STUB_PROBE, missing]), "stub header and missing files count, real files not")
	assert_false(AutoplayScript.stub_dependencies(PackedStringArray(["res://scenes/title/title.gd"])).has(
		"res://scenes/title/title.gd"), "the M6 title screen is a real implementation")
	for p: String in AutoplayScript.REQUIRED:
		assert_true(p.begins_with("res://") and p.ends_with(".gd"), "required script path %s" % p)


func test_dry_run_reaches_title_then_skips_or_continues() -> void:
	var title: Node = (load(SCENE_TITLE) as PackedScene).instantiate()
	title.call("setup", {})
	add_to_tree(title)
	await wait_frames(2)
	assert_true(Router.current == title, "title adopted as current screen")
	var ap: Node = AutoplayScript.new()
	ap.set("dry_run", true)
	add_to_tree(ap)
	var stubs: PackedStringArray = AutoplayScript.stub_dependencies()
	var ok: bool = await wait_until(func() -> bool: return bool(ap.get("finished")) or int(ap.get("step")) >= 1, 120)
	assert_true(ok, "boot_to_title is reached within its budget")
	if not stubs.is_empty():
		assert_true(bool(ap.get("finished")), "with stub modules the run ends after boot_to_title")
		assert_eq(int(ap.get("result_code")), 0)
		assert_eq(str(ap.get("result_line")), "AUTOPLAY: SKIPPED (stub)", "exact skip line (check.sh regex)")
	else:
		assert_eq(int(ap.get("step")), 1, "all modules real: continues with new_game")
		ap.set("finished", true)          # stop before it starts a real game inside the test run
	assert_eq(ap.process_mode, Node.PROCESS_MODE_ALWAYS)


func test_watchdog_failure_is_reported_not_quit_in_dry_run() -> void:
	var ap: Node = AutoplayScript.new()
	ap.set("dry_run", true)
	Router.adopt(null)                  # no title screen → boot_to_title never succeeds
	add_to_tree(ap)
	var ok: bool = await wait_until(func() -> bool: return bool(ap.get("finished")), 400)
	assert_true(ok, "budget exceeded ends the run")
	assert_eq(int(ap.get("result_code")), 1)
	assert_has(str(ap.get("result_line")), "Assertion failed: AUTOPLAY step 'boot_to_title' failed", "check.sh ERR_RE line")


func test_smallest_safe_room() -> void:
	assert_eq(AutoplayScript.smallest_safe_room(null), "")
	var layout: FloorLayout = FloorLayout.new()
	layout.safe_room_ids[Vector2i(3, 1)] = "sr_f1_kiosk"
	layout.safe_room_ids[Vector2i(0, 4)] = "sr_f1_b_waschsalon"
	layout.safe_room_ids[Vector2i(5, 5)] = "sr_f1_c"
	assert_eq(AutoplayScript.smallest_safe_room(layout), "sr_f1_b_waschsalon", "lexicographically smallest id")


func test_boot_arguments() -> void:
	var a: Dictionary = TitleFlow.parse_args(PackedStringArray(["--autoplay"]))
	assert_true(bool(a["autoplay"]))
	assert_eq(int(TitleFlow.parse_args(PackedStringArray(["--seed=17"]))["seed"]), 17)
	for target: String in ["explore", "safe_room", "battle:enc_f1_g0", "credits", "game_over", "lobby", "title"]:
		assert_eq(str(TitleFlow.parse_args(PackedStringArray(["--goto=" + target]))["goto"]), target)
