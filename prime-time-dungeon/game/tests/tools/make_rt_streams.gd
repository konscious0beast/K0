extends SceneTree
## Writes the canned real-time streams of tests/fixtures/rt_min/streams (07 §12.2, R1a) with
## tests/fixtures/rt_min/stream_builder.gd. No class_name / autoload identifiers (02_TECH §13.2 rule 4).
## godot --headless --path game -s res://tests/tools/make_rt_streams.gd -- --out=<abs dir>
## (tools: GODOT=… godot --headless --path game -s … -- --out="$PWD/game/tests/fixtures/rt_min/streams")

const BUILDER: String = "res://tests/fixtures/rt_min/stream_builder.gd"


func _initialize() -> void:
	var out_dir: String = ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.trim_prefix("--out=")
	if out_dir == "":
		printerr("Assertion failed: make_rt_streams: missing --out=<dir>")
		quit(1)
		return
	await process_frame
	var builder: Object = (load(BUILDER) as GDScript).new()
	var failed: PackedStringArray = builder.call("write_all", out_dir)
	for f: String in failed:
		printerr("Assertion failed: make_rt_streams: cannot write %s" % f)
	print("RT_STREAMS: %s → %s" % ["ok" if failed.is_empty() else "failed", out_dir])
	quit(0 if failed.is_empty() else 1)
