extends SceneTree
## Writes the review matrix of the persona lines (08 §4.4 R9, K1) as CSV with tests/tools/persona_matrix_builder.gd:
## every persona_* line × every Vorleben × f / m / n (+ the free-text intro × the sample texts of job_texts.json),
## identical renderings once. The humor editors sign it off before block K changes are merged.
## No class_name / autoload identifiers (02_TECH §13.2 rule 4).
## godot --headless --path game -s res://tests/tools/persona_matrix.gd -- --out=<abs file>
## (repo: --out="$PWD/docs/review/persona_matrix.csv")

const BUILDER: String = "res://tests/tools/persona_matrix_builder.gd"


func _initialize() -> void:
	var out_file: String = ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_file = a.trim_prefix("--out=")
	if out_file == "":
		printerr("Assertion failed: persona_matrix: missing --out=<file>")
		quit(1)
		return
	await process_frame
	var data: Object = root.get_node("DB").get("data")
	var builder: GDScript = load(BUILDER) as GDScript
	var rows: Array = builder.call("build", data)
	var err: int = int(builder.call("write", out_file, data))
	if err != OK:
		printerr("Assertion failed: persona_matrix: cannot write %s (error %d)" % [out_file, err])
	print("PERSONA_MATRIX: %d rows → %s" % [rows.size(), out_file])
	quit(0 if err == OK else 1)
