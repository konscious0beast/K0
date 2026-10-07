# STUB(M0) — owned by M6. Replace completely, keep the public API.
extends Node
## Main scene stub (02_TECH §0.2): goes straight to Router.SCENE_TITLE; with --autoplay it only prints
## "AUTOPLAY: SKIPPED (stub)" once the title is shown and quits with exit code 0.

const AUTOPLAY_FRAME_BUDGET: int = 300


## Lives under root (the boot scene is freed by the first Router.goto).
class AutoplayStub extends Node:
	var frames: int = 0

	func _process(_delta: float) -> void:
		frames += 1
		var cur: Node = Router.current
		if cur != null and cur is TitleScreen and not Router.busy:
			print("AUTOPLAY: SKIPPED (stub)")
			set_process(false)
			get_tree().quit(0)
		elif frames > AUTOPLAY_FRAME_BUDGET:
			printerr("Assertion failed: AUTOPLAY step 'boot_to_title' failed: title not reached (stub)")
			set_process(false)
			get_tree().quit(1)


func _ready() -> void:
	if OS.get_cmdline_user_args().has("--autoplay"):
		Game.autoplay = true
		Game.ephemeral = true
		Save.read_only = true
		var ap: AutoplayStub = AutoplayStub.new()
		ap.name = "Autoplay"
		ap.process_mode = Node.PROCESS_MODE_ALWAYS
		get_tree().root.add_child.call_deferred(ap)
	Game.apply_settings()
	Router.goto(Router.SCENE_TITLE)
