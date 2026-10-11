extends SceneTree
## Platform matrix leg (05 Kap. 2; gate before every SIM_VERSION bump, 07 §12.2 / 08 §10.2 Nr. 17): N core bot runs
## (tests/tools/platform_matrix_bot.gd) → one "MATRIX: run …" line per run and "MATRIX: digest <sha256> runs <n>
## replay <ok|FAILED> sim_version <v> renderer <name>". tools/platform_matrix.sh compares the digests of the legs.
## No class_name / autoload identifiers (02_TECH §13.2 rule 4).
## godot --headless --path game -s res://tests/tools/platform_matrix.gd -- [--runs=20]

const BOT: String = "res://tests/tools/platform_matrix_bot.gd"


func _initialize() -> void:
	var runs: int = 20
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--runs="):
			runs = maxi(1, int(a.trim_prefix("--runs=")))
	await process_frame
	var bot: Object = (load(BOT) as GDScript).new()
	var res: Dictionary = bot.call("run_all", runs)
	if res.has("error"):
		printerr("Assertion failed: platform_matrix: data invalid: %s" % str(res["error"]))
		quit(1)
		return
	for r: Variant in (res["runs"] as Array):
		var d: Dictionary = r
		print("MATRIX: run seed %d ticks %d cmds %d checkpoints %d final %s cps %s replay %s%s" % [int(d["seed"]),
			int(d["ticks"]), int(d["cmds"]), int(d["checkpoints"]), str(d["final_hash"]), str(d["cp_digest"]),
			"ok" if bool(d["replay_ok"]) else "FAILED", "" if bool(d["replay_ok"]) else " " + str(d["replay_errors"])])
	var sim_version: Variant = (load("res://core/live/run_sim.gd") as GDScript).get_script_constant_map().get(
		"SIM_VERSION", -1)
	print("MATRIX: digest %s runs %d replay %s sim_version %s display %s renderer %s arch %s os %s" % [
		str(res["digest"]), (res["runs"] as Array).size(), "ok" if bool(res["ok"]) else "FAILED", str(sim_version),
		DisplayServer.get_name(),
		RenderingServer.get_current_rendering_driver_name() + "/" + RenderingServer.get_current_rendering_method(),
		Engine.get_architecture_name(), OS.get_name()])
	quit(0 if bool(res["ok"]) else 1)
