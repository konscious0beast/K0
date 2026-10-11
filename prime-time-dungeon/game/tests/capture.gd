extends SceneTree
## Screenshot tool (02_TECH §11.3), used by `check.sh --shot`. No class_name / autoload identifiers.
## godot --path <game> --rendering-driver opengl3 --resolution WxH -s res://tests/capture.gd -- \
##     --scene=<res://…tscn> --out=<abs.png> [--frames=<n>] [--no-global-ui] [--params=<json>] [--touch] \
##     [--recipe=<name>]
## --params: JSON object merged over {"capture": true} for the scene's setup(params).
## --touch:  touch controls on + input scheme TOUCH before the scene is built (phone layout stills).
## --recipe: named scripted state from res://tests/capture_recipes.gd, run after the scene is in the tree; the
##           --frames wait follows it.

const GLOBAL_UI: String = "res://scenes/ui/global_ui.tscn"
const RECIPES: String = "res://tests/capture_recipes.gd"
const SCHEME_TOUCH: int = 2              # Game.InputScheme.TOUCH


func _initialize() -> void:
	var scene_path: String = ""
	var out_path: String = ""
	var frames: int = 90
	var with_global_ui: bool = true
	var params: Dictionary = {"capture": true}
	var touch: bool = false
	var recipe: String = ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--scene="):
			scene_path = a.trim_prefix("--scene=")
		elif a.begins_with("--out="):
			out_path = a.trim_prefix("--out=")
		elif a.begins_with("--frames="):
			frames = maxi(1, a.trim_prefix("--frames=").to_int())
		elif a == "--no-global-ui":
			with_global_ui = false
		elif a == "--touch":
			touch = true
		elif a.begins_with("--recipe="):
			recipe = a.trim_prefix("--recipe=")
		elif a.begins_with("--params="):
			var parsed: Variant = JSON.parse_string(a.trim_prefix("--params="))
			if not (parsed is Dictionary):
				printerr("Assertion failed: capture: --params is not a JSON object")
				quit(1)
				return
			params.merge(parsed as Dictionary, true)
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
		if touch:
			var settings: Object = game.get("settings") as Object
			if settings != null:
				settings.set("touch_controls", &"on")
			game.call("set_input_scheme", SCHEME_TOUCH)
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
		node.call("setup", params)
	root.add_child(node)
	var router: Node = root.get_node_or_null("Router")
	if router != null:
		router.call("adopt", node)
	if with_global_ui and ResourceLoader.exists(GLOBAL_UI):
		var ui_scene: PackedScene = load(GLOBAL_UI) as PackedScene
		if ui_scene != null:
			root.add_child(ui_scene.instantiate())
	if recipe != "":
		var script: GDScript = load(RECIPES) as GDScript
		if script == null or not script.can_instantiate():
			printerr("Assertion failed: capture: cannot load %s" % RECIPES)
			quit(1)
			return
		var runner: Node = script.new() as Node
		runner.name = "CaptureRecipes"
		root.add_child(runner)
		var ok: Variant = await runner.call("run", recipe, node)
		if not bool(ok):
			printerr("Assertion failed: capture: recipe '%s' failed" % recipe)
			quit(1)
			return
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
