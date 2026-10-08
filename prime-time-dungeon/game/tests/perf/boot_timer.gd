extends SceneTree
## Startup timer (02_TECH §12.1 "Start", docs/PERFORMANCE.md), used by tools/perf.sh. Starts the real main scene
## (boot.tscn) like the engine does and prints when the first frame is drawn and when the title is interactive.
## Deliberately free of class_name / autoload identifiers (§13.2 rule 4) AND of any script that references the screens,
## so nothing is compiled ahead that the real boot would not compile (perf_runner.gd compiles every screen).
## Then starts a new game from the title (skip intro, seed 4242) and waits for the interactive exploration: the first
## exploration also compiles the exploration scripts (deferred from the boot, see GlobalUi.initial_mode).
## Prints one line, times in ms since process start (title includes the fixed 2.0 s logo card + 0.5 s fade):
## "BOOT: init_ms=… boot_ready_ms=… first_frame_ms=…|-1 title_ms=… frames=… explore_ms=… explore_cost_ms=…"

const BOOT_SCENE: String = "res://scenes/boot/boot.tscn"
const TITLE_SCENE: String = "res://scenes/title/title.tscn"
const EXPLORE_SCENE: String = "res://scenes/exploration/exploration.tscn"
const MAX_FRAMES: int = 3000


func _initialize() -> void:
	var init_ms: int = Time.get_ticks_msec()       # engine + autoload _init (scripts compiled, DB loaded)
	await process_frame
	var t0: int = Time.get_ticks_msec()
	var packed: PackedScene = load(BOOT_SCENE) as PackedScene
	if packed == null:
		printerr("Assertion failed: boot_timer: cannot load %s" % BOOT_SCENE)
		quit(1)
		return
	var boot: Node = packed.instantiate()
	root.add_child(boot)
	current_scene = boot
	var t_ready: int = Time.get_ticks_msec()
	var first_frame: int = -1
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		first_frame = Time.get_ticks_msec()
	var router: Node = root.get_node_or_null("Router")
	var n: int = 0
	while n < MAX_FRAMES:
		await process_frame
		n += 1
		var cur: Variant = router.get("current") if router != null else null
		if cur is Node and (cur as Node).scene_file_path == TITLE_SCENE and not bool(router.get("busy")):
			break
	var t_title: int = Time.get_ticks_msec()
	var title_ok: bool = n < MAX_FRAMES
	# Title → new game (the autoplay path, 02_TECH §11.4) → interactive exploration.
	var t_new: int = Time.get_ticks_msec()
	var cur1: Variant = router.get("current") if router != null else null
	if title_ok and cur1 is Node and (cur1 as Node).has_method("request_new_game"):
		(cur1 as Node).call("request_new_game", 0, "Kai", true, 4242)
	var m: int = 0
	while title_ok and m < MAX_FRAMES:
		await process_frame
		m += 1
		var cur: Variant = router.get("current") if router != null else null
		if cur is Node and (cur as Node).scene_file_path == EXPLORE_SCENE and not bool(router.get("busy")):
			break
	var t_explore: int = Time.get_ticks_msec()
	print(("BOOT: init_ms=%d boot_ready_ms=%d first_frame_ms=%d title_ms=%d frames=%d explore_ms=%d " +
		"explore_cost_ms=%d") % [init_ms, t_ready - t0 + init_ms, first_frame if first_frame >= 0 else -1, t_title, n,
		t_explore, t_explore - t_new])
	var cur2: Variant = router.get("current") if router != null else null
	if cur2 is Node:
		(cur2 as Node).queue_free()
	await process_frame
	await process_frame
	quit(0 if title_ok and m < MAX_FRAMES else 1)
