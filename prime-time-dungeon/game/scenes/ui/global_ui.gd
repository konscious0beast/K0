extends Node
## Persistent UI (02_TECH §9.4): ShowOverlay (layer 40), ModDialog + Toasts (45), DebugOverlay (90). Added once under
## root by Boot (and by capture.gd), PROCESS_MODE_ALWAYS, outside the Router stack. Display mode follows
## Events.overlay_mode_requested; the initial mode is derived from the active screen (scenes that requested a mode before
## GlobalUi existed, e.g. in captures). Also caches the last event-run summary (Events.run_finished) for RunResult.

const SHOW_OVERLAY: String = "res://scenes/ui/show_overlay.tscn"
const MOD_DIALOG: String = "res://scenes/ui/mod_dialog.tscn"
const ToastStack := preload("res://scenes/ui/toast_stack.gd")
const DebugOverlay := preload("res://scenes/ui/debug_overlay.gd")
const RunResultScript := preload("res://scenes/ui/run_result.gd")

var show_overlay: CanvasLayer
var mod_dialog: CanvasLayer
var toasts: CanvasLayer
var debug_overlay: CanvasLayer

var _params: Dictionary = {}


## Optional: {"capture": true} → demo still (overlay with sample numbers, a M.O.D. line, a toast).
func setup(params: Dictionary) -> void:
	_params = params


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	# Exactly one GlobalUi: a second instance (e.g. capture.gd adding one next to a GlobalUi still) removes itself.
	if get_parent() != null:
		for n: Node in get_parent().get_children():
			if n != self and n.get_script() == get_script():
				queue_free()
				return
	var capture: bool = bool(_params.get("capture", false))
	show_overlay = (load(SHOW_OVERLAY) as PackedScene).instantiate() as CanvasLayer
	show_overlay.name = "ShowOverlay"
	show_overlay.call("setup", {"capture": capture})
	add_child(show_overlay)
	mod_dialog = (load(MOD_DIALOG) as PackedScene).instantiate() as CanvasLayer
	mod_dialog.name = "ModDialog"
	mod_dialog.call("setup", {"capture": capture})
	add_child(mod_dialog)
	toasts = ToastStack.new()
	toasts.name = "Toasts"
	add_child(toasts)
	debug_overlay = DebugOverlay.new()
	debug_overlay.name = "DebugOverlay"
	add_child(debug_overlay)
	Events.run_finished.connect(_on_run_finished)
	if capture:
		toasts.call("push_toast", "Erster Kill", &"achievement")
	else:
		var mode: StringName = initial_mode()
		show_overlay.call("set_mode", mode)
		mod_dialog.call("set_overlay_mode", mode)


## Overlay mode for the active screen (Router.current): exploration / battle / safe room, else menu.
static func initial_mode() -> StringName:
	var cur: Node = Router.current
	if cur is ExplorationScene:
		return &"explore"
	if cur is BattleScene:
		return &"battle"
	if cur is SafeRoomScene:
		return &"safe_room"
	return &"menu"


func _on_run_finished(summary: Dictionary) -> void:
	RunResultScript.last_summary = summary.duplicate(true)
