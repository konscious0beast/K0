extends SceneTree
## Screenshot tool (02_TECH §11.3), used by `check.sh --shot`. No class_name / autoload identifiers.
## godot --path <game> --rendering-driver opengl3 --resolution WxH -s res://tests/capture.gd -- \
##     --scene=<res://…tscn> --out=<abs.png> [--frames=<n>] [--no-global-ui]

const GLOBAL_UI: String = "res://scenes/ui/global_ui.tscn"


func _initialize() -> void:
	var scene_path: String = ""
	var out_path: String = ""
	var frames: int = 90
	var with_global_ui: bool = true
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--scene="):
			scene_path = a.trim_prefix("--scene=")
		elif a.begins_with("--out="):
			out_path = a.trim_prefix("--out=")
		elif a.begins_with("--frames="):
			frames = maxi(1, a.trim_prefix("--frames=").to_int())
		elif a == "--no-global-ui":
			with_global_ui = false
	if scene_path == "" or out_path == "":
		printerr("Assertion failed: capture: missing --scene/--out")
		quit(1)
		return
	if DisplayServer.get_name() == "headless":
		# The dummy renderer never emits frame_post_draw: without this check the process would hang.
		printerr("Assertion failed: capture: needs a display (run via check.sh --shot / xvfb)")
		quit(2)
		return
	await process_frame
	Engine.max_fps = 60
	var game: Node = root.get_node_or_null("Game")
	if game != null:
		game.set("ephemeral", true)
	if not ResourceLoader.exists(scene_path):
		printerr("Assertion failed: capture: scene not found %s" % scene_path)
		quit(1)
		return
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		printerr("Assertion failed: capture: not a scene %s" % scene_path)
		quit(1)
		return
	var node: Node = packed.instantiate()
	if node == null:
		printerr("Assertion failed: capture: cannot instantiate %s" % scene_path)
		quit(1)
		return
	if node.has_method("setup"):
		node.call("setup", {"capture": true})
	root.add_child(node)
	var router: Node = root.get_node_or_null("Router")
	if router != null:
		router.call("adopt", node)
	if with_global_ui and ResourceLoader.exists(GLOBAL_UI):
		var ui_scene: PackedScene = load(GLOBAL_UI) as PackedScene
		if ui_scene != null:
			root.add_child(ui_scene.instantiate())
	for i in frames:
		await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if img == null or img.is_empty():
		printerr("Assertion failed: capture: empty image")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
	var err: Error = img.save_png(out_path)
	if err != OK:
		printerr("Assertion failed: capture: cannot write %s (error %d)" % [out_path, err])
		quit(2)
		return
	print("CAPTURE: saved %s %dx%d" % [out_path, img.get_width(), img.get_height()])
	quit(0)
