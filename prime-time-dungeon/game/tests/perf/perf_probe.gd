extends SceneTree
## Performance probe entry (02_TECH §12.1/§12.5, docs/PERFORMANCE.md), used by `tools/perf.sh`. No class_name /
## autoload identifiers (§11, §13.2 rule 4): the measuring node (perf_runner.gd) is loaded after the first frame.
## godot --path <game> [--rendering-driver opengl3] [--resolution 1280x720] -s res://tests/perf/perf_probe.gd -- \
##     [--only=startup,explore,battle,safe_room,leak] [--quality=high|low] [--cycles=20] [--out=<abs.md>]
## Without a display (headless) only the timing and leak sections run (the dummy renderer draws nothing).

const RUNNER: String = "res://tests/perf/perf_runner.gd"


func _initialize() -> void:
	# Process start → main loop: engine init + every autoload _init() (DB loads all JSON there, §2.3).
	var init_ms: int = Time.get_ticks_msec()
	await process_frame
	var script: GDScript = load(RUNNER) as GDScript
	if script == null or not script.can_instantiate():
		printerr("Assertion failed: perf: cannot load %s" % RUNNER)
		quit(1)
		return
	var node: Node = script.new() as Node
	if node == null:
		printerr("Assertion failed: perf: runner is not a Node")
		quit(1)
		return
	node.set("engine_init_ms", init_ms)
	node.name = "PerfRunner"
	root.add_child(node)
